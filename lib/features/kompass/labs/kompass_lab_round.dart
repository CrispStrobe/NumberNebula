import 'dart:math' as math;

const kompassLabIds = <String>[
  'number_dock',
  'supply_station',
  'data_observatory',
  'geometry_workshop',
];

String kompassLabTitle(String id, bool german) => switch (id) {
      'number_dock' => german ? 'Zahlendock' : 'Place Value Dock',
      'supply_station' => german ? 'Versorgungsstation' : 'Supply Station',
      'data_observatory' => german ? 'Datenobservatorium' : 'Data Observatory',
      'geometry_workshop' =>
        german ? 'Geometriewerkstatt' : 'Geometry Workshop',
      _ => german ? 'Lernlabor' : 'Learning lab',
    };

/// Original, deterministic learning rounds. Their outcomes are practice
/// evidence; they must never be promoted to independent assessment results.
class KompassLabRound {
  final String type;
  final List<String> skillIds;
  final Map<String, dynamic> config;
  final String titleDe, titleEn, promptDe, promptEn, solutionDe, solutionEn;
  final List<String> hintsDe, hintsEn;

  const KompassLabRound({
    required this.type,
    required this.skillIds,
    required this.config,
    required this.titleDe,
    required this.titleEn,
    required this.promptDe,
    required this.promptEn,
    required this.solutionDe,
    required this.solutionEn,
    required this.hintsDe,
    required this.hintsEn,
  });

  String title(bool german) => german ? titleDe : titleEn;
  String prompt(bool german) => german ? promptDe : promptEn;
  String solution(bool german) => german ? solutionDe : solutionEn;
  List<String> hints(bool german) => german ? hintsDe : hintsEn;

  Map<String, dynamic> createResponse() => switch (type) {
        'buildNumber' => {
            'counts': [0, 0, 0, 0]
          },
        'regroup' => {'counts': List<int>.from(config['start'] as List)},
        'numberLine' => {'value': config['min']},
        'shopping' => {'total': '', 'coins': List<int>.filled(8, 0)},
        'elapsed' => {
            'hour': config['startHour'],
            'minute': config['startMinute']
          },
        'capacity' => {'bottles': 0, 'cups': 0},
        'length' => {'millimetres': ''},
        'buildChart' => {
            'values': [0, 0, 0]
          },
        'chance' => {'blue': 0, 'draws': <String>[]},
        'event' => {'answer': '', 'draws': <String>[]},
        'axes' => {'axes': <String>[]},
        'cubeNet' => {'cells': <String>[]},
        'sideView' => {
            'heights': [0, 0, 0]
          },
        _ => <String, dynamic>{},
      };

  /// Restore only the known response shape. A damaged local draft must not
  /// turn a counter list into an out-of-range widget access.
  Map<String, dynamic> normalizeResponse(Map<String, dynamic> saved) {
    final defaults = createResponse();
    final result = <String, dynamic>{};
    for (final entry in defaults.entries) {
      final value = saved[entry.key];
      if (entry.value is List<int>) {
        final expected = entry.value as List<int>;
        final maximum = switch (entry.key) {
          'counts' => 29,
          'coins' => 30,
          'values' => 12,
          'heights' => 3,
          _ => 30,
        };
        result[entry.key] = value is List &&
                value.length == expected.length &&
                value.every((n) => n is num && n.isFinite)
            ? value.map((n) => (n as num).toInt().clamp(0, maximum)).toList()
            : List<int>.of(expected);
      } else if (entry.value is List) {
        final strings = stringList(value);
        result[entry.key] = switch (entry.key) {
          'draws' => strings
              .where((s) => s == 'star' || s == 'circle')
              .take(50)
              .toList(),
          'axes' => strings
              .where(const [
                'vertical',
                'horizontal',
                'diagonalDown',
                'diagonalUp'
              ].contains)
              .toSet()
              .toList(),
          'cells' =>
            strings.where((s) => parseCell(s) != null).toSet().toList(),
          _ => strings,
        };
      } else if (entry.value is int) {
        final number =
            value is num && value.isFinite ? value.toInt() : entry.value as int;
        result[entry.key] = switch (entry.key) {
          'value' => number.clamp(config['min'] as int, config['max'] as int),
          'hour' => number.clamp(0, 23),
          'minute' => number.clamp(0, 55),
          'bottles' => number.clamp(0, 10),
          'cups' => number.clamp(0, 24),
          'blue' => number.clamp(0, 12),
          _ => number,
        };
      } else {
        result[entry.key] = value?.toString() ?? entry.value;
      }
    }
    return result;
  }

  KompassLabCheck check(Map<String, dynamic> response) {
    int points = 0, maximum = 1;
    String feedbackDe = 'Prüfe deine Darstellung noch einmal.',
        feedbackEn = 'Check your representation once more.';
    switch (type) {
      case 'buildNumber':
      case 'regroup':
        final counts = intList(response['counts']);
        final value = placeValueTotal(counts);
        final canonical =
            counts.length == 4 && counts.every((n) => n >= 0 && n <= 9);
        points = value == config['target'] && canonical ? 1 : 0;
        feedbackDe = value != config['target']
            ? 'Der Wert stimmt noch nicht. Ein Tausender zählt 1000, ein Hunderter 100, ein Zehner 10 und ein Einer 1.'
            : 'Der Wert stimmt. Bündle jetzt so, dass in jeder Stelle höchstens 9 stehen.';
        feedbackEn = value != config['target']
            ? 'The value is not right yet. A thousand is 1000, a hundred 100, a ten 10 and a one 1.'
            : 'The value is right. Regroup until every place contains at most 9.';
      case 'numberLine':
        points = response['value'] == config['target'] ? 1 : 0;
        feedbackDe =
            'Die Mitte ist von beiden Enden gleich weit entfernt. Vergleiche die beiden Abstände.';
        feedbackEn =
            'The midpoint is the same distance from both ends. Compare the two distances.';
      case 'shopping':
        maximum = 2;
        final total = parseLabNumber(response['total']);
        final billCorrect = total != null &&
            (total * 100 - (config['totalCents'] as int)).abs() < 0.001;
        final coinsCorrect =
            coinTotal(intList(response['coins'])) == config['changeCents'];
        points = (billCorrect ? 1 : 0) + (coinsCorrect ? 1 : 0);
        feedbackDe = billCorrect
            ? 'Der Kassenbon stimmt. Wechselgeld ist der bezahlte Betrag minus dem Gesamtpreis.'
            : 'Multipliziere jeden Einzelpreis mit der Anzahl. Addiere danach die beiden Preise.';
        feedbackEn = billCorrect
            ? 'The receipt is correct. Change is the amount paid minus the total price.'
            : 'Multiply each unit price by its quantity, then add the two costs.';
      case 'elapsed':
        maximum = 2;
        points = (response['hour'] == config['endHour'] ? 1 : 0) +
            (response['minute'] == config['endMinute'] ? 1 : 0);
        feedbackDe =
            'Gehe zuerst bis zur nächsten vollen Stunde und dann die übrigen Minuten weiter. Eine Stunde hat 60 Minuten.';
        feedbackEn =
            'Go to the next full hour, then add the remaining minutes. An hour has 60 minutes.';
      case 'capacity':
        points = (numberAt(response, 'bottles') * 1000 +
                    numberAt(response, 'cups') * 250) ==
                config['targetMl']
            ? 1
            : 0;
        feedbackDe =
            'Eine Flasche enthält 1000 ml, ein Becher 250 ml. Vier Becher ersetzen eine Flasche.';
        feedbackEn =
            'A bottle holds 1000 ml and a cup 250 ml. Four cups replace one bottle.';
      case 'length':
        points = parseLabNumber(response['millimetres']) == config['targetMm']
            ? 1
            : 0;
        feedbackDe =
            'Ziehe den Startwert vom Endwert ab. Wandle dann um: 1 cm = 10 mm.';
        feedbackEn =
            'Subtract the start reading from the end reading. Then convert: 1 cm = 10 mm.';
      case 'buildChart':
        final actual = intList(response['values']);
        final expected = intList(config['values']);
        maximum = expected.length;
        for (var i = 0; i < expected.length; i++) {
          if (i < actual.length && actual[i] == expected[i]) points++;
        }
        feedbackDe =
            'Vergleiche jeden Balken mit seiner Tabellenzeile. Die Skala zählt in Zweierschritten.';
        feedbackEn =
            'Compare each bar with its table row. The scale counts in steps of two.';
      case 'chance':
        points = numberAt(response, 'blue') == config['red'] ? 1 : 0;
        feedbackDe =
            'Alle Steine werden gleich gut gemischt. Gleiche Anzahlen geben den zwei Sorten die gleiche Chance; einzelne Ziehungen müssen sich nicht abwechseln.';
        feedbackEn =
            'Every token is equally mixed. Equal counts give both types equal chances; individual draws need not alternate.';
      case 'event':
        points = response['answer'] == config['answer'] ? 1 : 0;
        feedbackDe =
            'Sicher heißt: jeder Stein passt. Unmöglich heißt: kein Stein passt. Sonst ist das Ereignis möglich, aber nicht sicher.';
        feedbackEn =
            'Certain means every token fits. Impossible means none fits. Otherwise the event is possible, but not certain.';
      case 'axes':
        points =
            _sameSet(stringList(response['axes']), stringList(config['axes']))
                ? 1
                : 0;
        feedbackDe =
            'Stelle dir das Falten an jeder ausgewählten Linie vor. Beide Hälften müssen vollständig aufeinanderliegen. Suche alle solchen Linien.';
        feedbackEn =
            'Imagine folding on each selected line. Both halves must match completely. Find every line that works.';
      case 'cubeNet':
        final additions = stringList(response['cells']).toSet();
        final fixed = stringList(config['cells']).toSet();
        final legal = additions.length == 1 &&
            additions.intersection(fixed).isEmpty &&
            additions.every((cell) {
              final pair = parseCell(cell);
              return pair != null &&
                  pair.$1 >= 0 &&
                  pair.$1 < 5 &&
                  pair.$2 >= 0 &&
                  pair.$2 < 4;
            });
        points = legal && isCubeNet({...fixed, ...additions}) ? 1 : 0;
        feedbackDe =
            'Ein Würfel hat sechs verschiedene Flächen. Das neue Quadrat muss an einer Kante anschließen und darf beim Falten keine andere Fläche überdecken.';
        feedbackEn =
            'A cube has six different faces. Join the new square along an edge; folding must not put two squares on the same face.';
      case 'sideView':
        maximum = 3;
        final actual = intList(response['heights']);
        final expected = intList(config['expected']);
        for (var i = 0; i < expected.length; i++) {
          if (i < actual.length && actual[i] == expected[i]) points++;
        }
        feedbackDe =
            'Schaue in Pfeilrichtung. Für jede Spalte der Ansicht zählt der höchste Stapel in dieser Blicklinie. Verdeckte Würfel vergrößern die Höhe nicht.';
        feedbackEn =
            'Look along the arrow. Each column shows the tallest stack on that sightline. Hidden cubes do not add extra height.';
    }
    return KompassLabCheck(
        points: points,
        maxPoints: maximum,
        feedbackDe: points == maximum ? solutionDe : feedbackDe,
        feedbackEn: points == maximum ? solutionEn : feedbackEn);
  }
}

class KompassLabCheck {
  final int points, maxPoints;
  final String feedbackDe, feedbackEn;
  const KompassLabCheck(
      {required this.points,
      required this.maxPoints,
      required this.feedbackDe,
      required this.feedbackEn});
  bool get correct => points == maxPoints;
  String feedback(bool german) => german ? feedbackDe : feedbackEn;
}

const labCoinValues = [200, 100, 50, 20, 10, 5, 2, 1];
int coinTotal(List<int> counts) {
  var total = 0;
  for (var i = 0; i < math.min(counts.length, labCoinValues.length); i++) {
    total += counts[i] * labCoinValues[i];
  }
  return total;
}

int placeValueTotal(List<int> counts) => counts.length != 4
    ? -1
    : counts[0] * 1000 + counts[1] * 100 + counts[2] * 10 + counts[3];
List<int> intList(Object? value) => value is List
    ? value.map((v) => v is num ? v.toInt() : 0).toList()
    : <int>[];
List<String> stringList(Object? value) =>
    value is List ? value.map((v) => v.toString()).toList() : <String>[];
int numberAt(Map<String, dynamic> value, String key) =>
    value[key] is num ? (value[key] as num).toInt() : 0;
double? parseLabNumber(Object? value) {
  final parsed = double.tryParse(value
      .toString()
      .trim()
      .replaceAll('€', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.'));
  return parsed != null && parsed.isFinite ? parsed : null;
}

bool _sameSet(Iterable<String> a, Iterable<String> b) {
  final aa = a.toSet(), bb = b.toSet();
  return aa.length == bb.length && aa.containsAll(bb);
}

String labMoney(int cents, bool german) =>
    '${cents ~/ 100}${german ? ',' : '.'}${(cents % 100).toString().padLeft(2, '0')} €';
String labTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

KompassLabRound generateKompassLabRound(String labId, int index, int seed) {
  final random = math.Random(seed + index * 7919);
  return switch (labId) {
    'number_dock' => _numberRound(index % 3, random),
    'supply_station' => _supplyRound(index % 4, random),
    'data_observatory' => _dataRound(index % 3, random),
    'geometry_workshop' => _geometryRound(index % 3, random),
    _ => throw ArgumentError.value(labId, 'labId', 'Unknown learning lab'),
  };
}

KompassLabRound _numberRound(int variant, math.Random random) {
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

KompassLabRound _supplyRound(int variant, math.Random random) {
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

KompassLabRound _dataRound(int variant, math.Random random) {
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

KompassLabRound _geometryRound(int variant, math.Random random) {
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

(int, int)? parseCell(String value) {
  final parts = value.split(',');
  if (parts.length != 2) return null;
  final row = int.tryParse(parts[0]), col = int.tryParse(parts[1]);
  return row == null || col == null ? null : (row, col);
}

typedef _Vector = (int, int, int);
_Vector _negative(_Vector v) => (-v.$1, -v.$2, -v.$3);

/// Independently folds every edge-connected square into a cube orientation.
/// A valid net occupies all six normals once, with consistent shared edges.
bool isCubeNet(Set<String> cells) {
  if (cells.length != 6) return false;
  final parsed = cells.map(parseCell).toList();
  if (parsed.any((c) => c == null)) return false;
  final coordinates = parsed.cast<(int, int)>().toSet();
  final first = coordinates.first;
  final orientation = <(int, int), (_Vector, _Vector, _Vector)>{
    first: ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
  };
  final queue = [first];
  for (var index = 0; index < queue.length; index++) {
    final cell = queue[index];
    final (normal, right, down) = orientation[cell]!;
    final neighbours = <(int, int), (_Vector, _Vector, _Vector)>{
      (cell.$1, cell.$2 + 1): (right, _negative(normal), down),
      (cell.$1, cell.$2 - 1): (_negative(right), normal, down),
      (cell.$1 + 1, cell.$2): (down, right, _negative(normal)),
      (cell.$1 - 1, cell.$2): (_negative(down), right, normal),
    };
    for (final entry in neighbours.entries) {
      if (!coordinates.contains(entry.key)) continue;
      if (orientation.containsKey(entry.key)) {
        if (orientation[entry.key] != entry.value) return false;
      } else {
        orientation[entry.key] = entry.value;
        queue.add(entry.key);
      }
    }
  }
  return orientation.length == 6 &&
      orientation.values.map((value) => value.$1).toSet().length == 6;
}
