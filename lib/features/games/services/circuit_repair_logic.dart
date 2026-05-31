import 'dart:math' as math;

/// 7-segment display encoding for digits 0-9.
/// Used only for rendering -- the puzzle logic is about digit POSITION swaps.
class SevenSegment {
  static const Map<int, Set<String>> digitSegments = {
    0: {'a', 'b', 'c', 'd', 'e', 'f'},
    1: {'b', 'c'},
    2: {'a', 'b', 'd', 'e', 'g'},
    3: {'a', 'b', 'c', 'd', 'g'},
    4: {'b', 'c', 'f', 'g'},
    5: {'a', 'c', 'd', 'f', 'g'},
    6: {'a', 'c', 'd', 'e', 'f', 'g'},
    7: {'a', 'b', 'c'},
    8: {'a', 'b', 'c', 'd', 'e', 'f', 'g'},
    9: {'a', 'b', 'c', 'd', 'f', 'g'},
  };

  /// Get the segments for a digit (0-9).
  static Set<String> getSegments(int digit) {
    return digitSegments[digit] ?? {};
  }
}

/// A circuit repair puzzle where two digit positions on a clock are swapped.
class CircuitRepairPuzzle {
  /// The correct time digits [H1, H2, M1, M2].
  final List<int> correctDigits;

  /// The displayed (invalid) digits after swapping two positions.
  final List<int> displayedDigits;

  /// The two swapped positions (indices 0-3).
  final int swapPosA;
  final int swapPosB;

  /// Max attempts allowed.
  final int maxAttempts;

  CircuitRepairPuzzle({
    required this.correctDigits,
    required this.displayedDigits,
    required this.swapPosA,
    required this.swapPosB,
    required this.maxAttempts,
  });

  /// Format digits as "HH:MM".
  String formatTime(List<int> digits) {
    return '${digits[0]}${digits[1]}:${digits[2]}${digits[3]}';
  }

  String get correctTimeString => formatTime(correctDigits);
  String get displayedTimeString => formatTime(displayedDigits);

  /// Check if a set of 4 digits represents a valid time (00:00 - 23:59).
  static bool isValidTime(List<int> digits) {
    final hours = digits[0] * 10 + digits[1];
    final minutes = digits[2] * 10 + digits[3];
    return hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59;
  }

  /// Apply a swap of two positions to a list of digits.
  static List<int> applySwap(List<int> digits, int posA, int posB) {
    final result = List<int>.from(digits);
    final temp = result[posA];
    result[posA] = result[posB];
    result[posB] = temp;
    return result;
  }

  /// Check if the player's swap produces a valid time.
  bool checkAnswer(int posA, int posB) {
    final a = math.min(posA, posB);
    final b = math.max(posA, posB);
    final correctA = math.min(swapPosA, swapPosB);
    final correctB = math.max(swapPosA, swapPosB);
    return a == correctA && b == correctB;
  }

  /// Apply a swap to the displayed digits and return the result.
  List<int> previewSwap(int posA, int posB) {
    return applySwap(displayedDigits, posA, posB);
  }

  /// Check if a specific pair of positions are the hours digits.
  static bool isHourDigit(int pos) => pos == 0 || pos == 1;

  /// Check if a specific pair of positions are the minute digits.
  static bool isMinuteDigit(int pos) => pos == 2 || pos == 3;

  /// Check whether the minutes portion of the displayed time is invalid (>= 60).
  bool get minutesInvalid {
    final minutes = displayedDigits[2] * 10 + displayedDigits[3];
    return minutes > 59;
  }

  /// Check whether the hours portion of the displayed time is invalid (>= 24).
  bool get hoursInvalid {
    final hours = displayedDigits[0] * 10 + displayedDigits[1];
    return hours > 23;
  }
}

class CircuitRepairGenerator {
  final math.Random _random;

  CircuitRepairGenerator({int? seed}) : _random = math.Random(seed);

  /// Generate a puzzle for the given grade and level.
  CircuitRepairPuzzle generate({required int grade, required int level}) {
    final maxAttempts = _maxAttempts(grade);

    // Try to produce a valid puzzle
    for (int attempt = 0; attempt < 200; attempt++) {
      final puzzle = _tryGenerate(grade: grade, maxAttempts: maxAttempts);
      if (puzzle != null) return puzzle;
    }

    // Fallback: the classic "15:69" -> "16:59" puzzle
    return CircuitRepairPuzzle(
      correctDigits: [1, 6, 5, 9],
      displayedDigits: [1, 5, 6, 9],
      swapPosA: 1,
      swapPosB: 2,
      maxAttempts: maxAttempts,
    );
  }

  int _maxAttempts(int grade) {
    if (grade <= 1) return 5;
    if (grade <= 2) return 4;
    return 3;
  }

  CircuitRepairPuzzle? _tryGenerate({
    required int grade,
    required int maxAttempts,
  }) {
    // 1. Generate a valid time based on grade
    final digits = _randomValidTime(grade);

    // 2. Pick two positions to swap
    final positions = [0, 1, 2, 3];
    positions.shuffle(_random);
    final posA = positions[0];
    final posB = positions[1];

    // The two digits must be different (otherwise the swap does nothing)
    if (digits[posA] == digits[posB]) return null;

    // 3. Apply the swap
    final displayed = CircuitRepairPuzzle.applySwap(digits, posA, posB);

    // 4. The displayed time must be INVALID
    if (CircuitRepairPuzzle.isValidTime(displayed)) return null;

    // 5. Ensure EXACTLY ONE swap of the displayed digits yields a valid time
    //    (the reverse of our swap). Check all 6 possible swaps.
    int validSwapCount = 0;
    for (int i = 0; i < 4; i++) {
      for (int j = i + 1; j < 4; j++) {
        final candidate = CircuitRepairPuzzle.applySwap(displayed, i, j);
        if (CircuitRepairPuzzle.isValidTime(candidate)) {
          validSwapCount++;
        }
      }
    }

    if (validSwapCount != 1) return null;

    return CircuitRepairPuzzle(
      correctDigits: digits,
      displayedDigits: displayed,
      swapPosA: posA,
      swapPosB: posB,
      maxAttempts: maxAttempts,
    );
  }

  /// Generate a random valid time depending on grade.
  List<int> _randomValidTime(int grade) {
    int hours;
    int minutes;

    if (grade <= 1) {
      // Grade 1: 10:00 - 12:59 (simpler digits)
      hours = 10 + _random.nextInt(3); // 10, 11, 12
      minutes = _random.nextInt(60);
    } else {
      // Grade 2+: full 00:00 - 23:59
      hours = _random.nextInt(24);
      minutes = _random.nextInt(60);
    }

    return [hours ~/ 10, hours % 10, minutes ~/ 10, minutes % 10];
  }
}
