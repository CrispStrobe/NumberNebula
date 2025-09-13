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
