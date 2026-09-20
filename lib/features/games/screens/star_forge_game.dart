import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../../../core/services/debug_provider.dart';
import '../../../core/services/puzzle_evaluation_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/star_forge_logic.dart';
import '../widgets/star_forge_diagram.dart';
import '../../../shared/widgets/onboarding_overlay.dart';
import 'package:flutter/foundation.dart';

class StarForgeGame extends StatefulWidget {
  final int grade;
  final int level;
  const StarForgeGame({super.key, required this.grade, required this.level});

  @override
  State<StarForgeGame> createState() => _StarForgeGameState();
}

class _StarForgeGameState extends State<StarForgeGame>
    with TickerProviderStateMixin, GameAnimationsMixin<StarForgeGame> {
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  StarForgePuzzle? puzzle;
  Map<int, int> userSolution = {};
  bool _isGenerating = true;
  int _lastDroppedNode = -1;
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;

  /// Arm whose four nodes are lit up, set by tapping its total. Nothing else
  /// on the board says which nodes an arm covers, and the arms overlap, so
  /// being able to ask "show me this one" is what makes the target readable.
  int? _highlightedArm;

  /// Cells the player has to fill — a flawless solve places each exactly
  /// once, so it doubles as the optimal move count for the performance grade.
  int _optimalMoves = 0;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
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
    ];

    if (onlyIfUnseen) {
      OnboardingOverlay.maybeShow(
        context,
        gameKey: 'star_forge',
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
    _dropController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  int _getStarPoints() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 2) return 5;
    if (grade == 3) return 6;
    return 7;
  }

  int _getClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    final grade = currentDifficulty?.grade ?? widget.grade;
    final points = _getStarPoints();
    final nodeCount = points * 2;

    // Grade 1, level 1: reveal 80% (only 2 empty nodes on a 10-node star)
    // Progressively remove clues as grade and level increase
    double clueRatio;
    if (grade <= 1) {
      clueRatio = 0.80 - (level - 1) * 0.03; // 80% -> 62% over 6 levels
    } else if (grade <= 2) {
      clueRatio = 0.70 - (level - 1) * 0.03; // 70% -> 52%
    } else {
      clueRatio = 0.60 - (level - 1) * 0.02; // 60% -> 42%
    }
    final count = (nodeCount * clueRatio).round();
    return count.clamp(2, nodeCount - 2);
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userSolution.clear();
      _highlightedArm = null;
      successController.reset();
    });

    try {
      final generator = StarForgeGenerator();
      final p = await generator.generate(
        points: _getStarPoints(),
        clueCount: _getClueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;

          // Calculate max moves: 2x empty nodes (generous safety net)
          final emptyCount = p.emptyNodes.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) debugPrint('[StarForge] Max moves allowed: $_maxMoves for ${p.emptyNodes.length} empty nodes');
      }
    } catch (e) {
      debugPrint('[StarForge] Error generating puzzle: $e');
    }
  }

  void _placeNumber(int number, int nodeIdx) {
    setState(() {
      // Remove number from any other node that has it
      userSolution.removeWhere((k, v) => v == number);
      userSolution[nodeIdx] = number;
      _lastDroppedNode = nodeIdx;
      _dropController.forward(from: 0.0);

      // Decrement moves on placement
      _movesRemaining--;
      if (kDebugMode) debugPrint('[StarForge] Moves remaining: $_movesRemaining/$_maxMoves');
    });

    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyNodes.length) {
      _handleOutOfMoves();
      return;
    }

    _checkSolution();
  }

  void _removeNumber(int nodeIdx) {
    setState(() {
      userSolution.remove(nodeIdx);
    });
  }

  void _checkSolution() {
    if (userSolution.length != puzzle!.emptyNodes.length) return;

    if (puzzle!.validateSolution(userSolution)) {
      _handleWin();
    } else {
      _handleIncorrect();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'star_forge',
      difficulty: widget.level,
      score: totalScore,
        performance: Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),
    ));

    successController.forward(from: 0.0);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleIncorrect() {
    HapticFeedback.heavyImpact();
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
    if (kDebugMode) debugPrint('[StarForge] FAILURE - recording loss');
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'star_forge',
      difficulty: widget.level,
        progress: _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
    ));
  }

  void _handleOutOfMoves() {
    if (kDebugMode) debugPrint('[StarForge] Out of moves! Game over.');
    _handleFailure();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildOutOfMovesDialog(),
      );
    }
  }

  Widget _buildOutOfMovesDialog() {
    final s = S.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.starForgeOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.starForgeOutOfMovesDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.tryAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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
    Color indicatorColor;
    if (_movesRemaining <= 3) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (_movesRemaining <= 5) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.cosmicPink;
    }

    return Container(
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

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: s.starForgeTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton.icon(
                    onPressed: _showOnboarding,
                    icon: const Icon(Icons.help_outline,
                        size: 18, color: SpaceTheme.starYellow),
                    label: Text(
                      s.starForgeHowToPlay,
                      style: const TextStyle(
                          color: SpaceTheme.starYellow, fontSize: 13),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    // Show target sum prominently
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
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
                              color: SpaceTheme.starYellow
                                  .withValues(alpha: 0.85),
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
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.starYellow.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.starYellow.withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
                return SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: StarForgeOutlinePainter(
                      points: puzzle!.points,
                      highlightedArm: _highlightedArm,
                      glowValue: glowAnimation.value,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._buildArmBadges(size),
                        ..._buildNodeWidgets(size),
                      ],
                    ),
                  ),
                );
              },
            ),
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
        nodeWidget = GestureDetector(
          onTap: () => _removeNumber(i),
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
        left: pos.dx - 30,
        top: pos.dy - 15,
        width: 60,
        height: 30,
        child: Center(
          child: Semantics(
            label: '${s.starForgeArmTotal}: ${total.sum} / $target',
            button: true,
            child: GestureDetector(
              onTap: () => setState(
                  () => _highlightedArm = isLit ? null : arm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isLit
                      ? edge.withValues(alpha: 0.25)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: edge, width: isLit ? 2.5 : 1.5),
                ),
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
                          color: SpaceTheme.moonSilver
                              .withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
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
      node = ScaleTransition(scale: _dropAnimation, child: node);
    }
    return node;
  }

  Widget _buildEmptyNode(int nodeIdx, double size, bool lit) {
    return DragTarget<int>(
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
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _placeNumber(details.data, nodeIdx),
    );
  }

  Widget _buildNumberTray() {
    final pool = puzzle!.numberPool;
    final usedValues = userSolution.values.toSet();

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
          return Draggable<int>(
            data: n,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: SpaceTheme.starGradient,
                  boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20)],
                ),
                child: Center(child: Text(n.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 20))),
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
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.starForgeWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.starForgeWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  if (context.read<DebugProvider>().isDebugMenuEnabled)
                    DebugPuzzleRating(
                      gameType: 'star_forge',
                      puzzleId: 'sf_g${widget.grade}_l${widget.level}_${DateTime.now().millisecondsSinceEpoch}',
                      grade: widget.grade,
                      level: widget.level,
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
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
