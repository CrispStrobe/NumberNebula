import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/asteroid_math_game.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/features/games/widgets/space_background.dart';
import 'package:space_math_academy/generated/l10n.dart';

Map<String, dynamic> snapshot(dynamic session) => Map<String, dynamic>.from(
    jsonDecode(jsonEncode(session.capturePuzzleSession())) as Map);

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
        'asteroid moving hit targets, pause and frame isolation '
        '(reduced motion: $reducedMotion)', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_seen_asteroid_math_all_games_guided_v1': true,
      });
      ProfilePreferences.activeId = 'default';
      PuzzleSessionStore.resetForTesting();
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final sri = SriService();
      final cognitive = CognitiveProfileService();
      final gp = GameProvider(
          progressService: ProgressService(),
          sriService: sri,
          cognitiveProfileService: cognitive);
      gp.fromJson({
        'grade': 1,
        'gameProgress': {'asteroid_math': 1},
      });
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: GameLearningShell(
            gameKey: 'asteroid_math',
            builder: (_) => const AsteroidMathGame(grade: 1, level: 1),
          ),
        ),
      ));

      dynamic session;
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        if (find.byType(AsteroidMathGame).evaluate().isNotEmpty) {
          session = tester.state(find.byType(AsteroidMathGame));
          if (session.capturePuzzleSession() != null) break;
        }
      }
      expect(session, isNotNull);
      expect(session.capturePuzzleSession(), isNotNull);
      final pause = GamePauseScope.of(session.context as BuildContext)!;
      pause.setPaused(true);

      final problems = [MathProblem.addition(1, 1), MathProblem.addition(2, 2)];
      final asteroids = [
        for (var i = 0; i < problems.length; i++)
          Asteroid(
            id: i,
            problem: problems[i],
            position: Offset(200 + 180 * i.toDouble(), 220),
            velocity: const Offset(120, 40),
            size: 64,
            rotationSpeed: 0.5,
            rotation: 0,
            type: AsteroidType.rocky,
            hue: 120,
          ),
      ];
      session.applyPuzzleSession({
        'asteroids': asteroids.map((a) => a.toJson()).toList(),
        'targetOrder': [2, 4],
        'currentTargetIndex': 0,
        'timeLeft': 60,
        'wrongShots': 0,
        'levelProblems': problems.map((p) => p.toJson()).toList(),
      });
      pause.setPaused(false);
      await tester.pump(const Duration(milliseconds: 20));
      // Flush the first frame's rebuild before observing widget identity.
      await tester.pump();
      final header = tester.widget<GameUI>(find.byType(GameUI));
      final background =
          tester.widget<SpaceBackground>(find.byType(SpaceBackground));
      final before = snapshot(session);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final after = snapshot(session);
      expect(after['asteroids'][0]['position'],
          isNot(equals(before['asteroids'][0]['position'])),
          reason: 'Essential gameplay must move even with reduced motion');
      expect(after['asteroids'][0]['rotation'],
          greaterThan(before['asteroids'][0]['rotation'] as num));

      const renderPath = String.fromEnvironment('ASTEROID_RENDER_PATH',
          defaultValue: 'cached');
      if (renderPath != 'legacy') {
        expect(tester.widget<GameUI>(find.byType(GameUI)), same(header),
            reason: 'Simulation frames must not rebuild the game header');
        expect(tester.widget<SpaceBackground>(find.byType(SpaceBackground)),
            same(background),
            reason: 'Simulation frames must not rebuild the background');
      }

      final paintFinder = find.byWidgetPredicate((widget) =>
          widget is CustomPaint && widget.painter is GameObjectsPainter);
      final playfieldOrigin = tester.getTopLeft(paintFinder);
      for (final asteroid in after['asteroids'] as List) {
        final hit = find.byKey(ValueKey('asteroid_hit_${asteroid['id']}'));
        final position = asteroid['position'] as List;
        final expected = playfieldOrigin +
            Offset((position[0] as num).toDouble(),
                (position[1] as num).toDouble());
        expect((tester.getCenter(hit) - expected).distance, lessThan(0.001),
            reason: 'Hit target must track the currently painted asteroid');
      }

      pause.setPaused(true);
      final paused = snapshot(session);
      await tester.pump(const Duration(seconds: 2));
      expect(snapshot(session), paused,
          reason: 'Pause must freeze both physics and the countdown');
      pause.setPaused(false);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const ValueKey('asteroid_hit_0')));
      await tester.pump();
      final tapped = snapshot(session);
      expect(tapped['currentTargetIndex'], 1);
      expect((tapped['asteroids'] as List).map((a) => a['id']), [1],
          reason: 'Tapping the moving correct target must remove that target');
      expect(tapped['wrongShots'], 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
