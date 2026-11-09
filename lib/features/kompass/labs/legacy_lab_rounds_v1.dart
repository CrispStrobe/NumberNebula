import 'dart:math' as math;

import 'kompass_lab_round.dart';

// Recipe 1: the original four lab generators exactly as frozen at
// 8971225b9c435867fa5f8fa4e20e98e3baa24fce (see
// tool/kompass/baselines/lab_recipes_v1.json). Drafts saved with this recipe
// replay the same rounds; new sessions use recipe 2 in kompass_lab_round.dart.
// Do not edit: the legacy audit compares this output byte for byte.

KompassLabRound generateLegacyLabRoundV1(String labId, int index, int seed) {
  final random = math.Random(seed + index * 7919);
  return switch (labId) {
    'number_dock' => _legacyNumberRound(index % 3, random),
    'supply_station' => _legacySupplyRound(index % 4, random),
    'data_observatory' => _legacyDataRound(index % 3, random),
    'geometry_workshop' => _legacyGeometryRound(index % 3, random),
    _ => throw ArgumentError.value(labId, 'labId', 'No recipe-1 lab'),
  };
}

KompassLabRound _legacyNumberRound(int variant, math.Random random) {
  if (variant == 2) {
    final min = (2 + random.nextInt(6)) * 100;
    final max = min + (1 + random.nextInt(4)) * 100;
    final middle = (min + max) ~/ 2;
    return KompassLabRound(
        type: 'numberLine',
        skillIds: const ['M-Z03'],
        config: {'min': min, 'max': max, 'target': middle, 'step': 5},
        titleDe: 'Die Mitte finden',
        titleEn: 'Find the midpoint',
        promptDe:
            'Verschiebe die Markierung genau in die Mitte zwischen $min und $max.',
        promptEn: 'Move the marker exactly halfway between $min and $max.',
        solutionDe:
            '$middle liegt genau in der Mitte: Beide Abstände sind ${middle - min}.',
        solutionEn:
            '$middle is the midpoint: both distances are ${middle - min}.',
        hintsDe: [
          'Vergleiche den Abstand zu beiden Enden.',
          'Halbiere den Abstand ${max - min} und gehe vom linken Ende aus weiter.',
          '$min + ${(max - min) ~/ 2} = $middle.'
        ],
        hintsEn: [
          'Compare the distances to both ends.',
          'Halve the distance ${max - min} and add it to the left endpoint.',
          '$min + ${(max - min) ~/ 2} = $middle.'
        ]);
  }
  final digits = [
    1 + random.nextInt(4),
    2 + random.nextInt(6),
    2 + random.nextInt(6),
    1 + random.nextInt(8)
  ];
  final target = placeValueTotal(digits);
  final regroup = variant == 1;
  final start = [digits[0] - 1, digits[1] + 9, digits[2] + 9, digits[3] + 10];
  return KompassLabRound(
      type: regroup ? 'regroup' : 'buildNumber',
      skillIds: const ['M-Z01'],
      config: {'target': target, 'start': start},
      titleDe: regroup ? 'Bündeln ohne Wertänderung' : 'Eine Zahl bauen',
      titleEn: regroup ? 'Regroup without changing value' : 'Build a number',
      promptDe: regroup
          ? 'Diese Darstellung ist $target wert. Bündle jeweils 10 in die nächstgrößere Stelle. Am Ende stehen in jeder Stelle höchstens 9.'
          : 'Baue $target mit Tausendern, Hundertern, Zehnern und Einern. In jeder Stelle dürfen am Ende höchstens 9 stehen.',
      promptEn: regroup
          ? 'This representation is worth $target. Trade groups of 10 into the next place. Finish with at most 9 in each place.'
          : 'Build $target from thousands, hundreds, tens and ones. Finish with at most 9 in each place.',
      solutionDe:
          '$target = ${digits[0]} T + ${digits[1]} H + ${digits[2]} Z + ${digits[3]} E. Bündeln ändert den Wert nicht.',
      solutionEn:
          '$target = ${digits[0]} thousands + ${digits[1]} hundreds + ${digits[2]} tens + ${digits[3]} ones. Regrouping preserves value.',
      hintsDe: [
        'Jede Stelle ist zehnmal so viel wert wie die rechts daneben.',
        '10 Einer sind 1 Zehner; 10 Zehner sind 1 Hunderter; 10 Hunderter sind 1 Tausender.',
        'Die Stellen sind ${digits.join(' | ')} von links nach rechts.'
      ],
      hintsEn: [
        'Each place is worth ten times the place to its right.',
        '10 ones make 1 ten; 10 tens make 1 hundred; 10 hundreds make 1 thousand.',
        'The places are ${digits.join(' | ')} from left to right.'
      ]);
}

KompassLabRound _legacySupplyRound(int variant, math.Random random) {
  if (variant == 0) {
    final prices = [125 + random.nextInt(5) * 25, 80 + random.nextInt(5) * 10];
    final quantities = [1 + random.nextInt(3), 1 + random.nextInt(2)];
    final total = prices[0] * quantities[0] + prices[1] * quantities[1];
    final paid = ((total + 999) ~/ 1000) * 1000;
    return KompassLabRound(
        type: 'shopping',
        skillIds: const ['M-G04'],
        config: {
          'prices': prices,
          'quantities': quantities,
          'totalCents': total,
          'paidCents': paid,
          'changeCents': paid - total
        },
        titleDe: 'Kassenbon und Wechselgeld',
        titleEn: 'Receipt and change',
        promptDe:
            'Berechne den Gesamtpreis. Bezahlt wird mit ${labMoney(paid, true)}. Stelle das richtige Wechselgeld mit Münzen zusammen.',
        promptEn:
            'Find the total price. Payment is ${labMoney(paid, false)}. Build the correct change using coins.',
        solutionDe:
            'Der Einkauf kostet ${labMoney(total, true)}. ${labMoney(paid, true)} − ${labMoney(total, true)} = ${labMoney(paid - total, true)} Wechselgeld.',
        solutionEn:
            'The purchase costs ${labMoney(total, false)}. ${labMoney(paid, false)} − ${labMoney(total, false)} = ${labMoney(paid - total, false)} change.',
        hintsDe: [
          'Anzahl × Einzelpreis ergibt den Preis einer Tabellenzeile.',
          'Addiere beide Zeilen. Ziehe den Gesamtpreis vom bezahlten Betrag ab.',
          'Gesamtpreis: ${labMoney(total, true)}; Wechselgeld: ${labMoney(paid - total, true)}.'
        ],
        hintsEn: [
          'Quantity × unit price gives the cost of one table row.',
          'Add both rows, then subtract the total from the payment.',
          'Total: ${labMoney(total, false)}; change: ${labMoney(paid - total, false)}.'
        ]);
  }
  if (variant == 1) {
    final hour = 7 + random.nextInt(10), minute = 15 + random.nextInt(9) * 5;
    final duration = 65 + random.nextInt(12) * 5;
    final end = hour * 60 + minute + duration;
    return KompassLabRound(
        type: 'elapsed',
        skillIds: const ['M-G05'],
        config: {
          'startHour': hour,
          'startMinute': minute,
          'duration': duration,
          'endHour': end ~/ 60,
          'endMinute': end % 60
        },
        titleDe: 'Ankunftszeit einstellen',
        titleEn: 'Set the arrival time',
        promptDe:
            'Abfahrt: ${labTime(hour, minute)} Uhr. Die Fahrt dauert $duration Minuten. Stelle die Ankunftszeit ein; benutze die 24-Stunden-Schreibweise.',
        promptEn:
            'Departure: ${labTime(hour, minute)}. The trip lasts $duration minutes. Set the arrival time using the 24-hour clock.',
        solutionDe:
            '${labTime(hour, minute)} + $duration Minuten = ${labTime(end ~/ 60, end % 60)} Uhr.',
        solutionEn:
            '${labTime(hour, minute)} + $duration minutes = ${labTime(end ~/ 60, end % 60)}.',
        hintsDe: [
          'Eine Stunde hat 60 Minuten.',
          'Bis zur nächsten vollen Stunde sind es ${60 - minute} Minuten. Rechne dann weiter.',
          'Die richtige Ankunftszeit ist ${labTime(end ~/ 60, end % 60)} Uhr.'
        ],
        hintsEn: [
          'One hour has 60 minutes.',
          'The next full hour is ${60 - minute} minutes away. Continue from there.',
          'The arrival time is ${labTime(end ~/ 60, end % 60)}.'
        ]);
  }
  if (variant == 2) {
    final target =
        (1 + random.nextInt(4)) * 1000 + (1 + random.nextInt(3)) * 250;
    return KompassLabRound(
        type: 'capacity',
        skillIds: const ['M-G07'],
        config: {'targetMl': target},
        titleDe: 'Vorrat abmessen',
        titleEn: 'Measure the supply',
        promptDe:
            'Fülle genau ${target ~/ 1000} l ${target % 1000} ml ab. Du hast 1-l-Flaschen und 250-ml-Becher. Mehrere Zusammenstellungen sind möglich.',
        promptEn:
            'Measure exactly ${target ~/ 1000} l ${target % 1000} ml. Use 1-litre bottles and 250-ml cups. More than one combination works.',
        solutionDe:
            'Die Gefäße enthalten zusammen $target ml. 1000 ml sind 1 l.',
        solutionEn:
            'The containers hold $target ml altogether. 1000 ml equals 1 litre.',
        hintsDe: [
          'Rechne alles in Millilitern.',
          '1 l = 1000 ml; vier Becher sind 1 l.',
          'Eine Möglichkeit: ${target ~/ 1000} Flaschen und ${(target % 1000) ~/ 250} Becher.'
        ],
        hintsEn: [
          'Use millilitres for every container.',
          '1 litre = 1000 ml; four cups make 1 litre.',
          'One solution: ${target ~/ 1000} bottles and ${(target % 1000) ~/ 250} cups.'
        ]);
  }
  final start = 2 + random.nextInt(4), length = 4 + random.nextInt(6);
  return KompassLabRound(
      type: 'length',
      skillIds: const ['M-G02'],
      config: {'start': start, 'end': start + length, 'targetMm': length * 10},
      titleDe: 'Messen ab einer anderen Stelle',
      titleEn: 'Measure from a different start',
      promptDe:
          'Das Band beginnt nicht bei 0. Lies seine Länge ab und gib sie in Millimetern an.',
      promptEn:
          'The strip does not start at zero. Read its length and give it in millimetres.',
      solutionDe:
          '${start + length} cm − $start cm = $length cm = ${length * 10} mm.',
      solutionEn:
          '${start + length} cm − $start cm = $length cm = ${length * 10} mm.',
      hintsDe: [
        'Der rechte Messwert allein ist nicht die Länge.',
        'Länge = Endwert − Startwert. 1 cm sind 10 mm.',
        '${start + length} − $start = $length cm, also ${length * 10} mm.'
      ],
      hintsEn: [
        'The right-hand reading alone is not the length.',
        'Length = end reading − start reading. 1 cm equals 10 mm.',
        '${start + length} − $start = $length cm, or ${length * 10} mm.'
      ]);
}

KompassLabRound _legacyDataRound(int variant, math.Random random) {
  if (variant == 0) {
    final values = List.generate(3, (_) => (1 + random.nextInt(6)) * 2);
    return KompassLabRound(
        type: 'buildChart',
        skillIds: const ['M-D02', 'M-D03'],
        config: {'values': values},
        titleDe: 'Ein Diagramm bauen',
        titleEn: 'Build a chart',
        promptDe:
            'Übertrage die Tabelle in das Säulendiagramm. Stelle jede Säule auf die richtige Höhe ein.',
        promptEn:
            'Transfer the table to the bar chart. Set each bar to the correct height.',
        solutionDe:
            'Die Säulen zeigen ${values.join(', ')}. Jeder Skalenabstand bedeutet 2.',
        solutionEn:
            'The bars show ${values.join(', ')}. Each scale interval represents 2.',
        hintsDe: [
          'Jede Tabellenzeile gehört zu genau einer Säule.',
          'Lies die Skala: 0, 2, 4, 6, 8, 10, 12.',
          'Die Höhen von links nach rechts sind ${values.join(', ')}.'
        ],
        hintsEn: [
          'Each table row belongs to one bar.',
          'Read the scale: 0, 2, 4, 6, 8, 10, 12.',
          'The heights from left to right are ${values.join(', ')}.'
        ]);
  }
  if (variant == 1) {
    final red = 2 + random.nextInt(5);
    return KompassLabRound(
        type: 'chance',
        skillIds: const ['M-D05'],
        config: {'red': red},
        titleDe: 'Gleiche Chancen herstellen',
        titleEn: 'Make equal chances',
        promptDe:
            'Im Beutel liegen $red Sternsteine. Stelle die Anzahl der Kreissteine so ein, dass beide Sorten gleich wahrscheinlich gezogen werden. Jeder Stein ist gleich groß.',
        promptEn:
            'The bag holds $red star tokens. Set the circle-token count so either type is equally likely to be drawn. All tokens have the same size.',
        solutionDe:
            '$red Sterne und $red Kreise ergeben gleiche Chancen. Auch dann können mehrere gleiche Sorten hintereinander kommen.',
        solutionEn:
            '$red stars and $red circles give equal chances. Repeated draws of the same type can still happen.',
        hintsDe: [
          'Vergleiche die Anzahlen, nicht eine einzelne Probeziehung.',
          'Jeder Stein hat die gleiche Chance. Beide Sorten brauchen gleich viele Steine.',
          'Stelle $red Kreissteine ein.'
        ],
        hintsEn: [
          'Compare the counts, not one trial draw.',
          'Every token has the same chance. Both types need equal counts.',
          'Set the circle count to $red.'
        ]);
  }
  final event = random.nextInt(3);
  final answer = ['certain', 'possible', 'impossible'][event];
  final eventDe =
      ['einen Stern oder einen Kreis', 'einen Stern', 'ein Dreieck'][event];
  final eventEn = ['a star or a circle', 'a star', 'a triangle'][event];
  final nameDe = ['sicher', 'möglich, aber nicht sicher', 'unmöglich'][event];
  final nameEn = ['certain', 'possible, but not certain', 'impossible'][event];
  return KompassLabRound(
      type: 'event',
      skillIds: const ['M-D04'],
      config: {
        'red': 3 + random.nextInt(3),
        'blue': 2 + random.nextInt(3),
        'answer': answer
      },
      titleDe: 'Sicher, möglich oder unmöglich?',
      titleEn: 'Certain, possible or impossible?',
      promptDe:
          'Du ziehst blind einen Stein. Wie ist das Ereignis, $eventDe zu ziehen?',
      promptEn:
          'Draw one token without looking. How would you describe drawing $eventEn?',
      solutionDe:
          'Das Ereignis ist $nameDe. Entscheidend sind alle Steine im Beutel, nicht nur die letzte Probeziehung.',
      solutionEn:
          'The event is $nameEn. What matters is every token in the bag, not just the last trial draw.',
      hintsDe: [
        'Welche Sorten liegen im Beutel?',
        'Passen alle Steine, nur einige oder gar keiner zur Beschreibung?',
        'Hier ist das Ereignis $nameDe.'
      ],
      hintsEn: [
        'Which types are in the bag?',
        'Do all tokens, some tokens or no tokens match the event?',
        'This event is $nameEn.'
      ]);
}

KompassLabRound _legacyGeometryRound(int variant, math.Random random) {
  if (variant == 0) {
    final square = random.nextBool();
    final points = square
        ? [
            [0, 0],
            [4, 0],
            [4, 4],
            [0, 4]
          ]
        : [
            [0, 0],
            [6, 0],
            [6, 3],
            [0, 3]
          ];
    final axes = square
        ? ['vertical', 'horizontal', 'diagonalDown', 'diagonalUp']
        : ['vertical', 'horizontal'];
    return KompassLabRound(
        type: 'axes',
        skillIds: const ['M-R05'],
        config: {'points': points, 'axes': axes},
        titleDe: 'Alle Spiegelachsen',
        titleEn: 'Every line of symmetry',
        promptDe:
            'Wähle alle Spiegelachsen dieser Figur. Eine ausgewählte Linie wird in der Figur eingezeichnet.',
        promptEn:
            'Select every line of symmetry. Each selected line appears on the shape.',
        solutionDe: square
            ? 'Das Quadrat hat vier Spiegelachsen: senkrecht, waagerecht und beide Diagonalen.'
            : 'Dieses Rechteck hat zwei Spiegelachsen: senkrecht und waagerecht. Seine Diagonalen sind keine Spiegelachsen.',
        solutionEn: square
            ? 'The square has four lines of symmetry: vertical, horizontal and both diagonals.'
            : 'This rectangle has two lines of symmetry: vertical and horizontal. Its diagonals are not lines of symmetry.',
        hintsDe: [
          'Beide Hälften müssen beim Falten deckungsgleich sein.',
          'Vergleiche auch die Diagonalen: Passen die Seitenlängen zusammen?',
          square
              ? 'Hier passen alle vier Linien.'
              : 'Hier passen nur die senkrechte und die waagerechte Linie.'
        ],
        hintsEn: [
          'Both halves must match when folded.',
          'Check the diagonals too: do the side lengths match?',
          square
              ? 'All four lines work here.'
              : 'Only the vertical and horizontal lines work here.'
        ]);
  }
  if (variant == 1) {
    final full = ['0,1', '1,0', '1,1', '1,2', '2,1', '3,1'];
    final removed = ['0,1', '1,0', '1,2', '3,1'][random.nextInt(4)];
    final fixed = full.where((c) => c != removed).toList();
    final pair = parseCell(removed)!;
    return KompassLabRound(
        type: 'cubeNet',
        skillIds: const ['M-R07'],
        config: {'cells': fixed},
        titleDe: 'Ein Würfelnetz ergänzen',
        titleEn: 'Complete a cube net',
        promptDe:
            'Füge genau ein Quadrat hinzu, sodass sich die sechs Quadrate zu einem Würfel falten lassen. Jede gültige Ergänzung zählt.',
        promptEn:
            'Add exactly one square so all six squares fold into a cube. Every valid completion is accepted.',
        solutionDe:
            'Die sechs Quadrate bilden sechs verschiedene Würfelflächen. Beim Falten überdeckt keine Fläche eine andere.',
        solutionEn:
            'The six squares form six different cube faces. No face overlaps another when folded.',
        hintsDe: [
          'Das neue Quadrat muss an einer Kante eines vorhandenen Quadrats liegen.',
          'Stelle dir eine Fläche als Boden vor und klappe ihre Nachbarn hoch. Es fehlen insgesamt sechs verschiedene Seiten.',
          'Eine Möglichkeit ist Zeile ${pair.$1 + 1}, Spalte ${pair.$2 + 1}.'
        ],
        hintsEn: [
          'The new square must share an edge with a given square.',
          'Imagine one face as the base and fold its neighbours up. You need six different sides.',
          'One solution is row ${pair.$1 + 1}, column ${pair.$2 + 1}.'
        ]);
  }
  final heights =
      List.generate(3, (_) => List.generate(3, (_) => random.nextInt(4)));
  heights[1][1] = 3;
  final right = random.nextBool();
  final expected = right
      ? heights.reversed.map((row) => row.reduce(math.max)).toList()
      : List.generate(
          3, (col) => heights.map((row) => row[col]).reduce(math.max));
  return KompassLabRound(
      type: 'sideView',
      skillIds: const ['M-R06'],
      config: {
        'heights': heights,
        'view': right ? 'right' : 'front',
        'expected': expected
      },
      titleDe: 'Eine Ansicht bauen',
      titleEn: 'Build a side view',
      promptDe:
          'Schaue in Pfeilrichtung auf das Würfelbauwerk. Stelle die drei Säulen der Ansicht von links nach rechts ein.',
      promptEn:
          'Look at the cube building along the arrow. Set the three columns of that view from left to right.',
      solutionDe:
          'Die sichtbaren Höhen von links nach rechts sind ${expected.join(', ')}. Jede Blicklinie zeigt ihren höchsten Stapel.',
      solutionEn:
          'The visible heights from left to right are ${expected.join(', ')}. Each sightline shows its tallest stack.',
      hintsDe: [
        'Die Pfeilrichtung legt fest, von welcher Seite du schaust.',
        'Hintereinanderstehende Stapel erscheinen in derselben Spalte. Nimm dort die größte Höhe.',
        'Die Höhen lauten ${expected.join(', ')}.'
      ],
      hintsEn: [
        'The arrow fixes the viewing direction.',
        'Stacks behind one another share a column. Use the greatest height on that sightline.',
        'The heights are ${expected.join(', ')}.'
      ]);
}
