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

  NebulaMatrixPuzzle({
    required this.size,
    required this.solution,
    required this.clues,
    required this.emptyCells,
    required this.numberPool,
  });

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

    return true;
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

    // Generate a valid Latin square using shuffled construction
    final solution = _generateLatinSquare(size);

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
