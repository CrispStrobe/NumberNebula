// Logic test: internal integrity of gameSkillMap.
//
// Focus is the map's self-consistency — not menu coverage (a separate
// contract test, test/contracts/menu_game_keys_test.dart, handles that).
// We assert: non-empty, keys well-formed/unique, every value is a valid
// SkillCategory, and every declared SkillCategory is actually exercised.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/models/skill_category.dart';

void main() {
  group('gameSkillMap integrity', () {
    test('is non-empty', () {
      expect(gameSkillMap, isNotEmpty);
    });

    test('every value is a valid SkillCategory', () {
      for (final entry in gameSkillMap.entries) {
        expect(
          SkillCategory.values,
          contains(entry.value),
          reason: 'Key "${entry.key}" maps to an unknown SkillCategory.',
        );
      }
    });

    test('keys are non-empty, trimmed, and unique', () {
      // A Dart map literal cannot contain duplicate const keys at the language
      // level, but this guards against accidental near-duplicates (whitespace)
      // and empty keys that would silently break lookups.
      for (final key in gameSkillMap.keys) {
        expect(key, isNotEmpty, reason: 'Found an empty game key.');
        expect(key, equals(key.trim()),
            reason: 'Key "$key" has leading/trailing whitespace.');
      }
      expect(gameSkillMap.keys.toSet().length, equals(gameSkillMap.length),
          reason: 'Duplicate keys detected in gameSkillMap.');
    });

    test('every SkillCategory enum value is used at least once', () {
      final used = gameSkillMap.values.toSet();
      final unused =
          SkillCategory.values.where((c) => !used.contains(c)).toList();
      expect(unused, isEmpty,
          reason: 'Declared SkillCategory value(s) never mapped: $unused. '
              'Either map a game to them or remove the enum value.');
    });
  });
}
