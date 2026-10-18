// ignore_for_file: avoid_relative_lib_imports
// tool/structural_review_g_regression.dart
// Lane G: frozen-report integrity plus a bounded seeded Robot generation,
// command-solution replay and JSON round-trip regression. This is not a
// replacement for the every-level sweep or empirical difficulty calibration.
import 'dart:convert';
import 'dart:io';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/generator_random.dart';
import '../lib/features/games/services/robot_path_logic.dart';

void main() {
  var checks = 0;
  void check(bool cond, String msg) {
    checks++;
    if (!cond) throw StateError('G regression failed: $msg');
  }

  // 1. Verify baseline report exists and has expected schema/case count.
  final report = jsonDecode(
      File('docs/calibration-sample-results.json').readAsStringSync()) as Map;
  check(report['schema'] == 3, 'schema');
  check(report['cases'] == 60400, 'cases');
  check((report['games'] as int) == 48, 'games');
  check((report['failures'] as List).isEmpty, 'failures');
  final candidates = (report['reviewCandidates'] as List).cast<String>();
  check(candidates.length == 67, '67 flags expected, got ${candidates.length}');

  // 2. Decompose 67 flags exactly as documented.
  var molecule =
      candidates.where((s) => s.contains('quantum_molecule_builder')).length;
  var robot = candidates.where((s) => s.contains('robot_path_game')).length;
  var warp = candidates.where((s) => s.contains('warp_fold')).length;
  var crossword =
      candidates.where((s) => s.contains('arithmancer_crosswords')).length;
  var solar = candidates.where((s) => s.contains('solarpanel_game')).length;
  var gridlock =
      candidates.where((s) => s.contains('space_station_gridlock')).length;
  check(molecule == 42, 'molecule 42 got $molecule');
  check(robot == 15, 'robot 15 got $robot');
  check(warp == 4, 'warp 4 got $warp');
  check(crossword == 3, 'crossword 3 got $crossword');
  check(solar == 2, 'solar 2 got $solar');
  check(gridlock == 1, 'gridlock 1 got $gridlock');

  // Molecule: 7 distinct transitions × 6 grades = 42
  // Extract level transitions for molecule flags.
  final molTransitions = <String>{};
  for (final c
      in candidates.where((s) => s.contains('quantum_molecule_builder'))) {
    final m = RegExp(r'between levels (\d+) and (\d+)').firstMatch(c);
    if (m != null) molTransitions.add('${m.group(1)}->${m.group(2)}');
  }
  check(molTransitions.length == 7,
      'molecule distinct transitions 7 got ${molTransitions.length}: $molTransitions');
  check(molTransitions.contains('8 and 9') || molTransitions.contains('8->9'),
      'missing 8->9');

  // 3. Verify molecule asset order: 20 levels, levelNumber 1..20 sequential.
  final molRaw =
      jsonDecode(File('assets/data/molecule_levels.json').readAsStringSync())
          as Map;
  final levels = (molRaw['levels'] as List).cast<Map>();
  check(levels.length == 30, 'molecule asset 30 levels (bundled pool)');
  for (var i = 0; i < levels.length; i++) {
    check(levels[i]['levelNumber'] == i + 1,
        'molecule levelNumber ${levels[i]['levelNumber']} != ${i + 1}');
  }
  // Calibration uses levels 1..20 from this pool; ensure those exist.
  check(levels.take(20).every((l) => (l['levelNumber'] as int) <= 20),
      'first 20 levels present');

  // 4. Verify sampling metadata: 10 per cell, 400 CommRelay balanced, 2031 sparse.
  final sampling = report['sampling'] as Map;
  check(sampling['seed'] == 20261002, 'seed');
  check((report['strata']['total'] as int) == 7493, 'strata total');
  check(report['strata']['underTenSamples'] == 2031, 'sparse strata');
  check(report['strata']['commRelayBalanced'] == 400, 'comm relay balanced');

  // 5. Verify focused sweep fallback rates.
  final focused = jsonDecode(
      File('docs/focused-calibration-results.json').readAsStringSync()) as Map;
  final sweeps = focused['sweeps'] as Map;
  check(
      sweeps.containsKey('launchCandidate'), 'focused launchCandidate present');
  // Constructive Square: 0 simpler-operation fallbacks via algorithmTraces check
  // In calibration-sample-results, square traces show candidate-constructive 1200
  final squareFb =
      (report['arithmeticSquareFallbacks'] as Map?)?['candidate-constructive'];
  check(squareFb == 1200, 'square constructive 1200 boards');
  // Focused pruned vs constructive fallback counts
  final focusedCases = report['focusedCalibration'] as Map;
  check(focusedCases['squarePrunedSimpleFallbacks'] == 591,
      'pruned fallback 591');

  // 6. Verify reference proof status for flagged Robot transition grade2 8->9 exists.
  final robot8to9 = candidates
      .where((s) =>
          s.contains('robot_path_game grade 2') && s.contains('levels 8 and 9'))
      .toList();
  check(robot8to9.length == 1, 'robot g2 8->9 flag exists');
  check(robot8to9.first.contains('referenceMoves drops from 31 to 21'),
      'robot g2 8->9 text');

  // 7. Verify algorithmComparison: legacy had 4 failed Robot boards, candidate 0.
  final algoComp = (report['algorithmComparison'] as List).cast<Map>();
  final robotLegacy = algoComp.firstWhere(
      (m) => m['game'] == 'robot_path_game' && m['algorithm'] == 'legacy');
  final robotCand = algoComp.firstWhere(
      (m) => m['game'] == 'robot_path_game' && m['algorithm'] == 'candidate');
  check(robotLegacy['failedBoards'] == 4, 'robot legacy 4 failures');
  check(robotCand['failedBoards'] == 0, 'robot candidate 0 failures');

  // 8. Verify per-case seeds preserved in frozen fixtures via focused report
  // (focused calibration also uses seeded determinism)
  check((focused['sweeps']['launchCandidate']['cases'] as int) == 6000,
      'focused launch 6000');

  final frozenChecks = checks;
  var generatedBoards = 0;
  for (final level in [8, 9]) {
    final seed = 20261002 + level * 1009;
    for (final path in [AlgorithmPath.legacy, AlgorithmPath.candidate]) {
      final board = withAlgorithmPath(path,
          () => withGeneratorSeed(seed, () => PathLevel.generate(2, level)));
      final before = jsonEncode(board.toJson());
      final commands = solveRobotCommands(board);
      check(commands != null,
          'Robot g2 l$level ${path.name} seed $seed has a command solution');
      var state = RobotCommandState.start(board);
      for (final command in commands!) {
        final next = stepRobotCommand(state, command);
        check(next != null, 'Robot command can execute: $command');
        state = next!;
      }
      check(state.row == board.goalRow && state.col == board.goalCol,
          'Robot replay reaches the goal');
      check(jsonEncode(board.toJson()) == before,
          'Robot solve/replay must not mutate the generated board');
      check(jsonEncode(PathLevel.fromJson(board.toJson()).toJson()) == before,
          'Robot JSON round trip');
      if (path == AlgorithmPath.candidate) {
        check(board.optimalMoves == commands.length,
            'candidate reference equals command BFS length');
        final allowance = withAlgorithmPath(path, () => board.commandAllowance);
        check(allowance >= commands.length,
            'candidate allowance covers the proved command sequence');
      }
      generatedBoards++;
    }
  }
  stdout.writeln('$frozenChecks frozen-report integrity checks; '
      '$generatedBoards newly generated Robot boards replayed; $checks total checks. '
      'These seeded cases are not the full sweep or human difficulty evidence.');
}
