// Unit tests for the pure puzzle logic exported by kenken_game.dart.
//
// The widget (_KenkenGameState) hard-couples to GameProvider, audio/haptics,
// localized strings (S.of) and an infinite-running set of AnimationControllers,
// so a pumped widget test would hang / require heavy plumbing. Fortunately the
// file ALSO exports a complete, side-effect-free Kenken engine that is the real
// value: the operation classes, the cage/Latin-square validators, the cell
// model and the full puzzle generator. We test those invariants directly.
//
// Determinism note: KenkenGenerator seeds its OWN internal math.Random per
// attempt, but the *first* base seed comes from an unseeded math.Random().
// We therefore never assert on the exact board layout — only on structural
// invariants that hold for EVERY valid puzzle (Latin-square property, every
// cage constraint satisfied by its own fullSolution, number pool = 1..size,
// and that a corrupted solution is rejected).

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/screens/kenken_game.dart';

DifficultyConfig _difficulty(int grade, int level) {
  // The generator does not actually read these scalar fields (it scales off
  // grade/level/customOps), so any well-formed config works. Kept minimal.
  return DifficultyConfig(
    grade: grade,
    level: level,
    difficultyMultiplier: 1.0,
    numberRange: const {'min': 1, 'max': 9},
    operationTypes: const [MathOperation.addition],
    equationProbability: 0.0,
    objectCount: 1,
    timeLimit: 0,
    gameSpeed: 1.0,
    showHints: false,
    animationSpeed: 1.0,
    visualComplexity: 1.0,
  );
}

Future<KenkenPuzzle> _generate(int grade, int level) {
  return KenkenPuzzle.generate({
    'grade': grade,
    'level': level,
    'difficulty': _difficulty(grade, level),
    'useCustomSettings': false,
    'customOps': <String>[],
    'customMin': 1,
    'customMax': 100,
  });
}

void main() {
  group('KenkenOperation.calculate', () {
    test('addition sums all operands', () {
      expect(KenkenAddition().calculate([2, 3, 1]), 6);
    });

    test('subtraction is order-independent (absolute difference)', () {
      expect(KenkenSubtraction().calculate([2, 5]), 3);
      expect(KenkenSubtraction().calculate([5, 2]), 3);
    });

    test('multiplication reduces by product', () {
      expect(KenkenMultiplication().calculate([2, 3, 2]), 12);
    });

    test('division divides larger by smaller when divisible, else null', () {
      expect(KenkenDivision().calculate([6, 2]), 3);
      expect(KenkenDivision().calculate([2, 6]), 3);
      expect(KenkenDivision().calculate([5, 2]), isNull);
    });

    test('cell-count metadata matches Kenken rules', () {
      expect(KenkenSubtraction().maxCells, 2);
      expect(KenkenDivision().maxCells, 2);
      expect(KenkenAddition().maxCells, isNull);
      expect(KenkenMultiplication().minCells, 2);
    });
  });

  group('KenkenCell', () {
    test('id encodes row (y) and column (x)', () {
      final cell = KenkenCell(value: 4, x: 2, y: 3);
      expect(cell.id, 'r3c2');
    });
  });

  group('KenkenCage', () {
    test('getTopLeftCell returns smallest (y, x)', () {
      final gen = KenkenGenerator(
        grade: 1,
        level: 1,
        difficultyConfig: _difficulty(1, 1),
        useCustomSettings: false,
        customOps: const {},
        customMin: 1,
        customMax: 100,
      );
      final cage = KenkenCage(id: 1, kenken: gen);
      final a = KenkenCell(value: 1, x: 1, y: 1);
      final b = KenkenCell(value: 2, x: 0, y: 1); // same row, smaller col
      final c = KenkenCell(value: 3, x: 5, y: 0); // top row -> wins
      cage.addCell(a);
      cage.addCell(b);
      cage.addCell(c);
      expect(cage.getTopLeftCell(), same(c));
    });

    test('addCell links the cell back to the cage group', () {
      final gen = KenkenGenerator(
        grade: 1,
        level: 1,
        difficultyConfig: _difficulty(1, 1),
        useCustomSettings: false,
        customOps: const {},
        customMin: 1,
        customMax: 100,
      );
      final cage = KenkenCage(id: 7, kenken: gen);
      final cell = KenkenCell(value: 1, x: 0, y: 0);
      cage.addCell(cell);
      expect(cell.group, same(cage));
      expect(cage.containsCell(0, 0), isTrue);
      expect(cage.containsCell(1, 0), isFalse);
    });

    test('validateConstraint checks a single-cell cage against its value', () {
      final gen = KenkenGenerator(
        grade: 1,
        level: 1,
        difficultyConfig: _difficulty(1, 1),
        useCustomSettings: false,
        customOps: const {},
        customMin: 1,
        customMax: 100,
      );
      final cage = KenkenCage(id: 1, kenken: gen);
      cage.addCell(KenkenCell(value: 3, x: 0, y: 0));
      cage.clue = '3';
      cage.operation = null;
      expect(cage.validateConstraint({'r0c0': 3}), isTrue);
      expect(cage.validateConstraint({'r0c0': 4}), isFalse);
    });

    test('validateConstraint checks a multi-cell additive cage', () {
      final gen = KenkenGenerator(
        grade: 1,
        level: 1,
        difficultyConfig: _difficulty(1, 1),
        useCustomSettings: false,
        customOps: const {},
        customMin: 1,
        customMax: 100,
      );
      final cage = KenkenCage(id: 1, kenken: gen);
      cage.addCell(KenkenCell(value: 0, x: 0, y: 0));
      cage.addCell(KenkenCell(value: 0, x: 1, y: 0));
      cage.operation = KenkenAddition();
      cage.clue = '5+';
      expect(cage.validateConstraint({'r0c0': 2, 'r0c1': 3}), isTrue);
      expect(cage.validateConstraint({'r0c0': 2, 'r0c1': 2}), isFalse);
    });
  });

  group('generated puzzle invariants', () {
    // Cover the size-3 (grade 1) through size-5 (grade 4) configurations.
    final cases = <List<int>>[
      [1, 1], // size 3, addition only
      [2, 1], // size 3, +/-
      [3, 1], // size 4, +/-/x
      [4, 1], // size 5, all ops once level>=6 adds division
    ];

    for (final c in cases) {
      final grade = c[0];
      final level = c[1];

      test('grade $grade level $level: structure is well-formed', () async {
        final puzzle = await _generate(grade, level);

        // Board is a size x size grid.
        expect(puzzle.board.length, puzzle.size);
        for (final row in puzzle.board) {
          expect(row.length, puzzle.size);
        }

        // Number pool is exactly 1..size, each once.
        expect(puzzle.numberPool, List.generate(puzzle.size, (i) => i + 1));

        // Clues + empty cells partition the whole board, no overlap.
        final total = puzzle.size * puzzle.size;
        expect(puzzle.clues.length + puzzle.emptyCells.length, total);
        for (final id in puzzle.clues.keys) {
          expect(puzzle.emptyCells.contains(id), isFalse);
        }

        // Full solution covers every cell with an in-range value.
        expect(puzzle.fullSolution.length, total);
        for (final v in puzzle.fullSolution.values) {
          expect(v, inInclusiveRange(1, puzzle.size));
        }

        // Every cage has at least 2 cells after single-cell merging.
        for (final cage in puzzle.cages) {
          expect(cage.cells.length, greaterThanOrEqualTo(2),
              reason: 'single-cell cages must be merged away');
        }
      });

      test('grade $grade level $level: fullSolution validates, corruption fails',
          () async {
        final puzzle = await _generate(grade, level);

        // The intended solution (everything except pre-filled clues) must pass.
        final userSolution = <String, int>{};
        for (final id in puzzle.emptyCells) {
          userSolution[id] = puzzle.fullSolution[id]!;
        }
        expect(puzzle.validateSolution(userSolution), isTrue,
            reason: 'the generators own solution must satisfy all constraints');

        // Corrupting any single empty cell to a different in-range value must
        // break the Latin-square or a cage constraint (or both).
        final firstEmpty = puzzle.emptyCells.first;
        final correct = puzzle.fullSolution[firstEmpty]!;
        final wrong = correct == puzzle.size ? correct - 1 : correct + 1;
        final corrupted = Map<String, int>.from(userSolution);
        corrupted[firstEmpty] = wrong;
        expect(puzzle.validateSolution(corrupted), isFalse,
            reason: 'a tampered solution must be rejected');
      });
    }

    test('getAllOperators only reports cages that carry an operation',
        () async {
      final puzzle = await _generate(3, 1);
      final operatorCount =
          puzzle.cages.where((cage) => cage.operation != null).length;
      expect(puzzle.getAllOperators().length, operatorCount);
      // Symbols are restricted to the known Kenken operator set.
      for (final sym in puzzle.getAllOperators()) {
        expect(['+', '-', '×', '÷'].contains(sym), isTrue);
      }
    });

    test('many seeded generations stay self-consistent', () async {
      for (int i = 0; i < 12; i++) {
        final puzzle = await _generate(3, 5); // size 5 grid
        final userSolution = <String, int>{};
        for (final id in puzzle.emptyCells) {
          userSolution[id] = puzzle.fullSolution[id]!;
        }
        expect(puzzle.validateSolution(userSolution), isTrue);
      }
    });
  });
}
