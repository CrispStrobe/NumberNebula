import '../services/generation_configs.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';
import '../mixins/puzzle_session_mixin.dart';

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

/// The originating round remains attached even if a drag crosses restoration.
typedef NebulaMatrixDrag = ({int number, Object round});

class NebulaMatrixGame extends StatefulWidget {
  final int grade;
  final int level;
  const NebulaMatrixGame({super.key, required this.grade, required this.level});

  @override
  State<NebulaMatrixGame> createState() => _NebulaMatrixGameState();
}

class _NebulaMatrixGameState extends State<NebulaMatrixGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<NebulaMatrixGame>,
        PuzzleSessionMixin<NebulaMatrixGame> {
  Object _round = Object();
  bool _gameOver = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_gameOver &&
      puzzle != null;

  bool _canPlace(NebulaMatrixDrag drag, String cellId, Object round) =>
      _canInteract(round) &&
      identical(drag.round, _round) &&
      _movesRemaining > 0 &&
      puzzle!.numberPool.contains(drag.number) &&
      puzzle!.emptyCells.contains(cellId) &&
      !userSolution.containsKey(cellId);

  bool _isSolved() =>
      puzzle != null &&
      userSolution.length == puzzle!.emptyCells.length &&
      puzzle!.validateSolution(userSolution);

  void _invalidateRoundEffects({bool cancelDrop = true}) {
    _round = Object();
    if (cancelDrop) cancelOneShotMotion(_dropController);
    cancelOneShotMotion(successController);
  }

  void _resetRoundEffects() {
    _invalidateRoundEffects();
    _dropController.reset();
    successController.reset();
    _lastDroppedCell = '';
    _clearFeedback();
  }

  void _clearFeedback() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(_dropController, reduced,
        duration: const Duration(milliseconds: 500));
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

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
  String get sessionGameKey => 'nebula_matrix';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (puzzle == null || _isGenerating || _gameOver) return null;
    return {
      'puzzle': puzzle!.toJson(),
      'answers': userSolution,
      'moves': _movesRemaining,
      'maxMoves': _maxMoves,
      'optimal': _optimalMoves
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle =
        NebulaMatrixPuzzle.fromJson(Map<String, dynamic>.from(state['puzzle']));
    userSolution = Map<String, int>.from(state['answers']);
    _movesRemaining = state['moves'];
    _maxMoves = state['maxMoves'];
    _optimalMoves = state['optimal'];
    _isGenerating = false;
    final solved = _isSolved();
    _gameOver = solved || _movesRemaining <= 0;
    if (_gameOver) {
      finishPuzzleSession();
      final round = _round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !identical(round, _round) ||
            !_gameOver ||
            _isGenerating) {
          return;
        }
        if (solved) {
          _showWinDialog(_winScore(), round);
        } else {
          _showOutOfMovesDialog(round);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) _generatePuzzle();
  }

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation =
        CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level,
            gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _invalidateRoundEffects();
    _dropController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  int _getGridSize() => NebulaMatrixGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getGridSize();

  int _getClueCount() => NebulaMatrixGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getClueCount();

  void _generatePuzzle() async {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    setState(() {
      _isGenerating = true;
      _gameOver = false;
      userSolution.clear();
      successController.reset();
    });

    try {
      final generator = NebulaMatrixGenerator();
      final p = await generator.generate(
        size: _getGridSize(),
        clueCount: _getClueCount(),
      );

      if (mounted && identical(round, _round)) {
        setState(() {
          puzzle = p;

          // Calculate max moves: 2x empty cells (generous safety net)
          final emptyCount = p.emptyCells.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) {
          debugPrint(
              '[NebulaMatrix] Max moves allowed: $_maxMoves for ${p.emptyCells.length} empty cells');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NebulaMatrix] Error generating puzzle: $e');
      }
    }
  }

  void _placeNumber(NebulaMatrixDrag drag, String cellId, Object round) {
    if (!_canPlace(drag, cellId, round)) return;
    setState(() {
      userSolution[cellId] = drag.number;
      _lastDroppedCell = cellId;
      _movesRemaining--;
    });
    _dropController.reset();
    playOneShotMotion(_dropController, () {});
    _checkSolution();
  }

  void _removeNumber(String cellId, int? expected, Object round) {
    if (!_canInteract(round) ||
        !puzzle!.emptyCells.contains(cellId) ||
        expected == null ||
        userSolution[cellId] != expected) {
      return;
    }
    setState(() => userSolution.remove(cellId));
  }

  void _checkSolution() {
    if (!_canInteract(_round)) return;
    // A correct final placement wins, including the last available move.
    if (_isSolved()) {
      _handleWin();
    } else if (_movesRemaining <= 0) {
      _handleOutOfMoves();
    } else if (userSolution.length == puzzle!.emptyCells.length) {
      _handleIncorrect();
    }
  }

  int _winScore() =>
      100 * widget.grade + widget.level * 25 + puzzle!.size * puzzle!.size * 10;

  void _handleWin() {
    if (!_canInteract(_round) || !_isSolved()) return;
    _invalidateRoundEffects(cancelDrop: false);
    _clearFeedback();
    setState(() => _gameOver = true);
    final round = _round;
    finishPuzzleSession();
    AppHaptics.lightImpact();
    final totalScore = _winScore();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'nebula_matrix',
          difficulty: widget.level,
          score: totalScore,
          performance:
              Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),
          movesUsed: _maxMoves - _movesRemaining,
          optimalMoves: _optimalMoves,
        ));

    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int score, Object round) {
    if (!mounted || !identical(round, _round) || !_gameOver || puzzle == null) {
      return;
    }
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildWinDialog(score, round, dialogContext),
    );
  }

  void _handleIncorrect() {
    AppHaptics.heavyImpact();
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
          skillLevel: widget.grade,
          gameType: 'nebula_matrix',
          difficulty: widget.level,
          progress:
              _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
        ));
  }

  void _handleOutOfMoves() {
    if (!_canInteract(_round) || _movesRemaining > 0) return;
    _invalidateRoundEffects(cancelDrop: false);
    _clearFeedback();
    setState(() => _gameOver = true);
    final round = _round;
    finishPuzzleSession();
    if (kDebugMode) debugPrint('[NebulaMatrix] Out of moves! Game over.');
    _handleFailure();

    _showOutOfMovesDialog(round);
  }

  void _showOutOfMovesDialog(Object round) {
    if (!mounted || !identical(round, _round) || !_gameOver || puzzle == null) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildOutOfMovesDialog(round, dialogContext),
    );
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _gameOver &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  Widget _buildOutOfMovesDialog(Object round, BuildContext dialogContext) {
    final s = S.of(context)!;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundSummary(gameKey: 'nebula_matrix'),
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.nebulaMatrixOutOfMoves,
              style: SpaceTheme.headlineStyle
                  .copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.nebulaMatrixOutOfMovesDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              overflowAlignment: OverflowBarAlignment.center,
              spacing: 16,
              overflowSpacing: 12,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    if (!_canUseDialog(round, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.tryAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_canUseDialog(round, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
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
    final round = _round;

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
                key: ValueKey(('nebula-header', round)),
                title: s.nebulaMatrixTitle,
                level: widget.level,
                onBack: () {
                  if (mounted && identical(round, _round) && !_isGenerating) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        child: _buildGrid(),
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink
                      .withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink
                    .withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: child,
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
    final round = _round;
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
      if (row == 0 || puzzle!.getZoneIndex(row - 1, col) != zoneIdx) {
        borderTop = 2.5;
      }
      if (row == puzzle!.size - 1 ||
          puzzle!.getZoneIndex(row + 1, col) != zoneIdx) {
        borderBottom = 2.5;
      }
      if (col == 0 || puzzle!.getZoneIndex(row, col - 1) != zoneIdx) {
        borderLeft = 2.5;
      }
      if (col == puzzle!.size - 1 ||
          puzzle!.getZoneIndex(row, col + 1) != zoneIdx) {
        borderRight = 2.5;
      }
    }

    Border cellBorder = Border(
      top: BorderSide(
          color: SpaceTheme.moonSilver.withValues(alpha: 0.6),
          width: borderTop),
      bottom: BorderSide(
          color: SpaceTheme.moonSilver.withValues(alpha: 0.6),
          width: borderBottom),
      left: BorderSide(
          color: SpaceTheme.moonSilver.withValues(alpha: 0.6),
          width: borderLeft),
      right: BorderSide(
          color: SpaceTheme.moonSilver.withValues(alpha: 0.6),
          width: borderRight),
    );

    if (isClue) {
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: zoneTint,
          gradient: LinearGradient(
            colors: [
              SpaceTheme.alienGreen.withValues(alpha: 0.3),
              SpaceTheme.deepSpace.withValues(alpha: 0.8)
            ],
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
            colors: [
              SpaceTheme.deepSpace.withValues(alpha: 0.7),
              SpaceTheme.nebulaPurple.withValues(alpha: 0.4)
            ],
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
        key: ValueKey(('nebula-filled', round, cellId, value)),
        onTap: () => _removeNumber(cellId, value, round),
        child: cell,
      );
    }

    // Empty cell - drag target
    return DragTarget<NebulaMatrixDrag>(
      key: ValueKey(('nebula-target', round, cellId)),
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
                    ? const LinearGradient(colors: [
                        SpaceTheme.starYellow,
                        SpaceTheme.planetOrange
                      ])
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
      onWillAcceptWithDetails: (details) =>
          _canPlace(details.data, cellId, round),
      onAcceptWithDetails: (details) =>
          _placeNumber(details.data, cellId, round),
    );
  }

  Widget _buildNumberPad() {
    final round = _round;
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
          return Draggable<NebulaMatrixDrag>(
            key: ValueKey(('nebula-number', round, n)),
            maxSimultaneousDrags:
                _canInteract(round) && _movesRemaining > 0 ? 1 : 0,
            data: (number: n, round: round),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: SpaceTheme.starGradient,
                  boxShadow: [
                    BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                        blurRadius: 20)
                  ],
                ),
                child: Center(
                    child: Text(n.toString(),
                        style:
                            SpaceTheme.headlineStyle.copyWith(fontSize: 20))),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _buildWinDialog(int score, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'nebula_matrix'),
                  const Icon(Icons.grid_on_rounded,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinDesc(score),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    overflowAlignment: OverflowBarAlignment.center,
                    spacing: 16,
                    overflowSpacing: 12,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) return;
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) return;
                          Navigator.of(dialogContext).pop();
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
