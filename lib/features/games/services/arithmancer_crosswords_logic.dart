// ignore_for_file: unused_element, unused_field
import 'dart:async';
import 'dart:math' as math;

import 'package:dart_csp/dart_csp.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// CROSSWORD PUZZLE SCALING CONFIGURATION
// ============================================================================
// Adjust these constants to fine-tune difficulty scaling for GRADES 1-4 ONLY

class CrosswordConfig {
  // Number range scaling (compress into 4 grades)
  static const int baseMinNumber = 1;
  static const int baseMaxNumber = 9;
  static const int numberRangeGrowthPerGrade = 5; // Aggressive growth: +5 to max per grade
  static const int maxNumberCap = 25; // Higher cap for grade 4

  // Puzzle size scaling (compress into 4 grades + 20 levels each)
  static const int baseEdges = 4; // Start very small
  static const int edgesGrowthPerLevel = 1; // +1 edge every 2 levels
  static const int levelDivisorForEdges = 2; // level/2 for growth calculation
  static const int edgesGrowthPerGrade = 4; // +4 edges per grade
  static const int maxEdges = 20; // Maximum puzzle complexity for grade 4 level 20

  // Clue system (pre-filled cells) - ALWAYS provide clues for mathematical reasoning
  static const int baseClues = 2; // Always start with at least 2 clues
  static const int cluesGrowthPerGrade = 1; // +1 clue per grade
  static const int cluesGrowthPerLevel = 1; // +1 clue every 10 levels
  static const int maxClues = 6; // Maximum pre-filled cells

  // Advanced constraints - must fit in grade 4
  static const int noDupsStartGrade = 4; // Enable unique numbers at grade 4
  static const int noDupsStartLevel = 15; // And only at level 15+

  // Operation complexity (compress into 4 grades)
  static const Map<int, List<String>> operationsByGrade = {
    1: ['+'], // Grade 1: Addition only
    2: ['+', '−'], // Grade 2: Add subtraction
    3: ['+', '−', '×'], // Grade 3: Add multiplication
    4: ['+', '−', '×', '÷'], // Grade 4: All operations (highly complex)
  };

  // Timeout scaling (grade 4 needs much more time)
  static const int baseTimeout = 20;
  static const int timeoutGrowthPerGrade = 15; // +15 seconds per grade
  static const int maxTimeout = 90; // Up to 90 seconds for grade 4

  // Calculate actual config for a given grade/level with optional custom settings
  static PuzzleConfig createConfig(int grade, int level, {
    bool useCustomSettings = false,
    List<String>? customOps,
    int? customMin,
    int? customMax,
  }) {
    // Number range - use custom settings if provided
    final minN = useCustomSettings && customMin != null ? customMin : baseMinNumber;
    final maxN = useCustomSettings && customMax != null
        ? customMax
        : math.min(baseMaxNumber + (grade * numberRangeGrowthPerGrade), maxNumberCap);

    // Puzzle size - both grade and level scaling
    final baseForGrade = baseEdges + (grade * edgesGrowthPerGrade);
    final levelBonus = level ~/ levelDivisorForEdges * edgesGrowthPerLevel;
    final edges = math.min(baseForGrade + levelBonus, maxEdges);

    // Operations - use custom settings if provided
    final ops = useCustomSettings && customOps != null && customOps.isNotEmpty
        ? _convertCustomOperations(customOps)
        : (operationsByGrade[grade] ?? operationsByGrade[4]!);

    // Clues - ALWAYS provide clues for mathematical reasoning
    final clues = math.min(
      baseClues + (grade * cluesGrowthPerGrade) + (level ~/ 10 * cluesGrowthPerLevel),
      maxClues
    );

    // Advanced constraints
    final noDups = grade >= noDupsStartGrade && level >= noDupsStartLevel;

    // Timeout - generous for complex grade 4 puzzles
    final timeout = math.min(
      baseTimeout + (grade * timeoutGrowthPerGrade),
      maxTimeout
    );

    return PuzzleConfig(
      minN: minN,
      maxN: maxN,
      ops: ops,
      targetEdges: edges,
      numClues: clues,
      noDups: noDups,
      timeoutSeconds: timeout,
    );
  }

  // Convert custom operation names to symbols
  static List<String> _convertCustomOperations(List<String> customOps) {
    const operationMap = {
      'addition': '+',
      'subtraction': '−',
      'multiplication': '×',
      'division': '÷',
    };

    return customOps
        .map((op) => operationMap[op] ?? op)
        .where((op) => ['+', '−', '×', '÷'].contains(op))
        .toList();
  }

  // Debug helper to see what config will be generated
  static String debugConfig(int grade, int level, {
    bool useCustomSettings = false,
    List<String>? customOps,
    int? customMin,
    int? customMax,
  }) {
    final config = createConfig(grade, level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    final customStr = useCustomSettings ? ' [CUSTOM]' : '';
    return 'Grade $grade, Level $level$customStr → Range=${config.minN}-${config.maxN}, '
           'Ops=${config.ops}, Edges=${config.targetEdges}, '
           'Clues=${config.numClues}, NoDups=${config.noDups}, '
           'Timeout=${config.timeoutSeconds}s';
  }
}

//##############################################################################
// EXACT BLUEPRINT COPY FROM gencw.dart - FOLLOWS PRECISELY
//##############################################################################

/// Configuration for the crossword puzzle generator
class PuzzleConfig {
  int minN;
  int maxN;
  List<String> ops;
  int targetEdges;
  int numClues;
  bool noDups;
  bool verbose;
  int timeoutSeconds;

  PuzzleConfig({
    this.minN = 1,
    this.maxN = 9,
    this.ops = const ['+', '−', '×', '÷'],
    this.targetEdges = 8,
    this.numClues = 0,
    this.noDups = false,
    this.verbose = false,
    this.timeoutSeconds = 30,
  });
}

/// Grid pattern generator - EXACT COPY from gencw.dart
class GridPatternGenerator {
  final int width;
  final int height;
  final int targetEdges;
  late List<List<String>> grid;
  final math.Random random = math.Random();
  int edgeCount = 0;
  late math.Point<int> mazeStart;
  late int firstDirection;
  final List<math.Point<int>> directions = [
    const math.Point(0, -1),
    const math.Point(1, 0),
    const math.Point(0, 1),
    const math.Point(-1, 0)
  ];

  GridPatternGenerator({
    this.width = 30,
    this.height = 25,
    required this.targetEdges,
  }) {
    initializeGrid();
    mazeStart = math.Point(width ~/ 2, height ~/ 2);
    firstDirection = random.nextInt(4);
    if (isValidPosition(mazeStart.x, mazeStart.y)) {
      grid[mazeStart.y][mazeStart.x] = '█';
    }
  }

  void initializeGrid() {
    grid = List.generate(height, (_) => List.generate(width, (_) => ' '));
  }

  bool isValidPosition(int x, int y) {
    return x >= 2 && x < width - 2 && y >= 2 && y < height - 2;
  }

  int countSquaresBehind(math.Point<int> pos, int direction) {
    math.Point<int> oppositeDir = directions[(direction + 2) % 4];
    int count = 0;
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (oppositeDir.x * step);
      int y = pos.y + (oppositeDir.y * step);
      if (!isValidPosition(x, y) || grid[y][x] != '█') break;
      count++;
    }
    return count;
  }

  bool canWalk4Steps(math.Point<int> pos, int direction) {
    if (countSquaresBehind(pos, direction) >= 4) return false;
    math.Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (!isValidPosition(x, y)) return false;
      if (step < 4 && grid[y][x] == '█') return false;
    }
    return true;
  }

  math.Point<int> walk4Steps(math.Point<int> pos, int direction) {
    math.Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (isValidPosition(x, y)) grid[y][x] = '█';
    }
    edgeCount++;
    return math.Point(pos.x + (dir.x * 4), pos.y + (dir.y * 4));
  }

  void runMazeWalker() {
    math.Point<int> currentPos = mazeStart;
    int currentDirection = firstDirection;

    for (int moves = 0; moves < 15 && edgeCount < targetEdges; moves++) {
      if (canWalk4Steps(currentPos, currentDirection)) {
        currentPos = walk4Steps(currentPos, currentDirection);
        int decision = random.nextInt(100);
        List<int> turnOptions = [(currentDirection + 1) % 4, (currentDirection + 3) % 4]
          ..shuffle(random);

        if (decision < 40) {
          math.Point<int> dir = directions[currentDirection];
          math.Point<int> backPos =
              math.Point(currentPos.x - (dir.x * 2), currentPos.y - (dir.y * 2));
          bool foundTurn = false;
          for (int newDir in turnOptions) {
            if (canWalk4Steps(backPos, newDir)) {
              currentPos = backPos;
              currentDirection = newDir;
              foundTurn = true;
              break;
            }
          }
          if (!foundTurn) break;
        } else {
          bool foundTurn = false;
          for (int newDir in turnOptions) {
            if (canWalk4Steps(currentPos, newDir)) {
              currentDirection = newDir;
              foundTurn = true;
              break;
            }
          }
          if (!foundTurn) break;
        }
      } else {
        List<int> turnOptions = [(currentDirection + 1) % 4, (currentDirection + 3) % 4]
          ..shuffle(random);
        bool foundTurn = false;
        for (int newDir in turnOptions) {
          if (canWalk4Steps(currentPos, newDir)) {
            currentDirection = newDir;
            foundTurn = true;
            break;
          }
        }
        if (!foundTurn) break;
      }
    }
  }

  List<List<String>> generatePattern() {
    for (int walker = 0; walker < 4 && edgeCount < targetEdges; walker++) {
      int oldEdgeCount = edgeCount;
      runMazeWalker();
      if (edgeCount == oldEdgeCount) break;
    }
    return grid;
  }


}

/// Equation representation - EXACT COPY from gencw.dart
class Equation {
  final List<math.Point<int>> numberCells;
  final math.Point<int> operatorCell;
  final String operator;
  
  Equation(this.numberCells, this.operatorCell, this.operator);
  
  List<String> get variableNames =>
      numberCells.map((p) => 'C_${p.y}_${p.x}').toList();
      
  Set<math.Point<int>> get allCells {
    final op = operatorCell;
    final n1 = numberCells[0];
    final n2 = numberCells[1];
    final n3 = numberCells[2];
    return {
      n1,
      op,
      math.Point((op.x + n2.x) ~/ 2, (op.y + n2.y) ~/ 2),
      n2,
      math.Point((n2.x + n3.x) ~/ 2, (n2.y + n3.y) ~/ 2),
      n3
    };
  }

  @override
  String toString() =>
      '${variableNames[0]} $operator ${variableNames[1]} == ${variableNames[2]}';
}

/// Puzzle parser - EXACT COPY from gencw.dart
class PuzzleParser {
  final List<List<String>> grid;
  final PuzzleConfig config;
  final math.Random random = math.Random();
  final List<Equation> equations = [];
  final Set<math.Point<int>> numberCellLocations = {};

  PuzzleParser(this.grid, this.config) {
    _findEquations();
  }

  void _findEquations() {
    int height = grid.length;
    int width = grid[0].length;
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width - 4; c++) {
        if (List.generate(5, (i) => grid[r][c + i])
            .every((cell) => cell == '█')) {
          final numberCells = [math.Point(c, r), math.Point(c + 2, r), math.Point(c + 4, r)];
          final operatorCell = math.Point(c + 1, r);
          final eq = Equation(numberCells, operatorCell,
              config.ops[random.nextInt(config.ops.length)]);
          equations.add(eq);
          numberCellLocations.addAll(numberCells);
        }
      }
    }
    for (int r = 0; r < height - 4; r++) {
      for (int c = 0; c < width; c++) {
        if (List.generate(5, (i) => grid[r + i][c])
            .every((cell) => cell == '█')) {
          final numberCells = [math.Point(c, r), math.Point(c, r + 2), math.Point(c, r + 4)];
          final operatorCell = math.Point(c, r + 1);
          final eq = Equation(numberCells, operatorCell,
              config.ops[random.nextInt(config.ops.length)]);
          equations.add(eq);
          numberCellLocations.addAll(numberCells);
        }
      }
    }
  }

  bool isPatternValid() {
    if (equations.isEmpty) return false;
    int totalBlockCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell == '█') totalBlockCells++;
      }
    }
    final cellsInEquations = <math.Point<int>>{};
    for (final eq in equations) {
      cellsInEquations.addAll(eq.allCells);
    }
    return totalBlockCells == cellsInEquations.length;
  }
}

/// ASCII renderer - EXACT COPY from gencw.dart
class AsciiRenderer {
  final PuzzleParser puzzle;
  final PuzzleConfig config;
  final Map<String, dynamic>? solution;
  late final int cellWidth;

  AsciiRenderer(this.puzzle, this.config, {this.solution}) {
    cellWidth = config.maxN.toString().length + 2;
  }

  String render() {
    if (puzzle.numberCellLocations.isEmpty) return "No valid equations found.";
    final equationCells = <math.Point<int>, String>{};
    for (final eq in puzzle.equations) {
      final mid1 = math.Point((eq.operatorCell.x + eq.numberCells[1].x) ~/ 2,
          (eq.operatorCell.y + eq.numberCells[1].y) ~/ 2);
      final mid2 = math.Point((eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
          (eq.numberCells[1].y + eq.numberCells[2].y) ~/ 2);
      equationCells[mid1] = eq.operator;
      equationCells[mid2] = '=';
    }
    final allDrawableCells = {
      ...puzzle.numberCellLocations,
      ...equationCells.keys
    };
    final minX = allDrawableCells.map((p) => p.x).reduce(math.min);
    final maxX = allDrawableCells.map((p) => p.x).reduce(math.max);
    final minY = allDrawableCells.map((p) => p.y).reduce(math.min);
    final maxY = allDrawableCells.map((p) => p.y).reduce(math.max);
    final canvasWidth = (maxX - minX + 1) * (cellWidth + 1) + 1;
    final canvasHeight = (maxY - minY + 1) * 2 + 1;
    var canvas = List.generate(canvasHeight, (_) => List.filled(canvasWidth, ' '));

    for (final point in allDrawableCells) {
      _drawBox(canvas, point.x - minX, point.y - minY);
    }
    for (final point in allDrawableCells) {
      String content = '';
      if (equationCells.containsKey(point)) {
        content = equationCells[point]!;
      } else if (puzzle.numberCellLocations.contains(point)) {
        final varName = 'C_${point.y}_${point.x}';
        content = solution?[varName]?.toString() ?? '';
      }
      _fillText(canvas, point.x - minX, point.y - minY, content);
    }
    return canvas.map((row) => row.join()).join('\n');
  }

  void _drawBox(List<List<String>> canvas, int x, int y) {
    int cx = x * (cellWidth + 1);
    int cy = y * 2;
    canvas[cy][cx] = '+';
    canvas[cy][cx + cellWidth] = '+';
    canvas[cy + 2][cx] = '+';
    canvas[cy + 2][cx + cellWidth] = '+';
    for (int i = 1; i < cellWidth; i++) {
      canvas[cy][cx + i] = '-';
      canvas[cy + 2][cx + i] = '-';
    }
    canvas[cy + 1][cx] = '|';
    canvas[cy + 1][cx + cellWidth] = '|';
  }

  void _fillText(List<List<String>> canvas, int x, int y, String text) {
    int cx = x * (cellWidth + 1) + (cellWidth ~/ 2) - (text.length - 1) ~/ 2;
    int cy = y * 2 + 1;
    for (int i = 0; i < text.length; i++) {
      if (cx + i < canvas[cy].length) {
        canvas[cy][cx + i] = text[i];
      }
    }
  }
}

/// MAIN GENERATOR
Future<CrosswordPuzzle> generateCrosswordPuzzle(PuzzleConfig config) async {
  if (kDebugMode) debugPrint('🔧 [GENERATOR] ========================================');
  debugPrint('🔧 [GENERATOR] MATH CROSSWORD PUZZLE GENERATOR & SOLVER');
  debugPrint('🔧 [GENERATOR] Config: Range=${config.minN}-${config.maxN}, Ops=${config.ops}, Edges=${config.targetEdges}, Clues=${config.numClues}, NoDups=${config.noDups}, Timeout=${config.timeoutSeconds}s');

  dynamic solution;
  PuzzleParser? successfulPuzzle;
  Map<String, int> finalClues = {};
  const maxAttempts = 50; // Reduced from 100
  
  final totalStopwatch = Stopwatch()..start();
  const maxTotalSeconds = 6; // Hard limit

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    if (totalStopwatch.elapsed.inSeconds >= maxTotalSeconds) {
      if (kDebugMode) debugPrint("⏰ [GENERATOR] Hard timeout at ${totalStopwatch.elapsed.inSeconds}s (max: ${maxTotalSeconds}s)");
      break;
    }
    
    if (kDebugMode) debugPrint('🔧 [GENERATOR] ------------------------------------------------------------');
    debugPrint('🔧 [GENERATOR] ATTEMPT $attempt/$maxAttempts (elapsed: ${totalStopwatch.elapsed.inSeconds}s)');

    // STEP 1: Generate a valid pattern
    if (kDebugMode) debugPrint("🔧 [GENERATOR] [1] Generating pattern...");
    PuzzleParser? puzzle;
    int patternAttempt = 0;
    do {
      patternAttempt++;
      if (patternAttempt > 20) { // Don't spend forever on pattern
        if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> Pattern generation taking too long, restarting attempt");
        break;
      }
      final generator = GridPatternGenerator(targetEdges: config.targetEdges);
      final rawGrid = generator.generatePattern();
      puzzle = PuzzleParser(rawGrid, config);
    } while (puzzle.isPatternValid() != true && patternAttempt < 20);

    if (puzzle == null || !puzzle.isPatternValid()) {
      if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> FAILED to generate valid pattern, retrying...");
      continue;
    }

    final allVarNames =
        puzzle.numberCellLocations.map((p) => 'C_${p.y}_${p.x}').toList();
    if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> Pattern OK: ${puzzle.equations.length} equations, ${allVarNames.length} cells");

    // STEP 2: Generate clues (keeping existing logic)
    debugPrint("🔧 [GENERATOR] [2] Generating ${config.numClues} clues...");
    final clues = <String, int>{};
    final domain = List<int>.generate(config.maxN - config.minN + 1, (i) => i + config.minN);

    final variableCounts = <String, int>{};
    for (final varName in allVarNames) {
      variableCounts[varName] = 0;
    }
    for (final eq in puzzle.equations) {
      for (final varName in eq.variableNames) {
        variableCounts[varName] = (variableCounts[varName] ?? 0) + 1;
      }
    }

    final List<String> candidates = [...allVarNames];
    final clueVars = <String>[];
    final disqualifiedEquations = <Equation>{};

    for (int i = 0; i < config.numClues && candidates.isNotEmpty; i++) {
      candidates.sort((a, b) => variableCounts[b]!.compareTo(variableCounts[a]!));
      if (candidates.isEmpty) break;
      final bestCandidate = candidates.first;

      final chosenEquation = puzzle.equations.firstWhere(
        (eq) => eq.variableNames.contains(bestCandidate) && !disqualifiedEquations.contains(eq),
        orElse: () => puzzle!.equations.first,
      );

      String clueVariable;
      switch (chosenEquation.operator) {
        case '+':
        case '×':
          clueVariable = chosenEquation.variableNames[2];
          break;
        case '−':
        case '÷':
          clueVariable = chosenEquation.variableNames[0];
          break;
        default:
          clueVariable = bestCandidate;
      }
      clueVars.add(clueVariable);
      disqualifiedEquations.add(chosenEquation);
      candidates.removeWhere((v) => chosenEquation.variableNames.contains(v));
    }

    final usedClueValues = <int>{};
    for (final clueVar in clueVars.toSet()) {
      int clueValue;
      do {
        clueValue = domain[math.Random().nextInt(domain.length)];
      } while (config.noDups && usedClueValues.contains(clueValue));
      clues[clueVar] = clueValue;
      if (config.noDups) usedClueValues.add(clueValue);
    }
    if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> Clues: $clues");

    // STEP 3: Solve CSP
    debugPrint("🔧 [GENERATOR] [3] Solving CSP (timeout: ${config.timeoutSeconds}s)...");
    final p = Problem();
    final fullDomain = List<int>.generate(config.maxN - config.minN + 1, (i) => i + config.minN);
    if (config.noDups) {
      fullDomain.removeWhere((val) => clues.values.contains(val));
    }
    for (final varName in allVarNames) {
      if (clues.containsKey(varName)) {
        p.addVariable(varName, [clues[varName]!]);
      } else {
        p.addVariable(varName, fullDomain);
      }
    }
    for (final eq in puzzle.equations) {
      p.addConstraint(eq.variableNames, (assignment) {
        final a = assignment[eq.variableNames[0]];
        final b = assignment[eq.variableNames[1]];
        final c = assignment[eq.variableNames[2]];
        if (a == null || b == null || c == null) return false;
        switch (eq.operator) {
          case '+':
            return a + b == c;
          case '−':
            return a - b == c;
          case '×':
            return a * b == c;
          case '÷':
            return b != 0 && a % b == 0 && a ~/ b == c;
          default:
            return false;
        }
      });
    }
    if (config.noDups) {
      p.addAllDifferent(allVarNames);
    }

    final solveStopwatch = Stopwatch()..start();
    try {
      final potentialSolution = await p
          .getSolution()
          .timeout(Duration(seconds: config.timeoutSeconds));
      solveStopwatch.stop();

      if (potentialSolution != 'FAILURE') {
        if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> SOLVED in ${solveStopwatch.elapsedMilliseconds}ms");
        solution = potentialSolution;
        successfulPuzzle = puzzle;
        finalClues = clues;
        
        if (kDebugMode) debugPrint("🔧 [GENERATOR] [4] Rendering ASCII preview...");
        final emptyRenderer = AsciiRenderer(puzzle, config, solution: clues);
        debugPrint(emptyRenderer.render());
        break;
      } else {
        if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> UNSOLVABLE (contradiction in clues)");
      }
    } catch (e) {
      solveStopwatch.stop();
      if (kDebugMode) debugPrint("🔧 [GENERATOR]   -> TIMEOUT after ${solveStopwatch.elapsedMilliseconds}ms");
    }
  }

  totalStopwatch.stop();
  if (kDebugMode) debugPrint('🔧 [GENERATOR] ========================================');
  
  if (solution != null && solution != 'FAILURE' && successfulPuzzle != null) {
    debugPrint("🔧 [GENERATOR] SUCCESS - Converting to game format...");
    
    try {
      final typedSolution = solution.cast<String, int>();
      if (kDebugMode) debugPrint("🔧 [GENERATOR] Solution cast successful");
      
      debugPrint("🔧 [GENERATOR] Calling _convertToGameFormat...");
      final result = _convertToGameFormat(successfulPuzzle, finalClues, typedSolution);
      
      if (kDebugMode) debugPrint("🔧 [GENERATOR] _convertToGameFormat returned successfully");
      debugPrint("🔧 [GENERATOR] Result structure validated - ready to return");
      
      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("❌ [GENERATOR] ERROR in conversion: $e");
      debugPrint("❌ [GENERATOR] StackTrace: $stackTrace");
      throw Exception("Puzzle generation succeeded but conversion failed: $e");
    }
  } else {
    final msg = "Failed after ${totalStopwatch.elapsed.inSeconds}s";
    if (kDebugMode) debugPrint("❌ [GENERATOR] FAILURE: $msg");
    throw Exception(msg);
  }
}

CrosswordPuzzle _convertToGameFormat(PuzzleParser puzzle, Map<String, int> clues, Map<String, int> solution) {
  final allVarNames = puzzle.numberCellLocations.map((p) => 'C_${p.y}_${p.x}').toList();
  
  final emptyCells = <String>{};
  for (final varName in allVarNames) {
    if (!clues.containsKey(varName)) {
      emptyCells.add(varName);
    }
  }

  final correctNumbers = emptyCells.map((cellId) => solution[cellId]!).toSet();
  final numberPool = _generateNumberPool(correctNumbers.cast<int>());

  // Create visual layout
  final (numberCells, operatorCells, equalsCells) = _createVisualLayout(puzzle);
  
  // Convert equations
  final gameEquations = puzzle.equations.map((eq) => CrosswordEquation(
    eq.numberCells, eq.operatorCell, eq.operator
  )).toList();

  return CrosswordPuzzle(
    clues: clues,
    emptyCells: emptyCells,
    equations: gameEquations,
    numberPool: numberPool,
    fullSolution: solution,
    numberCells: numberCells,
    operatorCells: operatorCells,
    equalsCells: equalsCells,
  );
}

List<int> _generateNumberPool(Set<int> correctNumbers) {
  final pool = <int>[];
  
  // Add all unique numbers that appear in the solution
  pool.addAll(correctNumbers);
  
  // Add a few decoy numbers (that don't appear in solution)
  final domain = List<int>.generate(9, (i) => i + 1); // 1-9
  final decoys = <int>{};
  final random = math.Random();
  
  final decoyCount = math.max(3, 6 - correctNumbers.length);
  while (decoys.length < decoyCount) {
    final decoy = domain[random.nextInt(domain.length)];
    if (!correctNumbers.contains(decoy)) {
      decoys.add(decoy);
    }
  }
  
  pool.addAll(decoys);
  pool.sort();  // CHANGED FROM pool.shuffle(random) to pool.sort()
  
  return pool;
}

(Map<math.Point<int>, String>, Map<math.Point<int>, String>, Set<math.Point<int>>) _createVisualLayout(PuzzleParser puzzle) {
  final numberCells = <math.Point<int>, String>{};
  final operatorCells = <math.Point<int>, String>{};
  final equalsCells = <math.Point<int>>{};
  
  for (final eq in puzzle.equations) {
    // Number cells
    for (int i = 0; i < eq.numberCells.length; i++) {
      numberCells[eq.numberCells[i]] = eq.variableNames[i];
    }
    
    // Operator cell
    operatorCells[eq.operatorCell] = eq.operator;
    
    // Equals cell (between second number and result)
    final eqPos = math.Point(
      (eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
      (eq.numberCells[1].y + eq.numberCells[2].y) ~/ 2,
    );
    equalsCells.add(eqPos);  // Add the Point directly, not wrapped in {}
  }
  
  if (kDebugMode) debugPrint("🎯 [LAYOUT] Created visual layout: ${numberCells.length} number cells, ${operatorCells.length} operator cells, ${equalsCells.length} equals cells");
  
  return (numberCells, operatorCells, equalsCells);  // Return the proper tuple
}

class CrosswordPuzzle {
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<CrosswordEquation> equations;
  final List<int> numberPool;
  final Map<String, int> fullSolution;
  
  // Visual layout data
  final Map<math.Point<int>, String> numberCells; // Position -> CellId
  final Map<math.Point<int>, String> operatorCells; // Position -> Operator
  final Set<math.Point<int>> equalsCells; // Positions of equals signs

  CrosswordPuzzle({
    required this.clues,
    required this.emptyCells,
    required this.equations,
    required this.numberPool,
    required this.fullSolution,
    required this.numberCells,
    required this.operatorCells,
    required this.equalsCells,
  });

  static Future<CrosswordPuzzle> generate(Map<String, dynamic> args) async {
    final attempt = args['attemptNumber'] as int? ?? 0;
    if (kDebugMode) debugPrint("🏭 [FACTORY-$attempt] ========================================");
    debugPrint("🏭 [FACTORY-$attempt] CrosswordPuzzle.generate() called in isolate");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool? ?? false;
    final customOps = args['customOps'] as List<String>? ?? [];
    final customMin = args['customMin'] as int?;
    final customMax = args['customMax'] as int?;
    
    if (kDebugMode) debugPrint("🏭 [FACTORY-$attempt] Grade: $grade, Level: $level");
    debugPrint("🏭 [FACTORY-$attempt] Custom: $useCustomSettings");
    
    // Use the new scaling configuration system with custom settings support
    final config = CrosswordConfig.createConfig(
      grade, 
      level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    
    if (kDebugMode) {
      debugPrint("🏭 [FACTORY-$attempt] Config created: ${CrosswordConfig.debugConfig(
      grade, 
      level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
      )}");
    }
    
    if (kDebugMode) debugPrint("🏭 [FACTORY-$attempt] Calling generateCrosswordPuzzle()...");
    
    final result = await generateCrosswordPuzzle(config);
    
    if (kDebugMode) debugPrint("🏭 [FACTORY-$attempt] generateCrosswordPuzzle() returned");
    debugPrint("🏭 [FACTORY-$attempt] Result has ${result.equations.length} equations");
    debugPrint("🏭 [FACTORY-$attempt] About to return from isolate...");
    
    return result;
  }

  bool validateSolution(Map<String, int> userSolution) {
    if (kDebugMode) debugPrint("✅ [CROSSWORD VALIDATION] Starting solution validation");
    
    // Create complete solution
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(userSolution);
    
    // Validate all equations
    for (final equation in equations) {
      final values = equation.variableNames.map((varName) => completeGrid[varName]!).toList();
      final operand1 = values[0];
      final operand2 = values[1];
      final result = values[2];
      
      bool isValid = false;
      switch (equation.operator) {
        case '+':
          isValid = operand1 + operand2 == result;
          break;
        case '−':
        case '-':
          isValid = operand1 - operand2 == result;
          break;
        case '×':
        case '*':
          isValid = operand1 * operand2 == result;
          break;
        case '÷':
        case '/':
          isValid = operand2 != 0 && operand1 % operand2 == 0 && operand1 ~/ operand2 == result;
          break;
      }
      
      if (!isValid) {
        if (kDebugMode) debugPrint("✅ [CROSSWORD VALIDATION] ❌ Equation failed: $equation -> $operand1 ${equation.operator} $operand2 = $result");
        return false;
      }
    }
    
    if (kDebugMode) debugPrint("✅ [CROSSWORD VALIDATION] ✅ Solution is valid!");
    return true;
  }

  List<String> getAllOperators() {
    return equations.map((eq) => eq.operator).toList();
  }
}

class CrosswordEquation {
  final List<math.Point<int>> numberCells;
  final math.Point<int> operatorCell;
  final String operator;
  
  CrosswordEquation(this.numberCells, this.operatorCell, this.operator);
  
  List<String> get variableNames =>
      numberCells.map((p) => 'C_${p.y}_${p.x}').toList();
      
  Set<math.Point<int>> get allCells {
    final op = operatorCell;
    final n1 = numberCells[0];
    final n2 = numberCells[1];
    final n3 = numberCells[2];
    return {
      n1,
      op,
      math.Point((op.x + n2.x) ~/ 2, (op.y + n2.y) ~/ 2),
      n2,
      math.Point((n2.x + n3.x) ~/ 2, (n2.y + n3.y) ~/ 2),
      n3
    };
  }

  @override
  String toString() =>
      '${variableNames[0]} $operator ${variableNames[1]} == ${variableNames[2]}';
}
