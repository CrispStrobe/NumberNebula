// Round-trip tests for ProgressService, the serialization layer over
// GameProvider. We save a mutated provider's state to (mocked)
// SharedPreferences, then load it into a fresh provider and assert the
// key fields survive the round-trip.
//
// Note: GameProvider forces `isFullVersionUnlocked = true` when
// AppConfig.inappsActive is false (the current build flag), so that
// field is not a meaningful round-trip target and is not asserted here.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';

GameProvider makeProvider() {
  return GameProvider(
    progressService: ProgressService(),
    sriService: SriService(),
    cognitiveProfileService: CognitiveProfileService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save then load round-trips core scalar fields', () async {
    final service = ProgressService();

    final source = makeProvider();
    source.addScore(250);
    source.setGrade(3); // setGrade resets level to 1
    source.setLevel(7);
    source.updateGameProgress('codebreaker', 4);
    source.updateGameProgress('kenken', 2);

    await service.saveProgress(source);

    final fresh = makeProvider();
    // Confirm fresh provider starts at defaults distinct from source.
    expect(fresh.score, 0);
    expect(fresh.grade, 1);

    await service.loadProgress(fresh);

    expect(fresh.score, 250);
    expect(fresh.grade, 3);
    expect(fresh.level, 7);
    expect(fresh.getGameProgress('codebreaker'), 4);
    expect(fresh.getGameProgress('kenken'), 2);
  });

  test('round-trips difficulty mode and symbol settings', () async {
    final service = ProgressService();

    final source = makeProvider();
    source.setDifficultyMode(DifficultyMode.challenge);
    source.setMultiplicationSymbol('*');
    source.setDivisionSymbol(':');

    await service.saveProgress(source);

    final fresh = makeProvider();
    expect(fresh.difficultyMode, DifficultyMode.normal);

    await service.loadProgress(fresh);

    expect(fresh.difficultyMode, DifficultyMode.challenge);
    expect(fresh.multiplicationSymbol, '*');
    expect(fresh.divisionSymbol, ':');
  });

  test('loadProgress with no saved data leaves provider at defaults',
      () async {
    final service = ProgressService();
    final fresh = makeProvider();

    await service.loadProgress(fresh);

    expect(fresh.score, 0);
    expect(fresh.level, 1);
    expect(fresh.grade, 1);
    expect(fresh.gameProgress, isEmpty);
  });

  test('gameProgress map and achievements survive the round-trip',
      () async {
    final service = ProgressService();

    final source = makeProvider();
    // Score >= 100 unlocks the 'first_century' achievement.
    source.addScore(120);
    expect(source.hasAchievement('first_century'), isTrue);

    await service.saveProgress(source);

    final fresh = makeProvider();
    expect(fresh.hasAchievement('first_century'), isFalse);

    await service.loadProgress(fresh);

    expect(fresh.hasAchievement('first_century'), isTrue);
    expect(fresh.score, 120);
  });
}
