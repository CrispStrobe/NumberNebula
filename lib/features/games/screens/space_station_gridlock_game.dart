// space_station_gridlock_game.dart - Responsive UI Update
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../services/gridlock_puzzle_tracker.dart';
import '../data/gridlock_puzzles_data.dart';
import 'package:flutter/foundation.dart';

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
  String _loadingStatus = '';
  
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPuzzleAsync();
    });
  }

  void _log(String message, [Map<String, dynamic>? data]) {
    const prefix = '[SpaceGridlock]';
    if (data != null && data.isNotEmpty) {
      if (kDebugMode) debugPrint('$prefix $message: ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    } else {
      debugPrint('$prefix $message');
    }
  }

  void _debugPrintOriginalBoard(String? originalBoard) {
    if (originalBoard == null) return;
    
    _log('🗺️  ORIGINAL BOARD:');
    for (int row = 0; row < gridSize; row++) {
      final rowStr = originalBoard.substring(row * gridSize, (row + 1) * gridSize);
      if (kDebugMode) debugPrint('    $rowStr');
    }
    debugPrint('');
    debugPrint('    Legend: A=player, x=wall, .=empty, o=empty');
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
      _loadingStatus = S.of(context)!.gridlockCalculatingDifficulty;
    });

    try {
      // Calculate complexity - Grades 1-4, Levels 1-20 each
      final rawComplexity = widget.grade + (widget.level / 10.0);
      
      if (rawComplexity < 1.7) {
        _currentComplexity = 1.0;
      } else if (rawComplexity < 2.4) {
        _currentComplexity = 2.0;
      } else if (rawComplexity < 3.3) {
        _currentComplexity = 3.0;
      } else if (rawComplexity < 4.2) {
        _currentComplexity = 4.0;
      } else if (rawComplexity < 5.0) {
        _currentComplexity = 5.0;
      } else if (rawComplexity < 5.7) {
        _currentComplexity = 6.0;
      } else {
        _currentComplexity = 7.0;
      }
      
      _log('🎯 Target complexity calculated', {
        'raw': rawComplexity.toStringAsFixed(2),
        'mapped': _currentComplexity,
        'grade': widget.grade,
        'level': widget.level,
      });
      
      setState(() => _loadingStatus = S.of(context)!.gridlockSearchingDatabase);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      final tracker = context.read<GridlockPuzzleTracker>();
      
      const tolerance = 0.0;
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
        setState(() => _loadingStatus = S.of(context)!.gridlockSelectingPuzzle);
        await Future.delayed(const Duration(milliseconds: 100));
        
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
        
        setState(() => _loadingStatus = S.of(context)!.gridlockLoadingConfig);
        await Future.delayed(const Duration(milliseconds: 100));
        
        _loadPuzzleFromData(selectedPuzzle);
        
        _log('✅ Puzzle loaded successfully');
      } else {
        _log('⚠️  No unused puzzles available, generating fallback');
        setState(() => _loadingStatus = S.of(context)!.gridlockGeneratingPuzzle);
        await Future.delayed(const Duration(milliseconds: 100));
        
        await _generateFallbackPuzzle(_currentComplexity);
      }
      
      setState(() => _loadingStatus = S.of(context)!.gridlockReady);
      await Future.delayed(const Duration(milliseconds: 200));
      
    } catch (e, stack) {
      _log('❌ ERROR loading puzzle: $e');
      if (kDebugMode) debugPrint('Stack trace: $stack');
      
      setState(() => _loadingStatus = S.of(context)!.gridlockError);
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

    _debugPrintOriginalBoard(puzzleData.originalBoard);
    
    try {
      ships = [];
      int blockingCount = 0;
      
      for (int i = 0; i < puzzleData.ships.length; i++) {
        final config = puzzleData.ships[i];
        final isPlayer = config['isPlayer'] == true;
        final isBlocking = config['isBlocking'] == true;
        
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
      if (kDebugMode) debugPrint('Stack trace: $stack');
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
      if (kDebugMode) debugPrint('Stack trace: $stack');
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
    
    for (int i = 0; i < ship.length; i++) {
      final r = ship.isHorizontal ? ship.row : ship.row + i;
      final c = ship.isHorizontal ? ship.col + i : ship.col;
      highlightedCells.add('$r-$c');
    }
    
    if (ship.isHorizontal) {
      for (int newCol = ship.col - 1; newCol >= 0; newCol--) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
      for (int newCol = ship.col + ship.length; newCol < gridSize; newCol++) {
        if (_isBlocked(ship.row, newCol)) break;
        highlightedCells.add('${ship.row}-$newCol');
      }
    } else {
      for (int newRow = ship.row - 1; newRow >= 0; newRow--) {
        if (_isBlocked(newRow, ship.col)) break;
        highlightedCells.add('$newRow-${ship.col}');
      }
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
    
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'space_station_gridlock',
      difficulty: widget.grade + (widget.level ~/ 5),
      score: totalScore,
    ));
    
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
                _buildResponsiveGameUI(),
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

  Widget _buildResponsiveGameUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 380;
        final isTinyScreen = constraints.maxWidth < 320;
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        
        // Determine layout approach based on screen size
        if (isLandscape && constraints.maxHeight < 400) {
          return _buildCompactLandscapeLayout(constraints);
        } else if (isSmallScreen) {
          return _buildCompactPortraitLayout(constraints, isTinyScreen);
        } else {
          return _buildStandardLayout(constraints);
        }
      },
    );
  }

  Widget _buildStandardLayout(BoxConstraints constraints) {
    return Column(
      children: [
        // Compact header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Expanded(
                child: Text(
                  '${S.of(context)!.level} ${widget.level}',
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 40), // Balance the layout
            ],
          ),
        ),
        
        // Stats and controls row
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactStat(S.of(context)!.gridlockMoves, '$moveCount', SpaceTheme.alienGreen),
              _buildCompactStat(S.of(context)!.gridlockTarget, '$minMoves', SpaceTheme.starYellow),
              _buildCompactStat(S.of(context)!.gridlockShips, '${ships.length}', SpaceTheme.cosmicPink),
              if (gameActive) ...[
                IconButton(
                  onPressed: () {
                    _log('🔄 Reset button pressed');
                    setState(_loadPuzzleAsync);
                  },
                  icon: const Icon(Icons.refresh, color: SpaceTheme.nebulaPurple),
                  tooltip: S.of(context)!.gridlockResetPuzzle,
                ),
              ],
            ],
          ),
        ),
        
        // Help text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            S.of(context)!.gridlockDragToExit,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Grid takes remaining space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPortraitLayout(BoxConstraints constraints, bool isTinyScreen) {
    return Column(
      children: [
        // Ultra-compact header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: isTinyScreen ? 4 : 6),
          color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${S.of(context)!.level} ${widget.level}',
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: isTinyScreen ? 14 : 16),
                    ),
                    const SizedBox(width: 12),
                    _buildTinyMoveCounter(),
                  ],
                ),
              ),
              if (gameActive) ...[
                IconButton(
                  onPressed: () => setState(_loadPuzzleAsync),
                  icon: const Icon(Icons.refresh, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ),
        
        // Grid with maximum space
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(isTinyScreen ? 8 : 12),
            child: _buildGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLandscapeLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left sidebar with controls
        Container(
          width: 120,
          color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '${S.of(context)!.level} ${widget.level}',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _buildVerticalStat(S.of(context)!.gridlockMoves, '$moveCount', SpaceTheme.alienGreen),
              const SizedBox(height: 8),
              _buildVerticalStat(S.of(context)!.gridlockTarget, '$minMoves', SpaceTheme.starYellow),
              const Spacer(),
              if (gameActive) ...[
                IconButton(
                  onPressed: () => setState(_loadPuzzleAsync),
                  icon: const Icon(Icons.refresh, color: SpaceTheme.nebulaPurple),
                ),
              ],
            ],
          ),
        ),
        
        // Grid area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildTinyMoveCounter() {
    final isOptimal = moveCount <= minMoves;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOptimal ? SpaceTheme.alienGreen.withValues(alpha: 0.5) : SpaceTheme.starYellow.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$moveCount',
            style: TextStyle(
              color: isOptimal ? SpaceTheme.alienGreen : SpaceTheme.starYellow,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '/$minMoves',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = math.min(constraints.maxWidth, constraints.maxHeight);
        
        const borderWidth = 3.0;
        const minCellSize = 30.0; // Minimum size for playability
        
        // Calculate optimal grid size
        final maxGridSize = availableSize - (borderWidth * 2);
        final cellSize = (maxGridSize / gridSize).clamp(minCellSize, 100.0);
        final gridPixelSize = (cellSize * gridSize) + (borderWidth * 2);
        
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
              color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
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
                                  color: SpaceTheme.alienGreen.withValues(alpha: _glowAnimation.value),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Exit arrow indicator
                    if (_cellSize > 40) Positioned(
                      right: cellSize * 0.1,
                      top: exitRow * cellSize + (cellSize / 2) - 12,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Icon(
                            Icons.arrow_forward,
                            color: SpaceTheme.alienGreen.withValues(alpha: _pulseAnimation.value * 0.7),
                            size: 24,
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

  Widget _buildShip(int index, SpaceShip ship, double cellSize) {
    final isDragging = draggingShipIndex == index;
    const double padding = 3.0;
    
    // Handle 1x1 blocking pieces (walls)
    final shipWidth = ship.length == 1 
        ? cellSize - (padding * 2)
        : ship.isHorizontal 
            ? (cellSize * ship.length) - (padding * 2)
            : cellSize - (padding * 2);
            
    final shipHeight = ship.length == 1
        ? cellSize - (padding * 2)
        : ship.isHorizontal 
            ? cellSize - (padding * 2)
            : (cellSize * ship.length) - (padding * 2);

    return Positioned(
      left: ship.col * cellSize + padding,
      top: ship.row * cellSize + padding,
      child: Semantics(
        label: ship.isPlayer
            ? S.of(context)!.gridlockPlayerShip
            : (ship.isBlocking ? S.of(context)!.gridlockBlockingShip : S.of(context)!.gridlockShip),
        hint: ship.isHorizontal ? S.of(context)!.gridlockDragHorizontally : S.of(context)!.gridlockDragVertically,
        button: true,
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
                      ? Colors.grey.shade800.withValues(alpha: 0.9)
                      : ship.color.withValues(alpha: isDragging ? 0.9 : 0.75),
                  borderRadius: BorderRadius.circular(
                    ship.length == 1 ? 2 : (cellSize < 40 ? 4 : 6)
                  ),
                  border: Border.all(
                    color: ship.isPlayer 
                        ? SpaceTheme.alienGreen 
                        : ship.isBlocking
                        ? Colors.grey.shade600
                        : Colors.white.withValues(alpha: 0.6),
                    width: ship.isPlayer ? 2.0 : ship.isBlocking ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ship.isBlocking
                          ? Colors.black.withValues(alpha: 0.5)
                          : ship.color.withValues(alpha: isDragging ? 0.6 : 0.3),
                      blurRadius: isDragging ? 12 : 6,
                      spreadRadius: isDragging ? 2 : 0,
                    ),
                  ],
                ),
                child: ship.length == 1 
                    ? null  // No icon for 1x1 walls to keep them minimal
                    : Center(
                        child: Icon(
                          ship.isPlayer 
                              ? Icons.rocket_launch 
                              : ship.isBlocking
                              ? Icons.block
                              : Icons.local_shipping,
                          color: ship.isBlocking ? Colors.grey.shade500 : Colors.white,
                          size: (cellSize * 0.4).clamp(14.0, 28.0),
                        ),
                      ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
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
              '${S.of(context)!.grade} ${widget.grade} • ${S.of(context)!.level} ${widget.level}',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.gridlockComplexity(_currentComplexity.toStringAsFixed(1)),
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
              child: Text(
                S.of(context)!.cancel,
                style: const TextStyle(color: SpaceTheme.cosmicPink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessDialog(int totalScore, int efficiencyBonus) {
    final performance = moveCount <= minMoves ? S.of(context)!.spaceGridlockPerfect : 
                       moveCount <= minMoves + 3 ? S.of(context)!.spaceGridlockGreat : S.of(context)!.spaceGridlockGood;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 380;
    final isTinyScreen = screenHeight < 600 || screenWidth < 320;
    
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 40,
              vertical: isSmallScreen ? 24 : 60,
            ),
            child: Container(
              padding: EdgeInsets.all(isTinyScreen ? 16 : isSmallScreen ? 20 : 24),
              constraints: BoxConstraints(
                maxHeight: screenHeight * (isSmallScreen ? 0.85 : 0.7),
                maxWidth: 400,
              ),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Content section with scroll if needed
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flight_takeoff, 
                            size: isTinyScreen ? 40 : isSmallScreen ? 50 : 60, 
                            color: SpaceTheme.alienGreen,
                          ),
                          SizedBox(height: isTinyScreen ? 8 : isSmallScreen ? 12 : 16),
                          Text(
                            S.of(context)!.spaceGridlockWinTitle,
                            style: SpaceTheme.headlineStyle.copyWith(
                              fontSize: isTinyScreen ? 20 : isSmallScreen ? 22 : 24,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isTinyScreen ? 8 : isSmallScreen ? 12 : 16),
                          Text(
                            S.of(context)!.spaceGridlockWinDesc(
                              moveCount,
                              minMoves,
                              performance,
                              totalScore,
                              efficiencyBonus,
                            ),
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: isTinyScreen ? 12 : isSmallScreen ? 13 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Always visible button section
                  SizedBox(height: isTinyScreen ? 12 : isSmallScreen ? 16 : 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: SizedBox(
                          height: isTinyScreen ? 36 : 44,
                          child: ElevatedButton(
                            onPressed: () {
                              _log('➡️  Next puzzle requested');
                              Navigator.of(context).pop();
                              _resetGame();
                            },
                            style: SpaceTheme.secondaryButtonStyle.copyWith(
                              padding: WidgetStateProperty.all(
                                EdgeInsets.symmetric(
                                  horizontal: isTinyScreen ? 12 : 16,
                                  vertical: isTinyScreen ? 8 : 12,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(S.of(context)!.nextPuzzle),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: SizedBox(
                          height: isTinyScreen ? 36 : 44,
                          child: ElevatedButton(
                            onPressed: () {
                              _log('🏠 Returning to bridge');
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: SpaceTheme.primaryButtonStyle.copyWith(
                              padding: WidgetStateProperty.all(
                                EdgeInsets.symmetric(
                                  horizontal: isTinyScreen ? 12 : 16,
                                  vertical: isTinyScreen ? 8 : 12,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(S.of(context)!.toTheBridge),
                            ),
                          ),
                        ),
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
  final bool isBlocking;
  final Color color;

  SpaceShip({
    required this.row,
    required this.col,
    required this.length,
    required this.isHorizontal,
    required this.isPlayer,
    this.isBlocking = false,
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
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: opacity * 0.5),
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
      ..color = (hasWon ? Colors.green : Colors.cyan).withValues(alpha: 0.05 * pulseIntensity)
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
            ? [Colors.green.withValues(alpha: 0.2 * glowIntensity), Colors.transparent]
            : [Colors.cyan.withValues(alpha: 0.1 * glowIntensity), Colors.transparent],
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
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    
    final highlightPaint = Paint()
      ..color = SpaceTheme.alienGreen.withValues(alpha: 0.2);
    
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

// Fallback generator 
class PuzzleGenerator {
  static const int gridSize = 6;
  static const int targetCarRow = 2;
  static Future<PuzzleConfiguration> generate(int grade, int level) async {
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

