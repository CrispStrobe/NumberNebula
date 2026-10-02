import 'dart:io';
import 'package:space_math_academy/features/games/data/gridlock_puzzles_data.dart';
import 'package:space_math_academy/features/games/screens/levels.dart';
import 'dart:convert';
import 'package:space_math_academy/features/games/services/board_hint_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_image_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/features/games/services/gridlock_puzzle_tracker.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/game_registry.dart';
import 'package:space_math_academy/features/games/mixins/puzzle_session_mixin.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  // Load shared asset futures outside per-test fake timer zones. Their cached
  // completions must remain usable across repeated samples.
  setUpAll(() async {
    await loadMoleculeLevels();
    await GridlockPuzzleDatabase.load();
  });
  const output = String.fromEnvironment('CALIBRATION_OUTPUT');
  const reduceMotion = bool.fromEnvironment('CALIBRATION_REDUCE_MOTION');
  final grades =
      const String.fromEnvironment('CALIBRATION_GRADES', defaultValue: '1')
          .split(',')
          .map(int.parse);
  final levels =
      const String.fromEnvironment('CALIBRATION_LEVELS', defaultValue: '1')
          .split(',')
          .map(int.parse);
  const samples = int.fromEnvironment('CALIBRATION_SAMPLES', defaultValue: 1);
  for (final grade in grades) {
    for (final level in levels) {
      for (int sample = 0; sample < samples; sample++) {
        for (final key in registeredGameKeys) {
          testWidgets(
              '$key g$grade l$level sample$sample restores its complete gameplay snapshot',
              (tester) async {
            SharedPreferences.setMockInitialValues({
              'onboarding_seen_${key}_all_games_guided_v1': true,
            });
            ProfilePreferences.activeId = 'default';
            PuzzleSessionStore.resetForTesting();
            tester.view.physicalSize = const Size(1600, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final sri = SriService();
            final cognitive = CognitiveProfileService();
            final gp = GameProvider(
                progressService: ProgressService(),
                sriService: sri,
                cognitiveProfileService: cognitive);
            Widget app() => MultiProvider(
                    providers: [
                      ChangeNotifierProvider.value(value: gp),
                      ChangeNotifierProvider.value(value: sri),
                      ChangeNotifierProvider.value(value: cognitive),
                      ChangeNotifierProvider(create: (_) => DebugProvider()),
                      ChangeNotifierProvider(
                          create: (_) => GridlockPuzzleTracker()),
                    ],
                    child: MaterialApp(
                        localizationsDelegates: S.localizationsDelegates,
                        supportedLocales: S.supportedLocales,
                        builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(disableAnimations: reduceMotion),
                              child: child!,
                            ),
                        home: gameBuilderFor(key)!(grade, level)));
            await tester.runAsync(() => loadGameLibrary(key));
            if (key == 'puzzle_math') {
              await tester.runAsync(PuzzleImageService.instance.init);
            }
            gp.fromJson({
              'grade': grade,
              'gameProgress': {key: level}
            });
            final readyClock = Stopwatch()..start();
            await tester.pumpWidget(app());
            final finder = find.byWidgetPredicate((w) =>
                w is StatefulWidget &&
                !w.runtimeType.toString().startsWith('_'));
            dynamic session;
            Map<String, dynamic>? before;
            for (int i = 0; i < 300 && before == null; i++) {
              await tester.pump(const Duration(milliseconds: 100));
              await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 50)));
              for (final element in tester.elementList(finder)) {
                if (element is StatefulElement &&
                    element.state is PuzzleSessionMixin) {
                  session = element.state;
                  before =
                      session.capturePuzzleSession() as Map<String, dynamic>?;
                  if (before != null) break;
                }
              }
            }

            expect(before, isNotNull,
                reason: 'No initialized save adapter for $key');
            readyClock.stop();
            if (key == 'star_loader_game' && grade == 6 && level == 10) {
              expect(before!['_optimalMoves'], greaterThanOrEqualTo(24),
                  reason: 'A search timeout must not weaken the existing push target');
            }
            for (final german in [false, true]) {
              final hint = findBoardHint(key, before!, german: german);
              expect(hint, isNotNull,
                  reason: '$key lacks board-aware coaching');
              expect(hint!.working, isNotEmpty);
            }
            if (output.isNotEmpty) {
              File(output).writeAsStringSync(
                  '${jsonEncode({
                        'game': key,
                        'grade': grade,
                        'level': level,
                        'sample': sample,
                        'readyWallMs': readyClock.elapsedMilliseconds,
                        'state': before
                      })}\n',
                  mode: FileMode.append);
            }

            // Pause physics, then take an immutable disk round trip. This exercises
            // every model codec, final collection, derived field and restore hook.
            final pause = GamePauseScope.of(session.context as BuildContext)!;
            if (key == 'asteroid_math') {
              if (reduceMotion) {
                final previousTime =
                    session.capturePuzzleSession()['timeLeft'] as int;
                await tester.pump(const Duration(seconds: 2));
                expect(session.capturePuzzleSession()['timeLeft'],
                    lessThan(previousTime),
                    reason:
                        'Reduced motion must preserve essential timed gameplay');
              }
              final time = session.capturePuzzleSession()['timeLeft'];
              await tester.tap(find
                  .text(S.of(session.context as BuildContext)!.hintStrategy)
                  .first);
              await tester.pump();
              await tester.pump(const Duration(seconds: 2));
              expect(pause.paused, isTrue);
              expect(session.capturePuzzleSession()['timeLeft'], time,
                  reason: 'Coaching must freeze the active game timer');
              expect(gp.coachingHintsUsed, 1);
              await tester.tap(find
                  .text(S.of(session.context as BuildContext)!.hintTryMyself));
              await tester.pump();
            }
            pause.setPaused(true);
            before = session.capturePuzzleSession() as Map<String, dynamic>;
            final disk = Map<String, dynamic>.from(
                jsonDecode(jsonEncode(before)) as Map);
            session.applyPuzzleSession(disk);
            final after =
                session.capturePuzzleSession() as Map<String, dynamic>;
            // Active play time is expected to grow while this assertion runs.
            before.remove('_elapsed');
            after.remove('_elapsed');
            expect(after, before,
                reason: 'State changed during disk round trip for $key');
            expect(gp.outcomeCount, 0,
                reason: 'Restore must not award completion');
            session.savePuzzleSession();
            final saved =
                await PuzzleSessionStore.instance.load(key, grade, level);
            expect(saved, isNotNull);
            expect(saved!['_coachingHints'], key == 'asteroid_math' ? 1 : 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            // Recreate the screen from disk, choose Continue, and verify that no
            // generator has replaced the saved board and no reward was awarded.
            await tester.pumpWidget(app());
            for (int i = 0;
                i < 15 && find.text('Continue').evaluate().isEmpty;
                i++) {
              await tester.pump(const Duration(milliseconds: 100));
              await tester.runAsync(() => Future<void>.delayed(Duration.zero));
            }
            expect(find.text('Continue'), findsOneWidget,
                reason: '$key did not offer resume');
            await tester.tap(find.text('Continue'));
            await tester.pump();
            dynamic resumed;
            for (final element in tester.elementList(finder)) {
              if (element is StatefulElement &&
                  element.state is PuzzleSessionMixin) {
                resumed = element.state;
              }
            }
            GamePauseScope.of(resumed.context as BuildContext)!.setPaused(true);
            expect(gp.coachingHintsUsed, key == 'asteroid_math' ? 1 : 0);
            final restored =
                resumed.capturePuzzleSession() as Map<String, dynamic>;
            restored.remove('_elapsed');
            // Floating objects may advance one display frame while the dialog closes.
            // Their exact coordinates were already verified by the JSON round trip.
            if (![
              'asteroid_math',
              'hyperdrive_gates',
              'planet_hopping',
              'pathfinder'
            ].contains(key)) {
              expect(restored, before,
                  reason: '$key did not restore its saved state');
            } else {
              for (final field in [
                'timeLeft',
                'currentTargetIndex',
                'lives',
                'gatesCleared',
                'problemsSolved',
                'nextTargetIndex'
              ]) {
                if (before.containsKey(field)) {
                  expect(restored[field], before[field],
                      reason: '$key reset $field');
                }
              }
            }
            expect(gp.outcomeCount, 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await PuzzleSessionStore.instance.clear(key);
          });
        }
      }
    }
  }
}
