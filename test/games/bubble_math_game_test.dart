// Tests for the public, plugin-free pieces of bubble_math_game.dart.
//
// The screen's game logic (_generateBubbles, _onBubbleTapped, the game
// timer, win/lose dialogs) lives in the private State class and is bound
// to a live BuildContext + GameProvider + an infinitely-repeating
// AnimationController + Timer.periodic. Those are not unit-testable
// without a dependency-injection seam (which we are not allowed to add),
// and a full screen pump runs infinite animations.
//
// What IS cleanly testable in isolation:
//   * the `Bubble` mutable model (mutation semantics used by the physics
//     update loop), and
//   * the `BubbleWidget` stateless widget, which depends ONLY on a Bubble
//     and a tap callback — no providers, no plugins, no localization.
// We exercise both here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/bubble_math_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

Bubble _makeBubble({
  int id = 0,
  String mathProblem = '6',
  int answer = 6,
  Offset position = const Offset(100, 100),
  Offset velocity = const Offset(10, -10),
  Color color = Colors.cyan,
  double size = 90,
}) {
  return Bubble(
    id: id,
    mathProblem: mathProblem,
    answer: answer,
    position: position,
    velocity: velocity,
    color: color,
    size: size,
  );
}

Widget _wrap(Widget child) {
  // BubbleWidget uses Positioned, so it must live inside a Stack.
  // Include localization delegates so S.of(context) works.
  return MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: Scaffold(
      body: Stack(children: [child]),
    ),
  );
}

void main() {
  group('Bubble model', () {
    test('stores constructor values and exposes them', () {
      final b = _makeBubble(
        id: 3,
        mathProblem: '2 + 2',
        answer: 4,
        position: const Offset(50, 60),
        velocity: const Offset(5, 5),
        size: 110,
      );

      expect(b.id, 3);
      expect(b.mathProblem, '2 + 2');
      expect(b.answer, 4);
      expect(b.position, const Offset(50, 60));
      expect(b.velocity, const Offset(5, 5));
      expect(b.size, 110);
    });

    test('mutable fields support the physics update used by the game loop',
        () {
      final b = _makeBubble(position: const Offset(0, 0),
          velocity: const Offset(60, -60));

      // Mirror _updateBubblePositions: position += velocity * 0.016.
      b.position += b.velocity * 0.016;
      expect(b.position.dx, closeTo(60 * 0.016, 1e-9));
      expect(b.position.dy, closeTo(-60 * 0.016, 1e-9));

      // Wall-bounce inverts a velocity component.
      b.velocity = Offset(-b.velocity.dx, b.velocity.dy);
      expect(b.velocity.dx, -60);
      expect(b.velocity.dy, -60);
    });
  });

  group('BubbleWidget', () {
    testWidgets('renders the math problem text', (tester) async {
      final b = _makeBubble(mathProblem: '7 x 3', answer: 21);

      await tester.pumpWidget(
        _wrap(BubbleWidget(bubble: b, onTapped: () {})),
      );
      await tester.pump();

      expect(find.text('7 x 3'), findsOneWidget);
    });

    testWidgets('exposes an accessible button label', (tester) async {
      final b = _makeBubble(mathProblem: '12', answer: 12);

      await tester.pumpWidget(
        _wrap(BubbleWidget(bubble: b, onTapped: () {})),
      );
      await tester.pump();

      // BubbleWidget wraps its content in a Semantics node carrying a
      // button label derived from the math problem.
      final semanticsWidget = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(BubbleWidget),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semanticsWidget.properties.label, 'Bubble 12');
      expect(semanticsWidget.properties.button, isTrue);
    });

    testWidgets('fires onTapped when tapped', (tester) async {
      var taps = 0;
      final b = _makeBubble();

      await tester.pumpWidget(
        _wrap(BubbleWidget(bubble: b, onTapped: () => taps++)),
      );
      await tester.pump();

      await tester.tap(find.text('6'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('positions itself centred on bubble.position', (tester) async {
      const pos = Offset(150, 200);
      const size = 100.0;
      final b = _makeBubble(position: pos, size: size);

      await tester.pumpWidget(
        _wrap(BubbleWidget(bubble: b, onTapped: () {})),
      );
      await tester.pump();

      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      // BubbleWidget offsets left/top by half the size so the circle is
      // centred on the logical position.
      expect(positioned.left, pos.dx - size / 2);
      expect(positioned.top, pos.dy - size / 2);
    });
  });
}
