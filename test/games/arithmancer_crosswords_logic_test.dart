// Unit tests for arithmancer_crosswords_logic.dart
//
// Deterministic coverage:
//   * CrosswordConfig.createConfig difficulty scaling stays within the
//     documented constant bounds for any grade/level.
//   * generateCrosswordPuzzle produces a puzzle whose every equation actually
//     satisfies its operator under the returned full solution, and whose
//     solution is accepted by validateSolution.
//   * CrosswordPuzzle.validateSolution accepts a correct solution, rejects a
//     corrupted one, and treats both ASCII '-' and unicode '−' (and '*'/'×',
//     '/'/'÷') as the same operator.
//
// Note on determinism: the generator's internal helpers (GridPatternGenerator,
// PuzzleParser, _generateNumberPool) construct their own unseeded math.Random()
// instances which are not injectable without editing lib/. We therefore do NOT
// assert exact puzzle layouts; we only assert invariants that must hold for
// ANY successfully generated puzzle, and we build CrosswordPuzzle objects
// directly for the validation-semantics tests.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/arithmancer_crosswords_logic.dart';

/// Evaluate an equation operator the same way the solver/validator does.
bool _holds(String op, int a, int b, int c) {
  switch (op) {
    case '+':
      return a + b == c;
    case '−':
    case '-':
      return a - b == c;
    case '×':
    case '*':
      return a * b == c;
    case '÷':
    case '/':
      return b != 0 && a % b == 0 && a ~/ b == c;
    default:
      return false;
  }
}

/// Build a single-equation puzzle: C_0_0 op C_0_2 = C_0_4, with no clues.
CrosswordPuzzle _singleEquationPuzzle(String op, int a, int b, int c) {
  const n1 = math.Point<int>(0, 0);
  const n2 = math.Point<int>(2, 0);
  const n3 = math.Point<int>(4, 0);
  final eq = CrosswordEquation([n1, n2, n3], const math.Point<int>(1, 0), op);
  return CrosswordPuzzle(
    clues: const {},
    emptyCells: {'C_0_0', 'C_0_2', 'C_0_4'},
    equations: [eq],
    numberPool: const [],
    fullSolution: {'C_0_0': a, 'C_0_2': b, 'C_0_4': c},
    numberCells: {n1: 'C_0_0', n2: 'C_0_2', n3: 'C_0_4'},
    operatorCells: {const math.Point<int>(1, 0): op},
    equalsCells: {const math.Point<int>(3, 0)},
  );
}

void main() {
  group('CrosswordConfig.createConfig difficulty scaling bounds', () {
    test('all grade/level combinations stay within documented bounds', () {
      for (var grade = 1; grade <= 4; grade++) {
        for (var level = 1; level <= 20; level++) {
          final cfg = CrosswordConfig.createConfig(grade, level);

          // Number range.
          expect(cfg.minN, CrosswordConfig.baseMinNumber);
          expect(cfg.maxN, lessThanOrEqualTo(CrosswordConfig.maxNumberCap),
              reason: 'maxN capped at maxNumberCap');
          expect(cfg.maxN, greaterThan(cfg.minN));

          // Edges.
          expect(cfg.targetEdges, lessThanOrEqualTo(CrosswordConfig.maxEdges),
              reason: 'edges capped at maxEdges');
          expect(cfg.targetEdges, greaterThanOrEqualTo(CrosswordConfig.baseEdges));

          // Clues.
          expect(cfg.numClues, lessThanOrEqualTo(CrosswordConfig.maxClues),
              reason: 'clues capped at maxClues');
          expect(cfg.numClues, greaterThanOrEqualTo(CrosswordConfig.baseClues));

          // Timeout.
          expect(cfg.timeoutSeconds,
              lessThanOrEqualTo(CrosswordConfig.maxTimeout),
              reason: 'timeout capped at maxTimeout');
          expect(cfg.timeoutSeconds,
              greaterThanOrEqualTo(CrosswordConfig.baseTimeout));

          // Operations match the per-grade table.
          expect(cfg.ops, CrosswordConfig.operationsByGrade[grade]);

          // noDups only enabled at grade 4 level 15+.
          final expectedNoDups = grade >= CrosswordConfig.noDupsStartGrade &&
              level >= CrosswordConfig.noDupsStartLevel;
          expect(cfg.noDups, expectedNoDups);
        }
      }
    });

    test('difficulty is monotonically non-decreasing across grades', () {
      for (var level = 1; level <= 20; level++) {
        var prevMax = 0;
        var prevEdges = 0;
        for (var grade = 1; grade <= 4; grade++) {
          final cfg = CrosswordConfig.createConfig(grade, level);
          expect(cfg.maxN, greaterThanOrEqualTo(prevMax));
          expect(cfg.targetEdges, greaterThanOrEqualTo(prevEdges));
          prevMax = cfg.maxN;
          prevEdges = cfg.targetEdges;
        }
      }
    });

    test('higher levels never produce fewer edges than lower levels', () {
      const grade = 3;
      var prevEdges = 0;
      for (var level = 1; level <= 20; level++) {
        final cfg = CrosswordConfig.createConfig(grade, level);
        expect(cfg.targetEdges, greaterThanOrEqualTo(prevEdges));
        prevEdges = cfg.targetEdges;
      }
    });

    test('custom settings override range and operations', () {
      final cfg = CrosswordConfig.createConfig(
        4,
        20,
        useCustomSettings: true,
        customOps: ['addition', 'multiplication'],
        customMin: 1,
        customMax: 5,
      );
      expect(cfg.minN, 1);
      expect(cfg.maxN, 5);
      expect(cfg.ops, ['+', '×']);
    });
  });

  group('CrosswordPuzzle.validateSolution semantics', () {
    test('accepts a correct addition solution and rejects a corrupted one', () {
      final puzzle = _singleEquationPuzzle('+', 3, 4, 7);
      expect(
          puzzle.validateSolution({'C_0_0': 3, 'C_0_2': 4, 'C_0_4': 7}), isTrue);
      expect(puzzle.validateSolution({'C_0_0': 3, 'C_0_2': 4, 'C_0_4': 8}),
          isFalse);
    });

    test('treats unicode minus and ASCII hyphen identically', () {
      final unicode = _singleEquationPuzzle('−', 9, 4, 5);
      final ascii = _singleEquationPuzzle('-', 9, 4, 5);
      const good = {'C_0_0': 9, 'C_0_2': 4, 'C_0_4': 5};
      const bad = {'C_0_0': 9, 'C_0_2': 4, 'C_0_4': 6};
      expect(unicode.validateSolution(good), isTrue);
      expect(ascii.validateSolution(good), isTrue);
      expect(unicode.validateSolution(bad), isFalse);
      expect(ascii.validateSolution(bad), isFalse);
    });

    test('treats unicode times/divide and ASCII */ identically', () {
      expect(_singleEquationPuzzle('×', 3, 4, 12)
          .validateSolution({'C_0_0': 3, 'C_0_2': 4, 'C_0_4': 12}), isTrue);
      expect(_singleEquationPuzzle('*', 3, 4, 12)
          .validateSolution({'C_0_0': 3, 'C_0_2': 4, 'C_0_4': 12}), isTrue);
      expect(_singleEquationPuzzle('÷', 12, 4, 3)
          .validateSolution({'C_0_0': 12, 'C_0_2': 4, 'C_0_4': 3}), isTrue);
      expect(_singleEquationPuzzle('/', 12, 4, 3)
          .validateSolution({'C_0_0': 12, 'C_0_2': 4, 'C_0_4': 3}), isTrue);
    });

    test('division rejects non-integer / divide-by-zero results', () {
      // 7 / 2 is not an integer -> invalid.
      expect(_singleEquationPuzzle('÷', 7, 2, 3)
          .validateSolution({'C_0_0': 7, 'C_0_2': 2, 'C_0_4': 3}), isFalse);
      // divide by zero -> invalid.
      expect(_singleEquationPuzzle('÷', 5, 0, 0)
          .validateSolution({'C_0_0': 5, 'C_0_2': 0, 'C_0_4': 0}), isFalse);
    });

    test('clue values are merged into the grid during validation', () {
      const n1 = math.Point<int>(0, 0);
      const n2 = math.Point<int>(2, 0);
      const n3 = math.Point<int>(4, 0);
      final eq = CrosswordEquation([n1, n2, n3], const math.Point<int>(1, 0), '+');
      final puzzle = CrosswordPuzzle(
        clues: const {'C_0_0': 2}, // pre-filled clue
        emptyCells: {'C_0_2', 'C_0_4'},
        equations: [eq],
        numberPool: const [],
        fullSolution: {'C_0_0': 2, 'C_0_2': 5, 'C_0_4': 7},
        numberCells: {n1: 'C_0_0', n2: 'C_0_2', n3: 'C_0_4'},
        operatorCells: {const math.Point<int>(1, 0): '+'},
        equalsCells: {const math.Point<int>(3, 0)},
      );
      // User only supplies the empty cells; the clue completes the equation.
      expect(puzzle.validateSolution({'C_0_2': 5, 'C_0_4': 7}), isTrue);
      expect(puzzle.validateSolution({'C_0_2': 6, 'C_0_4': 7}), isFalse);
    });
  });

  group('generateCrosswordPuzzle produces self-consistent puzzles', () {
    test('every equation satisfies its operator under the full solution',
        () async {
      // Small, fast config (grade 1, level 1): few edges, addition only,
      // numbers 1-14. Runs well inside the generator's 6s hard timeout.
      final config = CrosswordConfig.createConfig(1, 1);
      final puzzle = await generateCrosswordPuzzle(config);

      expect(puzzle.equations, isNotEmpty,
          reason: 'a generated puzzle must contain at least one equation');

      for (final eq in puzzle.equations) {
        final names = eq.variableNames;
        final a = puzzle.fullSolution[names[0]];
        final b = puzzle.fullSolution[names[1]];
        final c = puzzle.fullSolution[names[2]];
        expect(a, isNotNull);
        expect(b, isNotNull);
        expect(c, isNotNull);

        // Operator must be one of the configured ops.
        expect(config.ops, contains(eq.operator));

        // The equation must actually hold for the produced solution.
        expect(_holds(eq.operator, a!, b!, c!), isTrue,
            reason: 'equation $eq does not hold: $a ${eq.operator} $b = $c');

        // Operands stay within the configured numeric domain.
        for (final v in [a, b, c]) {
          expect(v, greaterThanOrEqualTo(config.minN));
          expect(v, lessThanOrEqualTo(config.maxN));
        }
      }

      // The puzzle's own validator must accept its own full solution.
      expect(puzzle.validateSolution(puzzle.fullSolution), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
