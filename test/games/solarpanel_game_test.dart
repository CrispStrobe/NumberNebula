// Unit tests for solarpanel_game.dart (Solar Panel).
//
// TESTABILITY NOTE:
//   The screen widget (_SolarPanelGameState) hard-couples to haptics, the
//   GameProvider, generated l10n (S.of(context)), compute() isolates and
//   several infinite animation controllers, so it is not a good smoke-test
//   target. HOWEVER the genuinely interesting game logic lives in the PUBLIC,
//   pure data class `SolarPanelPuzzle`:
//     - the static `generate(Map)` entry point (the same one fed to compute()),
//     - `validateSolution`, the win/lose oracle,
//     - `getAnswerIndexForCell`, the hidden-cell -> answer-slot mapping,
//     - `getCellPositions`, the layout geometry.
//   We test these directly.
//
//   The generator uses an UNSEEDED math.Random() internally with no injection
//   seam (we must NOT add one per the task rules), so we cannot assert on exact
//   generated literals. Instead we assert STRUCTURAL INVARIANTS across many
//   generated puzzles, which is the right thing to test for a generator anyway.
//
//   The panel relation under test:
//     leftPanel  = A * B   (solution[1] = solution[3] * solution[4])
//     rightPanel = B * C   (solution[2] = solution[4] * solution[5])
//     top        = leftPanel + rightPanel  (solution[0] = solution[1] + solution[2])

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/solarpanel_game.dart';

/// Builds the args map exactly as the screen does, with custom settings off so
/// generation follows the default grade/level rules.
Map<String, dynamic> _args({required int grade, required int level}) => {
      'grade': grade,
      'level': level,
      'useCustomSettings': false,
      'customMin': 1,
      'customMax': 20,
    };

/// True iff [solution] (= [top, leftPanel, rightPanel, A, B, C]) is internally
/// consistent with the solar-panel arithmetic relation.
bool _solutionConsistent(List<int> s) {
  final top = s[0];
  final leftPanel = s[1];
  final rightPanel = s[2];
  final a = s[3];
  final b = s[4];
  final c = s[5];
  return leftPanel == a * b && rightPanel == b * c && top == leftPanel + rightPanel;
}

void main() {
  group('SolarPanelPuzzle.generate invariants', () {
    test('many generated puzzles are well-formed and self-consistent', () {
      // Cover a spread of grades/levels. Generator is unseeded internally,
      // so we run several iterations per config to exercise its randomness.
      for (var grade = 1; grade <= 4; grade++) {
        for (var level = 1; level <= 10; level++) {
          for (var iter = 0; iter < 3; iter++) {
            final puzzle = SolarPanelPuzzle.generate(_args(grade: grade, level: level));

            // fullSolution must be a 6-cell panel obeying the relation.
            expect(puzzle.fullSolution.length, 6,
                reason: 'grade=$grade level=$level: solution must have 6 cells');
            expect(_solutionConsistent(puzzle.fullSolution), isTrue,
                reason:
                    'grade=$grade level=$level: ${puzzle.fullSolution} must satisfy panel relation');

            // baseNumbers are the [A, B, C] tail of the solution.
            expect(puzzle.baseNumbers, puzzle.fullSolution.sublist(3, 6),
                reason: 'grade=$grade level=$level: baseNumbers == solution[3..6)');

            // Hidden-cell count is clamped to [2, 5] and at least one base
            // number (cell 3/4/5) is always hidden.
            expect(puzzle.hiddenCells.length, inInclusiveRange(2, 5),
                reason: 'grade=$grade level=$level: hidden count clamped 2..5');
            expect(puzzle.hiddenCells.every((c) => c >= 0 && c < 6), isTrue,
                reason: 'grade=$grade level=$level: hidden cells in 0..5');
            expect(puzzle.hiddenCells.any((c) => c == 3 || c == 4 || c == 5), isTrue,
                reason: 'grade=$grade level=$level: at least one base number hidden');

            // Visible values cover exactly the non-hidden cells and match the
            // true solution.
            for (var i = 0; i < 6; i++) {
              if (puzzle.hiddenCells.contains(i)) {
                expect(puzzle.visibleValues.containsKey(i), isFalse,
                    reason: 'grade=$grade level=$level: hidden cell $i is not visible');
              } else {
                expect(puzzle.visibleValues[i], puzzle.fullSolution[i],
                    reason: 'grade=$grade level=$level: visible cell $i matches solution');
              }
            }
          }
        }
      }
    });

    test('number pool contains the correct hidden answers', () {
      for (var iter = 0; iter < 30; iter++) {
        final puzzle = SolarPanelPuzzle.generate(_args(grade: 2, level: 5));
        final sortedHidden = puzzle.hiddenCells.toList()..sort();
        // Every hidden answer value must be available in the number pool so the
        // puzzle is actually solvable by dragging from the pool.
        for (final cell in sortedHidden) {
          expect(puzzle.numberPool.contains(puzzle.fullSolution[cell]), isTrue,
              reason: 'hidden cell $cell value ${puzzle.fullSolution[cell]} '
                  'must be in pool ${puzzle.numberPool}');
        }
        // Pool is never empty and not absurdly large.
        expect(puzzle.numberPool, isNotEmpty);
        expect(puzzle.numberPool.length, lessThanOrEqualTo(12));
      }
    });
  });

  group('getAnswerIndexForCell', () {
    test('maps hidden cells to sorted answer slots and rejects visible cells', () {
      final puzzle = SolarPanelPuzzle(
        baseNumbers: const [3, 2, 4],
        hiddenCells: const {1, 4, 3}, // intentionally unsorted
        visibleValues: const {0: 14, 2: 8, 5: 4},
        fullSolution: const [14, 6, 8, 3, 2, 4],
        numberPool: const [6, 3, 2],
      );

      // Sorted hidden cells: [1, 3, 4] -> answer indices 0, 1, 2.
      expect(puzzle.getAnswerIndexForCell(1), 0);
      expect(puzzle.getAnswerIndexForCell(3), 1);
      expect(puzzle.getAnswerIndexForCell(4), 2);

      // Non-hidden cells map to -1.
      expect(puzzle.getAnswerIndexForCell(0), -1);
      expect(puzzle.getAnswerIndexForCell(2), -1);
      expect(puzzle.getAnswerIndexForCell(5), -1);
    });
  });

  group('validateSolution', () {
    // Panel: top=14, left=6, right=8, A=3, B=2, C=4. Hide left(1), A(3), B(4).
    SolarPanelPuzzle buildPuzzle() => SolarPanelPuzzle(
          baseNumbers: const [3, 2, 4],
          hiddenCells: const {1, 3, 4},
          visibleValues: const {0: 14, 2: 8, 5: 4},
          fullSolution: const [14, 6, 8, 3, 2, 4],
          numberPool: const [6, 3, 2, 5, 7],
        );

    test('accepts the intended solution', () {
      final puzzle = buildPuzzle();
      // Sorted hidden cells [1, 3, 4] -> answers [left=6, A=3, B=2].
      expect(puzzle.validateSolution(const [6, 3, 2]), isTrue);
    });

    test('rejects a corrupted solution', () {
      final puzzle = buildPuzzle();
      // Wrong A breaks left = A*B and top = left+right.
      expect(puzzle.validateSolution(const [6, 5, 2]), isFalse);
      // Wrong left panel value.
      expect(puzzle.validateSolution(const [7, 3, 2]), isFalse);
    });

    test('a freshly generated puzzle validates against its own solution', () {
      for (var iter = 0; iter < 30; iter++) {
        final puzzle = SolarPanelPuzzle.generate(_args(grade: 3, level: 6));
        final sortedHidden = puzzle.hiddenCells.toList()..sort();
        final intended =
            sortedHidden.map((cell) => puzzle.fullSolution[cell]).toList();
        expect(puzzle.validateSolution(intended), isTrue,
            reason: 'generated puzzle must accept its own hidden values');

        // Corrupt the first hidden answer and expect rejection (offset by +1
        // cannot keep all three arithmetic relations true simultaneously).
        final corrupted = List<int>.from(intended);
        corrupted[0] = corrupted[0] + 1;
        expect(puzzle.validateSolution(corrupted), isFalse,
            reason: 'corrupting an answer must break validation');
      }
    });
  });

  group('getCellPositions', () {
    test('produces 6 in-bounds positions in the expected pyramid layout', () {
      final puzzle = SolarPanelPuzzle.generate(_args(grade: 1, level: 1));
      const size = 400.0;
      final positions = puzzle.getCellPositions(size);

      expect(positions.length, 6);
      for (final p in positions) {
        expect(p.dx, inInclusiveRange(0.0, size));
        expect(p.dy, inInclusiveRange(0.0, size));
      }

      // Top cell (0) is horizontally centered and highest on screen.
      expect(positions[0].dx, closeTo(size / 2, 0.001));
      // Rows descend: top row above middle row above bottom row.
      expect(positions[0].dy, lessThan(positions[1].dy));
      expect(positions[1].dy, lessThan(positions[3].dy));
      // Middle/bottom rows share their own y.
      expect(positions[1].dy, closeTo(positions[2].dy, 0.001));
      expect(positions[3].dy, closeTo(positions[4].dy, 0.001));
      expect(positions[4].dy, closeTo(positions[5].dy, 0.001));
      // Bottom row A,B,C are left-of-center, center, right-of-center.
      expect(positions[3].dx, lessThan(positions[4].dx));
      expect(positions[4].dx, lessThan(positions[5].dx));
      expect(positions[4].dx, closeTo(size / 2, 0.001));
    });

    test('scales linearly with container size', () {
      final puzzle = SolarPanelPuzzle.generate(_args(grade: 1, level: 1));
      final small = puzzle.getCellPositions(200.0);
      final big = puzzle.getCellPositions(400.0);
      for (var i = 0; i < 6; i++) {
        expect(big[i], _offsetCloseTo(small[i] * 2.0));
      }
    });
  });
}

/// Matcher for an Offset close to [expected] within a small tolerance.
Matcher _offsetCloseTo(Offset expected, [double tol = 0.001]) =>
    predicate<Offset>(
      (o) => (o.dx - expected.dx).abs() <= tol && (o.dy - expected.dy).abs() <= tol,
      'Offset close to $expected',
    );
