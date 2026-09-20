// High-volume generation soak for the three games held back in
// `debugOnlyGames` as fixed-pending-play-through.
//
// Each was gated for a generation bug that only showed up on some seeds: a
// magic constant that no arrangement could reach, a chain whose legal moves
// could strand the player, a grid whose pieces could not be taken back. The
// existing per-game tests each run a few dozen iterations, which is enough to
// catch a broken generator and not enough to catch a rare one.
//
// So this sweeps the whole parameter space the app actually asks for, many
// times over, and asserts the invariant that matters for each: that what the
// generator hands the player can in fact be finished. It is deliberately
// separate from the per-game test files, which document behaviour; this one
// exists to buy confidence before the games come off the debug gate.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/services/ion_chain_logic.dart';
import 'package:space_math_academy/features/games/services/relic_assembly_logic.dart';

void main() {
  group('star_forge generates only solvable magic stars', () {
    test('every line sums to the magic constant, across all point counts', () async {
      final gen = StarForgeGenerator();
      var generated = 0;
      for (final points in [5, 6, 7]) {
        for (int clues = 3; clues <= points; clues++) {
          for (int i = 0; i < 40; i++) {
            final p = await gen.generate(points: points, clueCount: clues);
            generated++;

            // The constant is forced by the geometry: every node lies on
            // exactly two lines, so the line sums must total twice the sum of
            // 1..2n, over n lines. A generator that picks any other constant
            // is searching for something that cannot exist.
            final n = p.points;
            expect(p.magicConstant, 2 * (2 * n + 1),
                reason: '$points-point star got constant ${p.magicConstant}');

            for (final line in p.lines) {
              final sum = line.fold<int>(0, (a, node) => a + p.solution[node]!);
              expect(sum, p.magicConstant,
                  reason: '$points-point star, line $line sums to $sum');
            }

            // The solution must be a permutation of 1..2n — no repeats, no gaps.
            final values = p.solution.values.toList()..sort();
            expect(values, List.generate(2 * n, (i) => i + 1),
                reason: '$points-point star solution is not a permutation');

            // Every node on exactly two lines is what forces the constant
            // above; if that ever stops holding the constant is wrong too.
            for (int node = 0; node < p.nodeCount; node++) {
              final on = p.lines.where((l) => l.contains(node)).length;
              expect(on, 2, reason: 'node $node lies on $on lines, not 2');
            }

            // The puzzle the player sees must be the solution minus the clues.
            expect(p.emptyNodes.length, p.nodeCount - p.clues.length);
            for (final entry in p.clues.entries) {
              expect(p.solution[entry.key], entry.value,
                  reason: 'clue at ${entry.key} contradicts the solution');
            }

            // And the solution must pass the game's own checker.
            expect(p.validateSolution({
              for (final node in p.emptyNodes) node: p.solution[node]!,
            }), isTrue);
          }
        }
      }
      expect(generated, greaterThanOrEqualTo(3 * 40));
    });
  });

  group('ion_chain never hands the player an unfinishable chain', () {
    // The parameters the game actually asks for, mirroring the grade/level
    // mapping in ion_chain_game.dart. Sweeping arbitrary combinations instead
    // tests puzzles the app cannot produce -- and it was that mismatch, not a
    // real defect, that this test first reported.
    List<int> paramsFor(int grade, int level) {
      if (grade <= 1) return [5, 3, 1, 2];
      if (grade <= 2) return [6 + (level > 5 ? 1 : 0), 3, 1 + (level > 5 ? 1 : 0), 3];
      return [7 + (level > 5 ? 2 : 0), 4, 2 + (level > 8 ? 1 : 0), 3 + (level > 5 ? 1 : 0)];
    }

    test('the start state is completable at every grade and level', () {
      var generated = 0;
      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 10; level++) {
          final q = paramsFor(grade, level);
          for (int seed = 0; seed < 50; seed++) {
            final p = IonChainPuzzle.generate(
              chainLength: q[0], ionTypeCount: q[1],
              ruleCount: q[2], blanksToRemove: q[3], seed: seed,
            );
            generated++;
            final where = 'grade=$grade level=$level seed=$seed';

            // The whole point of the fix: from the state the player is given,
            // some sequence of tray placements must finish it.
            expect(
              IonChainPuzzle.isCompletable(p.chain, p.availableIons, p.rules),
              isTrue,
              reason: 'unfinishable from the start -- $where',
            );

            // A solution that breaks its own rules is the shipped-unsolvable
            // case: no placement the player makes can ever be accepted.
            expect(IonChainPuzzle.validateChain(p.solution, p.rules), isTrue,
                reason: "the generator's own solution fails its rules -- $where");

            // The same rule listed twice reads as two constraints.
            final shown =
                p.rules.map((r) => '${r.kind}:${r.a}:${r.b}').toList();
            expect(shown.toSet().length, shown.length,
                reason: 'duplicate rule shown to the player -- $where');

            // Prefilled slots must agree with the solution.
            for (int i = 0; i < p.chain.length; i++) {
              if (p.chain[i] != null) {
                expect(p.chain[i], p.solution[i],
                    reason: 'prefilled slot $i contradicts the solution -- $where');
              }
            }
          }
        }
      }
      expect(generated, greaterThanOrEqualTo(2000));
    });

    test('a rule set the ion types cannot satisfy is weakened, not shipped broken', () {
      // Two ion types cannot satisfy "no two the same adjacent" AND "A must
      // not neighbor B" at once: the first forces A,B,A,B..., the second
      // forbids it. The generator used to fall through to that alternation
      // with both rules still attached. No difficulty asks for two types
      // today, so this guards a setting someone could reasonably turn to.
      for (int length = 5; length <= 9; length++) {
        for (int rules = 1; rules <= 3; rules++) {
          for (int seed = 0; seed < 20; seed++) {
            final p = IonChainPuzzle.generate(
              chainLength: length, ionTypeCount: 2,
              ruleCount: rules, blanksToRemove: 2, seed: seed,
            );
            final where = 'len=$length rules=$rules seed=$seed';
            expect(IonChainPuzzle.validateChain(p.solution, p.rules), isTrue,
                reason: 'solution violates its own rules -- $where');
            expect(
              IonChainPuzzle.isCompletable(p.chain, p.availableIons, p.rules),
              isTrue,
              reason: 'unfinishable with two ion types -- $where',
            );
          }
        }
      }
    });

    test('generation is deterministic for a given seed', () {
      // Without this, a soak failure cannot be reproduced from its seed.
      for (int seed = 0; seed < 20; seed++) {
        final a = IonChainPuzzle.generate(
            chainLength: 7, ionTypeCount: 3, ruleCount: 2,
            blanksToRemove: 3, seed: seed);
        final b = IonChainPuzzle.generate(
            chainLength: 7, ionTypeCount: 3, ruleCount: 2,
            blanksToRemove: 3, seed: seed);
        expect(a.solution, b.solution, reason: 'seed $seed is not reproducible');
        expect(a.chain, b.chain, reason: 'seed $seed is not reproducible');
      }
    });
  });

  group('relic_assembly generates grids whose pieces actually fit', () {
    test('the intended placement validates, across all grid sizes', () async {
      final gen = RelicAssemblyGenerator();
      var generated = 0;
      for (final rows in [2, 3]) {
        for (int cols = 2; cols <= 4; cols++) {
          for (int values = 2; values <= 4; values++) {
            for (int i = 0; i < 25; i++) {
              final p = await gen.generate(
                  rows: rows, cols: cols, edgeValueCount: values);
              generated++;
              final where = '${rows}x$cols values=$values';

              expect(p.solutionTiles.length, rows * cols,
                  reason: 'wrong tile count — $where');
              expect(p.playerTiles.length, rows * cols,
                  reason: 'player tile count differs from the solution — $where');

              // The player's tiles are the solution's, shuffled and turned,
              // so the identity placement is NOT the answer -- assuming it was
              // is what this test got wrong first time round. Recover the
              // answer instead: for each grid position find an unused player
              // tile and a rotation that reproduces the solution tile's edges.
              // If that mapping exists for every position, the puzzle handed
              // to the player is solvable.
              final placement = List.filled(rows * cols, -1);
              final rotations = List.filled(rows * cols, 0);
              final used = List.filled(rows * cols, false);

              for (int pos = 0; pos < rows * cols; pos++) {
                final want = p.solutionTiles[pos].edges;
                var found = false;
                for (int j = 0; j < p.playerTiles.length && !found; j++) {
                  if (used[j]) continue;
                  for (int rot = 0; rot < 4 && !found; rot++) {
                    final cand = p.playerTiles[j].copyWith(rotation: rot);
                    if (List.generate(4, cand.getEdge).toString() == want.toString()) {
                      placement[pos] = j;
                      rotations[j] = rot;
                      used[j] = true;
                      found = true;
                    }
                  }
                }
                expect(found, isTrue,
                    reason: 'no player tile can be turned into solution tile '
                        '$pos -- a piece the puzzle needs is missing -- $where');
              }

              expect(p.validatePlacement(placement, rotations), isTrue,
                  reason: 'the recovered solution does not validate -- $where');
            }
          }
        }
      }
      expect(generated, greaterThan(100));
    });
  });
}
