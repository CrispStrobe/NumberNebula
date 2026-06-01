import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A mathematical constraint clue about the secret code.
/// Each clue describes a property of the digits (sum, comparison, parity, etc.)
class VaultClue {
  final String clueTextEn;
  final String clueTextDe;
  /// Function that checks if a candidate code satisfies this clue
  final bool Function(List<int>) check;

  const VaultClue({
    required this.clueTextEn,
    required this.clueTextDe,
    required this.check,
  });
}

/// Result of puzzle generation
class VaultCrackerPuzzle {
  final List<int> secretCode;
  final int codeLength;
  final int digitRange; // digits go from 1 to digitRange
  final List<VaultClue> clues;

  const VaultCrackerPuzzle({
    required this.secretCode,
    required this.codeLength,
    required this.digitRange,
    required this.clues,
  });

  /// Check if a guess matches the secret code
  bool isCorrect(List<int> guess) {
    if (guess.length != codeLength) return false;
    for (int i = 0; i < codeLength; i++) {
      if (guess[i] != secretCode[i]) return false;
    }
    return true;
  }
}

/// Clue template: generates a clue from a secret code.
/// Returns null if the clue is trivial or unhelpful for this particular code.
typedef _ClueFactory = VaultClue? Function(List<int> secret, int digitRange);

class VaultCrackerLogic {
  /// Count how many codes in the given range satisfy ALL clues.
  /// Returns the count (stops at 2 for efficiency — we only need to know if unique).
  static int _countSolutions(
      List<VaultClue> clues, int codeLength, int digitRange) {
    int solutions = 0;

    void search(List<int> candidate, int pos) {
      if (solutions > 1) return;
      if (pos == codeLength) {
        for (final clue in clues) {
          if (!clue.check(candidate)) return;
        }
        solutions++;
        return;
      }
      for (int d = 1; d <= digitRange; d++) {
        candidate[pos] = d;
        search(candidate, pos + 1);
        if (solutions > 1) return;
      }
    }

    search(List<int>.filled(codeLength, 0), 0);
    return solutions;
  }

  /// All available clue factories. Each takes the secret code and digit range,
  /// and returns a VaultClue if applicable, or null if trivial.
  static final List<_ClueFactory> _clueFactories = [
    // Sum of all digits
    (secret, range) {
      final sum = secret.fold(0, (s, d) => s + d);
      return VaultClue(
        clueTextEn: 'The sum of all digits is $sum.',
        clueTextDe: 'Die Summe aller Ziffern ist $sum.',
        check: (c) => c.fold(0, (s, d) => s + d) == sum,
      );
    },
    // Product of first two digits
    (secret, range) {
      if (secret.length < 2) return null;
      final prod = secret[0] * secret[1];
      return VaultClue(
        clueTextEn: 'The product of the 1st and 2nd digit is $prod.',
        clueTextDe: 'Das Produkt der 1. und 2. Ziffer ist $prod.',
        check: (c) => c[0] * c[1] == prod,
      );
    },
    // Difference of first and last
    (secret, range) {
      final diff = (secret.first - secret.last).abs();
      return VaultClue(
        clueTextEn: 'The difference between the 1st and last digit is $diff.',
        clueTextDe: 'Die Differenz zwischen 1. und letzter Ziffer ist $diff.',
        check: (c) => (c.first - c.last).abs() == diff,
      );
    },
    // A specific digit is even/odd
    (secret, range) {
      final pos = secret.length > 2 ? 1 : 0; // 2nd digit if available
      final isEven = secret[pos] % 2 == 0;
      final posLabel = pos == 0 ? '1st' : '${pos + 1}${pos == 1 ? 'nd' : pos == 2 ? 'rd' : 'th'}';
      final posLabelDe = '${pos + 1}.';
      return VaultClue(
        clueTextEn: 'The $posLabel digit is ${isEven ? "even" : "odd"}.',
        clueTextDe: 'Die $posLabelDe Ziffer ist ${isEven ? "gerade" : "ungerade"}.',
        check: (c) => (c[pos] % 2 == 0) == isEven,
      );
    },
    // One digit is greater than another
    (secret, range) {
      if (secret.length < 2) return null;
      final i = 0, j = secret.length - 1;
      if (secret[i] == secret[j]) return null;
      final greater = secret[i] > secret[j];
      return VaultClue(
        clueTextEn: greater
            ? 'The 1st digit is larger than the last digit.'
            : 'The 1st digit is smaller than the last digit.',
        clueTextDe: greater
            ? 'Die 1. Ziffer ist größer als die letzte Ziffer.'
            : 'Die 1. Ziffer ist kleiner als die letzte Ziffer.',
        check: (c) => greater ? c[i] > c[j] : c[i] < c[j],
      );
    },
    // No digit repeats (or some digit repeats)
    (secret, range) {
      final unique = secret.toSet().length == secret.length;
      return VaultClue(
        clueTextEn: unique
            ? 'All digits are different.'
            : 'At least two digits are the same.',
        clueTextDe: unique
            ? 'Alle Ziffern sind verschieden.'
            : 'Mindestens zwei Ziffern sind gleich.',
        check: (c) => (c.toSet().length == c.length) == unique,
      );
    },
    // A specific digit value is known
    (secret, range) {
      final pos = secret.length > 2 ? 2 : 0;
      final posLabel = pos == 0 ? '1st' : '${pos + 1}${pos == 1 ? 'nd' : pos == 2 ? 'rd' : 'th'}';
      final posLabelDe = '${pos + 1}.';
      return VaultClue(
        clueTextEn: 'The $posLabel digit is ${secret[pos]}.',
        clueTextDe: 'Die $posLabelDe Ziffer ist ${secret[pos]}.',
        check: (c) => c[pos] == secret[pos],
      );
    },
    // Sum of first two equals last (or similar arithmetic relation)
    (secret, range) {
      if (secret.length < 3) return null;
      final sumFirst = secret[0] + secret[1];
      if (sumFirst != secret[2] || sumFirst > range) return null;
      return VaultClue(
        clueTextEn: 'The 3rd digit equals the sum of the 1st and 2nd.',
        clueTextDe: 'Die 3. Ziffer ist die Summe der 1. und 2. Ziffer.',
        check: (c) => c[0] + c[1] == c[2],
      );
    },
    // Digits are in ascending/descending order
    (secret, range) {
      bool ascending = true, descending = true;
      for (int i = 1; i < secret.length; i++) {
        if (secret[i] <= secret[i - 1]) ascending = false;
        if (secret[i] >= secret[i - 1]) descending = false;
      }
      if (!ascending && !descending) {
        return VaultClue(
          clueTextEn: 'The digits are NOT in ascending or descending order.',
          clueTextDe: 'Die Ziffern sind NICHT auf- oder absteigend sortiert.',
          check: (c) {
            bool asc = true, desc = true;
            for (int i = 1; i < c.length; i++) {
              if (c[i] <= c[i - 1]) asc = false;
              if (c[i] >= c[i - 1]) desc = false;
            }
            return !asc && !desc;
          },
        );
      }
      if (ascending) {
        return VaultClue(
          clueTextEn: 'The digits are in ascending order.',
          clueTextDe: 'Die Ziffern sind aufsteigend sortiert.',
          check: (c) {
            for (int i = 1; i < c.length; i++) {
              if (c[i] <= c[i - 1]) return false;
            }
            return true;
          },
        );
      }
      return VaultClue(
        clueTextEn: 'The digits are in descending order.',
        clueTextDe: 'Die Ziffern sind absteigend sortiert.',
        check: (c) {
          for (int i = 1; i < c.length; i++) {
            if (c[i] >= c[i - 1]) return false;
          }
          return true;
        },
      );
    },
    // Maximum digit value
    (secret, range) {
      final maxVal = secret.reduce(math.max);
      return VaultClue(
        clueTextEn: 'The largest digit is $maxVal.',
        clueTextDe: 'Die größte Ziffer ist $maxVal.',
        check: (c) => c.reduce(math.max) == maxVal,
      );
    },
    // Minimum digit value
    (secret, range) {
      final minVal = secret.reduce(math.min);
      return VaultClue(
        clueTextEn: 'The smallest digit is $minVal.',
        clueTextDe: 'Die kleinste Ziffer ist $minVal.',
        check: (c) => c.reduce(math.min) == minVal,
      );
    },
    // Middle digit parity (for 3+ digit codes)
    (secret, range) {
      if (secret.length < 3) return null;
      final mid = secret.length ~/ 2;
      final isEven = secret[mid] % 2 == 0;
      return VaultClue(
        clueTextEn: 'The middle digit is ${isEven ? "even" : "odd"}.',
        clueTextDe: 'Die mittlere Ziffer ist ${isEven ? "gerade" : "ungerade"}.',
        check: (c) => (c[c.length ~/ 2] % 2 == 0) == isEven,
      );
    },
    // Product of all digits
    (secret, range) {
      final prod = secret.fold(1, (p, d) => p * d);
      if (prod > 100) return null; // too large, not helpful
      return VaultClue(
        clueTextEn: 'The product of all digits is $prod.',
        clueTextDe: 'Das Produkt aller Ziffern ist $prod.',
        check: (c) => c.fold(1, (p, d) => p * d) == prod,
      );
    },
  ];

  static VaultCrackerPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    debugPrint(
        '[VAULT_CRACKER] Generating algebraic constraint puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int codeLength;
    int digitRange; // digits 1..digitRange
    int targetClueCount;

    if (difficulty.grade <= 1) {
      codeLength = 3;
      digitRange = 5;
      targetClueCount = 4;
    } else if (difficulty.grade <= 2) {
      codeLength = level <= 5 ? 3 : 3;
      digitRange = level <= 5 ? 6 : 7;
      targetClueCount = level <= 5 ? 4 : 5;
    } else if (difficulty.grade <= 3) {
      codeLength = level <= 3 ? 3 : 4;
      digitRange = level <= 3 ? 6 : 6;
      targetClueCount = level <= 3 ? 4 : 5;
    } else {
      codeLength = level <= 5 ? 4 : 4;
      digitRange = level <= 5 ? 7 : 8;
      targetClueCount = level <= 5 ? 5 : 6;
    }

    // Try generating puzzles until we find one with a unique solution
    for (int attempt = 0; attempt < 200; attempt++) {
      // Generate secret code with digits 1..digitRange
      final secretCode = List.generate(codeLength, (_) => rng.nextInt(digitRange) + 1);

      // Generate all applicable clues for this code
      final applicableClues = <VaultClue>[];
      final shuffledFactories = List<_ClueFactory>.from(_clueFactories)..shuffle(rng);

      for (final factory in shuffledFactories) {
        final clue = factory(secretCode, digitRange);
        if (clue != null) {
          applicableClues.add(clue);
        }
      }

      if (applicableClues.length < targetClueCount) continue;

      // Try subsets of clues to find one that uniquely determines the code
      for (int size = targetClueCount;
          size <= applicableClues.length && size <= targetClueCount + 2;
          size++) {
        final clueSubset = applicableClues.sublist(0, size);
        final solutions = _countSolutions(clueSubset, codeLength, digitRange);

        if (solutions == 1) {
          debugPrint(
              '[VAULT_CRACKER] Generated code: $secretCode, clues=${clueSubset.length}, '
              'codeLength=$codeLength, digitRange=1-$digitRange');

          return VaultCrackerPuzzle(
            secretCode: secretCode,
            codeLength: codeLength,
            digitRange: digitRange,
            clues: clueSubset,
          );
        }
      }
    }

    // Fallback: generate a simple puzzle with direct digit clues
    debugPrint('[VAULT_CRACKER] Warning: falling back to direct-clue puzzle');
    final secretCode = List.generate(codeLength, (_) => rng.nextInt(digitRange) + 1);
    final clues = <VaultClue>[];

    // Give away all but one digit directly, plus the sum
    for (int i = 0; i < codeLength - 1; i++) {
      final pos = i;
      final val = secretCode[pos];
      final posLabel = '${pos + 1}${pos == 0 ? 'st' : pos == 1 ? 'nd' : pos == 2 ? 'rd' : 'th'}';
      clues.add(VaultClue(
        clueTextEn: 'The $posLabel digit is $val.',
        clueTextDe: 'Die ${pos + 1}. Ziffer ist $val.',
        check: (c) => c[pos] == val,
      ));
    }
    final sum = secretCode.fold(0, (s, d) => s + d);
    clues.add(VaultClue(
      clueTextEn: 'The sum of all digits is $sum.',
      clueTextDe: 'Die Summe aller Ziffern ist $sum.',
      check: (c) => c.fold(0, (s, d) => s + d) == sum,
    ));

    return VaultCrackerPuzzle(
      secretCode: secretCode,
      codeLength: codeLength,
      digitRange: digitRange,
      clues: clues,
    );
  }
}
