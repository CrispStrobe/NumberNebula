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
import 'package:space_math_academy/features/games/screens/cryptex_lock_breaker_game.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
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
          home: const CryptexLockBreakerGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CryptexLockBreakerGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {bool nearSolution = false,
    int adjustments = 0,
    int solutionA = 1,
    int dialCount = 3}) {
  final solution = [solutionA, 2, 3, 4, 5].sublist(0, dialCount);
  final initial =
      nearSolution ? [0, ...solution.skip(1)] : List<int>.filled(dialCount, 0);
  final puzzle = CryptexPuzzle(
    dialCount: dialCount,
    solution: solution,
    initialValues: initial,
    equations: [
      for (final pair in [
        for (var index = 0; index < dialCount - 1; index++) [index, index + 1],
        [0, dialCount - 1],
      ])
        CryptexEquation(
            leftOperandIndices: pair,
            operator: '+',
            rightSide: solution[pair[0]] + solution[pair[1]],
            resultDialIndex: null),
    ],
  );
  return {
    'currentPuzzle': puzzle.toJson(),
    'dialValues': initial,
    '_dialAdjustments': adjustments
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

Finder _dial(int index) => find
    .byWidgetPredicate((widget) =>
        widget is GestureDetector &&
        widget.onPanStart != null &&
        widget.onPanUpdate != null &&
        widget.onPanEnd != null)
    .at(index);
Finder _drop(int index) =>
    find.byWidgetPredicate((widget) => widget is DragTarget<int>).at(index);

Future<TestGesture> _preview(
    WidgetTester tester, int dial, List<int> steps) async {
  final origin = tester.getCenter(_dial(dial));
  final pointer = await tester.startGesture(origin);
  // Start the real recognizer before measuring its drag anchor. Flutter's
  // touch slop must not silently alter the tested 20-pixel digit steps.
  await pointer.moveBy(const Offset(0, -30));
  await tester.pump();
  expect(_session(tester).isDragging, isTrue);
  final anchor = _session(tester).dragStartY as double;
  for (final step in steps) {
    await pointer.moveTo(Offset(origin.dx, anchor - step * 20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return pointer;
}

Future<void> _drag(WidgetTester tester, int dial, List<int> steps) async {
  final pointer = await _preview(tester, dial, steps);
  await pointer.up();
  await tester.pump();
}

Future<void> _digit(WidgetTester tester, int dial, int value) async {
  final source = find.byWidgetPredicate(
      (widget) => widget is Draggable<int> && widget.data == value);
  expect(source, findsOneWidget);
  await tester.drag(
      source, tester.getCenter(_drop(dial)) - tester.getCenter(source));
  await tester.pump();
}

void _retainedInput(GestureDetector gesture, DragTarget<int> drop) {
  gesture.onTap!();
  gesture.onPanStart!(DragStartDetails(globalPosition: const Offset(500, 500)));
  gesture.onPanUpdate!(DragUpdateDetails(
      globalPosition: const Offset(500, 460), delta: const Offset(0, -40)));
  gesture.onPanEnd!(DragEndDetails());
  gesture.onPanCancel?.call();
  drop.onAcceptWithDetails!(
      DragTargetDetails<int>(data: 9, offset: Offset.zero));
}

CryptexBodyPainter _body(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter is CryptexBodyPainter))
    .painter as CryptexBodyPainter;
double _rotation(WidgetTester tester) => (tester
        .widget<CustomPaint>(find.byWidgetPredicate((widget) =>
            widget is CustomPaint &&
            widget.painter is CryptexBackgroundPainter))
        .painter as CryptexBackgroundPainter)
    .rotationAngle;

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'cryptex_rounds_${profile++}';
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_cryptex_lock_breaker': true});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets('final multi-step drag is graded before win (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester,
          reduced: reduced,
          board: _board(nearSolution: true, adjustments: 2, solutionA: 5));
      final retained = tester.widget<GestureDetector>(_dial(0));
      final drop = tester.widget<DragTarget<int>>(_drop(0));
      final pointer = await _preview(tester, 0, [1, 3, 5]);
      expect(_session(tester).dialValues, [5, 2, 3]);
      expect(_session(tester).capturePuzzleSession(), isNull,
          reason: 'A preview is not a committed saveable adjustment');
      expect(app.gp.outcomeCount, 0);
      await pointer.up();
      await tester.pump();
      expect(app.gp.outcomeCount, 1);
      final outcome = app.gp.lastOutcome!;
      expect(outcome.wasSuccessful, isTrue);
      expect(outcome.movesUsed, 3,
          reason: 'The winning gesture must be included before reporting');
      expect(outcome.optimalMoves, 1);
      expect(outcome.performance, Perf.fromMoves(3, 1));
      expect(outcome.score, 500);
      _retainedInput(retained, drop);
      await tester.pump();
      expect(_session(tester).dialValues, [5, 2, 3]);
      expect(app.gp.outcomeCount, 1);
      expect(_session(tester).capturePuzzleSession(), isNull);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(_dialog, findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 1);
      await tester.tap(
          find.widgetWithText(ElevatedButton, _strings(tester).nextCryptex));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_snapshot(tester)['_dialAdjustments'], 0);
      expect(_session(tester).gameActive, isTrue);
      expect(_session(tester).isUnlocked, isFalse);
      expect(_session(tester).particles, isEmpty);
      expect(_body(tester).unlockProgress, 0);
      final next = _snapshot(tester);
      _retainedInput(retained, drop);
      await tester.pump();
      expect(_snapshot(tester), next);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });

    testWidgets('restore cancels victory and clears effects (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester,
          reduced: reduced, board: _board(nearSolution: true));
      await _digit(tester, 0, 1);
      expect(app.gp.outcomeCount, 1);
      await tester.pump(const Duration(milliseconds: 200));
      final replacement = _board(adjustments: 4);
      await _restore(tester, app, replacement);
      expect(_session(tester).selectedDial, -1);
      expect(_session(tester).isDragging, isFalse);
      expect(_session(tester).particles, isEmpty);
      expect(_body(tester).isUnlocked, isFalse);
      expect(_body(tester).unlockProgress, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester), replacement);
      expect(_body(tester).unlockProgress, 0);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });

    testWidgets('dispose cancels delayed victory (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester,
          reduced: reduced, board: _board(nearSolution: true));
      final gesture = tester.widget<GestureDetector>(_dial(0));
      final drop = tester.widget<DragTarget<int>>(_drop(0));
      await _digit(tester, 0, 1);
      await _unmount(tester);
      _retainedInput(gesture, drop);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(app.gp.outcomeCount, 1);
      expect(_dialog, findsNothing);
    });
  }

  testWidgets(
      'multi-step, same-value and cancelled drags count committed settings',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 0, [1, 3, 2]);
    expect(_snapshot(tester)['dialValues'], [2, 0, 0]);
    expect(_snapshot(tester)['_dialAdjustments'], 1);
    await _drag(tester, 0, [1, 0]);
    expect(_snapshot(tester)['dialValues'], [2, 0, 0]);
    expect(_snapshot(tester)['_dialAdjustments'], 1,
        reason: 'Returning to the starting digit is not a new setting');
    final pointer = await _preview(tester, 0, [2, 4]);
    await pointer.cancel();
    await tester.pump();
    expect(_snapshot(tester)['dialValues'], [2, 0, 0]);
    expect(_snapshot(tester)['_dialAdjustments'], 1);
    expect(_session(tester).isDragging, isFalse);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets(
      'real digit drops count changes and include the final winning drop',
      (tester) async {
    final app = await _mount(tester);
    await _digit(tester, 0, 0);
    expect(_snapshot(tester)['_dialAdjustments'], 0);
    await _digit(tester, 0, 1);
    expect(_snapshot(tester)['_dialAdjustments'], 1);
    await _digit(tester, 1, 2);
    expect(_snapshot(tester)['_dialAdjustments'], 2);
    await _digit(tester, 2, 3);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.movesUsed, 3);
    expect(app.gp.lastOutcome!.optimalMoves, 3);
    expect(app.gp.lastOutcome!.performance, 1);
    await _unmount(tester);
  });

  testWidgets(
      'replacement cancels active drag and rejects retained dial callbacks',
      (tester) async {
    final app = await _mount(tester, board: _board(dialCount: 5));
    final gesture = tester.widget<GestureDetector>(_dial(4));
    final drop = tester.widget<DragTarget<int>>(_drop(4));
    final pointer = await _preview(tester, 4, [1, 3]);
    final replacement = _board(adjustments: 4);
    await _restore(tester, app, replacement);
    expect(_session(tester).isDragging, isFalse);
    expect(_session(tester).selectedDial, -1);
    _retainedInput(gesture, drop);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), replacement);
    expect(_session(tester).particles, isEmpty);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets('reduced motion stops decoration and keeps delayed win intact',
      (tester) async {
    final app = await _mount(tester, board: _board(nearSolution: true));
    final initial = _rotation(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_rotation(tester), isNot(initial));
    await _digit(tester, 0, 1);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    final stopped = _rotation(tester);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_rotation(tester), stopped);
    }
    expect(_session(tester).particles, isEmpty);
    expect(_body(tester).unlockProgress, 1);
    expect(_dialog, findsNothing);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'idle decoration avoids root builds and saves (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      // Finish the restore's ordinary debounced checkpoint before observing
      // writes. Do not await persistence flushes in the fake timer zone.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      final writes = PuzzleSessionStore.instance.recordWriteCount;
      final header = tester.widget<GameUI>(find.byType(GameUI));
      final initialRotation = _rotation(tester);
      final board = _snapshot(tester);
      for (var frame = 0; frame < 60; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.widget<GameUI>(find.byType(GameUI)), same(header),
            reason: 'Empty particle updates must not rebuild the screen');
      }
      expect(PuzzleSessionStore.instance.recordWriteCount, writes,
          reason: 'Decoration must not serialize unchanged puzzle state');
      expect(_snapshot(tester), board);
      expect(_session(tester).particles, isEmpty);
      expect(_rotation(tester),
          reduced ? initialRotation : isNot(initialRotation));
      if (reduced) {
        app.motion.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));
        expect(_rotation(tester), isNot(initialRotation));
      }
      expect(app.gp.outcomeCount, 0);
      await _unmount(tester);
    });
  }

  testWidgets(
      'concurrent and out-of-range dial input cannot corrupt an active drag',
      (tester) async {
    final app = await _mount(tester);
    final other = tester.widget<GestureDetector>(_dial(1));
    final drop = tester.widget<DragTarget<int>>(_drop(1));
    for (final value in [-1, 10]) {
      drop.onAcceptWithDetails!(
          DragTargetDetails<int>(data: value, offset: Offset.zero));
    }
    await tester.pump();
    expect(_snapshot(tester)['_dialAdjustments'], 0);
    expect(_snapshot(tester)['dialValues'], [0, 0, 0]);
    final pointer = await _preview(tester, 0, [2]);
    other.onTap!();
    other.onPanStart!(DragStartDetails(globalPosition: const Offset(600, 500)));
    drop.onAcceptWithDetails!(
        DragTargetDetails<int>(data: 2, offset: Offset.zero));
    await tester.pump();
    expect(_session(tester).selectedDial, 0);
    expect(_session(tester).dialValues, [2, 0, 0]);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester)['_dialAdjustments'], 1);
    expect(_snapshot(tester)['dialValues'], [2, 0, 0]);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
}
