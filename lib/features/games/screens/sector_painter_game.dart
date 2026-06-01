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
  late AnimationController _conflictController;
  late Animation<double> _conflictAnimation;

  SectorPainterPuzzle? _puzzle;
  final Map<int, int> _coloring = {};
  int _selectedColor = 0;
  bool _isGenerating = true;
  bool _won = false;
  DifficultyConfig? currentDifficulty;
  Set<int> _conflictRegions = {};

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

    _conflictController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _conflictAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _conflictController, curve: Curves.easeOut));
    _conflictController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _conflictRegions = {});
        _conflictController.reset();
      }
    });

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
    _conflictController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _won = false;
      _coloring.clear();
      _conflictRegions = {};
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

    // Check for adjacent same-color conflicts and flash
    final hasConflicts = _checkConflicts();

    // Auto-check win when all regions colored with no conflicts
    if (!hasConflicts && _coloring.length == _puzzle!.regions.length) {
      if (_puzzle!.validateColoring(_coloring)) {
        // Small delay so the last color is visible before win dialog
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_won) _handleWin();
        });
      }
    }
  }

  bool _checkConflicts() {
    if (_puzzle == null) return false;
    final conflicts = _puzzle!.findConflicts(_coloring);
    if (conflicts.isNotEmpty) {
      final regions = <int>{};
      for (final pair in conflicts) {
        regions.add(pair[0]);
        regions.add(pair[1]);
      }
      setState(() => _conflictRegions = regions);
      _conflictController.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      return true;
    }
    return false;
  }

  void _handleWin() {
    if (_won) return;
    _won = true;
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
              _buildHeader(s),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 700;
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

  Widget _buildHeader(S s) {
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

  Widget _buildWideLayout(BoxConstraints constraints) {
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
                const SizedBox(height: 12),
                _buildMinColorsHint(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Column(
      children: [
        _buildColorPalette(),
        _buildMinColorsHint(),
        Expanded(child: _buildMapArea()),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMinColorsHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, color: SpaceTheme.starYellow, size: 16),
            const SizedBox(width: 6),
            Text(
              'Min colors: ${_puzzle!.chromaticNumber}',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12,
                color: SpaceTheme.starYellow,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Painted: ${_coloring.length}/${_puzzle!.regions.length}',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            ),
          ],
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
            behavior: HitTestBehavior.opaque,
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
        final availW = constraints.maxWidth - 32;
        final availH = constraints.maxHeight - 32;

        return Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_glowAnimation, _pulseAnimation, _conflictAnimation]),
            builder: (context, child) {
              return Container(
                width: availW + 16,
                height: availH + 16,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpaceTheme.starYellow
                        .withValues(alpha: _glowAnimation.value * 0.5),
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
                  painter: _GraphMapPainter(
                    puzzle: _puzzle!,
                    coloring: _coloring,
                    paletteColors: _paletteColors,
                    glowValue: _glowAnimation.value,
                    conflictRegions: _conflictRegions,
                    conflictValue: _conflictAnimation.value,
                    width: availW,
                    height: availH,
                  ),
                  child: Stack(
                    children: _puzzle!.regions.map((region) {
                      final pos = _puzzle!.positions[region];
                      final x = pos.x * availW;
                      final y = pos.y * availH;
                      final isColored = _coloring.containsKey(region);
                      final isConflict = _conflictRegions.contains(region);
                      final nodeRadius = _computeNodeRadius(availW, availH);

                      return Positioned(
                        left: x - nodeRadius,
                        top: y - nodeRadius,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _paintRegion(region),
                          child: _buildRegionNode(
                            region, nodeRadius * 2, isColored, isConflict,
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

  double _computeNodeRadius(double availW, double availH) {
    final regionCount = _puzzle!.regions.length;
    final area = availW * availH;
    // Base radius from available area
    final areaRadius = math.sqrt(area / regionCount) * 0.25;

    // Also compute from minimum distance between any two nodes
    double minDist = double.infinity;
    final positions = _puzzle!.positions;
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final dx = (positions[i].x - positions[j].x) * availW;
        final dy = (positions[i].y - positions[j].y) * availH;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < minDist) minDist = d;
      }
    }
    // Radius must be less than half the minimum distance so circles don't overlap
    final distRadius = minDist > 0 ? minDist * 0.4 : areaRadius;

    return math.min(areaRadius, distRadius).clamp(14.0, 35.0);
  }

  Widget _buildRegionNode(
      int region, double size, bool isColored, bool isConflict) {
    final color = isColored
        ? _paletteColors[_coloring[region]! % _paletteColors.length]
        : null;

    final scale = isColored ? 1.0 : _pulseAnimation.value;
    final conflictFlash = isConflict ? _conflictAnimation.value : 0.0;

    return Transform.scale(
      scale: scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isColored
              ? RadialGradient(
                  colors: [
                    Color.lerp(color!, Colors.white, 0.2)!,
                    color,
                    color.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                )
              : RadialGradient(
                  colors: [
                    SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
                    SpaceTheme.deepSpace.withValues(alpha: 0.9),
                  ],
                ),
          border: Border.all(
            color: isConflict
                ? Color.lerp(
                    Colors.transparent, SpaceTheme.rocketRed, conflictFlash)!
                : isColored
                    ? Colors.white.withValues(alpha: 0.6)
                    : SpaceTheme.starYellow.withValues(alpha: 0.5),
            width: isConflict ? 4 : 2,
          ),
          boxShadow: [
            if (isColored)
              BoxShadow(
                color: color!.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            if (isConflict)
              BoxShadow(
                color: SpaceTheme.rocketRed.withValues(alpha: conflictFlash * 0.8),
                blurRadius: 16,
                spreadRadius: 4,
              ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${region + 1}',
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: size * 0.3,
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
                  size: size * 0.2,
                ),
            ],
          ),
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
                  if (colorsUsed <= _puzzle!.chromaticNumber)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SpaceTheme.starYellow),
                        ),
                        child: Text(
                          'Optimal coloring!',
                          style: SpaceTheme.bodyStyle.copyWith(
                            color: SpaceTheme.starYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

/// Paints adjacency lines between graph-positioned regions.
class _GraphMapPainter extends CustomPainter {
  final SectorPainterPuzzle puzzle;
  final Map<int, int> coloring;
  final List<Color> paletteColors;
  final double glowValue;
  final Set<int> conflictRegions;
  final double conflictValue;
  final double width;
  final double height;

  _GraphMapPainter({
    required this.puzzle,
    required this.coloring,
    required this.paletteColors,
    required this.glowValue,
    required this.conflictRegions,
    required this.conflictValue,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.4 * glowValue)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final conflictLinePaint = Paint()
      ..color = SpaceTheme.rocketRed.withValues(alpha: conflictValue)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw all adjacency edges
    final drawn = <String>{};
    for (final region in puzzle.regions) {
      final fromPos = puzzle.positions[region];
      final fromCenter = Offset(fromPos.x * width, fromPos.y * height);

      for (final neighbor in puzzle.adjacency[region] ?? <int>{}) {
        final key = '${math.min(region, neighbor)}-${math.max(region, neighbor)}';
        if (drawn.contains(key)) continue;
        drawn.add(key);

        final toPos = puzzle.positions[neighbor];
        final toCenter = Offset(toPos.x * width, toPos.y * height);

        // Check if this edge is a conflict
        final isConflictEdge = conflictRegions.contains(region) &&
            conflictRegions.contains(neighbor) &&
            coloring[region] != null &&
            coloring[neighbor] != null &&
            coloring[region] == coloring[neighbor];

        canvas.drawLine(
          fromCenter,
          toCenter,
          isConflictEdge ? conflictLinePaint : linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphMapPainter oldDelegate) =>
      oldDelegate.glowValue != glowValue ||
      oldDelegate.coloring != coloring ||
      oldDelegate.conflictValue != conflictValue ||
      oldDelegate.conflictRegions != conflictRegions;
}
