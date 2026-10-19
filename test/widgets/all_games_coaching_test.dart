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
        for (final german in [false, true]) {
          final practice = lesson!.practice(german);
          final rules = german ? lesson.lesson.rulesDe : lesson.lesson.rulesEn;
          final question = german ? lesson.questionDe : lesson.questionEn;
          expect(
            practice.body.indexOf(rules),
            0,
            reason: '$key must teach its rule before asking',
          );
          expect(
            practice.body.indexOf(question),
            greaterThan(practice.body.indexOf(rules)),
          );
        }
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
          lesson.workingDe,
        ]) {
          expect(value, isNotEmpty, reason: '$key has incomplete coaching');
        }
      }
    },
  );
  for (final lang in ['en', 'de']) {
    testWidgets('all lessons remain playable on a landscape phone ($lang)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final key in registeredGameKeys) {
        final lesson = gameCoaching[key]!;
        var done = false;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: OnboardingOverlay(
              key: ValueKey(key),
              title: 'Practice',
              steps: [lesson.practice(lang == 'de')],
              onDismiss: () => done = true,
            ),
          ),
        );
        await tester.pump();
        final correct = find.widgetWithText(
          OutlinedButton,
          lesson.label(lesson.answer, lang == 'de'),
        );
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
  for (final lang in ['en', 'de']) {
    for (final key in registeredGameKeys) {
      testWidgets(
        '$key teaches its actual rule before a wrong and correct practice answer ($lang)',
        (t) async {
          t.view.physicalSize = const Size(390, 500);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final lesson = gameCoaching[key]!;
          var done = false;
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: OnboardingOverlay(
                title: 'Practice',
                steps: [lesson.practice(lang == 'de')],
                onDismiss: () => done = true,
              ),
            ),
          );
          await t.pump();
          final body = find.text(lesson.practice(lang == 'de').body);
          expect(body, findsOneWidget);
          final wrong = find.widgetWithText(
            OutlinedButton,
            lesson.label(
              lesson.choices.firstWhere((v) => v != lesson.answer),
              lang == 'de',
            ),
          );
          await t.ensureVisible(wrong);
          await t.tap(wrong);
          await t.pump();
          expect(done, isFalse);
          final right = find.widgetWithText(
            OutlinedButton,
            lesson.label(lesson.answer, lang == 'de'),
          );
          await t.ensureVisible(right);
          await t.tap(right);
          await t.pump();
          expect(
            find.text(lang == 'de' ? lesson.workingDe : lesson.workingEn),
            findsOneWidget,
          );
          await t.tap(find.byType(ElevatedButton));
          expect(done, isTrue);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
