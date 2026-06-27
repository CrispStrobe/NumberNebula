import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/dark_matter_grid_logic.dart';

class DarkMatterGridGame extends StatefulWidget {
  final int grade;
  final int level;
  const DarkMatterGridGame({super.key, required this.grade, required this.level});

  @override
  State<DarkMatterGridGame> createState() => _DarkMatterGridGameState();
}

class _DarkMatterGridGameState extends State<DarkMatterGridGame>
    with TickerProviderStateMixin, GameAnimationsMixin<DarkMatterGridGame> {
  late AnimationController _tapController;

  DifficultyConfig? currentDifficulty;
  DarkMatterGridPuzzle? puzzle;
  late List<List<bool>> grid;
  int moveCount = 0;
  bool _isGenerating = true;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

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
    _tapController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
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
    final toggleCount = (gridSize + currentDifficulty!.level).clamp(3, gridSize * gridSize - 1);

    puzzle = DarkMatterGridPuzzle.generate(
      gridSize: gridSize,
      toggleCount: toggleCount,
    );

    setState(() {
      grid = puzzle!.grid.map(List<bool>.from).toList();
      _isGenerating = false;
    });
  }

  void _onCellTap(int row, int col) {
    if (_won) return;

    HapticFeedback.selectionClick();
    _tapController.forward(from: 0.0);

    setState(() {
      grid = DarkMatterGridPuzzle.toggle(grid, row, col);
      moveCount++;
    });

    if (DarkMatterGridPuzzle.isSolved(grid)) {
      _handleWin();
    }
  }

  void _handleWin() {
    _won = true;
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int moveBonus = (puzzle!.minMoves * 50) ~/ (moveCount.clamp(1, 999));
    int totalScore = baseScore + levelBonus + moveBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'dark_matter_grid',
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

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
                title: s.darkMatterGridTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.darkMatterGridInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${s.level}: ${widget.level}  |  Moves: $moveCount',
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
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
          final maxCellW = (constraints.maxWidth - 56) / gridSize;
          final maxCellH = (constraints.maxHeight - 56) / gridSize;
          final cellSize = maxCellW < maxCellH ? maxCellW : maxCellH;
          final clampedSize = cellSize.clamp(40.0, 80.0);

          return AnimatedBuilder(
            animation: glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6B48FF).withValues(alpha: 0.1 * glowAnimation.value),
                      SpaceTheme.deepSpace.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6B48FF).withValues(alpha: glowAnimation.value),
                    width: 2,
                  ),
                ),
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
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCell(int row, int col, double clampedSize) {
    final isLit = grid[row][col];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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

  Widget _buildWinDialog(int bonusScore) {
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
                  const Icon(Icons.emoji_events, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.darkMatterGridWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.darkMatterGridWinDesc(moveCount, bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
          ),
        );
      },
    );
  }
}
