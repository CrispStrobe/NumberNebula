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


import 'package:flutter/services.dart' show AssetBundle, rootBundle;


import '../services/gridlock_level_data.dart';
export '../services/gridlock_level_data.dart' show GridlockPuzzleData, shipsFromBoard;

const String gridlockPuzzlesAsset = 'assets/puzzles/gridlock_puzzles.json';

class GridlockPuzzleDatabase extends GridlockLevelDatabase {
 GridlockPuzzleDatabase(super.puzzles);
 factory GridlockPuzzleDatabase.fromJson(String source) => GridlockPuzzleDatabase(GridlockLevelDatabase.fromJson(source).puzzles);
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

}
