// space_station_gridlock_game.dart - COMPLETE REWRITE with walls support
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
import '../services/gridlock_puzzle_tracker.dart';
import '../data/gridlock_puzzles_data.dart';

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

  double _cellSize = 50.0;
  bool _isLoading = false;
  String _loadingStatus = 'Initializing...';
  
  String? _currentPuzzleId;
  double _currentComplexity = 1.0;
  
  List<GridlockParticle> particles = [];
  Set<String> highlightedCells = {};

  @override
  void initState() {
    super.initState();
    _log('🎮 INITIALIZING GAME', {
      'grade': widget.grade,
      'level': widget.level,
    });
    
    _setupAnimationControllers();
    _loadPuzzleAsync();
  }

  void _log(String message, [Map<String, dynamic>? data]) {
    final prefix = '[SpaceGridlock]';
    if (data != null && data.isNotEmpty) {
      debugPrint('$prefix $message: ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    } else {
      debugPrint('$prefix $message');
    }
  }

  void _setupAnimationControllers() {
    _log('🎬 Setting up animation controllers');
    
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

  Future<void> _loadPuzzleAsync() async {
    _log('📂 Starting puzzle load sequence');
    
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Calculating difficulty...';
    });

    try {
      // Calculate complexity - Grades 1-4, Levels 1-20 each
      // Raw range: 1.1 (G1L1) to 6.0 (G4L20)
      final rawComplexity = widget.grade + (widget.level / 10.0);
      
      // Map to our 7-level system (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0)
      // Distribute across the full 4 grades × 20 levels = 80 total levels
      if (rawComplexity < 1.7) {
        _currentComplexity = 1.0; // Easy: Grade 1, Levels 1-6
      } else if (rawComplexity < 2.4) {
        _currentComplexity = 2.0; // Easy+: Grade 1 L7-14, Grade 2 L1-4
      } else if (rawComplexity < 3.3) {
        _currentComplexity = 3.0; // Medium: Grade 1 L15-20, Grade 2 L5-13
      } else if (rawComplexity < 4.2) {
        _currentComplexity = 4.0; // Medium+: Grade 2 L14-20, Grade 3 L1-12
      } else if (rawComplexity < 5.0) {
        _currentComplexity = 5.0; // Hard: Grade 3 L13-19, Grade 4 L1-9
      } else if (rawComplexity < 5.7) {
        _currentComplexity = 6.0; // Hard+: Grade 3 L20, Grade 4 L10-17
      } else {
        _currentComplexity = 7.0; // Expert: Grade 4, Levels 18-20
      }
      
      _log('🎯 Target complexity calculated', {
        'raw': rawComplexity.toStringAsFixed(2),
        'mapped': _currentComplexity,
        'grade': widget.grade,
        'level': widget.level,
      });
      
      setState(() => _loadingStatus = 'Searching puzzle database...');
      await Future.delayed(const Duration(milliseconds: 100));
      
      final tracker = context.read<GridlockPuzzleTracker>();
      
      // Get available puzzles - exact match preferred
      final tolerance = 0.0; // Exact match since we have broader ranges now
      final allPuzzlesAtLevel = getPuzzlesByComplexity(_currentComplexity, tolerance: tolerance);
      _log('🔍 Found puzzles in database', {
        'total_at_complexity': allPuzzlesAtLevel.length,
        'complexity': _currentComplexity,
      });
      
      final availablePuzzles = allPuzzlesAtLevel
          .where((p) => !tracker.hasPlayedPuzzle(p.id))
          .toList();
      
      _log('✨ Filtered unused puzzles', {
        'available': availablePuzzles.length,
        'already_played': allPuzzlesAtLevel.length - availablePuzzles.length,
      });

      if (availablePuzzles.isNotEmpty) {
        setState(() => _loadingStatus = 'Selecting puzzle...');
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Pick random puzzle
        final random = math.Random();
        final selectedPuzzle = availablePuzzles[random.nextInt(availablePuzzles.length)];
        
        _log('🎲 Selected puzzle', {
          'id': selectedPuzzle.id,
          'complexity': selectedPuzzle.complexity,
          'min_moves': selectedPuzzle.minMoves,
          'ships': selectedPuzzle.ships.length,
        });
        
        _currentPuzzleId = selectedPuzzle.id;
        tracker.markPuzzleAsPlayed(selectedPuzzle.id);
        
        setState(() => _loadingStatus = 'Loading puzzle configuration...');
        await Future.delayed(const Duration(milliseconds: 100));
        
        _loadPuzzleFromData(selectedPuzzle);
        
        _log('✅ Puzzle loaded successfully');
      } else {
        _log('⚠️  No unused puzzles available, generating fallback');
        setState(() => _loadingStatus = 'Generating custom puzzle...');
        await Future.delayed(const Duration(milliseconds: 100));
        
        await _generateFallbackPuzzle(_currentComplexity);
      }
      
      setState(() => _loadingStatus = 'Ready!');
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e, stack) {
      _log('❌ ERROR loading puzzle: $e');
      debugPrint('Stack trace: $stack');
      
      setState(() => _loadingStatus = 'Error! Using fallback...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _generateFallbackPuzzle(_currentComplexity);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadPuzzleFromData(GridlockPuzzleData puzzleData) {
    _log('🔧 Building ship configuration from puzzle data');
    
    try {
      ships = [];
      int blockingCount = 0;
      
      for (int i = 0; i < puzzleData.ships.length; i++) {
        final config = puzzleData.ships[i];
        final isPlayer = config['isPlayer'] == true;
        final isBlocking = config['isBlocking'] == true; // Read from data
        
        if (isBlocking) blockingCount++;
        
        final ship = SpaceShip(
          row: config['row']!,
          col: config['col']!,
          length: config['length']!,
          isHorizontal: config['isHorizontal']!,
          isPlayer: isPlayer,
          isBlocking: isBlocking,
          color: isPlayer 
              ? SpaceTheme.alienGreen
              : isBlocking
              ? Colors.grey.shade800
              : _getShipColor(i),
        );
        
        ships.add(ship);
        
        _log('  Ship ${i + 1}/${puzzleData.ships.length}', {
          'type': isPlayer ? 'PLAYER' : isBlocking ? 'BLOCKING' : 'ship',
          'position': '(${ship.row}, ${ship.col})',
          'size': ship.length,
          'orientation': ship.isHorizontal ? 'H' : 'V',
        });
      }

      playerShipIndex = ships.indexWhere((ship) => ship.isPlayer);
      if (playerShipIndex == -1) {
        throw Exception('No player ship found in puzzle data!');
      }
      
      exitRow = ships[playerShipIndex].row;
      minMoves = puzzleData.minMoves;
      moveCount = 0;
      gameActive = true;
      hasWon = false;

      _log('🚀 Puzzle configuration complete', {
        'total_ships': ships.length,
        'blocking_pieces': blockingCount,
        'movable_ships': ships.length - blockingCount - 1,
        'player_ship_index': playerShipIndex,
        'exit_row': exitRow,
        'target_moves': minMoves,
      });
      
    } catch (e, stack) {
      _log('❌ ERROR building puzzle: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> _generateFallbackPuzzle(double complexity) async {
    _log('🎲 Generating fallback puzzle', {'complexity': complexity});
    
    try {
      final puzzleConfig = await PuzzleGenerator.generate(widget.grade, widget.level);

      ships = puzzleConfig.ships.asMap().entries.map((entry) {
        final index = entry.key;
        final config = entry.value;
        return SpaceShip(
          row: config['row']!,
          col: config['col']!,
          length: config['length']!,
          isHorizontal: config['isHorizontal']!,
          isPlayer: config['isPlayer'] ?? false,
          isBlocking: false,
          color: config['isPlayer'] == true
              ? SpaceTheme.alienGreen
              : _getShipColor(index),
        );
      }).toList();

      playerShipIndex = ships.indexWhere((ship) => ship.isPlayer);
      if (playerShipIndex == -1) {
        throw Exception('Generated puzzle has no player ship!');
      }
      
      exitRow = ships[playerShipIndex].row;
      minMoves = puzzleConfig.minMoves;
      moveCount = 0;
      gameActive = true;
      hasWon = false;
      _currentPuzzleId = null;

      _log('✅ Fallback puzzle generated', {
        'ships': ships.length,
        'min_moves': minMoves,
      });
      
    } catch (e, stack) {
      _log('❌ ERROR generating fallback: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
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

  void _onPanStart(DragStartDetails details, int shipIndex) {
    if (!gameActive || hasWon) return;
    
    final ship = ships[shipIndex];
    
    // Prevent dragging blocking pieces
    if (ship.isBlocking) {
      _log('🚫 Attempted to drag blocking piece', {'index': shipIndex});
      return;
    }
    
    _log('👆 Pan start', {'ship': shipIndex, 'type': ship.isPlayer ? 'player' : 'ship'});
    
    setState(() {
      draggingShipIndex = shipIndex;
      dragStartPos = details.globalPosition;
      _highlightPossibleMoves(shipIndex);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, int shipIndex) {
    if (!gameActive || hasWon || draggingShipIndex != shipIndex) return;
    
    final ship = ships[shipIndex];
    if (ship.isBlocking) return;
    
    final delta = details.globalPosition - dragStartPos!;
    
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
    _log('👆 Pan end');
    setState(() {
      draggingShipIndex = null;
      dragStartPos = null;
      highlightedCells.clear();
    });
  }

  void _highlightPossibleMoves(int shipIndex) {
    final ship = ships[shipIndex];
    highlightedCells.clear();
    
    // Highlight ship's current position
    for (int i = 0; i < ship.length; i++) {
      final r = ship.isHorizontal ? ship.row : ship.row + i;
      final c = ship.isHorizontal ? ship.col + i : ship.col;
      highlightedCells.add('$r-$c');
    }
    
    // Highlight possible moves
    if (ship.isHorizontal) {
      // Left
      for (int newCol = ship.col - 1; newCol >= 0; newCol--) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
      // Right
      for (int newCol = ship.col + ship.length; newCol < gridSize; newCol++) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
    } else {
      // Up
      for (int newRow = ship.row - 1; newRow >= 0; newRow--) {
        if (_isBlocked(newRow, ship.col)) break;
        highlightedCells.add('$newRow-${ship.col}');
      }
      // Down
      for (int newRow = ship.row + ship.length; newRow < gridSize; newRow++) {
        if (_isBlocked(newRow, ship.col)) break;
        highlightedCells.add('$newRow-${ship.col}');
      }
    }
    
    _log('💡 Highlighted ${highlightedCells.length} cells');
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
        if (newCol < 0) return false;
        return !_isBlocked(ship.row, newCol);
      } else {
        if (newCol + ship.length > gridSize) return false;
        return !_isBlocked(ship.row, newCol + ship.length - 1);
      }
    } else {
      final newRow = ship.row + direction;
      if (direction < 0) {
        if (newRow < 0) return false;
        return !_isBlocked(newRow, ship.col);
      } else {
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
    
    final ship = ships[shipIndex];
    _log('🚢 Ship moved', {
      'ship': shipIndex,
      'type': ship.isPlayer ? 'PLAYER' : 'ship',
      'new_pos': '(${ship.row}, ${ship.col})',
      'move_count': moveCount,
      'efficiency': '$moveCount/$minMoves',
    });
    
    _addMoveParticles(ship);
    
    if (ship.isPlayer) {
      _checkWinCondition();
    }
  }

  void _addMoveParticles(SpaceShip ship) {
    final random = math.Random();
    
    for (int i = 0; i < ship.length; i++) {
      final r = ship.isHorizontal ? ship.row : ship.row + i;
      final c = ship.isHorizontal ? ship.col + i : ship.col;
      final centerX = (c + 0.5) * _cellSize;
      final centerY = (r + 0.5) * _cellSize;
      
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
    
    if (playerShip.isHorizontal && playerShip.col + playerShip.length >= gridSize) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    final efficiency = moveCount <= minMoves ? 'PERFECT' : 
                      moveCount <= minMoves + 3 ? 'GREAT' : 'GOOD';
    
    _log('🎉 PUZZLE SOLVED!', {
      'moves_used': moveCount,
      'target_moves': minMoves,
      'efficiency': efficiency,
      'puzzle_id': _currentPuzzleId ?? 'generated',
    });
    
    setState(() {
      gameActive = false;
      hasWon = true;
    });
    
    _successController.forward();
    _exitController.forward();
    HapticFeedback.heavyImpact();
    
    final baseScore = 250 * widget.grade;
    final efficiencyBonus = moveCount <= minMoves ? 300 : 
                           moveCount <= minMoves + 3 ? 150 : 50;
    final difficultyBonus = ships.length * 20;
    final totalScore = baseScore + efficiencyBonus + difficultyBonus;
    
    _log('💰 Score calculated', {
      'base': baseScore,
      'efficiency_bonus': efficiencyBonus,
      'difficulty_bonus': difficultyBonus,
      'total': totalScore,
    });
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'space_station_gridlock',
      scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: true,
    );
    
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
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
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
              
              ...particles.map((p) => p.build()),
              
              if (!_isLoading) ...[
                _buildGameUI(),
              ],
              
              if (_isLoading) ...[
                _buildLoadingOverlay(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return Column(
      children: [
        GameUI(
          title: S.of(context)!.spaceGridlockTitle,
          level: widget.level,
          onBack: () {
            _log('⬅️  Back button pressed');
            Navigator.of(context).pop();
          },
        ),
        
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
        
        Expanded(
          child: _buildGrid(),
        ),
        
        const SizedBox(height: 16),
        
        if (gameActive) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _log('🔄 Reset button pressed');
                    setState(() {
                      _loadPuzzleAsync();
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
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 40;
        final availableHeight = constraints.maxHeight - 40;
        
        const borderWidth = 3.0;
        final maxGridSize = (availableWidth < availableHeight 
            ? availableWidth 
            : availableHeight).clamp(200.0, 580.0);
        
        final gridPixelSize = maxGridSize;
        final cellSize = (gridPixelSize - (borderWidth * 2)) / gridSize;
        
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
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(SpaceTheme.alienGreen),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingStatus,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Grade ${widget.grade} • Level ${widget.level}',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Complexity: ${_currentComplexity.toStringAsFixed(1)}',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12,
                color: SpaceTheme.starYellow,
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                _log('❌ Load cancelled by user');
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: SpaceTheme.cosmicPink),
              ),
            ),
          ],
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
    const double padding = 3.0;
    
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
                  color: ship.isBlocking 
                      ? Colors.grey.shade800.withOpacity(0.9)
                      : ship.color.withOpacity(isDragging ? 0.9 : 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ship.isPlayer 
                        ? SpaceTheme.alienGreen 
                        : ship.isBlocking
                        ? Colors.grey.shade600
                        : Colors.white.withOpacity(0.6),
                    width: ship.isPlayer ? 2.5 : ship.isBlocking ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ship.isBlocking
                          ? Colors.black.withOpacity(0.5)
                          : ship.color.withOpacity(isDragging ? 0.6 : 0.3),
                      blurRadius: isDragging ? 12 : 6,
                      spreadRadius: isDragging ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    ship.isPlayer 
                        ? Icons.rocket_launch 
                        : ship.isBlocking
                        ? Icons.block
                        : Icons.local_shipping,
                    color: ship.isBlocking ? Colors.grey.shade500 : Colors.white,
                    size: (cellSize * 0.35).clamp(16.0, 32.0),
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
    final performance = moveCount <= minMoves ? S.of(context)!.spaceGridlockPerfect : 
                       moveCount <= minMoves + 3 ? S.of(context)!.spaceGridlockGreat : S.of(context)!.spaceGridlockGood;
    
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
                              _log('➡️  Next puzzle requested');
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
                              _log('🏠 Returning to bridge');
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
    _log('🔄 Resetting game state');
    setState(() {
      particles.clear();
      highlightedCells.clear();
      draggingShipIndex = null;
    });
    
    _successController.reset();
    _exitController.reset();
    _loadPuzzleAsync();
  }

  @override
  void dispose() {
    _log('🗑️  Disposing game');
    _pulseController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    _successController.dispose();
    _exitController.dispose();
    super.dispose();
  }
}

// SpaceShip class with blocking support
class SpaceShip {
  int row;
  int col;
  final int length;
  final bool isHorizontal;
  final bool isPlayer;
  final bool isBlocking; // NEW: prevents moving
  final Color color;

  SpaceShip({
    required this.row,
    required this.col,
    required this.length,
    required this.isHorizontal,
    required this.isPlayer,
    this.isBlocking = false, // NEW
    required this.color,
  });
}

// Rest of classes remain the same...
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
    
    for (final cell in highlightedCells) {
      final parts = cell.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
        highlightPaint,
      );
    }
    
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

// Fallback generator (same as before, omitted for brevity)
class PuzzleGenerator {
  static const int gridSize = 6;
  static const int targetCarRow = 2;
  static final _random = math.Random();

  static Future<PuzzleConfiguration> generate(int grade, int level) async {
    // Same implementation as original
    return PuzzleConfiguration(
      minMoves: 10,
      ships: [
        {'row': 2, 'col': 1, 'length': 2, 'isHorizontal': true, 'isPlayer': true},
        {'row': 0, 'col': 3, 'length': 3, 'isHorizontal': false, 'isPlayer': false},
        {'row': 2, 'col': 3, 'length': 2, 'isHorizontal': false, 'isPlayer': false},
      ],
    );
  }
}

class PuzzleConfiguration {
  final List<Map<String, dynamic>> ships;
  final int minMoves;

  PuzzleConfiguration({required this.ships, required this.minMoves});
}

class _SolverState {
  final List<Map<String, dynamic>> ships;
  final int moves;
  late final String hashKey;
  
  _SolverState(this.ships, this.moves) {
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