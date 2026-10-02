import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/models/game_outcome.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'package:space_math_academy/features/games/widgets/performance_badge.dart';
import 'package:space_math_academy/features/games/widgets/strategy_hint_dialog.dart';
import 'package:space_math_academy/generated/l10n.dart';

GameProvider provider() => GameProvider(
    progressService: ProgressService(),
    sriService: SriService(),
    cognitiveProfileService: CognitiveProfileService());
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['en', 'de']) {
    testWidgets(
        'result card fits a small landscape phone with large text ($locale)',
        (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gp = provider()
        ..reportOutcome(GameOutcome.win(
            gameType: 'star_forge',
            difficulty: 1,
            score: 100,
            performance: .75,
            movesUsed: 8,
            optimalMoves: 5,
            hintsUsed: 2));
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: gp,
          child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.8)),
                  child: child!),
              home: Scaffold(
                  body: ScrollableRoundDialog(
                      backgroundColor: Colors.black,
                      child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoundSummary(gameKey: 'star_forge')
                              ])))))));
      await tester.pump();
      expect(find.byType(PerformanceBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unmeasured outcomes do not invent accuracy or hint counts',
      (tester) async {
    final gp = provider()
      ..reportOutcome(
          GameOutcome.win(gameType: 'star_forge', difficulty: 1, score: 100));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: gp,
        child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const Scaffold(body: RoundSummary(gameKey: 'star_forge')))));
    expect(find.byType(PerformanceBadge), findsNothing);
    expect(find.text('0 strategy hints used'), findsNothing);
    expect(find.text('Round completed'), findsOneWidget);
  });
  testWidgets('hint reveals strategy then working before placing a move',
      (tester) async {
    bool demonstrated = false;
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Scaffold(
            body: StrategyHintDialog(
                focus: 'Look at the two lower bricks.',
                strategy: 'Add them.',
                working: '3 + 4 = 7',
                demonstrate: () => demonstrated = true))));
    expect(find.text('3 + 4 = 7'), findsNothing);
    expect(find.text('Show this move'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Add them.'), findsOneWidget);
    expect(find.text('3 + 4 = 7'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('3 + 4 = 7'), findsOneWidget);
    expect(demonstrated, isFalse);
    await tester.tap(find.text('Show this move'));
    await tester.pump();
    expect(demonstrated, isTrue);
  });
}
