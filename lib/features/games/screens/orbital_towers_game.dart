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
import '../services/orbital_towers_logic.dart';

class OrbitalTowersGame extends StatefulWidget {
  final int grade;
  final int level;
  const OrbitalTowersGame({super.key, required this.grade, required this.level});

  @override
  State<OrbitalTowersGame> createState() => _OrbitalTowersGameState();
}

class _OrbitalTowersGameState extends State<OrbitalTowersGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  OrbitalTowersPuzzle? puzzle;
  Map<String, int> userSolution = {};
  bool _isGenerating = true;
  String _lastDroppedCell = '';
  DifficultyConfig? currentDifficulty;

  // Track completed rows/columns that flash green
  final Set<String> _validatedLines = {};

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

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int _getGridSize() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    return 5;
  }

  int _getEdgeClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    final size = _getGridSize();
    final maxClues = size * 4;
    final base = (maxClues * 0.75).round();
    final reduction = (level / 4).floor();
    return (base - reduction).clamp(size, maxClues);
  }

  int _getCellClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    if (level <= 3) return 2;
    if (level <= 6) return 1;
    return 0;
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userSolution.clear();
      _validatedLines.clear();
      _successController.reset();
    });

    try {
      final generator = OrbitalTowersGenerator();
      final p = await generator.generate(
        size: _getGridSize(),
        edgeClueCount: _getEdgeClueCount(),
        cellClueCount: _getCellClueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;
          _isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint('[OrbitalTowers] Error generating puzzle: $e');
    }
  }

  void _placeNumber(int number, String cellId) {
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedCell = cellId;
      _dropController.forward(from: 0.0);
    });
    _checkLineCompletion(cellId);
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    setState(() {
      userSolution.remove(cellId);
    });
  }

  void _checkLineCompletion(String cellId) {
    if (puzzle == null) return;
    final size = puzzle!.size;
    // Parse row/col from cellId
    final parts = cellId.split('c');
    final row = int.parse(parts[0].substring(1));
    final col = int.parse(parts[1]);

    final complete = Map<String, int>.from(puzzle!.clues);
    complete.addAll(userSolution);

    // Check if row is complete
    bool rowComplete = true;
    final rowVals = <int>{};
    for (int c = 0; c < size; c++) {
      final v = complete['r${row}c$c'];
      if (v == null) { rowComplete = false; break; }
      rowVals.add(v);
    }
    if (rowComplete && rowVals.length == size) {
      _validatedLines.add('row_$row');
    }

    // Check if col is complete
    bool colComplete = true;
    final colVals = <int>{};
    for (int r = 0; r < size; r++) {
      final v = complete['r${r}c$col'];
      if (v == null) { colComplete = false; break; }
      colVals.add(v);
    }
    if (colComplete && colVals.length == size) {
      _validatedLines.add('col_$col');
    }
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
    int sizeBonus = puzzle!.size * puzzle!.size * 15;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'orbital_towers',
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

  void _handleIncorrect() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.orbitalTowersLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isRowValidated(int row) => _validatedLines.contains('row_$row');
  bool _isColValidated(int col) => _validatedLines.contains('col_$col');

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
                title: s.orbitalTowersTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.orbitalTowersInstructions(puzzle!.size),
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildGridWithClues(constraints),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildGridWithClues(constraints),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: _buildNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridWithClues(BoxConstraints outerConstraints) {
    final size = puzzle!.size;

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.rocketRed.withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.rocketRed.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Account for clue columns (2 extra) and rows (2 extra)
                final maxCellW = (constraints.maxWidth - 16) / (size + 2);
                final maxCellH = (constraints.maxHeight - 16) / (size + 2);
                final cellSize = math.min(maxCellW, maxCellH).clamp(30.0, 70.0);
                final clueSize = cellSize * 0.7;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top edge clues
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: clueSize),
                        ...List.generate(size, (c) {
                          return _buildEdgeClue(puzzle!.edgeClues['top_$c'], clueSize);
                        }),
                        SizedBox(width: clueSize),
                      ],
                    ),
                    // Grid rows with left/right clues
                    ...List.generate(size, (r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildEdgeClue(puzzle!.edgeClues['left_$r'], clueSize),
                          ...List.generate(size, (c) {
                            final cellId = 'r${r}c$c';
                            return _buildCell(cellId, r, c, cellSize);
                          }),
                          _buildEdgeClue(puzzle!.edgeClues['right_$r'], clueSize),
                        ],
                      );
                    }),
                    // Bottom edge clues
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: clueSize),
                        ...List.generate(size, (c) {
                          return _buildEdgeClue(puzzle!.edgeClues['bottom_$c'], clueSize);
                        }),
                        SizedBox(width: clueSize),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEdgeClue(int? clue, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: clue != null
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  child: Text(
                    clue.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: size * 0.5,
                      color: SpaceTheme.starYellow,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCell(String cellId, int row, int col, double cellSize) {
    final isClue = puzzle!.clues.containsKey(cellId);
    final hasUserValue = userSolution.containsKey(cellId);
    final value = isClue ? puzzle!.clues[cellId] : userSolution[cellId];
    final isLastDropped = cellId == _lastDroppedCell;
    final isRowValid = _isRowValidated(row);
    final isColValid = _isColValidated(col);
    final isHighlighted = isRowValid || isColValid;

    if (isClue) {
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHighlighted
                ? [SpaceTheme.alienGreen, SpaceTheme.alienGreen.withValues(alpha: 0.6)]
                : [SpaceTheme.alienGreen.withValues(alpha: 0.4), SpaceTheme.deepSpace],
          ),
          border: Border.all(color: Colors.grey.shade600, width: 1),
        ),
        child: Center(
          child: _buildTowerVisual(value!, cellSize),
        ),
      );
    }

    if (hasUserValue) {
      Widget cell = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHighlighted
                ? [SpaceTheme.alienGreen.withValues(alpha: 0.3), SpaceTheme.deepSpace]
                : [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple],
          ),
          border: Border.all(
            color: isHighlighted ? SpaceTheme.alienGreen : Colors.grey.shade600,
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Center(
          child: _buildTowerVisual(value!, cellSize),
        ),
      );

      if (isLastDropped) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      return GestureDetector(onTap: () => _removeNumber(cellId), child: cell);
    }

    // Empty cell -- DragTarget
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            gradient: isHovering
                ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
            border: Border.all(
              color: isHovering ? SpaceTheme.starYellow : Colors.grey.shade600,
              width: isHovering ? 3 : 1,
            ),
            boxShadow: isHovering
                ? [BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Center(
                  child: Icon(Icons.add, color: SpaceTheme.nebulaPurple, size: cellSize * 0.3),
                ),
              );
            },
          ),
        );
      },
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _placeNumber(details.data, cellId),
    );
  }

  /// Visual tower representation: stacked blocks proportional to height
  Widget _buildTowerVisual(int height, double cellSize) {
    final size = puzzle!.size;
    final blockHeight = (cellSize * 0.7) / size;
    final blockWidth = cellSize * 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Number label on top
        Text(
          height.toString(),
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: cellSize * 0.22,
            color: SpaceTheme.starYellow,
          ),
        ),
        // Stacked blocks
        ...List.generate(height, (i) {
          final shade = (i + 1) / size;
          return Container(
            width: blockWidth,
            height: blockHeight.clamp(2.0, 10.0),
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SpaceTheme.planetOrange.withValues(alpha: 0.5 + shade * 0.5),
                  SpaceTheme.rocketRed.withValues(alpha: 0.3 + shade * 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList().reversed,
      ],
    );
  }

  Widget _buildNumberPad() {
    final numbers = puzzle!.numberPool;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: SpaceTheme.starGradient,
                      boxShadow: [BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )],
                    ),
                    child: Center(
                      child: Text(n.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildTrayTile(n)),
                child: _buildTrayTile(n),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTile(int number) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18)),
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
                  const Icon(Icons.location_city, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.orbitalTowersWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.orbitalTowersWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
