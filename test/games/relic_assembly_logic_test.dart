// Unit tests for relic_assembly_logic.dart — pure puzzle logic only.
//
// Tests tile edge matching, grid dimensions, and validation logic
// for the edge-matching card puzzle.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/relic_assembly_logic.dart';

void main() {
  group('RelicTile.getEdge', () {
    test('rotation 0 returns edges in original order', () {
      final tile = RelicTile(edges: [1, 2, 3, 4], rotation: 0);
      expect(tile.getEdge(0), 1); // top
      expect(tile.getEdge(1), 2); // right
      expect(tile.getEdge(2), 3); // bottom
      expect(tile.getEdge(3), 4); // left
    });

    test('rotation 1 (90 CW): top becomes what was left', () {
      final tile = RelicTile(edges: [1, 2, 3, 4], rotation: 1);
      // getEdge(side) = edges[(side - rotation + 4) % 4]
      // top(0): edges[(0-1+4)%4] = edges[3] = 4
      // right(1): edges[(1-1+4)%4] = edges[0] = 1
      // bottom(2): edges[(2-1+4)%4] = edges[1] = 2
      // left(3): edges[(3-1+4)%4] = edges[2] = 3
      expect(tile.getEdge(0), 4);
      expect(tile.getEdge(1), 1);
      expect(tile.getEdge(2), 2);
      expect(tile.getEdge(3), 3);
    });

    test('rotation 2 (180): edges are reversed pairs', () {
      final tile = RelicTile(edges: [1, 2, 3, 4], rotation: 2);
      expect(tile.getEdge(0), 3);
      expect(tile.getEdge(1), 4);
      expect(tile.getEdge(2), 1);
      expect(tile.getEdge(3), 2);
    });
  });

  group('RelicTile.copyWith', () {
    test('creates a copy with a different rotation', () {
      final original = RelicTile(edges: [1, 2, 3, 4], rotation: 0);
      final copy = original.copyWith(rotation: 2);

      expect(copy.rotation, 2);
      expect(copy.edges, [1, 2, 3, 4]);
      expect(original.rotation, 0); // original unchanged
    });
  });

  group('RelicAssemblyGenerator structure', () {
    for (final dims in [
      [2, 2],
      [2, 3],
      [3, 3],
    ]) {
      final rows = dims[0];
      final cols = dims[1];

      test('${rows}x$cols grid: correct tile count', () async {
        final gen = RelicAssemblyGenerator();
        final puzzle = await gen.generate(
          rows: rows,
          cols: cols,
          edgeValueCount: 4,
        );

        expect(puzzle.rows, rows);
        expect(puzzle.cols, cols);
        expect(puzzle.solutionTiles.length, rows * cols);
        expect(puzzle.playerTiles.length, rows * cols);
      });

      test('${rows}x$cols grid: solution tiles have matching internal edges',
          () async {
        final gen = RelicAssemblyGenerator();
        for (int i = 0; i < 3; i++) {
          final puzzle = await gen.generate(
            rows: rows,
            cols: cols,
            edgeValueCount: 4,
          );

          // In the solution, all tiles have rotation 0.
          // Check right-left matches between horizontally adjacent tiles.
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols - 1; c++) {
              final left = puzzle.solutionTiles[r * cols + c];
              final right = puzzle.solutionTiles[r * cols + c + 1];
              expect(left.getEdge(1), right.getEdge(3),
                  reason: 'right edge of ($r,$c) must match left edge of ($r,${c + 1})');
            }
          }

          // Check bottom-top matches between vertically adjacent tiles.
          for (int r = 0; r < rows - 1; r++) {
            for (int c = 0; c < cols; c++) {
              final top = puzzle.solutionTiles[r * cols + c];
              final bottom = puzzle.solutionTiles[(r + 1) * cols + c];
              expect(top.getEdge(2), bottom.getEdge(0),
                  reason: 'bottom edge of ($r,$c) must match top edge of (${r + 1},$c)');
            }
          }
        }
      });
    }

    test('edge values are within 1..edgeValueCount', () async {
      final gen = RelicAssemblyGenerator();
      final puzzle = await gen.generate(
        rows: 3,
        cols: 3,
        edgeValueCount: 5,
      );

      for (final tile in puzzle.solutionTiles) {
        for (final edge in tile.edges) {
          expect(edge, inInclusiveRange(1, 5));
        }
      }
    });
  });

  group('RelicAssemblyPuzzle.validatePlacement', () {
    test('solution placement with identity mapping validates', () async {
      final gen = RelicAssemblyGenerator();
      for (int i = 0; i < 3; i++) {
        final puzzle = await gen.generate(
          rows: 2,
          cols: 2,
          edgeValueCount: 3,
        );

        // Build a valid placement using solutionTiles.
        // The solutionTiles are in row-major order with rotation 0.
        // playerTiles are shuffled, so we need to find which playerTile
        // matches each solution tile. Instead, let's directly test that
        // solutionTiles edges match.
        // We can't easily map playerTiles back, but we can verify that
        // the validation logic works by constructing a scenario.

        // Simple test: solution tiles all have rotation 0
        // Build a puzzle where we just use solutionTiles as playerTiles
        final testPuzzle = RelicAssemblyPuzzle(
          rows: puzzle.rows,
          cols: puzzle.cols,
          solutionTiles: puzzle.solutionTiles,
          playerTiles: puzzle.solutionTiles,
          edgeValueCount: puzzle.edgeValueCount,
        );

        final placement = List.generate(puzzle.rows * puzzle.cols, (i) => i);
        final rotations =
            List.generate(puzzle.rows * puzzle.cols, (_) => 0);

        expect(testPuzzle.validatePlacement(placement, rotations), isTrue);
      }
    });

    test('wrong placement length is rejected', () async {
      final gen = RelicAssemblyGenerator();
      final puzzle = await gen.generate(
        rows: 2,
        cols: 2,
        edgeValueCount: 3,
      );

      expect(puzzle.validatePlacement([0], [0]), isFalse);
    });

    test('invalid tile index is rejected', () async {
      final gen = RelicAssemblyGenerator();
      final puzzle = await gen.generate(
        rows: 2,
        cols: 2,
        edgeValueCount: 3,
      );

      final placement = [0, 1, 2, 99]; // 99 is out of range
      final rotations = [0, 0, 0, 0];
      expect(puzzle.validatePlacement(placement, rotations), isFalse);
    });
  });
}
