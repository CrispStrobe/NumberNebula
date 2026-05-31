// lib/features/games/services/ion_chain_logic.dart
//
// Sequence builder with adjacency constraints (CSP-based).
// Place colored ions on a rail obeying rules like:
// - no two of same color adjacent
// - specific color must neighbor another specific color
// Generates valid chains, removes some for player to fill.

import 'dart:math' as math;

enum IonType { red, blue, green, yellow, purple }

class IonRule {
  final String description;
  final String descriptionDe;
  final bool Function(IonType?, IonType?) check;

  IonRule({
    required this.description,
    required this.descriptionDe,
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

  /// Validate if a completed chain satisfies all rules.
  static bool validateChain(List<IonType?> chain, List<IonRule> rules) {
    for (int i = 0; i < chain.length - 1; i++) {
      for (final rule in rules) {
        if (!rule.check(chain[i], chain[i + 1])) return false;
      }
    }
    return true;
  }

  static final List<IonRule Function(IonType, IonType)> _ruleFactories = [
    // Rule: no two of type A adjacent
    (IonType a, IonType _) => IonRule(
      description: 'No two ${a.name} ions adjacent',
      descriptionDe: 'Keine zwei ${_ionNameDe(a)}-Ionen nebeneinander',
      check: (left, right) {
        if (left == null || right == null) return true;
        return !(left == a && right == a);
      },
    ),
    // Rule: type A must not be next to type B
    (IonType a, IonType b) => IonRule(
      description: '${a.name} must not neighbor ${b.name}',
      descriptionDe: '${_ionNameDe(a)} darf nicht neben ${_ionNameDe(b)} stehen',
      check: (left, right) {
        if (left == null || right == null) return true;
        return !((left == a && right == b) || (left == b && right == a));
      },
    ),
  ];

  static String _ionNameDe(IonType type) {
    switch (type) {
      case IonType.red: return 'Rot';
      case IonType.blue: return 'Blau';
      case IonType.green: return 'Grun';
      case IonType.yellow: return 'Gelb';
      case IonType.purple: return 'Lila';
    }
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

    for (int attempt = 0; attempt < 100; attempt++) {
      // Generate rules
      final rules = <IonRule>[];
      final usedRuleKeys = <String>{};

      int ruleTries = 0;
      while (rules.length < ruleCount && ruleTries < 50) {
        ruleTries++;
        final factoryIdx = rng.nextInt(_ruleFactories.length);
        final a = types[rng.nextInt(types.length)];
        final b = types[rng.nextInt(types.length)];
        final key = '$factoryIdx:${a.index}:${b.index}';

        if (usedRuleKeys.contains(key)) continue;
        if (factoryIdx == 0 && a == b) continue; // self-adjacency rule doesn't need b
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

    // Fallback: simple chain with no-same-adjacent rule
    final fallbackRules = [
      IonRule(
        description: 'No two same-colored ions adjacent',
        descriptionDe: 'Keine zwei gleichfarbigen Ionen nebeneinander',
        check: (left, right) {
          if (left == null || right == null) return true;
          return left != right;
        },
      ),
    ];

    final solution = <IonType>[];
    for (int i = 0; i < chainLength; i++) {
      solution.add(types[i % types.length]);
    }

    final chain = List<IonType?>.from(solution);
    final available = <IonType>[];
    for (int i = 0; i < blanksToRemove && i < chainLength; i++) {
      available.add(chain[i]!);
      chain[i] = null;
    }

    return IonChainPuzzle(
      chainLength: chainLength,
      chain: chain,
      solution: solution,
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
    if (partial.length == length) return true;

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
