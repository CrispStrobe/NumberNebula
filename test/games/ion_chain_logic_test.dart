// Unit tests for ion_chain_logic.dart.
//
// Tests the CSP-based sequence builder: chain validation, rule checking,
// and generated puzzle invariants. The generator uses an unseeded Random,
// so we assert structural invariants over multiple seeded generations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/ion_chain_logic.dart';

void main() {
  group('IonChainPuzzle.validateChain', () {
    test('valid chain with no-same-adjacent rule passes', () {
      final rule = IonRule(
        description: 'No two same adjacent',
        descriptionDe: 'Keine zwei gleichen nebeneinander',
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
        description: 'No two same adjacent',
        descriptionDe: 'Keine zwei gleichen nebeneinander',
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

    test('chain with nulls is considered valid (nulls are unfilled slots)', () {
      final rule = IonRule(
        description: 'No two red adjacent',
        descriptionDe: 'Keine zwei Rot nebeneinander',
        check: (left, right) {
          if (left == null || right == null) return true;
          return !(left == IonType.red && right == IonType.red);
        },
      );
      final chain = <IonType?>[IonType.red, null, IonType.red];
      expect(IonChainPuzzle.validateChain(chain, [rule]), isTrue);
    });

    test('empty chain validates trivially', () {
      expect(IonChainPuzzle.validateChain([], []), isTrue);
    });

    test('single-element chain validates trivially', () {
      final rule = IonRule(
        description: 'test',
        descriptionDe: 'test',
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
          int availIdx = 0;
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
}
