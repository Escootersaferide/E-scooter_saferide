import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'assessment.dart';
import 'assessment_timer.dart';
import 'feeling.dart';
import 'question_card.dart';
import 'ride_result.dart';
import 'saferide_ui.dart';
import 'tips.dart';
import 'traffic_questions.dart';

class RideCheckPage extends StatefulWidget {
  const RideCheckPage({super.key, required this.trafficBank});

  final List<TrafficQuestion> trafficBank;

  @override
  State<RideCheckPage> createState() => _RideCheckPageState();
}

class _RideCheckPageState extends State<RideCheckPage> {
  late final AssessmentTimer _timer;
  final _random = Random();
  late var _trafficQuestions = drawTrafficQuestions(
    _random,
    widget.trafficBank,
  );
  final _answers = List<int?>.filled(
    readinessQuestions.length + trafficQuestionCount,
    null,
  );
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = AssessmentTimer(AssessmentKind.qualification.timeLimit)
      ..addListener(_redraw);
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _advanceQuestion(int step) {
    if (_step != step || _answers[step] == null) return;
    if (_timer.expired) {
      _redraw();
      return;
    }
    setState(() {
      _step++;
      if (_step == _answers.length) _timer.pause();
    });
  }

  void _restart() {
    setState(() {
      _trafficQuestions = drawTrafficQuestions(_random, widget.trafficBank);
      _answers.fillRange(0, _answers.length, null);
      _step = 0;
      _timer.restart(AssessmentKind.qualification.timeLimit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final readinessCount = readinessQuestions.length;
    final expired = _timer.expired && step < _answers.length;

    final Widget content;
    if (expired) {
      content = AssessmentEndedCard(
        buttonLabel: 'Пройти заново',
        onPressed: _restart,
      );
    } else if (step >= _answers.length) {
      final evaluation = RideEvaluation(
        readinessAnswers: _answers.sublist(0, readinessCount).cast<int>(),
        attemptQuestions: _trafficQuestions,
        trafficAnswers: _answers.sublist(readinessCount).cast<int>(),
      );
      content = step == _answers.length
          ? _CheckStage(
              number: 3,
              child: RideRecommendations(
                evaluation: evaluation,
                onContinue: () => setState(() => _step = step + 1),
              ),
            )
          : RideCheckResult(
              evaluation: evaluation,
              onRestart: _restart,
              onHome: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
            );
    } else {
      final isReadiness = step < readinessCount;
      final index = isReadiness ? step : step - readinessCount;
      final readiness = isReadiness ? readinessQuestions[index] : null;
      final traffic = isReadiness ? null : _trafficQuestions[index];
      final options =
          readiness?.options.map((option) => option.label).toList() ??
          traffic!.options;
      final selected = _answers[step];
      final nextLabel = switch (step + 1) {
        final next when next == readinessCount => 'К тесту ПДД',
        final next when next == _answers.length => 'К рекомендациям',
        _ => 'Продолжить',
      };

      content = _CheckStage(
        number: isReadiness ? 1 : 2,
        child: QuestionCard(
          section: isReadiness ? 'Проверка самочувствия' : 'Тест по ПДД',
          number: index + 1,
          count: isReadiness ? readinessCount : _trafficQuestions.length,
          prompt: readiness?.prompt ?? traffic!.prompt,
          illustration: traffic?.illustration,
          options: options,
          selected: selected,
          onSelect: (option) => setState(() => _answers[step] = option),
          nextLabel: nextLabel,
          onNext: selected == null ? null : () => _advanceQuestion(step),
        ),
      );
    }

    return PopScope<void>(
      canPop: step == 0 || expired,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && !expired) {
          setState(() {
            if (_step == _answers.length) _timer.resume();
            _step--;
          });
        }
      },
      child: SaferideScaffold(
        scrollKey: ValueKey((step, expired)),
        actions: !expired && step < _answers.length
            ? [AssessmentTimerBadge(secondsLeft: _timer.secondsLeft)]
            : const [],
        child: content,
      ),
    );
  }
}

class _CheckStage extends StatelessWidget {
  const _CheckStage({required this.number, required this.child});

  final int number;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: number / 3,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Шаг $number из 3',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
