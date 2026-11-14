// Drives every KOMPASS entry point in the REAL app under AOT (profile or
// release). 1.6.4 (70) crashed with SIGSEGV on iPad when "Meine nächste Übung"
// or "Selbstständig lösen" was tapped: the AOT build evaluated a nested
// collection `if`/`if-case` in the course screen that JIT widget tests
// evaluated correctly. Widget tests cannot see that class of failure, so this
// test opens each flow in a compiled build.
//
// Run (macOS, AOT):
//   flutter drive --profile -d macos \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/kompass_open_test.dart
// iOS device: same command with `-d <device id>` (needs a valid development
// signing identity).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:space_math_academy/features/kompass/screens/kompass_hub_screen.dart';
import 'package:space_math_academy/main.dart' as app;

Future<void> _hold(WidgetTester tester, {int ms = 800}) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _log(String step) => debugPrint('KOMPASS-E2E: $step');

Finder _keyPrefix(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

Future<bool> _waitFor(WidgetTester tester, Finder finder,
    {int tries = 40}) async {
  for (var i = 0; i < tries && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  return finder.evaluate().isNotEmpty;
}

/// Lazily built lists only create rows near the viewport: scroll the
/// current page's main list (up, then down) until [finder] exists.
Future<bool> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return true;
  for (final delta in const [-300.0, 300.0]) {
    final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    if (lists.evaluate().isEmpty) return false;
    try {
      await tester.scrollUntilVisible(finder, delta,
          scrollable: lists.last, maxScrolls: 80);
    } catch (_) {
      continue;
    }
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return true;
  }
  return false;
}

bool _atHub(WidgetTester tester) {
  final hub = find.byType(KompassHubScreen);
  if (hub.evaluate().isEmpty) return false;
  return ModalRoute.of(tester.element(hub.first))?.isCurrent ?? false;
}

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  expect(
      await _waitFor(tester, finder, tries: 8) || await _reveal(tester, finder),
      isTrue,
      reason: 'missing $what');
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  await _hold(tester);
}

Future<void> _tapText(WidgetTester tester, List<String> labels) async {
  final finder = find.byWidgetPredicate(
      (w) => w is Text && labels.contains(w.data ?? ''),
      skipOffstage: false);
  await _tap(tester, finder, labels.join(' / '));
}

/// Accepts the dialog's primary action ("Neu beginnen", "Start", ...).
Future<void> _confirmDialog(WidgetTester tester) async {
  final dialog = find.byType(AlertDialog);
  if (!await _waitFor(tester, dialog, tries: 6)) return;
  final primary =
      find.descendant(of: dialog, matching: find.byType(FilledButton));
  await tester.tap(primary.first, warnIfMissed: false);
  await _hold(tester);
}

/// Returns to the hub; answers a leave confirmation if one appears.
Future<void> _backToHub(WidgetTester tester) async {
  for (var i = 0; i < 4 && !_atHub(tester); i++) {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    // Not awaited: a route that asks before leaving would block the test.
    unawaited(nav.maybePop());
    await _hold(tester);
    await _confirmDialog(tester);
  }
  expect(_atHub(tester), isTrue, reason: 'did not return to the KOMPASS hub');
}

Future<void> _exerciseSession(WidgetTester tester, String name) async {
  expect(await _waitFor(tester, _keyPrefix('kompass-task-nav-')), isTrue,
      reason: '$name did not show its task list');
  _log('$name open');
  expect(tester.takeException(), isNull);
  final check = find.byKey(const ValueKey('kompass-check-answer'));
  if (await _reveal(tester, check)) {
    await _tap(tester, check, '$name check answer');
    _log('$name answer checked');
    expect(tester.takeException(), isNull);
  }
  final hint = find.byKey(const ValueKey('kompass-hint'));
  if (await _reveal(tester, hint)) {
    await _tap(tester, hint, '$name hint');
  }
  final second = find.byKey(const ValueKey('kompass-task-nav-1'));
  if (await _reveal(tester, second)) {
    await _tap(tester, second, '$name second task');
    _log('$name second task');
    expect(tester.takeException(), isNull);
  }
  await _backToHub(tester);
}

/// `--dart-define=KOMPASS_E2E_ONLY=<lab id>` opens just that lab (diagnosis).
const _only = String.fromEnvironment('KOMPASS_E2E_ONLY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every KOMPASS entry point opens and renders', (tester) async {
    app.main();
    await _hold(tester, ms: 4000);

    await _tap(tester, find.byKey(const ValueKey('open-kompass')), 'hub');
    await _hold(tester, ms: 2500);

    if (_only.isEmpty) {
      _log('practice');
      await _tap(tester, find.byKey(const ValueKey('kompass-next-practice')),
          'next practice');
      await _confirmDialog(tester);
      await _exerciseSession(tester, 'practice');

      _log('check');
      await _tapText(
          tester, const ['Selbstständig lösen', 'Independent check']);
      await _confirmDialog(tester);
      await _exerciseSession(tester, 'check');

      _log('rehearsal');
      await _tapText(
          tester, const ['45-Minuten-Probelauf', '45-minute rehearsal']);
      await _confirmDialog(tester); // replace the open session
      await _confirmDialog(tester); // start the clock
      await _exerciseSession(tester, 'rehearsal');

      for (final kind in const ['practice', 'test']) {
        final paper = find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('kompass-paper-') &&
              key.value.endsWith('-$kind');
        });
        _log('paper $kind');
        await _tap(tester, paper, 'paper $kind');
        await _confirmDialog(tester);
        await _confirmDialog(tester);
        await _exerciseSession(tester, 'paper $kind');
      }
    }

    for (final id in const [
      'reasoning_workshop',
      'journey_planner',
      'area_studio',
      'chance_detective',
      'number_dock',
      'supply_station',
      'data_observatory',
      'geometry_workshop'
    ]) {
      if (_only.isNotEmpty && id != _only) continue;
      _log('lab $id');
      await _tap(tester, find.byKey(ValueKey('kompass-lab-$id')), 'lab $id');
      _log('lab $id tapped');
      await _hold(tester, ms: 2000);
      _log('lab $id open');
      expect(tester.takeException(), isNull);
      await _backToHub(tester);
      _log('lab $id closed');
    }
    _log('done');
  });
}
