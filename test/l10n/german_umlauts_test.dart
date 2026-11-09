// Guard against dropped umlauts in the German translations.
//
// This has been reported four separate times from the running app -- Lugner
// for Lügner, Munzen for Münzen, Hohe for Höhe, and a sweep that turned up
// Rasterfuller, Wurfeldaten, verhullt, zuruckzudrangen, Tauschvorgangen and
// Uberlegene. Every one shipped to German-speaking children. Catching them by
// reading the screen is clearly not working, so catch them here.
//
// The check is word-level and deliberately conservative: it lists forms that
// are only ever wrong in German, and stays away from ones that are legitimate
// words in their own right. "Zahlen" (numbers) is not a broken "zählen", "hohe"
// (tall) is not a broken "Höhe", and "lange" (long) is not a broken "Länge" --
// an earlier version of this sweep flagged all three and the noise buried the
// real defects.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Forms that are always a dropped umlaut in German, never a word themselves.
const Map<String, String> _alwaysWrong = {
  'fuller': 'füller',
  'wurfel': 'würfel',
  'wurfeldaten': 'würfeldaten',
  'verhullt': 'verhüllt',
  'zuruck': 'zurück',
  'zuruckzudrangen': 'zurückzudrängen',
  'tauschvorgangen': 'tauschvorgängen',
  'vorgangen': 'vorgängen',
  'uberlegene': 'überlegene',
  'uberlegen': 'überlegen',
  'uberlappung': 'überlappung',
  'ubertragung': 'übertragung',
  'uberprufe': 'überprüfe',
  'uberein': 'überein',
  'lugner': 'lügner',
  'munzen': 'münzen',
  'mussen': 'müssen',
  'konnen': 'können',
  'wahle': 'wähle',
  'prufe': 'prüfe',
  'losung': 'lösung',
  'loschen': 'löschen',
  'nachste': 'nächste',
  'verfugbar': 'verfügbar',
  'schlussel': 'schlüssel',
  'ratsel': 'rätsel',
  'turme': 'türme',
  'gebaude': 'gebäude',
  'drucke': 'drücke',
  'erklarung': 'erklärung',
  'bestatigen': 'bestätigen',
  'gronsse': 'größe',
  'grosser': 'größer',
  'fur': 'für',
  'stuck': 'stück',
  'lucke': 'lücke',
};

void main() {
  test('no German string has a dropped umlaut', () {
    final arb = jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
        as Map<String, dynamic>;
    final word = RegExp(r'[A-Za-zÄÖÜäöüß]+');
    final problems = <String>[];

    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      for (final m in word.allMatches(value)) {
        final correct = _alwaysWrong[m.group(0)!.toLowerCase()];
        if (correct != null) {
          problems.add('  $key: "${m.group(0)}" should be "$correct"\n'
              '      in: ${value.length > 90 ? '${value.substring(0, 90)}…' : value}');
        }
      }
    });

    expect(problems, isEmpty,
        reason: 'Dropped umlauts in app_de.arb:\n${problems.join('\n')}');
  });

  test('the German and English translations cover the same keys', () {
    // A key present in one file and not the other means someone sees a raw
    // identifier, or an English string, where a translation was intended.
    Set<String> keysOf(String path) =>
        (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();

    final en = keysOf('lib/l10n/app_en.arb');
    final de = keysOf('lib/l10n/app_de.arb');
    expect(en.difference(de), isEmpty, reason: 'keys missing from German');
    expect(de.difference(en), isEmpty, reason: 'keys missing from English');
  });

  test('no German string is left as its English original', () {
    // An untranslated entry is the other half of this bug: the German file
    // has the key, but the value was never translated. Only flags strings with
    // real words in them, so shared tokens (numbers, symbols, product names)
    // do not trip it.
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final de = jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
        as Map<String, dynamic>;

    // Words that are legitimately identical in both languages, or proper nouns.
    final shared = RegExp(
        r'^(OK|Level|Score|Start|Stop|Combo|Bonus|Reset|Info|Modus|Total|'
        r'Solo|Update|Version|Import|Export|Automatik|Standard|E-Mail|App|'
        r'Sensor|Radar|Quiz|Tempo|Basis|Prozent|Faktor|Minute|Sekunde)$',
        caseSensitive: false);


    // Entries that must read the same in both languages, with the reason.
    const identicalOnPurpose = <String>{
      // A postal address is not translated; it has to match the real one.
      'imprintProviderAddress',
      // Proper names of the two stations in the game's fiction.
      'voidCrossingStationAlpha',
      'voidCrossingStationOmega',
    };
    final untranslated = <String>[];
    en.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      final g = de[key];
      if (g is! String || g != value) return;
      if (shared.hasMatch(value.trim())) return;
      if (identicalOnPurpose.contains(key)) return;
      // Needs at least two real words to be worth flagging.
      if (RegExp(r'[A-Za-z]{3,}\s+[A-Za-z]{3,}').hasMatch(value)) {
        untranslated.add('  $key: "$value"');
      }
    });

    expect(untranslated, isEmpty,
        reason: 'English text left in app_de.arb:\n${untranslated.join('\n')}');
  });
}
