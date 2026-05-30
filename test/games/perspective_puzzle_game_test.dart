// Unit tests for perspective_puzzle_game.dart (Perspective Puzzle, 3D spatial).
//
// TESTABILITY NOTES:
//   The interactive surface (flutter_cube 3D scene, AnimationControllers, camera
//   panning, GameProvider/HapticFeedback/dialog wiring) lives in the private
//   _PerspectivePuzzleGameState and is not unit-testable without a full provider
//   tree plus plugin/asset mocks. The GAME LOGIC, however, is exposed through
//   public, top-level, pure surfaces:
//     - PerspectivePuzzle.generate(Map<String,int>)  (the compute() entry point)
//     - PerspectivePuzzle (structure, gridSize, maxHeight, difficulty,
//       correctViews) and the Block / PerspectiveView types.
//   `generate` internally uses an UNSEEDED math.Random() built for compute()
//   isolates, with no injection seam (per the harness rules we do NOT add one).
//   We therefore assert the structural INVARIANTS that every generated puzzle
//   must satisfy across many iterations, plus the load-bearing relationships of
//   the four projected views (these views ARE the answer the player must pick,
//   so a wrong projection makes the puzzle unwinnable or ambiguous).

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/perspective_puzzle_game.dart';

void main() {
  // Sweep grade/level combos with many repeats to exercise the unseeded RNG.
  final paramSets = <Map<String, int>>[
    {'grade': 1, 'level': 1},
    {'grade': 1, 'level': 8},
    {'grade': 3, 'level': 4},
    {'grade': 5, 'level': 12},
    {'grade': 2, 'level': 20},
  ];

  group('PerspectivePuzzle.generate invariants', () {
    test('structure & derived fields are internally consistent (250 iters)', () {
      for (final params in paramSets) {
        // Re-derive the deterministic difficulty/gridSize the source computes,
        // so we can check generate() agrees with its own documented formulas.
        final grade = params['grade']!;
        final level = params['level']!;
        final expectedDifficulty =
            (grade + (level ~/ 4)) < 5 ? grade + (level ~/ 4) : 5;
        final expectedGridSize = 3 + (expectedDifficulty ~/ 3);

        for (int i = 0; i < 50; i++) {
          final puzzle = PerspectivePuzzle.generate(params);

          expect(puzzle.difficulty, expectedDifficulty,
              reason: 'difficulty formula for $params');
          expect(puzzle.gridSize, expectedGridSize,
              reason: 'gridSize formula for $params');

          final size = puzzle.gridSize;
          expect(puzzle.structure, isNotEmpty);

          // Every block sits inside the grid footprint, at non-negative height.
          for (final b in puzzle.structure) {
            expect(b.x, inInclusiveRange(0, size - 1));
            expect(b.z, inInclusiveRange(0, size - 1));
            expect(b.y, greaterThanOrEqualTo(0));
          }

          // No two blocks share the same (x, y, z) cell.
          final cells = puzzle.structure.map((b) => '${b.x},${b.y},${b.z}');
          expect(cells.toSet().length, puzzle.structure.length,
              reason: 'block positions must be unique');

          // maxHeight is exactly the tallest occupied y.
          final tallest =
              puzzle.structure.map((b) => b.y).reduce((a, c) => a > c ? a : c);
          expect(puzzle.maxHeight, tallest);
        }
      }
    });

    test('columns are gravity-filled: no floating blocks (250 iters)', () {
      // The generator stacks blocks by incrementing a per-(x,z) heightMap, so a
      // block at height y in a column implies every cell below it is occupied.
      for (final params in paramSets) {
        for (int i = 0; i < 50; i++) {
          final puzzle = PerspectivePuzzle.generate(params);

          // Map column (x,z) -> set of occupied y values.
          final columns = <String, Set<int>>{};
          for (final b in puzzle.structure) {
            columns.putIfAbsent('${b.x},${b.z}', () => <int>{}).add(b.y);
          }
          for (final entry in columns.entries) {
            final heights = entry.value;
            final top = heights.reduce((a, c) => a > c ? a : c);
            // y from 0..top must all be present (contiguous, ground-anchored).
            for (int y = 0; y <= top; y++) {
              expect(heights.contains(y), isTrue,
                  reason: 'floating gap in column ${entry.key} at y=$y');
            }
          }
        }
      }
    });
  });

  group('PerspectivePuzzle.generate correctViews', () {
    test('all four views exist with correct dimensions (250 iters)', () {
      for (final params in paramSets) {
        for (int i = 0; i < 50; i++) {
          final puzzle = PerspectivePuzzle.generate(params);
          final size = puzzle.gridSize;
          final rows = puzzle.maxHeight + 1;

          expect(puzzle.correctViews.keys.toSet(),
              {'Front', 'Back', 'Left', 'Right'});

          for (final view in puzzle.correctViews.values) {
            expect(view.length, rows, reason: 'one row per height level');
            for (final row in view) {
              expect(row.length, size, reason: 'one column per grid lane');
            }
          }
        }
      }
    });

    test('every view cell maps to a real block in the structure (250 iters)',
        () {
      // A non-null cell in any projection must be a block that exists in the
      // 3D structure (projection never invents blocks).
      for (final params in paramSets) {
        for (int i = 0; i < 50; i++) {
          final puzzle = PerspectivePuzzle.generate(params);
          for (final view in puzzle.correctViews.values) {
            for (final row in view) {
              for (final Block? cell in row) {
                if (cell != null) {
                  expect(puzzle.structure.contains(cell), isTrue,
                      reason: 'projected cell must exist in structure');
                }
              }
            }
          }
        }
      }
    });

    test('Front view picks the max-z block per (x,y) and bottom-anchors it', () {
      // Verify the actual projection semantics documented in _getFrontView:
      //   row index = maxHeight - y  (so the highest y is at the top, y=0 at
      //   bottom), col index = x, and the visible block is the one with the
      //   largest z among blocks sharing that (x,y).
      for (final params in paramSets) {
        for (int i = 0; i < 30; i++) {
          final puzzle = PerspectivePuzzle.generate(params);
          final front = puzzle.correctViews['Front']!;
          final maxH = puzzle.maxHeight;

          for (final b in puzzle.structure) {
            // Find the front-visible block for this (x,y) directly.
            final sameXY = puzzle.structure
                .where((o) => o.x == b.x && o.y == b.y)
                .toList();
            final maxZ =
                sameXY.map((o) => o.z).reduce((a, c) => a > c ? a : c);
            final visible = sameXY.firstWhere((o) => o.z == maxZ);

            final cell = front[maxH - b.y][b.x];
            expect(cell, isNotNull,
                reason: 'occupied (x:${b.x}, y:${b.y}) must show in Front');
            expect(cell, visible,
                reason: 'Front shows the largest-z block at (x,y)');
          }
        }
      }
    });

    test('Back view is the horizontal mirror of column choice (min-z visible)',
        () {
      // _getBackView: col = size-1-x, visible block = min z at (x,y).
      for (final params in paramSets) {
        for (int i = 0; i < 30; i++) {
          final puzzle = PerspectivePuzzle.generate(params);
          final back = puzzle.correctViews['Back']!;
          final size = puzzle.gridSize;
          final maxH = puzzle.maxHeight;

          for (final b in puzzle.structure) {
            final sameXY = puzzle.structure
                .where((o) => o.x == b.x && o.y == b.y)
                .toList();
            final minZ =
                sameXY.map((o) => o.z).reduce((a, c) => a < c ? a : c);
            final visible = sameXY.firstWhere((o) => o.z == minZ);

            final cell = back[maxH - b.y][size - 1 - b.x];
            expect(cell, visible,
                reason: 'Back shows the smallest-z block, mirrored in x');
          }
        }
      }
    });

    test('the Block typedef carries position and Color', () {
      final puzzle = PerspectivePuzzle.generate({'grade': 3, 'level': 4});
      final b = puzzle.structure.first;
      expect(b.color, isA<Color>());
      expect(b.x, isA<int>());
      expect(b.y, isA<int>());
      expect(b.z, isA<int>());
    });
  });
}
