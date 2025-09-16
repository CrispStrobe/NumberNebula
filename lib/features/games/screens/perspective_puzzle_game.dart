// lib/features/games/screens/perspective_puzzle_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:collection/collection.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';

// =============================================================================
// VISUAL CONFIG & HELPERS
// =============================================================================
class _VisualConfig {
  // Fixed isometric camera position
  static final cube.Vector3 baseCameraPosition = cube.Vector3(4, 4, 4);
  static final cube.Vector3 cameraTarget = cube.Vector3(0, 0, 0);
  static final cube.Vector3 lightPosition = cube.Vector3(10, 15, 10);

  static final List<Color> blockColors = [
    const Color(0xFF00C8FF), const Color(0xFF64DD17), const Color(0xFFFF9100),
    const Color(0xFFD500F9), const Color(0xFFFFEA00), const Color(0xFFFF1744),
  ];

  // === FIX 1: CORRECTED ORTHOGONAL ARROW DIRECTIONS ===
  // The arrows now point straight-on from the named perspective, matching the 2D view logic.
  // They are also positioned closer to the origin to be well within camera view.
  static final Map<String, Map<String, dynamic>> perspectiveData = {
    'Front': { // Arrow from +Z axis looking toward the origin
      'arrowStart': cube.Vector3(0, 0.5, 2.5),
      'arrowEnd': cube.Vector3(0, 0.5, -0.5),
      'color': const Color(0xFF00C8FF),
    },
    'Back': { // Arrow from -Z axis looking toward the origin
      'arrowStart': cube.Vector3(0, 0.5, -2.5),
      'arrowEnd': cube.Vector3(0, 0.5, 0.5),
      'color': const Color(0xFFFF1744),
    },
    'Left': { // Arrow from -X axis looking toward the origin
      'arrowStart': cube.Vector3(-2.5, 0.5, 0),
      'arrowEnd': cube.Vector3(0.5, 0.5, 0),
      'color': const Color(0xFF64DD17),
    },
    'Right': { // Arrow from +X axis looking toward the origin
      'arrowStart': cube.Vector3(2.5, 0.5, 0),
      'arrowEnd': cube.Vector3(-0.5, 0.5, 0),
      'color': const Color(0xFFFF9100),
    },
  };
}


// NEW: Robust 3D Arrow using a single mesh and the lookAt() method
// FINAL, CORRECTED VERSION: Uses the proper axis-angle vector for rotation
class _Arrow3D {
  /// Generates a single, unified mesh for an arrow pointing along the +Z axis.
  static cube.Mesh _generateArrowMesh(double length, double shaftRadius, double headRadius, double headLength) {
    final shaftLength = length - headLength;
    final vertices = <cube.Vector3>[];
    final indices = <cube.Polygon>[];

    // Shaft Vertices
    vertices.addAll([
      cube.Vector3(-shaftRadius, -shaftRadius, 0), cube.Vector3(shaftRadius, -shaftRadius, 0),
      cube.Vector3(shaftRadius, shaftRadius, 0), cube.Vector3(-shaftRadius, shaftRadius, 0),
      cube.Vector3(-shaftRadius, -shaftRadius, shaftLength), cube.Vector3(shaftRadius, -shaftRadius, shaftLength),
      cube.Vector3(shaftRadius, shaftRadius, shaftLength), cube.Vector3(-shaftRadius, shaftRadius, shaftLength),
    ]);

    // Shaft side faces
    indices.addAll([
      cube.Polygon(0, 4, 5), cube.Polygon(0, 5, 1), cube.Polygon(1, 5, 6),
      cube.Polygon(1, 6, 2), cube.Polygon(2, 6, 7), cube.Polygon(2, 7, 3),
      cube.Polygon(3, 7, 4), cube.Polygon(3, 4, 0),
    ]);

    // Head Vertices
    vertices.addAll([
      cube.Vector3(-headRadius, -headRadius, shaftLength), cube.Vector3(headRadius, -headRadius, shaftLength),
      cube.Vector3(headRadius, headRadius, shaftLength), cube.Vector3(-headRadius, headRadius, shaftLength),
      cube.Vector3(0, 0, length),
    ]);

    // Head pyramid faces
    indices.addAll([
      cube.Polygon(8, 9, 12), cube.Polygon(9, 10, 12),
      cube.Polygon(10, 11, 12), cube.Polygon(11, 8, 12),
      cube.Polygon(8, 11, 10), cube.Polygon(8, 10, 9),
    ]);

    return cube.Mesh(vertices: vertices, indices: indices);
  }

  /// Creates a fully oriented 3D arrow object.
  static cube.Object createArrow(cube.Vector3 start, cube.Vector3 end, Color color) {
    final material = cube.Material()
      ..diffuse.setValues(color.red / 255, color.green / 255, color.blue / 255);

    final length = (end - start).length;
    if (length < 0.1) return cube.Object();

    // 1. Generate a standard arrow mesh pointing along the +Z axis
    final arrowMesh = _generateArrowMesh(length, 0.15, 0.35, length * 0.4);
    final arrowObject = cube.Object(position: start, mesh: arrowMesh..material = material, name: 'arrow');

    // 2. Define source and target vectors for rotation
    final source = cube.Vector3(0, 0, 1);
    final target = (end - start)..normalize();
    
    // 3. Calculate the axis and angle of rotation
    final dot = cube.dot3(source, target);
    
    // Check if vectors are not already aligned
    if (dot < 0.9999) {
      cube.Vector3 axis;
      double angle;

      if (dot < -0.9999) {
        // The vectors are opposite. We can rotate 180 degrees around any perpendicular axis.
        // The Y axis is a stable choice.
        axis = cube.Vector3(0, 1, 0);
        angle = math.pi;
      } else {
        // Standard case: find the axis via cross product and angle via dot product.
        axis = cube.Vector3.zero();
        cube.cross3(axis, source, target);
        axis.normalize();
        angle = math.acos(dot);
      }
      
      // 4. THE FIX: Set the object's rotation to the axis scaled by the angle.
      arrowObject.rotation.setFrom(axis..scale(angle));
      arrowObject.updateTransform();
    }
    
    return arrowObject;
  }
}

class _CubeGeometry {
  static final List<cube.Vector3> vertices = [
    cube.Vector3(-0.5, -0.5, -0.5), cube.Vector3(0.5, -0.5, -0.5),
    cube.Vector3(0.5, 0.5, -0.5), cube.Vector3(-0.5, 0.5, -0.5),
    cube.Vector3(-0.5, -0.5, 0.5), cube.Vector3(0.5, -0.5, 0.5),
    cube.Vector3(0.5, 0.5, 0.5), cube.Vector3(-0.5, 0.5, 0.5),
  ];
  static final List<cube.Polygon> indices = [
    cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3), cube.Polygon(5, 4, 7),
    cube.Polygon(5, 7, 6), cube.Polygon(4, 0, 3), cube.Polygon(4, 3, 7),
    cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2), cube.Polygon(3, 2, 6),
    cube.Polygon(3, 6, 7), cube.Polygon(4, 5, 1), cube.Polygon(4, 1, 0),
  ];
}

// =============================================================================
// DATA MODELS & PUZZLE LOGIC
// =============================================================================
typedef Block = ({int x, int y, int z, Color color});
typedef PerspectiveView = List<List<Block?>>;

class PerspectivePuzzle {
  final Set<Block> structure;
  final int gridSize;
  final int maxHeight;
  final int difficulty;
  final Map<String, PerspectiveView> correctViews;

  PerspectivePuzzle({
    required this.structure,
    required this.gridSize,
    required this.maxHeight,
    required this.difficulty,
    required this.correctViews,
  });

  static PerspectivePuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 3 + (difficulty ~/ 3);
    final totalBlocks = 4 + (difficulty * 2) + random.nextInt(difficulty + 2);
    Set<Block> structure = {};
    var heightMap = List.generate(gridSize, (_) => List.generate(gridSize, (_) => 0));

    int currentX = gridSize ~/ 2;
    int currentZ = gridSize ~/ 2;

    for (int i = 0; i < totalBlocks; i++) {
      if (random.nextDouble() < 0.5 || heightMap[currentX][currentZ] >= 2) {
        final moves = [[-1, 0], [1, 0], [0, -1], [0, 1]]..shuffle();
        for (var move in moves) {
          int nextX = currentX + move[0], nextZ = currentZ + move[1];
          if (nextX >= 0 && nextX < gridSize && nextZ >= 0 && nextZ < gridSize) {
            currentX = nextX;
            currentZ = nextZ;
            break;
          }
        }
      }
      int currentY = heightMap[currentX][currentZ];
      final color = _VisualConfig.blockColors[random.nextInt(_VisualConfig.blockColors.length)];
      structure.add((x: currentX, y: currentY, z: currentZ, color: color));
      heightMap[currentX][currentZ] = currentY + 1;
    }

    int maxHeight = structure.isEmpty ? 0 : structure.map((b) => b.y).reduce(math.max);
    final correctViews = {
      'Front': _getFrontView(structure, gridSize, maxHeight),
      'Back': _getBackView(structure, gridSize, maxHeight),
      'Left': _getLeftView(structure, gridSize, maxHeight),
      'Right': _getRightView(structure, gridSize, maxHeight),
    };
    return PerspectivePuzzle(
      structure: structure,
      gridSize: gridSize,
      maxHeight: maxHeight,
      difficulty: difficulty,
      correctViews: correctViews,
    );
  }

  static PerspectiveView _createEmptyView(int width, int height) =>
      List.generate(height + 1, (_) => List.generate(width, (_) => null));

  // === FIX 2: ADDED VERBOSE LOGGING TO ALL PERSPECTIVE FUNCTIONS ===

  // View from the Front (+Z axis looking toward -Z)
  static PerspectiveView _getFrontView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) print('[PerspectivePuzzle] Calculating Front View...');
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        final block = s.where((b) => b.x == x && b.y == y).sortedBy<num>((b) => -b.z).firstOrNull; // Max Z is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = x;
          view[viewRow][viewCol] = block;
          if (kDebugMode) print('  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol].');
        }
      }
    }
    return view;
  }

  // View from the Back (-Z axis looking toward +Z), mirrored horizontally
  static PerspectiveView _getBackView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) print('[PerspectivePuzzle] Calculating Back View...');
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        final block = s.where((b) => b.x == x && b.y == y).sortedBy<num>((b) => b.z).firstOrNull; // Min Z is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = size - 1 - x; // Flipped horizontally
          view[viewRow][viewCol] = block;
          if (kDebugMode) print('  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol]. (Original x:${block.x} flipped to $viewCol)');
        }
      }
    }
    return view;
  }

  // View from the Left (-X axis looking toward +X)
  static PerspectiveView _getLeftView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) print('[PerspectivePuzzle] Calculating Left View...');
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        final block = s.where((b) => b.z == z && b.y == y).sortedBy<num>((b) => b.x).firstOrNull; // Min X is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = z; // Z-axis becomes the horizontal axis
          view[viewRow][viewCol] = block;
          if (kDebugMode) print('  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol].');
        }
      }
    }
    return view;
  }

  // View from the Right (+X axis looking toward -X), mirrored horizontally
  static PerspectiveView _getRightView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) print('[PerspectivePuzzle] Calculating Right View...');
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        final block = s.where((b) => b.z == z && b.y == y).sortedBy<num>((b) => -b.x).firstOrNull; // Max X is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = size - 1 - z; // Flipped horizontally
          view[viewRow][viewCol] = block;
          if (kDebugMode) print('  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol]. (Original z:${block.z} flipped to $viewCol)');
        }
      }
    }
    return view;
  }
}

// =============================================================================
// FLUTTER WIDGET & STATE (No changes needed below this line)
// =============================================================================
enum AnswerState { unanswered, correct, incorrect }

class PerspectivePuzzleGame extends StatefulWidget {
  final int grade;
  final int level;
  const PerspectivePuzzleGame({super.key, required this.grade, required this.level});
  @override
  State<PerspectivePuzzleGame> createState() => _PerspectivePuzzleGameState();
}

class _PerspectivePuzzleGameState extends State<PerspectivePuzzleGame> with TickerProviderStateMixin {
  late AnimationController _successController;
  PerspectivePuzzle? currentPuzzle;
  bool _isGenerating = true;
  List<String> _perspectivesToSolve = [];
  int _currentTurnIndex = 0;
  List<PerspectiveView> _answerChoices = [];
  int _correctAnswerIndex = -1;
  int _selectedAnswerIndex = -1;
  AnswerState _answerState = AnswerState.unanswered;
  final cube.Object _sceneObject = cube.Object(name: 'world');
  final cube.Object _arrowObject = cube.Object(name: 'arrowContainer');
  cube.Scene? _scene;
  
  // Camera rotation state - we'll control camera instead of scene
  double _cameraRotationY = 0.0;
  static const double _maxRotation = 0.26; // ~15 degrees
  double? _lastPanX;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _generatePuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    setState(() => _isGenerating = true);
    final puzzle = await compute(PerspectivePuzzle.generate, {'grade': widget.grade, 'level': widget.level});
    if (mounted) {
      setState(() {
        currentPuzzle = puzzle;
        _perspectivesToSolve = ['Front', 'Right', 'Back', 'Left']..shuffle();
        _currentTurnIndex = 0;
        _isGenerating = false;
        _cameraRotationY = 0.0; // Reset rotation
        _createSceneObject(puzzle.structure);
        _setupTurn();
      });
    }
  }

  void _setupTurn() {
    if (currentPuzzle == null) return;
    final currentPerspective = _perspectivesToSolve[_currentTurnIndex];
    final correctView = currentPuzzle!.correctViews[currentPerspective]!;
    final decoys = _generateDecoys(correctView, 3);
    setState(() {
      _answerChoices = [correctView, ...decoys]..shuffle();
      _correctAnswerIndex = _answerChoices.indexOf(correctView);
      _selectedAnswerIndex = -1;
      _answerState = AnswerState.unanswered;
    });
    _updateArrowForPerspective(currentPerspective);
  }
  
  void _updateArrowForPerspective(String perspective) {
    if (_scene == null) return;
    
    // Remove old arrow object if it exists
    _arrowObject.children.clear();
    // A bit safer to check before removing
    if (_scene!.world.children.contains(_arrowObject)) {
      _scene!.world.remove(_arrowObject);
    }

    // Create new arrow
    final perspectiveInfo = _VisualConfig.perspectiveData[perspective]!;
    final arrowColor = perspectiveInfo['color'] as Color;
    final start = perspectiveInfo['arrowStart'] as cube.Vector3;
    final end = perspectiveInfo['arrowEnd'] as cube.Vector3;
    
    final newArrow = _Arrow3D.createArrow(start, end, arrowColor);
    _arrowObject.add(newArrow);
    
    // Add arrow container back to scene
    _scene!.world.add(_arrowObject);
    _scene!.update();
  }
  
  void _updateCameraPosition() {
    if (_scene == null) return;
    
    // Use the base camera position and apply rotation
    final basePos = _VisualConfig.baseCameraPosition;
    
    // Simple Y-axis rotation matrix logic
    final cosY = math.cos(_cameraRotationY);
    final sinY = math.sin(_cameraRotationY);
    
    final newX = basePos.x * cosY - basePos.z * sinY;
    final newZ = basePos.x * sinY + basePos.z * cosY;

    _scene!.camera.position.setValues(newX, basePos.y, newZ);
    _scene!.camera.target.setFrom(_VisualConfig.cameraTarget);
    _scene!.update();
  }
  
  List<PerspectiveView> _generateDecoys(PerspectiveView correctView, int count) {
    final decoys = <PerspectiveView>{};
    final random = math.Random();
    while (decoys.length < count) {
        var newView = correctView.map((row) => List<Block?>.from(row)).toList();
        int modType = random.nextInt(3);
        if (modType == 0 && newView.isNotEmpty && newView[0].length > 1) {
            int col1 = random.nextInt(newView[0].length);
            int col2 = random.nextInt(newView[0].length);
            if(col1 == col2) continue;
            for(var row in newView) {
                var temp = row[col1]; row[col1] = row[col2]; row[col2] = temp;
            }
        } else if (modType == 1) {
            var blocks = newView.expand((row) => row).whereNotNull().toList();
            if (blocks.isNotEmpty) {
                var blockToRemove = blocks[random.nextInt(blocks.length)];
                for (var i = 0; i < newView.length; i++) {
                    for (var j = 0; j < newView[i].length; j++) {
                        if (newView[i][j] == blockToRemove) {
                            newView[i][j] = null;
                        }
                    }
                }
            }
        } else {
            var blocks = newView.expand((row) => row).whereNotNull().toList();
             if (blocks.isNotEmpty) {
                var blockToChange = blocks[random.nextInt(blocks.length)];
                var newColor = _VisualConfig.blockColors[random.nextInt(_VisualConfig.blockColors.length)];
                for (var i = 0; i < newView.length; i++) {
                    for (var j = 0; j < newView[i].length; j++) {
                        if (newView[i][j] == blockToChange) {
                            newView[i][j] = (x: blockToChange.x, y: blockToChange.y, z: blockToChange.z, color: newColor);
                        }
                    }
                }
            }
        }
        if (!const DeepCollectionEquality().equals(newView, correctView)) {
            decoys.add(newView);
        }
    }
    return decoys.toList();
  }

  void _selectAnswer(int index) {
    if (_answerState != AnswerState.unanswered) return;
    setState(() => _selectedAnswerIndex = index);
    if (index == _correctAnswerIndex) {
      setState(() => _answerState = AnswerState.correct);
      Future.delayed(const Duration(milliseconds: 1000), _nextTurn);
    } else {
      setState(() => _answerState = AnswerState.incorrect);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() {
          _selectedAnswerIndex = -1;
          _answerState = AnswerState.unanswered;
        });
      });
    }
  }
  
  void _nextTurn() {
    if (!mounted) return;
    if (_currentTurnIndex < _perspectivesToSolve.length - 1) {
      setState(() => _currentTurnIndex++);
      _setupTurn();
    } else {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    int score = 250 * widget.grade + (currentPuzzle?.difficulty ?? 1) * 100;
    context.read<GameProvider>().addScore(score);
    _successController.forward(from: 0.0);
    showDialog(context: context, barrierDismissible: false, builder: (_) => _buildSuccessDialog(score));
  }
  
  String _getTranslatedPerspective(BuildContext context, String perspective) {
    switch (perspective) {
        case 'Front': return S.of(context)!.perspectiveFront;
        case 'Back': return S.of(context)!.perspectiveBack;
        case 'Left': return S.of(context)!.perspectiveLeft;
        case 'Right': return S.of(context)!.perspectiveRight;
        default: return perspective.toUpperCase();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_lastPanX != null) {
      final deltaX = details.globalPosition.dx - _lastPanX!;
      final rotationDelta = deltaX * 0.005; // Sensitivity
      
      setState(() {
        _cameraRotationY -= rotationDelta; // Invert for more natural drag
        _cameraRotationY = _cameraRotationY.clamp(-_maxRotation, _maxRotation);
        _updateCameraPosition();
      });
    }
    _lastPanX = details.globalPosition.dx;
  }

  void _handlePanEnd(DragEndDetails details) {
    _lastPanX = null;
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
              GameUI(title: S.of(context)!.perspectivePuzzleGameTitle, level: widget.level, onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return constraints.maxWidth > 700 ? _buildWideLayout() : _buildTallLayout();
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
          // Left side - 3D View
          Expanded(
            flex: 5,
            child: _build3DView(),
          ),
          const SizedBox(width: 20),
          // Right side - Answer choices
          Expanded(
            flex: 6,
            child: _buildInteractionArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Top - 3D View
          Expanded(
            flex: 4,
            child: _build3DView(),
          ),
          const SizedBox(height: 16),
          // Bottom - Answer choices
          Expanded(
            flex: 5,
            child: _buildInteractionArea(),
          ),
        ],
      ),
    );
  }

  Widget _build3DView() {
    final currentPerspective = _perspectivesToSolve[_currentTurnIndex];
    final perspectiveInfo = _VisualConfig.perspectiveData[currentPerspective]!;
    
    return Container(
      decoration: SpaceTheme.cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 3D Scene with pan gesture for camera rotation
            GestureDetector(
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: cube.Cube(
                interactive: false,
                onSceneCreated: (s) {
                  _scene = s;
                  _scene!.world.add(_sceneObject);
                  
                  // Set up camera
                  _updateCameraPosition();
                  _scene!.light.position.setFrom(_VisualConfig.lightPosition);
                  
                  // Create arrow for initial perspective
                  _updateArrowForPerspective(currentPerspective);
                },
              ),
            ),
            // Direction indicator with arrow color
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: perspectiveInfo['color'], width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: perspectiveInfo['color'],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '➤ ${_getTranslatedPerspective(context, currentPerspective)} ➤',
                        style: SpaceTheme.bodyStyle.copyWith(
                          color: perspectiveInfo['color'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: perspectiveInfo['color'],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Rotation hint
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ziehen ±15°',
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionArea() {
    final perspective = _getTranslatedPerspective(context, _perspectivesToSolve[_currentTurnIndex]);
    
    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            S.of(context)!.perspectivePuzzleSelectView(perspective),
            style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
        // Answer choices grid - NO SCROLLING
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate size for 2x2 grid with proper spacing
              final spacing = 12.0;
              final availableWidth = constraints.maxWidth - spacing;
              final availableHeight = constraints.maxHeight - spacing;
              final cellWidth = availableWidth / 2;
              final cellHeight = availableHeight / 2;
              final cellSize = math.min(cellWidth, cellHeight);
              
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: List.generate(_answerChoices.length, (index) {
                  Border? border;
                  if (_selectedAnswerIndex == index) {
                      border = Border.all(
                          color: _answerState == AnswerState.correct ? SpaceTheme.alienGreen : 
                                 _answerState == AnswerState.incorrect ? SpaceTheme.rocketRed :
                                 SpaceTheme.starYellow,
                          width: 4);
                  }
                  
                  return GestureDetector(
                    onTap: () => _selectAnswer(index),
                    child: Container(
                      width: cellSize,
                      height: cellSize,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: SpaceTheme.deepSpace,
                        border: border ?? Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Center(
                        child: PerspectiveGridWidget(
                          view: _answerChoices[index],
                          maxSize: cellSize - 16,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  void _createSceneObject(Set<Block> blocks) {
    _sceneObject.children.clear();
    if (blocks.isEmpty || currentPuzzle == null) return;
    
    // Calculate center offset for better positioning
    final size = (currentPuzzle!.gridSize - 1) / 2.0;
    final height = (currentPuzzle!.maxHeight) / 2.0;
    
    for (final block in blocks) {
      final material = cube.Material();
      material.diffuse.setValues(block.color.red/255, block.color.green/255, block.color.blue/255);
      _sceneObject.add(cube.Object(
        position: cube.Vector3(block.x - size, block.y - height, block.z - size),
        mesh: cube.Mesh(
          vertices: _CubeGeometry.vertices, 
          indices: _CubeGeometry.indices,
          material: material
        )
      ));
    }
    _scene?.update();
  }
  
  Widget _buildSuccessDialog(int bonusScore) {
     return ScaleTransition(
      scale: CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
      child: AlertDialog(
        backgroundColor: SpaceTheme.deepSpace.withOpacity(0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: SpaceTheme.alienGreen, width: 2)),
        title: Text(S.of(context)!.perspectivePuzzleWinTitle, style: SpaceTheme.headlineStyle),
        content: Text(S.of(context)!.perspectivePuzzleWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,),
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
    );
  }
}

// Robust, responsive PerspectiveGridWidget
class PerspectiveGridWidget extends StatelessWidget {
  final PerspectiveView view;
  final double maxSize;
  
  const PerspectiveGridWidget({
    super.key, 
    required this.view, 
    required this.maxSize,
  });

  @override
  Widget build(BuildContext context) {
    if (view.isEmpty) return const SizedBox.shrink();
    
    final maxRowLength = view.map((row) => row.length).reduce(math.max);
    if (maxRowLength == 0) return const SizedBox.shrink();
    
    // Calculate cell size to fit within maxSize with some padding
    final cellSize = math.min(maxSize / maxRowLength, maxSize / view.length) * 0.85;
    final gridWidth = maxRowLength * cellSize;
    final gridHeight = view.length * cellSize;
    
    return SizedBox(
      width: gridWidth,
      height: gridHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: view.map((row) {
          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(maxRowLength, (col) {
                Block? block;
                if (col < row.length) {
                  block = row[col];
                }
                
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(0.5),
                    decoration: BoxDecoration(
                      color: block?.color ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      border: block == null 
                          ? Border.all(color: Colors.white12, width: 0.5)
                          : Border.all(color: Colors.white24, width: 0.5),
                    ),
                  ),
                );
              }),
            ),
          );
        }).toList(),
      ),
    );
  }
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);
}