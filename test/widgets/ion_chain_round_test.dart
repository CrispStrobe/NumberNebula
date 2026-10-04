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
import 'package:space_math_academy/features/games/screens/ion_chain_game.dart';
import 'package:space_math_academy/features/games/services/ion_chain_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({bool reduced = false}) : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
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
          home: const IonChainGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(IonChainGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
        {int mistakes = 0,
        List<String?> chain = const ['red', null, 'red', null],
        List<String?>? player,
        List<String> supply = const ['blue', 'green'],
        List<String> solution = const ['red', 'blue', 'red', 'green']}) =>
    {
      'puzzle': {
        'chainLength': chain.length,
        'chain': chain,
        'solution': solution,
        'availableIons': supply,
        'rules': [
          {'kind': 'noRepeatAtAll', 'a': null, 'b': null}
        ],
        'ionTypes': ['red', 'blue', 'green'],
      },
      '_playerChain': player ?? chain,
      '_ruleViolations': mistakes,
    };

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
    {bool reduced = false, Map<String, dynamic>? board}) async {
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
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  return app;
}

final _ring = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.child is Stack);
final _targets = find.byWidgetPredicate((widget) => widget is DragTarget);
Finder _tray(IonType type) {
  final icon = switch (type) {
    IonType.red => Icons.star,
    IonType.blue => Icons.circle,
    IonType.green => Icons.hexagon,
    IonType.yellow => Icons.diamond,
    IonType.purple => Icons.change_history,
  };
  return find
      .ancestor(
          of: find.byIcon(icon),
          matching: find.byWidgetPredicate((widget) => widget is Draggable))
      .first;
}

final _placed = find.descendant(
    of: _ring,
    matching: find.byWidgetPredicate((widget) => widget is GestureDetector));
Future<void> _drop(WidgetTester tester, IonType type, {int target = 0}) async {
  final destination = tester.getCenter(_targets.at(target));
  await tester.drag(_tray(type), destination - tester.getCenter(_tray(type)));
  await tester.pump();
}

Future<TestGesture> _startDrag(WidgetTester tester, IonType type) async {
  final gesture = await tester.startGesture(tester.getCenter(_tray(type)));
  await gesture.moveBy(const Offset(30, -30));
  await tester.pump();
  return gesture;
}

void _grade(_App app, {int mistakes = 0}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125);
  expect(
      app.gp.lastOutcome!.performance, Perf.fromMistakes(mistakes, per: .15));
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'ion_chain_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_ion_chain': true});
    PuzzleSessionStore.resetForTesting();
  });
  for (final reduced in [false, true]) {
    testWidgets(
        'real drops win once and retry starts a saveable round (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(mistakes: 2));
      await _drop(tester, IonType.blue);
      final removal = tester.widget<GestureDetector>(_placed.first);
      expect(_snapshot(tester)['_playerChain'], ['red', 'blue', 'red', null]);
      expect(app.gp.outcomeCount, 0);
      await _drop(tester, IonType.green);
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app, mistakes: 2);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      removal.onTap!();
      await tester.pump();
      _grade(app, mistakes: 2);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      final state = _snapshot(tester);
      expect(state['_ruleViolations'], 0);
      expect(state['_playerChain'], (state['puzzle'] as Map)['chain']);
    });

    testWidgets(
        'active old drag cannot paint restored same-size board (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final gesture = await _startDrag(tester, IonType.blue);
      await _restore(tester, app, _board(mistakes: 4));
      final before = _snapshot(tester);
      await gesture.moveTo(tester.getCenter(_targets.first));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      await _drop(tester, IonType.blue);
      expect(_snapshot(tester)['_playerChain'], ['red', 'blue', 'red', null]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'real removal returns inventory and another bead can fill its slot',
      (tester) async {
    final app = await _mount(tester);
    await _drop(tester, IonType.blue);
    final dynamic depleted = tester.widget(_tray(IonType.blue));
    expect(depleted.maxSimultaneousDrags, 0);
    await tester.tap(_placed.first);
    await tester.pump();
    expect(_snapshot(tester)['_playerChain'], ['red', null, 'red', null]);
    final dynamic replenished = tester.widget(_tray(IonType.blue));
    expect(replenished.maxSimultaneousDrags, 1);
    await _drop(tester, IonType.green);
    await _drop(tester, IonType.blue);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app);
  });

  testWidgets('old removal cannot remove a different bead or replacement board',
      (tester) async {
    final app = await _mount(tester);
    await _drop(tester, IonType.blue);
    final old = tester.widget<GestureDetector>(_placed.first);
    await tester.tap(_placed.first);
    await tester.pump();
    await _drop(tester, IonType.green);
    final before = _snapshot(tester);
    old.onTap!();
    await tester.pump();
    expect(_snapshot(tester), before);
    await _restore(
        tester,
        app,
        _board(
            chain: const ['red', null, 'blue'],
            supply: const ['green'],
            solution: const ['red', 'green', 'blue'],
            mistakes: 5));
    final restored = _snapshot(tester);
    old.onTap!();
    await tester.pump();
    expect(_snapshot(tester), restored);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rule and dead-end rejection keep inventory and grade saved mistakes',
      (tester) async {
    final app = await _mount(tester,
        board: _board(chain: const [
          'green',
          null,
          'green',
          'red',
          null,
          'green',
          'blue'
        ], supply: const [
          'red',
          'blue'
        ], solution: const [
          'green',
          'red',
          'green',
          'red',
          'blue',
          'green',
          'blue'
        ], mistakes: 2));
    final chain = _snapshot(tester)['_playerChain'];
    await _drop(tester, IonType.red, target: 1);
    expect(_snapshot(tester)['_playerChain'], chain);
    expect(_snapshot(tester)['_ruleViolations'], 3);
    await _drop(tester, IonType.blue);
    expect(_snapshot(tester)['_playerChain'], chain);
    expect(_snapshot(tester)['_ruleViolations'], 4);
    final saved = _snapshot(tester);
    await _restore(tester, app, saved);
    expect(_snapshot(tester), saved);
    expect(find.byType(SnackBar), findsNothing);
    await _drop(tester, IonType.red);
    await _drop(tester, IonType.blue);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, mistakes: 4);
  });

  testWidgets('canceled drag leaves inventory and grade unchanged',
      (tester) async {
    final app = await _mount(tester);
    final before = _snapshot(tester);
    final gesture = await _startDrag(tester, IonType.blue);
    await gesture.moveTo(tester.getCenter(_targets.first));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('success finishes when motion is reduced during the effect',
      (tester) async {
    final app = await _mount(tester);
    await _drop(tester, IonType.blue);
    await _drop(tester, IonType.green);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(_dialog, findsOneWidget);
    _grade(app);
  });

  testWidgets('old dialog buttons cannot change a restored board',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drop(tester, IonType.blue);
    await _drop(tester, IonType.green);
    await tester.pump(const Duration(milliseconds: 300));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app, _board(mistakes: 6));
    final before = _snapshot(tester);
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(_screen, findsOneWidget);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing an active drag cannot submit an outcome',
      (tester) async {
    final app = await _mount(tester);
    final gesture = await _startDrag(tester, IonType.blue);
    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('static ring repaints on radius and slot-count changes',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final dynamic previous = tester.widget<CustomPaint>(_ring).painter;
    tester.view.physicalSize = const Size(300, 1100);
    await tester.pump();
    final dynamic resized = tester.widget<CustomPaint>(_ring).painter;
    expect(resized.ringRadius, isNot(previous.ringRadius));
    expect(resized.shouldRepaint(previous), isTrue);
    await _restore(
        tester,
        app,
        _board(
            chain: const ['red', null, 'blue'],
            supply: const ['green'],
            solution: const ['red', 'green', 'blue']));
    final dynamic restored = tester.widget<CustomPaint>(_ring).painter;
    expect(restored.slotCount, 3);
    expect(restored.shouldRepaint(resized), isTrue);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
