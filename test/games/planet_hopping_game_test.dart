// Unit tests for planet_hopping_game.dart.
//
// The screen itself (PlanetHoppingGame) is a StatefulWidget that hard-couples to
// GameProvider/SriService, three infinite AnimationControllers, periodic Timers,
// HapticFeedback and MediaQuery-driven planet generation. Its game-flow methods
// (_initializeGame, _updateGame, _landOnPlanet, _winGame, ...) are private
// instance methods with no dependency-injection seam, so they cannot be
// exercised directly. However the file also defines several pure, deterministic
// data-model classes (and one Offset extension) that encode the real game
// logic. We test those directly:
//   * OffsetExtensions.normalize() — vector normalization used for thrust/bounce.
//   * SpaceHopper                  — landOn()/takeOff() physics state transitions.
//   * Planet                       — answer / problemExpression getters delegate.
//   * ParticleEffect               — update() lifecycle + motion/drag.
//   * GravityWave                  — update() lifecycle, radius growth, opacity.
//   * Star                         — field storage.
//
// None of these touch plugins or assets; they need only an initialized binding
// for Offset/Color value types.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/screens/planet_hopping_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OffsetExtensions.normalize', () {
    test('returns a unit vector preserving direction', () {
      const v = Offset(3, 4); // length 5
      final n = v.normalize();
      expect(n.distance, closeTo(1.0, 1e-9));
      expect(n.dx, closeTo(0.6, 1e-9));
      expect(n.dy, closeTo(0.8, 1e-9));
    });

    test('returns zero for a zero-length vector (no division by zero)', () {
      expect(Offset.zero.normalize(), Offset.zero);
    });

    test('scaling a vector does not change its normalized direction', () {
      final a = const Offset(2, -1).normalize();
      final b = const Offset(20, -10).normalize();
      expect(a.dx, closeTo(b.dx, 1e-9));
      expect(a.dy, closeTo(b.dy, 1e-9));
    });
  });

  group('SpaceHopper physics', () {
    test('takeOff launches at fixed speed toward the tap and unlands', () {
      final hopper = SpaceHopper()
        ..position = const Offset(100, 100)
        ..isLanded = true
        ..landedOnPlanetId = 2;

      hopper.takeOff(const Offset(200, 100)); // straight right

      expect(hopper.isLanded, isFalse);
      expect(hopper.landedOnPlanetId, isNull);
      // Launch speed is a constant 450; direction is +x.
      expect(hopper.velocity.distance, closeTo(450.0, 1e-6));
      expect(hopper.velocity.dx, closeTo(450.0, 1e-6));
      expect(hopper.velocity.dy, closeTo(0.0, 1e-6));
    });

    test('landOn snaps onto the planet, zeroes velocity and records its id', () {
      final problem = MathProblem.addition(2, 3);
      final planet = Planet(
        id: 5,
        position: const Offset(300, 400),
        radius: 40,
        mass: 4,
        problem: problem,
        color: Colors.red,
        visited: false,
      );

      final hopper = SpaceHopper()
        ..position = const Offset(10, 10)
        ..velocity = const Offset(120, -90)
        ..isLanded = false;

      hopper.landOn(planet);

      expect(hopper.isLanded, isTrue);
      expect(hopper.landedOnPlanetId, 5);
      expect(hopper.velocity, Offset.zero);
      expect(hopper.position, const Offset(300, 400));
    });
  });

  group('Planet model', () {
    Planet makePlanet(MathProblem problem) => Planet(
          id: 1,
          position: const Offset(50, 60),
          radius: 35,
          mass: 4,
          problem: problem,
          color: Colors.blue,
          visited: false,
        );

    test('answer and problemExpression delegate to the MathProblem', () {
      final problem = MathProblem.addition(3, 4);
      final planet = makePlanet(problem);
      expect(planet.answer, 7);
      expect(planet.problemExpression, problem.expression);
      expect(planet.problemExpression, '3 + 4');
    });

    test('answer matches the underlying problem across operations', () {
      expect(makePlanet(MathProblem.multiplication(6, 7)).answer, 42);
      expect(makePlanet(MathProblem.subtraction(10, 4)).answer, 6);
      expect(makePlanet(MathProblem.division(20, 5)).answer, 4);
    });
  });

  group('ParticleEffect lifecycle', () {
    test('starts at maxLife and signals completion only when life runs out', () {
      final p = ParticleEffect(
        position: Offset.zero,
        velocity: const Offset(100, 0),
        color: Colors.white,
        life: 1.0,
        size: 3,
      );
      expect(p.maxLife, 1.0);

      // Not yet expired after a partial tick.
      expect(p.update(0.4), isFalse);
      expect(p.update(0.4), isFalse);
      // Crossing the full lifetime expires it.
      expect(p.update(0.4), isTrue);
    });

    test('moves by velocity*dt and applies drag to its velocity', () {
      final p = ParticleEffect(
        position: Offset.zero,
        velocity: const Offset(100, 0),
        color: Colors.white,
        life: 5.0,
        size: 3,
      );
      p.update(0.1);
      // Position advanced by initial velocity * dt.
      expect(p.position.dx, closeTo(10.0, 1e-6));
      // Velocity decayed by the 0.95 drag factor.
      expect(p.velocity.dx, closeTo(95.0, 1e-6));
    });
  });

  group('GravityWave lifecycle', () {
    test('grows toward maxRadius and reports its opacity over its lifetime', () {
      final wave = GravityWave(
        center: const Offset(100, 100),
        maxRadius: 100,
        color: Colors.cyan,
      );
      expect(wave.currentRadius, 0);
      expect(wave.opacity, closeTo(1.0, 1e-9));

      // maxLife is 1.0s; growth rate is maxRadius/maxLife == 100 px/s.
      final doneAfterHalf = wave.update(0.5);
      expect(doneAfterHalf, isFalse);
      expect(wave.currentRadius, closeTo(50.0, 1e-6));
      expect(wave.opacity, closeTo(0.5, 1e-6));
    });

    test('completes once it has expanded to maxRadius', () {
      final wave = GravityWave(
        center: Offset.zero,
        maxRadius: 80,
        color: Colors.purple,
      );
      // A full-second tick both depletes life and reaches maxRadius.
      expect(wave.update(1.0), isTrue);
      expect(wave.opacity, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Star model', () {
    test('stores its position, size and brightness verbatim', () {
      final star = Star(
        position: const Offset(12, 34),
        size: 2.5,
        brightness: 0.7,
      );
      expect(star.position, const Offset(12, 34));
      expect(star.size, 2.5);
      expect(star.brightness, 0.7);
    });
  });
}
