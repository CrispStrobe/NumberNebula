// lib/features/games/services/starloader_level_generator.dart

import 'dart:math' as math;

class LevelGenerator {
  // --- Tile Constants ---
  static const int WALL = 0;
  static const int FLOOR = 1;
  static const int TARGET = 2;
  static const int BOX_ON_TARGET = 3;
  static const int BOX = 4;
  static const int PLAYER = 5;

  // --- Internal State ---
  final math.Random _random = math.Random();
  final bool _verbose;

  // --- Reverse Play State (Reset on each generation) ---
  Set<String> _exploredStates = {};
  List<List<int>>? _bestRoom;
  int _bestScore = -1;
  Map<String, List<int>>? _bestBoxMapping;

  // --- Statics ---
  static const Map<int, List<int>> CHANGE_COORDINATES = {
    0: [-1, 0], // Up
    1: [1, 0], // Down
    2: [0, -1], // Left
    3: [0, 1], // Right
  };

  static const List<List<List<int>>> MASKS = [
    [
      [0, 0, 0],
      [1, 1, 1],
      [0, 0, 0]
    ],
    [
      [0, 1, 0],
      [0, 1, 0],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [1, 1, 0],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [1, 1, 0],
      [1, 1, 0]
    ],
    [
      [0, 0, 0],
      [0, 1, 1],
      [0, 1, 0]
    ]
  ];

  LevelGenerator({bool verbose = false}) : _verbose = verbose;

  void _log(String message) {
    if (_verbose) {
      print('[LevelGenerator] $message');
    }
  }

  /// Checks if placing a box at [r, c] creates a 2x2 square of obstacles
  /// (Walls or Boxes), which renders the level unsolvable.
  bool _formsDeadlock(List<List<int>> room, int r, int c) {
    // Helper to check if a tile is a solid obstacle
    bool isObstacle(int r, int c) {
      if (r < 0 || r >= room.length || c < 0 || c >= room[0].length) return true; // Bounds are walls
      final tile = room[r][c];
      // Note: In reverse play, BOX and BOX_ON_TARGET are obstacles. 
      // WALL is obviously an obstacle.
      return tile == WALL || tile == BOX || tile == BOX_ON_TARGET;
    }

    // Check the 4 possible 2x2 squares containing (r, c)
    // 1. Top-Left quadrant relative to (r,c)
    if (isObstacle(r - 1, c - 1) && isObstacle(r - 1, c) && isObstacle(r, c - 1)) return true;
    
    // 2. Top-Right quadrant
    if (isObstacle(r - 1, c + 1) && isObstacle(r - 1, c) && isObstacle(r, c + 1)) return true;
    
    // 3. Bottom-Left quadrant
    if (isObstacle(r + 1, c - 1) && isObstacle(r + 1, c) && isObstacle(r, c - 1)) return true;
    
    // 4. Bottom-Right quadrant
    if (isObstacle(r + 1, c + 1) && isObstacle(r + 1, c) && isObstacle(r, c + 1)) return true;

    return false;
  }

  /// Generates a new Sokoban level.
  GeneratedLevel generateLevel({
    required int dimX,
    required int dimY,
    required int numBoxes,
    int? numGenSteps,
    double pChangeDirection = 0.35,
    int maxTries = 4,
  }) {
    _log('Starting level generation ($dimX x $dimY, $numBoxes boxes)...');
    numGenSteps ??= (1.7 * (dimX + dimY)).round();
    _log('Using numGenSteps: $numGenSteps');

    for (int attempt = 0; attempt < maxTries; attempt++) {
      _log('--- Attempt ${attempt + 1} of $maxTries ---');
      try {
        List<List<int>> room =
            _generateTopology(dimX, dimY, numGenSteps, pChangeDirection);
        _log('Topology generated.');

        room = _placePlayerAndTargets(room, numBoxes);
        _log('Player and $numBoxes targets placed.');

        List<List<int>> roomStructure = _createRoomStructure(room);
        _log('Room structure created.');

        List<List<int>> roomState = _createInitialStateWithBoxesOnTargets(room);
        _log('Initial room state created (boxes on targets).');

        final result = _reversePlaying(roomState, roomStructure, numBoxes);

        // In generateLevel method, replace the success block:
        if (result.score > 0) {
          _log('✅ Success! Found valid level with score: ${result.score}');
          final cleanedState = _cleanupBoxesOnTargets(result.room);

          final level = GeneratedLevel(
            roomStructure: roomStructure,
            roomState: cleanedState,
            boxMapping: result.boxMapping,
            optimalMoves: result.score,
          );
          
          // Add this to print the level layout if verbose
          if (_verbose) {
            _log('\n${level.toLayoutString()}');
          }

          return level;
        } else {
          _log(
              '⚠️ Failed attempt. Reverse play score was ${result.score}. Retrying...');
        }
      } catch (e) {
        _log('⚠️ Error during attempt ${attempt + 1}: $e. Retrying...');
        continue;
      }
    }

    _log('❌ All $maxTries attempts failed. Returning fallback level.');
    return _createFallbackLevel(dimX, dimY, numBoxes);
  }

  List<List<int>> _generateTopology(
      int dimX, int dimY, int numSteps, double pChangeDirection) {
    List<List<int>> level = List.generate(dimX, (_) => List.filled(dimY, 0));

    int posX = 1 + _random.nextInt(dimX - 2);
    int posY = 1 + _random.nextInt(dimY - 2);
    int direction = _random.nextInt(4);

    for (int step = 0; step < numSteps; step++) {
      if (_random.nextDouble() < pChangeDirection) {
        direction = _random.nextInt(4);
      }

      final change = CHANGE_COORDINATES[direction]!;
      posX = (posX + change[0]).clamp(1, dimX - 2);
      posY = (posY + change[1]).clamp(1, dimY - 2);

      final mask = MASKS[_random.nextInt(MASKS.length)];
      _applyMask(level, mask, posX, posY);
    }

    for (int i = 0; i < dimX; i++) {
      for (int j = 0; j < dimY; j++) {
        if (level[i][j] > 0) level[i][j] = FLOOR;
      }
    }

    for (int i = 0; i < dimX; i++) {
      level[i][0] = WALL;
      level[i][dimY - 1] = WALL;
    }
    for (int j = 0; j < dimY; j++) {
      level[0][j] = WALL;
      level[dimX - 1][j] = WALL;
    }

    return level;
  }

  void _applyMask(List<List<int>> level, List<List<int>> mask, int x, int y) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        int targetX = x - 1 + i;
        int targetY = y - 1 + j;
        if (targetX >= 0 &&
            targetX < level.length &&
            targetY >= 0 &&
            targetY < level[0].length) {
          level[targetX][targetY] += mask[i][j];
        }
      }
    }
  }

  List<List<int>> _placePlayerAndTargets(List<List<int>> room, int numBoxes) {
    List<List<int>> result = room.map((row) => List<int>.from(row)).toList();

    List<List<int>> floorPositions = [];
    for (int i = 0; i < result.length; i++) {
      for (int j = 0; j < result[i].length; j++) {
        if (result[i][j] == FLOOR) {
          floorPositions.add([i, j]);
        }
      }
    }

    if (floorPositions.length < numBoxes + 1) {
      throw Exception(
          'Not enough floor space (${floorPositions.length}) to place $numBoxes boxes and 1 player.');
    }

    floorPositions.shuffle(_random);

    final playerPos = floorPositions.removeLast();
    result[playerPos[0]][playerPos[1]] = PLAYER;

    for (int i = 0; i < numBoxes; i++) {
      final targetPos = floorPositions.removeLast();
      result[targetPos[0]][targetPos[1]] = TARGET;
    }

    return result;
  }

  List<List<int>> _createRoomStructure(List<List<int>> room) {
    List<List<int>> structure = room.map((row) => List<int>.from(row)).toList();
    for (int i = 0; i < structure.length; i++) {
      for (int j = 0; j < structure[i].length; j++) {
        if (structure[i][j] == PLAYER) {
          structure[i][j] = FLOOR;
        }
      }
    }
    return structure;
  }

  List<List<int>> _createInitialStateWithBoxesOnTargets(
      List<List<int>> room) {
    List<List<int>> state = room.map((row) => List<int>.from(row)).toList();
    for (int i = 0; i < state.length; i++) {
      for (int j = 0; j < state[i].length; j++) {
        if (state[i][j] == TARGET) {
          state[i][j] = BOX;
        }
      }
    }
    return state;
  }

  List<List<int>> _cleanupBoxesOnTargets(List<List<int>> room) {
    List<List<int>> cleaned = room.map((row) => List<int>.from(row)).toList();
    for (int i = 0; i < cleaned.length; i++) {
      for (int j = 0; j < cleaned[i].length; j++) {
        if (cleaned[i][j] == BOX_ON_TARGET) {
          cleaned[i][j] = BOX;
        }
      }
    }
    return cleaned;
  }

  ReversePlayResult _reversePlaying(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    int numBoxes,
  ) {
    Map<String, List<int>> boxMapping = {};
    for (int i = 0; i < roomStructure.length; i++) {
      for (int j = 0; j < roomStructure[i].length; j++) {
        if (roomStructure[i][j] == TARGET) {
          String key = '$i,$j';
          boxMapping[key] = [i, j];
        }
      }
    }

    _exploredStates.clear();
    _bestRoom = null;
    _bestScore = -1;
    _bestBoxMapping = null;
    _log('Starting reverse play DFS...');

    _depthFirstSearch(
      roomState,
      roomStructure,
      boxMapping,
      numBoxes,
      0,
      null,
      300,
    );

    _log('DFS finished. Explored ${_exploredStates.length} states.');
    _log('Best score found: $_bestScore');

    return ReversePlayResult(
      room: _bestRoom ?? roomState,
      score: _bestScore,
      boxMapping: _bestBoxMapping ?? boxMapping,
    );
  }

  void _depthFirstSearch(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int numBoxes,
    int boxSwaps,
    String? lastPulledBoxKey,
    int ttl,
  ) {
    if (ttl <= 0 || _exploredStates.length > 300000) {
      return;
    }

    String stateHash = _hashState(roomState);
    if (_exploredStates.contains(stateHash)) {
      return;
    }
    _exploredStates.add(stateHash);

    int emptyTargets = 0;
    for (int i = 0; i < roomState.length; i++) {
      for (int j = 0; j < roomState[i].length; j++) {
        if (roomState[i][j] == TARGET) {
          emptyTargets++;
        }
      }
    }
    bool allBoxesOffTargets = (emptyTargets == numBoxes);

    int displacement = _boxDisplacementScore(boxMapping);
    int score = boxSwaps * displacement;

    if (!allBoxesOffTargets) {
      score = 0;
    }

    if (score > _bestScore) {
      if (_verbose && score > 0) {
        _log('... New best score: $score (swaps: $boxSwaps, disp: $displacement)');
      }
      _bestRoom = roomState.map((row) => List<int>.from(row)).toList();
      _bestScore = score;
      _bestBoxMapping = Map<String, List<int>>.from(boxMapping);
    }

    for (int action = 0; action < 8; action++) {
      final result = _reverseMove(roomState, roomStructure, boxMapping, action);

      if (result != null) {
        int newBoxSwaps = boxSwaps;
        String? newLastPulled = lastPulledBoxKey;

        if (result.pulled && result.pulledBoxKey != null) {
          if (result.pulledBoxKey != lastPulledBoxKey) {
            newBoxSwaps = boxSwaps + 1;
          }
          newLastPulled = result.pulledBoxKey;
        }

        _depthFirstSearch(
          result.room,
          roomStructure,
          result.boxMapping,
          numBoxes,
          newBoxSwaps,
          newLastPulled,
          ttl - 1,
        );
      }
    }
  }

  String _hashState(List<List<int>> room) {
    return room.map((row) => row.join()).join();
  }

  int _boxDisplacementScore(Map<String, List<int>> boxMapping) {
    int score = 0;
    for (var entry in boxMapping.entries) {
      final targetPos = entry.key.split(',').map(int.parse).toList();
      final boxPos = entry.value;
      score += (targetPos[0] - boxPos[0]).abs() +
          (targetPos[1] - boxPos[1]).abs();
    }
    return score;
  }

  ReverseMoveResult? _reverseMove(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int action,
  ) {
    List<List<int>> newRoom =
        roomState.map((row) => List<int>.from(row)).toList();
    Map<String, List<int>> newBoxMapping = Map.from(boxMapping);

    List<int>? playerPos;
    for (int i = 0; i < newRoom.length; i++) {
      for (int j = 0; j < newRoom[i].length; j++) {
        if (newRoom[i][j] == PLAYER) {
          playerPos = [i, j];
          break;
        }
      }
      if (playerPos != null) break;
    }
    if (playerPos == null) return null;

    final change = CHANGE_COORDINATES[action % 4]!;
    final nextPos = [playerPos[0] + change[0], playerPos[1] + change[1]];

    if (nextPos[0] < 0 ||
        nextPos[0] >= newRoom.length ||
        nextPos[1] < 0 ||
        nextPos[1] >= newRoom[0].length) {
      return null;
    }

    if (![FLOOR, TARGET].contains(newRoom[nextPos[0]][nextPos[1]])) {
      return null;
    }

    // --- We have a valid move, now check for pull ---
    bool pulled = false;
    String? pulledBoxKey;

    if (action < 4) {
      final behindPos = [playerPos[0] - change[0], playerPos[1] - change[1]];

      if (behindPos[0] >= 0 &&
          behindPos[0] < newRoom.length &&
          behindPos[1] >= 0 &&
          behindPos[1] < newRoom[0].length) {
        
        if ([BOX, BOX_ON_TARGET].contains(newRoom[behindPos[0]][behindPos[1]])) {
          
          // Determine the type of box (on target or floor) based on structure
          bool isTarget = roomStructure[playerPos[0]][playerPos[1]] == TARGET;
          
          // The box moves TO the player's old position
          newRoom[playerPos[0]][playerPos[1]] = isTarget ? BOX_ON_TARGET : BOX; 

          // The spot where the box came FROM reverts to its structure
          newRoom[behindPos[0]][behindPos[1]] = roomStructure[behindPos[0]][behindPos[1]];

          // Update mapping
          for (var entry in newBoxMapping.entries) {
            if (entry.value[0] == behindPos[0] && entry.value[1] == behindPos[1]) {
              newBoxMapping[entry.key] = [playerPos[0], playerPos[1]];
              pulledBoxKey = entry.key;
              break;
            }
          }

          // ---------------------------------------------------------
          // NEW: Check for 2x2 Deadlocks immediately
          // ---------------------------------------------------------
          // The box is now located at playerPos. Check if it formed a cluster.
          if (_formsDeadlock(newRoom, playerPos[0], playerPos[1])) {
            return null; // This pull creates an impossible knot. Reject it.
          }
          // ---------------------------------------------------------

          pulled = true;
        }
      }
    }

    if (!pulled) {
      newRoom[playerPos[0]][playerPos[1]] =
          roomStructure[playerPos[0]][playerPos[1]];
    }

    newRoom[nextPos[0]][nextPos[1]] = PLAYER;

    return ReverseMoveResult(
      room: newRoom,
      boxMapping: newBoxMapping,
      pulled: pulled,
      pulledBoxKey: pulledBoxKey,
    );
  }

  GeneratedLevel _createFallbackLevel(int dimX, int dimY, int numBoxes) {
    List<List<int>> structure =
        List.generate(dimX, (_) => List.filled(dimY, WALL));
    List<List<int>> state =
        List.generate(dimX, (_) => List.filled(dimY, WALL));

    int startRow = dimX ~/ 2;
    for (int j = 1; j < dimY - 1; j++) {
      structure[startRow][j] = FLOOR;
      state[startRow][j] = FLOOR;
    }

    state[startRow][2] = PLAYER;

    for (int i = 0; i < numBoxes && i < dimY - 5; i++) {
      structure[startRow][dimY - 3 - i] = TARGET;
      state[startRow][3 + i] = BOX;
    }

    return GeneratedLevel(
      roomStructure: structure,
      roomState: state,
      boxMapping: {},
      optimalMoves: numBoxes * (dimY - 6),
    );
  }
}

// --- Helper Data Classes ---

class GeneratedLevel {
  final List<List<int>> roomStructure;
  final List<List<int>> roomState;
  final Map<String, List<int>> boxMapping;
  final int optimalMoves;

  GeneratedLevel({
    required this.roomStructure,
    required this.roomState,
    required this.boxMapping,
    required this.optimalMoves,
  });

  String toLayoutString() {
    List<String> lines = [];
    for (int i = 0; i < roomState.length; i++) {
      String line = '';
      for (int j = 0; j < roomState[i].length; j++) {
        if (roomState[i][j] == LevelGenerator.WALL) {
          line += 'W';
        } else if (roomState[i][j] == LevelGenerator.PLAYER) {
          line += 'P';
        } else if (roomState[i][j] == LevelGenerator.BOX) {
          if (roomStructure[i][j] == LevelGenerator.TARGET) {
            line += 'X';
          } else {
            line += 'B';
          }
        } else if (roomStructure[i][j] == LevelGenerator.TARGET) {
          line += 'T';
        } else {
          line += ' ';
        }
      }
      lines.add(line);
    }
    return lines.join('\n');
  }
}

class ReversePlayResult {
  final List<List<int>> room;
  final int score;
  final Map<String, List<int>> boxMapping;

  ReversePlayResult({
    required this.room,
    required this.score,
    required this.boxMapping,
  });
}

class ReverseMoveResult {
  final List<List<int>> room;
  final Map<String, List<int>> boxMapping;
  final bool pulled;
  final String? pulledBoxKey;

  ReverseMoveResult({
    required this.room,
    required this.boxMapping,
    required this.pulled,
    this.pulledBoxKey,
  });
}

// ============================================================================
// CLI DEBUG VISUALIZER (only runs when main() is called)
// ============================================================================

class AnsiColors {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String dim = '\x1B[2m';
  
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String white = '\x1B[37m';
}

void printLevel(GeneratedLevel level, String title) {
  print('\n${AnsiColors.bold}${AnsiColors.cyan}═══ $title ═══${AnsiColors.reset}');
  
  for (int i = 0; i < level.roomState.length; i++) {
    String line = '';
    for (int j = 0; j < level.roomState[i].length; j++) {
      String char = ' ';
      String color = AnsiColors.reset;
      
      if (level.roomState[i][j] == LevelGenerator.WALL) {
        char = '█';
        color = AnsiColors.dim;
      } else if (level.roomState[i][j] == LevelGenerator.PLAYER) {
        char = '@';
        color = '${AnsiColors.bold}${AnsiColors.green}';
      } else if (level.roomState[i][j] == LevelGenerator.BOX) {
        if (level.roomStructure[i][j] == LevelGenerator.TARGET) {
          char = '✓';
          color = '${AnsiColors.bold}${AnsiColors.yellow}';
        } else {
          char = '■';
          color = '${AnsiColors.bold}${AnsiColors.red}';
        }
      } else if (level.roomStructure[i][j] == LevelGenerator.TARGET) {
        char = '·';
        color = AnsiColors.blue;
      } else {
        char = ' ';
      }
      
      line += '$color$char${AnsiColors.reset}';
    }
    print(line);
  }
  
  print('\n${AnsiColors.yellow}Legend:${AnsiColors.reset}');
  print('  ${AnsiColors.dim}█${AnsiColors.reset} Wall');
  print('  ${AnsiColors.bold}${AnsiColors.green}@${AnsiColors.reset} Player');
  print('  ${AnsiColors.bold}${AnsiColors.red}■${AnsiColors.reset} Box');
  print('  ${AnsiColors.blue}·${AnsiColors.reset} Target');
  print('  ${AnsiColors.bold}${AnsiColors.yellow}✓${AnsiColors.reset} Box on Target');
  print('\n${AnsiColors.cyan}Optimal Moves: ${AnsiColors.bold}${level.optimalMoves}${AnsiColors.reset}');
}

void main(List<String> args) {
  int dimX = 8;
  int dimY = 8;
  int numBoxes = 3;
  int? numGenSteps;
  double pChangeDirection = 0.35;
  int maxTries = 4;
  bool verbose = false;
  
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--width':
      case '-w':
        if (i + 1 < args.length) dimX = int.parse(args[++i]);
        break;
      case '--height':
      case '-h':
        if (i + 1 < args.length) dimY = int.parse(args[++i]);
        break;
      case '--boxes':
      case '-b':
        if (i + 1 < args.length) numBoxes = int.parse(args[++i]);
        break;
      case '--steps':
      case '-s':
        if (i + 1 < args.length) numGenSteps = int.parse(args[++i]);
        break;
      case '--change-prob':
      case '-p':
        if (i + 1 < args.length) pChangeDirection = double.parse(args[++i]);
        break;
      case '--tries':
      case '-t':
        if (i + 1 < args.length) maxTries = int.parse(args[++i]);
        break;
      case '--verbose':
      case '-v':
        verbose = true;
        break;
      case '--help':
        print('''
Starloader Sokoban Level Generator - Debug CLI

Usage: dart starloader_level_generator.dart [options]

Options:
  -w, --width <n>         Grid width (default: 8)
  -h, --height <n>        Grid height (default: 8)
  -b, --boxes <n>         Number of boxes (default: 3)
  -s, --steps <n>         Topology generation steps (default: auto)
  -p, --change-prob <f>   Direction change probability (default: 0.35)
  -t, --tries <n>         Max generation attempts (default: 4)
  -v, --verbose           Enable verbose logging
  --help                  Show this help

Example:
  dart lib/features/games/services/starloader_level_generator.dart -w 10 -h 10 -b 4 -v
        ''');
        return;
    }
  }
  
  print('${AnsiColors.bold}${AnsiColors.magenta}');
  print('╔════════════════════════════════════════╗');
  print('║  STARLOADER LEVEL GENERATOR DEBUGGER  ║');
  print('╚════════════════════════════════════════╝');
  print(AnsiColors.reset);
  
  print('\n${AnsiColors.cyan}Parameters:${AnsiColors.reset}');
  print('  Grid Size: ${dimX}x$dimY');
  print('  Boxes: $numBoxes');
  print('  Generation Steps: ${numGenSteps ?? "(auto)"}');
  print('  Change Direction Prob: $pChangeDirection');
  print('  Max Attempts: $maxTries');
  print('  Verbose: $verbose');
  
  final generator = LevelGenerator(verbose: verbose);
  
  print('\n${AnsiColors.yellow}Generating level...${AnsiColors.reset}');
  
  final level = generator.generateLevel(
    dimX: dimX,
    dimY: dimY,
    numBoxes: numBoxes,
    numGenSteps: numGenSteps,
    pChangeDirection: pChangeDirection,
    maxTries: maxTries,
  );
  
  printLevel(level, 'GENERATED LEVEL');
  
  print('\n${AnsiColors.green}${AnsiColors.bold}✓ Generation complete!${AnsiColors.reset}');
  print('\n${AnsiColors.dim}Tip: Try different parameters to see how the algorithm behaves!${AnsiColors.reset}');
}