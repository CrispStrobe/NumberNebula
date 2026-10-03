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
import 'package:space_math_academy/features/games/screens/void_crossing_game.dart';
import 'package:space_math_academy/features/games/services/void_crossing_logic.dart';
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
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: motion,
            builder: (_, reduced, __) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
          ),
          home: const VoidCrossingGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(VoidCrossingGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {bool two = false,
    bool prepared = false,
    bool conflict = false,
    int moves = 0,
    int maxMoves = 6}) {
  final entities = [
    const VoidEntity(
        id: 'zorblex', nameKey: 'voidCrossingZorblex', emoji: '👾'),
    if (two || conflict)
      const VoidEntity(
          id: 'glimbit', nameKey: 'voidCrossingGlimbit', emoji: '🐛'),
    if (conflict)
      const VoidEntity(
          id: 'star_moss', nameKey: 'voidCrossingStarMoss', emoji: '🌿'),
  ];
  final puzzle = VoidCrossingPuzzle(
    entities: entities,
    conflicts: conflict
        ? [const ConflictRule(entityA: 'zorblex', entityB: 'glimbit')]
        : [],
    boatCapacity: 1,
    optimalMoves: conflict
        ? 7
        : two
            ? 3
            : 1,
    maxMoves: maxMoves,
  );
  return {
    '_currentLevel': 1,
    '_puzzle': puzzle.toJson(),
    '_gameState': VoidCrossingGameState(
      leftStation: {
        for (final entity in entities)
          if (!prepared || entity.id != 'zorblex') entity.id,
      },
      rightStation: {},
      onShuttle: prepared ? {'zorblex'} : {},
      shuttleOnLeft: true,
      movesTaken: moves,
    ).toJson(),
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

Finder _launch(WidgetTester tester) => find
    .ancestor(
      of: find.text(_strings(tester).voidCrossingLaunch),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    )
    .first;

Future<void> _tapEntity(WidgetTester tester, String label) async {
  final entity = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label);
  expect(entity, findsOneWidget);
  await tester.tap(entity);
  await tester.pump();
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'void_rounds_${profile++}';
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_void_crossing': true});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });

  for (final moves in [0, 2]) {
    testWidgets(
        'restored win grades $moves prior moves against the real optimum',
        (tester) async {
      final app =
          await _mount(tester, board: _board(prepared: true, moves: moves));
      await tester.tap(_launch(tester));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(_launch(tester)).onPressed, isNull);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(app.gp.outcomeCount, 0);
      expect(_session(tester).capturePuzzleSession(), isNull);
      await _frames(tester, 25);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.movesUsed, moves + 1);
      expect(app.gp.lastOutcome!.optimalMoves, 1);
      expect(app.gp.lastOutcome!.performance, Perf.fromMoves(moves + 1, 1));
      if (moves > 0) expect(app.gp.lastOutcome!.performance, lessThan(1.0));
      expect(_dialog, findsOneWidget);
      await _frames(tester, 90);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }

  testWidgets('nonterminal crossing commits cargo and one move after animation',
      (tester) async {
    final app = await _mount(tester, board: _board(two: true, prepared: true));
    await tester.tap(_launch(tester));
    await tester.pump();
    await _frames(tester, 90);
    final state = _snapshot(tester)['_gameState'] as Map;
    expect(state['movesTaken'], 1);
    expect(state['shuttleOnLeft'], isFalse);
    expect(state['onShuttle'], isEmpty);
    expect(state['leftStation'], ['glimbit']);
    expect(state['rightStation'], ['zorblex']);
    expect(app.gp.outcomeCount, 0);
    expect(tester.widget<ElevatedButton>(_launch(tester)).onPressed, isNotNull);
    await _unmount(tester);
  });

  testWidgets('out-of-moves retry begins a fresh saveable session',
      (tester) async {
    final app = await _mount(tester,
        board: _board(two: true, prepared: true, moves: 2, maxMoves: 3));
    final s = _strings(tester);
    await tester.tap(_launch(tester));
    await tester.pump();
    await _frames(tester, 90);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).puzzleSessionFinished, isTrue);
    final retry = find.descendant(
        of: _dialog, matching: find.widgetWithText(ElevatedButton, s.tryAgain));
    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_session(tester).puzzleSessionFinished, isFalse);
    final state = _snapshot(tester)['_gameState'] as Map;
    expect(state['movesTaken'], 0);
    expect(state['leftStation'], ['zorblex', 'glimbit']);
    expect(state['rightStation'], isEmpty);
    expect(state['onShuttle'], isEmpty);
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });

  for (final reduced in [false, true]) {
    testWidgets('restoration cancels pending crossing (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(prepared: true));
      await tester.tap(_launch(tester));
      // With zero-duration feedback, completion is queued for a later frame.
      if (!reduced) await tester.pump(const Duration(milliseconds: 400));
      await _restore(tester, app, _board(two: true));
      final restored = _snapshot(tester);
      await _frames(tester, 100);
      expect(_snapshot(tester), restored);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      await _unmount(tester);
    });

    testWidgets('disposal cancels pending crossing (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(prepared: true));
      await tester.tap(_launch(tester));
      await _unmount(tester);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
    });
  }

  for (final initiallyReduced in [true, false]) {
    testWidgets(
        'reduced motion still completes one crossing (initial:$initiallyReduced)',
        (tester) async {
      final app = await _mount(tester,
          reduced: initiallyReduced, board: _board(prepared: true));
      await tester.tap(_launch(tester));
      if (!initiallyReduced) {
        await tester.pump(const Duration(milliseconds: 300));
        expect(app.gp.outcomeCount, 0);
        app.motion.value = true;
        await tester.pump();
      }
      await _frames(tester, 12);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.movesUsed, 1);
      expect(app.gp.lastOutcome!.optimalMoves, 1);
      expect(_dialog, findsOneWidget);
      app.motion.value = false;
      await tester.pump();
      await _frames(tester, 90);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }

  for (final action in ['restore', 'reset']) {
    testWidgets('$action clears a full-shuttle warning and its deadline',
        (tester) async {
      final app = await _mount(tester, board: _board(two: true));
      final s = _strings(tester);
      final warning = find.text(s.voidCrossingShuttleFull(1));
      await _tapEntity(tester, s.voidCrossingZorblex);
      await _tapEntity(tester, s.voidCrossingGlimbit);
      expect(warning, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      if (action == 'restore') {
        await _restore(tester, app, _board(two: true));
      } else {
        await tester.tap(find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == s.tryAgain));
        await tester.pump();
      }
      expect(warning, findsNothing);
      await _tapEntity(tester, s.voidCrossingZorblex);
      await _tapEntity(tester, s.voidCrossingGlimbit);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(warning, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(warning, findsNothing);
      expect(app.gp.outcomeCount, 0);
      await _unmount(tester);
    });
  }

  testWidgets('restoration clears a previous conflict warning', (tester) async {
    final app =
        await _mount(tester, board: _board(conflict: true, maxMoves: 10));
    final s = _strings(tester);
    await _tapEntity(tester, s.voidCrossingStarMoss);
    await tester.tap(_launch(tester));
    await tester.pump();
    expect(find.text(s.voidCrossingConflictWarning), findsOneWidget);
    expect((_snapshot(tester)['_gameState'] as Map)['movesTaken'], 0);
    await _restore(tester, app, _board());
    expect(find.text(s.voidCrossingConflictWarning), findsNothing);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets('Reduce motion suspends stars and resumes their forward loop',
      (tester) async {
    final app = await _mount(tester);
    final stars = find.byWidgetPredicate((widget) =>
        widget is AnimatedBuilder &&
        widget.animation is AnimationController &&
        (widget.animation as AnimationController).duration ==
            const Duration(seconds: 30));
    expect(stars, findsOneWidget);
    final controller =
        tester.widget<AnimatedBuilder>(stars).animation as AnimationController;
    expect(controller.isAnimating, isTrue);
    app.motion.value = true;
    await tester.pump();
    expect(controller.isAnimating, isFalse);
    final stopped = controller.value;
    await _frames(tester, 12);
    expect(controller.value, stopped);
    app.motion.value = false;
    await tester.pump();
    await _frames(tester, 12);
    expect(controller.isAnimating, isTrue);
    expect(controller.status, AnimationStatus.forward);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
}
