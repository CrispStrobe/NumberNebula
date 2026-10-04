import 'package:space_math_academy/core/services/app_haptics.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
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
import '../services/dark_matter_grid_logic.dart';

class DarkMatterGridGame extends StatefulWidget {
  final int grade;
  final int level;
  const DarkMatterGridGame(
      {super.key, required this.grade, required this.level});

  @override
  State<DarkMatterGridGame> createState() => _DarkMatterGridGameState();
}

class _DarkMatterGridGameState extends State<DarkMatterGridGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<DarkMatterGridGame>,
        PuzzleSessionMixin<DarkMatterGridGame> {
  Object _round = Object();
  bool _reducedMotion = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      puzzle != null &&
      grid.length == puzzle!.size &&
      grid.every((row) => row.length == puzzle!.size);

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    successController.reset();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    _reducedMotion = reduced;
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  DifficultyConfig? currentDifficulty;
  DarkMatterGridPuzzle? puzzle;
  late List<List<bool>> grid;
  int moveCount = 0;
  bool _isGenerating = true;
  bool _won = false;

  @override
  String get sessionGameKey => 'dark_matter_grid';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (puzzle == null || _isGenerating || _won) return null;
    return {'puzzle': puzzle!.toJson(), 'grid': grid, 'moves': moveCount};
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle = DarkMatterGridPuzzle.fromJson(
        Map<String, dynamic>.from(state['puzzle']));
    grid = (state['grid'] as List).map((v) => List<bool>.from(v)).toList();
    moveCount = state['moves'];
    _isGenerating = false;
    _won = DarkMatterGridPuzzle.isSolved(grid);
    if (_won) {
      finishPuzzleSession();
      final round = _round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(round, _round) || !_won || _isGenerating) {
          return;
        }
        _showWinDialog(_winScore(), round);
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
    initGameAnimations(usePulse: false);

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
    _round = Object();
    cancelOneShotMotion(successController);
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    _resetRoundEffects();
    beginPuzzleSession();
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _won = false;
      moveCount = 0;
      successController.reset();
    });

    final grade = currentDifficulty!.grade;
    int gridSize;
    if (grade <= 1) {
      gridSize = 3;
    } else if (grade <= 2) {
      gridSize = 4;
    } else {
      gridSize = 5;
    }

    // More toggles at higher levels = harder
    final toggleCount =
        (gridSize + currentDifficulty!.level).clamp(3, gridSize * gridSize - 1);

    puzzle = DarkMatterGridPuzzle.generate(
      gridSize: gridSize,
      toggleCount: toggleCount,
    );

    setState(() {
      grid = puzzle!.grid.map(List<bool>.from).toList();
      _isGenerating = false;
    });
  }

  void _onCellTap(int row, int col, Object round) {
    if (!_canInteract(round) ||
        row < 0 ||
        col < 0 ||
        row >= grid.length ||
        col >= grid[row].length) {
      return;
    }

    AppHaptics.selectionClick();

    setState(() {
      grid = DarkMatterGridPuzzle.toggle(grid, row, col);
      moveCount++;
    });

    if (DarkMatterGridPuzzle.isSolved(grid)) {
      _handleWin();
    }
  }

  int _winScore() {
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int moveBonus = (puzzle!.minMoves * 50) ~/ (moveCount.clamp(1, 999));
    return baseScore + levelBonus + moveBonus;
  }

  void _handleWin() {
    if (!_canInteract(_round) || !DarkMatterGridPuzzle.isSolved(grid)) return;
    _resetRoundEffects();
    setState(() => _won = true);
    final round = _round;
    finishPuzzleSession();
    AppHaptics.lightImpact();
    final totalScore = _winScore();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'dark_matter_grid',
          difficulty: widget.level,
          score: totalScore,
          performance: Perf.fromMoves(moveCount, puzzle!.minMoves),
          movesUsed: moveCount,
          optimalMoves: puzzle!.minMoves,
        ));

    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int score, Object round) {
    if (!mounted || !identical(round, _round) || !_won || puzzle == null) {
      return;
    }
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildWinDialog(score, round, dialogContext),
    );
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _won &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final round = _round;

    if (_isGenerating || puzzle == null) {
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
                key: ValueKey(('dark-header', round)),
                title: s.darkMatterGridTitle,
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
                child: Text(
                  s.darkMatterGridInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('${s.level}: ${widget.level}',
                        style: SpaceTheme.titleStyle.copyWith(fontSize: 14)),
                    Text(s.roundMoves(moveCount),
                        style: SpaceTheme.titleStyle.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              Expanded(child: _buildGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final gridSize = puzzle!.size;
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Include 24px padding, the 4px border, and each cell's 6px margin.
          final maxCellW = (constraints.maxWidth - 28) / gridSize - 6;
          final maxCellH = (constraints.maxHeight - 28) / gridSize - 6;
          final cellSize = maxCellW < maxCellH ? maxCellW : maxCellH;
          final clampedSize = cellSize.clamp(40.0, 80.0);
          final boardExtent = (clampedSize + 6) * gridSize + 28;

          final board = AnimatedBuilder(
            animation: glowAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(gridSize, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(gridSize, (col) {
                    return _buildCell(row, col, clampedSize);
                  }),
                );
              }),
            ),
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6B48FF)
                          .withValues(alpha: 0.1 * glowAnimation.value),
                      SpaceTheme.deepSpace.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6B48FF)
                        .withValues(alpha: glowAnimation.value),
                    width: 2,
                  ),
                ),
                child: child,
              );
            },
          );
          if (boardExtent > constraints.maxWidth ||
              boardExtent > constraints.maxHeight) {
            // Keep the original touch target size in short or narrow viewports.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(child: board),
            );
          }
          return board;
        },
      ),
    );
  }

  Widget _buildCell(int row, int col, double clampedSize) {
    final round = _round;
    final isLit = grid[row][col];

    return GestureDetector(
      key: ValueKey(('dark-cell', round, row, col)),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col, round),
      child: AnimatedContainer(
        key: ValueKey(_reducedMotion),
        duration:
            _reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
        width: clampedSize,
        height: clampedSize,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: isLit
              ? const LinearGradient(
                  colors: [Color(0xFF6B48FF), Color(0xFFAA88FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLit
                ? const Color(0xFF6B48FF).withValues(alpha: 0.8)
                : Colors.grey.shade800,
            width: 2,
          ),
          boxShadow: isLit
              ? [
                  BoxShadow(
                    color: const Color(0xFF6B48FF).withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            isLit ? Icons.light_mode : Icons.dark_mode,
            color: isLit ? Colors.white : Colors.grey.shade600,
            size: clampedSize * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildWinDialog(
      int bonusScore, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'dark_matter_grid'),
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.darkMatterGridWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.darkMatterGridWinDesc(moveCount, bonusScore),
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
