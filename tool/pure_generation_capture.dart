import '../lib/features/games/services/algorithm_path.dart';
// ignore_for_file: avoid_relative_lib_imports
// Relative imports intentionally support the isolated, Flutter-free tool package.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../lib/features/games/services/game_generation.dart';
import '../lib/features/games/services/generated_board_validation.dart';

/// Separate isolates keep synchronous CSP work from blocking progress reporting.
Future<void> capturePureBoards(
    {required String output,
    required List<int> grades,
    required List<int> levels,
    required int samples,
    required int seed,
    String? game,
    int workers = 4,
    bool freshSokoban = false,
    AlgorithmPath path = AlgorithmPath.auto,
    SquareGenerationPath squarePath =
        SquareGenerationPath.constructive}) async {
  final selected = game == null ? gameKeys : [game];
  if (selected.any((key) => !gameKeys.contains(key))) {
    throw ArgumentError('Unknown game $game');
  }
  final molecule = File('assets/data/molecule_levels.json').readAsStringSync();
  final gridlock =
      File('assets/puzzles/gridlock_puzzles.json').readAsStringSync();
  final starloader =
      File('assets/data/starloader_levels.json').readAsStringSync();
  var cursor = 0;
  Future<void> worker() async {
    while (cursor < selected.length) {
      final key = selected[cursor++], index = gameKeys.indexOf(key);
      final partPath = '$output.$index.part';
      final result = await Isolate.run(() async {
        final assets = GenerationAssets(
            moleculeSource: molecule,
            gridlockSource: gridlock,
            starloaderSource: starloader);
        final file = File(partPath)..writeAsStringSync('');
        var cases = 0, failures = 0;
        for (final grade in grades) {
          for (final level in levels) {
            final variants = key == 'comm_relay'
                ? [
                    for (final language in ['en', 'de'])
                      for (final mechanic
                          in grade <= 2 ? ['caesar'] : ['atbash', 'keyword'])
                        {'language': language, 'mechanic': mechanic}
                  ]
                : [<String, String>{}];
            for (var variant = 0; variant < variants.length; variant++) {
              for (int sample = 0; sample < samples; sample++) {
                // Stable across worker count, filtering, and traversal order.
                final caseSeed = (seed +
                        index * 1000003 +
                        grade * 10007 +
                        level * 1009 +
                        sample * 97 +
                        variant * 7919) &
                    0x7fffffff;
                final clock = Stopwatch()..start();
                Map<String, dynamic> state = {};
                List<String> errors = [];
                final trace = <String, String>{};
                try {
                  state = await withAlgorithmTrace(
                      trace,
                      () => withAlgorithmPath(
                          path,
                          () => withSquareGenerationPath(
                              squarePath,
                              () => generateGameBoard(key, grade, level,
                                  seed: caseSeed,
                                  assets: assets,
                                  freshSokoban: freshSokoban,
                                  language: variants[variant]['language'],
                                  mechanic: variants[variant]['mechanic']))));
                  errors = withAlgorithmPath(
                      path, () => validateGeneratedBoard(key, state));
                } catch (e, st) {
                  errors = ['$e', st.toString().split('\n').take(3).join('\n')];
                }
                clock.stop();
                file.writeAsStringSync(
                    '${jsonEncode({
                          'game': key,
                          'grade': grade,
                          'level': level,
                          'sample': sample,
                          'seed': caseSeed,
                          'generationMs': clock.elapsedMicroseconds / 1000,
                          'source': 'pure-dart',
                          'algorithm': path.name,
                          'squarePath': squarePath.name,
                          'algorithmTrace': trace,
                          'language':
                              variants[variant]['language'] ?? 'neutral',
                          'mechanic': variants[variant]['mechanic'],
                          'validationFailures': errors,
                          'state': state
                        })}\n',
                    mode: FileMode.append);
                cases++;
                if (errors.isNotEmpty) failures++;
              }
            }
          }
        }
        return {'game': key, 'cases': cases, 'failures': failures};
      });
      stdout.writeln(
          'Generated ${result['game']}: ${result['cases']} boards, ${result['failures']} failures');
    }
  }

  await Future.wait(List.generate(workers.clamp(1, 8), (_) => worker()));
  final sink = File(output).openWrite();
  for (final key in selected) {
    final index = gameKeys.indexOf(key);
    final part = File('$output.$index.part');
    await sink.addStream(part.openRead());
    part.deleteSync();
  }
  await sink.close();
}
