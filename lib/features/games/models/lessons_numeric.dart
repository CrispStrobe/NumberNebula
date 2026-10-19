import 'practice_lesson.dart';

// Exercises and guidance follow the actual screen controls and validators.
const Map<String, PracticeLesson> numericLessons = {
  "star_forge": PracticeLesson(
    rulesEn:
        "Fill the empty star nodes with the available numbers. Use each number once. Every complete drawn straight line must add to the displayed target; a shared node belongs to every line through it. Drag a number to an empty node; tap your placement to remove it.",
    rulesDe:
        "Fülle die leeren Sternknoten mit den verfügbaren Zahlen. Verwende jede Zahl einmal. Jede vollständige gezeichnete Gerade muss die Zielsumme ergeben. Ein gemeinsamer Knoten zählt auf jeder Geraden durch ihn. Ziehe eine Zahl auf einen leeren Knoten; tippe auf deine Zahl, um sie zu entfernen.",
    boardEn:
        "Target 22. Two lines share □: \n1 + 6 + 10 + □ = 22\n2 + 7 + 8 + □ = 22\nAvailable here: 3,5,9.",
    boardDe:
        "Zielsumme 22. Zwei Geraden teilen □: \n1 + 6 + 10 + □ = 22\n2 + 7 + 8 + □ = 22\nHier verfügbar: 3,5,9.",
    questionEn:
        "Which number can you drag into the shared node without breaking either line?",
    questionDe:
        "Welche Zahl kannst du in den gemeinsamen Knoten ziehen, sodass beide Geraden stimmen?",
    optionsEn: ["3", "5", "9"],
    optionsDe: ["3", "5", "9"],
    correctIndex: 1,
    explanationEn:
        "5 works in both lines: 1+6+10+5=22 and 2+7+8+5=22. With 3 both sums are 20; with 9 both are 26. Check entire lines, not just the outer points.",
    explanationDe:
        "5 passt in beide Geraden: 1+6+10+5=22 und 2+7+8+5=22. Mit 3 ergeben beide 20, mit 9 ergeben beide 26. Zähle die ganze Gerade, nicht nur die äußeren Spitzen.",
    focusEn: "Find a complete drawn line with just one empty node.",
    focusDe:
        "Suche eine vollständige gezeichnete Gerade mit genau einem leeren Knoten.",
    strategyEn:
        "Add its filled nodes and subtract that total from the target. Check that the missing number is still available and also fits every other line through that node.",
    strategyDe:
        "Addiere ihre belegten Knoten und ziehe die Summe von der Zielsumme ab. Prüfe, ob die fehlende Zahl noch verfügbar ist und auch auf jeder anderen Geraden durch diesen Knoten passt.",
  ),
  "number_walls": PracticeLesson(
    rulesEn:
        "Drag numbers into the empty bricks. The operation shown for this wall applies to each upper brick and its two neighbours directly below. Addition: add them; multiplication: multiply them; subtraction: take their positive difference; division: divide the larger by the smaller exactly. All little triangles must work.",
    rulesDe:
        "Ziehe Zahlen in die leeren Steine. Die angezeigte Rechenart gilt für jeden oberen Stein und seine beiden Nachbarn direkt darunter. Addition: addieren; Multiplikation: multiplizieren; Subtraktion: den positiven Unterschied bilden; Division: die größere Zahl ohne Rest durch die kleinere teilen. Alle kleinen Dreiecke müssen stimmen.",
    boardEn: "Addition wall: \n      13\n   7      □\n 3    4     2",
    boardDe: "Additionsmauer: \n      13\n   7      □\n 3    4     2",
    questionEn:
        "Which number belongs in □ and makes both the lower pair and the top work?",
    questionDe:
        "Welche Zahl gehört in □, damit sowohl das untere Paar als auch die Spitze stimmen?",
    optionsEn: ["8", "9", "6"],
    optionsDe: ["8", "9", "6"],
    correctIndex: 2,
    explanationEn:
        "The missing brick is 4+2=6. It also fits above: 7+6=13. Neither 8 nor 9 matches either required sum.",
    explanationDe:
        "Der fehlende Stein ist 4+2=6. Auch darüber stimmt es: 7+6=13. 8 und 9 erfüllen die beiden benötigten Summen nicht.",
    focusEn: "Check the wall’s operation before choosing a brick.",
    focusDe: "Prüfe zuerst die Rechenart dieser Mauer.",
    strategyEn:
        "Use the two bricks immediately below the gap, then check the triangle above it. If a lower brick is missing, work backwards from a known upper brick. For subtraction and division, check both possible lower values.",
    strategyDe:
        "Nutze die zwei Steine direkt unter der Lücke und prüfe danach das Dreieck darüber. Fehlt ein unterer Stein, rechne vom bekannten oberen Stein zurück. Bei Subtraktion und Division prüfst du beide möglichen unteren Werte.",
  ),
  "orbital_towers": PracticeLesson(
    rulesEn:
        "Fill an N×N grid with heights 1 to N, once in every row and column. An edge clue counts towers visible from that edge: a taller tower hides every shorter tower behind it. Drag heights into empty cells; satisfy every row, column and edge clue.",
    rulesDe:
        "Fülle ein N×N-Gitter mit den Höhen 1 bis N, jede einmal pro Zeile und Spalte. Eine Randzahl zählt die von dort sichtbaren Türme: Ein höherer Turm verdeckt alle niedrigeren dahinter. Ziehe Höhen in leere Felder; alle Zeilen, Spalten und Randzahlen müssen stimmen.",
    boardEn:
        "4×4 row, viewed from the LEFT: \nedge clue 2 → [2, □, 1, 3]\nThis row must contain 1,2,3,4 once.",
    boardDe:
        "4×4-Zeile, Blick von LINKS: \nRandzahl 2 → [2, □, 1, 3]\nDiese Zeile braucht 1,2,3,4 je einmal.",
    questionEn: "Which height fills the gap AND gives two visible towers?",
    questionDe: "Welche Höhe füllt die Lücke UND ergibt zwei sichtbare Türme?",
    optionsEn: [
      "4; only 2 and 4 are visible",
      "3; count both towers of height 3",
      "1; count the first two cells",
    ],
    optionsDe: [
      "4; nur 2 und 4 sind sichtbar",
      "3; beide Türme mit Höhe 3 zählen",
      "1; die ersten beiden Felder zählen",
    ],
    correctIndex: 0,
    explanationEn:
        "The missing height is 4. From the left you see 2, then 4; 4 hides 1 and 3. Repeating 3 or 1 breaks the row rule. Visibility is not the number of occupied cells.",
    explanationDe:
        "Die fehlende Höhe ist 4. Von links siehst du 2, dann 4; 4 verdeckt 1 und 3. Eine weitere 3 oder 1 verletzt die Zeilenregel. Sichtbarkeit ist nicht die Anzahl belegter Felder.",
    focusEn: "Pick one edge clue and look into the grid from that exact side.",
    focusDe:
        "Wähle eine Randzahl und schaue genau von dieser Seite ins Gitter.",
    strategyEn:
        "Keep the tallest height seen so far. Count a tower only when it is taller than that height. Then exclude heights already in the gap’s row or column; a fitting view alone is not enough.",
    strategyDe:
        "Merke dir die bisher größte Höhe. Zähle einen Turm nur, wenn er höher ist. Schließe dann Höhen aus, die schon in Zeile oder Spalte der Lücke stehen; ein passender Blick allein reicht nicht.",
  ),
  "magic_triangles": PracticeLesson(
    rulesEn:
        "Drag the available numbers into the triangle’s empty circles, using each once. Add ALL circles along each of the three sides, including both corners. Each side must equal the displayed target. A corner belongs to two sides; the total of all circles is not the goal.",
    rulesDe:
        "Ziehe die verfügbaren Zahlen in die leeren Kreise des Dreiecks, jede einmal. Addiere ALLE Kreise entlang jeder der drei Seiten, einschließlich beider Ecken. Jede Seite muss die Zielsumme ergeben. Eine Ecke zählt für zwei Seiten; die Summe aller Kreise ist nicht das Ziel.",
    boardEn:
        "Target 9; numbers 1–6: \n       1\n    6     □\n 2     4     3\nLeft side 1+6+2=9; bottom 2+4+3=9.",
    boardDe:
        "Zielsumme 9; Zahlen 1–6: \n       1\n    6     □\n 2     4     3\nLinks 1+6+2=9; unten 2+4+3=9.",
    questionEn:
        "Which number completes the RIGHT side while keeping every number used once?",
    questionDe:
        "Welche Zahl vervollständigt die RECHTE Seite, wenn jede Zahl nur einmal vorkommen darf?",
    optionsEn: ["4", "6", "5"],
    optionsDe: ["4", "6", "5"],
    correctIndex: 2,
    explanationEn:
        "The right side includes its corners: 1+□+3=9, so □=5. Both other sides already equal 9. 4 and 6 are already used and would make that side 8 or 10.",
    explanationDe:
        "Die rechte Seite enthält ihre Ecken: 1+□+3=9, also □=5. Die beiden anderen Seiten ergeben schon 9. 4 und 6 sind bereits belegt und ergäben rechts 8 oder 10.",
    focusEn: "Choose a whole side with exactly one empty circle.",
    focusDe: "Wähle eine ganze Seite mit genau einem leeren Kreis.",
    strategyEn:
        "Count both corners and every circle between them. Subtract their sum from the target. If the gap is a corner, check its other side too; do not reuse a number already on the triangle.",
    strategyDe:
        "Zähle beide Ecken und alle Kreise dazwischen. Ziehe ihre Summe von der Zielsumme ab. Liegt die Lücke an einer Ecke, prüfe auch deren zweite Seite. Verwende keine schon belegte Zahl erneut.",
  ),
  "arithmatic_square": PracticeLesson(
    rulesEn:
        "Drag numbers into the empty cells so every horizontal AND vertical equation is true. A crossing cell has one value for both directions. In this game calculate each equation step by step from left to right (or top to bottom), even when addition and multiplication mix; the last cell is the result.",
    rulesDe:
        "Ziehe Zahlen in die leeren Felder, sodass jede waagerechte UND senkrechte Gleichung stimmt. Ein Kreuzungsfeld hat für beide Richtungen denselben Wert. Rechne in diesem Spiel schrittweise von links nach rechts beziehungsweise oben nach unten, auch bei gemischtem Plus und Mal. Das letzte Feld ist das Ergebnis.",
    boardEn:
        "One shared gap X: \nRow: (2 + X) × 3 = 18\nColumn: X + 1 = 5\nEvaluate the row as (2 + X) × 3.",
    boardDe:
        "Eine gemeinsame Lücke X: \nZeile: (2 + X) × 3 = 18\nSpalte: X + 1 = 5\nDie Zeile wird als (2 + X) × 3 berechnet.",
    questionEn:
        "Which number makes both equations true using this game’s calculation order?",
    questionDe:
        "Welche Zahl macht beide Gleichungen mit der Rechenreihenfolge dieses Spiels richtig?",
    optionsEn: ["3", "4", "6"],
    optionsDe: ["3", "4", "6"],
    correctIndex: 1,
    explanationEn:
        "X=4: first 2+4=6, then 6×3=18; vertically 4+1=5. X=3 gives 15 and 4, while X=6 gives 24 and 7. This game’s left-to-right rule matters here.",
    explanationDe:
        "X=4: erst 2+4=6, dann 6×3=18; senkrecht 4+1=5. X=3 ergibt 15 und 4, X=6 ergibt 24 und 7. Hier ist die Rechenregel von links nach rechts entscheidend.",
    focusEn: "Find a row or column with just one missing value.",
    focusDe: "Suche eine Zeile oder Spalte mit genau einem fehlenden Wert.",
    strategyEn:
        "Apply the displayed operations in order, then test the proposed value in the crossing equation. Do not apply “multiplication before addition” to this game’s sequential equations.",
    strategyDe:
        "Führe die angezeigten Rechenschritte der Reihe nach aus und prüfe den gefundenen Wert in der kreuzenden Gleichung. Verwende bei diesen schrittweisen Gleichungen nicht die Regel „Punkt vor Strich“.",
  ),
  "arithmancer_crosswords": PracticeLesson(
    rulesEn:
        "Fill the empty number cells so every horizontal and vertical equation is true. Equations cross at a shared number: that one cell must satisfy both. Follow each displayed operator and equals sign. Drag an available number into a gap; tap your placement to remove it.",
    rulesDe:
        "Fülle die leeren Zahlenfelder, sodass alle waagerechten und senkrechten Gleichungen stimmen. An einer Kreuzung teilen sich zwei Gleichungen dieselbe Zahl: Sie muss in beide passen. Beachte die Rechenzeichen und Gleichheitszeichen. Ziehe eine verfügbare Zahl in eine Lücke; tippe auf deine Zahl, um sie zu entfernen.",
    boardEn:
        "A crossing cell X belongs to both: \nHorizontal: X + 3 = 8\nVertical: 2 × X = 10",
    boardDe:
        "Ein Kreuzungsfeld X gehört zu beiden: \nWaagerecht: X + 3 = 8\nSenkrecht: 2 × X = 10",
    questionEn: "Which number belongs in the shared crossing cell?",
    questionDe: "Welche Zahl gehört in das gemeinsame Kreuzungsfeld?",
    optionsEn: ["5", "11", "8"],
    optionsDe: ["5", "11", "8"],
    correctIndex: 0,
    explanationEn:
        "5 satisfies both: 5+3=8 and 2×5=10. 11 adds 8+3 instead of finding the missing operand; 8 copies the result into the gap. Every crossing must work in both directions.",
    explanationDe:
        "5 erfüllt beides: 5+3=8 und 2×5=10. 11 addiert 8+3 statt den fehlenden Summanden zu suchen; 8 kopiert das Ergebnis in die Lücke. Jede Kreuzung muss in beiden Richtungen stimmen.",
    focusEn: "Look for an equation with only one empty number.",
    focusDe: "Suche eine Gleichung mit nur einer fehlenden Zahl.",
    strategyEn:
        "Work backwards with the inverse operation to find that number, then read the equation crossing the same cell. Keep the value only if it makes both equations true; division must have no remainder.",
    strategyDe:
        "Finde die Zahl durch die Umkehroperation und lies dann die Gleichung, die dasselbe Feld kreuzt. Behalte die Zahl nur, wenn beide Gleichungen stimmen. Division muss ohne Rest aufgehen.",
  ),
  "solarpanel_game": PracticeLesson(
    rulesEn:
        "This panel uses TWO rules. Multiply the left and middle bottom numbers for the left middle panel; multiply the middle and right bottom numbers for the right middle panel. ADD those two middle panels for the top. Drag numbers into the gaps until all three relationships work.",
    rulesDe:
        "Dieses Panel hat ZWEI Regeln. Multipliziere unten links mit unten Mitte für das linke mittlere Feld; unten Mitte mit unten rechts für das rechte mittlere Feld. ADDIERE die beiden mittleren Felder für die Spitze. Ziehe Zahlen in die Lücken, bis alle drei Beziehungen stimmen.",
    boardEn: "        □\n     6     12\n   2    3     4\n6=2×3 and 12=3×4.",
    boardDe: "        □\n     6     12\n   2    3     4\n6=2×3 und 12=3×4.",
    questionEn: "Which number belongs at the TOP of this panel?",
    questionDe: "Welche Zahl gehört an die SPITZE dieses Panels?",
    optionsEn: ["72", "18", "24"],
    optionsDe: ["72", "18", "24"],
    correctIndex: 1,
    explanationEn:
        "Top=6+12=18. 72 multiplies the middle panels, but the top uses addition. 24 multiplies all three bottom numbers and ignores both middle panels.",
    explanationDe:
        "Oben steht 6+12=18. 72 multipliziert die mittleren Felder, aber oben wird addiert. 24 multipliziert alle drei unteren Zahlen und übergeht die mittleren Felder.",
    focusEn: "Locate the gap: bottom, middle or top?",
    focusDe: "Wo liegt die Lücke: unten, in der Mitte oder oben?",
    strategyEn:
        "Use products from bottom to middle and a sum from middle to top. A missing bottom factor can be found by exact division; remember that the bottom middle factor is shared by both products.",
    strategyDe:
        "Von unten zur Mitte brauchst du Produkte, von der Mitte zur Spitze eine Summe. Einen fehlenden unteren Faktor findest du durch Division ohne Rest. Der Faktor unten in der Mitte gehört zu beiden Produkten.",
  ),
  "codebreaker": PracticeLesson(
    rulesEn:
        "Each symbol stands for one hidden number. The same symbol must have the same number everywhere it occurs. Use the displayed equations to work out the values, then drag a number onto one hidden occurrence of a symbol: all its hidden copies receive that value together. Tap a placed copy to remove that symbol’s assignment.",
    rulesDe:
        "Jedes Symbol steht für eine verborgene Zahl. Dasselbe Symbol braucht an jeder Stelle denselben Wert. Ermittle die Werte aus den angezeigten Gleichungen und ziehe eine Zahl auf ein verdecktes Vorkommen eines Symbols: Alle seine verdeckten Kopien erhalten diesen Wert gemeinsam. Tippe auf eine belegte Kopie, um die Zuweisung dieses Symbols zu entfernen.",
    boardEn: "★ + 3 = 8\n2 × ★ = ●\nAvailable choices are pairs(★,●).",
    boardDe: "★ + 3 = 8\n2 × ★ = ●\nDie Antworten sind Paare(★,●).",
    questionEn: "Which pair can fill all occurrences consistently?",
    questionDe: "Welches Paar passt einheitlich an alle Stellen?",
    optionsEn: ["★=8,●=16", "★=5,●=7", "★=5,●=10"],
    optionsDe: ["★=8,●=16", "★=5,●=7", "★=5,●=10"],
    correctIndex: 2,
    explanationEn:
        "★=8−3=5. Use that SAME 5 in the second equation: 2×5=10, so ●=10. Copying 8 fails the first equation; 7 adds 2 instead of multiplying.",
    explanationDe:
        "★=8−3=5. Nutze GENAU diese 5 auch in der zweiten Gleichung: 2×5=10, also ●=10. Die 8 zu kopieren verletzt die erste Gleichung; 7 addiert 2 statt zu multiplizieren.",
    focusEn: "Find a symbol in an equation whose other numbers are known.",
    focusDe:
        "Suche ein Symbol in einer Gleichung, deren andere Zahlen bekannt sind.",
    strategyEn:
        "Solve that equation, then substitute the value in every equation containing the same symbol. Assign the symbol once; its hidden copies update together. If the equations disagree, revisit an earlier placement instead of assigning a second value to that symbol.",
    strategyDe:
        "Löse diese Gleichung und setze den Wert in jede Gleichung mit demselben Symbol ein. Weise dem Symbol einmal den Wert zu; seine verdeckten Kopien ändern sich gemeinsam. Widersprechen sich Gleichungen, prüfe eine frühere Platzierung, statt dem Symbol einen zweiten Wert zu geben.",
  ),
  "cryptex_lock_breaker": PracticeLesson(
    rulesEn:
        "Adjust the numbered dials until ALL displayed equations are true at the same time. A named dial has the same current value wherever it appears. Turn a dial or drop a number on it. Finishing just one equation does not unlock the cryptex; finish the adjustment to commit it. For minus, use the positive difference. For division, this lock counts how many whole groups of the second value fit into the first.",
    rulesDe:
        "Stelle die Zahlenräder so ein, dass ALLE angezeigten Gleichungen gleichzeitig stimmen. Ein benanntes Rad hat überall denselben aktuellen Wert. Drehe ein Rad oder lege eine Zahl darauf. Eine richtige Gleichung allein öffnet die Cryptex nicht; beende die Einstellung, um sie zu übernehmen. Bei Minus zählt der positive Unterschied. Bei Division zählt dieses Schloss, wie oft der zweite Wert vollständig in den ersten passt.",
    boardEn: "Equations: A+B=9 and B×C=12.\nCurrent dials: A=5, B=4, C=2.",
    boardDe: "Gleichungen: A+B=9 und B×C=12.\nAktuelle Räder: A=5, B=4, C=2.",
    questionEn: "Which single dial adjustment makes BOTH equations true?",
    questionDe:
        "Welche einzelne Radeinstellung macht BEIDE Gleichungen richtig?",
    optionsEn: ["Set C to 3", "Set B to 6", "Set A to 7"],
    optionsDe: ["Stelle C auf 3", "Stelle B auf 6", "Stelle A auf 7"],
    correctIndex: 0,
    explanationEn:
        "A+B is already 5+4=9. Keep those dials and set C=3 so 4×3=12. Setting B=6 fixes the product with C=2 but breaks the sum; changing A breaks the sum without fixing the product.",
    explanationDe:
        "A+B stimmt schon: 5+4=9. Lass diese Räder stehen und setze C=3, damit 4×3=12. B=6 repariert zwar das Produkt mit C=2, zerstört aber die Summe. Ein anderes A zerstört die Summe und repariert das Produkt nicht.",
    focusEn:
        "Find an incorrect equation and note which dials it shares with correct equations.",
    focusDe:
        "Suche eine falsche Gleichung und prüfe, welche Räder sie mit richtigen Gleichungen teilt.",
    strategyEn:
        "Prefer changing a dial that fixes the incorrect equation while preserving the correct ones. After each committed adjustment, substitute the actual dial values into every affected equation. Green in one equation is only partial progress.",
    strategyDe:
        "Ändere möglichst ein Rad, das die falsche Gleichung repariert und die richtigen erhält. Setze nach jeder abgeschlossenen Einstellung die tatsächlichen Radwerte in alle betroffenen Gleichungen ein. Eine grüne Gleichung ist nur ein Teilerfolg.",
  ),
  "kenken": PracticeLesson(
    rulesEn:
        "In an N×N grid, put 1 to N exactly once in each row and column. The cells inside each outlined cage must also make its target using the printed operation. A one-cell cage gives its value. Subtraction uses the positive difference; division uses the larger divided by the smaller without remainder.",
    rulesDe:
        "In einem N×N-Gitter stehen 1 bis N genau einmal in jeder Zeile und Spalte. Die Felder jedes umrandeten Käfigs müssen zusätzlich mit der angegebenen Rechenart dessen Zielzahl ergeben. Ein Einzelfeld gibt seinen Wert vor. Bei Minus zählt der positive Unterschied, bei Division der größere Wert geteilt durch den kleineren ohne Rest.",
    boardEn:
        "4×4 grid. Row: [1,2,□,4].\nThe gap shares a two-cell cage marked 6× with a cell containing 2.",
    boardDe:
        "4×4-Gitter. Zeile: [1,2,□,4].\nDie Lücke gehört mit einem Feld mit 2 zu einem Zweierkäfig mit der Angabe 6×.",
    questionEn: "Which number satisfies BOTH the row and the cage?",
    questionDe:
        "Welche Zahl erfüllt SOWOHL die Zeilenregel als auch den Käfig?",
    optionsEn: ["4", "3", "2"],
    optionsDe: ["4", "3", "2"],
    correctIndex: 1,
    explanationEn:
        "3 is missing from the row and 2×3=6. 4 would repeat 4 and give 8 in the cage; 2 would repeat 2 and give 4. A cage result alone never replaces the row and column rules.",
    explanationDe:
        "3 fehlt in der Zeile und 2×3=6. 4 würde die 4 wiederholen und im Käfig 8 ergeben; 2 würde die 2 wiederholen und 4 ergeben. Ein passendes Käfigergebnis ersetzt nie die Zeilen- und Spaltenregeln.",
    focusEn:
        "Combine one small cage with the missing numbers in its rows and columns.",
    focusDe:
        "Verknüpfe einen kleinen Käfig mit den fehlenden Zahlen seiner Zeilen und Spalten.",
    strategyEn:
        "List number combinations that reach the cage target, then remove any that repeat a number in a row or column. For two-cell subtraction or division cages, try both placements of a valid pair before deciding.",
    strategyDe:
        "Suche Zahlenkombinationen für die Käfigvorgabe und streiche alle, die eine Zahl in einer Zeile oder Spalte wiederholen. Bei Zweierkäfigen mit Minus oder Division prüfst du beide Anordnungen eines passenden Paares.",
  ),
  "nebula_matrix": PracticeLesson(
    rulesEn:
        "Fill an N×N grid with 1 to N, once in every row and column. When regions are drawn, each region must also contain 1 to N once. Drag numbers into empty cells. A number allowed by its row may still be forbidden by its column or region.",
    rulesDe:
        "Fülle ein N×N-Gitter mit 1 bis N, jede Zahl einmal pro Zeile und Spalte. Sind Bereiche eingezeichnet, braucht auch jeder Bereich 1 bis N je einmal. Ziehe Zahlen in leere Felder. Eine Zahl kann in der Zeile passen und trotzdem in Spalte oder Bereich verboten sein.",
    boardEn:
        "4×4 grid, gap at row 1, column 2.\nRow 1: [1,□,3,4]\nColumn 2 already contains 1,3,4.\nIts 2×2 region already contains 1,3,4.",
    boardDe:
        "4×4-Gitter, Lücke in Zeile 1, Spalte 2.\nZeile 1: [1,□,3,4]\nSpalte 2 enthält schon 1,3,4.\nIhr 2×2-Bereich enthält schon 1,3,4.",
    questionEn:
        "Which number can you place without repeating a number in any of the three groups?",
    questionDe:
        "Welche Zahl kannst du einsetzen, ohne in einer der drei Gruppen eine Zahl zu wiederholen?",
    optionsEn: ["2", "3", "4"],
    optionsDe: ["2", "3", "4"],
    correctIndex: 0,
    explanationEn:
        "2 is the only missing number in the row, column and region. 3 or 4 would repeat an existing number in all three groups. Region checks apply when that board has regions; some sizes have none.",
    explanationDe:
        "2 ist die einzige fehlende Zahl in Zeile, Spalte und Bereich. 3 oder 4 würde in allen drei Gruppen eine Zahl wiederholen. Die Bereichsregel gilt für Spielbretter mit Bereichen; manche Größen haben keine.",
    focusEn: "Choose a gap and inspect its row, column and any drawn region.",
    focusDe:
        "Wähle eine Lücke und prüfe ihre Zeile, Spalte und einen eventuell eingezeichneten Bereich.",
    strategyEn:
        "Start with 1 to N and cross out every number already present in those groups. If one candidate remains, place it. If several remain, find a more constrained gap rather than guessing from the row alone.",
    strategyDe:
        "Beginne mit 1 bis N und streiche jede Zahl, die in einer dieser Gruppen vorkommt. Bleibt genau eine, setze sie ein. Bleiben mehrere, suche eine stärker eingeschränkte Lücke, statt nur anhand der Zeile zu raten.",
  ),
  "gravity_well": PracticeLesson(
    rulesEn:
        "Every shown scale is balanced: both sides have the same total weight. Identical lettered objects have the same weight on every scale. Work out all unknown weights, tap each answer field to enter its value, then check the balance.",
    rulesDe:
        "Jede gezeigte Waage ist im Gleichgewicht: Beide Seiten wiegen insgesamt gleich viel. Gleich bezeichnete Objekte haben auf jeder Waage dasselbe Gewicht. Ermittle alle unbekannten Gewichte, tippe auf ihre Antwortfelder und prüfe anschließend das Gleichgewicht.",
    boardEn: "Scale 1: A+2 kg balances 8 kg.\nScale 2: A+B balances 10 kg.",
    boardDe:
        "Waage 1: A+2 kg gleicht 8 kg aus.\nWaage 2: A+B gleicht 10 kg aus.",
    questionEn: "Which pair of weights balances BOTH scales?",
    questionDe: "Welches Gewichtspaar bringt BEIDE Waagen ins Gleichgewicht?",
    optionsEn: ["A=8 kg, B=2 kg", "A=6 kg, B=10 kg", "A=6 kg, B=4 kg"],
    optionsDe: ["A=8 kg, B=2 kg", "A=6 kg, B=10 kg", "A=6 kg, B=4 kg"],
    correctIndex: 2,
    explanationEn:
        "From scale 1, A=8−2=6 kg. Use that same 6 kg in scale 2: B=10−6=4 kg. Copying 8 ignores the extra 2 kg; copying 10 ignores A on the second scale.",
    explanationDe:
        "Aus Waage 1 folgt A=8−2=6 kg. Nutze dieselben 6 kg in Waage 2: B=10−6=4 kg. Die 8 zu übernehmen übergeht die zusätzlichen 2 kg; die 10 zu übernehmen übergeht A auf Waage 2.",
    focusEn: "Find a scale with only one unknown object type.",
    focusDe: "Suche eine Waage mit nur einer unbekannten Objektsorte.",
    strategyEn:
        "Remove equal known weights from both sides. If several identical unknown objects remain, divide the remaining weight by their count. Substitute the result on the other scales before entering and checking every answer.",
    strategyDe:
        "Nimm auf beiden Seiten gleich viel bekanntes Gewicht weg. Bleiben mehrere gleiche unbekannte Objekte, teile das verbleibende Gewicht durch ihre Anzahl. Setze das Ergebnis in die anderen Waagen ein, bevor du alle Antworten eingibst und prüfst.",
  ),
  "galactic_market": PracticeLesson(
    rulesEn:
        "The total change contains the visible coins AND several identical hidden coins. Find the value of ONE hidden coin: subtract the visible coins from the total, then divide the remainder by the number of hidden coins. Select that denomination and submit it.",
    rulesDe:
        "Das gesamte Wechselgeld besteht aus den sichtbaren Münzen UND mehreren gleichen verdeckten Münzen. Suche den Wert EINER verdeckten Münze: Ziehe die sichtbaren Münzen von der Gesamtsumme ab und teile den Rest durch die Anzahl verdeckter Münzen. Wähle diesen Münzwert und bestätige ihn.",
    boardEn:
        "Total change 22. Visible coins: 5 and 2.\nThere are 3 identical hidden coins.",
    boardDe:
        "Wechselgeld insgesamt 22. Sichtbare Münzen: 5 und 2.\nEs gibt 3 gleiche verdeckte Münzen.",
    questionEn: "Which value should you select for EACH hidden coin?",
    questionDe: "Welchen Wert musst du für JEDE verdeckte Münze auswählen?",
    optionsEn: ["15", "7", "5"],
    optionsDe: ["15", "7", "5"],
    correctIndex: 2,
    explanationEn:
        "Visible coins total 7; 22−7=15 remains for all 3 hidden coins. Each is 15÷3=5. 15 is their combined value; 7 is the visible total, not one hidden coin.",
    explanationDe:
        "Die sichtbaren Münzen ergeben 7; 22−7=15 bleiben für alle 3 verdeckten Münzen. Jede hat den Wert 15÷3=5. 15 ist ihr gemeinsamer Wert; 7 ist die sichtbare Summe, nicht der Wert einer verdeckten Münze.",
    focusEn: "Separate the visible coin total from the hidden coin total.",
    focusDe: "Trenne den Wert der sichtbaren von dem der verdeckten Münzen.",
    strategyEn:
        "Add the visible coins first. Subtract that from the displayed change, then divide by the hidden coin count. Check by multiplying your chosen denomination by that count and adding the visible total back.",
    strategyDe:
        "Addiere zuerst die sichtbaren Münzen. Ziehe diese Summe vom Wechselgeld ab und teile durch die Anzahl verdeckter Münzen. Prüfe durch Rückwärtsrechnen: gewählter Münzwert mal Anzahl plus sichtbare Summe.",
  ),
  "chrono_repair": PracticeLesson(
    rulesEn:
        "Read the broken clock and its malfunction message. Recover the actual time by undoing that fault, then select the corrected hour and minute and check. For a clock running ahead, subtract the stated offset, carrying across hours and 12 as needed. For a mirrored clock, reflect the whole hand positions; do not mirror hour and minute separately.",
    rulesDe:
        "Lies die defekte Uhr und ihre Fehlermeldung. Mache den Fehler rückgängig, wähle dann die richtige Stunde und Minute und prüfe. Geht die Uhr vor, ziehe den angegebenen Vorsprung ab und beachte Stundenwechsel und den Übergang über 12. Spiegele bei einer gespiegelten Uhr die ganzen Zeigerpositionen, nicht Stunde und Minute getrennt.",
    boardEn:
        "Broken clock shows 3:10.\nMessage: the clock is 1 hour 30 minutes AHEAD.",
    boardDe:
        "Die defekte Uhr zeigt 3:10.\nMeldung: Die Uhr geht 1 Stunde 30 Minuten VOR.",
    questionEn: "Which corrected time should you select?",
    questionDe: "Welche richtige Zeit musst du auswählen?",
    optionsEn: ["4:40", "1:40", "2:40"],
    optionsDe: ["4:40", "1:40", "2:40"],
    correctIndex: 1,
    explanationEn:
        "Undo the advance: 3:10−1 hour=2:10; subtract 30 minutes to reach 1:40. 4:40 adds the fault again; 2:40 handles the minute borrowing incorrectly.",
    explanationDe:
        "Mache den Vorsprung rückgängig: 3:10−1 Stunde=2:10; weitere 30 Minuten zurück ergeben 1:40. 4:40 addiert den Fehler erneut; 2:40 behandelt den Stundenwechsel beim Minutenabzug falsch.",
    focusEn: "First read which fault the message describes: advance or mirror.",
    focusDe:
        "Lies zuerst, welchen Fehler die Meldung beschreibt: Vorsprung oder Spiegelung.",
    strategyEn:
        "For an advance, work backwards on the 12-hour clock, subtracting minutes and hours with correct borrowing. For a mirror, reflect both hands together across the vertical axis; for example, mirrored 8:20 corresponds to 3:40. Check the selected hour AND minute.",
    strategyDe:
        "Gehe bei einem Vorsprung auf der 12-Stunden-Uhr rückwärts und ziehe Minuten und Stunden mit richtigem Stundenwechsel ab. Spiegele bei einer Spiegelung beide Zeiger gemeinsam an der senkrechten Achse; gespiegelte 8:20 entspricht zum Beispiel 3:40. Prüfe die gewählte Stunde UND Minute.",
  ),
  "vault_cracker": PracticeLesson(
    rulesEn:
        "Use every written clue to deduce the secret code in the correct order. Enter one allowed digit in each position and submit. After a guess, green means correct digit and position, yellow means the digit belongs elsewhere, and gray means no unmatched copy remains. Repeated digits must follow the clues; do not assume they are forbidden.",
    rulesDe:
        "Nutze alle geschriebenen Hinweise, um den Geheimcode in der richtigen Reihenfolge zu finden. Gib an jeder Stelle eine erlaubte Ziffer ein und bestätige. Nach einem Versuch bedeutet Grün richtige Ziffer und Stelle, Gelb die Ziffer gehört woandershin und Grau es bleibt kein unzugeordnetes Vorkommen übrig. Ob Ziffern mehrfach vorkommen dürfen, bestimmen die Hinweise.",
    boardEn:
        "Three-digit code, digits 1–5.\nFirst digit is 2.\nSum of all digits is 6.\nThird digit is the sum of the first two.",
    boardDe:
        "Dreistelliger Code, Ziffern 1–5.\nDie erste Ziffer ist 2.\nDie Summe aller Ziffern ist 6.\nDie dritte Ziffer ist die Summe der ersten beiden.",
    questionEn: "Which candidate obeys EVERY clue?",
    questionDe: "Welcher Kandidat erfüllt JEDEN Hinweis?",
    optionsEn: ["2,3,4", "2,1,3", "2,2,4"],
    optionsDe: ["2,3,4", "2,1,3", "2,2,4"],
    correctIndex: 1,
    explanationEn:
        "2,1,3 satisfies all clues: first 2, total 2+1+3=6 and third 3=2+1. 2,3,4 has total 9 and 4≠2+3; 2,2,4 satisfies the third-digit relation but totals 8.",
    explanationDe:
        "2,1,3 erfüllt alles: zuerst 2, insgesamt 2+1+3=6 und dritte Ziffer 3=2+1. 2,3,4 ergibt 9 und 4≠2+3; 2,2,4 erfüllt die dritte Bedingung, ergibt aber 8.",
    focusEn: "Combine the strongest clues before submitting a code.",
    focusDe:
        "Verknüpfe die stärksten Hinweise, bevor du einen Code abschickst.",
    strategyEn:
        "Use exact-position clues first, then test the remaining digits against every sum, comparison and parity clue. After a guess, keep green positions and reconsider yellow positions; duplicate matches use up individual copies.",
    strategyDe:
        "Beginne mit genauen Positionshinweisen und prüfe die übrigen Ziffern gegen jede Summe, jeden Vergleich und jede Gerade-Ungerade-Bedingung. Behalte nach einem Versuch grüne Stellen und überdenke gelbe. Bei mehrfachen Ziffern wird jedes Vorkommen nur einmal zugeordnet.",
  ),
  "launch_sequence": PracticeLesson(
    rulesEn:
        "Put the numbered launch modules in the displayed target order from left to right. Drag a module to another position, shifting the modules between them; or tap two neighbouring modules to swap them. Tapping distant modules does not swap them. A long drag counts each position crossed, so fix out-of-order pairs deliberately.",
    rulesDe:
        "Bringe die nummerierten Startmodule von links nach rechts in die angezeigte Zielreihenfolge. Ziehe ein Modul an eine andere Stelle; die Module dazwischen rücken weiter. Oder tippe zwei benachbarte Module zum Tauschen an. Entfernte Module lassen sich nicht durch Antippen tauschen. Ein langer Zug zählt jede überquerte Stelle; löse falsche Paare gezielt.",
    boardEn: "Target: [1,2,3,4]\nCurrent: [1,3,2,4]",
    boardDe: "Ziel: [1,2,3,4]\nAktuell: [1,3,2,4]",
    questionEn: "Which legal action immediately completes the target order?",
    questionDe: "Welche erlaubte Aktion stellt sofort die Zielreihenfolge her?",
    optionsEn: [
      "Tap 1, then 4 to swap them",
      "Drag 4 to the beginning",
      "Tap 3, then neighbouring 2",
    ],
    optionsDe: [
      "Tippe 1, dann 4 zum Tauschen an",
      "Ziehe 4 an den Anfang",
      "Tippe 3, dann die benachbarte 2 an",
    ],
    correctIndex: 2,
    explanationEn:
        "Swapping adjacent 3 and 2 produces[1,2,3,4]. 1 and 4 are not neighbours, so that tap pair cannot swap; moving 4 to the front creates more disorder.",
    explanationDe:
        "Der Tausch der benachbarten 3 und 2 ergibt[1,2,3,4]. 1 und 4 sind nicht benachbart und lassen sich so nicht tauschen. Die 4 an den Anfang zu ziehen erzeugt weitere Unordnung.",
    focusEn: "Find two neighbours that appear in the wrong target order.",
    focusDe: "Suche zwei Nachbarn, die entgegen der Zielreihenfolge stehen.",
    strategyEn:
        "Swap that adjacent inverted pair, or drag the next required module into place while checking what shifts between. Compare with the target after every move. A distant tap pair is not a valid swap; use a drag for that movement.",
    strategyDe:
        "Tausche dieses benachbarte falsche Paar oder ziehe das als Nächstes benötigte Modul an seine Stelle und beachte die nachrückenden Module. Vergleiche nach jedem Zug mit dem Ziel. Zwei entfernte Module werden nicht durch Antippen getauscht; dafür brauchst du eine Ziehbewegung.",
  ),
};
