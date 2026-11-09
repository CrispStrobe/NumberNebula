import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/missions/data/game_pool.dart';

/// REMAINING_WORK.md summarises [debugOnlyGames], and a summary drifts.
///
/// It did: three games stayed listed as "Not started" for three commits after
/// they were fixed, so the document said there was work outstanding that had
/// already been done. `game_pool.dart` is the source of truth -- this only
/// checks the summary still agrees with it.
void main() {
  late String doc;

  setUpAll(() {
    doc = File('REMAINING_WORK.md').readAsStringSync();
  });

  test('every gated game is listed in REMAINING_WORK.md', () {
    final missing = debugOnlyGames.where((k) => !doc.contains('`$k`')).toList();
    expect(
      missing,
      isEmpty,
      reason: 'gated in game_pool.dart but absent from REMAINING_WORK.md: $missing',
    );
  });

  test('REMAINING_WORK.md does not list games that have shipped', () {
    // The table's rows carry a `key` in backticks. Any key mentioned in the
    // withheld-games section must still actually be withheld, or the document
    // is telling a reader a shipped game is broken.
    final section = doc.substring(
      doc.indexOf('### Games withheld from players'),
      doc.indexOf('### Fixed and shipping'),
    );
    final listed = RegExp(r'`([a-z_]+)`')
        .allMatches(section)
        .map((m) => m.group(1)!)
        .where((k) => k != 'debugOnlyGames' && k != 'game_pool')
        .toSet();
    final shipped = listed.difference(debugOnlyGames).toList();
    expect(
      shipped,
      isEmpty,
      reason: 'listed as withheld but no longer gated: $shipped',
    );
  });

  test('the gate carries a reason for every key', () {
    // Each key in debugOnlyGames has a comment above it saying why. A key added
    // without one leaves the next person no way to know what to verify.
    final src = File('lib/features/missions/data/game_pool.dart').readAsStringSync();
    final block = src.substring(
      src.indexOf('const Set<String> debugOnlyGames'),
      src.indexOf('};', src.indexOf('const Set<String> debugOnlyGames')),
    );
    for (final key in debugOnlyGames) {
      final at = block.indexOf("'$key'");
      expect(at, greaterThan(0), reason: '$key not found in the literal');
      final before = block.substring(0, at);
      expect(
        before.trimRight().endsWith('.') || before.contains('//'),
        isTrue,
        reason: '$key has no comment explaining why it is gated',
      );
    }
  });
}
