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
import '../services/nebula_matrix_logic.dart';
import 'package:flutter/foundation.dart';

class NebulaMatrixGame extends StatefulWidget {
  final int grade;
  final int level;
  const NebulaMatrixGame({super.key, required this.grade, required this.level});

  @override
  State<NebulaMatrixGame> createState() => _NebulaMatrixGameState();
}

class _NebulaMatrixGameState extends State<NebulaMatrixGame>
    with TickerProviderStateMixin, GameAnimationsMixin<NebulaMatrixGame> {
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  NebulaMatrixPuzzle? puzzle;
  Map<String, int> userSolution = {};
  bool _isGenerating = true;
  String _lastDroppedCell = '';
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;

  /// Cells the player has to fill — a flawless solve places each exactly
  /// once, so it doubles as the optimal move count for the performance grade.
  int _optimalMoves = 0;

  @override
  void initState() {
    super.initState();
    initGameAnimations();


    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);


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
    _dropController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  int _getGridSize() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    if (grade <= 3) return 5;
    return 5;
  }

  int _getClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    final size = _getGridSize();
    final totalCells = size * size;
    // More clues at low levels, fewer at high levels
    final base = (totalCells * 0.6).round();
    final reduction = (level / 4).floor();
    return (base - reduction).clamp(size, totalCells - 1);
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userSolution.clear();
      successController.reset();
    });

    try {
      final generator = NebulaMatrixGenerator();
      final p = await generator.generate(
        size: _getGridSize(),
        clueCount: _getClueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;

          // Calculate max moves: 2x empty cells (generous safety net)
          final emptyCount = p.emptyCells.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) debugPrint('[NebulaMatrix] Max moves allowed: $_maxMoves for ${p.emptyCells.length} empty cells');
      }
    } catch (e) {
      debugPrint('[NebulaMatrix] Error generating puzzle: $e');
    }
  }

  void _placeNumber(int number, String cellId) {
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedCell = cellId;
      _dropController.forward(from: 0.0);

      // Decrement moves on placement
      _movesRemaining--;
      if (kDebugMode) debugPrint('[NebulaMatrix] Moves remaining: $_movesRemaining/$_maxMoves');
    });

    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }

    _checkSolution();
  }

  void _removeNumber(String cellId) {
    setState(() {
      userSolution.remove(cellId);
    });
  }

  void _checkSolution() {
    if (userSolution.length != puzzle!.emptyCells.length) return;

    if (puzzle!.validateSolution(userSolution)) {
      _handleWin();
    } else {
      _handleIncorrect();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.size * puzzle!.size * 10;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'nebula_matrix',
      difficulty: widget.level,
      score: totalScore,
        performance: Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),
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

  void _handleIncorrect() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.nebulaMatrixLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleFailure() {
    if (kDebugMode) debugPrint('[NebulaMatrix] FAILURE - recording loss');
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'nebula_matrix',
      difficulty: widget.level,
        progress: _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
    ));
  }

  void _handleOutOfMoves() {
    if (kDebugMode) debugPrint('[NebulaMatrix] Out of moves! Game over.');
    _handleFailure();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildOutOfMovesDialog(),
      );
    }
  }

  Widget _buildOutOfMovesDialog() {
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
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.nebulaMatrixOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.nebulaMatrixOutOfMovesDesc,
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

  Widget _buildMovesIndicator() {
    Color indicatorColor;
    if (_movesRemaining <= 3) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (_movesRemaining <= 5) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.cosmicPink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: indicatorColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: indicatorColor, size: 18),
          const SizedBox(width: 6),
          Text(
            '$_movesRemaining',
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: 14,
              color: indicatorColor,
            ),
          ),
        ],
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
                title: s.nebulaMatrixTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        puzzle!.zones.isNotEmpty
                            ? s.nebulaMatrixInstructionsZones
                            : s.nebulaMatrixInstructions,
                        style: SpaceTheme.bodyStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMovesIndicator(),
                  ],
                ),
              ),
              Expanded(child: _buildGridArea()),
              _buildNumberPad(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink.withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildGrid(),
          );
        },
      ),
    );
  }

  // Zone background tint colors (alternating for visual distinction)
  static const _zoneTints = [
    Color(0x15FF6B35), // warm orange tint
    Color(0x1506FFA5), // green tint
    Color(0x156B48FF), // purple tint
    Color(0x15FFD700), // yellow tint
    Color(0x15FF69B4), // pink tint
    Color(0x1500C9DB), // cyan tint
  ];

  Widget _buildGrid() {
    final gridSize = puzzle!.size;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCellW = (constraints.maxWidth - 32) / gridSize;
        final maxCellH = (constraints.maxHeight - 32) / gridSize;
        final cellSize = math.min(maxCellW, maxCellH).clamp(30.0, 65.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(gridSize, (row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(gridSize, (col) {
                final cellId = 'r${row}c$col';
                return _buildCell(cellId, cellSize, row, col);
              }),
            );
          }),
        );
      },
    );
  }

  Widget _buildCell(String cellId, double cellSize, int row, int col) {
    final isClue = puzzle!.clues.containsKey(cellId);
    final hasUserValue = userSolution.containsKey(cellId);
    final value = isClue ? puzzle!.clues[cellId] : userSolution[cellId];
    final isLastDropped = cellId == _lastDroppedCell;

    // Zone-aware border: thicker on zone boundaries
    final zoneIdx = puzzle!.getZoneIndex(row, col);
    final hasZones = puzzle!.zones.isNotEmpty;
    final zoneTint = hasZones && zoneIdx >= 0
        ? _zoneTints[zoneIdx % _zoneTints.length]
        : Colors.transparent;

    // Compute thick borders on zone edges
    double borderTop = 1, borderBottom = 1, borderLeft = 1, borderRight = 1;
    if (hasZones && zoneIdx >= 0) {
      if (row == 0 || puzzle!.getZoneIndex(row - 1, col) != zoneIdx) borderTop = 2.5;
      if (row == puzzle!.size - 1 || puzzle!.getZoneIndex(row + 1, col) != zoneIdx) borderBottom = 2.5;
      if (col == 0 || puzzle!.getZoneIndex(row, col - 1) != zoneIdx) borderLeft = 2.5;
      if (col == puzzle!.size - 1 || puzzle!.getZoneIndex(row, col + 1) != zoneIdx) borderRight = 2.5;
    }

    Border cellBorder = Border(
      top: BorderSide(color: SpaceTheme.moonSilver.withValues(alpha: 0.6), width: borderTop),
      bottom: BorderSide(color: SpaceTheme.moonSilver.withValues(alpha: 0.6), width: borderBottom),
      left: BorderSide(color: SpaceTheme.moonSilver.withValues(alpha: 0.6), width: borderLeft),
      right: BorderSide(color: SpaceTheme.moonSilver.withValues(alpha: 0.6), width: borderRight),
    );

    if (isClue) {
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: zoneTint,
          gradient: LinearGradient(
            colors: [SpaceTheme.alienGreen.withValues(alpha: 0.3), SpaceTheme.deepSpace.withValues(alpha: 0.8)],
          ),
          border: cellBorder,
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: cellSize * 0.45),
          ),
        ),
      );
    }

    if (hasUserValue) {
      Widget cell = Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: zoneTint,
          gradient: LinearGradient(
            colors: [SpaceTheme.deepSpace.withValues(alpha: 0.7), SpaceTheme.nebulaPurple.withValues(alpha: 0.4)],
          ),
          border: cellBorder,
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: cellSize * 0.45),
          ),
        ),
      );

      if (isLastDropped) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      return GestureDetector(
        onTap: () => _removeNumber(cellId),
        child: cell,
      );
    }

    // Empty cell - drag target
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: isHovering ? null : zoneTint,
                gradient: isHovering
                    ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                    : null,
                border: cellBorder,
              ),
              child: Transform.scale(
                scale: pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: SpaceTheme.nebulaPurple,
                    size: cellSize * 0.3,
                  ),
                ),
              ),
            );
          },
        );
      },
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _placeNumber(details.data, cellId),
    );
  }

  Widget _buildNumberPad() {
    final numbers = puzzle!.numberPool;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: numbers.map((n) {
          return Draggable<int>(
            data: n,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: SpaceTheme.starGradient,
                  boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20)],
                ),
                child: Center(child: Text(n.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 20))),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: _buildTrayTile(n)),
            child: _buildTrayTile(n),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrayTile(int number) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 16)),
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
                  const Icon(Icons.grid_on_rounded, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
