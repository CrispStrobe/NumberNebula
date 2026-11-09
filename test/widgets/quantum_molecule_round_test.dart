import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/levels.dart';
import 'package:space_math_academy/features/games/screens/quantum_molecule_builder_game.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'support/round_dialog_finder.dart';

class _RouteObserver extends NavigatorObserver {
  VoidCallback? onDialogPush;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is DialogRoute) onDialogPush?.call();
  }
}

class _Harness {
  final Locale locale;
  final double scale;
  final bool pushed;
  final Future<void> Function()? levelLoader;
  final ValueNotifier<bool> motion;
  final observer = _RouteObserver();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  _Harness({
    this.locale = const Locale('en'),
    this.scale = 1,
    this.pushed = false,
    this.levelLoader,
    bool reduced = false,
  }) : motion = ValueNotifier(reduced);
  late final gp = GameProvider(
    progressService: ProgressService(),
    sriService: sri,
    cognitiveProfileService: cognitive,
  );
  Widget _game() {
    if (levelLoader == null) {
      return const QuantumMoleculeBuilderGame(grade: 1, level: 1);
    }
    // Only loader seam cases invoke this optional constructor parameter. Using
    // the constructor tear-off keeps original-API counterfactual cases
    // compilable when run against the preceding screen without this seam.
    return Function.apply(QuantumMoleculeBuilderGame.new, const [], {
          #grade: 1,
          #level: 1,
          #levelLoader: levelLoader,
        })
        as Widget;
  }

  Widget build() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: gp),
      ChangeNotifierProvider.value(value: sri),
      ChangeNotifierProvider.value(value: cognitive),
      ChangeNotifierProvider.value(value: debug),
    ],
    child: MaterialApp(
      locale: locale,
      navigatorObservers: [observer],
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: motion,
        builder: (_, reduced, __) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
      home: pushed
          ? Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => _game())),
                    child: const Text('Start molecule'),
                  ),
                ),
              ),
            )
          : _game(),
    ),
  );
}

final _screen = find.byType(QuantumMoleculeBuilderGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> _capture(WidgetTester t) =>
    _copy(_state(t).capturePuzzleSession() as Map<String, dynamic>);
Finder _atom(WidgetTester t, String type) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.properties.label == S.of(t.element(_screen))!.a11yAtom(type),
);
Finder _undo() => find.widgetWithIcon(ElevatedButton, Icons.undo);
Atom _model(Map<String, dynamic> board, String id) => (board['atoms'] as List)
    .map((v) => Atom.fromJson(Map<String, dynamic>.from(v as Map)))
    .singleWhere((a) => a.id == id);
Future<(_Harness, Map<String, dynamic>)> _mount(
  WidgetTester t, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(1600, 1100),
  bool reduced = false,
  bool pushed = false,
}) async {
  final app = _Harness(
    locale: locale,
    scale: scale,
    reduced: reduced,
    pushed: pushed,
  );
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    app.motion.dispose();
  });
  await t.runAsync(() async {
    await loadMoleculeLevels();
  });
  await t.pumpWidget(app.build());
  if (pushed) {
    await t.tap(find.text('Start molecule'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
  }
  for (var i = 0; i < 30; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (_state(t).capturePuzzleSession() != null) break;
  }
  expect(_state(t).capturePuzzleSession(), isNotNull);
  final real = _capture(t);
  expect((real['grid'] as List).length, 16);
  expect(levelsData.length, 30);
  return (app, real);
}

Map<String, dynamic> _fixture(
  Map<String, dynamic> real, {
  bool replacement = false,
  bool winning = false,
  int limit = 12,
}) {
  // Preserve EVERY real captured session field, including authored level/progress
  // metadata. Only the explicit board/models/counts/viewport are replaced.
  final board = _copy(real);
  final row = replacement ? 8 : 3;
  final oxygenCol = replacement ? 10 : 6;
  final cells = List.generate(
    16,
    (r) => List.generate(
      16,
      (c) => r == 0 || r == 15 || c == 0 || c == 15
          ? CellType.wall.name
          : CellType.empty.name,
    ),
  );
  final atoms = [
    Atom(
      type: AtomType.hydrogen,
      row: row,
      col: 2,
      id: 'H',
      atomixIndex: winning ? 6 : 0,
    ),
    Atom(
      type: AtomType.oxygen,
      row: row,
      col: oxygenCol,
      id: 'O',
      atomixIndex: winning ? 10 : 11,
    ),
  ];
  final pattern = MoleculePattern(
    name: winning ? 'H-O corridor' : 'Vertical H-O',
    size: 2,
    grid: winning
        ? [
            [6, 10],
            [null, null],
          ]
        : [
            [0, null],
            [11, null],
          ],
    atomTypes: [AtomType.hydrogen, AtomType.oxygen],
  );
  board.addAll({
    'grid': cells,
    'atoms': atoms.map((a) => a.toJson()).toList(),
    'targetPattern': pattern.toJson(),
    'movesMade': 0,
    'moveLimit': limit,
    'gridOffsetX': 0,
    'gridOffsetY': 0,
    'visibleWidth': 16,
    'visibleHeight': 16,
    '_moveHistory': <dynamic>[],
  });
  expect(cells.length, 16);
  expect(cells.every((v) => v.length == 16), isTrue);
  expect(atoms.map((a) => a.id).toSet().length, 2);
  expect(atoms.map((a) => (a.row, a.col)).toSet().length, 2);
  for (final a in atoms) {
    expect(cells[a.row][a.col], CellType.empty.name);
  }
  // Independent cell-by-cell oracle: oxygen, rather than a target marker,
  // blocks the hydrogen one cell before its own occupied cell.
  expect(_endpoint(board, 'H', 0, 1), (row, oxygenCol - 1));
  expect(_endpoint(board, 'O', 0, -1), (row, 3));
  return board;
}

(int, int) _endpoint(Map<String, dynamic> board, String id, int dr, int dc) {
  final atom = _model(board, id);
  final occupied = (board['atoms'] as List)
      .map((v) => Atom.fromJson(Map<String, dynamic>.from(v as Map)))
      .where((a) => a.id != id)
      .map((a) => (a.row, a.col))
      .toSet();
  final cells = board['grid'] as List;
  var row = atom.row, col = atom.col;
  while (true) {
    final nr = row + dr, nc = col + dc;
    if (nr < 0 ||
        nr >= 16 ||
        nc < 0 ||
        nc >= 16 ||
        (cells[nr] as List)[nc] == CellType.wall.name ||
        occupied.contains((nr, nc))) {
      break;
    }
    row = nr;
    col = nc;
  }
  return (row, col);
}

Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic state = _state(t);
  state.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  state.setState(() => state.applyPuzzleSession(_copy(board)));
  await t.pump();
  await t.pump();
}

Future<void> _selectH(WidgetTester t) async {
  final finder = _atom(t, 'Hydrogen');
  await t.ensureVisible(finder);
  await t.pump();
  if (t.widget<Semantics>(finder).properties.selected != true) {
    await t.tap(finder);
    await t.pump();
  }
  expect(t.widget<Semantics>(finder).properties.selected, isTrue);
}

Future<void> _buttonMove(WidgetTester t, IconData icon) async {
  final button = find.widgetWithIcon(ElevatedButton, icon);
  await t.ensureVisible(button);
  await t.pump();
  expect(button.hitTestable(), findsOneWidget);
  await t.tap(button);
  await t.pump();
  await t.pump();
}

void _selectionBelongsToCurrentAtoms(WidgetTester t) {
  final dynamic state = _state(t);
  final Atom? selected = state.selectedAtom as Atom?;
  final atoms = state.atoms as List<Atom>;
  expect(
    selected == null || atoms.any((a) => identical(a, selected)),
    isTrue,
    reason:
        'A selected atom must be a current model instance, not merely share its ID.',
  );
}

void _renderedHMatchesRestoredModel(
  WidgetTester t,
  Map<String, dynamic> board,
) {
  final h = _model(board, 'H'), o = _model(board, 'O');
  final cell = t.getSize(_atom(t, 'Hydrogen')).width;
  // Both visuals have one whole-cell SizedBox. Oxygen is an independent,
  // stationary coordinate reference for the shared grid origin and cellsize.
  final expected =
      t.getCenter(_atom(t, 'Oxygen')) +
      Offset((h.col - o.col) * cell, (h.row - o.row) * cell);
  expect((t.getCenter(_atom(t, 'Hydrogen')) - expected).distance, lessThan(.1));
}

Finder _retry(WidgetTester t) =>
    find.widgetWithText(ElevatedButton, S.of(t.element(_screen))!.tryAgain);
Finder _next(WidgetTester t) => find.widgetWithText(
  ElevatedButton,
  S.of(t.element(_screen))!.moleculeBuilderNextMolecule,
);
Finder _bridge(WidgetTester t) =>
    find.widgetWithText(ElevatedButton, S.of(t.element(_screen))!.toTheBridge);
Future<void> _settleSlide(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 250));
  await t.pump();
}

Future<void> _result(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 1600));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

Future<void> _finish(
  WidgetTester t,
  Map<String, dynamic> real, {
  bool win = true,
}) async {
  await _restore(t, _fixture(real, winning: win, limit: 1));
  await _selectH(t);
  await _buttonMove(t, Icons.arrow_forward);
  await _settleSlide(t);
}

Future<void> _cover(WidgetTester t) async {
  Navigator.of(t.element(_screen)).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          const Scaffold(body: Center(child: Text('Covering route'))),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

void _noGameEffects(WidgetTester t) {
  final dynamic state = _state(t);
  expect(state.slidingAtom, isNull);
  expect(state.slideStartPos, isNull);
  expect(state.slideEndPos, isNull);
  expect(state.particles, isEmpty);
}

Future<void> _currentInput(WidgetTester t, Map<String, dynamic> real) async {
  final replacement = _fixture(real, replacement: true);
  await _restore(t, replacement);
  await _selectH(t);
  await _buttonMove(t, Icons.arrow_forward);
  await _settleSlide(t);
  expect((
    _model(_capture(t), 'H').row,
    _model(_capture(t), 'H').col,
  ), _endpoint(replacement, 'H', 0, 1));
  expect(_capture(t)['movesMade'], 1);
}

Future<void> _generatedInput(WidgetTester t) async {
  final before = _capture(t);
  final atoms = (before['atoms'] as List)
      .map((raw) => Atom.fromJson(Map<String, dynamic>.from(raw as Map)))
      .toList();
  for (var index = 0; index < atoms.length; index++) {
    final raw = (before['atoms'] as List)[index];
    final atom = Atom.fromJson(Map<String, dynamic>.from(raw as Map));
    for (final move in [
      (0, 1, Icons.arrow_forward),
      (0, -1, Icons.arrow_back),
      (1, 0, Icons.arrow_downward),
      (-1, 0, Icons.arrow_upward),
    ]) {
      final endpoint = _endpoint(before, atom.id, move.$1, move.$2);
      if (endpoint == (atom.row, atom.col)) continue;
      final finder = _atom(t, atom.type.name).at(
        atoms
            .take(index)
            .where((other) => other.type.name == atom.type.name)
            .length,
      );
      await t.ensureVisible(finder);
      await t.pump();
      await t.tap(finder);
      await t.pump();
      expect(t.widget<Semantics>(finder).properties.selected, isTrue);
      await _buttonMove(t, move.$3);
      await _settleSlide(t);
      expect(_state(t).movesMade, 1);
      return;
    }
  }
  fail('Real authored/generated board must permit an actual move');
}

Future<void> _saveSession(Map<String, dynamic> board) async {
  final pending = PuzzleSessionStore.instance.save(
    'quantum_molecule_builder',
    1,
    1,
    board,
  );
  await PuzzleSessionStore.instance.flush();
  await pending;
}

Future<void> _awaitResumePrompt(WidgetTester t) async {
  for (var i = 0; i < 30; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
    if (find
        .widgetWithText(ElevatedButton, S.of(t.element(_screen))!.resumePuzzle)
        .evaluate()
        .isNotEmpty) {
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      return;
    }
  }
  fail(
    'Public restorePuzzleSession must present the real saved-session prompt',
  );
}

Future<(_Harness, Map<String, dynamic>)> _mountPendingLoader(
  WidgetTester t,
  Completer<void> pending,
) async {
  final (_, real) = await _mount(t);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  await PuzzleSessionStore.instance.clear('quantum_molecule_builder');
  final app = _Harness(levelLoader: () => pending.future);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    app.motion.dispose();
  });
  await t.pumpWidget(app.build());
  await t.pump();
  expect(_state(t).capturePuzzleSession(), isNull);
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  return (app, real);
}

void main() {
  var id = 0;
  setUp(() {
    ProfilePreferences.activeId = 'molecule_round_${id++}';
    SharedPreferences.setMockInitialValues({});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets(
    'contract: real direction input stops before occupied oxygen and completed Undo costs two',
    (t) async {
      final (app, real) = await _mount(t);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      final moved = _capture(t), h = _model(moved, 'H');
      expect((h.row, h.col), _endpoint(board, 'H', 0, 1));
      expect(moved['movesMade'], 1);
      expect((moved['_moveHistory'] as List).length, 1);
      expect(app.gp.outcomeCount, 0);
      await t.tap(_undo());
      await t.pump();
      expect(
        (_model(_capture(t), 'H').row, _model(_capture(t), 'H').col),
        (3, 2),
      );
      expect(_capture(t)['movesMade'], 3);
      expect(_capture(t)['_moveHistory'], isEmpty);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect(
        (_model(_capture(t), 'H').row, _model(_capture(t), 'H').col),
        (3, 5),
      );
      expect(_capture(t)['movesMade'], 4);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: real held atom pan cannot act on a replacement round',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      final g = await t.startGesture(t.getCenter(_atom(t, 'Hydrogen')));
      await g.moveBy(const Offset(20, 0));
      await t.pump();
      final replacement = _fixture(real, replacement: true);
      await _restore(t, replacement);
      final before = _capture(t);
      await g.moveBy(const Offset(45, 0));
      await g.up();
      await t.pump(const Duration(milliseconds: 300));
      expect(_capture(t), before);
      _selectionBelongsToCurrentAtoms(t);
      expect(app.gp.outcomeCount, 0);
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(replacement, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
    },
  );
  testWidgets(
    'contract: restore cancels old slide visuals and leaves new atom input owned',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      await t.pump(const Duration(milliseconds: 70));
      final replacement = _fixture(real, replacement: true);
      await _restore(t, replacement);
      final before = _capture(t);
      _renderedHMatchesRestoredModel(t, before);
      _selectionBelongsToCurrentAtoms(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(_capture(t), before);
      _renderedHMatchesRestoredModel(t, before);
      _selectionBelongsToCurrentAtoms(t);
      expect(app.gp.outcomeCount, 0);
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(replacement, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
    },
  );
  testWidgets(
    'contract: in-flight Undo cannot be overwritten by a later unaccounted slide',
    (t) async {
      final (app, real) = await _mount(t);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 70));
      final beforeTap = _capture(t);
      final undo = t.widget<ElevatedButton>(_undo());
      if (undo.onPressed != null) {
        await t.tap(_undo());
        await t.pump();
      }
      final afterTap = _capture(t);
      final accepted =
          (beforeTap['_moveHistory'] as List).isNotEmpty &&
          (afterTap['_moveHistory'] as List).isEmpty;
      // The later repair may disable/defer Undo while busy or apply it safely.
      // This probe requires coherent settled behavior under either policy.
      await t.pump(const Duration(milliseconds: 300));
      final settled = _capture(t), h = _model(settled, 'H');
      expect((h.row, h.col), accepted ? (3, 2) : _endpoint(board, 'H', 0, 1));
      expect(settled['movesMade'], accepted ? 3 : 1);
      expect((settled['_moveHistory'] as List).length, accepted ? 0 : 1);
      expect(app.gp.outcomeCount, 0);
      await _selectH(t);
      final expected = _endpoint(settled, 'H', 0, accepted ? 1 : -1);
      await _buttonMove(t, accepted ? Icons.arrow_forward : Icons.arrow_back);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), expected);
      expect(_capture(t)['movesMade'], accepted ? 4 : 2);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: last legal slide wins once and delayed success cannot leak across restore',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real, winning: true, limit: 1));
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
      expect(app.gp.lastOutcome!.score, 300);
      expect(app.gp.lastOutcome!.movesUsed, 1);
      await _restore(t, _fixture(real, replacement: true));
      final before = _capture(t);
      await t.pump(const Duration(milliseconds: 1500));
      expect(find.byWidgetPredicate((w) => w is Dialog), findsNothing);
      expect(_capture(t), before);
      expect(app.gp.outcomeCount, 1);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'contract: actual same-round pan reaches occupied-cell endpoint',
    (t) async {
      final (app, real) = await _mount(t);
      final board = _fixture(real);
      await _restore(t, board);
      final g = await t.startGesture(t.getCenter(_atom(t, 'Hydrogen')));
      await g.moveBy(const Offset(20, 0));
      await t.pump();
      await g.moveBy(const Offset(65, 0));
      await g.up();
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(board, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: actual slide paints intermediate geometry before the endpoint',
    (t) async {
      final (_, real) = await _mount(t);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      final start = t.getCenter(_atom(t, 'Hydrogen'));
      final cell = t.getSize(_atom(t, 'Hydrogen')).width;
      final end =
          start + Offset((_endpoint(board, 'H', 0, 1).$2 - 2) * cell, 0);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 70));
      final mid = t.getCenter(_atom(t, 'Hydrogen'));
      expect(mid.dx, greaterThan(start.dx + 1));
      expect(mid.dx, lessThan(end.dx - 1));
      expect(mid.dy, closeTo(start.dy, .1));
      await t.pump(const Duration(milliseconds: 250));
      await t.pump();
      expect((t.getCenter(_atom(t, 'Hydrogen')) - end).distance, lessThan(.1));
    },
  );
  testWidgets(
    'contract: in-flight capture restores a coherent move with completed Undo penalty',
    (t) async {
      final (app, real) = await _mount(t);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 70));
      final saved = _capture(t), h = _model(saved, 'H');
      final moved = (h.row, h.col) == _endpoint(board, 'H', 0, 1);
      // Both atomic commit and deferred commit policies are permitted. A save
      // must never combine the old position with a charged move/history entry.
      expect((h.row, h.col), moved ? _endpoint(board, 'H', 0, 1) : (3, 2));
      expect(saved['movesMade'], moved ? 1 : 0);
      expect((saved['_moveHistory'] as List).length, moved ? 1 : 0);
      await _restore(t, saved);
      await t.pump(const Duration(milliseconds: 300));
      expect(_capture(t), saved);
      _renderedHMatchesRestoredModel(t, saved);
      if (!moved) {
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
      }
      await t.tap(_undo());
      await t.pump();
      expect(
        (_model(_capture(t), 'H').row, _model(_capture(t), 'H').col),
        (3, 2),
      );
      expect(_capture(t)['movesMade'], 3);
      expect(_capture(t)['_moveHistory'], isEmpty);
      await t.pump(const Duration(milliseconds: 800));
      await PuzzleSessionStore.instance.flush();
      expect(
        await PuzzleSessionStore.instance.load(
          'quantum_molecule_builder',
          1,
          1,
        ),
        _capture(t),
      );
      expect(app.gp.outcomeCount, 0);
    },
  );
  for (final held in ['direction', 'undo', 'atom']) {
    testWidgets(
      'contract: held $held pointer cannot transfer across same-ID restore',
      (t) async {
        final (app, real) = await _mount(t);
        await _restore(t, _fixture(real));
        await _selectH(t);
        if (held == 'undo') {
          await _buttonMove(t, Icons.arrow_forward);
          await _settleSlide(t);
        }
        final finder = held == 'direction'
            ? find.widgetWithIcon(ElevatedButton, Icons.arrow_forward)
            : held == 'undo'
            ? _undo()
            : _atom(t, 'Hydrogen');
        await t.ensureVisible(finder);
        await t.pump();
        final press = await t.startGesture(t.getCenter(finder));
        await t.pump(const Duration(milliseconds: 40));
        await _restore(t, _fixture(real, replacement: true));
        final before = _capture(t);
        await press.up();
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(_capture(t), before);
        _selectionBelongsToCurrentAtoms(t);
        expect(_state(t).selectedAtom, isNull);
        expect(app.gp.outcomeCount, 0);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
        expect(_capture(t)['movesMade'], 1);
      },
    );
  }
  testWidgets(
    'contract: retained arrow and Undo callbacks reject a restored round',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await _settleSlide(t);
      final arrow = t
          .widget<ElevatedButton>(
            find.widgetWithIcon(ElevatedButton, Icons.arrow_back),
          )
          .onPressed!;
      final undo = t.widget<ElevatedButton>(_undo()).onPressed!;
      await _restore(t, _fixture(real, replacement: true));
      final before = _capture(t);
      arrow();
      undo();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(_capture(t), before);
      expect(app.gp.outcomeCount, 0);
      await _currentInput(t, real);
    },
  );
  testWidgets(
    'contract: different-ID replacement rejects an old held pan and accepts current keyboard input',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      final g = await t.startGesture(t.getCenter(_atom(t, 'Hydrogen')));
      await g.moveBy(const Offset(20, 0));
      await t.pump();
      final board = _fixture(real, replacement: true);
      for (final atom in board['atoms'] as List) {
        atom['id'] = 'new-${atom['id']}';
      }
      await _restore(t, board);
      final before = _capture(t);
      await g.moveBy(const Offset(60, 0));
      await g.up();
      await _settleSlide(t);
      expect(_capture(t), before);
      _selectionBelongsToCurrentAtoms(t);
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'new-H').row,
        _model(_capture(t), 'new-H').col,
      ), _endpoint(board, 'new-H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  for (final win in [true, false]) {
    testWidgets(
      'contract: last legal ${win ? 'winning' : 'incorrect'} move reports exactly once and terminal capture is null',
      (t) async {
        final (app, real) = await _mount(t);
        await _restore(t, _fixture(real, winning: win, limit: 1));
        await _selectH(t);
        final arrow = t
            .widget<ElevatedButton>(
              find.widgetWithIcon(ElevatedButton, Icons.arrow_forward),
            )
            .onPressed!;
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
        expect(app.gp.outcomeCount, 1);
        expect(app.gp.lastOutcome!.wasSuccessful, win);
        if (win) {
          expect(app.gp.lastOutcome!.score, 300);
          expect(app.gp.lastOutcome!.movesUsed, 1);
        }
        final outcome = app.gp.lastOutcome;
        arrow();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await _result(t);
        expect(app.gp.outcomeCount, 1);
        expect(identical(outcome, app.gp.lastOutcome), isTrue);
        expect(_state(t).capturePuzzleSession(), isNull);
        expect(roundDialogs, findsOneWidget);
      },
    );
    testWidgets(
      'contract: obsolete delayed ${win ? 'success' : 'loss'} cannot open after restore',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        expect(app.gp.outcomeCount, 1);
        await _restore(t, _fixture(real, replacement: true));
        final before = _capture(t);
        await _result(t);
        expect(roundDialogs, findsNothing);
        expect(_capture(t), before);
        expect(app.gp.outcomeCount, 1);
        await _currentInput(t, real);
      },
    );
    testWidgets(
      'contract: delayed ${win ? 'success' : 'loss'} and particles are harmless after disposal',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        await t.pumpWidget(const SizedBox.shrink());
        await _result(t);
        expect(_screen, findsNothing);
        expect(roundDialogs, findsNothing);
        expect(t.takeException(), isNull);
        expect(app.gp.outcomeCount, 1);
      },
    );
    testWidgets(
      'contract: ${win ? 'solved' : 'exhausted'} restore is silent terminal with actual playable retry',
      (t) async {
        final (app, real) = await _mount(t);
        final board = _fixture(real, winning: win, limit: 1);
        board['movesMade'] = 1;
        if (win) {
          (board['atoms'] as List).first['col'] = 5;
        }
        await _restore(t, board);
        await _result(t);
        expect(_state(t).gameActive, isFalse);
        expect(_state(t).hasWon, win);
        expect(_state(t).hasLost, !win);
        expect(_state(t).capturePuzzleSession(), isNull);
        expect(app.gp.outcomeCount, 0);
        expect(find.byType(RoundSummary), findsNothing);
        await t.ensureVisible(_retry(t));
        await t.pump();
        expect(_retry(t).hitTestable(), findsOneWidget);
        await t.tap(_retry(t));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        expect(_state(t).capturePuzzleSession(), isNotNull);
        await _generatedInput(t);
        expect(app.gp.outcomeCount, 0);
      },
    );
    testWidgets(
      'contract: actual ${win ? 'next molecule' : 'loss retry'} starts a new playable authored round',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        await _result(t);
        final action = win ? _next(t) : _retry(t);
        await t.ensureVisible(action);
        await t.pump();
        expect(action.hitTestable(), findsOneWidget);
        await t.tap(action);
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        expect(roundDialogs, findsNothing);
        expect(_state(t).capturePuzzleSession(), isNotNull);
        expect(_capture(t)['_currentLevel'], win ? 2 : 1);
        await _generatedInput(t);
        expect(app.gp.outcomeCount, 1);
      },
    );
    testWidgets(
      'contract: covered ${win ? 'success' : 'loss'} rejects retained action and back callbacks; restore preserves cover',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        await _result(t);
        final action = t
            .widget<ElevatedButton>(win ? _next(t) : _retry(t))
            .onPressed!;
        final back = t.widget<ElevatedButton>(_bridge(t)).onPressed!;
        await _cover(t);
        final covering = ModalRoute.of(t.element(find.text('Covering route')))!;
        action();
        back();
        await t.pump();
        expect(covering.isCurrent, isTrue);
        expect(find.text('Covering route'), findsOneWidget);
        await _restore(t, _fixture(real, replacement: true));
        expect(covering.isCurrent, isTrue);
        Navigator.of(t.element(find.text('Covering route'))).pop();
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        for (
          var frame = 0;
          frame < 4 &&
              find
                  .text('Covering route', skipOffstage: false)
                  .evaluate()
                  .isNotEmpty;
          frame++
        ) {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump();
        }
        expect(find.text('Covering route', skipOffstage: false), findsNothing);
        expect(roundDialogs, findsNothing);
        final before = _capture(t);
        action();
        back();
        await t.pump();
        expect(_capture(t), before);
        expect(_screen, findsOneWidget);
        expect(app.gp.outcomeCount, 1);
        await _currentInput(t, real);
      },
    );
    testWidgets(
      'contract: ${win ? 'success' : 'loss'} dialog invalidation before its first builder keeps replacement playable',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        var invoked = false;
        app.observer.onDialogPush = () {
          invoked = true;
          app.observer.onDialogPush = null;
          final dynamic state = _state(t);
          state.beginPuzzleSession();
          // ignore: invalid_use_of_protected_member
          state.setState(
            () => state.applyPuzzleSession(_fixture(real, replacement: true)),
          );
        };
        await _result(t);
        expect(invoked, isTrue);
        expect(roundDialogs, findsNothing);
        expect(_capture(t)['movesMade'], 0);
        expect(app.gp.outcomeCount, 1);
        expect(t.takeException(), isNull);
        await _currentInput(t, real);
      },
    );
  }
  testWidgets(
    'contract: Undo penalty can exhaust the round once without changing its two-move cost',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real, limit: 3));
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await _settleSlide(t);
      await t.tap(_undo());
      await t.pump();
      await _result(t);
      expect(_state(t).movesMade, 3);
      expect(_state(t).hasLost, isTrue);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
      expect(_state(t).capturePuzzleSession(), isNull);
    },
  );
  for (final initial in [true, false]) {
    testWidgets(
      'contract: ${initial ? 'initial' : 'mid-slide'} reduced motion completes meaningful movement and clears effects',
      (t) async {
        final (app, real) = await _mount(t, reduced: initial);
        final board = _fixture(real);
        await _restore(t, board);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        if (!initial) {
          await t.pump(const Duration(milliseconds: 70));
          expect(_state(t).slidingAtom, isNotNull);
          app.motion.value = true;
          await t.pump();
          await t.pump();
        }
        expect((
          _model(_capture(t), 'H').row,
          _model(_capture(t), 'H').col,
        ), _endpoint(board, 'H', 0, 1));
        _noGameEffects(t);
        _renderedHMatchesRestoredModel(t, _capture(t));
        await t.pump();
        await t.tap(_undo());
        await t.pump();
        expect(_capture(t)['movesMade'], 3);
        expect(app.gp.outcomeCount, 0);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        expect(_capture(t)['movesMade'], 4);
        _noGameEffects(t);
      },
    );
  }
  for (final win in [true, false]) {
    testWidgets(
      'contract: mid-${win ? 'success' : 'failure'} reduced motion clears particles and leaves owned result usable',
      (t) async {
        final (app, real) = await _mount(t);
        await _finish(t, real, win: win);
        expect(_state(t).particles, isNotEmpty);
        app.motion.value = true;
        await t.pump();
        await t.pump();
        _noGameEffects(t);
        await _result(t);
        expect(roundDialogs, findsOneWidget);
        _noGameEffects(t);
        expect(app.gp.outcomeCount, 1);
        final scale = find.byWidgetPredicate(
          (w) => w is Transform && w.child is ScrollableRoundDialog,
        );
        if (win) {
          expect(scale, findsOneWidget);
          expect(
            t.widget<Transform>(scale).transform.storage[0],
            closeTo(1, .000001),
          );
        }
        final action = win ? _next(t) : _retry(t);
        await t.ensureVisible(action);
        await t.pump();
        expect(action.hitTestable(), findsOneWidget);
        await t.tap(action);
        await t.pump();
        await _generatedInput(t);
        expect(app.gp.outcomeCount, 1);
        _noGameEffects(t);
      },
    );
  }
  testWidgets(
    'contract: disposing a sliding game cannot complete or report a later outcome',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real, winning: true, limit: 1));
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 70));
      await t.pumpWidget(const SizedBox.shrink());
      await _result(t);
      expect(t.takeException(), isNull);
      expect(roundDialogs, findsNothing);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: removing the game beneath its result removes only the owned result',
    (t) async {
      final (app, real) = await _mount(t, pushed: true);
      final navigator = Navigator.of(t.element(_screen));
      final gameRoute = ModalRoute.of(t.element(_screen))!;
      await _finish(t, real);
      await _result(t);
      await _cover(t);
      final cover = ModalRoute.of(t.element(find.text('Covering route')))!;
      navigator.removeRoute(gameRoute);
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(_screen, findsNothing);
      expect(cover.isCurrent, isTrue);
      navigator.pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text('Start molecule'), findsOneWidget);
      expect(roundDialogs, findsNothing);
      expect(app.gp.outcomeCount, 1);
      expect(t.takeException(), isNull);
    },
  );
  for (final locale in ['en', 'de']) {
    for (final height in [844.0, 500.0]) {
      testWidgets(
        'contract: $locale 390x$height text2 keeps actual board input Undo and result controls reachable',
        (t) async {
          final (app, real) = await _mount(
            t,
            locale: Locale(locale),
            scale: 2,
            size: Size(390, height),
            reduced: true,
          );
          await _restore(t, _fixture(real));
          await t.ensureVisible(_atom(t, 'Hydrogen'));
          await t.pump();
          expect(_atom(t, 'Hydrogen').hitTestable(), findsOneWidget);
          await _selectH(t);
          await _buttonMove(t, Icons.arrow_forward);
          expect(_capture(t)['movesMade'], 1);
          await t.ensureVisible(_undo());
          await t.pump();
          expect(_undo().hitTestable(), findsOneWidget);
          await t.tap(_undo());
          await t.pump();
          expect(_capture(t)['movesMade'], 3);
          expect(t.takeException(), isNull);
          await _finish(t, real, win: false);
          await _result(t);
          await t.ensureVisible(_retry(t));
          await t.pump();
          expect(_retry(t).hitTestable(), findsOneWidget);
          await t.tap(_retry(t));
          await t.pump();
          await _generatedInput(t);
          expect(app.gp.outcomeCount, 1);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'contract: win retains efficiency bonus and half-limit quality reference',
    (t) async {
      final (app, real) = await _mount(t, reduced: true);
      await _restore(t, _fixture(real, winning: true, limit: 12));
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.score, 410);
      expect(app.gp.lastOutcome!.movesUsed, 1);
      expect(app.gp.lastOutcome!.optimalMoves, 6);
      expect(_state(t).capturePuzzleSession(), isNull);
      await _result(t);
    },
  );
  for (final win in [true, false]) {
    testWidgets(
      'contract: initial reduced motion leaves ${win ? 'win' : 'loss'} effects stopped and result actionable',
      (t) async {
        final (app, real) = await _mount(t, reduced: true);
        await _finish(t, real, win: win);
        _noGameEffects(t);
        await _result(t);
        expect(roundDialogs, findsOneWidget);
        _noGameEffects(t);
        expect(app.gp.outcomeCount, 1);
        final action = win ? _next(t) : _retry(t);
        await t.ensureVisible(action);
        await t.pump();
        expect(action.hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets(
    'contract: snapshot during last legal winning slide preserves an unreported playable outcome',
    (t) async {
      final (app, real) = await _mount(t);
      final board = _fixture(real, winning: true, limit: 1);
      await _restore(t, board);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await t.pump(const Duration(milliseconds: 70));
      expect(app.gp.outcomeCount, 0);
      expect(_state(t).capturePuzzleSession(), isNotNull);
      final snapshot = _capture(t), h = _model(snapshot, 'H');
      final preMove = (h.row, h.col) == (3, 2);
      if (preMove) {
        expect(snapshot['movesMade'], 0);
        expect(snapshot['_moveHistory'], isEmpty);
      } else {
        expect((h.row, h.col), _endpoint(board, 'H', 0, 1));
        expect(snapshot['movesMade'], 1);
        expect((snapshot['_moveHistory'] as List).length, 1);
      }
      await _restore(t, snapshot);
      await t.pump(const Duration(milliseconds: 300));
      if (preMove) {
        expect(app.gp.outcomeCount, 0);
        expect(_state(t).gameActive, isTrue);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
      }
      // A deferred pre-move save must remain playable. An endpoint save must
      // explicitly retain its pending result; silently terminalizing loses it.
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
      expect(app.gp.lastOutcome!.score, 300);
      expect(app.gp.lastOutcome!.movesUsed, 1);
      await _result(t);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'contract: silent solved restore keeps previous learning outcome and suppresses its stale summary',
    (t) async {
      final (app, real) = await _mount(t);
      await _finish(t, real, win: false);
      final previous = app.gp.lastOutcome;
      final solved = _fixture(real, winning: true, limit: 12);
      (solved['atoms'] as List).first['col'] = 5;
      solved['movesMade'] = 1;
      await _restore(t, solved);
      await _result(t);
      expect(app.gp.outcomeCount, 1);
      expect(identical(app.gp.lastOutcome, previous), isTrue);
      expect(find.byType(RoundSummary), findsNothing);
      expect(roundDialogs, findsNothing);
      expect(_state(t).capturePuzzleSession(), isNull);
      await t.ensureVisible(_retry(t));
      await t.pump();
      expect(_retry(t).hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'contract: current saved-session Resume restores the saved board and accepts actual input',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real, replacement: true));
      final old = _fixture(real);
      old['movesMade'] = 2;
      await _saveSession(old);
      final pending = _state(t).restorePuzzleSession() as Future<bool>;
      unawaited(pending);
      await _awaitResumePrompt(t);
      final resume = find.widgetWithText(
        ElevatedButton,
        S.of(t.element(_screen))!.resumePuzzle,
      );
      expect(resume.hitTestable(), findsOneWidget);
      await t.tap(resume);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(await pending, isTrue);
      expect(_capture(t), old);
      await _selectH(t);
      await _buttonMove(t, Icons.arrow_forward);
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(old, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 3);
      expect(app.gp.outcomeCount, 0);
    },
  );
  for (final accept in [true, false]) {
    testWidgets(
      'contract: obsolete saved-session ${accept ? 'Resume' : 'Start new'} cannot overwrite or clear a newer round',
      (t) async {
        final (app, real) = await _mount(t);
        await _restore(t, _fixture(real));
        final old = _fixture(real);
        old['movesMade'] = 2;
        await _saveSession(old);
        final pending = _state(t).restorePuzzleSession() as Future<bool>;
        unawaited(pending);
        await _awaitResumePrompt(t);
        final replacement = _fixture(real, replacement: true);
        await _restore(t, replacement);
        await _saveSession(replacement);
        final text = accept
            ? S.of(t.element(_screen))!.resumePuzzle
            : S.of(t.element(_screen))!.startNewPuzzle;
        final action = accept
            ? find.widgetWithText(ElevatedButton, text)
            : find.widgetWithText(TextButton, text);
        expect(action.hitTestable(), findsOneWidget);
        await t.tap(action);
        await t.pump();
        await pending;
        // Inspect storage before advancing the750ms autosave timer: a stale
        // decline must not clear a new save and be hidden by a later rewrite.
        expect(_capture(t), replacement);
        expect(
          await PuzzleSessionStore.instance.load(
            'quantum_molecule_builder',
            1,
            1,
          ),
          replacement,
        );
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        expect(roundDialogs, findsNothing);
        expect(app.gp.outcomeCount, 0);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
        expect((
          _model(_capture(t), 'H').row,
          _model(_capture(t), 'H').col,
        ), _endpoint(replacement, 'H', 0, 1));
        expect(_capture(t)['movesMade'], 1);
        expect(app.gp.outcomeCount, 0);
      },
    );
  }

  for (final fail in [false, true]) {
    testWidgets(
      'seam: obsolete initial loader ${fail ? 'failure' : 'success'} cannot replace a restored round',
      (t) async {
        final pending = Completer<void>();
        final (app, real) = await _mountPendingLoader(t, pending);
        final replacement = _fixture(real, replacement: true);
        await _restore(t, replacement);
        final before = _capture(t);
        if (fail) {
          pending.completeError(
            StateError('obsolete controlled loader failure'),
          );
        } else {
          pending.complete();
        }
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        expect(_capture(t), before);
        expect(roundDialogs, findsNothing);
        expect(t.takeException(), isNull);
        await _selectH(t);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settleSlide(t);
        expect((
          _model(_capture(t), 'H').row,
          _model(_capture(t), 'H').col,
        ), _endpoint(replacement, 'H', 0, 1));
        expect(_capture(t)['movesMade'], 1);
        expect(app.gp.outcomeCount, 0);
      },
    );
    testWidgets(
      'seam: initial loader ${fail ? 'failure' : 'success'} after disposal is harmless',
      (t) async {
        final pending = Completer<void>();
        final (app, _) = await _mountPendingLoader(t, pending);
        await t.pumpWidget(const SizedBox.shrink());
        if (fail) {
          pending.completeError(
            StateError('disposed controlled loader failure'),
          );
        } else {
          pending.complete();
        }
        await t.pump();
        await t.pump(const Duration(milliseconds: 1500));
        expect(_screen, findsNothing);
        expect(roundDialogs, findsNothing);
        expect(t.takeException(), isNull);
        expect(app.gp.outcomeCount, 0);
      },
    );
  }
  testWidgets(
    'seam: current controlled initial loader failure retains playable cached authored levels',
    (t) async {
      final pending = Completer<void>();
      final (app, _) = await _mountPendingLoader(t, pending);
      // The bundled30levels were loaded by the independent positive mount. This
      // tests the owned loading failure boundary, not a corrupt asset/parser.
      pending.completeError(StateError('current controlled loader failure'));
      for (var i = 0; i < 30; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
        if (_state(t).capturePuzzleSession() != null) break;
      }
      expect(t.takeException(), isNull);
      expect(_state(t).capturePuzzleSession(), isNotNull);
      expect(levelsData.length, 30);
      expect(roundDialogs, findsNothing);
      await _generatedInput(t);
      expect(app.gp.outcomeCount, 0);
    },
  );

  for (final locale in ['en', 'de']) {
    testWidgets(
      'contract: $locale short phone text2 exposes reachable help and molecule-info close controls',
      (t) async {
        final (app, real) = await _mount(
          t,
          locale: Locale(locale),
          scale: 2,
          size: const Size(390, 500),
          reduced: true,
        );
        final board = _fixture(real);
        await _restore(t, board);
        final before = _capture(t);
        final strings = S.of(t.element(_screen))!;
        final help = find.byTooltip(strings.moleculeBuilderHelp);
        await t.ensureVisible(help);
        await t.pump();
        expect(help.hitTestable(), findsOneWidget);
        await t.tap(help);
        await t.pump();
        expect(find.text(strings.moleculeBuilderInfoTitle), findsOneWidget);
        expect(t.takeException(), isNull);
        final close = find.widgetWithIcon(IconButton, Icons.close);
        await t.ensureVisible(close);
        await t.pump();
        expect(close.hitTestable(), findsOneWidget);
        await t.tap(close);
        await t.pump();
        expect(find.text(strings.moleculeBuilderInfoTitle), findsNothing);
        expect(_capture(t), before);
        // The actual preview uses the captured localized level display name,
        // which is independent of our synthetic targetPattern name.
        final target = find.text(board['levelDisplayName'] as String);
        expect(target, findsOneWidget);
        await t.ensureVisible(target);
        await t.pump();
        expect(target.hitTestable(), findsOneWidget);
        await t.tap(target);
        await t.pump();
        expect(find.text(strings.moleculeBuilderMoleculeInfo), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.ensureVisible(close);
        await t.pump();
        expect(close.hitTestable(), findsOneWidget);
        await t.tap(close);
        await t.pump();
        expect(find.text(strings.moleculeBuilderMoleculeInfo), findsNothing);
        expect(close, findsNothing);
        expect(_capture(t), before);
        await _selectH(t);
        await _buttonMove(t, Icons.arrow_forward);
        await _settleSlide(t);
        expect((
          _model(_capture(t), 'H').row,
          _model(_capture(t), 'H').col,
        ), _endpoint(board, 'H', 0, 1));
        expect(_capture(t)['movesMade'], 1);
        expect(app.gp.outcomeCount, 0);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'contract: Help blocks actual arrow keys until its overlay closes',
    (t) async {
      final (app, real) = await _mount(t, reduced: true);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      final before = _capture(t);
      final strings = S.of(t.element(_screen))!;
      final help = find.byTooltip(strings.moleculeBuilderHelp);
      await t.ensureVisible(help);
      await t.pump();
      expect(help.hitTestable(), findsOneWidget);
      await t.tap(help);
      await t.pump();
      expect(find.text(strings.moleculeBuilderInfoTitle), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect(
        _capture(t),
        before,
        reason: 'Reading Help must not charge an unseen move to selected H.',
      );
      expect(app.gp.outcomeCount, 0);
      final close = find.widgetWithIcon(IconButton, Icons.close);
      await t.ensureVisible(close);
      await t.pump();
      expect(close.hitTestable(), findsOneWidget);
      await t.tap(close);
      await t.pump();
      expect(find.text(strings.moleculeBuilderInfoTitle), findsNothing);
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(board, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'contract: molecule-info blocks actual arrow keys until its overlay closes',
    (t) async {
      final (app, real) = await _mount(t, reduced: true);
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      final before = _capture(t);
      final strings = S.of(t.element(_screen))!;
      final target = find.text(board['levelDisplayName'] as String);
      expect(target, findsOneWidget);
      await t.ensureVisible(target);
      await t.pump();
      expect(target.hitTestable(), findsOneWidget);
      await t.tap(target);
      await t.pump();
      expect(find.text(strings.moleculeBuilderMoleculeInfo), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect(
        _capture(t),
        before,
        reason: 'Reading molecule information must not move selected H.',
      );
      expect(app.gp.outcomeCount, 0);
      final close = find.widgetWithIcon(IconButton, Icons.close);
      await t.ensureVisible(close);
      await t.pump();
      expect(close.hitTestable(), findsOneWidget);
      await t.tap(close);
      await t.pump();
      expect(find.text(strings.moleculeBuilderMoleculeInfo), findsNothing);
      await _selectH(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(board, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 0);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'contract: German restored Hydrogen keeps its localized selected label',
    (t) async {
      final (app, real) = await _mount(
        t,
        locale: const Locale('de'),
        reduced: true,
      );
      final board = _fixture(real);
      await _restore(t, board);
      await _selectH(t);
      final strings = S.of(t.element(_screen))!;
      expect(
        find.text(
          '${strings.moleculeBuilderSelected}: ${strings.atomNameHydrogen}',
        ),
        findsOneWidget,
        reason: 'A deserialized known atom must retain its German name.',
      );
      expect(_capture(t), board);
      expect(app.gp.outcomeCount, 0);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settleSlide(t);
      expect((
        _model(_capture(t), 'H').row,
        _model(_capture(t), 'H').col,
      ), _endpoint(board, 'H', 0, 1));
      expect(_capture(t)['movesMade'], 1);
      expect(app.gp.outcomeCount, 0);
      expect(t.takeException(), isNull);
    },
  );
}
