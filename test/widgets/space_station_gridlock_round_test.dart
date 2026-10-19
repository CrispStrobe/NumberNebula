import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/features/games/data/gridlock_puzzles_data.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/space_station_gridlock_game.dart';
import 'package:space_math_academy/features/games/services/gridlock_puzzle_tracker.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';

class GridlockTestApp {
  final Locale locale;
  final double scale;
  final ValueNotifier<bool> motion;
  Widget game = const SpaceStationGridlockGame(grade: 1, level: 1);
  GridlockTestApp({
    this.locale = const Locale('en'),
    this.scale = 1,
    bool reduced = false,
  }) : motion = ValueNotifier(reduced);
  final sri = SriService(), cognitive = CognitiveProfileService();
  final debug = DebugProvider(), tracker = GridlockPuzzleTracker();
  late final gp = GameProvider(
    progressService: ProgressService(),
    sriService: sri,
    cognitiveProfileService: cognitive,
  );
  Widget build() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: gp),
      ChangeNotifierProvider.value(value: sri),
      ChangeNotifierProvider.value(value: cognitive),
      ChangeNotifierProvider.value(value: debug),
      ChangeNotifierProvider.value(value: tracker),
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
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
      ),
      home: game,
    ),
  );
}

final _screen = find.byType(SpaceStationGridlockGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> _capture(WidgetTester t) =>
    _copy(_state(t).capturePuzzleSession() as Map<String, dynamic>);
List<Map<String, dynamic>> _ships(Map<String, dynamic> board) =>
    (board['ships'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
Finder _dialogs() => find.byElementPredicate((element) {
  if (element.widget is! Dialog) return false;
  var nested = false;
  element.visitAncestorElements((e) {
    if (e.widget is Dialog) {
      nested = true;
      return false;
    }
    return true;
  });
  return !nested;
});
Future<(GridlockTestApp, Map<String, dynamic>)> _mount(
  WidgetTester t, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(1600, 1100),
  bool reduced = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.runAsync(GridlockPuzzleDatabase.load);
  final app = GridlockTestApp(locale: locale, scale: scale, reduced: reduced);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    app.motion.dispose();
  });
  await t.pumpWidget(app.build());
  await _waitPlayable(t);
  return (app, _capture(t));
}

Map<String, dynamic> _fixture(
  Map<String, dynamic> real, {
  bool fLeft = false,
  bool fRight = false,
  bool beforeExit = false,
}) {
  final board = _copy(real);
  const raw = 'IBBKooIoJKCCAAJoLMoxEELMoooFFooGGHHo';
  final configs = shipsFromBoard(raw);
  const colors = [
    SpaceTheme.cosmicPink,
    SpaceTheme.starYellow,
    SpaceTheme.planetOrange,
    SpaceTheme.nebulaPurple,
    Colors.cyan,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.lime,
    Colors.deepOrange,
    Colors.purple,
    Colors.pink,
  ];
  final models = <Map<String, dynamic>>[
    for (var i = 0; i < configs.length; i++)
      SpaceShip(
        row: configs[i]['row'] as int,
        col: configs[i]['col'] as int,
        length: configs[i]['length'] as int,
        isHorizontal: configs[i]['isHorizontal'] as bool,
        isPlayer: configs[i]['isPlayer'] as bool,
        isBlocking: configs[i]['isBlocking'] as bool,
        color: configs[i]['isPlayer'] == true
            ? SpaceTheme.alienGreen
            : configs[i]['isBlocking'] == true
            ? Colors.grey.shade800
            : colors[i % colors.length],
      ).toJson(),
  ];
  board.addAll({
    'ships': models,
    'playerShipIndex': 0,
    'exitRow': 2,
    'minMoves': 8,
    'moveCount': 0,
    '_currentPuzzleId': 'GRID_1',
    '_currentComplexity': 1.0,
  });
  _validate(board);
  if (fLeft) _legalStep(board, 4, -1);
  if (fRight) _legalStep(board, 4, 1);
  if (beforeExit) {
    // Exact authored list indices: A0 B1 C2 E3 F4 G5 H6 I7 J8 K9 L10 M11 wall12.
    for (final move in [
      (4, -1, 3),
      (5, -1, 1),
      (6, -1, 1),
      (10, 1, 2),
      (11, 1, 2),
      (3, 1, 2),
      (9, 1, 3),
      (1, 1, 3),
      (8, -1, 1),
      (0, 1, 3),
    ]) {
      for (var i = 0; i < move.$3; i++) {
        _legalStep(board, move.$1, move.$2);
      }
    }
    expect(board['moveCount'], 21);
    expect(_ships(board)[0]['col'], 3);
  }
  return board;
}

Set<(int, int)> _cells(Map<String, dynamic> ship) => {
  for (var k = 0; k < (ship['length'] as int); k++)
    (
      (ship['row'] as int) + (ship['isHorizontal'] == true ? 0 : k),
      (ship['col'] as int) + (ship['isHorizontal'] == true ? k : 0),
    ),
};
void _validate(Map<String, dynamic> board) {
  final occupied = <(int, int)>{};
  final ships = _ships(board);
  expect(ships.length, 13);
  expect(ships.where((s) => s['isPlayer'] == true).length, 1);
  for (final ship in ships) {
    for (final cell in _cells(ship)) {
      expect(cell.$1, inInclusiveRange(0, 5));
      expect(cell.$2, inInclusiveRange(0, 5));
      expect(
        occupied.add(cell),
        isTrue,
        reason: 'Legal authored-derived fixture may not overlap',
      );
    }
  }
}

void _legalStep(Map<String, dynamic> board, int index, int direction) {
  final ships = _ships(board), ship = ships[index];
  expect(ship['isBlocking'], isFalse);
  final shifted = Map<String, dynamic>.from(ship);
  final key = ship['isHorizontal'] == true ? 'col' : 'row';
  shifted[key] = (ship[key] as int) + direction;
  final occupied = <(int, int)>{};
  for (var i = 0; i < ships.length; i++) {
    if (i != index) occupied.addAll(_cells(ships[i]));
  }
  for (final cell in _cells(shifted)) {
    expect(cell.$1, inInclusiveRange(0, 5));
    expect(cell.$2, inInclusiveRange(0, 5));
    expect(occupied.contains(cell), isFalse);
  }
  ships[index] = shifted;
  board['ships'] = ships;
  board['moveCount'] = (board['moveCount'] as int) + 1;
  _validate(board);
}

int _kind(Map<String, dynamic> ship) => ship['isPlayer'] == true
    ? 0
    : ship['isBlocking'] == true
    ? 1
    : 2;
Finder _ship(WidgetTester t, int index) => _shipFor(t, _capture(t), index);
Finder _shipFor(WidgetTester t, Map<String, dynamic> board, int index) {
  final ships = _ships(board),
      kind = _kind(ships[index]),
      s = S.of(t.element(_screen))!;
  final label = kind == 0
      ? s.gridlockPlayerShip
      : kind == 1
      ? s.gridlockBlockingShip
      : s.gridlockShip;
  final rank = ships.take(index).where((ship) => _kind(ship) == kind).length;
  return find
      .byWidgetPredicate((w) => w is Semantics && w.properties.label == label)
      .at(rank);
}

Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic state = _state(t);
  state.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  state.setState(() => state.applyPuzzleSession(_copy(board)));
  await t.pump();
  await t.pump();
}

Future<TestGesture> _startRight(WidgetTester t, int index) async {
  final finder = _ship(t, index);
  await t.ensureVisible(finder);
  await t.pump();
  expect(finder.hitTestable(), findsOneWidget);
  final gesture = await t.startGesture(t.getCenter(finder));
  await gesture.moveBy(const Offset(22, 0));
  await t.pump();
  return gesture;
}

Future<void> _oneLeftF(WidgetTester t) async {
  final finder = _ship(t, 4);
  await t.ensureVisible(finder);
  await t.pump();
  expect(finder.hitTestable(), findsOneWidget);
  final gesture = await t.startGesture(t.getCenter(finder));
  await gesture.moveBy(const Offset(-22, 0));
  await t.pump();
  await gesture.up();
  await t.pump();
}

Future<void> _win(WidgetTester t, Map<String, dynamic> real) async {
  await _restore(t, _fixture(real, beforeExit: true));
  final gesture = await _startRight(t, 0);
  await gesture.moveBy(const Offset(35, 0));
  await t.pump();
  await gesture.up();
  await t.pump();
}

Future<void> _result(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 1600));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
}

Future<void> _waitPlayable(WidgetTester t) async {
  // Advance only the actual100/200ms loading stages, with a bounded wait.
  for (var i = 0; i < 25; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
    if (_state(t).capturePuzzleSession() != null) return;
  }
  fail(
    'Current authored load must expose a playable snapshot within bounded stages',
  );
}

Finder _next(WidgetTester t) =>
    find.widgetWithText(ElevatedButton, S.of(t.element(_screen))!.nextPuzzle);
Finder _bridge(WidgetTester t) =>
    find.widgetWithText(ElevatedButton, S.of(t.element(_screen))!.toTheBridge);
Finder _exitTransform(WidgetTester t, Map<String, dynamic> board) => find
    .descendant(of: _shipFor(t, board, 0), matching: find.byType(Transform));
double _cellFromStationaryReferences(
  WidgetTester t,
  Map<String, dynamic> board,
) {
  // In the legal pre-exit witness B(row0,col4) and C(row1,col4) are
  // stationary horizontal length2 ships. Their center separation is one cell,
  // independent of ship padding, player exit motion, or private layout fields.
  final b = t.getCenter(_shipFor(t, board, 1)),
      c = t.getCenter(_shipFor(t, board, 2));
  expect((c.dx - b.dx).abs(), lessThan(.1));
  return (c.dy - b.dy).abs();
}

bool _canStep(Map<String, dynamic> board, int index, int direction) {
  final ships = _ships(board), ship = ships[index];
  if (ship['isBlocking'] == true) return false;
  final shifted = Map<String, dynamic>.from(ship),
      key = ship['isHorizontal'] == true ? 'col' : 'row';
  shifted[key] = (ship[key] as int) + direction;
  final occupied = <(int, int)>{};
  for (var i = 0; i < ships.length; i++) {
    if (i != index) occupied.addAll(_cells(ships[i]));
  }
  return _cells(shifted).every(
    (cell) =>
        cell.$1 >= 0 &&
        cell.$1 < 6 &&
        cell.$2 >= 0 &&
        cell.$2 < 6 &&
        !occupied.contains(cell),
  );
}

Future<void> _actualAuthoredInput(WidgetTester t) async {
  final before = _capture(t), ships = _ships(before);
  for (var index = 0; index < ships.length; index++) {
    // Avoid a chance instant terminal player move; test a genuine nonplayer
    // legal input on whichever authored puzzle the production loader selected.
    if (ships[index]['isPlayer'] == true ||
        ships[index]['isBlocking'] == true) {
      continue;
    }
    for (final direction in [-1, 1]) {
      if (!_canStep(before, index, direction)) continue;
      final finder = _ship(t, index);
      await t.ensureVisible(finder);
      await t.pump();
      expect(finder.hitTestable(), findsOneWidget);
      final gesture = await t.startGesture(t.getCenter(finder));
      final axis = ships[index]['isHorizontal'] == true
          ? const Offset(1, 0)
          : const Offset(0, 1);
      await gesture.moveBy(axis * (22.0 * direction));
      await t.pump();
      await gesture.moveBy(axis * (35.0 * direction));
      await t.pump();
      await gesture.up();
      await t.pump();
      final after = _capture(t),
          moved = _ships(after),
          key = ships[index]['isHorizontal'] == true ? 'col' : 'row';
      final delta = (moved[index][key] as int) - (ships[index][key] as int);
      expect(delta * direction, greaterThan(0));
      expect(
        (after['moveCount'] as int) - (before['moveCount'] as int),
        delta.abs(),
      );
      final otherAxis = key == 'col' ? 'row' : 'col';
      expect(moved[index][otherAxis], ships[index][otherAxis]);
      for (var i = 0; i < ships.length; i++) {
        if (i != index) expect(moved[i], ships[i]);
      }
      // The newly selected authored puzzle need not contain13ships; use its
      // actual ordered models for the generic occupancy check.
      final occupied = <(int, int)>{};
      for (final ship in moved) {
        for (final cell in _cells(ship)) {
          expect(cell.$1, inInclusiveRange(0, 5));
          expect(cell.$2, inInclusiveRange(0, 5));
          expect(occupied.add(cell), isTrue);
        }
      }
      return;
    }
  }
  fail('The actual selected authored puzzle must offer legal nonplayer input');
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

Future<void> _popCover(WidgetTester t) async {
  Navigator.of(t.element(find.text('Covering route'))).pop();
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  await t.pump();
  for (
    var i = 0;
    i < 4 &&
        find.text('Covering route', skipOffstage: false).evaluate().isNotEmpty;
    i++
  ) {
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
  }
  expect(find.text('Covering route', skipOffstage: false), findsNothing);
}

void main() {
  var id = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'gridlock_round_${id++}';
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets(
    'Gridlock: actual authored F drag moves one legal cell and saves coherently',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      await _oneLeftF(t);
      final moved = _capture(t);
      expect(_ships(moved)[4]['col'], 2);
      expect(moved['moveCount'], 1);
      _validate(moved);
      expect(app.gp.outcomeCount, 0);
      await _restore(t, moved);
      expect(_capture(t), moved);
      await t.pump(const Duration(milliseconds: 800));
      await PuzzleSessionStore.instance.flush();
      expect(
        await PuzzleSessionStore.instance.load('space_station_gridlock', 1, 1),
        moved,
      );
    },
  );
  testWidgets(
    'Gridlock: actual held pan cannot charge replacement ships at the reused authored index',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real, fRight: true));
      final gesture = await _startRight(
        t,
        4,
      ); // F is at its legally reached right boundary.
      expect(_capture(t)['moveCount'], 1);
      await _restore(t, _fixture(real, fLeft: true));
      final before = _capture(t);
      await gesture.moveBy(const Offset(35, 0));
      await t.pump();
      await gesture.up();
      await t.pump();
      expect(_capture(t), before);
      expect(app.gp.outcomeCount, 0);
      final fresh = await _startRight(t, 4);
      await fresh.up();
      await t.pump();
      expect(_ships(_capture(t))[4]['col'], 3);
      expect(_capture(t)['moveCount'], 2);
      _validate(_capture(t));
    },
  );
  testWidgets(
    'Gridlock: actual final exit wins once with preserved reference and terminal capture null',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
      expect(app.gp.lastOutcome!.score, 560);
      expect(app.gp.lastOutcome!.movesUsed, 22);
      expect(app.gp.lastOutcome!.optimalMoves, 8);
      expect(_state(t).capturePuzzleSession(), isNull);
      await _result(t);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'Gridlock: obsolete delayed success cannot open over a new legal authored round',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      expect(app.gp.outcomeCount, 1);
      await _restore(t, _fixture(real));
      final before = _capture(t);
      await _result(t);
      expect(_dialogs(), findsNothing);
      expect(_capture(t), before);
      expect(app.gp.outcomeCount, 1);
      await _oneLeftF(t);
      expect(_capture(t)['moveCount'], 1);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'Gridlock: restore removes the built owned result and rejects its retained Next callback',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      await _result(t);
      expect(_dialogs(), findsOneWidget);
      final next = find.widgetWithText(
        ElevatedButton,
        S.of(t.element(_screen))!.nextPuzzle,
      );
      await t.ensureVisible(next);
      await t.pump();
      expect(next.hitTestable(), findsOneWidget);
      final retained = t.widget<ElevatedButton>(next).onPressed!;
      await _restore(t, _fixture(real));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(_dialogs(), findsNothing);
      final before = _capture(t);
      retained();
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      await t.pump();
      expect(_capture(t), before);
      expect(app.gp.outcomeCount, 1);
      await _oneLeftF(t);
      expect(_capture(t)['moveCount'], 1);
    },
  );

  for (final initial in [true, false]) {
    testWidgets(
      'Gridlock: ${initial ? 'initial' : 'mid-win'} reduced motion snaps owned exit and clears particles',
      (t) async {
        final (app, real) = await _mount(t, reduced: initial);
        final beforeExit = _fixture(real, beforeExit: true);
        await _win(t, real);
        expect(app.gp.outcomeCount, 1);
        if (!initial) {
          await t.pump(const Duration(milliseconds: 70));
          final transform = _exitTransform(t, beforeExit);
          expect(transform, findsOneWidget);
          final x = t.widget<Transform>(transform).transform.storage[12];
          final cell = _cellFromStationaryReferences(t, beforeExit);
          expect(x, greaterThan(0));
          expect(x, lessThan(2 * cell));
          expect(_state(t).particles, isNotEmpty);
          app.motion.value = true;
        }
        // Shared motion completions can require post-frame work plus rendering;
        // these frames advance no movement time or threshold.
        await t.pump();
        await t.pump();
        await t.pump();
        final transform = _exitTransform(t, beforeExit);
        expect(transform, findsOneWidget);
        expect(
          t.widget<Transform>(transform).transform.storage[12],
          closeTo(2 * _cellFromStationaryReferences(t, beforeExit), .1),
        );
        expect(_state(t).particles, isEmpty);
        expect(_state(t).moveCount, 22);
        expect(app.gp.outcomeCount, 1);
        await _result(t);
        expect(_dialogs(), findsOneWidget);
        final scale = find.byWidgetPredicate(
          (w) => w is Transform && w.child is ScrollableRoundDialog,
        );
        expect(scale, findsOneWidget);
        expect(
          t.widget<Transform>(scale).transform.storage[0],
          closeTo(1, .000001),
        );
        await t.ensureVisible(_next(t));
        await t.pump();
        expect(_next(t).hitTestable(), findsOneWidget);
        await t.tap(_next(t));
        await t.pump();
        await _waitPlayable(t);
        await _actualAuthoredInput(t);
        expect(app.gp.outcomeCount, 1);
      },
    );
  }
  testWidgets(
    'Gridlock: restored legal exited board is silent terminal without replaying learning outcome',
    (t) async {
      final (app, real) = await _mount(t);
      final exited = _fixture(real, beforeExit: true);
      _legalStep(exited, 0, 1);
      expect(exited['moveCount'], 22);
      expect(_ships(exited)[0]['col'], 4);
      await _restore(t, exited);
      await _result(t);
      expect(_state(t).gameActive, isFalse);
      expect(_state(t).hasWon, isTrue);
      expect(_state(t).capturePuzzleSession(), isNull);
      expect(app.gp.outcomeCount, 0);
      expect(find.byType(RoundSummary), findsNothing);
      // A silent retry card or an owned silent dialog may be added by the repair;
      // this case deliberately does not prescribe its wording/hierarchy.
      await _restore(t, _fixture(real));
      await _oneLeftF(t);
      expect(_capture(t)['moveCount'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'Gridlock: actual current Next loads another usable authored puzzle without replaying the win',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      await _result(t);
      final outcome = app.gp.lastOutcome;
      await t.ensureVisible(_next(t));
      await t.pump();
      expect(_next(t).hitTestable(), findsOneWidget);
      await t.tap(_next(t));
      await t.pump();
      await _waitPlayable(t);
      expect(_dialogs(), findsNothing);
      expect(_capture(t)['moveCount'], 0);
      expect(_capture(t)['_currentPuzzleId'], isNotNull);
      expect(app.gp.outcomeCount, 1);
      expect(identical(app.gp.lastOutcome, outcome), isTrue);
      await _actualAuthoredInput(t);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'Gridlock: covered result rejects retained Next and Bridge without popping the cover',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      await _result(t);
      final next = t.widget<ElevatedButton>(_next(t)).onPressed!;
      final bridge = t.widget<ElevatedButton>(_bridge(t)).onPressed!;
      await _cover(t);
      final covering = ModalRoute.of(t.element(find.text('Covering route')))!;
      next();
      bridge();
      await t.pump();
      expect(covering.isCurrent, isTrue);
      expect(find.text('Covering route'), findsOneWidget);
      expect(_state(t).moveCount, 22);
      expect(app.gp.outcomeCount, 1);
      await _popCover(t);
      expect(_dialogs(), findsOneWidget);
      await t.ensureVisible(_next(t));
      await t.pump();
      expect(_next(t).hitTestable(), findsOneWidget);
      await t.tap(_next(t));
      await t.pump();
      await _waitPlayable(t);
      await _actualAuthoredInput(t);
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'Gridlock: restore beneath covered result removes only its owned route and old callbacks stay inert',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      await _result(t);
      final next = t.widget<ElevatedButton>(_next(t)).onPressed!;
      final bridge = t.widget<ElevatedButton>(_bridge(t)).onPressed!;
      await _cover(t);
      final covering = ModalRoute.of(t.element(find.text('Covering route')))!;
      await _restore(t, _fixture(real));
      final before = _capture(t);
      expect(covering.isCurrent, isTrue);
      next();
      bridge();
      await t.pump();
      expect(covering.isCurrent, isTrue);
      expect(_capture(t), before);
      await _popCover(t);
      expect(_dialogs(), findsNothing);
      next();
      bridge();
      await t.pump();
      expect(_capture(t), before);
      await _oneLeftF(t);
      expect(_capture(t)['moveCount'], 1);
      expect(app.gp.outcomeCount, 1);
    },
  );
  for (final locale in ['en', 'de']) {
    testWidgets(
      'Gridlock: $locale 390x500 text2 keeps actual legal drag and current result Next reachable',
      (t) async {
        final (app, real) = await _mount(
          t,
          locale: Locale(locale),
          scale: 2,
          size: const Size(390, 500),
          reduced: true,
        );
        await _restore(t, _fixture(real));
        await _oneLeftF(t);
        expect(_ships(_capture(t))[4]['col'], 2);
        expect(_capture(t)['moveCount'], 1);
        expect(t.takeException(), isNull);
        await _win(t, real);
        await _result(t);
        expect(app.gp.outcomeCount, 1);
        expect(t.takeException(), isNull);
        await t.ensureVisible(_next(t));
        await t.pump();
        expect(_next(t).hitTestable(), findsOneWidget);
        await t.tap(_next(t));
        await t.pump();
        await _waitPlayable(t);
        expect(_dialogs(), findsNothing);
        await _actualAuthoredInput(t);
        expect(app.gp.outcomeCount, 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final blocked in ['wall', 'cross-axis', 'occupied']) {
    testWidgets(
      'Gridlock: $blocked input neither moves nor charges and fresh input still works',
      (t) async {
        final (app, real) = await _mount(t);
        await _restore(t, _fixture(real));
        final before = _capture(t);
        final index = blocked == 'wall'
            ? 12
            : blocked == 'occupied'
            ? 2
            : 4;
        final finder = _ship(t, index);
        final gesture = await t.startGesture(t.getCenter(finder));
        final delta = blocked == 'cross-axis'
            ? const Offset(0, -40)
            : const Offset(-40, 0);
        await gesture.moveBy(delta);
        await t.pump();
        await gesture.moveBy(delta);
        await t.pump();
        await gesture.up();
        await t.pump();
        expect(_capture(t), before);
        expect(app.gp.outcomeCount, 0);
        await _oneLeftF(t);
        expect(_capture(t)['moveCount'], 1);
      },
    );
  }
  testWidgets(
    'Gridlock: every qualifying pan update commits one cell and cancel clears drag feedback',
    (t) async {
      final (_, real) = await _mount(t);
      await _restore(t, _fixture(real));
      final gesture = await t.startGesture(t.getCenter(_ship(t, 4)));
      await gesture.moveBy(const Offset(-22, 0));
      await t.pump();
      expect(_capture(t)['moveCount'], 1);
      expect(_ships(_capture(t))[4]['col'], 2);
      await gesture.moveBy(const Offset(-35, 0));
      await t.pump();
      expect(_capture(t)['moveCount'], 2);
      expect(_ships(_capture(t))[4]['col'], 1);
      _validate(_capture(t));
      await gesture.cancel();
      await t.pump();
      expect(_state(t).draggingShipIndex, isNull);
      expect(_state(t).dragStartPos, isNull);
      expect(_state(t).highlightedCells, isEmpty);
      expect(_capture(t)['moveCount'], 2);
    },
  );
  testWidgets(
    'Gridlock: vertical input preserves horizontal coordinate and counts legal cells',
    (t) async {
      final (app, real) = await _mount(t);
      await _restore(t, _fixture(real));
      // M(row2,col5,length2) can move down into the clear exit-side column.
      final before = _capture(t);
      expect(_canStep(before, 11, 1), isTrue);
      final expected = _copy(before);
      _legalStep(expected, 11, 1);
      final gesture = await t.startGesture(t.getCenter(_ship(t, 11)));
      await gesture.moveBy(const Offset(0, 22));
      await t.pump();
      await gesture.up();
      await t.pump();
      expect(_capture(t), expected);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'Gridlock: move particles expire after their actual half-second lifetime',
    (t) async {
      final (_, real) = await _mount(t);
      await _restore(t, _fixture(real));
      await _oneLeftF(t);
      expect(_state(t).particles, isNotEmpty);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(_state(t).particles, isEmpty);
      expect(_capture(t)['moveCount'], 1);
    },
  );
  testWidgets(
    'Gridlock: restore clears current drag highlights and particles without altering saved moves',
    (t) async {
      final (_, real) = await _mount(t);
      await _restore(t, _fixture(real));
      final gesture = await _startRight(t, 4);
      expect(_state(t).particles, isNotEmpty);
      expect(_state(t).highlightedCells, isNotEmpty);
      final replacement = _fixture(real, fLeft: true);
      await _restore(t, replacement);
      expect(_state(t).particles, isEmpty);
      expect(_state(t).highlightedCells, isEmpty);
      expect(_state(t).draggingShipIndex, isNull);
      await gesture.cancel();
      await t.pump();
      expect(_capture(t), replacement);
      await _oneLeftF(t);
      expect(_capture(t)['moveCount'], 2);
    },
  );
  for (final delay in [0, 100, 200, 300]) {
    testWidgets(
      'Gridlock: restore supersedes actual Next load at ${delay}ms without marking an obsolete puzzle',
      (t) async {
        final (app, real) = await _mount(t);
        await _win(t, real);
        await _result(t);
        final played = app.tracker.playedPuzzleIds;
        await t.tap(_next(t));
        await t.pump();
        for (var elapsed = 0; elapsed < delay; elapsed += 100) {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump();
        }
        final replacement = _fixture(real, fLeft: true);
        await _restore(t, replacement);
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump();
        }
        expect(_capture(t), replacement);
        expect(app.tracker.playedPuzzleIds, played);
        expect(app.gp.outcomeCount, 1);
        await _oneLeftF(t);
        expect(_capture(t)['moveCount'], 2);
      },
    );
  }
  testWidgets(
    'Gridlock: disposed win cannot push a delayed result or award twice',
    (t) async {
      final (app, real) = await _mount(t);
      await _win(t, real);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 2));
      expect(_dialogs(), findsNothing);
      expect(app.gp.outcomeCount, 1);
      expect(t.takeException(), isNull);
    },
  );
}

// Reuse the actual-control fixture in the separate loader-seam suite. The
// original-API suite above never passes the loader seam, including comparisons
// against a screen that predates that additive constructor argument.
Future<(GridlockTestApp, Map<String, dynamic>)> mountGridlock(WidgetTester t) =>
    _mount(t);
Map<String, dynamic> captureGridlock(WidgetTester t) => _capture(t);
Map<String, dynamic> gridlockFixture(Map<String, dynamic> source) =>
    _fixture(source, fLeft: true);
Future<void> restoreGridlock(WidgetTester t, Map<String, dynamic> board) =>
    _restore(t, board);
Future<void> moveGridlockLeft(WidgetTester t) => _oneLeftF(t);
Future<void> waitGridlockPlayable(WidgetTester t) => _waitPlayable(t);
