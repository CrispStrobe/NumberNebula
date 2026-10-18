import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed round audits do not silently skip their acceptance cases',
      () {
    for (final game in [
      'star_forge',
      'chrono_repair',
      'orbital_towers',
      'arithmatic_square',
      'alien_tribunal',
      'arithmancer_crosswords',
      'kenken',
      'magic_triangles',
      'number_walls',
      'hive_station',
      'xenobiology_lab',
    ]) {
      final path = 'test/widgets/${game}_round_test.dart';
      expect(RegExp(r'\bskip\s*:').hasMatch(File(path).readAsStringSync()),
          isFalse,
          reason: '$path: repair acceptance failures instead of hiding them');
    }
  });
}
