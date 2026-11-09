import 'dart:math' as math;

import '../kompass_lab_round.dart';

/// New, seeded practice recipes. The original four labs keep their old cycles.
KompassLabRound generateReasoningRound(int index, int seed) {
  final random = math.Random(seed + index * 7919 + 110003);
  return switch (index % 4) {
    0 => _inverseWall(random),
    1 => _maxWall(random),
    2 => _machine(random),
    _ => _codes(random),
  };
}

Map<String, dynamic> createReasoningResponse(KompassLabRound round) =>
    switch (round.type) {
      'reasoning_inverse_wall' => {'middle': '', 'base': '', 'inverse': ''},
      'reasoning_max_wall' => {
          'order': <String>[],
          'top': '',
          'reason': '',
        },
      'reasoning_machine' => {'next': '', 'after': '', 'rule': ''},
      'reasoning_codes' => {
          'draftFirst': '',
          'draftSecond': '',
          'codes': <String>[],
          'count': '',
          'reason': '',
        },
      _ => throw ArgumentError.value(round.type, 'round.type'),
    };

Map<String, dynamic> normalizeReasoningResponse(
  KompassLabRound round,
  Map<String, dynamic> saved,
) {
  final result = createReasoningResponse(round);
  for (final key in result.keys.toList()) {
    final value = saved[key];
    if (result[key] is List) {
      // Keep duplicate and disallowed strings visible for correction. Silently
      // deduplicating a draft could turn an invalid submission into a success.
      result[key] = value is List
          ? value
              .map((item) => item is String ? item : '')
              .take(key == 'order' ? 6 : 20)
              .toList()
          : <String>[];
    } else {
      result[key] = value is String || (value is num && value.isFinite)
          ? value.toString()
          : '';
    }
  }
  return result;
}

KompassLabCheck checkReasoningRound(
  KompassLabRound round,
  Map<String, dynamic> response,
) {
  final config = round.config;
  var points = 0;
  var maximum = 3;
  var de = 'Prüfe deinen Lösungsweg Schritt für Schritt.';
  var en = 'Check your method one step at a time.';
  switch (round.type) {
    case 'reasoning_inverse_wall':
      final middle = _integer(response['middle']);
      final base = _integer(response['base']);
      final middleCorrect = middle == config['rightMiddle'];
      final baseCorrect = base == config['rightBase'];
      final carried = !middleCorrect &&
          middle != null &&
          base != null &&
          base >= 0 &&
          base == middle - (config['middleBase'] as int);
      final inverseCorrect = response['inverse'] == 'subtract';
      points = (middleCorrect ? 1 : 0) +
          (baseCorrect || carried ? 1 : 0) +
          (inverseCorrect ? 1 : 0);
      if (!middleCorrect) {
        de = carried
            ? 'Dein zweiter Schritt passt zu deinem Zwischenergebnis und bekommt einen Teilpunkt. Prüfe zuerst den rechten Stein in der mittleren Reihe: oberster Stein minus linker mittlerer Stein.'
            : 'Berechne zuerst den rechten Stein in der mittleren Reihe: oberster Stein minus linker mittlerer Stein.';
        en = carried
            ? 'Your second step follows your intermediate result and earns partial credit. First check the right middle brick: top brick minus left middle brick.'
            : 'First calculate the right middle brick: top brick minus left middle brick.';
      } else if (!baseCorrect) {
        de = 'Der mittlere Stein stimmt. Ziehe davon die bekannte untere Zahl ab, um die fehlende untere Zahl zu finden.';
        en = 'The middle brick is correct. Subtract the known base number from it to find the missing base number.';
      } else {
        de = 'Beide Zahlen stimmen. Welche Rechenart macht eine Addition rückgängig?';
        en = 'Both numbers are correct. Which operation reverses addition?';
      }
    case 'reasoning_max_wall':
      final cards = (config['cards'] as List).cast<int>();
      final order = _strings(response['order']);
      final validOrder = order.length == 3 &&
          order.toSet().length == 3 &&
          order.every(const ['c0', 'c1', 'c2'].contains);
      final largest = cards.reduce(math.max);
      final optimal = validOrder && cards[int.parse(order[1][1])] == largest;
      final topCorrect = _integer(response['top']) == config['maximumTop'];
      final reasonCorrect = response['reason'] == 'twice';
      points = (optimal ? 1 : 0) +
          (topCorrect ? 1 : 0) +
          (reasonCorrect ? 1 : 0);
      if (!validOrder) {
        de = 'Benutze jede Zahlenkarte genau einmal und belege alle drei unteren Plätze.';
        en = 'Use each number card exactly once and fill all three base positions.';
      } else if (!optimal) {
        de = 'Vergleiche die Anordnungen. Die mittlere untere Zahl geht in beide Steine darüber ein.';
        en = 'Compare the arrangements. The middle base number contributes to both bricks above it.';
      } else if (!topCorrect) {
        de = 'Die größte Zahl liegt richtig in der Mitte. Berechne beide mittleren Steine und addiere sie für die Spitze.';
        en = 'The largest number is correctly placed in the middle. Calculate both middle bricks and add them to find the top.';
      } else {
        de = 'Anordnung und Spitze stimmen. Erkläre jetzt, warum die mittlere Zahl so wichtig ist.';
        en = 'The arrangement and top are correct. Now explain why the middle number matters.';
      }
    case 'reasoning_machine':
      final next = _integer(response['next']);
      final after = _integer(response['after']);
      final nextCorrect = next == config['next'];
      final afterCorrect = after == config['after'];
      final carried = !nextCorrect &&
          next != null &&
          next >= 0 &&
          after == next * (config['factor'] as int);
      final ruleCorrect = response['rule'] == 'add_then_multiply';
      points = (nextCorrect ? 1 : 0) +
          (afterCorrect || carried ? 1 : 0) +
          (ruleCorrect ? 1 : 0);
      de = carried
          ? 'Du hast dein Zwischenergebnis richtig weiter multipliziert; dafür gibt es einen Teilpunkt. Prüfe die erste neue Zahl: Nach dem Multiplizieren kommt wieder das Addieren.'
          : !nextCorrect
              ? 'Nach dem letzten Multiplizieren kommt wieder das Addieren. Die beiden Rechenschritte wechseln sich ab.'
              : !afterCorrect
                  ? 'Die erste neue Zahl stimmt. Wende auf diese Zahl als Nächstes den Multiplikationsschritt an.'
                  : 'Die Zahlen stimmen. Wähle auch die richtige Reihenfolge der nächsten beiden Rechenschritte.';
      en = carried
          ? 'You correctly multiplied your intermediate result, earning partial credit. Check the first new number: addition follows multiplication.'
          : !nextCorrect
              ? 'Addition follows the last multiplication. The two operations alternate.'
              : !afterCorrect
                  ? 'The first new number is correct. Apply the multiplication step to that number next.'
                  : 'The numbers are correct. Also choose the correct order of the next two operations.';
    case 'reasoning_codes':
      maximum = 4;
      final symbols = (config['symbols'] as List).cast<String>();
      final repeat = config['repetition'] == true;
      final expected = _allowedCodes(symbols, repeat);
      final codes = _strings(response['codes']);
      final distinct = codes.toSet();
      final validList = codes.isNotEmpty &&
          distinct.length == codes.length &&
          codes.every(expected.contains);
      final complete = validList &&
          distinct.length == expected.length &&
          distinct.containsAll(expected);
      final countCorrect = _integer(response['count']) == expected.length;
      final reasonCorrect = response['reason'] == 'systematic';
      points = (validList ? 1 : 0) +
          (complete ? 1 : 0) +
          (countCorrect ? 1 : 0) +
          (reasonCorrect ? 1 : 0);
      if (codes.isEmpty) {
        de = 'Baue die Codes mit den beiden Stellen und füge sie deiner Liste hinzu. Eine Anzahl allein zeigt noch nicht alle Möglichkeiten.';
        en = 'Build codes using the two positions and add them to your list. A count alone does not show every possibility.';
      } else if (distinct.length != codes.length) {
        de = 'In deiner Liste steht ein Code mehrfach. Entferne Doppelungen, damit jede Möglichkeit genau einmal vorkommt.';
        en = 'Your list repeats a code. Remove duplicates so each possibility appears exactly once.';
      } else if (!validList) {
        de = repeat
            ? 'Ein Code hat genau zwei Stellen. Verwende an jeder Stelle nur die angebotenen Zeichen.'
            : 'Ein Code hat genau zwei Stellen mit verschiedenen angebotenen Zeichen. Wiederholung innerhalb eines Codes ist hier nicht erlaubt.';
        en = repeat
            ? 'A code has exactly two positions. Use only the offered symbols in each position.'
            : 'A code has exactly two different offered symbols. Repeating a symbol within a code is not allowed here.';
      } else if (!complete) {
        de = 'Deine bisherigen Codes sind erlaubt. Halte das erste Zeichen fest und ergänze alle erlaubten zweiten Zeichen; dann wechsle das erste.';
        en = 'Your current codes are allowed. Keep the first symbol fixed and add every allowed second symbol, then change the first.';
      } else if (!countCorrect) {
        de = 'Die Liste ist vollständig. Zähle ihre verschiedenen Einträge noch einmal.';
        en = 'The list is complete. Count its distinct entries again.';
      } else {
        de = 'Liste und Anzahl stimmen. Wähle die Begründung, die zeigt, dass kein Code fehlt.';
        en = 'The list and count are correct. Choose the explanation showing that no code is missing.';
      }
    default:
      throw ArgumentError.value(round.type, 'round.type');
  }
  return KompassLabCheck(
    points: points,
    maxPoints: maximum,
    feedbackDe: points == maximum ? round.solutionDe : de,
    feedbackEn: points == maximum ? round.solutionEn : en,
  );
}

int? _integer(Object? value) {
  final parsed = parseLabNumber(value);
  return parsed != null && parsed == parsed.truncateToDouble()
      ? parsed.toInt()
      : null;
}

List<String> _strings(Object? value) =>
    value is List
        ? value.map((item) => item is String ? item : '').toList()
        : const [];

List<String> _allowedCodes(List<String> symbols, bool repetition) => [
      for (final first in symbols)
        for (final second in symbols)
          if (repetition || first != second) '$first$second',
    ];

KompassLabRound _inverseWall(math.Random random) {
  final left = 120 + random.nextInt(8) * 20;
  final middle = 140 + random.nextInt(9) * 10;
  final right = 80 + random.nextInt(9) * 20;
  final leftMiddle = left + middle;
  final rightMiddle = middle + right;
  final top = leftMiddle + rightMiddle;
  return KompassLabRound(
    type: 'reasoning_inverse_wall',
    skillIds: const ['M-Z04'],
    config: {
      'leftBase': left,
      'middleBase': middle,
      'rightBase': right,
      'leftMiddle': leftMiddle,
      'rightMiddle': rightMiddle,
      'top': top,
    },
    titleDe: 'Rückwärts durch die Zahlenmauer',
    titleEn: 'Work backwards through the wall',
    promptDe: 'Jeder obere Stein ist die Summe der beiden Steine direkt darunter. Finde zuerst die rechte Lücke in der mittleren Reihe und dann die rechte Lücke unten. Verwende dein Zwischenergebnis für den zweiten Schritt.',
    promptEn: 'Each upper brick is the sum of the two directly below it. Find the right middle blank first, then the right base blank. Use your intermediate result for the second step.',
    solutionDe: '$top − $leftMiddle = $rightMiddle; danach $rightMiddle − $middle = $right. Subtrahieren macht das Addieren rückgängig. Kontrolle: $middle + $right = $rightMiddle.',
    solutionEn: '$top − $leftMiddle = $rightMiddle; then $rightMiddle − $middle = $right. Subtraction reverses addition. Check: $middle + $right = $rightMiddle.',
    hintsDe: [
      'Der oberste Stein setzt sich aus den beiden mittleren Steinen zusammen.',
      'Ziehe zuerst $leftMiddle von $top ab. Ziehe danach $middle von deinem Ergebnis ab.',
      'Die beiden fehlenden Steine sind $rightMiddle und $right. Prüfe sie durch Addieren.',
    ],
    hintsEn: [
      'The top brick is made from the two middle bricks.',
      'First subtract $leftMiddle from $top. Then subtract $middle from your result.',
      'The missing bricks are $rightMiddle and $right. Check them by adding.',
    ],
  );
}

KompassLabRound _maxWall(math.Random random) {
  final cards = [
    10 + random.nextInt(5) * 5,
    40 + random.nextInt(5) * 5,
    80 + random.nextInt(5) * 5,
  ]..shuffle(random);
  final largest = cards.reduce(math.max);
  final total = cards.reduce((a, b) => a + b) + largest;
  return KompassLabRound(
    type: 'reasoning_max_wall',
    skillIds: const ['M-Z09'],
    config: {'cards': cards, 'maximumTop': total},
    titleDe: 'Die größte Mauerspitze',
    titleEn: 'Make the largest wall top',
    promptDe: 'Lege jede Zahlenkarte genau einmal in die untere Reihe. Jeder obere Stein ist die Summe der beiden Steine darunter. Ordne die Karten so, dass die Spitze möglichst groß wird, und begründe deine Anordnung.',
    promptEn: 'Use every number card once in the base row. Each upper brick is the sum of the two below. Arrange the cards to make the top as large as possible and explain your arrangement.',
    solutionDe: 'Die $largest gehört in die Mitte. Sie geht in beide mittleren Steine ein und zählt oben zweimal; die äußeren Zahlen zählen je einmal. Die größte Spitze ist $total. Die beiden äußeren Karten dürfen vertauscht sein.',
    solutionEn: 'Put $largest in the middle. It contributes to both middle bricks and counts twice at the top; each outer number counts once. The largest top is $total. Either order of the outer cards works.',
    hintsDe: [
      'Probiere jede der drei Karten einmal in der Mitte.',
      'Verfolge die mittlere untere Zahl: Sie wird in beiden Steinen darüber verwendet.',
      'Lege $largest in die Mitte. Addiere alle drei Karten und noch einmal $largest.',
    ],
    hintsEn: [
      'Try each of the three cards in the middle.',
      'Trace the middle base number: it is used in both bricks above.',
      'Put $largest in the middle. Add all three cards and another $largest.',
    ],
  );
}

KompassLabRound _machine(math.Random random) {
  final start = 3 + random.nextInt(6);
  final add = 3 + random.nextInt(7);
  final factor = 2 + random.nextInt(2);
  final shown = [start];
  for (var step = 0; step < 4; step++) {
    shown.add(step.isEven ? shown.last + add : shown.last * factor);
  }
  final next = shown.last + add;
  final after = next * factor;
  return KompassLabRound(
    type: 'reasoning_machine',
    skillIds: const ['M-Z08'],
    config: {
      'start': start,
      'add': add,
      'factor': factor,
      'shown': shown,
      'next': next,
      'after': after,
    },
    titleDe: 'Die Rechenmaschine im Wechsel',
    titleEn: 'The alternating calculation machine',
    promptDe: 'Die Maschine verwendet abwechselnd +$add und ×$factor, beginnend mit +$add. Setze die angefangene Folge um zwei Zahlen fort. Welche beiden Rechenschritte kommen jetzt?',
    promptEn: 'The machine alternates +$add and ×$factor, starting with +$add. Continue the displayed sequence by two numbers. Which two operations come next?',
    solutionDe: '${shown.last} + $add = $next; danach $next × $factor = $after. Nach dem Multiplizieren kommt wieder das Addieren.',
    solutionEn: '${shown.last} + $add = $next; then $next × $factor = $after. Addition follows multiplication again.',
    hintsDe: [
      'Die beiden Regeln wechseln sich ab; derselbe Schritt kommt nicht zweimal hintereinander.',
      'Der letzte sichtbare Schritt war ×$factor. Als Nächstes kommt +$add, dann wieder ×$factor.',
      'Die nächsten beiden Zahlen sind $next und $after.',
    ],
    hintsEn: [
      'The two rules alternate; the same step does not occur twice in a row.',
      'The last visible step was ×$factor. Next comes +$add, followed by ×$factor.',
      'The next two numbers are $next and $after.',
    ],
  );
}

KompassLabRound _codes(math.Random random) {
  final available = ['A', 'B', 'C', 'D', 'E']..shuffle(random);
  final symbols = available.take(2 + random.nextInt(2)).toList()..sort();
  final repeat = random.nextBool();
  final codes = _allowedCodes(symbols, repeat);
  final secondChoices = symbols.length - (repeat ? 0 : 1);
  return KompassLabRound(
    type: 'reasoning_codes',
    skillIds: const ['M-Z12'],
    config: {'symbols': symbols, 'repetition': repeat},
    titleDe: 'Kein Code darf fehlen',
    titleEn: 'Find every code',
    promptDe: 'Ein Code hat genau zwei Stellen. Verwende ${symbols.join(', ')}. ${repeat ? 'Ein Zeichen darf in einem Code zweimal vorkommen.' : 'Ein Zeichen darf in einem Code nur einmal vorkommen.'} Die Reihenfolge zählt: ${symbols[0]}${symbols[1]} und ${symbols[1]}${symbols[0]} sind verschiedene Codes. Baue alle erlaubten Codes und erkläre, warum deine Liste vollständig ist.',
    promptEn: 'A code has exactly two positions. Use ${symbols.join(', ')}. ${repeat ? 'A symbol may appear twice within one code.' : 'A symbol may appear only once within one code.'} Order matters: ${symbols[0]}${symbols[1]} and ${symbols[1]}${symbols[0]} are different codes. Build every allowed code and explain why your list is complete.',
    solutionDe: '${codes.join(', ')}. Für jedes der ${symbols.length} ersten Zeichen gibt es $secondChoices erlaubte zweite Zeichen: ${symbols.length} × $secondChoices = ${codes.length} Codes. Geordnetes Auflisten vermeidet Lücken und Doppelungen.',
    solutionEn: '${codes.join(', ')}. Each of the ${symbols.length} first symbols has $secondChoices allowed second symbols: ${symbols.length} × $secondChoices = ${codes.length} codes. A systematic list avoids omissions and duplicates.',
    hintsDe: [
      'Halte das erste Zeichen fest und probiere alle erlaubten zweiten Zeichen.',
      'Wechsle erst danach das erste Zeichen. Beachte, ob Wiederholung erlaubt ist.',
      'Es gibt ${symbols.length} Gruppen mit je $secondChoices Codes, also ${codes.length} verschiedene Codes.',
    ],
    hintsEn: [
      'Keep the first symbol fixed and try every allowed second symbol.',
      'Only then change the first symbol. Check whether repetition is allowed.',
      'There are ${symbols.length} groups of $secondChoices codes: ${codes.length} distinct codes altogether.',
    ],
  );
}
