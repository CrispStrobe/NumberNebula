import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

class MagicTrianglePuzzle {
  final int circlesPerSide;
  final int totalCircles;
  final int warpFrequency;
  final Set<int> hiddenIndices;
  final Map<int, int> visibleValues;
  final List<int> allNumbers;
  final List<int> numberPool;

  MagicTrianglePuzzle({
    required this.circlesPerSide,
    required this.warpFrequency,
    required this.hiddenIndices,
    required this.visibleValues,
    required this.allNumbers,
    required this.numberPool,
  }) : totalCircles = (circlesPerSide * 3) - 3;

  int getAnswerIndex(int globalIndex) {
    debugPrint("🔍 [Puzzle] getAnswerIndex($globalIndex)");
    int answerIndex = 0;
    for (int i=0; i < totalCircles; i++) {
        if (hiddenIndices.contains(i)) {
            if (i == globalIndex) {
              debugPrint("🔍 [Puzzle] Found globalIndex $globalIndex at answerIndex $answerIndex");
              return answerIndex;
            }
            answerIndex++;
        }
    }
    debugPrint("❌ [Puzzle] globalIndex $globalIndex not found in hiddenIndices");
    return -1;
  }

  static MagicTrianglePuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;

    debugPrint("\n--- Generating Enhanced Triangle Puzzle ---");
    int circlesPerSide = _determineCirclesPerSide(grade, level);
    final totalCircles = (circlesPerSide * 3) - 3;
    debugPrint("[Wormhole] Parameters: Grade=$grade, Level=$level -> circlesPerSide=$circlesPerSide");

    final stopwatch = Stopwatch()..start();
    List<int>? solution;
    List<int> allNumbers = [];

    int attempts = 0;
    while (solution == null && attempts < 15) {
      if (attempts > 0) debugPrint("... Retrying puzzle generation (attempt ${attempts + 1}) ...");

      allNumbers = _generateNumberSet(grade, level, totalCircles, attempts);
      debugPrint("[Wormhole] Enhanced resonator values: $allNumbers");

      debugPrint("[Wormhole] Backtracking for a stable alignment...");
      final solver = _MagicTriangleSolver(circlesPerSide, allNumbers);
      solution = solver.findSolution();
      attempts++;
    }
    stopwatch.stop();

    if (solution == null) {
      debugPrint("❌ [Wormhole] FATAL: Solver failed after multiple attempts. Defaulting to an easier puzzle.");
      return generate({'grade': 1, 'level': 1});
    }

    debugPrint("✅ [Wormhole] Stable Alignment FOUND in ${stopwatch.elapsedMilliseconds}ms: $solution");
    final warpFrequency = _calculateSideSums(solution, circlesPerSide)[0];
    debugPrint("✨ [Wormhole] Required Warp Frequency: $warpFrequency");

    int visibleCount = _determineVisibleCount(grade, level, totalCircles);
    debugPrint("[Wormhole] Total circles: $totalCircles, Visible: $visibleCount, Hidden: ${totalCircles - visibleCount}");
    final allIndices = List.generate(totalCircles, (i) => i)..shuffle();
    final hiddenIndices = allIndices.sublist(0, totalCircles - visibleCount).toSet();
    debugPrint("[Wormhole] Hidden indices: $hiddenIndices");

    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCircles; i++) {
      if (!hiddenIndices.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }
    debugPrint("[Wormhole] Visible values: $visibleValues");

    final hiddenNumbers = allNumbers.where((n) => !visibleValues.values.contains(n)).toList();
    debugPrint("[Wormhole] Hidden numbers: $hiddenNumbers");

    final decoyCount = _calculateDecoyCount(grade, level, hiddenNumbers.length);
    final decoyNumbers = _generateEnhancedDecoys(grade, level, decoyCount, allNumbers, hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    debugPrint("[Wormhole] Added $decoyCount enhanced decoy resonators: $decoyNumbers");
    debugPrint("[Wormhole] Final number pool for user: $numberPool");

    final puzzle = MagicTrianglePuzzle(
      circlesPerSide: circlesPerSide,
      warpFrequency: warpFrequency,
      hiddenIndices: hiddenIndices,
      visibleValues: visibleValues,
      allNumbers: allNumbers,
      numberPool: numberPool,
    );

    debugPrint("[Wormhole] ✅ Enhanced puzzle generation complete - returning puzzle");
    return puzzle;
  }

  static int _determineCirclesPerSide(int grade, int level) {
    final totalDifficulty = grade + (level / 5.0);

    debugPrint("[Difficulty] Grade=$grade, Level=$level, TotalDifficulty=$totalDifficulty");

    if (totalDifficulty <= 2.0) return 3;
    if (totalDifficulty <= 3.5) return 4;
    if (totalDifficulty <= 5.0) return 5;
    if (totalDifficulty <= 6.5) return 6;
    return 7;
  }

  static int _determineVisibleCount(int grade, int level, int totalCircles) {
    final difficulty = grade + (level / 5.0);

    double visibilityRatio = 0.80 - (difficulty * 0.06);

    visibilityRatio -= (level - 1) * 0.01;

    visibilityRatio = visibilityRatio.clamp(0.25, 0.80);

    final int minVisible = math.max(3, (totalCircles / 5).ceil());
    final int maxVisible = (totalCircles * 0.75).floor();

    final calculatedVisible = (totalCircles * visibilityRatio).round();

    debugPrint("[Enhanced Difficulty] Grade $grade, Level $level, Total Circles $totalCircles");
    debugPrint("[Enhanced Difficulty] Visibility Ratio: ${visibilityRatio.toStringAsFixed(2)} -> Calculated: $calculatedVisible nodes");
    debugPrint("[Enhanced Difficulty] Clamping between Min: $minVisible and Max: $maxVisible");

    return calculatedVisible.clamp(minVisible, maxVisible);
  }

  static List<int> _generateNumberSet(int grade, int level, int totalCircles, int attempt) {
    final random = math.Random();
    final difficulty = grade + (level / 5.0);

    if (difficulty < 2.5) {
      final baseStart = math.max(1, level + attempt * 2);
      return List.generate(totalCircles, (i) => baseStart + i);
    } else if (difficulty < 4.0) {
      final baseStart = math.max(1, level + grade + attempt * 3);
      final numbers = <int>[];
      int current = baseStart;
      for (int i = 0; i < totalCircles; i++) {
        numbers.add(current);
        current += (random.nextBool() && i > 1) ? random.nextInt(2) + 1 : 1;
      }
      return numbers;
    } else if (difficulty < 5.5) {
      final baseStart = level * 2 + grade * 3 + attempt * 4;
      final range = math.max(totalCircles + 5, 10 + level * 2);
      final numbers = <int>[];
      final used = <int>{};

      while (numbers.length < totalCircles) {
        final num = baseStart + random.nextInt(range);
        if (!used.contains(num)) {
          used.add(num);
          numbers.add(num);
        }
      }
      numbers.sort();
      return numbers;
    } else {
      final baseStart = level * 3 + grade * 4 + attempt * 6;
      final range = math.max(totalCircles + 8, 20 + level * 2);
      final numbers = <int>[];
      final used = <int>{};

      while (numbers.length < totalCircles) {
        final num = baseStart + random.nextInt(range);
        if (!used.contains(num)) {
          used.add(num);
          numbers.add(num);
        }
      }

      numbers.sort();
      return numbers;
    }
  }

  static int _calculateDecoyCount(int grade, int level, int hiddenCount) {
    final baseDecoys = 2 + (level / 4).floor();
    final gradeMultiplier = (grade >= 3) ? 1.3 : 1.0;

    final totalDecoys = (baseDecoys * gradeMultiplier).round();

    final minDecoys = math.max(2, hiddenCount ~/ 3);
    final maxDecoys = hiddenCount + 5;

    return totalDecoys.clamp(minDecoys, maxDecoys);
  }

  static List<int> _generateEnhancedDecoys(int grade, int level, int count,
                                         List<int> correctNumbers, List<int> hiddenNumbers) {
    debugPrint("[Enhanced Decoys] Generating $count decoy numbers");
    final decoys = <int>{};
    final allCorrect = Set<int>.from(correctNumbers);
    final random = math.Random();
    final difficulty = grade + (level / 5.0);

    final minCorrect = correctNumbers.isNotEmpty ? correctNumbers.first : 1;
    final maxCorrect = correctNumbers.isNotEmpty ? correctNumbers.last : 10;
    final range = maxCorrect - minCorrect;

    while (decoys.length < count) {
      int decoy = 1;

      if (difficulty < 2.5) {
        final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
        decoy = baseNum + random.nextInt(6) - 3;
      } else if (difficulty < 4.0) {
        if (random.nextBool()) {
          final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
          decoy = baseNum + random.nextInt(8) - 4;
        } else {
          decoy = minCorrect + random.nextInt(range + 8);
        }
      } else if (difficulty < 5.5) {
        final strategy = random.nextInt(3);
        switch (strategy) {
          case 0:
            final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
            decoy = baseNum + [1, -1, 2, -2][random.nextInt(4)];
            break;
          case 1:
            decoy = minCorrect - 3 + random.nextInt(range + 12);
            break;
          case 2:
            decoy = maxCorrect + random.nextInt(8) + 1;
            break;
        }
      } else {
        final strategy = random.nextInt(4);
        switch (strategy) {
          case 0:
            final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
            decoy = baseNum + [-1, 1][random.nextInt(2)];
            break;
          case 1:
            decoy = minCorrect + random.nextInt(range + 10);
            break;
          case 2:
            decoy = maxCorrect + random.nextInt(12) + 2;
            break;
          case 3:
            decoy = math.max(1, minCorrect - random.nextInt(6) - 1);
            break;
        }
      }

      if (decoy > 0 && !allCorrect.contains(decoy) && !decoys.contains(decoy)) {
        decoys.add(decoy);
      }
    }

    final result = decoys.toList();
    debugPrint("[Enhanced Decoys] Generated: $result");
    return result;
  }

  SolutionResult checkSolution(List<int> userAnswers) {
    debugPrint("✅ [Puzzle] checkSolution: $userAnswers");
    final completeArrangement = List<int>.filled(totalCircles, 0);
    int hiddenIdx = 0;
    for (int i = 0; i < totalCircles; i++) {
      if (hiddenIndices.contains(i)) {
        completeArrangement[i] = userAnswers[hiddenIdx++];
      } else {
        completeArrangement[i] = visibleValues[i]!;
      }
    }
    debugPrint("✅ [Puzzle] Complete arrangement: $completeArrangement");

    final usedHidden = Set.from(userAnswers);
    final correctHidden = allNumbers.where((n) => !visibleValues.values.contains(n));
    debugPrint("✅ [Puzzle] Used hidden: $usedHidden, Correct hidden: $correctHidden");
    if(usedHidden.length != correctHidden.length || !usedHidden.containsAll(correctHidden)) {
        debugPrint("❌ [Puzzle] Wrong numbers used");
        return SolutionResult(isValid: false, isPerfect: false);
    }

    final sideSums = _calculateSideSums(completeArrangement, circlesPerSide);
    debugPrint("✅ [Puzzle] Side sums: $sideSums, Target: $warpFrequency");
    final isPerfect = sideSums.every((sum) => sum == warpFrequency);
    debugPrint("✅ [Puzzle] Solution result: isPerfect=$isPerfect");
    return SolutionResult(isValid: true, isPerfect: isPerfect);
  }

  static List<int> _getSideIndices(int side, int circlesPerSide) {
    final n = circlesPerSide;
    switch (side) {
      case 0: return List.generate(n, (i) => i);
      case 1: return [n - 1, ...List.generate(n - 1, (i) => n + i)];
      case 2: return [2 * n - 2, ...List.generate(n - 2, (i) => 2 * n - 1 + i), 0];
      default: return [];
    }
  }

  static List<int> _calculateSideSums(List<int> arrangement, int circlesPerSide) {
    final sums = <int>[];
    for (int side = 0; side < 3; side++) {
      final indices = _getSideIndices(side, circlesPerSide);
      sums.add(indices.fold(0, (acc, index) => acc + arrangement[index]));
    }
    return sums;
  }

  List<Offset> getCirclePositions(Offset center, double radius) {
    debugPrint("🔺 [Puzzle] getCirclePositions - center: $center, radius: $radius");
    final points = <Offset>[];
    final n = circlesPerSide;

    final cornerAngles = [ -math.pi / 2, math.pi / 6, 5 * math.pi / 6 ];
    final cornerPoints = [
      center + Offset(math.cos(cornerAngles[0]), math.sin(cornerAngles[0])) * radius,
      center + Offset(math.cos(cornerAngles[1]), math.sin(cornerAngles[1])) * radius,
      center + Offset(math.cos(cornerAngles[2]), math.sin(cornerAngles[2])) * radius,
    ];

    for (int i = 0; i < n; i++) {
      points.add(Offset.lerp(cornerPoints[0], cornerPoints[1], i / (n - 1))!);
    }
    for (int i = 1; i < n; i++) {
      points.add(Offset.lerp(cornerPoints[1], cornerPoints[2], i / (n - 1))!);
    }
    for (int i = 1; i < n - 1; i++) {
      points.add(Offset.lerp(cornerPoints[2], cornerPoints[0], i / (n - 1))!);
    }

    debugPrint("🔺 [Puzzle] Generated ${points.length} circle positions");
    return points;
  }
}

class _MagicTriangleSolver {
  final int circlesPerSide;
  final List<int> numbersToUse;
  final int totalCircles;
  late List<int> _arrangement;
  late List<bool> _usedFlags;
  int _iterations = 0;
  late int _maxIterations;

  _MagicTriangleSolver(this.circlesPerSide, this.numbersToUse)
      : totalCircles = (circlesPerSide * 3) - 3 {
    _arrangement = List.filled(totalCircles, 0);
    _usedFlags = List.filled(numbersToUse.length, false);

    _maxIterations = _calculateMaxIterations();
    numbersToUse.shuffle();

    debugPrint("[Enhanced Solver] Initialized with $totalCircles circles, numbers: $numbersToUse");
    debugPrint("[Enhanced Solver] Max iterations: $_maxIterations");
  }

  int _calculateMaxIterations() {
    const baseIterations = 100000;
    final complexityFactor = math.pow(circlesPerSide, 2.0).toInt();
    return baseIterations * complexityFactor;
  }

  List<int>? findSolution() {
    debugPrint("[Enhanced Solver] Starting enhanced backtracking algorithm");
    _iterations = 0;

    if (_solve(0, -1)) {
        debugPrint("[Enhanced Solver] Solution found after $_iterations iterations.");
        return _arrangement;
    } else {
        debugPrint("[Enhanced Solver] FAILED to find a solution after $_iterations iterations (limit: $_maxIterations).");
        return null;
    }
  }

  bool _solve(int k, int targetSum) {
    _iterations++;
    if (_iterations > _maxIterations) {
      debugPrint("[Enhanced Solver] Max iterations reached, giving up");
      return false;
    }

    if (_iterations % 50000 == 0) {
      debugPrint("[Enhanced Solver] Progress: $_iterations iterations, position $k/$totalCircles");
    }

    if (k == totalCircles) {
      debugPrint("[Enhanced Solver] All positions filled, solution found!");
      return true;
    }

    for (int i = 0; i < numbersToUse.length; i++) {
      if (!_usedFlags[i]) {
        _arrangement[k] = numbersToUse[i];
        _usedFlags[i] = true;

        bool passesPruning = true;
        int nextTargetSum = targetSum;

        if (k == circlesPerSide - 1) {
          nextTargetSum = MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[0];
          if (nextTargetSum < 10 || nextTargetSum > 300) passesPruning = false;
        } else if (k == 2 * circlesPerSide - 2) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[1] != targetSum) {
            passesPruning = false;
          }
        } else if (k == totalCircles - 1) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[2] != targetSum) {
            passesPruning = false;
          }
        }

        if (passesPruning && _solve(k + 1, nextTargetSum)) return true;

        _usedFlags[i] = false;
      }
    }
    return false;
  }
}

class SolutionResult {
  final bool isValid;
  final bool isPerfect;
  SolutionResult({required this.isValid, required this.isPerfect});
}
