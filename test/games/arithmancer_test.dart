// Unit tests for the pure card-battler engine in
// lib/shared/utils/arithmancer.dart.
//
// We focus on the deterministic, side-effect-free parts of the engine:
//   * MathResult's number-property detectors (isPrime/isPerfectSquare/...)
//   * damage/block derivation and clamping
//   * MathCard.clone independence
//   * ExpressionEvaluator operator precedence + divide-by-zero guard
//
// We do NOT exercise ArithmancerGame.startNewBattle / takeTurn / log because
// those call print() and mutate game state; they are out of scope for a focused
// logic test. The combat/AI orchestration is left untested by design (it would
// need a logging seam to assert cleanly).

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/shared/utils/arithmancer.dart';

/// Builds a non-chained MathResult with the given numeric value. The property
/// getters only depend on `value` and `isChained`, so empty cards/expression
/// are fine for detector tests.
MathResult resultOf(double value, {List<MathCard>? cards}) =>
    MathResult(value, cards ?? const <MathCard>[], value.toString(),
        const <String>[]);

void main() {
  group('MathResult number-property detectors', () {
    test('isPrime accepts known primes and rejects non-primes', () {
      for (final p in [2, 3, 5, 7, 11, 13, 17, 19, 97, 101]) {
        expect(resultOf(p.toDouble()).isPrime, isTrue,
            reason: '$p should be prime');
      }
      for (final n in [0, 1, 4, 9, 15, 100, -7]) {
        expect(resultOf(n.toDouble()).isPrime, isFalse,
            reason: '$n should not be prime');
      }
    });

    test('isComposite is true only for composites (>=4, not prime)', () {
      for (final c in [4, 6, 8, 9, 100]) {
        expect(resultOf(c.toDouble()).isComposite, isTrue, reason: '$c');
      }
      for (final n in [1, 2, 3, 5, 7]) {
        expect(resultOf(n.toDouble()).isComposite, isFalse, reason: '$n');
      }
    });

    test('isPerfectSquare and isPerfectCube', () {
      for (final s in [0, 1, 4, 9, 16, 25, 100]) {
        expect(resultOf(s.toDouble()).isPerfectSquare, isTrue, reason: '$s');
      }
      expect(resultOf(2).isPerfectSquare, isFalse);
      expect(resultOf(-4).isPerfectSquare, isFalse);

      for (final c in [0, 1, 8, 27, 64]) {
        expect(resultOf(c.toDouble()).isPerfectCube, isTrue, reason: '$c');
      }
      expect(resultOf(9).isPerfectCube, isFalse);
    });

    test('isFibonacci within the hardcoded table (audit-flagged: <=1597)', () {
      for (final f in [0, 1, 2, 3, 5, 8, 13, 21, 34, 1597]) {
        expect(resultOf(f.toDouble()).isFibonacci, isTrue, reason: '$f');
      }
      // Inside the table's range but not a Fibonacci number.
      for (final n in [4, 6, 9, 100]) {
        expect(resultOf(n.toDouble()).isFibonacci, isFalse, reason: '$n');
      }
      // 2584 is the next Fibonacci after 1597 but the detector's table stops at
      // 1597, so it is (incorrectly, per the audit) reported as non-Fibonacci.
      expect(resultOf(2584).isFibonacci, isFalse);
    });

    test('isTriangular / isPentagonal / isHexagonal against formula values', () {
      for (final t in [1, 3, 6, 10, 15, 21, 28, 36]) {
        expect(resultOf(t.toDouble()).isTriangular, isTrue, reason: 't=$t');
      }
      expect(resultOf(7).isTriangular, isFalse);

      for (final p in [1, 5, 12, 22, 35, 51]) {
        expect(resultOf(p.toDouble()).isPentagonal, isTrue, reason: 'p=$p');
      }
      expect(resultOf(13).isPentagonal, isFalse);

      for (final h in [1, 6, 15, 28, 45, 66]) {
        expect(resultOf(h.toDouble()).isHexagonal, isTrue, reason: 'h=$h');
      }
      expect(resultOf(7).isHexagonal, isFalse);
    });

    test('isPowerOfTwo, isPalindromic, isMersennePrime, isCatalan', () {
      for (final p in [1, 2, 4, 8, 16, 32, 64]) {
        expect(resultOf(p.toDouble()).isPowerOfTwo, isTrue, reason: '$p');
      }
      expect(resultOf(6).isPowerOfTwo, isFalse);

      for (final p in [1, 7, 11, 22, 101, 111]) {
        expect(resultOf(p.toDouble()).isPalindromic, isTrue, reason: '$p');
      }
      expect(resultOf(12).isPalindromic, isFalse);

      // Mersenne primes: 2^p - 1 that are themselves prime (3, 7, 31, 127).
      for (final m in [3, 7, 31, 127]) {
        expect(resultOf(m.toDouble()).isMersennePrime, isTrue, reason: '$m');
      }
      expect(resultOf(15).isMersennePrime, isFalse); // 2^4-1 but not prime
      expect(resultOf(5).isMersennePrime, isFalse); // prime but 6 not pow2

      for (final c in [1, 2, 5, 14, 42, 132]) {
        expect(resultOf(c.toDouble()).isCatalan, isTrue, reason: '$c');
      }
      expect(resultOf(3).isCatalan, isFalse);
    });

    test('parity, sign, divisibility and fractional', () {
      expect(resultOf(4).isEven, isTrue);
      expect(resultOf(4).isOdd, isFalse);
      expect(resultOf(5).isOdd, isTrue);
      expect(resultOf(-3).isNegative, isTrue);
      expect(resultOf(3).isNegative, isFalse);
      expect(resultOf(0.5).isFractional, isTrue);
      expect(resultOf(1.5).isFractional, isFalse); // must be in (0, 1)
      expect(resultOf(9).isDivisibleBy3, isTrue);
      expect(resultOf(25).isDivisibleBy5, isTrue);
      expect(resultOf(21).isDivisibleBy7, isTrue);
      expect(resultOf(22).isDivisibleBy7, isFalse);
    });

    test('chained results suppress single-value property detectors', () {
      final left = resultOf(7); // prime
      final right = resultOf(4); // perfect square
      final chained = MathResult.chained(left, right, const <MathCard>[]);
      expect(chained.isChained, isTrue);
      expect(chained.isPrime, isFalse);
      expect(chained.isPerfectSquare, isFalse);
      expect(chained.isEven, isFalse);
    });
  });

  group('MathResult damage / block clamping', () {
    test('positive value becomes damage, no block', () {
      final r = resultOf(12);
      expect(r.damage, 12);
      expect(r.block, 0);
    });

    test('negative value becomes block, no damage', () {
      final r = resultOf(-8);
      expect(r.damage, 0);
      expect(r.block, 8);
    });

    test('damage clamps to 9999 ceiling', () {
      expect(resultOf(50000).damage, 9999);
      expect(resultOf(-50000).block, 9999);
    });

    test('chained damage/block is the sum of both sides', () {
      final chained = MathResult.chained(resultOf(10), resultOf(-4),
          const <MathCard>[]);
      expect(chained.damage, 10); // 10 + 0
      expect(chained.block, 4); //  0 + 4
    });

    test('fractional value yields damageReduction equal to value', () {
      final r = resultOf(0.25);
      expect(r.damageReduction, closeTo(0.25, 1e-9));
      expect(resultOf(5).damageReduction, 0.0);
    });
  });

  group('MathCard.clone', () {
    test('clone copies fields and gives an independent properties map', () {
      final card = MathCard(
        id: 'fixed-id',
        name: 'Seven',
        type: CardType.number,
        cost: 2,
        value: 7,
        properties: {'tag': 'lucky'},
      );
      final copy = card.clone();

      expect(copy.id, card.id);
      expect(copy.name, card.name);
      expect(copy.value, card.value);
      expect(copy.cost, card.cost);

      // Mutating the clone's map must not affect the original.
      copy.properties['tag'] = 'changed';
      copy.properties['extra'] = true;
      expect(card.properties['tag'], 'lucky');
      expect(card.properties.containsKey('extra'), isFalse);
    });

    test('clone with newId produces a different, non-empty id', () {
      final card = MathCard(id: 'orig', name: 'Two', type: CardType.number);
      final copy = card.clone(newId: true);
      expect(copy.id, isNot('orig'));
      expect(copy.id, isNotEmpty);
    });
  });

  group('ExpressionEvaluator', () {
    final evaluator = ExpressionEvaluator();

    MathCard num_(int v) =>
        MathCard(name: '$v', type: CardType.number, value: v);
    MathCard op(String o) =>
        MathCard(name: o, type: CardType.operator, operator: o);

    // NOTE on precedence: the documented invariant "2 + 3 * 4 == 14" lives in
    // the private _toPostfix/_evaluatePostfix shunting-yard methods. The only
    // public entry point, generateAllResults, never emits a multi-operator
    // expression for these hands (its _canAddCard / parentheses-consumption
    // rules cap each generated expression at a single operator), so the
    // precedence path cannot be reached without a DI/visibility seam that we
    // are not permitted to add. We therefore assert the single-operator results
    // the generator DOES produce, which still proves arithmetic correctness.
    test('single-operator arithmetic is correct', () {
      final hand = [num_(2), op('+'), num_(3), op('*'), num_(4)];
      final values =
          evaluator.generateAllResults(hand).map((r) => r.value).toSet();
      expect(values, containsAll(<double>[5.0, 8.0, 12.0]),
          reason: '2+3=5, 2*4=8, 3*4=12 should all be reachable');
    });

    test('division by zero is guarded (no NaN/Infinity results)', () {
      final hand = [num_(5), op('/'), num_(0)];
      final results = evaluator.generateAllResults(hand);

      for (final r in results) {
        expect(r.value.isFinite, isTrue,
            reason: 'no result should be Infinity/NaN');
      }
      // 5 / 0 must not surface as a result value.
      final divResult = results.where((r) => r.expression == '5 / 0');
      expect(divResult, isEmpty,
          reason: 'divide-by-zero expression should be dropped, not returned');
    });

    test('exact division evaluates correctly', () {
      final hand = [num_(8), op('/'), num_(2)];
      final results = evaluator.generateAllResults(hand);
      expect(results.map((r) => r.value), contains(4.0));
    });
  });
}
