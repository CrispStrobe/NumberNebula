// Unit tests for alien_tribunal_logic.dart — pure puzzle logic only.
//
// The headline guarantee is that every generated puzzle has exactly ONE valid
// verdict. That is not free: statements about a single other delegate ("X is a
// liar") only assert whether two delegates share a role, so flipping every role
// at once satisfies them equally well. Puzzles built from those alone are
// always ambiguous — which is why the generator also uses pair and tally
// statements, and why these tests check uniqueness rather than mere
// self-consistency.

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

        final roles = [
          for (int j = 0; j < puzzle.personCount; j++)
            puzzle.people[j].isTruthTeller
        ];

        for (int j = 0; j < puzzle.personCount; j++) {
          final person = puzzle.people[j];
          // A truth-teller's claim holds; a liar's does not.
          expect(person.claimHolds(roles), person.isTruthTeller,
              reason: '${person.name} (${person.isTruthTeller ? "truth-teller" : "liar"}) '
                  'made a claim inconsistent with their role');
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
          final person = puzzle.people[j];
          if (person.kind == TribunalClaimKind.count) continue;
          expect(person.targetIndex, isNot(equals(j)),
              reason: 'person $j must not reference self');
          expect(person.secondTargetIndex, isNot(equals(j)),
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
        if (person.kind == TribunalClaimKind.count) {
          expect(person.countValue, inInclusiveRange(0, puzzle.personCount));
          continue;
        }
        expect(person.targetIndex, inInclusiveRange(0, puzzle.personCount - 1));
        if (person.kind == TribunalClaimKind.pair) {
          expect(person.secondTargetIndex,
              inInclusiveRange(0, puzzle.personCount - 1));
          expect(person.secondTargetIndex, isNot(equals(person.targetIndex)));
        }
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

  group('AlienTribunalLogic.generate solvability', () {
    test('every generated puzzle has exactly one valid verdict', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 8; level += 3) {
          for (int i = 0; i < 12; i++) {
            final puzzle = AlienTribunalLogic.generate({
              'grade': grade,
              'level': level,
              'difficulty': _config(grade: grade, level: level),
            });

            final solutions = puzzle.findAllSolutions();
            expect(solutions.length, 1,
                reason: 'grade $grade level $level puzzle has '
                    '${solutions.length} valid verdicts, must have exactly 1');

            // ...and that one solution is the one the generator recorded.
            expect(solutions.single, [
              for (int j = 0; j < puzzle.personCount; j++)
                puzzle.people[j].isTruthTeller
            ]);
          }
        }
      }
    });

    test('the fallback puzzle is itself uniquely solvable', () {
      // The fallback is near-unreachable, so pin it down directly: two
      // delegates vouching for each other plus one lying about the tally.
      final names = ['Zyx', 'Qar', 'Meb'];
      final puzzle = AlienTribunalPuzzle(
        personCount: 3,
        people: [
          TribunalPerson(
            name: names[0], isTruthTeller: true, statement: '',
            targetIndex: 1, claimsTruthTeller: true),
          TribunalPerson(
            name: names[1], isTruthTeller: true, statement: '',
            targetIndex: 0, claimsTruthTeller: true),
          TribunalPerson(
            name: names[2], isTruthTeller: false, statement: '',
            kind: TribunalClaimKind.count, targetIndex: -1,
            claimsTruthTeller: false, countValue: 3),
        ],
      );

      expect(puzzle.findAllSolutions(), [
        [true, true, false]
      ]);
    });

    test('statements about single delegates alone are never unique', () {
      // Guards the reason pair/tally statements exist: with only "X is a liar"
      // style claims, flipping every role is always a second valid verdict.
      const puzzle = AlienTribunalPuzzle(
        personCount: 3,
        people: [
          TribunalPerson(
            name: 'A', isTruthTeller: true, statement: '',
            targetIndex: 2, claimsTruthTeller: true),
          TribunalPerson(
            name: 'B', isTruthTeller: false, statement: '',
            targetIndex: 0, claimsTruthTeller: false),
          TribunalPerson(
            name: 'C', isTruthTeller: true, statement: '',
            targetIndex: 1, claimsTruthTeller: false),
        ],
      );

      final solutions = puzzle.findAllSolutions();
      expect(solutions.length, 2);
      // The two solutions are exact opposites of each other.
      expect(solutions[0], solutions[1].map((v) => !v).toList());
    });
  });

  group('AlienTribunalLogic.generate variety', () {
    test('verdict patterns vary instead of repeating one arrangement', () {
      final patterns = <String>{};
      for (int i = 0; i < 60; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });
        patterns.add(
            puzzle.people.map((p) => p.isTruthTeller ? 'T' : 'L').join());
      }

      // 3 delegates allow 6 mixed arrangements; 60 draws should hit them all.
      // The regression this guards is the generator emitting only 'TLT'.
      expect(patterns.length, 6, reason: 'saw only $patterns');
    });

    test('statements are not all of the same kind', () {
      final kinds = <TribunalClaimKind>{};
      for (int i = 0; i < 40; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 4,
          'level': 6,
          'difficulty': _config(grade: 4, level: 6),
        });
        kinds.addAll(puzzle.people.map((p) => p.kind));
      }

      expect(kinds, containsAll(TribunalClaimKind.values));
    });

    test('older grades may use disjunctions, grade 1 never does', () {
      for (int i = 0; i < 40; i++) {
        final puzzle = AlienTribunalLogic.generate({
          'grade': 1,
          'level': 2,
          'difficulty': _config(grade: 1, level: 2),
        });

        for (final person in puzzle.people) {
          if (person.kind == TribunalClaimKind.pair) {
            expect(person.pairRequiresBoth, isTrue,
                reason: 'grade 1 must not need "at least one of" reasoning');
          }
        }
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
      expect(person.kind, TribunalClaimKind.single);
      expect(person.claimHolds([true, true, false]), isTrue);
      expect(person.claimHolds([true, false, false]), isFalse);
    });
  });
}
