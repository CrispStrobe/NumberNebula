import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/player_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/models/skill_category.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/models/game_outcome.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/missions/providers/mission_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test(
      'legacy progress survives, sibling starts clean, switching restores each child',
      () async {
    final profiles = PlayerProfileService();
    await profiles.load();
    final progress = ProgressService();
    final sri = SriService();
    final cognitive = CognitiveProfileService();
    final gp = GameProvider(
        progressService: progress,
        sriService: sri,
        cognitiveProfileService: cognitive);
    final missions = MissionProvider();
    gp.setGrade(3);
    gp.reportOutcome(GameOutcome.win(
        gameType: 'star_forge', difficulty: 1, score: 125, performance: 0.9));
    sri.recordResponse(MathProblem.addition(3, 4), false);
    cognitive.recordAttempt(SkillCategory.logicDeduction, 1, true);
    await missions.startMission(grade: 3, level: 1, locale: 'en');
    final missionId = missions.state!.mission.id;
    await PuzzleSessionStore.instance.save('star_forge', 3, 1, {
      'board': [1, 2],
      'moves': 4
    });
    await progress.saveProgress(gp);
    await sri.saveSriData();
    await cognitive.saveProfile();
    profiles.onSwitch = (id) async {
      await progress.saveProgress(gp);
      await sri.saveSriData();
      await cognitive.saveProfile();
      ProfilePreferences.activeId = id;
      await progress.loadProgress(gp);
      await sri.loadSriData();
      await cognitive.loadProfile();
      await missions.loadSaved();
    };
    await profiles.add('Lina');
    final sibling = profiles.players.last.id;
    await profiles.activate(sibling);
    expect(gp.grade, 1);
    expect(gp.score, 0);
    expect(gp.achievements, isEmpty);
    expect(gp.bestStars, isEmpty);
    expect(gp.roundHistory, isEmpty);
    expect(sri.totalTrackedProblems, 0);
    expect(cognitive.totalAttempts, 0);
    expect(missions.state, isNull);
    expect(await PuzzleSessionStore.instance.list(), isEmpty);
    gp.setGrade(2);
    await profiles.activate('default');
    expect(gp.grade, 3);
    expect(gp.score, 125);
    expect(gp.bestStars['star_forge'], 3);
    expect(gp.roundHistory, hasLength(1));
    expect(sri.totalTrackedProblems, 1);
    expect(cognitive.totalAttempts, greaterThan(0));
    expect(missions.state!.mission.id, missionId);
    expect(
        (await PuzzleSessionStore.instance.load('star_forge', 3, 1))!['moves'],
        4);
    await profiles.activate(sibling);
    expect(gp.grade, 2);
    final reopened = PlayerProfileService();
    await reopened.load();
    expect(reopened.active.name, 'Lina');
  });

  test(
      'a pending write keeps the profile it started with; language stays shared',
      () async {
    final pending = ProfilePreferences.getInstance();
    ProfilePreferences.activeId = 'sibling';
    await (await pending).setInt('grade', 3);
    final sibling = await ProfilePreferences.getInstance();
    expect(sibling.getInt('grade'), isNull);
    await sibling.setString('language', 'de');
    ProfilePreferences.activeId = 'default';
    final original = await ProfilePreferences.getInstance();
    expect(original.getInt('grade'), 3);
    expect(original.getString('language'), 'de');
  });

  test('queued puzzle saves cannot resurrect a completed round', () async {
    final store = PuzzleSessionStore();
    final old = store.save('star_forge', 1, 1, {'moves': 4});
    final latest = store.save('star_forge', 1, 1, {'moves': 3});
    await Future.wait([old, latest]);
    expect((await store.load('star_forge', 1, 1))!['moves'], 3);
    final save = store.save('star_forge', 1, 1, {'moves': 2});
    final clear = store.clear('star_forge');
    await Future.wait([save, clear]);
    expect(await store.list(), isEmpty);
    expect(await store.load('star_forge', 2, 1), isNull);
  });
  test('a gentler launched round uses its grade without changing the profile',
      () {
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService());
    gp.setGrade(3);
    expect(DifficultyManager.getDifficulty(gp, 1, gradeOverride: 2).grade, 2);
    expect(gp.grade, 3);
    expect(DifficultyManager.getDifficulty(gp, 1).grade, 3);
  });
  test('first-load asynchronous saves cannot overwrite the final round snapshot', () async {
    final progress = ProgressService();
    final gp = GameProvider(progressService: progress, sriService: SriService(), cognitiveProfileService: CognitiveProfileService());
    gp.reportOutcome(GameOutcome.win(gameType: 'star_forge', difficulty: 1, score: 125, performance: .9));
    await ProfilePreferences.flushWrites();
    final reopened = GameProvider(progressService: progress, sriService: SriService(), cognitiveProfileService: CognitiveProfileService());
    await progress.loadProgress(reopened);
    expect(reopened.score, 125); expect(reopened.bestStars['star_forge'], 3);
    expect(reopened.roundHistory, hasLength(1));
  });

}
