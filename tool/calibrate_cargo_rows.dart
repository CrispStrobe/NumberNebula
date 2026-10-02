// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/cargo_generation.dart';
import '../lib/features/games/services/cargo_row_generation.dart';
import 'cargo_row_scenarios.dart';

Future<void> main(List<String> args) async {
  String option(String key, String fallback) {
    final index = args.indexOf(key);
    return index < 0 ? fallback : args[index + 1];
  }

  final samples = int.parse(option('--samples', '50'));
  final grades =
      option('--grades', '1,2,3,4,5,6').split(',').map(int.parse).toList();
  if (samples < 1 || samples > 1000 || grades.any((g) => g < 1 || g > 6)) {
    throw ArgumentError('Grades 1..6, samples 1..1000 required');
  }
  final output = File(option('--output', 'cargo-row-calibration.json'));
  output.parent.createSync(recursive: true);
  final capture = File('${output.path}.fixtures.jsonl').openWrite();
  final groups = <String, Map<String, dynamic>>{};
  var cases = 0, failures = 0;
  for (final grade in grades) {
    for (var level = 1; level <= 20; level++) {
      for (var sample = 0; sample < samples; sample++) {
        final seed = 20261002 + grade * 10007 + level * 1009 + sample * 97;
        final input = cargoScenario(grade, level, sample % 7, sample % 4, seed);
        final original = jsonEncode([input.board, input.piece.toJson()]);
        // Forced assistance measures correctness; the 30% branch matches the
        // live higher-grade assistance chance. These are planted opportunities.
        for (final chance in [1.0, .30]) {
          for (final path in [AlgorithmPath.legacy, AlgorithmPath.candidate]) {
            final clock = Stopwatch()..start();
            final result = await withAlgorithmPath(
                path,
                () => generateCargoRowValues(
                    baseline: input.piece,
                    board: input.board,
                    minValue: input.config.numberMin,
                    maxValue: input.config.numberMax,
                    targetSum: input.config.targetSum,
                    assistanceChance: chance,
                    random: Random(seed)));
            clock.stop();
            var reachable = 0;
            for (final landing in cargoLandings(input.board, result.piece)) {
              final placed =
                  replayCargoLanding(input.board, result.piece, landing);
              if (placed.any((row) =>
                  row.every((v) => v != null) &&
                  row.whereType<int>().reduce((a, b) => a + b) ==
                      input.config.targetSum)) {
                reachable++;
              }
            }
            final valid = original ==
                    jsonEncode([input.board, input.piece.toJson()]) &&
                result.piece.cubes
                    .expand((r) => r)
                    .whereType<CargoCube>()
                    .every((c) =>
                        c.value >= input.config.numberMin &&
                        c.value <= input.config.numberMax) &&
                (result.landing == null ||
                    verifiesCargoTarget(
                        input.board,
                        result.piece,
                        result.landing!,
                        result.targetRows,
                        input.config.targetSum)) &&
                (path != AlgorithmPath.candidate ||
                    chance != 1 ||
                    reachable > 0);
            if (!valid) failures++;
            final key = '$grade/${path.name}/$chance';
            final group = groups.putIfAbsent(
                key,
                () => {
                      'grade': grade,
                      'algorithm': path.name,
                      'assistanceChance': chance,
                      'cases': 0,
                      'failures': 0,
                      'assisted': 0,
                      'reachableTargetBoards': 0,
                      'generationUs': <int>[],
                      'implementations': <String, int>{}
                    });
            group['cases']++;
            if (!valid) group['failures']++;
            if (result.landing != null) group['assisted']++;
            if (reachable > 0) group['reachableTargetBoards']++;
            (group['generationUs'] as List<int>).add(clock.elapsedMicroseconds);
            final trace = group['implementations'] as Map<String, int>;
            trace.update(result.implementation, (v) => v + 1,
                ifAbsent: () => 1);
            capture.writeln(jsonEncode({
              'grade': grade,
              'level': level,
              'sample': sample,
              'seed': seed,
              'algorithm': path.name,
              'assistanceChance': chance,
              'implementation': result.implementation,
              'valid': valid,
              'generationUs': clock.elapsedMicroseconds,
              'reachableTargets': reachable,
              'board': input.board,
              'piece': result.piece.toJson(),
              'targetSum': input.config.targetSum,
              'targetRows': result.targetRows,
              'placement': result.landing == null
                  ? null
                  : {
                      'rotations': result.landing!.rotations,
                      'x': result.landing!.x,
                      'y': result.landing!.y
                    }
            }));
            cases++;
          }
        }
      }
    }
    stdout.writeln('Completed grade $grade');
  }
  await capture.close();
  for (final group in groups.values) {
    final times = (group.remove('generationUs') as List<int>)..sort();
    group['generationUsMedian'] = times[times.length ~/ 2];
    group['generationUsP95'] = times[((times.length - 1) * .95).round()];
  }
  output.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'kind': 'planted-cargo-row-opportunities',
        'cases': cases,
        'failures': failures,
        'humanPlaytestData': false,
        'samplesPerCell': samples,
        'grades': grades,
        'scope':
            'Synthetic reachable row-completion opportunities, all seven shapes and four orientations. Forced assistance checks feasibility; 30% probes the live higher-grade chance. Grades 1–2 are stress-tested here but retain their legacy generator in the app. No whole-game win rate or child difficulty estimate.',
        'groups': groups.values.toList()
      })}\n');
  stdout.writeln('$cases Cargo cases, $failures failures. ${output.path}');
  if (failures > 0) exitCode = 1;
}
