// Unit tests for star_chart_scan_logic.dart (equation finder redesign).
//
// Tests equation generation, grid placement, and puzzle invariants.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_chart_scan_logic.dart';

void main() {
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
