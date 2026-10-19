/// A bilingual mechanic exercise. Choices are actions or explanations, not
/// forced numeric answers for games whose mechanics are spatial or logical.
class PracticeLesson {
  final String rulesEn, rulesDe, boardEn, boardDe, questionEn, questionDe;
  final List<String> optionsEn, optionsDe;
  final int correctIndex;
  final String explanationEn,
      explanationDe,
      focusEn,
      focusDe,
      strategyEn,
      strategyDe;
  const PracticeLesson({
    required this.rulesEn,
    required this.rulesDe,
    required this.boardEn,
    required this.boardDe,
    required this.questionEn,
    required this.questionDe,
    required this.optionsEn,
    required this.optionsDe,
    required this.correctIndex,
    required this.explanationEn,
    required this.explanationDe,
    required this.focusEn,
    required this.focusDe,
    required this.strategyEn,
    required this.strategyDe,
  });
}
