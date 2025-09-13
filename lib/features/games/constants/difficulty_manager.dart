import '../constants/app_constants.dart';

class DifficultyManager {
  static DifficultyConfig getDifficulty(int grade, int level) {
    final baseGrade = grade.clamp(3, 6);
    final effectiveLevel = level.clamp(1, 20);
    
    // Progressive scaling within grade
    final gradeMultiplier = (baseGrade - 2) * 0.3; // 0.3, 0.6, 0.9, 1.2
    final levelMultiplier = (effectiveLevel - 1) * 0.05; // 0 to 0.95
    final totalDifficulty = 1.0 + gradeMultiplier + levelMultiplier;
    
    return DifficultyConfig(
      grade: baseGrade,
      level: effectiveLevel,
      difficultyMultiplier: totalDifficulty,
      
      // Math complexity
      numberRange: _calculateNumberRange(baseGrade, effectiveLevel),
      operationTypes: _getOperationTypes(baseGrade, effectiveLevel),
      equationProbability: _calculateEquationProbability(baseGrade, effectiveLevel),
      
      // Game mechanics
      objectCount: _calculateObjectCount(baseGrade, effectiveLevel),
      timeLimit: _calculateTimeLimit(baseGrade, effectiveLevel),
      gameSpeed: _calculateGameSpeed(baseGrade, effectiveLevel),
      
      // Visual complexity
      showHints: effectiveLevel <= 3,
      animationSpeed: 1.0 + (levelMultiplier * 0.5),
      visualComplexity: totalDifficulty,
    );
  }
  
  static Map<String, int> _calculateNumberRange(int grade, int level) {
    final baseMax = [0, 0, 0, 15, 25, 40, 80][grade]; // Index 3-6
    final levelBonus = (level - 1) * 3;
    final maxNumber = baseMax + levelBonus;
    
    return {
      'min': level <= 5 ? 1 : 2,
      'max': maxNumber,
    };
  }
  
  static List<MathOperation> _getOperationTypes(int grade, int level) {
    final operations = <MathOperation>[];
    
    operations.add(MathOperation.addition);
    
    if (grade >= 3 || level >= 3) {
      operations.add(MathOperation.subtraction);
    }
    
    if (grade >= 4 || level >= 5) {
      operations.add(MathOperation.multiplication);
    }
    
    if (grade >= 5 || level >= 8) {
      operations.add(MathOperation.division);
    }
    
    return operations;
  }
  
  static double _calculateEquationProbability(int grade, int level) {
    final baseProbability = 0.2 + (grade - 3) * 0.15;
    final levelBonus = (level - 1) * 0.03;
    return (baseProbability + levelBonus).clamp(0.1, 0.8);
  }
  
  static int _calculateObjectCount(int grade, int level) {
    final baseCount = 3 + grade;
    final levelBonus = (level - 1) ~/ 2;
    return (baseCount + levelBonus).clamp(4, 15);
  }
  
  static int _calculateTimeLimit(int grade, int level) {
    final baseTime = 120 - (grade - 3) * 15; // 120, 105, 90, 75
    final levelPenalty = (level - 1) * 2;
    return (baseTime - levelPenalty).clamp(45, 180);
  }
  
  static double _calculateGameSpeed(int grade, int level) {
    final baseSpeed = 60.0 + (grade - 3) * 20.0;
    final levelBonus = (level - 1) * 3.0;
    return baseSpeed + levelBonus;
  }
}

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