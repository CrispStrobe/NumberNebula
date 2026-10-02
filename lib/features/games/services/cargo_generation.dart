import 'dart:math' as math;
import 'generator_random.dart';

class CargoCube {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {'value': value, 'color': color};
  factory CargoCube.fromJson(Map<String, dynamic> json) =>
      CargoCube(value: json['value'] as int, color: json['color'] as int);

  final int value;
  final int color;

  CargoCube({required this.value, required this.color});
}

/// Tetris-style "7-bag" shape randomizer.
///
/// Drawing each shape independently at random gives long droughts — a player
/// can go a dozen pieces without the straight bar they need. The 7-bag deals a
/// shuffled permutation of all shapes before reshuffling, so every shape shows
/// up once per bag: same variety, no unfair runs. Seed it for a reproducible
/// sequence (daily runs, tests).
class CargoShapeBag {
  Map<String, dynamic> toJson() => {'remaining': List<int>.from(_bag)};
  factory CargoShapeBag.fromJson(Map<String, dynamic> json) =>
      CargoShapeBag().._bag.addAll(List<int>.from(json['remaining'] as List));

  final math.Random _random;
  final List<int> _bag = [];

  CargoShapeBag({math.Random? random, int? seed})
      : _random = random ?? generatorRandom(seed);

  /// Next shape index, refilling and reshuffling the bag when it runs out.
  int next(int shapeCount) {
    if (shapeCount <= 0) return 0;
    if (_bag.isEmpty) {
      _bag.addAll(List.generate(shapeCount, (i) => i)..shuffle(_random));
    }
    return _bag.removeLast();
  }
}

class CargoPiece {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'shape': shape.map((v0) => v0.map((v1) => v1).toList()).toList(),
        'cubes':
            cubes.map((v0) => v0.map((v1) => (v1?.toJson())).toList()).toList()
      };
  factory CargoPiece.fromJson(Map<String, dynamic> json) => CargoPiece(
      x: json['x'] as int,
      y: json['y'] as int,
      shape: (json['shape'] as List)
          .map((v0) => (v0 as List).map((v1) => v1 as bool).toList())
          .toList(),
      cubes: (json['cubes'] as List)
          .map((v0) => (v0 as List)
              .map((v1) => (v1 == null
                  ? null
                  : CargoCube.fromJson(Map<String, dynamic>.from(v1 as Map))))
              .toList())
          .toList());

  int x, y;
  List<List<bool>> shape;
  List<List<CargoCube?>> cubes;

  CargoPiece(
      {required this.x,
      required this.y,
      required this.shape,
      required this.cubes});

  /// The seven tetromino shapes, in the order their colours are assigned.
  static const List<List<List<bool>>> shapes = [
    [
      [false, false, false, false],
      [true, true, true, true],
      [false, false, false, false],
      [false, false, false, false]
    ],
    [
      [true, true],
      [true, true]
    ],
    [
      [false, true, false],
      [true, true, true],
      [false, false, false]
    ],
    [
      [false, false, true],
      [true, true, true],
      [false, false, false]
    ],
    [
      [true, false, false],
      [true, true, true],
      [false, false, false]
    ],
    [
      [false, true, true],
      [true, true, false],
      [false, false, false]
    ],
    [
      [true, true, false],
      [false, true, true],
      [false, false, false]
    ],
  ];

  /// Number of distinct shapes — the size of one [CargoShapeBag] bag.
  static int get shapeCount => shapes.length;

  static CargoPiece random(
    int minValue,
    int maxValue,
    int gridCols, {
    // When set, [targetSumChance] of pieces are biased so a full row can reach
    // this sum; [sequenceChance] of pieces are emitted as a consecutive run.
    // Defaults keep the legacy pure-uniform behaviour.
    int? targetSum,
    double sequenceChance = 0.0,
    double targetSumChance = 0.0,
    // Shape to build. Pass one from a [CargoShapeBag] for fair distribution;
    // omitted means "pick uniformly at random", the legacy behaviour.
    int? shapeIndex,
    // Injectable source of randomness, so a run can be reproduced.
    math.Random? random,
  }) {
    final rng = random ?? generatorRandom();

    const colors = [
      0xFF4DD0E1,
      0xFFFFEE58,
      0xFFBA68C8,
      0xFFFFA726,
      0xFF64B5F6,
      0xFF81C784,
      0xFFE57373
    ];

    final pickedIndex =
        (shapeIndex ?? rng.nextInt(shapes.length)) % shapes.length;
    final shape = shapes[pickedIndex];
    final color = colors[pickedIndex % colors.length];

    // Values for the filled cells, in row-major order.
    final filledCount =
        shape.fold<int>(0, (n, row) => n + row.where((c) => c).length);
    final values = _pieceValues(
      rng,
      minValue,
      maxValue,
      gridCols,
      filledCount,
      targetSum: targetSum,
      sequenceChance: sequenceChance,
      targetSumChance: targetSumChance,
    );

    var k = 0;
    final cubes = List.generate(
        shape.length,
        (i) => List.generate(shape[i].length, (j) {
              if (shape[i][j]) {
                return CargoCube(value: values[k++], color: color);
              }
              return null;
            }));

    return CargoPiece(
      x: (gridCols ~/ 2) - (shape[0].length ~/ 2),
      y: -2,
      shape: shape,
      cubes: cubes,
    );
  }

  /// Builds the [count] cube values for a piece's filled cells.
  ///
  /// The legacy generator drew every value i.i.d. uniform over [min,max], which
  /// is decoupled from the game's whole point — the targetSum / consecutive /
  /// doubling / fibonacci bonuses essentially never fired by chance. We now,
  /// with the given probabilities, emit values that give the player a real shot
  /// at those bonuses:
  ///   * a consecutive run (n, n+1, ... or reversed) for the sequence bonuses;
  ///   * values clustered around targetSum/gridCols so a row can hit the target.
  /// Every returned value is guaranteed to lie within [min,max] (so the
  /// arithmetic stays valid and the unit-test invariant holds).
  static List<int> _pieceValues(
    math.Random random,
    int min,
    int max,
    int gridCols,
    int count, {
    int? targetSum,
    double sequenceChance = 0.0,
    double targetSumChance = 0.0,
  }) {
    final span = max - min + 1;
    final roll = random.nextDouble();

    // Consecutive run — only when the range is wide enough to hold one.
    if (roll < sequenceChance && count >= 1 && span >= count) {
      final start = min + random.nextInt(span - count + 1);
      final run = List.generate(count, (i) => start + i);
      return random.nextBool() ? run.reversed.toList() : run;
    }

    // Target-sum biasing: cluster around the per-cell average for a full row.
    if (targetSum != null &&
        gridCols > 0 &&
        roll < sequenceChance + targetSumChance) {
      final center = (targetSum / gridCols).round().clamp(min, max);
      return List.generate(count, (_) {
        final v = center + (random.nextInt(3) - 1); // center +/- 1
        return v.clamp(min, max);
      });
    }

    // Default: uniform over the full range.
    return List.generate(count, (_) => min + random.nextInt(span));
  }
}

/// Same bands in the live game, pure generation and dynamic calibration.
class CargoGenerationConfig {
  final int band;
  CargoGenerationConfig(int grade, int level)
      : band = ((grade + level / 5).ceil() - 2).clamp(0, 6);
  int get numberMin => const [1, 1, 1, 1, 2, 3, 5][band];
  int get numberMax => const [5, 7, 9, 12, 15, 18, 20][band];
  int get targetSum => const [15, 21, 28, 36, 48, 60, 75][band];
  int get dropSpeed => 1000 - band * 100;
  int get rowsToWin => 8 + band * 2;
}
