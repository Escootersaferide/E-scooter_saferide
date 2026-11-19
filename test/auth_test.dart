import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saferide/auth_service.dart';
import 'package:saferide/main.dart';
import 'package:saferide/session_storage.dart';

http.Response _jsonResponse(Map<String, Object?> body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('Validators accept valid email, phone, and password', () {
    expect(validateEmail('rider@scoot.ru'), isNull);
    expect(validateEmail('invalid'), isNotNull);

    expect(validatePhone('+7 (999) 123-45-67'), isNull);
    expect(validatePhone('8 999 123 45 67'), isNull);
    expect(validatePhone('12345'), isNotNull);

    expect(validatePassword('StrongPass123'), isNull);
    expect(validatePassword('short'), isNotNull);
  });

  testWidgets('User can register, stay signed in after reload, and log out', (
    tester,
  ) async {
    var logoutCalled = false;
    var meCalls = 0;
    final storage = MemorySessionStorage();
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/auth/register') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['email'], 'dmitrii@scoot.ru');
        expect(payload['phone'], '+7 (999) 123-45-67');
        expect(payload['password'], 'SecretPass123');
        return _jsonResponse({
          'token': 'test-token-123',
          'user': {
            'id': 1,
            'email': 'dmitrii@scoot.ru',
            'phone': '+79991234567',
            'created_at': '2026-11-19T10:00:00Z',
          },
        }, status: 201);
      }
      if (request.url.path == '/api/auth/me') {
        expect(request.headers['Authorization'], 'Bearer test-token-123');
        meCalls++;
        return _jsonResponse({
          'user': {
            'id': 1,
            'email': 'dmitrii@scoot.ru',
            'phone': '+79991234567',
            'created_at': '2026-11-19T10:00:00Z',
          },
        });
      }
      if (request.url.path == '/api/auth/logout') {
        expect(request.headers['Authorization'], 'Bearer test-token-123');
        logoutCalled = true;
        return _jsonResponse({'ok': true});
      }
      return _jsonResponse({'error': 'Not found'}, status: 404);
    });
    final service = AuthService(
      baseUrl: 'http://127.0.0.1:8000',
      client: mockClient,
    );

    await tester.pumpWidget(
      ScootApp(
        key: const ValueKey('first_mount'),
        authService: service,
        sessionStorage: storage,
      ),
    );
    await tester.ensureVisible(find.text('Войти или зарегистрироваться'));
    await tester.tap(find.text('Войти или зарегистрироваться'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth_email_field')),
      'dmitrii@scoot.ru',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_phone_field')),
      '+7 (999) 123-45-67',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      'SecretPass123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_confirm_password_field')),
      'SecretPass123',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('auth_submit_button')));
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('dmitrii@scoot.ru'), findsOneWidget);
    expect(find.text('+79991234567'), findsOneWidget);

    // Simulate page reload with a fresh ScootApp backed by the same storage.
    await tester.pumpWidget(
      ScootApp(
        key: const ValueKey('reloaded_mount'),
        authService: service,
        sessionStorage: storage,
      ),
    );
    await tester.pumpAndSettle();

    expect(meCalls, 1);
    expect(find.text('dmitrii@scoot.ru'), findsOneWidget);
    expect(find.text('+79991234567'), findsOneWidget);

    await tester.ensureVisible(find.text('Выйти'));
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
    expect(await storage.load(), isNull);
    expect(find.text('Войти или зарегистрироваться'), findsOneWidget);
  });

  testWidgets('Expired stored session is cleared when /api/auth/me returns 401', (
    tester,
  ) async {
    final storage = MemorySessionStorage(
      const AuthSession(
        token: 'expired-token',
        user: AuthUser(
          id: 1,
          email: 'old@scoot.ru',
          phone: '+79990000000',
          createdAt: '2026-11-19T10:00:00Z',
        ),
      ),
    );
    final mockClient = MockClient((request) async {
      return _jsonResponse({'error': 'Сессия истекла.'}, status: 401);
    });
    final service = AuthService(
      baseUrl: 'http://127.0.0.1:8000',
      client: mockClient,
    );

    await tester.pumpWidget(
      ScootApp(authService: service, sessionStorage: storage),
    );
    await tester.pumpAndSettle();

    expect(await storage.load(), isNull);
    expect(find.text('Войти или зарегистрироваться'), findsOneWidget);
  });

  testWidgets('Login shows backend error message on invalid credentials', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      return _jsonResponse({
        'error': 'Неверный email/телефон или пароль.',
      }, status: 401);
    });
    final service = AuthService(
      baseUrl: 'http://127.0.0.1:8000',
      client: mockClient,
    );

    await tester.pumpWidget(
      ScootApp(authService: service, sessionStorage: MemorySessionStorage()),
    );
    await tester.tap(find.byTooltip('Войти в аккаунт'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth_identifier_field')),
      'dmitrii@scoot.ru',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      'WrongPass123',
    );

    await tester.ensureVisible(find.byKey(const ValueKey('auth_submit_button')));
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Неверный email/телефон или пароль.'), findsOneWidget);
  });

  testWidgets('Tapping the top-left Scoot logo returns to the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScootApp(sessionStorage: MemorySessionStorage()),
    );
    await tester.ensureVisible(find.text('Начать проверку'));
    await tester.tap(find.text('Начать проверку'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Начать'));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.text('Шаг 1 из 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scoot_home_logo')));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в Scoot!'), findsOneWidget);
  });
}
