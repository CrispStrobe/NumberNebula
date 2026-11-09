import 'package:flutter/material.dart';
import '../../../shared/widgets/onboarding_overlay.dart';
import 'practice_lesson_catalog.dart';

/// Widget adapter for the pure bilingual mechanic lessons. Numeric IDs select
/// labelled actions; children never have to answer an unrelated numeric quiz.
class GameCoaching {
  final PracticeLesson lesson;
  const GameCoaching(this.lesson);
  int get answer => lesson.correctIndex;
  List<int> get choices => List.generate(lesson.optionsEn.length, (i) => i);
  String get board => lesson.boardEn;
  String get questionEn => lesson.questionEn;
  String get questionDe => lesson.questionDe;
  String get focusEn => lesson.focusEn;
  String get focusDe => lesson.focusDe;
  String get strategyEn => lesson.strategyEn;
  String get strategyDe => lesson.strategyDe;
  String get workingEn => lesson.explanationEn;
  String get workingDe => lesson.explanationDe;
  String label(int choice, bool german) =>
      (german ? lesson.optionsDe : lesson.optionsEn)[choice];
  OnboardingStep practice(bool german) => OnboardingStep(
    icon: Icons.school_outlined,
    practiceBoard: german ? lesson.boardDe : lesson.boardEn,
    substituteChoiceIntoBoard: false,
    choices: choices,
    choiceLabels: {for (final i in choices) i: label(i, german)},
    answer: answer,
    body: german
        ? '${lesson.rulesDe}\n\n${lesson.questionDe}'
        : '${lesson.rulesEn}\n\n${lesson.questionEn}',
    explanation: german ? lesson.explanationDe : lesson.explanationEn,
  );
}

final gameCoaching = <String, GameCoaching>{
  for (final entry in practiceLessons.entries)
    entry.key: GameCoaching(entry.value),
};
