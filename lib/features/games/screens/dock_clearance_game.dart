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

  DifficultyConfig? currentDifficulty;
  DockClearancePuzzle? puzzle;
  late List<Ship> ships;
  int moveCount = 0;
  bool _isGenerating = true;
  bool _won = false;
  int? _dragShipId;
  Offset? _dragStart;

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
      _won = false;
      moveCount = 0;
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

  void _tryMoveShip(int shipId, int deltaRow, int deltaCol) {
    if (_won) return;

    final shipIdx = ships.indexWhere((s) => s.id == shipId);
    if (shipIdx == -1) return;
    final ship = ships[shipIdx];

    // Ships can only move along their axis
    if (ship.orientation == ShipOrientation.horizontal && deltaRow != 0) return;
    if (ship.orientation == ShipOrientation.vertical && deltaCol != 0) return;

    Ship moved;
    if (ship.orientation == ShipOrientation.horizontal) {
      moved = ship.copyWith(col: ship.col + deltaCol);
    } else {
      moved = ship.copyWith(row: ship.row + deltaRow);
    }

    // Check bounds
    for (final cell in moved.cells) {
      if (cell[0] < 0 || cell[0] >= puzzle!.boardSize ||
          cell[1] < 0 || cell[1] >= puzzle!.boardSize) {
        return;
      }
    }

    // Check collision
    final testShips = List<Ship>.from(ships);
    testShips[shipIdx] = moved;
    final grid = List.generate(puzzle!.boardSize, (_) => List.filled(puzzle!.boardSize, -1));
    for (final s in testShips) {
      for (final cell in s.cells) {
        if (grid[cell[0]][cell[1]] != -1 && grid[cell[0]][cell[1]] != s.id) return;
        grid[cell[0]][cell[1]] = s.id;
      }
    }

    HapticFeedback.selectionClick();
    setState(() {
      ships[shipIdx] = moved;
      moveCount++;
    });

    // Check win
    if (DockClearancePuzzle.isTargetAtExit(ships, puzzle!.boardSize)) {
      _handleWin();
    }
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
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${s.level}: ${widget.level}  |  Moves: $moveCount',
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
                ),
              ),
              Expanded(child: _buildBoard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final boardSize = puzzle!.boardSize;
    final screenWidth = MediaQuery.of(context).size.width - 64;
    final cellSize = (screenWidth / boardSize).clamp(40.0, 80.0);

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00C9DB).withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: SizedBox(
              width: cellSize * boardSize + 4,
              height: cellSize * boardSize + 4,
              child: Stack(
                children: [
                  // Grid lines
                  ...List.generate(boardSize, (row) {
                    return Positioned.fill(
                      child: Row(
                        children: List.generate(boardSize, (col) {
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade800,
                                width: 0.5,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                  // Exit marker
                  Positioned(
                    top: puzzle!.exitRow * cellSize,
                    right: -6,
                    child: Container(
                      width: 12,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE63946).withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                      ),
                    ),
                  ),
                  // Ships
                  ...ships.map((ship) => _buildShip(ship, cellSize)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShip(Ship ship, double cellSize) {
    final color = _shipColors[ship.id % _shipColors.length];
    final width = ship.orientation == ShipOrientation.horizontal
        ? cellSize * ship.length - 4
        : cellSize - 4;
    final height = ship.orientation == ShipOrientation.vertical
        ? cellSize * ship.length - 4
        : cellSize - 4;

    return Positioned(
      left: ship.col * cellSize + 2,
      top: ship.row * cellSize + 2,
      child: GestureDetector(
        onPanStart: (details) {
          _dragShipId = ship.id;
          _dragStart = details.localPosition;
        },
        onPanUpdate: (details) {
          if (_dragShipId != ship.id || _dragStart == null) return;
          final dx = details.localPosition.dx - _dragStart!.dx;
          final dy = details.localPosition.dy - _dragStart!.dy;

          if (dx.abs() > cellSize * 0.5 || dy.abs() > cellSize * 0.5) {
            if (ship.orientation == ShipOrientation.horizontal) {
              _tryMoveShip(ship.id, 0, dx > 0 ? 1 : -1);
            } else {
              _tryMoveShip(ship.id, dy > 0 ? 1 : -1, 0);
            }
            _dragStart = details.localPosition;
          }
        },
        onPanEnd: (_) {
          _dragShipId = null;
          _dragStart = null;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ship.isTarget ? Colors.white : color.withValues(alpha: 0.5),
              width: ship.isTarget ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: ship.isTarget
                ? const Icon(Icons.rocket_launch, color: Colors.white, size: 20)
                : Icon(Icons.directions_boat, color: Colors.white.withValues(alpha: 0.7), size: 16),
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
                  Text(s.dockClearanceWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.dockClearanceWinDesc(moveCount, bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
