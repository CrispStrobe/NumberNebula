// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/robot_path_logic.dart';
import '../lib/features/games/services/launch_sequence_logic.dart';
import '../lib/features/games/services/generated_board_validation.dart';
import '../lib/features/games/services/hint_completion_solver.dart';
import '../lib/features/games/services/arithmetic_tables.dart';
import '../lib/features/games/services/arithmetic_square_logic.dart';
import '../lib/features/games/services/generator_random.dart';
import '../lib/features/games/services/game_generation.dart';
import '../lib/features/games/constants/difficulty_manager.dart';
import 'package:dart_csp/dart_csp.dart';
import 'calibration_summary.dart';
import 'calibration_fixture_reader.dart';

Future<void> main() async {
  var checks = 0;
  void check(bool condition, String reason) {
    checks++;
    if (!condition) throw StateError(reason);
  }

  PathLevel board(List<String> rows, {int direction = 1}) {
    const cells = {
      '#': CellType.wall,
      '.': CellType.empty,
      'S': CellType.start,
      'G': CellType.goal,
      'J': CellType.jumpableWall,
      'D': CellType.destructible,
      'B': CellType.movable
    };
    final grid =
        rows.map((r) => r.split('').map((c) => cells[c]!).toList()).toList();
    final start = rows.join().indexOf('S'), goal = rows.join().indexOf('G');
    return PathLevel(
        gridSize: rows.length,
        grid: grid,
        startRow: start ~/ rows.length,
        startCol: start % rows.length,
        startDirection: direction,
        goalRow: goal ~/ rows.length,
        goalCol: goal % rows.length,
        optimalMoves: 0);
  }

  for (final example in [
    (board(['#####', '#S.G#', '#####', '#####', '#####']), 2),
    (board(['#####', '#S..#', '###G#', '#####', '#####']), 4),
    (board(['#####', '#SJG#', '#####', '#####', '#####']), 1),
    (board(['#####', '#SDG#', '#####', '#####', '#####']), 3),
    (board(['######', '#SBG.#', '######', '######', '######', '######']), 2),
  ]) {
    final commands = solveRobotCommands(example.$1);
    check(commands != null && commands.length == example.$2,
        'Wrong command optimum');
    var state = RobotCommandState.start(example.$1);
    final before = jsonEncode(example.$1.toJson());
    for (final command in commands!) {
      state = stepRobotCommand(state, command)!;
    }
    check(state.row == example.$1.goalRow && state.col == example.$1.goalCol,
        'Replay failed');
    check(before == jsonEncode(example.$1.toJson()), 'Solver mutated board');
  }
  final pull = board(['#####', '#.SB#', '##G##', '#####', '#####']);
  final pulled =
      stepRobotCommand(RobotCommandState.start(pull), RobotCommand.pull)!;
  check(
      pulled.col == 1 &&
          pulled.grid[1][2] == CellType.movable &&
          pulled.grid[1][3] == CellType.empty,
      'Pull semantics');
  final noStartPush = RobotCommandState(1, 1, 1, [
    [CellType.wall, CellType.wall, CellType.wall, CellType.wall],
    [CellType.wall, CellType.empty, CellType.movable, CellType.start],
    List.filled(4, CellType.wall),
    List.filled(4, CellType.wall)
  ]);
  check(stepRobotCommand(noStartPush, RobotCommand.push) == null,
      'Push cannot land on start');
  check(solveRobotCommands(pull, maxStates: 1) == null,
      'Bounded search must not invent proof');
  for (final op in ['+', '−', '×', '÷']) {
    final p = Problem();
    p.addVariables(['a', 'b', 'c'], [1, 2, 3, 4, 5, 6]);
    addArithmeticConstraint(p, ['a', 'b', 'c'], [1, 2, 3, 4, 5, 6], op);
    final solution = await p.getSolution();
    check(solution is Map, 'Arithmetic constraint no solution $op');
    final v = solution as Map;
    check(
        arithmeticTriples([1, 2, 3, 4, 5, 6], op)
            .any((t) => t[0] == v['a'] && t[1] == v['b'] && t[2] == v['c']),
        'Arithmetic support wrong $op');
  }
  final data = <String, dynamic>{
    'values': {'r0c0': 1},
    'domains': {
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) 'r${r}c$c': [1, 2, 3]
    },
    'groups': [
      for (var r = 0; r < 3; r++) [for (var c = 0; c < 3; c++) 'r${r}c$c'],
      for (var c = 0; c < 3; c++) [for (var r = 0; r < 3; r++) 'r${r}c$c']
    ],
    'sightlines': [
      {
        'cells': ['r0c0', 'r0c1', 'r0c2'],
        'target': 3
      }
    ],
    'cages': [
      {
        'cells': ['r1c0', 'r2c0'],
        'op': '+',
        'clue': '5+'
      }
    ],
    'timeoutMs': 1000
  };
  final frozen = jsonEncode(data);
  for (final path in AlgorithmPath.values) {
    final result = withAlgorithmPath(path, () => findHintCompletion(data));
    check(result != null && result['r0c1'] == 2 && result['r0c2'] == 3,
        'Hint ignored visibility/current placement $path');
    check(jsonEncode(data) == frozen, 'Hint mutated input $path');
    check(
        withAlgorithmPath(
                path,
                () => findHintCompletion({
                      ...data,
                      'values': {'r0c0': 1, 'r0c1': 1}
                    })) ==
            null,
        'Contradictory hints accepted $path');
  }
  for (final cage in [
    {
      'cells': ['r0c0', 'r0c1', 'r0c2'],
      'op': '+',
      'clue': '6+'
    },
    {
      'cells': ['r0c0', 'r0c1', 'r0c2'],
      'op': '×',
      'clue': '6×'
    },
    {
      'cells': ['r0c0', 'r0c1'],
      'op': '−',
      'clue': '1−'
    },
    {
      'cells': ['r0c0', 'r0c1'],
      'op': '÷',
      'clue': '2÷'
    },
    {
      'cells': ['r0c0', 'r0c1', 'r0c2'],
      'op': '+',
      'clue': '5+'
    },
    {
      'cells': ['r0c0', 'r0c1', 'r0c2'],
      'op': '×',
      'clue': '5×'
    },
  ]) {
    final input = {
      ...data,
      'values': <String, int>{},
      'sightlines': [],
      'cages': [cage]
    };
    final candidate = withAlgorithmPath(
        AlgorithmPath.candidate, () => findHintCompletion(input));
    final legacy = withAlgorithmPath(
        AlgorithmPath.legacy, () => findHintCompletion(input));
    check((candidate == null) == (legacy == null),
        'Cage pruning changed satisfiability $cage');
    if (candidate != null) {
      check(findHintCompletionLegacy({...input, 'values': candidate}) != null,
          'Candidate cage completion failed independent validation');
    }
  }
  for (final grade in [4, 5, 6]) {
    final legacy = withAlgorithmPath(
        AlgorithmPath.legacy,
        () => DifficultyManager.getDifficulty(
            GenerationSettings(grade: grade), 1));
    final candidate = withAlgorithmPath(
        AlgorithmPath.candidate,
        () => DifficultyManager.getDifficulty(
            GenerationSettings(grade: grade), 1));
    check(legacy.grade == 4 && candidate.grade == grade,
        'Grade path not independent');
    check(
        candidate.timeLimit == legacy.timeLimit &&
            candidate.gameSpeed == legacy.gameSpeed,
        'Advanced grades changed pressure without evidence');
    check(candidate.numberRange['max']! == [80, 120, 180][grade - 4],
        'Advanced number range');
  }
  final assets = GenerationAssets(
      moleculeSource:
          File('assets/data/molecule_levels.json').readAsStringSync(),
      gridlockSource:
          File('assets/puzzles/gridlock_puzzles.json').readAsStringSync(),
      starloaderSource:
          File('assets/data/starloader_levels.json').readAsStringSync());
  for (final sample in [2, 3]) {
    final seed = (20261002 +
            gameKeys.indexOf('arithmancer_crosswords') * 1000003 +
            6 * 10007 +
            20 * 1009 +
            sample * 97) &
        0x7fffffff;
    final watch = Stopwatch()..start();
    final state = await withAlgorithmPath(
        AlgorithmPath.candidate,
        () => generateGameBoard('arithmancer_crosswords', 6, 20,
            seed: seed, assets: assets));
    check(watch.elapsed < const Duration(seconds: 10),
        'Wide-domain all-different cliff seed $seed');
    check((state['puzzle']['equations'] as List).isNotEmpty,
        'Advanced crossword regression returned empty board');
  }
  for (final grade in [1, 2, 3, 4, 5, 6]) {
    for (final level in [1, 10, 20]) {
      for (var sample = 0; sample < 10; sample++) {
        final state = await withAlgorithmPath(
            AlgorithmPath.candidate,
            () => generateGameBoard('robot_path_game', grade, level,
                seed: 20261002 + sample, assets: assets));
        final b = PathLevel.fromJson(
            Map<String, dynamic>.from(state['currentLevel']));
        final solution = solveRobotCommands(b);
        check(
            solution != null &&
                solution.length == b.optimalMoves &&
                b.commandAllowance >= solution.length,
            'Generated command proof g$grade l$level s$sample');
      }
    }
  }
  // Independent adjacent-swap execution proves each requested sorting workload.
  for (var n = 2; n <= 8; n++) {
    for (var target = 0; target <= n * (n - 1) ~/ 2; target++) {
      for (var seed = 0; seed < 10; seed++) {
        final puzzle = withAlgorithmPath(
            AlgorithmPath.candidate,
            () => LaunchSequencePuzzle.generate(
                itemCount: n, minInversions: target, seed: seed));
        final sorted = List<int>.from(puzzle.sequence);
        var swaps = 0;
        for (var end = n - 1; end > 0; end--) {
          for (var i = 0; i < end; i++) {
            if (sorted[i] > sorted[i + 1]) {
              final a = sorted[i];
              sorted[i] = sorted[i + 1];
              sorted[i + 1] = a;
              swaps++;
            }
          }
        }
        check(
            swaps == (target == 0 ? 1 : target) &&
                sorted.join(',') == List.generate(n, (i) => i + 1).join(','),
            'Exact sorting workload n$n target$target seed$seed');
      }
    }
  }
  for (var grade = 1; grade <= 6; grade++) {
    var previous = 0;
    for (var level = 1; level <= 20; level++) {
      final target = withAlgorithmPath(AlgorithmPath.candidate,
          () => LaunchSequenceGenerationConfig(grade, level).inversions);
      check(target >= previous, 'Sorting progression g$grade l$level');
      previous = target;
    }
  }
  for (final path in AlgorithmPath.values) {
    for (final invalid in [(1, 0), (4, -1), (4, 7)]) {
      var rejected = false;
      try {
        withAlgorithmPath(
            path,
            () => LaunchSequencePuzzle.generate(
                itemCount: invalid.$1, minInversions: invalid.$2));
      } on ArgumentError {
        rejected = true;
      }
      check(rejected, 'Invalid sorting input rejected $path $invalid');
    }
  }
  for (final path in SquareGenerationPath.values) {
    for (var grade = 1; grade <= 6; grade++) {
      for (final level in [1, 10, 20]) {
        final trace = <String, String>{};
        final square = await withAlgorithmTrace(
            trace,
            () => withAlgorithmPath(
                AlgorithmPath.candidate,
                () => withSquareGenerationPath(
                    path,
                    () => generateGameBoard('arithmatic_square', grade, level,
                        seed: 20261002, assets: assets))));
        check(validateGeneratedBoard('arithmatic_square', square).isEmpty,
            'Square $path g$grade l$level validates');
        check(
            path != SquareGenerationPath.constructive ||
                trace['arithmetic-square'] == 'candidate-constructive',
            'Constructive Square does not silently fall back');
      }
    }
  }
  // Frozen failures from the large sweep: infeasible anchored attempts must
  // accept the solver's FAILURE marker and continue to another relation.
  for (final seed in [33302272, 33302369, 33302466]) {
    final square = await withAlgorithmPath(
        AlgorithmPath.candidate,
        () => withSquareGenerationPath(
            SquareGenerationPath.constructive,
            () => generateGameBoard('arithmatic_square', 4, 1,
                seed: seed, assets: assets)));
    check(validateGeneratedBoard('arithmatic_square', square).isEmpty,
        'Square handles solver FAILURE seed $seed');
  }
  for (final operation in [
    'addition',
    'subtraction',
    'multiplication',
    'division'
  ]) {
    final symbol = {
      'addition': '+',
      'subtraction': '−',
      'multiplication': '×',
      'division': '÷'
    }[operation]!;
    final square = await withAlgorithmPath(
        AlgorithmPath.candidate,
        () => withSquareGenerationPath(
            SquareGenerationPath.constructive,
            () => withGeneratorSeed(
                1234,
                () => ArithmeticSquareGenerator(
                        grade: 4,
                        level: 20,
                        difficultyConfig: DifficultyManager.getDifficulty(
                            GenerationSettings(grade: 4), 20),
                        useCustomSettings: true,
                        customOps: {operation},
                        customMin: 1,
                        customMax: 20)
                    .generate())));
    check(square.validateSolution(square.fullSolution),
        'Custom $operation square validates');
    check(square.getAllOperators().every((op) => op == symbol),
        'Custom $operation square retains requested operation');
    check(square.fullSolution.values.every((n) => n >= 1 && n <= 20),
        'Custom square retains requested range');
  }
  final comparisonRows = [
    for (final path in SquareGenerationPath.values)
      {
        'game': 'arithmatic_square',
        'grade': 4,
        'level': 20,
        'algorithm': 'candidate',
        'squarePath': path.name,
        'mechanic': '+',
        'language': 'neutral',
        'generationMs': path.index + 1
      }
  ];
  for (final stratified in [false, true]) {
    final groups = summarizeCalibration(comparisonRows, stratified: stratified);
    check(groups.length == 2 && groups.every((row) => row['samples'] == 1),
        'Square A/B report keeps candidate paths separate');
  }
  final fixtureBytes = utf8.encode(
      '\r\n{"game":"square","operator":"÷","language":"für"}\r\n\n{"game":"launch"}');
  final fixtureChunks = [
    for (var i = 0; i < fixtureBytes.length; i += 3)
      fixtureBytes.sublist(i, (i + 3).clamp(0, fixtureBytes.length))
  ];
  final decoded =
      await decodeCalibrationFixtures(Stream.fromIterable(fixtureChunks))
          .toList();
  check(
      decoded.length == 2 &&
          decoded.first['operator'] == '÷' &&
          decoded.first['language'] == 'für' &&
          decoded.last['game'] == 'launch',
      'Streaming fixtures handles chunked UTF-8, blank lines, CRLF and final line');
  check(
      (await decodeCalibrationFixtures(Stream.value(utf8.encode('\n ')))
              .toList())
          .isEmpty,
      'Empty fixture stream stays empty');
  for (final invalid in ['[]', '{bad json}']) {
    var context = false;
    try {
      await decodeCalibrationFixtures(Stream.value(utf8.encode('\n$invalid')),
              source: 'capture.jsonl')
          .toList();
    } on FormatException catch (error) {
      context = error.message.contains('capture.jsonl:2:');
    }
    check(context, 'Malformed fixture includes source and line');
  }
  stdout.writeln('$checks algorithm path checks passed.');
}
