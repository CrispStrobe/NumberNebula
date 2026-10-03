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
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/perspective_puzzle_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final motion = ValueNotifier(false);
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  late final gp = GameProvider(
      progressService: ProgressService(),
      sriService: sri,
      cognitiveProfileService: cognitive);

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
          home: const PerspectivePuzzleGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(PerspectivePuzzleGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;

Map<String, dynamic> _snapshot(WidgetTester tester) =>
    Map<String, dynamic>.from(
        jsonDecode(jsonEncode(_session(tester).capturePuzzleSession())) as Map);

Map<String, dynamic> _board({int lives = 3, bool finalTurn = false}) {
  const Block block = (x: 0, y: 0, z: 0, color: Colors.blue);
  final PerspectiveView correct = [
    [block]
  ];
  final puzzle = PerspectivePuzzle(
    structure: {block},
    gridSize: 1,
    maxHeight: 1,
    difficulty: 1,
    correctViews: {
      for (final side in ['Front', 'Right', 'Back', 'Left']) side: correct,
    },
  );
  final views = <PerspectiveView>[
    correct,
    [
      [(x: 0, y: 0, z: 0, color: Colors.red)]
    ],
    [
      [null]
    ],
    [
      [(x: 0, y: 0, z: 0, color: Colors.yellow)]
    ],
  ];
  return {
    'currentPuzzle': puzzle.toJson(),
    '_perspectivesToSolve': finalTurn ? ['Front'] : ['Front', 'Right'],
    '_currentTurnIndex': 0,
    '_answerChoices': [
      for (final view in views)
        [
          for (final row in view)
            [
              for (final cell in row)
                cell == null
                    ? null
                    : {
                        'x': cell.x,
                        'y': cell.y,
                        'z': cell.z,
                        'color': cell.color.toARGB32(),
                      },
            ],
        ],
    ],
    '_correctAnswerIndex': 0,
    '_correctAttempts': 0,
    '_totalAttempts': 0,
    '_lives': lives,
    '_answerState': 'unanswered',
    '_selectedAnswerIndex': -1,
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
    {int lives = 3, bool finalTurn = false}) async {
  final app = _App();
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(app.motion.dispose);
  await tester.pumpWidget(app.build());
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restore(tester, app, _board(lives: lives, finalTurn: finalTurn));
  return app;
}

Finder _choice(WidgetTester tester, int index) {
  final label = _strings(tester).a11yAnswerChoice(index + 1);
  return find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label);
}

Future<void> _answer(WidgetTester tester, int index) async {
  final choice = _choice(tester, index);
  expect(choice, findsOneWidget);
  await tester.tap(choice);
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'perspective_callbacks_${profile++}';
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'correct answers advance after one second and final win occurs once',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 0);
    await _answer(tester, 1);
    expect(_snapshot(tester)['_totalAttempts'], 1,
        reason: 'Answer feedback must lock duplicate taps');
    await tester.pump(const Duration(milliseconds: 999));
    expect(_snapshot(tester)['_currentTurnIndex'], 0);
    expect(app.gp.outcomeCount, 0);
    await tester.pump(const Duration(milliseconds: 2));
    final next = _snapshot(tester);
    expect(next['_currentTurnIndex'], 1);
    expect(next['_correctAttempts'], 1);
    expect(next['_totalAttempts'], 1);
    expect(next['_answerState'], 'unanswered');
    await _answer(tester, next['_correctAnswerIndex'] as int);
    await tester.pump(const Duration(milliseconds: 1001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(_dialog, findsOneWidget);
    expect(
        find.text(_strings(tester).perspectivePuzzleWinTitle), findsOneWidget);
    final score = app.gp.score;
    await tester.pump(const Duration(seconds: 3));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.score, score);
    expect(_dialog, findsOneWidget);
    await _unmount(tester);
  });

  testWidgets(
      'wrong answer retry unlocks after 1.5 seconds without extra attempts',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 1);
    await tester.pump(const Duration(milliseconds: 1499));
    await _answer(tester, 0);
    final locked = _snapshot(tester);
    expect(locked['_answerState'], 'incorrect');
    expect(locked['_totalAttempts'], 1);
    expect(locked['_lives'], 2);
    await tester.pump(const Duration(milliseconds: 2));
    expect(_snapshot(tester)['_answerState'], 'unanswered');
    await _answer(tester, 0);
    await tester.pump(const Duration(milliseconds: 1001));
    final next = _snapshot(tester);
    expect(next['_currentTurnIndex'], 1);
    expect(next['_totalAttempts'], 2);
    expect(next['_correctAttempts'], 1);
    expect(next['_lives'], 2);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets('last life reports delayed failure once', (tester) async {
    final app = await _mount(tester, lives: 1);
    await _answer(tester, 1);
    await _answer(tester, 0);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 1);
    expect(
        find.text(_strings(tester).perspectivePuzzleLoseTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(app.gp.outcomeCount, 1);
    expect(_dialog, findsOneWidget);
    await _unmount(tester);
  });

  for (final pending in ['advance', 'win', 'retry', 'failure']) {
    testWidgets('restored board cancels pending $pending callback',
        (tester) async {
      final app = await _mount(tester,
          lives: pending == 'failure' ? 1 : 3, finalTurn: pending == 'win');
      await _answer(tester, pending == 'retry' || pending == 'failure' ? 1 : 0);
      await tester.pump(const Duration(milliseconds: 500));
      await _restore(tester, app, _board());
      final restored = _snapshot(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_snapshot(tester), restored);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      await _unmount(tester);
    });

    testWidgets('disposal cancels pending $pending callback', (tester) async {
      final app = await _mount(tester,
          lives: pending == 'failure' ? 1 : 3, finalTurn: pending == 'win');
      await _answer(tester, pending == 'retry' || pending == 'failure' ? 1 : 0);
      await _unmount(tester);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
    });
  }

  testWidgets('old retry deadline cannot unlock new answer feedback',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await _restore(tester, app, _board());
    await _answer(tester, 1);
    await tester.pump(const Duration(milliseconds: 1001));
    await _answer(tester, 0);
    expect(_snapshot(tester)['_answerState'], 'incorrect');
    expect(_snapshot(tester)['_totalAttempts'], 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_snapshot(tester)['_answerState'], 'unanswered');
    expect(_snapshot(tester)['_lives'], 2);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  for (final feedback in ['correct', 'win', 'retry', 'failure']) {
    testWidgets(
        'saved $feedback feedback resumes with its lock and coherent counters',
        (tester) async {
      final app = await _mount(tester,
          lives: feedback == 'failure' ? 1 : 3, finalTurn: feedback == 'win');
      final correct = feedback == 'correct' || feedback == 'win';
      await _answer(tester, correct ? 0 : 1);
      await tester.pump(const Duration(milliseconds: 600));
      final pending = _snapshot(tester);
      expect(pending['_answerState'], correct ? 'correct' : 'incorrect');
      await _restore(tester, app, pending);
      // Pass the old deadline while staying before the restored deadline.
      await tester.pump(Duration(milliseconds: correct ? 450 : 950));
      await _answer(tester, correct ? 1 : 0);
      expect(_snapshot(tester), pending,
          reason: 'Restored feedback must not repeat a guess or unlock early');
      expect(app.gp.outcomeCount, 0);
      await tester.pump(const Duration(milliseconds: 551));
      if (feedback == 'failure' || feedback == 'win') {
        await tester.pump(const Duration(milliseconds: 300));
        expect(app.gp.outcomeCount, 1);
        expect(_dialog, findsOneWidget);
      } else {
        final next = _snapshot(tester);
        expect(next['_totalAttempts'], 1);
        expect(next['_correctAttempts'], correct ? 1 : 0);
        expect(next['_currentTurnIndex'], correct ? 1 : 0);
        expect(next['_answerState'], 'unanswered');
        expect(next['_lives'], correct ? 3 : 2);
      }
      await _unmount(tester);
    });
  }

  for (final feedback in ['advance', 'win', 'failure']) {
    testWidgets(
        'legacy snapshot resumes pending $feedback without repeating a guess',
        (tester) async {
      final correct = feedback != 'failure';
      final app = await _mount(tester,
          lives: correct ? 3 : 1, finalTurn: feedback == 'win');
      await _answer(tester, correct ? 0 : 1);
      final legacy = _snapshot(tester)
        ..remove('_answerState')
        ..remove('_selectedAnswerIndex');
      await _restore(tester, app, legacy);
      final inferred = _snapshot(tester);
      expect(inferred['_answerState'], correct ? 'correct' : 'incorrect');
      expect(inferred['_totalAttempts'], 1);
      expect(inferred['_correctAttempts'], correct ? 1 : 0);
      await tester.pump(Duration(milliseconds: correct ? 1001 : 1501));
      if (feedback == 'advance') {
        final next = _snapshot(tester);
        expect(next['_currentTurnIndex'], 1);
        expect(next['_totalAttempts'], 1);
        expect(next['_correctAttempts'], 1);
        expect(app.gp.outcomeCount, 0);
      } else {
        await tester.pump(const Duration(milliseconds: 300));
        expect(app.gp.outcomeCount, 1);
        expect(_dialog, findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(app.gp.outcomeCount, 1);
      }
      await _unmount(tester);
    });
  }
}
