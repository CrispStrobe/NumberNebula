// Logic tests for the public model/value classes exported by
// signal_triangulation_game.dart.
//
// NOTE on testability: the core game logic (difficulty parameterisation,
// secret-sequence generation, and the Mastermind feedback computation
// `_calculateFeedback`) lives in PRIVATE instance methods of the State
// subclass; secret generation uses an unseeded `math.Random()` with no
// injection seam. Per the task rules we do NOT add a DI seam, so those are
// not directly unit-testable. What IS public and pure here are the value
// model classes:
//   * SignalGlyph  -- its ==/hashCode is load-bearing (used as Map keys in
//     the feedback histogram and for empty-slot detection); the static glyph
//     lists drive difficulty scaling.
//   * SignalParticle -- deterministic physics in update().
//   * SignalBackgroundPainter -- shouldRepaint contract.
// We test invariants on those.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/signal_triangulation_game.dart';

void main() {
  group('SignalGlyph equality / hashCode (used as histogram Map keys)', () {
    test('identical constants are equal and share a hashCode', () {
      expect(SignalGlyph.alpha, equals(SignalGlyph.alpha));
      expect(SignalGlyph.alpha.hashCode, equals(SignalGlyph.alpha.hashCode));
    });

    test('equality is by name only', () {
      const sameName = SignalGlyph(
        name: 'alpha',
        displayName: 'Different Display',
        icon: Icons.star,
        color: Colors.black,
      );
      // Different display/icon/color but same name -> equal (and same hash).
      expect(sameName, equals(SignalGlyph.alpha));
      expect(sameName.hashCode, equals(SignalGlyph.alpha.hashCode));
    });

    test('different glyphs are not equal', () {
      expect(SignalGlyph.alpha, isNot(equals(SignalGlyph.beta)));
      expect(SignalGlyph.empty, isNot(equals(SignalGlyph.alpha)));
    });

    test('histogram counting (mirrors _calculateFeedback) keys correctly', () {
      // The feedback code builds <SignalGlyph,int> counts; verify Map keying.
      final counts = <SignalGlyph, int>{};
      final seq = [
        SignalGlyph.alpha,
        SignalGlyph.alpha,
        SignalGlyph.beta,
      ];
      for (final g in seq) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
      expect(counts[SignalGlyph.alpha], 2);
      expect(counts[SignalGlyph.beta], 1);
      expect(counts.length, 2);
    });
  });

  group('SignalGlyph difficulty glyph lists', () {
    test('lists grow monotonically with difficulty and contain no empty', () {
      final basic = SignalGlyph.getBasicGlyphs();
      final intermediate = SignalGlyph.getIntermediateGlyphs();
      final advanced = SignalGlyph.getAdvancedGlyphs();
      final all = SignalGlyph.getAllGlyphs();

      expect(basic.length, 5);
      expect(intermediate.length, 6);
      expect(advanced.length, 7);
      expect(all.length, 8);

      // Each higher tier is a superset of the lower one.
      expect(basic.every(intermediate.contains), isTrue);
      expect(intermediate.every(advanced.contains), isTrue);
      expect(advanced.every(all.contains), isTrue);

      // The empty sentinel is never a selectable glyph.
      expect(all.contains(SignalGlyph.empty), isFalse);
    });

    test('every selectable glyph has an icon and a color', () {
      for (final g in SignalGlyph.getAllGlyphs()) {
        expect(g.icon, isNotNull, reason: '${g.name} missing icon');
        expect(g.color, isNotNull, reason: '${g.name} missing color');
      }
    });

    test('all selectable glyphs are distinct by name', () {
      final all = SignalGlyph.getAllGlyphs();
      expect(all.map((g) => g.name).toSet().length, all.length);
    });
  });

  group('SignalParticle.update physics', () {
    test('moves by velocity*dt, decays life, and reports death at end', () {
      final p = SignalParticle(
        position: const Offset(0, 0),
        velocity: const Offset(10, 0),
        color: Colors.green,
        size: 4,
        opacity: 1.0,
        life: 1.0,
      );

      final dead = p.update(0.5);
      expect(dead, isFalse);
      // position advanced by velocity*dt.
      expect(p.position.dx, closeTo(5.0, 1e-9));
      // velocity damped by 0.95.
      expect(p.velocity.dx, closeTo(9.5, 1e-9));
      // opacity == life/maxLife.
      expect(p.opacity, closeTo(0.5, 1e-9));

      // Drain the rest of the life.
      final dead2 = p.update(0.5);
      expect(dead2, isTrue);
      expect(p.life, lessThanOrEqualTo(0.0));
      expect(p.opacity, 0.0);
    });

    test('opacity stays clamped within [0,1]', () {
      final p = SignalParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.red,
        size: 2,
        opacity: 1.0,
        life: 1.0,
      );
      p.update(2.0); // overshoot life
      expect(p.opacity, inInclusiveRange(0.0, 1.0));
    });

    test('factory particles have positive size and life and correct colors', () {
      const origin = Offset(100, 100);
      final success = SignalParticle.success(origin);
      final warning = SignalParticle.warning(origin);
      final failure = SignalParticle.failure(origin);

      for (final p in [success, warning, failure]) {
        expect(p.size, greaterThan(0));
        expect(p.life, greaterThan(0));
        expect(p.opacity, 1.0);
        expect(p.position, origin);
      }
      expect(success.color, Colors.green);
      expect(warning.color, Colors.orange);
      expect(failure.color, Colors.red);
    });
  });

  group('SignalBackgroundPainter.shouldRepaint', () {
    test('repaints only when a tracked field changes', () {
      final base = SignalBackgroundPainter(
        pulseIntensity: 0.5,
        scanProgress: 0.25,
        gameWon: false,
      );
      final same = SignalBackgroundPainter(
        pulseIntensity: 0.5,
        scanProgress: 0.25,
        gameWon: false,
      );
      final changedPulse = SignalBackgroundPainter(
        pulseIntensity: 0.6,
        scanProgress: 0.25,
        gameWon: false,
      );
      final changedWon = SignalBackgroundPainter(
        pulseIntensity: 0.5,
        scanProgress: 0.25,
        gameWon: true,
      );

      expect(base.shouldRepaint(same), isFalse);
      expect(base.shouldRepaint(changedPulse), isTrue);
      expect(base.shouldRepaint(changedWon), isTrue);
    });
  });

  group('GuessResult holds feedback fields', () {
    test('stores guess and feedback counts verbatim', () {
      final result = GuessResult(
        guess: [SignalGlyph.alpha, SignalGlyph.beta],
        correctPosition: 1,
        correctGlyph: 1,
      );
      expect(result.guess.length, 2);
      expect(result.correctPosition, 1);
      expect(result.correctGlyph, 1);
    });
  });
}
