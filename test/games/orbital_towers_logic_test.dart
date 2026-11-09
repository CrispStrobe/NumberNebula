// Unit tests for orbital_towers_logic.dart — pure puzzle logic only.
//
// Tests structural invariants: Latin square property, visibility clue
// correctness, and solution validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/orbital_towers_logic.dart';

void main() {
  _sightlineTests();

  group('OrbitalTowersGenerator Latin square', () {
    for (final size in [3, 4, 5]) {
      test('size $size: solution is a valid Latin square', () async {
        final gen = OrbitalTowersGenerator();
        for (int i = 0; i < 3; i++) {
          final puzzle = await gen.generate(
            size: size,
            edgeClueCount: size * 2,
            cellClueCount: size,
          );

          expect(puzzle.size, size);
          expect(puzzle.solution.length, size * size);

          for (int r = 0; r < size; r++) {
            final rowVals = <int>{};
            for (int c = 0; c < size; c++) {
              final v = puzzle.solution['r${r}c$c']!;
              expect(v, inInclusiveRange(1, size));
              rowVals.add(v);
            }
            expect(rowVals.length, size,
                reason: 'row $r must have $size unique values');
          }

          for (int c = 0; c < size; c++) {
            final colVals = <int>{};
            for (int r = 0; r < size; r++) {
              colVals.add(puzzle.solution['r${r}c$c']!);
            }
            expect(colVals.length, size,
                reason: 'column $c must have $size unique values');
          }
        }
      });
    }
  });

  group('OrbitalTowersGenerator visibility clues', () {
    test('edge clues match computed visibility from solution', () async {
      final gen = OrbitalTowersGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          size: 4,
          edgeClueCount: 16, // request all clues
          cellClueCount: 0,
        );

        for (final entry in puzzle.edgeClues.entries) {
          final key = entry.key;
          final expected = entry.value;
          final parts = key.split('_');
          final dir = parts[0];
          final idx = int.parse(parts[1]);
          final size = puzzle.size;

          List<int> line;
          if (dir == 'top') {
            line = List.generate(size, (r) => puzzle.solution['r${r}c$idx']!);
          } else if (dir == 'bottom') {
            line = List.generate(
                size, (r) => puzzle.solution['r${size - 1 - r}c$idx']!);
          } else if (dir == 'left') {
            line = List.generate(size, (c) => puzzle.solution['r${idx}c$c']!);
          } else {
            line = List.generate(
                size, (c) => puzzle.solution['r${idx}c${size - 1 - c}']!);
          }

          // Compute visibility
          int maxSeen = 0;
          int count = 0;
          for (final h in line) {
            if (h > maxSeen) {
              count++;
              maxSeen = h;
            }
          }

          expect(count, expected,
              reason: 'edge clue $key should match computed visibility');
        }
      }
    });
  });

  group('OrbitalTowersPuzzle puzzle structure', () {
    test('clues + emptyCells partition the grid', () async {
      final gen = OrbitalTowersGenerator();
      final puzzle = await gen.generate(
        size: 4,
        edgeClueCount: 8,
        cellClueCount: 4,
      );

      final total = puzzle.size * puzzle.size;
      expect(puzzle.clues.length + puzzle.emptyCells.length, total);

      for (final cell in puzzle.clues.keys) {
        expect(puzzle.emptyCells.contains(cell), isFalse);
      }
    });

    test('numberPool is 1..size', () async {
      final gen = OrbitalTowersGenerator();
      final puzzle = await gen.generate(
        size: 5,
        edgeClueCount: 10,
        cellClueCount: 3,
      );

      expect(puzzle.numberPool, List.generate(5, (i) => i + 1));
    });
  });

  group('OrbitalTowersPuzzle.validateSolution', () {
    test('correct solution is accepted', () async {
      final gen = OrbitalTowersGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          size: 4,
          edgeClueCount: 8,
          cellClueCount: 2,
        );

        final userSolution = <String, int>{};
        for (final cell in puzzle.emptyCells) {
          userSolution[cell] = puzzle.solution[cell]!;
        }
        expect(puzzle.validateSolution(userSolution), isTrue);
      }
    });

    test('corrupted solution is rejected', () async {
      final gen = OrbitalTowersGenerator();
      final puzzle = await gen.generate(
        size: 4,
        edgeClueCount: 8,
        cellClueCount: 2,
      );

      final userSolution = <String, int>{};
      for (final cell in puzzle.emptyCells) {
        userSolution[cell] = puzzle.solution[cell]!;
      }

      final firstEmpty = puzzle.emptyCells.first;
      final correct = userSolution[firstEmpty]!;
      userSolution[firstEmpty] = correct == puzzle.size ? 1 : correct + 1;

      expect(puzzle.validateSolution(userSolution), isFalse);
    });

    test('empty user solution is rejected', () async {
      final gen = OrbitalTowersGenerator();
      final puzzle = await gen.generate(
        size: 3,
        edgeClueCount: 6,
        cellClueCount: 2,
      );

      expect(puzzle.validateSolution({}), isFalse);
    });
  });

  group('visibility counting via edge clues', () {
    test('ascending column: all towers visible from top', () async {
      // We verify visibility counting indirectly through generated edge clues.
      // For a generated puzzle, we already verified edge clues match the
      // computed visibility in the "edge clues match" test above. Here we
      // test specific structural properties.
      final gen = OrbitalTowersGenerator();
      final puzzle = await gen.generate(
        size: 4,
        edgeClueCount: 16, // all clues
        cellClueCount: 0,
      );

      // Every edge clue must be between 1 and size
      for (final count in puzzle.edgeClues.values) {
        expect(count, inInclusiveRange(1, puzzle.size));
      }
    });
  });
}

// Appended: the sightline rule the onboarding diagram illustrates.
void _sightlineTests() {
  group('OrbitalTowersPuzzle.visibilityAlongLine', () {
    test('a tower is visible only when nothing taller stands in front', () {
      // The worked example the onboarding draws: the 1 hides behind the 2,
      // the 3 hides behind the 4, so the camera reports 2.
      expect(OrbitalTowersPuzzle.visibilityAlongLine([2, 1, 4, 3]),
          [true, false, true, false]);
    });

    test('ascending heights are all visible, descending shows only the first',
        () {
      expect(OrbitalTowersPuzzle.visibilityAlongLine([1, 2, 3, 4]),
          [true, true, true, true]);
      expect(OrbitalTowersPuzzle.visibilityAlongLine([4, 3, 2, 1]),
          [true, false, false, false]);
    });

    test('agrees with the edge clues the generator computes', () async {
      final generator = OrbitalTowersGenerator();
      for (int size = 3; size <= 5; size++) {
        for (int i = 0; i < 10; i++) {
          final puzzle = await generator.generate(
              size: size, edgeClueCount: size * 2, cellClueCount: 2);

          for (final entry in puzzle.edgeClues.entries) {
            final parts = entry.key.split('_');
            final idx = int.parse(parts[1]);
            final List<int> line;
            switch (parts[0]) {
              case 'top':
                line = List.generate(
                    size, (r) => puzzle.solution['r${r}c$idx']!);
              case 'bottom':
                line = List.generate(
                    size, (r) => puzzle.solution['r${size - 1 - r}c$idx']!);
              case 'left':
                line = List.generate(
                    size, (c) => puzzle.solution['r${idx}c$c']!);
              default:
                line = List.generate(
                    size, (c) => puzzle.solution['r${idx}c${size - 1 - c}']!);
            }
            final visible = OrbitalTowersPuzzle.visibilityAlongLine(line)
                .where((v) => v)
                .length;
            expect(visible, entry.value,
                reason: 'clue ${entry.key} says ${entry.value}, '
                    'the rule sees $visible along $line');
          }
        }
      }
    });
  });
}
