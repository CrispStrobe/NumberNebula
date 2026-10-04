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
import 'package:space_math_academy/features/games/screens/galactic_market_game.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _RecordingSri extends SriService {
  final List<(MathProblem, bool)> responses = [];
  @override
  void recordResponse(MathProblem problem, bool wasCorrect) {
    responses.add((problem, wasCorrect));
    super.recordResponse(problem, wasCorrect);
  }
}

class _App {
  final ValueNotifier<bool> motion;
  final sri = _RecordingSri();
  final cognitive = CognitiveProfileService();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  final double textScale;
  _App({bool reduced = false, this.textScale = 1})
      : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
        ],
        child: MaterialApp(
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
          home: const GalacticMarketGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(GalacticMarketGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
        {int answer = 5,
        List<int> known = const [2],
        int unknown = 2,
        List<int> options = const [1, 2, 5, 10, 20],
        int? selected,
        int mistakes = 0}) =>
    {
      '_changeTotal':
          known.fold<int>(0, (sum, coin) => sum + coin) + answer * unknown,
      '_knownCoins': List.of(known),
      '_unknownCount': unknown,
      '_correctDenomination': answer,
      '_attemptsUsed': mistakes,
      '_constraintText': '$unknown hidden coins',
      '_denomOptions': List.of(options),
      '_selectedDenom': selected,
      '_mathProblems': [
        MathProblem.division(answer * unknown, unknown, difficulty: 1).toJson()
      ],
    };

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
    Map<String, dynamic>? board}) async {
  final app = _App(reduced: reduced, textScale: textScale);
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

final _pickers = find.byWidgetPredicate((widget) =>
    widget is GestureDetector &&
    widget.child is AnimatedContainer &&
    (widget.child! as AnimatedContainer).constraints?.maxWidth == 64);
Finder _picker(WidgetTester tester, int value) =>
    _pickers.at((_snapshot(tester)['_denomOptions'] as List).indexOf(value));
final _submitButton = find.ancestor(
    of: find.byIcon(Icons.check_circle_outline),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton));
Future<void> _select(WidgetTester tester, int value) async {
  await tester.tap(_picker(tester, value));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(_submitButton);
  await tester.pump();
}

void _grade(_App app, {int mistakes = 0}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.sri.responses, hasLength(1));
  expect(app.sri.responses.single.$2, isTrue);
  expect(app.sri.responses.single.$1.toJson(),
      app.gp.lastOutcome!.mathProblems.single.toJson());
  expect(app.gp.lastOutcome!.score, 125 + (2 - mistakes) * 50);
  expect(app.gp.lastOutcome!.performance, Perf.fromAttempts(mistakes + 1, 2));
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('galactic_market', 1, 1).then((value) {
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
    final id = 'galactic_market_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_galactic_market': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'submit starts disabled and selection is unsubmitted playable state',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    expect(tester.widget<ElevatedButton>(_submitButton).onPressed, isNull);
    await _select(tester, 5);
    expect(_snapshot(tester)['_selectedDenom'], 5);
    expect(app.gp.outcomeCount, 0);
    expect(
        tester
            .widget<AnimatedContainer>(find.descendant(
                of: _picker(tester, 5),
                matching: find.byType(AnimatedContainer)))
            .duration,
        Duration.zero);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'real denomination submit wins once and retry resets attempts (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _select(tester, 5);
      final picker = tester.widget<GestureDetector>(_picker(tester, 2));
      final submit = tester.widget<ElevatedButton>(_submitButton);
      await _submit(tester);
      submit.onPressed!();
      picker.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['_attemptsUsed'], 0);
      expect(_snapshot(tester)['_selectedDenom'], isNull);
    });
  }

  testWidgets('two wrong scans lose once and show subtraction then division',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _select(tester, 1);
    await _submit(tester);
    expect(_snapshot(tester)['_attemptsUsed'], 1);
    expect(_snapshot(tester)['_selectedDenom'], isNull);
    await _select(tester, 2);
    final submit = tester.widget<ElevatedButton>(_submitButton);
    await _submit(tester);
    submit.onPressed!();
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(app.sri.responses, hasLength(1));
    expect(app.sri.responses.single.$2, isFalse);
    expect(app.sri.responses.single.$1.toJson(),
        (_board()['_mathProblems'] as List).single);
    final retained = app.gp.lastOutcome!;
    final originalProblems =
        retained.mathProblems.map((problem) => problem.toJson()).toList();
    expect(find.text('12 − 2 = 10\n10 ÷ 2 = 5'), findsOneWidget);
    expect(_session(tester).capturePuzzleSession(), isNull);
    await tester
        .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_snapshot(tester)['_attemptsUsed'], 0);
    expect(_dialog, findsNothing);
    expect(retained.mathProblems.map((problem) => problem.toJson()).toList(),
        originalProblems);
    await _restore(tester, app, _board(answer: 10));
    expect(retained.mathProblems.map((problem) => problem.toJson()).toList(),
        originalProblems);
    expect(app.sri.responses, hasLength(1));
  });

  testWidgets(
      'wrong scan and later correct selection persist without inferring a win on restore',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _select(tester, 1);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    var saved = await _stored(tester);
    expect(saved!['_attemptsUsed'], 1);
    expect(saved['_selectedDenom'], isNull);
    await _select(tester, 5);
    await tester.pump(const Duration(milliseconds: 1000));
    saved = await _stored(tester);
    expect(saved!['_selectedDenom'], 5);
    expect(saved['_attemptsUsed'], 1);
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['_selectedDenom'], 5);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, mistakes: 1);
  });

  testWidgets(
      'older exhausted snapshot offers retry without another loss report',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(mistakes: 2, selected: 5));
    await tester.pump(const Duration(milliseconds: 700));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    expect(app.sri.responses, isEmpty);
    await tester
        .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_snapshot(tester)['_attemptsUsed'], 0);
    expect(app.gp.outcomeCount, 0);
    expect(app.sri.responses, isEmpty);
  });

  for (final options in [
    const [1, 2, 5, 10, 20],
    const [1, 5, 10]
  ]) {
    testWidgets(
        'retained denomination submit and navigation reject restored options$options',
        (tester) async {
      final app = await _mount(tester, board: _board(selected: 5));
      final picker = tester.widget<GestureDetector>(_picker(tester, 20));
      final submit = tester.widget<ElevatedButton>(_submitButton);
      final header = tester.widget<GameUI>(find.byType(GameUI));
      await _restore(tester, app,
          _board(answer: 10, options: options, selected: 1, mistakes: 1));
      final before = _snapshot(tester);
      picker.onTap!();
      submit.onPressed!();
      header.onBack();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_screen, findsOneWidget);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'active picker pointer cannot select after options$options replacement',
        (tester) async {
      final app = await _mount(tester, reduced: true);
      final pointer =
          await tester.startGesture(tester.getCenter(_picker(tester, 1)));
      await _restore(
          tester, app, _board(answer: 10, options: options, selected: 5));
      final before = _snapshot(tester);
      await pointer.up();
      await tester.pump();
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'active submit pointer cannot score correct replacement selection',
      (tester) async {
    final app = await _mount(tester, reduced: true, board: _board(selected: 1));
    final pointer = await tester.startGesture(tester.getCenter(_submitButton));
    await _restore(tester, app, _board(selected: 5));
    final before = _snapshot(tester);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement clears visible and queued wrong-scan feedback',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _select(tester, 1);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(_screen)).showSnackBar(const SnackBar(
      content: Text('queued obsolete market feedback'),
      duration: Duration(seconds: 20),
    ));
    await _restore(tester, app, _board(answer: 10, selected: 10));
    final before = _snapshot(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SnackBar), findsNothing);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('invalid saved selection normalizes and leaves submit disabled',
      (tester) async {
    await _mount(tester, reduced: true, board: _board(selected: 99));
    expect(_snapshot(tester)['_selectedDenom'], isNull);
    expect(tester.widget<ElevatedButton>(_submitButton).onPressed, isNull);
  });

  for (final replace in [false, true]) {
    testWidgets(
        'retained closed dialog callbacks cannot navigate (replace:$replace)',
        (tester) async {
      final app =
          await _mount(tester, reduced: true, board: _board(selected: 5));
      await _submit(tester);
      await tester.pump(const Duration(milliseconds: 700));
      final retry = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      final exit = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
      Navigator.of(tester.element(_screen)).pop();
      await tester.pump();
      Map<String, dynamic>? before;
      if (replace) {
        await _restore(tester, app, _board(answer: 10, selected: 10));
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
      'reported arithmetic stays owned by outcome across real retry and session restore',
      (tester) async {
    final app = await _mount(tester, reduced: true, board: _board(selected: 5));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retained = app.gp.lastOutcome!;
    final original = jsonDecode(jsonEncode(
        retained.mathProblems.map((problem) => problem.toJson()).toList()));
    expect(original, _board()['_mathProblems']);
    await tester
        .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(retained.mathProblems.map((problem) => problem.toJson()).toList(),
        original);
    await _restore(tester, app, _board(answer: 10));
    expect(_snapshot(tester)['_mathProblems'], isNot(original));
    expect(retained.mathProblems.map((problem) => problem.toJson()).toList(),
        original);
    _grade(app);
  });

  testWidgets(
      'mid-success reduction completes600ms visual before bounded Material feedback',
      (tester) async {
    final app = await _mount(tester, board: _board(selected: 5));
    await _submit(tester);
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

  testWidgets('disposal rejects retained picker and submit events',
      (tester) async {
    final app = await _mount(tester, board: _board(selected: 5));
    final picker = tester.widget<GestureDetector>(_picker(tester, 1));
    final submit = tester.widget<ElevatedButton>(_submitButton);
    await tester.pumpWidget(const SizedBox.shrink());
    picker.onTap!();
    submit.onPressed!();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'maximum coin table fits390px phone with doubled text through win and retry',
      (tester) async {
    final board = _board(known: [1, 2, 5, 10, 20], unknown: 8);
    final app = await _mount(tester, reduced: true, textScale: 2, board: board);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final coins = find.byWidgetPredicate((widget) =>
        widget is Container &&
        widget.constraints?.maxWidth == 56 &&
        widget.constraints?.maxHeight == 56);
    expect(coins, findsNWidgets(13));
    expect(_snapshot(tester)['_changeTotal'], 78);
    expect(_snapshot(tester)['_knownCoins'], [1, 2, 5, 10, 20]);
    expect(_snapshot(tester)['_unknownCount'], 8);
    await tester.ensureVisible(_picker(tester, 5));
    await tester.pump();
    await _select(tester, 5);
    expect(_snapshot(tester)['_selectedDenom'], 5);
    expect(_snapshot(tester)['_mathProblems'], board['_mathProblems']);
    expect(app.gp.outcomeCount, 0);
    await tester.ensureVisible(_submitButton);
    await tester.pump();
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(_dialog, findsOneWidget);
    _grade(app);
    final retry =
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsNothing);
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    expect(_snapshot(tester)['_attemptsUsed'], 0);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'maximum phone board with doubled text supports loss arithmetic and retry',
      (tester) async {
    final board =
        _board(known: [1, 2, 5, 10, 20], unknown: 8, mistakes: 1, selected: 2);
    final app = await _mount(tester, reduced: true, textScale: 2, board: board);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(_submitButton);
    await tester.pump();
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(_dialog, findsOneWidget);
    expect(find.text('78 − 38 = 40\n40 ÷ 8 = 5'), findsOneWidget);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(app.sri.responses, hasLength(1));
    expect(app.sri.responses.single.$2, isFalse);
    expect(app.sri.responses.single.$1.toJson(),
        (board['_mathProblems'] as List).single);
    final retry =
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsNothing);
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    expect(_snapshot(tester)['_attemptsUsed'], 0);
    expect(app.gp.outcomeCount, 1);
    expect(app.sri.responses, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
