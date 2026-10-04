import 'dart:convert';
import 'dart:math' as math;

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
import 'package:space_math_academy/features/games/screens/sector_painter_game.dart';
import 'package:space_math_academy/features/games/services/sector_painter_logic.dart';
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
          home: const SectorPainterGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(SectorPainterGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {Map<int, int> coloring = const {0: 0},
    int selected = 1,
    int conflicts = 0,
    int count = 2}) {
  final puzzle = SectorPainterPuzzle(
    regions: List.generate(count, (index) => index),
    adjacency: {
      for (var index = 0; index < count; index++)
        index: {if (index > 0) index - 1, if (index + 1 < count) index + 1}
    },
    chromaticNumber: 2,
    availableColors: 3,
    positions: [
      for (var index = 0; index < count; index++)
        math.Point<double>((index + 1) / (count + 1), .5)
    ],
  );
  return {
    '_puzzle': puzzle.toJson(),
    '_coloring':
        coloring.entries.map((entry) => [entry.key, entry.value]).toList(),
    '_selectedColor': selected,
    '_conflictEvents': conflicts
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

Finder _node(int region) => find
    .ancestor(
        of: find.text('${region + 1}'),
        matching: find.byWidgetPredicate(
            (widget) => widget is GestureDetector && widget.onTap != null))
    .first;
final _palettes = find.byWidgetPredicate((widget) {
  if (widget is! GestureDetector || widget.child is! AnimatedContainer) {
    return false;
  }
  final decoration = (widget.child! as AnimatedContainer).decoration;
  return decoration is BoxDecoration &&
      decoration.shape == BoxShape.circle &&
      decoration.color != null;
});
Finder _palette(int color) => _palettes.at(color);
GestureDetector _callback(WidgetTester tester, Finder finder) =>
    tester.widget<GestureDetector>(finder);
Future<void> _paint(WidgetTester tester, int region) async {
  await tester.tap(_node(region));
  await tester.pump();
}

Future<void> _color(WidgetTester tester, int color) async {
  await tester.tap(_palette(color));
  await tester.pump();
}

AnimatedContainer _nodeVisual(WidgetTester tester, int region) =>
    tester.widget<AnimatedContainer>(find
        .descendant(of: _node(region), matching: find.byType(AnimatedContainer))
        .first);
double _borderWidth(WidgetTester tester, int region) =>
    ((_nodeVisual(tester, region).decoration! as BoxDecoration).border!
            as Border)
        .top
        .width;
dynamic _graphPainter(WidgetTester tester) => tester
    .widget<CustomPaint>(
        find.ancestor(of: _node(0), matching: find.byType(CustomPaint)).first)
    .painter;

void _grade(_App app, {int conflicts = 0, bool optimal = true}) {
  expect(app.gp.outcomeCount, 1);
  final outcome = app.gp.lastOutcome!;
  expect(outcome.wasSuccessful, isTrue);
  expect(outcome.score, optimal ? 225 : 125);
  expect(
      outcome.performance,
      Perf.combine([optimal ? 1 : .6, Perf.fromMistakes(conflicts, per: .1)],
          weights: [2, 1]));
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'sector_painter_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_sector_painter': true});
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'valid painting wins once at300ms and real retry is saveable (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final region = _callback(tester, _node(1));
      final palette = _callback(tester, _palette(2));
      await _paint(tester, 1);
      expect(app.gp.outcomeCount, 0);
      expect(_snapshot(tester)['_coloring'], [
        [0, 0],
        [1, 1]
      ]);
      await tester.pump(const Duration(milliseconds: 299));
      expect(_dialog, findsNothing);
      expect(app.gp.outcomeCount, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      region.onTap!();
      palette.onTap!();
      await tester.pump();
      _grade(app);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        if (_session(tester).capturePuzzleSession() != null) break;
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      expect(_snapshot(tester)['_coloring'], isEmpty);
      expect(_snapshot(tester)['_conflictEvents'], 0);
    });

    testWidgets(
        'unpainting complete solution cancels delayed win (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _paint(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      await _paint(tester, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['_coloring'], [
        [0, 0]
      ]);
    });

    testWidgets(
        'introducing conflict cancels delayed win then correcting grades saved mistakes (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(conflicts: 2));
      await _paint(tester, 1);
      await tester.pump(const Duration(milliseconds: 100));
      await _color(tester, 0);
      await _paint(tester, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['_conflictEvents'], 3);
      expect(_snapshot(tester)['_coloring'], [
        [0, 0],
        [1, 0]
      ]);
      await _color(tester, 1);
      await _paint(tester, 1);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app, conflicts: 3);
      expect(_dialog, findsOneWidget);
    });
  }

  testWidgets(
      'replacement cancels win timer and rejects old node and palette closures',
      (tester) async {
    final app = await _mount(tester);
    final region = _callback(tester, _node(1));
    final palette = _callback(tester, _palette(2));
    await _paint(tester, 1);
    await tester.pump(const Duration(milliseconds: 100));
    await _restore(
        tester, app, _board(coloring: {1: 2}, selected: 0, conflicts: 4));
    final before = _snapshot(tester);
    region.onTap!();
    palette.onTap!();
    await tester.pump(const Duration(seconds: 2));
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restore keeps selected color and mistakes while canceling flash; invalid selection normalizes',
      (tester) async {
    final app = await _mount(tester, board: _board(selected: 0));
    await _paint(tester, 1);
    expect(_borderWidth(tester, 0), 4);
    final saved = _snapshot(tester);
    expect(saved['_selectedColor'], 0);
    expect(saved['_conflictEvents'], 1);
    await _restore(tester, app, saved);
    expect(_snapshot(tester), saved);
    expect(_borderWidth(tester, 0), 2);
    expect(_borderWidth(tester, 1), 2);
    await tester.pump(const Duration(milliseconds: 800));
    expect(_snapshot(tester), saved);
    for (final selected in [-1, 99]) {
      await _restore(tester, app, _board(selected: selected, conflicts: 7));
      expect(_snapshot(tester)['_selectedColor'], 0);
      expect(_snapshot(tester)['_conflictEvents'], 7);
      await _paint(tester, 1);
      expect(_snapshot(tester)['_conflictEvents'], 8);
    }
    expect(app.gp.outcomeCount, 0);
  });

  for (final initiallyReduced in [false, true]) {
    testWidgets(
        'conflict one-shot clears and stops after motion reduction (initial:$initiallyReduced)',
        (tester) async {
      final app = await _mount(tester,
          reduced: initiallyReduced, board: _board(selected: 0));
      await _paint(tester, 1);
      if (!initiallyReduced) {
        expect(_borderWidth(tester, 0), 4);
        await tester.pump(const Duration(milliseconds: 150));
        app.motion.value = true;
        await tester.pump();
      }
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_borderWidth(tester, 0), 2);
      expect(_borderWidth(tester, 1), 2);
      expect(_nodeVisual(tester, 1).duration, Duration.zero);
      expect(tester.binding.transientCallbackCount, 0);
      expect(_snapshot(tester)['_conflictEvents'], 1);
      app.motion.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      app.motion.value = true;
      await tester.pump();
      await tester.pump();
      expect(_borderWidth(tester, 0), 2);
      expect(_snapshot(tester)['_conflictEvents'], 1);
      expect(app.gp.outcomeCount, 0);
    });
  }

  testWidgets(
      'extra valid colors preserve nonoptimal score and weighted mistakes',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(
            count: 3, coloring: {0: 0, 1: 1}, selected: 2, conflicts: 4));
    await _paint(tester, 2);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, conflicts: 4, optimal: false);
    expect(_dialog, findsOneWidget);
  });

  testWidgets(
      'reduced static graph snapshots painting and repaints restored topology and resize',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final dynamic previous = _graphPainter(tester);
    expect(previous.coloring, {0: 0});
    await _paint(tester, 1);
    final dynamic colored = _graphPainter(tester);
    expect(colored.shouldRepaint(previous), isTrue);
    expect(previous.coloring, {0: 0},
        reason:
            'The old painter must retain its own map rather than share mutable state');
    expect(colored.coloring, {0: 0, 1: 1});
    await _restore(
        tester, app, _board(count: 3, coloring: {0: 0, 2: 0}, selected: 1));
    final dynamic restored = _graphPainter(tester);
    expect(restored.shouldRepaint(colored), isTrue);
    expect(restored.puzzle.regions.length, 3);
    expect(colored.coloring, {0: 0, 1: 1});
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    final dynamic resized = _graphPainter(tester);
    expect(resized.shouldRepaint(restored), isTrue);
    expect(resized.width != restored.width || resized.height != restored.height,
        isTrue);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mid-success reduced motion keeps one award and usable dialog',
      (tester) async {
    final app = await _mount(tester);
    await _paint(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(_dialog, findsOneWidget);
    _grade(app);
    expect(find.widgetWithText(ElevatedButton, _strings(tester).playAgain),
        findsOneWidget);
  });

  testWidgets(
      'retained terminal dialog callbacks cannot affect replacement round',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _paint(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app, _board(coloring: {1: 2}, selected: 2));
    final before = _snapshot(tester);
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump(const Duration(seconds: 1));
    expect(_snapshot(tester), before);
    expect(_screen, findsOneWidget);
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'in-flight real retry generation cannot replace an applied session',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _paint(tester, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    retry.onPressed!();
    expect(_session(tester).capturePuzzleSession(), isNull);
    // Apply synchronously before the isolate result can return to this event loop.
    _session(tester).beginPuzzleSession();
    _session(tester).applyPuzzleSession(
        _board(coloring: {1: 2}, selected: 2, conflicts: 5));
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    final before = _snapshot(tester);
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_snapshot(tester), before);
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal cancels pending victory and retained taps',
      (tester) async {
    final app = await _mount(tester);
    final region = _callback(tester, _node(1));
    final palette = _callback(tester, _palette(2));
    await _paint(tester, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    region.onTap!();
    palette.onTap!();
    await tester.pump(const Duration(seconds: 2));
    expect(_dialog, findsNothing);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
