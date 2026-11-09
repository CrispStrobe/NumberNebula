import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';
import 'package:space_math_academy/core/utils/app_logger.dart';
import 'package:space_math_academy/shared/utils/arithmancer.dart';

/// Verify that former unconditional prints are now gated behind
/// kDebugMode+verbose and do not pollute stdout via print().

void main() {
  group('StarloaderLevelGenerator logging', () {
    test('verbose=false produces no debugPrint output', () {
      final messages = <String>[];
      final orig = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) messages.add(msg);
      };
      addTearDown(() => debugPrint = orig);

      // Generator with verbose false should not log even though it has internal _log calls.
      // _log is only reachable via generateLevel path; but even calling it with verbose false
      // should be silent. We test via AppLogger.verbose directly as proxy.
      AppLogger.verbose('test-silent', enabled: false, tag: 'Gen');
      expect(messages, isEmpty);

      // verbose true does emit (proves gate is wired)
      AppLogger.verbose('test-loud', enabled: true, tag: 'Gen');
      expect(messages, hasLength(1));
    });

    test('verbose generator does not use print when disabled, uses print when enabled (pure-dart CLI)', () async {
      // verbose false must not print
      final silentPrints = <String>[];
      await runZonedGuarded(() async {
        final gen = LevelGenerator(verbose: false);
        try {
          gen.generateLevel(dimX: 5, dimY: 5, numBoxes: 1, maxTries: 1);
        } catch (_) {}
      }, (e, s) {}, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          silentPrints.add(line);
        },
      ));
      expect(silentPrints, isEmpty, reason: 'verbose false must not print');

      // verbose true is allowed to print (pure-dart CLI harness) - ensure it does not throw and is captured via print
      final loudPrints = <String>[];
      await runZonedGuarded(() async {
        final gen = LevelGenerator(verbose: true);
        try {
          gen.generateLevel(dimX: 5, dimY: 5, numBoxes: 1, maxTries: 1);
        } catch (_) {}
      }, (e, s) {}, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          loudPrints.add(line);
        },
      ));
      // When verbose, generator is expected to log via print (CLI mode). We just verify it does not crash.
      expect(loudPrints, isNotEmpty, reason: 'verbose true should log via print in pure-dart mode');
    });
  });

  group('Arithmancer takeDamage logging gate', () {
    // Helper to make a minimal game and enemy.
    ArithmancerGame makeGame({required bool verbose}) =>
        ArithmancerGame(PrimeHunterAI(), Random(1), verbose: verbose);

    MathResult makeResult(double v) => MathResult(v, const [], v.toString(), const []);

    test('takeDamage result is identical regardless of verbose flag', () {
      for (final verbose in [true, false]) {
        final game = makeGame(verbose: verbose);
        final enemyA = MathematicalEnemy(
            name: 'Goblin', maxHealth: 100, behavior: [
          {'attack': 5}
        ]);
        final enemyB = MathematicalEnemy(
            name: 'Goblin', maxHealth: 100, behavior: [
          {'attack': 5}
        ]);
        final result = makeResult(10);

        final dmgA = enemyA.takeDamage(result, game);
        // Recreate with opposite verbose to ensure no logic branch depends on it
        final game2 = makeGame(verbose: !verbose);
        final dmgB = enemyB.takeDamage(result, game2);

        expect(dmgA, dmgB, reason: 'verbose must not affect damage');
        expect(enemyA.health, enemyB.health);
      }
    });

    test('takeDamage with chained result sums correctly', () {
      final game = makeGame(verbose: false);
      final enemy = MathematicalEnemy(
          name: 'Boss', maxHealth: 200, behavior: [
        {'attack': 10}
      ]);
      final left = makeResult(7);
      final right = makeResult(8);
      final chained = MathResult.chained(left, right, const []);
      final dmg = enemy.takeDamage(chained, game);
      // No shields, so damage = 7 + 8
      expect(dmg, 15);
      expect(enemy.health, 185);
    });

    test('takeDamage does not log when verbose false, does log when verbose true (pure-dart verbose print)', () async {
      // verbose false must not print
      final silentPrints = <String>[];
      await runZonedGuarded(() async {
        final game = makeGame(verbose: false);
        final enemy = MathematicalEnemy(
            name: 'Goblin', maxHealth: 100, behavior: [
          {'attack': 5}
        ]);
        enemy.takeDamage(makeResult(12), game);
      }, (e, s) {}, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          silentPrints.add(line);
        },
      ));
      expect(silentPrints, isEmpty, reason: 'verbose false must not print');

      // verbose true is allowed to print (pure-dart CLI mode) - ensure it does not throw
      final loudPrints = <String>[];
      await runZonedGuarded(() async {
        final game = makeGame(verbose: true);
        final enemy = MathematicalEnemy(
            name: 'Goblin', maxHealth: 100, behavior: [
          {'attack': 5}
        ]);
        enemy.takeDamage(makeResult(12), game);
      }, (e, s) {}, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          loudPrints.add(line);
        },
      ));
      expect(loudPrints, isNotEmpty, reason: 'verbose true should log via print in pure-dart mode');
      expect(loudPrints.any((m) => m.contains('takeDamage')), isTrue);
    });
  });
}
