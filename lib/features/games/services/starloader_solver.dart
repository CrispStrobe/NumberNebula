// lib/features/games/services/starloader_solver.dart
//
// Push-optimal Sokoban solver used to measure the TRUE difficulty of a
// generated Cargo-Loader (StarLoader) level. The legacy generator scored
// levels with `boxSwaps * displacement` (Manhattan distance to goal), which
// rewards boxes sitting far away on open floor in a straight line — i.e. the
// most boring possible level. This solver computes the real minimum number of
// box pushes required to solve the level (or proves it unsolvable / gives up
// after a node budget), so generation can select for genuinely hard puzzles.
//
// Pure Dart (no Flutter imports) so it is unit-testable and can also run in the
// offline level-baking tool.
//
// Tile encoding matches LevelGenerator:
//   structure: WALL=0, FLOOR=1, TARGET=2
//   state:     BOX_ON_TARGET=3, BOX=4, PLAYER=5  (otherwise mirrors structure)
//
// The board is treated as a generic grid[row][col]; Sokoban is symmetric in
// the two axes so the physical x/y meaning of the indices does not matter.

import 'package:collection/collection.dart';

class StarloaderSolver {
  static const int wall = 0;
  static const int floor = 1;
  static const int target = 2;
  static const int boxOnTarget = 3;
  static const int box = 4;
  static const int player = 5;

  final int rows;
  final int cols;

  /// True where the cell is a wall (immovable).
  final List<bool> _wall;

  /// True where the cell is a goal/target.
  final List<bool> _target;

  /// True where a box can NEVER reach any target from (computed once); pushing
  /// a box onto such a cell is an immediate, permanent deadlock.
  late final List<bool> _dead;

  /// Initial box cells and the initial player cell, as flat indices.
  final List<int> _initialBoxes;
  final int _initialPlayer;

  StarloaderSolver._(
    this.rows,
    this.cols,
    this._wall,
    this._target,
    this._initialBoxes,
    this._initialPlayer,
  ) {
    _dead = _computeDeadSquares();
  }

  /// Builds a solver from a level's static [structure] and dynamic [state]
  /// grids (the same shapes LevelGenerator / LevelEntry produce).
  factory StarloaderSolver.fromGrids(
    List<List<int>> structure,
    List<List<int>> state,
  ) {
    final rows = structure.length;
    final cols = rows > 0 ? structure[0].length : 0;
    final wallFlags = List<bool>.filled(rows * cols, false);
    final targetFlags = List<bool>.filled(rows * cols, false);
    final boxes = <int>[];
    int playerCell = -1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (structure[r][c] == wall) wallFlags[idx] = true;
        if (structure[r][c] == target) targetFlags[idx] = true;
        final s = state[r][c];
        if (s == box || s == boxOnTarget) boxes.add(idx);
        if (s == player) playerCell = idx;
      }
    }
    boxes.sort();
    return StarloaderSolver._(
      rows,
      cols,
      wallFlags,
      targetFlags,
      boxes,
      playerCell,
    );
  }

  int get boxCount => _initialBoxes.length;
  int get targetCount => _target.where((t) => t).length;

  // --- Geometry helpers -------------------------------------------------

  int _idx(int r, int c) => r * cols + c;
  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// The 4 orthogonal neighbours of [cell] (as flat indices), or -1 when out
  /// of bounds. Order: up, down, left, right.
  List<int> _neighbours(int cell) {
    final r = cell ~/ cols;
    final c = cell % cols;
    return [
      _inBounds(r - 1, c) ? _idx(r - 1, c) : -1,
      _inBounds(r + 1, c) ? _idx(r + 1, c) : -1,
      _inBounds(r, c - 1) ? _idx(r, c - 1) : -1,
      _inBounds(r, c + 1) ? _idx(r, c + 1) : -1,
    ];
  }

  // --- Dead-square precomputation --------------------------------------

  /// A cell is "live" if a box placed there could be pulled back to some
  /// target. We compute this by reverse-pulling from every target: a box can
  /// be pulled from `from` to `to` (adjacent) only if the cell beyond `to`
  /// (where the player would stand to pull) is also free. The complement of
  /// the live set (restricted to non-wall cells) is the dead set.
  List<bool> _computeDeadSquares() {
    final live = List<bool>.filled(rows * cols, false);
    final queue = <int>[];
    for (var cell = 0; cell < rows * cols; cell++) {
      if (_target[cell]) {
        live[cell] = true;
        queue.add(cell);
      }
    }

    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      final r = cell ~/ cols;
      final c = cell % cols;
      // For each pull direction, the box moves from `cell` to `pullTo`, and the
      // player must stand one further along the same line at `playerCell`.
      const dirs = [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ];
      for (final d in dirs) {
        final pr = r + d[0];
        final pc = c + d[1];
        final ppr = r + 2 * d[0];
        final ppc = c + 2 * d[1];
        if (!_inBounds(pr, pc) || !_inBounds(ppr, ppc)) continue;
        final pullTo = _idx(pr, pc);
        final playerCell = _idx(ppr, ppc);
        if (_wall[pullTo] || _wall[playerCell]) continue;
        if (!live[pullTo]) {
          live[pullTo] = true;
          queue.add(pullTo);
        }
      }
    }

    final dead = List<bool>.filled(rows * cols, false);
    for (var cell = 0; cell < rows * cols; cell++) {
      if (!_wall[cell] && !live[cell]) dead[cell] = true;
    }
    return dead;
  }

  /// Exposed for tests: cells from which no box can ever reach a target.
  List<bool> get deadSquares => List.unmodifiable(_dead);

  // --- Player reachability ---------------------------------------------

  /// Cells the player can reach from [start] without pushing any box, given the
  /// current [boxSet]. Returns the visited bitmap and the canonical (minimum-
  /// index) reachable cell used to normalise equivalent states.
  ({List<bool> reachable, int canonical}) _playerReach(
    int start,
    Set<int> boxSet,
  ) {
    final reachable = List<bool>.filled(rows * cols, false);
    var canonical = start;
    final stack = <int>[start];
    reachable[start] = true;
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      if (cell < canonical) canonical = cell;
      for (final n in _neighbours(cell)) {
        if (n < 0 || reachable[n] || _wall[n] || boxSet.contains(n)) continue;
        reachable[n] = true;
        stack.add(n);
      }
    }
    return (reachable: reachable, canonical: canonical);
  }

  // --- Heuristic --------------------------------------------------------

  /// Admissible lower bound on remaining pushes: each box needs at least its
  /// Manhattan distance to the nearest target (each push moves it 1 closer).
  int _heuristic(List<int> boxes) {
    var total = 0;
    for (final b in boxes) {
      final br = b ~/ cols;
      final bc = b % cols;
      var best = 1 << 30;
      for (var t = 0; t < rows * cols; t++) {
        if (!_target[t]) continue;
        final d = (br - t ~/ cols).abs() + (bc - t % cols).abs();
        if (d < best) best = d;
      }
      if (best != 1 << 30) total += best;
    }
    return total;
  }

  String _key(int canonicalPlayer, List<int> boxes) =>
      '$canonicalPlayer|${boxes.join(",")}';

  bool _allOnTargets(List<int> boxes) {
    for (final b in boxes) {
      if (!_target[b]) return false;
    }
    return true;
  }

  /// Solves for the minimum number of box pushes. Stops and reports
  /// `exhausted` once [nodeBudget] states have been expanded without proving
  /// optimality (so runtime callers stay bounded; offline baking can pass a
  /// large budget).
  StarloaderSolveResult solve({int nodeBudget = 200000}) {
    if (_initialPlayer < 0) {
      return const StarloaderSolveResult(
        solved: false,
        pushes: null,
        exhausted: false,
      );
    }
    if (_initialBoxes.length != targetCount) {
      // Malformed: box/target counts differ — can never fully cover.
      return const StarloaderSolveResult(
        solved: false,
        pushes: null,
        exhausted: false,
      );
    }
    // Any box already stuck on a dead, non-target square ⇒ unsolvable.
    for (final b in _initialBoxes) {
      if (_dead[b] && !_target[b]) {
        return const StarloaderSolveResult(
          solved: false,
          pushes: null,
          exhausted: false,
        );
      }
    }
    if (_allOnTargets(_initialBoxes)) {
      return const StarloaderSolveResult(
        solved: true,
        pushes: 0,
        exhausted: false,
      );
    }

    final initialBoxSet = _initialBoxes.toSet();
    final startReach = _playerReach(_initialPlayer, initialBoxSet);
    final startBoxes = List<int>.from(_initialBoxes)..sort();

    // A* over (normalised player region, box configuration). g = pushes so far.
    final open = PriorityQueue<_Node>((a, b) => a.f.compareTo(b.f));
    final bestG = <String, int>{};

    final startKey = _key(startReach.canonical, startBoxes);
    final startH = _heuristic(startBoxes);
    bestG[startKey] = 0;
    open.add(_Node(
      canonicalPlayer: startReach.canonical,
      reachable: startReach.reachable,
      boxes: startBoxes,
      g: 0,
      f: startH,
    ));

    var expanded = 0;
    while (open.isNotEmpty) {
      if (expanded >= nodeBudget) {
        return const StarloaderSolveResult(
          solved: false,
          pushes: null,
          exhausted: true,
        );
      }
      final node = open.removeFirst();
      final nodeKey = _key(node.canonicalPlayer, node.boxes);
      if (node.g > (bestG[nodeKey] ?? 1 << 30)) continue; // stale entry
      expanded++;

      if (_allOnTargets(node.boxes)) {
        return StarloaderSolveResult(
          solved: true,
          pushes: node.g,
          exhausted: false,
        );
      }

      final boxSet = node.boxes.toSet();
      for (var i = 0; i < node.boxes.length; i++) {
        final b = node.boxes[i];
        final br = b ~/ cols;
        final bc = b % cols;
        const dirs = [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ];
        for (final d in dirs) {
          final toR = br + d[0];
          final toC = bc + d[1];
          final fromR = br - d[0];
          final fromC = bc - d[1];
          if (!_inBounds(toR, toC) || !_inBounds(fromR, fromC)) continue;
          final to = _idx(toR, toC);
          final fromCell = _idx(fromR, fromC);
          // Destination must be empty; player must be able to stand behind.
          if (_wall[to] || boxSet.contains(to)) continue;
          if (_wall[fromCell] || boxSet.contains(fromCell)) continue;
          if (!node.reachable[fromCell]) continue;
          // Pushing onto a dead non-target square is a permanent deadlock.
          if (_dead[to] && !_target[to]) continue;

          final newBoxes = List<int>.from(node.boxes);
          newBoxes[i] = to;
          newBoxes.sort();
          if (_isFrozenDeadlock(to, newBoxes.toSet())) continue;

          // After the push the player occupies the box's former cell.
          final newReach = _playerReach(b, newBoxes.toSet());
          final newKey = _key(newReach.canonical, newBoxes);
          final newG = node.g + 1;
          if (newG >= (bestG[newKey] ?? 1 << 30)) continue;
          bestG[newKey] = newG;
          open.add(_Node(
            canonicalPlayer: newReach.canonical,
            reachable: newReach.reachable,
            boxes: newBoxes,
            g: newG,
            f: newG + _heuristic(newBoxes),
          ));
        }
      }
    }

    return const StarloaderSolveResult(
      solved: false,
      pushes: null,
      exhausted: false,
    );
  }

  /// Detects the classic "frozen" deadlock: a box pushed into a position where
  /// it is blocked on both a vertical and a horizontal neighbour (by a wall or
  /// another box) and is not on a target. Such a box can never move again.
  bool _isFrozenDeadlock(int cell, Set<int> boxSet) {
    if (_target[cell]) return false;
    final r = cell ~/ cols;
    final c = cell % cols;
    bool blocked(int rr, int cc) {
      if (!_inBounds(rr, cc)) return true;
      final idx = _idx(rr, cc);
      return _wall[idx] || boxSet.contains(idx);
    }

    final vBlocked = blocked(r - 1, c) || blocked(r + 1, c);
    final hBlocked = blocked(r, c - 1) || blocked(r, c + 1);
    return vBlocked && hBlocked;
  }
}

class StarloaderSolveResult {
  /// Whether a full solution (all boxes on targets) was found.
  final bool solved;

  /// Minimum number of pushes when [solved]; null otherwise.
  final int? pushes;

  /// True when the search hit its node budget without a verdict (treat as
  /// "unknown / probably hard" rather than "unsolvable").
  final bool exhausted;

  const StarloaderSolveResult({
    required this.solved,
    required this.pushes,
    required this.exhausted,
  });

  @override
  String toString() =>
      'StarloaderSolveResult(solved: $solved, pushes: $pushes, exhausted: $exhausted)';
}

class _Node {
  final int canonicalPlayer;
  final List<bool> reachable;
  final List<int> boxes;
  final int g;
  final int f;

  _Node({
    required this.canonicalPlayer,
    required this.reachable,
    required this.boxes,
    required this.g,
    required this.f,
  });
}
