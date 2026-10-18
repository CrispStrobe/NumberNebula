import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'support/round_dialog_finder.dart';
// ignore_for_file: curly_braces_in_flow_control_structures
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
import 'package:space_math_academy/features/games/screens/orbital_towers_game.dart';
import 'package:space_math_academy/features/games/services/orbital_towers_logic.dart';
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
  final bool pushed;
  _App(
      {bool reduced = false,
      this.textScale = 1,
      this.locale,
      this.pushed = false})
      : motion = ValueNotifier(reduced);
  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider<DebugProvider>.value(value: debug)
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
                    child: child!)),
            initialRoute: pushed ? '/audit-game' : null,
            routes: pushed
                ? {
                    '/audit-game': (_) =>
                        const OrbitalTowersGame(grade: 1, level: 1)
                  }
                : const {},
            home: pushed
                ? const Scaffold(body: Text('audit root'))
                : const OrbitalTowersGame(grade: 1, level: 1)),
      );
}

final _screen = find.byType(OrbitalTowersGame);
final _dialog = roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

OrbitalTowersPuzzle _testPuzzle(
    {int size = 4, Set<String> empty = const {'r0c0', 'r0c1'}}) {
  // Simple Latin square solution for size 4
  final solution = <String, int>{};
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      solution['r${r}c$c'] = (r + c) % size + 1;
    }
  }
  final clues = <String, int>{};
  for (final e in solution.entries) {
    if (!empty.contains(e.key)) {
      clues[e.key] = e.value;
    }
  }
  return OrbitalTowersPuzzle(
      size: size,
      solution: solution,
      clues: clues,
      emptyCells: empty,
      numberPool: List.generate(size, (i) => i + 1),
      edgeClues: {});
}

Map<String, dynamic> _board(
    {int size = 4,
    Set<String> empty = const {'r0c0', 'r0c1'},
    Map<String, int> answers = const {},
    int? moves,
    int? maxMoves,
    int? optimal}) {
  final puzzle = _testPuzzle(size: size, empty: empty);
  final emptyCount = empty.length;
  return {
    'puzzle': puzzle.toJson(),
    'answers': Map.of(answers),
    'moves': moves ?? emptyCount * 2,
    'maxMoves': maxMoves ?? emptyCount * 2,
    'optimal': optimal ?? emptyCount,
    'hints': 0
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
    bool pushed = false,
    double textScale = 1,
    Locale? locale,
    Map<String, dynamic>? board}) async {
  final app = _App(
      reduced: reduced, textScale: textScale, locale: locale, pushed: pushed);
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
    find.byWidgetPredicate((w) => w is DragTarget<OrbitalTowersDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<OrbitalTowersDrag> && w.data!.number == n);
DragTarget<OrbitalTowersDrag> _target(WidgetTester tester, [int idx = 0]) =>
    tester.widget<DragTarget<OrbitalTowersDrag>>(_targets.at(idx));
OrbitalTowersDrag _payload(WidgetTester tester, int n) =>
    tester.widget<Draggable<OrbitalTowersDrag>>(_draggable(n)).data!;
void _deliver(DragTarget<OrbitalTowersDrag> t, OrbitalTowersDrag d) =>
    t.onAcceptWithDetails!(
        DragTargetDetails<OrbitalTowersDrag>(data: d, offset: Offset.zero));
Future<void> _drag(WidgetTester tester, int value, [int targetIdx = 0]) async {
  await tester.drag(
      _draggable(value),
      tester.getCenter(_targets.at(targetIdx)) -
          tester.getCenter(_draggable(value)));
  await tester.pump();
}

final _filled = find.byWidgetPredicate((w) =>
    w is GestureDetector &&
    w.key is ValueKey &&
    (w.key as ValueKey).value.toString().contains('orbital-filled'));
void _grade(_App app, {int moves = 2, int optimal = 2}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.movesUsed, moves);
  expect(app.gp.lastOutcome!.optimalMoves, optimal);
}

Future<void> _retry(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(_dialog, findsNothing);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('orbital_towers', 1, 1).then((v) {
    saved = v;
    complete = true;
  });
  for (var frame = 0; frame < 100 && !complete; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(complete, isTrue);
  return saved;
}

void main() {
  testWidgets('adversarial: retained back callback rejects restored round',
      (t) async {
    await _mount(t, reduced: true, pushed: true);
    final old = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final dynamic session = _session(t);
    final before = jsonDecode(jsonEncode(session.capturePuzzleSession()))
        as Map<String, dynamic>;
    session.beginPuzzleSession();
    session.applyPuzzleSession(before);
    session.rebuildForTesting();
    await t.pump();
    old();
    await t.pump();
    expect(_screen, findsOneWidget);
    expect(session.capturePuzzleSession(), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('adversarial: back callback cannot dismiss a covering route',
      (t) async {
    await _mount(t, reduced: true, pushed: true);
    final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final context = t.element(_screen);
    showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('audit route probe')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    back();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('audit route probe'), findsOneWidget);
    Navigator.of(context).pop();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });

  var profile = 0;
  setUp(() {
    final id = 'orbital_towers_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_orbital_towers_guided_v1': true});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets('real drop consumes one move and removal is free',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 1);
    expect(_snapshot(tester)['answers'], containsPair('r0c0', 1));
    expect(_snapshot(tester)['moves'], 3);
    await tester.pump(const Duration(milliseconds: 1000));
    var saved = await _stored(tester);
    expect(saved!['answers'], containsPair('r0c0', 1));
    await tester.tap(_filled.first);
    await tester.pump();
    expect(_snapshot(tester)['answers'], isEmpty);
    expect(app.gp.outcomeCount, 0);
  });
  for (final reduced in [false, true]) {
    testWidgets(
        'actual final correct drop wins once and retry (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _drag(tester, 1);
      await _drag(tester, 2);
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app, moves: 2, optimal: 2);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      await _retry(tester);
      _grade(app, moves: 2, optimal: 2);
    });
  }
  testWidgets('old payload cannot mutate new board', (tester) async {
    final app = await _mount(tester);
    final oldTarget = _target(tester);
    final oldPayload = _payload(tester, 1);
    await _restore(tester, app, _board(empty: {'r1c0', 'r1c1'}));
    final before = _snapshot(tester);
    final newTarget = _target(tester);
    _deliver(oldTarget, oldPayload);
    _deliver(newTarget, oldPayload);
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets('reduced motion completes immediately', (tester) async {
    final app = await _mount(tester, reduced: true);
    await _drag(tester, 1);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    app.motion.value = false;
    await tester.pump();
    expect(app.gp.outcomeCount, 0);
  });
  for (final lang in ['en', 'de']) {
    testWidgets('phone doubled text win in $lang', (tester) async {
      final app = await _mount(tester,
          reduced: true, textScale: 2, locale: Locale(lang));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await _drag(tester, 1);
      await _drag(tester, 2);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      _grade(app);
    });
  }
  testWidgets(
      'full incorrect final move loses once without a negative-budget escape',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(answers: {'r0c0': 1}, moves: 1));
    await _drag(tester, 1);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).capturePuzzleSession(), isNull);
  });
  testWidgets('older full wrong zero-move snapshot offers retry without replay',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _restore(
        tester, app, _board(answers: {'r0c0': 1, 'r0c1': 1}, moves: 0));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    expect(_session(tester).capturePuzzleSession(), isNull);
  });
}
