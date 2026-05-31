// lib/features/games/services/hive_station_logic.dart
//
// Hexagonal minesweeper variant.
// Cells show adjacent energy count; player marks which cells contain energy.

import 'dart:math' as math;

/// Axial coordinate for a hex cell.
class HexCoord {
  final int q;
  final int r;
  const HexCoord(this.q, this.r);

  @override
  bool operator ==(Object other) =>
      other is HexCoord && other.q == q && other.r == r;

  @override
  int get hashCode => q * 1000 + r;

  @override
  String toString() => '($q,$r)';

  /// The 6 hex neighbors in axial coordinates.
  List<HexCoord> get neighbors => [
        HexCoord(q + 1, r),
        HexCoord(q - 1, r),
        HexCoord(q, r + 1),
        HexCoord(q, r - 1),
        HexCoord(q + 1, r - 1),
        HexCoord(q - 1, r + 1),
      ];
}

class HiveStationPuzzle {
  /// All cells in the hex grid.
  final Set<HexCoord> allCells;

  /// Which cells contain energy (the "mines").
  final Set<HexCoord> energyCells;

  /// Number hints: cell -> count of adjacent energy cells.
  /// Only shown for non-energy cells (or for revealed hints).
  final Map<HexCoord, int> numberHints;

  /// Which cells have their hint revealed to the player.
  final Set<HexCoord> revealedHints;

  /// The "radius" parameter used to generate the grid.
  final int radius;

  HiveStationPuzzle({
    required this.allCells,
    required this.energyCells,
    required this.numberHints,
    required this.revealedHints,
    required this.radius,
  });

  bool validateSolution(Set<HexCoord> userMarked) {
    if (userMarked.length != energyCells.length) return false;
    return userMarked.every((c) => energyCells.contains(c));
  }
}

class HiveStationGenerator {
  final math.Random _random = math.Random();

  /// Generate a hex minesweeper puzzle.
  /// [radius] determines grid size: 1 = 7 cells, 2 = 19 cells, 3 = 37 cells.
  /// [energyFraction] fraction of cells that contain energy (0.2-0.4).
  /// [hintFraction] fraction of non-energy cells to reveal hints for.
  Future<HiveStationPuzzle> generate({
    required int radius,
    required double energyFraction,
    required double hintFraction,
  }) async {
    // Build hex grid
    final allCells = <HexCoord>{};
    for (int q = -radius; q <= radius; q++) {
      for (int r = -radius; r <= radius; r++) {
        if ((q + r).abs() <= radius) {
          allCells.add(HexCoord(q, r));
        }
      }
    }

    // Select energy cells
    final cellList = allCells.toList()..shuffle(_random);
    final energyCount = (allCells.length * energyFraction).round().clamp(1, allCells.length - 1);
    final energyCells = cellList.take(energyCount).toSet();

    // Compute number hints for all cells
    final numberHints = <HexCoord, int>{};
    for (final cell in allCells) {
      if (!energyCells.contains(cell)) {
        int count = 0;
        for (final n in cell.neighbors) {
          if (energyCells.contains(n)) count++;
        }
        numberHints[cell] = count;
      }
    }

    // Select which hints to reveal
    final hintCells = numberHints.keys.toList()..shuffle(_random);
    final revealCount = (hintCells.length * hintFraction).round().clamp(
      (allCells.length * 0.15).round(), // minimum hints
      hintCells.length,
    );
    final revealedHints = hintCells.take(revealCount).toSet();

    return HiveStationPuzzle(
      allCells: allCells,
      energyCells: energyCells,
      numberHints: numberHints,
      revealedHints: revealedHints,
      radius: radius,
    );
  }
}
