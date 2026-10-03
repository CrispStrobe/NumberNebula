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
import 'package:space_math_academy/features/games/screens/signal_triangulation_game.dart';
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
          home: const SignalTriangulationGame(grade: 1, level: 1),
        ),
      );
}

final _screen = find.byType(SignalTriangulationGame);
dynamic _session(WidgetTester tester) => tester.state(_screen);
S _strings(WidgetTester tester) => S.of(tester.element(_screen))!;

Map<String, dynamic> _board({int allowance = 3}) => {
      'secret': ['alpha', 'alpha', 'alpha', 'alpha'],
      'guess': ['empty', 'empty', 'empty', 'empty'],
      'position': 0,
      'history': <Map<String, dynamic>>[],
      'length': 4,
      'maxGuesses': allowance,
      'glyphs': SignalGlyph.getAllGlyphs().map((glyph) => glyph.name).toList(),
    };

Future<void> _restore(WidgetTester tester, _App app,
    {int allowance = 3}) async {
  final dynamic session = _session(tester);
  session.beginPuzzleSession();
  session.applyPuzzleSession(_board(allowance: allowance));
  // Rebuild through a real dependency update, without private game methods.
  final reduced = app.motion.value;
  app.motion.value = !reduced;
  await tester.pump();
  app.motion.value = reduced;
  await tester.pump();
}

Future<_App> _mount(WidgetTester tester) async {
  final app = _App();
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(app.motion.dispose);
  await tester.pumpWidget(app.build());
  for (var i = 0; i < 3; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await _restore(tester, app);
  return app;
}

Future<void> _fill(WidgetTester tester, String glyph) async {
  final label = _strings(tester).a11yGlyph(glyph);
  final selector = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label);
  expect(selector, findsOneWidget);
  for (var index = 0; index < 4; index++) {
    await tester.tap(selector);
    await tester.pump();
  }
}

Future<void> _transmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(
      ElevatedButton, _strings(tester).signalTriangulationTransmit));
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
    ProfilePreferences.activeId = 'signal_callbacks_${profile++}';
    PuzzleSessionStore.resetForTesting();
  });

  for (final action in ['clear', 'transmit', 'restore']) {
    testWidgets('$action invalidates the previous auto-submit delay',
        (tester) async {
      final app = await _mount(tester);
      await _fill(tester, 'beta');
      await tester.pump(const Duration(milliseconds: 300));
      if (action == 'clear') {
        await tester.tap(find.widgetWithText(
            ElevatedButton, _strings(tester).signalTriangulationClear));
        await tester.pump();
      } else if (action == 'transmit') {
        await _transmit(tester);
      } else {
        await _restore(tester, app);
      }
      final expectedHistory = action == 'transmit' ? 1 : 0;
      await _fill(tester, 'beta');
      // The old deadline has passed, but this new guess still has 250ms left.
      await tester.pump(const Duration(milliseconds: 250));
      final dynamic session = _session(tester);
      expect(session.capturePuzzleSession()['history'],
          hasLength(expectedHistory));
      expect(session.capturePuzzleSession()['position'], 4);
      await tester.pump(const Duration(milliseconds: 260));
      expect(session.capturePuzzleSession()['history'],
          hasLength(expectedHistory + 1));
      expect(session.capturePuzzleSession()['position'], 0);
      expect(app.gp.outcomeCount, 0);
      await _unmount(tester);
    });
  }

  for (final win in [true, false]) {
    testWidgets('delayed ${win ? 'win' : 'loss'} dialog completes once',
        (tester) async {
      final app = await _mount(tester);
      await _restore(tester, app, allowance: 1);
      final s = _strings(tester);
      final title =
          win ? s.signalTriangulationWinTitle : s.signalTriangulationLoseTitle;
      await _fill(tester, win ? 'alpha' : 'beta');
      await _transmit(tester);
      expect(app.gp.outcomeCount, 1);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text(title), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(title), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(title), findsOneWidget);
      expect(app.gp.outcomeCount, 1);
      await tester.tap(
          find.widgetWithText(ElevatedButton, win ? s.nextSignal : s.tryAgain));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_session(tester).capturePuzzleSession()['history'], isEmpty);
      // The old round's 12-second header deadline must not collapse this round.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 600));
      expect(_session(tester).showHeader, isTrue);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });

    testWidgets('restore cancels the old ${win ? 'win' : 'loss'} dialog',
        (tester) async {
      final app = await _mount(tester);
      await _restore(tester, app, allowance: 1);
      await _fill(tester, win ? 'alpha' : 'beta');
      await _transmit(tester);
      expect(app.gp.outcomeCount, 1);
      await tester.pump(const Duration(milliseconds: 100));
      await _restore(tester, app);
      await tester.pump(const Duration(milliseconds: 1300));
      expect(
          find.byWidgetPredicate((widget) => widget is Dialog), findsNothing);
      expect(_session(tester).capturePuzzleSession()['history'], isEmpty);
      expect(_session(tester).gameActive, isTrue);
      expect(app.gp.outcomeCount, 1);
      await _unmount(tester);
    });
  }

  for (final pending in ['submit', 'win', 'loss']) {
    testWidgets('disposal cancels pending $pending callbacks', (tester) async {
      final app = await _mount(tester);
      await _restore(tester, app, allowance: 1);
      await _fill(tester, pending == 'win' ? 'alpha' : 'beta');
      if (pending != 'submit') await _transmit(tester);
      final outcomes = app.gp.outcomeCount;
      await _unmount(tester);
      expect(app.gp.outcomeCount, outcomes);
      expect(
          find.byWidgetPredicate((widget) => widget is Dialog), findsNothing);
    });
  }

  testWidgets('restore during header collapse keeps the new header visible',
      (tester) async {
    final app = await _mount(tester);
    await tester.pump(const Duration(seconds: 12));
    await _restore(tester, app);
    await tester.pump(const Duration(milliseconds: 600));
    expect(_session(tester).showHeader, isTrue);
    expect(_session(tester).gameActive, isTrue);
    await _unmount(tester);
  });

  testWidgets('Reduce motion suspends radar and pulse decoration',
      (tester) async {
    final app = await _mount(tester);
    final paint = find.byWidgetPredicate((widget) =>
        widget is CustomPaint && widget.painter is SignalBackgroundPainter);
    final initial = tester.widget<CustomPaint>(paint);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<CustomPaint>(paint), isNot(same(initial)));
    app.motion.value = true;
    await tester.pump();
    final stopped = tester.widget<CustomPaint>(paint);
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<CustomPaint>(paint), same(stopped));
    }
    app.motion.value = false;
    await tester.pump();
    final resumed = tester.widget<CustomPaint>(paint);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<CustomPaint>(paint), isNot(same(resumed)));
    expect(_session(tester).capturePuzzleSession()['history'], isEmpty);
    await _unmount(tester);
  });
}
