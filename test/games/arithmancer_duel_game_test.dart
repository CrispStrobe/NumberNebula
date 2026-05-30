// Smoke / build test for arithmancer_duel_game.dart.
//
// Why a smoke test (and not a focused unit test of this file):
//   The screen's game logic — battlefield evaluation (_executeBattlefield),
//   damage application, turn handling, hand/deck syncing and expression →
//   MathProblem parsing (_parseExpressionToProblem) — all lives in PRIVATE
//   instance methods of the State class, bound to a live BuildContext, a
//   GameProvider/SriService, eleven AnimationControllers (several repeating
//   forever) and showDialog()/HapticFeedback calls. None of that is reachable
//   without a dependency-injection seam we are not allowed to add. The
//   genuinely pure mathematical-combat logic the screen relies on
//   (ArithmancerGame, ExpressionEvaluator, MathResult and the AI personalities)
//   lives in shared/utils/arithmancer.dart and is already unit-tested directly
//   in arithmancer_test.dart.
//
// What this test proves: ArithmancerDuelGame constructs and renders its first
// frame inside the real provider tree it reads from (GameProvider / SriService)
// plus the app's localization delegates, without throwing. The game is set up
// synchronously in initState (no async puzzle generation), so the first frame
// is the live board.
//
// We deliberately use a single pump() and never pumpAndSettle(): the pulse /
// glow / shield / particle AnimationControllers repeat forever and would hang
// settle. The particle controller also drives a 16ms repeating timer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/arithmancer_duel_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // GameProvider / the services may touch shared_preferences; give them a
    // clean, in-memory store so construction never hits a real plugin.
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness(GameMode mode) {
    final progressService = ProgressService();
    final sriService = SriService();
    final cognitiveProfileService = CognitiveProfileService();
    final gameProvider = GameProvider(
      progressService: progressService,
      sriService: sriService,
      cognitiveProfileService: cognitiveProfileService,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gameProvider),
        ChangeNotifierProvider.value(value: sriService),
        ChangeNotifierProvider.value(value: cognitiveProfileService),
        Provider.value(value: progressService),
      ],
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: ArithmancerDuelGame(grade: 1, level: 1, gameMode: mode),
      ),
    );
  }

  // A generously sized landscape surface so the dense board (deck / opponent /
  // battlefield / player / hand columns) lays out without RenderFlex overflow,
  // which the test framework reports as an exception.
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('builds its first frame in vsPrograms mode inside the real '
      'provider tree without throwing', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(buildHarness(GameMode.vsPrograms));
    // Single pump only: the screen runs infinitely-repeating animations and a
    // 16ms particle timer, so pumpAndSettle would hang.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ArithmancerDuelGame), findsOneWidget);
  });

  testWidgets('builds its first frame in vsPlayers (PvP) mode without throwing',
      (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(buildHarness(GameMode.vsPlayers));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ArithmancerDuelGame), findsOneWidget);
  });
}
