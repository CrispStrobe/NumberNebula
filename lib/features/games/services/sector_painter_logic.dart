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

  /// Return list of conflicting pairs (both share same color).
  List<List<int>> findConflicts(Map<int, int> coloring) {
    final conflicts = <List<int>>[];
    for (final region in regions) {
      if (!coloring.containsKey(region)) continue;
      final color = coloring[region]!;
      for (final neighbor in adjacency[region] ?? <int>{}) {
        if (neighbor > region && coloring[neighbor] == color) {
          conflicts.add([region, neighbor]);
        }
      }
    }
    return conflicts;
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
  SectorPainterPuzzle generate({required int grade, required int level}) {
    int regionCount;
    int numColors;

    if (grade <= 1) {
      regionCount = 6;
      numColors = 3;
    } else if (grade <= 2) {
      regionCount = 7 + (level > 5 ? 1 : 0);
      numColors = 3;
    } else if (grade <= 3) {
      regionCount = 9 + (level > 5 ? 1 : 0);
      numColors = level > 8 ? 4 : 3;
    } else {
      regionCount = math.min(15, 10 + level ~/ 3);
      numColors = level > 5 ? 5 : 4;
    }

    return _generateGraph(regionCount, numColors);
  }

  /// Pick from a set of interesting graph topologies that look like maps.
  SectorPainterPuzzle _generateGraph(int regionCount, int numColors) {
    // Try multiple times to get a good graph
    for (int attempt = 0; attempt < 10; attempt++) {
      final result = _buildScatteredGraph(regionCount, numColors);
      if (result != null) return result;
    }
    // Fallback: always succeeds
    return _buildScatteredGraph(regionCount, numColors, forceSuccess: true)!;
  }

  /// Build a graph by scattering seed points and connecting nearby ones
  /// (Delaunay-inspired). Produces map-like shapes.
  SectorPainterPuzzle? _buildScatteredGraph(int regionCount, int numColors,
      {bool forceSuccess = false}) {
    final regions = List.generate(regionCount, (i) => i);
    final positions = <math.Point<double>>[];
    final adjacency = <int, Set<int>>{};
    for (final r in regions) {
      adjacency[r] = <int>{};
    }

    // Pick a topology shape
    final shape = _random.nextInt(5);
    switch (shape) {
      case 0:
        _scatterIslandChain(positions, regionCount);
        break;
      case 1:
        _scatterGalaxyCluster(positions, regionCount);
        break;
      case 2:
        _scatterNebulaCloud(positions, regionCount);
        break;
      case 3:
        _scatterRingFormation(positions, regionCount);
        break;
      default:
        _scatterCrossPattern(positions, regionCount);
        break;
    }

    // Connect neighbors: for each point, connect to the K nearest,
    // ensuring every node has at least 2 connections.
    final maxNeighbors = math.min(4, regionCount - 1);

    // Compute all pairwise distances
    final distances = <_Edge>[];
    for (int i = 0; i < regionCount; i++) {
      for (int j = i + 1; j < regionCount; j++) {
        final dx = positions[i].x - positions[j].x;
        final dy = positions[i].y - positions[j].y;
        distances.add(_Edge(i, j, math.sqrt(dx * dx + dy * dy)));
      }
    }
    distances.sort((a, b) => a.dist.compareTo(b.dist));

    // Add edges by shortest distance, respecting max degree
    final degree = List.filled(regionCount, 0);
    for (final edge in distances) {
      if (degree[edge.a] < maxNeighbors && degree[edge.b] < maxNeighbors) {
        _addEdge(adjacency, edge.a, edge.b);
        degree[edge.a]++;
        degree[edge.b]++;
      }
    }

    // Ensure minimum connectivity: every node needs at least 2 edges
    for (int i = 0; i < regionCount; i++) {
      if (adjacency[i]!.length < 2) {
        // Find nearest unconnected node
        for (final edge in distances) {
          final other = edge.a == i ? edge.b : (edge.b == i ? edge.a : -1);
          if (other == -1) continue;
          if (adjacency[i]!.contains(other)) continue;
          _addEdge(adjacency, i, other);
          break;
        }
      }
    }

    // Ensure the graph is connected (union-find)
    final parent = List.generate(regionCount, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }
    void union(int a, int b) {
      parent[find(a)] = find(b);
    }

    for (final region in regions) {
      for (final neighbor in adjacency[region]!) {
        union(region, neighbor);
      }
    }

    // Connect disconnected components
    for (int i = 1; i < regionCount; i++) {
      if (find(i) != find(0)) {
        // Find the closest node in the main component
        double bestDist = double.infinity;
        int bestJ = 0;
        for (int j = 0; j < regionCount; j++) {
          if (find(j) == find(0)) {
            final dx = positions[i].x - positions[j].x;
            final dy = positions[i].y - positions[j].y;
            final d = math.sqrt(dx * dx + dy * dy);
            if (d < bestDist) {
              bestDist = d;
              bestJ = j;
            }
          }
        }
        _addEdge(adjacency, i, bestJ);
        union(i, bestJ);
      }
    }

    // Add a few extra cross-edges to make it harder
    final extraEdges = regionCount ~/ 3;
    int added = 0;
    for (int attempt = 0;
        attempt < regionCount * 5 && added < extraEdges;
        attempt++) {
      final a = _random.nextInt(regionCount);
      final b = _random.nextInt(regionCount);
      if (a != b && !adjacency[a]!.contains(b)) {
        // Only add if they are somewhat close
        final dx = positions[a].x - positions[b].x;
        final dy = positions[a].y - positions[b].y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < 0.45) {
          _addEdge(adjacency, a, b);
          added++;
        }
      }
    }

    final chromaticNumber = _greedyChromaticNumber(regions, adjacency);

    if (!forceSuccess && chromaticNumber > numColors) return null;

    return SectorPainterPuzzle(
      regions: regions,
      adjacency: adjacency,
      chromaticNumber: chromaticNumber,
      availableColors: math.max(numColors, chromaticNumber),
      positions: positions,
    );
  }

  /// Island chain: points scattered along a curved path
  void _scatterIslandChain(
      List<math.Point<double>> positions, int count) {
    final startAngle = _random.nextDouble() * math.pi * 0.5;
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final baseX = 0.15 + t * 0.7;
      final baseY =
          0.5 + 0.2 * math.sin(startAngle + t * math.pi * 1.5);
      final jitterX = (_random.nextDouble() - 0.5) * 0.1;
      final jitterY = (_random.nextDouble() - 0.5) * 0.1;
      positions.add(math.Point(
        (baseX + jitterX).clamp(0.05, 0.95),
        (baseY + jitterY).clamp(0.05, 0.95),
      ));
    }
  }

  /// Galaxy cluster: 2-3 clusters of points
  void _scatterGalaxyCluster(
      List<math.Point<double>> positions, int count) {
    final clusterCount = 2 + _random.nextInt(2); // 2 or 3
    final centers = <math.Point<double>>[];
    for (int c = 0; c < clusterCount; c++) {
      centers.add(math.Point(
        0.2 + _random.nextDouble() * 0.6,
        0.2 + _random.nextDouble() * 0.6,
      ));
    }

    for (int i = 0; i < count; i++) {
      final center = centers[i % clusterCount];
      final angle = _random.nextDouble() * 2 * math.pi;
      final radius = 0.05 + _random.nextDouble() * 0.15;
      positions.add(math.Point(
        (center.x + radius * math.cos(angle)).clamp(0.05, 0.95),
        (center.y + radius * math.sin(angle)).clamp(0.05, 0.95),
      ));
    }
  }

  /// Nebula cloud: scattered broadly with some clustering
  void _scatterNebulaCloud(
      List<math.Point<double>> positions, int count) {
    for (int i = 0; i < count; i++) {
      // Use normal-ish distribution via Box-Muller
      final u1 = _random.nextDouble();
      final u2 = _random.nextDouble();
      final r = math.sqrt(-2 * math.log(u1.clamp(0.001, 1.0)));
      final theta = 2 * math.pi * u2;
      positions.add(math.Point(
        (0.5 + r * math.cos(theta) * 0.18).clamp(0.05, 0.95),
        (0.5 + r * math.sin(theta) * 0.18).clamp(0.05, 0.95),
      ));
    }
  }

  /// Ring formation: points on a ring with some inner nodes
  void _scatterRingFormation(
      List<math.Point<double>> positions, int count) {
    final outerCount = (count * 0.7).ceil();
    final innerCount = count - outerCount;

    for (int i = 0; i < outerCount; i++) {
      final angle = (2 * math.pi * i) / outerCount;
      final radius = 0.32 + _random.nextDouble() * 0.06;
      positions.add(math.Point(
        0.5 + radius * math.cos(angle),
        0.5 + radius * math.sin(angle),
      ));
    }

    for (int i = 0; i < innerCount; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final radius = _random.nextDouble() * 0.15;
      positions.add(math.Point(
        (0.5 + radius * math.cos(angle)).clamp(0.1, 0.9),
        (0.5 + radius * math.sin(angle)).clamp(0.1, 0.9),
      ));
    }
  }

  /// Cross pattern: points along a + shape
  void _scatterCrossPattern(
      List<math.Point<double>> positions, int count) {
    final half = count ~/ 2;
    // Horizontal arm
    for (int i = 0; i < half; i++) {
      final t = i / (half - 1);
      positions.add(math.Point(
        (0.1 + t * 0.8).clamp(0.05, 0.95),
        (0.5 + (_random.nextDouble() - 0.5) * 0.08).clamp(0.1, 0.9),
      ));
    }
    // Vertical arm
    for (int i = 0; i < count - half; i++) {
      final t = i / ((count - half) - 1).clamp(1, count);
      positions.add(math.Point(
        (0.5 + (_random.nextDouble() - 0.5) * 0.08).clamp(0.1, 0.9),
        (0.1 + t * 0.8).clamp(0.05, 0.95),
      ));
    }
  }

  void _addEdge(Map<int, Set<int>> adj, int a, int b) {
    adj[a]!.add(b);
    adj[b]!.add(a);
  }

  int _greedyChromaticNumber(
      List<int> regions, Map<int, Set<int>> adjacency) {
    final coloring = <int, int>{};
    // Sort by degree (most constrained first) for better estimate
    final sorted = List<int>.from(regions);
    sorted.sort((a, b) =>
        (adjacency[b]?.length ?? 0).compareTo(adjacency[a]?.length ?? 0));

    for (final region in sorted) {
      final neighborColors = <int>{};
      for (final neighbor in adjacency[region] ?? <int>{}) {
        if (coloring.containsKey(neighbor)) {
          neighborColors.add(coloring[neighbor]!);
        }
      }
      int color = 0;
      while (neighborColors.contains(color)) {
        color++;
      }
      coloring[region] = color;
    }
    return coloring.values.toSet().length;
  }
}

class _Edge {
  final int a;
  final int b;
  final double dist;
  _Edge(this.a, this.b, this.dist);
}
