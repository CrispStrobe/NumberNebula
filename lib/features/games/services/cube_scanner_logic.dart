import 'dart:math' as math;

/// Standard die face layout: opposite faces sum to 7.
/// Face indices: 0=top, 1=front, 2=right, 3=left, 4=back, 5=bottom
/// Pairs: (0,5), (1,4), (2,3) -> each pair sums to 7.
class Die {
  /// The 6 face values [top, front, right, left, back, bottom].
  final List<int> faces;

  Die(this.faces);

  int get top => faces[0];
  int get front => faces[1];
  int get right => faces[2];
  int get left => faces[3];
  int get back => faces[4];
  int get bottom => faces[5];

  /// Generate a random valid die (opposite faces sum to 7).
  factory Die.random(math.Random rng) {
    // Standard die: 1-6, opposite faces sum to 7
    // top+bottom=7, front+back=7, left+right=7
    // We pick a random orientation
    final orientations = _allOrientations();
    return orientations[rng.nextInt(orientations.length)];
  }

  static List<Die> _allOrientations() {
    // Generate all 24 valid orientations of a standard die
    // Base: top=1, front=2, right=3 -> left=4, back=5, bottom=6
    final results = <Die>[];

    // All possible (top, front) pairs for a standard die
    final topFrontPairs = [
      [1, 2], [1, 3], [1, 5], [1, 4],
      [2, 6], [2, 3], [2, 1], [2, 4],
      [3, 6], [3, 2], [3, 1], [3, 5],
      [4, 1], [4, 2], [4, 6], [4, 5],
      [5, 1], [5, 3], [5, 6], [5, 4],
      [6, 2], [6, 4], [6, 5], [6, 3],
    ];

    for (final pair in topFrontPairs) {
      final top = pair[0];
      final front = pair[1];
      final bottom = 7 - top;
      final back = 7 - front;

      // Determine right based on top and front using cross product logic
      final right = _determineRight(top, front);
      if (right == 0) continue;
      final left = 7 - right;

      results.add(Die([top, front, right, left, back, bottom]));
    }

    // Fallback: if logic is complex, just return a few standard orientations
    if (results.isEmpty) {
      results.add(Die([1, 2, 3, 4, 5, 6]));
      results.add(Die([2, 1, 4, 3, 6, 5]));
      results.add(Die([3, 1, 2, 5, 6, 4]));
    }

    return results;
  }

  static int _determineRight(int top, int front) {
    // Given top and front of a standard die, determine the right face
    // This is based on the standard die convention
    final remaining = {1, 2, 3, 4, 5, 6}
      ..remove(top)
      ..remove(7 - top)
      ..remove(front)
      ..remove(7 - front);

    if (remaining.length != 2) return 0;
    final sorted = remaining.toList()..sort();
    // Convention: use first remaining value as right
    return sorted[0];
  }
}

/// Which faces of a die are visible to the player.
class VisibleFaces {
  final int? top;
  final int? front;
  final int? right;
  final int? left;

  VisibleFaces({this.top, this.front, this.right, this.left});

  List<MapEntry<String, int>> get visibleEntries {
    final entries = <MapEntry<String, int>>[];
    if (top != null) entries.add(MapEntry('top', top!));
    if (front != null) entries.add(MapEntry('front', front!));
    if (right != null) entries.add(MapEntry('right', right!));
    if (left != null) entries.add(MapEntry('left', left!));
    return entries;
  }
}

/// A puzzle where the player must deduce hidden face values.
class CubeScannerPuzzle {
  /// The dice in the puzzle.
  final List<Die> dice;

  /// Which faces are visible for each die.
  final List<VisibleFaces> visibleFaces;

  /// The question: which face of which die to determine.
  /// Map of dieIndex -> faceName (e.g., 'bottom')
  final Map<int, String> questions;

  /// The correct answers.
  final Map<int, int> correctAnswers;

  /// Number of dice.
  int get diceCount => dice.length;

  CubeScannerPuzzle({
    required this.dice,
    required this.visibleFaces,
    required this.questions,
    required this.correctAnswers,
  });
}

class CubeScannerGenerator {
  final math.Random _random;

  CubeScannerGenerator({int? seed}) : _random = math.Random(seed);

  /// Generate a puzzle:
  /// - grade 1: 1 die, 3 visible faces, find 1 hidden face
  /// - grade 2: 2 dice (stacked), find hidden faces
  /// - grade 3-4: 2-3 dice, fewer visible faces
  CubeScannerPuzzle generate({required int grade, required int level}) {
    int numDice;
    int visibleCount;

    if (grade <= 1) {
      numDice = 1;
      visibleCount = 3;
    } else if (grade <= 2) {
      numDice = 2;
      visibleCount = 2;
    } else if (grade <= 3) {
      numDice = 2 + (level > 8 ? 1 : 0);
      visibleCount = 2;
    } else {
      numDice = math.min(3, 2 + level ~/ 7);
      visibleCount = level > 10 ? 1 : 2;
    }

    final dice = <Die>[];
    final visible = <VisibleFaces>[];
    final questions = <int, String>{};
    final answers = <int, int>{};

    for (int i = 0; i < numDice; i++) {
      final die = Die.random(_random);
      dice.add(die);

      // Choose which faces to show
      final allFaces = ['top', 'front', 'right', 'left'];
      allFaces.shuffle(_random);
      final shownFaces = allFaces.take(visibleCount).toSet();

      visible.add(VisibleFaces(
        top: shownFaces.contains('top') ? die.top : null,
        front: shownFaces.contains('front') ? die.front : null,
        right: shownFaces.contains('right') ? die.right : null,
        left: shownFaces.contains('left') ? die.left : null,
      ));

      // Ask about a hidden face (opposite of a visible one)
      final hiddenOptions = <String, int>{};
      if (shownFaces.contains('top')) hiddenOptions['bottom'] = die.bottom;
      if (shownFaces.contains('front')) hiddenOptions['back'] = die.back;
      if (shownFaces.contains('right')) hiddenOptions['left'] = die.left;
      if (shownFaces.contains('left')) hiddenOptions['right'] = die.right;

      // Remove faces that are already shown from options
      hiddenOptions.removeWhere((key, _) => shownFaces.contains(key));

      if (hiddenOptions.isNotEmpty) {
        final entry =
            hiddenOptions.entries.elementAt(_random.nextInt(hiddenOptions.length));
        questions[i] = entry.key;
        answers[i] = entry.value;
      } else {
        // Fallback: ask about bottom
        questions[i] = 'bottom';
        answers[i] = die.bottom;
      }
    }

    return CubeScannerPuzzle(
      dice: dice,
      visibleFaces: visible,
      questions: questions,
      correctAnswers: answers,
    );
  }
}
