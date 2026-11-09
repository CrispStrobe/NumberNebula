import 'dart:math' as math;

import '../services/kompass_scorer.dart';
import 'extensions/reasoning_rounds.dart';
import 'extensions/journey_rounds.dart';
import 'extensions/area_rounds.dart';
import 'extensions/chance_rounds.dart';
import 'legacy_lab_rounds_v1.dart';

const kompassLabIds = <String>[
  'number_dock',
  'supply_station',
  'data_observatory',
  'geometry_workshop',
  'reasoning_workshop',
  'journey_planner',
  'area_studio',
  'chance_detective',
];

/// Explicitly rehearsed course procedures must not later appear as unseen
/// checks, even when the learner leaves the lab before submitting an answer.
const kompassLabExposedFamilies = <String, List<String>>{
  'journey_planner': ['mg05_backward_departure', 'mg05_timetable_with_walk'],
  'chance_detective': [
    'md04_draw_two_without_replacement',
    'md04_repeat_spin_possible',
  ],
};

/// Shared by controls and restored drafts; leaves room for intermediate carries.
const labMaxPlaceCount = 99;

/// The labs that existed before recipe 2; only they have a recipe 1.
const kompassLegacyLabIds = {
  'number_dock',
  'supply_station',
  'data_observatory',
  'geometry_workshop',
};

String kompassLabTitle(String id, bool german) => switch (id) {
      'number_dock' => german ? 'Zahlendock' : 'Place Value Dock',
      'supply_station' => german ? 'Versorgungsstation' : 'Supply Station',
      'data_observatory' => german ? 'Datenobservatorium' : 'Data Observatory',
      'geometry_workshop' =>
        german ? 'Geometriewerkstatt' : 'Geometry Workshop',
      'reasoning_workshop' => german ? 'Denkwerkstatt' : 'Reasoning Workshop',
      'journey_planner' => german ? 'Reiseplanung' : 'Journey Planner',
      'area_studio' => german ? 'Flächenstudio' : 'Area Studio',
      'chance_detective' => german ? 'Zufallsdetektive' : 'Chance Detectives',
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
        _ when type.startsWith('reasoning_') => createReasoningResponse(this),
        _ when type.startsWith('journey_') => createJourneyResponse(this),
        _ when type.startsWith('area_') => createAreaResponse(this),
        _ when type.startsWith('chance_') =>
          createChanceDetectiveResponse(this),
        'buildNumber' => {
            'counts': [0, 0, 0, 0]
          },
        'regroup' => {'counts': List<int>.from(config['start'] as List)},
        'regroupWrite' => {
            'counts': List<int>.from(config['start'] as List),
            'number': ''
          },
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
    if (type.startsWith('reasoning_'))
      return normalizeReasoningResponse(this, saved);
    if (type.startsWith('journey_'))
      return normalizeJourneyResponse(this, saved);
    if (type.startsWith('area_')) return normalizeAreaResponse(this, saved);
    if (type.startsWith('chance_'))
      return normalizeChanceDetectiveResponse(this, saved);
    final defaults = createResponse();
    final result = <String, dynamic>{};
    for (final entry in defaults.entries) {
      final value = saved[entry.key];
      if (entry.value is List<int>) {
        final expected = entry.value as List<int>;
        final maximum = switch (entry.key) {
          'counts' => labMaxPlaceCount,
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
              .where(const ['star', 'circle', 'triangle'].contains)
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
    if (type.startsWith('reasoning_'))
      return checkReasoningRound(this, response);
    if (type.startsWith('journey_')) return checkJourneyRound(this, response);
    if (type.startsWith('area_')) return checkAreaRound(this, response);
    if (type.startsWith('chance_'))
      return checkChanceDetectiveRound(this, response);
    int points = 0, maximum = 1;
    String feedbackDe = 'Prüfe deine Darstellung noch einmal.',
        feedbackEn = 'Check your representation once more.';
    switch (type) {
      case 'buildNumber':
      case 'regroup':
      case 'regroupWrite':
        final counts = intList(response['counts']);
        final value = placeValueTotal(counts);
        final canonical =
            counts.length == 4 && counts.every((n) => n >= 0 && n <= 9);
        final built = value == config['target'] && canonical;
        points = built ? 1 : 0;
        feedbackDe = value != config['target']
            ? 'Der Wert stimmt noch nicht. Ein Tausender zählt 1000, ein Hunderter 100, ein Zehner 10 und ein Einer 1.'
            : 'Der Wert stimmt. Bündle jetzt so, dass in jeder Stelle höchstens 9 stehen.';
        feedbackEn = value != config['target']
            ? 'The value is not right yet. A thousand is 1000, a hundred 100, a ten 10 and a one 1.'
            : 'The value is right. Regroup until every place contains at most 9.';
        if (type == 'regroupWrite') {
          maximum = 2;
          final written = parseLabNumber(response['number']) ==
              (config['target'] as int).toDouble();
          if (written) points++;
          if (built && !written) {
            feedbackDe =
                'Das Bündeln stimmt. Lies jetzt die Stellen ab und schreibe die Zahl auf.';
            feedbackEn =
                'The regrouping is right. Now read the places and write down the number.';
          }
        }
      case 'numberLine':
        points = response['value'] == config['target'] ? 1 : 0;
        feedbackDe =
            'Die Mitte ist von beiden Enden gleich weit entfernt. Vergleiche die beiden Abstände.';
        feedbackEn =
            'The midpoint is the same distance from both ends. Compare the two distances.';
      case 'shopping':
        maximum = 2;
        final total = parseLabNumber(response['total'], unit: '€');
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
        final withinSupply = numberAt(response, 'bottles') <=
            (config['maxBottles'] as int? ?? 10);
        points = withinSupply &&
                (numberAt(response, 'bottles') * 1000 +
                        numberAt(response, 'cups') * 250) ==
                    config['targetMl']
            ? 1
            : 0;
        feedbackDe = withinSupply
            ? 'Eine Flasche enthält 1000 ml, ein Becher 250 ml. Vier Becher ersetzen eine Flasche.'
            : 'So viele Flaschen sind nicht da. Ersetze fehlende Flaschen durch Becher.';
        feedbackEn = withinSupply
            ? 'A bottle holds 1000 ml and a cup 250 ml. Four cups replace one bottle.'
            : 'There are not that many bottles. Replace missing bottles with cups.';
      case 'length':
        points = parseLabNumber(response['millimetres'], unit: 'mm') ==
                config['targetMm']
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
        points = numberAt(response, 'blue') ==
                (config['circles'] as int? ?? config['red'] as int)
            ? 1
            : 0;
        final relational = config['circles'] != null;
        feedbackDe = relational
            ? 'Alle Steine werden gleich gut gemischt. Jeder Stein hat dieselbe Chance: Vergleiche die Anzahlen der Steine auf beiden Seiten. Einzelne Ziehungen müssen sich nicht abwechseln.'
            : 'Alle Steine werden gleich gut gemischt. Gleiche Anzahlen geben den zwei Sorten die gleiche Chance; einzelne Ziehungen müssen sich nicht abwechseln.';
        feedbackEn = relational
            ? 'Every token is equally mixed and has the same chance: compare the token counts on both sides. Individual draws need not alternate.'
            : 'Every token is equally mixed. Equal counts give both types equal chances; individual draws need not alternate.';
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

/// Bare values use the field's displayed unit; written units must agree.
double? parseLabNumber(Object? value, {String unit = ''}) =>
    KompassScorer.parseNumber(value, unit: unit);

bool _sameSet(Iterable<String> a, Iterable<String> b) {
  final aa = a.toSet(), bb = b.toSet();
  return aa.length == bb.length && aa.containsAll(bb);
}

String labMoney(int cents, bool german) =>
    '${cents ~/ 100}${german ? ',' : '.'}${(cents % 100).toString().padLeft(2, '0')} €';
String labTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Recipe 2 (2026-11-09) made the original four labs harder; recipe 1 keeps
/// their frozen generators for drafts saved before that change.
const kompassLabRecipe = 2;

KompassLabRound generateKompassLabRound(String labId, int index, int seed,
    {int recipe = kompassLabRecipe}) {
  if (recipe == 1 && kompassLegacyLabIds.contains(labId)) {
    return generateLegacyLabRoundV1(labId, index, seed);
  }
  final random = math.Random(seed + index * 7919);
  return switch (labId) {
    'number_dock' => _numberRound(index % 3, random),
    'supply_station' => _supplyRound(index % 4, random),
    'data_observatory' => _dataRound(index % 3, random),
    'geometry_workshop' => _geometryRound(index % 3, random),
    'reasoning_workshop' => generateReasoningRound(index, seed),
    'journey_planner' => generateJourneyRound(index, seed),
    'area_studio' => generateAreaRound(index, seed),
    'chance_detective' => generateChanceDetectiveRound(index, seed),
    _ => throw ArgumentError.value(labId, 'labId', 'Unknown learning lab'),
  };
}

KompassLabRound _numberRound(int variant, math.Random random) {
  if (variant == 2) {
    // Non-round endpoints: the midpoint has to be calculated, not recognised.
    final min = (10 + random.nextInt(70)) * 10;
    final span = (6 + random.nextInt(25)) * 20;
    final max = min + span;
    final middle = min + span ~/ 2;
    return KompassLabRound(
        type: 'numberLine',
        skillIds: const ['M-Z03'],
        config: {'min': min, 'max': max, 'target': middle, 'step': 10},
        titleDe: 'Die Mitte finden',
        titleEn: 'Find the midpoint',
        promptDe:
            'Verschiebe die Markierung genau in die Mitte zwischen $min und $max.',
        promptEn: 'Move the marker exactly halfway between $min and $max.',
        solutionDe:
            'Der Abstand ist $max − $min = $span. Die Hälfte davon ist ${span ~/ 2}. $min + ${span ~/ 2} = $middle.',
        solutionEn:
            'The distance is $max − $min = $span. Half of it is ${span ~/ 2}. $min + ${span ~/ 2} = $middle.',
        hintsDe: [
          'Die Mitte ist von beiden Enden gleich weit entfernt.',
          'Berechne zuerst den Abstand $max − $min. Halbiere ihn und gehe vom linken Ende aus weiter.',
          '$min + ${span ~/ 2} = $middle.'
        ],
        hintsEn: [
          'The midpoint is the same distance from both ends.',
          'First find the distance $max − $min. Halve it and add it to the left endpoint.',
          '$min + ${span ~/ 2} = $middle.'
        ]);
  }
  if (variant == 1) return _regroupRound(random);
  return _buildNumberRound(random);
}

const _placeNamesDe = ['Tausender', 'Hunderter', 'Zehner', 'Einer'];
const _placeNamesEn = ['thousands', 'hundreds', 'tens', 'ones'];

List<int> placeDigits(int n) =>
    [n ~/ 1000, n % 1000 ~/ 100, n % 100 ~/ 10, n % 10];

String _placeList(List<(int, int)> parts, bool german) {
  final items = [
    for (final (place, count) in parts)
      '$count ${german ? _placeNamesDe[place] : _placeNamesEn[place]}'
  ];
  if (items.length == 1) return items.single;
  final last = items.removeLast();
  return '${items.join(', ')} ${german ? 'und' : 'and'} $last';
}

/// German number word for 1..9999 (school spelling, written as one word).
String germanNumberWord(int n) {
  const ones = [
    '', 'eins', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht',
    'neun' //
  ];
  const teens = [
    'zehn', 'elf', 'zwölf', 'dreizehn', 'vierzehn', 'fünfzehn', 'sechzehn',
    'siebzehn', 'achtzehn', 'neunzehn' //
  ];
  const tens = [
    '', '', 'zwanzig', 'dreißig', 'vierzig', 'fünfzig', 'sechzig', 'siebzig',
    'achtzig', 'neunzig' //
  ];
  String prefix(int d) => d == 1 ? 'ein' : ones[d];
  final [t, h, z, e] = placeDigits(n);
  final rest = n % 100;
  final below100 = rest == 0
      ? ''
      : rest < 10
          ? ones[rest]
          : rest < 20
              ? teens[rest - 10]
              : e == 0
                  ? tens[z]
                  : '${prefix(e)}und${tens[z]}';
  return '${t > 0 ? '${prefix(t)}tausend' : ''}'
      '${h > 0 ? '${prefix(h)}hundert' : ''}$below100';
}

/// English number word for 1..9999 (British "and" before tens and ones).
String englishNumberWord(int n) {
  const ones = [
    '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine' //
  ];
  const teens = [
    'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen' //
  ];
  const tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety' //
  ];
  final [t, h, z, e] = placeDigits(n);
  final rest = n % 100;
  final parts = <String>[
    if (t > 0) '${ones[t]} thousand',
    if (h > 0) '${ones[h]} hundred',
  ];
  if (rest > 0) {
    final words = rest < 10
        ? ones[rest]
        : rest < 20
            ? teens[rest - 10]
            : e == 0
                ? tens[z]
                : '${tens[z]}-${ones[e]}';
    parts.add(parts.isEmpty ? words : 'and $words');
  }
  return parts.join(' ');
}

/// The target is never shown in digits: the learner has to interpret a
/// number word, a scrambled place description with an empty place, an
/// un-bundled amount or a step across a place boundary.
KompassLabRound _buildNumberRound(math.Random random) {
  final kind = random.nextInt(4);
  final digits = [
    2 + random.nextInt(7),
    random.nextInt(10),
    random.nextInt(10),
    random.nextInt(10)
  ];
  // Empty places are the classic error source; most rounds contain one.
  if (kind == 1 || random.nextInt(3) > 0) digits[1 + random.nextInt(3)] = 0;
  late final String clueDe, clueEn, hintDe, hintEn;
  switch (kind) {
    case 0:
      final target = placeValueTotal(digits);
      clueDe = '„${germanNumberWord(target)}“';
      clueEn = '“${englishNumberWord(target)}”';
      hintDe = 'Zerlege das Zahlwort: Wie viele Tausender, Hunderter, '
          'Zehner und Einer werden genannt? Was nicht genannt wird, ist 0.';
      hintEn = 'Split the number word: how many thousands, hundreds, tens and '
          'ones does it name? A place that is not named is 0.';
    case 1:
      final parts = [
        for (var i = 0; i < 4; i++)
          if (digits[i] > 0) (i, digits[i])
      ]..shuffle(random);
      clueDe = _placeList(parts, true);
      clueEn = _placeList(parts, false);
      hintDe = 'Die Angaben stehen durcheinander. Ordne sie nach Stellen. '
          'Eine Stelle, die nicht vorkommt, bekommt 0.';
      hintEn = 'The parts are mixed up. Sort them by place. A place that is '
          'not mentioned gets 0.';
    case 2:
      final counts = List<int>.of(digits);
      // Un-bundle one or two places so the description has 10 or more.
      final trades = 1 + random.nextInt(2);
      for (var n = 0, guard = 0; n < trades && guard < 20; guard++) {
        final i = random.nextInt(3);
        if (counts[i] == 0 || counts[i + 1] + 10 > 19) continue;
        counts[i]--;
        counts[i + 1] += 10;
        n++;
      }
      if (counts.every((c) => c <= 9)) {
        counts[0]--;
        counts[1] += 10;
      }
      final parts = [
        for (var i = 0; i < 4; i++)
          if (counts[i] > 0) (i, counts[i])
      ];
      clueDe = _placeList(parts, true);
      clueEn = _placeList(parts, false);
      hintDe = '10 Einer sind 1 Zehner, 10 Zehner sind 1 Hunderter und '
          '10 Hunderter sind 1 Tausender. Bündle, wo 10 oder mehr stehen.';
      hintEn = '10 ones make 1 ten, 10 tens make 1 hundred and 10 hundreds '
          'make 1 thousand. Regroup wherever there are 10 or more.';
    default:
      // A step of 1, 10 or 100 that crosses a place boundary.
      final place = 1 + random.nextInt(3);
      final delta = [1000, 100, 10, 1][place];
      final up = random.nextBool();
      digits[place] = up ? 0 : 9;
      final target = placeValueTotal(digits);
      final base = up ? target - delta : target + delta;
      clueDe = up
          ? 'die Zahl, die um $delta größer ist als $base'
          : 'die Zahl, die um $delta kleiner ist als $base';
      clueEn = up
          ? 'the number that is $delta more than $base'
          : 'the number that is $delta less than $base';
      hintDe = up
          ? 'Rechne $base + $delta. Achte darauf, ob eine Stelle über 9 '
              'hinausgeht und gebündelt werden muss.'
          : 'Rechne $base − $delta. Achte darauf, ob du an einer Stelle '
              'entbündeln musst.';
      hintEn = up
          ? 'Work out $base + $delta. Watch for a place that goes past 9 '
              'and has to be regrouped.'
          : 'Work out $base − $delta. Watch for a place that has to be '
              'un-bundled.';
  }
  final target = placeValueTotal(digits);
  return KompassLabRound(
      type: 'buildNumber',
      skillIds: const ['M-Z01'],
      config: {'target': target, 'clue': kind},
      titleDe: 'Eine Zahl bauen',
      titleEn: 'Build a number',
      promptDe:
          'Lege diese Zahl mit Tausendern, Hundertern, Zehnern und Einern: '
          '$clueDe. In jeder Stelle dürfen am Ende höchstens 9 stehen.',
      promptEn: 'Build this number from thousands, hundreds, tens and ones: '
          '$clueEn. Finish with at most 9 in each place.',
      solutionDe: '$target = ${digits[0]} T + ${digits[1]} H + ${digits[2]} Z '
          '+ ${digits[3]} E.',
      solutionEn: '$target = ${digits[0]} thousands + ${digits[1]} hundreds + '
          '${digits[2]} tens + ${digits[3]} ones.',
      hintsDe: [
        hintDe,
        'Jede Stelle ist zehnmal so viel wert wie die rechts daneben.',
        'Die Stellen sind ${digits.join(' | ')} von links nach rechts.'
      ],
      hintsEn: [
        hintEn,
        'Each place is worth ten times the place to its right.',
        'The places are ${digits.join(' | ')} from left to right.'
      ]);
}

/// The material is un-bundled in several places, sometimes so that one
/// regrouping causes the next. Its value is not stated: after regrouping the
/// learner also writes down the number.
KompassLabRound _regroupRound(math.Random random) {
  final digits = [
    2 + random.nextInt(7),
    random.nextInt(10),
    random.nextInt(10),
    random.nextInt(10)
  ];
  final target = placeValueTotal(digits);
  final start = List<int>.of(digits);
  final trades = 2 + random.nextInt(3);
  for (var n = 0, guard = 0; n < trades && guard < 40; guard++) {
    final i = random.nextInt(3);
    if (start[i] == 0 || start[i + 1] + 10 > 29) continue;
    start[i]--;
    start[i + 1] += 10;
    n++;
  }
  if (start.where((c) => c > 9).length < 2) {
    // Guarantee at least two places that need regrouping.
    for (var i = 0; i < 3 && start.where((c) => c > 9).length < 2; i++) {
      if (start[i + 1] <= 9 && start[i] > 0) {
        start[i]--;
        start[i + 1] += 10;
      }
    }
  }
  return KompassLabRound(
      type: 'regroupWrite',
      skillIds: const ['M-Z01'],
      config: {'target': target, 'start': start},
      titleDe: 'Bündeln ohne Wertänderung',
      titleEn: 'Regroup without changing value',
      promptDe: 'Auf dem Brett liegen ${_placeList([
            for (var i = 0; i < 4; i++)
              if (start[i] > 0) (i, start[i])
          ], true)}. '
          'Bündle jeweils 10 in die nächstgrößere Stelle, bis in jeder Stelle höchstens 9 stehen. '
          'Schreibe dann die Zahl auf.',
      promptEn: 'The board holds ${_placeList([
            for (var i = 0; i < 4; i++)
              if (start[i] > 0) (i, start[i])
          ], false)}. '
          'Trade groups of 10 into the next place until every place has at most 9. '
          'Then write down the number.',
      solutionDe: '$target = ${digits[0]} T + ${digits[1]} H + ${digits[2]} Z '
          '+ ${digits[3]} E. Bündeln ändert den Wert nicht.',
      solutionEn: '$target = ${digits[0]} thousands + ${digits[1]} hundreds + '
          '${digits[2]} tens + ${digits[3]} ones. Regrouping preserves value.',
      hintsDe: [
        'Beginne bei den Einern. Ein neuer Zehner kann bei den Zehnern wieder 10 voll machen.',
        '10 Einer sind 1 Zehner; 10 Zehner sind 1 Hunderter; 10 Hunderter sind 1 Tausender.',
        'Nach dem Bündeln stehen dort ${digits.join(' | ')}.'
      ],
      hintsEn: [
        'Start with the ones. A new ten can fill up the tens to 10 again.',
        '10 ones make 1 ten; 10 tens make 1 hundred; 10 hundreds make 1 thousand.',
        'After regrouping the places are ${digits.join(' | ')}.'
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
    // The amount is given as a fraction of a litre, and the bottle supply is
    // sometimes too small, so cups have to stand in for whole litres.
    final litres = 1 + random.nextInt(4), quarters = 1 + random.nextInt(3);
    final target = litres * 1000 + quarters * 250;
    final maxBottles = random.nextBool() ? 10 : litres - 1;
    final fraction = ['', '¼', '½', '¾'][quarters];
    final limitDe = maxBottles >= litres
        ? ''
        : maxBottles == 0
            ? ' Es ist keine Flasche mehr da.'
            : maxBottles == 1
                ? ' Es ist nur noch 1 Flasche da.'
                : ' Es sind nur noch $maxBottles Flaschen da.';
    final limitEn = maxBottles >= litres
        ? ''
        : maxBottles == 0
            ? ' There are no bottles left.'
            : maxBottles == 1
                ? ' Only 1 bottle is left.'
                : ' Only $maxBottles bottles are left.';
    final bottles = math.min(litres, maxBottles);
    final cups = (target - bottles * 1000) ~/ 250;
    final bottlesDe = bottles == 1 ? '1 Flasche' : '$bottles Flaschen';
    final bottlesEn = bottles == 1 ? '1 bottle' : '$bottles bottles';
    final cupsDe = cups == 1 ? '1 Becher' : '$cups Becher';
    final cupsEn = cups == 1 ? '1 cup' : '$cups cups';
    return KompassLabRound(
        type: 'capacity',
        skillIds: const ['M-G07'],
        config: {'targetMl': target, 'maxBottles': maxBottles},
        titleDe: 'Vorrat abmessen',
        titleEn: 'Measure the supply',
        promptDe:
            'Fülle genau $litres $fraction l ab. Du hast 1-l-Flaschen und 250-ml-Becher.$limitDe',
        promptEn:
            'Measure exactly $litres $fraction litres. Use 1-litre bottles and 250-ml cups.$limitEn',
        solutionDe:
            '$litres $fraction l = $target ml. $bottlesDe und $cupsDe ergeben ${bottles * 1000} ml + ${cups * 250} ml = $target ml.',
        solutionEn:
            '$litres $fraction litres = $target ml. $bottlesEn and $cupsEn give ${bottles * 1000} ml + ${cups * 250} ml = $target ml.',
        hintsDe: [
          '1 l = 1000 ml. Wie viele Milliliter sind $fraction l?',
          '¼ l = 250 ml, ½ l = 500 ml, ¾ l = 750 ml. Vier Becher ersetzen eine Flasche.',
          'Eine Möglichkeit: $bottlesDe und $cupsDe.'
        ],
        hintsEn: [
          '1 litre = 1000 ml. How many millilitres is $fraction litre?',
          '¼ l = 250 ml, ½ l = 500 ml, ¾ l = 750 ml. Four cups replace one bottle.',
          'One solution: $bottlesEn and $cupsEn.'
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
    // Relational goals with a distractor type in the bag: "equal to the
    // stars" alone would only ask for copying a number.
    final goal = random.nextInt(3);
    final stars = 2 + random.nextInt(goal == 1 ? 5 : 4);
    final triangles = 1 + random.nextInt(goal == 2 ? 4 : 3);
    final circles = switch (goal) {
      0 => stars,
      1 => stars * 2,
      _ => stars + triangles,
    };
    final trianglesDe = triangles == 1 ? '1 Dreieck' : '$triangles Dreiecke';
    final trianglesEn = triangles == 1 ? '1 triangle' : '$triangles triangles';
    final goalDe = [
      'ein Kreis genauso wahrscheinlich ist wie ein Stern',
      'ein Kreis doppelt so wahrscheinlich ist wie ein Stern',
      'ein Kreis genauso wahrscheinlich ist wie „kein Kreis“',
    ][goal];
    final goalEn = [
      'a circle is exactly as likely as a star',
      'a circle is twice as likely as a star',
      'a circle is exactly as likely as “not a circle”',
    ][goal];
    final reasonDe = [
      'Gleich viele Kreise wie Sterne: $circles. ${triangles == 1 ? 'Das Dreieck ändert' : 'Die Dreiecke ändern'} daran nichts.',
      'Doppelt so viele Kreise wie Sterne: 2 · $stars = $circles.',
      '„Kein Kreis“ sind alle Sterne und Dreiecke: $stars + $triangles = $circles. So viele Kreise braucht es.',
    ][goal];
    final reasonEn = [
      'As many circles as stars: $circles. The ${triangles == 1 ? 'triangle does' : 'triangles do'} not change that.',
      'Twice as many circles as stars: 2 · $stars = $circles.',
      '“Not a circle” means every star and triangle: $stars + $triangles = $circles. That many circles are needed.',
    ][goal];
    return KompassLabRound(
        type: 'chance',
        skillIds: const ['M-D05'],
        config: {
          'red': stars,
          'triangles': triangles,
          'goal': goal,
          'circles': circles
        },
        titleDe: 'Chancen einstellen',
        titleEn: 'Set the chances',
        promptDe:
            'Im Beutel liegen $stars Sterne und $trianglesDe. Lege so viele Kreise dazu, dass beim blinden Ziehen $goalDe. Alle Steine sind gleich groß.',
        promptEn:
            'The bag holds $stars stars and $trianglesEn. Add circles so that, drawing without looking, $goalEn. All tokens have the same size.',
        solutionDe:
            '$reasonDe Auch dann können mehrere gleiche Sorten hintereinander kommen.',
        solutionEn:
            '$reasonEn Repeated draws of the same type can still happen.',
        hintsDe: [
          'Vergleiche die Anzahlen, nicht eine einzelne Probeziehung.',
          'Jeder Stein hat die gleiche Chance. Welche Steine gehören zu jeder Seite des Vergleichs?',
          'Stelle $circles Kreise ein.'
        ],
        hintsEn: [
          'Compare the counts, not one trial draw.',
          'Every token has the same chance. Which tokens belong to each side of the comparison?',
          'Set the circle count to $circles.'
        ]);
  }
  final triangles = random.nextBool() ? 0 : 1 + random.nextInt(3);
  final present = {'star', 'circle', if (triangles > 0) 'triangle'};
  const events = [
    ('einen Stern', 'a star', {'star'}),
    (
      'einen Kreis oder ein Dreieck',
      'a circle or a triangle',
      {'circle', 'triangle'}
    ),
    ('einen Stern oder einen Kreis', 'a star or a circle', {'star', 'circle'}),
    ('ein Dreieck', 'a triangle', {'triangle'}),
    ('ein Quadrat', 'a square', <String>{}),
    ('keinen Kreis', 'anything but a circle', {'star', 'triangle'}),
    (
      'einen Stern, einen Kreis oder ein Dreieck',
      'a star, a circle or a triangle',
      {'star', 'circle', 'triangle'}
    ),
  ];
  final (eventDe, eventEn, matching) = events[random.nextInt(events.length)];
  final answer = present.every(matching.contains)
      ? 'certain'
      : present.any(matching.contains)
          ? 'possible'
          : 'impossible';
  final nameDe = {
    'certain': 'sicher',
    'possible': 'möglich, aber nicht sicher',
    'impossible': 'unmöglich'
  }[answer]!;
  final nameEn = {
    'certain': 'certain',
    'possible': 'possible, but not certain',
    'impossible': 'impossible'
  }[answer]!;
  return KompassLabRound(
      type: 'event',
      skillIds: const ['M-D04'],
      config: {
        'red': 3 + random.nextInt(3),
        'blue': 2 + random.nextInt(3),
        'triangles': triangles,
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
    final shape = labSymmetryShapes[random.nextInt(labSymmetryShapes.length)];
    final axes = shape.axes;
    String names(bool german) {
      final labels = [
        for (final axis in axes)
          switch (axis) {
            'vertical' => german ? 'senkrecht' : 'vertical',
            'horizontal' => german ? 'waagerecht' : 'horizontal',
            'diagonalDown' => german
                ? 'diagonal von links oben nach rechts unten'
                : 'diagonal from top left to bottom right',
            _ => german
                ? 'diagonal von links unten nach rechts oben'
                : 'diagonal from bottom left to top right',
          }
      ];
      return labels.join(german ? '; ' : '; ');
    }

    final countDe = switch (axes.length) {
      0 => 'keine Spiegelachse',
      1 => 'genau eine Spiegelachse',
      _ => '${axes.length} Spiegelachsen'
    };
    final countEn = switch (axes.length) {
      0 => 'no line of symmetry',
      1 => 'exactly one line of symmetry',
      _ => '${axes.length} lines of symmetry'
    };
    return KompassLabRound(
        type: 'axes',
        skillIds: const ['M-R05'],
        config: {'points': shape.points, 'axes': axes, 'shape': shape.id},
        titleDe: 'Alle Spiegelachsen',
        titleEn: 'Every line of symmetry',
        promptDe:
            'Wähle alle Spiegelachsen dieser Figur. Eine ausgewählte Linie wird in der Figur eingezeichnet. Es kann auch sein, dass keine Linie passt.',
        promptEn:
            'Select every line of symmetry. Each selected line appears on the shape. It is possible that no line works.',
        solutionDe:
            'Die Figur (${shape.nameDe}) hat $countDe${axes.isEmpty ? '' : ': ${names(true)}'}.',
        solutionEn:
            'The shape (${shape.nameEn}) has $countEn${axes.isEmpty ? '' : ': ${names(false)}'}.',
        hintsDe: [
          'Beide Hälften müssen beim Falten deckungsgleich sein.',
          'Prüfe jede der vier Linien einzeln: Landet jede Ecke beim Falten wieder auf einer Ecke?',
          axes.isEmpty
              ? 'Hier passt keine der Linien.'
              : 'Hier passen: ${names(true)}.'
        ],
        hintsEn: [
          'Both halves must match when folded.',
          'Check each of the four lines separately: does every corner land on a corner when folded?',
          axes.isEmpty
              ? 'No line works here.'
              : 'These work here: ${names(false)}.'
        ]);
  }
  if (variant == 1) {
    final net = _randomCubeNet(random);
    final removable = [
      for (final cell in net)
        if (_connected(net.where((c) => c != cell).toSet())) cell
    ];
    final removed = removable[random.nextInt(removable.length)];
    final fixed = net.where((c) => c != removed).toList();
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
          'Stelle dir eine Fläche als Boden vor und klappe ihre Nachbarn hoch. Welche Seite des Würfels fehlt noch?',
          'Eine Möglichkeit ist Zeile ${pair.$1 + 1}, Spalte ${pair.$2 + 1}.'
        ],
        hintsEn: [
          'The new square must share an edge with a given square.',
          'Imagine one face as the base and fold its neighbours up. Which side of the cube is still missing?',
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

class LabSymmetryShape {
  final String id, nameDe, nameEn;
  final List<List<int>> points;
  final List<String> axes;
  const LabSymmetryShape(
      this.id, this.nameDe, this.nameEn, this.points, this.axes);
}

/// Axes are drawn through the bounding box, so every listed axis is either
/// its vertical/horizontal centre line or one of its corner diagonals. The
/// lab test reflects each vertex set to verify this list.
const labSymmetryShapes = <LabSymmetryShape>[
  LabSymmetryShape('square', 'Quadrat', 'square', [
    [0, 0], [4, 0], [4, 4], [0, 4] //
  ], [
    'vertical', 'horizontal', 'diagonalDown', 'diagonalUp' //
  ]),
  LabSymmetryShape('rectangle', 'Rechteck', 'rectangle', [
    [0, 0], [6, 0], [6, 3], [0, 3] //
  ], [
    'vertical', 'horizontal' //
  ]),
  LabSymmetryShape('rhombus', 'Raute', 'rhombus', [
    [3, 0], [6, 2], [3, 4], [0, 2] //
  ], [
    'vertical', 'horizontal' //
  ]),
  LabSymmetryShape('tiltedRhombus', 'Raute', 'rhombus', [
    [0, 0], [3, 1], [4, 4], [1, 3] //
  ], [
    'diagonalDown', 'diagonalUp' //
  ]),
  LabSymmetryShape(
      'triangle', 'gleichschenkliges Dreieck', 'isosceles triangle', [
    [2, 0], [4, 4], [0, 4] //
  ], [
    'vertical' //
  ]),
  LabSymmetryShape('trapezoid', 'Trapez', 'trapezoid', [
    [1, 0], [5, 0], [6, 3], [0, 3] //
  ], [
    'vertical' //
  ]),
  LabSymmetryShape('arrow', 'Pfeilspitze', 'arrowhead', [
    [0, 0], [5, 2], [0, 4], [2, 2] //
  ], [
    'horizontal' //
  ]),
  LabSymmetryShape('kite', 'Drachenviereck', 'kite', [
    [0, 0], [4, 1], [4, 4], [1, 4] //
  ], [
    'diagonalDown' //
  ]),
  LabSymmetryShape('parallelogram', 'Parallelogramm', 'parallelogram', [
    [2, 0], [6, 0], [4, 3], [0, 3] //
  ], <String>[]),
];

const labNetRows = 5, labNetCols = 4;

bool _connected(Set<String> cells) {
  if (cells.isEmpty) return false;
  final seen = <String>{cells.first};
  final queue = [cells.first];
  for (var i = 0; i < queue.length; i++) {
    final (r, c) = parseCell(queue[i])!;
    for (final next in [
      '${r + 1},$c',
      '${r - 1},$c',
      '$r,${c + 1}',
      '$r,${c - 1}'
    ]) {
      if (cells.contains(next) && seen.add(next)) queue.add(next);
    }
  }
  return seen.length == cells.length;
}

/// Grows random edge-connected hexominoes inside the lab grid until one
/// folds into a cube, so every one of the eleven nets can occur.
List<String> _randomCubeNet(math.Random random) {
  for (var attempt = 0; attempt < 400; attempt++) {
    final cells = <String>{
      '${random.nextInt(labNetRows)},${random.nextInt(labNetCols)}'
    };
    while (cells.length < 6) {
      final frontier = <String>{
        for (final cell in cells)
          for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
            if (parseCell(cell) case (final r, final c)
                when r + dr >= 0 &&
                    r + dr < labNetRows &&
                    c + dc >= 0 &&
                    c + dc < labNetCols)
              '${r + dr},${c + dc}'
      }.difference(cells).toList();
      cells.add(frontier[random.nextInt(frontier.length)]);
    }
    if (isCubeNet(cells)) return cells.toList();
  }
  return const ['0,1', '1,0', '1,1', '1,2', '2,1', '3,1'];
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
