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
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/hive_station_game.dart';
import 'package:space_math_academy/features/games/services/hive_station_logic.dart';
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
            home: const HiveStationGame(grade: 1, level: 1)),
      );
}

final _screen = find.byType(HiveStationGame);
final _dialog = find.byType(Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Set<HexCoord> _allCellsFor(int radius) {
  final s = <HexCoord>{};
  for (int q = -radius; q <= radius; q++) {
    for (int r = -radius; r <= radius; r++) {
      if ((q + r).abs() <= radius) s.add(HexCoord(q, r));
    }
  }
  return s;
}

HiveStationPuzzle _testPuzzle(
    {int radius = 2, Set<HexCoord>? energy, int? revealUpTo}) {
  final allCells = _allCellsFor(radius);
  final energyCells = energy ?? {const HexCoord(1, 0), const HexCoord(0, 1)};
  // Compute hints for all non-energy cells
  final hints = <HexCoord, int>{};
  for (final c in allCells) {
    if (!energyCells.contains(c)) {
      int cnt = 0;
      for (final n in c.neighbors) if (energyCells.contains(n)) cnt++;
      hints[c] = cnt;
    }
  }
  // Reveal most but leave a few hidden so player has choices
  final nonEnergy = allCells.where((c) => !energyCells.contains(c)).toList();
  final revealed = revealUpTo != null
      ? nonEnergy.take(revealUpTo).toSet()
      : nonEnergy.take(nonEnergy.length - 4).toSet();
  return HiveStationPuzzle(
      allCells: allCells,
      energyCells: energyCells,
      numberHints: hints,
      revealedHints: revealed,
      radius: radius);
}

Map<String, dynamic> _board({
  HiveStationPuzzle? puzzle,
  Set<HexCoord>? marked,
  int attempts = 3,
}) {
  final p = puzzle ?? _testPuzzle();
  return {
    'puzzle': p.toJson(),
    'userMarked': (marked ?? <HexCoord>{}).map((e) => e.toJson()).toList(),
    '_attemptsLeft': attempts,
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
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  return app;
}

Future<void> _retry(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, _strings(tester).tryAgain);
  final alt = find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  final target = btn.evaluate().isNotEmpty ? btn : alt;
  await tester.ensureVisible(target.first);
  await tester.pump();
  await tester.tap(target.first);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(_dialog, findsNothing);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('hive_station', 1, 1).then((v) {
    saved = v;
    complete = true;
  });
  for (var frame = 0; frame < 100 && !complete; frame++)
    await tester.pump(const Duration(milliseconds: 20));
  expect(complete, isTrue);
  return saved;
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'hive_station_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues({});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('tap toggles mark and persists', (tester) async {
    final app = await _mount(tester, reduced: true);
    final dyn = _session(tester);
    final snap0 = _snapshot(tester);
    expect((snap0['userMarked'] as List), isEmpty);
    const coord = HexCoord(1, 0); // energy cell, not revealed
    final round = dyn.testRound as Object;
    dyn.toggleForTesting(coord, round);
    await tester.pump();
    expect(_snapshot(tester)['userMarked'], contains(containsPair('q', 1)));
    // toggle off
    dyn.toggleForTesting(coord, round);
    await tester.pump();
    expect((_snapshot(tester)['userMarked'] as List), isEmpty);
    // persisted
    await tester.pump(const Duration(milliseconds: 900));
    final saved = await _stored(tester);
    expect(saved!['userMarked'], isEmpty);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('wrong attempt decrements but stays recoverable', (tester) async {
    final puzzle = _testPuzzle();
    final app = await _mount(tester,
        reduced: true, board: _board(puzzle: puzzle, attempts: 3));
    final dyn = _session(tester);
    final wrong = puzzle.allCells.firstWhere((c) =>
        !puzzle.energyCells.contains(c) && !puzzle.revealedHints.contains(c));
    final correctOne = puzzle.energyCells.first;
    final round = dyn.testRound as Object;
    dyn.toggleForTesting(wrong, round);
    await tester.pump();
    dyn.toggleForTesting(correctOne, round);
    await tester.pump();
    // 2 marked == energyCells.length (2) but contains wrong -> wrong attempt
    final check = find.byKey(ValueKey(('hive-check', round)));
    await tester.tap(check);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_snapshot(tester)['_attemptsLeft'], 2);
    expect(app.gp.outcomeCount, 0);
    expect(find.byType(SnackBar), findsOneWidget);
    dyn.toggleForTesting(wrong, round);
    await tester.pump();
    expect((_snapshot(tester)['userMarked'] as List).length, 1);
  });

  testWidgets('correct solution wins once and retry resets', (tester) async {
    final puzzle = _testPuzzle();
    final app =
        await _mount(tester, reduced: true, board: _board(puzzle: puzzle));
    final dyn = _session(tester);
    final round = dyn.testRound as Object;
    for (final e in puzzle.energyCells) {
      dyn.toggleForTesting(e, round);
      await tester.pump();
    }
    final check = find.byKey(ValueKey(('hive-check', round)));
    await tester.tap(check);
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    await _retry(tester);
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    expect(app.gp.outcomeCount, 1); // no extra win on retry
  });

  testWidgets('exhausting attempts loses once', (tester) async {
    final puzzle = _testPuzzle();
    final app = await _mount(tester,
        reduced: true, board: _board(puzzle: puzzle, attempts: 1));
    final dyn = _session(tester);
    final wrong = puzzle.allCells.firstWhere((c) =>
        !puzzle.energyCells.contains(c) && !puzzle.revealedHints.contains(c));
    final round = dyn.testRound as Object;
    dyn.toggleForTesting(wrong, round);
    await tester.pump();
    for (final e in puzzle.energyCells.skip(1)) {
      dyn.toggleForTesting(e, round);
      await tester.pump();
    }
    // Ensure count matches
    final marked = (_snapshot(tester)['userMarked'] as List).length;
    if (marked < puzzle.energyCells.length) {
      // fill with another non-energy
      final extra = puzzle.allCells.firstWhere((c) =>
          !puzzle.energyCells.contains(c) &&
          !puzzle.revealedHints.contains(c) &&
          c != wrong);
      dyn.toggleForTesting(extra, round);
      await tester.pump();
    }
    final check = find.byKey(ValueKey(('hive-check', round)));
    await tester.tap(check);
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_dialog, findsOneWidget);
    // Tapping again should not double-report
    await tester.tap(check);
    await tester.pump();
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('old round toggle cannot mutate new board after restore',
      (tester) async {
    final puzzleA =
        _testPuzzle(energy: {const HexCoord(1, 0), const HexCoord(0, 1)});
    final puzzleB =
        _testPuzzle(energy: {const HexCoord(-1, 0), const HexCoord(0, -1)});
    final app = await _mount(tester, board: _board(puzzle: puzzleA));
    final oldRound = (_session(tester).testRound as Object);
    const coord = HexCoord(1, 0);
    await _restore(tester, app, _board(puzzle: puzzleB));
    final before = _snapshot(tester);
    // Old round toggle should be ignored
    _session(tester).toggleForTesting(coord, oldRound);
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    // New round should work
    final newRound = _session(tester).testRound as Object;
    _session(tester).toggleForTesting(const HexCoord(-1, 0), newRound);
    await tester.pump();
    expect(_snapshot(tester)['userMarked'], isNotEmpty);
  });

  testWidgets('reduced motion completes immediately', (tester) async {
    final app = await _mount(tester, reduced: true);
    final puzzle = _testPuzzle();
    final dyn = _session(tester);
    final round = dyn.testRound as Object;
    final coord = puzzle.energyCells.first;
    dyn.toggleForTesting(coord, round);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    app.motion.value = false;
    await tester.pump();
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('revealed hints cannot be toggled', (tester) async {
    final puzzle = _testPuzzle();
    final revealed = puzzle.revealedHints.first;
    await _mount(tester, reduced: true, board: _board(puzzle: puzzle));
    final dyn = _session(tester);
    final round = dyn.testRound as Object;
    dyn.toggleForTesting(revealed, round);
    await tester.pump();
    expect((_snapshot(tester)['userMarked'] as List), isEmpty);
  });

  for (final lang in ['en', 'de']) {
    testWidgets('phone doubled text win in $lang', (tester) async {
      final puzzle = _testPuzzle();
      final app = await _mount(tester,
          reduced: true,
          textScale: 2,
          locale: Locale(lang),
          board: _board(puzzle: puzzle));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      final dyn = _session(tester);
      final round = dyn.testRound as Object;
      for (final e in puzzle.energyCells) {
        dyn.toggleForTesting(e, round);
        await tester.pump();
      }
      final check = find.byKey(ValueKey(('hive-check', round)));
      await tester.ensureVisible(check);
      await tester.pump();
      await tester.tap(check);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 1);
    });
  }

  testWidgets('short viewport 390x500 keeps controls reachable',
      (tester) async {
    await _mount(tester,
        reduced: true, textScale: 2, locale: const Locale('en'));
    tester.view.physicalSize = const Size(390, 500);
    await tester.pump();
    final check = find.byType(ElevatedButton);
    expect(check, findsWidgets);
    await tester.ensureVisible(check.first);
    await tester.pump();
    // No overflow exception
    expect(tester.takeException(), isNull);
  });
}
