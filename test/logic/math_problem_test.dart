// Unit tests for MathProblem (pure model logic).
//
// We test the deterministic, dependency-free parts of the model:
// the factory constructors, isValid(), JSON round-trip, and
// generateMultipleChoiceOptions(). We deliberately do NOT exercise
// MathProblem.generateProblem / .random / _generateFromConfig because
// those construct an unseeded math.Random internally (no DI seam) and
// depend on GameProvider + SriService; per the no-lib-changes rule we
// leave them untested. generateMultipleChoiceOptions() also uses an
// internal unseeded Random, so we assert only its INVARIANTS, not exact
// values, and run many iterations to shake out flakiness.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';

void main() {
  group('factory constructors compute correct answers', () {
    final rng = math.Random(42);

    test('addition: answer == a + b and operands preserved', () {
      for (var i = 0; i < 50; i++) {
        final a = rng.nextInt(200);
        final b = rng.nextInt(200);
        final p = MathProblem.addition(a, b);
        expect(p.answer, a + b);
        expect(p.operandA, a);
        expect(p.operandB, b);
        expect(p.operation, MathOperation.addition);
        expect(p.expression, '$a + $b');
        expect(p.isValid(), isTrue);
      }
    });

    test('subtraction: never negative, larger operand first', () {
      for (var i = 0; i < 50; i++) {
        final a = rng.nextInt(200);
        final b = rng.nextInt(200);
        final p = MathProblem.subtraction(a, b);
        expect(p.answer, isNonNegative);
        expect(p.answer, math.max(a, b) - math.min(a, b));
        // Factory swaps so operandA >= operandB.
        expect(p.operandA, greaterThanOrEqualTo(p.operandB));
        expect(p.operandA - p.operandB, p.answer);
        expect(p.operation, MathOperation.subtraction);
        expect(p.isValid(), isTrue);
      }
    });

    test('multiplication: answer == a * b', () {
      for (var i = 0; i < 50; i++) {
        final a = rng.nextInt(20);
        final b = rng.nextInt(20);
        final p = MathProblem.multiplication(a, b);
        expect(p.answer, a * b);
        expect(p.operation, MathOperation.multiplication);
        expect(p.isValid(), isTrue);
      }
    });

    test('division: clean (no remainder) and answer is the quotient', () {
      for (var i = 0; i < 50; i++) {
        final divisor = rng.nextInt(11) + 2; // 2..12, avoid zero
        final dividend = rng.nextInt(200) + 1;
        final p = MathProblem.division(dividend, divisor);
        // Division must be exact: operandA divisible by operandB.
        expect(p.operandB, divisor);
        expect(p.operandA % p.operandB, 0);
        expect(p.operandA ~/ p.operandB, p.answer);
        expect(p.operation, MathOperation.division);
        expect(p.isValid(), isTrue);
      }
    });
  });

  group('isValid()', () {
    test('rejects a corrupted answer', () {
      final good = MathProblem.addition(7, 8); // answer 15
      expect(good.isValid(), isTrue);

      final corrupted = MathProblem(
        expression: '7 + 8',
        answer: 16, // wrong
        operation: MathOperation.addition,
        operandA: 7,
        operandB: 8,
        difficulty: 1,
      );
      expect(corrupted.isValid(), isFalse);
    });

    test('rejects division with a remainder', () {
      final bad = MathProblem(
        expression: '10 ÷ 3',
        answer: 3,
        operation: MathOperation.division,
        operandA: 10,
        operandB: 3,
        difficulty: 1,
      );
      expect(bad.isValid(), isFalse);
    });
  });

  group('toJson / fromJson round-trip', () {
    test('preserves all fields across each operation type', () {
      final originals = <MathProblem>[
        MathProblem.addition(12, 34, difficulty: 2),
        MathProblem.subtraction(50, 17, difficulty: 3),
        MathProblem.multiplication(6, 7, difficulty: 4),
        MathProblem.division(48, 6, difficulty: 5),
      ];

      for (final original in originals) {
        final restored = MathProblem.fromJson(original.toJson());
        expect(restored, original); // operator== compares core fields
        expect(restored.answer, original.answer);
        expect(restored.operation, original.operation);
        expect(restored.operandA, original.operandA);
        expect(restored.operandB, original.operandB);
        expect(restored.difficulty, original.difficulty);
        expect(restored.isValid(), isTrue);
      }
    });
  });

  group('generateMultipleChoiceOptions()', () {
    test('contains correct answer, no duplicates, count respected, '
        'all positive (many iterations across operations)', () {
      final problems = <MathProblem>[
        MathProblem.addition(13, 9),
        MathProblem.subtraction(40, 11),
        MathProblem.multiplication(8, 7),
        MathProblem.division(56, 7),
      ];

      for (final p in problems) {
        // Repeat to catch flakiness from the internal unseeded Random.
        for (var iter = 0; iter < 100; iter++) {
          final opts = p.generateMultipleChoiceOptions();
          expect(opts.length, 4);
          expect(opts.toSet().length, opts.length,
              reason: 'options must be unique');
          expect(opts, contains(p.answer));
          expect(opts.every((o) => o > 0), isTrue,
              reason: 'all options must be positive');
        }
      }
    });

    test('respects a custom optionsCount', () {
      final p = MathProblem.multiplication(9, 9); // answer 81, lots of headroom
      for (var iter = 0; iter < 50; iter++) {
        final opts = p.generateMultipleChoiceOptions(optionsCount: 3);
        expect(opts.length, 3);
        expect(opts.toSet().length, 3);
        expect(opts, contains(81));
      }
    });
  });
}
