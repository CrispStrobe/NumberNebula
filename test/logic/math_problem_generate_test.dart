// Regression test for MathProblem.generateProblem in CUSTOM mode.
//
// Bug: when a player set a custom number range with min == max (the settings
// sliders allow it) and 'subtraction' was an active custom operation,
// _generateFromConfig computed random.nextInt(max - (min+1) + 1) ==
// random.nextInt(0) and threw a RangeError — crashing problem generation for
// every game that calls generateProblem (planet_hopping, puzzle_math,
// hyperdrive_gates, asteroid_math, path_finder).
//
// We force the crashing path deterministically: custom mode, subtraction-only,
// degenerate range — so the operation pick is always subtraction.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';

/// SriService stub: never offers a review problem (so generateProblem falls
/// through to _generateFromConfig) and never reports mastery (so the
/// non-mastered retry loop exits immediately).
class _NoReviewSri extends SriService {
  @override
  List<String> getProblemsForReview(
          {int limit = 5, Set<String>? excludeIds, bool resetSessionFirst = false}) =>
      const [];
  @override
  bool isProblemMastered(String problemId) => false;
}

class _NoopProgress extends ProgressService {
  @override
  Future<void> saveProgress(GameProvider gameProvider) async {}
}

void main() {
  late GameProvider gp;
  late _NoReviewSri sri;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sri = _NoReviewSri();
    gp = GameProvider(
      progressService: _NoopProgress(),
      sriService: sri,
      cognitiveProfileService: CognitiveProfileService(),
    );
  });

  test('custom subtraction with a degenerate min==max range does not crash', () {
    gp.setUseCustomSettings(true);
    gp.setCustomOperations({'subtraction'});
    gp.setCustomRange(min: 5, max: 5); // degenerate — was the crash trigger

    for (var i = 0; i < 100; i++) {
      final p = MathProblem.generateProblem(gp, 1, sri);
      expect(p.operation, MathOperation.subtraction);
      expect(p.isValid(), isTrue);
      expect(p.answer, isNonNegative);
      // With a single legal value, every operand is that value.
      expect(p.operandA, 5);
      expect(p.operandB, 5);
    }
  });

  test('custom subtraction with a normal range still produces valid problems', () {
    gp.setUseCustomSettings(true);
    gp.setCustomOperations({'subtraction'});
    gp.setCustomRange(min: 1, max: 10);

    for (var i = 0; i < 100; i++) {
      final p = MathProblem.generateProblem(gp, 1, sri);
      expect(p.operation, MathOperation.subtraction);
      expect(p.isValid(), isTrue);
      expect(p.answer, isNonNegative);
      expect(p.operandA, greaterThanOrEqualTo(p.operandB));
      expect(p.operandA, inInclusiveRange(1, 10));
      expect(p.operandB, inInclusiveRange(1, 10));
    }
  });
}
