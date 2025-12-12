// lib/features/games/services/starloader_puzzle_debug.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:collection';

void main(List<String> args) {
  int dimX = 8;
  int dimY = 8;
  int numBoxes = 2;
  
  if (args.isNotEmpty && args[0] == '--help') {
    print('Usage: dart starloader_puzzle_debug.dart [dimX] [dimY] [numBoxes]');
    print('Example: dart starloader_puzzle_debug.dart 10 10 3');
    return;
  }
  
  if (args.length >= 1) dimX = int.tryParse(args[0]) ?? dimX;
  if (args.length >= 2) dimY = int.tryParse(args[1]) ?? dimY;
  if (args.length >= 3) numBoxes = int.tryParse(args[2]) ?? numBoxes;
  
  print('\n${"═" * 80}');
  print('║${_center("SOKOBAN PUZZLE GENERATOR - PRODUCTION QUALITY", 78)}║');
  print('${"═" * 80}\n');
  
  print('📋 Configuration:');
  print('   • Grid Size: ${dimX}x$dimY');
  print('   • Number of Boxes: $numBoxes\n');
  
  final generator = LevelGenerator(verbose: true);
  
  try {
    final level = generator.generateLevel(
      dimX: dimX,
      dimY: dimY,
      numBoxes: numBoxes,
    );
    
    print('\n${"═" * 80}');
    print('║${_center("GENERATION COMPLETE ✓", 78)}║');
    print('${"═" * 80}\n');
    
    print('📊 Final Statistics:');
    print('   • Optimal Moves: ${level.optimalMoves}');
    print('   • Unique Boxes Moved: ${_countMovedBoxes(level)}');
    print('   • Total Displacement: ${_calculateDisplacement(level.boxMapping)}');
    print('\n🎮 Final Layout:');
    _printLevel(level.roomState, level.roomStructure);
    
    print('\n${"═" * 80}');
    print('║${_center("QUALITY ANALYSIS", 78)}║');
    print('${"═" * 80}\n');
    
    _performAdvancedAnalysis(level);
    
  } catch (e, stackTrace) {
    print('\n❌ FATAL ERROR: $e');
    print('Stack trace:\n$stackTrace');
  }
}

String _center(String text, int width) {
  final padding = (width - text.length) ~/ 2;
  return ' ' * padding + text + ' ' * (width - text.length - padding);
}

int _countMovedBoxes(GeneratedLevel level) {
  int count = 0;
  for (var entry in level.boxMapping.entries) {
    final target = entry.key.split(',').map(int.parse).toList();
    final box = entry.value;
    if (target[0] != box[0] || target[1] != box[1]) count++;
  }
  return count;
}

int _calculateDisplacement(Map<String, List<int>> boxMapping) {
  int total = 0;
  for (var entry in boxMapping.entries) {
    final target = entry.key.split(',').map(int.parse).toList();
    final box = entry.value;
    total += (target[0] - box[0]).abs() + (target[1] - box[1]).abs();
  }
  return total;
}

void _printLevel(List<List<int>> state, List<List<int>> structure) {
  print('   ┌${"─" * (state[0].length * 2)}┐');
  for (int y = 0; y < state.length; y++) {
    String line = '   │';
    for (int x = 0; x < state[y].length; x++) {
      final s = state[y][x];
      final str = structure[y][x];
      
      if (s == LevelGenerator.WALL) {
        line += '\x1B[90m██\x1B[0m';
      } else if (s == LevelGenerator.PLAYER) {
        line += '\x1B[91m▼ \x1B[0m';
      } else if (s == LevelGenerator.BOX) {
        if (str == LevelGenerator.TARGET) {
          line += '\x1B[93m☒ \x1B[0m';
        } else {
          line += '\x1B[33m☐ \x1B[0m';
        }
      } else if (str == LevelGenerator.TARGET) {
        line += '\x1B[96m◎ \x1B[0m';
      } else {
        line += '  ';
      }
    }
    print('$line│');
  }
  print('   └${"─" * (state[0].length * 2)}┘');
}

void _performAdvancedAnalysis(GeneratedLevel level) {
  final boxes = <List<int>>[];
  final targets = <List<int>>[];
  List<int>? playerPos;
  
  for (int y = 0; y < level.roomState.length; y++) {
    for (int x = 0; x < level.roomState[y].length; x++) {
      if (level.roomState[y][x] == LevelGenerator.PLAYER) {
        playerPos = [x, y];
      } else if (level.roomState[y][x] == LevelGenerator.BOX) {
        boxes.add([x, y]);
      }
      if (level.roomStructure[y][x] == LevelGenerator.TARGET) {
        targets.add([x, y]);
      }
    }
  }
  
  print('Basic Info:');
  print('  • ${boxes.length} boxes, ${targets.length} targets');
  print('  • Player at (${playerPos![0]}, ${playerPos[1]})\n');
  
  // Check individual box distances
  int trivialBoxes = 0;
  int totalManhattan = 0;
  for (int i = 0; i < boxes.length; i++) {
    final box = boxes[i];
    final target = targets[i];
    final manhattan = (box[0] - target[0]).abs() + (box[1] - target[1]).abs();
    totalManhattan += manhattan;
    
    print('  Box ${i + 1} → Target ${i + 1}: $manhattan tiles away');
    
    if (manhattan <= 3) {
      trivialBoxes++;
      print('     ⚠️  TOO CLOSE!');
    }
  }
  
  final avgDistance = totalManhattan / boxes.length;
  print('\n  Average distance: ${avgDistance.toStringAsFixed(1)} tiles');
  
  // Final verdict
  print('\n${"─" * 80}');
  if (trivialBoxes >= boxes.length / 2) {
    print('❌ TRIVIAL: Too many boxes close to targets');
  } else if (avgDistance < 5.0) {
    print('⚠️  EASY: Boxes are fairly close to targets');
  } else if (level.optimalMoves < boxes.length * 10) {
    print('⚠️  MEDIUM: Moderate challenge');
  } else {
    print('✅ GOOD: Puzzle appears properly challenging');
  }
}

// ============================================================================
// FIXED LEVEL GENERATOR
// ============================================================================

class GeneratedLevel {
  final List<List<int>> roomState;
  final List<List<int>> roomStructure;
  final Map<String, List<int>> boxMapping;
  final int optimalMoves;
  
  GeneratedLevel({
    required this.roomState,
    required this.roomStructure,
    required this.boxMapping,
    required this.optimalMoves,
  });
}

class LevelGenerator {
  static const int WALL = 0;
  static const int FLOOR = 1;
  static const int TARGET = 2;
  static const int BOX_ON_TARGET = 3;
  static const int BOX = 4;
  static const int PLAYER = 5;

  final math.Random _random = math.Random();
  final bool _verbose;
  
  Set<String> _exploredStates = {};
  List<List<int>>? _bestRoom;
  int _bestScore = -1;
  Map<String, List<int>>? _bestBoxMapping;
  
  static const Map<int, List<int>> CHANGE_COORDINATES = {
    0: [-1, 0], 1: [1, 0], 2: [0, -1], 3: [0, 1],
  };

  LevelGenerator({bool verbose = false}) : _verbose = verbose;

  void _log(String message, {bool force = false}) {
    if (_verbose || force) print(message);
  }

  GeneratedLevel generateLevel({
    required int dimX,
    required int dimY,
    required int numBoxes,
    int maxTries = 15,
  }) {
    _log('🎯 Starting generation: ${dimX}x$dimY, $numBoxes boxes\n');

    for (int attempt = 0; attempt < maxTries; attempt++) {
      _log('━━━ ATTEMPT ${attempt + 1}/$maxTries ━━━\n');
      
      try {
        // Step 1: Generate room with ENOUGH space
        _log('📐 Generating room topology...');
        final room = _generateBetterRoom(dimX, dimY);
        final floorCount = _countFloor(room);
        _log('   ✓ Created room with $floorCount floor tiles');
        
        // ✅ FIX: Much more reasonable minimum
        final minFloor = math.max(numBoxes * 8, 20);
        if (floorCount < minFloor) {
          _log('   ⚠️  Need at least $minFloor tiles, retrying...\n');
          continue;
        }
        _log('');
        
        // Step 2: Place targets with decent spacing
        _log('🎯 Placing targets...');
        final targets = _placeTargetsWithSpacing(room, numBoxes);
        if (targets == null) {
          _log('   ⚠️  Could not place targets, retrying...\n');
          continue;
        }
        for (int i = 0; i < targets.length; i++) {
          _log('   • Target ${i + 1}: (${targets[i][0]}, ${targets[i][1]})');
        }
        _log('');
        
        // Step 3: Place player
        _log('👤 Placing player...');
        final playerPos = _placePlayer(room, targets);
        if (playerPos == null) {
          _log('   ⚠️  Could not place player, retrying...\n');
          continue;
        }
        _log('   ✓ Player at (${playerPos[0]}, ${playerPos[1]})\n');
        
        // Step 4: Create structures
        final roomStructure = _createStructure(room, targets);
        final roomState = _createInitialState(room, targets, playerPos);
        
        _log('🎲 Running reverse-play scrambling...');
        
        // Step 5: Reverse play with good parameters
        final result = _reversePlayGood(roomState, roomStructure, numBoxes);
        
        final displacement = _boxDisplacementScore(result.boxMapping);
        _log('   ✓ Done! Score: ${result.score}, Displacement: $displacement\n');
        
        // ✅ FIX: Adaptive quality requirements based on grid size
        final minDisplacement = (numBoxes * 4).clamp(6, 20);
        final minScore = (numBoxes * 8).clamp(12, 40);
        
        if (result.score >= minScore && 
            displacement >= minDisplacement &&
            result.movedBoxesCount == numBoxes) {
          
          _log('✅ QUALITY CHECK PASSED!\n', force: true);
          
          final cleanedState = _cleanupBoxesOnTargets(result.room);
          
          return GeneratedLevel(
            roomStructure: roomStructure,
            roomState: cleanedState,
            boxMapping: result.boxMapping,
            optimalMoves: result.score,
          );
        } else {
          _log('❌ Quality check failed:');
          if (result.score < minScore) _log('   • Score: ${result.score} < $minScore');
          if (displacement < minDisplacement) _log('   • Displacement: $displacement < $minDisplacement');
          if (result.movedBoxesCount < numBoxes) _log('   • Boxes moved: ${result.movedBoxesCount}/$numBoxes');
          _log('');
        }
      } catch (e) {
        _log('❌ Error: $e\n');
        continue;
      }
    }

    _log('❌ ALL ATTEMPTS FAILED - Using fallback\n', force: true);
    return _createFallbackLevel(dimX, dimY, numBoxes);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BETTER ROOM GENERATION
  // ═══════════════════════════════════════════════════════════════════════
  
  List<List<int>> _generateBetterRoom(int dimX, int dimY) {
    List<List<int>> room = List.generate(dimX, (_) => List.filled(dimY, WALL));
    
    // Fill most of the interior with floor
    for (int x = 2; x < dimX - 2; x++) {
      for (int y = 2; y < dimY - 2; y++) {
        // Create mostly open space with occasional walls
        if (_random.nextDouble() > 0.2) {  // 80% floor
          room[x][y] = FLOOR;
        }
      }
    }
    
    // Ensure center is always open
    final cx = dimX ~/ 2;
    final cy = dimY ~/ 2;
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (cx + dx > 0 && cx + dx < dimX && cy + dy > 0 && cy + dy < dimY) {
          room[cx + dx][cy + dy] = FLOOR;
        }
      }
    }
    
    // Ensure there are some connected paths
    _ensureConnectivity(room);
    
    return room;
  }

  void _ensureConnectivity(List<List<int>> room) {
    // Simple flood fill to check if all floor tiles are connected
    List<int>? firstFloor;
    outer: for (int x = 0; x < room.length; x++) {
      for (int y = 0; y < room[x].length; y++) {
        if (room[x][y] == FLOOR) {
          firstFloor = [x, y];
          break outer;
        }
      }
    }
    
    if (firstFloor == null) return;
    
    final reachable = <String>{};
    final queue = Queue<List<int>>();
    queue.add(firstFloor);
    reachable.add('${firstFloor[0]},${firstFloor[1]}');
    
    while (queue.isNotEmpty) {
      final pos = queue.removeFirst();
      for (final dir in CHANGE_COORDINATES.values) {
        final nx = pos[0] + dir[0];
        final ny = pos[1] + dir[1];
        final key = '$nx,$ny';
        
        if (nx >= 0 && nx < room.length && ny >= 0 && ny < room[0].length &&
            room[nx][ny] == FLOOR && !reachable.contains(key)) {
          reachable.add(key);
          queue.add([nx, ny]);
        }
      }
    }
    
    // Connect any isolated floor tiles
    for (int x = 0; x < room.length; x++) {
      for (int y = 0; y < room[x].length; y++) {
        if (room[x][y] == FLOOR && !reachable.contains('$x,$y')) {
          // Create path to nearest reachable tile
          for (final dir in CHANGE_COORDINATES.values) {
            final nx = x + dir[0];
            final ny = y + dir[1];
            if (nx >= 0 && nx < room.length && ny >= 0 && ny < room[0].length) {
              room[nx][ny] = FLOOR;
            }
          }
        }
      }
    }
  }

  int _countFloor(List<List<int>> room) {
    int count = 0;
    for (var row in room) {
      for (var cell in row) {
        if (cell == FLOOR) count++;
      }
    }
    return count;
  }

  List<List<int>>? _placeTargetsWithSpacing(List<List<int>> room, int numBoxes) {
    List<List<int>> floorTiles = [];
    for (int x = 2; x < room.length - 2; x++) {
      for (int y = 2; y < room[x].length - 2; y++) {
        if (room[x][y] == FLOOR) {
          floorTiles.add([x, y]);
        }
      }
    }
    
    if (floorTiles.length < numBoxes) return null;
    
    List<List<int>> targets = [];
    
    // Place first target randomly
    floorTiles.shuffle(_random);
    targets.add(floorTiles.removeAt(0));
    
    // Place remaining targets with decent spacing
    while (targets.length < numBoxes && floorTiles.isNotEmpty) {
      // Sort by distance from nearest target (furthest first)
      floorTiles.sort((a, b) {
        int minDistA = 999;
        int minDistB = 999;
        for (var target in targets) {
          final distA = (a[0] - target[0]).abs() + (a[1] - target[1]).abs();
          final distB = (b[0] - target[0]).abs() + (b[1] - target[1]).abs();
          minDistA = math.min(minDistA, distA);
          minDistB = math.min(minDistB, distB);
        }
        return minDistB.compareTo(minDistA);
      });
      
      targets.add(floorTiles.removeAt(0));
    }
    
    return targets.length == numBoxes ? targets : null;
  }

  List<int>? _placePlayer(List<List<int>> room, List<List<int>> targets) {
    List<List<int>> floorTiles = [];
    final targetSet = targets.map((t) => '${t[0]},${t[1]}').toSet();
    
    for (int x = 0; x < room.length; x++) {
      for (int y = 0; y < room[x].length; y++) {
        if (room[x][y] == FLOOR && !targetSet.contains('$x,$y')) {
          floorTiles.add([x, y]);
        }
      }
    }
    
    if (floorTiles.isEmpty) return null;
    
    floorTiles.shuffle(_random);
    return floorTiles.first;
  }

  List<List<int>> _createStructure(List<List<int>> room, List<List<int>> targets) {
    List<List<int>> structure = room.map((row) => List<int>.from(row)).toList();
    for (var target in targets) {
      structure[target[0]][target[1]] = TARGET;
    }
    return structure;
  }

  List<List<int>> _createInitialState(List<List<int>> room, List<List<int>> targets, List<int> player) {
    List<List<int>> state = room.map((row) => List<int>.from(row)).toList();
    for (var target in targets) {
      state[target[0]][target[1]] = BOX;
    }
    state[player[0]][player[1]] = PLAYER;
    return state;
  }

  List<List<int>> _cleanupBoxesOnTargets(List<List<int>> room) {
    List<List<int>> cleaned = room.map((row) => List<int>.from(row)).toList();
    for (int i = 0; i < cleaned.length; i++) {
      for (int j = 0; j < cleaned[i].length; j++) {
        if (cleaned[i][j] == BOX_ON_TARGET) cleaned[i][j] = BOX;
      }
    }
    return cleaned;
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
      optimalMoves: numBoxes * 3,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REVERSE PLAY
  // ═══════════════════════════════════════════════════════════════════════

  ReversePlayResult _reversePlayGood(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    int numBoxes,
  ) {
    Map<String, List<int>> boxMapping = {};
    for (int i = 0; i < roomStructure.length; i++) {
      for (int j = 0; j < roomStructure[i].length; j++) {
        if (roomStructure[i][j] == TARGET) {
          boxMapping['$i,$j'] = [i, j];
        }
      }
    }

    _exploredStates.clear();
    _bestRoom = null;
    _bestScore = -1;
    _bestBoxMapping = null;

    Set<String> movedBoxes = {};

    _depthFirstSearch(
      roomState,
      roomStructure,
      boxMapping,
      numBoxes,
      movedBoxes,
      null,
      600,
      0,
    );

    return ReversePlayResult(
      room: _bestRoom ?? roomState,
      score: _bestScore,
      boxMapping: _bestBoxMapping ?? boxMapping,
      movedBoxesCount: (_bestBoxMapping != null) 
          ? _countMovedBoxes(_bestBoxMapping!, roomStructure)
          : 0,
    );
  }

  int _countMovedBoxes(Map<String, List<int>> boxMapping, List<List<int>> structure) {
    int count = 0;
    for (var entry in boxMapping.entries) {
      final target = entry.key.split(',').map(int.parse).toList();
      final box = entry.value;
      if (target[0] != box[0] || target[1] != box[1]) count++;
    }
    return count;
  }

  void _depthFirstSearch(
    List<List<int>> roomState,
    List<List<int>> roomStructure,
    Map<String, List<int>> boxMapping,
    int numBoxes,
    Set<String> movedBoxes,
    String? lastPulledBoxKey,
    int ttl,
    int depth,
  ) {
    if (ttl <= 0 || _exploredStates.length > 500000) return;

    String stateHash = _hashState(roomState);
    if (_exploredStates.contains(stateHash)) return;
    _exploredStates.add(stateHash);

    int displacement = _boxDisplacementScore(boxMapping);
    int boxSwaps = movedBoxes.length;
    int score = boxSwaps * displacement;

    if (score > _bestScore) {
      _bestRoom = roomState.map((row) => List<int>.from(row)).toList();
      _bestScore = score;
      _bestBoxMapping = Map<String, List<int>>.from(boxMapping);
    }

    for (int action = 0; action < 8; action++) {
      final result = _reverseMove(roomState, roomStructure, boxMapping, action);

      if (result != null) {
        Set<String> newMovedBoxes = Set.from(movedBoxes);
        
        if (result.pulled && result.pulledBoxKey != null) {
          newMovedBoxes.add(result.pulledBoxKey!);
        }

        _depthFirstSearch(
          result.room,
          roomStructure,
          result.boxMapping,
          numBoxes,
          newMovedBoxes,
          result.pulled ? result.pulledBoxKey : lastPulledBoxKey,
          ttl - 1,
          depth + 1,
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

    if (![FLOOR, TARGET].contains(newRoom[nextPos[0]][nextPos[1]])) {
      return null;
    }

    bool pulled = false;
    String? pulledBoxKey;

    if (action < 4) {
      final behindPos = [playerPos[0] - change[0], playerPos[1] - change[1]];

      if (behindPos[0] >= 0 && behindPos[0] < newRoom.length &&
          behindPos[1] >= 0 && behindPos[1] < newRoom[0].length) {
        if ([BOX, BOX_ON_TARGET].contains(newRoom[behindPos[0]][behindPos[1]])) {
          newRoom[playerPos[0]][playerPos[1]] = BOX_ON_TARGET;
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
}

class ReversePlayResult {
  final List<List<int>> room;
  final int score;
  final Map<String, List<int>> boxMapping;
  final int movedBoxesCount;

  ReversePlayResult({
    required this.room,
    required this.score,
    required this.boxMapping,
    required this.movedBoxesCount,
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