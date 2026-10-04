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
import 'package:space_math_academy/features/games/screens/comm_relay_game.dart';
import 'package:space_math_academy/features/games/services/comm_relay_logic.dart';
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
          home: const CommRelayGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CommRelayGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {CipherType type = CipherType.caesar,
    int shift = 0,
    int attempts = 0,
    int maxAttempts = 5,
    String text = ''}) {
  final puzzle = CommRelayPuzzle(
      plainText: 'HELLO',
      cipherText: switch (type) {
        CipherType.caesar => CommRelayPuzzle.encryptCaesar('HELLO', 3),
        CipherType.atbash => CommRelayPuzzle.encryptAtbash('HELLO'),
        // SPACE + unused A-Z gives SPACEBDFGHIJKLMNOQRTUVWXYZ.
        // HELLO maps indices 7,4,11,11,14 to FEJJM.
        CipherType.keyword => 'FEJJM',
      },
      cipherType: type,
      shiftAmount: type == CipherType.caesar ? 3 : null,
      keyword: type == CipherType.keyword ? 'SPACE' : null,
      hintLetters: const {});
  return {
    'puzzle': puzzle.toJson(),
    '_currentShift': shift,
    '_attempts': attempts,
    '_maxAttempts': maxAttempts,
    '_text': text
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

Finder _check(WidgetTester tester) {
  final board = _snapshot(tester);
  final caesar = (board['puzzle'] as Map)['cipherType'] == 'caesar';
  final label = caesar
      ? _strings(tester).commRelayDecodeBtn(
          (board['_maxAttempts'] as int) - (board['_attempts'] as int))
      : _strings(tester).commRelayDecode;
  return find.widgetWithText(ElevatedButton, label);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(_check(tester));
  await tester.pump();
}

void _grade(_App app, {int attempts = 1, int maxAttempts = 5}) {
  expect(app.gp.outcomeCount, 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125 + (maxAttempts - attempts) * 50);
  expect(app.gp.lastOutcome!.performance,
      Perf.fromAttempts(attempts, maxAttempts));
}

Future<void> _slider(WidgetTester tester, int value) async {
  final finder = find.byType(Slider);
  final width = tester.getSize(finder).width;
  await tester
      .tapAt(tester.getCenter(finder) + Offset((width - 48) * value / 26, 0));
  await tester.pump();
  expect(_snapshot(tester)['_currentShift'], value);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('comm_relay', 1, 1).then((value) {
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
    final id = 'comm_relay_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_comm_relay': true});
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'actual Caesar slider wins once with terminal controls blocked (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      final oldSlider = tester.widget<Slider>(find.byType(Slider));
      final oldCheck = tester.widget<ElevatedButton>(_check(tester));
      await _slider(tester, 3);
      await _submit(tester);
      oldCheck.onPressed!();
      oldCheck.onPressed!();
      oldSlider.onChanged!(0);
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(_dialog, findsOneWidget);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_dialog, findsNothing);
      expect(_snapshot(tester)['_attempts'], 0);
      expect(_snapshot(tester)['_text'], '');
      expect(_snapshot(tester)['_maxAttempts'], 5);
    });

    for (final type in [CipherType.atbash, CipherType.keyword]) {
      testWidgets(
          'actual ${type.name} text wins and duplicate checks ignored (reduced:$reduced)',
          (tester) async {
        final app = await _mount(tester,
            reduced: reduced, board: _board(type: type, attempts: 2));
        final check = tester.widget<ElevatedButton>(_check(tester));
        await tester.enterText(find.byType(TextField), ' hello ');
        await tester.pump();
        expect(_snapshot(tester)['_text'], ' hello ');
        await _submit(tester);
        check.onPressed!();
        await tester.pump(const Duration(milliseconds: 700));
        _grade(app, attempts: 3);
        expect(_dialog, findsOneWidget);
        expect(_session(tester).capturePuzzleSession(), isNull);
      });
    }
  }

  for (final type in [CipherType.caesar, CipherType.atbash]) {
    testWidgets(
        'exhausted ${type.name} attempt loses once and real retry resets budget',
        (tester) async {
      final app = await _mount(tester,
          reduced: true, board: _board(type: type, attempts: 4, text: 'WRONG'));
      final check = tester.widget<ElevatedButton>(_check(tester));
      await _submit(tester);
      check.onPressed!();
      check.onPressed!();
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      await tester
          .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_snapshot(tester)['_attempts'], 0);
      expect(_snapshot(tester)['_maxAttempts'], 5);
      expect(_dialog, findsNothing);
    });
  }

  testWidgets('wrong text attempts and subsequent typing persist and restore',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(type: CipherType.atbash, attempts: 1));
    await tester.enterText(find.byType(TextField), 'WRONG');
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_snapshot(tester)['_attempts'], 2);
    expect(app.gp.outcomeCount, 0);
    var stored = await _stored(tester);
    expect(stored, isNotNull);
    expect(stored!['_attempts'], 2);
    expect(stored['_text'], 'WRONG');
    await tester.enterText(find.byType(TextField), 'HEL');
    await tester.pump(const Duration(milliseconds: 1000));
    stored = await _stored(tester);
    expect(stored!['_text'], 'HEL');
    expect(stored['_attempts'], 2);
    await _restore(tester, app, stored);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'HEL');
    expect(_snapshot(tester)['_attempts'], 2);
    await tester.enterText(find.byType(TextField), 'HELLO');
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, attempts: 3);
  });

  for (final targetType in [CipherType.caesar, CipherType.atbash]) {
    testWidgets(
        'old slider/check closures cannot mutate restored ${targetType.name} board',
        (tester) async {
      final app = await _mount(tester);
      final slider = tester.widget<Slider>(find.byType(Slider));
      final check = tester.widget<ElevatedButton>(_check(tester));
      await _restore(tester, app,
          _board(type: targetType, shift: 1, attempts: 2, text: 'NEW'));
      final before = _snapshot(tester);
      slider.onChanged!(3);
      check.onPressed!();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final targetType in [CipherType.caesar, CipherType.keyword]) {
    testWidgets(
        'retained text callbacks and keyboard cannot edit restored ${targetType.name} board',
        (tester) async {
      final app = await _mount(tester, board: _board(type: CipherType.atbash));
      await tester.enterText(find.byType(TextField), 'OLD');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      final check = tester.widget<ElevatedButton>(_check(tester));
      await _restore(
          tester, app, _board(type: targetType, text: 'NEW', attempts: 2));
      final before = _snapshot(tester);
      field.onChanged?.call('HELLO');
      field.onSubmitted?.call('HELLO');
      check.onPressed!();
      // The keyboard channel belongs to the obsolete input connection.
      if (tester.testTextInput.hasAnyClients) {
        tester.testTextInput
            .updateEditingValue(const TextEditingValue(text: 'STALE'));
      }
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'old live controller and keyboard cannot overwrite replacement before rebuild',
      (tester) async {
    final app = await _mount(tester, board: _board(type: CipherType.atbash));
    await tester.enterText(find.byType(TextField), 'OLD');
    await tester.pump();
    final oldField = tester.widget<TextField>(find.byType(TextField));
    final oldController = oldField.controller!;
    _session(tester).beginPuzzleSession();
    _session(tester).applyPuzzleSession(
        _board(type: CipherType.atbash, text: 'NEW', attempts: 2));
    // The old EditableText and input connection are still mounted this frame.
    oldController.text = 'HELLO';
    oldField.onChanged!('HELLO');
    tester.testTextInput
        .updateEditingValue(const TextEditingValue(text: 'STALE'));
    expect(_snapshot(tester)['_text'], 'NEW');
    expect(_snapshot(tester)['_attempts'], 2);
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    final newField = tester.widget<TextField>(find.byType(TextField));
    expect(newField.controller, isNot(same(oldController)));
    expect(newField.controller!.text, 'NEW');
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy exhausted snapshot stays terminal without replaying loss',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(attempts: 5, shift: 3));
    expect(_session(tester).capturePuzzleSession(), isNull);
    final check = tester.widget<ElevatedButton>(find.widgetWithText(
        ElevatedButton, _strings(tester).commRelayDecodeBtn(0)));
    final slider = tester.widget<Slider>(find.byType(Slider));
    check.onPressed?.call();
    slider.onChanged?.call(3);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsOneWidget);
    await tester
        .tap(find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dialog, findsNothing);
    expect(_snapshot(tester)['_attempts'], 0);
    expect(_snapshot(tester)['_maxAttempts'], 5);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'retained terminal dialog buttons cannot retry or exit replacement',
      (tester) async {
    final app = await _mount(tester, reduced: true, board: _board(shift: 3));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app,
        _board(type: CipherType.atbash, text: 'REPLACED', attempts: 2));
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
      'closed same-round dialog callbacks cannot generate or exit while pop animates',
      (tester) async {
    final app = await _mount(tester, reduced: true, board: _board(shift: 3));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    final exit = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).backToMenu));
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    // The route can remain mounted during its reverse animation; it no longer
    // owns navigation even though the round itself has not been replaced.
    retry.onPressed!();
    exit.onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_screen, findsOneWidget);
    expect(_dialog, findsNothing);
    expect(_session(tester).capturePuzzleSession(), isNull);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mid-success reduced motion finishes one shot without duplicate outcome',
      (tester) async {
    final app = await _mount(tester, board: _board(shift: 3));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    await tester.pump();
    // Prove the game one-shot completes immediately after reducing motion.
    final AnimationController success = _session(tester).successController;
    expect(success.isAnimating, isFalse);
    expect(success.value, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    // Android Material3's real button tap uses a 617ms InkSparkle. Allow
    // its finite framework feedback to finish (650ms total since the tap).
    await tester.pump(const Duration(milliseconds: 250));
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

  testWidgets('disposal rejects retained submission and slider callbacks',
      (tester) async {
    final app = await _mount(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    final check = tester.widget<ElevatedButton>(_check(tester));
    await tester.pumpWidget(const SizedBox.shrink());
    slider.onChanged!(3);
    check.onPressed!();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
