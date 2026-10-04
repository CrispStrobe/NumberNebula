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
import 'package:space_math_academy/features/games/screens/vault_cracker_game.dart';
import 'package:space_math_academy/features/games/services/vault_cracker_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';

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
          home: const VaultCrackerGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(VaultCrackerGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {List<int> secret = const [1, 2, 3],
    int range = 5,
    List<int?>? answer,
    List<List<int>> guesses = const []}) {
  final puzzle = VaultCrackerPuzzle(
      secretCode: List.of(secret),
      codeLength: secret.length,
      digitRange: range,
      clues: const []);
  return {
    'puzzle': puzzle.toJson(),
    'answer': answer ?? List<int?>.filled(secret.length, null),
    'guesses': guesses.map(List<int>.of).toList()
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

Finder _controls(double width) => find.byWidgetPredicate((widget) =>
    widget is GestureDetector &&
    widget.child is Container &&
    (widget.child! as Container).constraints?.maxWidth == width);
Finder _digit(int value) => _controls(44).at(value - 1);
Finder _slot(int position) => _controls(52).at(position);
final _check = find.widgetWithIcon(ElevatedButton, Icons.check);
Finder _clear(WidgetTester tester) => find.ancestor(
    of: find.text(_strings(tester).clearButton),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton));
Future<void> _digits(WidgetTester tester, List<int> digits) async {
  for (final digit in digits) {
    await tester.tap(_digit(digit));
    await tester.pump();
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(_check);
  await tester.pump();
}

void _grade(_App app, {int guesses = 1}) {
  expect(app.gp.outcomeCount, 1);
  final outcome = app.gp.lastOutcome!;
  expect(outcome.wasSuccessful, isTrue);
  expect(outcome.score, 125 + (6 - guesses) * 15);
  expect(outcome.movesUsed, guesses);
  expect(outcome.optimalMoves, 3);
  expect(outcome.performance, Perf.fromMoves(guesses, 3));
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('vault_cracker', 1, 1).then((value) {
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
    final id = 'vault_cracker_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_vault_cracker': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'actual digit pad fills first empty; slots and clear preserve partial-submit guard',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    expect(tester.widget<ElevatedButton>(_check).onPressed, isNull);
    await _digits(tester, [3, 2]);
    expect(_snapshot(tester)['answer'], [3, 2, null]);
    await tester.tap(_slot(0));
    await tester.pump();
    await _digits(tester, [1]);
    expect(_snapshot(tester)['answer'], [1, 2, null]);
    await tester.tap(_clear(tester));
    await tester.pump();
    expect(_snapshot(tester)['answer'], [null, null, null]);
    expect(_snapshot(tester)['guesses'], isEmpty);
    expect(tester.widget<ElevatedButton>(_check).onPressed, isNull);
    expect(app.gp.outcomeCount, 0);
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'actual complete code wins once then retry resets history (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _digits(tester, [1, 2, 3]);
      final submit = tester.widget<ElevatedButton>(_check);
      final clear = tester.widget<ElevatedButton>(_clear(tester));
      final digit = tester.widget<GestureDetector>(_digit(5));
      final slot = tester.widget<GestureDetector>(_slot(2));
      await _submit(tester);
      submit.onPressed!();
      clear.onPressed!();
      digit.onTap!();
      slot.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['guesses'], isEmpty);
      expect(
          (_snapshot(tester)['answer'] as List).every((value) => value == null),
          isTrue);
    });
  }

  testWidgets(
      'sixth incorrect guess loses once with best positional partial progress',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(guesses: [
          [1, 2, 5],
          [5, 5, 5],
          [4, 4, 4],
          [3, 3, 3],
          [2, 2, 2]
        ]));
    await _digits(tester, [5, 5, 5]);
    final submit = tester.widget<ElevatedButton>(_check);
    await _submit(tester);
    submit.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(app.gp.lastOutcome!.performance, Perf.forLoss(progress: 2 / 3));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    await tester
        .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_snapshot(tester)['guesses'], isEmpty);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets(
      'wrong history and partial next code persist then grade after restore',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _digits(tester, [1, 1, 1]);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    var stored = await _stored(tester);
    expect(stored!['guesses'], [
      [1, 1, 1]
    ]);
    expect(stored['answer'], [null, null, null]);
    await _digits(tester, [2]);
    await tester.pump(const Duration(milliseconds: 1000));
    stored = await _stored(tester);
    expect(stored!['answer'], [2, null, null]);
    expect(stored['guesses'], [
      [1, 1, 1]
    ]);
    await _restore(tester, app, stored);
    final restored = _snapshot(tester);
    for (final field in ['puzzle', 'answer', 'guesses']) {
      expect(restored[field], stored[field]);
    }
    await tester.tap(_clear(tester));
    await tester.pump();
    await _digits(tester, [1, 2, 3]);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, guesses: 2);
  });

  testWidgets('history feedback consumes repeated digits exactly once',
      (tester) async {
    await _mount(tester,
        reduced: true,
        board: _board(secret: [
          1,
          1,
          2
        ], guesses: [
          [1, 2, 2],
          [2, 1, 1]
        ]));
    final history = find
        .ancestor(of: find.text('2 / 6'), matching: find.byType(Column))
        .first;
    final cells = find.descendant(
        of: history,
        matching: find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 44 &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color != null));
    final colors = tester
        .widgetList<Container>(cells)
        .map((widget) => (widget.decoration! as BoxDecoration).color)
        .toList();
    expect(colors, [
      SpaceTheme.alienGreen,
      Colors.grey.shade700,
      SpaceTheme.alienGreen,
      SpaceTheme.starYellow,
      SpaceTheme.alienGreen,
      SpaceTheme.starYellow
    ]);
    expect(_snapshot(tester)['guesses'], [
      [1, 2, 2],
      [2, 1, 1]
    ]);
  });

  for (final secret in [
    const [1, 2],
    const [3, 2, 1, 2]
  ]) {
    testWidgets(
        'retained controls cannot mutate replacement length${secret.length} range3',
        (tester) async {
      final app = await _mount(tester,
          board: _board(secret: [1, 2, 3, 4], answer: [1, 2, 3, 5]));
      final submit = tester.widget<ElevatedButton>(_check);
      final clear = tester.widget<ElevatedButton>(_clear(tester));
      final digit = tester.widget<GestureDetector>(_digit(5));
      final slot = tester.widget<GestureDetector>(_slot(3));
      await _restore(
          tester,
          app,
          _board(secret: secret, range: 3, answer: [
            for (var index = 0; index < secret.length; index++)
              index == 0 ? 2 : null
          ]));
      final before = _snapshot(tester);
      digit.onTap!();
      slot.onTap!();
      clear.onPressed!();
      submit.onPressed!();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final control in ['digit-pad', 'filled-slot', 'clear']) {
    testWidgets(
        'active $control pointer cannot affect same-geometry replacement',
        (tester) async {
      final app = await _mount(tester,
          reduced: true, board: _board(answer: [1, null, null]));
      final pointer = await tester.startGesture(tester.getCenter(switch (
          control) {
        'digit-pad' => _digit(5),
        'filled-slot' => _slot(0),
        _ => _clear(tester)
      }));
      await _restore(tester, app, _board(answer: [2, null, null]));
      final before = _snapshot(tester);
      await pointer.up();
      await tester.pump();
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'active submit pointer cannot score same-geometry replacement answer',
      (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(answer: [1, 2, 5]));
    final pointer = await tester.startGesture(tester.getCenter(_check));
    await _restore(tester, app, _board(answer: [1, 2, 3]));
    final before = _snapshot(tester);
    await pointer.up();
    await tester.pump();
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'same-round filled-slot callback cannot clear a different replacement digit',
      (tester) async {
    await _mount(tester, reduced: true);
    await _digits(tester, [1]);
    final old = tester.widget<GestureDetector>(_slot(0));
    await tester.tap(_slot(0));
    await tester.pump();
    await _digits(tester, [2]);
    old.onTap!();
    await tester.pump();
    expect(_snapshot(tester)['answer'], [2, null, null]);
  });

  for (final won in [false, true]) {
    testWidgets(
        'saved terminal ${won ? 'win' : 'loss'} offers retry without replay',
        (tester) async {
      final guesses = won
          ? [
              [1, 2, 3]
            ]
          : List.generate(6, (_) => [5, 5, 5]);
      final app =
          await _mount(tester, reduced: true, board: _board(guesses: guesses));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      expect(app.gp.outcomeCount, 0);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['guesses'], isEmpty);
      expect(app.gp.outcomeCount, 0);
    });
  }

  testWidgets('terminal dialog callbacks cannot alter a replacement round',
      (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(answer: [1, 2, 3]));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app, _board(secret: [1, 2], range: 3));
    final before = _snapshot(tester);
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump(const Duration(milliseconds: 700));
    expect(_snapshot(tester), before);
    expect(_screen, findsOneWidget);
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'closed same-round dialog buttons cannot act during reverse transition',
      (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(answer: [1, 2, 3]));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_screen, findsOneWidget);
    expect(_dialog, findsNothing);
    expect(_session(tester).capturePuzzleSession(), isNull);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fourth guess retains par-three performance and original score',
      (tester) async {
    final app = await _mount(tester,
        reduced: true,
        board: _board(guesses: [
          [5, 5, 5],
          [4, 4, 4],
          [3, 3, 3]
        ]));
    await _digits(tester, [1, 2, 3]);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, guesses: 4);
  });

  testWidgets(
      'mid-success reduced motion immediately completes game visual before bounded ink settling',
      (tester) async {
    final app = await _mount(tester, board: _board(answer: [1, 2, 3]));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    final AnimationController success = _session(tester).successController;
    expect(success.isAnimating, isFalse);
    expect(success.value, 1);
    // The actual Android Material3 button's InkSparkle runs for617ms.
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(_dialog, findsOneWidget);
    _grade(app);
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    _grade(app);
  });

  testWidgets('disposal rejects retained digit slot clear and submit events',
      (tester) async {
    final app = await _mount(tester, board: _board(answer: [1, 2, 5]));
    final digit = tester.widget<GestureDetector>(_digit(5));
    final slot = tester.widget<GestureDetector>(_slot(2));
    final clear = tester.widget<ElevatedButton>(_clear(tester));
    final submit = tester.widget<ElevatedButton>(_check);
    await tester.pumpWidget(const SizedBox.shrink());
    digit.onTap!();
    slot.onTap!();
    clear.onPressed!();
    submit.onPressed!();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
