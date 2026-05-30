// Unit tests for codebreaker_logic.dart.
//
// Tested as pure logic where feasible:
//   * PuzzleSolver.solve  — solvable vs unsolvable systems (deterministic,
//     hand-built equations; no randomness involved).
//   * AdvancedCodebreakerPuzzle.validateSolution — accepts the true solution,
//     rejects a wrong one (hand-built puzzle, no randomness involved).
//   * AdvancedPuzzleGenerator.generate() — async; the generator uses an
//     internal unseeded math.Random with NO injection seam, so we cannot pin
//     exact output. Instead we assert INVARIANTS over several generated
//     puzzles: every generated puzzle must validate against its own solution
//     key via PuzzleSolver, and every symbol in the key must be in-range.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/codebreaker_logic.dart';

DifficultyConfig _config({
  int grade = 1,
  int min = 1,
  int max = 20,
  List<MathOperation> ops = const [
    MathOperation.addition,
    MathOperation.subtraction,
  ],
}) {
  return DifficultyConfig(
    grade: grade,
    level: 1,
    difficultyMultiplier: 1.0,
    numberRange: {'min': min, 'max': max},
    operationTypes: ops,
    equationProbability: 1.0,
    objectCount: 1,
    timeLimit: 60,
    gameSpeed: 1.0,
    showHints: false,
    animationSpeed: 1.0,
    visualComplexity: 1.0,
  );
}

void main() {
  group('PuzzleSolver.solve', () {
    test('solves a fully determined linear system', () {
      // star = 3, moon = 5, sun = 8 with:
      //   star + moon = sun   (3 + 5 = 8)
      //   sun - star = moon   (8 - 3 = 5)  redundant but consistent
      // Anchor star to a literal so the chain is determined.
      final equations = <PuzzleEquation>[
        PuzzleEquation(term1: 1, op: '+', term2: 2, result: 'star'), // star = 3
        PuzzleEquation(term1: 'star', op: '+', term2: 2, result: 'moon'), // moon=5
        PuzzleEquation(
            term1: 'star', op: '+', term2: 'moon', result: 'sun'), // sun=8
      ];
      final solver = PuzzleSolver();
      final result = solver.solve(equations, ['star', 'moon', 'sun']);

      expect(result, isNotNull);
      expect(result!['star'], 3);
      expect(result['moon'], 5);
      expect(result['sun'], 8);
    });

    test('returns null when the system is underdetermined', () {
      // Two equations, three unknowns, no literal anchors -> cannot solve all.
      final equations = <PuzzleEquation>[
        PuzzleEquation(term1: 'a', op: '+', term2: 'b', result: 'c'),
        PuzzleEquation(term1: 'a', op: '-', term2: 'b', result: 'c'),
      ];
      final solver = PuzzleSolver();
      final result = solver.solve(equations, ['a', 'b', 'c']);

      expect(result, isNull);
    });

    test('handles same-symbol-on-both-sides addition (x + x = result)', () {
      // moon + moon = 10  => moon = 5
      final equations = <PuzzleEquation>[
        PuzzleEquation(term1: 'moon', op: '+', term2: 'moon', result: 10),
      ];
      final solver = PuzzleSolver();
      final result = solver.solve(equations, ['moon']);

      expect(result, isNotNull);
      expect(result!['moon'], 5);
    });
  });

  group('AdvancedCodebreakerPuzzle.validateSolution', () {
    // Build a deterministic puzzle by hand:
    //   eq0: star(3) + moon(5) = sun(8)
    // hidden positions: eq0_term1 (star), eq0_term2 (moon), eq0_result (sun)
    AdvancedCodebreakerPuzzle buildPuzzle() {
      final equations = <PuzzleEquation>[
        PuzzleEquation(
            term1: 'star', op: '+', term2: 'moon', result: 'sun'),
      ];
      return AdvancedCodebreakerPuzzle(
        knownSymbolValues: const {},
        equations: equations,
        hiddenSymbols: {'star', 'moon', 'sun'},
        numberPool: const [3, 5, 8, 1, 2, 4, 6, 7],
        hiddenPositions: const ['eq0_term1', 'eq0_term2', 'eq0_result'],
        fullSolution: const {'star': 3, 'moon': 5, 'sun': 8},
        visiblePositions: const {},
      );
    }

    test('accepts the true solution', () {
      final puzzle = buildPuzzle();
      final ok = puzzle.validateSolution({
        'eq0_term1': 3,
        'eq0_term2': 5,
        'eq0_result': 8,
      });
      expect(ok, isTrue);
    });

    test('rejects a wrong value', () {
      final puzzle = buildPuzzle();
      final ok = puzzle.validateSolution({
        'eq0_term1': 3,
        'eq0_term2': 5,
        'eq0_result': 9, // wrong: should be 8
      });
      expect(ok, isFalse);
    });

    test('rejects when a hidden position is left unfilled', () {
      final puzzle = buildPuzzle();
      final ok = puzzle.validateSolution({
        'eq0_term1': 3,
        'eq0_term2': 5,
        // eq0_result missing
      });
      expect(ok, isFalse);
    });
  });

  group('AdvancedPuzzleGenerator.generate (invariants)', () {
    test('generated puzzles validate against their own solution key', () async {
      // No seam to seed the generator's internal Random, so assert invariants
      // across several runs rather than exact output.
      for (int i = 0; i < 8; i++) {
        final generator = AdvancedPuzzleGenerator(
          difficulty: _config(grade: 1, min: 1, max: 20),
          useCSP: false,
        );

        final equations = await generator.generate();
        final symbols = generator.symbols;
        final key = generator.solution;

        expect(equations, isNotEmpty,
            reason: 'generate() must produce at least one equation');
        expect(symbols, isNotEmpty);

        // The generator's own solver must recover exactly the solution key.
        final solved = PuzzleSolver().solve(equations, symbols);
        expect(solved, isNotNull,
            reason: 'generated puzzle must be solvable');
        for (final symbol in symbols) {
          expect(solved![symbol], key[symbol],
              reason: 'solver value for $symbol must match generated key');
        }

        // All key values must lie within the configured numeric range.
        for (final v in key.values) {
          expect(v, inInclusiveRange(1, 20));
        }
      }
    });
  });
}
