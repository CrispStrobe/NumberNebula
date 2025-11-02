// convert_rush_database.dart
// Converts Michael Fogleman's Rush Hour database to Dart puzzle format
// Usage: dart run convert_rush_database.dart input.txt output.dart

import 'dart:io';
import 'dart:math' as math;

const int gridSize = 6;

// Configuration: puzzles per complexity level
const int puzzlesPerLevel = 200;

void main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    print('Usage: dart run convert_rush_database.dart <input_file> <output_file> [puzzles_per_level]');
    print('');
    print('Example: dart run convert_rush_database.dart rush.txt gridlock_puzzles_data.dart 200');
    print('');
    print('Default puzzles_per_level: $puzzlesPerLevel');
    exit(1);
  }

  final inputFile = args[0];
  final outputFile = args[1];
  final perLevel = args.length == 3 ? int.parse(args[2]) : puzzlesPerLevel;

  print('🎮 Rush Hour Database Converter');
  print('=' * 60);
  print('Input:  $inputFile');
  print('Output: $outputFile');
  print('Target: $perLevel puzzles per complexity level\n');

  // Check if input file exists
  if (!await File(inputFile).exists()) {
    print('❌ Error: Input file not found: $inputFile');
    exit(1);
  }

  // Read and parse input
  final lines = await File(inputFile).readAsLines();
  print('📖 Reading ${lines.length} puzzles...\n');

  final puzzles = <ParsedPuzzle>[];
  int skipped = 0;
  int wallCount = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final puzzle = parseLine(line, i + 1);
    if (puzzle != null) {
      // we KEEP puzzles with walls!
      puzzles.add(puzzle);
    } else {
      skipped++;
    }

    if ((i + 1) % 10000 == 0) {
      print('  Processed ${i + 1} lines... (${puzzles.length} valid, $skipped skipped)');
    }
  }

  print('\n✅ Parsed ${puzzles.length} valid puzzles');
  print('   Skipped $skipped puzzles');
  print('   Includes $wallCount puzzles with 1x1 walls (converted to blocking pieces)\n');

  // Map complexity based on moves
  assignComplexity(puzzles);
  
  // Show distribution BEFORE filtering
  print('');
  print('📈 Distribution before filtering:');
  final preFilterDist = <double, int>{};
  for (final p in puzzles) {
    preFilterDist[p.complexity] = (preFilterDist[p.complexity] ?? 0) + 1;
  }
  for (final key in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]) {
    if (preFilterDist.containsKey(key)) {
      print('   Level $key: ${preFilterDist[key]} puzzles');
    }
  }

  // Filter to keep only the coolest puzzles
  print('');
  print('🎯 Selecting the coolest $perLevel puzzles per complexity level...');
  final filtered = filterCoolestPuzzles(puzzles, perLevel);
  print('   Selected ${filtered.length} total puzzles\n');

  // Write output
  print('💾 Writing to $outputFile...');
  await writeDartFile(outputFile, filtered);

  // Print statistics
  printStatistics(filtered);

  print('\n🎉 Conversion complete!');
}

ParsedPuzzle? parseLine(String line, int lineNumber) {
  final parts = line.split(' ');
  if (parts.length < 2) return null;

  try {
    final moves = int.parse(parts[0]);
    final boardDesc = parts[1];
    final clusterSize = parts.length > 2 ? int.parse(parts[2]) : 0;

    if (boardDesc.length != gridSize * gridSize) {
      print('⚠️  Line $lineNumber: Invalid board size (${boardDesc.length} chars)');
      return null;
    }

    final ships = parseBoard(boardDesc);
    if (ships.isEmpty) {
      print('⚠️  Line $lineNumber: No ships found');
      return null;
    }

    final hasWalls = boardDesc.contains('x');

    return ParsedPuzzle(
      moves: moves,
      ships: ships,
      clusterSize: clusterSize,
      hasWalls: hasWalls,
      originalBoard: boardDesc,
    );
  } catch (e) {
    print('⚠️  Line $lineNumber: Parse error: $e');
    return null;
  }
}

List<Map<String, dynamic>> parseBoard(String boardDesc) {
  final ships = <Map<String, dynamic>>[];
  final pieceChars = <String, List<int>>{};
  final wallPositions = <int>[];

  // Map character positions
  for (int i = 0; i < boardDesc.length; i++) {
    final char = boardDesc[i];
    if (char == 'x') {
      wallPositions.add(i);
    } else if (char != '.' && char != 'o') {
      pieceChars.putIfAbsent(char, () => []).add(i);
    }
  }

  // Sort so 'A' (primary) comes first
  final sortedChars = pieceChars.keys.toList()..sort();

  for (final char in sortedChars) {
    final positions = pieceChars[char]!;
    if (positions.length < 2) continue; // Must be at least size 2

    final ship = buildShip(positions, char == 'A');
    if (ship != null) {
      ship['isBlocking'] = false;
      ships.add(ship);
    }
  }

  // Convert each wall to a simple 1x1 blocking piece
  for (final wallPos in wallPositions) {
    ships.add({
      'row': wallPos ~/ gridSize,
      'col': wallPos % gridSize,
      'length': 1,  // 1x1 wall!
      'isHorizontal': true,  // Doesn't matter for 1x1
      'isPlayer': false,
      'isBlocking': true,
    });
  }

  return ships;
}

bool _isOccupied(Map<String, List<int>> pieceChars, int pos) {
  for (final positions in pieceChars.values) {
    if (positions.contains(pos)) return true;
  }
  return false;
}

Map<String, dynamic>? buildShip(List<int> positions, bool isPlayer) {
  if (positions.isEmpty) return null;

  positions.sort();
  final first = positions.first;
  final row = first ~/ gridSize;
  final col = first % gridSize;

  // Determine orientation and validate
  bool isHorizontal;
  if (positions.length == 1) {
    return null; // Invalid single-cell piece
  }

  final stride = positions[1] - positions[0];
  if (stride == 1) {
    isHorizontal = true;
  } else if (stride == gridSize) {
    isHorizontal = false;
  } else {
    return null; // Invalid spacing
  }

  // Validate contiguous
  for (int i = 1; i < positions.length; i++) {
    if (positions[i] - positions[i - 1] != stride) {
      return null; // Not contiguous
    }
  }

  return {
    'row': row,
    'col': col,
    'length': positions.length,
    'isHorizontal': isHorizontal,
    'isPlayer': isPlayer,
  };
}

void assignComplexity(List<ParsedPuzzle> puzzles) {
  print('📊 Assigning complexity levels (7 BROAD LEVELS ONLY)...');
  print('   Consolidating into levels: 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0');

  // ONLY 7 LEVELS - broader ranges to ensure 100+ puzzles per level
  for (final puzzle in puzzles) {
    final moves = puzzle.moves;
    
    // Level 1.0: Easy (7-12 moves)
    if (moves <= 12) {
      puzzle.complexity = 1.0;
    } 
    // Level 2.0: Easy+ (13-17 moves)
    else if (moves <= 17) {
      puzzle.complexity = 2.0;
    } 
    // Level 3.0: Medium (18-23 moves)
    else if (moves <= 23) {
      puzzle.complexity = 3.0;
    } 
    // Level 4.0: Medium+ (24-29 moves)
    else if (moves <= 29) {
      puzzle.complexity = 4.0;
    } 
    // Level 5.0: Hard (30-36 moves)
    else if (moves <= 36) {
      puzzle.complexity = 5.0;
    } 
    // Level 6.0: Hard+ (37-44 moves)
    else if (moves <= 44) {
      puzzle.complexity = 6.0;
    } 
    // Level 7.0: Expert (45+ moves) - ALL the super hard ones!
    else {
      puzzle.complexity = 7.0;
    }
  }
  
  print('   ✓ Complexity assignment complete');
}

List<ParsedPuzzle> filterCoolestPuzzles(List<ParsedPuzzle> puzzles, int perLevel) {
  // Group by complexity
  final byComplexity = <double, List<ParsedPuzzle>>{};
  for (final puzzle in puzzles) {
    byComplexity.putIfAbsent(puzzle.complexity, () => []).add(puzzle);
  }

  final filtered = <ParsedPuzzle>[];

  for (final complexity in byComplexity.keys.toList()..sort()) {
    final list = byComplexity[complexity]!;
    
    // Calculate "coolness" score for each puzzle
    for (final puzzle in list) {
      // Factors that make a puzzle "cool":
      // 1. More moves = harder/more interesting (weight: 0.4)
      // 2. More pieces = more complex (weight: 0.3)
      // 3. Larger cluster size = more varied solutions (weight: 0.2)
      // 4. Balanced piece distribution (weight: 0.1)
      
      final moveScore = puzzle.moves / 70.0; // Normalize to 0-1
      final pieceScore = (puzzle.ships.length - 2) / 16.0; // 2-18 pieces normalized
      final clusterScore = math.min(1.0, puzzle.clusterSize / 100000.0); // Normalize
      
      // Variety score: prefer mix of horizontal/vertical pieces
      final horizontal = puzzle.ships.where((s) => s['isHorizontal'] == true).length;
      final vertical = puzzle.ships.length - horizontal;
      final balance = 1.0 - (horizontal - vertical).abs() / puzzle.ships.length;
      
      puzzle.coolness = moveScore * 0.4 + 
                       pieceScore * 0.3 + 
                       clusterScore * 0.2 +
                       balance * 0.1;
    }

    // Sort by coolness (descending) and take top N
    list.sort((a, b) => b.coolness.compareTo(a.coolness));
    final selected = list.take(math.min(perLevel, list.length)).toList();
    
    print('  Complexity $complexity: Selected ${selected.length} from ${list.length} puzzles');
    filtered.addAll(selected);
  }

  return filtered;
}

Future<void> writeDartFile(String outputFile, List<ParsedPuzzle> puzzles) async {
  final sink = File(outputFile).openWrite();

  // Write header
  sink.writeln('// gridlock_puzzles_data.dart');
  sink.writeln('// AUTO-GENERATED FROM RUSH HOUR DATABASE - DO NOT EDIT MANUALLY');
  sink.writeln('// Converted: ${DateTime.now().toIso8601String()}');
  sink.writeln('// Total puzzles: ${puzzles.length}');
  sink.writeln('// Source: Michael Fogleman\'s Rush Hour Database');
  sink.writeln('//');
  sink.writeln('// Difficulty Mapping (Grades 1-4, Levels 1-20 each):');
  sink.writeln('//   1.0 (Easy):     7-12 moves  → Grade 1, Levels 1-6');
  sink.writeln('//   2.0 (Easy+):    13-17 moves → Grade 1 L7-14, Grade 2 L1-4');
  sink.writeln('//   3.0 (Medium):   18-23 moves → Grade 1 L15-20, Grade 2 L5-13');
  sink.writeln('//   4.0 (Medium+):  24-29 moves → Grade 2 L14-20, Grade 3 L1-12');
  sink.writeln('//   5.0 (Hard):     30-36 moves → Grade 3 L13-19, Grade 4 L1-9');
  sink.writeln('//   6.0 (Hard+):    37-44 moves → Grade 3 L20, Grade 4 L10-17');
  sink.writeln('//   7.0 (Expert):   45+ moves   → Grade 4, Levels 18-20');
  sink.writeln('');

  // Write class definition
  sink.writeln('class GridlockPuzzleData {');
  sink.writeln('  final String id;');
  sink.writeln('  final double complexity;');
  sink.writeln('  final int minMoves;');
  sink.writeln('  final List<Map<String, dynamic>> ships;\n');
  sink.writeln('  final String? originalBoard;\n');
  
  sink.writeln('  const GridlockPuzzleData({');
  sink.writeln('    required this.id,');
  sink.writeln('    required this.complexity,');
  sink.writeln('    required this.minMoves,');
  sink.writeln('    required this.ships,');
  sink.writeln('    this.originalBoard,');
  sink.writeln('  });');
  sink.writeln('}\n');

  // Sort by complexity then moves
  puzzles.sort((a, b) {
    final compCompare = a.complexity.compareTo(b.complexity);
    if (compCompare != 0) return compCompare;
    return a.moves.compareTo(b.moves);
  });

  // Write puzzle list
  sink.writeln('const gridlockPuzzles = <GridlockPuzzleData>[');

  for (int i = 0; i < puzzles.length; i++) {
    final puzzle = puzzles[i];
    final id = 'GRID_${i + 1}';

    sink.writeln('  GridlockPuzzleData(');
    sink.writeln('    id: \'$id\',');
    sink.writeln('    complexity: ${puzzle.complexity},');
    sink.writeln('    minMoves: ${puzzle.moves},');
    sink.writeln('    originalBoard: \'${puzzle.originalBoard}\',');
    sink.writeln('    ships: [');

    for (final ship in puzzle.ships) {
      sink.write('      {');
      sink.write('\'row\': ${ship['row']}, ');
      sink.write('\'col\': ${ship['col']}, ');
      sink.write('\'length\': ${ship['length']}, ');
      sink.write('\'isHorizontal\': ${ship['isHorizontal']}, ');
      sink.write('\'isPlayer\': ${ship['isPlayer']}, ');
      sink.write('\'isBlocking\': ${ship['isBlocking'] ?? false}');
      sink.writeln('},');
    }

    sink.writeln('    ],');
    sink.writeln('  ),');
  }

  sink.writeln('];\n');

  // Write helper function
  sink.writeln('List<GridlockPuzzleData> getPuzzlesByComplexity(double complexity, {double tolerance = 0.0}) {');
  sink.writeln('  return gridlockPuzzles');
  sink.writeln('      .where((p) => (p.complexity - complexity).abs() <= tolerance)');
  sink.writeln('      .toList();');
  sink.writeln('}');

  await sink.flush();
  await sink.close();
}

void printStatistics(List<ParsedPuzzle> puzzles) {
  print('\n📊 Puzzle Statistics:');
  print('=' * 60);

  final byComplexity = <double, List<ParsedPuzzle>>{};
  for (final puzzle in puzzles) {
    byComplexity.putIfAbsent(puzzle.complexity, () => []).add(puzzle);
  }

  final complexities = byComplexity.keys.toList()..sort();

  for (final complexity in complexities) {
    final list = byComplexity[complexity]!;
    final avgMoves = list.map((p) => p.moves).reduce((a, b) => a + b) / list.length;
    final minMoves = list.map((p) => p.moves).reduce(math.min);
    final maxMoves = list.map((p) => p.moves).reduce(math.max);
    final avgShips = list.map((p) => p.ships.length).reduce((a, b) => a + b) / list.length;

    final difficulty = complexity <= 2.0 ? 'Easy  ' :
                      complexity <= 4.0 ? 'Medium' :
                      complexity <= 6.0 ? 'Hard  ' : 'Expert';

    print('$difficulty $complexity: ${list.length.toString().padLeft(6)} puzzles | '
          'Moves: ${minMoves.toString().padLeft(2)}-${maxMoves.toString().padLeft(2)} '
          '(avg: ${avgMoves.toStringAsFixed(1).padLeft(4)}) | '
          'Ships: ${avgShips.toStringAsFixed(1)}');
  }

  print('=' * 60);
  print('Total: ${puzzles.length} puzzles');
  print('');
  print('Expected distribution with 200 per level:');
  print('  Level 1.0 (Easy):     ~${(puzzles.where((p) => p.complexity == 1.0).length).toString().padLeft(4)} available');
  print('  Level 2.0 (Easy+):    ~${(puzzles.where((p) => p.complexity == 2.0).length).toString().padLeft(4)} available');
  print('  Level 3.0 (Medium):   ~${(puzzles.where((p) => p.complexity == 3.0).length).toString().padLeft(4)} available');
  print('  Level 4.0 (Medium+):  ~${(puzzles.where((p) => p.complexity == 4.0).length).toString().padLeft(4)} available');
  print('  Level 5.0 (Hard):     ~${(puzzles.where((p) => p.complexity == 5.0).length).toString().padLeft(4)} available');
  print('  Level 6.0 (Hard+):    ~${(puzzles.where((p) => p.complexity == 6.0).length).toString().padLeft(4)} available');
  print('  Level 7.0 (Expert):   ~${(puzzles.where((p) => p.complexity == 7.0).length).toString().padLeft(4)} available');
}

class ParsedPuzzle {
  final int moves;
  final List<Map<String, dynamic>> ships;
  final int clusterSize;
  final bool hasWalls;
  final String originalBoard;
  double complexity = 1.0;
  double coolness = 0.0;

  ParsedPuzzle({
    required this.moves,
    required this.ships,
    required this.clusterSize,
    required this.hasWalls,
    required this.originalBoard,
  });
}