// Unit tests for alien_tribunal_logic.dart — pure puzzle logic only.
//
// The generator uses recursive retry for non-unique solutions and falls back
// to a hardcoded 3-person puzzle when retries are exhausted. The fallback
// may not produce the requested personCount and may have multiple valid
// solutions. We test what the generator guarantees: statement consistency
// with its own solution and correct checkSolution/getSolution behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/alien_tribunal_logic.dart';

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
  group('AlienTribunalLogic.generate structure', () {
    test('generates at least 3 people', () {
      for (int grade = 2; grade <= 3; grade++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': grade,
          'level': 3,
          'difficulty': _config(grade: grade, level: 3),
        });

        expect(puzzle.personCount, greaterThanOrEqualTo(3));
        expect(puzzle.people.length, puzzle.personCount);
      }
    });

    test('all people have unique names', () {
      for (int i = 0; i < 3; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 3,
          'level': 3,
          'difficulty': _config(grade: 3, level: 3),
        });

        final names = puzzle.people.map((p) => p.name).toSet();
        expect(names.length, puzzle.personCount);
      }
    });
  });

  group('AlienTribunalLogic.generate statement consistency', () {
    test('statements are consistent with the generators own assignment',
        () {
      for (int i = 0; i < 5; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 3,
          'level': 3,
          'difficulty': _config(grade: 3, level: 3),
        });

        for (int j = 0; j < puzzle.personCount; j++) {
          final person = puzzle.people[j];
          final targetIsTruthTeller =
              puzzle.people[person.targetIndex].isTruthTeller;

          if (person.isTruthTeller) {
            // Truth-tellers' claims match reality
            expect(person.claimsTruthTeller, targetIsTruthTeller,
                reason:
                    '${person.name} is a truth-teller, claim must match reality');
          } else {
            // Liars' claims are opposite to reality
            expect(person.claimsTruthTeller, !targetIsTruthTeller,
                reason:
                    '${person.name} is a liar, claim must be opposite to reality');
          }
        }
      }
    });

    test('each person references someone else (not self)', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 3,
          'level': 3,
          'difficulty': _config(grade: 3, level: 3),
        });

        for (int j = 0; j < puzzle.personCount; j++) {
          expect(puzzle.people[j].targetIndex, isNot(equals(j)),
              reason: 'person $j must not reference self');
        }
      }
    });

    test('target indices are within valid range', () {
      final puzzle = AlienTribunalLogic.generate({
        'grade': 2,
        'level': 3,
        'difficulty': _config(grade: 2, level: 3),
      });

      for (final person in puzzle.people) {
        expect(person.targetIndex,
            inInclusiveRange(0, puzzle.personCount - 1));
      }
    });
  });

  group('AlienTribunalLogic.generate mixed roles', () {
    test('puzzle has at least one truth-teller and one liar', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });

        final truthTellers =
            puzzle.people.where((p) => p.isTruthTeller).length;
        final liars = puzzle.people.where((p) => !p.isTruthTeller).length;

        expect(truthTellers, greaterThanOrEqualTo(1));
        expect(liars, greaterThanOrEqualTo(1));
      }
    });
  });

  group('AlienTribunalPuzzle.checkSolution', () {
    test('correct solution is accepted', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });

        expect(puzzle.checkSolution(puzzle.getSolution()), isTrue);
      }
    });

    test('flipped solution is rejected', () {
      final puzzle = AlienTribunalLogic.generate({
        'grade': 3,
        'level': 3,
        'difficulty': _config(grade: 3, level: 3),
      });

      // Flip all roles
      final flipped = <int, bool>{};
      for (int i = 0; i < puzzle.personCount; i++) {
        flipped[i] = !puzzle.people[i].isTruthTeller;
      }
      expect(puzzle.checkSolution(flipped), isFalse);
    });

    test('empty solution is rejected', () {
      final puzzle = AlienTribunalLogic.generate({
        'grade': 2,
        'level': 1,
        'difficulty': _config(grade: 2, level: 1),
      });

      expect(puzzle.checkSolution({}), isFalse);
    });
  });

  group('AlienTribunalPuzzle.getSolution', () {
    test('getSolution returns correct mapping', () {
      final puzzle = AlienTribunalLogic.generate({
        'grade': 2,
        'level': 3,
        'difficulty': _config(grade: 2, level: 3),
      });

      final sol = puzzle.getSolution();
      expect(sol.length, puzzle.personCount);
      for (int i = 0; i < puzzle.personCount; i++) {
        expect(sol[i], puzzle.people[i].isTruthTeller);
      }
    });
  });

  group('TribunalPerson', () {
    test('stores all fields correctly', () {
      const person = TribunalPerson(
        name: 'Zyx',
        isTruthTeller: true,
        statement: '"Qar tells the truth."',
        targetIndex: 1,
        claimsTruthTeller: true,
      );

      expect(person.name, 'Zyx');
      expect(person.isTruthTeller, isTrue);
      expect(person.targetIndex, 1);
      expect(person.claimsTruthTeller, isTrue);
      expect(person.statement, contains('Qar'));
    });
  });
}
