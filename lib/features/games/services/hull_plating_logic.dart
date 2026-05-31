// lib/features/games/services/hull_plating_logic.dart
import 'dart:math' as math;

/// A polyomino piece defined by its cell offsets from (0,0).
class PlatingPiece {
  final int id;
  final List<(int, int)> cells; // relative offsets
  final Color4 color;

  PlatingPiece({required this.id, required this.cells, required this.color});

  /// Rotate 90 degrees clockwise, returning a new piece.
  PlatingPiece rotated() {
    final rotated = cells.map((c) => (c.$2, -c.$1)).toList();
    // Normalize so min row and col are 0
    final minR = rotated.map((c) => c.$1).reduce(math.min);
    final minC = rotated.map((c) => c.$2).reduce(math.min);
    final normalized = rotated.map((c) => (c.$1 - minR, c.$2 - minC)).toList();
    return PlatingPiece(id: id, cells: normalized, color: color);
  }

  /// All 4 rotations of this piece.
  List<PlatingPiece> allRotations() {
    final rotations = <PlatingPiece>[this];
    var current = this;
    for (int i = 0; i < 3; i++) {
      current = current.rotated();
      // Check if this rotation is distinct from existing ones
      bool isDuplicate = false;
      for (final existing in rotations) {
        if (_sameCells(existing.cells, current.cells)) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) rotations.add(current);
    }
    return rotations;
  }

  static bool _sameCells(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }

  int get width {
    if (cells.isEmpty) return 0;
    return cells.map((c) => c.$2).reduce(math.max) + 1;
  }

  int get height {
    if (cells.isEmpty) return 0;
    return cells.map((c) => c.$1).reduce(math.max) + 1;
  }
}

/// Simple color index (mapped to actual colors in the UI).
enum Color4 { red, blue, green, yellow, cyan, purple }

/// A placed piece on the board.
class PlacedPiece {
  final int pieceId;
  final List<(int, int)> absoluteCells; // actual board positions

  PlacedPiece({required this.pieceId, required this.absoluteCells});

  bool covers(int row, int col) =>
      absoluteCells.any((c) => c.$1 == row && c.$2 == col);
}

class HullPlatingPuzzle {
  final int rows;
  final int cols;
  final List<List<bool>> board; // true = must be covered
  final List<PlatingPiece> pieces; // pieces to place
  final List<PlacedPiece> solution; // valid placement

  HullPlatingPuzzle({
    required this.rows,
    required this.cols,
    required this.board,
    required this.pieces,
    required this.solution,
  });

  int get activeCellCount {
    int count = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c]) count++;
      }
    }
    return count;
  }

  /// Check if a cell is dark on the checkerboard pattern (for visual only).
  static bool isDarkCell(int row, int col) => (row + col) % 2 == 0;

  /// Validate a complete placement covers all active cells with no overlaps.
  static bool validatePlacement(
    List<PlacedPiece> placed,
    List<List<bool>> board,
    int rows,
    int cols,
  ) {
    final covered = <String>{};
    for (final piece in placed) {
      for (final cell in piece.absoluteCells) {
        final key = '${cell.$1},${cell.$2}';
        if (covered.contains(key)) return false; // overlap
        if (cell.$1 < 0 || cell.$1 >= rows) return false;
        if (cell.$2 < 0 || cell.$2 >= cols) return false;
        if (!board[cell.$1][cell.$2]) return false; // placing on a hole
        covered.add(key);
      }
    }

    // All active cells must be covered
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c] && !covered.contains('$r,$c')) return false;
      }
    }
    return true;
  }

  /// Standard piece shapes (polyominoes).
  static final _dominoShape = [(0, 0), (0, 1)];
  static final _triShape = [(0, 0), (0, 1), (0, 2)]; // I-tromino
  static final _lTriShape = [(0, 0), (1, 0), (1, 1)]; // L-tromino
  static final _squareShape = [(0, 0), (0, 1), (1, 0), (1, 1)]; // square
  static final _tShape = [(0, 0), (0, 1), (0, 2), (1, 1)]; // T-tetromino
  static final _lShape = [(0, 0), (1, 0), (2, 0), (2, 1)]; // L-tetromino
  static final _sShape = [(0, 1), (0, 2), (1, 0), (1, 1)]; // S-tetromino
  static final _iShape = [(0, 0), (1, 0), (2, 0), (3, 0)]; // I-tetromino

  static HullPlatingPuzzle generate({
    required int grade,
    required int level,
    int? seed,
  }) {
    final rng = math.Random(seed);

    int rows, cols;
    List<List<(int, int)>> shapePool;

    if (grade <= 1) {
      rows = 3;
      cols = 4;
      // Only dominoes and L-trominoes for beginners
      shapePool = [_dominoShape, _dominoShape, _lTriShape, _triShape];
    } else if (grade <= 2) {
      rows = 4;
      cols = 4;
      shapePool = [_dominoShape, _lTriShape, _squareShape, _tShape, _triShape];
    } else {
      rows = 4;
      cols = 6;
      shapePool = [
        _dominoShape, _lTriShape, _squareShape,
        _tShape, _lShape, _sShape, _iShape,
      ];
    }

    // Build a full board (no holes at easy levels)
    final board = List.generate(rows, (_) => List.filled(cols, true));

    // Fill the board with random pieces using backtracking
    final solution = <PlacedPiece>[];
    final used = List.generate(rows, (_) => List.filled(cols, false));
    final pieces = <PlatingPiece>[];
    int pieceId = 0;

    const colors = Color4.values;

    bool fill() {
      // Find first uncovered cell
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (board[r][c] && !used[r][c]) {
            // Try each shape in random order
            final shuffledShapes = List<List<(int, int)>>.from(shapePool)
              ..shuffle(rng);

            for (final shape in shuffledShapes) {
              final piece = PlatingPiece(
                id: pieceId,
                cells: shape.toList(),
                color: colors[pieceId % colors.length],
              );

              // Try all rotations
              for (final rotated in piece.allRotations()) {
                // Try placing at each offset so the piece covers (r, c)
                for (final anchor in rotated.cells) {
                  final dr = r - anchor.$1;
                  final dc = c - anchor.$2;

                  final absoluteCells = rotated.cells
                      .map((cell) => (cell.$1 + dr, cell.$2 + dc))
                      .toList();

                  // Check if all cells are valid and uncovered
                  bool canPlace = true;
                  for (final ac in absoluteCells) {
                    if (ac.$1 < 0 || ac.$1 >= rows || ac.$2 < 0 ||
                        ac.$2 >= cols || !board[ac.$1][ac.$2] ||
                        used[ac.$1][ac.$2]) {
                      canPlace = false;
                      break;
                    }
                  }

                  if (canPlace) {
                    // Place the piece
                    for (final ac in absoluteCells) {
                      used[ac.$1][ac.$2] = true;
                    }
                    final placedPiece = PlacedPiece(
                      pieceId: pieceId,
                      absoluteCells: absoluteCells,
                    );
                    solution.add(placedPiece);
                    pieces.add(PlatingPiece(
                      id: pieceId,
                      cells: rotated.cells.toList(),
                      color: colors[pieceId % colors.length],
                    ));
                    pieceId++;

                    if (fill()) return true;

                    // Backtrack
                    pieceId--;
                    solution.removeLast();
                    pieces.removeLast();
                    for (final ac in absoluteCells) {
                      used[ac.$1][ac.$2] = false;
                    }
                  }
                }
              }
            }

            // No piece fits here -- backtrack
            return false;
          }
        }
      }
      // All cells covered!
      return true;
    }

    fill();

    return HullPlatingPuzzle(
      rows: rows,
      cols: cols,
      board: board,
      pieces: pieces..shuffle(rng), // shuffle so player doesn't see solution order
      solution: solution,
    );
  }
}
