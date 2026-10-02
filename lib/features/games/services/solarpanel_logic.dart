import 'generator_random.dart';
import 'dart:math' as math;

// DEVELOPMENT TWEAKING CONSTANTS
const bool kTweakProblems = false;
const int kTweakRangeMin = 2;
const int kTweakRangeMax = 8;

class SolarPanelPuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'baseNumbers': baseNumbers.map((v0) => v0).toList(),
        'hiddenCells': hiddenCells.map((v0) => v0).toList(),
        'visibleValues':
            visibleValues.entries.map((v0) => [v0.key, v0.value]).toList(),
        'fullSolution': fullSolution.map((v0) => v0).toList(),
        'numberPool': numberPool.map((v0) => v0).toList()
      };
  factory SolarPanelPuzzle.fromJson(Map<String, dynamic> json) =>
      SolarPanelPuzzle(
          baseNumbers:
              (json['baseNumbers'] as List).map((v0) => v0 as int).toList(),
          hiddenCells:
              (json['hiddenCells'] as List).map((v0) => v0 as int).toSet(),
          visibleValues: Map<int, int>.fromEntries(
              (json['visibleValues'] as List)
                  .map((v0) => MapEntry(v0[0] as int, v0[1] as int))),
          fullSolution:
              (json['fullSolution'] as List).map((v0) => v0 as int).toList(),
          numberPool:
              (json['numberPool'] as List).map((v0) => v0 as int).toList());

  final List<int> baseNumbers; // [A, B, C]
  final Set<int> hiddenCells;
  final Map<int, int> visibleValues;
  final List<int> fullSolution; // [top, leftPanel, rightPanel, A, B, C]
  final List<int> numberPool;

  SolarPanelPuzzle({
    required this.baseNumbers,
    required this.hiddenCells,
    required this.visibleValues,
    required this.fullSolution,
    required this.numberPool,
  });

  int getAnswerIndexForCell(int cellIndex) {
    if (!hiddenCells.contains(cellIndex)) return -1;
    final sortedHiddenCells = hiddenCells.toList()..sort();
    return sortedHiddenCells.indexOf(cellIndex);
  }

  static SolarPanelPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final generator = _SolarPanelGenerator(
      grade,
      level,
      useCustomSettings: useCustomSettings,
      customRangeMin: customMin,
      customRangeMax: customMax,
    );

    return generator.generate();
  }

  bool validateSolution(List<int> userSolution) {
    final completePanel = List<int>.filled(6, 0);
    final sortedHiddenCells = hiddenCells.toList()..sort();

    for (int i = 0; i < 6; i++) {
      if (!hiddenCells.contains(i)) {
        completePanel[i] = visibleValues[i]!;
      }
    }

    for (int answerIndex = 0;
        answerIndex < userSolution.length;
        answerIndex++) {
      if (answerIndex < sortedHiddenCells.length) {
        final cellIndex = sortedHiddenCells[answerIndex];
        completePanel[cellIndex] = userSolution[answerIndex];
      }
    }

    // Validate: top = leftPanel + rightPanel
    // leftPanel = A * B, rightPanel = B * C
    final a = completePanel[3];
    final b = completePanel[4];
    final c = completePanel[5];
    final leftPanel = completePanel[1];
    final rightPanel = completePanel[2];
    final top = completePanel[0];

    return leftPanel == a * b &&
        rightPanel == b * c &&
        top == leftPanel + rightPanel;
  }
}

// Generator class
class _SolarPanelGenerator {
  final int grade;
  final int level;
  final bool useCustomSettings;
  final int customRangeMin;
  final int customRangeMax;

  _SolarPanelGenerator(
    this.grade,
    this.level, {
    required this.useCustomSettings,
    required this.customRangeMin,
    required this.customRangeMax,
  });

  SolarPanelPuzzle generate() {
    List<int>? solution;
    int attempts = 0;

    while (solution == null && attempts < 50) {
      try {
        solution = _generateValidPanel();
        if (solution != null && _validatePanel(solution)) {
          break;
        } else {
          solution = null;
        }
      } catch (e) {
        // Generation error
      }
      attempts++;
    }

    solution ??= _createFallbackPanel();

    final hiddenCells = _selectHiddenCells();

    final visibleValues = <int, int>{};
    for (int i = 0; i < 6; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }

    final hiddenNumbers = hiddenCells.map((i) => solution![i]).toList();
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)
      ..shuffle(generatorRandom());

    return SolarPanelPuzzle(
      baseNumbers: solution.sublist(3, 6),
      hiddenCells: hiddenCells,
      visibleValues: visibleValues,
      fullSolution: solution,
      numberPool: numberPool,
    );
  }

  List<int>? _generateValidPanel() {
    final random = generatorRandom();

    // Generate base numbers
    final minVal = _getMinNumber();
    final maxVal = _getMaxNumber();

    final a = minVal + random.nextInt(maxVal - minVal + 1);
    final b = minVal + random.nextInt(maxVal - minVal + 1);
    final c = minVal + random.nextInt(maxVal - minVal + 1);

    final leftPanel = a * b;
    final rightPanel = b * c;
    final top = leftPanel + rightPanel;

    return [top, leftPanel, rightPanel, a, b, c];
  }

  bool _validatePanel(List<int> solution) {
    // Check no value is too large
    if (solution.any((n) => n > 500)) return false;

    final a = solution[3];
    final b = solution[4];
    final c = solution[5];
    final leftPanel = solution[1];
    final rightPanel = solution[2];
    final top = solution[0];

    return leftPanel == a * b &&
        rightPanel == b * c &&
        top == leftPanel + rightPanel;
  }

  List<int> _createFallbackPanel() {
    return [14, 6, 8, 3, 2, 4]; // 3*2=6, 2*4=8, 6+8=14
  }

  Set<int> _selectHiddenCells() {
    final hidden = <int>{};
    final maxHidden = (2 + grade + (level / 5)).clamp(2, 5).floor();
    final candidates = List.generate(6, (i) => i)..shuffle(generatorRandom());

    // Ensure at least one base number is hidden
    final baseIndices = [3, 4, 5];
    hidden.add(baseIndices[generatorRandom().nextInt(3)]);

    // Add more random cells
    for (final cell in candidates) {
      if (hidden.length >= maxHidden) break;
      hidden.add(cell);
    }

    return hidden;
  }

  List<int> _generateDecoyNumbers(List<int> hiddenNumbers) {
    final decoys = <int>{};
    final decoyCount = (8 - hiddenNumbers.length).clamp(2, 4);

    for (final num in hiddenNumbers) {
      if (decoys.length >= decoyCount) break;
      final offset = 1 + generatorRandom().nextInt(5);
      final variations = [
        num - offset,
        num + offset,
        num * 2,
        (num / 2).round()
      ];
      for (final v in variations) {
        if (!hiddenNumbers.contains(v) && v > 0) {
          decoys.add(v);
          if (decoys.length >= decoyCount) break;
        }
      }
    }
    if (decoys.length < decoyCount) {
      final available = [
        for (var v = 1; v <= 20; v++)
          if (!decoys.contains(v) && !hiddenNumbers.contains(v)) v
      ]..shuffle(generatorRandom());
      decoys.addAll(available.take(decoyCount - decoys.length));
    }

    return decoys.toList();
  }

  int _getMinNumber() {
    if (kTweakProblems) return kTweakRangeMin;
    if (useCustomSettings) return customRangeMin;
    return math.max(1, (grade - 1) * 2 + (level / 3).floor());
  }

  int _getMaxNumber() {
    if (kTweakProblems) return kTweakRangeMax;
    if (useCustomSettings) return customRangeMax;
    return _getMinNumber() + 6 + grade * 2;
  }
}
