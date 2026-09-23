// The Puzzle Math countdown ticks once a second. Only the clock listens to
// it: a tick must not rebuild the jigsaw board, whose pieces are clipped
// full-board images.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_image_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/puzzle_math_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness() {
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
        home: PuzzleMathGame(grade: 2, level: 1),
      ),
    );
  }

  testWidgets('a clock tick updates the clock without rebuilding the board',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(PuzzleImageService.instance.init);

    await tester.pumpWidget(harness());
    await tester.pump();
    expect(find.text('2:00'), findsOneWidget);

    final boardImages = find.byType(Image);
    expect(boardImages, findsWidgets);
    final before = tester.widgetList<Image>(boardImages).toList();

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('1:59'), findsOneWidget);
    final after = tester.widgetList<Image>(boardImages).toList();
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(identical(after[i], before[i]), isTrue,
          reason: 'board image $i was rebuilt by the clock tick');
    }

    // Dispose the screen so its periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
