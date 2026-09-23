// ignore_for_file: avoid_print
// tool/puzzle_merge.dart
//
// Unified puzzle dataset merge tool.
// Merges newly generated puzzles into existing JSON datasets.
// Supports all game types. Deduplicates by puzzle ID.
//
// Usage:
//   dart run tool/puzzle_merge.dart <game_type> <new_puzzles.json>
//
// Example:
//   dart run tool/puzzle_merge.dart gridlock /tmp/new_gridlock.json
//
// The tool reads the existing dataset from assets/puzzles/<game_type>.json,
// merges in the new puzzles, deduplicates, and writes back.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isNotEmpty && args[0] == '--convert-gridlock') {
    _convertGridlockDartToJson();
    return;
  }

  if (args.length >= 2 && args[0] == '--merge-starloader') {
    _mergeStarLoader(args[1]);
    return;
  }

  if (args.length < 2) {
    print('Usage:');
    print('  dart run tool/puzzle_merge.dart <game_type> <new_puzzles.json>');
    print('  dart run tool/puzzle_merge.dart --merge-starloader <local_db.json>');
    print('  dart run tool/puzzle_merge.dart --convert-gridlock');
    print('\nStar Loader merge workflow:');
    print('  1. Play levels in debug mode on VPS, rate them');
    print('  2. Copy local DB: ~/Documents/starloader_db.json');
    print('  3. dart run tool/puzzle_merge.dart --merge-starloader ~/Documents/starloader_db.json');
    print('  4. git commit + push => Vercel deploys updated levels');
    print('\nGeneric merge (other CSP games):');
    print('  dart run tool/puzzle_merge.dart arithmancer_crosswords /tmp/new.json');
    exit(1);
  }

  final gameType = args[0];
  final newFile = args[1];
  _mergePuzzles(gameType, newFile);
}

void _mergePuzzles(String gameType, String newFilePath) {
  final datasetPath = 'assets/puzzles/$gameType.json';

  // Load existing dataset
  Map<String, dynamic> existing;
  final datasetFile = File(datasetPath);
  if (datasetFile.existsSync()) {
    existing = jsonDecode(datasetFile.readAsStringSync()) as Map<String, dynamic>;
  } else {
    existing = {'puzzles': [], 'meta': {'gameType': gameType, 'version': 1}};
  }

  final existingPuzzles = (existing['puzzles'] as List).cast<Map<String, dynamic>>();
  final existingIds = existingPuzzles.map((p) => p['id'] as String).toSet();

  print('Existing: ${existingPuzzles.length} puzzles');

  // Load new puzzles
  final newJson = File(newFilePath).readAsStringSync();
  final newData = jsonDecode(newJson);
  final List<dynamic> newPuzzles;
  if (newData is Map && newData.containsKey('puzzles')) {
    newPuzzles = newData['puzzles'] as List;
  } else if (newData is List) {
    newPuzzles = newData;
  } else {
    print('Error: new file must contain {"puzzles": [...]} or a bare list');
    exit(1);
  }

  print('New:      ${newPuzzles.length} puzzles');

  // Merge with dedup
  int added = 0;
  int skipped = 0;
  for (final puzzle in newPuzzles) {
    final p = puzzle as Map<String, dynamic>;
    final id = p['id'] as String?;
    if (id != null && existingIds.contains(id)) {
      skipped++;
      continue;
    }
    existingPuzzles.add(p);
    if (id != null) existingIds.add(id);
    added++;
  }

  // Optionally merge evaluations
  if (newData is Map && newData.containsKey('evaluations')) {
    final evals = newData['evaluations'] as List;
    _applyEvaluations(existingPuzzles, evals.cast<Map<String, dynamic>>());
    print('Applied ${evals.length} evaluations');
  }

  // Sort by complexity/grade for readability
  existingPuzzles.sort((a, b) {
    final ca = (a['complexity'] ?? a['grade'] ?? 0) as num;
    final cb = (b['complexity'] ?? b['grade'] ?? 0) as num;
    return ca.compareTo(cb);
  });

  // Update metadata
  existing['puzzles'] = existingPuzzles;
  existing['meta'] = {
    'gameType': gameType,
    'version': (existing['meta']?['version'] ?? 0) + 1,
    'totalPuzzles': existingPuzzles.length,
    'lastUpdated': DateTime.now().toIso8601String(),
  };

  // Write back
  final output = const JsonEncoder.withIndent('  ').convert(existing);
  datasetFile.writeAsStringSync(output);

  print('Added:    $added new, $skipped duplicates skipped');
  print('Total:    ${existingPuzzles.length} puzzles');
  print('Written:  $datasetPath (${(output.length / 1024).toStringAsFixed(1)} KB)');
}

/// Apply evaluation ratings to puzzles by matching puzzle IDs.
void _applyEvaluations(
    List<Map<String, dynamic>> puzzles, List<Map<String, dynamic>> evals) {
  final ratingsByPuzzle = <String, List<int>>{};
  for (final eval in evals) {
    final id = eval['puzzleId'] as String;
    final rating = eval['rating'] as int;
    ratingsByPuzzle.putIfAbsent(id, () => []).add(rating);
  }

  for (final puzzle in puzzles) {
    final id = puzzle['id'] as String?;
    if (id != null && ratingsByPuzzle.containsKey(id)) {
      final ratings = ratingsByPuzzle[id]!;
      puzzle['rating'] =
          (ratings.reduce((a, b) => a + b) / ratings.length).round();
    }
  }
}

/// Merge Star Loader (Frachtlader) puzzle databases.
/// Takes a local DB file (with ratings from debug play) and merges it into
/// the bundled asset, keeping well-rated and unrated puzzles.
///
/// Usage: dart run tool/puzzle_merge.dart --merge-starloader <local_db.json>
///
/// The local DB is the file from getApplicationDocumentsDirectory/starloader_db.json
/// on the VPS after debug play sessions. It contains levels with ratings.
void _mergeStarLoader(String localDbPath) {
  print('Merging Star Loader puzzle databases...');

  // Load the master DB
  final masterFile = File('lib/features/games/data/starloader_master_db.json');
  Map<String, dynamic> masterData;
  if (masterFile.existsSync()) {
    masterData = jsonDecode(masterFile.readAsStringSync()) as Map<String, dynamic>;
  } else {
    masterData = {'levels': []};
  }
  final masterLevels = (masterData['levels'] as List).cast<Map<String, dynamic>>();
  print('Master DB: ${masterLevels.length} levels');

  // Load the local DB (with ratings)
  final localFile = File(localDbPath);
  if (!localFile.existsSync()) {
    print('Error: local DB file not found: $localDbPath');
    exit(1);
  }
  final localData = jsonDecode(localFile.readAsStringSync()) as Map<String, dynamic>;
  final localLevels = (localData['levels'] as List).cast<Map<String, dynamic>>();
  print('Local DB:  ${localLevels.length} levels');

  // Build content hash index from master
  final masterHashes = <String, int>{};
  for (int i = 0; i < masterLevels.length; i++) {
    final hash = _contentHash(masterLevels[i]);
    masterHashes[hash] = i;
  }

  // Merge: add new levels, update ratings on existing ones
  int added = 0;
  int updated = 0;
  for (final local in localLevels) {
    final hash = _contentHash(local);
    if (masterHashes.containsKey(hash)) {
      // Update rating if local has one
      final localRating = local['avgRating'] as num? ?? 0;
      final localCount = local['ratingCount'] as int? ?? 0;
      if (localCount > 0) {
        final idx = masterHashes[hash]!;
        final master = masterLevels[idx];
        final masterCount = master['ratingCount'] as int? ?? 0;
        final masterRating = master['avgRating'] as num? ?? 0;
        // Weighted average merge
        final totalCount = masterCount + localCount;
        final merged = (masterRating * masterCount + localRating * localCount) / totalCount;
        masterLevels[idx]['avgRating'] = double.parse(merged.toStringAsFixed(2));
        masterLevels[idx]['ratingCount'] = totalCount;
        updated++;
      }
    } else {
      // New level — add to master
      masterLevels.add(local);
      masterHashes[hash] = masterLevels.length - 1;
      added++;
    }
  }

  // Save updated master DB
  masterData['levels'] = masterLevels;
  final masterOutput = const JsonEncoder.withIndent('  ').convert(masterData);
  masterFile.writeAsStringSync(masterOutput);

  // Generate filtered bundled asset: only unrated OR rating >= 3
  final bundledLevels = masterLevels.where((l) {
    final count = l['ratingCount'] as int? ?? 0;
    final rating = l['avgRating'] as num? ?? 0;
    return count == 0 || rating >= 3;
  }).toList();

  // Compact: the bundled file ships inside the app.
  final bundledOutput = jsonEncode({
    'levels': bundledLevels,
  });
  final bundledFile = File('assets/data/starloader_levels.json');
  bundledFile.writeAsStringSync(bundledOutput);

  print('\nResults:');
  print('  Added:   $added new levels');
  print('  Updated: $updated ratings');
  print('  Master:  ${masterLevels.length} total (${(masterOutput.length / 1024).toStringAsFixed(0)} KB)');
  print('  Bundled: ${bundledLevels.length} levels (rating >= 3 or unrated)');
  print('  Written: ${masterFile.path}');
  print('  Written: ${bundledFile.path}');
}

String _contentHash(Map<String, dynamic> level) {
  // Use roomStructure + roomState as identity (same as LevelEntry.contentHash)
  final struct = level['roomStructure']?.toString() ?? '';
  final state = level['roomState']?.toString() ?? '';
  return '$struct|$state'.hashCode.toRadixString(36);
}

/// Convert the existing gridlock_puzzles_data.dart to JSON format.
void _convertGridlockDartToJson() {
  print('Converting gridlock_puzzles_data.dart to JSON...');

  final dartFile = File('lib/features/games/data/gridlock_puzzles_data.dart');
  if (!dartFile.existsSync()) {
    print('Error: gridlock_puzzles_data.dart not found');
    exit(1);
  }

  final content = dartFile.readAsStringSync();

  // Parse each GridlockPuzzleData entry
  final puzzleRegex = RegExp(
    r"GridlockPuzzleData\(\s*"
    r"id:\s*'([^']+)',\s*"
    r"complexity:\s*([\d.]+),\s*"
    r"minMoves:\s*(\d+),\s*"
    r"(?:originalBoard:\s*'([^']*)',\s*)?"
    r"ships:\s*\[([\s\S]*?)\],?\s*\)",
    multiLine: true,
  );

  final puzzles = <Map<String, dynamic>>[];

  for (final match in puzzleRegex.allMatches(content)) {
    final id = match.group(1)!;
    final complexity = double.parse(match.group(2)!);
    final minMoves = int.parse(match.group(3)!);
    final originalBoard = match.group(4);
    final shipsRaw = match.group(5)!;

    // Parse ships
    final shipRegex = RegExp(
      r"\{'row':\s*(\d+),\s*'col':\s*(\d+),\s*'length':\s*(\d+),\s*"
      r"'isHorizontal':\s*(true|false),\s*'isPlayer':\s*(true|false),\s*"
      r"'isBlocking':\s*(true|false)\}",
    );

    final ships = <Map<String, dynamic>>[];
    for (final sm in shipRegex.allMatches(shipsRaw)) {
      ships.add({
        'row': int.parse(sm.group(1)!),
        'col': int.parse(sm.group(2)!),
        'length': int.parse(sm.group(3)!),
        'isHorizontal': sm.group(4) == 'true',
        'isPlayer': sm.group(5) == 'true',
        'isBlocking': sm.group(6) == 'true',
      });
    }

    puzzles.add({
      'id': id,
      'complexity': complexity,
      'minMoves': minMoves,
      if (originalBoard != null) 'originalBoard': originalBoard,
      'ships': ships,
      'rating': 3, // default rating
    });
  }

  final output = const JsonEncoder.withIndent('  ').convert({
    'meta': {
      'gameType': 'gridlock',
      'version': 1,
      'totalPuzzles': puzzles.length,
      'source': 'Converted from gridlock_puzzles_data.dart',
      'lastUpdated': DateTime.now().toIso8601String(),
    },
    'puzzles': puzzles,
  });

  final outFile = File('assets/puzzles/gridlock.json');
  outFile.writeAsStringSync(output);

  print('Converted ${puzzles.length} puzzles');
  print('Written: ${outFile.path} (${(output.length / 1024).toStringAsFixed(1)} KB)');
}
