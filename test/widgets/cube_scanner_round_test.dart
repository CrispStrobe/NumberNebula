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
import 'package:space_math_academy/features/games/screens/cube_scanner_game.dart';
import 'package:space_math_academy/features/games/services/cube_scanner_logic.dart';
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
          home: const CubeScannerGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CubeScannerGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {int seed = 7, int wrong = 0, bool selected = false}) {
  final puzzle = CubeScannerGenerator(seed: seed).generate(grade: 1, level: 1);
  return {
    '_puzzle': puzzle.toJson(),
    '_selectedAnswer': selected ? puzzle.correctAnswer : null,
    '_wrongAnswers': wrong,
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

Finder _button(String text) => find
    .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((widget) => widget is ElevatedButton))
    .first;
Finder _check(WidgetTester tester) =>
    _button(_strings(tester).cubeScannerCheck);
Finder _choice(int index) => find
    .ancestor(
        of: find.text(['A', 'B', 'C', 'D', 'E'][index]),
        matching: find.byType(GestureDetector))
    .first;
Future<void> _pick(WidgetTester tester, {bool correct = true}) async {
  final puzzle = CubeScannerPuzzle.fromJson(
      Map<String, dynamic>.from(_snapshot(tester)['_puzzle'] as Map));
  final index = correct
      ? puzzle.choices.indexOf(puzzle.correctAnswer)
      : puzzle.choices.indexWhere((value) => value != puzzle.correctAnswer);
  await tester.tap(_choice(index));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester, {bool correct = true}) async {
  await _pick(tester, correct: correct);
  await tester.tap(_check(tester));
  await tester.pump();
}

AnimationController _feedback(WidgetTester tester) {
  final builder = find.byWidgetPredicate((widget) =>
      widget is AnimatedBuilder &&
      widget.animation is CurvedAnimation &&
      (widget.animation as CurvedAnimation).curve == Curves.easeOut);
  final animation =
      tester.widget<AnimatedBuilder>(builder).animation as CurvedAnimation;
  return animation.parent as AnimationController;
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'cube_scanner_rounds_${profile++}';
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_cube_scanner': true});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets('win waits 700ms and blocks duplicate input (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final puzzle = _snapshot(tester)['_puzzle'] as Map;
      await _pick(tester);
      final check = tester.widget<ElevatedButton>(_check(tester)).onPressed!;
      check();
      check();
      await tester.pump();
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
      expect(app.gp.lastOutcome!.performance, 1);
      expect(app.gp.lastOutcome!.score,
          125 + (puzzle['dice'] as List).length * 75);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(find.text(_strings(tester).cubeScannerCheck), findsNothing);
      expect(_dialog, findsNothing);
      await tester.pump(const Duration(milliseconds: 650));
      expect(_dialog, findsNothing);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_dialog, findsOneWidget);
      await _frames(tester, 45);
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
    testWidgets('restore cancels the old win and feedback (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _submit(tester);
      await tester.pump(const Duration(milliseconds: 200));
      final replacement = _board(seed: 23, wrong: 2);
      await _restore(tester, app, replacement);
      expect(_feedback(tester).value, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester), replacement);
      expect(_feedback(tester).value, 0);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
    testWidgets('dispose cancels pending win (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _submit(tester);
      await _unmount(tester);
      expect(app.gp.outcomeCount, 1);
      expect(_dialog, findsNothing);
    });
    testWidgets(
        'loss reports once and real retry starts a saveable round (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _pick(tester, correct: false);
      final check = tester.widget<ElevatedButton>(_check(tester)).onPressed!;
      check();
      check();
      await tester.pump();
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_session(tester).puzzleSessionFinished, isTrue);
      await tester.tap(_button(_strings(tester).playAgain));
      await tester.pump();
      expect(_session(tester).puzzleSessionFinished, isFalse);
      expect(_snapshot(tester)['_selectedAnswer'], isNull);
      expect(_snapshot(tester)['_wrongAnswers'], 0);
      expect(_feedback(tester).value, 0);
      await _frames(tester, 50);
      expect(_dialog, findsNothing);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }

  testWidgets('legacy restored selection retains mistakes in win grading',
      (tester) async {
    final board = _board(wrong: 2, selected: true);
    final app = await _mount(tester, board: board);
    expect(_snapshot(tester), board);
    expect(_feedback(tester).value, 0);
    await tester.tap(_check(tester));
    await tester.pump();
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(2, per: 0.25));
    await _unmount(tester);
  });

  for (final initial in [false, true]) {
    testWidgets(
        'reduced motion finishes feedback and restore clears it (initial:$initial)',
        (tester) async {
      final app = await _mount(tester, reduced: initial);
      await _submit(tester, correct: false);
      if (!initial) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(_feedback(tester).value, greaterThan(0));
        expect(_feedback(tester).value, lessThan(1));
        app.motion.value = true;
        await tester.pump();
      }
      await _frames(tester, 8);
      expect(_feedback(tester).value, 1);
      expect(_feedback(tester).isAnimating, isFalse);
      final replacement = _board(seed: 23, wrong: 2);
      await _restore(tester, app, replacement);
      app.motion.value = false;
      await tester.pump();
      await _frames(tester, 40);
      expect(_feedback(tester).value, 0);
      expect(_snapshot(tester), replacement);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }

  testWidgets('selection toggles without counting an attempt', (tester) async {
    final app = await _mount(tester);
    final puzzle = _snapshot(tester)['_puzzle'] as Map;
    final index = (puzzle['choices'] as List).indexOf(puzzle['correctAnswer']);
    await tester.tap(_choice(index));
    await tester.pump();
    expect(_snapshot(tester)['_selectedAnswer'], puzzle['correctAnswer']);
    await tester.tap(_choice(index));
    await tester.pump();
    expect(_snapshot(tester)['_selectedAnswer'], isNull);
    expect(tester.widget<ElevatedButton>(_check(tester)).onPressed, isNull);
    expect(_snapshot(tester)['_wrongAnswers'], 0);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });
}
