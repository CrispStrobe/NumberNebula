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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  SectorPainterPuzzle? _puzzle;
  final Map<int, int> _coloring = {};
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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
    _pulseController.dispose();
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
    HapticFeedback.selectionClick();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxHeight < 500;
              final bool isWide = constraints.maxWidth > 700;

              return Column(
                children: [
                  _buildHeader(s, isCompact),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(isCompact)
                        : _buildCompactLayout(isCompact),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(S s, bool isCompact) {
    if (!isCompact) {
      return Column(
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
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              s.sectorPainterTitle,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool isCompact) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildMapArea(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildColorPaletteVertical(),
                const SizedBox(height: 16),
                _buildCheckButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(bool isCompact) {
    return Column(
      children: [
        _buildColorPalette(),
        Expanded(child: _buildMapArea()),
        _buildCheckButton(),
        SizedBox(height: isCompact ? 8 : 16),
      ],
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
              width: isSelected ? 52 : 44,
              height: isSelected ? 52 : 44,
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
              child: isSelected
                  ? const Icon(Icons.brush, color: Colors.white, size: 22)
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildColorPaletteVertical() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Colors', style: SpaceTheme.titleStyle.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(_puzzle!.availableColors, (index) {
              final isSelected = _selectedColor == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 52 : 44,
                  height: isSelected ? 52 : 44,
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
                  child: isSelected
                      ? const Icon(Icons.brush, color: Colors.white, size: 22)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = math.min(constraints.maxWidth, constraints.maxHeight) - 24;
        final regionCount = _puzzle!.regions.length;

        // Arrange regions in a grid-like layout
        final cols = _computeGridCols(regionCount);
        final rows = (regionCount / cols).ceil();

        final cellW = availableSize / cols;
        final cellH = availableSize / rows;
        final cellSize = math.min(cellW, cellH);
        final totalW = cellSize * cols;
        final totalH = cellSize * rows;

        return Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: totalW + 16,
                height: totalH + 16,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value * 0.5),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.deepSpace.withValues(alpha: 0.9),
                      SpaceTheme.nebulaPurple.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: CustomPaint(
                  size: Size(totalW, totalH),
                  painter: _TerritoryMapPainter(
                    puzzle: _puzzle!,
                    coloring: _coloring,
                    paletteColors: _paletteColors,
                    glowValue: _glowAnimation.value,
                    cols: cols,
                    rows: rows,
                    cellSize: cellSize,
                  ),
                  child: Stack(
                    children: _puzzle!.regions.map((region) {
                      final col = region % cols;
                      final row = region ~/ cols;
                      final isColored = _coloring.containsKey(region);

                      return Positioned(
                        left: col * cellSize,
                        top: row * cellSize,
                        child: GestureDetector(
                          onTap: () => _paintRegion(region),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final scale = isColored ? 1.0 : _pulseAnimation.value;
                              return Transform.scale(
                                scale: scale,
                                child: _buildRegionTile(region, cellSize),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRegionTile(int region, double cellSize) {
    final isColored = _coloring.containsKey(region);
    final color = isColored
        ? _paletteColors[_coloring[region]! % _paletteColors.length]
        : null;

    // Determine which borders to thicken (adjacent regions share thin borders)
    final adjacents = _puzzle!.adjacency[region] ?? <int>{};
    final regionCount = _puzzle!.regions.length;
    final cols = _computeGridCols(regionCount);

    final thisRow = region ~/ cols;
    final thisCol = region % cols;

    // Check adjacency in each cardinal direction
    final regionAbove = (thisRow > 0) ? (thisRow - 1) * cols + thisCol : -1;
    final regionBelow = (thisRow < (regionCount / cols).ceil() - 1)
        ? (thisRow + 1) * cols + thisCol
        : -1;
    final regionLeft = (thisCol > 0) ? thisRow * cols + (thisCol - 1) : -1;
    final regionRight = (thisCol < cols - 1) ? thisRow * cols + (thisCol + 1) : -1;

    final adjAbove = regionAbove >= 0 && regionAbove < regionCount && adjacents.contains(regionAbove);
    final adjBelow = regionBelow >= 0 && regionBelow < regionCount && adjacents.contains(regionBelow);
    final adjLeft = regionLeft >= 0 && regionLeft < regionCount && adjacents.contains(regionLeft);
    final adjRight = regionRight >= 0 && regionRight < regionCount && adjacents.contains(regionRight);

    const padding = 3.0;
    final innerSize = cellSize - padding * 2;

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isColored
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color!.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.6),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SpaceTheme.deepSpace.withValues(alpha: 0.9),
                      SpaceTheme.nebulaPurple.withValues(alpha: 0.6),
                    ],
                  ),
            border: Border(
              top: BorderSide(
                color: adjAbove
                    ? SpaceTheme.starYellow.withValues(alpha: 0.8)
                    : SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                width: adjAbove ? 3 : 1,
              ),
              bottom: BorderSide(
                color: adjBelow
                    ? SpaceTheme.starYellow.withValues(alpha: 0.8)
                    : SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                width: adjBelow ? 3 : 1,
              ),
              left: BorderSide(
                color: adjLeft
                    ? SpaceTheme.starYellow.withValues(alpha: 0.8)
                    : SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                width: adjLeft ? 3 : 1,
              ),
              right: BorderSide(
                color: adjRight
                    ? SpaceTheme.starYellow.withValues(alpha: 0.8)
                    : SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                width: adjRight ? 3 : 1,
              ),
            ),
            boxShadow: isColored
                ? [BoxShadow(
                    color: color!.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )]
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${region + 1}',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: innerSize * 0.3,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isColored)
                  Icon(
                    Icons.touch_app,
                    color: Colors.white38,
                    size: innerSize * 0.2,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _computeGridCols(int count) {
    if (count <= 4) return 2;
    if (count <= 6) return 3;
    if (count <= 9) return 3;
    return 4;
  }

  Widget _buildCheckButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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

/// Paints adjacency lines between grid-positioned territories.
class _TerritoryMapPainter extends CustomPainter {
  final SectorPainterPuzzle puzzle;
  final Map<int, int> coloring;
  final List<Color> paletteColors;
  final double glowValue;
  final int cols;
  final int rows;
  final double cellSize;

  _TerritoryMapPainter({
    required this.puzzle,
    required this.coloring,
    required this.paletteColors,
    required this.glowValue,
    required this.cols,
    required this.rows,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.35 * glowValue)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final regionCount = puzzle.regions.length;

    // Draw adjacency lines between non-grid-adjacent regions (diagonal/cross connections)
    for (final region in puzzle.regions) {
      final fromCol = region % cols;
      final fromRow = region ~/ cols;
      final fromCenter = Offset(
        (fromCol + 0.5) * cellSize,
        (fromRow + 0.5) * cellSize,
      );

      for (final neighbor in puzzle.adjacency[region] ?? <int>{}) {
        if (neighbor > region && neighbor < regionCount) {
          final toCol = neighbor % cols;
          final toRow = neighbor ~/ cols;

          // Only draw lines for non-immediate-grid-neighbors
          final dCol = (toCol - fromCol).abs();
          final dRow = (toRow - fromRow).abs();
          final isGridNeighbor = (dCol + dRow) == 1;

          if (!isGridNeighbor) {
            final toCenter = Offset(
              (toCol + 0.5) * cellSize,
              (toRow + 0.5) * cellSize,
            );
            canvas.drawLine(fromCenter, toCenter, linePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TerritoryMapPainter oldDelegate) =>
      oldDelegate.glowValue != glowValue || oldDelegate.coloring != coloring;
}
