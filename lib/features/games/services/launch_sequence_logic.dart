// lib/features/games/services/launch_sequence_logic.dart
//
// Sorting puzzle: reorder a shuffled sequence using adjacent swaps.
// Score by proximity to optimal swap count (= number of inversions = bubble sort count).

import 'dart:math' as math;

class LaunchSequencePuzzle {
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
    final rng = math.Random(seed);
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
