import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A logic grid puzzle: match N people to N items using clues
class CrewManifestPuzzle {
  final int size; // number of crew members = number of items
  final List<String> crewNames;
  final List<String> itemNames;
  final Map<String, String> solution; // crewName -> itemName
  final List<String> clues; // text clues

  const CrewManifestPuzzle({
    required this.size,
    required this.crewNames,
    required this.itemNames,
    required this.solution,
    required this.clues,
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

    debugPrint('[CREW_MANIFEST] Generating puzzle for grade=$grade, level=$level');

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

    debugPrint('[CREW_MANIFEST] Solution: $solution');

    // Generate clues from the solution
    final clues = _generateClues(crewNames, itemNames, solution, size, rng, difficulty.grade);

    return CrewManifestPuzzle(
      size: size,
      crewNames: crewNames,
      itemNames: itemNames,
      solution: solution,
      clues: clues,
    );
  }

  static List<String> _generateClues(
    List<String> crew,
    List<String> items,
    Map<String, String> solution,
    int size,
    math.Random rng,
    int grade,
  ) {
    final clues = <String>[];
    final usedDirect = <int>{};

    // We need enough clues to make the puzzle solvable.
    // Strategy: give direct positive clues for some, negative clues for others.

    // Build reverse map: item -> crew
    final reverseMap = <String, String>{};
    for (final e in solution.entries) {
      reverseMap[e.value] = e.key;
    }

    // Give one direct clue for each crew except the last (which can be deduced)
    final crewIndices = List.generate(size, (i) => i)..shuffle(rng);

    // Direct positive clues (N-1 of them make it solvable)
    int directClueCount = (size - 1).clamp(2, size - 1);
    // For higher grades, give fewer direct clues and more negative ones
    if (grade >= 3 && size >= 4) {
      directClueCount = (size * 0.5).ceil().clamp(1, size - 1);
    }

    for (int i = 0; i < directClueCount && i < size; i++) {
      final idx = crewIndices[i];
      final crewName = crew[idx];
      final item = solution[crewName]!;
      usedDirect.add(idx);

      // Vary clue style
      final style = rng.nextInt(3);
      switch (style) {
        case 0:
          clues.add('$crewName has the $item.');
          break;
        case 1:
          clues.add('The $item belongs to $crewName.');
          break;
        case 2:
          clues.add('$crewName was assigned the $item.');
          break;
      }
    }

    // Add negative clues for remaining crew members
    for (int i = 0; i < size; i++) {
      if (usedDirect.contains(i)) continue;
      final crewName = crew[i];
      final correctItem = solution[crewName]!;

      // Pick a wrong item to say they DON'T have
      final wrongItems = items.where((it) => it != correctItem).toList()..shuffle(rng);
      if (wrongItems.isNotEmpty) {
        clues.add('$crewName does not have the ${wrongItems.first}.');
      }
    }

    // Add extra negative clues for flavor
    final extraClues = rng.nextInt(2) + 1;
    for (int e = 0; e < extraClues; e++) {
      final crewIdx = rng.nextInt(size);
      final crewName = crew[crewIdx];
      final correctItem = solution[crewName]!;
      final wrongItems = items.where((it) => it != correctItem).toList()..shuffle(rng);
      if (wrongItems.isNotEmpty) {
        clues.add('$crewName does not have the ${wrongItems.first}.');
      }
    }

    clues.shuffle(rng);

    debugPrint('[CREW_MANIFEST] Generated ${clues.length} clues');
    return clues;
  }
}
