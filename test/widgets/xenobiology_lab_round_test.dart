import 'dart:convert';
import 'dart:math' as math;

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
import 'package:space_math_academy/features/games/screens/xenobiology_lab_game.dart';
import 'package:space_math_academy/features/games/services/xenobiology_lab_logic.dart';
import 'package:space_math_academy/generated/l10n.dart';

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
              child: child!,
            ),
          ),
          home: const XenobiologyLabGame(grade: 2, level: 1),
        ),
      );
}

final _screen = find.byType(XenobiologyLabGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board({int grade = 2, int level = 1, int seed = 42}) {
  final random = math.Random(seed);
  final gen = generateXenobiologyLab(grade, level, random: random);
  // Start with sliders at 0, wrongChecks 0
  return {
    '_eyesA': gen['_eyesA'],
    '_legsA': gen['_legsA'],
    '_eyesB': gen['_eyesB'],
    '_legsB': gen['_legsB'],
    '_countA': gen['_countA'],
    '_countB': gen['_countB'],
    '_totalEyes': gen['_totalEyes'],
    '_totalLegs': gen['_totalLegs'],
    '_nameA': gen['_nameA'],
    '_nameB': gen['_nameB'],
    '_hasThirdType': gen['_hasThirdType'],
    '_eyesC': gen['_eyesC'],
    '_legsC': gen['_legsC'],
    '_countC': gen['_countC'],
    '_nameC': gen['_nameC'],
    '_sliderA': 0,
    '_sliderB': 0,
    '_sliderC': 0,
    '_maxSliderValue': gen['_maxSliderValue'],
    '_mathProblems': gen['_mathProblems'],
    '_wrongChecks': 0,
  };
}

Future<void> _restore(WidgetTester tester, _App app, Map<String, dynamic> board) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  final reduced = app.motion.value;
  app.motion.value = !reduced;
  await tester.pump();
  app.motion.value = reduced;
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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  return app;
}

Finder _submitBtn() => find.byWidgetPredicate((w) =>
    w is ElevatedButton &&
    w.key is ValueKey &&
    (w.key as ValueKey).value.toString().contains('xeno-submit'));

Future<void> _setSlider(WidgetTester tester, int which, int value) async {
  final session = _session(tester);
  final round = session.testRound as Object;
  session.setSliderForTesting(which, value, round);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  final btn = _submitBtn();
  if (btn.evaluate().isEmpty) return;
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pump();
}

Future<void> _retry(WidgetTester tester) async {
  final btn = find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_dialog, findsNothing);
  expect(_session(tester).capturePuzzleSession(), isNotNull);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('xenobiology_lab', 2, 1).then((v) {
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
    final id = 'xenobiology_lab_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_xenobiology_lab': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('correct census wins once and terminal session is captured as null', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 1);
    await _restore(tester, app, board);
    final correctA = board['_countA'] as int;
    final correctB = board['_countB'] as int;
    await _setSlider(tester, 0, correctA);
    await _setSlider(tester, 1, correctB);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    // Duplicate submit must not report again
    final before = app.gp.outcomeCount;
    await _submit(tester);
    await tester.pump();
    expect(app.gp.outcomeCount, before);
  });

  testWidgets('wrong census increments counter, stays editable and saved', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 2);
    await _restore(tester, app, board);
    // Set wrong values (0,0 is wrong unless total is 0 which it never is)
    await _setSlider(tester, 0, 0);
    await _setSlider(tester, 1, 0);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    final snap = _snapshot(tester);
    expect(snap['_wrongChecks'], 1);
    // Still editable
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    // Sliders still work after mistake
    await _setSlider(tester, 0, 1);
    await tester.pump();
    expect(_snapshot(tester)['_sliderA'], 1);
    // Persisted
    final saved = await _stored(tester);
    expect(saved!['_wrongChecks'], 1);
  });

  testWidgets('old round slider cannot mutate new board', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board1 = _board(seed: 10);
    await _restore(tester, app, board1);
    final oldRound = _session(tester).testRound as Object;
    final oldSnap = _snapshot(tester);
    final board2 = _board(seed: 20);
    await _restore(tester, app, board2);
    final newSnapBefore = _snapshot(tester);
    // Try to mutate with old round
    _session(tester).setSliderForTesting(0, 5, oldRound);
    await tester.pump();
    expect(_snapshot(tester), newSnapBefore);
    expect(_snapshot(tester)['sliderA'], isNot(newSnapBefore['sliderA'] == 5 ? oldSnap['sliderA'] : 5));
    // New round does mutate
    final newRound = _session(tester).testRound as Object;
    _session(tester).setSliderForTesting(0, 3, newRound);
    await tester.pump();
    expect(_snapshot(tester)['_sliderA'], 3);
  });

  testWidgets('retry after win resets board and allows new win', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 3);
    await _restore(tester, app, board);
    await _setSlider(tester, 0, board['_countA'] as int);
    await _setSlider(tester, 1, board['_countB'] as int);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    await _retry(tester);
    // Should be fresh
    expect(_snapshot(tester)['_wrongChecks'], 0);
    expect(_snapshot(tester)['_sliderA'], 0);
    expect(app.gp.outcomeCount, 1);
    // Can win again after retry
    final board2 = _board(seed: 4);
    await _restore(tester, app, board2);
    await _setSlider(tester, 0, board2['_countA'] as int);
    await _setSlider(tester, 1, board2['_countB'] as int);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 2);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  });

  testWidgets('restored solved board shows win dialog and is terminal', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 5);
    final solvedBoard = Map<String, dynamic>.from(board);
    solvedBoard['_sliderA'] = board['_countA'];
    solvedBoard['_sliderB'] = board['_countB'];
    solvedBoard['_sliderC'] = board['_countC'];
    await _restore(tester, app, solvedBoard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
    expect(app.gp.outcomeCount, 0); // No duplicate reward on restore
  });

  testWidgets('pointer down before restore and up afterward does not corrupt new round', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board1 = _board(seed: 11);
    await _restore(tester, app, board1);
    final oldRound = _session(tester).testRound as Object;
    // Simulate pointer down on old round's submit (tap down)
    final gesture = await tester.startGesture(tester.getCenter(_submitBtn()));
    await tester.pump();
    // Restore while pointer is down
    final board2 = _board(seed: 12);
    await _restore(tester, app, board2);
    await gesture.up();
    await tester.pump();
    // Should not have won or corrupted
    expect(_snapshot(tester)['_sliderA'], 0);
    expect(app.gp.outcomeCount, 0);
    // Old round check should be ignored
    _session(tester).checkForTesting(oldRound);
    await tester.pump();
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('reduced motion respects initial and mid-animation toggle', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 6);
    await _restore(tester, app, board);
    await _setSlider(tester, 0, board['_countA'] as int);
    await _setSlider(tester, 1, board['_countB'] as int);
    await _submit(tester);
    await tester.pump();
    // With reduced motion, animation should complete immediately
    await tester.pump(const Duration(milliseconds: 100));
    expect(_dialog, findsOneWidget);
    // Toggle motion mid-way
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    expect(_dialog, findsOneWidget);
  });

  testWidgets('phone layout 390x844 and short 390x500 with textScale 2 have no overflow', (tester) async {
    for (final size in [const Size(390, 844), const Size(390, 500)]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = _App(reduced: false, textScale: scale);
        await tester.pumpWidget(app.build());
        for (var attempt = 0; attempt < 150; attempt++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          if (_session(tester).capturePuzzleSession() != null) break;
        }
        await _restore(tester, app, _board(seed: size.height.toInt()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // Also test German locale
        await tester.pumpWidget(_App(reduced: false, textScale: scale, locale: const Locale('de')).build());
        for (var attempt = 0; attempt < 150; attempt++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          if (_session(tester).capturePuzzleSession() != null) break;
        }
        await _restore(tester, app, _board(seed: 99));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('exhausted saves do not replay rewards', (tester) async {
    final app = await _mount(tester, reduced: true);
    final board = _board(seed: 7);
    await _restore(tester, app, board);
    await _setSlider(tester, 0, board['_countA'] as int);
    await _setSlider(tester, 1, board['_countB'] as int);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(_session(tester).capturePuzzleSession(), isNull);
    // Simulate app restart with terminal state: apply same solved board should not replay
    final terminalBoard = Map<String, dynamic>.from(board);
    terminalBoard['_sliderA'] = board['_countA'];
    terminalBoard['_sliderB'] = board['_countB'];
    // Apply should detect solved and show dialog but not report outcome again
    await _restore(tester, app, terminalBoard);
    await tester.pump();
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('English rendering sanity', (tester) async {
    await _mount(tester);
    expect(find.textContaining('Xenobiology'), findsOneWidget);
    expect(_submitBtn(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // German
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final deApp = _App(locale: const Locale('de'));
    await tester.pumpWidget(deApp.build());
    for (var attempt = 0; attempt < 150; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      if (_session(tester).capturePuzzleSession() != null) break;
    }
    await _restore(tester, deApp, _board());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
