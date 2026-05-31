// Unit tests for launch_sequence_logic.dart.
//
// Tests the sorting puzzle logic: inversion counting, shuffled sequence
// generation, sorted-state detection, and generated puzzle invariants.
// The generator uses an unseeded Random, so we assert structural invariants
// over multiple seeded generations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/launch_sequence_logic.dart';

void main() {
  group('LaunchSequencePuzzle.countInversions', () {
    test('sorted array has 0 inversions', () {
      expect(LaunchSequencePuzzle.countInversions([1, 2, 3, 4, 5]), 0);
    });

    test('reverse-sorted array has maximum inversions', () {
      // [5,4,3,2,1] -> n*(n-1)/2 = 10 inversions
      expect(LaunchSequencePuzzle.countInversions([5, 4, 3, 2, 1]), 10);
    });

    test('single swap creates exactly 1 inversion', () {
      // [1, 3, 2, 4] -> only (3,2) is an inversion
      expect(LaunchSequencePuzzle.countInversions([1, 3, 2, 4]), 1);
    });

    test('[2, 1, 3] has 1 inversion', () {
      expect(LaunchSequencePuzzle.countInversions([2, 1, 3]), 1);
    });

    test('[3, 1, 2] has 2 inversions', () {
      expect(LaunchSequencePuzzle.countInversions([3, 1, 2]), 2);
    });

    test('single element has 0 inversions', () {
      expect(LaunchSequencePuzzle.countInversions([42]), 0);
    });

    test('empty array has 0 inversions', () {
      expect(LaunchSequencePuzzle.countInversions([]), 0);
    });

    test('two-element inversed pair has 1 inversion', () {
      expect(LaunchSequencePuzzle.countInversions([2, 1]), 1);
    });
  });

  group('LaunchSequencePuzzle.isSorted', () {
    test('sorted sequence returns true', () {
      expect(LaunchSequencePuzzle.isSorted([1, 2, 3, 4]), isTrue);
    });

    test('unsorted sequence returns false', () {
      expect(LaunchSequencePuzzle.isSorted([1, 3, 2, 4]), isFalse);
    });

    test('single element is sorted', () {
      expect(LaunchSequencePuzzle.isSorted([1]), isTrue);
    });

    test('empty sequence is sorted', () {
      expect(LaunchSequencePuzzle.isSorted([]), isTrue);
    });

    test('equal adjacent elements are considered sorted', () {
      expect(LaunchSequencePuzzle.isSorted([1, 1, 2, 3]), isTrue);
    });

    test('reverse order is not sorted', () {
      expect(LaunchSequencePuzzle.isSorted([3, 2, 1]), isFalse);
    });
  });

  group('LaunchSequencePuzzle.generate (invariants)', () {
    final testCases = <Map<String, int>>[
      // grade 1-like: small sequence, few inversions
      {'itemCount': 4, 'minInversions': 1},
      // grade 4-like: larger sequence, more inversions
      {'itemCount': 8, 'minInversions': 5},
    ];

    for (final tc in testCases) {
      final itemCount = tc['itemCount']!;
      final minInversions = tc['minInversions']!;

      test('itemCount=$itemCount: sequence is a permutation of 1..N', () {
        for (int seed = 0; seed < 5; seed++) {
          final puzzle = LaunchSequencePuzzle.generate(
            itemCount: itemCount,
            minInversions: minInversions,
            seed: seed,
          );
          expect(puzzle.sequence.length, itemCount);
          final sorted = List<int>.from(puzzle.sequence)..sort();
          expect(sorted, List.generate(itemCount, (i) => i + 1));
        }
      });

      test('itemCount=$itemCount: target is sorted 1..N', () {
        final puzzle = LaunchSequencePuzzle.generate(
          itemCount: itemCount,
          minInversions: minInversions,
          seed: 42,
        );
        expect(puzzle.target, List.generate(itemCount, (i) => i + 1));
      });

      test('itemCount=$itemCount: optimalSwaps equals inversion count', () {
        for (int seed = 0; seed < 5; seed++) {
          final puzzle = LaunchSequencePuzzle.generate(
            itemCount: itemCount,
            minInversions: minInversions,
            seed: seed,
          );
          final computed =
              LaunchSequencePuzzle.countInversions(puzzle.sequence);
          expect(puzzle.optimalSwaps, computed,
              reason: 'optimalSwaps must equal inversion count');
        }
      });

      test('itemCount=$itemCount: optimalSwaps >= minInversions', () {
        for (int seed = 0; seed < 5; seed++) {
          final puzzle = LaunchSequencePuzzle.generate(
            itemCount: itemCount,
            minInversions: minInversions,
            seed: seed,
          );
          expect(puzzle.optimalSwaps, greaterThanOrEqualTo(minInversions));
        }
      });

      test('itemCount=$itemCount: sequence is not already sorted', () {
        for (int seed = 0; seed < 5; seed++) {
          final puzzle = LaunchSequencePuzzle.generate(
            itemCount: itemCount,
            minInversions: minInversions,
            seed: seed,
          );
          expect(LaunchSequencePuzzle.isSorted(puzzle.sequence), isFalse,
              reason: 'generated sequence should be shuffled');
        }
      });
    }

    test('different seeds usually produce different sequences', () {
      final p1 = LaunchSequencePuzzle.generate(
          itemCount: 6, minInversions: 2, seed: 1);
      final p2 = LaunchSequencePuzzle.generate(
          itemCount: 6, minInversions: 2, seed: 999);

      bool anyDiff = false;
      for (int i = 0; i < 6; i++) {
        if (p1.sequence[i] != p2.sequence[i]) anyDiff = true;
      }
      expect(anyDiff, isTrue);
    });
  });
}
