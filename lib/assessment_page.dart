import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'assessment.dart';
import 'auth_service.dart';
import 'question_card.dart';
import 'saferide_ui.dart';
import 'timed_questions.dart';
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
  late final TimedQuestions _questions;
  late final _bundledTraffic = _loadBundledTraffic();
  bool _submitting = false;
  AuthException? _submissionError;
  AssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    _questions = TimedQuestions(
      widget.attempt.questions.length,
      now: widget.now,
    )..addListener(_updateClock);
  }

  Future<Map<String, TrafficQuestion>> _loadBundledTraffic() async {
    try {
      return {
        for (final question in await loadTrafficQuestions())
          question.prompt: question,
      };
    } on Object {
      return const {};
    }
  }

  void _updateClock() {
    if (ModalRoute.isCurrentOf(context) == false) return;
    final index = _questions.index;
    if (_questions.advanceIfTimedOut()) {
      _afterAdvance(index);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  void _next(int index) {
    if (_questions.index == index && _questions.advance()) {
      _afterAdvance(index);
    }
  }

  void _afterAdvance(int index) {
    if (_questions.answers[index] == null || _questions.index > index + 1) {
      showQuestionTimeout(context);
    }
    setState(() {});
    if (_questions.finished) unawaited(_submit());
  }

  Future<void> _submit() async {
    if (_submitting || !_questions.finished) return;
    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      final answers = _questions.answers;
      if (!widget.attempt.acceptsSkippedAnswers && answers.contains(null)) {
        // Previous APIs need an option index, so encode missing answers using
        // a known incorrect option without changing the displayed selections.
        final bank = await _bundledTraffic;
        for (var i = 0; i < answers.length; i++) {
          if (answers[i] != null) continue;
          final fallback = widget.attempt.questions[i].legacyIncorrectOption(
            bank,
          );
          if (fallback == null) {
            throw const AuthException(
              'Для зачёта пропущенного задания нужно обновить сервер.',
            );
          }
          answers[i] = fallback;
        }
      }
      if (!mounted) return;
      final result = await widget.service.submitAssessment(
        widget.token,
        widget.attempt.id,
        [
          for (final (index, answer) in answers.indexed)
            widget.attempt.questions[index].answerForServer(answer),
        ],
      );
      if (mounted) setState(() => _result = result);
    } on AuthException catch (error) {
      if (mounted) setState(() => _submissionError = error);
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
      final skipped = _questions.answers
          .where((answer) => answer == null)
          .length;
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
              if (skipped > 0) ...[
                const SizedBox(height: 6),
                Text('Пропущено по времени — $skipped'),
              ],
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

    if (_questions.finished) {
      final error = _submissionError;
      final canRetry = error?.statusCode != 404 && error?.statusCode != 410;
      return SaferideScaffold(
        child: SaferideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(error?.message ?? 'Проверяем ответы…'),
              const SizedBox(height: 12),
              if (_submitting)
                const LinearProgressIndicator()
              else
                FilledButton(
                  onPressed: canRetry
                      ? _submit
                      : () => Navigator.of(context).pop(),
                  child: Text(canRetry ? 'Отправить ещё раз' : 'К началу'),
                ),
            ],
          ),
        ),
      );
    }

    final index = _questions.index;
    final question = widget.attempt.questions[index];
    return SaferideScaffold(
      scrollKey: ValueKey(index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isOrder ? 'Короткий тест перед поездкой' : 'Большой тест',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (index + 1) / _questions.count),
          const SizedBox(height: 14),
          FutureBuilder(
            future: widget.attempt.acceptsSkippedAnswers
                ? null
                : _bundledTraffic,
            builder: (context, snapshot) => QuestionCard(
              section: question.section,
              number: index + 1,
              count: _questions.count,
              prompt: question.prompt,
              illustration:
                  question.illustration ??
                  snapshot.data?[question.prompt]?.illustration,
              options: question.options,
              selected: _questions.selected,
              secondsLeft: _questions.secondsLeft,
              skipped: _questions.skipped,
              onSelect: (answer) {
                if (_questions.index == index) {
                  setState(() => _questions.select(answer));
                }
              },
              nextLabel: index + 1 == _questions.count
                  ? 'Завершить тест'
                  : 'Продолжить',
              onNext: _questions.canAdvance ? () => _next(index) : null,
            ),
          ),
          if (index > 0)
            TextButton(
              onPressed: () => setState(_questions.previous),
              child: const Text('Предыдущий вопрос'),
            ),
        ],
      ),
    );
  }
}
