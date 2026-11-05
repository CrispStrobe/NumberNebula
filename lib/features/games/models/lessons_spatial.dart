import 'practice_lesson.dart';

// Mechanic-specific practice examples audited against the screens and models.
const Map<String, PracticeLesson> spatialLessons = {
  "block_counter": PracticeLesson(
    rulesEn:
        "Count every cube in the structure, including cubes hidden behind or underneath others. Move the view to inspect the stacks, choose a total, then check your answer.",
    rulesDe:
        "Zähle alle Würfel des Bauwerks, auch verdeckte Würfel hinter oder unter anderen. Bewege die Ansicht, untersuche die Stapel und wähle dann die Gesamtzahl.",
    boardEn:
        "Top view: each number is the full height of one stack.\n2  1\n0  3\n0 means no cubes.",
    boardDe:
        "Draufsicht: Jede Zahl ist die ganze Höhe eines Stapels.\n2  1\n0  3\n0 bedeutet: kein Würfel.",
    questionEn: "How many cubes belong to this structure?",
    questionDe: "Wie viele Würfel gehören zu diesem Bauwerk?",
    explanationEn:
        "2 + 1 + 0 + 3 = 6 cubes. Three occupied floor squares do not mean three cubes: two stacks contain several. The empty floor square contributes zero.",
    explanationDe:
        "2 + 1 + 0 + 3 = 6 Würfel. Drei belegte Bodenfelder sind nicht drei Würfel: Zwei Stapel sind höher als eins. Das leere Bodenfeld zählt null.",
    focusEn: "Look for stacks whose lower cubes are hidden.",
    focusDe: "Achte auf Stapel mit verdeckten unteren Würfeln.",
    strategyEn:
        "Count one stack at a time and keep a subtotal. Count solid cubes, not visible faces; one cube can show several faces.",
    strategyDe:
        "Zähle Stapel für Stapel und merke dir die Zwischensumme. Zähle ganze Würfel statt sichtbarer Flächen: Ein Würfel kann mehrere Flächen zeigen.",
    optionsEn: [
      "3: count only the occupied floor squares",
      "6: add all stack heights",
      "4: count the four floor squares",
    ],
    optionsDe: [
      "3: nur die belegten Bodenfelder zählen",
      "6: alle Stapelhöhen addieren",
      "4: die vier Bodenfelder zählen",
    ],
    correctIndex: 1,
  ),
  "perspective_puzzle": PracticeLesson(
    rulesEn:
        "Choose the flat picture seen from the named viewing direction. A nearer cube hides a cube directly behind it at the same height. Match both occupied squares and their colors.",
    rulesDe:
        "Wähle das flache Bild aus der gefragten Blickrichtung. Ein näherer Würfel verdeckt einen Würfel direkt dahinter auf gleicher Höhe. Lage und Farben müssen stimmen.",
    boardEn:
        "Look from the FRONT. Two cubes stand one directly behind the other at the same height: blue is nearer to you, red is behind blue. There are no other cubes.",
    boardDe:
        "Blick von VORNE. Zwei Würfel stehen auf gleicher Höhe direkt hintereinander: Blau steht näher bei dir, Rot hinter Blau. Es gibt keine weiteren Würfel.",
    questionEn: "What appears in that square of the front picture?",
    questionDe: "Was siehst du an dieser Stelle im Bild von vorne?",
    explanationEn:
        "The nearer blue cube covers the red cube along this line of sight. Red is still part of the structure, but does not appear beside blue or through it.",
    explanationDe:
        "Der nähere blaue Würfel verdeckt den roten in dieser Blickrichtung. Rot gehört weiterhin zum Bauwerk, erscheint aber weder neben Blau noch durch Blau hindurch.",
    focusEn: "Check the requested direction before comparing the pictures.",
    focusDe: "Prüfe zuerst, von welcher Seite du schauen sollst.",
    strategyEn:
        "Trace one line of sight at a time. Keep the nearest color in each visible position; do not count hidden cubes as extra squares.",
    strategyDe:
        "Verfolge eine Blicklinie nach der anderen. Merke dir jeweils die vorderste Farbe. Verdeckte Würfel ergeben keine zusätzlichen Bildfelder.",
    optionsEn: [
      "One blue square",
      "One red square",
      "A blue square beside a red square",
    ],
    optionsDe: [
      "Ein blaues Quadrat",
      "Ein rotes Quadrat",
      "Ein blaues Quadrat neben einem roten",
    ],
    correctIndex: 0,
  ),
  "hull_plating": PracticeLesson(
    rulesEn:
        "Cover every active hull square with the pieces in the tray. Use Rotate to turn the tray pieces, then drag a piece onto the hull. Pieces may not overlap, leave the board or cover a hole. Tap a placed piece to remove it.",
    rulesDe:
        "Bedecke alle aktiven Rumpffelder mit den Teilen aus der Ablage. Drehe mit Drehen die Teile in der Ablage und ziehe dann eines auf den Rumpf. Teile dürfen sich nicht überlappen, über den Rand ragen oder Löcher bedecken. Tippe ein gelegtes Teil zum Entfernen an.",
    boardEn:
        "A local gap, viewed from above:\n. #\n. #\n. = uncovered hull, # = hole.\nThe remaining two-square piece is horizontal: [X X].",
    boardDe:
        "Eine Lücke von oben:\n. #\n. #\n. = freier Rumpf, # = Loch.\nDas übrige Zweierstück liegt waagerecht: [X X].",
    questionEn: "How can this piece cover the gap?",
    questionDe: "Wie deckt dieses Teil die Lücke ab?",
    explanationEn:
        "After a quarter turn, both squares fit the vertical gap. A horizontal placement covers a hole, and a square outside the board is also illegal. Rotation changes orientation, not the number of squares.",
    explanationDe:
        "Nach einer Vierteldrehung passen beide Felder in die senkrechte Lücke. Waagerecht würde ein Loch bedeckt. Über den Rand zu legen ist ebenfalls verboten. Drehen ändert die Lage, nicht die Anzahl der Felder.",
    focusEn: "Compare the whole outline of a piece with the gap.",
    focusDe: "Vergleiche den ganzen Umriss des Teils mit der Lücke.",
    strategyEn:
        "Start with narrow corners and gaps. Before placing, trace every square of the rotated piece and check that each lands on uncovered hull.",
    strategyDe:
        "Beginne mit schmalen Ecken und Lücken. Gehe vor dem Legen jedes Feld des gedrehten Teils durch: Es muss auf freiem Rumpf landen.",
    optionsEn: [
      "Place it horizontally across the top row",
      "Place one square outside the board",
      "Rotate it to stand vertically, then cover both dots",
    ],
    optionsDe: [
      "Waagerecht über die obere Zeile legen",
      "Ein Feld über den Rand legen",
      "Senkrecht drehen und beide Punkte bedecken",
    ],
    correctIndex: 2,
  ),
  "relic_assembly": PracticeLesson(
    rulesEn:
        "Fill the grid with every tile once. Drag a tile into a space, or select it and tap a space. Tap a placed tile to turn it; its × removes it. Match the numbers on every shared edge: right with left, bottom with top. Outside edges have no frame rule.",
    rulesDe:
        "Fülle das Raster mit jeder Kachel einmal. Ziehe eine Kachel auf ein Feld oder wähle sie und tippe ein freies Feld an. Antippen dreht eine gelegte Kachel; ihr × entfernt sie. An gemeinsamen Kanten müssen gleiche Zahlen liegen: rechts an links, unten an oben. Für Außenkanten gibt es keine Rahmenregel.",
    boardEn:
        "The tile already on the left has a 3 on its right edge.\nThe tile to its right has these edges:\ntop: 3 | right: 2 | bottom: 1 | left: 4.",
    boardDe:
        "Die linke Kachel zeigt rechts die Zahl 3.\nDie Kachel rechts daneben hat diese Kanten:\noben: 3 | rechts: 2 | unten: 1 | links: 4.",
    questionEn:
        "How should you turn the right tile so this shared edge matches?",
    questionDe:
        "Wie drehst du die rechte Kachel, damit diese gemeinsame Kante passt?",
    explanationEn:
        "The 3 must move from the top edge to the left edge. A counterclockwise quarter turn does that. No turn leaves 4 on the shared edge; a clockwise turn puts 1 there. Check other neighbors too before finishing.",
    explanationDe:
        "Die 3 muss von oben nach links wandern. Das schafft eine Vierteldrehung nach links. Ohne Drehung liegt dort die 4; nach rechts gedreht die 1. Prüfe vor dem Abschluss auch die anderen Nachbarn.",
    focusEn: "Compare the two edges that actually touch.",
    focusDe: "Vergleiche genau die beiden Kanten, die sich berühren.",
    strategyEn:
        "Choose a cell with two already placed neighbors. Turn a candidate mentally and check both shared edges before placing it.",
    strategyDe:
        "Wähle ein Feld mit zwei bereits belegten Nachbarn. Drehe eine mögliche Kachel im Kopf und prüfe beide gemeinsamen Kanten vor dem Legen.",
    optionsEn: [
      "Leave it as it is",
      "One quarter turn counterclockwise (or three clockwise)",
      "One quarter turn clockwise",
    ],
    optionsDe: [
      "Unverändert lassen",
      "Eine Vierteldrehung nach links (oder drei nach rechts)",
      "Eine Vierteldrehung nach rechts",
    ],
    correctIndex: 1,
  ),
  "grid_filler_game": PracticeLesson(
    rulesEn:
        "Fill the square board with the square pieces from the tray. Each type shows its side length and how many remain. Select a type and place it, or drag a piece; you can move or remove placed pieces. No overlaps or parts outside the board.",
    rulesDe:
        "Fülle das quadratische Brett mit den quadratischen Teilen aus der Ablage. Jede Sorte zeigt Seitenlänge und Restanzahl. Wähle eine Sorte und lege sie oder ziehe ein Teil. Gelegte Teile kannst du verschieben oder entfernen. Kein Teil darf überlappen oder über den Rand ragen.",
    boardEn:
        "Only these gaps remain in a corner of the board:\n#..#\n#..#\n###.\n# = covered, . = empty.\nTray: one 2×2 square and one 1×1 square.",
    boardDe:
        "In einer Ecke bleiben nur diese Lücken:\n#..#\n#..#\n###.\n# = belegt, . = leer.\nAblage: ein 2×2-Quadrat und ein 1×1-Quadrat.",
    questionEn: "Which plan uses both remaining pieces and fills every gap?",
    questionDe: "Welcher Plan benutzt beide Restteile und füllt alle Lücken?",
    explanationEn:
        "The four adjacent empty squares make exactly one 2×2 space; the separate empty square takes 1×1. Using 1×1 in the larger gap strands the 2×2 piece. Overlapping covered squares is illegal.",
    explanationDe:
        "Die vier zusammenhängenden freien Felder bilden genau Platz für 2×2. Das einzelne Feld braucht 1×1. Legst du 1×1 in die größere Lücke, bleibt kein Platz für 2×2. Belegte Felder zu überdecken ist verboten.",
    focusEn: "Compare the remaining piece sizes with the shapes of the gaps.",
    focusDe: "Vergleiche die Größen der Restteile mit den Formen der Lücken.",
    strategyEn:
        "Reserve a place for large squares first. A 3×3 piece needs three clear rows and three clear columns together, not just nine scattered empty cells.",
    strategyDe:
        "Halte zuerst Platz für große Quadrate frei. Ein 3×3-Teil braucht drei freie Zeilen und drei freie Spalten zusammen, nicht bloß neun verstreute Felder.",
    optionsEn: [
      "Put 2×2 in the four-square gap; put 1×1 in the single gap",
      "Put 1×1 inside the four-square gap first",
      "Put 2×2 over the single gap and covered squares",
    ],
    optionsDe: [
      "2×2 in die Viererlücke; 1×1 ins einzelne Feld",
      "1×1 zuerst mitten in die Viererlücke legen",
      "2×2 über das einzelne und bereits belegte Felder legen",
    ],
    correctIndex: 0,
  ),
  "quantum_molecule_builder": PracticeLesson(
    rulesEn:
        "Arrange the atoms like the target picture. Select an atom and send it up, down, left or right: it slides until a wall, another atom or the board edge stops it. You cannot stop it halfway. Match the shown atom types and empty target spaces within the move allowance.",
    rulesDe:
        "Ordne die Atome wie im Zielbild an. Wähle ein Atom und schicke es hoch, runter, nach links oder rechts: Es gleitet bis zu einer Wand, einem anderen Atom oder dem Rand. Du kannst es unterwegs nicht anhalten. Atomarten und leere Zielfelder müssen innerhalb des Zuglimits passen.",
    boardEn:
        "One row, from left to right:\n# H . . O #\n# = wall; . = empty.\nH is selected. O stays still.",
    boardDe:
        "Eine Zeile von links nach rechts:\n# H . . O #\n# = Wand; . = leer.\nH ist ausgewählt. O bleibt stehen.",
    questionEn: "Where does H stop after one move to the right?",
    questionDe: "Wo hält H nach einem Zug nach rechts?",
    explanationEn:
        "H crosses both empty spaces and stops directly before O: # . . H O #. One slide counts as one move, even across several squares. H cannot stop early or pass through O.",
    explanationDe:
        "H überquert beide freien Felder und hält direkt vor O: # . . H O #. Auch über mehrere Felder zählt das Gleiten als ein Zug. H kann weder früher anhalten noch durch O hindurch.",
    focusEn: "Find the stopping square before moving an atom.",
    focusDe: "Finde vor dem Zug das Feld, auf dem das Atom anhalten wird.",
    strategyEn:
        "Trace the selected direction to the first obstacle. Use walls and other atoms as stoppers to build the target arrangement; the target can fit at different places on the board. Undo adds a move penalty.",
    strategyDe:
        "Verfolge die Richtung bis zum ersten Hindernis. Nutze Wände und andere Atome als Stopper für das Zielmuster. Das Muster kann an verschiedenen Stellen des Bretts passen. Rückgängig kostet zusätzliche Züge.",
    optionsEn: [
      "On the first empty space",
      "On the same space as O",
      "On the empty space immediately to the left of O",
    ],
    optionsDe: [
      "Auf dem ersten freien Feld",
      "Auf demselben Feld wie O",
      "Auf dem freien Feld direkt links neben O",
    ],
    correctIndex: 2,
  ),
  "space_station_gridlock": PracticeLesson(
    rulesEn:
        "Free the player ship and slide it to the right-hand exit. Horizontal ships slide left or right; vertical ships slide up or down. Ships cannot turn, overlap or pass through each other. Fixed blockers stay still. Each moved square counts as a move.",
    rulesDe:
        "Befreie das Spielerschiff und schiebe es zum Ausgang rechts. Waagerechte Schiffe gleiten links oder rechts, senkrechte hoch oder runter. Schiffe können sich nicht drehen, überlappen oder durcheinander fahren. Feste Hindernisse bleiben stehen. Jedes verschobene Feld zählt als Zug.",
    boardEn:
        "Six columns; rows are numbered from the top:\n1: . . . . . .\n2: . . V . . .\n3: P P V . . . → exit\n4: . . . . . .\n5: . . . . . .\n6: . . . . . .\nP = horizontal player ship; V = one vertical ship of length 2.",
    boardDe:
        "Sechs Spalten; Zeilen von oben gezählt:\n1: . . . . . .\n2: . . V . . .\n3: P P V . . . → Ausgang\n4: . . . . . .\n5: . . . . . .\n6: . . . . . .\nP = waagerechtes Spielerschiff; V = ein senkrechtes Zweierschiff.",
    questionEn: "Which move clears row 3 for the player ship?",
    questionDe: "Welcher Zug macht Zeile 3 für das Spielerschiff frei?",
    explanationEn:
        "Moving V up puts it in rows 1 and 2, freeing row 3. Moving it down leaves it in rows 3 and 4, still in the way. A vertical ship cannot move sideways.",
    explanationDe:
        "Nach oben steht V in Zeile 1 und 2; Zeile 3 wird frei. Nach unten steht es in Zeile 3 und 4 und blockiert weiterhin. Ein senkrechtes Schiff kann nicht seitwärts fahren.",
    focusEn: "Follow the player ship’s row toward the right-hand exit.",
    focusDe: "Verfolge die Zeile des Spielerschiffs bis zum Ausgang rechts.",
    strategyEn:
        "Find the first blocker in the exit lane. Check which way it can slide completely out of that row, then clear the space it needs.",
    strategyDe:
        "Finde das erste Hindernis auf dem Weg zum Ausgang. Prüfe, wie es ganz aus dieser Zeile fahren kann. Schaffe dann den dafür nötigen Platz.",
    optionsEn: [
      "Move V one square up",
      "Move V one square down",
      "Move V one square right",
    ],
    optionsDe: [
      "V ein Feld nach oben schieben",
      "V ein Feld nach unten schieben",
      "V ein Feld nach rechts schieben",
    ],
    correctIndex: 0,
  ),
  "star_loader_game": PracticeLesson(
    rulesEn:
        "Walk the loader up, down, left or right and push boxes onto every target. A push moves one box one square if the square beyond is free. You cannot pull boxes or push two together. Undo lets you reconsider a move.",
    rulesDe:
        "Gehe mit dem Lader hoch, runter, links oder rechts und schiebe Kisten auf alle Zielfelder. Du kannst eine Kiste um ein Feld schieben, wenn das Feld dahinter frei ist. Ziehen oder zwei Kisten zugleich schieben geht nicht. Mit Rückgängig kannst du einen Zug zurücknehmen.",
    boardEn:
        "An enclosed corridor:\n# # # # # #\n# P B T . #\n# # # # # #\nP = player, B = box, T = target, # = wall.",
    boardDe:
        "Ein geschlossener Gang:\n# # # # # #\n# P B T . #\n# # # # # #\nP = Lader, B = Kiste, T = Ziel, # = Wand.",
    questionEn: "What puts the box on the target?",
    questionDe: "Wie kommt die Kiste aufs Ziel?",
    explanationEn:
        "The loader stands directly left of the box and the target to its right is free. Moving right pushes it onto T. Boxes cannot be pulled; walls block walking.",
    explanationDe:
        "Der Lader steht direkt links von der Kiste; das Ziel rechts daneben ist frei. Ein Schritt nach rechts schiebt sie auf T. Kisten lassen sich nicht ziehen; Wände blockieren den Weg.",
    focusEn: "Check the square beyond the box before pushing.",
    focusDe: "Prüfe vor dem Schieben das Feld hinter der Kiste.",
    strategyEn:
        "Plan where you must stand for the next push. Avoid pushing a box into a wall corner unless that corner is its target: you may not be able to stand behind it again.",
    strategyDe:
        "Plane, wo du für den nächsten Schub stehen musst. Schiebe eine Kiste nicht in eine Wandecke, außer dort ist ihr Ziel: Vielleicht kommst du danach nicht mehr hinter sie.",
    optionsEn: [
      "Move left and pull the box after you",
      "Move right once to push the box onto T",
      "Move up through the wall",
    ],
    optionsDe: [
      "Nach links gehen und die Kiste nachziehen",
      "Einmal nach rechts gehen und die Kiste auf T schieben",
      "Nach oben durch die Wand gehen",
    ],
    correctIndex: 1,
  ),
  "robot_path_game": PracticeLesson(
    rulesEn:
        "Build a command list, then run it to guide the robot to the goal. Forward moves one square in the direction the robot faces. Left and right turns change its facing without moving. Walls need the matching special command when one is available; an illegal command crashes the run.",
    rulesDe:
        "Baue eine Befehlsliste und starte sie, um den Roboter zum Ziel zu führen. Vorwärts geht ein Feld in seine Blickrichtung. Links- und Rechtsdrehung ändern nur die Blickrichtung. Für Hindernisse brauchst du den passenden Spezialbefehl, falls er verfügbar ist. Ein unerlaubter Befehl beendet den Lauf.",
    boardEn:
        "The robot faces RIGHT.\nR →  .  .\n#    #  G\nR = robot, G = goal, # = wall.\nIt must go two squares right, then one down.",
    boardDe:
        "Der Roboter schaut nach RECHTS.\nR →  .  .\n#    #  G\nR = Roboter, G = Ziel, # = Wand.\nEr muss zwei Felder nach rechts und dann ein Feld nach unten.",
    questionEn: "Which program reaches G?",
    questionDe: "Welches Programm erreicht G?",
    explanationEn:
        "Two forward commands reach the rightmost square. Facing right, a right turn points down; the final forward command reaches G. Turning after just one step faces a wall. A left turn points up, away from G.",
    explanationDe:
        "Zweimal Vorwärts führt zum rechten Feld. Wenn der Roboter nach rechts schaut, dreht Rechts ihn nach unten. Das letzte Vorwärts erreicht G. Schon nach einem Schritt zu drehen führt zur Wand. Links dreht nach oben, vom Ziel weg.",
    focusEn: "Keep track of where the robot faces after every turn.",
    focusDe: "Merke dir nach jeder Drehung die neue Blickrichtung.",
    strategyEn:
        "Trace your program one command at a time with a finger. Mark position and facing separately. A turn is relative to the robot, not a move toward the screen’s left or right edge.",
    strategyDe:
        "Gehe die Liste mit dem Finger Befehl für Befehl durch. Merke dir Ort und Blickrichtung getrennt. Eine Drehung richtet sich nach dem Roboter, nicht nach dem linken oder rechten Bildschirmrand.",
    optionsEn: [
      "Forward, Right turn, Forward, Forward",
      "Forward, Forward, Left turn, Forward",
      "Forward, Forward, Right turn, Forward",
    ],
    optionsDe: [
      "Vorwärts, Rechtsdrehung, Vorwärts, Vorwärts",
      "Vorwärts, Vorwärts, Linksdrehung, Vorwärts",
      "Vorwärts, Vorwärts, Rechtsdrehung, Vorwärts",
    ],
    correctIndex: 2,
  ),
  "warp_fold": PracticeLesson(
    rulesEn:
        "Watch which half folds over which, and where the cut is made in the folded sheet. Choose the picture after the sheet opens again. Each unfolding reflects the cut across that fold line. With several folds, undo the last fold first.",
    rulesDe:
        "Beobachte, welche Hälfte wohin gefaltet und wo das gefaltete Blatt ausgeschnitten wird. Wähle das Bild nach dem Aufklappen. Bei jedem Aufklappen wird der Schnitt an der Faltlinie gespiegelt. Bei mehreren Faltungen klappst du die letzte zuerst auf.",
    boardEn:
        "One fold only: the left half folds onto the right half along a VERTICAL center line. A small cut is made in the right half, away from the fold. The sheet then opens.",
    boardDe:
        "Nur eine Faltung: Die linke Hälfte wird an der SENKRECHTEN Mittellinie auf die rechte gefaltet. Ein kleiner Schnitt liegt in der rechten Hälfte, abseits der Falte. Dann wird aufgeklappt.",
    questionEn: "Where should you look for the matching cut?",
    questionDe: "Wo liegt der dazugehörige gespiegelte Schnitt?",
    explanationEn:
        "The crease is vertical, so reflection swaps left and right while keeping height. A cut above it would use a horizontal crease. Opening the sheet reveals cuts in the layers; it does not erase them.",
    explanationDe:
        "Die Falte steht senkrecht. Spiegeln tauscht deshalb links und rechts, die Höhe bleibt gleich. Ein Schnitt darüber würde zu einer waagerechten Falte gehören. Aufklappen zeigt die Schnitte in den Lagen und löscht sie nicht.",
    focusEn: "Find the axis of the last fold.",
    focusDe: "Suche die Achse der letzten Faltung.",
    strategyEn:
        "Work backward through the folds. At each step keep the existing cut and imagine its reflection on the other side of that crease. Compare the resulting pattern with the answer pictures.",
    strategyDe:
        "Gehe die Faltungen rückwärts durch. Behalte bei jedem Schritt den bisherigen Schnitt und stelle dir sein Spiegelbild jenseits der Falte vor. Vergleiche das Muster dann mit den Antwortbildern.",
    optionsEn: [
      "In the left half, at the same height and reflected across the fold",
      "Above the cut in the right half",
      "Nowhere: opening the sheet removes the cut",
    ],
    optionsDe: [
      "Links auf gleicher Höhe, an der Falte gespiegelt",
      "Über dem Schnitt in der rechten Hälfte",
      "Nirgends: Aufklappen entfernt den Schnitt",
    ],
    correctIndex: 0,
  ),
  "cube_scanner": PracticeLesson(
    rulesEn:
        "Read which die face or total the question asks for. On these dice, opposite faces add to 7: 1 opposite 6, 2 opposite 5, 3 opposite 4. For a roll question, follow the stated rolls before answering; a neighboring face is not the opposite face.",
    rulesDe:
        "Lies, nach welcher Würfelseite oder Summe gefragt wird. Bei diesen Würfeln ergeben gegenüberliegende Seiten 7: 1 gegenüber 6, 2 gegenüber 5, 3 gegenüber 4. Bei einer Rollaufgabe verfolge erst die angegebenen Bewegungen. Eine Nachbarseite ist nicht die Gegenseite.",
    boardEn:
        "A die shows 2 on TOP, 6 on FRONT and 3 on RIGHT. It does not roll. The question asks for the BOTTOM face.",
    boardDe:
        "Ein Würfel zeigt OBEN 2, VORNE 6 und RECHTS 3. Er wird nicht gerollt. Gesucht ist die UNTERSEITE.",
    questionEn: "Which number belongs on the bottom?",
    questionDe: "Welche Zahl steht unten?",
    explanationEn:
        "Bottom is opposite top, so 7 − 2 = 5. The face opposite front 6 is back 1, not bottom. The visible 3 is on the right and does not answer the question.",
    explanationDe:
        "Unten liegt gegenüber von oben: 7 − 2 = 5. Gegenüber von vorne 6 liegt hinten 1, nicht unten. Die sichtbare 3 liegt rechts und beantwortet die Frage nicht.",
    focusEn: "Name the requested face before calculating.",
    focusDe: "Benenne die gesuchte Seite, bevor du rechnest.",
    strategyEn:
        "For a hidden face, locate its opposite visible face. For rolls, update the top, bottom and side positions after each stated roll, then answer the requested face or sum.",
    strategyDe:
        "Suche bei einer verdeckten Seite zuerst die sichtbare Gegenseite. Bei Rollaufgaben aktualisierst du nach jeder Bewegung oben, unten und die Seiten. Beantworte erst danach die gefragte Seite oder Summe.",
    optionsEn: [
      "1, because front and bottom are opposite",
      "5, because top and bottom add to 7",
      "3, because it is already visible",
    ],
    optionsDe: [
      "1, weil vorne und unten gegenüberliegen",
      "5, weil oben und unten zusammen 7 ergeben",
      "3, weil die Zahl schon sichtbar ist",
    ],
    correctIndex: 1,
  ),
  "circuit_repair": PracticeLesson(
    rulesEn:
        "Repair the digital clock by swapping two whole digit positions. Tap one digit and then another, inspect the preview and confirm. You do not move individual light segments. Hours run from 00 to 23; minutes and seconds from 00 to 59.",
    rulesDe:
        "Repariere die Digitaluhr, indem du zwei ganze Ziffernplätze vertauschst. Tippe erst eine Ziffer, dann die andere an, prüfe die Vorschau und bestätige. Einzelne Leuchtstriche werden nicht verschoben. Stunden gehen von 00 bis 23, Minuten und Sekunden von 00 bis 59.",
    boardEn:
        "Displayed time: 71:23\nDigit positions from left: 1 2 : 3 4\nExactly two positions were swapped.",
    boardDe:
        "Angezeigt: 71:23\nZiffernplätze von links: 1 2 : 3 4\nGenau zwei Plätze wurden vertauscht.",
    questionEn: "Which swap repairs this clock?",
    questionDe: "Welcher Tausch repariert diese Uhr?",
    explanationEn:
        "17:23 is a valid time. The first choice leaves 73 minutes, which exceeds 59. The second leaves 73 hours, which exceeds 23. Swap whole positions, not digits you invent or individual segments.",
    explanationDe:
        "17:23 ist eine gültige Uhrzeit. Die erste Wahl ergibt 73 Minuten, also mehr als 59. Die zweite ergibt 73 Stunden, also mehr als 23. Tausche ganze Plätze statt erfundener Ziffern oder einzelner Leuchtstriche.",
    focusEn: "Find which time field is outside its allowed range.",
    focusDe:
        "Finde, welcher Teil der Uhrzeit außerhalb seines erlaubten Bereichs liegt.",
    strategyEn:
        "Try a pair in the preview and check every time field, not just the one that was invalid. Use Reset to reconsider the pair before confirming.",
    strategyDe:
        "Probiere ein Paar in der Vorschau und prüfe alle Teile der Uhrzeit, nicht nur den vorher ungültigen. Mit Zurücksetzen kannst du vor dem Bestätigen ein anderes Paar wählen.",
    optionsEn: [
      "Positions 1 and 3 → 21:73",
      "Positions 2 and 4 → 73:21",
      "Positions 1 and 2 → 17:23",
    ],
    optionsDe: [
      "Platz 1 und 3 → 21:73",
      "Platz 2 und 4 → 73:21",
      "Platz 1 und 2 → 17:23",
    ],
    correctIndex: 2,
  ),
  "dark_matter_grid": PracticeLesson(
    rulesEn:
        "Light every cell. Tapping a cell flips that cell and its direct neighbors above, below, left and right: lit becomes dark and dark becomes lit. Diagonal cells do not flip. At the edge, only neighbors inside the board change.",
    rulesDe:
        "Bringe alle Felder zum Leuchten. Antippen schaltet das Feld und seine direkten Nachbarn oben, unten, links und rechts um: hell wird dunkel und dunkel wird hell. Diagonale Felder ändern sich nicht. Am Rand ändern sich nur Nachbarn auf dem Brett.",
    boardEn: "L = lit, D = dark:\nL D L\nD D D\nL D L",
    boardDe: "H = hell, D = dunkel:\nH D H\nD D D\nH D H",
    questionEn: "Which single tap lights the whole board?",
    questionDe: "Welches einmalige Antippen macht das ganze Brett hell?",
    explanationEn:
        "The center tap flips exactly the five dark cells in the cross. The four lit corners stay lit. A corner or edge tap changes a different set and leaves dark cells behind.",
    explanationDe:
        "Die Mitte schaltet genau die fünf dunklen Felder des Kreuzes um. Die vier hellen Ecken bleiben hell. Ein Eck- oder Randfeld verändert eine andere Gruppe und lässt dunkle Felder übrig.",
    focusEn: "Check the entire cross affected by a tap.",
    focusDe: "Prüfe das ganze Kreuz, das ein Tipp verändert.",
    strategyEn:
        "Before tapping, name which affected cells will become lit and which will become dark. Tapping the same cell twice cancels its effect. The goal is all lit, not all dark.",
    strategyDe:
        "Benenne vor dem Tippen, welche betroffenen Felder hell und welche dunkel werden. Zweimal dasselbe Feld anzutippen hebt die Wirkung auf. Das Ziel ist überall hell, nicht überall dunkel.",
    optionsEn: [
      "The center cell",
      "The top-left corner",
      "The top-middle cell",
    ],
    optionsDe: [
      "Das mittlere Feld",
      "Die Ecke oben links",
      "Das Feld oben in der Mitte",
    ],
    correctIndex: 0,
  ),
  "ion_chain": PracticeLesson(
    rulesEn:
        "Fill the empty slots of the ion RING with beads from the tray, obeying every displayed forbidden-neighbor rule. Each bead has two neighbors, including the pair across the last and first slots. Drag a bead from the tray to an empty slot; fixed beads stay in place. Tap your own placements to remove them.",
    rulesDe:
        "Fülle die freien Plätze des Ionenrings mit Perlen aus der Ablage. Beachte alle angezeigten Verbote für Nachbarpaare. Jede Perle hat zwei Nachbarn; auch der letzte und erste Platz liegen nebeneinander. Ziehe eine Perle aus der Ablage auf einen freien Platz. Vorgegebene bleiben liegen; eigene kannst du zum Entfernen antippen.",
    boardEn:
        "Six slots around a ring, read clockwise:\nred STAR → ? → red STAR → blue CIRCLE → ? → blue CIRCLE → back to first red STAR\nRule: two red STAR beads may not be neighbors.\nTray: one red STAR and one blue CIRCLE for the two gaps.",
    boardDe:
        "Sechs Plätze im Ring, im Uhrzeigersinn:\nroter STERN → ? → roter STERN → blauer KREIS → ? → blauer KREIS → zurück zum ersten roten STERN\nRegel: Zwei rote STERN-Perlen dürfen keine Nachbarn sein.\nAblage: ein roter STERN und ein blauer KREIS für die zwei Lücken.",
    questionEn:
        "What belongs in the FIRST empty slot, between the two red stars?",
    questionDe:
        "Was gehört auf den ERSTEN freien Platz zwischen den beiden roten Sternen?",
    explanationEn:
        "The blue CIRCLE has a red STAR on each side, so both pairs are allowed. Put the remaining red star in the other gap between blue circles. A red STAR in the first gap would make forbidden STAR–STAR pairs. The last slot also touches the first: this is a closed ring, not an open row.",
    explanationDe:
        "Der blaue KREIS hat auf beiden Seiten einen roten STERN; beide Paare sind erlaubt. Der übrige rote Stern passt in die andere Lücke zwischen blauen Kreisen. Ein roter STERN in der ersten Lücke würde verbotene STERN–STERN-Paare bilden. Der letzte Platz berührt auch den ersten: Es ist ein geschlossener Ring, keine offene Reihe.",
    focusEn:
        "Inspect both neighbors of an empty slot, including across the ring’s join.",
    focusDe:
        "Prüfe beide Nachbarn eines freien Platzes, auch über den Ringschluss hinweg.",
    strategyEn:
        "Start with a slot constrained by two fixed neighbors. Cross out bead types forbidden by either neighbor, then check the remaining tray and other gaps before placing.",
    strategyDe:
        "Beginne mit einem Platz zwischen zwei vorgegebenen Perlen. Streiche Sorten, die einer der Nachbarn verbietet. Prüfe dann den Rest der Ablage und die übrigen Lücken.",
    optionsEn: [
      "Red STAR, because the row ends there",
      "Blue CIRCLE, because both neighbors are red STARS",
      "Either color; only the first three slots matter",
    ],
    optionsDe: [
      "Roter STERN, weil die Reihe dort endet",
      "Blauer KREIS, weil beide Nachbarn rote STERNE sind",
      "Jede Farbe; nur die ersten drei Plätze zählen",
    ],
    correctIndex: 1,
  ),
  "sector_painter": PracticeLesson(
    rulesEn:
        "Color every sector using the available palette. Sectors joined by a line must have different colors; sectors without a connecting line may share a color. Select a color, then tap a sector. Recolor a sector to fix a conflict; tapping it with its current color clears it.",
    rulesDe:
        "Färbe alle Sektoren mit den verfügbaren Farben. Sektoren mit einer Verbindungslinie brauchen unterschiedliche Farben; ohne Verbindung dürfen sie gleich sein. Wähle eine Farbe und tippe einen Sektor an. Färbe bei einem Konflikt um. Erneutes Antippen mit derselben Farbe löscht sie dort.",
    boardEn:
        "Connections: A—B—C. There is NO line A—C.\nA is red, C is red, B is uncolored.\nPalette: red and green.",
    boardDe:
        "Verbindungen: A—B—C. Zwischen A und C gibt es KEINE Linie.\nA ist rot, C ist rot, B ist ungefärbt.\nPalette: Rot und Grün.",
    questionEn: "What color can B have?",
    questionDe: "Welche Farbe kann B haben?",
    explanationEn:
        "B connects to both red sectors, so it must be green. A and C may remain red because they are not connected to each other. You do not need a different color for every sector.",
    explanationDe:
        "B ist mit beiden roten Sektoren verbunden und muss grün sein. A und C dürfen rot bleiben, denn sie sind nicht miteinander verbunden. Du brauchst nicht für jeden Sektor eine eigene Farbe.",
    focusEn: "Follow a sector’s connecting lines to its neighbors.",
    focusDe: "Folge den Verbindungslinien eines Sektors zu seinen Nachbarn.",
    strategyEn:
        "Start at a sector with many connections. Exclude colors already used by its colored neighbors; nearby sectors without a connecting line do not exclude colors.",
    strategyDe:
        "Beginne bei einem Sektor mit vielen Verbindungen. Schließe die Farben seiner gefärbten Nachbarn aus. Bloß nahe Sektoren ohne Verbindung schließen keine Farbe aus.",
    optionsEn: [
      "Red, because A and C are also red",
      "Neither color: all sectors need unique colors",
      "Green, different from both connected neighbors",
    ],
    optionsDe: [
      "Rot, weil A und C auch rot sind",
      "Keine: Jeder Sektor braucht eine eigene Farbe",
      "Grün, anders als beide verbundenen Nachbarn",
    ],
    correctIndex: 2,
  ),
  "void_crossing": PracticeLesson(
    rulesEn:
        "Bring every creature to the right station within the crossing limit. Tap creatures at the shuttle’s station to load or unload; respect the shown seat capacity, then launch. A forbidden pair may not remain together at the station you leave unless its shown guardian is there. The shuttle supervises the station where it is docked; returning empty is allowed when the other station stays safe.",
    rulesDe:
        "Bringe alle Wesen innerhalb des Fahrtlimits zur rechten Station. Tippe Wesen an der Shuttlestation zum Ein- oder Ausladen an. Beachte die Sitzanzahl und starte dann. Ein verbotenes Paar darf nicht an der verlassenen Station bleiben, außer sein angezeigter Wächter ist dort. Das Shuttle beaufsichtigt seine aktuelle Station. Leer zurückzufahren ist erlaubt, wenn die andere Station sicher bleibt.",
    boardEn:
        "All three creatures are on the left. The shuttle has ONE passenger seat.\nForbidden unattended pairs: A with B; B with C.\nA with C is safe. No guardians.",
    boardDe:
        "Alle drei Wesen sind links. Das Shuttle hat EINEN Passagierplatz.\nUnbeaufsichtigt verboten: A mit B; B mit C.\nA mit C ist sicher. Keine Wächter.",
    questionEn: "Whom should you take on the first crossing?",
    questionDe: "Wen nimmst du bei der ersten Fahrt mit?",
    explanationEn:
        "Taking B leaves A and C together, which is safe. Taking A leaves the forbidden pair B–C; taking C leaves the forbidden pair A–B. After arrival, plan the return trip too: the shuttle must come back to collect more creatures.",
    explanationDe:
        "Mit B bleiben A und C zurück; das ist sicher. Mit A bliebe das verbotene Paar B–C. Mit C bliebe A–B. Plane nach der Ankunft auch die Rückfahrt: Das Shuttle muss weitere Wesen abholen.",
    focusEn: "Check the creatures that will remain at the station you leave.",
    focusDe: "Prüfe die Wesen, die an der verlassenen Station zurückbleiben.",
    strategyEn:
        "Try a passenger choice mentally, then inspect every forbidden pair among those left behind. Plan a safe return before launching; sometimes a creature must ride back with you.",
    strategyDe:
        "Wähle im Kopf Passagiere und prüfe dann jedes verbotene Paar unter den Zurückbleibenden. Plane vor dem Start eine sichere Rückfahrt. Manchmal muss ein Wesen wieder mit zurück.",
    optionsEn: [
      "B, leaving the safe pair A and C",
      "A, leaving B and C",
      "C, leaving A and B",
    ],
    optionsDe: [
      "B; das sichere Paar A und C bleibt zurück",
      "A; B und C bleiben zurück",
      "C; A und B bleiben zurück",
    ],
    correctIndex: 0,
  ),
};
