// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/features/games/services/algorithm_path.dart';
import '../lib/features/games/services/cargo_generation.dart';
import '../lib/features/games/services/cargo_row_generation.dart';
import 'cargo_row_scenarios.dart';

Future<void> main() async {
  var checks = 0;
  void check(bool condition, String message) {
    checks++;
    if (!condition) throw StateError(message);
  }

  for (var grade = 1; grade <= 6; grade++) {
    for (final level in [1, 10, 20]) {
      for (var shape = 0; shape < 7; shape++) {
        for (var rotation = 0; rotation < 4; rotation++) {
          final input = cargoScenario(grade, level, shape, rotation,
              grade * 100 + shape * 7 + rotation);
          final before = jsonEncode([input.board, input.piece.toJson()]);
          final result = await withAlgorithmPath(
              AlgorithmPath.candidate,
              () => generateCargoRowValues(
                  baseline: input.piece,
                  board: input.board,
                  minValue: input.config.numberMin,
                  maxValue: input.config.numberMax,
                  targetSum: input.config.targetSum,
                  assistanceChance: 1,
                  random: Random(42)));
          check(result.landing != null,
              'Planted reachable target missing g$grade l$level s$shape r$rotation');
          final placed =
              replayCargoLanding(input.board, result.piece, result.landing!);
          check(
              result.targetRows.every((r) =>
                  placed[r].every((v) => v != null) &&
                  placed[r].whereType<int>().reduce((a, b) => a + b) ==
                      input.config.targetSum),
              'Actual rotated/drop cubes fail target');
          check(jsonEncode([input.board, input.piece.toJson()]) == before,
              'Candidate mutated inputs');
          final beforeCubes = input.piece.cubes
              .expand((row) => row)
              .whereType<CargoCube>()
              .toList();
          final afterCubes = result.piece.cubes
              .expand((row) => row)
              .whereType<CargoCube>()
              .toList();
          check(
              List.generate(
                      4, (i) => beforeCubes[i].color == afterCubes[i].color)
                  .every((v) => v),
              'Candidate changed colours');
          final changed = <int>{};
          for (var r = 0; r < result.landing!.cells.length; r++) {
            if (result.targetRows.contains(result.landing!.y + r)) {
              changed.addAll(result.landing!.cells[r].whereType<int>());
            }
          }
          check(
              List.generate(
                      4,
                      (i) =>
                          changed.contains(i) ||
                          beforeCubes[i].value == afterCubes[i].value)
                  .every((v) => v),
              'Candidate changed unrelated values');
          check(jsonEncode(result.piece.shape) == jsonEncode(input.piece.shape),
              'Shape bag was overridden');
          check(
              result.piece.cubes.expand((r) => r).whereType<CargoCube>().every(
                  (cube) =>
                      cube.value >= input.config.numberMin &&
                      cube.value <= input.config.numberMax),
              'Values out of range');
          final legacy = await withAlgorithmPath(
              AlgorithmPath.legacy,
              () => generateCargoRowValues(
                  baseline: input.piece,
                  board: input.board,
                  minValue: input.config.numberMin,
                  maxValue: input.config.numberMax,
                  targetSum: input.config.targetSum,
                  assistanceChance: 1));
          check(identical(legacy.piece, input.piece),
              'Baseline path was changed');
        }
      }
    }
  }
  final input = cargoScenario(6, 20, 1, 0, 20261002);
  for (final board in [
    List.generate(18, (_) => List<int?>.filled(8, null)),
    [List<int?>.filled(8, 5), ...input.board.skip(1)],
    [
      for (final row in input.board)
        row.map((v) => v == null ? null : 1000).toList()
    ]
  ]) {
    final result = await withAlgorithmPath(
        AlgorithmPath.candidate,
        () => generateCargoRowValues(
            baseline: input.piece,
            board: board,
            minValue: 5,
            maxValue: 20,
            targetSum: 75,
            assistanceChance: 1));
    check(identical(result.piece, input.piece) && result.landing == null,
        'Infeasible/crowded board must retain baseline');
  }
  final skipped = await generateCargoRowValues(
      baseline: input.piece,
      board: input.board,
      minValue: 5,
      maxValue: 20,
      targetSum: 75,
      assistanceChance: 0);
  check(identical(skipped.piece, input.piece),
      'Zero assistance preserves preview');
  final doubleBoard = [for (final row in input.board) List<int?>.from(row)];
  doubleBoard[16] = List<int?>.from(doubleBoard[17]);
  final doubleResult = await withAlgorithmPath(
      AlgorithmPath.candidate,
      () => generateCargoRowValues(
          baseline: input.piece,
          board: doubleBoard,
          minValue: 5,
          maxValue: 20,
          targetSum: 75,
          assistanceChance: 1));
  check(doubleResult.targetRows.length == 2,
      'Square piece should solve both completed rows');
  final doublePlaced = replayCargoLanding(
      doubleBoard, doubleResult.piece, doubleResult.landing!);
  check(
      doubleResult.targetRows.every((r) =>
          doublePlaced[r].whereType<int>().reduce((a, b) => a + b) == 75),
      'Both row sums independently replay');
  final invalidBoard = [
    [1, 2],
    [1]
  ];
  final auto = await withAlgorithmPath(
      AlgorithmPath.auto,
      () => generateCargoRowValues(
          baseline: input.piece,
          board: invalidBoard,
          minValue: 5,
          maxValue: 20,
          targetSum: 75,
          assistanceChance: 1));
  check(
      identical(auto.piece, input.piece) &&
          auto.implementation == 'legacy-error-fallback',
      'Auto retains baseline on malformed board');
  var rejected = false;
  try {
    await withAlgorithmPath(
        AlgorithmPath.candidate,
        () => generateCargoRowValues(
            baseline: input.piece,
            board: invalidBoard,
            minValue: 5,
            maxValue: 20,
            targetSum: 75,
            assistanceChance: 1));
  } on ArgumentError {
    rejected = true;
  }
  check(rejected, 'Strict candidate surfaces malformed board');
  stdout.writeln('$checks Cargo row-generation checks passed.');
}
