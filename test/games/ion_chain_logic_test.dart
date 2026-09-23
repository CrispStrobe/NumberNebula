// Unit tests for ion_chain_logic.dart.
//
// Tests the CSP-based sequence builder: chain validation, rule checking,
// and generated puzzle invariants. The generator uses an unseeded Random,
// so we assert structural invariants over multiple seeded generations.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/ion_chain_logic.dart';

void main() {
  group('IonChainPuzzle.isCompletable', () {
    // Mirrors the screen's placement check: a bead may only go down if it
    // breaks no rule AND leaves the ring finishable.
    bool uiAccepts(List<IonType?> chain, int slot, IonType bead,
        List<IonRule> rules, List<IonType> trayAfter) {
      final test = List<IonType?>.from(chain)..[slot] = bead;
      final prev = (slot - 1 + test.length) % test.length;
      final next = (slot + 1) % test.length;
      for (final r in rules) {
        if (test[prev] != null && !r.check(test[prev], bead)) return false;
        if (test[next] != null && !r.check(bead, test[next])) return false;
      }
      return IonChainPuzzle.isCompletable(test, trayAfter, rules);
    }

    /// The difficulty parameters ion_chain_game.dart derives from grade/level.
    List<int> params(int grade, int level) {
      if (grade <= 1) return [5, 3, 1, 2];
      if (grade <= 2) {
        return [6 + (level > 5 ? 1 : 0), 3, 1 + (level > 5 ? 1 : 0), 3];
      }
      return [
        7 + (level > 5 ? 2 : 0),
        4,
        2 + (level > 8 ? 1 : 0),
        3 + (level > 5 ? 1 : 0)
      ];
    }

    test('a full, rule-abiding ring is completable', () {
      final puzzle = IonChainPuzzle.generate(
        chainLength: 6, ionTypeCount: 3, ruleCount: 1,
        blanksToRemove: 3, seed: 7);

      final blanks = [
        for (int i = 0; i < puzzle.chainLength; i++)
          if (puzzle.chain[i] == null) i
      ];
      expect(
          IonChainPuzzle.isCompletable(
              puzzle.chain, puzzle.availableIons, puzzle.rules),
          isTrue);
      expect(blanks.length, puzzle.availableIons.length);
    });

    test('a ring whose blanks cannot be filled is rejected', () {
      final rules = [
        IonRule(
          kind: IonRuleKind.noRepeatAtAll,
          check: (l, r) => l == null || r == null || l != r,
        ),
      ];
      // Only a red is left, and both neighbours of the gap are red.
      final chain = <IonType?>[IonType.red, null, IonType.red, IonType.blue];
      expect(IonChainPuzzle.isCompletable(chain, [IonType.red], rules), isFalse);
      expect(IonChainPuzzle.isCompletable(chain, [IonType.green], rules), isTrue);
    });

    test('tray size must match the number of blanks', () {
      final rules = <IonRule>[];
      final chain = <IonType?>[IonType.red, null, IonType.blue];
      expect(IonChainPuzzle.isCompletable(chain, const [], rules), isFalse);
      expect(
          IonChainPuzzle.isCompletable(
              chain, const [IonType.red, IonType.blue], rules),
          isFalse);
    });

    test('no sequence of accepted moves can strand the player', () {
      // The bug this guards: before dead-end detection, ~45% of puzzles could
      // be played into a state where no remaining bead fitted any open slot.
      // The ring then never filled, so the win never fired and the game
      // silently became unwinnable.
      final rng = math.Random(3);

      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 10; level += 3) {
          final p = params(grade, level);
          for (int i = 0; i < 6; i++) {
            final puzzle = IonChainPuzzle.generate(
              chainLength: p[0], ionTypeCount: p[1],
              ruleCount: p[2], blanksToRemove: p[3]);

            final blanks = [
              for (int j = 0; j < puzzle.chainLength; j++)
                if (puzzle.chain[j] == null) j
            ];

            for (int trial = 0; trial < 10; trial++) {
              final chain = List<IonType?>.from(puzzle.chain);
              final tray = List<IonType>.from(puzzle.availableIons)..shuffle(rng);
              final open = List<int>.from(blanks)..shuffle(rng);

              while (open.isNotEmpty) {
                final slot = open.removeAt(0);
                final options = <int>[];
                for (int k = 0; k < tray.length; k++) {
                  final after = List<IonType>.from(tray)..removeAt(k);
                  if (uiAccepts(chain, slot, tray[k], puzzle.rules, after)) {
                    options.add(k);
                  }
                }
                expect(options, isNotEmpty,
                    reason: 'grade $grade level $level: no bead fits slot $slot, '
                        'the player is stranded with the ring unfinished');
                chain[slot] = tray.removeAt(options[rng.nextInt(options.length)]);
              }

              expect(IonChainPuzzle.validateChain(chain, puzzle.rules), isTrue,
                  reason: 'a ring completed through accepted moves must win');
            }
          }
        }
      }
    });

    test('the intended solution is always accepted move by move', () {
      for (int grade = 1; grade <= 4; grade++) {
        final p = params(grade, 6);
        for (int i = 0; i < 10; i++) {
          final puzzle = IonChainPuzzle.generate(
            chainLength: p[0], ionTypeCount: p[1],
            ruleCount: p[2], blanksToRemove: p[3]);

          final chain = List<IonType?>.from(puzzle.chain);
          var tray = List<IonType>.from(puzzle.availableIons);

          for (int j = 0; j < puzzle.chainLength; j++) {
            if (puzzle.chain[j] != null) continue;
            final bead = puzzle.solution[j];
            final after = List<IonType>.from(tray)..remove(bead);
            expect(uiAccepts(chain, j, bead, puzzle.rules, after), isTrue,
                reason: 'the generator\'s own solution must be playable');
            chain[j] = bead;
            tray = after;
          }
        }
      }
    });
  });

  group('IonChainPuzzle.generate rules', () {
    test('never shows the same rule to the player twice', () {
      // "No two Xs adjacent" ignores its second ion, so the de-duplication key
      // must not include it -- otherwise the rule is generated, and listed,
      // several times over.
      for (int i = 0; i < 200; i++) {
        final puzzle = IonChainPuzzle.generate(
          chainLength: 8, ionTypeCount: 4, ruleCount: 3, blanksToRemove: 4);

        // A rule is identified by what it forbids, not by its wording -- the
        // wording now lives in the screen so that it can be localized, and a
        // rule shown twice would be a duplicate in either language.
        final shown = puzzle.rules
            .map((r) => '${r.kind}:${r.a}:${r.b}')
            .toList();
        expect(shown.toSet().length, shown.length,
            reason: 'duplicate rule shown: $shown');
      }
    });
  });

  group('IonChainPuzzle.validateChain', () {
    test('valid chain with no-same-adjacent rule passes', () {
      final rule = IonRule(
        kind: IonRuleKind.noRepeatAtAll,
        check: (left, right) {
          if (left == null || right == null) return true;
          return left != right;
        },
      );
      final chain = [IonType.red, IonType.blue, IonType.red, IonType.green];
      expect(
        IonChainPuzzle.validateChain(
            chain.map<IonType?>((e) => e).toList(), [rule]),
        isTrue,
      );
    });

    test('invalid chain with same-adjacent violates rule', () {
      final rule = IonRule(
        kind: IonRuleKind.noRepeatAtAll,
        check: (left, right) {
          if (left == null || right == null) return true;
          return left != right;
        },
      );
      final chain = [IonType.red, IonType.red, IonType.blue];
      expect(
        IonChainPuzzle.validateChain(
            chain.map<IonType?>((e) => e).toList(), [rule]),
        isFalse,
      );
    });

    test('chain with nulls skips null-adjacent checks', () {
      final rule = IonRule(
        kind: IonRuleKind.noSelfPair,
        a: IonType.red,
        check: (left, right) {
          if (left == null || right == null) return true;
          return !(left == IonType.red && right == IonType.red);
        },
      );
      // In a circular chain, red-null-blue: red is not adjacent to blue,
      // and nulls are skipped → should pass
      final chain = <IonType?>[IonType.red, null, IonType.blue];
      expect(IonChainPuzzle.validateChain(chain, [rule]), isTrue);
    });

    test('empty chain validates trivially', () {
      expect(IonChainPuzzle.validateChain([], []), isTrue);
    });

    test('single-element chain validates trivially', () {
      final rule = IonRule(
        kind: IonRuleKind.noRepeatAtAll,
        check: (left, right) => left != right,
      );
      expect(
        IonChainPuzzle.validateChain([IonType.red], [rule]),
        isTrue,
      );
    });
  });

  group('IonChainPuzzle.generate (invariants)', () {
    final testCases = <Map<String, int>>[
      // grade 1-like: short chain, few types, few rules
      {'chainLength': 5, 'ionTypeCount': 2, 'ruleCount': 1, 'blanks': 2},
      // grade 4-like: longer chain, more types, more rules
      {'chainLength': 8, 'ionTypeCount': 4, 'ruleCount': 2, 'blanks': 4},
    ];

    for (final tc in testCases) {
      final chainLength = tc['chainLength']!;
      final ionTypeCount = tc['ionTypeCount']!;
      final ruleCount = tc['ruleCount']!;
      final blanks = tc['blanks']!;

      test('length=$chainLength types=$ionTypeCount: solution satisfies all rules',
          () {
        for (int seed = 0; seed < 5; seed++) {
          final puzzle = IonChainPuzzle.generate(
            chainLength: chainLength,
            ionTypeCount: ionTypeCount,
            ruleCount: ruleCount,
            blanksToRemove: blanks,
            seed: seed,
          );

          // Solution must have correct length
          expect(puzzle.solution.length, chainLength);

          // Solution must satisfy all rules
          final solutionNullable =
              puzzle.solution.map<IonType?>((e) => e).toList();
          expect(
            IonChainPuzzle.validateChain(solutionNullable, puzzle.rules),
            isTrue,
            reason: 'solution must satisfy all rules (seed=$seed)',
          );
        }
      });

      test('length=$chainLength types=$ionTypeCount: chain has correct blanks',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = IonChainPuzzle.generate(
            chainLength: chainLength,
            ionTypeCount: ionTypeCount,
            ruleCount: ruleCount,
            blanksToRemove: blanks,
            seed: seed,
          );

          expect(puzzle.chain.length, chainLength);
          final nullCount = puzzle.chain.where((e) => e == null).length;
          expect(nullCount, blanks,
              reason: 'should have exactly $blanks blank slots');
        }
      });

      test('length=$chainLength types=$ionTypeCount: available ions match removed ions',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = IonChainPuzzle.generate(
            chainLength: chainLength,
            ionTypeCount: ionTypeCount,
            ruleCount: ruleCount,
            blanksToRemove: blanks,
            seed: seed,
          );

          // Available ions count must equal blank count
          expect(puzzle.availableIons.length, blanks);

          // Filling blanks with the correct solution values should produce the solution
          final filled = List<IonType?>.from(puzzle.chain);
          for (int i = 0; i < chainLength; i++) {
            if (filled[i] == null) {
              filled[i] = puzzle.solution[i];
            }
          }
          for (int i = 0; i < chainLength; i++) {
            expect(filled[i], puzzle.solution[i]);
          }
        }
      });

      test('length=$chainLength types=$ionTypeCount: ion types are within specified count',
          () {
        final puzzle = IonChainPuzzle.generate(
          chainLength: chainLength,
          ionTypeCount: ionTypeCount,
          ruleCount: ruleCount,
          blanksToRemove: blanks,
          seed: 42,
        );
        expect(puzzle.ionTypes.length, ionTypeCount);
        for (final ion in puzzle.solution) {
          expect(puzzle.ionTypes.contains(ion), isTrue,
              reason: '$ion should be in the allowed ion types');
        }
      });
    }

    test('rules list has expected count', () {
      final puzzle = IonChainPuzzle.generate(
        chainLength: 6,
        ionTypeCount: 3,
        ruleCount: 2,
        blanksToRemove: 3,
        seed: 42,
      );
      expect(puzzle.rules.length, greaterThanOrEqualTo(1));
    });

    test('pre-filled cells in chain match solution', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = IonChainPuzzle.generate(
          chainLength: 6,
          ionTypeCount: 3,
          ruleCount: 1,
          blanksToRemove: 3,
          seed: seed,
        );
        for (int i = 0; i < puzzle.chainLength; i++) {
          if (puzzle.chain[i] != null) {
            expect(puzzle.chain[i], puzzle.solution[i],
                reason: 'pre-filled cell at $i must match solution');
          }
        }
      }
    });
  });

  group('generated rules always bind', () {
    // The level bands ion_chain_game.dart asks for. A play-through of grade 1
    // got "Circle may not be next to Star" on a ring with no star: any
    // placement won, so there was nothing to work out.
    const bands = <(int, int, int, int)>[
      (5, 3, 1, 2), // grade 1
      (6, 3, 1, 3), // grade 2, levels 1-5
      (7, 3, 2, 3), // grade 2, levels 6+
      (7, 4, 2, 3), // grade 3+, levels 1-5
      (9, 4, 2, 4), // grade 3+, levels 6-8
      (9, 4, 3, 4), // grade 3+, levels 9+
    ];

    for (final (length, types, ruleCount, blanks) in bands) {
      test('length $length, $types types, $ruleCount rules, $blanks blanks', () {
        for (var seed = 0; seed < 200; seed++) {
          final p = IonChainPuzzle.generate(
            chainLength: length,
            ionTypeCount: types,
            ruleCount: ruleCount,
            blanksToRemove: blanks,
            seed: seed,
          );
          final named = {
            for (final r in p.rules) ...[if (r.a != null) r.a!, if (r.b != null) r.b!],
          };
          expect(p.solution.toSet().containsAll(named), isTrue,
              reason: 'seed $seed: a rule names a shape that is not on the ring');
          expect(
              IonChainPuzzle.rulesMatter(
                  p.chain, p.solution, p.availableIons, p.rules),
              isTrue,
              reason: 'seed $seed: every way of filling the blanks is legal');
        }
      });
    }

    test('rulesMatter spots a rule about an absent shape', () {
      final rule = IonRule(
        kind: IonRuleKind.noMixedPair,
        a: IonType.red,
        b: IonType.yellow,
        check: (x, y) => !((x == IonType.red && y == IonType.yellow) ||
            (x == IonType.yellow && y == IonType.red)),
      );
      const solution = [IonType.red, IonType.blue, IonType.green, IonType.blue];
      expect(
          IonChainPuzzle.rulesMatter(
              [IonType.red, null, IonType.green, null],
              solution,
              [IonType.blue, IonType.blue],
              [rule]),
          isFalse);
    });
  });
}
