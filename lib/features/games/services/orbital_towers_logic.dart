// lib/features/games/services/orbital_towers_logic.dart
//
// Skyscraper puzzle generator.
// Place heights 1-N in a Latin square. Edge clues show how many towers
// are visible from that direction (taller towers block shorter ones).

import 'dart:math' as math;

class OrbitalTowersPuzzle {
  final int size;

  /// Full solution grid: 'r{row}c{col}' -> height (1..size)
  final Map<String, int> solution;

  /// Clue cells given to the player.
  final Map<String, int> clues;

  /// Empty cells the player must fill.
  final Set<String> emptyCells;

  /// Edge clues: 'top_c', 'bottom_c', 'left_r', 'right_r' -> visible count.
  /// Some may be null (hidden).
  final Map<String, int> edgeClues;

  /// Available numbers for drag/drop.
  final List<int> numberPool;

  OrbitalTowersPuzzle({
    required this.size,
    required this.solution,
    required this.clues,
    required this.emptyCells,
    required this.edgeClues,
    required this.numberPool,
  });

  bool validateSolution(Map<String, int> userSolution) {
    final complete = Map<String, int>.from(clues);
    complete.addAll(userSolution);

    // Check Latin square property
    for (int r = 0; r < size; r++) {
      final rowVals = <int>{};
      for (int c = 0; c < size; c++) {
        final v = complete['r${r}c$c'];
        if (v == null || v < 1 || v > size) return false;
        rowVals.add(v);
      }
      if (rowVals.length != size) return false;
    }
    for (int c = 0; c < size; c++) {
      final colVals = <int>{};
      for (int r = 0; r < size; r++) {
        final v = complete['r${r}c$c'];
        if (v == null) return false;
        colVals.add(v);
      }
      if (colVals.length != size) return false;
    }

    // Check edge clues
    for (final entry in edgeClues.entries) {
      final key = entry.key;
      final expected = entry.value;
      final parts = key.split('_');
      final dir = parts[0];
      final idx = int.parse(parts[1]);

      List<int> line;
      if (dir == 'top') {
        line = List.generate(size, (r) => complete['r${r}c$idx']!);
      } else if (dir == 'bottom') {
        line = List.generate(size, (r) => complete['r${size - 1 - r}c$idx']!);
      } else if (dir == 'left') {
        line = List.generate(size, (c) => complete['r${idx}c$c']!);
      } else {
        line = List.generate(size, (c) => complete['r${idx}c${size - 1 - c}']!);
      }

      if (_countVisible(line) != expected) return false;
    }

    return true;
  }

  /// Which towers along [line] the camera at its near end can see: a tower is
  /// visible only when nothing taller stands in front of it.
  ///
  /// Public so the onboarding diagram can illustrate the same rule the puzzle
  /// is scored by, instead of a hand-drawn copy of it that could drift.
  static List<bool> visibilityAlongLine(List<int> line) {
    final visible = <bool>[];
    int maxSeen = 0;
    for (final h in line) {
      final isVisible = h > maxSeen;
      if (isVisible) maxSeen = h;
      visible.add(isVisible);
    }
    return visible;
  }

  static int _countVisible(List<int> line) =>
      visibilityAlongLine(line).where((v) => v).length;
}

class OrbitalTowersGenerator {
  final math.Random _random = math.Random();

  /// Generate a skyscraper puzzle.
  /// [size] grid dimension (3-5).
  /// [edgeClueCount] how many edge clues to show.
  /// [cellClueCount] how many cell values to pre-fill.
  Future<OrbitalTowersPuzzle> generate({
    required int size,
    required int edgeClueCount,
    required int cellClueCount,
  }) async {
    assert(size >= 3 && size <= 5);

    // Generate a valid Latin square
    final solution = _generateLatinSquare(size);

    // Compute all edge clues
    final allEdgeClues = <String, int>{};

    for (int c = 0; c < size; c++) {
      final topLine = List.generate(size, (r) => solution['r${r}c$c']!);
      allEdgeClues['top_$c'] = OrbitalTowersPuzzle._countVisible(topLine);

      final bottomLine = List.generate(size, (r) => solution['r${size - 1 - r}c$c']!);
      allEdgeClues['bottom_$c'] = OrbitalTowersPuzzle._countVisible(bottomLine);
    }

    for (int r = 0; r < size; r++) {
      final leftLine = List.generate(size, (c) => solution['r${r}c$c']!);
      allEdgeClues['left_$r'] = OrbitalTowersPuzzle._countVisible(leftLine);

      final rightLine = List.generate(size, (c) => solution['r${r}c${size - 1 - c}']!);
      allEdgeClues['right_$r'] = OrbitalTowersPuzzle._countVisible(rightLine);
    }

    // Select which edge clues to show
    final edgeKeys = allEdgeClues.keys.toList()..shuffle(_random);
    final shownEdgeClues = <String, int>{};
    final effectiveEdgeCount = edgeClueCount.clamp(size, size * 4);
    for (final key in edgeKeys.take(effectiveEdgeCount)) {
      shownEdgeClues[key] = allEdgeClues[key]!;
    }

    // Select cell clues
    final allCells = <String>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        allCells.add('r${r}c$c');
      }
    }
    allCells.shuffle(_random);

    final effectiveCellClues = cellClueCount.clamp(0, size * size - 1);
    final clueCells = allCells.take(effectiveCellClues).toSet();

    final clues = <String, int>{};
    final emptyCells = <String>{};
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cell = 'r${r}c$c';
        if (clueCells.contains(cell)) {
          clues[cell] = solution[cell]!;
        } else {
          emptyCells.add(cell);
        }
      }
    }

    final numberPool = List.generate(size, (i) => i + 1);

    return OrbitalTowersPuzzle(
      size: size,
      solution: solution,
      clues: clues,
      emptyCells: emptyCells,
      edgeClues: shownEdgeClues,
      numberPool: numberPool,
    );
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

    // Shuffle columns and rows
    for (int i = 0; i < size * 3; i++) {
      final c1 = _random.nextInt(size);
      final c2 = _random.nextInt(size);
      if (c1 != c2) {
        for (int r = 0; r < size; r++) {
          final t = grid['r${r}c$c1']!;
          grid['r${r}c$c1'] = grid['r${r}c$c2']!;
          grid['r${r}c$c2'] = t;
        }
      }

      final r1 = _random.nextInt(size);
      final r2 = _random.nextInt(size);
      if (r1 != r2) {
        for (int c = 0; c < size; c++) {
          final t = grid['r${r1}c$c']!;
          grid['r${r1}c$c'] = grid['r${r2}c$c']!;
          grid['r${r2}c$c'] = t;
        }
      }
    }

    return grid;
  }
}
