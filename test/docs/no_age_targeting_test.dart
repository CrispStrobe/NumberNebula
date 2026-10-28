import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// NumberNebula is for math learners of all ages. App Review rejected 1.4.10
// under guideline 2.3.8 for a "for kids" subtitle, and the app must not state
// an age range or a child/school audience anywhere a player can read it.
// Privacy wording that says the app is *safe* for children is allowed.
void main() {
  final banned = <RegExp>[
    RegExp(r'\d+\s*[-–]\s*\d+\s*(years|jahre)', caseSensitive: false),
    RegExp(r'\b(ages?|alter)\s+\d', caseSensitive: false),
    RegExp(r'\b(grades?|klassen?)\s+\d', caseSensitive: false),
    RegExp(r'\bfor (kids|children)\b', caseSensitive: false),
    RegExp(r'\bfür kinder\b', caseSensitive: false),
    RegExp(r'\bdesigned for children\b', caseSensitive: false),
    RegExp(r'primary[- ]school|grundschul', caseSensitive: false),
    RegExp(r'young learners|junge lernende', caseSensitive: false),
    RegExp(r'\byour child\b|\bdein kind\b|\bihr kind\b', caseSensitive: false),
  ];

  final files = <String>[
    'lib/l10n/app_en.arb',
    'lib/l10n/app_de.arb',
    'lib/shared/widgets/privacy_policy_dialog.dart',
    'web/index.html',
    'web/manifest.json',
    'web/privacy.html',
    for (final dir in ['fastlane/metadata/en-US', 'fastlane/metadata/de-DE'])
      for (final f in Directory(dir).listSync().whereType<File>())
        if (f.path.endsWith('.txt')) f.path,
  ];

  for (final path in files) {
    test('$path states no age range or child audience', () {
      final text = File(path).readAsStringSync();
      final hits = [
        for (final pattern in banned)
          for (final m in pattern.allMatches(text)) m.group(0),
      ];
      expect(hits, isEmpty);
    });
  }
}
