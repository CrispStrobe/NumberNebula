import 'dart:convert';

List<Map<String, dynamic>> parseMoleculeLevels(String source) {
  final levels = (jsonDecode(source) as Map<String, dynamic>)['levels'] as List;
  List<List<Map<String, dynamic>>> grid(List rows) => [
        for (final row in rows.cast<List>())
          [
            for (final cell in row.cast<List>())
              {'type': cell[0] as String, 'index': cell[1] as int},
          ],
      ];
  return [
    for (final level in levels.cast<Map<String, dynamic>>())
      {
        ...level,
        'playfield': grid(level['playfield'] as List),
        'solution': grid(level['solution'] as List),
      },
  ];
}
