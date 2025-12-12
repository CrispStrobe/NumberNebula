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
  String get fast => 'SCHNELL';

  @override
  String get grade3 => 'Stufe 1';

  @override
  String get grade4 => 'Stufe 2';

  @override
  String get grade5 => 'Stufe 3';

  @override
  String get grade6 => 'Stufe 4';

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
  String get tryAgain => 'Nochmal versuchen!';

  @override
  String get gameOver => 'Mission abgeschlossen!';

  @override
  String get nextLevel => 'Nächstes Level';

  @override
  String get playAgain => 'Nochmal';

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
  String get congratulations => 'Glückwunsch!';

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
  String get currentGrade => 'Aktuelle Stufe';

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
  String get totalScore => 'Gesamtpunkte';

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
  String get developerName => 'CrispStrobe';

  @override
  String get targetAge => 'Zielalter';

  @override
  String get targetAgeRange => '6-12 Jahre (Klassen 1-6)';

  @override
  String get aboutApp =>
      'Die App hilft hoffentlich Kindern, Mathematik durch fesselnde Weltraum-Spiele zu lernen. Optimiert für Tablets.';

  @override
  String get languageRestartPrompt =>
      'Die App-Sprache wird beim Neustart geändert. Möchtest du jetzt neu starten?';

  @override
  String get later => 'Später';

  @override
  String get restartNow => 'Jetzt neu starten';

  @override
  String get resetProgressConfirm =>
      'Bist du sicher, dass du den gesamten Fortschritt zurücksetzen möchtest? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get appVersionValue => '1.0.2';

  @override
  String get legalNotice => 'Impressum anzeigen';

  @override
  String get debugPanelTitle => 'Debug-Panel';

  @override
  String get debugForceUnlock => 'Vollversion erzwingen';

  @override
  String get debugApplyAndClose => 'Anwenden & Schließen';

  @override
  String get parentalGateTitle => 'Kindersicherung';

  @override
  String get parentalGateChallenge =>
      'Um fortzufahren, bitte diese Aufgabe lösen:';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get pleaseTryAgain => 'Bitte versuche es erneut.';

  @override
  String get purchaseTitle => 'Vollzugriff freischalten';

  @override
  String get purchaseDescription =>
      'Schalte alle 8 Spiele, alle 4 Schwierigkeitsstufen und zukünftige Updates mit einem einzigen Kauf frei!';

  @override
  String get purchaseButton => 'Jetzt freischalten!';

  @override
  String get contactingStore => 'Verbinde mit Missionskontrolle...';

  @override
  String get purchaseError =>
      'Ein Fehler ist aufgetreten. Bitte prüfe deine Verbindung und versuche es erneut.';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get storeUnavailable =>
      'Der Store ist derzeit nicht verfügbar. Bitte prüfe deine Verbindung und ob du mit deinem Konto angemeldet bist.';

  @override
  String get languageChanged => 'Sprache geändert';

  @override
  String get languageChangedDesc =>
      'Die App-Sprache wird nach einem Neustart geändert. Möchtest du jetzt neu starten?';

  @override
  String get selectGrade => 'Stufe auswählen';

  @override
  String gradeN(int gradeNumber) {
    return 'Stufe $gradeNumber';
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
  String get reset => 'Neustart';

  @override
  String get playToUnlock => 'Spielen zum Freischalten!';

  @override
  String get chooseYourGrade => 'Wähle deine Stufe';

  @override
  String get grade3Desc =>
      'Grundlegende Addition, Subtraktion und einfache Multiplikation';

  @override
  String get grade4Desc =>
      'Mehrstellige Arithmetik und Einführung in die Division';

  @override
  String get grade5Desc => 'Komplexe Operationen, Brüche und Dezimalzahlen';

  @override
  String get grade6Desc =>
      'Fortgeschrittene Mathematik und anspruchsvolle Rätsel';

  @override
  String get adaptiveDifficulty => 'Angepasste Schwierigkeit';

  @override
  String get adaptiveDifficultyDesc => 'Passt Aufgaben an dein Können an';

  @override
  String get adjustProblems => 'Passe die Aufgaben an deine Fähigkeiten an';

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
      'Suche den Planeten mit der größten Gravitation.';

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
  String get asteroidMathHunterDesc =>
      'Navigiere durch ein gefährliches Asteroidenfeld! Zerstöre die treibenden Weltraumfelsen in der richtigen Reihenfolge, bevor sie kollidieren.';

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
  String get launch => 'Start';

  @override
  String get splashScreenSubtitle => 'Erkunden • Lernen • Entdecken';

  @override
  String get pathFinderTitle => 'PfadFinder';

  @override
  String get pathFinderDesc =>
      'Navigiere durch Quanten-Raumkorridore! Berechne die richtige Flugbahn durch gefährliche kosmische Phänomene, um sicher anzukommen.';

  @override
  String get pathFinderSolve => 'LÖSE:';

  @override
  String pathFinderChoosePath(String expression) {
    return 'Wähle den Pfad für: $expression';
  }

  @override
  String get pathFinderInstructions =>
      'TIPPE auf Weltraumrouten • BERECHNE Matheaufgaben • NAVIGIERE durch kosmische Gefahren';

  @override
  String get pathFinderWinTitle => 'Quanten-Navigation abgeschlossen!';

  @override
  String pathFinderWinDesc(int targetProblems, int totalScore) {
    return 'Du hast erfolgreich $targetProblems Quantenkorridore navigiert!\nGesamtpunktzahl: $totalScore Punkte!';
  }

  @override
  String get pathFinderLoseTitle => 'Navigationssysteme offline!';

  @override
  String get pathFinderLoseDesc =>
      'Dein Schiff hat zu viel Schaden durch kosmische Gefahren erlitten!\nKalibriere deine Navigationssysteme neu und versuche es erneut, Kommandant!';

  @override
  String get pathFinderFailureWormhole => 'Wurmloch-Kollaps!';

  @override
  String get pathFinderFailureNebula => 'Nebel-Interferenz!';

  @override
  String get pathFinderFailureAsteroidBelt => 'Asteroidenkollision!';

  @override
  String get pathFinderFailureClearSpace => 'Navigationsfehler!';

  @override
  String get pathFinderFailureIonStorm => 'Ionensturm-Schäden!';

  @override
  String get pathFinderFailureQuantumTunnel => 'Quanten-Instabilität!';

  @override
  String get numberWalls => 'Zahlenmauern';

  @override
  String get numberWallsDesc =>
      'Baue kosmische Rechenpyramiden! Stabilisiere die Quantenstruktur!';

  @override
  String get numberWallsGameTitle => 'Quanten-Pyramiden-Baumeister';

  @override
  String get numberWallsInstructions =>
      'Baue die Zahlenmauer! Ziehe Zahlen, um die Struktur zu vervollständigen.';

  @override
  String get numberWallsCalculating => 'Berechne Pyramiden-Koordinaten...';

  @override
  String get numberWallsBricks => 'Verfügbare Bausteine';

  @override
  String get numberWallsFail =>
      'Strukturelle Integrität gefährdet! Das mathematische Fundament ist instabil. Versuche es erneut!';

  @override
  String get numberWallsWinTitle => 'Pyramide stabilisiert!';

  @override
  String numberWallsWinDesc(int bonusScore) {
    return 'Perfekte mathematische Ausrichtung! Die Quantenstruktur ist stabil.\nBonus: +$bonusScore Punkte!';
  }

  @override
  String get numberWallsNextWall => 'Nächste Pyramide';

  @override
  String get numberWallsAddition => 'Quanten-Additions-Matrix';

  @override
  String get numberWallsSubtraction => 'Stern-Subtraktions-Gitter';

  @override
  String get numberWallsMultiplication => 'Kosmisches Multiplikations-Array';

  @override
  String get numberWallsDivision => 'Galaktisches Divisions-Netzwerk';

  @override
  String get numberWallsDropFar => 'Bitte näher zum Ziel platzieren.';

  @override
  String get numberWallsAddDesc =>
      'Jeder Stein ist die Summe der zwei darunter.';

  @override
  String get numberWallsSubDesc =>
      'Der untere Stein ist der Unterschied zwischen den beiden darüber.';

  @override
  String get numberWallsMultDesc =>
      'Jeder Stein ist das Produkt der beiden darunter.';

  @override
  String get numberWallsDivDesc =>
      'Jeder Stein ist das Ergebnis der Teilung der beiden darunter.';

  @override
  String get codebreaker => 'Codeknacker';

  @override
  String get codebreakerDesc =>
      'Fange außerirdische Übertragungen ab und entschlüssle sie! Löse komplexe Gleichungssysteme, um ihre Geheimnisse zu lüften.';

  @override
  String get codebreakerSuccess => 'Code geknackt!';

  @override
  String get codebreakerError => 'Übertragung fehlerhaft';

  @override
  String get codebreakerTransmissionReceived => 'Alien-Übertragung abgefangen';

  @override
  String get codebreakerSelectNumbers =>
      'Wähle Zahlen aus, um die Übertragung zu entschlüsseln';

  @override
  String get codebreakerInstructions =>
      'Entschlüssle die Alien-Symbole, indem du die Gleichungen löst. Tippe auf Zahlen, um die fehlenden Werte einzusetzen.';

  @override
  String get codebreakerWinTitle => 'Mission abgeschlossen!';

  @override
  String get codebreakerLoseTitle => 'Übertragung verloren';

  @override
  String codebreakerWinDesc(int totalScore) {
    return 'Ausgezeichnete Arbeit, Kadett! Du hast $totalScore Punkte verdient. Die Galaxie ist dank deiner kryptografischen Fähigkeiten sicherer!';
  }

  @override
  String get codebreakerLoseDesc =>
      'Die Alien-Codes waren zu komplex, um sie rechtzeitig zu knacken. Keine Sorge – selbst die besten Codeknacker brauchen Übung!';

  @override
  String get problemCustomization => 'Aufgaben-Anpassung';

  @override
  String get problemCustomizationDesc =>
      'Passe die Rechenarten und Zahlenbereiche in den Spielen an.';

  @override
  String get problemCustomizationUnlock =>
      'Diese Funktion erfordert die Vollversion.';

  @override
  String get enableCustomSettings => 'Eigene Einstellungen aktivieren';

  @override
  String get allowedOperations => 'Erlaubte Rechenarten';

  @override
  String get numberRange => 'Zahlenbereich';

  @override
  String get minValue => 'Min. Wert';

  @override
  String get maxValue => 'Max. Wert';

  @override
  String get perspectivePuzzleGameTitle => 'Anomalie-Scan';

  @override
  String get anomalyScanTitle => 'Anomalie-Scan';

  @override
  String get perspectivePuzzleInstructions =>
      'Scanne Astro-Objekte aus verschiedenen Sensor-Perspektiven.';

  @override
  String anomalyScanSelectReadout(String perspective) {
    return 'Ordne das Hologramm dem korrekten $perspective Sensor-Scan zu';
  }

  @override
  String get anomalyScanWinTitle => 'Analyse abgeschlossen!';

  @override
  String anomalyScanWinDesc(int bonus) {
    return 'Anomalie identifiziert. Daten protokolliert. Bonus: $bonus Punkte.';
  }

  @override
  String get perspectivePuzzleWinTitle => 'Analyse vollständig!';

  @override
  String perspectivePuzzleWinDesc(int bonus) {
    return 'Anomalie identifiziert. Daten protokolliert. Bonus: $bonus Punkte.';
  }

  @override
  String perspectivePuzzleSelectView(String perspective) {
    return 'Wähle die Perspektive $perspective .';
  }

  @override
  String get perspectiveFront => 'VORN';

  @override
  String get perspectiveBack => 'HINTEN';

  @override
  String get perspectiveLeft => 'LINKS';

  @override
  String get perspectiveRight => 'RECHTS';

  @override
  String get anomalyScanFail => 'Scan-Fehler. Sensoren werden rekalibriert...';

  @override
  String get perspectiveDensityScan => 'DICHTE';

  @override
  String get perspectiveStructuralScan => 'STRUKTUR';

  @override
  String get perspectiveThermalScan => 'THERMAL';

  @override
  String get perspectiveEMScan => 'EM-FELD';

  @override
  String get blockCounterGameTitle => '3D Block-Zähler';

  @override
  String get blockCounterInstructions =>
      'Drehe und zähle alle Blöcke einschließlich der versteckten';

  @override
  String get blockCounterFail => 'Falsche Anzahl! Versuche es erneut.';

  @override
  String blockCounterComplexity(int level) {
    return 'Komplexität: $level';
  }

  @override
  String get blockCounterQuestion =>
      'Wie viele Blöcke sind in dieser Struktur?';

  @override
  String get blockCounterSelectAnswer => 'Wähle deine Antwort';

  @override
  String get blockCounterShowHint => 'Versteckte zeigen';

  @override
  String get blockCounterHideHint => 'Hinweis verbergen';

  @override
  String get blockCounterRotateInstructions =>
      'Ziehen zum Drehen • Kneifen zum Zoomen';

  @override
  String get blockCounterHintShowing =>
      'Versteckte Blöcke sind gelb hervorgehoben';

  @override
  String get blockCounterHintHidden =>
      'Einige Blöcke können hinter anderen versteckt sein';

  @override
  String get blockCounterWinTitle => 'Perfekte Zählung!';

  @override
  String blockCounterWinDesc(int count) {
    return 'Richtig! Es waren $count Blöcke insgesamt.';
  }

  @override
  String blockCounterBonusPoints(int bonus) {
    return 'Bonuspunkte: $bonus';
  }

  @override
  String get blockCounterDifficultyVeryEasy => 'Sehr Einfach';

  @override
  String get blockCounterDifficultyEasy => 'Einfach';

  @override
  String get blockCounterDifficultyMedium => 'Mittel';

  @override
  String get blockCounterDifficultyHard => 'Schwer';

  @override
  String get blockCounterNextPuzzle => 'Nächstes Rätsel';

  @override
  String get blockCounterBackToMenu => 'Zurück zum Menü';

  @override
  String get sriStatisticsTitle => 'Lernfortschritt';

  @override
  String get sriStatisticsDesc =>
      'Sieh dir deinen Fortschritt an und erkenne, wo du dich verbessern kannst.';

  @override
  String get premiumFeature =>
      'Dies ist eine Premium-Funktion. Schalte die Vollversion frei, um darauf zuzugreifen.';

  @override
  String get close => 'Schließen';

  @override
  String get sriMastery => 'Gesamtbeherrschung';

  @override
  String get sriTotal => 'Gesamt Erfasst';

  @override
  String get sriMastered => 'Beherrscht';

  @override
  String get sriLearning => 'Im Training';

  @override
  String get progressMatrixTitle => 'Fortschrittsmatrix';

  @override
  String get progressMatrixDesc =>
      'Die Farbe zeigt die Beherrschung (grün ist am besten). Die Zahl zeigt die Anzahl der Aufgaben in diesem Bereich.';

  @override
  String get signalTriangulationGameTitle => 'Signal-Triangulation';

  @override
  String get signalTriangulationInstructions =>
      'Ein schwaches Weltraum-Signal wurde erkannt! Entschlüssele die Folge durch Analyse der Echo-Antworten. Grüne Punkte = richtige Frequenz an richtiger Position, Orange Ringe = richtige Frequenz an falscher Position.';

  @override
  String signalTriangulationAttempts(int current, int max) {
    return 'Versuche: $current/$max';
  }

  @override
  String signalTriangulationLength(int length) {
    return 'Sequenz: $length Frequenzen';
  }

  @override
  String get signalTriangulationCurrentSequence => 'Aktuelle Signalsequenz';

  @override
  String get signalTriangulationFrequencies => 'Verfügbare Frequenzen';

  @override
  String get signalTriangulationPreviousAttempts => 'Echo-Analyse-Protokoll';

  @override
  String get signalTriangulationClear => 'Löschen';

  @override
  String get signalTriangulationTransmit => 'Senden';

  @override
  String get signalTriangulationWinTitle => 'Signalquelle lokalisiert!';

  @override
  String signalTriangulationWinDesc(int attempts, int totalScore, int bonus) {
    return 'Ausgezeichnete Arbeit, Astro-Techniker! Du hast Signal in $attempts Versuchen trianguliert und $totalScore Punkte verdient. Effizienz-Bonus: $bonus Punkte!';
  }

  @override
  String get signalTriangulationLoseTitle => 'Signal im Rauschen verloren';

  @override
  String get signalTriangulationLoseDesc =>
      'Das Signal ist jenseits der Erkennungsreichweite verblasst. Das Signal bleibt in der kosmischen Leere verborgen.';

  @override
  String signalTriangulationReveal(String sequence) {
    return 'Die korrekte Sequenz war: $sequence';
  }

  @override
  String get nextSignal => 'Nächstes Signal';

  @override
  String get cryptexLockBreakerGameTitle => 'Kryptex-Schloss-Knacker';

  @override
  String get cryptexLockBreakerInstructions =>
      'Das Code-Kryptex nutzt ineinandergreifende Gleichungen als Kombination. Drehe die Scheiben, um alle Gleichungen gleichzeitig zu erfüllen.';

  @override
  String get cryptexLockBreakerControls =>
      'Tippe und ziehe Scheiben hoch/runter zum Drehen • Beobachte, wie Gleichungen grün werden, wenn gelöst';

  @override
  String get cryptexLockBreakerEquations => 'Schloss-Gleichungen';

  @override
  String get cryptexLockBreakerWinTitle => 'Kryptex entsperrt!';

  @override
  String cryptexLockBreakerWinDesc(
      int totalScore, int complexityBonus, int equationBonus) {
    return 'Brillante Arbeit, Astro-Techniker! Du hast den Schlossmechanismus geknackt und $totalScore Punkte verdient. Komplexitäts-Bonus: $complexityBonus • Gleichungs-Bonus: $equationBonus';
  }

  @override
  String get nextCryptex => 'Nächstes Kryptex';

  @override
  String get arithmancerGameTitle => 'Arithmancer-Duell';

  @override
  String get arithmancerGameInstructions =>
      'Kämpfe als Coder gegen feindselige KI Programme.';

  @override
  String get arithmancerHealth => 'Gesundheit';

  @override
  String get arithmancerSkipTurn => 'Zug überspringen';

  @override
  String get arithmancerEnergy => 'Energie';

  @override
  String get arithmancerBlock => 'Schild';

  @override
  String get arithmancerExpression => 'Kampfsequenz';

  @override
  String get arithmancerExecute => 'Ausführen';

  @override
  String get arithmancerDragCards =>
      'Ziehe Karten hierher, um deine Kampfsequenz zu erstellen';

  @override
  String get arithmancerHand => 'Neural-Arsenal';

  @override
  String get arithmancerNoCards => 'Keine Algorithmen verfügbar';

  @override
  String get arithmancerInvalidExpression =>
      'Ungültige Sequenz - Syntax prüfen';

  @override
  String get arithmancerNotEnoughEnergy =>
      'Unzureichende Verarbeitungsleistung';

  @override
  String arithmancerEnemyAttack(int damage) {
    return 'KI-Gegenangriff verursacht $damage Schaden!';
  }

  @override
  String get arithmancerPropertyPrime => 'Primzahl';

  @override
  String get arithmancerPropertySquare => 'Quadratzahl';

  @override
  String get arithmeticSquareOutOfMoves => 'Alle Züge verbraucht!';

  @override
  String get arithmeticSquareOutOfMovesDesc =>
      'Überlege dir jeden Zug genau, um das Rätsel zu lösen!';

  @override
  String get arithmancerPropertyFibonacci => 'Fibonacci';

  @override
  String get arithmancerPropertyEven => 'Gerade';

  @override
  String get arithmancerPropertyOdd => 'Ungerade';

  @override
  String get arithmancerPropertyPowerOfTwo => 'Zweierpotenz';

  @override
  String get arithmancerShieldPrime => 'Primzahl-Schild';

  @override
  String get arithmancerShieldEven => 'Gerade-Absorber';

  @override
  String get arithmancerShieldOdd => 'Ungerade-Schwäche';

  @override
  String get arithmancerShieldSquare => 'Quadrat-Immunität';

  @override
  String get arithmancerShieldFibonacci => 'Fibonacci-Sperre';

  @override
  String get arithmancerShieldPowerOfTwo => 'Binär-Festung';

  @override
  String get arithmancerVictoryTitle => 'Neural-Durchbruch erfolgreich!';

  @override
  String arithmancerVictoryDesc(int score) {
    return 'Schurkische KI neutralisiert! Du hast $score Daten-Credits für die Wiederherstellung dieses Netzwerkknotens erhalten.';
  }

  @override
  String get arithmancerDefeatTitle => 'System kompromittiert';

  @override
  String get arithmancerDefeatDesc =>
      'Die schurkische KI hat deine Verteidigung überwältigt. Analysiere Angriffsmuster für den nächsten Versuch...';

  @override
  String get arithmancerNextChallenge => 'Neues Ziel angreifen';

  @override
  String get arithmancerTryAgain => 'Infiltration wiederholen';

  @override
  String get arithmancerReturnToBridge => 'Zur Brücke zurück';

  @override
  String get arithmancerGameModeNeuralBreach => 'NEURAL-DURCHBRUCH';

  @override
  String get arithmancerGameModeAiDuel => 'KI-KAMPF-DUELL';

  @override
  String get arithmancerGameModeNeuralLadder => 'NEURAL-LEITER';

  @override
  String get arithmancerDeck => 'STAPEL';

  @override
  String get arithmancerUsed => 'BENUTZT';

  @override
  String get arithmancerOpponentProcessing => 'GEGNER VERARBEITET...';

  @override
  String get arithmancerBonusPrime => 'PRIMZAHL';

  @override
  String get arithmancerBonusSquare => 'QUADRAT';

  @override
  String get arithmancerBonusFibonacci => 'FIBONACCI';

  @override
  String get arithmancerBonusBinary => 'BINÄR';

  @override
  String get arithmancerInstructionsGeneral =>
      'Erstelle mathematische Ausdrücke um Schaden zu verursachen';

  @override
  String arithmancerInstructionsAiPlayer(String aiName) {
    return 'Besiege $aiName mit cleverer Mathematik';
  }

  @override
  String get arithmancerInstructionsPrimeShield =>
      'Verwende Primzahlen um den Primzahl-Schild zu durchbrechen';

  @override
  String get arithmancerInstructionsSquareImmune =>
      'Vermeide Quadratzahlen - dieser Gegner ist immun';

  @override
  String get arithmancerInstructionsFibonacciOnly =>
      'Nur Fibonacci-Zahlen können Schaden verursachen';

  @override
  String get arithmancerInstructionsPowerOfTwoOnly =>
      'Nur Zweierpotenzen durchdringen diese Verteidigung';

  @override
  String get arithmancerLadderProgressTitle => 'Leiter-Fortschritt';

  @override
  String arithmancerLadderProgressDesc(int step, int total) {
    return 'Stufe $step von $total abgeschlossen! Klettere weiter die neurale Leiter hinauf.';
  }

  @override
  String get arithmancerLadderContinue => 'Leiter fortsetzen';

  @override
  String get arithmancerLadderChampionTitle => 'Leiter-Champion!';

  @override
  String arithmancerLadderChampionDesc(int score) {
    return 'Glückwunsch! Du hast die gesamte neurale Leiter erobert und $score Punkte verdient!';
  }

  @override
  String get arithmancerTurnSkipped =>
      'Zug übersprungen - Energie für nächste Runde gespeichert';

  @override
  String get arithmancerGameplayGuide => 'Gameplay-Leitfaden';

  @override
  String get arithmancerGuideBasics =>
      '• Ziehe Karten aus deiner Hand in das Schlachtfeld um mathematische Ausdrücke zu erstellen\n• Klicke \'Ausführen\' um Schaden basierend auf dem Ergebnis zu verursachen';

  @override
  String get arithmancerGuideCards =>
      '• Zahlenkarten (grün): Liefern Werte\n• Operatorkarten (gelb): +, -, ×, ÷\n• Klammerkarten (rosa): Teile in ( und ) für Reihenfolge';

  @override
  String get arithmancerGuideCombat =>
      '• Jede Karte kostet Energie zum Spielen\n• Höhere Zahlen verursachen mehr Schaden\n• Negative Ergebnisse gewähren Schild-Punkte';

  @override
  String get arithmancerGuideProperties =>
      '• Primzahlen: 3× Schaden\n• Quadratzahlen: 2× Schaden\n• Fibonacci: 1.7× Schaden\n• Zweierpotenzen: 1.6× Schaden';

  @override
  String get arithmancerGuideShields =>
      '• Gegner haben verschiedene mathematische Schilde\n• Einige blockieren spezifische Zahlentypen\n• Beobachte Feind-Beschreibungen für Hinweise';

  @override
  String get arithmancerGuideDiscard =>
      '• Ziehe ungewollte Karten auf den BENUTZT-Stapel rechts\n• Verwende dies um deine Hand zu verwalten';

  @override
  String get arithmancerGuideSkip =>
      '• Klicke den Überspringen-Button um deinen Zug zu beenden\n• Deine Energie wird für die nächste Runde verdoppelt';

  @override
  String get arithmancerModeSelectionSubtitle => 'Wähle dein Kampfprotokoll';

  @override
  String get arithmancerModeNeuralBreachDesc =>
      'Bekämpfe feindliche KI-Programme in Sequenz';

  @override
  String get arithmancerModeAiDuelDesc =>
      'Kämpfe gegen fortgeschrittene KI-Persönlichkeiten';

  @override
  String get arithmancerModeNeuralLadderDesc =>
      'Klettere durch gemischte Programm- und KI-Herausforderungen';

  @override
  String get arithmeticSquare => 'Rechenquadrat';

  @override
  String get arithmeticSquareInstructions =>
      'Fülle die leeren Felder aus, damit jede Zeile und Spalte gültige Gleichungen bildet!';

  @override
  String get arithmeticSquareError =>
      'Einige Gleichungen stimmen nicht! Überprüfe deine Zahlen und versuche es erneut.';

  @override
  String get arithmeticSquareSelectNumbers =>
      'Ziehe Zahlen in die leeren Felder:';

  @override
  String get arithmeticSquareWinTitle => 'Mathematische Meisterschaft!';

  @override
  String arithmeticSquareWinDesc(int bonusScore) {
    return 'Ausgezeichnet! Du hast das Rechenquadrat gelöst und $bonusScore Bonuspunkte für deine mathematische Präzision erhalten!';
  }

  @override
  String get arithmancerCrosswords => 'Arithmancer Kreuzworträtsel';

  @override
  String get arithmancerCrosswordsInstructions =>
      'Löse die sich kreuzenden Mathe-Gleichungen, indem du Zahlen in das Kreuzworträtsel-Gitter einsetzt!';

  @override
  String get arithmancerCrosswordsError =>
      'Die Kreuzworträtsel-Gleichungen stimmen nicht! Überprüfe deine Mathematik und versuche es erneut.';

  @override
  String get arithmancerCrosswordsOutOfMoves => 'Alle Züge verbraucht.';

  @override
  String get arithmancerCrosswordsOutOfMovesDesc =>
      'Plane deine Züge genau, um das Rätsel zu lösen!';

  @override
  String get arithmancerCrosswordsSelectNumbers =>
      'Ziehe Zahlen zum Ausfüllen des Kreuzworträtsels:';

  @override
  String get arithmancerCrosswordsWinTitle => 'Kreuzworträtsel-Champion!';

  @override
  String arithmancerCrosswordsWinDesc(int bonusScore) {
    return 'Brillant! Du hast das mathematische Kreuzworträtsel gemeistert und $bonusScore Bonuspunkte für deine arithmantische Meisterschaft erhalten!';
  }

  @override
  String get kenken => 'KenKen';

  @override
  String get kenkenInstructions =>
      'Fülle das Gitter so, dass jede Zeile und Spalte jede Zahl genau einmal enthält. Zahlen in Käfigen müssen den mathematischen Hinweis erfüllen.';

  @override
  String get kenkenError =>
      'Hoppla! Die Lösung erfüllt nicht alle Bedingungen. Überprüfe die Käfig-Mathematik und die Lateinisches-Quadrat-Regeln!';

  @override
  String get kenkenSelectNumbers => 'Ziehe Zahlen um das Gitter zu füllen:';

  @override
  String get kenkenWinTitle => 'Mathematische Meisterschaft!';

  @override
  String kenkenWinDesc(int bonusScore) {
    return 'Unglaubliches logisches Denken! Du hast dieses KenKen-Rätsel perfekt gelöst und $bonusScore Bonuspunkte für deine mathematischen Fähigkeiten erhalten!';
  }

  @override
  String get asteroidFieldTitle => 'Asteroiden-Navigator';

  @override
  String get asteroidFieldInstructions =>
      'Zeige sichere Sektoren auf, vermeide Asteroiden! Langes Drücken oder Flaggen-Modus zum Markieren von Gefahren.';

  @override
  String get asteroidFieldRevealMode => 'Aufdeckmodus';

  @override
  String get asteroidFieldFlagMode => 'Flaggenmodus';

  @override
  String get asteroidFieldWinTitle => 'Feld geräumt!';

  @override
  String asteroidFieldWinDesc(
      String time, int score, int speedBonus, int efficiencyBonus) {
    return 'Navigation abgeschlossen in $time!\n\nGesamtpunktzahl: $score\nGeschwindigkeitsbonus: +$speedBonus\nEffizienzbonus: +$efficiencyBonus';
  }

  @override
  String get asteroidFieldLoseTitle => 'Asteroiden-Einschlag!';

  @override
  String get asteroidFieldLoseDesc =>
      'Dein Schiff hat einen Asteroiden getroffen. Das Feld wurde aufgedeckt.';

  @override
  String get nextField => 'Nächstes Feld';

  @override
  String get cargoBayTitle => 'Frachtraum-Organisator';

  @override
  String get cargoBayInstructions =>
      'Sortiere das Frachtgut und beachte dabei die Zahlenverhältnisse!';

  @override
  String get cargoBayNext => 'Nächste';

  @override
  String get cargoBayHold => 'Halten';

  @override
  String get cargoBayPressC => 'Drücke C';

  @override
  String get cargoBayBonuses => 'Boni';

  @override
  String get cargoBayKeyboardHints =>
      'Pfeiltasten: Bewegen | ↑: Drehen | Leertaste: Fallen | C: Halten';

  @override
  String get cargoBayWinTitle => 'Mission erfolgreich!';

  @override
  String cargoBayWinDesc(int rows, int score, int rowBonus) {
    return 'Perfekt! $rows Reihen geräumt!\n\nPunktzahl: $score\nBoni-Bonus: +$rowBonus';
  }

  @override
  String get cargoBayLoseTitle => 'Frachtraum überlastet!';

  @override
  String get cargoBayLoseDesc =>
      'Der Frachtraum ist voll!\nVersuche es erneut!';

  @override
  String get nextShipment => 'Nächste Ladung';

  @override
  String get bonusTargetSum => 'Zielsumme';

  @override
  String bonusTargetSumDesc(int target) {
    return 'Volle Reihe/Spalte = $target';
  }

  @override
  String get bonusFibonacciTitle => 'Fibonacci';

  @override
  String get bonusDoublingTitle => 'Verdopplung';

  @override
  String get bonusConsecutiveTitle => 'Aufsteigend';

  @override
  String get bonusSquareTitle => 'Quadrat-Summe';

  @override
  String get moleculeBuilderTitle => 'Molekül-Labor';

  @override
  String get moleculeBuilderInstructions =>
      'Schiebe Atome zum Zielmolekül! Atome gleiten bis zu einer Wand oder einem anderen Atom.';

  @override
  String get moleculeBuilderMoves => 'Züge';

  @override
  String get moleculeBuilderAtoms => 'Atome';

  @override
  String get moleculeBuilderTarget => 'Ziel';

  @override
  String get moleculeBuilderSelected => 'Ausgewählt';

  @override
  String get moleculeBuilderNone => 'Keins';

  @override
  String get moleculeBuilderPrevious => 'Zurück';

  @override
  String get moleculeBuilderNext => 'Weiter';

  @override
  String get moleculeBuilderRestart => 'Neustart';

  @override
  String get moleculeBuilderLevel => 'Level';

  @override
  String get moleculeBuilderWinTitle => 'Molekül zusammengebaut!';

  @override
  String moleculeBuilderWinDesc(int moves, int score, int efficiencyBonus) {
    return 'Gelöst in $moves Zügen\nPunktzahl: $score (+$efficiencyBonus Bonus)';
  }

  @override
  String get moleculeBuilderLoseTitle => 'Züge aufgebraucht!';

  @override
  String get moleculeBuilderLoseDesc =>
      'Zuglimit überschritten! Die Molekülstruktur bleibt unvollständig.\nStudiere das Muster und versuche es erneut, Wissenschaftler!';

  @override
  String get moleculeBuilderNextMolecule => 'Nächstes Molekül';

  @override
  String get moleculeBuilderUndo => 'Zurück';

  @override
  String get moleculeBuilderHelp => 'Hilfe / Anleitung';

  @override
  String get moleculeBuilderInfoTitle => 'Spielanleitung';

  @override
  String get moleculeBuilderInfoGoal =>
      'Ziel: Ordne die losen Atome auf dem Gitter an, um die links gezeigte Zielmolekülstruktur perfekt nachzubilden.';

  @override
  String get moleculeBuilderInfoHowTo =>
      'Spielanleitung: Tippe ein Atom an, um es auszuwählen. Benutze dann die Pfeiltasten oder wische über das Atom, um es zu verschieben. Atome gleiten geradlinig, bis sie auf eine Wand oder ein anderes Atom treffen.';

  @override
  String get moleculeBuilderInfoMoves =>
      'Züge: Jede Verschiebung kostet einen Zug. Versuche, das Molekül zu bauen, bevor dir die Züge ausgehen!';

  @override
  String get moleculeBuilderInfoUndo =>
      'Rückgängig: Die \'Rückgängig\'-Schaltfläche macht deinen letzten Zug rückgängig, kostet aber als Strafe 2 Züge.';

  @override
  String get level01Label => 'Wasser';

  @override
  String get level02Label => 'Methan';

  @override
  String get level03Label => 'Methanol';

  @override
  String get level04Label => 'Ethylen';

  @override
  String get level05Label => 'Propen';

  @override
  String get level06Label => 'Bonus-Sektion 1';

  @override
  String get level07Label => 'Ethanol';

  @override
  String get level08Label => 'Isopropanol';

  @override
  String get level09Label => 'Ethanal';

  @override
  String get level10Label => 'Aceton';

  @override
  String get level11Label => 'Ameisensäure';

  @override
  String get level12Label => 'Bonus-Sektion 2';

  @override
  String get level13Label => 'Essigsäure';

  @override
  String get level14Label => 'trans-Buten';

  @override
  String get level15Label => 'cis-Buten';

  @override
  String get level16Label => 'Dimethylether';

  @override
  String get level17Label => 'Butanol';

  @override
  String get level18Label => 'Bonus-Sektion 3';

  @override
  String get level19Label => '2-Methyl-2-Propanol';

  @override
  String get level20Label => 'Glycerin';

  @override
  String get level21Label => 'Polytetrafluorethylen';

  @override
  String get level22Label => 'Oxalsäure';

  @override
  String get level23Label => 'Formaldehyd';

  @override
  String get level24Label => 'Bonus-Sektion 4';

  @override
  String get level25Label => 'Essigsäureethylester';

  @override
  String get level26Label => 'Ammoniak';

  @override
  String get level27Label => '3-Methylpentan';

  @override
  String get level28Label => 'Propanal';

  @override
  String get level29Label => 'Propin';

  @override
  String get level30Label => 'Bonus-Sektion 5';

  @override
  String get atomNameHydrogen => 'Wasserstoff';

  @override
  String get atomNameOxygen => 'Sauerstoff';

  @override
  String get atomNameCarbon => 'Kohlenstoff';

  @override
  String get atomNameNitrogen => 'Stickstoff';

  @override
  String get atomNameSulfur => 'Schwefel';

  @override
  String get atomNameFluorine => 'Fluor';

  @override
  String get atomNameSpecial => 'Spezial';

  @override
  String get moleculeBuilderMoleculeInfo => 'Molekül-Info';

  @override
  String get moleculeBuilderBonusTitle => 'Bonus-Ziel';

  @override
  String get moleculeInfoNomenclature => 'Nomenklatur & Beschreibung';

  @override
  String get moleculeInfoKeyFacts => 'Wichtige Fakten';

  @override
  String get moleculeInfoInSpace => 'Im Weltraum';

  @override
  String get level01Desc =>
      'Wasser (H₂O) ist eine anorganische Verbindung, die für alle bekannten Lebensformen essentiell ist. Bei Standardtemperatur ist es eine geschmacks- und geruchlose Flüssigkeit und wird wegen seiner Fähigkeit, viele Stoffe zu lösen, als \'universelles Lösungsmittel\' bezeichnet.';

  @override
  String get level01Facts =>
      '• Besteht aus zwei Wasserstoffatomen, die kovalent an ein Sauerstoffatom gebunden sind.\n• Aufgrund seiner Polarität bildet es starke Wasserstoffbrückenbindungen, was zu einem hohen Siedepunkt und hoher Oberflächenspannung führt.\n• Eis hat eine geringere Dichte als flüssiges Wasser, eine seltene Eigenschaft, die Wasserlebewesen unter gefrorenen Oberflächen überleben lässt.';

  @override
  String get level01Space =>
      'Wasser ist in interstellaren Wolken, auf Kometen und auf Eismonden wie Europa reichlich vorhanden. Im Vakuum des Weltraums kann flüssiges Wasser nicht existieren; es gefriert entweder zu Eis oder verdampft. Auf dem Mars führt der niedrige atmosphärische Druck dazu, dass Wasser knapp über 0°C siedet.';

  @override
  String get level02Desc =>
      'Methan (CH₄) ist das einfachste Alkan und der Hauptbestandteil von Erdgas. Es ist ein farb- und geruchloses Gas und ein starkes Treibhausgas.';

  @override
  String get level02Facts =>
      '• Besitzt ein zentrales Kohlenstoffatom, das an vier Wasserstoffatome in einer tetraedrischen Geometrie gebunden ist.\n• Wird von anaeroben Bakterien in Umgebungen wie Feuchtgebieten und den Verdauungstrakten von Wiederkäuern produziert.\n• Eine wichtige Brennstoffquelle und ein Ausgangsstoff für die chemische Industrie.';

  @override
  String get level02Space =>
      'Methan ist in unserem Sonnensystem weit verbreitet. Titan, der größte Mond des Saturns, hat eine dichte Methanatmosphäre mit Flüssen und Seen aus flüssigem Methan auf seiner Oberfläche, wo die Temperatur eisige -179°C beträgt.';

  @override
  String get level03Desc =>
      'Methanol (CH₃OH), oder Holzgeist, ist der einfachste Alkohol. Es ist eine leichte, flüchtige, farblose und brennbare Flüssigkeit mit einem charakteristischen Geruch.';

  @override
  String get level03Facts =>
      '• Besteht aus einer Methylgruppe (-CH₃), die mit einer Hydroxylgruppe (-OH) verbunden ist.\n• Bei Einnahme ist es hochgiftig und wird als Lösungsmittel, Frostschutzmittel und in der chemischen Synthese verwendet.\n• Ein wichtiger Treibstoff in einigen Spezialmotoren.';

  @override
  String get level03Space =>
      'Riesige Wolken aus Methanol existieren in sternbildenden Regionen der Milchstraße. Es bildet sich auf der Oberfläche von eisigen Staubkörnern und gilt als wichtiger Baustein für komplexere organische Moleküle im Weltraum.';

  @override
  String get level04Desc =>
      'Ethylen (C₂H₄), oder Ethen, ist das einfachste Alken, gekennzeichnet durch eine Kohlenstoff-Kohlenstoff-Doppelbindung. Es ist ein farbloses, brennbares Gas mit einem schwach süßlichen Geruch.';

  @override
  String get level04Facts =>
      '• Die weltweit am meisten produzierte organische Verbindung, hauptsächlich zur Herstellung von Polyethylen-Kunststoff.\n• Wirkt als natürliches Pflanzenhormon und reguliert Prozesse wie Fruchtreifung, Blütenöffnung und Blattabwurf.\n• Die Doppelbindung macht es wesentlich reaktiver als Ethan.';

  @override
  String get level04Space =>
      'Ethylen kommt in den Atmosphären von Gasriesen wie Jupiter und Saturn vor. Auf dem Titan zerlegt Sonnenlicht Methan in komplexere Kohlenwasserstoffe, einschließlich Ethylen, was zum orangefarbenen Dunst des Mondes beiträgt.';

  @override
  String get level05Desc =>
      'Propen (C₃H₆), oder Propylen, ist ein Alken mit drei Kohlenstoffatomen und einer Doppelbindung. Es ist ein farbloses Gas mit einem schwachen, erdölähnlichen Geruch.';

  @override
  String get level05Facts =>
      '• Ein wichtiger Ausgangsstoff in der petrochemischen Industrie, nach Ethylen an zweiter Stelle.\n• Hauptsächlich zur Herstellung von Polypropylen verwendet, einem vielseitigen Kunststoff für Verpackungen, Textilien und Autoteile.\n• Wird durch Dampfspaltung von Kohlenwasserstoffen hergestellt.';

  @override
  String get level05Space =>
      'Die NASA-Sonde Cassini hat Propen auf dem Saturnmond Titan nachgewiesen. Seine Anwesenheit hilft Wissenschaftlern, die komplexe Atmosphärenchemie auf methanreichen Welten zu modellieren und zu verstehen, wie Bausteine des Lebens entstehen könnten.';

  @override
  String get level07Desc =>
      'Ethanol (C₂H₅OH), oder Trinkalkohol, ist der Alkohol, der in alkoholischen Getränken enthalten ist. Es ist eine flüchtige, brennbare, farblose Flüssigkeit, die durch die Gärung von Zucker hergestellt wird.';

  @override
  String get level07Facts =>
      '• Besteht aus einer Ethylgruppe (-C₂H₅), die an eine Hydroxylgruppe (-OH) gebunden ist.\n• Weit verbreitet als Lösungsmittel, Antiseptikum und als erneuerbarer Biokraftstoff zur Ergänzung von Benzin.\n• Es ist ein Depressivum des Zentralnervensystems.';

  @override
  String get level07Space =>
      'Gigantische, Milliarden Kilometer breite Ethanolwolken wurden im interstellaren Raum entdeckt. Diese kosmischen Spirituosen bilden sich auf Staubkörnern und sind nicht trinkbar! Auf dem Mars würde der niedrige Druck Ethanol bereits bei 10°C zum Sieden bringen.';

  @override
  String get level08Desc =>
      'Isopropanol ((CH₃)₂CHOH), oder Isopropylalkohol, ist ein gängiges Desinfektions- und Reinigungsmittel, weithin als Reinigungsalkohol bekannt. Es ist ein Isomer von Propanol.';

  @override
  String get level08Facts =>
      '• Die Hydroxylgruppe (-OH) ist am mittleren Kohlenstoffatom der Dreikohlenstoffkette angebracht.\n• Seine Fähigkeit, Öle zu lösen, und seine schnelle Verdunstung machen es zu einem wirksamen Reiniger für Elektronik und zu einem Enteisungsmittel.\n• Die Einnahme ist giftig.';

  @override
  String get level08Space =>
      'Isopropanol wurde eindeutig in einer sternbildenden Wolke nahe dem Zentrum unserer Galaxie, Sagittarius B2, nachgewiesen. Es ist der größte bisher gefundene Alkohol mit einer verzweigten Struktur, was Hinweise darauf gibt, wie komplexe organische Moleküle zwischen Sternen entstehen.';

  @override
  String get level09Desc =>
      'Ethanal (CH₃CHO), allgemein als Acetaldehyd bekannt, ist eine reaktive, farblose Flüssigkeit mit einem stechenden, fruchtigen Geruch. Es ist ein wichtiges Zwischenprodukt in der organischen Synthese und im Stoffwechsel.';

  @override
  String get level09Facts =>
      '• Kommt natürlich in Kaffee, Brot und reifen Früchten vor.\n• Im menschlichen Körper ist es ein Zwischenprodukt beim Abbau von Ethanol und eine Hauptursache für Katersymptome.\n• Wird zur Herstellung von Essigsäure, Parfums und Farbstoffen verwendet.';

  @override
  String get level09Space =>
      'Acetaldehyd findet sich in Kometen und interstellaren Molekülwolken. Es gilt als wichtiges präbiotisches Molekül, da es unter weltraumähnlichen Bedingungen zu Aminosäuren wie Alanin reagieren kann, was darauf hindeutet, dass die Bausteine des Lebens einen außerirdischen Ursprung haben könnten.';

  @override
  String get level10Desc =>
      'Aceton (CH₃COCH₃), oder Propanon, ist das einfachste Keton. Es ist eine farblose, flüchtige und brennbare Flüssigkeit mit einem charakteristischen süßlich-stechenden Geruch. Es ist ein gängiges Lösungsmittel, berühmt für seine Verwendung in Nagellackentfernern.';

  @override
  String get level10Facts =>
      '• Besitzt eine zentrale Carbonylgruppe (C=O), die an zwei Methylgruppen gebunden ist.\n• Ist mit Wasser mischbar und dient als wichtiges Reinigungsmittel im Labor und in der Industrie.\n• Der menschliche Körper produziert auf natürliche Weise geringe Mengen Aceton während des Stoffwechsels.';

  @override
  String get level10Space =>
      'Aceton wurde von der Raumsonde Rosetta in der Gaswolke um den Kometen 67P nachgewiesen. Seine Anwesenheit auf Kometen stützt die Theorie, dass diese \'schmutzigen Schneebälle\' einen Cocktail aus komplexen organischen Molekülen auf die frühe Erde gebracht haben könnten.';

  @override
  String get level11Desc =>
      'Ameisensäure (HCOOH) ist die einfachste Carbonsäure. Es ist eine farblose Flüssigkeit mit einem stechenden, durchdringenden Geruch. Sie kommt natürlich im Gift von Ameisen und Bienen vor.';

  @override
  String get level11Facts =>
      '• Ihr Name leitet sich vom lateinischen Wort für Ameise, \'formica\', ab, da sie erstmals aus Ameisenkörpern isoliert wurde.\n• Wird als Konservierungs- und antibakterielles Mittel in Tierfutter verwendet.\n• Sie ist ätzend und reizt die Haut.';

  @override
  String get level11Space =>
      'Ameisensäure ist in interstellaren Wolken reichlich vorhanden und wurde in Kometen beobachtet. Sie ist ein Schlüsselmolekül für Astrochemiker, da sie die Carboxylgruppe (-COOH) enthält, die das entscheidende Merkmal aller Aminosäuren, den Bausteinen von Proteinen, ist.';

  @override
  String get level13Desc =>
      'Essigsäure (CH₃COOH) ist eine Carbonsäure, die Essig seinen sauren Geschmack und stechenden Geruch verleiht. In ihrer reinen, wasserfreien Form wird sie Eisessig genannt.';

  @override
  String get level13Facts =>
      '• Besteht aus einer Methylgruppe, die an eine Carboxylgruppe gebunden ist.\n• Ein grundlegendes chemisches Reagenz und eine Industriechemikalie, die bei der Herstellung von Kunststoffen, Fotofilmen und Textilien verwendet wird.\n• Als schwache Säure wird sie als Lebensmittelzusatzstoff (E260) zur Säureregulierung eingesetzt.';

  @override
  String get level13Space =>
      'Essigsäure wurde in den heißen molekularen Kernen von sternbildenden Regionen wie Sagittarius B2 nachgewiesen. Ihre Anwesenheit deutet darauf hin, dass die Chemie in diesen stellaren Kinderstuben komplex genug ist, um die Schlüsselkomponenten der Biochemie zu bilden.';

  @override
  String get level14Desc =>
      'trans-Buten ist ein Isomer von Buten (C₄H₈), bei dem die Hauptkohlenstoffketten auf gegenüberliegenden Seiten der Kohlenstoff-Kohlenstoff-Doppelbindung liegen. Diese \'trans\'-Konfiguration macht es stabiler als sein cis-Isomer.';

  @override
  String get level14Facts =>
      '• Die starre Doppelbindung verhindert eine Rotation und erzeugt unterschiedliche geometrische Isomere.\n• Es ist bei Raumtemperatur ein farbloses, brennbares Gas.\n• Wird bei der Herstellung von synthetischem Kautschuk und anderen Chemikalien verwendet.';

  @override
  String get level14Space =>
      'Das relative Vorkommen von cis- und trans-Isomeren im Weltraum kann Astronomen Aufschluss über die Bedingungen geben, unter denen sie sich gebildet haben. Eine Hochtemperatur-Gasphasenreaktion könnte ein anderes Isomerenverhältnis erzeugen als eine Niedertemperaturreaktion auf der Oberfläche eines Eiskorns.';

  @override
  String get level15Desc =>
      'cis-Buten ist ein Isomer von Buten (C₄H₈), bei dem die Hauptkohlenstoffketten auf der gleichen Seite der Kohlenstoff-Kohlenstoff-Doppelbindung liegen. Diese Konfiguration ist aufgrund sterischer Hinderung weniger stabil als das trans-Isomer.';

  @override
  String get level15Facts =>
      '• Hat aufgrund eines kleinen molekularen Dipolmoments einen etwas höheren Siedepunkt als sein trans-Isomer.\n• Die cis-trans-Isomerie ist in der Biologie von entscheidender Bedeutung, insbesondere bei der Funktion von Fettsäuren und im Sehvorgang (Retinal).';

  @override
  String get level15Space =>
      'Der Nachweis spezifischer Isomere wie cis-Buten im Weltraum ist eine große Herausforderung für die Radioastronomie. Ein bestätigter Nachweis könnte tiefe Einblicke in die physikalischen und chemischen Prozesse in protoplanetaren Scheiben geben, wo neue Planeten geboren werden.';

  @override
  String get level16Desc =>
      'Dimethylether (CH₃OCH₃) ist der einfachste Ether. Es ist ein farbloses Gas, das ein Isomer von Ethanol ist, aber aufgrund fehlender Wasserstoffbrückenbindungen sehr unterschiedliche Eigenschaften hat.';

  @override
  String get level16Facts =>
      '• Es wird als sauber verbrennender Alternativkraftstoff für Dieselmotoren entwickelt, da es sehr geringe Emissionen von Partikeln und Stickoxiden erzeugt.\n• Wird als Treibmittel in Aerosolspraydosen verwendet und ersetzt FCKW.\n• Kann aus Erdgas, Kohle oder Biomasse hergestellt werden.';

  @override
  String get level16Space =>
      'Dimethylether ist eines der am häufigsten vorkommenden großen organischen Moleküle, die in sternbildenden Wolken gefunden werden. Er dient Astronomen als entscheidender chemischer Indikator, der ihnen hilft, die Temperatur und Dichte der Regionen zu bestimmen, in denen Sterne und Planeten entstehen.';

  @override
  String get level17Desc =>
      'Butanol (C₄H₉OH) ist ein Vier-Kohlenstoff-Alkohol mit mehreren Isomeren. Butan-1-ol, hier gezeigt, ist ein primärer Alkohol mit einem bananenartigen Geruch. Es wird als Lösungsmittel verwendet und als Biokraftstoff erforscht.';

  @override
  String get level17Facts =>
      '• Als Biokraftstoff (\'Biobutanol\') hat es eine höhere Energiedichte als Ethanol und ist weniger korrosiv, was es zu einer attraktiveren Benzin-Alternative macht.\n• Wird in einer Vielzahl von Anwendungen eingesetzt, einschließlich als künstliches Aroma in Lebensmitteln und als Zutat in Parfums.\n• Zu seinen Isomeren gehören Isobutanol und tert-Butanol.';

  @override
  String get level17Space =>
      'Komplexe Alkohole, die größer als Propanol sind, wurden im interstellaren Raum noch nicht eindeutig nachgewiesen. Die Suche nach Butanol dauert an, da seine Entdeckung die Grenzen der bekannten interstellaren Chemie erweitern und bestätigen würde, dass auch größere, komplexere organische Strukturen zwischen den Sternen entstehen können.';

  @override
  String get level19Desc =>
      '2-Methyl-2-Propanol ((CH₃)₃COH), auch als tert-Butanol bekannt, ist der einfachste tertiäre Alkohol. Es ist bei Raumtemperatur ein farbloser Feststoff, der leicht schmilzt und einen kampferartigen Geruch hat.';

  @override
  String get level19Facts =>
      '• Das \'tert\' (tertiär) bezieht sich darauf, dass der zentrale Kohlenstoff an drei andere Kohlenstoffatome gebunden ist.\n• Wird als Lösungsmittel, als Vergällungsmittel für Ethanol und als Oktanzahl-Booster für Benzin verwendet.\n• Seine sperrige Form verhindert, dass es auf die gleiche Weise wie andere Butanol-Isomere reagiert.';

  @override
  String get level19Space =>
      'Einen verzweigten tertiären Alkohol wie diesen im Weltraum nachzuweisen, wäre eine monumentale Entdeckung. Es würde beweisen, dass nicht nur lange Ketten, sondern auch komplexe, verzweigte Strukturen in der rauen Umgebung interstellarer Wolken synthetisiert werden können, was das Inventar präbiotischer Moleküle erweitert.';

  @override
  String get level20Desc =>
      'Glycerin (C₃H₈O₃), oder Glycerol, ist eine einfache Polyolverbindung. Es ist eine farblose, geruchlose, viskose und süß schmeckende Flüssigkeit. Es ist ungiftig und bildet das Rückgrat aller Triglyceride (Fette).';

  @override
  String get level20Facts =>
      '• Die drei Hydroxylgruppen (-OH) machen es sehr gut wasserlöslich und hygroskopisch (es zieht Wassermoleküle an und hält sie fest).\n• Weit verbreitet in Lebensmitteln als Süßstoff, in Arzneimitteln und in Körperpflegeprodukten wie Seife und Feuchtigkeitscremes.\n• Ein natürliches Frostschutzmittel bei einigen arktischen und alpinen Insekten.';

  @override
  String get level20Space =>
      'Glycerin ist ein Schlüsselmolekül bei der Suche nach außerirdischem Leben. Seine Fähigkeit, als Lösungsmittel zu wirken und den Gefrierpunkt von Wasser zu senken, könnte Flüssigkeiten auf ansonsten gefrorenen Welten stabil halten und potenziell bewohnbare Umgebungen auf Eismonden oder Exoplaneten schaffen.';

  @override
  String get level21Desc =>
      'Polytetrafluorethylen ((C₂F₄)n), oder PTFE, ist ein synthetisches Polymer, das am besten unter dem Markennamen Teflon bekannt ist. Das Bild zeigt sein Monomer, Tetrafluorethylen.';

  @override
  String get level21Facts =>
      '• Es hat einen der niedrigsten Reibungskoeffizienten aller Feststoffe, was es extrem antihaftbeschichtet macht.\n• Sehr beständig gegen chemische Angriffe und stabil über einen weiten Temperaturbereich.\n• Wird in antihaftbeschichtetem Kochgeschirr, Rohrauskleidungen und medizinischen Geräten verwendet.';

  @override
  String get level21Space =>
      'Fluor ist im Kosmos ein relativ seltenes Element. Obwohl nicht erwartet wird, dass sich komplexe Fluorpolymere auf natürliche Weise im Weltraum bilden, machen die unglaubliche Haltbarkeit und die reibungsarmen Eigenschaften von PTFE es zu einem wichtigen Material für die Raumfahrt, das von Raumanzügen bis zu Rover-Komponenten verwendet wird.';

  @override
  String get level22Desc =>
      'Oxalsäure ((COOH)₂) ist die einfachste Dicarbonsäure. Sie ist ein farbloser kristalliner Feststoff, der sich in Wasser zu einer farblosen Lösung auflöst. Sie ist eine viel stärkere Säure als Essigsäure.';

  @override
  String get level22Facts =>
      '• Kommt natürlich in vielen Pflanzen vor, einschließlich Blattgemüse (wie Spinat), Gemüse, Obst und Nüssen.\n• Sie bindet sich mit Mineralien wie Kalzium zu Kristallen, die der Hauptbestandteil der häufigsten Art von Nierensteinen sind.\n• Wird als Reinigungs- und Bleichmittel verwendet, insbesondere zur Entfernung von Rost.';

  @override
  String get level22Space =>
      'Auf dem Mars haben Instrumente an Bord von Rovern Mineralien entdeckt, die mit Oxalaten in Verbindung gebracht werden könnten. Die Anwesenheit dieser Salze deutet darauf hin, dass auf dem Roten Planeten Wasser und organische Chemie stattgefunden haben, was Hinweise auf seine frühere Bewohnbarkeit liefert.';

  @override
  String get level23Desc =>
      'Formaldehyd (CH₂O), oder Methanal, ist das einfachste Aldehyd. Es ist ein farbloses Gas mit einem charakteristischen stechenden, reizenden Geruch. Es ist ein entscheidender Vorläufer für viele andere chemische Verbindungen.';

  @override
  String get level23Facts =>
      '• Wird bei der Herstellung von Industrieharzen verwendet, z. B. für Spanplatten und Beschichtungen.\n• Ein wichtiges Konservierungs- und Desinfektionsmittel, obwohl seine Verwendung aufgrund seiner Karzinogenität heute eingeschränkt ist.\n• Es ist ein Verbrennungsprodukt und kommt im Tabakrauch vor.';

  @override
  String get level23Space =>
      'Formaldehyd ist ein Eckpfeiler der Astrochemie. Es war eines der ersten organischen Moleküle, das im interstellaren Medium nachgewiesen wurde. Es bildet sich leicht auf kosmischen Eiskörnern und gilt als Ausgangspunkt für die Synthese komplexerer Moleküle, einschließlich Zuckern wie Ribose, einem Bestandteil der RNA.';

  @override
  String get level25Desc =>
      'Essigsäureethylester (CH₃COOC₂H₅), oder Ethylacetat, ist ein gängiger Ester. Es ist eine farblose Flüssigkeit mit einem charakteristischen süßen, fruchtigen Geruch, der an Birnenbonbons oder Nagellackentferner erinnert.';

  @override
  String get level25Facts =>
      '• Es ist ein ausgezeichnetes Lösungsmittel, das in Klebstoffen, Nagellackentfernern und zum Entkoffeinieren von Tee und Kaffee verwendet wird.\n• Wird als künstliches Fruchtaroma in Lebensmitteln, Parfums und Süßigkeiten verwendet.\n• Wird im großen Maßstab als Lösungsmittel hergestellt.';

  @override
  String get level25Space =>
      'Ethylacetat wurde in der Staubwolke im Zentrum der Milchstraße nachgewiesen. Ester sind für viele der angenehmen Gerüche und Geschmäcker verantwortlich, die wir auf der Erde kennen (wie Früchte und Blumen). Ihre Entdeckung im Weltraum deutet darauf hin, dass das Universum ein chemisch reicher Ort ist, der in der Lage ist, die Moleküle zu erzeugen, die wir mit dem Leben verbinden.';

  @override
  String get level26Desc =>
      'Ammoniak (NH₃) ist eine Verbindung aus Stickstoff und Wasserstoff. Es ist ein farbloses Gas mit einem sehr scharfen, stechenden Geruch. Es ist ein grundlegender Baustein für Düngemittel, Kunststoffe und Pharmazeutika.';

  @override
  String get level26Facts =>
      '• Eine der am meisten produzierten anorganischen Chemikalien der Welt, hauptsächlich zur Verwendung in Stickstoffdüngern.\n• Seine Fähigkeit, Wasserstoffbrückenbindungen zu bilden, macht es sehr gut in Wasser löslich.\n• Eine Schlüsselverbindung im Stickstoffkreislauf, die für die Herstellung von Proteinen und Nukleinsäuren unerlässlich ist.';

  @override
  String get level26Space =>
      'Ammoniak ist ein Hauptbestandteil der Atmosphären von Jupiter und Saturn, wo es brillante weiße Wolken aus Ammoniak-Eiskristallen bildet. Es ist auch in Kometen und auf Eismonden fest gefroren. Die Anwesenheit von Ammoniak ist ein wichtiger Indikator für die Verfügbarkeit von Stickstoff für die Chemie auf anderen Welten.';

  @override
  String get level27Desc =>
      '3-Methylpentan (C₆H₁₄) ist ein verzweigtkettiges Alkan und ein Isomer von Hexan. Es ist eine farblose, brennbare Flüssigkeit und ein Bestandteil von Benzin.';

  @override
  String get level27Facts =>
      '• Als verzweigtes Alkan hat es eine höhere Oktanzahl als geradkettiges Hexan, was es zu einer besseren Kraftstoffkomponente zur Verhinderung von Motorklopfen macht.\n• Es wird aus Rohöl raffiniert.\n• Es hat zwei Enantiomere, (3R)-Methylpentan und (3S)-Methylpentan, die Spiegelbilder voneinander sind.';

  @override
  String get level27Space =>
      'Während einfache Alkane wie Methan häufig sind, sind größere verzweigte Alkane im Weltraum schwerer nachzuweisen. Sie werden jedoch in kohligen Chondrit-Meteoriten gefunden. Diese Meteoriten sind unberührte Proben aus dem frühen Sonnensystem und zeigen, dass komplexe organische Chemie, einschließlich der Bildung von Isomeren, aktiv war, als sich die Planeten bildeten.';

  @override
  String get level28Desc =>
      'Propanal (CH₃CH₂CHO) ist ein Drei-Kohlenstoff-Aldehyd. Es ist eine farblose, brennbare Flüssigkeit mit einem fruchtigen, aber erstickenden Geruch. Es ist ein Isomer von Aceton.';

  @override
  String get level28Facts =>
      '• Es wird hauptsächlich als Vorläufer zur Herstellung anderer Chemikalien wie Propanol und verschiedener Harze verwendet.\n• Wie andere Aldehyde ist es aufgrund seiner Carbonylgruppe eine reaktive Verbindung.\n• Es kann durch die Oxidation von Propan-1-ol gebildet werden.';

  @override
  String get level28Space =>
      'Propanal wurde in der sternbildenden Region Sagittarius B2 nachgewiesen. Zusammen mit seinem Isomer Aceton hilft sein Nachweis Astronomen, die chemische Komplexität des interstellaren Mediums zu kartieren und die Bildungswege von Molekülen zu verstehen, die die wichtige Carbonyl-Funktionsgruppe enthalten.';

  @override
  String get level29Desc =>
      'Propin (C₃H₄) ist ein Alkin mit drei Kohlenstoffatomen und einer Kohlenstoff-Kohlenstoff-Dreifachbindung. Es ist ein farbloses, brennbares Gas. Es ist eine praktische, bei Raumtemperatur flüssige Alternative zu Acetylen.';

  @override
  String get level29Facts =>
      '• Die Dreifachbindung macht es sehr reaktiv und nützlich in der organischen Synthese.\n• Es ist ein Bestandteil von MAPP-Gas, einem Brenngas, das beim Schweißen und Löten wegen seiner hohen Flammentemperatur verwendet wird.\n• Es ist ein Isomer von sowohl Propadien als auch Cyclopropen.';

  @override
  String get level29Space =>
      'Propin wurde im interstellaren Medium nachgewiesen, insbesondere in der Atmosphäre des Saturnmondes Titan. Auf Titan zerlegt komplexe Photochemie, angetrieben durch Sonnenlicht, Methan und Stickstoff und erzeugt eine reiche Suppe aus Kohlenwasserstoffen, einschließlich Propin, die zu seinem atmosphärischen Dunst beitragen.';

  @override
  String get spaceGridlockTitle => 'Raumstation-Stau';

  @override
  String get spaceGridlockInstructions =>
      'Ziehe Schiffe, um einen Weg freizumachen! Führe dein Schiff zum Ausgang rechts.';

  @override
  String get spaceGridlockReset => 'Puzzle zurücksetzen';

  @override
  String get spaceGridlockWinTitle => 'Andocken abgeschlossen!';

  @override
  String get spaceGridlockPerfect => 'Perfekt!';

  @override
  String get spaceGridlockGreat => 'Großartig!';

  @override
  String get spaceGridlockGood => 'Gut!';

  @override
  String spaceGridlockWinDesc(
      int moves, int minMoves, String performance, int score, int bonus) {
    return 'Schiff angedockt in $moves Zügen!\nOptimal: $minMoves Züge\nLeistung: $performance\n\nGesamtpunktzahl: $score\nEffizienzbonus: +$bonus';
  }

  @override
  String get nextPuzzle => 'Nächstes Puzzle';

  @override
  String get baseScore => 'Basispunkte';

  @override
  String get efficiencyBonus => 'Effizienzbonus';

  @override
  String get grade => 'Klasse';

  @override
  String get emptyProgram => 'Befehle hierher ziehen';

  @override
  String get undo => 'Zurück';

  @override
  String get run => 'Los!';

  @override
  String get clear => 'Leeren';

  @override
  String get shoot => 'Zerstöre';

  @override
  String get jump => 'Hüpfe';

  @override
  String get robotPathJump => 'Hüpfe';

  @override
  String get robotPathDestroy => 'Zerkleinere';

  @override
  String get robotPathWait => 'Warte';

  @override
  String get robotPathPush => 'Schiebe';

  @override
  String get robotPathPull => 'Ziehe';

  @override
  String get robotPathTooltipWall => 'Mauer';

  @override
  String get robotPathTooltipJumpable => 'Springbare Lücke';

  @override
  String get robotPathTooltipDestructible => 'Zerstörbarer Fels';

  @override
  String get robotPathTooltipMovable => 'Beweglicher Fels';

  @override
  String get robotPathTooltipStart => 'Start';

  @override
  String get robotPathTooltipGoal => 'Ziel';

  @override
  String get robotPathErrorNotDestructible => 'Ziel ist nicht zerstörbar!';

  @override
  String get robotPathErrorNotJumpable => 'Hier kann nicht gesprungen werden!';

  @override
  String get robotPathErrorNotMovable => 'Ziel ist nicht beweglich!';

  @override
  String get robotPathErrorCannotPush =>
      'Schieben fehlgeschlagen! Ziel ist blockiert.';

  @override
  String get robotPathErrorCannotPull =>
      'Ziehen fehlgeschlagen! Nicht genug Platz.';

  @override
  String get robotPathTitle => 'Roboterpfad';

  @override
  String get robotPathDesc =>
      'Programmiere den Roboter, um das Ziel zu erreichen!';

  @override
  String get robotPathError =>
      'Wumms! Der Roboter hat ein Hindernis getroffen.';

  @override
  String get robotPathNotComplete =>
      'Pfad unvollständig. Der Roboter hat das Ziel nicht erreicht.';

  @override
  String get robotPathSuccess => 'Ziel erfasst! Der Roboter ist angekommen.';

  @override
  String get program => 'Programm';

  @override
  String get commands => 'Befehle';

  @override
  String get forward => 'Vorwärts';

  @override
  String get turnLeft => 'Links drehen';

  @override
  String get turnRight => 'Rechts drehen';

  @override
  String get starLoaderGameTitle => 'Frachtlader';

  @override
  String get starLoaderTitle => 'Frachtlader';

  @override
  String get starLoaderGameDesc =>
      'Schiebe die Frachtkisten ohne hängen zu bleiben auf die grünen Ziele.';

  @override
  String get starLoaderHint =>
      'Bewege dich mit Pfeiltasten oder Wischen. Bringe alle Frachtkisten auf die Ziele!';

  @override
  String get moves => 'Züge';

  @override
  String get optimal => 'Optimal';

  @override
  String get starLoaderWinTitle => 'Fracht geladen!';

  @override
  String starLoaderWinDesc(int moves, int time, int score) {
    return 'Abgeschlossen in $moves Zügen, ${time}s. Punkte: $score';
  }

  @override
  String get efficiency => 'Effizienz';

  @override
  String get movesVsOptimal => 'Züge / Optimal';

  @override
  String get imprint => 'Impressum';

  @override
  String get imprintServiceProvider => 'Diensteanbieter';

  @override
  String get imprintProviderAddress =>
      'Christian Ströbele\nNikolausstr. 5\n70190 Stuttgart\nDeutschland/Germany';

  @override
  String get imprintContact => 'Kontakt';

  @override
  String get imprintContactDetails =>
      'Email: postmaster@crispstro.be\nPhone: 0049 176 6421 8601';

  @override
  String get imprintContentResponsible => 'Verantwortlich für den Inhalt';

  @override
  String get imprintDisclaimer => 'Haftungsausschluss';

  @override
  String get imprintDisclaimerText =>
      'Diese App wird \'as is\' (so wie sie ist) ausschließlich zu Bildungs- und kreativen Zwecken bereitgestellt, ohne jegliche Haftung.';

  @override
  String get imprintWebsite => 'www.crispstro.be';

  @override
  String get solarPanelGameTitle => 'Solarpanel-Baumeister';

  @override
  String get solarPanelTitle => 'Baue Solaranlagen';

  @override
  String get solarPanelHint =>
      'Höhe × Breite = Panelfläche. Addiere beide Panels für Gesamtleistung!';

  @override
  String get solarPanelNumbers => 'Verfügbare Zahlen';

  @override
  String get solarPanelDropFar => 'Näher an eine leere Zelle ziehen!';

  @override
  String get solarPanelFail => 'Nicht ganz! Prüfe deine Rechnungen.';

  @override
  String get solarPanelWinTitle => '🌞 Station versorgt!';

  @override
  String solarPanelWinDesc(Object bonus) {
    return 'Großartig! Du hast $bonus Bonus-Watt verdient!';
  }

  @override
  String get solarPanelNext => 'Nächste Anlage';
}
