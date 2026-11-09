// Strings added after playing Star Forge and Cube Scanner to a win: Star
// Forge's move budget was an unlabelled number, and a wrong Cube Scanner
// answer ended the round without saying why.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  test('English', () async {
    final s = await S.delegate.load(const Locale('en'));
    expect(s.starForgeMovesLeft(1), '1 move left');
    expect(s.starForgeMovesLeft(4), '4 moves left');
    expect(s.cubeScannerWhyHiddenFace(5, 2), 'Opposite faces add up to 7: 7 − 5 = 2.');
    expect(s.cubeScannerWhyHiddenSum(12, 9), contains('21 − 12 = 9'));
  });

  test('German', () async {
    final s = await S.delegate.load(const Locale('de'));
    expect(s.starForgeMovesLeft(1), 'Noch 1 Zug');
    expect(s.starForgeMovesLeft(4), 'Noch 4 Züge');
    expect(s.cubeScannerWhyHiddenFace(5, 2), contains('7 − 5 = 2'));
    expect(s.cubeScannerWhyHiddenSum(12, 9), contains('21 − 12 = 9'));
  });
}
