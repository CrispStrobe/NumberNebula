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
import '../services/dock_clearance_logic.dart';

class DockClearanceGame extends StatefulWidget {
  final int grade;
  final int level;
  const DockClearanceGame({super.key, required this.grade, required this.level});

  @override
  State<DockClearanceGame> createState() => _DockClearanceGameState();
}

class _DockClearanceGameState extends State<DockClearanceGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;

  DifficultyConfig? currentDifficulty;
  DockClearancePuzzle? puzzle;
  late List<Ship> ships;
  int moveCount = 0;
  bool _isGenerating = true;
  bool _won = false;

  // Drag state -- ship follows finger smoothly
  int? _dragShipIdx;
  double _dragOffset = 0.0; // pixel offset along axis during drag
  Offset _dragStartLocal = Offset.zero;

  // Undo support
  final List<_MoveRecord> _moveHistory = [];

  static const List<Color> _shipColors = [
    Color(0xFFE63946), // red = target
    Color(0xFF06FFA5),
    Color(0xFF6B48FF),
    Color(0xFFFFD700),
    Color(0xFFFF6B35),
    Color(0xFF00C9DB),
    Color(0xFFFF69B4),
    Color(0xFF8B8B8B),
    Color(0xFFFF6B9D),
    Color(0xFFA855F7),
  ];

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
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _dropController = AnimationController(
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
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _won = false;
      moveCount = 0;
      _moveHistory.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;
    int boardSize;
    int shipCount;
    int minMoves;

    if (grade <= 1) {
      boardSize = 4;
      shipCount = 3;
      minMoves = 1;
    } else if (grade <= 2) {
      boardSize = 5;
      shipCount = 5;
      minMoves = 2;
    } else {
      boardSize = 6;
      shipCount = (6 + currentDifficulty!.level ~/ 3).clamp(6, 10);
      minMoves = 3;
    }

    puzzle = DockClearancePuzzle.generate(
      boardSize: boardSize,
      shipCount: shipCount,
      minMoves: minMoves,
    );

    setState(() {
      ships = puzzle!.ships.map((s) => s.copyWith()).toList();
      _isGenerating = false;
    });
  }

  /// Try to move a ship by delta cells. Returns true if move succeeded.
  bool _tryMoveShip(int shipIdx, int delta) {
    if (_won) return false;
    final ship = ships[shipIdx];

    Ship moved;
    if (ship.orientation == ShipOrientation.horizontal) {
      moved = ship.copyWith(col: ship.col + delta);
    } else {
      moved = ship.copyWith(row: ship.row + delta);
    }

    // Check bounds
    for (final cell in moved.cells) {
      if (cell[0] < 0 || cell[0] >= puzzle!.boardSize ||
          cell[1] < 0 || cell[1] >= puzzle!.boardSize) {
        return false;
      }
    }

    // Check collision
    final testShips = List<Ship>.from(ships);
    testShips[shipIdx] = moved;
    final grid = List.generate(
        puzzle!.boardSize, (_) => List.filled(puzzle!.boardSize, -1));
    for (final s in testShips) {
      for (final cell in s.cells) {
        if (grid[cell[0]][cell[1]] != -1 && grid[cell[0]][cell[1]] != s.id) {
          return false;
        }
        grid[cell[0]][cell[1]] = s.id;
      }
    }

    // Record undo
    _moveHistory.add(_MoveRecord(
      shipIdx: shipIdx,
      oldRow: ship.row,
      oldCol: ship.col,
    ));

    HapticFeedback.selectionClick();
    setState(() {
      ships[shipIdx] = moved;
      moveCount++;
    });

    _dropController.forward(from: 0.0);

    // Check win
    if (DockClearancePuzzle.isTargetAtExit(ships, puzzle!.boardSize)) {
      _handleWin();
    }
    return true;
  }

  void _undoMove() {
    if (_moveHistory.isEmpty || _won) return;
    final record = _moveHistory.removeLast();
    HapticFeedback.selectionClick();
    setState(() {
      ships[record.shipIdx] = ships[record.shipIdx].copyWith(
        row: record.oldRow,
        col: record.oldCol,
      );
      moveCount--;
    });
  }

  void _handleWin() {
    _won = true;
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int efficiencyBonus = puzzle!.optimalMoves > 0
        ? (puzzle!.optimalMoves * 100) ~/ moveCount.clamp(1, 999)
        : 50;
    int totalScore = baseScore + levelBonus + efficiencyBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'dock_clearance',
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
                title: s.dockClearanceTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.dockClearanceInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              // Move counter + undo bar
              _buildControlBar(s),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(child: _buildBoard(constraints));
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Move counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SpaceTheme.nebulaPurple),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.compare_arrows, color: SpaceTheme.starYellow, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${s.moves}: $moveCount',
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Undo button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton.icon(
              onPressed: _moveHistory.isEmpty || _won ? null : _undoMove,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(s.undo),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpaceTheme.nebulaPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(BoxConstraints constraints) {
    final boardSize = puzzle!.boardSize;
    final maxW = (constraints.maxWidth - 48) / boardSize;
    final maxH = (constraints.maxHeight - 16) / boardSize;
    final cellSize = math.min(maxW, maxH).clamp(30.0, 80.0);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00C9DB)
                  .withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
          ),
          child: SizedBox(
            width: cellSize * boardSize + 4,
            height: cellSize * boardSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Grid background
                CustomPaint(
                  size: Size(cellSize * boardSize, cellSize * boardSize),
                  painter: _GridPainter(boardSize: boardSize, cellSize: cellSize),
                ),
                // Exit marker
                Positioned(
                  top: puzzle!.exitRow * cellSize,
                  right: -10,
                  child: Container(
                    width: 14,
                    height: cellSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE63946), Color(0xFFFF6B9D)],
                      ),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE63946)
                              .withValues(alpha: _glowAnimation.value * 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                    ),
                  ),
                ),
                // Ships -- rendered with drag offset
                ...List.generate(ships.length, (idx) {
                  return _buildShip(idx, cellSize);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShip(int shipIdx, double cellSize) {
    final ship = ships[shipIdx];
    final color = _shipColors[ship.id % _shipColors.length];
    final isHoriz = ship.orientation == ShipOrientation.horizontal;
    final shipW = isHoriz ? cellSize * ship.length - 4 : cellSize - 4;
    final shipH = isHoriz ? cellSize - 4 : cellSize * ship.length - 4;
    final isDragging = _dragShipIdx == shipIdx;

    double left = ship.col * cellSize + 2;
    double top = ship.row * cellSize + 2;

    // Apply drag offset for smooth following
    if (isDragging) {
      if (isHoriz) {
        left += _dragOffset;
      } else {
        top += _dragOffset;
      }
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (details) {
          if (_won) return;
          _dragShipIdx = shipIdx;
          _dragStartLocal = details.localPosition;
          _dragOffset = 0.0;
        },
        onPanUpdate: (details) {
          if (_won || _dragShipIdx != shipIdx) return;

          final delta = isHoriz
              ? details.localPosition.dx - _dragStartLocal.dx
              : details.localPosition.dy - _dragStartLocal.dy;

          setState(() {
            _dragOffset = delta;
          });
        },
        onPanEnd: (details) {
          if (_dragShipIdx != shipIdx) return;

          // Snap: determine how many cells to move
          final cellsMoved = (_dragOffset / cellSize).round();
          _dragOffset = 0.0;
          _dragShipIdx = null;

          if (cellsMoved != 0) {
            // Try to move incrementally (handles blocked intermediate cells)
            final direction = cellsMoved > 0 ? 1 : -1;
            for (int i = 0; i < cellsMoved.abs(); i++) {
              if (!_tryMoveShip(shipIdx, direction)) break;
            }
          }
          setState(() {}); // reset drag visual
        },
        child: AnimatedContainer(
          duration: isDragging
              ? Duration.zero
              : const Duration(milliseconds: 150),
          width: shipW,
          height: shipH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ship.isTarget
                  ? Colors.white
                  : color.withValues(alpha: 0.5),
              width: ship.isTarget ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDragging ? 0.7 : 0.4),
                blurRadius: isDragging ? 12 : 6,
                spreadRadius: isDragging ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: ship.isTarget
                ? const Icon(Icons.rocket_launch, color: Colors.white, size: 20)
                : Icon(Icons.directions_boat,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
          ),
        ),
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
                  const Icon(Icons.emoji_events, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.dockClearanceWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.dockClearanceWinDesc(moveCount, bonusScore),
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

class _MoveRecord {
  final int shipIdx;
  final int oldRow;
  final int oldCol;
  _MoveRecord({required this.shipIdx, required this.oldRow, required this.oldCol});
}

/// Draws the grid lines for the board background.
class _GridPainter extends CustomPainter {
  final int boardSize;
  final double cellSize;
  _GridPainter({required this.boardSize, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade800.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= boardSize; i++) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, boardSize * cellSize), paint);
      canvas.drawLine(Offset(0, pos), Offset(boardSize * cellSize, pos), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.boardSize != boardSize || oldDelegate.cellSize != cellSize;
}
