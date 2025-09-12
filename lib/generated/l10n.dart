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

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to Space Math Academy!'**
  String get welcome;

  /// Button to start the math adventure
  ///
  /// In en, this message translates to:
  /// **'Start Your Math Adventure'**
  String get startAdventure;

  /// Header for grade selection
  ///
  /// In en, this message translates to:
  /// **'Choose Your Grade'**
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

  /// Game menu title
  ///
  /// In en, this message translates to:
  /// **'Game Menu'**
  String get gameMenu;

  /// Zauberdreiecke game name
  ///
  /// In en, this message translates to:
  /// **'Magic Triangles'**
  String get magicTriangles;

  /// Description of magic triangles game
  ///
  /// In en, this message translates to:
  /// **'Solve the mystery of the cosmic triangles! Fill in the missing numbers.'**
  String get magicTrianglesDesc;

  /// Bubble math game name
  ///
  /// In en, this message translates to:
  /// **'Cosmic Bubble Math'**
  String get bubbleMath;

  /// Description of bubble math game
  ///
  /// In en, this message translates to:
  /// **'Pop the floating space bubbles in the correct mathematical order!'**
  String get bubbleMathDesc;

  /// Puzzle math game name
  ///
  /// In en, this message translates to:
  /// **'Space Puzzle Math'**
  String get puzzleMath;

  /// Description of puzzle math game
  ///
  /// In en, this message translates to:
  /// **'Complete the space station by solving math puzzles and fitting pieces together!'**
  String get puzzleMathDesc;

  /// Level indicator
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// Score indicator
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// Lives remaining
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get lives;

  /// Time indicator
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Correct answer feedback
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// Incorrect answer feedback
  ///
  /// In en, this message translates to:
  /// **'Try again!'**
  String get incorrect;

  /// Excellent performance feedback
  ///
  /// In en, this message translates to:
  /// **'Excellent work, Space Explorer!'**
  String get excellent;

  /// Good performance feedback
  ///
  /// In en, this message translates to:
  /// **'Good job!'**
  String get good;

  /// Encouragement to try again
  ///
  /// In en, this message translates to:
  /// **'Let\'s try again!'**
  String get tryAgain;

  /// Game over message
  ///
  /// In en, this message translates to:
  /// **'Mission Complete!'**
  String get gameOver;

  /// Button to go to next level
  ///
  /// In en, this message translates to:
  /// **'Next Mission'**
  String get nextLevel;

  /// Button to play again
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// Button to return to main menu
  ///
  /// In en, this message translates to:
  /// **'Back to Space Station'**
  String get backToMenu;

  /// Settings menu
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Sound settings
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// Music settings
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// Language settings
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Progress tracking
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Achievements section
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

  /// No description provided for @instructionsMagicTriangles.
  ///
  /// In en, this message translates to:
  /// **'Find the missing numbers in each triangle. Each side should add up to the same total!'**
  String get instructionsMagicTriangles;

  /// No description provided for @instructionsBubbleMath.
  ///
  /// In en, this message translates to:
  /// **'Pop the bubbles in order from smallest to largest answer. Watch out for the moving bubbles!'**
  String get instructionsBubbleMath;

  /// No description provided for @instructionsPuzzleMath.
  ///
  /// In en, this message translates to:
  /// **'Drag puzzle pieces to their correct spots. Rotate pieces by tapping them. Match the math answers!'**
  String get instructionsPuzzleMath;

  /// No description provided for @hintsMagicTriangles.
  ///
  /// In en, this message translates to:
  /// **'Remember: each side of the triangle adds up to the magic number!'**
  String get hintsMagicTriangles;

  /// No description provided for @hintsBubbleMath.
  ///
  /// In en, this message translates to:
  /// **'Start with the smallest answer and work your way up!'**
  String get hintsBubbleMath;

  /// No description provided for @hintsPuzzleMath.
  ///
  /// In en, this message translates to:
  /// **'Look for matching colors and solve the math problems first!'**
  String get hintsPuzzleMath;

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
