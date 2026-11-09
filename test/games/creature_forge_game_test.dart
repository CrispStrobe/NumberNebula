// Unit tests for the mathematical invariants of the Creature Forge game.
//
// The game logic is fully private inside _CreatureForgeGameState.
// We reimplement the combinatorial formula and test that the answer is always
// heads * bodies * tails - forbiddenCombos, with part counts and constraint
// values in the expected ranges per grade.

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

class _CreatureForgePuzzle {
  final int headCount;
  final int bodyCount;
  final int tailCount;
  final int forbiddenCombos;
  final bool hasConstraints;
  final int correctAnswer;

  _CreatureForgePuzzle({
    required this.headCount,
    required this.bodyCount,
    required this.tailCount,
    required this.forbiddenCombos,
    required this.hasConstraints,
    required this.correctAnswer,
  });

  static _CreatureForgePuzzle generate(int grade, math.Random random) {
    int headCount, bodyCount, tailCount;
    int forbiddenCombos;
    bool hasConstraints;

    if (grade <= 2) {
      headCount = 2;
      bodyCount = 2;
      tailCount = 2;
      hasConstraints = false;
      forbiddenCombos = 0;
    } else if (grade == 3) {
      headCount = 3;
      bodyCount = 3;
      tailCount = 3;
      hasConstraints = true;
      forbiddenCombos = random.nextInt(3) + 2; // 2-4
    } else {
      headCount = 4;
      bodyCount = 4;
      tailCount = 4;
      hasConstraints = true;
      forbiddenCombos = random.nextInt(5) + 3; // 3-7
    }

    final correctAnswer =
        headCount * bodyCount * tailCount - forbiddenCombos;

    return _CreatureForgePuzzle(
      headCount: headCount,
      bodyCount: bodyCount,
      tailCount: tailCount,
      forbiddenCombos: forbiddenCombos,
      hasConstraints: hasConstraints,
      correctAnswer: correctAnswer,
    );
  }
}

void main() {
  group('Creature Forge: combination count formula', () {
    test('correctAnswer = heads * bodies * tails - forbidden', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final p = _CreatureForgePuzzle.generate(grade, random);
          expect(p.correctAnswer,
              p.headCount * p.bodyCount * p.tailCount - p.forbiddenCombos);
        }
      }
    });

    test('correctAnswer is always positive', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 5; i++) {
          final p = _CreatureForgePuzzle.generate(grade, random);
          expect(p.correctAnswer, greaterThan(0),
              reason: 'There must always be at least 1 valid creature');
        }
      }
    });
  });

  group('Creature Forge: grade 1-2 (no constraints)', () {
    test('part counts are all 2, no forbidden combos', () {
      final random = math.Random();
      for (int i = 0; i < 3; i++) {
        final p = _CreatureForgePuzzle.generate(1, random);
        expect(p.headCount, 2);
        expect(p.bodyCount, 2);
        expect(p.tailCount, 2);
        expect(p.forbiddenCombos, 0);
        expect(p.hasConstraints, isFalse);
        expect(p.correctAnswer, 8); // 2*2*2
      }
    });
  });

  group('Creature Forge: grade 3 (with constraints)', () {
    test('part counts are 3, forbidden in [2,4]', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _CreatureForgePuzzle.generate(3, random);
        expect(p.headCount, 3);
        expect(p.bodyCount, 3);
        expect(p.tailCount, 3);
        expect(p.hasConstraints, isTrue);
        expect(p.forbiddenCombos, inInclusiveRange(2, 4));
        // Total combos = 27, forbidden 2-4, so answer 23-25
        expect(p.correctAnswer, inInclusiveRange(23, 25));
      }
    });
  });

  group('Creature Forge: grade 4 (with constraints)', () {
    test('part counts are 4, forbidden in [3,7]', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _CreatureForgePuzzle.generate(4, random);
        expect(p.headCount, 4);
        expect(p.bodyCount, 4);
        expect(p.tailCount, 4);
        expect(p.hasConstraints, isTrue);
        expect(p.forbiddenCombos, inInclusiveRange(3, 7));
        // Total combos = 64, forbidden 3-7, so answer 57-61
        expect(p.correctAnswer, inInclusiveRange(57, 61));
      }
    });
  });

  group('Creature Forge: forbidden never exceeds total', () {
    test('forbidden < total combinations at all grades', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 5; i++) {
          final p = _CreatureForgePuzzle.generate(grade, random);
          final total = p.headCount * p.bodyCount * p.tailCount;
          expect(p.forbiddenCombos, lessThan(total));
        }
      }
    });
  });
}
