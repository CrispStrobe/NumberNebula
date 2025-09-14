// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Weltraum Mathe Akademie';

  @override
  String get welcome => 'Entdecke das Mathe-Universum!';

  @override
  String get startAdventure => 'Starte dein Mathe-Abenteuer';

  @override
  String get chooseGrade => 'Wähle deine Stufe';

  @override
  String get grade3 => '3. Klasse';

  @override
  String get grade4 => '4. Klasse';

  @override
  String get grade5 => '5. Klasse';

  @override
  String get grade6 => '6. Klasse';

  @override
  String get gameMenu => 'Missionskontrolle';

  @override
  String get magicTriangles => 'Kosmische Dreiecke';

  @override
  String get magicTrianglesDesc =>
      'Richte die kosmischen Energieknoten aus! Jede Seite des Dreiecks muss die gleiche kosmische Frequenz ergeben, um das Wurmloch zu stabilisieren.';

  @override
  String get bubbleMath => 'Asteroidenfeld-Jäger';

  @override
  String get bubbleMathDesc =>
      'Navigiere durch ein gefährliches Asteroidenfeld! Zerstöre die treibenden Weltraumfelsen in der richtigen Reihenfolge, bevor sie kollidieren.';

  @override
  String get puzzleMath => 'Sternbild-Puzzles';

  @override
  String get puzzleMathDesc =>
      'Rekonstruiere himmlische Sternenkarten! Löse Gleichungen, um die richtigen Koordinaten zu finden und Fragmente zu platzieren.';

  @override
  String get hyperdriveGates => 'Hyperantriebs-Tore';

  @override
  String get hyperdriveGatesDesc =>
      'Setze einen Kurs durch Quanten-Raumtore! Fliege durch das Tor mit der richtigen Antwort, um den Sprung auf Lichtgeschwindigkeit zu machen.';

  @override
  String get planetHopping => 'Gravitations-Schleuder';

  @override
  String get planetHoppingDesc =>
      'Schleudere dein Schiff zwischen Planeten! Berechne die richtige Flugbahn und besuche Planeten in der korrekten mathematischen Reihenfolge.';

  @override
  String get level => 'Level';

  @override
  String get score => 'Punkte';

  @override
  String get lives => 'Hüllenintegrität';

  @override
  String get time => 'Zeit';

  @override
  String get correct => 'Richtig!';

  @override
  String get incorrect => 'Neuberechnung...';

  @override
  String get excellent => 'Hervorragende Arbeit, Weltraum-Kommandant!';

  @override
  String get good => 'Gut gemacht!';

  @override
  String get tryAgain => 'Versuchen wir es nochmal!';

  @override
  String get gameOver => 'Mission abgeschlossen!';

  @override
  String get nextLevel => 'Nächste Mission';

  @override
  String get playAgain => 'Nochmal spielen';

  @override
  String get backToMenu => 'Zurück zur Missionskontrolle';

  @override
  String get settings => 'Einstellungen';

  @override
  String get sound => 'Soundeffekte';

  @override
  String get music => 'Musik';

  @override
  String get language => 'Sprache';

  @override
  String get progress => 'Karrierefortschritt';

  @override
  String get achievements => 'Erfolge';

  @override
  String get mathOperationsAddition => 'Addition';

  @override
  String get mathOperationsSubtraction => 'Subtraktion';

  @override
  String get mathOperationsMultiplication => 'Multiplikation';

  @override
  String get mathOperationsDivision => 'Division';

  @override
  String get congratulations => 'Herzlichen Glückwunsch, Kommandant!';

  @override
  String missionsCompleted(int count) {
    return 'Missionen abgeschlossen: $count';
  }

  @override
  String starsEarned(int count) {
    return 'Sterne erhalten: $count';
  }

  @override
  String get audioSettings => 'Audio-Einstellungen';

  @override
  String get soundEffects => 'Soundeffekte';

  @override
  String get backgroundMusicDesc => 'Hintergrundmusik';

  @override
  String get gameplay => 'Spielablauf';

  @override
  String get puzzleTimer => 'Puzzle-Timer';

  @override
  String get puzzleTimerDesc => 'Timer in Puzzle-Spielen aktivieren';

  @override
  String get showHints => 'Hinweise anzeigen';

  @override
  String get showHintsDesc => 'Hilfreiche Tipps während der Spiele anzeigen';

  @override
  String get hapticFeedback => 'Haptisches Feedback';

  @override
  String get hapticFeedbackDesc =>
      'Vibration bei Berührung (falls unterstützt)';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get appLanguageDesc => 'Wähle deine bevorzugte Sprache';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get difficulty => 'Schwierigkeit';

  @override
  String get currentGrade => 'Aktuelle Klasse';

  @override
  String get currentLevelDesc => 'Aktuelles Level';

  @override
  String get difficultyDescGrade3 => 'Grundrechenarten';

  @override
  String get difficultyDescGrade4 => 'Mehrstellige Mathematik';

  @override
  String get difficultyDescGrade5 => 'Komplexe Probleme';

  @override
  String get difficultyDescGrade6 => 'Fortgeschrittene Herausforderungen';

  @override
  String get totalScore => 'Gesamtpunktzahl';

  @override
  String get gamesPlayed => 'Gespielte Spiele';

  @override
  String get resetProgress => 'Fortschritt zurücksetzen';

  @override
  String get about => 'Über';

  @override
  String get appVersion => 'App-Version';

  @override
  String get developer => 'Entwickler';

  @override
  String get developerName => 'Space Math Academy Team';

  @override
  String get targetAge => 'Zielalter';

  @override
  String get targetAgeRange => '8-12 Jahre (Klasse 3-6)';

  @override
  String get aboutApp =>
      'Die Space Math Academy hilft Grundschülern, Mathematik durch fesselnde Weltraum-Spiele zu lernen. Perfekt für iPads und für junge Lernende konzipiert.';

  @override
  String get languageChanged => 'Sprache geändert';

  @override
  String get languageChangedDesc =>
      'Die App-Sprache wird nach einem Neustart geändert. Möchtest du jetzt neu starten?';

  @override
  String get later => 'Später';

  @override
  String get restartNow => 'Jetzt neu starten';

  @override
  String get selectGrade => 'Klasse auswählen';

  @override
  String gradeN(int gradeNumber) {
    return 'Klasse $gradeNumber';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get restartToApplyChanges =>
      'Bitte starte die App neu, um die Sprachänderungen zu übernehmen';

  @override
  String get resetProgressConfirmation =>
      'Bist du sicher, dass du den gesamten Fortschritt zurücksetzen möchtest? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get progressResetSuccess => 'Fortschritt erfolgreich zurückgesetzt!';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get playToUnlock => 'Spielen zum Freischalten!';

  @override
  String get chooseYourGrade => 'Wähle deine Klassenstufe';

  @override
  String get grade3Desc =>
      'Grundlegende Addition, Subtraktion und einfache Multiplikation';

  @override
  String get grade4Desc =>
      'Mehrstellige Arithmetik und Einführung in die Division';

  @override
  String get grade5Desc => 'Komplexe Operationen und Problemlösung';

  @override
  String get grade6Desc =>
      'Fortgeschrittene Mathematik und anspruchsvolle Rätsel';

  @override
  String get settingsComingSoon => 'Einstellungen bald verfügbar!';

  @override
  String get spaceExplorerProgress => 'Weltraumforscher-Fortschritt';

  @override
  String get unlocked => 'Freigeschaltet';

  @override
  String get complete => 'Abgeschlossen';

  @override
  String get rankRookie => 'Rekrut';

  @override
  String get rankExplorer => 'Entdecker';

  @override
  String get rankVeteran => 'Veteran';

  @override
  String get rankExpert => 'Experte';

  @override
  String get rankLegend => 'Legende';

  @override
  String get achievementFirstCenturyTitle => 'Erstes Hundert!';

  @override
  String get achievementFirstCenturyDesc => 'Erreiche 100 Punkte';

  @override
  String get achievementScoreMasterTitle => 'Punkte-Meister';

  @override
  String get achievementScoreMasterDesc => 'Erreiche 500 Punkte';

  @override
  String get achievementThousandClubTitle => 'Tausender-Club';

  @override
  String get achievementThousandClubDesc => 'Erreiche 1000 Punkte';

  @override
  String get achievementLevelExplorerTitle => 'Level-Entdecker';

  @override
  String get achievementLevelExplorerDesc => 'Erreiche Level 5';

  @override
  String get achievementSpaceCommanderTitle => 'Weltraum-Kommandant';

  @override
  String get achievementSpaceCommanderDesc => 'Erreiche Level 10';

  @override
  String get achievementTriangleWizardTitle => 'Dreiecks-Magier';

  @override
  String get achievementTriangleWizardDesc =>
      'Schließe 3 Kosmische Dreiecke-Level ab';

  @override
  String get achievementBubblePopperTitle => 'Blasen-Platzer';

  @override
  String get achievementBubblePopperDesc => 'Schließe 3 Blasen-Mathe-Level ab';

  @override
  String get achievementPuzzleSolverTitle => 'Puzzle-Löser';

  @override
  String get achievementPuzzleSolverDesc => 'Schließe 3 Puzzle-Mathe-Level ab';

  @override
  String get achievementAllRounderTitle => 'Alleskönner';

  @override
  String get achievementAllRounderDesc => 'Spiele alle Spieltypen';

  @override
  String get achievementSpeedDemonTitle => 'Geschwindigkeits-Dämon';

  @override
  String get achievementSpeedDemonDesc =>
      'Schließe ein Level in unter 30 Sekunden ab';

  @override
  String get achievementPerfectionistTitle => 'Perfektionist';

  @override
  String get achievementPerfectionistDesc =>
      'Schließe ein Level ohne Fehler ab';

  @override
  String get achievementMathematicianTitle => 'Junger Mathematiker';

  @override
  String get achievementMathematicianDesc => 'Löse 100 Matheaufgaben';

  @override
  String get unlockedStatus => 'FREIGESCHALTET';

  @override
  String get lockedStatus => 'GESPERRT';

  @override
  String get achievementUnlocked => 'ERFOLG FREIGESCHALTET!';

  @override
  String get continueExploring => 'Weiter erkunden';

  @override
  String get planetHoppingObjectiveAsc =>
      'Besuche Planeten in aufsteigender Reihenfolge!';

  @override
  String get planetHoppingObjectiveDesc =>
      'Besuche Planeten in absteigender Reihenfolge!';

  @override
  String get planetHoppingObjectiveEvenOdd =>
      'Besuche zuerst gerade, dann ungerade Zahlen!';

  @override
  String get planetHoppingTitle => 'Planeten-Hüpfen';

  @override
  String planetHoppingNextTarget(Object target) {
    return 'Nächstes: $target';
  }

  @override
  String get planetHoppingInstructions =>
      'TIPPE irgendwohin, um dorthin zu springen • Nutze die Schwerkraft, um zwischen Planeten zu schwingen';

  @override
  String get planetHoppingWinTitle => 'Sonnensystem gemeistert!';

  @override
  String planetHoppingWinDesc(Object bonus) {
    return 'Du hast erfolgreich alle Planeten in der richtigen Reihenfolge navigiert!\nLebens-Bonus: $bonus Punkte';
  }

  @override
  String planetHoppingWinDescBonus(int bonus) {
    return 'Du hast erfolgreich alle Planeten in der richtigen Reihenfolge navigiert!\nLebens-Bonus: $bonus Punkte';
  }

  @override
  String get planetHoppingLoseDescCrash =>
      'Du bist zu oft abgestürzt!\nStudiere die Planetenreihenfolge und versuche es erneut.';

  @override
  String planetHoppingNextTargetValue(int value) {
    return 'Nächster: $value';
  }

  @override
  String get exploreAgain => 'Erneut erkunden';

  @override
  String get missionCompleteStatus => 'Mission erfolgreich';

  @override
  String get planetHoppingLoseTitle => 'Navigation fehlgeschlagen!';

  @override
  String get planetHoppingLoseDesc =>
      'Du bist zu oft abgestürzt!\nStudiere die Planetenreihenfolge und versuche es erneut.';

  @override
  String get retryMission => 'Mission wiederholen';

  @override
  String get returnToBase => 'Zurück zur Basis';

  @override
  String get hyperdriveGatesTitle => 'Hyperantriebs-Tore';

  @override
  String get solve => 'LÖSE:';

  @override
  String hyperdriveGatesObjective(Object correctAnswer) {
    return 'Fliege durch Tore mit: $correctAnswer';
  }

  @override
  String get hyperdriveGatesInstructions =>
      'ZIEHE, um dein Schiff zu steuern • FLIEGE durch KORREKTE Tore • VERMEIDE falsche Antworten';

  @override
  String get hyperdriveGatesWinTitle =>
      'Hyperantriebs-Navigation abgeschlossen!';

  @override
  String hyperdriveGatesWinDesc(Object targetGatesNeeded) {
    return 'Du hast erfolgreich durch $targetGatesNeeded Tore navigiert!\nDu bist bereit für Missionen im tiefen Weltraum!';
  }

  @override
  String get flyAgain => 'Erneut fliegen';

  @override
  String get hyperdriveGatesLoseTitle => 'Navigationssystem ausgefallen!';

  @override
  String get hyperdriveGatesLoseDesc =>
      'Dein Schiff hat zu viel Schaden genommen!\nKehre zur Basis zurück für Reparaturen und versuche es erneut.';

  @override
  String get noPuzzleImagesFound =>
      'Keine Sternbild-Bilder in assets/images/ gefunden.';

  @override
  String get puzzleMathInstructions =>
      'Baue das Weltraum-Sternbild wieder auf! Ziehe Teile an die richtigen Stellen. Tippe auf Teile, um sie zu drehen!';

  @override
  String get timer => 'Timer';

  @override
  String get timesUp => 'Zeit abgelaufen, Weltraumkadett!';

  @override
  String get constellationPieces => 'Sternbild-Teile';

  @override
  String get puzzleMathIncorrect =>
      'Überprüfe die Mathe-Antwort oder versuche, das Teil zu drehen!';

  @override
  String get puzzleMathWin =>
      'Sternbild wiederhergestellt, Weltraum-Entdecker!';

  @override
  String puzzleMathWinBonus(Object bonus) {
    return 'Sternbild wiederhergestellt!\nZeitbonus: $bonus Punkte!';
  }

  @override
  String get puzzleMathTryAnother => 'Versuchen wir ein anderes Sternbild!';

  @override
  String get magicTrianglesGameTitle => 'Wurmloch-Aktivator';

  @override
  String get magicTrianglesInstructions =>
      'Richte das Stargate aus! Ziehe Resonatoren, um die erforderliche Warp-Frequenz auf jeder Seite zu erreichen.';

  @override
  String magicTrianglesWarpFrequency(Object warpFrequency) {
    return 'Warp-Frequenz: $warpFrequency';
  }

  @override
  String get magicTrianglesResonators => 'Verfügbare Subraum-Resonatoren';

  @override
  String get magicTrianglesFail =>
      'Ausrichtung fehlgeschlagen. Die Energiesignatur ist falsch. Versuche es erneut!';

  @override
  String get calculatingCoordinates => 'Berechne Wurmloch-Koordinaten...';

  @override
  String get magicTrianglesWinTitle => 'Wurmloch stabilisiert!';

  @override
  String magicTrianglesWinDesc(Object bonusScore) {
    return 'Perfekte Ausrichtung! Der Warp-Korridor ist offen.\nBonus: +$bonusScore Punkte!';
  }

  @override
  String get nextAnomaly => 'Nächste Anomalie';

  @override
  String get toTheBridge => 'Zur Brücke';

  @override
  String get asteroidMathHunter => 'Asteroiden-Mathe-Jäger';

  @override
  String asteroidMathTarget(Object target) {
    return 'Ziel-Asteroid: $target';
  }

  @override
  String get asteroidMathWinTitle => 'Asteroidenfeld geräumt!';

  @override
  String asteroidMathWinDesc(Object timeBonus) {
    return 'Zeitbonus: $timeBonus Punkte!\nDu bist ein wahrer Weltraum-Jäger!';
  }

  @override
  String get timesUpSpaceCadet => 'Zeit abgelaufen, Weltraumkadett!';

  @override
  String get asteroidMathLoseDesc =>
      'Das Asteroidenfeld wurde zu chaotisch!\nVersuche es erneut, Kommandant!';

  @override
  String get nextTarget => 'Nächstes Ziel: ';

  @override
  String get loadingAdventure => 'Lade Weltraum-Abenteuer...';

  @override
  String get preparingMission => 'Bereite deine Mathe-Mission vor...';

  @override
  String get initializing => 'Initialisiere Space Math Academy...';

  @override
  String get loadingAssets => 'Lade Spiel-Assets...';

  @override
  String get loadingProgress => 'Lade gespeicherten Fortschritt...';

  @override
  String get preparingSpaceStation => 'Bereite Raumstation vor...';

  @override
  String get calibratingNav => 'Kalibriere Navigationssysteme...';

  @override
  String get readyForLaunch => 'Bereit zum Start!';

  @override
  String get splashScreenSubtitle => 'Erkunden • Lernen • Entdecken';
}
