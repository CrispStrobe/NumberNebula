import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/player_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/streak_service.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/game_menu_screen.dart';
import 'package:space_math_academy/features/home/screens/home_screen.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_hub_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_repository.dart';
import 'package:space_math_academy/generated/l10n.dart';

class _HomeFixture {
  final players = PlayerProfileService();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final debug = DebugProvider();
  final streak = StreakService(getNow: () => DateTime(2026, 11, 8));
  final navigator = GlobalKey<NavigatorState>();
  late final game = GameProvider(
    progressService: ProgressService(),
    sriService: sri,
    cognitiveProfileService: cognitive,
  );

  Future<void> load(String id) async {
    SharedPreferences.setMockInitialValues({
      'players_v1': jsonEncode([
        {'id': 'default', 'name': ''},
        {'id': id, 'name': 'Alexandra Weltraumforscherin'},
      ]),
      'active_player_v1': id,
      'player_${id}_streak_current': 365,
      'player_${id}_streak_longest': 365,
      'player_${id}_streak_lastDay': '2026-11-08',
    });
    await players.load();
    await streak.load();
    await sri.loadSriData();
  }

  Widget app({required String locale, required double scale}) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider.value(value: players),
          ChangeNotifierProvider.value(value: sri),
          ChangeNotifierProvider.value(value: cognitive),
          ChangeNotifierProvider.value(value: debug),
          ChangeNotifierProvider.value(value: streak),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: SpaceTheme.darkTheme,
          locale: Locale(locale),
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      );

  void dispose() {
    game.dispose();
    players.dispose();
    sri.dispose();
    cognitive.dispose();
    debug.dispose();
    streak.dispose();
  }
}

Future<void> _showHome(WidgetTester tester, _HomeFixture fixture,
    {required Size size, required String locale, required double scale}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(fixture.app(locale: locale, scale: scale));
  // Home has a continuously moving logo. Settle only its finite entrance.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _close(WidgetTester tester, _HomeFixture fixture) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  fixture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ProfilePreferences.activeId = 'default');

  for (final locale in ['de', 'en']) {
    testWidgets(
        'compact home keeps toolbar and course entry reachable ($locale)',
        (tester) async {
      final fixture = _HomeFixture();
      await fixture.load('home_$locale');
      await tester.runAsync(KompassRepository.load);
      await _showHome(tester, fixture,
          size: const Size(390, 500), locale: locale, scale: 2);
      final strings = S.of(tester.element(find.byType(HomeScreen)))!;
      expect(tester.takeException(), isNull);

      for (final action in [
        find.byTooltip(strings.imprint),
        find.byTooltip('Review'),
        find.byIcon(Icons.people_alt_outlined),
        find.byTooltip('Cognitive profile'),
        find.byTooltip(strings.settings),
        find.text('365'),
      ]) {
        expect(action.hitTestable(), findsOneWidget,
            reason:
                'Every existing toolbar action must fit the compact header.');
      }
      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(strings.savedPuzzlesTitle), findsOneWidget);
      expect(find.text('${strings.playersTitle}: Alexandra Weltraumforscherin'),
          findsOneWidget);
      fixture.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 300));

      final start = find.text(strings.startAdventure);
      await tester.ensureVisible(start);
      await tester.pump();
      expect(start.hitTestable(), findsOneWidget);
      final course = find.byKey(const ValueKey('open-kompass'));
      await tester.ensureVisible(course);
      await tester.pump();
      expect(course.hitTestable(), findsOneWidget);
      await tester.tap(course);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(KompassHubScreen), findsOneWidget);
      expect(
          find.byKey(const ValueKey('kompass-next-practice')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, fixture);
    });
  }

  testWidgets('landscape home retains the existing start-adventure route',
      (tester) async {
    final fixture = _HomeFixture();
    await fixture.load('home_landscape');
    await _showHome(tester, fixture,
        size: const Size(1280, 720), locale: 'en', scale: 1);
    final title = tester.getRect(find.text('NumberNebula'));
    final toolbar = tester.getRect(find.byKey(const ValueKey('home-toolbar')));
    expect(title.center.dy, closeTo(toolbar.center.dy, 1));
    final start = find.text('Start Your Math Adventure');
    await tester.ensureVisible(start);
    await tester.pump();
    expect(start.hitTestable(), findsOneWidget);
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GameMenuScreen), findsOneWidget);
    expect(find.byType(GameCard), findsWidgets);
    expect(tester.takeException(), isNull);
    await _close(tester, fixture);
  });
}
