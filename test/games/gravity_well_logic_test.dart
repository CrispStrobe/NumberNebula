// Unit tests for gravity_well_logic.dart — pure puzzle logic only.
//
// Tests scale balance correctness, weight generation, difficulty scaling,
// and solution validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/gravity_well_logic.dart';

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
  group('BalanceScale', () {
    test('isBalanced returns true when sides are equal', () {
      const scale = BalanceScale(
        leftSide: [
          ScaleItem(label: 'A', weight: 5, isKnown: false),
          ScaleItem(label: 'B', weight: 3, isKnown: true),
        ],
        rightSide: [
          ScaleItem(label: '8 kg', weight: 8, isKnown: true),
        ],
      );

      expect(scale.leftTotal, 8);
      expect(scale.rightTotal, 8);
      expect(scale.isBalanced, isTrue);
    });

    test('isBalanced returns false when sides differ', () {
      const scale = BalanceScale(
        leftSide: [
          ScaleItem(label: 'A', weight: 5, isKnown: false),
        ],
        rightSide: [
          ScaleItem(label: '3 kg', weight: 3, isKnown: true),
        ],
      );

      expect(scale.isBalanced, isFalse);
    });

    test('leftTotal and rightTotal compute correctly', () {
      const scale = BalanceScale(
        leftSide: [
          ScaleItem(label: 'A', weight: 2, isKnown: false),
          ScaleItem(label: 'B', weight: 7, isKnown: true),
        ],
        rightSide: [
          ScaleItem(label: 'C', weight: 4, isKnown: false),
          ScaleItem(label: '5 kg', weight: 5, isKnown: true),
        ],
      );

      expect(scale.leftTotal, 9);
      expect(scale.rightTotal, 9);
    });
  });

  group('GravityWellLogic.generate difficulty scaling', () {
    test('grade 1: 2 objects, 1 scale', () {
      for (int i = 0; i < 3; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        expect(puzzle.objectCount, 2);
        expect(puzzle.scales.length, 1);
      }
    });

    test('grade 4 level 10: 5 objects, 4 scales', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 4,
        'level': 10,
        'difficulty': _config(grade: 4, level: 10),
      });

      expect(puzzle.objectCount, 5);
      expect(puzzle.scales.length, 4);
    });
  });

  group('GravityWellLogic.generate invariants', () {
    test('all scales are balanced', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final puzzle = GravityWellLogic.generate({
            'grade': grade,
            'level': 5,
            'difficulty': _config(grade: grade, level: 5),
          });

          for (int s = 0; s < puzzle.scales.length; s++) {
            expect(puzzle.scales[s].isBalanced, isTrue,
                reason: 'scale $s must be balanced');
          }
        }
      }
    });

    test('known + unknown weights partition all objects', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 3,
          'level': 5,
          'difficulty': _config(grade: 3, level: 5),
        });

        final allLabels = <String>{
          ...puzzle.knownWeights.keys,
          ...puzzle.unknownWeights.keys,
        };
        expect(allLabels.length, puzzle.objectCount);

        // No overlap
        for (final k in puzzle.knownWeights.keys) {
          expect(puzzle.unknownWeights.containsKey(k), isFalse);
        }
      }
    });

    test('at least one unknown weight exists', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });

        expect(puzzle.unknownWeights, isNotEmpty);
      }
    });

    test('all weights are positive', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 3,
          'level': 5,
          'difficulty': _config(grade: 3, level: 5),
        });

        for (final w in puzzle.knownWeights.values) {
          expect(w, greaterThan(0));
        }
        for (final w in puzzle.unknownWeights.values) {
          expect(w, greaterThan(0));
        }
      }
    });

    test('weights are within maxWeight range', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 1,
          'level': 1,
          'difficulty': _config(grade: 1, level: 1),
        });

        // grade 1 => maxWeight = 10
        for (final w in puzzle.knownWeights.values) {
          expect(w, inInclusiveRange(1, 10));
        }
        for (final w in puzzle.unknownWeights.values) {
          expect(w, inInclusiveRange(1, 10));
        }
      }
    });
  });

  group('GravityWellPuzzle.checkSolution', () {
    test('correct solution is accepted', () {
      for (int i = 0; i < 5; i++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 2,
          'level': 3,
          'difficulty': _config(grade: 2, level: 3),
        });

        expect(puzzle.checkSolution(puzzle.unknownWeights), isTrue);
      }
    });

    test('wrong weights are rejected', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 2,
        'level': 3,
        'difficulty': _config(grade: 2, level: 3),
      });

      final wrong = <String, int>{};
      for (final entry in puzzle.unknownWeights.entries) {
        wrong[entry.key] = entry.value + 1; // off by one
      }
      expect(puzzle.checkSolution(wrong), isFalse);
    });

    test('empty answer is rejected', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 1,
        'level': 1,
        'difficulty': _config(grade: 1, level: 1),
      });

      expect(puzzle.checkSolution({}), isFalse);
    });

    test('partial answer is rejected', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 3,
        'level': 5,
        'difficulty': _config(grade: 3, level: 5),
      });

      if (puzzle.unknownWeights.length > 1) {
        // Provide only the first unknown
        final partial = <String, int>{};
        final first = puzzle.unknownWeights.entries.first;
        partial[first.key] = first.value;
        expect(puzzle.checkSolution(partial), isFalse);
      }
    });
  });
}
