// Guards the set of games withheld from players.
//
// A key here is the only thing standing between a child and a game that cannot
// be completed, so a typo in it must fail loudly rather than quietly shipping
// the broken game.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/missions/data/game_pool.dart';

void main() {
  group('debugOnlyGames', () {
    test('every withheld key names a real game', () {
      for (final key in debugOnlyGames) {
        expect(gameBuilders.containsKey(key), isTrue,
            reason: '"$key" is withheld but no such game exists -- typo?');
        expect(gameTitles.containsKey(key), isTrue,
            reason: '"$key" has no title, so debug mode would show a raw key');
      }
    });

    test('withheld games are never picked for a mission', () {
      for (final key in debugOnlyGames) {
        expect(missionGameKeys, isNot(contains(key)));
        expect(calculationGames, isNot(contains(key)));
        expect(puzzleGames, isNot(contains(key)));
      }
    });

    test('missions still have enough games to draw from', () {
      // Missions ask for up to 6 tasks, split between calculation and puzzles.
      expect(calculationGames.length, greaterThanOrEqualTo(6));
      expect(puzzleGames.length, greaterThanOrEqualTo(6));
      // At least one hands-on puzzle must survive the exclusions, or every
      // mission degenerates into a list of grids to fill in.
      expect(puzzleGames.where(signaturePuzzleGames.contains), isNotEmpty);
    });

    test('isGamePlayable hides them only outside debug mode', () {
      for (final key in debugOnlyGames) {
        expect(isGamePlayable(key, debugEnabled: false), isFalse);
        expect(isGamePlayable(key, debugEnabled: true), isTrue);
      }
      // A working game is always playable.
      expect(isGamePlayable('alien_tribunal', debugEnabled: false), isTrue);
    });
  });
}
