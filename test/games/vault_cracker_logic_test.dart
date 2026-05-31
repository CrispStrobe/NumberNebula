// Unit tests for vault_cracker_logic.dart — pure puzzle logic only.
//
// Tests code generation, feedback evaluation (green/yellow/gray),
// and difficulty scaling.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/vault_cracker_logic.dart';

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
  group('VaultCrackerLogic.generate difficulty scaling', () {
    test('grade 1: code length is 3, digit range is 6', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = VaultCrackerLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        expect(puzzle.codeLength, 3);
        expect(puzzle.digitRange, 6);
        expect(puzzle.maxAttempts, 8);
        expect(puzzle.secretCode.length, 3);

        for (final d in puzzle.secretCode) {
          expect(d, inInclusiveRange(0, 5));
        }
      }
    });

    test('grade 4 level 10: code length is 5, digit range is 8', () {
      final puzzle = VaultCrackerLogic.generate({
        'grade': 4,
        'level': 10,
        'difficulty': _config(grade: 4, level: 10),
      });

      expect(puzzle.codeLength, 5);
      expect(puzzle.digitRange, 8);
      expect(puzzle.secretCode.length, 5);
    });

    test('grade 4 level 15: code length is 6, digit range is 10', () {
      final puzzle = VaultCrackerLogic.generate({
        'grade': 4,
        'level': 15,
        'difficulty': _config(grade: 4, level: 15),
      });

      expect(puzzle.codeLength, 6);
      expect(puzzle.digitRange, 10);
    });
  });

  group('VaultCrackerPuzzle.evaluate feedback', () {
    test('all green for exact match', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      final feedback = puzzle.evaluate([1, 2, 3]);
      expect(feedback, [
        DigitFeedback.green,
        DigitFeedback.green,
        DigitFeedback.green,
      ]);
    });

    test('all gray for no match', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      final feedback = puzzle.evaluate([4, 5, 0]);
      expect(feedback, [
        DigitFeedback.gray,
        DigitFeedback.gray,
        DigitFeedback.gray,
      ]);
    });

    test('yellow for correct digit in wrong position', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      final feedback = puzzle.evaluate([3, 1, 2]);
      expect(feedback, [
        DigitFeedback.yellow,
        DigitFeedback.yellow,
        DigitFeedback.yellow,
      ]);
    });

    test('mixed green, yellow, gray', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3, 4],
        codeLength: 4,
        maxAttempts: 6,
        digitRange: 6,
      );

      // Guess [1, 3, 5, 4]
      // pos 0: 1==1 -> green
      // pos 1: 3!=2, but 3 is in secret -> yellow
      // pos 2: 5 not in secret -> gray
      // pos 3: 4==4 -> green
      final feedback = puzzle.evaluate([1, 3, 5, 4]);
      expect(feedback[0], DigitFeedback.green);
      expect(feedback[1], DigitFeedback.yellow);
      expect(feedback[2], DigitFeedback.gray);
      expect(feedback[3], DigitFeedback.green);
    });

    test('duplicate digit in guess: only one yellow per secret occurrence',
        () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      // Guess [2, 2, 2]: secret has one 2 at pos 1
      // pos 0: 2!=1, but 2 in secret -> yellow (consumes the 2)
      // pos 1: 2==2 -> green (wait, green pass first)
      // Actually green pass first: pos 1 is green.
      // Then yellow pass: pos 0: 2 not in remaining secret -> gray
      // pos 2: 2!=3, 2 not in remaining -> gray
      final feedback = puzzle.evaluate([2, 2, 2]);
      expect(feedback[0], DigitFeedback.gray);
      expect(feedback[1], DigitFeedback.green);
      expect(feedback[2], DigitFeedback.gray);
    });
  });

  group('VaultCrackerPuzzle.isCorrect', () {
    test('exact match returns true', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      expect(puzzle.isCorrect([1, 2, 3]), isTrue);
    });

    test('wrong guess returns false', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      expect(puzzle.isCorrect([1, 2, 4]), isFalse);
    });

    test('wrong length returns false', () {
      const puzzle = VaultCrackerPuzzle(
        secretCode: [1, 2, 3],
        codeLength: 3,
        maxAttempts: 8,
        digitRange: 6,
      );

      expect(puzzle.isCorrect([1, 2]), isFalse);
    });
  });

  group('VaultCrackerLogic.generate invariants', () {
    test('generated codes have correct length and digit range', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int level = 1; level <= 15; level += 7) {
          final puzzle = VaultCrackerLogic.generate({
            'grade': grade,
            'level': level,
            'difficulty': _config(grade: grade, level: level),
          });

          expect(puzzle.secretCode.length, puzzle.codeLength);
          for (final d in puzzle.secretCode) {
            expect(d, inInclusiveRange(0, puzzle.digitRange - 1));
          }
          expect(puzzle.maxAttempts, greaterThan(0));
        }
      }
    });
  });
}
