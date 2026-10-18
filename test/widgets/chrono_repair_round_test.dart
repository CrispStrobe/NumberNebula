import 'support/round_dialog_finder.dart';
import 'dart:convert';
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
import 'package:space_math_academy/features/games/models/performance.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/chrono_repair_game.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);
  final double textScale;
  final Locale? locale;
  _App({bool reduced = false, this.textScale = 1, this.locale})
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
                    textScaler: TextScaler.linear(textScale)),
                child: child!),
          ),
          home: const ChronoRepairGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(ChronoRepairGame);
final _dialog = roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board({
  int correctHour = 3,
  int correctMinute = 15,
  int displayedHour = 5,
  int displayedMinute = 15,
  ClockMalfunction malfunction = ClockMalfunction.offset,
  int offsetHours = 2,
  int offsetMinutes = 0,
  String hint = 'Clock runs fast',
  int selectedHour = 1,
  int selectedMinute = 0,
  int wrongChecks = 0,
}) {
  return {
    '_correctHour': correctHour,
    '_correctMinute': correctMinute,
    '_displayedHour': displayedHour,
    '_displayedMinute': displayedMinute,
    '_malfunction': malfunction.name,
    '_offsetHours': offsetHours,
    '_offsetMinutes': offsetMinutes,
    '_malfunctionHint': hint,
    '_selectedHour': selectedHour,
    '_selectedMinute': selectedMinute,
    '_mathProblems': [],
    '_wrongChecks': wrongChecks,
  };
}

Future<void> _restore(
    WidgetTester tester, _App app, Map<String, dynamic> board) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  await tester.pump();
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester,
    {bool reduced = false,
    double textScale = 1,
    Locale? locale,
    Map<String, dynamic>? board}) async {
  final app = _App(reduced: reduced, textScale: textScale, locale: locale);
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
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  return app;
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final btn = find.byWidgetPredicate((w) =>
      w is ElevatedButton &&
      w.key is ValueKey &&
      (w.key as ValueKey).value.toString().contains('chrono-submit'));
  expect(btn, findsOneWidget);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pump();
}

Future<void> _setHour(WidgetTester tester, int target) async {
  // Use stepper up until target reached - simplest is to directly set via state for testing
  // Find hour stepper up button (first one is hour)
  final upButtons = find.byIcon(Icons.keyboard_arrow_up);
  expect(upButtons, findsAtLeastNWidgets(2));
  // Hour is first stepper
  for (int i = 0; i < 20; i++) {
    final snap = _snapshot(tester);
    if (snap['_selectedHour'] == target) {
      break;
    }
    await tester.ensureVisible(upButtons.at(0));
    await tester.tap(upButtons.at(0));
    await tester.pump();
  }
  expect(_snapshot(tester)['_selectedHour'], target);
}

Future<void> _setMinute(WidgetTester tester, int target) async {
  final upButtons = find.byIcon(Icons.keyboard_arrow_up);
  expect(upButtons, findsAtLeastNWidgets(2));
  for (int i = 0; i < 20; i++) {
    final snap = _snapshot(tester);
    if (snap['_selectedMinute'] == target) {
      break;
    }
    await tester.ensureVisible(upButtons.at(1));
    await tester.tap(upButtons.at(1));
    await tester.pump();
  }
  expect(_snapshot(tester)['_selectedMinute'], target);
}

void _gradeWin(_App app, {int wrong = 0}) {
  expect(app.gp.outcomeCount, wrong + 1);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(wrong));
}

Future<void> _retry(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(_dialog, findsNothing);
  expect(_snapshot(tester)['_wrongChecks'], 0);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('chrono_repair', 1, 1).then((v) {
    saved = v;
    complete = true;
  });
  for (var frame = 0; frame < 100 && !complete; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(complete, isTrue);
  return saved;
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'chrono_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_chrono_repair': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('correct submission wins once with performance and retry',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _setHour(tester, 3);
    await _setMinute(tester, 15);
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _gradeWin(app, wrong: 0);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    expect(await _stored(tester), isNull);
    await _retry(tester);
    expect(_session(tester).capturePuzzleSession(), isNotNull);
  });

  testWidgets(
      'wrong submission shows snackbar, increments wrongChecks and remains playable',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _setHour(tester, 5); // wrong
    await _tapSubmit(tester);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(_snapshot(tester)['_wrongChecks'], 1);
    expect(_snapshot(tester)['_selectedHour'], 5);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(
        _session(tester).capturePuzzleSession(), isNotNull); // still playable
    await tester.pump(const Duration(milliseconds: 1000));
    final saved = await _stored(tester);
    expect(saved!['_wrongChecks'], 1);
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['_wrongChecks'], 1);
    // Now correct and win
    await _setHour(tester, 3);
    await _setMinute(tester, 15);
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _gradeWin(app, wrong: 1);
  });

  testWidgets('old stepper callbacks cannot affect new board', (tester) async {
    final app = await _mount(tester);
    final oldBack = tester.widget<GameUI>(find.byType(GameUI));
    final oldUp = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up).first);
    final oldSubmit = tester.widget<ElevatedButton>(find.byWidgetPredicate(
        (w) =>
            w is ElevatedButton &&
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().contains('chrono-submit')));
    await _restore(
        tester,
        app,
        _board(
            correctHour: 7,
            correctMinute: 30,
            displayedHour: 9,
            displayedMinute: 30));
    final before = _snapshot(tester);
    oldBack.onBack();
    oldUp.onPressed!();
    oldSubmit.onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active press before restore cannot submit to new board',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final gesture = await tester.startGesture(tester.getCenter(find
        .byWidgetPredicate((w) => w is ElevatedButton && w.key is ValueKey)));
    await _restore(tester, app, _board(correctHour: 7, correctMinute: 30));
    await gesture.up();
    await tester.pump();
    expect(_snapshot(tester)['_selectedHour'], 1);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('disposal rejects retained callbacks', (tester) async {
    final app = await _mount(tester);
    final oldUp = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up).first);
    final oldSubmit = tester.widget<ElevatedButton>(find
        .byWidgetPredicate((w) => w is ElevatedButton && w.key is ValueKey));
    await tester.pumpWidget(const SizedBox.shrink());
    oldUp.onPressed!();
    oldSubmit.onPressed!();
    await tester.pump(const Duration(milliseconds: 500));
    expect(app.gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('win dialog buttons cannot be reused after close or replacement',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _setHour(tester, 3);
    await _setMinute(tester, 15);
    await _tapSubmit(tester);
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
    _gradeWin(app);
  });

  testWidgets('reduced motion completes win immediately', (tester) async {
    final app = await _mount(tester, reduced: true);
    await _setHour(tester, 3);
    await _setMinute(tester, 15);
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_session(tester).successController.isAnimating, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    _gradeWin(app);
  });

  for (final lang in ['en', 'de']) {
    testWidgets('phone doubled text still allows win in $lang', (tester) async {
      final app = await _mount(tester,
          reduced: true, textScale: 2, locale: Locale(lang));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _setHour(tester, 3);
      await _setMinute(tester, 15);
      await _tapSubmit(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_dialog, findsOneWidget);
      _gradeWin(app);
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
      await _retry(tester);
    });
  }

  testWidgets(
      'short doubled-text viewport scrolls to actual clock controls and win',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, textScale: 2, locale: const Locale('de'));
    tester.view.physicalSize = const Size(390, 500);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _setHour(tester, 3);
    await _setMinute(tester, 15);
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    _gradeWin(app);
    expect(tester.takeException(), isNull);
  });
  testWidgets('restoring correct unsubmitted clock input preserves submission',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(selectedHour: 3, selectedMinute: 15));
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    expect(_dialog, findsNothing);
    expect(app.gp.outcomeCount, 0);
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _gradeWin(app);
  });
  testWidgets('partial restore clears prior win and old result callbacks',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(selectedHour: 3, selectedMinute: 15));
    await _tapSubmit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_dialog, findsOneWidget);
    Navigator.of(tester.element(_screen)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _restore(tester, app, _board());
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    await _setHour(tester, 2);
    expect(_snapshot(tester)['_selectedHour'], 2);
    expect(app.gp.outcomeCount, 1);
  });
}
