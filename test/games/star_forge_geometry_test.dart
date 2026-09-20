// The board drawing has to agree with the puzzle it is drawing.
//
// Star Forge's arms were laid out on two rings whose indices did not follow
// the ring around, so each arm came out as a bent polyline crossing its
// neighbours -- five overlapping streaks of colour, and an instruction
// ("each line through the star must have the same sum") naming something no
// player could pick out. The new layout only works because an arm really is
// four *neighbouring* positions of the outline. That is the property tested
// here: if it ever stops holding, the drawing silently goes back to lying
// about the puzzle.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/widgets/star_forge_diagram.dart';

void main() {
  group('StarForgeGeometry', () {
    test('every node gets its own place on the outline', () {
      for (final points in [5, 6, 7]) {
        final seen = <int>{};
        for (int node = 0; node < 2 * points; node++) {
          seen.add(StarForgeGeometry.ringPosition(node, points));
        }
        expect(seen, hasLength(2 * points), reason: 'points=$points');
        expect(seen.reduce((a, b) => a < b ? a : b), 0);
        expect(seen.reduce((a, b) => a > b ? a : b), 2 * points - 1);
      }
    });

    test('tips and inner nodes alternate around the outline', () {
      for (final points in [5, 6, 7]) {
        for (int node = 0; node < 2 * points; node++) {
          final pos = StarForgeGeometry.ringPosition(node, points);
          // Tips are nodes 0..points-1 and must land on even positions, so
          // the outline steps out, in, out, in -- which is what makes it read
          // as a star rather than two unrelated rings.
          expect(pos.isEven, node < points, reason: 'points=$points node=$node');
        }
      }
    });

    test('every arm is four neighbouring positions of the outline', () async {
      for (final points in [5, 6, 7]) {
        final puzzle = await StarForgeGenerator()
            .generate(points: points, clueCount: points);

        for (int arm = 0; arm < puzzle.lines.length; arm++) {
          final positions = puzzle.lines[arm]
              .map((n) => StarForgeGeometry.ringPosition(n, points))
              .toList();

          // The four positions, read as a run starting at 2*arm and wrapping.
          final expected = <int>{
            for (int k = 0; k < 4; k++) (2 * arm + k) % (2 * points),
          };
          expect(positions.toSet(), expected,
              reason: 'arm $arm of a $points-point star must be a run');
        }
      }
    });

    test('badges are spaced evenly and never share an angle', () {
      for (final points in [5, 6, 7]) {
        final angles = <double>[
          for (int arm = 0; arm < points; arm++)
            StarForgeGeometry.angleAt(2 * arm + 1.5, points),
        ];
        for (int i = 0; i + 1 < angles.length; i++) {
          expect(angles[i + 1] - angles[i], closeTo(2 * math.pi / points, 1e-12),
              reason: 'points=$points');
        }
      }
    });

    test('the worked example really is a solved board', () async {
      // The onboarding shows a 5-point star with 1..10 placed and claims every
      // arm totals 22. Rebuild it through the puzzle's own line structure so
      // the claim cannot drift away from the rule the game scores by.
      const tips = [1, 9, 3, 7, 5];
      const inner = [10, 2, 8, 4, 6];
      final puzzle =
          await StarForgeGenerator().generate(points: 5, clueCount: 5);

      int valueAt(int node) => node < 5 ? tips[node] : inner[node - 5];

      expect({...tips, ...inner}, hasLength(10));
      for (final line in puzzle.lines) {
        expect(line.map(valueAt).reduce((a, b) => a + b), 22);
      }
    });
  });
}
