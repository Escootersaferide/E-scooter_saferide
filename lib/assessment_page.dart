import 'package:material_ui/material_ui.dart';

import 'assessment.dart';
import 'auth_service.dart';
import 'question_card.dart';
import 'saferide_ui.dart';

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({
    super.key,
    required this.service,
    required this.token,
    required this.kind,
    required this.attempt,
  });

  final AuthService service;
  final String token;
  final AssessmentKind kind;
  final AssessmentAttempt attempt;

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  late final _answers = List<int?>.filled(
    widget.attempt.questions.length,
    null,
  );
  int _index = 0;
  bool _submitting = false;
  String? _error;
  AssessmentResult? _result;

  Future<void> _next() async {
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
      if (mounted) setState(() => _result = result);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
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

    final question = widget.attempt.questions[_index];
    final isLast = _index + 1 == _answers.length;
    return SaferideScaffold(
      scrollKey: ValueKey(_index),
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
          QuestionCard(
            section: question.section,
            number: _index + 1,
            count: _answers.length,
            prompt: question.prompt,
            options: question.options,
            selected: _answers[_index],
            onSelect: (answer) {
              if (!_submitting) setState(() => _answers[_index] = answer);
            },
            nextLabel: _submitting
                ? 'Проверяем ответы…'
                : isLast
                ? 'Завершить тест'
                : 'Продолжить',
            onNext: _answers[_index] == null || _submitting ? null : _next,
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
