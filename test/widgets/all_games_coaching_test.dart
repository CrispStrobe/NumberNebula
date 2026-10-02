import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/game_registry.dart';
import 'package:space_math_academy/features/games/models/game_coaching.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';

void main() {
  test(
      'every registered game has a playable lesson and three specific hint stages',
      () {
    for (final key in registeredGameKeys) {
      final lesson = gameCoaching[key];
      expect(lesson, isNotNull, reason: key);
      expect(lesson!.choices.toSet().length, lesson.choices.length);
      expect(lesson.choices, contains(lesson.answer));
      for (final value in [
        lesson.questionEn,
        lesson.questionDe,
        lesson.focusEn,
        lesson.focusDe,
        lesson.strategyEn,
        lesson.strategyDe,
        lesson.workingEn,
        lesson.workingDe
      ]) {
        expect(value, isNotEmpty, reason: '$key has incomplete coaching');
      }
    }
  });
  for (final lang in ['en', 'de']) {
    testWidgets('all lessons remain playable on a landscape phone ($lang)',
        (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final key in registeredGameKeys) {
        final lesson = gameCoaching[key]!;
        var done = false;
        await tester.pumpWidget(MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: OnboardingOverlay(
                key: ValueKey(key),
                title: 'Practice',
                steps: [lesson.practice(lang == 'de')],
                onDismiss: () => done = true)));
        await tester.pump();
        final correct =
            find.widgetWithText(OutlinedButton, lesson.answer.toString());
        await tester.ensureVisible(correct);
        await tester.tap(correct);
        await tester.pump();
        final next = find.byType(ElevatedButton);
        await tester.tap(next);
        expect(done, isTrue, reason: key);
        expect(tester.takeException(), isNull, reason: key);
      }
    });
  }
}
