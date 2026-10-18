import '../services/generation_configs.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';
import '../mixins/puzzle_session_mixin.dart';

import '../../../core/services/debug_provider.dart';
import '../../../core/services/puzzle_evaluation_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/strategy_hint_dialog.dart';
import '../services/hint_completion_solver.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/star_forge_logic.dart';
import '../widgets/star_forge_diagram.dart';
import '../../../shared/widgets/onboarding_overlay.dart';
import 'package:flutter/foundation.dart';

typedef StarForgeDrag = ({int number, Object round});

class StarForgeGame extends StatefulWidget {
  final int grade;
  final int level;
  const StarForgeGame({super.key, required this.grade, required this.level});

  @override
  State<StarForgeGame> createState() => _StarForgeGameState();
}

class _StarForgeGameState extends State<StarForgeGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<StarForgeGame>,
        PuzzleSessionMixin<StarForgeGame> {
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  StarForgePuzzle? puzzle;
  Map<int, int> userSolution = {};
  bool _isGenerating = true;
  int _lastDroppedNode = -1;
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;
  int _hintsUsed = 0;
  bool _hintLoading = false;

  /// Arm whose four nodes are lit up, set by tapping its total. Nothing else
  /// on the board says which nodes an arm covers, and the arms overlap, so
  /// being able to ask "show me this one" is what makes the target readable.
  int? _highlightedArm;

  /// Cells the player has to fill — a flawless solve places each exactly
  /// once, so it doubles as the optimal move count for the performance grade.
  int _optimalMoves = 0;

  Object _round = Object();
  VoidCallback _backForRound() {
    final round = _round;
    return () {
      if (mounted &&
          identical(round, _round) &&
          !_isGenerating &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    };
  }

  bool _won = false;
  bool _outOfMoves = false;
  bool _reducedMotion = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      !_outOfMoves &&
      puzzle != null;

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    cancelOneShotMotion(_dropController);
    _clearFeedback();
  }

  void _clearFeedback() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  bool _isSolved() =>
      puzzle != null &&
      userSolution.length == puzzle!.emptyNodes.length &&
      puzzle!.validateSolution(userSolution);

  @visibleForTesting
  Object get testRound => _round;

  @visibleForTesting
  void rebuildForTesting() => setState(() {});

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    _reducedMotion = reduced;
    updateOneShotMotion(_dropController, reduced,
        duration: const Duration(milliseconds: 500));
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @override
  String get sessionGameKey => 'star_forge';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (puzzle == null || _isGenerating || _won || _outOfMoves) {
      return null;
    }
    return {
      'puzzle': puzzle!.toJson(),
      'answers': userSolution.map((k, v) => MapEntry(k.toString(), v)),
      'moves': _movesRemaining,
      'maxMoves': _maxMoves,
      'optimal': _optimalMoves,
      'hints': _hintsUsed,
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle = StarForgePuzzle.fromJson(
        Map<String, dynamic>.from(state['puzzle'] as Map));
    userSolution = Map<String, dynamic>.from(state['answers'] as Map)
        .map((k, v) => MapEntry(int.parse(k), v as int));
    _movesRemaining = state['moves'] as int;
    _maxMoves = state['maxMoves'] as int;
    _optimalMoves = state['optimal'] as int;
    _hintsUsed = state['hints'] as int? ?? 0;
    _isGenerating = false;
    _won = false;
    _outOfMoves = false;
    _lastDroppedNode = -1;
    _highlightedArm = null;
    _hintLoading = false;
    // Older saves may contain a fully solved or exhausted board. Treat them as
    // terminal so they offer retry without replaying rewards.
    final solved = _isSolved();
    final exhausted = !solved && _movesRemaining <= 0;
    if (solved || exhausted) {
      _won = solved;
      _outOfMoves = exhausted;
      finishPuzzleSession();
      final round = _round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(round, _round) || _isGenerating) {
          return;
        }
        if (solved && _won) {
          _showWinDialog(_winScore(), round);
        } else if (exhausted && _outOfMoves) {
          _showOutOfMovesDialog(round);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      _generatePuzzle();
    }
  }

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level,
            gradeOverride: widget.grade);
        await _restoreOrGenerate();
        if (!mounted) {
          return;
        }
        _showOnboarding(onlyIfUnseen: true);
      }
    });
  }

  /// The walkthrough. Shown once on a player's first visit and again from the
  /// help button.
  ///
  /// "Each line through the star must have the same sum" was the whole of the
  /// old explanation, and it was wrong twice over: nothing on the board was a
  /// line a player could trace, and the sentence never said what a line was
  /// made of or that neighbouring ones share nodes. All four steps here are
  /// drawn on a solved 5-point star, so every claim is one the player can
  /// check by counting.
  void _showOnboarding({bool onlyIfUnseen = false}) {
    final s = S.of(context)!;
    final steps = [
      OnboardingStep(
        icon: Icons.hub,
        body: s.starForgeOnboardArm,
        illustration: const StarForgeArmDiagram(),
      ),
      OnboardingStep(
        icon: Icons.join_inner,
        body: s.starForgeOnboardOverlap,
        illustration: const StarForgeOverlapDiagram(),
      ),
      OnboardingStep(
        icon: Icons.auto_awesome,
        body: s.starForgeOnboardGoal,
        illustration: const StarForgeGoalDiagram(),
      ),
      OnboardingStep(
        icon: Icons.touch_app,
        body: s.starForgeOnboardPlace,
      ),
      OnboardingStep(
        icon: Icons.touch_app,
        body: s.guidedStarPrompt,
        practiceBoard: '8 + ? + 1 + 9 = 22',
        choices: const [3, 4, 5],
        answer: 4,
        explanation: s.guidedStarReason,
      ),
    ];

    if (onlyIfUnseen) {
      OnboardingOverlay.maybeShow(
        context,
        gameKey: 'star_forge_guided_v1',
        title: s.starForgeTitle,
        steps: steps,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => OnboardingOverlay(
        title: s.starForgeTitle,
        steps: steps,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  /// What the arm at [armIdx] currently adds up to, and whether all four of
  /// its nodes are filled. Clues and placed numbers count alike.
  ({int sum, bool complete}) _armTotal(int armIdx) {
    final line = puzzle!.lines[armIdx];
    int sum = 0;
    bool complete = true;
    for (final nodeIdx in line) {
      final v = puzzle!.clues[nodeIdx] ?? userSolution[nodeIdx];
      if (v == null) {
        complete = false;
      } else {
        sum += v;
      }
    }
    return (sum: sum, complete: complete);
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _round = Object();
    cancelOneShotMotion(successController);
    cancelOneShotMotion(_dropController);
    _dropController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  int _getStarPoints() => StarForgeGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getStarPoints();

  int _getClueCount() => StarForgeGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getClueCount();

  void _generatePuzzle() async {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    setState(() {
      _isGenerating = true;
      _won = false;
      _outOfMoves = false;
      _hintsUsed = 0;
      _hintLoading = false;
      _lastDroppedNode = -1;
      userSolution.clear();
      _highlightedArm = null;
      successController.reset();
      _dropController.reset();
    });

    try {
      final generator = StarForgeGenerator();
      final p = await generator.generate(
        points: _getStarPoints(),
        clueCount: _getClueCount(),
      );

      if (mounted && identical(round, _round)) {
        setState(() {
          puzzle = p;

          // Calculate max moves: 2x empty nodes (generous safety net)
          final emptyCount = p.emptyNodes.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) {
          debugPrint(
              '[StarForge] Max moves allowed: $_maxMoves for ${p.emptyNodes.length} empty nodes');
        }
      }
    } catch (e) {
      if (mounted && identical(round, _round)) {
        if (kDebugMode) {
          debugPrint('[StarForge] Error generating puzzle: $e');
        }
      }
    }
  }

  Future<void> _showStrategyHint() async {
    final round = _round;
    if (_hintLoading || puzzleSessionFinished) {
      return;
    }
    final p = puzzle;
    if (p == null) {
      return;
    }
    final missing =
        p.emptyNodes.where((i) => !userSolution.containsKey(i)).toList();
    if (missing.isEmpty) {
      return;
    }
    final node = missing.first;
    final arm = p.lines.indexWhere((line) => line.contains(node));
    setState(() {
      _highlightedArm = arm;
      _hintsUsed++;
    });
    final s = S.of(context)!;
    final initial = Map<int, int>.from(userSolution);
    _hintLoading = true;
    final completion = await compute(findHintCompletion, {
      'values':
          {...p.clues, ...initial}.map((k, v) => MapEntry(k.toString(), v)),
      'domains': {for (final i in p.emptyNodes) i.toString(): p.numberPool},
      'groups': [List.generate(p.nodeCount, (i) => i.toString())],
      'equations': p.lines
          .map((line) => {
                'cells': line.map((i) => i.toString()).toList(),
                'op': 'sum',
                'target': p.magicConstant
              })
          .toList(),
      'pool': p.numberPool,
    });
    if (!mounted || !identical(round, _round)) {
      return;
    }
    _hintLoading = false;
    if (mounted) {
      setState(() {});
    }
    if (!mounted ||
        !identical(p, puzzle) ||
        !mapEquals(initial, userSolution)) {
      return;
    }
    final compatible = completion != null;
    final value = completion?[node.toString()];
    final line = p.lines[arm];
    final equation =
        '${line.map((i) => completion?[i.toString()]).join(' + ')} = ${p.magicConstant}';
    StrategyHintDialog.show(context,
        focus: s.hintStarFocus,
        strategy: s.hintStarStrategy,
        working: compatible
            ? '$equation\n${s.hintPossibleMove(value!)}'
            : s.hintCheckPlacements,
        demonstrate: compatible
            ? () {
                if (mounted) {
                  _placeNumber(value!, node, round);
                }
              }
            : null);
  }

  void _placeNumber(int number, int nodeIdx, Object round) {
    if (_movesRemaining <= 0 ||
        !_canInteract(round) ||
        puzzle!.clues.containsKey(nodeIdx) ||
        !puzzle!.emptyNodes.contains(nodeIdx) ||
        !puzzle!.numberPool.contains(number)) {
      return;
    }
    // Prevent duplicate reporting after win/outOfMoves
    if (_won || _outOfMoves) {
      return;
    }
    setState(() {
      // Remove number from any other node that has it
      userSolution.removeWhere((k, v) => v == number);
      userSolution[nodeIdx] = number;
      _lastDroppedNode = nodeIdx;
      _movesRemaining--;
      if (kDebugMode) {
        debugPrint('[StarForge] Moves remaining: $_movesRemaining/$_maxMoves');
      }
    });
    _dropController.forward(from: 0.0);
    playOneShotMotion(_dropController, () {});

    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && !_isSolved()) {
      _handleOutOfMoves();
      return;
    }

    _checkSolution();
  }

  void _removeNumber(int nodeIdx, int? expected, Object round) {
    if (!_canInteract(round) ||
        !puzzle!.emptyNodes.contains(nodeIdx) ||
        expected == null ||
        userSolution[nodeIdx] != expected) {
      return;
    }
    setState(() {
      userSolution.remove(nodeIdx);
    });
  }

  void _checkSolution() {
    if (!_canInteract(_round)) {
      return;
    }
    if (userSolution.length != puzzle!.emptyNodes.length) {
      return;
    }

    if (puzzle!.validateSolution(userSolution)) {
      _handleWin();
    } else {
      _handleIncorrect();
    }
  }

  int _winScore() => 100 * widget.grade + widget.level * 25;

  void _handleWin() {
    if (!_canInteract(_round) || !_isSolved()) {
      return;
    }
    _resetRoundEffects();
    setState(() => _won = true);
    final round = _round;
    finishPuzzleSession();
    AppHaptics.lightImpact();
    final totalScore = _winScore();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'star_forge',
          difficulty: widget.level,
          score: totalScore,
          performance: Perf.penalize(
              Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),
              hints: _hintsUsed),
          hintsUsed: _hintsUsed,
          movesUsed: _maxMoves - _movesRemaining,
          optimalMoves: _optimalMoves,
        ));

    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int score, Object round) {
    if (!mounted || !identical(round, _round) || !_won || puzzle == null) {
      return;
    }
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildWinDialog(score, round, dialogContext),
    );
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      (_won || _outOfMoves) &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  void _handleIncorrect() {
    if (!_canInteract(_round)) {
      return;
    }
    AppHaptics.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.starForgeLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleFailure() {
    if (kDebugMode) {
      debugPrint('[StarForge] FAILURE - recording loss');
    }
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'star_forge',
          difficulty: widget.level,
          progress:
              _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
        ));
  }

  void _handleOutOfMoves() {
    if (_outOfMoves || _won) {
      return;
    }
    if (!_canInteract(_round)) {
      return;
    }
    _resetRoundEffects();
    setState(() => _outOfMoves = true);
    final round = _round;
    finishPuzzleSession();
    if (kDebugMode) {
      debugPrint('[StarForge] Out of moves! Game over.');
    }
    _handleFailure();
    _showOutOfMovesDialog(round);
  }

  void _showOutOfMovesDialog(Object round) {
    if (!mounted ||
        !identical(round, _round) ||
        !_outOfMoves ||
        puzzle == null) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildOutOfMovesDialog(round, dialogContext),
    );
  }

  Widget _buildOutOfMovesDialog(Object round, BuildContext dialogContext) {
    final s = S.of(context)!;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundSummary(gameKey: 'star_forge'),
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.starForgeOutOfMoves,
              style: SpaceTheme.headlineStyle
                  .copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.starForgeOutOfMovesDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              overflowAlignment: OverflowBarAlignment.center,
              spacing: 16,
              overflowSpacing: 12,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    if (!_canUseDialog(round, dialogContext)) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.tryAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_canUseDialog(round, dialogContext)) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(s.backToMenu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovesIndicator() {
    // Colour by the moves to spare, not the raw count: a level with two empty
    // nodes has only four moves, and the old fixed thresholds showed that in
    // alarm red from the first frame -- and turned it redder with every
    // correct placement. Red now means no room left for a mistake.
    final stillEmpty = (puzzle?.emptyNodes.length ?? 0) - userSolution.length;
    final spare = _movesRemaining - stillEmpty;
    Color indicatorColor;
    if (spare <= 0) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (spare == 1) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.cosmicPink;
    }

    final label = S.of(context)!.starForgeMovesLeft(_movesRemaining);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: indicatorColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: indicatorColor, size: 18),
              const SizedBox(width: 6),
              Text(
                '$_movesRemaining',
                style: SpaceTheme.titleStyle.copyWith(
                  fontSize: 14,
                  color: indicatorColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(s.loadingAdventure, style: SpaceTheme.bodyStyle),
              ],
            ),
          ),
        ),
      );
    }

    final round = _round;
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                key: ValueKey(('star-header', round)),
                title: s.starForgeTitle,
                level: widget.level,
                onBack: _backForRound(),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                    child: TextButton.icon(
                        onPressed: _hintLoading ? null : _showStrategyHint,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(s.strategyHint))),
                Flexible(
                    child: TextButton.icon(
                        onPressed: _showOnboarding,
                        icon: const Icon(Icons.help_outline),
                        label: Text(s.howToPlay))),
              ]),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        s.starForgeInstructions,
                        style: SpaceTheme.bodyStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                SpaceTheme.starYellow.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.starForgeTarget.toUpperCase(),
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: 9,
                              height: 1.0,
                              letterSpacing: 1.2,
                              color:
                                  SpaceTheme.starYellow.withValues(alpha: 0.85),
                            ),
                          ),
                          Text(
                            '${puzzle!.magicConstant}',
                            style: SpaceTheme.headlineStyle.copyWith(
                              fontSize: 18,
                              height: 1.1,
                              color: SpaceTheme.starYellow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMovesIndicator(),
                  ],
                ),
              ),
              Expanded(child: _buildStarArea()),
              _buildNumberTray(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarArea() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = (constraints.biggest.shortestSide - 32)
              .clamp(0.0, double.infinity);
          final size = available * 0.9;
          final board = SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ..._buildArmBadges(size),
                ..._buildNodeWidgets(size),
              ],
            ),
          );
          return AnimatedBuilder(
            animation: glowAnimation,
            child: board,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.starYellow
                          .withValues(alpha: 0.1 * glowAnimation.value),
                      SpaceTheme.deepSpace.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SpaceTheme.starYellow
                        .withValues(alpha: glowAnimation.value),
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: StarForgeOutlinePainter(
                    points: puzzle!.points,
                    highlightedArm: _highlightedArm,
                    glowValue: glowAnimation.value,
                  ),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildNodeWidgets(double areaSize) {
    final widgets = <Widget>[];
    final points = puzzle!.points;
    final nodeCount = puzzle!.nodeCount;
    final nodeSize = areaSize * 0.09;

    // Nodes that belong to the arm the player asked to see.
    final litNodes = _highlightedArm == null
        ? const <int>{}
        : puzzle!.lines[_highlightedArm!].toSet();

    for (int i = 0; i < nodeCount; i++) {
      final pos = StarForgeGeometry.nodeCenter(i, points, areaSize);
      final isClue = puzzle!.clues.containsKey(i);
      final value = isClue ? puzzle!.clues[i] : userSolution[i];
      final lit = litNodes.contains(i);

      Widget nodeWidget;
      if (isClue) {
        nodeWidget = _buildClueNode(value!, nodeSize, lit);
      } else if (userSolution.containsKey(i)) {
        final round = _round;
        final expected = userSolution[i];
        nodeWidget = GestureDetector(
          key: ValueKey(('star-filled', round, i)),
          onTap: () => _removeNumber(i, expected, round),
          child: _buildFilledNode(value!, nodeSize, i == _lastDroppedNode, lit),
        );
      } else {
        nodeWidget = _buildEmptyNode(i, nodeSize, lit);
      }

      widgets.add(Positioned(
        left: pos.dx - nodeSize / 2,
        top: pos.dy - nodeSize / 2,
        child: nodeWidget,
      ));
    }

    return widgets;
  }

  /// One badge per arm, sitting outside the middle of the four nodes it
  /// covers: what that arm adds up to right now, against the target.
  ///
  /// This is the feedback the game had none of. Before, a board was either
  /// accepted or rejected wholesale once the last number went down, with no
  /// way to tell which arm was wrong or how far off it was.
  List<Widget> _buildArmBadges(double areaSize) {
    final s = S.of(context)!;
    final points = puzzle!.points;
    final target = puzzle!.magicConstant;
    final badges = <Widget>[];

    for (int arm = 0; arm < puzzle!.lines.length; arm++) {
      final pos = StarForgeGeometry.armBadgeCenter(arm, points, areaSize);
      final total = _armTotal(arm);
      final armColor = starArmColors[arm % starArmColors.length];
      final isLit = _highlightedArm == arm;

      final Color edge;
      final IconData? mark;
      if (!total.complete) {
        edge = armColor;
        mark = null;
      } else if (total.sum == target) {
        edge = SpaceTheme.alienGreen;
        mark = Icons.check;
      } else {
        edge = SpaceTheme.rocketRed;
        mark = Icons.close;
      }

      badges.add(Positioned(
        key: ValueKey(('star-badge', _round, arm)),
        left: pos.dx - 30,
        top: pos.dy - 15,
        width: 60,
        height: 30,
        child: Center(
          child: Semantics(
            label: '${s.starForgeArmTotal}: ${total.sum} / $target',
            button: true,
            child: GestureDetector(
              onTap: () {
                if (!mounted || _isGenerating) {
                  return;
                }
                setState(() => _highlightedArm = isLit ? null : arm);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isLit
                      ? edge.withValues(alpha: 0.25)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: edge, width: isLit ? 2.5 : 1.5),
                ),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${total.sum}',
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 13,
                            height: 1.0,
                            fontWeight: FontWeight.bold,
                            color: edge,
                          ),
                        ),
                        if (mark != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(mark, size: 12, color: edge),
                          )
                        else
                          Text(
                            '/$target',
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: 10,
                              height: 1.0,
                              color:
                                  SpaceTheme.moonSilver.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    )),
              ),
            ),
          ),
        ),
      ));
    }

    return badges;
  }

  Widget _buildClueNode(int value, double size, bool lit) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        ),
        border: Border.all(
            color: lit ? Colors.white : SpaceTheme.alienGreen,
            width: lit ? 3 : 2),
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: size * 0.45),
        ),
      ),
    );
  }

  Widget _buildFilledNode(
      int value, double size, bool isLastDropped, bool lit) {
    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SpaceTheme.starGradient,
        border: Border.all(
            color: lit ? Colors.white : SpaceTheme.starYellow,
            width: lit ? 3 : 2),
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: size * 0.45),
        ),
      ),
    );

    if (isLastDropped) {
      // Reduced motion makes the drop immediate; animation still completes via one-shot helper.
      if (_reducedMotion) {
        return node;
      }
      return ScaleTransition(scale: _dropAnimation, child: node);
    }
    return node;
  }

  Widget _buildEmptyNode(int nodeIdx, double size, bool lit) {
    final round = _round;
    return DragTarget<StarForgeDrag>(
      key: ValueKey(('star-target', round, nodeIdx)),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHovering
                ? SpaceTheme.starYellow.withValues(alpha: 0.5)
                : SpaceTheme.deepSpace.withValues(alpha: 0.8),
            border: Border.all(
              color: isHovering
                  ? SpaceTheme.starYellow
                  : lit
                      ? Colors.white
                      : SpaceTheme.nebulaPurple,
              width: lit ? 3 : 2,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              color: SpaceTheme.nebulaPurple,
              size: size * 0.4,
            ),
          ),
        );
      },
      onWillAcceptWithDetails: (details) =>
          _canInteract(details.data.round) && details.data.round == round,
      onAcceptWithDetails: (details) {
        if (!identical(details.data.round, round)) {
          return;
        }
        _placeNumber(details.data.number, nodeIdx, round);
      },
    );
  }

  Widget _buildNumberTray() {
    final pool = puzzle!.numberPool;
    final usedValues = userSolution.values.toSet();

    final round = _round;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: pool.map((n) {
          final isUsed = usedValues.contains(n);
          return Draggable<StarForgeDrag>(
            key: ValueKey(('star-drag', round, n)),
            data: (number: n, round: round),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: SpaceTheme.starGradient,
                  boxShadow: [
                    BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                        blurRadius: 20)
                  ],
                ),
                child: Center(
                    child: Text(n.toString(),
                        style:
                            SpaceTheme.headlineStyle.copyWith(fontSize: 20))),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildTrayNumber(n, false),
            ),
            child: Opacity(
              opacity: isUsed ? 0.3 : 1.0,
              child: _buildTrayNumber(n, isUsed),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrayNumber(int number, bool isUsed) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score, Object round, BuildContext dialogContext) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: ScrollableRoundDialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundSummary(gameKey: 'star_forge'),
                  const Icon(Icons.auto_awesome,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.starForgeWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.starForgeWinDesc(score),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  if (context.read<DebugProvider>().isDebugMenuEnabled)
                    DebugPuzzleRating(
                      gameType: 'star_forge',
                      puzzleId:
                          'sf_g${widget.grade}_l${widget.level}_${DateTime.now().millisecondsSinceEpoch}',
                      grade: widget.grade,
                      level: widget.level,
                    ),
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    overflowAlignment: OverflowBarAlignment.center,
                    spacing: 16,
                    overflowSpacing: 12,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(s.backToMenu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
