// space_station_gridlock_game.dart:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:collection';

import '../../../core/theme/space_theme.dart';
import '../constants/app_constants.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class SpaceStationGridlockGame extends StatefulWidget {
  final int grade;
  final int level;

  const SpaceStationGridlockGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<SpaceStationGridlockGame> createState() => _SpaceStationGridlockGameState();
}

class _SpaceStationGridlockGameState extends State<SpaceStationGridlockGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _slideController;
  late AnimationController _successController;
  late AnimationController _exitController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _exitAnimation;

  // Game State
  static const gridSize = 6;
  late List<SpaceShip> ships;
  late int playerShipIndex;
  late int exitRow;
  late int minMoves;
  int moveCount = 0;
  bool gameActive = true;
  bool hasWon = false;
  int? draggingShipIndex;
  Offset? dragStartPos;

  double _cellSize = 50.0; // Default, will be updated by LayoutBuilder
  bool _isGenerating = false;
  
  // Visual Effects
  List<GridlockParticle> particles = [];
  Set<String> highlightedCells = {};

  @override
  void initState() {
    super.initState();
    debugPrint("🚢 [SpaceGridlock] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _generatePuzzleAsync(); // Use async version
    }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
        parent: _slideController, curve: Curves.easeOut);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
        parent: _successController, curve: Curves.elasticOut);

    _exitController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _exitAnimation = CurvedAnimation(
        parent: _exitController, curve: Curves.easeInOut);
  }

  Future<void> _generatePuzzleAsync() async {
    setState(() {
        _isGenerating = true;
    });

    try {
        // AWAIT the Future to get the actual PuzzleConfiguration
        final puzzleConfig = await PuzzleGenerator.generate(widget.grade, widget.level);

        // Now puzzleConfig is a PuzzleConfiguration, not a Future
        ships = puzzleConfig.ships.asMap().entries.map((entry) {
        final index = entry.key;
        final config = entry.value;
        return SpaceShip(
            row: config['row']!,
            col: config['col']!,
            length: config['length']!,
            isHorizontal: config['isHorizontal']!,
            isPlayer: config['isPlayer'] ?? false,
            color: config['isPlayer'] == true
                ? SpaceTheme.alienGreen
                : _getShipColor(index),
        );
        }).toList();

        playerShipIndex = ships.indexWhere((ship) => ship.isPlayer);
        if (playerShipIndex == -1) {
        debugPrint("FATAL: No player ship generated!");
        return;
        }
        
        exitRow = ships[playerShipIndex].row;
        minMoves = puzzleConfig.minMoves;
        moveCount = 0;
        gameActive = true;
        hasWon = false;

        debugPrint('🚢 [SpaceGridlock] Puzzle generated: ${ships.length} ships, min moves: $minMoves');
        
    } catch (e) {
        debugPrint('Error generating puzzle: $e');
    } finally {
        if (mounted) {
        setState(() {
            _isGenerating = false;
        });
        }
    }
    }

  Color _getShipColor(int index) {
    final colors = [
      SpaceTheme.cosmicPink,
      SpaceTheme.starYellow,
      SpaceTheme.planetOrange,
      SpaceTheme.nebulaPurple,
      Colors.cyan,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.lime,
      Colors.deepOrange,
      Colors.purple,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  void _validatePuzzle() {
    // Check that ships don't overlap
    final occupied = <String>{};
    for (final ship in ships) {
      for (int i = 0; i < ship.length; i++) {
        final r = ship.isHorizontal ? ship.row : ship.row + i;
        final c = ship.isHorizontal ? ship.col + i : ship.col;
        final key = '$r-$c';
        if (occupied.contains(key)) {
          debugPrint("⚠️ [SpaceGridlock] Overlap detected at $key");
        }
        occupied.add(key);
      }
    }
  }

  void _onPanStart(DragStartDetails details, int shipIndex) {
    if (!gameActive || hasWon) return;
    
    setState(() {
      draggingShipIndex = shipIndex;
      dragStartPos = details.globalPosition;
      _highlightPossibleMoves(shipIndex);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, int shipIndex) {
    if (!gameActive || hasWon || draggingShipIndex != shipIndex) return;
    
    final ship = ships[shipIndex];
    final delta = details.globalPosition - dragStartPos!;
    
    // Only allow movement in the ship's orientation
    if (ship.isHorizontal && delta.dx.abs() > 20) {
      final direction = delta.dx > 0 ? 1 : -1;
      if (_canMoveShip(shipIndex, direction)) {
        _moveShip(shipIndex, direction);
        dragStartPos = details.globalPosition;
      }
    } else if (!ship.isHorizontal && delta.dy.abs() > 20) {
      final direction = delta.dy > 0 ? 1 : -1;
      if (_canMoveShip(shipIndex, direction)) {
        _moveShip(shipIndex, direction);
        dragStartPos = details.globalPosition;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      draggingShipIndex = null;
      dragStartPos = null;
      highlightedCells.clear();
    });
  }

  void _highlightPossibleMoves(int shipIndex) {
    final ship = ships[shipIndex];
    highlightedCells.clear();
    
    // Highlight current position
    for (int i = 0; i < ship.length; i++) {
      final r = ship.isHorizontal ? ship.row : ship.row + i;
      final c = ship.isHorizontal ? ship.col + i : ship.col;
      highlightedCells.add('$r-$c');
    }
    
    // Highlight possible moves
    if (ship.isHorizontal) {
      // Check left
      for (int newCol = ship.col - 1; newCol >= 0; newCol--) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
      // Check right
      for (int newCol = ship.col + ship.length; newCol < gridSize; newCol++) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
    } else {
      // Check up
      for (int newRow = ship.row - 1; newRow >= 0; newRow--) {
        if (_isBlocked(newRow, ship.col)) break;
        highlightedCells.add('$newRow-${ship.col}');
      }
      // Check down
      for (int newRow = ship.row + ship.length; newRow < gridSize; newRow++) {
        if (_isBlocked(newRow, ship.col)) break;
        highlightedCells.add('$newRow-${ship.col}');
      }
    }
  }

  bool _isBlocked(int row, int col) {
    for (int i = 0; i < ships.length; i++) {
      if (i == draggingShipIndex) continue;
      final ship = ships[i];
      for (int j = 0; j < ship.length; j++) {
        final r = ship.isHorizontal ? ship.row : ship.row + j;
        final c = ship.isHorizontal ? ship.col + j : ship.col;
        if (r == row && c == col) return true;
      }
    }
    return false;
  }

  bool _canMoveShip(int shipIndex, int direction) {
    final ship = ships[shipIndex];
    
    if (ship.isHorizontal) {
      final newCol = ship.col + direction;
      if (direction < 0) {
        // Moving left
        if (newCol < 0) return false;
        return !_isBlocked(ship.row, newCol);
      } else {
        // Moving right
        if (newCol + ship.length > gridSize) return false;
        return !_isBlocked(ship.row, newCol + ship.length - 1);
      }
    } else {
      final newRow = ship.row + direction;
      if (direction < 0) {
        // Moving up
        if (newRow < 0) return false;
        return !_isBlocked(newRow, ship.col);
      } else {
        // Moving down
        if (newRow + ship.length > gridSize) return false;
        return !_isBlocked(newRow + ship.length - 1, ship.col);
      }
    }
  }

  void _moveShip(int shipIndex, int direction) {
    HapticFeedback.selectionClick();
    _slideController.forward(from: 0.0);
    
    setState(() {
      final ship = ships[shipIndex];
      if (ship.isHorizontal) {
        ship.col += direction;
      } else {
        ship.row += direction;
      }
      moveCount++;
    });
    
    // Add movement particles
    final ship = ships[shipIndex];
    _addMoveParticles(ship);
    
    // Check win condition
    if (ship.isPlayer) {
      _checkWinCondition();
    }
  }

  void _addMoveParticles(SpaceShip ship) {
    final random = math.Random();
    
    for (int i = 0; i < ship.length; i++) {
        final r = ship.isHorizontal ? ship.row : ship.row + i;
        final c = ship.isHorizontal ? ship.col + i : ship.col;
        final centerX = 20 + (c + 0.5) * _cellSize;
        final centerY = 200 + (r + 0.5) * _cellSize;
        
        for (int j = 0; j < 3; j++) {
        particles.add(GridlockParticle.trail(
            Offset(centerX + (random.nextDouble() - 0.5) * 20, 
                centerY + (random.nextDouble() - 0.5) * 20),
            ship.color,
        ));
        }
    }
    }

  void _checkWinCondition() {
    final playerShip = ships[playerShipIndex];
    
    // Check if player ship can reach the exit (right edge)
    if (playerShip.isHorizontal && playerShip.col + playerShip.length >= gridSize) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [SpaceGridlock] Success! Ship docked in $moveCount moves");
    
    setState(() {
      gameActive = false;
      hasWon = true;
    });
    
    _successController.forward();
    _exitController.forward();
    HapticFeedback.heavyImpact();
    
    // Calculate score
    final baseScore = 250 * widget.grade;
    final efficiencyBonus = moveCount <= minMoves ? 300 : 
                           moveCount <= minMoves + 3 ? 150 : 50;
    final difficultyBonus = ships.length * 20;
    final totalScore = baseScore + efficiencyBonus + difficultyBonus;
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'space_station_gridlock',
      scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: true,
    );
    
    // Add celebration particles
    for (int i = 0; i < 60; i++) {
      particles.add(GridlockParticle.celebration(
        MediaQuery.of(context).size.center(Offset.zero),
      ));
    }
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, efficiencyBonus),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // final cellSize = (screenSize.width - 40) / gridSize;
    
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background
              Positioned.fill(
                child: AnimatedBuilder(
                    animation: Listenable.merge([_pulseController, _glowController]),
                    builder: (context, child) {
                    return CustomPaint(
                        painter: GridlockBackgroundPainter(
                        pulseIntensity: _pulseAnimation.value,
                        glowIntensity: _glowAnimation.value,
                        hasWon: hasWon,
                        ),
                    );
                    },
                ),
                ),
              
              // Particles
              ...particles.map((p) => p.build()),
              
              // Main game UI
              if (!_isGenerating) ...[
               Column(
                children: [
                  GameUI(
                    title: S.of(context)!.spaceGridlockTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  
                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat(Icons.touch_app, '$moveCount', SpaceTheme.alienGreen),
                        _buildStat(Icons.flag, '$minMoves', SpaceTheme.starYellow),
                        _buildStat(Icons.rocket_launch, '${ships.length}', SpaceTheme.cosmicPink),
                      ],
                    ),
                  ),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      S.of(context)!.spaceGridlockInstructions,
                      style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Grid
                  Expanded(
                    child: LayoutBuilder(
                        builder: (context, constraints) {
                        // Account for margins and all padding layers
                        final availableWidth = constraints.maxWidth - 40;
                        final availableHeight = constraints.maxHeight - 40;
                        
                        const borderWidth = 3.0;
                        
                        // Calculate max grid size, accounting for overhead
                        final maxGridSize = (availableWidth < availableHeight 
                            ? availableWidth 
                            : availableHeight).clamp(200.0, 580.0); // Reduced max to leave room
                        
                        final gridPixelSize = maxGridSize;
                        final cellSize = (gridPixelSize - (borderWidth * 2)) / gridSize;
                        
                        // Update cell size for other methods
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _cellSize != cellSize) {
                            setState(() {
                                _cellSize = cellSize;
                            });
                            }
                        });
                        
                        return Center(
                            child: Container(
                            width: gridPixelSize,
                            height: gridPixelSize,
                            decoration: BoxDecoration(
                                color: SpaceTheme.deepSpace.withOpacity(0.5),
                                border: Border.all(color: SpaceTheme.nebulaPurple, width: borderWidth),
                                borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                                padding: const EdgeInsets.all(borderWidth),
                                child: ClipRect(
                                child: Stack(
                                    children: [
                                    // Grid lines
                                    CustomPaint(
                                        size: Size(
                                        gridPixelSize - (borderWidth * 2),
                                        gridPixelSize - (borderWidth * 2),
                                        ),
                                        painter: GridPainter(
                                        cellSize: cellSize,
                                        highlightedCells: highlightedCells,
                                        ),
                                    ),
                                    
                                    // Exit indicator
                                    Positioned(
                                        right: -borderWidth,
                                        top: exitRow * cellSize,
                                        child: AnimatedBuilder(
                                        animation: _glowAnimation,
                                        builder: (context, child) {
                                            return Container(
                                            width: borderWidth * 2,
                                            height: cellSize,
                                            decoration: BoxDecoration(
                                                color: SpaceTheme.alienGreen,
                                                boxShadow: [
                                                BoxShadow(
                                                    color: SpaceTheme.alienGreen.withOpacity(_glowAnimation.value),
                                                    blurRadius: 15,
                                                    spreadRadius: 3,
                                                ),
                                                ],
                                            ),
                                            );
                                        },
                                        ),
                                    ),
                                    
                                    // Ships
                                    ...ships.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final ship = entry.value;
                                        return _buildShip(index, ship, cellSize);
                                    }),
                                    ],
                                ),
                                ),
                            ),
                            ),
                        );
                        },
                    ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Reset button
                  if (gameActive) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _generatePuzzleAsync();
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(S.of(context)!.spaceGridlockReset),
                            style: SpaceTheme.secondaryButtonStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                ],
              ),
            ],
            
            // Loading overlay - note the THREE dots before 'if'
            if (_isGenerating) ...[
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(SpaceTheme.alienGreen),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Generating Puzzle...',
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Finding the perfect challenge',
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: SpaceTheme.cosmicPink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

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

  Widget _buildShip(int index, SpaceShip ship, double cellSize) {
    final isDragging = draggingShipIndex == index;
    const double padding = 3.0; // Padding between ships and grid lines
    
    // Calculate ship dimensions
    final shipWidth = ship.isHorizontal 
        ? (cellSize * ship.length) - (padding * 2)
        : cellSize - (padding * 2);
    final shipHeight = ship.isHorizontal 
        ? cellSize - (padding * 2)
        : (cellSize * ship.length) - (padding * 2);

    return Positioned(
        left: ship.col * cellSize + padding,
        top: ship.row * cellSize + padding,
        child: GestureDetector(
        onPanStart: (details) => _onPanStart(details, index),
        onPanUpdate: (details) => _onPanUpdate(details, index),
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
            animation: ship.isPlayer ? _exitAnimation : _slideAnimation,
            builder: (context, child) {
            final exitOffset = ship.isPlayer && hasWon 
                ? _exitAnimation.value * cellSize * 2 
                : 0.0;

            return Transform.translate(
                offset: Offset(exitOffset, 0),
                child: Container(
                width: shipWidth,
                height: shipHeight,
                decoration: BoxDecoration(
                    color: ship.color.withOpacity(isDragging ? 0.9 : 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                    color: ship.isPlayer 
                        ? SpaceTheme.alienGreen 
                        : Colors.white.withOpacity(0.6),
                    width: ship.isPlayer ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                    BoxShadow(
                        color: ship.color.withOpacity(isDragging ? 0.6 : 0.3),
                        blurRadius: isDragging ? 12 : 6,
                        spreadRadius: isDragging ? 2 : 0,
                    ),
                    ],
                ),
                child: Center(
                    child: Icon(
                    ship.isPlayer ? Icons.rocket_launch : Icons.local_shipping,
                    color: Colors.white,
                    size: (cellSize * 0.35).clamp(16.0, 32.0), // Scale icon with cell
                    ),
                ),
                ),
            );
            },
        ),
        ),
    );
    }

  Widget _buildSuccessDialog(int totalScore, int efficiencyBonus) {
    final performance = moveCount <= minMoves ? 'Perfect!' : 
                       moveCount <= minMoves + 3 ? 'Great!' : 'Good!';
    
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
                    const Icon(Icons.flight_takeoff, size: 60, color: SpaceTheme.alienGreen),
                    const SizedBox(height: 16),
                    Text(
                      S.of(context)!.spaceGridlockWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      S.of(context)!.spaceGridlockWinDesc(
                        moveCount,
                        minMoves,
                        performance,
                        totalScore,
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              _resetGame();
                            },
                            style: SpaceTheme.secondaryButtonStyle,
                            child: Text(S.of(context)!.nextPuzzle, textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
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

  void _resetGame() {
    setState(() {
        particles.clear();
        highlightedCells.clear();
        draggingShipIndex = null;
    });
    
    _successController.reset();
    _exitController.reset();
    _generatePuzzleAsync(); // Use async version
    }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    _successController.dispose();
    _exitController.dispose();
    super.dispose();
  }
}

// Data Models
class SpaceShip {
  int row;
  int col;
  final int length;
  final bool isHorizontal;
  final bool isPlayer;
  final Color color;

  SpaceShip({
    required this.row,
    required this.col,
    required this.length,
    required this.isHorizontal,
    required this.isPlayer,
    required this.color,
  });
}


// Visual Effects
class GridlockParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  GridlockParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory GridlockParticle.trail(Offset pos, Color shipColor) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 20 + random.nextDouble() * 40;
    return GridlockParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: shipColor,
      size: 2 + random.nextDouble() * 3,
      opacity: 0.8,
      life: 0.3 + random.nextDouble() * 0.2,
    );
  }

  factory GridlockParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 100 + random.nextDouble() * 200;
    return GridlockParticle(
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
    velocity *= 0.95;
    return life <= 0;
  }

  Widget build() {
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
                color: color.withOpacity(opacity * 0.5),
                blurRadius: size * 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painters
class GridlockBackgroundPainter extends CustomPainter {
  final double pulseIntensity;
  final double glowIntensity;
  final bool hasWon;

  GridlockBackgroundPainter({
    required this.pulseIntensity,
    required this.glowIntensity,
    required this.hasWon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw subtle grid pattern
    final gridPaint = Paint()
      ..color = (hasWon ? Colors.green : Colors.cyan).withOpacity(0.05 * pulseIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    // Central glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: hasWon 
            ? [Colors.green.withOpacity(0.2 * glowIntensity), Colors.transparent]
            : [Colors.cyan.withOpacity(0.1 * glowIntensity), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: 300));
    
    canvas.drawCircle(center, 300, glowPaint);
  }

  @override
  bool shouldRepaint(GridlockBackgroundPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.hasWon != hasWon;
}

class GridPainter extends CustomPainter {
  final double cellSize;
  final Set<String> highlightedCells;

  GridPainter({required this.cellSize, required this.highlightedCells});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    final highlightPaint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(0.2);
    
    // Draw highlights
    for (final cell in highlightedCells) {
      final parts = cell.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
        highlightPaint,
      );
    }
    
    // Draw grid lines
    for (int i = 0; i <= 6; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) =>
      oldDelegate.highlightedCells != highlightedCells;
}

class PuzzleGenerator {
  static const int gridSize = 6;
  static const String targetCarId = 'PLAYER';
  static const int targetCarRow = 2;
  static final _random = math.Random();

  /// Generates a verified solvable puzzle - now with proper async support
  static Future<PuzzleConfiguration> generate(int grade, int level) async {
    debugPrint('🎮 [PuzzleGenerator] Starting generation for Grade $grade, Level $level');
    
    // More realistic difficulty targets
    int minMovesTarget;
    int maxMovesTarget;
    int maxAttempts;
    int maxSolverMoves;

    final double complexity = grade + (level / 5.0);

    if (complexity <= 2.0) {
      minMovesTarget = 8;
      maxMovesTarget = 18;
      maxAttempts = 100;
      maxSolverMoves = 40;
    } else if (complexity <= 4.0) {
      minMovesTarget = 12;
      maxMovesTarget = 25;
      maxAttempts = 150;
      maxSolverMoves = 50;
    } else if (complexity <= 6.0) {
      minMovesTarget = 18;
      maxMovesTarget = 35;
      maxAttempts = 200;
      maxSolverMoves = 60;
    } else {
      minMovesTarget = 25;
      maxMovesTarget = 45;
      maxAttempts = 250;
      maxSolverMoves = 80;
    }

    debugPrint('  Target: $minMovesTarget-$maxMovesTarget moves, max solver depth: $maxSolverMoves');

    PuzzleConfiguration? bestPuzzle;
    int bestSolutionLength = 0;

    for (int attempts = 0; attempts < maxAttempts; attempts++) {
      if (attempts % 25 == 0) {
        debugPrint('  Attempt $attempts... (best: $bestSolutionLength moves)');
        // Yield to UI every 25 attempts
        await Future.delayed(Duration.zero);
      }

      try {
        final puzzle = _generateRandomPuzzle(complexity);
        final solutionLength = _solvePuzzle(puzzle, maxSolverMoves);
        
        if (solutionLength != null && solutionLength > 0) {
          // Found a valid, solvable puzzle
          if (solutionLength >= minMovesTarget && solutionLength <= maxMovesTarget) {
            debugPrint('✅ Valid puzzle: $solutionLength moves (target: $minMovesTarget-$maxMovesTarget)');
            return PuzzleConfiguration(ships: puzzle.ships, minMoves: solutionLength);
          }
          
          // Track best puzzle
          if (solutionLength > bestSolutionLength) {
            bestSolutionLength = solutionLength;
            bestPuzzle = puzzle;
          }
        }
      } catch (e) {
        // Skip failed attempts
        continue;
      }
    }

    // Use best puzzle found or fallback
    if (bestPuzzle != null && bestSolutionLength >= minMovesTarget * 0.6) {
      debugPrint('⚠️ Using best: $bestSolutionLength moves (target: $minMovesTarget-$maxMovesTarget)');
      return PuzzleConfiguration(ships: bestPuzzle.ships, minMoves: bestSolutionLength);
    }

    debugPrint('❌ Using fallback puzzle for complexity $complexity');
    return _getFallbackPuzzle(complexity);
  }

  /// Generate a random puzzle configuration (simpler approach from CLI)
  static PuzzleConfiguration _generateRandomPuzzle(double complexity) {
    final ships = <Map<String, dynamic>>[];
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // 1. Always add the player car (horizontal, row 2)
    final playerStart = _random.nextInt(gridSize - 2); // Leave room to move
    final playerShip = {
      'row': targetCarRow,
      'col': playerStart,
      'length': 2,
      'isHorizontal': true,
      'isPlayer': true,
    };
    ships.add(playerShip);
    _markGrid(grid, playerShip, true);

    // 2. Add random cars based on complexity
    final numCars = complexity <= 2.0 
        ? 6 + _random.nextInt(3)   // 6-8 cars for easy
        : complexity <= 4.0 
        ? 8 + _random.nextInt(4)   // 8-11 cars for medium
        : 10 + _random.nextInt(5); // 10-14 cars for hard
    
    int attempts = 0;
    const maxPlacementAttempts = 200;
    
    while (ships.length < numCars && attempts < maxPlacementAttempts) {
      attempts++;
      
      final isHorizontal = _random.nextBool();
      final length = _random.nextBool() ? 2 : 3;
      final rowOrCol = _random.nextInt(gridSize);
      final maxStart = gridSize - length;
      final start = _random.nextInt(maxStart + 1);

      final newShip = isHorizontal
          ? {
              'row': rowOrCol,
              'col': start,
              'length': length,
              'isHorizontal': true,
              'isPlayer': false,
            }
          : {
              'row': start,
              'col': rowOrCol,
              'length': length,
              'isHorizontal': false,
              'isPlayer': false,
            };

      if (_canPlaceShip(grid, newShip)) {
        ships.add(newShip);
        _markGrid(grid, newShip, true);
        attempts = 0; // Reset on success
      }
    }

    return PuzzleConfiguration(ships: ships, minMoves: 0);
  }

  /// Check if ship can be placed
  static bool _canPlaceShip(List<List<bool>> grid, Map<String, dynamic> ship) {
    final row = ship['row'] as int;
    final col = ship['col'] as int;
    final length = ship['length'] as int;
    final isHorizontal = ship['isHorizontal'] as bool;

    for (int i = 0; i < length; i++) {
      final r = isHorizontal ? row : row + i;
      final c = isHorizontal ? col + i : col;
      
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
      if (grid[r][c]) return false;
    }
    return true;
  }

  /// Mark grid with ship
  static void _markGrid(List<List<bool>> grid, Map<String, dynamic> ship, bool mark) {
    final row = ship['row'] as int;
    final col = ship['col'] as int;
    final length = ship['length'] as int;
    final isHorizontal = ship['isHorizontal'] as bool;

    for (int i = 0; i < length; i++) {
      final r = isHorizontal ? row : row + i;
      final c = isHorizontal ? col + i : col;
      grid[r][c] = mark;
    }
  }

  /// BFS solver - simplified and optimized
  static int? _solvePuzzle(PuzzleConfiguration config, int maxMoves) {
    final queue = Queue<_SolverState>();
    final visited = <String>{};
    
    final initialState = _SolverState(config.ships, 0);
    queue.add(initialState);
    visited.add(initialState.hashKey);

    int nodesExplored = 0;
    const maxNodes = 15000; // Reduced from 50000
    
    while (queue.isNotEmpty && nodesExplored < maxNodes) {
      final current = queue.removeFirst();
      nodesExplored++;
      
      // Check win condition
      final playerShip = current.ships.firstWhere((s) => s['isPlayer'] == true);
      final playerCol = playerShip['col'] as int;
      final playerLength = playerShip['length'] as int;
      
      if (playerCol + playerLength >= gridSize) {
        return current.moves;
      }
      
      // Don't explore beyond maxMoves
      if (current.moves >= maxMoves) continue;
      
      // Try all possible moves
      for (int shipIdx = 0; shipIdx < current.ships.length; shipIdx++) {
        for (final direction in [-1, 1]) {
          final newShip = _tryMove(current.ships[shipIdx], direction);
          if (newShip != null && !_checkCollision(current.ships, shipIdx, newShip)) {
            final newShips = List<Map<String, dynamic>>.from(current.ships);
            newShips[shipIdx] = newShip;
            
            final newState = _SolverState(newShips, current.moves + 1);
            
            if (!visited.contains(newState.hashKey)) {
              visited.add(newState.hashKey);
              queue.add(newState);
            }
          }
        }
      }
    }
    
    return null; // No solution found
  }

  /// Try to move ship in direction
  static Map<String, dynamic>? _tryMove(Map<String, dynamic> ship, int direction) {
    final isHorizontal = ship['isHorizontal'] as bool;
    final row = ship['row'] as int;
    final col = ship['col'] as int;
    final length = ship['length'] as int;
    
    if (isHorizontal) {
      final newCol = col + direction;
      if (newCol < 0 || newCol + length > gridSize) return null;
      return {...ship, 'col': newCol};
    } else {
      final newRow = row + direction;
      if (newRow < 0 || newRow + length > gridSize) return null;
      return {...ship, 'row': newRow};
    }
  }

  /// Check collision
  static bool _checkCollision(List<Map<String, dynamic>> ships, int movedIdx, Map<String, dynamic> movedShip) {
    final movedRow = movedShip['row'] as int;
    final movedCol = movedShip['col'] as int;
    final movedLength = movedShip['length'] as int;
    final movedHorizontal = movedShip['isHorizontal'] as bool;
    
    for (int i = 0; i < ships.length; i++) {
      if (i == movedIdx) continue;
      
      final ship = ships[i];
      final shipRow = ship['row'] as int;
      final shipCol = ship['col'] as int;
      final shipLength = ship['length'] as int;
      final shipHorizontal = ship['isHorizontal'] as bool;
      
      // Get occupied cells
      final movedCells = <String>{};
      final shipCells = <String>{};
      
      for (int j = 0; j < movedLength; j++) {
        final r = movedHorizontal ? movedRow : movedRow + j;
        final c = movedHorizontal ? movedCol + j : movedCol;
        movedCells.add('$r,$c');
      }
      
      for (int j = 0; j < shipLength; j++) {
        final r = shipHorizontal ? shipRow : shipRow + j;
        final c = shipHorizontal ? shipCol + j : shipCol;
        shipCells.add('$r,$c');
      }
      
      if (movedCells.intersection(shipCells).isNotEmpty) {
        return true;
      }
    }
    
    return false;
  }

  /// Fallback puzzles for different difficulty levels
  static PuzzleConfiguration _getFallbackPuzzle(double complexity) {
    if (complexity <= 2.0) {
      // Easy puzzle
      return PuzzleConfiguration(
        minMoves: 10,
        ships: [
          {'row': 2, 'col': 1, 'length': 2, 'isHorizontal': true, 'isPlayer': true},
          {'row': 0, 'col': 3, 'length': 3, 'isHorizontal': false, 'isPlayer': false},
          {'row': 2, 'col': 3, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
          {'row': 1, 'col': 1, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 4, 'col': 2, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 3, 'col': 5, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
        ],
      );
    } else if (complexity <= 4.0) {
      // Medium puzzle
      return PuzzleConfiguration(
        minMoves: 15,
        ships: [
          {'row': 2, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': true},
          {'row': 0, 'col': 2, 'length': 3, 'isHorizontal': false, 'isPlayer': false},
          {'row': 2, 'col': 2, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
          {'row': 0, 'col': 4, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
          {'row': 1, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 3, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 4, 'col': 3, 'length': 3, 'isHorizontal': true, 'isPlayer': false},
          {'row': 5, 'col': 1, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
        ],
      );
    } else {
      // Hard puzzle
      return PuzzleConfiguration(
        minMoves: 20,
        ships: [
          {'row': 2, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': true},
          {'row': 0, 'col': 1, 'length': 3, 'isHorizontal': false, 'isPlayer': false},
          {'row': 0, 'col': 3, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
          {'row': 1, 'col': 4, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
          {'row': 2, 'col': 2, 'length': 3, 'isHorizontal': false, 'isPlayer': false},
          {'row': 0, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 1, 'col': 2, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 3, 'col': 0, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 4, 'col': 3, 'length': 2, 'isHorizontal': true, 'isPlayer': false},
          {'row': 5, 'col': 0, 'length': 3, 'isHorizontal': true, 'isPlayer': false},
        ],
      );
    }
  }
}

/// Solver state for BFS
class _SolverState {
  final List<Map<String, dynamic>> ships;
  final int moves;
  late final String hashKey;
  
  _SolverState(this.ships, this.moves) {
    // Create canonical hash - sort ships by position
    final sorted = List<Map<String, dynamic>>.from(ships);
    sorted.sort((a, b) {
      final rowComp = (a['row'] as int).compareTo(b['row'] as int);
      if (rowComp != 0) return rowComp;
      final colComp = (a['col'] as int).compareTo(b['col'] as int);
      if (colComp != 0) return colComp;
      return (a['length'] as int).compareTo(b['length'] as int);
    });
    hashKey = sorted.map((s) => 
      '${s['row']},${s['col']},${s['length']},${s['isHorizontal'] ? "H" : "V"}'
    ).join('|');
  }
}

class PuzzleConfiguration {
  final List<Map<String, dynamic>> ships;
  final int minMoves;

  PuzzleConfiguration({required this.ships, required this.minMoves});
}

/// Internal state representation for solving
class _PuzzleState {
  final List<Map<String, dynamic>> ships;
  late final String _hash;

  _PuzzleState(this.ships) {
    // Create a canonical hash for state comparison
    final sorted = List<Map<String, dynamic>>.from(ships);
    sorted.sort((a, b) {
      final rowCompare = (a['row'] as int).compareTo(b['row'] as int);
      if (rowCompare != 0) return rowCompare;
      return (a['col'] as int).compareTo(b['col'] as int);
    });
    _hash = sorted.map((s) => '${s['row']},${s['col']},${s['length']},${s['isHorizontal']}').join('|');
  }

  @override
  String toString() => _hash;
}

/// Node for BFS solver
class _SolverNode {
  final _PuzzleState state;
  final int moves;

  _SolverNode(this.state, this.moves);
}

/// A temporary, mutable class for easier ship manipulation during generation.
class _TempShip {
  int row, col, length;
  bool isHorizontal, isPlayer;
  _TempShip({
    required this.row, required this.col, required this.length, 
    required this.isHorizontal, this.isPlayer = false,
  });

  Map<String, dynamic> toMap() => {
    'row': row, 'col': col, 'length': length, 
    'isHorizontal': isHorizontal, 'isPlayer': isPlayer,
  };
}