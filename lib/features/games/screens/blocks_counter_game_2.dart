// lib/features/games/screens/blocks_counter_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;

// --- Your existing imports would go here ---
// Example placeholder imports:
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../../../shared/utils/app_utilities.dart'; // For SpaceDialog if needed

//##############################################################################
//#
//#                           VISUALS CONFIGURATION
//#
//##############################################################################
/// A centralized place to tweak all visual parameters for the 3D scene.
// In _GameVisualsConfig class

final class _GameVisualsConfig {
  // --- Camera Settings ---
  static const double cameraDistanceFactor = 1.7;
  static final cube.Vector3 cameraTarget = cube.Vector3(0, 0, 0);

  // --- Lighting Settings ---
  static final cube.Vector3 lightPosition = cube.Vector3(15, 20, 20);
  static const Color lightColor = Colors.white;
  // Now that lighting works, we can use normal intensity values.
  static const double diffuseIntensity = 1.0;
  static const double ambientIntensity = 0.3;
  static const double specularIntensity = 1.2;

  // --- Block Material & Appearance ---
  static final cube.Vector3 blockScale = cube.Vector3(0.95, 0.95, 0.95);
  static final cube.Vector3 blockSpecularColor = cube.Vector3(1.0, 1.0, 1.0);
  static const double blockShininess = 64.0;
  static const List<Color> blockColors = [
    Color(0xFF00A3FF), Color(0xFFF9A825), Color(0xFF29B6F6),
    Color(0xFFFF5252), Color(0xFF26A69A), Color(0xFFEC407A),
  ];
}


// --- This helper is still needed for some versions of flutter_cube ---
class _CubeGeometry {
  final List<cube.Vector3> vertices = [
    cube.Vector3(-0.5, -0.5, -0.5), cube.Vector3(0.5, -0.5, -0.5),
    cube.Vector3(0.5, 0.5, -0.5),  cube.Vector3(-0.5, 0.5, -0.5),
    cube.Vector3(-0.5, -0.5, 0.5), cube.Vector3(0.5, -0.5, 0.5),
    cube.Vector3(0.5, 0.5, 0.5),  cube.Vector3(-0.5, 0.5, 0.5),
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

// --- DATA MODELS AND PUZZLE GENERATION LOGIC ---
// This section is unchanged from the previous version, as the generation logic is solid.

class BlockPosition3D {
  final int x, y, z;
  final bool isVisible;
  BlockPosition3D({ required this.x, required this.y, required this.z, required this.isVisible });
}

class BlockStructure {
  final List<BlockPosition3D> blocks;
  final int gridWidth, gridDepth, maxHeight;
  BlockStructure({ required this.blocks, required this.gridWidth, required this.gridDepth, required this.maxHeight });
}

class BlockCountingPuzzle {
  final BlockStructure blockStructure;
  final int correctAnswer;
  final List<int> answerChoices;
  final int difficulty;
  BlockCountingPuzzle({required this.blockStructure, required this.correctAnswer, required this.answerChoices, required this.difficulty});

  static BlockCountingPuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 2 + (difficulty ~/ 1.5);
    final totalBlocks = 8 + (difficulty * 5);
    const moveProbability = 0.65;
    List<List<int>> grid = List.generate(gridSize, (_) => List.generate(gridSize, (_) => 0));
    int currentX = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    int currentZ = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    grid[currentX][currentZ] = 1;

    for (int i = 1; i < totalBlocks; i++) {
      if (random.nextDouble() < moveProbability) {
        final moves = [[-1, 0], [1, 0], [0, -1], [0, 1]]..shuffle();
        for (var move in moves) {
          int nextX = currentX + move[0];
          int nextZ = currentZ + move[1];
          if (nextX >= 0 && nextX < gridSize && nextZ >= 0 && nextZ < gridSize) {
            currentX = nextX;
            currentZ = nextZ;
            break;
          }
        }
      }
      grid[currentX][currentZ]++;
    }

    List<BlockPosition3D> blocks = [];
    int maxHeight = 0;
    for (int x = 0; x < gridSize; x++) {
      for (int z = 0; z < gridSize; z++) {
        int height = grid[x][z];
        if (height > maxHeight) maxHeight = height;
        for (int y = 0; y < height; y++) {
          bool isVisible = _isBlockVisible(x, y, z, grid, height);
          blocks.add(BlockPosition3D(x: x, y: y, z: z, isVisible: isVisible));
        }
      }
    }

    final correctAnswer = blocks.length;
    final choices = {correctAnswer};
    while (choices.length < 4) {
      int variance = random.nextInt(difficulty + 2) + 1;
      choices.add(math.max(1, correctAnswer + (random.nextBool() ? 1 : -1) * variance));
    }

    return BlockCountingPuzzle(
      blockStructure: BlockStructure(blocks: blocks, gridWidth: gridSize, gridDepth: gridSize, maxHeight: maxHeight),
      correctAnswer: correctAnswer,
      answerChoices: choices.toList()..shuffle(),
      difficulty: difficulty,
    );
  }

  static bool _isBlockVisible(int x, int y, int z, List<List<int>> grid, int stackHeight) {
    if (y == stackHeight - 1) return true;
    int gridSize = grid.length;
    if (x == 0 || grid[x - 1][z] <= y) return true;
    if (x == gridSize - 1 || grid[x + 1][z] <= y) return true;
    if (z == 0 || grid[x][z - 1] <= y) return true;
    if (z == gridSize - 1 || grid[x][z + 1] <= y) return true;
    return false;
  }
}

// --- FLUTTER WIDGET AND STATE ---

class BlockCounterGame extends StatefulWidget {
  final int grade;
  final int level;
  const BlockCounterGame({super.key, required this.grade, required this.level});
  @override
  State<BlockCounterGame> createState() => _BlockCounterGameState();
}

class _BlockCounterGameState extends State<BlockCounterGame> with TickerProviderStateMixin {
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  BlockCountingPuzzle? currentPuzzle;
  int? userAnswer;
  List<int> answerChoices = [];
  bool _isGenerating = true;
  int _selectedAnswerIndex = -1;
  bool _showingHint = false;
  late cube.Object _sceneObject;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    _generatePuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    setState(() => _isGenerating = true);
    final puzzle = await compute(BlockCountingPuzzle.generate, {'grade': widget.grade, 'level': widget.level});
    if (mounted) {
      setState(() {
        currentPuzzle = puzzle;
        answerChoices = List.from(currentPuzzle!.answerChoices);
        _createSceneObject();
        _isGenerating = false;
        _selectedAnswerIndex = -1;
        userAnswer = null;
        _showingHint = false;
      });
    }
  }

  void _createSceneObject() {
    if (currentPuzzle == null) return;
    final scene = cube.Object(name: 'world');
    final blockStructure = currentPuzzle!.blockStructure;
    final geometry = _CubeGeometry();
    final random = math.Random();

    for (final blockData in blockStructure.blocks) {
      if (!blockData.isVisible && !_showingHint) continue;

      final cubeObject = cube.Object(
        position: cube.Vector3(
          blockData.x.toDouble() - blockStructure.gridWidth / 2.0 + 0.5,
          blockData.y.toDouble() - blockStructure.maxHeight / 2.0 + 0.5,
          blockData.z.toDouble() - blockStructure.gridDepth / 2.0 + 0.5,
        ),
        // Using values from the config class
        scale: _GameVisualsConfig.blockScale,
        lighting: true,
      );

      final material = cube.Material();
      final color = !blockData.isVisible && _showingHint
          ? SpaceTheme.starYellow
          // Using colors from the config class
          : _GameVisualsConfig.blockColors[random.nextInt(_GameVisualsConfig.blockColors.length)];
      
      material.diffuse.setFrom(cube.Vector3(color.red / 255, color.green / 255, color.blue / 255));
      
      // Using material properties from the config class
      material.specular.setFrom(_GameVisualsConfig.blockSpecularColor);
      material.shininess = _GameVisualsConfig.blockShininess;

      cubeObject.mesh = cube.Mesh(vertices: geometry.vertices, indices: geometry.indices, material: material);
      scene.add(cubeObject);
    }

    _sceneObject = scene;
  }

  void _selectAnswer(int answerIndex) {
    setState(() { _selectedAnswerIndex = answerIndex; userAnswer = answerChoices[answerIndex]; });
    _checkAnswer();
  }

  void _checkAnswer() {
    if (userAnswer == null) return;
    final isCorrect = userAnswer == currentPuzzle!.correctAnswer;
    isCorrect ? _handleSuccess() : _handleIncorrect();
  }

  // In _BlockCounterGameState class
  void _handleSuccess() {
    // This method no longer needs to handle the dialog result.
    // It just shows the dialog and the dialog's buttons handle the actions.
    int baseScore = 150 * widget.grade;
    context.read<GameProvider>().addScore(baseScore);
    _successController.forward(from: 0.0);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildSuccessDialog(baseScore),
    );
    }
  
  void _resetGame() {
  if (!mounted) return;
  
  Navigator.of(context).pop(); // Close the dialog first.

  // Schedule the new puzzle generation for the very next frame.
  // This robustly prevents state conflicts after navigation.
  Future.delayed(Duration.zero, () {
    if (mounted) {
      _generatePuzzle();
    }
  });
}

  void _handleIncorrect() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context)!.blockCounterFail), backgroundColor: SpaceTheme.rocketRed, duration: const Duration(seconds: 2)));
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) { setState(() { _selectedAnswerIndex = -1; userAnswer = null; }); } });
  }

  void _toggleHint() {
    setState(() { _showingHint = !_showingHint; _createSceneObject(); });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(S.of(context)!.loadingAdventure, style: SpaceTheme.bodyStyle)])));
    }
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(title: S.of(context)!.blockCounterGameTitle, level: widget.level, onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth > 650 ? _buildWideLayout() : _buildTallLayout()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(flex: 3, child: _buildVisualizationArea()),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildAnswerArea()),
      ]),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(children: [
          _buildVisualizationArea(),
          const SizedBox(height: 24),
          _buildAnswerArea(),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildVisualizationArea() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Text(S.of(context)!.blockCounterQuestion, style: SpaceTheme.titleStyle.copyWith(fontSize: 20), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
            height: 350,
            decoration: SpaceTheme.cardDecoration,
            child: cube.Cube(onSceneCreated: (cube.Scene scene) {
            scene.world.add(_sceneObject);

            // --- DYNAMIC CAMERA & PERSPECTIVE FIX ---
            final structure = currentPuzzle!.blockStructure;
            final maxSize = math.max(structure.gridWidth, math.max(structure.gridDepth, structure.maxHeight)).toDouble();
            
            // 1. Calculate a consistent isometric camera position based on the object's size.
            // This ensures a good viewing angle and proper distance for any size puzzle.
            final distance = maxSize * _GameVisualsConfig.cameraDistanceFactor;
            scene.camera.position.setValues(distance, distance * 0.8, distance);
            
            // 2. We no longer use camera.zoom, as positioning is more reliable.
            scene.camera.target.setFrom(_GameVisualsConfig.cameraTarget);

            // Use the much brighter light settings from the config
            scene.light.position.setFrom(_GameVisualsConfig.lightPosition);
            scene.light.setColor(
                _GameVisualsConfig.lightColor,
                _GameVisualsConfig.diffuseIntensity,
                _GameVisualsConfig.ambientIntensity,
                _GameVisualsConfig.specularIntensity,
            );
            }),
        ),
        // --- HINT BUTTON AND TEXT REMOVED ---
        // The ElevatedButton and Text widgets that were here have been deleted.
        ],
    );
    }

  Widget _buildAnswerArea() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(S.of(context)!.blockCounterSelectAnswer, style: SpaceTheme.titleStyle.copyWith(fontSize: 18)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: SpaceTheme.cardDecoration,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5),
          itemCount: answerChoices.length,
          itemBuilder: (context, index) {
            final answer = answerChoices[index];
            final isSelected = _selectedAnswerIndex == index;
            final isCorrect = userAnswer != null && answer == currentPuzzle!.correctAnswer;
            final isWrong = userAnswer != null && isSelected && !isCorrect;
            return ElevatedButton(
              onPressed: userAnswer == null ? () => _selectAnswer(index) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCorrect ? SpaceTheme.alienGreen : (isWrong ? SpaceTheme.rocketRed : SpaceTheme.deepSpace),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(answer.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 24)),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildSuccessDialog(int bonusScore) {
    return AnimatedBuilder(
        animation: _successAnimation,
        builder: (context, child) {
        return Transform.scale(
            scale: _successAnimation.value,
            child: AlertDialog(
            title: Text(S.of(context)!.blockCounterWinTitle),
            content: Text("${S.of(context)!.blockCounterWinDesc(currentPuzzle!.correctAnswer)}\n${S.of(context)!.blockCounterBonusPoints(bonusScore)}"),
            actions: [
                // THIS IS THE FIX: This button now calls _resetGame.
                ElevatedButton(
                onPressed: _resetGame,
                child: Text(S.of(context)!.nextLevel)
                ),
                // The "Back to Menu" button logic is fine.
                ElevatedButton(
                onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Close game screen
                },
                child: Text(S.of(context)!.backToMenu)
                ),
            ],
            ),
        );
        },
    );
    }


}