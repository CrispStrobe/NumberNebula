// Smoke / build test for MagicTrianglesGame (the screen).
//
// Why a smoke test (and not a logic test): every piece of game logic in
// magic_triangles_game.dart lives in PRIVATE members of the
// _MagicTrianglesGameState class (the scoring formula in _handleSuccess,
// _placeNumber / _removeNumber / _checkIfComplete, the drop hit-testing in
// _findClosestEmptyNode). There is no public/static method, top-level
// function, or model class in this file to unit-test directly, and we are
// not allowed to add a dependency-injection seam. The pure puzzle logic the
// screen drives (generation, solving, checkSolution, getAnswerIndex,
// getCirclePositions) lives in the separate MagicTrianglePuzzle service and
// is already covered by test/games/magic_triangle_puzzle_test.dart.
//
// What this test proves: the screen constructs and renders its FIRST frame
// inside its real provider tree + localization without throwing. initState
// kicks off puzzle generation via compute(); we only pump a single frame, so
// the widget is in its "calculating coordinates" loading state. We do NOT
// use pumpAndSettle: the screen runs infinitely-repeating AnimationControllers
// (glow + time) and pumpAndSettle would hang.
//
// Determinism notes: SharedPreferences is mocked (OnboardingOverlay.maybeShow
// reads it); we never assert on randomness or wall-clock time. The puzzle
// generator uses an unseeded math.Random internally, but this test asserts
// nothing about generated content — only that the first frame renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/magic_triangles_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

Widget _wrap(Widget child) {
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
      ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
      ChangeNotifierProvider<SriService>.value(value: sriService),
      ChangeNotifierProvider<CognitiveProfileService>.value(
          value: cognitiveProfileService),
      Provider<ProgressService>.value(value: progressService),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'builds its first (loading) frame inside the real provider tree '
      'without throwing', (tester) async {
    await tester.pumpWidget(
      _wrap(const MagicTrianglesGame(grade: 1, level: 1)),
    );
    // A single frame only — the screen runs infinite animations and an
    // async compute(); pumpAndSettle would hang.
    await tester.pump();

    // The screen constructed without throwing and produced a Scaffold.
    expect(find.byType(MagicTrianglesGame), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    // No uncaught exceptions surfaced during build/first frame.
    expect(tester.takeException(), isNull);
  });
}
