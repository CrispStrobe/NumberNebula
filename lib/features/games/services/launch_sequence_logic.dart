import 'algorithm_path.dart';
import 'generator_random.dart';
// lib/features/games/services/launch_sequence_logic.dart
//
// Sorting puzzle: reorder a shuffled sequence using adjacent swaps.
// Score by proximity to optimal swap count (= number of inversions = bubble sort count).

class LaunchSequencePuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'sequence': sequence.map((v0) => v0).toList(),
        'target': target.map((v0) => v0).toList(),
        'optimalSwaps': optimalSwaps
      };
  factory LaunchSequencePuzzle.fromJson(Map<String, dynamic> json) =>
      LaunchSequencePuzzle(
          sequence: (json['sequence'] as List).map((v0) => v0 as int).toList(),
          target: (json['target'] as List).map((v0) => v0 as int).toList(),
          optimalSwaps: json['optimalSwaps'] as int);

  final List<int> sequence; // shuffled
  final List<int> target; // sorted order
  final int optimalSwaps; // minimum swaps needed (inversion count)

  LaunchSequencePuzzle({
    required this.sequence,
    required this.target,
    required this.optimalSwaps,
  });

  /// Count inversions in a permutation (= optimal adjacent swap count).
  static int countInversions(List<int> arr) {
    int inversions = 0;
    for (int i = 0; i < arr.length; i++) {
      for (int j = i + 1; j < arr.length; j++) {
        if (arr[i] > arr[j]) inversions++;
      }
    }
    return inversions;
  }

  /// Generate a shuffled sequence with a guaranteed minimum number of inversions.
  static LaunchSequencePuzzle generate({
    required int itemCount,
    required int minInversions,
    int? seed,
  }) {
    final maxInversions = itemCount * (itemCount - 1) ~/ 2;
    if (itemCount < 2 || minInversions < 0 || minInversions > maxInversions) {
      throw ArgumentError(
          'At least two items and attainable inversion count required');
    }
    if (algorithmPath != AlgorithmPath.legacy) {
      final rng = generatorRandom(seed);
      final target = List.generate(itemCount, (i) => i + 1);
      final remaining = List<int>.from(target);
      final sequence = <int>[];
      var inversionsLeft = minInversions == 0 ? 1 : minInversions;
      // Construct a feasible Lehmer code. Each chosen rank contributes exactly
      // that many inversions; reserve enough capacity for the remaining suffix.
      while (remaining.isNotEmpty) {
        final n = remaining.length;
        final capacity = (n - 1) * (n - 2) ~/ 2;
        final lower = (inversionsLeft - capacity).clamp(0, n - 1);
        final upper = inversionsLeft.clamp(0, n - 1);
        final rank = lower + rng.nextInt(upper - lower + 1);
        sequence.add(remaining.removeAt(rank));
        inversionsLeft -= rank;
      }
      recordAlgorithm('launch-sequence', 'candidate-exact-inversions');
      return LaunchSequencePuzzle(
          sequence: sequence,
          target: target,
          optimalSwaps: countInversions(sequence));
    }
    recordAlgorithm('launch-sequence', 'legacy-random-shuffle');
    final rng = generatorRandom(seed);
    final target = List.generate(itemCount, (i) => i + 1);

    for (int attempt = 0; attempt < 200; attempt++) {
      final sequence = List<int>.from(target)..shuffle(rng);
      final inversions = countInversions(sequence);

      if (inversions >= minInversions && inversions > 0) {
        return LaunchSequencePuzzle(
          sequence: sequence,
          target: target,
          optimalSwaps: inversions,
        );
      }
    }

    // Fallback: manually create inversions by swapping from sorted
    final sequence = List<int>.from(target);
    int swapsDone = 0;
    while (swapsDone < minInversions) {
      final i = rng.nextInt(itemCount - 1);
      if (sequence[i] < sequence[i + 1]) {
        final temp = sequence[i];
        sequence[i] = sequence[i + 1];
        sequence[i + 1] = temp;
        swapsDone++;
      }
    }

    return LaunchSequencePuzzle(
      sequence: sequence,
      target: target,
      optimalSwaps: countInversions(sequence),
    );
  }

  /// Check if sequence is sorted.
  static bool isSorted(List<int> sequence) {
    for (int i = 0; i < sequence.length - 1; i++) {
      if (sequence[i] > sequence[i + 1]) return false;
    }
    return true;
  }
}

/// Shared by app and CLI: legacy retains its original floors; candidates use
/// deliberate, nondecreasing swap targets without changing reward formulas.
class LaunchSequenceGenerationConfig {
  final int grade, level;
  LaunchSequenceGenerationConfig(int grade, int level)
      : grade = grade.clamp(1, 6),
        level = level.clamp(1, 20);
  int get itemCount => grade <= 1
      ? 4
      : grade <= 2
          ? 5
          : (6 + level ~/ 5).clamp(6, 8);
  int get inversions {
    if (algorithmPath == AlgorithmPath.legacy) {
      return grade <= 1
          ? 2
          : grade <= 2
              ? 3
              : (4 + level ~/ 3).clamp(4, 15);
    }
    final count = grade <= 1
        ? 2 + (level - 1) * 3 ~/ 19
        : grade <= 2
            ? 3 + (level - 1) * 5 ~/ 19
            : 5 + (grade - 3) * 2 + (level - 1) * (9 + grade - 3) ~/ 19;
    return count.clamp(1, itemCount * (itemCount - 1) ~/ 2);
  }
}
