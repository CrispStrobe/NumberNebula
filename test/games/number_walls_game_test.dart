// Unit tests for number_walls_game.dart (Number Walls).
//
// TESTABILITY NOTE:
//   The screen widget (_NumberWallsGameState) hard-couples to audio/haptics,
//   the GameProvider, generated l10n (S.of(context)), compute() isolates and
//   infinite animation controllers, so it is not a good smoke-test target.
//   HOWEVER the genuinely interesting game logic lives in the PUBLIC, pure
//   data class `NumberWallPuzzle`:
//     - the static `generate(Map)` entry point (the same one fed to compute()),
//     - `validateSolution`, the win/lose oracle,
//     - `getAnswerIndexForCell`, the hidden-cell -> answer-slot mapping,
//     - `getCellPositions`, the layout geometry,
//   plus the static `_validateOperationConstraints` it delegates to. We test
//   these directly.
//
//   The generator uses an UNSEEDED math.Random() internally with no injection
//   seam (we must NOT add one per the task rules), so we cannot assert on exact
//   generated literals. Instead we assert STRUCTURAL INVARIANTS across many
//   generated puzzles, which is the right thing to test for a generator anyway.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/number_walls_game.dart';

/// Builds the args map exactly as the screen does, with custom settings off so
/// generation follows the default grade/level rules.
Map<String, dynamic> _args({required int grade, required int level}) => {
      'grade': grade,
      'level': level,
      'useCustomSettings': false,
      'customOps': <String>[],
      'customMin': 1,
      'customMax': 20,
    };

/// Recomputes the parent value of a wall triple under [op]; mirrors the
/// constraint enforced in _validateOperationConstraints.
bool _tripleHolds(int parent, int left, int right, WallOperation op) {
  switch (op) {
    case WallOperation.addition:
      return parent == left + right;
    case WallOperation.subtraction:
      return parent == (left - right).abs();
    case WallOperation.multiplication:
      return parent == left * right;
    case WallOperation.division:
      if (left == 0 || right == 0) return false;
      final d1 = left / right;
      final d2 = right / left;
      return (d1 == parent && d1 == d1.roundToDouble()) ||
          (d2 == parent && d2 == d2.roundToDouble());
  }
}

/// Returns the user-answer list that exactly reproduces [puzzle.fullSolution]
/// for the hidden cells, in the canonical sorted-hidden-cell order that
/// validateSolution / getAnswerIndexForCell expect.
List<int> _intendedAnswers(NumberWallPuzzle puzzle) {
  final sorted = puzzle.hiddenCells.toList()..sort();
  return [for (final cell in sorted) puzzle.fullSolution[cell]];
}

void main() {
  group('NumberWallPuzzle.generate invariants (50 puzzles per case)', () {
    // Sample a spread of grades/levels covering the operation branches
    // (add/sub for low grades, +mult for grade 3, +mult/div for grade 4) at
    // wall heights 3 and 4.
    //
    // KNOWN SOURCE BUG (documented, not asserted): _determineWallHeight returns
    // 5 or 6 for grade 4 at level >= 5, but _createFallbackWall only defines
    // height-3 (6 cells) and height-4 (10 cells) walls. When the 50-attempt
    // random generation fails for a height-5/6 wall it falls back to an
    // UNDERSIZED list and NumberWallPuzzle.generate throws a RangeError. We
    // therefore restrict the generator-invariant cases to heights 3 and 4,
    // which are the configurations that reliably generate. (Per task rules we
    // do not modify lib/ to add the missing fallback walls.)
    final cases = <Map<String, int>>[
      {'grade': 1, 'level': 1}, // height 3, addition
      {'grade': 2, 'level': 8}, // height 3, add/sub
      {'grade': 3, 'level': 6}, // height 4, add/sub/mult
      {'grade': 3, 'level': 8}, // height 4, add/sub/mult
      {'grade': 4, 'level': 3}, // height 4, add/sub/mult/(no div < lvl6)
      {'grade': 4, 'level': 4}, // height 4
    ];

    for (final c in cases) {
      final g = c['grade']!;
      final l = c['level']!;
      test('grade $g level $l produces well-formed, solvable walls', () {
        for (int iter = 0; iter < 50; iter++) {
          final puzzle = NumberWallPuzzle.generate(_args(grade: g, level: l));

          // Geometry / sizing is self-consistent.
          expect(puzzle.totalCells,
              equals(puzzle.wallHeight * (puzzle.wallHeight + 1) ~/ 2));
          expect(puzzle.fullSolution.length, equals(puzzle.totalCells));
          expect(puzzle.wallHeight, greaterThanOrEqualTo(3));

          // Hidden cells are valid, in range, and not the whole wall.
          expect(puzzle.hiddenCells, isNotEmpty);
          expect(puzzle.hiddenCells.length, lessThan(puzzle.totalCells));
          for (final cell in puzzle.hiddenCells) {
            expect(cell, inInclusiveRange(0, puzzle.totalCells - 1));
          }

          // Visible values cover exactly the non-hidden cells and match the
          // full solution.
          for (int i = 0; i < puzzle.totalCells; i++) {
            if (puzzle.hiddenCells.contains(i)) {
              expect(puzzle.visibleValues.containsKey(i), isFalse);
            } else {
              expect(puzzle.visibleValues[i], equals(puzzle.fullSolution[i]));
            }
          }

          // The full solution actually obeys the wall's operation everywhere.
          for (int row = 0; row < puzzle.wallHeight - 1; row++) {
            final rowStart = row * (row + 1) ~/ 2;
            final nextStart = (row + 1) * (row + 2) ~/ 2;
            for (int col = 0; col <= row; col++) {
              final parent = puzzle.fullSolution[rowStart + col];
              final left = puzzle.fullSolution[nextStart + col];
              final right = puzzle.fullSolution[nextStart + col + 1];
              expect(_tripleHolds(parent, left, right, puzzle.operation), isTrue,
                  reason: 'fullSolution violates ${puzzle.operation.name} at '
                      'row $row col $col: parent=$parent left=$left right=$right');
            }
          }

          // The number pool must contain every hidden number (so the puzzle is
          // actually solvable with the offered bricks).
          final pool = List<int>.from(puzzle.numberPool);
          for (final cell in puzzle.hiddenCells) {
            final needed = puzzle.fullSolution[cell];
            expect(pool.remove(needed), isTrue,
                reason: 'numberPool is missing a required brick $needed; '
                    'pool=${puzzle.numberPool}');
          }
        }
      });
    }
  });

  group('getAnswerIndexForCell', () {
    test('maps hidden cells to their sorted-position index and -1 otherwise',
        () {
      final puzzle = NumberWallPuzzle.generate(_args(grade: 4, level: 4));
      final sorted = puzzle.hiddenCells.toList()..sort();

      for (int slot = 0; slot < sorted.length; slot++) {
        expect(puzzle.getAnswerIndexForCell(sorted[slot]), equals(slot));
      }
      // A non-hidden cell maps to -1.
      for (int i = 0; i < puzzle.totalCells; i++) {
        if (!puzzle.hiddenCells.contains(i)) {
          expect(puzzle.getAnswerIndexForCell(i), equals(-1));
        }
      }
    });
  });

  group('validateSolution', () {
    test('accepts the intended solution for many generated puzzles', () {
      for (int iter = 0; iter < 40; iter++) {
        final puzzle = NumberWallPuzzle.generate(_args(grade: 4, level: 4));
        expect(puzzle.validateSolution(_intendedAnswers(puzzle)), isTrue,
            reason: 'the generator\'s own fullSolution must validate');
      }
    });

    test('rejects a corrupted solution (one slot perturbed)', () {
      for (int iter = 0; iter < 40; iter++) {
        final puzzle = NumberWallPuzzle.generate(_args(grade: 4, level: 4));
        final answers = _intendedAnswers(puzzle);
        if (answers.isEmpty) continue;
        // Perturb the first slot by +1; for a valid wall this must break at
        // least one parent/child constraint involving that cell.
        final corrupted = List<int>.from(answers);
        corrupted[0] = corrupted[0] + 1;
        // Only meaningful if the corruption actually changed the wall; +1 from
        // a non-negative value always differs, so this holds.
        expect(puzzle.validateSolution(corrupted), isFalse,
            reason: 'perturbing a hidden cell must invalidate the wall');
      }
    });

    test('hand-built addition wall validates correctly', () {
      // Height-3 addition wall:
      //        15
      //      7    8
      //    3   4    4
      // Hide the apex (index 0) and the middle of the bottom row (index 4).
      final puzzle = NumberWallPuzzle(
        wallHeight: 3,
        operation: WallOperation.addition,
        hiddenCells: {0, 4},
        visibleValues: {1: 7, 2: 8, 3: 3, 5: 4},
        fullSolution: [15, 7, 8, 3, 4, 4],
        numberPool: [15, 4],
      );
      // sorted hidden cells = [0, 4] -> answers [apex, bottom-middle].
      expect(puzzle.validateSolution([15, 4]), isTrue);
      expect(puzzle.validateSolution([16, 4]), isFalse); // wrong apex
      expect(puzzle.validateSolution([15, 5]), isFalse); // wrong middle
    });
  });

  group('getCellPositions geometry', () {
    test('returns one centered position per cell, all within the container',
        () {
      const size = 300.0;
      for (final op in WallOperation.values) {
        final puzzle = NumberWallPuzzle(
          wallHeight: 4,
          operation: op,
          hiddenCells: {0},
          visibleValues: const {},
          fullSolution: List<int>.filled(10, 1),
          numberPool: const [1],
        );
        final positions = puzzle.getCellPositions(size);
        expect(positions.length, equals(puzzle.totalCells));
        for (final p in positions) {
          expect(p.dx, inInclusiveRange(0.0, size));
          expect(p.dy, inInclusiveRange(0.0, size));
        }
        // Each row is horizontally centered around size/2.
        for (int row = 0; row < puzzle.wallHeight; row++) {
          final start = row * (row + 1) ~/ 2;
          final rowCells = [
            for (int col = 0; col <= row; col++) positions[start + col]
          ];
          final avgX =
              rowCells.map((p) => p.dx).reduce((a, b) => a + b) / rowCells.length;
          expect(avgX, closeTo(size / 2, 0.001),
              reason: 'row $row should be centered horizontally');
        }
      }
    });

    test('subtraction inverts the wall vertically vs addition', () {
      const size = 300.0;
      NumberWallPuzzle make(WallOperation op) => NumberWallPuzzle(
            wallHeight: 4,
            operation: op,
            hiddenCells: {0},
            visibleValues: const {},
            fullSolution: List<int>.filled(10, 1),
            numberPool: const [1],
          );
      final addApex = make(WallOperation.addition).getCellPositions(size)[0];
      final subApex = make(WallOperation.subtraction).getCellPositions(size)[0];
      // Addition: apex (row 0) is at the top (smaller y). Subtraction inverts
      // so the apex sits at the bottom (larger y).
      expect(addApex.dy, lessThan(subApex.dy),
          reason: 'subtraction layout places the single-cell tip at the bottom');
    });
  });
}
