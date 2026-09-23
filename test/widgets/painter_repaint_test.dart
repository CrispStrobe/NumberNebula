// Painters that take a colour or shape must repaint when it changes, or a
// reused CustomPaint keeps showing the old drawing. They used to return
// false unconditionally.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/planet_hopping_game.dart'
    as hopping;
import 'package:space_math_academy/features/games/widgets/arithmancer_duel_effects.dart';
import 'package:space_math_academy/features/games/widgets/hyperdrive_gates_world.dart'
    as hyperdrive;

void main() {
  test('planet hopping surface repaints only for a new colour', () {
    final red = hopping.PlanetSurfacePainter(Colors.red);
    expect(red.shouldRepaint(hopping.PlanetSurfacePainter(Colors.red)), isFalse);
    expect(red.shouldRepaint(hopping.PlanetSurfacePainter(Colors.blue)), isTrue);
  });

  test('duel card pattern repaints only for a new colour', () {
    final red = CardPatternPainter(color: Colors.red);
    expect(red.shouldRepaint(CardPatternPainter(color: Colors.red)), isFalse);
    expect(red.shouldRepaint(CardPatternPainter(color: Colors.blue)), isTrue);
  });

  test('hyperdrive planet surface repaints only for a new colour', () {
    final red = hyperdrive.PlanetSurfacePainter(color: Colors.red);
    expect(red.shouldRepaint(hyperdrive.PlanetSurfacePainter(color: Colors.red)),
        isFalse);
    expect(red.shouldRepaint(hyperdrive.PlanetSurfacePainter(color: Colors.blue)),
        isTrue);
  });

  test('hyperdrive asteroid repaints only for a new shape', () {
    final shape = Path()..addOval(const Rect.fromLTWH(0, 0, 40, 40));
    final painter = hyperdrive.AsteroidPainter(shape: shape);
    expect(painter.shouldRepaint(hyperdrive.AsteroidPainter(shape: shape)), isFalse);
    expect(painter.shouldRepaint(hyperdrive.AsteroidPainter(shape: Path())), isTrue);
  });
}
