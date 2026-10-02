import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../shared/widgets/onboarding_overlay.dart';
import '../models/game_coaching.dart';
import '../services/board_hint_engine.dart';
import '../providers/game_provider.dart';
import 'strategy_hint_dialog.dart';

/// Read without subscribing in timer callbacks; a coach or backgrounded app
/// must never consume the player's remaining time or run an opponent turn.
class GamePauseController extends ChangeNotifier {
  Map<String, dynamic>? Function()? captureBoard;
  bool _paused = false;
  bool get paused => _paused;
  void setPaused(bool value) {
    if (value == _paused) return;
    _paused = value;
    notifyListeners();
  }

  Future<void> waitUntilResumed() async {
    while (_paused) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

class GamePauseScope extends InheritedWidget {
  final GamePauseController controller;
  const GamePauseScope(
      {super.key, required this.controller, required super.child});
  static GamePauseController? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GamePauseScope>()?.controller;
  static bool isPaused(BuildContext context) => of(context)?.paused ?? false;
  @override
  bool updateShouldNotify(GamePauseScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Gate first play until the practice question is complete or skipped. The
/// actual round is mounted afterwards, so generation and timers cannot race
/// onboarding. Replay and strategy hints remain reachable in the common bar.
class GameLearningShell extends StatefulWidget {
  final String gameKey;
  final WidgetBuilder builder;
  const GameLearningShell(
      {super.key, required this.gameKey, required this.builder});
  @override
  State<GameLearningShell> createState() => _GameLearningShellState();
}

class _GameLearningShellState extends State<GameLearningShell>
    with WidgetsBindingObserver {
  final _pause = GamePauseController();
  bool _ready = false;
  bool _coachOpen = false;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  String get _tutorialKey => '${widget.gameKey}_all_games_guided_v1';
  Future<void> _prepare() async {
    if (!await OnboardingOverlay.hasBeenSeen(_tutorialKey) && mounted) {
      await _tutorial();
    }
    if (!mounted) return;
    // Existing instruction overlays describe the same rules. The common
    // tutorial replaces their automatic first-open presentation, not help.
    await OnboardingOverlay.markSeen(widget.gameKey);
    await OnboardingOverlay.markSeen('${widget.gameKey}_guided_v1');
    if (!mounted) return;
    context.read<GameProvider>()
      ..coachingGameKey = widget.gameKey
      ..coachingHintsUsed = 0;
    setState(() => _ready = true);
  }

  bool get _german => Localizations.localeOf(context).languageCode == 'de';
  Future<void> _tutorial() async {
    final lesson = gameCoaching[widget.gameKey]!;
    _coachOpen = true;
    _pause.setPaused(true);
    try {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => OnboardingOverlay(
              title: S.of(context)!.guidedPractice,
              steps: [lesson.practice(_german)],
              onDismiss: () => Navigator.pop(dialogContext)));
      await OnboardingOverlay.markSeen(_tutorialKey);
    } finally {
      _coachOpen = false;
      _pause.setPaused(!_foreground);
    }
  }

  Future<void> _hint() async {
    if (_coachOpen) return;
    final lesson = gameCoaching[widget.gameKey]!;
    final gp = context.read<GameProvider>();
    gp.coachingHintsUsed = (gp.coachingHintsUsed ?? 0) + 1;
    _coachOpen = true;
    _pause.setPaused(true);
    try {
      final board = _pause.captureBoard?.call();
      final hint = board == null
          ? null
          : findBoardHint(widget.gameKey, board, german: _german);
      await StrategyHintDialog.show(context,
          focus: hint?.focus ?? (_german ? lesson.focusDe : lesson.focusEn),
          strategy: hint?.strategy ??
              (_german ? lesson.strategyDe : lesson.strategyEn),
          working:
              hint?.working ?? (_german ? lesson.workingDe : lesson.workingEn));
    } finally {
      _coachOpen = false;
      _pause.setPaused(!_foreground);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _pause.setPaused(_coachOpen || !_foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pause.setPaused(false);
    _pause.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = S.of(context)!;
    return GamePauseScope(
      controller: _pause,
      child: ColoredBox(
          color: const Color(0xFF090D24),
          child: SafeArea(
            child: Column(children: [
              SizedBox(
                  height: 40,
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(
                        onPressed: _tutorial,
                        icon: const Icon(Icons.school_outlined, size: 18),
                        label: Text(s.guidedPractice)),
                    TextButton.icon(
                        onPressed: _hint,
                        icon: const Icon(Icons.lightbulb_outline, size: 18),
                        label: Text(s.hintStrategy)),
                  ])),
              Expanded(
                  child: LayoutBuilder(
                      builder: (context, constraints) => MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                              size: Size(
                                  constraints.maxWidth, constraints.maxHeight),
                              padding: EdgeInsets.zero),
                          child: ListenableBuilder(
                              listenable: _pause,
                              builder: (context, _) => TickerMode(
                                  enabled: !_pause.paused,
                                  child: widget.builder(context)))))),
            ]),
          )),
    );
  }
}
