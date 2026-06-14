// lib/src/client/api_client.dart
// Thin HTTP client over the Bondify PUBLIC endpoints. These are safe to call
// from a mobile app because they only require your (non-secret) Project ID.
//
// IMPORTANT: never embed your project's secret_key (sk_…) in a mobile app.
// The public flow below is exactly what mobile clients should use. It requires
// "Mobile SDK" to be enabled in your project settings.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Raw response of `POST /api/v1/generate/public`.
class GenerateResponse {
  final String deeplink;
  final String sessionToken;
  final int? expiresAt;
  const GenerateResponse({
    required this.deeplink,
    required this.sessionToken,
    this.expiresAt,
  });
}

/// Raw response of `POST /api/v1/verify/public` (pending or confirmed).
class VerifyResponse {
  final BondifyStatus status;
  final BondifyUser? user;
  const VerifyResponse({required this.status, this.user});
}

class BondifyApiClient {
  final BondifyConfig config;
  final http.Client _http;

  BondifyApiClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Uri _u(String path) => Uri.parse('${config.apiBase}$path');

  /// Creates a login session and returns the Telegram deep link + token.
  Future<GenerateResponse> generate() async {
    final res = await _http.post(
      _u('/api/v1/generate/public'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'project_id': config.projectId}),
    );

    final body = _safeJson(res.body);
    if (res.statusCode != 200) {
      throw BondifyException(
        body['error']?.toString() ?? 'Failed to start login (${res.statusCode})',
      );
    }
    return GenerateResponse(
      deeplink: body['deeplink'] as String,
      sessionToken: body['session_token'] as String,
      expiresAt: body['expires_at'] is int ? body['expires_at'] as int : null,
    );
  }

  /// Polls the session once. Returns its current status (and user if confirmed).
  Future<VerifyResponse> verifyOnce(String sessionToken) async {
    final res = await _http.post(
      _u('/api/v1/verify/public'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'project_id': config.projectId,
        'session_token': sessionToken,
      }),
    );

    // Non-200 during polling is treated as "keep waiting" by the caller.
    if (res.statusCode != 200) {
      return const VerifyResponse(status: BondifyStatus.pending);
    }

    final body = _safeJson(res.body);
    final status = (body['status'] ?? '').toString();

    // The confirmed payload has no explicit "status" field — it returns the
    // user object directly with a `proof`.
    if (body.containsKey('proof')) {
      return VerifyResponse(
        status: BondifyStatus.confirmed,
        user: BondifyUser.fromJson(body),
      );
    }
    if (status == 'expired') {
      return const VerifyResponse(status: BondifyStatus.expired);
    }
    if (status == 'cancelled') {
      return const VerifyResponse(status: BondifyStatus.cancelled);
    }
    return const VerifyResponse(status: BondifyStatus.pending);
  }

  Map<String, dynamic> _safeJson(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void close() => _http.close();
}
