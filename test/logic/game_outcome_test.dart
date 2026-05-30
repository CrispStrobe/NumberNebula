// Unit tests for GameOutcome (pure value type).
//
// GameOutcome is dependency-free: a const value holder plus three named
// factories that centralize the "what counts as success" decision. We test
// the factory semantics (win => wasSuccessful, loss => zero score + not
// successful, fromRatio => 70% pass mark with the total==0 guard) and that
// the attempted mathProblems list is preserved through each factory.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/game_outcome.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';

void main() {
  final problems = <MathProblem>[
    MathProblem.addition(2, 3),
    MathProblem.multiplication(4, 5),
  ];

  group('GameOutcome.win', () {
    test('marks success and keeps score + problems', () {
      final o = GameOutcome.win(
        gameType: 'asteroid',
        difficulty: 2,
        score: 150,
        mathProblems: problems,
      );
      expect(o.wasSuccessful, isTrue);
      expect(o.score, 150);
      expect(o.gameType, 'asteroid');
      expect(o.difficulty, 2);
      expect(o.mathProblems, same(problems));
    });
  });

  group('GameOutcome.loss', () {
    test('zeroes score, marks failure, still preserves problems', () {
      final o = GameOutcome.loss(
        gameType: 'asteroid',
        difficulty: 3,
        mathProblems: problems,
      );
      expect(o.wasSuccessful, isFalse);
      expect(o.score, 0);
      expect(o.difficulty, 3);
      expect(o.mathProblems, same(problems));
    });

    test('defaults to an empty problem list', () {
      final o = GameOutcome.loss(gameType: 'asteroid', difficulty: 1);
      expect(o.mathProblems, isEmpty);
    });
  });

  group('GameOutcome.fromRatio', () {
    GameOutcome ratio(int correct, int total, {double? threshold}) =>
        GameOutcome.fromRatio(
          gameType: 'quiz',
          difficulty: 1,
          score: 99,
          correct: correct,
          total: total,
          mathProblems: problems,
          passThreshold: threshold ?? 0.7,
        );

    test('7/10 passes at the default 0.7 threshold', () {
      final o = ratio(7, 10);
      expect(o.wasSuccessful, isTrue);
      // score is reported regardless of pass/fail
      expect(o.score, 99);
      expect(o.mathProblems, same(problems));
    });

    test('6/10 fails at the default 0.7 threshold', () {
      expect(ratio(6, 10).wasSuccessful, isFalse);
    });

    test('exactly meeting the threshold passes (>=)', () {
      // 0.7 boundary: at threshold should pass.
      expect(ratio(7, 10).wasSuccessful, isTrue);
    });

    test('total == 0 is never a success (guards divide-by-zero)', () {
      final o = ratio(0, 0);
      expect(o.wasSuccessful, isFalse);
    });

    test('honors a custom passThreshold', () {
      // 6/10 = 0.6, fails at 0.7 but passes at 0.5.
      expect(ratio(6, 10, threshold: 0.5).wasSuccessful, isTrue);
      expect(ratio(6, 10, threshold: 0.7).wasSuccessful, isFalse);
    });
  });
}
