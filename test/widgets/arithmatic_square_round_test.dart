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
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/arithmatic_square_game.dart';
import 'package:space_math_academy/features/games/services/arithmetic_square_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final motion = ValueNotifier(true);
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  final double scale;
  final Locale locale;
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({this.scale = 1, this.locale = const Locale('en')});
  Widget build() => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: gp),
            ChangeNotifierProvider<SriService>.value(value: sri),
            ChangeNotifierProvider.value(value: cognitive),
            ChangeNotifierProvider.value(value: debug),
          ],
          child: MaterialApp(
              locale: locale,
              theme: ThemeData(platform: TargetPlatform.android),
              localizationsDelegates: S.localizationsDelegates,
              supportedLocales: S.supportedLocales,
              builder: (context, child) => ValueListenableBuilder<bool>(
                  valueListenable: motion,
                  builder: (_, reduced, __) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          disableAnimations: reduced,
                          textScaler: TextScaler.linear(scale)),
                      child: child!)),
              home: const ArithmeticSquareGame(grade: 1, level: 1)));
}

final _screen = find.byType(ArithmeticSquareGame);
final _dialog = find.byType(Dialog);
final _targets = find.byType(DragTarget<ArithmeticSquareDrag>);
dynamic _session(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _snap(WidgetTester t) =>
    jsonDecode(jsonEncode(_session(t).capturePuzzleSession()))
        as Map<String, dynamic>;
Map<String, dynamic> _board(
    {Set<String> empty = const {'r0c0', 'r0c1'},
    Map<String, int> answers = const {},
    int? moves}) {
  final solution = {
    'r0c0': 1,
    'r0c1': 1,
    'r0c2': 2,
    'r1c0': 1,
    'r1c1': 1,
    'r1c2': 2,
    'r2c0': 2,
    'r2c1': 2,
    'r2c2': 4
  };
  final pool = [...empty.map((c) => solution[c]!), 3];
  final puzzle = ArithmeticSquarePuzzle(
      gridSize: 3,
      clues: Map.fromEntries(
          solution.entries.where((e) => !empty.contains(e.key))),
      playerHints: {},
      emptyCells: empty,
      rowOperators: List.generate(3, (_) => ['+']),
      columnOperators: List.generate(3, (_) => ['+']),
      numberPool: pool,
      fullSolution: solution);
  final remaining = List<int>.from(pool);
  for (final v in answers.values) {
    remaining.remove(v);
  }
  return {
    'puzzle': puzzle.toJson(),
    'userSolution': answers.entries.map((e) => [e.key, e.value]).toList(),
    'numberPool': remaining,
    '_movesRemaining': moves ?? empty.length * 2,
    '_maxMoves': empty.length * 2,
    '_optimalMoves': empty.length
  };
}

Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic state = _session(t);
  state.beginPuzzleSession();
  state.applyPuzzleSession(board);
  state.rebuildForTesting();
  await t.pump();
  await t.pump();
}

Future<_App> _mount(WidgetTester t,
    {double scale = 1,
    Locale locale = const Locale('en'),
    Map<String, dynamic>? board}) async {
  final app = _App(scale: scale, locale: locale);
  t.view.physicalSize = const Size(1400, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(app.motion.dispose);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  await t.pumpWidget(app.build());
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 20));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(t).capturePuzzleSession() != null) break;
  }
  expect(_session(t).capturePuzzleSession(), isNotNull);
  await _restore(t, board ?? _board());
  return app;
}

Finder _source(int n) => find
    .byWidgetPredicate(
        (w) => w is Draggable<ArithmeticSquareDrag> && w.data!.number == n)
    .first;
Future<void> _drag(WidgetTester t, int n) async {
  final source = _source(n);
  final target = _targets.first;
  await t.ensureVisible(source);
  await t.ensureVisible(target);
  await t.drag(source, t.getCenter(target) - t.getCenter(source));
  await t.pump();
}

Future<Map<String, dynamic>?> _saved(WidgetTester t) async {
  var done = false;
  Map<String, dynamic>? result;
  PuzzleSessionStore.instance.load('arithmatic_square', 1, 1).then((v) {
    result = v;
    done = true;
  });
  for (var i = 0; i < 100 && !done; i++) {
    await t.pump(const Duration(milliseconds: 20));
  }
  expect(done, isTrue);
  return result;
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'arith_square_audit_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_arithmatic_square': true});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets(
      'real drag spends a move, removal is free and partial save survives',
      (t) async {
    final app = await _mount(t);
    await _drag(t, 1);
    expect(_snap(t)['userSolution'], [
      ['r0c0', 1]
    ]);
    expect(_snap(t)['_movesRemaining'], 3);
    await t.pump(const Duration(seconds: 1));
    final saved = await _saved(t);
    expect(saved, isNotNull);
    await _restore(t, saved!);
    expect(_snap(t)['userSolution'], [
      ['r0c0', 1]
    ]);
    final filled = find.byWidgetPredicate((w) =>
        w is GestureDetector &&
        w.key is ValueKey &&
        (w.key as ValueKey).value.toString().contains('arith-filled'));
    await t.tap(filled.first);
    await t.pump();
    expect(_snap(t)['userSolution'], isEmpty);
    expect(_snap(t)['_movesRemaining'], 3);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'duplicate placed numbers consume two inventory copies after restore',
      (t) async {
    await _mount(t, board: _board(empty: {'r0c0', 'r0c1', 'r1c0'}));
    await _drag(t, 1);
    await _drag(t, 1);
    final before = _snap(t);
    expect(before['numberPool'], unorderedEquals([1, 3]));
    await _restore(t, before);
    expect(_snap(t)['numberPool'], unorderedEquals([1, 3]));
    expect(_snap(t)['userSolution'], before['userSolution']);
  });
  testWidgets('last legal correct drop wins once and clears saved session',
      (t) async {
    final app = await _mount(t, board: _board(moves: 2));
    await _drag(t, 1);
    await _drag(t, 1);
    await t.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(t).capturePuzzleSession(), isNull);
    expect(await _saved(t), isNull);
    final retry = find.widgetWithText(
        ElevatedButton, S.of(t.element(_screen))!.playAgain);
    await t.ensureVisible(retry);
    await t.tap(retry);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets(
      'full wrong last drop loses rather than permitting negative moves',
      (t) async {
    final app = await _mount(t, board: _board(answers: {'r0c0': 1}, moves: 1));
    await _drag(t, 3);
    await t.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(t).capturePuzzleSession(), isNull);
  });
  for (final solved in [false, true]) {
    testWidgets(
        'older full zero-move save is terminal without replay (solved:$solved)',
        (t) async {
      final app = await _mount(t);
      await _restore(
          t, _board(answers: {'r0c0': 1, 'r0c1': solved ? 1 : 3}, moves: 0));
      await t.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      expect(_session(t).capturePuzzleSession(), isNull);
      expect(app.gp.outcomeCount, 0);
    });
  }
  testWidgets('old target and drag payload cannot mutate restored round',
      (t) async {
    final app = await _mount(t);
    final old = t.widget<DragTarget<ArithmeticSquareDrag>>(_targets.first);
    final payload = t.widget<Draggable<ArithmeticSquareDrag>>(_source(1)).data!;
    await _restore(t, _board(empty: {'r1c0', 'r1c1'}));
    final before = _snap(t);
    old.onAcceptWithDetails!(
        DragTargetDetails(data: payload, offset: Offset.zero));
    t
            .widget<DragTarget<ArithmeticSquareDrag>>(_targets.first)
            .onAcceptWithDetails!(
        DragTargetDetails(data: payload, offset: Offset.zero));
    await t.pump();
    expect(_snap(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  for (final locale in [const Locale('en'), const Locale('de')]) {
    testWidgets(
        'doubled text phone supports actual win in ${locale.languageCode}',
        (t) async {
      final app = await _mount(t, scale: 2, locale: locale);
      t.view.physicalSize = const Size(390, 844);
      await t.pump();
      expect(t.takeException(), isNull);
      await _drag(t, 1);
      await _drag(t, 1);
      await t.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 1);
      expect(t.takeException(), isNull);
    });
  }
}
