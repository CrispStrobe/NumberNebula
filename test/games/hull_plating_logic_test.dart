// Unit tests for hull_plating_logic.dart (polyomino packing redesign).
//
// Tests pure logic: board generation, piece rotation, solution coverage,
// and validatePlacement.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/hull_plating_logic.dart';

void main() {
  group('HullPlatingPuzzle.isDarkCell', () {
    test('checkerboard pattern: (r+c) even is dark', () {
      expect(HullPlatingPuzzle.isDarkCell(0, 0), isTrue);
      expect(HullPlatingPuzzle.isDarkCell(0, 1), isFalse);
      expect(HullPlatingPuzzle.isDarkCell(1, 0), isFalse);
      expect(HullPlatingPuzzle.isDarkCell(1, 1), isTrue);
    });
  });

  group('PlatingPiece rotation', () {
    test('rotating a domino 4 times returns to original', () {
      final piece = PlatingPiece(
        id: 0,
        cells: [(0, 0), (0, 1)],
        color: Color4.red,
      );
      var current = piece;
      for (int i = 0; i < 4; i++) {
        current = current.rotated();
      }
      // After 4 rotations, cells should match original (normalized)
      expect(current.cells.toSet(), piece.cells.toSet());
    });

    test('allRotations returns distinct rotations only', () {
      // A square piece has only 1 unique rotation
      final square = PlatingPiece(
        id: 0,
        cells: [(0, 0), (0, 1), (1, 0), (1, 1)],
        color: Color4.blue,
      );
      expect(square.allRotations().length, 1);

      // A domino has 2 unique rotations
      final domino = PlatingPiece(
        id: 1,
        cells: [(0, 0), (0, 1)],
        color: Color4.green,
      );
      expect(domino.allRotations().length, 2);

      // An L-piece has 4 unique rotations
      final lPiece = PlatingPiece(
        id: 2,
        cells: [(0, 0), (1, 0), (2, 0), (2, 1)],
        color: Color4.yellow,
      );
      expect(lPiece.allRotations().length, 4);
    });

    test('width and height computed correctly', () {
      final piece = PlatingPiece(
        id: 0,
        cells: [(0, 0), (0, 1), (0, 2)],
        color: Color4.red,
      );
      expect(piece.width, 3);
      expect(piece.height, 1);
    });
  });

  group('PlacedPiece.covers', () {
    test('covers returns true for its own cells', () {
      final p = PlacedPiece(
        pieceId: 0,
        absoluteCells: [(2, 3), (2, 4)],
      );
      expect(p.covers(2, 3), isTrue);
      expect(p.covers(2, 4), isTrue);
      expect(p.covers(2, 5), isFalse);
      expect(p.covers(0, 0), isFalse);
    });
  });

  group('HullPlatingPuzzle.generate: board structure', () {
    test('grade 1: 3x4 board', () {
      for (int seed = 0; seed < 3; seed++) {
        final puzzle = HullPlatingPuzzle.generate(
          grade: 1, level: 1, seed: seed,
        );
        expect(puzzle.rows, 3);
        expect(puzzle.cols, 4);

        // All cells active (no holes at grade 1)
        for (int r = 0; r < puzzle.rows; r++) {
          for (int c = 0; c < puzzle.cols; c++) {
            expect(puzzle.board[r][c], isTrue);
          }
        }
      }
    });

    test('grade 2: 4x4 board', () {
      final puzzle = HullPlatingPuzzle.generate(
        grade: 2, level: 1, seed: 42,
      );
      expect(puzzle.rows, 4);
      expect(puzzle.cols, 4);
    });

    test('grade 3+: 4x6 board', () {
      final puzzle = HullPlatingPuzzle.generate(
        grade: 3, level: 1, seed: 42,
      );
      expect(puzzle.rows, 4);
      expect(puzzle.cols, 6);
    });
  });

  group('HullPlatingPuzzle.generate: solution validity', () {
    test('solution pieces cover all active cells without overlap', () {
      for (int grade = 1; grade <= 3; grade++) {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = HullPlatingPuzzle.generate(
            grade: grade, level: 1, seed: seed,
          );

          final covered = <String>{};
          for (final placed in puzzle.solution) {
            for (final cell in placed.absoluteCells) {
              final key = '${cell.$1},${cell.$2}';
              expect(covered.contains(key), isFalse,
                  reason: 'Cell $key covered twice (grade=$grade seed=$seed)');
              covered.add(key);

              // Cell must be on the board
              expect(cell.$1, greaterThanOrEqualTo(0));
              expect(cell.$1, lessThan(puzzle.rows));
              expect(cell.$2, greaterThanOrEqualTo(0));
              expect(cell.$2, lessThan(puzzle.cols));
              expect(puzzle.board[cell.$1][cell.$2], isTrue);
            }
          }

          // All active cells must be covered
          for (int r = 0; r < puzzle.rows; r++) {
            for (int c = 0; c < puzzle.cols; c++) {
              if (puzzle.board[r][c]) {
                expect(covered.contains('$r,$c'), isTrue,
                    reason: 'Active cell ($r,$c) not covered');
              }
            }
          }
        }
      }
    });

    test('pieces list matches solution piece count', () {
      final puzzle = HullPlatingPuzzle.generate(
        grade: 2, level: 1, seed: 0,
      );
      expect(puzzle.pieces.length, puzzle.solution.length);
    });

    test('total cells in solution equals active cell count', () {
      final puzzle = HullPlatingPuzzle.generate(
        grade: 1, level: 1, seed: 0,
      );
      int totalCells = 0;
      for (final placed in puzzle.solution) {
        totalCells += placed.absoluteCells.length;
      }
      expect(totalCells, puzzle.activeCellCount);
    });
  });

  group('HullPlatingPuzzle.validatePlacement', () {
    test('valid full-coverage passes', () {
      final board = [
        [true, true],
        [true, true],
      ];
      final p1 = PlacedPiece(pieceId: 0, absoluteCells: [(0, 0), (0, 1)]);
      final p2 = PlacedPiece(pieceId: 1, absoluteCells: [(1, 0), (1, 1)]);
      expect(
        HullPlatingPuzzle.validatePlacement([p1, p2], board, 2, 2),
        isTrue,
      );
    });

    test('partial coverage fails', () {
      final board = [
        [true, true],
        [true, true],
      ];
      final p1 = PlacedPiece(pieceId: 0, absoluteCells: [(0, 0), (0, 1)]);
      expect(
        HullPlatingPuzzle.validatePlacement([p1], board, 2, 2),
        isFalse,
      );
    });

    test('overlapping pieces fail', () {
      final board = [
        [true, true],
        [true, true],
      ];
      final p1 = PlacedPiece(pieceId: 0, absoluteCells: [(0, 0), (0, 1)]);
      final p2 = PlacedPiece(pieceId: 1, absoluteCells: [(0, 0), (1, 0)]);
      expect(
        HullPlatingPuzzle.validatePlacement([p1, p2], board, 2, 2),
        isFalse,
      );
    });

    test('placing on hole fails', () {
      final board = [
        [true, false],
        [true, true],
      ];
      final p = PlacedPiece(pieceId: 0, absoluteCells: [(0, 0), (0, 1)]);
      expect(
        HullPlatingPuzzle.validatePlacement([p], board, 2, 2),
        isFalse,
      );
    });

    test('out of bounds fails', () {
      final board = [
        [true, true],
      ];
      final p = PlacedPiece(pieceId: 0, absoluteCells: [(0, 0), (1, 0)]);
      expect(
        HullPlatingPuzzle.validatePlacement([p], board, 1, 2),
        isFalse,
      );
    });
  });
}
