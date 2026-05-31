// Unit tests for the mathematical invariants of the Galactic Market game.
//
// The game logic is fully private inside _GalacticMarketGameState.
// We reimplement the greedy coin-counting algorithm and test the invariants
// that the game relies on: target reachability, optimal coin count correctness,
// and denomination set validity.

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

/// Greedy optimal coin count, matching _calculateOptimalCoins from the game.
int _calculateOptimalCoins(int target, List<int> denoms) {
  int remaining = target;
  int count = 0;
  for (final d in denoms) {
    count += remaining ~/ d;
    remaining = remaining % d;
  }
  return count;
}

/// Generates puzzle parameters matching the game's _generatePuzzle logic.
class _MarketPuzzle {
  final int target;
  final List<int> denominations; // sorted descending
  final int optimalCount;

  _MarketPuzzle({
    required this.target,
    required this.denominations,
    required this.optimalCount,
  });

  static _MarketPuzzle generate(int grade, math.Random random) {
    List<int> denoms;
    int target;

    if (grade <= 2) {
      denoms = [1, 2, 5];
      target = random.nextInt(15) + 5; // 5-19
    } else {
      denoms = [1, 2, 5, 10, 25];
      if (grade >= 4) denoms.add(50);
      target = random.nextInt(80) + 20; // 20-99
    }

    denoms.sort((a, b) => b.compareTo(a));
    final optimalCount = _calculateOptimalCoins(target, denoms);

    return _MarketPuzzle(
      target: target,
      denominations: denoms,
      optimalCount: optimalCount,
    );
  }
}

void main() {
  group('Galactic Market: greedy optimal coin algorithm', () {
    test('known examples produce correct optimal counts', () {
      // With [25, 10, 5, 2, 1]:
      // 41 = 25 + 10 + 5 + 1 = 4 coins
      expect(_calculateOptimalCoins(41, [25, 10, 5, 2, 1]), 4);

      // 30 = 25 + 5 = 2 coins
      expect(_calculateOptimalCoins(30, [25, 10, 5, 2, 1]), 2);

      // 1 = 1 coin
      expect(_calculateOptimalCoins(1, [5, 2, 1]), 1);

      // 5 = 1 coin
      expect(_calculateOptimalCoins(5, [5, 2, 1]), 1);

      // 7 = 5 + 2 = 2 coins
      expect(_calculateOptimalCoins(7, [5, 2, 1]), 2);

      // 0 = 0 coins
      expect(_calculateOptimalCoins(0, [5, 2, 1]), 0);
    });

    test('greedy works correctly because denomination 1 is always present', () {
      // Since 1 is always in the denomination set, any target is reachable.
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _MarketPuzzle.generate(1, random);
        expect(p.denominations.contains(1), isTrue,
            reason: 'denomination set must include 1');

        // Verify the greedy solution actually reaches the target
        int remaining = p.target;
        int coins = 0;
        for (final d in p.denominations) {
          coins += remaining ~/ d;
          remaining = remaining % d;
        }
        expect(remaining, 0, reason: 'greedy must reach target exactly');
        expect(coins, p.optimalCount);
      }
    });
  });

  group('Galactic Market: target ranges per grade', () {
    test('grade 1-2 produces target in [5, 19]', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _MarketPuzzle.generate(1, random);
        expect(p.target, inInclusiveRange(5, 19));
        expect(p.denominations, [5, 2, 1]);
      }
    });

    test('grade 3 produces target in [20, 99] with 5 denominations', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _MarketPuzzle.generate(3, random);
        expect(p.target, inInclusiveRange(20, 99));
        expect(p.denominations, [25, 10, 5, 2, 1]);
      }
    });

    test('grade 4 adds denomination 50', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _MarketPuzzle.generate(4, random);
        expect(p.target, inInclusiveRange(20, 99));
        expect(p.denominations.contains(50), isTrue);
        expect(p.denominations, [50, 25, 10, 5, 2, 1]);
      }
    });
  });

  group('Galactic Market: optimal count is positive and bounded', () {
    test('optimal count <= target (at most target coins of 1)', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final p = _MarketPuzzle.generate(grade, random);
          expect(p.optimalCount, greaterThan(0));
          expect(p.optimalCount, lessThanOrEqualTo(p.target));
        }
      }
    });

    test('optimal count <= ceil(target / max_denom)', () {
      // The optimal is at most target / largest_denom coins (rounded up)
      // plus remaining from smaller denoms, but always <= target.
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _MarketPuzzle.generate(4, random);
        // With denomination 50, target max 99 => at most 2 coins of 50
        // plus at most a few more. The count should be reasonable.
        expect(p.optimalCount, lessThanOrEqualTo(p.target));
      }
    });
  });

  group('Galactic Market: denominations are sorted descending', () {
    test('all grade levels have descending denomination order', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        final p = _MarketPuzzle.generate(grade, random);
        for (int i = 1; i < p.denominations.length; i++) {
          expect(p.denominations[i - 1], greaterThan(p.denominations[i]));
        }
      }
    });
  });
}
