import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_image_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/game_registry.dart';
import 'package:space_math_academy/shared/widgets/onboarding_overlay.dart';
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/puzzle_math_game.dart';
import 'package:space_math_academy/features/games/widgets/game_learning_shell.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'package:space_math_academy/generated/l10n.dart';

import 'support/round_dialog_finder.dart';

class _App {
  final Locale locale;
  final double scale;
  final ValueNotifier<bool> motion;
  final pause = GamePauseController();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App({this.locale = const Locale('en'), this.scale = 1, bool reduced = true})
      : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider.value(value: debug),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: motion,
            builder: (_, reduced, __) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale)),
              child: GamePauseScope(controller: pause, child: child!),
            ),
          ),
          home: const PuzzleMathGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(PuzzleMathGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
Map<String, dynamic> _snapshot(WidgetTester t) =>
    _copy(_state(t).capturePuzzleSession() as Map<String, dynamic>);
typedef _Drag = ({int pieceId, Object round});
int _pieceId(dynamic data) => data is int ? data : data.pieceId as int;
Finder _source(int id) =>
    find.byWidgetPredicate((w) => w is Draggable && _pieceId(w.data) == id);
final _targets = find.byWidgetPredicate((w) => w is DragTarget);
Finder _slot(int id) => _targets.at(id);
Finder _piece(int id, {bool placed = false}) => find.byWidgetPredicate((w) =>
    w is PuzzlePieceWidget &&
    w.data.id == id &&
    w.isPlaced == placed &&
    (placed ? w.onRemove != null : w.onRotate != null));

Map<String, dynamic> _board(
    {Map<int, int> placed = const {},
    int time = 120,
    int mistakes = 0,
    int rotation = 0,
    bool equalAnswers = false}) {
  final pieces = List.generate(
      4,
      (id) => PuzzlePieceData(
            id: id,
            row: id ~/ 2,
            col: id % 2,
            rotation: id == 0 ? rotation : 0,
            problem:
                MathProblem.addition(1, equalAnswers && id == 1 ? 1 : id + 1),
          ));
  // Independent arithmetic and spatial checks keep the fixture meaningful.
  for (final p in pieces) {
    expect(p.problem.operandA + p.problem.operandB, p.answer);
    expect(p.row * 2 + p.col, p.id);
  }
  return {
    'pieces': pieces.map((p) => p.toJson()).toList(),
    'placedPieces': placed.entries.map((e) => [e.key, e.value]).toList(),
    'columns': 2,
    'rows': 2,
    'currentPuzzleImage': 'assets/images/puzzle01.webp',
    '_misplacements': mistakes,
    '_edgeShapes': [
      ['h-0-0', 'knob'],
      ['h-1-0', 'hole'],
      ['v-0-0', 'knob'],
      ['v-0-1', 'hole'],
    ],
    '_time': time,
  };
}

Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic s = _state(t);
  s.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  s.setState(() => s.applyPuzzleSession(_copy(board)));
  await t.pump();
  await t.pump();
}

Future<_App> _mount(WidgetTester t,
    {Locale locale = const Locale('en'),
    double scale = 1,
    bool reduced = true,
    bool timed = true}) async {
  final app = _App(locale: locale, scale: scale, reduced: reduced);
  app.gp.setPuzzleTimer(timed);
  t.view.physicalSize = const Size(1400, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    app.motion.dispose();
    app.pause.dispose();
  });
  await t.runAsync(PuzzleImageService.instance.init);
  await t.pumpWidget(app.build());
  for (var i = 0; i < 30; i++) {
    await t.pump();
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    if (_state(t).capturePuzzleSession() != null) break;
  }
  expect(_state(t).capturePuzzleSession(), isNotNull);
  await _restore(t, _board());
  return app;
}

void _deliver(dynamic target, dynamic data) {
  if (data is int) {
    target.onAcceptWithDetails!(
        DragTargetDetails<int>(data: data, offset: Offset.zero));
  } else {
    target.onAcceptWithDetails!(
        DragTargetDetails<_Drag>(data: data as _Drag, offset: Offset.zero));
  }
}

Future<void> _drop(WidgetTester t, int id, int slot) async {
  await t.ensureVisible(_source(id));
  await t.pump();
  expect(_source(id).hitTestable(), findsOneWidget);
  await t.drag(
      _source(id), t.getCenter(_slot(slot)) - t.getCenter(_source(id)));
  await t.pump();
}

Future<void> _dialog(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(roundDialogs, findsOneWidget);
}

Future<void> _finish(WidgetTester t) async {
  await _restore(t, _board(placed: {0: 0, 1: 1, 2: 2}));
  await _drop(t, 3, 3);
  await _dialog(t);
}

Finder _retry() => find
    .descendant(
        of: roundDialogs,
        matching: find.byWidgetPredicate((w) =>
            w is ButtonStyleButton && w.onPressed != null && w.child is Text))
    .first;
VoidCallback _retryCallback(WidgetTester t) =>
    t.widget<ButtonStyleButton>(_retry()).onPressed!;
VoidCallback _backCallback(WidgetTester t) =>
    t.widget<IconButton>(find.byType(IconButton).first).onPressed!;
Future<void> _cover(WidgetTester t) async {
  showDialog<void>(
      context: t.element(_screen),
      builder: (_) => const AlertDialog(content: Text('Covering route')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'puzzle_math_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues({});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('contract: actual drop and removal return the same physical tile',
      (t) async {
    final app = await _mount(t);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
    expect(_source(0), findsNothing);
    await t.tap(_piece(0, placed: true));
    await t.pump();
    expect(_snapshot(t)['placedPieces'], isEmpty);
    expect(_source(0), findsOneWidget);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets('contract: actual wrong-answer drop persists one mistake',
      (t) async {
    final app = await _mount(t);
    // Flush the restored board first, so its pending save cannot hide a missing
    // state notification from the rejected drop.
    await t.pump(const Duration(milliseconds: 800));
    await PuzzleSessionStore.instance.flush();
    await _drop(t, 0, 1);
    expect(_snapshot(t)['placedPieces'], isEmpty);
    expect(_snapshot(t)['_misplacements'], 1);
    expect(app.gp.outcomeCount, 0);
    await t.pump(const Duration(milliseconds: 800));
    await PuzzleSessionStore.instance.flush();
    final saved = await PuzzleSessionStore.instance.load('puzzle_math', 1, 1);
    expect(saved!['_misplacements'], 1);
    await _restore(t, saved);
    expect(_snapshot(t), saved);
  });
  testWidgets(
      'contract: pointer rotation rejects a turned piece until a full turn',
      (t) async {
    await _mount(t);
    await t.tap(_piece(0));
    await t.pump();
    expect((_snapshot(t)['pieces'] as List).first['rotation'], 90);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], isEmpty);
    expect(_snapshot(t)['_misplacements'], 1);
    for (var i = 0; i < 3; i++) {
      await t.tap(_piece(0));
      await t.pump();
    }
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
  });
  testWidgets(
      'contract: equal answers remain interchangeable without tile duplication',
      (t) async {
    await _mount(t);
    await _restore(t, _board(equalAnswers: true));
    final dynamic originalTarget = t.widget(_slot(1));
    final dynamic source = t.widget(_source(0));
    await _drop(t, 0, 1);
    expect(_snapshot(t)['placedPieces'], [
      [1, 0]
    ]);
    _deliver(t.widget(_slot(0)), source.data);
    _deliver(originalTarget, t.widget<Draggable>(_source(1)).data);
    await t.pump();
    expect(_snapshot(t)['placedPieces'], [
      [1, 0]
    ]);
    await _drop(t, 1, 0);
    expect(_snapshot(t)['placedPieces'], [
      [1, 0],
      [0, 1]
    ]);
  });
  testWidgets(
      'contract: old target and old payload cannot mutate replacement round',
      (t) async {
    await _mount(t);
    final dynamic target = t.widget(_slot(0));
    final dynamic source = t.widget(_source(0));
    final before = _snapshot(t);
    await _restore(t, before);
    _deliver(target, source.data);
    _deliver(t.widget(_slot(0)), source.data);
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets('contract: unknown tile payload is rejected without exception',
      (t) async {
    await _mount(t);
    final dynamic source = t.widget(_source(0));
    final dynamic data = source.data;
    final dynamic invalid =
        data is int ? 999 : (pieceId: 999, round: data.round as Object);
    final before = _snapshot(t);
    _deliver(t.widget(_slot(0)), invalid);
    await t.pump();
    expect(t.takeException(), isNull);
    expect(_snapshot(t), before);
  });
  testWidgets('contract: actual drag overlay cannot cross restore', (t) async {
    await _mount(t);
    final g = await t.startGesture(t.getCenter(_source(0)));
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    final before = _snapshot(t);
    await _restore(t, before);
    await g.moveTo(t.getCenter(_slot(0)));
    await g.up();
    await t.pump();
    expect(_snapshot(t), before);
  });
  for (final placed in [false, true]) {
    testWidgets(
        'contract: retained ${placed ? 'removal' : 'rotation'} cannot mutate restored round',
        (t) async {
      await _mount(t);
      if (placed) await _drop(t, 0, 0);
      final piece = t.widget<PuzzlePieceWidget>(_piece(0, placed: placed));
      final callback = placed ? piece.onRemove! : piece.onRotate!;
      final before = _snapshot(t);
      await _restore(t, before);
      callback();
      await t.pump();
      expect(_snapshot(t), before);
    });
    testWidgets(
        'contract: pointer-down ${placed ? 'removal' : 'rotation'} cannot cross restore',
        (t) async {
      await _mount(t);
      if (placed) await _drop(t, 0, 0);
      final g = await t.startGesture(t.getCenter(_piece(0, placed: placed)));
      final before = _snapshot(t);
      await _restore(t, before);
      await g.up();
      await t.pump();
      expect(_snapshot(t), before);
    });
  }
  testWidgets(
      'contract: old timer switch and back callbacks cannot change restored round',
      (t) async {
    final app = await _mount(t);
    final toggle = t.widget<Switch>(find.byType(Switch)).onChanged!;
    final back = _backCallback(t);
    final before = _snapshot(t);
    await _restore(t, before);
    toggle(false);
    back();
    await t.pump();
    expect(app.gp.puzzleTimerEnabled, isTrue);
    expect(_snapshot(t), before);
    expect(_screen, findsOneWidget);
  });
  for (final timerControl in [true, false]) {
    testWidgets(
        'contract: pointer-down ${timerControl ? 'timer' : 'back'} cannot cross restore',
        (t) async {
      final app = await _mount(t);
      final control =
          timerControl ? find.byType(Switch) : find.byType(IconButton).first;
      final g = await t.startGesture(t.getCenter(control));
      final before = _snapshot(t);
      await _restore(t, before);
      await g.up();
      await t.pump();
      expect(app.gp.puzzleTimerEnabled, isTrue);
      expect(_screen, findsOneWidget);
      expect(_snapshot(t), before);
    });
  }
  testWidgets('contract: retained input after disposal has no effect',
      (t) async {
    final app = await _mount(t);
    final rotate = t.widget<PuzzlePieceWidget>(_piece(0)).onRotate!;
    final toggle = t.widget<Switch>(find.byType(Switch)).onChanged!;
    final back = _backCallback(t);
    final dynamic target = t.widget(_slot(0));
    final dynamic source = t.widget(_source(0));
    await t.pumpWidget(const SizedBox.shrink());
    rotate();
    toggle(false);
    back();
    _deliver(target, source.data);
    await t.pump(const Duration(seconds: 2));
    expect(app.gp.puzzleTimerEnabled, isTrue);
    expect(app.gp.outcomeCount, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets('contract: back callback cannot dismiss a covering route',
      (t) async {
    await _mount(t);
    final back = _backCallback(t);
    await _cover(t);
    back();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
  });
  testWidgets(
      'contract: timer expires on the tick from one to zero exactly once',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(time: 1, placed: {0: 0}));
    await t.pump(const Duration(seconds: 1));
    await _dialog(t);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(app.gp.lastOutcome!.performance, Perf.forLoss(progress: .25));
    expect(_state(t).capturePuzzleSession(), isNull);
    await t.pump(const Duration(seconds: 5));
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets(
      'contract: last-second solve wins and cancelled timer cannot lose afterwards',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(time: 1, placed: {0: 0, 1: 1, 2: 2}));
    await _drop(t, 3, 3);
    await _dialog(t);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(app.gp.lastOutcome!.score, 102);
    await t.pump(const Duration(seconds: 3));
    expect(app.gp.outcomeCount, 1);
    expect(roundDialogs, findsOneWidget);
  });
  testWidgets(
      'contract: pause preserves countdown and resume consumes one second',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(time: 3));
    app.pause.setPaused(true);
    await t.pump(const Duration(seconds: 5));
    expect(_snapshot(t)['_time'], 3);
    expect(app.gp.outcomeCount, 0);
    app.pause.setPaused(false);
    await t.pump(const Duration(seconds: 1));
    expect(_snapshot(t)['_time'], 2);
  });
  testWidgets(
      'contract: restored round replaces old timer rather than ticking twice',
      (t) async {
    await _mount(t);
    await _restore(t, _board(time: 1));
    await t.pump(const Duration(milliseconds: 500));
    await _restore(t, _board(time: 8));
    await t.pump(const Duration(milliseconds: 500));
    expect(_snapshot(t)['_time'], 8);
    await t.pump(const Duration(milliseconds: 500));
    expect(_snapshot(t)['_time'], 7);
  });
  testWidgets(
      'contract: disabled timer keeps zero-time restored board playable',
      (t) async {
    final app = await _mount(t, timed: false);
    await _restore(t, _board(time: 0));
    await t.pump(const Duration(seconds: 3));
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
    expect(app.gp.outcomeCount, 0);
  });
  for (final solved in [false, true]) {
    testWidgets(
        'contract: restored ${solved ? 'solved' : 'expired'} board offers retry without outcome replay',
        (t) async {
      final app = await _mount(t);
      await _restore(
          t,
          _board(
              time: solved ? 25 : 0,
              placed: solved ? {0: 0, 1: 1, 2: 2, 3: 3} : {0: 0}));
      await _dialog(t);
      expect(app.gp.outcomeCount, 0);
      expect(_state(t).capturePuzzleSession(), isNull);
      await t.pump(const Duration(seconds: 2));
      expect(app.gp.outcomeCount, 0);
      await t.ensureVisible(_retry());
      await t.tap(_retry());
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_state(t).capturePuzzleSession(), isNotNull);
      expect(app.gp.outcomeCount, 0);
    });
  }
  testWidgets(
      'contract: terminal callbacks cannot replay outcome or alter learning record',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: {0: 0, 1: 1, 2: 2}, mistakes: 2));
    final dynamic target = t.widget(_slot(3));
    final dynamic source = t.widget(_source(3));
    final toggle = t.widget<Switch>(find.byType(Switch)).onChanged!;
    await _drop(t, 3, 3);
    await _dialog(t);
    final outcome = app.gp.lastOutcome!;
    expect(outcome.performance, .8);
    expect(outcome.mathProblems.length, 4);
    _deliver(target, source.data);
    toggle(false);
    await t.pump();
    expect(app.gp.outcomeCount, 1);
    expect(identical(app.gp.lastOutcome, outcome), isTrue);
    expect(app.gp.puzzleTimerEnabled, isTrue);
    expect(_state(t).capturePuzzleSession(), isNull);
  });
  Finder suggestion() => find.descendant(
      of: find.byType(RoundSummary),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  testWidgets('contract: suggested challenge cannot dismiss a covering route',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    final callback = t.widget<ButtonStyleButton>(suggestion()).onPressed!;
    await _cover(t);
    callback();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets(
      'contract: suggested challenge cannot navigate after a round restore',
      (t) async {
    await _mount(t);
    await _finish(t);
    final callback = t.widget<ButtonStyleButton>(suggestion()).onPressed!;
    await _restore(t, _board(time: 80));
    await t.pump(const Duration(milliseconds: 400));
    expect(roundDialogs, findsNothing);
    final before = _snapshot(t);
    callback();
    await t.pump();
    expect(roundDialogs, findsNothing);
    expect(_snapshot(t), before);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
  });
  testWidgets('contract: restore clears a loss dialog and accepts new input',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(time: 1));
    await t.pump(const Duration(seconds: 1));
    await _dialog(t);
    final retry = _retryCallback(t);
    final outcome = app.gp.lastOutcome;
    await _restore(t, _board(time: 80));
    await t.pump(const Duration(milliseconds: 400));
    expect(roundDialogs, findsNothing);
    retry();
    await t.pump();
    expect(_snapshot(t)['_time'], 80);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
    expect(app.gp.outcomeCount, 1);
    expect(identical(app.gp.lastOutcome, outcome), isTrue);
  });
  testWidgets('contract: restore removes a result route before its first build',
      (t) async {
    final app = await _mount(t);
    await _restore(t, _board(placed: {0: 0, 1: 1, 2: 2}));
    final dynamic target = t.widget(_slot(3));
    final dynamic source = t.widget(_source(3));
    _deliver(target, source.data);
    expect(app.gp.outcomeCount, 1);
    // Do not pump the just-pushed result route before replacing the round.
    await _restore(t, _board(time: 80));
    await t.pump(const Duration(milliseconds: 400));
    expect(roundDialogs, findsNothing);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
    expect(app.gp.outcomeCount, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'contract: restore removes only its result beneath a covering route',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    final retry = _retryCallback(t);
    await _cover(t);
    await _restore(t, _board(time: 80));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Covering route'), findsOneWidget);
    // Include offstage routes: an obsolete result must not remain underneath.
    expect(find.byType(RoundSummary, skipOffstage: false), findsNothing);
    retry();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
    await t.tapAt(const Offset(10, 10));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(roundDialogs, findsNothing);
    await _drop(t, 0, 0);
    expect(_snapshot(t)['placedPieces'], [
      [0, 0]
    ]);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: actual suggested challenge opens a playable game',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    await t.runAsync(
        () => OnboardingOverlay.markSeen('puzzle_math_all_games_guided_v1'));
    await t.runAsync(() => loadGameLibrary('puzzle_math'));
    final original = _state(t);
    await t.ensureVisible(suggestion());
    await t.tap(suggestion());
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 30; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 50));
      if (_screen.evaluate().length == 1 &&
          !identical(_state(t), original) &&
          _state(t).capturePuzzleSession() != null) {
        break;
      }
    }
    expect(_screen, findsOneWidget);
    expect(identical(_state(t), original), isFalse);
    expect(roundDialogs, findsNothing);
    expect(_snapshot(t)['placedPieces'], isEmpty);
    expect(app.gp.outcomeCount, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('contract: actual retry starts one new playable round',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    await t.tap(_retry());
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(roundDialogs, findsNothing);
    expect(_snapshot(t)['placedPieces'], isEmpty);
    expect(_snapshot(t)['_misplacements'], 0);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: retained retry cannot dismiss covering route',
      (t) async {
    final app = await _mount(t);
    await _finish(t);
    final retry = _retryCallback(t);
    await _cover(t);
    retry();
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: old retry cannot replace a newly restored round',
      (t) async {
    await _mount(t);
    await _finish(t);
    final retry = _retryCallback(t);
    await t.tap(_retry());
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await _restore(t, _board(time: 80, mistakes: 1));
    final before = _snapshot(t);
    retry();
    await t.pump();
    expect(_snapshot(t), before);
  });
  for (final locale in ['en', 'de']) {
    for (final height in [500.0, 844.0]) {
      testWidgets(
          'contract: phone text-scale2 controls and retry reachable ($locale $height)',
          (t) async {
        await _mount(t, locale: Locale(locale), scale: 2);
        t.view.physicalSize = Size(390, height);
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.byType(Switch).hitTestable(), findsOneWidget);
        await _drop(t, 0, 0);
        expect(_snapshot(t)['placedPieces'], [
          [0, 0]
        ]);
        await _restore(t, _board(time: 1));
        await t.pump(const Duration(seconds: 1));
        await _dialog(t);
        expect(t.takeException(), isNull);
        await t.ensureVisible(_retry());
        await t.pump();
        expect(_retry().hitTestable(), findsOneWidget);
      });
    }
  }
  for (final reducedInitially in [true, false]) {
    testWidgets(
        'contract: ${reducedInitially ? 'initial' : 'mid-hover'} reduced motion keeps drop and win reachable',
        (t) async {
      final app = await _mount(t, reduced: reducedInitially);
      await _restore(t, _board(placed: {0: 0, 1: 1, 2: 2}));
      final g = await t.startGesture(t.getCenter(_source(3)));
      await g.moveTo(t.getCenter(_slot(3)));
      await t.pump(const Duration(milliseconds: 50));
      app.motion.value = true;
      await t.pump();
      final hover = find.descendant(
          of: _slot(3), matching: find.byType(AnimatedContainer));
      expect(hover, findsOneWidget);
      final container = t.widget<AnimatedContainer>(hover);
      expect(container.duration, Duration.zero);
      final painted =
          find.descendant(of: hover, matching: find.byType(DecoratedBox)).first;
      expect(t.widget<DecoratedBox>(painted).decoration, container.decoration);
      await g.up();
      await _dialog(t);
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
      expect(t.takeException(), isNull);
    });
  }
}
