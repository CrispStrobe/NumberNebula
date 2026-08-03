// lib/features/games/models/performance.dart
//
// "How well did you play?" — a single normalized quality ratio in 0.0..1.0
// that every mini-game can report alongside its win/loss outcome.
//
// Raw scores are useless for comparison: they scale with grade and level and
// each game invents its own bonus formula. The performance ratio answers a
// different, comparable question: "what fraction of a perfect run was this?".
// 1.0 = flawless (first try, optimal moves, no mistakes), 0.0 = as bad as it
// gets. Missions grade tasks with it, so a sloppy win no longer looks the same
// as a perfect one.
//
// Games build the ratio with the [Perf] helpers below rather than inventing
// their own arithmetic, so "one mistake" costs roughly the same everywhere.

import 'dart:math' as math;

/// Grade buckets used for colour-coding results.
///
/// Thresholds (per product spec):
///   >= 85%  excellent (green)
///   >  70%  good      (yellow)
///   >  40%  fair      (orange)
///   else    poor      (red)
enum PerfGrade { excellent, good, fair, poor }

/// Lower bound of [PerfGrade.excellent].
const double kPerfExcellent = 0.85;

/// Exclusive lower bound of [PerfGrade.good].
const double kPerfGood = 0.70;

/// Exclusive lower bound of [PerfGrade.fair].
const double kPerfFair = 0.40;

/// Bucket a 0..1 performance ratio.
PerfGrade gradeForPerformance(double performance) {
  if (performance >= kPerfExcellent) return PerfGrade.excellent;
  if (performance > kPerfGood) return PerfGrade.good;
  if (performance > kPerfFair) return PerfGrade.fair;
  return PerfGrade.poor;
}

/// Performance ratio expressed as a whole percentage, for display.
int performancePercent(double performance) =>
    (performance.clamp(0.0, 1.0) * 100).round();

/// Builders for the normalized 0..1 performance ratio.
///
/// All helpers clamp their result, so callers can pass raw counters without
/// defensive checks.
class Perf {
  const Perf._();

  /// Perfect run — nothing tracked went wrong.
  static const double perfect = 1.0;

  /// Floor used for a completed-but-terrible run, so a finished game is never
  /// reported as literally zero effort.
  static const double failedFloor = 0.15;

  static double _clamp(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

  /// "Got [correct] of [total] right."
  static double fromRatio(int correct, int total) {
    if (total <= 0) return perfect;
    return _clamp(correct / total);
  }

  /// Solved after [attemptsUsed] attempts out of [maxAttempts] allowed
  /// (1 = solved on the first try).
  ///
  /// Linear from 1.0 on a first-try solve down towards 0 as the player burns
  /// through the allowance.
  static double fromAttempts(int attemptsUsed, int maxAttempts) {
    if (maxAttempts <= 1) return attemptsUsed <= 1 ? perfect : failedFloor;
    final wasted = math.max(0, attemptsUsed - 1);
    return _clamp(1.0 - wasted / maxAttempts);
  }

  /// [mistakes] wrong actions, each costing [per] of the score.
  ///
  /// The default of 0.2 means: flawless = 100%, one slip = 80% (yellow),
  /// two = 60% (orange), four = 20% (red). Games with many small steps should
  /// pass a smaller [per] (e.g. `1 / expectedSteps`).
  static double fromMistakes(int mistakes, {double per = 0.2}) {
    if (mistakes <= 0) return perfect;
    return _clamp(1.0 - mistakes * per);
  }

  /// Finished in [movesUsed] where [optimalMoves] was the best possible.
  ///
  /// Being at the optimum scores 1.0; every extra move costs [slope] / optimal.
  /// With the default slope, +25% moves ≈ 82%, +50% ≈ 65%, double ≈ 30%.
  static double fromMoves(int movesUsed, int optimalMoves,
      {double slope = 0.7}) {
    if (optimalMoves <= 0) return perfect;
    if (movesUsed <= optimalMoves) return perfect;
    return _clamp(1.0 - slope * (movesUsed - optimalMoves) / optimalMoves);
  }

  /// Finished in [secondsUsed] against a [parSeconds] target.
  ///
  /// Anything at or under par is perfect; overruns decay gently and never
  /// drop below [floor] so a slow-but-correct solve stays respectable.
  static double fromTime(int secondsUsed, int parSeconds, {double floor = 0.5}) {
    if (parSeconds <= 0) return perfect;
    if (secondsUsed <= parSeconds) return perfect;
    final over = (secondsUsed - parSeconds) / parSeconds;
    return _clamp(math.max(floor, 1.0 - 0.5 * over));
  }

  /// Fraction of lives/health remaining, where losing everything is a loss.
  ///
  /// Surviving untouched is perfect; every lost life is a visible dent but a
  /// win on the last life still lands above the "poor" band.
  static double fromLives(int livesLeft, int maxLives) {
    if (maxLives <= 0) return perfect;
    return _clamp(0.4 + 0.6 * (livesLeft / maxLives));
  }

  /// Weighted average of several partial signals.
  ///
  /// Use when a game has more than one meaningful quality dimension, e.g.
  /// accuracy and speed: `Perf.combine([acc, speed], weights: [2, 1])`.
  static double combine(List<double> parts, {List<double>? weights}) {
    if (parts.isEmpty) return perfect;
    if (weights == null || weights.length != parts.length) {
      return _clamp(parts.reduce((a, b) => a + b) / parts.length);
    }
    double sum = 0;
    double wsum = 0;
    for (int i = 0; i < parts.length; i++) {
      sum += parts[i].clamp(0.0, 1.0) * weights[i];
      wsum += weights[i];
    }
    if (wsum <= 0) return perfect;
    return _clamp(sum / wsum);
  }

  /// Apply hint/undo penalties to an otherwise computed ratio.
  static double penalize(double base, {int hints = 0, double perHint = 0.12}) {
    if (hints <= 0) return _clamp(base);
    return _clamp(base - hints * perHint);
  }

  /// Performance for a lost round. Games should still report *how far* the
  /// player got when they can ([progress] in 0..1); the result is capped well
  /// inside the "poor" band so a loss never reads as a good run.
  static double forLoss({double progress = 0.0}) =>
      _clamp(progress).clamp(0.0, kPerfFair * 0.75);
}
