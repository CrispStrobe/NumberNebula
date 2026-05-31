import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../constants/difficulty_manager.dart';

/// Feedback for a single digit in a guess
enum DigitFeedback { green, yellow, gray }

/// A clue attempt with feedback
class VaultClue {
  final List<int> guess;
  final List<DigitFeedback> feedback;

  const VaultClue({required this.guess, required this.feedback});
}

/// Result of puzzle generation
class VaultCrackerPuzzle {
  final List<int> secretCode;
  final int codeLength;
  final int maxAttempts;
  final int digitRange; // digits go from 0 to digitRange-1

  const VaultCrackerPuzzle({
    required this.secretCode,
    required this.codeLength,
    required this.maxAttempts,
    required this.digitRange,
  });

  /// Evaluate a guess against the secret code
  List<DigitFeedback> evaluate(List<int> guess) {
    final feedback = List<DigitFeedback>.filled(codeLength, DigitFeedback.gray);
    final secretUsed = List<bool>.filled(codeLength, false);
    final guessUsed = List<bool>.filled(codeLength, false);

    // First pass: find greens (correct digit, correct position)
    for (int i = 0; i < codeLength; i++) {
      if (guess[i] == secretCode[i]) {
        feedback[i] = DigitFeedback.green;
        secretUsed[i] = true;
        guessUsed[i] = true;
      }
    }

    // Second pass: find yellows (correct digit, wrong position)
    for (int i = 0; i < codeLength; i++) {
      if (guessUsed[i]) continue;
      for (int j = 0; j < codeLength; j++) {
        if (secretUsed[j]) continue;
        if (guess[i] == secretCode[j]) {
          feedback[i] = DigitFeedback.yellow;
          secretUsed[j] = true;
          break;
        }
      }
    }

    return feedback;
  }

  /// Check if guess matches secret
  bool isCorrect(List<int> guess) {
    if (guess.length != codeLength) return false;
    for (int i = 0; i < codeLength; i++) {
      if (guess[i] != secretCode[i]) return false;
    }
    return true;
  }
}

class VaultCrackerLogic {
  static VaultCrackerPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficulty = args['difficulty'] as DifficultyConfig;
    final rng = math.Random();

    debugPrint('[VAULT_CRACKER] Generating puzzle for grade=$grade, level=$level');

    // Difficulty scaling
    int codeLength;
    int maxAttempts;
    int digitRange;

    if (difficulty.grade <= 1) {
      codeLength = 3;
      maxAttempts = 8;
      digitRange = 6; // digits 0-5
    } else if (difficulty.grade <= 2) {
      codeLength = level <= 5 ? 3 : 4;
      maxAttempts = level <= 5 ? 7 : 6;
      digitRange = level <= 5 ? 6 : 8;
    } else if (difficulty.grade <= 3) {
      codeLength = level <= 3 ? 4 : 5;
      maxAttempts = level <= 3 ? 6 : 5;
      digitRange = 8;
    } else {
      codeLength = level <= 5 ? 4 : level <= 10 ? 5 : 6;
      maxAttempts = level <= 5 ? 5 : 4;
      digitRange = level <= 10 ? 8 : 10;
    }

    // Generate secret code
    final secretCode = List.generate(codeLength, (_) => rng.nextInt(digitRange));

    debugPrint('[VAULT_CRACKER] Generated code: $secretCode, length=$codeLength, maxAttempts=$maxAttempts, digitRange=$digitRange');

    return VaultCrackerPuzzle(
      secretCode: secretCode,
      codeLength: codeLength,
      maxAttempts: maxAttempts,
      digitRange: digitRange,
    );
  }
}
