import 'generator_random.dart';
import 'dart:math' as math;
import 'number_wall_fallback.dart';

// DEVELOPMENT TWEAKING CONSTANTS
const bool kTweakProblems = false; // Set to true to override normal generation
const String kTweakOps =
    'subtraction'; // 'addition', 'subtraction', 'multiplication', 'division'
const int kTweakRangeMin = 2;
const int kTweakRangeMax = 8;
const int kTweakWallHeight = 4; // Override wall height when tweaking

enum WallOperation { addition, subtraction, multiplication, division }

class NumberWallPuzzle {
  Map<String, dynamic> toJson() => {
        'wallHeight': wallHeight,
        'operation': operation.name,
        'hiddenCells': hiddenCells.toList(),
        'visibleValues': visibleValues.map((k, v) => MapEntry(k.toString(), v)),
        'fullSolution': fullSolution,
        'numberPool': numberPool,
      };
  factory NumberWallPuzzle.fromJson(Map<String, dynamic> json) =>
      NumberWallPuzzle(
        wallHeight: json['wallHeight'] as int,
        operation: WallOperation.values.byName(json['operation'] as String),
        hiddenCells: Set<int>.from(json['hiddenCells'] as List),
        visibleValues: Map<String, dynamic>.from(json['visibleValues'] as Map)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        fullSolution: List<int>.from(json['fullSolution'] as List),
        numberPool: List<int>.from(json['numberPool'] as List),
      );

  final int wallHeight;
  final int totalCells;
  final WallOperation operation;
  final Set<int> hiddenCells;
  final Map<int, int> visibleValues;
  final List<int> fullSolution;
  final List<int> numberPool;

  NumberWallPuzzle({
    required this.wallHeight,
    required this.operation,
    required this.hiddenCells,
    required this.visibleValues,
    required this.fullSolution,
    required this.numberPool,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  int getAnswerIndexForCell(int cellIndex) {
    if (!hiddenCells.contains(cellIndex)) return -1;
    final sortedHiddenCells = hiddenCells.toList()..sort();
    return sortedHiddenCells.indexOf(cellIndex);
  }

  // MODIFIED: This method now inverts the wall's vertical layout for subtraction puzzles.

  static NumberWallPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps =
        (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final wallHeight = _determineWallHeight(grade, level);
    final operation =
        _determineOperation(grade, level, useCustomSettings, customOps);

    final generator = _NumberWallGenerator(
      wallHeight,
      grade,
      level,
      operation,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customRangeMin: customMin,
      customRangeMax: customMax,
    );

    return generator.generate();
  }

  static int _determineWallHeight(int grade, int level) {
    if (kTweakProblems) return kTweakWallHeight;
    if (grade >= 4) {
      if (level <= 4) return 4;
      if (level <= 8) return 5;
      return 6;
    }
    if (grade >= 3) {
      if (level <= 6) return 3;
      return 4;
    }
    return 3;
  }

  static WallOperation _determineOperation(
      int grade, int level, bool useCustom, Set<String> customOps) {
    if (kTweakProblems) {
      switch (kTweakOps.toLowerCase()) {
        case 'addition':
          return WallOperation.addition;
        case 'subtraction':
          return WallOperation.subtraction;
        case 'multiplication':
          return WallOperation.multiplication;
        case 'division':
          return WallOperation.division;
      }
    }

    if (useCustom && customOps.isNotEmpty) {
      final availableOps = customOps
          .map((op) {
            switch (op) {
              case 'addition':
                return WallOperation.addition;
              case 'subtraction':
                return WallOperation.subtraction;
              case 'multiplication':
                return WallOperation.multiplication;
              case 'division':
                return WallOperation.division;
              default:
                return null;
            }
          })
          .whereType<WallOperation>()
          .toList();

      if (availableOps.isNotEmpty) {
        return availableOps[generatorRandom().nextInt(availableOps.length)];
      }
    }

    if (grade == 1) return WallOperation.addition;
    if (grade == 2) {
      if (level <= 6) return WallOperation.addition;
      return generatorRandom().nextBool()
          ? WallOperation.addition
          : WallOperation.subtraction;
    }
    if (grade == 3) {
      final operations = [WallOperation.addition, WallOperation.subtraction];
      if (level >= 5) operations.add(WallOperation.multiplication);
      return operations[generatorRandom().nextInt(operations.length)];
    }
    final operations = [
      WallOperation.addition,
      WallOperation.subtraction,
      WallOperation.multiplication
    ];
    if (level >= 6) operations.add(WallOperation.division);
    return operations[generatorRandom().nextInt(operations.length)];
  }

  bool validateSolution(List<int> userSolution) {
    final completeWall = List<int>.filled(totalCells, 0);
    final sortedHiddenCells = hiddenCells.toList()..sort();

    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        completeWall[i] = visibleValues[i]!;
      }
    }

    for (int answerIndex = 0;
        answerIndex < userSolution.length;
        answerIndex++) {
      if (answerIndex < sortedHiddenCells.length) {
        final cellIndex = sortedHiddenCells[answerIndex];
        completeWall[cellIndex] = userSolution[answerIndex];
      }
    }

    return _validateOperationConstraints(completeWall, wallHeight, operation);
  }

  static bool _validateOperationConstraints(
      List<int> wall, int height, WallOperation operation) {
    for (int row = 0; row < height - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;

      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;

        if (rightChild < wall.length) {
          final parentValue = wall[parentCell];
          final leftValue = wall[leftChild];
          final rightValue = wall[rightChild];

          bool isValid = false;
          switch (operation) {
            case WallOperation.addition:
              isValid = parentValue == leftValue + rightValue;
              break;
            case WallOperation.subtraction:
              isValid = parentValue == (leftValue - rightValue).abs();
              break;
            case WallOperation.multiplication:
              isValid = parentValue == leftValue * rightValue;
              break;
            case WallOperation.division:
              if (leftValue != 0 && rightValue != 0) {
                final div1 = leftValue / rightValue;
                final div2 = rightValue / leftValue;
                isValid =
                    (div1 == parentValue && div1 == div1.roundToDouble()) ||
                        (div2 == parentValue && div2 == div2.roundToDouble());
              }
              break;
          }
          if (!isValid) return false;
        }
      }
    }
    return true;
  }
}

// Generator class
class _NumberWallGenerator {
  final int wallHeight;
  final int grade;
  final int level;
  final WallOperation operation;
  final int totalCells;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customRangeMin;
  final int customRangeMax;

  _NumberWallGenerator(
    this.wallHeight,
    this.grade,
    this.level,
    this.operation, {
    required this.useCustomSettings,
    required this.customOps,
    required this.customRangeMin,
    required this.customRangeMax,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  NumberWallPuzzle generate() {
    List<int>? fullSolution;
    int attempts = 0;

    while (fullSolution == null && attempts < 100) {
      try {
        final candidate = _generateValidWall();
        if (candidate != null &&
            _validateWallStructure(candidate) &&
            NumberWallPuzzle._validateOperationConstraints(
                candidate, wallHeight, operation)) {
          fullSolution = candidate;
          break;
        }
      } catch (_) {
        // Catches potential generation errors, e.g., division by zero
      }
      attempts++;
    }

    fullSolution ??= _createFallbackWall();

    final hiddenCells = _selectHiddenCells();

    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = fullSolution[i];
      }
    }

    final hiddenNumbers = hiddenCells.map((i) => fullSolution![i]).toList();
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)
      ..shuffle(generatorRandom());

    return NumberWallPuzzle(
      wallHeight: wallHeight,
      operation: operation,
      hiddenCells: hiddenCells,
      visibleValues: visibleValues,
      fullSolution: fullSolution,
      numberPool: numberPool,
    );
  }

  List<int>? _generateValidWall() {
    switch (operation) {
      case WallOperation.addition:
        return _generateAdditionWall();
      case WallOperation.subtraction:
        return _generateSubtractionWall();
      case WallOperation.multiplication:
        return _generateMultiplicationWall();
      case WallOperation.division:
        return _generateDivisionWall();
    }
  }

  List<int> _generateAdditionWall() {
    final bottomRow = List.generate(
        wallHeight,
        (_) =>
            _getMinNumber() +
            generatorRandom().nextInt(_getMaxNumber() - _getMinNumber() + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => a + b);
  }

  List<int> _generateSubtractionWall() {
    final bottomRow = List.generate(
        wallHeight,
        (_) =>
            math.max(1, _getMinNumber()) +
            generatorRandom().nextInt(_getMaxNumber() - _getMinNumber() + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => (a - b).abs());
  }

  List<int> _generateMultiplicationWall() {
    int minBase, maxBase;
    if (useCustomSettings) {
      // If the user sets max to 100, they want the top of the wall to be around 100.
      // Top of wall for height H is roughly factor^(2^(H-1)).
      // So factor = result^(1/2^(H-1)).
      double exponent = math.pow(2.0, wallHeight - 1.0).toDouble();
      double maxFactor =
          math.pow(customRangeMax.toDouble(), 1.0 / exponent).toDouble();
      minBase = customRangeMin;
      maxBase = maxFactor.floor().clamp(minBase, customRangeMax);
      // Ensure we have at least some range if customRangeMax is small
      if (maxBase == minBase && maxBase < customRangeMax && wallHeight > 2) {
        maxBase = (maxBase + 1).clamp(minBase, customRangeMax);
      }
    } else {
      minBase = math.max(1, (grade / 2).round());
      maxBase = math.max(3, (level / 2).round() + 3);
    }

    final bottomRow = List.generate(wallHeight,
        (_) => minBase + generatorRandom().nextInt(maxBase - minBase + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => a * b);
  }

  List<int>? _generateDivisionWall() {
    final wall = List<int>.filled(totalCells, 0);
    final random = generatorRandom();

    int maxTopValue = useCustomSettings ? customRangeMax * 5 : 24 + grade * 12;
    wall[0] = (12 + random.nextInt(maxTopValue)) *
        2; // Start with a highly divisible number

    for (int row = 0; row < wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;

      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;

        final parentValue = wall[parentCell];
        if (parentValue == 0) return null; // Generation failed

        // Every accepted wall is bounded at 5000. Reject growing candidates
        // before factoring; the former O(parentValue) scan could run for hours.
        if (parentValue < 1 || parentValue > 5000) return null;
        final divisors = boundedDivisionWallFactors(parentValue);
        if (divisors.isEmpty) return null;
        final rightValue = divisors[random.nextInt(divisors.length)];
        final leftValue = parentValue * rightValue;

        wall[leftChild] = leftValue;
        wall[rightChild] = rightValue;
      }
    }
    // Reverse build for division logic
    return _buildWallFromBottom(wall.sublist(wall.length - wallHeight), (a, b) {
      if (b != 0 && a % b == 0) return a ~/ b;
      if (a != 0 && b % a == 0) return b ~/ a;
      return 0; // Should not happen with this generation logic
    });
  }

  List<int> _buildWallFromBottom(
      List<int> bottomRow, int Function(int, int) operation) {
    final wall = List<int>.filled(totalCells, 0);
    final bottomRowStart = (wallHeight - 1) * wallHeight ~/ 2;
    for (int i = 0; i < wallHeight; i++) {
      wall[bottomRowStart + i] = bottomRow[i];
    }

    for (int row = wallHeight - 2; row >= 0; row--) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final currentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        if (rightChild < wall.length) {
          final value = operation(wall[leftChild], wall[rightChild]);
          if (value < 0 || value > 5000) {
            throw StateError('Wall value outside bounded range');
          }
          wall[currentCell] = value;
        }
      }
    }
    return wall;
  }

  bool _validateWallStructure(List<int> wall) {
    if (wall.any((n) => n > 5000)) {
      return false; // Prevent excessively large numbers
    }
    return NumberWallPuzzle._validateOperationConstraints(
        wall, wallHeight, operation);
  }

  List<int> _createFallbackWall() =>
      buildFallbackNumberWall(wallHeight, operation.name);

  Set<int> _selectHiddenCells() {
    final maxHidden =
        (2 + grade + (level / 5)).clamp(2, totalCells - 2).floor();
    final candidates = List.generate(totalCells, (i) => i)
      ..shuffle(generatorRandom());
    return candidates.take(maxHidden).toSet();
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
    // Tweak/Custom settings take priority
    if (kTweakProblems) return kTweakRangeMin;
    if (useCustomSettings) return customRangeMin;
    // Default dynamic calculation
    return math.max(1, (grade - 1) * 3 + (level / 2).floor());
  }

  int _getMaxNumber() {
    // Tweak/Custom settings take priority
    if (kTweakProblems) return kTweakRangeMax;
    if (useCustomSettings) return customRangeMax;
    // Default dynamic calculation
    return _getMinNumber() + 10 + grade * 2;
  }
}

/// Proper factors whose product with the parent fits the playable number cap.
List<int> boundedDivisionWallFactors(int parent, {int maximum = 5000}) {
  if (parent < 1 || parent > maximum) return [];
  final factors = <int>{};
  for (int i = 2; i * i <= parent; i++) {
    if (parent % i == 0) {
      if (parent * i <= maximum) factors.add(i);
      final other = parent ~/ i;
      if (other < parent && parent * other <= maximum) factors.add(other);
    }
  }
  if (factors.isEmpty && parent * parent <= maximum) factors.add(parent);
  return factors.toList()..sort();
}
