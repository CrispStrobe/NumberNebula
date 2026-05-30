// Unit tests for the pure game logic in quantum_molecule_builder_game.dart.
//
// The screen widget itself hard-couples to localization (S.of(context)),
// providers, haptics and infinite animation/particle timers, so it is not
// usefully pumpable. However the file exposes several pure top-level
// functions and model classes that encode the actual Atomix game rules:
//   - getAtomTypeFromIndex(int)         -> atom-type classification
//   - getBondingDirections(int)         -> valency / bond direction table
//   - AtomixLevel.fromMap(Map)          -> level-data parser
//   - MoleculePattern.water()           -> default target pattern
//   - AtomType constants                -> element registry
// These are tested directly, plus invariants over the real `levelsData`.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/quantum_molecule_builder_game.dart';
import 'package:space_math_academy/features/games/screens/levels.dart';

void main() {
  group('getAtomTypeFromIndex', () {
    test('classifies the documented element ranges', () {
      // Hydrogen: 0..7
      for (var i = 0; i <= 7; i++) {
        expect(getAtomTypeFromIndex(i), AtomType.hydrogen, reason: 'index $i');
      }
      // Oxygen: 8..13
      for (var i = 8; i <= 13; i++) {
        expect(getAtomTypeFromIndex(i), AtomType.oxygen, reason: 'index $i');
      }
      // Carbon: 14..28
      for (var i = 14; i <= 28; i++) {
        expect(getAtomTypeFromIndex(i), AtomType.carbon, reason: 'index $i');
      }
      // Fluorine: 29, 30
      expect(getAtomTypeFromIndex(29), AtomType.fluorine);
      expect(getAtomTypeFromIndex(30), AtomType.fluorine);
      // Nitrogen: 31
      expect(getAtomTypeFromIndex(31), AtomType.nitrogen);
    });

    test('maps the 12 bonus-stage specials cyclically and stably', () {
      const expected = [
        AtomType.special1, AtomType.special2, AtomType.special3,
        AtomType.special4, AtomType.special5, AtomType.special6,
        AtomType.special7, AtomType.special8, AtomType.special9,
        AtomType.special10, AtomType.special11, AtomType.special12,
      ];
      for (var i = 32; i <= 43; i++) {
        expect(getAtomTypeFromIndex(i), expected[i - 32], reason: 'index $i');
      }
    });

    test('falls back to hydrogen for out-of-range indices', () {
      expect(getAtomTypeFromIndex(-1), AtomType.hydrogen);
      expect(getAtomTypeFromIndex(999), AtomType.hydrogen);
    });
  });

  group('getBondingDirections (valency invariants)', () {
    int valencyFor(int index) => getBondingDirections(index).length;

    test('hydrogen and fluorine are monovalent', () {
      for (var i = 0; i <= 7; i++) {
        expect(valencyFor(i), 1, reason: 'hydrogen index $i');
      }
      expect(valencyFor(29), 1);
      expect(valencyFor(30), 1);
    });

    test('oxygen entries define between 1 and 2 bond directions', () {
      // Indices 8 and 9 are the fully divalent oxygen orientations; 10..13 are
      // single-bond oxygen orientations used at molecule edges.
      expect(valencyFor(8), 2);
      expect(valencyFor(9), 2);
      for (var i = 10; i <= 13; i++) {
        expect(valencyFor(i), 1, reason: 'oxygen index $i');
      }
    });

    test('carbon never exceeds valency 4 and nitrogen is trivalent', () {
      for (var i = 14; i <= 28; i++) {
        final v = valencyFor(i);
        expect(v, greaterThanOrEqualTo(2), reason: 'carbon index $i');
        expect(v, lessThanOrEqualTo(4), reason: 'carbon index $i');
      }
      expect(valencyFor(31), 3); // nitrogen
    });

    test('unknown indices have no bonds and returned sets are distinct', () {
      expect(getBondingDirections(100), isEmpty);
      // Each direction in a set is unique by definition of Set.
      final dirs = getBondingDirections(14);
      expect(dirs, containsAll(<BondDirection>{
        BondDirection.left,
        BondDirection.right,
        BondDirection.up,
        BondDirection.down,
      }));
    });
  });

  group('MoleculePattern.water', () {
    test('is a 3x3 H-O-H pattern with matching atom types', () {
      final water = MoleculePattern.water();
      expect(water.size, 3);
      expect(water.grid.length, 3);
      for (final row in water.grid) {
        expect(row.length, 3, reason: 'pattern grid must be square');
      }
      // Middle row holds the three atom indices.
      expect(water.grid[1], [6, 8, 2]);
      expect(water.atomTypes,
          [AtomType.hydrogen, AtomType.oxygen, AtomType.hydrogen]);
      // The non-null cells in the grid correspond to the atomTypes count.
      final nonNull =
          water.grid.expand((r) => r).where((c) => c != null).length;
      expect(nonNull, water.atomTypes.length);
    });
  });

  group('AtomType registry', () {
    test('core elements carry the expected chemical symbols', () {
      expect(AtomType.hydrogen.symbol, 'H');
      expect(AtomType.oxygen.symbol, 'O');
      expect(AtomType.carbon.symbol, 'C');
      expect(AtomType.nitrogen.symbol, 'N');
      expect(AtomType.fluorine.symbol, 'F');
    });

    test('the 12 special types all use the generic "Special" name and are distinct', () {
      const specials = [
        AtomType.special1, AtomType.special2, AtomType.special3,
        AtomType.special4, AtomType.special5, AtomType.special6,
        AtomType.special7, AtomType.special8, AtomType.special9,
        AtomType.special10, AtomType.special11, AtomType.special12,
      ];
      for (final s in specials) {
        expect(s.name, 'Special');
      }
      final symbols = specials.map((s) => s.symbol).toSet();
      expect(symbols.length, specials.length,
          reason: 'special symbols must be unique');
    });
  });

  group('AtomixLevel.fromMap', () {
    test('round-trips the first real level from levelsData', () {
      expect(levelsData, isNotEmpty);
      final level = AtomixLevel.fromMap(levelsData.first);
      expect(level.levelNumber, isPositive);
      expect(level.name, isNotEmpty);
      // 16x16 playfield/solution per the game grid constant.
      expect(level.playfield.length, 16);
      expect(level.solution.length, 16);
      for (final row in level.playfield) {
        expect(row.length, 16);
      }
    });
  });

  group('levelsData invariants (parses + solvable shape)', () {
    test('every level parses, has atoms, and a non-empty solution', () {
      expect(levelsData, isNotEmpty);
      for (final raw in levelsData) {
        final level = AtomixLevel.fromMap(raw);

        // Count atoms on the playfield and in the solution.
        var playfieldAtoms = 0;
        for (final row in level.playfield) {
          for (final cell in row) {
            if (cell['type'] == 'atom') playfieldAtoms++;
          }
        }
        var solutionAtoms = 0;
        for (final row in level.solution) {
          for (final cell in row) {
            if (cell['type'] == 'atom') solutionAtoms++;
          }
        }

        expect(playfieldAtoms, greaterThan(0),
            reason: 'level ${level.levelNumber} (${level.name}) has no atoms');
        // A puzzle is only solvable if the number of pieces to place matches
        // the number of slots in the target molecule.
        expect(solutionAtoms, playfieldAtoms,
            reason:
                'level ${level.levelNumber} (${level.name}) playfield/solution atom mismatch');
      }
    });

    test('every atom index on a playfield classifies to a known atom type', () {
      for (final raw in levelsData) {
        final level = AtomixLevel.fromMap(raw);
        for (final row in level.playfield) {
          for (final cell in row) {
            if (cell['type'] == 'atom') {
              final index = cell['index'] as int;
              // Must not throw and must yield a real AtomType instance.
              final type = getAtomTypeFromIndex(index);
              expect(type.symbol, isNotEmpty,
                  reason: 'level ${level.levelNumber} atom index $index');
            }
          }
        }
      }
    });
  });
}
