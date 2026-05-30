// Unit tests for gridlock_puzzle_generator.dart (Space Station Gridlock).
//
// IMPORTANT TESTABILITY LIMITATION:
//   The interesting algorithmic pieces of this file — _generateRandomPuzzle,
//   _solvePuzzle, _canPlaceShip, _checkCollision, _tryMove — are all PRIVATE
//   top-level functions and therefore cannot be imported from a test. The
//   generator also calls main() (which performs dart:io file output) and uses
//   an UNSEEDED math.Random() with no injection seam, so generated output is
//   non-deterministic and not reachable from outside the library anyway.
//
//   The only public, pure, side-effect-free surface is the data class
//   SolverState (plus the trivial holders PuzzleConfig / GeneratedPuzzle).
//   SolverState.hashKey is the de-duplication key that drives the BFS solver's
//   `visited` set, so its correctness is load-bearing: a wrong hash either
//   merges distinct board states (missed solutions) or fails to merge equal
//   ones (exponential blow-up). We therefore test the hashing INVARIANTS that
//   the solver relies on, rather than the unreachable private generator/solver.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/shared/utils/gridlock_puzzle_generator.dart';

Map<String, dynamic> _ship({
  required int row,
  required int col,
  int length = 2,
  bool isHorizontal = true,
  bool isPlayer = false,
}) {
  return {
    'row': row,
    'col': col,
    'length': length,
    'isHorizontal': isHorizontal,
    'isPlayer': isPlayer,
  };
}

void main() {
  group('SolverState.hashKey', () {
    test('is order-independent for the same set of ships', () {
      final a = _ship(row: 2, col: 0, isPlayer: true);
      final b = _ship(row: 0, col: 1, isHorizontal: false, length: 3);
      final c = _ship(row: 4, col: 4);

      final s1 = SolverState([a, b, c], 0);
      final s2 = SolverState([c, a, b], 5); // different list order + moves

      expect(s1.hashKey, equals(s2.hashKey),
          reason: 'hashKey must be a canonical, order-independent fingerprint '
              'of the board so the solver can de-duplicate states regardless '
              'of ship list ordering.');
    });

    test('does not depend on the move counter', () {
      final ships = [
        _ship(row: 2, col: 0, isPlayer: true),
        _ship(row: 0, col: 3, isHorizontal: false),
      ];
      final early = SolverState(ships, 1);
      final later = SolverState(ships, 99);

      expect(early.hashKey, equals(later.hashKey),
          reason: 'Two boards with identical ship layouts are the same '
              'position; move count must not affect the visited-set key.');
    });

    test('distinguishes positions that differ only by one ship moving', () {
      final base = [
        _ship(row: 2, col: 0, isPlayer: true),
        _ship(row: 0, col: 3, isHorizontal: false),
      ];
      // Move the player ship one column to the right.
      final moved = [
        _ship(row: 2, col: 1, isPlayer: true),
        _ship(row: 0, col: 3, isHorizontal: false),
      ];

      expect(SolverState(base, 0).hashKey,
          isNot(equals(SolverState(moved, 0).hashKey)),
          reason: 'A real move must produce a distinct key, otherwise the '
              'solver would treat the new state as already-visited and never '
              'find solutions.');
    });

    test('distinguishes orientation (horizontal vs vertical) at same anchor',
        () {
      final horizontal = [_ship(row: 1, col: 1, length: 3, isHorizontal: true)];
      final vertical = [_ship(row: 1, col: 1, length: 3, isHorizontal: false)];

      expect(SolverState(horizontal, 0).hashKey,
          isNot(equals(SolverState(vertical, 0).hashKey)),
          reason: 'Orientation is encoded as H/V in the key and must '
              'distinguish otherwise-identical ships.');
    });

    test('distinguishes ship length at same anchor and orientation', () {
      final len2 = [_ship(row: 3, col: 0, length: 2)];
      final len3 = [_ship(row: 3, col: 0, length: 3)];

      expect(SolverState(len2, 0).hashKey,
          isNot(equals(SolverState(len3, 0).hashKey)));
    });

    test('encodes every ship in the key (count of segments matches ships)', () {
      final ships = [
        _ship(row: 2, col: 0, isPlayer: true),
        _ship(row: 0, col: 3, isHorizontal: false),
        _ship(row: 5, col: 2),
      ];
      final key = SolverState(ships, 0).hashKey;

      // Segments are joined by '|', so N ships -> N segments.
      expect(key.split('|').length, equals(ships.length));
      // Each segment is "row,col,length,(H|V)".
      for (final segment in key.split('|')) {
        expect(RegExp(r'^\d+,\d+,\d+,[HV]$').hasMatch(segment), isTrue,
            reason: 'Unexpected segment format: $segment');
      }
    });

    test('does not mutate the input ship list ordering', () {
      final a = _ship(row: 5, col: 5);
      final b = _ship(row: 0, col: 0, isPlayer: true);
      final input = [a, b]; // intentionally non-canonical order
      SolverState(input, 0);

      // SolverState sorts a COPY, so the caller's list must be untouched —
      // the solver depends on this because it reuses the ship list to spawn
      // successor states.
      expect(identical(input[0], a), isTrue);
      expect(identical(input[1], b), isTrue);
    });

    test('hashKey is computed eagerly and stable across reads', () {
      final state = SolverState(
        [_ship(row: 2, col: 0, isPlayer: true)],
        0,
      );
      final first = state.hashKey;
      final second = state.hashKey;
      expect(first, same(second));
      expect(first, equals('2,0,2,H'));
    });
  });

  group('PuzzleConfig / GeneratedPuzzle holders', () {
    test('PuzzleConfig retains the exact ship list given', () {
      final ships = [_ship(row: 2, col: 0, isPlayer: true)];
      final config = PuzzleConfig(ships: ships);
      expect(config.ships, same(ships));
    });

    test('GeneratedPuzzle preserves its fields', () {
      final ships = [_ship(row: 2, col: 0, isPlayer: true)];
      final puzzle = GeneratedPuzzle(
        id: 'GRID_1',
        complexity: 4.0,
        minMoves: 12,
        ships: ships,
      );
      expect(puzzle.id, 'GRID_1');
      expect(puzzle.complexity, 4.0);
      expect(puzzle.minMoves, 12);
      expect(puzzle.ships, same(ships));
    });
  });
}
