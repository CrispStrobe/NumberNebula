import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/cube_scanner_logic.dart';
import '../widgets/cube_scanner_diagram.dart';
import '../../../shared/widgets/onboarding_overlay.dart';

class CubeScannerGame extends StatefulWidget {
  final int grade;
  final int level;
  const CubeScannerGame({super.key, required this.grade, required this.level});
  @override
  State<CubeScannerGame> createState() => _CubeScannerGameState();
}

class _CubeScannerGameState extends State<CubeScannerGame>
    with TickerProviderStateMixin, GameAnimationsMixin<CubeScannerGame> {
  // ---------------------------------------------------------------------------
  // Animation controllers (per VISUAL_TEMPLATE.md)
  // ---------------------------------------------------------------------------
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  // ---------------------------------------------------------------------------
  // Puzzle state
  // ---------------------------------------------------------------------------
  CubeScannerPuzzle? _puzzle;
  int? _selectedAnswer;
  bool _isGenerating = true;
  bool _showResult = false;

  /// Wrong faces picked before the right one.
  int _wrongAnswers = 0;
  bool _resultCorrect = false;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

    // Glow (continuous, for borders/accents)

    // Feedback flash (one-shot, for correct/wrong flash)
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
        _showOnboarding();
      }
    });
  }

  /// Show how a die is put together, before asking the player to reason about
  /// one. Two facts make this puzzle solvable and the board shows neither:
  /// that opposite faces sum to seven, and that the faces you cannot see are
  /// exactly the ones opposite the faces you can.
  void _showOnboarding() {
    final s = S.of(context)!;
    OnboardingOverlay.maybeShow(
      context,
      gameKey: 'cube_scanner',
      title: s.cubeScannerOnboardTitle,
      steps: [
        OnboardingStep(
          icon: Icons.casino,
          body: s.cubeScannerOnboardRule,
          illustration: const DieOppositePairsDiagram(),
        ),
        OnboardingStep(
          icon: Icons.visibility_off,
          body: s.cubeScannerOnboardHidden,
          illustration: DieHiddenFacesDiagram(
            scannedLabel: s.cubeScannerScanned,
            hiddenLabel: s.cubeScannerHidden,
          ),
        ),
        OnboardingStep(
          icon: Icons.functions,
          body: s.cubeScannerOnboardTotal,
          illustration: const DieTotalPipsDiagram(),
        ),
        OnboardingStep(
          icon: Icons.keyboard,
          body: s.cubeScannerOnboardAnswer,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Puzzle generation
  // ---------------------------------------------------------------------------
  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _wrongAnswers = 0;
      _selectedAnswer = null;
      _showResult = false;
      _resultCorrect = false;
      successController.reset();
      _feedbackController.reset();
    });

    final generator =
        CubeScannerGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _isGenerating = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------
  void _selectAnswer(int value) {
    if (_showResult) return;
    setState(() {
      // Toggle: tap again to deselect
      _selectedAnswer = (_selectedAnswer == value) ? null : value;
    });
  }

  void _submitAnswer() {
    if (_puzzle == null || _selectedAnswer == null || _showResult) return;

    final correct = _selectedAnswer == _puzzle!.correctAnswer;
    setState(() {
      _showResult = true;
      _resultCorrect = correct;
    });
    _feedbackController.forward(from: 0.0);

    if (correct) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    final baseScore = 100 * widget.grade;
    final levelBonus = widget.level * 25;
    final diceBonus = _puzzle!.diceCount * 75;
    final totalScore = baseScore + levelBonus + diceBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'cube_scanner',
      difficulty: widget.level,
      score: totalScore,
      performance: Perf.fromMistakes(_wrongAnswers, per: 0.25),
    ));

    // Delay to let the green flash show, then show dialog
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      successController.forward(from: 0.0);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalScore),
      );
    });
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    _wrongAnswers++;
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'cube_scanner',
      difficulty: widget.level,
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? _buildWideLayout(constraints)
                        : _buildCompactLayout(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Layouts (per VISUAL_TEMPLATE.md)
  // ---------------------------------------------------------------------------
  Widget _buildWideLayout(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Center(child: _buildDiceArea(constraints)),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: _buildQuestionAndChoices(constraints),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(child: _buildDiceArea(constraints)),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: _buildQuestionAndChoices(constraints),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dice area: draws the isometric die/dice
  // ---------------------------------------------------------------------------
  Widget _buildDiceArea(BoxConstraints constraints) {
    final puzzle = _puzzle!;
    return LayoutBuilder(
      builder: (context, innerConstraints) {
        if (puzzle.arrangement == DiceArrangement.single) {
          return _buildSingleDie(innerConstraints);
        } else if (puzzle.arrangement == DiceArrangement.verticalStack) {
          return _buildStackedDice(innerConstraints);
        } else {
          return _buildRowDice(innerConstraints);
        }
      },
    );
  }

  Widget _buildSingleDie(BoxConstraints constraints) {
    final cubeSize = math.min(
      constraints.maxWidth * 0.7,
      constraints.maxHeight * 0.8,
    ).clamp(200.0, 400.0);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return SizedBox(
          width: cubeSize,
          height: cubeSize,
          child: CustomPaint(
            painter: _IsometricDiePainter(
              die: _puzzle!.dice[0],
              visible: _puzzle!.visibleFaces[0],
              glowValue: glowAnimation.value,
              label: null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedDice(BoxConstraints constraints) {
    // Two dice stacked vertically
    final cubeSize = math.min(
      constraints.maxWidth * 0.5,
      constraints.maxHeight * 0.38,
    ).clamp(120.0, 250.0);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Die 1 (top)
            SizedBox(
              width: cubeSize,
              height: cubeSize,
              child: CustomPaint(
                painter: _IsometricDiePainter(
                  die: _puzzle!.dice[0],
                  visible: _puzzle!.visibleFaces[0],
                  glowValue: glowAnimation.value,
                  label: '1',
                ),
              ),
            ),
            // Connecting indicator
            Container(
              width: 3,
              height: 8,
              decoration: BoxDecoration(
                color: SpaceTheme.starYellow.withValues(alpha: glowAnimation.value),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            // Die 2 (bottom)
            SizedBox(
              width: cubeSize,
              height: cubeSize,
              child: CustomPaint(
                painter: _IsometricDiePainter(
                  die: _puzzle!.dice[1],
                  visible: _puzzle!.visibleFaces[1],
                  glowValue: glowAnimation.value,
                  label: '2',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRowDice(BoxConstraints constraints) {
    final diceCount = _puzzle!.diceCount;
    final cubeSize = math.min(
      (constraints.maxWidth - 40) / diceCount,
      constraints.maxHeight * 0.7,
    ).clamp(100.0, 200.0);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        final children = <Widget>[];
        for (int i = 0; i < diceCount; i++) {
          if (i > 0) {
            // Connecting indicator between dice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow
                      .withValues(alpha: glowAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            );
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: SpaceTheme.starYellow
                        .withValues(alpha: glowAnimation.value),
                  ),
                ),
              ),
            );
          }
          children.add(
            SizedBox(
              width: cubeSize,
              height: cubeSize,
              child: CustomPaint(
                painter: _IsometricDiePainter(
                  die: _puzzle!.dice[i],
                  visible: _puzzle!.visibleFaces[i],
                  glowValue: glowAnimation.value,
                  label: '${i + 1}',
                ),
              ),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Question + multiple choice
  // ---------------------------------------------------------------------------
  Widget _buildQuestionAndChoices(BoxConstraints constraints) {
    final puzzle = _puzzle!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Question text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SpaceTheme.nebulaPurple.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              _questionText(puzzle.question),
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.cosmicPink,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          // Hint text
          Text(
            S.of(context)!.cubeScannerInstructions,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Multiple choice buttons (A-E)
          Expanded(
            child: _buildChoiceButtons(puzzle),
          ),
          // Submit button
          if (!_showResult || !_resultCorrect) ...[
            const SizedBox(height: 8),
            _buildActionButton(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceButtons(CubeScannerPuzzle puzzle) {
    const labels = ['A', 'B', 'C', 'D', 'E'];
    return AnimatedBuilder(
      animation: _feedbackAnimation,
      builder: (context, _) {
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: List.generate(puzzle.choices.length, (i) {
            final value = puzzle.choices[i];
            final isSelected = _selectedAnswer == value;
            final label = i < labels.length ? labels[i] : '${i + 1}';

            // Determine button color based on state
            Color bgColor;
            Color borderColor;
            Color textColor;

            if (_showResult) {
              if (value == puzzle.correctAnswer) {
                // Correct answer: green
                final flash = _feedbackAnimation.value;
                bgColor = SpaceTheme.alienGreen.withValues(alpha: 0.3 + flash * 0.5);
                borderColor = SpaceTheme.alienGreen;
                textColor = SpaceTheme.alienGreen;
              } else if (isSelected && !_resultCorrect) {
                // Wrong selection: red
                final flash = _feedbackAnimation.value;
                bgColor = SpaceTheme.rocketRed.withValues(alpha: 0.3 + flash * 0.3);
                borderColor = SpaceTheme.rocketRed;
                textColor = SpaceTheme.rocketRed;
              } else {
                bgColor = SpaceTheme.deepSpace;
                borderColor = SpaceTheme.nebulaPurple.withValues(alpha: 0.4);
                textColor = Colors.white38;
              }
            } else if (isSelected) {
              bgColor = SpaceTheme.starYellow;
              borderColor = SpaceTheme.starYellow;
              textColor = SpaceTheme.deepSpace;
            } else {
              bgColor = SpaceTheme.deepSpace;
              borderColor = SpaceTheme.nebulaPurple;
              textColor = Colors.white;
            }

            return GestureDetector(
              onTap: () => _selectAnswer(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: isSelected && !_showResult
                      ? [
                          BoxShadow(
                            color: SpaceTheme.starYellow.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$value',
                      style: SpaceTheme.titleStyle.copyWith(
                        fontSize: 22,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Question text
  // ---------------------------------------------------------------------------

  /// The puzzle carries its question as data, so the wording lives here and
  /// goes through the normal localization.
  String _faceName(CubeFace face) {
    final s = S.of(context)!;
    return switch (face) {
      CubeFace.top => s.cubeScannerFaceTop,
      CubeFace.front => s.cubeScannerFaceFront,
      CubeFace.right => s.cubeScannerFaceRight,
      CubeFace.left => s.cubeScannerFaceLeft,
      CubeFace.back => s.cubeScannerFaceBack,
      CubeFace.bottom => s.cubeScannerFaceBottom,
    };
  }

  String _rollName(CubeRoll roll) {
    final s = S.of(context)!;
    return switch (roll) {
      CubeRoll.forward => s.cubeScannerRollForward,
      CubeRoll.backward => s.cubeScannerRollBackward,
      CubeRoll.left => s.cubeScannerRollLeft,
      CubeRoll.right => s.cubeScannerRollRight,
    };
  }

  String _questionText(CubeScannerQuestion q) {
    final s = S.of(context)!;
    switch (q.kind) {
      case CubeQuestionKind.hiddenFace:
        return s.cubeScannerQHiddenFace(_faceName(q.face!));
      case CubeQuestionKind.hiddenFaceSum:
        return s.cubeScannerQHiddenFaceSum;
      case CubeQuestionKind.rollToFace:
        final rolls =
            q.rolls.map(_rollName).join(s.cubeScannerRollJoin);
        return s.cubeScannerQRoll(rolls, _faceName(q.face!));
      case CubeQuestionKind.hiddenPips:
        return _puzzle!.arrangement == DiceArrangement.verticalStack
            ? s.cubeScannerQHiddenPipsStack
            : s.cubeScannerQHiddenPipsRow;
    }
  }

  Widget _buildActionButton() {
    if (_showResult && !_resultCorrect) {
      // After wrong answer: show "Try Again" to regenerate
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _generatePuzzle,
          icon: const Icon(Icons.refresh),
          label: Text(S.of(context)!.playAgain),
          style: SpaceTheme.secondaryButtonStyle,
        ),
      );
    }

    // Normal submit
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedAnswer != null ? _submitAnswer : null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(S.of(context)!.cubeScannerWinTitle),
        style: SpaceTheme.primaryButtonStyle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Win dialog
  // ---------------------------------------------------------------------------
  Widget _buildWinDialog(int score) {
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
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.cubeScannerWinTitle,
                    style: SpaceTheme.headlineStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.cubeScannerWinDesc(score),
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

// =============================================================================
// Isometric die painter
// =============================================================================
/// Draws a single isometric die with 3 visible faces (top, left-front, right-front).
/// Wireframe edges with glow, face values as big numbers.
/// Face shading: top = lighter, left = medium, right = darker.
class _IsometricDiePainter extends CustomPainter {
  final Die die;
  final VisibleFaces visible;
  final double glowValue;
  final String? label;

  _IsometricDiePainter({
    required this.die,
    required this.visible,
    required this.glowValue,
    this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Isometric projection angles
    const dxFactor = 0.866; // cos(30deg)
    const dyFactor = 0.5; // sin(30deg)

    // Compute scale s so the cube fits within the widget.
    // True isometric cube: width = 2 * s * dxFactor, height = 2 * s.
    // Fit to both dimensions with margin.
    final sFromWidth = (size.width * 0.85) / (2 * dxFactor);
    final sFromHeight = (size.height * 0.85) / 2.0;
    final s = math.min(sFromWidth, sFromHeight);

    // 7 visible vertices of a proper isometric cube (height = 2s, width = 2s*cos30)
    final topCenter = Offset(cx, cy - s);
    final topLeft = Offset(cx - s * dxFactor, cy - s + s * dyFactor);
    final topRight = Offset(cx + s * dxFactor, cy - s + s * dyFactor);
    final topFront = Offset(cx, cy - s + s * dyFactor * 2);
    final bottomCenter = Offset(cx, cy + s);
    final bottomLeft = Offset(cx - s * dxFactor, cy + s - s * dyFactor);
    final bottomRight = Offset(cx + s * dxFactor, cy + s - s * dyFactor);

    // Three face paths
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

    // Face fills: top=lighter, left=medium, right=darker
    final topFill = Paint()..color = const Color(0xFF252552);
    final leftFill = Paint()..color = const Color(0xFF1A1A3E);
    final rightFill = Paint()..color = const Color(0xFF12122A);

    canvas.drawPath(topFace, topFill);
    canvas.drawPath(leftFace, leftFill);
    canvas.drawPath(rightFace, rightFill);

    // Edge glow color
    final glowColor = Color.lerp(
      SpaceTheme.nebulaPurple,
      SpaceTheme.starYellow,
      glowValue * 0.6,
    )!;

    // Outer glow (wider, transparent, blurred)
    final outerGlow = Paint()
      ..color = glowColor.withValues(alpha: glowValue * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
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

    // Face centers for text placement
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

    final fontSize = s * 0.38;

    // Draw face values (only visible ones)
    if (visible.top != null) {
      _drawFaceValue(
          canvas, topCenterPt, visible.top!, fontSize, Colors.white);
    } else {
      _drawQuestionMark(canvas, topCenterPt, fontSize * 0.8);
    }

    // Left face shows front value in isometric view
    final leftVal = visible.front ?? visible.left;
    if (leftVal != null) {
      _drawFaceValue(
          canvas, leftCenterPt, leftVal, fontSize * 0.85, Colors.white70);
    } else {
      _drawQuestionMark(canvas, leftCenterPt, fontSize * 0.7);
    }

    if (visible.right != null) {
      _drawFaceValue(canvas, rightCenterPt, visible.right!, fontSize * 0.85,
          Colors.white70);
    } else {
      _drawQuestionMark(canvas, rightCenterPt, fontSize * 0.7);
    }

    // Die label (for multi-die puzzles)
    if (label != null) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: SpaceTheme.starYellow.withValues(alpha: 0.7),
            fontSize: fontSize * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(4, size.height - labelPainter.height - 4));
    }
  }

  void _drawFaceValue(
      Canvas canvas, Offset center, int value, double fontSize, Color color) {
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
      Offset(
          center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _drawQuestionMark(Canvas canvas, Offset center, double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: SpaceTheme.cosmicPink.withValues(alpha: 0.5),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
          center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _IsometricDiePainter oldDelegate) =>
      oldDelegate.glowValue != glowValue;
}
