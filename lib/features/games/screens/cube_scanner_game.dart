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

    // Check all answers are filled
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
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _puzzle!.diceCount,
                  itemBuilder: (context, index) => _buildDieCard(index),
                ),
              ),
              _buildCheckButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDieCard(int dieIndex) {
    final die = _puzzle!.dice[dieIndex];
    final visible = _puzzle!.visibleFaces[dieIndex];
    final question = _puzzle!.questions[dieIndex]!;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cube ${dieIndex + 1}',
                style: SpaceTheme.titleStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              // Show visible faces
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDieVisual(die, visible),
                ],
              ),
              const SizedBox(height: 12),
              // Show visible face values
              Wrap(
                spacing: 12,
                children: visible.visibleEntries.map((entry) {
                  return Chip(
                    label: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: SpaceTheme.nebulaPurple,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Question
              Text(
                'What is the $question face?',
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.cosmicPink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Answer buttons (1-6)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final value = i + 1;
                  final isSelected = _answers[dieIndex] == value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => _setAnswer(dieIndex, value),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SpaceTheme.starYellow
                              : SpaceTheme.deepSpace,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? SpaceTheme.starYellow
                                : SpaceTheme.nebulaPurple,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$value',
                            style: SpaceTheme.titleStyle.copyWith(
                              fontSize: 18,
                              color: isSelected
                                  ? SpaceTheme.deepSpace
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDieVisual(Die die, VisibleFaces visible) {
    // Simple isometric die rendering
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _DiePainter(
          die: die,
          visible: visible,
          glowValue: _glowAnimation.value,
        ),
      ),
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

class _DiePainter extends CustomPainter {
  final Die die;
  final VisibleFaces visible;
  final double glowValue;

  _DiePainter({
    required this.die,
    required this.visible,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.35;

    // Isometric offsets
    const dx = 0.5;
    const dy = 0.25;

    // Top face
    final topPath = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s * dx, cy - s * dy)
      ..lineTo(cx, cy + s * (1 - 2 * dy) - s)
      ..lineTo(cx - s * dx, cy - s * dy)
      ..close();

    // Front face (left)
    final frontPath = Path()
      ..moveTo(cx - s * dx, cy - s * dy)
      ..lineTo(cx, cy + s * (1 - 2 * dy) - s)
      ..lineTo(cx, cy + s * 0.3)
      ..lineTo(cx - s * dx, cy + s * 0.05)
      ..close();

    // Right face
    final rightPath = Path()
      ..moveTo(cx + s * dx, cy - s * dy)
      ..lineTo(cx, cy + s * (1 - 2 * dy) - s)
      ..lineTo(cx, cy + s * 0.3)
      ..lineTo(cx + s * dx, cy + s * 0.05)
      ..close();

    // Draw faces
    final topPaint = Paint()
      ..color = visible.top != null
          ? SpaceTheme.nebulaPurple
          : const Color(0xFF333355);
    final frontPaint = Paint()
      ..color = visible.front != null || visible.left != null
          ? SpaceTheme.nebulaPurple.withValues(alpha: 0.8)
          : const Color(0xFF222244);
    final rightPaint = Paint()
      ..color = visible.right != null
          ? SpaceTheme.nebulaPurple.withValues(alpha: 0.6)
          : const Color(0xFF1A1A3A);

    canvas.drawPath(topPath, topPaint);
    canvas.drawPath(frontPath, frontPaint);
    canvas.drawPath(rightPath, rightPaint);

    // Draw edges
    final edgePaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: glowValue * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(topPath, edgePaint);
    canvas.drawPath(frontPath, edgePaint);
    canvas.drawPath(rightPath, edgePaint);

    // Draw dots for visible faces
    final dotPaint = Paint()..color = Colors.white;
    if (visible.top != null) {
      _drawDots(canvas, cx, cy - s * 0.65, 14, visible.top!, dotPaint);
    }
    if (visible.front != null) {
      _drawDots(canvas, cx - s * dx * 0.5, cy - s * 0.05, 10, visible.front!, dotPaint);
    }
    if (visible.right != null) {
      _drawDots(canvas, cx + s * dx * 0.5, cy - s * 0.05, 10, visible.right!, dotPaint);
    }
  }

  void _drawDots(
      Canvas canvas, double cx, double cy, double faceSize, int value, Paint paint) {
    // Simplified: draw the value as text instead of dots for clarity
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: TextStyle(
          color: Colors.white,
          fontSize: faceSize * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DiePainter oldDelegate) =>
      oldDelegate.glowValue != glowValue;
}
