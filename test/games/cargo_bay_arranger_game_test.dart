// Unit tests for cargo_bay_arranger_game.dart (Cargo Bay Arranger, a Tetris-
// like number-stacking game).
//
// TESTABILITY NOTES:
//   The entire game loop (collision, bonus scanning, Fibonacci/doubling/
//   consecutive detection, row clearing, scoring) lives in the *private*
//   _CargoBayArrangerGameState class, behind AnimationControllers, a Ticker,
//   the GameProvider/HapticFeedback wiring and dialogs. None of that is
//   reachable from a unit test and there is no dependency-injection seam to
//   add (and the HARD RULES forbid adding one in lib/).
//
//   The genuinely PURE, public, top-level surfaces are the data models at the
//   bottom of the file:
//     - CargoPiece.random(min, max, gridCols)  (piece generation)
//     - CargoCube / Position / BonusMatch / CargoParticle
//     - CargoBayPainter.shouldRepaint / GridPainter.shouldRepaint
//   CargoPiece.random uses an UNSEEDED math.Random() internally with no
//   injection seam, so we cannot assert exact literal output. Instead we
//   assert the structural INVARIANTS every generated piece must satisfy across
//   many iterations. These are load-bearing: the cube values must stay inside
//   [min,max] (otherwise a target-sum can never be reached / the math is
//   wrong), the shape/cubes matrices must stay structurally aligned (a `true`
//   shape cell must have a non-null cube and vice versa), and the spawn x must
//   keep the piece inside the grid.

import 'package:flutter/material.dart' show Color, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/cargo_bay_arranger_game.dart';

void main() {
  group('CargoPiece.random invariants', () {
    // A spread of (min, max) ranges matching the game's progressive
    // difficulty bands, plus the fixed gridCols (8) used by the screen.
    const gridCols = 8;
    final ranges = <List<int>>[
      [1, 5],
      [1, 9],
      [2, 15],
      [3, 18],
      [5, 20],
      [7, 7], // degenerate single-value range
    ];

    test('cube values stay within [min, max] and shape aligns with cubes', () {
      for (final r in ranges) {
        final min = r[0];
        final max = r[1];
        for (var iter = 0; iter < 200; iter++) {
          final piece = CargoPiece.random(min, max, gridCols);

          // shape and cubes must be the same dimensions.
          expect(piece.cubes.length, piece.shape.length,
              reason: 'row count mismatch for range $r');
          for (var i = 0; i < piece.shape.length; i++) {
            expect(piece.cubes[i].length, piece.shape[i].length,
                reason: 'col count mismatch at row $i for range $r');

            for (var j = 0; j < piece.shape[i].length; j++) {
              if (piece.shape[i][j]) {
                // Filled cells must carry a cube with an in-range value.
                final cube = piece.cubes[i][j];
                expect(cube, isNotNull,
                    reason: 'filled shape cell had null cube ($r)');
                expect(cube!.value, inInclusiveRange(min, max),
                    reason: 'cube value ${cube.value} outside [$min,$max]');
              } else {
                // Empty cells must have no cube.
                expect(piece.cubes[i][j], isNull,
                    reason: 'empty shape cell had a non-null cube ($r)');
              }
            }
          }

          // At least one filled cell — pieces are never empty.
          final hasFilled =
              piece.shape.any((row) => row.any((cell) => cell));
          expect(hasFilled, isTrue, reason: 'generated an empty piece');
        }
      }
    });

    test('spawn position keeps the piece horizontally inside the grid', () {
      for (var iter = 0; iter < 200; iter++) {
        final piece = CargoPiece.random(1, 9, gridCols);
        final width = piece.shape[0].length;

        // Spawn x is centered: (gridCols ~/ 2) - (width ~/ 2).
        expect(piece.x, greaterThanOrEqualTo(0));
        expect(piece.x + width, lessThanOrEqualTo(gridCols),
            reason: 'piece (width $width) spawned out of horizontal bounds');

        // Pieces spawn above the visible grid.
        expect(piece.y, lessThan(0));
      }
    });

    test('degenerate range produces only that single value', () {
      for (var iter = 0; iter < 50; iter++) {
        final piece = CargoPiece.random(4, 4, gridCols);
        for (var i = 0; i < piece.shape.length; i++) {
          for (var j = 0; j < piece.shape[i].length; j++) {
            if (piece.shape[i][j]) {
              expect(piece.cubes[i][j]!.value, 4);
            }
          }
        }
      }
    });
  });

  group('CargoParticle physics', () {
    test('update advances position, decays life, and reports death', () {
      const anyColor = Color(0xFFFFFFFF);
      final particle = CargoParticle(
        position: const Offset(10, 10),
        velocity: const Offset(0, 100), // 100 px/s downward
        color: anyColor,
        size: 4,
        life: 1.0,
      );

      // Half-second step: y advances ~50, life drops to ~0.5, still alive.
      final diedFirst = particle.update(0.5);
      expect(diedFirst, isFalse);
      expect(particle.position.dy, greaterThan(10));
      expect(particle.life, closeTo(0.5, 0.0001));

      // Another full second exhausts the remaining life -> dies.
      final diedSecond = particle.update(1.0);
      expect(diedSecond, isTrue);
      expect(particle.life, lessThanOrEqualTo(0));
    });

    test('factory bonus particle starts with full positive life', () {
      for (var i = 0; i < 50; i++) {
        final p = CargoParticle.bonus(Offset.zero, const Color(0xFF00FF00));
        expect(p.life, greaterThan(0));
        expect(p.size, greaterThan(0));
      }
    });
  });

  group('value objects', () {
    test('Position stores its coordinates', () {
      final pos = Position(3, 7);
      expect(pos.x, 3);
      expect(pos.y, 7);
    });

    test('BonusMatch carries type, positions and values', () {
      final match = BonusMatch(
        BonusType.consecutive4,
        [Position(0, 0), Position(1, 0)],
        [1, 2, 3, 4],
      );
      expect(match.type, BonusType.consecutive4);
      expect(match.positions, hasLength(2));
      expect(match.values, [1, 2, 3, 4]);
    });

    test('BonusType enum has the documented 13 bonus kinds', () {
      // targetSum + 3 fib + 3 doubling + 4 consecutive + 2 square = 13.
      expect(BonusType.values, hasLength(13));
    });
  });

  group('painters shouldRepaint', () {
    test('CargoBayPainter repaints only when pulse changes', () {
      final a = CargoBayPainter(
          pulseIntensity: 0.5, gameWon: false, gameLost: false);
      final same = CargoBayPainter(
          pulseIntensity: 0.5, gameWon: true, gameLost: true);
      final diff = CargoBayPainter(
          pulseIntensity: 0.9, gameWon: false, gameLost: false);
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(diff), isTrue);
    });

    test('GridPainter repaints on cellSize or intensity change', () {
      final a = GridPainter(cellSize: 20, intensity: 0.5);
      final same = GridPainter(cellSize: 20, intensity: 0.5);
      final diffCell = GridPainter(cellSize: 25, intensity: 0.5);
      final diffIntensity = GridPainter(cellSize: 20, intensity: 0.8);
      expect(a.shouldRepaint(same), isFalse);
      expect(a.shouldRepaint(diffCell), isTrue);
      expect(a.shouldRepaint(diffIntensity), isTrue);
    });
  });

  group('CargoPiece.random structured sampling (bonus-reachability fix)', () {
    // Reads a piece's filled-cell values in row-major order.
    List<int> filledValues(CargoPiece p) {
      final out = <int>[];
      for (var i = 0; i < p.shape.length; i++) {
        for (var j = 0; j < p.shape[i].length; j++) {
          if (p.shape[i][j]) out.add(p.cubes[i][j]!.value);
        }
      }
      return out;
    }

    test('sequenceChance:1.0 always yields a consecutive run (±1 monotonic)',
        () {
      for (var iter = 0; iter < 200; iter++) {
        final p = CargoPiece.random(1, 9, 8, sequenceChance: 1.0);
        final vals = filledValues(p);
        expect(vals, isNotEmpty);
        // Wide range (1..9) always fits a run for any piece (<=4 cells), so the
        // values must step by exactly +1 or exactly -1 throughout.
        if (vals.length >= 2) {
          final step = vals[1] - vals[0];
          expect(step.abs(), 1, reason: 'not a unit step: $vals');
          for (var k = 1; k < vals.length; k++) {
            expect(vals[k] - vals[k - 1], step, reason: 'not monotonic: $vals');
          }
        }
        // Still in range.
        for (final v in vals) {
          expect(v, inInclusiveRange(1, 9));
        }
      }
    });

    test('targetSumChance:1.0 clusters values near targetSum/gridCols', () {
      // center = round(80/8) = 10, clamped into [1,20]; values land in 9..11.
      for (var iter = 0; iter < 200; iter++) {
        final p = CargoPiece.random(1, 20, 8,
            targetSum: 80, sequenceChance: 0.0, targetSumChance: 1.0);
        for (final v in filledValues(p)) {
          expect(v, inInclusiveRange(9, 11),
              reason: 'value $v not clustered near center 10');
        }
      }
    });

    test('structured sampling still respects a degenerate range', () {
      for (var iter = 0; iter < 50; iter++) {
        final p = CargoPiece.random(7, 7, 8,
            targetSum: 56, sequenceChance: 0.5, targetSumChance: 0.5);
        for (final v in filledValues(p)) {
          expect(v, 7);
        }
      }
    });
  });
}
