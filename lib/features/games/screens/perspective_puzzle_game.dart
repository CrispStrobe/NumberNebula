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
  static const int rotationDurationSeconds = 25;
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

    int maxHeight = structure.map((b) => b.y).reduce(math.max);
    
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
        Block? frontBlock;
        for (int z = 0; z < size; z++) {
          final block = s.firstWhereOrNull((b) => b.x == x && b.y == y && b.z == z);
          if (block != null) { frontBlock = block; break; }
        }
        if (frontBlock != null) view[maxH-y][x] = frontBlock;
      }
    }
    return view;
  }
  
  static PerspectiveView _getBackView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        Block? backBlock;
        for (int z = size - 1; z >= 0; z--) {
          final block = s.firstWhereOrNull((b) => b.x == x && b.y == y && b.z == z);
          if (block != null) { backBlock = block; break; }
        }
        if (backBlock != null) view[maxH-y][size-1-x] = backBlock;
      }
    }
    return view;
  }
  
  static PerspectiveView _getLeftView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        Block? leftBlock;
        for (int x = 0; x < size; x++) {
          final block = s.firstWhereOrNull((b) => b.x == x && b.y == y && b.z == z);
          if (block != null) { leftBlock = block; break; }
        }
        if (leftBlock != null) view[maxH-y][z] = leftBlock;
      }
    }
    return view;
  }
  
  static PerspectiveView _getRightView(Set<Block> s, int size, int maxH) {
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        Block? rightBlock;
        for (int x = size - 1; x >= 0; x--) {
          final block = s.firstWhereOrNull((b) => b.x == x && b.y == y && b.z == z);
          if (block != null) { rightBlock = block; break; }
        }
        if (rightBlock != null) view[maxH-y][size-1-z] = rightBlock;
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
  late AnimationController _rotationController;

  PerspectivePuzzle? currentPuzzle;
  bool _isGenerating = true;
  
  List<String> _perspectivesToSolve = [];
  int _currentTurnIndex = 0;
  List<PerspectiveView> _answerChoices = [];
  int _correctAnswerIndex = -1;
  int _selectedAnswerIndex = -1;
  AnswerState _answerState = AnswerState.unanswered;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _rotationController = AnimationController(duration: const Duration(seconds: _VisualConfig.rotationDurationSeconds), vsync: this)..repeat();
    _generatePuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    _rotationController.dispose();
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
        _setupTurn();
      });
    }
  }

  void _setupTurn() {
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
    final decoys = <PerspectiveView>{};
    final random = math.Random();
    
    while (decoys.length < count) {
        var newView = correctView.map((row) => List<Block?>.from(row)).toList();
        int modType = random.nextInt(3);
        if (modType == 0 && newView.isNotEmpty && newView[0].length > 1) {
            int col1 = random.nextInt(newView[0].length);
            int col2 = random.nextInt(newView[0].length);
            for(var row in newView) {
                var temp = row[col1]; row[col1] = row[col2]; row[col2] = temp;
            }
        } else if (modType == 1) {
            var blocks = newView.expand((row) => row).whereNotNull().toList();
            if (blocks.isNotEmpty) {
                var blockToRemove = blocks[random.nextInt(blocks.length)];
                for (var i = 0; i < newView.length; i++) {
                    for (var j = 0; j < newView[i].length; j++) {
                        if (newView[i][j] == blockToRemove) newView[i][j] = null;
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
    final sceneObject = _createSceneObject(puzzle.structure);
    cube.Scene? scene;
    
    return Container(
      decoration: SpaceTheme.cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            sceneObject.rotation.y = _rotationController.value * 2 * math.pi;
            scene?.update();
            return child!;
          },
          child: cube.Cube(
            onSceneCreated: (s) {
              scene = s;
              scene!.world.add(sceneObject);
              final maxDim = math.max(puzzle.gridSize, puzzle.maxHeight).toDouble();
              final distance = maxDim * _VisualConfig.cameraDistanceFactor + 2.0;
              scene!.camera.position.setValues(distance, distance * 0.8, distance);
              scene!.camera.target.setFrom(_VisualConfig.cameraTarget);
              scene!.light.position.setFrom(_VisualConfig.lightPosition);
            },
          ),
        ),
      ),
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
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
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: SpaceTheme.deepSpace,
                    border: border
                  ),
                  child: PerspectiveGridWidget(view: _answerChoices[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  cube.Object _createSceneObject(Set<Block> blocks) {
    final scene = cube.Object(name: 'world');
    if (blocks.isEmpty || currentPuzzle == null) return scene;
    final size = currentPuzzle!.gridSize / 2.0;
    final height = currentPuzzle!.maxHeight / 2.0;
    
    for (final block in blocks) {
      // FIX: Use the correct method to set material color
      final material = cube.Material();
      material.diffuse.setValues(block.color.red/255, block.color.green/255, block.color.blue/255);

      scene.add(cube.Object(
        position: cube.Vector3(block.x - size, block.y - height, block.z - size),
        mesh: cube.Mesh(
          vertices: _CubeGeometry.vertices, 
          indices: _CubeGeometry.indices,
          material: material
        )
      ));
    }
    return scene;
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

class PerspectiveGridWidget extends StatelessWidget {
  final PerspectiveView view;
  const PerspectiveGridWidget({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    if (view.isEmpty || view[0].isEmpty) return const SizedBox.shrink();
    return GridView.builder(
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
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: block?.color ?? Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}