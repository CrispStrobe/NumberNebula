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
import 'package:space_math_academy/features/games/screens/warp_fold_game.dart';
import 'package:space_math_academy/features/games/services/warp_fold_logic.dart';
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
          home: const WarpFoldGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(WarpFoldGame);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
        {int seed = 7, int wrong = 0, bool retry = false}) =>
    {
      '_puzzle':
          WarpFoldGenerator(seed: seed).generate(grade: 1, level: 1).toJson(),
      '_selectedOption': null,
      '_wrongAnswers': wrong,
      '_retryPending': retry,
    };

Future<void> _restore(
    WidgetTester tester, _App app, Map<String, dynamic> board) async {
  _session(tester).beginPuzzleSession();
  _session(tester).applyPuzzleSession(board);
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    app.motion.dispose();
  });
  await tester.pumpWidget(app.build());
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  if (board != null) await _restore(tester, app, board);
  return app;
}

Finder _submit(WidgetTester tester) => find
    .ancestor(
      of: find.text(_strings(tester).warpFoldTitle),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    )
    .first;

Future<void> _pick(WidgetTester tester, int index) async {
  final card = find
      .ancestor(
        of: find.text('${index + 1}'),
        matching: find.byType(GestureDetector),
      )
      .first;
  await tester.tap(card);
  await tester.pump();
}

Future<void> _submitOption(WidgetTester tester, int index) async {
  await _pick(tester, index);
  await tester.tap(_submit(tester));
  await tester.pump();
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
  expect(tester.takeException(), isNull);
}

void main() {
  var profile = 0;
  setUp(() {
    final id = 'warp_fold_rounds_${profile++}';
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = id;
    PuzzleSessionStore.resetForTesting();
  });

  for (final reduced in [false, true]) {
    testWidgets('intro and replay finish and return options (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      await _frames(tester, 110);
      expect(_submit(tester), findsOneWidget);
      await tester.tap(find.byTooltip(_strings(tester).warpFoldReplay));
      await tester.pump();
      if (!reduced) {
        expect(find.byTooltip(_strings(tester).warpFoldReplay), findsNothing);
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byTooltip(_strings(tester).warpFoldReplay), findsNothing,
            reason: 'Full-motion replay retains its 1500ms duration');
      }
      await _frames(tester, 110);
      expect(find.byTooltip(_strings(tester).warpFoldReplay), findsOneWidget);
      expect(_submit(tester), findsOneWidget);
      expect(app.gp.outcomeCount, 0);
      await _unmount(tester);
    });
  }

  testWidgets('motion toggling during replay completes once and restores play',
      (tester) async {
    final app = await _mount(tester, board: _board());
    await tester.tap(find.byTooltip(_strings(tester).warpFoldReplay));
    await tester.pump(const Duration(milliseconds: 100));
    app.motion.value = true;
    await tester.pump();
    app.motion.value = false;
    await _frames(tester, 12);
    expect(_submit(tester), findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets(
      'wrong answer retry remains saveable and grades retained mistakes',
      (tester) async {
    final app = await _mount(tester, board: _board());
    final correct =
        (_snapshot(tester)['_puzzle'] as Map)['correctIndex'] as int;
    await _submitOption(tester, (correct + 1) % 5);
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_session(tester).puzzleSessionFinished, isTrue);
    expect(_snapshot(tester)['_retryPending'], isTrue);
    expect(tester.widget<ElevatedButton>(_submit(tester)).onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(tester.widget<ElevatedButton>(_submit(tester)).onPressed, isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_session(tester).puzzleSessionFinished, isFalse);
    expect(_snapshot(tester)['_wrongAnswers'], 1);
    expect(_snapshot(tester)['_retryPending'], isFalse);
    await _submitOption(tester, correct);
    await _frames(tester, 25);
    expect(app.gp.outcomeCount, 2);
    expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(1, per: 0.25));
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(find.text(_strings(tester).warpFoldWinTitle), findsOneWidget);
    await _frames(tester, 180);
    expect(app.gp.outcomeCount, 2);
    await _unmount(tester);
  });

  testWidgets('restored pending retry unlocks without recounting a loss',
      (tester) async {
    final app = await _mount(tester, board: _board(wrong: 2, retry: true));
    expect(_snapshot(tester)['_retryPending'], isTrue);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(_snapshot(tester)['_retryPending'], isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_snapshot(tester)['_wrongAnswers'], 2);
    expect(_snapshot(tester)['_retryPending'], isFalse);
    expect(app.gp.outcomeCount, 0);
    expect(_session(tester).puzzleSessionFinished, isFalse);
    await _unmount(tester);
  });

  testWidgets('restoring during replay invalidates its old completion',
      (tester) async {
    final app = await _mount(tester, board: _board());
    await tester.tap(find.byTooltip(_strings(tester).warpFoldReplay));
    await tester.pump(const Duration(milliseconds: 100));
    final replacement = _board(seed: 23, wrong: 2);
    await _restore(tester, app, replacement);
    await tester.pump(const Duration(seconds: 3));
    expect(_snapshot(tester)['_puzzle'], replacement['_puzzle']);
    expect(_snapshot(tester)['_wrongAnswers'], 2);
    expect(_submit(tester), findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    await _unmount(tester);
  });

  testWidgets('stale retry cannot unlock a restored winning board',
      (tester) async {
    final app = await _mount(tester, board: _board());
    final correct =
        (_snapshot(tester)['_puzzle'] as Map)['correctIndex'] as int;
    await _submitOption(tester, (correct + 1) % 5);
    await tester.pump(const Duration(milliseconds: 200));
    final replacement = _board(seed: 23);
    await _restore(tester, app, replacement);
    final nextCorrect = (replacement['_puzzle'] as Map)['correctIndex'] as int;
    await _submitOption(tester, nextCorrect);
    await _frames(tester, 180);
    expect(app.gp.outcomeCount, 2);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(tester.widget<ElevatedButton>(_submit(tester)).onPressed, isNull);
    await _unmount(tester);
  });

  for (final folding in [false, true]) {
    testWidgets('disposing pending effects is safe (folding:$folding)',
        (tester) async {
      final app = await _mount(tester, board: _board());
      if (folding) {
        await tester.tap(find.byTooltip(_strings(tester).warpFoldReplay));
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        final correct =
            (_snapshot(tester)['_puzzle'] as Map)['correctIndex'] as int;
        await _submitOption(tester, (correct + 1) % 5);
      }
      final outcomes = app.gp.outcomeCount;
      await _unmount(tester);
      expect(app.gp.outcomeCount, outcomes);
    });
  }
}
