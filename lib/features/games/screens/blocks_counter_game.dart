// ignore_for_file: constant_identifier_names
// lib/features/games/screens/blocks_counter_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import '../mixins/game_animations_mixin.dart';

import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../constants/difficulty_manager.dart';

// =============================================================================
// VISUAL CONFIGURATION - Tweak these parameters to adjust 3D rendering
// =============================================================================
class _VisualConfig {
  // --- Camera ---
  // static const double cameraDistanceFactor = 2.0; // How far the camera is based on puzzle size
  static const double cameraDistanceFactor = 0.4;
  static final cube.Vector3 cameraTarget = cube.Vector3(0, -0.5, 0); // Aim slightly below center for better view angle

  // --- Lighting ---
  // static final cube.Vector3 lightPosition = cube.Vector3(15, 20, 20); // Position of the main light
  static final cube.Vector3 lightPosition = cube.Vector3(5, 30, 15);
  static const Color lightColor = Colors.white; // Color of the light
  // static const double ambientIntensity = 0.6; // Overall ambient light
  static const double ambientIntensity = 0.9; 
  // static const double diffuseIntensity = 1.0; // Directional light contribution
  static const double diffuseIntensity = 1.5; 
  static const double specularIntensity = 0.2; // Highlight intensity

  // --- Material ---
  static final cube.Vector3 materialSpecular = cube.Vector3(0.8, 0.8, 0.8); // How much light is reflected
  static const double materialShininess = 10.0; // Sharpness of the specular highlight (higher = shinier)

  // --- Cube Appearance ---
  static const double cubeSize = 0.98;
  static const double cubeSpacing = 1.0;
  
  // --- Animation & UI ---
  static const int rotationDurationSeconds = 15;
  // static const double containerHeight = 350.0;
  static const double containerBorderRadius = 16.0;
  
  // --- More vivid, saturated cube colors (adjusted for better contrast) ---
  static const List<Color> cubeColors = [
    Color(0xFF00C8FF), // Brighter Cyan
    Color(0xFF64DD17), // Brighter Lime Green  
    Color(0xFFFF9100), // Brighter Orange
    Color(0xFFD500F9), // Brighter Purple/Magenta
    Color(0xFF304FFE), // Brighter Blue
    Color(0xFFFFEA00), // Brighter Yellow
    Color(0xFF1DE9B6), // Brighter Teal
    Color(0xFFFF1744), // Bright Red
  ];
}

// --- Helper class to manually define Cube geometry for flutter_cube v0.1.1 ---
class _CubeGeometry {
  final List<cube.Vector3> vertices = [
    cube.Vector3(-0.5, -0.5, -0.5), cube.Vector3(0.5, -0.5, -0.5),
    cube.Vector3(0.5, 0.5, -0.5), cube.Vector3(-0.5, 0.5, -0.5),
    cube.Vector3(-0.5, -0.5, 0.5), cube.Vector3(0.5, -0.5, 0.5),
    cube.Vector3(0.5, 0.5, 0.5), cube.Vector3(-0.5, 0.5, 0.5),
  ];

  final List<cube.Polygon> indices = [
    cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3), // front
    cube.Polygon(5, 4, 7), cube.Polygon(5, 7, 6), // back
    cube.Polygon(4, 0, 3), cube.Polygon(4, 3, 7), // left
    cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2), // right
    cube.Polygon(3, 2, 6), cube.Polygon(3, 6, 7), // top
    cube.Polygon(4, 5, 1), cube.Polygon(4, 1, 0), // bottom
  ];
}
// --- END OF FIX ---

//##############################################################################
//#
//#                      DATA MODELS & PUZZLE LOGIC
//#
//##############################################################################

// NEW: Updated data model. Note the 'color' property is retained for the rendering logic.
class BlockPosition3D {
  final int x, y, z;
  final bool isVisible;
  final Color color;

  BlockPosition3D({
    required this.x,
    required this.y,
    required this.z,
    required this.isVisible,
    required this.color,
  });
}

// NEW: Updated data model with grid dimensions.
class BlockStructure {
  final List<BlockPosition3D> blocks;
  final int gridWidth, gridDepth, maxHeight;

  BlockStructure({
    required this.blocks,
    required this.gridWidth,
    required this.gridDepth,
    required this.maxHeight,
  });
}

// dynamic puzzle generation logic.
class BlockCountingPuzzle {
  final BlockStructure blockStructure;
  final int correctAnswer;
  final List<int> answerChoices;
  final int difficulty;

  BlockCountingPuzzle({
    required this.blockStructure,
    required this.correctAnswer,
    required this.answerChoices,
    required this.difficulty
  });

  static BlockCountingPuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();
    
    // 1. Determine puzzle parameters based on player progress
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 3 + (difficulty ~/ 1.5);
    final totalBlocks = 8 + (difficulty * 5) + random.nextInt(difficulty * 2);
    const moveProbability = 0.65;
    
    // 2. Create a 2D grid to represent the height map of the structure
    List<List<int>> grid = List.generate(gridSize.toInt(), (_) => List.generate(gridSize.toInt(), (_) => 0));
    
    // 3. Perform a "random walk" to place stacks of blocks
    int currentX = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    int currentZ = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    grid[currentX][currentZ] = 1;

    for (int i = 1; i < totalBlocks; i++) {
      // Occasionally move to an adjacent tile
      if (random.nextDouble() < moveProbability) {
        final moves = [[-1, 0], [1, 0], [0, -1], [0, 1]]..shuffle();
        for (var move in moves) {
          int nextX = currentX + move[0];
          int nextZ = currentZ + move[1];
          // Check if the move is within the grid bounds
          if (nextX >= 0 && nextX < gridSize && nextZ >= 0 && nextZ < gridSize) {
            currentX = nextX;
            currentZ = nextZ;
            break;
          }
        }
      }
      // Add a block to the current stack
      grid[currentX][currentZ]++;
    }

    // 4. Convert the 2D height map into a 3D list of blocks
    List<BlockPosition3D> blocks = [];
    int maxHeight = 0;
    final puzzleColor = _VisualConfig.cubeColors[random.nextInt(_VisualConfig.cubeColors.length)];

    for (int x = 0; x < gridSize; x++) {
      for (int z = 0; z < gridSize; z++) {
        int height = grid[x][z];
        if (height > maxHeight) maxHeight = height;
        for (int y = 0; y < height; y++) {
          bool isVisible = _isBlockVisible(x, y, z, grid, height);
          blocks.add(BlockPosition3D(
            x: x, 
            y: y, 
            z: z, 
            isVisible: isVisible,
            color: puzzleColor, // Assign a consistent color for the puzzle
          ));
        }
      }
    }

    // 5. Generate answer choices
    final correctAnswer = blocks.length;
    final choices = {correctAnswer};
    final variance = math.max(2, (difficulty + 2));
    var guard = 0;
    while (choices.length < 4 && guard++ < 500) {
      int offset = random.nextInt(variance) + 1;
      choices.add(math.max(1, correctAnswer + (random.nextBool() ? 1 : -1) * offset));
    }

    return BlockCountingPuzzle(
      blockStructure: BlockStructure(
        blocks: blocks, 
        gridWidth: gridSize.toInt(), 
        gridDepth: gridSize.toInt(), 
        maxHeight: maxHeight
      ),
      correctAnswer: correctAnswer,
      answerChoices: choices.toList()..shuffle(),
      difficulty: difficulty,
    );
  }

  // Helper to determine if a block is externally visible
  static bool _isBlockVisible(int x, int y, int z, List<List<int>> grid, int stackHeight) {
    if (y == stackHeight - 1) return true; // Top block is always visible
    int gridSize = grid.length;
    if (x == 0 || grid[x - 1][z] <= y) return true;
    if (x == gridSize - 1 || grid[x + 1][z] <= y) return true;
    if (z == 0 || grid[x][z - 1] <= y) return true;
    if (z == gridSize - 1 || grid[x][z + 1] <= y) return true;
    return false;
  }
}

//##############################################################################
//#
//#                        FLUTTER WIDGET & STATE
//#
//##############################################################################

class BlockCounterGame extends StatefulWidget {
  final int grade;
  final int level;

  const BlockCounterGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<BlockCounterGame> createState() => _BlockCounterGameState();
}

class _BlockCounterGameState extends State<BlockCounterGame> with TickerProviderStateMixin, GameAnimationsMixin<BlockCounterGame> {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  BlockCountingPuzzle? currentPuzzle;
  int? userAnswer;
  List<int> answerChoices = [];
  
  bool _isGenerating = true;
  int _selectedAnswerIndex = -1;

  /// Wrong counts submitted before the right one.
  int _wrongAnswers = 0;
  cube.Object? _sceneObject;
  cube.Scene? _scene; 
  Key _cubeKey = UniqueKey();
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    initGameAnimations(useGlow: false, usePulse: false);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: _VisualConfig.rotationDurationSeconds),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    // Initialize difficulty from framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level);
        _generatePuzzle();
      }
    });
    
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    disposeGameAnimations(useGlow: false, usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) {
      if (kDebugMode) debugPrint("⚠️ [BLOCK_COUNTER] Difficulty not yet initialized, waiting...");
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _wrongAnswers = 0;
      _cubeKey = UniqueKey();
      _scene = null;
      userAnswer = null;
      _selectedAnswerIndex = -1;
      successController.reset();
    });

    try {
      final puzzle = await compute(
        BlockCountingPuzzle.generate,
        {'grade': widget.grade, 'level': widget.level},
      );
      
      if (mounted) {
        _createSceneObject(puzzle.blockStructure);
        
        setState(() {
          currentPuzzle = puzzle;
          answerChoices = List.from(currentPuzzle!.answerChoices);
          _isGenerating = false;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("❌ Error generating puzzle: $e\n$stackTrace");
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  void _createSceneObject(BlockStructure blockStructure) {
    final scene = cube.Object(name: 'world');
    final geometry = _CubeGeometry();

    // UPDATED: Use new grid properties for centering
    final centerX = blockStructure.gridWidth / 2.0;
    final centerY = blockStructure.maxHeight / 2.0; 
    final centerZ = blockStructure.gridDepth / 2.0;

    for (final blockData in blockStructure.blocks) {
      // Only render blocks that are visible
      if (!blockData.isVisible) continue;

      final cubeObject = cube.Object(
        position: cube.Vector3(
          (blockData.x - centerX + 0.5) * _VisualConfig.cubeSpacing,
          (blockData.z - centerZ + 0.5) * _VisualConfig.cubeSpacing, // model z -> scene y
          (blockData.y - centerY + 0.5) * _VisualConfig.cubeSpacing, // model y -> scene z
        ),
        scale: cube.Vector3(
          _VisualConfig.cubeSize, 
          _VisualConfig.cubeSize, 
          _VisualConfig.cubeSize
        ),
        lighting: true,
      );

      final material = cube.Material();
      final color = blockData.color; // Use the color assigned during generation
      
      material.diffuse.setFrom(cube.Vector3(
        color.r,
        color.g,
        color.b,
      ));
      
      // FIX: Add specular and shininess for better lighting effects
      material.specular.setFrom(_VisualConfig.materialSpecular);
      material.shininess = _VisualConfig.materialShininess;
      
      cubeObject.mesh = cube.Mesh(
        vertices: geometry.vertices,
        indices: geometry.indices,
        material: material,
      );
      
      scene.add(cubeObject);
    }
    _sceneObject = scene;
  }

  void _selectAnswer(int answerIndex) {
    if (userAnswer != null) return;
    
    setState(() {
      _selectedAnswerIndex = answerIndex;
      userAnswer = answerChoices[answerIndex];
    });
    _checkAnswer();
  }

  void _checkAnswer() {
    if (userAnswer == null) return;
    final isCorrect = userAnswer == currentPuzzle!.correctAnswer;
    if (isCorrect) {
      _handleSuccess();
    } else {
      _handleIncorrect();
    }
  }

  void _handleSuccess() {
    HapticFeedback.lightImpact();
    int baseScore = 150 * widget.grade;
    int difficultyBonus = (currentPuzzle?.difficulty ?? 1) * 50;
    int totalScore = baseScore + difficultyBonus;
    
    // SINGLE CALL to unified progression system
    // Block Counter is spatial3d, so no mathProblem needed
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'block_counter',
      difficulty: widget.level,
      score: totalScore,
      performance: Perf.fromMistakes(_wrongAnswers, per: 0.25),
    ));
    
    successController.forward(from: 0.0);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(totalScore),
    );
  }

  void _handleIncorrect() {
    _wrongAnswers++;
    // Track the incorrect attempt
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'block_counter',
      difficulty: widget.level,
    ));
    
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.blockCounterFail)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _selectedAnswerIndex = -1;
          userAnswer = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: SpaceTheme.starYellow),
                const SizedBox(height: 16),
                Text(S.of(context)!.loadingAdventure, style: SpaceTheme.bodyStyle),
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
                title: S.of(context)!.blockCounterGameTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 650;

                    // DYNAMIC CALCULATION:
                    // Calculate height based on the available space from the LayoutBuilder.
                    // This is more robust than using MediaQuery.
                    final availableHeight = constraints.maxHeight;

                    // For portrait (tall layout), use 45% of the available height.
                    // For landscape (wide layout), use a larger portion (e.g., 75%).
                    // We also clamp the value to ensure it's never too small or large.
                    // The wide (landscape) column also stacks a question label
                    // above this container, so reserve headroom — a 0.75 factor
                    // with a 300 floor overflowed the short landscape height by
                    // a few pixels.
                    final double containerHeight = isWide
                        ? (availableHeight * 0.68).clamp(240.0, 500.0)
                        : (availableHeight * 0.45).clamp(250.0, 400.0);

                    // Pass the calculated height to the layout methods.
                    return isWide
                        ? _buildWideLayout(containerHeight)
                        : _buildTallLayout(containerHeight);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(double containerHeight) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _buildVisualizationArea(containerHeight)), // Pass parameter
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildAnswerArea()),
        ],
      ),
    );
  }

  Widget _buildTallLayout(double containerHeight) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(), // Prevents overscroll glow
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Reduced top padding
        child: Column(
          children: [
            _buildVisualizationArea(containerHeight), // Pass parameter
            const SizedBox(height: 16),
            _buildAnswerArea(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizationArea(double containerHeight) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.of(context)!.blockCounterQuestion, style: SpaceTheme.titleStyle, textAlign: TextAlign.center),
        SizedBox(
          height: containerHeight, // Use the passed-in value
        
        // We wrap the container in Expanded with no the fixed height
        // to make it fill the available space instead of overflowing.
        // Expanded(
          child: Container(
            decoration: SpaceTheme.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(_VisualConfig.containerBorderRadius),
              boxShadow: [
                BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_VisualConfig.containerBorderRadius),
              child: Container(
                color: const Color(0xFF1A1A2E),
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    _sceneObject?.rotation.y = _rotationAnimation.value;
                    _scene?.update();
                    return child!;
                  },
                  child: cube.Cube(
                    key: _cubeKey,
                    onSceneCreated: (cube.Scene scene) {
                      _scene = scene;
                      if (_sceneObject != null) {
                        scene.world.add(_sceneObject!);
                      }
                      
                      final structure = currentPuzzle!.blockStructure;
                      final maxDimension = math.max(structure.gridWidth, 
                                            math.max(structure.gridDepth, structure.maxHeight)).toDouble();
                      final distance = maxDimension * _VisualConfig.cameraDistanceFactor + 3.0; 

                      scene.camera.position.setValues(distance, distance * 0.8, distance);
                      scene.camera.target.setFrom(_VisualConfig.cameraTarget);
                      
                      scene.light.position.setFrom(_VisualConfig.lightPosition);
                      
                      scene.light.setColor(
                        _VisualConfig.lightColor,
                        _VisualConfig.ambientIntensity,
                        _VisualConfig.diffuseIntensity,
                        _VisualConfig.specularIntensity,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          S.of(context)!.blockCounterSelectAnswer,
          style: SpaceTheme.titleStyle,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: SpaceTheme.cardDecoration,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: answerChoices.length,
            itemBuilder: (context, index) {
              final answer = answerChoices[index];
              final isSelected = _selectedAnswerIndex == index;
              final isCorrect = userAnswer != null &&
                               answer == currentPuzzle!.correctAnswer;
              final isWrong = userAnswer != null && isSelected && !isCorrect;

              return Semantics(
                button: true,
                label: S.of(context)!.a11yAnswer(answer.toString()),
                selected: isSelected,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: userAnswer == null ? () => _selectAnswer(index) : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                      backgroundColor: isCorrect
                          ? SpaceTheme.alienGreen
                          : isWrong
                              ? SpaceTheme.rocketRed
                              : isSelected
                                  ? SpaceTheme.spaceBlue
                                  : SpaceTheme.deepSpace,
                      foregroundColor: Colors.white,
                      elevation: isSelected ? 8 : 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? SpaceTheme.starYellow
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            answer.toString(),
                            style: SpaceTheme.headlineStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Non-color cue for correctness so color-blind
                        // players also see the feedback.
                        if (isCorrect)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(Icons.check, color: Colors.white, size: 20),
                          )
                        else if (isWrong)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // The redundant success/fail text block below the buttons was
        // removed entirely. The pop-up dialog handles this feedback.
      ],
    );
  }

  Widget _buildSuccessDialog(int totalScore) {
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A3E).withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.greenAccent, width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(width: 10),
                Text(
                  S.of(context)!.blockCounterWinTitle, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ]
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context)!.blockCounterWinDesc(currentPuzzle!.correctAnswer),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.blockCounterBonusPoints(totalScore),
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                autofocus: true,
                child: Text(
                  S.of(context)!.blockCounterNextPuzzle,
                  style: const TextStyle(color: Colors.cyanAccent)
                ),
                onPressed: () {
                  if (kDebugMode) debugPrint("🧊 Next puzzle button pressed");
                  Navigator.pop(context); // Close dialog
                  debugPrint("🧊 Dialog closed, generating new puzzle");
                  _generatePuzzle(); // Generate new puzzle directly
                },
              ),
              TextButton(
                child: Text(
                  S.of(context)!.blockCounterBackToMenu, 
                  style: const TextStyle(color: Colors.white)
                ),
                onPressed: () {
                  if (kDebugMode) debugPrint("🧊 Back to menu button pressed");
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to menu
                  debugPrint("🧊 Returned to main menu");
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
