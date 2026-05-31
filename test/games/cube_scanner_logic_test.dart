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

    test('faceByName returns correct values', () {
      final die = Die([1, 2, 3, 4, 5, 6]);
      expect(die.faceByName('top'), 1);
      expect(die.faceByName('front'), 2);
      expect(die.faceByName('right'), 3);
      expect(die.faceByName('left'), 4);
      expect(die.faceByName('back'), 5);
      expect(die.faceByName('bottom'), 6);
    });

    test('faceByName throws on invalid name', () {
      final die = Die([1, 2, 3, 4, 5, 6]);
      expect(() => die.faceByName('invalid'), throwsArgumentError);
    });
  });

  group('VisibleFaces', () {
    test('visibleEntries returns only non-null faces', () {
      const vf = VisibleFaces(top: 1, front: null, right: 3, left: null);
      final entries = vf.visibleEntries;
      expect(entries.length, 2);
      expect(entries[0].key, 'Top');
      expect(entries[0].value, 1);
      expect(entries[1].key, 'Right');
      expect(entries[1].value, 3);
    });

    test('visibleEntries empty when all null', () {
      const vf = VisibleFaces();
      expect(vf.visibleEntries, isEmpty);
    });

    test('visibleEntries full when all set', () {
      const vf = VisibleFaces(top: 1, front: 2, right: 3, left: 4);
      expect(vf.visibleEntries.length, 4);
    });

    test('visibleSum computes correctly', () {
      const vf = VisibleFaces(top: 3, front: 5, right: 6);
      expect(vf.visibleSum, 14);
    });

    test('visibleSum is 0 for all-null', () {
      const vf = VisibleFaces();
      expect(vf.visibleSum, 0);
    });
  });

  group('CubeScannerGenerator - single die (grade 1-2)', () {
    test('grade 1: single die, 3 visible faces, correct answer is 7 - top', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);

        expect(puzzle.diceCount, 1);
        expect(puzzle.arrangement, DiceArrangement.single);
        expect(puzzle.choices.length, 5);
        expect(puzzle.choices.contains(puzzle.correctAnswer), isTrue);

        // All dice satisfy opposite-faces-sum-to-7
        final die = puzzle.dice[0];
        expect(die.top + die.bottom, 7);
        expect(die.front + die.back, 7);
        expect(die.right + die.left, 7);

        // Visible faces should be top, front, right
        final vis = puzzle.visibleFaces[0];
        expect(vis.top, isNotNull);
        expect(vis.front, isNotNull);
        expect(vis.right, isNotNull);

        // Correct answer = 7 - top (bottom face)
        expect(puzzle.correctAnswer, die.bottom);
      }
    });

    test('grade 2, higher level: asks for sum of hidden faces', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 2, level: 8);

        expect(puzzle.diceCount, 1);
        final vis = puzzle.visibleFaces[0];
        final expectedHiddenSum = 21 - vis.visibleSum;
        expect(puzzle.correctAnswer, expectedHiddenSum);
      }
    });
  });

  group('CubeScannerGenerator - stacked dice (grade 3)', () {
    test('generates 2 stacked dice with touching face constraint', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 3, level: 5);

        expect(puzzle.diceCount, 2);
        expect(puzzle.arrangement, DiceArrangement.verticalStack);

        final die1 = puzzle.dice[0];
        final die2 = puzzle.dice[1];

        // Touching faces: die1.bottom == die2.top
        expect(die1.bottom, die2.top,
            reason: 'touching faces must be equal (seed=$seed)');

        // All dice valid
        for (final die in puzzle.dice) {
          expect(die.top + die.bottom, 7);
          expect(die.front + die.back, 7);
          expect(die.right + die.left, 7);
        }

        // Correct answer = die2.bottom
        expect(puzzle.correctAnswer, die2.bottom);
        expect(puzzle.choices.contains(puzzle.correctAnswer), isTrue);
      }
    });
  });

  group('CubeScannerGenerator - row dice (grade 4)', () {
    test('generates 3 row dice with touching face constraints', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 4, level: 10);

        expect(puzzle.diceCount, 3);
        expect(puzzle.arrangement, DiceArrangement.horizontalRow);

        final die1 = puzzle.dice[0];
        final die2 = puzzle.dice[1];
        final die3 = puzzle.dice[2];

        // Touching constraints
        expect(die1.right, die2.left,
            reason: 'die1.right == die2.left (seed=$seed)');
        expect(die2.right, die3.left,
            reason: 'die2.right == die3.left (seed=$seed)');

        // All dice valid
        for (final die in puzzle.dice) {
          expect(die.top + die.bottom, 7);
          expect(die.front + die.back, 7);
          expect(die.right + die.left, 7);
        }

        // Correct answer = die1.right
        expect(puzzle.correctAnswer, die1.right);
        expect(puzzle.choices.contains(puzzle.correctAnswer), isTrue);
      }
    });
  });

  group('CubeScannerGenerator - choices', () {
    test('always generates exactly 5 choices', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: 5);
          expect(puzzle.choices.length, 5,
              reason: 'must have 5 choices (grade=$grade, seed=$seed)');
        }
      }
    });

    test('correct answer is always among choices', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int seed = 0; seed < 5; seed++) {
          final gen = CubeScannerGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: 5);
          expect(puzzle.choices.contains(puzzle.correctAnswer), isTrue,
              reason: 'correct answer must be in choices (grade=$grade, seed=$seed)');
        }
      }
    });
  });

  group('Die - 24 orientations', () {
    test('Die.random produces exactly 24 unique orientations', () {
      // Collect all orientations by trying many seeds
      final seen = <String>{};
      for (int seed = 0; seed < 200; seed++) {
        final die = Die.random(math.Random(seed));
        seen.add(die.faces.toString());
      }
      expect(seen.length, 24,
          reason: 'should produce all 24 die orientations');
    });
  });

  group('Hidden face deduction', () {
    test('hidden face can be computed via opposite-face rule', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);

        final die = puzzle.dice[0];
        final visible = puzzle.visibleFaces[0];

        if (visible.top != null) {
          expect(7 - visible.top!, die.bottom);
        }
        if (visible.front != null) {
          expect(7 - visible.front!, die.back);
        }
        if (visible.right != null) {
          expect(7 - visible.right!, die.left);
        }
      }
    });
  });
}
