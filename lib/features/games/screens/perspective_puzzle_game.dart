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
  static const double cameraDistanceFactor = 2.5;
  static final cube.Vector3 cameraTarget = cube.Vector3(0, -0.5, 0);
  static final cube.Vector3 lightPosition = cube.Vector3(15, 20, 20);
  static final List<Color> blockColors = [
    const Color(0xFF00C8FF), const Color(0xFF64DD17), const Color(0xFFFF9100),
    const Color(0xFFD500F9), const Color(0xFFFFEA00), const Color(0xFFFF1744),
  ];
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
    // Puzzle generation logic remains the same and is correct.
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 3 + (difficulty ~/ 2);
    final totalBlocks = 6 + (difficulty * 3) + random.nextInt(difficulty * 2);
    Set<Block> structure = {};
    var heightMap = List.generate(gridSize, (_) => List.generate(gridSize, (_) => -1));
    int currentX = random.nextInt(gridSize);
    int currentZ = random.nextInt(gridSize);
    for (int i = 0; i < totalBlocks; i++) {
      if (random.nextDouble() < 0.7 || heightMap[currentX][currentZ] == -1) {
        final moves = [[-1,0],[1,0],[0,-1],[0,1]]..shuffle();
        for(var move in moves) {
            int nextX = currentX + move[0], nextZ = currentZ + move[1];
            if(nextX >= 0 && nextX < gridSize && nextZ >= 0 && nextZ < gridSize) {
                currentX = nextX; currentZ = nextZ;
                break;
            }
        }
      }
      int currentY = heightMap[currentX][currentZ] + 1;
      final color = _VisualConfig.blockColors[random.nextInt(_VisualConfig.blockColors.length)];
      structure.add((x: currentX, y: currentY, z: currentZ, color: color));
      heightMap[currentX][currentZ] = currentY;
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
      correctViews: correctViews
    );
  }

  static PerspectiveView _createEmptyView(int width, int height) =>
      List.generate(height + 1, (_) => List.generate(width, (_) => null));
  static PerspectiveView _getFrontView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        s.where((b) => b.x == x && b.y == y).sortedBy<num>((b) => b.z).firstOrNull
          .let((b) => view[maxH-y][x] = b);
      }
    }
    return view;
  }
  static PerspectiveView _getBackView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        s.where((b) => b.x == x && b.y == y).sortedBy<num>((b) => -b.z).firstOrNull
          .let((b) => view[maxH-y][x] = b);
      }
    }
    return view;
  }
  static PerspectiveView _getLeftView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        s.where((b) => b.z == z && b.y == y).sortedBy<num>((b) => b.x).firstOrNull
          .let((b) => view[maxH-y][z] = b);
      }
    }
    return view;
  }
  static PerspectiveView _getRightView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        s.where((b) => b.z == z && b.y == y).sortedBy<num>((b) => -b.x).firstOrNull
          .let((b) => view[maxH-y][size-1-z] = b);
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
  cube.Scene? _scene;

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
    // Puzzle generation, state setup, and game logic methods remain the same
    // They are correct and do not need changes.
    setState(() => _isGenerating = true);
    final puzzle = await compute(PerspectivePuzzle.generate, {'grade': widget.grade, 'level': widget.level});
    if (mounted) {
      setState(() {
        currentPuzzle = puzzle;
        _perspectivesToSolve = ['Front', 'Right', 'Back', 'Left']..shuffle();
        _currentTurnIndex = 0;
        _isGenerating = false;
        _createSceneObject(puzzle.structure);
        _setupTurn();
      });
    }
  }

  void _setupTurn() {
    // This logic is also correct.
    final currentPerspective = _perspectivesToSolve[_currentTurnIndex];
    final correctView = currentPuzzle!.correctViews[currentPerspective]!;
    final decoys = _generateDecoys(correctView, 2);
    setState(() {
      _answerChoices = [correctView, ...decoys]..shuffle();
      _correctAnswerIndex = _answerChoices.indexOf(correctView);
      _selectedAnswerIndex = -1;
      _answerState = AnswerState.unanswered;
    });
  }
  
  List<PerspectiveView> _generateDecoys(PerspectiveView correctView, int count) {
    // This logic is correct.
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
                    newView[i].remove(blockToRemove);
                }
            }
        } else {
            var blocks = newView.expand((row) => row).whereNotNull().toList();
             if (blocks.isNotEmpty) {
                var blockToChange = blocks[random.nextInt(blocks.length)];
                var newColor = _VisualConfig.blockColors[random.nextInt(_VisualConfig.blockColors.length)];
                for (var i = 0; i < newView.length; i++) {
                    for (var j = 0; j < newView[i].length; j++) {
                        if (newView[i][j] == blockToChange) newView[i][j] = (x: blockToChange.x, y: blockToChange.y, z: blockToChange.z, color: newColor);
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
                    return constraints.maxWidth > 650 ? _buildWideLayout() : _buildTallLayout();
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: _build3DView()),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildInteractionArea()),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Expanded(flex: 4, child: _build3DView()),
          const SizedBox(height: 16),
          Expanded(flex: 5, child: _buildInteractionArea()),
        ],
      ),
    );
  }

  Widget _build3DView() {
    final puzzle = currentPuzzle!;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: SpaceTheme.cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanUpdate: (details) {
                _sceneObject.rotation.y += details.delta.dx * 0.01;
                _scene?.update();
              },
              child: cube.Cube(
                // FIX: Disable the library's built-in controls
                interactive: false,
                onSceneCreated: (s) {
                  _scene = s;
                  _scene!.world.add(_sceneObject);
                  final maxDim = math.max(puzzle.gridSize, puzzle.maxHeight).toDouble();
                  final distance = maxDim * _VisualConfig.cameraDistanceFactor + 2.0;
                  _scene!.camera.position.setValues(distance, distance * 0.8, distance);
                  _scene!.camera.target.setFrom(_VisualConfig.cameraTarget);
                  _scene!.light.position.setFrom(_VisualConfig.lightPosition);
                },
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text("FRONT", style: SpaceTheme.bodyStyle.copyWith(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
                  const Icon(Icons.arrow_downward, color: Colors.white54, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionArea() {
    final perspective = _getTranslatedPerspective(context, _perspectivesToSolve[_currentTurnIndex]);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          S.of(context)!.perspectivePuzzleSelectView(perspective),
          style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _answerChoices.length,
            itemBuilder: (context, index) {
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
                  padding: const EdgeInsets.all(8), // Add padding around the FittedBox
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: SpaceTheme.deepSpace,
                    border: border
                  ),
                  // FIX: This robustly scales the grid to fit ANY available space.
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: PerspectiveGridWidget(view: _answerChoices[index]),
                  ),
                ),
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
    _sceneObject.rotation.y = 0; // Reset rotation for new puzzle
    final size = currentPuzzle!.gridSize / 2.0;
    final height = currentPuzzle!.maxHeight / 2.0;
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

// FIX: This widget is now self-sizing for use in FittedBox.
class PerspectiveGridWidget extends StatelessWidget {
  final PerspectiveView view;
  final double cellSize; // The size of each block cell
  const PerspectiveGridWidget({super.key, required this.view, this.cellSize = 30.0});

  @override
  Widget build(BuildContext context) {
    if (view.isEmpty || view[0].isEmpty) return const SizedBox.shrink();
    
    // Calculate the intrinsic size of the grid
    final width = view[0].length * cellSize;
    final height = view.length * cellSize;

    return SizedBox(
      width: width,
      height: height,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: view[0].length,
        ),
        itemCount: view.length * view[0].length,
        itemBuilder: (context, index) {
          final row = index ~/ view[0].length;
          final col = index % view[0].length;
          final block = view[row][col];
          return Container(
            margin: const EdgeInsets.all(1.0),
            decoration: BoxDecoration(
              color: block?.color ?? Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);
}