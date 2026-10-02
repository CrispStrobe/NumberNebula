import 'dart:convert';
import 'dart:io';

/// Summaries describe variation within sampled boards, not uncertainty about children.
List<Map<String, dynamic>> summarizeCalibration(
    List<Map<String, dynamic>> cases,
    {bool stratified = false}) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in cases) {
    final square = row['game'] == 'arithmatic_square'
        ? '/${row['squarePath'] ?? 'pruned'}'
        : '';
    final suffix = stratified ? '/${row['mechanic']}/${row['language']}' : '';
    final key =
        '${row['game']}/${row['grade']}/${row['level']}/${row['algorithm']}$square$suffix';
    groups.putIfAbsent(key, () => []).add(row);
  }
  num? percentile(Iterable<num> values, double fraction) {
    final sorted = values.toList()..sort();
    return sorted.isEmpty
        ? null
        : sorted[((sorted.length - 1) * fraction).round()];
  }

  return [
    for (final rows in groups.values)
      {
        'game': rows.first['game'],
        'grade': rows.first['grade'],
        'level': rows.first['level'],
        'algorithm': rows.first['algorithm'],
        if (rows.first['game'] == 'arithmatic_square')
          'squarePath': rows.first['squarePath'] ?? 'pruned',
        if (stratified) 'mechanic': rows.first['mechanic'],
        if (stratified) 'language': rows.first['language'],
        'samples': rows.length,
        if (stratified) 'needsMoreSamples': rows.length < 10,
        'validEstimates': rows.where((r) => r['feltDifficulty'] is Map).length,
        for (final scenario in ['novice', 'fluent'])
          '${scenario}Score': {
            for (final q in {'p10': 0.1, 'median': 0.5, 'p90': 0.9}.entries)
              q.key: percentile(
                  rows.where((r) => r['feltDifficulty'] is Map).map(
                      (r) => r['feltDifficulty']['${scenario}Score'] as num),
                  q.value)
          },
        for (final field in [
          'generationMs',
          'hintMedianUs',
          'referenceMoves',
          'hiddenCells'
        ])
          '${field}Median':
              percentile(rows.map((r) => r[field]).whereType<num>(), 0.5),
        'noviceBands': {
          for (final band in ['light', 'moderate', 'stretch', 'heavy'])
            band: rows
                .where((r) => r['feltDifficulty']?['noviceBand'] == band)
                .length
        },
      }
  ];
}

void writeCalibrationTable(File output, List<Map<String, dynamic>> groups) {
  String cell(Object? value) =>
      '"${(value ?? '').toString().replaceAll('"', '""')}"';
  final lines = <List<Object?>>[
    [
      'game',
      'grade',
      'level',
      'algorithm',
      'square_path',
      'samples',
      'valid_estimates',
      'novice_p10',
      'novice_median',
      'novice_p90',
      'fluent_median',
      'generation_ms_median',
      'reference_moves_median',
      'hidden_cells_median'
    ],
    for (final row in groups)
      [
        row['game'],
        row['grade'],
        row['level'],
        row['algorithm'],
        row['squarePath'],
        row['samples'],
        row['validEstimates'],
        row['noviceScore']['p10'],
        row['noviceScore']['median'],
        row['noviceScore']['p90'],
        row['fluentScore']['median'],
        row['generationMsMedian'],
        row['referenceMovesMedian'],
        row['hiddenCellsMedian']
      ]
  ];
  output.writeAsStringSync(
      '${lines.map((r) => r.map(cell).join(',')).join('\n')}\n',
      encoding: utf8);
}
