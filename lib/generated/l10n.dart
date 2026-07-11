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
  /// **'Number Nebula'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Number Nebula!'**
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
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @gameOver.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get gameOver;

  /// No description provided for @nextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next Level'**
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
  /// **'Congratulations!'**
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
  /// **'CrispStrobe'**
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
  /// **'Number Nebula helps primary school students learn mathematics through engaging space-themed games. Perfect for iPads and designed with young learners in mind.'**
  String get aboutApp;

  /// No description provided for @languageRestartPrompt.
  ///
  /// In en, this message translates to:
  /// **'The app language will change when you restart. Would you like to restart now?'**
  String get languageRestartPrompt;

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

  /// No description provided for @resetProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all progress? This action cannot be undone.'**
  String get resetProgressConfirm;

  /// No description provided for @legalNotice.
  ///
  /// In en, this message translates to:
  /// **'View Legal Notice'**
  String get legalNotice;

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

  /// No description provided for @planetHoppingOrderAsc.
  ///
  /// In en, this message translates to:
  /// **'Solve the expressions and visit planets from SMALLEST to LARGEST result!'**
  String get planetHoppingOrderAsc;

  /// No description provided for @planetHoppingOrderDesc.
  ///
  /// In en, this message translates to:
  /// **'Solve the expressions and visit planets from LARGEST to SMALLEST result!'**
  String get planetHoppingOrderDesc;

  /// No description provided for @planetHoppingOrderEvensOdds.
  ///
  /// In en, this message translates to:
  /// **'Visit planets with EVEN results first, then ODD results — both in ascending order!'**
  String get planetHoppingOrderEvensOdds;

  /// No description provided for @planetHoppingOrderAscShort.
  ///
  /// In en, this message translates to:
  /// **'Small→Big'**
  String get planetHoppingOrderAscShort;

  /// No description provided for @planetHoppingOrderDescShort.
  ///
  /// In en, this message translates to:
  /// **'Big→Small'**
  String get planetHoppingOrderDescShort;

  /// No description provided for @planetHoppingOrderEvensOddsShort.
  ///
  /// In en, this message translates to:
  /// **'Even→Odd'**
  String get planetHoppingOrderEvensOddsShort;

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

  /// No description provided for @magicTrianglesOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get magicTrianglesOutOfMoves;

  /// No description provided for @magicTrianglesOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many placements! Position each resonator carefully to align the wormhole efficiently.'**
  String get magicTrianglesOutOfMovesDesc;

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

  /// No description provided for @asteroidMathHunterDesc.
  ///
  /// In en, this message translates to:
  /// **'Navigate a dangerous asteroid field! Blast the drifting space rocks in the correct numerical sequence before they collide.'**
  String get asteroidMathHunterDesc;

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

  /// No description provided for @asteroidMathLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission Failed!'**
  String get asteroidMathLoseTitle;

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
  /// **'Initializing Number Nebula...'**
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

  /// No description provided for @numberWallsOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get numberWallsOutOfMoves;

  /// No description provided for @numberWallsOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many placements! Place each building block carefully to stabilize the pyramid.'**
  String get numberWallsOutOfMovesDesc;

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

  /// No description provided for @codebreakerOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get codebreakerOutOfMoves;

  /// No description provided for @codebreakerOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many placements! Think carefully about each code assignment to crack the transmission efficiently.'**
  String get codebreakerOutOfMovesDesc;

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
  /// **'A faint signal has been detected! Decode the frequency sequence by analyzing echo responses. Green dots = correct frequency in correct position, Orange rings = correct frequency in wrong position.'**
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
  /// **'Excellent work, Astro-Technician! You triangulated the sginal in {attempts} attempts, earning {totalScore} points. Efficiency bonus: {bonus} points!'**
  String signalTriangulationWinDesc(int attempts, int totalScore, int bonus);

  /// No description provided for @signalTriangulationLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Lost in Static'**
  String get signalTriangulationLoseTitle;

  /// No description provided for @signalTriangulationLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The signal has faded beyond detection range. The result cache remains hidden in the cosmic void.'**
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
  /// **'A Code-Cryptex blocks your path! It uses interlocking mathematical equations as its combination. Rotate the dials to satisfy all equations simultaneously.'**
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
  /// **'Brilliant work, Astro-Technician! You\'ve cracked the lock mechanism and earned {totalScore} points. Complexity bonus: {complexityBonus} • Equation bonus: {equationBonus}'**
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

  /// No description provided for @arithmancerSkipTurn.
  ///
  /// In en, this message translates to:
  /// **'Skip turn'**
  String get arithmancerSkipTurn;

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

  /// No description provided for @arithmeticSquareOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get arithmeticSquareOutOfMoves;

  /// No description provided for @arithmeticSquareOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Think carefully about each placement to solve the puzzle efficiently.'**
  String get arithmeticSquareOutOfMovesDesc;

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

  /// No description provided for @arithmancerGameModeNeuralBreach.
  ///
  /// In en, this message translates to:
  /// **'NEURAL BREACH'**
  String get arithmancerGameModeNeuralBreach;

  /// No description provided for @arithmancerGameModeAiDuel.
  ///
  /// In en, this message translates to:
  /// **'AI COMBAT DUEL'**
  String get arithmancerGameModeAiDuel;

  /// No description provided for @arithmancerGameModeNeuralLadder.
  ///
  /// In en, this message translates to:
  /// **'NEURAL LADDER'**
  String get arithmancerGameModeNeuralLadder;

  /// No description provided for @arithmancerDeck.
  ///
  /// In en, this message translates to:
  /// **'DECK'**
  String get arithmancerDeck;

  /// No description provided for @arithmancerUsed.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get arithmancerUsed;

  /// No description provided for @arithmancerOpponentProcessing.
  ///
  /// In en, this message translates to:
  /// **'OPPONENT PROCESSING...'**
  String get arithmancerOpponentProcessing;

  /// No description provided for @arithmancerBonusPrime.
  ///
  /// In en, this message translates to:
  /// **'PRIME'**
  String get arithmancerBonusPrime;

  /// No description provided for @arithmancerBonusSquare.
  ///
  /// In en, this message translates to:
  /// **'SQUARE'**
  String get arithmancerBonusSquare;

  /// No description provided for @arithmancerBonusFibonacci.
  ///
  /// In en, this message translates to:
  /// **'FIBONACCI'**
  String get arithmancerBonusFibonacci;

  /// No description provided for @arithmancerBonusBinary.
  ///
  /// In en, this message translates to:
  /// **'BINARY'**
  String get arithmancerBonusBinary;

  /// No description provided for @arithmancerInstructionsGeneral.
  ///
  /// In en, this message translates to:
  /// **'Create mathematical expressions to deal damage'**
  String get arithmancerInstructionsGeneral;

  /// No description provided for @arithmancerInstructionsAiPlayer.
  ///
  /// In en, this message translates to:
  /// **'Defeat {aiName} with clever mathematics'**
  String arithmancerInstructionsAiPlayer(String aiName);

  /// No description provided for @arithmancerInstructionsPrimeShield.
  ///
  /// In en, this message translates to:
  /// **'Use prime numbers to break through the prime shield'**
  String get arithmancerInstructionsPrimeShield;

  /// No description provided for @arithmancerInstructionsSquareImmune.
  ///
  /// In en, this message translates to:
  /// **'Avoid perfect squares - this enemy is immune'**
  String get arithmancerInstructionsSquareImmune;

  /// No description provided for @arithmancerInstructionsFibonacciOnly.
  ///
  /// In en, this message translates to:
  /// **'Only Fibonacci numbers can deal damage'**
  String get arithmancerInstructionsFibonacciOnly;

  /// No description provided for @arithmancerInstructionsPowerOfTwoOnly.
  ///
  /// In en, this message translates to:
  /// **'Only powers of two penetrate this defense'**
  String get arithmancerInstructionsPowerOfTwoOnly;

  /// No description provided for @arithmancerInstructionsParityDaemon.
  ///
  /// In en, this message translates to:
  /// **'Use ODD numbers! Even numbers are absorbed by this daemon'**
  String get arithmancerInstructionsParityDaemon;

  /// No description provided for @arithmancerHelpPrimeTitle.
  ///
  /// In en, this message translates to:
  /// **'What are Prime Numbers?'**
  String get arithmancerHelpPrimeTitle;

  /// No description provided for @arithmancerHelpPrimeExplain.
  ///
  /// In en, this message translates to:
  /// **'A prime number can only be divided by 1 and itself. It has no other divisors.'**
  String get arithmancerHelpPrimeExplain;

  /// No description provided for @arithmancerHelpPrimeExamples.
  ///
  /// In en, this message translates to:
  /// **'2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47 ...'**
  String get arithmancerHelpPrimeExamples;

  /// No description provided for @arithmancerHelpPrimeStrategy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Create expressions that equal a prime >= 11 for 3x damage!'**
  String get arithmancerHelpPrimeStrategy;

  /// No description provided for @arithmancerHelpParityTitle.
  ///
  /// In en, this message translates to:
  /// **'Odd vs Even Numbers'**
  String get arithmancerHelpParityTitle;

  /// No description provided for @arithmancerHelpParityExplain.
  ///
  /// In en, this message translates to:
  /// **'Even numbers (divisible by 2) are ABSORBED — they heal the enemy! Odd numbers deal bonus damage.'**
  String get arithmancerHelpParityExplain;

  /// No description provided for @arithmancerHelpParityExamples.
  ///
  /// In en, this message translates to:
  /// **'Odd: 1, 3, 5, 7, 9, 11, 13 ...  Even: 2, 4, 6, 8, 10, 12 ...'**
  String get arithmancerHelpParityExamples;

  /// No description provided for @arithmancerHelpParityStrategy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Odd + Odd = Even (bad!). Odd x Odd = Odd (good!). Watch your operators!'**
  String get arithmancerHelpParityStrategy;

  /// No description provided for @arithmancerHelpSquareTitle.
  ///
  /// In en, this message translates to:
  /// **'What are Perfect Squares?'**
  String get arithmancerHelpSquareTitle;

  /// No description provided for @arithmancerHelpSquareExplain.
  ///
  /// In en, this message translates to:
  /// **'A perfect square is a number that equals some integer multiplied by itself.'**
  String get arithmancerHelpSquareExplain;

  /// No description provided for @arithmancerHelpSquareExamples.
  ///
  /// In en, this message translates to:
  /// **'1x1=1, 2x2=4, 3x3=9, 4x4=16, 5x5=25, 6x6=36, 7x7=49, 8x8=64 ...'**
  String get arithmancerHelpSquareExamples;

  /// No description provided for @arithmancerHelpSquareStrategy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Create a perfect square for 2.5x damage! Non-squares deal almost nothing.'**
  String get arithmancerHelpSquareStrategy;

  /// No description provided for @arithmancerHelpFibTitle.
  ///
  /// In en, this message translates to:
  /// **'What are Fibonacci Numbers?'**
  String get arithmancerHelpFibTitle;

  /// No description provided for @arithmancerHelpFibExplain.
  ///
  /// In en, this message translates to:
  /// **'Each Fibonacci number is the sum of the two before it. Start with 1, 1, then add: 1+1=2, 1+2=3, 2+3=5, ...'**
  String get arithmancerHelpFibExplain;

  /// No description provided for @arithmancerHelpFibExamples.
  ///
  /// In en, this message translates to:
  /// **'1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 ...'**
  String get arithmancerHelpFibExamples;

  /// No description provided for @arithmancerHelpFibStrategy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Only Fibonacci results deal damage! Memorize the sequence or use addition cards to build them.'**
  String get arithmancerHelpFibStrategy;

  /// No description provided for @arithmancerHelpPow2Title.
  ///
  /// In en, this message translates to:
  /// **'What are Powers of Two?'**
  String get arithmancerHelpPow2Title;

  /// No description provided for @arithmancerHelpPow2Explain.
  ///
  /// In en, this message translates to:
  /// **'Start with 1 and keep doubling: 1, 2, 4, 8, 16, 32, ... Each is 2 multiplied by itself a certain number of times.'**
  String get arithmancerHelpPow2Explain;

  /// No description provided for @arithmancerHelpPow2Examples.
  ///
  /// In en, this message translates to:
  /// **'2^0=1, 2^1=2, 2^2=4, 2^3=8, 2^4=16, 2^5=32, 2^6=64, 2^7=128 ...'**
  String get arithmancerHelpPow2Examples;

  /// No description provided for @arithmancerHelpPow2Strategy.
  ///
  /// In en, this message translates to:
  /// **'Tip: Use multiplication: 2x2=4, 2x4=8, 4x4=16. Only powers of 2 deal full damage!'**
  String get arithmancerHelpPow2Strategy;

  /// No description provided for @arithmancerLadderProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Ladder Progress'**
  String get arithmancerLadderProgressTitle;

  /// No description provided for @arithmancerLadderProgressDesc.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total} complete! Continue climbing the neural ladder.'**
  String arithmancerLadderProgressDesc(int step, int total);

  /// No description provided for @arithmancerLadderContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Ladder'**
  String get arithmancerLadderContinue;

  /// No description provided for @arithmancerLadderChampionTitle.
  ///
  /// In en, this message translates to:
  /// **'Ladder Champion!'**
  String get arithmancerLadderChampionTitle;

  /// No description provided for @arithmancerLadderChampionDesc.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You\'ve conquered the entire neural ladder and earned {score} points!'**
  String arithmancerLadderChampionDesc(int score);

  /// No description provided for @arithmancerTurnSkipped.
  ///
  /// In en, this message translates to:
  /// **'Turn skipped - energy saved for next round'**
  String get arithmancerTurnSkipped;

  /// No description provided for @arithmancerGameplayGuide.
  ///
  /// In en, this message translates to:
  /// **'Gameplay Guide'**
  String get arithmancerGameplayGuide;

  /// No description provided for @arithmancerGuideBasics.
  ///
  /// In en, this message translates to:
  /// **'• Drag cards from your hand to the battlefield to create mathematical expressions\n• Click \'Execute\' to deal damage based on the result'**
  String get arithmancerGuideBasics;

  /// No description provided for @arithmancerGuideCards.
  ///
  /// In en, this message translates to:
  /// **'• Number cards (green): Provide values\n• Operator cards (yellow): +, -, ×, ÷\n• Parentheses cards (pink): Split into ( and ) for order of operations'**
  String get arithmancerGuideCards;

  /// No description provided for @arithmancerGuideCombat.
  ///
  /// In en, this message translates to:
  /// **'• Each card costs energy to play\n• Higher numbers deal more damage\n• Negative results grant shield points'**
  String get arithmancerGuideCombat;

  /// No description provided for @arithmancerGuideProperties.
  ///
  /// In en, this message translates to:
  /// **'• Prime numbers: 3× damage\n• Perfect squares: 2× damage\n• Fibonacci: 1.7× damage\n• Powers of two: 1.6× damage'**
  String get arithmancerGuideProperties;

  /// No description provided for @arithmancerGuideShields.
  ///
  /// In en, this message translates to:
  /// **'• Enemies have various mathematical shields\n• Some block specific number types\n• Watch enemy descriptions for hints'**
  String get arithmancerGuideShields;

  /// No description provided for @arithmancerGuideDiscard.
  ///
  /// In en, this message translates to:
  /// **'• Drag unwanted cards to the USED pile on the right\n• Use this to manage your hand'**
  String get arithmancerGuideDiscard;

  /// No description provided for @arithmancerGuideSkip.
  ///
  /// In en, this message translates to:
  /// **'• Click the skip button to end your turn\n• Your energy will be doubled for the next round'**
  String get arithmancerGuideSkip;

  /// No description provided for @arithmancerModeSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your combat protocol'**
  String get arithmancerModeSelectionSubtitle;

  /// No description provided for @arithmancerModeNeuralBreachDesc.
  ///
  /// In en, this message translates to:
  /// **'Battle hostile AI programs in sequence'**
  String get arithmancerModeNeuralBreachDesc;

  /// No description provided for @arithmancerModeAiDuelDesc.
  ///
  /// In en, this message translates to:
  /// **'Fight advanced AI personalities one-on-one'**
  String get arithmancerModeAiDuelDesc;

  /// No description provided for @arithmancerModeNeuralLadderDesc.
  ///
  /// In en, this message translates to:
  /// **'Climb through mixed program and AI challenges'**
  String get arithmancerModeNeuralLadderDesc;

  /// Title for the Arithmetic Square puzzle game
  ///
  /// In en, this message translates to:
  /// **'Arithmetic Square'**
  String get arithmeticSquare;

  /// Instructions for playing the Arithmetic Square game
  ///
  /// In en, this message translates to:
  /// **'Fill the empty cells to make each row and column form valid equations!'**
  String get arithmeticSquareInstructions;

  /// Error message when the arithmetic square solution is incorrect
  ///
  /// In en, this message translates to:
  /// **'Some equations don\'t add up! Check your numbers and try again.'**
  String get arithmeticSquareError;

  /// Instruction text above the number pool in arithmetic square
  ///
  /// In en, this message translates to:
  /// **'Drag numbers into the empty cells:'**
  String get arithmeticSquareSelectNumbers;

  /// Title shown in success dialog for arithmetic square
  ///
  /// In en, this message translates to:
  /// **'Mathematical Mastery!'**
  String get arithmeticSquareWinTitle;

  /// Success message for completing arithmetic square puzzle
  ///
  /// In en, this message translates to:
  /// **'Outstanding! You\'ve solved the arithmetic square and earned {bonusScore} bonus points for your mathematical precision!'**
  String arithmeticSquareWinDesc(int bonusScore);

  /// Title for the Arithmancer Crosswords puzzle game
  ///
  /// In en, this message translates to:
  /// **'Arithmancer Crosswords'**
  String get arithmancerCrosswords;

  /// Instructions for playing the Arithmancer Crosswords game
  ///
  /// In en, this message translates to:
  /// **'Solve the intersecting math equations by placing numbers in the crossword grid!'**
  String get arithmancerCrosswordsInstructions;

  /// Error message when the crossword solution is incorrect
  ///
  /// In en, this message translates to:
  /// **'The crossword equations don\'t balance! Check your math and try again.'**
  String get arithmancerCrosswordsError;

  /// No description provided for @arithmancerCrosswordsOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get arithmancerCrosswordsOutOfMoves;

  /// No description provided for @arithmancerCrosswordsOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Plan your moves carefully to solve the crossword efficiently.'**
  String get arithmancerCrosswordsOutOfMovesDesc;

  /// Instruction text above the number pool in arithmancer crosswords
  ///
  /// In en, this message translates to:
  /// **'Drag numbers to fill the crossword:'**
  String get arithmancerCrosswordsSelectNumbers;

  /// Title shown in success dialog for arithmancer crosswords
  ///
  /// In en, this message translates to:
  /// **'Crossword Champion!'**
  String get arithmancerCrosswordsWinTitle;

  /// Success message for completing arithmancer crosswords puzzle
  ///
  /// In en, this message translates to:
  /// **'Brilliant! You\'ve mastered the mathematical crossword and earned {bonusScore} bonus points for your arithmantic prowess!'**
  String arithmancerCrosswordsWinDesc(int bonusScore);

  /// Name of the KenKen puzzle game
  ///
  /// In en, this message translates to:
  /// **'KenKen'**
  String get kenken;

  /// Instructions for playing KenKen
  ///
  /// In en, this message translates to:
  /// **'Fill the grid so each row and column contains every number exactly once. Numbers in cages must satisfy the math clue.'**
  String get kenkenInstructions;

  /// Error message when KenKen solution is incorrect
  ///
  /// In en, this message translates to:
  /// **'Oops! The solution doesn\'t satisfy all constraints. Check the cage math and Latin square rules!'**
  String get kenkenError;

  /// Title for KenKen out-of-moves dialog
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get kenkenOutOfMoves;

  /// Description for KenKen out-of-moves dialog
  ///
  /// In en, this message translates to:
  /// **'Too many placements! Think carefully about each number to solve the KenKen grid efficiently.'**
  String get kenkenOutOfMovesDesc;

  /// Instructions for the number selection pad in KenKen
  ///
  /// In en, this message translates to:
  /// **'Drag numbers to fill the grid:'**
  String get kenkenSelectNumbers;

  /// Title for KenKen win dialog
  ///
  /// In en, this message translates to:
  /// **'Mathematical Mastery!'**
  String get kenkenWinTitle;

  /// Description for KenKen win dialog with bonus score
  ///
  /// In en, this message translates to:
  /// **'Incredible logical thinking! You\'ve solved this KenKen puzzle perfectly and earned {bonusScore} bonus points for your mathematical prowess!'**
  String kenkenWinDesc(int bonusScore);

  /// No description provided for @asteroidFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Field Navigator'**
  String get asteroidFieldTitle;

  /// No description provided for @asteroidFieldInstructions.
  ///
  /// In en, this message translates to:
  /// **'Reveal safe sectors, avoid asteroids! Long-press or use flag mode to mark dangers.'**
  String get asteroidFieldInstructions;

  /// No description provided for @asteroidFieldRevealMode.
  ///
  /// In en, this message translates to:
  /// **'Reveal Mode'**
  String get asteroidFieldRevealMode;

  /// No description provided for @asteroidFieldFlagMode.
  ///
  /// In en, this message translates to:
  /// **'Flag Mode'**
  String get asteroidFieldFlagMode;

  /// No description provided for @asteroidFieldWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Field Cleared!'**
  String get asteroidFieldWinTitle;

  /// Victory message with time, score, and bonuses
  ///
  /// In en, this message translates to:
  /// **'Navigation complete in {time}!\n\nTotal Score: {score}\nSpeed Bonus: +{speedBonus}\nEfficiency Bonus: +{efficiencyBonus}'**
  String asteroidFieldWinDesc(
      String time, int score, int speedBonus, int efficiencyBonus);

  /// No description provided for @asteroidFieldLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Impact!'**
  String get asteroidFieldLoseTitle;

  /// No description provided for @asteroidFieldLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Your ship hit an asteroid. The field has been revealed.'**
  String get asteroidFieldLoseDesc;

  /// No description provided for @nextField.
  ///
  /// In en, this message translates to:
  /// **'Next Field'**
  String get nextField;

  /// No description provided for @cargoBayTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo Bay Arranger'**
  String get cargoBayTitle;

  /// No description provided for @cargoBayInstructions.
  ///
  /// In en, this message translates to:
  /// **'Arrange cargo and watch for number patterns!'**
  String get cargoBayInstructions;

  /// No description provided for @cargoBayNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get cargoBayNext;

  /// No description provided for @cargoBayHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get cargoBayHold;

  /// No description provided for @cargoBayPressC.
  ///
  /// In en, this message translates to:
  /// **'Press C'**
  String get cargoBayPressC;

  /// No description provided for @cargoBayBonuses.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get cargoBayBonuses;

  /// No description provided for @cargoBayKeyboardHints.
  ///
  /// In en, this message translates to:
  /// **'Arrow Keys: Move | ↑: Rotate | Space: Drop | C: Hold'**
  String get cargoBayKeyboardHints;

  /// No description provided for @cargoBayWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get cargoBayWinTitle;

  /// No description provided for @cargoBayWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Perfect! {rows} rows cleared!\n\nScore: {score}\nBonus Total: +{rowBonus}'**
  String cargoBayWinDesc(int rows, int score, int rowBonus);

  /// No description provided for @cargoBayLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo Bay Overloaded!'**
  String get cargoBayLoseTitle;

  /// No description provided for @cargoBayLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The cargo bay is full!\nTry again!'**
  String get cargoBayLoseDesc;

  /// No description provided for @nextShipment.
  ///
  /// In en, this message translates to:
  /// **'Next Shipment'**
  String get nextShipment;

  /// No description provided for @bonusTargetSum.
  ///
  /// In en, this message translates to:
  /// **'Target Sum'**
  String get bonusTargetSum;

  /// No description provided for @bonusTargetSumDesc.
  ///
  /// In en, this message translates to:
  /// **'Full row/column = {target}'**
  String bonusTargetSumDesc(int target);

  /// No description provided for @bonusFibonacciTitle.
  ///
  /// In en, this message translates to:
  /// **'Fibonacci'**
  String get bonusFibonacciTitle;

  /// No description provided for @bonusDoublingTitle.
  ///
  /// In en, this message translates to:
  /// **'Doubling'**
  String get bonusDoublingTitle;

  /// No description provided for @bonusConsecutiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Consecutive'**
  String get bonusConsecutiveTitle;

  /// No description provided for @bonusSquareTitle.
  ///
  /// In en, this message translates to:
  /// **'Square Sum'**
  String get bonusSquareTitle;

  /// No description provided for @moleculeBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Molecule Builder'**
  String get moleculeBuilderTitle;

  /// No description provided for @moleculeBuilderInstructions.
  ///
  /// In en, this message translates to:
  /// **'Slide atoms to form the target molecule! Atoms glide until hitting a wall or another atom.'**
  String get moleculeBuilderInstructions;

  /// No description provided for @moleculeBuilderMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moleculeBuilderMoves;

  /// No description provided for @moleculeBuilderAtoms.
  ///
  /// In en, this message translates to:
  /// **'Atoms'**
  String get moleculeBuilderAtoms;

  /// No description provided for @moleculeBuilderTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get moleculeBuilderTarget;

  /// No description provided for @moleculeBuilderSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get moleculeBuilderSelected;

  /// No description provided for @moleculeBuilderNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get moleculeBuilderNone;

  /// No description provided for @moleculeBuilderPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get moleculeBuilderPrevious;

  /// No description provided for @moleculeBuilderNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get moleculeBuilderNext;

  /// No description provided for @moleculeBuilderRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get moleculeBuilderRestart;

  /// No description provided for @moleculeBuilderLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get moleculeBuilderLevel;

  /// No description provided for @moleculeBuilderWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Molecule Complete!'**
  String get moleculeBuilderWinTitle;

  /// Victory message with moves and score
  ///
  /// In en, this message translates to:
  /// **'Solved in {moves} moves\nScore: {score} (+{efficiencyBonus} bonus)'**
  String moleculeBuilderWinDesc(int moves, int score, int efficiencyBonus);

  /// No description provided for @moleculeBuilderLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get moleculeBuilderLoseTitle;

  /// No description provided for @moleculeBuilderLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Move limit exceeded! The molecular structure remains incomplete.\nStudy the pattern and try again, scientist!'**
  String get moleculeBuilderLoseDesc;

  /// No description provided for @moleculeBuilderNextMolecule.
  ///
  /// In en, this message translates to:
  /// **'Next Molecule'**
  String get moleculeBuilderNextMolecule;

  /// No description provided for @moleculeBuilderUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get moleculeBuilderUndo;

  /// No description provided for @moleculeBuilderHelp.
  ///
  /// In en, this message translates to:
  /// **'Help / Instructions'**
  String get moleculeBuilderHelp;

  /// No description provided for @moleculeBuilderInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Play'**
  String get moleculeBuilderInfoTitle;

  /// No description provided for @moleculeBuilderInfoGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal: Arrange the loose atoms on the grid to perfectly match the target molecule structure shown on the left.'**
  String get moleculeBuilderInfoGoal;

  /// No description provided for @moleculeBuilderInfoHowTo.
  ///
  /// In en, this message translates to:
  /// **'How to Play: Tap an atom to select it. Then, use the arrow buttons or swipe on the atom to slide it. Atoms will slide in a straight line until they hit a wall or another atom.'**
  String get moleculeBuilderInfoHowTo;

  /// No description provided for @moleculeBuilderInfoMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves: Each slide costs one move. Try to build the molecule before you run out of moves!'**
  String get moleculeBuilderInfoMoves;

  /// No description provided for @moleculeBuilderInfoUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo: The \'Undo\' button will revert your last move, but it costs 2 moves as a penalty.'**
  String get moleculeBuilderInfoUndo;

  /// No description provided for @level01Label.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get level01Label;

  /// No description provided for @level02Label.
  ///
  /// In en, this message translates to:
  /// **'Methane'**
  String get level02Label;

  /// No description provided for @level03Label.
  ///
  /// In en, this message translates to:
  /// **'Methanol'**
  String get level03Label;

  /// No description provided for @level04Label.
  ///
  /// In en, this message translates to:
  /// **'Ethylene'**
  String get level04Label;

  /// No description provided for @level05Label.
  ///
  /// In en, this message translates to:
  /// **'Propene'**
  String get level05Label;

  /// No description provided for @level06Label.
  ///
  /// In en, this message translates to:
  /// **'Bonus Section 1'**
  String get level06Label;

  /// No description provided for @level07Label.
  ///
  /// In en, this message translates to:
  /// **'Ethanol'**
  String get level07Label;

  /// No description provided for @level08Label.
  ///
  /// In en, this message translates to:
  /// **'Isopropanol'**
  String get level08Label;

  /// No description provided for @level09Label.
  ///
  /// In en, this message translates to:
  /// **'Ethanal'**
  String get level09Label;

  /// No description provided for @level10Label.
  ///
  /// In en, this message translates to:
  /// **'Acetone'**
  String get level10Label;

  /// No description provided for @level11Label.
  ///
  /// In en, this message translates to:
  /// **'Formic Acid'**
  String get level11Label;

  /// No description provided for @level12Label.
  ///
  /// In en, this message translates to:
  /// **'Bonus Section 2'**
  String get level12Label;

  /// No description provided for @level13Label.
  ///
  /// In en, this message translates to:
  /// **'Acetic Acid'**
  String get level13Label;

  /// No description provided for @level14Label.
  ///
  /// In en, this message translates to:
  /// **'trans-Butene'**
  String get level14Label;

  /// No description provided for @level15Label.
  ///
  /// In en, this message translates to:
  /// **'cis-Butene'**
  String get level15Label;

  /// No description provided for @level16Label.
  ///
  /// In en, this message translates to:
  /// **'Dimethyl ether'**
  String get level16Label;

  /// No description provided for @level17Label.
  ///
  /// In en, this message translates to:
  /// **'Butanol'**
  String get level17Label;

  /// No description provided for @level18Label.
  ///
  /// In en, this message translates to:
  /// **'Bonus Section 3'**
  String get level18Label;

  /// No description provided for @level19Label.
  ///
  /// In en, this message translates to:
  /// **'2-Methyl-2-Propanol'**
  String get level19Label;

  /// No description provided for @level20Label.
  ///
  /// In en, this message translates to:
  /// **'Glycerin'**
  String get level20Label;

  /// No description provided for @level21Label.
  ///
  /// In en, this message translates to:
  /// **'Poly-Tetra-Fluoro-Ethene'**
  String get level21Label;

  /// No description provided for @level22Label.
  ///
  /// In en, this message translates to:
  /// **'Oxalic Acid'**
  String get level22Label;

  /// No description provided for @level23Label.
  ///
  /// In en, this message translates to:
  /// **'Formaldehyde'**
  String get level23Label;

  /// No description provided for @level24Label.
  ///
  /// In en, this message translates to:
  /// **'Bonus Section 4'**
  String get level24Label;

  /// No description provided for @level25Label.
  ///
  /// In en, this message translates to:
  /// **'Acetic acid ethyl ester'**
  String get level25Label;

  /// No description provided for @level26Label.
  ///
  /// In en, this message translates to:
  /// **'Ammonia'**
  String get level26Label;

  /// No description provided for @level27Label.
  ///
  /// In en, this message translates to:
  /// **'3-Methyl-Pentane'**
  String get level27Label;

  /// No description provided for @level28Label.
  ///
  /// In en, this message translates to:
  /// **'Propanal'**
  String get level28Label;

  /// No description provided for @level29Label.
  ///
  /// In en, this message translates to:
  /// **'Propyne'**
  String get level29Label;

  /// No description provided for @level30Label.
  ///
  /// In en, this message translates to:
  /// **'Bonus Section 5'**
  String get level30Label;

  /// No description provided for @atomNameHydrogen.
  ///
  /// In en, this message translates to:
  /// **'Hydrogen'**
  String get atomNameHydrogen;

  /// No description provided for @atomNameOxygen.
  ///
  /// In en, this message translates to:
  /// **'Oxygen'**
  String get atomNameOxygen;

  /// No description provided for @atomNameCarbon.
  ///
  /// In en, this message translates to:
  /// **'Carbon'**
  String get atomNameCarbon;

  /// No description provided for @atomNameNitrogen.
  ///
  /// In en, this message translates to:
  /// **'Nitrogen'**
  String get atomNameNitrogen;

  /// No description provided for @atomNameSulfur.
  ///
  /// In en, this message translates to:
  /// **'Sulfur'**
  String get atomNameSulfur;

  /// No description provided for @atomNameFluorine.
  ///
  /// In en, this message translates to:
  /// **'Fluorine'**
  String get atomNameFluorine;

  /// No description provided for @atomNameSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get atomNameSpecial;

  /// No description provided for @moleculeBuilderMoleculeInfo.
  ///
  /// In en, this message translates to:
  /// **'Molecule Info'**
  String get moleculeBuilderMoleculeInfo;

  /// No description provided for @moleculeBuilderBonusTitle.
  ///
  /// In en, this message translates to:
  /// **'Bonus Target'**
  String get moleculeBuilderBonusTitle;

  /// No description provided for @moleculeInfoNomenclature.
  ///
  /// In en, this message translates to:
  /// **'Nomenclature & Description'**
  String get moleculeInfoNomenclature;

  /// No description provided for @moleculeInfoKeyFacts.
  ///
  /// In en, this message translates to:
  /// **'Key Facts'**
  String get moleculeInfoKeyFacts;

  /// No description provided for @moleculeInfoInSpace.
  ///
  /// In en, this message translates to:
  /// **'In Space'**
  String get moleculeInfoInSpace;

  /// No description provided for @level01Desc.
  ///
  /// In en, this message translates to:
  /// **'Water (H₂O) is an inorganic compound essential for all known forms of life. It is a tasteless, odorless liquid at standard temperature, often called the \'universal solvent\' for its ability to dissolve many substances.'**
  String get level01Desc;

  /// No description provided for @level01Facts.
  ///
  /// In en, this message translates to:
  /// **'• Consists of two hydrogen atoms covalently bonded to a single oxygen atom.\n• Due to its polarity, it exhibits strong hydrogen bonds, leading to a high boiling point and surface tension.\n• Ice is less dense than liquid water, a rare property that allows aquatic life to survive under frozen surfaces.'**
  String get level01Facts;

  /// No description provided for @level01Space.
  ///
  /// In en, this message translates to:
  /// **'Water is abundant in interstellar clouds, on comets, and on icy moons like Europa. In the vacuum of space, liquid water cannot exist; it either freezes into ice or boils away into vapor. On Mars, its low atmospheric pressure means water boils at just above 0°C (32°F).'**
  String get level01Space;

  /// No description provided for @level02Desc.
  ///
  /// In en, this message translates to:
  /// **'Methane (CH₄) is the simplest alkane and the primary component of natural gas. It is a colorless, odorless gas and a potent greenhouse gas.'**
  String get level02Desc;

  /// No description provided for @level02Facts.
  ///
  /// In en, this message translates to:
  /// **'• Features a central carbon atom bonded to four hydrogen atoms in a tetrahedral geometry.\n• Produced by anaerobic bacteria in environments like wetlands and the digestive tracts of ruminants.\n• A key fuel source and a starting material for the chemical industry.'**
  String get level02Facts;

  /// No description provided for @level02Space.
  ///
  /// In en, this message translates to:
  /// **'Methane is common in our solar system. Titan, Saturn\'s largest moon, has a thick methane atmosphere with rivers and lakes of liquid methane on its surface, where the temperature is a frigid -179°C (-290°F).'**
  String get level02Space;

  /// No description provided for @level03Desc.
  ///
  /// In en, this message translates to:
  /// **'Methanol (CH₃OH), or wood alcohol, is the simplest alcohol. It is a light, volatile, colorless, and flammable liquid with a distinctive odor.'**
  String get level03Desc;

  /// No description provided for @level03Facts.
  ///
  /// In en, this message translates to:
  /// **'• Composed of a methyl group (-CH₃) linked to a hydroxyl group (-OH).\n• It is highly toxic if ingested and is used as a solvent, antifreeze, and in chemical synthesis.\n• An important fuel in some specialized engines.'**
  String get level03Facts;

  /// No description provided for @level03Space.
  ///
  /// In en, this message translates to:
  /// **'Vast clouds of methanol exist in star-forming regions of the Milky Way. It forms on the surface of icy dust grains and is considered a key building block for more complex organic molecules in space.'**
  String get level03Space;

  /// No description provided for @level04Desc.
  ///
  /// In en, this message translates to:
  /// **'Ethylene (C₂H₄), or ethene, is the simplest alkene, characterized by a carbon-carbon double bond. It is a colorless flammable gas with a faint sweet odor.'**
  String get level04Desc;

  /// No description provided for @level04Facts.
  ///
  /// In en, this message translates to:
  /// **'• The most produced organic compound in the world, primarily used to make polyethylene plastic.\n• Acts as a natural plant hormone, regulating processes like fruit ripening, flower opening, and leaf shedding.\n• The double bond makes it much more reactive than ethane.'**
  String get level04Facts;

  /// No description provided for @level04Space.
  ///
  /// In en, this message translates to:
  /// **'Ethylene is present in the atmospheres of gas giants like Jupiter and Saturn. On Titan, sunlight breaks down methane into more complex hydrocarbons, including ethylene, contributing to the moon\'s orange haze.'**
  String get level04Space;

  /// No description provided for @level05Desc.
  ///
  /// In en, this message translates to:
  /// **'Propene (C₃H₆), or propylene, is an alkene with three carbon atoms and one double bond. It is a colorless gas with a faint petroleum-like odor.'**
  String get level05Desc;

  /// No description provided for @level05Facts.
  ///
  /// In en, this message translates to:
  /// **'• A vital starting material in the petrochemical industry, second only to ethylene.\n• Primarily used to produce polypropylene, a versatile plastic used in packaging, textiles, and automotive parts.\n• Produced by steam cracking of hydrocarbon feedstocks.'**
  String get level05Facts;

  /// No description provided for @level05Space.
  ///
  /// In en, this message translates to:
  /// **'NASA\'s Cassini spacecraft detected propene on Titan. Its presence helps scientists model the complex atmospheric chemistry on worlds rich in methane, providing insights into how building blocks for life might form.'**
  String get level05Space;

  /// No description provided for @level07Desc.
  ///
  /// In en, this message translates to:
  /// **'Ethanol (C₂H₅OH), or grain alcohol, is the alcohol found in alcoholic beverages. It is a volatile, flammable, colorless liquid produced by the fermentation of sugars.'**
  String get level07Desc;

  /// No description provided for @level07Facts.
  ///
  /// In en, this message translates to:
  /// **'• Composed of an ethyl group (-C₂H₅) bonded to a hydroxyl group (-OH).\n• Widely used as a solvent, antiseptic, and as a renewable biofuel to supplement gasoline.\n• It is a central nervous system depressant.'**
  String get level07Facts;

  /// No description provided for @level07Space.
  ///
  /// In en, this message translates to:
  /// **'Gigantic clouds of ethanol, billions of kilometers wide, have been found floating in interstellar space. These cosmic spirits are formed on dust grains and are not drinkable! On Mars, the low pressure would cause ethanol to boil at just 10°C (50°F).'**
  String get level07Space;

  /// No description provided for @level08Desc.
  ///
  /// In en, this message translates to:
  /// **'Isopropanol ((CH₃)₂CHOH), or isopropyl alcohol, is a common disinfectant and cleaning agent, widely known as rubbing alcohol. It is an isomer of propanol.'**
  String get level08Desc;

  /// No description provided for @level08Facts.
  ///
  /// In en, this message translates to:
  /// **'• The hydroxyl group (-OH) is attached to the middle carbon of the three-carbon chain.\n• Its ability to dissolve oils and its rapid evaporation make it an effective cleaner for electronics and a de-icing agent.\n• It is toxic to ingest.'**
  String get level08Facts;

  /// No description provided for @level08Space.
  ///
  /// In en, this message translates to:
  /// **'Isopropanol was definitively detected in a star-forming cloud near the center of our galaxy, Sagittarius B2. It is the largest alcohol found so far with a branched structure, giving clues about how complex organic molecules form between stars.'**
  String get level08Space;

  /// No description provided for @level09Desc.
  ///
  /// In en, this message translates to:
  /// **'Ethanal (CH₃CHO), commonly known as acetaldehyde, is a reactive, colorless liquid with a pungent, fruity odor. It is an important intermediate in organic synthesis and metabolism.'**
  String get level09Desc;

  /// No description provided for @level09Facts.
  ///
  /// In en, this message translates to:
  /// **'• Occurs naturally in coffee, bread, and ripe fruit.\n• In the human body, it is an intermediate in the breakdown of ethanol and is a major cause of hangover symptoms.\n• Used to produce acetic acid, perfumes, and dyes.'**
  String get level09Facts;

  /// No description provided for @level09Space.
  ///
  /// In en, this message translates to:
  /// **'Acetaldehyde is found in comets and interstellar molecular clouds. It is a key prebiotic molecule because it can react to form amino acids like alanine under space-like conditions, suggesting that life\'s building blocks may have extraterrestrial origins.'**
  String get level09Space;

  /// No description provided for @level10Desc.
  ///
  /// In en, this message translates to:
  /// **'Acetone (CH₃COCH₃), or propanone, is the simplest ketone. It is a colorless, volatile, and flammable liquid with a distinctive sweet, pungent odor. It\'s a common solvent, famously used in nail polish remover.'**
  String get level10Desc;

  /// No description provided for @level10Facts.
  ///
  /// In en, this message translates to:
  /// **'• Features a central carbonyl group (C=O) bonded to two methyl groups.\n• Miscible with water and serves as an important solvent for cleaning in laboratory and industrial settings.\n• The human body naturally produces small amounts of acetone during metabolism.'**
  String get level10Facts;

  /// No description provided for @level10Space.
  ///
  /// In en, this message translates to:
  /// **'Acetone has been detected in the gas cloud surrounding Comet 67P by the Rosetta spacecraft. Its presence on comets suggests that these \'dirty snowballs\' could have delivered a cocktail of complex organic molecules to the early Earth.'**
  String get level10Space;

  /// No description provided for @level11Desc.
  ///
  /// In en, this message translates to:
  /// **'Formic Acid (HCOOH) is the simplest carboxylic acid. It is a colorless liquid with a pungent, penetrating odor. It is naturally found in the venom of ants and bees.'**
  String get level11Desc;

  /// No description provided for @level11Facts.
  ///
  /// In en, this message translates to:
  /// **'• Its name comes from the Latin word for ant, \'formica\', as it was first isolated from ant bodies.\n• Used as a preservative and antibacterial agent in livestock feed.\n• It is corrosive and an irritant to the skin.'**
  String get level11Facts;

  /// No description provided for @level11Space.
  ///
  /// In en, this message translates to:
  /// **'Formic acid is abundant in interstellar clouds and has been observed in comets. It is a key molecule for astrochemists because it contains the carboxyl group (-COOH) that is the defining feature of all amino acids, the building blocks of proteins.'**
  String get level11Space;

  /// No description provided for @level13Desc.
  ///
  /// In en, this message translates to:
  /// **'Acetic Acid (CH₃COOH) is a carboxylic acid that gives vinegar its sour taste and pungent smell. In its pure, water-free form, it is called glacial acetic acid.'**
  String get level13Desc;

  /// No description provided for @level13Facts.
  ///
  /// In en, this message translates to:
  /// **'• Consists of a methyl group bonded to a carboxyl group.\n• A fundamental chemical reagent and industrial chemical, used in the production of plastics, photographic film, and textiles.\n• A weak acid, it is used as a food additive (E260) for acidity regulation.'**
  String get level13Facts;

  /// No description provided for @level13Space.
  ///
  /// In en, this message translates to:
  /// **'Acetic acid has been detected in the hot molecular cores of star-forming regions like Sagittarius B2. Its presence suggests that the chemistry in these stellar nurseries is complex enough to form the key components of biochemistry.'**
  String get level13Space;

  /// No description provided for @level14Desc.
  ///
  /// In en, this message translates to:
  /// **'trans-Butene is an isomer of butene (C₄H₈) where the main carbon chains are on opposite sides of the carbon-carbon double bond. This \'trans\' configuration makes it more stable than its cis-isomer.'**
  String get level14Desc;

  /// No description provided for @level14Facts.
  ///
  /// In en, this message translates to:
  /// **'• The rigid double bond prevents rotation, creating distinct geometric isomers.\n• It is a colorless, flammable gas at room temperature.\n• Used in the production of synthetic rubber and other chemicals.'**
  String get level14Facts;

  /// No description provided for @level14Space.
  ///
  /// In en, this message translates to:
  /// **'The relative abundance of cis and trans isomers in space can tell astronomers about the conditions under which they formed. A high-temperature, gas-phase reaction might produce a different ratio of isomers than a low-temperature reaction on the surface of an ice grain.'**
  String get level14Space;

  /// No description provided for @level15Desc.
  ///
  /// In en, this message translates to:
  /// **'cis-Butene is an isomer of butene (C₄H₈) where the main carbon chains are on the same side of the carbon-carbon double bond. This configuration is less stable than the trans-isomer due to steric strain.'**
  String get level15Desc;

  /// No description provided for @level15Facts.
  ///
  /// In en, this message translates to:
  /// **'• Has a slightly higher boiling point than its trans-isomer due to a small molecular dipole moment.\n• The cis-trans isomerism is critically important in biology, especially in the function of fatty acids and vision (retinal).'**
  String get level15Facts;

  /// No description provided for @level15Space.
  ///
  /// In en, this message translates to:
  /// **'Detecting specific isomers like cis-butene in space is a major challenge for radio astronomy. A confirmed detection could provide deep insights into the physical and chemical processes occurring in protoplanetary disks, where new planets are born.'**
  String get level15Space;

  /// No description provided for @level16Desc.
  ///
  /// In en, this message translates to:
  /// **'Dimethyl ether (CH₃OCH₃) is the simplest ether. It is a colorless gas that is an isomer of ethanol, but with very different properties due to the lack of hydrogen bonding.'**
  String get level16Desc;

  /// No description provided for @level16Facts.
  ///
  /// In en, this message translates to:
  /// **'• It is being developed as a clean-burning alternative fuel for diesel engines, as it produces very low emissions of particulates and NOx.\n• Used as a propellant in aerosol spray cans, replacing CFCs.\n• Can be produced from natural gas, coal, or biomass.'**
  String get level16Facts;

  /// No description provided for @level16Space.
  ///
  /// In en, this message translates to:
  /// **'Dimethyl ether is one of the most abundant large organic molecules found in star-forming clouds. It serves as a crucial chemical tracer for astronomers, helping them gauge the temperature and density of the regions where stars and planets are forming.'**
  String get level16Space;

  /// No description provided for @level17Desc.
  ///
  /// In en, this message translates to:
  /// **'Butanol (C₄H₉OH) is a four-carbon alcohol with several isomers. Butan-1-ol, shown here, is a primary alcohol with a banana-like odor. It is used as a solvent and is being researched as a biofuel.'**
  String get level17Desc;

  /// No description provided for @level17Facts.
  ///
  /// In en, this message translates to:
  /// **'• As a biofuel (\'biobutanol\'), it has a higher energy density than ethanol and is less corrosive, making it a more attractive gasoline alternative.\n• Used in a wide range of applications, including as an artificial flavoring in food and an ingredient in perfumes.\n• Its isomers include isobutanol and tert-butanol.'**
  String get level17Facts;

  /// No description provided for @level17Space.
  ///
  /// In en, this message translates to:
  /// **'Complex alcohols larger than propanol have not yet been definitively found in interstellar space. The search for butanol is ongoing, as its discovery would push the boundary of known interstellar chemistry and confirm that larger, more complex organic structures can form between the stars.'**
  String get level17Space;

  /// No description provided for @level19Desc.
  ///
  /// In en, this message translates to:
  /// **'2-Methyl-2-Propanol ((CH₃)₃COH), also known as tert-Butanol, is the simplest tertiary alcohol. It is a colorless solid at room temperature, which melts easily and has a camphor-like odor.'**
  String get level19Desc;

  /// No description provided for @level19Facts.
  ///
  /// In en, this message translates to:
  /// **'• The \'tert\' (tertiary) refers to the central carbon being attached to three other carbon atoms.\n• Used as a solvent, a denaturant for ethanol, and a gasoline octane booster.\n• Its bulky shape prevents it from reacting in the same way as other butanol isomers.'**
  String get level19Facts;

  /// No description provided for @level19Space.
  ///
  /// In en, this message translates to:
  /// **'Detecting a branched tertiary alcohol like this one in space would be a monumental discovery. It would prove that not only can long chains form, but complex, branched structures can also be synthesized in the harsh environment of interstellar clouds, expanding the inventory of prebiotic molecules.'**
  String get level19Space;

  /// No description provided for @level20Desc.
  ///
  /// In en, this message translates to:
  /// **'Glycerin (C₃H₈O₃), or glycerol, is a simple polyol compound. It is a colorless, odorless, viscous, and sweet-tasting liquid. It is non-toxic and is the backbone of all triglycerides (fats).'**
  String get level20Desc;

  /// No description provided for @level20Facts.
  ///
  /// In en, this message translates to:
  /// **'• The three hydroxyl (-OH) groups make it highly water-soluble and hygroscopic (it attracts and holds water molecules).\n• Widely used in food as a sweetener, in pharmaceuticals, and in personal care products like soap and moisturizers.\n• A natural antifreeze in some arctic and alpine insects.'**
  String get level20Facts;

  /// No description provided for @level20Space.
  ///
  /// In en, this message translates to:
  /// **'Glycerol is a key molecule in the search for extraterrestrial life. Its ability to act as a solvent and lower the freezing point of water could make liquids stable on otherwise frozen worlds, potentially creating habitable environments on icy moons or exoplanets.'**
  String get level20Space;

  /// No description provided for @level21Desc.
  ///
  /// In en, this message translates to:
  /// **'Poly-Tetra-Fluoro-Ethene ((C₂F₄)n), or PTFE, is a synthetic polymer best known by the brand name Teflon. The image shows its monomer, tetrafluoroethene.'**
  String get level21Desc;

  /// No description provided for @level21Facts.
  ///
  /// In en, this message translates to:
  /// **'• It has one of the lowest coefficients of friction of any solid, making it extremely non-stick.\n• Highly resistant to chemical attack and stable over a wide range of temperatures.\n• Used in non-stick cookware, pipe linings, and medical devices.'**
  String get level21Facts;

  /// No description provided for @level21Space.
  ///
  /// In en, this message translates to:
  /// **'Fluorine is a relatively rare element in the cosmos. While complex fluoropolymers are not expected to form naturally in space, PTFE\'s incredible durability and low-friction properties make it a vital material for space exploration, used in everything from spacesuits to rover components.'**
  String get level21Space;

  /// No description provided for @level22Desc.
  ///
  /// In en, this message translates to:
  /// **'Oxalic Acid ((COOH)₂) is the simplest dicarboxylic acid. It is a colorless crystalline solid that dissolves in water to give a colorless solution. It is a much stronger acid than acetic acid.'**
  String get level22Desc;

  /// No description provided for @level22Facts.
  ///
  /// In en, this message translates to:
  /// **'• Found naturally in many plants, including leafy greens (like spinach), vegetables, fruits, and nuts.\n• It binds with minerals like calcium to form crystals, which are the main component of the most common type of kidney stones.\n• Used as a cleaning and bleaching agent, especially for removing rust.'**
  String get level22Facts;

  /// No description provided for @level22Space.
  ///
  /// In en, this message translates to:
  /// **'On Mars, instruments aboard rovers have detected minerals that could be associated with oxalates. The presence of these salts suggests that water and organic chemistry have occurred on the Red Planet, providing clues about its past habitability.'**
  String get level22Space;

  /// No description provided for @level23Desc.
  ///
  /// In en, this message translates to:
  /// **'Formaldehyde (CH₂O), or methanal, is the simplest aldehyde. It is a colorless gas with a characteristic pungent, irritating odor. It\'s a crucial precursor to many other chemical compounds.'**
  String get level23Desc;

  /// No description provided for @level23Facts.
  ///
  /// In en, this message translates to:
  /// **'• Used in the production of industrial resins, such as for particleboard and coatings.\n• An important preservative and disinfectant, though its use is now limited due to its carcinogenicity.\n• It is a product of combustion and is found in tobacco smoke.'**
  String get level23Facts;

  /// No description provided for @level23Space.
  ///
  /// In en, this message translates to:
  /// **'Formaldehyde is a cornerstone of astrochemistry. It was one of the first organic molecules detected in the interstellar medium. It forms readily on cosmic ice grains and is considered a starting point for the synthesis of more complex molecules, including sugars like ribose, a component of RNA.'**
  String get level23Space;

  /// No description provided for @level25Desc.
  ///
  /// In en, this message translates to:
  /// **'Acetic acid ethyl ester (CH₃COOC₂H₅), or ethyl acetate, is a common ester. It is a colorless liquid with a characteristic sweet, fruity smell, reminiscent of pear drops or nail polish remover.'**
  String get level25Desc;

  /// No description provided for @level25Facts.
  ///
  /// In en, this message translates to:
  /// **'• It is an excellent solvent used in glues, nail polish removers, and for decaffeinating tea and coffee.\n• Used as an artificial fruit flavoring in foods, perfumes, and candies.\n• Produced on a large scale for use as a solvent.'**
  String get level25Facts;

  /// No description provided for @level25Space.
  ///
  /// In en, this message translates to:
  /// **'Ethyl acetate has been detected in the dust cloud at the center of the Milky Way. Esters are responsible for many of the pleasant smells and tastes we know on Earth (like fruits and flowers). Finding them in space suggests that the universe is a chemically rich place, capable of creating the molecules we associate with life.'**
  String get level25Space;

  /// No description provided for @level26Desc.
  ///
  /// In en, this message translates to:
  /// **'Ammonia (NH₃) is a compound of nitrogen and hydrogen. It\'s a colorless gas with a very sharp, pungent odor. It is a fundamental building block for fertilizers, plastics, and pharmaceuticals.'**
  String get level26Desc;

  /// No description provided for @level26Facts.
  ///
  /// In en, this message translates to:
  /// **'• One of the most highly produced inorganic chemicals in the world, primarily for use in nitrogen fertilizers.\n• Its ability to form hydrogen bonds makes it very soluble in water.\n• A key compound in the nitrogen cycle, essential for making proteins and nucleic acids.'**
  String get level26Facts;

  /// No description provided for @level26Space.
  ///
  /// In en, this message translates to:
  /// **'Ammonia is a major component of the atmospheres of Jupiter and Saturn, where it forms brilliant white clouds of ammonia ice. It is also frozen solid in comets and on icy moons. The presence of ammonia is a key indicator of the availability of nitrogen for chemistry on other worlds.'**
  String get level26Space;

  /// No description provided for @level27Desc.
  ///
  /// In en, this message translates to:
  /// **'3-Methyl-Pentane (C₆H₁₄) is a branched-chain alkane and an isomer of hexane. It is a colorless, flammable liquid and a component of gasoline.'**
  String get level27Desc;

  /// No description provided for @level27Facts.
  ///
  /// In en, this message translates to:
  /// **'• As a branched alkane, it has a higher octane rating than straight-chain hexane, making it a better fuel component for preventing engine knocking.\n• It is refined from crude oil.\n• It has two enantiomers, (3R)-methylpentane and (3S)-methylpentane, which are mirror images of each other.'**
  String get level27Facts;

  /// No description provided for @level27Space.
  ///
  /// In en, this message translates to:
  /// **'While simple alkanes like methane are common, larger branched alkanes are harder to detect in space. However, they are found in carbonaceous chondrite meteorites. These meteorites are pristine samples from the early solar system and show that complex organic chemistry, including the formation of isomers, was active when the planets were forming.'**
  String get level27Space;

  /// No description provided for @level28Desc.
  ///
  /// In en, this message translates to:
  /// **'Propanal (CH₃CH₂CHO) is a three-carbon aldehyde. It is a colorless, flammable liquid with a fruity yet suffocating odor. It is an isomer of acetone.'**
  String get level28Desc;

  /// No description provided for @level28Facts.
  ///
  /// In en, this message translates to:
  /// **'• It is primarily used as a precursor to other chemicals, such as propanol and various resins.\n• Like other aldehydes, it is a reactive compound due to its carbonyl group.\n• It can be formed from the oxidation of propan-1-ol.'**
  String get level28Facts;

  /// No description provided for @level28Space.
  ///
  /// In en, this message translates to:
  /// **'Propanal has been detected in the Sagittarius B2 star-forming region. Along with its isomer acetone, its detection helps astronomers map the chemical complexity of the interstellar medium and understand the formation routes of molecules containing the important carbonyl functional group.'**
  String get level28Space;

  /// No description provided for @level29Desc.
  ///
  /// In en, this message translates to:
  /// **'Propyne (C₃H₄) is an alkyne with three carbon atoms and a carbon-carbon triple bond. It is a colorless, flammable gas. It is a convenient, liquid-at-room-temperature alternative to acetylene.'**
  String get level29Desc;

  /// No description provided for @level29Facts.
  ///
  /// In en, this message translates to:
  /// **'• The triple bond makes it highly reactive and useful in organic synthesis.\n• It is a component of MAPP gas, a fuel gas used in welding and brazing for its high flame temperature.\n• It is an isomer of both propadiene and cyclopropene.'**
  String get level29Facts;

  /// No description provided for @level29Space.
  ///
  /// In en, this message translates to:
  /// **'Propyne has been detected in the interstellar medium, particularly in the atmosphere of Saturn\'s moon Titan. On Titan, complex photochemistry driven by sunlight breaks down methane and nitrogen, creating a rich soup of hydrocarbons, including propyne, which contribute to its atmospheric haze.'**
  String get level29Space;

  /// No description provided for @spaceGridlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Space Station Gridlock'**
  String get spaceGridlockTitle;

  /// No description provided for @spaceGridlockInstructions.
  ///
  /// In en, this message translates to:
  /// **'Drag ships to clear a path! Guide your ship to the exit on the right.'**
  String get spaceGridlockInstructions;

  /// No description provided for @spaceGridlockReset.
  ///
  /// In en, this message translates to:
  /// **'Reset Puzzle'**
  String get spaceGridlockReset;

  /// No description provided for @spaceGridlockWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Docking Complete!'**
  String get spaceGridlockWinTitle;

  /// No description provided for @spaceGridlockPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect!'**
  String get spaceGridlockPerfect;

  /// No description provided for @spaceGridlockGreat.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get spaceGridlockGreat;

  /// No description provided for @spaceGridlockGood.
  ///
  /// In en, this message translates to:
  /// **'Good!'**
  String get spaceGridlockGood;

  /// Victory message with moves, score, and performance rating
  ///
  /// In en, this message translates to:
  /// **'Ship docked in {moves} moves!\nOptimal: {minMoves} moves\nPerformance: {performance}\n\nTotal Score: {score}\nEfficiency Bonus: +{bonus}'**
  String spaceGridlockWinDesc(
      int moves, int minMoves, String performance, int score, int bonus);

  /// No description provided for @nextPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Next Puzzle'**
  String get nextPuzzle;

  /// No description provided for @baseScore.
  ///
  /// In en, this message translates to:
  /// **'Base Score'**
  String get baseScore;

  /// No description provided for @efficiencyBonus.
  ///
  /// In en, this message translates to:
  /// **'Efficiency Bonus'**
  String get efficiencyBonus;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get grade;

  /// No description provided for @emptyProgram.
  ///
  /// In en, this message translates to:
  /// **'Drag commands here'**
  String get emptyProgram;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @shoot.
  ///
  /// In en, this message translates to:
  /// **'shoot'**
  String get shoot;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'jump'**
  String get jump;

  /// No description provided for @robotPathJump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get robotPathJump;

  /// No description provided for @robotPathDestroy.
  ///
  /// In en, this message translates to:
  /// **'Destroy'**
  String get robotPathDestroy;

  /// No description provided for @robotPathWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get robotPathWait;

  /// No description provided for @robotPathPush.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get robotPathPush;

  /// No description provided for @robotPathPull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get robotPathPull;

  /// No description provided for @robotPathTooltipWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get robotPathTooltipWall;

  /// No description provided for @robotPathTooltipJumpable.
  ///
  /// In en, this message translates to:
  /// **'Jumpable Gap'**
  String get robotPathTooltipJumpable;

  /// No description provided for @robotPathTooltipDestructible.
  ///
  /// In en, this message translates to:
  /// **'Destructible Rock'**
  String get robotPathTooltipDestructible;

  /// No description provided for @robotPathTooltipMovable.
  ///
  /// In en, this message translates to:
  /// **'Movable Block'**
  String get robotPathTooltipMovable;

  /// No description provided for @robotPathTooltipStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get robotPathTooltipStart;

  /// No description provided for @robotPathTooltipGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get robotPathTooltipGoal;

  /// No description provided for @robotPathErrorNotDestructible.
  ///
  /// In en, this message translates to:
  /// **'Target is not destructible!'**
  String get robotPathErrorNotDestructible;

  /// No description provided for @robotPathErrorNotJumpable.
  ///
  /// In en, this message translates to:
  /// **'Cannot jump over this!'**
  String get robotPathErrorNotJumpable;

  /// No description provided for @robotPathErrorNotMovable.
  ///
  /// In en, this message translates to:
  /// **'Target is not movable!'**
  String get robotPathErrorNotMovable;

  /// No description provided for @robotPathErrorCannotPush.
  ///
  /// In en, this message translates to:
  /// **'Cannot push! Destination is blocked.'**
  String get robotPathErrorCannotPush;

  /// No description provided for @robotPathErrorCannotPull.
  ///
  /// In en, this message translates to:
  /// **'Cannot pull! Not enough space.'**
  String get robotPathErrorCannotPull;

  /// No description provided for @robotPathTitle.
  ///
  /// In en, this message translates to:
  /// **'Robot Path'**
  String get robotPathTitle;

  /// No description provided for @robotPathDesc.
  ///
  /// In en, this message translates to:
  /// **'Program the robot to reach the goal!'**
  String get robotPathDesc;

  /// No description provided for @robotPathError.
  ///
  /// In en, this message translates to:
  /// **'Crash! Robot hit an obstacle.'**
  String get robotPathError;

  /// No description provided for @robotPathNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Path incomplete. The robot did not reach the goal.'**
  String get robotPathNotComplete;

  /// No description provided for @robotPathSuccess.
  ///
  /// In en, this message translates to:
  /// **'Target Acquired! Robot has reached the destination.'**
  String get robotPathSuccess;

  /// No description provided for @program.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get program;

  /// No description provided for @commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @turnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn Left'**
  String get turnLeft;

  /// No description provided for @turnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn Right'**
  String get turnRight;

  /// No description provided for @starLoaderGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo-Loader'**
  String get starLoaderGameTitle;

  /// No description provided for @starLoaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo-Loader'**
  String get starLoaderTitle;

  /// No description provided for @starLoaderGameDesc.
  ///
  /// In en, this message translates to:
  /// **'Push the crates onto the indicated targets.'**
  String get starLoaderGameDesc;

  /// No description provided for @starLoaderHint.
  ///
  /// In en, this message translates to:
  /// **'Use arrows or swipe to move. Get all crates to the targets!'**
  String get starLoaderHint;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get moves;

  /// No description provided for @optimal.
  ///
  /// In en, this message translates to:
  /// **'Optimal'**
  String get optimal;

  /// No description provided for @starLoaderWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo Loaded!'**
  String get starLoaderWinTitle;

  /// No description provided for @starLoaderWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed in {moves} moves, {time}s. Score: {score}'**
  String starLoaderWinDesc(int moves, int time, int score);

  /// No description provided for @efficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get efficiency;

  /// No description provided for @movesVsOptimal.
  ///
  /// In en, this message translates to:
  /// **'Moves / Optimal'**
  String get movesVsOptimal;

  /// No description provided for @imprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint / Legal'**
  String get imprint;

  /// No description provided for @imprintServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Service Provider'**
  String get imprintServiceProvider;

  /// No description provided for @imprintProviderAddress.
  ///
  /// In en, this message translates to:
  /// **'Christian Ströbele\nNikolausstr. 5\n70190 Stuttgart\nDeutschland/Germany'**
  String get imprintProviderAddress;

  /// No description provided for @imprintContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get imprintContact;

  /// No description provided for @imprintContactDetails.
  ///
  /// In en, this message translates to:
  /// **'Email: postmaster@crispstro.be\nPhone: 0049 176 6421 8601'**
  String get imprintContactDetails;

  /// No description provided for @imprintContentResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible for Content'**
  String get imprintContentResponsible;

  /// No description provided for @imprintDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get imprintDisclaimer;

  /// No description provided for @imprintDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This app is provided as is, exclusively for educational and creative purposes, without any liability.'**
  String get imprintDisclaimerText;

  /// No description provided for @imprintWebsite.
  ///
  /// In en, this message translates to:
  /// **'www.crispstro.be'**
  String get imprintWebsite;

  /// No description provided for @solarPanelGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Solar Panel Builder'**
  String get solarPanelGameTitle;

  /// No description provided for @solarPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Build Solar Arrays'**
  String get solarPanelTitle;

  /// No description provided for @solarPanelHint.
  ///
  /// In en, this message translates to:
  /// **'Height × Width = Panel Area. Add both panels for total power!'**
  String get solarPanelHint;

  /// No description provided for @solarPanelNumbers.
  ///
  /// In en, this message translates to:
  /// **'Available Numbers'**
  String get solarPanelNumbers;

  /// No description provided for @solarPanelDropFar.
  ///
  /// In en, this message translates to:
  /// **'Drop closer to an empty cell!'**
  String get solarPanelDropFar;

  /// No description provided for @solarPanelFail.
  ///
  /// In en, this message translates to:
  /// **'Not quite! Check your calculations.'**
  String get solarPanelFail;

  /// No description provided for @solarPanelWinTitle.
  ///
  /// In en, this message translates to:
  /// **'🌞 Station Powered!'**
  String get solarPanelWinTitle;

  /// No description provided for @solarPanelWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Amazing work! You earned {bonus} bonus watts!'**
  String solarPanelWinDesc(Object bonus);

  /// No description provided for @solarPanelNext.
  ///
  /// In en, this message translates to:
  /// **'Next Array'**
  String get solarPanelNext;

  /// No description provided for @starChartScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Star Chart Scan'**
  String get starChartScanTitle;

  /// No description provided for @starChartScanDesc.
  ///
  /// In en, this message translates to:
  /// **'Hidden equations are embedded in this star chart data! Scan horizontally, vertically, and diagonally to find math equations like 3+4=7 hidden in the number grid.'**
  String get starChartScanDesc;

  /// No description provided for @starChartScanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Swipe across cells to highlight hidden equations (e.g. 3+4=7, 9-2=7). Equations can run in any direction. Find all equations to decode the chart!'**
  String get starChartScanInstructions;

  /// No description provided for @starChartScanWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Chart Decoded!'**
  String get starChartScanWinTitle;

  /// No description provided for @starChartScanWinDesc.
  ///
  /// In en, this message translates to:
  /// **'All {letter} equations found! You earned {bonusScore} cartography points.'**
  String starChartScanWinDesc(String letter, int bonusScore);

  /// No description provided for @starChartScanLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Incomplete!'**
  String get starChartScanLoseTitle;

  /// No description provided for @starChartScanLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Some equations remain hidden in the data. Try scanning diagonally too, Commander.'**
  String get starChartScanLoseDesc;

  /// No description provided for @commRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Comm Relay'**
  String get commRelayTitle;

  /// No description provided for @commRelayDesc.
  ///
  /// In en, this message translates to:
  /// **'A garbled transmission from deep space! The communication relay has shifted every letter. Crack the cipher to read the original message!'**
  String get commRelayDesc;

  /// No description provided for @commRelayInstructions.
  ///
  /// In en, this message translates to:
  /// **'Each letter has been shifted by a fixed amount in the alphabet. Find the shift and decode the message.'**
  String get commRelayInstructions;

  /// No description provided for @commRelayWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Decoded!'**
  String get commRelayWinTitle;

  /// No description provided for @commRelayWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The transmission reads loud and clear! You earned {bonusScore} intelligence points.'**
  String commRelayWinDesc(int bonusScore);

  /// No description provided for @commRelayLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Static!'**
  String get commRelayLoseTitle;

  /// No description provided for @commRelayLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The message remains garbled. Try different shift values, Commander.'**
  String get commRelayLoseDesc;

  /// No description provided for @commRelayEncryptedSignal.
  ///
  /// In en, this message translates to:
  /// **'ENCRYPTED SIGNAL'**
  String get commRelayEncryptedSignal;

  /// No description provided for @commRelayDecoded.
  ///
  /// In en, this message translates to:
  /// **'DECODED'**
  String get commRelayDecoded;

  /// No description provided for @commRelayHintLetters.
  ///
  /// In en, this message translates to:
  /// **'HINT LETTERS'**
  String get commRelayHintLetters;

  /// No description provided for @commRelayShift.
  ///
  /// In en, this message translates to:
  /// **'SHIFT: {shift}'**
  String commRelayShift(String shift);

  /// No description provided for @commRelayDecodeBtn.
  ///
  /// In en, this message translates to:
  /// **'DECODE  ({attemptsLeft} left)'**
  String commRelayDecodeBtn(int attemptsLeft);

  /// No description provided for @commRelayTypeHint.
  ///
  /// In en, this message translates to:
  /// **'TYPE DECODED MESSAGE...'**
  String get commRelayTypeHint;

  /// No description provided for @commRelayDecode.
  ///
  /// In en, this message translates to:
  /// **'DECODE'**
  String get commRelayDecode;

  /// No description provided for @commRelayAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String commRelayAnswer(String answer);

  /// No description provided for @hullPlatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Hull Plating'**
  String get hullPlatingTitle;

  /// No description provided for @hullPlatingDesc.
  ///
  /// In en, this message translates to:
  /// **'The ship\'s hull took a hit! Cover the damaged section with armor plates of different shapes. Every gap must be sealed — rotate and place each plate precisely!'**
  String get hullPlatingDesc;

  /// No description provided for @hullPlatingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Drag armor plates from the tray onto the hull grid. Rotate plates with the button. Cover every cell with no overlaps!'**
  String get hullPlatingInstructions;

  /// No description provided for @hullPlatingWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Hull Sealed!'**
  String get hullPlatingWinTitle;

  /// No description provided for @hullPlatingWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The breach is patched! The ship is space-worthy again. You earned {bonusScore} repair credits.'**
  String hullPlatingWinDesc(int bonusScore);

  /// No description provided for @hullPlatingLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Breach Remains!'**
  String get hullPlatingLoseTitle;

  /// No description provided for @hullPlatingLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Gaps remain in the hull plating. Try a different arrangement, Commander.'**
  String get hullPlatingLoseDesc;

  /// No description provided for @vaultCrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault Cracker'**
  String get vaultCrackerTitle;

  /// No description provided for @vaultCrackerDesc.
  ///
  /// In en, this message translates to:
  /// **'An ancient alien vault blocks your path! Mathematical clues describe the secret code. Use logic and arithmetic to deduce the combination!'**
  String get vaultCrackerDesc;

  /// No description provided for @vaultCrackerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Read the mathematical clues carefully. Each describes a property of the secret code (sums, products, comparisons). Deduce all digits, then enter the code.'**
  String get vaultCrackerInstructions;

  /// No description provided for @vaultCrackerWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault Breached!'**
  String get vaultCrackerWinTitle;

  /// No description provided for @vaultCrackerWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The vault doors swing open! You cracked the code in {attempts} attempts, earning {bonusScore} archaeology points.'**
  String vaultCrackerWinDesc(int attempts, int bonusScore);

  /// No description provided for @vaultCrackerLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault Sealed!'**
  String get vaultCrackerLoseTitle;

  /// No description provided for @vaultCrackerLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts triggered the lockout. Analyze the clue patterns more carefully, Commander.'**
  String get vaultCrackerLoseDesc;

  /// No description provided for @crewManifestTitle.
  ///
  /// In en, this message translates to:
  /// **'Crew Manifest'**
  String get crewManifestTitle;

  /// No description provided for @crewManifestDesc.
  ///
  /// In en, this message translates to:
  /// **'The crew database is scrambled! Use the clues from the ship\'s log to match each crew member to their role, quarters, and home planet.'**
  String get crewManifestDesc;

  /// No description provided for @crewManifestInstructions.
  ///
  /// In en, this message translates to:
  /// **'Read the clues and mark the logic grid. An X means \'not possible\', a check means \'confirmed match\'.'**
  String get crewManifestInstructions;

  /// No description provided for @crewManifestWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Manifest Restored!'**
  String get crewManifestWinTitle;

  /// No description provided for @crewManifestWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Every crew member accounted for! Your detective work earned {bonusScore} intelligence points.'**
  String crewManifestWinDesc(int bonusScore);

  /// No description provided for @crewManifestLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Database Error!'**
  String get crewManifestLoseTitle;

  /// No description provided for @crewManifestLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The manifest contains contradictions. Re-read the clues carefully, Commander.'**
  String get crewManifestLoseDesc;

  /// No description provided for @crewManifestSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Manifest'**
  String get crewManifestSubmit;

  /// No description provided for @crewManifestHas1.
  ///
  /// In en, this message translates to:
  /// **'{crew} has the {item}.'**
  String crewManifestHas1(String crew, String item);

  /// No description provided for @crewManifestHas2.
  ///
  /// In en, this message translates to:
  /// **'The {item} belongs to {crew}.'**
  String crewManifestHas2(String crew, String item);

  /// No description provided for @crewManifestHas3.
  ///
  /// In en, this message translates to:
  /// **'{crew} was assigned the {item}.'**
  String crewManifestHas3(String crew, String item);

  /// No description provided for @crewManifestNot1.
  ///
  /// In en, this message translates to:
  /// **'{crew} does not have the {item}.'**
  String crewManifestNot1(String crew, String item);

  /// No description provided for @crewManifestNot2.
  ///
  /// In en, this message translates to:
  /// **'The {item} does not belong to {crew}.'**
  String crewManifestNot2(String crew, String item);

  /// No description provided for @alienTribunalTitle.
  ///
  /// In en, this message translates to:
  /// **'Alien Tribunal'**
  String get alienTribunalTitle;

  /// No description provided for @alienTribunalDesc.
  ///
  /// In en, this message translates to:
  /// **'Galactic delegates are testifying, but some always lie! Truth-tellers always speak truth, liars always lie. Study their statements and identify who is trustworthy!'**
  String get alienTribunalDesc;

  /// No description provided for @alienTribunalInstructions.
  ///
  /// In en, this message translates to:
  /// **'Read each delegate\'s statement. Mark each as \'Truth-Teller\' or \'Liar\'. All statements must be consistent with your assignments.'**
  String get alienTribunalInstructions;

  /// No description provided for @alienTribunalWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Justice Served!'**
  String get alienTribunalWinTitle;

  /// No description provided for @alienTribunalWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The tribunal\'s verdict is sound! Your deduction earned {bonusScore} diplomacy points.'**
  String alienTribunalWinDesc(int bonusScore);

  /// No description provided for @alienTribunalLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistrial!'**
  String get alienTribunalLoseTitle;

  /// No description provided for @alienTribunalLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Your assignments are contradictory. If someone is a truth-teller, their statements must be true, Commander.'**
  String get alienTribunalLoseDesc;

  /// No description provided for @alienTribunalSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Verdict'**
  String get alienTribunalSubmit;

  /// No description provided for @alienTribunalClaimTruth1.
  ///
  /// In en, this message translates to:
  /// **'\"{name} tells the truth.\"'**
  String alienTribunalClaimTruth1(String name);

  /// No description provided for @alienTribunalClaimTruth2.
  ///
  /// In en, this message translates to:
  /// **'\"{name} is trustworthy.\"'**
  String alienTribunalClaimTruth2(String name);

  /// No description provided for @alienTribunalClaimTruth3.
  ///
  /// In en, this message translates to:
  /// **'\"{name} is a truth-teller.\"'**
  String alienTribunalClaimTruth3(String name);

  /// No description provided for @alienTribunalClaimLiar1.
  ///
  /// In en, this message translates to:
  /// **'\"{name} is a liar.\"'**
  String alienTribunalClaimLiar1(String name);

  /// No description provided for @alienTribunalClaimLiar2.
  ///
  /// In en, this message translates to:
  /// **'\"{name} cannot be trusted.\"'**
  String alienTribunalClaimLiar2(String name);

  /// No description provided for @alienTribunalClaimLiar3.
  ///
  /// In en, this message translates to:
  /// **'\"{name} always lies.\"'**
  String alienTribunalClaimLiar3(String name);

  /// No description provided for @gravityWellTitle.
  ///
  /// In en, this message translates to:
  /// **'Gravity Well'**
  String get gravityWellTitle;

  /// No description provided for @gravityWellDesc.
  ///
  /// In en, this message translates to:
  /// **'Calibrate the gravity well! Place celestial masses on cosmic scales until perfect equilibrium is achieved. The warp drive won\'t engage without balanced gravity.'**
  String get gravityWellDesc;

  /// No description provided for @gravityWellInstructions.
  ///
  /// In en, this message translates to:
  /// **'Determine the weight of each object by reading the balanced scales. Drag your answer onto the target scale.'**
  String get gravityWellInstructions;

  /// No description provided for @gravityWellWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Gravity Calibrated!'**
  String get gravityWellWinTitle;

  /// No description provided for @gravityWellWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Perfect equilibrium achieved! The warp drive hums to life. You earned {bonusScore} calibration points.'**
  String gravityWellWinDesc(int bonusScore);

  /// No description provided for @gravityWellLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Gravitational Anomaly!'**
  String get gravityWellLoseTitle;

  /// No description provided for @gravityWellLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The imbalanced gravity well warped the local spacetime. Recalculate the masses, Commander.'**
  String get gravityWellLoseDesc;

  /// No description provided for @gravityWellKnown.
  ///
  /// In en, this message translates to:
  /// **'Known: {values}'**
  String gravityWellKnown(String values);

  /// No description provided for @gravityWellScaleN.
  ///
  /// In en, this message translates to:
  /// **'Scale {n}'**
  String gravityWellScaleN(int n);

  /// No description provided for @gravityWellEnterWeights.
  ///
  /// In en, this message translates to:
  /// **'Enter unknown weights:'**
  String get gravityWellEnterWeights;

  /// No description provided for @gravityWellCheckBalance.
  ///
  /// In en, this message translates to:
  /// **'Check Balance'**
  String get gravityWellCheckBalance;

  /// No description provided for @gravityWellKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get gravityWellKg;

  /// No description provided for @sectorPainterTitle.
  ///
  /// In en, this message translates to:
  /// **'Sector Painter'**
  String get sectorPainterTitle;

  /// No description provided for @sectorPainterDesc.
  ///
  /// In en, this message translates to:
  /// **'Assign communication frequencies to star map sectors! Bordering sectors must use different frequencies to avoid signal interference.'**
  String get sectorPainterDesc;

  /// No description provided for @sectorPainterInstructions.
  ///
  /// In en, this message translates to:
  /// **'Color each sector so no two adjacent sectors share the same color. Use as few colors as possible!'**
  String get sectorPainterInstructions;

  /// No description provided for @sectorPainterWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequencies Assigned!'**
  String get sectorPainterWinTitle;

  /// No description provided for @sectorPainterWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Zero interference across the star map! You solved it with only {colors} frequencies, earning {bonusScore} points.'**
  String sectorPainterWinDesc(int colors, int bonusScore);

  /// No description provided for @sectorPainterLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Signal Interference!'**
  String get sectorPainterLoseTitle;

  /// No description provided for @sectorPainterLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjacent sectors are broadcasting on the same frequency! Reassign the channels, Commander.'**
  String get sectorPainterLoseDesc;

  /// No description provided for @warpFoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Warp Fold'**
  String get warpFoldTitle;

  /// No description provided for @warpFoldDesc.
  ///
  /// In en, this message translates to:
  /// **'The warp drive folds space itself! Predict what the star chart looks like after space has been folded and cut. Spatial intuition is your only tool!'**
  String get warpFoldDesc;

  /// No description provided for @warpFoldInstructions.
  ///
  /// In en, this message translates to:
  /// **'Watch the folding animation, then choose which unfolded result is correct.'**
  String get warpFoldInstructions;

  /// No description provided for @warpFoldWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Space Unfolded!'**
  String get warpFoldWinTitle;

  /// No description provided for @warpFoldWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Your spatial reasoning is flawless! You earned {bonusScore} dimensional points.'**
  String warpFoldWinDesc(int bonusScore);

  /// No description provided for @warpFoldLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Dimensional Mishap!'**
  String get warpFoldLoseTitle;

  /// No description provided for @warpFoldLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The unfolded space didn\'t match your prediction. Trace the folds step by step, Commander.'**
  String get warpFoldLoseDesc;

  /// No description provided for @cubeScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cube Scanner'**
  String get cubeScannerTitle;

  /// No description provided for @cubeScannerDesc.
  ///
  /// In en, this message translates to:
  /// **'Alien data cubes have been recovered! Your scanner reveals some faces, but others are hidden. Use the rule -- opposite faces always sum to 7 -- to deduce the hidden values.'**
  String get cubeScannerDesc;

  /// No description provided for @cubeScannerInstructions.
  ///
  /// In en, this message translates to:
  /// **'Study the visible faces of each cube. Opposite faces sum to 7. Determine the hidden face values.'**
  String get cubeScannerInstructions;

  /// No description provided for @cubeScannerWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Cubes Decoded!'**
  String get cubeScannerWinTitle;

  /// No description provided for @cubeScannerWinDesc.
  ///
  /// In en, this message translates to:
  /// **'All cube data extracted! Your analysis earned {bonusScore} scanner points.'**
  String cubeScannerWinDesc(int bonusScore);

  /// No description provided for @cubeScannerLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Incomplete!'**
  String get cubeScannerLoseTitle;

  /// No description provided for @cubeScannerLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Some face values are wrong. Remember: opposite faces always sum to 7, Commander.'**
  String get cubeScannerLoseDesc;

  /// No description provided for @circuitRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Circuit Repair'**
  String get circuitRepairTitle;

  /// No description provided for @circuitRepairDesc.
  ///
  /// In en, this message translates to:
  /// **'The cockpit clock is glitching! Two digit positions got swapped, showing an impossible time. Find the two positions to swap back and restore the correct readout!'**
  String get circuitRepairDesc;

  /// No description provided for @circuitRepairInstructions.
  ///
  /// In en, this message translates to:
  /// **'The clock shows an invalid time because two digit positions are swapped. Tap two digits to swap them. The result must be a valid time!'**
  String get circuitRepairInstructions;

  /// No description provided for @circuitRepairWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Fixed!'**
  String get circuitRepairWinTitle;

  /// No description provided for @circuitRepairWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear readout restored! Your electrical skills earned {bonusScore} tech points.'**
  String circuitRepairWinDesc(int bonusScore);

  /// No description provided for @circuitRepairLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Still Glitching!'**
  String get circuitRepairLoseTitle;

  /// No description provided for @circuitRepairLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The display is still showing wrong digits. Think about which two segments, when swapped, make all digits valid, Commander.'**
  String get circuitRepairLoseDesc;

  /// No description provided for @darkMatterGridTitle.
  ///
  /// In en, this message translates to:
  /// **'Dark Matter Grid'**
  String get darkMatterGridTitle;

  /// No description provided for @darkMatterGridDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark matter has blanketed this sector! Toggle the nodes to push back the darkness. But beware -- each node affects its neighbors!'**
  String get darkMatterGridDesc;

  /// No description provided for @darkMatterGridInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap a node to toggle it and all adjacent nodes. Light up the entire grid to clear the sector.'**
  String get darkMatterGridInstructions;

  /// No description provided for @darkMatterGridWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Sector Illuminated!'**
  String get darkMatterGridWinTitle;

  /// No description provided for @darkMatterGridWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The dark matter recedes! You cleared the grid in {moves} moves and earned {bonusScore} photon points.'**
  String darkMatterGridWinDesc(int moves, int bonusScore);

  /// No description provided for @darkMatterGridLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Darkness Persists!'**
  String get darkMatterGridLoseTitle;

  /// No description provided for @darkMatterGridLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The dark matter grid remains unstable. Think about which nodes affect which neighbors, Commander.'**
  String get darkMatterGridLoseDesc;

  /// No description provided for @dockClearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Dock Clearance'**
  String get dockClearanceTitle;

  /// No description provided for @dockClearanceDesc.
  ///
  /// In en, this message translates to:
  /// **'The space dock is jammed! Slide the parked ships to clear a path for your vessel to reach the launch tube. No diagonal moves -- ships only slide along their axis!'**
  String get dockClearanceDesc;

  /// No description provided for @dockClearanceInstructions.
  ///
  /// In en, this message translates to:
  /// **'Slide ships horizontally or vertically to create a clear path. Get the red ship to the exit!'**
  String get dockClearanceInstructions;

  /// No description provided for @dockClearanceWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch Clear!'**
  String get dockClearanceWinTitle;

  /// No description provided for @dockClearanceWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Your ship rockets out of the dock! Cleared in {moves} moves, earning {bonusScore} docking credits.'**
  String dockClearanceWinDesc(int moves, int bonusScore);

  /// No description provided for @dockClearanceLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Still Jammed!'**
  String get dockClearanceLoseTitle;

  /// No description provided for @dockClearanceLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'No clear path to the exit. Try sliding different ships first, Commander.'**
  String get dockClearanceLoseDesc;

  /// No description provided for @ionChainTitle.
  ///
  /// In en, this message translates to:
  /// **'Ion Ring'**
  String get ionChainTitle;

  /// No description provided for @ionChainDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete the ion ring! Arrange charged particles around the plasma loop so every neighbor pair obeys the constraint rules. One wrong placement and the ring destabilizes!'**
  String get ionChainDesc;

  /// No description provided for @ionChainInstructions.
  ///
  /// In en, this message translates to:
  /// **'Drag ions onto the ring. Read the rules carefully — some shapes cannot be neighbors. The ring is circular: the last bead is adjacent to the first!'**
  String get ionChainInstructions;

  /// No description provided for @ionChainWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Ring Stabilized!'**
  String get ionChainWinTitle;

  /// No description provided for @ionChainWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The plasma flows in a perfect loop! You earned {bonusScore} chemistry points.'**
  String ionChainWinDesc(int bonusScore);

  /// No description provided for @ionChainLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Chain Reaction!'**
  String get ionChainLoseTitle;

  /// No description provided for @ionChainLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Incompatible ions caused a plasma surge! Check the adjacency rules, Commander.'**
  String get ionChainLoseDesc;

  /// No description provided for @launchSequenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch Sequence'**
  String get launchSequenceTitle;

  /// No description provided for @launchSequenceDesc.
  ///
  /// In en, this message translates to:
  /// **'The launch queue is scrambled! Reorder the fleet by swapping adjacent ships. Get them in the correct sequence using the fewest swaps possible!'**
  String get launchSequenceDesc;

  /// No description provided for @launchSequenceInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap two adjacent ships to swap them. Arrange all ships in the correct order. Fewer swaps = more points!'**
  String get launchSequenceInstructions;

  /// No description provided for @launchSequenceWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Fleet Launched!'**
  String get launchSequenceWinTitle;

  /// No description provided for @launchSequenceWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Perfect sequence! You sorted the fleet in {moves} swaps (optimal: {optimal}), earning {bonusScore} efficiency points.'**
  String launchSequenceWinDesc(int moves, int optimal, int bonusScore);

  /// No description provided for @launchSequenceLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Sequence Error!'**
  String get launchSequenceLoseTitle;

  /// No description provided for @launchSequenceLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The fleet is still out of order. Keep swapping adjacent ships, Commander.'**
  String get launchSequenceLoseDesc;

  /// No description provided for @starForgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Star Forge'**
  String get starForgeTitle;

  /// No description provided for @starForgeDesc.
  ///
  /// In en, this message translates to:
  /// **'Ignite a new star! Distribute energy values across the forge nodes so every plasma arm carries the same total charge. The star ignites when all arms align!'**
  String get starForgeDesc;

  /// No description provided for @starForgeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place numbers in the empty nodes. Each line through the star must have the same sum.'**
  String get starForgeInstructions;

  /// No description provided for @starForgeWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Star Ignited!'**
  String get starForgeWinTitle;

  /// No description provided for @starForgeWinDesc.
  ///
  /// In en, this message translates to:
  /// **'A brilliant new star blazes to life! Your forge mastery earned {bonusScore} fusion points.'**
  String starForgeWinDesc(int bonusScore);

  /// No description provided for @starForgeLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Forge Misfire!'**
  String get starForgeLoseTitle;

  /// No description provided for @starForgeLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The energy imbalance caused a plasma leak. Redistribute the charge and try again, Commander.'**
  String get starForgeLoseDesc;

  /// No description provided for @starForgeOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get starForgeOutOfMoves;

  /// No description provided for @starForgeOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many node placements! Plan your energy distribution carefully to ignite the star.'**
  String get starForgeOutOfMovesDesc;

  /// No description provided for @nebulaMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Nebula Matrix'**
  String get nebulaMatrixTitle;

  /// No description provided for @nebulaMatrixDesc.
  ///
  /// In en, this message translates to:
  /// **'Stabilize the energy field! Fill every row, column, and zone of the nebula grid so no frequency repeats. One wrong resonance and the nebula collapses!'**
  String get nebulaMatrixDesc;

  /// No description provided for @nebulaMatrixInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place numbers so each row and column contains every value exactly once.'**
  String get nebulaMatrixInstructions;

  /// No description provided for @nebulaMatrixInstructionsZones.
  ///
  /// In en, this message translates to:
  /// **'Place numbers so each row and column contains every value exactly once. Colored zones must also contain each value once.'**
  String get nebulaMatrixInstructionsZones;

  /// No description provided for @nebulaMatrixWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Nebula Stabilized!'**
  String get nebulaMatrixWinTitle;

  /// No description provided for @nebulaMatrixWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The energy field is perfectly balanced! You earned {bonusScore} resonance points for your precision.'**
  String nebulaMatrixWinDesc(int bonusScore);

  /// No description provided for @nebulaMatrixLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Field Collapse!'**
  String get nebulaMatrixLoseTitle;

  /// No description provided for @nebulaMatrixLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Conflicting frequencies destabilized the nebula. Recalibrate your matrix and try again, Commander.'**
  String get nebulaMatrixLoseDesc;

  /// No description provided for @nebulaMatrixOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get nebulaMatrixOutOfMoves;

  /// No description provided for @nebulaMatrixOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many placements! Place each frequency carefully to stabilize the nebula.'**
  String get nebulaMatrixOutOfMovesDesc;

  /// No description provided for @orbitalTowersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orbital Towers'**
  String get orbitalTowersTitle;

  /// No description provided for @orbitalTowersDesc.
  ///
  /// In en, this message translates to:
  /// **'Build a space city on the orbital platform! The satellite cameras on each edge report how many towers they can see. Taller towers hide shorter ones behind them.'**
  String get orbitalTowersDesc;

  /// No description provided for @orbitalTowersInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place towers of height 1 to {size} so each row and column has every height once. Edge clues show how many towers are visible from that direction.'**
  String orbitalTowersInstructions(int size);

  /// No description provided for @orbitalTowersWinTitle.
  ///
  /// In en, this message translates to:
  /// **'City Constructed!'**
  String get orbitalTowersWinTitle;

  /// No description provided for @orbitalTowersWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The orbital city rises into view! All satellite readings match perfectly. You earned {bonusScore} construction credits.'**
  String orbitalTowersWinDesc(int bonusScore);

  /// No description provided for @orbitalTowersLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Blueprint Mismatch!'**
  String get orbitalTowersLoseTitle;

  /// No description provided for @orbitalTowersLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The satellite cameras don\'t match your layout. Remember: tall towers block the view of shorter ones behind them, Commander.'**
  String get orbitalTowersLoseDesc;

  /// No description provided for @orbitalTowersOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of Moves!'**
  String get orbitalTowersOutOfMoves;

  /// No description provided for @orbitalTowersOutOfMovesDesc.
  ///
  /// In en, this message translates to:
  /// **'Too many tower placements! Study the edge clues carefully before placing each tower.'**
  String get orbitalTowersOutOfMovesDesc;

  /// No description provided for @hiveStationTitle.
  ///
  /// In en, this message translates to:
  /// **'Hive Station'**
  String get hiveStationTitle;

  /// No description provided for @hiveStationDesc.
  ///
  /// In en, this message translates to:
  /// **'The station\'s energy hive needs charging! Each cell displays how many of its neighbors hold an energy core. Deduce which cells need power!'**
  String get hiveStationDesc;

  /// No description provided for @hiveStationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap hexagonal cells to fill them with energy. The number in each cell tells you how many adjacent cells contain energy.'**
  String get hiveStationInstructions;

  /// No description provided for @hiveStationWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Hive Charged!'**
  String get hiveStationWinTitle;

  /// No description provided for @hiveStationWinDesc.
  ///
  /// In en, this message translates to:
  /// **'All energy cores placed correctly! The station hums with power. You earned {bonusScore} charge points.'**
  String hiveStationWinDesc(int bonusScore);

  /// No description provided for @hiveStationLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Power Mismatch!'**
  String get hiveStationLoseTitle;

  /// No description provided for @hiveStationLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Some cells report the wrong neighbor count. Check your energy placement, Commander.'**
  String get hiveStationLoseDesc;

  /// No description provided for @hiveStationWrongAttempt.
  ///
  /// In en, this message translates to:
  /// **'Not quite right! {remaining} attempts left.'**
  String hiveStationWrongAttempt(int remaining);

  /// No description provided for @relicAssemblyTitle.
  ///
  /// In en, this message translates to:
  /// **'Relic Assembly'**
  String get relicAssemblyTitle;

  /// No description provided for @relicAssemblyDesc.
  ///
  /// In en, this message translates to:
  /// **'Ancient alien tablet fragments have been excavated! Arrange the pieces so the glyphs on touching edges match perfectly. The artifact holds the key to the next star system!'**
  String get relicAssemblyDesc;

  /// No description provided for @relicAssemblyInstructions.
  ///
  /// In en, this message translates to:
  /// **'Place and rotate tablet pieces in the grid. Touching edges must show matching glyphs.'**
  String get relicAssemblyInstructions;

  /// No description provided for @relicAssemblyWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifact Restored!'**
  String get relicAssemblyWinTitle;

  /// No description provided for @relicAssemblyWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The ancient tablet glows with power! Your archaeology earned {bonusScore} discovery points.'**
  String relicAssemblyWinDesc(int bonusScore);

  /// No description provided for @relicAssemblyLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Fragments Misaligned!'**
  String get relicAssemblyLoseTitle;

  /// No description provided for @relicAssemblyLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Some edge glyphs don\'t match their neighbors. Try rotating or repositioning the pieces, Commander.'**
  String get relicAssemblyLoseDesc;

  /// No description provided for @xenobiologyLabTitle.
  ///
  /// In en, this message translates to:
  /// **'Xenobiology Lab'**
  String get xenobiologyLabTitle;

  /// No description provided for @xenobiologyLabDesc.
  ///
  /// In en, this message translates to:
  /// **'A new species has been discovered! Each subspecies has different numbers of eyes, tentacles, and legs. Use the census data to classify the colony!'**
  String get xenobiologyLabDesc;

  /// No description provided for @xenobiologyLabInstructions.
  ///
  /// In en, this message translates to:
  /// **'Two alien types live together. You know each type\'s traits and the total eyes and legs observed. Calculate how many of each type there must be, then submit!'**
  String get xenobiologyLabInstructions;

  /// No description provided for @xenobiologyLabWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Species Cataloged!'**
  String get xenobiologyLabWinTitle;

  /// No description provided for @xenobiologyLabWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Field report filed! Your xenobiology skills earned {bonusScore} research credits.'**
  String xenobiologyLabWinDesc(int bonusScore);

  /// No description provided for @xenobiologyLabLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Census Error!'**
  String get xenobiologyLabLoseTitle;

  /// No description provided for @xenobiologyLabLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The numbers don\'t add up. Double-check the trait counts for each subspecies, Commander.'**
  String get xenobiologyLabLoseDesc;

  /// No description provided for @galacticMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Galactic Market'**
  String get galacticMarketTitle;

  /// No description provided for @galacticMarketDesc.
  ///
  /// In en, this message translates to:
  /// **'The alien shopkeeper gave you change, but some coins landed face-down! You know the total and can see some coins. Deduce the hidden denomination!'**
  String get galacticMarketDesc;

  /// No description provided for @galacticMarketInstructions.
  ///
  /// In en, this message translates to:
  /// **'Look at the total change and the visible coins. The face-down coins all have the same value. Calculate: (total - known coins) / number of hidden coins = ?'**
  String get galacticMarketInstructions;

  /// No description provided for @galacticMarketWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Complete!'**
  String get galacticMarketWinTitle;

  /// No description provided for @galacticMarketWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Exact change tendered! You used only {coins} coins, earning {bonusScore} trade points.'**
  String galacticMarketWinDesc(int coins, int bonusScore);

  /// No description provided for @galacticMarketLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Amount!'**
  String get galacticMarketLoseTitle;

  /// No description provided for @galacticMarketLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The merchant frowns -- that\'s not the right amount. Try a different combination of coins, Commander.'**
  String get galacticMarketLoseDesc;

  /// No description provided for @creatureForgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Creature Forge'**
  String get creatureForgeTitle;

  /// No description provided for @creatureForgeDesc.
  ///
  /// In en, this message translates to:
  /// **'The xenobiology bay has parts from multiple alien species! Tap to select heads, bodies, and tails, then build creatures. How many unique beings can you create?'**
  String get creatureForgeDesc;

  /// No description provided for @creatureForgeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Select one part from each row, then tap BUILD to add the creature to your gallery. Find all valid combinations, then enter the total count!'**
  String get creatureForgeInstructions;

  /// No description provided for @creatureForgeWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Species Catalog Complete!'**
  String get creatureForgeWinTitle;

  /// No description provided for @creatureForgeWinDesc.
  ///
  /// In en, this message translates to:
  /// **'You discovered all {count} possible creatures! Your curiosity earned {bonusScore} biology points.'**
  String creatureForgeWinDesc(int count, int bonusScore);

  /// No description provided for @creatureForgeLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing Species!'**
  String get creatureForgeLoseTitle;

  /// No description provided for @creatureForgeLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t found all the combinations yet. Remember: each head can pair with each body AND each tail, Commander.'**
  String get creatureForgeLoseDesc;

  /// No description provided for @asteroidDuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Duel'**
  String get asteroidDuelTitle;

  /// No description provided for @asteroidDuelDesc.
  ///
  /// In en, this message translates to:
  /// **'A strategic standoff in the asteroid belt! Take turns mining rocks with your opponent. The commander who takes the last asteroid loses. Think ahead!'**
  String get asteroidDuelDesc;

  /// No description provided for @asteroidDuelInstructions.
  ///
  /// In en, this message translates to:
  /// **'Choose 1 to {max} asteroids per turn. Force your opponent to take the last one!'**
  String asteroidDuelInstructions(int max);

  /// No description provided for @asteroidDuelWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Duel Won!'**
  String get asteroidDuelWinTitle;

  /// No description provided for @asteroidDuelWinDesc.
  ///
  /// In en, this message translates to:
  /// **'Superior strategy! Your opponent is stranded. You earned {bonusScore} tactical points.'**
  String asteroidDuelWinDesc(int bonusScore);

  /// No description provided for @asteroidDuelLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Outmaneuvered!'**
  String get asteroidDuelLoseTitle;

  /// No description provided for @asteroidDuelLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Your opponent forced you into the last asteroid. Study the patterns -- there\'s always a winning strategy, Commander.'**
  String get asteroidDuelLoseDesc;

  /// No description provided for @chronoRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Chrono Repair'**
  String get chronoRepairTitle;

  /// No description provided for @chronoRepairDesc.
  ///
  /// In en, this message translates to:
  /// **'Relativistic effects have scrambled the station clocks! Some run fast, some are mirrored, some have broken segments. Deduce the real time!'**
  String get chronoRepairDesc;

  /// No description provided for @chronoRepairInstructions.
  ///
  /// In en, this message translates to:
  /// **'Each clock has a specific malfunction (offset, mirror, broken segments). Figure out the correct time.'**
  String get chronoRepairInstructions;

  /// No description provided for @chronoRepairWinTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Synchronized!'**
  String get chronoRepairWinTitle;

  /// No description provided for @chronoRepairWinDesc.
  ///
  /// In en, this message translates to:
  /// **'All clocks show the correct time! You earned {bonusScore} temporal points.'**
  String chronoRepairWinDesc(int bonusScore);

  /// No description provided for @chronoRepairLoseTitle.
  ///
  /// In en, this message translates to:
  /// **'Still Out of Sync!'**
  String get chronoRepairLoseTitle;

  /// No description provided for @chronoRepairLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'The displayed time is incorrect. Consider the specific malfunction of each clock, Commander.'**
  String get chronoRepairLoseDesc;

  /// No description provided for @gridlockPlayerShip.
  ///
  /// In en, this message translates to:
  /// **'Player ship'**
  String get gridlockPlayerShip;

  /// No description provided for @gridlockBlockingShip.
  ///
  /// In en, this message translates to:
  /// **'Blocking ship'**
  String get gridlockBlockingShip;

  /// No description provided for @gridlockShip.
  ///
  /// In en, this message translates to:
  /// **'Ship'**
  String get gridlockShip;

  /// No description provided for @gridlockDragHorizontally.
  ///
  /// In en, this message translates to:
  /// **'Drag horizontally to move'**
  String get gridlockDragHorizontally;

  /// No description provided for @gridlockDragVertically.
  ///
  /// In en, this message translates to:
  /// **'Drag vertically to move'**
  String get gridlockDragVertically;

  /// No description provided for @gridlockMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get gridlockMoves;

  /// No description provided for @gridlockTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get gridlockTarget;

  /// No description provided for @gridlockShips.
  ///
  /// In en, this message translates to:
  /// **'Ships'**
  String get gridlockShips;

  /// No description provided for @gridlockResetPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Reset Puzzle'**
  String get gridlockResetPuzzle;

  /// No description provided for @gridlockDragToExit.
  ///
  /// In en, this message translates to:
  /// **'Drag the green ship to the exit'**
  String get gridlockDragToExit;

  /// No description provided for @gridlockInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get gridlockInitializing;

  /// No description provided for @gridlockCalculatingDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Calculating difficulty...'**
  String get gridlockCalculatingDifficulty;

  /// No description provided for @gridlockSearchingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Searching puzzle database...'**
  String get gridlockSearchingDatabase;

  /// No description provided for @gridlockSelectingPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Selecting puzzle...'**
  String get gridlockSelectingPuzzle;

  /// No description provided for @gridlockLoadingConfig.
  ///
  /// In en, this message translates to:
  /// **'Loading puzzle configuration...'**
  String get gridlockLoadingConfig;

  /// No description provided for @gridlockGeneratingPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Generating custom puzzle...'**
  String get gridlockGeneratingPuzzle;

  /// No description provided for @gridlockReady.
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get gridlockReady;

  /// No description provided for @gridlockError.
  ///
  /// In en, this message translates to:
  /// **'Error! Using fallback...'**
  String get gridlockError;

  /// No description provided for @gridlockComplexity.
  ///
  /// In en, this message translates to:
  /// **'Complexity: {value}'**
  String gridlockComplexity(String value);

  /// No description provided for @puzzleGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Puzzle Generation Failed'**
  String get puzzleGenerationFailed;

  /// No description provided for @puzzleGenerationFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'Unable to generate puzzle. Please try again.'**
  String get puzzleGenerationFailedDesc;

  /// No description provided for @puzzleGenerationFailedDescAlt.
  ///
  /// In en, this message translates to:
  /// **'Unable to generate a puzzle. Would you like to try again or return to the main menu?'**
  String get puzzleGenerationFailedDescAlt;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// No description provided for @creatureForgeAlreadyDiscovered.
  ///
  /// In en, this message translates to:
  /// **'Already discovered this creature!'**
  String get creatureForgeAlreadyDiscovered;

  /// No description provided for @creatureForgeInvalidCombo.
  ///
  /// In en, this message translates to:
  /// **'Invalid combination! {constraint}'**
  String creatureForgeInvalidCombo(String constraint);

  /// No description provided for @creatureForgeNotQuiteAnswer.
  ///
  /// In en, this message translates to:
  /// **'Not quite! You said {answer}, try again.'**
  String creatureForgeNotQuiteAnswer(int answer);

  /// No description provided for @creatureForgeTotalPossible.
  ///
  /// In en, this message translates to:
  /// **'Total possible: '**
  String get creatureForgeTotalPossible;

  /// No description provided for @creatureForgeSubmit.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT'**
  String get creatureForgeSubmit;

  /// No description provided for @creatureForgeFoundSpecies.
  ///
  /// In en, this message translates to:
  /// **'You found {count} species!\nCorrect total: {total}'**
  String creatureForgeFoundSpecies(int count, int total);

  /// No description provided for @creatureForgeConstraintWingedSpiked.
  ///
  /// In en, this message translates to:
  /// **'Winged bodies cannot pair with spiked tails'**
  String get creatureForgeConstraintWingedSpiked;

  /// No description provided for @creatureForgeConstraintAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Winged bodies need crystal heads\nAquatic bodies reject flame tails'**
  String get creatureForgeConstraintAdvanced;

  /// No description provided for @bubbleNextTarget.
  ///
  /// In en, this message translates to:
  /// **'Next target: '**
  String get bubbleNextTarget;

  /// No description provided for @bubbleAllTargetsPopped.
  ///
  /// In en, this message translates to:
  /// **'All targets popped'**
  String get bubbleAllTargetsPopped;

  /// No description provided for @bubbleTimeBonusPoints.
  ///
  /// In en, this message translates to:
  /// **'Time Bonus: {points} points!'**
  String bubbleTimeBonusPoints(int points);

  /// No description provided for @xenoCensusReport.
  ///
  /// In en, this message translates to:
  /// **'Census Report'**
  String get xenoCensusReport;

  /// No description provided for @xenoEyes.
  ///
  /// In en, this message translates to:
  /// **'Eyes'**
  String get xenoEyes;

  /// No description provided for @xenoLegs.
  ///
  /// In en, this message translates to:
  /// **'Legs'**
  String get xenoLegs;

  /// No description provided for @xenoCreatures.
  ///
  /// In en, this message translates to:
  /// **'Creatures'**
  String get xenoCreatures;

  /// No description provided for @xenoTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: '**
  String get xenoTarget;

  /// No description provided for @xenoYours.
  ///
  /// In en, this message translates to:
  /// **'Yours: '**
  String get xenoYours;

  /// No description provided for @sectorMinColors.
  ///
  /// In en, this message translates to:
  /// **'Min colors: {count}'**
  String sectorMinColors(int count);

  /// No description provided for @sectorPainted.
  ///
  /// In en, this message translates to:
  /// **'Painted: {done}/{total}'**
  String sectorPainted(int done, int total);

  /// No description provided for @sectorColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get sectorColors;

  /// No description provided for @sectorOptimalColoring.
  ///
  /// In en, this message translates to:
  /// **'Optimal coloring!'**
  String get sectorOptimalColoring;

  /// No description provided for @warpFoldStep.
  ///
  /// In en, this message translates to:
  /// **'Fold {step}: {direction}'**
  String warpFoldStep(int step, String direction);

  /// No description provided for @warpCutHoles.
  ///
  /// In en, this message translates to:
  /// **'Cut {count} hole(s)...'**
  String warpCutHoles(int count);

  /// No description provided for @warpWhichPattern.
  ///
  /// In en, this message translates to:
  /// **'Which pattern appears when unfolded?'**
  String get warpWhichPattern;

  /// No description provided for @warpFoldsAndCuts.
  ///
  /// In en, this message translates to:
  /// **'Folds: {folds}  |  Cuts: {cuts}'**
  String warpFoldsAndCuts(String folds, int cuts);

  /// No description provided for @warpDirLeft.
  ///
  /// In en, this message translates to:
  /// **'← Left'**
  String get warpDirLeft;

  /// No description provided for @warpDirRight.
  ///
  /// In en, this message translates to:
  /// **'→ Right'**
  String get warpDirRight;

  /// No description provided for @warpDirUp.
  ///
  /// In en, this message translates to:
  /// **'↑ Up'**
  String get warpDirUp;

  /// No description provided for @warpDirDown.
  ///
  /// In en, this message translates to:
  /// **'↓ Down'**
  String get warpDirDown;

  /// No description provided for @circuitInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Not a valid time! {remaining} attempts left.'**
  String circuitInvalidTime(int remaining);

  /// No description provided for @circuitSwapInstruction.
  ///
  /// In en, this message translates to:
  /// **'Two digits on this clock swapped places! Tap two digit positions to swap them back.'**
  String get circuitSwapInstruction;

  /// No description provided for @circuitAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts: {remaining} / {total}'**
  String circuitAttempts(int remaining, int total);

  /// No description provided for @circuitPositionSelected.
  ///
  /// In en, this message translates to:
  /// **'Position {pos} selected -- tap another digit'**
  String circuitPositionSelected(int pos);

  /// No description provided for @circuitSwapPositions.
  ///
  /// In en, this message translates to:
  /// **'Swap: position {pos1} <-> position {pos2}'**
  String circuitSwapPositions(int pos1, int pos2);

  /// No description provided for @circuitResultValid.
  ///
  /// In en, this message translates to:
  /// **'Result: {time} (valid!)'**
  String circuitResultValid(String time);

  /// No description provided for @circuitResultInvalid.
  ///
  /// In en, this message translates to:
  /// **'Result: {time} (invalid)'**
  String circuitResultInvalid(String time);

  /// No description provided for @circuitTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap a digit on the clock to start'**
  String get circuitTapToStart;

  /// No description provided for @circuitClockNowReads.
  ///
  /// In en, this message translates to:
  /// **'The clock now reads {time}'**
  String circuitClockNowReads(String time);

  /// No description provided for @circuitCorrectTimeWas.
  ///
  /// In en, this message translates to:
  /// **'The correct time was {time}'**
  String circuitCorrectTimeWas(String time);

  /// No description provided for @chronoClockRunsFast.
  ///
  /// In en, this message translates to:
  /// **'This clock runs {hours} hours fast'**
  String chronoClockRunsFast(int hours);

  /// No description provided for @chronoClockMirrored.
  ///
  /// In en, this message translates to:
  /// **'This clock is horizontally mirrored'**
  String get chronoClockMirrored;

  /// No description provided for @chronoClockRunsFastCombined.
  ///
  /// In en, this message translates to:
  /// **'This clock runs {hours} h {minutes} min fast'**
  String chronoClockRunsFastCombined(int hours, int minutes);

  /// No description provided for @chronoWhatIsCorrectTime.
  ///
  /// In en, this message translates to:
  /// **'What is the correct time?'**
  String get chronoWhatIsCorrectTime;

  /// No description provided for @asteroidDuelMine.
  ///
  /// In en, this message translates to:
  /// **'Mine {count}!'**
  String asteroidDuelMine(int count);

  /// No description provided for @asteroidDuelTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap asteroids to select (1-{max})'**
  String asteroidDuelTapToSelect(int max);

  /// No description provided for @asteroidDuelHint.
  ///
  /// In en, this message translates to:
  /// **'Hint: Try to leave {safe}+1 = {safeP1} asteroids for the AI. The key pattern is multiples of {safe}, plus 1.'**
  String asteroidDuelHint(int safe, int safeP1);

  /// No description provided for @crewManifestClues.
  ///
  /// In en, this message translates to:
  /// **'Clues:'**
  String get crewManifestClues;

  /// No description provided for @crewManifestMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get crewManifestMatch;

  /// No description provided for @crewManifestEliminate.
  ///
  /// In en, this message translates to:
  /// **'Eliminate'**
  String get crewManifestEliminate;

  /// No description provided for @alienTribunalTruth.
  ///
  /// In en, this message translates to:
  /// **'Truth'**
  String get alienTribunalTruth;

  /// No description provided for @alienTribunalLiar.
  ///
  /// In en, this message translates to:
  /// **'Liar'**
  String get alienTribunalLiar;

  /// No description provided for @puzzleAllPiecesPlaced.
  ///
  /// In en, this message translates to:
  /// **'All pieces placed!'**
  String get puzzleAllPiecesPlaced;

  /// No description provided for @signalNoAttemptsYet.
  ///
  /// In en, this message translates to:
  /// **'No attempts yet'**
  String get signalNoAttemptsYet;

  /// No description provided for @perspectiveDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag ±15°'**
  String get perspectiveDragHint;

  /// No description provided for @allTargetsPopped.
  ///
  /// In en, this message translates to:
  /// **'All targets popped'**
  String get allTargetsPopped;

  /// No description provided for @creatureForgeForbidden.
  ///
  /// In en, this message translates to:
  /// **'FORBIDDEN'**
  String get creatureForgeForbidden;

  /// No description provided for @creatureForgeAlreadyFound.
  ///
  /// In en, this message translates to:
  /// **'ALREADY FOUND'**
  String get creatureForgeAlreadyFound;

  /// No description provided for @creatureForgeNewSpecies.
  ///
  /// In en, this message translates to:
  /// **'NEW SPECIES!'**
  String get creatureForgeNewSpecies;

  /// No description provided for @creatureForgeAdd.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get creatureForgeAdd;

  /// No description provided for @ionChainRules.
  ///
  /// In en, this message translates to:
  /// **'RULES'**
  String get ionChainRules;

  /// No description provided for @ionChainRing.
  ///
  /// In en, this message translates to:
  /// **'ION RING'**
  String get ionChainRing;

  /// No description provided for @ionChainAvailableBeads.
  ///
  /// In en, this message translates to:
  /// **'AVAILABLE BEADS'**
  String get ionChainAvailableBeads;

  /// No description provided for @ionChainRuleViolation.
  ///
  /// In en, this message translates to:
  /// **'Rule violation! This bead can\'t go here.'**
  String get ionChainRuleViolation;

  /// No description provided for @hullPlatingNoFit.
  ///
  /// In en, this message translates to:
  /// **'Piece doesn\'t fit here! Try rotating or a different position.'**
  String get hullPlatingNoFit;

  /// No description provided for @hullPlatingAllPlaced.
  ///
  /// In en, this message translates to:
  /// **'All pieces placed!'**
  String get hullPlatingAllPlaced;

  /// No description provided for @hullPlatingClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get hullPlatingClear;

  /// No description provided for @gridFillerPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get gridFillerPlayAgain;

  /// No description provided for @gridFillerExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get gridFillerExit;

  /// No description provided for @gridFillerResetGrid.
  ///
  /// In en, this message translates to:
  /// **'Reset Grid'**
  String get gridFillerResetGrid;

  /// No description provided for @chronoRepairSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get chronoRepairSubmit;

  /// No description provided for @xenobiologySubmitCensus.
  ///
  /// In en, this message translates to:
  /// **'Submit Census'**
  String get xenobiologySubmitCensus;

  /// No description provided for @galacticMarketOneCoin.
  ///
  /// In en, this message translates to:
  /// **'One coin is face-down.'**
  String get galacticMarketOneCoin;

  /// No description provided for @galacticMarketNCoins.
  ///
  /// In en, this message translates to:
  /// **'The {count} face-down coins all have the same value.'**
  String galacticMarketNCoins(int count);

  /// No description provided for @launchSequenceTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: '**
  String get launchSequenceTarget;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// No description provided for @difficultyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get difficultyChallenge;

  /// No description provided for @warpFoldReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get warpFoldReplay;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @magicTrianglesOnboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Magic Triangles'**
  String get magicTrianglesOnboardTitle;

  /// No description provided for @magicTrianglesOnboardDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag numbers from the pool onto the empty triangle nodes.'**
  String get magicTrianglesOnboardDrag;

  /// No description provided for @magicTrianglesOnboardSum.
  ///
  /// In en, this message translates to:
  /// **'Every side of the triangle must add up to the same number.'**
  String get magicTrianglesOnboardSum;

  /// No description provided for @magicTrianglesOnboardTap.
  ///
  /// In en, this message translates to:
  /// **'Tap a placed number to send it back to the pool.'**
  String get magicTrianglesOnboardTap;

  /// No description provided for @parentDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Dashboard'**
  String get parentDashboardTitle;

  /// No description provided for @parentDashboardPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN'**
  String get parentDashboardPinTitle;

  /// No description provided for @parentDashboardPinDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit code to view this screen.\nDefault code is {pin} until you change it.'**
  String parentDashboardPinDesc(String pin);

  /// No description provided for @parentDashboardUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get parentDashboardUnlock;

  /// No description provided for @parentDashboardMathMastery.
  ///
  /// In en, this message translates to:
  /// **'Mathematical Mastery'**
  String get parentDashboardMathMastery;

  /// No description provided for @parentDashboardProblemsTracked.
  ///
  /// In en, this message translates to:
  /// **'Problems tracked'**
  String get parentDashboardProblemsTracked;

  /// No description provided for @parentDashboardMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get parentDashboardMastered;

  /// No description provided for @parentDashboardDueForReview.
  ///
  /// In en, this message translates to:
  /// **'Due for review'**
  String get parentDashboardDueForReview;

  /// No description provided for @parentDashboardCognitiveStrengths.
  ///
  /// In en, this message translates to:
  /// **'Cognitive Strengths'**
  String get parentDashboardCognitiveStrengths;

  /// No description provided for @parentDashboardNoData.
  ///
  /// In en, this message translates to:
  /// **'no data yet'**
  String get parentDashboardNoData;

  /// No description provided for @parentDashboardDataBasis.
  ///
  /// In en, this message translates to:
  /// **'Data basis'**
  String get parentDashboardDataBasis;

  /// No description provided for @parentDashboardStrongest.
  ///
  /// In en, this message translates to:
  /// **'Strongest category'**
  String get parentDashboardStrongest;

  /// No description provided for @parentDashboardWeakest.
  ///
  /// In en, this message translates to:
  /// **'Weakest category'**
  String get parentDashboardWeakest;

  /// No description provided for @parentDashboardTotalAttempts.
  ///
  /// In en, this message translates to:
  /// **'Total attempts'**
  String get parentDashboardTotalAttempts;

  /// No description provided for @parentDashboardGameProgress.
  ///
  /// In en, this message translates to:
  /// **'Game Progress'**
  String get parentDashboardGameProgress;

  /// No description provided for @parentDashboardGamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games played'**
  String get parentDashboardGamesPlayed;

  /// No description provided for @parentDashboardNone.
  ///
  /// In en, this message translates to:
  /// **'none yet'**
  String get parentDashboardNone;

  /// No description provided for @parentDashboardChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change Parent PIN'**
  String get parentDashboardChangePin;

  /// No description provided for @parentDashboardChangePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get parentDashboardChangePinTitle;

  /// No description provided for @parentDashboardNewPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get parentDashboardNewPin;

  /// No description provided for @parentDashboardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get parentDashboardConfirm;

  /// No description provided for @parentDashboardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get parentDashboardCancel;

  /// No description provided for @parentDashboardSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get parentDashboardSave;

  /// No description provided for @parentDashboardPinUpdated.
  ///
  /// In en, this message translates to:
  /// **'PIN updated'**
  String get parentDashboardPinUpdated;

  /// No description provided for @parentDashboardPin4Digits.
  ///
  /// In en, this message translates to:
  /// **'4 digits required'**
  String get parentDashboardPin4Digits;

  /// No description provided for @parentDashboardPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'Does not match'**
  String get parentDashboardPinMismatch;

  /// No description provided for @parentDashboardLevelN.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String parentDashboardLevelN(int level);

  /// No description provided for @sriReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get sriReviewTitle;

  /// No description provided for @sriMasteredLabel.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get sriMasteredLabel;

  /// No description provided for @sriLearningLabel.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get sriLearningLabel;

  /// No description provided for @sriMasteryLabel.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get sriMasteryLabel;

  /// No description provided for @sriToughestProblems.
  ///
  /// In en, this message translates to:
  /// **'Toughest problems'**
  String get sriToughestProblems;

  /// No description provided for @flashcardBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Box'**
  String get flashcardBoxTitle;

  /// No description provided for @flashcardBoxNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get flashcardBoxNew;

  /// No description provided for @flashcardBoxFirstReview.
  ///
  /// In en, this message translates to:
  /// **'First Review'**
  String get flashcardBoxFirstReview;

  /// No description provided for @flashcardBoxPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get flashcardBoxPractice;

  /// No description provided for @flashcardBoxConfident.
  ///
  /// In en, this message translates to:
  /// **'Confident'**
  String get flashcardBoxConfident;

  /// No description provided for @flashcardBoxMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get flashcardBoxMastered;

  /// No description provided for @flashcardBoxMovedToBox.
  ///
  /// In en, this message translates to:
  /// **'Moved to Box {boxNum}'**
  String flashcardBoxMovedToBox(int boxNum);

  /// No description provided for @flashcardBoxMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get flashcardBoxMove;

  /// No description provided for @cognitiveProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Cognitive Profile'**
  String get cognitiveProfileTitle;

  /// No description provided for @cognitiveProfileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play a few games to start building your profile.'**
  String get cognitiveProfileEmpty;

  /// No description provided for @cognitiveProfileAttempts.
  ///
  /// In en, this message translates to:
  /// **'{total} attempts across {areas} skill areas'**
  String cognitiveProfileAttempts(int total, int areas);

  /// No description provided for @cognitiveProfileNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet — play to see this fill in.'**
  String get cognitiveProfileNoData;

  /// No description provided for @cognitiveArithmetic.
  ///
  /// In en, this message translates to:
  /// **'Arithmetic'**
  String get cognitiveArithmetic;

  /// No description provided for @cognitiveSpatial2D.
  ///
  /// In en, this message translates to:
  /// **'Spatial (2D)'**
  String get cognitiveSpatial2D;

  /// No description provided for @cognitiveSpatial3D.
  ///
  /// In en, this message translates to:
  /// **'Spatial (3D)'**
  String get cognitiveSpatial3D;

  /// No description provided for @cognitiveLogic.
  ///
  /// In en, this message translates to:
  /// **'Logic & Deduction'**
  String get cognitiveLogic;

  /// No description provided for @cognitivePattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern Recognition'**
  String get cognitivePattern;

  /// No description provided for @clearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearButton;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelN(int level);

  /// No description provided for @a11yPlacedValueTapRemove.
  ///
  /// In en, this message translates to:
  /// **'Placed value, tap to remove'**
  String get a11yPlacedValueTapRemove;

  /// No description provided for @a11yNumberDragSlot.
  ///
  /// In en, this message translates to:
  /// **'Number {number}, drag to a slot'**
  String a11yNumberDragSlot(int number);

  /// No description provided for @a11yNumberDragCell.
  ///
  /// In en, this message translates to:
  /// **'Number {number}, drag to a cell'**
  String a11yNumberDragCell(int number);

  /// No description provided for @a11yMovesRemaining.
  ///
  /// In en, this message translates to:
  /// **'Moves remaining: {moves}'**
  String a11yMovesRemaining(int moves);

  /// No description provided for @a11yBattlefieldCard.
  ///
  /// In en, this message translates to:
  /// **'Battlefield card {name}'**
  String a11yBattlefieldCard(String name);

  /// No description provided for @a11yHealthStatus.
  ///
  /// In en, this message translates to:
  /// **'Health {current} of {max}'**
  String a11yHealthStatus(int current, int max);

  /// No description provided for @a11yHandCard.
  ///
  /// In en, this message translates to:
  /// **'Hand card {name}'**
  String a11yHandCard(String name);

  /// No description provided for @a11yAsteroid.
  ///
  /// In en, this message translates to:
  /// **'Asteroid {problem}'**
  String a11yAsteroid(String problem);

  /// No description provided for @a11yAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer {answer}'**
  String a11yAnswer(String answer);

  /// No description provided for @a11yBubble.
  ///
  /// In en, this message translates to:
  /// **'Bubble {problem}'**
  String a11yBubble(String problem);

  /// No description provided for @a11yCargoGrid.
  ///
  /// In en, this message translates to:
  /// **'Cargo bay grid'**
  String get a11yCargoGrid;

  /// No description provided for @a11yPlacedValue.
  ///
  /// In en, this message translates to:
  /// **'Placed value {value}'**
  String a11yPlacedValue(String value);

  /// No description provided for @a11yEmptySlot.
  ///
  /// In en, this message translates to:
  /// **'Empty slot for {symbol}'**
  String a11yEmptySlot(String symbol);

  /// No description provided for @a11yDial.
  ///
  /// In en, this message translates to:
  /// **'Dial {label}, value {value}'**
  String a11yDial(String label, int value);

  /// No description provided for @a11yDialHint.
  ///
  /// In en, this message translates to:
  /// **'Drag up or down to change value, or drop a number'**
  String get a11yDialHint;

  /// No description provided for @a11yPiece.
  ///
  /// In en, this message translates to:
  /// **'Piece {size}x{size2}, {remaining} of {total} left'**
  String a11yPiece(int size, int size2, int remaining, int total);

  /// No description provided for @a11yPlacedPiece.
  ///
  /// In en, this message translates to:
  /// **'Placed {size}x{size2} piece'**
  String a11yPlacedPiece(int size, int size2);

  /// No description provided for @a11yGameArea.
  ///
  /// In en, this message translates to:
  /// **'Game area'**
  String get a11yGameArea;

  /// No description provided for @a11yAnswerChoice.
  ///
  /// In en, this message translates to:
  /// **'Answer choice {index}'**
  String a11yAnswerChoice(int index);

  /// No description provided for @a11yLivesRemaining.
  ///
  /// In en, this message translates to:
  /// **'Lives remaining: {lives} of {max}'**
  String a11yLivesRemaining(int lives, int max);

  /// No description provided for @a11yProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress {current} of {total}'**
  String a11yProgress(int current, int total);

  /// No description provided for @a11yAtom.
  ///
  /// In en, this message translates to:
  /// **'Atom {type}'**
  String a11yAtom(String type);

  /// No description provided for @a11yRemoveCommand.
  ///
  /// In en, this message translates to:
  /// **'Remove command'**
  String get a11yRemoveCommand;

  /// No description provided for @a11yCommand.
  ///
  /// In en, this message translates to:
  /// **'Command {name}'**
  String a11yCommand(String name);

  /// No description provided for @a11yGlyph.
  ///
  /// In en, this message translates to:
  /// **'Glyph {name}'**
  String a11yGlyph(String name);

  /// No description provided for @a11yResonator.
  ///
  /// In en, this message translates to:
  /// **'Resonator {number}, drag to a triangle node'**
  String a11yResonator(int number);

  /// No description provided for @a11yBrick.
  ///
  /// In en, this message translates to:
  /// **'Number brick {number}, drag to a slot'**
  String a11yBrick(int number);

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @crashLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Crash log copied to clipboard'**
  String get crashLogCopied;

  /// No description provided for @languageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change language: {error}'**
  String languageChangeFailed(String error);

  /// No description provided for @debugModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Debug Mode Enabled!'**
  String get debugModeEnabled;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @voidCrossingTitle.
  ///
  /// In en, this message translates to:
  /// **'Void Crossing'**
  String get voidCrossingTitle;

  /// No description provided for @voidCrossingDesc.
  ///
  /// In en, this message translates to:
  /// **'Transport creatures across the void — but watch who you leave alone!'**
  String get voidCrossingDesc;

  /// No description provided for @voidCrossingOnboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Void Crossing'**
  String get voidCrossingOnboardTitle;

  /// No description provided for @voidCrossingOnboardTap.
  ///
  /// In en, this message translates to:
  /// **'Tap creatures to load them onto the shuttle, tap again to unload.'**
  String get voidCrossingOnboardTap;

  /// No description provided for @voidCrossingOnboardLaunch.
  ///
  /// In en, this message translates to:
  /// **'Press Launch to send the shuttle across. Plan your moves wisely!'**
  String get voidCrossingOnboardLaunch;

  /// No description provided for @voidCrossingOnboardConflict.
  ///
  /// In en, this message translates to:
  /// **'Some creatures fight when left alone. Check the rules at the bottom!'**
  String get voidCrossingOnboardConflict;

  /// No description provided for @voidCrossingStationAlpha.
  ///
  /// In en, this message translates to:
  /// **'Station Alpha'**
  String get voidCrossingStationAlpha;

  /// No description provided for @voidCrossingStationOmega.
  ///
  /// In en, this message translates to:
  /// **'Station Omega'**
  String get voidCrossingStationOmega;

  /// No description provided for @voidCrossingLaunch.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get voidCrossingLaunch;

  /// No description provided for @voidCrossingReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get voidCrossingReset;

  /// No description provided for @voidCrossingRules.
  ///
  /// In en, this message translates to:
  /// **'Conflict Rules'**
  String get voidCrossingRules;

  /// No description provided for @voidCrossingConflictWarning.
  ///
  /// In en, this message translates to:
  /// **'These creatures would fight! Change your cargo.'**
  String get voidCrossingConflictWarning;

  /// No description provided for @voidCrossingTapToLoad.
  ///
  /// In en, this message translates to:
  /// **'Tap to load onto shuttle'**
  String get voidCrossingTapToLoad;

  /// No description provided for @voidCrossingWin.
  ///
  /// In en, this message translates to:
  /// **'All Safe!'**
  String get voidCrossingWin;

  /// No description provided for @voidCrossingWinDesc.
  ///
  /// In en, this message translates to:
  /// **'All creatures transported in {moves} crossings!'**
  String voidCrossingWinDesc(int moves);

  /// No description provided for @voidCrossingNextPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Next Puzzle'**
  String get voidCrossingNextPuzzle;

  /// No description provided for @voidCrossingLose.
  ///
  /// In en, this message translates to:
  /// **'Out of Fuel!'**
  String get voidCrossingLose;

  /// No description provided for @voidCrossingLoseDesc.
  ///
  /// In en, this message translates to:
  /// **'You ran out of shuttle crossings. Try a different strategy!'**
  String get voidCrossingLoseDesc;

  /// No description provided for @voidCrossingZorblex.
  ///
  /// In en, this message translates to:
  /// **'Zorblex'**
  String get voidCrossingZorblex;

  /// No description provided for @voidCrossingGlimbit.
  ///
  /// In en, this message translates to:
  /// **'Glimbit'**
  String get voidCrossingGlimbit;

  /// No description provided for @voidCrossingStarMoss.
  ///
  /// In en, this message translates to:
  /// **'Star Moss'**
  String get voidCrossingStarMoss;

  /// No description provided for @voidCrossingKraxxon.
  ///
  /// In en, this message translates to:
  /// **'Kraxxon'**
  String get voidCrossingKraxxon;

  /// No description provided for @voidCrossingLumifae.
  ///
  /// In en, this message translates to:
  /// **'Lumifae'**
  String get voidCrossingLumifae;

  /// No description provided for @voidCrossingVoidCrab.
  ///
  /// In en, this message translates to:
  /// **'Void Crab'**
  String get voidCrossingVoidCrab;

  /// No description provided for @voidCrossingNebulaSeed.
  ///
  /// In en, this message translates to:
  /// **'Nebula Seed'**
  String get voidCrossingNebulaSeed;

  /// No description provided for @voidCrossingPyrowyrm.
  ///
  /// In en, this message translates to:
  /// **'Pyrowyrm'**
  String get voidCrossingPyrowyrm;

  /// No description provided for @voidCrossingOnShuttle.
  ///
  /// In en, this message translates to:
  /// **'On shuttle:'**
  String get voidCrossingOnShuttle;

  /// No description provided for @voidCrossingTapToUnload.
  ///
  /// In en, this message translates to:
  /// **'Tap to unload from shuttle'**
  String get voidCrossingTapToUnload;

  /// No description provided for @gridFillerTitle.
  ///
  /// In en, this message translates to:
  /// **'Grid Filler'**
  String get gridFillerTitle;

  /// No description provided for @gridFillerDesc.
  ///
  /// In en, this message translates to:
  /// **'Fill a grid with square pieces — no gaps allowed!'**
  String get gridFillerDesc;

  /// No description provided for @missionHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Space Missions'**
  String get missionHubTitle;

  /// No description provided for @missionHubStart.
  ///
  /// In en, this message translates to:
  /// **'Ready for a Mission?'**
  String get missionHubStart;

  /// No description provided for @missionHubStartDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a series of challenges to decode a secret space codeword!'**
  String get missionHubStartDesc;

  /// No description provided for @missionHubResume.
  ///
  /// In en, this message translates to:
  /// **'Mission in Progress'**
  String get missionHubResume;

  /// No description provided for @missionHubResumeDesc.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} tasks completed.'**
  String missionHubResumeDesc(int completed, int total);

  /// No description provided for @missionHubContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Mission'**
  String get missionHubContinue;

  /// No description provided for @missionHubNewMission.
  ///
  /// In en, this message translates to:
  /// **'New Mission'**
  String get missionHubNewMission;

  /// No description provided for @missionHubAbandon.
  ///
  /// In en, this message translates to:
  /// **'Abandon'**
  String get missionHubAbandon;

  /// No description provided for @missionHubAbandonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Abandon this mission? All progress will be lost.'**
  String get missionHubAbandonConfirm;

  /// No description provided for @missionStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Mission Tasks'**
  String get missionStreakTitle;

  /// No description provided for @missionSolveCodeword.
  ///
  /// In en, this message translates to:
  /// **'Decode the Codeword!'**
  String get missionSolveCodeword;

  /// No description provided for @missionCodewordTitle.
  ///
  /// In en, this message translates to:
  /// **'Codeword Puzzle'**
  String get missionCodewordTitle;

  /// No description provided for @missionCodewordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Arrange the letters to form the secret space word!'**
  String get missionCodewordInstructions;

  /// No description provided for @missionAvailableLetters.
  ///
  /// In en, this message translates to:
  /// **'Available Letters'**
  String get missionAvailableLetters;

  /// No description provided for @missionAllPlaced.
  ///
  /// In en, this message translates to:
  /// **'All letters placed!'**
  String get missionAllPlaced;

  /// No description provided for @missionComplete.
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get missionComplete;

  /// No description provided for @missionCompleteDesc.
  ///
  /// In en, this message translates to:
  /// **'You decoded the codeword: {word}'**
  String missionCompleteDesc(String word);
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
