// lib/features/games/screens/blocks_counter_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:model_viewer_plus/model_viewer_plus.dart';

// Your other imports
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../../../shared/utils/app_utilities.dart';

// --- DATA MODELS AND PUZZLE GENERATION LOGIC ---
// This part is the same as before.
class BlockPosition3D {
  final int x, y, z;
  BlockPosition3D({ required this.x, required this.y, required this.z });
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
          blocks.add(BlockPosition3D(x: x, y: y, z: z));
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
}

// --- FLUTTER WIDGET AND STATE (COMPLETELY REWORKED) ---

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
  String? _gltfJson; // Will hold the 3D model data

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
    // NEW: Generate the 3D model file content from the puzzle data
    final jsonModel = await compute(_generateGltfJson, puzzle.blockStructure);
    if (mounted) {
      setState(() {
        currentPuzzle = puzzle;
        _gltfJson = jsonModel;
        answerChoices = List.from(currentPuzzle!.answerChoices);
        _isGenerating = false;
        _selectedAnswerIndex = -1;
        userAnswer = null;
      });
    }
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

  void _handleSuccess() {
    int baseScore = 150 * widget.grade;
    context.read<GameProvider>().addScore(baseScore);
    _successController.forward(from: 0.0);
    showDialog(context: context, barrierDismissible: false, builder: (context) => _buildSuccessDialog(baseScore));
  }
  
  // THIS IS THE CORRECTED DIALOG LOGIC FROM PathFinderGame
  void _resetGame() {
    if (!mounted) return;
    Navigator.of(context).pop(); // Close the dialog
    _generatePuzzle();
  }

  void _handleIncorrect() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context)!.blockCounterFail), backgroundColor: SpaceTheme.rocketRed, duration: const Duration(seconds: 2)));
    Future.delayed(const Duration(milliseconds: 500), () { if (mounted) { setState(() { _selectedAnswerIndex = -1; userAnswer = null; }); } });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null || _gltfJson == null) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(S.of(context)!.loadingAdventure, style: SpaceTheme.bodyStyle)])));
    }
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(title: S.of(context)!.blockCounterGameTitle, level: widget.level, onBack: () => Navigator.of(context).pop()),
              Expanded(child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth > 650 ? _buildWideLayout() : _buildTallLayout())),
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
    final structure = currentPuzzle!.blockStructure;
    final maxSize = math.max(structure.gridWidth, math.max(structure.gridDepth, structure.maxHeight)).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.of(context)!.blockCounterQuestion, style: SpaceTheme.titleStyle.copyWith(fontSize: 20), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          height: 350,
          decoration: SpaceTheme.cardDecoration,
          child: ModelViewer(
            // The src is a data URI containing our generated 3D model
            src: 'data:application/json;base64,${base64Encode(utf8.encode(_gltfJson!))}',
            backgroundColor: Colors.transparent,
            cameraControls: true, // User can rotate, pan, and zoom!
            disableZoom: false,
            autoRotate: false,
            // Set initial camera view
            cameraOrbit: '30deg 75deg ${maxSize * 2.5}m',
            cameraTarget: '0m 0m 0m',
            // Use a built-in neutral environment for nice lighting and reflections
            environmentImage: 'neutral',
            shadowIntensity: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerArea() {
    // ... This method is unchanged
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
    // This now correctly uses the _resetGame method
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: AlertDialog(
            title: Text(S.of(context)!.blockCounterWinTitle),
            content: Text("${S.of(context)!.blockCounterWinDesc(currentPuzzle!.correctAnswer)}\n${S.of(context)!.blockCounterBonusPoints(bonusScore)}"),
            actions: [
              ElevatedButton(onPressed: _resetGame, child: Text(S.of(context)!.nextLevel)),
              ElevatedButton(
                onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
                child: Text(S.of(context)!.backToMenu)
              ),
            ],
          ),
        );
      },
    );
  }
}

// NEW: Helper function to generate a glTF 2.0 JSON model on the fly.
// This is a complex but powerful way to solve the rendering problem.
String _generateGltfJson(BlockStructure structure) {
  final List<double> positions = [];
  final List<double> normals = [];
  final List<int> indices = [];
  final random = math.Random();
  final colors = [ [0.0, 0.639, 1.0], [0.976, 0.658, 0.145], [0.16, 0.713, 0.964], [1.0, 0.321, 0.321], [0.149, 0.65, 0.6], [0.925, 0.25, 0.474] ];

  int vertexOffset = 0;

  for (final block in structure.blocks) {
    final color = colors[random.nextInt(colors.length)];
    // Cube vertices (8 corners)
    final v = [
      [-0.5, -0.5, 0.5], [0.5, -0.5, 0.5], [0.5, 0.5, 0.5], [-0.5, 0.5, 0.5],
      [-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, 0.5, -0.5], [-0.5, 0.5, -0.5],
    ];
    // Per-face data: vertex indices and normal vector
    final faces = [
      // front, back, top, bottom, right, left
      {'v': [0, 1, 2, 3], 'n': [0, 0, 1]}, {'v': [5, 4, 7, 6], 'n': [0, 0, -1]},
      {'v': [3, 2, 6, 7], 'n': [0, 1, 0]}, {'v': [1, 0, 4, 5], 'n': [0, -1, 0]},
      {'v': [1, 5, 6, 2], 'n': [1, 0, 0]}, {'v': [4, 0, 3, 7], 'n': [-1, 0, 0]},
    ];
    
    // Center the whole structure
    final offsetX = block.x - structure.gridWidth / 2.0 + 0.5;
    final offsetY = block.y - structure.maxHeight / 2.0 + 0.5;
    final offsetZ = block.z - structure.gridDepth / 2.0 + 0.5;

    for (final face in faces) {
      final vIndices = face['v'] as List<int>;
      final n = face['n'] as List<double>;
      for (final vIndex in vIndices) {
        positions.addAll([v[vIndex][0] + offsetX, v[vIndex][1] + offsetY, v[vIndex][2] + offsetZ]);
        normals.addAll(n);
      }
      indices.addAll([ vertexOffset, vertexOffset + 1, vertexOffset + 2, vertexOffset, vertexOffset + 2, vertexOffset + 3, ]);
      vertexOffset += 4;
    }
  }

  // Convert vertex/normal data to a Base64 encoded buffer
  final buffer = Float32List.fromList([...positions, ...normals]).buffer.asUint8List();
  final indicesBuffer = Uint16List.fromList(indices).buffer.asUint8List();
  final base64Buffer = base64Encode(buffer);
  final base64Indices = base64Encode(indicesBuffer);

  // Build the glTF 2.0 JSON structure
  return jsonEncode({
    "asset": {"version": "2.0"}, "scenes": [{"nodes": [0]}],
    "nodes": [{"mesh": 0}],
    "meshes": [{
      "primitives": [{
        "attributes": {"POSITION": 1, "NORMAL": 2}, "indices": 0,
        "material": 0
      }]
    }],
    "materials": [{
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.8, 0.8, 0.8, 1.0], // Tinted white
        "metallicFactor": 0.2, "roughnessFactor": 0.3
      }
    }],
    "buffers": [
      {"uri": "data:application/octet-stream;base64,$base64Indices", "byteLength": indicesBuffer.lengthInBytes},
      {"uri": "data:application/octet-stream;base64,$base64Buffer", "byteLength": buffer.lengthInBytes}
    ],
    "bufferViews": [
      {"buffer": 0, "byteOffset": 0, "byteLength": indicesBuffer.lengthInBytes, "target": 34963}, // ELEMENT_ARRAY_BUFFER
      {"buffer": 1, "byteOffset": 0, "byteLength": positions.length * 4, "target": 34962}, // ARRAY_BUFFER
      {"buffer": 1, "byteOffset": positions.length * 4, "byteLength": normals.length * 4, "target": 34962} // ARRAY_BUFFER
    ],
    "accessors": [
      {"bufferView": 0, "byteOffset": 0, "componentType": 5123, "count": indices.length, "type": "SCALAR"}, // UNSIGNED_SHORT
      {"bufferView": 1, "byteOffset": 0, "componentType": 5126, "count": positions.length ~/ 3, "type": "VEC3", "min": [-0.5, -0.5, -0.5], "max": [0.5, 0.5, 0.5]}, // FLOAT
      {"bufferView": 2, "byteOffset": 0, "componentType": 5126, "count": normals.length ~/ 3, "type": "VEC3"} // FLOAT
    ]
  });
}