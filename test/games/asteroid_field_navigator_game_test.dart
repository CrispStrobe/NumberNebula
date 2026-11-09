// Logic tests for the public model/value classes exported by
// asteroid_field_navigator_game.dart.
//
// NOTE on testability: the core Minesweeper logic (field generation, the
// flood-fill reveal BFS, win-condition check, scoring) lives in PRIVATE
// instance methods of the State subclass and uses unseeded `math.Random()`
// with no injection seam. Per the task rules we do NOT add a DI seam, so
// those are not directly unit-testable. What IS public and pure here are
// three value/model classes: AsteroidCell (whose ==/hashCode is load-bearing
// for the flood-fill `visited`/`cellsToReveal` Sets), ExplosionParticle
// (deterministic physics in update(), plus factory invariants we can assert
// across many seeded-by-construction draws), and AsteroidFieldPainter
// (shouldRepaint). We test those invariants.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/asteroid_field_navigator_game.dart';

void main() {
  group('AsteroidCell equality / hashCode (used by flood-fill Sets)', () {
    test('two cells with same row/col are equal and share a hashCode', () {
      final a = AsteroidCell(row: 3, col: 4);
      final b = AsteroidCell(row: 3, col: 4, isMine: true, adjacentMines: 5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cells with different coordinates are not equal', () {
      expect(AsteroidCell(row: 1, col: 2), isNot(equals(AsteroidCell(row: 2, col: 1))));
      expect(AsteroidCell(row: 0, col: 0), isNot(equals(AsteroidCell(row: 0, col: 1))));
    });

    test('a Set deduplicates by coordinate regardless of mutable state', () {
      // The reveal algorithm relies on this: adding the "same" cell twice
      // (e.g. a freshly built copy) must not grow the visited set.
      final visited = <AsteroidCell>{};
      expect(visited.add(AsteroidCell(row: 2, col: 2)), isTrue);
      expect(visited.add(AsteroidCell(row: 2, col: 2, isRevealed: true)), isFalse);
      expect(visited.length, 1);
    });

    test('default flags are all false / counts zero', () {
      final c = AsteroidCell(row: 0, col: 0);
      expect(c.isMine, isFalse);
      expect(c.isRevealed, isFalse);
      expect(c.isFlagged, isFalse);
      expect(c.isExploded, isFalse);
      expect(c.adjacentMines, 0);
    });
  });

  group('ExplosionParticle.update physics', () {
    ExplosionParticle makeParticle({double life = 1.0}) => ExplosionParticle(
          position: Offset.zero,
          velocity: const Offset(100, 0),
          color: Colors.red,
          size: 5,
          opacity: 1.0,
          life: life,
        );

    test('position advances by velocity * dt and velocity decays', () {
      final p = makeParticle();
      final dead = p.update(0.5);
      // x = 0 + 100 * 0.5 = 50.
      expect(p.position.dx, closeTo(50.0, 1e-9));
      expect(p.position.dy, closeTo(0.0, 1e-9));
      // velocity damped by 0.96 factor.
      expect(p.velocity.dx, closeTo(96.0, 1e-9));
      expect(dead, isFalse);
    });

    test('opacity tracks remaining life fraction and clamps to [0,1]', () {
      final p = makeParticle(life: 1.0);
      p.update(0.25); // life -> 0.75
      expect(p.opacity, closeTo(0.75, 1e-9));
      expect(p.opacity, inInclusiveRange(0.0, 1.0));
    });

    test('update returns true (dead) once life is exhausted', () {
      final p = makeParticle(life: 0.4);
      expect(p.update(0.3), isFalse); // life -> 0.1
      expect(p.update(0.3), isTrue); // life -> -0.2
      expect(p.opacity, 0.0); // clamped, never negative
    });

    test('explosion factory produces in-range values across many draws', () {
      for (var i = 0; i < 200; i++) {
        final p = ExplosionParticle.explosion(const Offset(10, 20));
        expect(p.position, const Offset(10, 20));
        expect(p.size, inInclusiveRange(4.0, 10.0));
        expect(p.life, inInclusiveRange(0.8, 1.3));
        expect(p.maxLife, equals(p.life));
        expect(p.opacity, 1.0);
        expect([Colors.red, Colors.orange, Colors.yellow], contains(p.color));
        // velocity magnitude in [80, 230].
        expect(p.velocity.distance, inInclusiveRange(79.0, 231.0));
      }
    });

    test('celebration factory produces in-range values across many draws', () {
      for (var i = 0; i < 200; i++) {
        final p = ExplosionParticle.celebration(const Offset(0, 0));
        expect(p.size, inInclusiveRange(3.0, 8.0));
        expect(p.life, inInclusiveRange(1.0, 1.6));
        expect(p.maxLife, equals(p.life));
        expect(
          [Colors.cyan, Colors.green, Colors.yellow, Colors.pink],
          contains(p.color),
        );
        expect(p.velocity.distance, inInclusiveRange(99.0, 301.0));
      }
    });
  });

  group('AsteroidFieldPainter.shouldRepaint', () {
    AsteroidFieldPainter make({
      double pulse = 0.8,
      double scan = 0.5,
      bool won = false,
      bool lost = false,
    }) =>
        AsteroidFieldPainter(
          pulseIntensity: pulse,
          scanProgress: scan,
          gameWon: won,
          gameLost: lost,
        );

    test('identical config does not repaint', () {
      expect(make().shouldRepaint(make()), isFalse);
    });

    test('any changed field triggers repaint', () {
      final base = make();
      expect(base.shouldRepaint(make(pulse: 0.9)), isTrue);
      expect(base.shouldRepaint(make(scan: 0.6)), isTrue);
      expect(base.shouldRepaint(make(won: true)), isTrue);
      expect(base.shouldRepaint(make(lost: true)), isTrue);
    });
  });
}
