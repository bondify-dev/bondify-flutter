// lib/src/models/models.dart
// Data models for the Bondify Flutter SDK.

/// Authentication status reported while waiting for the user to confirm.
enum BondifyStatus { pending, confirmed, expired, cancelled }

/// The result of a successful Telegram authentication.
///
/// [proof] is a signed JWT. Send it to YOUR backend and verify it there with
/// your project's webhook secret (`whsec_…`). Never trust the client alone.
class BondifyUser {
  /// The user's Telegram ID (stable, numeric, as a string).
  final String telegramId;

  /// The user's display name from Telegram.
  final String name;

  /// The user's @username, if they have one (without the leading @).
  final String? username;

  /// The user's phone number, only if your project collects it (Pro+).
  final String? phone;

  /// Signed JWT to verify on your backend. Treat as a bearer credential.
  final String proof;

  /// When the login was confirmed (ms since epoch).
  final int confirmedAt;

  const BondifyUser({
    required this.telegramId,
    required this.name,
    this.username,
    this.phone,
    required this.proof,
    required this.confirmedAt,
  });

  factory BondifyUser.fromJson(Map<String, dynamic> json) {
    return BondifyUser(
      telegramId: (json['telegram_id'] ?? '').toString(),
      name: (json['telegram_name'] ?? '') as String,
      username: json['telegram_username'] as String?,
      phone: json['telegram_phone'] as String?,
      proof: (json['proof'] ?? '') as String,
      confirmedAt: (json['confirmed_at'] is int)
          ? json['confirmed_at'] as int
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() => 'BondifyUser(id: $telegramId, name: $name)';
}

/// SDK configuration. Only [projectId] is required.
class BondifyConfig {
  /// Your Bondify Project ID (e.g. `proj_xxxxxxxx`), found in the dashboard.
  final String projectId;

  /// API base URL. Defaults to the hosted Bondify API.
  final String apiBase;

  /// How long to wait for the user to confirm before giving up.
  final Duration sessionTimeout;

  /// How often to poll the verify endpoint.
  final Duration pollInterval;

  const BondifyConfig({
    required this.projectId,
    this.apiBase = 'https://api.bondify.dev',
    this.sessionTimeout = const Duration(minutes: 10),
    this.pollInterval = const Duration(seconds: 2),
  });
}

/// Thrown when authentication fails (network, timeout, cancelled, expired…).
class BondifyException implements Exception {
  final String message;
  final BondifyStatus? status;
  BondifyException(this.message, {this.status});
  @override
  String toString() => 'BondifyException: $message';
}

/// A cancellation handle for an in-flight authentication.
class BondifyCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
