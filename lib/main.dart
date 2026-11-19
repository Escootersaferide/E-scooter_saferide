import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'complex_check.dart';
import 'feeling.dart';
import 'scoot_ui.dart';
import 'traffic_questions.dart';

void main() {
  runApp(const ScootApp());
}

class ScootApp extends StatefulWidget {
  const ScootApp({super.key});

  @override
  State<ScootApp> createState() => _ScootAppState();
}

class _ScootAppState extends State<ScootApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scoot',
      debugShowCheckedModeBanner: false,
      theme: scootTheme(Brightness.light),
      darkTheme: scootTheme(Brightness.dark),
      themeMode: _themeMode,
      home: WelcomeScreen(
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onThemeChanged});

  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return ScootScaffold(
      actions: [
        IconButton(
          onPressed: () =>
              onThemeChanged(dark ? ThemeMode.light : ThemeMode.dark),
          tooltip: dark ? 'Включить светлую тему' : 'Включить тёмную тему',
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
      ],
      child: ScootCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SvgPicture.asset(
              'assets/svg/main.svg',
              height: 220,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 20),
            Text(
              'Добро пожаловать в Scoot!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Оцените своё состояние и проверьте знание ПДД '
              'перед поездкой на электросамокате.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${readinessQuestions.length} вопроса о состоянии '
                    'и $trafficQuestionCount вопросов по ПДД',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ComprehensiveCheckPage(),
                ),
              ),
              child: const Text('Начать проверку'),
            ),
          ],
        ),
      ),
    );
  }
}
