import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/gravity_well_logic.dart';

class GravityWellGame extends StatefulWidget {
  final int grade;
  final int level;
  const GravityWellGame({super.key, required this.grade, required this.level});

  @override
  State<GravityWellGame> createState() => _GravityWellGameState();
}

class _GravityWellGameState extends State<GravityWellGame>
    with TickerProviderStateMixin, GameAnimationsMixin<GravityWellGame> {

  GravityWellPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  Map<String, int> _userAnswers = {};
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);


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
    glowController.stop();
    successController.stop();
    pulseController.stop();
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      successController.reset();
    });

    final generated = GravityWellLogic.generate({
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _userAnswers = {for (final label in generated.unknownWeights.keys) label: 1};
        _isGenerating = false;
      });
    }
  }

  void _showNumberInput(String label, int currentValue) {
    final controller = TextEditingController(text: '$currentValue');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceTheme.deepSpace,
        title: Text('$label = ?', style: SpaceTheme.titleStyle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
          decoration: InputDecoration(
            suffix: Text(S.of(context)!.gravityWellKg,
                style: const TextStyle(color: Colors.white54)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) {
              setState(() {
                _userAnswers[label] = parsed.clamp(1, 30);
              });
            }
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null) {
                setState(() {
                  _userAnswers[label] = parsed.clamp(1, 30);
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkSolution() {
    if (puzzle == null || _gameOver) return;

    if (puzzle!.checkSolution(_userAnswers)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  /// Extract arithmetic problems from balance scales.
  /// Each scale where the unknown appears produces an addition/subtraction problem.
  List<MathProblem> _extractMathProblems() {
    if (puzzle == null) return [];
    final problems = <MathProblem>[];

    for (final scale in puzzle!.scales) {
      // Sum known weights on each side to derive the equation
      final leftKnown = scale.leftSide
          .where((item) => !puzzle!.unknownWeights.containsKey(item.label))
          .fold(0, (sum, item) => sum + item.weight);
      final rightKnown = scale.rightSide
          .where((item) => !puzzle!.unknownWeights.containsKey(item.label))
          .fold(0, (sum, item) => sum + item.weight);
      final leftUnknown = scale.leftSide
          .where((item) => puzzle!.unknownWeights.containsKey(item.label));
      final rightUnknown = scale.rightSide
          .where((item) => puzzle!.unknownWeights.containsKey(item.label));

      // Simple case: one unknown on one side, known values on other
      if (leftUnknown.length == 1 && rightUnknown.isEmpty) {
        // unknown = rightKnown - leftKnown (subtraction)
        final unknownWeight = leftUnknown.first.weight;
        if (rightKnown > leftKnown) {
          problems.add(MathProblem.subtraction(rightKnown, leftKnown,
              difficulty: widget.grade));
        } else {
          problems.add(MathProblem.addition(leftKnown, unknownWeight,
              difficulty: widget.grade));
        }
      } else if (rightUnknown.length == 1 && leftUnknown.isEmpty) {
        final unknownWeight = rightUnknown.first.weight;
        if (leftKnown > rightKnown) {
          problems.add(MathProblem.subtraction(leftKnown, rightKnown,
              difficulty: widget.grade));
        } else {
          problems.add(MathProblem.addition(rightKnown, unknownWeight,
              difficulty: widget.grade));
        }
      }
    }
    return problems;
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int complexityBonus = puzzle!.scales.length * 30 + puzzle!.unknownWeights.length * 40;
    int totalScore = baseScore + levelBonus + complexityBonus;

    final mathProblems = _extractMathProblems();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'gravity_well',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: mathProblems,
    ));

    successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'gravity_well',
      difficulty: widget.level,
      mathProblems: _extractMathProblems(),
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.gravityWellLoseDesc)),
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
                title: s.gravityWellTitle,
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

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildScalesArea(constraints),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: _buildAnswerPanel(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Text(
            S.of(context)!.gravityWellInstructions,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Known weights reference
          if (puzzle!.knownWeights.isNotEmpty) _buildKnownWeightsBar(),

          // Balance scales
          ..._buildScaleWidgets(constraints.maxWidth - 24),

          const SizedBox(height: 12),

          // Answer input section
          _buildAnswerPanel(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildScalesArea(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.of(context)!.gravityWellInstructions,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (puzzle!.knownWeights.isNotEmpty) _buildKnownWeightsBar(),
          ..._buildScaleWidgets(constraints.maxWidth * 0.6 - 24),
        ],
      ),
    );
  }

  Widget _buildKnownWeightsBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: SpaceTheme.alienGreen, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              S.of(context)!.gravityWellKnown(puzzle!.knownWeights.entries.map((e) => '${e.key} = ${e.value} ${S.of(context)!.gravityWellKg}').join(', ')),
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13, color: SpaceTheme.alienGreen),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScaleWidgets(double maxWidth) {
    return List.generate(puzzle!.scales.length, (i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaleWidth = math.max(200.0, math.min(constraints.maxWidth, maxWidth));
            final scaleHeight = (scaleWidth * 0.55).clamp(120.0, 220.0);
            return _buildScaleVisual(i, scaleWidth, scaleHeight);
          },
        ),
      );
    });
  }

  Widget _buildScaleVisual(int index, double width, double height) {
    final scale = puzzle!.scales[index];

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SpaceTheme.nebulaPurple.withValues(alpha: glowAnimation.value),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  S.of(context)!.gravityWellScaleN(index + 1),
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 12,
                    color: SpaceTheme.starYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BalanceScalePainter(
                    scale: scale,
                    unknownLabels: puzzle!.unknownWeights.keys.toSet(),
                    knownWeights: puzzle!.knownWeights,
                    glowValue: glowAnimation.value,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnswerPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.gravityWellEnterWeights,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...puzzle!.unknownWeights.keys.map(_buildAnswerInput),
          const SizedBox(height: 12),
          if (!_gameOver)
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: pulseAnimation.value,
                  child: ElevatedButton.icon(
                    onPressed: _checkSolution,
                    icon: const Icon(Icons.balance),
                    label: Text(S.of(context)!.gravityWellCheckBalance),
                    style: SpaceTheme.primaryButtonStyle,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(String label) {
    final value = _userAnswers[label] ?? 1;
    const maxWeight = 30; // reasonable upper bound

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06FFA5), Color(0xFF00C9DB)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                label,
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('= ', style: TextStyle(color: Colors.white, fontSize: 18)),
          // Minus button
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: SpaceTheme.starYellow),
            iconSize: 28,
            onPressed: _gameOver ? null : () {
              HapticFeedback.selectionClick();
              setState(() {
                _userAnswers[label] = (value - 1).clamp(1, maxWeight);
              });
            },
          ),
          // Value display — tappable for keyboard input
          GestureDetector(
            onTap: _gameOver ? null : () => _showNumberInput(label, value),
            child: Container(
              width: 56, height: 42,
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.starYellow, width: 2),
              ),
              child: Center(
                child: Text(
                  '$value',
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
                ),
              ),
            ),
          ),
          // Plus button
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: SpaceTheme.starYellow),
            iconSize: 28,
            onPressed: _gameOver ? null : () {
              HapticFeedback.selectionClick();
              setState(() {
                _userAnswers[label] = (value + 1).clamp(1, maxWeight);
              });
            },
          ),
          const SizedBox(width: 4),
          Text(S.of(context)!.gravityWellKg, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWinDialog(int totalScore) {
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
                  const Icon(Icons.balance, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.gravityWellWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.gravityWellWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
                        child: Text(s.playAgain),
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
          ),
        );
      },
    );
  }
}

/// CustomPainter that draws a balance scale with fulcrum, beam, and pans.
/// Wireframe style with bright lines on dark background. Beam is LEVEL
/// because all scales are in equilibrium.
class _BalanceScalePainter extends CustomPainter {
  final BalanceScale scale;
  final Set<String> unknownLabels;
  final Map<String, int> knownWeights;
  final double glowValue;

  _BalanceScalePainter({
    required this.scale,
    required this.unknownLabels,
    required this.knownWeights,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final baseY = h * 0.92;
    final fulcrumTopY = h * 0.45;
    final beamLen = w * 0.38;

    // Colors
    final beamColor = Color.lerp(
      const Color(0xFF4488CC),
      SpaceTheme.starYellow,
      glowValue * 0.3,
    )!;
    const fulcrumColor = SpaceTheme.moonSilver;

    // -- Fulcrum triangle --
    final fulcrumPaint = Paint()
      ..color = fulcrumColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fulcrumGlow = Paint()
      ..color = fulcrumColor.withValues(alpha: glowValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final fulcrumPath = Path()
      ..moveTo(centerX, fulcrumTopY)
      ..lineTo(centerX - 14, baseY)
      ..lineTo(centerX + 14, baseY)
      ..close();
    canvas.drawPath(fulcrumPath, fulcrumGlow);
    canvas.drawPath(fulcrumPath, fulcrumPaint);

    // Base line
    canvas.drawLine(
      Offset(centerX - 30, baseY),
      Offset(centerX + 30, baseY),
      fulcrumPaint,
    );

    // -- Beam: LEVEL (balanced) --
    final leftEnd = Offset(centerX - beamLen, fulcrumTopY);
    final rightEnd = Offset(centerX + beamLen, fulcrumTopY);

    final beamPaint = Paint()
      ..color = beamColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final beamGlowPaint = Paint()
      ..color = beamColor.withValues(alpha: glowValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(leftEnd, rightEnd, beamGlowPaint);
    canvas.drawLine(leftEnd, rightEnd, beamPaint);

    // Fulcrum pivot dot
    canvas.drawCircle(
      Offset(centerX, fulcrumTopY),
      4,
      Paint()..color = beamColor,
    );

    // -- Pan strings --
    final panStringPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final panDepth = h * 0.10;
    final panHalfW = beamLen * 0.40;

    // Left pan
    final leftPanCenter = Offset(leftEnd.dx, leftEnd.dy + panDepth);
    _drawPanStrings(canvas, leftEnd, panDepth, panHalfW, panStringPaint);
    _drawPan(canvas, leftPanCenter, panHalfW, const Color(0xFF00AACC));

    // Right pan
    final rightPanCenter = Offset(rightEnd.dx, rightEnd.dy + panDepth);
    _drawPanStrings(canvas, rightEnd, panDepth, panHalfW, panStringPaint);
    _drawPan(canvas, rightPanCenter, panHalfW, const Color(0xFFCC8800));

    // -- Draw items on pans --
    _drawItems(canvas, scale.leftSide, leftPanCenter, panHalfW);
    _drawItems(canvas, scale.rightSide, rightPanCenter, panHalfW);
  }

  void _drawPanStrings(Canvas canvas, Offset top, double depth, double panHalfW, Paint paint) {
    canvas.drawLine(top, Offset(top.dx - panHalfW, top.dy + depth), paint);
    canvas.drawLine(top, Offset(top.dx + panHalfW, top.dy + depth), paint);
  }

  void _drawPan(Canvas canvas, Offset center, double halfW, Color color) {
    final panPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final panEdge = Paint()
      ..color = color.withValues(alpha: 0.7 + glowValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final panGlow = Paint()
      ..color = color.withValues(alpha: glowValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final panPath = Path()
      ..moveTo(center.dx - halfW, center.dy)
      ..quadraticBezierTo(center.dx, center.dy + halfW * 0.4, center.dx + halfW, center.dy);

    canvas.drawPath(panPath, panGlow);
    canvas.drawPath(panPath, panPaint);
    canvas.drawPath(panPath, panEdge);
  }

  void _drawItems(Canvas canvas, List<ScaleItem> items, Offset panCenter, double panHalfW) {
    if (items.isEmpty) return;

    final itemCount = items.length;
    final spacing = (panHalfW * 2) / (itemCount + 1);

    for (int i = 0; i < itemCount; i++) {
      final item = items[i];
      final x = panCenter.dx - panHalfW + spacing * (i + 1);
      final y = panCenter.dy - 18;
      final isUnknown = unknownLabels.contains(item.label);
      final isWeightBlock = item.label.contains('kg');

      // Determine box size based on label length
      final labelText = _getItemLabel(item, isUnknown, isWeightBlock);
      final boxW = math.max(32.0, labelText.length * 9.0 + 10);
      const boxH = 30.0;
      final boxRect = Rect.fromCenter(center: Offset(x, y), width: boxW, height: boxH);

      // Box fill & edge color based on type
      Color edgeColor;
      Color fillColor;
      if (isWeightBlock) {
        edgeColor = SpaceTheme.moonSilver;
        fillColor = SpaceTheme.moonSilver.withValues(alpha: 0.15);
      } else if (isUnknown) {
        edgeColor = SpaceTheme.starYellow;
        fillColor = SpaceTheme.nebulaPurple.withValues(alpha: 0.6);
      } else {
        edgeColor = const Color(0xFF06FFA5);
        fillColor = SpaceTheme.deepSpace.withValues(alpha: 0.8);
      }

      final boxFill = Paint()..color = fillColor;
      final boxEdge = Paint()
        ..color = edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(4)),
        boxFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(4)),
        boxEdge,
      );

      // Weight block icon (small lines on top)
      if (isWeightBlock) {
        final iconPaint = Paint()
          ..color = SpaceTheme.moonSilver.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(x - 4, y - boxH / 2 - 3),
          Offset(x + 4, y - boxH / 2 - 3),
          iconPaint,
        );
        canvas.drawLine(
          Offset(x - 2, y - boxH / 2 - 6),
          Offset(x + 2, y - boxH / 2 - 6),
          iconPaint,
        );
      }

      // Draw label text
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: isUnknown ? SpaceTheme.starYellow : Colors.white,
            fontSize: labelText.length > 5 ? 11 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  String _getItemLabel(ScaleItem item, bool isUnknown, bool isWeightBlock) {
    if (isWeightBlock) {
      return item.label; // e.g. "5 kg"
    }
    if (isUnknown) {
      return '${item.label} = ?';
    }
    // Known labeled object: show "A = 3 kg"
    final weight = knownWeights[item.label];
    if (weight != null) {
      return '${item.label}=${weight}kg';
    }
    return item.label;
  }

  @override
  bool shouldRepaint(covariant _BalanceScalePainter oldDelegate) =>
      oldDelegate.glowValue != glowValue;
}
