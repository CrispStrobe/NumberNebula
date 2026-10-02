import 'robot_path_generator.dart' as gen;
import 'algorithm_path.dart';

enum CellType { empty, wall, start, goal, jumpableWall, destructible, movable }

class PathLevel {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'grid': grid.map((v0) => v0.map((v1) => v1.name).toList()).toList(),
        'startRow': startRow,
        'startCol': startCol,
        'startDirection': startDirection,
        'goalRow': goalRow,
        'goalCol': goalCol,
        'optimalMoves': optimalMoves
      };
  factory PathLevel.fromJson(Map<String, dynamic> json) => PathLevel(
      gridSize: json['gridSize'] as int,
      grid: (json['grid'] as List)
          .map((v0) => (v0 as List)
              .map((v1) => CellType.values.byName(v1 as String))
              .toList())
          .toList(),
      startRow: json['startRow'] as int,
      startCol: json['startCol'] as int,
      startDirection: json['startDirection'] as int,
      goalRow: json['goalRow'] as int,
      goalCol: json['goalCol'] as int,
      optimalMoves: json['optimalMoves'] as int);

  final int gridSize;
  List<List<CellType>> grid;
  final int startRow;
  final int startCol;
  final int startDirection;
  final int goalRow;
  final int goalCol;
  final int optimalMoves;

  PathLevel({
    required this.gridSize,
    required this.grid,
    required this.startRow,
    required this.startCol,
    required this.startDirection,
    required this.goalRow,
    required this.goalCol,
    required this.optimalMoves,
  });

  int get commandAllowance => (optimalMoves * 1.75)
      .ceil()
      .clamp(20, algorithmPath == AlgorithmPath.legacy ? 40 : 80);

  static PathLevel generate(int grade, int level) {
    if (algorithmPath == AlgorithmPath.legacy) {
      recordAlgorithm('robot-path', 'legacy');
      return _generateLegacy(grade, level);
    }
    // Preserve the maze algorithm; independently prove the complete command path.
    // Retry unchanged generation when a movable obstacle blocks its route.
    for (var attempt = 0; attempt < 4; attempt++) {
      final board = _generateLegacy(grade, level);
      final commands = solveRobotCommands(board);
      if (commands != null && commands.length <= 60) {
        recordAlgorithm('robot-path', 'candidate-verified');
        return PathLevel(
            gridSize: board.gridSize,
            grid: board.grid,
            startRow: board.startRow,
            startCol: board.startCol,
            startDirection: board.startDirection,
            goalRow: board.goalRow,
            goalCol: board.goalCol,
            optimalMoves: commands.length);
      }
    }
    // Verified fallback: keep the original generated maze, clearing only special
    // obstacles whose interactions prevented a bounded proof. Ordinary walls stay.
    recordAlgorithm('robot-path', 'legacy-maze-cleared-obstacles-verified');
    final board = _generateLegacy(grade, level);
    for (final row in board.grid) {
      for (var c = 0; c < row.length; c++) {
        if (row[c] == CellType.movable ||
            row[c] == CellType.destructible ||
            row[c] == CellType.jumpableWall) {
          row[c] = CellType.empty;
        }
      }
    }
    final commands = solveRobotCommands(board);
    if (commands == null || commands.length > 60) {
      throw StateError('Robot maze has no bounded command proof');
    }
    return PathLevel(
        gridSize: board.gridSize,
        grid: board.grid,
        startRow: board.startRow,
        startCol: board.startCol,
        startDirection: board.startDirection,
        goalRow: board.goalRow,
        goalCol: board.goalCol,
        optimalMoves: commands.length);
  }

  static PathLevel _generateLegacy(int grade, int level) {
    final generator = gen.RobotPathGenerator();

    final complexity = (grade - 1) * 5 + level;
    final int dim = (10 + (complexity * 0.5)).clamp(10, 17).toInt();
    final int pathLen = (9 + complexity).clamp(10, 25).toInt();
    final int obsCount = (1 + (complexity / 3)).clamp(1, 5).toInt();

    final double variety;
    if (grade == 1) {
      variety = 0.0;
    } else if (grade == 2) {
      variety = 0.3;
    } else if (grade == 3) {
      variety = 0.6;
    } else {
      variety = 0.9;
    }

    final robotLevel = generator.generateLevel(
      dimX: dim,
      dimY: dim,
      pathLength: pathLen,
      obstacleCount: obsCount,
      obstacleVariety: variety,
    );

    final int gridSize = robotLevel.grid.length;
    final grid = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (c) => CellType.wall),
    );

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        switch (robotLevel.grid[r][c]) {
          case gen.RobotPathGenerator.PATH:
            grid[r][c] = CellType.empty;
            break;
          case gen.RobotPathGenerator.START:
            grid[r][c] = CellType.start;
            break;
          case gen.RobotPathGenerator.GOAL:
            grid[r][c] = CellType.goal;
            break;
          case gen.RobotPathGenerator.JUMPABLE_WALL:
            grid[r][c] = CellType.jumpableWall;
            break;
          case gen.RobotPathGenerator.DESTRUCTIBLE:
            grid[r][c] = CellType.destructible;
            break;
          case gen.RobotPathGenerator.MOVABLE:
            grid[r][c] = CellType.movable;
            break;
          case gen.RobotPathGenerator.WALL:
          default:
            grid[r][c] = CellType.wall;
            break;
        }
      }
    }

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final cell = grid[r][c];

        if (cell == CellType.jumpableWall && grade < 2) {
          grid[r][c] = CellType.empty;
        }

        if (cell == CellType.destructible && grade < 3) {
          grid[r][c] = CellType.empty;
        }

        if (cell == CellType.movable && grade < 4) {
          grid[r][c] = CellType.empty;
        }
      }
    }

    int optimalMoves = _calculateOptimalPath(robotLevel);

    int startDirection = 1;
    final startPos = robotLevel.start;
    if (_isValidGridPos(grid, startPos.x, startPos.y + 1)) {
      startDirection = 1; // Right
    } else if (_isValidGridPos(grid, startPos.x + 1, startPos.y)) {
      startDirection = 2; // Down
    } else if (_isValidGridPos(grid, startPos.x, startPos.y - 1)) {
      startDirection = 3; // Left
    } else if (_isValidGridPos(grid, startPos.x - 1, startPos.y)) {
      startDirection = 0; // Up
    }

    return PathLevel(
      gridSize: gridSize,
      grid: grid,
      startRow: robotLevel.start.x,
      startCol: robotLevel.start.y,
      startDirection: startDirection,
      goalRow: robotLevel.goal.x,
      goalCol: robotLevel.goal.y,
      optimalMoves: optimalMoves,
    );
  }

  static bool _isValidGridPos(List<List<CellType>> grid, int r, int c) {
    if (r < 0 || r >= grid.length || c < 0 || c >= grid.length) return false;
    final cell = grid[r][c];
    return cell == CellType.empty || cell == CellType.goal;
  }

  static int _calculateOptimalPath(gen.RobotLevel robotLevel) {
    return robotLevel.optimalMoves + robotLevel.obstacles.length;
  }
}

/// Commands match the app's execution rules, including the distinct start-cell
/// restrictions on push/pull and goal tiles becoming empty after a box moves.
enum RobotCommand {
  forward,
  jump,
  turnLeft,
  turnRight,
  destroy,
  wait,
  push,
  pull
}

class RobotCommandState {
  final int row, col, direction;
  final List<List<CellType>> grid;
  final String? _sharedGridKey;
  late final String _gridKey =
      _sharedGridKey ?? grid.map((r) => r.map((c) => c.index).join()).join();
  RobotCommandState(this.row, this.col, this.direction, this.grid,
      {String? gridKey})
      : _sharedGridKey = gridKey;
  factory RobotCommandState.start(PathLevel level) => RobotCommandState(
      level.startRow, level.startCol, level.startDirection, level.grid);
  String get key => '$row,$col,$direction:$_gridKey';
}

RobotCommandState? stepRobotCommand(
    RobotCommandState state, RobotCommand command) {
  final grid = state.grid, n = grid.length;
  final dr = [-1, 0, 1, 0][state.direction];
  final dc = [0, 1, 0, -1][state.direction];
  final r = state.row, c = state.col;
  bool inside(int y, int x) => y >= 0 && y < n && x >= 0 && x < n;
  bool clear(int y, int x, {bool allowStart = true}) =>
      inside(y, x) &&
      (grid[y][x] == CellType.empty ||
          grid[y][x] == CellType.goal ||
          (allowStart && grid[y][x] == CellType.start));
  RobotCommandState moved(int y, int x, [List<List<CellType>>? changed]) =>
      RobotCommandState(y, x, state.direction, changed ?? grid,
          gridKey: changed == null ? state._gridKey : null);
  if (command == RobotCommand.turnLeft || command == RobotCommand.turnRight) {
    return RobotCommandState(
        r,
        c,
        (state.direction + (command == RobotCommand.turnLeft ? 3 : 1)) % 4,
        grid,
        gridKey: state._gridKey);
  }
  if (command == RobotCommand.wait) return state;
  final y = r + dr, x = c + dc;
  if (!inside(y, x)) return null;
  switch (command) {
    case RobotCommand.forward:
      return clear(y, x) ? moved(y, x) : null;
    case RobotCommand.jump:
      return grid[y][x] == CellType.jumpableWall &&
              clear(r + 2 * dr, c + 2 * dc)
          ? moved(r + 2 * dr, c + 2 * dc)
          : null;
    case RobotCommand.destroy:
      if (grid[y][x] != CellType.destructible) return null;
      final changed = grid.map(List<CellType>.from).toList();
      changed[y][x] = CellType.empty;
      return moved(r, c, changed);
    case RobotCommand.push:
    case RobotCommand.pull:
      if (grid[y][x] != CellType.movable) return null;
      final destR = command == RobotCommand.push ? r + 2 * dr : r - dr;
      final destC = command == RobotCommand.push ? c + 2 * dc : c - dc;
      if (!clear(destR, destC, allowStart: false)) return null;
      final changed = grid.map(List<CellType>.from).toList();
      changed[y][x] = CellType.empty;
      changed[command == RobotCommand.push ? destR : r]
          [command == RobotCommand.push ? destC : c] = CellType.movable;
      return command == RobotCommand.push
          ? moved(y, x, changed)
          : moved(destR, destC, changed);
    default:
      return null;
  }
}

/// Breadth first search proves the shortest command sequence, including turns.
/// null means no proof within the node budget (never a claim of unsolvability).
List<RobotCommand>? solveRobotCommands(PathLevel level,
    {int maxStates = 50000}) {
  final states = [RobotCommandState.start(level)];
  final parents = [-1], commands = <RobotCommand?>[null];
  final seen = <String>{states.first.key};
  for (var head = 0; head < states.length; head++) {
    final state = states[head];
    if (state.row == level.goalRow && state.col == level.goalCol) {
      final result = <RobotCommand>[];
      for (var i = head; parents[i] >= 0; i = parents[i]) {
        result.add(commands[i]!);
      }
      return result.reversed.toList();
    }
    for (final command in RobotCommand.values) {
      if (command == RobotCommand.wait) continue;
      final next = stepRobotCommand(state, command);
      if (next == null || !seen.add(next.key)) continue;
      if (states.length >= maxStates) return null;
      states.add(next);
      parents.add(head);
      commands.add(command);
    }
  }
  return null;
}
