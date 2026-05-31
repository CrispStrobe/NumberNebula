// Unit tests for circuit_repair_logic.dart.
//
// Tests the digit-position-swap clock puzzle logic: SevenSegment rendering
// data, time validation, swap mechanics, puzzle generation invariants.

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

  group('CircuitRepairPuzzle.isValidTime', () {
    test('00:00 is valid', () {
      expect(CircuitRepairPuzzle.isValidTime([0, 0, 0, 0]), isTrue);
    });

    test('23:59 is valid', () {
      expect(CircuitRepairPuzzle.isValidTime([2, 3, 5, 9]), isTrue);
    });

    test('24:00 is invalid', () {
      expect(CircuitRepairPuzzle.isValidTime([2, 4, 0, 0]), isFalse);
    });

    test('15:69 is invalid (minutes >= 60)', () {
      expect(CircuitRepairPuzzle.isValidTime([1, 5, 6, 9]), isFalse);
    });

    test('12:30 is valid', () {
      expect(CircuitRepairPuzzle.isValidTime([1, 2, 3, 0]), isTrue);
    });

    test('99:99 is invalid', () {
      expect(CircuitRepairPuzzle.isValidTime([9, 9, 9, 9]), isFalse);
    });
  });

  group('CircuitRepairPuzzle.applySwap', () {
    test('swapping positions 0 and 3 works', () {
      final digits = [1, 5, 6, 9];
      final swapped = CircuitRepairPuzzle.applySwap(digits, 0, 3);
      expect(swapped, [9, 5, 6, 1]);
    });

    test('swapping positions 1 and 2 works', () {
      final digits = [1, 5, 6, 9];
      final swapped = CircuitRepairPuzzle.applySwap(digits, 1, 2);
      expect(swapped, [1, 6, 5, 9]);
    });

    test('double swap restores original', () {
      final digits = [2, 3, 4, 5];
      final swapped = CircuitRepairPuzzle.applySwap(digits, 0, 2);
      final restored = CircuitRepairPuzzle.applySwap(swapped, 0, 2);
      expect(restored, digits);
    });
  });

  group('CircuitRepairPuzzle.checkAnswer', () {
    test('correct answer in either order passes', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [1, 6, 5, 9],
        displayedDigits: [1, 5, 6, 9],
        swapPosA: 1,
        swapPosB: 2,
        maxAttempts: 3,
      );
      expect(puzzle.checkAnswer(1, 2), isTrue);
      expect(puzzle.checkAnswer(2, 1), isTrue);
    });

    test('wrong answer fails', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [1, 6, 5, 9],
        displayedDigits: [1, 5, 6, 9],
        swapPosA: 1,
        swapPosB: 2,
        maxAttempts: 3,
      );
      expect(puzzle.checkAnswer(0, 1), isFalse);
      expect(puzzle.checkAnswer(2, 3), isFalse);
      expect(puzzle.checkAnswer(0, 3), isFalse);
    });
  });

  group('CircuitRepairPuzzle.formatTime', () {
    test('formats as HH:MM', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [1, 6, 5, 9],
        displayedDigits: [1, 5, 6, 9],
        swapPosA: 1,
        swapPosB: 2,
        maxAttempts: 3,
      );
      expect(puzzle.correctTimeString, '16:59');
      expect(puzzle.displayedTimeString, '15:69');
    });
  });

  group('CircuitRepairPuzzle validity helpers', () {
    test('minutesInvalid detects >= 60', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [1, 6, 5, 9],
        displayedDigits: [1, 5, 6, 9], // 15:69
        swapPosA: 1,
        swapPosB: 2,
        maxAttempts: 3,
      );
      expect(puzzle.minutesInvalid, isTrue);
      expect(puzzle.hoursInvalid, isFalse);
    });

    test('hoursInvalid detects >= 24', () {
      final puzzle = CircuitRepairPuzzle(
        correctDigits: [1, 2, 3, 0],
        displayedDigits: [3, 2, 1, 0], // 32:10
        swapPosA: 0,
        swapPosB: 2,
        maxAttempts: 3,
      );
      expect(puzzle.hoursInvalid, isTrue);
    });
  });

  group('CircuitRepairGenerator.generate (invariants)', () {
    final gradeLevelPairs = <List<int>>[
      [1, 1],
      [1, 5],
      [2, 1],
      [2, 5],
      [3, 1],
      [4, 1],
    ];

    for (final pair in gradeLevelPairs) {
      final grade = pair[0];
      final level = pair[1];

      test('grade=$grade level=$level: correct digits form a valid time', () {
        for (int seed = 0; seed < 10; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.correctDigits.length, 4,
              reason: 'always 4 digits for HH:MM (seed=$seed)');
          expect(CircuitRepairPuzzle.isValidTime(puzzle.correctDigits), isTrue,
              reason: 'correct time must be valid (seed=$seed)');
        }
      });

      test('grade=$grade level=$level: displayed time is INVALID', () {
        for (int seed = 0; seed < 10; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(CircuitRepairPuzzle.isValidTime(puzzle.displayedDigits), isFalse,
              reason:
                  'displayed time ${puzzle.displayedTimeString} must be invalid (seed=$seed)');
        }
      });

      test('grade=$grade level=$level: swapping back restores correct time', () {
        for (int seed = 0; seed < 10; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          final restored = CircuitRepairPuzzle.applySwap(
              puzzle.displayedDigits, puzzle.swapPosA, puzzle.swapPosB);
          expect(restored, puzzle.correctDigits,
              reason:
                  'swapping back must restore correct digits (seed=$seed)');
        }
      });

      test('grade=$grade level=$level: exactly ONE swap produces a valid time',
          () {
        for (int seed = 0; seed < 10; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          int validSwapCount = 0;
          for (int i = 0; i < 4; i++) {
            for (int j = i + 1; j < 4; j++) {
              final candidate =
                  CircuitRepairPuzzle.applySwap(puzzle.displayedDigits, i, j);
              if (CircuitRepairPuzzle.isValidTime(candidate)) {
                validSwapCount++;
              }
            }
          }
          expect(validSwapCount, 1,
              reason:
                  'exactly one swap should produce a valid time for ${puzzle.displayedTimeString} (seed=$seed)');
        }
      });

      test('grade=$grade level=$level: swapped positions are distinct', () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.swapPosA, isNot(puzzle.swapPosB));
          expect(puzzle.swapPosA, inInclusiveRange(0, 3));
          expect(puzzle.swapPosB, inInclusiveRange(0, 3));
        }
      });

      test('grade=$grade level=$level: checkAnswer accepts stored swap', () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CircuitRepairGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.checkAnswer(puzzle.swapPosA, puzzle.swapPosB), isTrue);
        }
      });
    }

    test('grade 1 generates times in 10:00-12:59 range', () {
      for (int seed = 0; seed < 20; seed++) {
        final gen = CircuitRepairGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);

        final hours = puzzle.correctDigits[0] * 10 + puzzle.correctDigits[1];
        expect(hours, inInclusiveRange(10, 12),
            reason:
                'grade 1 hours should be 10-12, got $hours (seed=$seed)');
      }
    });

    test('maxAttempts scales with grade', () {
      final gen = CircuitRepairGenerator(seed: 42);
      final p1 = gen.generate(grade: 1, level: 1);
      final p2 = gen.generate(grade: 2, level: 1);
      final p3 = gen.generate(grade: 3, level: 1);

      expect(p1.maxAttempts, 5);
      expect(p2.maxAttempts, 4);
      expect(p3.maxAttempts, 3);
    });
  });
}
