import 'dart:math' as math;

/// Standard die: opposite faces sum to 7.
/// Face indices: 0=top, 1=front, 2=right, 3=left, 4=back, 5=bottom
class Die {
  final List<int> faces;

  Die(this.faces)
      : assert(faces.length == 6),
        assert(faces[0] + faces[5] == 7),
        assert(faces[1] + faces[4] == 7),
        assert(faces[2] + faces[3] == 7);

  int get top => faces[0];
  int get front => faces[1];
  int get right => faces[2];
  int get left => faces[3];
  int get back => faces[4];
  int get bottom => faces[5];

  int faceByName(String name) {
    switch (name) {
      case 'top':
        return top;
      case 'front':
        return front;
      case 'right':
        return right;
      case 'left':
        return left;
      case 'back':
        return back;
      case 'bottom':
        return bottom;
      default:
        throw ArgumentError('Unknown face: $name');
    }
  }

  /// All 24 valid orientations of a standard Western die.
  /// Standard die: when 1 is on top and 2 faces you, 3 is on your right.
  static List<Die> _allOrientations() {
    // Build by enumerating all (top, front) pairs and computing right
    // using the chirality of a standard Western die.
    //
    // Encode the standard die as a rotation group acting on face values.
    // Base orientation: top=1, front=2, right=3, left=4, back=5, bottom=6
    //
    // We enumerate by placing each of the 6 values on top (6 choices),
    // then rotating the 4 side faces (4 choices) = 24 orientations.

    // For each face-on-top, define the cycle of (front, right, back, left)
    // when rotating clockwise (viewed from top).
    // These are determined by the standard Western die chirality.
    final Map<int, List<List<int>>> topRotations = {
      1: [
        [2, 3, 5, 4],
        [3, 5, 4, 2],
        [5, 4, 2, 3],
        [4, 2, 3, 5],
      ],
      2: [
        [6, 3, 1, 4],
        [3, 1, 4, 6],
        [1, 4, 6, 3],
        [4, 6, 3, 1],
      ],
      3: [
        [2, 6, 5, 1],
        [6, 5, 1, 2],
        [5, 1, 2, 6],
        [1, 2, 6, 5],
      ],
      4: [
        [2, 1, 5, 6],
        [1, 5, 6, 2],
        [5, 6, 2, 1],
        [6, 2, 1, 5],
      ],
      5: [
        [1, 3, 6, 4],
        [3, 6, 4, 1],
        [6, 4, 1, 3],
        [4, 1, 3, 6],
      ],
      6: [
        [2, 4, 5, 3],
        [4, 5, 3, 2],
        [5, 3, 2, 4],
        [3, 2, 4, 5],
      ],
    };

    final results = <Die>[];
    for (final topVal in topRotations.keys) {
      final bottomVal = 7 - topVal;
      for (final rot in topRotations[topVal]!) {
        // rot = [front, right, back, left]
        results.add(Die([topVal, rot[0], rot[1], rot[3], rot[2], bottomVal]));
      }
    }
    return results;
  }

  static List<Die>? _cachedOrientations;

  factory Die.random(math.Random rng) {
    _cachedOrientations ??= _allOrientations();
    return _cachedOrientations![rng.nextInt(_cachedOrientations!.length)];
  }

  /// Roll the die forward (top goes to front, front goes to bottom, etc.)
  Die rollForward() => Die([faces[1], faces[5], faces[2], faces[3], faces[0], faces[4]]);

  /// Roll the die backward (top goes to back)
  Die rollBackward() => Die([faces[4], faces[0], faces[2], faces[3], faces[5], faces[1]]);

  /// Roll the die to the right (top goes to right)
  Die rollRight() => Die([faces[3], faces[1], faces[0], faces[5], faces[4], faces[2]]);

  /// Roll the die to the left (top goes to left)
  Die rollLeft() => Die([faces[2], faces[1], faces[5], faces[0], faces[4], faces[3]]);
}

/// Which faces of a die are visible in the isometric view.
/// In our isometric projection we always show: top, left-front, right-front.
class VisibleFaces {
  final int? top;
  final int? front;
  final int? right;
  final int? left;

  const VisibleFaces({this.top, this.front, this.right, this.left});

  List<MapEntry<String, int>> get visibleEntries {
    final entries = <MapEntry<String, int>>[];
    if (top != null) entries.add(MapEntry('Top', top!));
    if (front != null) entries.add(MapEntry('Front', front!));
    if (right != null) entries.add(MapEntry('Right', right!));
    if (left != null) entries.add(MapEntry('Left', left!));
    return entries;
  }

  int get visibleSum {
    int s = 0;
    if (top != null) s += top!;
    if (front != null) s += front!;
    if (right != null) s += right!;
    if (left != null) s += left!;
    return s;
  }
}

/// Types of questions we can ask.
enum QuestionType {
  /// "What value is on the BOTTOM face?" (single die, grade 1-2)
  singleHiddenFace,

  /// "What is the sum of the three HIDDEN faces?" (single die, grade 1-2)
  hiddenFaceSum,

  /// "What value is on face X of die Y?" (multi-die, grade 3-4)
  chainedHiddenFace,
}

/// Arrangement of multiple dice.
enum DiceArrangement {
  single,
  verticalStack, // die 1 bottom touches die 2 top
  horizontalRow, // die 1 right touches die 2 left
}

/// A complete puzzle.
class CubeScannerPuzzle {
  final List<Die> dice;
  final List<VisibleFaces> visibleFaces;
  final DiceArrangement arrangement;
  final String questionText;
  final int correctAnswer;
  final List<int> choices; // 5 options including the correct one
  int get diceCount => dice.length;

  // Kept for backward compatibility with existing code references
  Map<int, String> get questions => {0: questionText};
  Map<int, int> get correctAnswers => {0: correctAnswer};

  CubeScannerPuzzle({
    required this.dice,
    required this.visibleFaces,
    required this.arrangement,
    required this.questionText,
    required this.correctAnswer,
    required this.choices,
  });
}

class CubeScannerGenerator {
  final math.Random _random;

  CubeScannerGenerator({int? seed}) : _random = math.Random(seed);

  CubeScannerPuzzle generate({required int grade, required int level}) {
    if (grade <= 1 && level <= 3) {
      return _generateSingleDie(grade, level); // easy intro
    } else if (grade <= 2) {
      // Alternate between bottom-face and rotation puzzles
      return _random.nextBool()
          ? _generateSingleDie(grade, level)
          : _generateRollPuzzle(grade, level);
    } else if (grade == 3) {
      return _generateStackedDice(level);
    } else {
      return level > 6
          ? _generateRowDice(level)
          : _generateStackedDice(level);
    }
  }

  // ---------------------------------------------------------------------------
  // Single die (grade 1-2)
  // ---------------------------------------------------------------------------
  CubeScannerPuzzle _generateSingleDie(int grade, int level) {
    final die = Die.random(_random);
    // Isometric view: always show top, front, right
    final visible = VisibleFaces(
      top: die.top,
      front: die.front,
      right: die.right,
    );

    int correctAnswer;
    String questionText;

    final bool askBottomFace = grade <= 1 || level <= 4;

    if (askBottomFace) {
      // "What is on the BOTTOM face?"
      correctAnswer = die.bottom; // = 7 - top
      questionText = 'What value is on the BOTTOM face?';
    } else {
      // "What is the sum of the three HIDDEN faces?"
      correctAnswer = 21 - visible.visibleSum;
      questionText = 'What is the sum of the 3 hidden faces?';
    }

    // Choices MUST match the question type's valid range
    final choices = askBottomFace
        ? _generateChoices(correctAnswer, min: 1, max: 6)
        : _generateChoices(correctAnswer, min: 3, max: 18);

    return CubeScannerPuzzle(
      dice: [die],
      visibleFaces: [visible],
      arrangement: DiceArrangement.single,
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: choices,
    );
  }

  // ---------------------------------------------------------------------------
  // Roll puzzle: show a die, describe rolls, ask what's on top
  // ---------------------------------------------------------------------------
  CubeScannerPuzzle _generateRollPuzzle(int grade, int level) {
    var die = Die.random(_random);

    // Generate 1-3 rolls depending on level
    final rollCount = level <= 5 ? 1 : (level <= 10 ? 2 : 3);
    const rollNames = ['forward', 'backward', 'left', 'right'];
    final rolls = <String>[];

    for (int i = 0; i < rollCount; i++) {
      final rollType = rollNames[_random.nextInt(rollNames.length)];
      rolls.add(rollType);
      switch (rollType) {
        case 'forward': die = die.rollForward(); break;
        case 'backward': die = die.rollBackward(); break;
        case 'left': die = die.rollLeft(); break;
        case 'right': die = die.rollRight(); break;
      }
    }

    // Show the initial die state
    final initialDie = Die.random(_random);
    var resultDie = initialDie;
    final actualRolls = <String>[];
    for (int i = 0; i < rollCount; i++) {
      final rollType = rollNames[_random.nextInt(rollNames.length)];
      actualRolls.add(rollType);
      switch (rollType) {
        case 'forward': resultDie = resultDie.rollForward(); break;
        case 'backward': resultDie = resultDie.rollBackward(); break;
        case 'left': resultDie = resultDie.rollLeft(); break;
        case 'right': resultDie = resultDie.rollRight(); break;
      }
    }

    final visible = VisibleFaces(
      top: initialDie.top,
      front: initialDie.front,
      right: initialDie.right,
    );

    final rollDesc = actualRolls.join(', then ');
    final questionText = 'Roll $rollDesc. What is on TOP?';
    final correctAnswer = resultDie.top;
    final choices = _generateChoices(correctAnswer, min: 1, max: 6);

    return CubeScannerPuzzle(
      dice: [initialDie],
      visibleFaces: [visible],
      arrangement: DiceArrangement.single,
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: choices,
    );
  }

  // ---------------------------------------------------------------------------
  // Two dice stacked vertically (grade 3)
  // Bottom of die1 touches top of die2 -- touching faces are EQUAL.
  // ---------------------------------------------------------------------------
  CubeScannerPuzzle _generateStackedDice(int level) {
    final die1 = Die.random(_random);
    // die1.bottom == die2.top  (touching faces equal)
    final touchValue = die1.bottom;

    // Find an orientation for die2 where top == touchValue
    Die? die2;
    Die._cachedOrientations ??= Die._allOrientations();
    final candidates = Die._cachedOrientations!
        .where((d) => d.top == touchValue)
        .toList();
    die2 = candidates[_random.nextInt(candidates.length)];

    final vis1 = VisibleFaces(top: die1.top, front: die1.front, right: die1.right);
    final vis2 = VisibleFaces(top: null, front: die2.front, right: die2.right);
    // die2.top is hidden (touching face)

    // Ask about die2's bottom, which requires chaining:
    // die1.bottom = X, die2.top = X, die2.bottom = 7 - X
    final correctAnswer = die2.bottom;
    const questionText =
        'The bottom of Cube 1 touches the top of Cube 2 (touching faces are equal).\n'
        'What value is on the BOTTOM of Cube 2?';

    final choices = _generateChoices(correctAnswer, min: 1, max: 6);

    return CubeScannerPuzzle(
      dice: [die1, die2],
      visibleFaces: [vis1, vis2],
      arrangement: DiceArrangement.verticalStack,
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: choices,
    );
  }

  // ---------------------------------------------------------------------------
  // Three dice in a row (grade 4)
  // die1.right == die2.left, die2.right == die3.left
  // ---------------------------------------------------------------------------
  CubeScannerPuzzle _generateRowDice(int level) {
    final die1 = Die.random(_random);
    final touch1 = die1.right; // die1.right == die2.left

    Die._cachedOrientations ??= Die._allOrientations();

    // Find die2 where left == touch1
    final candidates2 = Die._cachedOrientations!
        .where((d) => d.left == touch1)
        .toList();
    final die2 = candidates2[_random.nextInt(candidates2.length)];

    final touch2 = die2.right; // die2.right == die3.left
    final candidates3 = Die._cachedOrientations!
        .where((d) => d.left == touch2)
        .toList();
    final die3 = candidates3[_random.nextInt(candidates3.length)];

    final vis1 = VisibleFaces(top: die1.top, front: die1.front);
    final vis2 = VisibleFaces(top: die2.top, front: die2.front);
    final vis3 = VisibleFaces(top: die3.top, front: die3.front, right: die3.right);

    // Ask about die3's bottom (requires knowing die3.top -> bottom = 7 - top)
    // Or ask about die2's right (hidden, equals die3's left = 7 - die3.right)
    // Let's ask about die1's right face (hidden, requires deduction)
    final correctAnswer = die1.right;
    const questionText =
        'Three cubes in a row. Each cube\'s right face touches the next cube\'s left face (touching faces are equal).\n'
        'What value is on the RIGHT face of Cube 1?';

    final choices = _generateChoices(correctAnswer, min: 1, max: 6);

    return CubeScannerPuzzle(
      dice: [die1, die2, die3],
      visibleFaces: [vis1, vis2, vis3],
      arrangement: DiceArrangement.horizontalRow,
      questionText: questionText,
      correctAnswer: correctAnswer,
      choices: choices,
    );
  }

  // ---------------------------------------------------------------------------
  // Generate 5 multiple-choice options including the correct answer
  // ---------------------------------------------------------------------------
  List<int> _generateChoices(int correct, {required int min, required int max}) {
    final choices = <int>{correct};
    int attempts = 0;
    while (choices.length < 5 && attempts < 100) {
      final candidate = min + _random.nextInt(max - min + 1);
      choices.add(candidate);
      attempts++;
    }
    // If we couldn't get 5 unique, fill with sequential
    int fill = min;
    while (choices.length < 5) {
      choices.add(fill);
      fill++;
    }
    final list = choices.toList()..shuffle(_random);
    return list;
  }
}
