// Guard against English text hardcoded into screens instead of the ARB files.
//
// Grid Filler shipped to German-speaking children with its title, win dialog,
// score line, instructions and piece tray all in English -- and its German
// title was sitting unused in the ARB the whole time. Anomaly Scan's failure
// dialog was the same, and two more carried a "// TODO: Add to L10n" comment
// that nothing ever acted on. A comment is not a reminder; a failing test is.
//
// Scope is deliberately "text the player can read": Text(...) and the widget
// properties that render a Text. It does not try to catch every string in the
// codebase, because most of them are keys, asset paths and debug output, and a
// check that cries wolf gets suppressed rather than fixed.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Files exempt from the check, each with the reason it is exempt.
const Map<String, String> _exempt = {
  // The debug menu is reachable only by tapping the title seven times; it is
  // a developer tool and is deliberately English-only.
  'lib/features/games/widgets/debug_panel.dart': 'developer-only debug menu',
  // The level editor is a developer tool, not a shipped game.
  'lib/features/games/screens/star_loader_game.dart': 'developer level editor',
};

/// Single sites exempt from the check: file path -> the literal text.
const Map<String, Set<String>> _exemptStrings = {
  // Shown only when DebugProvider.isDebugMenuEnabled, for rating generated
  // puzzles during development.
  'lib/features/games/screens/space_station_gridlock_game.dart': {
    'Rate this puzzle',
  },
};

void main() {
  test('no player-visible English is hardcoded outside the ARB files', () {
    // A Dart string literal in either quote style, allowing escapes so that
    // text containing an apostrophe is matched too -- an earlier version of
    // this sweep excluded those and missed "You've run out of attempts".
    const lit = r"""(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")""";
    final displayed = RegExp(
      r'(?:Text\(\s*(?:const\s+)?|'
      r'(?:label|title|content|tooltip|semanticLabel|hintText|labelText)'
      r'\s*:\s*(?:const\s+)?Text\(\s*)($lit)'.replaceAll(r'$lit', lit),
    );
    // Either branch of a conditional passed straight to Text: the pattern
    // above only sees a literal right after the parenthesis, so
    // `Text(x ? 'Each hidden coin = $n credits' : 'Select a denomination')`
    // slipped through and shipped English to German players.
    final conditional = RegExp(
      r'Text\(\s*(?:const\s+)?[^;(){}]*?\?\s*($lit)\s*:\s*($lit)'
          .replaceAll(r'$lit', lit),
    );
    // Prose: two words, or a single capitalised word. Keeps symbols, numbers
    // and interpolation-only strings out of the results.
    final prose = RegExp(r'[A-Za-z]{3,}\s+[A-Za-z]{2,}|^[A-Z][a-z]{3,}$');

    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      if (_exempt.containsKey(path)) continue;

      final src = entity.readAsStringSync();
      final found = [
        for (final m in displayed.allMatches(src)) (m.start, m.group(1)!),
        for (final m in conditional.allMatches(src)) ...[
          (m.start, m.group(1)!),
          (m.start, m.group(2)!),
        ],
      ];
      for (final (start, raw) in found) {
        final text = raw.substring(1, raw.length - 1);
        if (_exemptStrings[path]?.contains(text) ?? false) continue;
        // Interpolation with no prose of its own is a value, not a sentence.
        if (text.contains(r'$') && !RegExp(r'[A-Za-z]{3,}\s').hasMatch(text)) {
          continue;
        }
        if (!prose.hasMatch(text)) continue;
        final line = '\n'.allMatches(src.substring(0, start)).length + 1;
        offenders.add('  $path:$line\n      "$text"');
      }
    }

    expect(offenders, isEmpty,
        reason: 'Hardcoded player-visible text — add it to lib/l10n/app_en.arb '
            'and app_de.arb and read it through S.of(context):\n'
            '${offenders.join('\n')}');
  });
}
