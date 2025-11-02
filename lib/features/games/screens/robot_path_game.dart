import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

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
  late AnimationController _warpController;

  late Animation<double> _glowAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _pulseAnimation;

  // Game state
  late PathLevel currentLevel;
  List<ProgramCommand> commandSequence = [];
  bool isExecuting = false;
  bool hasWon = false;
  int currentRobotRow = 0;
  int currentRobotCol = 0;
  int currentRobotDirection = 0; // 0=up, 1=right, 2=down, 3=left
  List<Offset> robotTrail = [];

  final int maxCommands = 30;
  bool showingError = false;
  String errorMessage = '';

  // Drag state
  int? draggedCommandIndex;
  int? draggedOverIndex;
  ProgramCommand? pendingCommand;

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
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
        parent: _successController, curve: Curves.elasticOut);

    _robotMoveController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _particleController.addListener(_updateParticles);

    _warpController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _generateLevel();
    _generateStarfield();
  }

  void _generateStarfield() {
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      particles.add(SpaceParticle(
        position: Offset(
          random.nextDouble() * 1000,
          random.nextDouble() * 1000,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 20,
          (random.nextDouble() - 0.5) * 20,
        ),
        size: 1 + random.nextDouble() * 2,
        opacity: 0.3 + random.nextDouble() * 0.7,
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

  void _insertCommand(ProgramCommand command, int index) {
    if (commandSequence.length < maxCommands && !isExecuting) {
      setState(() {
        commandSequence.insert(index, command);
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

  void _moveCommand(int fromIndex, int toIndex) {
    if (!isExecuting && fromIndex != toIndex) {
      setState(() {
        final command = commandSequence.removeAt(fromIndex);
        final insertIndex = toIndex > fromIndex ? toIndex - 1 : toIndex;
        commandSequence.insert(insertIndex, command);
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
      isExecuting = true;
      showingError = false;
      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      robotTrail.clear();
      robotTrail.add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
    });

    for (int i = 0; i < commandSequence.length; i++) {
      if (!mounted) return;

      final command = commandSequence[i].command;
      bool success = await _executeCommand(command);

      if (!success) {
        _createExplosion(currentRobotCol.toDouble(), currentRobotRow.toDouble());
        setState(() {
          showingError = true;
          errorMessage = S.of(context)!.robotPathError;
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
      errorMessage = S.of(context)!.robotPathNotComplete;
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
    await Future.delayed(const Duration(milliseconds: 400));

    switch (command) {
      case RobotCommand.forward:
        int newRow = currentRobotRow;
        int newCol = currentRobotCol;

        switch (currentRobotDirection) {
          case 0: newRow--; break; // up
          case 1: newCol++; break; // right
          case 2: newRow++; break; // down
          case 3: newCol--; break; // left
        }

        if (newRow < 0 || newRow >= currentLevel.gridSize ||
            newCol < 0 || newCol >= currentLevel.gridSize) {
          return false;
        }

        final cellType = currentLevel.grid[newRow][newCol];
        if (cellType == CellType.asteroid || cellType == CellType.blackHole) {
          return false;
        }

        setState(() {
          currentRobotRow = newRow;
          currentRobotCol = newCol;
          robotTrail.add(Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
          _createTrailParticles(currentRobotCol.toDouble(), currentRobotRow.toDouble());
        });
        return true;

      case RobotCommand.turnLeft:
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          currentRobotDirection = (currentRobotDirection - 1) % 4;
          if (currentRobotDirection < 0) currentRobotDirection = 3;
        });
        return true;

      case RobotCommand.turnRight:
        await Future.delayed(const Duration(milliseconds: 200));
        setState(() {
          currentRobotDirection = (currentRobotDirection + 1) % 4;
        });
        return true;
    }
  }

  void _createTrailParticles(double x, double y) {
    final random = math.Random();
    for (int i = 0; i < 5; i++) {
      particles.add(SpaceParticle(
        position: Offset(x, y),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 40,
          (random.nextDouble() - 0.5) * 40,
        ),
        size: 2 + random.nextDouble() * 3,
        opacity: 0.8,
        color: SpaceTheme.alienGreen,
        lifetime: 0.5,
      ));
    }
  }

  void _createExplosion(double x, double y) {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 50 + random.nextDouble() * 100;
      explosions.add(ExplosionParticle(
        position: Offset(x, y),
        velocity: Offset.fromDirection(angle, speed),
        size: 3 + random.nextDouble() * 5,
        color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      ));
    }
  }

  void _resetRobot() {
    setState(() {
      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      robotTrail.clear();
      isExecuting = false;
      showingError = false;
    });
  }

  void _handleSuccess() {
    setState(() {
      hasWon = true;
      isExecuting = false;
    });

    _successController.forward(from: 0.0);
    _warpController.forward(from: 0.0);

    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 50 + random.nextDouble() * 150;
      explosions.add(ExplosionParticle(
        position: Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()),
        velocity: Offset.fromDirection(angle, speed),
        size: 3 + random.nextDouble() * 6,
        color: [SpaceTheme.alienGreen, SpaceTheme.starYellow, Colors.cyan][random.nextInt(3)],
      ));
    }

    final int baseScore = 100 * widget.grade;
    final int efficiency = (currentLevel.optimalMoves / commandSequence.length * 100).round();
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
          builder: (context) => _buildSuccessDialog(baseScore, bonusScore, efficiency),
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
                  _buildScoreRow(S.of(context)!.baseScore, '+$baseScore', SpaceTheme.alienGreen),
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
                  S.of(context)!.nextLevel,
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

  Widget _buildScoreRow(String label, String value, Color color, {bool bold = false}) {
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

  Widget _buildDialogButton(String text, IconData icon, Color color, VoidCallback onPressed) {
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

  @override
  Widget build(BuildContext context) {
    // FIXED: Add ! null assertion
    final s = S.of(context)!;

    return Scaffold(
      body: SpaceBackground(
        // FIXED: Replaced GameUI wrapper with Scaffold > SpaceBackground
        child: Stack(
          children: [
            // Animated background
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: SpaceBackgroundPainter(
                    glowIntensity: _glowAnimation.value,
                    time: _particleController.value,
                    hasWon: hasWon,
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
                      final isLandscape = orientation == Orientation.landscape;

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

            // FIXED: Add GameUI as a header inside the Stack
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
    final double availableHeight = constraints.maxHeight;
    final double availableWidth = constraints.maxWidth;

    final double maxGridSize = math.min(
      availableWidth * 0.92,
      availableHeight * 0.45,
    );
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0).copyWith(top: 80), // Push content below header
        child: Column(
          children: [
            // FIXED: Removed _buildHeader(), GameUI is now the header
            _buildGrid(cellSize, maxGridSize),
            const SizedBox(height: 12),
            if (showingError) ...[
              _buildErrorMessage(),
              const SizedBox(height: 12),
            ],
            _buildProgramArea(constraints.maxWidth),
            const SizedBox(height: 12),
            _buildCommandPalette(),
            const SizedBox(height: 12),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    final double availableHeight = constraints.maxHeight;
    final double availableWidth = constraints.maxWidth;

    final double maxGridSize = math.min(
      availableWidth * 0.45,
      availableHeight * 0.85,
    );
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return Row(
      children: [
        // Left side - Grid
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0).copyWith(top: 80), // Push content below header
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGrid(cellSize, maxGridSize),
                  if (showingError) ...[
                    const SizedBox(height: 12),
                    _buildErrorMessage(),
                  ],
                ],
              ),
            ),
          ),
        ),

        // --- UPDATED Right side - Controls ---
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(12.0).copyWith(top: 80), // Push content below header
            // Use a Column to stack Program, Palette, and Controls
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Program Area is now Expanded to fill available space
                Expanded(
                  child: _buildProgramArea(availableWidth * 0.45),
                ),
                const SizedBox(height: 12),
                _buildCommandPalette(),
                const SizedBox(height: 12),
                _buildControlButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: _buildHeader() is removed, as GameUI provides it.

  Widget _buildGrid(double cellSize, double maxGridSize) {
    return Center(
      child: Container(
        width: maxGridSize,
        height: maxGridSize,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              SpaceTheme.deepSpace.withOpacity(0.4),
              SpaceTheme.deepSpace.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SpaceTheme.alienGreen.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.alienGreen.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
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
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                left: currentRobotCol * cellSize,
                top: currentRobotRow * cellSize,
                child: _buildRobot(cellSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, double cellSize) {
    final cellType = currentLevel.grid[row][col];

    return Container(
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
  }

  Widget _buildCellContent(CellType cellType, double cellSize) {
    switch (cellType) {
      case CellType.empty:
        return const SizedBox();

      case CellType.asteroid:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value * 0.9,
              child: Container(
                margin: EdgeInsets.all(cellSize * 0.1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.grey[800]!,
                      Colors.grey[900]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.circle,
                    color: Colors.grey[700],
                    size: cellSize * 0.4,
                  ),
                ),
              ),
            );
          },
        );

      case CellType.blackHole:
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.all(cellSize * 0.1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SpaceTheme.nebulaPurple.withOpacity(_glowAnimation.value),
                    Colors.black,
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.nebulaPurple.withOpacity(_glowAnimation.value * 0.8),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            );
          },
        );

      case CellType.start:
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                SpaceTheme.alienGreen.withOpacity(0.4),
                SpaceTheme.alienGreen.withOpacity(0.1),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.flight_takeoff,
              color: SpaceTheme.alienGreen,
              size: cellSize * 0.6,
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
                    SpaceTheme.starYellow.withOpacity(0.4 * _pulseAnimation.value),
                    SpaceTheme.starYellow.withOpacity(0.1),
                  ],
                ),
              ),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.stars,
                    color: SpaceTheme.starYellow,
                    size: cellSize * 0.6,
                  ),
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildRobot(double cellSize) {
    return Container(
      width: cellSize,
      height: cellSize,
      child: Center(
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: currentRobotDirection * math.pi / 2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (hasWon ? SpaceTheme.starYellow : Colors.cyan)
                          .withOpacity(_glowAnimation.value * 0.8),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy,
                  color: hasWon ? SpaceTheme.starYellow : Colors.cyan,
                  size: cellSize * 0.7,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.3),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SpaceTheme.deepSpace.withOpacity(0.8),
            SpaceTheme.nebulaPurple.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SpaceTheme.alienGreen.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.alienGreen.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ... (Program title row - no change here) ...
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SpaceTheme.alienGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.code,
                      color: SpaceTheme.alienGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    S.of(context)!.program,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: commandSequence.length >= maxCommands
                      ? Colors.red.withOpacity(0.3)
                      : SpaceTheme.alienGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: commandSequence.length >= maxCommands
                        ? Colors.red
                        : SpaceTheme.alienGreen,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${commandSequence.length}/$maxCommands',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- REPLACED ReorderableListView with Expanded > ScrollView > Wrap ---
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: draggedOverIndex != null
                      ? SpaceTheme.alienGreen
                      : Colors.white.withOpacity(0.1),
                  width: draggedOverIndex != null ? 2 : 1,
                ),
              ),
              child: commandSequence.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Colors.white.withOpacity(0.3),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            S.of(context)!.emptyProgram,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  // Use a ScrollView in case the commands overflow
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Wrap(
                        spacing: 8, // Horizontal space
                        runSpacing: 8, // Vertical space
                        children: [
                          // Map the commands to chips
                          for (int i = 0; i < commandSequence.length; i++)
                            _buildProgramCommandChip(
                              commandSequence[i],
                              i,
                              // Key is still useful for widget identity
                              key: ValueKey(commandSequence[i].id), 
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          // --- END REPLACEMENT ---
        ],
      ),
    );
  }

  Widget _buildProgramCommandChip(ProgramCommand programCommand, int index, {required Key key}) {
    final command = programCommand.command;
    final commandInfo = _getCommandInfo(command);

    return Padding(
      key: key,
      padding: const EdgeInsets.only(right: 8),
      // OLD GestureDetector wrapper is removed.
      // ReorderableListView handles dragging.
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              commandInfo.color.withOpacity(0.8),
              commandInfo.color.withOpacity(0.4),
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
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          // Set clipBehavior to none to allow the 'X' to pop out
          clipBehavior: Clip.none, 
          children: [
            Center(
              child: Icon(
                commandInfo.icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // --- ADDED: REMOVE BUTTON ---
            Positioned(
              top: -8, // Positioned slightly outside the top-left
              left: -8,
              child: GestureDetector(
                onTap: !isExecuting ? () => _removeCommand(index) : null,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
            // --- END ADDED SECTION ---
          ],
        ),
      ),
    );
  }

  Widget _buildCommandPalette() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.deepSpace.withOpacity(0.7),
            SpaceTheme.deepSpace.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SpaceTheme.alienGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ... (Commands title - no change here) ...
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SpaceTheme.nebulaPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.apps,
                  color: SpaceTheme.nebulaPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                S.of(context)!.commands,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // --- REPLACED Wrap with Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              _buildCommandButton(RobotCommand.forward),
              const SizedBox(width: 12), // Use SizedBox for spacing
              _buildCommandButton(RobotCommand.turnLeft),
              const SizedBox(width: 12),
              _buildCommandButton(RobotCommand.turnRight),
            ],
          ),
          // --- END REPLACEMENT ---
        ],
      ),
    );
  }

  Widget _buildCommandButton(RobotCommand command) {
    final commandInfo = _getCommandInfo(command);

    return GestureDetector(
      onTap: isExecuting ? null : () => _addCommand(command),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            // width: 90,
            // height: 90,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  commandInfo.color.withOpacity(isExecuting ? 0.3 : 0.7),
                  commandInfo.color.withOpacity(isExecuting ? 0.2 : 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: commandInfo.color.withOpacity(isExecuting ? 0.3 : 1.0),
                width: 2,
              ),
              boxShadow: isExecuting ? [] : [
                BoxShadow(
                  color: commandInfo.color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  commandInfo.icon,
                  color: Colors.white.withOpacity(isExecuting ? 0.5 : 1.0),
                  size: 36,
                ),
                const SizedBox(height: 6),
                Text(
                  commandInfo.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(isExecuting ? 0.5 : 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  CommandInfo _getCommandInfo(RobotCommand command) {
    switch (command) {
      case RobotCommand.forward:
        return CommandInfo(
          icon: Icons.arrow_upward,
          color: SpaceTheme.alienGreen,
          label: S.of(context)!.forward,
        );
      case RobotCommand.turnLeft:
        return CommandInfo(
          icon: Icons.rotate_left,
          color: SpaceTheme.nebulaPurple,
          label: S.of(context)!.turnLeft,
        );
      case RobotCommand.turnRight:
        return CommandInfo(
          icon: Icons.rotate_right,
          color: SpaceTheme.starYellow,
          label: S.of(context)!.turnRight,
        );
    }
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildControlButton(
          S.of(context)!.run,
          Icons.play_arrow,
          Colors.green,
          _executeProgram,
          enabled: !isExecuting && commandSequence.isNotEmpty,
        ),
        _buildControlButton(
          S.of(context)!.clear,
          Icons.clear_all,
          Colors.orange,
          _clearCommands,
          enabled: !isExecuting && commandSequence.isNotEmpty,
        ),
        _buildControlButton(
          S.of(context)!.reset,
          Icons.refresh,
          Colors.blue,
          _resetRobot,
          enabled: isExecuting || showingError,
        ),
      ],
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: enabled ? 8 : 2,
        shadowColor: enabled ? color.withOpacity(0.5) : Colors.transparent,
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
    _warpController.dispose();
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

enum RobotCommand { forward, turnLeft, turnRight }

enum CellType { empty, asteroid, blackHole, start, goal }

class PathLevel {
  final int gridSize;
  final List<List<CellType>> grid;
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
    // Calculate complexity based on grade and level
    // Grades 1-4, Levels 1-20 each = 80 unique levels
    final complexity = (grade - 1) * 20 + level;
    
    // Determine grid size based on complexity
    int gridSize;
    if (complexity <= 20) {
      gridSize = 5; // Grade 1: 5x5 grid
    } else if (complexity <= 40) {
      gridSize = 6; // Grade 2: 6x6 grid
    } else if (complexity <= 60) {
      gridSize = 7; // Grade 3: 7x7 grid
    } else {
      gridSize = 8; // Grade 4: 8x8 grid
    }

    // Generate level based on complexity
    // final random = math.Random(complexity);
    final random = math.Random();
    
    // Initialize empty grid
    final grid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => CellType.empty),
    );

    // Place start (top-left area)
    int startRow = random.nextInt(2);
    int startCol = random.nextInt(2);
    grid[startRow][startCol] = CellType.start;

    // Place goal (bottom-right area)
    int goalRow = gridSize - 1 - random.nextInt(2);
    int goalCol = gridSize - 1 - random.nextInt(2);
    grid[goalRow][goalCol] = CellType.goal;

    // Add obstacles based on complexity
    int numObstacles = (complexity / 4).floor() + 2;
    numObstacles = math.min(numObstacles, (gridSize * gridSize * 0.3).floor());

    for (int i = 0; i < numObstacles; i++) {
      int wallRow = random.nextInt(gridSize);
      int wallCol = random.nextInt(gridSize);
      
      // Don't place walls on start, goal, or adjacent to them
      if (grid[wallRow][wallCol] == CellType.empty &&
          !_isAdjacent(wallRow, wallCol, startRow, startCol) &&
          !_isAdjacent(wallRow, wallCol, goalRow, goalCol)) {
        // FIXED: Changed CellType.wall to CellType.asteroid
        grid[wallRow][wallCol] = CellType.asteroid;
      }
    }

    // Calculate optimal moves (Manhattan distance + adjustments)
    int optimalMoves = (goalRow - startRow).abs() + (goalCol - startCol).abs();
    optimalMoves += (complexity / 10).floor(); // Add turns based on complexity

    return PathLevel(
      gridSize: gridSize,
      grid: grid,
      startRow: startRow,
      startCol: startCol,
      startDirection: 1, // Start facing right
      goalRow: goalRow,
      goalCol: goalCol,
      optimalMoves: optimalMoves,
    );
  }

  static bool _isAdjacent(int row1, int col1, int row2, int col2) {
    return (row1 - row2).abs() <= 1 && (col1 - col2).abs() <= 1;
  }
}

class PathState {
  final int row;
  final int col;
  final int direction;
  final int moves;

  PathState(this.row, this.col, this.direction, this.moves);
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
    opacity = ((lifetime - age) / lifetime).clamp(0.0, 1.0);
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
    velocity = velocity * 0.95;
    life -= 0.016;
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
                color: color.withOpacity(life.clamp(0.0, 1.0) * 0.5),
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
      ..color = SpaceTheme.alienGreen.withOpacity(0.6 * glowIntensity)
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

class SpaceBackgroundPainter extends CustomPainter {
  final double glowIntensity;
  final double time;
  final bool hasWon;

  SpaceBackgroundPainter({
    required this.glowIntensity,
    required this.time,
    required this.hasWon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Nebula effect
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: hasWon
            ? [
                SpaceTheme.starYellow.withOpacity(0.3 * glowIntensity),
                SpaceTheme.alienGreen.withOpacity(0.2 * glowIntensity),
                Colors.transparent,
              ]
            : [
                SpaceTheme.nebulaPurple.withOpacity(0.2 * glowIntensity),
                SpaceTheme.alienGreen.withOpacity(0.1 * glowIntensity),
                Colors.transparent,
              ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));

    canvas.drawCircle(center, size.width * 0.6, nebulaPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(0.05 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(SpaceBackgroundPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.time != time ||
      oldDelegate.hasWon != hasWon;
}

