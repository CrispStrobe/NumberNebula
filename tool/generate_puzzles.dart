// tool/generate_puzzles.dart
//
// CLI script to pre-generate puzzle datasets for CSP-heavy games.
// Run on VPS: dart run tool/generate_puzzles.dart
//
// Output: assets/puzzles/{gameType}.json
// These can be committed to the repo or hosted remotely.

import 'dart:convert';
import 'dart:io';

import 'package:space_math_academy/features/games/services/arithmancer_crosswords_logic.dart';

/// Generate crossword puzzles for all grade/level combinations.
Future<void> generateCrosswordPuzzles() async {
  print('=== Generating Arithmancer Crossword Puzzles ===');
  final puzzles = <Map<String, dynamic>>[];
  int generated = 0;
  int failed = 0;

  for (int grade = 1; grade <= 4; grade++) {
    // Generate for a spread of levels within each grade
    for (int level in [1, 3, 5, 8, 10, 13, 15, 18, 20]) {
      // Generate 3 puzzles per grade/level for variety
      for (int variant = 0; variant < 3; variant++) {
        try {
          final config = CrosswordConfig.getConfig(grade, level);
          print('  Grade $grade, Level $level, Variant $variant '
              '(ops=${config.ops}, edges=${config.targetEdges}, '
              'range=${config.minN}-${config.maxN})...');

          final puzzle = await generateCrosswordPuzzle(config);

          // Serialize the puzzle data
          final entry = {
            'grade': grade,
            'level': level,
            'ops': config.ops,
            'rating': 3, // default rating, can be updated via evaluations
            'data': {
              'grid': puzzle.grid
                  .map((row) => row.map((c) => c.toJson()).toList())
                  .toList(),
              'equations': puzzle.equations
                  .map((eq) => {
                        'terms': eq.terms,
                        'operators': eq.operators,
                        'result': eq.result,
                      })
                  .toList(),
              'solution': puzzle.solution,
              'clues': puzzle.clues,
              'gridWidth': puzzle.gridWidth,
              'gridHeight': puzzle.gridHeight,
            },
          };

          puzzles.add(entry);
          generated++;
          print('    -> OK ($generated generated)');
        } catch (e) {
          failed++;
          print('    -> FAILED: $e');
        }
      }
    }
  }

  final output = jsonEncode({'puzzles': puzzles});
  final file = File('assets/puzzles/arithmancer_crosswords.json');
  await file.writeAsString(output);

  print('\n=== Done ===');
  print('Generated: $generated, Failed: $failed');
  print('Output: ${file.path} (${(output.length / 1024).toStringAsFixed(1)} KB)');
}

void main() async {
  await generateCrosswordPuzzles();
  // Future: add other game generators here
  // await generateCodebreakerPuzzles();
  // await generateStarForgePuzzles();
}
