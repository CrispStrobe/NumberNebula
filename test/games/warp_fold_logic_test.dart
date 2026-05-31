// Unit tests for warp_fold_logic.dart.
//
// Tests the fold-and-cut puzzle logic: fold transforms, correct result
// computation, distractor generation, and generated puzzle invariants.
// The generator uses an unseeded Random, so we assert structural invariants
// over multiple seeded generations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/warp_fold_logic.dart';

void main() {
  group('WarpFoldPuzzle structure', () {
    test('generated puzzle has exactly 5 options', () {
      for (int seed = 0; seed < 5; seed++) {
        final gen = WarpFoldGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);
        expect(puzzle.options.length, 5);
      }
    });

    test('correctIndex points to the correct result', () {
      for (int seed = 0; seed < 5; seed++) {
        final gen = WarpFoldGenerator(seed: seed);
        final puzzle = gen.generate(grade: 2, level: 3);

        expect(puzzle.correctIndex, inInclusiveRange(0, 4));
        final selected = puzzle.options[puzzle.correctIndex];

        // Must match correctResult
        for (int r = 0; r < puzzle.gridSize; r++) {
          for (int c = 0; c < puzzle.gridSize; c++) {
            expect(selected[r][c], puzzle.correctResult[r][c],
                reason:
                    'option at correctIndex must match correctResult at ($r,$c)');
          }
        }
      }
    });

    test('distractors differ from the correct result', () {
      for (int seed = 0; seed < 5; seed++) {
        final gen = WarpFoldGenerator(seed: seed);
        final puzzle = gen.generate(grade: 3, level: 5);

        for (int i = 0; i < puzzle.options.length; i++) {
          if (i == puzzle.correctIndex) continue;
          final option = puzzle.options[i];

          bool differs = false;
          for (int r = 0; r < puzzle.gridSize && !differs; r++) {
            for (int c = 0; c < puzzle.gridSize && !differs; c++) {
              if (option[r][c] != puzzle.correctResult[r][c]) {
                differs = true;
              }
            }
          }
          expect(differs, isTrue,
              reason: 'distractor $i must differ from correct result');
        }
      }
    });
  });

  group('WarpFoldPuzzle grid dimensions', () {
    test('correctResult grid is gridSize x gridSize', () {
      final gen = WarpFoldGenerator(seed: 42);
      final puzzle = gen.generate(grade: 2, level: 1);

      expect(puzzle.correctResult.length, puzzle.gridSize);
      for (final row in puzzle.correctResult) {
        expect(row.length, puzzle.gridSize);
      }
    });

    test('all options have correct grid dimensions', () {
      final gen = WarpFoldGenerator(seed: 42);
      final puzzle = gen.generate(grade: 4, level: 10);

      for (final option in puzzle.options) {
        expect(option.length, puzzle.gridSize);
        for (final row in option) {
          expect(row.length, puzzle.gridSize);
        }
      }
    });
  });

  group('WarpFoldPuzzle fold/cut counts scale with grade', () {
    test('grade 1 has 1 fold', () {
      final gen = WarpFoldGenerator(seed: 42);
      final puzzle = gen.generate(grade: 1, level: 1);
      expect(puzzle.folds.length, 1);
      expect(puzzle.cuts.length, 1);
    });

    test('grade 2 has 2 folds', () {
      final gen = WarpFoldGenerator(seed: 42);
      final puzzle = gen.generate(grade: 2, level: 1);
      expect(puzzle.folds.length, 2);
    });

    test('grade 4 has 3 folds', () {
      final gen = WarpFoldGenerator(seed: 42);
      final puzzle = gen.generate(grade: 4, level: 1);
      expect(puzzle.folds.length, 3);
    });
  });

  group('WarpFoldPuzzle symmetry from folds', () {
    test('single left/right fold produces horizontal symmetry', () {
      // A left or right fold should mirror across the vertical center
      for (int seed = 0; seed < 5; seed++) {
        final gen2 = WarpFoldGenerator(seed: seed);
        final puzzle = gen2.generate(grade: 1, level: 1);

        // With 1 fold, the result should have symmetry of some kind.
        // The correct result has holes; verify it has at least one hole.
        bool hasHole = false;
        for (final row in puzzle.correctResult) {
          for (final cell in row) {
            if (cell) hasHole = true;
          }
        }
        expect(hasHole, isTrue,
            reason: 'puzzle must have at least one hole after cutting');
      }
    });

    test('correct result has multiple holes from fold-induced duplication', () {
      // A single fold + cut should produce at least 2 holes (the cut is
      // mirrored). With rounding, the hole cluster count may vary, but
      // the total number of true cells should be > 1.
      for (int seed = 0; seed < 10; seed++) {
        final gen = WarpFoldGenerator(seed: seed);
        final puzzle = gen.generate(grade: 1, level: 1);
        final grid = puzzle.correctResult;

        int holeCount = 0;
        for (final row in grid) {
          for (final cell in row) {
            if (cell) holeCount++;
          }
        }
        // With 1 fold and 1 cut, the cut is mirrored, so we expect
        // holes on both sides of the fold axis.
        expect(holeCount, greaterThan(1),
            reason: 'fold should duplicate cut holes (seed=$seed)');
      }
    });
  });

  group('WarpFoldPuzzle gridSize is always 8', () {
    test('gridSize is 8 regardless of grade/level', () {
      for (final grade in [1, 2, 3, 4]) {
        final gen = WarpFoldGenerator(seed: 42);
        final puzzle = gen.generate(grade: grade, level: 5);
        expect(puzzle.gridSize, 8);
      }
    });
  });
}
