import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/learning_round.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);
  LearningRound round(int days, double? value, {int difficulty = 1}) =>
      LearningRound(
          gameKey: 'star_forge',
          difficulty: difficulty,
          playedAt: now.subtract(Duration(days: days)),
          performance: value,
          successful: true);
  test('compares like-for-like weeks and reports the supporting sample', () {
    final trends = weeklyTrends([
      for (int i = 1; i <= 3; i++) round(i, 0.9),
      for (int i = 8; i <= 10; i++) round(i, 0.6),
      round(2, 0, difficulty: 2),
      round(1, null),
      round(30, 0.1),
      round(-1, 0.1),
    ], now);
    expect(trends, hasLength(1));
    expect(trends.single.change, closeTo(0.3, 0.001));
    expect(trends.single.recentAttempts, 3);
    expect(trends.single.previousAttempts, 3);
  });
  test('does not claim improvement with insufficient or unmeasured history',
      () {
    expect(
        weeklyTrends(
            [round(1, .9), round(2, .9), round(8, .3), round(9, null)], now),
        isEmpty);
  });
  test('does not compare different school skill levels', () {
    expect(
        weeklyTrends([
          for (int i = 1; i <= 3; i++) round(i, .9),
          for (int i = 8; i <= 10; i++)
            LearningRound(
                gameKey: 'star_forge',
                difficulty: 1,
                grade: 3,
                playedAt: now.subtract(Duration(days: i)),
                performance: .3,
                successful: true),
        ], now),
        isEmpty);
  });
}
