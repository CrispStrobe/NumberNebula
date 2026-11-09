"""Project-owned competency identifiers with newly written bilingual copy."""
from common import L
from source_mapping import load_source_mapping, SourceMappingError


_ROWS = [
    ("M-Z01", "numbers", "Stellenwerte und Bündeln", "Place value and regrouping", "Zahlen darstellen, bündeln und den Wert beim Tauschen erhalten.", "Represent and regroup numbers while preserving their value.", ["number_walls", "asteroid_math"]),
    ("M-Z02", "numbers", "Ordnen und Nachbarzahlen", "Ordering and neighbouring numbers", "Zahlen vergleichen und benachbarte Zehner oder Hunderter bestimmen.", "Compare numbers and locate neighbouring tens or hundreds.", ["asteroid_math"]),
    ("M-Z03", "numbers", "Zahlenstrahl und Abstände", "Number lines and distances", "Gleiche Abstände, Mittelpunkte und fehlende Endpunkte nutzen.", "Use equal distances, midpoints and missing endpoints.", []),
    ("M-Z04", "numbers", "Addieren, Subtrahieren, Prüfen", "Add, subtract and check", "Additive Aufgaben lösen und mit der Umkehroperation prüfen.", "Solve additive problems and check with the inverse operation.", ["number_walls", "arithmancer_crosswords"]),
    ("M-Z05", "numbers", "Malnehmen und Teilen", "Multiplication and division", "Einmaleinsbeziehungen und Stellenwerte auf größere Aufgaben übertragen.", "Transfer multiplication facts and place value to larger calculations.", ["number_walls", "kenken"]),
    ("M-Z06", "numbers", "Rechnung und Rechengeschichte", "Calculations and stories", "Zwischen Handlung, Rechengeschichte und Operation wechseln.", "Connect an action, a mathematical story and an operation.", []),
    ("M-Z07", "numbers", "Rechenstrategien erklären", "Explain calculation strategies", "Hilfsaufgaben und Ausgleichsschritte erklären und prüfen.", "Explain and check helpful calculations and compensation steps.", ["asteroid_math"]),
    ("M-Z08", "numbers", "Muster und Regeln", "Patterns and rules", "Eindeutig vorgegebene Regeltypen erkennen, anwenden und beschreiben.", "Recognise, apply and describe explicitly constrained rules.", []),
    ("M-Z09", "numbers", "Systematisch optimieren", "Systematic optimisation", "Möglichkeiten geordnet vergleichen und ein bestes Ergebnis begründen.", "Compare possibilities systematically and justify an optimum.", ["number_walls"]),
    ("M-Z10", "numbers", "Sachaufgaben modellieren", "Model word problems", "Relevante Angaben auswählen, passende Rechnungen bilden und Ergebnisse deuten.", "Select relevant information, form calculations and interpret results.", []),
    ("M-Z11", "numbers", "Überschlagen und prüfen", "Estimate and check", "Gerundete Vergleichswerte für eine sinnvolle Ergebniskontrolle nutzen.", "Use rounded reference values to check whether results are plausible.", ["asteroid_math"]),
    ("M-Z12", "numbers", "Alle Möglichkeiten finden", "Find every possibility", "Kombinationen ohne Dopplung erfassen und Vollständigkeit begründen.", "List combinations without duplicates and explain completeness.", ["codebreaker"]),
    ("M-R01", "geometry", "Eigenschaften von Figuren", "Properties of shapes", "Figuren anhand von Seiten und Winkeln erkennen und beschreiben.", "Recognise and describe shapes using sides and angles.", ["hull_plating"]),
    ("M-R02", "geometry", "Figuren zusammensetzen", "Compose and decompose shapes", "Teilfiguren zusammensetzen oder zerlegen und dabei Regeln einhalten.", "Compose or partition shapes while respecting the stated constraints.", ["hull_plating", "grid_filler_game"]),
    ("M-R03", "geometry", "Flächen vergleichen", "Compare areas", "Flächen mit derselben Einheitsfläche messen und vergleichen.", "Measure and compare areas using the same unit square.", ["sector_painter", "hull_plating"]),
    ("M-R04", "geometry", "Figuren gedanklich drehen", "Mentally rotate shapes", "Eine Drehung von Verschiebung und Spiegelung unterscheiden.", "Distinguish a rotation from a translation or reflection.", ["hull_plating"]),
    ("M-R05", "geometry", "Spiegeln und Spiegelachsen", "Reflections and symmetry axes", "Spiegelbilder erzeugen und Aussagen über Achsen prüfen.", "Construct reflections and check claims about symmetry axes.", ["warp_fold"]),
    ("M-R06", "geometry", "Baupläne und Ansichten", "Plans and views", "Turmhöhen, Verdeckung und Blickrichtung miteinander verbinden.", "Connect tower heights, occlusion and viewing direction.", ["perspective_puzzle", "block_counter"]),
    ("M-R07", "geometry", "Würfelnetze", "Cube nets", "Ein Netz gedanklich falten und benachbarte oder gegenüberliegende Flächen finden.", "Mentally fold a net and identify adjacent or opposite faces.", ["cube_scanner"]),
    ("M-R08", "geometry", "Umfang und Flächeninhalt", "Perimeter and area", "Randlänge und bedeckte Fläche unterscheiden und getrennt bestimmen.", "Distinguish boundary length from covered area and determine each separately.", ["hull_plating"]),
    ("M-G01", "measurement", "Plausible Größen", "Plausible quantities", "Alltagsgrößen mit passenden Einheiten und Bezugswerten einschätzen.", "Estimate everyday quantities using suitable units and reference values.", []),
    ("M-G02", "measurement", "Längen umrechnen", "Convert lengths", "Längen in gleiche Einheiten umwandeln, vergleichen und berechnen.", "Convert lengths to common units, compare them and calculate with them.", []),
    ("M-G03", "measurement", "Preisbeziehungen", "Price relationships", "Eine ausdrücklich gleiche Preisregel für verschiedene Mengen anwenden.", "Apply an explicitly constant price rule to different quantities.", ["galactic_market"]),
    ("M-G04", "measurement", "Mit Geld rechnen", "Calculate with money", "Teilpreise, Gesamtpreis und Rückgeld in mehrschrittigen Aufgaben bestimmen.", "Determine subtotals, total cost and change in multi-step problems.", ["galactic_market"]),
    ("M-G05", "measurement", "Zeitpunkte und Zeitspannen", "Times and durations", "Uhrzeiten, Dauer und Fahrpläne auch über eine volle Stunde hinweg verknüpfen.", "Connect clock times, durations and timetables across hour boundaries.", ["chrono_repair"]),
    ("M-G06", "measurement", "Messen und Zeichnen", "Measure and draw", "Den Nullpunkt des Lineals nutzen und maßhaltige Zeichnungen prüfen.", "Use a ruler's zero point and check scale-accurate drawings.", []),
    ("M-G07", "measurement", "Liter und Milliliter", "Litres and millilitres", "Mit der gegebenen Beziehung 1 l = 1000 ml Mengen ergänzen und vergleichen.", "Use the given relationship 1 l = 1000 ml to complete and compare quantities.", []),
    ("M-D01", "data", "Tabellen lesen", "Read tables", "Tabellenwerte entnehmen, verknüpfen und fehlende Häufigkeiten bestimmen.", "Read and combine table values and determine missing frequencies.", []),
    ("M-D02", "data", "Daten darstellen", "Represent data", "Häufigkeiten mit beschrifteter, einheitlicher Skala darstellen.", "Represent frequencies with labels and a consistent scale.", []),
    ("M-D03", "data", "Diagrammskalen verstehen", "Understand chart scales", "Skalen beim Ablesen berücksichtigen und Aussagen anhand von Daten prüfen.", "Account for scales when reading charts and check data-based claims.", []),
    ("M-D04", "data", "Sicher, möglich, unmöglich", "Certain, possible, impossible", "Ereignisse einem vollständig beschriebenen Ergebnisraum zuordnen.", "Classify events using a fully specified set of possible outcomes.", []),
    ("M-D05", "data", "Chancen vergleichen", "Compare chances", "Anteile gleich wahrscheinlicher Ergebnisse vergleichen und faire Regeln begründen.", "Compare proportions of equally likely outcomes and justify fair rules.", []),
]

def competencies():
    mapping = {row["id"]: row for row in load_source_mapping()["competencies"]}
    result = []
    for id, domain, de, en, goal_de, goal_en, games in _ROWS:
        reference = mapping.get(id)
        if reference is None or reference["domain"] != domain:
            raise SourceMappingError(f"{id}: authored goal disagrees with source identity/domain")
        result.append({"id": id, "domain": reference["domain"],
                       "title": L(de, en), "goal": L(goal_de, goal_en),
                       "evidence": reference["evidence"],
                       "curriculumUrl": reference["curriculumUrl"],
                       "gameKeys": games,
                       "curriculumCode": reference["curriculumCode"],
                       "curriculumVersion": reference["curriculumVersion"],
                       "estimatedSeconds": reference["estimatedSeconds"]})
    if len(result) != len(mapping) or {row["id"] for row in result} != set(mapping):
        raise SourceMappingError("authored goals must match all 32 source competencies exactly once")
    return result
