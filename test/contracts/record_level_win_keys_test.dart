// Contract test: every gameType string passed into recordLevelWin has a
// matching entry in gameSkillMap. Catches the class of bug where a game
// calls recordLevelWin with a key the provider can't resolve — the call
// returns false silently and progression stops working.
//
// We approximate "gameType arg in any source file" by grepping for
// `gameType: 'foo'` literals. Tight enough in this codebase that there are
// no false positives.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/models/skill_category.dart';

void main() {
  test('every gameType: literal across the codebase is in gameSkillMap', () {
    final regex = RegExp(r"gameType:\s*'([^']+)'");
    final usedKeys = <String>{};

    final libDir = Directory('lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final m in regex.allMatches(content)) {
        usedKeys.add(m.group(1)!);
      }
    }

    expect(usedKeys, isNotEmpty,
        reason: 'No gameType: literals found in lib/ — regex drifted?');

    final missing =
        usedKeys.where((k) => !gameSkillMap.containsKey(k)).toSet();
    expect(missing, isEmpty,
        reason: 'gameType key(s) used at call sites but not in gameSkillMap: '
            '$missing. recordLevelWin will silently return false and '
            'progression will not advance.');
  });
}
