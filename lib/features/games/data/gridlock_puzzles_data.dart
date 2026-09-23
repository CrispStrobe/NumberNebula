// gridlock_puzzles_data.dart
//
// The Space Station Gridlock puzzle database: 1313 puzzles from Michael
// Fogleman's Rush Hour Database, stored as the compact asset
// assets/puzzles/gridlock_puzzles.json and parsed on first use.
//
// Each puzzle is kept as its 36-character board string, row-major on the 6x6
// grid: 'o' is an empty cell, 'x' a fixed wall, 'A' the player ship and every
// other letter one ship. The ship list the game needs is derived from that
// string. This used to be a 2 MB generated Dart file that every player
// downloaded with the app, whether or not they ever opened this game.
//
// Difficulty mapping (Grades 1-4, Levels 1-20 each):
//   1.0 (Easy):     7-12 moves  → Grade 1, Levels 1-6
//   2.0 (Easy+):    13-17 moves → Grade 1 L7-14, Grade 2 L1-4
//   3.0 (Medium):   18-23 moves → Grade 1 L15-20, Grade 2 L5-13
//   4.0 (Medium+):  24-29 moves → Grade 2 L14-20, Grade 3 L1-12
//   5.0 (Hard):     30-36 moves → Grade 3 L13-19, Grade 4 L1-9
//   6.0 (Hard+):    37-44 moves → Grade 3 L20, Grade 4 L10-17
//   7.0 (Expert):   45+ moves   → Grade 4, Levels 18-20

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

const String gridlockPuzzlesAsset = 'assets/puzzles/gridlock_puzzles.json';
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
    (piece == 'A' ? player : isHorizontal ? horizontal : vertical).add(s);
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

class GridlockPuzzleDatabase {
  final List<GridlockPuzzleData> puzzles;

  GridlockPuzzleDatabase(this.puzzles);

  /// Parses the JSON produced for [gridlockPuzzlesAsset]:
  /// `{"puzzles": [[id, complexity, minMoves, board], ...]}`.
  factory GridlockPuzzleDatabase.fromJson(String source) {
    final rows = (jsonDecode(source) as Map<String, dynamic>)['puzzles'] as List;
    return GridlockPuzzleDatabase([
      for (final row in rows.cast<List>())
        GridlockPuzzleData(
          id: row[0] as String,
          complexity: (row[1] as num).toDouble(),
          minMoves: row[2] as int,
          originalBoard: row[3] as String,
        ),
    ]);
  }

  static Future<GridlockPuzzleDatabase>? _cached;

  /// Loads the bundled database once and reuses it for later games.
  static Future<GridlockPuzzleDatabase> load({AssetBundle? bundle}) {
    return _cached ??= (bundle ?? rootBundle)
        .loadString(gridlockPuzzlesAsset)
        .then(GridlockPuzzleDatabase.fromJson)
        .catchError((Object e) {
      _cached = null;
      throw e;
    });
  }

  List<GridlockPuzzleData> byComplexity(double complexity,
      {double tolerance = 0.0}) {
    return puzzles
        .where((p) => (p.complexity - complexity).abs() <= tolerance)
        .toList();
  }
}
