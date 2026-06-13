// lib/core/services/puzzle_image_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PuzzleImageService {
  static final PuzzleImageService instance = PuzzleImageService._internal();
  factory PuzzleImageService() => instance;
  PuzzleImageService._internal();

  List<String> _puzzleImagePaths = [];

  Future<void> init() async {
    if (kDebugMode) debugPrint("[PuzzleImageService] Initializing...");
    
    try {
      // Try multiple ways to load the manifest as it varies by Flutter version
      String manifestContent = "";
      try {
        manifestContent = await rootBundle.loadString('AssetManifest.json');
      } catch (_) {
        try {
          manifestContent = await rootBundle.loadString('AssetManifest.bin.json');
        } catch (_) {}
      }

      if (manifestContent.isNotEmpty) {
        final Map<String, dynamic> manifestMap = json.decode(manifestContent);
        if (kDebugMode) debugPrint("[PuzzleImageService] Asset manifest loaded successfully.");

        final allAssetKeys = manifestMap.keys.toList();
        final puzzleRegex = RegExp(r'assets/images/puzzle\d+\.(png|jpg|jpeg|webp)$', caseSensitive: false);
        
        _puzzleImagePaths = allAssetKeys
            .where(puzzleRegex.hasMatch)
            .toList();
            
        if (kDebugMode) debugPrint("[PuzzleImageService] Found ${_puzzleImagePaths.length} puzzle images after filtering.");
      }
    } catch (e) {
      debugPrint("[PuzzleImageService] Error parsing asset manifest: $e");
    }

    // ALWAYS check if we found images, and use fallback if not (regardless of exceptions above)
    if (_puzzleImagePaths.isEmpty) {
      if (kDebugMode) debugPrint("[PuzzleImageService] WARNING: No puzzle images found in manifest. Using hardcoded fallback.");
      _puzzleImagePaths = [
        'assets/images/puzzle01.png',
        'assets/images/puzzle02.jpg',
        'assets/images/puzzle03.jpg',
        'assets/images/puzzle04.jpg',
        'assets/images/puzzle05.jpg',
        'assets/images/puzzle06.jpg',
        'assets/images/puzzle07.jpg',
      ];
    }
    
    _puzzleImagePaths.sort();
    if (kDebugMode) debugPrint("[PuzzleImageService] Sorted image paths: $_puzzleImagePaths");
  }

  String? getImageForLevel(int level) {
    if (_puzzleImagePaths.isEmpty) {
      if (kDebugMode) debugPrint("[PuzzleImageService] No images available to serve for level $level.");
      return null;
    }
    
    final index = (level - 1) % _puzzleImagePaths.length;
    final imagePath = _puzzleImagePaths[index];
    if (kDebugMode) debugPrint("[PuzzleImageService] Serving image '$imagePath' for level $level.");
    return imagePath;
  }
}