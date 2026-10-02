import 'robot_path_logic.dart';
import 'algorithm_path.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'alien_tribunal_logic.dart';
import 'vault_cracker_logic.dart';
import 'orbital_towers_logic.dart';
import 'ion_chain_logic.dart';
import 'hull_plating_logic.dart';
import 'board_hint_engine.dart' show solveLights;
import 'magic_triangle_solver.dart';
import 'round_generation.dart';
import 'void_crossing_logic.dart';
import 'comm_relay_logic.dart';

Map<String, dynamic> boardMap(Object? raw) => raw is Map
    ? raw.map((k, v) => MapEntry(k.toString(), v))
    : raw is List
        ? {
            for (final pair in raw)
              if (pair is List && pair.length == 2) pair[0].toString(): pair[1]
          }
        : {};
List<dynamic> boardList(Object? raw) => raw is List ? raw : [];

/// Checks rules independently of generator retries; unknown proofs stay explicit.
List<String> validateGeneratedBoard(String game, Map<String, dynamic> state) {
  final errors = <String>[];
  void check(bool valid, String rule) {
    if (!valid) errors.add(rule);
  }

  final p = boardMap(state['puzzle'] ?? state['_puzzle']);
  final solution = boardMap(p['fullSolution'] ?? p['solution']);
  final encoded = jsonEncode(state);
  check(jsonEncode(jsonDecode(encoded)) == encoded,
      'JSON round trip changed the board');
  // Every exposed clue must agree with the recorded reference solution.
  for (final field in ['clues', 'playerHints', 'visibleValues']) {
    for (final e in boardMap(p[field]).entries) {
      final expected = solution[e.key] ??
          (p['fullSolution'] is List && int.tryParse(e.key) != null
              ? boardList(p['fullSolution']).elementAt(int.parse(e.key))
              : null);
      if (expected != null) {
        check(
            expected == e.value, '$field disagrees with solution at ${e.key}');
      }
    }
  }
  num calculate(num a, num b, String op) => switch (op) {
        '+' || 'addition' => a + b,
        '-' || '−' => a - b,
        'subtraction' => (a - b).abs(),
        '*' || '×' || 'x' || 'multiplication' => a * b,
        '/' || '÷' || 'division' => b == 0 ? double.nan : a / b,
        _ => double.nan
      };
  void mathFact(Map<String, dynamic> fact) {
    if (fact.isEmpty) return;
    final a = fact['operandA'], b = fact['operandB'];
    if (a is num && b is num) {
      check(
          calculate(
                  a,
                  b,
                  fact['operation'] is int
                      ? [
                          'addition',
                          'subtraction',
                          'multiplication',
                          'division'
                        ][fact['operation']]
                      : fact['operation'] as String) ==
              fact['answer'],
          'Incorrect arithmetic fact');
    }
  }

  for (final field in ['levelProblems', '_mathProblems']) {
    for (final f in boardList(state[field])) {
      mathFact(boardMap(f));
    }
  }
  mathFact(boardMap(state['currentProblem']));
  switch (game) {
    case 'number_walls':
      final h = p['wallHeight'] as int, s = List<int>.from(p['fullSolution']);
      check(s.length == h * (h + 1) ~/ 2, 'Wall has wrong number of cells');
      for (int r = 0; r < h - 1; r++) {
        for (int c = 0; c <= r; c++) {
          final i = r * (r + 1) ~/ 2 + c, j = (r + 1) * (r + 2) ~/ 2 + c;
          final a = s[j], b = s[j + 1], v = s[i], op = p['operation'];
          check(
              op == 'division'
                  ? (b != 0 && a / b == v) || (a != 0 && b / a == v)
                  : calculate(a, b, op as String) == v,
              'Wall relation fails at $i');
        }
      }
      final counts = <int, int>{};
      for (final v in boardList(p['numberPool'])) {
        counts[v as int] = (counts[v] ?? 0) + 1;
      }
      for (final i in boardList(p['hiddenCells'])) {
        final v = s[i as int];
        check((counts[v] ?? 0) > 0, 'Pool missing hidden value $v');
        counts[v] = (counts[v] ?? 0) - 1;
      }
    case 'solarpanel_game':
      final s = List<int>.from(p['fullSolution']);
      check(
          s.length == 6 &&
              s[0] == s[1] + s[2] &&
              s[1] == s[3] * s[4] &&
              s[2] == s[4] * s[5],
          'Solar panel arithmetic fails');
    case 'magic_triangles':
      final values = List<int>.from(p['allNumbers']),
          n = p['circlesPerSide'] as int;
      final solved = solveMagicTriangle(n, values);
      check(solved != null, 'Triangle has no equal-sum arrangement');
    case 'arithmatic_square':
      final n = p['gridSize'] as int;
      for (int r = 0; r < n; r++) {
        num value = solution['r${r}c0'];
        for (int c = 1; c < n - 1; c++) {
          value = calculate(
              value, solution['r${r}c$c'], p['rowOperators'][r][c - 1]);
        }
        check(value == solution['r${r}c${n - 1}'],
            'Arithmetic square row $r fails');
      }
      for (int c = 0; c < n; c++) {
        num value = solution['r0c$c'];
        for (int r = 1; r < n - 1; r++) {
          value = calculate(
              value, solution['r${r}c$c'], p['columnOperators'][c][r - 1]);
        }
        check(value == solution['r${n - 1}c$c'],
            'Arithmetic square column $c fails');
      }
    case 'arithmancer_crosswords':
      for (final eq in boardList(p['equations'])) {
        final cells = boardList(eq['numberCells']);
        final v = [
          for (final cell in cells) solution['C_${cell[1]}_${cell[0]}'] as int
        ];
        check(calculate(v[0], v[1], eq['operator']) == v[2],
            'Crossword equation fails');
      }
    case 'nebula_matrix':
    case 'orbital_towers':
    case 'kenken':
      final n = p['size'] as int;
      for (int i = 0; i < n; i++) {
        for (final ids in [
          List.generate(n, (j) => 'r${i}c$j'),
          List.generate(n, (j) => 'r${j}c$i')
        ]) {
          final values = ids.map((id) => solution[id]).toSet();
          check(
              values.length == n &&
                  values.every((v) => v is int && v >= 1 && v <= n),
              'Latin row/column fails');
        }
      }
      if (game == 'nebula_matrix') {
        for (final zone in boardList(p['zones'])) {
          check(boardList(zone).map((id) => solution[id]).toSet().length == n,
              'Sudoku zone fails');
        }
      }
      if (game == 'orbital_towers') {
        check(
            OrbitalTowersPuzzle.fromJson(p)
                .validateSolution(Map<String, int>.from(solution)),
            'Tower edge clue fails');
      }
      if (game == 'kenken') {
        final covered = <String>[];
        for (final cage in boardList(p['cages'])) {
          final cells = List<String>.from(cage['cells']);
          covered.addAll(cells);
          final values = cells.map((id) => solution[id] as int).toList();
          final target =
              int.parse(RegExp(r'\d+').firstMatch(cage['clue'])![0]!);
          final op = cage['op'];
          final result = op == null
              ? values.single
              : op == '+'
                  ? values.reduce((a, b) => a + b)
                  : op == '×'
                      ? values.reduce((a, b) => a * b)
                      : op == '-'
                          ? (values[0] - values[1]).abs()
                          : values.reduce(math.max) / values.reduce(math.min);
          check(result == target, 'KenKen cage clue fails');
        }
        check(covered.length == n * n && covered.toSet().length == n * n,
            'KenKen cages do not partition the grid');
      }
    case 'star_forge':
      check(solution.values.toSet().length == p['nodeCount'],
          'Star repeats values');
      for (final line in boardList(p['lines'])) {
        check(
            boardList(line).fold<int>(
                    0, (s, id) => s + (solution[id.toString()] as int)) ==
                p['magicConstant'],
            'Star arm sum fails');
      }
    case 'codebreaker':
      final key = boardMap(p['fullSolution']);
      for (final eq in boardList(p['equations'])) {
        num value(dynamic x) => x is num ? x : key[x.toString()] as num;
        check(
            calculate(value(eq['term1']), value(eq['term2']), eq['op']) ==
                value(eq['result']),
            'Codebreaker equation fails');
      }
    case 'cryptex_lock_breaker':
      final values = List<int>.from(p['solution']);
      for (final eq in boardList(p['equations'])) {
        final ids = List<int>.from(eq['leftOperandIndices']);
        final v = eq['operator'] == '-'
            ? (values[ids[0]] - values[ids[1]]).abs()
            : calculate(values[ids[0]], values[ids[1]], eq['operator']);
        check(
            v ==
                (eq['resultDialIndex'] == null
                    ? eq['rightSide']
                    : values[eq['resultDialIndex']]),
            'Cryptex equation fails');
      }
    case 'alien_tribunal':
      final model = AlienTribunalPuzzle.fromJson(p),
          solutions = model.findAllSolutions();
      check(solutions.length == 1,
          'Tribunal assignment is ambiguous or impossible');
      check(model.checkSolution(model.getSolution()),
          'Tribunal reference answer fails');
    case 'crew_manifest':
      final names = List<String>.from(p['crewNames']),
          items = List<String>.from(p['itemNames']),
          clues = boardList(p['structuredClues']);
      var count = 0;
      void visit(Map<String, String> assignment, Set<String> used) {
        if (assignment.length == names.length) {
          if (clues.every((c) => c['type'] == 'positive'
              ? assignment[c['crewName']] == c['itemName']
              : assignment[c['crewName']] != c['itemName'])) {
            count++;
          }
          return;
        }
        final name = names[assignment.length];
        for (final item in items) {
          if (!used.contains(item)) {
            assignment[name] = item;
            visit(assignment, {...used, item});
            assignment.remove(name);
          }
        }
      }
      visit({}, {});
      check(count == 1, 'Crew assignment is ambiguous or impossible');
    case 'vault_cracker':
      final model = VaultCrackerPuzzle.fromJson(p);
      var count = 0;
      void visit(List<int> digits) {
        if (count > 1) return;
        if (digits.length == model.codeLength) {
          if (model.clues.every((c) => c.check(digits))) count++;
          return;
        }
        for (int i = 1; i <= model.digitRange; i++) {
          visit([...digits, i]);
        }
      }
      visit([]);
      check(count == 1, 'Vault clues are ambiguous or impossible');
    case 'gravity_well':
      for (final scale in boardList(p['scales'])) {
        int sum(dynamic side) => boardList(side)
            .fold<int>(0, (s, item) => s + (item['weight'] as int));
        check(sum(scale['leftSide']) == sum(scale['rightSide']),
            'Scale is unbalanced');
      }
    case 'launch_sequence':
      final seq = List<int>.from(p['sequence']);
      int inversions = 0;
      for (int i = 0; i < seq.length; i++) {
        for (int j = i + 1; j < seq.length; j++) {
          if (seq[i] > seq[j]) inversions++;
        }
      }
      check(inversions == p['optimalSwaps'],
          'Sorting minimum swaps is incorrect');
      check(
          (seq.toList()..sort()).join(',') == boardList(p['target']).join(','),
          'Sorting sequence is not a permutation');
    case 'dark_matter_grid':
      final grid =
          boardList(state['grid']).map((r) => List<bool>.from(r)).toList();
      final taps = solveLights(grid);
      check(taps != null, 'Lights are unsolvable');
      if (taps != null) {
        final n = grid.length;
        for (final i in taps) {
          for (final (dr, dc) in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final r = i ~/ n + dr, c = i % n + dc;
            if (r >= 0 && r < n && c >= 0 && c < n) grid[r][c] = !grid[r][c];
          }
        }
        check(grid.every((r) => r.every((v) => v)),
            'Lights solution replay fails');
      }
    case 'ion_chain':
      final model = IonChainPuzzle.fromJson(p);
      check(IonChainPuzzle.validateChain(model.solution, model.rules),
          'Ion solution violates neighbour rules');
    case 'hull_plating':
      final model = HullPlatingPuzzle.fromJson(p);
      check(
          HullPlatingPuzzle.validatePlacement(
              model.solution, model.board, model.rows, model.cols),
          'Hull solution does not cover board');
    case 'relic_assembly':
      final rows = p['rows'] as int,
          cols = p['cols'] as int,
          tiles = boardList(p['solutionTiles']);
      check(tiles.length == rows * cols, 'Relic tile count fails');
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final edge = tiles[r * cols + c]['edges'];
          if (c + 1 < cols) {
            check(edge[1] == tiles[r * cols + c + 1]['edges'][3],
                'Relic horizontal edge mismatch');
          }
          if (r + 1 < rows) {
            check(edge[2] == tiles[(r + 1) * cols + c]['edges'][0],
                'Relic vertical edge mismatch');
          }
        }
      }
    case 'sector_painter':
      final regions = boardList(p['regions']), adj = boardMap(p['adjacency']);
      final colors = <String, int>{};
      bool color(int i) {
        if (i == regions.length) return true;
        final id = regions[i].toString();
        for (int c = 0; c < (p['availableColors'] as int); c++) {
          if (boardList(adj[id]).every((v) => colors[v.toString()] != c)) {
            colors[id] = c;
            if (color(i + 1)) return true;
            colors.remove(id);
          }
        }
        return false;
      }
      check(color(0), 'Sector graph is not colourable');
    case 'warp_fold':
      check(
          boardList(p['options'])
                  .where((o) => jsonEncode(o) == jsonEncode(p['correctResult']))
                  .length ==
              1,
          'Fold options do not have exactly one correct answer');
    case 'cube_scanner':
      final choices = boardList(p['choices']);
      check(
          choices.toSet().length == choices.length &&
              choices.where((c) => c == p['correctAnswer']).length == 1,
          'Cube choices are invalid');
    case 'circuit_repair':
      final digits = List<int>.from(p['displayedDigits']),
          a = p['swapPosA'] as int,
          b = p['swapPosB'] as int;
      final v = digits[a];
      digits[a] = digits[b];
      digits[b] = v;
      check(digits.join(',') == boardList(p['correctDigits']).join(','),
          'Circuit swap replay fails');
    case 'block_counter':
      final blocks = boardList(p['blockStructure']['blocks']);
      check(blocks.length == p['correctAnswer'], 'Block counting answer fails');
      check(
          boardList(p['answerChoices'])
                  .where((v) => v == p['correctAnswer'])
                  .length ==
              1,
          'Block choices fail');
    case 'perspective_puzzle':
      final blocks = boardList(p['structure']),
          views = boardList(p['correctViews']);
      check(
          blocks.isNotEmpty && views.length == 4, 'Perspective views missing');
      for (final view in views) {
        for (final row in boardList(view[1])) {
          for (final b in boardList(row)) {
            if (b != null) {
              check(blocks.any((v) => jsonEncode(v) == jsonEncode(b)),
                  'Perspective projects a nonexistent block');
            }
          }
        }
      }
    case 'star_chart_scan':
      for (final e in boardList(p['placedEquations'])) {
        final text = boardList(e['cells'])
            .map((cell) => p['grid'][cell[0]][cell[1]])
            .join();
        check(
            text == e['equation'], 'Equation search placement is overwritten');
        final m = RegExp(r'^(\d+)([+\-x])(\d+)=(\d+)$').firstMatch(text);
        check(
            m != null &&
                calculate(int.parse(m[1]!), int.parse(m[3]!), m[2]!) ==
                    int.parse(m[4]!),
            'Equation search arithmetic fails');
      }
    case 'comm_relay':
      final plain = p['plainText'] as String;
      final encrypted = switch (p['cipherType']) {
        'caesar' =>
          CommRelayPuzzle.encryptCaesar(plain, p['shiftAmount'] as int),
        'atbash' => CommRelayPuzzle.encryptAtbash(plain),
        'keyword' => _encodeKeyword(plain, p['keyword'] as String),
        _ => '',
      };
      check(encrypted == p['cipherText'],
          'Cipher mapping does not encode plaintext');
      for (final e in boardMap(p['hintLetters']).entries) {
        for (int i = 0; i < plain.length; i++) {
          if (encrypted[i] == e.key) {
            check(plain[i] == e.value, 'Cipher hint disagrees with plaintext');
          }
        }
      }
      check(
          p['plainText'] is String &&
              p['cipherText'] is String &&
              (p['plainText'] as String).length ==
                  (p['cipherText'] as String).length,
          'Cipher length differs');
    case 'asteroid_field_navigator':
      final grid = boardList(state['grid'])
          .map((r) => boardList(r)
              .map((c) => AsteroidCell.fromJson(boardMap(c)))
              .toList())
          .toList();
      check(
          grid.expand((r) => r).where((c) => c.isMine).length ==
              state['mineCount'],
          'Mine count fails');
      for (final row in grid) {
        for (final cell in row) {
          if (!cell.isMine) {
            check(
                cell.adjacentMines ==
                    countAdjacentMines(grid, cell.row, cell.col),
                'Mine neighbour count fails');
          }
        }
      }
    case 'hive_station':
      final cells = boardList(p['allCells']),
          energy = boardList(p['energyCells']);
      final keys = cells.map(jsonEncode).toSet();
      check(energy.every((c) => keys.contains(jsonEncode(c))),
          'Hive energy outside grid');
    case 'galactic_market':
      final known = boardList(state['_knownCoins'])
          .fold<int>(0, (s, c) => s + (c as int));
      check(
          known +
                  (state['_unknownCount'] as int) *
                      (state['_correctDenomination'] as int) ==
              state['_changeTotal'],
          'Coin total fails');
      check(
          boardList(state['_denomOptions'])
              .contains(state['_correctDenomination']),
          'Correct coin option missing');
    case 'xenobiology_lab':
      final third = state['_hasThirdType'] == true;
      for (final part in ['Eyes', 'Legs']) {
        final a = state['_${part.toLowerCase()}A'] as int,
            b = state['_${part.toLowerCase()}B'] as int,
            c = state['_${part.toLowerCase()}C'] as int;
        check(
            a * (state['_countA'] as int) +
                    b * (state['_countB'] as int) +
                    (third ? c * (state['_countC'] as int) : 0) ==
                state['_total$part'],
            'Census total fails');
      }
    case 'chrono_repair':
      final correct = ((state['_correctHour'] as int) % 12) * 60 +
          (state['_correctMinute'] as int);
      final displayed = ((state['_displayedHour'] as int) % 12) * 60 +
          (state['_displayedMinute'] as int);
      final expected = state['_malfunction'] == 'mirror'
          ? (720 - correct) % 720
          : (correct +
                  (state['_offsetHours'] as int) * 60 +
                  (state['_offsetMinutes'] as int)) %
              720;
      check(displayed == expected,
          'Clock transformation disagrees with reference time');
      check(
          (state['_correctHour'] as int) >= 1 &&
              (state['_correctHour'] as int) <= 12 &&
              (state['_correctMinute'] as int) % 5 == 0,
          'Clock time invalid');
    case 'asteroid_duel':
      check(
          state['_remaining'] == state['_totalAsteroids'] &&
              (state['_maxPerTurn'] as int) >= 1,
          'Nim initial state invalid');
    case 'asteroid_math':
    case 'planet_hopping':
      final facts = game == 'asteroid_math'
          ? boardList(state['levelProblems'])
          : boardList(state['planets']).map((p) => p['problem']).toList();
      for (final f in facts) {
        mathFact(boardMap(f));
      }
      check(
          facts.isNotEmpty &&
              facts.map((f) => f['answer']).toSet().length == facts.length,
          'Targets are empty or duplicated');
    case 'hyperdrive_gates':
    case 'pathfinder':
      final choices = boardList(state['choices']),
          answer = state['currentProblem']['answer'];
      check(
          choices.toSet().length == choices.length &&
              choices.where((c) => c == answer).length == 1,
          'Route choices fail');
    case 'puzzle_math':
      final pieces = boardList(state['pieces']);
      check(pieces.length == (state['rows'] as int) * (state['columns'] as int),
          'Jigsaw piece count fails');
      for (final piece in pieces) {
        mathFact(boardMap(piece['problem']));
      }
    case 'grid_filler_game':
      final n = state['_pieceTypes'] as int, size = state['gridSize'] as int;
      final area = boardList(state['availablePieces']).fold<int>(
          0,
          (s, p) =>
              s +
              (p['count'] as int) * (p['size'] as int) * (p['size'] as int));
      check(area == size * size && size == n * (n + 1) ~/ 2,
          'Grid filler area cannot tile grid');
    case 'signal_triangulation':
      final secret = boardList(state['secret']);
      check(
          secret.length == state['length'] &&
              secret.every((g) => boardList(state['glyphs']).contains(g)),
          'Signal secret invalid');
    case 'cargo_bay_arranger':
      for (final name in ['currentPiece', 'nextPiece']) {
        final piece = state[name];
        final shape = boardList(piece['shape']),
            cubes = boardList(piece['cubes']);
        var filled = 0;
        for (int r = 0; r < shape.length; r++) {
          for (int c = 0; c < boardList(shape[r]).length; c++) {
            if (shape[r][c] == true) {
              filled++;
              check(
                  cubes[r][c] != null &&
                      cubes[r][c]['value'] >= state['numberMin'] &&
                      cubes[r][c]['value'] <= state['numberMax'],
                  'Cargo value out of range');
            } else {
              check(cubes[r][c] == null, 'Cargo cube outside shape');
            }
          }
        }
        check(filled == 4, 'Cargo shape is not tetromino');
      }
    case 'arithmancer_duel':
      check(boardList(state['hand']).isNotEmpty, 'Duel starting hand empty');
    case 'quantum_molecule_builder':
      final data = boardMap(state['levelData']);
      check(
          boardList(data['playfield']).isNotEmpty &&
              boardList(data['solution']).isNotEmpty,
          'Molecule board missing');
    case 'space_station_gridlock':
      check(
          boardList(state['ships']).isNotEmpty &&
              (state['minMoves'] as int) > 0,
          'Gridlock board missing');
    case 'robot_path_game':
      final level = boardMap(state['currentLevel']),
          grid = boardList(level['grid']);
      check(
          grid[level['startRow']][level['startCol']] == 'start' &&
              grid[level['goalRow']][level['goalCol']] == 'goal',
          'Robot start/goal missing');
      final board = PathLevel.fromJson(level);
      final solution = solveRobotCommands(board);
      check(solution != null, 'Robot commands have no bounded proof');
      if (solution != null) {
        check((state['maxCommands'] as int) >= solution.length,
            'Robot command allowance is below proven solution');
        if (algorithmPath != AlgorithmPath.legacy) {
          check(board.optimalMoves == solution.length,
              'Robot reference omits commands');
        }
      }
    case 'star_loader_game':
      check((state['_optimalMoves'] as int) > 0,
          'Star Loader reference pushes missing');
      if (state['generationMode'] == 'bundled') {
        check((state['_optimalMoves'] as int) >= state['requestedMinPushes'],
            'Star Loader below requested floor');
      }
    case 'void_crossing':
      final optimum = VoidCrossingLogic.solve(VoidCrossingPuzzle.fromJson(p));
      check(optimum > 0 && optimum == p['optimalMoves'],
          'Crossing reference is not the BFS optimum');
      check((p['maxMoves'] as int) >= optimum,
          'Crossing allowance is below optimum');
      check(
          boardList(p['entities']).length >= 3 &&
              (p['optimalMoves'] as int) > 0,
          'Crossing puzzle invalid');
    default:
      errors.add('No validator for $game');
  }
  return errors;
}

String _encodeKeyword(String plain, String keyword) {
  final alphabet = <String>{
    ...keyword.toUpperCase().split(''),
    ...List.generate(26, (i) => String.fromCharCode(65 + i))
  }.toList();
  return plain
      .split('')
      .map((c) =>
          RegExp(r'[A-Z]').hasMatch(c) ? alphabet[c.codeUnitAt(0) - 65] : c)
      .join();
}
