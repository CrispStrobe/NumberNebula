import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/models/game_coaching.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/features/games/widgets/strategy_hint_dialog.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';
import 'package:space_math_academy/generated/l10n.dart';

Future<void> pumpUntil(WidgetTester t, Finder finder) async {
  for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump();
  }
  expect(finder, findsWidgets);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final lang in ['en', 'de']) {
    testWidgets(
      'actual hint shell retains the game rule and uses current board ($lang)',
      (t) async {
        final gp = GameProvider(
          progressService: ProgressService(),
          sriService: SriService(),
          cognitiveProfileService: CognitiveProfileService(),
        );
        addTearDown(gp.dispose);
        await OnboardingOverlay.markSeen(
          'magic_triangles_all_games_guided_v2_rules',
        );
        final board = <String, dynamic>{
          'currentPuzzle': {
            'circlesPerSide': 3,
            'warpFrequency': 9,
            'hiddenIndices': [1],
            'visibleValues': [
              [0, 1],
              [2, 2],
              [3, 4],
              [4, 3],
              [5, 5],
            ],
            'allNumbers': [1, 2, 3, 4, 5, 6],
            'numberPool': [6, 7, 9],
          },
          'userAnswers': [null],
        };
        final before = jsonEncode(board);
        GamePauseController? pause;
        await t.pumpWidget(
          ChangeNotifierProvider.value(
            value: gp,
            child: MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              home: GameLearningShell(
                gameKey: 'magic_triangles',
                builder: (_) => Builder(
                  builder: (context) {
                    pause = GamePauseScope.of(context)!;
                    pause!.captureBoard = () => board;
                    return const Center(child: Text('Live round'));
                  },
                ),
              ),
            ),
          ),
        );
        await pumpUntil(t, find.text('Live round'));
        final s = S.of(t.element(find.text('Live round')))!;
        await t.tap(find.text(s.hintStrategy));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(StrategyHintDialog), findsOneWidget);
        expect(pause!.paused, isTrue);
        await t.tap(find.widgetWithText(ElevatedButton, s.onboardingNext));
        await t.pump();
        final rule = gameCoaching['magic_triangles']!;
        expect(
          find.textContaining(lang == 'de' ? rule.strategyDe : rule.strategyEn),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            lang == 'de'
                ? 'Alle drei Dreiecksseiten müssen die Summe 9'
                : 'All three triangle sides must total 9',
          ),
          findsOneWidget,
        );
        await t.tap(find.widgetWithText(ElevatedButton, s.onboardingNext));
        await t.pump();
        expect(find.textContaining('9 − 1 − 2 = 6'), findsOneWidget);
        expect(jsonEncode(board), before);
        expect(gp.outcomeCount, 0);
        await t.tap(find.widgetWithText(TextButton, s.hintTryMyself));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(pause!.paused, isFalse);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('old seen flag does not hide corrected rules on the next visit', (
    t,
  ) async {
    final gp = GameProvider(
      progressService: ProgressService(),
      sriService: SriService(),
      cognitiveProfileService: CognitiveProfileService(),
    );
    addTearDown(gp.dispose);
    await OnboardingOverlay.markSeen('asteroid_math_all_games_guided_v1');
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: gp,
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: GameLearningShell(
            gameKey: 'asteroid_math',
            builder: (_) => const Text('Scored round'),
          ),
        ),
      ),
    );
    await pumpUntil(t, find.byType(OnboardingOverlay));
    expect(find.text('Scored round'), findsNothing);
    expect(find.textContaining('aufsteigender Reihenfolge'), findsOneWidget);
    final s = S.of(t.element(find.byType(OnboardingOverlay)))!;
    await t.tap(find.widgetWithText(TextButton, s.skip));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await pumpUntil(t, find.text('Scored round'));
    expect(
      await OnboardingOverlay.hasBeenSeen(
        'asteroid_math_all_games_guided_v2_rules',
      ),
      isTrue,
    );
    expect(gp.outcomeCount, 0);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
