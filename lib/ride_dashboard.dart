import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'assessment.dart';
import 'assessment_page.dart';
import 'auth_service.dart';
import 'saferide_ui.dart';

class RideDashboard extends StatefulWidget {
  const RideDashboard({
    super.key,
    required this.service,
    required this.session,
    required this.onLogout,
    required this.themeAction,
  });

  final AuthService service;
  final AuthSession session;
  final VoidCallback onLogout;
  final Widget themeAction;

  @override
  State<RideDashboard> createState() => _RideDashboardState();
}

class _RideDashboardState extends State<RideDashboard> {
  RideOverview? _overview;
  String? _error;
  Timer? _timer;
  DateTime? _retryAt;
  bool _loading = true;
  bool _starting = false;

  int get _remainingSeconds {
    final milliseconds =
        _retryAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await widget.service.rideOverview(widget.session.token);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _overview = overview;
        _retryAt = DateTime.now().add(overview.retryAfter);
      });
      if (overview.retryAfter > Duration.zero) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_remainingSeconds == 0) timer.cancel();
          setState(() {});
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) widget.onLogout();
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(AssessmentKind kind) async {
    setState(() => _starting = true);
    try {
      final attempt = await widget.service.startAssessment(
        widget.session.token,
        kind,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AssessmentPage(
            service: widget.service,
            token: widget.session.token,
            kind: kind,
            attempt: attempt,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        widget.onLogout();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) await _load();
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (profileContext) => _ProfilePage(
          user: widget.session.user,
          qualified: _overview?.qualified,
          onLogout: () {
            Navigator.of(profileContext).pop();
            widget.onLogout();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = _overview;
    final qualified = overview?.qualified ?? false;
    final remaining = _remainingSeconds;
    final canStart = !_loading && !_starting && _error == null;
    final cooldown =
        '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';

    return SaferideScaffold(
      actions: [
        if (!qualified)
          IconButton(
            onPressed: _openProfile,
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline_rounded),
          ),
        widget.themeAction,
      ],
      child: SaferideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              qualified ? 'Меню поездок' : 'Большой тест',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading && overview == null)
              const LinearProgressIndicator()
            else if (_error case final String error) ...[
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('Обновить'),
              ),
            ] else if (!qualified) ...[
              const Text(
                'Чтобы открыть меню поездок, ответьте на 4 вопроса о самочувствии '
                'и наберите минимум 16 из 20 по ПДД.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: canStart
                    ? () => _start(AssessmentKind.qualification)
                    : null,
                child: Text(
                  _starting ? 'Открываем тест…' : 'Пройти большой тест',
                ),
              ),
            ] else ...[
              const Text('Перед каждой поездкой пройдите короткий тест.'),
              if (remaining > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Следующая попытка через $cooldown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: canStart && remaining == 0
                    ? () => _start(AssessmentKind.order)
                    : null,
                icon: const Icon(Icons.electric_scooter_outlined),
                label: Text(_starting ? 'Открываем тест…' : 'Заказать самокат'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        _RideHistoryPage(history: overview!.history),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('История заказов'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openProfile,
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('Профиль'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.user,
    required this.qualified,
    required this.onLogout,
  });

  final AuthUser user;
  final bool? qualified;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SaferideScaffold(
      child: SaferideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Профиль', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text('Электронная почта'),
            Text(user.email, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Номер телефона'),
            Text(user.phone, style: theme.textTheme.titleMedium),
            if (qualified != null) ...[
              const SizedBox(height: 12),
              Text(
                qualified! ? 'Большой тест пройден' : 'Большой тест не пройден',
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onLogout, child: const Text('Выйти')),
          ],
        ),
      ),
    );
  }
}

class _RideHistoryPage extends StatelessWidget {
  const _RideHistoryPage({required this.history});

  final List<AssessmentResult> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localization = MaterialLocalizations.of(context);
    return SaferideScaffold(
      child: SaferideCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('История заказов', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Попытки короткого теста перед поездкой.'),
            const SizedBox(height: 16),
            if (history.isEmpty) const Text('Попыток пока нет.'),
            for (final attempt in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  attempt.passed
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  color: attempt.passed
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                title: Text(
                  attempt.passed ? 'Допуск получен' : 'Тест не пройден',
                ),
                subtitle: Text(
                  '${localization.formatShortDate(attempt.completedAt.toLocal())} · '
                  '${localization.formatTimeOfDay(TimeOfDay.fromDateTime(attempt.completedAt.toLocal()), alwaysUse24HourFormat: true)}',
                ),
                trailing: Text('${attempt.score} из ${attempt.total}'),
              ),
          ],
        ),
      ),
    );
  }
}
