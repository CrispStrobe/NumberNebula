// Unit tests for StarloaderSolver — the push-optimal Sokoban solver that
// measures the true difficulty of Cargo-Loader (StarLoader) levels.
//
// Tile encoding (matches LevelGenerator):
//   structure: WALL=0, FLOOR=1, TARGET=2
//   state:     BOX_ON_TARGET=3, BOX=4, PLAYER=5 (else mirrors structure)
//
// These cases are fully deterministic — no Random, no assets, no plugins.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

void main() {
  group('shipped level pool (assets/data/starloader_levels.json)', () {
    test('every baked level is solvable and stored optimalMoves is the true '
        'push-optimal count', () {
      final levels = (jsonDecode(
              File('assets/data/starloader_levels.json').readAsStringSync())
          ['levels'] as List);
      expect(levels, isNotEmpty);

      for (final l in levels) {
        final id = l['id'];
        final structure = (l['roomStructure'] as List)
            .map((r) => List<int>.from(r))
            .toList();
        final state =
            (l['roomState'] as List).map((r) => List<int>.from(r)).toList();
        final res = StarloaderSolver.fromGrids(structure, state)
            .solve(nodeBudget: 1000000);
        expect(res.solved, isTrue,
            reason: 'baked level $id must be solvable (got $res)');
        expect(l['optimalMoves'], res.pushes,
            reason: 'baked level $id stored optimalMoves '
                '${l['optimalMoves']} != true optimal ${res.pushes}');
        // Difficulty floor by grade — no trivial levels should ship.
        final grade = int.parse((l['difficulty'] as String).split('_')[1]);
        final floors = {1: 6, 2: 9, 3: 13, 4: 17};
        expect(res.pushes, greaterThanOrEqualTo(floors[grade]!),
            reason: 'baked level $id (grade $grade) is too trivial '
                '(${res.pushes} pushes)');
      }
    });
  });

  group('StarloaderSolver.solve', () {
    test('already-solved level needs 0 pushes', () {
      // #####
      // #@*.#  -> box already on target; remaining target has no box... use a
      // single box already on its target.
      final structure = [
        [0, 0, 0, 0],
        [0, 1, 2, 0],
        [0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0],
        [0, 5, 3, 0], // player, box-on-target
        [0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isTrue);
      expect(r.pushes, 0);
    });

    test('single box, one push to target', () {
      // #####
      // #@$.#
      // #####
      final structure = [
        [0, 0, 0, 0, 0],
        [0, 1, 1, 2, 0],
        [0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0],
        [0, 5, 4, 2, 0],
        [0, 0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isTrue);
      expect(r.pushes, 1);
    });

    test('single box, two pushes (box travels two cells)', () {
      // ######
      // #@$ .#
      // ######
      final structure = [
        [0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 2, 0],
        [0, 0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0, 0],
        [0, 5, 4, 1, 2, 0],
        [0, 0, 0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isTrue);
      expect(r.pushes, 2);
    });

    test('box frozen in a non-target corner is proven unsolvable', () {
      final structure = [
        [0, 0, 0, 0, 0],
        [0, 1, 1, 1, 0],
        [0, 1, 1, 2, 0],
        [0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0],
        [0, 4, 1, 5, 0], // box jammed into corner (1,1), not a target
        [0, 1, 1, 2, 0],
        [0, 0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isFalse);
      expect(r.exhausted, isFalse,
          reason: 'should be proven unsolvable, not budget-capped');
      expect(r.pushes, isNull);
    });

    test('mismatched box/target counts is unsolvable', () {
      // Two boxes, one target.
      final structure = [
        [0, 0, 0, 0, 0],
        [0, 1, 1, 2, 0],
        [0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0],
        [0, 4, 4, 5, 0],
        [0, 0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isFalse);
    });

    test('two boxes with an open lane: optimal is the sum of their pushes', () {
      // Open top lane (row 1) lets the player walk around either box, so each
      // box can be pushed one cell east onto its target independently.
      //   #######
      //   #     #   <- open lane for repositioning
      //   #@$.$.#   <- player, box, target, box, target
      //   #######
      final structure = [
        [0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 1, 0],
        [0, 1, 1, 2, 1, 2, 0],
        [0, 0, 0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 1, 0],
        [0, 5, 4, 2, 4, 2, 0],
        [0, 0, 0, 0, 0, 0, 0],
      ];
      final r = StarloaderSolver.fromGrids(structure, state).solve();
      expect(r.solved, isTrue);
      // Each box is Manhattan-distance 1 from its target -> 2 pushes minimum,
      // and the open lane makes that achievable.
      expect(r.pushes, 2);
    });

    test('dead squares include non-target corners and exclude targets', () {
      final structure = [
        [0, 0, 0, 0, 0],
        [0, 1, 1, 1, 0],
        [0, 1, 2, 1, 0],
        [0, 1, 1, 1, 0],
        [0, 0, 0, 0, 0],
      ];
      final state = [
        [0, 0, 0, 0, 0],
        [0, 5, 1, 1, 0],
        [0, 1, 2, 1, 0],
        [0, 1, 1, 1, 0],
        [0, 0, 0, 0, 0],
      ];
      final solver = StarloaderSolver.fromGrids(structure, state);
      final dead = solver.deadSquares;
      int idx(int r, int c) => r * 5 + c;
      // The four interior corners are non-target corners -> dead.
      expect(dead[idx(1, 1)], isTrue);
      expect(dead[idx(1, 3)], isTrue);
      expect(dead[idx(3, 1)], isTrue);
      expect(dead[idx(3, 3)], isTrue);
      // The centre target is never dead.
      expect(dead[idx(2, 2)], isFalse);
    });
  });
}
