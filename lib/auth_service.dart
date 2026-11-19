import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'assessment.dart';

const defaultSaferideApiUrl = String.fromEnvironment(
  'SAFERIDE_API_URL',
  defaultValue: String.fromEnvironment(
    'SCOOT_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  ),
);

const minPasswordLength = 8;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phoneAllowedPattern = RegExp(r'^[+\d\s()\-]+$');
final _nonDigitPattern = RegExp(r'\D');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty || email.length > 254 || !_emailPattern.hasMatch(email)) {
    return 'Укажите корректный email.';
  }
  return null;
}

String? validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty || !_phoneAllowedPattern.hasMatch(phone)) {
    return 'Укажите корректный номер телефона.';
  }
  final digits = phone.replaceAll(_nonDigitPattern, '');
  if (digits.length < 10 || digits.length > 15) {
    return 'Номер телефона должен содержать от 10 до 15 цифр.';
  }
  return null;
}

String? validateIdentifier(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return 'Укажите email или номер телефона.';
  }
  return raw.contains('@') ? validateEmail(raw) : validatePhone(raw);
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < minPasswordLength) {
    return 'Пароль должен содержать не менее $minPasswordLength символов.';
  }
  if (password.trim().isEmpty) {
    return 'Пароль не может состоять только из пробелов.';
  }
  return null;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      phone: json['phone'] as String,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final int id;
  final String email;
  final String phone;
  final String createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'created_at': createdAt,
  };
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String token;
  final AuthUser user;

  Map<String, Object?> toJson() => {'token': token, 'user': user.toJson()};
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    String baseUrl = defaultSaferideApiUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  Future<AuthSession> register({
    required String email,
    required String phone,
    required String password,
  }) async {
    final json = await _post(
      '/api/auth/register',
      body: {
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      },
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final json = await _post(
      '/api/auth/login',
      body: {'identifier': identifier.trim(), 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthUser> fetchCurrentUser(String token) async {
    final json = await _get('/api/auth/me', token: token);
    return AuthUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await _post('/api/auth/logout', body: const {}, token: token);
  }

  Future<RideOverview> rideOverview(String token) async =>
      RideOverview.fromJson(await _get('/api/rides', token: token));

  Future<AssessmentAttempt> startAssessment(
    String token,
    AssessmentKind kind,
  ) async => AssessmentAttempt.fromJson(
    await _post('/api/rides/start', token: token, body: {'kind': kind.name}),
  );

  Future<AssessmentResult> submitAssessment(
    String token,
    String id,
    List<int> answers,
  ) async => AssessmentResult.fromJson(
    await _post(
      '/api/rides/submit',
      token: token,
      body: {'id': id, 'answers': answers},
    ),
  );

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
          .timeout(timeout);
      return _parseResponse(response);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Сервер не ответил вовремя. Проверьте соединение и повторите попытку.',
      );
    } on Exception {
      throw const AuthException(
        'Не удалось подключиться к серверу. Убедитесь, что backend запущен.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token, withJson: true),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parseResponse(response);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Сервер не ответил вовремя. Проверьте соединение и повторите попытку.',
      );
    } on Exception {
      throw const AuthException(
        'Не удалось подключиться к серверу. Убедитесь, что backend запущен.',
      );
    }
  }

  Map<String, String> _headers({String? token, bool withJson = false}) {
    return {
      if (withJson) 'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final raw = utf8.decode(response.bodyBytes);
    Map<String, dynamic> data = const {};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } on FormatException {
        throw AuthException(
          'Сервер вернул некорректный ответ.',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = data['error'] as String?;
      throw AuthException(
        serverMessage ?? 'Ошибка сервера (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return data;
  }
}
