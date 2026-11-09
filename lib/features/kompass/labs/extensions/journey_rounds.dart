import 'dart:math' as math;

import '../kompass_lab_round.dart';

/// Times are integer minutes after midnight on one explicitly stated day.
String journeyTime(int minutes) => labTime(minutes ~/ 60, minutes % 60);

int? parseJourneyTime(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{1,2})[:.](\d{2})(?:\s*Uhr)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  return hour < 24 && minute < 60 ? hour * 60 + minute : null;
}

KompassLabRound generateJourneyRound(int index, int seed) {
  final random = math.Random(seed + index * 7919 + 431);
  if (index.isEven) {
    final deadline = (10 + random.nextInt(7)) * 60 + random.nextInt(12) * 5;
    final ride = 24 + random.nextInt(28);
    final walk = 8 + random.nextInt(14);
    final reserve = 3 + random.nextInt(8);
    final stop = deadline - reserve - walk;
    final leave = stop - ride;
    return KompassLabRound(
      type: 'journey_backward',
      skillIds: const ['M-G05'],
      config: {
        'deadline': deadline,
        'rideMinutes': ride,
        'walkMinutes': walk,
        'reserveMinutes': reserve,
        'stopTime': stop,
        'leaveTime': leave,
      },
      titleDe: 'Vom Ziel rückwärts planen',
      titleEn: 'Plan backwards from the destination',
      promptDe: 'Der Werkstattkurs beginnt um ${journeyTime(deadline)} Uhr. '
          'Die Fahrt zum Zielhalt dauert $ride Minuten, der anschließende '
          'Fußweg $walk Minuten. Du möchtest mindestens $reserve Minuten '
          'vor Kursbeginn dort sein. Die Fahrt beginnt direkt beim Losfahren; '
          'weitere Wartezeiten gibt es nicht. Alle Zeiten gelten am selben Tag.',
      promptEn:
          'The workshop begins at ${journeyTime(deadline)}. The ride to the '
          'destination stop takes $ride minutes, followed by a $walk-minute '
          'walk. You want to arrive at least $reserve minutes before it starts. '
          'The ride starts when you set off; there are no other waits. '
          'All times are on the same day.',
      solutionDe:
          'Spätestens ${journeyTime(deadline - reserve)} Uhr an der Werkstatt, '
          '${journeyTime(stop)} Uhr am Zielhalt und ${journeyTime(leave)} Uhr '
          'losfahren. Die Probe vorwärts: $ride + $walk + $reserve = '
          '${ride + walk + reserve} Minuten bis zum Kursbeginn.',
      solutionEn:
          'Reach the workshop by ${journeyTime(deadline - reserve)}, the stop '
          'by ${journeyTime(stop)}, and set off at ${journeyTime(leave)}. '
          'Check forwards: $ride + $walk + $reserve = '
          '${ride + walk + reserve} minutes until the workshop starts.',
      hintsDe: [
        '„Spätestens“ bedeutet: Eine spätere Zeit würde nicht mehr reichen. '
            'Rechne vom Kursbeginn rückwärts.',
        'Ziehe zuerst die Reserve und dann den Fußweg ab. Danach folgt die Fahrt. '
            'Eine Stunde hat 60 Minuten.',
        'Am Zielhalt spätestens ${journeyTime(stop)} Uhr; '
            'losfahren spätestens ${journeyTime(leave)} Uhr.',
      ],
      hintsEn: [
        '“Latest” means a later time would be too late. Work backwards from '
            'the workshop start.',
        'Subtract the reserve, then the walk, then the ride. '
            'An hour contains 60 minutes.',
        'Reach the stop by ${journeyTime(stop)}; '
            'set off at ${journeyTime(leave)}.',
      ],
    );
  }

  final start = (8 + random.nextInt(8)) * 60 + 30 + random.nextInt(25);
  final ride = 17 + random.nextInt(24);
  final walk = 5 + random.nextInt(11);
  final reserve = 2 + random.nextInt(6);
  final platform = start + ride + walk;
  final ready = platform + reserve;
  final firstReachable = random.nextInt(3);
  final interval = 8 + random.nextInt(8);
  final slack = random.nextBool() ? 0 : 1 + random.nextInt(5);
  final first = ready + slack - firstReachable * interval;
  final services = [
    for (var i = 0; i < 3; i++)
      {'id': String.fromCharCode(65 + i), 'departure': first + i * interval},
  ];
  final best = services[firstReachable];
  return KompassLabRound(
    type: 'journey_connection',
    skillIds: const ['M-G05', 'M-D01'],
    config: {
      'startTime': start,
      'rideMinutes': ride,
      'walkMinutes': walk,
      'reserveMinutes': reserve,
      'platformTime': platform,
      'services': services,
      'bestService': best['id'],
    },
    titleDe: 'Welchen Anschluss erreichst du?',
    titleEn: 'Which connection can you catch?',
    promptDe:
        'Dein Zubringer fährt um ${journeyTime(start)} Uhr los und braucht '
        '$ride Minuten. Danach gehst du $walk Minuten zum Bahnsteig. '
        'Vor der Abfahrt des Anschlusses musst du mindestens $reserve Minuten '
        'am Bahnsteig sein. Die Tabelle zeigt alle Anschlüsse. '
        'Wähle den frühesten erreichbaren. Alle Zeiten gelten am selben Tag.',
    promptEn: 'Your feeder service leaves at ${journeyTime(start)} and takes '
        '$ride minutes. Then you walk $walk minutes to the platform. '
        'You must be there at least $reserve minutes before the connection '
        'departs. The table lists all connections. Choose the earliest one '
        'you can catch. All times are on the same day.',
    solutionDe: 'Du erreichst den Bahnsteig um ${journeyTime(platform)} Uhr. '
        'Mit $reserve Minuten Reserve darf der Anschluss frühestens um '
        '${journeyTime(ready)} Uhr abfahren. ${best['id']} um '
        '${journeyTime(best['departure'] as int)} Uhr ist der erste passende.',
    solutionEn: 'You reach the platform at ${journeyTime(platform)}. With the '
        '$reserve-minute reserve, a connection must leave at '
        '${journeyTime(ready)} or later. ${best['id']} at '
        '${journeyTime(best['departure'] as int)} is the first suitable one.',
    hintsDe: [
      'Rechne zuerst die Fahrt und danach den Fußweg zur Startzeit hinzu.',
      'Addiere zur Ankunft am Bahnsteig noch die Reserve. „Mindestens“ '
          'schließt eine genau passende Wartezeit ein.',
      'Ankunft am Bahnsteig: ${journeyTime(platform)} Uhr. '
          'Der früheste erreichbare Anschluss ist ${best['id']}.',
    ],
    hintsEn: [
      'Add the ride and then the walk to the starting time.',
      'Add the reserve to the platform arrival time. “At least” includes '
          'a wait exactly equal to the required reserve.',
      'Platform arrival: ${journeyTime(platform)}. '
          'The earliest reachable connection is ${best['id']}.',
    ],
  );
}

Map<String, dynamic> createJourneyResponse(KompassLabRound round) =>
    round.type == 'journey_backward'
        ? {'stopTime': '', 'leaveTime': ''}
        : {'platformTime': '', 'service': ''};

Map<String, dynamic> normalizeJourneyResponse(
  KompassLabRound round,
  Map<String, dynamic> saved,
) {
  final result = createJourneyResponse(round);
  for (final key in result.keys.toList()) {
    final value = saved[key];
    if (value is String && value.length <= 40) result[key] = value;
  }
  if (result.containsKey('service')) {
    final services = (round.config['services'] as List)
        .map((service) => (service as Map)['id']);
    if (!services.contains(result['service'])) result['service'] = '';
  }
  return result;
}

KompassLabCheck checkJourneyRound(
  KompassLabRound round,
  Map<String, dynamic> response,
) {
  final config = round.config;
  int points;
  String de, en;
  if (round.type == 'journey_backward') {
    final stopCorrect =
        parseJourneyTime(response['stopTime']) == config['stopTime'];
    final leaveCorrect =
        parseJourneyTime(response['leaveTime']) == config['leaveTime'];
    points = (stopCorrect ? 1 : 0) + (leaveCorrect ? 1 : 0);
    de = stopCorrect
        ? 'Die Ankunft am Zielhalt stimmt. Rechne von dort die Fahrt rückwärts, '
            'um die späteste Abfahrt zu finden.'
        : 'Berücksichtige vor dem Kursbeginn sowohl die Reserve als auch den '
            'Fußweg. Rechne Uhrzeiten in Stunden und Minuten, nicht als Dezimalzahlen.';
    en = stopCorrect
        ? 'The destination-stop time is correct. Subtract the ride from that '
            'time to find the latest departure.'
        : 'Allow both the reserve and the walk before the workshop starts. '
            'Use hours and minutes, not decimal hours.';
  } else {
    final platformCorrect =
        parseJourneyTime(response['platformTime']) == config['platformTime'];
    final serviceCorrect = response['service'] == config['bestService'];
    points = (platformCorrect ? 1 : 0) + (serviceCorrect ? 1 : 0);
    de = platformCorrect
        ? 'Die Bahnsteig-Ankunft stimmt. Prüfe zusätzlich die Reserve und '
            'wähle danach den frühesten zulässigen Anschluss.'
        : 'Zur Startzeit gehören die Fahrtdauer und der anschließende Fußweg. '
            'Die Reserve kommt erst beim Prüfen der Anschluss-Abfahrten dazu.';
    en = platformCorrect
        ? 'The platform arrival is correct. Allow the reserve as well, '
            'then choose the earliest eligible connection.'
        : 'Add both the ride and the following walk to the starting time. '
            'Use the reserve when checking the connection departures.';
  }
  return KompassLabCheck(
    points: points,
    maxPoints: 2,
    feedbackDe: points == 2 ? round.solutionDe : de,
    feedbackEn: points == 2 ? round.solutionEn : en,
  );
}
