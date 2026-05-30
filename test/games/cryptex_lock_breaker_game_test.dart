// Unit tests for the pure game-logic models in cryptex_lock_breaker_game.dart.
//
// The screen widget itself hard-couples to AnimationControllers, HapticFeedback,
// the GameProvider/SRI services and CustomPainters, so it is not a high-value
// pump target. However the file exposes two public, side-effect-free data
// models — CryptexPuzzle (with its static generator) and CryptexEquation —
// that encode the actual puzzle math. Those are tested directly here.
//
// NOTE on determinism: CryptexPuzzle.generate / _generateSolvablePuzzle use an
// internal, unseeded math.Random() that cannot be injected without editing
// lib/ (forbidden). We therefore do NOT assert on exact generated values;
// instead we assert structural INVARIANTS that must hold for *every* generated
// puzzle across many iterations. CryptexEquation is fully deterministic and is
// tested with exact expectations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/screens/cryptex_lock_breaker_game.dart';

void main() {
  group('CryptexEquation.isSatisfied / _calculateLeftSide', () {
    test('addition equation is satisfied only by matching dials', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '+',
        rightSide: 7,
      );
      expect(eq.isSatisfied([3, 4, 9]), isTrue); // 3 + 4 == 7
      expect(eq.isSatisfied([3, 5, 9]), isFalse); // 3 + 5 == 8
    });

    test('subtraction uses absolute value (order independent)', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '-',
        rightSide: 2,
      );
      expect(eq.isSatisfied([5, 3, 0]), isTrue); // |5 - 3| == 2
      expect(eq.isSatisfied([3, 5, 0]), isTrue); // |3 - 5| == 2
      expect(eq.isSatisfied([3, 4, 0]), isFalse);
    });

    test('multiplication and integer division', () {
      final mul = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '*',
        rightSide: 12,
      );
      expect(mul.isSatisfied([3, 4]), isTrue);
      expect(mul.isSatisfied([2, 4]), isFalse);

      final div = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '/',
        rightSide: 3,
      );
      expect(div.getCurrentResult([9, 3]), 3); // 9 ~/ 3
      expect(div.isSatisfied([9, 3]), isTrue);
    });

    test('division by zero yields 0 rather than throwing', () {
      final div = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '/',
        rightSide: 0,
      );
      expect(() => div.getCurrentResult([5, 0]), returnsNormally);
      expect(div.getCurrentResult([5, 0]), 0);
    });

    test('malformed equation with <2 operands evaluates to 0', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0],
        operator: '+',
        rightSide: 0,
      );
      expect(eq.getCurrentResult([5, 5]), 0);
    });
  });

  group('CryptexEquation display + toMathProblem', () {
    test('display maps operand indices to dial letters', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0, 2],
        operator: '*',
        rightSide: 6,
      );
      expect(eq.getLeftSideDisplay(), 'A * C');
      expect(eq.getRightSideDisplay(), '6');
      expect(eq.toString(), 'A * C = 6');
    });

    test('right side display uses a dial letter when resultDialIndex set', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '+',
        rightSide: 0,
        resultDialIndex: 2,
      );
      expect(eq.getRightSideDisplay(), 'C');
    });

    test('toMathProblem maps operator to the right MathOperation and answer', () {
      final solution = [4, 5, 6];
      final eq = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '*',
        rightSide: 20,
      );
      final problem = eq.toMathProblem(solution);
      expect(problem.operation, MathOperation.multiplication);
      expect(problem.operandA, 4);
      expect(problem.operandB, 5);
      expect(problem.answer, 20); // rightSide is used as the answer
      expect(problem.difficulty, 3); // * and / are difficulty 3

      final addEq = CryptexEquation(
        leftOperandIndices: [0, 1],
        operator: '+',
        rightSide: 9,
      );
      final addProblem = addEq.toMathProblem(solution);
      expect(addProblem.operation, MathOperation.addition);
      expect(addProblem.difficulty, 1);
    });

    test('toMathProblem returns a safe dummy for malformed equations', () {
      final eq = CryptexEquation(
        leftOperandIndices: [0],
        operator: '+',
        rightSide: 5,
      );
      final problem = eq.toMathProblem([1, 2, 3]);
      expect(problem.expression, 'error');
      expect(problem.answer, 0);
    });
  });

  group('CryptexPuzzle.generate invariants (many seeds)', () {
    test('every generated puzzle is well-formed and solved by its solution', () {
      // Cover the full complexity ladder used inside generate().
      const cases = <List<int>>[
        [1, 0], // complexity 1.0  -> 3 dials, +/-
        [2, 0], // complexity 2.0  -> 3 dials
        [3, 0], // complexity 3.0  -> 3 or 4 dials, +/-/*
        [4, 0], // complexity 4.0  -> 4 dials, all ops
        [5, 0], // complexity 5.0  -> 4 dials
        [6, 5], // complexity 7.0  -> 4 or 5 dials
      ];

      for (final c in cases) {
        final grade = c[0];
        final level = c[1];
        for (int iter = 0; iter < 30; iter++) {
          final puzzle = CryptexPuzzle.generate(grade, level);

          // Structural invariants.
          expect(puzzle.dialCount, inInclusiveRange(3, 5));
          expect(puzzle.solution.length, puzzle.dialCount);
          expect(puzzle.initialValues.length, puzzle.dialCount);
          expect(puzzle.equations, isNotEmpty);

          // Solution digits are 1..9; dials addressable.
          for (final v in puzzle.solution) {
            expect(v, inInclusiveRange(1, 9));
          }
          // Initial values are valid digits and differ from the solution
          // (so the puzzle always starts unsolved).
          for (int i = 0; i < puzzle.dialCount; i++) {
            expect(puzzle.initialValues[i], inInclusiveRange(0, 9));
            expect(puzzle.initialValues[i] == puzzle.solution[i], isFalse);
          }

          // Every equation references in-bounds dials with a known operator.
          for (final eq in puzzle.equations) {
            for (final idx in eq.leftOperandIndices) {
              expect(idx, inInclusiveRange(0, puzzle.dialCount - 1));
            }
            expect(['+', '-', '*', '/'].contains(eq.operator), isTrue);
          }

          // CORE INVARIANT: the puzzle is solvable — its own solution
          // satisfies every equation simultaneously.
          expect(
            puzzle.equations.every((eq) => eq.isSatisfied(puzzle.solution)),
            isTrue,
            reason: 'grade=$grade level=$level iter=$iter solution='
                '${puzzle.solution} equations=${puzzle.equations}',
          );

          // The initial (starting) state must NOT already satisfy everything,
          // because at least one dial differs from the solution. We only
          // assert it is not trivially pre-solved when the differing dial
          // participates in some equation; the weaker guarantee we can always
          // assert is that initial != solution element-wise (checked above).
        }
      }
    });
  });
}
