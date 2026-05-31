import 'dart:math' as math;

/// Represents a planar graph for the Sector Painter (graph coloring) game.
class SectorPainterPuzzle {
  /// List of region names/IDs
  final List<int> regions;

  /// Adjacency list: regionIndex -> set of adjacent region indices
  final Map<int, Set<int>> adjacency;

  /// The minimum number of colors needed (chromatic number)
  final int chromaticNumber;

  /// Number of colors available to the player
  final int availableColors;

  /// Positions for rendering (normalized 0..1)
  final List<math.Point<double>> positions;

  SectorPainterPuzzle({
    required this.regions,
    required this.adjacency,
    required this.chromaticNumber,
    required this.availableColors,
    required this.positions,
  });

  /// Validate that no two adjacent regions share the same color.
  bool validateColoring(Map<int, int> coloring) {
    for (final region in regions) {
      if (!coloring.containsKey(region)) return false;
      final color = coloring[region]!;
      for (final neighbor in adjacency[region] ?? <int>{}) {
        if (coloring[neighbor] == color) return false;
      }
    }
    return true;
  }

  /// Count distinct colors used in a coloring.
  int countColors(Map<int, int> coloring) {
    return coloring.values.toSet().length;
  }
}

class SectorPainterGenerator {
  final math.Random _random;

  SectorPainterGenerator({int? seed}) : _random = math.Random(seed);

  /// Generate a puzzle based on grade/level difficulty.
  ///
  /// - grade 1: 4 regions, 2-3 colors
  /// - grade 2: 5-6 regions, 3 colors
  /// - grade 3: 7-8 regions, 3-4 colors
  /// - grade 4: 9-12 regions, 3-4 colors
  SectorPainterPuzzle generate({required int grade, required int level}) {
    int regionCount;
    int numColors;

    if (grade <= 1) {
      regionCount = 4;
      numColors = 3;
    } else if (grade <= 2) {
      regionCount = 5 + (level > 5 ? 1 : 0);
      numColors = 3;
    } else if (grade <= 3) {
      regionCount = 7 + (level > 5 ? 1 : 0);
      numColors = level > 8 ? 4 : 3;
    } else {
      regionCount = math.min(12, 9 + level ~/ 5);
      numColors = level > 5 ? 4 : 3;
    }

    return _generatePlanarGraph(regionCount, numColors);
  }

  SectorPainterPuzzle _generatePlanarGraph(int regionCount, int numColors) {
    final regions = List.generate(regionCount, (i) => i);
    final adjacency = <int, Set<int>>{};
    for (final r in regions) {
      adjacency[r] = <int>{};
    }

    // Generate positions in a circle with some jitter
    final positions = <math.Point<double>>[];
    for (int i = 0; i < regionCount; i++) {
      final angle = (2 * math.pi * i) / regionCount;
      final radius = 0.3 + _random.nextDouble() * 0.1;
      final x = 0.5 + radius * math.cos(angle);
      final y = 0.5 + radius * math.sin(angle);
      positions.add(math.Point(x, y));
    }

    // Create edges: connect each node to its circular neighbors
    for (int i = 0; i < regionCount; i++) {
      final next = (i + 1) % regionCount;
      _addEdge(adjacency, i, next);
    }

    // Add some cross-edges to make it more interesting, keeping it planar-like
    final maxExtraEdges = regionCount ~/ 2;
    int added = 0;
    for (int attempt = 0; attempt < regionCount * 3 && added < maxExtraEdges; attempt++) {
      final a = _random.nextInt(regionCount);
      final b = _random.nextInt(regionCount);
      if (a != b && !adjacency[a]!.contains(b)) {
        // Only add if distance > 1 in circular order
        final dist = (a - b).abs();
        final circDist = math.min(dist, regionCount - dist);
        if (circDist >= 2) {
          _addEdge(adjacency, a, b);
          added++;
        }
      }
    }

    // Compute chromatic number via greedy (approximate)
    final chromaticNumber = _greedyChromaticNumber(regions, adjacency);

    return SectorPainterPuzzle(
      regions: regions,
      adjacency: adjacency,
      chromaticNumber: chromaticNumber,
      availableColors: numColors,
      positions: positions,
    );
  }

  void _addEdge(Map<int, Set<int>> adj, int a, int b) {
    adj[a]!.add(b);
    adj[b]!.add(a);
  }

  int _greedyChromaticNumber(List<int> regions, Map<int, Set<int>> adjacency) {
    final coloring = <int, int>{};
    for (final region in regions) {
      final neighborColors = <int>{};
      for (final neighbor in adjacency[region] ?? <int>{}) {
        if (coloring.containsKey(neighbor)) {
          neighborColors.add(coloring[neighbor]!);
        }
      }
      // Assign the smallest color not used by neighbors
      int color = 0;
      while (neighborColors.contains(color)) {
        color++;
      }
      coloring[region] = color;
    }
    return coloring.values.toSet().length;
  }
}
