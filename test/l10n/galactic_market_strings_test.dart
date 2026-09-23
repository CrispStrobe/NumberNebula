// The Galactic Market confirm button used to be a hardcoded English string
// ("Each hidden coin = 1 credits"), so German players saw English and the
// singular was wrong in both languages.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  test('English confirm text agrees with the number', () async {
    final s = await S.delegate.load(const Locale('en'));
    expect(s.galacticMarketSubmitEach(1), 'Each hidden coin = 1 credit');
    expect(s.galacticMarketSubmitEach(5), 'Each hidden coin = 5 credits');
    expect(s.galacticMarketSelectDenom, 'Select a denomination');
  });

  test('German confirm text is German and agrees with the number', () async {
    final s = await S.delegate.load(const Locale('de'));
    expect(s.galacticMarketSubmitEach(1), 'Jede verdeckte Münze = 1 Credit');
    expect(s.galacticMarketSubmitEach(10), 'Jede verdeckte Münze = 10 Credits');
    expect(s.galacticMarketSelectDenom, 'Wähle einen Nennwert');
  });
}
