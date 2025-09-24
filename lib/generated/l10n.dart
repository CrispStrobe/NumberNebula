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

  /// No description provided for @fast.
  ///
  /// In en, this message translates to:
  /// **'FAST'**
  String get fast;

  /// No description provided for @grade3.
  ///
  /// In en, this message translates to:
  /// **'Level 1'**
  String get grade3;

  /// No description provided for @grade4.
  ///
  /// In en, this message translates to:
  /// **'Level 2'**
  String get grade4;

  /// No description provided for @grade5.
  ///
  /// In en, this message translates to:
  /// **'Level 3'**
  String get grade5;

  /// No description provided for @grade6.
  ///
  /// In en, this message translates to:
  /// **'Level 4'**
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
  /// **'Current Skill'**
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

  /// No description provided for @debugPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug Panel'**
  String get debugPanelTitle;

  /// No description provided for @debugForceUnlock.
  ///
  /// In en, this message translates to:
  /// **'Force Full Unlock'**
  String get debugForceUnlock;

  /// No description provided for @debugApplyAndClose.
  ///
  /// In en, this message translates to:
  /// **'Apply & Close'**
  String get debugApplyAndClose;

  /// No description provided for @parentalGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Parental Gate'**
  String get parentalGateTitle;

  /// No description provided for @parentalGateChallenge.
  ///
  /// In en, this message translates to:
  /// **'To continue, please solve this problem:'**
  String get parentalGateChallenge;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @purchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Full Access'**
  String get purchaseTitle;

  /// No description provided for @purchaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock all 8 games, all 4 skill levels, and all future updates with a single purchase!'**
  String get purchaseDescription;

  /// No description provided for @purchaseButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock Now!'**
  String get purchaseButton;

  /// No description provided for @contactingStore.
  ///
  /// In en, this message translates to:
  /// **'Contacting Mission Control...'**
  String get contactingStore;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please check your connection and try again.'**
  String get purchaseError;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The store is currently unavailable. Please check your connection and that you are signed in to your account.'**
  String get storeUnavailable;

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
  /// **'Select Skill Level'**
  String get selectGrade;

  /// No description provided for @gradeN.
  ///
  /// In en, this message translates to:
  /// **'Skill Level {gradeNumber}'**
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
  /// **'Choose Your Skill Level'**
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
  /// **'Complex operations, fractions, and decimals'**
  String get grade5Desc;

  /// No description provided for @grade6Desc.
  ///
  /// In en, this message translates to:
  /// **'Advanced math, logic puzzles, and multi-step problems'**
  String get grade6Desc;

  /// No description provided for @adaptiveDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Difficulty'**
  String get adaptiveDifficulty;

  /// No description provided for @adaptiveDifficultyDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjusts problems based on your skill'**
  String get adaptiveDifficultyDesc;

  /// No description provided for @adjustProblems.
  ///
  /// In en, this message translates to:
  /// **'Adjusts problems based on your skill'**
  String get adjustProblems;

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
  /// **'Gravity Sling'**
  String get planetHoppingTitle;

  /// No description provided for @planetHoppingNextTarget.
  ///
  /// In en, this message translates to:
  /// **'Next: {target}'**
  String planetHoppingNextTarget(Object target);

  /// No description provided for @planetHoppingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Seek the planet with greatest gravitational pull.'**
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

  /// No description provided for @launch.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch;

  /// No description provided for @splashScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore • Learn • Discover'**
  String get splashScreenSubtitle;

  /// No description provided for @pathFinderTitle.
  ///
  /// In en, this message translates to:
  /// **'Path Finder'**
  String get pathFinderTitle;

  /// No description provided for @pathFinderDesc.
  ///
  /// In en, this message translates to:
  /// **'Navigate quantum space corridors! Calculate the right trajectory through dangerous cosmic phenomena to reach your destination safely.'**
  String get pathFinderDesc;

  /// No description provided for @pathFinderSolve.
  ///
  /// In en, this message translates to:
  /// **'SOLVE:'**
  String get pathFinderSolve;

  /// Prompts player to choose the correct path
  ///
  /// In en, this message translates to:
  /// **'Choose the path for: {expression}'**
  String pathFinderChoosePath(String expression);

  /// No description provided for @pathFinderInstructions.
  ///
  /// In en, this message translates to:
  /// **'TAP on space routes • CALCULATE math problems • NAVIGATE through cosmic hazards'**
  String get pathFinderInstructions;

  /// No description provided for @pathFinderWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Quantum Navigation Complete!'**
  String get pathFinderWinTitle;

  /// Victory message showing problems solved and score
  ///
  /// In en, this message translates to:
  /// **'You successfully navigated through {targetProblems} quantum corridors!\nTotal Score: {totalScore} points!'**
  String pathFinderWinDesc(int targetProblems, int totalScore);

  /// No description provided for @pathFinderLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation Systems Offline!'**
  String get pathFinderLoseTitle;

  /// No description provided for @pathFinderLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Your ship sustained too much damage from cosmic hazards!\nRecalibrate your navigation systems and try again, Commander!'**
  String get pathFinderLoseDesc;

  /// No description provided for @pathFinderFailureWormhole.
  ///
  /// In en, this message translates to:
  /// **'Wormhole collapse!'**
  String get pathFinderFailureWormhole;

  /// No description provided for @pathFinderFailureNebula.
  ///
  /// In en, this message translates to:
  /// **'Nebula interference!'**
  String get pathFinderFailureNebula;

  /// No description provided for @pathFinderFailureAsteroidBelt.
  ///
  /// In en, this message translates to:
  /// **'Asteroid collision!'**
  String get pathFinderFailureAsteroidBelt;

  /// No description provided for @pathFinderFailureClearSpace.
  ///
  /// In en, this message translates to:
  /// **'Navigation error!'**
  String get pathFinderFailureClearSpace;

  /// No description provided for @pathFinderFailureIonStorm.
  ///
  /// In en, this message translates to:
  /// **'Ion storm damage!'**
  String get pathFinderFailureIonStorm;

  /// No description provided for @pathFinderFailureQuantumTunnel.
  ///
  /// In en, this message translates to:
  /// **'Quantum instability!'**
  String get pathFinderFailureQuantumTunnel;

  /// No description provided for @numberWalls.
  ///
  /// In en, this message translates to:
  /// **'Number Walls'**
  String get numberWalls;

  /// No description provided for @numberWallsDesc.
  ///
  /// In en, this message translates to:
  /// **'Build cosmic calculation pyramids! Stabilize the quantum structure!'**
  String get numberWallsDesc;

  /// No description provided for @numberWallsGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Quantum Pyramid Builder'**
  String get numberWallsGameTitle;

  /// No description provided for @numberWallsInstructions.
  ///
  /// In en, this message translates to:
  /// **'Build the number wall! Drag numbers to complete the structure.'**
  String get numberWallsInstructions;

  /// No description provided for @numberWallsCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating pyramid coordinates...'**
  String get numberWallsCalculating;

  /// No description provided for @numberWallsBricks.
  ///
  /// In en, this message translates to:
  /// **'Available Building Blocks'**
  String get numberWallsBricks;

  /// No description provided for @numberWallsFail.
  ///
  /// In en, this message translates to:
  /// **'Structural integrity compromised! The mathematical foundation is unstable. Try again!'**
  String get numberWallsFail;

  /// No description provided for @numberWallsWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Pyramid Stabilized!'**
  String get numberWallsWinTitle;

  /// No description provided for @numberWallsWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Perfect mathematical alignment! The quantum structure is stable.\nBonus: +{bonusScore} points!'**
  String numberWallsWinDesc(int bonusScore);

  /// No description provided for @numberWallsNextWall.
  ///
  /// In en, this message translates to:
  /// **'Next Pyramid'**
  String get numberWallsNextWall;

  /// No description provided for @numberWallsAddition.
  ///
  /// In en, this message translates to:
  /// **'Quantum Addition Matrix'**
  String get numberWallsAddition;

  /// No description provided for @numberWallsSubtraction.
  ///
  /// In en, this message translates to:
  /// **'Stellar Subtraction Grid'**
  String get numberWallsSubtraction;

  /// No description provided for @numberWallsMultiplication.
  ///
  /// In en, this message translates to:
  /// **'Cosmic Multiplication Array'**
  String get numberWallsMultiplication;

  /// No description provided for @numberWallsDivision.
  ///
  /// In en, this message translates to:
  /// **'Galactic Division Network'**
  String get numberWallsDivision;

  /// No description provided for @numberWallsDropFar.
  ///
  /// In en, this message translates to:
  /// **'Drop it closer to the target please.'**
  String get numberWallsDropFar;

  /// No description provided for @numberWallsAddDesc.
  ///
  /// In en, this message translates to:
  /// **'Each brick is the sum of the two below it.'**
  String get numberWallsAddDesc;

  /// No description provided for @numberWallsSubDesc.
  ///
  /// In en, this message translates to:
  /// **'The top brick is the difference of the two below it.'**
  String get numberWallsSubDesc;

  /// No description provided for @numberWallsMultDesc.
  ///
  /// In en, this message translates to:
  /// **'Each brick is the product of the two below it.'**
  String get numberWallsMultDesc;

  /// No description provided for @numberWallsDivDesc.
  ///
  /// In en, this message translates to:
  /// **'Each brick is the quotient of the two below it.'**
  String get numberWallsDivDesc;

  /// No description provided for @codebreaker.
  ///
  /// In en, this message translates to:
  /// **'Codebreaker'**
  String get codebreaker;

  /// No description provided for @codebreakerDesc.
  ///
  /// In en, this message translates to:
  /// **'Intercept and decode alien transmissions! Solve complex equation systems to reveal their secrets.'**
  String get codebreakerDesc;

  /// No description provided for @codebreakerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Code cracked!'**
  String get codebreakerSuccess;

  /// No description provided for @codebreakerError.
  ///
  /// In en, this message translates to:
  /// **'Transmission corrupted'**
  String get codebreakerError;

  /// No description provided for @codebreakerTransmissionReceived.
  ///
  /// In en, this message translates to:
  /// **'Alien transmission intercepted'**
  String get codebreakerTransmissionReceived;

  /// No description provided for @codebreakerSelectNumbers.
  ///
  /// In en, this message translates to:
  /// **'Select numbers to decode the transmission'**
  String get codebreakerSelectNumbers;

  /// No description provided for @codebreakerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Decode the alien symbols by solving the equations. Tap numbers to fill in the missing values.'**
  String get codebreakerInstructions;

  /// No description provided for @codebreakerWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get codebreakerWinTitle;

  /// No description provided for @codebreakerLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Transmission Lost'**
  String get codebreakerLoseTitle;

  /// No description provided for @codebreakerWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Excellent work, Agent! You earned {totalScore} points. The galaxy is safer thanks to your cryptographic skills!'**
  String codebreakerWinDesc(int totalScore);

  /// No description provided for @codebreakerLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The alien codes proved too complex to crack in time. Don\'t worry - even the best codebreakers need practice!'**
  String get codebreakerLoseDesc;

  /// No description provided for @problemCustomization.
  ///
  /// In en, this message translates to:
  /// **'Problem Customization'**
  String get problemCustomization;

  /// No description provided for @problemCustomizationDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize the math operations and number ranges used in games.'**
  String get problemCustomizationDesc;

  /// No description provided for @problemCustomizationUnlock.
  ///
  /// In en, this message translates to:
  /// **'This feature requires the full version.'**
  String get problemCustomizationUnlock;

  /// No description provided for @enableCustomSettings.
  ///
  /// In en, this message translates to:
  /// **'Enable Custom Settings'**
  String get enableCustomSettings;

  /// No description provided for @allowedOperations.
  ///
  /// In en, this message translates to:
  /// **'Allowed Operations'**
  String get allowedOperations;

  /// No description provided for @numberRange.
  ///
  /// In en, this message translates to:
  /// **'Number Range'**
  String get numberRange;

  /// No description provided for @minValue.
  ///
  /// In en, this message translates to:
  /// **'Min Value'**
  String get minValue;

  /// No description provided for @maxValue.
  ///
  /// In en, this message translates to:
  /// **'Max Value'**
  String get maxValue;

  /// No description provided for @perspectivePuzzleGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Anomaly Scan'**
  String get perspectivePuzzleGameTitle;

  /// No description provided for @anomalyScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Anomaly Scan'**
  String get anomalyScanTitle;

  /// No description provided for @perspectivePuzzleInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan space objects with different sensor perspectives.'**
  String get perspectivePuzzleInstructions;

  /// No description provided for @anomalyScanSelectReadout.
  ///
  /// In en, this message translates to:
  /// **'Match hologram to correct {perspective} sensor readout'**
  String anomalyScanSelectReadout(String perspective);

  /// No description provided for @anomalyScanWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete!'**
  String get anomalyScanWinTitle;

  /// No description provided for @anomalyScanWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Anomaly Identified. Data logged. Bonus: {bonus} points.'**
  String anomalyScanWinDesc(int bonus);

  /// No description provided for @perspectivePuzzleWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete!'**
  String get perspectivePuzzleWinTitle;

  /// No description provided for @perspectivePuzzleWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Anomaly Identified. Data logged. Bonus: {bonus} points.'**
  String perspectivePuzzleWinDesc(int bonus);

  /// No description provided for @perspectivePuzzleSelectView.
  ///
  /// In en, this message translates to:
  /// **'Select the {perspective} perspective.'**
  String perspectivePuzzleSelectView(String perspective);

  /// No description provided for @perspectiveFront.
  ///
  /// In en, this message translates to:
  /// **'FRONT'**
  String get perspectiveFront;

  /// No description provided for @perspectiveBack.
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get perspectiveBack;

  /// No description provided for @perspectiveLeft.
  ///
  /// In en, this message translates to:
  /// **'LEFT'**
  String get perspectiveLeft;

  /// No description provided for @perspectiveRight.
  ///
  /// In en, this message translates to:
  /// **'RIGHT'**
  String get perspectiveRight;

  /// No description provided for @anomalyScanFail.
  ///
  /// In en, this message translates to:
  /// **'Scan Mismatch. Recalibrating sensors...'**
  String get anomalyScanFail;

  /// No description provided for @perspectiveDensityScan.
  ///
  /// In en, this message translates to:
  /// **'DENSITY'**
  String get perspectiveDensityScan;

  /// No description provided for @perspectiveStructuralScan.
  ///
  /// In en, this message translates to:
  /// **'STRUCTURAL'**
  String get perspectiveStructuralScan;

  /// No description provided for @perspectiveThermalScan.
  ///
  /// In en, this message translates to:
  /// **'THERMAL'**
  String get perspectiveThermalScan;

  /// No description provided for @perspectiveEMScan.
  ///
  /// In en, this message translates to:
  /// **'EM-FIELD'**
  String get perspectiveEMScan;

  /// No description provided for @blockCounterGameTitle.
  ///
  /// In en, this message translates to:
  /// **'3D Block Counter'**
  String get blockCounterGameTitle;

  /// No description provided for @blockCounterInstructions.
  ///
  /// In en, this message translates to:
  /// **'Rotate and count all blocks including hidden ones'**
  String get blockCounterInstructions;

  /// No description provided for @blockCounterFail.
  ///
  /// In en, this message translates to:
  /// **'Incorrect count! Try again.'**
  String get blockCounterFail;

  /// No description provided for @blockCounterComplexity.
  ///
  /// In en, this message translates to:
  /// **'Complexity: {level}'**
  String blockCounterComplexity(int level);

  /// No description provided for @blockCounterQuestion.
  ///
  /// In en, this message translates to:
  /// **'How many blocks are in this structure?'**
  String get blockCounterQuestion;

  /// No description provided for @blockCounterSelectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Select Your Answer'**
  String get blockCounterSelectAnswer;

  /// No description provided for @blockCounterShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show Hidden'**
  String get blockCounterShowHint;

  /// No description provided for @blockCounterHideHint.
  ///
  /// In en, this message translates to:
  /// **'Hide Hint'**
  String get blockCounterHideHint;

  /// No description provided for @blockCounterRotateInstructions.
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate • Pinch to zoom'**
  String get blockCounterRotateInstructions;

  /// No description provided for @blockCounterHintShowing.
  ///
  /// In en, this message translates to:
  /// **'Hidden blocks are highlighted in yellow'**
  String get blockCounterHintShowing;

  /// No description provided for @blockCounterHintHidden.
  ///
  /// In en, this message translates to:
  /// **'Some blocks may be hidden behind others'**
  String get blockCounterHintHidden;

  /// No description provided for @blockCounterWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Perfect Count!'**
  String get blockCounterWinTitle;

  /// No description provided for @blockCounterWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Correct! There were {count} blocks total.'**
  String blockCounterWinDesc(int count);

  /// No description provided for @blockCounterBonusPoints.
  ///
  /// In en, this message translates to:
  /// **'Bonus points: {bonus}'**
  String blockCounterBonusPoints(int bonus);

  /// No description provided for @blockCounterDifficultyVeryEasy.
  ///
  /// In en, this message translates to:
  /// **'Very easy'**
  String get blockCounterDifficultyVeryEasy;

  /// No description provided for @blockCounterDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get blockCounterDifficultyEasy;

  /// No description provided for @blockCounterDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get blockCounterDifficultyMedium;

  /// No description provided for @blockCounterDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get blockCounterDifficultyHard;

  /// No description provided for @blockCounterNextPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Next mission'**
  String get blockCounterNextPuzzle;

  /// No description provided for @blockCounterBackToMenu.
  ///
  /// In en, this message translates to:
  /// **'Back to base'**
  String get blockCounterBackToMenu;

  /// No description provided for @sriStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Insights'**
  String get sriStatisticsTitle;

  /// No description provided for @sriStatisticsDesc.
  ///
  /// In en, this message translates to:
  /// **'View your progress and identify areas for improvement.'**
  String get sriStatisticsDesc;

  /// No description provided for @premiumFeature.
  ///
  /// In en, this message translates to:
  /// **'This is a premium feature. Unlock the full version to access.'**
  String get premiumFeature;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sriMastery.
  ///
  /// In en, this message translates to:
  /// **'Overall Mastery'**
  String get sriMastery;

  /// No description provided for @sriTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Tracked'**
  String get sriTotal;

  /// No description provided for @sriMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get sriMastered;

  /// No description provided for @sriLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sriLearning;

  /// No description provided for @progressMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress Matrix'**
  String get progressMatrixTitle;

  /// No description provided for @progressMatrixDesc.
  ///
  /// In en, this message translates to:
  /// **'Color shows mastery (green is best). Number shows problems tracked in that area.'**
  String get progressMatrixDesc;

  /// No description provided for @signalTriangulationGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Triangulation'**
  String get signalTriangulationGameTitle;

  /// No description provided for @signalTriangulationInstructions.
  ///
  /// In en, this message translates to:
  /// **'A faint Precursor signal has been detected! Decode the frequency sequence by analyzing echo responses. Green dots = correct frequency in correct position, Orange rings = correct frequency in wrong position.'**
  String get signalTriangulationInstructions;

  /// No description provided for @signalTriangulationAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts: {current}/{max}'**
  String signalTriangulationAttempts(int current, int max);

  /// No description provided for @signalTriangulationLength.
  ///
  /// In en, this message translates to:
  /// **'Sequence: {length} frequencies'**
  String signalTriangulationLength(int length);

  /// No description provided for @signalTriangulationCurrentSequence.
  ///
  /// In en, this message translates to:
  /// **'Current Signal Sequence'**
  String get signalTriangulationCurrentSequence;

  /// No description provided for @signalTriangulationFrequencies.
  ///
  /// In en, this message translates to:
  /// **'Available Frequencies'**
  String get signalTriangulationFrequencies;

  /// No description provided for @signalTriangulationPreviousAttempts.
  ///
  /// In en, this message translates to:
  /// **'Echo Analysis Log'**
  String get signalTriangulationPreviousAttempts;

  /// No description provided for @signalTriangulationClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signalTriangulationClear;

  /// No description provided for @signalTriangulationTransmit.
  ///
  /// In en, this message translates to:
  /// **'Transmit'**
  String get signalTriangulationTransmit;

  /// No description provided for @signalTriangulationWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Source Located!'**
  String get signalTriangulationWinTitle;

  /// No description provided for @signalTriangulationWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Excellent work, Astro-Technician! You triangulated the Precursor cache in {attempts} attempts, earning {totalScore} points. Efficiency bonus: {bonus} points!'**
  String signalTriangulationWinDesc(int attempts, int totalScore, int bonus);

  /// No description provided for @signalTriangulationLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Lost in Static'**
  String get signalTriangulationLoseTitle;

  /// No description provided for @signalTriangulationLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The signal has faded beyond detection range. The Precursor cache remains hidden in the cosmic void.'**
  String get signalTriangulationLoseDesc;

  /// No description provided for @signalTriangulationReveal.
  ///
  /// In en, this message translates to:
  /// **'The correct sequence was: {sequence}'**
  String signalTriangulationReveal(String sequence);

  /// No description provided for @nextSignal.
  ///
  /// In en, this message translates to:
  /// **'Next Signal'**
  String get nextSignal;

  /// No description provided for @cryptexLockBreakerGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Cryptex Lock Breaker'**
  String get cryptexLockBreakerGameTitle;

  /// No description provided for @cryptexLockBreakerInstructions.
  ///
  /// In en, this message translates to:
  /// **'An ancient Precursor Cryptex blocks your path! This mechanical vault uses interlocking mathematical equations as its combination. Rotate the dials to satisfy all equations simultaneously and unlock the secrets within.'**
  String get cryptexLockBreakerInstructions;

  /// No description provided for @cryptexLockBreakerControls.
  ///
  /// In en, this message translates to:
  /// **'Tap and drag dials up/down to rotate • Watch the equations turn green when solved'**
  String get cryptexLockBreakerControls;

  /// No description provided for @cryptexLockBreakerEquations.
  ///
  /// In en, this message translates to:
  /// **'Lock Equations'**
  String get cryptexLockBreakerEquations;

  /// No description provided for @cryptexLockBreakerWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Cryptex Unlocked!'**
  String get cryptexLockBreakerWinTitle;

  /// No description provided for @cryptexLockBreakerWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Brilliant work, Astro-Technician! You\'ve cracked the Precursor lock mechanism and earned {totalScore} points. Complexity bonus: {complexityBonus} • Equation bonus: {equationBonus}'**
  String cryptexLockBreakerWinDesc(
      int totalScore, int complexityBonus, int equationBonus);

  /// No description provided for @nextCryptex.
  ///
  /// In en, this message translates to:
  /// **'Next Cryptex'**
  String get nextCryptex;

  /// Title of the Arithmancer game
  ///
  /// In en, this message translates to:
  /// **'Arithmancer\'s Duel'**
  String get arithmancerGameTitle;

  /// No description provided for @arithmancerGameInstructions.
  ///
  /// In en, this message translates to:
  /// **'Fight as Combat Coder against rogue AI programs, leverage your Neural Arsenal.'**
  String get arithmancerGameInstructions;

  /// Health stat label
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get arithmancerHealth;

  /// Energy stat label
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get arithmancerEnergy;

  /// Block stat label
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get arithmancerBlock;

  /// Expression builder area title
  ///
  /// In en, this message translates to:
  /// **'Combat Sequence'**
  String get arithmancerExpression;

  /// Button to execute the mathematical expression
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get arithmancerExecute;

  /// Placeholder text for empty expression area
  ///
  /// In en, this message translates to:
  /// **'Drag cards here to build your combat sequence'**
  String get arithmancerDragCards;

  /// Hand area title
  ///
  /// In en, this message translates to:
  /// **'Neural Arsenal'**
  String get arithmancerHand;

  /// Message when hand is empty
  ///
  /// In en, this message translates to:
  /// **'No algorithms available'**
  String get arithmancerNoCards;

  /// Error message for invalid mathematical expression
  ///
  /// In en, this message translates to:
  /// **'Invalid sequence - check syntax'**
  String get arithmancerInvalidExpression;

  /// Error message when not enough energy to execute
  ///
  /// In en, this message translates to:
  /// **'Insufficient processing power'**
  String get arithmancerNotEnoughEnergy;

  /// Message when enemy attacks
  ///
  /// In en, this message translates to:
  /// **'AI counterattack deals {damage} damage!'**
  String arithmancerEnemyAttack(int damage);

  /// Prime number mathematical property
  ///
  /// In en, this message translates to:
  /// **'Prime'**
  String get arithmancerPropertyPrime;

  /// Perfect square mathematical property
  ///
  /// In en, this message translates to:
  /// **'Perfect Square'**
  String get arithmancerPropertySquare;

  /// Fibonacci number mathematical property
  ///
  /// In en, this message translates to:
  /// **'Fibonacci'**
  String get arithmancerPropertyFibonacci;

  /// Even number mathematical property
  ///
  /// In en, this message translates to:
  /// **'Even'**
  String get arithmancerPropertyEven;

  /// Odd number mathematical property
  ///
  /// In en, this message translates to:
  /// **'Odd'**
  String get arithmancerPropertyOdd;

  /// Power of two mathematical property
  ///
  /// In en, this message translates to:
  /// **'Power of 2'**
  String get arithmancerPropertyPowerOfTwo;

  /// Prime number defense shield
  ///
  /// In en, this message translates to:
  /// **'Prime Shield'**
  String get arithmancerShieldPrime;

  /// Even number defense shield
  ///
  /// In en, this message translates to:
  /// **'Even Absorber'**
  String get arithmancerShieldEven;

  /// Odd number weakness
  ///
  /// In en, this message translates to:
  /// **'Odd Vulnerable'**
  String get arithmancerShieldOdd;

  /// Perfect square defense shield
  ///
  /// In en, this message translates to:
  /// **'Square Immunity'**
  String get arithmancerShieldSquare;

  /// Fibonacci sequence defense shield
  ///
  /// In en, this message translates to:
  /// **'Fibonacci Lock'**
  String get arithmancerShieldFibonacci;

  /// Power of two defense shield
  ///
  /// In en, this message translates to:
  /// **'Binary Fortress'**
  String get arithmancerShieldPowerOfTwo;

  /// Victory dialog title
  ///
  /// In en, this message translates to:
  /// **'Neural Breach Successful!'**
  String get arithmancerVictoryTitle;

  /// Victory dialog description
  ///
  /// In en, this message translates to:
  /// **'Rogue AI neutralized! You earned {score} data credits for restoring this network node.'**
  String arithmancerVictoryDesc(int score);

  /// Defeat dialog title
  ///
  /// In en, this message translates to:
  /// **'System Compromised'**
  String get arithmancerDefeatTitle;

  /// Defeat dialog description
  ///
  /// In en, this message translates to:
  /// **'The rogue AI has overwhelmed your defenses. Analyzing attack patterns for next attempt...'**
  String get arithmancerDefeatDesc;

  /// Button to start next challenge
  ///
  /// In en, this message translates to:
  /// **'Engage New Target'**
  String get arithmancerNextChallenge;

  /// Button to try again after defeat
  ///
  /// In en, this message translates to:
  /// **'Retry Infiltration'**
  String get arithmancerTryAgain;

  /// Button to return to main menu
  ///
  /// In en, this message translates to:
  /// **'Return to Bridge'**
  String get arithmancerReturnToBridge;
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
