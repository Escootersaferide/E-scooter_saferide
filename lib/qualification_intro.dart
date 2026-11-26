import 'package:material_ui/material_ui.dart';

import 'scooter_illustration.dart';
import 'timed_questions.dart';

class QualificationIntro extends StatelessWidget {
  const QualificationIntro({
    super.key,
    required this.onStart,
    required this.starting,
  });

  final VoidCallback? onStart;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          final artwork = Container(
            height: wide ? null : 210,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.95),
                radius: 1.35,
                colors: [colors.primaryContainer, colors.surfaceContainerLow],
              ),
            ),
            child: ScooterIllustration(maxHeight: wide ? 295 : 220),
          );
          final content = Padding(
            padding: EdgeInsets.fromLTRB(20, wide ? 24 : 4, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  headingLevel: 1,
                  child: Text(
                    'Безопасные поездки начинаются с проверки',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Чтобы открыть меню поездок, подтвердите готовность и наберите 16 из 20 по ПДД.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                const _IntroDetail(
                  icon: Icons.shield_outlined,
                  text: '20 вопросов по ПДД',
                ),
                const SizedBox(height: 7),
                const _IntroDetail(
                  icon: Icons.favorite_border_rounded,
                  text: '4 вопроса о самочувствии',
                ),
                const SizedBox(height: 7),
                _IntroDetail(
                  icon: Icons.timer_outlined,
                  text: '${questionTimeLimit.inSeconds} секунд на вопрос',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          starting ? 'Открываем тест…' : 'Пройти большой тест',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          );
          return wide
              ? Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth / 2,
                      child: artwork,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: constraints.maxWidth / 2,
                        child: content,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [artwork, content],
                );
        },
      ),
    );
  }
}

class _IntroDetail extends StatelessWidget {
  const _IntroDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
