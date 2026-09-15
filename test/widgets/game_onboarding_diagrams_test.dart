// The onboarding illustrations are the fix for two games held back because
// their boards do not convey their rules, so "it compiles" is not enough --
// these pump each one and check the thing it is supposed to show is on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/widgets/cube_scanner_diagram.dart';
import 'package:space_math_academy/features/games/widgets/void_crossing_diagram.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ));
  await tester.pump();
}

void main() {
  group('Cube Scanner diagrams', () {
    testWidgets('the opposite-pairs diagram shows all three pairs summing to 7',
        (tester) async {
      await _pump(tester, const DieOppositePairsDiagram());
      expect(find.byType(DieFace), findsNWidgets(6));
      expect(find.text('7'), findsNWidgets(3));
      expect(find.text('+'), findsNWidgets(3));
      expect(find.text('='), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hidden-faces diagram derives each hidden value from 7',
        (tester) async {
      await _pump(tester, const DieHiddenFacesDiagram(visible: [2, 3, 1]));
      expect(find.byType(DieFace), findsNWidgets(6));
      // The subtraction is spelled out, so a hidden value never looks guessed.
      expect(find.text('7−2'), findsOneWidget);
      expect(find.text('7−3'), findsOneWidget);
      expect(find.text('7−1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every die value 1..6 draws without error', (tester) async {
      for (int v = 1; v <= 6; v++) {
        await _pump(tester, DieFace(value: v));
        expect(tester.takeException(), isNull, reason: 'value $v');
      }
    });
  });

  group('Void Crossing diagrams', () {
    testWidgets('the conflict diagram contrasts left-alone with supervised',
        (tester) async {
      await _pump(tester, const VoidConflictDiagram(predator: '🦎', prey: '🐛'));
      // The same pair appears in both situations -- that is the point: the
      // only thing that changed is who is watching.
      expect(find.text('🦎'), findsNWidgets(2));
      expect(find.text('🐛'), findsNWidgets(2));
      // The shuttle is present in exactly one of the two.
      expect(find.text('🚀'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shuttle diagram shows one seat per unit of capacity',
        (tester) async {
      for (final capacity in [1, 2, 3]) {
        await _pump(tester, VoidShuttleDiagram(capacity: capacity));
        expect(find.byIcon(Icons.add), findsNWidgets(capacity),
            reason: 'capacity $capacity');
        // And that the pilot always travels.
        expect(find.text('🚀'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
