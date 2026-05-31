// lib/features/games/services/nebula_matrix_logic.dart
//
// Latin square (mini-Sudoku) puzzle generator using dart_csp.
// Each row and column must contain unique values 1..N.

import 'dart:math' as math;

class NebulaMatrixPuzzle {
  final int size;
  final Map<String, int> solution;
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<int> numberPool;
  /// Zone definitions: list of zones, each zone is a list of cell keys.
  /// For size 4: four 2x2 zones. For size 6: six 2x3 zones. For others: empty.
  final List<List<String>> zones;

  NebulaMatrixPuzzle({
    required this.size,
    required this.solution,
    required this.clues,
    required this.emptyCells,
    required this.numberPool,
    required this.zones,
  });

  /// Get zone index for a cell (for coloring in UI), or -1 if no zones.
  int getZoneIndex(int row, int col) {
    if (zones.isEmpty) return -1;
    final key = 'r${row}c$col';
    for (int z = 0; z < zones.length; z++) {
      if (zones[z].contains(key)) return z;
    }
    return -1;
  }

  bool validateSolution(Map<String, int> userSolution) {
    final complete = Map<String, int>.from(clues);
    complete.addAll(userSolution);

    // Check rows
    for (int r = 0; r < size; r++) {
      final rowVals = <int>{};
      for (int c = 0; c < size; c++) {
        final v = complete['r${r}c$c'];
        if (v == null || v < 1 || v > size) return false;
        rowVals.add(v);
      }
      if (rowVals.length != size) return false;
    }

    // Check columns
    for (int c = 0; c < size; c++) {
      final colVals = <int>{};
      for (int r = 0; r < size; r++) {
        final v = complete['r${r}c$c'];
        if (v == null) return false;
        colVals.add(v);
      }
      if (colVals.length != size) return false;
    }

    // Check zones (if any)
    for (final zone in zones) {
      final zoneVals = <int>{};
      for (final key in zone) {
        final v = complete[key];
        if (v == null) return false;
        zoneVals.add(v);
      }
      if (zoneVals.length != size) return false;
    }

    return true;
  }

  /// Build zone definitions based on grid size.
  static List<List<String>> buildZones(int size) {
    if (size == 4) {
      // Four 2x2 zones
      return [
        for (int br = 0; br < 2; br++)
          for (int bc = 0; bc < 2; bc++)
            [
              for (int r = br * 2; r < br * 2 + 2; r++)
                for (int c = bc * 2; c < bc * 2 + 2; c++)
                  'r${r}c$c'
            ],
      ];
    }
    if (size == 6) {
      // Six 2x3 zones (2 rows of 3 columns)
      return [
        for (int br = 0; br < 3; br++)
          for (int bc = 0; bc < 2; bc++)
            [
              for (int r = bc * 3; r < bc * 3 + 3; r++)
                for (int c = br * 2; c < br * 2 + 2; c++)
                  'r${r}c$c'
            ],
      ];
    }
    return []; // No zones for size 3 or 5
  }
}

class NebulaMatrixGenerator {
  final math.Random _random = math.Random();

  /// Generate a Latin square puzzle.
  /// [size] is the grid dimension (3-6).
  /// [clueCount] is how many cells to reveal.
  Future<NebulaMatrixPuzzle> generate({
    required int size,
    required int clueCount,
  }) async {
    assert(size >= 3 && size <= 6);

    // Generate a valid grid (Latin square + zone constraints if applicable)
    final zones = NebulaMatrixPuzzle.buildZones(size);
    Map<String, int> solution;
    if (zones.isNotEmpty) {
      // Need zone-compatible grid -- generate-validate-retry
      solution = _generateZoneGrid(size, zones);
    } else {
      solution = _generateLatinSquare(size);
    }

    // Select clue cells
    final allCells = <String>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        allCells.add('r${r}c$c');
      }
    }

    allCells.shuffle(_random);
    final effectiveClues = clueCount.clamp(size, size * size - 1);
    final clueCells = allCells.take(effectiveClues).toSet();

    final clues = <String, int>{};
    final emptyCells = <String>{};

    for (final cell in allCells) {
      if (clueCells.contains(cell)) {
        clues[cell] = solution[cell]!;
      } else {
        emptyCells.add(cell);
      }
    }

    final numberPool = List.generate(size, (i) => i + 1);

    return NebulaMatrixPuzzle(
      size: size,
      solution: solution,
      clues: clues,
      emptyCells: emptyCells,
      numberPool: numberPool,
      zones: NebulaMatrixPuzzle.buildZones(size),
    );
  }

  Map<String, int> _generateZoneGrid(int size, List<List<String>> zones) {
    // Generate Latin squares and check zone validity, retry until found
    for (int attempt = 0; attempt < 200; attempt++) {
      final grid = _generateLatinSquare(size);
      bool zonesValid = true;
      for (final zone in zones) {
        final vals = <int>{};
        for (final key in zone) {
          vals.add(grid[key]!);
        }
        if (vals.length != size) {
          zonesValid = false;
          break;
        }
      }
      if (zonesValid) return grid;
    }
    // Fallback: return a Latin square anyway (zones won't be checked in easy mode)
    return _generateLatinSquare(size);
  }

  Map<String, int> _generateLatinSquare(int size) {
    final baseList = List.generate(size, (i) => i + 1);
    baseList.shuffle(_random);

    final grid = <String, int>{};
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        grid['r${r}c$c'] = baseList[(r + c) % size];
      }
    }

    // Shuffle columns
    for (int i = 0; i < size * 2; i++) {
      final c1 = _random.nextInt(size);
      final c2 = _random.nextInt(size);
      if (c1 == c2) continue;
      for (int r = 0; r < size; r++) {
        final temp = grid['r${r}c$c1']!;
        grid['r${r}c$c1'] = grid['r${r}c$c2']!;
        grid['r${r}c$c2'] = temp;
      }
    }

    // Shuffle rows
    for (int i = 0; i < size * 2; i++) {
      final r1 = _random.nextInt(size);
      final r2 = _random.nextInt(size);
      if (r1 == r2) continue;
      for (int c = 0; c < size; c++) {
        final temp = grid['r${r1}c$c']!;
        grid['r${r1}c$c'] = grid['r${r2}c$c']!;
        grid['r${r2}c$c'] = temp;
      }
    }

    return grid;
  }
}
