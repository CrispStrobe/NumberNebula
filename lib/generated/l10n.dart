import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Space Math Academy'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Space Math Academy!'**
  String get welcome;

  /// No description provided for @startAdventure.
  ///
  /// In en, this message translates to:
  /// **'Start Your Math Adventure'**
  String get startAdventure;

  /// No description provided for @chooseGrade.
  ///
  /// In en, this message translates to:
  /// **'Set Your Skill Level'**
  String get chooseGrade;

  /// No description provided for @grade3.
  ///
  /// In en, this message translates to:
  /// **'3rd Grade'**
  String get grade3;

  /// No description provided for @grade4.
  ///
  /// In en, this message translates to:
  /// **'4th Grade'**
  String get grade4;

  /// No description provided for @grade5.
  ///
  /// In en, this message translates to:
  /// **'5th Grade'**
  String get grade5;

  /// No description provided for @grade6.
  ///
  /// In en, this message translates to:
  /// **'6th Grade'**
  String get grade6;

  /// No description provided for @gameMenu.
  ///
  /// In en, this message translates to:
  /// **'Mission Control'**
  String get gameMenu;

  /// No description provided for @magicTriangles.
  ///
  /// In en, this message translates to:
  /// **'Cosmic Triangles'**
  String get magicTriangles;

  /// No description provided for @magicTrianglesDesc.
  ///
  /// In en, this message translates to:
  /// **'Align the cosmic energy nodes! Each side of the triangle must sum to the same cosmic frequency to stabilize the wormhole.'**
  String get magicTrianglesDesc;

  /// No description provided for @bubbleMath.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Field Hunter'**
  String get bubbleMath;

  /// No description provided for @bubbleMathDesc.
  ///
  /// In en, this message translates to:
  /// **'Navigate a dangerous asteroid field! Blast the drifting space rocks in the correct numerical sequence before they collide.'**
  String get bubbleMathDesc;

  /// No description provided for @puzzleMath.
  ///
  /// In en, this message translates to:
  /// **'Constellation Puzzles'**
  String get puzzleMath;

  /// No description provided for @puzzleMathDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconstruct celestial star charts! Solve equations to find the correct coordinates and lock star fragments into place.'**
  String get puzzleMathDesc;

  /// No description provided for @hyperdriveGates.
  ///
  /// In en, this message translates to:
  /// **'Hyperdrive Gates'**
  String get hyperdriveGates;

  /// No description provided for @hyperdriveGatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Plot a course through quantum space gates! Fly through the gate with the correct answer to make the jump to lightspeed.'**
  String get hyperdriveGatesDesc;

  /// No description provided for @planetHopping.
  ///
  /// In en, this message translates to:
  /// **'Gravity Sling'**
  String get planetHopping;

  /// No description provided for @planetHoppingDesc.
  ///
  /// In en, this message translates to:
  /// **'Slingshot your ship between planets! Calculate the right trajectory and visit planets in the correct mathematical sequence.'**
  String get planetHoppingDesc;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @lives.
  ///
  /// In en, this message translates to:
  /// **'Hull Integrity'**
  String get lives;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Recalculating...'**
  String get incorrect;

  /// No description provided for @excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent work, Space Commander!'**
  String get excellent;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good job!'**
  String get good;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Let\'s try again!'**
  String get tryAgain;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get gameOver;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next Mission'**
  String get nextLevel;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @backToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to Mission Control'**
  String get backToMenu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound FX'**
  String get sound;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Career Progress'**
  String get progress;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @mathOperationsAddition.
  ///
  /// In en, this message translates to:
  /// **'Addition'**
  String get mathOperationsAddition;

  /// No description provided for @mathOperationsSubtraction.
  ///
  /// In en, this message translates to:
  /// **'Subtraction'**
  String get mathOperationsSubtraction;

  /// No description provided for @mathOperationsMultiplication.
  ///
  /// In en, this message translates to:
  /// **'Multiplication'**
  String get mathOperationsMultiplication;

  /// No description provided for @mathOperationsDivision.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get mathOperationsDivision;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations, Commander!'**
  String get congratulations;

  /// Number of missions completed
  ///
  /// In en, this message translates to:
  /// **'Missions Completed: {count}'**
  String missionsCompleted(int count);

  /// Number of stars earned
  ///
  /// In en, this message translates to:
  /// **'Stars Earned: {count}'**
  String starsEarned(int count);

  /// No description provided for @audioSettings.
  ///
  /// In en, this message translates to:
  /// **'Audio Settings'**
  String get audioSettings;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @backgroundMusicDesc.
  ///
  /// In en, this message translates to:
  /// **'Background music'**
  String get backgroundMusicDesc;

  /// No description provided for @gameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get gameplay;

  /// No description provided for @puzzleTimer.
  ///
  /// In en, this message translates to:
  /// **'Puzzle Timer'**
  String get puzzleTimer;

  /// No description provided for @puzzleTimerDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable timer in puzzle games'**
  String get puzzleTimerDesc;

  /// No description provided for @showHints.
  ///
  /// In en, this message translates to:
  /// **'Show Hints'**
  String get showHints;

  /// No description provided for @showHintsDesc.
  ///
  /// In en, this message translates to:
  /// **'Display helpful hints during games'**
  String get showHintsDesc;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// No description provided for @hapticFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibration on touch (if supported)'**
  String get hapticFeedbackDesc;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @appLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get appLanguageDesc;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @difficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get difficulty;

  /// No description provided for @currentGrade.
  ///
  /// In en, this message translates to:
  /// **'Current Grade'**
  String get currentGrade;

  /// No description provided for @currentLevelDesc.
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get currentLevelDesc;

  /// No description provided for @difficultyDescGrade3.
  ///
  /// In en, this message translates to:
  /// **'Basic operations'**
  String get difficultyDescGrade3;

  /// No description provided for @difficultyDescGrade4.
  ///
  /// In en, this message translates to:
  /// **'Multi-digit math'**
  String get difficultyDescGrade4;

  /// No description provided for @difficultyDescGrade5.
  ///
  /// In en, this message translates to:
  /// **'Complex problems'**
  String get difficultyDescGrade5;

  /// No description provided for @difficultyDescGrade6.
  ///
  /// In en, this message translates to:
  /// **'Advanced challenges'**
  String get difficultyDescGrade6;

  /// No description provided for @totalScore.
  ///
  /// In en, this message translates to:
  /// **'Total Score'**
  String get totalScore;

  /// No description provided for @gamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games Played'**
  String get gamesPlayed;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset Progress'**
  String get resetProgress;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'Space Math Academy Team'**
  String get developerName;

  /// No description provided for @targetAge.
  ///
  /// In en, this message translates to:
  /// **'Target Age'**
  String get targetAge;

  /// No description provided for @targetAgeRange.
  ///
  /// In en, this message translates to:
  /// **'8-12 years (Grades 3-6)'**
  String get targetAgeRange;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'Space Math Academy helps primary school students learn mathematics through engaging space-themed games. Perfect for iPads and designed with young learners in mind.'**
  String get aboutApp;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language Changed'**
  String get languageChanged;

  /// No description provided for @languageChangedDesc.
  ///
  /// In en, this message translates to:
  /// **'The app language will change when you restart. Would you like to restart now?'**
  String get languageChangedDesc;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get restartNow;

  /// No description provided for @selectGrade.
  ///
  /// In en, this message translates to:
  /// **'Select Grade'**
  String get selectGrade;

  /// No description provided for @gradeN.
  ///
  /// In en, this message translates to:
  /// **'Grade {gradeNumber}'**
  String gradeN(int gradeNumber);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @restartToApplyChanges.
  ///
  /// In en, this message translates to:
  /// **'Please restart the app to apply language changes'**
  String get restartToApplyChanges;

  /// No description provided for @resetProgressConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all progress? This action cannot be undone.'**
  String get resetProgressConfirmation;

  /// No description provided for @progressResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Progress reset successfully!'**
  String get progressResetSuccess;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @playToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Play to unlock!'**
  String get playToUnlock;

  /// No description provided for @chooseYourGrade.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Grade'**
  String get chooseYourGrade;

  /// No description provided for @grade3Desc.
  ///
  /// In en, this message translates to:
  /// **'Basic addition, subtraction, and simple multiplication'**
  String get grade3Desc;

  /// No description provided for @grade4Desc.
  ///
  /// In en, this message translates to:
  /// **'Multi-digit arithmetic and introduction to division'**
  String get grade4Desc;

  /// No description provided for @grade5Desc.
  ///
  /// In en, this message translates to:
  /// **'Complex operations and problem solving'**
  String get grade5Desc;

  /// No description provided for @grade6Desc.
  ///
  /// In en, this message translates to:
  /// **'Advanced mathematics and challenging puzzles'**
  String get grade6Desc;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Settings coming soon!'**
  String get settingsComingSoon;

  /// No description provided for @spaceExplorerProgress.
  ///
  /// In en, this message translates to:
  /// **'Space Explorer Progress'**
  String get spaceExplorerProgress;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @rankRookie.
  ///
  /// In en, this message translates to:
  /// **'Rookie'**
  String get rankRookie;

  /// No description provided for @rankExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get rankExplorer;

  /// No description provided for @rankVeteran.
  ///
  /// In en, this message translates to:
  /// **'Veteran'**
  String get rankVeteran;

  /// No description provided for @rankExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get rankExpert;

  /// No description provided for @rankLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get rankLegend;

  /// No description provided for @achievementFirstCenturyTitle.
  ///
  /// In en, this message translates to:
  /// **'First Century!'**
  String get achievementFirstCenturyTitle;

  /// No description provided for @achievementFirstCenturyDesc.
  ///
  /// In en, this message translates to:
  /// **'Score 100 points'**
  String get achievementFirstCenturyDesc;

  /// No description provided for @achievementScoreMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Score Master'**
  String get achievementScoreMasterTitle;

  /// No description provided for @achievementScoreMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Score 500 points'**
  String get achievementScoreMasterDesc;

  /// No description provided for @achievementThousandClubTitle.
  ///
  /// In en, this message translates to:
  /// **'Thousand Club'**
  String get achievementThousandClubTitle;

  /// No description provided for @achievementThousandClubDesc.
  ///
  /// In en, this message translates to:
  /// **'Score 1000 points'**
  String get achievementThousandClubDesc;

  /// No description provided for @achievementLevelExplorerTitle.
  ///
  /// In en, this message translates to:
  /// **'Level Explorer'**
  String get achievementLevelExplorerTitle;

  /// No description provided for @achievementLevelExplorerDesc.
  ///
  /// In en, this message translates to:
  /// **'Reach level 5'**
  String get achievementLevelExplorerDesc;

  /// No description provided for @achievementSpaceCommanderTitle.
  ///
  /// In en, this message translates to:
  /// **'Space Commander'**
  String get achievementSpaceCommanderTitle;

  /// No description provided for @achievementSpaceCommanderDesc.
  ///
  /// In en, this message translates to:
  /// **'Reach level 10'**
  String get achievementSpaceCommanderDesc;

  /// No description provided for @achievementTriangleWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Triangle Wizard'**
  String get achievementTriangleWizardTitle;

  /// No description provided for @achievementTriangleWizardDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 3 Magic Triangle levels'**
  String get achievementTriangleWizardDesc;

  /// No description provided for @achievementBubblePopperTitle.
  ///
  /// In en, this message translates to:
  /// **'Bubble Popper'**
  String get achievementBubblePopperTitle;

  /// No description provided for @achievementBubblePopperDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 3 Bubble Math levels'**
  String get achievementBubblePopperDesc;

  /// No description provided for @achievementPuzzleSolverTitle.
  ///
  /// In en, this message translates to:
  /// **'Puzzle Solver'**
  String get achievementPuzzleSolverTitle;

  /// No description provided for @achievementPuzzleSolverDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 3 Puzzle Math levels'**
  String get achievementPuzzleSolverDesc;

  /// No description provided for @achievementAllRounderTitle.
  ///
  /// In en, this message translates to:
  /// **'All-Rounder'**
  String get achievementAllRounderTitle;

  /// No description provided for @achievementAllRounderDesc.
  ///
  /// In en, this message translates to:
  /// **'Play all game types'**
  String get achievementAllRounderDesc;

  /// No description provided for @achievementSpeedDemonTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed Demon'**
  String get achievementSpeedDemonTitle;

  /// No description provided for @achievementSpeedDemonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a level in under 30 seconds'**
  String get achievementSpeedDemonDesc;

  /// No description provided for @achievementPerfectionistTitle.
  ///
  /// In en, this message translates to:
  /// **'Perfectionist'**
  String get achievementPerfectionistTitle;

  /// No description provided for @achievementPerfectionistDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a level without mistakes'**
  String get achievementPerfectionistDesc;

  /// No description provided for @achievementMathematicianTitle.
  ///
  /// In en, this message translates to:
  /// **'Young Mathematician'**
  String get achievementMathematicianTitle;

  /// No description provided for @achievementMathematicianDesc.
  ///
  /// In en, this message translates to:
  /// **'Solve 100 math problems'**
  String get achievementMathematicianDesc;

  /// No description provided for @unlockedStatus.
  ///
  /// In en, this message translates to:
  /// **'UNLOCKED'**
  String get unlockedStatus;

  /// No description provided for @lockedStatus.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get lockedStatus;

  /// No description provided for @achievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'ACHIEVEMENT UNLOCKED!'**
  String get achievementUnlocked;

  /// No description provided for @continueExploring.
  ///
  /// In en, this message translates to:
  /// **'Continue Exploring'**
  String get continueExploring;

  /// No description provided for @planetHoppingObjectiveAsc.
  ///
  /// In en, this message translates to:
  /// **'Visit planets in ascending order!'**
  String get planetHoppingObjectiveAsc;

  /// No description provided for @planetHoppingObjectiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Visit planets in descending order!'**
  String get planetHoppingObjectiveDesc;

  /// No description provided for @planetHoppingObjectiveEvenOdd.
  ///
  /// In en, this message translates to:
  /// **'Visit even numbers first, then odd!'**
  String get planetHoppingObjectiveEvenOdd;

  /// No description provided for @planetHoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Planet Hopping'**
  String get planetHoppingTitle;

  /// No description provided for @planetHoppingNextTarget.
  ///
  /// In en, this message translates to:
  /// **'Next: {target}'**
  String planetHoppingNextTarget(Object target);

  /// No description provided for @planetHoppingInstructions.
  ///
  /// In en, this message translates to:
  /// **'TAP anywhere to jump toward that location • Use gravity to swing between planets'**
  String get planetHoppingInstructions;

  /// No description provided for @planetHoppingWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Solar System Mastered!'**
  String get planetHoppingWinTitle;

  /// No description provided for @planetHoppingWinDesc.
  ///
  /// In en, this message translates to:
  /// **'You successfully navigated all planets in the correct sequence!\nLives Bonus: {bonus} points'**
  String planetHoppingWinDesc(Object bonus);

  /// Win message with bonus points.
  ///
  /// In en, this message translates to:
  /// **'You successfully navigated all planets in the correct sequence!\nLives Bonus: {bonus} points'**
  String planetHoppingWinDescBonus(int bonus);

  /// No description provided for @planetHoppingLoseDescCrash.
  ///
  /// In en, this message translates to:
  /// **'You crash-landed too many times!\nStudy the planet sequence and try again.'**
  String get planetHoppingLoseDescCrash;

  /// Displays the next numerical target in the sequence.
  ///
  /// In en, this message translates to:
  /// **'Next: {value}'**
  String planetHoppingNextTargetValue(int value);

  /// No description provided for @exploreAgain.
  ///
  /// In en, this message translates to:
  /// **'Explore Again'**
  String get exploreAgain;

  /// No description provided for @missionCompleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete'**
  String get missionCompleteStatus;

  /// No description provided for @planetHoppingLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation Failed!'**
  String get planetHoppingLoseTitle;

  /// No description provided for @planetHoppingLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'You crash-landed too many times!\nStudy the planet sequence and try again.'**
  String get planetHoppingLoseDesc;

  /// No description provided for @retryMission.
  ///
  /// In en, this message translates to:
  /// **'Retry Mission'**
  String get retryMission;

  /// No description provided for @returnToBase.
  ///
  /// In en, this message translates to:
  /// **'Return to Base'**
  String get returnToBase;

  /// No description provided for @hyperdriveGatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Hyperdrive Gates'**
  String get hyperdriveGatesTitle;

  /// No description provided for @solve.
  ///
  /// In en, this message translates to:
  /// **'SOLVE:'**
  String get solve;

  /// No description provided for @hyperdriveGatesObjective.
  ///
  /// In en, this message translates to:
  /// **'Fly through gates with: {correctAnswer}'**
  String hyperdriveGatesObjective(Object correctAnswer);

  /// No description provided for @hyperdriveGatesInstructions.
  ///
  /// In en, this message translates to:
  /// **'DRAG to steer your ship up/down • FLY through CORRECT gates • AVOID wrong answers'**
  String get hyperdriveGatesInstructions;

  /// No description provided for @hyperdriveGatesWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Hyperdrive Navigation Complete!'**
  String get hyperdriveGatesWinTitle;

  /// No description provided for @hyperdriveGatesWinDesc.
  ///
  /// In en, this message translates to:
  /// **'You successfully navigated through {targetGatesNeeded} gates!\nYou\'re ready for deep space missions!'**
  String hyperdriveGatesWinDesc(Object targetGatesNeeded);

  /// No description provided for @flyAgain.
  ///
  /// In en, this message translates to:
  /// **'Fly Again'**
  String get flyAgain;

  /// No description provided for @hyperdriveGatesLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation System Failure!'**
  String get hyperdriveGatesLoseTitle;

  /// No description provided for @hyperdriveGatesLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Your ship took too much damage!\nReturn to base for repairs and try again.'**
  String get hyperdriveGatesLoseDesc;

  /// No description provided for @noPuzzleImagesFound.
  ///
  /// In en, this message translates to:
  /// **'No constellation images found in assets/images/'**
  String get noPuzzleImagesFound;

  /// No description provided for @puzzleMathInstructions.
  ///
  /// In en, this message translates to:
  /// **'Rebuild the space constellation! Drag pieces to correct spots. Tap pieces to rotate them!'**
  String get puzzleMathInstructions;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @timesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up, space cadet!'**
  String get timesUp;

  /// No description provided for @constellationPieces.
  ///
  /// In en, this message translates to:
  /// **'Constellation Pieces'**
  String get constellationPieces;

  /// No description provided for @puzzleMathIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Check the math answer or try rotating the piece!'**
  String get puzzleMathIncorrect;

  /// No description provided for @puzzleMathWin.
  ///
  /// In en, this message translates to:
  /// **'Constellation restored, Space Explorer!'**
  String get puzzleMathWin;

  /// No description provided for @puzzleMathWinBonus.
  ///
  /// In en, this message translates to:
  /// **'Constellation restored!\nTime Bonus: {bonus} points!'**
  String puzzleMathWinBonus(Object bonus);

  /// No description provided for @puzzleMathTryAnother.
  ///
  /// In en, this message translates to:
  /// **'Let\'s try another constellation!'**
  String get puzzleMathTryAnother;

  /// No description provided for @magicTrianglesGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Wormhole Activator'**
  String get magicTrianglesGameTitle;

  /// No description provided for @magicTrianglesInstructions.
  ///
  /// In en, this message translates to:
  /// **'Align the Stargate! Drag resonators to match the required Warp Frequency on each side.'**
  String get magicTrianglesInstructions;

  /// No description provided for @magicTrianglesWarpFrequency.
  ///
  /// In en, this message translates to:
  /// **'Warp Frequency: {warpFrequency}'**
  String magicTrianglesWarpFrequency(Object warpFrequency);

  /// No description provided for @magicTrianglesResonators.
  ///
  /// In en, this message translates to:
  /// **'Available Subspace Resonators'**
  String get magicTrianglesResonators;

  /// No description provided for @magicTrianglesFail.
  ///
  /// In en, this message translates to:
  /// **'Alignment failed. The energy signature is incorrect. Try again!'**
  String get magicTrianglesFail;

  /// No description provided for @calculatingCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Calculating wormhole coordinates...'**
  String get calculatingCoordinates;

  /// No description provided for @magicTrianglesWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Wormhole Stabilized!'**
  String get magicTrianglesWinTitle;

  /// No description provided for @magicTrianglesWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Perfect alignment! The warp corridor is open.\nBonus: +{bonusScore} points!'**
  String magicTrianglesWinDesc(Object bonusScore);

  /// No description provided for @nextAnomaly.
  ///
  /// In en, this message translates to:
  /// **'Next Anomaly'**
  String get nextAnomaly;

  /// No description provided for @toTheBridge.
  ///
  /// In en, this message translates to:
  /// **'To Bridge'**
  String get toTheBridge;

  /// No description provided for @asteroidMathHunter.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Hunter'**
  String get asteroidMathHunter;

  /// No description provided for @asteroidMathTarget.
  ///
  /// In en, this message translates to:
  /// **'Target asteroid: {target}'**
  String asteroidMathTarget(Object target);

  /// No description provided for @asteroidMathWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Field Cleared!'**
  String get asteroidMathWinTitle;

  /// No description provided for @asteroidMathWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Time Bonus: {timeBonus} points!\nYou are a true Space Hunter!'**
  String asteroidMathWinDesc(Object timeBonus);

  /// No description provided for @timesUpSpaceCadet.
  ///
  /// In en, this message translates to:
  /// **'Time\'s Up, Space Cadet!'**
  String get timesUpSpaceCadet;

  /// No description provided for @asteroidMathLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The asteroid field got too chaotic!\nTry again, Commander!'**
  String get asteroidMathLoseDesc;

  /// No description provided for @nextTarget.
  ///
  /// In en, this message translates to:
  /// **'Next target: '**
  String get nextTarget;

  /// No description provided for @loadingAdventure.
  ///
  /// In en, this message translates to:
  /// **'Loading Space Adventure...'**
  String get loadingAdventure;

  /// No description provided for @preparingMission.
  ///
  /// In en, this message translates to:
  /// **'Preparing your math mission...'**
  String get preparingMission;

  /// No description provided for @initializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing Space Math Academy...'**
  String get initializing;

  /// No description provided for @loadingAssets.
  ///
  /// In en, this message translates to:
  /// **'Loading game assets...'**
  String get loadingAssets;

  /// No description provided for @loadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading saved progress...'**
  String get loadingProgress;

  /// No description provided for @preparingSpaceStation.
  ///
  /// In en, this message translates to:
  /// **'Preparing space station...'**
  String get preparingSpaceStation;

  /// No description provided for @calibratingNav.
  ///
  /// In en, this message translates to:
  /// **'Calibrating navigation systems...'**
  String get calibratingNav;

  /// No description provided for @readyForLaunch.
  ///
  /// In en, this message translates to:
  /// **'Ready for launch!'**
  String get readyForLaunch;

  /// No description provided for @splashScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore • Learn • Discover'**
  String get splashScreenSubtitle;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return SDe();
    case 'en':
      return SEn();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
