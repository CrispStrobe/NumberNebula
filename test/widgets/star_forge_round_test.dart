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
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/star_forge_game.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
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
  final double textScale;
  final Locale? locale;
  _App({bool reduced = false, this.textScale = 1, this.locale})
      : motion = ValueNotifier(reduced);

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
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
          home: const StarForgeGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(StarForgeGame);
final _dialog = roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

StarForgePuzzle _testPuzzle(
    {int points = 5, Set<int> emptyNodes = const {7, 8}}) {
  // Fixed solved layout for 5-point star: tips 1,9,3,7,5 + inner 10,2,8,4,6
  const tips = [1, 9, 3, 7, 5];
  const inner = [10, 2, 8, 4, 6]; // ignore: prefer_const_declarations
  final solution = <int, int>{};
  for (int i = 0; i < 5; i++) {
    solution[i] = tips[i];
    solution[5 + i] = inner[i];
  }
  // Lines as in StarForgeGenerator._buildStarLines
  List<List<int>> lines = [];
  for (int i = 0; i < points; i++) {
    lines.add([i, points + i, points + (i + 1) % points, (i + 1) % points]);
  }
  const magicConstant = 22; // 2*(2*5+1)
  final nodeCount = points * 2;
  final clues = <int, int>{};
  for (int i = 0; i < nodeCount; i++) {
    if (!emptyNodes.contains(i)) {
      clues[i] = solution[i]!;
    }
  }
  final clueValues = clues.values.toSet();
  final numberPool = List<int>.generate(nodeCount, (i) => i + 1)
      .where((v) => !clueValues.contains(v))
      .toList()
    ..sort();
  return StarForgePuzzle(
    points: points,
    nodeCount: nodeCount,
    lines: lines,
    magicConstant: magicConstant,
    solution: solution,
    clues: clues,
    emptyNodes: emptyNodes,
    numberPool: numberPool,
  );
}

Map<String, dynamic> _board({
  int points = 5,
  Set<int> empty = const {7, 8},
  Map<int, int> answers = const {},
  int? movesRemaining,
  int? maxMoves,
  int? optimal,
  int hintsUsed = 0,
}) {
  final puzzle = _testPuzzle(points: points, emptyNodes: empty);
  final emptyCount = empty.length;
  final opt = optimal ?? emptyCount;
  final max = maxMoves ?? emptyCount * 2;
  final moves = movesRemaining ?? max;
  return {
    'puzzle': puzzle.toJson(),
    'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
    'moves': moves,
    'maxMoves': max,
    'optimal': opt,
    'hints': hintsUsed,
  };
}

Future<void> _restore(
    WidgetTester tester, _App app, Map<String, dynamic> board) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  await tester.pump();
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester,
    {bool reduced = false,
    double textScale = 1,
    Locale? locale,
    Map<String, dynamic>? board}) async {
  final app = _App(reduced: reduced, textScale: textScale, locale: locale);
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
  await _restore(tester, app, board ?? _board());
  return app;
}

final _targets =
    find.byWidgetPredicate((widget) => widget is DragTarget<StarForgeDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<StarForgeDrag> && w.data!.number == n);
DragTarget<StarForgeDrag> _target(WidgetTester tester, [int index = 0]) =>
    tester.widget<DragTarget<StarForgeDrag>>(_targets.at(index));
StarForgeDrag _payload(WidgetTester tester, int n) =>
    tester.widget<Draggable<StarForgeDrag>>(_draggable(n)).data!;
void _deliver(DragTarget<StarForgeDrag> target, StarForgeDrag data) =>
    target.onAcceptWithDetails!(
        DragTargetDetails<StarForgeDrag>(data: data, offset: Offset.zero));
Future<void> _drag(WidgetTester tester, int value,
    [int targetIndex = 0]) async {
  await tester.drag(
      _draggable(value),
      tester.getCenter(_targets.at(targetIndex)) -
          tester.getCenter(_draggable(value)));
  await tester.pump();
}

final _filled = find.byWidgetPredicate((widget) =>
    widget is GestureDetector &&
    widget.key is ValueKey &&
    (widget.key as ValueKey).value.toString().contains('star-filled'));

void _grade(_App app, {int moves = 2, int optimal = 2}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125);
  expect(app.gp.lastOutcome!.movesUsed, moves);
  expect(app.gp.lastOutcome!.optimalMoves, optimal);
  expect(app.gp.lastOutcome!.performance,
      Perf.penalize(Perf.fromMoves(moves, optimal), hints: 0));
}

Future<void> _retry(WidgetTester tester, {bool loss = false}) async {
  final button = find.widgetWithText(ElevatedButton,
      loss ? _strings(tester).tryAgain : _strings(tester).playAgain);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
  final board = _snapshot(tester);
  expect(board['answers'], isEmpty);
  expect(board['moves'], board['maxMoves']);
  expect(_dialog, findsNothing);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('star_forge', 1, 1).then((value) {
    saved = value;
    complete = true;
  });
  for (var frame = 0; frame < 100 && !complete; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(complete, isTrue,
      reason: 'Session read must finish within 100 frames');
  return saved;
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'star_forge_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_star_forge_guided_v1': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'real drop consumes one move and removal is free; partial data persists',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 8);
    expect(_snapshot(tester)['answers'], containsPair('7', 8));
    expect(_snapshot(tester)['moves'], 3);
    await tester.pump(const Duration(milliseconds: 1000));
    var saved = await _stored(tester);
    expect(saved!['answers'], containsPair('7', 8));
    expect(saved['moves'], 3);
    await tester.tap(_filled.first);
    await tester.pump();
    expect(_snapshot(tester)['answers'], isEmpty);
    expect(_snapshot(tester)['moves'], 3);
    await _drag(tester, 4);
    await tester.pump(const Duration(milliseconds: 1000));
    saved = await _stored(tester);
    expect(saved!['answers'], containsPair('7', 4));
    expect(saved['moves'], 2);
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['answers'], containsPair('7', 4));
    expect(_snapshot(tester)['moves'], 2);
    expect(app.gp.outcomeCount, 0);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'actual final correct drop wins once and retry resets doubled budget (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final oldTarget = _target(tester);
      final oldPayload = _payload(tester, 8);
      await _drag(tester, 8);
      final remove = tester.widget<GestureDetector>(_filled.first);
      await _drag(tester, 4);
      _deliver(oldTarget, oldPayload);
      remove.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app, moves: 2, optimal: 2);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      expect(await _stored(tester), isNull);
      await _retry(tester);
      _grade(app, moves: 2, optimal: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full wrong last-budget drop loses once and offers retry',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(answers: {7: 4}, movesRemaining: 1));
    await _drag(tester, 8);
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    await _retry(tester, loss: true);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets(
      'full incorrect at zero remaining with empty still triggers outOfMoves loss',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(empty: {7, 8, 3}, answers: {7: 8}, movesRemaining: 1));
    await _drag(tester,
        4); // fill second slot, but still one empty left and moves become 0 -> should outOfMoves
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    await _retry(tester, loss: true);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets(
      'old target and old round payload cannot mutate current board or clue cell',
      (tester) async {
    final app = await _mount(tester);
    final target = _target(tester);
    final old = _payload(tester, 8);
    final back = tester.widget<GameUI>(find.byType(GameUI));
    await _restore(
        tester, app, _board(empty: {3, 7}, answers: {}, movesRemaining: 4));
    final before = _snapshot(tester);
    final current = _target(tester);
    final fresh = _payload(tester, 7);
    _deliver(target, fresh);
    _deliver(target, old);
    _deliver(current, old);
    back.onBack();
    expect(
        current.onWillAcceptWithDetails!(
            DragTargetDetails<StarForgeDrag>(data: old, offset: Offset.zero)),
        isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_screen, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'old same-round filled callback cannot remove different new value',
      (tester) async {
    await _mount(tester, reduced: true);
    await _drag(tester, 8);
    final old = tester.widget<GestureDetector>(_filled.first);
    await tester.tap(_filled.first);
    await tester.pump();
    await _drag(tester, 4);
    old.onTap!();
    await tester.pump();
    expect(_snapshot(tester)['answers'], containsPair('7', 4));
    expect(_snapshot(tester)['moves'], 2);
  });

  testWidgets('accepted active drag payload cannot land in replacement round',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final pointer = await tester.startGesture(tester.getCenter(_draggable(8)));
    await pointer.moveBy(const Offset(0, -30));
    await tester.pump();
    await _restore(tester, app, _board());
    final before = _snapshot(tester);
    await pointer.moveTo(tester.getCenter(_targets.first));
    await tester.pump();
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active filled-cell finger cannot remove restored same-geometry value',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(answers: {7: 8}, movesRemaining: 3));
    final pointer = await tester.startGesture(tester.getCenter(_filled.first));
    await _restore(tester, app, _board(answers: {7: 4}, movesRemaining: 3));
    final before = _snapshot(tester);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final won in [false, true]) {
    testWidgets(
        'older ${won ? 'full correct' : 'exhausted'} snapshot offers retry without outcome replay',
        (tester) async {
      final app = await _mount(tester,
          reduced: true,
          board: _board(
              empty: const {7, 8},
              answers: won ? {7: 8, 8: 4} : {7: 8},
              movesRemaining: won ? 2 : 0));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 0);
      await _retry(tester, loss: !won);
      expect(app.gp.outcomeCount, 0);
    });
  }

  testWidgets('restore clears pending incorrect feedback and last-drop visuals',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 4);
    await _drag(tester, 8);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(_screen)).showSnackBar(const SnackBar(
        content: Text('obsolete star feedback'),
        duration: Duration(seconds: 20)));
    await _restore(tester, app, _board(answers: {7: 8}, movesRemaining: 3));
    final before = _snapshot(tester);
    expect(
        find.descendant(
            of: _filled.first, matching: find.byType(ScaleTransition)),
        findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SnackBar), findsNothing);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'mid-drop reduction completes 500ms effect without changing board or budget',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 8);
    await tester.pump(const Duration(milliseconds: 100));
    final before = _snapshot(tester);
    final scaleFinder = find.descendant(
        of: _filled.first, matching: find.byType(ScaleTransition));
    final scale = tester.widget<ScaleTransition>(scaleFinder);
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    expect(scaleFinder, findsNothing);
    expect(scale.scale.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'mid-success reduction immediately completes visual before finite Material settling',
      (tester) async {
    final app = await _mount(tester,
        board: _board(empty: const {7, 8}, answers: {7: 8}, movesRemaining: 3));
    await _drag(tester, 4);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    final AnimationController success = _session(tester).successController;
    expect(success.isAnimating, isFalse);
    expect(success.value, 1);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(_dialog, findsOneWidget);
    _grade(app);
  });

  for (final replace in [false, true]) {
    testWidgets(
        'closed star dialog buttons cannot navigate or retry (replace:$replace)',
        (tester) async {
      final app = await _mount(tester,
          reduced: true,
          board:
              _board(empty: const {7, 8}, answers: {7: 8}, movesRemaining: 3));
      await _drag(tester, 4);
      await tester.pump(const Duration(milliseconds: 700));
      final retry = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      final exit = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
      Navigator.of(tester.element(_screen)).pop();
      await tester.pump();
      Map<String, dynamic>? before;
      if (replace) {
        await _restore(tester, app, _board());
        before = _snapshot(tester);
      }
      retry.onPressed!();
      exit.onPressed!();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_screen, findsOneWidget);
      expect(_dialog, findsNothing);
      if (replace) {
        expect(_snapshot(tester), before);
      } else {
        expect(_session(tester).capturePuzzleSession(), isNull);
      }
      _grade(app);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry generation cannot overwrite synchronous restore',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(empty: const {7, 8}, answers: {7: 8}, movesRemaining: 3));
    await _drag(tester, 4);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    retry.onPressed!();
    expect(_session(tester).capturePuzzleSession(), isNull);
    _session(tester).beginPuzzleSession();
    _session(tester).applyPuzzleSession(
        _board(empty: const {7, 8}, answers: {7: 2}, movesRemaining: 3));
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    final before = _snapshot(tester);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_snapshot(tester), before);
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal rejects retained drag payload target removal and back',
      (tester) async {
    final app = await _mount(tester,
        board: _board(empty: const {7, 8}, answers: {7: 8}, movesRemaining: 3));
    final target = _target(tester);
    final data = _payload(tester, 4);
    final remove = tester.widget<GestureDetector>(_filled.first);
    final header = tester.widget<GameUI>(find.byType(GameUI));
    await tester.pumpWidget(const SizedBox.shrink());
    _deliver(target, data);
    remove.onTap!();
    header.onBack();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'de']) {
    testWidgets(
        'five-point phone doubled text supports real win and retry in $language',
        (tester) async {
      final app = await _mount(tester,
          reduced: true, textScale: 2, locale: Locale(language));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_draggable(8));
      await tester.pump();
      await _drag(tester, 8);
      await _drag(tester, 4);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      expect(_dialog, findsOneWidget);
      _grade(app);
      await _retry(tester);
      _grade(app);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'short viewport scrolls star board while preserving minimum hit boxes',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, textScale: 2, locale: const Locale('en'));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 500);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final target = _targets.first;
    await tester.ensureVisible(target);
    await tester.pump();
    await _drag(tester, 8);
    expect(_snapshot(tester)['answers'], containsPair('7', 8));
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });
  for (final win in [false, true]) {
    testWidgets('partial restore clears prior terminal flags (win:$win)',
        (tester) async {
      final app = await _mount(tester,
          reduced: true,
          board: win
              ? _board(answers: {7: 8}, movesRemaining: 1)
              : _board(movesRemaining: 1));
      await _drag(tester, win ? 4 : 8);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      Navigator.of(tester.element(_screen)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _restore(tester, app, _board());
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      await _drag(tester, 8);
      expect(_snapshot(tester)['answers'], containsPair('7', 8));
      expect(app.gp.outcomeCount, 1);
    });
  }
}
