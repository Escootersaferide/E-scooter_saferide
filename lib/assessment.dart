import 'feeling.dart';
import 'traffic_questions.dart';

enum AssessmentKind { qualification, order }

const _removedCrossingQuestion =
    'Какой знак отмечает пешеходный переход у проезжей части?';

class AssessmentQuestion {
  AssessmentQuestion.fromJson(Map<String, dynamic> json)
    : category = json['category'] as String,
      prompt = switch (json) {
        {
          'category': 'readiness',
          'prompt': 'Может ли недавно употреблённый алкоголь сейчас влиять на вашу реакцию?',
        } =>
          recentAlcoholPrompt,
        _ => json['prompt'] as String,
      },
      options = List<String>.from(json['options'] as List),
      illustration = QuestionIllustration.fromJson(json['illustration']),
      _replacement = null;

  AssessmentQuestion._replacementFor(
    TrafficQuestion question,
    int serverCorrect,
  ) : category = 'traffic',
      prompt = question.prompt,
      options = question.options,
      illustration = question.illustration,
      _replacement = (
        shownCorrect: question.correctOption,
        serverCorrect: serverCorrect,
      );

  final String category;
  final String prompt;
  final List<String> options;
  final QuestionIllustration? illustration;
  final ({int shownCorrect, int serverCorrect})? _replacement;

  bool get _wasRemoved =>
      category == 'traffic' && prompt == _removedCrossingQuestion;

  String get section => switch (category) {
    'readiness' => 'Самочувствие',
    'traffic' => 'Правила дорожного движения',
    _ => 'Безопасность поездки',
  };

  int? legacyIncorrectOption(Map<String, TrafficQuestion> bank) {
    if (options.length < 2) return null;
    if (_replacement case final question?) {
      return question.shownCorrect == 0 ? 1 : 0;
    }
    // Previous servers score the first readiness option as the ready response.
    if (category == 'readiness') return 1;

    final traffic = bank[prompt];
    final correct = traffic == null
        ? switch (prompt) {
            'Что стоит проверить перед началом поездки?' =>
              'Тормоза, шины и заряд',
            'Что делать, если вы заметили неисправность тормозов во время поездки?' =>
              'Безопасно остановиться и сообщить о неисправности',
            'Как нужно держать руль электросамоката во время движения?' =>
              'Нужно держаться за руль как минимум одной рукой',
            _ => null,
          }
        : traffic.options[traffic.correctOption];
    final correctIndex = correct == null ? -1 : options.indexOf(correct);
    if (correctIndex < 0) return null;
    return correctIndex == 0 ? 1 : 0;
  }

  int? answerForServer(int? answer) {
    final replacement = _replacement;
    if (replacement == null || answer == null) return answer;
    // The older server grades the original slot, so preserve the displayed outcome.
    if (answer == replacement.shownCorrect) return replacement.serverCorrect;
    return replacement.serverCorrect == 0 ? 1 : 0;
  }
}

class AssessmentAttempt {
  AssessmentAttempt.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      minScore = json['min_score'] as int,
      acceptsSkippedAnswers = json['accepts_skipped_answers'] == true,
      questions = [
        for (final question in json['questions'] as List)
          AssessmentQuestion.fromJson(question as Map<String, dynamic>),
      ];

  AssessmentAttempt._({
    required this.id,
    required this.minScore,
    required this.acceptsSkippedAnswers,
    required this.questions,
  });

  final String id;
  final int minScore;
  final bool acceptsSkippedAnswers;
  final List<AssessmentQuestion> questions;

  bool get needsQuestionReplacement => questions.any((q) => q._wasRemoved);

  AssessmentAttempt replaceRemovedQuestions(List<TrafficQuestion> bank) {
    final used = {for (final question in questions) question.prompt};
    final current = <AssessmentQuestion>[];
    for (final question in questions) {
      if (!question._wasRemoved) {
        current.add(question);
        continue;
      }
      final serverCorrect = question.options.indexOf('5.19.1 или 5.19.2');
      if (serverCorrect < 0 || question.options.length < 2) {
        throw StateError('Missing grading options for a removed question');
      }
      final replacement = bank.firstWhere((q) => !used.contains(q.prompt));
      used.add(replacement.prompt);
      current.add(
        AssessmentQuestion._replacementFor(replacement, serverCorrect),
      );
    }
    return AssessmentAttempt._(
      id: id,
      minScore: minScore,
      acceptsSkippedAnswers: acceptsSkippedAnswers,
      questions: current,
    );
  }
}

class AssessmentResult {
  AssessmentResult.fromJson(Map<String, dynamic> json)
    : completedAt = DateTime.parse(json['completed_at'] as String),
      passed = json['passed'] as bool,
      readinessOk = json['readiness_ok'] as bool,
      score = json['score'] as int,
      total = json['total'] as int;

  final DateTime completedAt;
  final bool passed;
  final bool readinessOk;
  final int score;
  final int total;
}

class RideOverview {
  RideOverview.fromJson(Map<String, dynamic> json)
    : qualified = json['qualified_at'] != null,
      retryAfter = Duration(seconds: json['retry_after_seconds'] as int),
      history = [
        for (final result in json['history'] as List)
          AssessmentResult.fromJson(result as Map<String, dynamic>),
      ];

  final bool qualified;
  final Duration retryAfter;
  final List<AssessmentResult> history;
}
