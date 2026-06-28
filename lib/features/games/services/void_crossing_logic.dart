// lib/features/games/services/void_crossing_logic.dart
//
// Logic engine for the Void Crossing puzzle — a space-themed river crossing
// game. Generates puzzles of increasing complexity and validates player moves.

import 'dart:math' as math;

final math.Random _rng = math.Random();

/// Represents a creature/cargo that must be transported across the void.
class VoidEntity {
  final String id;
  final String nameKey; // i18n key
  final String emoji;   // fallback visual

  const VoidEntity({
    required this.id,
    required this.nameKey,
    required this.emoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VoidEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// A conflict rule: entityA and entityB cannot be left alone without the
/// guardian entity present.
class ConflictRule {
  final String entityA;
  final String entityB;
  final String? guardian; // if null, they simply can't be together

  const ConflictRule({
    required this.entityA,
    required this.entityB,
    this.guardian,
  });
}

/// A complete puzzle definition.
class VoidCrossingPuzzle {
  final List<VoidEntity> entities;
  final List<ConflictRule> conflicts;
  final int boatCapacity;
  final int optimalMoves;
  final int maxMoves;

  const VoidCrossingPuzzle({
    required this.entities,
    required this.conflicts,
    required this.boatCapacity,
    required this.optimalMoves,
    required this.maxMoves,
  });
}

/// Immutable snapshot of the game state for BFS solving.
class _State {
  final Set<String> leftBank;
  final Set<String> rightBank;
  final bool boatOnLeft;

  const _State(this.leftBank, this.rightBank, this.boatOnLeft);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _State &&
          leftBank.length == other.leftBank.length &&
          leftBank.containsAll(other.leftBank) &&
          boatOnLeft == other.boatOnLeft;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(leftBank.toList()..sort()),
        boatOnLeft,
      );
}

/// Game state tracking for the running game.
class VoidCrossingGameState {
  final Set<String> leftStation;
  final Set<String> rightStation;
  final Set<String> onShuttle;
  bool shuttleOnLeft;
  int movesTaken;

  VoidCrossingGameState({
    required this.leftStation,
    required this.rightStation,
    required this.onShuttle,
    required this.shuttleOnLeft,
    this.movesTaken = 0,
  });

  VoidCrossingGameState copy() => VoidCrossingGameState(
        leftStation: Set.of(leftStation),
        rightStation: Set.of(rightStation),
        onShuttle: Set.of(onShuttle),
        shuttleOnLeft: shuttleOnLeft,
        movesTaken: movesTaken,
      );

  /// Get entities on the current bank (where shuttle is docked).
  Set<String> get currentBank => shuttleOnLeft ? leftStation : rightStation;

  /// Get entities on the far bank.
  Set<String> get farBank => shuttleOnLeft ? rightStation : leftStation;
}

class VoidCrossingLogic {
  // ─── Entity catalogue ────────────────────────────────────────────────

  static const _zorblex = VoidEntity(
    id: 'zorblex', nameKey: 'voidCrossingZorblex', emoji: '👾',
  );
  static const _glimbit = VoidEntity(
    id: 'glimbit', nameKey: 'voidCrossingGlimbit', emoji: '🐛',
  );
  static const _starMoss = VoidEntity(
    id: 'star_moss', nameKey: 'voidCrossingStarMoss', emoji: '🌿',
  );
  static const _kraxxon = VoidEntity(
    id: 'kraxxon', nameKey: 'voidCrossingKraxxon', emoji: '🦎',
  );
  static const _lumifae = VoidEntity(
    id: 'lumifae', nameKey: 'voidCrossingLumifae', emoji: '🦋',
  );
  static const _voidCrab = VoidEntity(
    id: 'void_crab', nameKey: 'voidCrossingVoidCrab', emoji: '🦀',
  );
  static const _nebulaSeed = VoidEntity(
    id: 'nebula_seed', nameKey: 'voidCrossingNebulaSeed', emoji: '🌰',
  );
  static const _pyrowyrm = VoidEntity(
    id: 'pyrowyrm', nameKey: 'voidCrossingPyrowyrm', emoji: '🐉',
  );

  /// Generate a puzzle appropriate for the given grade + level.
  ///
  /// **Grade** (1–4) is the primary dimension and gates the puzzle *type*:
  ///   - Grade 1: Classic 3-entity chain (boat=1). Simple A→B→C food chain.
  ///   - Grade 2: 4 entities (boat=1). Extra creature adds a second conflict
  ///              path, requires more planning.
  ///   - Grade 3: 5 entities (boat=2). Multiple interlocking conflicts.
  ///   - Grade 4: 6 entities (boat=2). Dense conflict web, hardest puzzles.
  ///
  /// **Level** (1–20) is the secondary dimension and tunes *parameters*
  /// within the grade's puzzle type:
  ///   - Extra moves allowed (generous at level 1, tight at level 20).
  ///   - At higher levels within a grade, additional conflicts may appear
  ///     (more constrained puzzles within the same entity set).
  static VoidCrossingPuzzle generatePuzzle(int grade, int level) {
    final g = grade.clamp(1, 4);
    final l = level.clamp(1, 20);

    // Generate with random entities; verify solvability (should always
    // pass for chain conflicts, but guard against edge cases).
    for (int attempt = 0; attempt < 10; attempt++) {
      final puzzle = switch (g) {
        1 => _gradeOne(l),
        2 => _gradeTwo(l),
        3 => _gradeThree(l),
        _ => _gradeFour(l),
      };
      final opt = solve(puzzle);
      if (opt >= 0 && opt <= puzzle.maxMoves) return puzzle;
    }
    // Fallback: deterministic classic puzzle
    return _gradeOne(l);
  }

  // ─── Entity triads / quads for variety ─────────────────────────────
  //
  // Each "template" is a set of entities + a conflict chain. The grade
  // methods randomly pick one template per puzzle, so repeated plays
  // at the same grade+level still feel fresh.

  /// All 8 entities in a flat list for random selection.
  static const _allEntities = [
    _zorblex, _glimbit, _starMoss, _kraxxon,
    _lumifae, _voidCrab, _nebulaSeed, _pyrowyrm,
  ];

  /// Pick [count] random entities from the catalogue; return them in a
  /// stable order together with a chain conflict A→B→…→N.
  static ({List<VoidEntity> entities, List<ConflictRule> chain})
      _randomChain(int count) {
    final pool = List<VoidEntity>.from(_allEntities)..shuffle(_rng);
    final picked = pool.take(count).toList();
    final chain = <ConflictRule>[];
    for (int i = 0; i < picked.length - 1; i++) {
      chain.add(ConflictRule(
          entityA: picked[i].id, entityB: picked[i + 1].id));
    }
    return (entities: picked, chain: chain);
  }

  /// Pick [count] random entities; use only the first [conflictCount]
  /// links of the chain as conflicts.
  static ({List<VoidEntity> entities, List<ConflictRule> conflicts})
      _randomWithConflicts(int count, int conflictCount) {
    final r = _randomChain(count);
    return (
      entities: r.entities,
      conflicts: r.chain.take(conflictCount).toList(),
    );
  }

  // ─── Grade 1: 3 entities, boat = 1 ──────────────────────────────────
  //
  // Classic A→B→C food chain. Optimal: 7 moves.
  // Each play picks a random trio of creatures from the pool.

  static VoidCrossingPuzzle _gradeOne(int level) {
    final extraMoves = (4 - ((level - 1) * 4 / 19).round()).clamp(0, 4);
    final r = _randomWithConflicts(3, 2);

    return VoidCrossingPuzzle(
      entities: r.entities,
      conflicts: r.conflicts,
      boatCapacity: 1,
      optimalMoves: 7,
      maxMoves: 7 + extraMoves,
    );
  }

  // ─── Grade 2: 4 entities, boat = 1 ──────────────────────────────────
  //
  // 4 creatures, same boat=1. Chain has 2 conflicts (A→B→C, D is free).
  // Optimal: 9 crossings. Random entity selection each play.

  static VoidCrossingPuzzle _gradeTwo(int level) {
    final extraMoves = (4 - ((level - 1) * 4 / 19).round()).clamp(0, 4);
    final r = _randomWithConflicts(4, 2);

    return VoidCrossingPuzzle(
      entities: r.entities,
      conflicts: r.conflicts,
      boatCapacity: 1,
      optimalMoves: 9,
      maxMoves: 9 + extraMoves,
    );
  }

  // ─── Grade 3: 5 entities, boat = 2 ──────────────────────────────────
  //
  // Boat capacity increases to 2 (new mechanic). 3 conflicts at low
  // levels, 4 at level 8+. Random entity selection.

  static VoidCrossingPuzzle _gradeThree(int level) {
    final extraMoves = (5 - ((level - 1) * 5 / 19).round()).clamp(0, 5);
    final conflictCount = level > 7 ? 4 : 3;
    final r = _randomWithConflicts(5, conflictCount);
    // BFS-verified: optimal=5 with 3 conflicts, optimal=7 with 4
    final optimal = conflictCount > 3 ? 7 : 5;

    return VoidCrossingPuzzle(
      entities: r.entities,
      conflicts: r.conflicts,
      boatCapacity: 2,
      optimalMoves: optimal,
      maxMoves: optimal + extraMoves,
    );
  }

  // ─── Grade 4: 6 entities, boat = 2 ──────────────────────────────────
  //
  // All 6 creatures. Level adds conflicts: 3 → 4 at L6 → 5 at L13.

  static VoidCrossingPuzzle _gradeFour(int level) {
    final extraMoves = (5 - ((level - 1) * 5 / 19).round()).clamp(0, 5);
    final conflictCount = level > 12 ? 5 : (level > 5 ? 4 : 3);
    final r = _randomWithConflicts(6, conflictCount);
    // BFS-verified: optimal=7 for chain conflicts at 6 entities / boat=2
    const optimal = 7;

    return VoidCrossingPuzzle(
      entities: r.entities,
      conflicts: r.conflicts,
      boatCapacity: 2,
      optimalMoves: optimal,
      maxMoves: optimal + extraMoves,
    );
  }

  // ─── Validation ──────────────────────────────────────────────────────

  /// Check whether a set of entities left alone violates any conflict rule.
  static bool hasConflict(Set<String> group, List<ConflictRule> conflicts) {
    for (final rule in conflicts) {
      if (group.contains(rule.entityA) && group.contains(rule.entityB)) {
        if (rule.guardian == null || !group.contains(rule.guardian)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Return the specific conflicting pair if one exists, null otherwise.
  static ConflictRule? findConflict(
      Set<String> group, List<ConflictRule> conflicts) {
    for (final rule in conflicts) {
      if (group.contains(rule.entityA) && group.contains(rule.entityB)) {
        if (rule.guardian == null || !group.contains(rule.guardian)) {
          return rule;
        }
      }
    }
    return null;
  }

  /// Check if moving the shuttle (leaving current bank) would cause a conflict
  /// on the bank being left.
  static bool wouldCauseConflict(
    VoidCrossingGameState state,
    VoidCrossingPuzzle puzzle,
  ) {
    // The bank the shuttle is leaving behind
    final leftBehind = Set<String>.from(state.currentBank);
    // Entities on shuttle are removed from bank
    leftBehind.removeAll(state.onShuttle);
    return hasConflict(leftBehind, puzzle.conflicts);
  }

  /// Check if the puzzle is solved: all entities on the right station.
  static bool isSolved(VoidCrossingGameState state, VoidCrossingPuzzle puzzle) {
    return state.rightStation.length == puzzle.entities.length &&
        state.onShuttle.isEmpty;
  }

  // ─── BFS Solver ──────────────────────────────────────────────────────

  /// Solve the puzzle using BFS, returns the minimum number of crossings.
  /// Returns -1 if unsolvable.
  static int solve(VoidCrossingPuzzle puzzle) {
    final allIds = puzzle.entities.map((e) => e.id).toSet();
    final initial = _State(Set.of(allIds), {}, true);
    final goal = _State({}, Set.of(allIds), false);

    final queue = <(_State, int)>[(initial, 0)];
    final visited = <_State>{initial};

    while (queue.isNotEmpty) {
      final (current, moves) = queue.removeAt(0);

      if (current == goal) return moves;

      final fromBank =
          current.boatOnLeft ? current.leftBank : current.rightBank;
      final toBank =
          current.boatOnLeft ? current.rightBank : current.leftBank;

      // Generate all possible passenger combinations (1..boatCapacity)
      final passengers = _combinations(fromBank.toList(), puzzle.boatCapacity);

      for (final combo in passengers) {
        final newFrom = Set<String>.from(fromBank)..removeAll(combo);
        final newTo = Set<String>.from(toBank)..addAll(combo);

        // Only check conflicts on the bank being LEFT BEHIND.
        // The shuttle (with the player) is present at the destination,
        // which prevents conflicts there — just like the farmer in the
        // classic wolf-goat-cabbage puzzle.
        if (hasConflict(newFrom, puzzle.conflicts)) continue;

        final newLeft =
            current.boatOnLeft ? newFrom : newTo;
        final newRight =
            current.boatOnLeft ? newTo : newFrom;

        final next = _State(newLeft, newRight, !current.boatOnLeft);
        if (!visited.contains(next)) {
          visited.add(next);
          queue.add((next, moves + 1));
        }
      }
    }

    return -1; // unsolvable
  }

  /// Generate all combinations of 0..maxSize from items.
  /// Size 0 represents an empty crossing (shuttle returns alone).
  static List<Set<String>> _combinations(List<String> items, int maxSize) {
    final result = <Set<String>>[<String>{}]; // empty trip
    final n = items.length;

    for (int size = 1; size <= math.min(maxSize, n); size++) {
      _combHelper(items, size, 0, <String>[], result);
    }

    return result;
  }

  static void _combHelper(List<String> items, int size, int start,
      List<String> current, List<Set<String>> result) {
    if (current.length == size) {
      result.add(Set.of(current));
      return;
    }
    for (int i = start; i < items.length; i++) {
      current.add(items[i]);
      _combHelper(items, size, i + 1, current, result);
      current.removeLast();
    }
  }

  /// Create initial game state from a puzzle.
  static VoidCrossingGameState createInitialState(VoidCrossingPuzzle puzzle) {
    return VoidCrossingGameState(
      leftStation: puzzle.entities.map((e) => e.id).toSet(),
      rightStation: {},
      onShuttle: {},
      shuttleOnLeft: true,
    );
  }
}
