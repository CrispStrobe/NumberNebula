// tool/generate_puzzles.dart
//
// Unified puzzle generation CLI for all CSP-heavy games.
// Run on VPS to pre-generate puzzles, then merge into datasets.
//
// Usage:
//   dart run tool/generate_puzzles.dart starloader [--count=50] [--grade=2]
//   dart run tool/generate_puzzles.dart crosswords [--count=5] [--grade=1]
//   dart run tool/generate_puzzles.dart all
//
// Output: assets/puzzles/<game_type>.json (or merged into master DB)

import 'dart:convert';
import 'dart:io';

import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage:');
    print('  dart run tool/generate_puzzles.dart starloader [--count=50] [--grade=2]');
    print('  dart run tool/generate_puzzles.dart crosswords [--count=5] [--grade=1]');
    print('  dart run tool/generate_puzzles.dart all');
    exit(0);
  }

  final command = args[0];
  final flags = _parseFlags(args.skip(1).toList());

  switch (command) {
    case 'starloader':
      await _generateStarLoader(
        count: flags['count'] ?? 20,
        grade: flags['grade'],
      );
    case 'all':
      for (int g = 1; g <= 4; g++) {
        await _generateStarLoader(count: 20, grade: g);
      }
    default:
      print('Unknown command: $command');
      exit(1);
  }
}

Map<String, int?> _parseFlags(List<String> args) {
  final result = <String, int?>{};
  for (final arg in args) {
    if (arg.startsWith('--count=')) {
      result['count'] = int.parse(arg.split('=')[1]);
    } else if (arg.startsWith('--grade=')) {
      result['grade'] = int.parse(arg.split('=')[1]);
    }
  }
  return result;
}

/// Generate Star Loader (Frachtlader / Sokoban) puzzles.
/// Writes new levels to a temp JSON file, then merge with:
///   dart run tool/puzzle_merge.dart --merge-starloader <output>
Future<void> _generateStarLoader({required int count, int? grade}) async {
  final grades = grade != null ? [grade] : [1, 2, 3, 4];
  final allLevels = <Map<String, dynamic>>[];
  final generator = LevelGenerator(verbose: false);

  for (final g in grades) {
    print('=== Star Loader Grade $g ===');

    int dimX, dimY, numBoxes, minPushes;
    if (g == 1) { dimX = 7; dimY = 7; numBoxes = 2; minPushes = 6; }
    else if (g == 2) { dimX = 8; dimY = 8; numBoxes = 3; minPushes = 9; }
    else if (g == 3) { dimX = 10; dimY = 10; numBoxes = 3; minPushes = 13; }
    else { dimX = 12; dimY = 11; numBoxes = 4; minPushes = 17; }

    int generated = 0;
    int attempts = 0;
    final maxAttempts = count * 50;

    while (generated < count && attempts < maxAttempts) {
      attempts++;
      try {
        final result = generator.generateLevel(
          dimX: dimX,
          dimY: dimY,
          numBoxes: numBoxes,
          maxTries: 5,
          minOptimalPushes: minPushes,
        );

        allLevels.add({
          'id': 'gen_g${g}_${DateTime.now().millisecondsSinceEpoch}_$generated',
          'difficulty': 'grade_$g',
          'dimX': dimX,
          'dimY': dimY,
          'roomStructure': result.roomStructure,
          'roomState': result.roomState,
          'optimalMoves': result.optimalMoves,
          'avgRating': 0.0,
          'ratingCount': 0,
        });
        generated++;
        stdout.write('\r  Generated $generated/$count (attempts: $attempts)');
      } catch (_) {
        // Generation failed, retry
      }
    }
    print('\n  Done: $generated levels in $attempts attempts');
  }

  // Write output
  final outputPath = '/tmp/starloader_generated_${DateTime.now().millisecondsSinceEpoch}.json';
  final output = const JsonEncoder.withIndent('  ').convert({
    'levels': allLevels,
  });
  File(outputPath).writeAsStringSync(output);

  print('\nTotal: ${allLevels.length} levels');
  print('Output: $outputPath');
  print('\nTo merge into master DB:');
  print('  dart run tool/puzzle_merge.dart --merge-starloader $outputPath');
}
