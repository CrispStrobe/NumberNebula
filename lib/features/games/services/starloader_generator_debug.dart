// generator_debug.dart

import 'dart:io';
import 'dart:math' as math;

// ==========================================
// 1. CLI Entry Point & Visualization Logic
// ==========================================

void main(List<String> args) {
  // Default parameters
  int width = 8;
  int height = 8;
  int boxes = 3;
  int attempts = 1;

  // Simple arg parsing
  for (var arg in args) {
    if (arg.startsWith('--w=')) width = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--h=')) height = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--b=')) boxes = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--n=')) attempts = int.parse(arg.split('=')[1]);
  }

  stdout.writeln('🔧 Generating $attempts Level(s) [${width}x$height, Boxes: $boxes]...\n');

  final generator = LevelGenerator(verbose: true);

  for (int i = 0; i < attempts; i++) {
    final level = generator.generateLevel(
      dimX: width,
      dimY: height,
      numBoxes: boxes,
      maxTries: 10, 
    );

    print('\n════════════════════════════════════');
    print('      LEVEL ${i + 1} GENERATED');
    print('════════════════════════════════════');
    print('Score (Complexity): ${level.optimalMoves}');
    print('Map Layout:');
    print(LevelVisualizer.render(level));
    print('════════════════════════════════════\n');
  }
}

/// Helper to render the level with ANSI colors for debugging
class LevelVisualizer {
  static const String ANSI_RESET = '\x1B[0m';
  static const String ANSI_WALL = '\x1B[48;5;235m\x1B[38;5;240m'; // Dark Grey
  static const String ANSI_FLOOR = '\x1B[48;5;250m'; // Light Grey
  static const String ANSI_TARGET = '\x1B[48;5;250m\x1B[31m'; // Red on Grey
  static const String ANSI_BOX = '\x1B[48;5;136m\x1B[38;5;0m'; // Brown
  static const String ANSI_BOX_OK = '\x1B[48;5;34m\x1B[38;5;0m'; // Green (Box on target)
  static const String ANSI_PLAYER = '\x1B[48;5;33m\x1B[38;5;255m'; // Blue

  static String render(GeneratedLevel level) {
    StringBuffer buffer = StringBuffer();
    
    // Top border
    buffer.writeln('   ' +List.generate(level.roomState[0].length, (index) => '$index').join(''));
    
    for (int x = 0; x < level.roomState.length; x++) {
      buffer.write('${x.toString().padRight(2)} '); // Row number
      for (int y = 0; y < level.roomState[x].length; y++) {
        int stateTile = level.roomState[x][y];
        int structTile = level.roomStructure[x][y];
        
        String char = ' ';
        String color = ANSI_RESET;

        if (stateTile == LevelGenerator.WALL) {
          char = '#';
          color = ANSI_WALL;
        } else if (stateTile == LevelGenerator.PLAYER) {
          char = '@'; // Player
          color = ANSI_PLAYER;
        } else if (stateTile == LevelGenerator.BOX) {
          char = '\$';
          // Check if it's on a target (even if state says BOX, structure checks truth)
          if (structTile == LevelGenerator.TARGET) {
             color = ANSI_BOX_OK;
          } else {
             color = ANSI_BOX;
          }
        } else if (stateTile == LevelGenerator.BOX_ON_TARGET) {
          char = '*';
          color = ANSI_BOX_OK;
        } else {
          // Empty Floor or Target
          if (structTile == LevelGenerator.TARGET) {
            char = '.';
            color = ANSI_TARGET;
          } else {
            char = ' ';
            color = ANSI_FLOOR;
          }
        }
        buffer.write('$color$char$ANSI_RESET');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

// ==========================================
// 2. Fixed Level Generator Class
// ==========================================

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

  // --- Reverse Play State ---
  Set<String> _exploredStates = {};
  List<List<int>>? _bestRoom;
  int _bestScore = -1;
  Map<String, List<int>>? _bestBoxMapping;

  static const Map<int, List<int>> CHANGE_COORDINATES = {
    0: [-1, 0], 1: [1, 0], 2: [0, -1], 3: [0, 1],
  };

  static const List<List<List<int>>> MASKS = [
    [[0, 0, 0], [1, 1, 1], [0, 0, 0]],
    [[0, 1, 0], [0, 1, 0], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 0], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 0], [1, 1, 0]],
    [[0, 0, 0], [0, 1, 1], [0, 1, 0]]
  ];

  LevelGenerator({bool verbose = false}) : _verbose = verbose;

  void _log(String message) {
    if (_verbose) print('\x1B[90m[Gen] $message\x1B[0m');
  }

  GeneratedLevel generateLevel({
    required int dimX,
    required int dimY,
    required int numBoxes,
    int? numGenSteps,
    double pChangeDirection = 0.35,
    int maxTries = 4,
  }) {
    _log('Starting ($dimX x $dimY, $numBoxes boxes)...');
    numGenSteps ??= (1.7 * (dimX + dimY)).round();

    for (int attempt = 0; attempt < maxTries; attempt++) {
      try {
        List<List<int>> room = _generateTopology(dimX, dimY, numGenSteps, pChangeDirection);
        room = _placePlayerAndTargets(room, numBoxes);
        List<List<int>> roomStructure = _createRoomStructure(room);
        List<List<int>> roomState = _createInitialStateWithBoxesOnTargets(room);

        // Run Reverse Play
        final result = _reversePlaying(roomState, roomStructure, numBoxes);

        if (result.score > 0) {
          _log('✅ Valid level found! Score: ${result.score}');
          final cleanedState = _cleanupBoxesOnTargets(result.room);
          return GeneratedLevel(
            roomStructure: roomStructure,
            roomState: cleanedState,
            boxMapping: result.boxMapping,
            optimalMoves: result.score,
          );
        } else {
          _log('⚠️ Low score (${result.score}). Retrying...');
        }
      } catch (e) {
        _log('⚠️ Error: $e. Retrying...');
        continue;
      }
    }
    _log('❌ Failed. Returning fallback.');
    return _createFallbackLevel(dimX, dimY, numBoxes);
  }

  List<List<int>> _generateTopology(int dimX, int dimY, int numSteps, double pChangeDirection) {
    List<List<int>> level = List.generate(dimX, (_) => List.filled(dimY, 0));
    int posX = 1 + _random.nextInt(dimX - 2);
    int posY = 1 + _random.nextInt(dimY - 2);
    int direction = _random.nextInt(4);

    for (int step = 0; step < numSteps; step++) {
      if (_random.nextDouble() < pChangeDirection) direction = _random.nextInt(4);
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
    // Enforce walls
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
        if (targetX >= 0 && targetX < level.length && targetY >= 0 && targetY < level[0].length) {
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
        if (result[i][j] == FLOOR) floorPositions.add([i, j]);
      }
    }

    if (floorPositions.length < numBoxes + 1) throw Exception('Not enough space');
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
    return room.map((row) => row.map((cell) => cell == PLAYER ? FLOOR : cell).toList()).toList();
  }

  List<List<int>> _createInitialStateWithBoxesOnTargets(List<List<int>> room) {
    return room.map((row) => row.map((cell) => cell == TARGET ? BOX : cell).toList()).toList();
  }

  List<List<int>> _cleanupBoxesOnTargets(List<List<int>> room) {
    return room.map((row) => row.map((cell) => cell == BOX_ON_TARGET ? BOX : cell).toList()).toList();
  }

  // --- Reverse Play Logic ---

  ReversePlayResult _reversePlaying(List<List<int>> roomState, List<List<int>> roomStructure, int numBoxes) {
    Map<String, List<int>> boxMapping = {};
    for (int i = 0; i < roomStructure.length; i++) {
      for (int j = 0; j < roomStructure[i].length; j++) {
        if (roomStructure[i][j] == TARGET) boxMapping['$i,$j'] = [i, j];
      }
    }

    _exploredStates.clear();
    _bestRoom = null;
    _bestScore = -1; 
    _bestBoxMapping = null;

    _depthFirstSearch(
      roomState,
      roomStructure,
      boxMapping,
      numBoxes,
      0, // boxSwaps
      null, // lastPulledBoxKey
      300, // ttl
    );

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
    if (ttl <= 0 || _exploredStates.length > 300000) return;

    String stateHash = _hashState(roomState);
    if (_exploredStates.contains(stateHash)) return;
    _exploredStates.add(stateHash);

    // Calculate score
    int emptyTargets = 0;
    for (int i = 0; i < roomState.length; i++) {
      for (int j = 0; j < roomState[i].length; j++) {
        if (roomState[i][j] == TARGET) emptyTargets++;
      }
    }
    
    // Only count score if all boxes are moved off targets
    // (Or at least, we prioritize states where they are)
    int displacement = _boxDisplacementScore(boxMapping);
    int score = boxSwaps * displacement;
    
    // Strictness: We usually only want to consider it a "solution" if all boxes are off targets.
    // However, for generation, we keep the best partial solution we find.
    if (emptyTargets != numBoxes) score = 0;

    if (score > _bestScore) {
      if (_verbose && score > 0) _log('New Best Score: $score (Swaps: $boxSwaps, Disp: $displacement)');
      _bestRoom = roomState.map((row) => List<int>.from(row)).toList();
      _bestScore = score;
      _bestBoxMapping = Map<String, List<int>>.from(boxMapping);
    }

    for (int action = 0; action < 8; action++) {
      final result = _reverseMove(roomState, roomStructure, boxMapping, action);

      if (result != null) {
        int newBoxSwaps = boxSwaps;
        
        // --- FIX 1: Correct Swap Logic ---
        if (result.pulled && result.pulledBoxKey != null) {
          if (result.pulledBoxKey != lastPulledBoxKey) {
            newBoxSwaps = boxSwaps + 1;
          }
        }

        // --- FIX 2: Recursive Parameter ---
        // We must pass the NEW box key if we pulled one, otherwise keep the old one.
        // This ensures the next step knows what we just pulled.
        String? nextLastPulledKey = result.pulled ? result.pulledBoxKey : lastPulledBoxKey;

        _depthFirstSearch(
          result.room,
          roomStructure,
          result.boxMapping,
          numBoxes,
          newBoxSwaps,
          nextLastPulledKey, // Pass the UPDATED key
          ttl - 1,
        );
      }
    }
  }

  String _hashState(List<List<int>> room) => room.map((row) => row.join()).join();

  int _boxDisplacementScore(Map<String, List<int>> boxMapping) {
    int score = 0;
    for (var entry in boxMapping.entries) {
      final targetPos = entry.key.split(',').map(int.parse).toList();
      final boxPos = entry.value;
      score += (targetPos[0] - boxPos[0]).abs() + (targetPos[1] - boxPos[1]).abs();
    }
    return score;
  }

  ReverseMoveResult? _reverseMove(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int action,
  ) {
    List<List<int>> newRoom = roomState.map((row) => List<int>.from(row)).toList();
    Map<String, List<int>> newBoxMapping = Map.from(boxMapping);

    // Find player
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

    // Bounds and Floor check
    if (nextPos[0] < 0 || nextPos[0] >= newRoom.length || nextPos[1] < 0 || nextPos[1] >= newRoom[0].length) return null;
    if (![FLOOR, TARGET].contains(newRoom[nextPos[0]][nextPos[1]])) return null;

    bool pulled = false;
    String? pulledBoxKey;

    // Pull Logic
    if (action < 4) {
      final behindPos = [playerPos[0] - change[0], playerPos[1] - change[1]];
      if (behindPos[0] >= 0 && behindPos[0] < newRoom.length && behindPos[1] >= 0 && behindPos[1] < newRoom[0].length) {
        
        // Check for ANY box type (4=BOX, 3=BOX_ON_TARGET)
        if ([BOX, BOX_ON_TARGET].contains(newRoom[behindPos[0]][behindPos[1]])) {
          
          // --- FIX 3: Maintain correct state type ---
          // When pulling a box onto 'playerPos', check what 'playerPos' really is structurally.
          // If it's a TARGET, the box becomes BOX_ON_TARGET (3).
          // If it's a FLOOR, the box becomes BOX (4).
          // This prevents state corruption.
          bool isTarget = roomStructure[playerPos[0]][playerPos[1]] == TARGET;
          newRoom[playerPos[0]][playerPos[1]] = isTarget ? BOX_ON_TARGET : BOX; 

          // Restore the tile where the box was
          newRoom[behindPos[0]][behindPos[1]] = roomStructure[behindPos[0]][behindPos[1]];

          for (var entry in newBoxMapping.entries) {
            if (entry.value[0] == behindPos[0] && entry.value[1] == behindPos[1]) {
              newBoxMapping[entry.key] = [playerPos[0], playerPos[1]];
              pulledBoxKey = entry.key;
              break;
            }
          }
          pulled = true;
        }
      }
    }

    if (!pulled) {
      // Just moving, restore tile under player
      newRoom[playerPos[0]][playerPos[1]] = roomStructure[playerPos[0]][playerPos[1]];
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
    // Basic fallback implementation
     List<List<int>> structure = List.generate(dimX, (_) => List.filled(dimY, WALL));
    List<List<int>> state = List.generate(dimX, (_) => List.filled(dimY, WALL));
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