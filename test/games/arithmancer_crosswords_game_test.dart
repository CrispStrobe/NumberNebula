// Smoke / build test for arithmancer_crosswords_game.dart.
//
// Why a smoke test (and not a focused unit test of this file):
//   The screen's game logic — scoring (_handleSuccess/_getOperationBonus),
//   move accounting (_placeNumber/_updateNumberPool), solution checking and
//   problem extraction — all lives in PRIVATE instance methods of the State
//   class, bound to a live BuildContext, a GameProvider, several infinitely
//   repeating AnimationControllers and showDialog()/SnackBar calls. None of
//   that is reachable without a dependency-injection seam we are not allowed
//   to add. The genuinely pure logic the screen relies on
//   (CrosswordPuzzle.validateSolution, CrosswordConfig.createConfig,
//   CrosswordEquation, the generator) lives in services/
//   arithmancer_crosswords_logic.dart and is already unit-tested directly in
//   arithmancer_crosswords_logic_test.dart.
//
// What this test proves: ArithmancerCrosswordsGame constructs and renders its
// first frame inside the real provider tree it reads from
// (GameProvider/SriService/CognitiveProfileService/ProgressService) plus the
// app's localization delegates, without throwing.
//
// On the first frame `puzzle == null` and `_isGenerating == true`, so the
// screen shows the loading view (a CircularProgressIndicator + the localized
// "loading adventure" text). Puzzle generation is kicked off from a
// post-frame callback via compute() (a background isolate) and therefore does
// not complete during a single synchronous pump — so the loading frame is the
// stable, observable state. We deliberately use a single pump() and never
// pumpAndSettle(): the glow/pulse AnimationControllers repeat forever and
// would hang settle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/arithmancer_crosswords_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // GameProvider / the services may touch shared_preferences; give them a
    // clean, in-memory store so construction never hits a real plugin.
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness() {
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
      child: const MaterialApp(
        localizationsDelegates: [...S.localizationsDelegates],
        supportedLocales: [...S.supportedLocales],
        locale: Locale('en'),
        home: ArithmancerCrosswordsGame(grade: 1, level: 1),
      ),
    );
  }

  testWidgets('builds its first (loading) frame inside the real provider tree '
      'without throwing', (tester) async {
    await tester.pumpWidget(buildHarness());
    // Single pump only: the screen runs infinitely-repeating animations, so
    // pumpAndSettle would hang. The post-frame puzzle generation runs in a
    // background isolate and does not resolve synchronously, leaving the
    // screen in its loading state.
    await tester.pump();

    expect(tester.takeException(), isNull);

    // The widget itself is mounted.
    expect(find.byType(ArithmancerCrosswordsGame), findsOneWidget);

    // Loading view: a progress indicator is shown while no puzzle exists yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
