import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class TrafficQuestion {
  const TrafficQuestion({
    required this.prompt,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });

  final String prompt;
  final List<String> options;
  final int correctOption;
  final String explanation;
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
    ),
];

List<TrafficQuestion> drawTrafficQuestions(
  Random random,
  List<TrafficQuestion> bank,
) {
  final shuffled = bank.toList()..shuffle(random);
  return List.unmodifiable(shuffled.take(trafficQuestionCount));
}
