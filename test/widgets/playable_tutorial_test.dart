import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
        'guided move fills the board and requires the right answer ($locale)',
        (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await S.delegate.load(Locale(locale));
      bool done = false;
      await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
              body: OnboardingOverlay(
                  title: s.guidedTry,
                  steps: [
                    OnboardingStep(
                        icon: Icons.touch_app,
                        body: s.guidedWallPrompt,
                        practiceBoard: '3 + 4 = ?',
                        choices: const [6, 7, 8],
                        answer: 7,
                        explanation: s.guidedWallReason)
                  ],
                  onDismiss: () => done = true))));
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      await tester.ensureVisible(find.text('6'));
      await tester.tap(find.text('6'));
      await tester.pump();
      expect(find.text('3 + 4 = 6'), findsOneWidget);
      expect(done, isFalse);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      await tester.tap(find.text('7'));
      await tester.pump();
      expect(find.text('3 + 4 = 7'), findsOneWidget);
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull);
      await tester.tap(find.byType(ElevatedButton));
      expect(done, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
