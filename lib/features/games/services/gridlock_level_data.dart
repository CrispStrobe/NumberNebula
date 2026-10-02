import 'dart:convert';

const int _gridSize = 6;

class GridlockPuzzleData {
  final String id;
  final double complexity;
  final int minMoves;
  final String originalBoard;

  /// Ship configurations in the order the game assigns colours: the player
  /// ship, then horizontal ships by (row, col), then vertical ships by
  /// (col, row), then walls by (row, col).
  late final List<Map<String, dynamic>> ships = shipsFromBoard(originalBoard);

  GridlockPuzzleData({
    required this.id,
    required this.complexity,
    required this.minMoves,
    required this.originalBoard,
  });
}

/// Derives the ship list from a 36-character Rush Hour board string.
List<Map<String, dynamic>> shipsFromBoard(String board) {
  if (board.length != _gridSize * _gridSize) {
    throw FormatException('Gridlock board must have 36 cells', board);
  }

  final cellsByPiece = <String, List<int>>{};
  for (int i = 0; i < board.length; i++) {
    final c = board[i];
    if (c == 'o' || c == '.') continue;
    cellsByPiece.putIfAbsent(c, () => []).add(i);
  }

  Map<String, dynamic> ship(int row, int col, int length, bool horizontal,
          {bool player = false, bool blocking = false}) =>
      {
        'row': row,
        'col': col,
        'length': length,
        'isHorizontal': horizontal,
        'isPlayer': player,
        'isBlocking': blocking,
      };

  final player = <Map<String, dynamic>>[];
  final horizontal = <Map<String, dynamic>>[];
  final vertical = <Map<String, dynamic>>[];
  final walls = <Map<String, dynamic>>[];

  cellsByPiece.forEach((piece, cells) {
    if (piece == 'x') {
      for (final i in cells) {
        walls.add(ship(i ~/ _gridSize, i % _gridSize, 1, true, blocking: true));
      }
      return;
    }
    // Cells are collected in index order, so the first is the top-left one.
    final row = cells.first ~/ _gridSize;
    final col = cells.first % _gridSize;
    final isHorizontal = cells.every((i) => i ~/ _gridSize == row);
    final s = ship(row, col, cells.length, isHorizontal, player: piece == 'A');
    (piece == 'A'
            ? player
            : isHorizontal
                ? horizontal
                : vertical)
        .add(s);
  });

  int byRowCol(Map<String, dynamic> a, Map<String, dynamic> b) {
    final r = (a['row'] as int).compareTo(b['row'] as int);
    return r != 0 ? r : (a['col'] as int).compareTo(b['col'] as int);
  }

  horizontal.sort(byRowCol);
  vertical.sort((a, b) {
    final c = (a['col'] as int).compareTo(b['col'] as int);
    return c != 0 ? c : (a['row'] as int).compareTo(b['row'] as int);
  });
  walls.sort(byRowCol);

  return [...player, ...horizontal, ...vertical, ...walls];
}

class GridlockLevelDatabase {
  final List<GridlockPuzzleData> puzzles;

  GridlockLevelDatabase(this.puzzles);

  /// Parses the JSON produced for [gridlockPuzzlesAsset]:
  /// `{"puzzles": [[id, complexity, minMoves, board], ...]}`.
  factory GridlockLevelDatabase.fromJson(String source) {
    final rows =
        (jsonDecode(source) as Map<String, dynamic>)['puzzles'] as List;
    return GridlockLevelDatabase([
      for (final row in rows.cast<List>())
        GridlockPuzzleData(
          id: row[0] as String,
          complexity: (row[1] as num).toDouble(),
          minMoves: row[2] as int,
          originalBoard: row[3] as String,
        ),
    ]);
  }

  List<GridlockPuzzleData> byComplexity(double complexity,
      {double tolerance = 0.0}) {
    return puzzles
        .where((p) => (p.complexity - complexity).abs() <= tolerance)
        .toList();
  }
}
