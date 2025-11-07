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

  /// Creates a level generator.
  /// Set [verbose] to true to get CLI logs during generation.
  LevelGenerator({bool verbose = false}) : _verbose = verbose;

  void _log(String message) {
    if (_verbose) {
      print('[LevelGenerator] $message');
    }
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
        // 1. Generate the floor plan
        List<List<int>> room =
            _generateTopology(dimX, dimY, numGenSteps, pChangeDirection);
        _log('Topology generated.');

        // 2. Place player and targets
        room = _placePlayerAndTargets(room, numBoxes);
        _log('Player and $numBoxes targets placed.');

        // 3. Create the static room structure (walls, floors, targets)
        List<List<int>> roomStructure = _createRoomStructure(room);
        _log('Room structure created.');

        // 4. Create the initial state (player, and boxes ON targets)
        //    Python: room_state[room_state == 2] = 4
        List<List<int>> roomState = _createInitialStateWithBoxesOnTargets(room);
        _log('Initial room state created (boxes on targets).');

        // 5. Play the game in reverse to shuffle the boxes
        final result = _reversePlaying(roomState, roomStructure, numBoxes);

        // 6. Check if the reverse-play found a valid, shuffled state
        //    Python: if score > 0:
        if (result.score > 0) {
          _log('✅ Success! Found valid level with score: ${result.score}');
          // 7. Clean up the final state
          //    Python: room_state[room_state == 3] = 4
          final cleanedState = _cleanupBoxesOnTargets(result.room);

          return GeneratedLevel(
            roomStructure: roomStructure,
            roomState: cleanedState,
            boxMapping: result.boxMapping,
            optimalMoves: result.score,
          );
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

  /// Generates the room's topology (walls and floors) using a random walk.
  List<List<int>> _generateTopology(
      int dimX, int dimY, int numSteps, double pChangeDirection) {
    List<List<int>> level = List.generate(dimX, (_) => List.filled(dimY, 0));

    // Start walk from a random non-edge position
    int posX = 1 + _random.nextInt(dimX - 2);
    int posY = 1 + _random.nextInt(dimY - 2);
    int direction = _random.nextInt(4); // 0-3

    for (int step = 0; step < numSteps; step++) {
      // 1. Randomly change direction
      if (_random.nextDouble() < pChangeDirection) {
        direction = _random.nextInt(4);
      }

      // 2. Move position, clamping to stay away from edges
      final change = CHANGE_COORDINATES[direction]!;
      posX = (posX + change[0]).clamp(1, dimX - 2);
      posY = (posY + change[1]).clamp(1, dimY - 2);

      // 3. Apply a random mask to "paint" the floor
      final mask = MASKS[_random.nextInt(MASKS.length)];
      _applyMask(level, mask, posX, posY);
    }

    // 4. Convert all painted areas to FLOOR
    for (int i = 0; i < dimX; i++) {
      for (int j = 0; j < dimY; j++) {
        if (level[i][j] > 0) level[i][j] = FLOOR;
      }
    }

    // 5. Enforce outer walls
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

  /// Applies a 3x3 mask to the level at the given (x, y) center.
  void _applyMask(List<List<int>> level, List<List<int>> mask, int x, int y) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        int targetX = x - 1 + i;
        int targetY = y - 1 + j;
        // Check bounds
        if (targetX >= 0 &&
            targetX < level.length &&
            targetY >= 0 &&
            targetY < level[0].length) {
          level[targetX][targetY] += mask[i][j];
        }
      }
    }
  }

  /// Randomly places 1 player and N targets onto FLOOR tiles.
  List<List<int>> _placePlayerAndTargets(List<List<int>> room, int numBoxes) {
    List<List<int>> result = room.map((row) => List<int>.from(row)).toList();

    // 1. Find all available floor positions
    List<List<int>> floorPositions = [];
    for (int i = 0; i < result.length; i++) {
      for (int j = 0; j < result[i].length; j++) {
        if (result[i][j] == FLOOR) {
          floorPositions.add([i, j]);
        }
      }
    }

    // 2. Check if there is enough space
    if (floorPositions.length < numBoxes + 1) {
      _log('Not enough floor space: ${floorPositions.length} spots for ${numBoxes + 1} items.');
      throw Exception(
          'Not enough floor space (${floorPositions.length}) to place $numBoxes boxes and 1 player.');
    }

    // 3. Shuffle and pick positions
    floorPositions.shuffle(_random);

    final playerPos = floorPositions.removeLast();
    result[playerPos[0]][playerPos[1]] = PLAYER;

    for (int i = 0; i < numBoxes; i++) {
      final targetPos = floorPositions.removeLast();
      result[targetPos[0]][targetPos[1]] = TARGET;
    }

    return result;
  }

  /// Creates the static structure (PLAYER -> FLOOR).
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

  /// Creates the initial game state (TARGET -> BOX).
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

  /// Cleans the final room state (BOX_ON_TARGET -> BOX).
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

  /// --- Reverse Play DFS ---

  /// Sets up and runs the reverse play DFS.
  ReversePlayResult _reversePlaying(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    int numBoxes,
  ) {
    // 1. Create the initial box mapping (target_pos -> box_pos)
    Map<String, List<int>> boxMapping = {};
    for (int i = 0; i < roomStructure.length; i++) {
      for (int j = 0; j < roomStructure[i].length; j++) {
        if (roomStructure[i][j] == TARGET) {
          String key = '$i,$j';
          boxMapping[key] = [i, j]; // Initially, box is on its target
        }
      }
    }

    // 2. Reset global state for this generation
    _exploredStates.clear();
    _bestRoom = null;
    _bestScore = -1; // <-- FIX 1: Must be -1 to accept 0-score states
    _bestBoxMapping = null;
    _log('Starting reverse play DFS...');

    // 3. Start the recursive search
    _depthFirstSearch(
      roomState,
      roomStructure,
      boxMapping,
      numBoxes,
      0, // boxSwaps
      null, // lastPulledBoxKey
      300, // ttl
    );

    _log('DFS finished. Explored ${_exploredStates.length} states.');
    _log('Best score found: $_bestScore');

    // 4. Return the best result found
    return ReversePlayResult(
      room: _bestRoom ?? roomState,
      score: _bestScore,
      boxMapping: _bestBoxMapping ?? boxMapping,
    );
  }

  /// Recursive DFS to explore reverse moves.
  void _depthFirstSearch(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int numBoxes,
    int boxSwaps,
    String? lastPulledBoxKey,  // This should stay constant in recursion!
    int ttl,
  ) {
    // 1. Check stop conditions
    if (ttl <= 0 || _exploredStates.length > 300000) {
      return;
    }

    // 2. Check if state has been explored
    String stateHash = _hashState(roomState);
    if (_exploredStates.contains(stateHash)) {
      return;
    }
    _exploredStates.add(stateHash);

    // 3. Calculate score
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

    // 4. Update best if this state is better
    if (score > _bestScore) {
      if (_verbose && score > 0) {
        _log('... New best score: $score (swaps: $boxSwaps, disp: $displacement)');
      }
      _bestRoom = roomState.map((row) => List<int>.from(row)).toList();
      _bestScore = score;
      _bestBoxMapping = Map<String, List<int>>.from(boxMapping);
    }

    // 5. Recursively try all 8 actions (4 pull, 4 move)
    for (int action = 0; action < 8; action++) {
      final result = _reverseMove(roomState, roomStructure, boxMapping, action);

      if (result != null) {
        // Calculate new box swaps count
        int newBoxSwaps = boxSwaps;
        
        // In Python: if last_pull_next != last_pull, increment
        // Since we always pass the same lastPulledBoxKey (null), 
        // ANY pull will increment the counter
        if (result.pulled && result.pulledBoxKey != null) {
          if (result.pulledBoxKey != lastPulledBoxKey) {
            newBoxSwaps = boxSwaps + 1;
          }
        }

        // ✅ FIX: Pass the ORIGINAL lastPulledBoxKey, not the new one!
        _depthFirstSearch(
          result.room,
          roomStructure,
          result.boxMapping,
          numBoxes,
          newBoxSwaps,
          lastPulledBoxKey,  // ✅ Use original value, matching Python!
          ttl - 1,
        );
      }
    }
  }

  /// Hashes a room state for the `_exploredStates` set.
  String _hashState(List<List<int>> room) {
    // A simple, fast-enough hash
    return room.map((row) => row.join()).join();
  }

  /// Calculates the total Manhattan distance of boxes from their targets.
  int _boxDisplacementScore(Map<String, List<int>> boxMapping) {
    int score = 0;
    for (var entry in boxMapping.entries) {
      // Parse 'i,j' string key back into [i, j]
      final targetPos = entry.key.split(',').map(int.parse).toList();
      final boxPos = entry.value;
      // Manhattan distance
      score += (targetPos[0] - boxPos[0]).abs() +
          (targetPos[1] - boxPos[1]).abs();
    }
    return score;
  }

  /// Simulates one reverse move (move or pull).
  ReverseMoveResult? _reverseMove(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int action,
  ) {
    // 1. Create copies to modify
    List<List<int>> newRoom =
        roomState.map((row) => List<int>.from(row)).toList();
    Map<String, List<int>> newBoxMapping = Map.from(boxMapping);

    // 2. Find player
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
    if (playerPos == null) return null; // Should not happen

    // 3. Get new player position
    final change = CHANGE_COORDINATES[action % 4]!;
    final nextPos = [playerPos[0] + change[0], playerPos[1] + change[1]];

    // 4. Check bounds
    if (nextPos[0] < 0 ||
        nextPos[0] >= newRoom.length ||
        nextPos[1] < 0 ||
        nextPos[1] >= newRoom[0].length) {
      return null;
    }

    // 5. Check if next position is valid (FLOOR or TARGET)
    if (![FLOOR, TARGET].contains(newRoom[nextPos[0]][nextPos[1]])) {
      return null;
    }

    // --- We have a valid move, now check for pull ---
    bool pulled = false;
    String? pulledBoxKey;

    // Actions 0-3 are "pull" actions
    if (action < 4) {
      // The position *behind* the player
      final behindPos = [playerPos[0] - change[0], playerPos[1] - change[1]];

      if (behindPos[0] >= 0 &&
          behindPos[0] < newRoom.length &&
          behindPos[1] >= 0 &&
          behindPos[1] < newRoom[0].length) {
        
        // Is there a box behind the player?
        if ([BOX, BOX_ON_TARGET]
            .contains(newRoom[behindPos[0]][behindPos[1]])) {
          
          // --- Yes: Perform Pull ---
          // Box lands where player was. Python uses 3 (BOX_ON_TARGET)
          newRoom[playerPos[0]][playerPos[1]] = BOX_ON_TARGET;

          // Where box was becomes the original structure tile
          newRoom[behindPos[0]][behindPos[1]] =
              roomStructure[behindPos[0]][behindPos[1]];

          // Update box mapping
          for (var entry in newBoxMapping.entries) {
            if (entry.value[0] == behindPos[0] &&
                entry.value[1] == behindPos[1]) {
              newBoxMapping[entry.key] = [playerPos[0], playerPos[1]];
              pulledBoxKey = entry.key;
              break;
            }
          }
          pulled = true;
        }
      }
    }

    // If no box was pulled, restore the structure tile where player was
    if (!pulled) {
      newRoom[playerPos[0]][playerPos[1]] =
          roomStructure[playerPos[0]][playerPos[1]];
    }

    // Move player to next position
    newRoom[nextPos[0]][nextPos[1]] = PLAYER;

    return ReverseMoveResult(
      room: newRoom,
      boxMapping: newBoxMapping,
      pulled: pulled,
      pulledBoxKey: pulledBoxKey,
    );
  }

  /// Fallback for when generation fails.
  GeneratedLevel _createFallbackLevel(int dimX, int dimY, int numBoxes) {
    List<List<int>> structure =
        List.generate(dimX, (_) => List.filled(dimY, WALL));
    List<List<int>> state =
        List.generate(dimX, (_) => List.filled(dimY, WALL));

    // Create a simple horizontal hallway
    int startRow = dimX ~/ 2;
    for (int j = 1; j < dimY - 1; j++) {
      structure[startRow][j] = FLOOR;
      state[startRow][j] = FLOOR;
    }

    // Player
    state[startRow][2] = PLAYER;

    // Boxes and Targets
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

  /// Utility to print the level to the console.
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
            line += 'X'; // Box on target
          } else {
            line += 'B'; // Box on floor
          }
        } else if (roomStructure[i][j] == LevelGenerator.TARGET) {
          line += 'T'; // Empty target
        } else {
          line += ' '; // Floor
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