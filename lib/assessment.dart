import 'feeling.dart';
import 'traffic_questions.dart';

enum AssessmentKind { qualification, order }

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
      illustration = QuestionIllustration.fromJson(json['illustration']);

  final String category;
  final String prompt;
  final List<String> options;
  final QuestionIllustration? illustration;

  String get section => switch (category) {
    'readiness' => 'Самочувствие',
    'traffic' => 'Правила дорожного движения',
    _ => 'Безопасность поездки',
  };

  int? legacyIncorrectOption(Map<String, TrafficQuestion> bank) {
    if (options.length < 2) return null;
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

  final String id;
  final int minScore;
  final bool acceptsSkippedAnswers;
  final List<AssessmentQuestion> questions;
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
