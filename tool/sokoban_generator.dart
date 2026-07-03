// ignore_for_file: avoid_print, constant_identifier_names
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: library_private_types_in_public_api
//
// tool/sokoban_generator.dart
//
// Sokoban level generator with parametrized difficulty (1..10).
// Faithful Dart port of tool/sokoban_generator.py (same algorithm, same
// difficulty bands and scoring). See that file for the long-form rationale.
//
// Why the levels are guaranteed playable and non-trivial
// ------------------------------------------------------
// 1.  ROOM SYNTHESIS    - the map is assembled from 3x3 wall templates
//     (Taylor & Parberry style) and validated: floor fully connected,
//     moderate density, no large open area.
// 2.  REVERSE GENERATION - boxes start ON the goals (solved state) and are
//     scrambled by *pulling* them backwards.  Every pull-reachable state is
//     solvable by construction, so the generator can never emit an
//     unsolvable level.
// 3.  FORWARD A* SOLVER  - each candidate start is re-solved with a
//     push-optimizing A* (dead-square + 2x2 freeze pruning, player position
//     normalized to its reachable region), yielding difficulty metrics.
// 4.  DIFFICULTY SCORING - score = pushes + 3*changes + 2*counter
//                                       + 2*log2(nodes+1)
// 5.  GENERATE-AND-TEST  - rooms/goal-sets are sampled until a level lands in
//     the requested band (with a time budget; best-effort otherwise).
//
// NOTE ON DETERMINISM: this port uses dart:math Random, seeded via -seed.
// A given (difficulty, seed) is reproducible in Dart, but Dart's RNG differs
// from CPython's Mersenne Twister, so output is NOT byte-identical to the
// Python tool.  Correctness is guaranteed structurally: every emitted level
// is re-solved and its LURD solution is replayed before it is returned.
//
// Cells are encoded as ints `r * 256 + c` (stride 256, coords < 256),
// which makes floor/box/goal sets plain Set<int> and directions plain int
// deltas: UP=-256, DOWN=256, LEFT=-1, RIGHT=1.
//
// Level format (standard Sokoban ASCII):
//     #  wall        .  goal            $  box        @  player
//     *  box on goal +  player on goal  (space) floor
//
// CLI
// ---
//   dart run tool/sokoban_generator.dart -d 6                  # one level
//   dart run tool/sokoban_generator.dart -d 9 -n 3 --seed 7    # three seeded
//   dart run tool/sokoban_generator.dart -d 4 --solution       # print LURD
//   dart run tool/sokoban_generator.dart --demo pack.html      # playable HTML

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// ---------------------------------------------------------------- geometry
const int _STRIDE = 256;
const int UP = -_STRIDE;
const int DOWN = _STRIDE;
const int LEFT = -1;
const int RIGHT = 1;
const List<int> DIRS = [UP, DOWN, LEFT, RIGHT];
const Map<int, String> DIR_CHAR = {UP: 'u', DOWN: 'd', LEFT: 'l', RIGHT: 'r'};
const Map<String, int> CHAR_DIR = {'u': UP, 'd': DOWN, 'l': LEFT, 'r': RIGHT};

/// Dead-square / unreachable sentinel (stands in for Python's float('inf')).
const int INF = 1 << 60;

/// Encode a (row, col) coordinate into the single-int cell id used throughout.
int cellId(int r, int c) => r * _STRIDE + c;

/// Decode the row of a cell id produced by [cellId].
int rowOf(int cell) => cell ~/ _STRIDE;

/// Decode the column of a cell id produced by [cellId].
int colOf(int cell) => cell % _STRIDE;

/// Canonical, hashable key for a set of box positions (sorted ints).
String _boxKey(Set<int> boxes) {
  final list = boxes.toList()..sort();
  return list.join(',');
}

// ------------------------------------------------------- seeded RNG helpers
/// Small wrapper over dart:math Random giving the Python-like helpers the
/// generator relies on (choice / sample / randrange / random).
class _Rng {
  _Rng(int? seed) : _r = seed == null ? math.Random() : math.Random(seed);
  final math.Random _r;

  double random() => _r.nextDouble();
  int randrange(int n) => _r.nextInt(n);
  T choice<T>(List<T> items) => items[_r.nextInt(items.length)];
  void shuffle<T>(List<T> items) => items.shuffle(_r);

  /// n distinct elements from [items] (partial Fisher-Yates); like
  /// random.sample.  Does not mutate [items].
  List<T> sample<T>(List<T> items, int n) {
    final pool = List<T>.of(items);
    final out = <T>[];
    for (var i = 0; i < n; i++) {
      final j = i + _r.nextInt(pool.length - i);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
      out.add(pool[i]);
    }
    return out;
  }
}

// ---------------------------------------------------------------- templates
// 3x3 building blocks ('#' wall, ' ' floor); rotations/mirrors are generated.
const List<List<String>> _BASE = [
  ['   ', '   ', '   '],
  ['#  ', '   ', '   '],
  ['## ', '   ', '   '],
  ['###', '   ', '   '],
  ['## ', '#  ', '   '],
  ['###', '#  ', '   '],
  ['#  ', '   ', '  #'],
  ['## ', '   ', ' ##'],
  [' # ', '   ', '   '],
  ['   ', ' # ', '   '],
  [' # ', ' # ', '   '],
  ['# #', '   ', '   '],
];

List<String> _rot(List<String> t) {
  // 90 degrees clockwise: new[r] = concat over c of t[2-c][r]
  return List<String>.generate(3, (r) {
    final sb = StringBuffer();
    for (var c = 0; c < 3; c++) {
      sb.write(t[2 - c][r]);
    }
    return sb.toString();
  });
}

List<String> _mirror(List<String> t) =>
    t.map((row) => row.split('').reversed.join()).toList();

final List<List<String>> TEMPLATES = _buildTemplates();

List<List<String>> _buildTemplates() {
  final out = <List<String>>[];
  final seen = <String>{};
  for (final t in _BASE) {
    for (final v in [t, _mirror(t)]) {
      var cur = v;
      for (var i = 0; i < 4; i++) {
        cur = _rot(cur);
        final key = cur.join('|');
        if (!seen.contains(key)) {
          seen.add(key);
          out.add(cur);
        }
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------- room build
class _Room {
  _Room(this.floors, this.H, this.W);
  final Set<int> floors;
  final int H;
  final int W;
}

/// Assemble a (3*bw+2) x (3*bh+2) room from random templates.
_Room buildRoom(_Rng rng, int bw, int bh) {
  final H = bh * 3 + 2;
  final W = bw * 3 + 2;
  final grid = List.generate(H, (_) => List<String>.filled(W, '#'));
  for (var by = 0; by < bh; by++) {
    for (var bx = 0; bx < bw; bx++) {
      final t = rng.choice(TEMPLATES);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          grid[1 + 3 * by + i][1 + 3 * bx + j] = t[i][j];
        }
      }
    }
  }
  final floors = <int>{};
  for (var r = 0; r < H; r++) {
    for (var c = 0; c < W; c++) {
      if (grid[r][c] == ' ') floors.add(cellId(r, c));
    }
  }
  return _Room(floors, H, W);
}

bool roomOk(Set<int> floors, int H, int W, int minFloor) {
  if (floors.length < minFloor) return false;
  final interior = (H - 2) * (W - 2);
  if (!(0.30 * interior <= floors.length && floors.length <= 0.82 * interior)) {
    return false;
  }
  // single connected component
  final start = floors.first;
  final seen = <int>{start};
  final dq = <int>[start];
  var head = 0;
  while (head < dq.length) {
    final p = dq[head++];
    for (final d in DIRS) {
      final q = p + d;
      if (floors.contains(q) && !seen.contains(q)) {
        seen.add(q);
        dq.add(q);
      }
    }
  }
  if (seen.length != floors.length) return false;
  // reject big open areas (they make puzzles trivial): 3x4 or 4x3 blocks
  for (final cellPos in floors) {
    final r = rowOf(cellPos), c = colOf(cellPos);
    var open34 = true;
    for (var i = 0; i < 3 && open34; i++) {
      for (var j = 0; j < 4; j++) {
        if (!floors.contains(cellId(r + i, c + j))) {
          open34 = false;
          break;
        }
      }
    }
    if (open34) return false;
    var open43 = true;
    for (var i = 0; i < 4 && open43; i++) {
      for (var j = 0; j < 3; j++) {
        if (!floors.contains(cellId(r + i, c + j))) {
          open43 = false;
          break;
        }
      }
    }
    if (open43) return false;
  }
  return true;
}

// ---------------------------------------------------------------- analysis
/// Precomputed floor adjacency -- the hot loops run on this.
Map<int, List<int>> makeNbrs(Set<int> floors) {
  final out = <int, List<int>>{};
  for (final c in floors) {
    final ns = <int>[];
    for (final d in DIRS) {
      if (floors.contains(c + d)) ns.add(c + d);
    }
    out[c] = ns;
  }
  return out;
}

/// Cells the player can walk to from [p], given box positions.
Set<int> reachable(Map<int, List<int>> nbrs, Set<int> boxes, int p) {
  final seen = <int>{p};
  final dq = <int>[p];
  var head = 0;
  while (head < dq.length) {
    final x = dq[head++];
    for (final y in nbrs[x]!) {
      if (!boxes.contains(y) && !seen.contains(y)) {
        seen.add(y);
        dq.add(y);
      }
    }
  }
  return seen;
}

int _minOf(Set<int> s) {
  var m = INF;
  for (final v in s) {
    if (v < m) m = v;
  }
  return m;
}

/// dist[c] = min pushes to bring a lone box from c to some goal.
/// dist == INF  <=>  c is a dead square (a box there can never score).
Map<int, int> pullMetric(Set<int> floors, Set<int> goals) {
  final dist = <int, int>{for (final c in floors) c: INF};
  final dq = <int>[];
  var head = 0;
  for (final g in goals) {
    dist[g] = 0;
    dq.add(g);
  }
  while (head < dq.length) {
    final x = dq[head++];
    for (final d in DIRS) {
      final y = x - d; // a box on y pushed towards d lands on x
      if (floors.contains(y) && floors.contains(y - d) && dist[y] == INF) {
        dist[y] = dist[x]! + 1;
        dq.add(y);
      }
    }
  }
  return dist;
}

/// True if the push that put a box on [movedTo] created a 2x2 block of
/// walls/boxes containing an off-goal box (a permanent deadlock).
bool freeze2x2(Set<int> floors, Set<int> boxes, int movedTo, Set<int> goals) {
  final r = rowOf(movedTo), c = colOf(movedTo);
  for (final dr in const [-1, 0]) {
    for (final dc in const [-1, 0]) {
      final cells = <int>[
        for (final i in const [0, 1])
          for (final j in const [0, 1]) cellId(r + dr + i, c + dc + j),
      ];
      final blocked =
          cells.every((x) => !floors.contains(x) || boxes.contains(x));
      if (blocked &&
          cells.any((x) => boxes.contains(x) && !goals.contains(x))) {
        return true;
      }
    }
  }
  return false;
}

// ---------------------------------------------------------------- backward
class _Candidate {
  _Candidate(this.boxes, this.player, this.depth, this.off);
  final Set<int> boxes;
  final int player;
  final int depth;
  final int off;
}

/// Beam search over PULL moves starting from the solved state.  Every state
/// reachable by pulls is forward-solvable by construction; the beam is driven
/// towards states whose boxes are far (in push-metric) from the goals.
/// Returns candidate start states, most-scrambled first.
List<_Candidate> backwardScramble(
  _Rng rng,
  Set<int> floors,
  Map<int, List<int>> nbrs,
  Set<int> goals,
  Map<int, int> dist,
  int beamWidth,
  int maxDepth, {
  int keep = 8,
}) {
  int spread(Set<int> boxes) {
    var s = 0;
    for (final b in boxes) {
      s += dist[b]!;
    }
    return s;
  }

  final boxes0 = Set<int>.of(goals);
  final remaining = floors.difference(boxes0);
  if (remaining.isEmpty) return [];

  var frontier = <MapEntry<Set<int>, int>>[]; // (boxes, player_cell)
  final rem = Set<int>.of(remaining);
  while (rem.isNotEmpty) {
    // one root per player region
    final p = rem.first;
    final reg = reachable(nbrs, boxes0, p);
    rem.removeAll(reg);
    frontier.add(MapEntry(boxes0, _minOf(reg)));
  }

  final visited = <String>{};
  // pool entry: (score, depth, off, boxes, player)
  final pool = <List<Object>>[];

  for (var depth = 1; depth <= maxDepth; depth++) {
    // next-state set, keyed to dedup on (boxes, player)
    final nxt = <String, MapEntry<Set<int>, int>>{};
    for (final fe in frontier) {
      final boxes = fe.key;
      final pcell = fe.value;
      final reg = reachable(nbrs, boxes, pcell);
      final key = '${_boxKey(boxes)}|${_minOf(reg)}';
      if (visited.contains(key)) continue;
      visited.add(key);
      for (final b in boxes) {
        for (final d in DIRS) {
          final p1 = b + d; // player stands here, box pulled here
          final p2 = p1 + d; // player steps back here
          if (reg.contains(p1) &&
              floors.contains(p2) &&
              !boxes.contains(p2)) {
            final nb = Set<int>.of(boxes)
              ..remove(b)
              ..add(p1);
            nxt.putIfAbsent('${_boxKey(nb)}|$p2', () => MapEntry(nb, p2));
          }
        }
      }
    }
    if (nxt.isEmpty) break;

    // score candidates: far-from-goal + off-goal + tie-break noise
    final scored = <List<Object>>[];
    for (final e in nxt.values) {
      final nb = e.key;
      final p2 = e.value;
      var off = 0;
      for (final b in nb) {
        if (!goals.contains(b)) off++;
      }
      final s = 3 * spread(nb) + 4 * off + rng.random();
      scored.add([s, nb, p2, off]);
    }
    scored.sort((a, b) => (b[0] as double).compareTo(a[0] as double));

    frontier = [
      for (final t in scored.take(beamWidth))
        MapEntry(t[1] as Set<int>, t[2] as int),
    ];
    final keepN = math.max(4, keep);
    for (final t in scored.take(keepN)) {
      pool.add([(t[0] as double) + depth, depth, t[3] as int, t[1], t[2]]);
    }
    if (pool.length > 400) {
      pool.sort((a, b) => (b[0] as double).compareTo(a[0] as double));
      pool.removeRange(math.min(keep * 8, pool.length), pool.length);
    }
  }

  pool.sort((a, b) => (b[0] as double).compareTo(a[0] as double));
  final out = <_Candidate>[];
  final seenBoxes = <String>{};
  for (final entry in pool) {
    final boxes = entry[3] as Set<int>;
    final bk = _boxKey(boxes);
    if (seenBoxes.contains(bk)) continue;
    seenBoxes.add(bk);
    out.add(_Candidate(boxes, entry[4] as int, entry[1] as int, entry[2] as int));
    if (out.length >= keep) break;
  }
  return out;
}

// ---------------------------------------------------------------- forward A*
class _SolveResult {
  _SolveResult(this.actions, this.expanded);
  final List<List<int>> actions; // [from, to]
  final int expanded;
}

/// Min-heap entry: [f, h, g, idx], compared lexicographically.
class _Heap {
  final List<List<int>> _a = [];

  bool get isNotEmpty => _a.isNotEmpty;

  static int _cmp(List<int> x, List<int> y) {
    for (var i = 0; i < 4; i++) {
      if (x[i] != y[i]) return x[i] - y[i];
    }
    return 0;
  }

  void push(List<int> e) {
    _a.add(e);
    var i = _a.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_cmp(_a[i], _a[parent]) < 0) {
        final tmp = _a[i];
        _a[i] = _a[parent];
        _a[parent] = tmp;
        i = parent;
      } else {
        break;
      }
    }
  }

  List<int> pop() {
    final top = _a[0];
    final last = _a.removeLast();
    if (_a.isNotEmpty) {
      _a[0] = last;
      var i = 0;
      final n = _a.length;
      while (true) {
        final l = 2 * i + 1, r = 2 * i + 2;
        var smallest = i;
        if (l < n && _cmp(_a[l], _a[smallest]) < 0) smallest = l;
        if (r < n && _cmp(_a[r], _a[smallest]) < 0) smallest = r;
        if (smallest == i) break;
        final tmp = _a[i];
        _a[i] = _a[smallest];
        _a[smallest] = tmp;
        i = smallest;
      }
    }
    return top;
  }
}

/// Push-count A* with dead-square + freeze pruning.
/// Returns a [_SolveResult] or null (unsolvable within [nodeCap]).
_SolveResult? solveForward(
  Set<int> floors,
  Map<int, List<int>> nbrs,
  Set<int> goals,
  Map<int, int> dist,
  Set<int> boxes0,
  int player0,
  int nodeCap,
) {
  var h0 = 0;
  for (final b in boxes0) {
    if (dist[b] == INF) return null;
    h0 += dist[b]!;
  }
  // states: parallel arrays (boxes, player, parent, fromCell, toCell)
  final sBoxes = <Set<int>>[boxes0];
  final sPlayer = <int>[player0];
  final sParent = <int>[-1];
  final sFrom = <int>[-1];
  final sTo = <int>[-1];

  final pq = _Heap()..push([h0, h0, 0, 0]);
  final gbest = <String, int>{};
  final closed = <String>{};
  var expanded = 0;

  while (pq.isNotEmpty) {
    final top = pq.pop();
    final h = top[1], g = top[2], idx = top[3];
    final boxes = sBoxes[idx];
    final player = sPlayer[idx];
    final reach = reachable(nbrs, boxes, player);
    final key = '${_boxKey(boxes)}|${_minOf(reach)}';
    if (closed.contains(key)) continue;
    closed.add(key);
    expanded++;
    if (expanded > nodeCap) return null;

    if (h == 0 && boxes.every(goals.contains)) {
      final actions = <List<int>>[];
      var i = idx;
      while (i > 0) {
        actions.add([sFrom[i], sTo[i]]);
        i = sParent[i];
      }
      return _SolveResult(actions.reversed.toList(), expanded);
    }

    for (final b in boxes) {
      for (final d in DIRS) {
        final behind = b - d, tgt = b + d;
        if (!reach.contains(behind)) continue;
        if (!floors.contains(tgt) || boxes.contains(tgt)) continue;
        final dt = dist[tgt]!;
        if (dt == INF) continue; // dead square
        final nb = Set<int>.of(boxes)
          ..remove(b)
          ..add(tgt);
        if (freeze2x2(floors, nb, tgt, goals)) continue;
        final ng = g + 1;
        final pkey = '${_boxKey(nb)}#$b';
        if ((gbest[pkey] ?? (1 << 30)) <= ng) continue;
        gbest[pkey] = ng;
        final nh = h - dist[b]! + dt; // incremental heuristic
        sBoxes.add(nb);
        sPlayer.add(b);
        sParent.add(idx);
        sFrom.add(b);
        sTo.add(tgt);
        pq.push([ng + nh, nh, ng, sBoxes.length - 1]);
      }
    }
  }
  return null;
}

class _Metrics {
  _Metrics(this.pushes, this.changes, this.counter, this.score);
  final int pushes;
  final int changes;
  final int counter;
  final double score;
}

_Metrics solutionMetrics(
    Map<int, int> dist, List<List<int>> actions, int expanded) {
  final pushes = actions.length;
  var changes = 0, counter = 0;
  int? prevTo;
  for (final a in actions) {
    final frm = a[0], to = a[1];
    if (prevTo != null && frm != prevTo) changes++;
    if (dist[to]! > dist[frm]!) counter++;
    prevTo = to;
  }
  final score = pushes +
      3.0 * changes +
      2.0 * counter +
      2.0 * (math.log(expanded + 1) / math.ln2);
  return _Metrics(pushes, changes, counter, _round1(score));
}

double _round1(double x) => (x * 10).round() / 10;

// ---------------------------------------------------------------- LURD
List<String> _bfsPath(
    Map<int, List<int>> nbrs, Set<int> boxes, int src, int dst) {
  if (src == dst) return [];
  final prev = <int, List<int>?>{src: null}; // cell -> [from, dir]
  final dq = <int>[src];
  var head = 0;
  while (head < dq.length) {
    final x = dq[head++];
    for (final y in nbrs[x]!) {
      final d = y - x;
      if (!boxes.contains(y) && !prev.containsKey(y)) {
        prev[y] = [x, d];
        if (y == dst) {
          final path = <String>[];
          var cur = y;
          while (prev[cur] != null) {
            final fx = prev[cur]![0], fd = prev[cur]![1];
            path.add(DIR_CHAR[fd]!);
            cur = fx;
          }
          return path.reversed.toList();
        }
        dq.add(y);
      }
    }
  }
  throw StateError('no player path (internal error)');
}

String buildLurd(Map<int, List<int>> nbrs, Set<int> boxes0, int player0,
    List<List<int>> actions) {
  final boxes = Set<int>.of(boxes0);
  var p = player0;
  final out = <String>[];
  for (final a in actions) {
    final frm = a[0], to = a[1];
    final d = to - frm;
    final stand = frm - d;
    out.addAll(_bfsPath(nbrs, boxes, p, stand));
    out.add(DIR_CHAR[d]!.toUpperCase());
    boxes.remove(frm);
    boxes.add(to);
    p = frm;
  }
  return out.join();
}

// ---------------------------------------------------------------- level obj
class Level {
  Level({
    required this.floors,
    required this.goals,
    required this.boxes,
    required this.player,
    required this.solution,
    required this.stats,
  });

  final Set<int> floors;
  final Set<int> goals;
  final Set<int> boxes;
  final int player;
  final String solution;
  final Map<String, dynamic> stats;

  String ascii() {
    var rMin = INF, rMax = -INF, cMin = INF, cMax = -INF;
    for (final f in floors) {
      final r = rowOf(f), c = colOf(f);
      if (r < rMin) rMin = r;
      if (r > rMax) rMax = r;
      if (c < cMin) cMin = c;
      if (c > cMax) cMax = c;
    }
    final r0 = rMin - 1, r1 = rMax + 1, c0 = cMin - 1, c1 = cMax + 1;
    final lines = <String>[];
    for (var r = r0; r <= r1; r++) {
      final line = StringBuffer();
      for (var c = c0; c <= c1; c++) {
        final p = cellId(r, c);
        if (floors.contains(p)) {
          if (p == player) {
            line.write(goals.contains(p) ? '+' : '@');
          } else if (boxes.contains(p)) {
            line.write(goals.contains(p) ? '*' : r'$');
          } else if (goals.contains(p)) {
            line.write('.');
          } else {
            line.write(' ');
          }
        } else {
          var near = false;
          for (final i in const [-1, 0, 1]) {
            for (final j in const [-1, 0, 1]) {
              if (floors.contains(cellId(r + i, c + j))) {
                near = true;
                break;
              }
            }
            if (near) break;
          }
          line.write(near ? '#' : ' ');
        }
      }
      lines.add(line.toString().replaceFirst(RegExp(r'\s+$'), ''));
    }
    return lines.join('\n');
  }

  /// Replay [solution]; true iff it solves the level.
  bool verify() {
    final bx = Set<int>.of(boxes);
    var p = player;
    for (final ch in solution.split('')) {
      final d = CHAR_DIR[ch.toLowerCase()]!;
      final q = p + d;
      if (bx.contains(q)) {
        final q2 = q + d;
        if (!floors.contains(q2) || bx.contains(q2)) return false;
        bx.remove(q);
        bx.add(q2);
        p = q;
      } else if (floors.contains(q)) {
        p = q;
      } else {
        return false;
      }
    }
    return _setEq(bx, goals);
  }
}

bool _setEq(Set<int> a, Set<int> b) =>
    a.length == b.length && a.every(b.contains);

// ---------------------------------------------------------------- difficulty
// bw,bh: room size in 3x3 blocks | boxes | acceptance band
class _Params {
  const _Params({
    required this.bw,
    required this.bh,
    required this.boxes,
    required this.minPushes,
    required this.minChanges,
    required this.scoreLo,
    required this.pushHi,
    required this.beam,
    required this.fwdCap,
    required this.minOff,
  });
  final int bw, bh, boxes, minPushes, minChanges, scoreLo, beam, fwdCap, minOff;
  final int? pushHi;
}

const Map<int, _Params> PARAMS = {
  1: _Params(bw: 2, bh: 2, boxes: 2, minPushes: 5, minChanges: 0, scoreLo: 20,
      pushHi: 14, beam: 120, fwdCap: 60000, minOff: 1),
  2: _Params(bw: 2, bh: 2, boxes: 2, minPushes: 8, minChanges: 0, scoreLo: 27,
      pushHi: 20, beam: 150, fwdCap: 80000, minOff: 2),
  3: _Params(bw: 3, bh: 2, boxes: 3, minPushes: 10, minChanges: 1, scoreLo: 36,
      pushHi: 26, beam: 200, fwdCap: 90000, minOff: 2),
  4: _Params(bw: 3, bh: 2, boxes: 3, minPushes: 14, minChanges: 2, scoreLo: 46,
      pushHi: null, beam: 250, fwdCap: 110000, minOff: 3),
  5: _Params(bw: 3, bh: 3, boxes: 4, minPushes: 16, minChanges: 3, scoreLo: 56,
      pushHi: null, beam: 300, fwdCap: 130000, minOff: 3),
  6: _Params(bw: 3, bh: 3, boxes: 4, minPushes: 20, minChanges: 4, scoreLo: 66,
      pushHi: null, beam: 350, fwdCap: 150000, minOff: 4),
  7: _Params(bw: 3, bh: 3, boxes: 5, minPushes: 24, minChanges: 5, scoreLo: 76,
      pushHi: null, beam: 400, fwdCap: 170000, minOff: 4),
  8: _Params(bw: 4, bh: 3, boxes: 5, minPushes: 28, minChanges: 6, scoreLo: 86,
      pushHi: null, beam: 450, fwdCap: 190000, minOff: 5),
  9: _Params(bw: 4, bh: 3, boxes: 6, minPushes: 26, minChanges: 7, scoreLo: 92,
      pushHi: null, beam: 500, fwdCap: 210000, minOff: 5),
  10: _Params(bw: 4, bh: 3, boxes: 6, minPushes: 30, minChanges: 8, scoreLo: 100,
      pushHi: null, beam: 550, fwdCap: 240000, minOff: 6),
};

// ---------------------------------------------------------------- generator
/// Scattered goals, or (higher difficulty, half the time) a packed cluster --
/// packed goals force a solving ORDER, which is what makes levels hard.
Set<int>? _placeGoals(
    _Rng rng, Set<int> floors, List<int> cand, int n, int difficulty) {
  if (difficulty >= 5 && rng.random() < 0.5) {
    final seedc = rng.choice(cand);
    final cluster = <int>[seedc];
    final pool = <int>{seedc};
    final frontier = <int>[seedc];
    while (cluster.length < n && frontier.isNotEmpty) {
      final x = frontier.removeAt(rng.randrange(frontier.length));
      final ns = [for (final d in DIRS) x + d];
      rng.shuffle(ns);
      for (final y in ns) {
        if (floors.contains(y) && !pool.contains(y)) {
          pool.add(y);
          cluster.add(y);
          frontier.add(y);
          if (cluster.length == n) break;
        }
      }
    }
    if (cluster.length == n) return cluster.toSet();
    return null;
  }
  return rng.sample(cand, n).toSet();
}

/// Generate one guaranteed-solvable level at [difficulty] (1..10).
/// stats['meets_target'] tells whether the full difficulty band was hit
/// (otherwise the best level found is returned).
Level generate(
  int difficulty, {
  int? seed,
  int maxAttempts = 250,
  double? timeBudget,
  bool verbose = false,
}) {
  difficulty = math.max(1, math.min(10, difficulty));
  final P = PARAMS[difficulty]!;
  timeBudget ??= (10 + 5 * difficulty).toDouble();
  final rng = _Rng(seed);
  Level? best;
  final sw = Stopwatch()..start();

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (sw.elapsedMilliseconds / 1000.0 > timeBudget && best != null) break;
    final room = buildRoom(rng, P.bw, P.bh);
    final floors = room.floors;
    if (!roomOk(floors, room.H, room.W, P.boxes * 5)) continue;

    // goals must allow at least one pull-off direction
    final cand = <int>[];
    for (final c in floors) {
      for (final d in DIRS) {
        if (floors.contains(c + d) && floors.contains(c + d + d)) {
          cand.add(c);
          break;
        }
      }
    }
    if (cand.length < P.boxes) continue;

    final goals = _placeGoals(rng, floors, cand, P.boxes, difficulty);
    if (goals == null) continue;

    final nbrs = makeNbrs(floors);
    final dist = pullMetric(floors, goals);
    var alive = 0;
    for (final c in floors) {
      if (dist[c]! < INF) alive++;
    }
    if (alive < P.boxes * 3) continue;

    final cands = backwardScramble(
        rng, floors, nbrs, goals, dist, P.beam, 3 * P.minPushes);
    for (final cnd in cands.take(3)) {
      if (cnd.off < P.minOff) continue;
      final sol =
          solveForward(floors, nbrs, goals, dist, cnd.boxes, cnd.player, P.fwdCap);
      if (sol == null) continue;
      final m = solutionMetrics(dist, sol.actions, sol.expanded);
      final lurd = buildLurd(nbrs, cnd.boxes, cnd.player, sol.actions);
      final level = Level(
        floors: floors,
        goals: goals,
        boxes: cnd.boxes,
        player: cnd.player,
        solution: lurd,
        stats: {
          'difficulty': difficulty,
          'pushes': m.pushes,
          'moves': lurd.length,
          'box_changes': m.changes,
          'counter_pushes': m.counter,
          'nodes': sol.expanded,
          'score': m.score,
          'boxes': P.boxes,
          'attempt': attempt,
          'meets_target': false,
        },
      );
      if (!level.verify()) {
        throw StateError('internal error: solution failed replay');
      }
      if (best == null || m.score > (best.stats['score'] as double)) {
        best = level;
      }
      final ok = m.pushes >= P.minPushes &&
          m.changes >= P.minChanges &&
          m.score >= P.scoreLo &&
          (P.pushHi == null || m.pushes <= P.pushHi!);
      if (verbose) {
        stderr.writeln('  attempt $attempt: pushes=${m.pushes} '
            'changes=${m.changes} counter=${m.counter} '
            'nodes=${sol.expanded} score=${m.score} ${ok ? 'ACCEPT' : ''}');
      }
      if (ok) {
        level.stats['meets_target'] = true;
        level.stats['gen_seconds'] = _round1(sw.elapsedMilliseconds / 1000.0);
        return level;
      }
    }
  }
  if (best != null) {
    best.stats['gen_seconds'] = _round1(sw.elapsedMilliseconds / 1000.0);
    return best;
  }
  throw StateError(
      'could not generate a level; try a different seed or lower difficulty');
}

// ---------------------------------------------------------------- HTML pack
const String _HTML_PAGE = r'''<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Sokoban pack</title>
<style>
 body{background:#1b1e24;color:#e6e6e6;font-family:ui-monospace,monospace;
      display:flex;flex-direction:column;align-items:center;padding:20px}
 h1{font-size:18px} #info{margin:6px 0 14px;color:#9aa}
 #board{line-height:1}
 .row{display:flex}
 .cell{width:34px;height:34px;display:flex;align-items:center;
       justify-content:center;font-size:22px}
 .wall{background:#3a4150;border-radius:4px;box-shadow:inset 0 -3px 0 #2b303c}
 .floor{background:#232833}.goal{background:#232833}
 .goal::after{content:'';position:absolute;width:10px;height:10px;
       border-radius:50%;background:#c98f2d}
 .cell{position:relative}
 .box{width:26px;height:26px;background:#b06a3b;border-radius:5px;
      box-shadow:inset 0 -4px 0 #8a4f28;z-index:1}
 .box.on{background:#d9a441;box-shadow:inset 0 -4px 0 #a87d2c}
 .player{width:24px;height:24px;background:#5aa9e6;border-radius:50%;
      box-shadow:inset 0 -4px 0 #3d7fb3;z-index:1}
 #msg{height:24px;color:#7ee787;margin-top:10px}
 button{background:#2e3542;color:#e6e6e6;border:0;border-radius:6px;
      padding:6px 12px;margin:0 4px;cursor:pointer}
</style></head><body>
<h1>Sokoban pack</h1>
<div id="info"></div>
<div id="board"></div>
<div id="msg"></div>
<div style="margin-top:10px">
 <button onclick="prev()">&#8592; level</button>
 <button onclick="undo()">undo (U)</button>
 <button onclick="reset()">restart (R)</button>
 <button onclick="next()">level &#8594;</button>
</div>
<p style="color:#778">arrow keys / WASD to move</p>
<script>
const LEVELS = __LEVELS__;
let li=0, grid, player, hist;
function load(){
  const rows = LEVELS[li].map.split("\n");
  grid = rows.map(r=>r.split(""));
  hist=[];
  for(let r=0;r<grid.length;r++)for(let c=0;c<grid[r].length;c++){
    const ch=grid[r][c];
    if(ch=='@'||ch=='+'){player=[r,c];grid[r][c]= ch=='+'?'.':' ';}
  }
  draw();
  document.getElementById('info').textContent =
    'level '+(li+1)+'/'+LEVELS.length+'  ·  difficulty '+LEVELS[li].d+
    '  ·  optimal-ish pushes: '+LEVELS[li].pushes;
  document.getElementById('msg').textContent='';
}
function cellAt(r,c){return (grid[r]&&grid[r][c])||'#';}
function setCell(r,c,ch){grid[r][c]=ch;}
function draw(){
  const b=document.getElementById('board');b.innerHTML='';
  for(let r=0;r<grid.length;r++){
    const row=document.createElement('div');row.className='row';
    for(let c=0;c<grid[r].length;c++){
      const ch=cellAt(r,c);
      const cell=document.createElement('div');
      cell.className='cell '+(ch=='#'?'wall':(ch=='.'||ch=='*')?'goal':'floor');
      if(ch=='$'||ch=='*'){const bx=document.createElement('div');
        bx.className='box'+(ch=='*'?' on':'');cell.appendChild(bx);}
      if(player[0]==r&&player[1]==c){const pl=document.createElement('div');
        pl.className='player';cell.appendChild(pl);}
      row.appendChild(cell);
    }
    b.appendChild(row);
  }
}
function move(dr,dc){
  const [r,c]=player, nr=r+dr, nc=c+dc, ch=cellAt(nr,nc);
  if(ch=='#')return;
  const snap=JSON.stringify({g:grid,p:player});
  if(ch=='$'||ch=='*'){
    const br=nr+dr, bc=nc+dc, bch=cellAt(br,bc);
    if(bch=='#'||bch=='$'||bch=='*')return;
    setCell(br,bc, bch=='.'?'*':'$');
    setCell(nr,nc, ch=='*'?'.':' ');
  }
  hist.push(snap);
  player=[nr,nc];draw();check();
}
function check(){
  for(const row of grid)for(const ch of row)if(ch=='$')return;
  document.getElementById('msg').textContent='Solved!  → next level';
}
function undo(){if(!hist.length)return;const s=JSON.parse(hist.pop());
  grid=s.g;player=s.p;draw();}
function reset(){load();}
function next(){li=(li+1)%LEVELS.length;load();}
function prev(){li=(li+LEVELS.length-1)%LEVELS.length;load();}
document.addEventListener('keydown',e=>{
  const k=e.key.toLowerCase();
  if(k=='arrowup'||k=='w')move(-1,0);
  else if(k=='arrowdown'||k=='s')move(1,0);
  else if(k=='arrowleft'||k=='a')move(0,-1);
  else if(k=='arrowright'||k=='d')move(0,1);
  else if(k=='r')reset(); else if(k=='u')undo(); else return;
  e.preventDefault();
});
load();
</script></body></html>
''';

void exportHtml(List<Level> levels, String path) {
  final data = [
    for (final lv in levels)
      {
        'd': lv.stats['difficulty'],
        'pushes': lv.stats['pushes'],
        'map': lv.ascii(),
      }
  ];
  final html = _HTML_PAGE.replaceFirst('__LEVELS__', jsonEncode(data));
  File(path).writeAsStringSync(html);
}

// ---------------------------------------------------------------- CLI
void main(List<String> argv) {
  int difficulty = 5;
  int count = 1;
  int? seed;
  bool solution = false;
  bool verbose = false;
  String? htmlPath;
  String? demoPath;

  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    String next() => argv[++i];
    switch (a) {
      case '-d':
      case '--difficulty':
        difficulty = int.parse(next());
      case '-n':
      case '--count':
        count = int.parse(next());
      case '--seed':
        seed = int.parse(next());
      case '--solution':
        solution = true;
      case '-v':
      case '--verbose':
        verbose = true;
      case '--html':
        htmlPath = next();
      case '--demo':
        demoPath = next();
      case '-h':
      case '--help':
        _printUsage();
        return;
      default:
        if (a.startsWith('-')) {
          stderr.writeln('unknown option: $a');
          _printUsage();
          exit(2);
        }
    }
  }

  final rng = _Rng(seed);
  final levels = <Level>[];

  if (demoPath != null) {
    for (var d = 1; d <= 10; d++) {
      final lv = generate(d, seed: rng.randrange(1 << 30), verbose: verbose);
      levels.add(lv);
      final tgt = (lv.stats['meets_target'] as bool) ? '' : '  (best effort)';
      print('difficulty $d: pushes=${lv.stats['pushes']} '
          'changes=${lv.stats['box_changes']} score=${lv.stats['score']}$tgt');
    }
    exportHtml(levels, demoPath);
    print('\nplayable pack written to $demoPath');
    return;
  }

  for (var i = 0; i < count; i++) {
    final s = seed == null ? null : rng.randrange(1 << 30);
    final lv = generate(difficulty, seed: s, verbose: verbose);
    levels.add(lv);
    final st = lv.stats;
    final tgt = (st['meets_target'] as bool) ? '' : '  (best effort)';
    print('; difficulty ${st['difficulty']}  pushes ${st['pushes']}  '
        'moves ${st['moves']}  box-changes ${st['box_changes']}  '
        'counter ${st['counter_pushes']}  nodes ${st['nodes']}  '
        'score ${st['score']}$tgt');
    print(lv.ascii());
    if (solution) print('; solution: ${lv.solution}');
    print('');
  }
  if (htmlPath != null) {
    exportHtml(levels, htmlPath);
    print('playable pack written to $htmlPath');
  }
}

void _printUsage() {
  print('Sokoban level generator (Dart port)');
  print('Usage:');
  print('  dart run tool/sokoban_generator.dart [-d N] [-n N] [--seed N]');
  print('       [--solution] [--html FILE] [--demo FILE] [-v]');
  print('  -d, --difficulty N   difficulty 1..10 (default 5)');
  print('  -n, --count N        number of levels (default 1)');
  print('      --seed N         RNG seed (reproducible)');
  print('      --solution       print the LURD solution');
  print('      --html FILE      write levels into a playable HTML file');
  print('      --demo FILE      one level per difficulty 1..10 into HTML');
  print('  -v, --verbose        log attempt metrics to stderr');
}
