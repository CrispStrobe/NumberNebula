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
import 'package:space_math_academy/features/games/screens/dark_matter_grid_game.dart';
import 'package:space_math_academy/features/games/services/dark_matter_grid_logic.dart';
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
  final Locale? locale;
  _App({bool reduced = false, this.textScale = 1, this.locale})
      : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
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
          home: const DarkMatterGridGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(DarkMatterGridGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {int size = 3,
    bool oneAway = false,
    bool solved = false,
    int moves = 0,
    int minMoves = 1}) {
  var grid =
      List.generate(size, (_) => List<bool>.filled(size, oneAway || solved));
  if (oneAway) {
    grid = DarkMatterGridPuzzle.toggle(grid, size ~/ 2, size ~/ 2);
  }
  final puzzle = DarkMatterGridPuzzle(
      size: size, grid: grid.map(List<bool>.of).toList(), minMoves: minMoves);
  return {
    'puzzle': puzzle.toJson(),
    'grid': grid.map(List<bool>.of).toList(),
    'moves': moves
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

final _cells = find.byWidgetPredicate(
    (widget) => widget is GestureDetector && widget.child is AnimatedContainer);
Finder _cell(WidgetTester tester, int row, int col) => _cells
    .at(row * ((_snapshot(tester)['puzzle'] as Map)['size'] as int) + col);
Future<void> _tapCell(WidgetTester tester, int row, int col) async {
  await tester.tap(_cell(tester, row, col));
  await tester.pump();
}

void _grade(_App app, {int moves = 1, int optimal = 1}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125 + optimal * 50 ~/ moves.clamp(1, 999));
  expect(app.gp.lastOutcome!.movesUsed, moves);
  expect(app.gp.lastOutcome!.optimalMoves, optimal);
  expect(app.gp.lastOutcome!.performance, Perf.fromMoves(moves, optimal));
}

Future<void> _retry(WidgetTester tester) async {
  final button =
      find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(_dialog, findsNothing);
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  expect(_snapshot(tester)['moves'], 0);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('dark_matter_grid', 1, 1).then((value) {
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
    final id = 'dark_matter_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_dark_matter_grid': true});
    PuzzleSessionStore.resetForTesting();
  });

  for (final point in [
    const Offset(0, 0),
    const Offset(0, 1),
    const Offset(1, 1)
  ]) {
    testWidgets(
        'actual${point.dx.toInt()},${point.dy.toInt()} toggles only orthogonal neighbors at one move',
        (tester) async {
      final app = await _mount(tester, reduced: true);
      final before = _snapshot(tester)['grid'];
      final row = point.dx.toInt(), col = point.dy.toInt();
      await _tapCell(tester, row, col);
      final grid = _snapshot(tester)['grid'] as List;
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(grid[r][c], (r - row).abs() + (c - col).abs() <= 1);
        }
      }
      expect(_snapshot(tester)['moves'], 1);
      await _tapCell(tester, row, col);
      expect(_snapshot(tester)['grid'], before);
      expect(_snapshot(tester)['moves'], 2);
      expect(app.gp.outcomeCount, 0);
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
        'real solving tap wins once with original score and retry (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(oneAway: true));
      final old = tester.widget<GestureDetector>(_cell(tester, 1, 1));
      await _tapCell(tester, 1, 1);
      old.onTap!();
      old.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(await _stored(tester), isNull);
      await _retry(tester);
      _grade(app);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'partial board and prior moves persist and later win retains approximate-minimum grading',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(oneAway: true, moves: 2));
    await _tapCell(tester, 0, 0);
    await tester.pump(const Duration(milliseconds: 1000));
    final saved = await _stored(tester);
    expect(saved!['moves'], 3);
    expect(saved['grid'], _snapshot(tester)['grid']);
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['moves'], 3);
    expect(_snapshot(tester)['grid'], saved['grid']);
    await _tapCell(tester, 0, 0);
    await _tapCell(tester, 1, 1);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, moves: 5);
  });

  for (final size in [2, 3]) {
    testWidgets(
        'old cell and header callbacks cannot touch replacement size$size',
        (tester) async {
      final app = await _mount(tester);
      final old = tester.widget<GestureDetector>(_cell(tester, 2, 2));
      final header = tester.widget<GameUI>(find.byType(GameUI));
      await _restore(tester, app, _board(size: size, oneAway: true, moves: 7));
      final before = _snapshot(tester);
      old.onTap!();
      header.onBack();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(_screen, findsOneWidget);
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('active finger cannot toggle same-size replacement board',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final pointer =
        await tester.startGesture(tester.getCenter(_cell(tester, 1, 1)));
    await _restore(tester, app, _board(oneAway: true));
    final before = _snapshot(tester);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'older solved snapshot offers retry without reporting another outcome',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(solved: true, moves: 9));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    expect(await _stored(tester), isNull);
    await _retry(tester);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets(
      'restoration cancels in-progress victory and resets controller for next board',
      (tester) async {
    final app = await _mount(tester, board: _board(oneAway: true));
    await _tapCell(tester, 1, 1);
    await tester.pump(const Duration(milliseconds: 100));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await _restore(tester, app, _board(moves: 4));
    final AnimationController success = _session(tester).successController;
    expect(success.isAnimating, isFalse);
    expect(success.value, 0);
    final before = _snapshot(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_snapshot(tester), before);
    expect(_dialog, findsNothing);
    _grade(app);
  });

  for (final replace in [false, true]) {
    testWidgets(
        'closed result buttons cannot retry or exit (replacement:$replace)',
        (tester) async {
      final app =
          await _mount(tester, reduced: true, board: _board(oneAway: true));
      await _tapCell(tester, 1, 1);
      await tester.pump(const Duration(milliseconds: 700));
      final retry = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      final exit = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
      Navigator.of(tester.element(_screen)).pop();
      await tester.pump();
      Map<String, dynamic>? before;
      if (replace) {
        await _restore(tester, app, _board(moves: 7));
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

  testWidgets(
      'initial and mid-reduced motion stop cell transitions and complete victory immediately',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _tapCell(tester, 0, 0);
    final visual = tester.widget<AnimatedContainer>(find
        .descendant(
            of: _cell(tester, 0, 0), matching: find.byType(AnimatedContainer))
        .first);
    expect(visual.duration, Duration.zero);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    app.motion.value = false;
    await tester.pump();
    await _restore(tester, app, _board(oneAway: true));
    await _tapCell(tester, 1, 1);
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

  testWidgets('disposal rejects retained cell and back callbacks',
      (tester) async {
    final app = await _mount(tester, board: _board(oneAway: true));
    final old = tester.widget<GestureDetector>(_cell(tester, 1, 1));
    final header = tester.widget<GameUI>(find.byType(GameUI));
    await tester.pumpWidget(const SizedBox.shrink());
    old.onTap!();
    header.onBack();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'de']) {
    testWidgets(
        'five-square phone doubled text supports real win and retry in$language',
        (tester) async {
      final app = await _mount(tester,
          reduced: true,
          textScale: 2,
          locale: Locale(language),
          board: _board(size: 5, oneAway: true));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _tapCell(tester, 2, 2);
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
      'short viewport scrolls five-square grid while preserving minimum hit boxes',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        textScale: 2,
        locale: const Locale('en'),
        board: _board(size: 5));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 500);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final last = _cell(tester, 4, 4);
    final visual = tester.widget<AnimatedContainer>(find
        .descendant(of: last, matching: find.byType(AnimatedContainer))
        .first);
    expect(visual.constraints!.minWidth, greaterThanOrEqualTo(40));
    expect(visual.constraints!.minHeight, greaterThanOrEqualTo(40));
    await tester.ensureVisible(last);
    await tester.pump();
    await _tapCell(tester, 4, 4);
    expect(_snapshot(tester)['moves'], 1);
    final grid = _snapshot(tester)['grid'] as List;
    expect(grid[4][4], isTrue);
    expect(grid[3][4], isTrue);
    expect(grid[4][3], isTrue);
    expect(grid[3][3], isFalse);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'de']) {
    testWidgets('move statistics use localized roundMoves in$language',
        (tester) async {
      final app = await _mount(tester,
          reduced: true, locale: Locale(language), board: _board(moves: 7));
      final label = _strings(tester).roundMoves(7);
      expect(find.textContaining(label), findsOneWidget);
      expect(find.textContaining('Moves:'), findsNothing);
      expect(Localizations.localeOf(tester.element(_screen)).languageCode,
          language);
      await _tapCell(tester, 0, 0);
      expect(
          find.textContaining(_strings(tester).roundMoves(8)), findsOneWidget);
      expect(app.gp.outcomeCount, 0);
    });
  }
}
