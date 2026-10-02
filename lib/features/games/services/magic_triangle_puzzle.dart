import 'generator_random.dart';
import 'magic_triangle_solver.dart';
import 'dart:math' as math;

import 'generator_diagnostics.dart';

class MagicTrianglePuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'circlesPerSide': circlesPerSide,
        'warpFrequency': warpFrequency,
        'hiddenIndices': hiddenIndices.map((v0) => v0).toList(),
        'visibleValues':
            visibleValues.entries.map((v0) => [v0.key, v0.value]).toList(),
        'allNumbers': allNumbers.map((v0) => v0).toList(),
        'numberPool': numberPool.map((v0) => v0).toList()
      };
  factory MagicTrianglePuzzle.fromJson(Map<String, dynamic> json) =>
      MagicTrianglePuzzle(
          circlesPerSide: json['circlesPerSide'] as int,
          warpFrequency: json['warpFrequency'] as int,
          hiddenIndices:
              (json['hiddenIndices'] as List).map((v0) => v0 as int).toSet(),
          visibleValues: Map<int, int>.fromEntries(
              (json['visibleValues'] as List)
                  .map((v0) => MapEntry(v0[0] as int, v0[1] as int))),
          allNumbers:
              (json['allNumbers'] as List).map((v0) => v0 as int).toList(),
          numberPool:
              (json['numberPool'] as List).map((v0) => v0 as int).toList());

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
    if (kDebugMode) traceGenerator("🔍 [Puzzle] getAnswerIndex($globalIndex)");
    int answerIndex = 0;
    for (int i = 0; i < totalCircles; i++) {
      if (hiddenIndices.contains(i)) {
        if (i == globalIndex) {
          if (kDebugMode) {
            traceGenerator(
                "🔍 [Puzzle] Found globalIndex $globalIndex at answerIndex $answerIndex");
          }
          return answerIndex;
        }
        answerIndex++;
      }
    }
    if (kDebugMode) {
      traceGenerator(
          "❌ [Puzzle] globalIndex $globalIndex not found in hiddenIndices");
    }
    return -1;
  }

  static MagicTrianglePuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;

    if (kDebugMode) {
      traceGenerator("\n--- Generating Enhanced Triangle Puzzle ---");
    }
    int circlesPerSide = _determineCirclesPerSide(grade, level);
    final totalCircles = (circlesPerSide * 3) - 3;
    traceGenerator(
        "[Wormhole] Parameters: Grade=$grade, Level=$level -> circlesPerSide=$circlesPerSide");

    final stopwatch = Stopwatch()..start();
    List<int>? solution;
    List<int> allNumbers = [];

    int attempts = 0;
    while (solution == null && attempts < 15) {
      if (attempts > 0) {
        traceGenerator(
            "... Retrying puzzle generation (attempt ${attempts + 1}) ...");
      }

      allNumbers = _generateNumberSet(grade, level, totalCircles, attempts);
      if (kDebugMode) {
        traceGenerator("[Wormhole] Enhanced resonator values: $allNumbers");
      }

      traceGenerator("[Wormhole] Backtracking for a stable alignment...");
      solution = solveMagicTriangle(circlesPerSide, allNumbers);
      attempts++;
    }
    stopwatch.stop();

    if (solution == null) {
      if (kDebugMode) {
        traceGenerator(
            "❌ [Wormhole] FATAL: Solver failed after multiple attempts. Defaulting to an easier puzzle.");
      }
      return generate({'grade': 1, 'level': 1});
    }

    if (kDebugMode) {
      traceGenerator(
          "✅ [Wormhole] Stable Alignment FOUND in ${stopwatch.elapsedMilliseconds}ms: $solution");
    }
    final warpFrequency = _calculateSideSums(solution, circlesPerSide)[0];
    traceGenerator("✨ [Wormhole] Required Warp Frequency: $warpFrequency");

    int visibleCount = _determineVisibleCount(grade, level, totalCircles);
    if (kDebugMode) {
      traceGenerator(
          "[Wormhole] Total circles: $totalCircles, Visible: $visibleCount, Hidden: ${totalCircles - visibleCount}");
    }
    final allIndices = List.generate(totalCircles, (i) => i)
      ..shuffle(generatorRandom());
    final hiddenIndices =
        allIndices.sublist(0, totalCircles - visibleCount).toSet();
    traceGenerator("[Wormhole] Hidden indices: $hiddenIndices");

    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCircles; i++) {
      if (!hiddenIndices.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }
    if (kDebugMode) traceGenerator("[Wormhole] Visible values: $visibleValues");

    final hiddenNumbers =
        allNumbers.where((n) => !visibleValues.values.contains(n)).toList();
    traceGenerator("[Wormhole] Hidden numbers: $hiddenNumbers");

    final decoyCount = _calculateDecoyCount(grade, level, hiddenNumbers.length);
    final decoyNumbers = _generateEnhancedDecoys(
        grade, level, decoyCount, allNumbers, hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)
      ..shuffle(generatorRandom());
    if (kDebugMode) {
      traceGenerator(
          "[Wormhole] Added $decoyCount enhanced decoy resonators: $decoyNumbers");
    }
    traceGenerator("[Wormhole] Final number pool for user: $numberPool");

    final puzzle = MagicTrianglePuzzle(
      circlesPerSide: circlesPerSide,
      warpFrequency: warpFrequency,
      hiddenIndices: hiddenIndices,
      visibleValues: visibleValues,
      allNumbers: allNumbers,
      numberPool: numberPool,
    );

    if (kDebugMode) {
      traceGenerator(
          "[Wormhole] ✅ Enhanced puzzle generation complete - returning puzzle");
    }
    return puzzle;
  }

  static int _determineCirclesPerSide(int grade, int level) {
    final totalDifficulty = grade + (level / 5.0);

    if (kDebugMode) {
      traceGenerator(
          "[Difficulty] Grade=$grade, Level=$level, TotalDifficulty=$totalDifficulty");
    }

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

    if (kDebugMode) {
      traceGenerator(
          "[Enhanced Difficulty] Grade $grade, Level $level, Total Circles $totalCircles");
    }
    traceGenerator(
        "[Enhanced Difficulty] Visibility Ratio: ${visibilityRatio.toStringAsFixed(2)} -> Calculated: $calculatedVisible nodes");
    traceGenerator(
        "[Enhanced Difficulty] Clamping between Min: $minVisible and Max: $maxVisible");

    return calculatedVisible.clamp(minVisible, maxVisible);
  }

  static List<int> _generateNumberSet(
      int grade, int level, int totalCircles, int attempt) {
    final random = generatorRandom();
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
    if (kDebugMode) {
      traceGenerator("[Enhanced Decoys] Generating $count decoy numbers");
    }
    final decoys = <int>{};
    final allCorrect = Set<int>.from(correctNumbers);
    final random = generatorRandom();
    final difficulty = grade + (level / 5.0);

    final minCorrect =
        correctNumbers.isNotEmpty ? correctNumbers.reduce(math.min) : 1;
    final maxCorrect =
        correctNumbers.isNotEmpty ? correctNumbers.reduce(math.max) : 10;
    final range = maxCorrect - minCorrect;

    int attempts = 0;
    while (decoys.length < count && attempts++ < count * 100) {
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
            final baseNum =
                correctNumbers[random.nextInt(correctNumbers.length)];
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
            final baseNum =
                correctNumbers[random.nextInt(correctNumbers.length)];
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

    // Ensure bounded generation even when the nearby range is exhausted.
    for (int value = maxCorrect + 1; decoys.length < count; value++) {
      if (value > 0 && !allCorrect.contains(value)) decoys.add(value);
    }
    final result = decoys.toList();
    if (kDebugMode) traceGenerator("[Enhanced Decoys] Generated: $result");
    return result;
  }

  SolutionResult checkSolution(List<int> userAnswers) {
    if (kDebugMode) traceGenerator("✅ [Puzzle] checkSolution: $userAnswers");
    final completeArrangement = List<int>.filled(totalCircles, 0);
    int hiddenIdx = 0;
    for (int i = 0; i < totalCircles; i++) {
      if (hiddenIndices.contains(i)) {
        completeArrangement[i] = userAnswers[hiddenIdx++];
      } else {
        completeArrangement[i] = visibleValues[i]!;
      }
    }
    if (kDebugMode) {
      traceGenerator("✅ [Puzzle] Complete arrangement: $completeArrangement");
    }

    final usedHidden = Set.from(userAnswers);
    final correctHidden =
        allNumbers.where((n) => !visibleValues.values.contains(n));
    if (kDebugMode) {
      traceGenerator(
          "✅ [Puzzle] Used hidden: $usedHidden, Correct hidden: $correctHidden");
    }
    if (usedHidden.length != correctHidden.length ||
        !usedHidden.containsAll(correctHidden)) {
      traceGenerator("❌ [Puzzle] Wrong numbers used");
      return SolutionResult(isValid: false, isPerfect: false);
    }

    final sideSums = _calculateSideSums(completeArrangement, circlesPerSide);
    if (kDebugMode) {
      traceGenerator("✅ [Puzzle] Side sums: $sideSums, Target: $warpFrequency");
    }
    final isPerfect = sideSums.every((sum) => sum == warpFrequency);
    traceGenerator("✅ [Puzzle] Solution result: isPerfect=$isPerfect");
    return SolutionResult(isValid: true, isPerfect: isPerfect);
  }

  static List<int> _getSideIndices(int side, int circlesPerSide) {
    final n = circlesPerSide;
    switch (side) {
      case 0:
        return List.generate(n, (i) => i);
      case 1:
        return [n - 1, ...List.generate(n - 1, (i) => n + i)];
      case 2:
        return [2 * n - 2, ...List.generate(n - 2, (i) => 2 * n - 1 + i), 0];
      default:
        return [];
    }
  }

  static List<int> _calculateSideSums(
      List<int> arrangement, int circlesPerSide) {
    final sums = <int>[];
    for (int side = 0; side < 3; side++) {
      final indices = _getSideIndices(side, circlesPerSide);
      sums.add(indices.fold(0, (acc, index) => acc + arrangement[index]));
    }
    return sums;
  }
}

class SolutionResult {
  final bool isValid;
  final bool isPerfect;
  SolutionResult({required this.isValid, required this.isPerfect});
}
