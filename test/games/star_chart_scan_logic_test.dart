// Unit tests for star_chart_scan_logic.dart.
//
// The StarChartScanPuzzle.generate() method is a pure function that accepts
// an optional seed, making tests reproducible. We test structural invariants:
// words placed in grid, no out-of-bounds, mystery letter exists, grid fully
// filled.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_chart_scan_logic.dart';

void main() {
  group('StarChartScanPuzzle: word placement invariants', () {
    final wordPool = [
      'STAR', 'MOON', 'SUN', 'ORBIT', 'COMET', 'MARS', 'VENUS',
      'NOVA', 'NEBULA', 'ROCKET', 'PLANET', 'SATURN',
    ];

    test('all placed words appear in the grid (cardinal only)', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 10,
          wordCount: 5,
          allowDiagonal: false,
          seed: seed,
        );

        for (final pw in puzzle.placedWords) {
          // Verify each letter of the word is in the grid at the expected cell
          for (int i = 0; i < pw.word.length; i++) {
            final (r, c) = pw.cells[i];
            expect(puzzle.grid[r][c], pw.word[i],
                reason:
                    'Word "${pw.word}" letter $i should be at ($r,$c)');
          }
        }
      }
    });

    test('all placed words appear in the grid (with diagonals)', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 10,
          wordCount: 6,
          allowDiagonal: true,
          seed: seed,
        );

        for (final pw in puzzle.placedWords) {
          for (int i = 0; i < pw.word.length; i++) {
            final (r, c) = pw.cells[i];
            expect(puzzle.grid[r][c], pw.word[i]);
          }
        }
      }
    });
  });

  group('StarChartScanPuzzle: grid bounds', () {
    final wordPool = ['STAR', 'MOON', 'COMET', 'ORBIT', 'NOVA', 'SUN'];

    test('no word cell extends beyond grid bounds', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 8,
          wordCount: 4,
          allowDiagonal: true,
          seed: seed,
        );

        for (final pw in puzzle.placedWords) {
          for (final (r, c) in pw.cells) {
            expect(r, inInclusiveRange(0, puzzle.gridSize - 1),
                reason: 'Row $r out of bounds for gridSize=${puzzle.gridSize}');
            expect(c, inInclusiveRange(0, puzzle.gridSize - 1),
                reason: 'Col $c out of bounds for gridSize=${puzzle.gridSize}');
          }
        }
      }
    });

    test('grid is exactly gridSize x gridSize', () {
      final puzzle = StarChartScanPuzzle.generate(
        wordPool: wordPool,
        gridSize: 10,
        wordCount: 3,
        allowDiagonal: false,
        seed: 42,
      );

      expect(puzzle.grid.length, puzzle.gridSize);
      for (final row in puzzle.grid) {
        expect(row.length, puzzle.gridSize);
      }
    });
  });

  group('StarChartScanPuzzle: mystery letter', () {
    final wordPool = ['STAR', 'MOON', 'COMET', 'ORBIT', 'NOVA'];

    test('mystery letter is a single uppercase letter', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 8,
          wordCount: 3,
          allowDiagonal: false,
          seed: seed,
        );

        expect(puzzle.mysteryLetter.length, 1);
        expect(puzzle.mysteryLetter.codeUnitAt(0), inInclusiveRange(65, 90));
      }
    });

    test('mystery letter appears at least once in the grid', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 8,
          wordCount: 3,
          allowDiagonal: false,
          seed: seed,
        );

        bool found = false;
        for (final row in puzzle.grid) {
          for (final cell in row) {
            if (cell == puzzle.mysteryLetter) {
              found = true;
              break;
            }
          }
          if (found) break;
        }
        expect(found, isTrue,
            reason: 'Mystery letter "${puzzle.mysteryLetter}" must be in grid');
      }
    });
  });

  group('StarChartScanPuzzle: grid completeness', () {
    final wordPool = ['STAR', 'MOON', 'COMET', 'ORBIT', 'NOVA'];

    test('every cell is filled (no empty strings)', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 8,
          wordCount: 3,
          allowDiagonal: false,
          seed: seed,
        );

        for (int r = 0; r < puzzle.gridSize; r++) {
          for (int c = 0; c < puzzle.gridSize; c++) {
            expect(puzzle.grid[r][c].isNotEmpty, isTrue,
                reason: 'Cell ($r,$c) must not be empty');
          }
        }
      }
    });
  });

  group('StarChartScanPuzzle: wordsToFind matches placedWords', () {
    final wordPool = ['STAR', 'MOON', 'COMET', 'ORBIT', 'NOVA', 'SUN'];

    test('wordsToFind list matches placed word strings', () {
      final puzzle = StarChartScanPuzzle.generate(
        wordPool: wordPool,
        gridSize: 10,
        wordCount: 4,
        allowDiagonal: false,
        seed: 7,
      );

      expect(puzzle.wordsToFind.length, puzzle.placedWords.length);
      for (int i = 0; i < puzzle.wordsToFind.length; i++) {
        expect(puzzle.wordsToFind[i], puzzle.placedWords[i].word);
      }
    });
  });

  group('StarChartScanPuzzle: words too long for grid are skipped', () {
    test('a word longer than gridSize is never placed', () {
      final puzzle = StarChartScanPuzzle.generate(
        wordPool: ['AB', 'ABCDEFGHIJK'], // 11-letter word in size-5 grid
        gridSize: 5,
        wordCount: 2,
        allowDiagonal: false,
        seed: 0,
      );

      for (final pw in puzzle.placedWords) {
        expect(pw.word.length, lessThanOrEqualTo(puzzle.gridSize));
      }
    });
  });

  group('StarChartScanPuzzle: PlacedWord cell count matches word length', () {
    final wordPool = ['STAR', 'MOON', 'COMET', 'ORBIT', 'NOVA'];

    test('each placed word has cells.length == word.length', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = StarChartScanPuzzle.generate(
          wordPool: wordPool,
          gridSize: 10,
          wordCount: 4,
          allowDiagonal: true,
          seed: seed,
        );

        for (final pw in puzzle.placedWords) {
          expect(pw.cells.length, pw.word.length);
        }
      }
    });
  });
}
