import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/widgets/round_summary.dart';
import 'support/round_dialog_finder.dart';

void main() {
  testWidgets('counts a subclass and a nested styling wrapper as one surface',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: ScrollableRoundDialog(child: const Text('result'))));
    expect(roundDialogs, findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home:
            Dialog(child: ScrollableRoundDialog(child: const Text('result')))));
    expect(roundDialogs, findsOneWidget);
  });
  testWidgets('does not conceal two independent dialog surfaces',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
      const Dialog(child: Text('one')),
      ScrollableRoundDialog(child: const Text('two')),
    ])));
    expect(roundDialogs, findsNWidgets(2));
  });
}
