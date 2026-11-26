import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saferide/assessment.dart';
import 'package:saferide/assessment_page.dart';
import 'package:saferide/auth_service.dart';
import 'package:saferide/main.dart';
import 'package:saferide/session_storage.dart';
import 'package:saferide/traffic_questions.dart';

http.Response _jsonResponse(Map<String, Object?> body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('Validators accept valid email, phone, and password', () {
    expect(validateEmail('rider@saferide.ru'), isNull);
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
        expect(payload['email'], 'dmitrii@saferide.ru');
        expect(payload['phone'], '+7 (999) 123-45-67');
        expect(payload['password'], 'SecretPass123');
        return _jsonResponse({
          'token': 'test-token-123',
          'user': {
            'id': 1,
            'email': 'dmitrii@saferide.ru',
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
            'email': 'dmitrii@saferide.ru',
            'phone': '+79991234567',
            'created_at': '2026-11-19T10:00:00Z',
          },
        });
      }
      if (request.url.path == '/api/rides') {
        expect(request.headers['Authorization'], 'Bearer test-token-123');
        return _jsonResponse({
          'qualified_at': null,
          'retry_after_seconds': 0,
          'history': [],
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
      SaferideApp(
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
      'dmitrii@saferide.ru',
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

    await tester.ensureVisible(
      find.byKey(const ValueKey('auth_submit_button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('dmitrii@saferide.ru'), findsOneWidget);
    expect(find.text('+79991234567'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    // Simulate page reload with a fresh SaferideApp backed by the same storage.
    await tester.pumpWidget(
      SaferideApp(
        key: const ValueKey('reloaded_mount'),
        authService: service,
        sessionStorage: storage,
      ),
    );
    await tester.pumpAndSettle();

    expect(meCalls, 1);
    await tester.tap(find.byTooltip('Профиль'));
    await tester.pumpAndSettle();
    expect(find.text('dmitrii@saferide.ru'), findsOneWidget);
    expect(find.text('+79991234567'), findsOneWidget);

    await tester.ensureVisible(find.text('Выйти'));
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();

    expect(logoutCalled, isTrue);
    expect(await storage.load(), isNull);
    expect(find.text('Войти или зарегистрироваться'), findsOneWidget);
  });

  testWidgets(
    'Expired stored session is cleared when /api/auth/me returns 401',
    (tester) async {
      final storage = MemorySessionStorage(
        const AuthSession(
          token: 'expired-token',
          user: AuthUser(
            id: 1,
            email: 'old@saferide.ru',
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
        SaferideApp(authService: service, sessionStorage: storage),
      );
      await tester.pumpAndSettle();

      expect(await storage.load(), isNull);
      expect(find.text('Войти или зарегистрироваться'), findsOneWidget);
    },
  );

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
      SaferideApp(authService: service, sessionStorage: MemorySessionStorage()),
    );
    await tester.tap(find.byTooltip('Войти в аккаунт'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('auth_identifier_field')),
      'dmitrii@saferide.ru',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      'WrongPass123',
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('auth_submit_button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Неверный email/телефон или пароль.'), findsOneWidget);
  });

  testWidgets(
    'Qualification unlocks the menu and failed orders show cooldown and history',
    (tester) async {
      const user = AuthUser(
        id: 2,
        email: 'rider@example.test',
        phone: '+79990000001',
        createdAt: '2026-11-19T10:00:00Z',
      );
      var qualified = false;
      var failedOrder = false;
      const failed = {
        'completed_at': '2026-11-19T10:02:00Z',
        'passed': false,
        'readiness_ok': true,
        'score': 3,
        'total': 5,
      };
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer rider-token');
        switch (request.url.path) {
          case '/api/auth/me':
            return _jsonResponse({'user': user.toJson()});
          case '/api/rides':
            return _jsonResponse({
              'qualified_at': qualified ? '2026-11-19T10:01:00Z' : null,
              'retry_after_seconds': failedOrder ? 300 : 0,
              'history': failedOrder ? [failed] : [],
            });
          case '/api/rides/start':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['kind'], qualified ? 'order' : 'qualification');
            return _jsonResponse({
              'id': body['kind'],
              'min_score': qualified ? 5 : 16,
              'questions': [
                {
                  'category': 'traffic',
                  'prompt': 'Кто имеет приоритет?',
                  'options': ['Пешеход', 'Самокатчик'],
                },
              ],
            });
          case '/api/rides/submit':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['answers'], [0]);
            if (body['id'] == 'qualification') {
              qualified = true;
              return _jsonResponse({
                'completed_at': '2026-11-19T10:01:00Z',
                'passed': true,
                'readiness_ok': true,
                'score': 16,
                'total': 20,
              });
            }
            expect(body['id'], 'order');
            failedOrder = true;
            return _jsonResponse(failed);
        }
        return _jsonResponse({'error': 'Not found'}, status: 404);
      });
      await tester.pumpWidget(
        SaferideApp(
          authService: AuthService(client: client),
          sessionStorage: MemorySessionStorage(
            const AuthSession(token: 'rider-token', user: user),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.text('Заказать самокат'), findsNothing);
      expect(find.text('20 секунд на вопрос'), findsOneWidget);
      await tap(find.text('Пройти большой тест'));
      await tap(find.text('Пешеход'));
      await tap(find.text('Завершить тест'));
      expect(find.text('Большой тест пройден'), findsOneWidget);
      await tap(find.text('К меню поездок'));
      expect(find.text('Меню поездок'), findsOneWidget);
      await tap(find.text('Заказать самокат'));
      await tap(find.text('Пешеход'));
      await tap(find.text('Завершить тест'));
      expect(find.textContaining('через 5 минут'), findsOneWidget);
      await tap(find.text('К меню поездок'));
      expect(find.textContaining('Следующая попытка через'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tap(find.text('История заказов'));
      expect(find.text('Тест не пройден'), findsOneWidget);
      expect(find.text('3 из 5'), findsOneWidget);
    },
  );

  for (final acceptsSkippedAnswers in [true, false]) {
    testWidgets(
      'Question deadlines survive back navigation (skip support: $acceptsSkippedAnswers)',
      (tester) async {
        final submissions = <List<dynamic>>[];
        const traffic = {
          'prompt':
              'Как пересечь дорогу по пешеходному переходу с электросамокатом?',
          'options': [
            'Проехать медленно',
            'Спешиться и перейти пешком',
            'Проехать по сигналу',
          ],
          'correct_option': 1,
          'explanation': 'Переход пройдите пешком.',
        };
        if (!acceptsSkippedAnswers) {
          final messenger = tester.binding.defaultBinaryMessenger;
          rootBundle.evict(trafficQuestionAsset);
          messenger.setMockMessageHandler('flutter/assets', (message) async {
            final path = utf8.decode(message!.buffer.asUint8List());
            return path == trafficQuestionAsset
                ? ByteData.sublistView(utf8.encode(jsonEncode([traffic])))
                : null;
          });
          addTearDown(() {
            rootBundle.evict(trafficQuestionAsset);
            messenger.setMockMessageHandler('flutter/assets', null);
          });
        }
        final service = AuthService(
          client: MockClient((request) async {
            expect(request.url.path, '/api/rides/submit');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            submissions.add(body['answers'] as List);
            return _jsonResponse({
              'completed_at': '2026-11-26T12:00:00Z',
              'passed': false,
              'readiness_ok': true,
              'score': 0,
              'total': 2,
            });
          }),
        );
        addTearDown(service.close);
        var now = DateTime.utc(2026, 11, 26);

        Future<void> press(String label) async {
          final target = find.text(label);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        Future<void> elapse(int seconds) async {
          now = now.add(Duration(seconds: seconds));
          await tester.pump(const Duration(milliseconds: 250));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: AssessmentPage(
              service: service,
              token: 'rider-token',
              kind: acceptsSkippedAnswers
                  ? AssessmentKind.qualification
                  : AssessmentKind.order,
              attempt: AssessmentAttempt.fromJson({
                'id': 'pending-test',
                'min_score': 2,
                if (acceptsSkippedAnswers) 'accepts_skipped_answers': true,
                'questions': [
                  {
                    'category': 'readiness',
                    'prompt': 'Может ли недавно употреблённый алкоголь сейчас влиять на вашу реакцию?',
                    'options': ['Нет', 'Да или не уверен(а)'],
                  },
                  {
                    'category': 'traffic',
                    'prompt': traffic['prompt'],
                    'options': traffic['options'],
                  },
                  {
                    'category': 'general',
                    'prompt': 'Что делать, если вы заметили неисправность тормозов во время поездки?',
                    'options': [
                      'Продолжить поездку на низкой скорости',
                      'Доехать до места назначения и сообщить потом',
                      'Безопасно остановиться и сообщить о неисправности',
                    ],
                  },
                ],
              }),
              now: () => now,
            ),
          ),
        );
        expect(find.text('На вопрос · 20 с'), findsOneWidget);
        expect(
          find.text('Употребляли ли вы недавно алкоголь?'),
          findsOneWidget,
        );
        await elapse(10);
        await press('Нет');
        await press('Продолжить');
        expect(find.text('Вопрос 2 из 3'), findsOneWidget);
        expect(find.text('На вопрос · 20 с'), findsOneWidget);

        await elapse(4);
        await press('Предыдущий вопрос');
        expect(find.text('На вопрос · 6 с'), findsOneWidget);
        await elapse(7);
        expect(find.text('Ответ сохранён'), findsOneWidget);
        expect(
          tester
              .widget<RadioListTile<int>>(find.byType(RadioListTile<int>).last)
              .enabled,
          isFalse,
        );
        await press('Продолжить');
        expect(find.text('Вопрос 2 из 3'), findsOneWidget);
        expect(find.text('На вопрос · 9 с'), findsOneWidget);

        // An unconfirmed selection expires while the first question is open.
        await press('Спешиться и перейти пешком');
        await press('Предыдущий вопрос');
        await elapse(9);
        await press('Продолжить');
        expect(find.text('Вопрос 3 из 3'), findsOneWidget);
        expect(find.text('На вопрос · 20 с'), findsOneWidget);
        expect(submissions, isEmpty);

        // The final timeout submits the attempt without an extra button press.
        await elapse(20);
        expect(submissions, [
          [
            0,
            if (acceptsSkippedAnswers) null else 0,
            if (acceptsSkippedAnswers) null else 0,
          ],
        ]);
        expect(find.text('Пропущено по времени — 2'), findsOneWidget);
      },
    );
  }

  testWidgets('Tapping the top-left Saferide logo returns to the home screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      SaferideApp(sessionStorage: MemorySessionStorage()),
    );
    await tester.tap(find.byTooltip('Войти в аккаунт'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth_identifier_field')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('saferide_home_logo')));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в saferide!'), findsOneWidget);
  });
}
