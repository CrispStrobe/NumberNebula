// Unit tests for hive_station_logic.dart — pure puzzle logic only.
//
// Tests hex grid generation, adjacency count correctness, and solution
// validation for the hexagonal minesweeper variant.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/hive_station_logic.dart';

void main() {
  group('HexCoord', () {
    test('equality and hashCode', () {
      const a = HexCoord(1, 2);
      const b = HexCoord(1, 2);
      const c = HexCoord(2, 1);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('neighbors returns exactly 6 adjacent coords', () {
      const cell = HexCoord(0, 0);
      final neighbors = cell.neighbors;

      expect(neighbors.length, 6);
      expect(neighbors, contains(const HexCoord(1, 0)));
      expect(neighbors, contains(const HexCoord(-1, 0)));
      expect(neighbors, contains(const HexCoord(0, 1)));
      expect(neighbors, contains(const HexCoord(0, -1)));
      expect(neighbors, contains(const HexCoord(1, -1)));
      expect(neighbors, contains(const HexCoord(-1, 1)));
    });
  });

  group('HiveStationGenerator grid structure', () {
    test('radius 1 produces 7 cells', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 1,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      expect(puzzle.radius, 1);
      expect(puzzle.allCells.length, 7);
    });

    test('radius 2 produces 19 cells', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      expect(puzzle.allCells.length, 19);
    });

    test('radius 3 produces 37 cells', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 3,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      expect(puzzle.allCells.length, 37);
    });
  });

  group('HiveStationGenerator adjacency counts', () {
    test('number hints accurately count adjacent energy cells', () async {
      final gen = HiveStationGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          radius: 2,
          energyFraction: 0.3,
          hintFraction: 1.0,
        );

        // Verify every number hint
        for (final entry in puzzle.numberHints.entries) {
          final cell = entry.key;
          final hint = entry.value;

          // Cell should NOT be an energy cell
          expect(puzzle.energyCells.contains(cell), isFalse,
              reason: 'hint cell $cell must not be an energy cell');

          // Manually count adjacent energy cells
          int count = 0;
          for (final n in cell.neighbors) {
            if (puzzle.energyCells.contains(n)) count++;
          }
          expect(hint, count,
              reason: 'hint at $cell should match adjacent energy count');
        }
      }
    });

    test('energy cells are not in numberHints', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 1.0,
      );

      for (final ec in puzzle.energyCells) {
        expect(puzzle.numberHints.containsKey(ec), isFalse);
      }
    });

    test('energy cells are a subset of allCells', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      for (final ec in puzzle.energyCells) {
        expect(puzzle.allCells.contains(ec), isTrue);
      }
    });
  });

  group('HiveStationPuzzle.validateSolution', () {
    test('correct solution is accepted', () async {
      final gen = HiveStationGenerator();
      for (int i = 0; i < 5; i++) {
        final puzzle = await gen.generate(
          radius: 2,
          energyFraction: 0.3,
          hintFraction: 0.5,
        );

        expect(puzzle.validateSolution(puzzle.energyCells), isTrue);
      }
    });

    test('wrong marking is rejected', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      // Mark a non-energy cell instead
      final nonEnergy = puzzle.allCells
          .where((c) => !puzzle.energyCells.contains(c))
          .toSet();
      if (nonEnergy.isNotEmpty) {
        final wrongMarked = Set<HexCoord>.from(puzzle.energyCells);
        wrongMarked.remove(wrongMarked.first);
        wrongMarked.add(nonEnergy.first);
        expect(puzzle.validateSolution(wrongMarked), isFalse);
      }
    });

    test('empty marking is rejected', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      expect(puzzle.validateSolution(<HexCoord>{}), isFalse);
    });

    test('too many markings rejected', () async {
      final gen = HiveStationGenerator();
      final puzzle = await gen.generate(
        radius: 2,
        energyFraction: 0.3,
        hintFraction: 0.5,
      );

      final tooMany = Set<HexCoord>.from(puzzle.energyCells);
      tooMany.add(const HexCoord(99, 99)); // extra cell
      expect(puzzle.validateSolution(tooMany), isFalse);
    });
  });
}
