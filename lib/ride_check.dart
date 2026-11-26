import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'feeling.dart';
import 'question_card.dart';
import 'ride_result.dart';
import 'saferide_ui.dart';
import 'timed_questions.dart';
import 'tips.dart';
import 'traffic_questions.dart';

class RideCheckPage extends StatefulWidget {
  const RideCheckPage({super.key, required this.trafficBank});

  final List<TrafficQuestion> trafficBank;

  @override
  State<RideCheckPage> createState() => _RideCheckPageState();
}

class _RideCheckPageState extends State<RideCheckPage> {
  final _random = Random();
  late var _trafficQuestions = drawTrafficQuestions(
    _random,
    widget.trafficBank,
  );
  late TimedQuestions _questions;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _questions = _newQuestions();
  }

  TimedQuestions _newQuestions() =>
      TimedQuestions(readinessQuestions.length + _trafficQuestions.length)
        ..addListener(_updateClock);

  void _updateClock() {
    final index = _questions.index;
    if (_questions.advanceIfTimedOut()) {
      _afterAdvance(index);
    } else {
      setState(() {});
    }
  }

  void _afterAdvance(int index) {
    if (_questions.answers[index] == null || _questions.index > index + 1) {
      showQuestionTimeout(context);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _questions.dispose();
      _trafficQuestions = drawTrafficQuestions(_random, widget.trafficBank);
      _questions = _newQuestions();
      _showResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _questions.index;
    final readinessCount = readinessQuestions.length;

    final Widget content;
    if (_questions.finished) {
      final answers = _questions.answers;
      final evaluation = RideEvaluation(
        readinessAnswers: answers.sublist(0, readinessCount),
        attemptQuestions: _trafficQuestions,
        trafficAnswers: answers.sublist(readinessCount),
      );
      content = _showResult
          ? RideCheckResult(
              evaluation: evaluation,
              onRestart: _restart,
              onHome: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
            )
          : _CheckStage(
              number: 3,
              child: RideRecommendations(
                evaluation: evaluation,
                onContinue: () => setState(() => _showResult = true),
              ),
            );
    } else {
      final isReadiness = step < readinessCount;
      final index = isReadiness ? step : step - readinessCount;
      final readiness = isReadiness ? readinessQuestions[index] : null;
      final traffic = isReadiness ? null : _trafficQuestions[index];
      final options =
          readiness?.options.map((option) => option.label).toList() ??
          traffic!.options;
      final nextLabel = switch (step + 1) {
        final next when next == readinessCount => 'К тесту ПДД',
        final next when next == _questions.count => 'К рекомендациям',
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
          selected: _questions.selected,
          secondsLeft: _questions.secondsLeft,
          skipped: _questions.skipped,
          onSelect: (option) {
            if (_questions.index == step) {
              setState(() => _questions.select(option));
            }
          },
          nextLabel: nextLabel,
          onNext: _questions.canAdvance
              ? () {
                  if (_questions.index == step && _questions.advance()) {
                    _afterAdvance(step);
                  }
                }
              : null,
        ),
      );
    }

    return PopScope<void>(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _questions.index > 0) {
          setState(() {
            if (_showResult) {
              _showResult = false;
            } else {
              _questions.previous();
            }
          });
        }
      },
      child: SaferideScaffold(
        scrollKey: ValueKey((step, _showResult)),
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
