// lib/features/games/services/hull_plating_logic.dart
import 'dart:math' as math;

/// Represents a domino piece (1x2 tile) covering two cells.
class Domino {
  final int id;
  final (int, int) cell1;
  final (int, int) cell2;

  Domino({required this.id, required this.cell1, required this.cell2});

  bool covers(int row, int col) {
    return (cell1.$1 == row && cell1.$2 == col) ||
        (cell2.$1 == row && cell2.$2 == col);
  }
}

class HullPlatingPuzzle {
  final int rows;
  final int cols;
  final List<List<bool>> board; // true = cell must be covered, false = hole
  final List<Domino> solution;
  final int dominoCount;

  HullPlatingPuzzle({
    required this.rows,
    required this.cols,
    required this.board,
    required this.solution,
    required this.dominoCount,
  });

  /// Check if a cell is dark on the checkerboard pattern.
  static bool isDarkCell(int row, int col) {
    return (row + col) % 2 == 0;
  }

  /// Validate that all placed dominoes cover the board correctly.
  /// Each domino must cover exactly one dark and one light cell.
  static bool validatePlacement(
    List<Domino> placed,
    List<List<bool>> board,
    int rows,
    int cols,
  ) {
    // Check that each domino covers one dark and one light cell
    for (final domino in placed) {
      final dark1 = isDarkCell(domino.cell1.$1, domino.cell1.$2);
      final dark2 = isDarkCell(domino.cell2.$1, domino.cell2.$2);
      if (dark1 == dark2) return false; // Both same color = invalid

      // Check cells are adjacent
      final dr = (domino.cell1.$1 - domino.cell2.$1).abs();
      final dc = (domino.cell1.$2 - domino.cell2.$2).abs();
      if (dr + dc != 1) return false; // Not adjacent

      // Check cells are on the board and not holes
      if (!_inBounds(domino.cell1.$1, domino.cell1.$2, rows, cols)) return false;
      if (!_inBounds(domino.cell2.$1, domino.cell2.$2, rows, cols)) return false;
      if (!board[domino.cell1.$1][domino.cell1.$2]) return false;
      if (!board[domino.cell2.$1][domino.cell2.$2]) return false;
    }

    // Check all active cells are covered exactly once
    final covered = <String>{};
    for (final domino in placed) {
      final k1 = '${domino.cell1.$1},${domino.cell1.$2}';
      final k2 = '${domino.cell2.$1},${domino.cell2.$2}';
      if (covered.contains(k1) || covered.contains(k2)) return false; // Overlap
      covered.add(k1);
      covered.add(k2);
    }

    // Check all active cells are covered
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c] && !covered.contains('$r,$c')) return false;
      }
    }

    return true;
  }

  static bool _inBounds(int r, int c, int rows, int cols) {
    return r >= 0 && r < rows && c >= 0 && c < cols;
  }

  /// Generate a hull plating puzzle.
  static HullPlatingPuzzle generate({
    required int grade,
    required int level,
    int? seed,
  }) {
    final random = math.Random(seed);

    int rows, cols;
    bool useHoles;

    if (grade <= 1) {
      rows = 2;
      cols = 3;
      useHoles = false;
    } else if (grade <= 2) {
      rows = 4;
      cols = 4;
      useHoles = false;
    } else {
      rows = 6;
      cols = 6;
      useHoles = true;
    }

    // Create the board
    final board = List.generate(rows, (_) => List.filled(cols, true));

    // Add irregular holes for higher grades
    if (useHoles) {
      // Remove a few cells while keeping the board tileable
      // We must remove cells in pairs (one dark, one light) to keep tileability
      final pairsToRemove = 1 + random.nextInt(3); // 1-3 pairs of holes
      for (int p = 0; p < pairsToRemove; p++) {
        // Find a random dark cell and an adjacent light cell to remove
        final candidates = <(int, int, int, int)>[]; // (r1, c1, r2, c2)
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (!board[r][c]) continue;
            // Check neighbors
            for (final (dr, dc) in [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && board[nr][nc]) {
                // Ensure we remove one dark and one light
                if (isDarkCell(r, c) != isDarkCell(nr, nc)) {
                  candidates.add((r, c, nr, nc));
                }
              }
            }
          }
        }

        if (candidates.isNotEmpty) {
          final pick = candidates[random.nextInt(candidates.length)];
          board[pick.$1][pick.$2] = false;
          board[pick.$3][pick.$4] = false;
        }
      }
    }

    // Count active cells
    int activeCells = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c]) activeCells++;
      }
    }

    // Generate a valid tiling solution using greedy matching
    final solution = _generateSolution(board, rows, cols, random);
    final dominoCount = activeCells ~/ 2;

    return HullPlatingPuzzle(
      rows: rows,
      cols: cols,
      board: board,
      solution: solution,
      dominoCount: dominoCount,
    );
  }

  /// Generate a valid domino tiling using randomized greedy matching.
  static List<Domino> _generateSolution(
    List<List<bool>> board,
    int rows,
    int cols,
    math.Random random,
  ) {
    final used = List.generate(rows, (_) => List.filled(cols, false));
    final dominoes = <Domino>[];
    int id = 0;

    // Collect all possible domino placements
    final placements = <(int, int, int, int)>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!board[r][c]) continue;
        // Right neighbor
        if (c + 1 < cols && board[r][c + 1]) {
          placements.add((r, c, r, c + 1));
        }
        // Down neighbor
        if (r + 1 < rows && board[r + 1][c]) {
          placements.add((r, c, r + 1, c));
        }
      }
    }

    placements.shuffle(random);

    for (final (r1, c1, r2, c2) in placements) {
      if (!used[r1][c1] && !used[r2][c2]) {
        used[r1][c1] = true;
        used[r2][c2] = true;
        dominoes.add(Domino(
          id: id++,
          cell1: (r1, c1),
          cell2: (r2, c2),
        ));
      }
    }

    return dominoes;
  }
}
