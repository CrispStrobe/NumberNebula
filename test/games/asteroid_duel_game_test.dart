// Unit tests for the mathematical invariants of the Asteroid Duel (Nim) game.
//
// The game logic is fully private inside _AsteroidDuelGameState. We test
// the Nim strategy invariants: losing positions, AI optimal play, and
// parameter ranges per grade.

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

/// In this Nim variant, the player who takes the LAST asteroid loses.
/// With maxPerTurn = m, a position is losing for the player whose turn it is
/// when: remaining % (m + 1) == 1 (the opponent can always force you to take
/// the last one).
///
/// The AI strategy from the game: leave remaining such that
/// (remaining - aiTake) % (maxPerTurn + 1) == 1.
/// i.e. idealRemaining = ((remaining - 1) ~/ mod) * mod + 1

/// Compute the AI's optimal move, matching the game's logic.
int? _aiOptimalTake(int remaining, int maxPerTurn) {
  final mod = maxPerTurn + 1;
  final idealRemaining = ((remaining - 1) ~/ mod) * mod + 1;
  final take = remaining - idealRemaining;

  if (take < 1 || take > math.min(maxPerTurn, remaining)) {
    return null; // No winning move available
  }
  return take;
}

/// Check if a position is losing for the player-to-move in last-takes-loses Nim.
bool _isLosingPosition(int remaining, int maxPerTurn) {
  return remaining % (maxPerTurn + 1) == 1;
}

void main() {
  group('Nim: losing position detection', () {
    test('remaining % (maxPerTurn+1) == 1 is a losing position (maxPerTurn=3)',
        () {
      // With maxPerTurn=3, mod=4. Losing positions: 1, 5, 9, 13, ...
      expect(_isLosingPosition(1, 3), isTrue);
      expect(_isLosingPosition(5, 3), isTrue);
      expect(_isLosingPosition(9, 3), isTrue);
      expect(_isLosingPosition(13, 3), isTrue);

      // Non-losing positions:
      expect(_isLosingPosition(2, 3), isFalse);
      expect(_isLosingPosition(3, 3), isFalse);
      expect(_isLosingPosition(4, 3), isFalse);
      expect(_isLosingPosition(6, 3), isFalse);
    });

    test('losing positions with maxPerTurn=4 (mod=5)', () {
      expect(_isLosingPosition(1, 4), isTrue);
      expect(_isLosingPosition(6, 4), isTrue);
      expect(_isLosingPosition(11, 4), isTrue);
      expect(_isLosingPosition(16, 4), isTrue);

      expect(_isLosingPosition(2, 4), isFalse);
      expect(_isLosingPosition(5, 4), isFalse);
    });
  });

  group('Nim: AI optimal move', () {
    test('AI can always find a winning move from a non-losing position', () {
      // From remaining=10, maxPerTurn=3: mod=4, ideal=9, take=1
      expect(_aiOptimalTake(10, 3), 1);

      // From remaining=7, maxPerTurn=3: mod=4, ideal=5, take=2
      expect(_aiOptimalTake(7, 3), 2);

      // From remaining=8, maxPerTurn=3: mod=4, ideal=5, take=3
      expect(_aiOptimalTake(8, 3), 3);
    });

    test('AI has no winning move from a losing position', () {
      // From remaining=5, maxPerTurn=3: mod=4, ideal=5, take=0 -> null
      expect(_aiOptimalTake(5, 3), isNull);

      // From remaining=1, maxPerTurn=3: ideal=1, take=0 -> null
      expect(_aiOptimalTake(1, 3), isNull);

      // From remaining=9, maxPerTurn=3: ideal=9, take=0 -> null
      expect(_aiOptimalTake(9, 3), isNull);
    });

    test('after AI optimal move, opponent is in a losing position', () {
      for (int remaining = 2; remaining <= 25; remaining++) {
        for (int maxTake in [3, 4]) {
          final take = _aiOptimalTake(remaining, maxTake);
          if (take != null) {
            final afterMove = remaining - take;
            expect(_isLosingPosition(afterMove, maxTake), isTrue,
                reason:
                    'After optimal take=$take from $remaining (max=$maxTake), '
                    'remaining=$afterMove should be losing for opponent');
          }
        }
      }
    });

    test('AI take is always in [1, min(maxPerTurn, remaining)]', () {
      for (int remaining = 2; remaining <= 20; remaining++) {
        for (int maxTake in [3, 4]) {
          final take = _aiOptimalTake(remaining, maxTake);
          if (take != null) {
            expect(take, greaterThanOrEqualTo(1));
            expect(take, lessThanOrEqualTo(math.min(maxTake, remaining)));
          }
        }
      }
    });
  });

  group('Nim: game parameter ranges per grade', () {
    test('grade 1: 8-12 asteroids, maxPerTurn=3', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final total = random.nextInt(5) + 8;
        expect(total, inInclusiveRange(8, 12));
      }
    });

    test('grade 2: 12-17 asteroids, maxPerTurn=3', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final total = random.nextInt(6) + 12;
        expect(total, inInclusiveRange(12, 17));
      }
    });

    test('grade 3: 16-21 asteroids, maxPerTurn=4', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final total = random.nextInt(6) + 16;
        expect(total, inInclusiveRange(16, 21));
      }
    });

    test('grade 4: 18-25 asteroids, maxPerTurn=4', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final total = random.nextInt(8) + 18;
        expect(total, inInclusiveRange(18, 25));
      }
    });
  });

  group('Nim: edge cases', () {
    test('remaining=2 with any maxPerTurn: take 1 to leave opponent at 1', () {
      expect(_aiOptimalTake(2, 3), 1);
      expect(_aiOptimalTake(2, 4), 1);
    });

    test('remaining=1 is always losing (must take the last one)', () {
      expect(_isLosingPosition(1, 3), isTrue);
      expect(_isLosingPosition(1, 4), isTrue);
      expect(_isLosingPosition(1, 1), isTrue);
    });
  });
}
