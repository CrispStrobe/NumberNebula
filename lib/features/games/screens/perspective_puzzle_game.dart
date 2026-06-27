// lib/features/games/screens/perspective_puzzle_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;
import 'package:collection/collection.dart';

import '../models/game_outcome.dart';
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
  
  static final Map<String, Map<String, dynamic>> perspectiveData = {
  // Arrow for the front - FIXED DIRECTION (should point AWAY from cube)
  'Front': {
    'arrowStart': cube.Vector3(0, 0.5, 5.0),
    'arrowEnd': cube.Vector3(0, 0.5, 2.0),
    'color': const Color(0xFF00C8FF),
  },
  // Arrow for the back (points TOWARDS cube)
  'Back': {
    'arrowStart': cube.Vector3(0, 0.5, -5.0),
    'arrowEnd': cube.Vector3(0, 0.5, -2.0),
    'color': const Color(0xFFFF1744),
  },
  // Arrow for the left - MOVED FURTHER OUT
  'Left': {
    'arrowStart': cube.Vector3(-5.0, 0.5, 0),
    'arrowEnd': cube.Vector3(-2.0, 0.5, 0),
    'color': const Color(0xFF64DD17),
  },
  // Arrow for the right - MOVED FURTHER OUT
  'Right': {
    'arrowStart': cube.Vector3(5.0, 0.5, 0),
    'arrowEnd': cube.Vector3(2.0, 0.5, 0),
    'color': const Color(0xFFFF9100),
  },
};
}

// Robust 3D Arrow using a single mesh
// Ultra-simple 3D Arrow - create specific geometry for each direction
class _Arrow3D {
  /// Creates a fully oriented 3D arrow object using predefined geometries
  static cube.Object createArrow(cube.Vector3 start, cube.Vector3 end, Color color) {
    final material = cube.Material()
      ..diffuse.setValues(color.r, color.g, color.b);

    final direction = end - start;
    
    // Determine which direction this arrow should point
    cube.Mesh arrowMesh;
    cube.Vector3 position;
    
    if (direction.z.abs() > direction.x.abs()) {
      // Z-direction arrow (Front/Back)
      if (direction.z > 0) {
        // Direction is positive Z (Back - towards cube)
        arrowMesh = _createZPositiveArrow();
        position = start;
      } else {
        // Direction is negative Z (Front - away from cube)
        arrowMesh = _createZNegativeArrow();
        position = start;
      }
    } else {
      // X-direction arrow (Left/Right)  
      if (direction.x > 0) {
        // Direction is positive X (Right - away from cube)
        arrowMesh = _createXPositiveArrow();
        position = start;
      } else {
        // Direction is negative X (Left - away from cube)
        arrowMesh = _createXNegativeArrow();
        position = start;
      }
    }
    
    return cube.Object(
      position: position,
      mesh: arrowMesh..material = material, 
      name: 'arrow'
    );
  }

  // Arrow pointing towards +Z (Back - towards cube)
  static cube.Mesh _createZPositiveArrow() {
    final vertices = <cube.Vector3>[
      // Shaft base at start
      cube.Vector3(-0.15, 0.35, 0), cube.Vector3(0.15, 0.35, 0),
      cube.Vector3(0.15, 0.65, 0), cube.Vector3(-0.15, 0.65, 0),
      
      // Shaft end (where head begins) - EXACT same Z as head base
      cube.Vector3(-0.15, 0.35, 2.0), cube.Vector3(0.15, 0.35, 2.0),
      cube.Vector3(0.15, 0.65, 2.0), cube.Vector3(-0.15, 0.65, 2.0),
      
      // Head base (EXACT same Z as shaft end for perfect connection)
      cube.Vector3(-0.35, 0.15, 2.0), cube.Vector3(0.35, 0.15, 2.0),
      cube.Vector3(0.35, 0.85, 2.0), cube.Vector3(-0.35, 0.85, 2.0),
      
      // Head tip
      cube.Vector3(0, 0.5, 3.0),
    ];
    
    final indices = <cube.Polygon>[
      // Shaft faces
      cube.Polygon(0, 1, 5), cube.Polygon(0, 5, 4),
      cube.Polygon(1, 2, 6), cube.Polygon(1, 6, 5),
      cube.Polygon(2, 3, 7), cube.Polygon(2, 7, 6),
      cube.Polygon(3, 0, 4), cube.Polygon(3, 4, 7),
      
      // Head pyramid faces
      cube.Polygon(8, 12, 9), cube.Polygon(9, 12, 10),
      cube.Polygon(10, 12, 11), cube.Polygon(11, 12, 8),
    ];
    
    return cube.Mesh(vertices: vertices, indices: indices);
  }

  // Arrow pointing towards -Z (Front - away from cube)
  static cube.Mesh _createZNegativeArrow() {
    final vertices = <cube.Vector3>[
      // Shaft base at start
      cube.Vector3(-0.15, 0.35, 0), cube.Vector3(0.15, 0.35, 0),
      cube.Vector3(0.15, 0.65, 0), cube.Vector3(-0.15, 0.65, 0),
      
      // Shaft end (where head begins) - EXACT same Z as head base
      cube.Vector3(-0.15, 0.35, -2.0), cube.Vector3(0.15, 0.35, -2.0),
      cube.Vector3(0.15, 0.65, -2.0), cube.Vector3(-0.15, 0.65, -2.0),
      
      // Head base (EXACT same Z as shaft end for perfect connection)
      cube.Vector3(-0.35, 0.15, -2.0), cube.Vector3(0.35, 0.15, -2.0),
      cube.Vector3(0.35, 0.85, -2.0), cube.Vector3(-0.35, 0.85, -2.0),
      
      // Head tip
      cube.Vector3(0, 0.5, -3.0),
    ];
    
    final indices = <cube.Polygon>[
      // Shaft faces
      cube.Polygon(0, 4, 5), cube.Polygon(0, 5, 1),
      cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2),
      cube.Polygon(2, 6, 7), cube.Polygon(2, 7, 3),
      cube.Polygon(3, 7, 4), cube.Polygon(3, 4, 0),
      
      // Head pyramid faces
      cube.Polygon(8, 9, 12), cube.Polygon(9, 10, 12),
      cube.Polygon(10, 11, 12), cube.Polygon(11, 8, 12),
    ];
    
    return cube.Mesh(vertices: vertices, indices: indices);
  }

  // Arrow pointing towards +X (Left - away from cube)
  static cube.Mesh _createXPositiveArrow() {
    final vertices = <cube.Vector3>[
      // Shaft base at start
      cube.Vector3(0, 0.35, -0.15), cube.Vector3(0, 0.35, 0.15),
      cube.Vector3(0, 0.65, 0.15), cube.Vector3(0, 0.65, -0.15),
      
      // Shaft end (where head begins) - EXACT same X as head base
      cube.Vector3(2.0, 0.35, -0.15), cube.Vector3(2.0, 0.35, 0.15),
      cube.Vector3(2.0, 0.65, 0.15), cube.Vector3(2.0, 0.65, -0.15),
      
      // Head base (EXACT same X as shaft end for perfect connection)
      cube.Vector3(2.0, 0.15, -0.35), cube.Vector3(2.0, 0.15, 0.35),
      cube.Vector3(2.0, 0.85, 0.35), cube.Vector3(2.0, 0.85, -0.35),
      
      // Head tip
      cube.Vector3(3.0, 0.5, 0),
    ];
    
    final indices = <cube.Polygon>[
      // Shaft faces
      cube.Polygon(0, 1, 5), cube.Polygon(0, 5, 4),
      cube.Polygon(1, 2, 6), cube.Polygon(1, 6, 5),
      cube.Polygon(2, 3, 7), cube.Polygon(2, 7, 6),
      cube.Polygon(3, 0, 4), cube.Polygon(3, 4, 7),
      
      // Head pyramid faces
      cube.Polygon(8, 12, 9), cube.Polygon(9, 12, 10),
      cube.Polygon(10, 12, 11), cube.Polygon(11, 12, 8),
    ];
    
    return cube.Mesh(vertices: vertices, indices: indices);
  }

  // Arrow pointing towards -X (Right - away from cube)
  static cube.Mesh _createXNegativeArrow() {
    final vertices = <cube.Vector3>[
      // Shaft base at start
      cube.Vector3(0, 0.35, -0.15), cube.Vector3(0, 0.35, 0.15),
      cube.Vector3(0, 0.65, 0.15), cube.Vector3(0, 0.65, -0.15),
      
      // Shaft end (where head begins) - EXACT same X as head base
      cube.Vector3(-2.0, 0.35, -0.15), cube.Vector3(-2.0, 0.35, 0.15),
      cube.Vector3(-2.0, 0.65, 0.15), cube.Vector3(-2.0, 0.65, -0.15),
      
      // Head base (EXACT same X as shaft end for perfect connection)
      cube.Vector3(-2.0, 0.15, -0.35), cube.Vector3(-2.0, 0.15, 0.35),
      cube.Vector3(-2.0, 0.85, 0.35), cube.Vector3(-2.0, 0.85, -0.35),
      
      // Head tip
      cube.Vector3(-3.0, 0.5, 0),
    ];
    
    final indices = <cube.Polygon>[
      // Shaft faces
      cube.Polygon(0, 4, 5), cube.Polygon(0, 5, 1),
      cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2),
      cube.Polygon(2, 6, 7), cube.Polygon(2, 7, 3),
      cube.Polygon(3, 7, 4), cube.Polygon(3, 4, 0),
      
      // Head pyramid faces
      cube.Polygon(8, 9, 12), cube.Polygon(9, 10, 12),
      cube.Polygon(10, 11, 12), cube.Polygon(11, 8, 12),
    ];
    
    return cube.Mesh(vertices: vertices, indices: indices);
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
// FLUTTER WIDGET & STATE
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

  int _correctAttempts = 0;
  int _totalAttempts = 0;
  int _lives = 3; // The player gets 3 chances for the whole puzzle.
  
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
    if (!mounted) return; // Check before starting
    setState(() => _isGenerating = true);
    
    final puzzle = await compute(PerspectivePuzzle.generate, {'grade': widget.grade, 'level': widget.level});
    
    // Safety check before calling setState
    if (mounted) {
        setState(() {
        currentPuzzle = puzzle;
        _perspectivesToSolve = ['Front', 'Right', 'Back', 'Left']..shuffle();
        _currentTurnIndex = 0;
        _isGenerating = false;
        _cameraRotationY = 0.0; // Reset rotation
        _correctAttempts = 0;
        _totalAttempts = 0;
        _lives = 3;
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
    
    _arrowObject.children.clear();
    if (_scene!.world.children.contains(_arrowObject)) {
      _scene!.world.remove(_arrowObject);
    }

    final perspectiveInfo = _VisualConfig.perspectiveData[perspective]!;
    final arrowColor = perspectiveInfo['color'] as Color;
    final start = perspectiveInfo['arrowStart'] as cube.Vector3;
    final end = perspectiveInfo['arrowEnd'] as cube.Vector3;
    
    final newArrow = _Arrow3D.createArrow(start, end, arrowColor);
    _arrowObject.add(newArrow);
    
    _scene!.world.add(_arrowObject);
    _scene!.update();
  }
  
  void _updateCameraPosition() {
    if (_scene == null) return;
    
    final basePos = _VisualConfig.baseCameraPosition;
    
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
        var newView = correctView.map(List<Block?>.from).toList();
        int modType = random.nextInt(3);
        if (modType == 0 && newView.isNotEmpty && newView[0].length > 1) {
            int col1 = random.nextInt(newView[0].length);
            int col2 = random.nextInt(newView[0].length);
            if(col1 == col2) continue;
            for(var row in newView) {
                var temp = row[col1]; row[col1] = row[col2]; row[col2] = temp;
            }
        } else if (modType == 1) {
            var blocks = newView.expand((row) => row).nonNulls.toList();
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
            var blocks = newView.expand((row) => row).nonNulls.toList();
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

    setState(() {
      _selectedAnswerIndex = index;
      _totalAttempts++; // Track every guess as an attempt.
    });

    if (index == _correctAnswerIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _correctAttempts++; // Track correct attempts.
        _answerState = AnswerState.correct;
      });
      // Move to the next turn or win the game.
      Future.delayed(const Duration(milliseconds: 1000), _nextTurn);
    } else {
      HapticFeedback.heavyImpact();
      // On incorrect guess, lose a life.
      setState(() {
        _lives--;
        _answerState = AnswerState.incorrect;
      });

      // Check if the game is over.
      if (_lives <= 0) {
        Future.delayed(const Duration(milliseconds: 1500), _handleFailure);
      } else {
        // If not over, reset for another try on the same turn.
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _selectedAnswerIndex = -1;
              _answerState = AnswerState.unanswered;
            });
          }
        });
      }
    }
  }
  
  void _nextTurn() {
    if (!mounted) return; // safety check

    if (_currentTurnIndex < _perspectivesToSolve.length - 1) {
        setState(() => _currentTurnIndex++);
        _setupTurn();
    } else {
        _handleSuccess();
    }
    }

  void _handleSuccess() {
    if (!mounted) return;

    // 1. Calculate a performance-based score.
    int baseScore = 250 * widget.grade;
    int difficultyBonus = (currentPuzzle?.difficulty ?? 1) * 100;
    // Penalize for incorrect guesses.
    int mistakes = _totalAttempts - _correctAttempts;
    int penalty = mistakes * 50; 
    int finalScore = (baseScore + difficultyBonus - penalty).clamp(50, 1000).toInt();

    // 2. Make the single, unified call to the GameProvider.
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'perspective_puzzle',
      difficulty: currentPuzzle?.difficulty ?? 1,
      score: finalScore,
    ));
    
    // 3. Trigger UI feedback.
    _successController.forward(from: 0.0);
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => _buildSuccessDialog(finalScore)
    );
  }

  void _handleFailure() {
    if (!mounted) return;

    if (kDebugMode) debugPrint("Perspective Puzzle Failed: Ran out of lives.");

    // Report the failure to the GameProvider.
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'perspective_puzzle',
      difficulty: currentPuzzle?.difficulty ?? 1,
    ));

    // Show a failure dialog.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: SpaceTheme.rocketRed, width: 2)
        ),
        title: const Text("Mission Failed", style: SpaceTheme.headlineStyle),
        content: const Text("You've run out of attempts. Let's try a different structure.", style: SpaceTheme.bodyStyle),
        actions: [
          TextButton(
            autofocus: true,
            child: Text(S.of(context)!.tryAgain),
            onPressed: () {
              Navigator.pop(ctx);
              _generatePuzzle();
            },
          ),
        ],
      )
    );
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
          Expanded( flex: 5, child: _build3DView() ),
          const SizedBox(width: 20),
          Expanded( flex: 6, child: _buildInteractionArea() ),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded( flex: 4, child: _build3DView() ),
          const SizedBox(height: 16),
          Expanded( flex: 5, child: _buildInteractionArea() ),
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
            GestureDetector(
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: cube.Cube(
                interactive: false,
                onSceneCreated: (s) {
                  _scene = s;
                  _scene!.world.add(_sceneObject);
                  
                  _updateCameraPosition();
                  _scene!.light.position.setFrom(_VisualConfig.lightPosition);
                  
                  _updateArrowForPerspective(currentPerspective);
                },
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: perspectiveInfo['color'], width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration( color: perspectiveInfo['color'], shape: BoxShape.circle ),
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
                        width: 8, height: 8,
                        decoration: BoxDecoration( color: perspectiveInfo['color'], shape: BoxShape.circle ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      S.of(context)!.perspectiveDragHint,
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
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            S.of(context)!.perspectivePuzzleSelectView(perspective),
            style: SpaceTheme.titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
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
                  
                  final isSelected = _selectedAnswerIndex == index;
                  final isCorrect = isSelected && _answerState == AnswerState.correct;
                  final isWrong = isSelected && _answerState == AnswerState.incorrect;
                  return Semantics(
                    label: S.of(context)!.a11yAnswerChoice(index + 1),
                    button: true,
                    selected: isSelected,
                    child: GestureDetector(
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
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: PerspectiveGridWidget(
                                view: _answerChoices[index],
                                maxSize: cellSize - 16,
                              ),
                            ),
                            if (isCorrect)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.check_circle, color: SpaceTheme.alienGreen, size: 28),
                              )
                            else if (isWrong)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.cancel, color: SpaceTheme.rocketRed, size: 28),
                              ),
                          ],
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
    if (!mounted) return; // safety check
    
    _sceneObject.children.clear();
    if (blocks.isEmpty || currentPuzzle == null) return;
    
    final size = (currentPuzzle!.gridSize - 1) / 2.0;
    final height = (currentPuzzle!.maxHeight) / 2.0;
    
    for (final block in blocks) {
        final material = cube.Material();
        material.diffuse.setValues(block.color.r, block.color.g, block.color.b);
        _sceneObject.add(cube.Object(
        position: cube.Vector3(block.x - size, block.y - height, block.z - size),
        mesh: cube.Mesh(
            vertices: _CubeGeometry.vertices, 
            indices: _CubeGeometry.indices,
            material: material
        )
        ));
    }
    
    // Only update scene if mounted
    if (mounted && _scene != null) {
        _scene!.update();
    }
    }
  
  Widget _buildSuccessDialog(int bonusScore) {
     return ScaleTransition(
      scale: CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
      child: AlertDialog(
        backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: SpaceTheme.alienGreen, width: 2)),
        title: Text(S.of(context)!.perspectivePuzzleWinTitle, style: SpaceTheme.headlineStyle),
        content: Text(S.of(context)!.perspectivePuzzleWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,),
        actions: [
          TextButton(
            autofocus: true,
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