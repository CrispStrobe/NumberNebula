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
import 'package:space_math_academy/features/games/screens/nebula_matrix_game.dart';
import 'package:space_math_academy/features/games/services/nebula_matrix_logic.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  final double textScale;
  _App({bool reduced = false, this.textScale = 1})
      : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
        ],
        child: MaterialApp(
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
          home: const NebulaMatrixGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(NebulaMatrixGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {int size = 3,
    List<String> empty = const ['r0c0', 'r0c1'],
    Map<String, int> answers = const {},
    int? moves}) {
  final solution = {
    for (var row = 0; row < size; row++)
      for (var col = 0; col < size; col++)
        'r${row}c$col':
            (col + (size == 6 ? row ~/ 2 + 3 * (row % 2) : row)) % size + 1
  };
  final zones = size == 6
      ? [
          for (var band = 0; band < 3; band++)
            for (var stack = 0; stack < 2; stack++)
              [
                for (var row = band * 2; row < band * 2 + 2; row++)
                  for (var col = stack * 3; col < stack * 3 + 3; col++)
                    'r${row}c$col'
              ]
        ]
      : <List<String>>[];
  final puzzle = NebulaMatrixPuzzle(
      size: size,
      solution: solution,
      clues: {
        for (final entry in solution.entries)
          if (!empty.contains(entry.key)) entry.key: entry.value
      },
      emptyCells: empty.toSet(),
      numberPool: List.generate(size, (index) => index + 1),
      zones: zones);
  return {
    'puzzle': puzzle.toJson(),
    'answers': Map.of(answers),
    'moves': moves ?? empty.length * 2,
    'maxMoves': empty.length * 2,
    'optimal': empty.length
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
    {bool reduced = false,
    double textScale = 1,
    Map<String, dynamic>? board}) async {
  final app = _App(reduced: reduced, textScale: textScale);
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

final _targets =
    find.byWidgetPredicate((widget) => widget is DragTarget<NebulaMatrixDrag>);
final _filled = find.byWidgetPredicate((widget) =>
    widget is GestureDetector &&
    widget.onTap != null &&
    (widget.child is Container || widget.child is ScaleTransition));
Finder _number(int value) => find.byWidgetPredicate((widget) =>
    widget is Draggable<NebulaMatrixDrag> && widget.data!.number == value);
DragTarget<NebulaMatrixDrag> _target(WidgetTester tester, [int index = 0]) =>
    tester.widget<DragTarget<NebulaMatrixDrag>>(_targets.at(index));
NebulaMatrixDrag _payload(WidgetTester tester, int value) =>
    tester.widget<Draggable<NebulaMatrixDrag>>(_number(value)).data!;
void _deliver(DragTarget<NebulaMatrixDrag> target, NebulaMatrixDrag data) =>
    target.onAcceptWithDetails!(
        DragTargetDetails<NebulaMatrixDrag>(data: data, offset: Offset.zero));
Future<void> _drag(WidgetTester tester, int value,
    [int targetIndex = 0]) async {
  await tester.drag(
      _number(value),
      tester.getCenter(_targets.at(targetIndex)) -
          tester.getCenter(_number(value)));
  await tester.pump();
}

void _grade(_App app, {int size = 3, int moves = 2, int optimal = 2}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125 + size * size * 10);
  expect(app.gp.lastOutcome!.movesUsed, moves);
  expect(app.gp.lastOutcome!.optimalMoves, optimal);
  expect(app.gp.lastOutcome!.performance, Perf.fromMoves(moves, optimal));
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
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  await tester.pump(const Duration(milliseconds: 300));
  final board = _snapshot(tester);
  expect(board['answers'], isEmpty);
  expect(board['moves'], board['maxMoves']);
  expect(board['maxMoves'], (board['optimal'] as int) * 2);
  expect(_dialog, findsNothing);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('nebula_matrix', 1, 1).then((value) {
    saved = value;
    complete = true;
  });
  // Storage callbacks share the widget test's fake clock. Keep advancing it
  // instead of awaiting a fake-zone future inside runAsync's real zone.
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
    final id = 'nebula_matrix_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_nebula_matrix': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'real drop consumes one move and removal is free; partial data persists',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 2);
    expect(_snapshot(tester)['answers'], {'r0c0': 2});
    expect(_snapshot(tester)['moves'], 3);
    await tester.pump(const Duration(milliseconds: 1000));
    var saved = await _stored(tester);
    expect(saved!['answers'], {'r0c0': 2});
    expect(saved['moves'], 3);
    await tester.tap(_filled.first);
    await tester.pump();
    expect(_snapshot(tester)['answers'], isEmpty);
    expect(_snapshot(tester)['moves'], 3);
    await _drag(tester, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    saved = await _stored(tester);
    expect(saved!['answers'], {'r0c0': 1});
    expect(saved['moves'], 2);
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['answers'], {'r0c0': 1});
    expect(_snapshot(tester)['moves'], 2);
    expect(app.gp.outcomeCount, 0);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'actual final correct drop wins once and retry resets doubled budget (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final oldTarget = _target(tester);
      final oldPayload = _payload(tester, 1);
      await _drag(tester, 1);
      final remove = tester.widget<GestureDetector>(_filled.first);
      await _drag(tester, 2);
      _deliver(oldTarget, oldPayload);
      remove.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      expect(await _stored(tester), isNull);
      await _retry(tester);
      _grade(app);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'full wrong final-budget drop loses once instead of bypassing exhaustion',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(answers: {'r0c0': 1}, moves: 1));
    final target = _target(tester);
    final data = _payload(tester, 1);
    await _drag(tester, 1);
    _deliver(target, data);
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(app.gp.lastOutcome!.performance, Perf.forLoss(progress: 1));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    await _retry(tester, loss: true);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('final-budget correct drop takes precedence over loss',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(answers: {'r0c0': 1}, moves: 1));
    await _drag(tester, 2);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, moves: 4);
    expect(_dialog, findsOneWidget);
  });

  testWidgets(
      'full incorrect positive-budget board remains editable then grades extra placements',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 1);
    await _drag(tester, 1);
    expect(_snapshot(tester)['moves'], 2);
    expect(_snapshot(tester)['answers'], {'r0c0': 1, 'r0c1': 1});
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    await tester.tap(_filled.at(1));
    await tester.pump();
    expect(_snapshot(tester)['moves'], 2);
    await _drag(tester, 2);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, moves: 3);
  });

  testWidgets(
      'invalid number and already filled target reject without spending moves',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final target = _target(tester);
    final data = _payload(tester, 1);
    for (final value in [0, 99]) {
      final invalid = (number: value, round: data.round);
      expect(
          target.onWillAcceptWithDetails!(DragTargetDetails<NebulaMatrixDrag>(
              data: invalid, offset: Offset.zero)),
          isFalse);
      _deliver(target, invalid);
    }
    expect(_snapshot(tester)['moves'], 4);
    expect(_snapshot(tester)['answers'], isEmpty);
    _deliver(target, data);
    await tester.pump();
    final before = _snapshot(tester);
    _deliver(target, _payload(tester, 2));
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'old target and old round payload cannot mutate current board or clue cell',
      (tester) async {
    final app = await _mount(tester);
    final target = _target(tester);
    final old = _payload(tester, 1);
    final back = tester.widget<GameUI>(find.byType(GameUI));
    await _restore(tester, app, _board(empty: ['r1c0', 'r1c1']));
    final before = _snapshot(tester);
    final current = _target(tester);
    final fresh = _payload(tester, 1);
    _deliver(target, fresh);
    _deliver(target, old);
    _deliver(current, old);
    back.onBack();
    expect(
        current.onWillAcceptWithDetails!(DragTargetDetails<NebulaMatrixDrag>(
            data: old, offset: Offset.zero)),
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
    await _drag(tester, 2);
    final old = tester.widget<GestureDetector>(_filled.first);
    await tester.tap(_filled.first);
    await tester.pump();
    await _drag(tester, 1);
    old.onTap!();
    await tester.pump();
    expect(_snapshot(tester)['answers'], {'r0c0': 1});
    expect(_snapshot(tester)['moves'], 2);
  });

  testWidgets('accepted active drag payload cannot land in replacement round',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final pointer = await tester.startGesture(tester.getCenter(_number(1)));
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
        reduced: true, board: _board(answers: {'r0c0': 2}, moves: 3));
    final pointer = await tester.startGesture(tester.getCenter(_filled.first));
    await _restore(tester, app, _board(answers: {'r0c0': 1}, moves: 3));
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
              answers: won ? {'r0c0': 1, 'r0c1': 2} : {'r0c0': 1},
              moves: won ? 2 : 0));
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
    await _drag(tester, 1);
    await _drag(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(_screen)).showSnackBar(const SnackBar(
        content: Text('obsolete matrix feedback'),
        duration: Duration(seconds: 20)));
    await _restore(tester, app, _board(answers: {'r0c0': 2}, moves: 3));
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
      'mid-drop reduction completes500ms effect without changing board or budget',
      (tester) async {
    final app = await _mount(tester);
    await _drag(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));
    final before = _snapshot(tester);
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    final scale = tester.widget<ScaleTransition>(find.descendant(
        of: _filled.first, matching: find.byType(ScaleTransition)));
    expect(scale.scale.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'mid-success reduction immediately completes visual before finite Material settling',
      (tester) async {
    final app =
        await _mount(tester, board: _board(answers: {'r0c0': 1}, moves: 3));
    await _drag(tester, 2);
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
        'closed matrix dialog buttons cannot navigate or retry (replace:$replace)',
        (tester) async {
      final app = await _mount(tester,
          reduced: true, board: _board(answers: {'r0c0': 1}, moves: 3));
      await _drag(tester, 2);
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
        reduced: true, board: _board(answers: {'r0c0': 1}, moves: 3));
    await _drag(tester, 2);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    retry.onPressed!();
    expect(_session(tester).capturePuzzleSession(), isNull);
    _session(tester).beginPuzzleSession();
    _session(tester)
        .applyPuzzleSession(_board(size: 6, answers: {'r0c0': 2}, moves: 3));
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
    final app =
        await _mount(tester, board: _board(answers: {'r0c0': 1}, moves: 3));
    final target = _target(tester);
    final data = _payload(tester, 2);
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

  for (final loss in [false, true]) {
    testWidgets(
        'six-zone phone board doubled text supports ${loss ? 'loss' : 'win'} and retry',
        (tester) async {
      final board = _board(size: 6, answers: {'r0c0': 1}, moves: loss ? 1 : 3);
      final app =
          await _mount(tester, reduced: true, textScale: 2, board: board);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_number(loss ? 1 : 2));
      await tester.pump();
      await _drag(tester, loss ? 1 : 2);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      expect(_dialog, findsOneWidget);
      if (loss) {
        expect(app.gp.outcomeCount, 1);
        expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
      } else {
        _grade(app, size: 6);
      }
      await _retry(tester, loss: loss);
      expect(tester.takeException(), isNull);
      expect(app.gp.outcomeCount, 1);
    });
  }
}
