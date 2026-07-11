// ============================================================
//  bondify_flutter — BondifyClient
//  Main singleton auth controller
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Main SDK class.
/// Manages auth state, polling, and timers.
///
/// Usage:
/// ```dart
/// // main.dart
/// BondifyClient.init(BondifyConfig(projectId: 'proj_xxx'));
///
/// // Anywhere in the app
/// final client = BondifyClient.instance;
/// await client.startAuth();
/// ```
class BondifyClient extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────
  static BondifyClient? _instance;
  static BondifyClient get instance {
    assert(
      _instance != null,
      'BondifyClient is not initialised. Call BondifyClient.init() in main().',
    );
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  /// Initialise the SDK (call once in main())
  static void init(BondifyConfig config) {
    _instance?.dispose();
    _instance = BondifyClient._(config);
  }

  // ── State ──────────────────────────────────────────────────────────────
  BondifyAuthState _state = BondifyAuthState.initial;
  BondifyAuthState get state => _state;

  // Callbacks
  void Function(BondifyUser user)?      onSuccess;
  void Function(BondifyException error)? onError;
  void Function()?                       onCancel;

  // Timers
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  Timer? _countdownTimer;

  final BondifyConfig    _config;
  final BondifyApiClient _client;
  bool _disposed = false;

  BondifyClient._(this._config)
      : _client = BondifyApiClient(
          apiUrl:    _config.apiUrl,
          projectId: _config.projectId,
        );

  // ── Convenience getters ─────────────────────────────────────────────────
  BondifyAuthStatus get status          => _state.status;
  BondifyUser?      get user            => _state.user;
  BondifyException? get error           => _state.error;
  String?           get deeplink        => _state.deeplink;
  String?           get sessionToken    => _state.sessionToken;
  bool              get isLoading       => _state.isLoading;
  bool              get isAuthenticated => _state.isAuthenticated;
  int?              get secondsLeft     => _state.secondsLeft;

  // ── Start auth ──────────────────────────────────────────────────────────
  /// Creates a session and starts polling.
  /// After calling this, use [deeplink] to open Telegram.
  Future<void> startAuth() async {
    if (_state.status == BondifyAuthStatus.polling ||
        _state.status == BondifyAuthStatus.pending) return;

    _clearTimers();
    _updateState(BondifyAuthState.initial.copyWith(status: BondifyAuthStatus.pending));

    try {
      final res = await _client.generateSession();

      if (_disposed) return;

      _updateState(_state.copyWith(
        status:       BondifyAuthStatus.polling,
        sessionToken: res.sessionToken,
        deeplink:     res.deeplink,
        expiresAt:    res.expiresAt,
        clearError:   true,
      ));

      _startCountdown(res.expiresAt);
      _startPolling(res.sessionToken, res.expiresAt);
    } on BondifyException catch (e) {
      _handleError(e);
    } catch (e) {
      _handleError(BondifyException(
        code:    BondifyErrorCode.unknownError,
        message: 'Unexpected error: $e',
        details: e,
      ));
    }
  }

  // ── Polling ─────────────────────────────────────────────────────────────
  void _startPolling(String sessionToken, DateTime expiresAt) {
    // Session timeout
    final timeoutDuration = expiresAt.difference(DateTime.now());
    _timeoutTimer = Timer(
      timeoutDuration.isNegative ? const Duration(seconds: 1) : timeoutDuration,
      () {
        _clearTimers();
        if (!_disposed && _state.status == BondifyAuthStatus.polling) {
          final err = BondifyException(
            code:    BondifyErrorCode.sessionExpired,
            message: 'Session timed out. Please request a new link.',
          );
          _updateState(_state.copyWith(
            status: BondifyAuthStatus.expired,
            error:  err,
          ));
          onError?.call(err);
        }
      },
    );

    // Polling loop
    _pollingTimer = Timer.periodic(_config.pollingInterval, (_) async {
      if (_disposed) return;
      await _checkOnce(sessionToken);
    });
  }

  Future<void> _checkOnce(String sessionToken) async {
    try {
      final res = await _client.verifySession(sessionToken);
      if (_disposed) return;

      switch (res.status) {
        case 'confirmed':
        case 'used':
          _clearTimers();
          final user = BondifyUser(
            telegramId:       res.telegramId!,
            telegramName:     res.telegramName!,
            telegramUsername: res.telegramUsername,
            telegramPhone:    res.telegramPhone,
            proof:            res.proof!,
            confirmedAt: res.confirmedAt != null
                ? DateTime.fromMillisecondsSinceEpoch(res.confirmedAt!)
                : DateTime.now(),
          );
          _updateState(_state.copyWith(
            status: BondifyAuthStatus.confirmed,
            user:   user,
          ));
          onSuccess?.call(user);

        case 'expired':
          _clearTimers();
          final err = BondifyException(
            code:    BondifyErrorCode.sessionExpired,
            message: 'The sign-in link has expired.',
          );
          _updateState(_state.copyWith(
            status: BondifyAuthStatus.expired,
            error:  err,
          ));
          onError?.call(err);

        case 'cancelled':
          _clearTimers();
          _updateState(_state.copyWith(status: BondifyAuthStatus.cancelled));
          onCancel?.call();

        default:
          break; // pending — keep polling
      }
    } on BondifyException catch (e) {
      if (e.code == BondifyErrorCode.networkError) {
        // Transient connectivity issue — keep polling silently, the next
        // tick will likely succeed.
        debugPrint('[Bondify] Polling network error (retrying): $e');
        return;
      }
      // Any other code (PROJECT_NOT_FOUND, PROJECT_INACTIVE,
      // PUBLIC_ACCESS_DISABLED, RATE_LIMITED, …) is a definitive response
      // from the backend — retrying won't help, so stop polling and let
      // the caller know instead of spinning silently forever.
      _handleError(e);
    } catch (e) {
      // Anything that isn't a BondifyException (e.g. VerifyResponse.fromJson
      // throwing a raw TypeError on a response shape we didn't expect) would
      // otherwise escape uncaught from this Timer.periodic callback, leaving
      // polling silently stuck with no feedback via onError — mirrors the
      // same defensive fallback startAuth() already has around
      // generateSession().
      _handleError(BondifyException(
        code:    BondifyErrorCode.unknownError,
        message: 'Unexpected polling error: $e',
        details: e,
      ));
    }
  }

  // ── Countdown timer ─────────────────────────────────────────────────────
  void _startCountdown(DateTime expiresAt) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // Notify listeners so they re-read secondsLeft from state
      notifyListeners();
    });
  }

  // ── Manual check ────────────────────────────────────────────────────────
  Future<void> checkStatus() async {
    if (_state.sessionToken == null) return;
    await _checkOnce(_state.sessionToken!);
  }

  // ── Reset ───────────────────────────────────────────────────────────────
  void reset() {
    _clearTimers();
    _updateState(BondifyAuthState.initial);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  void _handleError(BondifyException e) {
    if (_disposed) return;
    _clearTimers();
    _updateState(_state.copyWith(
      status: BondifyAuthStatus.error,
      error:  e,
    ));
    onError?.call(e);
  }

  void _updateState(BondifyAuthState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  void _clearTimers() {
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _pollingTimer   = null;
    _timeoutTimer   = null;
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _clearTimers();
    _client.dispose();
    super.dispose();
  }
}
