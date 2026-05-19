// Contract test: every game class registered in the menu must call
// recordLevelWin somewhere in its source. Catches the class of bug where
// magic_triangles / path_finder used legacy `addScore` directly and
// never reported a win, leaving the mastery / 3-wins gate permanently
// stuck.
//
// Strategy: walk game_menu_screen.dart for class constructors invoked
// inside `gameBuilder:`, then check that each class's source contains
// a recordLevelWin( call. Dart convention is class FooGame in
// foo_game.dart — we map class → snake_case file under
// lib/features/games/screens/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _classToSnakeCase(String className) {
  final buf = StringBuffer();
  for (var i = 0; i < className.length; i++) {
    final c = className[i];
    if (c == c.toUpperCase() && c != c.toLowerCase()) {
      if (i > 0) buf.write('_');
      buf.write(c.toLowerCase());
    } else {
      buf.write(c);
    }
  }
  return buf.toString();
}

/// One-off overrides for class → file name mappings that don't follow
/// the strict snake_case-of-class-name convention.
const Map<String, String> _filenameOverrides = {
  'BlockCounterGame': 'blocks_counter_game', // plural in filename
  'ArithmeticSquareGame': 'arithmatic_square_game', // typo in filename
  'SolarPanelGame': 'solarpanel_game', // no underscore
};

void main() {
  test('every game class in the menu calls recordLevelWin', () {
    final menuFile =
        File('lib/features/games/screens/game_menu_screen.dart')
            .readAsStringSync();

    // Extract class names invoked inside gameBuilder: callbacks.
    // Patterns like:
    //   gameBuilder: (grade, level) => MagicTrianglesGame(grade: grade, ...)
    final regex = RegExp(
      r'gameBuilder:\s*\([^)]*\)\s*=>\s*(\w+Game)\s*\(',
    );
    final gameClasses = regex
        .allMatches(menuFile)
        .map((m) => m.group(1)!)
        .toSet();

    expect(gameClasses, isNotEmpty,
        reason: 'No game classes extracted from menu — regex drifted?');

    final missingFiles = <String>[];
    final missingRecordCalls = <String>[];

    for (final cls in gameClasses) {
      final filename = _filenameOverrides[cls] ?? _classToSnakeCase(cls);
      final path = 'lib/features/games/screens/$filename.dart';
      final file = File(path);
      if (!file.existsSync()) {
        missingFiles.add('$cls → $path (not found)');
        continue;
      }
      final source = file.readAsStringSync();
      // Accept either the legacy recordLevelWin(...) shim or the
      // canonical reportOutcome(GameOutcome.*(...)) form.
      if (!source.contains('recordLevelWin(') &&
          !source.contains('reportOutcome(')) {
        missingRecordCalls.add('$cls ($path)');
      }
    }

    expect(missingFiles, isEmpty,
        reason: 'Could not locate game source file for class(es): '
            '$missingFiles. Either rename the file to match the class '
            '(snake_case) or add an entry to _filenameOverrides above.');

    expect(missingRecordCalls, isEmpty,
        reason: 'Menu-registered game class(es) do not call '
            'recordLevelWin anywhere in their source: $missingRecordCalls. '
            'Without it, players can complete the game but global '
            'progression/scoring will not advance.');
  });
}
