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
import '../services/relic_assembly_logic.dart';

class RelicAssemblyGame extends StatefulWidget {
  final int grade;
  final int level;
  const RelicAssemblyGame({super.key, required this.grade, required this.level});

  @override
  State<RelicAssemblyGame> createState() => _RelicAssemblyGameState();
}

class _RelicAssemblyGameState extends State<RelicAssemblyGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  RelicAssemblyPuzzle? puzzle;
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;

  // Player's grid: position index -> tile index in playerTiles
  late List<int> placement;
  // Player's rotations: tile index -> rotation (0-3)
  late List<int> rotations;
  // Selected tile for placement (from tray)
  int? selectedTileIndex;

  // Glyph symbols for display
  static const _glyphSymbols = ['1', '2', '3', '4', '5', '6', '7', '8'];
  static const _glyphColors = [
    Color(0xFFFF6B35),
    Color(0xFF6B48FF),
    Color(0xFF06FFA5),
    Color(0xFFE63946),
    Color(0xFFFFD700),
    Color(0xFF00C9DB),
    Color(0xFFFF69B4),
    Color(0xFF8B8B8B),
  ];

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

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

  int _getRows() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 2;
    if (grade <= 2) return 2;
    return 3;
  }

  int _getCols() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 2;
    if (grade <= 2) return 3;
    return 3;
  }

  int _getEdgeValueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    // More edge values = harder
    const base = 3;
    final bonus = (level / 5).floor();
    return (base + bonus).clamp(3, 7);
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      selectedTileIndex = null;
      _successController.reset();
    });

    try {
      final generator = RelicAssemblyGenerator();
      final p = await generator.generate(
        rows: _getRows(),
        cols: _getCols(),
        edgeValueCount: _getEdgeValueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;
          placement = List.filled(p.rows * p.cols, -1);
          rotations = List.generate(p.playerTiles.length, (i) => p.playerTiles[i].rotation);
          _isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint('[RelicAssembly] Error generating puzzle: $e');
    }
  }

  void _selectTile(int tileIdx) {
    setState(() {
      if (selectedTileIndex == tileIdx) {
        selectedTileIndex = null;
      } else {
        selectedTileIndex = tileIdx;
      }
    });
  }

  void _rotateTile(int tileIdx) {
    setState(() {
      rotations[tileIdx] = (rotations[tileIdx] + 1) % 4;
    });
    HapticFeedback.selectionClick();
  }

  void _placeTileAt(int gridPos) {
    if (selectedTileIndex == null) return;

    setState(() {
      // Remove tile from previous position if any
      for (int i = 0; i < placement.length; i++) {
        if (placement[i] == selectedTileIndex) {
          placement[i] = -1;
        }
      }
      // Place tile at this position
      placement[gridPos] = selectedTileIndex!;
      selectedTileIndex = null;

      // If there was a tile here, don't auto-select it
    });

    HapticFeedback.lightImpact();
    _checkSolution();
  }

  void _removeTileFromGrid(int gridPos) {
    setState(() {
      placement[gridPos] = -1;
    });
  }

  void _checkSolution() {
    // Check if all positions are filled
    if (placement.any((p) => p < 0)) return;

    if (puzzle!.validatePlacement(placement, rotations)) {
      _handleWin();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'relic_assembly',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildWinDialog(totalScore),
      );
    }
  }

  /// Check if the edge of a placed tile at grid position [pos] matches
  /// its neighbor on the given [side] (0=top, 1=right, 2=bottom, 3=left).
  /// Returns null if no neighbor, true if match, false if mismatch.
  bool? _edgeMatches(int pos, int side) {
    if (puzzle == null) return null;
    final tileIdx = placement[pos];
    if (tileIdx < 0) return null;

    final row = pos ~/ puzzle!.cols;
    final col = pos % puzzle!.cols;
    int neighborPos = -1;
    int neighborSide = -1;

    switch (side) {
      case 0: // top
        if (row == 0) return null;
        neighborPos = pos - puzzle!.cols;
        neighborSide = 2; // neighbor's bottom
      case 1: // right
        if (col >= puzzle!.cols - 1) return null;
        neighborPos = pos + 1;
        neighborSide = 3; // neighbor's left
      case 2: // bottom
        if (row >= puzzle!.rows - 1) return null;
        neighborPos = pos + puzzle!.cols;
        neighborSide = 0; // neighbor's top
      case 3: // left
        if (col == 0) return null;
        neighborPos = pos - 1;
        neighborSide = 1; // neighbor's right
    }

    if (neighborPos < 0 || neighborPos >= placement.length) return null;
    final neighborTileIdx = placement[neighborPos];
    if (neighborTileIdx < 0) return null;

    final tile = puzzle!.playerTiles[tileIdx].copyWith(rotation: rotations[tileIdx]);
    final neighbor = puzzle!.playerTiles[neighborTileIdx].copyWith(rotation: rotations[neighborTileIdx]);
    return tile.getEdge(side) == neighbor.getEdge(neighborSide);
  }

  Set<int> _getPlacedTileIndices() {
    return placement.where((p) => p >= 0).toSet();
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
                title: s.relicAssemblyTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.relicAssemblyInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: _buildGridArea(),
              ),
              Expanded(
                flex: 2,
                child: _buildTileTray(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    final rows = puzzle!.rows;
    final cols = puzzle!.cols;
    const maxCellSize = 80.0;
    final cellSize = math.min(maxCellSize, (MediaQuery.of(context).size.width - 80) / cols);

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.planetOrange.withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.planetOrange.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(cols, (c) {
                    final pos = r * cols + c;
                    return _buildGridSlot(pos, cellSize);
                  }),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridSlot(int pos, double cellSize) {
    final tileIdx = placement[pos];

    if (tileIdx >= 0) {
      final tile = puzzle!.playerTiles[tileIdx];
      return GestureDetector(
        onTap: () => _removeTileFromGrid(pos),
        child: _buildTileWidget(tile, rotations[tileIdx], cellSize, false, gridPos: pos),
      );
    }

    // Empty slot -- accepts drag OR tap (if tile selected)
    return DragTarget<int>(
      builder: (context, candidates, _) {
        final isHovering = candidates.isNotEmpty;
        return GestureDetector(
          onTap: () => _placeTileAt(pos),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: cellSize,
            height: cellSize,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isHovering
                  ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                  : selectedTileIndex != null
                      ? SpaceTheme.starYellow.withValues(alpha: 0.15)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering
                    ? SpaceTheme.starYellow
                    : selectedTileIndex != null
                        ? SpaceTheme.starYellow.withValues(alpha: 0.7)
                        : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                width: isHovering ? 3 : (selectedTileIndex != null ? 2 : 1),
              ),
              boxShadow: isHovering
                  ? [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                size: cellSize * 0.3,
              ),
            ),
          ),
        );
      },
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        setState(() => selectedTileIndex = details.data);
        _placeTileAt(pos);
      },
    );
  }

  Widget _buildTileWidget(RelicTile tile, int rotation, double size, bool isSelected, {int? gridPos}) {
    final effectiveTile = tile.copyWith(rotation: rotation);
    final edgeSize = size * 0.25;

    // Check edge matches if this tile is placed on the grid
    final topMatch = gridPos != null ? _edgeMatches(gridPos, 0) : null;
    final rightMatch = gridPos != null ? _edgeMatches(gridPos, 1) : null;
    final bottomMatch = gridPos != null ? _edgeMatches(gridPos, 2) : null;
    final leftMatch = gridPos != null ? _edgeMatches(gridPos, 3) : null;

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? SpaceTheme.starYellow.withValues(alpha: 0.3)
            : SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Top edge
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(child: _buildEdgeLabel(effectiveTile.getEdge(0), edgeSize, matchState: topMatch)),
          ),
          // Right edge
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: Center(child: _buildEdgeLabel(effectiveTile.getEdge(1), edgeSize, matchState: rightMatch)),
          ),
          // Bottom edge
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(child: _buildEdgeLabel(effectiveTile.getEdge(2), edgeSize, matchState: bottomMatch)),
          ),
          // Left edge
          Positioned(
            left: 2,
            top: 0,
            bottom: 0,
            child: Center(child: _buildEdgeLabel(effectiveTile.getEdge(3), edgeSize, matchState: leftMatch)),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeLabel(int value, double size, {bool? matchState}) {
    final colorIdx = (value - 1).clamp(0, _glyphColors.length - 1);
    // Edge match feedback: green border for match, red for mismatch
    Color bgColor = _glyphColors[colorIdx].withValues(alpha: 0.3);
    Color? borderColor;
    if (matchState == true) {
      bgColor = SpaceTheme.alienGreen.withValues(alpha: 0.4);
      borderColor = SpaceTheme.alienGreen;
    } else if (matchState == false) {
      bgColor = SpaceTheme.rocketRed.withValues(alpha: 0.4);
      borderColor = SpaceTheme.rocketRed;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          _glyphSymbols[colorIdx],
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            color: _glyphColors[colorIdx],
          ),
        ),
      ),
    );
  }

  Widget _buildTileTray() {
    final placedIndices = _getPlacedTileIndices();
    final availableTiles = <int>[];
    for (int i = 0; i < puzzle!.playerTiles.length; i++) {
      if (!placedIndices.contains(i)) {
        availableTiles.add(i);
      }
    }

    const tileSize = 65.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: availableTiles.isEmpty
          ? Center(
              child: Text(
                S.of(context)!.relicAssemblyInstructions,
                style: SpaceTheme.bodyStyle.copyWith(color: Colors.white70),
              ),
            )
          : SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: availableTiles.map((idx) {
                  final isSelected = selectedTileIndex == idx;
                  return Draggable<int>(
                    data: idx,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(
                            color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                            blurRadius: 15, spreadRadius: 3,
                          )],
                        ),
                        child: _buildTileWidget(
                          puzzle!.playerTiles[idx], rotations[idx], tileSize, true,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildTileWidget(
                        puzzle!.playerTiles[idx], rotations[idx], tileSize, false,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () => _selectTile(idx),
                      onLongPress: () => _rotateTile(idx),
                      child: Stack(
                        children: [
                          _buildTileWidget(
                            puzzle!.playerTiles[idx], rotations[idx], tileSize, isSelected,
                          ),
                          // Rotate button overlay
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _rotateTile(idx),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: const Icon(Icons.rotate_right, color: Colors.white70, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
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
                  const Icon(Icons.dashboard_customize_outlined, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.relicAssemblyWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.relicAssemblyWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
