import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/area_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/journey_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';

const _seed = 417;

KompassLabRound _construction(int area, int perimeter) => KompassLabRound(
      type: 'area_construct',
      skillIds: const ['M-R08'],
      config: {
        'rows': 6,
        'cols': 6,
        'sideCm': 1,
        'areaCm2': area,
        'perimeterCm': perimeter,
      },
      titleDe: 'Bauen',
      titleEn: 'Build',
      promptDe: 'Baue eine zusammenhängende Figur ohne Löcher.',
      promptEn: 'Build a connected shape without holes.',
      solutionDe: 'Die Figur passt.',
      solutionEn: 'The shape fits.',
      hintsDe: const [],
      hintsEn: const [],
    );

Widget _app(
  String labId, {
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
          labId: labId,
          german: german,
          onCompleted: onCompleted,
        ),
      ),
    );

Future<void> _open(
  WidgetTester tester,
  String labId,
  int index, {
  bool german = true,
  double scale = 1,
  void Function(Map<String, dynamic>)? onCompleted,
}) async {
  final round = generateKompassLabRound(labId, index, _seed);
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    'kompass_lab_v1_$labId',
    jsonEncode({
      'schemaVersion': 1,
      'labId': labId,
      'sessionId': 'extension:$labId',
      'seed': _seed,
      'index': index,
      'response': round.createResponse(),
      'firstResponse': <String, dynamic>{},
      'activeMillis': 0,
      'attempts': 0,
      'hintsUsed': 0,
      'completed': false,
      'reported': false,
    }),
  );
  await tester.pumpWidget(
    _app(labId, german: german, scale: scale, onCompleted: onCompleted),
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

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _state(WidgetTester tester) => tester
    .state<KompassLabScreenState>(find.byType(KompassLabScreen))
    .exportState();

void _compact(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test('journey clock input keeps minutes separate from decimal hours', () {
    expect(parseJourneyTime('9:05'), 9 * 60 + 5);
    expect(parseJourneyTime(' 09.05 Uhr '), 9 * 60 + 5);
    expect(parseJourneyTime('23:59'), 1439);
    for (final input in ['24:00', '09:60', '9.5', '9,50', '-1:05', '900']) {
      expect(parseJourneyTime(input), isNull, reason: input);
    }
    expect(parseJourneyTime(null), isNull);
    expect(parseJourneyTime(905), isNull);
  });

  test('backwards plans satisfy an independent forward time equation', () {
    for (var seed = 0; seed < 30; seed++) {
      final round = generateJourneyRound(0, seed);
      final c = round.config;
      final deadline = c['deadline'] as int;
      final ride = c['rideMinutes'] as int;
      final walk = c['walkMinutes'] as int;
      final reserve = c['reserveMinutes'] as int;
      final stop = deadline - walk - reserve;
      final departure = stop - ride;
      expect(departure, greaterThanOrEqualTo(0));
      expect(deadline, lessThan(24 * 60));
      expect(
        checkJourneyRound(round, {
          'stopTime': journeyTime(stop),
          'leaveTime': journeyTime(departure),
        }).correct,
        isTrue,
      );
      expect(
        checkJourneyRound(round, {
          'stopTime': journeyTime(stop),
          'leaveTime': journeyTime(departure + reserve),
        }).points,
        1,
      );
      expect(generateJourneyRound(0, seed).config, c);
    }
  });

  test(
    'connections include exact reserve equality and different best rows',
    () {
      final bestIds = <String>{};
      var equalityCases = 0;
      for (var seed = 0; seed < 60; seed++) {
        final round = generateJourneyRound(1, seed);
        final c = round.config;
        final platform = (c['startTime'] as int) +
            (c['rideMinutes'] as int) +
            (c['walkMinutes'] as int);
        final earliest = platform + (c['reserveMinutes'] as int);
        final services = (c['services'] as List).cast<Map>();
        final possible = services
            .where((row) => (row['departure'] as int) >= earliest)
            .toList()
          ..sort(
            (a, b) => (a['departure'] as int).compareTo(b['departure'] as int),
          );
        final best = possible.first;
        bestIds.add(best['id'] as String);
        if (best['departure'] == earliest) equalityCases++;
        expect(
          checkJourneyRound(round, {
            'platformTime': journeyTime(platform),
            'service': best['id'],
          }).points,
          2,
        );
        final wrong = services.firstWhere((row) => row['id'] != best['id']);
        expect(
          checkJourneyRound(round, {
            'platformTime': journeyTime(platform),
            'service': wrong['id'],
          }).points,
          1,
        );
      }
      expect(bestIds, {'A', 'B', 'C'});
      expect(equalityCases, greaterThan(0));
    },
  );

  test(
    'new lab drafts reject foreign shapes but retain unfinished time text',
    () {
      final journey = generateJourneyRound(1, _seed);
      expect(
        normalizeJourneyResponse(journey, {
          'platformTime': '14:',
          'service': 'not-a-service',
          'injected': true,
        }),
        {'platformTime': '14:', 'service': ''},
      );
      final area = generateAreaRound(1, _seed);
      expect(
        normalizeAreaResponse(area, {
          'cells': ['0,0', '0,0', '1,2', '6,0', '-1,2', 'bad', 42],
        }),
        {
          'cells': ['0,0', '1,2'],
        },
      );
      expect(
        normalizeAreaResponse(generateAreaRound(0, _seed), {
          'area': ['wrong type'],
          'perimeter': '12 cm',
        }),
        {'area': '', 'perimeter': '12 cm'},
      );
    },
  );

  test(
    'area measurement distinguishes shared edges, corners, holes and repeats',
    () {
      final elbow = measureAreaShape(['0,0', '1,0', '1,1'], rows: 6, cols: 6);
      expect(elbow.cells, 3);
      expect(elbow.boundaryEdges, 8);
      expect(elbow.connected, isTrue);
      expect(elbow.holeFree, isTrue);
      final corners = measureAreaShape(['0,0', '1,1'], rows: 6, cols: 6);
      expect(corners.boundaryEdges, 8);
      expect(corners.connected, isFalse);
      final ring = ['0,0', '0,1', '0,2', '1,0', '1,2', '2,0', '2,1', '2,2'];
      final hole = measureAreaShape(ring, rows: 6, cols: 6);
      expect(hole.cells, 8);
      expect(hole.boundaryEdges, 16);
      expect(hole.connected, isTrue);
      expect(hole.holeFree, isFalse);
      expect(
        checkAreaRound(_construction(8, 16), {'cells': ring}).correct,
        isFalse,
      );
      expect(
        checkAreaRound(_construction(2, 8), {
          'cells': ['0,0', '1,1'],
        }).correct,
        isFalse,
      );
      expect(measureAreaShape(['0,0', '0,0'], rows: 6, cols: 6).valid, isFalse);
      expect(measureAreaShape(['6,0'], rows: 6, cols: 6).valid, isFalse);
    },
  );

  test(
    'construction accepts genuinely different shapes with the same measures',
    () {
      final round = _construction(6, 12);
      final staircase = ['0,0', '0,1', '0,2', '1,0', '1,1', '2,0'];
      final longCorner = ['0,0', '0,1', '0,2', '0,3', '1,0', '1,1'];
      expect(checkAreaRound(round, {'cells': staircase}).points, 3);
      expect(checkAreaRound(round, {'cells': longCorner}).points, 3);
      final line = [for (var col = 0; col < 6; col++) '0,$col'];
      expect(checkAreaRound(round, {'cells': line}).points, 2);
      expect(checkAreaRound(round, {'cells': line}).correct, isFalse);
      expect(checkAreaRound(round, {'cells': <String>[]}).points, 0);
    },
  );

  test(
    'area recipes remain solvable and scaled dimensions use square units',
    () {
      var twoCentimetreCases = 0;
      for (var seed = 0; seed < 30; seed++) {
        final measure = generateAreaRound(0, seed);
        final cells = (measure.config['cells'] as List).cast<String>().toSet();
        var sharedEdges = 0;
        for (final value in cells) {
          final coordinates = value.split(',').map(int.parse).toList();
          if (cells.contains('${coordinates[0] + 1},${coordinates[1]}'))
            sharedEdges++;
          if (cells.contains('${coordinates[0]},${coordinates[1] + 1}'))
            sharedEdges++;
        }
        final side = measure.config['sideCm'] as int;
        if (side == 2) twoCentimetreCases++;
        final area = cells.length * side * side;
        final perimeter = (4 * cells.length - 2 * sharedEdges) * side;
        expect(
          checkAreaRound(measure, {
            'area': '$area cm²',
            'perimeter': '$perimeter cm',
          }).correct,
          isTrue,
        );
        expect(
          checkAreaRound(measure, {
            'area': '$area cm',
            'perimeter': '$perimeter cm',
          }).points,
          1,
        );
        final construct = generateAreaRound(1, seed);
        expect(
          checkAreaRound(construct, {
            'cells': construct.config['exampleCells'],
          }).correct,
          isTrue,
        );
        expect(generateAreaRound(1, seed).config, construct.config);
      }
      expect(twoCentimetreCases, greaterThan(0));
    },
  );

  testWidgets(
    'backward journey retains drafts and first mistakes after reopening',
    (tester) async {
      _compact(tester);
      final events = <Map<String, dynamic>>[];
      final round = generateJourneyRound(0, _seed);
      final stop = journeyTime(round.config['stopTime'] as int);
      final leave = journeyTime(round.config['leaveTime'] as int);
      await _open(
        tester,
        'journey_planner',
        0,
        scale: 2,
        onCompleted: events.add,
      );
      await _enter(tester, 'journey_stopTime', stop);
      await _enter(tester, 'journey_leaveTime', '00:00');
      await _tap(tester, 'lab_check');
      expect(_state(tester)['firstPoints'], 1);
      expect(events, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app('journey_planner', scale: 2, onCompleted: events.add),
      );
      await tester.pumpAndSettle();
      expect((_state(tester)['response'] as Map)['stopTime'], stop);
      expect((_state(tester)['firstResponse'] as Map)['leaveTime'], '00:00');
      await _enter(tester, 'journey_leaveTime', leave);
      await _tap(tester, 'lab_check');
      expect(events, hasLength(1));
      expect(events.single['firstCorrect'], isFalse);
      expect(events.single['awardedPoints'], 1);
      expect((events.single['finalResponse'] as Map)['leaveTime'], leave);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connection uses real clock input and a keyboard-selected service',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      final round = generateJourneyRound(1, _seed);
      await _open(
        tester,
        'journey_planner',
        1,
        german: false,
        onCompleted: events.add,
      );
      await _enter(
        tester,
        'journey_platformTime',
        journeyTime(round.config['platformTime'] as int),
      );
      final chip = find.byKey(
        ValueKey('journey_service_${round.config['bestService']}'),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      final label =
          find.descendant(of: chip, matching: find.byType(Text)).first;
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        (_state(tester)['response'] as Map)['service'],
        round.config['bestService'],
      );
      await _tap(tester, 'lab_check');
      expect(events.single['firstCorrect'], isTrue);
      expect(events.single['awardedPoints'], 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'area measurement accepts actual unit input on a compact large-text screen',
    (tester) async {
      _compact(tester);
      final events = <Map<String, dynamic>>[];
      final round = generateAreaRound(0, _seed);
      await _open(tester, 'area_studio', 0, scale: 2, onCompleted: events.add);
      await _enter(tester, 'area_area', '${round.config['areaCm2']} cm²');
      await _enter(
        tester,
        'area_perimeter',
        '${round.config['perimeterCm']} cm',
      );
      await _tap(tester, 'lab_check');
      expect(events.single['awardedPoints'], 2);
      expect(events.single['practiceOnly'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'area construction accepts keyboard and tap cells and restores them',
    (tester) async {
      _compact(tester);
      final events = <Map<String, dynamic>>[];
      final round = generateAreaRound(1, _seed);
      final cells = (round.config['exampleCells'] as List).cast<String>();
      await _open(
        tester,
        'area_studio',
        1,
        german: false,
        onCompleted: events.add,
      );
      final first = find.byKey(ValueKey('kompass_cell_${cells.first}'));
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      final label =
          find.descendant(of: first, matching: find.byType(Text)).first;
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect((_state(tester)['response'] as Map)['cells'], [cells.first]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app('area_studio', german: false, onCompleted: events.add),
      );
      await tester.pumpAndSettle();
      expect((_state(tester)['response'] as Map)['cells'], [cells.first]);
      for (final cell in cells.skip(1)) {
        await _tap(tester, 'kompass_cell_$cell');
      }
      await _tap(tester, 'lab_check');
      expect(events, hasLength(1));
      expect(events.single['awardedPoints'], 3);
      expect(
        (events.single['finalResponse'] as Map)['cells'],
        unorderedEquals(cells),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
