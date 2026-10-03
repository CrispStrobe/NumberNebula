import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/circuit_repair_game.dart';
import 'package:space_math_academy/features/games/services/circuit_repair_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);

  _App({bool reduced = false}) : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: motion,
            builder: (_, reduced, __) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
          home: const CircuitRepairGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CircuitRepairGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {bool selected = false,
    int attempts = 0,
    int maxAttempts = 5,
    bool six = false}) {
  final puzzle = CircuitRepairPuzzle(
    correctDigits: six ? [1, 6, 5, 9, 3, 2] : [1, 6, 5, 9],
    displayedDigits: six ? [1, 5, 6, 9, 3, 2] : [1, 5, 6, 9],
    swapPosA: 1,
    swapPosB: 2,
    maxAttempts: maxAttempts,
  );
  return {
    '_puzzle': puzzle.toJson(), '_selectedFirst': selected ? 1 : null,
    '_selectedSecond': selected ? 2 : null,
    // Older interrupted saves can have a selected pair and unswapped digits.
    '_currentDigits': puzzle.displayedDigits, '_attemptsUsed': attempts
  };
}

Future<void> _restore(
    WidgetTester tester, _App app, Map<String, dynamic> board) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  final reduced = app.motion.value;
  app.motion.value = !reduced;
  await tester.pump();
  app.motion.value = reduced;
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester,
    {bool reduced = false, Map<String, dynamic>? board}) async {
  final app = _App(reduced: reduced);
  tester.view.physicalSize = const Size(1400, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(app.motion.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(app.build());
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  return app;
}

final _digits = find.byWidgetPredicate((widget) =>
    widget is CustomPaint &&
    widget.painter.runtimeType.toString() == '_SevenSegmentPainter');
Future<void> _digit(WidgetTester tester, int position) async {
  final gesture = find
      .ancestor(
          of: _digits.at(position), matching: find.byType(GestureDetector))
      .first;
  await tester.tap(gesture);
  await tester.pump();
}

void _expectDigits(WidgetTester tester, List<int> digits) {
  expect(_digits, findsNWidgets(digits.length));
  for (var position = 0; position < digits.length; position++) {
    final dynamic painter =
        tester.widget<CustomPaint>(_digits.at(position)).painter;
    expect(painter.segments,
        unorderedEquals(SevenSegment.getSegments(digits[position])));
  }
}

Finder _button(String text) => find
    .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((widget) => widget is ElevatedButton))
    .first;
Future<void> _frames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'circuit_rounds_${profile++}';
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_circuit_repair': true});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets('normal preview waits 400 ms and saves a coherent selected swap',
      (tester) async {
    final app = await _mount(tester);
    await _digit(tester, 1);
    await _digit(tester, 2);
    await tester.pump(const Duration(milliseconds: 300));
    _expectDigits(tester, [1, 5, 6, 9]);
    expect(_snapshot(tester)['_currentDigits'], [1, 6, 5, 9]);
    await _frames(tester, 12);
    _expectDigits(tester, [1, 6, 5, 9]);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
  for (final six in [false, true]) {
    testWidgets('restores interrupted selected preview (six:$six)',
        (tester) async {
      final app = await _mount(tester,
          board: _board(selected: true, attempts: 2, six: six));
      _expectDigits(tester, six ? [1, 6, 5, 9, 3, 2] : [1, 6, 5, 9]);
      expect(_snapshot(tester)['_attemptsUsed'], 2);
      await tester.tap(_button(_strings(tester).circuitRepairWinTitle));
      await tester.pump();
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.performance, Perf.fromAttempts(3, 5));
      expect(app.gp.lastOutcome!.score, 215);
      expect(_session(tester).capturePuzzleSession(), isNull);
      await _frames(tester, 40);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }
  testWidgets('reselecting after a completed preview restores original digits',
      (tester) async {
    final app = await _mount(tester, board: _board(selected: true));
    await _digit(tester, 1);
    _expectDigits(tester, [1, 5, 6, 9]);
    expect(_snapshot(tester)['_selectedFirst'], 2);
    expect(_snapshot(tester)['_selectedSecond'], isNull);
    await _digit(tester, 1);
    await _frames(tester, 30);
    _expectDigits(tester, [1, 6, 5, 9]);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
  testWidgets(
      'correct submit before preview finishes commits correct digits once',
      (tester) async {
    final app = await _mount(tester);
    await _digit(tester, 1);
    await _digit(tester, 2);
    final submit = tester
        .widget<ElevatedButton>(_button(_strings(tester).circuitRepairWinTitle))
        .onPressed!;
    submit();
    submit();
    await tester.pump();
    _expectDigits(tester, [1, 6, 5, 9]);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.score, 275);
    await _frames(tester, 40);
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });
  for (final reduced in [false, true]) {
    for (final action in ['restore', 'reset', 'deselect', 'dispose']) {
      testWidgets('$action cancels pending preview (reduced:$reduced)',
          (tester) async {
        final app = await _mount(tester, reduced: reduced);
        await _digit(tester, 1);
        // No pump after second selection: zero-duration completion is queued.
        await tester.tap(find
            .ancestor(of: _digits.at(2), matching: find.byType(GestureDetector))
            .first);
        if (!reduced) await tester.pump(const Duration(milliseconds: 100));
        if (action == 'restore') {
          await _restore(tester, app, _board(six: true));
        } else if (action == 'reset') {
          // Invoke the real button before deferred completion runs.
          tester
              .widget<ElevatedButton>(_button(_strings(tester).reset))
              .onPressed!();
        } else if (action == 'deselect') {
          final gesture = tester.widget<GestureDetector>(find
              .ancestor(
                  of: _digits.at(1), matching: find.byType(GestureDetector))
              .first);
          gesture.onTap!();
        } else {
          await _unmount(tester);
        }
        await _frames(tester, 40);
        if (action != 'dispose') {
          _expectDigits(
              tester, action == 'restore' ? [1, 5, 6, 9, 3, 2] : [1, 5, 6, 9]);
          await _unmount(tester);
        }
        expect(app.gp.outcomeCount, 0);
      });
    }
  }
  testWidgets(
      'wrong submit before preview completes stays reverted and counts once',
      (tester) async {
    final app = await _mount(tester);
    await _digit(tester, 0);
    await _digit(tester, 1);
    await tester.tap(_button(_strings(tester).circuitRepairWinTitle));
    await tester.pump();
    await _frames(tester, 40);
    _expectDigits(tester, [1, 5, 6, 9]);
    expect(_snapshot(tester)['_attemptsUsed'], 1);
    expect(_snapshot(tester)['_selectedFirst'], isNull);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
  testWidgets(
      'terminal loss blocks duplicates and play again begins saveable session',
      (tester) async {
    final app = await _mount(tester, board: _board(attempts: 4));
    await _digit(tester, 0);
    await _digit(tester, 1);
    final submit = tester
        .widget<ElevatedButton>(_button(_strings(tester).circuitRepairWinTitle))
        .onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    final retry = find.descendant(
        of: _dialog,
        matching:
            find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_session(tester).puzzleSessionFinished, isFalse);
    expect(_snapshot(tester)['_attemptsUsed'], 0);
    await _frames(tester, 40);
    final puzzle = _snapshot(tester)['_puzzle'] as Map;
    _expectDigits(tester, List<int>.from(puzzle['displayedDigits'] as List));
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });
  for (final initial in [true, false]) {
    testWidgets('reduced motion completes preview once (initial:$initial)',
        (tester) async {
      final app = await _mount(tester, reduced: initial);
      await _digit(tester, 1);
      await _digit(tester, 2);
      if (!initial) {
        await tester.pump(const Duration(milliseconds: 100));
        app.motion.value = true;
        await tester.pump();
      }
      await _frames(tester, 8);
      _expectDigits(tester, [1, 6, 5, 9]);
      app.motion.value = false;
      await tester.pump();
      await _frames(tester, 40);
      _expectDigits(tester, [1, 6, 5, 9]);
      expect(app.gp.outcomeCount, 0);
      await _unmount(tester);
    });
  }
}
