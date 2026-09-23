// lib/features/games/services/ion_chain_logic.dart
//
// Sequence builder with adjacency constraints (CSP-based).
// Place colored ions on a rail obeying rules like:
// - no two of same color adjacent
// - specific color must neighbor another specific color
// Generates valid chains, removes some for player to fill.

import 'dart:math' as math;

enum IonType { red, blue, green, yellow, purple }

/// What a rule forbids. The screen renders each kind as a little picture --
/// the two shapes it talks about, with a "no" mark between them -- so the
/// rule does not depend on the player matching a word like "Raute" to a shape
/// they have only ever seen drawn.
enum IonRuleKind {
  /// Two beads of type [IonRule.a] may not sit next to each other.
  noSelfPair,

  /// A bead of type [IonRule.a] may not sit next to one of type [IonRule.b].
  noMixedPair,

  /// No two beads of the *same* type may sit next to each other, whichever
  /// type that is. Only the fallback generator produces this.
  noRepeatAtAll,
}

class IonRule {
  /// Which of the three forbidden-neighbour shapes this rule is.
  final IonRuleKind kind;

  /// The first shape the rule names. Null only for [IonRuleKind.noRepeatAtAll],
  /// which names no shape at all.
  final IonType? a;

  /// The second shape, set only for [IonRuleKind.noMixedPair].
  final IonType? b;

  final bool Function(IonType?, IonType?) check;

  IonRule({
    required this.kind,
    this.a,
    this.b,
    required this.check,
  });
}

class IonChainPuzzle {
  final int chainLength;
  final List<IonType?> chain; // null = empty slot for player
  final List<IonType> solution;
  final List<IonType> availableIons; // ions the player can place
  final List<IonRule> rules;
  final List<IonType> ionTypes; // which types are in use

  IonChainPuzzle({
    required this.chainLength,
    required this.chain,
    required this.solution,
    required this.availableIons,
    required this.rules,
    required this.ionTypes,
  });

  /// Validate if a completed circular chain satisfies all rules.
  /// Checks all adjacent pairs INCLUDING last-to-first (bracelet/ring).
  /// Skips pairs where either element is null (unfilled slots).
  static bool validateChain(List<IonType?> chain, List<IonRule> rules) {
    if (chain.length <= 1) return true;
    for (int i = 0; i < chain.length; i++) {
      final next = (i + 1) % chain.length;
      for (final rule in rules) {
        if (!rule.check(chain[i], chain[next])) return false;
      }
    }
    return true;
  }

  /// Whether the still-empty slots of [chain] can be filled from [tray]
  /// without breaking a rule.
  ///
  /// The screen uses this to refuse a move that would strand the player: every
  /// placement it accepts leaves the ring completable, so a legal move can
  /// never dead-end the puzzle. The search is tiny -- a handful of blanks and
  /// at most one bead per blank -- and duplicate bead types are tried once.
  static bool isCompletable(
    List<IonType?> chain,
    List<IonType> tray,
    List<IonRule> rules,
  ) {
    final blanks = <int>[];
    for (int i = 0; i < chain.length; i++) {
      if (chain[i] == null) blanks.add(i);
    }
    if (blanks.length != tray.length) return false;

    final working = List<IonType?>.from(chain);
    final remaining = List<IonType>.from(tray);

    bool fill(int blankIndex) {
      if (blankIndex == blanks.length) {
        return validateChain(working, rules);
      }
      final slot = blanks[blankIndex];
      final tried = <IonType>{};
      for (int i = 0; i < remaining.length; i++) {
        final bead = remaining[i];
        if (!tried.add(bead)) continue; // same type, same outcome

        working[slot] = bead;
        // Reject early on a neighbour that is already placed.
        if (_slotFits(working, slot, rules)) {
          remaining.removeAt(i);
          final solved = fill(blankIndex + 1);
          remaining.insert(i, bead);
          if (solved) return true;
        }
        working[slot] = null;
      }
      return false;
    }

    return fill(0);
  }

  /// Whether the bead now in [slot] agrees with its already-placed neighbours.
  /// Slots yet to be filled are not a conflict -- they are simply unknown.
  static bool _slotFits(List<IonType?> chain, int slot, List<IonRule> rules) {
    final bead = chain[slot];
    final prev = (slot - 1 + chain.length) % chain.length;
    final next = (slot + 1) % chain.length;
    for (final rule in rules) {
      if (chain[prev] != null && !rule.check(chain[prev], bead)) return false;
      if (chain[next] != null && !rule.check(bead, chain[next])) return false;
    }
    return true;
  }

  static final List<IonRule Function(IonType, IonType)> _ruleFactories = [
    // Rule: no two of type A adjacent
    (IonType a, IonType _) => IonRule(
      kind: IonRuleKind.noSelfPair,
      a: a,
      check: (left, right) {
        if (left == null || right == null) return true;
        return !(left == a && right == a);
      },
    ),
    // Rule: type A must not be next to type B
    (IonType a, IonType b) => IonRule(
      kind: IonRuleKind.noMixedPair,
      a: a,
      b: b,
      check: (left, right) {
        if (left == null || right == null) return true;
        return !((left == a && right == b) || (left == b && right == a));
      },
    ),
  ];

  /// Whether [rules] actually constrain the player: every shape a rule
  /// names is on the finished ring, and at least one way of dropping
  /// [available] into the empty slots of [chain] breaks a rule.
  static bool rulesMatter(List<IonType?> chain, List<IonType> solution,
      List<IonType> available, List<IonRule> rules) {
    final onRing = solution.toSet();
    for (final rule in rules) {
      if (rule.a != null && !onRing.contains(rule.a)) return false;
      if (rule.b != null && !onRing.contains(rule.b)) return false;
    }

    final blanks = [
      for (var i = 0; i < chain.length; i++)
        if (chain[i] == null) i,
    ];
    var foundIllegal = false;
    void place(int k, List<IonType> left, List<IonType?> working) {
      if (foundIllegal) return;
      if (k == blanks.length) {
        if (!validateChain(working, rules)) foundIllegal = true;
        return;
      }
      final tried = <IonType>{};
      for (var i = 0; i < left.length; i++) {
        if (!tried.add(left[i])) continue;
        working[blanks[k]] = left[i];
        place(k + 1, [...left]..removeAt(i), working);
      }
      working[blanks[k]] = null;
    }

    place(0, available, List<IonType?>.from(chain));
    return foundIllegal;
  }

  /// Generate a puzzle using backtracking CSP.
  static IonChainPuzzle generate({
    required int chainLength,
    required int ionTypeCount,
    required int ruleCount,
    required int blanksToRemove,
    int? seed,
  }) {
    final rng = math.Random(seed);
    final types = IonType.values.take(ionTypeCount).toList();

    for (int attempt = 0; attempt < 500; attempt++) {
      // Generate rules
      final rules = <IonRule>[];
      final usedRuleKeys = <String>{};

      int ruleTries = 0;
      while (rules.length < ruleCount && ruleTries < 50) {
        ruleTries++;
        final factoryIdx = rng.nextInt(_ruleFactories.length);
        final a = types[rng.nextInt(types.length)];
        final b = types[rng.nextInt(types.length)];
        // Factory 0 ("no two As adjacent") ignores b entirely, so b must stay
        // out of its key -- otherwise the same rule is generated, and shown to
        // the player, several times over. Factory 1 is symmetric, so normalise
        // (a,b) and (b,a) to one key.
        final ka = a.index;
        final kb = b.index;
        final key = factoryIdx == 1
            ? '1:${math.min(ka, kb)}:${math.max(ka, kb)}'
            : '0:$ka';

        if (usedRuleKeys.contains(key)) continue;
        if (factoryIdx == 1 && a == b) continue; // same type avoidance is rule 0

        usedRuleKeys.add(key);
        rules.add(_ruleFactories[factoryIdx](a, b));
      }

      if (rules.length < ruleCount) continue;

      // Solve using backtracking
      final solution = <IonType>[];
      if (_solve(solution, chainLength, types, rules, rng)) {
        // Remove some positions for the player to fill
        final chain = List<IonType?>.from(solution);
        final positions = List.generate(chainLength, (i) => i)..shuffle(rng);
        final blanks = positions.take(blanksToRemove.clamp(1, chainLength - 1)).toList();
        final availableIons = <IonType>[];

        for (final pos in blanks) {
          availableIons.add(chain[pos]!);
          chain[pos] = null;
        }

        // A rule the board cannot break is noise: "Circle may not be next to
        // Star" on a ring with no star, or blanks that every arrangement
        // fills legally, leave the player nothing to work out.
        if (!rulesMatter(chain, solution, availableIons, rules)) continue;

        // Shuffle available ions so it's not trivial
        availableIons.shuffle(rng);

        return IonChainPuzzle(
          chainLength: chainLength,
          chain: chain,
          solution: solution,
          availableIons: availableIons,
          rules: rules,
          ionTypes: types,
        );
      }
    }

    // Fallback: use "no same adjacent" + one pair exclusion rule.
    // Build solution via backtracking (not a trivial repeating pattern).
    final typeA = types[rng.nextInt(types.length)];
    IonType typeB;
    do { typeB = types[rng.nextInt(types.length)]; } while (typeB == typeA);

    final noSameAdjacent = IonRule(
      kind: IonRuleKind.noRepeatAtAll,
      check: (left, right) {
        if (left == null || right == null) return true;
        return left != right;
      },
    );
    final pairExclusion = IonRule(
      kind: IonRuleKind.noMixedPair,
      a: typeA,
      b: typeB,
      check: (left, right) {
        if (left == null || right == null) return true;
        return !((left == typeA && right == typeB) || (left == typeB && right == typeA));
      },
    );

    // Weaken the fallback until it is satisfiable, rather than shipping rules
    // no arrangement can meet.
    //
    // Both rules together are impossible with only two ion types: "no two the
    // same next to each other" forces A,B,A,B..., which is precisely what "A
    // must not neighbor B" forbids. The old code then fell through to that
    // same alternation as a last resort and shipped it *with both rules still
    // attached* -- a puzzle whose own solution broke its own rules, so no
    // placement the player made could ever be accepted.
    //
    // No difficulty setting asks for two types today, so this was unreachable;
    // it would have become a shipped-unsolvable game the moment someone tuned
    // the grade mapping down, which is the failure this game was gated for in
    // the first place.
    var fallbackRules = <IonRule>[noSameAdjacent, pairExclusion];
    final fallbackSolution = <IonType>[];
    if (!_solve(fallbackSolution, chainLength, types, fallbackRules, rng)) {
      fallbackRules = <IonRule>[noSameAdjacent];
      fallbackSolution.clear();
      if (!_solve(fallbackSolution, chainLength, types, fallbackRules, rng)) {
        // Only reachable with a single ion type, where nothing can be
        // constrained at all. Ship the chain with no rules rather than with
        // rules it violates.
        fallbackRules = <IonRule>[];
        fallbackSolution.clear();
        for (int i = 0; i < chainLength; i++) {
          fallbackSolution.add(types[i % types.length]);
        }
      }
    }

    final chain = List<IonType?>.from(fallbackSolution);
    final positions = List.generate(chainLength, (i) => i)..shuffle(rng);
    final blanks = positions.take(blanksToRemove.clamp(1, chainLength - 1)).toList();
    final available = <IonType>[];
    for (final pos in blanks) {
      available.add(chain[pos]!);
      chain[pos] = null;
    }
    available.shuffle(rng);

    return IonChainPuzzle(
      chainLength: chainLength,
      chain: chain,
      solution: fallbackSolution,
      availableIons: available,
      rules: fallbackRules,
      ionTypes: types,
    );
  }

  static bool _solve(
    List<IonType> partial,
    int length,
    List<IonType> types,
    List<IonRule> rules,
    math.Random rng,
  ) {
    if (partial.length == length) {
      // For circular chain: also check last-to-first adjacency
      for (final rule in rules) {
        if (!rule.check(partial.last, partial.first)) return false;
      }
      return true;
    }

    final shuffledTypes = List<IonType>.from(types)..shuffle(rng);
    for (final type in shuffledTypes) {
      // Check rules against previous element
      bool valid = true;
      if (partial.isNotEmpty) {
        for (final rule in rules) {
          if (!rule.check(partial.last, type)) {
            valid = false;
            break;
          }
        }
      }

      if (valid) {
        partial.add(type);
        if (_solve(partial, length, types, rules, rng)) return true;
        partial.removeLast();
      }
    }
    return false;
  }
}
