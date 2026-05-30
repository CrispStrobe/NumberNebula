// Smoke / build test for codebreaker_game.dart.
//
// Why a smoke test (and not a focused unit test of this file):
//   The screen's game logic — scoring (_handleSuccess / _getOperationBonus),
//   placement and pool accounting (_placeNumber / _removeNumber), solution
//   checking (_checkSolution) and problem extraction (_extractMathProblems) —
//   all lives in PRIVATE instance methods of the State class, bound to a live
//   BuildContext, a GameProvider, several infinitely-repeating
//   AnimationControllers and showDialog()/SnackBar calls. None of that is
//   reachable without a dependency-injection seam we are not allowed to add.
//   The genuinely pure logic the screen relies on (AdvancedCodebreakerPuzzle:
//   generate / validateSolution / getSymbolFromPosition / isPositionVisible,
//   PuzzleEquation, the generator) lives in services/codebreaker_logic.dart
//   and is already unit-tested directly in codebreaker_logic_test.dart.
//
// What this test proves: CodebreakerGame constructs and renders its first
// frame inside the real provider tree it reads from
// (GameProvider / SriService / CognitiveProfileService / ProgressService) plus
// the app's localization delegates, without throwing.
//
// On the first frame `puzzle == null` and `_isGenerating == true`, so the
// screen shows the loading view (a CircularProgressIndicator + the localized
// "loading adventure" text). Puzzle generation is kicked off from a post-frame
// callback via compute() (a background isolate) and therefore does not
// complete during a single synchronous pump — so the loading frame is the
// stable, observable state. We deliberately use a single pump() and never
// pumpAndSettle(): the glow AnimationController repeats forever and would hang
// settle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/codebreaker_game.dart';
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
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale('en'),
        home: CodebreakerGame(grade: 1, level: 1),
      ),
    );
  }

  testWidgets(
      'builds its first (loading) frame inside the real provider tree '
      'without throwing', (tester) async {
    await tester.pumpWidget(buildHarness());
    // Single pump only: the screen runs an infinitely-repeating glow
    // animation, so pumpAndSettle would hang. The post-frame puzzle
    // generation runs in a background isolate and does not resolve
    // synchronously, leaving the screen in its loading state.
    await tester.pump();

    expect(tester.takeException(), isNull);

    // The widget itself is mounted.
    expect(find.byType(CodebreakerGame), findsOneWidget);

    // Loading view: a progress indicator is shown while no puzzle exists yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
