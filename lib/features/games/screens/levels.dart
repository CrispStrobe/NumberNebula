/// Level data for the Quantum Molecule Builder (Atomiks) game.
///
/// The 30 levels live in assets/data/molecule_levels.json with each
/// playfield/solution cell stored as a `[type, index]` pair; [loadMoleculeLevels]
/// expands them back into the `{'type': …, 'index': …}` maps
/// AtomixLevel.fromMap reads. This used to be a 474 KB Dart literal compiled
/// into the game.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

const String moleculeLevelsAsset = 'assets/data/molecule_levels.json';

/// All levels, in order. Empty until [loadMoleculeLevels] completes.
List<Map<String, dynamic>> get levelsData => _levels;
List<Map<String, dynamic>> _levels = const [];

Future<List<Map<String, dynamic>>>? _loading;

/// Loads the bundled levels once; later calls return the same list.
Future<List<Map<String, dynamic>>> loadMoleculeLevels({AssetBundle? bundle}) {
  return _loading ??= (bundle ?? rootBundle)
      .loadString(moleculeLevelsAsset)
      .then((source) => _levels = parseMoleculeLevels(source))
      .catchError((Object e) {
    _loading = null;
    throw e;
  });
}

/// Parses the asset format into the map shape AtomixLevel.fromMap expects.
List<Map<String, dynamic>> parseMoleculeLevels(String source) {
  final levels = (jsonDecode(source) as Map<String, dynamic>)['levels'] as List;
  List<List<Map<String, dynamic>>> grid(List rows) => [
        for (final row in rows.cast<List>())
          [
            for (final cell in row.cast<List>())
              {'type': cell[0] as String, 'index': cell[1] as int},
          ],
      ];
  return [
    for (final level in levels.cast<Map<String, dynamic>>())
      {
        ...level,
        'playfield': grid(level['playfield'] as List),
        'solution': grid(level['solution'] as List),
      },
  ];
}
