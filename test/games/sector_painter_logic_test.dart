// Unit tests for sector_painter_logic.dart.
//
// Tests the graph coloring puzzle logic: validation of proper coloring,
// color counting, adjacency structure, and generated puzzle invariants.
// The generator uses an unseeded Random, so we assert structural invariants
// over multiple seeded generations.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/sector_painter_logic.dart';

void main() {
  group('SectorPainterPuzzle.validateColoring', () {
    test('valid coloring passes', () {
      // Triangle graph: 0-1, 1-2, 2-0
      final puzzle = SectorPainterPuzzle(
        regions: [0, 1, 2],
        adjacency: {
          0: {1, 2},
          1: {0, 2},
          2: {0, 1},
        },
        chromaticNumber: 3,
        availableColors: 3,
        positions: [],
      );
      expect(puzzle.validateColoring({0: 0, 1: 1, 2: 2}), isTrue);
    });

    test('invalid coloring (adjacent same color) fails', () {
      final puzzle = SectorPainterPuzzle(
        regions: [0, 1, 2],
        adjacency: {
          0: {1, 2},
          1: {0, 2},
          2: {0, 1},
        },
        chromaticNumber: 3,
        availableColors: 3,
        positions: [],
      );
      expect(puzzle.validateColoring({0: 0, 1: 0, 2: 1}), isFalse);
    });

    test('incomplete coloring (missing region) fails', () {
      final puzzle = SectorPainterPuzzle(
        regions: [0, 1, 2],
        adjacency: {
          0: {1},
          1: {0},
          2: <int>{},
        },
        chromaticNumber: 2,
        availableColors: 2,
        positions: [],
      );
      // Missing region 2
      expect(puzzle.validateColoring({0: 0, 1: 1}), isFalse);
    });

    test('graph with no edges: any coloring is valid', () {
      final puzzle = SectorPainterPuzzle(
        regions: [0, 1, 2],
        adjacency: {
          0: <int>{},
          1: <int>{},
          2: <int>{},
        },
        chromaticNumber: 1,
        availableColors: 1,
        positions: [],
      );
      // All same color is fine since no adjacency
      expect(puzzle.validateColoring({0: 0, 1: 0, 2: 0}), isTrue);
    });
  });

  group('SectorPainterPuzzle.countColors', () {
    test('counts distinct colors used', () {
      final puzzle = SectorPainterPuzzle(
        regions: [0, 1, 2, 3],
        adjacency: {},
        chromaticNumber: 2,
        availableColors: 4,
        positions: [],
      );
      expect(puzzle.countColors({0: 0, 1: 1, 2: 0, 3: 1}), 2);
      expect(puzzle.countColors({0: 0, 1: 1, 2: 2, 3: 3}), 4);
      expect(puzzle.countColors({0: 5, 1: 5, 2: 5, 3: 5}), 1);
    });
  });

  group('SectorPainterGenerator.generate (invariants)', () {
    final gradeLevelPairs = <List<int>>[
      [1, 1], // grade 1: 4 regions, 3 colors
      [2, 1], // grade 2: 5 regions
      [3, 1], // grade 3: 7 regions
      [4, 1], // grade 4: 9+ regions
    ];

    for (final pair in gradeLevelPairs) {
      final grade = pair[0];
      final level = pair[1];

      test('grade=$grade level=$level: adjacency is symmetric', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = SectorPainterGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (final region in puzzle.regions) {
            for (final neighbor in puzzle.adjacency[region] ?? <int>{}) {
              expect(
                puzzle.adjacency[neighbor]?.contains(region),
                isTrue,
                reason:
                    'adjacency must be symmetric: $region->$neighbor but not reverse',
              );
            }
          }
        }
      });

      test('grade=$grade level=$level: no self-loops in adjacency', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = SectorPainterGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          for (final region in puzzle.regions) {
            expect(
              puzzle.adjacency[region]?.contains(region),
              isFalse,
              reason: 'region $region should not be adjacent to itself',
            );
          }
        }
      });

      test('grade=$grade level=$level: graph is connected (circular construction)',
          () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = SectorPainterGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          // BFS to check connectivity
          final visited = <int>{};
          final queue = [puzzle.regions.first];
          visited.add(puzzle.regions.first);
          while (queue.isNotEmpty) {
            final node = queue.removeAt(0);
            for (final neighbor in puzzle.adjacency[node] ?? <int>{}) {
              if (!visited.contains(neighbor)) {
                visited.add(neighbor);
                queue.add(neighbor);
              }
            }
          }
          expect(visited.length, puzzle.regions.length,
              reason: 'graph should be connected');
        }
      });

      test('grade=$grade level=$level: chromatic number is positive and consistent', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = SectorPainterGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          expect(puzzle.chromaticNumber, greaterThan(0));
          // The chromatic number should not exceed the region count
          expect(puzzle.chromaticNumber,
              lessThanOrEqualTo(puzzle.regions.length),
              reason:
                  'chromatic number cannot exceed total region count');
          // Available colors should be positive
          expect(puzzle.availableColors, greaterThan(0));
        }
      });

      test('grade=$grade level=$level: greedy coloring validates successfully', () {
        for (int seed = 0; seed < 3; seed++) {
          final gen = SectorPainterGenerator(seed: seed);
          final puzzle = gen.generate(grade: grade, level: level);

          // Build a greedy coloring and verify it
          final coloring = <int, int>{};
          for (final region in puzzle.regions) {
            final neighborColors = <int>{};
            for (final neighbor in puzzle.adjacency[region] ?? <int>{}) {
              if (coloring.containsKey(neighbor)) {
                neighborColors.add(coloring[neighbor]!);
              }
            }
            int color = 0;
            while (neighborColors.contains(color)) {
              color++;
            }
            coloring[region] = color;
          }
          expect(puzzle.validateColoring(coloring), isTrue,
              reason: 'greedy coloring must produce a valid coloring');
        }
      });
    }

    test('region count scales with grade', () {
      final gen = SectorPainterGenerator(seed: 42);
      final p1 = gen.generate(grade: 1, level: 1);
      final gen2 = SectorPainterGenerator(seed: 42);
      final p4 = gen2.generate(grade: 4, level: 1);

      expect(p4.regions.length, greaterThanOrEqualTo(p1.regions.length),
          reason: 'higher grade should have more regions');
    });

    test('positions list matches region count', () {
      final gen = SectorPainterGenerator(seed: 42);
      final puzzle = gen.generate(grade: 3, level: 5);
      expect(puzzle.positions.length, puzzle.regions.length);
    });
  });
}
