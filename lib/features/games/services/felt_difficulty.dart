import 'dart:math' as math;
import 'generated_board_validation.dart' show boardMap, boardList;

/// An explicit, untrained workload heuristic. Ordinal bands are estimates for
/// two proficiency scenarios, not measured success probabilities or ages.
Map<String, dynamic> estimateFeltDifficulty(
    String game, int grade, Map<String, dynamic> state) {
  final p =
      boardMap(state['puzzle'] ?? state['_puzzle'] ?? state['currentPuzzle']);
  final hidden = boardList(p['emptyCells'] ??
      p['emptyNodes'] ??
      p['hiddenCells'] ??
      p['hiddenIndices']);
  var units = hidden.length.toDouble(),
      arithmetic = 0.0,
      spatial = 0.0,
      planning = 0.0,
      reading = 0.0;
  final reasons = <String>[];
  final prerequisites = <String>[];
  final facts = <Map<String, dynamic>>[];
  for (final field in ['levelProblems', '_mathProblems']) {
    facts.addAll(boardList(state[field]).map(boardMap));
  }
  for (final planet in boardList(state['planets'])) {
    facts.add(boardMap(planet['problem']));
  }
  for (final piece in boardList(state['pieces'])) {
    facts.add(boardMap(piece['problem']));
  }
  final current = boardMap(state['currentProblem']);
  if (current.isNotEmpty) facts.add(current);
  if (facts.isNotEmpty) {
    units = facts.length.toDouble();
    for (final fact in facts) {
      final a = (fact['operandA'] as num? ?? 0).abs(),
          b = (fact['operandB'] as num? ?? 0).abs();
      final op = fact['operation'];
      final weight = op == 2
          ? 1.6
          : op == 3
              ? 2.0
              : 1.0;
      final digits =
          math.max(a.toInt().toString().length, b.toInt().toString().length);
      arithmetic += weight + math.max(0, digits - 1) * 0.7;
      if (op == 0 && a % 10 + b % 10 >= 10) arithmetic += 0.5;
      if (op == 1 && a % 10 < b % 10) arithmetic += 0.5;
    }
    arithmetic /= facts.length;
    prerequisites.add('Arithmetic facts or counting/decomposition');
    reasons.add(
        '${facts.length} arithmetic decisions; operand size and operation type affect workload.');
  }
  switch (game) {
    case 'star_chart_scan':
      units = boardList(p['equations']).length.toDouble();
      spatial = 1.5;
      arithmetic = 1.5;
      planning = 0.8;
      reasons.add(
          'Find arithmetic equations among distractors in a two-dimensional grid.');
      prerequisites.add('Visual scanning and checking arithmetic');
    case 'comm_relay':
      units = (p['plainText'] as String).replaceAll(' ', '').length.toDouble();
      reading = 1.5;
      planning = p['cipherType'] == 'keyword' ? 2.5 : 1.5;
      reasons.add(
          'Decode $units letters using ${p['cipherType']} substitution rules.');
      prerequisites.add('Letter recognition, rule tracking and reading');
    case 'launch_sequence':
    case 'circuit_repair':
      final reference = p['optimalMoves'] ?? p['optimalSwaps'];
      units = reference is num
          ? reference.toDouble()
          : boardList(p['sequence']).length.toDouble();
      planning = 1.3 + math.min(2.5, units / 10);
      spatial = game == 'circuit_repair' ? 1.2 : 0.3;
      reasons.add(
          'Ordering or connectivity must be restored through successive swaps.');
      prerequisites.add('Ordering and planning intermediate states');
    case 'number_walls':
    case 'solarpanel_game':
    case 'arithmatic_square':
    case 'arithmancer_crosswords':
    case 'codebreaker':
    case 'kenken':
    case 'star_forge':
    case 'magic_triangles':
      final op = p['operation'];
      arithmetic = math.max(
          arithmetic, op == 'multiplication' || op == 'division' ? 2.6 : 1.5);
      final total = (p['nodeCount'] ??
          p['totalCells'] ??
          p['size'] ??
          p['gridSize'] ??
          0) as num;
      final clues =
          boardMap(p['clues'] ?? p['playerHints'] ?? p['visibleValues']).length;
      planning = 1 + math.min(2.5, hidden.length / math.max(1, clues) * 0.4);
      if (game == 'codebreaker') {
        units = boardList(p['hiddenSymbols']).length.toDouble();
        planning = 2.5;
      }
      if (game == 'arithmancer_crosswords') reading = 0.5;
      reasons.add(
          '$units unknown placements; $clues visible clues constrain inference.');
      prerequisites.add('Inverse arithmetic and intersecting constraints');
      if (total > 12) spatial = 0.5;
    case 'nebula_matrix':
    case 'orbital_towers':
      final size = p['size'] as num;
      planning = 1.2 + size / 5 + hidden.length / (size * size);
      if (game == 'orbital_towers') spatial = 1.3;
      reasons.add(
          '${hidden.length} empty cells with row/column constraints${game == 'orbital_towers' ? ' and directional visibility' : ''}.');
      prerequisites.add('Elimination across simultaneous constraints');
    case 'alien_tribunal':
    case 'crew_manifest':
    case 'vault_cracker':
    case 'gravity_well':
    case 'xenobiology_lab':
    case 'galactic_market':
    case 'cryptex_lock_breaker':
      units = game == 'alien_tribunal'
          ? boardList(p['people']).length.toDouble()
          : game == 'crew_manifest'
              ? (p['size'] as num).toDouble()
              : game == 'vault_cracker'
                  ? (p['length'] as num).toDouble()
                  : game == 'gravity_well'
                      ? boardMap(p['unknownWeights']).length.toDouble()
                      : game == 'xenobiology_lab'
                          ? state['_hasThirdType'] == true
                              ? 3
                              : 2
                          : game == 'galactic_market'
                              ? 1
                              : (p['dialCount'] as num).toDouble();
      planning = game == 'galactic_market' ? 1 : 1.8 + units / 5;
      arithmetic = math.max(arithmetic,
          game == 'alien_tribunal' || game == 'crew_manifest' ? 0 : 1.5);
      reading = game == 'alien_tribunal' ||
              game == 'crew_manifest' ||
              game == 'vault_cracker'
          ? 1.4
          : 0.3;
      reasons.add(
          '$units coupled unknowns; visible totals/clues must be combined.');
      prerequisites.add('Multi-step deduction or inverse arithmetic');
    case 'perspective_puzzle':
    case 'block_counter':
    case 'warp_fold':
    case 'cube_scanner':
      final blocks = boardList(p['structure']).isNotEmpty
          ? boardList(p['structure'])
          : boardList(boardMap(p['blockStructure'])['blocks']);
      final folds = boardList(p['folds']).length,
          dice = boardList(p['dice']).length;
      units = game == 'block_counter'
          ? blocks.length.toDouble()
          : game == 'perspective_puzzle'
              ? 4
              : 1;
      spatial = game == 'block_counter'
          ? 1 +
              blocks.where((b) => b['isVisible'] == false).length /
                  math.max(1, blocks.length) *
                  2
          : game == 'perspective_puzzle'
              ? 2.5
              : game == 'warp_fold'
                  ? 1 + folds * 0.7
                  : 1 + dice * 0.5;
      planning = game == 'warp_fold' ? folds * 0.5 : 0.5;
      reasons.add(
          'Spatial workload: ${blocks.length} cubes, $folds folds, $dice dice (where applicable).');
      prerequisites.add('Mental projection, hidden objects or rotation');
    case 'robot_path_game':
    case 'star_loader_game':
    case 'space_station_gridlock':
    case 'void_crossing':
    case 'quantum_molecule_builder':
      final level = boardMap(state['currentLevel']);
      final reference = state['_optimalMoves'] ??
          state['minMoves'] ??
          level['optimalMoves'] ??
          p['optimalMoves'];
      units = reference is num
          ? reference.toDouble()
          : boardList(state['atoms']).length * 3.0;
      planning = 1.5 + math.min(3, units / 15);
      spatial = 1.2;
      if (game == 'void_crossing') {
        final entities = boardList(p['entities']).length;
        final conflicts = boardList(p['conflicts']).length;
        planning += entities * 0.05 + conflicts * 0.15;
        reasons.add(
            '$entities entities and $conflicts conflict rules must be tracked across both banks.');
      }
      reasons.add(reference is num
          ? 'Reference solution requires $reference actions; ordering and dead ends add planning load.'
          : 'No verified optimum; atom count is a rough workload proxy.');
      prerequisites
          .add('Planning ahead, state tracking and recovery from dead ends');
    case 'signal_triangulation':
      units = (state['length'] as num).toDouble();
      final symbols = boardList(state['glyphs']).length;
      planning = math.log(math.pow(symbols, units)) / math.ln2 / 6;
      reading = 0.5;
      reasons.add(
          '$symbols symbols across $units positions; feedback must eliminate combinations.');
      prerequisites.add('Comparison, positional memory and hypothesis testing');
    case 'sector_painter':
    case 'ion_chain':
    case 'dark_matter_grid':
    case 'hive_station':
    case 'asteroid_field_navigator':
      units = game == 'sector_painter'
          ? boardList(p['regions']).length.toDouble()
          : game == 'ion_chain'
              ? boardList(p['chain']).where((v) => v == null).length.toDouble()
              : game == 'dark_matter_grid'
                  ? (p['size'] as num) * (p['size'] as num).toDouble()
                  : game == 'hive_station'
                      ? boardList(p['allCells']).length.toDouble()
                      : (state['gridRows'] as num) *
                          (state['gridCols'] as num).toDouble();
      planning = game == 'dark_matter_grid'
          ? 3
          : game == 'asteroid_field_navigator' || game == 'hive_station'
              ? 2.5
              : 1.7;
      spatial = 0.8;
      reasons.add(
          '$units cells/placements; local interactions can require revisiting decisions.');
      prerequisites.add('Neighbour constraints and deduction');
    case 'hull_plating':
    case 'relic_assembly':
    case 'grid_filler_game':
    case 'puzzle_math':
      if (game == 'hull_plating') {
        units = boardList(p['pieces']).length.toDouble();
      }
      if (game == 'relic_assembly') {
        units = boardList(p['playerTiles']).length.toDouble();
      }
      if (game == 'grid_filler_game') {
        units = boardList(state['availablePieces'])
            .fold<double>(0, (s, p) => s + (p['count'] as num));
      }
      spatial = 1.5;
      planning = 1.2 + math.min(2, units / 15);
      reasons.add(
          '$units pieces to place; shape matching and order constrain choices.');
      prerequisites.add('Spatial matching and placement planning');
    case 'cargo_bay_arranger':
      units = (state['rowsToWin'] as num).toDouble();
      planning = 2;
      spatial = 1.3;
      arithmetic = 1.5;
      reasons.add(
          'Falling pieces combine arithmetic and spatial decisions under time pressure.');
      prerequisites.add('Arithmetic while planning placements');
    case 'chrono_repair':
      units = state['_malfunction'] == 'combined' ? 2 : 1;
      spatial = state['_malfunction'] == 'mirror' ? 1.5 : 0.5;
      arithmetic = math.max(arithmetic, 1.5);
      planning = units;
      prerequisites.add('Clock reading and wraparound arithmetic');
      reasons.add('Clock transformation: ${state['_malfunction']}.');
    case 'asteroid_duel':
      units = (state['_remaining'] as num).toDouble();
      planning = 2.5;
      arithmetic = 1;
      prerequisites.add('Recognising a repeating take-away strategy');
      reasons.add(
          'Rule discovery is difficult before the modulo strategy is known; repetition becomes easy afterwards.');
    case 'arithmancer_duel':
      units = boardList(state['hand']).length.toDouble();
      arithmetic = 2;
      planning = 2;
      reading = 0.8;
      prerequisites.add('Expression construction and card rules');
      reasons.add('$units hand cards provide competing expression choices.');
  }
  final referenceValues = boardMap(p['fullSolution'] ?? p['solution'])
      .values
      .whereType<num>()
      .toList();
  if (referenceValues.isEmpty && p['fullSolution'] is List) {
    referenceValues.addAll((p['fullSolution'] as List).whereType<num>());
  }
  final largestMagnitude =
      referenceValues.fold<num>(0, (a, b) => math.max(a, b.abs()));
  if (arithmetic > 0 && largestMagnitude >= 10) {
    arithmetic +=
        math.min(2, largestMagnitude.toInt().toString().length * 0.4 - 0.4);
    reasons.add(
        'Reference values reach $largestMagnitude; larger numbers add arithmetic burden.');
  }
  final timePressure = [
    'asteroid_math',
    'hyperdrive_gates',
    'pathfinder',
    'planet_hopping',
    'cargo_bay_arranger'
  ].contains(game);
  if (timePressure) {
    reasons.add(
        'Movement or falling pieces impose time pressure; actual reaction demands require device measurements.');
  }
  final workingMemory = math.min(
      4,
      planning * (timePressure ? 1.2 : 0.8) +
          (arithmetic > 1 ? 0.4 : 0) +
          (spatial > 1 ? 0.4 : 0));
  final novice = 1 +
      arithmetic * 0.7 +
      spatial * 0.65 +
      planning * 0.7 +
      reading * 0.5 +
      workingMemory * 0.25 +
      math.log(1 + units) / math.ln2 * 0.22;
  final fluent = 1 +
      arithmetic * 0.35 +
      spatial * 0.5 +
      planning * 0.5 +
      reading * 0.25 +
      workingMemory * 0.15 +
      math.log(1 + units) / math.ln2 * 0.15;
  String band(double score) => score < 2.5
      ? 'light'
      : score < 3.5
          ? 'moderate'
          : score < 4.5
              ? 'stretch'
              : 'heavy';
  return {
    'model': 'workload-heuristic-v1',
    'empiricallyCalibrated': false,
    'confidence': 'low',
    'requestedGrade': grade,
    'workUnits': units,
    'timePressure': timePressure,
    'largestReferenceMagnitude': largestMagnitude,
    'arithmeticLoad': arithmetic,
    'spatialLoad': spatial,
    'planningLoad': planning,
    'readingLoad': reading,
    'workingMemoryLoad': workingMemory,
    'noviceScore': novice,
    'fluentScore': fluent,
    'noviceBand': band(novice),
    'fluentBand': band(fluent),
    'prerequisites': prerequisites,
    'reasons': reasons,
    'interpretation':
        'Relative workload scenarios; not a predicted age, completion time or pass rate.'
  };
}
