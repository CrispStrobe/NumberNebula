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
  String get magicTriangles => 'Sternentor';

  @override
  String get magicTrianglesDesc =>
      'Richte die kosmischen Energieknoten aus! Jede Seite des Dreiecks muss die gleiche kosmische Frequenz ergeben, um das Wurmloch zu stabilisieren.';

  @override
  String get bubbleMath => 'Asteroidenfeld';

  @override
  String get bubbleMathDesc =>
      'Navigiere durch ein gefährliches Asteroidenfeld! Zerstöre die treibenden Weltraumfelsen in der richtigen Reihenfolge, bevor sie kollidieren.';

  @override
  String get puzzleMath => 'Sternbild-Puzzles';

  @override
  String get puzzleMathDesc =>
      'Rekonstruiere himmlische Sternenkarten! Löse Gleichungen, um die richtigen Koordinaten zu finden und Fragmente zu platzieren.';

  @override
  String get hyperdriveGates => 'Raumtore';

  @override
  String get hyperdriveGatesDesc =>
      'Setze einen Kurs durch die Raumtore! Fliege durch das Tor mit der richtigen Antwort, um den Sprung auf Lichtgeschwindigkeit zu machen.';

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
  String get gameOver => 'Mission Erfolgreich!';

  @override
  String get nextLevel => 'Nächste Mission';

  @override
  String get playAgain => 'Nochmal spielen';

  @override
  String get backToMenu => 'Zurück zur Missionskontrolle';

  @override
  String get settings => 'Einstellungen';

  @override
  String get sound => 'Sound-Effekte';

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
}
