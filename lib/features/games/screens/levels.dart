import '../services/molecule_level_data.dart';
export '../services/molecule_level_data.dart';
/// Level data for the Quantum Molecule Builder (Atomiks) game.
///
/// The 30 levels live in assets/data/molecule_levels.json with each
/// playfield/solution cell stored as a `[type, index]` pair; [loadMoleculeLevels]
/// expands them back into the `{'type': …, 'index': …}` maps
/// AtomixLevel.fromMap reads. This used to be a 474 KB Dart literal compiled
/// into the game.


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
