import 'calibration_fixture_reader.dart';
import '../lib/features/games/services/algorithm_path.dart';
// ignore_for_file: avoid_relative_lib_imports
// Relative imports intentionally support the isolated, Flutter-free tool package.
// Pure Dart replay/analysis, with optional Flutter headless fixture capture.
import 'dart:convert';
import 'dart:io';
import 'pure_generation_capture.dart';
import 'calibration_summary.dart';
import '../lib/features/games/services/generated_board_validation.dart';
import '../lib/features/games/services/felt_difficulty.dart';
import '../lib/features/games/game_keys.dart';
import '../lib/features/games/services/board_hint_engine.dart';

Future<void> main(List<String> args) async {
  String option(String name, String fallback) {
    final i = args.indexOf(name);
    if (i < 0) return fallback;
    if (i + 1 >= args.length) throw ArgumentError('Missing value after $name');
    return args[i + 1];
  }

  if (args.contains('--help')) {
    stdout.writeln(
        'dart run tool/calibrate_games.dart --capture [--flutter PATH] '
        '[--grades 1,3,6] [--levels 1,10] [--samples 3] [--game KEY] [--output report.json]\n'
        'or --generate [--seed 20261002] [--workers 4] for pure Dart generation of all games;\n'
        '[--algorithm legacy|candidate|auto] [--square-path constructive|pruned]; all 20 levels are sampled.\n'
        'or --input fixtures.jsonl for pure Dart replay (no Flutter/device needed).');
    return;
  }
  if (args.contains('--generate') && args.contains('--capture')) {
    throw ArgumentError('Choose --generate or --capture, not both');
  }
  final output = File(option('--output', 'calibration-report.json')).absolute;
  output.parent.createSync(recursive: true);
  final input = File(option('--input', '${output.path}.fixtures.jsonl'));
  if (args.contains('--generate')) {
    final grades =
        option('--grades', '1,2,3,4,5,6').split(',').map(int.parse).toList();
    final levels = option('--levels', List.generate(20, (i) => i + 1).join(','))
        .split(',')
        .map(int.parse)
        .toList();
    final samples = int.parse(option('--samples', '10'));
    if (grades.any((g) => g < 1 || g > 6) ||
        levels.any((l) => l < 1 || l > 20) ||
        samples < 1 ||
        samples > 1000) {
      throw ArgumentError(
          'Grades 1..6, levels 1..20, samples 1..1000 required');
    }
    input.parent.createSync(recursive: true);
    await capturePureBoards(
        output: input.absolute.path,
        grades: grades,
        levels: levels,
        samples: samples,
        seed: int.parse(option('--seed', '20261002')),
        workers: int.parse(option('--workers', '4')),
        game: args.contains('--game') ? option('--game', '') : null,
        freshSokoban: args.contains('--fresh-sokoban'),
        path: AlgorithmPath.values.byName(option('--algorithm', 'auto')),
        squarePath: SquareGenerationPath.values
            .byName(option('--square-path', 'constructive')));
  }
  if (args.contains('--capture')) {
    final grades = option('--grades', '1').split(',').map(int.parse);
    final levels = option('--levels', '1').split(',').map(int.parse);
    final samples = int.parse(option('--samples', '1'));
    if (grades.any((g) => g < 1 || g > 6) ||
        levels.any((l) => l < 1) ||
        samples < 1 ||
        samples > 100) {
      stderr
          .writeln('Grades must be 1..6, levels positive, and samples 1..100.');
      exitCode = 2;
      return;
    }
    input.parent.createSync(recursive: true);
    input.writeAsStringSync('');
    final flutter =
        option('--flutter', Platform.environment['FLUTTER'] ?? 'flutter');
    final result = await Process.start(flutter, [
      'test',
      'test/widgets/all_games_sessions_test.dart',
      '--concurrency=1',
      '--reporter=expanded',
      if (args.contains('--game')) '--plain-name=${option('--game', '')} g',
      '--dart-define=GAME_ALGORITHM_PATH=${option('--algorithm', 'auto')}',
      '--dart-define=SQUARE_GENERATION_PATH=${option('--square-path', 'constructive')}',
      '--dart-define=CALIBRATION_OUTPUT=${input.absolute.path}',
      '--dart-define=CALIBRATION_GRADES=${option('--grades', '1')}',
      '--dart-define=CALIBRATION_LEVELS=${option('--levels', '1')}',
      '--dart-define=CALIBRATION_SAMPLES=${option('--samples', '1')}'
    ]);
    await Future.wait(
        [stdout.addStream(result.stdout), stderr.addStream(result.stderr)]);
    if (await result.exitCode != 0) {
      stderr.writeln(
          'Fixture capture failed; no calibration success is claimed.');
      exitCode = 1;
      return;
    }
  }
  if (!input.existsSync()) {
    stderr.writeln('Supply --input fixtures.jsonl or --capture.');
    exitCode = 2;
    return;
  }
  final reports = <Map<String, dynamic>>[];
  final failures = <String>[];
  await for (final record
      in decodeCalibrationFixtures(input.openRead(), source: input.path)) {
    if (reports.isNotEmpty && reports.length % 500 == 0) {
      stdout.writeln('Analyzed ${reports.length} boards');
    }
    record['algorithm'] ??= option('--algorithm', 'auto');
    final game = record['game'] as String;
    final state = Map<String, dynamic>.from(record['state'] as Map);
    if (record['source'] == 'pure-dart' && state.isNotEmpty) {
      record['validationFailures'] = withAlgorithmPath(
          AlgorithmPath.values.byName(record['algorithm'] as String? ?? 'auto'),
          () => validateGeneratedBoard(game, state));
    }
    failures.addAll((record['validationFailures'] as List? ?? []).map((e) =>
        '$game g${record['grade']} l${record['level']} seed${record['seed']}: $e'));
    final encoded = jsonEncode(state);
    final hintTimes = <int>[];
    BoardHint? hint;
    try {
      for (int i = 0; i < 5; i++) {
        final clock = Stopwatch()..start();
        hint = withAlgorithmPath(
            AlgorithmPath.values
                .byName(record['algorithm'] as String? ?? 'auto'),
            () => findBoardHint(game, state));
        hintTimes.add(clock.elapsedMicroseconds);
      }
      final german = withAlgorithmPath(
          AlgorithmPath.values.byName(record['algorithm'] as String? ?? 'auto'),
          () => findBoardHint(game, state, german: true));
      if (german == null) failures.add('$game missing German hint');
      if (hint == null) failures.add('$game has no board-aware hint');
      if (encoded != jsonEncode(state)) {
        failures.add('$game hint changed the board');
      }
      if (encoded != jsonEncode(jsonDecode(encoded))) {
        failures.add('$game is not stable JSON');
      }
    } catch (error) {
      failures.add('$game: $error');
    }
    final p = (state['puzzle'] ?? state['_puzzle'] ?? state['currentPuzzle'])
            as Map? ??
        {};
    final optimal = state['optimal'] ??
        state['_optimalMoves'] ??
        state['minMoves'] ??
        p['minMoves'] ??
        p['optimalSwaps'] ??
        p['optimalMoves'] ??
        (state['currentLevel'] as Map?)?['optimalMoves'];
    final allowance = state['maxMoves'] ??
        state['_maxMoves'] ??
        state['moveLimit'] ??
        state['maxCommands'] ??
        state['maxGuesses'] ??
        state['_maxAttempts'] ??
        state['timeLeft'];
    hintTimes.sort();
    final hidden = p['emptyCells'] ??
        p['emptyNodes'] ??
        p['hiddenCells'] ??
        p['hiddenIndices'];
    final rows = p['size'] ?? p['gridSize'] ?? p['rows'] ?? state['gridRows'];
    reports.add({
      'game': game,
      'grade': record['grade'],
      'level': record['level'],
      'algorithm': record['algorithm'] ?? 'auto',
      'algorithmTrace': record['algorithmTrace'],
      'squarePath': record['squarePath'],
      'language': record['language'] ?? 'unknown',
      'mechanic': record['mechanic'] ?? calibrationMechanic(game, state),
      'effectiveLevel': state['_currentLevel'] ?? record['level'],
      'sample': record['sample'],
      'readyWallMs': record['readyWallMs'],
      'generationMs': record['generationMs'],
      'seed': record['seed'],
      'source': record['source'] ?? 'headless-flutter',
      'feltDifficulty': record['validationFailures'] is List &&
              (record['validationFailures'] as List).isNotEmpty
          ? null
          : estimateFeltDifficulty(game, record['grade'] as int, state),
      'snapshotBytes': utf8.encode(encoded).length,
      'hintMedianUs':
          hintTimes.isEmpty ? null : hintTimes[hintTimes.length ~/ 2],
      'hintMaxUs': hintTimes.isEmpty ? null : hintTimes.last,
      'hintVerifiedMove': hint?.verified ?? false,
      'gridSizeOrRows': rows,
      'hiddenCells': hidden is List ? hidden.length : null,
      'referenceMoves': optimal,
      'referenceProof': game == 'void_crossing'
          ? 'BFS-checked'
          : game == 'launch_sequence'
              ? 'inversion-count-checked'
              : game == 'robot_path_game'
                  ? record['algorithm'] == 'legacy'
                      ? 'legacy estimate; command solvability checked separately'
                      : 'command BFS checked; includes turns and interactions'
                  : game == 'star_loader_game'
                      ? 'bundled push optima checked by solver tests'
                      : optimal == null
                          ? 'unknown'
                          : 'model reference; optimum not independently proven',
      'allowance': allowance,
      'allowancePerReferenceMove':
          optimal is num && optimal > 0 && allowance is num
              ? allowance / optimal
              : null
    });
  }
  if (reports.isEmpty) failures.add('No captured boards to analyze');
  stdout.writeln('Validated ${reports.length} boards and localized hints.');
  final games = reports.map((r) => r['game']).toSet();
  final requireAll = args.contains('--require-all');
  if (requireAll &&
      (games.length != gameKeys.length || !games.containsAll(gameKeys))) {
    failures.add('Expected 48 games, found ${games.length}');
  }
  final findings = <String>[];
  final grouped = summarizeCalibration(reports);
  final strata = summarizeCalibration(reports, stratified: true);
  final progressions = <String, List<Map<String, dynamic>>>{};
  for (final row in strata) {
    if (row['needsMoreSamples'] == true) continue;
    final key = '${row['game']} grade ${row['grade']} ${row['algorithm']} '
        '${row['squarePath'] == null ? '' : '${row['squarePath']} '}'
        '${row['mechanic']} ${row['language']}';
    progressions.putIfAbsent(key, () => []).add(row);
  }
  for (final entry in progressions.entries) {
    final progression = entry.value
      ..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
    for (var i = 1; i < progression.length; i++) {
      final previous = progression[i - 1], next = progression[i];
      // Compare neighboring levels only: a missing sparse stratum must not
      // appear to be an abrupt difficulty jump across a larger gap.
      if ((next['level'] as int) != (previous['level'] as int) + 1) continue;
      final a = previous['noviceScore']['median'],
          b = next['noviceScore']['median'];
      if (a is num && b is num && (b - a).abs() >= 0.75) {
        findings.add('${entry.key}: estimated novice workload changes '
            '${a.toStringAsFixed(2)} → ${b.toStringAsFixed(2)} between levels '
            '${previous['level']} and ${next['level']}; inspect prerequisites and allowances.');
      }
      for (final field in ['hiddenCells', 'referenceMoves']) {
        final a = previous['${field}Median'], b = next['${field}Median'];
        if (a is num && b is num && a > 0 && b < a * 0.8) {
          findings.add('${entry.key}: $field drops from $a to $b between '
              'levels ${previous['level']} and ${next['level']}; inspect the generator.');
        }
      }
    }
  }
  writeCalibrationTable(File('${output.path}.summary.csv'), grouped);
  final report = {
    'schema': 3,
    'stratifiedSummary': strata,
    'kind': 'structural-calibration',
    'humanPlaytestData': false,
    'difficultyEstimatesValidated': false,
    'games': games.length,
    'cases': reports.length,
    'notes': [
      'Pure generation uses stable per-case seed streams. Wall-time solver fallbacks may vary; frozen fixtures support exact replay.',
      'readyWallMs includes the headless harness and polling, not pure generator CPU time.',
      'Reference moves come from game models; independently checked optima are game-specific, and unknown optima remain null. Candidate numeric ranges explicitly extend grades 5–6; bounded spatial/asset families retain documented caps.',
      'Automated findings flag review candidates; they do not change child difficulty thresholds.'
    ],
    'failures': failures,
    'reviewCandidates': findings,
    'groupedDifficulty': grouped,
    'results': reports
  };
  output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(
      '${games.length} games, ${reports.length} cases, ${failures.length} failures. Report: ${output.path}');
  for (final failure in failures) {
    stderr.writeln(failure);
  }
  if (failures.isNotEmpty) exitCode = 1;
}

String calibrationMechanic(String game, Map<String, dynamic> state) {
  final p = state['puzzle'] is Map ? state['puzzle'] as Map : state;
  if (p['cipherType'] != null) return p['cipherType'].toString();
  if (p['operation'] != null) return p['operation'].toString();
  final ops = <String>{};
  for (final field in ['rowOperators', 'columnOperators']) {
    for (final row in p[field] as List? ?? []) {
      ops.addAll((row as List).cast<String>());
    }
  }
  for (final eq in p['equations'] as List? ?? []) {
    if (eq is Map && (eq['operator'] ?? eq['op'] ?? eq['operation']) != null) {
      ops.add((eq['operator'] ?? eq['op'] ?? eq['operation']).toString());
    }
  }
  for (final cage in p['cages'] as List? ?? []) {
    if (cage is Map && cage['op'] != null) {
      ops.add(cage['op'].toString());
    }
  }
  return ops.isEmpty ? game : (ops.toList()..sort()).join(',');
}
