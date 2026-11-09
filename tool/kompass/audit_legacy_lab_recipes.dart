import 'dart:convert';
import 'dart:io';

import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';

const _baselineCommit = '8971225b9c435867fa5f8fa4e20e98e3baa24fce';
const _variants = {
  'number_dock': ['buildNumber', 'regroup', 'numberLine'],
  'supply_station': ['shopping', 'elapsed', 'capacity', 'length'],
  'data_observatory': ['buildChart', 'chance', 'event'],
  'geometry_workshop': ['axes', 'cubeNet', 'sideView'],
};

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _checkData(KompassLabCheck check) => {
  'points': check.points,
  'maxPoints': check.maxPoints,
  'correct': check.correct,
  'feedbackDe': check.feedbackDe,
  'feedbackEn': check.feedbackEn,
};

Map<String, dynamic> _snapshot(
  String labId,
  KompassLabRound round,
  List<Map<String, dynamic>> probes,
) {
  final defaults = round.createResponse();
  return {
    'labTitleDe': kompassLabTitle(labId, true),
    'labTitleEn': kompassLabTitle(labId, false),
    'type': round.type,
    'skillIds': round.skillIds,
    'config': round.config,
    'titleDe': round.titleDe,
    'titleEn': round.titleEn,
    'promptDe': round.promptDe,
    'promptEn': round.promptEn,
    'solutionDe': round.solutionDe,
    'solutionEn': round.solutionEn,
    'hintsDe': round.hintsDe,
    'hintsEn': round.hintsEn,
    'defaultResponse': defaults,
    'normalizedDefaultResponse': round.normalizeResponse(_copyMap(defaults)),
    'defaultCheck': _checkData(round.check(_copyMap(defaults))),
    'responseChecks': [
      for (final probe in probes)
        {
          'label': probe['label'],
          'response': _copyMap(probe['response'] as Map<String, dynamic>),
          'normalizedResponse': round.normalizeResponse(
            _copyMap(probe['response'] as Map<String, dynamic>),
          ),
          'check': _checkData(round.check(
            _copyMap(probe['response'] as Map<String, dynamic>),
          )),
          'normalizedCheck': _checkData(round.check(round.normalizeResponse(
            _copyMap(probe['response'] as Map<String, dynamic>),
          ))),
        },
    ],
  };
}

String _describe(Object? value) {
  final encoded = jsonEncode(value);
  return encoded.length <= 180 ? encoded : '${encoded.substring(0, 177)}...';
}

/// Map ordering is immaterial; list order, numeric types and text are exact.
void _compare(
  Object? expected,
  Object? actual,
  String path,
  List<String> differences,
) {
  if (differences.length >= 20) return;
  if (expected is Map && actual is Map) {
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) {
        differences.add('$path.$key: missing field');
      } else {
        _compare(expected[key], actual[key], '$path.$key', differences);
      }
      if (differences.length >= 20) return;
    }
    for (final key in actual.keys) {
      if (!expected.containsKey(key)) {
        differences.add('$path.$key: unexpected field');
      }
      if (differences.length >= 20) return;
    }
    return;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      differences.add('$path: expected ${expected.length} items, '
          'received ${actual.length}');
    }
    final count = expected.length < actual.length
        ? expected.length
        : actual.length;
    for (var index = 0; index < count; index++) {
      _compare(expected[index], actual[index], '$path[$index]', differences);
      if (differences.length >= 20) return;
    }
    return;
  }
  final numericTypeChanged = expected is num && actual is num &&
      expected.runtimeType != actual.runtimeType;
  if (expected != actual || numericTypeChanged) {
    differences.add('$path: expected ${_describe(expected)}, '
        'received ${_describe(actual)}'
        '${numericTypeChanged ? ' (numeric type changed)' : ''}');
  }
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String _caseKey(String labId, int seed, int index) => '$labId/$seed/$index';

/// Frozen outputs were captured from the public baseline commit in a detached
/// worktree, never from the expanded generators. This needs only the Dart VM.
/// An optional fixture path supports reviewing intentionally versioned recipes.
void main(List<String> args) {
  _require(args.length <= 1, 'Usage: audit_legacy_lab_recipes.dart [fixture.json]');
  final file = args.isEmpty
      ? File.fromUri(Platform.script.resolve('baselines/lab_recipes_v1.json'))
      : File(args.single);
  final fixture = Map<String, dynamic>.from(
    jsonDecode(file.readAsStringSync()) as Map,
  );
  _require(fixture['schemaVersion'] == 1, 'Unknown legacy fixture schema');
  final source = fixture['source'] as Map;
  _require(source['repository'] == 'CrispStrobe/NumberNebula' &&
      source['commit'] == _baselineCommit &&
      source['path'] == 'lib/features/kompass/labs/kompass_lab_round.dart',
      'The legacy fixture must remain pinned to $_baselineCommit');

  final expectedKeys = <String>{
    for (final entry in _variants.entries)
      for (final seed in [0, 417])
        for (final base in [0, 120])
          for (var variant = 0; variant < entry.value.length; variant++)
            _caseKey(entry.key, seed, base + variant),
    // Covers the fourth missing-square alternative in the original cube net.
    _caseKey('geometry_workshop', 3, 1),
  };
  final cases = (fixture['cases'] as List).cast<Map>();
  _require(fixture['caseCount'] == 53 && cases.length == 53 &&
      cases.length == expectedKeys.length, 'Expected all 53 frozen recipe cases');
  final seen = <String>{};
  final seenTypes = <String>{};
  final differences = <String>[];
  var scoringResults = 0;
  for (final item in cases) {
    final labId = item['labId'] as String;
    final seed = item['seed'] as int;
    final index = item['index'] as int;
    final key = _caseKey(labId, seed, index);
    _require(expectedKeys.contains(key) && seen.add(key),
        'Unexpected or repeated frozen case $key');
    final expected = Map<String, dynamic>.from(item['round'] as Map);
    final type = expected['type'] as String;
    final variants = _variants[labId]!;
    _require(type == variants[index % variants.length],
        'Frozen variant identity was changed for $key');
    seenTypes.add(type);
    final probes = (expected['responseChecks'] as List)
        .map((probe) => Map<String, dynamic>.from(probe as Map))
        .toList();
    final expectedLabels = {
      'solved', 'changed',
      if (type == 'capacity') 'alternate_valid',
      if (type == 'shopping') 'wrong_unit',
    };
    _require(probes.length == expectedLabels.length &&
        probes.map((probe) => probe['label']).toSet().containsAll(expectedLabels),
        'Frozen scoring probes were changed for $key');
    _require((probes.singleWhere((p) => p['label'] == 'solved')['check'] as Map)
        ['correct'] == true, 'Baseline solved response must succeed for $key');
    _require((probes.singleWhere((p) => p['label'] == 'changed')['check'] as Map)
        ['correct'] == false, 'Baseline changed response must fail for $key');
    final actual = _snapshot(
      labId,
      generateKompassLabRound(labId, index, seed, recipe: 1),
      probes,
    );
    _compare(expected, actual, key, differences);
    scoringResults += 1 + 2 * probes.length;
  }
  _require(seen.length == expectedKeys.length && seenTypes.length == 13,
      'Missing an original lab variant or later-index case');
  if (differences.isNotEmpty) {
    throw StateError('Legacy recipes changed from $_baselineCommit:\n'
        '${differences.join('\n')}');
  }
  stdout.writeln('Legacy lab recipe audit passed: ${cases.length} frozen cases, '
      '${seenTypes.length} variants, $scoringResults scoring results '
      'against ${_baselineCommit.substring(0, 7)}.');
}
