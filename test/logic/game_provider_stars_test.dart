// Unit tests for the star-rating tracking added to GameProvider.
//
// Tests that reportOutcome computes lastStars and updates bestStars,
// and that bestStars persists across save/load cycles.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/models/skill_category.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/models/game_outcome.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/tuning.dart';

// --- Fakes (same pattern as game_provider_test.dart) ---

class FakeProgressService extends ProgressService {
  @override
  Future<void> saveProgress(GameProvider gameProvider) async {}
}

class FakeSriService extends SriService {
  final List<MathProblem> recorded = [];
  bool grantArithmeticMastery = false;

  @override
  void recordResponse(MathProblem problem, bool wasCorrect) {
    recorded.add(problem);
  }

  @override
  Map<MathOperation, Map<NumberRange, OperationStat>> getDetailedBreakdown() {
    final tracked = grantArithmeticMastery ? kMinTrackedProblemsForMastery : 0;
    return {
      for (final op in MathOperation.values)
        op: {
          for (final range in NumberRange.values)
            range: OperationStat(
              tracked: tracked,
              mastered: tracked,
              averageEasiness: 2.5,
            ),
        },
    };
  }
}

class FakeCognitiveProfileService extends CognitiveProfileService {
  int recordAttemptCalls = 0;
  bool grantMastery = false;

  @override
  void recordAttempt(SkillCategory skill, int difficulty, bool success) {
    recordAttemptCalls++;
  }

  @override
  bool hasMastery(SkillCategory skill, int difficulty,
      {double threshold = kDefaultPassThreshold}) {
    return grantMastery;
  }
}

GameProvider _buildProvider(FakeSriService sri, FakeCognitiveProfileService cog) {
  return GameProvider(
    progressService: FakeProgressService(),
    sriService: sri,
    cognitiveProfileService: cog,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSriService sri;
  late FakeCognitiveProfileService cog;
  late GameProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sri = FakeSriService();
    cog = FakeCognitiveProfileService();
    provider = _buildProvider(sri, cog);
  });

  group('lastStars computation', () {
    test('loss yields 0 stars', () {
      provider.reportOutcome(GameOutcome.loss(
        gameType: 'kenken',
        difficulty: 1,
      ));
      expect(provider.lastStars, 0);
    });

    test('low-score win yields 1 star', () {
      // kenken thresholds: [300, 800, 1200]
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 100,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.lastStars, 1);
    });

    test('mid-score win yields 2 stars', () {
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 900,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.lastStars, 2);
    });

    test('high-score win yields 3 stars', () {
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 1500,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.lastStars, 3);
    });
  });

  group('bestStars tracking', () {
    test('starts empty', () {
      expect(provider.bestStars, isEmpty);
    });

    test('first win sets bestStars', () {
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 900,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.bestStars['kenken'], 2);
    });

    test('higher star rating replaces lower', () {
      // 1 star
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 100,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.bestStars['kenken'], 1);

      // 3 stars — should replace
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 1500,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.bestStars['kenken'], 3);
    });

    test('lower star rating does NOT replace higher', () {
      // 3 stars first
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 1500,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.bestStars['kenken'], 3);

      // 1 star — should NOT replace
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 100,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      expect(provider.bestStars['kenken'], 3);
    });

    test('loss does not set bestStars (0 stars does not beat absent)', () {
      provider.reportOutcome(GameOutcome.loss(
        gameType: 'kenken',
        difficulty: 1,
      ));
      // 0 > 0 is false, so bestStars should NOT have an entry
      expect(provider.bestStars.containsKey('kenken'), isFalse);
    });

    test('tracks multiple games independently', () {
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 1500,
        mathProblems: [MathProblem.addition(2, 3)],
      ));
      provider.reportOutcome(GameOutcome.win(
        gameType: 'bubble_math',
        difficulty: 1,
        score: 100,
        mathProblems: [MathProblem.addition(1, 2)],
      ));

      expect(provider.bestStars['kenken'], 3);
      expect(provider.bestStars['bubble_math'], 1);
    });
  });

  group('bestStars persistence', () {
    test('toJson includes bestStars, fromJson restores it', () {
      provider.reportOutcome(GameOutcome.win(
        gameType: 'kenken',
        difficulty: 1,
        score: 1500,
        mathProblems: [MathProblem.addition(2, 3)],
      ));

      final json = provider.toJson();
      expect(json['bestStars'], isA<Map>());
      expect(json['bestStars']['kenken'], 3);

      // Create a fresh provider and load
      final provider2 = _buildProvider(FakeSriService(), FakeCognitiveProfileService());
      provider2.fromJson(json);
      expect(provider2.bestStars['kenken'], 3);
    });
  });
}
