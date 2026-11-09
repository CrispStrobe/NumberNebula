// Unit tests for GameProvider progression core: reportOutcome /
// canAdvanceToNextLevel and the "3 wins AND mastery" advance gate.
//
// GameProvider constructor-injects ProgressService, SriService and
// CognitiveProfileService. Those are concrete classes (not interfaces),
// so we subclass each to build controllable spies that:
//   * record which methods were called (routing assertions), and
//   * return a deterministic mastery verdict.
//
// Mastery for arithmetic flows through SriService.getDetailedBreakdown()
// (consumed by GameProvider._checkArithmeticMastery), so the fake SRI
// overrides that to synthesize a "all-mastered" or "nothing-tracked"
// breakdown on demand. Mastery for non-arithmetic flows through
// CognitiveProfileService.hasMastery, overridden directly.
//
// NOTE on AppConfig.inappsActive: it is a compile-time `const false` in
// this build, so GameProvider unlocks the full version in its constructor.
// That does not affect the progression paths under test; we don't assert
// on it.

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

/// ProgressService whose save is a no-op (avoids touching the real provider
/// serialization path during the test; we still call setMockInitialValues so
/// any SharedPreferences access in the services resolves cleanly).
class FakeProgressService extends ProgressService {
  @override
  Future<void> saveProgress(GameProvider gameProvider) async {}
}

/// SriService spy. Records every recordResponse call and returns a
/// caller-controlled detailed breakdown so arithmetic mastery is
/// deterministic.
class FakeSriService extends SriService {
  final List<MathProblem> recorded = [];

  /// When true, getDetailedBreakdown reports a large, fully-mastered set so
  /// _checkArithmeticMastery returns true. When false, reports nothing
  /// tracked so it returns false.
  bool grantArithmeticMastery = false;

  @override
  void recordResponse(MathProblem problem, bool wasCorrect) {
    recorded.add(problem);
    // Deliberately do NOT call super: the real impl hits SharedPreferences
    // and notifies; we only care about the routing/recording fact here.
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
              // All tracked are mastered -> ratio 1.0 >= passThreshold.
              mastered: tracked,
              averageEasiness: 2.5,
            ),
        },
    };
  }
}

/// CognitiveProfileService spy. Records recordAttempt calls and returns a
/// caller-controlled mastery verdict.
class FakeCognitiveProfileService extends CognitiveProfileService {
  int recordAttemptCalls = 0;
  bool grantMastery = false;

  @override
  void recordAttempt(SkillCategory skill, int difficulty, bool success) {
    recordAttemptCalls++;
    // Do NOT call super (it persists and notifies).
  }

  @override
  bool hasMastery(SkillCategory skill, int difficulty,
      {double threshold = kDefaultPassThreshold}) {
    return grantMastery;
  }
}

GameProvider buildProvider(
  FakeSriService sri,
  FakeCognitiveProfileService cog,
) {
  return GameProvider(
    progressService: FakeProgressService(),
    sriService: sri,
    cognitiveProfileService: cog,
  );
}

MathProblem sampleProblem() => MathProblem.addition(2, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSriService sri;
  late FakeCognitiveProfileService cog;
  late GameProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sri = FakeSriService();
    cog = FakeCognitiveProfileService();
    provider = buildProvider(sri, cog);
  });

  // 'puzzle_math' is an arithmetic game; 'magic_triangles' is
  // patternRecognition (non-arithmetic). Both are in gameSkillMap.
  const arithmeticGame = 'puzzle_math';
  const nonArithmeticGame = 'magic_triangles';

  GameOutcome win(String gameType, {List<MathProblem> problems = const []}) =>
      GameOutcome.win(
        gameType: gameType,
        difficulty: 1,
        score: 10,
        mathProblems: problems,
      );

  test('fewer than 3 wins does not advance even with mastery granted', () {
    sri.grantArithmeticMastery = true; // mastery is satisfied
    bool advanced = false;
    for (var i = 0; i < kWinsRequiredForLevelUp - 1; i++) {
      advanced = provider.reportOutcome(
        win(arithmeticGame, problems: [sampleProblem()]),
      );
    }
    expect(advanced, isFalse);
    expect(provider.getGameProgress(arithmeticGame), 0,
        reason: 'No advance => level untouched (default 0).');
    expect(
      provider.canAdvanceToNextLevel(arithmeticGame, 1),
      isFalse,
      reason: 'Only ${kWinsRequiredForLevelUp - 1} wins recorded.',
    );
  });

  test('3 wins but mastery false does not advance', () {
    sri.grantArithmeticMastery = false; // mastery NOT satisfied
    bool advanced = false;
    for (var i = 0; i < kWinsRequiredForLevelUp; i++) {
      advanced = provider.reportOutcome(
        win(arithmeticGame, problems: [sampleProblem()]),
      );
    }
    expect(advanced, isFalse,
        reason: 'Win count met but mastery gate failed.');
    expect(provider.getGameProgress(arithmeticGame), 0);
    // Win threshold is met, so the gate must be failing purely on mastery.
    expect(provider.canAdvanceToNextLevel(arithmeticGame, 1), isFalse);
  });

  test('3 wins + mastery true advances and resets current-level wins', () {
    sri.grantArithmeticMastery = true;

    // First two wins: gate not yet open (need 3).
    expect(
      provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()])),
      isFalse,
    );
    expect(
      provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()])),
      isFalse,
    );

    // Third win opens the gate and advances.
    final advanced =
        provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()]));
    expect(advanced, isTrue);

    // Level went from default(1) to 2.
    expect(provider.getGameProgress(arithmeticGame), 2);

    // currentLevelWins reset to 0: a single subsequent win must NOT advance.
    final advancedAgain =
        provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()]));
    expect(advancedAgain, isFalse,
        reason: 'Win counter should have reset to 0 after advancing.');
    expect(provider.canAdvanceToNextLevel(arithmeticGame, 2), isFalse);
  });

  test('arithmetic outcome routes math problems to SriService only', () {
    final problems = [sampleProblem(), MathProblem.multiplication(3, 4)];
    provider.reportOutcome(win(arithmeticGame, problems: problems));

    expect(sri.recorded.length, problems.length,
        reason: 'Each MathProblem should be recorded once via SRI.');
    expect(cog.recordAttemptCalls, 0,
        reason: 'Arithmetic must not touch CognitiveProfileService.');
  });

  test('non-arithmetic outcome routes to CognitiveProfileService only', () {
    cog.grantMastery = false;
    // mathProblems present but should be ignored for routing on a
    // non-arithmetic game type.
    provider.reportOutcome(
      win(nonArithmeticGame, problems: [sampleProblem()]),
    );

    expect(cog.recordAttemptCalls, 1,
        reason: 'Non-arithmetic should record one cognitive attempt.');
    expect(sri.recorded, isEmpty,
        reason: 'Non-arithmetic must not touch SriService.');
  });

  test('non-arithmetic 3-wins + mastery advances via cognitive gate', () {
    cog.grantMastery = true;
    bool advanced = false;
    for (var i = 0; i < kWinsRequiredForLevelUp; i++) {
      advanced = provider.reportOutcome(win(nonArithmeticGame));
    }
    expect(advanced, isTrue);
    expect(provider.getGameProgress(nonArithmeticGame), 2);
  });

  test('a loss does not increment the win counter', () {
    sri.grantArithmeticMastery = true;
    // Two wins...
    provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()]));
    provider.reportOutcome(win(arithmeticGame, problems: [sampleProblem()]));
    // ...then a loss should not count toward the 3-win threshold.
    provider.reportOutcome(GameOutcome.loss(
      gameType: arithmeticGame,
      difficulty: 1,
      mathProblems: [sampleProblem()],
    ));
    expect(provider.canAdvanceToNextLevel(arithmeticGame, 1), isFalse,
        reason: 'Loss must not satisfy the 3-win gate.');
  });

  test('unknown game type returns false and records nothing', () {
    final advanced = provider.reportOutcome(GameOutcome.win(
      gameType: 'not_a_real_game',
      difficulty: 1,
      score: 5,
      mathProblems: [sampleProblem()],
    ));
    expect(advanced, isFalse);
    expect(sri.recorded, isEmpty);
    expect(cog.recordAttemptCalls, 0);
  });
}
