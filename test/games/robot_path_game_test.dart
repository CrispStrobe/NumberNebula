// Unit tests for robot_path_game.dart.
//
// The screen widget (RobotPathGame) hard-couples to TickerProvider animations,
// Provider<GameProvider>, generated localisations and CustomPainters, and it
// runs infinite repeating AnimationControllers — so a settle-based widget test
// would hang and a smoke test adds little. Instead we unit-test the pure logic
// that the screen file itself defines as top-level / static members:
//
//   * PathLevel.generate(grade, level) — the screen's own conversion of a
//     RobotPathGenerator level into a CellType grid, including grade-gating of
//     obstacle kinds, gridSize, startDirection selection and optimalMoves.
//   * SpaceParticle.update() and ExplosionParticle.update() — deterministic
//     visual-effect physics with no dependency on context/animation.
//
// PathLevel.generate relies on RobotPathGenerator's INTERNAL, UNSEEDED
// math.Random (no injection seam exists, and the hard rules forbid adding one),
// so we assert INVARIANTS that must hold regardless of the random draws across
// many generated levels, never exact literal layouts.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Offset, Color, Colors;

import 'package:space_math_academy/features/games/screens/robot_path_game.dart';

/// 4-neighbour BFS over walkable CellTypes. MOVABLE acts as a wall, mirroring
/// the generator's own reachability predicate (a placed movable block must
/// still leave the base level traversable, which the generator validates).
bool _reaches(
    List<List<CellType>> grid, int fromR, int fromC, int toR, int toC) {
  if (fromR == toR && fromC == toC) return true;
  final n = grid.length;
  bool walkable(CellType t) =>
      t == CellType.empty ||
      t == CellType.start ||
      t == CellType.goal ||
      t == CellType.jumpableWall ||
      t == CellType.destructible;
  final visited = <String>{'$fromR,$fromC'};
  final queue = <List<int>>[
    [fromR, fromC]
  ];
  const deltas = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1],
  ];
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    if (cur[0] == toR && cur[1] == toC) return true;
    for (final d in deltas) {
      final nr = cur[0] + d[0];
      final nc = cur[1] + d[1];
      if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
      final key = '$nr,$nc';
      if (visited.contains(key)) continue;
      if (!walkable(grid[nr][nc])) continue;
      visited.add(key);
      queue.add([nr, nc]);
    }
  }
  return false;
}

void _assertLevelInvariants(PathLevel level, int grade) {
  final n = level.gridSize;

  // Square grid of the reported size.
  expect(level.grid.length, n, reason: 'grid row count == gridSize');
  for (final row in level.grid) {
    expect(row.length, n, reason: 'grid is square');
  }

  // Start / goal in bounds, distinct, and carry the correct markers.
  expect(level.startRow >= 0 && level.startRow < n, isTrue);
  expect(level.startCol >= 0 && level.startCol < n, isTrue);
  expect(level.goalRow >= 0 && level.goalRow < n, isTrue);
  expect(level.goalCol >= 0 && level.goalCol < n, isTrue);
  expect(level.startRow == level.goalRow && level.startCol == level.goalCol,
      isFalse,
      reason: 'start and goal differ');
  expect(level.grid[level.startRow][level.startCol], CellType.start,
      reason: 'start cell marked start');
  expect(level.grid[level.goalRow][level.goalCol], CellType.goal,
      reason: 'goal cell marked goal');

  // startDirection is one of the four cardinal codes used by the mover.
  expect(level.startDirection, inInclusiveRange(0, 3));

  // optimalMoves is sensible.
  expect(level.optimalMoves, greaterThanOrEqualTo(0));

  // Grade-gating: obstacle kinds are stripped to plain corridor below the
  // grade at which the matching command unlocks (see PathLevel.generate).
  for (final row in level.grid) {
    for (final cell in row) {
      if (grade < 2) {
        expect(cell, isNot(CellType.jumpableWall),
            reason: 'no jumpable walls below grade 2');
      }
      if (grade < 3) {
        expect(cell, isNot(CellType.destructible),
            reason: 'no destructibles below grade 3');
      }
      if (grade < 4) {
        expect(cell, isNot(CellType.movable),
            reason: 'no movable blocks below grade 4');
      }
    }
  }

  // For grade 1 there are never movable blocks, so the plain-walk corridor
  // from start to goal over walkable tiles must be continuous.
  final hasMovable =
      level.grid.any((row) => row.any((c) => c == CellType.movable));
  if (!hasMovable) {
    expect(
      _reaches(level.grid, level.startRow, level.startCol, level.goalRow,
          level.goalCol),
      isTrue,
      reason: 'goal reachable from start over walkable tiles',
    );
  }
}

void main() {
  group('PathLevel.generate invariants', () {
    test('grade 1 levels: plain corridor, no advanced obstacles', () {
      for (int level = 1; level <= 5; level++) {
        for (int i = 0; i < 10; i++) {
          final pl = PathLevel.generate(1, level);
          _assertLevelInvariants(pl, 1);
        }
      }
    });

    test('grades 2..4 across several levels stay structurally valid', () {
      for (int grade = 2; grade <= 4; grade++) {
        for (int level = 1; level <= 5; level++) {
          for (int i = 0; i < 6; i++) {
            final pl = PathLevel.generate(grade, level);
            _assertLevelInvariants(pl, grade);
          }
        }
      }
    });

    test('gridSize grows with complexity but stays clamped to 10..17', () {
      // PathLevel.generate clamps dim to [10,17]; gridSize equals the
      // generator grid length, which equals that dim.
      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 5; level++) {
          final pl = PathLevel.generate(grade, level);
          expect(pl.gridSize, inInclusiveRange(10, 17),
              reason: 'gridSize clamped to [10,17]');
        }
      }
    });

    test('startDirection points at a walkable neighbour when one exists', () {
      // generate() picks startDirection toward an adjacent empty/goal cell.
      // direction codes: 0=up,1=right(col+1 via x,y+1),2=down,3=left.
      // The screen stores grid as grid[row][col] with start at
      // (startRow,startCol). We verify the chosen direction is consistent:
      // the neighbour it points to is in-bounds, and if ANY orthogonal
      // walkable neighbour exists the chosen one is itself walkable.
      bool walkable(CellType t) =>
          t == CellType.empty || t == CellType.goal;
      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 5; level++) {
          for (int i = 0; i < 5; i++) {
            final pl = PathLevel.generate(grade, level);
            final r = pl.startRow;
            final c = pl.startCol;
            // Map direction code to (dr,dc) as used by generate()'s probes:
            // 1 -> (0,+1), 2 -> (+1,0), 3 -> (0,-1), 0 -> (-1,0).
            const drBy = {0: -1, 1: 0, 2: 1, 3: 0};
            const dcBy = {0: 0, 1: 1, 2: 0, 3: -1};
            final nr = r + drBy[pl.startDirection]!;
            final nc = c + dcBy[pl.startDirection]!;
            final anyWalkableNeighbour = [
              [r - 1, c],
              [r + 1, c],
              [r, c - 1],
              [r, c + 1],
            ].any((p) {
              final pr = p[0];
              final pc = p[1];
              if (pr < 0 || pr >= pl.gridSize || pc < 0 || pc >= pl.gridSize) {
                return false;
              }
              return walkable(pl.grid[pr][pc]);
            });
            if (anyWalkableNeighbour) {
              expect(nr >= 0 && nr < pl.gridSize, isTrue,
                  reason: 'chosen neighbour row in bounds');
              expect(nc >= 0 && nc < pl.gridSize, isTrue,
                  reason: 'chosen neighbour col in bounds');
              expect(walkable(pl.grid[nr][nc]), isTrue,
                  reason: 'startDirection points at a walkable cell');
            }
          }
        }
      }
    });
  });

  group('SpaceParticle.update physics', () {
    test('advances position by velocity*dt and reports death at lifetime', () {
      final p = SpaceParticle(
        position: const Offset(10, 20),
        velocity: const Offset(100, -50),
        size: 3,
        opacity: 1.0,
        color: const Color(0xFFFFFFFF),
        lifetime: 0.1,
      );
      final dead = p.update();
      // One tick is 0.016s. Position moves by velocity * 0.016.
      expect(p.position.dx, closeTo(10 + 100 * 0.016, 1e-9));
      expect(p.position.dy, closeTo(20 + -50 * 0.016, 1e-9));
      // age (0.016) < lifetime (0.1) so it is still alive.
      expect(dead, isFalse);

      // Run enough ticks to exceed lifetime; it must eventually die and
      // opacity must clamp to >= 0 (never negative).
      bool died = false;
      for (int i = 0; i < 100 && !died; i++) {
        died = p.update();
        expect(p.opacity, greaterThanOrEqualTo(0.0));
      }
      expect(died, isTrue, reason: 'particle dies once age >= lifetime');
    });
  });

  group('ExplosionParticle.update physics', () {
    test('decays velocity and life, dies after finite ticks', () {
      final e = ExplosionParticle(
        position: const Offset(0, 0),
        velocity: const Offset(80, 80),
        size: 4,
        color: Colors.orange,
      );
      final initialSpeed = e.velocity.distance;
      e.update();
      // Velocity is multiplied by 0.94 each tick -> strictly shrinks.
      expect(e.velocity.distance, lessThan(initialSpeed));

      bool died = false;
      int ticks = 0;
      while (!died && ticks < 1000) {
        died = e.update();
        ticks++;
      }
      expect(died, isTrue, reason: 'explosion particle expires');
      // life decreases by 0.02/tick from 1.0 (minus the one tick already
      // taken), so death occurs in well under 100 ticks.
      expect(ticks, lessThan(100));
    });
  });
}
