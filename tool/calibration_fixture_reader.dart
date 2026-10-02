import 'dart:convert';

/// Decode one board at a time so large captures do not retain every game state.
Stream<Map<String, dynamic>> decodeCalibrationFixtures(Stream<List<int>> bytes,
    {String source = 'fixtures'}) async* {
  var lineNumber = 0;
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    lineNumber++;
    if (line.trim().isEmpty) continue;
    try {
      final value = jsonDecode(line);
      if (value is! Map) throw const FormatException('Expected a board object');
      yield Map<String, dynamic>.from(value);
    } on FormatException catch (error) {
      throw FormatException('$source:$lineNumber: ${error.message}');
    }
  }
}
