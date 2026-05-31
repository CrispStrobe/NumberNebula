import 'dart:math' as math;

/// 7-segment display segments are labeled a-g:
///  _a_
/// |   |
/// f   b
/// |_g_|
/// |   |
/// e   c
/// |_d_|
///
/// Each digit 0-9 maps to a set of active segments.
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

  static const List<String> allSegments = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

  /// Get the segments for a digit.
  static Set<String> getSegments(int digit) {
    return digitSegments[digit] ?? {};
  }

  /// Try to determine which digit a set of segments represents.
  /// Returns -1 if it doesn't match any valid digit.
  static int identifyDigit(Set<String> segments) {
    for (final entry in digitSegments.entries) {
      if (entry.value.length == segments.length &&
          entry.value.containsAll(segments)) {
        return entry.key;
      }
    }
    return -1;
  }

  /// Apply a segment swap to a digit's segments.
  /// Swaps segA and segB in the wiring, then returns the resulting segments.
  static Set<String> applySwap(Set<String> segments, String segA, String segB) {
    final result = <String>{};
    for (final seg in segments) {
      if (seg == segA) {
        result.add(segB);
      } else if (seg == segB) {
        result.add(segA);
      } else {
        result.add(seg);
      }
    }
    return result;
  }
}

/// A circuit repair puzzle.
class CircuitRepairPuzzle {
  /// The intended digits (correct display).
  final List<int> correctDigits;

  /// The corrupted digits (what the display shows after swap).
  final List<int> corruptedDigits;

  /// The corrupted segment sets for each digit position.
  final List<Set<String>> corruptedSegments;

  /// The two segments that are swapped (the answer).
  final String swappedSegA;
  final String swappedSegB;

  CircuitRepairPuzzle({
    required this.correctDigits,
    required this.corruptedDigits,
    required this.corruptedSegments,
    required this.swappedSegA,
    required this.swappedSegB,
  });

  /// Check if the player's answer is correct.
  bool checkAnswer(String segA, String segB) {
    return (segA == swappedSegA && segB == swappedSegB) ||
        (segA == swappedSegB && segB == swappedSegA);
  }
}

class CircuitRepairGenerator {
  final math.Random _random;

  CircuitRepairGenerator({int? seed}) : _random = math.Random(seed);

  /// Generate a puzzle:
  /// - grade 1: 1 digit display
  /// - grade 2: 2 digits
  /// - grade 3-4: 3+ digits
  CircuitRepairPuzzle generate({required int grade, required int level}) {
    int numDigits;

    if (grade <= 1) {
      numDigits = 1;
    } else if (grade <= 2) {
      numDigits = 2;
    } else if (grade <= 3) {
      numDigits = level > 8 ? 3 : 2;
    } else {
      numDigits = math.min(4, 2 + level ~/ 5);
    }

    return _generatePuzzle(numDigits);
  }

  CircuitRepairPuzzle _generatePuzzle(int numDigits) {
    // Try multiple times to find a valid swap
    for (int attempt = 0; attempt < 100; attempt++) {
      // Generate random target digits
      final correctDigits = List.generate(numDigits, (_) => _random.nextInt(10));

      // Pick two segments to swap
      final segments = List<String>.from(SevenSegment.allSegments);
      segments.shuffle(_random);
      final segA = segments[0];
      final segB = segments[1];

      // Apply the swap to all digits and check if the result is valid
      // (each corrupted display should still form a recognizable but wrong digit,
      // or at least a visually distinct pattern)
      final corruptedSegments = <Set<String>>[];
      final corruptedDigits = <int>[];
      bool allValid = true;

      for (final digit in correctDigits) {
        final original = SevenSegment.getSegments(digit);
        final swapped = SevenSegment.applySwap(original, segA, segB);
        final corruptedDigit = SevenSegment.identifyDigit(swapped);

        corruptedSegments.add(swapped);
        corruptedDigits.add(corruptedDigit);

        // We need at least one digit to actually change
        // It's OK if some digits stay the same (swap doesn't affect them)
      }

      // Check that at least one digit changed
      bool anyChanged = false;
      for (int i = 0; i < numDigits; i++) {
        if (corruptedDigits[i] != correctDigits[i]) {
          anyChanged = true;
          break;
        }
      }

      if (anyChanged && allValid) {
        return CircuitRepairPuzzle(
          correctDigits: correctDigits,
          corruptedDigits: corruptedDigits,
          corruptedSegments: corruptedSegments,
          swappedSegA: segA,
          swappedSegB: segB,
        );
      }
    }

    // Fallback: simple known-good puzzle
    return CircuitRepairPuzzle(
      correctDigits: [8],
      corruptedDigits: [0],
      corruptedSegments: [SevenSegment.applySwap(SevenSegment.getSegments(8), 'g', 'a')],
      swappedSegA: 'a',
      swappedSegB: 'g',
    );
  }
}
