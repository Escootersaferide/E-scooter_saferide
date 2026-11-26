import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saferide/assessment.dart';
import 'package:saferide/assessment_page.dart';
import 'package:saferide/auth_service.dart';
import 'package:saferide/qualification_intro.dart';
import 'package:saferide/saferide_ui.dart';
import 'package:saferide/traffic_questions.dart';

const crossingQuestion = {
  'category': 'traffic',
  'prompt': 'Как пересечь дорогу на пешеходном переходе?',
  'options': ['Спешиться и перейти пешком', 'Проехать по переходу'],
};
const readinessQuestion = {
  'category': 'readiness',
  'prompt': 'Употребляли ли вы недавно алкоголь?',
  'options': ['Нет', 'Да или не уверен(а)'],
};

Widget assessmentScreen(
  AuthService service,
  DateTime Function() now,
  List<Map<String, Object>> questions,
) => MaterialApp(
  home: AssessmentPage(
    service: service,
    token: 'test-token',
    kind: AssessmentKind.qualification,
    attempt: AssessmentAttempt.fromJson({
      'id': 'test-attempt',
      'min_score': 1,
      'accepts_skipped_answers': true,
      'questions': questions,
    }),
    now: now,
  ),
);

http.Response jsonResponse(Map<String, Object> body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response assessmentResult({required int score}) => jsonResponse({
  'completed_at': '2026-11-26T12:00:00Z',
  'passed': score == 1,
  'readiness_ok': true,
  'score': score,
  'total': 1,
});

Future<void> press(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('A removed question is replaced and graded in its original slot', () {
    const removed = 'Какой знак отмечает пешеходный переход у проезжей части?';
    const existing = TrafficQuestion(
      prompt: 'Как пересечь дорогу на пешеходном переходе?',
      options: ['Спешиться и перейти пешком', 'Проехать по переходу'],
      correctOption: 0,
      explanation: 'Переход нужно пройти пешком, ведя самокат.',
    );
    const replacement = TrafficQuestion(
      prompt: 'Как вести себя рядом с пешеходами?',
      options: ['Увеличить скорость', 'Уступить дорогу'],
      correctOption: 1,
      explanation: 'Пешеходы имеют приоритет.',
    );
    final original = AssessmentAttempt.fromJson({
      'id': 'saved-attempt',
      'min_score': 2,
      'questions': [
        crossingQuestion,
        {
          'category': 'traffic',
          'prompt': removed,
          'options': ['4.4.1', '3.35', '5.19.1 или 5.19.2'],
        },
      ],
    });

    expect(original.needsQuestionReplacement, isTrue);
    final current = original.replaceRemovedQuestions([existing, replacement]);
    expect(current.needsQuestionReplacement, isFalse);
    expect(current.id, original.id);
    expect(current.minScore, original.minScore);
    expect(current.questions.map((q) => q.prompt), [
      existing.prompt,
      replacement.prompt,
    ]);
    final updated = current.questions.last;
    expect(updated.answerForServer(1), 2);
    expect(updated.answerForServer(0), 0);
    expect(updated.answerForServer(null), isNull);
    expect(updated.answerForServer(updated.legacyIncorrectOption({})), 0);
  });

  testWidgets('A confirmation exactly at 20 seconds counts as a skip', (
    tester,
  ) async {
    final submissions = <Object?>[];
    final service = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/rides/submit');
        submissions.add(jsonDecode(request.body)['answers']);
        return assessmentResult(score: 0);
      }),
    );
    addTearDown(service.close);
    var now = DateTime.utc(2026, 11, 26);
    await tester.pumpWidget(
      assessmentScreen(service, () => now, [crossingQuestion]),
    );
    await press(tester, 'Спешиться и перейти пешком');

    // Tap the still-visible button before the next clock update.
    now = now.add(const Duration(seconds: 20));
    await press(tester, 'Завершить тест');

    expect(submissions, [
      [null],
    ]);
    expect(find.text('Пропущено по времени — 1'), findsOneWidget);
    expect(find.text('Большой тест пока не пройден'), findsOneWidget);
  });

  testWidgets('Editing an earlier answer preserves the next deadline', (
    tester,
  ) async {
    final submissions = <Object?>[];
    final service = AuthService(
      client: MockClient((request) async {
        submissions.add(jsonDecode(request.body)['answers']);
        return assessmentResult(score: 1);
      }),
    );
    addTearDown(service.close);
    var now = DateTime.utc(2026, 11, 26);
    await tester.pumpWidget(
      assessmentScreen(service, () => now, [
        readinessQuestion,
        crossingQuestion,
      ]),
    );

    now = now.add(const Duration(seconds: 5));
    await press(tester, 'Да или не уверен(а)');
    await press(tester, 'Продолжить');
    expect(find.text('На вопрос · 20 с'), findsOneWidget);
    now = now.add(const Duration(seconds: 9));
    await press(tester, 'Предыдущий вопрос');
    expect(find.text('На вопрос · 6 с'), findsOneWidget);
    await press(tester, 'Нет');
    await press(tester, 'Продолжить');
    expect(find.text('На вопрос · 11 с'), findsOneWidget);
    await press(tester, 'Спешиться и перейти пешком');

    // A confirmation just before the deadline still counts.
    now = now.add(const Duration(seconds: 10, milliseconds: 999));
    await press(tester, 'Завершить тест');

    expect(submissions, [
      [0, 0],
    ]);
    expect(find.text('Большой тест пройден'), findsOneWidget);
  });

  testWidgets('A retry sends the same answers once after a server error', (
    tester,
  ) async {
    final submissions = <Object?>[];
    final pending = Completer<http.Response>();
    final service = AuthService(
      client: MockClient((request) async {
        submissions.add(jsonDecode(request.body));
        if (submissions.length == 1) {
          return jsonResponse({
            'error': 'Сервер временно недоступен.',
          }, status: 503);
        }
        return pending.future;
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      assessmentScreen(service, () => DateTime.utc(2026, 11, 26), [
        crossingQuestion,
      ]),
    );
    await press(tester, 'Спешиться и перейти пешком');
    await press(tester, 'Завершить тест');
    expect(find.text('Сервер временно недоступен.'), findsOneWidget);

    final retry = find.text('Отправить ещё раз');
    await tester.tap(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(submissions, [
      {
        'id': 'test-attempt',
        'answers': [0],
      },
      {
        'id': 'test-attempt',
        'answers': [0],
      },
    ]);

    pending.complete(assessmentResult(score: 1));
    await tester.pumpAndSettle();
    expect(find.text('Большой тест пройден'), findsOneWidget);
    expect(find.text('Отправить ещё раз'), findsNothing);
  });

  testWidgets('The test start button works on a narrow screen in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: saferideTheme(brightness),
          home: SaferideScaffold(
            child: QualificationIntro(onStart: () => starts++, starting: false),
          ),
        ),
      );
      expect(find.text('20 секунд на вопрос'), findsOneWidget);
      await press(tester, 'Пройти большой тест');
      expect(tester.takeException(), isNull);
    }
    expect(starts, 2);
  });
}
