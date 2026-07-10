// Screenshot-driver integration test.
//
// Navigates the real app (home -> game menu -> a game) and HOLDS each screen
// for a few seconds, printing a `SHOT_MARKER <name>` line just before each
// hold. A host script (tool/capture_screenshots.sh) watches for those markers
// and grabs native-resolution pixels with `xcrun simctl io screenshot` during
// the hold window.
//
// We deliberately drive with fixed `pump()` steps instead of `pumpAndSettle()`
// because the animated SpaceBackground runs a repeating animation that never
// settles.
//
// Run (on a booted simulator):
//   flutter test integration_test/screenshots_test.dart -d <sim-udid>

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:space_math_academy/main.dart' as app;
import 'package:space_math_academy/features/games/screens/game_menu_screen.dart';

Future<void> _hold(WidgetTester tester, {int ms = 7000}) async {
  final steps = ms ~/ 150;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Finder _startButton() {
  for (final label in const [
    'Start Your Math Adventure',
    'Starte dein Mathe-Abenteuer',
  ]) {
    final f = find.text(label);
    if (f.evaluate().isNotEmpty) return f;
  }
  return find.byType(GameCard); // fallback: already on the menu
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drive the app and hold screens for screenshots',
      (tester) async {
    app.main();
    await _hold(tester, ms: 4000); // splash -> home

    // 1. Home screen.
    debugPrint('SHOT_MARKER home');
    await _hold(tester);

    // 2. Game menu.
    final start = _startButton();
    if (start.evaluate().isNotEmpty && start != find.byType(GameCard)) {
      await tester.tap(start.first, warnIfMissed: false);
      await _hold(tester, ms: 3000);
    }
    debugPrint('SHOT_MARKER menu');
    await _hold(tester);

    // 3. A game (first card).
    final cards = find.byType(GameCard);
    if (cards.evaluate().isNotEmpty) {
      await tester.tap(cards.first, warnIfMissed: false);
      await _hold(tester, ms: 3500);

      // Dismiss the first-run tutorial overlay so the puzzle is unobstructed.
      for (final label in const ['Skip', 'Überspringen', 'Got it!', 'Verstanden']) {
        final f = find.text(label);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await _hold(tester, ms: 1500);
          break;
        }
      }

      debugPrint('SHOT_MARKER game1');
      await _hold(tester, ms: 8000);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
