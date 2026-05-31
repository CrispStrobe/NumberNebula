// Unit tests for cube_scanner_logic.dart.
//
// Tests the die/cube puzzle logic: face value constraints (opposite faces
// sum to 7), visible/hidden face computation, and generated puzzle
// invariants. The generator uses an unseeded Random, so we assert structural
// invariants over multiple seeded generations.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/cube_scanner_logic.dart';

void main() {
  group('Die', () {
    test('opposite faces sum to 7 for a standard die', () {
      final die = Die([1, 2, 3, 4, 5, 6]);
      expect(die.top + die.bottom, 7); // faces[0] + faces[5]
      expect(die.front + die.back, 7); // faces[1] + faces[4]
      expect(die.right + die.left, 7); // faces[2] + faces[3]
    });

    test('Die.random always produces opposite-faces-sum-to-7', () {
      // Use multiple seeds to test several random dice
      for (int seed = 0; seed < 20; seed++) {
        final die = Die.random(math.Random(seed));
        expect(die.top + die.bottom, 7,
            reason: 'top+bottom must be 7 (seed=$seed)');
        expect(die.front + die.back, 7,
            reason: 'front+back must be 7 (seed=$seed)');
        expect(die.right + die.left, 7,
            reason: 'right+left must be 7 (seed=$seed)');
      }
    });

    test('Die.random face values are all in 1..6', () {
      for (int seed = 0; seed < 20; seed++) {
        final die = Die.random(math.Random(seed));
        for (final face in die.faces) {
          expect(face, inInclusiveRange(1, 6),
              reason: 'face value must be 1-6 (seed=$seed)');
        }
      }
    });

    test('Die.random produces all 6 distinct face values', () {
      for (int seed = 0; seed < 20; seed++) {
        final die = Die.random(math.Random(seed));
        expect(die.faces.toSet().length, 6,
            reason: 'all 6 face values must be distinct (seed=$seed)');
      }
    });

    test('face accessors map to correct indices', () {
      final die = Die([10, 20, 30, 40, 50, 60]);
      expect(die.top, 10);
      expect(die.front, 20);
      expect(die.right, 30);
      expect(die.left, 40);
      expect(die.back, 50);
      expect(die.bottom, 60);
    });
  });

  group('VisibleFaces', () {
    test('visibleEntries returns only non-null faces', () {
      final vf = VisibleFaces(top: 1, front: null, right: 3, left: null);
      final entries = vf.visibleEntries;
      expect(entries.length, 2);
      expect(entries[0].key, 'top');
      expect(entries[0].value, 1);
      expect(entries[1].key, 'right');
      expect(entries[1].value, 3);
    });

    test('visibleEntries empty when all null', () {
      final vf = VisibleFaces();
      expect(vf.visibleEntries, isEmpty);
    });

    test('visibleEntries full when all set', () {
      final vf = VisibleFaces(top: 1, front: 2, right: 3, left: 4);
      expect(vf.visibleEntries.length, 4);
    });
  });

  group('CubeScannerGenerator.generate (invariants)', () {
    final gradeLevelPairs = <List<int>>[
      [1, 1], // 1 die, 3 visible faces
      [2, 1], // 2 dice, 2 visible faces
      [4, 1], // 2-3 dice, 2 visible faces
      [4, 12], // higher level: potentially fewer visible faces
    ];

    for (final pair in gradeLevelPairs) {
      final grade = pair[0];
      final level = pair[1];

      test('grade=$grade level=$level: all dice satisfy opposite-sums-to-7', () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (int i = 0; i < puzzle.diceCount; i++) {
            final die = puzzle.dice[i];
            expect(die.top + die.bottom, 7,
                reason: 'die $i: top+bottom must be 7');
            expect(die.front + die.back, 7,
                reason: 'die $i: front+back must be 7');
            expect(die.right + die.left, 7,
                reason: 'die $i: right+left must be 7');
          }
        }
      });

      test('grade=$grade level=$level: correct answers are derivable from visible faces',
          () {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (final entry in puzzle.questions.entries) {
            final dieIdx = entry.key;
            final faceName = entry.value;
            final die = puzzle.dice[dieIdx];

            // The correct answer must match the actual die face
            int expectedValue;
            switch (faceName) {
              case 'top':
                expectedValue = die.top;
                break;
              case 'bottom':
                expectedValue = die.bottom;
                break;
              case 'front':
                expectedValue = die.front;
                break;
              case 'back':
                expectedValue = die.back;
                break;
              case 'right':
                expectedValue = die.right;
                break;
              case 'left':
                expectedValue = die.left;
                break;
              default:
                fail('unexpected face name: $faceName');
                return;
            }
            expect(puzzle.correctAnswers[dieIdx], expectedValue,
                reason: 'answer for die $dieIdx face $faceName must match');
          }
        }
      });

      test('grade=$grade level=$level: all correct answers are in 1..6', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (final answer in puzzle.correctAnswers.values) {
            expect(answer, inInclusiveRange(1, 6));
          }
        }
      });

      test('grade=$grade level=$level: every die has a question', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (int i = 0; i < puzzle.diceCount; i++) {
            expect(puzzle.questions.containsKey(i), isTrue,
                reason: 'die $i should have a question');
            expect(puzzle.correctAnswers.containsKey(i), isTrue,
                reason: 'die $i should have a correct answer');
          }
        }
      });
    }

    test('dice count scales with grade', () {
      final gen1 = CubeScannerGenerator(seed: 42);
      final p1 = gen1.generate(grade: 1, level: 1);
      final gen4 = CubeScannerGenerator(seed: 42);
      final p4 = gen4.generate(grade: 4, level: 1);

      expect(p1.diceCount, 1);
      expect(p4.diceCount, greaterThanOrEqualTo(2));
    });

    test('hidden face answer can be computed via opposite-face rule', () {
      // For each puzzle, if a visible face is shown, its opposite should sum to 7
      for (int seed = 0; seed < 5; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);

        final die = puzzle.dice[0];
        final visible = puzzle.visibleFaces[0];

        // Check that if top is visible, bottom = 7 - top
        if (visible.top != null) {
          expect(7 - visible.top!, die.bottom);
        }
        if (visible.front != null) {
          expect(7 - visible.front!, die.back);
        }
        if (visible.right != null) {
          expect(7 - visible.right!, die.left);
        }
        if (visible.left != null) {
          expect(7 - visible.left!, die.right);
        }
      }
    });
  });
}

