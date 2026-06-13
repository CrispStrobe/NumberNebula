import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
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

  int _getRadius() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 1; // 7 cells
    if (grade <= 2) return 2; // 19 cells
    return 3; // 37 cells
  }

  double _getEnergyFraction() {
    return 0.3; // 30% of cells have energy
  }

  double _getHintFraction() {
    // Grade 1-2: show ALL non-energy hints (100%). Player just taps blanks.
    // This matches the Kanguru mechanic (C7/2024_34 shows ALL numbers).
    //
    // Grade 3+: hide SOME number cells (shown as "?" in the UI).
    // Now blank cells could be energy OR hidden-number, requiring real
    // deduction from surrounding hint values. This is the Minesweeper depth.
    if (currentDifficulty == null) return 1.0;
    final grade = currentDifficulty!.grade;
    if (grade <= 1) return 0.90; // easy: most hints visible but not all
    if (grade <= 2) return 0.80; // some hidden, requires basic deduction
    if (grade == 3) return 0.70; // moderate deduction needed
    return 0.60; // harder deduction, more hidden cells
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userMarked.clear();
      successController.reset();
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
    if (puzzle!.validateSolution(userMarked)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'hive_station',
      difficulty: widget.level,
      score: totalScore,
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

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'hive_station',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.hiveStationLoseDesc)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${userMarked.length} / ${puzzle!.energyCells.length}',
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: userMarked.length == puzzle!.energyCells.length ? _checkSolution : null,
            icon: const Icon(Icons.check),
            label: Text(s.correct.replaceAll('!', '')),
            style: SpaceTheme.primaryButtonStyle,
          ),
        ],
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
