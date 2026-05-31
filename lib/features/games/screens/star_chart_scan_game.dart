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
import '../services/star_chart_scan_logic.dart';

class StarChartScanGame extends StatefulWidget {
  final int grade;
  final int level;
  const StarChartScanGame({super.key, required this.grade, required this.level});

  @override
  State<StarChartScanGame> createState() => _StarChartScanGameState();
}

class _StarChartScanGameState extends State<StarChartScanGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  StarChartScanPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Tracking found equations and current selection
  final Set<String> _foundEquations = {};
  final Set<String> _foundCells = {}; // 'row,col' keys
  // Track which cells belong to which found equation (for colored highlighting)
  final Map<String, int> _cellEquationIndex = {};
  List<(int, int)> _currentSelection = [];
  bool _isDragging = false;

  static const _highlightColors = [
    Color(0xFF06FFA5), // alien green
    Color(0xFFFF69B4), // cosmic pink
    Color(0xFF6B48FF), // purple
    Color(0xFFFFD700), // gold
    Color(0xFFFF6B35), // orange
    Color(0xFF00BCD4), // cyan
    Color(0xFFE63946), // red
    Color(0xFF8BC34A), // light green
    Color(0xFF9C27B0), // deep purple
    Color(0xFFFF9800), // amber
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
      _foundEquations.clear();
      _foundCells.clear();
      _cellEquationIndex.clear();
      _currentSelection.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;
    int gridSize;
    int equationCount;
    bool allowDiagonal;
    List<String> operators;

    if (grade <= 1) {
      gridSize = 7;
      equationCount = 3;
      allowDiagonal = false;
      operators = ['+'];
    } else if (grade <= 2) {
      gridSize = 8;
      equationCount = 5;
      allowDiagonal = false;
      operators = ['+', '-'];
    } else if (grade <= 3) {
      gridSize = 9;
      equationCount = 6;
      allowDiagonal = true;
      operators = ['+', '-', 'x'];
    } else {
      gridSize = 10;
      equationCount = 8;
      allowDiagonal = true;
      operators = ['+', '-', 'x'];
    }

    final generated = StarChartScanPuzzle.generate(
      gridSize: gridSize,
      equationCount: equationCount,
      allowDiagonal: allowDiagonal,
      operators: operators,
    );

    if (mounted) {
      setState(() {
        puzzle = generated;
        _isGenerating = false;
      });
    }
  }

  void _onPanStart(
      DragStartDetails details, double cellSize, Offset gridOrigin) {
    final pos =
        _getCellFromPosition(details.localPosition, cellSize, gridOrigin);
    if (pos != null) {
      setState(() {
        _isDragging = true;
        _currentSelection = [pos];
      });
    }
  }

  void _onPanUpdate(
      DragUpdateDetails details, double cellSize, Offset gridOrigin) {
    if (!_isDragging) return;
    final pos =
        _getCellFromPosition(details.localPosition, cellSize, gridOrigin);
    if (pos != null && _currentSelection.isNotEmpty) {
      if (_currentSelection.length == 1 || _isValidLineExtension(pos)) {
        if (!_currentSelection.contains(pos)) {
          setState(() {
            _currentSelection.add(pos);
          });
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || _currentSelection.isEmpty) {
      setState(() {
        _isDragging = false;
        _currentSelection.clear();
      });
      return;
    }

    final selectedStr = _currentSelection
        .map((pos) => puzzle!.grid[pos.$1][pos.$2])
        .join();

    final reverseStr = selectedStr.split('').reversed.join();
    String? matchedEquation;

    for (final target in puzzle!.equationsToFind) {
      if (_foundEquations.contains(target)) continue;
      if (selectedStr == target || reverseStr == target) {
        matchedEquation = target;
        break;
      }
    }

    if (matchedEquation != null) {
      HapticFeedback.lightImpact();
      final eqIdx = _foundEquations.length;
      setState(() {
        _foundEquations.add(matchedEquation!);
        for (final pos in _currentSelection) {
          final key = '${pos.$1},${pos.$2}';
          _foundCells.add(key);
          _cellEquationIndex[key] = eqIdx;
        }
      });

      if (_foundEquations.length == puzzle!.equationsToFind.length) {
        _handleWin();
      }
    }

    setState(() {
      _isDragging = false;
      _currentSelection.clear();
    });
  }

  bool _isValidLineExtension((int, int) newPos) {
    if (_currentSelection.length < 2) return true;

    final first = _currentSelection.first;
    final second = _currentSelection[1];
    final dr = second.$1 - first.$1;
    final dc = second.$2 - first.$2;

    final last = _currentSelection.last;
    final newDr = newPos.$1 - last.$1;
    final newDc = newPos.$2 - last.$2;

    return newDr == dr && newDc == dc;
  }

  (int, int)? _getCellFromPosition(
      Offset position, double cellSize, Offset gridOrigin) {
    final relX = position.dx - gridOrigin.dx;
    final relY = position.dy - gridOrigin.dy;

    final col = (relX / cellSize).floor();
    final row = (relY / cellSize).floor();

    if (row >= 0 &&
        row < puzzle!.gridSize &&
        col >= 0 &&
        col < puzzle!.gridSize) {
      return (row, col);
    }
    return null;
  }

  void _handleWin() {
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int eqBonus = puzzle!.equationsToFind.length * 30;
    int totalScore = baseScore + levelBonus + eqBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'star_chart_scan',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _buildWinDialog(totalScore),
          );
        }
      });
    }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 500;
              final isWide = constraints.maxWidth > 700;

              return Column(
                children: [
                  _buildHeader(s, isCompact),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout()
                        : _buildCompactLayout(),
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
            title: s.starChartScanTitle,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              s.starChartScanInstructions,
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
              s.starChartScanTitle,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${_foundEquations.length}/${puzzle?.equationsToFind.length ?? 0}',
              style: const TextStyle(
                color: SpaceTheme.alienGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildGameArea(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildEquationListPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Expanded(child: _buildGameArea()),
        _buildEquationList(),
      ],
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDim =
            math.min(constraints.maxWidth - 16, constraints.maxHeight - 16);
        final cellSize = maxDim / puzzle!.gridSize;
        final gridSide = cellSize * puzzle!.gridSize;

        return Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: gridSide + 12,
                height: gridSide + 12,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SpaceTheme.starYellow
                        .withValues(alpha: _glowAnimation.value * 0.6),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.deepSpace.withValues(alpha: 0.8),
                      SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onPanStart: (d) => _onPanStart(d, cellSize, Offset.zero),
                  onPanUpdate: (d) => _onPanUpdate(d, cellSize, Offset.zero),
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    size: Size(gridSide, gridSide),
                    painter: _GridPainter(
                      puzzle: puzzle!,
                      cellSize: cellSize,
                      foundCells: _foundCells,
                      cellEquationIndex: _cellEquationIndex,
                      highlightColors: _highlightColors,
                      currentSelection: _currentSelection,
                      glowValue: _glowAnimation.value,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEquationListPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '=',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children:
                  puzzle!.equationsToFind.asMap().entries.map((entry) {
                final eq = entry.value;
                final found = _foundEquations.contains(eq);
                final color = found
                    ? _highlightColors[
                        _getEqColorIndex(eq) % _highlightColors.length]
                    : Colors.white70;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        found
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          found ? eq : '? ? ? = ?',
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 14,
                            color: color,
                            decoration:
                                found ? TextDecoration.lineThrough : null,
                            decorationColor: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_foundEquations.length}/${puzzle!.equationsToFind.length}',
              style: const TextStyle(
                color: SpaceTheme.alienGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getEqColorIndex(String eq) {
    final idx = puzzle!.equationsToFind.indexOf(eq);
    return idx >= 0 ? idx : 0;
  }

  Widget _buildEquationList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children:
            puzzle!.equationsToFind.asMap().entries.map((entry) {
          final eq = entry.value;
          final found = _foundEquations.contains(eq);
          final color = found
              ? _highlightColors[
                  _getEqColorIndex(eq) % _highlightColors.length]
              : null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: found
                  ? color!.withValues(alpha: 0.25)
                  : SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: found ? color! : Colors.grey.shade600,
              ),
            ),
            child: Text(
              found ? eq : '? ? ? = ?',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12,
                color: found ? color : Colors.white70,
                decoration: found ? TextDecoration.lineThrough : null,
                decorationColor: found ? color : null,
              ),
            ),
          );
        }).toList(),
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
                  const Icon(Icons.functions,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.starChartScanWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    s.starChartScanWinDesc(
                        '${puzzle!.equationsToFind.length}', bonusScore),
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

class _GridPainter extends CustomPainter {
  final StarChartScanPuzzle puzzle;
  final double cellSize;
  final Set<String> foundCells;
  final Map<String, int> cellEquationIndex;
  final List<Color> highlightColors;
  final List<(int, int)> currentSelection;
  final double glowValue;

  _GridPainter({
    required this.puzzle,
    required this.cellSize,
    required this.foundCells,
    required this.cellEquationIndex,
    required this.highlightColors,
    required this.currentSelection,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selectionSet = <String>{};
    for (final pos in currentSelection) {
      selectionSet.add('${pos.$1},${pos.$2}');
    }

    final fontSize = math.max(18.0, cellSize * 0.45);

    for (int r = 0; r < puzzle.gridSize; r++) {
      for (int c = 0; c < puzzle.gridSize; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize,
          r * cellSize,
          cellSize,
          cellSize,
        );

        final key = '$r,$c';
        final isFound = foundCells.contains(key);
        final isSelected = selectionSet.contains(key);
        final eqIdx = cellEquationIndex[key];

        // Draw cell background
        final bgPaint = Paint();
        if (isFound && eqIdx != null) {
          final highlightColor =
              highlightColors[eqIdx % highlightColors.length];
          bgPaint.color = highlightColor.withValues(alpha: 0.3);
        } else if (isSelected) {
          bgPaint.color = const Color(0xFFFFD700).withValues(alpha: 0.35);
        } else {
          bgPaint.color = const Color(0xFF1A1A2E).withValues(alpha: 0.5);
        }
        canvas.drawRect(rect, bgPaint);

        // Draw cell border
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 0.5;
        canvas.drawRect(rect, borderPaint);

        // Determine character color
        Color charColor;
        final cellChar = puzzle.grid[r][c];
        final isOperator =
            cellChar == '+' || cellChar == '-' || cellChar == 'x' || cellChar == '=';

        if (isFound && eqIdx != null) {
          charColor = highlightColors[eqIdx % highlightColors.length];
        } else if (isSelected) {
          charColor = const Color(0xFFFFD700);
        } else if (isOperator) {
          charColor = const Color(0xFF06FFA5).withValues(alpha: 0.9);
        } else {
          charColor = Colors.white.withValues(alpha: 0.9);
        }

        // Draw character
        final textPainter = TextPainter(
          text: TextSpan(
            text: cellChar,
            style: TextStyle(
              color: charColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }
    }

    // Draw colored stripes across found equation cells
    if (foundCells.isNotEmpty) {
      _drawFoundEquationStripes(canvas);
    }

    // Draw selection line
    if (currentSelection.length >= 2) {
      _drawSelectionLine(canvas);
    }
  }

  void _drawFoundEquationStripes(Canvas canvas) {
    final eqGroups = <int, List<String>>{};
    for (final entry in cellEquationIndex.entries) {
      eqGroups.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    for (final entry in eqGroups.entries) {
      final idx = entry.key;
      final cells = entry.value;
      if (cells.length < 2) continue;

      final color = highlightColors[idx % highlightColors.length];
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = cellSize * 0.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final firstParts = cells.first.split(',');
      final lastParts = cells.last.split(',');
      final startR = int.parse(firstParts[0]);
      final startC = int.parse(firstParts[1]);
      final endR = int.parse(lastParts[0]);
      final endC = int.parse(lastParts[1]);

      canvas.drawLine(
        Offset((startC + 0.5) * cellSize, (startR + 0.5) * cellSize),
        Offset((endC + 0.5) * cellSize, (endR + 0.5) * cellSize),
        linePaint,
      );
    }
  }

  void _drawSelectionLine(Canvas canvas) {
    final first = currentSelection.first;
    final last = currentSelection.last;

    final linePaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.3)
      ..strokeWidth = cellSize * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset((first.$2 + 0.5) * cellSize, (first.$1 + 0.5) * cellSize),
      Offset((last.$2 + 0.5) * cellSize, (last.$1 + 0.5) * cellSize),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.foundCells != foundCells ||
        oldDelegate.currentSelection != currentSelection ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.cellEquationIndex != cellEquationIndex;
  }
}
