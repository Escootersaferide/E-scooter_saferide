import 'package:material_ui/material_ui.dart';

import 'ride_check.dart';
import 'saferide_ui.dart';
import 'traffic_questions.dart';

class ComprehensiveCheckPage extends StatelessWidget {
  const ComprehensiveCheckPage({super.key, this.trafficBank});

  final List<TrafficQuestion>? trafficBank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SaferideScaffold(
      child: SaferideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.assignment_outlined, size: 42),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Комплексная проверка',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Оцените самочувствие, пройдите тест по правилам для '
              'электросамокатов и посмотрите рекомендации перед поездкой. '
              'На ответы отводится 7 минут.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Для зачёта по ПДД нужно набрать $trafficPassScore из '
              '$trafficQuestionCount. Если ответы укажут на риск, '
              'saferide порекомендует отложить поездку независимо от балла.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final bank = trafficBank ?? await loadTrafficQuestions();
                if (!context.mounted) return;
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideCheckPage(trafficBank: bank),
                  ),
                );
              },
              child: const Text('Начать'),
            ),
          ],
        ),
      ),
    );
  }
}
