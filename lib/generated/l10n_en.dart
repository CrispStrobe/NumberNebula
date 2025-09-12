// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Space Math Academy';

  @override
  String get welcome => 'Welcome to Space Math Academy!';

  @override
  String get startAdventure => 'Start Your Math Adventure';

  @override
  String get chooseGrade => 'Choose Your Grade';

  @override
  String get grade3 => '3rd Grade';

  @override
  String get grade4 => '4th Grade';

  @override
  String get grade5 => '5th Grade';

  @override
  String get grade6 => '6th Grade';

  @override
  String get gameMenu => 'Game Menu';

  @override
  String get magicTriangles => 'Magic Triangles';

  @override
  String get magicTrianglesDesc =>
      'Solve the mystery of the cosmic triangles! Fill in the missing numbers.';

  @override
  String get bubbleMath => 'Cosmic Bubble Math';

  @override
  String get bubbleMathDesc =>
      'Pop the floating space bubbles in the correct mathematical order!';

  @override
  String get puzzleMath => 'Space Puzzle Math';

  @override
  String get puzzleMathDesc =>
      'Complete the space station by solving math puzzles and fitting pieces together!';

  @override
  String get level => 'Level';

  @override
  String get score => 'Score';

  @override
  String get lives => 'Lives';

  @override
  String get time => 'Time';

  @override
  String get correct => 'Correct!';

  @override
  String get incorrect => 'Try again!';

  @override
  String get excellent => 'Excellent work, Space Explorer!';

  @override
  String get good => 'Good job!';

  @override
  String get tryAgain => 'Let\'s try again!';

  @override
  String get gameOver => 'Mission Complete!';

  @override
  String get nextLevel => 'Next Mission';

  @override
  String get playAgain => 'Play Again';

  @override
  String get backToMenu => 'Back to Space Station';

  @override
  String get settings => 'Settings';

  @override
  String get sound => 'Sound';

  @override
  String get music => 'Music';

  @override
  String get language => 'Language';

  @override
  String get progress => 'Progress';

  @override
  String get achievements => 'Achievements';

  @override
  String get mathOperationsAddition => 'Addition';

  @override
  String get mathOperationsSubtraction => 'Subtraction';

  @override
  String get mathOperationsMultiplication => 'Multiplication';

  @override
  String get mathOperationsDivision => 'Division';

  @override
  String get instructionsMagicTriangles =>
      'Find the missing numbers in each triangle. Each side should add up to the same total!';

  @override
  String get instructionsBubbleMath =>
      'Pop the bubbles in order from smallest to largest answer. Watch out for the moving bubbles!';

  @override
  String get instructionsPuzzleMath =>
      'Drag puzzle pieces to their correct spots. Rotate pieces by tapping them. Match the math answers!';

  @override
  String get hintsMagicTriangles =>
      'Remember: each side of the triangle adds up to the magic number!';

  @override
  String get hintsBubbleMath =>
      'Start with the smallest answer and work your way up!';

  @override
  String get hintsPuzzleMath =>
      'Look for matching colors and solve the math problems first!';

  @override
  String get congratulations => 'Congratulations, Commander!';

  @override
  String missionsCompleted(int count) {
    return 'Missions Completed: $count';
  }

  @override
  String starsEarned(int count) {
    return 'Stars Earned: $count';
  }
}
