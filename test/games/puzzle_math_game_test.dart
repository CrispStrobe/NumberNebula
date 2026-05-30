// Pure-logic tests for puzzle_math_game.dart.
//
// The interactive _PuzzleMathGameState is not unit-testable in isolation:
// _initializeGame() hard-reads GameProvider + SriService from context, pulls a
// real asset path from PuzzleImageService, and the build tree depends on
// generated localizations and asset images. There is no DI seam and the task
// forbids adding one, so we instead test the file's pure, public, side-effect-
// free building blocks directly:
//
//  * PuzzlePieceData  -- the model that backs every slot/piece (answer +
//    problemExpression delegate to its MathProblem; rotation is mutable).
//  * JigsawPieceClipper.getClip / shouldReclip -- the geometry that draws the
//    jigsaw edges. We assert INVARIANTS that must hold for every piece of a
//    grid regardless of which random knob/hole pattern is chosen.
//
// The edge-shape map is built the same way the screen builds it
// (_generateEdgeShapes) but with a *seeded* Random so the suite is
// deterministic.

import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/screens/puzzle_math_game.dart';

/// Build an interior-edge-shape map exactly like the screen's
/// _generateEdgeShapes, but with a seeded Random for determinism.
Map<String, JigsawSide> buildEdgeShapes(int columns, int rows, int seed) {
  final shapes = <String, JigsawSide>{};
  final random = math.Random(seed);
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < columns - 1; c++) {
      shapes['h-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
    }
  }
  for (int r = 0; r < rows - 1; r++) {
    for (int c = 0; c < columns; c++) {
      shapes['v-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
    }
  }
  return shapes;
}

PuzzlePieceData pieceAt(int row, int col, int columns) {
  return PuzzlePieceData(
    id: row * columns + col,
    problem: MathProblem.addition(row, col),
    row: row,
    col: col,
  );
}

void main() {
  group('PuzzlePieceData', () {
    test('answer and problemExpression delegate to the underlying problem', () {
      final problem = MathProblem.multiplication(6, 7);
      final piece = PuzzlePieceData(id: 3, problem: problem, row: 1, col: 2);

      expect(piece.answer, 42);
      expect(piece.answer, problem.answer);
      expect(piece.problemExpression, problem.expression);
      expect(piece.id, 3);
      expect(piece.row, 1);
      expect(piece.col, 2);
    });

    test('rotation defaults to 0 and is mutable (matches _rotatePiece)', () {
      final piece = PuzzlePieceData(
        id: 0,
        problem: MathProblem.addition(2, 3),
        row: 0,
        col: 0,
      );
      expect(piece.rotation, 0);

      // _rotatePiece advances by 90 degrees mod 360.
      piece.rotation = (piece.rotation + 90) % 360;
      expect(piece.rotation, 90);
      piece.rotation = (piece.rotation + 90) % 360;
      piece.rotation = (piece.rotation + 90) % 360;
      piece.rotation = (piece.rotation + 90) % 360;
      expect(piece.rotation, 0); // wraps back around after four turns
    });
  });

  group('JigsawPieceClipper.getClip invariants', () {
    // Iterate the grade->grid mapping the screen actually uses, with several
    // seeds, and verify every piece produces a valid clip path.
    const grids = <List<int>>[
      [2, 2],
      [2, 3],
      [3, 3],
      [3, 4],
    ];

    test('every piece of every grid yields a closed, in-bounds path', () {
      const pieceSide = 80.0;
      const bumpSize = pieceSide / 4;
      const extended = Size(pieceSide + bumpSize * 2, pieceSide + bumpSize * 2);

      for (final grid in grids) {
        final columns = grid[0];
        final rows = grid[1];
        for (int seed = 0; seed < 5; seed++) {
          final edgeShapes = buildEdgeShapes(columns, rows, seed);

          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < columns; c++) {
              final data = pieceAt(r, c, columns);
              final clipper = JigsawPieceClipper(
                data: data,
                columns: columns,
                rows: rows,
                edgeShapes: edgeShapes,
                bumpSize: bumpSize,
              );

              final Path path = clipper.getClip(extended);

              // A real piece outline encloses positive area.
              final bounds = path.getBounds();
              expect(bounds.isEmpty, isFalse,
                  reason: 'empty path for ($r,$c) ${columns}x$rows seed=$seed');

              // The core piece centre must lie inside the outline.
              final centre =
                  Offset(extended.width / 2, extended.height / 2);
              expect(path.contains(centre), isTrue,
                  reason: 'centre outside path for ($r,$c) '
                      '${columns}x$rows seed=$seed');

              // Knobs/holes never extend further than one bumpSize beyond the
              // extended widget box, so bounds stay within a tight envelope.
              expect(bounds.left, greaterThanOrEqualTo(-0.01));
              expect(bounds.top, greaterThanOrEqualTo(-0.01));
              expect(bounds.right, lessThanOrEqualTo(extended.width + 0.01));
              expect(bounds.bottom, lessThanOrEqualTo(extended.height + 0.01));
            }
          }
        }
      }
    });

    test('outer border edges of corner pieces are flat (no knob beyond box)',
        () {
      // A flat edge keeps the outline flush against bumpSize..bumpSize+core.
      // Corner piece (0,0) in a 3x4 grid has flat top and flat left edges.
      const pieceSide = 100.0;
      const bumpSize = pieceSide / 4;
      const extended = Size(pieceSide + bumpSize * 2, pieceSide + bumpSize * 2);
      final edgeShapes = buildEdgeShapes(3, 4, 7);

      final corner = pieceAt(0, 0, 3);
      final clipper = JigsawPieceClipper(
        data: corner,
        columns: 3,
        rows: 4,
        edgeShapes: edgeShapes,
        bumpSize: bumpSize,
      );
      final bounds = clipper.getClip(extended).getBounds();

      // Flat top edge => nothing pokes above bumpSize.
      expect(bounds.top, greaterThanOrEqualTo(bumpSize - 0.01));
      // Flat left edge => nothing pokes left of bumpSize.
      expect(bounds.left, greaterThanOrEqualTo(bumpSize - 0.01));
    });
  });

  group('JigsawPieceClipper.shouldReclip', () {
    final shapes = buildEdgeShapes(3, 3, 1);
    final dataA = pieceAt(0, 0, 3);
    final dataB = pieceAt(1, 1, 3);

    JigsawPieceClipper make(PuzzlePieceData d, double bump) => JigsawPieceClipper(
          data: d,
          columns: 3,
          rows: 3,
          edgeShapes: shapes,
          bumpSize: bump,
        );

    test('reclips when data, bumpSize, or edgeShapes change', () {
      final base = make(dataA, 20);

      // Same inputs -> no reclip.
      expect(base.shouldReclip(make(dataA, 20)), isFalse);

      // Different piece data -> reclip.
      expect(base.shouldReclip(make(dataB, 20)), isTrue);

      // Different bump size -> reclip.
      expect(base.shouldReclip(make(dataA, 25)), isTrue);

      // Different edgeShapes map instance -> reclip.
      final other = JigsawPieceClipper(
        data: dataA,
        columns: 3,
        rows: 3,
        edgeShapes: buildEdgeShapes(3, 3, 99),
        bumpSize: 20,
      );
      expect(base.shouldReclip(other), isTrue);
    });
  });
}
