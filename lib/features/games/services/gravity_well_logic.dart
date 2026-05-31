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

    debugPrint('[GRAVITY_WELL] Generating grade=$grade level=$level');

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
    debugPrint('[GRAVITY_WELL] Using fallback puzzle');
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

    // Build scales that form a solvable system.
    // Strategy: create a chain of equations where each scale introduces
    // or constrains exactly one unknown using known objects and previously
    // solved unknowns.
    final scales = <BalanceScale>[];
    final solvedUnknowns = <String>{};
    final unknownList = unknownLabels.toList()..shuffle(rng);

    for (int i = 0; i < unknownList.length && scales.length < scaleCount; i++) {
      final target = unknownList[i];
      final targetWeight = weights[target]!;

      // Build a scale where 'target' is on one side and known/solved
      // objects are on the other, possibly with numeric weight blocks.
      final availableKnown = <String>[
        ...knownLabels,
        ...solvedUnknowns,
      ]..shuffle(rng);

      // Pick 1-2 known objects for the other side
      final otherSideLabels = <String>[];
      int otherSideWeight = 0;
      final howMany = math.min(1 + rng.nextInt(2), availableKnown.length);
      for (int j = 0; j < howMany; j++) {
        otherSideLabels.add(availableKnown[j]);
        otherSideWeight += weights[availableKnown[j]]!;
      }

      if (otherSideLabels.isEmpty) continue;

      // The difference must be bridged by a numeric weight block
      final diff = targetWeight - otherSideWeight;

      final leftSide = <ScaleItem>[
        ScaleItem(label: target, weight: targetWeight, isKnown: false),
      ];
      final rightSide = <ScaleItem>[
        ...otherSideLabels.map((l) => ScaleItem(
          label: l,
          weight: weights[l]!,
          isKnown: knownLabels.contains(l),
        )),
      ];

      if (diff > 0) {
        // Right side is lighter, add weight block to right
        rightSide.add(ScaleItem(
          label: '$diff kg',
          weight: diff,
          isKnown: true,
        ));
      } else if (diff < 0) {
        // Left side is lighter, add weight block to left
        leftSide.add(ScaleItem(
          label: '${-diff} kg',
          weight: -diff,
          isKnown: true,
        ));
      }
      // diff == 0: perfectly balanced without extra weights

      scales.add(BalanceScale(leftSide: leftSide, rightSide: rightSide));
      solvedUnknowns.add(target);
    }

    // Add extra "redundant" scales for flavor and to make it feel richer.
    // These mix known and already-solved objects in interesting combos.
    while (scales.length < scaleCount) {
      final allLabels = List<String>.from(labels)..shuffle(rng);
      // Split into two groups
      final split = 1 + rng.nextInt(math.max(1, allLabels.length - 1));
      final left = allLabels.take(split).toList();
      final right = allLabels.skip(split).toList();

      if (left.isEmpty || right.isEmpty) continue;

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
