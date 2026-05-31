// lib/features/games/services/relic_assembly_logic.dart
//
// Edge-matching card puzzle generator.
// Place and rotate tiles in a grid so touching edges match.
// Each tile has 4 edge values (top, right, bottom, left).

import 'dart:math' as math;

class RelicTile {
  /// Edge values: [top, right, bottom, left]
  final List<int> edges;

  /// Current rotation (0, 1, 2, 3 = 0, 90, 180, 270 degrees clockwise)
  int rotation;

  RelicTile({required this.edges, this.rotation = 0});

  /// Get the effective edge value at a given side after rotation.
  /// Side: 0=top, 1=right, 2=bottom, 3=left
  int getEdge(int side) {
    return edges[(side - rotation + 4) % 4];
  }

  RelicTile copyWith({int? rotation}) {
    return RelicTile(
      edges: List.from(edges),
      rotation: rotation ?? this.rotation,
    );
  }
}

class RelicAssemblyPuzzle {
  final int rows;
  final int cols;

  /// The correct arrangement of tiles (row-major order).
  final List<RelicTile> solutionTiles;

  /// The tiles given to the player (shuffled, rotations randomized).
  final List<RelicTile> playerTiles;

  /// Number of distinct edge values used.
  final int edgeValueCount;

  RelicAssemblyPuzzle({
    required this.rows,
    required this.cols,
    required this.solutionTiles,
    required this.playerTiles,
    required this.edgeValueCount,
  });

  /// Validate that the player's placement is correct.
  /// [placement] maps grid position (index) -> tile index in playerTiles.
  /// Each tile also has its rotation set.
  bool validatePlacement(List<int> placement, List<int> rotations) {
    if (placement.length != rows * cols) return false;

    // Check all internal edge matches
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final tileIdx = placement[idx];
        if (tileIdx < 0 || tileIdx >= playerTiles.length) return false;

        final tile = playerTiles[tileIdx].copyWith(rotation: rotations[tileIdx]);

        // Check right neighbor
        if (c < cols - 1) {
          final rightTileIdx = placement[idx + 1];
          final rightTile = playerTiles[rightTileIdx].copyWith(rotation: rotations[rightTileIdx]);
          if (tile.getEdge(1) != rightTile.getEdge(3)) return false;
        }

        // Check bottom neighbor
        if (r < rows - 1) {
          final bottomTileIdx = placement[idx + cols];
          final bottomTile = playerTiles[bottomTileIdx].copyWith(rotation: rotations[bottomTileIdx]);
          if (tile.getEdge(2) != bottomTile.getEdge(0)) return false;
        }
      }
    }

    return true;
  }
}

class RelicAssemblyGenerator {
  final math.Random _random = math.Random();

  /// Generate an edge-matching puzzle.
  /// [rows] and [cols] define the grid.
  /// [edgeValueCount] is how many distinct glyph types to use.
  Future<RelicAssemblyPuzzle> generate({
    required int rows,
    required int cols,
    required int edgeValueCount,
  }) async {
    // Generate a valid grid of tiles where internal edges match
    final tiles = <RelicTile>[];

    // Create a grid of edge values
    // Horizontal edges: between (r,c) bottom and (r+1,c) top
    // Vertical edges: between (r,c) right and (r,c+1) left
    final hEdges = <String, int>{}; // 'r_c' -> value for horizontal edge below (r,c)
    final vEdges = <String, int>{}; // 'r_c' -> value for vertical edge right of (r,c)

    // Assign random matching values to internal edges
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (r < rows - 1) {
          hEdges['${r}_$c'] = _random.nextInt(edgeValueCount) + 1;
        }
        if (c < cols - 1) {
          vEdges['${r}_$c'] = _random.nextInt(edgeValueCount) + 1;
        }
      }
    }

    // Build tiles from the edge grid
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Top edge
        final top = r > 0 ? hEdges['${r - 1}_$c']! : (_random.nextInt(edgeValueCount) + 1);
        // Right edge
        final right = c < cols - 1 ? vEdges['${r}_$c']! : (_random.nextInt(edgeValueCount) + 1);
        // Bottom edge
        final bottom = r < rows - 1 ? hEdges['${r}_$c']! : (_random.nextInt(edgeValueCount) + 1);
        // Left edge
        final left = c > 0 ? vEdges['${r}_${c - 1}']! : (_random.nextInt(edgeValueCount) + 1);

        tiles.add(RelicTile(edges: [top, right, bottom, left]));
      }
    }

    // Create player tiles: shuffle order and randomize rotations
    final playerTiles = tiles.map((t) {
      final rot = _random.nextInt(4);
      return RelicTile(edges: List.from(t.edges), rotation: rot);
    }).toList();

    // Shuffle the player tiles
    playerTiles.shuffle(_random);

    return RelicAssemblyPuzzle(
      rows: rows,
      cols: cols,
      solutionTiles: tiles,
      playerTiles: playerTiles,
      edgeValueCount: edgeValueCount,
    );
  }
}
