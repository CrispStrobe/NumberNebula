import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/chance_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';

const _lab = 'chance_detective';
const _pairs = [
  ['star', 'star'],
  ['star', 'circle'],
  ['circle', 'star'],
  ['circle', 'circle'],
];

bool _legal(KompassLabRound round, List<String> pair) {
  final available = <String, int>{
    'star': round.config['stars'] as int,
    'circle': round.config['circles'] as int,
  };
  for (final token in pair) {
    if ((available[token] ?? 0) == 0) return false;
    if (round.config['replacement'] != true) {
      available[token] = available[token]! - 1;
    }
  }
  return true;
}

bool _contradicts(KompassLabRound round, List<String> pair) {
  final stars = pair.where((value) => value == 'star').length;
  return switch (round.config['claim']) {
    'same' => stars == 1,
    'atLeastStar' => stars == 0,
    _ => stars != 1,
  };
}

List<String> _witness(KompassLabRound round) => _pairs.firstWhere(
      (pair) => _legal(round, pair) && _contradicts(round, pair),
    );

Map<String, dynamic> _answer(
  List<String> pair, {
  String reason = 'exception',
}) =>
    {'first': pair[0], 'second': pair[1], 'reason': reason};

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
  int index,
  int seed, {
  bool german = true,
  double scale = 1,
  void Function(Map<String, dynamic>)? onCompleted,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final round = generateChanceDetectiveRound(index, seed);
  final prefs = await ProfilePreferences.getInstance();
  await prefs.setString(
    'kompass_lab_v1_$_lab',
    jsonEncode({
      'schemaVersion': 1,
      'labId': _lab,
      'sessionId': 'chance-fixture:$index:$seed',
      'seed': seed,
      'index': index,
      'response': createChanceDetectiveResponse(round),
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
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, List<String> pair) async {
  await _tap(tester, 'chance_first_${pair[0]}');
  await _tap(tester, 'chance_second_${pair[1]}');
}

Map<String, dynamic> _state(WidgetTester tester) => tester
    .state<KompassLabScreenState>(find.byType(KompassLabScreen))
    .exportState();

void main() {
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'chance-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test(
    'all generated claims have legal counterexamples under the stated draw rule',
    () {
      final policies = <bool>{};
      for (var index = 0; index < 3; index++) {
        for (var seed = 0; seed < 64; seed++) {
          final round = generateChanceDetectiveRound(index, seed);
          policies.add(round.config['replacement'] == true);
          var possibleWitnesses = 0;
          for (final pair in _pairs) {
            final legal = _legal(round, pair);
            final witness = legal && _contradicts(round, pair);
            final result = checkChanceDetectiveRound(round, _answer(pair));
            expect(result.points, (legal ? 1 : 0) + (witness ? 1 : 0) + 1);
            expect(result.correct, witness);
            if (witness) possibleWitnesses++;
          }
          expect(possibleWitnesses, greaterThan(0));
          final example = RegExp(
            r'(star|circle) and then (star|circle)',
          ).firstMatch(round.solutionEn);
          expect(
            example,
            isNotNull,
            reason: 'The worked solution names a concrete witness.',
          );
          final foundExample = example!;
          final pair = [foundExample.group(1)!, foundExample.group(2)!];
          expect(_legal(round, pair), isTrue);
          expect(_contradicts(round, pair), isTrue);
        }
      }
      expect(policies, {true, false});
    },
  );

  test(
    'replacement permits reuse; a single token cannot be drawn twice without it',
    () {
      for (final replacement in [false, true]) {
        final template = generateChanceDetectiveRound(2, 417);
        final round = KompassLabRound(
          type: template.type,
          skillIds: template.skillIds,
          config: {
            ...template.config,
            'stars': 1,
            'circles': 2,
            'replacement': replacement,
            'claim': 'oneEach',
          },
          titleDe: template.titleDe,
          titleEn: template.titleEn,
          promptDe: template.promptDe,
          promptEn: template.promptEn,
          solutionDe: template.solutionDe,
          solutionEn: template.solutionEn,
          hintsDe: template.hintsDe,
          hintsEn: template.hintsEn,
        );
        final result = checkChanceDetectiveRound(
          round,
          _answer(['star', 'star']),
        );
        expect(result.points, replacement ? 3 : 1);
        expect(result.correct, replacement);
        expect(
          checkChanceDetectiveRound(
            round,
            _answer(['circle', 'circle']),
          ).correct,
          isTrue,
        );
      }
    },
  );

  test(
    'a legal pair is insufficient unless it disproves the claim and has a valid reason',
    () {
      final round = generateChanceDetectiveRound(1, 417);
      final legalButSupporting = ['star', 'circle'];
      expect(
        checkChanceDetectiveRound(round, _answer(legalButSupporting)).points,
        2,
      );
      final witness = _witness(round);
      expect(
        checkChanceDetectiveRound(
          round,
          _answer(witness, reason: 'frequent'),
        ).points,
        2,
      );
      expect(
        checkChanceDetectiveRound(
          round,
          _answer(witness, reason: 'oneTrial'),
        ).points,
        2,
      );
      expect(
        checkChanceDetectiveRound(
          round,
          _answer(['triangle', 'circle']),
        ).points,
        1,
      );
      expect(
        checkChanceDetectiveRound(round, {
          'first': '',
          'second': '',
          'reason': 'exception',
        }).correct,
        isFalse,
      );
    },
  );

  test(
    'restoration retains valid choices and removes unknown response fields',
    () {
      final round = generateChanceDetectiveRound(0, 417);
      expect(
        normalizeChanceDetectiveResponse(round, {
          'first': 'star',
          'second': 'circle',
          'reason': 'exception',
          'unused': 3,
        }),
        {'first': 'star', 'second': 'circle', 'reason': 'exception'},
      );
      expect(
        normalizeChanceDetectiveResponse(round, {
          'first': 'triangle',
          'second': 7,
          'reason': 'magic',
        }),
        createChanceDetectiveResponse(round),
      );
    },
  );

  testWidgets(
    'actual controls preserve a legal but nonrefuting first pair after correction',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 1, 417, onCompleted: events.add);
      final round = generateChanceDetectiveRound(1, 417);
      await _select(tester, ['star', 'circle']);
      await _tap(tester, 'chance_reason_exception');
      await _tap(tester, 'lab_check');
      expect(events, isEmpty);
      expect(_state(tester)['firstPoints'], 2);
      await _select(tester, _witness(round));
      await _tap(tester, 'lab_check');
      expect(events, hasLength(1));
      expect(events.single['firstCorrect'], isFalse);
      expect(events.single['awardedPoints'], 2);
      expect((events.single['response'] as Map)['first'], 'star');
      expect((events.single['finalResponse'] as Map)['first'], 'circle');
      expect(events.single['practiceOnly'], isTrue);
    },
  );

  testWidgets(
    'an illegal repeated draw remains incomplete until a possible witness is built',
    (tester) async {
      final seed = Iterable<int>.generate(1000).firstWhere((seed) {
        final config = generateChanceDetectiveRound(2, seed).config;
        return config['replacement'] == false && config['stars'] == 1;
      });
      final events = <Map<String, dynamic>>[];
      await _open(tester, 2, seed, onCompleted: events.add);
      await _select(tester, ['star', 'star']);
      await _tap(tester, 'chance_reason_exception');
      await _tap(tester, 'lab_check');
      expect(events, isEmpty);
      expect(_state(tester)['firstPoints'], 1);
      await _select(tester, ['circle', 'circle']);
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isFalse);
      expect(events.single['awardedPoints'], 1);
      expect(events.single['maxPoints'], 3);
    },
  );

  testWidgets(
    'a partial witness and assistance restore before the first submission',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      await _open(tester, 0, 417, onCompleted: events.add);
      final witness = _witness(generateChanceDetectiveRound(0, 417));
      await _tap(tester, 'chance_first_${witness[0]}');
      await _tap(tester, 'chance_reason_exception');
      await _tap(tester, 'lab_hint');
      final roundId = _state(tester)['roundId'];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(onCompleted: events.add));
      await tester.pumpAndSettle();
      expect(_state(tester)['roundId'], roundId);
      expect((_state(tester)['response'] as Map)['first'], witness[0]);
      expect((_state(tester)['response'] as Map)['second'], '');
      expect(_state(tester)['hintsUsed'], 1);
      expect(_state(tester)['attempts'], 0);
      await _tap(tester, 'chance_second_${witness[1]}');
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isTrue);
      expect(events.single['hintsUsed'], 1);
    },
  );

  for (var index = 0; index < 3; index++) {
    testWidgets('chance claim $index fits a short phone with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _open(tester, index, 417, scale: 2, german: index.isEven);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'lab_hint');
      await _tap(tester, 'lab_check');
      expect(tester.takeException(), isNull);
    });
  }
}
