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
      }
    });
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
                      child: Text(
                        '∑ ${puzzle!.magicConstant}',
                        style: SpaceTheme.headlineStyle.copyWith(
                          fontSize: 18,
                          color: SpaceTheme.starYellow,
                        ),
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
                    painter: _StarLinePainter(
                      puzzle: puzzle!,
                      glowValue: glowAnimation.value,
                    ),
                    child: Stack(
                      children: _buildNodeWidgets(size),
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
    final center = Offset(areaSize / 2, areaSize / 2);
    final outerRadius = areaSize * 0.42;
    final innerRadius = areaSize * 0.2;
    final nodeSize = areaSize * 0.09;

    for (int i = 0; i < nodeCount; i++) {
      final pos = _getNodePosition(i, points, center, outerRadius, innerRadius);
      final isClue = puzzle!.clues.containsKey(i);
      final value = isClue ? puzzle!.clues[i] : userSolution[i];

      Widget nodeWidget;
      if (isClue) {
        nodeWidget = _buildClueNode(value!, nodeSize);
      } else if (userSolution.containsKey(i)) {
        nodeWidget = GestureDetector(
          onTap: () => _removeNumber(i),
          child: _buildFilledNode(value!, nodeSize, i == _lastDroppedNode),
        );
      } else {
        nodeWidget = _buildEmptyNode(i, nodeSize);
      }

      widgets.add(Positioned(
        left: pos.dx - nodeSize / 2,
        top: pos.dy - nodeSize / 2,
        child: nodeWidget,
      ));
    }

    return widgets;
  }

  Offset _getNodePosition(int idx, int points, Offset center, double outerR, double innerR) {
    final isOuter = idx < points;
    final angle = (idx < points ? idx : idx - points) * (2 * math.pi / points) - math.pi / 2;
    final radius = isOuter ? outerR : innerR;
    final adjustedAngle = isOuter ? angle : angle + math.pi / points;
    return Offset(
      center.dx + radius * math.cos(adjustedAngle),
      center.dy + radius * math.sin(adjustedAngle),
    );
  }

  Widget _buildClueNode(int value, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        ),
        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: size * 0.45),
        ),
      ),
    );
  }

  Widget _buildFilledNode(int value, double size, bool isLastDropped) {
    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SpaceTheme.starGradient,
        border: Border.all(color: SpaceTheme.starYellow, width: 2),
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

  Widget _buildEmptyNode(int nodeIdx, double size) {
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
              color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
              width: 2,
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

class _StarLinePainter extends CustomPainter {
  final StarForgePuzzle puzzle;
  final double glowValue;

  _StarLinePainter({required this.puzzle, required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.42;
    final innerR = size.width * 0.2;
    final points = puzzle.points;

    // Color-code each line so players can see which nodes belong together
    const lineColors = [
      Color(0xFFFF6B6B), // red
      Color(0xFF4ECDC4), // teal
      Color(0xFFFFD93D), // yellow
      Color(0xFF6BCB77), // green
      Color(0xFFBB86FC), // purple
      Color(0xFFFF9F43), // orange
      Color(0xFF45B7D1), // cyan
    ];

    for (int li = 0; li < puzzle.lines.length; li++) {
      final line = puzzle.lines[li];
      final lineColor = lineColors[li % lineColors.length];
      final paint = Paint()
        ..color = lineColor.withValues(alpha: 0.5 + 0.2 * glowValue)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < line.length - 1; i++) {
        final p1 = _getPos(line[i], points, center, outerR, innerR);
        final p2 = _getPos(line[i + 1], points, center, outerR, innerR);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  Offset _getPos(int idx, int pts, Offset center, double outerR, double innerR) {
    final isOuter = idx < pts;
    final angle = (idx < pts ? idx : idx - pts) * (2 * math.pi / pts) - math.pi / 2;
    final radius = isOuter ? outerR : innerR;
    final adjustedAngle = isOuter ? angle : angle + math.pi / pts;
    return Offset(
      center.dx + radius * math.cos(adjustedAngle),
      center.dy + radius * math.sin(adjustedAngle),
    );
  }

  @override
  bool shouldRepaint(covariant _StarLinePainter oldDelegate) =>
      oldDelegate.glowValue != glowValue;
}
