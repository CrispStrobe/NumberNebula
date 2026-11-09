import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/kompass_content.dart';

/// Bundled, offline content. A failed load is retryable, not cached forever.
class KompassRepository {
  static const assetPath = 'assets/kompass/math_v2.json';

  /// The six original kompass4 practice papers, converted by
  /// `tool/kompass/import_kompass4_math.py`. Their tasks use `original` and are
  /// never drawn into practice, check or rehearsal selections.
  static const originalAssetPath = 'assets/kompass/kompass4/math_original.json';
  static KompassPack? _loaded;

  static Future<KompassPack> load({AssetBundle? bundle}) async {
    if (bundle == null && _loaded != null) return _loaded!;
    final source = bundle ?? rootBundle;
    final main = kompassMap(jsonDecode(await source.loadString(assetPath)));
    Map<String, dynamic>? original;
    try {
      original =
          kompassMap(jsonDecode(await source.loadString(originalAssetPath)));
    } on FlutterError {
      // Only a missing asset is tolerated (e.g. a reduced test bundle);
      // malformed content still fails below.
      original = null;
    }
    final pack = fromJson(merge(main, original));
    if (bundle == null) _loaded = pack;
    return pack;
  }

  /// Appends the original papers to the main package. The combined version
  /// names both inputs, so saved attempts stay tied to the exact content.
  static Map<String, dynamic> merge(
      Map<String, dynamic> main, Map<String, dynamic>? original) {
    if (original == null) return main;
    if (original['schemaVersion'] != 1 ||
        original['id'] != 'kompass4_math_original') {
      throw const FormatException('Unsupported original paper package.');
    }
    final mainTasks = main['tasks'] as List;
    return {
      ...main,
      'version': '${main['version']}+k4.${original['version']}',
      // The main tasks are byte-identical objects, so records saved against
      // the main package alone (or its compatible predecessors) stay usable.
      'compatibleTaskIds': {
        ...?(main['compatibleTaskIds'] as Map?)?.cast<String, dynamic>(),
        main['version'] as String: [
          for (final task in mainTasks) (task as Map)['id'] as String
        ],
      },
      'tasks': [...main['tasks'] as List, ...original['tasks'] as List],
      'papers': original['papers'],
      'originalSource': original['source'],
    };
  }

  static KompassPack fromJson(Map<String, dynamic> json) =>
      KompassPack.fromJson(json);
}
