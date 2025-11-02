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
  late AnimationController _roverWheelController;

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

  final int maxCommands = 20;
  bool showingError = false;
  String errorMessage = '';

  // Particles
  List<SpaceParticle> particles = [];
  List<ExplosionParticle> explosions = [];
  List<DustParticle> dustParticles = [];

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
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _roverWheelController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _particleController.addListener(_updateParticles);

    _generateLevel();
    _generateStarfield();
  }

  void _generateStarfield() {
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      particles.add(SpaceParticle(
        position: Offset(
          random.nextDouble() * 1000,
          random.nextDouble() * 1000,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 10,
          (random.nextDouble() - 0.5) * 10,
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
      dustParticles.removeWhere((d) => d.update());
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
      isExecuting = true;
      showingError = false;
      currentRobotRow = currentLevel.startRow;
      currentRobotCol = currentLevel.startCol;
      currentRobotDirection = currentLevel.startDirection;
      robotTrail.clear();
      robotTrail.add(
          Offset(currentRobotCol.toDouble(), currentRobotRow.toDouble()));
    });

    for (int i = 0; i < commandSequence.length; i++) {
      if (!mounted) return;

      final command = commandSequence[i].command;
      bool success = await _executeCommand(command);

      if (!success) {
        _createExplosion(
            currentRobotCol.toDouble(), currentRobotRow.toDouble());
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
    await Future.delayed(const Duration(milliseconds: 350));

    switch (command) {
      case RobotCommand.forward:
        return _moveForward(1);

      case RobotCommand.jump:
        return _moveForward(2);

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
    }
  }

  Future<bool> _moveForward(int distance) async {
    int newRow = currentRobotRow;
    int newCol = currentRobotCol;

    // Calculate target position
    for (int i = 0; i < distance; i++) {
      switch (currentRobotDirection) {
        case 0:
          newRow--;
          break; // up
        case 1:
          newCol++;
          break; // right
        case 2:
          newRow++;
          break; // down
        case 3:
          newCol--;
          break; // left
      }
    }

    // Check bounds
    if (newRow < 0 ||
        newRow >= currentLevel.gridSize ||
        newCol < 0 ||
        newCol >= currentLevel.gridSize) {
      return false;
    }

    // Check intermediate cells for jump
    if (distance == 2) {
      int midRow = currentRobotRow;
      int midCol = currentRobotCol;
      switch (currentRobotDirection) {
        case 0:
          midRow--;
          break;
        case 1:
          midCol++;
          break;
        case 2:
          midRow++;
          break;
        case 3:
          midCol--;
          break;
      }

      // Can only jump over asteroids or craters
      if (midRow >= 0 &&
          midRow < currentLevel.gridSize &&
          midCol >= 0 &&
          midCol < currentLevel.gridSize) {
        final midCell = currentLevel.grid[midRow][midCol];
        if (midCell != CellType.asteroid && midCell != CellType.crater) {
          return false;
        }
      }
    }

    final cellType = currentLevel.grid[newRow][newCol];
    if (cellType == CellType.asteroid ||
        cellType == CellType.blackHole ||
        cellType == CellType.crater ||
        cellType == CellType.energyField) {
      return false;
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
      return false;
    }

    final cellType = currentLevel.grid[targetRow][targetCol];
    if (cellType == CellType.asteroid || cellType == CellType.crater) {
      setState(() {
        currentLevel.grid[targetRow][targetCol] = CellType.empty;
      });
      _createExplosion(targetCol.toDouble(), targetRow.toDouble(), small: true);
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    return false;
  }

  void _createDustParticles(double x, double y) {
    final random = math.Random();
    for (int i = 0; i < 8; i++) {
      dustParticles.add(DustParticle(
        position: Offset(x, y),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 30,
          (random.nextDouble() - 0.5) * 30,
        ),
        size: 2 + random.nextDouble() * 3,
        color: Colors.brown.withOpacity(0.6),
      ));
    }
  }

  void _createExplosion(double x, double y, {bool small = false}) {
    final random = math.Random();
    int count = small ? 10 : 20;
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

    final random = math.Random();
    for (int i = 0; i < 40; i++) {
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
                  painter: MoonSurfacePainter(
                    glowIntensity: _glowAnimation.value,
                    time: _particleController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),

            // Particles
            ...particles.map((p) => p.build()),
            ...explosions.map((e) => e.build()),
            ...dustParticles.map((d) => d.build()),

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
    final double availableHeight = constraints.maxHeight;
    final double availableWidth = constraints.maxWidth;

    final double maxGridSize = math.min(
      availableWidth * 0.92,
      availableHeight * 0.40,
    );
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0).copyWith(top: 80),
        child: Column(
          children: [
            // Grid and controls side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grid
                Expanded(
                  flex: 6,
                  child: _buildGrid(cellSize, maxGridSize),
                ),
                const SizedBox(width: 8),
                // Control buttons
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildControlButton(
                        s.run,
                        Icons.play_arrow,
                        Colors.green,
                        _executeProgram,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      _buildControlButton(
                        s.clear,
                        Icons.clear_all,
                        Colors.orange,
                        _clearCommands,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                      const SizedBox(height: 6),
                      _buildControlButton(
                        s.reset,
                        Icons.refresh,
                        Colors.blue,
                        _resetRobot,
                        enabled: isExecuting || showingError,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (showingError) ...[
              _buildErrorMessage(),
              const SizedBox(height: 12),
            ],
            _buildProgramArea(constraints.maxWidth),
            const SizedBox(height: 12),
            _buildCommandPalette(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    final s = S.of(context)!;
    final double availableHeight = constraints.maxHeight;
    final double availableWidth = constraints.maxWidth;

    final double maxGridSize = math.min(
      availableWidth * 0.42,
      availableHeight * 0.80,
    );
    final double cellSize = maxGridSize / currentLevel.gridSize;

    return Row(
      children: [
        // Left side - Grid and controls
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0).copyWith(top: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGrid(cellSize, maxGridSize),
                  const SizedBox(height: 12),
                  if (showingError) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        s.run,
                        Icons.play_arrow,
                        Colors.green,
                        _executeProgram,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        s.clear,
                        Icons.clear_all,
                        Colors.orange,
                        _clearCommands,
                        enabled: !isExecuting && commandSequence.isNotEmpty,
                        compact: true,
                      ),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        s.reset,
                        Icons.refresh,
                        Colors.blue,
                        _resetRobot,
                        enabled: isExecuting || showingError,
                        compact: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right side - Program and Commands
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(12.0).copyWith(top: 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildProgramArea(availableWidth * 0.45),
                ),
                const SizedBox(height: 12),
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
            colors: [
              const Color(0xFF2C1810).withOpacity(0.4),
              const Color(0xFF1A0F08).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.brown.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.3),
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

    return Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.brown.withOpacity(0.1),
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
              scale: _pulseAnimation.value * 0.85,
              child: Container(
                margin: EdgeInsets.all(cellSize * 0.15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.grey[700]!,
                      Colors.grey[900]!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        );

      case CellType.crater:
        return Container(
          margin: EdgeInsets.all(cellSize * 0.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.black,
                Colors.brown[900]!,
                Colors.brown[700]!,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
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
                    Colors.deepPurple.withOpacity(0.5),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.nebulaPurple
                        .withOpacity(_glowAnimation.value * 0.8),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            );
          },
        );

      case CellType.energyField:
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: EdgeInsets.all(cellSize * 0.15),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.3 * _glowAnimation.value),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
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
                SpaceTheme.alienGreen.withOpacity(0.3),
                SpaceTheme.alienGreen.withOpacity(0.1),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.flag,
              color: SpaceTheme.alienGreen,
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
                    SpaceTheme.starYellow
                        .withOpacity(0.4 * _pulseAnimation.value),
                    SpaceTheme.starYellow.withOpacity(0.1),
                  ],
                ),
              ),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.star,
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

  Widget _buildRover(double cellSize) {
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
                width: cellSize * 0.8,
                height: cellSize * 0.8,
                decoration: BoxDecoration(
                  color: hasWon
                      ? SpaceTheme.starYellow.withOpacity(0.2)
                      : Colors.cyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasWon ? SpaceTheme.starYellow : Colors.cyan,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (hasWon ? SpaceTheme.starYellow : Colors.cyan)
                          .withOpacity(_glowAnimation.value * 0.8),
                      blurRadius: 12,
                      spreadRadius: 2,
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
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Front indicator
                    Positioned(
                      top: cellSize * 0.15,
                      left: cellSize * 0.35,
                      child: Container(
                        width: cellSize * 0.1,
                        height: cellSize * 0.2,
                        decoration: BoxDecoration(
                          color: hasWon ? SpaceTheme.starYellow : Colors.cyan,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(10),
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
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SpaceTheme.deepSpace.withOpacity(0.8),
            SpaceTheme.nebulaPurple.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceTheme.alienGreen.withOpacity(0.3),
          width: 2,
        ),
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
                  Icon(
                    Icons.code,
                    color: SpaceTheme.alienGreen,
                    size: 18,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
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
                          size: 28,
                        ),
                        const SizedBox(height: 6),
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
                    padding: const EdgeInsets.all(8),
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
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCommandChip(ProgramCommand programCommand, int index) {
    final command = programCommand.command;
    final commandInfo = _getCommandInfo(command);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                commandInfo.color.withOpacity(0.8),
                commandInfo.color.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: commandInfo.color,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  commandInfo.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
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
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
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
  }

  Widget _buildCommandPalette() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.deepSpace.withOpacity(0.7),
            SpaceTheme.deepSpace.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
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
              Icon(
                Icons.apps,
                color: SpaceTheme.nebulaPurple,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.commands,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
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
              if (widget.grade >= 4) _buildCommandButton(RobotCommand.wait),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandButton(RobotCommand command) {
    final commandInfo = _getCommandInfo(command);

    return GestureDetector(
      onTap: isExecuting ? null : () => _addCommand(command),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              commandInfo.color.withOpacity(isExecuting ? 0.3 : 0.7),
              commandInfo.color.withOpacity(isExecuting ? 0.2 : 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: commandInfo.color.withOpacity(isExecuting ? 0.3 : 1.0),
            width: 2,
          ),
          boxShadow: isExecuting
              ? []
              : [
                  BoxShadow(
                    color: commandInfo.color.withOpacity(0.4),
                    blurRadius: 8,
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
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              commandInfo.label,
              style: TextStyle(
                color: Colors.white.withOpacity(isExecuting ? 0.5 : 0.9),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      case RobotCommand.jump:
        return CommandInfo(
          icon: Icons.redo,
          color: Colors.teal,
          label: 'Jump',
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
      case RobotCommand.destroy:
        return CommandInfo(
          icon: Icons.clear,
          color: Colors.red,
          label: 'Destroy',
        );
      case RobotCommand.wait:
        return CommandInfo(
          icon: Icons.pause,
          color: Colors.blue,
          label: 'Wait',
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
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: enabled ? 6 : 2,
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
    _roverWheelController.dispose();
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

enum RobotCommand { forward, jump, turnLeft, turnRight, destroy, wait }

enum CellType {
  empty,
  asteroid,
  crater,
  blackHole,
  energyField,
  start,
  goal
}

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
    final complexity = (grade - 1) * 20 + level;
    final random = math.Random();

    // Determine grid size
    int gridSize;
    if (complexity <= 20) {
      gridSize = 5 + (level ~/ 4);
    } else if (complexity <= 40) {
      gridSize = 6 + (level ~/ 4);
    } else if (complexity <= 60) {
      gridSize = 7 + (level ~/ 4);
    } else {
      gridSize = 8 + (level ~/ 4);
    }
    gridSize = gridSize.clamp(5, 10);

    // Initialize grid
    final grid = List.generate(
      gridSize,
      (i) => List.generate(gridSize, (j) => CellType.empty),
    );

    // Place start - varied positions
    int startRow = level % 2 == 0 ? 0 : gridSize - 1;
    int startCol = random.nextInt(gridSize);
    grid[startRow][startCol] = CellType.start;

    // Place goal - opposite corner area
    int goalRow = startRow == 0 ? gridSize - 1 : 0;
    int goalCol = random.nextInt(gridSize);
    grid[goalRow][goalCol] = CellType.goal;

    // Create interesting path with obstacles
    _createMazePath(grid, startRow, startCol, goalRow, goalCol, complexity, grade);

    // Add obstacles based on grade
    _addObstacles(grid, complexity, grade, startRow, startCol, goalRow, goalCol);

    // Calculate optimal moves
    int optimalMoves = _calculateOptimalPath(
        grid, startRow, startCol, goalRow, goalCol, grade);

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

  static void _createMazePath(List<List<CellType>> grid, int startRow,
      int startCol, int goalRow, int goalCol, int complexity, int grade) {
    final random = math.Random();
    int currentRow = startRow;
    int currentCol = startCol;

    // Create a winding path
    while (currentRow != goalRow || currentCol != goalCol) {
      // Move towards goal with some randomness
      if (random.nextDouble() < 0.7) {
        if (currentRow < goalRow) {
          currentRow++;
        } else if (currentRow > goalRow) {
          currentRow--;
        } else if (currentCol < goalCol) {
          currentCol++;
        } else if (currentCol > goalCol) {
          currentCol--;
        }
      } else {
        // Random direction
        int dir = random.nextInt(4);
        switch (dir) {
          case 0:
            if (currentRow > 0) currentRow--;
            break;
          case 1:
            if (currentCol < grid[0].length - 1) currentCol++;
            break;
          case 2:
            if (currentRow < grid.length - 1) currentRow++;
            break;
          case 3:
            if (currentCol > 0) currentCol--;
            break;
        }
      }

      if (grid[currentRow][currentCol] == CellType.empty) {
        grid[currentRow][currentCol] = CellType.empty; // Keep as path
      }
    }
  }

  static void _addObstacles(List<List<CellType>> grid, int complexity,
      int grade, int startRow, int startCol, int goalRow, int goalCol) {
    final random = math.Random();
    
    // Number of obstacles increases with complexity
    int numAsteroids = (complexity / 8).floor() + 2;
    int numCraters = grade >= 2 ? (complexity / 12).floor() + 1 : 0;
    int numBlackHoles = grade >= 3 ? (complexity / 20).floor() : 0;
    int numEnergyFields = grade >= 4 ? (complexity / 15).floor() : 0;

    // Add asteroids
    for (int i = 0; i < numAsteroids; i++) {
      int row = random.nextInt(grid.length);
      int col = random.nextInt(grid[0].length);

      if (grid[row][col] == CellType.empty &&
          !_isNearStartOrGoal(row, col, startRow, startCol, goalRow, goalCol)) {
        grid[row][col] = CellType.asteroid;
      }
    }

    // Add craters
    for (int i = 0; i < numCraters; i++) {
      int row = random.nextInt(grid.length);
      int col = random.nextInt(grid[0].length);

      if (grid[row][col] == CellType.empty &&
          !_isNearStartOrGoal(row, col, startRow, startCol, goalRow, goalCol)) {
        grid[row][col] = CellType.crater;
      }
    }

    // Add black holes
    for (int i = 0; i < numBlackHoles; i++) {
      int row = random.nextInt(grid.length);
      int col = random.nextInt(grid[0].length);

      if (grid[row][col] == CellType.empty &&
          !_isNearStartOrGoal(row, col, startRow, startCol, goalRow, goalCol)) {
        grid[row][col] = CellType.blackHole;
      }
    }

    // Add energy fields
    for (int i = 0; i < numEnergyFields; i++) {
      int row = random.nextInt(grid.length);
      int col = random.nextInt(grid[0].length);

      if (grid[row][col] == CellType.empty &&
          !_isNearStartOrGoal(row, col, startRow, startCol, goalRow, goalCol)) {
        grid[row][col] = CellType.energyField;
      }
    }
  }

  static bool _isNearStartOrGoal(int row, int col, int startRow, int startCol,
      int goalRow, int goalCol) {
    return (row - startRow).abs() <= 1 && (col - startCol).abs() <= 1 ||
        (row - goalRow).abs() <= 1 && (col - goalCol).abs() <= 1;
  }

  static int _calculateOptimalPath(List<List<CellType>> grid, int startRow,
      int startCol, int goalRow, int goalCol, int grade) {
    // Simple BFS to find shortest path considering available commands
    final queue = <PathState>[];
    final visited = <String>{};

    queue.add(PathState(startRow, startCol, 1, 0));
    visited.add('$startRow,$startCol,1');

    while (queue.isNotEmpty) {
      final state = queue.removeAt(0);

      if (state.row == goalRow && state.col == goalCol) {
        return state.moves;
      }

      // Try all possible moves
      for (int newDir = 0; newDir < 4; newDir++) {
        int turnCost = (state.direction - newDir).abs();
        if (turnCost > 2) turnCost = 4 - turnCost;

        // Try forward move
        int newRow = state.row;
        int newCol = state.col;
        switch (newDir) {
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

        if (newRow >= 0 &&
            newRow < grid.length &&
            newCol >= 0 &&
            newCol < grid[0].length) {
          final cell = grid[newRow][newCol];
          if (cell != CellType.asteroid &&
              cell != CellType.blackHole &&
              cell != CellType.crater &&
              cell != CellType.energyField) {
            String key = '$newRow,$newCol,$newDir';
            if (!visited.contains(key)) {
              visited.add(key);
              queue.add(PathState(newRow, newCol, newDir, state.moves + turnCost + 1));
            }
          }
        }

        // Try jump (grade 2+)
        if (grade >= 2) {
          int jumpRow = state.row;
          int jumpCol = state.col;
          for (int i = 0; i < 2; i++) {
            switch (newDir) {
              case 0:
                jumpRow--;
                break;
              case 1:
                jumpCol++;
                break;
              case 2:
                jumpRow++;
                break;
              case 3:
                jumpCol--;
                break;
            }
          }

          if (jumpRow >= 0 &&
              jumpRow < grid.length &&
              jumpCol >= 0 &&
              jumpCol < grid[0].length) {
            final cell = grid[jumpRow][jumpCol];
            if (cell != CellType.blackHole && cell != CellType.energyField) {
              String key = '$jumpRow,$jumpCol,$newDir';
              if (!visited.contains(key)) {
                visited.add(key);
                queue.add(PathState(jumpRow, jumpCol, newDir, state.moves + turnCost + 1));
              }
            }
          }
        }
      }
    }

    // Fallback
    return (goalRow - startRow).abs() + (goalCol - startCol).abs() + 5;
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

class DustParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double life;

  DustParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.life = 0.8,
  });

  bool update() {
    position = position + velocity * 0.016;
    velocity = velocity * 0.92;
    life -= 0.025;
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
      ..color = Colors.cyan.withOpacity(0.4 * glowIntensity)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

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

class MoonSurfacePainter extends CustomPainter {
  final double glowIntensity;
  final double time;

  MoonSurfacePainter({
    required this.glowIntensity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw some distant stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);
    final random = math.Random(42);

    for (int i = 0; i < 50; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        random.nextDouble() * 1.5,
        starPaint,
      );
    }

    // Draw horizon
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.brown.withOpacity(0.1 * glowIntensity),
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      horizonPaint,
    );
  }

  @override
  bool shouldRepaint(MoonSurfacePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity || oldDelegate.time != time;
}