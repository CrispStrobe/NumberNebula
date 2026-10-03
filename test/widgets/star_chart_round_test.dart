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
import 'package:space_math_academy/features/games/screens/star_chart_scan_game.dart';
import 'package:space_math_academy/features/games/services/star_chart_scan_logic.dart';
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
          home: const StarChartScanGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(StarChartScanGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board({bool two = false, int wrong = 0}) {
  const equations = ['1+1=2', '2+1=3'];
  final grid = List.generate(6, (_) => List.filled(6, '9'));
  for (var row = 0; row < (two ? 2 : 1); row++) {
    for (var col = 0; col < 5; col++) {
      grid[row][col] = equations[row][col];
    }
  }
  final puzzle = StarChartScanPuzzle(
    gridSize: 6,
    grid: grid,
    placedEquations: [
      for (var row = 0; row < (two ? 2 : 1); row++)
        PlacedEquation(
          equation: equations[row],
          startRow: row,
          startCol: 0,
          direction: cardinalDirections.first,
          cells: [for (var col = 0; col < 5; col++) (row, col)],
        ),
    ],
    equationsToFind: equations.take(two ? 2 : 1).toList(),
  );
  return {
    'puzzle': puzzle.toJson(),
    '_foundEquations': <String>[],
    '_wrongSelections': wrong,
    '_foundCells': <String>[],
    '_cellEquationIndex': <List<dynamic>>[],
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

final _grid = find.byWidgetPredicate((widget) =>
    widget is CustomPaint &&
    widget.painter.runtimeType.toString() == '_GridPainter');
dynamic _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_grid).painter;
Offset _cell(WidgetTester tester, int row, int col) {
  final double size = _painter(tester).cellSize;
  return tester.getTopLeft(_grid) +
      Offset((col + 0.5) * size, (row + 0.5) * size);
}

Future<TestGesture> _startSweep(WidgetTester tester, int row, int col) async {
  final gesture = await tester.startGesture(_cell(tester, row, col));
  // Cross touch slop while remaining inside the starting cell.
  await gesture.moveBy(const Offset(25, 0));
  await tester.pump();
  return gesture;
}

Future<void> _sweep(WidgetTester tester,
    {int row = 0, bool reverse = false}) async {
  final gesture = await _startSweep(tester, row, reverse ? 4 : 0);
  await gesture.moveTo(_cell(tester, row, reverse ? 0 : 4));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'star_chart_rounds_${profile++}';
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    for (final reverse in [false, true]) {
      testWidgets(
          'winning sweep reports once and waits 600ms (reduced:$reduced, reverse:$reverse)',
          (tester) async {
        final app = await _mount(tester, reduced: reduced);
        await _sweep(tester, reverse: reverse);
        expect(app.gp.outcomeCount, 1);
        expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
        expect(app.gp.lastOutcome!.performance, 1);
        expect(app.gp.lastOutcome!.score, 155);
        expect(_session(tester).capturePuzzleSession(), isNull);
        expect(_dialog, findsNothing);
        // Completed boards reject subsequent sweeps while the dialog is pending.
        await _sweep(tester, row: 2);
        expect(app.gp.outcomeCount, 1);
        expect(_painter(tester).currentSelection, isEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        expect(_dialog, findsNothing);
        await tester.pump(const Duration(milliseconds: 150));
        expect(_dialog, findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(_dialog, findsOneWidget);
        expect(app.gp.outcomeCount, 1);
        await _unmount(tester);
      });
    }
    testWidgets('restoring cancels pending win dialog (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _sweep(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final replacement = _board(two: true, wrong: 3);
      await _restore(tester, app, replacement);
      await tester.pump(const Duration(seconds: 1));
      expect(_snapshot(tester), replacement);
      expect(_dialog, findsNothing);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
    testWidgets('disposing cancels pending win dialog (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _sweep(tester);
      await _unmount(tester);
      expect(app.gp.outcomeCount, 1);
      expect(_dialog, findsNothing);
    });
  }

  testWidgets('partial progress and wrong sweeps restore without recounting',
      (tester) async {
    final app = await _mount(tester, board: _board(two: true, wrong: 4));
    await _sweep(tester);
    await _sweep(tester, row: 2);
    final saved = _snapshot(tester);
    expect(saved['_foundEquations'], ['1+1=2']);
    expect(saved['_foundCells'], [for (var col = 0; col < 5; col++) '0,$col']);
    expect(saved['_wrongSelections'], 5);
    await _restore(tester, app, saved);
    expect(_snapshot(tester), saved);
    expect(app.gp.outcomeCount, 0);
    await _sweep(tester, row: 1);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(3, per: 0.08));
    expect(app.gp.lastOutcome!.score, 185);
    await _unmount(tester);
  });

  testWidgets(
      'restoring during a drag discards its selection and late pointer events',
      (tester) async {
    final app = await _mount(tester, board: _board(two: true));
    final gesture = await _startSweep(tester, 0, 0);
    await gesture.moveTo(_cell(tester, 0, 4));
    await tester.pump();
    expect(_painter(tester).currentSelection, hasLength(5));
    final replacement = _board(two: true, wrong: 3);
    await _restore(tester, app, replacement);
    expect(_painter(tester).currentSelection, isEmpty);
    await gesture.moveTo(_cell(tester, 1, 4));
    await gesture.up();
    await tester.pump();
    expect(_snapshot(tester), replacement);
    expect(app.gp.outcomeCount, 0);
    await _sweep(tester);
    expect(_snapshot(tester)['_foundEquations'], ['1+1=2']);
    await _unmount(tester);
  });

  testWidgets(
      'cancelled gesture clears the highlight without counting a mistake',
      (tester) async {
    final app = await _mount(tester);
    final gesture = await _startSweep(tester, 0, 0);
    await gesture.moveTo(_cell(tester, 0, 4));
    await tester.pump();
    expect(_painter(tester).currentSelection, hasLength(5));
    await gesture.cancel();
    await tester.pump();
    expect(_painter(tester).currentSelection, isEmpty);
    expect(_snapshot(tester)['_wrongSelections'], 0);
    expect(app.gp.outcomeCount, 0);
    await _sweep(tester);
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });

  testWidgets('play again begins a fresh saveable round', (tester) async {
    final app = await _mount(tester);
    await _sweep(tester);
    await tester.pump(const Duration(milliseconds: 650));
    final retry = find.descendant(
        of: _dialog,
        matching:
            find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsNothing);
    expect(_session(tester).puzzleSessionFinished, isFalse);
    final saved = _snapshot(tester);
    expect(saved['_foundEquations'], isEmpty);
    expect(saved['_wrongSelections'], 0);
    expect(_painter(tester).currentSelection, isEmpty);
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });
}
