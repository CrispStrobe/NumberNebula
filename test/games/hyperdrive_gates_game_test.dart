// Logic tests for the public value/model classes exported by
// hyperdrive_gates_game.dart.
//
// NOTE on testability: the core game loop (gate spawning, collision handling,
// scoring, win/lose) lives in PRIVATE instance methods of the State subclass,
// reads providers (SriService, GameProvider) via context, drives multiple
// AnimationControllers, uses unseeded `math.Random()`, and depends on other
// game-object classes (Spaceship, Gate, etc.) declared in the
// hyperdrive_gates_world widget. There is no injection seam, and per the task
// rules we do NOT add one. What IS public and pure here are GravityField
// (deterministic inverse-square force physics in calculateForce) and PowerUp
// (its static color mapping, icon mapping, and deterministic update()/
// collisionRect physics). We unit-test those invariants directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/hyperdrive_gates_game.dart';

void main() {
  group('GravityField.calculateForce', () {
    GravityField makeField({
      Offset center = const Offset(100, 100),
      double strength = 150.0,
      double maxDistance = 120.0,
    }) =>
        GravityField(center: center, strength: strength, maxDistance: maxDistance);

    test('returns zero force beyond maxDistance', () {
      final field = makeField();
      // Object 200px away on the x-axis (> maxDistance 120).
      final force = field.calculateForce(const Offset(300, 100), 1.0);
      expect(force, Offset.zero);
    });

    test('returns zero force inside the deadzone (distance < 10)', () {
      final field = makeField();
      final force = field.calculateForce(const Offset(105, 100), 1.0);
      expect(force, Offset.zero);
    });

    test('force points from the object toward the field center', () {
      final field = makeField(center: const Offset(100, 100));
      // Object directly to the right of center; force should pull it left (-x).
      final force = field.calculateForce(const Offset(150, 100), 1.0);
      expect(force.dx, lessThan(0));
      expect(force.dy, closeTo(0.0, 1e-9));
    });

    test('force magnitude follows the inverse-square law', () {
      final field = makeField(center: Offset.zero, strength: 150.0);
      // distance 50: f = 150 / 50^2 = 0.06
      final near = field.calculateForce(const Offset(50, 0), 1.0);
      expect(near.distance, closeTo(0.06, 1e-9));
      // distance 100: f = 150 / 100^2 = 0.015 (= 1/4 of the distance-50 force).
      final far = field.calculateForce(const Offset(100, 0), 1.0);
      expect(far.distance, closeTo(0.015, 1e-9));
      expect(near.distance, closeTo(far.distance * 4, 1e-9));
    });

    test('force scales linearly with object mass', () {
      final field = makeField(center: Offset.zero);
      final m1 = field.calculateForce(const Offset(60, 0), 1.0);
      final m2 = field.calculateForce(const Offset(60, 0), 2.0);
      expect(m2.distance, closeTo(m1.distance * 2, 1e-9));
    });
  });

  group('PowerUp static mappings', () {
    test('every PowerUpType maps to a distinct color', () {
      final colors = PowerUpType.values
          .map((t) => PowerUp(position: Offset.zero, type: t).color)
          .toSet();
      expect(colors.length, PowerUpType.values.length);
    });

    test('every PowerUpType exposes a non-null icon', () {
      for (final type in PowerUpType.values) {
        final powerUp = PowerUp(position: Offset.zero, type: type);
        expect(powerUp.icon, isA<IconData>());
      }
    });

    test('color matches the documented mapping', () {
      expect(PowerUp(position: Offset.zero, type: PowerUpType.shield).color,
          Colors.blue);
      expect(PowerUp(position: Offset.zero, type: PowerUpType.slowTime).color,
          Colors.purple);
      expect(PowerUp(position: Offset.zero, type: PowerUpType.extraLife).color,
          Colors.red);
      expect(PowerUp(position: Offset.zero, type: PowerUpType.magneticField).color,
          Colors.orange);
      expect(PowerUp(position: Offset.zero, type: PowerUpType.speedBoost).color,
          Colors.green);
    });
  });

  group('PowerUp.update physics', () {
    test('moves left by gameSpeed * dt and advances rotation/pulse', () {
      final p = PowerUp(position: const Offset(500, 200), type: PowerUpType.shield);
      p.update(0.5, 160.0); // dx -= 160 * 0.5 = 80
      expect(p.position.dx, closeTo(420.0, 1e-9));
      expect(p.position.dy, closeTo(200.0, 1e-9));
      expect(p.rotation, closeTo(0.5 * 2, 1e-9));
      expect(p.pulsePhase, closeTo(0.5 * 3, 1e-9));
    });

    test('collisionRect is a 40x40 box centered on the current position', () {
      final p = PowerUp(position: const Offset(300, 150), type: PowerUpType.slowTime);
      final rect = p.collisionRect;
      expect(rect.center, const Offset(300, 150));
      expect(rect.width, 40);
      expect(rect.height, 40);
    });
  });
}
