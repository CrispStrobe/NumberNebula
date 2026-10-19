import 'dart:async';
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
import 'package:space_math_academy/features/games/screens/relic_assembly_game.dart';
import 'package:space_math_academy/features/games/services/relic_assembly_logic.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'package:space_math_academy/generated/l10n.dart';

import 'support/round_dialog_finder.dart';

class _App {
  final Locale locale;
  final double scale;
  final int grade;
  final bool pushed;
  final ValueNotifier<bool> motion;
  final pause = GamePauseController();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
    progressService: ProgressService(),
    sriService: sri,
    cognitiveProfileService: cognitive,
  );
  _App({
    this.locale = const Locale('en'),
    this.scale = 1,
    this.grade = 1,
    this.pushed = false,
    bool reduced = true,
  }) : motion = ValueNotifier(reduced);

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
                textScaler: TextScaler.linear(scale),
              ),
              child: GamePauseScope(controller: pause, child: child!),
            ),
          ),
          home: pushed
              ? Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Home'),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RelicAssemblyGame(
                                  grade: grade,
                                  level: 1,
                                ),
                              ),
                            ),
                            child: const Text('Start relic'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RelicAssemblyGame(grade: grade, level: 1),
        ),
      );
}

final _screen = find.byType(RelicAssemblyGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> _snapshot(WidgetTester t) =>
    _copy(_state(t).capturePuzzleSession() as Map<String, dynamic>);
typedef _Drag = ({int tileIndex, Object round, int rotation});
final _targets = find.byWidgetPredicate((w) => w is DragTarget);
final _sources = find.byWidgetPredicate((w) => w is Draggable);
int _index(dynamic data) => data is int ? data : data.tileIndex as int;
Finder _source(int index) =>
    find.byWidgetPredicate((w) => w is Draggable && _index(w.data) == index);
Finder _slot(WidgetTester t, int pos) {
  final placement = List<int>.from(_snapshot(t)['placement'] as List);
  expect(placement[pos], -1);
  return _targets.at(placement.take(pos).where((v) => v < 0).length);
}

Finder _filled(WidgetTester t, int pos) {
  final placement = List<int>.from(_snapshot(t)['placement'] as List);
  expect(placement[pos], greaterThanOrEqualTo(0));
  final cells = find.ancestor(
    of: find.byIcon(Icons.close),
    matching: find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTap != null && w.onLongPress != null,
    ),
  );
  return cells.at(placement.take(pos).where((v) => v >= 0).length);
}

Finder _remove(WidgetTester t, int pos) => find
    .ancestor(
      of: find.descendant(
        of: _filled(t, pos),
        matching: find.byIcon(Icons.close),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null && w.onLongPress == null,
      ),
    )
    .first;
Finder _trayRotate(int index) => find
    .ancestor(
      of: find.descendant(
        of: _source(index),
        matching: find.byIcon(Icons.rotate_right),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null && w.onLongPress == null,
      ),
    )
    .first;
Offset _handle(WidgetTester t, int index) {
  final rect = t.getRect(_source(index));
  // At the56pxminimum the center overlaps the32pxrotate button. Lower-left
  // belongs to the actual opaque select/drag detector at every supported size.
  return Offset(rect.left + rect.width * .25, rect.top + rect.height * .75);
}

RelicAssemblyPuzzle _puzzle() => RelicAssemblyPuzzle(
      rows: 2,
      cols: 2,
      edgeValueCount: 3,
      solutionTiles: [
        RelicTile(edges: [1, 2, 3, 1]),
        RelicTile(edges: [2, 1, 1, 2]),
        RelicTile(edges: [3, 3, 2, 2]),
        RelicTile(edges: [1, 2, 1, 3]),
      ],
      playerTiles: [
        RelicTile(edges: [3, 3, 2, 2]),
        RelicTile(edges: [1, 2, 3, 1]),
        RelicTile(edges: [2, 1, 1, 2]),
        RelicTile(edges: [3, 1, 2, 1]),
      ],
    );
Map<String, dynamic> _board({
  List<int> placement = const [-1, -1, -1, -1],
  List<int> rotations = const [0, 0, 0, 0],
  int moves = 0,
  int? selected,
}) {
  final p = _puzzle();
  const solution = [1, 2, 0, 3], turns = [0, 0, 0, 3];
  // Check the fixture with independent edge indexing, including baked D turn.
  int edge(int pos, int side) =>
      p.playerTiles[solution[pos]].edges[(side - turns[solution[pos]] + 4) % 4];
  for (var pos = 0; pos < 4; pos++) {
    expect(
      List.generate(4, (side) => edge(pos, side)),
      p.solutionTiles[pos].edges,
    );
    expect(p.playerTiles[pos].edges.every((v) => v >= 1 && v <= 3), isTrue);
    if (pos % 2 == 0) expect(edge(pos, 1), edge(pos + 1, 3));
    if (pos < 2) expect(edge(pos, 2), edge(pos + 2, 0));
  }
  expect(solution.toSet(), {0, 1, 2, 3});
  return {
    'puzzle': p.toJson(),
    'placement': placement,
    'rotations': rotations,
    '_placements': moves,
    'selectedTileIndex': selected,
  };
}

Map<String, dynamic> _uniform({int size = 2, bool duplicates = false}) {
  final count = size * size;
  final tiles = List.generate(count, (_) => RelicTile(edges: [1, 1, 1, 1]));
  return {
    'puzzle': RelicAssemblyPuzzle(
      rows: size,
      cols: size,
      edgeValueCount: 3,
      solutionTiles: tiles,
      playerTiles: tiles,
    ).toJson(),
    'placement': List.filled(count, duplicates ? 0 : -1),
    'rotations': List.filled(count, 0),
    '_placements': duplicates ? count : 0,
    'selectedTileIndex': null,
  };
}

Map<String, dynamic> _phoneBoard({bool fullIncorrect = false}) {
  final board = _uniform(size: 3);
  final json = board['puzzle'] as Map<String, dynamic>;
  final players = json['playerTiles'] as List;
  final solution = json['solutionTiles'] as List;
  (players[8] as Map<String, dynamic>)['edges'] = [2, 1, 1, 1];
  (solution[8] as Map<String, dynamic>)['edges'] = [1, 2, 1, 1];
  final puzzle = RelicAssemblyPuzzle.fromJson(json);
  final correctTurns = List<int>.filled(9, 0)..[8] = 1;
  // Check all nine tiles and twelve internal joins independently of the
  // production validator. Only the outer right edge carries2 when solved.
  int edge(int pos, int side) =>
      puzzle.playerTiles[pos].edges[(side - correctTurns[pos] + 4) % 4];
  for (var pos = 0; pos < 9; pos++) {
    expect(
      List.generate(4, (side) => edge(pos, side)),
      puzzle.solutionTiles[pos].edges,
    );
    expect(
      puzzle.playerTiles[pos].edges.every((value) => value >= 1 && value <= 3),
      isTrue,
    );
    if (pos % 3 < 2) {
      expect(edge(pos, 1), edge(pos + 1, 3));
    }
    if (pos < 6) {
      expect(edge(pos, 2), edge(pos + 3, 0));
    }
  }
  expect(puzzle.rows, 3);
  expect(puzzle.cols, 3);
  expect(puzzle.playerTiles.length, 9);
  // At rotation0 the edge from cell5(bottom1) to cell8(top2) is wrong.
  expect(puzzle.playerTiles[5].edges[2], 1);
  expect(puzzle.playerTiles[8].edges[0], 2);
  if (fullIncorrect) {
    board['placement'] = List<int>.generate(9, (index) => index);
    board['_placements'] = 9;
  }
  return board;
}

Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic s = _state(t);
  s.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  s.setState(() => s.applyPuzzleSession(_copy(board)));
  await t.pump();
  await t.pump();
}

Future<_App> _mount(
  WidgetTester t, {
  bool reduced = true,
  Locale locale = const Locale('en'),
  double scale = 1,
  int grade = 1,
  bool pushed = false,
}) async {
  final app = _App(
    reduced: reduced,
    locale: locale,
    scale: scale,
    grade: grade,
    pushed: pushed,
  );
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
  if (pushed) {
    await t.tap(find.text('Start relic'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  for (var i = 0; i < 30; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    if (_state(t).capturePuzzleSession() != null) break;
  }
  expect(_state(t).capturePuzzleSession(), isNotNull);
  await _restore(t, _board());
  return app;
}

void _deliver(dynamic target, dynamic data) {
  if (data is int) {
    target.onAcceptWithDetails!(
      DragTargetDetails<int>(data: data, offset: Offset.zero),
    );
  } else {
    target.onAcceptWithDetails!(
      DragTargetDetails<_Drag>(data: data as _Drag, offset: Offset.zero),
    );
  }
}

Future<void> _select(WidgetTester t, int index) async {
  await t.ensureVisible(_source(index));
  await t.pump();
  await t.tapAt(_handle(t, index));
  await t.pump();
}

Future<void> _drop(WidgetTester t, int index, int pos) async {
  await t.ensureVisible(_source(index));
  await t.pump();
  final from = _handle(t, index), to = t.getCenter(_slot(t, pos));
  await t.dragFrom(from, to - from);
  await t.pump();
}

Future<void> _dialog(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
  expect(roundDialogs, findsOneWidget);
}

Future<void> _finish(WidgetTester t) async {
  await _restore(
    t,
    _board(placement: [1, 2, 0, -1], rotations: [0, 0, 0, 3], moves: 3),
  );
  await _drop(t, 3, 3);
  await _dialog(t);
}

Finder _retry() => find
    .descendant(
      of: roundDialogs,
      matching: find.byWidgetPredicate(
        (w) => w is ButtonStyleButton && w.onPressed != null && w.child is Text,
      ),
    )
    .first;
Future<void> _cover(WidgetTester t) async {
  showDialog<void>(
    context: t.element(_screen),
    builder: (_) => const AlertDialog(content: Text('Covering route')),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _generatedInput(WidgetTester t) async {
  final dynamic data = t.widget<Draggable>(_sources.first).data;
  final index = _index(data);
  await _drop(t, index, 0);
  expect((_snapshot(t)['placement'] as List)[0], index);
  expect(_snapshot(t)['_placements'], 1);
}

void main() {
  var profile = 0;
  setUp(() {
    ProfilePreferences.activeId = 'relic_rounds_${profile++}';
    SharedPreferences.setMockInitialValues({});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets('contract: actual drag consumes exactly one physical tile', (
    t,
  ) async {
    final app = await _mount(t);
    await _drop(t, 1, 0);
    expect(_snapshot(t)['placement'], [1, -1, -1, -1]);
    expect(_snapshot(t)['_placements'], 1);
    expect(_source(1), findsNothing);
    expect(_sources, findsNWidgets(3));
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
    'contract: actual select toggles and restored unused selection places by tap',
    (t) async {
      final app = await _mount(t);
      await _select(t, 1);
      expect(_snapshot(t)['selectedTileIndex'], 1);
      await _select(t, 1);
      expect(_snapshot(t)['selectedTileIndex'], isNull);
      await _restore(t, _board(selected: 1));
      await t.tap(_slot(t, 0));
      await t.pump();
      expect(_snapshot(t)['placement'], [1, -1, -1, -1]);
      expect(_snapshot(t)['selectedTileIndex'], isNull);
      expect(_snapshot(t)['_placements'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: overlay long-press and grid rotation are free and removal returns inventory',
    (t) async {
      await _mount(t);
      await t.tap(_trayRotate(1));
      await t.pump();
      expect((_snapshot(t)['rotations'] as List)[1], 1);
      await t.longPressAt(_handle(t, 1));
      await t.pump();
      expect((_snapshot(t)['rotations'] as List)[1], 2);
      await _drop(t, 1, 0);
      await t.tap(_filled(t, 0));
      await t.pump();
      expect((_snapshot(t)['rotations'] as List)[1], 3);
      expect(_snapshot(t)['_placements'], 1);
      await t.tap(_remove(t, 0));
      await t.pump();
      expect(_source(1), findsOneWidget);
      await _drop(t, 1, 0);
      await t.longPress(_filled(t, 0));
      await t.pump();
      expect(_snapshot(t)['placement'], [-1, -1, -1, -1]);
      expect(_snapshot(t)['_placements'], 2);
    },
  );
  testWidgets(
    'contract: full incorrect board persists and one grid turn wins without extra placements',
    (t) async {
      final app = await _mount(t);
      await _restore(
        t,
        _board(placement: [1, 2, 0, 3], rotations: [0, 0, 0, 2], moves: 4),
      );
      expect(roundDialogs, findsNothing);
      expect(app.gp.outcomeCount, 0);
      await t.pump(const Duration(milliseconds: 800));
      await PuzzleSessionStore.instance.flush();
      final saved = await PuzzleSessionStore.instance.load(
        'relic_assembly',
        1,
        1,
      );
      expect(saved!['placement'], [1, 2, 0, 3]);
      expect(saved['rotations'], [0, 0, 0, 2]);
      expect(saved['_placements'], 4);
      await t.tap(_filled(t, 3));
      await _dialog(t);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.score, 125);
      expect(app.gp.lastOutcome!.movesUsed, 4);
      expect(app.gp.lastOutcome!.optimalMoves, 4);
      expect(app.gp.lastOutcome!.performance, 1);
      expect(_state(t).capturePuzzleSession(), isNull);
    },
  );
  testWidgets(
    'contract: removing and replacing retains counted placement quality',
    (t) async {
      final app = await _mount(t);
      await _restore(
        t,
        _board(placement: [1, 2, 0, -1], rotations: [0, 0, 0, 3], moves: 3),
      );
      await t.tap(_remove(t, 0));
      await t.pump();
      await _drop(t, 1, 0);
      await _drop(t, 3, 3);
      await _dialog(t);
      expect(app.gp.lastOutcome!.movesUsed, 5);
      expect(app.gp.lastOutcome!.optimalMoves, 4);
      expect(app.gp.lastOutcome!.performance, Perf.fromMoves(5, 4));
      expect(app.gp.outcomeCount, 1);
    },
  );
  testWidgets(
    'contract: retained consumed payload cannot relocate its physical tile',
    (t) async {
      final app = await _mount(t);
      final dynamic data = t.widget<Draggable>(_source(1)).data;
      await _drop(t, 1, 0);
      final before = _snapshot(t);
      _deliver(t.widget(_slot(t, 1)), data);
      await t.pump();
      expect(_snapshot(t), before);
      expect(app.gp.outcomeCount, 0);
      await t.tap(_remove(t, 0));
      await t.pump();
      await _drop(t, 1, 0);
      expect((_snapshot(t)['placement'] as List)[0], 1);
      expect(_snapshot(t)['_placements'], 2);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: unknown payload is rejected without a crash or state change',
    (t) async {
      await _mount(t);
      final dynamic data = t.widget<Draggable>(_source(1)).data;
      final dynamic bad = data is int
          ? 999
          : (
              tileIndex: 999,
              round: data.round as Object,
              rotation: data.rotation as int,
            );
      final before = _snapshot(t);
      _deliver(t.widget(_slot(t, 0)), bad);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_snapshot(t), before);
    },
  );
  testWidgets('contract: old target and payload cannot cross restoration', (
    t,
  ) async {
    await _mount(t);
    final dynamic target = t.widget(_slot(t, 0));
    final dynamic data = t.widget<Draggable>(_source(1)).data;
    await _restore(t, _board(rotations: [1, 2, 3, 0]));
    final before = _snapshot(t);
    _deliver(target, data);
    _deliver(t.widget(_slot(t, 1)), data);
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets('contract: real active drag cannot cross restoration', (t) async {
    await _mount(t);
    final g = await t.startGesture(_handle(t, 1));
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    await _restore(t, _board());
    final before = _snapshot(t);
    await g.moveTo(t.getCenter(_slot(t, 0)));
    await g.up();
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets(
    'contract: dragged orientation matches its original avatar after live rotation',
    (t) async {
      await _mount(t);
      final rotate = t.widget<GestureDetector>(_trayRotate(3)).onTap!;
      final g = await t.startGesture(_handle(t, 3));
      await g.moveBy(const Offset(20, 0));
      await t.pump();
      rotate();
      await t.pump();
      expect((_snapshot(t)['rotations'] as List)[3], 1);
      await g.moveTo(t.getCenter(_slot(t, 0)));
      await g.up();
      await t.pump();
      expect((_snapshot(t)['placement'] as List)[0], 3);
      expect((_snapshot(t)['rotations'] as List)[3], 0);
      expect(_snapshot(t)['_placements'], 1);
    },
  );
  testWidgets(
    'contract: same-index replacement rejects a retained old removal',
    (t) async {
      final app = await _mount(t);
      await _drop(t, 1, 0);
      final old = t.widget<GestureDetector>(_remove(t, 0)).onTap!;
      await t.tap(_remove(t, 0));
      await t.pump();
      await _drop(t, 1, 0);
      final before = _snapshot(t);
      old();
      await t.pump();
      expect(_snapshot(t), before);
      expect(app.gp.outcomeCount, 0);
      await t.tap(_remove(t, 0));
      await t.pump();
      expect(_snapshot(t)['placement'], [-1, -1, -1, -1]);
      expect(_snapshot(t)['_placements'], 2);
    },
  );
  testWidgets(
    'contract: pointer-down grid rotation cannot transfer to a coalesced replacement',
    (t) async {
      final app = await _mount(t);
      final dynamic target = t.widget(_slot(t, 0));
      await _drop(t, 1, 0);
      final remove = t.widget<GestureDetector>(_remove(t, 0)).onTap!;
      final dynamic data = t.widget<Draggable>(_source(2)).data;
      final g = await t.startGesture(t.getCenter(_filled(t, 0)));
      remove();
      _deliver(target, data);
      await t.pump();
      final before = _snapshot(t);
      expect((before['placement'] as List)[0], 2);
      expect(before['_placements'], 2);
      await g.up();
      await t.pump();
      expect(_snapshot(t), before);
      expect(app.gp.outcomeCount, 0);
      await t.tap(_filled(t, 0));
      await t.pump();
      expect((_snapshot(t)['rotations'] as List)[2], 1);
    },
  );
  testWidgets(
    'contract: retained tray rotation and grid removal reject restored round',
    (t) async {
      await _mount(t);
      final rotate = t.widget<GestureDetector>(_trayRotate(2)).onTap!;
      await _drop(t, 1, 0);
      final remove = t.widget<GestureDetector>(_remove(t, 0)).onTap!;
      final before = _snapshot(t);
      await _restore(t, before);
      rotate();
      remove();
      await t.pump();
      expect(_snapshot(t), before);
    },
  );
  testWidgets(
    'contract: select pointer-down cannot become a new-round selection',
    (t) async {
      await _mount(t);
      final g = await t.startGesture(_handle(t, 1));
      final before = _snapshot(t);
      await _restore(t, before);
      await g.up();
      await t.pump();
      expect(_snapshot(t), before);
    },
  );
  for (final selected in [1, 999]) {
    testWidgets(
      'contract: unusable restored selection $selected cannot move or invent a tile',
      (t) async {
        final app = await _mount(t);
        await _restore(
          t,
          _board(placement: [1, -1, -1, -1], moves: 1, selected: selected),
        );
        expect(_snapshot(t)['selectedTileIndex'], isNull);
        final before = _snapshot(t);
        await t.tap(_slot(t, 1));
        await t.pump();
        expect(_snapshot(t), before);
        expect(app.gp.outcomeCount, 0);
        await _select(t, 2);
        await t.tap(_slot(t, 1));
        await t.pump();
        expect(_snapshot(t)['placement'], [1, 2, -1, -1]);
      },
    );
  }
  testWidgets(
    'contract: duplicate-index restored coverage is not a physical solve',
    (t) async {
      final app = await _mount(t);
      await _restore(t, _uniform(duplicates: true));
      expect(roundDialogs, findsNothing);
      await t.tap(_filled(t, 0));
      await t.pump();
      expect(app.gp.outcomeCount, 0);
      expect(_state(t).capturePuzzleSession(), isNotNull);
      await t.tap(_remove(t, 0));
      await t.pump();
      expect(_source(0), findsNothing);
      expect(_sources, findsNWidgets(3));
      expect(_snapshot(t)['_placements'], 4);
    },
  );
  testWidgets(
    'contract: solved restore offers silent retry without stale outcome evidence',
    (t) async {
      final app = await _mount(t);
      await _finish(t);
      final old = app.gp.lastOutcome;
      await _restore(
        t,
        _board(placement: [1, 2, 0, 3], rotations: [0, 0, 0, 3], moves: 7),
      );
      await _dialog(t);
      expect(app.gp.outcomeCount, 1);
      expect(identical(app.gp.lastOutcome, old), isTrue);
      expect(find.byType(RoundSummary), findsNothing);
      expect(_state(t).capturePuzzleSession(), isNull);
      await t.ensureVisible(_retry());
      expect(_retry().hitTestable(), findsOneWidget);
    },
  );
  testWidgets(
    'contract: terminal callbacks cannot replay wins or mutate records',
    (t) async {
      final app = await _mount(t);
      await _restore(
        t,
        _board(placement: [1, 2, 0, -1], rotations: [0, 0, 0, 3], moves: 3),
      );
      final dynamic target = t.widget(_slot(t, 3));
      final dynamic data = t.widget<Draggable>(_source(3)).data;
      final remove = t.widget<GestureDetector>(_remove(t, 0)).onTap!;
      await _drop(t, 3, 3);
      await _dialog(t);
      final outcome = app.gp.lastOutcome;
      remove();
      _deliver(target, data);
      await t.pump();
      expect(app.gp.outcomeCount, 1);
      expect(identical(app.gp.lastOutcome, outcome), isTrue);
      expect(_state(t).capturePuzzleSession(), isNull);
      expect(roundDialogs, findsOneWidget);
    },
  );
  testWidgets(
    'contract: owned result reset beneath a cover preserves the cover and rejects old retry',
    (t) async {
      await _mount(t);
      final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
      await _finish(t);
      final retry = t.widget<ButtonStyleButton>(_retry()).onPressed!;
      await _cover(t);
      back();
      retry();
      await t.pump();
      expect(find.text('Covering route'), findsOneWidget);
      await _restore(t, _board());
      expect(find.text('Covering route'), findsOneWidget);
      Navigator.of(t.element(find.text('Covering route'))).pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      expect(roundDialogs, findsNothing);
      retry();
      await t.pump();
      await _drop(t, 1, 0);
      expect(_snapshot(t)['_placements'], 1);
    },
  );
  testWidgets(
    'contract: owned result is removed even before its builder executes',
    (t) async {
      final app = await _mount(t);
      await _restore(
        t,
        _board(placement: [1, 2, 0, -1], rotations: [0, 0, 0, 3], moves: 3),
      );
      final dynamic data = t.widget<Draggable>(_source(3)).data;
      _deliver(t.widget(_slot(t, 3)), data);
      final dynamic state = _state(t);
      state.beginPuzzleSession();
      // ignore: invalid_use_of_protected_member
      state.setState(() => state.applyPuzzleSession(_copy(_board())));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      expect(roundDialogs, findsNothing);
      expect(app.gp.outcomeCount, 1);
      await _drop(t, 1, 0);
      expect(_snapshot(t)['_placements'], 1);
    },
  );
  testWidgets(
    'contract: actual retry and suggestion each open a playable generated round',
    (t) async {
      final app = await _mount(t);
      await _finish(t);
      await t.tap(_retry());
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      expect(roundDialogs, findsNothing);
      await _generatedInput(t);
      expect(app.gp.outcomeCount, 1);
      await _finish(t);
      await t.runAsync(
        () => OnboardingOverlay.markSeen('relic_assembly_all_games_guided_v2_rules'),
      );
      await t.runAsync(() => loadGameLibrary('relic_assembly'));
      final original = _state(t);
      final suggestion = find.descendant(
        of: find.byType(RoundSummary),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      await t.ensureVisible(suggestion);
      await t.tap(suggestion);
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      for (var i = 0; i < 30; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
        if (_screen.evaluate().length == 1 &&
            !identical(_state(t), original) &&
            _state(t).capturePuzzleSession() != null) {
          break;
        }
      }
      expect(identical(_state(t), original), isFalse);
      expect(roundDialogs, findsNothing);
      await _generatedInput(t);
      expect(app.gp.outcomeCount, 2);
    },
  );
  testWidgets(
    'contract: retained empty target cannot overwrite a live occupied cell',
    (t) async {
      await _mount(t);
      final dynamic target = t.widget(_slot(t, 0));
      await _drop(t, 1, 0);
      final dynamic data = t.widget<Draggable>(_source(2)).data;
      final before = _snapshot(t);
      _deliver(target, data);
      await t.pump();
      expect(_snapshot(t), before);
    },
  );
  for (final reducedInitially in [true, false]) {
    testWidgets(
      'contract: ${reducedInitially ? 'initial' : 'mid-hover'} reduced motion snaps actual hover paint and keeps completion usable',
      (t) async {
        final app = await _mount(t, reduced: reducedInitially);
        final target = _slot(t, 0);
        final g = await t.startGesture(_handle(t, 1));
        await g.moveTo(t.getCenter(target));
        await t.pump(const Duration(milliseconds: 50));
        app.motion.value = true;
        await t.pump();
        final painted = t
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: target,
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration as BoxDecoration;
        expect(painted.color, SpaceTheme.starYellow.withValues(alpha: .3));
        await g.up();
        await t.pump();
        expect((_snapshot(t)['placement'] as List)[0], 1);
        await _finish(t);
        await t.ensureVisible(_retry());
        expect(_retry().hitTestable(), findsOneWidget);
        expect(app.gp.outcomeCount, 1);
      },
    );
  }
  for (final locale in ['en', 'de']) {
    for (final height in [500.0, 844.0]) {
      testWidgets(
        'contract: large-text phone actual drag tap rotate and retry reachable ($locale $height)',
        (t) async {
          final app = await _mount(
            t,
            grade: 3,
            locale: Locale(locale),
            scale: 2,
          );
          await _restore(t, _phoneBoard());
          t.view.physicalSize = Size(390, height);
          await t.pump();
          expect(t.takeException(), isNull);
          await _drop(t, 0, 0);
          await _select(t, 1);
          await t.tap(_slot(t, 1));
          await t.pump();
          expect((_snapshot(t)['placement'] as List).take(2).toList(), [0, 1]);
          await t.tap(_filled(t, 1));
          await t.pump();
          expect((_snapshot(t)['rotations'] as List)[1], 1);
          await t.tap(_remove(t, 1));
          await t.pump();
          expect((_snapshot(t)['placement'] as List)[1], -1);
          await _restore(t, _phoneBoard(fullIncorrect: true));
          final wrong = _snapshot(t);
          expect((wrong['puzzle'] as Map)['rows'], 3);
          expect((wrong['puzzle'] as Map)['cols'], 3);
          expect(wrong['placement'], List<int>.generate(9, (index) => index));
          expect(wrong['rotations'], List<int>.filled(9, 0));
          expect(wrong['_placements'], 9);
          expect(roundDialogs, findsNothing);
          expect(app.gp.outcomeCount, 0);
          await t.ensureVisible(_filled(t, 8));
          await t.pump();
          expect(_filled(t, 8).hitTestable(), findsOneWidget);
          await t.tap(_filled(t, 8));
          await _dialog(t);
          expect(app.gp.outcomeCount, 1);
          expect(app.gp.lastOutcome!.score, 325);
          expect(app.gp.lastOutcome!.movesUsed, 9);
          expect(app.gp.lastOutcome!.optimalMoves, 9);
          expect(app.gp.lastOutcome!.performance, 1);
          expect(_state(t).capturePuzzleSession(), isNull);
          expect(t.takeException(), isNull);
          await t.ensureVisible(_retry());
          await t.pump();
          expect(_retry().hitTestable(), findsOneWidget);
        },
      );
    }
  }
  testWidgets(
    'seam: stale generation success cannot replace a restored round',
    (t) async {
      final app = await _mount(t);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      expect(_state(t).capturePuzzleSession(), isNull);
      await _restore(t, _board(placement: [1, -1, -1, -1], moves: 2));
      final before = _snapshot(t);
      pending.complete(_puzzle());
      await work;
      await t.pump();
      expect(_snapshot(t), before);
      expect(app.gp.outcomeCount, 0);
      await _drop(t, 2, 1);
      expect(_snapshot(t)['placement'], [1, 2, -1, -1]);
      expect(_snapshot(t)['_placements'], 3);
    },
  );
  testWidgets(
    'seam: stale generation failure cannot replace a restored round',
    (t) async {
      final app = await _mount(t);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      await _restore(t, _board(placement: [1, -1, -1, -1], moves: 1));
      final before = _snapshot(t);
      pending.completeError(StateError('obsolete generation failure'));
      await work;
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_snapshot(t), before);
      expect(find.text(S.of(t.element(_screen))!.tryAgain), findsNothing);
      expect(app.gp.outcomeCount, 0);
      await _drop(t, 2, 1);
      expect(_snapshot(t)['placement'], [1, 2, -1, -1]);
    },
  );
  testWidgets(
    'seam: late generation success after disposal has no effect',
    (t) async {
      final app = await _mount(t);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
      pending.complete(_puzzle());
      await work;
      await t.pump();
      expect(_screen, findsNothing);
      expect(t.takeException(), isNull);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'seam: late generation failure after disposal has no effect',
    (t) async {
      final app = await _mount(t);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
      pending.completeError(StateError('disposed generation failure'));
      await work;
      await t.pump();
      expect(_screen, findsNothing);
      expect(t.takeException(), isNull);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'seam: overlapping generations keep the newer completion and its input',
    (t) async {
      final app = await _mount(t);
      final older = Completer<RelicAssemblyPuzzle>();
      final newer = Completer<RelicAssemblyPuzzle>();
      final oldWork =
          _state(t).generateForTesting(older.future) as Future<void>;
      await t.pump();
      final newWork =
          _state(t).generateForTesting(newer.future) as Future<void>;
      await t.pump();
      newer.complete(_puzzle());
      await newWork;
      await t.pump();
      await _drop(t, 1, 0);
      final before = _snapshot(t);
      final different = RelicAssemblyPuzzle.fromJson(
        Map<String, dynamic>.from(_uniform()['puzzle'] as Map),
      );
      older.complete(different);
      await oldWork;
      await t.pump();
      expect(_snapshot(t), before);
      expect(app.gp.outcomeCount, 0);
      await _drop(t, 2, 1);
      expect(_snapshot(t)['placement'], [1, 2, -1, -1]);
      expect(_snapshot(t)['_placements'], 2);
    },
  );
  testWidgets(
    'seam: current generation failure offers an actual playable retry',
    (t) async {
      final app = await _mount(t);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      expect(_state(t).capturePuzzleSession(), isNull);
      pending.completeError(StateError('controlled current failure'));
      await work;
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_state(t).capturePuzzleSession(), isNull);
      expect(_sources, findsNothing);
      final retry = find.widgetWithText(
        ElevatedButton,
        S.of(t.element(_screen))!.tryAgain,
      );
      await t.ensureVisible(retry);
      await t.pump();
      expect(retry.hitTestable(), findsOneWidget);
      await t.tap(retry);
      for (var i = 0; i < 30; i++) {
        await t.pump();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        if (_state(t).capturePuzzleSession() != null) break;
      }
      expect(_state(t).capturePuzzleSession(), isNotNull);
      await _generatedInput(t);
      expect(_snapshot(t)['_placements'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'seam: held error retry cannot transfer to a coalesced replacement failure',
    (t) async {
      final app = await _mount(t);
      final first = Completer<RelicAssemblyPuzzle>();
      final firstWork =
          _state(t).generateForTesting(first.future) as Future<void>;
      first.completeError(StateError('first controlled failure'));
      await firstWork;
      await t.pump();
      final retry = find.widgetWithText(
        ElevatedButton,
        S.of(t.element(_screen))!.tryAgain,
      );
      expect(retry.hitTestable(), findsOneWidget);
      final oldRetry = t.widget<ElevatedButton>(retry).onPressed!;
      final press = await t.startGesture(t.getCenter(retry));
      await t.pump(const Duration(milliseconds: 50));
      final second = Completer<RelicAssemblyPuzzle>();
      final secondWork =
          _state(t).generateForTesting(second.future) as Future<void>;
      second.completeError(StateError('replacement controlled failure'));
      await secondWork;
      // Both generating and failure states coalesce before this frame.
      await t.pump();
      oldRetry();
      await press.up();
      await t.pump();
      expect(_state(t).capturePuzzleSession(), isNull);
      expect(retry.hitTestable(), findsOneWidget);
      expect(_sources, findsNothing);
      expect(t.takeException(), isNull);
      expect(app.gp.outcomeCount, 0);
      await t.tap(retry);
      for (var i = 0; i < 30; i++) {
        await t.pump();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        if (_state(t).capturePuzzleSession() != null) break;
      }
      expect(_state(t).capturePuzzleSession(), isNotNull);
      await _generatedInput(t);
      expect(_snapshot(t)['_placements'], 1);
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'seam: current generation success replaces the board and saves valid input',
    (t) async {
      final app = await _mount(t);
      await _drop(t, 1, 0);
      final pending = Completer<RelicAssemblyPuzzle>();
      final work = _state(t).generateForTesting(pending.future) as Future<void>;
      await t.pump();
      expect(_state(t).capturePuzzleSession(), isNull);
      final generated = RelicAssemblyPuzzle.fromJson(
        Map<String, dynamic>.from(_uniform()['puzzle'] as Map),
      );
      pending.complete(generated);
      await work;
      await t.pump();
      final ready = _snapshot(t);
      expect(ready['puzzle'], generated.toJson());
      expect(ready['placement'], [-1, -1, -1, -1]);
      expect(ready['rotations'], [0, 0, 0, 0]);
      expect(ready['selectedTileIndex'], isNull);
      expect(ready['_placements'], 0);
      await _generatedInput(t);
      await t.pump(const Duration(milliseconds: 800));
      await PuzzleSessionStore.instance.flush();
      final saved = await PuzzleSessionStore.instance.load(
        'relic_assembly',
        1,
        1,
      );
      expect(saved, _snapshot(t));
      expect(app.gp.outcomeCount, 0);
    },
  );
  testWidgets(
    'contract: mid-success reduced motion snaps the actual result scale and keeps retry playable',
    (t) async {
      final app = await _mount(t, reduced: false);
      await _restore(
        t,
        _board(
          placement: [1, 2, 0, -1],
          rotations: [0, 0, 0, 3],
          moves: 3,
        ),
      );
      await _drop(t, 3, 3);
      await t.pump(const Duration(milliseconds: 70));
      expect(roundDialogs, findsOneWidget);
      // The game's success transform directly wraps its Dialog. Framework
      // route animations and button ripples do not satisfy this predicate.
      final resultScale = find.byWidgetPredicate(
        (w) => w is Transform && w.child is Dialog,
      );
      expect(resultScale, findsOneWidget);
      double scale() => t.widget<Transform>(resultScale).transform.storage[0];
      expect(scale(), greaterThan(0));
      expect(scale(), isNot(closeTo(1, 0.000001)));
      app.motion.value = true;
      await t.pump();
      await t.pump();
      expect(scale(), closeTo(1, 0.000001));
      expect(app.gp.outcomeCount, 1);
      expect(_state(t).capturePuzzleSession(), isNull);
      await t.ensureVisible(_retry());
      await t.pump();
      expect(_retry().hitTestable(), findsOneWidget);
      await t.tap(_retry());
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      for (var i = 0; i < 30; i++) {
        await t.pump();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        if (_state(t).capturePuzzleSession() != null) break;
      }
      expect(roundDialogs, findsNothing);
      await _generatedInput(t);
      expect(app.gp.outcomeCount, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'contract: disposing the game beneath its result removes only its owned dialog and returns to Home',
    (t) async {
      final app = await _mount(t, pushed: true);
      final gameRoute = ModalRoute.of(t.element(_screen))!;
      final navigator = Navigator.of(t.element(_screen));
      await _finish(t);
      await _cover(t);
      final coveringRoute = ModalRoute.of(
        t.element(find.text('Covering route')),
      )!;
      navigator.removeRoute(gameRoute);
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_screen, findsNothing);
      expect(find.text('Covering route'), findsOneWidget);
      expect(coveringRoute.isCurrent, isTrue);
      expect(find.byType(RoundSummary, skipOffstage: false), findsNothing);
      expect(app.gp.outcomeCount, 1);
      navigator.pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(roundDialogs, findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Start relic').hitTestable(), findsOneWidget);
      expect(ModalRoute.of(t.element(find.text('Home')))!.isCurrent, isTrue);
      expect(app.gp.outcomeCount, 1);
      expect(t.takeException(), isNull);
    },
  );
}
