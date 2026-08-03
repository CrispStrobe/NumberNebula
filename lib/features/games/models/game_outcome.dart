// lib/features/games/models/game_outcome.dart
//
// Canonical end-of-level reporting payload. Replaces the named-parameter
// soup of the legacy GameProvider.recordLevelWin(...) signature with a
// single value type, and centralizes the "what counts as success" decision
// in named factories so callers don't reinvent thresholds.
//
// Use `GameOutcome.win` / `.loss` / `.fromRatio` instead of constructing
// the value directly, and report via `gameProvider.reportOutcome(...)`.

import '../tuning.dart';
import 'math_problem.dart';
import 'performance.dart';

class GameOutcome {
  final String gameType;
  final int difficulty;
  final int score;
  final bool wasSuccessful;
  final List<MathProblem> mathProblems;

  /// How well the round was played, normalized to 0.0..1.0 — "what fraction
  /// of a perfect run was this?". Independent of grade/level, so it can be
  /// compared across games and graded with [gradeForPerformance].
  ///
  /// Null means the game did not measure quality; consumers fall back to
  /// [effectivePerformance], which derives a coarse value from the outcome.
  /// Build it with the [Perf] helpers rather than hand-rolled arithmetic.
  final double? performance;

  const GameOutcome({
    required this.gameType,
    required this.difficulty,
    required this.score,
    required this.wasSuccessful,
    this.mathProblems = const [],
    this.performance,
  });

  /// Performance ratio with a fallback for games that don't report one.
  ///
  /// An unmeasured win sits at the bottom of the "excellent" band — it was, as
  /// far as we know, a clean solve — and an unmeasured loss lands in "poor".
  double get effectivePerformance {
    final p = performance;
    if (p != null) return p.clamp(0.0, 1.0);
    return wasSuccessful ? kPerfExcellent : Perf.forLoss();
  }

  PerfGrade get grade => gradeForPerformance(effectivePerformance);

  /// Binary completion: player succeeded. Awards [score] points and reports
  /// any [mathProblems] the player attempted to SriService.
  ///
  /// Pass [performance] (0..1, built with [Perf]) whenever the game knows how
  /// cleanly the round was played — mistakes, retries, moves over the optimum.
  factory GameOutcome.win({
    required String gameType,
    required int difficulty,
    required int score,
    List<MathProblem> mathProblems = const [],
    double? performance,
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: score,
        wasSuccessful: true,
        mathProblems: mathProblems,
        performance: performance,
      );

  /// Binary completion: player failed. No score, but the attempted problems
  /// still report to SRI so the system knows which concepts the player
  /// struggled with.
  ///
  /// [progress] (0..1) records how far the player got before failing; it is
  /// surfaced as a capped performance ratio so a near-miss reads better than
  /// giving up immediately.
  factory GameOutcome.loss({
    required String gameType,
    required int difficulty,
    List<MathProblem> mathProblems = const [],
    double progress = 0.0,
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: 0,
        wasSuccessful: false,
        mathProblems: mathProblems,
        performance: Perf.forLoss(progress: progress),
      );

  /// "Got [correct] of [total] right" with the canonical 70% pass mark.
  /// Use this for games where success is gradient, not binary.
  factory GameOutcome.fromRatio({
    required String gameType,
    required int difficulty,
    required int score,
    required int correct,
    required int total,
    List<MathProblem> mathProblems = const [],
    double passThreshold = kDefaultPassThreshold,
    double? performance,
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: score,
        wasSuccessful: total > 0 && (correct / total) >= passThreshold,
        mathProblems: mathProblems,
        performance: performance ?? Perf.fromRatio(correct, total),
      );
}
