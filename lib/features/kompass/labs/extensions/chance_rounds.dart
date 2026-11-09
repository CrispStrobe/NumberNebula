import 'dart:math' as math;

import '../kompass_lab_round.dart';

/// Construct evidence, rather than treating a small random sample as a proof.
KompassLabRound generateChanceDetectiveRound(int index, int seed) {
  final random = math.Random(seed + index * 7919 + 310127);
  final claim = ['same', 'atLeastStar', 'oneEach'][index % 3];
  final replacement = random.nextBool();
  final stars = 1 + random.nextInt(3);
  var circles = 1 + random.nextInt(3);
  if (claim == 'atLeastStar') circles = 2 + random.nextInt(2);
  if (claim == 'oneEach' && stars == 1 && circles == 1) circles = 2;
  final claimDe = switch (claim) {
    'same' => 'Bei zwei Ziehungen sind die beiden Zeichen sicher gleich.',
    'atLeastStar' =>
      'Bei zwei Ziehungen ist sicher mindestens ein Stern dabei.',
    _ =>
      'Bei zwei Ziehungen erhält man sicher genau einen Stern und einen Kreis.',
  };
  final claimEn = switch (claim) {
    'same' => 'Two draws are certain to show the same symbol twice.',
    'atLeastStar' => 'Two draws are certain to include at least one star.',
    _ => 'Two draws are certain to give exactly one star and one circle.',
  };
  final witness = claim == 'same'
      ? ['star', 'circle']
      : claim == 'atLeastStar' || (!replacement && stars < 2)
          ? ['circle', 'circle']
          : ['star', 'star'];
  String symbol(String value, bool german) => value == 'star'
      ? (german ? 'Stern' : 'star')
      : (german ? 'Kreis' : 'circle');
  return KompassLabRound(
    type: 'chance_counterexample',
    skillIds: const ['M-D04'],
    config: {
      'stars': stars,
      'circles': circles,
      'replacement': replacement,
      'claim': claim,
      'claimDe': claimDe,
      'claimEn': claimEn,
    },
    titleDe: 'Eine Behauptung widerlegen',
    titleEn: 'Disprove a claim',
    promptDe:
        'Im Beutel liegen $stars gleich große Sternsteine und $circles gleich große Kreissteine. '
        'Es wird gut gemischt und zweimal blind gezogen. '
        '${replacement ? 'Nach der ersten Ziehung wird der Stein zurückgelegt und neu gemischt.' : 'Der erste Stein wird nicht zurückgelegt.'} '
        'Wähle zwei mögliche Ziehungen, bei denen diese Behauptung falsch ist: „$claimDe“',
    promptEn:
        'A bag contains $stars equal-sized star tokens and $circles equal-sized circle tokens. '
        'Mix well and draw blindly twice. '
        '${replacement ? 'Replace the first token and mix again before the second draw.' : 'Do not replace the first token.'} '
        'Choose two possible draws that make this claim false: “$claimEn”',
    solutionDe:
        'Zum Beispiel ${symbol(witness[0], true)} und dann ${symbol(witness[1], true)}. '
        'Diese Ziehungen sind erlaubt und widersprechen der Behauptung. Ein einziges mögliches Gegenbeispiel reicht: „sicher“ bedeutet, dass es keine Ausnahme gibt.',
    solutionEn:
        'For example, ${symbol(witness[0], false)} and then ${symbol(witness[1], false)}. '
        'These draws are allowed and contradict the claim. One possible counterexample is enough: “certain” allows no exception.',
    hintsDe: [
      '„Sicher“ bedeutet: Die Behauptung gilt bei jeder erlaubten Ziehung. Gesucht ist eine Ausnahme, nicht das wahrscheinlichste Ergebnis.',
      replacement
          ? 'Mit Zurücklegen ist der Beutel vor beiden Ziehungen gleich gefüllt. Dasselbe Zeichen darf zweimal erscheinen.'
          : 'Ohne Zurücklegen kann ein Zeichen nur so oft erscheinen, wie passende Steine vorhanden sind.',
      claim == 'same'
          ? 'Welche zwei unterschiedlichen Zeichen sind nacheinander möglich?'
          : claim == 'atLeastStar'
              ? 'Kannst du zweimal einen Kreis ziehen, sodass kein Stern dabei ist?'
              : 'Kannst du zweimal dasselbe Zeichen ziehen? Prüfe auch, ob genügend Steine dafür da sind.',
    ],
    hintsEn: [
      '“Certain” means the claim holds for every allowed draw. Look for an exception, not the most likely result.',
      replacement
          ? 'With replacement, the bag has the same contents before each draw. The same symbol may appear twice.'
          : 'Without replacement, a symbol can appear only as often as there are matching tokens.',
      claim == 'same'
          ? 'Which two different symbols could appear in order?'
          : claim == 'atLeastStar'
              ? 'Could you draw two circles, with no star at all?'
              : 'Could you draw the same symbol twice? Check whether enough tokens are available.',
    ],
  );
}

Map<String, dynamic> createChanceDetectiveResponse(KompassLabRound round) => {
      'first': '',
      'second': '',
      'reason': '',
    };

Map<String, dynamic> normalizeChanceDetectiveResponse(
  KompassLabRound round,
  Map<String, dynamic> saved,
) =>
    {
      'first': const ['star', 'circle'].contains(saved['first'])
          ? saved['first']
          : '',
      'second': const ['star', 'circle'].contains(saved['second'])
          ? saved['second']
          : '',
      'reason':
          const ['exception', 'frequent', 'oneTrial'].contains(saved['reason'])
              ? saved['reason']
              : '',
    };

KompassLabCheck checkChanceDetectiveRound(
  KompassLabRound round,
  Map<String, dynamic> response,
) {
  final first = response['first'];
  final second = response['second'];
  final symbols = [first, second];
  final selected = symbols.every(const ['star', 'circle'].contains);
  final legal = selected &&
      (round.config['replacement'] == true ||
          (symbols.where((s) => s == 'star').length <=
                  (round.config['stars'] as int) &&
              symbols.where((s) => s == 'circle').length <=
                  (round.config['circles'] as int)));
  final claimHolds = switch (round.config['claim']) {
    'same' => first == second,
    'atLeastStar' => symbols.contains('star'),
    _ => first != second,
  };
  final witness = legal && !claimHolds;
  final reason = response['reason'] == 'exception';
  final points = (legal ? 1 : 0) + (witness ? 1 : 0) + (reason ? 1 : 0);
  return KompassLabCheck(
    points: points,
    maxPoints: 3,
    feedbackDe: points == 3
        ? round.solutionDe
        : !legal
            ? 'Prüfe die Beutelregel: Beide Zeichen müssen vorhanden sein. Ohne Zurücklegen darfst du einen einzelnen Stein nicht zweimal verwenden.'
            : !witness
                ? 'Deine Ziehungen sind möglich, aber die Behauptung gilt dabei noch. Suche eine erlaubte Ausnahme.'
                : 'Dein Gegenbeispiel passt. Warum genügt schon eine mögliche Ausnahme, um „sicher“ zu widerlegen?',
    feedbackEn: points == 3
        ? round.solutionEn
        : !legal
            ? 'Check the bag rule: both symbols must be available. Without replacement, one token cannot be used twice.'
            : !witness
                ? 'Your draws are possible, but the claim still holds for them. Find an allowed exception.'
                : 'Your counterexample works. Why is one possible exception enough to disprove “certain”?',
  );
}
