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

/// Which face a question asks about.
enum CubeFace { top, front, right, left, back, bottom }

/// A quarter-turn of the cube, named from the player's point of view.
enum CubeRoll { forward, backward, left, right }

/// What a puzzle asks.
///
/// This used to be an English sentence baked into the puzzle by the
/// generator, which is why "The bottom of Cube 1 touches the top of Cube 2"
/// showed up in English no matter the app language -- there was no German
/// string for it to have. The question now travels as data and the screen
/// renders it through the normal localization, so a new language needs no
/// change here.
enum CubeQuestionKind {
  /// One face you cannot see, on a single cube.
  hiddenFace,

  /// The total of the three faces of a single cube that are turned away.
  hiddenFaceSum,

  /// A named face after the cube has been rolled a few times.
  rollToFace,

  /// Every pip that is hidden across a stack or row of cubes -- the faces
  /// turned away, the undersides, and the faces where the cubes touch.
  hiddenPips,
}

class CubeScannerQuestion {
  final CubeQuestionKind kind;

  /// The face asked about, for [CubeQuestionKind.hiddenFace] and
  /// [CubeQuestionKind.rollToFace].
  final CubeFace? face;

  /// The rolls to carry out, for [CubeQuestionKind.rollToFace].
  final List<CubeRoll> rolls;

  /// How many cubes are on the board.
  final int diceCount;

  const CubeScannerQuestion({
    required this.kind,
    this.face,
    this.rolls = const [],
    this.diceCount = 1,
  });
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
  final CubeScannerQuestion question;
  final int correctAnswer;
  final List<int> choices; // 5 options including the correct one
  int get diceCount => dice.length;

  CubeScannerPuzzle({
    required this.dice,
    required this.visibleFaces,
    required this.arrangement,
    required this.question,
    required this.correctAnswer,
    required this.choices,
  });
}

class CubeScannerGenerator {
  final math.Random _random;

  CubeScannerGenerator({int? seed}) : _random = math.Random(seed);

  /// Pick a puzzle for this grade and level.
  ///
  /// Every grade draws from more than one question type. The old generator
  /// gave grades 3 and 4 exactly one shape of question each, and both of them
  /// were answerable without any deduction at all: in the stack, cube 2's
  /// bottom works out to cube 1's *visible* top face every single time, and in
  /// the row, cube 1's right face works out to cube 3's visible right face.
  /// Both were solvable by copying a number off the screen, and there was only
  /// ever the one of them to play.
  CubeScannerPuzzle generate({required int grade, required int level}) {
    final g = grade.clamp(1, 4);

    final List<CubeScannerPuzzle Function()> options;
    switch (g) {
      case 1:
        options = level <= 3
            ? [() => _singleHiddenFace(easy: true)]
            : [
                () => _singleHiddenFace(easy: false),
                _singleHiddenSum,
              ];
      case 2:
        options = [
          _singleHiddenSum,
          () => _rollPuzzle(rollCount: level <= 8 ? 1 : 2),
          () => _singleHiddenFace(easy: false),
        ];
      case 3:
        options = [
          _stackHiddenPips,
          () => _rollPuzzle(rollCount: level <= 10 ? 2 : 3),
        ];
      default:
        options = [
          () => _rowHiddenPips(diceCount: 3),
          () => _rollPuzzle(rollCount: 3),
          _stackHiddenPips,
        ];
    }

    return options[_random.nextInt(options.length)]();
  }

  // ---------------------------------------------------------------------------
  // Single die
  // ---------------------------------------------------------------------------

  /// "Which value is on the {bottom|back|left} face?"
  ///
  /// [easy] pins the question to the bottom face, which is the one the
  /// onboarding works through. Past that the back and left faces come up too,
  /// so the same drawing does not always ask the same thing.
  CubeScannerPuzzle _singleHiddenFace({required bool easy}) {
    final die = Die.random(_random);
    final visible = VisibleFaces(
      top: die.top,
      front: die.front,
      right: die.right,
    );

    const askable = [CubeFace.bottom, CubeFace.back, CubeFace.left];
    final face = easy
        ? CubeFace.bottom
        : askable[_random.nextInt(askable.length)];

    final answer = switch (face) {
      CubeFace.bottom => die.bottom,
      CubeFace.back => die.back,
      CubeFace.left => die.left,
      CubeFace.top => die.top,
      CubeFace.front => die.front,
      CubeFace.right => die.right,
    };

    // The tempting mistake is reading off the face you can see instead of its
    // opposite, so that value is deliberately among the choices.
    final trap = 7 - answer;

    return CubeScannerPuzzle(
      dice: [die],
      visibleFaces: [visible],
      arrangement: DiceArrangement.single,
      question: CubeScannerQuestion(kind: CubeQuestionKind.hiddenFace, face: face),
      correctAnswer: answer,
      choices: _choices(answer, min: 1, max: 6, tempting: [trap]),
    );
  }

  /// "What is the total of the three faces you cannot see?"
  CubeScannerPuzzle _singleHiddenSum() {
    final die = Die.random(_random);
    final visible = VisibleFaces(
      top: die.top,
      front: die.front,
      right: die.right,
    );
    final answer = 21 - visible.visibleSum;

    return CubeScannerPuzzle(
      dice: [die],
      visibleFaces: [visible],
      arrangement: DiceArrangement.single,
      question: const CubeScannerQuestion(kind: CubeQuestionKind.hiddenFaceSum),
      correctAnswer: answer,
      // Adding up what you *can* see instead is the classic slip.
      choices: _choices(answer, min: 3, max: 18, tempting: [visible.visibleSum]),
    );
  }

  // ---------------------------------------------------------------------------
  // Rolling
  // ---------------------------------------------------------------------------

  /// "Roll the cube forward, then right. Which value is then on top?"
  ///
  /// The only question in the game that needs the cube turned in the head
  /// rather than a face swapped for 7 minus itself, so it appears from grade 2
  /// upward and deepens with the level.
  CubeScannerPuzzle _rollPuzzle({required int rollCount}) {
    final start = Die.random(_random);
    final visible = VisibleFaces(
      top: start.top,
      front: start.front,
      right: start.right,
    );

    var die = start;
    final rolls = <CubeRoll>[];
    for (int i = 0; i < rollCount; i++) {
      // Undoing the roll just made would waste a step and make the puzzle
      // shorter than it looks.
      CubeRoll roll;
      do {
        roll = CubeRoll.values[_random.nextInt(CubeRoll.values.length)];
      } while (rolls.isNotEmpty && roll == _opposite(rolls.last));
      rolls.add(roll);
      die = switch (roll) {
        CubeRoll.forward => die.rollForward(),
        CubeRoll.backward => die.rollBackward(),
        CubeRoll.left => die.rollLeft(),
        CubeRoll.right => die.rollRight(),
      };
    }

    const askable = [CubeFace.top, CubeFace.front, CubeFace.right];
    final face = askable[_random.nextInt(askable.length)];
    final answer = switch (face) {
      CubeFace.top => die.top,
      CubeFace.front => die.front,
      CubeFace.right => die.right,
      CubeFace.bottom => die.bottom,
      CubeFace.back => die.back,
      CubeFace.left => die.left,
    };

    // Forgetting to roll at all, and rolling one step too far, are the two
    // mistakes worth catching.
    final notRolled = switch (face) {
      CubeFace.top => start.top,
      CubeFace.front => start.front,
      _ => start.right,
    };

    return CubeScannerPuzzle(
      dice: [start],
      visibleFaces: [visible],
      arrangement: DiceArrangement.single,
      question: CubeScannerQuestion(
        kind: CubeQuestionKind.rollToFace,
        face: face,
        rolls: rolls,
      ),
      correctAnswer: answer,
      choices: _choices(answer, min: 1, max: 6, tempting: [notRolled, 7 - answer]),
    );
  }

  static CubeRoll _opposite(CubeRoll roll) => switch (roll) {
        CubeRoll.forward => CubeRoll.backward,
        CubeRoll.backward => CubeRoll.forward,
        CubeRoll.left => CubeRoll.right,
        CubeRoll.right => CubeRoll.left,
      };

  // ---------------------------------------------------------------------------
  // Several cubes: count the pips you cannot see
  // ---------------------------------------------------------------------------

  /// Two cubes stacked, touching faces equal: "how many pips are hidden?"
  ///
  /// Answering needs the fact that a cube carries 21 pips altogether
  /// (1+2+3+4+5+6), so the hidden total is 42 minus everything on show. That
  /// is several steps and the answer is not a number anywhere on the board --
  /// the point of replacing the old stack question, whose answer was always
  /// cube 1's visible top face.
  CubeScannerPuzzle _stackHiddenPips() {
    final die1 = Die.random(_random);

    // The cubes touch, and touching faces carry the same value.
    final candidates = (Die._cachedOrientations ??= Die._allOrientations())
        .where((d) => d.top == die1.bottom)
        .toList();
    final die2 = candidates[_random.nextInt(candidates.length)];

    final vis1 = VisibleFaces(top: die1.top, front: die1.front, right: die1.right);
    // Cube 2's top is the face cube 1 is standing on, so it is not on show.
    final vis2 = VisibleFaces(front: die2.front, right: die2.right);

    final shown = vis1.visibleSum + vis2.visibleSum;
    final answer = 42 - shown;

    return CubeScannerPuzzle(
      dice: [die1, die2],
      visibleFaces: [vis1, vis2],
      arrangement: DiceArrangement.verticalStack,
      question: const CubeScannerQuestion(
        kind: CubeQuestionKind.hiddenPips,
        diceCount: 2,
      ),
      correctAnswer: answer,
      // Counting one cube instead of two, and adding up what is on show, are
      // the two ways this goes wrong.
      choices: _choices(answer, min: 10, max: 38, tempting: [21 - shown, shown]),
    );
  }

  /// Three cubes side by side, touching faces equal: "how many pips are
  /// hidden?" -- 63 minus everything on show.
  CubeScannerPuzzle _rowHiddenPips({required int diceCount}) {
    final orientations = Die._cachedOrientations ??= Die._allOrientations();

    final dice = <Die>[Die.random(_random)];
    for (int i = 1; i < diceCount; i++) {
      final touch = dice.last.right; // right face meets the next cube's left
      final candidates = orientations.where((d) => d.left == touch).toList();
      dice.add(candidates[_random.nextInt(candidates.length)]);
    }

    // Only the last cube's right face is free; the others are pressed against
    // their neighbour.
    final visible = <VisibleFaces>[
      for (int i = 0; i < diceCount; i++)
        VisibleFaces(
          top: dice[i].top,
          front: dice[i].front,
          right: i == diceCount - 1 ? dice[i].right : null,
        ),
    ];

    int shown = 0;
    for (final v in visible) {
      shown += v.visibleSum;
    }
    final answer = 21 * diceCount - shown;

    return CubeScannerPuzzle(
      dice: dice,
      visibleFaces: visible,
      arrangement: DiceArrangement.horizontalRow,
      question: CubeScannerQuestion(
        kind: CubeQuestionKind.hiddenPips,
        diceCount: diceCount,
      ),
      correctAnswer: answer,
      choices: _choices(answer,
          min: 20, max: 60, tempting: [shown, 21 * diceCount - shown - 7]),
    );
  }

  // ---------------------------------------------------------------------------
  // Multiple choice
  // ---------------------------------------------------------------------------

  /// Five options: the answer, any [tempting] near-misses that still fit the
  /// range, then neighbours of the answer.
  ///
  /// Distractors used to be drawn uniformly from the whole range, which left
  /// the right answer guessable whenever it sat far from the rest.
  List<int> _choices(
    int correct, {
    required int min,
    required int max,
    List<int> tempting = const [],
  }) {
    final choices = <int>{correct};

    for (final t in tempting) {
      if (choices.length >= 5) break;
      if (t >= min && t <= max) choices.add(t);
    }

    // Neighbours, closest first, so the options cluster around the answer.
    for (int d = 1; d <= max - min && choices.length < 5; d++) {
      for (final candidate in [correct - d, correct + d]) {
        if (choices.length >= 5) break;
        if (candidate >= min && candidate <= max) choices.add(candidate);
      }
    }

    // Only reachable if the range itself holds fewer than five values.
    for (int v = min; v <= max && choices.length < 5; v++) {
      choices.add(v);
    }

    return choices.toList()..shuffle(_random);
  }
}
