import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'saferide_ui.dart';

class AssessmentTimer extends ChangeNotifier {
  AssessmentTimer(Duration duration, {this.now = DateTime.now})
    : _paused = duration {
    resume();
  }

  final DateTime Function() now;
  Duration _paused;
  DateTime? _deadline;
  Timer? _ticker;
  int _lastSeconds = 0;

  Duration get remaining {
    final value = _deadline?.difference(now()) ?? _paused;
    return value.isNegative ? Duration.zero : value;
  }

  bool get expired => remaining == Duration.zero;

  int get secondsLeft =>
      (remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;

  void pause() {
    _paused = remaining;
    _deadline = null;
    _ticker?.cancel();
  }

  void resume() {
    if (_deadline != null || _paused <= Duration.zero) return;
    _deadline = now().add(_paused);
    _lastSeconds = secondsLeft;
    // Measure against a deadline so background tabs can catch up after a pause.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final seconds = secondsLeft;
      if (seconds == 0) pause();
      if (seconds == _lastSeconds) return;
      _lastSeconds = seconds;
      notifyListeners();
    });
  }

  void restart(Duration duration) {
    pause();
    _paused = duration;
    resume();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class AssessmentTimerBadge extends StatelessWidget {
  const AssessmentTimerBadge({super.key, required this.secondsLeft});

  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final low = secondsLeft <= 30;
    final minutes = secondsLeft ~/ 60;
    final seconds = secondsLeft % 60;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: low ? colors.errorContainer : colors.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Semantics(
              label: 'Осталось $minutes мин. $seconds сек.',
              excludeSemantics: true,
              child: Text(
                "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: low
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssessmentEndedCard extends StatelessWidget {
  const AssessmentEndedCard({
    super.key,
    this.title = 'Время вышло',
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SaferideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              Icons.timer_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            headingLevel: 2,
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          const Text('Начните новую попытку, чтобы пройти проверку.'),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
