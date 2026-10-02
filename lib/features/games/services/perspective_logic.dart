import 'generator_random.dart';
import 'dart:math' as math;
import 'generator_diagnostics.dart';
import 'package:collection/collection.dart';

const generatorPalette = [
  0xFF00C8FF,
  0xFF64DD17,
  0xFFFF9100,
  0xFFD500F9,
  0xFFFFEA00,
  0xFFFF1744
];
typedef Block = ({int x, int y, int z, int color});
typedef PerspectiveView = List<List<Block?>>;

class PerspectivePuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'structure': structure
            .map((v0) => {'x': v0.x, 'y': v0.y, 'z': v0.z, 'color': v0.color})
            .toList(),
        'gridSize': gridSize,
        'maxHeight': maxHeight,
        'difficulty': difficulty,
        'correctViews': correctViews.entries
            .map((v0) => [
                  v0.key,
                  v0.value
                      .map((v1) => v1
                          .map((v2) => (v2 == null
                              ? null
                              : {
                                  'x': v2.x,
                                  'y': v2.y,
                                  'z': v2.z,
                                  'color': v2.color
                                }))
                          .toList())
                      .toList()
                ])
            .toList()
      };
  factory PerspectivePuzzle.fromJson(Map<String, dynamic> json) =>
      PerspectivePuzzle(
          structure: (json['structure'] as List)
              .map((v0) => (
                    x: v0['x'] as int,
                    y: v0['y'] as int,
                    z: v0['z'] as int,
                    color: v0['color'] as int
                  ))
              .toSet(),
          gridSize: json['gridSize'] as int,
          maxHeight: json['maxHeight'] as int,
          difficulty: json['difficulty'] as int,
          correctViews: Map<String, PerspectiveView>.fromEntries(
              (json['correctViews'] as List).map((v0) => MapEntry(
                  v0[0] as String,
                  (v0[1] as List)
                      .map((v1) => (v1 as List)
                          .map((v2) => (v2 == null
                              ? null
                              : (
                                  x: v2['x'] as int,
                                  y: v2['y'] as int,
                                  z: v2['z'] as int,
                                  color: v2['color'] as int
                                )))
                          .toList())
                      .toList()))));

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
    final random = generatorRandom();
    final difficulty = math.min(5, (grade) + (level ~/ 4));
    final gridSize = 3 + (difficulty ~/ 3);
    final totalBlocks = 4 + (difficulty * 2) + random.nextInt(difficulty + 2);
    Set<Block> structure = {};
    var heightMap =
        List.generate(gridSize, (_) => List.generate(gridSize, (_) => 0));

    int currentX = gridSize ~/ 2;
    int currentZ = gridSize ~/ 2;

    for (int i = 0; i < totalBlocks; i++) {
      if (random.nextDouble() < 0.5 || heightMap[currentX][currentZ] >= 2) {
        final moves = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1]
        ]..shuffle(generatorRandom());
        for (var move in moves) {
          int nextX = currentX + move[0], nextZ = currentZ + move[1];
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
      int currentY = heightMap[currentX][currentZ];
      final color = generatorPalette[random.nextInt(generatorPalette.length)];
      structure.add((x: currentX, y: currentY, z: currentZ, color: color));
      heightMap[currentX][currentZ] = currentY + 1;
    }

    int maxHeight =
        structure.isEmpty ? 0 : structure.map((b) => b.y).reduce(math.max);
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
    if (kDebugMode) {
      traceGenerator('[PerspectivePuzzle] Calculating Front View...');
    }
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        final block = s
            .where((b) => b.x == x && b.y == y)
            .sortedBy<num>((b) => -b.z)
            .firstOrNull; // Max Z is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = x;
          view[viewRow][viewCol] = block;
          if (kDebugMode) {
            traceGenerator(
                '  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol].');
          }
        }
      }
    }
    return view;
  }

  // View from the Back (-Z axis looking toward +Z), mirrored horizontally
  static PerspectiveView _getBackView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) {
      traceGenerator('[PerspectivePuzzle] Calculating Back View...');
    }
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int x = 0; x < size; x++) {
        final block = s
            .where((b) => b.x == x && b.y == y)
            .sortedBy<num>((b) => b.z)
            .firstOrNull; // Min Z is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = size - 1 - x; // Flipped horizontally
          view[viewRow][viewCol] = block;
          if (kDebugMode) {
            traceGenerator(
                '  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol]. (Original x:${block.x} flipped to $viewCol)');
          }
        }
      }
    }
    return view;
  }

  // View from the Left (-X axis looking toward +X)
  static PerspectiveView _getLeftView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) {
      traceGenerator('[PerspectivePuzzle] Calculating Left View...');
    }
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        final block = s
            .where((b) => b.z == z && b.y == y)
            .sortedBy<num>((b) => b.x)
            .firstOrNull; // Min X is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = z; // Z-axis becomes the horizontal axis
          view[viewRow][viewCol] = block;
          if (kDebugMode) {
            traceGenerator(
                '  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol].');
          }
        }
      }
    }
    return view;
  }

  // View from the Right (+X axis looking toward -X), mirrored horizontally
  static PerspectiveView _getRightView(Set<Block> s, int size, int maxH) {
    if (kDebugMode) {
      traceGenerator('[PerspectivePuzzle] Calculating Right View...');
    }
    var view = _createEmptyView(size, maxH);
    for (int y = 0; y <= maxH; y++) {
      for (int z = 0; z < size; z++) {
        final block = s
            .where((b) => b.z == z && b.y == y)
            .sortedBy<num>((b) => -b.x)
            .firstOrNull; // Max X is visible
        if (block != null) {
          final viewRow = maxH - y;
          final viewCol = size - 1 - z; // Flipped horizontally
          view[viewRow][viewCol] = block;
          if (kDebugMode) {
            traceGenerator(
                '  - Found block at (x:${block.x}, y:${block.y}, z:${block.z}). Mapped to view[$viewRow][$viewCol]. (Original z:${block.z} flipped to $viewCol)');
          }
        }
      }
    }
    return view;
  }
}
