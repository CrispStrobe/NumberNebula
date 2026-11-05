// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/board_hint_engine.dart';
import '../lib/features/games/services/generator_random.dart';
import '../lib/features/games/services/magic_triangle_puzzle.dart';
import '../lib/features/games/services/magic_triangle_solver.dart';
import '../lib/features/games/services/generation_configs.dart';
import '../lib/features/games/services/round_generation.dart';
import '../lib/features/games/constants/difficulty_manager.dart';
import '../lib/features/games/models/math_problem.dart';

List<List<int>> sides(int n) => [
  List.generate(n, (i) => i),
  List.generate(n, (i) => n - 1 + i),
  [for (var i = 2 * n - 2; i < 3 * n - 3; i++) i, 0],
];
bool deductionChain(MagicTrianglePuzzle p) {
  final remaining = Set<int>.of(p.hiddenIndices);
  while (remaining.isNotEmpty) {
    var progress = false;
    for (final side in sides(p.circlesPerSide)) {
      final missing = side.where(remaining.contains).toList();
      if (missing.length == 1) {
        remaining.remove(missing.single);
        progress = true;
      }
    }
    if (!progress) return false;
  }
  return true;
}

Map<String, dynamic> features(MagicTrianglePuzzle p) => {
  'nodesPerSide': p.circlesPerSide,
  'hidden': p.hiddenIndices.length,
  'choices': p.numberPool.length,
  'target': p.warpFrequency,
  'deductionChain': deductionChain(p),
};
void verify(MagicTrianglePuzzle p) {
  if (p.allNumbers.toSet().length != p.totalCircles ||
      p.hiddenIndices.intersection(p.visibleValues.keys.toSet()).isNotEmpty ||
      p.hiddenIndices.length + p.visibleValues.length != p.totalCircles) {
    throw StateError('Invalid partition or repeated values');
  }
  final arrangement = solveMagicTriangle(p.circlesPerSide, p.allNumbers);
  if (arrangement == null ||
      sides(p.circlesPerSide).any(
        (s) =>
            s.fold<int>(0, (sum, i) => sum + arrangement[i]) != p.warpFrequency,
      ) ||
      p.visibleValues.entries.any((e) => arrangement[e.key] != e.value) ||
      p.hiddenIndices.any((i) => !p.numberPool.contains(arrangement[i]))) {
    throw StateError('No matching solution/reference/pool');
  }
}

void verifyTeachingHints(MagicTrianglePuzzle p) {
  for (final german in [false, true]) {
    final hidden = p.hiddenIndices.toList()..sort();
    final answers = List<int?>.filled(hidden.length, null);
    final state = <String, dynamic>{
      'currentPuzzle': p.toJson(),
      'userAnswers': answers,
    };
    for (var step = 0; step < hidden.length; step++) {
      final before = jsonEncode(state);
      final hint = findBoardHint('magic_triangles', state, german: german);
      if (jsonEncode(state) != before ||
          hint == null ||
          !hint.verified ||
          hint.value is! int ||
          hint.target == null) {
        throw StateError(
          'An introductory hint must explain a compatible move without changing the board',
        );
      }
      final global = int.parse(hint.target!);
      final index = hidden.indexOf(global);
      if (index < 0 || answers[index] != null) {
        throw StateError('Hint targets an unavailable node');
      }
      answers[index] = hint.value as int;
    }
    if (!p.checkSolution(answers.cast<int>()).isPerfect) {
      throw StateError(
        'Following the hints does not complete the actual game rules',
      );
    }
  }
}

void main(List<String> args) {
  final smoke = args.contains('--smoke');
  final rows = <Map<String, dynamic>>[];
  final grades = smoke ? [1, 3] : [1, 2, 3, 4, 5, 6];
  final levels = smoke ? [1, 3] : List.generate(20, (i) => i + 1);
  for (final grade in grades) {
    var previousNodes = 0, previousHidden = 0, previousChoices = 0;
    for (final level in levels) {
      final profile = MagicTriangleGenerationConfig(grade, level);
      if (profile.circlesPerSide < previousNodes ||
          profile.hiddenCount < previousHidden ||
          profile.hiddenCount + profile.decoyCount < previousChoices) {
        throw StateError('Structural progression decreased');
      }
      previousNodes = profile.circlesPerSide;
      previousHidden = profile.hiddenCount;
      previousChoices = profile.hiddenCount + profile.decoyCount;
      for (final seed in [31, 97, 211]) {
        MagicTrianglePuzzle generate(AlgorithmPath path) => withAlgorithmPath(
          path,
          () => withGeneratorSeed(
            seed,
            () =>
                MagicTrianglePuzzle.generate({'grade': grade, 'level': level}),
          ),
        );
        final old = generate(AlgorithmPath.legacy),
            candidate = generate(AlgorithmPath.candidate);
        verify(old);
        verify(candidate);
        if (profile.requireDeductionChain) verifyTeachingHints(candidate);
        final automatic = generate(AlgorithmPath.auto);
        if (jsonEncode(automatic.toJson()) != jsonEncode(candidate.toJson())) {
          throw StateError('Auto/candidate mismatch');
        }
        if (candidate.circlesPerSide != profile.circlesPerSide ||
            candidate.hiddenIndices.length != profile.hiddenCount ||
            candidate.numberPool.length !=
                profile.hiddenCount + profile.decoyCount ||
            (profile.requireDeductionChain && !deductionChain(candidate))) {
          throw StateError(
            'Profile or introductory deduction failed: grade=$grade level=$level seed=$seed',
          );
        }
        final count = grade <= 1
            ? 4
            : grade == 2
            ? 6
            : grade == 3
            ? 9
            : 12;
        final jigsaw = withGeneratorSeed(
          seed,
          () => generateJigsawProblems(
            GenerationSettings(grade: grade),
            level,
            const NoProblemReviews(),
            count,
          ),
        );
        rows.add({
          'grade': grade,
          'level': level,
          'seed': seed,
          'legacyTriangle': features(old),
          'candidateTriangle': features(candidate),
          'jigsawIndependentTasks': count,
          'jigsawExpressions': jigsaw.map((f) => f.expression).toList(),
        });
      }
    }
  }
  final report = {
    'cases': rows.length,
    'gitHead': Process.runSync('git', [
      'rev-parse',
      'HEAD',
    ]).stdout.toString().trim(),
    'workingTreeDirty': Process.runSync('git', [
      'status',
      '--porcelain',
    ]).stdout.toString().trim().isNotEmpty,
    'failures': 0,
    'empiricallyCalibrated': false,
    'limits':
        'Structural constraints and actual seeded generation only. No measured child performance or claim of equal felt difficulty.',
    'casesByProfile': rows,
  };
  final output = args.indexOf('--output');
  if (output >= 0) File(args[output + 1]).writeAsStringSync(jsonEncode(report));
  stdout.writeln(
    'PASS: ${rows.length} paired profiles; legacy/candidate/auto solved and introductory deduction verified.',
  );
  for (final row in rows.where(
    (r) => r['grade'] == 3 && r['level'] == 3 && r['seed'] == 31,
  )) {
    stdout.writeln(jsonEncode(row));
  }
}
