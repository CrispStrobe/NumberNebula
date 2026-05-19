// ignore_for_file: avoid_print
// test_level_generator.dart
import 'dart:io';
import 'starloader_level_generator.dart';

void main(List<String> args) {
  print('🎮 StarLoader Level Generator Test Suite\n');
  print('=' * 60);

  if (args.isEmpty) {
    showMenu();
    return;
  }

  final command = args[0].toLowerCase();
  
  switch (command) {
    case 'generate':
      generateAndDisplay(args);
      break;
    case 'batch':
      batchGenerate(args);
      break;
    case 'stats':
      generateStats(args);
      break;
    case 'play':
      playLevel(args);
      break;
    default:
      showMenu();
  }
}

void showMenu() {
  print('''
Usage:
  dart test_level_generator.dart <command> [options]

Commands:
  generate [dimX] [dimY] [boxes]  - Generate and display a single level
  batch <count> [dimX] [dimY]     - Generate multiple levels and show stats
  stats <count>                   - Generate levels and show statistics
  play [dimX] [dimY] [boxes]      - Interactive level testing

Examples:
  dart test_level_generator.dart generate 7 7 2
  dart test_level_generator.dart batch 10 8 8
  dart test_level_generator.dart stats 50
  dart test_level_generator.dart play 10 10 3
''');
}

void generateAndDisplay(List<String> args) {
  final dimX = args.length > 1 ? int.tryParse(args[1]) ?? 10 : 10;
  final dimY = args.length > 2 ? int.tryParse(args[2]) ?? 10 : 10;
  final numBoxes = args.length > 3 ? int.tryParse(args[3]) ?? 3 : 3;

  print('\n📦 Generating level: ${dimX}x$dimY with $numBoxes boxes...\n');

  final generator = LevelGenerator();
  final stopwatch = Stopwatch()..start();
  
  final level = generator.generateLevel(
    dimX: dimX,
    dimY: dimY,
    numBoxes: numBoxes,
  );
  
  stopwatch.stop();

  displayLevel(level);
  
  print('\n📊 Statistics:');
  print('   Generation time: ${stopwatch.elapsedMilliseconds}ms');
  print('   Optimal moves: ${level.optimalMoves}');
  print('   Room dimensions: ${level.roomState.length}x${level.roomState[0].length}');
  print('   Floor tiles: ${countTiles(level, LevelGenerator.FLOOR)}');
  print('   Targets: ${countTargets(level)}');
  print('   Boxes: ${countBoxes(level)}');
  
  print('\n🗺️  Layout String Format:');
  print(level.toLayoutString());
}

void batchGenerate(List<String> args) {
  final count = args.length > 1 ? int.tryParse(args[1]) ?? 10 : 10;
  final dimX = args.length > 2 ? int.tryParse(args[2]) ?? 10 : 10;
  final dimY = args.length > 3 ? int.tryParse(args[3]) ?? 10 : 10;

  print('\n📦 Generating $count levels of size ${dimX}x$dimY...\n');

  final generator = LevelGenerator();
  final times = <int>[];
  final optimalMoves = <int>[];
  int successCount = 0;

  for (int i = 0; i < count; i++) {
    stdout.write('\rProgress: ${i + 1}/$count');
    
    final stopwatch = Stopwatch()..start();
    try {
      final level = generator.generateLevel(
        dimX: dimX,
        dimY: dimY,
        numBoxes: 2 + (i % 4),
      );
      stopwatch.stop();
      
      times.add(stopwatch.elapsedMilliseconds);
      optimalMoves.add(level.optimalMoves);
      successCount++;
      
      if (i < 3) {
        print('\n\nLevel ${i + 1}:');
        displayLevelCompact(level);
      }
    } catch (e) {
      stopwatch.stop();
      print('\n❌ Failed to generate level ${i + 1}: $e');
    }
  }

  print('\n\n📊 Batch Statistics:');
  print('   Success rate: $successCount/$count (${(successCount / count * 100).toStringAsFixed(1)}%)');
  
  if (times.isNotEmpty) {
    final avgTime = times.reduce((a, b) => a + b) / times.length;
    final minTime = times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.reduce((a, b) => a > b ? a : b);
    
    print('   Avg generation time: ${avgTime.toStringAsFixed(1)}ms');
    print('   Min/Max time: ${minTime}ms / ${maxTime}ms');
    
    final avgOptimal = optimalMoves.reduce((a, b) => a + b) / optimalMoves.length;
    final minOptimal = optimalMoves.reduce((a, b) => a < b ? a : b);
    final maxOptimal = optimalMoves.reduce((a, b) => a > b ? a : b);
    
    print('   Avg optimal moves: ${avgOptimal.toStringAsFixed(1)}');
    print('   Min/Max optimal: $minOptimal / $maxOptimal');
  }
}

void generateStats(List<String> args) {
  final count = args.length > 1 ? int.tryParse(args[1]) ?? 20 : 20;

  print('\n📊 Generating detailed statistics for $count levels...\n');

  final generator = LevelGenerator();
  final sizes = [
    [7, 7, 2],
    [8, 8, 3],
    [10, 10, 3],
    [12, 11, 4],
  ];

  for (final size in sizes) {
    print('\n🎯 Testing ${size[0]}x${size[1]} with ${size[2]} boxes:');
    
    final times = <int>[];
    final scores = <int>[];
    int failures = 0;

    for (int i = 0; i < count; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        final level = generator.generateLevel(
          dimX: size[0],
          dimY: size[1],
          numBoxes: size[2],
        );
        stopwatch.stop();
        
        times.add(stopwatch.elapsedMilliseconds);
        scores.add(level.optimalMoves);
      } catch (e) {
        failures++;
      }
    }

    if (times.isNotEmpty) {
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final avgScore = scores.reduce((a, b) => a + b) / scores.length;
      
      print('   ✓ Success: ${count - failures}/$count (${((count - failures) / count * 100).toStringAsFixed(1)}%)');
      print('   ⏱  Avg time: ${avgTime.toStringAsFixed(1)}ms');
      print('   🎯 Avg optimal: ${avgScore.toStringAsFixed(1)} moves');
    }
  }
}

void playLevel(List<String> args) {
  final dimX = args.length > 1 ? int.tryParse(args[1]) ?? 10 : 10;
  final dimY = args.length > 2 ? int.tryParse(args[2]) ?? 10 : 10;
  final numBoxes = args.length > 3 ? int.tryParse(args[3]) ?? 3 : 3;

  print('\n🎮 Interactive Level Tester\n');
  
  final generator = LevelGenerator();
  final level = generator.generateLevel(
    dimX: dimX,
    dimY: dimY,
    numBoxes: numBoxes,
  );

  // Create game state
  var state = level.roomState.map((row) => List<int>.from(row)).toList();
  final structure = level.roomStructure;
  var playerPos = findPlayer(state);
  var moveCount = 0;

  while (true) {
    print('\n${'=' * 60}');
    displayGameState(state, structure);
    print('\nMoves: $moveCount | Optimal: ${level.optimalMoves}');
    print('Commands: w/a/s/d (move), q (quit), r (reset), n (new level)');
    
    stdout.write('\n> ');
    final input = stdin.readLineSync()?.toLowerCase() ?? '';

    if (input == 'q') {
      print('👋 Goodbye!');
      break;
    }

    if (input == 'r') {
      state = level.roomState.map((row) => List<int>.from(row)).toList();
      playerPos = findPlayer(state);
      moveCount = 0;
      print('🔄 Level reset!');
      continue;
    }

    if (input == 'n') {
      print('🎲 Generating new level...');
      final newLevel = generator.generateLevel(
        dimX: dimX,
        dimY: dimY,
        numBoxes: numBoxes,
      );
      state = newLevel.roomState.map((row) => List<int>.from(row)).toList();
      playerPos = findPlayer(state);
      moveCount = 0;
      continue;
    }

    // Handle movement
    int dx = 0, dy = 0;
    switch (input) {
      case 'w': dx = -1; break;
      case 's': dx = 1; break;
      case 'a': dy = -1; break;
      case 'd': dy = 1; break;
      default:
        print('❌ Invalid command');
        continue;
    }

    if (tryMove(state, structure, playerPos, dx, dy)) {
      playerPos = [playerPos[0] + dx, playerPos[1] + dy];
      moveCount++;

      // Check win
      if (checkWin(state, structure)) {
        displayGameState(state, structure);
        print('\n🎉 Congratulations! You solved it in $moveCount moves!');
        print('   Optimal was ${level.optimalMoves} moves.');
        
        if (moveCount <= level.optimalMoves) {
          print('   ⭐⭐⭐ PERFECT! You matched or beat the optimal solution!');
        } else if (moveCount <= level.optimalMoves * 1.2) {
          print('   ⭐⭐ Great job! Very close to optimal!');
        } else {
          print('   ⭐ Good job! Can you do better?');
        }
        
        stdout.write('\nPlay again? (y/n): ');
        final again = stdin.readLineSync()?.toLowerCase() ?? '';
        if (again != 'y') break;
        
        state = level.roomState.map((row) => List<int>.from(row)).toList();
        playerPos = findPlayer(state);
        moveCount = 0;
      }
    } else {
      print('❌ Cannot move there!');
    }
  }
}

void displayLevel(GeneratedLevel level) {
  print('Level Layout:');
  print('┌${'─' * (level.roomState[0].length * 2 + 1)}┐');
  
  for (int i = 0; i < level.roomState.length; i++) {
    stdout.write('│ ');
    for (int j = 0; j < level.roomState[i].length; j++) {
      final state = level.roomState[i][j];
      final structure = level.roomStructure[i][j];
      
      stdout.write('${getTileChar(state, structure)} ');
    }
    print('│');
  }
  
  print('└${'─' * (level.roomState[0].length * 2 + 1)}┘');
  
  print('\nLegend:');
  print('  █ = Wall    · = Floor    ○ = Target    @ = Player');
  print('  □ = Box     ◉ = Box on Target');
}

void displayLevelCompact(GeneratedLevel level) {
  for (int i = 0; i < level.roomState.length; i++) {
    for (int j = 0; j < level.roomState[i].length; j++) {
      final state = level.roomState[i][j];
      final structure = level.roomStructure[i][j];
      stdout.write(getTileChar(state, structure));
    }
    print('');
  }
}

void displayGameState(List<List<int>> state, List<List<int>> structure) {
  print('┌${'─' * (state[0].length * 2 + 1)}┐');
  
  for (int i = 0; i < state.length; i++) {
    stdout.write('│ ');
    for (int j = 0; j < state[i].length; j++) {
      stdout.write('${getTileChar(state[i][j], structure[i][j])} ');
    }
    print('│');
  }
  
  print('└${'─' * (state[0].length * 2 + 1)}┘');
}

String getTileChar(int state, int structure) {
  if (state == LevelGenerator.WALL) return '█';
  if (state == LevelGenerator.PLAYER) {
    return structure == LevelGenerator.TARGET ? '⊕' : '@';
  }
  if (state == LevelGenerator.BOX) {
    return structure == LevelGenerator.TARGET ? '◉' : '□';
  }
  if (structure == LevelGenerator.TARGET) return '○';
  return '·';
}

int countTiles(GeneratedLevel level, int tileType) {
  int count = 0;
  for (final row in level.roomState) {
    for (final tile in row) {
      if (tile == tileType) count++;
    }
  }
  return count;
}

int countTargets(GeneratedLevel level) {
  int count = 0;
  for (final row in level.roomStructure) {
    for (final tile in row) {
      if (tile == LevelGenerator.TARGET) count++;
    }
  }
  return count;
}

int countBoxes(GeneratedLevel level) {
  int count = 0;
  for (final row in level.roomState) {
    for (final tile in row) {
      if (tile == LevelGenerator.BOX) count++;
    }
  }
  return count;
}

List<int> findPlayer(List<List<int>> state) {
  for (int i = 0; i < state.length; i++) {
    for (int j = 0; j < state[i].length; j++) {
      if (state[i][j] == LevelGenerator.PLAYER) {
        return [i, j];
      }
    }
  }
  return [0, 0];
}

bool tryMove(List<List<int>> state, List<List<int>> structure, List<int> playerPos, int dx, int dy) {
  final newX = playerPos[0] + dx;
  final newY = playerPos[1] + dy;

  // Check bounds
  if (newX < 0 || newX >= state.length || newY < 0 || newY >= state[0].length) {
    return false;
  }

  // Check wall
  if (state[newX][newY] == LevelGenerator.WALL) {
    return false;
  }

  // Check box
  if (state[newX][newY] == LevelGenerator.BOX) {
    final boxNewX = newX + dx;
    final boxNewY = newY + dy;

    // Check if box can be pushed
    if (boxNewX < 0 || boxNewX >= state.length || 
        boxNewY < 0 || boxNewY >= state[0].length) {
      return false;
    }

    if (state[boxNewX][boxNewY] != LevelGenerator.FLOOR &&
        state[boxNewX][boxNewY] != LevelGenerator.TARGET) {
      return false;
    }

    // Push box
    state[boxNewX][boxNewY] = LevelGenerator.BOX;
    state[newX][newY] = LevelGenerator.PLAYER;
    state[playerPos[0]][playerPos[1]] = structure[playerPos[0]][playerPos[1]];
    return true;
  }

  // Simple move
  state[newX][newY] = LevelGenerator.PLAYER;
  state[playerPos[0]][playerPos[1]] = structure[playerPos[0]][playerPos[1]];
  return true;
}

bool checkWin(List<List<int>> state, List<List<int>> structure) {
  for (int i = 0; i < structure.length; i++) {
    for (int j = 0; j < structure[i].length; j++) {
      if (structure[i][j] == LevelGenerator.TARGET) {
        if (state[i][j] != LevelGenerator.BOX && state[i][j] != LevelGenerator.PLAYER) {
          return false;
        }
      }
    }
  }
  return true;
}