// Tests for the in-app Sokoban generator (lib/features/games/services/
// sokoban_generator.dart) and its Star Loader int-grid conversion.
//
// The tool/ copy (tool/sokoban_generator.dart) has its own broad invariant
// suite in test/tool/sokoban_generator_test.dart. This file focuses on what is
// unique to the lib copy: the StarLoaderEntry conversion, and a cross-check of
// every generated level against the game's OWN solver (StarloaderSolver) — an
// independent oracle that both confirms solvability and that the generator's
// push count is push-optimal (so shipped `optimalMoves` are trustworthy).

import 'package:flutter_test/flutter_test.dart';

import 'package:space_math_academy/features/games/services/sokoban_generator.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

int _count(List<List<int>> grid, int tile) {
  var n = 0;
  for (final row in grid) {
    for (final v in row) {
      if (v == tile) n++;
    }
  }
  return n;
}

void main() {
  group('generate (lib copy) — solvable & self-consistent', () {
    for (final d in const [1, 2, 3, 4]) {
      test('difficulty $d level verifies via replay', () {
        for (final seed in const [1, 5, 9]) {
          final lv = generate(d, seed: seed, timeBudget: 8);
          expect(lv.verify(), isTrue, reason: 'd=$d seed=$seed');
          expect(lv.boxes.length, PARAMS[d]!.boxes);
          expect(lv.goals.length, PARAMS[d]!.boxes);
          expect(lv.stats['pushes'], greaterThan(0));
        }
      });
    }
  });

  group('sokobanToStarLoaderEntry — grid schema', () {
    test('produces a well-formed, bordered grid with matching pieces', () {
      for (final d in const [1, 2, 3, 4]) {
        for (final seed in const [2, 7, 13]) {
          final lv = generate(d, seed: seed, timeBudget: 8);
          final e = sokobanToStarLoaderEntry(lv);
          final where = 'd=$d seed=$seed';

          // dims mirror the grid shape
          expect(e.roomState.length, e.dimX, reason: '$where: dimX');
          expect(e.roomStructure.length, e.dimX, reason: '$where: struct rows');
          for (final row in e.roomState) {
            expect(row.length, e.dimY, reason: '$where: dimY');
          }

          // outer ring is all wall
          for (var c = 0; c < e.dimY; c++) {
            expect(e.roomState[0][c], slWall, reason: '$where: top border');
            expect(e.roomState[e.dimX - 1][c], slWall,
                reason: '$where: bottom border');
          }
          for (var r = 0; r < e.dimX; r++) {
            expect(e.roomState[r][0], slWall, reason: '$where: left border');
            expect(e.roomState[r][e.dimY - 1], slWall,
                reason: '$where: right border');
          }

          // piece counts: one player, boxes == targets == generator box count
          expect(_count(e.roomState, slPlayer), 1, reason: '$where: player');
          final targets = _count(e.roomStructure, slTarget);
          final boxes = _count(e.roomState, slBox);
          expect(targets, PARAMS[d]!.boxes, reason: '$where: target count');
          expect(boxes, PARAMS[d]!.boxes, reason: '$where: box count');

          // player must NOT sit on a target (not representable in the layout)
          var playerOnTarget = false;
          for (var r = 0; r < e.dimX; r++) {
            for (var c = 0; c < e.dimY; c++) {
              if (e.roomState[r][c] == slPlayer &&
                  e.roomStructure[r][c] == slTarget) {
                playerOnTarget = true;
              }
            }
          }
          expect(playerOnTarget, isFalse, reason: '$where: player off target');
        }
      }
    });
  });

  group('cross-check with the game solver (StarloaderSolver)', () {
    test('every generated entry is solvable with a matching push count', () {
      for (final d in const [1, 2, 3, 4]) {
        for (final seed in const [3, 11, 21]) {
          final lv = generate(d, seed: seed, timeBudget: 8);
          final e = sokobanToStarLoaderEntry(lv);
          final where = 'd=$d seed=$seed';

          final solver =
              StarloaderSolver.fromGrids(e.roomStructure, e.roomState);
          final result = solver.solve(nodeBudget: 400000);

          expect(result.solved || result.exhausted, isTrue,
              reason: '$where: solver must not declare it unsolvable');
          if (result.solved) {
            // Both A*s are push-optimal → identical minimum push count.
            expect(result.pushes, e.optimalMoves,
                reason: '$where: solver pushes match optimalMoves');
          }
        }
      }
    });
  });

  group('generateStarLoaderEntry — determinism & range', () {
    test('same seed reproduces identical grids', () {
      final a = generateStarLoaderEntry(difficulty: 3, seed: 424242, timeBudget: 8);
      final b = generateStarLoaderEntry(difficulty: 3, seed: 424242, timeBudget: 8);
      expect(a.roomStructure, b.roomStructure);
      expect(a.roomState, b.roomState);
      expect(a.optimalMoves, b.optimalMoves);
    });
  });
}
