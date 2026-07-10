// Automated layout audit: pumps every game at four device/orientation sizes
// and records RenderFlex "overflow" errors — the objective signal that a
// screen's layout breaks at that size. Prints one `AUDIT <config> <game>
// <status>` line per (game, size), then an `AUDIT_DONE` sentinel.
//
// Run (on a booted simulator, GEM env cleared for CocoaPods):
//   env -u GEM_HOME -u GEM_PATH -u RUBYOPT flutter test \
//     integration_test/layout_audit_test.dart -d <sim-udid>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:space_math_academy/main.dart' as app;
import 'package:space_math_academy/core/theme/space_theme.dart';
import 'package:space_math_academy/generated/l10n.dart';
import 'package:space_math_academy/features/missions/data/game_pool.dart';
import 'package:space_math_academy/features/missions/providers/mission_provider.dart';

// Logical sizes (dp). Phone ~ iPhone 16 Pro Max; tablet ~ iPad Pro 13".
const _configs = <String, Size>{
  'iphone-landscape': Size(956, 440),
  'iphone-portrait': Size(440, 956),
  'ipad-landscape': Size(1366, 1032),
  'ipad-portrait': Size(1032, 1366),
};

Widget _wrap(Widget game, MissionProvider mission) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app.gameProvider),
      ChangeNotifierProvider.value(value: app.sriService),
      ChangeNotifierProvider.value(value: app.cognitiveProfileService),
      ChangeNotifierProvider.value(value: app.gridlockPuzzleTracker),
      ChangeNotifierProvider.value(value: app.purchaseService),
      ChangeNotifierProvider.value(value: app.debugProvider),
      ChangeNotifierProvider.value(value: app.streakService),
      ChangeNotifierProvider.value(value: mission),
      Provider.value(value: app.progressService),
      Provider.value(value: app.audioService),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('en'),
      theme: SpaceTheme.lightTheme,
      home: game,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('layout audit across sizes', (tester) async {
    final mission = MissionProvider();
    try {
      await mission.loadSaved();
    } catch (_) {}

    const dpr = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final cfg in _configs.entries) {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = cfg.value * dpr;

      for (final game in gameBuilders.entries) {
        final overflow = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (details) {
          final s = details.exceptionAsString();
          if (s.contains('overflowed')) {
            overflow.add(s.split('\n').first.trim());
          } else {
            prev?.call(details);
          }
        };

        var status = 'ok';
        try {
          await tester.pumpWidget(_wrap(game.value(2, 1), mission));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        } catch (e) {
          status = 'threw:${e.toString().split('\n').first.trim()}';
        } finally {
          FlutterError.onError = prev;
          // Dispose the game so its timers/animations are cancelled before the
          // next one (keeps failures isolated to the game under test).
          try {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));
          } catch (_) {}
        }

        if (overflow.isNotEmpty) {
          // Extract "overflowed by N pixels on the <side>" for each, so we can
          // rank real breakage (large N) over cosmetic sub-pixel noise.
          final detail = overflow
              .map((m) {
                final match =
                    RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)')
                        .firstMatch(m);
                return match == null
                    ? m
                    : '${match.group(1)}px-${match.group(2)}';
              })
              .toSet()
              .join(',');
          status = 'OVERFLOW[$detail]';
        }
        debugPrint('AUDIT\t${cfg.key}\t${game.key}\t$status');
      }
    }
    debugPrint('AUDIT_DONE');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
