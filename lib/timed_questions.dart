import 'dart:async';

import 'package:flutter/foundation.dart';

const questionTimeLimit = Duration(seconds: 20);

class TimedQuestions extends ChangeNotifier {
  TimedQuestions(int count, {this.now = DateTime.now})
    : _questions = List.generate(count, (_) => _QuestionProgress()) {
    _show(0);
  }

  final DateTime Function() now;
  final List<_QuestionProgress> _questions;
  int _index = 0;
  bool _reviewingExpired = false;
  Timer? _ticker;

  int get index => _index;
  int get count => _questions.length;
  bool get finished => _index == count;
  List<int?> get answers => [
    for (final question in _questions) question.answer,
  ];
  _QuestionProgress get _current => _questions[_index];

  int get secondsLeft {
    final remaining = _current.deadline!.difference(now());
    return remaining <= Duration.zero
        ? 0
        : (remaining.inMicroseconds / Duration.microsecondsPerSecond).ceil();
  }

  bool get expired => _current.expiredAt(now());
  bool get skipped => expired && _current.answer == null;
  int? get selected => expired ? _current.answer : _current.selection;
  bool get canAdvance => expired || selected != null;

  void select(int? option) {
    if (!expired) _current.selection = option;
  }

  bool advance() {
    final time = now();
    if (!_current.expiredAt(time)) {
      final selection = _current.selection;
      if (selection == null) return false;
      _current.answer = selection;
    }
    _advance(time);
    return true;
  }

  bool advanceIfTimedOut() {
    if (finished || _reviewingExpired || !skipped) return false;
    _advance(now());
    return true;
  }

  void previous() {
    if (_index > 0) _show(_index - 1);
  }

  void _advance(DateTime time) {
    var next = _index + 1;
    while (next < count && _questions[next].skippedAt(time)) {
      next++;
    }
    _show(next);
  }

  void _show(int index) {
    _index = index;
    if (finished) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final time = now();
    _current.deadline ??= time.add(questionTimeLimit);
    _reviewingExpired = _current.expiredAt(time);
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class _QuestionProgress {
  DateTime? deadline;
  int? selection;
  int? answer;

  bool expiredAt(DateTime time) =>
      deadline != null && !time.isBefore(deadline!);

  bool skippedAt(DateTime time) => answer == null && expiredAt(time);
}
