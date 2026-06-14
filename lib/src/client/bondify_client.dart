// lib/src/client/bondify_client.dart
// High-level client: starts a session, opens Telegram, and polls until the
// user confirms. Use this directly for custom UIs, or use BondifyButton /
// showBondifyAuthSheet for ready-made widgets.

import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'api_client.dart';

class BondifyClient {
  final BondifyConfig config;
  final BondifyApiClient _api;

  BondifyClient(this.config, {BondifyApiClient? apiClient})
      : _api = apiClient ?? BondifyApiClient(config);

  /// Optional global singleton, configured once at app start:
  /// `BondifyClient.init(BondifyConfig(projectId: '...'));`
  static BondifyClient? _instance;
  static BondifyClient get instance {
    final i = _instance;
    if (i == null) {
      throw BondifyException(
        'BondifyClient not initialised. Call BondifyClient.init(...) first.',
      );
    }
    return i;
  }

  static void init(BondifyConfig config) => _instance = BondifyClient(config);

  /// Creates a session and returns the Telegram deep link + session token.
  Future<GenerateResponse> startSession() => _api.generate();

  /// Opens the Telegram deep link in the Telegram app (or browser fallback).
  Future<void> openTelegram(String deeplink) async {
    final uri = Uri.parse(deeplink);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw BondifyException('Could not open Telegram. Is it installed?');
    }
  }

  /// Polls until the session is confirmed, expires, times out, or is cancelled.
  Future<BondifyUser> waitForConfirmation(
    String sessionToken, {
    void Function(BondifyStatus status)? onStatus,
    BondifyCancelToken? cancelToken,
  }) async {
    final deadline = DateTime.now().add(config.sessionTimeout);

    while (DateTime.now().isBefore(deadline)) {
      if (cancelToken?.isCancelled == true) {
        throw BondifyException('Cancelled', status: BondifyStatus.cancelled);
      }
      await Future.delayed(config.pollInterval);

      VerifyResponse res;
      try {
        res = await _api.verifyOnce(sessionToken);
      } catch (_) {
        // Transient network error — keep polling.
        continue;
      }

      switch (res.status) {
        case BondifyStatus.confirmed:
          onStatus?.call(BondifyStatus.confirmed);
          return res.user!;
        case BondifyStatus.expired:
          onStatus?.call(BondifyStatus.expired);
          throw BondifyException('Session expired', status: BondifyStatus.expired);
        case BondifyStatus.cancelled:
          onStatus?.call(BondifyStatus.cancelled);
          throw BondifyException('Login cancelled', status: BondifyStatus.cancelled);
        case BondifyStatus.pending:
          onStatus?.call(BondifyStatus.pending);
      }
    }
    throw BondifyException('Timed out waiting for confirmation',
        status: BondifyStatus.expired);
  }

  /// Convenience: full flow — start, open Telegram, wait for confirmation.
  Future<BondifyUser> authenticate({
    void Function(BondifyStatus status)? onStatus,
    BondifyCancelToken? cancelToken,
  }) async {
    final session = await startSession();
    await openTelegram(session.deeplink);
    return waitForConfirmation(
      session.sessionToken,
      onStatus: onStatus,
      cancelToken: cancelToken,
    );
  }

  void close() => _api.close();
}
