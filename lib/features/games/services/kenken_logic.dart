import 'generator_random.dart';
import 'dart:math' as math;
import 'generator_diagnostics.dart';
import '../constants/difficulty_config.dart';

class KenkenPuzzle {
  Map<String, dynamic> toJson() => {
        'size': size,
        'clues': clues,
        'emptyCells': emptyCells.toList(),
        'numberPool': numberPool,
        'fullSolution': fullSolution,
        'cages': cages
            .map((c) => {
                  'id': c.id,
                  'clue': c.clue,
                  'op': c.operation?.symbol,
                  'cells': c.cells.map((cell) => cell.id).toList()
                })
            .toList()
      };
  factory KenkenPuzzle.fromJson(
      Map<String, dynamic> json, DifficultyConfig config) {
    final size = json['size'] as int;
    final solution = Map<String, int>.from(json['fullSolution']);
    final generator = KenkenGenerator(
        grade: config.grade,
        level: config.level,
        difficultyConfig: config,
        useCustomSettings: false,
        customOps: {},
        customMin: 1,
        customMax: size);
    generator.size = size;
    final board = List.generate(
        size,
        (r) => List.generate(
            size, (c) => KenkenCell(value: solution['r${r}c$c']!, x: c, y: r)));
    generator.board = board;
    final cages = <KenkenCage>[];
    for (final raw in json['cages'] as List) {
      final cage = KenkenCage(id: raw['id'], kenken: generator)
        ..clue = raw['clue'];
      cage.operation = switch (raw['op']) {
        '+' => KenkenAddition(),
        '-' => KenkenSubtraction(),
        '×' => KenkenMultiplication(),
        '÷' => KenkenDivision(),
        null => null,
        _ => throw FormatException('Unknown cage operation'),
      };
      for (final id in raw['cells'] as List) {
        final parts = (id as String).substring(1).split('c');
        cage.addCell(board[int.parse(parts[0])][int.parse(parts[1])]);
      }
      cages.add(cage);
    }
    generator.cages = cages;
    return KenkenPuzzle(
        size: size,
        board: board,
        cages: cages,
        clues: Map<String, int>.from(json['clues']),
        emptyCells: Set<String>.from(json['emptyCells']),
        numberPool: List<int>.from(json['numberPool']),
        fullSolution: solution);
  }

  final int size;
  final List<List<KenkenCell>> board;
  final List<KenkenCage> cages;
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<int> numberPool;
  final Map<String, int> fullSolution;

  KenkenPuzzle({
    required this.size,
    required this.board,
    required this.cages,
    required this.clues,
    required this.emptyCells,
    required this.numberPool,
    required this.fullSolution,
  });

  static Future<KenkenPuzzle> generate(Map<String, dynamic> args) async {
    if (kDebugMode) {
      traceGenerator(
          "🎯 [KENKEN FACTORY] Starting puzzle generation with args: $args");
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
          "🎯 [KENKEN FACTORY] Using difficulty config: ${difficultyConfig.grade}");
    }

    final generator = KenkenGenerator(
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
      traceGenerator("✅ [KENKEN VALIDATION] Starting solution validation");
    }

    // Create complete grid
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(userSolution);

    // Validate Latin square property (each row and column contains each number exactly once)
    for (int r = 0; r < size; r++) {
      final rowValues = <int>[];
      for (int c = 0; c < size; c++) {
        rowValues.add(completeGrid['r${r}c$c'] ?? 0);
      }
      if (!_isValidLatinSequence(rowValues)) {
        if (kDebugMode) {
          traceGenerator(
              "✅ [KENKEN VALIDATION] ❌ Row $r violates Latin square property: $rowValues");
        }
        return false;
      }
    }

    for (int c = 0; c < size; c++) {
      final colValues = <int>[];
      for (int r = 0; r < size; r++) {
        colValues.add(completeGrid['r${r}c$c'] ?? 0);
      }
      if (!_isValidLatinSequence(colValues)) {
        if (kDebugMode) {
          traceGenerator(
              "✅ [KENKEN VALIDATION] ❌ Column $c violates Latin square property: $colValues");
        }
        return false;
      }
    }

    // Validate all cage constraints
    for (final cage in cages) {
      if (!cage.validateConstraint(completeGrid)) {
        if (kDebugMode) {
          traceGenerator(
              "✅ [KENKEN VALIDATION] ❌ Cage constraint failed: ${cage.clue}");
        }
        return false;
      }
    }

    if (kDebugMode) {
      traceGenerator("✅ [KENKEN VALIDATION] ✅ Solution is valid!");
    }
    return true;
  }

  bool _isValidLatinSequence(List<int> values) {
    final expected = List.generate(size, (i) => i + 1);
    final sorted = List.from(values)..sort();
    return sorted.length == expected.length &&
        sorted.every(expected.contains) &&
        expected.every(sorted.contains);
  }

  KenkenCage? getCageForCell(KenkenCell cell) {
    return cages.firstWhere((cage) => cage.cells.contains(cell));
  }

  List<String> getAllOperators() {
    return cages
        .where((cage) => cage.operation != null)
        .map((cage) => cage.operation!.symbol)
        .toList();
  }
}

/// Individual cell in the Kenken grid
class KenkenCell {
  final int value;
  int x;
  int y;
  KenkenCage? group;

  KenkenCell({required this.value, required this.x, required this.y});

  String get id => 'r${y}c$x';
}

/// Cage containing multiple cells (direct port from blueprint)
class KenkenCage {
  final int id;
  final KenkenGenerator kenken;
  final List<KenkenCell> cells = [];
  String? clue;
  KenkenOperation? operation;

  KenkenCage({required this.id, required this.kenken});

  void addCell(KenkenCell cell) {
    cells.add(cell);
    cell.group = this;
  }

  List<int> getValues() => cells.map((c) => c.value).toList();

  KenkenCell getTopLeftCell() {
    KenkenCell topLeft = cells.first;
    for (final cell in cells) {
      if (cell.y < topLeft.y || (cell.y == topLeft.y && cell.x < topLeft.x)) {
        topLeft = cell;
      }
    }
    return topLeft;
  }

  bool containsCell(int row, int col) {
    return cells.any((cell) => cell.y == row && cell.x == col);
  }

  List<KenkenCell> _getGrowthCandidates(KenkenCell cell) {
    final candidates = <KenkenCell>[];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];
    for (final dir in directions) {
      int nx = cell.x + dir[1];
      int ny = cell.y + dir[0];
      if (ny >= 0 && ny < kenken.size && nx >= 0 && nx < kenken.size) {
        final neighbor = kenken.board[ny][nx];
        if (neighbor.group == null) {
          candidates.add(neighbor);
        }
      }
    }
    return candidates;
  }

  bool grow() {
    final growthCandidates = <KenkenCell>[];
    for (final cell in cells) {
      growthCandidates.addAll(_getGrowthCandidates(cell));
    }
    if (growthCandidates.isEmpty) return false;
    final cellToAdd =
        growthCandidates[kenken._random.nextInt(growthCandidates.length)];
    addCell(cellToAdd);
    return true;
  }

  bool validateConstraint(Map<String, int> grid) {
    if (cells.length == 1) {
      // Single cell cages just need to match their value
      final expectedValue = int.tryParse(clue ?? '');
      if (expectedValue == null) return false;
      return grid[cells.first.id] == expectedValue;
    }

    if (operation == null || clue == null) return false;

    final values = cells.map((cell) => grid[cell.id]!).toList();
    final result = operation!.calculate(values);
    final expectedResult =
        int.tryParse(clue!.replaceAll(operation!.symbol, ''));

    return result == expectedResult;
  }
}

/// Abstract base class for Kenken operations (exact port from blueprint)
abstract class KenkenOperation {
  final String symbol;
  final int minCells;
  final int? maxCells;

  KenkenOperation(
      {required this.symbol, required this.minCells, this.maxCells});

  int? calculate(List<int> numbers);
}

class KenkenAddition extends KenkenOperation {
  KenkenAddition() : super(symbol: '+', minCells: 2);

  @override
  int? calculate(List<int> numbers) => numbers.reduce((a, b) => a + b);
}

class KenkenSubtraction extends KenkenOperation {
  KenkenSubtraction() : super(symbol: '-', minCells: 2, maxCells: 2);

  @override
  int? calculate(List<int> numbers) => (numbers[0] - numbers[1]).abs();
}

class KenkenMultiplication extends KenkenOperation {
  KenkenMultiplication() : super(symbol: '×', minCells: 2);

  @override
  int? calculate(List<int> numbers) => numbers.reduce((a, b) => a * b);
}

class KenkenDivision extends KenkenOperation {
  KenkenDivision() : super(symbol: '÷', minCells: 2, maxCells: 2);

  @override
  int? calculate(List<int> numbers) {
    final n1 = numbers[0];
    final n2 = numbers[1];
    if (n1 % n2 == 0) return (n1 ~/ n2);
    if (n2 % n1 == 0) return (n2 ~/ n1);
    return null;
  }
}

/// Generator following the exact algorithm from the blueprint
class KenkenGenerator {
  final int grade;
  final int level;
  final DifficultyConfig difficultyConfig;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customMin;
  final int customMax;
  late math.Random _random;

  late final int size;
  late final int maxGroupSize;
  late final List<KenkenOperation> operations;
  late final int? minResult;
  late final int? maxResult;
  late final bool strictOperations;
  late final bool verbose;
  List<List<KenkenCell>> board = [];
  List<KenkenCage> cages = [];

  KenkenGenerator({
    required this.grade,
    required this.level,
    required this.difficultyConfig,
    required this.useCustomSettings,
    required this.customOps,
    required this.customMin,
    required this.customMax,
  }) {
    _random = generatorRandom();
  }

  Future<KenkenPuzzle> generate() async {
    if (kDebugMode) {
      traceGenerator("🔧 [KENKEN GENERATOR] Starting Kenken generation");
    }

    // Initialize parameters based on grade/level (following blueprint logic)
    _initializeParameters();

    const maxSeeds = 50;
    const maxRetries = 1000;

    for (int seedTry = 1; seedTry <= maxSeeds; seedTry++) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] === SEED $seedTry/$maxSeeds ===");
      }

      int currentBaseSeed = _random.nextInt(1000000000);

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        int currentSeed =
            currentBaseSeed + (attempt * 1000) + (attempt * attempt * 137);

        try {
          final puzzle = await _attemptGeneration(currentSeed);
          if (puzzle != null) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [KENKEN GENERATOR] ✅ SUCCESS! Generated valid puzzle on seed $seedTry, attempt $attempt");
            }
            return puzzle;
          }
        } catch (e) {
          if (attempt <= 3) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [KENKEN GENERATOR] ❌ Attempt $attempt failed: $e");
            }
          }
        }
      }
    }

    throw Exception(
        "Failed to generate a valid Kenken puzzle after trying $maxSeeds seeds with $maxRetries attempts each");
  }

  void _initializeParameters() {
    // PROPER scaling based on grade/level - much more aggressive for high levels
    if (grade <= 1) {
      size = 3;
    } else if (grade <= 2) {
      size = level <= 5 ? 3 : 4;
    } else if (grade <= 3) {
      size = level <= 3
          ? 4
          : level <= 8
              ? 5
              : 6;
    } else {
      // Grade 4+
      size = level <= 5
          ? 5
          : level <= 10
              ? 6
              : level <= 15
                  ? 7
                  : level <= 20
                      ? 8
                      : 9;
    }

    maxGroupSize = 4; // Fixed as in blueprint

    // Operations based on custom settings or grade
    operations = _getAvailableOperations();

    // Result range based on custom settings or defaults
    if (useCustomSettings) {
      minResult = customMin;
      maxResult = customMax;
    } else {
      minResult = null; // Let operations determine natural bounds
      maxResult = null;
    }

    // EXACT blueprint settings
    strictOperations = false; // BLUEPRINT DEFAULT: allow fallback to addition
    verbose = true; // NEW: verbose logging

    if (kDebugMode) {
      traceGenerator(
          "🔧 [KENKEN GENERATOR] Initialized: size=$size, maxGroupSize=$maxGroupSize, operations=${operations.map((o) => o.symbol).join(',')}, range=${minResult ?? 'any'}-${maxResult ?? 'any'}");
    }
  }

  List<KenkenOperation> _getAvailableOperations() {
    if (useCustomSettings && customOps.isNotEmpty) {
      return customOps.map((op) {
        switch (op) {
          case 'addition':
            return KenkenAddition();
          case 'subtraction':
            return KenkenSubtraction();
          case 'multiplication':
            return KenkenMultiplication();
          case 'division':
            return KenkenDivision();
          default:
            return KenkenAddition();
        }
      }).toList();
    }

    final ops = <KenkenOperation>[KenkenAddition()];
    if (grade >= 2) ops.add(KenkenSubtraction());
    if (grade >= 3) ops.add(KenkenMultiplication());
    if (grade >= 4 && level >= 6) ops.add(KenkenDivision());

    return ops;
  }

  Future<KenkenPuzzle?> _attemptGeneration(int seed) async {
    // EXACT blueprint: Reset state for each attempt
    _random = generatorRandom(seed);
    cages.clear();
    board.clear();

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Generating ${size}x$size Kenken puzzle (seed: $seed)...");
      }
    }

    // Step 1: Create Latin Square (exact copy from blueprint)
    _createLatinSquare();
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [1] Created Latin square");
      }
    }

    // Step 2: Shuffle Board (exact copy from blueprint)
    _shuffleBoard();
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [2] Shuffled board");
      }
    }

    // Step 3: Create Cages and Clues (exact copy from blueprint)
    _createCagesAndClues();
    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] [3] Created ${cages.length} cages");
      }
    }

    // Step 4: Merge Single Cell Cages (exact copy from blueprint)
    _mergeSingleCellCages();
    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] [4] Merged single cell cages, final count: ${cages.length}");
      }
    }

    // Step 5: Print ASCII debug output (exact copy from blueprint)
    _printAsciiDebug();

    // Step 6: Create puzzle data for Flutter UI
    final (clues, emptyCells, numberPool) = _createPuzzleData();

    return KenkenPuzzle(
      size: size,
      board: board,
      cages: cages,
      clues: clues,
      emptyCells: emptyCells,
      numberPool: numberPool,
      fullSolution: _createFullSolution(),
    );
  }

  // EXACT copy from blueprint
  void _createLatinSquare() {
    final baseList = List.generate(size, (i) => i + 1)..shuffle(_random);
    board = List.generate(size, (y) {
      return List.generate(size, (x) {
        final value = baseList[(x + y) % size];
        return KenkenCell(value: value, x: x, y: y);
      });
    });
  }

  // EXACT copy from blueprint
  void _shuffleBoard() {
    for (int i = 0; i < size * 2; i++) {
      final col1 = _random.nextInt(size);
      final col2 = _random.nextInt(size);
      for (int y = 0; y < size; y++) {
        final temp = board[y][col1];
        board[y][col1] = board[y][col2];
        board[y][col2] = temp;
        board[y][col1].x = col1;
        board[y][col2].x = col2;
      }

      final row1 = _random.nextInt(size);
      final row2 = _random.nextInt(size);
      final tempRow = board[row1];
      board[row1] = board[row2];
      board[row2] = tempRow;
      for (int x = 0; x < size; x++) {
        board[row1][x].y = row1;
        board[row2][x].y = row2;
      }
    }
  }

  // EXACT copy from blueprint
  void _createCagesAndClues() {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] Creating cages and clues...");
      }
    }

    int cageId = 1;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (board[y][x].group == null) {
          int targetSize = 1 + _random.nextInt(maxGroupSize);
          final newCage = KenkenCage(id: cageId++, kenken: this);
          newCage.addCell(board[y][x]);

          while (newCage.cells.length < targetSize) {
            if (!newCage.grow()) break;
          }

          if (verbose) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [KENKEN GENERATOR] Created cage ${newCage.id} with ${newCage.cells.length} cells");
            }
          }

          _assignOperationToCage(newCage);
          cages.add(newCage);
        }
      }
    }

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Created ${cages.length} cages total");
      }
    }
  }

  // EXACT copy from blueprint
  void _mergeSingleCellCages() {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] Merging single cell cages...");
      }
    }

    bool hadToMerge = true;
    int mergeCount = 0;
    while (hadToMerge) {
      hadToMerge = false;
      for (final cage in cages.toList()) {
        if (cage.cells.length == 1) {
          final singleCell = cage.cells.first;
          final neighbors = _getNeighborCells(singleCell);
          if (neighbors.isEmpty) continue;

          final targetCage =
              neighbors[_random.nextInt(neighbors.length)].group!;

          if (verbose) {
            if (kDebugMode) {
              traceGenerator(
                  "🔧 [KENKEN GENERATOR]   Merging single cell cage ${cage.id} into cage ${targetCage.id}");
            }
          }

          // Perform the merge
          targetCage.addCell(singleCell);
          cages.remove(cage);

          // Recalculate the clue for the now larger cage
          _assignOperationToCage(targetCage);

          hadToMerge = true;
          mergeCount++;
          break;
        }
      }
    }

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Merged $mergeCount single cell cages");
      }
    }
  }

  List<KenkenCell> _getNeighborCells(KenkenCell cell) {
    final neighbors = <KenkenCell>[];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];
    for (final dir in directions) {
      int nx = cell.x + dir[1];
      int ny = cell.y + dir[0];
      if (ny >= 0 && ny < size && nx >= 0 && nx < size) {
        neighbors.add(board[ny][nx]);
      }
    }
    return neighbors;
  }

  // EXACT copy from blueprint with strict operation enforcement
  void _assignOperationToCage(KenkenCage cage) {
    if (cage.cells.length == 1) {
      cage.clue = cage.cells.first.value.toString();
      cage.operation = null;
      if (verbose) {
        if (kDebugMode) {
          traceGenerator(
              "🔧 [KENKEN GENERATOR]   Single cell cage: ${cage.clue}");
        }
      }
      return;
    }

    final cageValues = cage.getValues();
    final availableOps = List<KenkenOperation>.from(operations)
      ..shuffle(_random);

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR]   Assigning operation to cage with ${cage.cells.length} cells, values: $cageValues");
      }
    }

    for (final op in availableOps) {
      if (cage.cells.length < op.minCells) {
        if (verbose) {
          if (kDebugMode) {
            traceGenerator(
                "🔧 [KENKEN GENERATOR]     ${op.symbol}: SKIP - need ${op.minCells} cells, have ${cage.cells.length}");
          }
        }
        continue;
      }
      if (op.maxCells != null && cage.cells.length > op.maxCells!) {
        if (verbose) {
          if (kDebugMode) {
            traceGenerator(
                "🔧 [KENKEN GENERATOR]     ${op.symbol}: SKIP - max ${op.maxCells} cells, have ${cage.cells.length}");
          }
        }
        continue;
      }

      final result = op.calculate(cageValues);
      if (result != null) {
        bool inRange = true;
        if (minResult != null && result < minResult!) inRange = false;
        if (maxResult != null && result > maxResult!) inRange = false;

        if (verbose) {
          if (kDebugMode) {
            traceGenerator(
                "🔧 [KENKEN GENERATOR]     ${op.symbol}: result=$result, inRange=$inRange (range: ${minResult ?? 'any'}-${maxResult ?? 'any'})");
          }
        }

        if (inRange) {
          cage.clue = '$result${op.symbol}';
          cage.operation = op;
          if (verbose) {
            if (kDebugMode) {
              traceGenerator("🔧 [KENKEN GENERATOR]     SUCCESS: ${cage.clue}");
            }
          }
          return;
        }
      } else {
        if (verbose) {
          if (kDebugMode) {
            traceGenerator(
                "🔧 [KENKEN GENERATOR]     ${op.symbol}: INVALID - cannot calculate result");
          }
        }
      }
    }

    // NEW: Strict operation enforcement
    if (strictOperations) {
      if (verbose) {
        if (kDebugMode) {
          traceGenerator(
              "🔧 [KENKEN GENERATOR]     FAILED: No valid operations found for cage with values $cageValues");
        }
      }
      throw Exception(
          'Cannot generate valid clue for cage with values $cageValues using specified operations and constraints');
    }

    // OLD: Fallback to addition only when not in strict mode
    final fallbackOp = KenkenAddition();
    final result = fallbackOp.calculate(cageValues)!;

    // If even addition is out of range, use it anyway (better than no clue)
    cage.clue = '$result${fallbackOp.symbol}';
    cage.operation = fallbackOp;
  }

  // EXACT copy from blueprint
  void _printAsciiDebug() {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [5] ASCII Debug Output:");
      }
      final asciiOutput = _toAsciiString(showSolution: false);
      for (final line in asciiOutput.split('\n')) {
        traceGenerator("🔧 [ASCII] $line");
      }

      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [5] ASCII Solution:");
      }
      final solutionOutput = _toAsciiString(showSolution: true);
      for (final line in solutionOutput.split('\n')) {
        traceGenerator("🔧 [ASCII] $line");
      }
    }
  }

  // EXACT copy from blueprint
  String _toAsciiString({required bool showSolution}) {
    final buffer = StringBuffer();
    final Map<KenkenCell, String> clueLocations = {};
    for (final cage in cages) {
      if (cage.clue != null) {
        clueLocations[cage.getTopLeftCell()] = cage.clue!;
      }
    }

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        buffer.write('+');
        bool sameGroupAbove =
            (y > 0 && board[y][x].group == board[y - 1][x].group);
        buffer.write(sameGroupAbove ? '....' : '====');
      }
      buffer.writeln('+');

      for (int x = 0; x < size; x++) {
        bool sameGroupLeft =
            (x > 0 && board[y][x].group == board[y][x - 1].group);
        buffer.write(sameGroupLeft ? ':' : '|');
        final cell = board[y][x];
        String clueContent = clueLocations[cell] ?? '';
        buffer.write(clueContent.padRight(4));
      }
      buffer.writeln('|');

      for (int x = 0; x < size; x++) {
        bool sameGroupLeft =
            (x > 0 && board[y][x].group == board[y][x - 1].group);
        buffer.write(sameGroupLeft ? ':' : '|');
        final cell = board[y][x];
        String valueContent = showSolution ? ' ${cell.value}  ' : '    ';
        buffer.write(valueContent);
      }
      buffer.writeln('|');
    }

    for (int x = 0; x < size; x++) {
      buffer.write('+====');
    }
    buffer.writeln('+');

    return buffer.toString();
  }

  (Map<String, int>, Set<String>, List<int>) _createPuzzleData() {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [6] Creating puzzle data...");
      }
    }

    final clues = <String, int>{};
    final emptyCells = <String>{};
    final allNumbers = <int>[];

    // Determine which cells to pre-fill as clues (minimal for Kenken)
    final numClues = _determineNumberOfClues();
    final allCells = <String>[];

    // Build list of all cell IDs and collect all numbers
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cellId = 'r${r}c$c';
        allCells.add(cellId);
        allNumbers.add(board[r][c].value);
      }
    }

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Total cells: ${allCells.length}, numClues: $numClues");
      }
    }

    // Randomly select a few cells to pre-fill
    final shuffledCells = List<String>.from(allCells);
    shuffledCells.shuffle(_random);
    final clueCells = shuffledCells.take(numClues).toList();

    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] Selected clue cells: $clueCells");
      }
    }

    // Set clues
    for (final cellId in clueCells) {
      final parts = cellId.split('c');
      final row = int.parse(parts[0].substring(1));
      final col = int.parse(parts[1]);
      clues[cellId] = board[row][col].value;
    }

    // All other cells are empty
    for (final cellId in allCells) {
      if (!clues.containsKey(cellId)) {
        emptyCells.add(cellId);
      }
    }

    if (verbose) {
      if (kDebugMode) traceGenerator("🔧 [KENKEN GENERATOR] Clues: $clues");
      traceGenerator("🔧 [KENKEN GENERATOR] Empty cells: ${emptyCells.length}");
    }

    // Create number pool with correct numbers + some decoys
    final correctNumbers = <int>[];
    for (final cellId in emptyCells) {
      final parts = cellId.split('c');
      final row = int.parse(parts[0].substring(1));
      final col = int.parse(parts[1]);
      correctNumbers.add(board[row][col].value);
    }

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Correct numbers: $correctNumbers");
      }
    }

    final numberPool = _generateNumberPool(correctNumbers);

    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] Final number pool: $numberPool");
      }
    }

    return (clues, emptyCells, numberPool);
  }

  int _determineNumberOfClues() {
    // Kenken typically has very few or no pre-filled clues
    if (size <= 4) return 0;
    if (size == 5) return 1;
    return 2;
  }

  List<int> _generateNumberPool(List<int> correctNumbers) {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Creating clean number pool for size $size grid");
      }
    }

    // CLEAN number pool: Just 1-size, each number once, reusable
    final pool = List.generate(size, (i) => i + 1);

    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] Clean number pool: $pool");
      }
    }

    return pool;
  }

  Map<String, int> _createFullSolution() {
    if (verbose) {
      if (kDebugMode) {
        traceGenerator("🔧 [KENKEN GENERATOR] [7] Creating full solution...");
      }
    }

    final solution = <String, int>{};
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cellId = 'r${r}c$c';
        solution[cellId] = board[r][c].value;
      }
    }

    if (verbose) {
      if (kDebugMode) {
        traceGenerator(
            "🔧 [KENKEN GENERATOR] Full solution created with ${solution.length} entries");
      }
    }

    return solution;
  }
}
