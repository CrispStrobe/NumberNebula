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
import '../services/hull_plating_logic.dart';

class HullPlatingGame extends StatefulWidget {
  final int grade;
  final int level;
  const HullPlatingGame({super.key, required this.grade, required this.level});

  @override
  State<HullPlatingGame> createState() => _HullPlatingGameState();
}

class _HullPlatingGameState extends State<HullPlatingGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  HullPlatingPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Player-placed dominoes
  final List<Domino> _placedDominoes = [];
  int _nextDominoId = 0;

  // Selection state for placing dominoes
  (int, int)? _firstCell;

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
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _placedDominoes.clear();
      _nextDominoId = 0;
      _firstCell = null;
      _successController.reset();
    });

    final generated = HullPlatingPuzzle.generate(
      grade: currentDifficulty!.grade,
      level: widget.level,
    );

    if (mounted) {
      setState(() {
        puzzle = generated;
        _isGenerating = false;
      });
    }
  }

  void _onCellTap(int row, int col) {
    if (puzzle == null) return;
    if (!puzzle!.board[row][col]) return; // Can't tap holes

    // Check if cell is already covered by a placed domino
    final existingDomino = _getDominoAt(row, col);
    if (existingDomino != null) {
      // Remove the domino
      HapticFeedback.lightImpact();
      setState(() {
        _placedDominoes.remove(existingDomino);
        _firstCell = null;
      });
      return;
    }

    if (_firstCell == null) {
      // Select first cell
      setState(() {
        _firstCell = (row, col);
      });
    } else {
      // Try to place domino between first cell and this cell
      final first = _firstCell!;
      final dr = (first.$1 - row).abs();
      final dc = (first.$2 - col).abs();

      if (dr + dc == 1) {
        // Adjacent cells - can place domino
        // Check both cells are free
        if (_getDominoAt(row, col) == null &&
            _getDominoAt(first.$1, first.$2) == null) {
          // Check checkerboard constraint
          final dark1 = HullPlatingPuzzle.isDarkCell(first.$1, first.$2);
          final dark2 = HullPlatingPuzzle.isDarkCell(row, col);

          if (dark1 != dark2) {
            HapticFeedback.lightImpact();
            setState(() {
              _placedDominoes.add(Domino(
                id: _nextDominoId++,
                cell1: first,
                cell2: (row, col),
              ));
              _firstCell = null;
            });

            // Check if puzzle is solved
            _checkSolution();
          } else {
            // Same color cells - invalid
            HapticFeedback.heavyImpact();
            setState(() {
              _firstCell = null;
            });
          }
        } else {
          setState(() {
            _firstCell = null;
          });
        }
      } else {
        // Not adjacent - reset selection to this cell
        setState(() {
          _firstCell = (row, col);
        });
      }
    }
  }

  Domino? _getDominoAt(int row, int col) {
    for (final domino in _placedDominoes) {
      if (domino.covers(row, col)) return domino;
    }
    return null;
  }

  void _checkSolution() {
    if (puzzle == null) return;

    // Count covered cells
    int coveredCount = _placedDominoes.length * 2;

    // Count active cells
    int activeCount = 0;
    for (int r = 0; r < puzzle!.rows; r++) {
      for (int c = 0; c < puzzle!.cols; c++) {
        if (puzzle!.board[r][c]) activeCount++;
      }
    }

    if (coveredCount == activeCount) {
      // All cells covered - validate
      final isValid = HullPlatingPuzzle.validatePlacement(
        _placedDominoes,
        puzzle!.board,
        puzzle!.rows,
        puzzle!.cols,
      );

      if (isValid) {
        _handleWin();
      }
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.rows * puzzle!.cols * 10;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'hull_plating',
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

  void _clearBoard() {
    HapticFeedback.lightImpact();
    setState(() {
      _placedDominoes.clear();
      _firstCell = null;
    });
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
                title: s.hullPlatingTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.hullPlatingInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(child: _buildGameArea()),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 48;
        final maxH = constraints.maxHeight - 16;
        final cellSize = math.min(
          maxW / puzzle!.cols,
          maxH / puzzle!.rows,
        ).clamp(30.0, 80.0);

        final gridWidth = cellSize * puzzle!.cols;
        final gridHeight = cellSize * puzzle!.rows;

        return Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: gridWidth + 16,
                height: gridHeight + 16,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8B8B8B)
                        .withValues(alpha: _glowAnimation.value * 0.6),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.deepSpace.withValues(alpha: 0.9),
                      const Color(0xFF1A1A2E).withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: _buildGrid(cellSize),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGrid(double cellSize) {
    // Build color map for dominoes
    final dominoColors = <int, Color>{};
    final colorPalette = [
      const Color(0xFF4A90D9),
      const Color(0xFF50C878),
      const Color(0xFFE8A317),
      const Color(0xFFCC4444),
      const Color(0xFF8A6BBE),
      const Color(0xFF33CCCC),
      const Color(0xFFFF7F50),
      const Color(0xFF6495ED),
      const Color(0xFFDDA0DD),
      const Color(0xFF98FB98),
      const Color(0xFFF4A460),
      const Color(0xFF87CEEB),
      const Color(0xFFFFB6C1),
      const Color(0xFFADD8E6),
      const Color(0xFFE6E6FA),
      const Color(0xFFFFA07A),
      const Color(0xFF90EE90),
      const Color(0xFFDEB887),
    ];
    for (final domino in _placedDominoes) {
      dominoColors[domino.id] =
          colorPalette[domino.id % colorPalette.length];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(puzzle!.rows, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(puzzle!.cols, (col) {
            return _buildCell(row, col, cellSize, dominoColors);
          }),
        );
      }),
    );
  }

  Widget _buildCell(
      int row, int col, double cellSize, Map<int, Color> dominoColors) {
    final isActive = puzzle!.board[row][col];
    final isDark = HullPlatingPuzzle.isDarkCell(row, col);
    final isSelected = _firstCell != null &&
        _firstCell!.$1 == row &&
        _firstCell!.$2 == col;
    final domino = _getDominoAt(row, col);

    Color bgColor;
    if (!isActive) {
      bgColor = Colors.transparent;
    } else if (domino != null) {
      bgColor = dominoColors[domino.id]!.withValues(alpha: 0.7);
    } else if (isSelected) {
      bgColor = SpaceTheme.starYellow.withValues(alpha: 0.5);
    } else if (isDark) {
      bgColor = const Color(0xFF2A2A4A);
    } else {
      bgColor = const Color(0xFF404070);
    }

    // Determine domino border styling
    BorderRadius? borderRadius;
    if (domino != null) {
      final isCell1 =
          domino.cell1.$1 == row && domino.cell1.$2 == col;
      final otherRow =
          isCell1 ? domino.cell2.$1 : domino.cell1.$1;
      final otherCol =
          isCell1 ? domino.cell2.$2 : domino.cell1.$2;

      if (otherRow == row) {
        // Horizontal domino
        if (col < otherCol) {
          borderRadius = const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          );
        } else {
          borderRadius = const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          );
        }
      } else {
        // Vertical domino
        if (row < otherRow) {
          borderRadius = const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          );
        } else {
          borderRadius = const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          );
        }
      }
    }

    return GestureDetector(
      onTap: isActive ? () => _onCellTap(row, col) : null,
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius ?? BorderRadius.circular(2),
          border: isActive
              ? Border.all(
                  color: isSelected
                      ? SpaceTheme.starYellow
                      : domino != null
                          ? dominoColors[domino.id]!
                          : Colors.grey.shade600,
                  width: isSelected ? 3 : 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isActive && domino == null
            ? Center(
                child: Icon(
                  isDark ? Icons.brightness_3 : Icons.wb_sunny,
                  size: cellSize * 0.3,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.15),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomBar() {
    final s = S.of(context)!;
    final placed = _placedDominoes.length;
    final total = puzzle!.dominoCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SpaceTheme.nebulaPurple),
            ),
            child: Text(
              '$placed / $total',
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _clearBoard,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(s.playAgain),
            style: SpaceTheme.secondaryButtonStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildWinDialog(int bonusScore) {
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
                  const Icon(Icons.view_compact,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinDesc(bonusScore),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
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
