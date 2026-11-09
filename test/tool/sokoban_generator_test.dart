// Unit tests for tool/sokoban_generator.dart — the difficulty-parametrized
// Sokoban level generator (faithful Dart port of tool/sokoban_generator.py).
//
// STRATEGY
//   * The generator is seeded (dart:math Random) so (difficulty, seed) is
//     reproducible; a determinism test pins that.  Output is NOT byte-equal
//     to the Python tool (different RNG), so — like the sibling
//     starloader_level_generator_test — the end-to-end tests assert
//     INVARIANTS that must hold for EVERY generated level rather than exact
//     bytes.
//   * The headline invariant (solvability) is checked with an INDEPENDENT
//     replay oracle written here in (row, col) space, distinct from the
//     library's own Level.verify(), so a bug shared by generation and
//     verification cannot hide.
//   * Pure helpers (pullMetric / freeze2x2 / reachable / roomOk / makeNbrs /
//     solutionMetrics / template synthesis) are unit-tested directly on
//     hand-built grids.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sokoban_generator.dart';

// --------------------------------------------------------------- test oracle
/// Independent solution replayer. Works entirely in (row, col) string space,
/// sharing none of the int-delta machinery of the code under test. Returns
/// true iff replaying [lv.solution] from the start state lands every box on a
/// goal without ever pushing into a wall / another box / off the floor.
bool replaySolves(Level lv) {
  Set<String> rc(Iterable<int> cells) =>
      {for (final c in cells) '${rowOf(c)},${colOf(c)}'};
  final floors = rc(lv.floors);
  final goals = rc(lv.goals);
  final boxes = rc(lv.boxes);
  var pr = rowOf(lv.player), pc = colOf(lv.player);
  const delta = {
    'u': [-1, 0],
    'd': [1, 0],
    'l': [0, -1],
    'r': [0, 1],
  };
  for (final ch in lv.solution.split('')) {
    final dl = delta[ch.toLowerCase()];
    if (dl == null) return false; // stray character
    final nr = pr + dl[0], nc = pc + dl[1];
    final np = '$nr,$nc';
    if (boxes.contains(np)) {
      final bp = '${nr + dl[0]},${nc + dl[1]}';
      if (!floors.contains(bp) || boxes.contains(bp)) return false;
      boxes.remove(np);
      boxes.add(bp);
    } else if (!floors.contains(np)) {
      return false;
    }
    pr = nr;
    pc = nc;
  }
  return boxes.length == goals.length && boxes.containsAll(goals);
}

/// 4-connectivity flood fill count over [floors] from [start].
int connectedCount(Set<int> floors, int start) {
  final seen = <int>{start};
  final stack = <int>[start];
  while (stack.isNotEmpty) {
    final x = stack.removeLast();
    for (final d in DIRS) {
      final y = x + d;
      if (floors.contains(y) && seen.add(y)) stack.add(y);
    }
  }
  return seen.length;
}

void main() {
  // ------------------------------------------------------------- geometry
  group('cell encoding', () {
    test('round-trips (row, col) through cellId/rowOf/colOf', () {
      for (final r in const [0, 1, 7, 13, 42]) {
        for (final c in const [0, 1, 5, 13, 99]) {
          final id = cellId(r, c);
          expect(rowOf(id), r);
          expect(colOf(id), c);
        }
      }
    });

    test('direction deltas move exactly one cell', () {
      final p = cellId(4, 4);
      expect(rowOf(p + UP), 3);
      expect(colOf(p + UP), 4);
      expect(rowOf(p + DOWN), 5);
      expect(colOf(p + LEFT), 3);
      expect(colOf(p + RIGHT), 5);
    });
  });

  // ------------------------------------------------------------- templates
  group('templates', () {
    test('all are unique 3x3 wall/floor blocks', () {
      expect(TEMPLATES, isNotEmpty);
      final keys = <String>{};
      for (final t in TEMPLATES) {
        expect(t.length, 3);
        for (final row in t) {
          expect(row.length, 3);
          for (final ch in row.split('')) {
            expect(ch == '#' || ch == ' ', isTrue);
          }
        }
        expect(keys.add(t.join('|')), isTrue, reason: 'templates must be unique');
      }
    });
  });

  // ------------------------------------------------------- pure analysis
  group('pullMetric', () {
    test('assigns push-distance and marks dead end cells as INF', () {
      // Horizontal corridor of five cells, goal in the middle.
      final floors = {
        for (var c = 1; c <= 5; c++) cellId(1, c),
      };
      final goals = {cellId(1, 3)};
      final dist = pullMetric(floors, goals);

      expect(dist[cellId(1, 3)], 0);
      expect(dist[cellId(1, 2)], 1);
      expect(dist[cellId(1, 4)], 1);
      // The two extreme cells are dead: no room behind a box to push it off.
      expect(dist[cellId(1, 1)], INF);
      expect(dist[cellId(1, 5)], INF);
    });
  });

  group('reachable', () {
    test('a wall of boxes splits the floor into two regions', () {
      // 3x3 open room; a vertical line of boxes down the middle column.
      final floors = {
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) cellId(r, c),
      };
      final nbrs = makeNbrs(floors);
      final boxes = {cellId(0, 1), cellId(1, 1), cellId(2, 1)};

      final left = reachable(nbrs, boxes, cellId(1, 0));
      expect(left, {cellId(0, 0), cellId(1, 0), cellId(2, 0)});
      expect(left.contains(cellId(1, 2)), isFalse);

      final right = reachable(nbrs, boxes, cellId(1, 2));
      expect(right, {cellId(0, 2), cellId(1, 2), cellId(2, 2)});
    });
  });

  group('freeze2x2', () {
    test('flags an off-goal box wedged in a wall corner', () {
      // Top-left corner: only (1,1) and its right/down neighbours are floor,
      // so a box pushed to (1,1) is frozen against the two walls.
      final floors = {
        cellId(1, 1),
        cellId(1, 2),
        cellId(2, 1),
        cellId(2, 2),
      };
      final goals = <int>{cellId(2, 2)};
      final boxes = {cellId(1, 1)};
      expect(freeze2x2(floors, boxes, cellId(1, 1), goals), isTrue);
    });

    test('does not flag a box that is on a goal', () {
      final floors = {
        cellId(1, 1),
        cellId(1, 2),
        cellId(2, 1),
        cellId(2, 2),
      };
      final goals = {cellId(1, 1)}; // the corner IS the goal
      final boxes = {cellId(1, 1)};
      expect(freeze2x2(floors, boxes, cellId(1, 1), goals), isFalse);
    });
  });

  group('roomOk', () {
    test('rejects a disconnected floor', () {
      // Two separate 2x2 blocks with no connecting floor.
      final floors = {
        cellId(1, 1), cellId(1, 2), cellId(2, 1), cellId(2, 2), // block A
        cellId(1, 5), cellId(1, 6), cellId(2, 5), cellId(2, 6), // block B
      };
      // H,W large enough that the density check passes; connectivity fails.
      expect(roomOk(floors, 4, 8, 4), isFalse);
    });

    test('rejects a large fully-open area (3x4 block)', () {
      final floors = {
        for (var r = 1; r <= 3; r++)
          for (var c = 1; c <= 4; c++) cellId(r, c),
      };
      // Connected & dense, but the 3x4 open block must be rejected.
      expect(roomOk(floors, 5, 6, 4), isFalse);
    });
  });

  group('solutionMetrics', () {
    test('counts pushes, box changes and counter pushes', () {
      // dist: bigger index = closer to goal, so a move to a LOWER-dist cell is
      // a counter push. Two boxes at cells A and B.
      final a = cellId(1, 1), a2 = cellId(1, 2);
      final b = cellId(3, 1), b2 = cellId(3, 2);
      final dist = {a: 5, a2: 4, b: 5, b2: 6};
      // Push A (5->4, forward), switch to B (5->6, counter), that's 1 change.
      final actions = [
        [a, a2],
        [b, b2],
      ];
      final m = solutionMetrics(dist, actions, 3);
      expect(m.pushes, 2);
      expect(m.changes, 1); // one switch between different boxes
      expect(m.counter, 1); // the B push increases distance-to-goal
    });
  });

  // ------------------------------------------------- end-to-end generation
  group('generate — invariants over many seeds', () {
    // Keep to low difficulties + a short budget so the suite stays fast.
    for (final difficulty in const [1, 2, 3, 4]) {
      test('difficulty $difficulty levels are structurally valid & solvable',
          () {
        for (final seed in const [1, 2, 3, 7, 42]) {
          final lv = generate(difficulty, seed: seed, timeBudget: 8);
          final where = 'd=$difficulty seed=$seed';
          final P = PARAMS[difficulty]!;

          // --- solvable, by BOTH the library and the independent oracle ---
          expect(lv.verify(), isTrue, reason: '$where: Level.verify()');
          expect(replaySolves(lv), isTrue,
              reason: '$where: independent replay oracle');

          // --- piece counts ---
          expect(lv.boxes.length, P.boxes, reason: '$where: box count');
          expect(lv.goals.length, P.boxes, reason: '$where: goal count');

          // --- every box / goal / player sits on a floor cell ---
          expect(lv.floors.containsAll(lv.boxes), isTrue,
              reason: '$where: boxes on floor');
          expect(lv.floors.containsAll(lv.goals), isTrue,
              reason: '$where: goals on floor');
          expect(lv.floors.contains(lv.player), isTrue,
              reason: '$where: player on floor');

          // --- floor is a single connected component ---
          expect(connectedCount(lv.floors, lv.player), lv.floors.length,
              reason: '$where: floor connectivity');

          // --- solution shape: only LURD chars; uppercase == push count ---
          expect(RegExp(r'^[lrudLRUD]*$').hasMatch(lv.solution), isTrue,
              reason: '$where: solution alphabet');
          final pushChars =
              lv.solution.split('').where((c) => c == c.toUpperCase()).length;
          expect(pushChars, lv.stats['pushes'],
              reason: '$where: one uppercase per push');
          expect(lv.stats['moves'], lv.solution.length,
              reason: '$where: moves == solution length');

          // --- when the difficulty band was hit, the band actually holds ---
          if (lv.stats['meets_target'] == true) {
            expect(lv.stats['pushes'], greaterThanOrEqualTo(P.minPushes),
                reason: '$where: min pushes');
            expect(lv.stats['box_changes'],
                greaterThanOrEqualTo(P.minChanges),
                reason: '$where: min changes');
            expect((lv.stats['score'] as double),
                greaterThanOrEqualTo(P.scoreLo.toDouble()),
                reason: '$where: score floor');
            if (P.pushHi != null) {
              expect(lv.stats['pushes'], lessThanOrEqualTo(P.pushHi!),
                  reason: '$where: push ceiling');
            }
          }
        }
      });
    }
  });

  group('generate — determinism', () {
    test('same (difficulty, seed) reproduces the identical level', () {
      final a = generate(3, seed: 12345, timeBudget: 8);
      final b = generate(3, seed: 12345, timeBudget: 8);
      expect(a.ascii(), b.ascii());
      expect(a.solution, b.solution);
      expect(a.stats['pushes'], b.stats['pushes']);
      expect(a.stats['score'], b.stats['score']);
    });

    test('different seeds generally produce different levels', () {
      final a = generate(3, seed: 1, timeBudget: 8);
      final b = generate(3, seed: 2, timeBudget: 8);
      // Not a hard guarantee, but a collision here would be extraordinary.
      expect(a.ascii() == b.ascii() && a.solution == b.solution, isFalse);
    });
  });

  group('Level.ascii / clamps to difficulty range', () {
    test('renders exactly one player glyph and matching goal/box counts', () {
      final lv = generate(2, seed: 9, timeBudget: 8);
      final art = lv.ascii();
      final players = RegExp(r'[@+]').allMatches(art).length;
      expect(players, 1, reason: 'exactly one player glyph');
      // '.', '*'(box-on-goal), '+'(player-on-goal) all cover a goal cell.
      final goalGlyphs = RegExp(r'[.*+]').allMatches(art).length;
      expect(goalGlyphs, lv.goals.length);
    });

    test('difficulty is clamped into 1..10', () {
      final lo = generate(-5, seed: 3, timeBudget: 8);
      final hi = generate(99, seed: 3, timeBudget: 8);
      expect(lo.stats['difficulty'], 1);
      expect(hi.stats['difficulty'], 10);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
