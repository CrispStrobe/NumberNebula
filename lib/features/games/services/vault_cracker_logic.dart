import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// A clue for a single attempt: the attempted code + text describing feedback
class VaultClue {
  final List<int> attempt;
  final int correctPosition; // digits correct and in right position
  final int correctDigit; // digits correct but wrong position
  final int wrong; // digits not in code at all
  final String clueTextEn;
  final String clueTextDe;

  const VaultClue({
    required this.attempt,
    required this.correctPosition,
    required this.correctDigit,
    required this.wrong,
    required this.clueTextEn,
    required this.clueTextDe,
  });
}

/// Result of puzzle generation
class VaultCrackerPuzzle {
  final List<int> secretCode;
  final int codeLength;
  final int digitRange; // digits go from 0 to digitRange-1
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

class VaultCrackerLogic {
  /// Evaluate how many digits are correct-position, correct-but-misplaced, and wrong
  static (int correctPos, int correctDigit, int wrong) _evaluate(
      List<int> secret, List<int> guess) {
    final len = secret.length;
    final secretUsed = List<bool>.filled(len, false);
    final guessUsed = List<bool>.filled(len, false);
    int correctPos = 0;
    int correctDigit = 0;

    // First pass: exact matches
    for (int i = 0; i < len; i++) {
      if (guess[i] == secret[i]) {
        correctPos++;
        secretUsed[i] = true;
        guessUsed[i] = true;
      }
    }

    // Second pass: misplaced
    for (int i = 0; i < len; i++) {
      if (guessUsed[i]) continue;
      for (int j = 0; j < len; j++) {
        if (secretUsed[j]) continue;
        if (guess[i] == secret[j]) {
          correctDigit++;
          secretUsed[j] = true;
          break;
        }
      }
    }

    final wrong = len - correctPos - correctDigit;
    return (correctPos, correctDigit, wrong);
  }

  /// Build clue text from feedback counts
  static (String en, String de) _buildClueText(
      int correctPos, int correctDigit, int wrong, int codeLength) {
    final partsEn = <String>[];
    final partsDe = <String>[];

    if (correctPos == codeLength) {
      return ('All digits correct and in the right position!',
          'Alle Ziffern korrekt und an der richtigen Stelle!');
    }

    if (correctPos > 0) {
      partsEn.add(
          '$correctPos ${correctPos == 1 ? "digit" : "digits"} correct, in the right position');
      partsDe.add(
          '$correctPos ${correctPos == 1 ? "Ziffer" : "Ziffern"} korrekt, an der richtigen Stelle');
    }
    if (correctDigit > 0) {
      partsEn.add(
          '$correctDigit ${correctDigit == 1 ? "digit" : "digits"} correct, but in the wrong position');
      partsDe.add(
          '$correctDigit ${correctDigit == 1 ? "Ziffer" : "Ziffern"} korrekt, aber an falscher Stelle');
    }
    if (wrong == codeLength) {
      return ('All digits wrong', 'Alle Ziffern falsch');
    }
    if (wrong > 0) {
      partsEn
          .add('$wrong ${wrong == 1 ? "digit" : "digits"} completely wrong');
      partsDe.add(
          '$wrong ${wrong == 1 ? "Ziffer" : "Ziffern"} komplett falsch');
    }

    return (partsEn.join(', '), partsDe.join(', '));
  }

  /// Check that exactly one code in the given range satisfies all clues
  static bool _hasUniqueSolution(
      List<VaultClue> clues, List<int> secret, int codeLength, int digitRange) {
    int solutions = 0;

    void search(List<int> candidate, int pos) {
      if (solutions > 1) return; // early exit
      if (pos == codeLength) {
        // Check all clues
        for (final clue in clues) {
          final (cp, cd, _) = _evaluate(candidate, clue.attempt);
          if (cp != clue.correctPosition || cd != clue.correctDigit) return;
        }
        solutions++;
        return;
      }
      for (int d = 0; d < digitRange; d++) {
        candidate[pos] = d;
        search(candidate, pos + 1);
        if (solutions > 1) return;
      }
    }

    search(List<int>.filled(codeLength, 0), 0);
    return solutions == 1;
  }

  /// Generate a set of clue-attempts that uniquely determine the secret code
  static List<VaultClue> _generateClues(
      List<int> secret, int codeLength, int digitRange, int clueCount,
      math.Random rng) {
    // We generate random attempts and compute their feedback.
    // Then we verify the clue set uniquely determines the secret.
    // If not, we add more clues until it does (up to a limit).

    for (int globalAttempt = 0; globalAttempt < 100; globalAttempt++) {
      final clues = <VaultClue>[];

      // Generate candidate clue-attempts
      for (int i = 0; i < clueCount + 5; i++) {
        final attempt = List.generate(codeLength, (_) => rng.nextInt(digitRange));
        // Skip if attempt IS the secret
        bool isSame = true;
        for (int j = 0; j < codeLength; j++) {
          if (attempt[j] != secret[j]) {
            isSame = false;
            break;
          }
        }
        if (isSame) continue;

        final (cp, cd, w) = _evaluate(secret, attempt);
        final (en, de) = _buildClueText(cp, cd, w, codeLength);
        clues.add(VaultClue(
          attempt: attempt,
          correctPosition: cp,
          correctDigit: cd,
          wrong: w,
          clueTextEn: en,
          clueTextDe: de,
        ));
      }

      // Try subsets of increasing size starting from clueCount
      for (int size = clueCount;
          size <= clues.length && size <= clueCount + 3;
          size++) {
        final subset = clues.sublist(0, size);
        if (_hasUniqueSolution(subset, secret, codeLength, digitRange)) {
          return subset;
        }
      }
    }

    // Fallback: return all generated clues (should rarely happen with small digit ranges)
    debugPrint('[VAULT_CRACKER] Warning: could not guarantee unique solution');
    final fallbackClues = <VaultClue>[];
    for (int d = 0; d < digitRange && fallbackClues.length < clueCount; d++) {
      final attempt = List.generate(codeLength, (_) => d);
      final (cp, cd, w) = _evaluate(secret, attempt);
      final (en, de) = _buildClueText(cp, cd, w, codeLength);
      fallbackClues.add(VaultClue(
        attempt: attempt,
        correctPosition: cp,
        correctDigit: cd,
        wrong: w,
        clueTextEn: en,
        clueTextDe: de,
      ));
    }
    return fallbackClues;
  }

  static VaultCrackerPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    debugPrint(
        '[VAULT_CRACKER] Generating static deduction puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int codeLength;
    int digitRange;
    int clueCount;

    if (difficulty.grade <= 1) {
      codeLength = 3;
      digitRange = 5; // digits 0-4
      clueCount = 4;
    } else if (difficulty.grade <= 2) {
      codeLength = level <= 5 ? 3 : 4;
      digitRange = level <= 5 ? 6 : 6;
      clueCount = level <= 5 ? 4 : 5;
    } else if (difficulty.grade <= 3) {
      codeLength = level <= 3 ? 4 : 4;
      digitRange = level <= 3 ? 6 : 7;
      clueCount = level <= 3 ? 4 : 5;
    } else {
      codeLength = level <= 5 ? 4 : 5;
      digitRange = level <= 5 ? 7 : 8;
      clueCount = level <= 5 ? 5 : 5;
    }

    // Generate secret code
    final secretCode = List.generate(codeLength, (_) => rng.nextInt(digitRange));

    final clues =
        _generateClues(secretCode, codeLength, digitRange, clueCount, rng);

    debugPrint(
        '[VAULT_CRACKER] Generated code: $secretCode, clues=${clues.length}, '
        'codeLength=$codeLength, digitRange=$digitRange');

    return VaultCrackerPuzzle(
      secretCode: secretCode,
      codeLength: codeLength,
      digitRange: digitRange,
      clues: clues,
    );
  }
}
