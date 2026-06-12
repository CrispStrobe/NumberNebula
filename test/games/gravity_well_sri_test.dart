// Unit tests for Gravity Well balance-scale puzzle generation and the
// math problem extraction added for SRI reporting.
//
// Tests GravityWellLogic.generate() puzzle validity and verifies that
// extractable arithmetic problems correspond to the scale equations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/gravity_well_logic.dart';

void main() {
  DifficultyConfig _difficultyFor(int grade) {
    return DifficultyConfig(
      grade: grade,
      level: 5,
      difficultyMultiplier: 1.5,
      numberRange: {'min': 1, 'max': 20},
      operationTypes: [],
      equationProbability: 0.5,
      objectCount: 8,
      timeLimit: 120,
      gameSpeed: 150,
      showHints: true,
      animationSpeed: 1.0,
      visualComplexity: 1.5,
    );
  }

  group('GravityWellLogic.generate', () {
    test('generates puzzle with correct object count for grade 1', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 1,
        'level': 1,
        'difficulty': _difficultyFor(1),
      });

      expect(puzzle.objectCount, greaterThanOrEqualTo(3));
      expect(puzzle.unknownWeights, isNotEmpty);
      expect(puzzle.knownWeights, isNotEmpty);
      expect(puzzle.scales, isNotEmpty);
    });

    test('generates puzzle with more unknowns for grade 4', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 4,
        'level': 10,
        'difficulty': _difficultyFor(4),
      });

      expect(puzzle.objectCount, greaterThanOrEqualTo(4));
      expect(puzzle.unknownWeights.length, greaterThanOrEqualTo(2));
    });

    test('all scales are balanced', () {
      for (int grade = 1; grade <= 4; grade++) {
        final puzzle = GravityWellLogic.generate({
          'grade': grade,
          'level': 5,
          'difficulty': _difficultyFor(grade),
        });

        for (int i = 0; i < puzzle.scales.length; i++) {
          final scale = puzzle.scales[i];
          expect(scale.isBalanced, isTrue,
              reason: 'Scale $i should be balanced at grade $grade');
        }
      }
    });

    test('checkSolution returns true for correct answers', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 2,
        'level': 5,
        'difficulty': _difficultyFor(2),
      });

      expect(puzzle.checkSolution(puzzle.unknownWeights), isTrue);
    });

    test('checkSolution returns false for wrong answers', () {
      final puzzle = GravityWellLogic.generate({
        'grade': 2,
        'level': 5,
        'difficulty': _difficultyFor(2),
      });

      final wrongAnswers = {
        for (final e in puzzle.unknownWeights.entries) e.key: e.value + 99
      };
      expect(puzzle.checkSolution(wrongAnswers), isFalse);
    });
  });

  group('Balance scale arithmetic extraction', () {
    // This tests the same logic used by _extractMathProblems in the game widget.
    // We replicate it here as a pure function to verify independently.

    List<Map<String, dynamic>> extractEquations(GravityWellPuzzle puzzle) {
      final equations = <Map<String, dynamic>>[];

      for (final scale in puzzle.scales) {
        final leftKnown = scale.leftSide
            .where((item) => !puzzle.unknownWeights.containsKey(item.label))
            .fold(0, (sum, item) => sum + item.weight);
        final rightKnown = scale.rightSide
            .where((item) => !puzzle.unknownWeights.containsKey(item.label))
            .fold(0, (sum, item) => sum + item.weight);
        final leftUnknown = scale.leftSide
            .where((item) => puzzle.unknownWeights.containsKey(item.label))
            .toList();
        final rightUnknown = scale.rightSide
            .where((item) => puzzle.unknownWeights.containsKey(item.label))
            .toList();

        if (leftUnknown.length == 1 && rightUnknown.isEmpty) {
          equations.add({
            'unknown': leftUnknown.first.label,
            'unknownWeight': leftUnknown.first.weight,
            'leftKnown': leftKnown,
            'rightKnown': rightKnown,
          });
        } else if (rightUnknown.length == 1 && leftUnknown.isEmpty) {
          equations.add({
            'unknown': rightUnknown.first.label,
            'unknownWeight': rightUnknown.first.weight,
            'leftKnown': leftKnown,
            'rightKnown': rightKnown,
          });
        }
      }
      return equations;
    }

    test('at least one extractable equation exists per puzzle', () {
      for (int trial = 0; trial < 10; trial++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 2,
          'level': 5,
          'difficulty': _difficultyFor(2),
        });

        final equations = extractEquations(puzzle);
        expect(equations, isNotEmpty,
            reason: 'Trial $trial: should find at least one simple equation');
      }
    });

    test('extracted equations are arithmetically correct', () {
      for (int trial = 0; trial < 10; trial++) {
        final puzzle = GravityWellLogic.generate({
          'grade': 2,
          'level': 5,
          'difficulty': _difficultyFor(2),
        });

        final equations = extractEquations(puzzle);
        for (final eq in equations) {
          // The scale is balanced, so:
          // unknownWeight + leftKnown = rightKnown (if unknown is on left)
          // or unknownWeight + rightKnown = leftKnown (if unknown is on right)
          final unknownWeight = eq['unknownWeight'] as int;
          final leftKnown = eq['leftKnown'] as int;
          final rightKnown = eq['rightKnown'] as int;

          // Balance: unknown + sameKnownSide = otherKnownSide
          // Either: unknownWeight + leftKnown == rightKnown
          //     or: unknownWeight + rightKnown == leftKnown
          final balanced = (unknownWeight + leftKnown == rightKnown) ||
              (unknownWeight + rightKnown == leftKnown);
          expect(balanced, isTrue,
              reason:
                  'Equation should balance: unknown=$unknownWeight, '
                  'leftKnown=$leftKnown, rightKnown=$rightKnown');
        }
      }
    });
  });
}
