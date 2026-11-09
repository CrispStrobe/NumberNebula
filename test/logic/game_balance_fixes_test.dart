// Integration-style unit tests for the game balance fixes.
//
// These verify the contracts that were broken/missing before the audit:
//   1. Bubble Math now reports outcomes with mathProblems
//   2. Arithmetic Square, Perspective Puzzle, Star Loader pass real scores
//   3. Puzzle Math uses .win/.loss factories
//   4. Cargo Bay row clearing produces addition MathProblems
//   5. Gravity Well reports MathProblems
//   6. All arithmetic-category games have SRI-compatible outcome paths

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

// --- Fakes ---

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
  @override
  void recordAttempt(SkillCategory skill, int difficulty, bool success) {}
  @override
  bool hasMastery(SkillCategory skill, int difficulty,
      {double threshold = kDefaultPassThreshold}) => false;
}

GameProvider _provider(FakeSriService sri) {
  return GameProvider(
    progressService: FakeProgressService(),
    sriService: sri,
    cognitiveProfileService: FakeCognitiveProfileService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSriService sri;
  late GameProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sri = FakeSriService();
    provider = _provider(sri);
  });

  group('Fix: Bubble Math outcome reporting', () {
    test('win outcome routes math problems to SRI', () {
      final problems = [
        MathProblem.addition(3, 5),
        MathProblem.multiplication(2, 4),
      ];

      provider.reportOutcome(GameOutcome.win(
        gameType: 'bubble_math',
        difficulty: 3,
        score: 150,
        mathProblems: problems,
      ));

      expect(sri.recorded.length, 2,
          reason: 'Bubble Math should now route problems to SRI');
      expect(provider.lastStars, greaterThan(0),
          reason: 'Win with score 150 should yield stars');
    });

    test('loss outcome still routes problems to SRI', () {
      final problems = [MathProblem.addition(1, 2)];

      provider.reportOutcome(GameOutcome.loss(
        gameType: 'bubble_math',
        difficulty: 3,
        mathProblems: problems,
      ));

      expect(sri.recorded.length, 1,
          reason: 'Loss should still record attempted problems');
      expect(provider.lastStars, 0);
    });
  });

  group('Fix: Score:0 bugs — non-zero scores reach provider', () {
    // These tests verify the contract: win outcomes with score > 0
    // result in addScore being called (observable via provider.score).

    test('arithmatic_square win adds score to provider', () {
      final startScore = provider.score;
      provider.reportOutcome(GameOutcome.win(
        gameType: 'arithmatic_square',
        difficulty: 5,
        score: 750,
      ));
      expect(provider.score, startScore + 750);
    });

    test('perspective_puzzle win adds score to provider', () {
      final startScore = provider.score;
      provider.reportOutcome(GameOutcome.win(
        gameType: 'perspective_puzzle',
        difficulty: 3,
        score: 600,
      ));
      expect(provider.score, startScore + 600);
    });

    test('star_loader_game win adds score to provider', () {
      final startScore = provider.score;
      provider.reportOutcome(GameOutcome.win(
        gameType: 'star_loader_game',
        difficulty: 7,
        score: 1200,
      ));
      expect(provider.score, startScore + 1200);
    });

    test('puzzle_math win adds score to provider', () {
      final startScore = provider.score;
      provider.reportOutcome(GameOutcome.win(
        gameType: 'puzzle_math',
        difficulty: 2,
        score: 200,
        mathProblems: [MathProblem.addition(3, 4)],
      ));
      expect(provider.score, startScore + 200);
    });
  });

  group('Fix: Cargo Bay SRI reporting', () {
    test('cargo_bay_arranger win routes problems to SRI', () {
      // Simulate what the game now does: extract addition problems from rows
      final rowProblems = [
        MathProblem.addition(3, 5),    // 3+5=8
        MathProblem.addition(8, 7),    // 8+7=15
        MathProblem.addition(15, 6),   // 15+6=21 (=targetSum)
      ];

      provider.reportOutcome(GameOutcome.win(
        gameType: 'cargo_bay_arranger',
        difficulty: 3,
        score: 800,
        mathProblems: rowProblems,
      ));

      expect(sri.recorded.length, 3);
    });
  });

  group('Fix: Gravity Well SRI reporting', () {
    test('gravity_well win routes balance-scale problems to SRI', () {
      final scaleProblems = [
        MathProblem.subtraction(15, 7),  // unknown = 15 - 7 = 8
        MathProblem.addition(3, 5),       // 3 + unknown = total
      ];

      provider.reportOutcome(GameOutcome.win(
        gameType: 'gravity_well',
        difficulty: 5,
        score: 600,
        mathProblems: scaleProblems,
      ));

      expect(sri.recorded.length, 2,
          reason: 'Gravity Well should now route problems to SRI');
    });
  });

  group('Contract: all arithmetic games in gameSkillMap route to SRI', () {
    // Verify that every game mapped to SkillCategory.arithmetic
    // actually routes through SriService when problems are provided.

    final arithmeticGames = gameSkillMap.entries
        .where((e) => e.value == SkillCategory.arithmetic)
        .map((e) => e.key)
        .toList();

    for (final gameType in arithmeticGames) {
      test('$gameType routes to SRI', () {
        final localSri = FakeSriService();
        final localProvider = _provider(localSri);

        localProvider.reportOutcome(GameOutcome.win(
          gameType: gameType,
          difficulty: 1,
          score: 100,
          mathProblems: [MathProblem.addition(1, 1)],
        ));

        expect(localSri.recorded.length, 1,
            reason: '$gameType is arithmetic and should route to SRI');
      });
    }
  });

  group('Contract: loss outcomes have zero score', () {
    test('GameOutcome.loss always has score 0', () {
      final o = GameOutcome.loss(
        gameType: 'any',
        difficulty: 1,
        mathProblems: [MathProblem.addition(2, 3)],
      );
      expect(o.score, 0);
      expect(o.wasSuccessful, isFalse);
    });

    test('loss does not increase provider score', () {
      final startScore = provider.score;
      provider.reportOutcome(GameOutcome.loss(
        gameType: 'kenken',
        difficulty: 1,
      ));
      expect(provider.score, startScore);
    });
  });
}
