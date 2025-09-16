// lib/features/games/screens/spatial_blocks_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:collection/collection.dart'; // For deep equality checks

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';

// =============================================================================
// VISUAL CONFIGURATION
// =============================================================================
class _VisualConfig {
  // --- Camera & Scene ---
  static const double cameraDistanceFactor = 2.2;
  static final cube.Vector3 cameraTarget = cube.Vector3(0, -0.5, 0);
  static const int rotationDurationSeconds = 20;

  // --- Lighting ---
  static final cube.Vector3 lightPosition = cube.Vector3(15, 20, 20);
  static const double ambientIntensity = 0.6;
  static const double diffuseIntensity = 1.0;

  // --- Material ---
  static final cube.Vector3 materialSpecular = cube.Vector3(0.8, 0.8, 0.8);
  static const double materialShininess = 100.0;

  // --- Cube Appearance ---
  static const double cubeSize = 0.95;
  static const double cubeSpacing = 1.0;
  static const List<Color> blockColors = [
    Color(0xFF00C8FF), // Cyan
    Color(0xFF64DD17), // Lime Green
    Color(0xFFFF9100), // Orange
    Color(0xFFD500F9), // Purple/Magenta
    Color(0xFFFFEA00), // Yellow
    Color(0xFFFF1744), // Red
  ];
}

// FIX: Helper class to manually define Cube geometry for flutter_cube v0.1.1
class _CubeGeometry {
  static final List<cube.Vector3> vertices = [
    cube.Vector3(-0.5, -0.5, -0.5), cube.Vector3(0.5, -0.5, -0.5),
    cube.Vector3(0.5, 0.5, -0.5), cube.Vector3(-0.5, 0.5, -0.5),
    cube.Vector3(-0.5, -0.5, 0.5), cube.Vector3(0.5, -0.5, 0.5),
    cube.Vector3(0.5, 0.5, 0.5), cube.Vector3(-0.5, 0.5, 0.5),
  ];

  static final List<cube.Polygon> indices = [
    cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3), // front
    cube.Polygon(5, 4, 7), cube.Polygon(5, 7, 6), // back
    cube.Polygon(4, 0, 3), cube.Polygon(4, 3, 7), // left
    cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2), // right
    cube.Polygon(3, 2, 6), cube.Polygon(3, 6, 7), // top
    cube.Polygon(4, 5, 1), cube.Polygon(4, 1, 0), // bottom
  ];
}

// =============================================================================
// DATA MODELS & PUZZLE LOGIC
// =============================================================================
@immutable
class Block {
  final int x, y, z;
  final Color color;

  const Block({required this.x, required this.y, required this.z, required this.color});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z &&
          color == other.color; // Also check color for structure equality

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode ^ color.hashCode;

  Block copyWith({int? x, int? y, int? z, Color? color}) {
    return Block(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      color: color ?? this.color,
    );
  }
}

class SpatialBlocksPuzzle {
  final Set<Block> targetStructure;
  final List<Color> piecePool;
  final int gridSize;
  final int difficulty;

  SpatialBlocksPuzzle({
    required this.targetStructure,
    required this.piecePool,
    required this.gridSize,
    required this.difficulty,
  });

  static SpatialBlocksPuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();

    final difficulty = math.min(5, (grade) + (level ~/ 5));
    final gridSize = 4 + (difficulty ~/ 2);
    final totalBlocks = 5 + (difficulty * 2) + random.nextInt(difficulty + 2);
    const moveProbability = 0.7;

    List<List<int>> heightMap = List.generate(gridSize, (_) => List.generate(gridSize, (_) => 0));
    Set<Block> structure = {};

    int currentX = random.nextInt(gridSize);
    int currentZ = random.nextInt(gridSize);

    for (int i = 0; i < totalBlocks; i++) {
      if (random.nextDouble() < moveProbability || heightMap[currentX][currentZ] == 0) {
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
      int currentY = heightMap[currentX][currentZ];
      
      final color = _VisualConfig.blockColors[random.nextInt(_VisualConfig.blockColors.length)];
      structure.add(Block(x: currentX, y: currentY, z: currentZ, color: color));
      heightMap[currentX][currentZ]++;
    }
    
    final normalizedStructure = _normalizeStructure(structure);
    final piecePool = normalizedStructure.map((block) => block.color).toList()..shuffle();

    return SpatialBlocksPuzzle(
      targetStructure: normalizedStructure,
      piecePool: piecePool,
      gridSize: gridSize,
      difficulty: difficulty,
    );
  }

  static Set<Block> _normalizeStructure(Set<Block> structure) {
    if (structure.isEmpty) return {};
    int minX = structure.first.x;
    int minY = structure.first.y;
    int minZ = structure.first.z;

    for (var block in structure) {
      minX = math.min(minX, block.x);
      minY = math.min(minY, block.y);
      minZ = math.min(minZ, block.z);
    }

    return structure.map((block) => block.copyWith(
      x: block.x - minX,
      y: block.y - minY,
      z: block.z - minZ,
    )).toSet();
  }
}

// =============================================================================
// FLUTTER WIDGET & STATE
// =============================================================================
class SpatialBlocksGame extends StatefulWidget {
  final int grade;
  final int level;

  const SpatialBlocksGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<SpatialBlocksGame> createState() => _SpatialBlocksGameState();
}

class _SpatialBlocksGameState extends State<SpatialBlocksGame> with TickerProviderStateMixin {
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _rotationController;

  SpatialBlocksPuzzle? currentPuzzle;
  List<Color> piecePool = [];
  // REFACTOR: Use a Set<Block> to store the full user structure for simpler logic
  Set<Block> userStructure = {}; 
  
  bool _isGenerating = true;
  cube.Object? _targetSceneObject;
  cube.Object? _userSceneObject;
  cube.Scene? _targetScene;
  cube.Scene? _userScene;
  Key _targetCubeKey = UniqueKey();
  Key _userCubeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
    _rotationController = AnimationController(
        duration: const Duration(seconds: _VisualConfig.rotationDurationSeconds), vsync: this)
      ..repeat();
    
    _generatePuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      _targetCubeKey = UniqueKey();
      _userCubeKey = UniqueKey();
      userStructure.clear(); // REFACTOR: Clear the set
    });

    final puzzle = await compute(
        SpatialBlocksPuzzle.generate, {'grade': widget.grade, 'level': widget.level});

    if (mounted) {
      setState(() {
        currentPuzzle = puzzle;
        piecePool = List.from(puzzle.piecePool);
        _targetSceneObject = _createSceneObject(puzzle.targetStructure);
        _userSceneObject = _createSceneObject({}); // Start with empty workspace
        _isGenerating = false;
      });
    }
  }

  cube.Object _createSceneObject(Set<Block> blocks) {
    final scene = cube.Object(name: 'world');
    if (blocks.isEmpty) return scene;

    final bounds = _getStructureBounds(blocks);
    final centerX = (bounds['maxX']! + bounds['minX']!) / 2.0;
    final centerY = (bounds['maxY']! + bounds['minY']!) / 2.0;
    final centerZ = (bounds['maxZ']! + bounds['minZ']!) / 2.0;

    for (final block in blocks) {
      final material = cube.Material()
        ..specular.setFrom(_VisualConfig.materialSpecular)
        ..shininess = _VisualConfig.materialShininess;
      material.diffuse.setValues(
          block.color.red / 255.0, block.color.green / 255.0, block.color.blue / 255.0);
      
      scene.add(cube.Object(
          position: cube.Vector3(
              (block.x - centerX) * _VisualConfig.cubeSpacing,
              (block.y - centerY) * _VisualConfig.cubeSpacing,
              (block.z - centerZ) * _VisualConfig.cubeSpacing),
          scale: cube.Vector3.all(_VisualConfig.cubeSize),
          lighting: true,
          backfaceCulling: false,
          // FIX: Use the standard Mesh constructor with manually defined geometry
          mesh: cube.Mesh(
            vertices: _CubeGeometry.vertices,
            indices: _CubeGeometry.indices,
            material: material
          )
      ));
    }
    return scene;
  }
  
  Map<String, double> _getStructureBounds(Set<Block> structure) {
    if (structure.isEmpty) return {'minX':0, 'maxX':0, 'minY':0, 'maxY':0, 'minZ':0, 'maxZ':0};
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    double minZ = double.infinity, maxZ = double.negativeInfinity;
    for (var b in structure) {
      minX = math.min(minX, b.x.toDouble()); maxX = math.max(maxX, b.x.toDouble());
      minY = math.min(minY, b.y.toDouble()); maxY = math.max(maxY, b.y.toDouble());
      minZ = math.min(minZ, b.z.toDouble()); maxZ = math.max(maxZ, b.z.toDouble());
    }
    return {'minX':minX, 'maxX':maxX, 'minY':minY, 'maxY':maxY, 'minZ':minZ, 'maxZ':maxZ};
  }

  void _handleDrop(Color color, int x, int z) {
    setState(() {
      // REFACTOR: Calculate height directly from the Set
      int y = userStructure.where((b) => b.x == x && b.z == z).length;
      
      final newBlock = Block(x: x, y: y, z: z, color: color);
      userStructure.add(newBlock);
      
      _userSceneObject = _createSceneObject(userStructure);
      
      // Remove the first occurrence of this color from the pool
      piecePool.remove(color);
    });
  }
  
  void _checkSolution() {
    final normalizedUserStructure = SpatialBlocksPuzzle._normalizeStructure(userStructure);
    if (const SetEquality().equals(normalizedUserStructure, currentPuzzle!.targetStructure)) {
      _handleSuccess();
    } else {
      _handleIncorrect();
    }
  }

  void _handleSuccess() {
    int score = 200 * widget.grade + (currentPuzzle?.difficulty ?? 1) * 75;
    context.read<GameProvider>().addScore(score);
    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(score),
    );
  }

  void _handleIncorrect() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(S.of(context)!.spatialBlocksFail),
      backgroundColor: SpaceTheme.rocketRed,
    ));
  }
  
  void _resetWorkspace() {
    setState(() {
      userStructure.clear(); // REFACTOR: Clear the set
      _userSceneObject = _createSceneObject({});
      piecePool = List.from(currentPuzzle!.piecePool);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: S.of(context)!.spatialBlocksGameTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return constraints.maxWidth > 750 ? _buildWideLayout() : _buildTallLayout();
                  },
                ),
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
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildTargetArea()),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildWorkspaceArea()),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 300, child: _buildTargetArea()),
            const SizedBox(height: 24),
            SizedBox(height: 450, child: _buildWorkspaceArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetArea() {
    return Column(
      children: [
        Text(S.of(context)!.spatialBlocksTarget, style: SpaceTheme.titleStyle),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: SpaceTheme.cardDecoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  _targetSceneObject?.rotation.y = _rotationController.value * 2 * math.pi;
                  _targetScene?.update();
                  return child!;
                },
                child: cube.Cube(
                  key: _targetCubeKey,
                  onSceneCreated: (scene) {
                    _targetScene = scene;
                    scene.world.add(_targetSceneObject!);
                    
                    final bounds = _getStructureBounds(currentPuzzle!.targetStructure);
                    final maxDim = [bounds['maxX']! - bounds['minX']!, bounds['maxY']! - bounds['minY']!, bounds['maxZ']! - bounds['minZ']!].reduce(math.max);
                    final distance = maxDim * _VisualConfig.cameraDistanceFactor + 3.0;

                    scene.camera.position.setValues(distance, distance * 0.7, distance);
                    scene.camera.target.setFrom(_VisualConfig.cameraTarget);
                    scene.light.position.setFrom(_VisualConfig.lightPosition);
                    scene.light.setColor(Colors.white, _VisualConfig.ambientIntensity, _VisualConfig.diffuseIntensity, 1.0);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWorkspaceArea() {
    final puzzle = currentPuzzle!;
    final gridSize = puzzle.gridSize;

    return Column(
      children: [
        Text(S.of(context)!.spatialBlocksWorkspace, style: SpaceTheme.titleStyle),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: SpaceTheme.cardDecoration,
            child: cube.Cube(
              key: _userCubeKey,
              interactive: true,
              onSceneCreated: (scene) {
                _userScene = scene;
                scene.world.add(_userSceneObject!);
                
                final distance = gridSize * _VisualConfig.cameraDistanceFactor;
                scene.camera.position.setValues(0, distance * 0.8, distance);
                scene.camera.target.setFrom(_VisualConfig.cameraTarget);
                scene.light.position.setFrom(_VisualConfig.lightPosition);
                scene.light.setColor(Colors.white, _VisualConfig.ambientIntensity, _VisualConfig.diffuseIntensity, 1.0);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          padding: const EdgeInsets.all(8),
          decoration: SpaceTheme.cardDecoration,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridSize,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: gridSize * gridSize,
            itemBuilder: (context, index) {
              final x = index % gridSize;
              final z = index ~/ gridSize;
              
              return DragTarget<Color>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty ? SpaceTheme.alienGreen.withOpacity(0.3) : SpaceTheme.deepSpace,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SpaceTheme.spaceBlue.withOpacity(0.5))
                    ),
                  );
                },
                onWillAccept: (color) => piecePool.isNotEmpty,
                onAccept: (color) => _handleDrop(color, x, z),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
        children: [
          Text(S.of(context)!.spatialBlocksPieces, style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: piecePool.mapIndexed((index, color) => Draggable<Color>(
              data: color,
              feedback: _buildPiece(color, isDragging: true),
              childWhenDragging: _buildPiece(color, isUsed: true),
              child: _buildPiece(color),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: Text(S.of(context)!.reset), // Assuming you have a generic "Reset" string
                 onPressed: _resetWorkspace,
                 style: SpaceTheme.secondaryButtonStyle,
               ),
               const SizedBox(width: 16),
               ElevatedButton(
                 onPressed: userStructure.isNotEmpty ? _checkSolution : null,
                 style: SpaceTheme.primaryButtonStyle,
                 child: Text(S.of(context)!.spatialBlocksCheck),
               ),
            ],
          ),
        ],
    );
  }

  Widget _buildPiece(Color color, {bool isDragging = false, bool isUsed = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isUsed ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUsed ? Colors.grey.withOpacity(0.5) : Colors.white70),
        boxShadow: isDragging ? [BoxShadow(color: color, blurRadius: 10, spreadRadius: 3)] : [],
      ),
    );
  }

  Widget _buildSuccessDialog(int bonusScore) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) => Transform.scale(
        scale: _successAnimation.value,
        child: AlertDialog(
          backgroundColor: SpaceTheme.deepSpace.withOpacity(0.9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: SpaceTheme.alienGreen, width: 2)),
          title: Text(S.of(context)!.spatialBlocksWinTitle, style: SpaceTheme.headlineStyle),
          content: Text(S.of(context)!.spatialBlocksWinDesc(bonusScore), style: SpaceTheme.bodyStyle),
          actions: [
            TextButton(
              child: Text(S.of(context)!.blockCounterNextPuzzle),
              onPressed: () {
                Navigator.pop(context);
                _generatePuzzle();
              },
            ),
          ],
        ),
      ),
    );
  }
}