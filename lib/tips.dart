import 'package:material_ui/material_ui.dart';

import 'feeling.dart';
import 'scoot_ui.dart';
import 'traffic_questions.dart';

class RideCheckResult extends StatelessWidget {
  const RideCheckResult({
    super.key,
    required this.readinessAnswers,
    required this.attemptQuestions,
    required this.trafficAnswers,
    required this.onRestart,
    required this.onHome,
  });

  final Iterable<int> readinessAnswers;
  final List<TrafficQuestion> attemptQuestions;
  final Iterable<int> trafficAnswers;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final advice = [
      for (final (index, answer) in readinessAnswers.indexed)
        if (readinessQuestions[index].options[answer].advice
            case final String recommendation)
          recommendation,
    ];
    final mistakes = [
      for (final (index, answer) in trafficAnswers.indexed)
        if (answer != attemptQuestions[index].correctOption)
          (question: attemptQuestions[index], answer: answer),
    ];
    final total = attemptQuestions.length;
    final score = total - mistakes.length;
    final passedTraffic = score >= trafficPassScore;
    final passed = advice.isEmpty && passedTraffic;
    final (title, message, icon) = switch ((advice.isNotEmpty, passedTraffic)) {
      (true, _) => (
        'Отложите поездку',
        'В ваших ответах есть факторы риска. Следуйте рекомендациям ниже.',
        Icons.warning_amber_rounded,
      ),
      (false, false) => (
        'Повторите ПДД',
        'Разберите ошибки и пройдите проверку ещё раз перед поездкой.',
        Icons.menu_book_rounded,
      ),
      (false, true) => (
        'Проверка пройдена',
        'По вашим ответам факторов риска не выявлено. '
            'Соблюдайте ПДД и учитывайте своё самочувствие перед поездкой.',
        Icons.emoji_events_rounded,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScootCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: passed
                    ? colors.primaryContainer
                    : colors.errorContainer,
                foregroundColor: passed
                    ? colors.onPrimaryContainer
                    : colors.onErrorContainer,
                child: Icon(icon, size: 32),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'ПДД · $score из $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Проходной балл — $trafficPassScore из $total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (advice.isNotEmpty) ...[
          const SizedBox(height: 12),
          ScootCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Рекомендации', style: theme.textTheme.titleMedium),
                for (final recommendation in advice)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(recommendation)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (mistakes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: const Text('Разбор ошибок'),
              subtitle: Text('Неверных ответов — ${mistakes.length}'),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              childrenPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                for (final mistake in mistakes) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    mistake.question.prompt,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ваш ответ — ${mistake.question.options[mistake.answer]}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Правильный ответ — '
                    '${mistake.question.options[mistake.question.correctOption]}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mistake.question.explanation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: onRestart, child: const Text('Пройти заново')),
        const SizedBox(height: 4),
        TextButton(onPressed: onHome, child: const Text('На главный экран')),
      ],
    );
  }
}
