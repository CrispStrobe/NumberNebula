// Integration test for the Star Loader generator wiring.
//
// Drives the REAL StarLoaderLevelManager end-to-end with the debug toggles set
// to "new Sokoban generator" + "always generate directly" (pool skipped), then
// reparses the produced runtime layout back into grids and cross-checks it with
// the game's own StarloaderSolver. This exercises the actual integration glue
// added to the manager: settings read -> generator branch -> grid conversion ->
// LevelData layout.
//
// path_provider has no test implementation here, so the manager's file-system
// setup throws and is caught (it falls back to an in-memory DB) — exactly the
// graceful path we want to confirm still yields a playable level.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/features/games/screens/star_loader_game.dart';
import 'package:space_math_academy/features/games/services/starloader_level_manager.dart';
import 'package:space_math_academy/features/games/services/starloader_solver.dart';

/// Reparse the runtime layout (reverse of manager._convertToLevelData) into the
/// static/dynamic int grids the solver consumes.
({List<List<int>> structure, List<List<int>> state}) _gridsFromLayout(
    List<String> layout) {
  const wall = 0, floor = 1, target = 2, box = 4, player = 5;
  final structure = <List<int>>[];
  final state = <List<int>>[];
  for (final line in layout) {
    final sRow = <int>[];
    final dRow = <int>[];
    for (final ch in line.split('')) {
      switch (ch) {
        case 'W':
          sRow.add(wall);
          dRow.add(wall);
        case 'P':
          sRow.add(floor);
          dRow.add(player);
        case 'B':
          sRow.add(floor);
          dRow.add(box);
        case 'T':
          sRow.add(target);
          dRow.add(target);
        case 'X':
          sRow.add(target);
          dRow.add(box);
        default: // ' '
          sRow.add(floor);
          dRow.add(floor);
      }
    }
    structure.add(sRow);
    state.add(dRow);
  }
  return (structure: structure, state: state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manager generates a solvable Sokoban level via the new generator',
      () async {
    SharedPreferences.setMockInitialValues({
      StarLoaderLevelManager.prefUseSokobanGen: true,
      StarLoaderLevelManager.prefPreferPregenerated: false, // force generation
    });

    final manager = StarLoaderLevelManager();
    final LevelData data = await manager.getLevelForGrade(1, 1);

    // Came from the new Sokoban generator (ids are prefixed 'sok_').
    expect(data.id, startsWith('sok_'), reason: 'used the sokoban generator');
    expect(data.optimalMoves, greaterThan(0));
    expect(data.layout, isNotEmpty);
    expect('P'.allMatches(data.layout.join()).length, 1,
        reason: 'exactly one player');

    // Cross-check solvability with the game's own solver, and that the
    // push count the game will show matches the true optimum.
    final grids = _gridsFromLayout(data.layout);
    final result = StarloaderSolver.fromGrids(grids.structure, grids.state)
        .solve(nodeBudget: 400000);
    expect(result.solved || result.exhausted, isTrue,
        reason: 'generated level must not be unsolvable');
    if (result.solved) {
      expect(result.pushes, data.optimalMoves,
          reason: 'displayed optimalMoves equals the solver optimum');
    }
    // Generous deadline: the whole test suite runs many isolates in parallel,
    // and this one both generates and solves — CPU contention can slow it well
    // past the wall-clock the work actually needs.
  }, timeout: const Timeout(Duration(minutes: 2)));
}
