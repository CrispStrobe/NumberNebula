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
import '../services/warp_fold_logic.dart';

class WarpFoldGame extends StatefulWidget {
  final int grade;
  final int level;
  const WarpFoldGame({super.key, required this.grade, required this.level});
  @override
  State<WarpFoldGame> createState() => _WarpFoldGameState();
}

class _WarpFoldGameState extends State<WarpFoldGame>
    with TickerProviderStateMixin, GameAnimationsMixin<WarpFoldGame> {
  late AnimationController _foldController;
  late Animation<double> _foldAnimation;

  WarpFoldPuzzle? _puzzle;
  int? _selectedOption;
  bool _isGenerating = true;
  bool _answered = false;

  /// Wrong unfoldings picked before the right one.
  int _wrongAnswers = 0;
  bool _showingFoldAnimation = false;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);
    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);

    _foldController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _foldAnimation = CurvedAnimation(
      parent: _foldController,
      curve: Curves.easeInOut,
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
    _foldController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _wrongAnswers = 0;
      _selectedOption = null;
      _answered = false;
      _showingFoldAnimation = false;
      successController.reset();
      _foldController.reset();
    });

    final generator =
        WarpFoldGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _isGenerating = false;
      _showingFoldAnimation = true;
    });

    // Play fold animation, then show the puzzle
    _foldController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showingFoldAnimation = false;
        });
      }
    });
  }

  void _selectOption(int index) {
    if (_answered || _showingFoldAnimation) return;
    setState(() {
      _selectedOption = index;
    });
  }

  void _submitAnswer() {
    if (_selectedOption == null || _answered) return;
    setState(() => _answered = true);

    if (_selectedOption == _puzzle!.correctIndex) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int foldBonus = _puzzle!.folds.length * 50;
    int totalScore = baseScore + levelBonus + foldBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'warp_fold',
      difficulty: widget.level,
      score: totalScore,
      performance: Perf.fromMistakes(_wrongAnswers, per: 0.25),
    ));

    successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore),
    );
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    _wrongAnswers++;
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'warp_fold',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.warpFoldLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _answered = false);
      }
    });
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
                title: s.warpFoldTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.warpFoldInstructions,
                      style: SpaceTheme.bodyStyle.copyWith(fontSize: 11))),
                  ]),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildGameContent(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent(BoxConstraints constraints) {
    if (_showingFoldAnimation) {
      return _buildFoldAnimationView(constraints);
    }
    return _buildPuzzleView(constraints);
  }

  Widget _buildFoldAnimationView(BoxConstraints constraints) {
    final paperSize = math.min(constraints.maxWidth * 0.6, constraints.maxHeight * 0.5);

    return Center(
      child: AnimatedBuilder(
        animation: _foldAnimation,
        builder: (context, _) {
          final foldCount = _puzzle!.folds.length;
          final cutCount = _puzzle!.cuts.length;
          // Determine which fold step we're on
          final stepsTotal = foldCount + 1; // folds + cut reveal
          final progress = _foldAnimation.value * stepsTotal;
          final currentStep = progress.floor().clamp(0, stepsTotal - 1);
          final stepProgress = progress - currentStep;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Step label
              Text(
                currentStep < foldCount
                    ? S.of(context)!.warpFoldStep(currentStep + 1, _foldDirLabel(_puzzle!.folds[currentStep].direction))
                    : S.of(context)!.warpCutHoles(cutCount),
                style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              // Animated paper
              SizedBox(
                width: paperSize,
                height: paperSize,
                child: CustomPaint(
                  painter: _FoldAnimationPainter(
                    folds: _puzzle!.folds,
                    cuts: _puzzle!.cuts,
                    gridSize: _puzzle!.gridSize,
                    currentStep: currentStep,
                    stepProgress: stepProgress,
                    foldCount: foldCount,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.warpWhichPattern,
                style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
              ),
            ],
          );
        },
      ),
    );
  }

  String _foldDirLabel(FoldDirection dir) {
    final s = S.of(context)!;
    switch (dir) {
      case FoldDirection.left:
        return s.warpDirLeft;
      case FoldDirection.right:
        return s.warpDirRight;
      case FoldDirection.top:
        return s.warpDirUp;
      case FoldDirection.bottom:
        return s.warpDirDown;
    }
  }

  Widget _buildPuzzleView(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Fold info bar with replay button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: _buildFoldInfo()),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _answered ? null : () {
                  setState(() => _showingFoldAnimation = true);
                  _foldController.forward(from: 0.0);
                },
                icon: const Icon(Icons.replay, color: SpaceTheme.starYellow),
                tooltip: S.of(context)!.warpFoldReplay,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Options grid - fills remaining space
          Expanded(
            child: _buildOptionsGrid(constraints),
          ),
          // Submit button
          _buildSubmitButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFoldInfo() {
    final foldNames = _puzzle!.folds.map((f) {
      switch (f.direction) {
        case FoldDirection.left:
          return '\u2190';
        case FoldDirection.right:
          return '\u2192';
        case FoldDirection.top:
          return '\u2191';
        case FoldDirection.bottom:
          return '\u2193';
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.content_cut, color: SpaceTheme.cosmicPink, size: 18),
          const SizedBox(width: 8),
          Text(
            S.of(context)!.warpFoldsAndCuts(foldNames.join(" "), _puzzle!.cuts.length),
            style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(BoxConstraints outerConstraints) {
    final optionCount = _puzzle!.options.length; // always 5

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a 3x2 grid layout, with the 5th item centered in the last row
        const spacing = 8.0;
        final availW = constraints.maxWidth - spacing * 2;
        final availH = constraints.maxHeight - spacing;
        // 3 columns, 2 rows
        final cellW = (availW / 3);
        final cellH = (availH / 2);
        final cellSize = math.min(cellW, cellH) - spacing;

        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(optionCount, (index) {
              return SizedBox(
                width: cellSize,
                height: cellSize,
                child: _buildOptionCard(index),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(int index) {
    final isSelected = _selectedOption == index;
    final isCorrect = index == _puzzle!.correctIndex;
    final showResult = _answered;

    Color borderColor;
    if (showResult && isSelected) {
      borderColor = isCorrect ? SpaceTheme.alienGreen : SpaceTheme.rocketRed;
    } else if (isSelected) {
      borderColor = SpaceTheme.starYellow;
    } else {
      borderColor = SpaceTheme.nebulaPurple.withValues(alpha: glowAnimation.value);
    }

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isSelected ? 3 : 1),
              boxShadow: isSelected
                  ? [BoxShadow(
                      color: borderColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    )]
                  : null,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _PaperGridPainter(
                      grid: _puzzle!.options[index],
                      gridSize: _puzzle!.gridSize,
                    ),
                  ),
                ),
                // Option number badge
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              _selectedOption != null && !_answered ? _submitAnswer : null,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(S.of(context)!.warpFoldTitle),
          style: SpaceTheme.primaryButtonStyle,
        ),
      ),
    );
  }

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
                  Text(S.of(context)!.warpFoldWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.warpFoldWinDesc(score),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
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

/// Painter for the fold animation sequence.
class _FoldAnimationPainter extends CustomPainter {
  final List<FoldStep> folds;
  final List<CutPosition> cuts;
  final int gridSize;
  final int currentStep;
  final double stepProgress;
  final int foldCount;

  _FoldAnimationPainter({
    required this.folds,
    required this.cuts,
    required this.gridSize,
    required this.currentStep,
    required this.stepProgress,
    required this.foldCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Paper background -- light so folds are visible
    final paperPaint = Paint()..color = const Color(0xFF8899AA);
    final paperRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(8)),
      paperPaint,
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(8)),
      Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Draw fold lines for completed folds
    final foldLinePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashLength = 6.0;

    for (int i = 0; i < math.min(currentStep, foldCount); i++) {
      _drawFoldLine(canvas, folds[i].direction, w, h, foldLinePaint, dashLength);
    }

    // Current fold animation
    if (currentStep < foldCount) {
      final dir = folds[currentStep].direction;
      // Draw the fold line being created
      final activeFoldPaint = Paint()
        ..color = SpaceTheme.starYellow.withValues(alpha: 0.6 + stepProgress * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      _drawFoldLine(canvas, dir, w, h, activeFoldPaint, dashLength);

      // Animate folding: draw a darker overlay for the folded portion
      final foldOverlay = Paint()
        ..color = const Color(0xFF2A2A44).withValues(alpha: 0.3 + stepProgress * 0.5);

      switch (dir) {
        case FoldDirection.left:
          canvas.drawRect(Rect.fromLTWH(0, 0, w / 2 * (1 - stepProgress), h), foldOverlay);
          break;
        case FoldDirection.right:
          canvas.drawRect(Rect.fromLTWH(w / 2 + w / 2 * stepProgress, 0, w / 2 * (1 - stepProgress), h), foldOverlay);
          break;
        case FoldDirection.top:
          canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2 * (1 - stepProgress)), foldOverlay);
          break;
        case FoldDirection.bottom:
          canvas.drawRect(Rect.fromLTWH(0, h / 2 + h / 2 * stepProgress, w, h / 2 * (1 - stepProgress)), foldOverlay);
          break;
      }
    }

    // Draw cuts if we're on the cut step -- scissors cutting holes
    if (currentStep >= foldCount) {
      for (final cut in cuts) {
        final cx = cut.x * w;
        final cy = cut.y * h;
        final radius = cut.size * w * 0.5 * (0.3 + stepProgress * 0.7);
        // Cut-out hole: dark with bright border
        canvas.drawCircle(Offset(cx, cy), radius,
          Paint()..color = SpaceTheme.deepSpace);
        canvas.drawCircle(Offset(cx, cy), radius,
          Paint()..color = SpaceTheme.starYellow.withValues(alpha: stepProgress)
            ..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final cellW = w / gridSize;
    final cellH = h / gridSize;
    for (int i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(i * cellW, 0), Offset(i * cellW, h), gridPaint);
      canvas.drawLine(Offset(0, i * cellH), Offset(w, i * cellH), gridPaint);
    }
  }

  void _drawFoldLine(Canvas canvas, FoldDirection dir, double w, double h, Paint paint, double dashLen) {
    switch (dir) {
      case FoldDirection.left:
      case FoldDirection.right:
        // Vertical center line
        _drawDashedLine(canvas, Offset(w / 2, 0), Offset(w / 2, h), paint, dashLen);
        break;
      case FoldDirection.top:
      case FoldDirection.bottom:
        // Horizontal center line
        _drawDashedLine(canvas, Offset(0, h / 2), Offset(w, h / 2), paint, dashLen);
        break;
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint, double dashLen) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final nx = dx / distance;
    final ny = dy / distance;
    var pos = 0.0;
    while (pos < distance) {
      final segEnd = math.min(pos + dashLen, distance);
      canvas.drawLine(
        Offset(start.dx + nx * pos, start.dy + ny * pos),
        Offset(start.dx + nx * segEnd, start.dy + ny * segEnd),
        paint,
      );
      pos += dashLen * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _FoldAnimationPainter oldDelegate) =>
      oldDelegate.currentStep != currentStep ||
      oldDelegate.stepProgress != stepProgress;
}

class _PaperGridPainter extends CustomPainter {
  final List<List<bool>> grid;
  final int gridSize;

  _PaperGridPainter({required this.grid, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    final paperPaint = Paint()..color = const Color(0xFF2A2A4A);
    final holePaint = Paint()..color = SpaceTheme.cosmicPink;
    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paperPaint);

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        if (r < grid.length && c < grid[r].length && grid[r][c]) {
          canvas.drawRect(rect, holePaint);
        }
        canvas.drawRect(rect, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGridPainter oldDelegate) => false;
}
