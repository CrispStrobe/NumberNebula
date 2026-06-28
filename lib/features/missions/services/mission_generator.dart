// lib/features/missions/services/mission_generator.dart
//
// Generates a Mission: picks a codeword, assigns a game task per letter.

import 'dart:math';

import '../data/game_pool.dart';
import '../data/word_lists.dart';
import '../models/mission.dart';

class MissionGenerator {
  final Random _rng = Random();

  /// Generate a mission for the given grade, level, and locale.
  Mission generate({
    required int grade,
    required int level,
    required String locale,
  }) {
    final g = grade.clamp(1, 4);
    final words = spaceWords[locale]?[g] ?? spaceWords['en']![g]!;
    final codeword = words[_rng.nextInt(words.length)];

    final availableGames = gameBuilders.keys.toList();
    final tasks = <MissionTask>[];
    String? lastGame;

    for (int i = 0; i < codeword.length; i++) {
      // Pick a random game, avoiding consecutive duplicates
      String gameType;
      do {
        gameType = availableGames[_rng.nextInt(availableGames.length)];
      } while (gameType == lastGame && availableGames.length > 1);
      lastGame = gameType;

      tasks.add(MissionTask(
        gameType: gameType,
        grade: g,
        level: level.clamp(1, 20),
        letter: codeword[i],
      ));
    }

    final id = 'mission_${DateTime.now().millisecondsSinceEpoch}';

    return Mission(
      id: id,
      tasks: tasks,
      codeword: codeword,
      grade: g,
      level: level.clamp(1, 20),
    );
  }
}
