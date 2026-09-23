// Tests for game_registry.dart: every game is reachable by gameKey, and
// DeferredGameLoader shows a loading screen, then the game, or a retry
// screen when the download fails.
//
// In the Dart VM deferred libraries are already loaded, so the loader tests
// drive DeferredGameLoader with their own load functions to exercise the slow
// and failing paths a web visitor can hit.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/models/skill_category.dart';
import 'package:space_math_academy/features/games/game_registry.dart';
import 'package:space_math_academy/features/missions/data/game_pool.dart';
import 'package:space_math_academy/generated/l10n.dart';

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: child,
    );

void main() {
  setUp(DeferredGameLoader.resetForTesting);

  group('registry', () {
    test('registers all 48 games, each with a skill mapping', () {
      final keys = registeredGameKeys.toSet();
      expect(keys.length, 48);
      expect(keys.difference(gameSkillMap.keys.toSet()), isEmpty);
    });

    test('game_pool exposes a builder for every registered game', () {
      expect(gameBuilders.keys.toSet(), registeredGameKeys.toSet());
    });

    test('unknown keys have no builder', () {
      expect(gameBuilderFor('no_such_game'), isNull);
    });

    test('builders return a loader keyed by the game', () {
      final widget = gameBuilderFor('kenken')!(2, 3);
      expect(widget, isA<DeferredGameLoader>());
      expect((widget as DeferredGameLoader).gameKey, 'kenken');
      expect(widget.key, const ValueKey('deferred_kenken'));
    });

    test('every registered game library loads', () async {
      // Catches a registry entry whose deferred import points at the wrong
      // library before it reaches a browser.
      for (final key in registeredGameKeys) {
        final loader = gameBuilderFor(key)!(1, 1) as DeferredGameLoader;
        await expectLater(loader.load(), completes, reason: key);
      }
    });
  });

  group('DeferredGameLoader', () {
    testWidgets('shows a loading screen until the code arrives', (tester) async {
      final download = Completer<void>();
      await tester.pumpWidget(_app(DeferredGameLoader(
        gameKey: 'slow',
        load: () => download.future,
        builder: (_) => const Text('game ready'),
      )));

      expect(find.byKey(const ValueKey('deferred_game_loading')), findsOneWidget);
      expect(find.text('game ready'), findsNothing);

      download.complete();
      await tester.pump();

      expect(find.text('game ready'), findsOneWidget);
      expect(DeferredGameLoader.isLoaded('slow'), isTrue);
    });

    testWidgets('a game opened before builds without a loading frame',
        (tester) async {
      DeferredGameLoader.markLoaded('warm');
      var loads = 0;
      await tester.pumpWidget(_app(DeferredGameLoader(
        gameKey: 'warm',
        load: () async => loads++,
        builder: (_) => const Text('game ready'),
      )));

      expect(find.text('game ready'), findsOneWidget);
      expect(loads, 0);
    });

    testWidgets('a failed download offers a retry that recovers',
        (tester) async {
      var attempts = 0;
      await tester.pumpWidget(_app(DeferredGameLoader(
        gameKey: 'flaky',
        load: () async {
          attempts++;
          if (attempts == 1) throw Exception('offline');
        },
        builder: (_) => const Text('game ready'),
      )));
      await tester.pump();

      final s = await S.delegate.load(const Locale('en'));
      expect(find.text(s.gameLoadFailedTitle), findsOneWidget);
      expect(DeferredGameLoader.isLoaded('flaky'), isFalse);

      await tester.tap(find.text(s.tryAgain));
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(find.text('game ready'), findsOneWidget);
    });

    testWidgets('leaving before the download ends does not throw',
        (tester) async {
      final download = Completer<void>();
      await tester.pumpWidget(_app(DeferredGameLoader(
        gameKey: 'abandoned',
        load: () => download.future,
        builder: (_) => const Text('game ready'),
      )));
      await tester.pumpWidget(_app(const SizedBox()));

      download.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
