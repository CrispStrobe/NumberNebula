// Unit tests for the public, pure logic exposed by grid_filler_game.dart.
//
// The core collision / win-scoring logic lives in the PRIVATE State class
// (_canPlacePiece, _checkWin, _placePieceFromPanel) and cannot be exercised
// without adding a dependency-injection seam to lib/ — which the task forbids.
// We therefore test the public, side-effect-free units the file does export:
//   * GridPiece   — the available-piece model (count / remainingCount).
//   * PlacedPiece — the placed-instance model (mutable position).
//   * GridFillerPainter.shouldRepaint — the only pure decision method on the
//     CustomPainter, which drives every visual repaint of the board.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/grid_filler_game.dart';

void main() {
  group('GridPiece model', () {
    test('remainingCount initializes to count', () {
      final piece = GridPiece(size: 3, count: 3, color: const Color(0xFF112233));
      expect(piece.size, 3);
      expect(piece.count, 3);
      expect(piece.remainingCount, 3);
    });

    test('remainingCount is mutable and independent of count', () {
      final piece = GridPiece(size: 5, count: 5, color: Colors.green);
      piece.remainingCount -= 2;
      expect(piece.remainingCount, 3);
      expect(piece.count, 5, reason: 'count is final and must not change');
    });

    test('the game initial inventory invariant holds: size==count for 1..9 '
        'so the total placed area exactly fills a 45x45 grid (sum of n*n^2)', () {
      // The screen builds 9 pieces where piece i has size==count==(i+1).
      // Total covered cells = sum_{n=1..9} n * (n*n) = sum n^3 = 2025 = 45^2.
      final pieces = List.generate(
        9,
        (i) => GridPiece(size: i + 1, count: i + 1, color: Colors.white),
      );
      var totalCells = 0;
      for (final p in pieces) {
        expect(p.remainingCount, p.count);
        totalCells += p.count * p.size * p.size;
      }
      expect(totalCells, 45 * 45,
          reason: 'inventory must tile the full 45x45 grid');
    });
  });

  group('PlacedPiece model', () {
    test('stores size, position and color; position is mutable', () {
      final piece = PlacedPiece(
        size: 4,
        position: const Offset(2, 3),
        color: Colors.blue,
      );
      expect(piece.size, 4);
      expect(piece.position, const Offset(2, 3));
      expect(piece.color, Colors.blue);

      piece.position = const Offset(10, 11);
      expect(piece.position, const Offset(10, 11));
    });
  });

  group('GridFillerPainter.shouldRepaint', () {
    GridFillerPainter make({
      Offset? hover,
      int? previewSize,
      bool canPlace = true,
    }) =>
        GridFillerPainter(
          gridSize: 45,
          cellSize: 10,
          hoverPosition: hover,
          previewSize: previewSize,
          previewColor: const Color(0xFF06FFA5),
          canPlace: canPlace,
        );

    test('identical configuration does not repaint', () {
      final a = make(hover: const Offset(1, 1), previewSize: 2);
      final b = make(hover: const Offset(1, 1), previewSize: 2);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('hover position change triggers repaint', () {
      final a = make(hover: const Offset(1, 1), previewSize: 2);
      final b = make(hover: const Offset(5, 5), previewSize: 2);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('preview size change triggers repaint', () {
      final a = make(hover: const Offset(1, 1), previewSize: 2);
      final b = make(hover: const Offset(1, 1), previewSize: 3);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('canPlace change (valid <-> invalid placement) triggers repaint', () {
      final a = make(hover: const Offset(1, 1), previewSize: 2, canPlace: true);
      final b =
          make(hover: const Offset(1, 1), previewSize: 2, canPlace: false);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('null hover stable across rebuilds does not repaint', () {
      final a = make();
      final b = make();
      expect(a.shouldRepaint(b), isFalse);
    });
  });
}
