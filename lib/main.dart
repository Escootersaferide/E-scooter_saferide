import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_page.dart';
import 'auth_service.dart';
import 'complex_check.dart';
import 'feeling.dart';
import 'scoot_ui.dart';
import 'session_storage.dart';
import 'traffic_questions.dart';

const _authEnabled = bool.fromEnvironment(
  'SCOOT_AUTH_ENABLED',
  defaultValue: true,
);

void main() {
  runApp(const ScootApp());
}

class ScootApp extends StatefulWidget {
  const ScootApp({super.key, this.authService, this.sessionStorage});

  final AuthService? authService;
  final SessionStorage? sessionStorage;

  @override
  State<ScootApp> createState() => _ScootAppState();
}

class _ScootAppState extends State<ScootApp> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final SessionStorage _sessionStorage =
      widget.sessionStorage ?? createSessionStorage();
  ThemeMode _themeMode = ThemeMode.system;
  AuthSession? _session;

  @override
  void initState() {
    super.initState();
    if (_authEnabled) {
      _restoreSession();
    }
  }

  @override
  void dispose() {
    if (widget.authService == null) {
      _authService.close();
    }
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final saved = await _sessionStorage.load();
    if (saved == null || !mounted) return;
    setState(() => _session = saved);
    try {
      final freshUser = await _authService.fetchCurrentUser(saved.token);
      if (!mounted || _session?.token != saved.token) return;
      final refreshed = AuthSession(token: saved.token, user: freshUser);
      setState(() => _session = refreshed);
      await _sessionStorage.save(refreshed);
    } on AuthException catch (error) {
      if (error.statusCode == 401) {
        if (!mounted || _session?.token != saved.token) return;
        setState(() => _session = null);
        await _sessionStorage.clear();
      }
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    setState(() => _session = session);
    await _sessionStorage.save(session);
  }

  Future<void> _logout() async {
    final token = _session?.token;
    setState(() => _session = null);
    await _sessionStorage.clear();
    if (token != null) {
      try {
        await _authService.logout(token);
      } on AuthException {
        // Local session is cleared even if the server is temporarily unreachable.
      }
    }
  }

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
        authService: _authService,
        session: _session,
        onSessionChanged: _saveSession,
        onLogout: _logout,
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.authService,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final ValueChanged<ThemeMode> onThemeChanged;
  final AuthService authService;
  final AuthSession? session;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;

  Future<void> _openAuth(BuildContext context, AuthMode initialMode) async {
    final result = await Navigator.push<AuthSession>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AuthPage(authService: authService, initialMode: initialMode),
      ),
    );
    if (result != null) {
      onSessionChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final user = session?.user;

    return ScootScaffold(
      actions: [
        if (_authEnabled && user == null)
          IconButton(
            onPressed: () => _openAuth(context, AuthMode.login),
            tooltip: 'Войти в аккаунт',
            icon: const Icon(Icons.person_outline_rounded),
          ),
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
            _WelcomeIllustration(dark: dark),
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
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: colors.primary),
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
            if (_authEnabled) const SizedBox(height: 12),
            if (_authEnabled && user == null)
              OutlinedButton.icon(
                onPressed: () => _openAuth(context, AuthMode.register),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Войти или зарегистрироваться'),
              )
            else if (user != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              user.phone,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onLogout,
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: AspectRatio(
          aspectRatio: 1072 / 818.65033,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, 0.08, 0.92, 1],
            ).createShader(bounds),
            child: SvgPicture.asset(
              'assets/svg/main.svg',
              colorMapper: dark
                  ? const _WelcomeIllustrationColors(dark: true)
                  : const _WelcomeIllustrationColors(dark: false),
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeIllustrationColors extends ColorMapper {
  const _WelcomeIllustrationColors({required this.dark});

  final bool dark;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (attributeName != 'fill') return color;
    // The exported artwork has separate white canvas and ground paths.
    if (id == 'path1' || id == 'path4') return Colors.transparent;
    if (!dark) return color;

    return switch (id) {
      // The vector wordmark includes two background-colored counters.
      'path154' ||
      'path156' ||
      'path158' ||
      'path159' ||
      'path160' => const Color(0xFFDCEFE9),
      'path155' || 'path157' => scootDarkCardColor,
      'path32' || 'path151' => color,
      'path42' || 'path62' => const Color(0xFF2D7563),
      'path43' || 'path63' || 'path65' => const Color(0xFF286050),
      'path44' => const Color(0xFF205448),
      _ => switch (color.toARGB32()) {
        0xFFFFFFFF => const Color(0xFF416159),
        0xFFD3F4F6 => const Color(0xFF33544E),
        0xFFB7EAE8 => const Color(0xFF3C5F59),
        0xFFA1E0DB => const Color(0xFF3A665F),
        0xFFDBF5F7 => const Color(0xFF2B4945),
        _ => color,
      },
    };
  }
}
