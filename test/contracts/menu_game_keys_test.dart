// Contract test: every gameKey used in the menu has a corresponding entry
// in gameSkillMap. Catches the class of bug we hit with `solar_panel` vs
// `solarpanel_game` (menu key didn't match what callers sent into
// recordLevelWin → progression silently broken).
//
// Strategy: text-grep the menu file at test time rather than importing it
// (no need to set up a widget tester just for a const-extraction).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/models/skill_category.dart';

void main() {
  test('every menu gameKey resolves in gameSkillMap', () {
    final menuFile = File('lib/features/games/screens/game_menu_screen.dart')
        .readAsStringSync();
    final regex = RegExp(r"gameKey:\s*'([^']+)'");
    final menuKeys =
        regex.allMatches(menuFile).map((m) => m.group(1)!).toSet();

    expect(menuKeys, isNotEmpty,
        reason: 'No gameKey entries found — regex or file path drifted?');

    final missing = menuKeys.where((k) => !gameSkillMap.containsKey(k)).toSet();
    expect(missing, isEmpty,
        reason: 'Menu gameKey(s) not in gameSkillMap: $missing. '
            'Either add the entry to lib/core/models/skill_category.dart '
            'or correct the gameKey in game_menu_screen.dart.');
  });
}
