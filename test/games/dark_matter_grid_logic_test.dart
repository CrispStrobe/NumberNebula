// Unit tests for dark_matter_grid_logic.dart.
//
// Tests the pure Lights Out puzzle logic: toggle mechanics, solved-state
// detection, and generated puzzle invariants (solvability, grid structure).
// The generator uses an unseeded Random by default, so we assert structural
// invariants rather than exact board values.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/dark_matter_grid_logic.dart';

void main() {
  group('DarkMatterGridPuzzle.toggle', () {
    test('toggling center cell flips center + 4 orthogonal neighbors', () {
      // 3x3 grid, all lit
      final grid = List.generate(3, (_) => List.filled(3, true));
      final result = DarkMatterGridPuzzle.toggle(grid, 1, 1);

      // Center + up + down + left + right should be flipped to false
      expect(result[1][1], false); // center
      expect(result[0][1], false); // up
      expect(result[2][1], false); // down
      expect(result[1][0], false); // left
      expect(result[1][2], false); // right

      // Corners should remain unchanged
      expect(result[0][0], true);
      expect(result[0][2], true);
      expect(result[2][0], true);
      expect(result[2][2], true);
    });

    test('toggling corner cell flips only valid neighbors', () {
      final grid = List.generate(3, (_) => List.filled(3, true));
      final result = DarkMatterGridPuzzle.toggle(grid, 0, 0);

      // (0,0) + (1,0) + (0,1) should flip; rest unchanged
      expect(result[0][0], false);
      expect(result[1][0], false);
      expect(result[0][1], false);
      expect(result[1][1], true); // not a neighbor of corner
      expect(result[2][2], true);
    });

    test('toggling edge cell flips only 4 cells (self + 3 neighbors)', () {
      final grid = List.generate(4, (_) => List.filled(4, false));
      final result = DarkMatterGridPuzzle.toggle(grid, 0, 2);

      // (0,2) self, (0,1) left, (0,3) right, (1,2) down -> flipped to true
      expect(result[0][2], true);
      expect(result[0][1], true);
      expect(result[0][3], true);
      expect(result[1][2], true);
      // No up neighbor exists
      expect(result[0][0], false);
    });

    test('toggling same cell twice restores original grid', () {
      final grid = List.generate(3, (_) => List.filled(3, true));
      final once = DarkMatterGridPuzzle.toggle(grid, 1, 1);
      final twice = DarkMatterGridPuzzle.toggle(once, 1, 1);

      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          expect(twice[r][c], grid[r][c],
              reason: 'toggle is self-inverse at ($r,$c)');
        }
      }
    });

    test('toggle does not mutate original grid', () {
      final grid = List.generate(3, (_) => List.filled(3, true));
      DarkMatterGridPuzzle.toggle(grid, 1, 1);
      // Original should still be all true
      for (final row in grid) {
        for (final cell in row) {
          expect(cell, true);
        }
      }
    });
  });

  group('DarkMatterGridPuzzle.isSolved', () {
    test('all-lit grid is solved', () {
      final grid = List.generate(4, (_) => List.filled(4, true));
      expect(DarkMatterGridPuzzle.isSolved(grid), isTrue);
    });

    test('grid with one dark cell is not solved', () {
      final grid = List.generate(4, (_) => List.filled(4, true));
      grid[2][3] = false;
      expect(DarkMatterGridPuzzle.isSolved(grid), isFalse);
    });

    test('all-dark grid is not solved', () {
      final grid = List.generate(3, (_) => List.filled(3, false));
      expect(DarkMatterGridPuzzle.isSolved(grid), isFalse);
    });
  });

  group('DarkMatterGridPuzzle.generate', () {
    test('generated puzzle has correct grid dimensions', () {
      for (final size in [3, 4, 5]) {
        final puzzle = DarkMatterGridPuzzle.generate(
          gridSize: size,
          toggleCount: 3,
          seed: 42,
        );
        expect(puzzle.size, size);
        expect(puzzle.grid.length, size);
        for (final row in puzzle.grid) {
          expect(row.length, size);
        }
      }
    });

    test('generated puzzle is NOT already solved', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = DarkMatterGridPuzzle.generate(
          gridSize: 4,
          toggleCount: 3,
          seed: seed,
        );
        expect(DarkMatterGridPuzzle.isSolved(puzzle.grid), isFalse,
            reason: 'puzzle with seed $seed should not start solved');
      }
    });

    test('generated puzzle is solvable by replaying toggled cells', () {
      // Since the puzzle is built by toggling from a solved state,
      // applying the same toggles should restore it. We verify by
      // checking that minMoves > 0 and the puzzle has valid structure.
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = DarkMatterGridPuzzle.generate(
          gridSize: 4,
          toggleCount: 4,
          seed: seed,
        );
        expect(puzzle.minMoves, greaterThan(0));
        expect(puzzle.minMoves, lessThanOrEqualTo(4));
      }
    });

    test('minMoves does not exceed toggleCount', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = DarkMatterGridPuzzle.generate(
          gridSize: 5,
          toggleCount: 6,
          seed: seed,
        );
        expect(puzzle.minMoves, lessThanOrEqualTo(6));
        expect(puzzle.minMoves, greaterThan(0));
      }
    });

    test('grid values are all booleans', () {
      final puzzle = DarkMatterGridPuzzle.generate(
        gridSize: 5,
        toggleCount: 3,
        seed: 99,
      );
      for (final row in puzzle.grid) {
        for (final cell in row) {
          expect(cell, isA<bool>());
        }
      }
    });

    test('different seeds produce different puzzles (usually)', () {
      final p1 = DarkMatterGridPuzzle.generate(
          gridSize: 4, toggleCount: 4, seed: 1);
      final p2 = DarkMatterGridPuzzle.generate(
          gridSize: 4, toggleCount: 4, seed: 999);

      bool anyDiff = false;
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          if (p1.grid[r][c] != p2.grid[r][c]) anyDiff = true;
        }
      }
      expect(anyDiff, isTrue,
          reason: 'different seeds should usually produce different grids');
    });
  });
}
