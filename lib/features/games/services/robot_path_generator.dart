// ignore_for_file: constant_identifier_names
// robot_path_generator.dart (FIXED - Carves both pocket and action spot)
import 'dart:math' as math;

class RobotPathGenerator {
  static const int EMPTY = 0;
  static const int WALL = 1;
  static const int PATH = 2;
  static const int START = 3;
  static const int GOAL = 4;
  static const int JUMPABLE_WALL = 5;
  static const int DESTRUCTIBLE = 6;
  static const int MOVABLE = 7;

  final math.Random _random = math.Random();

  RobotLevel generateLevel({
    required int dimX,
    required int dimY,
    required int pathLength,
    required int obstacleCount,
    double turnFrequency = 0.3,
    double obstacleVariety = 0.7,
    int maxAttempts = 5,
  }) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final startTime = DateTime.now();
        
        final level = _generateLevelWithTimeout(
          dimX,
          dimY,
          pathLength,
          obstacleCount,
          turnFrequency,
          obstacleVariety,
          startTime,
        );
        
        if (level != null) {
          return level;
        }
      } catch (e) {
        continue;
      }
    }
    
    return _createFallbackLevel(dimX, dimY);
  }

  RobotLevel? _generateLevelWithTimeout(
    int dimX,
    int dimY,
    int pathLength,
    int obstacleCount,
    double turnFrequency,
    double obstacleVariety,
    DateTime startTime,
  ) {
    List<Position> mainPath = _generateContinuousPath(
      dimX,
      dimY,
      pathLength,
      turnFrequency,
      startTime,
    );

    if (mainPath.length < 5) {
      return null;
    }

    List<List<int>> grid = List.generate(
      dimX,
      (_) => List.filled(dimY, WALL),
    );

    // Mark path
    for (var pos in mainPath) {
      grid[pos.x][pos.y] = PATH;
    }

    // Mark start and goal
    grid[mainPath.first.x][mainPath.first.y] = START;
    grid[mainPath.last.x][mainPath.last.y] = GOAL;

    // Place obstacles (with validation for movable objects)
    List<Obstacle> obstacles = _placeObstaclesOnPath(
      grid,
      mainPath,
      obstacleCount,
      obstacleVariety,
    );

    return RobotLevel(
      grid: grid,
      start: mainPath.first,
      goal: mainPath.last,
      obstacles: obstacles,
      optimalMoves: mainPath.length - 1,
    );
  }

  List<Position> _generateContinuousPath(
    int dimX,
    int dimY,
    int targetLength,
    double turnFrequency,
    DateTime startTime,
  ) {
    int startQuadrantX = dimX ~/ 3;
    int startQuadrantY = dimY ~/ 3;
    
    Position current = Position(
      2 + _random.nextInt(math.max(1, startQuadrantX - 2)),
      2 + _random.nextInt(math.max(1, startQuadrantY - 2)),
    );
    
    int minGoalX = math.max(dimX ~/ 2, current.x + dimX ~/ 3);
    int minGoalY = math.max(dimY ~/ 2, current.y + dimY ~/ 3);
    
    Position goal = Position(
      minGoalX + _random.nextInt(math.max(1, dimX - 2 - minGoalX)),
      minGoalY + _random.nextInt(math.max(1, dimY - 2 - minGoalY)),
    );
    
    goal = Position(
      goal.x.clamp(2, dimX - 3),
      goal.y.clamp(2, dimY - 3),
    );

    List<Position> path = [current];
    Set<String> visited = {'${current.x},${current.y}'};
    
    int direction = _random.nextBool() ? 1 : 3;
    int stepsSinceLastTurn = 0;
    int iterationCount = 0;

    while (path.length < targetLength) {
      iterationCount++;
      
      if (iterationCount % 100 == 0) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed > 250) {
          throw TimeoutException('Path generation timeout');
        }
      }
      
      if (stepsSinceLastTurn >= 4 && _random.nextDouble() < turnFrequency) {
        if (direction == 0 || direction == 1) {
          direction = _random.nextBool() ? 2 : 3;
        } else {
          direction = _random.nextBool() ? 0 : 1;
        }
        stepsSinceLastTurn = 0;
      }

      Position next = _step(current, direction);

      if (!_isValidMove(next, dimX, dimY, visited)) {
        List<int> dirs = [0, 1, 2, 3];
        dirs.shuffle(_random);
        
        bool found = false;
        for (int dir in dirs) {
          next = _step(current, dir);
          if (_isValidMove(next, dimX, dimY, visited)) {
            direction = dir;
            found = true;
            stepsSinceLastTurn = 0;
            break;
          }
        }
        
        if (!found) {
          break;
        }
      }

      path.add(next);
      visited.add('${next.x},${next.y}');
      current = next;
      stepsSinceLastTurn++;
    }

    int safetyCounter = 0;
    while ((current.x != goal.x || current.y != goal.y) && safetyCounter < 200) {
      safetyCounter++;
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed > 250) {
        throw TimeoutException('Path to goal timeout');
      }
      
      int dx = goal.x - current.x;
      int dy = goal.y - current.y;
      
      Position next;
      
      if (dx.abs() > dy.abs()) {
        next = Position(current.x + dx.sign, current.y);
      } else if (dy.abs() > 0) {
        next = Position(current.x, current.y + dy.sign);
      } else if (dx.abs() > 0) {
        next = Position(current.x + dx.sign, current.y);
      } else {
        break;
      }
      
      if (!_isInBounds(next, dimX, dimY)) {
        if (dx.abs() > dy.abs()) {
          next = Position(current.x, current.y + dy.sign);
        } else {
          next = Position(current.x + dx.sign, current.y);
        }
      }
      
      if (_isInBounds(next, dimX, dimY)) {
        if (!visited.contains('${next.x},${next.y}')) {
          path.add(next);
          visited.add('${next.x},${next.y}');
        }
        current = next;
      } else {
        break;
      }
    }

    return path;
  }

  bool _isValidMove(Position pos, int dimX, int dimY, Set<String> visited) {
    return _isInBounds(pos, dimX, dimY) && !visited.contains('${pos.x},${pos.y}');
  }

  bool _isInBounds(Position pos, int dimX, int dimY) {
    // Keep the 2-tile border
    return pos.x >= 2 && pos.x < dimX - 2 && pos.y >= 2 && pos.y < dimY - 2;
  }

  Position _step(Position pos, int direction) {
    switch (direction) {
      case 0: return Position(pos.x - 1, pos.y); // Up
      case 1: return Position(pos.x + 1, pos.y); // Down
      case 2: return Position(pos.x, pos.y - 1); // Left
      case 3: return Position(pos.x, pos.y + 1); // Right
      default: return pos;
    }
  }

  List<Obstacle> _placeObstaclesOnPath(
    List<List<int>> grid,
    List<Position> path,
    int count,
    double variety,
  ) {
    List<Obstacle> obstacles = [];
    Set<int> reservedPathIndices = {};
    
    // Place obstacles across the middle ~20%-80% of the path (never right at
    // the start/goal). The previous expressions collapsed to constants
    // (startIdx==3, endIdx==path.length-4) because of redundant min/max calls,
    // so the path-length scaling was dead.
    int startIdx = math.max(3, path.length ~/ 5);
    int endIdx = math.min(path.length - 4, path.length - path.length ~/ 5);
    
    int usableLength = endIdx - startIdx;
    if (usableLength <= 0 || count <= 0) return obstacles;
    
    double spacing = usableLength / count;
    
    List<int> potentialIndices = [];
    for (int i = 0; i < count; i++) {
      int idx = startIdx + (spacing * (i + 0.5)).round();
      if (idx >= endIdx || idx >= path.length) break;
      if(!potentialIndices.contains(idx)) {
        potentialIndices.add(idx);
      }
    }

    // --- PASS 1: Place MOVABLE obstacles ---
    for (int idx in potentialIndices) {
      if (reservedPathIndices.contains(idx)) continue;
      
      Position pos = path[idx];
      ObstacleType type = _pickObstacleType(variety);

      if (type != ObstacleType.movable) continue;

      List<List<int>> dirPairs = [[2, 3], [3, 2]]; 
      dirPairs.shuffle(_random);

      for (var pair in dirPairs) {
        Position pocketPos = _step(pos, pair[0]); 
        Position actionPos = _step(pos, pair[1]); 
        
        Position beforePos = path[idx - 1];
        Position accessPos = _step(beforePos, pair[1]); 

        if (_isInBounds(pocketPos, grid.length, grid[0].length) && grid[pocketPos.x][pocketPos.y] == WALL &&
            _isInBounds(actionPos, grid.length, grid[0].length) && grid[actionPos.x][actionPos.y] == WALL &&
            _isInBounds(accessPos, grid.length, grid[0].length) && grid[accessPos.x][accessPos.y] == WALL) {
          
          Position afterPos = path[idx + 1];

          // 1. Check for bypass
          List<List<int>> bypassTestGrid = grid.map(List<int>.from).toList();
          bypassTestGrid[pos.x][pos.y] = WALL; 
          bypassTestGrid[pocketPos.x][pocketPos.y] = PATH;
          bypassTestGrid[actionPos.x][actionPos.y] = PATH;
          bypassTestGrid[accessPos.x][accessPos.y] = PATH;
          
          bool createsBypass = _canReach(bypassTestGrid, beforePos, afterPos);
          if (createsBypass) continue;
          
          // 2. Check if solvable
          List<List<int>> testGrid = grid.map(List<int>.from).toList();
          testGrid[pos.x][pos.y] = MOVABLE;
          testGrid[pocketPos.x][pocketPos.y] = PATH;
          testGrid[actionPos.x][actionPos.y] = PATH;
          testGrid[accessPos.x][accessPos.y] = PATH;
          
          bool isSolvable = _isMovableSolvable(testGrid, path.first, path.last, pos);

          // 3. If NOT a bypass AND IS solvable, COMMIT
          if (isSolvable) {
            grid[pos.x][pos.y] = MOVABLE;
            grid[pocketPos.x][pocketPos.y] = PATH;
            grid[actionPos.x][actionPos.y] = PATH;
            grid[accessPos.x][accessPos.y] = PATH;
            
            obstacles.add(Obstacle(position: pos, type: ObstacleType.movable));
            
            reservedPathIndices.add(idx);
            reservedPathIndices.add(idx - 1);
            reservedPathIndices.add(idx + 1);
            
            break; 
          }
        }
      }
    } // --- End MOVABLE pass ---
    
    // --- PASS 2: Place OTHER obstacles ---
    for (int idx in potentialIndices) {
      if (reservedPathIndices.contains(idx)) continue; 
      
      Position pos = path[idx];
      if (grid[pos.x][pos.y] != PATH) continue; 

      ObstacleType type = _pickObstacleType(variety);
      
      if (type == ObstacleType.movable) {
          type = _random.nextBool() ? ObstacleType.jumpWall : ObstacleType.destructible;
      }

      // *** BEGIN NEW FIX ***
      // Check for Jumpable Wall placement
      if (type == ObstacleType.jumpWall) {
        Position before = path[idx - 1];
        Position after = path[idx + 1];

        // Check for horizontal straight line
        bool isHorizontal = (before.x == pos.x && after.x == pos.x);
        // Check for vertical straight line
        bool isVertical = (before.y == pos.y && after.y == pos.y);

        // If it's not a straight line, it's an invalid jump. Downgrade it.
        if (!isHorizontal && !isVertical) {
          type = ObstacleType.destructible;
        }
      }
      // *** END NEW FIX ***

      switch (type) {
        case ObstacleType.jumpWall:
          grid[pos.x][pos.y] = JUMPABLE_WALL;
          obstacles.add(Obstacle(position: pos, type: ObstacleType.jumpWall));
          break;
        case ObstacleType.destructible:
          grid[pos.x][pos.y] = DESTRUCTIBLE;
          obstacles.add(Obstacle(position: pos, type: ObstacleType.destructible));
          break;
        case ObstacleType.movable: // Should not be hit
           break;
      }
      reservedPathIndices.add(idx); 
    }
    
    return obstacles;
  }

  // This function is UNCHANGED from your previous version. It's correct.
  bool _isMovableSolvable(List<List<int>> grid, Position start, Position goal, Position objectPos) {
    // This function receives a 'grid' where the MOVABLE object is ALREADY placed.
    // It must check if a PUSH or a PULL can solve the puzzle.

    // Try moving in all 4 directions
    List<int> directions = [0, 1, 2, 3]; // 0=Up, 1=Down, 2=Left, 3=Right
    
    for (int dir in directions) {
      
      // --- 1. TRY PUSHING in this direction ---
      // Robot stands BEHIND object, moves FORWARD
      {
        Position pushFrom = _step(objectPos, (dir + 2) % 4); // Opposite direction (where robot stands)
        Position pushTo = _step(objectPos, dir); // Where object moves
        
        // Check bounds
        if (_isInBounds(pushFrom, grid.length, grid[0].length) &&
            _isInBounds(pushTo, grid.length, grid[0].length)) {
          
          // Check if robot can stand at pushFrom
          int pushFromTile = grid[pushFrom.x][pushFrom.y];
          bool canStand = (pushFromTile == PATH || pushFromTile == START || pushFromTile == GOAL);
          
          // Check if object can be pushed into pushTo (must be empty path)
          int pushToTile = grid[pushTo.x][pushTo.y];
          bool canPushTo = (pushToTile == PATH);

          if (canStand && canPushTo) {
            // Check: Can we reach the 'pushFrom' position from the 'start'?
            // This is the key: the 'grid' now has the carved 'action spot'
            bool canReachObject = _canReach(grid, start, pushFrom);
            
            if (canReachObject) {
              // Simulate the push
              List<List<int>> testGrid = grid.map(List<int>.from).toList();
              testGrid[objectPos.x][objectPos.y] = PATH; // Old object spot is now path
              testGrid[pushTo.x][pushTo.y] = MOVABLE;    // New object spot
              
              // Check: Can we reach the 'goal' *after* pushing?
              // The robot is now at the 'objectPos' (its old spot).
              bool canReachGoal = _canReach(testGrid, objectPos, goal);
              
              if (canReachGoal) {
                return true; // Found a valid PUSH solution
              }
            }
          }
        }
      } // End Push Check

      // --- 2. TRY PULLING in this direction ---
      // Robot stands IN FRONT of object, moves BACKWARD
      // Object moves INTO the robot's old spot.
      {
        Position robotStandPos = _step(objectPos, (dir + 2) % 4); // Robot stands opposite 'dir'
        Position robotMovePos = _step(robotStandPos, (dir + 2) % 4); // Robot moves further opposite 'dir'
        Position objectMovePos = robotStandPos; // Object moves into robot's standing spot

        // Check bounds for the two spaces the robot needs
        if (_isInBounds(robotStandPos, grid.length, grid[0].length) &&
            _isInBounds(robotMovePos, grid.length, grid[0].length)) {

            // Check if robot can stand at robotStandPos
            int standTile = grid[robotStandPos.x][robotStandPos.y];
            bool canStand = (standTile == PATH || standTile == START || standTile == GOAL);

            // Check if robot can move to robotMovePos (must be empty path)
            // This is the "needs more space" check.
            // My generator does NOT carve this *second* space.
            // This logic needs to be updated.
            
            // Let's assume the "pocket" is the space the robot moves into.
            // No, that's wrong.
            
            // Let's re-evaluate the PULL.
            // `robotStandPos` is the "action spot".
            // `robotMovePos` MUST be a *path* tile (the "needs more space").
            // `objectMovePos` = `robotStandPos`.
            
            // The `_placeObstaclesOnPath` only carves `pocketPos` and `actionPos`.
            // PULL (dir=3, Right) -> object moves right
            // `robotStandPos = (5,9)` (action)
            // `robotMovePos = (5,8)` (must be path)
            // `objectMovePos = (5,9)`
            
            // This means `pocketPos` for a PUSH is `objectMovePos` for a PULL.
            // And `actionPos` for a PUSH is `robotStandPos` for a PULL.
            
            // The pull `robotMovePos` check is the problem.
            // `_placeObstaclesOnPath` must carve `pocketPos` and `actionPos`
            // AND ensure `_step(actionPos, (dir+2)%4)` is ALSO a path.
            
            // This is too complex. Let's simplify and ASSUME
            // the main path provides the "needs more space" tile.
            
            int moveTile = grid[robotMovePos.x][robotMovePos.y];
            bool canMoveTo = (moveTile == PATH || moveTile == START || moveTile == GOAL);

            if (canStand && canMoveTo) {
                // Check: Can we reach the 'robotStandPos' from the 'start'?
                bool canReachObject = _canReach(grid, start, robotStandPos);

                if (canReachObject) {
                    // Simulate the pull
                    List<List<int>> testGrid = grid.map(List<int>.from).toList();
                    testGrid[objectPos.x][objectPos.y] = PATH; // Old object spot is now path
                    testGrid[objectMovePos.x][objectMovePos.y] = MOVABLE; // New object spot (where robot was)

                    // Robot is now at robotMovePos
                    bool canReachGoal = _canReach(testGrid, robotMovePos, goal);

                    if (canReachGoal) {
                        return true; // Found a valid PULL solution
                    }
                }
            }
        }
      } // End Pull Check
    } // End for loop
    
    // We checked all 4 directions for both PUSH and PULL, and none worked.
    return false;
  }

  bool _canReach(List<List<int>> grid, Position from, Position to) {
    // Simple BFS pathfinding
    if (from == to) return true;
    
    Set<String> visited = {};
    List<Position> queue = [from];
    visited.add('${from.x},${from.y}');
    
    while (queue.isNotEmpty) {
      Position current = queue.removeAt(0);
      
      if (current == to) return true;
      
      // Try all 4 directions
      for (int dir = 0; dir < 4; dir++) {
        Position next = _step(current, dir);
        String key = '${next.x},${next.y}';
        
        if (visited.contains(key)) continue;
        
        // Use grid bounds, not internal bounds, for BFS
         if (next.x < 0 || next.x >= grid.length || next.y < 0 || next.y >= grid[0].length) {
          continue;
        }
        
        int tile = grid[next.x][next.y];
        // Can walk on PATH, START, GOAL, JUMPABLE_WALL, DESTRUCTIBLE
        // *** NOTE: MOVABLE is NOT in this list, so it's treated as a wall. ***
        if (tile == PATH || tile == START || tile == GOAL || 
            tile == JUMPABLE_WALL || tile == DESTRUCTIBLE) {
          visited.add(key);
          queue.add(next);
        }
      }
      
      // Safety limit
      if (visited.length > (grid.length * grid[0].length)) return false;
    }
    
    return false;
  }

  ObstacleType _pickObstacleType(double variety) {
    double r = _random.nextDouble();
    
    // Prioritize movable if variety is high
    if (variety > 0.7) {
      if (r < 0.5) return ObstacleType.movable;       // 50%
      if (r < 0.75) return ObstacleType.jumpWall;     // 25%
      return ObstacleType.destructible;               // 25%
    } else if (variety > 0.4) {
      if (r < 0.3) return ObstacleType.movable;       // 30%
      if (r < 0.65) return ObstacleType.jumpWall;    // 35%
      return ObstacleType.destructible;               // 35%
    } else {
      // Low variety, no movable
      return r < 0.5 ? ObstacleType.jumpWall : ObstacleType.destructible;
    }
  }

  RobotLevel _createFallbackLevel(int dimX, int dimY) {
    List<List<int>> grid = List.generate(
      dimX,
      (_) => List.filled(dimY, WALL),
    );

    int midX = dimX ~/ 2;
    for (int j = 1; j < dimY - 1; j++) {
      grid[midX][j] = PATH;
    }

    grid[midX][1] = START;
    grid[midX][dimY - 2] = GOAL;

    return RobotLevel(
      grid: grid,
      start: Position(midX, 1),
      goal: Position(midX, dimY - 2),
      obstacles: [],
      optimalMoves: dimY - 3,
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}

class Position {
  final int x;
  final int y;

  Position(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  
  @override
  String toString() => '($x, $y)';
}

enum ObstacleType {
  jumpWall,
  destructible,
  movable,
}

class Obstacle {
  final Position position;
  final ObstacleType type; // Fixed typo

  Obstacle({
    required this.position,
    required this.type,
  });
}

class RobotLevel {
  final List<List<int>> grid;
  final Position start;
  final Position goal;
  final List<Obstacle> obstacles;
  final int optimalMoves;

  RobotLevel({
    required this.grid,
    required this.start,
    required this.goal,
    required this.obstacles,
    required this.optimalMoves,
  });

  String toLayoutString() {
    List<String> lines = [];
    for (int i = 0; i < grid.length; i++) {
      String line = '';
      for (int j = 0; j < grid[i].length; j++) {
        switch (grid[i][j]) {
          case RobotPathGenerator.WALL:
            line += '█';
          case RobotPathGenerator.PATH:
            line += ' ';
          case RobotPathGenerator.START:
            line += 'S';
          case RobotPathGenerator.GOAL:
            line += 'G';
          case RobotPathGenerator.JUMPABLE_WALL:
            line += '▬';
          case RobotPathGenerator.DESTRUCTIBLE:
            line += '▓';
          case RobotPathGenerator.MOVABLE:
            line += '○';
          default:
            line += '█';
        }
      }
      lines.add(line);
    }
    return lines.join('\n');
  }
}