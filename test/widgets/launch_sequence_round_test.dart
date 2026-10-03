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
import 'package:space_math_academy/features/games/screens/launch_sequence_game.dart';
import 'package:space_math_academy/features/games/services/launch_sequence_logic.dart';
import 'package:flutter/foundation.dart';
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
          home: const LaunchSequenceGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(LaunchSequenceGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {List<int> values = const [4, 1, 2, 3], int swaps = 0, int? selected}) {
  final puzzle = LaunchSequencePuzzle(
      sequence: List.of(values),
      target: List.of(values)..sort(),
      optimalSwaps: LaunchSequencePuzzle.countInversions(values));
  return {
    'puzzle': puzzle.toJson(),
    'sequence': List.of(values),
    'swapCount': swaps,
    '_selectedIndex': selected
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

final _list = find.byType(ReorderableListView);
Finder _ship(int value) => find
    .ancestor(
        of: find.text('#$value'),
        matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTap != null))
    .first;
GestureDetector _tap(WidgetTester tester, int value) =>
    tester.widget<GestureDetector>(_ship(value));
ReorderableListView _reorder(WidgetTester tester) =>
    tester.widget<ReorderableListView>(_list);
Future<void> _sort(WidgetTester tester) async {
  _reorder(tester).onReorderItem!(0, 3);
  await tester.pump();
}

void _grade(_App app, {int moves = 3, int optimal = 3, int score = 225}) {
  expect(app.gp.outcomeCount, 1);
  final outcome = app.gp.lastOutcome!;
  expect(outcome.wasSuccessful, isTrue);
  expect(outcome.movesUsed, moves);
  expect(outcome.optimalMoves, optimal);
  expect(outcome.performance, Perf.fromMoves(moves, optimal));
  expect(outcome.score, score);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'launch_sequence_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_launch_sequence': true});
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'long relocation is three adjacent moves and dialog waits 1300ms (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final tap = _tap(tester, 4);
      final reorder = _reorder(tester);
      await _sort(tester);
      expect(_session(tester).sequence, [1, 2, 3, 4]);
      _grade(app);
      expect(_session(tester).capturePuzzleSession(), isNull);
      tap.onTap!();
      reorder.onReorderItem!(0, 1);
      _reorder(tester).onReorderItem!(3, 0);
      expect(_session(tester).sequence, [1, 2, 3, 4]);
      expect(_session(tester).swapCount, 3);
      await tester.pump(const Duration(milliseconds: 1299));
      expect(_dialog, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsOneWidget);
      _grade(app);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      expect(_session(tester).swapCount, 0);
      expect(_snapshot(tester)['_selectedIndex'], isNull);
    });

    testWidgets('restoration cancels pending launch dialog (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _sort(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await _restore(
          tester, app, _board(values: [2, 1], swaps: 7, selected: 1));
      final before = _snapshot(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(_snapshot(tester), before);
      expect(_dialog, findsNothing);
      expect(app.gp.outcomeCount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'actual long-press drag accounts for final relocation before grading',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final app = await _mount(tester, reduced: true);
    final origin = tester.getCenter(_ship(4));
    final destination = tester.getCenter(_ship(3)) + const Offset(70, 0);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 0);
    await gesture.up();
    await tester.pump();
    // Flutter commits the reorder after its 250ms proxy return animation.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(_session(tester).sequence, [1, 2, 3, 4]);
    _grade(app);
  });

  testWidgets('active drag cannot commit into same-length restored round',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final app = await _mount(tester, reduced: true);
    final origin = tester.getCenter(_ship(4));
    final destination = tester.getCenter(_ship(3)) + const Offset(70, 0);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 0);
    await _restore(
        tester, app, _board(values: [3, 1, 4, 2], swaps: 7, selected: 2));
    final before = _snapshot(tester);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'accepted reorder cancellation leaves sequence and moves unchanged',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final app = await _mount(tester, reduced: true);
    final before = _snapshot(tester);
    final origin = tester.getCenter(_ship(4));
    final destination = tester.getCenter(_ship(3)) + const Offset(70, 0);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(destination);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reverse and forward nonwinning relocations retain prior moves; same index is free',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(values: [3, 4, 1, 2], swaps: 5, selected: 2));
    _reorder(tester).onReorderItem!(3, 0);
    await tester.pump();
    expect(_session(tester).sequence, [2, 3, 4, 1]);
    expect(_session(tester).swapCount, 8);
    expect(_snapshot(tester)['_selectedIndex'], isNull);
    _reorder(tester).onReorderItem!(0, 2);
    await tester.pump();
    expect(_session(tester).sequence, [3, 4, 2, 1]);
    expect(_session(tester).swapCount, 10);
    final before = _snapshot(tester);
    _reorder(tester).onReorderItem!(1, 1);
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'same-card selection cancels free and adjacent real taps win once',
      (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(values: [2, 1, 3]));
    await tester.tap(_ship(2));
    await tester.pump();
    expect(_snapshot(tester)['_selectedIndex'], 0);
    await tester.tap(_ship(2));
    await tester.pump();
    expect(_snapshot(tester)['_selectedIndex'], isNull);
    expect(_session(tester).swapCount, 0);
    await tester.tap(_ship(2));
    await tester.pump();
    await tester.tap(_ship(1));
    await tester.pump();
    expect(_session(tester).sequence, [1, 2, 3]);
    _grade(app, moves: 1, optimal: 1);
  });

  testWidgets(
      'valid restored selection works; invalid selections normalize without losing moves',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(values: [2, 1, 3], swaps: 4, selected: 0));
    expect(_snapshot(tester)['_selectedIndex'], 0);
    await tester.tap(_ship(1));
    await tester.pump();
    _grade(app, moves: 5, optimal: 1, score: 145);
    for (final selected in [-1, 99]) {
      await _restore(
          tester, app, _board(values: [2, 1], swaps: 7, selected: selected));
      expect(_snapshot(tester)['_selectedIndex'], isNull);
      expect(_session(tester).swapCount, 7);
      await tester.tap(_ship(2));
      await tester.pump();
      expect(_snapshot(tester)['_selectedIndex'], 0);
    }
    expect(app.gp.outcomeCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'retained callbacks cannot index or reorder smaller restored round',
      (tester) async {
    final app = await _mount(tester, board: _board(values: [5, 4, 3, 2, 1]));
    final oldLast = _tap(tester, 1);
    final oldFirst = _tap(tester, 5);
    final oldList = _reorder(tester);
    await _restore(tester, app, _board(values: [2, 1], swaps: 7, selected: 0));
    final before = _snapshot(tester);
    oldLast.onTap!();
    oldFirst.onTap!();
    oldList.onReorderItem!(4, 0);
    oldList.onReorderItem!(0, 4);
    final current = _reorder(tester);
    current.onReorderItem!(-1, 0);
    current.onReorderItem!(0, 2);
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mid-launch reduced motion finishes visuals but keeps dialog deadline',
      (tester) async {
    final app = await _mount(tester);
    await _sort(tester);
    await tester.pump(const Duration(milliseconds: 300));
    app.motion.value = true;
    await tester.pump();
    // The implicit ship decoration transition is also allowed to settle.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    final launchedShip = tester.widget<Transform>(
        find.ancestor(of: _ship(1), matching: find.byType(Transform)).first);
    expect(launchedShip.transform.storage[13], -300);
    final fadedShip = tester.widget<Opacity>(
        find.ancestor(of: _ship(1), matching: find.byType(Opacity)).first);
    expect(fadedShip.opacity, .2);
    expect(_dialog, findsNothing);
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 699));
    expect(_dialog, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsOneWidget);
    _grade(app);
  });

  testWidgets(
      'disposal cancels launch timer and retained tap/reorder callbacks',
      (tester) async {
    final app = await _mount(tester);
    final tap = _tap(tester, 4);
    final reorder = _reorder(tester);
    await _sort(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    tap.onTap!();
    reorder.onReorderItem!(0, 3);
    await tester.pump(const Duration(seconds: 3));
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });
}
