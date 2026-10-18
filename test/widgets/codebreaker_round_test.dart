import 'support/round_dialog_finder.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'dart:convert';
import 'dart:async';
import 'package:space_math_academy/features/games/services/codebreaker_logic.dart';

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
import 'package:space_math_academy/features/games/screens/codebreaker_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final Locale locale;
  final double scale;
  final bool pushed;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  _App(
      {bool reduced = false,
      this.locale = const Locale('en'),
      this.scale = 1,
      this.pushed = false})
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
                  textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: pushed
              ? Builder(
                  builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const CodebreakerGame(grade: 1, level: 1))),
                      child: const Text('Start codebreaker')))
              : const CodebreakerGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CodebreakerGame);
dynamic _state(WidgetTester t) => t.state(_screen);
Map<String, dynamic> _snapshot(WidgetTester t) =>
    jsonDecode(jsonEncode(_state(t).capturePuzzleSession()))
        as Map<String, dynamic>;
final _targets = find.byWidgetPredicate((w) => w is DragTarget);
typedef _Payload = ({int number, Object round});
int _number(dynamic data) => data is int ? data : data.number as int;
Finder _source(WidgetTester t, int number) => find
    .byWidgetPredicate((w) => w is Draggable && _number(w.data) == number)
    .first;
Finder _filled(WidgetTester t, int n) => find.descendant(
    of: find.byWidgetPredicate((w) =>
        w is Semantics &&
        w.properties.label == S.of(t.element(_screen))!.a11yPlacedValue('$n')),
    matching:
        find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null));
// Use the actual widgets and both payload shapes so these regressions also run
// against the previous integer-payload implementation as negative controls.
void _deliver(dynamic target, dynamic data) {
  if (data is int) {
    target.onAcceptWithDetails!(
        DragTargetDetails<int>(data: data, offset: Offset.zero));
  } else {
    target.onAcceptWithDetails!(DragTargetDetails<_Payload>(
        data: data as _Payload, offset: Offset.zero));
  }
}

AdvancedCodebreakerPuzzle _puzzle() => AdvancedCodebreakerPuzzle(
      knownSymbolValues: {},
      equations: [
        PuzzleEquation(term1: 'nebula', op: '+', term2: 1, result: 3),
        PuzzleEquation(term1: 'nebula', op: '+', term2: 'star', result: 5),
        PuzzleEquation(term1: 'planet', op: '+', term2: 1, result: 5),
      ],
      hiddenSymbols: {'nebula', 'star', 'planet'},
      numberPool: [2, 2, 3, 4, 7, 7, 8, 9],
      hiddenPositions: ['eq0_term1', 'eq1_term1', 'eq1_term2', 'eq2_term1'],
      fullSolution: {'nebula': 2, 'star': 3, 'planet': 4},
      visiblePositions: {},
    );
Map<String, dynamic> _board(
        {Map<String, int> answers = const {}, int moves = 6}) =>
    {
      'puzzle': _puzzle().toJson(),
      'answers': answers,
      'moves': moves,
      'maxMoves': 6,
      'optimal': 3,
      'pool': [2, 2, 3, 4, 7, 7, 8, 9],
    };
Future<void> _restore(WidgetTester t, Map<String, dynamic> board) async {
  final dynamic s = _state(t);
  s.beginPuzzleSession();
  // ignore: invalid_use_of_protected_member
  s.setState(() => s.applyPuzzleSession(
      jsonDecode(jsonEncode(board)) as Map<String, dynamic>));
  await t.pump();
  await t.pump();
}

Future<_App> _mount(WidgetTester t,
    {bool reduced = true,
    Locale locale = const Locale('en'),
    double scale = 1,
    bool pushed = false}) async {
  final app =
      _App(reduced: reduced, locale: locale, scale: scale, pushed: pushed);
  t.view.physicalSize = const Size(1400, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(app.motion.dispose);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
  await t.pumpWidget(app.build());
  if (pushed) {
    await t.tap(find.text('Start codebreaker'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 20));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_state(t).capturePuzzleSession() != null) break;
  }
  expect(_state(t).capturePuzzleSession(), isNotNull);
  final p = _puzzle();
  expect(
      p.validateSolution(
          {'eq0_term1': 2, 'eq1_term1': 2, 'eq1_term2': 3, 'eq2_term1': 4}),
      isTrue);
  await _restore(t, _board());
  return app;
}

Future<void> _drop(WidgetTester t, int value, int targetIndex) async {
  final source = _source(t, value);
  final target = _targets.at(targetIndex);
  await t.ensureVisible(source);
  await t.ensureVisible(target);
  await t.pump();
  expect(source.hitTestable(), findsOneWidget);
  expect(target.hitTestable(), findsOneWidget);
  await t.drag(source, t.getCenter(target) - t.getCenter(source));
  await t.pump();
}

Future<void> _settleDialog(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 1700));
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _last(WidgetTester t, {required bool correct}) async {
  final b = _board(
      answers: {'eq0_term1': 2, 'eq1_term1': 2, 'eq1_term2': 3}, moves: 1);
  b['pool'] = [2, 4, 7, 7, 8, 9];
  await _restore(t, b);
  await _drop(t, correct ? 4 : 7, 0);
  await _settleDialog(t);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'codebreaker_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_codebreaker': true});
    PuzzleSessionStore.resetForTesting();
  });
  testWidgets(
      'contract: real drop fills repeated symbol and consumes one assignment token',
      (t) async {
    final app = await _mount(t);
    await _drop(t, 2, 0);
    final s = _snapshot(t);
    expect(s['answers'], {'eq0_term1': 2, 'eq1_term1': 2});
    expect(s['moves'], 5);
    expect(s['pool'], [2, 3, 4, 7, 7, 8, 9]);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets(
      'contract: duplicate pool values preserve different symbol assignments',
      (t) async {
    await _mount(t);
    await _drop(t, 7, 0);
    await _drop(t, 7, 0);
    expect(_snapshot(t)['answers'],
        {'eq0_term1': 7, 'eq1_term1': 7, 'eq1_term2': 7});
    expect((_snapshot(t)['pool'] as List).where((n) => n == 7), isEmpty);
  });
  testWidgets('contract: a retained target cannot reuse a consumed tile',
      (t) async {
    await _mount(t);
    final dynamic target = t.widget(_targets.first);
    final dynamic source = t.widget(_source(t, 3));
    _deliver(target, source.data);
    await t.pump();
    final before = _snapshot(t);
    _deliver(target, source.data);
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: both old target and old payload reject replacement round',
      (t) async {
    final app = await _mount(t);
    final dynamic target = t.widget(_targets.first);
    final dynamic source = t.widget(_source(t, 2));
    final before = _snapshot(t);
    await _restore(t, before);
    _deliver(target, source.data);
    _deliver(t.widget(_targets.first), source.data);
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });
  testWidgets('contract: real drag overlay cannot cross restoration',
      (t) async {
    await _mount(t);
    final source = _source(t, 2);
    final g = await t.startGesture(t.getCenter(source));
    await g.moveBy(const Offset(20, 0));
    await t.pump();
    final before = _snapshot(t);
    await _restore(t, before);
    await g.moveTo(t.getCenter(_targets.first));
    await g.up();
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: filled pointer-down before restore cannot remove new answers',
      (t) async {
    await _mount(t);
    await _drop(t, 2, 0);
    final filled = _filled(t, 2).first;
    final g = await t.startGesture(t.getCenter(filled));
    final before = _snapshot(t);
    await _restore(t, before);
    await g.up();
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: last legal correct drop wins once with symbol move par',
      (t) async {
    final app = await _mount(t);
    await _last(t, correct: true);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(app.gp.lastOutcome!.movesUsed, 6);
    expect(app.gp.lastOutcome!.optimalMoves, 3);
    expect(_state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
  });
  testWidgets('contract: full incorrect last drop loses once', (t) async {
    final app = await _mount(t);
    await _last(t, correct: false);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(app.gp.outcomeCount, 1);
  });
  testWidgets('contract: terminal target cannot mutate outcome or board',
      (t) async {
    final app = await _mount(t);
    final dynamic target = t.widget(_targets.first);
    final dynamic source = t.widget(_source(t, 7));
    await _last(t, correct: true);
    final before = jsonEncode(_state(t).userSolution);
    final problems =
        app.gp.lastOutcome!.mathProblems.map((p) => p.expression).toList();
    _deliver(target, source.data);
    await t.pump();
    expect(jsonEncode(_state(t).userSolution), before);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.mathProblems.map((p) => p.expression), problems);
  });
  testWidgets(
      'contract: full wrong board stays editable and persists while budget remains',
      (t) async {
    final app = await _mount(t);
    await _drop(t, 2, 0);
    await _drop(t, 3, 0);
    await _drop(t, 7, 0);
    expect(app.gp.outcomeCount, 0);
    expect(_state(t).puzzleSessionFinished, isFalse);
    _state(t).savePuzzleSession();
    await PuzzleSessionStore.instance.flush();
    final saved = await PuzzleSessionStore.instance.load('codebreaker', 1, 1);
    expect(saved!['answers'], _snapshot(t)['answers']);
    expect(saved['moves'], 3);
    final remove = _filled(t, 7).first;
    await t.tap(remove);
    await t.pump();
    expect((_snapshot(t)['answers'] as Map).length, lessThan(4));
  });
  for (final solved in [false, true]) {
    testWidgets(
        'contract: restored terminal board offers retry without replay (solved:$solved)',
        (t) async {
      final app = await _mount(t);
      await _restore(
          t,
          _board(
              answers: solved
                  ? {
                      'eq0_term1': 2,
                      'eq1_term1': 2,
                      'eq1_term2': 3,
                      'eq2_term1': 4
                    }
                  : {},
              moves: solved ? 3 : 0));
      await _settleDialog(t);
      expect(_state(t).capturePuzzleSession(), isNull);
      expect(roundDialogs, findsOneWidget);
      expect(app.gp.outcomeCount, 0);
    });
  }
  for (final reduced in [false, true]) {
    for (final correct in [false, true]) {
      testWidgets(
          'contract: real retry is playable (won:$correct reduced:$reduced)',
          (t) async {
        final app = await _mount(t, reduced: reduced);
        await _last(t, correct: correct);
        expect(roundDialogs, findsOneWidget);
        final retry = find
            .descendant(of: roundDialogs, matching: find.byType(ElevatedButton))
            .first;
        await t.ensureVisible(retry);
        await t.tap(retry);
        for (var i = 0; i < 150; i++) {
          await t.pump(const Duration(milliseconds: 20));
          await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          if (_state(t).capturePuzzleSession() != null) break;
        }
        await t.pump(const Duration(milliseconds: 400));
        expect(roundDialogs, findsNothing);
        final before = _snapshot(t);
        await _drop(t, (before['pool'] as List).first as int, 0);
        expect(_snapshot(t)['moves'], (before['moves'] as int) - 1);
        expect(app.gp.outcomeCount, 1);
      });
    }
    testWidgets(
        'contract: drop respects initial and mid-animation reduced motion (initial:$reduced)',
        (t) async {
      final app = await _mount(t, reduced: reduced);
      await _drop(t, 2, 0);
      await t.pump(const Duration(milliseconds: 100));
      if (!reduced) {
        app.motion.value = true;
        await t.pump();
        await t.pump();
      }
      final scales = t.widgetList<ScaleTransition>(find.ancestor(
          of: _filled(t, 2), matching: find.byType(ScaleTransition)));
      expect(scales, isNotEmpty);
      for (final scale in scales) {
        if (scale.scale is CurvedAnimation) {
          expect(scale.scale.value, 1);
          expect(scale.scale.status, AnimationStatus.completed);
        }
      }
      expect(_snapshot(t)['moves'], 5);
    });
  }
  testWidgets('contract: retained removal cannot clear restored assignment',
      (t) async {
    await _mount(t);
    await _drop(t, 2, 0);
    final old = t.widget<GestureDetector>(_filled(t, 2).first);
    final before = _snapshot(t);
    await _restore(t, before);
    old.onTap!();
    await t.pump();
    expect(_snapshot(t), before);
  });
  testWidgets('contract: restore clears drop animation and queued feedback',
      (t) async {
    await _mount(t, reduced: false);
    await _drop(t, 2, 0);
    await t.pump(const Duration(milliseconds: 100));
    final before = _snapshot(t);
    await _restore(t, before);
    expect(
        find.ancestor(
            of: _filled(t, 2), matching: find.byType(ScaleTransition)),
        findsNothing);
    expect(_snapshot(t), before);
  });
  for (final locale in ['en', 'de']) {
    for (final height in [500.0, 844.0]) {
      testWidgets(
          'contract: large-text phone controls and retry reachable ($locale $height)',
          (t) async {
        await _mount(t, locale: Locale(locale), scale: 2);
        t.view.physicalSize = Size(390, height);
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull);
        final tile = _source(t, 2);
        await t.ensureVisible(tile);
        await t.pump();
        expect(tile.hitTestable(), findsOneWidget);
        await _last(t, correct: false);
        expect(t.takeException(), isNull);
        final retry = find
            .descendant(of: roundDialogs, matching: find.byType(ElevatedButton))
            .first;
        await t.ensureVisible(retry);
        await t.pump();
        expect(retry.hitTestable(), findsOneWidget);
      });
    }
  }
  testWidgets('contract: back callback cannot dismiss a covering route',
      (t) async {
    await _mount(t);
    final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final context = t.element(_screen);
    showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Covering route')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final route = ModalRoute.of(t.element(find.text('Covering route')))!;
    back();
    expect(route.isCurrent, isTrue);
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
  });
  testWidgets('contract: retained retry cannot dismiss a covering route',
      (t) async {
    await _mount(t);
    await _last(t, correct: false);
    final retry = t
        .widget<ElevatedButton>(find
            .descendant(of: roundDialogs, matching: find.byType(ElevatedButton))
            .first)
        .onPressed!;
    showDialog<void>(
        context: t.element(_screen),
        builder: (_) => const AlertDialog(content: Text('Covering route')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final route = ModalRoute.of(t.element(find.text('Covering route')))!;
    retry();
    expect(route.isCurrent, isTrue);
    await t.pump();
    expect(find.text('Covering route'), findsOneWidget);
  });
  testWidgets('contract: retained retry cannot regenerate a replacement round',
      (t) async {
    final app = await _mount(t);
    await _last(t, correct: false);
    final retry = t
        .widget<ElevatedButton>(find
            .descendant(of: roundDialogs, matching: find.byType(ElevatedButton))
            .first)
        .onPressed!;
    Navigator.of(t.element(roundDialogs)).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await _restore(t, _board());
    final before = _snapshot(t);
    retry();
    await t.pump();
    expect(_snapshot(t), before);
    expect(app.gp.outcomeCount, 1);
    expect(roundDialogs, findsNothing);
  });
  testWidgets('contract: back pointer-down before restore cannot pop new round',
      (t) async {
    await _mount(t, pushed: true);
    final back = find.byIcon(Icons.arrow_back_ios);
    final g = await t.startGesture(t.getCenter(back));
    final before = _snapshot(t);
    await _restore(t, before);
    await g.up();
    await t.pump(const Duration(milliseconds: 400));
    expect(_screen, findsOneWidget);
    expect(_snapshot(t), before);
  });
  testWidgets(
      'contract: removal returns one token for a repeated-symbol assignment',
      (t) async {
    await _mount(t);
    await _drop(t, 7, 0);
    await _drop(t, 7, 0);
    await t.tap(_filled(t, 7).first);
    await t.pump();
    expect(_snapshot(t)['answers'], {'eq1_term2': 7});
    expect((_snapshot(t)['pool'] as List).where((n) => n == 7).length, 1);
    expect(_snapshot(t)['moves'], 4);
  });
  testWidgets(
      'contract: autofill never writes a visible occurrence into answers',
      (t) async {
    await _mount(t);
    final board = _board();
    final p = board['puzzle'] as Map<String, dynamic>;
    p['hiddenPositions'] = ['eq1_term1', 'eq1_term2', 'eq2_term1'];
    p['visiblePositions'] = ['eq0_term1'];
    await _restore(t, board);
    await _drop(t, 2, 0);
    expect(_snapshot(t)['answers'], {'eq1_term1': 2});
    expect(_snapshot(t)['moves'], 5);
  });
  for (final fail in [false, true]) {
    testWidgets(
        'controlled generation: obsolete ${fail ? "failure" : "success"} cannot replace a restored round',
        (t) async {
      final app = await _mount(t);
      final pending = Completer<AdvancedCodebreakerPuzzle>();
      final Future<void> completed =
          _state(t).generateForTesting(pending.future) as Future<void>;
      expect(_state(t).capturePuzzleSession(), isNull);
      await _restore(t, _board(moves: 4));
      final before = _snapshot(t);
      if (fail) {
        pending.completeError(StateError('obsolete generation'));
      } else {
        pending.complete(_puzzle());
      }
      await completed;
      await t.pump();
      expect(_snapshot(t), before);
      expect(roundDialogs, findsNothing);
      expect(app.gp.outcomeCount, 0);
    });
  }
  testWidgets(
      'controlled generation: pending completion after disposal is harmless',
      (t) async {
    final app = await _mount(t);
    final pending = Completer<AdvancedCodebreakerPuzzle>();
    final Future<void> completed =
        _state(t).generateForTesting(pending.future) as Future<void>;
    await t.pumpWidget(const SizedBox.shrink());
    pending.complete(_puzzle());
    await completed;
    await t.pump();
    expect(t.takeException(), isNull);
    expect(app.gp.outcomeCount, 0);
  });
  for (final restore in [false, true]) {
    testWidgets(
        'motion replay: a later drop restarts feedback (restored:$restore)',
        (t) async {
      await _mount(t, reduced: false);
      await _drop(t, 2, 0);
      await t.pump(const Duration(milliseconds: 600));
      if (restore) {
        await _restore(t, _snapshot(t));
      }
      await _drop(t, 3, 0);
      await t.pump(const Duration(milliseconds: 100));
      final scale = t.widget<ScaleTransition>(find
          .ancestor(of: _filled(t, 3), matching: find.byType(ScaleTransition))
          .single);
      expect(scale.scale.status, AnimationStatus.forward);
      expect(_snapshot(t)['moves'], 4);
    });
  }
  testWidgets(
      'motion replay: restored playable round restarts its next victory',
      (t) async {
    final app = await _mount(t, reduced: false);
    await _last(t, correct: true);
    final dynamic state = _state(t);
    expect(state.successController.status, AnimationStatus.completed);
    Navigator.of(t.element(roundDialogs)).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final b = _board(
        answers: {'eq0_term1': 2, 'eq1_term1': 2, 'eq1_term2': 3}, moves: 1);
    b['pool'] = [2, 4, 7, 7, 8, 9];
    await _restore(t, b);
    await _drop(t, 4, 0);
    await t.pump(const Duration(milliseconds: 100));
    expect(state.successController.status, AnimationStatus.forward);
    expect(app.gp.outcomeCount, 2);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  });
}
