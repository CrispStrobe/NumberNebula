// Unit tests for the normalized performance ratio and its grade bands.
//
// The product rule these lock down: >=85% green (excellent), >70% yellow
// (good), >40% orange (fair), below that red (poor).

import 'package:flutter_test/flutter_test.dart';

import 'package:space_math_academy/features/games/models/game_outcome.dart';
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/tuning.dart';

void main() {
  group('gradeForPerformance bands', () {
    test('85% and above is excellent', () {
      expect(gradeForPerformance(1.0), PerfGrade.excellent);
      expect(gradeForPerformance(0.85), PerfGrade.excellent);
    });

    test('above 70% up to 85% is good', () {
      expect(gradeForPerformance(0.8499), PerfGrade.good);
      expect(gradeForPerformance(0.71), PerfGrade.good);
    });

    test('above 40% up to 70% is fair', () {
      expect(gradeForPerformance(0.70), PerfGrade.fair);
      expect(gradeForPerformance(0.41), PerfGrade.fair);
    });

    test('40% and below is poor', () {
      expect(gradeForPerformance(0.40), PerfGrade.poor);
      expect(gradeForPerformance(0.0), PerfGrade.poor);
    });
  });

  group('Perf builders', () {
    test('fromRatio is the plain accuracy, clamped', () {
      expect(Perf.fromRatio(3, 4), closeTo(0.75, 1e-9));
      expect(Perf.fromRatio(0, 0), 1.0); // nothing to get wrong
      expect(Perf.fromRatio(5, 4), 1.0);
      expect(Perf.fromRatio(-1, 4), 0.0);
    });

    test('fromAttempts rewards a first-try solve and decays', () {
      expect(Perf.fromAttempts(1, 5), 1.0);
      expect(Perf.fromAttempts(2, 5), closeTo(0.8, 1e-9));
      expect(Perf.fromAttempts(5, 5), closeTo(0.2, 1e-9));
      expect(gradeForPerformance(Perf.fromAttempts(2, 5)), PerfGrade.good);
    });

    test('fromMistakes costs a fifth of the score per slip by default', () {
      expect(Perf.fromMistakes(0), 1.0);
      expect(Perf.fromMistakes(1), closeTo(0.8, 1e-9));
      expect(Perf.fromMistakes(3), closeTo(0.4, 1e-9));
      expect(Perf.fromMistakes(99), 0.0);
      expect(Perf.fromMistakes(-2), 1.0);
    });

    test('fromMoves is perfect at or under the optimum', () {
      expect(Perf.fromMoves(10, 10), 1.0);
      expect(Perf.fromMoves(8, 10), 1.0);
      expect(Perf.fromMoves(15, 10), closeTo(0.65, 1e-9));
      expect(Perf.fromMoves(20, 10), closeTo(0.3, 1e-9));
      expect(Perf.fromMoves(5, 0), 1.0); // unknown optimum -> no penalty
    });

    test('fromTime is perfect within par and never bottoms out', () {
      expect(Perf.fromTime(30, 60), 1.0);
      expect(Perf.fromTime(90, 60), closeTo(0.75, 1e-9));
      expect(Perf.fromTime(600, 60), 0.5); // floor
    });

    test('fromLives keeps a last-life win out of the red', () {
      expect(Perf.fromLives(3, 3), 1.0);
      expect(Perf.fromLives(1, 3), closeTo(0.6, 1e-9));
      expect(gradeForPerformance(Perf.fromLives(1, 3)), PerfGrade.fair);
    });

    test('combine averages, optionally weighted', () {
      expect(Perf.combine([1.0, 0.5]), closeTo(0.75, 1e-9));
      expect(Perf.combine([1.0, 0.4], weights: [3, 1]), closeTo(0.85, 1e-9));
      expect(Perf.combine([]), 1.0);
    });

    test('penalize deducts per hint', () {
      expect(Perf.penalize(1.0, hints: 2, perHint: 0.1), closeTo(0.8, 1e-9));
      expect(Perf.penalize(0.5), 0.5);
    });

    test('forLoss never escapes the poor band', () {
      expect(gradeForPerformance(Perf.forLoss()), PerfGrade.poor);
      expect(gradeForPerformance(Perf.forLoss(progress: 1.0)), PerfGrade.poor);
      expect(Perf.forLoss(progress: 0.5), lessThanOrEqualTo(kPerfFair));
    });
  });

  group('GameOutcome performance', () {
    test('reported performance is used verbatim', () {
      final outcome = GameOutcome.win(
        gameType: 'kenken',
        difficulty: 3,
        score: 500,
        performance: 0.62,
      );
      expect(outcome.effectivePerformance, closeTo(0.62, 1e-9));
      expect(outcome.grade, PerfGrade.fair);
    });

    test('an unmeasured win falls back to the bottom of green', () {
      final outcome =
          GameOutcome.win(gameType: 'kenken', difficulty: 3, score: 500);
      expect(outcome.performance, isNull);
      expect(outcome.effectivePerformance, kPerfExcellent);
      expect(outcome.grade, PerfGrade.excellent);
    });

    test('a loss is graded poor regardless of how far the player got', () {
      final outcome = GameOutcome.loss(
        gameType: 'kenken',
        difficulty: 3,
        progress: 0.9,
      );
      expect(outcome.grade, PerfGrade.poor);
    });

    test('fromRatio derives performance from the ratio', () {
      final outcome = GameOutcome.fromRatio(
        gameType: 'kenken',
        difficulty: 3,
        score: 100,
        correct: 9,
        total: 10,
      );
      expect(outcome.effectivePerformance, closeTo(0.9, 1e-9));
      expect(outcome.wasSuccessful, isTrue);
    });
  });

  group('starsForPerformance', () {
    test('mirrors the grade bands', () {
      expect(starsForPerformance(1.0), 3);
      expect(starsForPerformance(0.85), 3);
      expect(starsForPerformance(0.8), 2);
      expect(starsForPerformance(0.71), 2);
      expect(starsForPerformance(0.7), 1);
      expect(starsForPerformance(0.1), 1);
    });
  });
}
