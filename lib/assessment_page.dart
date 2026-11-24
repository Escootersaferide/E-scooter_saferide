import 'package:material_ui/material_ui.dart';

import 'assessment.dart';
import 'assessment_timer.dart';
import 'auth_service.dart';
import 'question_card.dart';
import 'saferide_ui.dart';
import 'traffic_questions.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({
    super.key,
    required this.service,
    required this.token,
    required this.kind,
    required this.attempt,
    this.now = DateTime.now,
  });

  final AuthService service;
  final String token;
  final AssessmentKind kind;
  final AssessmentAttempt attempt;
  final DateTime Function() now;

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final AssessmentTimer _timer;
  late final _answers = List<int?>.filled(
    widget.attempt.questions.length,
    null,
  );
  // Older servers omit remaining time and illustrations from the attempt.
  late final _bundledIllustrations = widget.attempt.remainingTime == null
      ? loadTrafficQuestions().then(
          (bank) => {
            for (final question in bank)
              question.prompt: ?question.illustration,
          },
        )
      : null;
  int _index = 0;
  bool _submitting = false;
  String? _error;
  String? _endedTitle;
  AssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    _timer = AssessmentTimer(
      widget.attempt.remainingTime ?? widget.kind.timeLimit,
      now: widget.now,
    )..addListener(_updateTimer);
  }

  void _updateTimer() => setState(() {});

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Future<void> _next(int index) async {
    if (_index != index ||
        _answers[index] == null ||
        _submitting ||
        _endedTitle != null) {
      return;
    }
    if (_timer.expired) {
      _updateTimer();
      return;
    }
    if (_index + 1 < _answers.length) {
      setState(() => _index++);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.service.submitAssessment(
        widget.token,
        widget.attempt.id,
        _answers.cast<int>(),
      );
      if (mounted) {
        _timer.pause();
        setState(() => _result = result);
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _endedTitle = switch (error.statusCode) {
            410 => 'Время вышло',
            404 => 'Попытка больше недоступна',
            _ => null,
          };
          if (_endedTitle != null) _timer.pause();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOrder = widget.kind == AssessmentKind.order;
    final result = _result;
    if (result != null) {
      final title = switch ((isOrder, result.passed)) {
        (true, true) => 'Допуск к поездке получен',
        (true, false) => 'Допуск к поездке пока закрыт',
        (false, true) => 'Большой тест пройден',
        (false, false) => 'Большой тест пока не пройден',
      };
      final message = switch ((isOrder, result.passed, result.readinessOk)) {
        (true, true, _) =>
          'Короткий тест пройден. Результат сохранён в истории.',
        (true, false, false) =>
          'Отложите поездку. Следующая попытка откроется через 5 минут.',
        (true, false, true) => 'Повторите правила безопасности. Следующая попытка откроется через 5 минут.',
        (false, true, _) => 'Теперь вам доступно меню поездок и короткий тест.',
        (false, false, false) =>
          'Отложите поездку и повторите проверку, когда будете готовы.',
        (false, false, true) => 'Повторите ПДД и попробуйте ещё раз.',
      };

      return SaferideScaffold(
        scrollKey: const ValueKey('assessment_result'),
        child: SaferideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                result.passed ? Icons.check_circle_outline : Icons.info_outline,
                size: 44,
                color: result.passed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text(
                'Правильных ответов: ${result.score} из ${result.total}. '
                'Для зачёта нужно ${widget.attempt.minScore}.',
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  isOrder || result.passed ? 'К меню поездок' : 'На главную',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_submitting && (_endedTitle != null || _timer.expired)) {
      return SaferideScaffold(
        scrollKey: const ValueKey('assessment_ended'),
        child: AssessmentEndedCard(
          title: _endedTitle ?? 'Время вышло',
          buttonLabel: isOrder ? 'К меню поездок' : 'На главную',
          onPressed: () => Navigator.of(context).pop(),
        ),
      );
    }

    final index = _index;
    final question = widget.attempt.questions[_index];
    final isLast = _index + 1 == _answers.length;
    return SaferideScaffold(
      scrollKey: ValueKey(_index),
      actions: [AssessmentTimerBadge(secondsLeft: _timer.secondsLeft)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOrder ? 'Короткий тест перед поездкой' : 'Большой тест',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (_index + 1) / _answers.length),
          const SizedBox(height: 14),
          FutureBuilder(
            future: _bundledIllustrations,
            builder: (context, snapshot) => QuestionCard(
              section: question.section,
              number: index + 1,
              count: _answers.length,
              prompt: question.prompt,
              illustration:
                  question.illustration ?? snapshot.data?[question.prompt],
              options: question.options,
              selected: _answers[index],
              onSelect: (answer) {
                if (_index == index && !_submitting && !_timer.expired) {
                  setState(() => _answers[index] = answer);
                }
              },
              nextLabel: _submitting
                  ? 'Проверяем ответы…'
                  : isLast
                  ? 'Завершить тест'
                  : 'Продолжить',
              onNext: _answers[index] == null || _submitting
                  ? null
                  : () => _next(index),
            ),
          ),
          if (_error case final String error)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_index > 0)
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                      _index--;
                      _error = null;
                    }),
              child: const Text('Предыдущий вопрос'),
            ),
        ],
      ),
    );
  }
}
