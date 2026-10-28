// lib/shared/widgets/onboarding_overlay.dart
//
// One-tap "how to play" overlay. Stack this on top of a game with
// [OnboardingOverlay.maybeShow(...)] inside initState. The widget
// shows once per game (keyed by gameKey, stored in SharedPreferences);
// subsequent runs no-op.
//
// Pass [steps] as a list of (icon, body) — typically 3 short cards. A step may
// also carry an [OnboardingStep.illustration]: a small diagram shown in place
// of the icon, for rules that are far easier to see than to read.

import 'package:flutter/material.dart';
import '../../core/services/profile_preferences.dart';

import '../../core/theme/space_theme.dart';
import '../../generated/l10n.dart';

class OnboardingStep {
  final IconData icon;
  final String body;

  /// A worked example drawn for this step. Shown instead of [icon] when given —
  /// some rules ("a taller tower hides the ones behind it") only land once the
  /// player has seen one.
  final Widget? illustration;

  final String? practiceBoard;
  final List<int> choices;
  final Map<int, String> choiceLabels;
  final bool substituteChoiceIntoBoard;
  final int? answer;
  final String? explanation;

  const OnboardingStep({
    required this.icon,
    required this.body,
    this.illustration,
    this.practiceBoard,
    this.choices = const [],
    this.choiceLabels = const {},
    this.substituteChoiceIntoBoard = true,
    this.answer,
    this.explanation,
  });
}

class OnboardingOverlay extends StatefulWidget {
  final String title;
  final List<OnboardingStep> steps;
  final VoidCallback onDismiss;

  const OnboardingOverlay({
    super.key,
    required this.title,
    required this.steps,
    required this.onDismiss,
  });

  static String _key(String gameKey) => 'onboarding_seen_$gameKey';

  /// Returns true iff the user has already dismissed the overlay for
  /// this game.
  static Future<bool> hasBeenSeen(String gameKey) async {
    final prefs = await ProfilePreferences.getInstance();
    return prefs.getBool(_key(gameKey)) ?? false;
  }

  /// Marks the overlay as seen for this game.
  static Future<void> markSeen(String gameKey) async {
    final prefs = await ProfilePreferences.getInstance();
    await prefs.setBool(_key(gameKey), true);
  }

  /// Convenience: from any StatefulWidget's `initState`, schedule a
  /// post-frame callback that pushes this overlay if and only if it
  /// hasn't been seen before. Marks it seen on dismiss.
  static void maybeShow(
    BuildContext context, {
    required String gameKey,
    required String title,
    required List<OnboardingStep> steps,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await hasBeenSeen(gameKey)) return;
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => OnboardingOverlay(
          title: title,
          steps: steps,
          onDismiss: () => Navigator.of(dialogContext).pop(),
        ),
      );
      await markSeen(gameKey);
    });
  }

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _index = 0;
  int? _choice;

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.steps.length - 1;
    final step = widget.steps[_index];
    // At large text sizes one labelled choice can be taller than the space
    // left between a pinned header and footer, so the whole card scrolls.
    final scrollWholeCard = MediaQuery.textScalerOf(context).scale(10) > 13;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: SpaceTheme.deepSpace,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: _scrollIf(scrollWholeCard, Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(widget.title,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
                    textAlign: TextAlign.center),
                TextButton(
                    onPressed: widget.onDismiss,
                    child: Text(S.of(context)!.skip,
                        style: const TextStyle(color: Colors.white60))),
              ],
            ),
            const SizedBox(height: 12),
            // Otherwise only the lesson scrolls, so the title, dots and Next
            // button stay on screen on a phone held sideways.
            _lessonViewport(scrollWholeCard,
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [SpaceTheme.nebulaPurple, SpaceTheme.spaceBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      (step.practiceBoard != null
                              ? Text(
                                  step.substituteChoiceIntoBoard
                                      ? step.practiceBoard!.replaceAll(
                                          '?',
                                          _choice?.toString() ?? '?',
                                        )
                                      : step.practiceBoard!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                  ),
                                )
                              : step.illustration) ??
                          Icon(step.icon, size: 48, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        step.body,
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (step.answer != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          alignment: WrapAlignment.center,
                          children: step.choices
                              .map(
                                (value) => OutlinedButton(
                                  onPressed: _choice == step.answer
                                      ? null
                                      : () => setState(() => _choice = value),
                                  child: Text(
                                    step.choiceLabels[value] ?? value.toString(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        if (_choice != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _choice == step.answer
                                  ? step.explanation!
                                  : S.of(context)!.guidedRetry,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < widget.steps.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? SpaceTheme.starYellow
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 4,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: step.answer != null && _choice != step.answer
                      ? null
                      : () {
                          if (isLast) {
                            widget.onDismiss();
                          } else {
                            setState(() {
                              _index++;
                              _choice = null;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.starYellow,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    isLast
                        ? S.of(context)!.onboardingGotIt
                        : S.of(context)!.onboardingNext,
                  ),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  static Widget _scrollIf(bool scroll, Widget child) =>
      scroll ? SingleChildScrollView(child: child) : child;

  static Widget _lessonViewport(bool scrollWholeCard, Widget lesson) =>
      scrollWholeCard
          ? lesson
          : Flexible(child: SingleChildScrollView(child: lesson));
}
