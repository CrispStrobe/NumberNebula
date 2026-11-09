// Logic tests for the public model/value/painter classes exported by
// path_finder_game.dart.
//
// NOTE on testability: the actual game flow (path generation, tap hit-testing,
// scoring, win/loss) lives in PRIVATE instance methods of the State subclass
// (_generateSpacePaths, _handleScreenTap, _handleCorrectPath, ...) and reads
// SriService / GameProvider from the BuildContext, plus drives several infinite
// AnimationControllers. There is no DI seam, and per the task rules we do not
// add one. What IS public and pure here are the value/model classes:
//   * SpacePath.getPointAt  -> deterministic quadratic-bezier evaluation,
//   * SpacePathTypeData      -> the damage / colors lookup tables,
//   * SpaceParticle.update   -> deterministic per-frame physics,
//   * BackgroundStar.create/update -> deterministic with a seeded Random,
//   * the CustomPainter shouldRepaint contracts.
// We test those invariants directly, seeding every math.Random.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/path_finder_game.dart';

void main() {
  group('SpacePath.getPointAt (quadratic bezier)', () {
    SpacePath makePath({
      Offset start = const Offset(0, 0),
      Offset control = const Offset(50, 100),
      Offset end = const Offset(100, 0),
    }) {
      return SpacePath(
        startPoint: start,
        endPoint: end,
        controlPoint: control,
        answer: 7,
        isCorrect: true,
        pathType: SpacePathType.clearSpace,
        width: kPathWidth,
      );
    }

    test('t=0 returns the start point, t=1 returns the end point', () {
      final p = makePath();
      expect(p.getPointAt(0).dx, closeTo(0, 1e-9));
      expect(p.getPointAt(0).dy, closeTo(0, 1e-9));
      expect(p.getPointAt(1).dx, closeTo(100, 1e-9));
      expect(p.getPointAt(1).dy, closeTo(0, 1e-9));
    });

    test('t=0.5 matches the closed-form midpoint of the curve', () {
      // Quadratic bezier at t=0.5 == 0.25*start + 0.5*control + 0.25*end.
      final p = makePath();
      final mid = p.getPointAt(0.5);
      expect(mid.dx, closeTo(0.25 * 0 + 0.5 * 50 + 0.25 * 100, 1e-9));
      expect(mid.dy, closeTo(0.25 * 0 + 0.5 * 100 + 0.25 * 0, 1e-9));
    });

    test('the curve stays inside the convex hull of its control points '
        'for many sampled t (used by tap hit-testing)', () {
      final p = makePath(
        start: const Offset(10, 20),
        control: const Offset(80, 200),
        end: const Offset(150, 30),
      );
      final minX = math.min(10.0, math.min(80.0, 150.0));
      final maxX = math.max(10.0, math.max(80.0, 150.0));
      final minY = math.min(20.0, math.min(200.0, 30.0));
      final maxY = math.max(20.0, math.max(200.0, 30.0));
      for (int i = 0; i <= 50; i++) {
        final pt = p.getPointAt(i / 50);
        expect(pt.dx, inInclusiveRange(minX - 1e-6, maxX + 1e-6));
        expect(pt.dy, inInclusiveRange(minY - 1e-6, maxY + 1e-6));
      }
    });

    test('a degenerate path (all points equal) evaluates to that point', () {
      const corner = Offset(42, 99);
      final p = makePath(start: corner, control: corner, end: corner);
      for (final t in [0.0, 0.3, 0.7, 1.0]) {
        final pt = p.getPointAt(t);
        expect(pt.dx, closeTo(corner.dx, 1e-9));
        expect(pt.dy, closeTo(corner.dy, 1e-9));
      }
    });
  });

  group('SpacePathTypeData lookup tables', () {
    test('damage is defined and positive for every path type', () {
      for (final type in SpacePathType.values) {
        expect(type.damage, greaterThan(0.0), reason: '$type');
      }
    });

    test('damage values match the documented tier ordering', () {
      // Hazardous paths cost more HP than the safe clearSpace route.
      expect(SpacePathType.asteroidBelt.damage, 1.0);
      expect(SpacePathType.quantumTunnel.damage, 1.0);
      expect(SpacePathType.ionStorm.damage, 0.75);
      expect(SpacePathType.wormhole.damage, 0.5);
      expect(SpacePathType.nebula.damage, 0.5);
      expect(SpacePathType.clearSpace.damage, 0.25);
      expect(SpacePathType.clearSpace.damage,
          lessThan(SpacePathType.asteroidBelt.damage));
    });

    test('colors returns exactly three colors per type (gradient needs 3 stops)',
        () {
      // SpacePathPainter feeds these into a 3-stop linear gradient [0,0.5,1].
      for (final type in SpacePathType.values) {
        expect(type.colors.length, 3, reason: '$type');
      }
    });
  });

  group('SpaceParticle.update (deterministic physics)', () {
    test('integrates position, decays life, and damps velocity', () {
      final particle = SpaceParticle(
        position: const Offset(0, 0),
        velocity: const Offset(100, 0),
        color: Colors.white,
        size: 3,
        opacity: 1.0,
        life: 1.0,
      );
      final dead = particle.update(0.1);
      expect(dead, isFalse);
      // position += velocity * dt
      expect(particle.position.dx, closeTo(10, 1e-9));
      // life -= dt
      expect(particle.life, closeTo(0.9, 1e-9));
      // opacity == life / maxLife
      expect(particle.opacity, closeTo(0.9, 1e-9));
      // velocity *= 0.97
      expect(particle.velocity.dx, closeTo(97, 1e-9));
    });

    test('returns true (expired) once life reaches zero', () {
      final particle = SpaceParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.white,
        size: 2,
        opacity: 1.0,
        life: 0.05,
      );
      expect(particle.update(0.05), isTrue);
      expect(particle.life, lessThanOrEqualTo(0.0));
    });

    test('factory particles have a positive finite life and clamped opacity '
        'across many draws', () {
      // Factories use unseeded Random internally, so we assert invariants
      // (ranges), not exact values, over many constructions.
      for (int i = 0; i < 200; i++) {
        final engine = SpaceParticle.engine(const Offset(50, 50), 0.3);
        final success = SpaceParticle.success(const Offset(50, 50));
        final damage = SpaceParticle.damage(const Offset(50, 50));
        for (final p in [engine, success, damage]) {
          expect(p.life, greaterThan(0.0));
          expect(p.life.isFinite, isTrue);
          expect(p.size, greaterThan(0.0));
          expect(p.update(0.0).runtimeType, bool);
          expect(p.opacity, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('BackgroundStar (seeded determinism + wrap-around)', () {
    test('create produces a star within bounds for a seeded Random', () {
      final rng = math.Random(42);
      const size = Size(400, 800);
      for (int i = 0; i < 100; i++) {
        final star = BackgroundStar.create(size, rng);
        expect(star.position.dx, inInclusiveRange(0.0, size.width));
        expect(star.position.dy, inInclusiveRange(0.0, size.height));
        expect(star.size, greaterThan(0.0));
        expect(star.brightness, inInclusiveRange(0.3, 1.0));
        expect(star.speed, greaterThan(0.0));
      }
    });

    test('the same seed yields identical stars (reproducible field)', () {
      const size = Size(400, 800);
      final a = BackgroundStar.create(size, math.Random(7));
      final b = BackgroundStar.create(size, math.Random(7));
      expect(a.position, b.position);
      expect(a.size, b.size);
      expect(a.speed, b.speed);
      expect(a.brightness, b.brightness);
    });

    test('dust stars are smaller and flagged as dust', () {
      const size = Size(400, 800);
      final dust = BackgroundStar.create(size, math.Random(1), isDust: true);
      expect(dust.isDust, isTrue);
      // dust size range is [0.5, 1.7); regular star min is 1.0 up to 3.5.
      expect(dust.size, lessThan(1.8));
    });

    test('update scrolls a star left and wraps it past the right edge', () {
      const size = Size(400, 800);
      final star = BackgroundStar(
        position: const Offset(5, 100),
        size: 2,
        speed: 50,
        brightness: 0.8,
      );
      // Big dt pushes dx below -10, triggering the wrap-around respawn.
      star.update(1.0, size, 100);
      expect(star.position.dx, greaterThan(size.width));
    });

    test('update moves a star left without wrapping when still on-screen', () {
      const size = Size(400, 800);
      final star = BackgroundStar(
        position: const Offset(300, 100),
        size: 2,
        speed: 50,
        brightness: 0.8,
      );
      final before = star.position.dx;
      star.update(0.1, size, 10);
      expect(star.position.dx, lessThan(before));
      expect(star.position.dy, 100); // y is unchanged when not wrapping
    });
  });

  group('CustomPainter shouldRepaint contracts', () {
    SpacePath path() => SpacePath(
          startPoint: Offset.zero,
          endPoint: const Offset(100, 0),
          controlPoint: const Offset(50, 50),
          answer: 3,
          isCorrect: true,
          pathType: SpacePathType.nebula,
          width: kPathWidth,
        );

    test('SpacePathPainter repaints only when progress changes', () {
      final a = SpacePathPainter(path: path(), progress: 0.1);
      final same = SpacePathPainter(path: path(), progress: 0.1);
      final diff = SpacePathPainter(path: path(), progress: 0.2);
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(diff), isTrue);
    });

    test('SpaceshipPainter repaints when boosting or damage changes', () {
      final base = SpaceshipPainter(boosting: false, damageLevel: 0.0);
      expect(base.shouldRepaint(SpaceshipPainter(boosting: false, damageLevel: 0.0)),
          isFalse);
      expect(base.shouldRepaint(SpaceshipPainter(boosting: true, damageLevel: 0.0)),
          isTrue);
      expect(base.shouldRepaint(SpaceshipPainter(boosting: false, damageLevel: 1.0)),
          isTrue);
    });
  });
}
