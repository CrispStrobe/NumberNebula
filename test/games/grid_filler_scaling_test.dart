// Unit tests for Grid Filler difficulty scaling.
//
// The game now scales piece types (N) from 4 to 9 based on
// complexity = grade + level/5.0. Grid size = N*(N+1)/2.
// We verify the mathematical property: sum of i^3 for i=1..N = (N(N+1)/2)^2,
// meaning the total cells from pieces exactly fills a square grid.

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Compute piece types N from complexity, mirroring _initializeGame logic.
  int pieceTypesFromComplexity(double complexity) {
    if (complexity <= 2.0) return 4;
    if (complexity <= 3.0) return 5;
    if (complexity <= 4.0) return 6;
    if (complexity <= 5.5) return 7;
    if (complexity <= 7.0) return 8;
    return 9;
  }

  int gridSizeFromPieceTypes(int n) => n * (n + 1) ~/ 2;

  /// Total cells covered by pieces: piece i has count=i and area=i*i.
  int totalPieceCells(int n) {
    int sum = 0;
    for (int i = 1; i <= n; i++) {
      sum += i * i * i; // i copies × i×i area = i³
    }
    return sum;
  }

  group('Grid Filler mathematical properties', () {
    test('sum of i³ for i=1..N equals (N(N+1)/2)² for all valid N', () {
      for (int n = 4; n <= 9; n++) {
        final gridSize = gridSizeFromPieceTypes(n);
        final gridArea = gridSize * gridSize;
        final cells = totalPieceCells(n);
        expect(cells, gridArea,
            reason: 'N=$n: piece cells ($cells) must equal grid area ($gridArea)');
      }
    });

    test('grid sizes for each N', () {
      expect(gridSizeFromPieceTypes(4), 10);   // 10×10
      expect(gridSizeFromPieceTypes(5), 15);   // 15×15
      expect(gridSizeFromPieceTypes(6), 21);   // 21×21
      expect(gridSizeFromPieceTypes(7), 28);   // 28×28
      expect(gridSizeFromPieceTypes(8), 36);   // 36×36
      expect(gridSizeFromPieceTypes(9), 45);   // 45×45
    });
  });

  group('Grid Filler difficulty scaling', () {
    test('grade 1, level 1 → complexity 1.2, N=4, grid=10', () {
      final complexity = 1 + (1 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 4);
      expect(gridSizeFromPieceTypes(4), 10);
    });

    test('grade 2, level 5 → complexity 3.0, N=5, grid=15', () {
      final complexity = 2 + (5 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 5);
    });

    test('grade 3, level 5 → complexity 4.0, N=6, grid=21', () {
      final complexity = 3 + (5 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 6);
    });

    test('grade 3, level 10 → complexity 5.0, N=7, grid=28', () {
      final complexity = 3 + (10 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 7);
    });

    test('grade 4, level 10 → complexity 6.0, N=8, grid=36', () {
      final complexity = 4 + (10 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 8);
    });

    test('grade 4, level 20 → complexity 8.0, N=9, grid=45', () {
      final complexity = 4 + (20 / 5.0);
      expect(pieceTypesFromComplexity(complexity), 9);
      expect(gridSizeFromPieceTypes(9), 45);
    });

    test('complexity increases monotonically within a grade', () {
      for (int grade = 1; grade <= 4; grade++) {
        double prev = 0;
        for (int level = 1; level <= 20; level++) {
          final complexity = grade + (level / 5.0);
          expect(complexity > prev, isTrue,
              reason: 'grade=$grade level=$level should increase');
          prev = complexity;
        }
      }
    });

    test('higher grade at same level always gives >= complexity', () {
      for (int level = 1; level <= 20; level++) {
        for (int grade = 1; grade < 4; grade++) {
          final c1 = grade + (level / 5.0);
          final c2 = (grade + 1) + (level / 5.0);
          expect(c2 > c1, isTrue,
              reason: 'grade ${grade+1} should beat grade $grade at level $level');
        }
      }
    });

    test('piece types never decrease within a grade as level rises', () {
      for (int grade = 1; grade <= 4; grade++) {
        int prevN = 0;
        for (int level = 1; level <= 20; level++) {
          final complexity = grade + (level / 5.0);
          final n = pieceTypesFromComplexity(complexity);
          expect(n >= prevN, isTrue,
              reason: 'N should not decrease at grade=$grade level=$level');
          prevN = n;
        }
      }
    });
  });
}
