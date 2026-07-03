#!/usr/bin/env python3
"""
Sokoban level generator with parametrized difficulty (1..10).

Why the levels are guaranteed playable and non-trivial
------------------------------------------------------
1.  ROOM SYNTHESIS   - the map is assembled from 3x3 wall templates
    (Taylor & Parberry style) and validated: floor must be fully
    connected, floor density must be moderate, and no 3x4 open area is
    allowed (large open areas make puzzles trivial).

2.  REVERSE GENERATION - boxes are placed ON the goals (solved state)
    and then scrambled by *pulling* them backwards with a breadth-first
    search over pull-moves.  Every state reachable by pulls is solvable
    by construction (the reversed pull sequence is a valid push
    solution), so the generator can NEVER emit an unsolvable level.
    The deepest / most scrambled states become candidate starts.

3.  FORWARD A* SOLVER - each candidate start is solved with a
    push-optimizing A* (dead-square pruning + 2x2 freeze-deadlock
    pruning, player position normalized to its reachable region).
    The solver both re-proves solvability and yields the metrics used
    to measure difficulty.

4.  DIFFICULTY SCORING - a level is accepted only if its solution
    satisfies the difficulty band:
        pushes            length of the push solution
        box changes       how often the solver must switch between
                          boxes (interleaving = planning depth)
        counter pushes    pushes that move a box AWAY from the goals
                          (counter-intuitive detours)
        search effort     log2 of A* nodes expanded (a good proxy for
                          how hard the level is for humans too)
    score = pushes + 3*changes + 2*counter + 2*log2(nodes)

5.  GENERATE-AND-TEST - rooms/goal-sets are sampled until a level lands
    in the requested band (with a time budget; the best level found so
    far is returned if the budget runs out, flagged in stats).

Level format (standard Sokoban ASCII):
    #  wall        .  goal            $  box        @  player
    *  box on goal +  player on goal  (space) floor

CLI
---
    python sokoban_generator.py -d 6                  # one level, difficulty 6
    python sokoban_generator.py -d 9 -n 3 --seed 7    # three seeded levels
    python sokoban_generator.py -d 4 --solution       # also print the LURD solution
    python sokoban_generator.py --demo pack.html      # playable HTML with levels d=1..10

Library
-------
    from sokoban_generator import generate
    level = generate(difficulty=7, seed=123)
    print(level.ascii())
    print(level.stats)       # pushes, changes, counter, nodes, score...
    print(level.solution)    # LURD string (uppercase = push)
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
import random
import sys
import time
from collections import deque
from dataclasses import dataclass, field

# ---------------------------------------------------------------- geometry
UP, DOWN, LEFT, RIGHT = (-1, 0), (1, 0), (0, -1), (0, 1)
DIRS = (UP, DOWN, LEFT, RIGHT)
DIR_CHAR = {UP: "u", DOWN: "d", LEFT: "l", RIGHT: "r"}
CHAR_DIR = {"u": UP, "d": DOWN, "l": LEFT, "r": RIGHT}
INF = float("inf")


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


# ---------------------------------------------------------------- templates
# 3x3 building blocks ('#' wall, ' ' floor); rotations/mirrors are generated.
_BASE = [
    ("   ", "   ", "   "),
    ("#  ", "   ", "   "),
    ("## ", "   ", "   "),
    ("###", "   ", "   "),
    ("## ", "#  ", "   "),
    ("###", "#  ", "   "),
    ("#  ", "   ", "  #"),
    ("## ", "   ", " ##"),
    (" # ", "   ", "   "),
    ("   ", " # ", "   "),
    (" # ", " # ", "   "),
    ("# #", "   ", "   "),
]


def _rot(t):  # 90 degrees clockwise
    return tuple("".join(t[2 - c][r] for c in range(3)) for r in range(3))


def _mirror(t):
    return tuple(row[::-1] for row in t)


TEMPLATES = []
_seen = set()
for _t in _BASE:
    for _v in (_t, _mirror(_t)):
        _cur = _v
        for _ in range(4):
            _cur = _rot(_cur)
            if _cur not in _seen:
                _seen.add(_cur)
                TEMPLATES.append(_cur)


# ---------------------------------------------------------------- room build
def build_room(rng, bw, bh):
    """Assemble a (3*bw+2) x (3*bh+2) room from random templates."""
    H, W = bh * 3 + 2, bw * 3 + 2
    grid = [["#"] * W for _ in range(H)]
    for by in range(bh):
        for bx in range(bw):
            t = rng.choice(TEMPLATES)
            for i in range(3):
                for j in range(3):
                    grid[1 + 3 * by + i][1 + 3 * bx + j] = t[i][j]
    floors = frozenset(
        (r, c) for r in range(H) for c in range(W) if grid[r][c] == " "
    )
    return floors, H, W


def room_ok(floors, H, W, min_floor):
    if len(floors) < min_floor:
        return False
    interior = (H - 2) * (W - 2)
    if not (0.30 * interior <= len(floors) <= 0.82 * interior):
        return False
    # single connected component
    start = next(iter(floors))
    seen = {start}
    dq = deque([start])
    while dq:
        p = dq.popleft()
        for d in DIRS:
            q = add(p, d)
            if q in floors and q not in seen:
                seen.add(q)
                dq.append(q)
    if len(seen) != len(floors):
        return False
    # reject big open areas (they make puzzles trivial)
    for (r, c) in floors:
        if all((r + i, c + j) in floors for i in range(3) for j in range(4)):
            return False
        if all((r + i, c + j) in floors for i in range(4) for j in range(3)):
            return False
    return True


# ---------------------------------------------------------------- analysis
def make_nbrs(floors):
    """Precomputed floor adjacency -- the hot loops run on this."""
    return {c: tuple(n for n in (add(c, d) for d in DIRS) if n in floors)
            for c in floors}


def reachable(nbrs, boxes, p):
    """Cells the player can walk to from p, given box positions."""
    seen = {p}
    dq = deque([p])
    while dq:
        x = dq.popleft()
        for y in nbrs[x]:
            if y not in boxes and y not in seen:
                seen.add(y)
                dq.append(y)
    return seen


def pull_metric(floors, goals):
    """dist[c] = min pushes to bring a lone box from c to some goal.
    dist == INF  <=>  c is a dead square (a box there can never score)."""
    dist = {c: INF for c in floors}
    dq = deque()
    for g in goals:
        dist[g] = 0
        dq.append(g)
    while dq:
        x = dq.popleft()
        for d in DIRS:
            y = sub(x, d)  # a box on y pushed towards d lands on x
            if y in floors and sub(y, d) in floors and dist[y] == INF:
                dist[y] = dist[x] + 1
                dq.append(y)
    return dist


def freeze2x2(floors, boxes, moved_to, goals):
    """True if the push that put a box on `moved_to` created a 2x2 block of
    walls/boxes containing a box that is off-goal (a permanent deadlock)."""
    r, c = moved_to
    for dr in (-1, 0):
        for dc in (-1, 0):
            cells = [(r + dr + i, c + dc + j) for i in (0, 1) for j in (0, 1)]
            if all((x not in floors) or (x in boxes) for x in cells):
                if any(x in boxes and x not in goals for x in cells):
                    return True
    return False


# ---------------------------------------------------------------- backward
def backward_scramble(rng, floors, nbrs, goals, dist, beam_width, max_depth, keep=8):
    """Beam search over PULL moves starting from the solved state.

    Every state reachable by pulls is forward-solvable by construction.
    The beam is driven towards states whose boxes are FAR (in push-metric)
    from the goals, i.e. towards genuinely deep scrambles.

    Returns candidate start states, most-scrambled first:
        [(boxes, player_cell, depth, boxes_off_goals), ...]"""

    def spread(boxes):
        return sum(dist[b] for b in boxes)      # all finite by construction

    boxes0 = frozenset(goals)
    remaining = set(floors - boxes0)
    if not remaining:
        return []
    frontier = []                                # (boxes, player_cell)
    while remaining:                             # one root per player region
        p = remaining.pop()
        reg = reachable(nbrs, boxes0, p)
        remaining -= reg
        frontier.append((boxes0, min(reg)))
    visited = set()
    pool = []                                    # global candidate pool
    for depth in range(1, max_depth + 1):
        nxt = {}
        for boxes, pcell in frontier:
            reg = reachable(nbrs, boxes, pcell)
            key = (boxes, min(reg))
            if key in visited:
                continue
            visited.add(key)
            for b in boxes:
                for d in DIRS:
                    p1 = add(b, d)   # player stands here, box is pulled here
                    p2 = add(p1, d)  # player steps back here
                    if p1 in reg and p2 in floors and p2 not in boxes:
                        nb = boxes - {b} | {p1}
                        nxt.setdefault((nb, p2), None)
        if not nxt:
            break
        scored = []
        for (nb, p2) in nxt:
            off = sum(1 for b in nb if b not in goals)
            s = 3 * spread(nb) + 4 * off + rng.random()
            scored.append((s, nb, p2, off))
        scored.sort(key=lambda t: -t[0])
        frontier = [(nb, p2) for _, nb, p2, _ in scored[:beam_width]]
        for s, nb, p2, off in scored[: max(4, keep)]:
            pool.append((s + depth, depth, off, nb, p2))
        if len(pool) > 400:
            pool.sort(key=lambda t: -t[0])
            del pool[keep * 8:]
    pool.sort(key=lambda t: -t[0])
    out, seen_boxes = [], set()
    for _, depth, off, boxes, pcell in pool:
        if boxes in seen_boxes:
            continue
        seen_boxes.add(boxes)
        out.append((boxes, pcell, depth, off))
        if len(out) >= keep:
            break
    return out


# ---------------------------------------------------------------- forward A*
def solve_forward(floors, nbrs, goals, dist, boxes0, player0, node_cap):
    """Push-count A* with dead-square + freeze pruning.
    Returns dict(actions=[(from,to)...], expanded=N) or None."""
    h0 = 0
    for b in boxes0:
        if dist[b] == INF:
            return None
        h0 += dist[b]
    states = [(boxes0, player0, -1, None)]   # (boxes, player, parent, action)
    pq = [(h0, h0, 0, 0)]          # (f, h, g, idx): low-h tiebreak
    gbest = {}
    closed = set()
    expanded = 0
    while pq:
        f, h, g, idx = heapq.heappop(pq)
        boxes, player, _, _ = states[idx]
        reach = reachable(nbrs, boxes, player)
        key = (boxes, min(reach))
        if key in closed:
            continue
        closed.add(key)
        expanded += 1
        if expanded > node_cap:
            return None
        if h == 0 and boxes <= goals:
            actions = []
            i = idx
            while i > 0:
                actions.append(states[i][3])
                i = states[i][2]
            actions.reverse()
            return {"actions": actions, "expanded": expanded}
        for b in boxes:
            for d in DIRS:
                behind, tgt = sub(b, d), add(b, d)
                if behind not in reach:
                    continue
                if tgt not in floors or tgt in boxes:
                    continue
                dt = dist[tgt]
                if dt == INF:                   # dead square
                    continue
                nb = boxes - {b} | {tgt}
                if freeze2x2(floors, nb, tgt, goals):
                    continue
                ng = g + 1
                pkey = (nb, b)
                if gbest.get(pkey, 1 << 30) <= ng:
                    continue
                gbest[pkey] = ng
                nh = h - dist[b] + dt           # incremental heuristic
                states.append((nb, b, idx, (b, tgt)))
                heapq.heappush(pq, (ng + nh, nh, ng, len(states) - 1))
    return None


def solution_metrics(dist, actions, expanded):
    pushes = len(actions)
    changes = counter = 0
    prev_to = None
    for frm, to in actions:
        if prev_to is not None and frm != prev_to:
            changes += 1
        if dist[to] > dist[frm]:
            counter += 1
        prev_to = to
    score = pushes + 3.0 * changes + 2.0 * counter + 2.0 * math.log2(expanded + 1)
    return pushes, changes, counter, round(score, 1)


# ---------------------------------------------------------------- LURD
def _bfs_path(nbrs, boxes, src, dst):
    if src == dst:
        return []
    prev = {src: None}
    dq = deque([src])
    while dq:
        x = dq.popleft()
        for y in nbrs[x]:
            d = sub(y, x)
            if y not in boxes and y not in prev:
                prev[y] = (x, d)
                if y == dst:
                    path = []
                    while prev[y] is not None:
                        x, d = prev[y]
                        path.append(DIR_CHAR[d])
                        y = x
                    return path[::-1]
                dq.append(y)
    raise RuntimeError("no player path (internal error)")


def build_lurd(nbrs, boxes0, player0, actions):
    boxes = set(boxes0)
    p = player0
    out = []
    for frm, to in actions:
        d = sub(to, frm)
        stand = sub(frm, d)
        out += _bfs_path(nbrs, boxes, p, stand)
        out.append(DIR_CHAR[d].upper())
        boxes.remove(frm)
        boxes.add(to)
        p = frm
    return "".join(out)


# ---------------------------------------------------------------- level obj
@dataclass
class Level:
    floors: frozenset
    goals: frozenset
    boxes: frozenset
    player: tuple
    solution: str
    stats: dict = field(default_factory=dict)

    def ascii(self):
        rows = [r for r, _ in self.floors]
        cols = [c for _, c in self.floors]
        r0, r1 = min(rows) - 1, max(rows) + 1
        c0, c1 = min(cols) - 1, max(cols) + 1
        lines = []
        for r in range(r0, r1 + 1):
            line = []
            for c in range(c0, c1 + 1):
                p = (r, c)
                if p in self.floors:
                    if p == self.player:
                        line.append("+" if p in self.goals else "@")
                    elif p in self.boxes:
                        line.append("*" if p in self.goals else "$")
                    elif p in self.goals:
                        line.append(".")
                    else:
                        line.append(" ")
                else:
                    near = any(
                        (r + i, c + j) in self.floors
                        for i in (-1, 0, 1)
                        for j in (-1, 0, 1)
                    )
                    line.append("#" if near else " ")
            lines.append("".join(line).rstrip())
        return "\n".join(lines)

    def verify(self):
        """Replay self.solution; True iff it solves the level."""
        boxes = set(self.boxes)
        p = self.player
        for ch in self.solution:
            d = CHAR_DIR[ch.lower()]
            q = add(p, d)
            if q in boxes:
                q2 = add(q, d)
                if q2 not in self.floors or q2 in boxes:
                    return False
                boxes.remove(q)
                boxes.add(q2)
                p = q
            elif q in self.floors:
                p = q
            else:
                return False
        return boxes == set(self.goals)


# ---------------------------------------------------------------- difficulty
# bw,bh: room size in 3x3 blocks | boxes | acceptance band
PARAMS = {
    1:  dict(bw=2, bh=2, boxes=2, min_pushes=5,  min_changes=0, score_lo=20,
             push_hi=14,   beam=120, fwd_cap=60000,  min_off=1),
    2:  dict(bw=2, bh=2, boxes=2, min_pushes=8,  min_changes=0, score_lo=27,
             push_hi=20,   beam=150, fwd_cap=80000,  min_off=2),
    3:  dict(bw=3, bh=2, boxes=3, min_pushes=10, min_changes=1, score_lo=36,
             push_hi=26,   beam=200, fwd_cap=90000,  min_off=2),
    4:  dict(bw=3, bh=2, boxes=3, min_pushes=14, min_changes=2, score_lo=46,
             push_hi=None, beam=250, fwd_cap=110000, min_off=3),
    5:  dict(bw=3, bh=3, boxes=4, min_pushes=16, min_changes=3, score_lo=56,
             push_hi=None, beam=300, fwd_cap=130000, min_off=3),
    6:  dict(bw=3, bh=3, boxes=4, min_pushes=20, min_changes=4, score_lo=66,
             push_hi=None, beam=350, fwd_cap=150000, min_off=4),
    7:  dict(bw=3, bh=3, boxes=5, min_pushes=24, min_changes=5, score_lo=76,
             push_hi=None, beam=400, fwd_cap=170000, min_off=4),
    8:  dict(bw=4, bh=3, boxes=5, min_pushes=28, min_changes=6, score_lo=86,
             push_hi=None, beam=450, fwd_cap=190000, min_off=5),
    9:  dict(bw=4, bh=3, boxes=6, min_pushes=26, min_changes=7, score_lo=92,
             push_hi=None, beam=500, fwd_cap=210000, min_off=5),
    10: dict(bw=4, bh=3, boxes=6, min_pushes=30, min_changes=8, score_lo=100,
             push_hi=None, beam=550, fwd_cap=240000, min_off=6),
}


# ---------------------------------------------------------------- generator
def _place_goals(rng, floors, cand, n, difficulty):
    """Scattered goals, or (at higher difficulty, half the time) a packed
    goal cluster -- packed goals force a solving ORDER, which is what makes
    classic Sokoban levels hard."""
    if difficulty >= 5 and rng.random() < 0.5:
        seedc = rng.choice(cand)
        cluster = [seedc]
        pool = {seedc}
        frontier = [seedc]
        while len(cluster) < n and frontier:
            x = frontier.pop(rng.randrange(len(frontier)))
            nbrs = [add(x, d) for d in DIRS]
            rng.shuffle(nbrs)
            for y in nbrs:
                if y in floors and y not in pool:
                    pool.add(y)
                    cluster.append(y)
                    frontier.append(y)
                    if len(cluster) == n:
                        break
        if len(cluster) == n:
            return frozenset(cluster)
        return None
    return frozenset(rng.sample(cand, n))


def generate(difficulty, seed=None, max_attempts=250, time_budget=None,
             verbose=False):
    """Generate one guaranteed-solvable level at the given difficulty (1..10).

    Returns a Level.  level.stats['meets_target'] tells whether the full
    difficulty band was hit (otherwise the best level found is returned)."""
    difficulty = max(1, min(10, int(difficulty)))
    P = PARAMS[difficulty]
    if time_budget is None:
        time_budget = 10 + 5 * difficulty
    rng = random.Random(seed)
    best = None
    t0 = time.time()

    for attempt in range(1, max_attempts + 1):
        if time.time() - t0 > time_budget and best is not None:
            break
        floors, H, W = build_room(rng, P["bw"], P["bh"])
        if not room_ok(floors, H, W, min_floor=P["boxes"] * 5):
            continue
        # goals must allow at least one pull-off direction
        cand = [
            c for c in floors
            if any(add(c, d) in floors and add(add(c, d), d) in floors
                   for d in DIRS)
        ]
        if len(cand) < P["boxes"]:
            continue
        goals = _place_goals(rng, floors, cand, P["boxes"], difficulty)
        if goals is None:
            continue
        nbrs = make_nbrs(floors)
        dist = pull_metric(floors, goals)
        alive = sum(1 for c in floors if dist[c] < INF)
        if alive < P["boxes"] * 3:
            continue

        cands = backward_scramble(
            rng, floors, nbrs, goals, dist,
            beam_width=P["beam"], max_depth=3 * P["min_pushes"])
        for boxes0, player0, depth, off in cands[:3]:
            if off < P["min_off"]:
                continue
            sol = solve_forward(floors, nbrs, goals, dist, boxes0,
                                player0, P["fwd_cap"])
            if sol is None:
                continue
            pushes, changes, counter, score = solution_metrics(
                dist, sol["actions"], sol["expanded"])
            lurd = build_lurd(nbrs, boxes0, player0, sol["actions"])
            level = Level(
                floors=floors, goals=goals, boxes=boxes0, player=player0,
                solution=lurd,
                stats=dict(difficulty=difficulty, pushes=pushes,
                           moves=len(lurd), box_changes=changes,
                           counter_pushes=counter, nodes=sol["expanded"],
                           score=score, boxes=P["boxes"],
                           attempt=attempt, meets_target=False),
            )
            assert level.verify(), "internal error: solution failed replay"
            if best is None or score > best.stats["score"]:
                best = level
            ok = (pushes >= P["min_pushes"]
                  and changes >= P["min_changes"]
                  and score >= P["score_lo"]
                  and (P["push_hi"] is None or pushes <= P["push_hi"]))
            if verbose:
                print(f"  attempt {attempt}: pushes={pushes} changes={changes}"
                      f" counter={counter} nodes={sol['expanded']}"
                      f" score={score} {'ACCEPT' if ok else ''}",
                      file=sys.stderr)
            if ok:
                level.stats["meets_target"] = True
                level.stats["gen_seconds"] = round(time.time() - t0, 2)
                return level
    if best is not None:
        best.stats["gen_seconds"] = round(time.time() - t0, 2)
        return best
    raise RuntimeError(
        "could not generate a level; try a different seed or lower difficulty")


# ---------------------------------------------------------------- HTML pack
_HTML_PAGE = """<!DOCTYPE html>
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
  const rows = LEVELS[li].map.split("\\n");
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
  document.getElementById('msg').textContent='Solved!  \\u2192 next level';
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
"""


def export_html(levels, path):
    data = [
        {"d": lv.stats["difficulty"], "pushes": lv.stats["pushes"],
         "map": lv.ascii()}
        for lv in levels
    ]
    html = _HTML_PAGE.replace("__LEVELS__", json.dumps(data))
    with open(path, "w") as f:
        f.write(html)


# ---------------------------------------------------------------- CLI
def main():
    ap = argparse.ArgumentParser(description="Sokoban level generator")
    ap.add_argument("-d", "--difficulty", type=int, default=5,
                    help="difficulty 1..10 (default 5)")
    ap.add_argument("-n", "--count", type=int, default=1,
                    help="number of levels")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--solution", action="store_true",
                    help="print the LURD solution")
    ap.add_argument("--html", metavar="FILE",
                    help="also write the levels into a playable HTML file")
    ap.add_argument("--demo", metavar="FILE",
                    help="generate one level per difficulty 1..10 into HTML")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    levels = []
    if args.demo:
        for d in range(1, 11):
            lv = generate(d, seed=rng.randrange(1 << 30), verbose=args.verbose)
            levels.append(lv)
            print(f"difficulty {d}: pushes={lv.stats['pushes']} "
                  f"changes={lv.stats['box_changes']} score={lv.stats['score']}"
                  f"{'' if lv.stats['meets_target'] else '  (best effort)'}")
        export_html(levels, args.demo)
        print(f"\nplayable pack written to {args.demo}")
        return

    for i in range(args.count):
        seed = None if args.seed is None else rng.randrange(1 << 30)
        lv = generate(args.difficulty, seed=seed, verbose=args.verbose)
        levels.append(lv)
        s = lv.stats
        print(f"; difficulty {s['difficulty']}  pushes {s['pushes']}  "
              f"moves {s['moves']}  box-changes {s['box_changes']}  "
              f"counter {s['counter_pushes']}  nodes {s['nodes']}  "
              f"score {s['score']}"
              f"{'' if s['meets_target'] else '  (best effort)'}")
        print(lv.ascii())
        if args.solution:
            print(f"; solution: {lv.solution}")
        print()
    if args.html:
        export_html(levels, args.html)
        print(f"playable pack written to {args.html}")


if __name__ == "__main__":
    main()
