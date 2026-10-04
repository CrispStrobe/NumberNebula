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
import 'package:space_math_academy/features/games/screens/crew_manifest_game.dart';
import 'package:space_math_academy/features/games/services/crew_manifest_logic.dart';
import 'package:space_math_academy/features/games/widgets/game_ui.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _App {
  final ValueNotifier<bool> motion;
  final sri = SriService();
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
          home: const CrewManifestGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(CrewManifestGame);
final _dialog = find.byWidgetPredicate((widget) => widget is Dialog);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Map<String, dynamic> _board(
    {int size = 3,
    bool complete = false,
    bool wrong = false,
    int mistakes = 0,
    bool changed = false}) {
  final names = ['Zara', 'Kip', 'Nova', 'Rex', 'Luna'].take(size).toList();
  final items =
      ['Helmet', 'Rope', 'Tools', 'Medkit', 'Radio'].take(size).toList();
  final targets = changed ? items.reversed.toList() : items;
  final puzzle = CrewManifestPuzzle(
      size: size,
      crewNames: names,
      itemNames: items,
      solution: {
        for (var index = 0; index < size; index++) names[index]: targets[index]
      },
      structuredClues: [
        for (var index = 0; index < size; index++)
          ManifestClue(
              type: ClueType.positive,
              crewName: names[index],
              itemName: targets[index])
      ]);
  return {
    'puzzle': puzzle.toJson(),
    '_wrongChecks': mistakes,
    '_gridState': [
      for (var row = 0; row < size; row++)
        for (var col = 0; col < size; col++)
          [
            '${row}_$col',
            complete
                ? (col ==
                        (wrong
                            ? (row + 1) % size
                            : (changed ? size - row - 1 : row))
                    ? 'check'
                    : 'cross')
                : 'empty'
          ],
    ]
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

final _cells = find.byWidgetPredicate(
    (widget) => widget is GestureDetector && widget.child is AnimatedContainer);
Finder _cell(WidgetTester tester, int row, int col) => _cells
    .at(row * ((_snapshot(tester)['puzzle'] as Map)['size'] as int) + col);
final _check = find.ancestor(
    of: find.byIcon(Icons.assignment_turned_in),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton));
Map<String, String> _marks(WidgetTester tester) =>
    Map.fromEntries((_snapshot(tester)['_gridState'] as List)
        .map((entry) => MapEntry(entry[0] as String, entry[1] as String)));
Future<void> _tapCell(WidgetTester tester, int row, int col) async {
  await tester.tap(_cell(tester, row, col));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(_check);
  await tester.pump();
}

Future<void> _match(WidgetTester tester, int row, int col) async {
  if (_marks(tester)['${row}_$col'] == 'cross') {
    await _tapCell(tester, row, col);
  }
  if (_marks(tester)['${row}_$col'] == 'empty') {
    await _tapCell(tester, row, col);
  }
}

void _grade(_App app, {int size = 3, int mistakes = 0, int outcomes = 1}) {
  expect(app.gp.outcomeCount, outcomes);
  expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
  expect(app.gp.lastOutcome!.score, 125 + size * 50);
  expect(app.gp.lastOutcome!.performance, Perf.fromMistakes(mistakes));
}

Future<void> _retry(WidgetTester tester) async {
  final button =
      find.widgetWithText(ElevatedButton, _strings(tester).playAgain);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    if (_session(tester).capturePuzzleSession() != null) break;
  }
  await tester.pump(const Duration(milliseconds: 300));
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  expect(_snapshot(tester)['_wrongChecks'], 0);
  expect(_marks(tester).values.every((value) => value == 'empty'), isTrue);
  expect(_dialog, findsNothing);
}

Future<Map<String, dynamic>?> _stored(WidgetTester tester) async {
  var complete = false;
  Map<String, dynamic>? saved;
  PuzzleSessionStore.instance.load('crew_manifest', 1, 1).then((value) {
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
    final id = 'crew_manifest_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_crew_manifest': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets(
      'actual cells cycle check cross empty and preserve eliminations needed by another check',
      (tester) async {
    await _mount(tester, reduced: true);
    await _tapCell(tester, 0, 0);
    expect(_marks(tester)['0_0'], 'check');
    expect(_marks(tester)['0_1'], 'cross');
    expect(_marks(tester)['1_0'], 'cross');
    expect(_marks(tester)['1_1'], 'empty');
    await _tapCell(tester, 1, 1);
    await _tapCell(tester, 0, 0);
    expect(_marks(tester)['0_0'], 'cross');
    expect(_marks(tester)['0_1'], 'cross',
        reason: 'The remaining column1 check still requires this elimination');
    expect(_marks(tester)['1_0'], 'cross',
        reason: 'The remaining row1 check still requires this elimination');
    expect(_marks(tester)['0_2'], 'empty');
    expect(_marks(tester)['2_0'], 'empty');
    await _tapCell(tester, 0, 0);
    expect(_marks(tester)['0_0'], 'empty');
  });

  testWidgets('incomplete check reports no result and remains editable',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _tapCell(tester, 0, 0);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.gp.outcomeCount, 0);
    expect(_snapshot(tester)['_wrongChecks'], 0);
    expect(_dialog, findsNothing);
    await _tapCell(tester, 1, 1);
    expect(_marks(tester)['1_1'], 'check');
  });

  for (final reduced in [false, true]) {
    testWidgets(
        'actual matching and check win once then retry (reduced:$reduced)',
        (tester) async {
      final app = await _mount(tester, reduced: reduced);
      for (var index = 0; index < 3; index++) {
        await _match(tester, index, index);
      }
      final cell = tester.widget<GestureDetector>(_cell(tester, 2, 2));
      final check = tester.widget<ElevatedButton>(_check);
      await _submit(tester);
      check.onPressed!();
      cell.onTap!();
      await tester.pump(const Duration(milliseconds: 700));
      _grade(app);
      expect(_dialog, findsOneWidget);
      expect(_session(tester).capturePuzzleSession(), isNull);
      expect(await _stored(tester), isNull);
      await _retry(tester);
      _grade(app);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'wrong complete assignment and later edit persist while later win grades saved checks',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, board: _board(complete: true, wrong: true, mistakes: 1));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(_dialog, findsNothing);
    var saved = await _stored(tester);
    expect(saved, isNotNull);
    expect(saved!['_wrongChecks'], 2);
    await _tapCell(tester, 0, 1);
    await tester.pump(const Duration(milliseconds: 1000));
    saved = await _stored(tester);
    expect(saved!['_wrongChecks'], 2);
    expect(
        Map.fromEntries((saved['_gridState'] as List)
            .map((entry) => MapEntry(entry[0], entry[1])))['0_1'],
        'cross');
    await _restore(tester, app, saved);
    expect(_snapshot(tester)['_gridState'], saved['_gridState']);
    await _tapCell(tester, 1, 2);
    await _tapCell(tester, 2, 0);
    for (var index = 0; index < 3; index++) {
      await _match(tester, index, index);
    }
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, mistakes: 2, outcomes: 2);
  });

  testWidgets(
      'correct unsubmitted saved matrix stays playable and restores transient highlights empty',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _tapCell(tester, 0, 0);
    final visual = tester.widget<AnimatedContainer>(find
        .descendant(
            of: _cell(tester, 0, 0), matching: find.byType(AnimatedContainer))
        .first);
    expect(
        ((visual.decoration! as BoxDecoration).border! as Border).top.width, 2);
    await _restore(tester, app, _board(complete: true, mistakes: 2));
    final restored = tester.widget<AnimatedContainer>(find
        .descendant(
            of: _cell(tester, 0, 0), matching: find.byType(AnimatedContainer))
        .first);
    expect(
        ((restored.decoration! as BoxDecoration).border! as Border).top.width,
        1);
    expect(restored.duration, Duration.zero);
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    _grade(app, mistakes: 2);
  });

  for (final size in [2, 3]) {
    testWidgets('retained cell check and back ignore replacement size$size',
        (tester) async {
      final app = await _mount(tester, board: _board(complete: true));
      final cell = tester.widget<GestureDetector>(_cell(tester, 2, 2));
      final check = tester.widget<ElevatedButton>(_check);
      final header = tester.widget<GameUI>(find.byType(GameUI));
      await _restore(tester, app, _board(size: size, changed: true));
      final before = _snapshot(tester);
      cell.onTap!();
      check.onPressed!();
      header.onBack();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_snapshot(tester), before);
      expect(_screen, findsOneWidget);
      expect(app.gp.outcomeCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final button in [false, true]) {
    testWidgets(
        'active ${button ? 'submit' : 'cell'} finger cannot affect same-size restored board',
        (tester) async {
      final app =
          await _mount(tester, reduced: true, board: _board(complete: true));
      final pointer = await tester.startGesture(
          tester.getCenter(button ? _check : _cell(tester, 0, 0)));
      await _restore(tester, app, _board(complete: true, changed: true));
      final before = _snapshot(tester);
      await pointer.up();
      await tester.pump();
      expect(_snapshot(tester), before);
      expect(app.gp.outcomeCount, 0);
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('replacement clears current and queued incomplete-check feedback',
      (tester) async {
    final app = await _mount(tester, reduced: true);
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsOneWidget);
    ScaffoldMessenger.of(tester.element(_screen)).showSnackBar(const SnackBar(
        content: Text('obsolete crew feedback'),
        duration: Duration(seconds: 20)));
    await _restore(tester, app, _board(changed: true));
    final before = _snapshot(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SnackBar), findsNothing);
    expect(_snapshot(tester), before);
    expect(app.gp.outcomeCount, 0);
  });

  for (final replace in [false, true]) {
    testWidgets(
        'closed result callbacks cannot exit or regenerate (replacement:$replace)',
        (tester) async {
      final app =
          await _mount(tester, reduced: true, board: _board(complete: true));
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
        await _restore(tester, app, _board(changed: true));
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
      'real retry generation cannot overwrite synchronously restored session',
      (tester) async {
    final app =
        await _mount(tester, reduced: true, board: _board(complete: true));
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    final retry = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, _strings(tester).playAgain));
    retry.onPressed!();
    expect(_session(tester).capturePuzzleSession(), isNull);
    _session(tester).beginPuzzleSession();
    _session(tester)
        .applyPuzzleSession(_board(size: 2, changed: true, mistakes: 7));
    app.motion.value = false;
    await tester.pump();
    app.motion.value = true;
    await tester.pump();
    final before = _snapshot(tester);
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_snapshot(tester), before);
    expect(_dialog, findsNothing);
    _grade(app);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mid-success reduction completes one-shot before finite framework ink settling',
      (tester) async {
    final app = await _mount(tester, board: _board(complete: true));
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

  testWidgets('disposal rejects retained cell submit and navigation callbacks',
      (tester) async {
    final app = await _mount(tester, board: _board(complete: true));
    final cell = tester.widget<GestureDetector>(_cell(tester, 2, 2));
    final check = tester.widget<ElevatedButton>(_check);
    final header = tester.widget<GameUI>(find.byType(GameUI));
    await tester.pumpWidget(const SizedBox.shrink());
    cell.onTap!();
    check.onPressed!();
    header.onBack();
    await tester.pump(const Duration(seconds: 2));
    expect(app.gp.outcomeCount, 0);
    expect(_dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'five-person phone board supports doubled text actual matches win and retry',
      (tester) async {
    final app = await _mount(tester,
        reduced: true, textScale: 2, board: _board(size: 5));
    expect(tester.takeException(), isNull,
        reason: 'The initial wide layout must also fit doubled text');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (var index = 0; index < 5; index++) {
      await tester.ensureVisible(_cell(tester, index, index));
      await tester.pump();
      await _match(tester, index, index);
    }
    await tester.ensureVisible(_check);
    await tester.pump();
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    expect(_dialog, findsOneWidget);
    _grade(app, size: 5);
    await _retry(tester);
    _grade(app, size: 5);
    expect(tester.takeException(), isNull);
  });
}
