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
import 'package:space_math_academy/features/games/screens/magic_triangles_game.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/features/games/services/magic_triangle_puzzle.dart';

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
          home: const MagicTrianglesGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(MagicTrianglesGame);
Finder get _dialog => roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Future<void> _restoreFromSessionPuzzle(WidgetTester tester) async {
  final dynamic session = _session(tester);
  const solved = [1, 4, 5, 2, 3, 6];
  final puzzle = MagicTrianglePuzzle(
    circlesPerSide: 3,
    warpFrequency: 10,
    hiddenIndices: {0, 2},
    visibleValues: {1: 4, 3: 2, 4: 3, 5: 6},
    allNumbers: solved,
    numberPool: [1, 5, 7, 8],
  );
  expect(puzzle.checkSolution([1, 5]).isPerfect, isTrue);
  final board = {
    'currentPuzzle': puzzle.toJson(),
    'userAnswers': [null, null],
    'numberPool': [1, 5, 7, 8],
    '_movesRemaining': 4,
    '_maxMoves': 4,
    '_optimalMoves': 2,
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
    find.byWidgetPredicate((w) => w is DragTarget<MagicTrianglesDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<MagicTrianglesDrag> && w.data!.number == n);
DragTarget<MagicTrianglesDrag> _target(WidgetTester tester, [int idx = 0]) =>
    tester.widget<DragTarget<MagicTrianglesDrag>>(_targets.at(idx));
MagicTrianglesDrag _payload(WidgetTester tester, int n) =>
    tester.widget<Draggable<MagicTrianglesDrag>>(_draggable(n).first).data!;
void _deliver(DragTarget<MagicTrianglesDrag> t, MagicTrianglesDrag d) =>
    t.onAcceptWithDetails!(
        DragTargetDetails<MagicTrianglesDrag>(data: d, offset: Offset.zero));
Future<void> _drag(WidgetTester tester, int value, [int targetIdx = 0]) async {
  final source = _draggable(value).first;
  final node = find.byWidgetPredicate((w) =>
      w is Semantics &&
      (w.properties.label ?? '').startsWith('Empty triangle node'));
  final target = node.at(targetIdx);
  await tester.ensureVisible(source);
  await tester.ensureVisible(target);
  await tester.pump();
  // The board receives the feedback's top-left position, as in victory tests.
  await tester.drag(
      source, tester.getCenter(target) - tester.getTopLeft(source));
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
      for (final cell
          in (s.currentPuzzle.hiddenIndices as Set).toList()..sort())
        cell as Object: (s.currentPuzzle.allNumbers as List)[cell as int] as int
    },
    valid: (s, answers) =>
        s.currentPuzzle.checkSolution(answers.values.toList()).isValid,
    place: (s, cell, value) => s.placeForTesting(value,
        s.currentPuzzle.getAnswerIndex(cell as int), cell as int, s.testRound),
    answersKey: 'userAnswers',
    movesKey: '_movesRemaining',
    poolKey: 'numberPool',
    maxMovesKey: '_maxMoves',
    optimalKey: '_optimalMoves',
    shape: 'list',
    reusable: false,
    boardDrop: true,
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
    final id = 'magic_triangles_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_magic_triangles': true});
    PuzzleSessionStore.resetForTesting();
  });

  for (final corners in [true, false]) {
    testWidgets(
        'real drop on ${corners ? "corner" : "midpoint"} nodes consumes one move',
        (tester) async {
      final app = await _mount(tester, reduced: true);
      const solution = [1, 4, 5, 2, 3, 6];
      final hidden = corners ? <int>{0, 2} : <int>{1, 5};
      final answers = [for (final i in hidden) solution[i]];
      final pool = [...answers, 7, 8];
      final puzzle = MagicTrianglePuzzle(
          circlesPerSide: 3,
          warpFrequency: 10,
          hiddenIndices: hidden,
          visibleValues: {
            for (var i = 0; i < solution.length; i++)
              if (!hidden.contains(i)) i: solution[i]
          },
          allNumbers: solution,
          numberPool: pool);
      expect(puzzle.checkSolution(answers).isPerfect, isTrue);
      final dynamic session = _session(tester);
      session.beginPuzzleSession();
      session.applyPuzzleSession({
        'currentPuzzle': puzzle.toJson(),
        'userAnswers': [null, null],
        'numberPool': pool,
        '_movesRemaining': 4,
        '_maxMoves': 4,
        '_optimalMoves': 2,
      });
      session.rebuildForTesting();
      await tester.pump();
      await _drag(tester, answers.first);
      final snap = _snapshot(tester);
      expect(snap['userAnswers'], [answers.first, null]);
      expect(snap['_movesRemaining'], 3);
      expect(snap['numberPool'], unorderedEquals(pool.skip(1)));
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('old payload cannot mutate new board after restore',
      (tester) async {
    final app = await _mount(tester);
    final snapBefore = _snapshot(tester);
    final List<int> poolBefore =
        List<int>.from(snapBefore['numberPool'] as List);
    final int poolNumber = poolBefore.first;
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
}
