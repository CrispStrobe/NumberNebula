import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';

const _seed = 417;

Map<String, dynamic> _snapshot(String id, int index,
        {Map<String, dynamic>? response}) =>
    {
      'schemaVersion': 1,
      'labId': id,
      'sessionId': 'fixture:$id',
      'seed': _seed,
      'index': index,
      'response': response ??
          generateKompassLabRound(id, index, _seed).createResponse(),
      'firstResponse': <String, dynamic>{},
      'activeMillis': 0,
      'attempts': 0,
      'hintsUsed': 0,
      'completed': false,
      'reported': false,
    };

Widget _app(String id,
        {bool german = true,
        double scale = 1,
        FutureOr<void> Function(Map<String, dynamic>)? onCompleted}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: KompassLabScreen(
            labId: id, german: german, onCompleted: onCompleted),
      ),
    );

Future<void> _open(WidgetTester tester, String id, int index,
    {bool german = true,
    double scale = 1,
    Map<String, dynamic>? response,
    FutureOr<void> Function(Map<String, dynamic>)? onCompleted}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('kompass_lab_v1_$id',
      jsonEncode(_snapshot(id, index, response: response)));
  await tester.pumpWidget(
      _app(id, german: german, scale: scale, onCompleted: onCompleted));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _setCounter(WidgetTester tester, String id, int target) async {
  for (var step = 0; step < 100; step++) {
    final text = tester.widget<Text>(find.byKey(ValueKey('lab_${id}_value')));
    final value = int.parse(text.data!);
    if (value == target) return;
    await _tap(tester, 'lab_${id}_${value < target ? 'plus' : 'minus'}');
  }
  fail('Counter $id did not reach $target through input');
}

KompassLabScreenState _state(WidgetTester tester) =>
    tester.state<KompassLabScreenState>(find.byType(KompassLabScreen));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test(
      'cube folding distinguishes nets from overlapping and disconnected layouts',
      () {
    expect(isCubeNet({'0,1', '1,0', '1,1', '1,2', '2,1', '3,1'}), isTrue);
    expect(isCubeNet({'0,0', '1,0', '1,1', '1,2', '1,3', '2,3'}), isTrue);
    expect(isCubeNet({'0,0', '0,1', '0,2', '1,0', '1,1', '1,2'}), isFalse);
    expect(isCubeNet({'0,0', '1,0', '2,0', '3,0', '4,0', '5,0'}), isFalse);
    expect(isCubeNet({'0,1', '1,0', '1,1', '1,2', '2,1', '9,9'}), isFalse);
  });

  test('regrouping fixtures preserve value and generation replays from seed',
      () {
    for (var seed = 0; seed < 20; seed++) {
      final round = generateKompassLabRound('number_dock', 1, seed);
      final start = intList(round.config['start']);
      expect(placeValueTotal(start), round.config['target']);
      expect(start.any((n) => n > 9), isTrue);
      for (var i = 3; i > 0; i--) {
        while (start[i] >= 10) {
          start[i] -= 10;
          start[i - 1]++;
        }
      }
      expect(round.check({'counts': start}).correct, isTrue);
      expect(
          generateKompassLabRound('number_dock', 1, seed).config, round.config);
    }
  });

  test(
      'lab evaluation accepts different valid containers and exact decimal commas',
      () {
    final volume = generateKompassLabRound('supply_station', 2, _seed);
    final target = volume.config['targetMl'] as int;
    expect(volume.check({'bottles': 0, 'cups': target ~/ 250}).correct, isTrue);
    expect(
        volume.check(
            {'bottles': target ~/ 1000, 'cups': target % 1000 ~/ 250}).correct,
        isTrue);
    expect(parseLabNumber(' 3,75 € '), 3.75);
    expect(parseLabNumber('NaN'), isNull);
    expect(parseLabNumber('Infinity'), isNull);
  });

  test('corrupt draft shapes restore safe controls without changing content',
      () {
    final round = generateKompassLabRound('number_dock', 0, _seed);
    expect(
        round.normalizeResponse({
          'counts': [1]
        }),
        {
          'counts': [0, 0, 0, 0]
        });
    expect(
        round.normalizeResponse({
          'counts': [1, 2, 'bad', 4]
        }),
        {
          'counts': [0, 0, 0, 0]
        });
    expect(
        round.normalizeResponse({
          'counts': [-1, 400, 2, 3]
        }),
        {
          'counts': [0, 29, 2, 3]
        });
  });

  testWidgets(
      'real retries keep the first attempt; completion and solved restore are single-shot',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'number_dock', 0, onCompleted: events.add);
    await _tap(tester, 'lab_check');
    expect(events, isEmpty);
    await _tap(tester, 'lab_hint');
    final target = generateKompassLabRound('number_dock', 0, _seed)
        .config['target'] as int;
    final digits = [
      target ~/ 1000,
      target % 1000 ~/ 100,
      target % 100 ~/ 10,
      target % 10
    ];
    for (var i = 0; i < digits.length; i++) {
      await _setCounter(tester, 'place_$i', digits[i]);
    }
    await _tap(tester, 'lab_check');
    expect(events, hasLength(1));
    expect(events.single['mode'], 'practice');
    expect(events.single['firstCorrect'], isFalse);
    expect(events.single['hintsUsed'], 1);
    expect(events.single['awardedPoints'], 0);
    expect(events.single['response'], {
      'counts': [0, 0, 0, 0]
    });
    expect(events.single['finalResponse'], {'counts': digits});
    expect(events.single['attempts'], 2);
    final originalId = events.single['roundId'];
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app('number_dock', onCompleted: events.add));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lab_next')), findsOneWidget);
    expect(events, hasLength(1));
    expect(_state(tester).exportState()['roundId'], originalId);
    await _tap(tester, 'lab_next');
    expect(_state(tester).exportState()['roundId'], isNot(originalId));
    final counts =
        intList((_state(tester).exportState()['response'] as Map)['counts']);
    final before = placeValueTotal(counts);
    for (var i = 3; i > 0; i--) {
      while (counts[i] >= 10) {
        await _tap(tester, 'lab_trade_$i');
        counts[i] -= 10;
        counts[i - 1]++;
      }
    }
    expect(placeValueTotal(counts), before);
    await _tap(tester, 'lab_check');
    expect(events, hasLength(2));
    expect(events.last['firstCorrect'], isTrue);
    expect(events.last['hintsUsed'], 0);
  });

  testWidgets(
      'failed async completion remains retryable across reopen and records once',
      (tester) async {
    var deliveries = 0;
    final durable = <String>{};
    Future<void> record(Map<String, dynamic> result) async {
      deliveries++;
      await Future<void>.value();
      if (deliveries == 1) throw StateError('simulated storage failure');
      durable.add(result['roundId'] as String);
    }

    final target = generateKompassLabRound('number_dock', 0, _seed)
        .config['target'] as int;
    final digits = [
      target ~/ 1000,
      target % 1000 ~/ 100,
      target % 100 ~/ 10,
      target % 10
    ];
    await _open(tester, 'number_dock', 0,
        response: {'counts': digits}, onCompleted: record);
    await _tap(tester, 'lab_check');
    expect(deliveries, 1);
    expect(durable, isEmpty);
    expect(_state(tester).exportState()['reported'], isFalse);
    expect(find.byKey(const ValueKey('lab_retry_record')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('lab_next')))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app('number_dock', onCompleted: record));
    await tester.pumpAndSettle();
    expect(deliveries, 1);
    await _tap(tester, 'lab_retry_record');
    expect(deliveries, 2);
    expect(durable, hasLength(1));
    expect(_state(tester).exportState()['reported'], isTrue);
    expect(find.byKey(const ValueKey('lab_retry_record')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app('number_dock', onCompleted: record));
    await tester.pumpAndSettle();
    expect(deliveries, 2);
    expect(durable, hasLength(1));
  });

  testWidgets('money lab records partial first credit and accepts comma input',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'supply_station', 0, onCompleted: events.add);
    final round = generateKompassLabRound('supply_station', 0, _seed);
    var change = round.config['changeCents'] as int;
    for (var i = 0; i < labCoinValues.length; i++) {
      final count = change ~/ labCoinValues[i];
      await _setCounter(tester, 'coin_$i', count);
      change %= labCoinValues[i];
    }
    await _tap(tester, 'lab_check');
    expect(events, isEmpty);
    final input = find.byKey(const ValueKey('lab_field_total'));
    await tester.ensureVisible(input);
    final cents = round.config['totalCents'] as int;
    await tester.enterText(
        input, '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}');
    await tester.pumpAndSettle();
    await _tap(tester, 'lab_check');
    expect(events, hasLength(1));
    expect(events.single['firstCorrect'], isFalse);
    expect(events.single['maxPoints'], 2);
    expect(events.single['awardedPoints'], 1);
    expect((events.single['response'] as Map)['total'], '');
  });

  testWidgets(
      'time lab handles crossing an hour through hour and minute controls',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'supply_station', 1, onCompleted: events.add);
    final config = generateKompassLabRound('supply_station', 1, _seed).config;
    final arrival = (config['startHour'] as int) * 60 +
        (config['startMinute'] as int) +
        (config['duration'] as int);
    await _setCounter(tester, 'hour', arrival ~/ 60);
    await _setCounter(tester, 'minute', arrival % 60);
    await _tap(tester, 'lab_check');
    expect(events.single['firstCorrect'], isTrue);
    expect(events.single['awardedPoints'], 2);
  });

  testWidgets('data lab builds all chart bars through the actual controls',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'data_observatory', 0, onCompleted: events.add);
    final values = intList(
        generateKompassLabRound('data_observatory', 0, _seed).config['values']);
    for (var i = 0; i < values.length; i++) {
      await _setCounter(tester, 'bar_$i', values[i]);
    }
    await _tap(tester, 'lab_check');
    expect(events.single['firstCorrect'], isTrue);
    expect(events.single['maxPoints'], 3);
    expect(events.single['awardedPoints'], 3);
  });

  testWidgets(
      'probability samples use replacement and reset when bag composition changes',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'data_observatory', 1, onCompleted: events.add);
    await _tap(tester, 'lab_draw');
    final first = _state(tester).exportState()['response'] as Map;
    expect(first['draws'], ['star']);
    expect(first['blue'], 0);
    await _tap(tester, 'lab_blue_plus');
    expect((_state(tester).exportState()['response'] as Map)['draws'], isEmpty);
    final stars = generateKompassLabRound('data_observatory', 1, _seed)
        .config['red'] as int;
    await _setCounter(tester, 'blue', stars);
    await _tap(tester, 'lab_draw');
    expect((_state(tester).exportState()['response'] as Map)['blue'], stars);
    await _tap(tester, 'lab_check');
    expect(events.single['practiceOnly'], isTrue);
    expect(events.single['firstCorrect'], isTrue);
  });

  testWidgets(
      'geometry accepts a valid net through grid input and keeps given faces fixed',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'geometry_workshop', 1, onCompleted: events.add);
    final fixed = stringList(
            generateKompassLabRound('geometry_workshop', 1, _seed)
                .config['cells'])
        .toSet();
    final full = {'0,1', '1,0', '1,1', '1,2', '2,1', '3,1'};
    final addition = full.difference(fixed).single;
    await _tap(tester, 'kompass_cell_${fixed.first}');
    expect((_state(tester).exportState()['response'] as Map)['cells'], isEmpty);
    await _tap(tester, 'kompass_cell_$addition');
    await _tap(tester, 'lab_check');
    expect(events.single['firstCorrect'], isTrue);
    expect((events.single['response'] as Map)['cells'], [addition]);
  });

  testWidgets(
      'side-view columns use the viewing direction and complete as practice',
      (tester) async {
    final events = <Map<String, dynamic>>[];
    await _open(tester, 'geometry_workshop', 2, onCompleted: events.add);
    final config =
        generateKompassLabRound('geometry_workshop', 2, _seed).config;
    final heights = (config['heights'] as List).map(intList).toList();
    final view = config['view'];
    final expected = <int>[];
    for (var i = 0; i < 3; i++) {
      var maximum = 0;
      for (var j = 0; j < 3; j++) {
        final height = view == 'right' ? heights[2 - i][j] : heights[j][i];
        if (height > maximum) maximum = height;
      }
      expected.add(maximum);
    }
    for (var i = 0; i < expected.length; i++) {
      await _setCounter(tester, 'height_$i', expected[i]);
    }
    await _tap(tester, 'lab_check');
    expect(events.single['firstCorrect'], isTrue);
    expect(events.single['skillIds'], ['M-R06']);
  });

  testWidgets(
      'active time freezes in background and captured writes stay with the player',
      (tester) async {
    await _open(tester, 'number_dock', 0);
    await _tap(tester, 'lab_place_0_plus');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = _state(tester).exportState()['activeMillis'];
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    expect(_state(tester).exportState()['activeMillis'], paused);
    final beforeSwitch = _state(tester).exportState()['response'];
    ProfilePreferences.activeId = 'second';
    // A retained old input callback may still be enabled visually; its guard
    // must prevent editing the previous player's round after a profile switch.
    await _tap(tester, 'lab_place_0_plus');
    expect(_state(tester).exportState()['response'], beforeSwitch);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('player_second_kompass_lab_v1_number_dock'), isNull);
    final saved =
        jsonDecode(prefs.getString('kompass_lab_v1_number_dock')!) as Map;
    expect((saved['response'] as Map)['counts'], [1, 0, 0, 0]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  for (final entry in {
    'number_dock': 3,
    'supply_station': 4,
    'data_observatory': 3,
    'geometry_workshop': 3
  }.entries) {
    for (var index = 0; index < entry.value; index++) {
      testWidgets('${entry.key} variant $index fits a phone at text scale 2',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _open(tester, entry.key, index, scale: 2, german: index.isEven);
        expect(tester.takeException(), isNull);
        await _tap(tester, 'lab_hint');
        await _tap(tester, 'lab_check');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
