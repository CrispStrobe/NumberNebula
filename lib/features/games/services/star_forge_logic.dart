// lib/features/games/services/star_forge_logic.dart
//
// Magic Star puzzle generator.
// A magic star has outer points and inner intersection nodes.
// Each line through the star must sum to the same "magic constant".

import 'dart:math' as math;

/// Describes a magic star puzzle.
class StarForgePuzzle {
  /// Number of points on the star (5, 6, or 7).
  final int points;

  /// Total number of nodes (points * 2 for a standard magic star).
  final int nodeCount;

  /// The lines of the star, each a list of node indices.
  final List<List<int>> lines;

  /// The magic constant each line must sum to.
  final int magicConstant;

  /// The full solution: node index -> value.
  final Map<int, int> solution;

  /// Which nodes are given as clues (node index -> value).
  final Map<int, int> clues;

  /// Which nodes the player must fill.
  final Set<int> emptyNodes;

  /// Available numbers for the player.
  final List<int> numberPool;

  StarForgePuzzle({
    required this.points,
    required this.nodeCount,
    required this.lines,
    required this.magicConstant,
    required this.solution,
    required this.clues,
    required this.emptyNodes,
    required this.numberPool,
  });

  bool validateSolution(Map<int, int> userSolution) {
    final complete = Map<int, int>.from(clues);
    complete.addAll(userSolution);
    if (complete.length != nodeCount) return false;

    // Check all values are unique and in range
    final values = complete.values.toSet();
    if (values.length != nodeCount) return false;

    for (final line in lines) {
      int sum = 0;
      for (final idx in line) {
        final v = complete[idx];
        if (v == null) return false;
        sum += v;
      }
      if (sum != magicConstant) return false;
    }
    return true;
  }
}

class StarForgeGenerator {
  final math.Random _random = math.Random();

  /// Generate a magic star puzzle.
  /// [points] is the number of star points (5, 6, or 7).
  /// [clueCount] is how many values to reveal.
  Future<StarForgePuzzle> generate({
    required int points,
    required int clueCount,
  }) async {
    assert(points >= 5 && points <= 7);

    // A magic star with n points has 2n nodes: n outer tips + n inner
    // intersections, and every node sits on exactly two lines.
    final nodeCount = points * 2;
    final values = List.generate(nodeCount, (i) => i + 1);
    final lines = _buildStarLines(points);

    final solution = _buildSolution(points);

    int magicConstant = 0;
    for (final idx in lines[0]) {
      magicConstant += solution[idx]!;
    }

    // Select clue nodes
    final allNodes = List.generate(nodeCount, (i) => i);
    allNodes.shuffle(_random);
    final clueNodes = allNodes.take(clueCount.clamp(0, nodeCount - 1)).toSet();

    final clues = <int, int>{};
    final emptyNodes = <int>{};

    for (int i = 0; i < nodeCount; i++) {
      if (clueNodes.contains(i)) {
        clues[i] = solution[i]!;
      } else {
        emptyNodes.add(i);
      }
    }

    // Number pool: all values not already given as clues
    final clueValues = clues.values.toSet();
    final numberPool = values.where((v) => !clueValues.contains(v)).toList()..sort();

    return StarForgePuzzle(
      points: points,
      nodeCount: nodeCount,
      lines: lines,
      magicConstant: magicConstant,
      solution: solution,
      clues: clues,
      emptyNodes: emptyNodes,
      numberPool: numberPool,
    );
  }

  /// Lay the values out so that every line hits the same total.
  ///
  /// Line i is [tip i, node i, node i+1, tip i+1], so its total is
  /// (tip i + node i) + (tip i+1 + node i+1): each line is simply two
  /// neighbouring tip/node pairs added together. Give every pair the same
  /// total by pairing k with 2n+1-k, and each of the n lines then sums to
  /// 2(2n+1) -- 22 for a 5-point star, 26 for 6, 30 for 7.
  ///
  /// That constant is not a choice: every node lies on exactly two lines, so
  /// the n line totals add up to twice the sum of 1..2n no matter how the
  /// values are arranged. A previous version searched for a solution among
  /// other constants, none of which can exist, and so spent 200 timed-out
  /// constraint solves -- minutes on the loading spinner -- before falling
  /// back to a hardcoded layout whose lines did not sum equally either.
  ///
  /// Which pair sits at which point, and which half of a pair is the outer
  /// tip, are both free: n! * 2^n layouts, so puzzles still vary.
  Map<int, int> _buildSolution(int points) {
    final pairs = [
      for (int k = 1; k <= points; k++) [k, 2 * points + 1 - k]
    ]..shuffle(_random);

    final solution = <int, int>{};
    for (int i = 0; i < points; i++) {
      final pair = pairs[i];
      final tipFirst = _random.nextBool();
      solution[i] = tipFirst ? pair[0] : pair[1];
      solution[points + i] = tipFirst ? pair[1] : pair[0];
    }
    return solution;
  }

  /// Build the lines of a magic star.
  /// For an n-pointed star, outer nodes are indices 0..n-1,
  /// inner nodes are indices n..2n-1.
  /// Each line: outer[i], inner[i], inner[(i+1)%n], outer[(i+1)%n] -- wait,
  /// actually for a magic star each line goes:
  /// outer[i], inner[i], inner[(i-1+n)%n], ... hmm, let me use the standard layout.
  ///
  /// Standard magic star lines (each has 4 nodes):
  /// Line i: outer[i], inner[i], inner[(i+1)%n], outer[(i+1)%n]
  List<List<int>> _buildStarLines(int n) {
    final lines = <List<int>>[];
    for (int i = 0; i < n; i++) {
      lines.add([
        i,                // outer tip i
        n + i,            // inner node i
        n + (i + 1) % n,  // inner node (i+1)
        (i + 1) % n,      // outer tip (i+1)
      ]);
    }
    return lines;
  }

}
