// lib/core/services/puzzle_dataset_service.dart
//
// Loads pre-generated puzzle datasets from remote URL or bundled assets.
// Used by CSP-heavy games (crosswords, codebreaker, etc.) to avoid
// expensive runtime generation.
//
// Architecture:
//   1. Try remote JSON (updatable without app rebuild)
//   2. Fall back to bundled asset (ships with app)
//   3. Fall back to live generation (slowest)
//
// Dataset format per game type:
//   { "puzzles": [ { "grade": 1, "level": 3, "ops": ["+"], "data": {...}, "rating": 5 } ] }

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A single pre-generated puzzle entry.
class PuzzleEntry {
  final int grade;
  final int level;
  final List<String> ops;
  final Map<String, dynamic> data;
  final int rating; // 0-5, higher = better quality (from evaluation)

  const PuzzleEntry({
    required this.grade,
    required this.level,
    required this.ops,
    required this.data,
    this.rating = 3,
  });

  factory PuzzleEntry.fromJson(Map<String, dynamic> json) => PuzzleEntry(
        grade: json['grade'] as int,
        level: json['level'] as int,
        ops: (json['ops'] as List).cast<String>(),
        data: json['data'] as Map<String, dynamic>,
        rating: json['rating'] as int? ?? 3,
      );

  Map<String, dynamic> toJson() => {
        'grade': grade,
        'level': level,
        'ops': ops,
        'data': data,
        'rating': rating,
      };
}

class PuzzleDatasetService {
  PuzzleDatasetService._();
  static final instance = PuzzleDatasetService._();

  /// Cached puzzles per game type.
  final Map<String, List<PuzzleEntry>> _cache = {};

  /// Base URL for remote datasets. Set to null to skip remote loading.
  /// Can be a GitHub raw URL, HF dataset, or any static host.
  static String? remoteBaseUrl;

  final _rng = Random();

  /// Load puzzles for a game type. Tries remote first, then bundled asset.
  Future<List<PuzzleEntry>> load(String gameType) async {
    if (_cache.containsKey(gameType)) return _cache[gameType]!;

    List<PuzzleEntry>? puzzles;

    // 1. Try remote
    if (remoteBaseUrl != null) {
      puzzles = await _loadRemote(gameType);
    }

    // 2. Try bundled asset
    puzzles ??= await _loadBundled(gameType);

    _cache[gameType] = puzzles ?? [];
    if (kDebugMode) {
      debugPrint('[PuzzleDataset] Loaded ${_cache[gameType]!.length} '
          'puzzles for $gameType');
    }
    return _cache[gameType]!;
  }

  /// Find a matching puzzle for the given parameters.
  /// Returns null if no match found (caller should fall back to live generation).
  Future<PuzzleEntry?> findPuzzle({
    required String gameType,
    required int grade,
    required int level,
    List<String>? requiredOps,
  }) async {
    final all = await load(gameType);
    if (all.isEmpty) return null;

    // Filter by grade (exact match required)
    var candidates = all.where((p) => p.grade == grade).toList();
    if (candidates.isEmpty) return null;

    // Filter by ops if specified
    if (requiredOps != null && requiredOps.isNotEmpty) {
      final opsSet = requiredOps.toSet();
      candidates = candidates
          .where((p) => p.ops.toSet().containsAll(opsSet))
          .toList();
      if (candidates.isEmpty) return null;
    }

    // Prefer puzzles close to the requested level
    candidates.sort((a, b) {
      final diffA = (a.level - level).abs();
      final diffB = (b.level - level).abs();
      if (diffA != diffB) return diffA.compareTo(diffB);
      // Tie-break by rating (higher is better)
      return b.rating.compareTo(a.rating);
    });

    // Pick randomly from the top 3 closest matches for variety
    final topN = candidates.take(3).toList();
    return topN[_rng.nextInt(topN.length)];
  }

  /// Clear the cache (e.g., after a remote update).
  void clearCache() => _cache.clear();

  /// Merge evaluation ratings into a dataset. Used to update puzzle quality
  /// scores from player evaluations collected via GridlockPuzzleTracker.
  /// Returns the updated dataset as a JSON string for committing to the repo.
  static String mergeEvaluations(
    String datasetJson,
    List<Map<String, dynamic>> evaluations,
  ) {
    final dataset = jsonDecode(datasetJson) as Map<String, dynamic>;
    final puzzles = (dataset['puzzles'] as List)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();

    // Build average ratings from evaluations
    final ratingsByPuzzle = <String, List<int>>{};
    for (final eval in evaluations) {
      final id = eval['puzzleId'] as String;
      final rating = eval['rating'] as int;
      ratingsByPuzzle.putIfAbsent(id, () => []).add(rating);
    }

    // Update puzzle ratings
    for (final puzzle in puzzles) {
      final data = puzzle['data'] as Map<String, dynamic>?;
      final id = data?['id'] as String?;
      if (id != null && ratingsByPuzzle.containsKey(id)) {
        final ratings = ratingsByPuzzle[id]!;
        puzzle['rating'] =
            (ratings.reduce((a, b) => a + b) / ratings.length).round();
      }
    }

    dataset['puzzles'] = puzzles;
    return const JsonEncoder.withIndent('  ').convert(dataset);
  }

  // ─── Private loaders ────────────────────────────────────────────────

  Future<List<PuzzleEntry>?> _loadRemote(String gameType) async {
    // Remote loading placeholder. To enable, implement platform-specific
    // HTTP fetch (e.g., package:http or dart:html for web).
    // For now, datasets are bundled as assets and updated via git push.
    if (kDebugMode) {
      debugPrint('[PuzzleDataset] Remote loading not yet implemented '
          'for $gameType, using bundled asset');
    }
    return null;
  }

  Future<List<PuzzleEntry>?> _loadBundled(String gameType) async {
    try {
      final json =
          await rootBundle.loadString('assets/puzzles/$gameType.json');
      return _parseDataset(json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PuzzleDataset] No bundled asset for $gameType');
      }
    }
    return null;
  }

  List<PuzzleEntry> _parseDataset(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final list = map['puzzles'] as List;
    return list
        .map((e) => PuzzleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
