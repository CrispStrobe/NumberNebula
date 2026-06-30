// test/logic/csp_generators_test.dart
//
// Smoke tests for CSP-based puzzle generators.
// Fast generators run in CI; slow ones (crosswords, star_forge) are
// skipped by default — run manually on VPS via:
//   flutter test test/logic/csp_generators_test.dart --run-skipped

import 'package:flutter_test/flutter_test.dart';

import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/arithmancer_crosswords_logic.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/services/alien_tribunal_logic.dart';

DifficultyConfig _makeDifficulty(int grade, int level) {
  return DifficultyConfig(
    grade: grade,
    level: level,
    difficultyMultiplier: 1.0,
    numberRange: {'min': 1, 'max': 10 + grade * 5},
    operationTypes: [MathOperation.addition, MathOperation.subtraction],
    equationProbability: 0.5,
    objectCount: 5,
    timeLimit: 120,
    gameSpeed: 60,
    showHints: true,
    animationSpeed: 1.0,
    visualComplexity: 1.0,
  );
}

void main() {
  group('Fast CSP generators', () {
    test('Alien Tribunal generates 5 puzzles', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 2,
          'level': 5,
          'difficulty': _makeDifficulty(2, 5),
        });
        expect(puzzle.people, isNotEmpty, reason: 'Puzzle $i has no people');
        expect(puzzle.personCount, greaterThan(0));
      }
    });
  });

  group('Slow CSP generators (run with --run-skipped)', () {
    test('Arithmancer Crosswords generates 2 grade-1 puzzles', () async {
      for (int i = 0; i < 2; i++) {
        final config = CrosswordConfig.createConfig(1, 1);
        final puzzle = await generateCrosswordPuzzle(config);
        expect(puzzle.equations, isNotEmpty);
        expect(puzzle.fullSolution, isNotEmpty);
        expect(puzzle.numberPool, isNotEmpty);
      }
    },
        timeout: const Timeout(Duration(minutes: 3)),
        skip: 'CSP generation too slow for CI — run on VPS');

    test('Star Forge generates 5 five-point star puzzles', () async {
      final gen = StarForgeGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(points: 5, clueCount: 4);
        expect(puzzle.solution, isNotEmpty);
        expect(puzzle.solution.length, equals(10));
        expect(puzzle.clues, isNotEmpty);
      }
    },
        timeout: const Timeout(Duration(minutes: 3)),
        skip: 'CSP generation too slow for CI — run on VPS');
  });
}
