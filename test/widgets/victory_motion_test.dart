import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/mixins/puzzle_session_mixin.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/magic_triangles_game.dart';
import 'package:space_math_academy/features/games/screens/number_walls_game.dart';
import 'package:space_math_academy/features/games/screens/solarpanel_game.dart';
import 'package:space_math_academy/features/games/services/magic_triangle_puzzle.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _VictoryHarness extends StatefulWidget {
  const _VictoryHarness();

  @override
  State<_VictoryHarness> createState() => _VictoryHarnessState();
}

class _VictoryHarnessState extends State<_VictoryHarness>
    with SingleTickerProviderStateMixin, PuzzleSessionMixin<_VictoryHarness> {
  late AnimationController controller;
  int completions = 0;

  @override
  String get sessionGameKey => 'victory_motion_harness';
  @override
  int get sessionGrade => 1;
  @override
  int get sessionLevel => 1;
  @override
  Map<String, dynamic>? capturePuzzleSession() => null;
  @override
  void applyPuzzleSession(Map<String, dynamic> state) {}

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) =>
      updateOneShotMotion(controller, reduced,
          duration: const Duration(milliseconds: 500));

  void start() =>
      playOneShotMotion(controller, () => setState(() => completions++));

  void resetRound() {
    cancelOneShotMotion(controller);
    controller.reset();
    beginPuzzleSession();
  }

  @override
  void dispose() {
    disposePuzzleSession();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Completed $completions');
}

class _TestApp {
  final bool initiallyReduced;
  final Widget home;
  late final ValueNotifier<bool> motion = ValueNotifier(initiallyReduced);
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  late final GameProvider gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);

  _TestApp(this.home, {this.initiallyReduced = false});

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
          home: home,
        ),
      );
}

class _LoopHarness extends StatefulWidget {
  final bool reverse;
  const _LoopHarness({required this.reverse});

  @override
  State<_LoopHarness> createState() => _LoopHarnessState();
}

class _LoopHarnessState extends State<_LoopHarness>
    with SingleTickerProviderStateMixin, PuzzleSessionMixin<_LoopHarness> {
  late AnimationController controller;

  @override
  String get sessionGameKey => 'loop_motion_harness';
  @override
  int get sessionGrade => 1;
  @override
  int get sessionLevel => 1;
  @override
  Map<String, dynamic>? capturePuzzleSession() => null;
  @override
  void applyPuzzleSession(Map<String, dynamic> state) {}

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: widget.reverse);
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) =>
      updateDecorativeMotion([controller], reduced, reverse: widget.reverse);

  @override
  void dispose() {
    disposePuzzleSession();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Map<String, dynamic> _winningBoard(String game) {
  switch (game) {
    case 'magic_triangles':
      final puzzle = MagicTrianglePuzzle(
        circlesPerSide: 3,
        warpFrequency: 10,
        hiddenIndices: {0},
        visibleValues: {1: 4, 2: 5, 3: 2, 4: 3, 5: 6},
        allNumbers: [1, 4, 5, 2, 3, 6],
        numberPool: [1],
      );
      return {
        'currentPuzzle': puzzle.toJson(),
        'userAnswers': [null],
        'numberPool': [1],
        '_movesRemaining': 2,
        '_maxMoves': 2,
        '_optimalMoves': 1,
      };
    case 'number_walls':
      final puzzle = NumberWallPuzzle(
        wallHeight: 2,
        operation: WallOperation.addition,
        hiddenCells: {0},
        visibleValues: {1: 2, 2: 3},
        fullSolution: [5, 2, 3],
        numberPool: [5],
      );
      return {
        'puzzle': puzzle.toJson(),
        'answers': [null],
        'pool': [5],
        'moves': 2,
        'maxMoves': 2,
        'optimal': 1,
        'hints': 0,
      };
    default:
      final puzzle = SolarPanelPuzzle(
        baseNumbers: [2, 3, 5],
        hiddenCells: {0},
        visibleValues: {1: 6, 2: 15, 3: 2, 4: 3, 5: 5},
        fullSolution: [21, 6, 15, 2, 3, 5],
        numberPool: [21],
      );
      return {
        'currentPuzzle': puzzle.toJson(),
        'userAnswers': [null],
        'numberPool': [21],
        '_wrongChecks': 0,
      };
  }
}

void main() {
  var profileNumber = 0;
  setUp(() {
    // Isolate pending fire-and-forget saves without waiting across fake clocks.
    // Disk round trips are covered by all_games_sessions_test.dart.
    ProfilePreferences.activeId = 'victory_${profileNumber++}';
    final prefix = 'player_${ProfilePreferences.activeId}_';
    SharedPreferences.setMockInitialValues({
      '${prefix}onboarding_seen_number_walls_guided_v1': true,
      for (final key in ['magic_triangles', 'number_walls', 'solarpanel_game'])
        '${prefix}onboarding_seen_$key': true,
    });
    PuzzleSessionStore.resetForTesting();
  });

  for (final reverse in [false, true]) {
    testWidgets('decorative resume preserves reverse:$reverse cycle direction',
        (tester) async {
      final app = _TestApp(_LoopHarness(reverse: reverse));
      await tester.pumpWidget(app.build());
      await tester.pump();
      final state = tester.state<_LoopHarnessState>(find.byType(_LoopHarness));
      await tester.pump(const Duration(milliseconds: 750));
      app.motion.value = true;
      await tester.pump();
      expect(state.controller.isAnimating, isFalse);
      final pausedValue = state.controller.value;
      await tester.pump(const Duration(seconds: 1));
      expect(state.controller.value, pausedValue);
      app.motion.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(state.controller.status,
          reverse ? AnimationStatus.reverse : AnimationStatus.forward);
      final resumedValue = state.controller.value;
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.controller.value,
          reverse ? lessThan(resumedValue) : greaterThan(resumedValue));
      await tester.pumpWidget(const SizedBox.shrink());
      app.motion.dispose();
    });
  }

  testWidgets('one-shot victory completes once through reduced-motion toggles',
      (tester) async {
    final app = _TestApp(const _VictoryHarness());
    await tester.pumpWidget(app.build());
    final state =
        tester.state<_VictoryHarnessState>(find.byType(_VictoryHarness));
    state.start();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.completions, 0);
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    expect(state.completions, 1);
    for (final value in [false, true, false]) {
      app.motion.value = value;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(state.completions, 1);
    expect(state.controller.isAnimating, isFalse,
        reason: 'Completion effects must never resume as decorative loops');
    await tester.pumpWidget(const SizedBox.shrink());
    app.motion.dispose();
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'one-shot cancellation blocks stale completions (reduced:$reduced)',
        (tester) async {
      final app = _TestApp(const _VictoryHarness(), initiallyReduced: reduced);
      await tester.pumpWidget(app.build());
      final state =
          tester.state<_VictoryHarnessState>(find.byType(_VictoryHarness));
      state.start();
      state.resetRound();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(state.completions, 0,
          reason: 'Reset must cancel both running and queued completions');
      state.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(state.completions, 1);
      state.resetRound();
      state.start();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(state.completions, 1,
          reason: 'Disposal must cancel callbacks queued for a removed screen');
      expect(tester.takeException(), isNull);
      app.motion.dispose();
    });
  }

  for (final game in ['magic_triangles', 'number_walls', 'solarpanel_game']) {
    for (final scenario in [
      'normal',
      'initial',
      'mid-victory',
      'toggles',
      'restore',
      if (game == 'solarpanel_game') 'mid-panel',
    ]) {
      testWidgets('$game victory survives reduced motion $scenario',
          (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final home = switch (game) {
          'magic_triangles' => const MagicTrianglesGame(grade: 1, level: 1),
          'number_walls' => const NumberWallsGame(grade: 1, level: 1),
          _ => const SolarPanelGame(grade: 1, level: 1),
        };
        final app = _TestApp(home, initiallyReduced: scenario == 'initial');
        final screen = find.byType(home.runtimeType);
        await tester.pumpWidget(app.build());
        final dialog = game == 'solarpanel_game'
            ? find.text(S.of(tester.element(screen))!.solarPanelWinTitle)
            : find.byWidgetPredicate((widget) => widget is Dialog);
        dynamic session = tester.state(screen);
        for (var attempt = 0; attempt < 150; attempt++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          if (session.capturePuzzleSession() != null) break;
        }
        expect(session.capturePuzzleSession(), isNotNull);
        session.applyPuzzleSession(_winningBoard(game));
        // Trigger a dependency rebuild to display the restored board without
        // reaching into private game methods or introducing a testing seam.
        app.motion.value = !app.initiallyReduced;
        await tester.pump();
        app.motion.value = app.initiallyReduced;
        await tester.pump();

        final number = switch (game) {
          'magic_triangles' => 1,
          'number_walls' => 5,
          _ => 21,
        };
        final source = find.byWidgetPredicate(
            (widget) => widget is Draggable<int> && widget.data == number);
        final target = find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith('Empty ') &&
            (widget.properties.label ?? '').contains('drop a number here'));
        expect(source, findsOneWidget);
        expect(target, findsOneWidget);
        // DragTarget receives the feedback's top-left offset, so align that
        // point with the cell center rather than assuming a pointer anchor.
        await tester.drag(
            source, tester.getCenter(target) - tester.getTopLeft(source));
        await tester.pump();
        if (scenario == 'restore') {
          await tester.pump(const Duration(milliseconds: 100));
          final outcomesBeforeRestore = app.gp.outcomeCount;
          final scoreBeforeRestore = app.gp.score;
          session.applyPuzzleSession(_winningBoard(game));
          app.motion.value = true;
          await tester.pump();
          app.motion.value = false;
          await tester.pump();
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 500));
          }
          expect(dialog, findsNothing,
              reason:
                  'Restoring a board must invalidate the previous win effect');
          expect(app.gp.outcomeCount, outcomesBeforeRestore);
          expect(app.gp.score, scoreBeforeRestore);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          app.motion.dispose();
          return;
        }
        if (scenario != 'initial' && scenario != 'normal') {
          // Solar shows expansion before warp; the others start warp directly.
          if (game == 'solarpanel_game' && scenario != 'mid-panel') {
            await tester.pump(const Duration(milliseconds: 2100));
          }
          await tester.pump(const Duration(milliseconds: 100));
          expect(dialog, findsNothing,
              reason:
                  'This setting change must happen during victory animation');
          app.motion.value = true;
          await tester.pump();
          if (scenario == 'toggles') {
            app.motion.value = false;
            await tester.pump();
            app.motion.value = true;
            await tester.pump();
          }
        }
        // Coarse normal-motion pumps also need frames to start the next ticker
        // and build the dialog route after each deferred stage completes.
        for (var frame = 0; frame < (scenario == 'normal' ? 10 : 12); frame++) {
          await tester.pump(scenario == 'normal'
              ? const Duration(milliseconds: 500)
              : const Duration(milliseconds: 16));
        }
        expect(app.gp.outcomeCount, 1);
        expect(dialog, findsOneWidget,
            reason: 'A win must reach its completion dialog');
        final score = app.gp.score;
        app.motion.value = false;
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(app.gp.outcomeCount, 1);
        expect(app.gp.score, score);
        expect(dialog, findsOneWidget,
            reason: 'Changing motion preferences must not replay victory');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        app.motion.dispose();
      });
    }
  }
}
