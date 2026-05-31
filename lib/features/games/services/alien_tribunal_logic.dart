import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A person at the tribunal: either a truth-teller or a liar
class TribunalPerson {
  final String name;
  final bool isTruthTeller;
  final String statement;
  /// The index of person this statement refers to (or -1 for self)
  final int targetIndex;
  /// What the statement claims about the target
  final bool claimsTruthTeller;

  const TribunalPerson({
    required this.name,
    required this.isTruthTeller,
    required this.statement,
    required this.targetIndex,
    required this.claimsTruthTeller,
  });
}

class AlienTribunalPuzzle {
  final List<TribunalPerson> people;
  final int personCount;

  const AlienTribunalPuzzle({
    required this.people,
    required this.personCount,
  });

  /// Check if user's assignment matches the solution
  bool checkSolution(Map<int, bool> userAssignment) {
    for (int i = 0; i < personCount; i++) {
      if (userAssignment[i] != people[i].isTruthTeller) return false;
    }
    return true;
  }

  /// Get the correct solution
  Map<int, bool> getSolution() {
    final sol = <int, bool>{};
    for (int i = 0; i < personCount; i++) {
      sol[i] = people[i].isTruthTeller;
    }
    return sol;
  }
}

class AlienTribunalLogic {
  static const _alienNames = [
    'Zyx', 'Qar', 'Meb', 'Tol', 'Pix',
    'Vor', 'Kel', 'Dun', 'Rix', 'Baf',
  ];

  static AlienTribunalPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    debugPrint('[ALIEN_TRIBUNAL] Generating puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int personCount;
    if (difficulty.grade <= 1) {
      personCount = 2;
    } else if (difficulty.grade <= 2) {
      personCount = level <= 5 ? 3 : 3;
    } else if (difficulty.grade <= 3) {
      personCount = level <= 3 ? 3 : 4;
    } else {
      personCount = level <= 5 ? 4 : 5;
    }

    // Pick names
    final availableNames = List<String>.from(_alienNames)..shuffle(rng);
    final names = availableNames.take(personCount).toList();

    // Generate valid assignment with at least 1 truth-teller and 1 liar
    List<bool> assignment;
    int maxRetries = 100;
    do {
      assignment = List.generate(personCount, (_) => rng.nextBool());
      maxRetries--;
    } while (maxRetries > 0 &&
        (assignment.every((v) => v) || assignment.every((v) => !v)));

    // If we exhausted retries, force a valid assignment
    if (assignment.every((v) => v) || assignment.every((v) => !v)) {
      assignment[0] = true;
      assignment[1] = false;
    }

    debugPrint('[ALIEN_TRIBUNAL] Assignment: ${List.generate(personCount, (i) => "${names[i]}=${assignment[i] ? 'T' : 'L'}")}');

    // Generate statements
    final people = <TribunalPerson>[];
    for (int i = 0; i < personCount; i++) {
      // Pick a target (not self)
      int targetIdx;
      do {
        targetIdx = rng.nextInt(personCount);
      } while (targetIdx == i);

      final targetIsTruthTeller = assignment[targetIdx];
      final iAmTruthTeller = assignment[i];

      // Truth-tellers say true things, liars say false things
      bool claimsTruthTeller;
      if (iAmTruthTeller) {
        claimsTruthTeller = targetIsTruthTeller; // truth-teller tells truth
      } else {
        claimsTruthTeller = !targetIsTruthTeller; // liar lies
      }

      // Generate statement text
      final targetName = names[targetIdx];
      String statement;
      if (claimsTruthTeller) {
        final style = rng.nextInt(3);
        switch (style) {
          case 0:
            statement = '"$targetName tells the truth."';
            break;
          case 1:
            statement = '"$targetName is trustworthy."';
            break;
          default:
            statement = '"$targetName is a truth-teller."';
        }
      } else {
        final style = rng.nextInt(3);
        switch (style) {
          case 0:
            statement = '"$targetName is a liar."';
            break;
          case 1:
            statement = '"$targetName cannot be trusted."';
            break;
          default:
            statement = '"$targetName always lies."';
        }
      }

      people.add(TribunalPerson(
        name: names[i],
        isTruthTeller: assignment[i],
        statement: statement,
        targetIndex: targetIdx,
        claimsTruthTeller: claimsTruthTeller,
      ));
    }

    // Verify the puzzle has a unique solution by checking all possible assignments
    final validSolutions = _findAllValidSolutions(people, personCount);
    debugPrint('[ALIEN_TRIBUNAL] Found ${validSolutions.length} valid solution(s)');

    // If not unique, regenerate (recursive with new seed)
    if (validSolutions.length != 1) {
      debugPrint('[ALIEN_TRIBUNAL] Non-unique solution, regenerating...');
      return generate(args);
    }

    return AlienTribunalPuzzle(
      people: people,
      personCount: personCount,
    );
  }

  /// Find all valid assignments for the given set of statements
  static List<List<bool>> _findAllValidSolutions(
    List<TribunalPerson> people,
    int personCount,
  ) {
    final solutions = <List<bool>>[];

    // Try all 2^n combinations
    final totalCombinations = 1 << personCount;
    for (int mask = 0; mask < totalCombinations; mask++) {
      final assignment = List.generate(
        personCount,
        (i) => (mask >> i) & 1 == 1,
      );

      if (_isConsistent(people, assignment, personCount)) {
        solutions.add(assignment);
      }
    }

    return solutions;
  }

  /// Check if an assignment is consistent with all statements
  static bool _isConsistent(
    List<TribunalPerson> people,
    List<bool> assignment,
    int personCount,
  ) {
    for (int i = 0; i < personCount; i++) {
      final person = people[i];
      final isTruthTeller = assignment[i];
      final targetIsTruthTeller = assignment[person.targetIndex];

      // If person is truth-teller, their claim must be true
      // If person is liar, their claim must be false
      if (isTruthTeller) {
        if (person.claimsTruthTeller != targetIsTruthTeller) return false;
      } else {
        if (person.claimsTruthTeller == targetIsTruthTeller) return false;
      }
    }
    return true;
  }
}
