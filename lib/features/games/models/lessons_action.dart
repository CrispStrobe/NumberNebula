import 'practice_lesson.dart';

const actionLessons = <String, PracticeLesson>{
  "asteroid_math": PracticeLesson(
    rulesEn:
        "Shoot the asteroids in ascending order of their RESULTS. Calculate every remaining expression; tap the one with the smallest remaining result. A correct calculation shot out of order is a mistake.",
    rulesDe:
        "Schieße die Asteroiden nach ihren ERGEBNISSEN aufsteigend ab. Berechne die übrigen Rechnungen und tippe auf das kleinste übrige Ergebnis. Eine richtige Rechnung zur falschen Zeit zählt als Fehler.",
    boardEn: "Near: 4 + 4   •   Far: 6 − 3   •   Middle: 2 × 2",
    boardDe: "Nah: 4 + 4   •   Fern: 6 − 3   •   Mitte: 2 × 2",
    questionEn: "Which asteroid must be shot first?",
    questionDe: "Welcher Asteroid muss zuerst abgeschossen werden?",
    optionsEn: [
      "6 − 3, because its result is 3",
      "4 + 4, because it is nearest",
      "2 × 2, because its first number is smallest"
    ],
    optionsDe: [
      "6 − 3, denn das Ergebnis ist 3",
      "4 + 4, denn er ist am nächsten",
      "2 × 2, denn die erste Zahl ist am kleinsten"
    ],
    correctIndex: 0,
    explanationEn:
        "The results are 8, 3 and 4. Shoot 3, then 4, then 8. Distance and the first printed number do not determine the order.",
    explanationDe:
        "Die Ergebnisse sind 8, 3 und 4. Schieße erst 3, dann 4, dann 8 ab. Entfernung und erste gedruckte Zahl bestimmen die Reihenfolge nicht.",
    focusEn: "Compare the results of the remaining expressions.",
    focusDe: "Vergleiche die Ergebnisse der übrigen Rechnungen.",
    strategyEn:
        "Calculate first, cross out targets already hit, then choose the smallest result still present.",
    strategyDe:
        "Rechne zuerst, streiche schon getroffene Ziele gedanklich und wähle das kleinste noch vorhandene Ergebnis.",
  ),
  "puzzle_math": PracticeLesson(
    rulesEn:
        "Complete the picture by dragging each piece onto an empty slot with the same result as its calculation. The piece must be upright. Tap an available piece to rotate it; a rotated matching answer is still rejected.",
    rulesDe:
        "Vervollständige das Bild: Ziehe jedes Teil auf einen leeren Platz mit dem Ergebnis seiner Rechnung. Das Teil muss aufrecht stehen. Tippe zum Drehen auf ein verfügbares Teil; auch ein passendes Ergebnis wird verdreht abgelehnt.",
    boardEn: "Piece: 4 + 5, upright. Empty slots: 6 and 9.",
    boardDe: "Teil: 4 + 5, aufrecht. Leere Plätze: 6 und 9.",
    questionEn: "Which placement is accepted?",
    questionDe: "Welche Platzierung wird angenommen?",
    optionsEn: [
      "Turn it upside down and place on 9",
      "Upright on 9",
      "Upright on 6"
    ],
    optionsDe: [
      "Auf den Kopf drehen und auf die 9",
      "Aufrecht auf die 9",
      "Aufrecht auf die 6"
    ],
    correctIndex: 1,
    explanationEn:
        "4 + 5 = 9, and upright means rotation zero. The wrong result or wrong rotation fails even if one of the two checks matches.",
    explanationDe:
        "4 + 5 = 9, und aufrecht bedeutet ohne Verdrehung. Ein falsches Ergebnis oder eine falsche Drehung scheitert, auch wenn die andere Prüfung passt.",
    focusEn: "Choose an unplaced piece and read its calculation.",
    focusDe: "Wähle ein noch nicht gelegtes Teil und lies seine Rechnung.",
    strategyEn:
        "Solve the calculation, find an empty slot carrying that result, then check that the picture is upright before dropping.",
    strategyDe:
        "Löse die Rechnung, suche einen leeren Platz mit diesem Ergebnis und prüfe vor dem Ablegen, ob das Bild aufrecht steht.",
  ),
  "hyperdrive_gates": PracticeLesson(
    rulesEn:
        "Calculate the expression shown for the approaching gates. Tap or steer toward the gate carrying that result. The position or size of a gate does not make its answer correct.",
    rulesDe:
        "Berechne die angezeigte Rechnung für die kommenden Tore. Tippe oder steuere zu dem Tor mit diesem Ergebnis. Position oder Größe eines Tors machen seine Antwort nicht richtig.",
    boardEn: "Display: 9 − 4. Left gate: 5. Right gate: 13.",
    boardDe: "Anzeige: 9 − 4. Linkes Tor: 5. Rechtes Tor: 13.",
    questionEn: "Where should the ship fly?",
    questionDe: "Wohin soll das Schiff fliegen?",
    optionsEn: [
      "Through 13, adding the two numbers",
      "Whichever gate is nearest",
      "Through the left gate marked 5"
    ],
    optionsDe: [
      "Durch 13: beide Zahlen addieren",
      "Durch das nächstgelegene Tor",
      "Durch das linke Tor mit der 5"
    ],
    correctIndex: 2,
    explanationEn:
        "The displayed sign is minus: 9 − 4 = 5. Choose 5 before the gate reaches the ship. Adding instead gives the distractor 13.",
    explanationDe:
        "Das angezeigte Zeichen ist Minus: 9 − 4 = 5. Wähle die 5, bevor das Tor das Schiff erreicht. Addieren ergibt die Ablenkungsantwort 13.",
    focusEn: "Read the current expression, including its sign.",
    focusDe: "Lies die aktuelle Rechnung einschließlich Rechenzeichen.",
    strategyEn:
        "Work out the result before moving and match that result to the gate label.",
    strategyDe:
        "Berechne das Ergebnis vor der Bewegung und gleiche es mit der Torbeschriftung ab.",
  ),
  "pathfinder": PracticeLesson(
    rulesEn:
        "At each fork, solve the displayed calculation and tap the path labelled with its result. Follow one correct fork after another; the visually straight path is not always correct.",
    rulesDe:
        "Löse an jeder Gabelung die angezeigte Rechnung und tippe auf den Weg mit ihrem Ergebnis. Folge so einer richtigen Abzweigung nach der anderen; der gerade Weg ist nicht immer richtig.",
    boardEn: "8 ÷ 2. Paths: left 4, middle 6, right 10.",
    boardDe: "8 ÷ 2. Wege: links 4, Mitte 6, rechts 10.",
    questionEn: "Which path continues the mission?",
    questionDe: "Welcher Weg setzt die Mission richtig fort?",
    optionsEn: ["Left: 4", "Middle: 6", "Right: 10"],
    optionsDe: ["Links: 4", "Mitte: 6", "Rechts: 10"],
    correctIndex: 0,
    explanationEn:
        "8 ÷ 2 = 4. The distractors 6 and 10 come from using subtraction or addition instead of the displayed division.",
    explanationDe:
        "8 ÷ 2 = 4. Die Ablenkungsantworten 6 und 10 entstehen, wenn du statt der angezeigten Division subtrahierst oder addierst.",
    focusEn: "Look at the expression for the current fork.",
    focusDe: "Betrachte die Rechnung der aktuellen Gabelung.",
    strategyEn:
        "Identify the operation, calculate its answer, then choose the path with exactly that label.",
    strategyDe:
        "Bestimme das Rechenzeichen, berechne die Antwort und wähle den Weg mit genau dieser Zahl.",
  ),
  "planet_hopping": PracticeLesson(
    rulesEn:
        "Land on planets in the displayed order of their calculated results. Ascending means smallest first; descending means largest first. Tap a destination only when its result is the next target.",
    rulesDe:
        "Lande auf Planeten in der angezeigten Reihenfolge ihrer Rechenergebnisse. Aufsteigend heißt kleinstes zuerst, absteigend größtes zuerst. Tippe ein Ziel erst an, wenn sein Ergebnis als Nächstes dran ist.",
    boardEn:
        "Order: 8 → 5 → 3. The 8 is already visited. Planets show 2 + 3 and 6 − 3.",
    boardDe:
        "Reihenfolge: 8 → 5 → 3. Die 8 ist schon besucht. Planeten zeigen 2 + 3 und 6 − 3.",
    questionEn: "Which planet is next?",
    questionDe: "Welcher Planet ist als Nächstes dran?",
    optionsEn: [
      "Return to 8",
      "2 + 3, because the next result is 5",
      "6 − 3, because 3 is smallest"
    ],
    optionsDe: [
      "Zur 8 zurückkehren",
      "2 + 3, denn als Nächstes kommt 5",
      "6 − 3, denn 3 ist am kleinsten"
    ],
    correctIndex: 1,
    explanationEn:
        "This round is descending. After 8 comes 5, then 3. Always choosing the smallest would break this round’s order.",
    explanationDe:
        "Diese Runde läuft absteigend. Nach 8 kommt 5, dann 3. Immer die kleinste Zahl zu wählen würde diese Reihenfolge verletzen.",
    focusEn: "Find the next entry in the displayed target order.",
    focusDe: "Suche den nächsten Eintrag in der angezeigten Zielreihenfolge.",
    strategyEn:
        "Exclude planets already visited; calculate the remaining expressions and match the next required value, respecting the arrow direction.",
    strategyDe:
        "Lasse besuchte Planeten weg, berechne die übrigen Rechnungen und wähle den nächsten geforderten Wert passend zur Pfeilrichtung.",
  ),
  "signal_triangulation": PracticeLesson(
    rulesEn:
        "Guess the ordered glyph code. Feedback counts exact positions separately from correct glyphs in different positions; it does not identify which slots are correct. Repeated glyphs are counted only as often as they occur in the secret.",
    rulesDe:
        "Errate den geordneten Zeichencode. Die Rückmeldung zählt richtige Positionen getrennt von richtigen Zeichen an anderen Positionen; sie verrät nicht, welche Plätze richtig sind. Wiederholte Zeichen zählen nur so oft, wie sie im Geheimcode vorkommen.",
    boardEn: "Secret for this example: ☀ ★ ●. Guess: ☀ ● ★.",
    boardDe: "Geheimcode dieses Beispiels: ☀ ★ ●. Versuch: ☀ ● ★.",
    questionEn: "Which feedback belongs to this guess?",
    questionDe: "Welche Rückmeldung gehört zu diesem Versuch?",
    optionsEn: [
      "3 exact positions",
      "0 matching glyphs",
      "1 exact position, 2 misplaced glyphs"
    ],
    optionsDe: [
      "3 richtige Positionen",
      "0 passende Zeichen",
      "1 richtige Position, 2 Zeichen am falschen Platz"
    ],
    correctIndex: 2,
    explanationEn:
        "☀ matches its position. ● and ★ are both in the code but swapped. In a real round the code is hidden: feedback totals alone do not tell you which slot to lock.",
    explanationDe:
        "☀ steht richtig. ● und ★ sind beide im Code, aber vertauscht. In einer echten Runde ist der Code verborgen: Die Rückmeldungszahlen allein sagen nicht, welchen Platz du festhalten sollst.",
    focusEn: "Compare one previous guess with both feedback counts.",
    focusDe: "Vergleiche einen früheren Versuch mit beiden Rückmeldungszahlen.",
    strategyEn:
        "Keep every feedback total consistent when trying a new order. Do not treat a misplaced match as an exact-position match.",
    strategyDe:
        "Beachte bei einer neuen Reihenfolge jede bisherige Rückmeldungszahl. Ein Zeichen am falschen Platz ist kein Positions-Treffer.",
  ),
  "arithmancer_duel": PracticeLesson(
    rulesEn:
        "Build a valid expression from available number, operator and bracket cards. You must afford the total cost of the cards played. Then check the result against the opponent’s shield or weakness; a correct expression alone does not guarantee a useful attack.",
    rulesDe:
        "Baue einen gültigen Ausdruck aus verfügbaren Zahlen-, Rechenzeichen- und Klammerkarten. Du musst die Gesamtkosten der gespielten Karten bezahlen können. Prüfe dann das Ergebnis gegen Schild oder Schwäche des Gegners; eine richtige Rechnung allein garantiert keinen wirksamen Angriff.",
    boardEn: "Energy: 2. Cards: 2 (cost 1), + (cost 1), 3 (cost 1).",
    boardDe: "Energie: 2. Karten: 2 (Kosten 1), + (Kosten 1), 3 (Kosten 1).",
    questionEn: "Can you play all three cards as 2 + 3 now?",
    questionDe: "Kannst du jetzt alle drei Karten als 2 + 3 spielen?",
    optionsEn: [
      "No: the three cards cost 3 energy",
      "Yes: the correct answer makes it free",
      "Yes: only the + card costs energy"
    ],
    optionsDe: [
      "Nein: Die drei Karten kosten 3 Energie",
      "Ja: Eine richtige Rechnung ist kostenlos",
      "Ja: Nur die Pluskarte kostet Energie"
    ],
    correctIndex: 0,
    explanationEn:
        "1 + 1 + 1 = 3 energy, but only 2 is available. Arithmetic validity, affordability and the opponent’s properties are separate checks.",
    explanationDe:
        "1 + 1 + 1 = 3 Energie, aber du hast nur 2. Gültige Rechnung, Bezahlbarkeit und Gegnereigenschaften sind getrennte Prüfungen.",
    focusEn:
        "Check the current hand, available energy and the opponent’s displayed properties.",
    focusDe:
        "Prüfe aktuelle Hand, verfügbare Energie und angezeigte Gegnereigenschaften.",
    strategyEn:
        "Add selected card costs first. Build an affordable expression, calculate it, and only then compare its mathematical properties with the opponent.",
    strategyDe:
        "Addiere zuerst die Kosten gewählter Karten. Baue einen bezahlbaren Ausdruck, rechne ihn aus und vergleiche erst dann seine mathematischen Eigenschaften mit dem Gegner.",
  ),
  "asteroid_field_navigator": PracticeLesson(
    rulesEn:
        "Reveal every safe cell without opening a mine. A revealed number counts mines in all eight neighbouring cells, including diagonals. Tap to reveal; long-press or right-click to flag a suspected mine. Flags alone do not win.",
    rulesDe:
        "Decke alle sicheren Felder auf, ohne eine Mine zu öffnen. Eine Zahl zählt Minen in allen acht Nachbarfeldern, auch diagonal. Tippen deckt auf; langes Drücken oder Rechtsklick markiert eine vermutete Mine. Markierungen allein gewinnen nicht.",
    boardEn:
        "Clue 1. One adjacent mine is correctly flagged; two adjacent cells remain covered. All other neighbours are known safe.",
    boardDe:
        "Hinweis 1. Eine benachbarte Mine ist sicher markiert; zwei Nachbarfelder sind noch verdeckt. Alle anderen Nachbarn sind sicher.",
    questionEn: "What follows for the two covered neighbours?",
    questionDe: "Was folgt für die beiden verdeckten Nachbarn?",
    optionsEn: [
      "The clue must count two more mines",
      "Both are safe to reveal",
      "Both must be flagged"
    ],
    optionsDe: [
      "Der Hinweis muss noch zwei Minen zählen",
      "Beide kannst du sicher aufdecken",
      "Beide müssen markiert werden"
    ],
    correctIndex: 1,
    explanationEn:
        "The one required mine is already accounted for. No additional adjacent mine can exist, so the two remaining neighbours are safe. This depends on the flag being justified.",
    explanationDe:
        "Die eine geforderte Mine ist schon berücksichtigt. Es kann keine weitere benachbarte Mine geben, also sind beide übrigen Nachbarn sicher. Dafür muss die Markierung wirklich begründet sein.",
    focusEn:
        "Choose a revealed number and count its flagged and still-covered neighbours.",
    focusDe:
        "Wähle eine aufgedeckte Zahl und zähle markierte sowie noch verdeckte Nachbarn.",
    strategyEn:
        "Needed mines = clue minus justified flags. Zero means remaining neighbours are safe; equality with the number of covered neighbours forces all of them to be mines.",
    strategyDe:
        "Fehlende Minen = Hinweis minus begründete Markierungen. Null bedeutet sichere übrige Nachbarn; entspricht die Zahl allen verdeckten Nachbarn, müssen diese Minen sein.",
  ),
  "cargo_bay_arranger": PracticeLesson(
    rulesEn:
        "Move and rotate falling cargo pieces to fill complete horizontal rows. Any full row clears; matching the target sum and special number patterns gives bonuses. Use Hold when helpful, and avoid stacking up to the top.",
    rulesDe:
        "Verschiebe und drehe fallende Frachtteile, um waagerechte Reihen vollständig zu füllen. Jede volle Reihe verschwindet; passende Zielsummen und besondere Zahlenmuster bringen Boni. Nutze bei Bedarf Halten und vermeide einen Stapel bis nach oben.",
    boardEn:
        "Example row: [2] [3] [4] [empty]. Drop a 1 into the last gap. Bonus target: 12.",
    boardDe:
        "Beispielreihe: [2] [3] [4] [leer]. Eine 1 fällt in die letzte Lücke. Bonusziel: 12.",
    questionEn: "Does the now-full row clear?",
    questionDe: "Verschwindet die jetzt volle Reihe?",
    optionsEn: [
      "No; a row must sum to 12 to clear",
      "No; all row values must match",
      "Yes; being full clears it, though its sum is only 10"
    ],
    optionsDe: [
      "Nein; nur Summe 12 lässt sie verschwinden",
      "Nein; alle Zahlen der Reihe müssen gleich sein",
      "Ja; voll genügt, obwohl ihre Summe nur 10 ist"
    ],
    correctIndex: 2,
    explanationEn:
        "2 + 3 + 4 + 1 = 10. The clearing rule checks that every row cell is occupied, not equality to the bonus target. Planning shape and avoiding holes comes first.",
    explanationDe:
        "2 + 3 + 4 + 1 = 10. Die Löschregel prüft, ob jedes Reihenfeld belegt ist, nicht ob die Bonuszielsumme erreicht ist. Plane zuerst Formen und vermeide Lücken.",
    focusEn: "Look for a row that can be completed by the current piece.",
    focusDe:
        "Suche eine Reihe, die sich mit dem aktuellen Teil vervollständigen lässt.",
    strategyEn:
        "Check the landing outline for holes and collisions. Complete a full row first; consider target sums and patterns as additional bonuses, not a condition for clearing.",
    strategyDe:
        "Prüfe die Landevorschau auf Lücken und Kollisionen. Vervollständige zuerst eine ganze Reihe; Zielsummen und Muster sind zusätzliche Boni, keine Löschbedingung.",
  ),
  "star_chart_scan": PracticeLesson(
    rulesEn:
        "Find the listed equations in the letter-and-number grid. Drag across every character in one straight horizontal, vertical or allowed diagonal line. Both sweep directions are accepted. A bent path or an unrelated true equation does not count.",
    rulesDe:
        "Finde die aufgelisteten Gleichungen im Zeichenraster. Ziehe über alle Zeichen auf einer geraden waagerechten, senkrechten oder erlaubten diagonalen Linie. Beide Ziehrichtungen zählen. Ein geknickter Weg oder eine nicht gesuchte richtige Gleichung zählt nicht.",
    boardEn: "Target: 3+2=5. One row reads: 3 | + | 2 | = | 5.",
    boardDe: "Gesucht: 3+2=5. Eine Zeile zeigt: 3 | + | 2 | = | 5.",
    questionEn: "Which selection finds it?",
    questionDe: "Welche Auswahl findet sie?",
    optionsEn: [
      "Drag straight from 3 through every character to 5",
      "Tap only the 5",
      "Select 3, then bend down to another 5"
    ],
    optionsDe: [
      "Gerade von 3 über alle Zeichen bis 5 ziehen",
      "Nur die 5 antippen",
      "3 wählen und dann zu einer anderen 5 nach unten abbiegen"
    ],
    correctIndex: 0,
    explanationEn:
        "The complete straight sweep spells exactly 3+2=5. Sweeping back from 5 to 3 also works because the game accepts reversed sweeps.",
    explanationDe:
        "Die vollständige gerade Auswahl ergibt genau 3+2=5. Auch rückwärts von 5 zur 3 funktioniert, weil das Spiel umgekehrte Ziehrichtungen akzeptiert.",
    focusEn: "Choose an equation in the not-yet-found target list.",
    focusDe: "Wähle eine noch nicht gefundene Gleichung aus der Zielliste.",
    strategyEn:
        "Locate one end, then trace the whole equation along a single direction. Include the operators and equals sign, not only the numbers.",
    strategyDe:
        "Suche ein Ende und verfolge die ganze Gleichung in einer einzigen Richtung. Nimm Rechenzeichen und Gleichheitszeichen mit, nicht nur die Zahlen.",
  ),
  "comm_relay": PracticeLesson(
    rulesEn:
        "Decode according to the named cipher. Caesar shifts every letter back by the same amount, wrapping A to Z; Atbash pairs opposite ends of the alphabet; a keyword cipher uses its displayed substitution. Preserve the message’s word order.",
    rulesDe:
        "Entschlüssle nach der benannten Chiffre. Caesar verschiebt jeden Buchstaben gleich weit zurück, von A geht es zu Z; Atbash paart entgegengesetzte Alphabetenden; die Schlüsselwortchiffre nutzt ihre angezeigte Zuordnung. Behalte die Wortreihenfolge bei.",
    boardEn: "Caesar: ciphertext DBU, shift back by 1.",
    boardDe: "Caesar: Geheimtext IBVT, um 1 zurückverschieben.",
    questionEn: "What message results?",
    questionDe: "Welche Nachricht entsteht?",
    optionsEn: ["ECV", "CAT", "DBU"],
    optionsDe: ["JCWU", "HAUS", "IBVT"],
    correctIndex: 1,
    explanationEn:
        "D→C, B→A, U→T gives CAT. Leaving letters unchanged does not decode; moving forward gives the wrong direction.",
    explanationDe:
        "I→H, B→A, V→U, T→S ergibt HAUS. Unverändert lassen entschlüsselt nicht; vorwärts verschieben ist die falsche Richtung.",
    focusEn: "Read the cipher type before using a letter rule.",
    focusDe: "Lies den Chiffrentyp, bevor du eine Buchstabenregel anwendest.",
    strategyEn:
        "For Caesar, test the same backwards shift on several letters. For Atbash or keyword substitution, use their own mapping rather than the Caesar wheel.",
    strategyDe:
        "Teste bei Caesar dieselbe Rückwärtsverschiebung an mehreren Buchstaben. Nutze bei Atbash oder Schlüsselwort die jeweilige Zuordnung statt des Caesar-Rads.",
  ),
  "crew_manifest": PracticeLesson(
    rulesEn:
        "Match every crew member to exactly one different item. Tap a grid cell to cycle through undecided, check mark and cross. A check means that pairing is confirmed; a cross means excluded. Use all clues before submitting.",
    rulesDe:
        "Ordne jedem Crewmitglied genau einen anderen Gegenstand zu. Tippen schaltet ein Rasterfeld zwischen unentschieden, Haken und Kreuz um. Ein Haken bestätigt die Zuordnung, ein Kreuz schließt sie aus. Nutze vor dem Bestätigen alle Hinweise.",
    boardEn:
        "Crew: Zara, Kip, Nova. Items: map, helm, laser. Zara has the map. Kip does not have the helm.",
    boardDe:
        "Crew: Zara, Kip, Nova. Dinge: Karte, Helm, Laser. Zara hat die Karte. Kip hat nicht den Helm.",
    questionEn: "Which complete assignment follows?",
    questionDe: "Welche vollständige Zuordnung folgt?",
    optionsEn: [
      "Zara–map, Kip–map, Nova–helm",
      "Zara–map, Kip–helm, Nova–laser",
      "Zara–map, Kip–laser, Nova–helm"
    ],
    optionsDe: [
      "Zara–Karte, Kip–Karte, Nova–Helm",
      "Zara–Karte, Kip–Helm, Nova–Laser",
      "Zara–Karte, Kip–Laser, Nova–Helm"
    ],
    correctIndex: 2,
    explanationEn:
        "The map is already Zara’s and cannot be reused. Kip cannot have the helm, so gets the laser; the helm remains for Nova. Both the clues and one-to-one assignment matter.",
    explanationDe:
        "Die Karte gehört schon Zara und darf nicht erneut vergeben werden. Kip darf nicht den Helm haben, erhält also den Laser; Nova bleibt der Helm. Hinweise und eindeutige Zuordnung müssen beide passen.",
    focusEn:
        "Start with a direct pairing or an exclusion in a row with few choices.",
    focusDe:
        "Beginne mit einer direkten Zuordnung oder einem Ausschluss in einer fast geklärten Zeile.",
    strategyEn:
        "After confirming a pairing, exclude its other row and column choices. Do not assign the same item to another crew member.",
    strategyDe:
        "Schließe nach einer bestätigten Zuordnung die übrigen Felder ihrer Zeile und Spalte aus. Vergib denselben Gegenstand nicht an ein zweites Crewmitglied.",
  ),
  "alien_tribunal": PracticeLesson(
    rulesEn:
        "Assign each speaker as truthful or lying. A truthful speaker’s entire statement must be true; a liar’s entire statement must be false. Test the roles against every statement, including statements about the speakers themselves.",
    rulesDe:
        "Ordne jedem Sprecher wahr oder lügend zu. Die ganze Aussage eines Wahrheitssagers muss wahr sein; die ganze Aussage eines Lügners muss falsch sein. Prüfe die Rollen gegen jede Aussage, auch Aussagen über die Sprecher selbst.",
    boardEn: "A says: “Both of us are liars.” B says: “A is a liar.”",
    boardDe: "A sagt: „Wir beide lügen.“ B sagt: „A lügt.“",
    questionEn: "Which roles make both statements consistent?",
    questionDe: "Welche Rollen machen beide Aussagen widerspruchsfrei?",
    optionsEn: [
      "A lies; B tells the truth",
      "A tells the truth; B lies",
      "Both lie"
    ],
    optionsDe: [
      "A lügt; B sagt die Wahrheit",
      "A sagt die Wahrheit; B lügt",
      "Beide lügen"
    ],
    correctIndex: 0,
    explanationEn:
        "A cannot truthfully say both are liars. If A lies, B’s claim is true, so B tells the truth. A’s “both” statement is then false, as required. Both lying would make A’s statement true and contradict that assignment.",
    explanationDe:
        "A kann nicht wahrheitsgemäß sagen, beide lügen. Lügt A, ist Bs Aussage wahr, also sagt B die Wahrheit. As „beide“-Aussage ist dann wie gefordert falsch. Würden beide lügen, wäre As Aussage wahr – ein Widerspruch.",
    focusEn:
        "Pick a statement whose truth changes under the role you are testing.",
    focusDe:
        "Wähle eine Aussage, deren Wahrheit sich mit der getesteten Rolle ändert.",
    strategyEn:
        "Assume one role, evaluate the WHOLE statement, and reject the assumption if the statement’s truth disagrees with the speaker’s assigned role.",
    strategyDe:
        "Nimm eine Rolle an, prüfe die GESAMTE Aussage und verwerfe die Annahme, wenn ihr Wahrheitswert nicht zur Sprecherrolle passt.",
  ),
  "hive_station": PracticeLesson(
    rulesEn:
        "Mark the hexagonal cells containing energy. A revealed clue counts energy in its six hexagonal neighbours. Tap cells to change your marks and submit the complete set; do not use square-grid diagonal rules.",
    rulesDe:
        "Markiere die Sechseckfelder mit Energie. Ein sichtbarer Hinweis zählt Energie in seinen sechs Sechseck-Nachbarn. Ändere Markierungen durch Tippen und bestätige die vollständige Menge; benutze nicht die Diagonalregeln eines quadratischen Gitters.",
    boardEn:
        "Clue 2: one neighbouring energy cell is confirmed. Exactly one neighbour is still undecided; all other neighbours are empty.",
    boardDe:
        "Hinweis 2: Eine benachbarte Energiezelle ist sicher. Genau ein Nachbar ist noch ungeklärt; alle anderen sind leer.",
    questionEn: "How should the undecided neighbour be treated?",
    questionDe: "Wie muss der ungeklärte Nachbar behandelt werden?",
    optionsEn: [
      "Mark the clue cell instead",
      "Mark it as energy",
      "Treat it as empty"
    ],
    optionsDe: [
      "Stattdessen das Hinweisfeld markieren",
      "Als Energie markieren",
      "Als leer behandeln"
    ],
    correctIndex: 1,
    explanationEn:
        "The clue needs two neighbouring energy cells. One is known and only one position remains, so that position must contain energy. The clue counts neighbours, not itself.",
    explanationDe:
        "Der Hinweis verlangt zwei Energie-Nachbarn. Einer steht fest und nur ein Feld bleibt, also muss dort Energie liegen. Das Hinweisfeld zählt seine Nachbarn, nicht sich selbst.",
    focusEn: "Count the six neighbours of a visible hexagonal clue.",
    focusDe: "Zähle die sechs Nachbarn eines sichtbaren Sechseckhinweises.",
    strategyEn:
        "Subtract confirmed energy marks from the clue. Compare what remains with the undecided neighbours; never count the clue cell itself.",
    strategyDe:
        "Ziehe sichere Energie-Markierungen vom Hinweis ab. Vergleiche den Rest mit den ungeklärten Nachbarn; zähle das Hinweisfeld nie selbst mit.",
  ),
  "xenobiology_lab": PracticeLesson(
    rulesEn:
        "Find how many creatures of each species are present. The SAME two counts must match both the total eyes and total legs. Enter the counts and check both totals before submitting.",
    rulesDe:
        "Bestimme die Anzahl jeder Art. DIESELBEN beiden Anzahlen müssen sowohl zur gesamten Augen- als auch zur gesamten Beinzahl passen. Gib die Anzahlen ein und prüfe vor dem Bestätigen beide Summen.",
    boardEn: "A: 2 eyes, 4 legs. B: 4 eyes, 6 legs. Totals: 8 eyes, 14 legs.",
    boardDe:
        "A: 2 Augen, 4 Beine. B: 4 Augen, 6 Beine. Insgesamt: 8 Augen, 14 Beine.",
    questionEn: "Which population satisfies both totals?",
    questionDe: "Welche Population erfüllt beide Summen?",
    optionsEn: ["4 of A and 0 of B", "0 of A and 2 of B", "2 of A and 1 of B"],
    optionsDe: [
      "4 von A und 0 von B",
      "0 von A und 2 von B",
      "2 von A und 1 von B"
    ],
    correctIndex: 2,
    explanationEn:
        "2×2 + 1×4 = 8 eyes and 2×4 + 1×6 = 14 legs. The other two choices also make 8 eyes, but have 16 or 12 legs: checking only eyes is insufficient.",
    explanationDe:
        "2×2 + 1×4 = 8 Augen und 2×4 + 1×6 = 14 Beine. Die beiden anderen Antworten ergeben ebenfalls 8 Augen, aber 16 oder 12 Beine: Nur Augen prüfen genügt nicht.",
    focusEn: "Compare your current species counts with BOTH totals.",
    focusDe: "Vergleiche deine aktuellen Artenzahlen mit BEIDEN Summen.",
    strategyEn:
        "Multiply each count by its species’ eyes and legs separately. A combination that matches only one total must still be changed.",
    strategyDe:
        "Multipliziere jede Anzahl getrennt mit Augen und Beinen ihrer Art. Eine Kombination, die nur zu einer Summe passt, musst du noch ändern.",
  ),
  "asteroid_duel": PracticeLesson(
    rulesEn:
        "Take at least one and at most the shown maximum each turn. Whoever takes the LAST asteroid loses. Plan what you leave the opponent, rather than trying to collect the most.",
    rulesDe:
        "Nimm pro Zug mindestens einen und höchstens die angezeigte Höchstzahl. Wer den LETZTEN Asteroiden nimmt, verliert. Plane, was du dem Gegner übrig lässt, statt möglichst viel zu sammeln.",
    boardEn: "6 asteroids remain. Legal take: 1, 2 or 3. Last take loses.",
    boardDe:
        "6 Asteroiden übrig. Erlaubt: 1, 2 oder 3 nehmen. Letzter Zug verliert.",
    questionEn:
        "Which first move lets you force the opponent to take the last asteroid?",
    questionDe:
        "Mit welchem ersten Zug kannst du den Gegner zum letzten Asteroiden zwingen?",
    optionsEn: ["Take 1, leaving 5", "Take 3, leaving 3", "Take all 6"],
    optionsDe: [
      "1 nehmen, 5 übrig lassen",
      "3 nehmen, 3 übrig lassen",
      "Alle 6 nehmen"
    ],
    correctIndex: 0,
    explanationEn:
        "Leave 5. If the opponent takes 1, 2 or 3, answer with 3, 2 or 1. That leaves 1 for the opponent, who must take it and lose. Taking 6 is illegal.",
    explanationDe:
        "Lasse 5 übrig. Nimmt der Gegner 1, 2 oder 3, antwortest du mit 3, 2 oder 1. So bleibt ihm 1, die er nehmen muss und dadurch verliert. 6 zu nehmen ist nicht erlaubt.",
    focusEn:
        "Count what remains after each legal take, remembering that the last take loses.",
    focusDe:
        "Zähle für jede erlaubte Entnahme, was übrig bleibt, und denke daran: Der letzte Zug verliert.",
    strategyEn:
        "Try to leave 1, then one full response-group more: for maximum 3, leave 1, 5, 9 and so on. Pair opponent and own takes to total 4.",
    strategyDe:
        "Versuche 1 oder eine ganze Antwortgruppe mehr übrig zu lassen: Bei höchstens 3 sind das 1, 5, 9 und so weiter. Ergänze Gegnerzug und eigenen Zug zusammen auf 4.",
  ),
};
