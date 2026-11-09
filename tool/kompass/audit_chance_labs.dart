import 'dart:io';

import '../../lib/features/kompass/labs/kompass_lab_round.dart';

void main() {
  var checks = 0;
  void verify(bool condition, String context) {
    checks++;
    if (!condition) throw StateError(context);
  }

  const pairs = [
    ['star', 'star'],
    ['star', 'circle'],
    ['circle', 'star'],
    ['circle', 'circle'],
  ];
  final replacements = <bool>{};
  for (var seed = 0; seed < 64; seed++) {
    for (var index = 0; index < 3; index++) {
      final round = generateKompassLabRound('chance_detective', index, seed);
      final replace = round.config['replacement'] as bool;
      replacements.add(replace);
      var witnesses = 0;
      for (final pair in pairs) {
        final bag = <String, int>{
          'star': round.config['stars'] as int,
          'circle': round.config['circles'] as int,
        };
        var legal = true;
        for (final token in pair) {
          if (bag[token]! <= 0) legal = false;
          if (!replace) bag[token] = bag[token]! - 1;
        }
        final starCount = pair.where((token) => token == 'star').length;
        final contradicts = switch (round.config['claim']) {
          'same' => starCount == 1,
          'atLeastStar' => starCount == 0,
          _ => starCount != 1,
        };
        final score = round.check({
          'first': pair[0],
          'second': pair[1],
          'reason': 'exception',
        });
        verify(score.correct == (legal && contradicts), '$seed/$index/$pair');
        verify(
          score.points == (legal ? 1 : 0) + (legal && contradicts ? 1 : 0) + 1,
          'partial credit $seed/$index/$pair',
        );
        if (legal && contradicts) {
          witnesses++;
          verify(
            !round.check({
              'first': pair[0],
              'second': pair[1],
              'reason': 'oneTrial',
            }).correct,
            'a trial is not a proof',
          );
        }
      }
      verify(witnesses > 0, 'generated claim must have a counterexample');
      final empty = round.createResponse();
      verify(!round.check(empty).correct, 'empty draft');
      verify(
        round.normalizeResponse(empty).toString() == empty.toString(),
        'restore',
      );
    }
  }
  verify(replacements.length == 2, 'both replacement policies');
  stdout.writeln('Chance lab audit passed: $checks checks across 64 seeds.');
}
