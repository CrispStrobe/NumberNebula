import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// The shape of a delegate's statement.
///
/// [single] statements alone can never yield a solvable puzzle. "X is a liar"
/// only ever asserts whether two delegates share a role, so swapping every
/// role at once satisfies exactly the same statements -- every puzzle built
/// from them has at least two valid verdicts. [pair] and [count] statements
/// break that symmetry, which is what makes a single correct verdict possible.
enum TribunalClaimKind {
  /// About one other delegate: "X tells the truth" / "X is a liar".
  single,

  /// About two other delegates: "X and Y both lie" / "at least one of X and Y lies".
  pair,

  /// About the whole tribunal: "exactly N of us are liars".
  count,
}

/// A delegate at the tribunal: either a truth-teller or a liar.
class TribunalPerson {
  final String name;
  final bool isTruthTeller;

  /// Legacy English rendering. The UI builds localized text from the
  /// structured fields below; this is kept for debugging and tests.
  final String statement;

  final TribunalClaimKind kind;

  /// Subject of a [TribunalClaimKind.single] claim, or the first subject of a
  /// [TribunalClaimKind.pair] claim. -1 for [TribunalClaimKind.count].
  final int targetIndex;

  /// Second subject of a [TribunalClaimKind.pair] claim, -1 otherwise.
  final int secondTargetIndex;

  /// Polarity of a [TribunalClaimKind.single] or [TribunalClaimKind.pair]
  /// claim: whether it asserts truth-telling rather than lying.
  final bool claimsTruthTeller;

  /// [TribunalClaimKind.pair] only: "both of them are..." when true,
  /// "at least one of them is..." when false.
  final bool pairRequiresBoth;

  /// [TribunalClaimKind.count] only: how many delegates the claim asserts.
  final int countValue;

  /// [TribunalClaimKind.count] only: counts truth-tellers rather than liars.
  final bool countsTruthTellers;

  /// Wording variant, for i18n template selection.
  final int statementStyle;

  const TribunalPerson({
    required this.name,
    required this.isTruthTeller,
    required this.statement,
    required this.targetIndex,
    required this.claimsTruthTeller,
    this.kind = TribunalClaimKind.single,
    this.secondTargetIndex = -1,
    this.pairRequiresBoth = true,
    this.countValue = 0,
    this.countsTruthTellers = false,
    this.statementStyle = 0,
  });

  /// Whether this delegate's claim is true under [assignment].
  bool claimHolds(List<bool> assignment) {
    switch (kind) {
      case TribunalClaimKind.single:
        return assignment[targetIndex] == claimsTruthTeller;
      case TribunalClaimKind.pair:
        final first = assignment[targetIndex] == claimsTruthTeller;
        final second = assignment[secondTargetIndex] == claimsTruthTeller;
        return pairRequiresBoth ? (first && second) : (first || second);
      case TribunalClaimKind.count:
        final matching =
            assignment.where((v) => v == countsTruthTellers).length;
        return matching == countValue;
    }
  }
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

  /// Whether [assignment] satisfies every delegate: truth-tellers' claims must
  /// hold, liars' claims must not.
  bool isConsistent(List<bool> assignment) {
    for (int i = 0; i < personCount; i++) {
      if (people[i].claimHolds(assignment) != assignment[i]) return false;
    }
    return true;
  }

  /// Every verdict consistent with the statements. A well-formed puzzle has
  /// exactly one.
  List<List<bool>> findAllSolutions() {
    final solutions = <List<bool>>[];
    for (int mask = 0; mask < (1 << personCount); mask++) {
      final assignment =
          List.generate(personCount, (i) => (mask >> i) & 1 == 1);
      if (isConsistent(assignment)) solutions.add(assignment);
    }
    return solutions;
  }
}

class AlienTribunalLogic {
  static const _alienNames = [
    'Zyx', 'Qar', 'Meb', 'Tol', 'Pix',
    'Vor', 'Kel', 'Dun', 'Rix', 'Baf',
  ];

  /// Statement re-rolls per role pattern. One draw is unique roughly 20-50% of
  /// the time, so exhausting this is already vanishingly unlikely.
  static const _statementAttempts = 80;

  /// Role patterns to try before giving up on a generated puzzle entirely.
  static const _patternAttempts = 12;

  static AlienTribunalPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    if (kDebugMode) {
      debugPrint('[ALIEN_TRIBUNAL] Generating puzzle for grade=$grade, level=$level');
    }

    // Minimum 3 delegates -- 2-delegate puzzles are almost always ambiguous.
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

    // "At least one of X and Y lies" needs a disjunction to reason through, so
    // it is held back until the older grades.
    final allowDisjunction = difficulty.grade >= 3;

    for (int p = 0; p < _patternAttempts; p++) {
      // Draw the verdict pattern first and hold it fixed while re-rolling
      // statements. Re-drawing the roles on every retry instead would skew the
      // game towards the few patterns that happen to be easiest to pin down,
      // which is how this game ended up always showing the same verdict.
      final roles = _randomRoles(personCount, rng);

      for (int a = 0; a < _statementAttempts; a++) {
        final puzzle = _tryBuild(roles, rng, allowDisjunction);
        if (puzzle != null) {
          if (kDebugMode) {
            debugPrint('[ALIEN_TRIBUNAL] Unique puzzle after ${p * _statementAttempts + a + 1} draws: '
                '${roles.map((r) => r ? "T" : "L").join()}');
          }
          return puzzle;
        }
      }
    }

    if (kDebugMode) debugPrint('[ALIEN_TRIBUNAL] Using fallback puzzle');
    return _fallback(rng);
  }

  /// A random role pattern with at least one truth-teller and one liar.
  static List<bool> _randomRoles(int personCount, math.Random rng) {
    while (true) {
      final roles = List.generate(personCount, (_) => rng.nextBool());
      if (roles.contains(true) && roles.contains(false)) return roles;
    }
  }

  /// Build one candidate puzzle for [roles]; null unless its verdict is unique.
  static AlienTribunalPuzzle? _tryBuild(
    List<bool> roles,
    math.Random rng,
    bool allowDisjunction,
  ) {
    final personCount = roles.length;
    final names =
        (List<String>.from(_alienNames)..shuffle(rng)).take(personCount).toList();

    final people = <TribunalPerson>[];
    for (int i = 0; i < personCount; i++) {
      final person = _randomStatement(i, roles, names, rng, allowDisjunction);
      if (person == null) return null;
      people.add(person);
    }

    final puzzle =
        AlienTribunalPuzzle(people: people, personCount: personCount);
    return puzzle.findAllSolutions().length == 1 ? puzzle : null;
  }

  /// A random statement for delegate [i] that is true exactly when [i] is a
  /// truth-teller -- which is what makes the delegate's role self-consistent.
  static TribunalPerson? _randomStatement(
    int i,
    List<bool> roles,
    List<String> names,
    math.Random rng,
    bool allowDisjunction,
  ) {
    final personCount = roles.length;
    final mustHold = roles[i];
    final others = (List.generate(personCount, (j) => j)..remove(i))
      ..shuffle(rng);

    final candidates = <TribunalPerson>[];

    TribunalPerson build({
      required TribunalClaimKind kind,
      int targetIndex = -1,
      int secondTargetIndex = -1,
      bool claimsTruthTeller = true,
      bool pairRequiresBoth = true,
      int countValue = 0,
      bool countsTruthTellers = false,
      required int styleCount,
    }) {
      final style = rng.nextInt(styleCount);
      final person = TribunalPerson(
        name: names[i],
        isTruthTeller: roles[i],
        statement: '',
        kind: kind,
        targetIndex: targetIndex,
        secondTargetIndex: secondTargetIndex,
        claimsTruthTeller: claimsTruthTeller,
        pairRequiresBoth: pairRequiresBoth,
        countValue: countValue,
        countsTruthTellers: countsTruthTellers,
        statementStyle: style,
      );
      return _withEnglishStatement(person, names);
    }

    // "X tells the truth" / "X is a liar" -- pick the polarity that makes the
    // statement land on the required truth value.
    final target = others.first;
    candidates.add(build(
      kind: TribunalClaimKind.single,
      targetIndex: target,
      claimsTruthTeller: mustHold ? roles[target] : !roles[target],
      styleCount: 3,
    ));

    // "X and Y both lie" / "at least one of X and Y lies".
    if (others.length >= 2) {
      final first = others[0];
      final second = others[1];
      for (final claimsTruth in [true, false]) {
        for (final both in [true, false]) {
          if (!both && !allowDisjunction) continue;
          final candidate = build(
            kind: TribunalClaimKind.pair,
            targetIndex: first,
            secondTargetIndex: second,
            claimsTruthTeller: claimsTruth,
            pairRequiresBoth: both,
            styleCount: 2,
          );
          if (candidate.claimHolds(roles) == mustHold) candidates.add(candidate);
        }
      }
    }

    // "Exactly N of us are liars" -- a truthful one states the real tally, a
    // lying one states any other.
    final countsTruthTellers = rng.nextBool();
    final actual = roles.where((r) => r == countsTruthTellers).length;
    int claimed;
    if (mustHold) {
      claimed = actual;
    } else {
      final wrong = [
        for (int k = 0; k <= personCount; k++)
          if (k != actual) k
      ];
      claimed = wrong[rng.nextInt(wrong.length)];
    }
    candidates.add(build(
      kind: TribunalClaimKind.count,
      countValue: claimed,
      countsTruthTellers: countsTruthTellers,
      styleCount: 1,
    ));

    if (candidates.isEmpty) return null;
    return candidates[rng.nextInt(candidates.length)];
  }

  /// A hand-verified 3-delegate puzzle with a single valid verdict, used only
  /// if random generation somehow exhausts every attempt.
  ///
  /// Two delegates vouch for each other and the third lies about the tally:
  /// the mutual vouching alone would leave the flipped verdict open, and the
  /// tally claim is what rules it out.
  static AlienTribunalPuzzle _fallback(math.Random rng) {
    final names = (List<String>.from(_alienNames)..shuffle(rng)).take(3).toList();
    // Shuffle which seat plays which part, so even this path varies.
    final seats = [0, 1, 2]..shuffle(rng);
    final vouchA = seats[0];
    final vouchB = seats[1];
    final liar = seats[2];

    final people = List<TribunalPerson?>.filled(3, null);
    people[vouchA] = _withEnglishStatement(
      TribunalPerson(
        name: names[vouchA],
        isTruthTeller: true,
        statement: '',
        kind: TribunalClaimKind.single,
        targetIndex: vouchB,
        claimsTruthTeller: true,
      ),
      names,
    );
    people[vouchB] = _withEnglishStatement(
      TribunalPerson(
        name: names[vouchB],
        isTruthTeller: true,
        statement: '',
        kind: TribunalClaimKind.single,
        targetIndex: vouchA,
        claimsTruthTeller: true,
      ),
      names,
    );
    people[liar] = _withEnglishStatement(
      TribunalPerson(
        name: names[liar],
        isTruthTeller: false,
        statement: '',
        kind: TribunalClaimKind.count,
        targetIndex: -1,
        claimsTruthTeller: false,
        countValue: 3,
      ),
      names,
    );

    return AlienTribunalPuzzle(
      people: people.cast<TribunalPerson>(),
      personCount: 3,
    );
  }

  /// Fills in the English [TribunalPerson.statement] fallback text.
  static TribunalPerson _withEnglishStatement(
    TribunalPerson person,
    List<String> names,
  ) {
    return TribunalPerson(
      name: person.name,
      isTruthTeller: person.isTruthTeller,
      statement: _englishStatement(person, names),
      kind: person.kind,
      targetIndex: person.targetIndex,
      secondTargetIndex: person.secondTargetIndex,
      claimsTruthTeller: person.claimsTruthTeller,
      pairRequiresBoth: person.pairRequiresBoth,
      countValue: person.countValue,
      countsTruthTellers: person.countsTruthTellers,
      statementStyle: person.statementStyle,
    );
  }

  static String _englishStatement(TribunalPerson p, List<String> names) {
    switch (p.kind) {
      case TribunalClaimKind.single:
        final name = names[p.targetIndex];
        if (p.claimsTruthTeller) {
          switch (p.statementStyle) {
            case 0:
              return '"$name tells the truth."';
            case 1:
              return '"$name is trustworthy."';
            default:
              return '"$name is a truth-teller."';
          }
        }
        switch (p.statementStyle) {
          case 0:
            return '"$name is a liar."';
          case 1:
            return '"$name cannot be trusted."';
          default:
            return '"$name always lies."';
        }
      case TribunalClaimKind.pair:
        final a = names[p.targetIndex];
        final b = names[p.secondTargetIndex];
        if (p.pairRequiresBoth) {
          if (p.claimsTruthTeller) {
            return p.statementStyle == 0
                ? '"$a and $b both tell the truth."'
                : '"You can trust both $a and $b."';
          }
          return p.statementStyle == 0
              ? '"$a and $b are both liars."'
              : '"Neither $a nor $b tells the truth."';
        }
        if (p.claimsTruthTeller) {
          return '"At least one of $a and $b tells the truth."';
        }
        return '"At least one of $a and $b is a liar."';
      case TribunalClaimKind.count:
        final noun = p.countsTruthTellers ? 'truth-teller' : 'liar';
        if (p.countValue == 0) return '"None of us is a $noun."';
        if (p.countValue == 1) return '"Exactly one of us is a $noun."';
        return '"Exactly ${p.countValue} of us are ${noun}s."';
    }
  }
}
