// ignore_for_file: unused_element, unused_field
// lib/features/games/models/math_problem.dart:

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../../../core/services/sri_service.dart'; // Import SRI Service
import '../providers/game_provider.dart'; 
import '../constants/difficulty_manager.dart';

class MathProblem {
  final String expression;
  final int answer;
  final MathOperation operation;
  final int operandA;
  final int operandB;
  final int difficulty;

  String get id {
    switch (operation) {
      case MathOperation.addition:
        return 'ADD_${math.min(operandA, operandB)}_${math.max(operandA, operandB)}';
      case MathOperation.subtraction:
        return 'SUB_${operandA}_$operandB';
      case MathOperation.multiplication:
        return 'MUL_${math.min(operandA, operandB)}_${math.max(operandA, operandB)}';
      case MathOperation.division:
        return 'DIV_${operandA}_$operandB';
    }
  }
  
  MathProblem({
    required this.expression,
    required this.answer,
    required this.operation,
    required this.operandA,
    required this.operandB,
    required this.difficulty,
  });

  static MathProblem generateProblem(GameProvider gameProvider, int level, SriService sriService) {
    final difficultyConfig = DifficultyManager.getDifficulty(gameProvider, level);
    
    // 1. Check if custom settings are active for filtering
    if (gameProvider.useCustomProblemSettings) {
      // Get all reviewable problems that match the custom operations
      final allReviewable = sriService.getProblemsForReview(limit: 100); // Get a larger batch to filter
      final filteredReviewable = allReviewable.where((problemId) {
        final opString = problemId.split('_').first;
        switch (opString) {
          case 'ADD': return gameProvider.customOperations.contains('addition');
          case 'SUB': return gameProvider.customOperations.contains('subtraction');
          case 'MUL': return gameProvider.customOperations.contains('multiplication');
          case 'DIV': return gameProvider.customOperations.contains('division');
          default: return false;
        }
      }).toList();

      if (filteredReviewable.isNotEmpty) {
        final problemId = filteredReviewable.first;
        debugPrint('[SRI] Found CUSTOM-FILTERED problem to review: $problemId');
        // (The logic to parse and return the problem remains the same)
        final parts = problemId.split('_');
        final type = parts[0];
        final operandA = int.parse(parts[1]);
        final operandB = int.parse(parts[2]);
        switch (type) {
          case 'ADD': return MathProblem.addition(operandA, operandB);
          case 'SUB': return MathProblem.subtraction(operandA, operandB);
          case 'MUL': return MathProblem.multiplication(operandA, operandB);
          case 'DIV': return MathProblem.division(operandA, operandB);
        }
      }
      // If no suitable review problems are found, fall through to generate a new one using custom settings.
    } else {
      // Original logic for non-custom mode: prioritize any review problem
      final problemsToReview = sriService.getProblemsForReview(limit: 1);
      if (problemsToReview.isNotEmpty) {
        final problemId = problemsToReview.first;
        debugPrint('[SRI] Found problem to review: $problemId');
        final parts = problemId.split('_');
        final type = parts[0];
        final operandA = int.parse(parts[1]);
        final operandB = int.parse(parts[2]);
        switch (type) {
          case 'ADD': return MathProblem.addition(operandA, operandB);
          case 'SUB': return MathProblem.subtraction(operandA, operandB);
          case 'MUL': return MathProblem.multiplication(operandA, operandB);
          case 'DIV': return MathProblem.division(operandA, operandB);
        }
      }
    }

    // 2. If no reviews are due (or none match filters), generate a new problem
    MathProblem newProblem;
    int attempts = 0;

    do {
      newProblem = _generateFromConfig(difficultyConfig);
      attempts++;
      if (attempts > 20) {
        debugPrint('[SRI] Could not find a non-mastered problem after 20 attempts. Serving a random one.');
        break;
      }
    } while (sriService.isProblemMastered(newProblem.id));

    debugPrint('[SRI] Generated new non-mastered problem: ${newProblem.expression}');
    return newProblem;
  }

  // **NEW**: A private static helper that generates a problem based on a DifficultyConfig
  static MathProblem _generateFromConfig(DifficultyConfig config) {
    final random = math.Random();
    final operations = config.operationTypes;
    final range = config.numberRange;
    // Normalise the range. A custom range can arrive with min == max (the
    // settings sliders allow it) or, defensively, min > max. Both previously
    // crashed the subtraction branch via random.nextInt(0)/negative.
    final lo = math.min(range['min']!, range['max']!);
    final hi = math.max(range['min']!, range['max']!);

    final operation = operations[random.nextInt(operations.length)];

    int a, b;

    switch (operation) {
      case MathOperation.addition:
        a = random.nextInt(hi - lo + 1) + lo;
        b = random.nextInt(hi - lo + 1) + lo;
        return MathProblem.addition(a, b, difficulty: config.grade);
      case MathOperation.subtraction:
        // a in [lo+1, hi] when the range has room; otherwise the degenerate
        // single value lo (yields a trivial a-a problem rather than crashing).
        a = hi > lo ? random.nextInt(hi - lo) + (lo + 1) : lo;
        b = random.nextInt(a - lo + 1) + lo; // b in [lo, a]
        return MathProblem.subtraction(a, b, difficulty: config.grade);
      case MathOperation.multiplication:
        final maxFactor = math.min(12, 3 + config.grade * 2);
        a = random.nextInt(maxFactor - 1) + 2;
        b = random.nextInt(maxFactor - 1) + 2;
        return MathProblem.multiplication(a, b, difficulty: config.grade);
      case MathOperation.division:
        final maxDivisor = math.min(12, 4 + config.grade);
        final divisor = random.nextInt(maxDivisor - 1) + 2;
        final quotient = random.nextInt(12) + 2;
        return MathProblem.division(divisor * quotient, divisor, difficulty: config.grade);
    }
  }

  // **FIX**: Changed this from a private factory to a private static method
  static MathProblem _generateRandom(int grade, {int? difficulty}) {
    final random = math.Random();
    final actualDifficulty = difficulty ?? (grade - 2);
    final operations = MathOperations.getOperationsForGrade(grade);
    final ranges = MathOperations.getNumberRangesForGrade(grade);
    
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case AppConstants.additionSymbol:
        return _generateAddition(random, ranges, actualDifficulty);
      case AppConstants.subtractionSymbol:
        return _generateSubtraction(random, ranges, actualDifficulty);
      case AppConstants.multiplicationSymbol:
        return _generateMultiplication(random, ranges, actualDifficulty);
      case AppConstants.divisionSymbol:
        return _generateDivision(random, ranges, actualDifficulty);
      default:
        return _generateAddition(random, ranges, actualDifficulty);
    }
  }
  
  // Factory constructors for different problem types
  factory MathProblem.addition(int a, int b, {int difficulty = 1}) {
    return MathProblem(
      expression: '$a + $b',
      answer: a + b,
      operation: MathOperation.addition,
      operandA: a,
      operandB: b,
      difficulty: difficulty,
    );
  }
  
  factory MathProblem.subtraction(int a, int b, {int difficulty = 1}) {
    // Ensure a >= b for positive results
    if (a < b) {
      final temp = a;
      a = b;
      b = temp;
    }
    
    return MathProblem(
      expression: '$a - $b',
      answer: a - b,
      operation: MathOperation.subtraction,
      operandA: a,
      operandB: b,
      difficulty: difficulty,
    );
  }
  
  factory MathProblem.multiplication(int a, int b, {int difficulty = 1}) {
    return MathProblem(
      expression: '$a × $b',
      answer: a * b,
      operation: MathOperation.multiplication,
      operandA: a,
      operandB: b,
      difficulty: difficulty,
    );
  }
  
  factory MathProblem.division(int dividend, int divisor, {int difficulty = 1}) {
    // Ensure clean division
    final quotient = dividend ~/ divisor;
    final actualDividend = divisor * quotient;
    
    return MathProblem(
      expression: '$actualDividend ÷ $divisor',
      answer: quotient,
      operation: MathOperation.division,
      operandA: actualDividend,
      operandB: divisor,
      difficulty: difficulty,
    );
  }
  
  // Generate random problem based on grade and difficulty
  factory MathProblem.random(int grade, {int? difficulty}) {
    final random = math.Random();
    final actualDifficulty = difficulty ?? (grade - 2);
    final operations = MathOperations.getOperationsForGrade(grade);
    final ranges = MathOperations.getNumberRangesForGrade(grade);
    
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case AppConstants.additionSymbol:
        return _generateAddition(random, ranges, actualDifficulty);
      case AppConstants.subtractionSymbol:
        return _generateSubtraction(random, ranges, actualDifficulty);
      case AppConstants.multiplicationSymbol:
        return _generateMultiplication(random, ranges, actualDifficulty);
      case AppConstants.divisionSymbol:
        return _generateDivision(random, ranges, actualDifficulty);
      default:
        return _generateAddition(random, ranges, actualDifficulty);
    }
  }
  
  static MathProblem _generateAddition(
    math.Random random,
    Map<String, int> ranges,
    int difficulty,
  ) {
    final maxNum = (ranges['max']! * (0.5 + difficulty * 0.2)).round();
    final a = random.nextInt(maxNum) + ranges['min']!;
    final b = random.nextInt(maxNum) + ranges['min']!;
    return MathProblem.addition(a, b, difficulty: difficulty);
  }
  
  static MathProblem _generateSubtraction(
    math.Random random,
    Map<String, int> ranges,
    int difficulty,
  ) {
    final maxNum = (ranges['max']! * (0.5 + difficulty * 0.2)).round();
    final a = random.nextInt(maxNum) + ranges['min']! + 10;
    final b = random.nextInt(a - ranges['min']!) + ranges['min']!;
    return MathProblem.subtraction(a, b, difficulty: difficulty);
  }
  
  static MathProblem _generateMultiplication(
    math.Random random,
    Map<String, int> ranges,
    int difficulty,
  ) {
    final maxFactor = math.min(12, 5 + difficulty * 2);
    final a = random.nextInt(maxFactor) + 2;
    final b = random.nextInt(maxFactor) + 2;
    return MathProblem.multiplication(a, b, difficulty: difficulty);
  }
  
  static MathProblem _generateDivision(
    math.Random random,
    Map<String, int> ranges,
    int difficulty,
  ) {
    final maxDivisor = math.min(15, 5 + difficulty * 2);
    final divisor = random.nextInt(maxDivisor) + 2;
    final quotient = random.nextInt(15) + 2;
    final dividend = divisor * quotient;
    return MathProblem.division(dividend, divisor, difficulty: difficulty);
  }
  
  // Validation methods
  bool isValid() {
    switch (operation) {
      case MathOperation.addition:
        return operandA + operandB == answer;
      case MathOperation.subtraction:
        return operandA - operandB == answer;
      case MathOperation.multiplication:
        return operandA * operandB == answer;
      case MathOperation.division:
        return operandA ~/ operandB == answer && operandA % operandB == 0;
    }
  }
  
  // Helper methods
  String get operationSymbol {
    switch (operation) {
      case MathOperation.addition:
        return AppConstants.additionSymbol;
      case MathOperation.subtraction:
        return AppConstants.subtractionSymbol;
      case MathOperation.multiplication:
        return AppConstants.multiplicationSymbol;
      case MathOperation.division:
        return AppConstants.divisionSymbol;
    }
  }
  
  String get operationName {
    switch (operation) {
      case MathOperation.addition:
        return 'Addition';
      case MathOperation.subtraction:
        return 'Subtraction';
      case MathOperation.multiplication:
        return 'Multiplication';
      case MathOperation.division:
        return 'Division';
    }
  }
  
  // Generate multiple choice options
  List<int> generateMultipleChoiceOptions({int optionsCount = 4}) {
    final options = <int>[answer];
    final random = math.Random();
    
    while (options.length < optionsCount) {
      int wrongAnswer;
      
      // Generate plausible wrong answers
      switch (operation) {
        case MathOperation.addition:
          wrongAnswer = answer + random.nextInt(10) - 5;
          break;
        case MathOperation.subtraction:
          wrongAnswer = answer + random.nextInt(10) - 5;
          break;
        case MathOperation.multiplication:
          wrongAnswer = answer + random.nextInt(20) - 10;
          break;
        case MathOperation.division:
          wrongAnswer = answer + random.nextInt(6) - 3;
          break;
      }
      
      // Ensure positive answers and no duplicates
      if (wrongAnswer > 0 && !options.contains(wrongAnswer)) {
        options.add(wrongAnswer);
      }
    }
    
    options.shuffle(random);
    return options;
  }
  
  // Difficulty assessment
  DifficultyLevel get difficultyLevel {
    final score = _calculateDifficultyScore();
    
    if (score < 10) return DifficultyLevel.easy;
    if (score < 20) return DifficultyLevel.medium;
    if (score < 30) return DifficultyLevel.hard;
    return DifficultyLevel.expert;
  }
  
  int _calculateDifficultyScore() {
    int score = 0;
    
    // Base score from operands
    score += (operandA / 10).ceil();
    score += (operandB / 10).ceil();
    
    // Operation complexity
    switch (operation) {
      case MathOperation.addition:
        score += 1;
        break;
      case MathOperation.subtraction:
        score += 2;
        break;
      case MathOperation.multiplication:
        score += 3;
        break;
      case MathOperation.division:
        score += 4;
        break;
    }
    
    // Answer magnitude
    score += (answer / 20).ceil();
    
    return score;
  }
  
  // Serialization
  Map<String, dynamic> toJson() {
    return {
      'expression': expression,
      'answer': answer,
      'operation': operation.index,
      'operandA': operandA,
      'operandB': operandB,
      'difficulty': difficulty,
    };
  }
  
  factory MathProblem.fromJson(Map<String, dynamic> json) {
    return MathProblem(
      expression: json['expression'],
      answer: json['answer'],
      operation: MathOperation.values[json['operation']],
      operandA: json['operandA'],
      operandB: json['operandB'],
      difficulty: json['difficulty'],
    );
  }
  
  @override
  String toString() {
    return 'MathProblem($expression = $answer)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is MathProblem &&
        other.expression == expression &&
        other.answer == answer &&
        other.operation == operation &&
        other.operandA == operandA &&
        other.operandB == operandB;
  }
  
  @override
  int get hashCode {
    return expression.hashCode ^
        answer.hashCode ^
        operation.hashCode ^
        operandA.hashCode ^
        operandB.hashCode;
  }
}

// Problem Set Generator
class MathProblemSet {
  final List<MathProblem> problems;
  final int grade;
  final int difficulty;
  
  MathProblemSet({
    required this.problems,
    required this.grade,
    required this.difficulty,
  });
  
  factory MathProblemSet.generate({
    required int grade,
    required int count,
    int? difficulty,
    List<MathOperation>? allowedOperations,
  }) {
    final problems = <MathProblem>[];
    final actualDifficulty = difficulty ?? grade - 2;
    
    for (int i = 0; i < count; i++) {
      problems.add(MathProblem.random(grade, difficulty: actualDifficulty));
    }
    
    return MathProblemSet(
      problems: problems,
      grade: grade,
      difficulty: actualDifficulty,
    );
  }
  
  // Sort problems by difficulty
  void sortByDifficulty() {
    problems.sort((a, b) => a._calculateDifficultyScore().compareTo(b._calculateDifficultyScore()));
  }
  
  // Filter by operation type
  List<MathProblem> filterByOperation(MathOperation operation) {
    return problems.where((problem) => problem.operation == operation).toList();
  }
  
  // Get problems in answer range
  List<MathProblem> getProblemsInRange(int minAnswer, int maxAnswer) {
    return problems
        .where((problem) => problem.answer >= minAnswer && problem.answer <= maxAnswer)
        .toList();
  }
  
  // Statistics
  Map<MathOperation, int> get operationDistribution {
    final distribution = <MathOperation, int>{};
    for (final problem in problems) {
      distribution[problem.operation] = (distribution[problem.operation] ?? 0) + 1;
    }
    return distribution;
  }
  
  double get averageDifficulty {
    if (problems.isEmpty) return 0.0;
    final totalScore = problems.fold(0, (sum, problem) => sum + problem._calculateDifficultyScore());
    return totalScore / problems.length;
  }
  
  List<int> get allAnswers => problems.map((p) => p.answer).toList();
  
  List<int> get sortedAnswers => allAnswers..sort();
}