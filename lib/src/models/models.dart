// ============================================================
//  bondify_flutter — Models
//  All Dart SDK data models
// ============================================================

/// SDK configuration
class BondifyConfig {
  /// project_id from the Bondify dashboard (required)
  final String projectId;

  /// Backend base URL (default: https://api.bondify.dev)
  final String apiUrl;

  /// Polling interval (default: 1.5 s)
  final Duration pollingInterval;

  /// Session timeout (default: 10 min)
  final Duration sessionTimeout;

  const BondifyConfig({
    required this.projectId,
    this.apiUrl           = 'https://api.bondify.dev',
    this.pollingInterval  = const Duration(milliseconds: 1500),
    this.sessionTimeout   = const Duration(minutes: 10),
  });
}

/// Authenticated user
class BondifyUser {
  final String telegramId;
  final String telegramName;
  final String? telegramUsername;
  final String? telegramPhone;

  /// JWT proof — short-lived token (5 min) for backend verification
  final String proof;
  final DateTime confirmedAt;

  const BondifyUser({
    required this.telegramId,
    required this.telegramName,
    required this.telegramUsername,
    required this.telegramPhone,
    required this.proof,
    required this.confirmedAt,
  });

  factory BondifyUser.fromJson(Map<String, dynamic> json) {
    return BondifyUser(
      telegramId:       json['telegram_id']       as String,
      telegramName:     json['telegram_name']      as String,
      telegramUsername: json['telegram_username']  as String?,
      telegramPhone:    json['telegram_phone']     as String?,
      proof:            json['proof']              as String,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['confirmed_at'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'telegram_id':       telegramId,
    'telegram_name':     telegramName,
    'telegram_username': telegramUsername,
    'telegram_phone':    telegramPhone,
    'proof':             proof,
    'confirmed_at':      confirmedAt.millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'BondifyUser(id: $telegramId, name: $telegramName, username: $telegramUsername)';
}

/// Auth session status
enum BondifyAuthStatus {
  idle,
  pending,
  polling,
  confirmed,
  expired,
  cancelled,
  error,
}

/// SDK error codes
enum BondifyErrorCode {
  sessionExpired,
  sessionCancelled,
  networkError,
  projectNotFound,
  projectInactive,
  publicAccessDisabled,
  rateLimited,
  pollingTimeout,
  unknownError,
}

class BondifyException implements Exception {
  final BondifyErrorCode code;
  final String message;
  final dynamic details;

  const BondifyException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'BondifyException(${code.name}): $message';
}

/// Full auth state
class BondifyAuthState {
  final BondifyAuthStatus status;
  final BondifyUser? user;
  final BondifyException? error;
  final String? sessionToken;
  final String? deeplink;
  final DateTime? expiresAt;

  /// Remaining time in seconds
  int? get secondsLeft {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isLoading =>
      status == BondifyAuthStatus.pending ||
      status == BondifyAuthStatus.polling;

  bool get isAuthenticated => status == BondifyAuthStatus.confirmed;

  const BondifyAuthState({
    this.status       = BondifyAuthStatus.idle,
    this.user         = null,
    this.error        = null,
    this.sessionToken = null,
    this.deeplink     = null,
    this.expiresAt    = null,
  });

  BondifyAuthState copyWith({
    BondifyAuthStatus?  status,
    BondifyUser?        user,
    BondifyException?   error,
    String?             sessionToken,
    String?             deeplink,
    DateTime?           expiresAt,
    bool                clearUser    = false,
    bool                clearError   = false,
    bool                clearSession = false,
  }) {
    return BondifyAuthState(
      status:       status       ?? this.status,
      user:         clearUser    ? null : (user         ?? this.user),
      error:        clearError   ? null : (error        ?? this.error),
      sessionToken: clearSession ? null : (sessionToken ?? this.sessionToken),
      deeplink:     clearSession ? null : (deeplink     ?? this.deeplink),
      expiresAt:    clearSession ? null : (expiresAt    ?? this.expiresAt),
    );
  }

  static const initial = BondifyAuthState();
}
