import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class QuestionIllustration {
  const QuestionIllustration({required this.asset, required this.alt});

  final String asset;
  final String alt;

  static QuestionIllustration? fromJson(Object? json) => switch (json) {
    {'asset': final String asset, 'alt': final String alt} =>
      QuestionIllustration(asset: asset, alt: alt),
    _ => null,
  };
}

class TrafficQuestion {
  const TrafficQuestion({
    required this.prompt,
    required this.options,
    required this.correctOption,
    required this.explanation,
    this.illustration,
  });

  final String prompt;
  final List<String> options;
  final int correctOption;
  final String explanation;
  final QuestionIllustration? illustration;
}

const trafficPassScore = 8;
const trafficQuestionCount = 10;
const trafficQuestionAsset = 'assets/questions/traffic.json';

Future<List<TrafficQuestion>> loadTrafficQuestions() async =>
    parseTrafficQuestions(await rootBundle.loadString(trafficQuestionAsset));

List<TrafficQuestion> parseTrafficQuestions(String source) => [
  for (final question in jsonDecode(source) as List<dynamic>)
    TrafficQuestion(
      prompt: question['prompt'] as String,
      options: List<String>.from(question['options'] as List),
      correctOption: question['correct_option'] as int,
      explanation: question['explanation'] as String,
      illustration: QuestionIllustration.fromJson(question['illustration']),
    ),
];

List<TrafficQuestion> drawTrafficQuestions(
  Random random,
  List<TrafficQuestion> bank,
) {
  final shuffled = bank.toList()..shuffle(random);
  final selected = shuffled.take(trafficQuestionCount).toList();
  if (selected.length > 1) {
    final hasIllustration = selected.first.illustration != null;
    if (selected.every((q) => (q.illustration != null) == hasIllustration)) {
      final other = shuffled.indexWhere(
        (q) => (q.illustration != null) != hasIllustration,
      );
      if (other != -1) {
        selected[random.nextInt(selected.length)] = shuffled[other];
      }
    }
  }
  return List.unmodifiable(selected);
}
