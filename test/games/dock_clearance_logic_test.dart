// Unit tests for dock_clearance_logic.dart.
//
// Tests the Rush Hour / sliding block puzzle logic: ship cell computation,
// grid building, non-overlapping ships, target ship presence, and BFS
// solvability. The generator uses an unseeded Random, so we test structural
// invariants over multiple seeded generations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/dock_clearance_logic.dart';

void main() {
  group('Ship.cells', () {
    test('horizontal ship occupies correct cells', () {
      final ship = Ship(
        id: 0, row: 2, col: 1, length: 3,
        orientation: ShipOrientation.horizontal,
      );
      expect(ship.cells, [
        [2, 1],
        [2, 2],
        [2, 3],
      ]);
    });

    test('vertical ship occupies correct cells', () {
      final ship = Ship(
        id: 1, row: 0, col: 3, length: 2,
        orientation: ShipOrientation.vertical,
      );
      expect(ship.cells, [
        [0, 3],
        [1, 3],
      ]);
    });
  });

  group('Ship.copyWith', () {
    test('copyWith preserves unchanged fields', () {
      final ship = Ship(
        id: 5, row: 1, col: 2, length: 3,
        orientation: ShipOrientation.horizontal, isTarget: true,
      );
      final moved = ship.copyWith(col: 4);
      expect(moved.id, 5);
      expect(moved.row, 1);
      expect(moved.col, 4);
      expect(moved.length, 3);
      expect(moved.orientation, ShipOrientation.horizontal);
      expect(moved.isTarget, true);
    });
  });

  group('DockClearancePuzzle.buildGrid', () {
    test('grid marks ship ids at correct positions', () {
      final ships = [
        Ship(id: 0, row: 0, col: 0, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
        Ship(id: 1, row: 2, col: 1, length: 2,
            orientation: ShipOrientation.vertical),
      ];
      final grid = DockClearancePuzzle.buildGrid(4, ships);
      expect(grid[0][0], 0);
      expect(grid[0][1], 0);
      expect(grid[2][1], 1);
      expect(grid[3][1], 1);
      expect(grid[1][1], -1); // empty
    });
  });

  group('DockClearancePuzzle.isTargetAtExit', () {
    test('returns true when target reaches right edge', () {
      final ships = [
        Ship(id: 0, row: 2, col: 4, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
      ];
      expect(DockClearancePuzzle.isTargetAtExit(ships, 6), isTrue);
    });

    test('returns false when target is not at right edge', () {
      final ships = [
        Ship(id: 0, row: 2, col: 0, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
      ];
      expect(DockClearancePuzzle.isTargetAtExit(ships, 6), isFalse);
    });
  });

  group('DockClearancePuzzle.encodeState', () {
    test('encodes ship positions deterministically', () {
      final ships = [
        Ship(id: 0, row: 1, col: 2, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
        Ship(id: 1, row: 3, col: 0, length: 2,
            orientation: ShipOrientation.vertical),
      ];
      final state = DockClearancePuzzle.encodeState(ships);
      expect(state, contains('0:1,2'));
      expect(state, contains('1:3,0'));
    });
  });

  group('DockClearancePuzzle.solveBFS', () {
    test('solves a trivial puzzle in 1 move', () {
      // Target just needs to slide right by 1 to reach edge on a 4x4 board
      final ships = [
        Ship(id: 0, row: 1, col: 2, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
      ];
      final result = DockClearancePuzzle.solveBFS(4, ships);
      expect(result, isNotNull);
      expect(result, 0); // col=2, length=2, so col+length=4=boardSize -> already at exit
    });

    test('returns 0 for already-solved puzzle', () {
      final ships = [
        Ship(id: 0, row: 0, col: 4, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
      ];
      expect(DockClearancePuzzle.solveBFS(6, ships), 0);
    });

    test('finds solution when ship is blocked', () {
      // 6x6 board: target at (2,0) len 2, blocker at (2,2) vertical len 2
      final ships = [
        Ship(id: 0, row: 2, col: 0, length: 2,
            orientation: ShipOrientation.horizontal, isTarget: true),
        Ship(id: 1, row: 1, col: 2, length: 2,
            orientation: ShipOrientation.vertical),
      ];
      final result = DockClearancePuzzle.solveBFS(6, ships);
      expect(result, isNotNull);
      expect(result!, greaterThan(0));
    });
  });

  group('DockClearancePuzzle.generate (invariants)', () {
    final testCases = <Map<String, int>>[
      // grade 1-like: small board, few ships
      {'boardSize': 5, 'shipCount': 3, 'minMoves': 1},
      // grade 4-like: larger board, more ships
      {'boardSize': 6, 'shipCount': 5, 'minMoves': 2},
    ];

    for (final tc in testCases) {
      final boardSize = tc['boardSize']!;
      final shipCount = tc['shipCount']!;
      final minMoves = tc['minMoves']!;

      test('boardSize=$boardSize shipCount=$shipCount: structure is well-formed',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = DockClearancePuzzle.generate(
            boardSize: boardSize,
            shipCount: shipCount,
            minMoves: minMoves,
            seed: seed,
          );

          expect(puzzle.boardSize, boardSize);

          // At least one ship must be the target (red ship)
          final targets = puzzle.ships.where((s) => s.isTarget).toList();
          expect(targets.length, 1,
              reason: 'exactly one target ship expected');

          // Target ship must be horizontal
          expect(targets.first.orientation, ShipOrientation.horizontal);

          // All ships must fit within the board
          for (final ship in puzzle.ships) {
            for (final cell in ship.cells) {
              expect(cell[0], inInclusiveRange(0, boardSize - 1),
                  reason: 'ship ${ship.id} row out of bounds');
              expect(cell[1], inInclusiveRange(0, boardSize - 1),
                  reason: 'ship ${ship.id} col out of bounds');
            }
          }
        }
      });

      test('boardSize=$boardSize shipCount=$shipCount: no overlapping ships',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = DockClearancePuzzle.generate(
            boardSize: boardSize,
            shipCount: shipCount,
            minMoves: minMoves,
            seed: seed,
          );

          final occupied = <String>{};
          for (final ship in puzzle.ships) {
            for (final cell in ship.cells) {
              final key = '${cell[0]},${cell[1]}';
              expect(occupied.contains(key), isFalse,
                  reason: 'cell $key occupied by multiple ships');
              occupied.add(key);
            }
          }
        }
      });

      test('boardSize=$boardSize shipCount=$shipCount: puzzle is solvable via BFS',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = DockClearancePuzzle.generate(
            boardSize: boardSize,
            shipCount: shipCount,
            minMoves: minMoves,
            seed: seed,
          );

          expect(puzzle.optimalMoves, greaterThanOrEqualTo(minMoves),
              reason: 'optimal moves should meet minimum requirement');

          // Independently verify BFS solvability
          final solution =
              DockClearancePuzzle.solveBFS(puzzle.boardSize, puzzle.ships);
          expect(solution, isNotNull,
              reason: 'generated puzzle must be BFS-solvable');
          expect(solution, puzzle.optimalMoves);
        }
      });
    }

    test('ship lengths are 2 or 3', () {
      final puzzle = DockClearancePuzzle.generate(
        boardSize: 6, shipCount: 5, minMoves: 1, seed: 42,
      );
      for (final ship in puzzle.ships) {
        expect(ship.length, anyOf(2, 3));
      }
    });
  });
}
