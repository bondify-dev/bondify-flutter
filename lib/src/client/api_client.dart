// ============================================================
//  bondify_flutter — BondifyApiClient
//  Типизированный HTTP-клиент
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class GenerateResponse {
  final String deeplink;
  final String sessionToken;
  final DateTime expiresAt;

  const GenerateResponse({
    required this.deeplink,
    required this.sessionToken,
    required this.expiresAt,
  });

  factory GenerateResponse.fromJson(Map<String, dynamic> json) {
    return GenerateResponse(
      deeplink:     json['deeplink']      as String,
      sessionToken: json['session_token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expires_at'] as int),
    );
  }
}

class VerifyResponse {
  final String status;
  final String? telegramId;
  final String? telegramName;
  final String? telegramUsername;
  final String? telegramPhone;
  final String? proof;
  final int? confirmedAt;
  final int? cancelledAt;

  const VerifyResponse({
    required this.status,
    this.telegramId,
    this.telegramName,
    this.telegramUsername,
    this.telegramPhone,
    this.proof,
    this.confirmedAt,
    this.cancelledAt,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      status:           json['status']             as String,
      telegramId:       json['telegram_id']        as String?,
      telegramName:     json['telegram_name']      as String?,
      telegramUsername: json['telegram_username']  as String?,
      telegramPhone:    json['telegram_phone']     as String?,
      proof:            json['proof']              as String?,
      confirmedAt:      json['confirmed_at']       as int?,
      cancelledAt:      json['cancelled_at']       as int?,
    );
  }
}

class BondifyApiClient {
  final String apiUrl;
  final String projectId;
  final http.Client _httpClient;

  BondifyApiClient({
    required this.apiUrl,
    required this.projectId,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ── Генерация сессии ────────────────────────────────────────────────────
  Future<GenerateResponse> generateSession() async {
    return _post<GenerateResponse>(
      path:    '/api/v1/generate/public',
      body:    {'project_id': projectId},
      fromJson: GenerateResponse.fromJson,
    );
  }

  // ── Верификация сессии ──────────────────────────────────────────────────
  Future<VerifyResponse> verifySession(String sessionToken) async {
    return _post<VerifyResponse>(
      path: '/api/v1/verify/public',
      body: {
        'project_id':    projectId,
        'session_token': sessionToken,
      },
      fromJson: VerifyResponse.fromJson,
    );
  }

  // ── Приватный хелпер POST ───────────────────────────────────────────────
  Future<T> _post<T>({
    required String path,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final uri = Uri.parse('$apiUrl$path');

    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw BondifyException(
        code:    BondifyErrorCode.networkError,
        message: 'Сетевая ошибка: $e',
        details: e,
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw BondifyException(
        code:    BondifyErrorCode.unknownError,
        message: 'Некорректный JSON-ответ (${response.statusCode})',
      );
    }

    if (response.statusCode != 200) {
      throw BondifyException(
        code:    _resolveErrorCode(data['code'] as String?, response.statusCode),
        message: data['error']?.toString() ?? 'HTTP ${response.statusCode}',
        details: data,
      );
    }

    return fromJson(data);
  }

  // API возвращает машиночитаемый `code` в теле большинства ошибок (см.
  // раздел Errors в REST API reference) — несколько разных причин отказа
  // могут иметь один и тот же HTTP-статус (например, 403 покрывает и
  // PUBLIC_ACCESS_DISABLED, и PROJECT_INACTIVE), поэтому `code` — источник
  // истины, когда он есть. Маппинг по статусу ниже — только запасной
  // вариант для ответа без `code`.
  BondifyErrorCode _resolveErrorCode(String? code, int status) {
    final fromApi = _codeFromApiString(code);
    return fromApi ?? _mapStatusCode(status);
  }

  BondifyErrorCode? _codeFromApiString(String? code) {
    return switch (code) {
      'SESSION_EXPIRED'         => BondifyErrorCode.sessionExpired,
      'SESSION_CANCELLED'       => BondifyErrorCode.sessionCancelled,
      'NETWORK_ERROR'           => BondifyErrorCode.networkError,
      'PROJECT_NOT_FOUND'       => BondifyErrorCode.projectNotFound,
      'PROJECT_INACTIVE'        => BondifyErrorCode.projectInactive,
      'PUBLIC_ACCESS_DISABLED'  => BondifyErrorCode.publicAccessDisabled,
      'RATE_LIMITED'            => BondifyErrorCode.rateLimited,
      'POLLING_TIMEOUT'         => BondifyErrorCode.pollingTimeout,
      'UNKNOWN_ERROR'           => BondifyErrorCode.unknownError,
      _                         => null,
    };
  }

  BondifyErrorCode _mapStatusCode(int status) {
    return switch (status) {
      404 => BondifyErrorCode.projectNotFound,
      403 => BondifyErrorCode.publicAccessDisabled,
      429 => BondifyErrorCode.rateLimited,
      _   => BondifyErrorCode.unknownError,
    };
  }

  void dispose() => _httpClient.close();
}
