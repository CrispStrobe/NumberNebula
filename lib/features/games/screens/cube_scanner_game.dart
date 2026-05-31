import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/cube_scanner_logic.dart';

class CubeScannerGame extends StatefulWidget {
  final int grade;
  final int level;
  const CubeScannerGame({super.key, required this.grade, required this.level});
  @override
  State<CubeScannerGame> createState() => _CubeScannerGameState();
}

class _CubeScannerGameState extends State<CubeScannerGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  CubeScannerPuzzle? _puzzle;
  final Map<int, int?> _answers = {};
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

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
    _glowController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _answers.clear();
      _successController.reset();
    });

    final generator =
        CubeScannerGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      for (final key in puzzle.questions.keys) {
        _answers[key] = null;
      }
      _isGenerating = false;
    });
  }

  void _setAnswer(int dieIndex, int value) {
    setState(() {
      _answers[dieIndex] = value;
    });
  }

  void _checkSolution() {
    if (_puzzle == null) return;

    if (_answers.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.cubeScannerLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    bool allCorrect = true;
    for (final entry in _puzzle!.correctAnswers.entries) {
      if (_answers[entry.key] != entry.value) {
        allCorrect = false;
        break;
      }
    }

    if (allCorrect) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int diceBonus = _puzzle!.diceCount * 75;
    int totalScore = baseScore + levelBonus + diceBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'cube_scanner',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore),
    );
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'cube_scanner',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.cubeScannerLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (_puzzle == null || _isGenerating) {
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
                title: s.cubeScannerTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.cubeScannerInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 650;
                    if (isWide) {
                      return _buildWideLayout(constraints);
                    }
                    return _buildTallLayout(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dice visuals on the left
          Expanded(
            flex: 5,
            child: _buildDiceColumn(constraints.maxHeight - 24),
          ),
          const SizedBox(width: 16),
          // Check button on the right
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCheckButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTallLayout(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          child: _buildDiceColumn(constraints.maxHeight * 0.85),
        ),
        _buildCheckButton(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDiceColumn(double maxHeight) {
    final dieCount = _puzzle!.diceCount;
    // Divide available height among dice
    final perDieHeight = (maxHeight / dieCount).clamp(180.0, 400.0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: dieCount,
      itemBuilder: (context, index) => _buildDieCard(index, perDieHeight),
    );
  }

  Widget _buildDieCard(int dieIndex, double cardHeight) {
    final die = _puzzle!.dice[dieIndex];
    final visible = _puzzle!.visibleFaces[dieIndex];
    final question = _puzzle!.questions[dieIndex]!;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Size the cube to fill ~60% of the card width
              final cubeSize = (constraints.maxWidth * 0.55).clamp(140.0, 300.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with cube title and visible face chips
                  Row(
                    children: [
                      Text(
                        'Cube ${dieIndex + 1}',
                        style: SpaceTheme.titleStyle.copyWith(
                          color: SpaceTheme.starYellow,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      ...visible.visibleEntries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: SpaceTheme.nebulaPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Cube wireframe visual
                  SizedBox(
                    width: cubeSize,
                    height: cubeSize,
                    child: CustomPaint(
                      painter: _WireframeDiePainter(
                        die: die,
                        visible: visible,
                        glowValue: _glowAnimation.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Question
                  Text(
                    'What is the $question face?',
                    style: SpaceTheme.bodyStyle.copyWith(
                      color: SpaceTheme.cosmicPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Answer buttons - larger
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(6, (i) {
                      final value = i + 1;
                      final isSelected = _answers[dieIndex] == value;
                      return GestureDetector(
                        onTap: () => _setAnswer(dieIndex, value),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SpaceTheme.starYellow
                                : SpaceTheme.deepSpace,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? SpaceTheme.starYellow
                                  : SpaceTheme.nebulaPurple,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$value',
                              style: SpaceTheme.titleStyle.copyWith(
                                fontSize: 22,
                                color: isSelected
                                    ? SpaceTheme.deepSpace
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCheckButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _checkSolution,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(S.of(context)!.cubeScannerWinTitle),
          style: SpaceTheme.primaryButtonStyle,
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.cubeScannerWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.cubeScannerWinDesc(score),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(S.of(context)!.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.backToMenu),
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

/// Wireframe/edge-glow isometric die painter.
/// Draws cube edges as bright colored lines on a dark background with glow.
class _WireframeDiePainter extends CustomPainter {
  final Die die;
  final VisibleFaces visible;
  final double glowValue;

  _WireframeDiePainter({
    required this.die,
    required this.visible,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Scale the cube to fill ~60% of the available space
    final s = math.min(size.width, size.height) * 0.38;

    // Isometric projection factors
    const dxFactor = 0.866; // cos(30deg)
    const dyFactor = 0.5;   // sin(30deg)

    // 8 vertices of an isometric cube centered at (cx, cy)
    // Top face 4 corners, bottom face 4 corners
    final topCenter = Offset(cx, cy - s * 0.6);
    final topLeft = Offset(cx - s * dxFactor, cy - s * 0.6 + s * dyFactor);
    final topRight = Offset(cx + s * dxFactor, cy - s * 0.6 + s * dyFactor);
    final topFront = Offset(cx, cy - s * 0.6 + s * dyFactor * 2);

    final bottomCenter = Offset(cx, cy + s * 0.6);
    final bottomLeft = Offset(cx - s * dxFactor, cy + s * 0.6 - s * dyFactor);
    final bottomRight = Offset(cx + s * dxFactor, cy + s * 0.6 - s * dyFactor);

    // Face paths
    final topFace = Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();

    final leftFace = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    final rightFace = Path()
      ..moveTo(topRight.dx, topRight.dy)
      ..lineTo(topFront.dx, topFront.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();

    // Dark fill for faces (subtle differentiation)
    final topFill = Paint()..color = const Color(0xFF1A1A3A);
    final leftFill = Paint()..color = const Color(0xFF151530);
    final rightFill = Paint()..color = const Color(0xFF101028);

    canvas.drawPath(topFace, topFill);
    canvas.drawPath(leftFace, leftFill);
    canvas.drawPath(rightFace, rightFill);

    // Glow edge paint
    final glowColor = Color.lerp(
      SpaceTheme.nebulaPurple,
      SpaceTheme.starYellow,
      glowValue * 0.6,
    )!;

    // Outer glow (wider, transparent)
    final outerGlow = Paint()
      ..color = glowColor.withValues(alpha: glowValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(topFace, outerGlow);
    canvas.drawPath(leftFace, outerGlow);
    canvas.drawPath(rightFace, outerGlow);

    // Inner edge (sharp, bright)
    final edgePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.7 + glowValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(topFace, edgePaint);
    canvas.drawPath(leftFace, edgePaint);
    canvas.drawPath(rightFace, edgePaint);

    // Draw face values as text
    final topCenterPt = Offset(
      (topCenter.dx + topRight.dx + topFront.dx + topLeft.dx) / 4,
      (topCenter.dy + topRight.dy + topFront.dy + topLeft.dy) / 4,
    );
    final leftCenterPt = Offset(
      (topLeft.dx + topFront.dx + bottomCenter.dx + bottomLeft.dx) / 4,
      (topLeft.dy + topFront.dy + bottomCenter.dy + bottomLeft.dy) / 4,
    );
    final rightCenterPt = Offset(
      (topRight.dx + topFront.dx + bottomCenter.dx + bottomRight.dx) / 4,
      (topRight.dy + topFront.dy + bottomCenter.dy + bottomRight.dy) / 4,
    );

    final fontSize = s * 0.35;

    if (visible.top != null) {
      _drawFaceValue(canvas, topCenterPt, visible.top!, fontSize, Colors.white);
    }
    // Left face shows front or left value
    final leftVal = visible.front ?? visible.left;
    if (leftVal != null) {
      _drawFaceValue(canvas, leftCenterPt, leftVal, fontSize * 0.85, Colors.white70);
    }
    if (visible.right != null) {
      _drawFaceValue(canvas, rightCenterPt, visible.right!, fontSize * 0.85, Colors.white70);
    }
  }

  void _drawFaceValue(Canvas canvas, Offset center, int value, double fontSize, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: SpaceTheme.starYellow.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _WireframeDiePainter oldDelegate) =>
      oldDelegate.glowValue != glowValue;
}
