import 'app_constants.dart';

class DifficultyConfig {
  final int grade;
  final int level;
  final double difficultyMultiplier;
  final Map<String, int> numberRange;
  final List<MathOperation> operationTypes;
  final double equationProbability;
  final int objectCount;
  final int timeLimit;
  final double gameSpeed;
  final bool showHints;
  final double animationSpeed;
  final double visualComplexity;

  const DifficultyConfig({
    required this.grade,
    required this.level,
    required this.difficultyMultiplier,
    required this.numberRange,
    required this.operationTypes,
    required this.equationProbability,
    required this.objectCount,
    required this.timeLimit,
    required this.gameSpeed,
    required this.showHints,
    required this.animationSpeed,
    required this.visualComplexity,
  });
}
