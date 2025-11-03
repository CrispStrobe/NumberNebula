// lib/features/games/services/starloader_level_generator.dart
import 'dart:math' as math;

class LevelGenerator {
  static const int WALL = 0;
  static const int FLOOR = 1;
  static const int TARGET = 2;
  static const int BOX_ON_TARGET = 3;
  static const int BOX = 4;
  static const int PLAYER = 5;

  final math.Random _random = math.Random();
  
  static const Map<int, List<int>> CHANGE_COORDINATES = {
    0: [-1, 0],  // Up
    1: [1, 0],   // Down
    2: [0, -1],  // Left
    3: [0, 1],   // Right
  };

  static const List<List<List<int>>> MASKS = [
    [[0, 0, 0], [1, 1, 1], [0, 0, 0]],
    [[0, 1, 0], [0, 1, 0], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 0], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 0], [1, 1, 0]],
    [[0, 0, 0], [0, 1, 1], [0, 1, 0]],
  ];

  GeneratedLevel generateLevel({
    required int dimX,
    required int dimY,
    required int numBoxes,
    int? numGenSteps,
    double pChangeDirection = 0.35,
    int maxTries = 4,
  }) {
    numGenSteps ??= (1.7 * (dimX + dimY)).round();

    for (int attempt = 0; attempt < maxTries; attempt++) {
      try {
        List<List<int>> room = _generateTopology(dimX, dimY, numGenSteps, pChangeDirection);
        room = _placePlayerAndTargets(room, numBoxes);
        List<List<int>> roomStructure = _createRoomStructure(room);
        List<List<int>> roomState = _createInitialStateWithBoxesOnTargets(room);

        final result = _reversePlaying(roomState, roomStructure, numBoxes);

        if (result.score > 0) {  // Use score, not moves
          final cleanedState = _cleanupBoxesOnTargets(result.room);
          
          return GeneratedLevel(
            roomStructure: roomStructure,
            roomState: cleanedState,
            boxMapping: result.boxMapping,
            optimalMoves: result.score,  // Use score as move estimate
          );
        }
      } catch (e) {
        continue;
      }
    }

    return _createFallbackLevel(dimX, dimY, numBoxes);
  }

  List<List<int>> _generateTopology(int dimX, int dimY, int numSteps, double pChangeDirection) {
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
        if (targetX >= 0 && targetX < level.length &&
            targetY >= 0 && targetY < level[0].length) {
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
      throw Exception('Not enough floor space');
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

  List<List<int>> _createInitialStateWithBoxesOnTargets(List<List<int>> room) {
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
    _bestScore = 0;
    _bestBoxMapping = null;

    _depthFirstSearch(
      roomState,
      roomStructure,
      boxMapping,
      numBoxes,
      0,           // boxSwaps
      null,        // lastPulledBox
      300,         // ttl
    );

    return ReversePlayResult(
      room: _bestRoom ?? roomState,
      score: _bestScore,
      boxMapping: _bestBoxMapping ?? boxMapping,
    );
  }

  Set<String> _exploredStates = {};
  List<List<int>>? _bestRoom;
  int _bestScore = -1; 
  Map<String, List<int>>? _bestBoxMapping;

  void _depthFirstSearch(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int numBoxes,
    int boxSwaps,
    String? lastPulledBox,
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

    // Check if all boxes are off their targets - count empty targets in room state
    int emptyTargets = 0;
    for (int i = 0; i < roomState.length; i++) {
      for (int j = 0; j < roomState[i].length; j++) {
        if (roomState[i][j] == TARGET) {
          emptyTargets++;
        }
      }
    }

    bool allBoxesOffTargets = (emptyTargets == numBoxes);

    // Calculate score using Python's formula: box_swaps * displacement
    int displacement = _boxDisplacementScore(boxMapping);
    int score = boxSwaps * displacement;

    // Update best if this is better
    if (allBoxesOffTargets && score > _bestScore) {
      _bestRoom = roomState.map((row) => List<int>.from(row)).toList();
      _bestScore = score;
      _bestBoxMapping = Map<String, List<int>>.from(boxMapping);
    }

    // Try all actions (pull and move actions)
    for (int action = 0; action < 8; action++) {
      final result = _reverseMove(roomState, roomStructure, boxMapping, action);
      
      if (result != null) {
        // Calculate new box swaps - increment if we pulled a different box
        int newBoxSwaps = boxSwaps;
        String? newLastPulledBox = lastPulledBox;
        
        if (result.pulled && result.pulledBoxKey != null) {
          if (result.pulledBoxKey != lastPulledBox) {
            newBoxSwaps = boxSwaps + 1;
          }
          newLastPulledBox = lastPulledBox; // Keep old value per Python logic
        }
        
        _depthFirstSearch(
          result.room,
          roomStructure,
          result.boxMapping,
          numBoxes,
          newBoxSwaps,
          newLastPulledBox,
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

    if (nextPos[0] < 0 || nextPos[0] >= newRoom.length ||
        nextPos[1] < 0 || nextPos[1] >= newRoom[0].length) {
      return null;
    }

    // Check if next position is a wall or box
    if (newRoom[nextPos[0]][nextPos[1]] == WALL ||
        newRoom[nextPos[0]][nextPos[1]] == BOX ||
        newRoom[nextPos[0]][nextPos[1]] == BOX_ON_TARGET) {
      return null;
    }

    bool pulled = false;
    String? pulledBoxKey;

    // If this is a pull action (0-3), try to pull a box
    if (action < 4) {
      final behindPos = [playerPos[0] - change[0], playerPos[1] - change[1]];

      if (behindPos[0] >= 0 && behindPos[0] < newRoom.length &&
          behindPos[1] >= 0 && behindPos[1] < newRoom[0].length) {
        
        // Check for both BOX and BOX_ON_TARGET
        if ([BOX, BOX_ON_TARGET].contains(newRoom[behindPos[0]][behindPos[1]])) {
          // Box lands where player was - set to BOX_ON_TARGET (3) per Python
          newRoom[playerPos[0]][playerPos[1]] = BOX_ON_TARGET;
          
          // Where box was becomes the structure tile
          newRoom[behindPos[0]][behindPos[1]] = roomStructure[behindPos[0]][behindPos[1]];
          
          // Update box mapping and track which box was pulled
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

    // If no box was pulled, restore the structure tile where player was
    if (!pulled) {
      newRoom[playerPos[0]][playerPos[1]] = roomStructure[playerPos[0]][playerPos[1]];
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

  GeneratedLevel _createFallbackLevel(int dimX, int dimY, int numBoxes) {
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