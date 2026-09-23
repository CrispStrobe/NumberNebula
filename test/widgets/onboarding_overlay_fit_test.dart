// The onboarding card has to fit a phone held sideways even when a step has
// a diagram and a long sentence -- Star Forge's first step is exactly that.
// Before the step content scrolled, the card overflowed and cut the
// buttons off.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/widgets/star_forge_diagram.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';

void main() {
  for (final (name, size) in [
    ('phone landscape', const Size(844, 390)),
    ('small phone landscape', const Size(667, 375)),
    ('phone portrait', const Size(390, 844)),
  ]) {
    testWidgets('Star Forge step 1 fits a $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final s = await S.delegate.load(const Locale('en'));
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: OnboardingOverlay(
            title: s.starForgeTitle,
            steps: [
              OnboardingStep(
                icon: Icons.hub,
                body: s.starForgeOnboardArm,
                illustration: const StarForgeArmDiagram(),
              ),
            ],
            onDismiss: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'the card overflowed');
      // The button to move on must be on screen, not clipped away.
      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.bottom, lessThanOrEqualTo(size.height));
    });
  }
}
