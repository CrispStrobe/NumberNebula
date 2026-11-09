"""Original transfer tasks extending the reviewed KOMPASS mathematics bank.

These tasks use the existing content contract. Practice may revisit a familiar
representation; the new held-out families change the reasoning requirement.
No source task wording or official assessment material is copied here.
"""
from common import L, task, number, choice, multi, manual, cells, figure, error


def tasks():
    out = []

    def add(skill, slug, domain, title_de, title_en, prompt_de, prompt_en,
            parts, *, use, hints, solution, fig=None, level=2, seconds=120,
            family=None):
        # The suffix sorts after existing tasks of the same competency. New
        # practice is not labelled level 1 merely to appear earlier in a route.
        out.append(task(
            skill, "zz_" + slug, domain, title_de, title_en,
            prompt_de, prompt_en, parts, use=use, hints=hints,
            solution=solution, fig=fig, level=level, seconds=seconds,
            family=family,
        ))

    s = "M-Z07"
    add(s, "division_doubling", "numbers",
        "Eine bekannte Division verdoppeln", "Double a known division",
        "48 Plättchen werden in Gruppen mit jeweils 8 Plättchen gelegt. Das sind 6 Gruppen. Nun sollen 96 Plättchen in genauso große Gruppen gelegt werden.",
        "48 counters are arranged in groups of 8 counters each. That makes 6 groups. Now arrange 96 counters in groups of the same size.",
        [number("groups", "Wie viele Gruppen entstehen aus 96 Plättchen?", "How many groups do 96 counters make?", 12, s,
                errors=[error(6, "unchanged_group_count", "Die Gruppengröße bleibt gleich, aber es sind doppelt so viele Plättchen vorhanden.", "The group size stays the same, but there are twice as many counters.")]),
         choice("reason", "Welche Begründung passt?", "Which explanation fits?",
                [("double_groups", "96 sind zweimal 48. Jede Hälfte bildet 6 Gruppen, zusammen also zweimal 6.", "96 is twice 48. Each half makes 6 groups, giving twice 6 altogether."),
                 ("double_size", "Es müssen nun 16 Plättchen in jeder Gruppe liegen.", "Each group must now contain 16 counters."),
                 ("add_eight", "Zur Zahl der Gruppen müssen immer 8 addiert werden.", "Always add 8 to the number of groups.")],
                "double_groups", s)], use="practice",
        hints=[("Was hat sich verändert: die Gesamtzahl oder die Größe jeder Gruppe?", "What changed: the total number or the size of each group?"),
               ("Teile die 96 Plättchen gedanklich in zwei gleich große Vorräte von 48.", "Think of the 96 counters as two equal supplies of 48."),
               ("Jeder Vorrat ergibt 6 Gruppen. Verbinde die beiden Gruppenzahlen.", "Each supply makes 6 groups. Combine those two group counts.")],
        solution=("96 : 8 = 12. Weil der Vorrat bei unveränderter Gruppengröße verdoppelt wird, verdoppelt sich die Gruppenzahl: 6 + 6 = 12.",
                  "96 ÷ 8 = 12. Doubling the supply while keeping each group the same size doubles the number of groups: 6 + 6 = 12."))

    s = "M-Z08"
    add(s, "two_direction_number_grid", "numbers",
        "Zwei Richtungen, zwei Regeln", "Two directions, two rules",
        "In diesem Zahlenfeld gilt nach rechts überall derselbe Additionsschritt. Nach unten gilt ebenfalls überall derselbe Additionsschritt; er darf ein anderer sein. A und B verdecken zwei Zahlen.",
        "Every step to the right in this number grid adds the same amount. Every step down also adds a constant amount, which may be different. A and B cover two numbers.",
        [number("a", "Welche Zahl steht unter A?", "What number is hidden by A?", 46, s),
         number("b", "Welche Zahl steht unter B?", "What number is hidden by B?", 60, s),
         choice("rule", "Welche beiden Schritte passen zum ganzen Zahlenfeld?", "Which two steps fit the whole grid?",
                [("right6_down20", "Nach rechts +6, nach unten +20", "Right +6, down +20"),
                 ("right20_down6", "Nach rechts +20, nach unten +6", "Right +20, down +6"),
                 ("right6_down14", "Nach rechts +6, nach unten +14", "Right +6, down +14")],
                "right6_down20", s)], use="practice",
        hints=[("Vergleiche zuerst zwei bekannte Nachbarn in derselben Zeile.", "First compare two known neighbours in the same row."),
               ("Vergleiche dann zwei bekannte Zahlen direkt untereinander.", "Then compare two known numbers directly above and below one another."),
               ("Prüfe eine verdeckte Zahl auf zwei Wegen: von links und von oben.", "Check a hidden number in two ways: from the left and from above.")],
        solution=("Nach rechts wird 6 addiert, nach unten 20. A = 40 + 6 = 46 und auch 26 + 20 = 46. B = 54 + 6 = 60 und auch 40 + 20 = 60.",
                  "Moving right adds 6 and moving down adds 20. A = 40 + 6 = 46 and also 26 + 20 = 46. B = 54 + 6 = 60 and also 40 + 20 = 60."),
        fig=figure("table", {"headers": ["1", "2", "3"],
                              "rows": [["14", "20", "26"], ["34", "40", "A"], ["54", "B", "66"]]},
                   "Zahlenfeld mit drei Spalten. Zeilen: 14, 20, 26; 34, 40, A; 54, B, 66.",
                   "Three-column number grid. Rows: 14, 20, 26; 34, 40, A; 54, B, 66."))

    s = "M-Z12"
    routes = ["RRDD", "RDRD", "RDDR", "DRRD", "DRDR", "DDRR"]
    add(s, "constrained_grid_routes", "numbers",
        "Alle erlaubten Wege finden", "Find every allowed route",
        "Starte im Feld oben links und gehe zum Feld unten rechts. Ein Schritt führt in ein benachbartes Feld nach rechts (→) oder nach unten (↓). Du brauchst genau zwei Schritte jeder Art. Das graue Feld oben rechts ist gesperrt und darf nicht betreten werden.",
        "Start in the top-left cell and go to the bottom-right cell. Each step moves to an adjacent cell right (→) or down (↓). You need exactly two steps of each kind. The grey top-right cell is blocked and must not be entered.",
        [multi("routes", "Wähle alle erlaubten Schrittfolgen.", "Select every allowed sequence of steps.",
               [(route.lower(), route.replace("R", "→").replace("D", "↓"),
                 route.replace("R", "→").replace("D", "↓")) for route in routes],
               [route.lower() for route in routes if route != "RRDD"], s),
         number("count", "Wie viele verschiedene erlaubte Wege gibt es insgesamt?", "How many different allowed routes are there altogether?", 5, s)],
        use="check", level=3, seconds=150,
        hints=[("Verfolge jede Schrittfolge vom Start aus, auch ihre Zwischenfelder.", "Trace each sequence from the start, including its intermediate cells."),
               ("Zwei Schritte nach rechts gleich am Anfang führen in das gesperrte Feld.", "Two rightward steps at the start lead into the blocked cell.")],
        solution=("Von den sechs Schrittfolgen ist nur →→↓↓ gesperrt. Die anderen fünf erreichen das Ziel ohne das Feld oben rechts. Vollständigkeit: Die zwei Rechts-Schritte können an sechs verschiedenen Paaren der vier Positionen stehen; eines dieser Paare ist verboten.",
                  "Only →→↓↓ is blocked among the six sequences. The other five reach the goal without entering the top-right cell. Completeness: the two rightward steps can occupy six different pairs of the four positions; one pair is forbidden."),
        fig=figure("grid", {"rows": 3, "cols": 3, "filled": ["0,2"]},
                   "Drei mal drei Felder. Start: Reihe 1, Spalte 1. Ziel: Reihe 3, Spalte 3. Gesperrt: Reihe 1, Spalte 3.",
                   "Three-by-three cells. Start: row 1, column 1. Goal: row 3, column 3. Blocked: row 1, column 3."))

    s = "M-Z10"
    add(s, "reverse_two_stage_stock", "numbers",
        "Den Anfangsbestand rekonstruieren", "Reconstruct the starting stock",
        "Am Morgen wird genau die Hälfte aller Aufkleber verteilt. Am Nachmittag verteilen 4 Helfer zusammen weitere 18 Aufkleber. Danach bleiben 27 übrig. Wie viele Aufkleber waren am Morgen vor dem Verteilen vorhanden?",
        "Exactly half of all the stickers are handed out in the morning. In the afternoon, 4 helpers hand out another 18 stickers altogether. Afterwards, 27 remain. How many stickers were there before any were handed out?",
        [choice("model", "Welche Rechnung stellt den Anfangsbestand wieder her?", "Which calculation reconstructs the starting stock?",
                [("undo_then_double", "(27 + 18) · 2", "(27 + 18) × 2"),
                 ("double_then_add", "27 · 2 + 18", "27 × 2 + 18"),
                 ("multiply_helpers", "(27 + 18) · 4", "(27 + 18) × 4")],
                "undo_then_double", s),
         number("start", "Wie viele Aufkleber waren es am Anfang?", "How many stickers were there at the start?", 90, s,
                errors=[error(72, "reverse_steps_wrong_order", "Stelle zuerst den Bestand vor dem Nachmittag wieder her. Erst dieser Bestand ist die Hälfte des Anfangs.", "First reconstruct the stock before the afternoon. That stock is half of the starting amount.")])],
        use="rehearsal", level=3,
        hints=[("Arbeite vom Ende der Geschichte zurück zum Anfang.", "Work backwards from the end of the story."),
               ("18 Aufkleber werden von allen 4 Helfern zusammen verteilt, nicht von jedem einzeln.", "The 4 helpers hand out 18 stickers altogether, not 18 each.")],
        solution=("Vor dem Nachmittag lagen noch 27 + 18 = 45 Aufkleber bereit. Diese 45 sind die Hälfte des Anfangsbestands: 45 · 2 = 90. Die Helferzahl 4 wird nicht zum Multiplizieren gebraucht.",
                  "Before the afternoon there were 27 + 18 = 45 stickers. Those 45 are half of the starting stock: 45 × 2 = 90. The number of helpers, 4, is not a multiplier."))

    s = "M-R08"
    add(s, "joined_and_exposed_edges", "geometry",
        "Gemeinsame Kanten zählen nicht doppelt", "Separate joined and exposed edges",
        "Drei quadratische Platten liegen ohne Überlappung in einer L-Form. Jede Plattenkante ist 2 cm lang. Ein Band soll nur am äußeren Rand entlanglaufen, nicht an den gemeinsamen Kanten zwischen Platten.",
        "Three square tiles form an L without overlaps. Each tile edge is 2 cm long. A ribbon follows only the outside boundary, not the shared edges between tiles.",
        [number("shared", "Wie viele ganze Kanten teilen sich je zwei Platten?", "How many whole edges are shared by two tiles?", 2, s),
         number("boundary", "Wie lang muss das Band für den äußeren Rand sein?", "How long must the ribbon be to cover the outside boundary?", 16, s, unit="cm"),
         choice("reason", "Warum zählt die Summe der drei einzelnen Plattenumfänge zu viel?", "Why is the sum of the three separate tile perimeters too large?",
                [("shared_twice", "Jede gemeinsame Kante kommt darin zweimal vor, aber gar nicht am äußeren Rand.", "Each shared edge is counted twice, although it is not on the outside boundary."),
                 ("only_corners", "Am äußeren Rand dürfen nur die Ecken gezählt werden.", "Only corners may be counted on the outside boundary."),
                 ("area_same", "Umfang und Flächeninhalt sind immer dieselbe Zahl.", "Perimeter and area are always the same number.")],
                "shared_twice", s)], use="practice",
        hints=[("Fahre gedanklich mit einem Finger einmal außen um die L-Form.", "Trace once around the outside of the L with an imaginary finger."),
               ("Markiere zuerst die Kanten, die zwischen zwei Platten liegen.", "First mark the edges between two tiles."),
               ("Es gibt zwölf einzelne Plattenkanten. Für jede Verbindung fallen zwei dieser gezählten Kanten weg.", "The separate tiles have twelve edges altogether. Each join removes two of those counted edges.")],
        solution=("Es gibt 2 gemeinsame Kanten. Am äußeren Rand bleiben 3 · 4 − 2 · 2 = 8 Plattenkanten. 8 · 2 cm = 16 cm. Die gemeinsamen Kanten wurden bei den Einzelumfängen jeweils doppelt gezählt.",
                  "There are 2 shared edges. The outside boundary has 3 × 4 − 2 × 2 = 8 tile edges. 8 × 2 cm = 16 cm. Each shared edge was counted twice in the separate perimeters."),
        fig=figure("grid", {"rows": 2, "cols": 2, "filled": ["0,0", "1,0", "1,1"]},
                   "L-Form aus den Feldern oben links, unten links und unten rechts. Jede Feldkante ist 2 cm lang; das leere Feld gehört nicht zur Form.",
                   "An L formed by the top-left, bottom-left and bottom-right cells. Each cell edge is 2 cm long; the empty cell is not part of the shape."))

    s = "M-R02"
    add(s, "square_and_corner_piece", "geometry",
        "Zwei verschiedene Teile ergänzen sich", "Fit two different pieces together",
        "Ein quadratisches Brett hat 3 mal 3 gleich große Felder. Das feste quadratische Teil bedeckt oben links 2 mal 2 Felder. Das zweite Teil besteht aus fünf Feldern: drei in einer Reihe und drei in einer dazu senkrechten Reihe, wobei das Eckfeld zu beiden Reihen gehört. Es darf gedreht werden. Decke das Brett ohne Lücke und Überlappung.",
        "A square board has 3 by 3 equal cells. A fixed square piece covers the top-left 2 by 2 cells. The other piece has five cells: three in one row and three in a perpendicular row, sharing the corner cell. It may be rotated. Cover the board without gaps or overlaps.",
        [cells("second_piece", "Markiere genau die Felder, die das zweite Teil bedeckt.", "Select exactly the cells covered by the second piece.",
               ["0,2", "1,2", "2,0", "2,1", "2,2"], s,
               figure("grid", {"rows": 3, "cols": 3, "filled": ["0,0", "0,1", "1,0", "1,1"]},
                      "Drei mal drei Felder; der feste quadratische Teil belegt die ersten zwei Reihen und ersten zwei Spalten.",
                      "Three-by-three cells; the fixed square occupies the first two rows and first two columns.")),
         number("covered", "Wie viele Felder bedecken beide Teile zusammen?", "How many cells do the two pieces cover together?", 9, s)],
        use="practice", seconds=140,
        family="mr02_complete_tile_rectangle",
        hints=[("Das feste Teil darf nicht verschoben oder überdeckt werden.", "The fixed piece cannot be moved or covered."),
               ("Suche die freien Felder an der rechten und an der unteren Brettkante.", "Look for the free cells along the right and bottom edges of the board."),
               ("Das gemeinsame Eckfeld gehört nur einmal zum zweiten Teil.", "The shared corner cell belongs to the second piece only once.")],
        solution=("Das zweite Teil liegt in der rechten Spalte und der unteren Reihe. Das Eckfeld unten rechts wird einmal gezählt: 3 + 3 − 1 = 5 Felder. Zusammen mit den 4 Feldern des Quadrats sind es 9.",
                  "The second piece occupies the right column and the bottom row. The bottom-right corner is counted once: 3 + 3 − 1 = 5 cells. Together with the square's 4 cells, the total is 9."))

    s = "M-R03"
    add(s, "overlapping_rectangles_union", "geometry",
        "Überdeckte Fläche nur einmal zählen", "Count overlap only once",
        "Jedes Feld des Gitters hat einen Flächeninhalt von 1 cm². Rechteck A ist grau eingezeichnet: Reihen 1 und 2, Spalten 1 bis 3. Lege gedanklich Rechteck B dazu: Reihen 2 und 3, Spalten 3 bis 5. Überlappende Felder zählen für die insgesamt bedeckte Fläche nur einmal.",
        "Each grid cell has area 1 cm². Rectangle A is shown in grey: rows 1 and 2, columns 1 to 3. Imagine adding rectangle B: rows 2 and 3, columns 3 to 5. Count overlapping cells only once in the total covered area.",
        [number("overlap", "Wie groß ist die Fläche, die zu A und B gehört?", "What area belongs to both A and B?", 1, s, unit="cm²"),
         number("covered", "Wie groß ist die insgesamt bedeckte Fläche?", "What is the total covered area?", 11, s, unit="cm²",
                errors=[error(12, "overlap_counted_twice", "Ein Feld gehört zu beiden Rechtecken. Beim Addieren beider Flächen wird dieses Feld doppelt gezählt.", "One cell belongs to both rectangles. Adding their areas counts that cell twice.")])],
        use="check", level=3,
        hints=[("Prüfe, welche Reihe und welche Spalte in beiden Beschreibungen vorkommen.", "Check which row and which column occur in both descriptions."),
               ("Addiere beide Rechteckflächen und ziehe die doppelt gezählte Fläche einmal ab.", "Add the rectangle areas and subtract the double-counted area once.")],
        solution=("Nur das Feld in Reihe 2, Spalte 3 gehört zu beiden Rechtecken. Die Überlappung ist 1 cm². Jedes Rechteck ist 6 cm² groß; insgesamt werden 6 + 6 − 1 = 11 cm² bedeckt.",
                  "Only the cell in row 2, column 3 belongs to both rectangles. The overlap is 1 cm². Each rectangle has area 6 cm², so the total covered area is 6 + 6 − 1 = 11 cm²."),
        fig=figure("grid", {"rows": 3, "cols": 5, "filled": ["0,0", "0,1", "0,2", "1,0", "1,1", "1,2"]},
                   "Gitter mit drei Reihen und fünf Spalten. Grau ist nur Rechteck A in den ersten beiden Reihen und ersten drei Spalten. B ist noch nicht eingezeichnet.",
                   "A grid with three rows and five columns. Only rectangle A is grey, in the first two rows and first three columns. B is not drawn yet."))

    s = "M-R06"
    add(s, "two_views_hidden_tower", "geometry",
        "Eine verdeckte Höhe ist nicht eindeutig", "A hidden height need not be unique",
        "Die Tabelle ist ein Bauplan mit zwei Reihen und zwei Spalten. Zahlen geben lückenlose Turmhöhen in Würfeln an; 0 bedeutet kein Turm. x ist eine ganze Zahl von 0 bis 4. Von vorne sieht man links Höhe 3 und rechts Höhe 2. Von rechts sieht man für die hintere Reihe Höhe 2 und für die vordere Reihe Höhe 3. Ein verdeckter niedriger Turm bleibt in einer Ansicht unsichtbar.",
        "The table is a two-row, two-column building plan. Numbers give solid tower heights in cubes; 0 means no tower. x is a whole number from 0 to 4. The front view has height 3 on the left and 2 on the right. The right view has height 2 for the back row and 3 for the front row. A lower tower hidden behind another is not visible in that view.",
        [multi("possible", "Welche Werte für x passen zu beiden Ansichten? Wähle alle.", "Which values of x fit both views? Select all.",
               [(str(value), str(value), str(value)) for value in range(5)],
               ["0", "1", "2"], s),
         choice("unique", "Kann man x mit diesen Angaben eindeutig bestimmen?", "Do these observations determine x uniquely?",
                [("yes", "Ja, genau ein Wert passt.", "Yes, exactly one value fits."),
                 ("no", "Nein, mehrere Werte passen.", "No, several values fit.")], "no", s)],
        use="rehearsal", level=3, seconds=150,
        hints=[("Eine Ansicht zeigt für jede Blickreihe nur den höchsten Turm.", "Each line of sight shows only its tallest tower."),
               ("Probiere x = 0, 1, 2, 3 und 4. Prüfe jeweils beide Blickrichtungen.", "Try x = 0, 1, 2, 3 and 4. Check both viewing directions for each value.")],
        solution=("x darf 0, 1 oder 2 sein. Von vorne verdeckt der vordere Dreierturm diese Höhe. Von rechts verdeckt der hintere Zweierturm sie. x = 3 oder 4 widerspricht der Höhe 2 der hinteren Reihe in der rechten Ansicht. Die Höhe ist deshalb nicht eindeutig bestimmt.",
                  "x can be 0, 1 or 2. From the front, the front tower of height 3 hides it. From the right, the back-row tower of height 2 hides it. x = 3 or 4 contradicts the back-row height 2 in the right view. The height is therefore not uniquely determined."),
        fig=figure("table", {"headers": [L("Reihe", "Row"), L("links", "left"), L("rechts", "right")],
                              "rows": [[L("hinten", "back"), "x", "2"], [L("vorne", "front"), "3", "1"]]},
                   "Bauplan: hintere Reihe x und 2; vordere Reihe 3 und 1. Links und rechts beziehen sich auf die Vorderansicht.",
                   "Building plan: back row x and 2; front row 3 and 1. Left and right refer to the front view."))

    s = "M-G04"
    add(s, "deposit_and_refund", "measurement",
        "Preis, Pfand und Rückgabe", "Price, deposit and return",
        "Eine Flasche Limonade kostet 1,25 € für das Getränk und zusätzlich 0,25 € Pfand. Du kaufst 4 Flaschen. Danach gibst du 3 leere Pfandflaschen zurück und bekommst für jede 0,25 € erstattet. Es gibt keine weiteren Kosten oder Erstattungen.",
        "A bottle of lemonade costs €1.25 for the drink plus a €0.25 deposit. You buy 4 bottles. Afterwards, you return 3 empty deposit bottles and receive €0.25 for each. There are no other charges or refunds.",
        [number("payment", "Wie viel bezahlst du beim Kauf vor der Rückgabe?", "How much do you pay at purchase, before the return?", 6, s, unit="€"),
         number("refund", "Wie viel bekommst du für die 3 leeren Flaschen zurück?", "How much is refunded for the 3 empty bottles?", 0.75, s, unit="€"),
         number("net", "Wie viel Geld hast du nach Kauf und Rückgabe insgesamt weniger?", "How much less money do you have after the purchase and return together?", 5.25, s, unit="€",
                errors=[error(5, "deposit_ignored", "Nach der Rückgabe bleibt das Pfand für eine nicht zurückgegebene Flasche noch bezahlt.", "After the return, the deposit on one unreturned bottle is still paid.")])],
        use="practice", seconds=150,
        hints=[("Beim Kauf gehört das Pfand für jede gekaufte Flasche zum Zahlbetrag.", "At purchase, each bottle's deposit is part of the payment."),
               ("Berechne die Rückgabe getrennt; es werden nur drei Flaschen zurückgegeben.", "Calculate the refund separately; only three bottles are returned."),
               ("Ziehe das zurückbekommene Geld vom zuerst bezahlten Geld ab.", "Subtract the refunded money from the original payment.")],
        solution=("Kauf: 4 · (1,25 € + 0,25 €) = 6,00 €. Rückgabe: 3 · 0,25 € = 0,75 €. Insgesamt fehlen danach 6,00 € − 0,75 € = 5,25 €.",
                  "Purchase: 4 × (€1.25 + €0.25) = €6.00. Refund: 3 × €0.25 = €0.75. The net reduction in money is €6.00 − €0.75 = €5.25."))

    s = "M-G07"
    add(s, "pour_and_return", "measurement",
        "Hin- und zurückgießen", "Pour out and pour back",
        "Eine Kanne enthält 1 l Wasser. Ein leerer Becher fasst mindestens 250 ml. Gieße zuerst 250 ml aus der Kanne in den Becher. Gieße danach genau 100 ml aus dem Becher zurück in die Kanne. Nichts wird verschüttet. Es gilt: 1 l = 1000 ml.",
        "A jug contains 1 litre of water. An empty cup holds at least 250 ml. First pour 250 ml from the jug into the cup. Then pour exactly 100 ml from the cup back into the jug. Nothing is spilled. Use 1 litre = 1000 ml.",
        [number("cup", "Wie viel Wasser ist am Ende im Becher?", "How much water is in the cup at the end?", 150, s, unit="ml"),
         number("jug", "Wie viel Wasser ist am Ende in der Kanne?", "How much water is in the jug at the end?", 850, s, unit="ml",
                errors=[error(750, "return_not_counted", "Nach dem ersten Gießen stimmt 750 ml. Den Rückfluss von 100 ml musst du noch berücksichtigen.", "750 ml is correct after the first pour. You still need to include the 100 ml poured back.")])],
        use="practice",
        hints=[("Rechne die Anfangsmenge zuerst in Milliliter um.", "First express the starting amount in millilitres."),
               ("Wenn Wasser die Kanne verlässt, nimmt die Bechermenge zu. Beim Zurückgießen ist es umgekehrt.", "When water leaves the jug, the amount in the cup grows. Pouring it back reverses that."),
               ("Prüfe am Ende, ob beide Mengen zusammen noch 1000 ml ergeben.", "Finally check that both amounts still add up to 1000 ml.")],
        solution=("Im Becher bleiben 250 − 100 = 150 ml. In der Kanne sind 1000 − 250 + 100 = 850 ml. Kontrolle: 150 + 850 = 1000 ml.",
                  "The cup contains 250 − 100 = 150 ml. The jug contains 1000 − 250 + 100 = 850 ml. Check: 150 + 850 = 1000 ml."))

    s = "M-G04"
    add(s, "offers_with_fixed_charge", "measurement",
        "Eine feste Gebühr mitrechnen", "Include a fixed charge",
        "Für genau 8 Leihstühle gibt es zwei Angebote. A verlangt einmalig 6 € Bereitstellung und 2 € je Stuhl. B verlangt keine Bereitstellung und 3 € je Stuhl. Es gibt keine weiteren Gebühren, Pfandbeträge oder Rabatte.",
        "There are two offers for exactly 8 rental chairs. A charges a one-off setup fee of €6 plus €2 per chair. B has no setup fee and charges €3 per chair. There are no other fees, deposits or discounts.",
        [number("a", "Wie viel kosten 8 Stühle bei A insgesamt?", "What is the total cost of 8 chairs from A?", 22, s, unit="€",
                errors=[error(64, "fixed_fee_per_item", "Die Bereitstellung wird nur einmal bezahlt, nicht für jeden Stuhl.", "The setup fee is paid only once, not for every chair.")]),
         number("b", "Wie viel kosten 8 Stühle bei B insgesamt?", "What is the total cost of 8 chairs from B?", 24, s, unit="€"),
         choice("cheaper", "Welches Angebot ist für diese 8 Stühle günstiger?", "Which offer is cheaper for these 8 chairs?",
                [("a", "A", "A"), ("b", "B", "B"), ("equal", "Beide kosten gleich viel.", "They cost the same.")], "a", s)],
        use="check", level=3,
        hints=[("Trenne die einmalige Gebühr vom Preis, der für jeden Stuhl anfällt.", "Separate the one-off fee from the price charged for every chair."),
               ("Vergleiche die vollständigen Zahlbeträge, nicht nur die Stückpreise.", "Compare the complete payments, not just the per-chair prices.")],
        solution=("A kostet 6 € + 8 · 2 € = 22 €. B kostet 8 · 3 € = 24 €. Für 8 Stühle ist A um 2 € günstiger. Die feste Gebühr fällt genau einmal an.",
                  "A costs €6 + 8 × €2 = €22. B costs 8 × €3 = €24. For 8 chairs, A is €2 cheaper. The fixed fee is charged exactly once."))

    s = "M-G05"
    add(s, "overlapping_preparations", "measurement",
        "Gleichzeitige Zeiten richtig verbinden", "Combine overlapping times",
        "Um 09:40 startet ein Gerät sein automatisches Aufwärmen für 18 Minuten. Gleichzeitig beginnt eine Person mit einer Vorbereitung, die 25 Minuten dauert. Sobald beides fertig ist, folgen noch genau 5 Minuten Wartezeit. Erst danach darf die Vorführung starten.",
        "At 09:40 a machine starts warming up automatically for 18 minutes. At the same time, a person starts a preparation task lasting 25 minutes. Once both are finished, there is a further wait of exactly 5 minutes. The demonstration may start only after that wait.",
        [number("elapsed", "Wie viele Minuten vergehen von 09:40 bis zum frühesten Start?", "How many minutes pass from 09:40 to the earliest start?", 30, s, unit="min",
                errors=[error(48, "overlap_added_as_sequence", "Aufwärmen und Vorbereitung beginnen gleichzeitig. Ihre Zeiten werden nicht hintereinander addiert.", "Warm-up and preparation start together. Their durations are not added one after another.")]),
         choice("start", "Wann ist der früheste Start?", "What is the earliest start time?",
                [("1003", "10:03", "10:03"), ("1010", "10:10", "10:10"), ("1028", "10:28", "10:28")], "1010", s),
         manual("reason", "Erkläre, welche Dauer über das Ende der gemeinsamen Vorbereitung entscheidet.", "Explain which duration determines when both preparations are finished.",
                "1 Punkt: Die Vorgänge laufen gleichzeitig; der längere mit 25 Minuten bestimmt das gemeinsame Ende. Danach kommen 5 Minuten hinzu. Eine gleichwertige Erklärung ist zulässig.",
                "1 point: the activities run at the same time, so the longer 25-minute activity determines when both are ready. The further 5-minute wait follows. Accept equivalent explanations.", s)],
        use="rehearsal", level=3, seconds=150,
        hints=[("Bestimme getrennt, wann das Gerät fertig ist und wann die Person fertig ist.", "Find separately when the machine is ready and when the person is ready."),
               ("Die zusätzliche Wartezeit beginnt erst am späteren der beiden Zeitpunkte.", "The additional wait starts at the later of those two times.")],
        solution=("Das Gerät ist um 09:58 bereit, die Person um 10:05. Beides ist also erst um 10:05 fertig. Nach 5 Minuten Wartezeit beginnt die Vorführung frühestens um 10:10. Insgesamt vergehen 25 + 5 = 30 Minuten.",
                  "The machine is ready at 09:58 and the person at 10:05. Both are therefore ready at 10:05. After the 5-minute wait, the earliest demonstration start is 10:10. Total elapsed time is 25 + 5 = 30 minutes."))

    s = "M-D02"
    add(s, "tally_frequency_table", "data",
        "Striche in Häufigkeiten übersetzen", "Translate tallies into frequencies",
        "Eine Strichliste erfasst drei Antworten A, B und C. Jeder senkrechte Strich zählt genau eine Antwort. Ein Leerraum zwischen Strichgruppen ändert ihren Wert nicht. Übertrage die Häufigkeiten in Zahlen.",
        "A tally records three answers A, B and C. Each vertical stroke counts exactly one answer. A space between groups of strokes does not change their value. Write the frequencies as numbers.",
        [number("a", "Welche Häufigkeit gehört zu A?", "What is the frequency for A?", 6, s),
         number("b", "Welche Häufigkeit gehört zu B?", "What is the frequency for B?", 4, s),
         number("c", "Welche Häufigkeit gehört zu C?", "What is the frequency for C?", 8, s)],
        use="practice",
        hints=[("Zähle Striche, nicht Gruppen von Strichen.", "Count strokes, not groups of strokes."),
               ("Eine Gruppe mit fünf Strichen und ein weiterer Strich bedeuten zusammen sechs.", "A group of five strokes and one more stroke represent six altogether.")],
        solution=("A hat 5 + 1 = 6 Antworten, B hat 4 und C hat 5 + 3 = 8. In der Häufigkeitstabelle stehen deshalb A: 6, B: 4, C: 8.",
                  "A has 5 + 1 = 6 answers, B has 4, and C has 5 + 3 = 8. The frequency table therefore records A: 6, B: 4, C: 8."),
        fig=figure("table", {"headers": [L("Antwort", "Answer"), L("Striche", "Tally strokes")],
                              "rows": [["A", "||||| |"], ["B", "||||"], ["C", "||||| |||"]]},
                   "Strichliste: A mit fünf Strichen und einem weiteren, B mit vier Strichen, C mit fünf Strichen und drei weiteren.",
                   "Tallies: A has five strokes and one more, B has four strokes, C has five strokes and three more."))

    s = "M-D03"
    add(s, "largest_is_not_majority", "data",
        "Am meisten ist nicht immer mehr als die Hälfte", "The largest group need not be a majority",
        "Jede Person stimmt für genau eine der drei Möglichkeiten A, B oder C. Alle Stimmen sind im Diagramm enthalten. Sam sagt: „A hat die meisten Stimmen. Also hat mehr als die Hälfte aller Personen A gewählt.“ Prüfe die zweite Aussage.",
        "Each person votes for exactly one of A, B or C. The chart includes every vote. Sam says, 'A has the most votes. So more than half of all the people chose A.' Check the second statement.",
        [number("total", "Wie viele Stimmen gibt es insgesamt?", "How many votes are there altogether?", 20, s),
         choice("claim", "Hat mehr als die Hälfte aller Personen A gewählt?", "Did more than half of all the people choose A?",
                [("yes", "Ja", "Yes"), ("no", "Nein", "No")], "no", s),
         manual("reason", "Begründe mit der Gesamtzahl und der Stimmenzahl von A.", "Explain using the total and A's vote count.",
                "1 Punkt: Die Hälfte von 20 ist 10. A hat 9 Stimmen und damit nicht mehr als 10. Dass 9 der größte Einzelwert ist, genügt nicht für mehr als die Hälfte.",
                "1 point: half of 20 is 10. A has 9 votes, which is not more than 10. Being the largest individual count does not establish more than half.", s)],
        use="practice", seconds=150,
        hints=[("Addiere für die Gesamtzahl alle drei Säulenwerte.", "Add all three bar values to find the total."),
               ("Halbiere die Gesamtzahl, nicht nur die größte Säule.", "Halve the total, not just the largest bar."),
               ("Vergleiche A mit dieser Hälfte. „Mehr als“ bedeutet streng größer.", "Compare A with that half. 'More than' means strictly greater.")],
        solution=("9 + 7 + 4 = 20 Stimmen. Die Hälfte ist 10. A hat zwar mehr Stimmen als B oder C einzeln, aber 9 sind weniger als 10. Sams zweite Aussage ist falsch.",
                  "9 + 7 + 4 = 20 votes. Half is 10. A has more votes than B or C individually, but 9 is less than 10. Sam's second statement is false."),
        fig=figure("barChart", {"labels": ["A", "B", "C"], "values": [9, 7, 4], "max": 10, "step": 1,
                                 "yLabel": L("Stimmen", "Votes")},
                   "Säulendiagramm mit Skala 0 bis 10 in Einerschritten. A: 9, B: 7, C: 4 Stimmen.",
                   "Bar chart with scale 0 to 10 in steps of one. A: 9, B: 7, C: 4 votes."))

    s = "M-D03"
    add(s, "compare_different_chart_scales", "data",
        "Zwei Diagramme mit verschiedenen Skalen", "Compare charts with different scales",
        "Die Diagramme zeigen Besucherzahlen an Ort A und Ort B für Montag und Dienstag. Jede Säule verwendet die Skala ihres eigenen Diagramms. Vergleiche die Besucherzahlen der beiden Orte.",
        "The charts show visitor counts at sites A and B on Monday and Tuesday. Each bar uses its own chart's scale. Compare the visitor counts at the two sites.",
        [choice("monday", "Welcher Ort hat am Montag mehr Besucher?", "Which site has more visitors on Monday?",
                [("a", "Ort A", "Site A"), ("b", "Ort B", "Site B"), ("equal", "Beide gleich viele", "Both have the same number")], "b", s,
                fig=figure("barChart", {"labels": [L("Mo", "Mon"), L("Di", "Tue")], "values": [15, 10], "max": 30, "step": 5,
                                          "yLabel": L("Ort B: Besucher", "Site B: visitors")},
                           "Ort B. Achse 0, 5, 10, 15, 20, 25, 30. Die Montagssäule reicht drei Skalenabstände hoch, die Dienstagssäule zwei.",
                           "Site B. Axis 0, 5, 10, 15, 20, 25, 30. Monday's bar is three scale intervals high and Tuesday's two.")),
         number("difference", "Um wie viele Besucher unterscheiden sich die Orte am Montag?", "By how many visitors do the sites differ on Monday?", 3, s),
         choice("two_days", "Welcher Ort hat an beiden Tagen zusammen mehr Besucher?", "Which site has more visitors across both days together?",
                [("a", "Ort A", "Site A"), ("b", "Ort B", "Site B"), ("equal", "Beide gleich viele", "Both have the same number")], "a", s)],
        use="check", level=3, seconds=150,
        hints=[("Lies die Achsenwerte in jedem Diagramm getrennt ab.", "Read the axis values separately in each chart."),
               ("Gleich hohe Säulen können bei verschiedenen Skalen verschiedene Zahlen bedeuten.", "Equal bar heights can represent different numbers on different scales.")],
        solution=("Am Montag hat A 12 und B 15 Besucher. B hat also 3 mehr. Zusammen hat A 12 + 20 = 32 Besucher und B 15 + 10 = 25. Über beide Tage hat A mehr.",
                  "On Monday A has 12 visitors and B has 15, so B has 3 more. Across both days A has 12 + 20 = 32 and B has 15 + 10 = 25. A has more across the two days."),
        fig=figure("barChart", {"labels": [L("Mo", "Mon"), L("Di", "Tue")], "values": [12, 20], "max": 24, "step": 4,
                                 "yLabel": L("Ort A: Besucher", "Site A: visitors")},
                   "Ort A. Achse 0, 4, 8, 12, 16, 20, 24. Die Montagssäule reicht drei Skalenabstände hoch, die Dienstagssäule fünf.",
                   "Site A. Axis 0, 4, 8, 12, 16, 20, 24. Monday's bar is three scale intervals high and Tuesday's five."))

    s = "M-D05"
    add(s, "fair_game_with_no_score", "data",
        "Auch Runden ohne Punkt berücksichtigen", "Include rounds with no score",
        "Zwei faire Glücksräder haben jeweils eine gleich große rote und blaue Hälfte. Sie werden unabhängig voneinander gedreht. Die vier geordneten Farbpaare in der Tabelle sind gleich wahrscheinlich. Ari erhält einen Punkt bei zweimal Rot. Bo erhält einen Punkt bei zweimal Blau. Bei zwei verschiedenen Farben erhält niemand einen Punkt. Vergleiche die Chance, in einer Runde einen Punkt zu erhalten.",
        "Two fair spinners each have equal red and blue halves. They are spun independently. The four ordered colour pairs in the table are equally likely. Ari scores one point for two reds. Bo scores one point for two blues. If the colours differ, nobody scores. Compare the chances of scoring a point in one round.",
        [choice("fair", "Haben Ari und Bo die gleiche Chance auf einen Punkt?", "Do Ari and Bo have the same chance of scoring a point?",
                [("same", "Ja, die Chancen sind gleich.", "Yes, their chances are equal."),
                 ("ari", "Nein, Aris Chance ist größer.", "No, Ari has a greater chance."),
                 ("bo", "Nein, Bos Chance ist größer.", "No, Bo has a greater chance.")], "same", s),
         number("neither", "Bei wie vielen der vier Farbpaare erhält niemand einen Punkt?", "For how many of the four colour pairs does nobody score?", 2, s),
         manual("reason", "Begründe die Chancen mithilfe der vier gleich wahrscheinlichen Farbpaare.", "Explain the chances using the four equally likely colour pairs.",
                "1 Punkt: Genau ein Farbpaar bringt Ari einen Punkt und genau eines Bo. Die beiden anderen bringen niemandem einen Punkt und bevorzugen keinen der beiden. Gleichwertige Erklärung zulässig.",
                "1 point: exactly one colour pair scores for Ari and exactly one for Bo. The other two score for neither and do not favour either player. Accept equivalent explanations.", s)],
        use="rehearsal", level=3, seconds=150,
        hints=[("Ordne jedes Farbpaar genau einer Möglichkeit zu: Punkt für Ari, Punkt für Bo oder kein Punkt.", "Assign each colour pair to exactly one outcome: Ari scores, Bo scores, or no score."),
               ("Gleiche Chancen bedeuten nicht, dass in jeder Runde jemand gewinnen muss.", "Equal chances do not require someone to score in every round.")],
        solution=("Rot–Rot bringt Ari einen Punkt, Blau–Blau bringt Bo einen Punkt. Beide haben ein günstiges von vier gleich wahrscheinlichen Farbpaaren. Rot–Blau und Blau–Rot bringen keinen Punkt. Die Chancen sind gleich; kurze tatsächliche Spielserien müssen trotzdem nicht gleich viele Punkte liefern.",
                  "Red–red scores for Ari and blue–blue scores for Bo. Each has one favourable pair among four equally likely pairs. Red–blue and blue–red score for nobody. The chances are equal, although actual short games need not produce equal scores."),
        fig=figure("table", {"headers": [L("Erstes Rad", "First spinner"), L("Zweites Rad", "Second spinner")],
                              "rows": [[L("Rot", "Red"), L("Rot", "Red")], [L("Rot", "Red"), L("Blau", "Blue")],
                                       [L("Blau", "Blue"), L("Rot", "Red")], [L("Blau", "Blue"), L("Blau", "Blue")]]},
                   "Vier geordnete Farbpaare: Rot–Rot, Rot–Blau, Blau–Rot, Blau–Blau.",
                   "Four ordered colour pairs: red–red, red–blue, blue–red, blue–blue."))

    return out
