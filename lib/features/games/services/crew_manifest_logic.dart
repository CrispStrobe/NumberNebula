import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// Types of clues for i18n rendering
enum ClueType { positive, negative }

/// A structured clue that can be rendered with i18n
class ManifestClue {
  final ClueType type;
  final String crewName;
  final String itemName;
  final int style; // 0-2 for template variation

  const ManifestClue({
    required this.type,
    required this.crewName,
    required this.itemName,
    this.style = 0,
  });
}

/// A logic grid puzzle: match N people to N items using clues
class CrewManifestPuzzle {
  final int size; // number of crew members = number of items
  final List<String> crewNames;
  final List<String> itemNames;
  final Map<String, String> solution; // crewName -> itemName
  final List<ManifestClue> structuredClues;

  const CrewManifestPuzzle({
    required this.size,
    required this.crewNames,
    required this.itemNames,
    required this.solution,
    required this.structuredClues,
  });

  /// Check if user's assignment matches solution
  bool checkSolution(Map<String, String> userAssignment) {
    for (final crew in crewNames) {
      if (userAssignment[crew] != solution[crew]) return false;
    }
    return true;
  }
}

class CrewManifestLogic {
  static const _allCrewNames = [
    'Zara', 'Kip', 'Nova', 'Rex', 'Luna',
    'Orion', 'Vega', 'Cosmo', 'Stella', 'Astro',
  ];

  static const _allItemNames = [
    'Helm', 'Map', 'Laser', 'Shield', 'Wrench',
    'Beacon', 'Scope', 'Crystal', 'Badge', 'Compass',
  ];

  static CrewManifestPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    if (kDebugMode) debugPrint('[CREW_MANIFEST] Generating puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int size;
    if (difficulty.grade <= 1) {
      size = 3;
    } else if (difficulty.grade <= 2) {
      size = level <= 5 ? 3 : 4;
    } else if (difficulty.grade <= 3) {
      size = level <= 3 ? 4 : 5;
    } else {
      size = level <= 5 ? 4 : 5;
    }

    // How many direct positive clues: fewer = harder
    int directClueCount;
    if (difficulty.grade <= 1) {
      directClueCount = size - 1; // all but one
    } else if (difficulty.grade <= 2) {
      directClueCount = size - 1;
    } else {
      // Higher grades: reduce direct clues, compensate with
      // more negative clues to keep uniqueness
      directClueCount = (size * 0.5).ceil().clamp(1, size - 1);
    }

    // Retry loop: generate clues and verify unique solution
    for (int attempt = 0; attempt < 40; attempt++) {
      final result = _tryGenerate(size, directClueCount, rng, difficulty.grade);
      if (result != null) {
        if (kDebugMode) debugPrint('[CREW_MANIFEST] Success on attempt $attempt');
        return result;
      }
    }

    // Fallback: guaranteed 3x3 puzzle
    if (kDebugMode) debugPrint('[CREW_MANIFEST] Using fallback puzzle');
    return const CrewManifestPuzzle(
      size: 3,
      crewNames: ['Zara', 'Kip', 'Nova'],
      itemNames: const ['Helm', 'Map', 'Laser'],
      solution: const {'Zara': 'Helm', 'Kip': 'Map', 'Nova': 'Laser'},
      structuredClues: const [
        ManifestClue(type: ClueType.positive, crewName: 'Zara', itemName: 'Helm', style: 0),
        ManifestClue(type: ClueType.positive, crewName: 'Kip', itemName: 'Map', style: 1),
      ],
    );
  }

  static CrewManifestPuzzle? _tryGenerate(
    int size, int directClueCount, math.Random rng, int grade,
  ) {
    // Pick random crew and items
    final availableCrew = List<String>.from(_allCrewNames)..shuffle(rng);
    final availableItems = List<String>.from(_allItemNames)..shuffle(rng);

    final crewNames = availableCrew.take(size).toList();
    final itemNames = availableItems.take(size).toList();

    // Create random assignment (the solution)
    final shuffledItems = List<String>.from(itemNames)..shuffle(rng);
    final solution = <String, String>{};
    for (int i = 0; i < size; i++) {
      solution[crewNames[i]] = shuffledItems[i];
    }

    // Generate clues
    final clues = <ManifestClue>[];
    final crewIndices = List.generate(size, (i) => i)..shuffle(rng);
    final usedDirect = <int>{};

    // Direct positive clues
    for (int i = 0; i < directClueCount && i < size; i++) {
      final idx = crewIndices[i];
      final crewName = crewNames[idx];
      final item = solution[crewName]!;
      usedDirect.add(idx);
      clues.add(ManifestClue(
        type: ClueType.positive,
        crewName: crewName,
        itemName: item,
        style: rng.nextInt(3),
      ));
    }

    // Negative clues for remaining crew members — give ENOUGH to disambiguate
    for (int i = 0; i < size; i++) {
      if (usedDirect.contains(i)) continue;
      final crewName = crewNames[i];
      final correctItem = solution[crewName]!;

      // Give multiple negative clues: eliminate all but 1 wrong item
      // so the crew member can be deduced from the remaining positive clues
      final wrongItems = itemNames.where((it) => it != correctItem).toList()..shuffle(rng);
      // For grade >= 3 eliminate fewer (harder); for lower grades eliminate more
      final eliminateCount = grade >= 3
          ? math.max(1, wrongItems.length - 2)
          : wrongItems.length - 1;
      for (int j = 0; j < eliminateCount && j < wrongItems.length; j++) {
        clues.add(ManifestClue(
          type: ClueType.negative,
          crewName: crewName,
          itemName: wrongItems[j],
          style: rng.nextInt(2),
        ));
      }
    }

    clues.shuffle(rng);

    // Verify unique solution using constraint propagation
    final solutionCount = _countSolutions(crewNames, itemNames, clues, size);
    if (solutionCount != 1) return null;

    return CrewManifestPuzzle(
      size: size,
      crewNames: crewNames,
      itemNames: itemNames,
      solution: solution,
      structuredClues: clues,
    );
  }

  /// Count how many valid assignments satisfy all clues (stops at 2).
  static int _countSolutions(
    List<String> crew, List<String> items,
    List<ManifestClue> clues, int size,
  ) {
    // Build constraint sets: for each crew member, which items are possible?
    final possible = <String, Set<String>>{};
    for (final c in crew) {
      possible[c] = Set<String>.from(items);
    }

    // Apply clues
    for (final clue in clues) {
      if (clue.type == ClueType.positive) {
        // crew has item => only this item is possible
        possible[clue.crewName] = {clue.itemName};
      } else {
        // crew does NOT have item
        possible[clue.crewName]?.remove(clue.itemName);
      }
    }

    // Backtracking solver — count solutions, stop at 2
    int count = 0;
    void solve(int idx, Set<String> usedItems) {
      if (count >= 2) return; // early exit
      if (idx == size) {
        count++;
        return;
      }
      final c = crew[idx];
      for (final item in possible[c]!) {
        if (usedItems.contains(item)) continue;
        usedItems.add(item);
        solve(idx + 1, usedItems);
        usedItems.remove(item);
        if (count >= 2) return;
      }
    }

    solve(0, <String>{});
    return count;
  }
}
