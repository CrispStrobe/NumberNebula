// ignore_for_file: avoid_print
// puzzle_generator_cli.dart
// Run with: dart run puzzle_generator_cli.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:collection';

const String outputFile = 'gridlock_puzzles_data.dart';
const String tempFile = 'gridlock_puzzles_data.dart.tmp';
const String backupFile = 'gridlock_puzzles_data.dart.backup';

void main() async {
  print('🎮 Space Station Gridlock Puzzle Generator (Incremental)');
  print('=========================================================\n');

  // Load existing puzzles
  final existingPuzzles = await _loadExistingPuzzles();
  print('📂 Loaded ${existingPuzzles.length} existing puzzles');
  
  final allPuzzles = List<GeneratedPuzzle>.from(existingPuzzles);
  final existingIds = existingPuzzles.map((p) => p.id).toSet();
  
  // Find highest ID to continue numbering
  int puzzleIdCounter = 1;
  for (final puzzle in existingPuzzles) {
    final match = RegExp(r'GRID_(\d+)').firstMatch(puzzle.id);
    if (match != null) {
      final id = int.parse(match.group(1)!);
      if (id >= puzzleIdCounter) puzzleIdCounter = id + 1;
    }
  }
  print('🔢 Starting ID counter at: $puzzleIdCounter\n');

  // Define complexity levels with target counts
  final complexityTargets = {
    1.0: 30, 1.5: 30, 2.0: 30, 2.5: 30,
    3.0: 40, 3.5: 40, 4.0: 40, 4.5: 40,
    5.0: 50, 5.5: 50, 6.0: 60, 6.5: 60,
    7.0: 80, 7.5: 80, 8.0: 100,
  };

  for (final entry in complexityTargets.entries) {
    final complexity = entry.key;
    final targetCount = entry.value;
    
    // Count existing puzzles for this complexity
    final existingCount = existingPuzzles
        .where((p) => (p.complexity - complexity).abs() < 0.01)
        .length;
    
    final needed = targetCount - existingCount;
    
    if (needed <= 0) {
      print('✓ Complexity $complexity: Already have $existingCount/$targetCount puzzles');
      continue;
    }
    
    print('🔄 Complexity $complexity: Generating $needed more puzzles (have $existingCount)...');
    
    final puzzlesForLevel = await _generatePuzzlesForComplexity(
      complexity,
      count: needed,
      startId: puzzleIdCounter,
      existingIds: existingIds,
    );
    
    allPuzzles.addAll(puzzlesForLevel);
    puzzleIdCounter += puzzlesForLevel.length;
    
    // Add new IDs to set
    for (final p in puzzlesForLevel) {
      existingIds.add(p.id);
    }
    
    print('  ✓ Generated ${puzzlesForLevel.length} new puzzles (total now: ${existingCount + puzzlesForLevel.length}/$targetCount)');
    
    // INCREMENTAL SAVE after each complexity level
    await _savePuzzlesAtomic(allPuzzles);
    print('  💾 Progress saved!\n');
  }

  print('\n✅ Total puzzles in pool: ${allPuzzles.length}');
  print('🎉 All done! Puzzles saved to $outputFile');
  
  // Print statistics
  print('\n📊 Puzzle Pool Statistics:');
  print('=' * 50);
  
  final byComplexity = <double, List<GeneratedPuzzle>>{};
  for (final puzzle in allPuzzles) {
    byComplexity.putIfAbsent(puzzle.complexity, () => []).add(puzzle);
  }
  
  final complexities = byComplexity.keys.toList()..sort();
  
  for (final complexity in complexities) {
    final puzzles = byComplexity[complexity]!;
    final avgMoves = puzzles.map((p) => p.minMoves).reduce((a, b) => a + b) / puzzles.length;
    final minMoves = puzzles.map((p) => p.minMoves).reduce(math.min);
    final maxMoves = puzzles.map((p) => p.minMoves).reduce(math.max);
    final avgShips = puzzles.map((p) => p.ships.length).reduce((a, b) => a + b) / puzzles.length;
    
    final difficulty = complexity <= 2.0 ? 'Easy  ' : 
                      complexity <= 4.0 ? 'Medium' : 
                      complexity <= 6.0 ? 'Hard  ' : 'Expert';
    
    print('$difficulty $complexity: ${puzzles.length.toString().padLeft(3)} puzzles | '
          'Moves: ${minMoves.toString().padLeft(2)}-${maxMoves.toString().padLeft(2)} '
          '(avg: ${avgMoves.toStringAsFixed(1).padLeft(4)}) | '
          'Ships: ${avgShips.toStringAsFixed(1)}');
  }
  
  print('=' * 50);
  print('Total: ${allPuzzles.length} puzzles');
}

Future<List<GeneratedPuzzle>> _generatePuzzlesForComplexity(
  double complexity, {
  required int count,
  required int startId,
  required Set<String> existingIds,
}) async {
  final puzzles = <GeneratedPuzzle>[];
  int attempts = 0;
  int solverCalls = 0;
  int solverTimeouts = 0;
  
  // MUCH higher iteration counts for high complexity
  int maxAttempts;
  if (complexity <= 2.0) {
    maxAttempts = count * 100;
  } else if (complexity <= 4.0) {
    maxAttempts = count * 200;
  } else if (complexity <= 6.0) {
    maxAttempts = count * 500;
  } else {
    maxAttempts = count * 1000;
  }

  // Target move ranges based on complexity
  int minMovesTarget;
  int maxMovesTarget;
  int maxSolverMoves;

  if (complexity <= 2.0) {
    minMovesTarget = 8;
    maxMovesTarget = 18;
    maxSolverMoves = 40;
  } else if (complexity <= 4.0) {
    minMovesTarget = 12;
    maxMovesTarget = 25;
    maxSolverMoves = 50;
  } else if (complexity <= 6.0) {
    minMovesTarget = 18;
    maxMovesTarget = 35;
    maxSolverMoves = 60;
  } else if (complexity <= 7.0) {
    minMovesTarget = 25;
    maxMovesTarget = 45;
    maxSolverMoves = 80;
  } else {
    minMovesTarget = 30;
    maxMovesTarget = 60;
    maxSolverMoves = 100;
  }

  print('  Target: $minMovesTarget-$maxMovesTarget moves, max depth: $maxSolverMoves, max attempts: $maxAttempts');

  final reportInterval = maxAttempts > 5000 ? 500 : 100;
  final startTime = DateTime.now();
  var lastReportTime = startTime;

  while (puzzles.length < count && attempts < maxAttempts) {
    attempts++;
    
    // Time-based progress updates
    final now = DateTime.now();
    if (now.difference(lastReportTime).inSeconds >= 10) {
      final elapsed = now.difference(startTime).inSeconds;
      final rate = attempts > 0 ? (puzzles.length / attempts * 100).toStringAsFixed(1) : '0.0';
      print('    ⏱️  ${elapsed}s elapsed | Attempt $attempts | Found ${puzzles.length}/$count (success: $rate%) | Solver timeouts: $solverTimeouts');
      lastReportTime = now;
    }
    
    if (attempts % reportInterval == 0) {
      final rate = attempts > 0 ? (puzzles.length / attempts * 100).toStringAsFixed(1) : '0.0';
      print('    Attempt $attempts (found ${puzzles.length}/$count, success rate: $rate%, timeouts: $solverTimeouts)');
    }

    try {
      final puzzle = _generateRandomPuzzle(complexity);
      solverCalls++;
      final solutionLength = _solvePuzzle(puzzle, maxSolverMoves);
      
      if (solutionLength == null) {
        solverTimeouts++;
      } else if (solutionLength >= minMovesTarget && solutionLength <= maxMovesTarget) {
        puzzles.add(GeneratedPuzzle(
          id: 'GRID_${startId + puzzles.length}',
          complexity: complexity,
          minMoves: solutionLength,
          ships: puzzle.ships,
        ));
        
        if (complexity >= 7.0 && puzzles.length % 5 == 0) {
          print('    ✓ Milestone: ${puzzles.length}/$count puzzles found');
        }
      }
    } catch (e) {
      // Silently continue on errors
      continue;
    }
  }

  final elapsed = DateTime.now().difference(startTime);
  final solverSuccessRate = solverCalls > 0 ? ((solverCalls - solverTimeouts) / solverCalls * 100).toStringAsFixed(1) : '0.0';
  
  print('  ⏱️  Completed in ${elapsed.inSeconds}s | Solver success rate: $solverSuccessRate%');

  if (puzzles.length < count) {
    print('    ⚠️  Only found ${puzzles.length}/$count puzzles after $attempts attempts');
  }

  return puzzles;
}

PuzzleConfig _generateRandomPuzzle(double complexity) {
  const gridSize = 6;
  const targetCarRow = 2;
  final random = math.Random();
  
  final ships = <Map<String, dynamic>>[];
  final grid = List.generate(gridSize, (_) => List.filled(gridSize, false));

  // 1. Add player car - vary starting position based on complexity
  int playerStart;
  if (complexity < 3.0) {
    playerStart = random.nextInt(gridSize - 2); // Anywhere
  } else if (complexity < 6.0) {
    playerStart = random.nextInt(2); // Favor left side (0-1)
  } else {
    playerStart = 0; // Force leftmost for hardest puzzles
  }
  
  final playerShip = {
    'row': targetCarRow,
    'col': playerStart,
    'length': 2,
    'isHorizontal': true,
    'isPlayer': true,
  };
  ships.add(playerShip);
  _markGrid(grid, playerShip, true);

  // 2. Add blocking ships - more ships for higher complexity
  int numCars;
  if (complexity <= 2.0) {
    numCars = 6 + random.nextInt(3);   // 6-8 ships
  } else if (complexity <= 4.0) {
    numCars = 8 + random.nextInt(4);   // 8-11 ships
  } else if (complexity <= 6.0) {
    numCars = 10 + random.nextInt(5);  // 10-14 ships
  } else {
    numCars = 12 + random.nextInt(5);  // 12-16 ships for hardest
  }
  
  int attempts = 0;
  const maxPlacementAttempts = 300;
  
  // Strategy: For high complexity, prioritize blocking positions
  final blockingPositions = <Map<String, dynamic>>[];
  
  // Key blocking columns for player exit
  if (complexity >= 5.0) {
    // Add vertical ships that block the player's path
    for (int col = playerStart + 2; col < gridSize; col++) {
      if (random.nextDouble() < 0.7) {
        blockingPositions.add({
          'col': col,
          'preferVertical': true,
          'priority': 'high',
        });
      }
    }
  }
  
  while (ships.length < numCars && attempts < maxPlacementAttempts) {
    attempts++;
    
    bool useBlockingStrategy = complexity >= 5.0 && 
                               blockingPositions.isNotEmpty && 
                               random.nextDouble() < 0.5;
    
    Map<String, dynamic> newShip;
    
    if (useBlockingStrategy) {
      // Use blocking strategy
      final blockPos = blockingPositions.removeAt(random.nextInt(blockingPositions.length));
      final col = blockPos['col'] as int;
      final preferVertical = blockPos['preferVertical'] as bool;
      
      final length = random.nextBool() ? 2 : 3;
      final isHorizontal = preferVertical ? false : random.nextBool();
      
      if (isHorizontal) {
        final maxStart = gridSize - length;
        final start = random.nextInt(maxStart + 1);
        final row = random.nextInt(gridSize);
        newShip = {
          'row': row,
          'col': start,
          'length': length,
          'isHorizontal': true,
          'isPlayer': false,
        };
      } else {
        // Vertical ship in blocking column
        final maxStart = gridSize - length;
        final start = random.nextInt(maxStart + 1);
        newShip = {
          'row': start,
          'col': col,
          'length': length,
          'isHorizontal': false,
          'isPlayer': false,
        };
      }
    } else {
      // Random placement
      final isHorizontal = random.nextBool();
      final length = (complexity >= 5.0 && random.nextDouble() < 0.4) ? 3 : 2;
      final rowOrCol = random.nextInt(gridSize);
      final maxStart = gridSize - length;
      final start = random.nextInt(maxStart + 1);

      newShip = isHorizontal
          ? {
              'row': rowOrCol,
              'col': start,
              'length': length,
              'isHorizontal': true,
              'isPlayer': false,
            }
          : {
              'row': start,
              'col': rowOrCol,
              'length': length,
              'isHorizontal': false,
              'isPlayer': false,
            };
    }

    if (_canPlaceShip(grid, newShip)) {
      ships.add(newShip);
      _markGrid(grid, newShip, true);
      attempts = 0;
    }
  }

  return PuzzleConfig(ships: ships);
}

bool _canPlaceShip(List<List<bool>> grid, Map<String, dynamic> ship) {
  const gridSize = 6;
  final row = ship['row'] as int;
  final col = ship['col'] as int;
  final length = ship['length'] as int;
  final isHorizontal = ship['isHorizontal'] as bool;

  for (int i = 0; i < length; i++) {
    final r = isHorizontal ? row : row + i;
    final c = isHorizontal ? col + i : col;
    
    if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
    if (grid[r][c]) return false;
  }
  return true;
}

void _markGrid(List<List<bool>> grid, Map<String, dynamic> ship, bool mark) {
  final row = ship['row'] as int;
  final col = ship['col'] as int;
  final length = ship['length'] as int;
  final isHorizontal = ship['isHorizontal'] as bool;

  for (int i = 0; i < length; i++) {
    final r = isHorizontal ? row : row + i;
    final c = isHorizontal ? col + i : col;
    grid[r][c] = mark;
  }
}

int? _solvePuzzle(PuzzleConfig config, int maxMoves) {
  const gridSize = 6;
  final queue = Queue<SolverState>();
  final visited = <String>{};
  
  final initialState = SolverState(config.ships, 0);
  queue.add(initialState);
  visited.add(initialState.hashKey);

  int nodesExplored = 0;
  const maxNodes = 15000;
  
  while (queue.isNotEmpty && nodesExplored < maxNodes) {
    final current = queue.removeFirst();
    nodesExplored++;
    
    // Check win condition
    final playerShip = current.ships.firstWhere((s) => s['isPlayer'] == true);
    final playerCol = playerShip['col'] as int;
    final playerLength = playerShip['length'] as int;
    
    if (playerCol + playerLength >= gridSize) {
      return current.moves;
    }
    
    // Don't explore beyond maxMoves
    if (current.moves >= maxMoves) continue;
    
    // Try all possible moves
    for (int shipIdx = 0; shipIdx < current.ships.length; shipIdx++) {
      for (final direction in [-1, 1]) {
        final newShip = _tryMove(current.ships[shipIdx], direction);
        if (newShip != null && !_checkCollision(current.ships, shipIdx, newShip)) {
          final newShips = List<Map<String, dynamic>>.from(current.ships);
          newShips[shipIdx] = newShip;
          
          final newState = SolverState(newShips, current.moves + 1);
          
          if (!visited.contains(newState.hashKey)) {
            visited.add(newState.hashKey);
            queue.add(newState);
          }
        }
      }
    }
  }
  
  return null; // No solution found
}

Map<String, dynamic>? _tryMove(Map<String, dynamic> ship, int direction) {
  const gridSize = 6;
  final isHorizontal = ship['isHorizontal'] as bool;
  final row = ship['row'] as int;
  final col = ship['col'] as int;
  final length = ship['length'] as int;
  
  if (isHorizontal) {
    final newCol = col + direction;
    if (newCol < 0 || newCol + length > gridSize) return null;
    return {...ship, 'col': newCol};
  } else {
    final newRow = row + direction;
    if (newRow < 0 || newRow + length > gridSize) return null;
    return {...ship, 'row': newRow};
  }
}

bool _checkCollision(List<Map<String, dynamic>> ships, int movedIdx, Map<String, dynamic> movedShip) {
  final movedRow = movedShip['row'] as int;
  final movedCol = movedShip['col'] as int;
  final movedLength = movedShip['length'] as int;
  final movedHorizontal = movedShip['isHorizontal'] as bool;
  
  for (int i = 0; i < ships.length; i++) {
    if (i == movedIdx) continue;
    
    final ship = ships[i];
    final shipRow = ship['row'] as int;
    final shipCol = ship['col'] as int;
    final shipLength = ship['length'] as int;
    final shipHorizontal = ship['isHorizontal'] as bool;
    
    final movedCells = <String>{};
    final shipCells = <String>{};
    
    for (int j = 0; j < movedLength; j++) {
      final r = movedHorizontal ? movedRow : movedRow + j;
      final c = movedHorizontal ? movedCol + j : movedCol;
      movedCells.add('$r,$c');
    }
    
    for (int j = 0; j < shipLength; j++) {
      final r = shipHorizontal ? shipRow : shipRow + j;
      final c = shipHorizontal ? shipCol + j : shipCol;
      shipCells.add('$r,$c');
    }
    
    if (movedCells.intersection(shipCells).isNotEmpty) {
      return true;
    }
  }
  
  return false;
}

Future<List<GeneratedPuzzle>> _loadExistingPuzzles() async {
  final file = File(outputFile);
  
  if (!await file.exists()) {
    print('📄 No existing file found, starting fresh');
    return [];
  }

  try {
    print('📖 Reading existing puzzles from $outputFile...');
    final content = await file.readAsString();
    
    final puzzles = <GeneratedPuzzle>[];
    final puzzlePattern = RegExp(
      r"GridlockPuzzleData\(\s*id:\s*'([^']+)',\s*complexity:\s*([\d.]+),\s*minMoves:\s*(\d+),\s*ships:\s*\[([\s\S]*?)\],\s*\)",
      multiLine: true,
    );
    
    for (final match in puzzlePattern.allMatches(content)) {
      final id = match.group(1)!;
      final complexity = double.parse(match.group(2)!);
      final minMoves = int.parse(match.group(3)!);
      final shipsStr = match.group(4)!;
      
      final ships = <Map<String, dynamic>>[];
      final shipPattern = RegExp(r"\{([^}]+)\}");
      
      for (final shipMatch in shipPattern.allMatches(shipsStr)) {
        final shipStr = shipMatch.group(1)!;
        final ship = <String, dynamic>{};
        
        final rowMatch = RegExp(r"'row':\s*(\d+)").firstMatch(shipStr);
        final colMatch = RegExp(r"'col':\s*(\d+)").firstMatch(shipStr);
        final lengthMatch = RegExp(r"'length':\s*(\d+)").firstMatch(shipStr);
        final isHMatch = RegExp(r"'isHorizontal':\s*(true|false)").firstMatch(shipStr);
        final isPlayerMatch = RegExp(r"'isPlayer':\s*(true|false)").firstMatch(shipStr);
        
        if (rowMatch != null) ship['row'] = int.parse(rowMatch.group(1)!);
        if (colMatch != null) ship['col'] = int.parse(colMatch.group(1)!);
        if (lengthMatch != null) ship['length'] = int.parse(lengthMatch.group(1)!);
        if (isHMatch != null) ship['isHorizontal'] = isHMatch.group(1) == 'true';
        if (isPlayerMatch != null) ship['isPlayer'] = isPlayerMatch.group(1) == 'true';
        
        if (ship.isNotEmpty) {
          ships.add(ship);
        }
      }
      
      if (ships.isNotEmpty) {
        puzzles.add(GeneratedPuzzle(
          id: id,
          complexity: complexity,
          minMoves: minMoves,
          ships: ships,
        ));
      }
    }
    
    return puzzles;
  } catch (e) {
    print('⚠️  Error loading existing puzzles: $e');
    print('   Creating backup and starting fresh...');
    
    try {
      await file.copy(backupFile);
      print('   📋 Backup saved to $backupFile');
    } catch (_) {}
    
    return [];
  }
}

Future<void> _savePuzzlesAtomic(List<GeneratedPuzzle> puzzles) async {
  try {
    final tempFileHandle = File(tempFile);
    final sink = tempFileHandle.openWrite();
    
    _writePuzzleContent(sink, puzzles);
    
    await sink.flush();
    await sink.close();
    
    final outputFileHandle = File(outputFile);
    
    if (await outputFileHandle.exists()) {
      try {
        await outputFileHandle.copy(backupFile);
      } catch (_) {}
    }
    
    try {
      await tempFileHandle.rename(outputFile);
    } catch (e) {
      await tempFileHandle.copy(outputFile);
      await tempFileHandle.delete();
    }
    
  } catch (e) {
    print('❌ Error saving puzzles: $e');
    rethrow;
  }
}

void _writePuzzleContent(IOSink sink, List<GeneratedPuzzle> puzzles) {
  sink.writeln('// gridlock_puzzles_data.dart');
  sink.writeln('// AUTO-GENERATED - DO NOT EDIT MANUALLY');
  sink.writeln('// Generated: ${DateTime.now().toIso8601String()}');
  sink.writeln('// Total puzzles: ${puzzles.length}\n');
  
  sink.writeln('class GridlockPuzzleData {');
  sink.writeln('  final String id;');
  sink.writeln('  final double complexity;');
  sink.writeln('  final int minMoves;');
  sink.writeln('  final List<Map<String, dynamic>> ships;\n');
  
  sink.writeln('  const GridlockPuzzleData({');
  sink.writeln('    required this.id,');
  sink.writeln('    required this.complexity,');
  sink.writeln('    required this.minMoves,');
  sink.writeln('    required this.ships,');
  sink.writeln('  });');
  sink.writeln('}\n');
  
  sink.writeln('const gridlockPuzzles = <GridlockPuzzleData>[');
  
  final sortedPuzzles = List<GeneratedPuzzle>.from(puzzles);
  sortedPuzzles.sort((a, b) {
    final compCompare = a.complexity.compareTo(b.complexity);
    if (compCompare != 0) return compCompare;
    return a.id.compareTo(b.id);
  });
  
  for (final puzzle in sortedPuzzles) {
    sink.writeln('  GridlockPuzzleData(');
    sink.writeln('    id: \'${puzzle.id}\',');
    sink.writeln('    complexity: ${puzzle.complexity},');
    sink.writeln('    minMoves: ${puzzle.minMoves},');
    sink.writeln('    ships: [');
    
    for (final ship in puzzle.ships) {
      sink.write('      {');
      sink.write('\'row\': ${ship['row']}, ');
      sink.write('\'col\': ${ship['col']}, ');
      sink.write('\'length\': ${ship['length']}, ');
      sink.write('\'isHorizontal\': ${ship['isHorizontal']}, ');
      sink.write('\'isPlayer\': ${ship['isPlayer'] ?? false}');
      sink.writeln('},');
    }
    
    sink.writeln('    ],');
    sink.writeln('  ),');
  }
  
  sink.writeln('];\n');
  
  sink.writeln('List<GridlockPuzzleData> getPuzzlesByComplexity(double complexity, {double tolerance = 0.3}) {');
  sink.writeln('  return gridlockPuzzles');
  sink.writeln('      .where((p) => (p.complexity - complexity).abs() <= tolerance)');
  sink.writeln('      .toList();');
  sink.writeln('}');
}

// Data classes
class GeneratedPuzzle {
  final String id;
  final double complexity;
  final int minMoves;
  final List<Map<String, dynamic>> ships;

  GeneratedPuzzle({
    required this.id,
    required this.complexity,
    required this.minMoves,
    required this.ships,
  });
}

class PuzzleConfig {
  final List<Map<String, dynamic>> ships;
  PuzzleConfig({required this.ships});
}

class SolverState {
  final List<Map<String, dynamic>> ships;
  final int moves;
  late final String hashKey;
  
  SolverState(this.ships, this.moves) {
    final sorted = List<Map<String, dynamic>>.from(ships);
    sorted.sort((a, b) {
      final rowComp = (a['row'] as int).compareTo(b['row'] as int);
      if (rowComp != 0) return rowComp;
      final colComp = (a['col'] as int).compareTo(b['col'] as int);
      if (colComp != 0) return colComp;
      return (a['length'] as int).compareTo(b['length'] as int);
    });
    hashKey = sorted.map((s) => 
      '${s['row']},${s['col']},${s['length']},${s['isHorizontal'] ? "H" : "V"}'
    ).join('|');
  }
}