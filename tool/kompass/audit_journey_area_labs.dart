import 'dart:convert';
import 'dart:io';

import 'package:space_math_academy/features/kompass/labs/extensions/area_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/journey_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';

var _checks = 0;

void require(bool condition, String message) {
  _checks++;
  if (!condition) throw StateError(message);
}

/// Independent cell-complex calculation: edge multiplicities give perimeter,
/// union/find gives connectivity, and Euler characteristic detects holes.
({int cells, int boundary, bool connected, bool holeFree}) geometry(
  List<String> ids,
) {
  final cells = ids
      .map((id) {
        final values = id.split(',').map(int.parse).toList();
        return (values[0], values[1]);
      })
      .toSet()
      .toList();
  final edges = <String, int>{};
  final vertices = <(int, int)>{};
  final parents = List.generate(cells.length, (index) => index);
  int root(int index) {
    while (parents[index] != index) {
      index = parents[index];
    }
    return index;
  }

  for (var index = 0; index < cells.length; index++) {
    final (row, col) = cells[index];
    vertices.addAll({
      (row, col),
      (row + 1, col),
      (row, col + 1),
      (row + 1, col + 1),
    });
    for (final edge in [
      'h:$row,$col',
      'h:${row + 1},$col',
      'v:$row,$col',
      'v:$row,${col + 1}',
    ]) {
      edges.update(edge, (count) => count + 1, ifAbsent: () => 1);
    }
    for (var other = 0; other < index; other++) {
      final cell = cells[other];
      if ((row - cell.$1).abs() + (col - cell.$2).abs() == 1) {
        parents[root(index)] = root(other);
      }
    }
  }
  final connected = cells.isNotEmpty &&
      {for (var index = 0; index < cells.length; index++) root(index)}.length ==
          1;
  return (
    cells: cells.length,
    boundary: edges.values.where((count) => count == 1).length,
    connected: connected,
    holeFree: connected && vertices.length - edges.length + cells.length == 1,
  );
}

KompassLabRound construction(int area, int perimeter) => KompassLabRound(
      type: 'area_construct',
      skillIds: const ['M-R08'],
      config: {
        'rows': 6,
        'cols': 6,
        'sideCm': 1,
        'areaCm2': area,
        'perimeterCm': perimeter,
      },
      titleDe: 'Figur',
      titleEn: 'Shape',
      promptDe: 'Zusammenhängend und ohne Löcher.',
      promptEn: 'Connected and without holes.',
      solutionDe: 'Passt.',
      solutionEn: 'Fits.',
      hintsDe: const [],
      hintsEn: const [],
    );

void main() {
  final bestRows = <String>{};
  var exactReserveCases = 0;
  var scaledAreaCases = 0;
  for (var seed = 0; seed < 40; seed++) {
    final backwards = generateJourneyRound(seed * 2, seed);
    final b = backwards.config;
    final deadline = b['deadline'] as int;
    final reserve = b['reserveMinutes'] as int;
    final walk = b['walkMinutes'] as int;
    final ride = b['rideMinutes'] as int;
    final stop = deadline - reserve - walk;
    final departure = stop - ride;
    require(departure >= 0 && deadline < 1440, 'Backward time leaves one day');
    require(
      checkJourneyRound(backwards, {
        'stopTime': journeyTime(stop),
        'leaveTime': journeyTime(departure),
      }).correct,
      'Independent backwards equation fails at seed $seed',
    );
    require(
      checkJourneyRound(backwards, {
            'stopTime': journeyTime(stop),
            'leaveTime': journeyTime(departure + reserve),
          }).points ==
          1,
      'Reserve must not be omitted',
    );

    final connection = generateJourneyRound(seed * 2 + 1, seed);
    final c = connection.config;
    final platform = (c['startTime'] as int) +
        (c['rideMinutes'] as int) +
        (c['walkMinutes'] as int);
    final firstAllowed = platform + (c['reserveMinutes'] as int);
    final services = (c['services'] as List).cast<Map>();
    final eligible = services
        .where((row) => (row['departure'] as int) >= firstAllowed)
        .toList()
      ..sort(
        (a, b) => (a['departure'] as int).compareTo(b['departure'] as int),
      );
    require(eligible.isNotEmpty, 'No feasible connection');
    final best = eligible.first;
    bestRows.add(best['id'] as String);
    if (best['departure'] == firstAllowed) exactReserveCases++;
    require(
      checkJourneyRound(connection, {
        'platformTime': journeyTime(platform),
        'service': best['id'],
      }).correct,
      'Independent earliest connection fails at seed $seed',
    );
    final wrong = services.firstWhere((row) => row['id'] != best['id']);
    require(
      checkJourneyRound(connection, {
            'platformTime': journeyTime(platform),
            'service': wrong['id'],
          }).points ==
          1,
      'Non-optimal connection must lose its own point',
    );

    final measure = generateAreaRound(seed * 2, seed);
    final m = measure.config;
    final cells = (m['cells'] as List).cast<String>();
    final shape = geometry(cells);
    final side = m['sideCm'] as int;
    if (side == 2) scaledAreaCases++;
    require(
      shape.connected && shape.holeFree,
      'Authored measurement shape invalid',
    );
    require(
      checkAreaRound(measure, {
        'area': '${shape.cells * side * side} cm²',
        'perimeter': '${shape.boundary * side} cm',
      }).correct,
      'Independent scaled geometry fails at seed $seed',
    );
    require(
      checkAreaRound(measure, {
            'area': '${shape.cells * side * side} cm',
            'perimeter': '${shape.boundary * side} cm',
          }).points ==
          1,
      'Length units accepted as square units',
    );

    final build = generateAreaRound(seed * 2 + 1, seed);
    final witness = (build.config['exampleCells'] as List).cast<String>();
    final expected = geometry(witness);
    require(
      expected.connected && expected.holeFree,
      'Construction witness topology',
    );
    require(
      expected.cells == build.config['areaCm2'] &&
          expected.boundary == build.config['perimeterCm'],
      'Construction witness dimensions',
    );
    require(
      checkAreaRound(build, {'cells': witness}).correct,
      'Valid construction witness rejected',
    );
    require(
      !checkAreaRound(build, {
        'cells': [...witness, witness.first],
      }).correct,
      'Duplicate cells accepted',
    );
    for (final round in [backwards, connection, measure, build]) {
      final before = round.createResponse();
      final restored = round.normalizeResponse(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(before)) as Map),
      );
      require(
        jsonEncode(before) == jsonEncode(restored),
        'Default draft round trip',
      );
    }
  }

  require(bestRows.length == 3, 'Best service stays in a fixed row');
  require(exactReserveCases > 0, 'No equality boundary exercised');
  require(scaledAreaCases > 0, 'No square-unit scaling exercised');
  for (final value in ['24:00', '09:60', '9.5', '9,50', '-1:05']) {
    require(
      parseJourneyTime(value) == null,
      'Invalid clock time accepted: $value',
    );
  }
  require(
    parseJourneyTime(' 09.05 Uhr ') == 545,
    'Conventional German clock input',
  );

  const stair = ['0,0', '0,1', '0,2', '1,0', '1,1', '2,0'];
  const longCorner = ['0,0', '0,1', '0,2', '0,3', '1,0', '1,1'];
  final sameTargets = construction(6, 12);
  require(
    checkAreaRound(sameTargets, {'cells': stair}).correct,
    'Valid staircase rejected',
  );
  require(
    checkAreaRound(sameTargets, {'cells': longCorner}).correct,
    'Different valid shape rejected',
  );
  const ring = ['0,0', '0,1', '0,2', '1,0', '1,2', '2,0', '2,1', '2,2'];
  final ringGeometry = geometry(ring);
  require(
    ringGeometry.connected &&
        !ringGeometry.holeFree &&
        ringGeometry.boundary == 16,
    'Independent ring fixture',
  );
  require(
    !checkAreaRound(construction(8, 16), {'cells': ring}).correct,
    'An enclosed hole accepted despite matching dimensions',
  );
  require(
    !checkAreaRound(construction(2, 8), {
      'cells': ['0,0', '1,1'],
    }).correct,
    'Corner-only contact accepted',
  );
  require(
    !checkAreaRound(construction(1, 4), {
      'cells': ['6,0'],
    }).correct,
    'Outside-grid cell accepted',
  );
  stdout.writeln(
    'Journey/area lab audit: $_checks checks across 40 seeds passed.',
  );
}
