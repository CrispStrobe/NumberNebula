import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A person at the tribunal: either a truth-teller or a liar
class TribunalPerson {
  final String name;
  final bool isTruthTeller;
  /// Legacy display text — prefer building from structured fields + i18n.
  final String statement;
  /// The index of person this statement refers to (or -1 for self)
  final int targetIndex;
  /// What the statement claims about the target
  final bool claimsTruthTeller;
  /// Style variant (0-2) for i18n template selection
  final int statementStyle;

  const TribunalPerson({
    required this.name,
    required this.isTruthTeller,
    required this.statement,
    required this.targetIndex,
    required this.claimsTruthTeller,
    this.statementStyle = 0,
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

    if (kDebugMode) debugPrint('[ALIEN_TRIBUNAL] Generating puzzle for grade=$grade, level=$level');

    // Difficulty scaling -- minimum 3 people (2-person puzzles are almost
    // always ambiguous and cause infinite retry loops)
    int personCount;
    if (difficulty.grade <= 1) {
      personCount = 3;
    } else if (difficulty.grade <= 2) {
      personCount = level <= 5 ? 3 : 4;
    } else if (difficulty.grade <= 3) {
      personCount = level <= 3 ? 4 : 5;
    } else {
      personCount = level <= 5 ? 4 : 5;
    }

    // Retry with a hard cap to avoid infinite loops
    for (int attempt = 0; attempt < 50; attempt++) {
      final result = _tryGenerate(personCount, rng);
      if (result != null) {
        if (kDebugMode) debugPrint('[ALIEN_TRIBUNAL] Success on attempt $attempt');
        return result;
      }
    }

    // Fallback: build a guaranteed-unique 3-person puzzle manually
    // A=truth-teller, B=liar, C=truth-teller
    // A says "C tells the truth" (true, consistent)
    // B says "A is a liar" (lie, consistent since A is truth-teller)
    // C says "B is a liar" (true, consistent)
    if (kDebugMode) debugPrint('[ALIEN_TRIBUNAL] Using fallback puzzle');
    final names = (List<String>.from(_alienNames)..shuffle(rng)).take(3).toList();
    return AlienTribunalPuzzle(
      people: [
        TribunalPerson(name: names[0], isTruthTeller: true,
          statement: '"${names[2]} tells the truth."', targetIndex: 2, claimsTruthTeller: true),
        TribunalPerson(name: names[1], isTruthTeller: false,
          statement: '"${names[0]} is a liar."', targetIndex: 0, claimsTruthTeller: false),
        TribunalPerson(name: names[2], isTruthTeller: true,
          statement: '"${names[1]} is a liar."', targetIndex: 1, claimsTruthTeller: false),
      ],
      personCount: 3,
    );
  }

  static AlienTribunalPuzzle? _tryGenerate(int personCount, math.Random rng) {
    // Pick names
    final availableNames = List<String>.from(_alienNames)..shuffle(rng);
    final names = availableNames.take(personCount).toList();

    // Generate valid assignment with at least 1 truth-teller and 1 liar
    List<bool> assignment;
    int retries = 20;
    do {
      assignment = List.generate(personCount, (_) => rng.nextBool());
      retries--;
    } while (retries > 0 &&
        (assignment.every((v) => v) || assignment.every((v) => !v)));

    if (assignment.every((v) => v) || assignment.every((v) => !v)) {
      assignment[0] = true;
      assignment[1] = false;
    }

    // Generate statements -- ensure each person targets a DIFFERENT person
    // to maximize information and improve uniqueness chances
    final people = <TribunalPerson>[];
    final usedTargets = <int>{};

    for (int i = 0; i < personCount; i++) {
      // Prefer a target not yet targeted by anyone else
      int targetIdx;
      final untargeted = List.generate(personCount, (j) => j)
          .where((j) => j != i && !usedTargets.contains(j))
          .toList();
      if (untargeted.isNotEmpty) {
        targetIdx = untargeted[rng.nextInt(untargeted.length)];
      } else {
        do {
          targetIdx = rng.nextInt(personCount);
        } while (targetIdx == i);
      }
      usedTargets.add(targetIdx);

      final targetIsTruthTeller = assignment[targetIdx];
      final iAmTruthTeller = assignment[i];

      bool claimsTruthTeller;
      if (iAmTruthTeller) {
        claimsTruthTeller = targetIsTruthTeller;
      } else {
        claimsTruthTeller = !targetIsTruthTeller;
      }

      final targetName = names[targetIdx];
      final style = rng.nextInt(3);
      // Build fallback English statement (used when i18n not available)
      String statement;
      if (claimsTruthTeller) {
        switch (style) {
          case 0: statement = '"$targetName tells the truth."'; break;
          case 1: statement = '"$targetName is trustworthy."'; break;
          default: statement = '"$targetName is a truth-teller."';
        }
      } else {
        switch (style) {
          case 0: statement = '"$targetName is a liar."'; break;
          case 1: statement = '"$targetName cannot be trusted."'; break;
          default: statement = '"$targetName always lies."';
        }
      }

      people.add(TribunalPerson(
        name: names[i],
        isTruthTeller: assignment[i],
        statement: statement,
        targetIndex: targetIdx,
        claimsTruthTeller: claimsTruthTeller,
        statementStyle: style,
      ));
    }

    // Verify unique solution
    final validSolutions = _findAllValidSolutions(people, personCount);
    if (validSolutions.length != 1) return null;

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
