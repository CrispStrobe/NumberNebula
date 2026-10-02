import '../services/generation_configs.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
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
import '../services/relic_assembly_logic.dart';
import 'package:flutter/foundation.dart';

class RelicAssemblyGame extends StatefulWidget {
  final int grade;
  final int level;
  const RelicAssemblyGame({super.key, required this.grade, required this.level});

  @override
  State<RelicAssemblyGame> createState() => _RelicAssemblyGameState();
}

class _RelicAssemblyGameState extends State<RelicAssemblyGame>
    with TickerProviderStateMixin, GameAnimationsMixin<RelicAssemblyGame>, PuzzleSessionMixin<RelicAssemblyGame> {
  bool _sessionReady = false;
  @override String get sessionGameKey => 'relic_assembly';
  @override int get sessionGrade => widget.grade;
  @override int get sessionLevel => widget.level;
  @override Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      'placement': placement.map((v0) => v0).toList(),
      'rotations': rotations.map((v0) => v0).toList(),
      '_placements': _placements,
      'selectedTileIndex': (selectedTileIndex)
    };
  }
  @override void applyPuzzleSession(Map<String, dynamic> state) {
    puzzle = (state["puzzle"] == null ? null : RelicAssemblyPuzzle.fromJson(Map<String, dynamic>.from(state["puzzle"] as Map)));
    placement = (state["placement"] as List).map((v0) => v0 as int).toList();
    rotations = (state["rotations"] as List).map((v0) => v0 as int).toList();
    _placements = state["_placements"] as int;
    selectedTileIndex = (state["selectedTileIndex"] == null ? null : state["selectedTileIndex"] as int);
    _isGenerating = false;
  }
  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }


  RelicAssemblyPuzzle? puzzle;
  bool _isGenerating = true;

  /// Tiles placed, including re-placements — a flawless fit places each once.
  int _placements = 0;
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
    initGameAnimations(usePulse: false);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level, gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  int _getRows() => RelicAssemblyGenerationConfig(currentDifficulty?.grade ?? widget.grade, currentDifficulty?.level ?? widget.level).getRows();

  int _getCols() => RelicAssemblyGenerationConfig(currentDifficulty?.grade ?? widget.grade, currentDifficulty?.level ?? widget.level).getCols();

  int _getEdgeValueCount() => RelicAssemblyGenerationConfig(currentDifficulty?.grade ?? widget.grade, currentDifficulty?.level ?? widget.level).getEdgeValueCount();

  Future<void> _generatePuzzle() async {
    beginPuzzleSession();
    setState(() {
      _isGenerating = true;
      _placements = 0;
      selectedTileIndex = null;
      successController.reset();
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
      if (kDebugMode) debugPrint('[RelicAssembly] Error generating puzzle: $e');
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
    AppHaptics.selectionClick();
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
      _placements++;

      // If there was a tile here, don't auto-select it
    });

    AppHaptics.lightImpact();
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
    AppHaptics.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      skillLevel: widget.grade,
      gameType: 'relic_assembly',
      difficulty: widget.level,
      score: totalScore,
      performance: Perf.fromMoves(_placements, placement.length),

      movesUsed: _placements,
      optimalMoves: placement.length,
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
    if (!_sessionReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
    // Fill the space the board is given rather than a fixed 80px: on a tablet
    // the old cap left the pieces thumbnail-sized with most of the screen
    // empty, and the edge glyphs scale with the cell.
    return LayoutBuilder(builder: (context, constraints) {
    final cellSize = math.min(
      (constraints.maxWidth - 60) / cols,
      (constraints.maxHeight - 40) / rows,
    ).clamp(48.0, 140.0);

    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.planetOrange.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.planetOrange.withValues(alpha: glowAnimation.value),
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
    });
  }

  Widget _buildGridSlot(int pos, double cellSize) {
    final tileIdx = placement[pos];

    if (tileIdx >= 0) {
      final tile = puzzle!.playerTiles[tileIdx];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Tap to rotate on the grid
          _rotateTile(tileIdx);
          _checkSolution();
        },
        onLongPress: () => _removeTileFromGrid(pos),
        child: Stack(
          children: [
            _buildTileWidget(tile, rotations[tileIdx], cellSize, false, gridPos: pos),
            // Rotate indicator
            Positioned(
              top: 2, right: 2,
              child: Icon(Icons.rotate_right, size: 14,
                color: SpaceTheme.starYellow.withValues(alpha: 0.7)),
            ),
            // Taking a piece back off the grid used to be long-press only,
            // with nothing on screen to suggest it -- so a misplaced piece
            // looked permanent and the puzzle looked unplayable.
            Positioned(
              bottom: 2, right: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _removeTileFromGrid(pos),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: SpaceTheme.rocketRed.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty slot -- accepts drag OR tap (if tile selected)
    return DragTarget<int>(
      builder: (context, candidates, _) {
        final isHovering = candidates.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
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

    return LayoutBuilder(builder: (context, constraints) {
    // As large as the tray allows (up to 110px), so the edge glyphs are
    // readable and a child's finger can hit a piece.
    final count = math.max(1, availableTiles.length);
    final tileSize = math.min(
      (constraints.maxWidth - 64 - 8 * (count - 1)) / count,
      constraints.maxHeight - 32,
    ).clamp(56.0, 110.0);

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
                      behavior: HitTestBehavior.opaque,
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
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _rotateTile(idx),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: const Icon(Icons.rotate_right, color: Colors.white70, size: 20),
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
    });
  }

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: ScrollableRoundDialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundSummary(gameKey: 'relic_assembly'),
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
