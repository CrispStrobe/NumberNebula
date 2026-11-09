import 'dart:io';

import '../../lib/features/kompass/labs/extensions/reasoning_rounds.dart';

/// Bounded independent arithmetic audit; needs Dart only, no Flutter engine.
void main() {
  var assertions = 0;
  void verify(bool condition, String description) {
    assertions++;
    if (!condition) throw StateError(description);
  }

  const permutations = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
  ];
  final repetitionPolicies = <bool>{};
  for (var seed = 0; seed < 64; seed++) {
    final inverse = generateReasoningRound(0, seed);
    final givens = inverse.config;
    final middle = (givens['top'] as int) - (givens['leftMiddle'] as int);
    final base = middle - (givens['middleBase'] as int);
    verify(
      checkReasoningRound(inverse, {
        'middle': '$middle',
        'base': '$base',
        'inverse': 'subtract',
      }).correct,
      'Inverse wall failed at seed $seed',
    );
    final carried = checkReasoningRound(inverse, {
      'middle': '${middle + 10}',
      'base': '${base + 10}',
      'inverse': 'subtract',
    });
    verify(
      carried.points == 2 && !carried.correct,
      'Invalid carried credit at seed $seed',
    );

    final wall = generateReasoningRound(1, seed);
    final cards = (wall.config['cards'] as List).cast<int>();
    final tops = [
      for (final order in permutations)
        (cards[order[0]] + cards[order[1]]) +
            (cards[order[1]] + cards[order[2]]),
    ];
    final sorted = List<int>.of(tops)..sort();
    var accepted = 0;
    for (var i = 0; i < permutations.length; i++) {
      final correct = checkReasoningRound(wall, {
        'order': [for (final index in permutations[i]) 'c$index'],
        'top': '${sorted.last}',
        'reason': 'twice',
      }).correct;
      verify(
        correct == (tops[i] == sorted.last),
        'Wall optimum mismatch at seed $seed',
      );
      if (correct) accepted++;
    }
    verify(accepted == 2, 'Both outside-card orders must work at seed $seed');

    final machine = generateReasoningRound(2, seed);
    var running = machine.config['start'] as int;
    var next = 0;
    for (var step = 0; step < 6; step++) {
      if (step.isEven) {
        running += machine.config['add'] as int;
      } else {
        running *= machine.config['factor'] as int;
      }
      if (step == 4) next = running;
    }
    verify(
      checkReasoningRound(machine, {
        'next': '$next',
        'after': '$running',
        'rule': 'add_then_multiply',
      }).correct,
      'Alternating phase mismatch at seed $seed',
    );
    verify(
      !checkReasoningRound(machine, {
        'next': '$next',
        'after': '$running',
        'rule': 'multiply_then_add',
      }).correct,
      'Wrong phase accepted at seed $seed',
    );

    final codeRound = generateReasoningRound(3, seed);
    final symbols = (codeRound.config['symbols'] as List).cast<String>();
    final repeat = codeRound.config['repetition'] == true;
    repetitionPolicies.add(repeat);
    final codes = <String>[];
    for (var first = 0; first < symbols.length; first++) {
      for (var second = 0; second < symbols.length; second++) {
        if (repeat || first != second)
          codes.add('${symbols[first]}${symbols[second]}');
      }
    }
    final answer = {
      'codes': codes,
      'count': '${codes.length}',
      'reason': 'systematic',
    };
    verify(
      checkReasoningRound(codeRound, answer).correct,
      'Complete code set rejected at seed $seed',
    );
    verify(
      !checkReasoningRound(codeRound, {...answer, 'codes': <String>[]}).correct,
      'Count-only answer accepted at seed $seed',
    );
    verify(
      !checkReasoningRound(codeRound, {
        ...answer,
        'codes': [...codes, codes.first],
      }).correct,
      'Duplicate code accepted at seed $seed',
    );
    verify(
      !checkReasoningRound(codeRound, {
        ...answer,
        'codes': [...codes, 7],
      }).correct,
      'Non-string code accepted at seed $seed',
    );
  }
  verify(
    repetitionPolicies.length == 2,
    'Both code repetition policies must be sampled',
  );
  stdout.writeln(
    'Reasoning lab audit passed: $assertions checks across seeds 0–63.',
  );
}
