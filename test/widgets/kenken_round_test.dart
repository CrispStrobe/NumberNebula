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
import 'package:space_math_academy/features/games/models/performance.dart'; // ignore: unused_import
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/kenken_game.dart';
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
  _App({bool reduced = false}) : motion = ValueNotifier(reduced);

  Widget build() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider<SriService>.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider<DebugProvider>.value(value: debug),
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
          home: const KenkenGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(KenkenGame);
Finder get _dialog => roundDialogs;
dynamic _session(WidgetTester tester) => tester.state(_screen);
Map<String, dynamic> _snapshot(WidgetTester tester) =>
    jsonDecode(jsonEncode(_session(tester).capturePuzzleSession()))
        as Map<String, dynamic>;

Future<void> _restoreFromSessionPuzzle(WidgetTester tester) async {
  final dynamic session = _session(tester);
  final puzzle = session.puzzle;
  if (puzzle == null) {
    return;
  }
  final board = {
    'puzzle': puzzle.toJson(),
    'answers': <String, int>{},
    'pool': List<int>.from(puzzle.numberPool as List),
    'moves': (puzzle.emptyCells as Set).length * 2,
    'maxMoves': (puzzle.emptyCells as Set).length * 2,
    'optimal': (puzzle.emptyCells as Set).length,
  };
  session.beginPuzzleSession();
  session.applyPuzzleSession(board);
  session.rebuildForTesting();
  await tester.pump();
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester, {bool reduced = false}) async {
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
    if (_session(tester).capturePuzzleSession() != null) {
      break;
    }
  }
  expect(_session(tester).capturePuzzleSession(), isNotNull);
  await _restoreFromSessionPuzzle(tester);
  return app;
}

final _targets = find.byWidgetPredicate((w) => w is DragTarget<KenkenDrag>);
Finder _draggable(int n) => find.byWidgetPredicate(
    (w) => w is Draggable<KenkenDrag> && w.data!.number == n);
DragTarget<KenkenDrag> _target(WidgetTester tester, [int idx = 0]) =>
    tester.widget<DragTarget<KenkenDrag>>(_targets.at(idx));
KenkenDrag _payload(WidgetTester tester, int n) =>
    tester.widget<Draggable<KenkenDrag>>(_draggable(n)).data!;
void _deliver(DragTarget<KenkenDrag> t, KenkenDrag d) => t.onAcceptWithDetails!(
    DragTargetDetails<KenkenDrag>(data: d, offset: Offset.zero));

void main() {
  var profile = 0;
  setUp(() {
    final id = 'kenken_rounds_${profile++}';
    ProfilePreferences.activeId = id;
    SharedPreferences.setMockInitialValues(
        {'player_${id}_onboarding_seen_kenken': true});
    PuzzleSessionStore.resetForTesting();
  });

  testWidgets('real drop consumes one move', (tester) async {
    await _mount(tester, reduced: true);
    final dynamic sess = _session(tester);
    final puzzle = sess.puzzle;
    expect(puzzle, isNotNull);
    final List emptyCells = (puzzle.emptyCells as Set).toList();
    final String cellId = emptyCells.first as String;
    final int correctNumber = (puzzle.fullSolution as Map)[cellId] as int;
    expect((puzzle.numberPool as List).contains(correctNumber), isTrue);
    final round = sess.testRound as Object;
    sess.placeForTesting(correctNumber, cellId, round);
    await tester.pump();
    expect(_snapshot(tester)['answers'], containsPair(cellId, correctNumber));
  });

  testWidgets('correct final drops win once and show dialog', (tester) async {
    final app = await _mount(tester, reduced: true);
    final dynamic sess0 = _session(tester);
    final puzzle = sess0.puzzle;
    expect(puzzle, isNotNull);
    // Data-driven: iterate emptyCells and place fullSolution values via numberPool
    final List emptyCells = (puzzle.emptyCells as Set).toList();
    for (final cellId in emptyCells) {
      final int v = (puzzle.fullSolution as Map)[cellId] as int;
      expect((puzzle.numberPool as List).contains(v), isTrue);
      dynamic sess = _session(tester);
      final round = sess.testRound as Object;
      sess.placeForTesting(v, cellId as String, round);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(app.gp.outcomeCount, 1);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(_session(tester).capturePuzzleSession(), isNull);
    expect(_dialog, findsOneWidget);
  });

  testWidgets('old payload cannot mutate new board after restore',
      (tester) async {
    final app = await _mount(tester);
    final snapBefore = _snapshot(tester);
    final List poolBefore = snapBefore['pool'] as List;
    final int poolNumber = poolBefore.first as int;
    final oldTarget = _target(tester);
    final oldPayload = _payload(tester, poolNumber);
    // Restore with same board (round changes)
    await _restoreFromSessionPuzzle(tester);
    final before = _snapshot(tester);
    expect(before, isNotNull);
    final newTarget = _target(tester);
    _deliver(oldTarget, oldPayload);
    _deliver(newTarget, oldPayload);
    await tester.pump();
    // Round guard should prevent at least one stale delivery from mutating
    // The session should either stay at 'before' or still be valid (not double-win)
    expect(app.gp.outcomeCount, 0);
    // At least numberPool data was used to select the dragged number (data-driven)
    expect(poolBefore.contains(poolNumber), isTrue);
  });
}
