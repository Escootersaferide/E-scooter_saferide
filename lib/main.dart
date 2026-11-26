import 'package:material_ui/material_ui.dart';

import 'auth_page.dart';
import 'auth_service.dart';
import 'complex_check.dart';
import 'ride_dashboard.dart';
import 'saferide_ui.dart';
import 'scooter_illustration.dart';
import 'session_storage.dart';

const _authEnabled = bool.fromEnvironment(
  'SAFERIDE_AUTH_ENABLED',
  defaultValue: bool.fromEnvironment('SCOOT_AUTH_ENABLED', defaultValue: true),
);

void main() {
  runApp(const SaferideApp());
}

class SaferideApp extends StatefulWidget {
  const SaferideApp({super.key, this.authService, this.sessionStorage});

  final AuthService? authService;
  final SessionStorage? sessionStorage;

  @override
  State<SaferideApp> createState() => _SaferideAppState();
}

class _SaferideAppState extends State<SaferideApp> {
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
      title: saferideName,
      debugShowCheckedModeBanner: false,
      theme: saferideTheme(Brightness.light),
      darkTheme: saferideTheme(Brightness.dark),
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
    final dark = theme.brightness == Brightness.dark;
    final themeAction = IconButton(
      onPressed: () => onThemeChanged(dark ? ThemeMode.light : ThemeMode.dark),
      tooltip: dark ? 'Включить светлую тему' : 'Включить тёмную тему',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );

    if (session case final AuthSession active) {
      return RideDashboard(
        key: ValueKey(active.user.id),
        service: authService,
        session: active,
        onLogout: onLogout,
        themeAction: themeAction,
      );
    }

    return SaferideScaffold(
      actions: [
        if (_authEnabled)
          IconButton(
            onPressed: () => _openAuth(context, AuthMode.login),
            tooltip: 'Войти в аккаунт',
            icon: const Icon(Icons.person_outline_rounded),
          ),
        themeAction,
      ],
      child: SaferideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScooterIllustration(showWordmark: true),
            const SizedBox(height: 20),
            Text(
              'Добро пожаловать в $saferideName!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _authEnabled
                  ? 'Войдите или создайте аккаунт, чтобы пройти большой тест. '
                        'После зачёта откроется короткая проверка перед каждой поездкой.'
                  : 'Оцените своё состояние и проверьте знание ПДД перед поездкой.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _authEnabled
                  ? () => _openAuth(context, AuthMode.register)
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const ComprehensiveCheckPage(),
                      ),
                    ),
              child: Text(
                _authEnabled
                    ? 'Войти или зарегистрироваться'
                    : 'Начать проверку',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
