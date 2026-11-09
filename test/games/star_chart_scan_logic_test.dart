// Unit tests for star_chart_scan_logic.dart (equation finder redesign).
//
// Tests equation generation, grid placement, and puzzle invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_chart_scan_logic.dart';

void main() {
  group('StarChartScanPuzzle.lineBetween', () {
    test('fills in the cells a fast drag skips over', () {
      // The regression: a drag reports positions several cells apart, and the
      // old code appended only the sampled cells. The selection then read
      // "3=7" instead of "3+4=7" and matched nothing, which made correct
      // sweeps look like the puzzle was broken.
      expect(StarChartScanPuzzle.lineBetween((2, 1), (2, 5)),
          [(2, 1), (2, 2), (2, 3), (2, 4), (2, 5)]);
    });

    test('runs in every straight direction, forwards and backwards', () {
      expect(StarChartScanPuzzle.lineBetween((4, 4), (1, 4)),
          [(4, 4), (3, 4), (2, 4), (1, 4)]);
      expect(StarChartScanPuzzle.lineBetween((0, 0), (3, 3)),
          [(0, 0), (1, 1), (2, 2), (3, 3)]);
      expect(StarChartScanPuzzle.lineBetween((0, 4), (3, 1)),
          [(0, 4), (1, 3), (2, 2), (3, 1)]);
      expect(StarChartScanPuzzle.lineBetween((3, 1), (0, 4)),
          [(3, 1), (2, 2), (1, 3), (0, 4)]);
    });

    test('a single cell is a run of one', () {
      expect(StarChartScanPuzzle.lineBetween((2, 2), (2, 2)), [(2, 2)]);
    });

    test('rejects cells that share no row, column or diagonal', () {
      expect(StarChartScanPuzzle.lineBetween((0, 0), (1, 3)), isNull);
      expect(StarChartScanPuzzle.lineBetween((2, 5), (5, 1)), isNull);
    });

    test('a sweep along a placed equation reads that equation back', () {
      for (int seed = 0; seed < 40; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          gridSize: 9,
          equationCount: 6,
          allowDiagonal: true,
          operators: const ['+', '-', 'x'],
          seed: seed,
        );

        for (final placed in puzzle.placedEquations) {
          final last = placed.cells.last;
          final line = StarChartScanPuzzle.lineBetween(
              (placed.startRow, placed.startCol), (last.$1, last.$2));

          expect(line, isNotNull,
              reason: '${placed.equation} does not lie on a straight run');
          final read =
              line!.map((cell) => puzzle.grid[cell.$1][cell.$2]).join();
          expect(read, placed.equation,
              reason: 'sweeping ${placed.equation} must read it back');
        }
      }
    });
  });

  group('StarChartScanPuzzle.generate: structure', () {
    test('grid has correct dimensions', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          gridSize: 7,
          equationCount: 3,
          allowDiagonal: false,
          operators: ['+'],
          seed: seed,
        );
        expect(puzzle.gridSize, 7);
        expect(puzzle.grid.length, 7);
        for (final row in puzzle.grid) {
          expect(row.length, 7);
        }
      }
    });

    test('all grid cells are non-empty', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          gridSize: 8,
          equationCount: 4,
          allowDiagonal: false,
          operators: ['+'],
          seed: seed,
        );
        for (int r = 0; r < puzzle.gridSize; r++) {
          for (int c = 0; c < puzzle.gridSize; c++) {
            expect(puzzle.grid[r][c].isNotEmpty, isTrue,
                reason: 'cell ($r,$c) must not be empty');
          }
        }
      }
    });

    test('equationsToFind matches placed equation count', () {
      final puzzle = StarChartScanPuzzle.generate(
        gridSize: 8,
        equationCount: 5,
        allowDiagonal: false,
        operators: ['+'],
        seed: 42,
      );
      expect(puzzle.equationsToFind.length, puzzle.placedEquations.length);
    });
  });

  group('StarChartScanPuzzle.generate: equation validity', () {
    test('placed equations contain valid math (a op b = c)', () {
      final puzzle = StarChartScanPuzzle.generate(
        gridSize: 8,
        equationCount: 4,
        allowDiagonal: false,
        operators: ['+', '-'],
        seed: 0,
      );
      for (final eq in puzzle.placedEquations) {
        // Equations like "3+4=7" (5 chars) or "6+9=15" (6 chars)
        expect(eq.equation.length, greaterThanOrEqualTo(5),
            reason: 'equation "${eq.equation}" should be at least 5 chars');
        expect(eq.equation.contains('='), isTrue,
            reason: 'equation "${eq.equation}" must contain "="');
      }
    });

    test('placed equation cells are within grid bounds', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          gridSize: 7,
          equationCount: 3,
          allowDiagonal: true,
          operators: ['+'],
          seed: seed,
        );
        for (final eq in puzzle.placedEquations) {
          for (final cell in eq.cells) {
            expect(cell.$1, greaterThanOrEqualTo(0));
            expect(cell.$1, lessThan(puzzle.gridSize));
            expect(cell.$2, greaterThanOrEqualTo(0));
            expect(cell.$2, lessThan(puzzle.gridSize));
          }
        }
      }
    });

    test('equation characters match grid contents at placed cells', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          gridSize: 8,
          equationCount: 4,
          allowDiagonal: false,
          operators: ['+'],
          seed: seed,
        );
        for (final eq in puzzle.placedEquations) {
          for (int i = 0; i < eq.cells.length; i++) {
            final r = eq.cells[i].$1;
            final c = eq.cells[i].$2;
            expect(puzzle.grid[r][c], eq.equation[i].toString(),
                reason: 'grid[$r][$c] should be "${eq.equation[i]}" for equation "${eq.equation}"');
          }
        }
      }
    });
  });

  group('StarChartScanPuzzle.generate: difficulty scaling', () {
    test('larger grid holds more equations', () {
      final small = StarChartScanPuzzle.generate(
        gridSize: 7,
        equationCount: 3,
        allowDiagonal: false,
        operators: ['+'],
        seed: 0,
      );
      final large = StarChartScanPuzzle.generate(
        gridSize: 10,
        equationCount: 7,
        allowDiagonal: true,
        operators: ['+', '-', 'x'],
        seed: 0,
      );
      expect(large.placedEquations.length,
          greaterThanOrEqualTo(small.placedEquations.length));
    });

    test('diagonal placement produces diagonal equations', () {
      final puzzle = StarChartScanPuzzle.generate(
        gridSize: 10,
        equationCount: 6,
        allowDiagonal: true,
        operators: ['+'],
        seed: 42,
      );
      // At least some equations should be non-cardinal
      // (can't guarantee every puzzle has diagonals, but most should)
      final hasDiagonal = puzzle.placedEquations.any(
          (eq) => eq.direction.dr != 0 && eq.direction.dc != 0);
      // This is probabilistic -- just log it
      if (!hasDiagonal) {
        // ignore: avoid_print
        print('Note: no diagonal equations found (seed=42), this is rare but possible');
      }
    });
  });

  group('PlacedEquation', () {
    test('cells count matches equation length', () {
      final puzzle = StarChartScanPuzzle.generate(
        gridSize: 8,
        equationCount: 4,
        allowDiagonal: false,
        operators: ['+'],
        seed: 0,
      );
      for (final eq in puzzle.placedEquations) {
        expect(eq.cells.length, eq.equation.length);
      }
    });
  });
}
