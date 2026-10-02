import 'game_outcome.dart';

class LearningRound {
  final String gameKey;
  final int difficulty;
  final int grade;
  final DateTime playedAt;
  final double? performance;
  final bool successful;
  const LearningRound(
      {required this.gameKey,
      required this.difficulty,
      required this.playedAt,
      required this.performance,
      required this.successful,
      this.grade = 1});
  factory LearningRound.fromOutcome(GameOutcome outcome, DateTime date,
          {required int grade}) =>
      LearningRound(
          gameKey: outcome.gameType,
          difficulty: outcome.difficulty,
          playedAt: date,
          performance: outcome.performance,
          successful: outcome.wasSuccessful,
          grade: grade);
  Map<String, dynamic> toJson() => {
        'game': gameKey,
        'difficulty': difficulty,
        'at': playedAt.toIso8601String(),
        'grade': grade,
        'performance': performance,
        'successful': successful
      };
  factory LearningRound.fromJson(Map<String, dynamic> json) => LearningRound(
      gameKey: json['game'] as String,
      difficulty: json['difficulty'] as int,
      grade: json['grade'] as int? ?? 0,
      playedAt: DateTime.parse(json['at'] as String),
      performance: (json['performance'] as num?)?.toDouble(),
      successful: json['successful'] as bool);
}

class LearningTrend {
  final String gameKey;
  final int difficulty;
  final int recentAttempts;
  final int previousAttempts;
  final double change;
  const LearningTrend(this.gameKey, this.difficulty, this.recentAttempts,
      this.previousAttempts, this.change);
}

/// Compare only the same game and difficulty, with at least three measured
/// rounds in each week. Scores and unknown performance are never averaged.
List<LearningTrend> weeklyTrends(List<LearningRound> rounds, DateTime now) {
  final start = now.subtract(const Duration(days: 7));
  final previousStart = now.subtract(const Duration(days: 14));
  final recent = <String, List<LearningRound>>{};
  final previous = <String, List<LearningRound>>{};
  for (final round in rounds) {
    if (round.performance == null ||
        round.playedAt.isAfter(now) ||
        round.playedAt.isBefore(previousStart)) {
      continue;
    }
    final key = '${round.gameKey}:${round.grade}:${round.difficulty}';
    final map = round.playedAt.isBefore(start) ? previous : recent;
    (map[key] ??= []).add(round);
  }
  final trends = <LearningTrend>[];
  for (final entry in recent.entries) {
    final before = previous[entry.key] ?? [];
    if (entry.value.length < 3 || before.length < 3) continue;
    double average(List<LearningRound> items) =>
        items.fold<double>(0, (sum, r) => sum + r.performance!) / items.length;
    final round = entry.value.first;
    trends.add(LearningTrend(
        round.gameKey,
        round.difficulty,
        entry.value.length,
        before.length,
        average(entry.value) - average(before)));
  }
  trends.sort((a, b) => b.change.compareTo(a.change));
  return trends;
}
