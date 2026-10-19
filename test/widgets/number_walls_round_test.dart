import 'package:space_math_academy/features/games/widgets/strategy_hint_dialog.dart';
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
import 'package:space_math_academy/features/games/screens/number_walls_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final Locale? locale;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({bool reduced = false, this.locale}) : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider<DebugProvider>.value(value: debug),
        ],
        child: MaterialApp(
          locale: locale,
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
          home: const NumberWallsGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(NumberWallsGame);
Finder get _dialog => roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Future<void> _restoreFromSessionPuzzle(WidgetTester tester) async {
  final dynamic session = _session(tester);
  final puzzle = session.currentPuzzle;
  if (puzzle == null) {
    return;
  }
  final board = {
    'puzzle': puzzle.toJson(),
    'answers': List.filled((puzzle.hiddenCells as Set).length, null),
    'moves': (puzzle.hiddenCells as Set).length * 2,
    'maxMoves': (puzzle.hiddenCells as Set).length * 2,
    'optimal': (puzzle.hiddenCells as Set).length,
    'hints': 0,
    'pool': List<int>.from(puzzle.numberPool as List),
  };
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  await tester.pump();
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester,
    {bool reduced = false, Locale? locale}) async {
  final app = _App(reduced: reduced, locale: locale);
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
    find.byWidgetPredicate((w) => w is DragTarget<NumberWallsDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<NumberWallsDrag> && w.data!.number == n);
DragTarget<NumberWallsDrag> _target(WidgetTester tester, [int idx = 0]) =>
    tester.widget<DragTarget<NumberWallsDrag>>(_targets.at(idx));
NumberWallsDrag _payload(WidgetTester tester, int n) =>
    tester.widget<Draggable<NumberWallsDrag>>(_draggable(n).first).data!;
void _deliver(DragTarget<NumberWallsDrag> t, NumberWallsDrag d) =>
    t.onAcceptWithDetails!(
        DragTargetDetails<NumberWallsDrag>(data: d, offset: Offset.zero));

Future<StrategyHintDialog> _openWorkedHint(WidgetTester tester) async {
  final strings = S.of(tester.element(_screen))!;
  await tester.tap(find.byIcon(Icons.lightbulb_outline));
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (find.byType(StrategyHintDialog).evaluate().isNotEmpty) {
      break;
    }
  }
  expect(find.byType(StrategyHintDialog), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 300));
  final hint =
      tester.widget<StrategyHintDialog>(find.byType(StrategyHintDialog));
  expect(find.text(hint.focus), findsOneWidget);
  await tester.tap(find.text(strings.onboardingNext));
  await tester.pump();
  expect(find.text(hint.strategy), findsOneWidget);
  await tester.tap(find.text(strings.onboardingNext));
  await tester.pump();
  expect(find.text(hint.working), findsOneWidget);
  return hint;
}

void main() {
  for (final lang in ['en', 'de']) {
    testWidgets(
        'in-screen hint explains current rules and guards restored rounds in $lang',
        (tester) async {
      final app = await _mount(tester, reduced: true, locale: Locale(lang));
      final puzzle = NumberWallPuzzle(
          wallHeight: 3,
          operation: WallOperation.addition,
          hiddenCells: {1, 2},
          visibleValues: {0: 13, 3: 3, 4: 4, 5: 2},
          fullSolution: [13, 7, 6, 3, 4, 2],
          numberPool: [6, 7]);
      final board = <String, dynamic>{
        'puzzle': puzzle.toJson(),
        'answers': [null, null],
        'moves': 4,
        'maxMoves': 4,
        'optimal': 2,
        'hints': 0,
        'pool': [6, 7]
      };
      final dynamic session = _session(tester);
      session.beginPuzzleSession();
      session.applyPuzzleSession(board);
      session.rebuildForTesting();
      await tester.pump();
      await tester.pump();
      final hint = await _openWorkedHint(tester);
      expect(
          hint.strategy,
          contains(lang == 'de'
              ? 'seine beiden Nachbarn direkt darunter'
              : 'its two neighbours directly below'));
      expect(hint.working, contains('[7] = 3 + 4'));
      expect(hint.demonstrate, isNotNull);
      final strings = S.of(tester.element(_screen))!;
      await tester.tap(find.text(strings.hintPlaceMove));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(StrategyHintDialog), findsNothing);
      expect(_snapshot(tester)['answers'], [7, null]);
      expect(
          puzzle.validateSolution(
              [(_snapshot(tester)['answers'] as List).first as int, 6]),
          isTrue);
      expect(_snapshot(tester)['moves'], 3);
      expect(_snapshot(tester)['hints'], 1);
      expect(app.gp.outcomeCount, 0);

      // This callback is the real second dialog's production demonstration.
      // Close its route normally, restore, then replay the obsolete callback.
      final oldHint = await _openWorkedHint(tester);
      final obsoleteMove = oldHint.demonstrate;
      expect(obsoleteMove, isNotNull);
      await tester.tap(find.text(strings.hintTryMyself));
      await tester.pump(const Duration(milliseconds: 300));
      session.beginPuzzleSession();
      session.applyPuzzleSession(board);
      session.rebuildForTesting();
      await tester.pump();
      await tester.pump();
      final before = _snapshot(tester);
      obsoleteMove!();
      await tester.pump();
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  registerGridRoundChecks(
    mount: (t, reduced) async {
      final app = await _mount(t, reduced: reduced);
      return (gp: app.gp, motion: app.motion);
    },
    state: _session,
    snapshot: _snapshot,
    solution: (s) => {
      for (final cell in (s.currentPuzzle.hiddenCells as Set).toList()..sort())
        cell as Object:
            (s.currentPuzzle.fullSolution as List)[cell as int] as int
    },
    valid: (s, answers) =>
        s.currentPuzzle.validateSolution(answers.values.toList()),
    place: (s, cell, value) =>
        s.placeForTesting(value, cell as int, s.testRound),
    answersKey: 'answers',
    movesKey: 'moves',
    poolKey: 'pool',
    maxMovesKey: 'maxMoves',
    optimalKey: 'optimal',
    shape: 'list',
    reusable: false,
    boardDrop: true,
  );

  testWidgets('back press from a replaced round cannot navigate',
      (tester) async {
    await _mount(tester);
    final back = find.byIcon(Icons.arrow_back);
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
    final id = 'number_walls_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues({
      'player_${id}_onboarding_seen_number_walls': true,
      'player_${id}_onboarding_seen_number_walls_guided_v1': true,
    });
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('real drop consumes one move', (tester) async {
    await _mount(tester, reduced: true);
    final dynamic sess = _session(tester);
    final puzzle = sess.currentPuzzle;
    expect(puzzle, isNotNull);
    final List<int> pool = List<int>.from(puzzle.numberPool as List);
    expect(pool, isNotEmpty);
    final Set hiddenCells = puzzle.hiddenCells as Set;
    final List sortedHidden = hiddenCells.toList()..sort();
    final int cellIdx = sortedHidden.first as int;
    final List fullSolution = puzzle.fullSolution as List;
    final int correctValue = fullSolution[cellIdx] as int;
    expect(pool.contains(correctValue), isTrue);
    final round = sess.testRound as Object;
    sess.placeForTesting(correctValue, cellIdx, round);
    await tester.pump();
    final snap = _snapshot(tester);
    expect((snap['answers'] as List).where((e) => e != null).length, 1);
  });

  testWidgets('old payload cannot mutate new board after restore',
      (tester) async {
    final app = await _mount(tester);
    final snapBefore = _snapshot(tester);
    final List<int> poolBefore = List<int>.from(snapBefore['pool'] as List);
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

  testWidgets('correct final drops win once and show dialog', (tester) async {
    final app = await _mount(tester, reduced: true);
    dynamic sess = _session(tester);
    final puzzle = sess.currentPuzzle;
    expect(puzzle, isNotNull);
    // Data-driven: use puzzle.numberPool to determine hiddenCells' correct answers.
    // NumberWalls hiddenCells are indices; fullSolution is per-cell value array.
    final List<int> pool = List<int>.from(puzzle.numberPool as List);
    final Set hiddenCells = puzzle.hiddenCells as Set;
    final List fullSolution = puzzle.fullSolution as List;
    // hiddenCells sorted -> answerIndex mapping
    final sortedHidden = hiddenCells.toList()..sort();
    for (int ansIdx = 0; ansIdx < sortedHidden.length; ansIdx++) {
      final int cellIdx = sortedHidden[ansIdx] as int;
      final int correctValue = fullSolution[cellIdx] as int;
      // Data-driven: correctValue must be in numberPool
      expect(pool.contains(correctValue), isTrue,
          reason: 'correct $correctValue should be in pool $pool');
      sess = _session(tester);
      final round = sess.testRound as Object;
      sess.placeForTesting(correctValue, cellIdx, round);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
  });
}
