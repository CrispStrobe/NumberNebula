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

class GameOutcome {
  final String gameType;
  final int difficulty;
  final int score;
  final bool wasSuccessful;
  final List<MathProblem> mathProblems;

  const GameOutcome({
    required this.gameType,
    required this.difficulty,
    required this.score,
    required this.wasSuccessful,
    this.mathProblems = const [],
  });

  /// Binary completion: player succeeded. Awards [score] points and reports
  /// any [mathProblems] the player attempted to SriService.
  factory GameOutcome.win({
    required String gameType,
    required int difficulty,
    required int score,
    List<MathProblem> mathProblems = const [],
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: score,
        wasSuccessful: true,
        mathProblems: mathProblems,
      );

  /// Binary completion: player failed. No score, but the attempted problems
  /// still report to SRI so the system knows which concepts the player
  /// struggled with.
  factory GameOutcome.loss({
    required String gameType,
    required int difficulty,
    List<MathProblem> mathProblems = const [],
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: 0,
        wasSuccessful: false,
        mathProblems: mathProblems,
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
  }) =>
      GameOutcome(
        gameType: gameType,
        difficulty: difficulty,
        score: score,
        wasSuccessful: total > 0 && (correct / total) >= passThreshold,
        mathProblems: mathProblems,
      );
}
