// Ground-truth render check: navigates the REAL app to a curated set of games
// (the ones the layout audit flagged with large overflow), fully loads each,
// dismisses the first-run tutorial, and holds it while a host script grabs
// native pixels via `simctl io screenshot`. This is the reliable check the
// standalone-pump audit can't be (the audit catches transient/loading states).
//
// Run:
//   env -u GEM_HOME -u GEM_PATH -u RUBYOPT flutter test \
//     integration_test/render_check_test.dart -d <sim-udid>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:space_math_academy/main.dart' as app;

// gameKeys flagged with large audit overflow (+ magic_triangles as a known-good
// control that the audit *also* flagged but which renders fine).
const _targets = <String>[
  // Edit this list to spot-check specific games' real rendered layout.
  'magic_triangles',
  'circuit_repair',
  'block_counter',
];

Future<void> _hold(WidgetTester tester, {int ms = 6500}) async {
  final steps = ms ~/ 150;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render curated games for visual triage', (tester) async {
    app.main();
    await _hold(tester, ms: 4000);

    // Home -> menu.
    for (final label in const ['Start Your Math Adventure', 'Starte dein Mathe-Abenteuer']) {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await _hold(tester, ms: 3000);
        break;
      }
    }

    final scrollable = find.byType(Scrollable).first;

    for (final key in _targets) {
      final card = find.byKey(ValueKey('gamecard_$key'));
      try {
        await tester.scrollUntilVisible(card, 250, scrollable: scrollable);
      } catch (_) {
        // already visible or not found; try tapping if present
      }
      if (card.evaluate().isEmpty) {
        debugPrint('SHOT_MARKER ${key}_NOTFOUND');
        continue;
      }
      await tester.tap(card, warnIfMissed: false);
      await _hold(tester, ms: 3500);

      // Dismiss first-run tutorial if present.
      for (final label in const ['Skip', 'Überspringen', 'Got it!', 'Verstanden']) {
        final f = find.text(label);
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f.first, warnIfMissed: false);
          await _hold(tester, ms: 1500);
          break;
        }
      }

      debugPrint('SHOT_MARKER $key');
      await _hold(tester, ms: 7000);

      // Back to the menu via the global Escape shortcut (also exercises a11y).
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _hold(tester, ms: 2500);
    }
    debugPrint('RENDER_CHECK_DONE');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
