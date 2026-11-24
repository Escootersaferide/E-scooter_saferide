import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'saferide_ui.dart';
import 'traffic_questions.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.section,
    required this.number,
    required this.count,
    required this.prompt,
    this.illustration,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.nextLabel,
    required this.onNext,
  });

  final String section;
  final int number;
  final int count;
  final String prompt;
  final QuestionIllustration? illustration;
  final List<String> options;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final String nextLabel;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SaferideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                section,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Вопрос $number из $count',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            headingLevel: 2,
            child: Text(
              prompt,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (illustration case final image?) ...[
            const SizedBox(height: 16),
            Center(
              child: SvgPicture.asset(
                image.asset,
                width: 136,
                height: 86,
                semanticsLabel: image.alt,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          RadioGroup<int>(
            groupValue: selected,
            onChanged: onSelect,
            child: Column(
              children: [
                for (final (index, option) in options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RadioListTile<int>(
                      value: index,
                      selected: selected == index,
                      activeColor: colors.primary,
                      selectedTileColor: colors.primaryContainer,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: selected == index
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(onPressed: onNext, child: Text(nextLabel)),
        ],
      ),
    );
  }
}
