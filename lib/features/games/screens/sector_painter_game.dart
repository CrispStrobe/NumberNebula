import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/sector_painter_logic.dart';

class SectorPainterGame extends StatefulWidget {
  final int grade;
  final int level;
  const SectorPainterGame({super.key, required this.grade, required this.level});
  @override
  State<SectorPainterGame> createState() => _SectorPainterGameState();
}

class _SectorPainterGameState extends State<SectorPainterGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  SectorPainterPuzzle? _puzzle;
  Map<int, int> _coloring = {};
  int _selectedColor = 0;
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;

  static const List<Color> _paletteColors = [
    Color(0xFFE63946),
    Color(0xFF06FFA5),
    Color(0xFF6B48FF),
    Color(0xFFFFD700),
    Color(0xFFFF69B4),
  ];

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
      _coloring.clear();
      _successController.reset();
    });

    final generator = SectorPainterGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _selectedColor = 0;
      _isGenerating = false;
    });
  }

  void _paintRegion(int region) {
    setState(() {
      if (_coloring[region] == _selectedColor) {
        _coloring.remove(region);
      } else {
        _coloring[region] = _selectedColor;
      }
    });
  }

  void _checkSolution() {
    if (_puzzle == null) return;

    // Check all regions are colored
    if (_coloring.length < _puzzle!.regions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.sectorPainterLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_puzzle!.validateColoring(_coloring)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    final colorsUsed = _puzzle!.countColors(_coloring);
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int colorBonus = colorsUsed <= _puzzle!.chromaticNumber ? 100 : 0;
    int totalScore = baseScore + levelBonus + colorBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'sector_painter',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore, colorsUsed),
    );
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'sector_painter',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.sectorPainterLoseDesc)),
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
                title: s.sectorPainterTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.sectorPainterInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              _buildColorPalette(),
              Expanded(child: _buildGraphArea()),
              _buildCheckButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_puzzle!.availableColors, (index) {
          final isSelected = _selectedColor == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 48 : 40,
              height: isSelected ? 48 : 40,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _paletteColors[index % _paletteColors.length],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white30,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(
                        color: _paletteColors[index % _paletteColors.length]
                            .withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGraphArea() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, constraints.maxHeight) - 32;
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _GraphPainter(
                    puzzle: _puzzle!,
                    coloring: _coloring,
                    paletteColors: _paletteColors,
                    glowValue: _glowAnimation.value,
                  ),
                  child: Stack(
                    children: _puzzle!.regions.map((region) {
                      final pos = _puzzle!.positions[region];
                      return Positioned(
                        left: pos.x * size - 24,
                        top: pos.y * size - 24,
                        child: GestureDetector(
                          onTap: () => _paintRegion(region),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _coloring.containsKey(region)
                                  ? _paletteColors[_coloring[region]! %
                                      _paletteColors.length]
                                  : SpaceTheme.deepSpace.withValues(alpha: 0.8),
                              border: Border.all(
                                color: SpaceTheme.starYellow.withValues(
                                    alpha: _glowAnimation.value),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_coloring.containsKey(region)
                                          ? _paletteColors[_coloring[region]! %
                                              _paletteColors.length]
                                          : SpaceTheme.nebulaPurple)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${region + 1}',
                                style: SpaceTheme.titleStyle
                                    .copyWith(fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
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
          label: Text(S.of(context)!.sectorPainterWinTitle),
          style: SpaceTheme.primaryButtonStyle,
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score, int colorsUsed) {
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
                  Text(S.of(context)!.sectorPainterWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.sectorPainterWinDesc(colorsUsed, score),
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
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

class _GraphPainter extends CustomPainter {
  final SectorPainterPuzzle puzzle;
  final Map<int, int> coloring;
  final List<Color> paletteColors;
  final double glowValue;

  _GraphPainter({
    required this.puzzle,
    required this.coloring,
    required this.paletteColors,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpaceTheme.nebulaPurple.withValues(alpha: 0.5 * glowValue)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw edges
    for (final region in puzzle.regions) {
      for (final neighbor in puzzle.adjacency[region] ?? <int>{}) {
        if (neighbor > region) {
          final p1 = puzzle.positions[region];
          final p2 = puzzle.positions[neighbor];
          canvas.drawLine(
            Offset(p1.x * size.width, p1.y * size.height),
            Offset(p2.x * size.width, p2.y * size.height),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.glowValue != glowValue || oldDelegate.coloring != coloring;
}
