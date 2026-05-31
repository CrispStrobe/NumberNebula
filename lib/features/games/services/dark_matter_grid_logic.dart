// lib/features/games/services/dark_matter_grid_logic.dart
//
// Lights Out puzzle generator. Starting from solved (all-lit) state,
// applies random toggles backward to guarantee solvability.

import 'dart:math' as math;

class DarkMatterGridPuzzle {
  final int size;
  final List<List<bool>> grid; // true = lit, false = dark
  final int minMoves; // approximate optimal solution length

  DarkMatterGridPuzzle({
    required this.size,
    required this.grid,
    required this.minMoves,
  });

  /// Toggle a cell and its orthogonal neighbors. Returns new grid state.
  static List<List<bool>> toggle(List<List<bool>> grid, int row, int col) {
    final size = grid.length;
    final newGrid = List.generate(size, (r) => List<bool>.from(grid[r]));
    final directions = [
      [0, 0],
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (final d in directions) {
      final nr = row + d[0];
      final nc = col + d[1];
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        newGrid[nr][nc] = !newGrid[nr][nc];
      }
    }
    return newGrid;
  }

  /// Check if all cells are lit.
  static bool isSolved(List<List<bool>> grid) {
    for (final row in grid) {
      for (final cell in row) {
        if (!cell) return false;
      }
    }
    return true;
  }

  /// Generate a solvable puzzle by starting from solved state and
  /// applying random toggles.
  static DarkMatterGridPuzzle generate({
    required int gridSize,
    required int toggleCount,
    int? seed,
  }) {
    final rng = math.Random(seed);

    // Start with all lit
    var grid = List.generate(gridSize, (_) => List.filled(gridSize, true));

    // Track which cells were toggled (each toggle is self-inverse,
    // so toggling same cell twice cancels out)
    final toggledCells = <String>{};

    int actualToggles = 0;
    int attempts = 0;
    while (actualToggles < toggleCount && attempts < toggleCount * 10) {
      attempts++;
      final r = rng.nextInt(gridSize);
      final c = rng.nextInt(gridSize);
      final key = '$r,$c';

      if (toggledCells.contains(key)) {
        // Toggle again = cancel, skip to keep puzzle interesting
        continue;
      }

      toggledCells.add(key);
      grid = toggle(grid, r, c);
      actualToggles++;
    }

    // If puzzle is already solved (unlikely but possible), add one more toggle
    if (isSolved(grid)) {
      final r = rng.nextInt(gridSize);
      final c = rng.nextInt(gridSize);
      grid = toggle(grid, r, c);
      actualToggles = 1;
    }

    return DarkMatterGridPuzzle(
      size: gridSize,
      grid: grid,
      minMoves: actualToggles,
    );
  }
}
