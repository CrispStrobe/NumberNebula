import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/kompass_content.dart';

/// Bundled, offline content. A failed load is retryable, not cached forever.
class KompassRepository {
  static const assetPath = 'assets/kompass/math_v2.json';
  static KompassPack? _loaded;

  static Future<KompassPack> load({AssetBundle? bundle}) async {
    if (bundle == null && _loaded != null) return _loaded!;
    final text = await (bundle ?? rootBundle).loadString(assetPath);
    final pack = fromJson(kompassMap(jsonDecode(text)));
    if (bundle == null) _loaded = pack;
    return pack;
  }

  static KompassPack fromJson(Map<String, dynamic> json) =>
      KompassPack.fromJson(json);
}
