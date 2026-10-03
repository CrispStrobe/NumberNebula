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
import 'package:space_math_academy/features/games/screens/blocks_counter_game.dart';
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
          home: const BlockCounterGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(BlockCounterGame);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;

Map<String, dynamic> _board({bool wrongHighlight = false}) => {
      'currentPuzzle': BlockCountingPuzzle(
        blockStructure: BlockStructure(
          blocks: [
            BlockPosition3D(
                x: 0, y: 0, z: 0, isVisible: true, color: Colors.cyan),
          ],
          gridWidth: 1,
          gridDepth: 1,
          maxHeight: 1,
        ),
        correctAnswer: 1,
        answerChoices: [1, 2, 3, 4],
        difficulty: 1,
      ).toJson(),
      'userAnswer': wrongHighlight ? 2 : null,
      'answerChoices': [1, 2, 3, 4],
      '_selectedAnswerIndex': wrongHighlight ? 1 : -1,
      '_wrongAnswers': wrongHighlight ? 1 : 0,
    };

Future<void> _restore(WidgetTester tester, _App app,
    {bool wrongHighlight = false}) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(_board(wrongHighlight: wrongHighlight));
  app.motion.value = true;
  await tester.pump();
  app.motion.value = false;
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester) async {
  final app = _App();
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(app.motion.dispose);
  await tester.pumpWidget(app.build());
  final dynamic session = _session(tester);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (session.capturePuzzleSession() != null) break;
  }
  expect(session.capturePuzzleSession(), isNotNull);
  await _restore(tester, app);
  return app;
}

Future<void> _answer(WidgetTester tester, int answer) async {
  final label = _strings(tester).a11yAnswer('$answer');
  final option = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label);
  expect(option, findsOneWidget);
  await tester.tap(option);
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1300));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'block_callbacks_${profile++}';
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('wrong answer unlocks after its original delay, then wins once',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 2);
    expect(app.gp.outcomeCount, 1);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_session(tester).userAnswer, 2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_session(tester).userAnswer, isNull);
    expect(_session(tester).capturePuzzleSession()['_wrongAnswers'], 1);
    await _answer(tester, 1);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_session(tester).userAnswer, 1);
    expect(app.gp.outcomeCount, 2);
    await _unmount(tester);
  });

  for (final newAnswer in [1, 3]) {
    testWidgets('restoration cancels old feedback before answer $newAnswer',
        (tester) async {
      final app = await _mount(tester);
      await _answer(tester, 2);
      await tester.pump(const Duration(milliseconds: 300));
      await _restore(tester, app);
      await _answer(tester, newAnswer);
      await tester.pump(const Duration(milliseconds: 750));
      expect(_session(tester).userAnswer, newAnswer,
          reason: 'The old deadline must not clear the restored round answer');
      expect(app.gp.outcomeCount, 2);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_session(tester).userAnswer, newAnswer == 1 ? 1 : isNull);
      expect(app.gp.outcomeCount, 2);
      await _unmount(tester);
    });
  }

  testWidgets('restored wrong highlight allows retry and retains mistakes',
      (tester) async {
    final app = await _mount(tester);
    await _restore(tester, app, wrongHighlight: true);
    expect(_session(tester).userAnswer, isNull);
    expect(_session(tester).capturePuzzleSession()['_wrongAnswers'], 1);
    expect(_session(tester).capturePuzzleSession()['_selectedAnswerIndex'], -1);
    await _answer(tester, 1);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.performance, 0.75);
    await _unmount(tester);
  });

  testWidgets('disposal cancels feedback without changing outcomes',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 2);
    await _unmount(tester);
    expect(app.gp.outcomeCount, 1);
  });

  testWidgets('restoration supersedes an in-flight next-puzzle generation',
      (tester) async {
    final app = await _mount(tester);
    await _answer(tester, 1);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.widgetWithText(
        TextButton, _strings(tester).blockCounterNextPuzzle));
    // Restore before giving the isolate's result a chance to return.
    await _restore(tester, app);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(_session(tester).capturePuzzleSession(), _board());
    expect(app.gp.outcomeCount, 1);
    await _unmount(tester);
  });
}
