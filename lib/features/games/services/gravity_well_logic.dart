import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A balance scale showing objects in equilibrium.
/// Players see labeled objects and numeric weights on each side.
/// The scale is always balanced: leftTotal == rightTotal.
class BalanceScale {
  final List<ScaleItem> leftSide;
  final List<ScaleItem> rightSide;

  const BalanceScale({required this.leftSide, required this.rightSide});

  int get leftTotal => leftSide.fold(0, (sum, item) => sum + item.weight);
  int get rightTotal => rightSide.fold(0, (sum, item) => sum + item.weight);
  bool get isBalanced => leftTotal == rightTotal;
}

/// An item on a scale: either a labeled object (A, B, C...) or a
/// numeric weight block ("5 kg"). [isKnown] means the weight is
/// directly visible to the player.
class ScaleItem {
  final String label;
  final int weight;
  final bool isKnown;

  const ScaleItem({
    required this.label,
    required this.weight,
    required this.isKnown,
  });
}

class GravityWellPuzzle {
  final List<BalanceScale> scales;
  final Map<String, int> unknownWeights; // label -> weight (answers)
  final Map<String, int> knownWeights;   // label -> weight (given)
  final int objectCount;

  const GravityWellPuzzle({
    required this.scales,
    required this.unknownWeights,
    required this.knownWeights,
    required this.objectCount,
  });

  bool checkSolution(Map<String, int> userAnswers) {
    for (final entry in unknownWeights.entries) {
      if (userAnswers[entry.key] != entry.value) return false;
    }
    return true;
  }
}

class GravityWellLogic {
  static GravityWellPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    if (kDebugMode) debugPrint('[GRAVITY_WELL] Generating grade=$grade level=$level');

    // Difficulty parameters
    int objectCount, scaleCount, maxWeight;

    if (difficulty.grade <= 1) {
      objectCount = 3;   // A, B, C -- one unknown
      scaleCount = 2;
      maxWeight = 10;
    } else if (difficulty.grade <= 2) {
      objectCount = 3;
      scaleCount = 2;
      maxWeight = 15;
    } else if (difficulty.grade <= 3) {
      objectCount = 4;
      scaleCount = 3;
      maxWeight = 20;
    } else {
      objectCount = 5;
      scaleCount = 3 + (level > 10 ? 1 : 0);
      maxWeight = 25;
    }

    // How many unknowns to solve for
    final unknownCount = (difficulty.grade <= 1) ? 1
        : (difficulty.grade <= 2) ? (level <= 5 ? 1 : 2)
        : (difficulty.grade <= 3) ? 2
        : (level <= 5 ? 2 : 3);

    for (int attempt = 0; attempt < 30; attempt++) {
      final result = _tryGenerate(
        objectCount, scaleCount, unknownCount, maxWeight, rng,
      );
      if (result != null) return result;
    }

    // Fallback: A=3, B=5, C=8. Scale 1: A+B = C. Scale 2: C = A+B.
    // Unknown: C. Known: A=3, B=5.
    if (kDebugMode) debugPrint('[GRAVITY_WELL] Using fallback puzzle');
    return const GravityWellPuzzle(
      scales: [
        BalanceScale(leftSide: [
          ScaleItem(label: 'A', weight: 3, isKnown: true),
          ScaleItem(label: 'B', weight: 5, isKnown: true),
        ], rightSide: [
          ScaleItem(label: 'C', weight: 8, isKnown: false),
        ]),
        BalanceScale(leftSide: [
          ScaleItem(label: 'C', weight: 8, isKnown: false),
          ScaleItem(label: '2 kg', weight: 2, isKnown: true),
        ], rightSide: [
          ScaleItem(label: 'A', weight: 3, isKnown: true),
          ScaleItem(label: 'B', weight: 5, isKnown: true),
          ScaleItem(label: '2 kg', weight: 2, isKnown: true),
        ]),
      ],
      unknownWeights: {'C': 8},
      knownWeights: {'A': 3, 'B': 5},
      objectCount: 3,
    );
  }

  static GravityWellPuzzle? _tryGenerate(
    int objectCount, int scaleCount, int unknownCount,
    int maxWeight, math.Random rng,
  ) {
    // Generate distinct weights for each object
    final labels = List.generate(objectCount, (i) => String.fromCharCode(65 + i));
    final weights = <String, int>{};
    final usedWeights = <int>{};
    for (final label in labels) {
      int w;
      int tries = 0;
      do {
        w = rng.nextInt(maxWeight - 1) + 2; // 2 to maxWeight
        tries++;
      } while (usedWeights.contains(w) && tries < 50);
      usedWeights.add(w);
      weights[label] = w;
    }

    // Pick unknowns
    final shuffled = List<String>.from(labels)..shuffle(rng);
    final unknownLabels = shuffled.take(unknownCount).toSet();
    final knownLabels = labels.where((l) => !unknownLabels.contains(l)).toSet();

    final knownWeights = <String, int>{};
    final unknownWeights = <String, int>{};
    for (final l in labels) {
      if (unknownLabels.contains(l)) {
        unknownWeights[l] = weights[l]!;
      } else {
        knownWeights[l] = weights[l]!;
      }
    }

    // Build scales that require multi-step reasoning.
    // Strategy: for 1 unknown, one scale with that unknown and known items
    // is fine (but mix with known items on both sides). For 2+ unknowns,
    // create scales that pair unknowns together so the player must combine
    // information across scales to solve.
    final scales = <BalanceScale>[];
    final unknownList = unknownLabels.toList()..shuffle(rng);
    final knownList = knownLabels.toList()..shuffle(rng);

    if (unknownCount == 1) {
      // Single unknown: put it on one side with a known object,
      // and known objects (+ weight block) on the other.
      final target = unknownList[0];
      final targetW = weights[target]!;

      // Pick 1-2 known objects for the other side
      final otherCount = math.min(1 + rng.nextInt(2), knownList.length);
      final otherLabels = knownList.take(otherCount).toList();
      final otherWeight = otherLabels.fold(0, (s, l) => s + weights[l]!);

      // Optionally add a known object next to the unknown
      final sameCount = knownList.length > otherCount ? 1 : 0;
      final sameLabels = sameCount > 0 ? [knownList[otherCount]] : <String>[];
      final sameWeight = sameLabels.fold(0, (s, l) => s + weights[l]!);

      final leftW = targetW + sameWeight;
      final rightW = otherWeight;
      final diff = leftW - rightW;

      final left = <ScaleItem>[
        ScaleItem(label: target, weight: targetW, isKnown: false),
        ...sameLabels.map((l) => ScaleItem(label: l, weight: weights[l]!, isKnown: true)),
      ];
      final right = <ScaleItem>[
        ...otherLabels.map((l) => ScaleItem(label: l, weight: weights[l]!, isKnown: true)),
      ];

      if (diff > 0) {
        right.add(ScaleItem(label: '$diff kg', weight: diff, isKnown: true));
      } else if (diff < 0) {
        left.add(ScaleItem(label: '${-diff} kg', weight: -diff, isKnown: true));
      }

      scales.add(BalanceScale(leftSide: left, rightSide: right));
    } else {
      // Multiple unknowns: pair unknowns on shared scales so no single
      // scale fully solves any unknown. The player must reason across scales.
      //
      // Scale 1: Unknown_A + Known_X = Unknown_B + weightBlock
      //   => gives relationship: A - B = constant
      // Scale 2: Unknown_A + Known_Y = weightBlock
      //   => directly solvable for A, then B from scale 1
      // For 3 unknowns, add a third scale with B + C.

      // First scale: pair first two unknowns on opposite sides
      final uA = unknownList[0];
      final uB = unknownList[1];
      final wA = weights[uA]!;
      final wB = weights[uB]!;

      // Add a known object to one side for variety
      final knownForScale1 = knownList.isNotEmpty ? knownList[0] : null;
      final kW1 = knownForScale1 != null ? weights[knownForScale1]! : 0;

      final leftW1 = wA + kW1;
      final rightW1 = wB;
      final diff1 = leftW1 - rightW1;

      final left1 = <ScaleItem>[
        ScaleItem(label: uA, weight: wA, isKnown: false),
        if (knownForScale1 != null)
          ScaleItem(label: knownForScale1, weight: kW1, isKnown: true),
      ];
      final right1 = <ScaleItem>[
        ScaleItem(label: uB, weight: wB, isKnown: false),
      ];
      if (diff1 > 0) {
        right1.add(ScaleItem(label: '$diff1 kg', weight: diff1, isKnown: true));
      } else if (diff1 < 0) {
        left1.add(ScaleItem(label: '${-diff1} kg', weight: -diff1, isKnown: true));
      }
      scales.add(BalanceScale(leftSide: left1, rightSide: right1));

      // Second scale: one unknown + known objects = weight block
      // This makes that unknown individually solvable, then the first scale
      // lets the player compute the other unknown.
      final knownForScale2 = knownList.length > 1 ? knownList[1] : knownForScale1;
      final kW2 = knownForScale2 != null ? weights[knownForScale2]! : 0;

      final leftW2 = wA;
      final rightW2 = kW2;
      final diff2 = leftW2 - rightW2;

      final left2 = <ScaleItem>[
        ScaleItem(label: uA, weight: wA, isKnown: false),
      ];
      final right2 = <ScaleItem>[
        if (knownForScale2 != null)
          ScaleItem(label: knownForScale2, weight: kW2, isKnown: true),
      ];
      if (diff2 > 0) {
        right2.add(ScaleItem(label: '$diff2 kg', weight: diff2, isKnown: true));
      } else if (diff2 < 0) {
        left2.add(ScaleItem(label: '${-diff2} kg', weight: -diff2, isKnown: true));
      }
      scales.add(BalanceScale(leftSide: left2, rightSide: right2));

      // Third unknown (if any): pair with B on a scale
      if (unknownList.length >= 3) {
        final uC = unknownList[2];
        final wC = weights[uC]!;
        final diff3 = wB - wC;

        final left3 = <ScaleItem>[
          ScaleItem(label: uB, weight: wB, isKnown: false),
        ];
        final right3 = <ScaleItem>[
          ScaleItem(label: uC, weight: wC, isKnown: false),
        ];
        if (diff3 > 0) {
          right3.add(ScaleItem(label: '$diff3 kg', weight: diff3, isKnown: true));
        } else if (diff3 < 0) {
          left3.add(ScaleItem(label: '${-diff3} kg', weight: -diff3, isKnown: true));
        }
        scales.add(BalanceScale(leftSide: left3, rightSide: right3));
      }
    }

    // Fill remaining scale slots with mixed scales that include unknowns
    // alongside known objects — these provide cross-checks, not freebies.
    while (scales.length < scaleCount) {
      final allLabels = List<String>.from(labels)..shuffle(rng);
      final split = 1 + rng.nextInt(math.max(1, allLabels.length - 1));
      final left = allLabels.take(split).toList();
      final right = allLabels.skip(split).toList();

      if (left.isEmpty || right.isEmpty) continue;

      // Ensure this extra scale has at least one unknown on each side
      // (or is genuinely interesting) — skip if it's all-known.
      final leftHasUnknown = left.any(unknownLabels.contains);
      final rightHasUnknown = right.any(unknownLabels.contains);
      if (!leftHasUnknown && !rightHasUnknown) continue;

      final leftWeight = left.fold(0, (s, l) => s + weights[l]!);
      final rightWeight = right.fold(0, (s, l) => s + weights[l]!);
      final diff = leftWeight - rightWeight;

      final leftItems = left.map((l) => ScaleItem(
        label: l, weight: weights[l]!,
        isKnown: knownLabels.contains(l),
      )).toList();
      final rightItems = right.map((l) => ScaleItem(
        label: l, weight: weights[l]!,
        isKnown: knownLabels.contains(l),
      )).toList();

      if (diff > 0) {
        rightItems.add(ScaleItem(label: '$diff kg', weight: diff, isKnown: true));
      } else if (diff < 0) {
        leftItems.add(ScaleItem(label: '${-diff} kg', weight: -diff, isKnown: true));
      }

      scales.add(BalanceScale(leftSide: leftItems, rightSide: rightItems));
    }

    // Verify all scales balance
    for (final s in scales) {
      if (!s.isBalanced) return null;
    }

    // Shuffle scale order so the "solving chain" isn't obvious
    scales.shuffle(rng);

    return GravityWellPuzzle(
      scales: scales,
      unknownWeights: unknownWeights,
      knownWeights: knownWeights,
      objectCount: objectCount,
    );
  }
}
