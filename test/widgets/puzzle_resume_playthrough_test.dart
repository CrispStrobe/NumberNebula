import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/star_forge_game.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  testWidgets(
      'place a brick, leave, restore exact star, finish once and clear save',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_seen_star_forge_guided_v1': true});
    ProfilePreferences.activeId = 'default';
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService());
    final debug = DebugProvider();
    Widget app() => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: gp),
              ChangeNotifierProvider.value(value: debug)
            ],
            child: MaterialApp(
                localizationsDelegates: S.localizationsDelegates,
                supportedLocales: S.supportedLocales,
                home: const StarForgeGame(grade: 1, level: 1)));
    await tester.pumpWidget(app());
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    dynamic state = tester.state(find.byType(StarForgeGame));
    final puzzle = state.puzzle as StarForgePuzzle;
    final nodes = puzzle.emptyNodes.toList()..sort();
    final number = puzzle.solution[nodes.first]!;
    final source =
        find.byWidgetPredicate((w) => w is Draggable<int> && w.data == number);
    final target = find.byType(DragTarget<int>).first;
    await tester.dragFrom(tester.getCenter(source),
        tester.getCenter(target) - tester.getCenter(source));
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.userSolution[nodes.first], number);
    final before = Map<String, dynamic>.from(state.capturePuzzleSession());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final saved = await PuzzleSessionStore.instance.load('star_forge', 1, 1);
    expect(saved, before);
    expect(gp.score, 0);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continue your puzzle?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    state = tester.state(find.byType(StarForgeGame));
    expect(state.capturePuzzleSession(), before);
    expect(gp.score, 0);
    final lastNumber = puzzle.solution[nodes.last]!;
    final lastSource = find
        .byWidgetPredicate((w) => w is Draggable<int> && w.data == lastNumber);
    final lastTarget = find.byType(DragTarget<int>).first;
    await tester.dragFrom(tester.getCenter(lastSource),
        tester.getCenter(lastTarget) - tester.getCenter(lastSource));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(gp.outcomeCount, 1);
    expect(gp.score, 125);
    expect(await PuzzleSessionStore.instance.load('star_forge', 1, 1), isNull);
    expect(find.text('Try suggested round'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(await PuzzleSessionStore.instance.list(), isEmpty);
  });
}
