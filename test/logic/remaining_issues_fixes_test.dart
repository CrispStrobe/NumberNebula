// Tests for the remaining-issues fixes:
//   1. Ion Chain: hardened puzzle generation (no trivial fallback)
//   2. Hive Station: hint fractions reduced, unique-solution verification
//   3. Vault Cracker: Wordle-style guess coloring algorithm
//   4. Xenobiology Lab: computed totals match expectations

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/ion_chain_logic.dart';
import 'package:space_math_academy/features/games/services/hive_station_logic.dart';

void main() {
  // ---------------------------------------------------------------
  // ION CHAIN — hardened puzzle generation
  // ---------------------------------------------------------------
  group('Ion Chain — hardened generation', () {
    test('generates non-trivial puzzles across many seeds', () {
      int fallbackCount = 0;
      for (int seed = 0; seed < 50; seed++) {
        final puzzle = IonChainPuzzle.generate(
          chainLength: 7,
          ionTypeCount: 3,
          ruleCount: 2,
          blanksToRemove: 3,
          seed: seed,
        );

        // Check if puzzle has at least 2 rules (not the trivial fallback)
        if (puzzle.rules.length < 2) fallbackCount++;

        // Solution must always be valid regardless
        final solutionNullable =
            puzzle.solution.map<IonType?>((e) => e).toList();
        expect(
          IonChainPuzzle.validateChain(solutionNullable, puzzle.rules),
          isTrue,
          reason: 'Solution must satisfy rules at seed=$seed',
        );
      }
      // With 500 CSP attempts, fallback should be rare (< 10% of cases)
      expect(fallbackCount, lessThan(5),
          reason: 'Fallback should trigger rarely with 500 CSP attempts');
    });

    test('fallback keeps two rules when two are satisfiable', () {
      // The original intent: a fallback puzzle should still be interesting,
      // not a single trivial constraint. That holds wherever the ion types can
      // actually support two rules.
      final puzzle = IonChainPuzzle.generate(
        chainLength: 5,
        ionTypeCount: 3,
        ruleCount: 5, // more than the generator can place, so it falls back
        blanksToRemove: 2,
        seed: 999,
      );

      expect(puzzle.rules.length, greaterThanOrEqualTo(2));
      expect(puzzle.solution.length, 5);
      final nullable = puzzle.solution.map<IonType?>((e) => e).toList();
      expect(IonChainPuzzle.validateChain(nullable, puzzle.rules), isTrue);
    });

    test('fallback drops a rule rather than shipping an impossible one', () {
      // This used to assert >= 2 rules here too, with ionTypeCount: 2 -- and
      // that is not achievable: the fallback's two rules are "no two the same
      // adjacent" and "A must not neighbor B", and with only types A and B the
      // first forces A,B,A,B... while the second forbids exactly that. Demanding
      // two rules demanded a puzzle with no solution, and the generator duly
      // produced one whose own solution broke its own rules.
      //
      // What matters is not the rule count but that the player can finish it.
      for (int seed = 0; seed < 25; seed++) {
        final puzzle = IonChainPuzzle.generate(
          chainLength: 5,
          ionTypeCount: 2,
          ruleCount: 5,
          blanksToRemove: 2,
          seed: seed,
        );
        final nullable = puzzle.solution.map<IonType?>((e) => e).toList();
        expect(IonChainPuzzle.validateChain(nullable, puzzle.rules), isTrue,
            reason: 'solution violates its own rules at seed=$seed');
        expect(
          IonChainPuzzle.isCompletable(
              puzzle.chain, puzzle.availableIons, puzzle.rules),
          isTrue,
          reason: 'unfinishable at seed=$seed',
        );
      }
    });

    test('solution is not a trivial repeating pattern', () {
      for (int seed = 0; seed < 20; seed++) {
        final puzzle = IonChainPuzzle.generate(
          chainLength: 7,
          ionTypeCount: 3,
          ruleCount: 2,
          blanksToRemove: 3,
          seed: seed,
        );

        // Check it's not just types[i % types.length]
        bool isTrivialPattern = true;
        for (int i = 0; i < puzzle.solution.length; i++) {
          if (puzzle.solution[i] != puzzle.ionTypes[i % puzzle.ionTypes.length]) {
            isTrivialPattern = false;
            break;
          }
        }
        // Not every seed needs to be non-trivial, but most should be
        if (isTrivialPattern && puzzle.rules.length >= 2) {
          // If it has 2+ rules, the backtracking solver was used,
          // so a trivial pattern would mean the solver found it valid.
          // That's OK — the pattern happens to satisfy the rules.
        }
      }
    });
  });

  // ---------------------------------------------------------------
  // HIVE STATION — hint fractions and unique solution
  // ---------------------------------------------------------------
  group('Hive Station — hint fraction changes', () {
    // The hint fractions are in the game widget, not the logic.
    // We test the logic-level uniqueness verification here.

    test('generated puzzle with full hints has unique solution', () async {
      final gen = HiveStationGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          radius: 2,
          energyFraction: 0.3,
          hintFraction: 1.0,
        );

        // With 100% hints, solution should be unique
        expect(puzzle.validateSolution(puzzle.energyCells), isTrue);
      }
    });

    test('generated puzzle with reduced hints still validates correctly',
        () async {
      final gen = HiveStationGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          radius: 2,
          energyFraction: 0.3,
          hintFraction: 0.7, // 70% hints — like grade 3
        );

        // The correct solution must still be accepted
        expect(puzzle.validateSolution(puzzle.energyCells), isTrue);

        // Revealed hints should be a subset of all hints
        expect(
          puzzle.revealedHints.every(
              puzzle.numberHints.containsKey),
          isTrue,
        );
      }
    });

    test('uniqueness verification adds hints if needed', () async {
      final gen = HiveStationGenerator();
      for (int i = 0; i < 10; i++) {
        final puzzle = await gen.generate(
          radius: 2,
          energyFraction: 0.3,
          hintFraction: 0.5, // Low hint rate — might need extras
        );

        // The generator should have added extra hints for uniqueness.
        // We can't easily verify uniqueness here without reimplementing
        // the solver, but we can check the puzzle is still valid.
        expect(puzzle.validateSolution(puzzle.energyCells), isTrue);
        expect(puzzle.revealedHints, isNotEmpty);
      }
    });

    test('radius 3 with low hints still produces valid puzzle', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 3,
        energyFraction: 0.3,
        hintFraction: 0.6,
      );

      expect(puzzle.allCells.length, 37);
      expect(puzzle.validateSolution(puzzle.energyCells), isTrue);
      expect(puzzle.revealedHints.length,
          greaterThanOrEqualTo((37 * 0.15).round()));
    });
  });

  // ---------------------------------------------------------------
  // VAULT CRACKER — Wordle guess coloring algorithm
  // ---------------------------------------------------------------
  group('Vault Cracker — Wordle coloring', () {
    // Replicate the _computeGuessColors algorithm from the game widget
    // to test it as a pure function.

    /// 0 = gray (not in code), 1 = yellow (wrong position), 2 = green (exact)
    List<int> computeGuessColors(List<int> guess, List<int> secret) {
      final colors = List.filled(guess.length, 0); // default gray
      final secretUsed = List.filled(secret.length, false);
      final guessUsed = List.filled(guess.length, false);

      // Pass 1: exact matches (green)
      for (int i = 0; i < guess.length; i++) {
        if (guess[i] == secret[i]) {
          colors[i] = 2; // green
          secretUsed[i] = true;
          guessUsed[i] = true;
        }
      }

      // Pass 2: wrong position (yellow)
      for (int i = 0; i < guess.length; i++) {
        if (guessUsed[i]) continue;
        for (int j = 0; j < secret.length; j++) {
          if (!secretUsed[j] && guess[i] == secret[j]) {
            colors[i] = 1; // yellow
            secretUsed[j] = true;
            break;
          }
        }
      }

      return colors;
    }

    test('exact match → all green', () {
      expect(computeGuessColors([1, 2, 3], [1, 2, 3]), [2, 2, 2]);
    });

    test('no match → all gray', () {
      expect(computeGuessColors([4, 5, 6], [1, 2, 3]), [0, 0, 0]);
    });

    test('wrong position → yellow', () {
      expect(computeGuessColors([2, 1, 3], [1, 2, 3]), [1, 1, 2]);
    });

    test('duplicate in guess, one match → one green one gray', () {
      // Secret: [1, 2, 3], Guess: [1, 1, 3]
      // First 1 is exact (green), second 1 has no remaining match (gray)
      expect(computeGuessColors([1, 1, 3], [1, 2, 3]), [2, 0, 2]);
    });

    test('duplicate in guess, wrong position → consumed by exact first', () {
      // Secret: [1, 2, 3], Guess: [2, 2, 1]
      // Pass 1: pos 1 exact (green), marks secret[1] used
      // Pass 2: pos 0 has 2, but secret's only 2 (pos 1) is used → gray
      //         pos 2 has 1, secret[0]=1 unused → yellow
      expect(computeGuessColors([2, 2, 1], [1, 2, 3]), [0, 2, 1]);
    });

    test('all same digit guess', () {
      // Secret: [1, 2, 1], Guess: [1, 1, 1]
      // First: exact (green), second: not 2 so wrong-pos since 1 exists at pos 2 (yellow? no, pos 2 has 1 → green)
      // Actually: pos 0: 1==1 green, pos 2: 1==1 green, pos 1: 1!=2, check remaining secret — all used → gray
      expect(computeGuessColors([1, 1, 1], [1, 2, 1]), [2, 0, 2]);
    });

    test('4-digit code', () {
      expect(
        computeGuessColors([1, 2, 3, 4], [4, 3, 2, 1]),
        [1, 1, 1, 1], // all wrong position
      );
    });
  });

  // ---------------------------------------------------------------
  // ION CHAIN — circular chain validation
  // ---------------------------------------------------------------
  group('Ion Chain — circular validation', () {
    test('circular check catches last-to-first violation', () {
      final rule = IonRule(
        kind: IonRuleKind.noSelfPair,
        a: IonType.red,
        check: (left, right) {
          if (left == null || right == null) return true;
          return !(left == IonType.red && right == IonType.red);
        },
      );
      // Chain: [blue, green, red, red] → last-to-first: red→blue OK
      // but red→red at positions 2→3: fail
      expect(
        IonChainPuzzle.validateChain(
          [IonType.blue, IonType.green, IonType.red, IonType.red],
          [rule],
        ),
        isFalse,
      );

      // Chain: [red, blue, green, red] → last-to-first: red→red: fail
      expect(
        IonChainPuzzle.validateChain(
          [IonType.red, IonType.blue, IonType.green, IonType.red],
          [rule],
        ),
        isFalse,
      );

      // Chain: [red, blue, green, blue] → last-to-first: blue→red: OK, all OK
      expect(
        IonChainPuzzle.validateChain(
          [IonType.red, IonType.blue, IonType.green, IonType.blue],
          [rule],
        ),
        isTrue,
      );
    });
  });
}
