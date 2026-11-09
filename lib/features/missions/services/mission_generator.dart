// lib/features/missions/services/mission_generator.dart
//
// Generates a Mission: picks a codeword and a balanced, duplicate-free set of
// mini-games to earn its letters.
//
// A mission is meant to feel like a varied training run, not a random draw:
//   * no mini-game appears twice,
//   * 2-3 tasks are calculation practice and 2-3 are puzzle/logic play,
//   * at least one of the hands-on signature puzzles (sokoban, atomix,
//     rush-hour, …) is always in the set,
//   * the codeword's letters are spread across the tasks, so a long word
//     doesn't turn into a twelve-game marathon.

import 'dart:math';

import '../data/game_pool.dart';
import '../data/word_lists.dart';
import '../models/mission.dart';

/// Number of tasks per mission, by grade. Always 4-6, always splittable into
/// 2-3 calculation games plus 2-3 puzzles.
int missionTaskCountForGrade(int grade) {
  if (grade <= 2) return 4;
  if (grade == 3) return 5;
  return 6;
}

class MissionGenerator {
  final Random _rng;

  MissionGenerator({Random? random}) : _rng = random ?? Random();

  /// Generate a mission for the given grade, level, and locale.
  ///
  /// [gameProgress] maps gameKey to the player's level in that game; when it
  /// is supplied each task is set at the level the player actually plays that
  /// game at, instead of one blanket level for the whole mission.
  Mission generate({
    required int grade,
    required int level,
    required String locale,
    Map<String, int>? gameProgress,
  }) {
    final g = grade.clamp(1, 4);
    final baseLevel = level.clamp(1, 20);

    final words = spaceWords[locale]?[g] ?? spaceWords['en']![g]!;
    // Words shorter than four letters can't cover a full task list.
    final usable = words.where((w) => w.length >= 4).toList();
    final pool = usable.isEmpty ? words : usable;
    final codeword = pool[_rng.nextInt(pool.length)];

    final taskCount =
        min(missionTaskCountForGrade(g), codeword.length);
    final gameTypes = _pickGames(taskCount);
    final letterGroups = _splitLetters(codeword, taskCount);

    final tasks = <MissionTask>[];
    for (int i = 0; i < taskCount; i++) {
      final gameType = gameTypes[i];
      final gameLevel = gameProgress?[gameType] ?? baseLevel;
      tasks.add(MissionTask(
        gameType: gameType,
        grade: g,
        level: gameLevel.clamp(1, 20),
        letters: letterGroups[i],
      ));
    }

    final id = 'mission_${DateTime.now().millisecondsSinceEpoch}';

    return Mission(
      id: id,
      tasks: tasks,
      codeword: codeword,
      grade: g,
      level: baseLevel,
    );
  }

  /// Pick [count] distinct games: roughly half calculation, half puzzle, with
  /// at least one signature puzzle, then shuffled so the two kinds interleave
  /// unpredictably.
  List<String> _pickGames(int count) {
    // 4 tasks -> 2 calc, 5 -> 2 or 3, 6 -> 3.
    final minCalc = count ~/ 3;
    final calcCount = (count ~/ 2 + (count.isOdd ? _rng.nextInt(2) : 0))
        .clamp(minCalc, count - minCalc);
    final puzzleCount = count - calcCount;

    final calcPool = calculationGames..shuffle(_rng);
    final puzzlePool = puzzleGames..shuffle(_rng);

    final picked = <String>[];
    picked.addAll(calcPool.take(calcCount));

    // Seed the puzzle half with a signature puzzle so every mission has at
    // least one hands-on game to play with.
    final signatures =
        puzzlePool.where(signaturePuzzleGames.contains).toList();
    if (puzzleCount > 0 && signatures.isNotEmpty) {
      picked.add(signatures.first);
    }
    for (final game in puzzlePool) {
      if (picked.length >= count) break;
      if (!picked.contains(game)) picked.add(game);
    }
    // Only if a pool was too small to fill its share: top up from anything
    // left so the mission still has the requested number of tasks.
    if (picked.length < count) {
      for (final game in missionGameKeys) {
        if (picked.length >= count) break;
        if (!picked.contains(game)) picked.add(game);
      }
    }

    final result = picked.take(count).toList()..shuffle(_rng);
    return result;
  }

  /// Spread [word]'s letters across [groups] tasks, front-loading the
  /// remainder so early tasks reveal a little more.
  List<String> _splitLetters(String word, int groups) {
    if (groups <= 0) return const [];
    final base = word.length ~/ groups;
    final remainder = word.length % groups;

    final result = <String>[];
    int cursor = 0;
    for (int i = 0; i < groups; i++) {
      final take = base + (i < remainder ? 1 : 0);
      result.add(word.substring(cursor, cursor + take));
      cursor += take;
    }
    return result;
  }
}
