// Unit tests for starloader_level_generator.dart — the Sokoban reverse-play
// level generator (pure Dart).
//
// LIMITATIONS / NOTES:
//   * LevelGenerator uses a PRIVATE, UNSEEDED `math.Random` with no injection
//     seam (lib/ must not be modified). We therefore cannot pin exact output.
//     Instead we assert INVARIANTS that must hold for EVERY generated level,
//     across many iterations.
//   * The `_formsDeadlock` 2x2-block check mentioned in the task brief lives in
//     the sibling CLI variant `starloader_level_generator_2.dart`, NOT in this
//     file (which the brief says to ignore). It cannot be exercised here, so it
//     is not tested. The deadlock-avoidance behaviour of THIS file is instead
//     covered indirectly by the "score > 0 / solution is non-trivial" invariant.
//
// Invariants asserted over many generated levels:
//   * The outer ring of the grid is always WALL (border integrity).
//   * The walkable interior (floor / target / player / box tiles) forms a
//     single connected component (4-connectivity).
//   * Exactly one PLAYER is placed, and it sits on a walkable tile.
//   * `numBoxes` targets exist in the structure, every box maps to a target,
//     and every box/target/player sits inside the border.
//   * `optimalMoves` (the generation score) is always > 0 — a non-trivial
//     solution (this holds both for genuine reverse-play results and for the
//     deterministic fallback level).

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';

/// Tiles that a player/box can occupy or move through.
const Set<int> _walkable = {
  LevelGenerator.FLOOR,
  LevelGenerator.TARGET,
  LevelGenerator.BOX,
  LevelGenerator.BOX_ON_TARGET,
  LevelGenerator.PLAYER,
};

/// 4-connectivity flood fill over walkable tiles starting at [sr],[sc].
int _connectedWalkableCount(List<List<int>> grid, int sr, int sc) {
  final rows = grid.length;
  final cols = grid[0].length;
  final seen = List.generate(rows, (_) => List<bool>.filled(cols, false));
  final stack = <List<int>>[
    [sr, sc],
  ];
  var count = 0;
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final r = p[0];
    final c = p[1];
    if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
    if (seen[r][c]) continue;
    if (!_walkable.contains(grid[r][c])) continue;
    seen[r][c] = true;
    count++;
    stack.add([r - 1, c]);
    stack.add([r + 1, c]);
    stack.add([r, c - 1]);
    stack.add([r, c + 1]);
  }
  return count;
}

int _countTile(List<List<int>> grid, int tile) {
  var n = 0;
  for (final row in grid) {
    for (final cell in row) {
      if (cell == tile) n++;
    }
  }
  return n;
}

void main() {
  group('LevelGenerator.generateLevel invariants', () {
    const dimX = 8;
    const dimY = 8;
    const numBoxes = 3;
    const iterations = 25;

    test('produces $iterations levels all satisfying core invariants', () {
      final gen = LevelGenerator();

      for (var iter = 0; iter < iterations; iter++) {
        final level = gen.generateLevel(
          dimX: dimX,
          dimY: dimY,
          numBoxes: numBoxes,
          maxTries: 10,
        );

        final state = level.roomState;
        final structure = level.roomStructure;

        // --- Shape ---
        expect(state.length, dimX, reason: 'iter $iter: row count');
        expect(structure.length, dimX, reason: 'iter $iter: struct row count');
        for (final row in state) {
          expect(row.length, dimY, reason: 'iter $iter: col count');
        }

        // --- Border integrity: the whole outer ring is WALL. ---
        for (var c = 0; c < dimY; c++) {
          expect(state[0][c], LevelGenerator.WALL,
              reason: 'iter $iter: top border at col $c');
          expect(state[dimX - 1][c], LevelGenerator.WALL,
              reason: 'iter $iter: bottom border at col $c');
        }
        for (var r = 0; r < dimX; r++) {
          expect(state[r][0], LevelGenerator.WALL,
              reason: 'iter $iter: left border at row $r');
          expect(state[r][dimY - 1], LevelGenerator.WALL,
              reason: 'iter $iter: right border at row $r');
        }

        // --- Exactly one player, on a walkable interior tile. ---
        expect(_countTile(state, LevelGenerator.PLAYER), 1,
            reason: 'iter $iter: exactly one player');
        var playerR = -1;
        var playerC = -1;
        var totalWalkable = 0;
        for (var r = 0; r < dimX; r++) {
          for (var c = 0; c < dimY; c++) {
            if (_walkable.contains(state[r][c])) {
              totalWalkable++;
              // Walkable tiles must be in the interior, never on the border.
              expect(r > 0 && r < dimX - 1 && c > 0 && c < dimY - 1, isTrue,
                  reason: 'iter $iter: walkable tile on border at $r,$c');
            }
            if (state[r][c] == LevelGenerator.PLAYER) {
              playerR = r;
              playerC = c;
            }
          }
        }
        expect(playerR, isNot(-1), reason: 'iter $iter: player located');

        // --- Floor connectivity: all walkable tiles reachable from player. ---
        final reachable = _connectedWalkableCount(state, playerR, playerC);
        expect(reachable, totalWalkable,
            reason: 'iter $iter: walkable region must be a single component '
                '(reachable $reachable of $totalWalkable)');

        // --- Targets / boxes / mapping. ---
        final targetCount = _countTile(structure, LevelGenerator.TARGET);
        expect(targetCount, numBoxes,
            reason: 'iter $iter: one target per box in structure');
        expect(level.boxMapping.length, numBoxes,
            reason: 'iter $iter: box mapping has one entry per box');
        for (final entry in level.boxMapping.entries) {
          final box = entry.value;
          expect(box.length, 2, reason: 'iter $iter: box pos is a coordinate');
          expect(
            box[0] > 0 && box[0] < dimX - 1 && box[1] > 0 && box[1] < dimY - 1,
            isTrue,
            reason: 'iter $iter: box ${box.join(',')} inside border',
          );
        }

        // --- Non-trivial solution. ---
        expect(level.optimalMoves, greaterThan(0),
            reason: 'iter $iter: generated level must have a positive score');
      }
    });

    test('respects requested dimensions for varied sizes', () {
      final gen = LevelGenerator();
      for (final size in const [
        [7, 9],
        [10, 8],
        [9, 9],
      ]) {
        final level = gen.generateLevel(
          dimX: size[0],
          dimY: size[1],
          numBoxes: 2,
          maxTries: 10,
        );
        expect(level.roomState.length, size[0]);
        expect(level.roomState[0].length, size[1]);
        expect(level.optimalMoves, greaterThan(0));
      }
    });
  });

  group('GeneratedLevel.toLayoutString', () {
    test('renders walls, player, boxes and targets consistently', () {
      final gen = LevelGenerator();
      final level = gen.generateLevel(
        dimX: 8,
        dimY: 8,
        numBoxes: 2,
        maxTries: 10,
      );
      final layout = level.toLayoutString();
      final lines = layout.split('\n');

      // One line per row, each line as wide as the grid.
      expect(lines.length, level.roomState.length);
      for (final line in lines) {
        expect(line.length, level.roomState[0].length);
      }
      // Exactly one player glyph.
      expect('P'.allMatches(layout).length, 1);
      // Border is all walls -> first and last line are entirely 'W'.
      expect(lines.first, 'W' * level.roomState[0].length);
      expect(lines.last, 'W' * level.roomState[0].length);
    });
  });
}
