import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../game_registry.dart';
import '../providers/game_provider.dart';
import 'performance_badge.dart';

/// Displays evidence the game actually reported; an unmeasured win never
/// becomes a made-up accuracy percentage. Reused by every end-of-round dialog.
class RoundSummary extends StatelessWidget {
  final String gameKey;
  const RoundSummary({super.key, required this.gameKey});
  @override
  Widget build(BuildContext context) {
    final gp = context.read<GameProvider>();
    final outcome = gp.lastOutcome;
    if (outcome == null || outcome.gameType != gameKey) {
      return const SizedBox.shrink();
    }
    final s = S.of(context)!;
    final measured = outcome.performance != null;
    final retry = !outcome.wasSuccessful ||
        (measured && outcome.effectivePerformance < 0.70);
    // Challenge the same skill at the player's current unlocked level. The
    // retry suggestion keeps this round's level and reduces grade by one.
    final playedGrade = outcome.skillLevel ?? gp.effectiveGrade;
    final grade = retry ? (playedGrade - 1).clamp(1, 6) : playedGrade;
    final level = retry
        ? outcome.difficulty
        : gp.gameProgress[gameKey] ?? outcome.difficulty;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (outcome.wasSuccessful)
              Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      3,
                      (i) => Icon(
                          i < gp.lastStars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: SpaceTheme.starYellow,
                          size: 24))),
            if (measured)
              PerformanceBadge(
                  performance: outcome.effectivePerformance, showLabel: true)
            else
              Text(s.roundCompleted, style: SpaceTheme.bodyStyle),
            if (outcome.movesUsed != null)
              Text(
                  outcome.optimalMoves == null
                      ? s.roundMoves(outcome.movesUsed!)
                      : s.roundMovesAndTarget(
                          outcome.movesUsed!, outcome.optimalMoves!),
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center),
            if (outcome.hintsUsed != null)
              Text(s.roundHints(outcome.hintsUsed!),
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            if (outcome.mathProblems.isNotEmpty)
              Text(s.roundFactsPractised(outcome.mathProblems.length),
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            Text(retry ? s.roundTryGentler : s.roundNextSuggestion,
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            TextButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(s.roundSuggestedChallenge),
                onPressed: () {
                  final builder = gameBuilderFor(gameKey);
                  if (builder == null) return;
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.pushReplacement(
                      MaterialPageRoute(builder: (_) => builder(grade, level)));
                }),
          ],
        ));
  }
}

/// Scroll a large result card on phones while retaining its existing design.
class ScrollableRoundDialog extends Dialog {
  ScrollableRoundDialog(
      {super.key,
      required Widget child,
      super.backgroundColor,
      super.shape,
      super.insetPadding,
      super.alignment})
      : super(child: SingleChildScrollView(child: child));
}
