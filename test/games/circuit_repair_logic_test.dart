// Unit tests for circuit_repair_logic.dart.
//
// Tests the 7-segment display puzzle logic: segment definitions for digits
// 0-9, segment swapping mechanics, digit identification, and generated
// puzzle invariants (corrupted display, answer validation).

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/circuit_repair_logic.dart';

void main() {
  group('SevenSegment.digitSegments', () {
    test('all digits 0-9 are defined', () {
      for (int d = 0; d <= 9; d++) {
        expect(SevenSegment.digitSegments.containsKey(d), isTrue,
            reason: 'digit $d must be defined');
        expect(SevenSegment.digitSegments[d], isNotEmpty);
      }
    });

    test('digit 8 uses all 7 segments', () {
      expect(SevenSegment.getSegments(8), {'a', 'b', 'c', 'd', 'e', 'f', 'g'});
    });

    test('digit 1 uses only b and c', () {
      expect(SevenSegment.getSegments(1), {'b', 'c'});
    });

    test('digit 0 uses all segments except g', () {
      expect(SevenSegment.getSegments(0), {'a', 'b', 'c', 'd', 'e', 'f'});
    });

    test('digit 7 uses a, b, c', () {
      expect(SevenSegment.getSegments(7), {'a', 'b', 'c'});
    });

    test('digit 4 uses b, c, f, g', () {
      expect(SevenSegment.getSegments(4), {'b', 'c', 'f', 'g'});
    });

    test('all segment names are from a-g', () {
      for (int d = 0; d <= 9; d++) {
        for (final seg in SevenSegment.getSegments(d)) {
          expect(SevenSegment.allSegments.contains(seg), isTrue,
              reason: 'digit $d has invalid segment $seg');
        }
      }
    });

    test('no two digits have identical segment sets', () {
      final seen = <String>{};
      for (int d = 0; d <= 9; d++) {
        final key = (SevenSegment.getSegments(d).toList()..sort()).join(',');
        expect(seen.contains(key), isFalse,
            reason: 'digit $d duplicates another digit segment set');
        seen.add(key);
      }
    });
  });

  group('SevenSegment.identifyDigit', () {
    test('identifies all digits 0-9 correctly', () {
      for (int d = 0; d <= 9; d++) {
        expect(SevenSegment.identifyDigit(SevenSegment.getSegments(d)), d);
      }
    });

    test('returns -1 for invalid segment set', () {
      expect(SevenSegment.identifyDigit({'a', 'g'}), -1);
      expect(SevenSegment.identifyDigit({}), -1);
    });
  });

  group('SevenSegment.applySwap', () {
    test('swapping segments a and g on digit 0 produces different set', () {
      final original = SevenSegment.getSegments(0); // {a,b,c,d,e,f}
      final swapped = SevenSegment.applySwap(original, 'a', 'g');
      // 'a' becomes 'g', 'g' not in original stays absent
      // original has a -> becomes g; original does not have g -> no change
      expect(swapped.contains('a'), isFalse);
      expect(swapped.contains('g'), isTrue);
    });

    test('swapping two segments that are both present swaps them', () {
      final segments = {'a', 'b', 'c'};
      final swapped = SevenSegment.applySwap(segments, 'a', 'c');
      // a->c, c->a, b stays
      expect(swapped, {'c', 'b', 'a'}); // same set since both were present
    });

    test('swapping and swapping back restores original', () {
      for (int d = 0; d <= 9; d++) {
        final original = SevenSegment.getSegments(d);
        final swapped = SevenSegment.applySwap(original, 'a', 'g');
        final restored = SevenSegment.applySwap(swapped, 'a', 'g');
        expect(restored, original,
            reason: 'double swap must restore original for digit $d');
      }
    });

    test('swapping a segment with itself is identity', () {
      final original = SevenSegment.getSegments(5);
      final swapped = SevenSegment.applySwap(original, 'b', 'b');
      expect(swapped, original);
    });
  });

  group('CircuitRepairPuzzle.checkAnswer', () {
    test('correct answer in either order passes', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [8],
        corruptedDigits: [0],
        corruptedSegments: [SevenSegment.applySwap(SevenSegment.getSegments(8), 'a', 'g')],
        swappedSegA: 'a',
        swappedSegB: 'g',
      );
      expect(puzzle.checkAnswer('a', 'g'), isTrue);
      expect(puzzle.checkAnswer('g', 'a'), isTrue);
    });

    test('wrong answer fails', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [8],
        corruptedDigits: [0],
        corruptedSegments: [SevenSegment.applySwap(SevenSegment.getSegments(8), 'a', 'g')],
        swappedSegA: 'a',
        swappedSegB: 'g',
      );
      expect(puzzle.checkAnswer('a', 'b'), isFalse);
      expect(puzzle.checkAnswer('c', 'd'), isFalse);
    });
  });

  group('CircuitRepairGenerator.generate (invariants)', () {
    final gradeLevelPairs = <List<int>>[
      [1, 1], // 1 digit
      [2, 1], // 2 digits
      [4, 1], // 2+ digits
      [4, 10], // higher level
    ];

    for (final pair in gradeLevelPairs) {
      final grade = pair[0];
      final level = pair[1];

      test('grade=$grade level=$level: swapping back restores correct digits', () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          final segA = puzzle.swappedSegA;
          final segB = puzzle.swappedSegB;

          // For each digit position, applying the swap to correctDigits segments
          // should produce the corruptedSegments
          for (int i = 0; i < puzzle.correctDigits.length; i++) {
            final originalSegs =
                SevenSegment.getSegments(puzzle.correctDigits[i]);
            final swappedSegs =
                SevenSegment.applySwap(originalSegs, segA, segB);
            expect(swappedSegs, puzzle.corruptedSegments[i],
                reason:
                    'applying swap to correct digit $i must produce corrupted segments (seed=$seed)');
          }
        }
      });

      test('grade=$grade level=$level: at least one digit is actually corrupted',
          () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          bool anyChanged = false;
          for (int i = 0; i < puzzle.correctDigits.length; i++) {
            if (puzzle.corruptedDigits[i] != puzzle.correctDigits[i]) {
              anyChanged = true;
            }
          }
          expect(anyChanged, isTrue,
              reason: 'at least one digit must change (seed=$seed)');
        }
      });

      test('grade=$grade level=$level: checkAnswer accepts the stored swap', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.checkAnswer(puzzle.swappedSegA, puzzle.swappedSegB),
              isTrue);
        }
      });

      test('grade=$grade level=$level: swapped segments are distinct', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.swappedSegA, isNot(puzzle.swappedSegB),
              reason: 'swapped segments must be different');
          expect(
            SevenSegment.allSegments.contains(puzzle.swappedSegA),
            isTrue,
          );
          expect(
            SevenSegment.allSegments.contains(puzzle.swappedSegB),
            isTrue,
          );
        }
      });
    }

    test('digit count scales with grade', () {
      final gen1 = CircuitRepairGenerator(seed: 42);
      final p1 = gen1.generate(grade: 1, level: 1);
      final gen4 = CircuitRepairGenerator(seed: 42);
      final p4 = gen4.generate(grade: 4, level: 1);

      expect(p1.correctDigits.length, 1);
      expect(p4.correctDigits.length, greaterThanOrEqualTo(2));
    });

    test('all correct digits are in 0..9', () {
      for (int seed = 0; seed < 5; seed++) {
        final gen = CircuitRepairGenerator(seed: seed);
        final puzzle = gen.generate(grade: 3, level: 5);
        for (final d in puzzle.correctDigits) {
          expect(d, inInclusiveRange(0, 9));
        }
      }
    });
  });
}
