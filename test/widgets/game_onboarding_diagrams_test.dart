// The onboarding illustrations are the fix for two games held back because
// their boards do not convey their rules, so "it compiles" is not enough --
// these pump each one and check the thing it is supposed to show is on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/widgets/cube_scanner_diagram.dart';
import 'package:space_math_academy/features/games/widgets/star_forge_diagram.dart';
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
      await _pump(
          tester,
          const DieHiddenFacesDiagram(
            scannedLabel: 'scanned',
            hiddenLabel: 'hidden',
            visible: [2, 3, 1],
          ));
      expect(find.byType(DieFace), findsNWidgets(6));
      // The subtraction is spelled out, so a hidden value never looks guessed.
      expect(find.text('7−2'), findsOneWidget);
      expect(find.text('7−3'), findsOneWidget);
      expect(find.text('7−1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the totals diagram shows where 21, 42 and 63 come from',
        (tester) async {
      await _pump(tester, const DieTotalPipsDiagram());
      // All six faces, plus the small cube glyph on each of the three tallies.
      expect(find.byType(DieFace), findsNWidgets(9));
      expect(find.text('7 + 7 + 7 = 21'), findsOneWidget);
      expect(find.text(' = 42'), findsOneWidget);
      expect(find.text(' = 63'), findsOneWidget);
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

  group('Star Forge diagrams', () {
    // The example is a solved 5-point star holding 1..10, so every number is
    // on screen exactly once and every arm shown really does total 22. If the
    // layout ever stops agreeing with the puzzle the numbers stop adding up,
    // which is the whole reason the example is drawn from the real geometry.
    testWidgets('the arm diagram spells out one arm and its total',
        (tester) async {
      await _pump(tester, const StarForgeArmDiagram());
      for (int v = 1; v <= 10; v++) {
        expect(find.text('$v'), findsOneWidget, reason: 'node $v');
      }
      expect(find.text('1 + 10 + 9 + 2 = 22'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the overlap diagram shows two arms at the same total',
        (tester) async {
      await _pump(tester, const StarForgeOverlapDiagram());
      // One badge per arm named, both reading 22 -- the point being that the
      // two arms share nodes and still agree.
      expect(find.text('22'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the goal diagram totals every arm and leaves two nodes open',
        (tester) async {
      await _pump(tester, const StarForgeGoalDiagram());
      expect(find.text('22'), findsNWidgets(5));
      expect(find.byIcon(Icons.add), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
