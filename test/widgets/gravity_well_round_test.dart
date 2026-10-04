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
import 'package:space_math_academy/features/games/screens/gravity_well_game.dart';
import 'package:space_math_academy/features/games/services/gravity_well_logic.dart';
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
          home: const GravityWellGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(GravityWellGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {String label = 'A', int answer = 3, int value = 1, int mistakes = 0}) {
  final puzzle = GravityWellPuzzle(scales: [
    BalanceScale(leftSide: [
      ScaleItem(label: label, weight: answer, isKnown: false)
    ], rightSide: [
      ScaleItem(label: '$answer kg', weight: answer, isKnown: true)
    ])
  ], unknownWeights: {
    label: answer
  }, knownWeights: const {}, objectCount: 1);
  return {
    'puzzle': puzzle.toJson(),
    '_userAnswers': [
      [label, value]
    ],
    '_wrongChecks': mistakes
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

final _plus = find.byIcon(Icons.add_circle_outline);
final _minus = find.byIcon(Icons.remove_circle_outline);
final _entry = find.byWidgetPredicate((widget) =>
    widget is GestureDetector &&
    widget.child is Container &&
    (widget.child as Container).constraints?.maxWidth == 56);
Finder _check(WidgetTester tester) => find.ancestor(
    of: find.text(_strings(tester).gravityWellCheckBalance),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton));
Future<void> _number(WidgetTester tester, String text,
    {bool submit = false}) async {
  await tester.tap(_entry.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(find.byType(TextField), text);
  if (submit) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  } else {
    await tester.tap(find.widgetWithText(TextButton, _strings(tester).ok));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _grade(_App app, {int mistakes = 0, int outcomes = 1}) {
  expect(app.gp.outcomeCount, outcomes);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 195);
  expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(mistakes));
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'gravity_well_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_gravity_well': true});
    PuzzleSessionStore.resetForTesting();
  });
  for (final reduced in [false, true]) {
    testWidgets(
        'real weights/check win once and retry saves a new board (reduced:$reduced)',
        (tester) async {
      final app =
          await _mount(tester, reduced: reduced, board: _board(mistakes: 2));
      final plus = tester.widget<IconButton>(
          find.ancestor(of: _plus, matching: find.byType(IconButton)));
      final entry = tester.widget<GestureDetector>(_entry);
      final check = tester.widget<ElevatedButton>(_check(tester));
      await tester.tap(_plus);
      await tester.pump();
      await tester.tap(_plus);
      await tester.pump();
      expect(_snapshot(tester)['_userAnswers'], [
        ['A', 3]
      ]);
      await tester.tap(_check(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app, mistakes: 2);
      expect(_session(tester).capturePuzzleSession(), isNull);
      plus.onPressed!();
      entry.onTap!();
      check.onPressed!();
      await tester.pump();
      _grade(app, mistakes: 2);
      expect(find.byType(TextField), findsNothing);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['_wrongChecks'], 0);
    });
  }
  testWidgets('wrong checks remain saveable and later edits persist',
      (tester) async {
    final app = await _mount(tester, board: _board(mistakes: 2));
    await tester.tap(_check(tester));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_snapshot(tester)['_wrongChecks'], 3);
    Map<String, dynamic>? saved;
    await tester.runAsync(() async {
      saved = await PuzzleSessionStore.instance.load('gravity_well', 1, 1);
    });
    expect(saved, isNotNull);
    expect(saved!['_wrongChecks'], 3);
    await tester.tap(_plus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.runAsync(() async {
      saved = await PuzzleSessionStore.instance.load('gravity_well', 1, 1);
    });
    expect(saved!['_userAnswers'], [
      ['A', 2]
    ]);
    await _restore(tester, app, saved!);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(_plus);
    await tester.pump();
    await tester.tap(_check(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, mistakes: 3, outcomes: 2);
  });
  testWidgets('keyboard submit and OK clamp weights and reject invalid text',
      (tester) async {
    final app = await _mount(tester);
    await _number(tester, '999');
    expect(_snapshot(tester)['_userAnswers'], [
      ['A', 30]
    ]);
    await _number(tester, '-5', submit: true);
    expect(_snapshot(tester)['_userAnswers'], [
      ['A', 1]
    ]);
    await _number(tester, 'invalid');
    expect(_snapshot(tester)['_userAnswers'], [
      ['A', 1]
    ]);
    await _number(tester, '3', submit: true);
    await tester.tap(_check(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app);
  });
  testWidgets('retained adjustment callbacks use the current value and round',
      (tester) async {
    final app = await _mount(tester);
    final plus = tester.widget<IconButton>(
        find.ancestor(of: _plus, matching: find.byType(IconButton)));
    final minus = tester.widget<IconButton>(
        find.ancestor(of: _minus, matching: find.byType(IconButton)));
    final entry = tester.widget<GestureDetector>(_entry);
    final check = tester.widget<ElevatedButton>(_check(tester));
    plus.onPressed!();
    plus.onPressed!();
    await tester.pump();
    expect(_snapshot(tester)['_userAnswers'], [
      ['A', 3]
    ]);
    minus.onPressed!();
    await tester.pump();
    expect(_snapshot(tester)['_userAnswers'], [
      ['A', 2]
    ]);
    await _restore(
        tester, app, _board(label: 'B', value: 7, answer: 8, mistakes: 4));
    final before = _snapshot(tester);
    plus.onPressed!();
    minus.onPressed!();
    entry.onTap!();
    check.onPressed!();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(find.byType(TextField), findsNothing);
    expect(app.gp.outcomeCount, 0);
  });
  for (final submit in [false, true]) {
    testWidgets('open entry cannot edit replacement board (submit:$submit)',
        (tester) async {
      final app = await _mount(tester);
      await tester.tap(_entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), '25');
      await _restore(tester, app, _board(value: 6, answer: 7, mistakes: 5));
      final before = _snapshot(tester);
      if (submit) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tester.tap(find.widgetWithText(TextButton, _strings(tester).ok));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_snapshot(tester), before);
      expect(find.byType(TextField), findsNothing);
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'closed entry callbacks cannot close another entry or use its controller',
      (tester) async {
    await _mount(tester);
    await tester.tap(_entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final old = tester.widget<TextButton>(
        find.widgetWithText(TextButton, _strings(tester).ok));
    await tester.tap(find.widgetWithText(TextButton, _strings(tester).ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(_entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    old.onPressed!();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mid-success reduced motion stops ticks and keeps one award',
      (tester) async {
    final app = await _mount(tester, board: _board(value: 3));
    await tester.tap(_check(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    _grade(app);
    expect(_dialog, findsOneWidget);
  });
  testWidgets('retained terminal dialog buttons cannot change restored round',
      (tester) async {
    final app = await _mount(tester, reduced: true, board: _board(value: 3));
    await tester.tap(_check(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app, _board(label: 'B'));
    final before = _snapshot(tester);
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(_screen, findsOneWidget);
    _grade(app);
  });
  testWidgets('disposed callbacks cannot edit or report outcomes',
      (tester) async {
    final app = await _mount(tester);
    final plus = tester.widget<IconButton>(
        find.ancestor(of: _plus, matching: find.byType(IconButton)));
    final entry = tester.widget<GestureDetector>(_entry);
    final check = tester.widget<ElevatedButton>(_check(tester));
    await tester.pumpWidget(const SizedBox.shrink());
    plus.onPressed!();
    entry.onTap!();
    check.onPressed!();
    await tester.pump();
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('static scale repaints after model and label restoration',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final paint = find.byWidgetPredicate((widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_BalanceScalePainter');
    final dynamic previous = tester.widget<CustomPaint>(paint).painter;
    await _restore(tester, app, _board(label: 'B', answer: 9));
    final dynamic current = tester.widget<CustomPaint>(paint).painter;
    expect(current.shouldRepaint(previous), isTrue);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });
}
