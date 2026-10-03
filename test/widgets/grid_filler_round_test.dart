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
import 'package:space_math_academy/features/games/screens/grid_filler_game.dart';
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
          home: const GridFillerGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(GridFillerGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {bool nearWin = false, int rejected = 2, int size = 3}) {
  final blue = Colors.blue.toARGB32();
  final orange = Colors.orange.toARGB32();
  return {
    '_pieceTypes': size == 3 ? 2 : 1,
    'gridSize': size,
    '_rejectedPlacements': rejected,
    'availablePieces': size == 3
        ? [
            {
              'size': 2,
              'count': 1,
              'color': blue,
              'remainingCount': nearWin ? 0 : 1
            },
            {
              'size': 1,
              'count': 5,
              'color': orange,
              'remainingCount': nearWin ? 1 : 5
            },
          ]
        : [
            {
              'size': 1,
              'count': size * size,
              'color': orange,
              'remainingCount': size * size
            },
          ],
    'placedPieces': nearWin
        ? [
            PlacedPiece(size: 2, position: Offset.zero, color: Colors.blue)
                .toJson(),
            for (final point in [
              const Offset(2, 0),
              const Offset(2, 1),
              const Offset(0, 2),
              const Offset(1, 2)
            ])
              PlacedPiece(size: 1, position: point, color: Colors.orange)
                  .toJson(),
          ]
        : <Map<String, dynamic>>[],
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

final _grid = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is GridFillerPainter);
final _target =
    find.byWidgetPredicate((widget) => widget is DragTarget<Object>);
Finder _inventory(int size) => find.byWidgetPredicate((widget) =>
    widget is LongPressDraggable<GridPiece> && widget.data!.size == size);
Finder _placed(PlacedPiece piece) => find.byWidgetPredicate((widget) =>
    widget is LongPressDraggable<PlacedPiece> && identical(widget.data, piece));
GestureDetector _tapWidget(WidgetTester tester, Finder parent) =>
    tester.widget<GestureDetector>(find
        .descendant(
            of: parent,
            matching: find.byWidgetPredicate(
                (widget) => widget is GestureDetector && widget.onTap != null))
        .first);
Offset _cell(WidgetTester tester, int x, int y) {
  final painter =
      tester.widget<CustomPaint>(_grid).painter! as GridFillerPainter;
  return tester.getTopLeft(_grid) +
      Offset((x + .5) * painter.cellSize, (y + .5) * painter.cellSize);
}

Future<void> _place(WidgetTester tester, int size, int x, int y) async {
  if ((_session(tester).selectedPiece as GridPiece?)?.size != size) {
    await tester.tap(_inventory(size));
    await tester.pump();
  }
  await tester.tapAt(_cell(tester, x, y));
  await tester.pump();
}

Future<void> _win(WidgetTester tester) => _place(tester, 1, 2, 2);
DragTarget<Object> _drop(WidgetTester tester) =>
    tester.widget<DragTarget<Object>>(_target);
void _deliver(DragTarget<Object> target, Object data, Offset offset) =>
    target.onAcceptWithDetails!(
        DragTargetDetails<Object>(data: data, offset: offset));
void _clean(WidgetTester tester) {
  final dynamic session = _session(tester);
  expect(session.selectedPiece, isNull);
  expect(session.hoverGridPosition, isNull);
  expect(session.draggedPlacedPiece, isNull);
  expect(session.dragPreviewPosition, isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'grid_filler_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_grid_filler_game': true});
    PuzzleSessionStore.resetForTesting();
  });

  test('grid painter invalidates geometry and preview color', () {
    GridFillerPainter painter(
            {int size = 3, double cell = 20, Color color = Colors.blue}) =>
        GridFillerPainter(
            gridSize: size,
            cellSize: cell,
            hoverPosition: Offset.zero,
            previewSize: 1,
            previewColor: color,
            canPlace: true);
    final previous = painter();
    expect(painter().shouldRepaint(previous), isFalse);
    expect(painter(size: 4).shouldRepaint(previous), isTrue);
    expect(painter(cell: 21).shouldRepaint(previous), isTrue);
    expect(painter(color: Colors.red).shouldRepaint(previous), isTrue);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'win reports once and retains 500ms dialog then real retry (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(nearWin: true));
      final oldPanel = _tapWidget(tester, _inventory(1));
      final oldTarget = _drop(tester);
      final oldPiece =
          (_session(tester).availablePieces as List).last as GridPiece;
      final point = _cell(tester, 2, 2);
      await _win(tester);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.score, 260);
      expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(2, per: .1));
      expect(_session(tester).capturePuzzleSession(), isNull);
      _clean(tester);
      oldPanel.onTap!();
      _deliver(oldTarget, oldPiece, point);
      await tester.pump(const Duration(milliseconds: 499));
      expect(_dialog, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 1);
      await tester.tap(find.widgetWithText(
          TextButton, _strings(tester).gridFillerPlayAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      expect(_session(tester).placedPieces, isEmpty);
      expect(
          (_session(tester).availablePieces as List)
              .every((dynamic piece) => piece.remainingCount == piece.count),
          isTrue);
      _clean(tester);
    });

    testWidgets(
        'replacement cancels winning dialog and effects (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(nearWin: true));
      await _win(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await _restore(tester, app, _board(size: 1, rejected: 0));
      final before = _snapshot(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester), before);
      _clean(tester);
      expect(app.gp.outcomeCount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'invalid placement retains mistakes; depleted and removed objects reject duplicates',
      (tester) async {
    await _mount(tester, reduced: true, board: _board(rejected: 0));
    final piece = (_session(tester).availablePieces as List).first as GridPiece;
    final panel = _tapWidget(tester, _inventory(2));
    await _place(tester, 2, 2, 2);
    expect(_snapshot(tester)['_rejectedPlacements'], 1);
    expect(piece.remainingCount, 1);
    // A rejected placement keeps the selection.
    await tester.tapAt(_cell(tester, 0, 0));
    await tester.pump();
    expect(piece.remainingCount, 0);
    final before = _snapshot(tester);
    panel.onTap!();
    _deliver(_drop(tester), piece, _cell(tester, 0, 2));
    await tester.pump();
    expect(_snapshot(tester), before);
    final placed =
        (_session(tester).placedPieces as List).single as PlacedPiece;
    final remove = _tapWidget(tester, _placed(placed));
    await tester.tap(_placed(placed));
    await tester.pump();
    remove.onTap!();
    _deliver(_drop(tester), placed, _cell(tester, 1, 1));
    await tester.pump();
    expect(piece.remainingCount, 1);
    expect(_session(tester).placedPieces, isEmpty);
    expect(_snapshot(tester)['_rejectedPlacements'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonfinite drop coordinates reject without mutating inventory',
      (tester) async {
    await _mount(tester, reduced: true, board: _board(rejected: 0));
    final piece = (_session(tester).availablePieces as List).first as GridPiece;
    final target = _drop(tester);
    for (final offset in [
      const Offset(double.nan, 0),
      const Offset(0, double.infinity)
    ]) {
      _deliver(target, piece, offset);
    }
    await tester.pump();
    expect(piece.remainingCount, 1);
    expect(_session(tester).placedPieces, isEmpty);
    expect(_snapshot(tester)['_rejectedPlacements'], 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real inventory long-press drop consumes one piece and clears hover',
      (tester) async {
    await _mount(tester, reduced: true, board: _board(size: 2));
    final source = _inventory(1);
    final origin = tester.getCenter(source);
    final topLeft = tester.getTopLeft(source);
    final painter =
        tester.widget<CustomPaint>(_grid).painter! as GridFillerPainter;
    final feedbackOrigin = tester.getTopLeft(_grid) +
        Offset(painter.cellSize * .1, painter.cellSize * .1);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveTo(origin + feedbackOrigin - topLeft);
    await tester.pump();
    expect(_session(tester).hoverGridPosition, Offset.zero);
    await gesture.up();
    await tester.pump();
    expect((_session(tester).availablePieces as List).single.remainingCount, 3);
    expect(
        (_session(tester).placedPieces as List).single.position, Offset.zero);
    expect(_session(tester).hoverGridPosition, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real accepted placed-piece drag moves then tap restores inventory',
      (tester) async {
    await _mount(tester, reduced: true, board: _board(size: 2));
    await _place(tester, 1, 0, 0);
    final piece = (_session(tester).placedPieces as List).single as PlacedPiece;
    final finder = _placed(piece);
    final origin = tester.getCenter(finder);
    final topLeft = tester.getTopLeft(finder);
    final destination = _cell(tester, 1, 0);
    final painter =
        tester.widget<CustomPaint>(_grid).painter! as GridFillerPainter;
    final feedbackOrigin =
        destination - Offset(painter.cellSize * .4, painter.cellSize * .4);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_session(tester).draggedPlacedPiece, same(piece));
    await gesture.moveTo(origin + feedbackOrigin - topLeft);
    await tester.pump();
    expect(_session(tester).dragPreviewPosition, const Offset(1, 0));
    await gesture.up();
    await tester.pump();
    expect(piece.position, const Offset(1, 0));
    expect(_session(tester).draggedPlacedPiece, isNull);
    await tester.tap(_placed(piece));
    await tester.pump();
    expect(_session(tester).placedPieces, isEmpty);
    expect((_session(tester).availablePieces as List).single.remainingCount, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'smaller restored board rejects retained callbacks and foreign model identities',
      (tester) async {
    final app = await _mount(tester, board: _board(nearWin: true));
    final oldPiece =
        (_session(tester).availablePieces as List).last as GridPiece;
    final oldPlaced =
        (_session(tester).placedPieces as List).first as PlacedPiece;
    final panel = tester.widget<LongPressDraggable<GridPiece>>(_inventory(1));
    final panelTap = _tapWidget(tester, _inventory(1));
    final placed =
        tester.widget<LongPressDraggable<PlacedPiece>>(_placed(oldPlaced));
    final placedTap = _tapWidget(tester, _placed(oldPlaced));
    final target = _drop(tester);
    panelTap.onTap!();
    panel.onDragStarted!();
    target.onMove!(
        DragTargetDetails<Object>(data: oldPiece, offset: _cell(tester, 2, 2)));
    await tester.pump();
    expect(_session(tester).hoverGridPosition, isNotNull);
    placed.onDragStarted!();
    target.onMove!(DragTargetDetails<Object>(
        data: oldPlaced, offset: _cell(tester, 0, 0)));
    await tester.pump();
    expect(_session(tester).draggedPlacedPiece, same(oldPlaced));
    expect(_session(tester).dragPreviewPosition, isNotNull);
    await _restore(tester, app, _board(size: 1, rejected: 0));
    final before = _snapshot(tester);
    _clean(tester);
    panelTap.onTap!();
    placedTap.onTap!();
    panel.onDragStarted!();
    placed.onDragStarted!();
    for (final old in [oldPiece, oldPlaced]) {
      _deliver(target, old, Offset.zero);
      final current = _drop(tester);
      expect(
          current.onWillAcceptWithDetails!(
              DragTargetDetails<Object>(data: old, offset: Offset.zero)),
          isFalse);
      _deliver(current, old, Offset.zero);
      current
          .onMove!(DragTargetDetails<Object>(data: old, offset: Offset.zero));
    }
    final end = DraggableDetails(
        wasAccepted: false, velocity: Velocity.zero, offset: Offset.zero);
    panel.onDragEnd!(end);
    placed.onDragEnd!(end);
    await tester.pump(const Duration(seconds: 2));
    expect(_snapshot(tester), before);
    _clean(tester);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reduced motion enabled during victory stops tickers without accelerating dialog',
      (tester) async {
    final app = await _mount(tester, board: _board(nearWin: true));
    await _win(tester);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(_dialog, findsNothing);
    await tester.pump(const Duration(milliseconds: 336));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('real reset invalidates pending victory dialog', (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(nearWin: true));
    await _win(tester);
    await tester.tap(find.widgetWithText(
        ElevatedButton, _strings(tester).gridFillerResetGrid));
    await tester.pump();
    final before = _snapshot(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(_dialog, findsNothing);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('disposal cancels victory timer and retained input',
      (tester) async {
    final app = await _mount(tester, board: _board(nearWin: true));
    final panel = _tapWidget(tester, _inventory(1));
    final target = _drop(tester);
    final piece = (_session(tester).availablePieces as List).last as GridPiece;
    await _win(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    panel.onTap!();
    _deliver(target, piece, Offset.zero);
    await tester.pump(const Duration(seconds: 3));
    expect(_dialog, findsNothing);
    expect(app.gp.outcomeCount, 1);
    expect(tester.takeException(), isNull);
  });
}
