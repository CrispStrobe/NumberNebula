// test_robot_path_generator.dart
import 'dart:io';
import 'robot_path_generator.dart';

void main(List<String> args) {
  print('🤖 Robot Path Generator Test Suite\n');
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
    case 'visualize':
      visualizeLevel(args);
      break;
    case 'difficulty':
      testDifficulty(args);
      break;
    default:
      showMenu();
  }
}

void showMenu() {
  print('''
Usage:
  dart test_robot_path_generator.dart <command> [options]

Commands:
  generate [dimX] [dimY] [pathLen] [obstacles]  - Generate single level
  batch <count> [dimX] [dimY]                    - Generate multiple levels
  stats <count>                                  - Generate and analyze stats
  visualize [dimX] [dimY] [pathLen] [obstacles]  - Animated visualization
  difficulty                                     - Test different difficulties

Examples:
  dart test_robot_path_generator.dart generate 15 15 20 5
  dart test_robot_path_generator.dart batch 20 12 12
  dart test_robot_path_generator.dart stats 50
  dart test_robot_path_generator.dart visualize 20 20 30 8
  dart test_robot_path_generator.dart difficulty

Difficulty Parameters:
  dimX, dimY       - Grid dimensions (larger = more space)
  pathLen          - Path length (10-50, longer = harder)
  obstacles        - Number of obstacles (2-15, more = harder)
  turnFrequency    - How winding (0.0-1.0, higher = more turns)
  obstacleVariety  - Mix of types (0.0-1.0, higher = more variety)
''');
}

void generateAndDisplay(List<String> args) {
  final dimX = args.length > 1 ? int.tryParse(args[1]) ?? 15 : 15;
  final dimY = args.length > 2 ? int.tryParse(args[2]) ?? 15 : 15;
  final pathLength = args.length > 3 ? int.tryParse(args[3]) ?? 20 : 20;
  final obstacles = args.length > 4 ? int.tryParse(args[4]) ?? 5 : 5;

  print('\n🤖 Generating level: ${dimX}x${dimY}, path=$pathLength, obstacles=$obstacles...\n');

  final generator = RobotPathGenerator();
  final stopwatch = Stopwatch()..start();
  
  final level = generator.generateLevel(
    dimX: dimX,
    dimY: dimY,
    pathLength: pathLength,
    obstacleCount: obstacles,
    turnFrequency: 0.4,
    obstacleVariety: 0.7,
  );
  
  stopwatch.stop();

  displayLevel(level);
  
  print('\n📊 Statistics:');
  print('   Generation time: ${stopwatch.elapsedMilliseconds}ms');
  print('   Optimal moves: ${level.optimalMoves}');
  print('   Grid dimensions: ${level.grid.length}x${level.grid[0].length}');
  print('   Start position: (${level.start.x}, ${level.start.y})');
  print('   Goal position: (${level.goal.x}, ${level.goal.y})');
  print('   Path tiles: ${countPathTiles(level)}');
  print('   Total obstacles: ${level.obstacles.length}');
  
  analyzeObstacles(level);
  
  print('\n🗺️  Layout String Format:');
  print(level.toLayoutString());
}

void batchGenerate(List<String> args) {
  final count = args.length > 1 ? int.tryParse(args[1]) ?? 20 : 20;
  final dimX = args.length > 2 ? int.tryParse(args[2]) ?? 15 : 15;
  final dimY = args.length > 3 ? int.tryParse(args[3]) ?? 15 : 15;

  print('\n🤖 Generating $count levels of size ${dimX}x${dimY}...\n');

  final generator = RobotPathGenerator();
  final times = <int>[];
  final optimalMoves = <int>[];
  final pathLengths = <int>[];
  final obstacleCounts = <int>[];
  int successCount = 0;

  for (int i = 0; i < count; i++) {
    stdout.write('\rProgress: ${i + 1}/$count');
    
    final pathLen = 15 + (i % 20);
    final obstCount = 3 + (i % 8);
    
    final stopwatch = Stopwatch()..start();
    try {
      final level = generator.generateLevel(
        dimX: dimX,
        dimY: dimY,
        pathLength: pathLen,
        obstacleCount: obstCount,
        turnFrequency: 0.3 + (i % 5) * 0.1,
        obstacleVariety: 0.5 + (i % 5) * 0.1,
      );
      stopwatch.stop();
      
      times.add(stopwatch.elapsedMilliseconds);
      optimalMoves.add(level.optimalMoves);
      pathLengths.add(countPathTiles(level));
      obstacleCounts.add(level.obstacles.length);
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
    print('\n⏱️  Generation Time:');
    final avgTime = times.reduce((a, b) => a + b) / times.length;
    final minTime = times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.reduce((a, b) => a > b ? a : b);
    print('   Average: ${avgTime.toStringAsFixed(1)}ms');
    print('   Range: ${minTime}ms - ${maxTime}ms');
    
    print('\n🎯 Optimal Moves:');
    final avgOptimal = optimalMoves.reduce((a, b) => a + b) / optimalMoves.length;
    final minOptimal = optimalMoves.reduce((a, b) => a < b ? a : b);
    final maxOptimal = optimalMoves.reduce((a, b) => a > b ? a : b);
    print('   Average: ${avgOptimal.toStringAsFixed(1)}');
    print('   Range: $minOptimal - $maxOptimal');
    
    print('\n🛤️  Path Length:');
    final avgPath = pathLengths.reduce((a, b) => a + b) / pathLengths.length;
    final minPath = pathLengths.reduce((a, b) => a < b ? a : b);
    final maxPath = pathLengths.reduce((a, b) => a > b ? a : b);
    print('   Average: ${avgPath.toStringAsFixed(1)} tiles');
    print('   Range: $minPath - $maxPath tiles');
    
    print('\n🚧 Obstacles:');
    final avgObst = obstacleCounts.reduce((a, b) => a + b) / obstacleCounts.length;
    print('   Average placed: ${avgObst.toStringAsFixed(1)}');
  }
}

void generateStats(List<String> args) {
  final count = args.length > 1 ? int.tryParse(args[1]) ?? 30 : 30;

  print('\n📊 Generating detailed statistics for $count levels...\n');

  final generator = RobotPathGenerator();
  
  final configs = [
    {'name': 'Easy', 'dim': 12, 'path': 15, 'obst': 3, 'turn': 0.2, 'var': 0.5},
    {'name': 'Medium', 'dim': 15, 'path': 25, 'obst': 6, 'turn': 0.4, 'var': 0.7},
    {'name': 'Hard', 'dim': 18, 'path': 35, 'obst': 10, 'turn': 0.6, 'var': 0.9},
    {'name': 'Expert', 'dim': 22, 'path': 45, 'obst': 14, 'turn': 0.7, 'var': 1.0},
  ];

  for (final config in configs) {
    print('\n🎯 Testing ${config['name']} difficulty:');
    print('   Config: ${config['dim']}x${config['dim']}, path=${config['path']}, obstacles=${config['obst']}');
    print('   Turn freq: ${config['turn']}, Variety: ${config['var']}');
    
    final times = <int>[];
    final moves = <int>[];
    final jumpWalls = <int>[];
    final destructibles = <int>[];
    final movables = <int>[];
    int failures = 0;

    for (int i = 0; i < count; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        final level = generator.generateLevel(
          dimX: config['dim'] as int,
          dimY: config['dim'] as int,
          pathLength: config['path'] as int,
          obstacleCount: config['obst'] as int,
          turnFrequency: config['turn'] as double,
          obstacleVariety: config['var'] as double,
        );
        stopwatch.stop();
        
        times.add(stopwatch.elapsedMilliseconds);
        moves.add(level.optimalMoves);
        
        // Count obstacle types
        int jump = 0, dest = 0, move = 0;
        for (var obs in level.obstacles) {
          switch (obs.type) {
            case ObstacleType.jumpWall:
              jump++;
              break;
            case ObstacleType.destructible:
              dest++;
              break;
            case ObstacleType.movable:
              move++;
              break;
          }
        }
        jumpWalls.add(jump);
        destructibles.add(dest);
        movables.add(move);
        
      } catch (e) {
        failures++;
      }
    }

    if (times.isNotEmpty) {
      final avgTime = times.reduce((a, b) => a + b) / times.length;
      final avgMoves = moves.reduce((a, b) => a + b) / moves.length;
      final avgJump = jumpWalls.reduce((a, b) => a + b) / jumpWalls.length;
      final avgDest = destructibles.reduce((a, b) => a + b) / destructibles.length;
      final avgMove = movables.reduce((a, b) => a + b) / movables.length;
      
      print('   ✓ Success: ${count - failures}/$count (${((count - failures) / count * 100).toStringAsFixed(1)}%)');
      print('   ⏱  Avg time: ${avgTime.toStringAsFixed(1)}ms');
      print('   🎯 Avg optimal moves: ${avgMoves.toStringAsFixed(1)}');
      print('   🚧 Avg obstacles: Jump=${avgJump.toStringAsFixed(1)}, Destroy=${avgDest.toStringAsFixed(1)}, Push/Pull=${avgMove.toStringAsFixed(1)}');
    }
  }
}

void visualizeLevel(List<String> args) {
  final dimX = args.length > 1 ? int.tryParse(args[1]) ?? 20 : 20;
  final dimY = args.length > 2 ? int.tryParse(args[2]) ?? 20 : 20;
  final pathLength = args.length > 3 ? int.tryParse(args[3]) ?? 30 : 30;
  final obstacles = args.length > 4 ? int.tryParse(args[4]) ?? 8 : 8;

  print('\n🎬 Interactive Level Visualizer\n');
  
  final generator = RobotPathGenerator();
  var level = generator.generateLevel(
    dimX: dimX,
    dimY: dimY,
    pathLength: pathLength,
    obstacleCount: obstacles,
    turnFrequency: 0.5,
    obstacleVariety: 0.8,
  );

  while (true) {
    print('\n' + '=' * 60);
    displayLevel(level);
    
    print('\n📊 Level Info:');
    print('   Optimal moves: ${level.optimalMoves}');
    print('   Obstacles: ${level.obstacles.length}');
    analyzeObstacles(level);
    
    print('\nCommands:');
    print('  [n] Generate new level');
    print('  [e] Easy difficulty    [m] Medium difficulty');
    print('  [h] Hard difficulty    [x] Expert difficulty');
    print('  [c] Custom parameters  [q] Quit');
    
    stdout.write('\n> ');
    final input = stdin.readLineSync()?.toLowerCase() ?? '';

    switch (input) {
      case 'q':
        print('👋 Goodbye!');
        return;
        
      case 'n':
        print('🎲 Generating new level...');
        level = generator.generateLevel(
          dimX: dimX,
          dimY: dimY,
          pathLength: pathLength,
          obstacleCount: obstacles,
          turnFrequency: 0.5,
          obstacleVariety: 0.8,
        );
        break;
        
      case 'e':
        print('🟢 Generating EASY level...');
        level = generator.generateLevel(
          dimX: 12,
          dimY: 12,
          pathLength: 15,
          obstacleCount: 3,
          turnFrequency: 0.2,
          obstacleVariety: 0.5,
        );
        break;
        
      case 'm':
        print('🟡 Generating MEDIUM level...');
        level = generator.generateLevel(
          dimX: 15,
          dimY: 15,
          pathLength: 25,
          obstacleCount: 6,
          turnFrequency: 0.4,
          obstacleVariety: 0.7,
        );
        break;
        
      case 'h':
        print('🟠 Generating HARD level...');
        level = generator.generateLevel(
          dimX: 18,
          dimY: 18,
          pathLength: 35,
          obstacleCount: 10,
          turnFrequency: 0.6,
          obstacleVariety: 0.9,
        );
        break;
        
      case 'x':
        print('🔴 Generating EXPERT level...');
        level = generator.generateLevel(
          dimX: 22,
          dimY: 22,
          pathLength: 45,
          obstacleCount: 14,
          turnFrequency: 0.7,
          obstacleVariety: 1.0,
        );
        break;
        
      case 'c':
        level = promptCustomLevel(generator);
        break;
        
      default:
        print('❌ Invalid command');
    }
  }
}

void testDifficulty(List<String> args) {
  print('\n🎮 Difficulty Curve Analysis\n');
  print('Testing how parameters affect difficulty...\n');
  
  final generator = RobotPathGenerator();
  
  print('📈 Testing PATH LENGTH impact (fixed 15x15 grid, 5 obstacles):');
  for (int pathLen in [10, 15, 20, 25, 30, 40]) {
    final level = generator.generateLevel(
      dimX: 15,
      dimY: 15,
      pathLength: pathLen,
      obstacleCount: 5,
      turnFrequency: 0.4,
      obstacleVariety: 0.7,
    );
    print('   Path=$pathLen → Optimal moves: ${level.optimalMoves}');
  }
  
  print('\n📈 Testing OBSTACLE COUNT impact (fixed 15x15 grid, path=25):');
  for (int obstCount in [2, 4, 6, 8, 10, 12]) {
    final level = generator.generateLevel(
      dimX: 15,
      dimY: 15,
      pathLength: 25,
      obstacleCount: obstCount,
      turnFrequency: 0.4,
      obstacleVariety: 0.7,
    );
    print('   Obstacles=$obstCount → Optimal moves: ${level.optimalMoves}, Placed: ${level.obstacles.length}');
  }
  
  print('\n📈 Testing TURN FREQUENCY impact (fixed 15x15 grid, path=25, obstacles=6):');
  for (double turn in [0.1, 0.3, 0.5, 0.7, 0.9]) {
    final level = generator.generateLevel(
      dimX: 15,
      dimY: 15,
      pathLength: 25,
      obstacleCount: 6,
      turnFrequency: turn,
      obstacleVariety: 0.7,
    );
    final pathTiles = countPathTiles(level);
    print('   Turn=${turn.toStringAsFixed(1)} → Path tiles: $pathTiles, Optimal moves: ${level.optimalMoves}');
  }
  
  print('\n📈 Testing OBSTACLE VARIETY impact (fixed 15x15 grid, path=25, obstacles=9):');
  for (double variety in [0.0, 0.3, 0.5, 0.7, 1.0]) {
    final level = generator.generateLevel(
      dimX: 15,
      dimY: 15,
      pathLength: 25,
      obstacleCount: 9,
      turnFrequency: 0.4,
      obstacleVariety: variety,
    );
    
    int jump = 0, dest = 0, move = 0;
    for (var obs in level.obstacles) {
      switch (obs.type) {
        case ObstacleType.jumpWall: jump++; break;
        case ObstacleType.destructible: dest++; break;
        case ObstacleType.movable: move++; break;
      }
    }
    print('   Variety=${variety.toStringAsFixed(1)} → Jump:$jump, Destroy:$dest, Push/Pull:$move');
  }
  
  print('\n✅ Difficulty testing complete!');
}

RobotLevel promptCustomLevel(RobotPathGenerator generator) {
  print('\n⚙️  Custom Level Generator\n');
  
  stdout.write('Grid width (8-30): ');
  final dimX = int.tryParse(stdin.readLineSync() ?? '') ?? 15;
  
  stdout.write('Grid height (8-30): ');
  final dimY = int.tryParse(stdin.readLineSync() ?? '') ?? 15;
  
  stdout.write('Path length (10-60): ');
  final pathLen = int.tryParse(stdin.readLineSync() ?? '') ?? 25;
  
  stdout.write('Obstacles (2-20): ');
  final obstacles = int.tryParse(stdin.readLineSync() ?? '') ?? 6;
  
  stdout.write('Turn frequency (0.0-1.0): ');
  final turnFreq = double.tryParse(stdin.readLineSync() ?? '') ?? 0.4;
  
  stdout.write('Obstacle variety (0.0-1.0): ');
  final variety = double.tryParse(stdin.readLineSync() ?? '') ?? 0.7;
  
  print('\n🎲 Generating custom level...');
  return generator.generateLevel(
    dimX: dimX.clamp(8, 30),
    dimY: dimY.clamp(8, 30),
    pathLength: pathLen.clamp(10, 60),
    obstacleCount: obstacles.clamp(2, 20),
    turnFrequency: turnFreq.clamp(0.0, 1.0),
    obstacleVariety: variety.clamp(0.0, 1.0),
  );
}

void displayLevel(RobotLevel level) {
  print('Level Layout:');
  print('┌' + '─' * (level.grid[0].length * 2 + 1) + '┐');
  
  for (int i = 0; i < level.grid.length; i++) {
    stdout.write('│ ');
    for (int j = 0; j < level.grid[i].length; j++) {
      stdout.write(getTileChar(level.grid[i][j]) + ' ');
    }
    print('│');
  }
  
  print('└' + '─' * (level.grid[0].length * 2 + 1) + '┘');
  
  print('\nLegend:');
  print('  █ = Wall       = Path      S = Start     G = Goal');
  print('  ▬ = Jump Wall  ▓ = Destroy  ○ = Push/Pull');
}

void displayLevelCompact(RobotLevel level) {
  for (int i = 0; i < level.grid.length; i++) {
    for (int j = 0; j < level.grid[i].length; j++) {
      stdout.write(getTileChar(level.grid[i][j]));
    }
    print('');
  }
  print('');
}

String getTileChar(int tile) {
  switch (tile) {
    case RobotPathGenerator.WALL:
      return '█';
    case RobotPathGenerator.PATH:
      return ' ';
    case RobotPathGenerator.START:
      return 'S';
    case RobotPathGenerator.GOAL:
      return 'G';
    case RobotPathGenerator.JUMPABLE_WALL:
      return '▬';
    case RobotPathGenerator.DESTRUCTIBLE:
      return '▓';
    case RobotPathGenerator.MOVABLE:
      return '○';
    default:
      return '█';
  }
}

int countPathTiles(RobotLevel level) {
  int count = 0;
  for (final row in level.grid) {
    for (final tile in row) {
      if (tile == RobotPathGenerator.PATH ||
          tile == RobotPathGenerator.START ||
          tile == RobotPathGenerator.GOAL ||
          tile == RobotPathGenerator.JUMPABLE_WALL) {
        count++;
      }
    }
  }
  return count;
}

void analyzeObstacles(RobotLevel level) {
  int jumpWalls = 0;
  int destructibles = 0;
  int movables = 0;
  
  for (var obstacle in level.obstacles) {
    switch (obstacle.type) {
      case ObstacleType.jumpWall:
        jumpWalls++;
        break;
      case ObstacleType.destructible:
        destructibles++;
        break;
      case ObstacleType.movable:
        movables++;
        break;
    }
  }
  
  print('\n🚧 Obstacle Breakdown:');
  print('   Jump walls: $jumpWalls (requires: jump)');
  print('   Destructible: $destructibles (requires: destroy)');
  print('   Movable: $movables (requires: push/pull)');
  
  // Calculate diversity score
  int types = (jumpWalls > 0 ? 1 : 0) + 
              (destructibles > 0 ? 1 : 0) + 
              (movables > 0 ? 1 : 0);
  String diversity = types == 3 ? 'High ⭐⭐⭐' : 
                     types == 2 ? 'Medium ⭐⭐' : 
                     'Low ⭐';
  print('   Diversity: $diversity');
}