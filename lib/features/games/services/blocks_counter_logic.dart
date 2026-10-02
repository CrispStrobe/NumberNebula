import 'generator_random.dart';
import 'dart:math' as math;

const generatorPalette = [
  0xFF00C8FF,
  0xFF64DD17,
  0xFFFF9100,
  0xFFD500F9,
  0xFF304FFE,
  0xFFFFEA00,
  0xFF1DE9B6,
  0xFFFF1744
];

class BlockPosition3D {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'z': z, 'isVisible': isVisible, 'color': color};
  factory BlockPosition3D.fromJson(Map<String, dynamic> json) =>
      BlockPosition3D(
          x: json['x'] as int,
          y: json['y'] as int,
          z: json['z'] as int,
          isVisible: json['isVisible'] as bool,
          color: json['color'] as int);

  final int x, y, z;
  final bool isVisible;
  final int color;

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
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((v0) => v0.toJson()).toList(),
        'gridWidth': gridWidth,
        'gridDepth': gridDepth,
        'maxHeight': maxHeight
      };
  factory BlockStructure.fromJson(Map<String, dynamic> json) => BlockStructure(
      blocks: (json['blocks'] as List)
          .map((v0) =>
              BlockPosition3D.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList(),
      gridWidth: json['gridWidth'] as int,
      gridDepth: json['gridDepth'] as int,
      maxHeight: json['maxHeight'] as int);

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
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'blockStructure': blockStructure.toJson(),
        'correctAnswer': correctAnswer,
        'answerChoices': answerChoices.map((v0) => v0).toList(),
        'difficulty': difficulty
      };
  factory BlockCountingPuzzle.fromJson(Map<String, dynamic> json) =>
      BlockCountingPuzzle(
          blockStructure: BlockStructure.fromJson(
              Map<String, dynamic>.from(json['blockStructure'] as Map)),
          correctAnswer: json['correctAnswer'] as int,
          answerChoices:
              (json['answerChoices'] as List).map((v0) => v0 as int).toList(),
          difficulty: json['difficulty'] as int);

  final BlockStructure blockStructure;
  final int correctAnswer;
  final List<int> answerChoices;
  final int difficulty;

  BlockCountingPuzzle(
      {required this.blockStructure,
      required this.correctAnswer,
      required this.answerChoices,
      required this.difficulty});

  static BlockCountingPuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = generatorRandom();

    // 1. Determine puzzle parameters based on player progress
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 3 + (difficulty ~/ 1.5);
    final totalBlocks = 8 + (difficulty * 5) + random.nextInt(difficulty * 2);
    const moveProbability = 0.65;

    // 2. Create a 2D grid to represent the height map of the structure
    List<List<int>> grid = List.generate(
        gridSize.toInt(), (_) => List.generate(gridSize.toInt(), (_) => 0));

    // 3. Perform a "random walk" to place stacks of blocks
    int currentX = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    int currentZ = random.nextInt(gridSize ~/ 2) + (gridSize ~/ 4);
    grid[currentX][currentZ] = 1;

    for (int i = 1; i < totalBlocks; i++) {
      // Occasionally move to an adjacent tile
      if (random.nextDouble() < moveProbability) {
        final moves = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1]
        ]..shuffle(generatorRandom());
        for (var move in moves) {
          int nextX = currentX + move[0];
          int nextZ = currentZ + move[1];
          // Check if the move is within the grid bounds
          if (nextX >= 0 &&
              nextX < gridSize &&
              nextZ >= 0 &&
              nextZ < gridSize) {
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
    final puzzleColor =
        generatorPalette[random.nextInt(generatorPalette.length)];

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
      choices.add(
          math.max(1, correctAnswer + (random.nextBool() ? 1 : -1) * offset));
    }

    return BlockCountingPuzzle(
      blockStructure: BlockStructure(
          blocks: blocks,
          gridWidth: gridSize.toInt(),
          gridDepth: gridSize.toInt(),
          maxHeight: maxHeight),
      correctAnswer: correctAnswer,
      answerChoices: choices.toList()..shuffle(generatorRandom()),
      difficulty: difficulty,
    );
  }

  // Helper to determine if a block is externally visible
  static bool _isBlockVisible(
      int x, int y, int z, List<List<int>> grid, int stackHeight) {
    if (y == stackHeight - 1) return true; // Top block is always visible
    int gridSize = grid.length;
    if (x == 0 || grid[x - 1][z] <= y) return true;
    if (x == gridSize - 1 || grid[x + 1][z] <= y) return true;
    if (z == 0 || grid[x][z - 1] <= y) return true;
    if (z == gridSize - 1 || grid[x][z + 1] <= y) return true;
    return false;
  }
}
