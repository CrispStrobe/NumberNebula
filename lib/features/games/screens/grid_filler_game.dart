// ignore_for_file: unused_element, unused_field
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';

// --- Game Piece Model ---
class GridPiece {
  final int size;
  final int count;
  final Color color;
  int remainingCount;

  GridPiece({
    required this.size,
    required this.count,
    required this.color,
  }) : remainingCount = count;
}

// --- Placed Piece Instance ---
class PlacedPiece {
  final int size;
  Offset position;
  final Color color;

  PlacedPiece({
    required this.size,
    required this.position,
    required this.color,
  });
}

// --- Main Game Widget ---
class GridFillerGame extends StatefulWidget {
  final int grade;
  final int level;

  const GridFillerGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<GridFillerGame> createState() => _GridFillerGameState();
}

class _GridFillerGameState extends State<GridFillerGame>
    with TickerProviderStateMixin {

  late int _pieceTypes; // N: pieces 1×1 through N×N
  late int gridSize;    // Derived: (N*(N+1)/2)

  late List<GridPiece> availablePieces;
  List<PlacedPiece> placedPieces = [];
  
  GridPiece? selectedPiece;
  Offset? hoverGridPosition;
  
  PlacedPiece? draggedPlacedPiece;
  Offset? dragPreviewPosition;
  
  bool _hasWon = false;
  
  final GlobalKey _gridKey = GlobalKey();
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _placeController;
  late AnimationController _winController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  double _currentCellSize = 10.0;
  
  @override
  void initState() {
    super.initState();
    
    debugPrint('🎮 GridFillerGame.initState() - Grade ${widget.grade}, Level ${widget.level}');
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut)
    );
    
    _placeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _winController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );
    
    _initializeGame();
  }
  
  @override
  void dispose() {
    debugPrint('🎮 GridFillerGame.dispose()');
    _glowController.dispose();
    _placeController.dispose();
    _winController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _initializeGame() {
    debugPrint('🎮 Initializing game...');

    // Scale piece types (N) by grade + level
    // N=4 → 10×10, N=5 → 15×15, N=6 → 21×21, N=7 → 28×28, N=8 → 36×36, N=9 → 45×45
    final complexity = widget.grade + (widget.level / 5.0);
    if (complexity <= 2.0) {
      _pieceTypes = 4;  // 10×10
    } else if (complexity <= 3.0) {
      _pieceTypes = 5;  // 15×15
    } else if (complexity <= 4.0) {
      _pieceTypes = 6;  // 21×21
    } else if (complexity <= 5.5) {
      _pieceTypes = 7;  // 28×28
    } else if (complexity <= 7.0) {
      _pieceTypes = 8;  // 36×36
    } else {
      _pieceTypes = 9;  // 45×45
    }
    gridSize = _pieceTypes * (_pieceTypes + 1) ~/ 2;
    debugPrint('🎮 Difficulty: complexity=$complexity, pieceTypes=$_pieceTypes, gridSize=$gridSize');

    final colors = [
      SpaceTheme.starYellow,
      SpaceTheme.planetOrange,
      SpaceTheme.alienGreen,
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFE91E63),
      const Color(0xFF673AB7),
      const Color(0xFF00E676),
      const Color(0xFFFF6F00),
    ];

    availablePieces = List.generate(_pieceTypes, (i) {
      final size = i + 1;
      return GridPiece(
        size: size,
        count: size,
        color: colors[i],
      );
    });
    
    placedPieces = [];
    selectedPiece = null;
    hoverGridPosition = null;
    draggedPlacedPiece = null;
    dragPreviewPosition = null;
    _hasWon = false;
    
    debugPrint('✅ Game initialized with ${availablePieces.length} piece types');
    setState(() {});
  }
  
  bool _canPlacePiece(int pieceSize, Offset position, {PlacedPiece? exclude}) {
    final x = position.dx.toInt();
    final y = position.dy.toInt();
    
    debugPrint('🔍 Checking if ${pieceSize}x$pieceSize can be placed at ($x, $y)');
    
    if (x < 0 || y < 0 || x + pieceSize > gridSize || y + pieceSize > gridSize) {
      debugPrint('❌ Out of bounds! Grid size: $gridSize, Piece would end at (${x + pieceSize}, ${y + pieceSize})');
      return false;
    }
    
    for (int dy = 0; dy < pieceSize; dy++) {
      for (int dx = 0; dx < pieceSize; dx++) {
        final checkX = x + dx;
        final checkY = y + dy;
        
        for (final piece in placedPieces) {
          if (piece == exclude) continue;
          
          final px = piece.position.dx.toInt();
          final py = piece.position.dy.toInt();
          
          if (checkX >= px && checkX < px + piece.size &&
              checkY >= py && checkY < py + piece.size) {
            debugPrint('❌ Collision with ${piece.size}x${piece.size} piece at ($px, $py)');
            return false;
          }
        }
      }
    }
    
    debugPrint('✅ Position is valid!');
    return true;
  }
  
  void _placePieceFromPanel(GridPiece piece, Offset position) {
    debugPrint('📍 Placing new ${piece.size}x${piece.size} piece at $position');
    
    if (!_canPlacePiece(piece.size, position)) {
      debugPrint('❌ Cannot place piece - invalid position');
      return;
    }
    
    final newPiece = PlacedPiece(
      size: piece.size,
      position: position,
      color: piece.color,
    );
    placedPieces.add(newPiece);
    
    final pieceIndex = availablePieces.indexWhere((p) => p.size == piece.size);
    availablePieces[pieceIndex].remainingCount--;
    
    debugPrint('✅ Piece placed! Remaining ${piece.size}x${piece.size}: ${availablePieces[pieceIndex].remainingCount}');
    
    selectedPiece = null;
    _placeController.forward(from: 0.0);
    
    _checkWin();
    setState(() {});
  }
  
  void _movePlacedPiece(PlacedPiece piece, Offset newPosition) {
    debugPrint('🔄 Moving ${piece.size}x${piece.size} from ${piece.position} to $newPosition');
    
    if (!_canPlacePiece(piece.size, newPosition, exclude: piece)) {
      debugPrint('❌ Cannot move piece - invalid position');
      return;
    }
    
    piece.position = newPosition;
    debugPrint('✅ Piece moved successfully!');
    
    setState(() {});
  }
  
  void _removePlacedPiece(PlacedPiece piece) {
    debugPrint('🗑️ Removing ${piece.size}x${piece.size} piece from ${piece.position}');
    
    placedPieces.remove(piece);
    
    final pieceIndex = availablePieces.indexWhere((p) => p.size == piece.size);
    availablePieces[pieceIndex].remainingCount++;
    
    debugPrint('✅ Piece removed! Remaining ${piece.size}x${piece.size}: ${availablePieces[pieceIndex].remainingCount}');
    
    setState(() {});
  }
  
  void _checkWin() {
    final allPlaced = availablePieces.every((p) => p.remainingCount == 0);
    
    debugPrint('🏆 Checking win condition: All placed? $allPlaced');
    
    if (allPlaced && !_hasWon) {
      _hasWon = true;
      HapticFeedback.lightImpact();
      _winController.forward();
      
      final baseScore = 200 * widget.grade;
      final complexityBonus = _pieceTypes * 30;
      final totalScore = baseScore + complexityBonus;
      
      debugPrint('🎉 WINNER! Score: $totalScore');
      
      context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'grid_filler_game',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: [],
    ));
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showWinDialog(totalScore);
      });
    }
  }
  
  Offset _getGridPosition(Offset globalPosition, double cellSize) {
    final RenderBox? box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      debugPrint('⚠️ Grid RenderBox not found');
      return Offset.zero;
    }
    
    final localPos = box.globalToLocal(globalPosition);
    final gridX = (localPos.dx / cellSize).floor().clamp(0, gridSize - 1);
    final gridY = (localPos.dy / cellSize).floor().clamp(0, gridSize - 1);
    
    debugPrint('📐 Global: $globalPosition -> Local: $localPos -> Grid: ($gridX, $gridY)');
    
    return Offset(gridX.toDouble(), gridY.toDouble());
  }
  
  void _showWinDialog(int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎉 Grid Complete!',
          style: TextStyle(color: SpaceTheme.alienGreen, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Perfect fit! All pieces placed!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '+$score points',
              style: const TextStyle(
                color: SpaceTheme.starYellow,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeGame();
            },
            child: const Text('Play Again', style: TextStyle(color: SpaceTheme.alienGreen)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SpaceBackground(child: Container()),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grid Filler',
                            style: TextStyle(
                              color: SpaceTheme.alienGreen,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Fill the $gridSize${context.read<GameProvider>().multiplicationSymbol}$gridSize grid',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: SpaceTheme.alienGreen.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.grid_on, color: SpaceTheme.alienGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${placedPieces.length}/${_pieceTypes * (_pieceTypes + 1) ~/ 2}',
                              style: const TextStyle(
                                color: SpaceTheme.alienGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selectedPiece != null) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedPiece!.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selectedPiece!.color, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.touch_app, color: selectedPiece!.color, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Click to place ${selectedPiece!.size}${context.read<GameProvider>().multiplicationSymbol}${selectedPiece!.size}',
                                style: TextStyle(
                                  color: selectedPiece!.color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Game area
                Expanded(
                  child: Row(
                    children: [
                      // Piece selector
                      Container(
                        width: 200,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Available Pieces',
                                style: TextStyle(
                                  color: SpaceTheme.alienGreen,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: availablePieces.length,
                                itemBuilder: (context, index) {
                                  final piece = availablePieces[index];
                                  return _buildPieceCard(piece);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ElevatedButton(
                                onPressed: _initializeGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SpaceTheme.planetOrange,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Reset Grid'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Grid area
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cellSize = math.min(
                              constraints.maxWidth / gridSize,
                              constraints.maxHeight / gridSize,
                            );
                            _currentCellSize = cellSize;
                            
                            return InteractiveViewer(
                              boundaryMargin: const EdgeInsets.all(double.infinity),
                              minScale: 0.5,
                              maxScale: 3.0,
                              constrained: false,
                              child: Center(
                                child: DragTarget<Object>(
                                  key: _gridKey,
                                  onWillAcceptWithDetails: (details) {
                                    debugPrint('🎯 Grid DragTarget: data=${details.data.runtimeType}');
                                    return details.data is GridPiece || details.data is PlacedPiece;
                                  },
                                  onAcceptWithDetails: (details) {
                                    debugPrint('✅ Grid DragTarget: Accepting drop at ${details.offset}');
                                    
                                    final gridPos = _getGridPosition(details.offset, cellSize);
                                    
                                    if (details.data is GridPiece) {
                                      final piece = details.data as GridPiece;
                                      debugPrint('📦 Dropped GridPiece ${piece.size}x${piece.size} at $gridPos');
                                      if (piece.remainingCount > 0) {
                                        _placePieceFromPanel(piece, gridPos);
                                      }
                                    } else if (details.data is PlacedPiece) {
                                      final piece = details.data as PlacedPiece;
                                      debugPrint('🔄 Dropped PlacedPiece ${piece.size}x${piece.size} at $gridPos');
                                      _movePlacedPiece(piece, gridPos);
                                      draggedPlacedPiece = null;
                                      dragPreviewPosition = null;
                                    }
                                  },
                                  onMove: (details) {
                                    final gridPos = _getGridPosition(details.offset, cellSize);
                                    setState(() {
                                      if (details.data is GridPiece) {
                                        hoverGridPosition = gridPos;
                                      } else if (details.data is PlacedPiece) {
                                        dragPreviewPosition = gridPos;
                                      }
                                    });
                                  },
                                  onLeave: (data) {
                                    debugPrint('👋 Drag left grid area');
                                    setState(() {
                                      hoverGridPosition = null;
                                      dragPreviewPosition = null;
                                    });
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    return MouseRegion(
                                      onHover: (event) {
                                        if (selectedPiece != null) {
                                          final gridPos = _getGridPosition(event.position, cellSize);
                                          setState(() {
                                            hoverGridPosition = gridPos;
                                          });
                                        }
                                      },
                                      child: GestureDetector(
                                        onTapUp: (details) {
                                          debugPrint('👆 Tap detected on grid');
                                          
                                          if (selectedPiece != null) {
                                            final gridPos = _getGridPosition(details.globalPosition, cellSize);
                                            debugPrint('🎯 Click-to-place mode: placing at $gridPos');
                                            _placePieceFromPanel(selectedPiece!, gridPos);
                                          }
                                        },
                                        child: Container(
                                          width: gridSize * cellSize,
                                          height: gridSize * cellSize,
                                          color: Colors.transparent,
                                          child: Stack(
                                            children: [
                                              // Grid background
                                              CustomPaint(
                                                size: Size(
                                                  gridSize * cellSize,
                                                  gridSize * cellSize,
                                                ),
                                                painter: GridFillerPainter(
                                                  gridSize: gridSize,
                                                  cellSize: cellSize,
                                                  hoverPosition: selectedPiece != null ? hoverGridPosition : dragPreviewPosition,
                                                  previewSize: selectedPiece?.size ?? draggedPlacedPiece?.size,
                                                  previewColor: selectedPiece?.color ?? draggedPlacedPiece?.color,
                                                  canPlace: (selectedPiece != null && hoverGridPosition != null && _canPlacePiece(selectedPiece!.size, hoverGridPosition!)) ||
                                                            (draggedPlacedPiece != null && dragPreviewPosition != null && _canPlacePiece(draggedPlacedPiece!.size, dragPreviewPosition!, exclude: draggedPlacedPiece)),
                                                ),
                                              ),
                                              
                                              // Placed pieces
                                              ...placedPieces.where((p) => p != draggedPlacedPiece).map((piece) {
                                                return Positioned(
                                                  left: piece.position.dx * cellSize,
                                                  top: piece.position.dy * cellSize,
                                                  child: _buildPlacedPiece(piece, cellSize),
                                                );
                                              }),
                                              
                                              // Coordinate display
                                              if ((selectedPiece != null && hoverGridPosition != null) || 
                                                  (draggedPlacedPiece != null && dragPreviewPosition != null))
                                                Positioned(
                                                  left: 8,
                                                  top: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.8),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: SpaceTheme.starYellow, width: 2),
                                                    ),
                                                    child: Text(
                                                      'Position: (${(selectedPiece != null ? hoverGridPosition : dragPreviewPosition)?.dx.toInt()}, ${(selectedPiece != null ? hoverGridPosition : dragPreviewPosition)?.dy.toInt()})',
                                                      style: const TextStyle(
                                                        color: SpaceTheme.starYellow,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPieceCard(GridPiece piece) {
    final isSelected = selectedPiece?.size == piece.size;
    final canUse = piece.remainingCount > 0;
    
    return LongPressDraggable<GridPiece>(
      data: piece,
      delay: const Duration(milliseconds: 100),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: piece.size * _currentCellSize,
          height: piece.size * _currentCellSize,
          decoration: BoxDecoration(
            color: piece.color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${piece.size}${context.read<GameProvider>().multiplicationSymbol}${piece.size}',
              style: TextStyle(
                color: Colors.white,
                fontSize: math.max(10, piece.size * 2).toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      onDragStarted: () {
        debugPrint('🎨 Started dragging ${piece.size}x${piece.size} from panel');
      },
      onDragEnd: (details) {
        debugPrint('🎨 Ended dragging ${piece.size}x${piece.size} - wasAccepted: ${details.wasAccepted}');
        setState(() {
          hoverGridPosition = null;
        });
      },
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildPieceCardContent(piece, isSelected, canUse),
      ),
      child: Semantics(
        label: 'Piece ${piece.size}x${piece.size}, ${piece.remainingCount} of ${piece.count} left',
        button: true,
        selected: isSelected,
        enabled: canUse,
        child: GestureDetector(
          onTap: canUse ? () {
            debugPrint('🖱️ Clicked piece ${piece.size}x${piece.size} in panel');
            setState(() {
              selectedPiece = isSelected ? null : piece;
              debugPrint(selectedPiece != null
                  ? '✅ Selected ${piece.size}x${piece.size} - click grid to place'
                  : '❌ Deselected piece');
            });
          } : null,
          child: _buildPieceCardContent(piece, isSelected, canUse),
        ),
      ),
    );
  }
  
  Widget _buildPieceCardContent(GridPiece piece, bool isSelected, bool canUse) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? piece.color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? piece.color.withValues(alpha: _glowAnimation.value)
                  : piece.color.withValues(alpha: 0.3),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canUse
                      ? piece.color.withValues(alpha: 0.7)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${piece.size}${context.read<GameProvider>().multiplicationSymbol}${piece.size}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${piece.size}${context.read<GameProvider>().multiplicationSymbol}${piece.size}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${piece.remainingCount}/${piece.count} left',
                    style: TextStyle(
                      color: canUse ? SpaceTheme.alienGreen : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPlacedPiece(PlacedPiece piece, double cellSize) {
    return LongPressDraggable<PlacedPiece>(
      data: piece,
      delay: const Duration(milliseconds: 100),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: piece.size * cellSize,
          height: piece.size * cellSize,
          decoration: BoxDecoration(
            color: piece.color.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${piece.size}${context.read<GameProvider>().multiplicationSymbol}${piece.size}',
              style: TextStyle(
                color: Colors.white,
                fontSize: math.max(10, piece.size * 2).toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      onDragStarted: () {
        debugPrint('🔄 Started dragging placed ${piece.size}x${piece.size} from ${piece.position}');
        setState(() {
          draggedPlacedPiece = piece;
        });
      },
      onDragEnd: (details) {
        debugPrint('🔄 Drag ended for ${piece.size}x${piece.size} - wasAccepted: ${details.wasAccepted}');
        setState(() {
          draggedPlacedPiece = null;
          dragPreviewPosition = null;
        });
      },
      childWhenDragging: Container(),
      child: Semantics(
        label: 'Placed ${piece.size}x${piece.size} piece',
        hint: 'Tap to remove or long-press to drag',
        button: true,
        child: GestureDetector(
        onTap: () {
          debugPrint('👆 Single tap to remove ${piece.size}x${piece.size}');
          _removePlacedPiece(piece);
        },
        child: Container(
          width: piece.size * cellSize,
          height: piece.size * cellSize,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 1.0,
              colors: [
                Color.lerp(piece.color, Colors.white, 0.3)!,
                piece.color,
                Color.lerp(piece.color, Colors.black, 0.2)!,
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: piece.color, width: 2),
          ),
          child: Center(
            child: Text(
              '${piece.size}${context.read<GameProvider>().multiplicationSymbol}${piece.size}',
              style: TextStyle(
                color: Colors.white,
                fontSize: math.max(10, piece.size * 2).toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// --- Custom Painter ---
class GridFillerPainter extends CustomPainter {
  final int gridSize;
  final double cellSize;
  final Offset? hoverPosition;
  final int? previewSize;
  final Color? previewColor;
  final bool canPlace;
  
  GridFillerPainter({
    required this.gridSize,
    required this.cellSize,
    this.hoverPosition,
    this.previewSize,
    this.previewColor,
    required this.canPlace,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= gridSize; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, gridSize * cellSize),
        gridPaint,
      );
      
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(gridSize * cellSize, i * cellSize),
        gridPaint,
      );
    }
    
    if (hoverPosition != null && previewSize != null && previewColor != null) {
      final rect = Rect.fromLTWH(
        hoverPosition!.dx * cellSize,
        hoverPosition!.dy * cellSize,
        previewSize! * cellSize,
        previewSize! * cellSize,
      );
      
      final previewPaint = Paint()
        ..color = canPlace
            ? previewColor!.withValues(alpha: 0.4)
            : Colors.red.withValues(alpha: 0.3);
      
      final borderPaint = Paint()
        ..color = canPlace ? previewColor! : Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        previewPaint,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        borderPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(GridFillerPainter oldDelegate) {
    return oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.canPlace != canPlace;
  }
}