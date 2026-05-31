// Unit tests for vault_cracker_logic.dart (static deduction redesign).

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/vault_cracker_logic.dart';

DifficultyConfig _config({int grade = 1}) {
  return DifficultyConfig(
    grade: grade,
    level: 1,
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

VaultCrackerPuzzle _generate({int grade = 1, int level = 1}) {
  return VaultCrackerLogic.generate({
    'grade': grade,
    'level': level,
    'difficulty': _config(grade: grade),
  });
}

void main() {
  group('VaultCrackerPuzzle.isCorrect', () {
    test('exact match returns true', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        digitRange: 5,
        clues: [],
      );
      expect(puzzle.isCorrect([1, 2, 3]), isTrue);
    });

    test('wrong code returns false', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        digitRange: 5,
        clues: [],
      );
      expect(puzzle.isCorrect([3, 2, 1]), isFalse);
    });

    test('wrong length returns false', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        digitRange: 5,
        clues: [],
      );
      expect(puzzle.isCorrect([1, 2]), isFalse);
    });
  });

  group('VaultCrackerLogic.generate: structure', () {
    test('grade 1: 3-digit code, digits in range', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = _generate(grade: 1);
        expect(puzzle.codeLength, 3);
        expect(puzzle.secretCode.length, 3);
        for (final d in puzzle.secretCode) {
          expect(d, greaterThanOrEqualTo(0));
          expect(d, lessThan(puzzle.digitRange));
        }
      }
    });

    test('grade 4: longer codes', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = _generate(grade: 4, level: 10);
        expect(puzzle.codeLength, greaterThanOrEqualTo(3));
        expect(puzzle.secretCode.length, puzzle.codeLength);
      }
    });

    test('has at least 3 clues', () {
      for (int grade = 1; grade <= 4; grade++) {
        final puzzle = _generate(grade: grade);
        expect(puzzle.clues.length, greaterThanOrEqualTo(3));
      }
    });
  });

  group('VaultCrackerLogic.generate: clue consistency', () {
    test('clue attempt length matches code length', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = _generate(grade: 2);
        for (final clue in puzzle.clues) {
          expect(clue.attempt.length, puzzle.codeLength);
        }
      }
    });

    test('clue feedback sums to code length', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = _generate(grade: 2);
        for (final clue in puzzle.clues) {
          expect(clue.correctPosition + clue.correctDigit + clue.wrong,
              puzzle.codeLength);
        }
      }
    });

    test('no clue is the exact secret code', () {
      for (int i = 0; i < 10; i++) {
        final puzzle = _generate(grade: 2);
        for (final clue in puzzle.clues) {
          expect(clue.correctPosition, lessThan(puzzle.codeLength));
        }
      }
    });

    test('clue text is not empty', () {
      final puzzle = _generate(grade: 1);
      for (final clue in puzzle.clues) {
        expect(clue.clueTextEn.isNotEmpty, isTrue);
        expect(clue.clueTextDe.isNotEmpty, isTrue);
      }
    });
  });
}
