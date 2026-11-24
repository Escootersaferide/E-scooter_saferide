import 'traffic_questions.dart';

enum AssessmentKind {
  qualification(Duration(minutes: 7)),
  order(Duration(minutes: 2));

  const AssessmentKind(this.timeLimit);

  final Duration timeLimit;
}

class AssessmentQuestion {
  AssessmentQuestion.fromJson(Map<String, dynamic> json)
    : category = json['category'] as String,
      prompt = json['prompt'] as String,
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
}

class AssessmentAttempt {
  AssessmentAttempt.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      minScore = json['min_score'] as int,
      remainingTime = switch (json['remaining_seconds']) {
        final int seconds => Duration(seconds: seconds),
        _ => null,
      },
      questions = [
        for (final question in json['questions'] as List)
          AssessmentQuestion.fromJson(question as Map<String, dynamic>),
      ];

  final String id;
  final int minScore;
  final Duration? remainingTime;
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
