// Unit tests for asteroid_math_game.dart.
//
// The screen itself (AsteroidMathGame) is a StatefulWidget that hard-couples to
// GameProvider/SriService, infinite animation controllers, periodic timers,
// HapticFeedback and CustomPaint. Its game-flow methods (_onAsteroidTapped,
// _updateGame, _endGame, ...) are private instance methods with no DI seam, so
// they cannot be exercised directly. However the file also defines several
// pure, deterministic data-model classes that encode real game logic. We test
// those directly:
//   * Asteroid              — mathProblem / answer getters delegate to MathProblem.
//   * ParticleExplosion     — update()/isComplete progress lifecycle (the random
//                             only affects particle visuals, never the timeline).
//   * LaserBeam             — update()/isComplete progress lifecycle.
//   * FloatingScore         — update()/isComplete progress lifecycle + fields.
//
// These have no randomness in their progress logic, no plugin/asset coupling,
// and need only an initialized binding for Offset/Color value types.

import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/screens/asteroid_math_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Asteroid model', () {
    Asteroid makeAsteroid(MathProblem problem) => Asteroid(
          id: 7,
          problem: problem,
          position: const Offset(100, 200),
          velocity: const Offset(1, 1),
          size: 60,
          rotationSpeed: 0.1,
          rotation: 0,
          type: AsteroidType.rocky,
          hue: 120,
        );

    test('mathProblem and answer getters delegate to the MathProblem', () {
      final problem = MathProblem.addition(3, 4);
      final asteroid = makeAsteroid(problem);

      expect(asteroid.answer, 7);
      expect(asteroid.mathProblem, problem.expression);
      expect(asteroid.mathProblem, '3 + 4');
      expect(asteroid.id, 7);
    });

    test('answer matches the underlying problem across operations', () {
      expect(makeAsteroid(MathProblem.multiplication(6, 7)).answer, 42);
      expect(makeAsteroid(MathProblem.subtraction(10, 4)).answer, 6);
      expect(makeAsteroid(MathProblem.division(20, 5)).answer, 4);
    });
  });

  group('ParticleExplosion lifecycle', () {
    test('starts incomplete and completes once cumulative dt reaches duration',
        () {
      final explosion = ParticleExplosion(
        position: const Offset(10, 10),
        isCorrect: true,
      );

      // Duration is explosionDurationMs / 1000 == 1.0s.
      expect(explosion.isComplete, isFalse);

      // 0.5s of 1.0s -> still running.
      explosion.update(0.5);
      expect(explosion.isComplete, isFalse);

      // Reaches 1.0s -> complete.
      explosion.update(0.5);
      expect(explosion.isComplete, isTrue);
    });

    test('correct explosions spawn more particles than wrong ones', () {
      final correct = ParticleExplosion(
        position: Offset.zero,
        isCorrect: true,
      );
      final wrong = ParticleExplosion(
        position: Offset.zero,
        isCorrect: false,
      );

      expect(correct.particles, isNotEmpty);
      expect(wrong.particles, isNotEmpty);
      expect(correct.particles.length, greaterThan(wrong.particles.length));
    });

    test('drawing before completion does not throw', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final explosion = ParticleExplosion(
        position: const Offset(50, 50),
        isCorrect: false,
      );
      explosion.update(0.25);

      expect(() => explosion.draw(canvas), returnsNormally);
    });
  });

  group('LaserBeam lifecycle', () {
    test('progress accumulates over its (laserBeamDuration) lifetime', () {
      final laser = LaserBeam(
        startPosition: const Offset(0, 0),
        endPosition: const Offset(100, 100),
      );
      expect(laser.isComplete, isFalse);

      // Duration is 0.4s; a single 0.2s tick is not enough.
      laser.update(0.2);
      expect(laser.isComplete, isFalse);

      // Crossing the full duration marks it complete.
      laser.update(0.2);
      expect(laser.isComplete, isTrue);
    });

    test('endpoints are preserved and drawing does not throw', () {
      const start = Offset(5, 6);
      const end = Offset(80, 90);
      final laser = LaserBeam(startPosition: start, endPosition: end);

      expect(laser.startPosition, start);
      expect(laser.endPosition, end);

      final canvas = Canvas(PictureRecorder());
      laser.update(0.1);
      expect(() => laser.draw(canvas), returnsNormally);
    });
  });

  group('FloatingScore lifecycle', () {
    test('retains text/color and completes after its 2.0s duration', () {
      final score = FloatingScore(
        position: const Offset(20, 30),
        text: '+150',
        color: Colors.amber,
      );

      expect(score.text, '+150');
      expect(score.color, Colors.amber);
      expect(score.isComplete, isFalse);

      // floatingScoreDuration is 2.0s; one 1.0s tick is not enough.
      score.update(1.0);
      expect(score.isComplete, isFalse);

      score.update(1.0);
      expect(score.isComplete, isTrue);
    });

    test('drawing mid-animation does not throw', () {
      final score = FloatingScore(
        position: const Offset(40, 40),
        text: '+10',
        color: Colors.white,
      );
      score.update(0.5);

      final canvas = Canvas(PictureRecorder());
      expect(() => score.draw(canvas), returnsNormally);
    });
  });
}
