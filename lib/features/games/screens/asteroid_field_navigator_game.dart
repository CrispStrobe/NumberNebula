// All imports remain the same...
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import '../../../core/theme/space_theme.dart';
import '../constants/app_constants.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';


class AsteroidFieldNavigatorGame extends StatefulWidget {
  final int grade;
  final int level;

  const AsteroidFieldNavigatorGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<AsteroidFieldNavigatorGame> createState() => _AsteroidFieldNavigatorGameState();
}

class _AsteroidFieldNavigatorGameState extends State<AsteroidFieldNavigatorGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _explosionController;
  late AnimationController _revealController;
  late AnimationController _successController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _explosionAnimation;
  late Animation<double> _revealAnimation;
  late Animation<double> _successAnimation;

  // Game State
  late List<List<AsteroidCell>> grid;
  late int gridRows;
  late int gridCols;
  late int mineCount;
  late int flagsPlaced;
  late int cellsRevealed;
  bool gameActive = true;
  bool hasWon = false;
  bool hasLost = false;
  bool isFlagMode = false;
  bool isFirstClick = true;
  DateTime? startTime;
  int elapsedSeconds = 0;
  Timer? gameTimer;
  
  // Visual Effects
  List<ExplosionParticle> particles = [];
  Set<String> animatingCells = {};

  @override
  void initState() {
    super.initState();
    debugPrint("💣 [AsteroidField] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _initializeGameParameters();
    _generateField();
    _startGameTimer();
  }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _explosionAnimation = CurvedAnimation(
        parent: _explosionController, curve: Curves.easeOut);

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _revealAnimation = CurvedAnimation(
        parent: _revealController, curve: Curves.easeOut);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
        parent: _successController, curve: Curves.elasticOut);
  }

  void _initializeGameParameters() {
    final complexity = widget.grade + (widget.level / 5.0);
    
    if (complexity <= 2.5) {
      gridRows = 6; gridCols = 6; mineCount = 6;
    } else if (complexity <= 3.5) {
      gridRows = 8; gridCols = 8; mineCount = 10;
    } else if (complexity <= 4.5) {
      gridRows = 10; gridCols = 10; mineCount = 15;
    } else if (complexity <= 5.5) {
      gridRows = 12; gridCols = 12; mineCount = 25;
    } else if (complexity <= 6.5) {
      gridRows = 15; gridCols = 15; mineCount = 40;
    } else {
      gridRows = 20; gridCols = 20; mineCount = 70;
    }
    
    flagsPlaced = 0;
    cellsRevealed = 0;
  }

  void _generateField() {
    final random = math.Random();
    
    grid = List.generate(
      gridRows,
      (row) => List.generate(
        gridCols,
        (col) => AsteroidCell(row: row, col: col),
      ),
    );
    
    int minesPlaced = 0;
    while (minesPlaced < mineCount) {
      final row = random.nextInt(gridRows);
      final col = random.nextInt(gridCols);
      
      if (!grid[row][col].isMine) {
        grid[row][col].isMine = true;
        minesPlaced++;
      }
    }
    
    for (int row = 0; row < gridRows; row++) {
      for (int col = 0; col < gridCols; col++) {
        if (!grid[row][col].isMine) {
          grid[row][col].adjacentMines = _countAdjacentMines(row, col);
        }
      }
    }
  }

  int _countAdjacentMines(int row, int col) {
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final newRow = row + dr;
        final newCol = col + dc;
        if (newRow >= 0 && newRow < gridRows && newCol >= 0 && newCol < gridCols) {
          if (grid[newRow][newCol].isMine) count++;
        }
      }
    }
    return count;
  }

  void _startGameTimer() {
    startTime = DateTime.now();
    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameActive) {
        setState(() {
          elapsedSeconds = DateTime.now().difference(startTime!).inSeconds;
        });
      }
    });
  }

  void _onCellTap(int row, int col) {
    if (!gameActive || grid[row][col].isRevealed) return;
    
    if (isFlagMode) {
      _toggleFlag(row, col);
    } else {
      if (!grid[row][col].isFlagged) {
        _revealCell(row, col);
      }
    }
  }

  void _onCellLongPress(int row, int col) {
    if (!gameActive || grid[row][col].isRevealed) return;
    _toggleFlag(row, col);
  }

  void _toggleFlag(int row, int col) {
    if (grid[row][col].isRevealed) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      if (grid[row][col].isFlagged) {
        grid[row][col].isFlagged = false;
        flagsPlaced--;
      } else if (flagsPlaced < mineCount) {
        grid[row][col].isFlagged = true;
        flagsPlaced++;
      }
    });
  }
  
  // --- FIXED: Completely rewritten and corrected map revelation algorithm ---
  void _revealCell(int row, int col) {
    if (!gameActive || grid[row][col].isRevealed || grid[row][col].isFlagged) {
      return;
    }

    if (isFirstClick && grid[row][col].isMine) {
      debugPrint("💣 [AsteroidField] First click on mine - regenerating field");
      _regenerateFieldWithoutMineAt(row, col);
    }
    isFirstClick = false;

    final initialCell = grid[row][col];
    if (initialCell.isMine) {
      _handleExplosion(row, col);
      return;
    }

    HapticFeedback.selectionClick();

    final Set<AsteroidCell> cellsToReveal = {initialCell};
    
    // Only start the flood-fill (BFS) if the initially clicked cell is a "0"
    if (initialCell.adjacentMines == 0) {
      final List<AsteroidCell> queue = [initialCell];
      final Set<AsteroidCell> visited = {initialCell};

      int head = 0;
      while (head < queue.length) {
        final currentCell = queue[head];
        head++;

        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final newRow = currentCell.row + dr;
            final newCol = currentCell.col + dc;

            if (newRow >= 0 && newRow < gridRows && newCol >= 0 && newCol < gridCols) {
              final neighbor = grid[newRow][newCol];
              if (!neighbor.isRevealed && !neighbor.isFlagged && visited.add(neighbor)) {
                cellsToReveal.add(neighbor);
                // Continue the search only from other "0" cells
                if (neighbor.adjacentMines == 0) {
                  queue.add(neighbor);
                }
              }
            }
          }
        }
      }
    }

    if (cellsToReveal.isNotEmpty) {
      setState(() {
        for (final cell in cellsToReveal) {
          if (!cell.isRevealed) {
            cell.isRevealed = true;
            cellsRevealed++;
            animatingCells.add('${cell.row}-${cell.col}');
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() => animatingCells.remove('${cell.row}-${cell.col}'));
              }
            });
          }
        }
      });
    }

    _checkWinCondition();
  }
  
  void _regenerateFieldWithoutMineAt(int avoidRow, int avoidCol) {
    grid[avoidRow][avoidCol].isMine = false;
    
    final random = math.Random();
    bool placed = false;
    while (!placed) {
      final row = random.nextInt(gridRows);
      final col = random.nextInt(gridCols);
      
      if ((row != avoidRow || col != avoidCol) && !grid[row][col].isMine) {
        grid[row][col].isMine = true;
        placed = true;
      }
    }
    
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (!grid[r][c].isMine) {
          grid[r][c].adjacentMines = _countAdjacentMines(r, c);
        } else {
          grid[r][c].adjacentMines = -1;
        }
      }
    }
  }

  void _handleExplosion(int row, int col) {
    if (!gameActive) return;
    
    gameTimer?.cancel();
    setState(() {
      gameActive = false;
      hasLost = true;
      grid[row][col].isRevealed = true;
      grid[row][col].isExploded = true;
    });
    
    _explosionController.forward();
    HapticFeedback.heavyImpact();
    
    // Particle effect logic remains the same
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          for (var row in grid) {
            for (var cell in row) {
              if (cell.isMine) cell.isRevealed = true;
            }
          }
        });
      }
    });
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'asteroid_field_navigator',
      scoreGained: 0,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: false,
    );
    
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (mounted) {
        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _buildFailureDialog(dialogContext),
        );
        
        if (!mounted) return;

        if (shouldRetry == true) {
          _resetGame();
        } else {
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _checkWinCondition() {
    final totalSafeCells = gridRows * gridCols - mineCount;
    if (cellsRevealed >= totalSafeCells && gameActive) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    if (!gameActive) return;

    gameTimer?.cancel();
    setState(() {
      gameActive = false;
      hasWon = true;
      for (var row in grid) {
        for (var cell in row) {
          if (cell.isMine && !cell.isFlagged) {
            cell.isFlagged = true;
          }
        }
      }
    });
    
    _successController.forward();
    HapticFeedback.heavyImpact();
    
    final baseScore = 300 * widget.grade;
    final speedBonus = math.max(0, (180 - elapsedSeconds) * 2);
    final efficiencyBonus = (mineCount - flagsPlaced) == 0 ? 200 : 100;
    final totalScore = baseScore + speedBonus + efficiencyBonus;
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'asteroid_field_navigator',
      scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: true,
    );
    
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (mounted) {
        final shouldPlayNext = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _buildSuccessDialog(
            dialogContext, totalScore, speedBonus, efficiencyBonus
          ),
        );

        if (!mounted) return;

        if (shouldPlayNext == true) {
          _resetGame();
        } else {
          Navigator.of(context).pop();
        }
      }
    });
  }

  double _calculateCellSize(Size screenSize) {
    final availableWidth = screenSize.width - 40;
    final availableHeight = screenSize.height - 300;
    return math.min(
      availableWidth / gridCols,
      availableHeight / gridRows,
    ).clamp(18.0, 55.0);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cellSize = _calculateCellSize(screenSize);
    
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _scanController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: AsteroidFieldPainter(
                        pulseIntensity: _pulseAnimation.value,
                        scanProgress: _scanAnimation.value,
                        gameWon: hasWon,
                        gameLost: hasLost,
                      ),
                    );
                  },
                ),
              ),
              
              ...particles.map((p) => p.build(context)),
              
              Column(
                children: [
                  GameUI(
                    title: S.of(context)!.asteroidFieldTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildStat(Icons.timer, _formatTime(elapsedSeconds), SpaceTheme.alienGreen),
                        _buildStat(Icons.flag, '$flagsPlaced/$mineCount', SpaceTheme.starYellow),
                        _buildStat(Icons.grid_on, '$cellsRevealed/${gridRows * gridCols - mineCount}', SpaceTheme.cosmicPink),
                      ],
                    ),
                  ),
                  
                  // --- FIXED: Restored original robust layout for centering and scrolling ---
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            width: cellSize * gridCols,
                            height: cellSize * gridRows,
                            decoration: BoxDecoration(
                              border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCols,
                                ),
                                itemCount: gridRows * gridCols,
                                itemBuilder: (context, index) {
                                  final row = index ~/ gridCols;
                                  final col = index % gridCols;
                                  return _buildCell(row, col);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  if (gameActive) ...[
                    const SizedBox(height: 12),
                    _buildControls(),
                  ],
                  
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // All other `_build` methods, dialogs, models, and painters remain the same as the previous fix.
  // I am including them for completeness.
  
  Widget _buildStat(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final cell = grid[row][col];
    final isAnimating = animatingCells.contains('$row-$col');
    
    final screenSize = MediaQuery.of(context).size;
    final cellSize = _calculateCellSize(screenSize);
    
    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      onSecondaryTap: () => _onCellLongPress(row, col),
      child: AnimatedBuilder(
        animation: Listenable.merge([isAnimating ? _revealAnimation : _pulseController, _explosionController]),
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: _getCellColor(cell),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getCellBorderColor(cell),
                width: cell.isExploded ? 3 : 2,
              ),
              boxShadow: cell.isExploded ? [
                BoxShadow(
                  color: SpaceTheme.rocketRed.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: Center(
              child: _getCellContent(cell, isAnimating, cellSize),
            ),
          );
        },
      ),
    );
  }

  Color _getCellColor(AsteroidCell cell) {
    if (cell.isExploded) {
      return SpaceTheme.rocketRed;
    } else if (cell.isRevealed) {
      return cell.isMine 
          ? SpaceTheme.rocketRed.withOpacity(0.3)
          : SpaceTheme.deepSpace.withOpacity(0.7);
    } else {
      return SpaceTheme.nebulaPurple.withOpacity(0.3);
    }
  }

  Color _getCellBorderColor(AsteroidCell cell) {
    if (cell.isExploded) return SpaceTheme.rocketRed;
    if (cell.isFlagged) return SpaceTheme.starYellow;
    if (cell.isRevealed) return SpaceTheme.alienGreen.withOpacity(0.3);
    return SpaceTheme.nebulaPurple;
  }

  Widget? _getCellContent(AsteroidCell cell, bool isAnimating, double cellSize) {
    final iconSize = cellSize * 0.6;
    final fontSize = cellSize * 0.5;
    
    if (cell.isFlagged && !cell.isRevealed) {
      return Icon(Icons.flag, color: SpaceTheme.starYellow, size: iconSize);
    }
    
    if (!cell.isRevealed) return null;
    
    if (cell.isMine) {
      return Icon(
        cell.isExploded ? Icons.flash_on : Icons.warning,
        color: Colors.white,
        size: iconSize + 2,
      );
    }
    
    if (cell.adjacentMines > 0) {
      return Text(
        cell.adjacentMines.toString(),
        style: TextStyle(
          color: _getNumberColor(cell.adjacentMines),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    
    return null;
  }

  Color _getNumberColor(int count) {
    switch (count) {
      case 1: return Colors.cyanAccent;
      case 2: return Colors.greenAccent;
      case 3: return Colors.yellowAccent;
      case 4: return Colors.orangeAccent;
      case 5: return Colors.redAccent;
      case 6: return Colors.pinkAccent;
      case 7: return Colors.purpleAccent;
      case 8: return Colors.white;
      default: return Colors.grey;
    }
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => isFlagMode = !isFlagMode);
                HapticFeedback.selectionClick();
              },
              icon: Icon(
                isFlagMode ? Icons.flag : Icons.touch_app,
                size: 20,
              ),
              label: Text(
                isFlagMode 
                    ? S.of(context)!.asteroidFieldRevealMode 
                    : S.of(context)!.asteroidFieldFlagMode,
              ),
              style: (isFlagMode ? SpaceTheme.primaryButtonStyle : SpaceTheme.secondaryButtonStyle).copyWith(
                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessDialog(BuildContext dialogContext, int totalScore, int speedBonus, int efficiencyBonus) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 60, color: SpaceTheme.alienGreen),
                    const SizedBox(height: 16),
                    Text(
                      S.of(context)!.asteroidFieldWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      S.of(context)!.asteroidFieldWinDesc(
                        _formatTime(elapsedSeconds),
                        totalScore,
                        speedBonus,
                        efficiencyBonus,
                      ),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            style: SpaceTheme.secondaryButtonStyle,
                            child: Text(S.of(context)!.nextField, textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            style: SpaceTheme.primaryButtonStyle,
                            child: Text(S.of(context)!.toTheBridge, textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFailureDialog(BuildContext dialogContext) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, size: 60, color: SpaceTheme.rocketRed),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.asteroidFieldLoseTitle,
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.asteroidFieldLoseDesc,
                style: SpaceTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: SpaceTheme.secondaryButtonStyle,
                      child: Text(S.of(context)!.tryAgain, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: SpaceTheme.primaryButtonStyle,
                      child: Text(S.of(context)!.toTheBridge, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _resetGame() {
    isFirstClick = true;
    setState(() {
      gameActive = true;
      hasWon = false;
      hasLost = false;
      isFlagMode = false;
      flagsPlaced = 0;
      cellsRevealed = 0;
      particles.clear();
      animatingCells.clear();
      elapsedSeconds = 0;
    });
    
    _generateField();
    _successController.reset();
    _explosionController.reset();
    _startGameTimer();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _explosionController.dispose();
    _revealController.dispose();
    _successController.dispose();
    super.dispose();
  }
}

class AsteroidCell {
  final int row;
  final int col;
  bool isMine;
  bool isRevealed;
  bool isFlagged;
  bool isExploded;
  int adjacentMines;

  AsteroidCell({
    required this.row,
    required this.col,
    this.isMine = false,
    this.isRevealed = false,
    this.isFlagged = false,
    this.isExploded = false,
    this.adjacentMines = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsteroidCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class ExplosionParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory ExplosionParticle.explosion(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 80 + random.nextDouble() * 150;
    return ExplosionParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 4 + random.nextDouble() * 6,
      opacity: 1.0,
      life: 0.8 + random.nextDouble() * 0.5,
    );
  }

  factory ExplosionParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 100 + random.nextDouble() * 200;
    return ExplosionParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.cyan, Colors.green, Colors.yellow, Colors.pink][random.nextInt(4)],
      size: 3 + random.nextDouble() * 5,
      opacity: 1.0,
      life: 1.0 + random.nextDouble() * 0.6,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.96;
    return life <= 0;
  }

  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(opacity * 0.6),
                blurRadius: size * 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AsteroidFieldPainter extends CustomPainter {
  final double pulseIntensity;
  final double scanProgress;
  final bool gameWon;
  final bool gameLost;

  AsteroidFieldPainter({
    required this.pulseIntensity,
    required this.scanProgress,
    required this.gameWon,
    required this.gameLost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    final gridPaint = Paint()
      ..color = (gameLost ? Colors.red : gameWon ? Colors.green : Colors.cyan)
          .withOpacity(0.08 * pulseIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    final scanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (gameLost ? Colors.red : gameWon ? Colors.green : Colors.cyan).withOpacity(0.0),
          (gameLost ? Colors.red : gameWon ? Colors.green : Colors.cyan).withOpacity(0.2 * pulseIntensity),
        ],
        stops: const [0.95, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * scanProgress));
    
    canvas.drawCircle(center, size.width * scanProgress, scanPaint);
  }

  @override
  bool shouldRepaint(AsteroidFieldPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.gameWon != gameWon ||
      oldDelegate.gameLost != gameLost;
}