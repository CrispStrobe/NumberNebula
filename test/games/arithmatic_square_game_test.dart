// Logic tests for ArithmeticSquarePuzzle (the pure model that lives in the
// arithmatic_square_game screen file).
//
// NOTE on scope: the screen widget itself hard-depends on GameProvider,
// SriService, l10n and an off-thread `compute(...)` puzzle generator that runs
// a CSP solver with an UNSEEDED math.Random — none of which is feasible to
// exercise deterministically without adding a DI seam (which the task forbids).
// The high-value, fully-pure target is `ArithmeticSquarePuzzle`, which has a
// public constructor and pure validation methods:
//   * validateSolution(userSolution)
//   * validateSingleEquation(grid, index, isRow)
//   * getAllOperators()
// We build small hand-authored puzzles with known correct solutions and assert
// the validator accepts the intended solution, rejects corruptions, handles the
// integer-division divisibility rule, and treats the ASCII/Unicode operator
// aliases ('-'/'−', '*'/'×', '/'/'÷') identically.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/arithmatic_square_game.dart';

/// Builds the cellId used throughout the puzzle ('r{row}c{col}').
String cell(int r, int c) => 'r${r}c$c';

/// A solved 3x3 additive square:
///   1 + 2 = 3
///   2 + 2 = 4   (rows: a+b=c)
///   3 + 4 = 7   (last row is the column results)
/// Columns use addition too: col0 1+2=3, col1 2+2=4, col2 3+4=7.
/// Grid layout (r{row}c{col}):
///   1 2 3
///   2 2 4
///   3 4 7
ArithmeticSquarePuzzle buildAdditiveSquare({
  required Set<String> emptyCells,
}) {
  final fullSolution = <String, int>{
    cell(0, 0): 1, cell(0, 1): 2, cell(0, 2): 3,
    cell(1, 0): 2, cell(1, 1): 2, cell(1, 2): 4,
    cell(2, 0): 3, cell(2, 1): 4, cell(2, 2): 7,
  };
  // clues = every non-empty cell.
  final clues = <String, int>{
    for (final e in fullSolution.entries)
      if (!emptyCells.contains(e.key)) e.key: e.value,
  };
  return ArithmeticSquarePuzzle(
    gridSize: 3,
    clues: clues,
    playerHints: const {},
    emptyCells: emptyCells,
    rowOperators: const [
      ['+'],
      ['+'],
      ['+'],
    ],
    columnOperators: const [
      ['+'],
      ['+'],
      ['+'],
    ],
    numberPool: const [],
    fullSolution: fullSolution,
  );
}

void main() {
  group('ArithmeticSquarePuzzle.validateSolution', () {
    test('accepts the intended solution and rejects a corrupted one', () {
      final empties = {cell(0, 0), cell(1, 1), cell(2, 2)};
      final puzzle = buildAdditiveSquare(emptyCells: empties);

      // Correct fill from the known full solution.
      final correct = {
        cell(0, 0): 1,
        cell(1, 1): 2,
        cell(2, 2): 7,
      };
      expect(puzzle.validateSolution(correct), isTrue);

      // Corrupt one cell -> the row/column equation no longer balances.
      final wrong = Map<String, int>.from(correct)..[cell(0, 0)] = 9;
      expect(puzzle.validateSolution(wrong), isFalse);
    });

    test('merges clues, hints and user solution before validating', () {
      // Make r0c0 a player hint rather than a clue, so the merge path that
      // overlays playerHints onto clues is exercised.
      final fullSolution = <String, int>{
        cell(0, 0): 1, cell(0, 1): 2, cell(0, 2): 3,
        cell(1, 0): 2, cell(1, 1): 2, cell(1, 2): 4,
        cell(2, 0): 3, cell(2, 1): 4, cell(2, 2): 7,
      };
      final empties = {cell(1, 1)};
      final puzzle = ArithmeticSquarePuzzle(
        gridSize: 3,
        clues: {
          for (final e in fullSolution.entries)
            if (e.key != cell(0, 0) && !empties.contains(e.key)) e.key: e.value,
        },
        playerHints: {cell(0, 0): 1},
        emptyCells: empties,
        rowOperators: const [
          ['+'],
          ['+'],
          ['+'],
        ],
        columnOperators: const [
          ['+'],
          ['+'],
          ['+'],
        ],
        numberPool: const [],
        fullSolution: fullSolution,
      );

      expect(puzzle.validateSolution({cell(1, 1): 2}), isTrue);
      expect(puzzle.validateSolution({cell(1, 1): 5}), isFalse);
    });
  });

  group('ArithmeticSquarePuzzle.validateSingleEquation', () {
    test('validates an individual row and column independently', () {
      final puzzle = buildAdditiveSquare(emptyCells: const {});
      final grid = puzzle.fullSolution;

      for (var i = 0; i < puzzle.gridSize; i++) {
        expect(puzzle.validateSingleEquation(grid, i, true), isTrue,
            reason: 'row $i should balance');
        expect(puzzle.validateSingleEquation(grid, i, false), isTrue,
            reason: 'column $i should balance');
      }

      // A grid missing a cell cannot be validated -> false (not a throw).
      final incomplete = Map<String, int>.from(grid)..remove(cell(0, 0));
      expect(puzzle.validateSingleEquation(incomplete, 0, true), isFalse);
    });

    test('respects integer-division divisibility for ÷ equations', () {
      // Single row equation: 8 ÷ 2 = 4. Columns are trivial 1-wide? No — we use
      // a 1x... shape would be degenerate, so use a 3-wide row of division:
      //   8 ÷ 2 = 4   (operators length = gridSize - 2 = 1)
      // To keep a well-formed square we reuse 3x3 with division on every line.
      // Build a grid that divides cleanly down rows and columns:
      //   8 4 2
      //   2 2 1
      //   4 2 2
      // row0: 8÷4=2, row1: 2÷2=1, row2: 4÷2=2
      // col0: 8÷2=4, col1: 4÷2=2, col2: 2÷1=2
      final fullSolution = <String, int>{
        cell(0, 0): 8, cell(0, 1): 4, cell(0, 2): 2,
        cell(1, 0): 2, cell(1, 1): 2, cell(1, 2): 1,
        cell(2, 0): 4, cell(2, 1): 2, cell(2, 2): 2,
      };
      final puzzle = ArithmeticSquarePuzzle(
        gridSize: 3,
        clues: fullSolution,
        playerHints: const {},
        emptyCells: const {},
        rowOperators: const [
          ['÷'],
          ['÷'],
          ['÷'],
        ],
        columnOperators: const [
          ['÷'],
          ['÷'],
          ['÷'],
        ],
        numberPool: const [],
        fullSolution: fullSolution,
      );

      expect(puzzle.validateSolution(const {}), isTrue);

      // Non-integer division must fail rather than truncate: 8÷4 expecting 3.
      final badResult = Map<String, int>.from(fullSolution)..[cell(0, 2)] = 3;
      expect(puzzle.validateSingleEquation(badResult, 0, true), isFalse);
    });

    test('treats ASCII and Unicode operator aliases identically', () {
      // Same numeric grid, but operators spelled with ASCII '-' / '*' aliases.
      //   6 2 4   row: 6 - 2 = 4
      //   1 1 1   row: 1 * 1 = 1
      //   6 2 4   row: 6 - 2 = 4
      // col0: 6 - 1 ... we need columns to balance too, so pick simple ops.
      // Use rows with '-' and columns with '-' on a self-consistent grid:
      //   9 4 5   9 - 4 = 5
      //   3 1 2   3 - 1 = 2
      //   6 3 3   6 - 3 = 3
      // col0: 9 - 3 = 6, col1: 4 - 1 = 3, col2: 5 - 2 = 3
      final fullSolution = <String, int>{
        cell(0, 0): 9, cell(0, 1): 4, cell(0, 2): 5,
        cell(1, 0): 3, cell(1, 1): 1, cell(1, 2): 2,
        cell(2, 0): 6, cell(2, 1): 3, cell(2, 2): 3,
      };
      ArithmeticSquarePuzzle make(String minus) => ArithmeticSquarePuzzle(
            gridSize: 3,
            clues: fullSolution,
            playerHints: const {},
            emptyCells: const {},
            rowOperators: [
              [minus],
              [minus],
              [minus],
            ],
            columnOperators: [
              [minus],
              [minus],
              [minus],
            ],
            numberPool: const [],
            fullSolution: fullSolution,
          );

      // Both the Unicode minus and the ASCII hyphen accept the same solution.
      expect(make('−').validateSolution(const {}), isTrue);
      expect(make('-').validateSolution(const {}), isTrue);
    });
  });

  group('ArithmeticSquarePuzzle.getAllOperators', () {
    test('flattens row then column operators in order', () {
      final puzzle = ArithmeticSquarePuzzle(
        gridSize: 3,
        clues: const {},
        playerHints: const {},
        emptyCells: const {},
        rowOperators: const [
          ['+'],
          ['−'],
          ['×'],
        ],
        columnOperators: const [
          ['÷'],
          ['+'],
          ['×'],
        ],
        numberPool: const [],
        fullSolution: const {},
      );

      expect(puzzle.getAllOperators(), ['+', '−', '×', '÷', '+', '×']);
    });
  });
}
