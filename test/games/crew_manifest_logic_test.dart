// Unit tests for crew_manifest_logic.dart — pure puzzle logic only.
//
// Tests puzzle generation, clue consistency, bijection property of
// assignments, and solution validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/crew_manifest_logic.dart';

DifficultyConfig _config({int grade = 1, int level = 1}) {
  return DifficultyConfig(
    grade: grade,
    level: level,
    difficultyMultiplier: 1.0,
    numberRange: const {'min': 1, 'max': 20},
    operationTypes: const [MathOperation.addition],
    equationProbability: 0.0,
    objectCount: 1,
    timeLimit: 60,
    gameSpeed: 1.0,
    showHints: false,
    animationSpeed: 1.0,
    visualComplexity: 1.0,
  );
}

void main() {
  group('CrewManifestLogic.generate structure', () {
    test('grade 1: size is 3', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = CrewManifestLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        expect(puzzle.size, 3);
        expect(puzzle.crewNames.length, 3);
        expect(puzzle.itemNames.length, 3);
      }
    });

    test('grade 4 level 10: size is 5', () {
      final puzzle = CrewManifestLogic.generate({
        'grade': 4,
        'level': 10,
        'difficulty': _config(grade: 4, level: 10),
      });

      expect(puzzle.size, 5);
      expect(puzzle.crewNames.length, 5);
      expect(puzzle.itemNames.length, 5);
    });
  });

  group('CrewManifestLogic.generate bijection', () {
    test('solution is a valid bijection (each crew -> unique item)', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final puzzle = CrewManifestLogic.generate({
            'grade': grade,
            'level': 5,
            'difficulty': _config(grade: grade, level: 5),
          });

          // Every crew member maps to exactly one item
          expect(puzzle.solution.length, puzzle.size);
          for (final crew in puzzle.crewNames) {
            expect(puzzle.solution.containsKey(crew), isTrue,
                reason: '$crew must have an assigned item');
          }

          // All assigned items are from itemNames
          for (final item in puzzle.solution.values) {
            expect(puzzle.itemNames.contains(item), isTrue,
                reason: '$item must be in the item pool');
          }

          // All items are unique (bijection)
          final assignedItems = puzzle.solution.values.toSet();
          expect(assignedItems.length, puzzle.size,
              reason: 'each crew member must have a unique item');
        }
      }
    });
  });

  group('CrewManifestLogic.generate clue consistency', () {
    test('positive clues are consistent with solution', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = CrewManifestLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        for (final clue in puzzle.clues) {
          // Parse positive clues: "X has the Y." or "The Y belongs to X."
          if (clue.contains('has the') && !clue.contains('not')) {
            final crewName =
                clue.substring(0, clue.indexOf(' has the'));
            final item = clue
                .substring(clue.indexOf('has the ') + 8)
                .replaceAll('.', '');
            expect(puzzle.solution[crewName], item,
                reason: 'positive clue "$clue" must match solution');
          } else if (clue.contains('belongs to') && !clue.contains('not')) {
            final item = clue
                .substring(clue.indexOf('The ') + 4, clue.indexOf(' belongs'))
                .trim();
            final crewName =
                clue.substring(clue.indexOf('belongs to ') + 11).replaceAll('.', '');
            expect(puzzle.solution[crewName], item,
                reason: 'positive clue "$clue" must match solution');
          } else if (clue.contains('was assigned') && !clue.contains('not')) {
            final crewName =
                clue.substring(0, clue.indexOf(' was assigned'));
            final item = clue
                .substring(clue.indexOf('assigned the ') + 13)
                .replaceAll('.', '');
            expect(puzzle.solution[crewName], item,
                reason: 'positive clue "$clue" must match solution');
          }
        }
      }
    });

    test('negative clues are consistent with solution', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = CrewManifestLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        for (final clue in puzzle.clues) {
          if (clue.contains('does not have')) {
            final crewName =
                clue.substring(0, clue.indexOf(' does not'));
            final item = clue
                .substring(clue.indexOf('have the ') + 9)
                .replaceAll('.', '');
            expect(puzzle.solution[crewName], isNot(equals(item)),
                reason: 'negative clue "$clue" must be consistent');
          }
        }
      }
    });

    test('puzzle has at least 1 clue', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = CrewManifestLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        expect(puzzle.clues, isNotEmpty);
      }
    });
  });

  group('CrewManifestPuzzle.checkSolution', () {
    test('correct assignment is accepted', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = CrewManifestLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });

        expect(puzzle.checkSolution(puzzle.solution), isTrue);
      }
    });

    test('wrong assignment is rejected', () {
      final puzzle = CrewManifestLogic.generate({
        'grade': 1,
        'level': 1,
        'difficulty': _config(grade: 1, level: 1),
      });

      // Swap two assignments
      final wrongSolution = Map<String, String>.from(puzzle.solution);
      final keys = wrongSolution.keys.toList();
      if (keys.length >= 2) {
        final temp = wrongSolution[keys[0]]!;
        wrongSolution[keys[0]] = wrongSolution[keys[1]]!;
        wrongSolution[keys[1]] = temp;
      }

      expect(puzzle.checkSolution(wrongSolution), isFalse);
    });

    test('empty assignment is rejected', () {
      final puzzle = CrewManifestLogic.generate({
        'grade': 1,
        'level': 1,
        'difficulty': _config(grade: 1, level: 1),
      });

      expect(puzzle.checkSolution({}), isFalse);
    });
  });
}
