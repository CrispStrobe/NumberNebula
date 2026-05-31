// Unit tests for nebula_matrix_logic.dart — pure puzzle logic only.
//
// The generator uses an unseeded Random, so we assert structural invariants
// (valid Latin square, correct clue/empty partitioning, solution validation)
// rather than exact board layouts.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/nebula_matrix_logic.dart';

void main() {
  group('NebulaMatrixGenerator Latin square invariants', () {
    for (final size in [3, 4, 5, 6]) {
      test('size $size: solution is a valid Latin square', () async {
        final gen = NebulaMatrixGenerator();
        for (int i = 0; i < 3; i++) {
          final puzzle = await gen.generate(size: size, clueCount: size);

          expect(puzzle.size, size);
          expect(puzzle.solution.length, size * size);

          // Check rows: no repeats, all values in 1..size
          for (int r = 0; r < size; r++) {
            final rowVals = <int>{};
            for (int c = 0; c < size; c++) {
              final v = puzzle.solution['r${r}c$c']!;
              expect(v, inInclusiveRange(1, size));
              rowVals.add(v);
            }
            expect(rowVals.length, size,
                reason: 'row $r must have $size unique values');
          }

          // Check columns: no repeats
          for (int c = 0; c < size; c++) {
            final colVals = <int>{};
            for (int r = 0; r < size; r++) {
              colVals.add(puzzle.solution['r${r}c$c']!);
            }
            expect(colVals.length, size,
                reason: 'column $c must have $size unique values');
          }
        }
      });
    }
  });

  group('NebulaMatrixGenerator puzzle structure', () {
    test('clues + emptyCells partition the entire grid', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 4, clueCount: 6);

      final total = puzzle.size * puzzle.size;
      expect(puzzle.clues.length + puzzle.emptyCells.length, total);

      for (final cell in puzzle.clues.keys) {
        expect(puzzle.emptyCells.contains(cell), isFalse);
      }
    });

    test('numberPool is 1..size', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 5, clueCount: 5);

      expect(puzzle.numberPool, List.generate(5, (i) => i + 1));
    });

    test('clue values match the solution', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 4, clueCount: 8);

      for (final entry in puzzle.clues.entries) {
        expect(entry.value, puzzle.solution[entry.key]);
      }
    });
  });

  group('NebulaMatrixPuzzle.validateSolution', () {
    test('correct solution is accepted', () async {
      final gen = NebulaMatrixGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(size: 4, clueCount: 4);

        final userSolution = <String, int>{};
        for (final cell in puzzle.emptyCells) {
          userSolution[cell] = puzzle.solution[cell]!;
        }
        expect(puzzle.validateSolution(userSolution), isTrue);
      }
    });

    test('corrupted solution is rejected', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 4, clueCount: 4);

      final userSolution = <String, int>{};
      for (final cell in puzzle.emptyCells) {
        userSolution[cell] = puzzle.solution[cell]!;
      }

      // Corrupt one cell
      final firstEmpty = puzzle.emptyCells.first;
      final correct = userSolution[firstEmpty]!;
      userSolution[firstEmpty] = correct == puzzle.size ? 1 : correct + 1;

      expect(puzzle.validateSolution(userSolution), isFalse);
    });

    test('empty user solution is rejected', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 3, clueCount: 3);

      expect(puzzle.validateSolution({}), isFalse);
    });

    test('out-of-range values are rejected', () async {
      final gen = NebulaMatrixGenerator();
      final puzzle = await gen.generate(size: 3, clueCount: 3);

      final userSolution = <String, int>{};
      for (final cell in puzzle.emptyCells) {
        userSolution[cell] = puzzle.size + 1; // out of range
      }
      expect(puzzle.validateSolution(userSolution), isFalse);
    });
  });
}
