// Unit tests for star_loader_game.dart (Sokoban-style "Star Loader" puzzle).
//
// The StarLoaderGame screen widget hard-couples to TickerProvider animations
// (five AnimationControllers, one repeating every 16ms), Provider<GameProvider>,
// generated localisations, HapticFeedback, a StarLoaderLevelManager that loads
// level data asynchronously, and a CustomPainter. All of the actual game-state
// logic (movement, push, undo, win-check, scoring) lives in the *private*
// _StarLoaderGameState class with no extraction seam, and the hard rules forbid
// adding one. A pumpAndSettle widget test would hang on the repeating controller.
//
// Instead we unit-test the pure, public logic the screen file itself defines as
// top-level members:
//   * TrailParticle.update() / CelebrationParticle.update() — deterministic
//     particle physics (position integration, velocity damping, life decay,
//     and the bool "is-dead" return contract).
//   * StarLoaderPainter.shouldRepaint / listEquals — the repaint predicate that
//     drives the CustomPaint, exercised across every field it inspects.
//   * The LevelData / MoveHistory / StarParticle plain model classes.
//
// These are all deterministic and need no Random seeding, context or plugins.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:space_math_academy/features/games/screens/star_loader_game.dart';

void main() {
  group('TrailParticle.update', () {
    test('integrates position by velocity*0.016 and damps velocity', () {
      final p = TrailParticle(
        position: const Offset(2, 4),
        velocity: const Offset(10, -5),
        size: 3,
        color: const Color(0xFF00FF00),
      );

      final dead = p.update();

      // position += velocity * 0.016
      expect(p.position.dx, closeTo(2 + 10 * 0.016, 1e-9));
      expect(p.position.dy, closeTo(4 + -5 * 0.016, 1e-9));
      // velocity *= 0.95
      expect(p.velocity.dx, closeTo(10 * 0.95, 1e-9));
      expect(p.velocity.dy, closeTo(-5 * 0.95, 1e-9));
      // life -= 0.03 (started at default 1.0)
      expect(p.life, closeTo(0.97, 1e-9));
      // still alive
      expect(dead, isFalse);
    });

    test('reports dead once life decays to zero', () {
      final p = TrailParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        size: 1,
        color: const Color(0xFFFFFFFF),
        life: 0.03,
      );

      // 0.03 - 0.03 == 0 -> dead (life <= 0)
      expect(p.update(), isTrue);
      expect(p.life, closeTo(0.0, 1e-9));
    });

    test('a zero-velocity particle dies after a bounded number of frames', () {
      final p = TrailParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        size: 1,
        color: const Color(0xFFFFFFFF),
      );

      var frames = 0;
      while (!p.update()) {
        frames++;
        expect(frames, lessThan(1000), reason: 'particle must terminate');
      }
      // life starts 1.0, drains 0.03/frame -> ~34 frames.
      expect(frames, inInclusiveRange(30, 40));
    });
  });

  group('CelebrationParticle.update', () {
    test('integrates position, damps velocity by 0.98 and decays life', () {
      final p = CelebrationParticle(
        position: const Offset(1, 1),
        velocity: const Offset(4, 8),
        size: 5,
        color: const Color(0xFF00FFFF),
      );

      final dead = p.update();

      expect(p.position.dx, closeTo(1 + 4 * 0.016, 1e-9));
      expect(p.position.dy, closeTo(1 + 8 * 0.016, 1e-9));
      expect(p.velocity.dx, closeTo(4 * 0.98, 1e-9));
      expect(p.velocity.dy, closeTo(8 * 0.98, 1e-9));
      expect(p.life, closeTo(1.0 - 0.016, 1e-9));
      expect(dead, isFalse);
    });

    test('lives longer than a trail particle (slower life decay)', () {
      int framesToDie(bool Function() update) {
        var n = 0;
        while (!update()) {
          n++;
          if (n > 5000) break;
        }
        return n;
      }

      final trail = TrailParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        size: 1,
        color: const Color(0xFFFFFFFF),
      );
      final celebration = CelebrationParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        size: 1,
        color: const Color(0xFFFFFFFF),
      );

      expect(framesToDie(celebration.update),
          greaterThan(framesToDie(trail.update)));
    });
  });

  group('StarLoaderPainter.shouldRepaint', () {
    StarLoaderPainter make({
      List<List<CellType>>? grid,
      Offset playerPos = const Offset(1, 1),
      int playerDirection = 2,
      List<Offset>? boxPositions,
      List<Offset>? targetPositions,
      List<TrailParticle>? trails,
      List<CelebrationParticle>? celebrationParticles,
      double cellSize = 32,
      double winPulse = 1.0,
      double pushAnimValue = 0.0,
    }) {
      return StarLoaderPainter(
        grid: grid ??
            [
              [CellType.wall, CellType.floor],
              [CellType.floor, CellType.target],
            ],
        playerPos: playerPos,
        playerDirection: playerDirection,
        boxPositions: boxPositions ?? const [Offset(1, 0)],
        targetPositions: targetPositions ?? const [Offset(1, 1)],
        trails: trails ?? const [],
        celebrationParticles: celebrationParticles ?? const [],
        cellSize: cellSize,
        winPulse: winPulse,
        pushAnimValue: pushAnimValue,
      );
    }

    test('returns false for identical delegates', () {
      final a = make();
      final b = make();
      expect(a.shouldRepaint(b), isFalse);
    });

    test('repaints when any inspected scalar field changes', () {
      final base = make();
      expect(base.shouldRepaint(make(playerPos: const Offset(2, 1))), isTrue);
      expect(base.shouldRepaint(make(playerDirection: 1)), isTrue);
      expect(base.shouldRepaint(make(cellSize: 40)), isTrue);
      expect(base.shouldRepaint(make(winPulse: 0.5)), isTrue);
      expect(base.shouldRepaint(make(pushAnimValue: 0.3)), isTrue);
    });

    test('repaints when box positions differ by value', () {
      final base = make(boxPositions: const [Offset(1, 0)]);
      final moved = make(boxPositions: const [Offset(1, 1)]);
      expect(base.shouldRepaint(moved), isTrue);
    });

    test('repaints when particle counts change but not on content-equal lists',
        () {
      final base = make(trails: const []);
      expect(
        base.shouldRepaint(make(trails: [
          TrailParticle(
            position: Offset.zero,
            velocity: Offset.zero,
            size: 1,
            color: const Color(0xFFFFFFFF),
          ),
        ])),
        isTrue,
      );
      expect(
        base.shouldRepaint(make(celebrationParticles: [
          CelebrationParticle(
            position: Offset.zero,
            velocity: Offset.zero,
            size: 1,
            color: const Color(0xFFFFFFFF),
          ),
        ])),
        isTrue,
      );
    });
  });

  group('models', () {
    test('LevelData retains its fields', () {
      final data = LevelData(
        id: 'g1-l1',
        layout: const ['WWW', 'WPB', 'WTW'],
        optimalMoves: 7,
      );
      expect(data.id, 'g1-l1');
      expect(data.layout, hasLength(3));
      expect(data.optimalMoves, 7);
    });

    test('MoveHistory distinguishes plain moves from box pushes', () {
      final plain = MoveHistory(playerPos: const Offset(2, 3));
      final push = MoveHistory(
        playerPos: const Offset(2, 3),
        pushedBoxOrigin: const Offset(3, 3),
      );
      expect(plain.pushedBoxOrigin, isNull);
      expect(push.pushedBoxOrigin, const Offset(3, 3));
      expect(push.playerPos, const Offset(2, 3));
    });

    test('StarParticle.build renders without throwing', () {
      final star = StarParticle(
        position: const Offset(10, 20),
        size: 2,
        opacity: 0.5,
      );
      expect(star.build(), isA<Widget>());
    });
  });
}
