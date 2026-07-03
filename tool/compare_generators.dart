// ignore_for_file: avoid_print
// tool/compare_generators.dart
//
// Dev utility: A/B the two Star Loader level generators (the new
// difficulty-parametrized Sokoban generator vs the legacy reverse-play
// LevelGenerator) on the same grades. Reports push-count / box-count
// distributions and a "richness" proxy, and renders a couple of samples from
// each so a human can eyeball playability.
//
//   dart run tool/compare_generators.dart [--count=20]

import 'package:space_math_academy/features/games/services/sokoban_generator.dart'
    as sok;
import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

const _gradeToDifficulty = {1: 2, 2: 3, 3: 4, 4: 5};
// Legacy per-grade sizing (mirrors StarLoaderLevelManager._generateLegacyEntry).
const _legacy = {
  1: [7, 7, 2, 6],
  2: [8, 8, 3, 9],
  3: [10, 10, 3, 13],
  4: [12, 11, 4, 17],
};

String _render(List<List<int>> structure, List<List<int>> state) {
  const sl = {0: '#', 1: ' ', 2: '.', 4: r'$', 5: '@'};
  final sb = StringBuffer();
  for (var r = 0; r < state.length; r++) {
    for (var c = 0; c < state[r].length; c++) {
      final s = state[r][c];
      // box-on-target => '*'
      if (s == 4 && structure[r][c] == 2) {
        sb.write('*');
      } else {
        sb.write(sl[s] ?? '?');
      }
    }
    sb.write('\n');
  }
  return sb.toString();
}

class _Stats {
  final pushes = <int>[];
  final boxes = <int>[];
  final nodes = <int>[];
  int trivial = 0; // pushes <= boxes*2 (barely more than one push each)
  int fail = 0;

  void report(String label) {
    if (pushes.isEmpty) {
      print('  $label: no levels');
      return;
    }
    pushes.sort();
    double avg(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;
    final med = pushes[pushes.length ~/ 2];
    print('  $label:  n=${pushes.length}  '
        'pushes avg=${avg(pushes).toStringAsFixed(1)} '
        'med=$med min=${pushes.first} max=${pushes.last}  '
        'boxes avg=${avg(boxes).toStringAsFixed(1)}  '
        'nodes med=${nodes.isEmpty ? '-' : (nodes..sort())[nodes.length ~/ 2]}  '
        'trivial=$trivial fail=$fail');
  }
}

void main(List<String> args) {
  var count = 20;
  for (final a in args) {
    if (a.startsWith('--count=')) count = int.parse(a.split('=')[1]);
  }
  final legacyGen = LevelGenerator(verbose: false);

  for (final grade in [1, 2, 3, 4]) {
    print('\n=== GRADE $grade '
        '(sokoban d=${_gradeToDifficulty[grade]}) ===');

    // --- New Sokoban generator ---
    final sokStats = _Stats();
    List<List<int>>? sokSampleStruct, sokSampleState;
    for (var i = 0; i < count; i++) {
      try {
        final e = sok.generateStarLoaderEntry(
            difficulty: _gradeToDifficulty[grade]!, timeBudget: 6);
        final res =
            StarloaderSolver.fromGrids(e.roomStructure, e.roomState)
                .solve(nodeBudget: 400000);
        if (!res.solved && !res.exhausted) {
          sokStats.fail++;
          continue;
        }
        final boxes = _countBoxes(e.roomState);
        sokStats.pushes.add(e.optimalMoves);
        sokStats.boxes.add(boxes);
        if (e.optimalMoves <= boxes * 2) sokStats.trivial++;
        if (i == 0) {
          sokSampleStruct = e.roomStructure;
          sokSampleState = e.roomState;
        }
      } catch (_) {
        sokStats.fail++;
      }
    }

    // --- Legacy generator ---
    final legStats = _Stats();
    List<List<int>>? legSampleStruct, legSampleState;
    final p = _legacy[grade]!;
    for (var i = 0; i < count; i++) {
      try {
        final g = legacyGen.generateLevel(
          dimX: p[0], dimY: p[1], numBoxes: p[2],
          maxTries: 20, minOptimalPushes: p[3],
        );
        final res =
            StarloaderSolver.fromGrids(g.roomStructure, g.roomState)
                .solve(nodeBudget: 400000);
        if (!res.solved && !res.exhausted) {
          legStats.fail++;
          continue;
        }
        final boxes = _countBoxes(g.roomState);
        legStats.pushes.add(g.optimalMoves);
        legStats.boxes.add(boxes);
        if (g.optimalMoves <= boxes * 2) legStats.trivial++;
        if (i == 0) {
          legSampleStruct = g.roomStructure;
          legSampleState = g.roomState;
        }
      } catch (_) {
        legStats.fail++;
      }
    }

    sokStats.report('SOKOBAN');
    legStats.report('LEGACY ');
    if (sokSampleStruct != null) {
      print('  --- sokoban sample ---');
      print(_render(sokSampleStruct, sokSampleState!)
          .split('\n')
          .map((l) => '    $l')
          .join('\n'));
    }
    if (legSampleStruct != null) {
      print('  --- legacy sample ---');
      print(_render(legSampleStruct, legSampleState!)
          .split('\n')
          .map((l) => '    $l')
          .join('\n'));
    }
  }
}

int _countBoxes(List<List<int>> state) {
  var n = 0;
  for (final row in state) {
    for (final v in row) {
      if (v == 4) n++;
    }
  }
  return n;
}
