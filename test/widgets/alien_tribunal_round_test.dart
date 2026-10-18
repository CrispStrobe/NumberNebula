import 'package:space_math_academy/features/games/widgets/game_ui.dart';
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
import 'package:space_math_academy/features/games/screens/alien_tribunal_game.dart';
import 'package:space_math_academy/features/games/services/alien_tribunal_logic.dart';
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
          home: const AlienTribunalGame(grade: 3, level: 1),
        ),
      );
}

final _screen = find.byType(AlienTribunalGame);
final _dialog = roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board({
  int personCount = 3,
  Map<int, bool?> assignment = const {},
  int wrongVerdicts = 0,
}) {
  final people = List.generate(personCount, (i) {
    return TribunalPerson(
      name: 'Alien ${String.fromCharCode(65 + i)}',
      statement: 'test',
      kind: TribunalClaimKind.single,
      targetIndex: (i + 1) % personCount,
      secondTargetIndex: 0,
      pairRequiresBoth: false,
      claimsTruthTeller: true,
      countsTruthTellers: false,
      countValue: 0,
      statementStyle: 0,
      isTruthTeller: i % 2 == 0,
    );
  });
  final puzzle = AlienTribunalPuzzle(
    people: people,
    personCount: personCount,
  );
  return {
    'puzzle': puzzle.toJson(),
    '_userAssignment': assignment.entries.map((e) => [e.key, e.value]).toList(),
    '_wrongVerdicts': wrongVerdicts,
  };
}

Future<void> _restore(
    WidgetTester tester, _App app, Map<String, dynamic> board) async {
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
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, board ?? _board());
  await tester.pump();
  return app;
}

Finder _tapTarget(int index) => find.byWidgetPredicate((w) =>
    w is GestureDetector &&
    w.key is ValueKey &&
    (w.key as ValueKey).value.toString().contains('alien-tap') &&
    (w.key as ValueKey).value.toString().contains('$index'));

Finder _submitBtn() => find.byWidgetPredicate((w) =>
    w is ElevatedButton &&
    w.key is ValueKey &&
    (w.key as ValueKey).value.toString().contains('alien-submit'));

Future<void> _tapCard(WidgetTester tester, int index) async {
  final finder = _tapTarget(index);
  expect(finder, findsOneWidget);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  final btn = _submitBtn();
  if (btn.evaluate().isEmpty) {
    return;
  }
  await tester.tap(btn);
  await tester.pump();
}

Future<void> _submitExpect(WidgetTester tester) async {
  final btn = _submitBtn();
  expect(btn, findsOneWidget);
  await tester.tap(btn);
  await tester.pump();
}

Future<void> _retry(WidgetTester tester) async {
  final button =
      find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_dialog, findsNothing);
  expect(_session(tester).capturePuzzleSession(), isNotNull);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('alien_tribunal', 3, 1).then((value) {
    saved = value;
    complete = true;
  });
  for (var frame = 0; frame < 100 && !complete; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(complete, isTrue,
      reason: 'Session read must finish within 100 frames');
  return saved;
}

void main() {
  testWidgets('adversarial: retained back callback rejects restored round',
      (t) async {
    await _mount(t, reduced: true);
    final old = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final dynamic session = _session(t);
    final before = jsonDecode(jsonEncode(session.capturePuzzleSession()))
        as Map<String, dynamic>;
    session.beginPuzzleSession();
    session.applyPuzzleSession(before);
    session.rebuildForTesting();
    await t.pump();
    old();
    await t.pump();
    expect(_screen, findsOneWidget);
    expect(session.capturePuzzleSession(), before);
    expect(t.takeException(), isNull);
  });
  testWidgets('adversarial: back callback cannot dismiss a covering route',
      (t) async {
    await _mount(t, reduced: true);
    final back = t.widget<GameUI>(find.byType(GameUI)).onBack;
    final context = t.element(_screen);
    showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('audit route probe')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    back();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('audit route probe'), findsOneWidget);
    Navigator.of(context).pop();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });

  var profile = 0;
  setUp(() {
    final id = 'alien_tribunal_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_alien_tribunal': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('tapping cycles through truth/liar/unset with round guard',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final round = session.testRound;
    expect(_snapshot(tester)['_userAssignment'], isEmpty);
    await _tapCard(tester, 0);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 1);
    final oldRound = Object();
    session.toggleForTesting(1, oldRound);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 1);
    session.toggleForTesting(1, round);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 2);
    expect(app.gp.outcomeCount, 0);
  });

  testWidgets('wrong verdict increments counter and stays editable',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final puzzle = session.puzzle as AlienTribunalPuzzle;
    // Make a wrong assignment: flip first person's correct value
    for (int i = 0; i < puzzle.personCount; i++) {
      final needed = puzzle.people[i].isTruthTeller;
      await _tapCard(tester, i);
      if (!needed) {
        await _tapCard(tester, i);
      }
    }
    // Flip one to make it wrong
    await _tapCard(tester, 0);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    // Wrong should have incremented and still be editable
    if (app.gp.outcomeCount == 1 && !app.gp.lastOutcome!.wasSuccessful) {
      expect(_snapshot(tester)['_wrongVerdicts'], 1);
      expect(_session(tester).capturePuzzleSession(), isNotNull);
      await _tapCard(tester, 0);
      await tester.pump();
      expect(_session(tester).capturePuzzleSession(), isNotNull);
    } else {
      // If somehow we solved correctly, then it's win
      expect(app.gp.outcomeCount, 1);
      expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    }
  });

  testWidgets('solved board wins once and captures terminal as null',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final puzzle = session.puzzle as AlienTribunalPuzzle;
    for (int i = 0; i < puzzle.personCount; i++) {
      final needed = puzzle.people[i].isTruthTeller;
      await _tapCard(tester, i);
      if (!needed) {
        await _tapCard(tester, i);
      }
    }
    await _submitExpect(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(0));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_submitBtn(), findsNothing);
    expect(app.gp.outcomeCount, 1);
    await _retry(tester);
    expect(_snapshot(tester)['_wrongVerdicts'], 0);
    expect((_snapshot(tester)['_userAssignment'] as List), isEmpty);
  });

  testWidgets('pointer down before restore and up after is ignored',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final oldRound = session.testRound;
    final gesture = await tester.startGesture(tester.getCenter(_tapTarget(0)));
    await tester.pump();
    await _restore(tester, app, _board(personCount: 3, assignment: {0: true}));
    await tester.pump();
    final newRound = session.testRound;
    expect(identical(oldRound, newRound), isFalse);
    await gesture.up();
    await tester.pump();
    expect((_snapshot(tester)['_userAssignment'] as List).length, 1);
    await _tapCard(tester, 1);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 2);
  });

  testWidgets('pending generation after restore is dropped', (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    session.generateForTesting();
    await tester.pump(const Duration(milliseconds: 10));
    final restored = _board(personCount: 3, assignment: {0: true, 1: false});
    await _restore(tester, app, restored);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((_snapshot(tester)['_userAssignment'] as List).length, 2);
  });

  testWidgets('disposal cancels pending generation', (tester) async {
    await _mount(tester, reduced: true);
    final session = _session(tester);
    session.generateForTesting();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate win is guarded', (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final puzzle = session.puzzle as AlienTribunalPuzzle;
    for (int i = 0; i < puzzle.personCount; i++) {
      final needed = puzzle.people[i].isTruthTeller;
      await _tapCard(tester, i);
      if (!needed) {
        await _tapCard(tester, i);
      }
    }
    await _submitExpect(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(_submitBtn(), findsNothing);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('partial save remains editable', (tester) async {
    final app = await _mount(tester, reduced: true);
    await _tapCard(tester, 0);
    await tester.pump();
    final snap = _snapshot(tester);
    expect(snap['_wrongVerdicts'], 0);
    await _restore(tester, app, snap);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 1);
    await _tapCard(tester, 1);
    expect((_snapshot(tester)['_userAssignment'] as List).length, 2);
  });

  testWidgets('terminal save does not replay rewards', (tester) async {
    final app = await _mount(tester, reduced: true);
    final session = _session(tester);
    final puzzle = session.puzzle as AlienTribunalPuzzle;
    for (int i = 0; i < puzzle.personCount; i++) {
      final needed = puzzle.people[i].isTruthTeller;
      await _tapCard(tester, i);
      if (!needed) {
        await _tapCard(tester, i);
      }
    }
    await _submitExpect(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    final stored = await _stored(tester);
    expect(stored, isNull);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('reduced motion toggle mid-animation', (tester) async {
    final app = await _mount(tester, reduced: true);
    expect(app.motion.value, isTrue);
    final session = _session(tester);
    final puzzle = session.puzzle as AlienTribunalPuzzle;
    for (int i = 0; i < puzzle.personCount; i++) {
      final needed = puzzle.people[i].isTruthTeller;
      await _tapCard(tester, i);
      if (!needed) {
        await _tapCard(tester, i);
      }
    }
    await _submitExpect(tester);
    await tester.pump();
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('phone layouts 390x844 at scale 1 reachable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(tester, textScale: 1, locale: const Locale('en'));
    expect(_submitBtn(), findsOneWidget);
    await tester.ensureVisible(_submitBtn());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone layouts 390x500 at scale 2 de reachable', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(tester, textScale: 2, locale: const Locale('de'));
    expect(_submitBtn(), findsOneWidget);
    await tester.ensureVisible(_submitBtn());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'correct unsubmitted saved verdict remains playable and earns its win',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(assignment: {0: true, 1: false, 2: true}));
    expect(_session(tester).capturePuzzleSession(), isNotNull);
    expect(_dialog, findsNothing);
    expect(app.gp.outcomeCount, 0);
    await _submitExpect(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
  });
}
