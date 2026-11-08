"""Project-owned competency identifiers with newly written bilingual copy."""
from common import L


_ROWS = [
    ("M-Z01", "numbers", "Stellenwerte und Bündeln", "Place value and regrouping", "Zahlen darstellen, bündeln und den Wert beim Tauschen erhalten.", "Represent and regroup numbers while preserving their value.", "01_01", ["number_walls", "asteroid_math"]),
    ("M-Z02", "numbers", "Ordnen und Nachbarzahlen", "Ordering and neighbouring numbers", "Zahlen vergleichen und benachbarte Zehner oder Hunderter bestimmen.", "Compare numbers and locate neighbouring tens or hundreds.", "01_01", ["asteroid_math"]),
    ("M-Z03", "numbers", "Zahlenstrahl und Abstände", "Number lines and distances", "Gleiche Abstände, Mittelpunkte und fehlende Endpunkte nutzen.", "Use equal distances, midpoints and missing endpoints.", "01_01", []),
    ("M-Z04", "numbers", "Addieren, Subtrahieren, Prüfen", "Add, subtract and check", "Additive Aufgaben lösen und mit der Umkehroperation prüfen.", "Solve additive problems and check with the inverse operation.", "01_02", ["number_walls", "arithmancer_crosswords"]),
    ("M-Z05", "numbers", "Malnehmen und Teilen", "Multiplication and division", "Einmaleinsbeziehungen und Stellenwerte auf größere Aufgaben übertragen.", "Transfer multiplication facts and place value to larger calculations.", "01_02", ["number_walls", "kenken"]),
    ("M-Z06", "numbers", "Rechnung und Rechengeschichte", "Calculations and stories", "Zwischen Handlung, Rechengeschichte und Operation wechseln.", "Connect an action, a mathematical story and an operation.", "01_02", []),
    ("M-Z07", "numbers", "Rechenstrategien erklären", "Explain calculation strategies", "Hilfsaufgaben und Ausgleichsschritte erklären und prüfen.", "Explain and check helpful calculations and compensation steps.", "01_02", ["asteroid_math"]),
    ("M-Z08", "numbers", "Muster und Regeln", "Patterns and rules", "Eindeutig vorgegebene Regeltypen erkennen, anwenden und beschreiben.", "Recognise, apply and describe explicitly constrained rules.", "01_03", []),
    ("M-Z09", "numbers", "Systematisch optimieren", "Systematic optimisation", "Möglichkeiten geordnet vergleichen und ein bestes Ergebnis begründen.", "Compare possibilities systematically and justify an optimum.", "01_03", ["number_walls"]),
    ("M-Z10", "numbers", "Sachaufgaben modellieren", "Model word problems", "Relevante Angaben auswählen, passende Rechnungen bilden und Ergebnisse deuten.", "Select relevant information, form calculations and interpret results.", "01_03", []),
    ("M-Z11", "numbers", "Überschlagen und prüfen", "Estimate and check", "Gerundete Vergleichswerte für eine sinnvolle Ergebniskontrolle nutzen.", "Use rounded reference values to check whether results are plausible.", "01_02", ["asteroid_math"]),
    ("M-Z12", "numbers", "Alle Möglichkeiten finden", "Find every possibility", "Kombinationen ohne Dopplung erfassen und Vollständigkeit begründen.", "List combinations without duplicates and explain completeness.", "01_03", ["codebreaker"]),
    ("M-R01", "geometry", "Eigenschaften von Figuren", "Properties of shapes", "Figuren anhand von Seiten und Winkeln erkennen und beschreiben.", "Recognise and describe shapes using sides and angles.", "02_02", ["hull_plating"]),
    ("M-R02", "geometry", "Figuren zusammensetzen", "Compose and decompose shapes", "Teilfiguren zusammensetzen oder zerlegen und dabei Regeln einhalten.", "Compose or partition shapes while respecting the stated constraints.", "02_02", ["hull_plating", "grid_filler_game"]),
    ("M-R03", "geometry", "Flächen vergleichen", "Compare areas", "Flächen mit derselben Einheitsfläche messen und vergleichen.", "Measure and compare areas using the same unit square.", "02_02", ["sector_painter", "hull_plating"]),
    ("M-R04", "geometry", "Figuren gedanklich drehen", "Mentally rotate shapes", "Eine Drehung von Verschiebung und Spiegelung unterscheiden.", "Distinguish a rotation from a translation or reflection.", "02_03", ["hull_plating"]),
    ("M-R05", "geometry", "Spiegeln und Spiegelachsen", "Reflections and symmetry axes", "Spiegelbilder erzeugen und Aussagen über Achsen prüfen.", "Construct reflections and check claims about symmetry axes.", "02_03", ["warp_fold"]),
    ("M-R06", "geometry", "Baupläne und Ansichten", "Plans and views", "Turmhöhen, Verdeckung und Blickrichtung miteinander verbinden.", "Connect tower heights, occlusion and viewing direction.", "02_01", ["perspective_puzzle", "block_counter"]),
    ("M-R07", "geometry", "Würfelnetze", "Cube nets", "Ein Netz gedanklich falten und benachbarte oder gegenüberliegende Flächen finden.", "Mentally fold a net and identify adjacent or opposite faces.", "02_04", ["cube_scanner"]),
    ("M-R08", "geometry", "Umfang und Flächeninhalt", "Perimeter and area", "Randlänge und bedeckte Fläche unterscheiden und getrennt bestimmen.", "Distinguish boundary length from covered area and determine each separately.", "02_02", ["hull_plating"]),
    ("M-G01", "measurement", "Plausible Größen", "Plausible quantities", "Alltagsgrößen mit passenden Einheiten und Bezugswerten einschätzen.", "Estimate everyday quantities using suitable units and reference values.", "03_01", []),
    ("M-G02", "measurement", "Längen umrechnen", "Convert lengths", "Längen in gleiche Einheiten umwandeln, vergleichen und berechnen.", "Convert lengths to common units, compare them and calculate with them.", "03_01", []),
    ("M-G03", "measurement", "Preisbeziehungen", "Price relationships", "Eine ausdrücklich gleiche Preisregel für verschiedene Mengen anwenden.", "Apply an explicitly constant price rule to different quantities.", "03_02", ["galactic_market"]),
    ("M-G04", "measurement", "Mit Geld rechnen", "Calculate with money", "Teilpreise, Gesamtpreis und Rückgeld in mehrschrittigen Aufgaben bestimmen.", "Determine subtotals, total cost and change in multi-step problems.", "03_02", ["galactic_market"]),
    ("M-G05", "measurement", "Zeitpunkte und Zeitspannen", "Times and durations", "Uhrzeiten, Dauer und Fahrpläne auch über eine volle Stunde hinweg verknüpfen.", "Connect clock times, durations and timetables across hour boundaries.", "03_02", ["chrono_repair"]),
    ("M-G06", "measurement", "Messen und Zeichnen", "Measure and draw", "Den Nullpunkt des Lineals nutzen und maßhaltige Zeichnungen prüfen.", "Use a ruler's zero point and check scale-accurate drawings.", "03_01", []),
    ("M-G07", "measurement", "Liter und Milliliter", "Litres and millilitres", "Mit der gegebenen Beziehung 1 l = 1000 ml Mengen ergänzen und vergleichen.", "Use the given relationship 1 l = 1000 ml to complete and compare quantities.", "03_01", []),
    ("M-D01", "data", "Tabellen lesen", "Read tables", "Tabellenwerte entnehmen, verknüpfen und fehlende Häufigkeiten bestimmen.", "Read and combine table values and determine missing frequencies.", "04_01", []),
    ("M-D02", "data", "Daten darstellen", "Represent data", "Häufigkeiten mit beschrifteter, einheitlicher Skala darstellen.", "Represent frequencies with labels and a consistent scale.", "04_01", []),
    ("M-D03", "data", "Diagrammskalen verstehen", "Understand chart scales", "Skalen beim Ablesen berücksichtigen und Aussagen anhand von Daten prüfen.", "Account for scales when reading charts and check data-based claims.", "04_01", []),
    ("M-D04", "data", "Sicher, möglich, unmöglich", "Certain, possible, impossible", "Ereignisse einem vollständig beschriebenen Ergebnisraum zuordnen.", "Classify events using a fully specified set of possible outcomes.", "04_02", []),
    ("M-D05", "data", "Chancen vergleichen", "Compare chances", "Anteile gleich wahrscheinlicher Ergebnisse vergleichen und faire Regeln begründen.", "Compare proportions of equally likely outcomes and justify fair rules.", "04_02", []),
]

_CURRICULUM = {"M-Z11", "M-Z12", "M-R01", "M-R08", "M-G06", "M-G07", "M-D02", "M-D03"}


def competencies():
    return [{"id": id, "domain": domain, "title": L(de, en),
             "goal": L(goal_de, goal_en),
             "evidence": "curriculum" if id in _CURRICULUM else "published2025",
             "curriculumUrl": f"https://www.bildungsplaene-bw.de/,Lde/BP2016BW_ALLG_GS_M.V2_IK_3-4_{chapter}",
             "gameKeys": games}
            for id, domain, de, en, goal_de, goal_en, chapter, games in _ROWS]
