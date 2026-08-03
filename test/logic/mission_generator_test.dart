// Contract tests for mission generation.
//
// A mission must never repeat a mini-game, must mix calculation practice with
// puzzle play (2-3 of each), and must always include at least one hands-on
// signature puzzle (sokoban, atomix, rush-hour, …).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:space_math_academy/core/models/skill_category.dart';
import 'package:space_math_academy/features/missions/data/game_pool.dart';
import 'package:space_math_academy/features/missions/models/mission.dart';
import 'package:space_math_academy/features/missions/services/mission_generator.dart';

int _calcCount(Mission m) => m.tasks
    .where((t) => gameSkillMap[t.gameType] == SkillCategory.arithmetic)
    .length;

int _puzzleCount(Mission m) => m.tasks.length - _calcCount(m);

void main() {
  group('MissionGenerator', () {
    // A fixed seed keeps failures reproducible; the loops still cover a wide
    // spread of codewords and game draws.
    final generator = MissionGenerator(random: Random(20260801));

    for (final locale in ['en', 'de']) {
      for (int grade = 1; grade <= 4; grade++) {
        test('grade $grade / $locale missions are well formed', () {
          for (int i = 0; i < 50; i++) {
            final mission = generator.generate(
              grade: grade,
              level: 5,
              locale: locale,
            );

            // No duplicate mini-games.
            final types = mission.tasks.map((t) => t.gameType).toList();
            expect(types.toSet().length, types.length,
                reason: 'duplicate game in $types');

            // Every game is actually playable.
            for (final type in types) {
              expect(gameBuilders.containsKey(type), isTrue,
                  reason: 'unknown game $type');
            }

            // 4-6 tasks, mixing 2-3 calculation games with 2-3 puzzles.
            expect(mission.tasks.length, inInclusiveRange(4, 6));
            expect(_calcCount(mission), inInclusiveRange(2, 3),
                reason: 'calculation games in $types');
            expect(_puzzleCount(mission), inInclusiveRange(2, 3),
                reason: 'puzzle games in $types');

            // At least one hands-on signature puzzle.
            expect(types.any(signaturePuzzleGames.contains), isTrue,
                reason: 'no signature puzzle in $types');

            // The tasks' letters reconstruct the codeword exactly.
            expect(mission.tasks.map((t) => t.letters).join(),
                mission.codeword);
            for (final task in mission.tasks) {
              expect(task.letters, isNotEmpty);
            }
          }
        });
      }
    }

    test('task levels follow per-game progress when available', () {
      final mission = generator.generate(
        grade: 3,
        level: 2,
        locale: 'en',
        gameProgress: {for (final k in gameBuilders.keys) k: 11},
      );
      for (final task in mission.tasks) {
        expect(task.level, 11);
      }
    });

    test('falls back to the mission level for unplayed games', () {
      final mission = generator.generate(
        grade: 3,
        level: 7,
        locale: 'en',
        gameProgress: const {},
      );
      for (final task in mission.tasks) {
        expect(task.level, 7);
      }
    });

    test('missionTaskCountForGrade stays inside the 4-6 band', () {
      for (int g = 1; g <= 4; g++) {
        expect(missionTaskCountForGrade(g), inInclusiveRange(4, 6));
      }
    });
  });

  group('MissionTask grading', () {
    MissionTask task() => MissionTask(
          gameType: 'kenken',
          grade: 2,
          level: 3,
          letters: 'AB',
        );

    test('starts ungraded', () {
      final t = task();
      expect(t.bestPerformance, isNull);
      expect(t.performanceGrade, isNull);
      expect(t.completed, isFalse);
    });

    test('a cleared round records its grade', () {
      final t = task()..recordAttempt(cleared: true, performance: 0.62);
      expect(t.completed, isTrue);
      expect(t.attempts, 1);
      expect(t.bestPerformance, closeTo(0.62, 1e-9));
    });

    test('replaying keeps the best result and never un-clears a task', () {
      final t = task()
        ..recordAttempt(cleared: true, performance: 0.62)
        ..recordAttempt(cleared: false, performance: 0.30)
        ..recordAttempt(cleared: true, performance: 0.91);
      expect(t.attempts, 3);
      expect(t.completed, isTrue);
      expect(t.bestPerformance, closeTo(0.91, 1e-9));
    });

    test('a failed attempt is still recorded for feedback', () {
      final t = task()..recordAttempt(cleared: false, performance: 0.2);
      expect(t.completed, isFalse);
      expect(t.bestPerformance, closeTo(0.2, 1e-9));
    });

    test('survives a save/load round trip', () {
      final t = task()..recordAttempt(cleared: true, performance: 0.77);
      final restored = MissionTask.fromJson(t.toJson());
      expect(restored.letters, 'AB');
      expect(restored.completed, isTrue);
      expect(restored.attempts, 1);
      expect(restored.bestPerformance, closeTo(0.77, 1e-9));
    });

    test('reads missions saved before multi-letter tasks', () {
      final restored = MissionTask.fromJson({
        'gameType': 'kenken',
        'grade': 1,
        'level': 1,
        'letter': 'X',
        'completed': true,
      });
      expect(restored.letters, 'X');
      expect(restored.completed, isTrue);
      expect(restored.bestPerformance, isNull);
    });
  });

  group('Mission summary', () {
    Mission missionWith(List<double?> results) => Mission(
          id: 'm',
          codeword: 'ABCD',
          grade: 2,
          level: 1,
          tasks: [
            for (int i = 0; i < results.length; i++)
              MissionTask(
                gameType: 'kenken',
                grade: 2,
                level: 1,
                letters: 'A',
                completed: results[i] != null,
                bestPerformance: results[i],
              ),
          ],
        );

    test('average ignores unplayed tasks', () {
      final m = missionWith([0.9, 0.7, null]);
      expect(m.averagePerformance, closeTo(0.8, 1e-9));
      expect(m.completedCount, 2);
      expect(m.allTasksDone, isFalse);
    });

    test('is null before anything is cleared', () {
      expect(missionWith([null, null]).averagePerformance, isNull);
    });
  });
}
