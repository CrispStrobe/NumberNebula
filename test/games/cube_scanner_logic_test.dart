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
    test('grade 1 level 1-3 asks for the bottom face', () {
      for (int seed = 0; seed < 10; seed++) {
        final gen = CubeScannerGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);

        expect(puzzle.diceCount, 1);
        expect(puzzle.arrangement, DiceArrangement.single);
        expect(puzzle.choices.length, 5);
        expect(puzzle.choices, contains(puzzle.correctAnswer));

        final die = puzzle.dice[0];
        expect(die.top + die.bottom, 7);
        expect(die.front + die.back, 7);
        expect(die.right + die.left, 7);

        // The scanner shows top, front and right.
        final vis = puzzle.visibleFaces[0];
        expect(vis.top, isNotNull);
        expect(vis.front, isNotNull);
        expect(vis.right, isNotNull);

        expect(puzzle.question.kind, CubeQuestionKind.hiddenFace);
        expect(puzzle.question.face, CubeFace.bottom);
        expect(puzzle.correctAnswer, die.bottom);
      }
    });

    test('grade 1 past level 3 also asks for the back and left faces', () {
      final asked = <CubeFace>{};
      for (int seed = 0; seed < 60; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 1, level: 8);
        if (puzzle.question.kind == CubeQuestionKind.hiddenFace) {
          asked.add(puzzle.question.face!);
        }
      }
      // The single fixed "what is on the bottom" question is what made this
      // game repetitive; all three hidden faces must come up.
      expect(asked,
          containsAll(<CubeFace>[CubeFace.bottom, CubeFace.back, CubeFace.left]));
    });

    test('grade 2 mixes hidden sums with rolls', () {
      final kinds = <CubeQuestionKind>{};
      for (int seed = 0; seed < 60; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 2, level: 8);
        kinds.add(puzzle.question.kind);
        expect(puzzle.diceCount, 1);
        expect(puzzle.choices, hasLength(5));
        expect(puzzle.choices, contains(puzzle.correctAnswer));
      }
      expect(kinds, contains(CubeQuestionKind.rollToFace));
      expect(kinds, contains(CubeQuestionKind.hiddenFaceSum));
    });

    test('a hidden-face-sum answer really is 21 minus what is on show', () {
      for (int seed = 0; seed < 80; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 2, level: 4);
        if (puzzle.question.kind != CubeQuestionKind.hiddenFaceSum) continue;
        expect(puzzle.correctAnswer,
            21 - puzzle.visibleFaces[0].visibleSum);
      }
    });

    test('a roll answer matches rolling the shown cube by hand', () {
      for (int seed = 0; seed < 80; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 4, level: 10);
        if (puzzle.question.kind != CubeQuestionKind.rollToFace) continue;

        var die = puzzle.dice[0];
        for (final roll in puzzle.question.rolls) {
          die = switch (roll) {
            CubeRoll.forward => die.rollForward(),
            CubeRoll.backward => die.rollBackward(),
            CubeRoll.left => die.rollLeft(),
            CubeRoll.right => die.rollRight(),
          };
        }
        final expected = switch (puzzle.question.face!) {
          CubeFace.top => die.top,
          CubeFace.front => die.front,
          CubeFace.right => die.right,
          CubeFace.left => die.left,
          CubeFace.back => die.back,
          CubeFace.bottom => die.bottom,
        };
        expect(puzzle.correctAnswer, expected,
            reason: 'roll result must match (seed=$seed)');
      }
    });

    test('a roll never immediately undoes the one before it', () {
      CubeRoll opposite(CubeRoll r) => switch (r) {
            CubeRoll.forward => CubeRoll.backward,
            CubeRoll.backward => CubeRoll.forward,
            CubeRoll.left => CubeRoll.right,
            CubeRoll.right => CubeRoll.left,
          };
      for (int seed = 0; seed < 80; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 4, level: 10);
        final rolls = puzzle.question.rolls;
        for (int i = 1; i < rolls.length; i++) {
          expect(rolls[i], isNot(opposite(rolls[i - 1])),
              reason: 'a cancelled-out roll makes the puzzle shorter than it '
                  'looks (seed=$seed)');
        }
      }
    });
  });

  group('CubeScannerGenerator - several cubes', () {
    test('the stack keeps the touching faces equal', () {
      for (int seed = 0; seed < 80; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 3, level: 5);
        if (puzzle.arrangement != DiceArrangement.verticalStack) continue;

        expect(puzzle.diceCount, 2);
        expect(puzzle.dice[0].bottom, puzzle.dice[1].top,
            reason: 'touching faces must be equal (seed=$seed)');
        for (final die in puzzle.dice) {
          expect(die.top + die.bottom, 7);
          expect(die.front + die.back, 7);
          expect(die.right + die.left, 7);
        }
        // Cube 2's top is the face cube 1 stands on, so it is not on show.
        expect(puzzle.visibleFaces[1].top, isNull);
      }
    });

    test('the row keeps every touching pair equal', () {
      for (int seed = 0; seed < 80; seed++) {
        final puzzle =
            CubeScannerGenerator(seed: seed).generate(grade: 4, level: 10);
        if (puzzle.arrangement != DiceArrangement.horizontalRow) continue;

        expect(puzzle.diceCount, 3);
        for (int i = 0; i + 1 < puzzle.diceCount; i++) {
          expect(puzzle.dice[i].right, puzzle.dice[i + 1].left,
              reason: 'cube $i.right == cube ${i + 1}.left (seed=$seed)');
        }
        // Only the last cube has a free right face.
        for (int i = 0; i + 1 < puzzle.diceCount; i++) {
          expect(puzzle.visibleFaces[i].right, isNull);
        }
        expect(puzzle.visibleFaces.last.right, isNotNull);
      }
    });

    test('a hidden-pip answer is 21 per cube minus what is drawn', () {
      for (int grade in [3, 4]) {
        for (int seed = 0; seed < 80; seed++) {
          final puzzle =
              CubeScannerGenerator(seed: seed).generate(grade: grade, level: 9);
          if (puzzle.question.kind != CubeQuestionKind.hiddenPips) continue;

          int shown = 0;
          for (final v in puzzle.visibleFaces) {
            shown += v.visibleSum;
          }
          expect(puzzle.correctAnswer, 21 * puzzle.diceCount - shown,
              reason: 'grade=$grade seed=$seed');
        }
      }
    });

    test('a multi-cube answer is never just a number already on screen', () {
      // The stack used to answer to cube 1's visible top face and the row to
      // cube 3's visible right face, so both were solvable by copying.
      for (int grade in [3, 4]) {
        for (int seed = 0; seed < 80; seed++) {
          final puzzle =
              CubeScannerGenerator(seed: seed).generate(grade: grade, level: 9);
          if (puzzle.diceCount < 2) continue;

          final onScreen = <int>{
            for (final v in puzzle.visibleFaces)
              for (final e in v.visibleEntries) e.value,
          };
          expect(onScreen, isNot(contains(puzzle.correctAnswer)),
              reason: 'answer must not be readable off the board '
                  '(grade=$grade, seed=$seed)');
        }
      }
    });
  });

  group('CubeScannerGenerator - choices', () {
    test('always generates exactly 5 distinct choices holding the answer', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int level in [1, 5, 12, 20]) {
          for (int seed = 0; seed < 10; seed++) {
            final puzzle = CubeScannerGenerator(seed: seed)
                .generate(grade: grade, level: level);
            expect(puzzle.choices, hasLength(5),
                reason: 'grade=$grade level=$level seed=$seed');
            expect(puzzle.choices.toSet(), hasLength(5),
                reason: 'choices must be distinct '
                    '(grade=$grade level=$level seed=$seed)');
            expect(puzzle.choices, contains(puzzle.correctAnswer),
                reason: 'grade=$grade level=$level seed=$seed');
          }
        }
      }
    });

    test('distractors sit close to the answer, not scattered at random', () {
      // A correct answer far from every distractor is guessable without doing
      // the arithmetic at all.
      for (int grade = 1; grade <= 4; grade++) {
        for (int seed = 0; seed < 20; seed++) {
          final puzzle =
              CubeScannerGenerator(seed: seed).generate(grade: grade, level: 7);
          final others = puzzle.choices
              .where((c) => c != puzzle.correctAnswer)
              .map((c) => (c - puzzle.correctAnswer).abs());
          expect(others.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(2),
              reason: 'some option must be adjacent to the answer '
                  '(grade=$grade, seed=$seed)');
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
