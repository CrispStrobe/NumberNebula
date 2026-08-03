import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/hive_station_logic.dart';
import 'package:flutter/foundation.dart';

class HiveStationGame extends StatefulWidget {
  final int grade;
  final int level;
  const HiveStationGame({super.key, required this.grade, required this.level});

  @override
  State<HiveStationGame> createState() => _HiveStationGameState();
}

class _HiveStationGameState extends State<HiveStationGame>
    with TickerProviderStateMixin, GameAnimationsMixin<HiveStationGame> {

  HiveStationPuzzle? puzzle;
  Set<HexCoord> userMarked = {};
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;
  int _attemptsLeft = 3;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);


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
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  // ─── Difficulty scaling ─────────────────────────────────────────────
  //
  // Grade gates the puzzle *type* (grid size, mechanics):
  //   Grade 1: radius 2 (19 cells), generous hints, 3 attempts
  //   Grade 2: radius 2→3, fewer hints, 3 attempts
  //   Grade 3: radius 3 (37 cells), sparse hints, 2 attempts
  //   Grade 4: radius 3→4, very sparse hints, 2 attempts
  //
  // Level tunes parameters within each grade:
  //   - Hint fraction decreases (more deduction needed)
  //   - Energy fraction increases slightly (more mines to find)
  //   - Attempts stay fixed per grade (mechanical gate)

  int _getRadius() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    final level = widget.level;
    if (grade <= 1) return 2; // 19 cells — enough for a real puzzle
    if (grade <= 2) return level >= 10 ? 3 : 2;
    if (grade <= 3) return 3; // 37 cells
    return level >= 8 ? 4 : 3; // grade 4: up to 61 cells
  }

  double _getEnergyFraction() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    final level = widget.level;
    // Grade 1: 25%→30%, Grade 2: 28%→33%, Grade 3: 30%→35%, Grade 4: 30%→38%
    final base = [0, 0.25, 0.28, 0.30, 0.30][grade.clamp(0, 4)];
    final max = [0, 0.30, 0.33, 0.35, 0.38][grade.clamp(0, 4)];
    return base + (level - 1) * (max - base) / 19;
  }

  double _getHintFraction() {
    if (currentDifficulty == null) return 0.75;
    final grade = currentDifficulty!.grade;
    final level = widget.level;
    // Grade determines range, level slides within it:
    //   Grade 1: 0.75 → 0.60  (most hints visible, some deduction)
    //   Grade 2: 0.65 → 0.50  (moderate deduction)
    //   Grade 3: 0.55 → 0.40  (significant deduction)
    //   Grade 4: 0.50 → 0.30  (expert: many hidden cells)
    final start = [1.0, 0.75, 0.65, 0.55, 0.50][grade.clamp(0, 4)];
    final end = [1.0, 0.60, 0.50, 0.40, 0.30][grade.clamp(0, 4)];
    return start - (level - 1) * (start - end) / 19;
  }

  int _getMaxAttempts() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    return grade <= 2 ? 3 : 2;
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userMarked.clear();
      successController.reset();
      _attemptsLeft = _getMaxAttempts();
      _gameOver = false;
    });

    try {
      final generator = HiveStationGenerator();
      final p = await generator.generate(
        radius: _getRadius(),
        energyFraction: _getEnergyFraction(),
        hintFraction: _getHintFraction(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HiveStation] Error generating puzzle: $e');
    }
  }

  void _toggleCell(HexCoord coord) {
    if (_gameOver) return;
    // Don't toggle cells that show a hint
    if (puzzle!.revealedHints.contains(coord)) return;

    setState(() {
      if (userMarked.contains(coord)) {
        userMarked.remove(coord);
      } else {
        userMarked.add(coord);
      }
    });

    HapticFeedback.selectionClick();
  }

  void _checkSolution() {
    if (_gameOver) return;
    if (puzzle!.validateSolution(userMarked)) {
      _handleWin();
    } else {
      setState(() {
        _attemptsLeft--;
        if (_attemptsLeft <= 0) {
          _gameOver = true;
          _handleFinalLoss();
        } else {
          _handleWrongAttempt();
        }
      });
    }
  }

  void _handleWrongAttempt() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(S.of(context)!.hiveStationWrongAttempt(_attemptsLeft)),
            ),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleFinalLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'hive_station',
      difficulty: widget.level,
    ));
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildLossDialog(),
      );
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int attemptBonus = _attemptsLeft * 30;
    int totalScore = baseScore + levelBonus + attemptBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'hive_station',
      difficulty: widget.level,
      score: totalScore,
      performance: Perf.fromAttempts(
          _getMaxAttempts() - _attemptsLeft + 1, _getMaxAttempts()),
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
                title: s.hiveStationTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.hiveStationInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: _buildHexGrid()),
              _buildCheckButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHexGrid() {
    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.starYellow.withValues(alpha: 0.08 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.starYellow.withValues(alpha: glowAnimation.value * 0.5),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
                return SizedBox(
                  width: availableSize,
                  height: availableSize,
                  child: _buildHexCells(availableSize),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHexCells(double areaSize) {
    final radius = puzzle!.radius;
    final hexSize = areaSize / (2 * radius + 2.5);
    final center = Offset(areaSize / 2, areaSize / 2);

    final cells = <Widget>[];

    for (final coord in puzzle!.allCells) {
      final pixelPos = _hexToPixel(coord, hexSize, center);
      final isRevealed = puzzle!.revealedHints.contains(coord);
      final isMarked = userMarked.contains(coord);
      final hint = puzzle!.numberHints[coord];

      cells.add(Positioned(
        left: pixelPos.dx - hexSize * 0.8,
        top: pixelPos.dy - hexSize * 0.8,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleCell(coord),
          child: _buildHexCell(
            hexSize: hexSize * 1.6,
            isRevealed: isRevealed,
            isMarked: isMarked,
            hint: isRevealed ? hint : null,
          ),
        ),
      ));
    }

    return Stack(children: cells);
  }

  Offset _hexToPixel(HexCoord coord, double hexSize, Offset center) {
    final x = hexSize * (math.sqrt(3) * coord.q + math.sqrt(3) / 2 * coord.r);
    final y = hexSize * (1.5 * coord.r);
    return Offset(center.dx + x, center.dy + y);
  }

  Widget _buildHexCell({
    required double hexSize,
    required bool isRevealed,
    required bool isMarked,
    int? hint,
  }) {
    Color bgColor;
    Color borderColor;
    if (isMarked) {
      bgColor = SpaceTheme.starYellow.withValues(alpha: 0.6);
      borderColor = SpaceTheme.starYellow;
    } else if (isRevealed) {
      bgColor = const Color(0xFF1E2A4A); // slightly lighter than deep space
      borderColor = const Color(0xFF4A5A8A); // visible light blue border
    } else {
      bgColor = const Color(0xFF2A1A3A); // dark purple, tappable cells
      borderColor = const Color(0xFF6B48FF).withValues(alpha: 0.6); // brighter purple
    }

    return SizedBox(
      width: hexSize,
      height: hexSize,
      child: CustomPaint(
        painter: _HexCellPainter(
          fillColor: bgColor,
          borderColor: borderColor,
          glowColor: isMarked ? SpaceTheme.starYellow.withValues(alpha: 0.4) : null,
        ),
        child: Center(
          child: hint != null
              ? Text(
                  hint.toString(),
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: hexSize * 0.35,
                    color: Colors.white,
                  ),
                )
              : isMarked
                  ? Icon(Icons.flash_on, color: Colors.white, size: hexSize * 0.4)
                  : null,
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    final s = S.of(context)!;

    // Attempts indicator color
    final attColor = _attemptsLeft <= 1
        ? SpaceTheme.rocketRed
        : _attemptsLeft <= 2
            ? SpaceTheme.planetOrange
            : SpaceTheme.alienGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Marked / total
          Text(
            '${userMarked.length} / ${puzzle!.energyCells.length}',
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow),
          ),
          const SizedBox(width: 16),
          // Check button
          ElevatedButton.icon(
            onPressed: !_gameOver &&
                    userMarked.length == puzzle!.energyCells.length
                ? _checkSolution
                : null,
            icon: const Icon(Icons.check),
            label: Text(s.correct.replaceAll('!', '')),
            style: SpaceTheme.primaryButtonStyle,
          ),
          const SizedBox(width: 16),
          // Attempts remaining
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: attColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: attColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_attemptsLeft',
                  style: SpaceTheme.titleStyle.copyWith(
                    fontSize: 14,
                    color: attColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossDialog() {
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
            const Icon(Icons.hexagon_outlined, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.hiveStationLoseTitle,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.hiveStationLoseDesc,
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
                  const Icon(Icons.hexagon, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.hiveStationWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.hiveStationWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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

/// Draws a flat-top hexagonal cell with fill, border, and optional glow.
class _HexCellPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color? glowColor;

  _HexCellPainter({
    required this.fillColor,
    required this.borderColor,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.92; // slight inset for spacing

    // Flat-top hexagon: vertices at 0, 60, 120, 180, 240, 300 degrees
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180; // -30 for flat-top
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Optional glow shadow
    if (glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    // Fill
    canvas.drawPath(path, Paint()..color = fillColor);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HexCellPainter old) =>
      fillColor != old.fillColor ||
      borderColor != old.borderColor ||
      glowColor != old.glowColor;
}
