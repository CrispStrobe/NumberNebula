import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/crew_manifest_logic.dart';

/// Cell state in the logic grid: empty, check (confirmed match), or X (eliminated).
enum CellMark { empty, check, cross }

class CrewManifestGame extends StatefulWidget {
  final int grade;
  final int level;
  const CrewManifestGame({super.key, required this.grade, required this.level});

  @override
  State<CrewManifestGame> createState() => _CrewManifestGameState();
}

class _CrewManifestGameState extends State<CrewManifestGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  CrewManifestPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Logic grid: Map<'crewIndex_itemIndex', CellMark>
  final Map<String, CellMark> _gridState = {};

  // Highlighted row/col for visual feedback
  int? _highlightedRow;
  int? _highlightedCol;

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
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

  String _cellKey(int row, int col) => '${row}_$col';

  CellMark _getMark(int row, int col) =>
      _gridState[_cellKey(row, col)] ?? CellMark.empty;

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _gridState.clear();
      _highlightedRow = null;
      _highlightedCol = null;
      _successController.reset();
    });

    final generated = await compute(CrewManifestLogic.generate, {
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        // Initialize all cells to empty
        for (int r = 0; r < generated.size; r++) {
          for (int c = 0; c < generated.size; c++) {
            _gridState[_cellKey(r, c)] = CellMark.empty;
          }
        }
        _isGenerating = false;
      });
    }
  }

  void _toggleCell(int row, int col) {
    if (_gameOver) return;

    setState(() {
      _highlightedRow = row;
      _highlightedCol = col;

      final current = _getMark(row, col);
      switch (current) {
        case CellMark.empty:
          // Place a check mark -> auto-X other cells in same row and col
          _gridState[_cellKey(row, col)] = CellMark.check;
          _autoEliminate(row, col);
          break;
        case CellMark.check:
          // Cycle to X, and un-eliminate the rest
          _gridState[_cellKey(row, col)] = CellMark.cross;
          _unAutoEliminate(row, col);
          break;
        case CellMark.cross:
          // Cycle to empty
          _gridState[_cellKey(row, col)] = CellMark.empty;
          break;
      }
    });

    HapticFeedback.selectionClick();
  }

  /// When a check is placed at (row, col), mark all other cells in the same
  /// row and column as X (if they are empty).
  void _autoEliminate(int row, int col) {
    final size = puzzle!.size;
    for (int c = 0; c < size; c++) {
      if (c != col && _getMark(row, c) == CellMark.empty) {
        _gridState[_cellKey(row, c)] = CellMark.cross;
      }
    }
    for (int r = 0; r < size; r++) {
      if (r != row && _getMark(r, col) == CellMark.empty) {
        _gridState[_cellKey(r, col)] = CellMark.cross;
      }
    }
  }

  /// When removing a check from (row, col), revert auto-eliminations -- set
  /// the auto-X'd cells back to empty UNLESS they were set by another check.
  void _unAutoEliminate(int row, int col) {
    final size = puzzle!.size;
    // For cells in the same row: only un-X if no other check in their column
    for (int c = 0; c < size; c++) {
      if (c != col && _getMark(row, c) == CellMark.cross) {
        // Check if any other check in column c requires this X
        bool neededByOther = false;
        for (int r = 0; r < size; r++) {
          if (r != row && _getMark(r, c) == CellMark.check) {
            neededByOther = true;
            break;
          }
        }
        if (!neededByOther) {
          _gridState[_cellKey(row, c)] = CellMark.empty;
        }
      }
    }
    // For cells in the same column: only un-X if no other check in their row
    for (int r = 0; r < size; r++) {
      if (r != row && _getMark(r, col) == CellMark.cross) {
        bool neededByOther = false;
        for (int c = 0; c < size; c++) {
          if (c != col && _getMark(r, c) == CellMark.check) {
            neededByOther = true;
            break;
          }
        }
        if (!neededByOther) {
          _gridState[_cellKey(r, col)] = CellMark.empty;
        }
      }
    }
  }

  void _checkSolution() {
    if (puzzle == null || _gameOver) return;

    // Build user assignment from check marks
    final userMap = <String, String>{};
    final size = puzzle!.size;

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_getMark(r, c) == CellMark.check) {
          userMap[puzzle!.crewNames[r]] = puzzle!.itemNames[c];
        }
      }
    }

    // Check if all crew have an assignment
    if (userMap.length != size) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.crewManifestLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
        ),
      );
      return;
    }

    if (puzzle!.checkSolution(userMap)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.size * 50;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'crew_manifest',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'crew_manifest',
      difficulty: widget.level,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.crewManifestLoseDesc)),
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
                title: s.crewManifestTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
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

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _buildGridArea(constraints),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildCluesAndSubmit(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          // Grid takes priority space
          Expanded(
            flex: 3,
            child: _buildGridArea(constraints),
          ),
          const SizedBox(height: 8),
          // Clues + submit scroll if needed
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: _buildCluesAndSubmit(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGridArea(BoxConstraints outerConstraints) {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.nebulaPurple.withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildLogicGrid(),
          );
        },
      ),
    );
  }

  Widget _buildLogicGrid() {
    final size = puzzle!.size;

    return LayoutBuilder(
      builder: (context, constraints) {
        // +1 for header column/row. Fill available space.
        final maxCellW = (constraints.maxWidth - 16) / (size + 1.3);
        final maxCellH = (constraints.maxHeight - 16) / (size + 1.3);
        final cellSize = (maxCellW < maxCellH ? maxCellW : maxCellH).clamp(38.0, 72.0);
        final headerW = cellSize * 1.3;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: empty corner + item names
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: headerW, height: cellSize),
                ...List.generate(size, (c) {
                  return SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            child: Text(
                              puzzle!.itemNames[c],
                              style: SpaceTheme.titleStyle.copyWith(
                                fontSize: 14,
                                color: SpaceTheme.starYellow,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            // Grid rows: crew name + cells
            ...List.generate(size, (r) {
              final isHighlightedRow = _highlightedRow == r;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Crew name header
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: headerW,
                    height: cellSize,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isHighlightedRow
                          ? SpaceTheme.alienGreen.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            puzzle!.crewNames[r],
                            style: SpaceTheme.titleStyle.copyWith(
                              fontSize: 15,
                              color: const Color(0xFF00C9DB),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Grid cells
                  ...List.generate(size, (c) {
                    return _buildGridCell(r, c, cellSize);
                  }),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildGridCell(int row, int col, double cellSize) {
    final mark = _getMark(row, col);
    final isHighlightedRow = _highlightedRow == row;
    final isHighlightedCol = _highlightedCol == col;
    final isHighlighted = isHighlightedRow || isHighlightedCol;

    Color bgColor;
    Widget? content;

    switch (mark) {
      case CellMark.check:
        bgColor = SpaceTheme.alienGreen.withValues(alpha: 0.25);
        content = Icon(Icons.check_circle, color: SpaceTheme.alienGreen, size: cellSize * 0.6);
        break;
      case CellMark.cross:
        bgColor = SpaceTheme.rocketRed.withValues(alpha: 0.15);
        content = Icon(Icons.close, color: SpaceTheme.rocketRed.withValues(alpha: 0.7), size: cellSize * 0.5);
        break;
      case CellMark.empty:
        bgColor = isHighlighted
            ? SpaceTheme.nebulaPurple.withValues(alpha: 0.3)
            : SpaceTheme.deepSpace.withValues(alpha: 0.5);
        content = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                Icons.radio_button_unchecked,
                color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                size: cellSize * 0.3,
              ),
            );
          },
        );
        break;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleCell(row, col),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: isHighlighted
                ? SpaceTheme.starYellow.withValues(alpha: 0.5)
                : SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildCluesAndSubmit() {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Instructions
        Text(
          s.crewManifestInstructions,
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Clues section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb, color: SpaceTheme.starYellow, size: 18),
                  const SizedBox(width: 8),
                  Text(S.of(context)!.crewManifestClues, style: SpaceTheme.titleStyle.copyWith(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              ...puzzle!.clues.map((clue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.arrow_right, color: SpaceTheme.starYellow, size: 16),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            clue,
                            style: SpaceTheme.bodyStyle.copyWith(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: SpaceTheme.alienGreen, size: 18),
            const SizedBox(width: 4),
            Text(S.of(context)!.crewManifestMatch, style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)),
            const SizedBox(width: 16),
            const Icon(Icons.close, color: SpaceTheme.rocketRed, size: 18),
            const SizedBox(width: 4),
            Text(S.of(context)!.crewManifestEliminate, style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        // Submit button
        if (!_gameOver)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _checkSolution,
              icon: const Icon(Icons.assignment_turned_in, size: 22),
              label: const Text('Submit Manifest', style: TextStyle(fontSize: 16)),
              style: SpaceTheme.primaryButtonStyle,
            ),
          ),
      ],
    );
  }

  Widget _buildWinDialog(int totalScore) {
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
                  const Icon(Icons.assignment_turned_in, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.crewManifestWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.crewManifestWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
