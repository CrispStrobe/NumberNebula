// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/game_generation.dart';
import '../lib/features/games/services/generated_board_validation.dart';
import '../lib/features/games/services/board_hint_engine.dart';

Future<void> main(List<String> args) async {
  final assets = GenerationAssets(
      moleculeSource:
          File('assets/data/molecule_levels.json').readAsStringSync(),
      gridlockSource:
          File('assets/puzzles/gridlock_puzzles.json').readAsStringSync(),
      starloaderSource:
          File('assets/data/starloader_levels.json').readAsStringSync());
  final rows = <Map<String, dynamic>>[];
  for (final game in [
    'robot_path_game',
    'arithmatic_square',
    'arithmancer_crosswords',
    'kenken',
    'orbital_towers'
  ]) {
    for (final grade in [1, 2, 3, 4]) {
      for (final level in [1, 10, 20]) {
        for (var sample = 0; sample < 3; sample++) {
          final seed = 20261002 + grade * 10007 + level * 1009 + sample * 97;
          Map<String, dynamic>? hintBoard;
          for (final path in [AlgorithmPath.legacy, AlgorithmPath.candidate]) {
            final trace = <String, String>{};
            final clock = Stopwatch()..start();
            try {
              final state = await withAlgorithmTrace(
                  trace,
                  () => withAlgorithmPath(
                      path,
                      () => generateGameBoard(game, grade, level,
                          seed: seed, assets: assets)));
              clock.stop();
              final failures = withAlgorithmPath(
                  path, () => validateGeneratedBoard(game, state));
              hintBoard ??= state;
              final hintClock = Stopwatch()..start();
              final hint = withAlgorithmPath(
                  path, () => findBoardHint(game, hintBoard!));
              hintClock.stop();
              rows.add({
                'game': game,
                'grade': grade,
                'level': level,
                'sample': sample,
                'seed': seed,
                'algorithm': path.name,
                'generationMs': clock.elapsedMicroseconds / 1000,
                'hintMs': hintClock.elapsedMicroseconds / 1000,
                'hintVerified': hint?.verified ?? false,
                'failures': failures,
                'trace': trace
              });
            } catch (e) {
              rows.add({
                'game': game,
                'grade': grade,
                'level': level,
                'sample': sample,
                'seed': seed,
                'algorithm': path.name,
                'failures': ['$e'],
                'trace': trace
              });
            }
          }
        }
      }
    }
    stdout.writeln('Compared $game');
  }
  num? median(Iterable<num> values) {
    final sorted = values.toList()..sort();
    return sorted.isEmpty ? null : sorted[sorted.length ~/ 2];
  }

  final summary = [
    for (final game in rows.map((r) => r['game']).toSet())
      for (final path in ['legacy', 'candidate'])
        (() {
          final group = rows
              .where((r) => r['game'] == game && r['algorithm'] == path)
              .toList();
          return {
            'game': game,
            'algorithm': path,
            'samples': group.length,
            'generationMedianMs':
                median(group.map((r) => r['generationMs']).whereType<num>()),
            'hintMedianMs':
                median(group.map((r) => r['hintMs']).whereType<num>()),
            'verifiedHints':
                group.where((r) => r['hintVerified'] == true).length,
            'failedBoards':
                group.where((r) => (r['failures'] as List).isNotEmpty).length
          };
        })()
  ];
  final output = File(args.isEmpty ? 'algorithm-comparison.json' : args.first);
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'kind': 'paired-algorithm-comparison',
        'sameHintBoards': true,
        'summary': summary,
        'results': rows
      })}\n');
  stdout.writeln(jsonEncode(summary));
}
