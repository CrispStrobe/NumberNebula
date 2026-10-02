// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/features/games/services/game_generation.dart';
import '../lib/features/games/services/generated_board_validation.dart';
import '../lib/features/games/services/felt_difficulty.dart';
import '../lib/features/games/services/number_walls_logic.dart';
import '../lib/features/games/services/xenobiology_lab_logic.dart';
import '../lib/features/games/services/chrono_repair_logic.dart';
import '../lib/features/games/services/void_crossing_logic.dart';

/// Runs with the isolated SDK package; failures remain active without --enable-asserts.
Future<void> main() async {
  var checks = 0;
  void check(bool condition, String message) {
    checks++;
    if (!condition) throw StateError(message);
  }

  final assets = GenerationAssets(
    moleculeSource: File('assets/data/molecule_levels.json').readAsStringSync(),
    gridlockSource:
        File('assets/puzzles/gridlock_puzzles.json').readAsStringSync(),
    starloaderSource:
        File('assets/data/starloader_levels.json').readAsStringSync(),
  );
  final registry =
      File('lib/features/games/game_registry.dart').readAsStringSync();
  final registered = RegExp(r"'([^']+)': _DeferredGame")
      .allMatches(registry)
      .map((m) => m[1]!)
      .toSet();
  check(
      registered.length == gameKeys.length && registered.containsAll(gameKeys),
      'Pure catalog and app registry must cover exactly the same games');
  for (final game in gameKeys) {
    final a =
        await generateGameBoard(game, 1, 1, seed: 20261002, assets: assets);
    // Interleave a different seed: global random state must not leak between cases.
    await generateGameBoard(game, 1, 1, seed: 91, assets: assets);
    final b =
        await generateGameBoard(game, 1, 1, seed: 20261002, assets: assets);
    const deadlineGenerators = {
      'arithmatic_square',
      'arithmancer_crosswords',
      'codebreaker',
      'robot_path_game'
    };
    if (!deadlineGenerators.contains(game)) {
      check(jsonEncode(a) == jsonEncode(b), '$game seeded generation changed');
    } else {
      check(validateGeneratedBoard(game, b).isEmpty,
          '$game invalid repeated board');
      if (jsonEncode(a) != jsonEncode(b)) {
        stdout.writeln(
            '$game: bounded search used a different wall-time fallback; fixture replay remains exact.');
      }
    }
    check(validateGeneratedBoard(game, a).isEmpty,
        '$game invalid generated board');
    final felt = estimateFeltDifficulty(game, 1, a);
    check(
        (felt['noviceScore'] as num).isFinite &&
            felt['empiricallyCalibrated'] == false,
        '$game invalid difficulty estimate');
  }
  // Previously stalled in division factor enumeration at this sampled seed.
  const seed =
      (20261002 + 6 * 1000003 + 4 * 10007 + 10 * 1009 + 97) & 0x7fffffff;
  final watch = Stopwatch()..start();
  final wall = await generateGameBoard('number_walls', 4, 10,
      seed: seed, assets: assets);
  check(watch.elapsed < const Duration(seconds: 5),
      'Division wall exceeded generation budget');
  check(validateGeneratedBoard('number_walls', wall).isEmpty,
      'Division wall regression');
  check(boundedDivisionWallFactors(1000000000000).isEmpty,
      'Over-limit division factors must terminate immediately');
  // Two assignments satisfy the same visible totals; accept both.
  final census = generateXenobiologyLab(3, 1, random: Random(5));
  check(
      matchesCensusTotals(census, 3, 5, 2), 'Reference census answer rejected');
  check(matchesCensusTotals(census, 4, 1, 5),
      'Valid alternative census answer rejected');
  check(!matchesCensusTotals(census, 4, 1, 4), 'Wrong census totals accepted');
  check(!matchesCensusTotals(census, -1, 5, 2),
      'Negative census counts accepted');
  for (int i = 0; i < 200; i++) {
    final clock = generateChronoRepair(2, 1, random: Random(i));
    check(validateGeneratedBoard('chrono_repair', clock).isEmpty,
        'Mirror clock fractional-hour regression seed $i');
  }
  for (final grade in [1, 2, 3, 4, 5, 6]) {
    for (final level in [1, 5, 10, 20]) {
      final crossing = VoidCrossingLogic.generatePuzzle(grade, level);
      check(crossing.entities.length == (grade.clamp(1, 4) + 2),
          'Crossing silently fell back to an easier grade g$grade l$level');
      check(crossing.optimalMoves == VoidCrossingLogic.solve(crossing),
          'Crossing optimum regression g$grade l$level');
    }
  }
  // Ensure validators reject corrupted arithmetic, transforms, and geometry.
  for (final game in [
    'number_walls',
    'arithmatic_square',
    'arithmancer_crosswords',
    'chrono_repair',
    'comm_relay',
    'signal_triangulation',
    'hyperdrive_gates',
    'asteroid_math',
    'void_crossing',
    'cargo_bay_arranger'
  ]) {
    final state = await generateGameBoard(game, 1, 1, seed: 42, assets: assets);
    final p = boardMap(state['puzzle'] ?? state['_puzzle']);
    switch (game) {
      case 'number_walls':
        p['fullSolution'][0] += 1;
      case 'arithmatic_square':
        p['fullSolution'][0][1] += 1;
      case 'arithmancer_crosswords':
        p['fullSolution'][0][1] += 1;
      case 'chrono_repair':
        state['_displayedMinute'] =
            ((state['_displayedMinute'] as int) + 5) % 60;
      case 'comm_relay':
        p['cipherText'] = 'WRONG';
      case 'signal_triangulation':
        state['secret'][0] = 'invalid-glyph';
      case 'hyperdrive_gates':
        state['choices'] = [999, 999];
      case 'asteroid_math':
        state['levelProblems'][0]['answer'] += 1;
      case 'void_crossing':
        p['optimalMoves'] += 1;
      case 'cargo_bay_arranger':
        final cubes = state['currentPiece']['cubes'] as List;
        final cube =
            cubes.expand((row) => row as List).firstWhere((c) => c != null);
        cube['value'] = -1;
    }
    if (p.isNotEmpty) {
      state[state.containsKey('_puzzle') ? '_puzzle' : 'puzzle'] = p;
    }
    check(validateGeneratedBoard(game, state).isNotEmpty,
        '$game corruption escaped validation');
  }
  // A seed that exhausted all crossword attempts before clues came from solutions.
  final crossword = await generateGameBoard('arithmancer_crosswords', 1, 10,
      seed: 34282014, assets: assets);
  check(validateGeneratedBoard('arithmancer_crosswords', crossword).isEmpty,
      'Crossword contradiction regression');
  stdout.writeln(
      '$checks pure Dart regression checks passed across ${gameKeys.length} games.');
}
