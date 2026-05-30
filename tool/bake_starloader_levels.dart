// Offline level baker for Cargo-Loader (StarLoader).
//
// Produces a SOLVER-VERIFIED level pool in assets/data/starloader_levels.json:
//   * Re-scores the existing baked levels with the real push-optimal solver,
//     dropping any that are unsolvable or trivial.
//   * Generates fresh solver-verified levels to top each grade up to a target
//     count, deduped by content hash.
//   * Stores the TRUE optimal push count in `optimalMoves` (the old generator
//     stored boxSwaps*displacement, which was meaningless — up to 1269 for a
//     level solvable in <25 pushes).
//
// Run:  dart run tool/bake_starloader_levels.dart [--target=24]
//
// This is a build-time tool (kept out of lib/ so it never ships). Commit the
// regenerated asset afterwards.

import 'dart:convert';
import 'dart:io';

import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

const assetPath = 'assets/data/starloader_levels.json';

// Per-grade board size, box count, and minimum real optimal-push threshold.
class GradeSpec {
  final int grade;
  final int dimX;
  final int dimY;
  final int numBoxes;
  final int minPushes;
  const GradeSpec(this.grade, this.dimX, this.dimY, this.numBoxes, this.minPushes);
}

const specs = [
  GradeSpec(1, 7, 7, 2, 6),
  GradeSpec(2, 8, 8, 3, 9),
  GradeSpec(3, 10, 10, 3, 13),
  GradeSpec(4, 12, 11, 4, 17),
];

String _contentHash(List<List<int>> structure, List<List<int>> state) {
  final b = StringBuffer();
  for (final row in structure) {
    b.write(row.join(''));
  }
  b.write('|');
  for (final row in state) {
    b.write(row.join(''));
  }
  return b.toString();
}

void main(List<String> args) {
  var target = 24;
  for (final a in args) {
    if (a.startsWith('--target=')) target = int.parse(a.split('=')[1]);
  }

  final gen = LevelGenerator();
  final kept = <int, List<Map<String, dynamic>>>{for (final s in specs) s.grade: []};
  final seen = <int, Set<String>>{for (final s in specs) s.grade: {}};
  final specByGrade = {for (final s in specs) s.grade: s};

  // 1. Re-score and filter the existing baked levels.
  var reExisting = 0, droppedUnsolvable = 0, droppedTrivial = 0;
  final existing = File(assetPath).existsSync()
      ? (jsonDecode(File(assetPath).readAsStringSync())['levels'] as List)
      : const [];
  for (final l in existing) {
    final grade = int.parse((l['difficulty'] as String).split('_')[1]);
    final spec = specByGrade[grade];
    if (spec == null) continue;
    final structure =
        (l['roomStructure'] as List).map((r) => List<int>.from(r)).toList();
    final state =
        (l['roomState'] as List).map((r) => List<int>.from(r)).toList();
    final res = StarloaderSolver.fromGrids(structure, state)
        .solve(nodeBudget: 500000);
    if (!res.solved) {
      droppedUnsolvable++;
      continue;
    }
    if (res.pushes! < spec.minPushes) {
      droppedTrivial++;
      continue;
    }
    final hash = _contentHash(structure, state);
    if (!seen[grade]!.add(hash)) continue;
    kept[grade]!.add({
      'id': l['id'],
      'difficulty': 'grade_$grade',
      'dimX': l['dimX'],
      'dimY': l['dimY'],
      'roomStructure': structure,
      'roomState': state,
      'optimalMoves': res.pushes, // corrected to TRUE push count
      'avgRating': 0.0,
      'ratingCount': 0,
    });
    reExisting++;
  }
  stdout.writeln('Existing: kept $reExisting, dropped $droppedUnsolvable '
      'unsolvable + $droppedTrivial trivial.');

  // 2. Generate fresh solver-verified levels to reach the target per grade.
  for (final spec in specs) {
    var generated = 0;
    var attempts = 0;
    final maxAttempts = target * 60; // bounded effort
    while (kept[spec.grade]!.length < target && attempts < maxAttempts) {
      attempts++;
      final level = gen.generateLevel(
        dimX: spec.dimX,
        dimY: spec.dimY,
        numBoxes: spec.numBoxes,
        maxTries: 12,
        minOptimalPushes: spec.minPushes,
        solverNodeBudget: 500000,
      );
      // Skip the trivial straight-corridor fallback (no real target placement).
      if (level.optimalMoves < spec.minPushes) continue;
      final hash = _contentHash(level.roomStructure, level.roomState);
      if (!seen[spec.grade]!.add(hash)) continue;
      kept[spec.grade]!.add({
        'id': 'baked_g${spec.grade}_${kept[spec.grade]!.length}',
        'difficulty': 'grade_${spec.grade}',
        'dimX': spec.dimX,
        'dimY': spec.dimY,
        'roomStructure': level.roomStructure,
        'roomState': level.roomState,
        'optimalMoves': level.optimalMoves,
        'avgRating': 0.0,
        'ratingCount': 0,
      });
      generated++;
    }
    final pushes =
        kept[spec.grade]!.map((e) => e['optimalMoves'] as int).toList()..sort();
    stdout.writeln('grade_${spec.grade}: ${kept[spec.grade]!.length} levels '
        '(+$generated new in $attempts attempts), '
        'push range ${pushes.first}..${pushes.last}');
  }

  // 3. Write the asset (matches LevelDatabase.toJson).
  final all = <Map<String, dynamic>>[];
  for (final s in specs) {
    all.addAll(kept[s.grade]!);
  }
  final out = const JsonEncoder.withIndent('  ').convert({'levels': all});
  File(assetPath).writeAsStringSync(out);
  stdout.writeln('Wrote ${all.length} levels to $assetPath');
}
