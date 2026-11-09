import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/reasoning_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';

const _seed = 417;
const _lab = 'reasoning_workshop';

List<String> _codes(KompassLabRound round) {
  final symbols = (round.config['symbols'] as List).cast<String>();
  final result = <String>[];
  for (var first = 0; first < symbols.length; first++) {
    for (var second = 0; second < symbols.length; second++) {
      if (round.config['repetition'] == true || first != second) {
        result.add('${symbols[first]}${symbols[second]}');
      }
    }
  }
  return result;
}

Widget _app({
  bool german = true,
  double scale = 1,
  void Function(Map<String, dynamic>)? onCompleted,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: KompassLabScreen(
          labId: _lab,
          german: german,
          onCompleted: onCompleted,
        ),
      ),
    );

Future<void> _open(
  WidgetTester tester,
  int index, {
  bool german = true,
  double scale = 1,
  void Function(Map<String, dynamic>)? onCompleted,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final round = generateReasoningRound(index, _seed);
  final prefs = await ProfilePreferences.getInstance();
  await prefs.setString(
    'kompass_lab_v1_$_lab',
    jsonEncode({
      'schemaVersion': 1,
      'labId': _lab,
      'sessionId': 'reasoning-fixture:$index',
      'seed': _seed,
      'index': index,
      'response': createReasoningResponse(round),
      'firstResponse': <String, dynamic>{},
      'activeMillis': 0,
      'attempts': 0,
      'hintsUsed': 0,
      'completed': false,
      'reported': false,
    }),
  );
  await tester.pumpWidget(
    _app(german: german, scale: scale, onCompleted: onCompleted),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String field, String value) async {
  final target = find.byKey(ValueKey('reasoning_field_$field'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _state(WidgetTester tester) => tester
    .state<KompassLabScreenState>(find.byType(KompassLabScreen))
    .exportState();

void main() {
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'reasoning-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test(
    'inverse walls preserve addition and award only valid follow-through',
    () {
      for (var seed = 0; seed < 32; seed++) {
        final round = generateReasoningRound(0, seed);
        final given = round.config;
        final middle = (given['top'] as int) - (given['leftMiddle'] as int);
        final base = middle - (given['middleBase'] as int);
        expect(
          (given['leftBase'] as int) + (given['middleBase'] as int),
          given['leftMiddle'],
        );
        expect(base, greaterThan(0));
        final correct = {
          'middle': '$middle',
          'base': '$base',
          'inverse': 'subtract',
        };
        expect(checkReasoningRound(round, correct).correct, isTrue);
        expect(
          checkReasoningRound(round, {...correct, 'inverse': 'add'}).points,
          2,
        );
        final carried = {
          'middle': '${middle + 10}',
          'base': '${base + 10}',
          'inverse': 'subtract',
        };
        expect(checkReasoningRound(round, carried).points, 2);
        expect(checkReasoningRound(round, carried).correct, isFalse);
        expect(
          checkReasoningRound(round, {
            ...carried,
            'base': '${base + 20}',
          }).points,
          1,
        );
        expect(
          checkReasoningRound(round, {
            ...correct,
            'middle': '$middle €',
          }).correct,
          isFalse,
        );
      }
    },
  );

  test(
    'every base permutation is checked against the independently built wall',
    () {
      const permutations = [
        [0, 1, 2],
        [0, 2, 1],
        [1, 0, 2],
        [1, 2, 0],
        [2, 0, 1],
        [2, 1, 0],
      ];
      for (var seed = 0; seed < 32; seed++) {
        final round = generateReasoningRound(1, seed);
        final cards = (round.config['cards'] as List).cast<int>();
        final tops = [
          for (final order in permutations)
            (cards[order[0]] + cards[order[1]]) +
                (cards[order[1]] + cards[order[2]]),
        ];
        final sortedTops = List<int>.of(tops)..sort();
        final maximum = sortedTops.last;
        var accepted = 0;
        for (var i = 0; i < permutations.length; i++) {
          final result = checkReasoningRound(round, {
            'order': [for (final card in permutations[i]) 'c$card'],
            'top': '$maximum',
            'reason': 'twice',
          });
          expect(result.correct, tops[i] == maximum);
          if (result.correct) accepted++;
        }
        expect(
          accepted,
          2,
          reason: 'Either ordering of the outside cards is valid.',
        );
        expect(
          checkReasoningRound(round, {
            'order': ['c0', 'c0', 'c2'],
            'top': '$maximum',
            'reason': 'twice',
          }).correct,
          isFalse,
        );
      }
    },
  );

  test(
    'machine steps alternate and carried credit does not complete a wrong sequence',
    () {
      for (var seed = 0; seed < 32; seed++) {
        final round = generateReasoningRound(2, seed);
        final config = round.config;
        final add = config['add'] as int;
        final factor = config['factor'] as int;
        var value = config['start'] as int;
        final independentSequence = [value];
        for (var step = 0; step < 6; step++) {
          value = step.isEven ? value + add : value * factor;
          independentSequence.add(value);
        }
        expect(config['shown'], independentSequence.take(5).toList());
        final correct = {
          'next': '${independentSequence[5]}',
          'after': '${independentSequence[6]}',
          'rule': 'add_then_multiply',
        };
        expect(checkReasoningRound(round, correct).correct, isTrue);
        final wrongNext = independentSequence[5] + 1;
        final carried = {
          'next': '$wrongNext',
          'after': '${wrongNext * factor}',
          'rule': 'add_then_multiply',
        };
        expect(checkReasoningRound(round, carried).points, 2);
        expect(checkReasoningRound(round, carried).correct, isFalse);
        expect(
          checkReasoningRound(round, {
            ...correct,
            'rule': 'multiply_then_add',
          }).points,
          2,
        );
      }
    },
  );

  test(
    'codes require a complete constructed set with the stated repetition and order',
    () {
      final seenRules = <bool>{};
      for (var seed = 0; seed < 64; seed++) {
        final round = generateReasoningRound(3, seed);
        final symbols = (round.config['symbols'] as List).cast<String>();
        final repetition = round.config['repetition'] == true;
        seenRules.add(repetition);
        final expected = _codes(round);
        final count = symbols.length * (symbols.length - (repetition ? 0 : 1));
        expect(expected.length, count);
        final correct = {
          'codes': expected,
          'count': '$count',
          'reason': 'systematic',
        };
        expect(checkReasoningRound(round, correct).correct, isTrue);
        expect(
          checkReasoningRound(round, {
            ...correct,
            'codes': expected.reversed.toList(),
          }).correct,
          isTrue,
        );
        expect(
          checkReasoningRound(round, {...correct, 'codes': <String>[]}).correct,
          isFalse,
        );
        expect(
          checkReasoningRound(round, {
            ...correct,
            'codes': expected.take(expected.length - 1).toList(),
          }).points,
          3,
        );
        expect(
          checkReasoningRound(round, {
            ...correct,
            'codes': [...expected, expected.first],
          }).points,
          2,
        );
        expect(
          checkReasoningRound(round, {
            ...correct,
            'codes': [...expected, 7],
          }).correct,
          isFalse,
        );
        expect(
          checkReasoningRound(round, {
            ...correct,
            'codes': [...expected, symbols.first],
          }).correct,
          isFalse,
        );
        if (!repetition) {
          expect(
            checkReasoningRound(round, {
              ...correct,
              'codes': [...expected, '${symbols.first}${symbols.first}'],
            }).correct,
            isFalse,
          );
        }
        // AB and BA are separate allowed codes, regardless of repetition policy.
        expect(expected, contains('${symbols[0]}${symbols[1]}'));
        expect(expected, contains('${symbols[1]}${symbols[0]}'));
      }
      expect(seenRules, {true, false});
    },
  );

  test(
    'recipes replay exactly and restored drafts keep duplicate codes for correction',
    () {
      for (var index = 0; index < 12; index++) {
        final first = generateReasoningRound(index, _seed);
        final second = generateReasoningRound(index, _seed);
        expect(first.type, second.type);
        expect(first.config, second.config);
        expect(first.promptDe, second.promptDe);
        expect(
          normalizeReasoningResponse(first, {}),
          createReasoningResponse(first),
        );
      }
      final round = generateReasoningRound(3, _seed);
      final codes = _codes(round);
      final restored = normalizeReasoningResponse(round, {
        'codes': [...codes, codes.first],
        'count': '${codes.length}',
        'reason': 'systematic',
        'unexpected': 'discard',
      });
      expect(restored['codes'], hasLength(codes.length + 1));
      expect(restored.containsKey('unexpected'), isFalse);
      expect(checkReasoningRound(round, restored).correct, isFalse);
    },
  );

  testWidgets(
    'inverse wall correction preserves partial first evidence through actual inputs',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 0, onCompleted: events.add);
      final config = generateReasoningRound(0, _seed).config;
      final middle = (config['top'] as int) - (config['leftMiddle'] as int);
      final base = middle - (config['middleBase'] as int);
      await _enter(tester, 'middle', '${middle + 10}');
      await _enter(tester, 'base', '${base + 10}');
      await _tap(tester, 'reasoning_inverse_subtract');
      await _tap(tester, 'lab_check');
      expect(events, isEmpty);
      expect(_state(tester)['firstPoints'], 2);
      await _enter(tester, 'middle', '$middle');
      await _enter(tester, 'base', '$base');
      await _tap(tester, 'lab_check');
      expect(events, hasLength(1));
      expect(events.single['firstCorrect'], isFalse);
      expect(events.single['awardedPoints'], 2);
      expect(events.single['maxPoints'], 3);
      expect((events.single['response'] as Map)['middle'], '${middle + 10}');
      expect((events.single['finalResponse'] as Map)['middle'], '$middle');
    },
  );

  testWidgets(
    'wall cards can be arranged and justified through actual controls',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 1, onCompleted: events.add);
      final cards = (generateReasoningRound(1, _seed).config['cards'] as List)
          .cast<int>();
      final indices = [0, 1, 2]..sort((a, b) => cards[a].compareTo(cards[b]));
      final order = [indices[0], indices[2], indices[1]];
      for (final index in order) {
        await _tap(tester, 'reasoning_card_c$index');
      }
      final top =
          cards[order[0]] + cards[order[1]] + cards[order[1]] + cards[order[2]];
      await _enter(tester, 'top', '$top');
      await _tap(tester, 'reasoning_reason_twice');
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isTrue);
      expect((events.single['response'] as Map)['order'], [
        for (final i in order) 'c$i',
      ]);
      expect(events.single['practiceOnly'], isTrue);
    },
  );

  testWidgets(
    'machine draft and hint restore before completing the second step',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 2, onCompleted: events.add);
      final config = generateReasoningRound(2, _seed).config;
      final next =
          ((config['shown'] as List).last as int) + (config['add'] as int);
      final after = next * (config['factor'] as int);
      await _enter(tester, 'next', '$next');
      await _tap(tester, 'reasoning_rule_add_then_multiply');
      await _tap(tester, 'lab_hint');
      final originalId = _state(tester)['roundId'];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(onCompleted: events.add));
      await tester.pumpAndSettle();
      expect(_state(tester)['roundId'], originalId);
      expect((_state(tester)['response'] as Map)['next'], '$next');
      expect(_state(tester)['hintsUsed'], 1);
      await _enter(tester, 'after', '$after');
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isTrue);
      expect(events.single['hintsUsed'], 1);
    },
  );

  testWidgets(
    'code builder collects every code and prevents duplicate insertion',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 3, onCompleted: events.add);
      final expected = _codes(generateReasoningRound(3, _seed));
      for (final code in expected) {
        await _tap(tester, 'reasoning_draftFirst_${code[0]}');
        await _tap(tester, 'reasoning_draftSecond_${code[1]}');
        await _tap(tester, 'reasoning_add_code');
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('reasoning_add_code')),
              )
              .onPressed,
          isNull,
        );
      }
      await _enter(tester, 'count', '${expected.length}');
      await _tap(tester, 'reasoning_reason_systematic');
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isTrue);
      expect((events.single['response'] as Map)['codes'], expected);
      expect(events.single['maxPoints'], 4);
    },
  );

  for (var index = 0; index < 4; index++) {
    testWidgets(
      'reasoning activity $index fits a short phone with doubled text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 650);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester, index, scale: 2, german: index.isEven);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'lab_hint');
        await _tap(tester, 'lab_check');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
