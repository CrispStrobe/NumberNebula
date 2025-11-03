// robot_path_game.dart (MODIFIED)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../services/robot_path_generator.dart' as gen;

class RobotPathGame extends StatefulWidget {
  final int grade;
  final int level;

  const RobotPathGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<RobotPathGame> createState() => _RobotPathGameState();
}

class _RobotPathGameState extends State<RobotPathGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _successController;
  late AnimationController _robotMoveController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _rotateController;

  late Animation<double> _glowAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  // Game state
  late PathLevel currentLevel;
  late List<List<CellType>> pristineGrid;

  List<ProgramCommand> commandSequence = [];
  bool isExecuting = false;
  bool hasWon = false;
  int currentRobotRow = 0;
  int currentRobotCol = 0;
  int currentRobotDirection = 0;
  List<Offset> robotTrail = [];

  // *** FIX 2: VISUAL INDICATOR ***
  int? currentlyExecutingIndex;

  int maxCommands = 20;
  bool showingError = false;
  String errorMessage = '';

  // Particles
  List<SpaceParticle> particles = [];
  List<ExplosionParticle> explosions = [];

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _robotMoveController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_rotateController);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _particleController.addListener(_updateParticles);

    _generateLevel();
    _generateStarfield();
  }

  void _generateStarfield() {
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      particles.add(SpaceParticle(
        position: Offset(
          random.nextDouble() * 2000,
          random.nextDouble() * 2000,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 8,
          (random.nextDouble() - 0.5) * 8,
        ),
        size: 1 + random.nextDouble() * 2,
        opacity: 0.4 + random.nextDouble() * 0.6,
        color: Colors.white,
      ));
    }
  }

  void _updateParticles() {
    setState(() {
      particles.removeWhere((p) => p.update());
      explosions.removeWhere((e) => e.update());
    });
  }

  void _generateLevel() {
    setState(() {
      currentLevel = PathLevel.generate(widget.grade, widget.level);
      
      maxCommands = (currentLevel.optimalMoves * 1.75).ceil().clamp(20, 40);

      // Save a copy of the original grid
      pristineGrid = currentLevel.grid.map((row) => List<CellType>.from(row)).toList();

      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      commandSequence.clear();
      robotTrail.clear();
      hasWon = false;
      isExecuting = false;
      showingError = false;
    });
  }

  void _addCommand(RobotCommand command) {
    if (commandSequence.length < maxCommands && !isExecuting) {
      setState(() {
        commandSequence.add(ProgramCommand(
          command: command,
          id: DateTime.now().millisecondsSinceEpoch.toString() +
              commandSequence.length.toString(),
        ));
      });
    }
  }

  void _removeCommand(int index) {
    if (!isExecuting) {
      setState(() {
        commandSequence.removeAt(index);
      });
    }
  }

  void _clearCommands() {
    if (!isExecuting) {
      setState(() {
        commandSequence.clear();
      });
    }
  }

  Future<void> _executeProgram() async {
    if (isExecuting || commandSequence.isEmpty) return;

    setState(() {
      // Restore the grid to its original state before running
      currentLevel.grid = pristineGrid.map((row) => List<CellType>.from(row)).toList();

      isExecuting = true;
      showingError = false;
      // *** FIX 1: BETTER ERRORS ***
      errorMessage = ''; // Clear any previous specific errors
      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      robotTrail.clear();
      robotTrail.add(
          Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
    });

    for (int i = 0; i < commandSequence.length; i++) {
      if (!mounted) return;

      // *** FIX 2: VISUAL INDICATOR ***
      // Set the currently executing index
      setState(() {
        currentlyExecutingIndex = i;
      });

      final command = commandSequence[i].command;
      bool success = await _executeCommand(command);

      if (!success) {
        _createExplosion(
            currentRobotCol.toDouble(), currentRobotRow.toDouble());
        
        // *** FIX 1: BETTER ERRORS ***
        // Check if a specific error was set. If not, use the generic crash message.
        setState(() {
          showingError = true;
          if (errorMessage.isEmpty) {
            try {
              errorMessage = S.of(context)!.robotPathError;
            } catch (_) {
              errorMessage = "Robot has crashed!";
            }
          }
        });
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          context.read<GameProvider>().recordLevelWin(
                gameType: 'robot_path_game',
                scoreGained: 0,
                difficulty: widget.level,
                wasSuccessful: false,
              );
        }

        _resetRobot();
        return;
      }

      if (currentRobotRow == currentLevel.goalRow &&
          currentRobotCol == currentLevel.goalCol) {
        _handleSuccess();
        return;
      }
    }

    setState(() {
      showingError = true;
      try {
        errorMessage = S.of(context)!.robotPathNotComplete;
      } catch (_) {
        errorMessage = "Goal not reached!";
      }
    });
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      context.read<GameProvider>().recordLevelWin(
            gameType: 'robot_path_game',
            scoreGained: 0,
            difficulty: widget.level,
            wasSuccessful: false,
          );
    }

    _resetRobot();
  }

  Future<bool> _executeCommand(RobotCommand command) async {
    await Future.delayed(const Duration(milliseconds: 350));

    switch (command) {
      case RobotCommand.forward:
        return _moveForward(1);

      case RobotCommand.jump:
        return _jumpForward();

      case RobotCommand.turnLeft:
        await Future.delayed(const Duration(milliseconds: 150));
        setState(() {
          currentRobotDirection = (currentRobotDirection - 1) % 4;
          if (currentRobotDirection < 0) currentRobotDirection = 3;
        });
        return true;

      case RobotCommand.turnRight:
        await Future.delayed(const Duration(milliseconds: 150));
        setState(() {
          currentRobotDirection = (currentRobotDirection + 1) % 4;
        });
        return true;

      case RobotCommand.destroy:
        return _destroyObstacle();

      case RobotCommand.wait:
        await Future.delayed(const Duration(milliseconds: 300));
        return true;

      case RobotCommand.push:
        return _push();

      case RobotCommand.pull:
        return _pull();
    }
  }

  Future<bool> _moveForward(int distance) async {
    int newRow = currentRobotRow;
    int newCol = currentRobotCol;

    for (int i = 0; i < distance; i++) {
      switch (currentRobotDirection) {
        case 0:
          newRow--;
          break;
        case 1:
          newCol++;
          break;
        case 2:
          newRow++;
          break;
        case 3:
          newCol--;
          break;
      }
    }

    if (newRow < 0 ||
        newRow >= currentLevel.gridSize ||
        newCol < 0 ||
        newCol >= currentLevel.gridSize) {
      return false; // Hit outer boundary (This is a crash, no specific error)
    }
    
    final cellType = currentLevel.grid[newRow][newCol];
    if (cellType == CellType.wall ||
        cellType == CellType.jumpableWall ||
        cellType == CellType.destructible ||
        cellType == CellType.movable) {
      return false; // Hit a solid obstacle (This is a crash)
    }

    setState(() {
      currentRobotRow = newRow;
      currentRobotCol = newCol;
      robotTrail
          .add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
      _createDustParticles(
          currentRobotCol.toDouble(), currentRobotRow.toDouble());
    });
    return true;
  }
  
  Future<bool> _jumpForward() async {
    int targetRow = currentRobotRow;
    int targetCol = currentRobotCol;
    int landingRow = currentRobotRow;
    int landingCol = currentRobotCol;
    
    switch (currentRobotDirection) {
      case 0:
        targetRow--;
        landingRow -= 2;
        break;
      case 1:
        targetCol++;
        landingCol += 2;
        break;
      case 2:
        targetRow++;
        landingRow += 2;
        break;
      case 3:
        targetCol--;
        landingCol -= 2;
        break;
    }
    
    if (targetRow < 0 ||
        targetRow >= currentLevel.gridSize ||
        targetCol < 0 ||
        targetCol >= currentLevel.gridSize) {
      return false; // Trying to jump into a boundary (crash)
    }
    
    if (currentLevel.grid[targetRow][targetCol] != CellType.jumpableWall) {
      // *** FIX 1: BETTER ERRORS ***
      setState(() {
        try {
          errorMessage = S.of(context)!.robotPathErrorNotJumpable;
        } catch (_) {
          errorMessage = "Cannot jump over this!";
        }
      });
      return false; // Not a jumpable wall (logical error)
    }
    
    if (landingRow < 0 ||
        landingRow >= currentLevel.gridSize ||
        landingCol < 0 ||
        landingCol >= currentLevel.gridSize) {
      return false; // Trying to land out of bounds (crash)
    }
    
    final landingCellType = currentLevel.grid[landingRow][landingCol];
    if (landingCellType != CellType.empty &&
        landingCellType != CellType.start &&
        landingCellType != CellType.goal) {
      return false; // Cannot land on another obstacle (crash)
    }

    setState(() {
      currentRobotRow = landingRow;
      currentRobotCol = landingCol;
      robotTrail
          .add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
      _createJumpParticles(
          currentRobotCol.toDouble(), currentRobotRow.toDouble());
    });
    return true;
  }
  
  Future<bool> _destroyObstacle() async {
    int targetRow = currentRobotRow;
    int targetCol = currentRobotCol;

    switch (currentRobotDirection) {
      case 0:
        targetRow--;
        break;
      case 1:
        targetCol++;
        break;
      case 2:
        targetRow++;
        break;
      case 3:
        targetCol--;
        break;
    }

    if (targetRow < 0 ||
        targetRow >= currentLevel.gridSize ||
        targetCol < 0 ||
        targetCol >= currentLevel.gridSize) {
      return false; // Target out of bounds (crash)
    }
    
    final cellType = currentLevel.grid[targetRow][targetCol];
    if (cellType == CellType.destructible) {
      setState(() {
        currentLevel.grid[targetRow][targetCol] = CellType.empty;
      });
      _createExplosion(targetCol.toDouble(), targetRow.toDouble(), small: true);
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    // *** FIX 1: BETTER ERRORS ***
    // Target is not destructible (logical error)
    setState(() {
      try {
        errorMessage = S.of(context)!.robotPathErrorNotDestructible;
      } catch (_) {
        errorMessage = "Target is not destructible!";
      }
    });
    return false;
  }

  Future<bool> _push() async {
    // 1. Find object
    int objRow = currentRobotRow;
    int objCol = currentRobotCol;
    switch (currentRobotDirection) {
      case 0: objRow--; break;
      case 1: objCol++; break;
      case 2: objRow++; break;
      case 3: objCol--; break;
    }

    if (objRow < 0 || objRow >= currentLevel.gridSize || objCol < 0 || objCol >= currentLevel.gridSize) return false; // (crash)
    
    if (currentLevel.grid[objRow][objCol] != CellType.movable) {
      // *** FIX 1: BETTER ERRORS ***
      setState(() {
        try {
          errorMessage = S.of(context)!.robotPathErrorNotMovable;
        } catch (_) {
          errorMessage = "Target is not movable!";
        }
      });
      return false; // (logical error)
    }

    // 2. Find destination
    int destRow = objRow;
    int destCol = objCol;
    switch (currentRobotDirection) {
      case 0: destRow--; break;
      case 1: destCol++; break;
      case 2: destRow++; break;
      case 3: destCol--; break;
    }

    if (destRow < 0 || destRow >= currentLevel.gridSize || destCol < 0 || destCol >= currentLevel.gridSize) return false; // (crash)
    
    // 3. Check if destination is clear
    final destCell = currentLevel.grid[destRow][destCol];
    if (destCell == CellType.empty || destCell == CellType.goal) {
      // 4. Perform push
      setState(() {
        // ... (push logic)
        currentLevel.grid[destRow][destCol] = CellType.movable;
        currentLevel.grid[objRow][objCol] = CellType.empty;
        currentRobotRow = objRow;
        currentRobotCol = objCol;
        robotTrail.add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
        _createDustParticles(currentRobotCol.toDouble(), currentRobotRow.toDouble());
      });
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }
    
    // *** FIX 1: BETTER ERRORS ***
    // Can't push into a wall (logical error)
    setState(() {
      try {
        errorMessage = S.of(context)!.robotPathErrorCannotPush;
      } catch (_) {
        errorMessage = "Cannot push! Destination is blocked.";
      }
    });
    return false;
  }

  Future<bool> _pull() async {
    // 1. Find robot's destination (behind robot)
    int robotDestRow = currentRobotRow;
    int robotDestCol = currentRobotCol;
    switch (currentRobotDirection) {
      case 0: robotDestRow++; break;
      case 1: robotDestCol--; break;
      case 2: robotDestRow--; break;
      case 3: robotDestCol++; break;
    }
    
    if (robotDestRow < 0 || robotDestRow >= currentLevel.gridSize || robotDestCol < 0 || robotDestCol >= currentLevel.gridSize) return false; // (crash)

    // 2. Check if robot's destination is clear
    final robotDestCell = currentLevel.grid[robotDestRow][robotDestCol];
    if (robotDestCell != CellType.empty && robotDestCell != CellType.goal) {
      // *** FIX 1: BETTER ERRORS ***
      setState(() {
        try {
          errorMessage = S.of(context)!.robotPathErrorCannotPull;
        } catch (_) {
          errorMessage = "Cannot pull! Not enough space.";
        }
      });
      return false; // Not enough space for robot (logical error)
    }

    // 3. Find object (in front of robot)
    int objRow = currentRobotRow;
    int objCol = currentRobotCol;
    switch (currentRobotDirection) {
      case 0: objRow--; break;
      case 1: objCol++; break;
      case 2: objRow++; break;
      case 3: objCol--; break;
    }

    if (objRow < 0 || objRow >= currentLevel.gridSize || objCol < 0 || objCol >= currentLevel.gridSize) return false; // (crash)
    
    if (currentLevel.grid[objRow][objCol] != CellType.movable) {
      // *** FIX 1: BETTER ERRORS ***
      setState(() {
        try {
          errorMessage = S.of(context)!.robotPathErrorNotMovable;
        } catch (_) {
          errorMessage = "Target is not movable!";
        }
      });
      return false; // (logical error)
    }

    // 4. Perform pull
    setState(() {
      // ... (pull logic)
      currentLevel.grid[currentRobotRow][currentRobotCol] = CellType.movable;
      currentLevel.grid[objRow][objCol] = CellType.empty;
      currentRobotRow = robotDestRow;
      currentRobotCol = robotDestCol;
      robotTrail.add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
      _createDustParticles(currentRobotCol.toDouble(), currentRobotRow.toDouble());
    });
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  void _createDustParticles(double x, double y) {
    final random = math.Random();
    for (int i = 0; i < 8; i++) {
      particles.add(SpaceParticle(
        position: Offset(x, y),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 30,
          (random.nextDouble() - 0.5) * 30,
        ),
        size: 2 + random.nextDouble() * 3,
        opacity: 0.6,
        color: const Color(0xFFD4A574),
        lifetime: 0.6,
      ));
    }
  }

  void _createJumpParticles(double x, double y) {
    final random = math.Random();
    for (int i = 0; i < 12; i++) {
      particles.add(SpaceParticle(
        position: Offset(x, y),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 40,
          (random.nextDouble() - 0.5) * 40,
        ),
        size: 2 + random.nextDouble() * 4,
        opacity: 0.8,
        color: Colors.cyan,
        lifetime: 0.8,
      ));
    }
  }

  void _createExplosion(double x, double y, {bool small = false}) {
    final random = math.Random();
    int count = small ? 15 : 25;
    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = (small ? 30 : 50) + random.nextDouble() * (small ? 50 : 100);
      explosions.add(ExplosionParticle(
        position: Offset(x, y),
        velocity: Offset.fromDirection(angle, speed),
        size: (small ? 2 : 3) + random.nextDouble() * (small ? 3 : 5),
        color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      ));
    }
  }

  void _resetRobot() {
    setState(() {
      currentLevel.grid = pristineGrid.map((row) => List<CellType>.from(row)).toList();

      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      robotTrail.clear();
      isExecuting = false;
      showingError = false;
      // *** FIX 2: VISUAL INDICATOR ***
      currentlyExecutingIndex = null; // Clear the indicator
    });
  }

  void _handleSuccess() {
    setState(() {
      hasWon = true;
      isExecuting = false;
      // *** FIX 2: VISUAL INDICATOR ***
      currentlyExecutingIndex = null; // Clear the indicator
    });

    _successController.forward(from: 0.0);

    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 50 + random.nextDouble() * 150;
      explosions.add(ExplosionParticle(
        position:
            Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()),
        velocity: Offset.fromDirection(angle, speed),
        size: 3 + random.nextDouble() * 6,
        color: [
          SpaceTheme.alienGreen,
          SpaceTheme.starYellow,
          Colors.cyan
        ][random.nextInt(3)],
      ));
    }

    final int baseScore = 100 * widget.grade;
    final int efficiency =
        (currentLevel.optimalMoves / commandSequence.length * 100).round();
    final int bonusScore = (baseScore * (efficiency / 100.0)).round();
    final int totalScore = baseScore + bonusScore;

    context.read<GameProvider>().recordLevelWin(
          gameType: 'robot_path_game',
          scoreGained: totalScore,
          difficulty: widget.level,
          wasSuccessful: true,
        );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              _buildSuccessDialog(baseScore, bonusScore, efficiency),
        );
      }
    });
  }

  Widget _buildSuccessDialog(int baseScore, int bonusScore, int efficiency) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SpaceTheme.deepSpace.withOpacity(0.95),
              SpaceTheme.nebulaPurple.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.alienGreen.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _successAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.starYellow,
                      SpaceTheme.starYellow.withOpacity(0.5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.congratulations,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.robotPathSuccess,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SpaceTheme.alienGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildScoreRow(S.of(context)!.baseScore, '+$baseScore',
                      SpaceTheme.alienGreen),
                  const SizedBox(height: 8),
                  _buildScoreRow(
                    S.of(context)!.efficiencyBonus,
                    '+$bonusScore ($efficiency%)',
                    SpaceTheme.starYellow,
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _buildScoreRow(
                    S.of(context)!.totalScore,
                    '${baseScore + bonusScore}',
                    Colors.white,
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDialogButton(
                  S.of(context)!.playAgain,
                  Icons.refresh,
                  SpaceTheme.alienGreen,
                  () {
                    Navigator.of(context).pop();
                    _generateLevel();
                  },
                ),
                _buildDialogButton(
                  S.of(context)!.toTheBridge,
                  Icons.arrow_forward,
                  SpaceTheme.nebulaPurple,
                  () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: bold ? 20 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDialogButton(
      String text, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        shadowColor: color.withOpacity(0.5),
      ),
    );
  }
  
  String _getTooltipForCell(CellType cellType, S s) {
    try {
      switch (cellType) {
        case CellType.wall:
          return s.robotPathTooltipWall;
        case CellType.jumpableWall:
          return s.robotPathTooltipJumpable;
        case CellType.destructible:
          return s.robotPathTooltipDestructible;
        case CellType.movable:
          return s.robotPathTooltipMovable;
        case CellType.start:
          return s.robotPathTooltipStart;
        case CellType.goal:
          return s.robotPathTooltipGoal;
        case CellType.empty:
          return '';
      }
    } catch (e) {
      // Fallback if i18n keys don't exist
      switch (cellType) {
        case CellType.wall:
          return "Wall";
        case CellType.jumpableWall:
          return "Jumpable Gap";
        case CellType.destructible:
          return "Destructible Rock";
        case CellType.movable:
          return "Movable Block";
        case CellType.start:
          return "Start";
        case CellType.goal:
          return "Goal";
        default:
          return '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Scaffold(
      body: SpaceBackground(
        child: Stack(
          children: [
            // Animated background
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: MartianSurfacePainter(
                    glowIntensity: _glowAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Particles
            ...particles.map((p) => p.build()),
            ...explosions.map((e) => e.build()),

            SafeArea(
              child: OrientationBuilder(
                builder: (context, orientation) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          orientation == Orientation.landscape;

                      if (isLandscape) {
                        return _buildLandscapeLayout(constraints);
                      } else {
                        return _buildPortraitLayout(constraints);
                      }
                    },
                  );
                },
              ),
            ),

            SafeArea(
              child: GameUI(
                title: s.robotPathTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    final s = S.of(context)!;
    final double availableWidth = constraints.maxWidth;
    
    final double maxGridSize = availableWidth * 0.95;
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0).copyWith(top: 80),
        child: Column(
          children: [
            _buildGrid(cellSize, maxGridSize),
            
            const SizedBox(height: 10),
            if (showingError) ...[
              _buildErrorMessage(),
              const SizedBox(height: 10),
            ],
            _buildProgramArea(availableWidth),
            const SizedBox(height: 10),
            _buildCommandPalette(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    final s = S.of(context)!;
    
    final double maxGridSize = math.min(
      constraints.maxWidth * 0.55,
      constraints.maxHeight * 0.85,
    );
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return Row(
      children: [
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10.0).copyWith(top: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGrid(cellSize, maxGridSize),
                  const SizedBox(height: 10),
                  if (showingError) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        s.run,
                        Icons.play_arrow,
                        const Color(0xFF00C853),
                        _executeProgram,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                      const SizedBox(width: 10),
                      _buildControlButton(
                        s.clear,
                        Icons.clear_all,
                        const Color(0xFFFF6D00),
                        _clearCommands,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(10.0).copyWith(top: 80),
            child: Column(
              children: [
                Expanded(
                  child: _buildProgramArea(constraints.maxWidth * 0.45),
                ),
                const SizedBox(height: 10),
                _buildCommandPalette(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(double cellSize, double maxGridSize) {
    return Center(
      child: Container(
        width: maxGridSize,
        height: maxGridSize,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              const Color(0xFF4A2C2A).withOpacity(0.6),
              const Color(0xFF2D1B1A).withOpacity(0.9),
              const Color(0xFF1A0F0E),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4A574).withOpacity(0.4),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFFD4A574).withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Terrain texture
              CustomPaint(
                size: Size(maxGridSize, maxGridSize),
                painter: TerrainPainter(seed: widget.level),
              ),

              // Grid cells
              for (int row = 0; row < currentLevel.gridSize; row++)
                for (int col = 0; col < currentLevel.gridSize; col++)
                  Positioned(
                    left: col * cellSize,
                    top: row * cellSize,
                    child: _buildCell(row, col, cellSize),
                  ),

              // Trail
              if (robotTrail.length > 1)
                CustomPaint(
                  size: Size(maxGridSize, maxGridSize),
                  painter: TrailPainter(
                    trail: robotTrail,
                    cellSize: cellSize,
                    glowIntensity: _glowAnimation.value,
                  ),
                ),

              // Robot
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                left: currentRobotCol * cellSize,
                top: currentRobotRow * cellSize,
                child: _buildRover(cellSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, double cellSize) {
    final cellType = currentLevel.grid[row][col];
    final s = S.of(context)!;
    final tooltipMessage = _getTooltipForCell(cellType, s);

    Widget cellContent = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 0.5,
        ),
      ),
      child: _buildCellContent(cellType, cellSize),
    );

    if (tooltipMessage.isEmpty) {
      return cellContent; // Don't wrap empty space
    }
    
    return Tooltip(
      message: tooltipMessage,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: cellContent,
    );
  }

  Widget _buildCellContent(CellType cellType, double cellSize) {
    switch (cellType) {
      case CellType.empty:
        return const SizedBox();
        
      case CellType.wall:
        return AnimatedBuilder(
          animation: _rotateAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotateAnimation.value,
              child: Container(
                margin: EdgeInsets.all(cellSize * 0.12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF6D6D6D),
                      Color(0xFF3D3D3D),
                      Color(0xFF1A1A1A),
                    ],
                    stops: [0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: AsteroidCratersPainter(),
                ),
              ),
            );
          },
        );
        
      case CellType.destructible:
        return Container(
          margin: EdgeInsets.all(cellSize * 0.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Colors.black,
                Color(0xFF8B0000), // Dark Red
                Color(0xFFB22222), // Firebrick
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
        
      case CellType.jumpableWall:
        return Container(
          margin: EdgeInsets.all(cellSize * 0.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF00BCD4),
                Color(0xFF00838F),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
        
      case CellType.movable:
        return Container(
          margin: EdgeInsets.all(cellSize * 0.15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF9C27B0),
                Color(0xFF6A1B9A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.purple.shade100, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        );

      case CellType.start:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF00E676).withOpacity(0.4),
                const Color(0xFF00E676).withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.flight_takeoff,
              color: const Color(0xFF00E676),
              size: cellSize * 0.5,
            ),
          ),
        );

      case CellType.goal:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700)
                        .withOpacity(0.5 * _pulseAnimation.value),
                    const Color(0xFFFFD700).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.stars_rounded,
                    color: const Color(0xFFFFD700),
                    size: cellSize * 0.65,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFFD700).withOpacity(0.8),
                        blurRadius: 10,
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

  Widget _buildRover(double cellSize) {
    return Container(
      width: cellSize,
      height: cellSize,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_glowAnimation, _rotateAnimation]),
          builder: (context, child) {
            return Transform.rotate(
              angle: currentRobotDirection * math.pi / 2,
              child: Container(
                width: cellSize * 0.75,
                height: cellSize * 0.75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (hasWon ? const Color(0xFFFFD700) : const Color(0xFF00E5FF))
                          .withOpacity(_glowAnimation.value * 0.9),
                      blurRadius: 16,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Rover body
                    Center(
                      child: Container(
                        width: cellSize * 0.5,
                        height: cellSize * 0.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF37474F),
                              const Color(0xFF263238),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: hasWon
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF00E5FF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Antenna/sensor
                    Positioned(
                      top: cellSize * 0.1,
                      left: cellSize * 0.35,
                      child: Container(
                        width: cellSize * 0.05,
                        height: cellSize * 0.25,
                        decoration: BoxDecoration(
                          color: hasWon
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF00E5FF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Light/sensor head
                    Positioned(
                      top: cellSize * 0.05,
                      left: cellSize * 0.3,
                      child: Container(
                        width: cellSize * 0.15,
                        height: cellSize * 0.15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              hasWon
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFF00E5FF),
                              hasWon
                                  ? const Color(0xFFFFD700).withOpacity(0.3)
                                  : const Color(0xFF00E5FF).withOpacity(0.3),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (hasWon
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFF00E5FF))
                                  .withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Wheels
                    Positioned(
                      bottom: cellSize * 0.05,
                      left: cellSize * 0.15,
                      child: _buildWheel(cellSize * 0.15),
                    ),
                    Positioned(
                      bottom: cellSize * 0.05,
                      right: cellSize * 0.15,
                      child: _buildWheel(cellSize * 0.15),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWheel(double size) {
    return AnimatedBuilder(
      animation: _rotateAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: isExecuting ? _rotateAnimation.value : 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(
                color: const Color(0xFF757575),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.3),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgramArea(double width) {
    return Container(
      width: width,
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 300,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E).withOpacity(0.5),
            const Color(0xFF0D1B5E).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.code,
                      color: Color(0xFF00E5FF),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.program,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: commandSequence.length >= maxCommands
                      ? Colors.red.withOpacity(0.3)
                      : const Color(0xFF00E5FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: commandSequence.length >= maxCommands
                        ? Colors.red
                        : const Color(0xFF00E5FF),
                    width: 2,
                  ),
                ),
                child: Text(
                  '${commandSequence.length}/$maxCommands',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: DragTarget<RobotCommand>(
              onWillAccept: (data) => !isExecuting,
              onAccept: (command) {
                _addCommand(command);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27).withOpacity(0.6),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? Colors.white
                          : const Color(0xFF00E5FF).withOpacity(0.3),
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: commandSequence.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app,
                                color: Colors.white.withOpacity(0.3),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                S.of(context)!.emptyProgram,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (int i = 0; i < commandSequence.length; i++)
                                _buildProgramCommandChip(
                                  commandSequence[i],
                                  i,
                                ),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgramCommandChip(ProgramCommand programCommand, int index) {
    final command = programCommand.command;
    final commandInfo = _getCommandInfo(command);
    
    // *** FIX 2: VISUAL INDICATOR ***
    final bool isCurrentlyExecuting = (currentlyExecutingIndex == index);

    final Widget chipUI = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                commandInfo.color.withOpacity(0.9),
                commandInfo.color.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: commandInfo.color,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: commandInfo.color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  commandInfo.icon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: !isExecuting ? () => _removeCommand(index) : null,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
    
    return DragTarget<Object>(
      onWillAccept: (data) => !isExecuting,
      onAccept: (data) {
        if (data is RobotCommand) {
          _insertCommand(data, index);
        } else if (data is int) {
          _reorderCommand(data, index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;

        return Draggable<int>(
          data: index,
          feedback: chipUI,
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: chipUI,
          ),
          // *** FIX 2: VISUAL INDICATOR ***
          // Wrap the child in an AnimatedScale
          child: AnimatedScale(
            scale: isCurrentlyExecuting ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: Container(
              padding: isTarget ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: isTarget
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                    )
                  : null,
              child: chipUI,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommandPalette() {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final s = S.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A237E).withOpacity(0.4),
            const Color(0xFF0D1B5E).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.widgets,
                      color: Color(0xFFFFD700),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.commands,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              if (isPortrait)
                Row(
                  children: [
                    _buildControlButton(
                      s.run,
                      Icons.play_arrow,
                      const Color(0xFF00C853),
                      _executeProgram,
                      enabled: !isExecuting && commandSequence.isNotEmpty,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      s.clear,
                      Icons.clear_all,
                      const Color(0xFFFF6D00),
                      _clearCommands,
                      enabled: !isExecuting && commandSequence.isNotEmpty,
                      compact: true,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildCommandButton(RobotCommand.forward),
              _buildCommandButton(RobotCommand.turnLeft),
              _buildCommandButton(RobotCommand.turnRight),
              if (widget.grade >= 2) _buildCommandButton(RobotCommand.jump),
              if (widget.grade >= 3) _buildCommandButton(RobotCommand.destroy),
              if (widget.grade >= 4) ...[
                _buildCommandButton(RobotCommand.push),
                _buildCommandButton(RobotCommand.pull),
              ]
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommandButton(RobotCommand command) {
    final commandInfo = _getCommandInfo(command);
    
    final Widget tileUI = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            commandInfo.color.withOpacity(isExecuting ? 0.3 : 0.8),
            commandInfo.color.withOpacity(isExecuting ? 0.2 : 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: commandInfo.color.withOpacity(isExecuting ? 0.3 : 1.0),
          width: 2,
        ),
        boxShadow: isExecuting
            ? []
            : [
                BoxShadow(
                  color: commandInfo.color.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            commandInfo.icon,
            color: Colors.white.withOpacity(isExecuting ? 0.5 : 1.0),
            size: 30,
          ),
          const SizedBox(height: 4),
          Text(
            commandInfo.label,
            style: TextStyle(
              color: Colors.white.withOpacity(isExecuting ? 0.5 : 0.95),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    
    return Draggable<RobotCommand>(
      data: command,
      feedback: tileUI,
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: tileUI,
      ),
      child: GestureDetector(
        onTap: isExecuting ? null : () => _addCommand(command),
        child: tileUI,
      ),
    );
  }

  void _reorderCommand(int oldIndex, int newIndex) {
    if (isExecuting) return;
    if (oldIndex == newIndex) return;

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final ProgramCommand item = commandSequence.removeAt(oldIndex);
      commandSequence.insert(newIndex, item);
    });
  }

  void _insertCommand(RobotCommand command, int index) {
    if (isExecuting || commandSequence.length >= maxCommands) return;
    setState(() {
      commandSequence.insert(
          index,
          ProgramCommand(
            command: command,
            id: DateTime.now().millisecondsSinceEpoch.toString() +
                commandSequence.length.toString(),
          ));
    });
  }

  CommandInfo _getCommandInfo(RobotCommand command) {
    switch (command) {
      case RobotCommand.forward:
        return CommandInfo(
          icon: Icons.arrow_upward,
          color: const Color(0xFF00E676),
          label: S.of(context)!.forward,
        );
      case RobotCommand.jump:
        return CommandInfo(
          icon: Icons.trending_up,
          color: const Color(0xFF00BCD4),
          label: S.of(context)!.robotPathJump,
        );
      case RobotCommand.turnLeft:
        return CommandInfo(
          icon: Icons.rotate_left,
          color: const Color(0xFF9C27B0),
          label: S.of(context)!.turnLeft,
        );
      case RobotCommand.turnRight:
        return CommandInfo(
          icon: Icons.rotate_right,
          color: const Color(0xFFFFD700),
          label: S.of(context)!.turnRight,
        );
      case RobotCommand.destroy:
        return CommandInfo(
          icon: Icons.flash_on,
          color: const Color(0xFFFF3D00),
          label: S.of(context)!.robotPathDestroy,
        );
      case RobotCommand.wait:
        return CommandInfo(
          icon: Icons.pause,
          color: const Color(0xFF2196F3),
          label: S.of(context)!.robotPathWait,
        );
      case RobotCommand.push:
        return CommandInfo(
          icon: Icons.arrow_circle_right_outlined,
          color: const Color(0xFF2196F3), // Blue
          label: S.of(context)!.robotPathPush,
        );
      case RobotCommand.pull:
        return CommandInfo(
          icon: Icons.arrow_circle_left_outlined,
          color: const Color(0xFFFF9800), // Orange
          label: S.of(context)!.robotPathPull,
        );
    }
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool enabled = true,
    bool compact = false,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: compact ? 18 : 20),
      label: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: enabled ? 8 : 2,
        shadowColor: enabled ? color.withOpacity(0.6) : Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _successController.dispose();
    _robotMoveController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }
}

// Data Classes
class ProgramCommand {
  final RobotCommand command;
  final String id;

  ProgramCommand({
    required this.command,
    required this.id,
  });
}

class CommandInfo {
  final IconData icon;
  final Color color;
  final String label;

  CommandInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}

enum RobotCommand {
  forward,
  jump,
  turnLeft,
  turnRight,
  destroy,
  wait,
  push,
  pull
}

enum CellType {
  empty,
  wall,
  start,
  goal,
  jumpableWall,
  destructible,
  movable
}

class PathLevel {
  final int gridSize;
  List<List<CellType>> grid;
  final int startRow;
  final int startCol;
  final int startDirection;
  final int goalRow;
  final int goalCol;
  final int optimalMoves;

  PathLevel({
    required this.gridSize,
    required this.grid,
    required this.startRow,
    required this.startCol,
    required this.startDirection,
    required this.goalRow,
    required this.goalCol,
    required this.optimalMoves,
  });
  
  static PathLevel generate(int grade, int level) {
    final generator = gen.RobotPathGenerator();
    
    final complexity = (grade - 1) * 5 + level;
    final int dim = (10 + (complexity * 0.5)).clamp(10, 17).toInt();
    final int pathLen = (9 + complexity).clamp(10, 25).toInt();
    final int obsCount = (1 + (complexity / 3)).clamp(1, 5).toInt();
    
    final double variety;
    if (grade == 1) {
      variety = 0.0;
    } else if (grade == 2) {
      variety = 0.3;
    } else if (grade == 3) {
      variety = 0.6;
    } else {
      variety = 0.9;
    }
    
    final robotLevel = generator.generateLevel(
      dimX: dim,
      dimY: dim,
      pathLength: pathLen,
      obstacleCount: obsCount,
      obstacleVariety: variety,
    );
    
    final int gridSize = robotLevel.grid.length;
    final grid = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (c) => CellType.wall),
    );

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        switch (robotLevel.grid[r][c]) {
          case gen.RobotPathGenerator.PATH:
            grid[r][c] = CellType.empty;
            break;
          case gen.RobotPathGenerator.START:
            grid[r][c] = CellType.start;
            break;
          case gen.RobotPathGenerator.GOAL:
            grid[r][c] = CellType.goal;
            break;
          case gen.RobotPathGenerator.JUMPABLE_WALL:
            grid[r][c] = CellType.jumpableWall;
            break;
          case gen.RobotPathGenerator.DESTRUCTIBLE:
            grid[r][c] = CellType.destructible;
            break;
          case gen.RobotPathGenerator.MOVABLE:
            grid[r][c] = CellType.movable;
            break;
          case gen.RobotPathGenerator.WALL:
          default:
            grid[r][c] = CellType.wall;
            break;
        }
      }
    }
    
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = grid[r][c];
        
        if (cell == CellType.jumpableWall && grade < 2) {
          grid[r][c] = CellType.empty;
        }
        
        if (cell == CellType.destructible && grade < 3) {
          grid[r][c] = CellType.empty;
        }
        
        if (cell == CellType.movable && grade < 4) {
          grid[r][c] = CellType.empty;
        }
      }
    }
    
    int optimalMoves = _calculateOptimalPath(robotLevel);
    
    int startDirection = 1;
    final startPos = robotLevel.start;
    if (_isValidGridPos(grid, startPos.x, startPos.y + 1)) {
      startDirection = 1; // Right
    } else if (_isValidGridPos(grid, startPos.x + 1, startPos.y)) {
      startDirection = 2; // Down
    } else if (_isValidGridPos(grid, startPos.x, startPos.y - 1)) {
      startDirection = 3; // Left
    } else if (_isValidGridPos(grid, startPos.x - 1, startPos.y)) {
      startDirection = 0; // Up
    }

    return PathLevel(
      gridSize: gridSize,
      grid: grid,
      startRow: robotLevel.start.x,
      startCol: robotLevel.start.y,
      startDirection: startDirection,
      goalRow: robotLevel.goal.x,
      goalCol: robotLevel.goal.y,
      optimalMoves: optimalMoves,
    );
  }

  static bool _isValidGridPos(List<List<CellType>> grid, int r, int c) {
    if (r < 0 || r >= grid.length || c < 0 || c >= grid.length) return false;
    final cell = grid[r][c];
    return cell == CellType.empty || cell == CellType.goal;
  }

  static int _calculateOptimalPath(gen.RobotLevel robotLevel) {
    return robotLevel.optimalMoves + robotLevel.obstacles.length;
  }
}

// Visual Effects
class SpaceParticle {
  Offset position;
  Offset velocity;
  double size;
  double opacity;
  Color color;
  double lifetime;
  double age;

  SpaceParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.opacity,
    required this.color,
    this.lifetime = 1.0,
    this.age = 0,
  });

  bool update() {
    age += 0.016;
    position = position + velocity * 0.016;
    opacity = ((lifetime - age) / lifetime).clamp(0.0, 1.0) * 0.8;
    return age >= lifetime;
  }

  Widget build() {
    return Positioned(
      left: position.dx,
      top: position.dy,
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

class ExplosionParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double life;

  ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.life = 1.0,
  });

  bool update() {
    position = position + velocity * 0.016;
    velocity = velocity * 0.94;
    life -= 0.020;
    return life <= 0;
  }

  Widget build() {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(life.clamp(0.0, 1.0)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(life.clamp(0.0, 1.0) * 0.6),
                blurRadius: size * 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrailPainter extends CustomPainter {
  final List<Offset> trail;
  final double cellSize;
  final double glowIntensity;

  TrailPainter({
    required this.trail,
    required this.cellSize,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5 * glowIntensity)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final first = trail.first;
    path.moveTo(
      first.dx * cellSize + cellSize / 2,
      first.dy * cellSize + cellSize / 2,
    );

    for (int i = 1; i < trail.length; i++) {
      final point = trail[i];
      path.lineTo(
        point.dx * cellSize + cellSize / 2,
        point.dy * cellSize + cellSize / 2,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrailPainter oldDelegate) =>
      oldDelegate.trail.length != trail.length ||
      oldDelegate.glowIntensity != glowIntensity;
}

class MartianSurfacePainter extends CustomPainter {
  final double glowIntensity;

  MartianSurfacePainter({required this.glowIntensity});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.4);
    final random = math.Random(42);

    for (int i = 0; i < 80; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        random.nextDouble() * 1.5,
        starPaint,
      );
    }

    // Draw nebula glow
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6B46C1).withOpacity(0.15 * glowIntensity),
          const Color(0xFF4C1D95).withOpacity(0.08 * glowIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.7, size.height * 0.3),
        radius: size.width * 0.4,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.3),
      size.width * 0.4,
      nebulaPaint,
    );
  }

  @override
  bool shouldRepaint(MartianSurfacePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity;
}

class TerrainPainter extends CustomPainter {
  final int seed;

  TerrainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw random terrain spots
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 5 + 2;
      
      paint.color = const Color(0xFF3D2314).withOpacity(random.nextDouble() * 0.3);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(TerrainPainter oldDelegate) => oldDelegate.seed != seed;
}

class AsteroidCratersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final random = math.Random(123);
    for (int i = 0; i < 5; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * size.width * 0.15;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(AsteroidCratersPainter oldDelegate) => false;
}