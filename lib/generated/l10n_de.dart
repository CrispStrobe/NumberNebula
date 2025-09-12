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
  String get welcome => 'Willkommen in der Weltraum Mathe Akademie!';

  @override
  String get startAdventure => 'Starte dein Mathe-Abenteuer';

  @override
  String get chooseGrade => 'Wähle deine Klasse';

  @override
  String get grade3 => '3. Klasse';

  @override
  String get grade4 => '4. Klasse';

  @override
  String get grade5 => '5. Klasse';

  @override
  String get grade6 => '6. Klasse';

  @override
  String get gameMenu => 'Spiele-Menü';

  @override
  String get magicTriangles => 'Zauberdreiecke';

  @override
  String get magicTrianglesDesc =>
      'Löse das Geheimnis der kosmischen Dreiecke! Fülle die fehlenden Zahlen ein.';

  @override
  String get bubbleMath => 'Kosmische Blasen-Mathe';

  @override
  String get bubbleMathDesc =>
      'Platze die schwebenden Weltraumblasen in der richtigen mathematischen Reihenfolge!';

  @override
  String get puzzleMath => 'Weltraum-Puzzle-Mathe';

  @override
  String get puzzleMathDesc =>
      'Vervollständige die Raumstation, indem du Mathe-Rätsel löst und Teile zusammenfügst!';

  @override
  String get level => 'Level';

  @override
  String get score => 'Punkte';

  @override
  String get lives => 'Leben';

  @override
  String get time => 'Zeit';

  @override
  String get correct => 'Richtig!';

  @override
  String get incorrect => 'Versuch es nochmal!';

  @override
  String get excellent => 'Hervorragende Arbeit, Weltraum-Forscher!';

  @override
  String get good => 'Gut gemacht!';

  @override
  String get tryAgain => 'Lass uns nochmal versuchen!';

  @override
  String get gameOver => 'Mission Erfolgreich!';

  @override
  String get nextLevel => 'Nächste Mission';

  @override
  String get playAgain => 'Nochmal spielen';

  @override
  String get backToMenu => 'Zurück zur Raumstation';

  @override
  String get settings => 'Einstellungen';

  @override
  String get sound => 'Ton';

  @override
  String get music => 'Musik';

  @override
  String get language => 'Sprache';

  @override
  String get progress => 'Fortschritt';

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
  String get instructionsMagicTriangles =>
      'Finde die fehlenden Zahlen in jedem Dreieck. Jede Seite sollte dieselbe Summe ergeben!';

  @override
  String get instructionsBubbleMath =>
      'Platze die Blasen in der Reihenfolge von der kleinsten zur größten Antwort. Achte auf die beweglichen Blasen!';

  @override
  String get instructionsPuzzleMath =>
      'Ziehe Puzzleteile an ihre richtigen Plätze. Drehe Teile durch Antippen. Finde die passenden Mathe-Antworten!';

  @override
  String get hintsMagicTriangles =>
      'Denk daran: jede Seite des Dreiecks ergibt dieselbe Zauberzahl!';

  @override
  String get hintsBubbleMath =>
      'Beginne mit der kleinsten Antwort und arbeite dich nach oben!';

  @override
  String get hintsPuzzleMath =>
      'Suche nach passenden Farben und löse zuerst die Mathe-Aufgaben!';

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
