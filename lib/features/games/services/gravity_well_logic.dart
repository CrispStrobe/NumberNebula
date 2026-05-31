import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A balance scale showing objects in equilibrium
class BalanceScale {
  final List<ScaleItem> leftSide;
  final List<ScaleItem> rightSide;

  const BalanceScale({required this.leftSide, required this.rightSide});

  int get leftTotal => leftSide.fold(0, (sum, item) => sum + item.weight);
  int get rightTotal => rightSide.fold(0, (sum, item) => sum + item.weight);
  bool get isBalanced => leftTotal == rightTotal;
}

/// An item on a scale, either known or unknown weight
class ScaleItem {
  final String label; // e.g., 'A', 'B', 'C'
  final int weight;
  final bool isKnown; // whether weight is shown to player

  const ScaleItem({
    required this.label,
    required this.weight,
    required this.isKnown,
  });
}

class GravityWellPuzzle {
  final List<BalanceScale> scales;
  final Map<String, int> unknownWeights; // label -> weight (the answers)
  final Map<String, int> knownWeights; // label -> weight (shown to player)
  final int objectCount;

  const GravityWellPuzzle({
    required this.scales,
    required this.unknownWeights,
    required this.knownWeights,
    required this.objectCount,
  });

  /// Check if user's answers match the unknown weights
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

    debugPrint('[GRAVITY_WELL] Generating puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int objectCount;
    int scaleCount;
    int maxWeight;

    if (difficulty.grade <= 1) {
      objectCount = 2;
      scaleCount = 1;
      maxWeight = 10;
    } else if (difficulty.grade <= 2) {
      objectCount = level <= 5 ? 2 : 3;
      scaleCount = level <= 5 ? 1 : 2;
      maxWeight = 15;
    } else if (difficulty.grade <= 3) {
      objectCount = level <= 3 ? 3 : 4;
      scaleCount = level <= 3 ? 2 : 3;
      maxWeight = 20;
    } else {
      objectCount = level <= 5 ? 4 : 5;
      scaleCount = level <= 5 ? 3 : 4;
      maxWeight = level <= 10 ? 20 : 30;
    }

    // Generate object labels and weights
    final labels = List.generate(objectCount, (i) => String.fromCharCode(65 + i)); // A, B, C, ...
    final weights = <String, int>{};
    for (final label in labels) {
      weights[label] = rng.nextInt(maxWeight - 1) + 1; // 1 to maxWeight
    }

    // Decide which objects are unknown (at least 1)
    final unknownCount = (objectCount * 0.5).ceil().clamp(1, objectCount - 1);
    final shuffledLabels = List<String>.from(labels)..shuffle(rng);
    final unknownLabels = shuffledLabels.take(unknownCount).toSet();

    final knownWeights = <String, int>{};
    final unknownWeights = <String, int>{};
    for (final label in labels) {
      if (unknownLabels.contains(label)) {
        unknownWeights[label] = weights[label]!;
      } else {
        knownWeights[label] = weights[label]!;
      }
    }

    debugPrint('[GRAVITY_WELL] Weights: $weights, Unknown: ${unknownWeights.keys}');

    // Generate scales that help solve the unknowns
    final scales = _generateScales(
      labels, weights, knownWeights, unknownWeights,
      scaleCount, objectCount, rng, maxWeight,
    );

    return GravityWellPuzzle(
      scales: scales,
      unknownWeights: unknownWeights,
      knownWeights: knownWeights,
      objectCount: objectCount,
    );
  }

  static List<BalanceScale> _generateScales(
    List<String> labels,
    Map<String, int> weights,
    Map<String, int> knownWeights,
    Map<String, int> unknownWeights,
    int scaleCount,
    int objectCount,
    math.Random rng,
    int maxWeight,
  ) {
    final scales = <BalanceScale>[];

    // Strategy: each scale must help deduce at least one unknown.
    // For simple puzzles: put unknown on one side, known weight on other.
    // For harder puzzles: combine known + unknown objects.

    final unknownList = unknownWeights.keys.toList();
    final knownList = knownWeights.keys.toList();

    for (int s = 0; s < scaleCount; s++) {
      List<ScaleItem> leftSide;
      List<ScaleItem> rightSide;

      if (s < unknownList.length && knownList.isNotEmpty) {
        // Simple scale: one unknown on left, balance with known weight on right
        final unknownLabel = unknownList[s % unknownList.length];
        final unknownWeight = weights[unknownLabel]!;

        leftSide = [
          ScaleItem(label: unknownLabel, weight: unknownWeight, isKnown: false),
        ];

        // Add a numeric weight on the right side to balance
        rightSide = [
          ScaleItem(
            label: '$unknownWeight kg',
            weight: unknownWeight,
            isKnown: true,
          ),
        ];

        // For harder puzzles, add a known object to both sides
        if (objectCount >= 3 && knownList.isNotEmpty && s > 0) {
          final knownLabel = knownList[rng.nextInt(knownList.length)];
          final knownWeight = weights[knownLabel]!;

          leftSide.add(
            ScaleItem(label: knownLabel, weight: knownWeight, isKnown: true),
          );
          // Add equivalent weight to right
          rightSide = [
            ScaleItem(
              label: '${unknownWeight + knownWeight} kg',
              weight: unknownWeight + knownWeight,
              isKnown: true,
            ),
          ];
        }
      } else {
        // Create a mixed scale with multiple objects
        final availableLabels = List<String>.from(labels)..shuffle(rng);
        final leftLabels = availableLabels.take((objectCount / 2).ceil()).toList();
        final rightLabels = availableLabels.skip((objectCount / 2).ceil()).toList();

        final leftTotal = leftLabels.fold(0, (sum, l) => sum + weights[l]!);
        final rightTotal = rightLabels.fold(0, (sum, l) => sum + weights[l]!);

        leftSide = leftLabels
            .map((l) => ScaleItem(
                  label: l,
                  weight: weights[l]!,
                  isKnown: !unknownWeights.containsKey(l),
                ))
            .toList();

        // Balance with a numeric weight
        if (leftTotal > rightTotal) {
          rightSide = rightLabels
              .map((l) => ScaleItem(
                    label: l,
                    weight: weights[l]!,
                    isKnown: !unknownWeights.containsKey(l),
                  ))
              .toList();
          rightSide.add(ScaleItem(
            label: '${leftTotal - rightTotal} kg',
            weight: leftTotal - rightTotal,
            isKnown: true,
          ));
        } else {
          rightSide = rightLabels
              .map((l) => ScaleItem(
                    label: l,
                    weight: weights[l]!,
                    isKnown: !unknownWeights.containsKey(l),
                  ))
              .toList();
          if (rightTotal > leftTotal) {
            leftSide.add(ScaleItem(
              label: '${rightTotal - leftTotal} kg',
              weight: rightTotal - leftTotal,
              isKnown: true,
            ));
          }
        }
      }

      scales.add(BalanceScale(leftSide: leftSide, rightSide: rightSide));
    }

    debugPrint('[GRAVITY_WELL] Generated ${scales.length} scales');
    return scales;
  }
}
