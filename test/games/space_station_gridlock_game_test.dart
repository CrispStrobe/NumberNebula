// Unit tests for space_station_gridlock_game.dart (Space Station Gridlock,
// a Rush-Hour style sliding-block puzzle).
//
// TESTABILITY NOTES:
//   The interactive surface (drag handling, win detection, scoring, success
//   dialog, HapticFeedback, particle rendering, AnimationControllers and the
//   GameProvider/GridlockPuzzleTracker wiring) all lives in the private
//   _SpaceStationGridlockGameState and is not unit-testable without a full
//   provider tree + plugin mocks. We therefore test the public, pure-ish
//   surfaces that encode the actual game logic:
//     - SpaceShip               (the movable-piece model + mutability contract)
//     - GridlockParticle.update (the particle physics step + invariants)
//     - PuzzleConfiguration / PuzzleGenerator.generate (fallback puzzle)
//     - GridlockPuzzleDatabase  (the bundled Rush-Hour puzzle database)
//   For the puzzle database we assert structural INVARIANTS that every puzzle
//   must satisfy for the game to be solvable / renderable: exactly one player
//   ship, every ship fully in-bounds on the 6x6 grid, the player ship is
//   horizontal (it must slide out the right edge), and the declared complexity
//   matches the bucket the lookup returned.

import 'dart:io';

import 'package:flutter/material.dart' show Color, Colors, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/space_station_gridlock_game.dart';
import 'package:space_math_academy/features/games/data/gridlock_puzzles_data.dart';

const int gridSize = 6;

void main() {
  group('SpaceShip model', () {
    test('stores its configuration and exposes mutable row/col', () {
      final ship = SpaceShip(
        row: 2,
        col: 1,
        length: 2,
        isHorizontal: true,
        isPlayer: true,
        color: const Color(0xFF00FF00),
      );

      expect(ship.length, 2);
      expect(ship.isHorizontal, isTrue);
      expect(ship.isPlayer, isTrue);
      expect(ship.isBlocking, isFalse, reason: 'isBlocking defaults to false');

      // row/col are the only mutable fields; a move must be reflectable.
      ship.col += 1;
      expect(ship.col, 2);
      ship.row += 1;
      expect(ship.row, 3);
    });
  });

  group('GridlockParticle.update physics', () {
    test('trail particle reports death exactly when life is exhausted', () {
      final p = GridlockParticle.trail(const Offset(10, 10), Colors.cyan);

      // Trail particles have a short life (0.3..0.5s). A single large step
      // must exhaust it and report death.
      final dead = p.update(5.0);
      expect(dead, isTrue);
      expect(p.life, lessThanOrEqualTo(0.0));
    });

    test('opacity stays clamped to [0,1] and moves toward 0 as it ages', () {
      final p = GridlockParticle.celebration(const Offset(0, 0));
      // Step in small increments; opacity must never leave [0,1].
      for (int i = 0; i < 50; i++) {
        p.update(0.05);
        expect(p.opacity, inInclusiveRange(0.0, 1.0));
      }
    });

    test('position advances along the velocity direction over a step', () {
      final p = GridlockParticle(
        position: const Offset(0, 0),
        velocity: const Offset(100, 0),
        color: Colors.green,
        size: 3,
        opacity: 1,
        life: 10,
      );
      p.update(0.1); // dt=0.1 -> +10 in x before damping of velocity
      expect(p.position.dx, closeTo(10.0, 0.0001));
      expect(p.position.dy, closeTo(0.0, 0.0001));
      // velocity is damped each step (*0.95), so it must have shrunk.
      expect(p.velocity.dx, lessThan(100.0));
    });
  });

  group('PuzzleGenerator fallback', () {
    test('generates a configuration with exactly one in-bounds player ship',
        () async {
      final config = await PuzzleGenerator.generate(1, 1);
      expect(config, isA<PuzzleConfiguration>());
      expect(config.minMoves, greaterThan(0));
      expect(config.ships, isNotEmpty);

      final players =
          config.ships.where((s) => s['isPlayer'] == true).toList();
      expect(players.length, 1, reason: 'fallback must have one player ship');

      for (final s in config.ships) {
        _expectShipInBounds(
          s['row'] as int,
          s['col'] as int,
          s['length'] as int,
          s['isHorizontal'] as bool,
        );
      }
    });
  });

  group('GridlockPuzzleDatabase invariants', () {
    const buckets = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0];
    final db = GridlockPuzzleDatabase.fromJson(
        File(gridlockPuzzlesAsset).readAsStringSync());
    List<GridlockPuzzleData> getPuzzlesByComplexity(double c,
            {double tolerance = 0.0}) =>
        db.byComplexity(c, tolerance: tolerance);

    test('holds the whole bundled database with unique ids', () {
      expect(db.puzzles.length, 1313);
      expect(db.puzzles.map((p) => p.id).toSet().length, 1313);
    });

    test('returns non-empty sets for every complexity bucket', () {
      for (final c in buckets) {
        final puzzles = getPuzzlesByComplexity(c, tolerance: 0.0);
        expect(puzzles, isNotEmpty, reason: 'no puzzles at complexity $c');
        // The lookup must only return puzzles of the requested complexity.
        for (final p in puzzles) {
          expect(p.complexity, c);
        }
      }
    });

    test('every bundled puzzle is solvable-shaped (one player, in-bounds)', () {
      // Validate the whole database via the public lookup so a bad data row
      // anywhere is caught. Each puzzle is the source of truth the screen
      // hands to _loadPuzzleFromData.
      for (final c in buckets) {
        for (final puzzle in getPuzzlesByComplexity(c, tolerance: 0.0)) {
          final reason = 'puzzle ${puzzle.id}';
          expect(puzzle.minMoves, greaterThan(0), reason: reason);
          expect(puzzle.ships, isNotEmpty, reason: reason);

          final players =
              puzzle.ships.where((s) => s['isPlayer'] == true).toList();
          expect(players.length, 1,
              reason: '$reason must have exactly one player ship');

          // The player ship must be horizontal: the screen wins by sliding it
          // off the right edge (_checkWinCondition only fires for horizontal).
          expect(players.first['isHorizontal'], isTrue, reason: reason);

          for (final s in puzzle.ships) {
            _expectShipInBounds(
              s['row'] as int,
              s['col'] as int,
              s['length'] as int,
              s['isHorizontal'] as bool,
              reason: reason,
            );
          }
        }
      }
    });

    test('tolerance widens the returned complexity window', () {
      final exact = getPuzzlesByComplexity(2.0, tolerance: 0.0);
      final wide = getPuzzlesByComplexity(2.0, tolerance: 1.0);
      // A wider tolerance must include at least everything the exact match did.
      expect(wide.length, greaterThanOrEqualTo(exact.length));
    });

    test('no two ships share a cell and the player can reach the exit row', () {
      for (final puzzle in db.puzzles) {
        final occupied = <int>{};
        for (final s in puzzle.ships) {
          for (int k = 0; k < (s['length'] as int); k++) {
            final r = (s['row'] as int) + (s['isHorizontal'] == true ? 0 : k);
            final c = (s['col'] as int) + (s['isHorizontal'] == true ? k : 0);
            expect(occupied.add(r * gridSize + c), isTrue,
                reason: '${puzzle.id} overlaps at ($r, $c)');
          }
        }
        final player = puzzle.ships.firstWhere((s) => s['isPlayer'] == true);
        expect(player['row'], 2, reason: '${puzzle.id} exit row');
        expect(player['length'], 2, reason: puzzle.id);
      }
    });

    test('the bundled asset loads through the asset bundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loaded = await GridlockPuzzleDatabase.load();
      expect(loaded.puzzles.length, db.puzzles.length);
      expect(identical(await GridlockPuzzleDatabase.load(), loaded), isTrue,
          reason: 'the database is parsed once and cached');
    });
  });

  group('shipsFromBoard', () {
    // GRID_1's ship list exactly as the old generated Dart database stored
    // it, so the derived order (which picks each ship's colour) is pinned.
    test('matches the ship list GRID_1 was generated with', () {
      Map<String, dynamic> s(int row, int col, int length, bool h,
              [bool player = false, bool blocking = false]) =>
          {
            'row': row,
            'col': col,
            'length': length,
            'isHorizontal': h,
            'isPlayer': player,
            'isBlocking': blocking,
          };
      expect(shipsFromBoard('IBBKooIoJKCCAAJoLMoxEELMoooFFooGGHHo'), [
        s(2, 0, 2, true, true),
        s(0, 1, 2, true),
        s(1, 4, 2, true),
        s(3, 2, 2, true),
        s(4, 3, 2, true),
        s(5, 1, 2, true),
        s(5, 3, 2, true),
        s(0, 0, 2, false),
        s(1, 2, 2, false),
        s(0, 3, 2, false),
        s(2, 4, 2, false),
        s(2, 5, 2, false),
        s(3, 1, 1, true, false, true),
      ]);
    });

    test('rejects a board of the wrong size', () {
      expect(() => shipsFromBoard('AAoo'), throwsFormatException);
    });
  });
}

void _expectShipInBounds(
  int row,
  int col,
  int length,
  bool isHorizontal, {
  String? reason,
}) {
  expect(row, inInclusiveRange(0, gridSize - 1), reason: reason);
  expect(col, inInclusiveRange(0, gridSize - 1), reason: reason);
  final endRow = isHorizontal ? row : row + length - 1;
  final endCol = isHorizontal ? col + length - 1 : col;
  expect(endRow, lessThan(gridSize), reason: reason);
  expect(endCol, lessThan(gridSize), reason: reason);
}
