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
  String get chooseGrade => 'Set Your Skill Level';

  @override
  String get grade3 => '3rd Grade';

  @override
  String get grade4 => '4th Grade';

  @override
  String get grade5 => '5th Grade';

  @override
  String get grade6 => '6th Grade';

  @override
  String get gameMenu => 'Mission Control';

  @override
  String get magicTriangles => 'Cosmic Triangles';

  @override
  String get magicTrianglesDesc =>
      'Align the cosmic energy nodes! Each side of the triangle must sum to the same cosmic frequency to stabilize the wormhole.';

  @override
  String get bubbleMath => 'Asteroid Field Hunter';

  @override
  String get bubbleMathDesc =>
      'Navigate a dangerous asteroid field! Blast the drifting space rocks in the correct numerical sequence before they collide.';

  @override
  String get puzzleMath => 'Constellation Puzzles';

  @override
  String get puzzleMathDesc =>
      'Reconstruct celestial star charts! Solve equations to find the correct coordinates and lock star fragments into place.';

  @override
  String get hyperdriveGates => 'Hyperdrive Gates';

  @override
  String get hyperdriveGatesDesc =>
      'Plot a course through quantum space gates! Fly through the gate with the correct answer to make the jump to lightspeed.';

  @override
  String get planetHopping => 'Gravity Sling';

  @override
  String get planetHoppingDesc =>
      'Slingshot your ship between planets! Calculate the right trajectory and visit planets in the correct mathematical sequence.';

  @override
  String get level => 'Level';

  @override
  String get score => 'Score';

  @override
  String get lives => 'Hull Integrity';

  @override
  String get time => 'Time';

  @override
  String get correct => 'Correct!';

  @override
  String get incorrect => 'Recalculating...';

  @override
  String get excellent => 'Excellent work, Space Commander!';

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
  String get backToMenu => 'Back to Mission Control';

  @override
  String get settings => 'Settings';

  @override
  String get sound => 'Sound FX';

  @override
  String get music => 'Music';

  @override
  String get language => 'Language';

  @override
  String get progress => 'Career Progress';

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
