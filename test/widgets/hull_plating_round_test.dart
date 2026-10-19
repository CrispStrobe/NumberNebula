import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/game_registry.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/hull_plating_game.dart';
import 'package:space_math_academy/features/games/services/hull_plating_logic.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'package:space_math_academy/generated/l10n.dart';

import 'support/round_dialog_finder.dart';

class _App {
  final Locale locale;
  final double scale;
  final ValueNotifier<bool> motion;
  final pause = GamePauseController();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({this.locale = const Locale('en'), this.scale = 1, bool reduced = true})
      : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider.value(value: debug),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: motion,
            builder: (_, reduced, __) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale)),
              child: GamePauseScope(controller: pause, child: child!),
            ),
          ),
          home: const HullPlatingGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(HullPlatingGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> _snapshot(WidgetTester t) =>
    _copy(_state(t).capturePuzzleSession() as Map<String, dynamic>);
typedef _Drag = ({int pieceId, Object round, int rotation});
final _sources = find.byWidgetPredicate((w) => w is Draggable);
final _targets = find.byWidgetPredicate((w) => w is DragTarget);
Finder _source(WidgetTester t, int id) => find.byWidgetPredicate((w) {
      if (w is! Draggable) return false;
      final dynamic data = w.data;
      return data is int
          ? (_state(t).puzzle as HullPlatingPuzzle).pieces[data].id == id
          : data.pieceId == id;
    });
Finder _cell(WidgetTester t, int row, int col) {
  final cells = _placed(_snapshot(t)).expand((p) => p.absoluteCells).toSet();
  final p = _state(t).puzzle as HullPlatingPuzzle;
  var index = 0;
  for (var r = 0; r < p.rows; r++) {
    for (var c = 0; c < p.cols; c++) {
      if (!p.board[r][c] || cells.contains((r, c))) continue;
      if (r == row && c == col) return _targets.at(index);
      index++;
    }
  }
  throw StateError('Cell ($row,$col) is not empty');
}

List<PlacedPiece> _placed(Map<String, dynamic> board) =>
    (board['_placedPieces'] as List)
        .map((p) => PlacedPiece.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
Map<String, dynamic> _board(
    {List<PlacedPiece> placed = const [],
    int moves = 0,
    int rotation = 0,
    bool reversed = false,
    bool tall = false}) {
  final pieces = [
    PlatingPiece(
        id: 10,
        cells: tall ? [(0, 0), (0, 1), (0, 2)] : [(0, 0), (0, 1)],
        color: Color4.red),
    PlatingPiece(
        id: 20,
        cells: tall ? [(0, 0), (0, 1), (0, 2)] : [(0, 0), (0, 1)],
        color: Color4.blue),
  ];
  final solution = tall
      ? [
          PlacedPiece(pieceId: 10, absoluteCells: [(0, 0), (1, 0), (2, 0)]),
          PlacedPiece(pieceId: 20, absoluteCells: [(0, 1), (1, 1), (2, 1)])
        ]
      : [_row(10, 0), _row(20, 1)];
  final p = HullPlatingPuzzle(
      rows: tall ? 3 : 2,
      cols: 2,
      board: List.generate(tall ? 3 : 2, (_) => [true, true]),
      pieces: reversed ? pieces.reversed.toList() : pieces,
      solution: solution);
  // Independently conserve physical IDs, cells and rotated shape geometry.
  final coverage = <(int, int)>{};
  for (final placement in p.solution) {
    final piece = p.pieces.singleWhere((v) => v.id == placement.pieceId);
    final minRow = placement.absoluteCells
        .map((c) => c.$1)
        .reduce((a, b) => a < b ? a : b);
    final minCol = placement.absoluteCells
        .map((c) => c.$2)
        .reduce((a, b) => a < b ? a : b);
    final normalized = placement.absoluteCells
        .map((c) => (c.$1 - minRow, c.$2 - minCol))
        .toSet();
    expect(
        piece.allRotations().any((v) =>
            v.cells.toSet().containsAll(normalized) &&
            v.cells.length == normalized.length),
        isTrue);
    for (final c in placement.absoluteCells) {
      expect(c.$1, inInclusiveRange(0, p.rows - 1));
      expect(c.$2, inInclusiveRange(0, p.cols - 1));
      expect(coverage.add(c), isTrue);
    }
  }
  expect(coverage.length, p.rows * p.cols);
  expect(p.solution.map((v) => v.pieceId).toSet(), {10, 20});
  return {
    'puzzle': p.toJson(),
    '_placedPieces': placed.map((p) => p.toJson()).toList(),
    '_selectedRotation': rotation,
    '_usedPieceIds': placed.map((p) => p.pieceId).toList(),
    '_placements': moves
  };
}

PlacedPiece _row(int id, int row) =>
    PlacedPiece(pieceId: id, absoluteCells: [(row, 0), (row, 1)]);
Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic s = _state(t);
  s.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  s.setState(() => s.applyPuzzleSession(_copy(board)));
  await t.pump();
  await t.pump();
}

Future<_App> _mount(WidgetTester t,
    {bool reduced = true,
    Locale locale = const Locale('en'),
    double scale = 1}) async {
  final app = _App(locale: locale, scale: scale, reduced: reduced);
  t.view.physicalSize = const Size(1400, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    app.motion.dispose();
    app.pause.dispose();
  });
  await t.pumpWidget(app.build());
  for (var i = 0; i < 30; i++) {
    await t.pump();
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    if (_state(t).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_state(t).capturePuzzleSession(), isNotNull);
  await _restore(t, _board());
  return app;
}

void _deliver(dynamic target, dynamic data) {
  if (data is int) {
    target.onAcceptWithDetails!(
        DragTargetDetails<int>(data: data, offset: Offset.zero));
  } else {
    target.onAcceptWithDetails!(
        DragTargetDetails<_Drag>(data: data as _Drag, offset: Offset.zero));
  }
}

Future<void> _drop(WidgetTester t, int id, int row, int col) async {
  final source = _source(t, id);
  final target = _cell(t, row, col);
  await t.ensureVisible(source);
  await t.pump();
  final handle = _handle(source);
  await t.ensureVisible(handle);
  await t.pump();
  expect(handle.hitTestable(), findsOneWidget);
  expect(target.hitTestable(), findsOneWidget);
  await t.drag(handle, t.getCenter(target) - t.getCenter(handle));
  await t.pump();
}

Finder _handle(Finder source) => find
    .descendant(
        of: source,
        matching: find.byWidgetPredicate(
            (w) => w is Text && (w.data?.endsWith(' cells') ?? false)))
    .first;
Finder _rotate() => find.widgetWithIcon(ElevatedButton, Icons.rotate_right);
Finder _clear() => find.widgetWithIcon(IconButton, Icons.delete_sweep);
Finder _removal() => find.ancestor(
    of: find.byIcon(Icons.close),
    matching:
        find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null));
Future<void> _dialog(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
  expect(roundDialogs, findsOneWidget);
}

Finder _retry() => find
    .descendant(
        of: roundDialogs,
        matching: find.byWidgetPredicate((w) =>
            w is ButtonStyleButton && w.onPressed != null && w.child is Text))
    .first;
Future<void> _finish(WidgetTester t) async {
  await _restore(t, _board(placed: [_row(10, 0)], moves: 1));
  await _drop(t, 20, 1, 0);
  await _dialog(t);
}

Future<void> _cover(WidgetTester t) async {
  showDialog<void>(
      context: t.element(_screen),
      builder: (_) => const AlertDialog(content: Text('Covering route')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void _willAccept(dynamic target, dynamic data) {
  if (data is int) {
    target.onWillAcceptWithDetails!(
        DragTargetDetails<int>(data: data, offset: Offset.zero));
  } else {
    target.onWillAcceptWithDetails!(
        DragTargetDetails<_Drag>(data: data as _Drag, offset: Offset.zero));
  }
}

void _leave(dynamic target, dynamic data) => target.onLeave!(data);
BoxDecoration _paintedCell(WidgetTester t, Finder target) => t
    .widget<DecoratedBox>(
        find.descendant(of: target, matching: find.byType(DecoratedBox)).first)
    .decoration as BoxDecoration;

Future<void> _dropFirstGenerated(WidgetTester t) async {
  final p = _state(t).puzzle as HullPlatingPuzzle;
  final dynamic data = t.widget<Draggable>(_sources.first).data;
  final id = data is int ? p.pieces[data].id : data.pieceId as int;
  final piece = p.pieces.singleWhere((v) => v.id == id);
  final solution = p.solution.singleWhere((v) => v.pieceId == id);
  int min(int a, int b) => a < b ? a : b;
  int max(int a, int b) => a > b ? a : b;
  final originRow = solution.absoluteCells.map((c) => c.$1).reduce(min);
  final originCol = solution.absoluteCells.map((c) => c.$2).reduce(min);
  final anchorRow = originRow + piece.cells.map((c) => c.$1).reduce(max) ~/ 2;
  final anchorCol = originCol + piece.cells.map((c) => c.$2).reduce(max) ~/ 2;
  await _drop(t, id, anchorRow, anchorCol);
  final saved = _snapshot(t);
  expect(saved['_placements'], 1);
  expect(_placed(saved).single.pieceId, id);
  expect(_placed(saved).single.absoluteCells.toSet(),
      solution.absoluteCells.toSet());
}

void main() {
  var profile = 0;
  setUp(() {
    ProfilePreferences.activeId = 'hull_rounds_${profile++}';
    SharedPreferences.setMockInitialValues({});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets(
      'contract: consumed payload cannot duplicate a physical plate to win',
      (t) async {
    final app = await _mount(t);
    final dynamic source = t.widget(_source(t, 10));
    final dynamic target = t.widget(_cell(t, 1, 0));
    _deliver(t.widget(_cell(t, 0, 0)), source.data);
    await t.pump();
    final before = _snapshot(t);
    _deliver(target, source.data);
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: old target and payload reject a reordered restored round',
      (t) async {
    final app = await _mount(t);
    final dynamic source = t.widget(_source(t, 10));
    final dynamic target = t.widget(_cell(t, 0, 0));
    await _restore(t, _board(reversed: true));
    final before = _snapshot(t);
    _deliver(target, source.data);
    _deliver(t.widget(_cell(t, 1, 0)), source.data);
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: real grouped drops consume distinct plates and win once',
      (t) async {
    final app = await _mount(t);
    expect(find.text('×2'), findsOneWidget);
    await _drop(t, 10, 0, 0);
    final s = _snapshot(t);
    expect(s['_usedPieceIds'], [10]);
    expect(s['_placements'], 1);
    expect(_placed(s).single.absoluteCells, [(0, 0), (0, 1)]);
    expect(find.text('×2'), findsNothing);
    await _drop(t, 20, 1, 0);
    await _dialog(t);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(app.gp.lastOutcome!.score, 185);
    expect(app.gp.lastOutcome!.movesUsed, 2);
    expect(app.gp.lastOutcome!.optimalMoves, 2);
    expect(app.gp.lastOutcome!.performance, 1);
    expect(_state(t).capturePuzzleSession(), isNull);
  });
  testWidgets(
      'contract: actual rotation and removal preserve placement accounting',
      (t) async {
    final app = await _mount(t);
    await t.tap(_rotate());
    await t.pump();
    expect(_snapshot(t)['_selectedRotation'], 1);
    await _drop(t, 10, 0, 0);
    expect(_placed(_snapshot(t)).single.absoluteCells, [(0, 0), (1, 0)]);
    expect(_snapshot(t)['_selectedRotation'], 0);
    await t.tap(_removal().first);
    await t.pump();
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    expect(_snapshot(t)['_usedPieceIds'], isEmpty);
    expect(_snapshot(t)['_placements'], 1);
    expect(find.text('×2'), findsOneWidget);
    await _drop(t, 10, 0, 0);
    await _drop(t, 20, 1, 0);
    await _dialog(t);
    expect(app.gp.lastOutcome!.movesUsed, 3);
    expect(app.gp.lastOutcome!.performance, Perf.fromMoves(3, 2));
  });
  testWidgets('contract: three-cell center anchor preserves rotated footprint',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(tall: true));
    await t.tap(_rotate());
    await t.pump();
    await _drop(t, 10, 1, 0);
    expect(_placed(_snapshot(t)).single.absoluteCells.toSet(),
        {(0, 0), (1, 0), (2, 0)});
    // Successful placement resets the live tray rotation, as before.
    await t.tap(_rotate());
    await t.pump();
    await _drop(t, 20, 1, 1);
    await _dialog(t);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets(
      'contract: bounds and overlap rejections preserve inventory and par',
      (t) async {
    final app = await _mount(t);
    await _drop(t, 10, 0, 1);
    expect(_snapshot(t)['_placements'], 0);
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    await _drop(t, 10, 0, 0);
    await t.tap(_rotate());
    await t.pump();
    final before = _snapshot(t);
    // Vertical plate centered on row1 extends outside the board.
    await _drop(t, 20, 1, 0);
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets('contract: unknown physical payload is ignored without exception',
      (t) async {
    await _mount(t);
    final dynamic data = t.widget<Draggable>(_sources.first).data;
    final dynamic invalid = data is int
        ? 999
        : (
            pieceId: 999,
            round: data.round as Object,
            rotation: data.rotation as int
          );
    final before = _snapshot(t);
    _willAccept(t.widget(_cell(t, 0, 0)), invalid);
    _deliver(t.widget(_cell(t, 0, 0)), invalid);
    await t.pump();
    expect(t.takeException(), isNull);
    expect(_snapshot(t), before);
  });
  testWidgets('contract: real drag overlay cannot cross round restoration',
      (t) async {
    await _mount(t);
    final handle = _handle(_source(t, 10));
    final g = await t.startGesture(t.getCenter(handle));
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    await _restore(t, _board(reversed: true));
    final before = _snapshot(t);
    await g.moveTo(t.getCenter(_cell(t, 0, 0)));
    await g.up();
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: retained dragged orientation survives live tray rotation',
      (t) async {
    await _mount(t);
    final dynamic source = t.widget(_source(t, 10));
    final dynamic target = t.widget(_cell(t, 0, 0));
    await t.tap(_rotate());
    await t.pump();
    _deliver(target, source.data);
    await t.pump();
    expect(_placed(_snapshot(t)).single.absoluteCells, [(0, 0), (0, 1)]);
  });
  testWidgets('contract: stale leave callback cannot clear a new-round hover',
      (t) async {
    await _mount(t);
    final dynamic source = t.widget(_source(t, 10));
    final dynamic oldTarget = t.widget(_cell(t, 0, 0));
    _willAccept(oldTarget, source.data);
    await t.pump();
    await _restore(t, _board());
    final dynamic newSource = t.widget(_source(t, 10));
    final target = _cell(t, 1, 0);
    _willAccept(t.widget(target), newSource.data);
    await t.pump();
    _leave(oldTarget, source.data);
    await t.pump();
    expect(_paintedCell(t, target).color,
        SpaceTheme.starYellow.withValues(alpha: .3));
  });
  for (final action in ['rotate', 'clear', 'remove', 'back']) {
    testWidgets('contract: retained $action rejects restored round', (t) async {
      await _mount(t);
      await _drop(t, 10, 0, 0);
      final VoidCallback callback = switch (action) {
        'rotate' => t.widget<ElevatedButton>(_rotate()).onPressed!,
        'clear' => t.widget<IconButton>(_clear()).onPressed!,
        'remove' => t.widget<GestureDetector>(_removal().first).onTap!,
        _ => t.widget<GameUI>(find.byType(GameUI)).onBack,
      };
      final before = _snapshot(t);
      await _restore(t, before);
      callback();
      await t.pump();
      expect(_snapshot(t), before);
    });
    testWidgets('contract: pointer-down $action cannot cross restore',
        (t) async {
      await _mount(t);
      await _drop(t, 10, 0, 0);
      final control = switch (action) {
        'rotate' => _rotate(),
        'clear' => _clear(),
        'remove' => _removal().first,
        _ => find.widgetWithIcon(IconButton, Icons.arrow_back_ios).first,
      };
      final g = await t.startGesture(t.getCenter(control));
      final before = _snapshot(t);
      await _restore(t, before);
      await g.up();
      await t.pump();
      expect(_snapshot(t), before);
    });
  }
  testWidgets('contract: restore clears obsolete drop effects and feedback',
      (t) async {
    await _mount(t, reduced: false);
    await _drop(t, 10, 0, 0);
    await t.pump(const Duration(milliseconds: 70));
    final before = _snapshot(t);
    await _restore(t, before);
    expect(
        find.descendant(
            of: _removal().first, matching: find.byType(ScaleTransition)),
        findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: real clear retains spent placement count and is persisted',
      (t) async {
    await _mount(t);
    await _drop(t, 10, 0, 0);
    await t.tap(_clear());
    await t.pump();
    expect(_snapshot(t)['_placements'], 1);
    expect(_snapshot(t)['_usedPieceIds'], isEmpty);
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    await t.pump(const Duration(milliseconds: 800));
    await PuzzleSessionStore.instance.flush();
    final saved = await PuzzleSessionStore.instance.load('hull_plating', 1, 1);
    expect(saved!['_placements'], 1);
    expect(saved['_placedPieces'], isEmpty);
    await _restore(t, saved);
    expect(_snapshot(t), saved);
  });
  testWidgets(
      'contract: restored placements rotation and inventory persist together',
      (t) async {
    await _mount(t);
    await _restore(t, _board(placed: [_row(10, 0)], moves: 3, rotation: 1));
    expect(_sources, findsOneWidget);
    expect(_source(t, 20), findsOneWidget);
    await t.pump(const Duration(milliseconds: 800));
    await PuzzleSessionStore.instance.flush();
    final saved = await PuzzleSessionStore.instance.load('hull_plating', 1, 1);
    expect(saved!['_selectedRotation'], 1);
    expect(saved['_usedPieceIds'], [10]);
    expect(saved['_placements'], 3);
    expect(_placed(saved).single.absoluteCells, [(0, 0), (0, 1)]);
  });
  testWidgets('contract: restored solved board offers retry without replay',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: [_row(10, 0), _row(20, 1)], moves: 2));
    await _dialog(t);
    expect(app.gp.outcomeCount, 0);
    expect(_state(t).capturePuzzleSession(), isNull);
    await t.ensureVisible(_retry());
    await t.tap(_retry());
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    expect(roundDialogs, findsNothing);
    expect(_state(t).capturePuzzleSession(), isNotNull);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets('contract: duplicate final callbacks cannot replay rewards',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: [_row(10, 0)], moves: 1));
    final dynamic source = t.widget(_source(t, 20));
    final dynamic target = t.widget(_cell(t, 1, 0));
    final remove = t.widget<GestureDetector>(_removal().first).onTap!;
    final clear = t.widget<IconButton>(_clear()).onPressed!;
    await _drop(t, 20, 1, 0);
    await _dialog(t);
    final outcome = app.gp.lastOutcome;
    remove();
    clear();
    _deliver(target, source.data);
    await t.pump();
    expect(app.gp.outcomeCount, 1);
    expect(identical(app.gp.lastOutcome, outcome), isTrue);
    expect(_state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
  });
  testWidgets(
      'contract: obsolete owned result is removed when restoring beneath a cover',
      (t) async {
    await _mount(t);
    await _finish(t);
    final retry = t.widget<ButtonStyleButton>(_retry()).onPressed!;
    await _cover(t);
    await _restore(t, _board());
    expect(find.text('Covering route'), findsOneWidget);
    final navigator = Navigator.of(t.element(find.text('Covering route')));
    navigator.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    expect(roundDialogs, findsNothing);
    retry();
    await t.pump();
    await _drop(t, 10, 0, 0);
    expect(_snapshot(t)['_placements'], 1);
  });
  testWidgets('contract: reset removes result even before its builder runs',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: [_row(10, 0)], moves: 1));
    final dynamic source = t.widget(_source(t, 20));
    _deliver(t.widget(_cell(t, 1, 0)), source.data);
    final dynamic state = _state(t);
    state.beginPuzzleSession();
    // ignore: invalid_use_of_protected_member
    state.setState(() => state.applyPuzzleSession(_copy(_board())));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    expect(roundDialogs, findsNothing);
    expect(app.gp.outcomeCount, 1);
    await _drop(t, 10, 0, 0);
    expect(_snapshot(t)['_placements'], 1);
  });
  testWidgets(
      'contract: retry remains usable and old retry cannot dismiss a cover',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    final retry = t.widget<ButtonStyleButton>(_retry()).onPressed!;
    await _cover(t);
    retry();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
    Navigator.of(t.element(find.text('Covering route'))).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(_retry());
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    expect(roundDialogs, findsNothing);
    expect(_snapshot(t)['_placements'], 0);
    expect(app.gp.outcomeCount, 1);
    await _dropFirstGenerated(t);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: back and suggested challenge respect covering route',
      (t) async {
    final app = await _mount(t);
    final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
    await _finish(t);
    final suggestion = t
        .widget<ButtonStyleButton>(find.descendant(
            of: find.byType(RoundSummary),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)))
        .onPressed;
    await _cover(t);
    back();
    suggestion!();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: retained controls after disposal cause no effects',
      (t) async {
    final app = await _mount(t);
    final rotate = t.widget<ElevatedButton>(_rotate()).onPressed!;
    final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final dynamic source = t.widget(_source(t, 10));
    final dynamic target = t.widget(_cell(t, 0, 0));
    await t.pumpWidget(const SizedBox.shrink());
    rotate();
    back();
    _willAccept(target, source.data);
    _leave(target, source.data);
    _deliver(target, source.data);
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(app.gp.outcomeCount, 0);
  });
  for (final locale in ['en', 'de']) {
    for (final height in [500.0, 844.0]) {
      testWidgets(
          'contract: phone controls and retry reachable at scale2 ($locale $height)',
          (t) async {
        await _mount(t, locale: Locale(locale), scale: 2);
        t.view.physicalSize = Size(390, height);
        await t.pump();
        expect(t.takeException(), isNull);
        expect(_rotate().hitTestable(), findsOneWidget);
        await _restore(t, _board(tall: true));
        await t.tap(_rotate());
        await t.pump();
        expect(t.takeException(), isNull);
        await _drop(t, 10, 1, 0);
        expect(_placed(_snapshot(t)).single.absoluteCells.toSet(),
            {(0, 0), (1, 0), (2, 0)});
        expect(_snapshot(t)['_placements'], 1);
        await t.tap(_rotate());
        await t.pump();
        await _drop(t, 20, 1, 1);
        await _dialog(t);
        expect(t.takeException(), isNull);
        await t.ensureVisible(_retry());
        await t.pump();
        expect(_retry().hitTestable(), findsOneWidget);
      });
    }
  }
  for (final reducedInitially in [true, false]) {
    testWidgets(
        'contract: ${reducedInitially ? 'initial' : 'mid-hover'} reduced motion snaps painted hover and drop',
        (t) async {
      final app = await _mount(t, reduced: reducedInitially);
      final source = _handle(_source(t, 10));
      final target = _cell(t, 0, 0);
      final g = await t.startGesture(t.getCenter(source));
      await g.moveTo(t.getCenter(target));
      await t.pump(const Duration(milliseconds: 50));
      app.motion.value = true;
      await t.pump();
      expect(_paintedCell(t, target).color,
          SpaceTheme.starYellow.withValues(alpha: .3));
      await g.up();
      await t.pump();
      final transitions = t.widgetList<ScaleTransition>(find.descendant(
          of: _removal(), matching: find.byType(ScaleTransition)));
      for (final transition in transitions) {
        expect(transition.scale.value, 1);
      }
      expect(_snapshot(t)['_placements'], 1);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'contract: reduced motion finishes an active drop without restoring transient effects',
      (t) async {
    final app = await _mount(t, reduced: false);
    await _drop(t, 10, 0, 0);
    await t.pump(const Duration(milliseconds: 70));
    expect(
        t
            .widgetList<ScaleTransition>(find.descendant(
                of: _removal(), matching: find.byType(ScaleTransition)))
            .any((v) => v.scale.value != 1),
        isTrue);
    app.motion.value = true;
    await t.pump();
    await t.pump();
    for (final transition in t.widgetList<ScaleTransition>(find.descendant(
        of: _removal(), matching: find.byType(ScaleTransition)))) {
      expect(transition.scale.value, 1);
    }
    expect(_snapshot(t)['_placements'], 1);
  });
  testWidgets(
      'contract: disposing game beneath its result removes only owned modal',
      (t) async {
    final app = await _mount(t);
    final gameRoute = ModalRoute.of(t.element(_screen))!;
    final navigator = Navigator.of(t.element(_screen));
    await _finish(t);
    await _cover(t);
    final coveringRoute =
        ModalRoute.of(t.element(find.text('Covering route')))!;
    navigator.removeRoute(gameRoute);
    await t.pump();
    await t.pump();
    expect(_screen, findsNothing);
    expect(find.text('Covering route'), findsOneWidget);
    expect(coveringRoute.isCurrent, isTrue);
    final allResults = find.byType(RoundSummary, skipOffstage: false);
    expect(allResults, findsNothing);
    expect(app.gp.outcomeCount, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('contract: retained occupied target rejects overlapping plate',
      (t) async {
    final app = await _mount(t);
    final dynamic oldTarget = t.widget(_cell(t, 0, 0));
    await _drop(t, 10, 0, 0);
    final dynamic source = t.widget(_source(t, 20));
    final before = _snapshot(t);
    _deliver(oldTarget, source.data);
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: old duplicate-ID save keeps plate unavailable until every copy is removed',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: [_row(10, 0), _row(10, 1)], moves: 2));
    expect(roundDialogs, findsNothing);
    expect(app.gp.outcomeCount, 0);
    await t.tap(_removal().first);
    await t.pump();
    expect(_placed(_snapshot(t)).single.pieceId, 10);
    expect(_snapshot(t)['_usedPieceIds'], [10]);
    expect(_source(t, 10), findsNothing);
    expect(_source(t, 20), findsOneWidget);
    expect(_snapshot(t)['_placements'], 2);
    await t.tap(_removal().first);
    await t.pump();
    expect(_source(t, 10), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });
  testWidgets('contract: restored inventory is derived from actual placements',
      (t) async {
    await _mount(t);
    final board = _board(placed: [_row(10, 0)], moves: 1);
    board['_usedPieceIds'] = [20];
    await _restore(t, board);
    expect(_snapshot(t)['_usedPieceIds'], [10]);
    expect(_source(t, 10), findsNothing);
    expect(_source(t, 20), findsOneWidget);
    await t.pump(const Duration(milliseconds: 800));
    await PuzzleSessionStore.instance.flush();
    final saved = await PuzzleSessionStore.instance.load('hull_plating', 1, 1);
    expect(saved!['_usedPieceIds'], [10]);
  });
  testWidgets(
      'contract: solved restore never displays an earlier Hull outcome as current evidence',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    expect(find.byType(RoundSummary), findsOneWidget);
    final earlier = app.gp.lastOutcome;
    await _restore(t, _board(placed: [_row(10, 0), _row(20, 1)], moves: 7));
    await _dialog(t);
    expect(find.byType(RoundSummary), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(app.gp.outcomeCount, 1);
    expect(identical(app.gp.lastOutcome, earlier), isTrue);
    expect(_state(t).capturePuzzleSession(), isNull);
    await t.ensureVisible(_retry());
    expect(_retry().hitTestable(), findsOneWidget);
  });
  testWidgets(
      'contract: actual suggested challenge opens a generated playable round',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    await t.runAsync(
        () => OnboardingOverlay.markSeen('hull_plating_all_games_guided_v2_rules'));
    await t.runAsync(() => loadGameLibrary('hull_plating'));
    final original = _state(t);
    final suggestion = find.descendant(
        of: find.byType(RoundSummary),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    await t.ensureVisible(suggestion);
    await t.tap(suggestion);
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 30; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump();
      if (_screen.evaluate().length == 1 &&
          !identical(_state(t), original) &&
          _state(t).capturePuzzleSession() != null) {
        break;
      }
    }
    expect(identical(_state(t), original), isFalse);
    expect(roundDialogs, findsNothing);
    await _dropFirstGenerated(t);
    expect(app.gp.outcomeCount, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'contract: actual drop crossing an inactive cell preserves inventory',
      (t) async {
    final app = await _mount(t);
    final p = HullPlatingPuzzle(rows: 2, cols: 3, board: [
      [true, true, true],
      [true, true, false]
    ], pieces: [
      PlatingPiece(id: 10, cells: [(0, 0), (0, 1)], color: Color4.red),
      PlatingPiece(id: 20, cells: [(0, 0), (0, 1), (1, 0)], color: Color4.blue),
    ], solution: [
      PlacedPiece(pieceId: 10, absoluteCells: [(0, 0), (1, 0)]),
      PlacedPiece(pieceId: 20, absoluteCells: [(0, 1), (0, 2), (1, 1)]),
    ]);
    // This valid five-cell packing includes a vertical domino rotation.
    final covered = p.solution.expand((piece) => piece.absoluteCells).toList();
    expect(covered.toSet(), {(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)});
    expect(covered.length, 5);
    final board = _board();
    board['puzzle'] = p.toJson();
    await _restore(t, board);
    final before = _snapshot(t);
    // Horizontal domino at (1,1) crosses the inactive cell (1,2).
    await _drop(t, 10, 1, 1);
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: retained removal cannot remove a different plate placed in the same round',
      (t) async {
    final app = await _mount(t);
    final board = _board();
    final pieces = (board['puzzle'] as Map<String, dynamic>)['pieces'] as List;
    // Distinct stored orientations keep both physical IDs available as real
    // tray sources after clear. Plate20 still fits its fixture solution rotated.
    (pieces[1] as Map<String, dynamic>)['cells'] = [
      [0, 0],
      [1, 0]
    ];
    await _restore(t, board);
    await _drop(t, 10, 0, 0);
    final oldRemove = t.widget<GestureDetector>(_removal().first).onTap!;
    expect(_snapshot(t)['_placements'], 1);
    await t.tap(_clear());
    await t.pump();
    expect(_snapshot(t)['_placements'], 1);
    await _drop(t, 20, 0, 0);
    final before = _snapshot(t);
    expect(_placed(before).single.pieceId, 20);
    expect(_placed(before).single.absoluteCells.toSet(), {(0, 0), (1, 0)});
    expect(before['_usedPieceIds'], [20]);
    expect(before['_placements'], 2);
    oldRemove();
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
    await t.tap(_removal().first);
    await t.pump();
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    expect(_snapshot(t)['_usedPieceIds'], isEmpty);
    expect(_snapshot(t)['_placements'], 2);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: retained removal cannot remove a new placement of the same physical plate',
      (t) async {
    final app = await _mount(t);
    await _drop(t, 10, 0, 0);
    final oldRemove = t.widget<GestureDetector>(_removal().first).onTap!;
    await t.tap(_removal().first);
    await t.pump();
    expect(_snapshot(t)['_placements'], 1);
    await _drop(t, 10, 0, 0);
    final before = _snapshot(t);
    expect(_placed(before).single.pieceId, 10);
    expect(_placed(before).single.absoluteCells, [(0, 0), (0, 1)]);
    expect(before['_usedPieceIds'], [10]);
    expect(before['_placements'], 2);
    // The ID and cells match the old model; the placed-instance identity differs.
    oldRemove();
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
    await t.tap(_removal().first);
    await t.pump();
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    expect(_snapshot(t)['_usedPieceIds'], isEmpty);
    expect(_snapshot(t)['_placements'], 2);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: pointer-down removal cannot transfer to a coalesced replacement plate',
      (t) async {
    final app = await _mount(t);
    final dynamic emptyTarget = t.widget(_cell(t, 0, 0));
    await _drop(t, 10, 0, 0);
    final dynamic unusedSource = t.widget(_source(t, 20));
    final clear = t.widget<IconButton>(_clear()).onPressed!;
    final gesture = await t.startGesture(t.getCenter(_removal().first));
    // Invoke actual control callbacks in the same frame: rendering an empty
    // cell between them would dispose the old recognizer and hide this defect.
    clear();
    _deliver(emptyTarget, unusedSource.data);
    await t.pump();
    final before = _snapshot(t);
    expect(_placed(before).single.pieceId, 20);
    expect(_placed(before).single.absoluteCells, [(0, 0), (0, 1)]);
    expect(before['_usedPieceIds'], [20]);
    expect(before['_placements'], 2);
    await gesture.up();
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
    await t.tap(_removal().first);
    await t.pump();
    expect(_snapshot(t)['_placedPieces'], isEmpty);
    expect(_snapshot(t)['_usedPieceIds'], isEmpty);
    expect(_snapshot(t)['_placements'], 2);
    expect(app.gp.outcomeCount, 0);
  });
}
