import 'support/round_contract_checks.dart';
import 'support/round_dialog_finder.dart';
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
import 'package:space_math_academy/features/games/models/performance.dart'; // ignore: unused_import
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/arithmancer_crosswords_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({bool reduced = false}) : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider<DebugProvider>.value(value: debug),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: motion,
            builder: (_, reduced, __) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
          home: const ArithmancerCrosswordsGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(ArithmancerCrosswordsGame);
Finder get _dialog => roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Future<void> _restoreFromSessionPuzzle(WidgetTester tester) async {
  final dynamic session = _session(tester);
  final puzzle = session.puzzle;
  if (puzzle == null) {
    return;
  }
  final Set emptyCells = puzzle.emptyCells as Set;
  final correctNumbers = <int>{};
  for (final cellId in emptyCells) {
    correctNumbers.add((puzzle.fullSolution as Map)[cellId] as int);
  }
  final List pool = puzzle.numberPool as List;
  final decoyNumbers = pool.where((n) => !correctNumbers.contains(n)).toSet();
  final board = {
    'puzzle': puzzle.toJson(),
    'userSolution': <List>[],
    'numberPool': List<int>.from(pool as List<int>),
    'correctNumbers': correctNumbers.toList(),
    'decoyNumbers': decoyNumbers.toList(),
    '_movesRemaining': emptyCells.length * 2,
    '_maxMoves': emptyCells.length * 2,
    '_optimalMoves': emptyCells.length,
  };
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  await tester.pump();
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester, {bool reduced = false}) async {
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
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restoreFromSessionPuzzle(tester);
  return app;
}

final _targets =
    find.byWidgetPredicate((w) => w is DragTarget<ArithmancerCrosswordsDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<ArithmancerCrosswordsDrag> && w.data!.number == n);
DragTarget<ArithmancerCrosswordsDrag> _target(WidgetTester tester,
        [int idx = 0]) =>
    tester.widget<DragTarget<ArithmancerCrosswordsDrag>>(_targets.at(idx));
ArithmancerCrosswordsDrag _payload(WidgetTester tester, int n) {
  final list = tester
      .widgetList<Draggable<ArithmancerCrosswordsDrag>>(_draggable(n))
      .toList();
  expect(list, isNotEmpty, reason: 'No draggable for $n');
  return list.first.data!;
}

void _deliver(
        DragTarget<ArithmancerCrosswordsDrag> t, ArithmancerCrosswordsDrag d) =>
    t.onAcceptWithDetails!(DragTargetDetails<ArithmancerCrosswordsDrag>(
        data: d, offset: Offset.zero));
Future<void> _drag(WidgetTester tester, int value, [int targetIdx = 0]) async {
  // ignore: unused_element
  final draggableFinder = _draggable(value);
  // If multiple draggables share the same number (duplicate pool entries),
  // pick the first one to avoid \"Too many elements\".
  final src = draggableFinder.at(0);
  await tester.drag(
      src, tester.getCenter(_targets.at(targetIdx)) - tester.getCenter(src));
  await tester.pump();
}

void main() {
  registerGridRoundChecks(
    mount: (t, reduced) async {
      final app = await _mount(t, reduced: reduced);
      return (gp: app.gp, motion: app.motion);
    },
    state: _session,
    snapshot: _snapshot,
    solution: (s) => {
      for (final cell in (s.puzzle.emptyCells as Set).toList()..sort())
        cell as Object: (s.puzzle.fullSolution as Map)[cell] as int
    },
    valid: (s, answers) => s.puzzle.validateSolution(
        {for (final e in answers.entries) e.key as String: e.value}),
    place: (s, cell, value) =>
        s.placeForTesting(value, cell as String, s.testRound),
    answersKey: 'userSolution',
    movesKey: '_movesRemaining',
    poolKey: 'numberPool',
    maxMovesKey: '_maxMoves',
    optimalKey: '_optimalMoves',
    shape: 'entries',
    reusable: false,
    boardDrop: false,
  );

  testWidgets('back press from a replaced round cannot navigate',
      (tester) async {
    await _mount(tester);
    final back = find.byIcon(Icons.arrow_back_ios);
    expect(back, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(back));
    final dynamic session = _session(tester);
    final before = _snapshot(tester);
    session.beginPuzzleSession();
    session.applyPuzzleSession(before);
    session.rebuildForTesting();
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_screen, findsOneWidget);
    expect(_snapshot(tester), before);
    expect(tester.takeException(), isNull);
  });
  var profile = 0;
  setUp(() {
    final id = 'crosswords_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_arithmancer_crosswords': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('real drop consumes one move', (tester) async {
    await _mount(tester, reduced: true);
    final dynamic sess = _session(tester);
    final puzzle = sess.puzzle;
    expect(puzzle, isNotNull);
    final Set emptyCells = puzzle.emptyCells as Set;
    final String cellId = emptyCells.first as String;
    final int correctNumber = (puzzle.fullSolution as Map)[cellId] as int;
    expect((puzzle.numberPool as List).contains(correctNumber), isTrue);
    await _drag(tester, correctNumber);
    await tester.pump();
    final sol = _snapshot(tester)['userSolution'] as List;
    expect(sol.any((e) => (e as List)[0] == cellId && e[1] == correctNumber),
        isTrue);
  });

  testWidgets('old payload cannot mutate new board after restore',
      (tester) async {
    final app = await _mount(tester);
    final snapBefore = _snapshot(tester);
    final List poolBefore = snapBefore['numberPool'] as List;
    final int poolNumber = poolBefore.first as int;
    final oldTarget = _target(tester);
    final oldPayload = _payload(tester, poolNumber);
    await _restoreFromSessionPuzzle(tester);
    final before = _snapshot(tester);
    expect(before, isNotNull);
    final newTarget = _target(tester);
    _deliver(oldTarget, oldPayload);
    _deliver(newTarget, oldPayload);
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(poolBefore.contains(poolNumber), isTrue);
  });

  testWidgets('correct final drops win once and show dialog', (tester) async {
    final app = await _mount(tester, reduced: true);
    dynamic sess0 = _session(tester);
    final puzzle = sess0.puzzle;
    expect(puzzle, isNotNull);
    final Set emptyCells = puzzle.emptyCells as Set;
    // Data-driven: solve each empty cell with fullSolution value (must be in numberPool)
    for (final cellId in emptyCells) {
      final int v = (puzzle.fullSolution as Map)[cellId] as int;
      expect((puzzle.numberPool as List).contains(v), isTrue);
      dynamic sess = _session(tester);
      final round = sess.testRound as Object;
      sess.placeForTesting(v, cellId as String, round);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
  });
}
