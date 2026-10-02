import 'algorithm_path.dart';
import 'arithmetic_tables.dart';
import 'generator_random.dart';
import 'dart:math' as math;
import 'generator_diagnostics.dart';
import 'dart:async';
import 'package:dart_csp/dart_csp.dart';
import '../constants/difficulty_config.dart';

class ArithmeticSquarePuzzle {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'clues': clues.entries.map((v0) => [v0.key, v0.value]).toList(),
        'playerHints':
            playerHints.entries.map((v0) => [v0.key, v0.value]).toList(),
        'emptyCells': emptyCells.map((v0) => v0).toList(),
        'rowOperators':
            rowOperators.map((v0) => v0.map((v1) => v1).toList()).toList(),
        'columnOperators':
            columnOperators.map((v0) => v0.map((v1) => v1).toList()).toList(),
        'numberPool': numberPool.map((v0) => v0).toList(),
        'fullSolution':
            fullSolution.entries.map((v0) => [v0.key, v0.value]).toList()
      };
  factory ArithmeticSquarePuzzle.fromJson(Map<String, dynamic> json) =>
      ArithmeticSquarePuzzle(
          gridSize: json['gridSize'] as int,
          clues: Map<String, int>.fromEntries((json['clues'] as List)
              .map((v0) => MapEntry(v0[0] as String, v0[1] as int))),
          playerHints: Map<String, int>.fromEntries((json['playerHints'] as List)
              .map((v0) => MapEntry(v0[0] as String, v0[1] as int))),
          emptyCells:
              (json['emptyCells'] as List).map((v0) => v0 as String).toSet(),
          rowOperators: (json['rowOperators'] as List)
              .map((v0) => (v0 as List).map((v1) => v1 as String).toList())
              .toList(),
          columnOperators: (json['columnOperators'] as List)
              .map((v0) => (v0 as List).map((v1) => v1 as String).toList())
              .toList(),
          numberPool:
              (json['numberPool'] as List).map((v0) => v0 as int).toList(),
          fullSolution: Map<String, int>.fromEntries(
              (json['fullSolution'] as List)
                  .map((v0) => MapEntry(v0[0] as String, v0[1] as int))));

  final int gridSize;
  final Map<String, int> clues; // CSP clues for generation
  final Map<String, int> playerHints; // Player-visible hints
  final Set<String> emptyCells;
  final List<List<String>> rowOperators;
  final List<List<String>> columnOperators;
  final List<int> numberPool;
  final Map<String, int> fullSolution;

  ArithmeticSquarePuzzle({
    required this.gridSize,
    required this.clues,
    required this.playerHints,
    required this.emptyCells,
    required this.rowOperators,
    required this.columnOperators,
    required this.numberPool,
    required this.fullSolution,
  });

  static Future<ArithmeticSquarePuzzle> generate(
      Map<String, dynamic> args) async {
    if (kDebugMode) {
      traceGenerator(
          "🎯 [ARITHMETIC SQUARE FACTORY] Starting puzzle generation with args: $args");
    }

    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps =
        (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    if (kDebugMode) {
      traceGenerator(
          "🎯 [ARITHMETIC SQUARE FACTORY] Using difficulty config: ${difficultyConfig.grade}");
    }

    final generator = ArithmeticSquareGenerator(
      grade: grade,
      level: level,
      difficultyConfig: difficultyConfig,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );

    return generator.generate();
  }

  bool validateSolution(Map<String, int> userSolution) {
    if (kDebugMode) {
      traceGenerator("✅ [VALIDATION] Starting solution validation");
    }

    // Create complete grid with CSP clues, player hints, and user solution
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(playerHints);
    completeGrid.addAll(userSolution);

    // Validate all rows
    for (int r = 0; r < gridSize; r++) {
      if (!validateSingleEquation(completeGrid, r, true)) {
        if (kDebugMode) {
          traceGenerator("✅ [VALIDATION] ❌ Row $r validation failed");
        }
        return false;
      }
    }

    // Validate all columns
    for (int c = 0; c < gridSize; c++) {
      if (!validateSingleEquation(completeGrid, c, false)) {
        if (kDebugMode) {
          traceGenerator("✅ [VALIDATION] ❌ Column $c validation failed");
        }
        return false;
      }
    }

    if (kDebugMode) traceGenerator("✅ [VALIDATION] ✅ Solution is valid!");
    return true;
  }

  /// NEW: Validate a single equation (row or column)
  /// Used for real-time SRI logging as equations are completed
  bool validateSingleEquation(Map<String, int> grid, int index, bool isRow) {
    final operators = isRow ? rowOperators[index] : columnOperators[index];
    final values = <int>[];

    // Gather all values for this equation
    for (int i = 0; i < gridSize; i++) {
      final cellId = isRow ? 'r${index}c$i' : 'r${i}c$index';
      final value = grid[cellId];
      if (value == null) return false; // Can't validate incomplete equation
      values.add(value);
    }

    // Calculate left side of equation using the exact same logic as gensq.dart
    final calculatedResult =
        _evaluateEquation(values.sublist(0, values.length - 1), operators);
    final expectedResult = values.last;

    final isValid = calculatedResult == expectedResult;
    if (kDebugMode) {
      traceGenerator(
          "✅ [VALIDATION] ${isRow ? 'Row' : 'Column'} $index: calculated=$calculatedResult, expected=$expectedResult, valid=$isValid");
    }

    return isValid;
  }

  int? _evaluateEquation(List<int> operands, List<String> ops) {
    // Direct port of the evaluate function from gensq.dart
    int currentVal = operands[0];
    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      final nextVal = operands[i + 1];
      switch (op) {
        case '+':
          currentVal += nextVal;
          break;
        case '−':
        case '-':
          currentVal -= nextVal;
          break;
        case '×':
        case '*':
          currentVal *= nextVal;
          break;
        case '÷':
        case '/':
          if (nextVal == 0 || currentVal % nextVal != 0) return null;
          currentVal ~/= nextVal;
          break;
        default:
          return null;
      }
    }
    return currentVal;
  }

  List<String> getAllOperators() {
    final allOps = <String>[];
    for (final row in rowOperators) {
      allOps.addAll(row);
    }
    for (final col in columnOperators) {
      allOps.addAll(col);
    }
    return allOps;
  }
}

/// Generator using the exact same CSP approach as gensq.dart, with strategic player hints
class ArithmeticSquareGenerator {
  final int grade;
  final int level;
  final DifficultyConfig difficultyConfig;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customMin;
  final int customMax;
  final math.Random _random = generatorRandom();

  /// Fallback flag: when the normal (possibly ×/÷) difficulty can't be
  /// generated inside the budget, force +/− only — those are near-instant and
  /// essentially always satisfiable — so the player always gets a puzzle.
  bool _forceSimpleOps = false;
  bool _useTables = false;

  ArithmeticSquareGenerator({
    required this.grade,
    required this.level,
    required this.difficultyConfig,
    required this.useCustomSettings,
    required this.customOps,
    required this.customMin,
    required this.customMax,
  });

  Future<ArithmeticSquarePuzzle> generate() async {
    if (algorithmPath == AlgorithmPath.legacy) {
      recordAlgorithm('arithmetic-square', 'legacy');
      return _generateLegacy();
    }
    if (squareGenerationPath == SquareGenerationPath.constructive) {
      try {
        final puzzle = await _generateConstructive();
        if (puzzle != null && puzzle.validateSolution(puzzle.fullSolution)) {
          recordAlgorithm('arithmetic-square', 'candidate-constructive');
          return puzzle;
        }
      } catch (_) {
        if (algorithmPath == AlgorithmPath.candidate) rethrow;
      }
      if (algorithmPath == AlgorithmPath.candidate) {
        throw StateError('Constructive square failed verification');
      }
    }
    _useTables = true;
    try {
      final puzzle = await _generateLegacy();
      if (puzzle.validateSolution(puzzle.fullSolution)) {
        recordAlgorithm(
            'arithmetic-square',
            _forceSimpleOps
                ? 'candidate-simple-operations-fallback'
                : 'candidate');
        return puzzle;
      }
    } catch (_) {
      if (algorithmPath == AlgorithmPath.candidate) rethrow;
    }
    if (algorithmPath == AlgorithmPath.candidate) {
      throw StateError('Candidate square failed verification');
    }
    recordAlgorithm('arithmetic-square', 'legacy-fallback');
    _useTables = false;
    _forceSimpleOps = false;
    return withAlgorithmPath(AlgorithmPath.legacy, _generateLegacy);
  }

  /// Solve a union of allowed arithmetic relations, then select an operator
  /// supported by each solved triple. Unlike random operator assignment, this
  /// cannot choose an impossible multiplication/division layout in advance.
  Future<ArithmeticSquarePuzzle?> _generateConstructive() async {
    final domain = _getNumberDomain();
    final ops = _getAvailableOperators();
    final relations = <String, Map<int, Map<int, Set<int>>>>{};
    for (final op in ops) {
      final index = <int, Map<int, Set<int>>>{};
      for (final tuple in arithmeticTriples(domain, op)) {
        index
            .putIfAbsent(tuple[0] as int, () => {})
            .putIfAbsent(tuple[1] as int, () => {})
            .add(tuple[2] as int);
      }
      if (index.isNotEmpty) relations[op] = index;
    }
    if (relations.isEmpty) return null;
    final union = <int, Map<int, Set<int>>>{};
    for (final relation in relations.values) {
      for (final a in relation.entries) {
        for (final b in a.value.entries) {
          union
              .putIfAbsent(a.key, () => {})
              .putIfAbsent(b.key, () => {})
              .addAll(b.value);
        }
      }
    }
    final cells = [
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) 'r${r}c$c'
    ];
    final equations = [
      for (var r = 0; r < 3; r++) [for (var c = 0; c < 3; c++) 'r${r}c$c'],
      for (var c = 0; c < 3; c++) [for (var r = 0; r < 3; r++) 'r${r}c$c'],
    ];
    bool supports(String op, List<String> vars, Map<String, dynamic> values) =>
        relations[op]?[values[vars[0]]]?[values[vars[1]]]
            ?.contains(values[vars[2]]) ??
        false;
    final advancedOps = relations.keys
        .where((op) => op == '×' || op == '÷')
        .toList()
      ..shuffle(_random);
    final anchorVars = equations[_random.nextInt(equations.length)];
    Map<String, dynamic>? solved;
    // A locally feasible advanced relation may still be incompatible with the
    // whole grid. Try each under its own cap, then relax only the anchor.
    for (final anchor in <String?>[...advancedOps, null]) {
      final problem = Problem();
      for (final cell in cells) {
        problem.addVariable(cell, domain);
      }
      for (final vars in equations) {
        problem.addConstraint(
            vars,
            (values) =>
                union[values[vars[0]]]?[values[vars[1]]]
                    ?.contains(values[vars[2]]) ??
                false);
      }
      if (anchor != null) {
        problem.addConstraint(
            anchorVars, (values) => supports(anchor, anchorVars, values));
      }
      final token = CancellationToken();
      final timer = Timer(const Duration(milliseconds: 500), token.cancel);
      try {
        final result = await problem.getSolutionWithRestarts(
            seed: generatorSolverSeed(),
            useDomWdeg: true,
            scale: 50,
            maxRestarts: 200,
            cancelToken: token);
        solved = result is Map ? Map<String, dynamic>.from(result) : null;
      } finally {
        timer.cancel();
      }
      if (solved != null) {
        recordAlgorithm('arithmetic-square-anchor', anchor ?? 'unanchored');
        break;
      }
    }
    if (solved == null) return null;
    final solution = solved.map((key, value) => MapEntry(key, value as int));
    final selected = equations.map((vars) {
      final matching =
          relations.keys.where((op) => supports(op, vars, solution)).toList();
      // Prefer an advanced operation when the actual numbers support it.
      final advanced = matching.where((op) => op == '×' || op == '÷').toList();
      return [_randChoice(advanced.isEmpty ? matching : advanced)];
    }).toList();
    final rowOps = selected.take(3).toList();
    final colOps = selected.skip(3).toList();
    final hints = _selectPlayerHints(3, rowOps, colOps, solution, {});
    final empty = cells.where((cell) => !hints.containsKey(cell)).toSet();
    return ArithmeticSquarePuzzle(
        gridSize: 3,
        clues: {},
        playerHints: hints,
        emptyCells: empty,
        rowOperators: rowOps,
        columnOperators: colOps,
        numberPool: _generateNumberPool(
            empty.map((cell) => solution[cell]!).toList(),
            hints.values.toList()),
        fullSolution: solution);
  }

  Future<ArithmeticSquarePuzzle> _generateLegacy() async {
    if (kDebugMode) {
      traceGenerator("🔧 [GENERATOR] Starting arithmetic square generation");
    }

    const maxAttempts = 120;
    const totalBudget = Duration(seconds: 6);
    final sw = Stopwatch()..start();

    // Defensive hard wall-clock cap. The 3x3 grid (see _determineGridSize)
    // already keeps every solve under ~40ms, but this guards against any future
    // difficulty widening: a hard CSP instance can run for tens of seconds and
    // `.timeout()` does NOT reliably interrupt the solver (measured worst case:
    // 69s under a 15s timeout). A Timer that cancels this shared token fires in
    // real wall-clock time on every platform — including Flutter web, where
    // compute() runs on the main thread — so generation always returns promptly
    // instead of freezing the UI.
    final token = CancellationToken();
    final deadline = Timer(totalBudget, token.cancel);

    try {
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        if (token.isCancelled || sw.elapsed >= totalBudget) {
          if (kDebugMode) {
            traceGenerator(
                "🔧 [GENERATOR] ⏰ Budget exhausted after ${sw.elapsedMilliseconds}ms / $attempt attempts");
          }
          break;
        }
        if (kDebugMode) {
          traceGenerator(
              "🔧 [GENERATOR] === Attempt $attempt/$maxAttempts ===");
        }

        try {
          final puzzle = await _attemptGeneration(token);
          if (puzzle != null) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [GENERATOR] ✅ SUCCESS! Generated valid puzzle on attempt $attempt (${sw.elapsedMilliseconds}ms)");
            }
            return puzzle;
          }
        } catch (e) {
          if (kDebugMode) {
            traceGenerator("🔧 [GENERATOR] ❌ Attempt $attempt failed: $e");
          }
        }
      }
    } finally {
      deadline.cancel();
    }

    // Fallback: nothing satisfiable was found in the budget — which can happen
    // on the slow web build for ×/÷-heavy grades. Force an addition/subtraction
    // puzzle (near-instant, essentially always satisfiable) so the player gets
    // a puzzle instead of a failure dialog.
    _forceSimpleOps = true;
    final fbToken = CancellationToken();
    final fbDeadline = Timer(const Duration(seconds: 3), fbToken.cancel);
    try {
      for (int attempt = 1; attempt <= 60 && !fbToken.isCancelled; attempt++) {
        try {
          final puzzle = await _attemptGeneration(fbToken);
          if (puzzle != null) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [GENERATOR] ✅ Fallback (+/−) puzzle generated");
            }
            return puzzle;
          }
        } catch (_) {}
      }
    } finally {
      fbDeadline.cancel();
    }

    throw Exception(
        "Failed to generate a valid puzzle within ${totalBudget.inSeconds}s");
  }

  Future<ArithmeticSquarePuzzle?> _attemptGeneration(
      CancellationToken token) async {
    // Step 1: Determine grid size and operators (same logic as gensq.dart)
    final gridSize = _determineGridSize();
    final availableOps = _getAvailableOperators();

    // Step 2: Randomly generate operators for each row and column
    final rowOperators = <List<String>>[];
    final columnOperators = <List<String>>[];

    for (int r = 0; r < gridSize; r++) {
      final ops = <String>[];
      for (int i = 0; i < gridSize - 2; i++) {
        ops.add(_randChoice(availableOps));
      }
      rowOperators.add(ops);
    }

    for (int c = 0; c < gridSize; c++) {
      final ops = <String>[];
      for (int i = 0; i < gridSize - 2; i++) {
        ops.add(_randChoice(availableOps));
      }
      columnOperators.add(ops);
    }

    if (kDebugMode) {
      traceGenerator(
          "🔧 [GENERATOR] Generated ${gridSize}x$gridSize grid with operators");
    }

    // Step 3: Generate CSP clues (minimal, just for solving)
    final clues = <String, int>{};
    final numCSPClues = _determineNumberOfCSPClues(gridSize);
    final allCells = <String>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        allCells.add('r${r}c$c');
      }
    }

    // Avoid result cells when possible for CSP clues
    final nonResultCells = allCells
        .where((cellId) => !_isResultCell(cellId, gridSize))
        .toList()
      ..shuffle(_random);
    final cspClueCells = nonResultCells.take(numCSPClues).toList();

    final domain = _getNumberDomain();
    for (final cellId in cspClueCells) {
      clues[cellId] = _randChoice(domain);
    }

    if (kDebugMode) {
      traceGenerator("🔧 [GENERATOR] Generated $numCSPClues CSP clues: $clues");
    }

    // Step 4: Solve using CSP
    final solution = await _solveWithCSP(
        gridSize, rowOperators, columnOperators, clues, token);

    if (solution == null) {
      if (kDebugMode) traceGenerator("🔧 [GENERATOR] ❌ CSP solver failed");
      return null;
    }

    if (kDebugMode) traceGenerator("🔧 [GENERATOR] ✅ CSP solved successfully");

    // Step 5: PLAYER HINTS - Strategic selection for gameplay
    final playerHints = _selectPlayerHints(
        gridSize, rowOperators, columnOperators, solution, clues);
    if (kDebugMode) {
      traceGenerator(
          "🔧 [GENERATOR] 🎯 Selected ${playerHints.length} player hints: $playerHints");
    }

    // Step 6: Create empty cells (excluding both CSP clues and player hints)
    final emptyCells = <String>{};
    for (final cellId in allCells) {
      if (!clues.containsKey(cellId) && !playerHints.containsKey(cellId)) {
        emptyCells.add(cellId);
      }
    }

    // Step 7: Generate number pool (removing unique hint numbers)
    final correctNumbers =
        emptyCells.map((cellId) => solution[cellId]!).toList();
    final numberPool = _generateNumberPool(
        correctNumbers.cast<int>(), playerHints.values.toList());

    return ArithmeticSquarePuzzle(
      gridSize: gridSize,
      clues: clues,
      playerHints: playerHints,
      emptyCells: emptyCells,
      rowOperators: rowOperators,
      columnOperators: columnOperators,
      numberPool: numberPool,
      fullSolution: solution,
    );
  }

  /// NEW: Strategic player hint selection - STRICT max 1 per equation
  Map<String, int> _selectPlayerHints(
    int gridSize,
    List<List<String>> rowOperators,
    List<List<String>> columnOperators,
    Map<String, int> solution,
    Map<String, int> cspClues,
  ) {
    if (kDebugMode) {
      traceGenerator("🎯 [PLAYER HINTS] Starting strategic hint selection");
    }

    final playerHints = <String, int>{};
    final allCells = <String>[];

    // Create list of all non-CSP-clue cells
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cellId = 'r${r}c$c';
        if (!cspClues.containsKey(cellId)) {
          allCells.add(cellId);
        }
      }
    }

    // Track which equations already have hints (STRICT: max 1 per equation)
    final rowsWithHints = <int>{};
    final colsWithHints = <int>{};

    // Calculate target number of hints based on difficulty
    final totalEquations = gridSize * 2; // rows + columns
    final maxHints =
        math.min(totalEquations, _calculateTargetHints(gridSize, grade, level));

    if (kDebugMode) {
      traceGenerator(
          "🎯 [PLAYER HINTS] Target hints: $maxHints out of $totalEquations equations");
    }

    // Priority 1: Add hints to equations with more complex operations
    final candidates = <_HintCandidate>[];

    for (final cellId in allCells) {
      final parts = cellId.split('c');
      final row = int.parse(parts[0].substring(1));
      final col = int.parse(parts[1]);

      // Skip result cells (last row and column)
      if (_isResultCell(cellId, gridSize)) continue;

      // Calculate complexity score for this cell's equations
      int complexity = 0;
      complexity += _calculateOperationComplexity(rowOperators[row]);
      complexity += _calculateOperationComplexity(columnOperators[col]);

      candidates.add(_HintCandidate(cellId, row, col, complexity));
    }

    // Sort by complexity (highest first)
    candidates.sort((a, b) => b.complexity.compareTo(a.complexity));

    // STRICT enforcement: only add hint if BOTH row AND column don't have hints yet
    for (final candidate in candidates) {
      if (playerHints.length >= maxHints) break;

      final canAddToRow = !rowsWithHints.contains(candidate.row);
      final canAddToCol = !colsWithHints.contains(candidate.col);

      // CRITICAL: Both equations must not have hints yet
      if (canAddToRow && canAddToCol) {
        playerHints[candidate.cellId] = solution[candidate.cellId]!;

        // Mark BOTH equations as having hints now
        rowsWithHints.add(candidate.row);
        colsWithHints.add(candidate.col);

        if (kDebugMode) {
          traceGenerator(
              "🎯 [PLAYER HINTS] Added hint at ${candidate.cellId} (value: ${solution[candidate.cellId]}) - row ${candidate.row}, col ${candidate.col}, complexity: ${candidate.complexity}");
        }
      }
    }

    if (kDebugMode) {
      traceGenerator(
          "🎯 [PLAYER HINTS] Final selection: ${playerHints.length} hints placed");
    }
    traceGenerator("🎯 [PLAYER HINTS] Rows with hints: $rowsWithHints");
    traceGenerator("🎯 [PLAYER HINTS] Columns with hints: $colsWithHints");
    return playerHints;
  }

  int _calculateTargetHints(int gridSize, int grade, int level) {
    // Base hints: smaller grids get more relative help
    int baseHints = gridSize == 3
        ? 2
        : gridSize == 4
            ? 3
            : 4;

    // Adjust for grade/level
    if (grade <= 2) baseHints += 1; // Younger students get more help
    if (level <= 3) baseHints += 1; // Early levels get more help

    // Cap at reasonable maximum
    return math.min(baseHints, gridSize * 2 - 2); // Don't hint every equation
  }

  int _calculateOperationComplexity(List<String> operators) {
    int complexity = 0;
    for (final op in operators) {
      switch (op) {
        case '+':
          complexity += 1;
          break;
        case '−':
        case '-':
          complexity += 2;
          break;
        case '×':
        case '*':
          complexity += 3;
          break;
        case '÷':
        case '/':
          complexity += 4;
          break;
      }
    }
    return complexity;
  }

  int _determineGridSize() {
    // Always 3x3. Larger grids (4x4+) were the sole cause of the runtime
    // blow-ups: a 16-variable CSP with a single random clue frequently yields
    // instances whose UNSAT proof takes tens of seconds (measured up to ~47s)
    // — regardless of the operators used — and the solver cannot be reliably
    // interrupted mid-search, which froze the web build. A 3x3 always solves in
    // well under 40ms, so difficulty scales through the number range and the
    // operator mix (×/÷ at higher grades) instead of through grid size.
    return 3;
  }

  List<String> _getAvailableOperators() {
    // Fallback wins over everything (including custom settings): +/− only is
    // near-instant and essentially always satisfiable, so a puzzle is still
    // produced even when custom settings restrict to ×/÷.
    if (_forceSimpleOps) return const ['+', '−'];

    // Convert framework operations to proper symbols (exactly like gensq.dart)
    if (useCustomSettings && customOps.isNotEmpty) {
      return customOps.map((op) {
        switch (op) {
          case 'addition':
            return '+';
          case 'subtraction':
            return '−';
          case 'multiplication':
            return '×';
          case 'division':
            return '÷';
          default:
            return '+';
        }
      }).toList();
    }

    final ops = <String>['+'];
    if (grade >= 2) ops.add('−');
    if (grade >= 3) ops.add('×');
    if (grade >= 4 && level >= 6) ops.add('÷');

    return ops;
  }

  List<int> _getNumberDomain() {
    final minVal = useCustomSettings ? customMin : math.max(1, grade);
    final maxVal = useCustomSettings
        ? customMax
        : math.min(
            algorithmPath == AlgorithmPath.legacy
                ? 20
                : grade >= 6
                    ? 40
                    : grade >= 5
                        ? 30
                        : 20,
            5 + grade * 3 + level);
    return List<int>.generate(maxVal - minVal + 1, (i) => i + minVal);
  }

  int _determineNumberOfCSPClues(int gridSize) {
    final totalCells = gridSize * gridSize;
    if (totalCells <= 9) {
      return 0; // Let CSP solve without clues for small grids
    }
    return 1; // Minimal CSP clues for larger grids
  }

  bool _isResultCell(String cellId, int gridSize) {
    final parts = cellId.split('c');
    final row = int.parse(parts[0].substring(1));
    final col = int.parse(parts[1]);

    // Last column and last row are result cells
    return col == gridSize - 1 || row == gridSize - 1;
  }

  // Direct port of CSP solving from gensq.dart
  Future<Map<String, int>?> _solveWithCSP(
    int gridSize,
    List<List<String>> rowOperators,
    List<List<String>> columnOperators,
    Map<String, int> clues,
    CancellationToken token,
  ) async {
    if (kDebugMode) traceGenerator("🔧 [CSP] Building CSP problem...");

    // Build Problem exactly like gensq.dart does
    final p = Problem();
    final fullDomain = _getNumberDomain();

    Map<String, List<int>>? narrowed;
    if (_useTables) {
      narrowed = pruneArithmeticDomains({
        for (var r = 0; r < gridSize; r++)
          for (var c = 0; c < gridSize; c++)
            'r${r}c$c': clues.containsKey('r${r}c$c')
                ? [clues['r${r}c$c']!]
                : fullDomain
      }, [
        for (var r = 0; r < gridSize; r++)
          (
            cells: List.generate(gridSize, (c) => 'r${r}c$c'),
            op: rowOperators[r].single
          ),
        for (var c = 0; c < gridSize; c++)
          (
            cells: List.generate(gridSize, (r) => 'r${r}c$c'),
            op: columnOperators[c].single
          ),
      ]);
      if (narrowed == null) return null;
    }
    // Add variables
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cellId = 'r${r}c$c';
        if (clues.containsKey(cellId)) {
          p.addVariable(cellId, [clues[cellId]!]);
        } else {
          p.addVariable(cellId, narrowed?[cellId] ?? fullDomain);
        }
      }
    }

    // Add row constraints (exactly like gensq.dart)
    for (int r = 0; r < gridSize; r++) {
      final rowVars = List<String>.generate(gridSize, (c) => 'r${r}c$c');
      if (_useTables) {
        addArithmeticConstraint(p, rowVars, fullDomain, rowOperators[r].single);
      } else {
        p.addConstraint(rowVars, _createPredicate(rowVars, rowOperators[r]));
      }
    }

    // Add column constraints (exactly like gensq.dart)
    for (int c = 0; c < gridSize; c++) {
      final colVars = List<String>.generate(gridSize, (r) => 'r${r}c$c');
      if (_useTables) {
        addArithmeticConstraint(
            p, colVars, fullDomain, columnOperators[c].single);
      } else {
        p.addConstraint(colVars, _createPredicate(colVars, columnOperators[c]));
      }
    }

    if (kDebugMode) {
      traceGenerator(
          "🔧 [CSP] Solving with ${gridSize * gridSize} variables...");
    }

    // If the global budget already expired, don't even start another solve.
    if (token.isCancelled) return null;
    // Bound each individual solve too. Combined with the always-3x3 grid this
    // is belt-and-suspenders (3x3 solves in <40ms), but it keeps a single hard
    // instance from ever dominating if the difficulty is widened in future.
    final solveToken = CancellationToken();
    // Short per-solve cap: a 3x3 SAT solve finishes in a few ms, so this only
    // ever cuts off unsatisfiable ×/÷ configs (expensive to disprove) — cutting
    // them fast lets many more configs be tried inside the budget, which
    // matters most on the web build where dart2js runs ~10x slower.
    final perSolveTimer =
        Timer(const Duration(milliseconds: 500), solveToken.cancel);

    try {
      final solution = await p.getSolutionWithRestarts(
        seed: generatorSolverSeed(),
        useDomWdeg: true,
        scale: 50,
        maxRestarts: 200,
        cancelToken: solveToken,
      );

      if (solution == 'FAILURE') {
        if (kDebugMode) {
          traceGenerator(
              "🔧 [CSP] ❌ No solution found (or per-solve budget hit)");
        }
        return null;
      }

      if (kDebugMode) traceGenerator("🔧 [CSP] ✅ Solution found: $solution");
      return (solution as Map).cast<String, int>();
    } catch (e) {
      if (kDebugMode) traceGenerator("🔧 [CSP] ❌ Solver error: $e");
      return null;
    } finally {
      perSolveTimer.cancel();
    }
  }

  // Direct port of predicate creation from gensq.dart
  NaryPredicate _createPredicate(List<String> varNames, List<String> opList) {
    return (assign) {
      final values = varNames.map((v) => assign[v]).toList();
      final operands = values.sublist(0, varNames.length - 1);
      final result = values.last;
      if (operands.any((op) => op == null) || result == null) return false;
      return _evaluateForPredicate(operands.cast<int>(), opList) == result;
    };
  }

  int? _evaluateForPredicate(List<int> operands, List<String> ops) {
    // Exact same logic as gensq.dart's evaluate function
    int currentVal = operands[0];
    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      final nextVal = operands[i + 1];
      switch (op) {
        case '+':
          currentVal += nextVal;
          break;
        case '−':
        case '-':
          currentVal -= nextVal;
          break;
        case '×':
        case '*':
          currentVal *= nextVal;
          break;
        case '÷':
        case '/':
          if (nextVal == 0 || currentVal % nextVal != 0) return null;
          currentVal ~/= nextVal;
          break;
        default:
          return null;
      }
    }
    return currentVal;
  }

  List<int> _generateNumberPool(
      List<int> correctNumbers, List<int> hintNumbers) {
    final pool = <int>[];
    pool.addAll(correctNumbers);

    // Remove hint numbers from pool ONLY if they don't appear multiple times
    final numberCounts = <int, int>{};
    for (final num in [...correctNumbers, ...hintNumbers]) {
      numberCounts[num] = (numberCounts[num] ?? 0) + 1;
    }

    final numbersToRemove = <int>[];
    for (final hintNum in hintNumbers) {
      if (numberCounts[hintNum] == 1) {
        // This hint number appears only once total, safe to remove from pool
        numbersToRemove.add(hintNum);
      }
    }

    for (final num in numbersToRemove) {
      pool.remove(num);
    }

    if (kDebugMode) {
      traceGenerator(
          "🎯 [NUMBER POOL] Removed unique hint numbers: $numbersToRemove");
    }

    final domain = _getNumberDomain();

    // Add some decoy numbers. Draw from the domain values NOT already in the
    // pool/hints, capped at how many are actually available — the old
    // `while (decoys.length < decoyCount)` loop spun forever whenever the
    // solution used enough distinct values that fewer than `decoyCount` decoys
    // remained (very likely at grade 1, whose domain is only 1..9). That
    // infinite loop froze generation, worst of all on the web build where it
    // runs on the main thread.
    final decoyCount = math.max(4, 8 - pool.length);
    final available = domain
        .where((d) => !pool.contains(d) && !hintNumbers.contains(d))
        .toList()
      ..shuffle(_random);
    final decoys = available.take(decoyCount).toList();

    pool.addAll(decoys);
    pool.shuffle(_random);

    if (kDebugMode) {
      traceGenerator(
          "🎯 [NUMBER POOL] Final pool size: ${pool.length}, contents: $pool");
    }
    return pool;
  }

  T _randChoice<T>(List<T> arr) => arr[_random.nextInt(arr.length)];
}

/// Helper class for hint candidate selection
class _HintCandidate {
  final String cellId;
  final int row;
  final int col;
  final int complexity;

  _HintCandidate(this.cellId, this.row, this.col, this.complexity);
}
