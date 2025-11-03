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
  /// **'Space Math Academy helps primary school students learn mathematics through engaging space-themed games. Perfect for iPads and designed with young learners in mind.'**
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

  /// No description provided for @appVersionValue.
  ///
  /// In en, this message translates to:
  /// **'1.0.2'**
  String get appVersionValue;

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
