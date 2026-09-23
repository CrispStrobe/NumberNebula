// lib/features/games/widgets/star_forge_diagram.dart
//
// Geometry and worked examples for Star Forge.
//
// The game was unreadable rather than unsolvable. Its nodes were drawn on two
// rings whose indices did not follow the ring around, so each "line" was a
// zigzag polyline that crossed its neighbours: five bent, overlapping streaks
// of colour, and the instruction "each line through the star must have the
// same sum" named something the player could not pick out on the board.
//
// The structure is actually simple once it is drawn in ring order: 2n nodes
// around a star outline, and every arm is four *neighbouring* nodes. Two
// arms that touch share two of those four. Laying the nodes out in that order
// turns every arm into a short, unbroken run of the outline, which is what
// makes the target total mean anything.
//
// [StarForgeGeometry] is the single source of that layout; the board and these
// diagrams both use it, so the example a player is shown cannot drift from the
// board they are then handed.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

/// Where every node sits, for a star with [points] points and 2 * points nodes.
///
/// Node indices come from the puzzle: `0 .. points-1` are the outer tips and
/// `points .. 2*points-1` are the inner nodes. Around the outline they
/// alternate, tip then inner, which is what [ringPosition] encodes.
class StarForgeGeometry {
  const StarForgeGeometry._();

  /// Fraction of the drawing area's half-width used by the outer tips.
  static const double outerFactor = 0.36;

  /// Inner nodes sit halfway in, which gives a star silhouette rather than
  /// the near-collapsed spike a very small inner radius produced.
  static const double innerFactor = 0.18;

  /// Where the per-arm total badges sit -- outside every node, so they never
  /// cover a number.
  static const double badgeFactor = 0.455;

  /// Position of [nodeIdx] along the outline: 0, 1, 2, ... going round once.
  static int ringPosition(int nodeIdx, int points) =>
      nodeIdx < points ? 2 * nodeIdx : 2 * (nodeIdx - points) + 1;

  /// Angle of a (possibly fractional) outline position. Position 0 is at the
  /// top and positions increase clockwise.
  static double angleAt(double ringPos, int points) =>
      ringPos * math.pi / points - math.pi / 2;

  static Offset _polar(Offset center, double radius, double angle) => Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

  /// Centre of the node [nodeIdx] within a square area of side [size].
  static Offset nodeCenter(int nodeIdx, int points, double size) {
    final pos = ringPosition(nodeIdx, points);
    final isTip = pos.isEven;
    return _polar(
      Offset(size / 2, size / 2),
      size * (isTip ? outerFactor : innerFactor),
      angleAt(pos.toDouble(), points),
    );
  }

  /// Centre of arm [armIdx]'s total badge. Arm `i` covers outline positions
  /// `2i .. 2i+3`, so its middle is at `2i + 1.5` -- and because the arms step
  /// round two positions at a time, the badges come out evenly spaced and
  /// never collide.
  static Offset armBadgeCenter(int armIdx, int points, double size) => _polar(
        Offset(size / 2, size / 2),
        size * badgeFactor,
        angleAt(2 * armIdx + 1.5, points),
      );

  /// The outline itself, as the closed path tip, inner, tip, inner, ...
  static List<Offset> outline(int points, double size) => [
        for (int pos = 0; pos < 2 * points; pos++)
          _polar(
            Offset(size / 2, size / 2),
            size * (pos.isEven ? outerFactor : innerFactor),
            angleAt(pos.toDouble(), points),
          ),
      ];

  /// The node indices of arm [armIdx], in the order they appear along the
  /// outline (which is *not* the order the puzzle lists them in).
  static List<int> armNodesInOutlineOrder(int armIdx, int points) {
    final next = (armIdx + 1) % points;
    return [armIdx, points + armIdx, next, points + next];
  }
}

/// A colour per arm, so a total badge and the stretch of outline it covers
/// can be recognised as the same thing.
const List<Color> starArmColors = [
  Color(0xFFFF6B6B), // red
  Color(0xFF4ECDC4), // teal
  Color(0xFFFFD93D), // yellow
  Color(0xFF6BCB77), // green
  Color(0xFFBB86FC), // purple
  Color(0xFFFF9F43), // orange
  Color(0xFF45B7D1), // cyan
];

/// Draws the star outline, and thickens one arm when [highlightedArm] is set.
class StarForgeOutlinePainter extends CustomPainter {
  final int points;

  /// Arm to draw in its own colour, or null for the plain outline.
  final int? highlightedArm;

  final double glowValue;

  const StarForgeOutlinePainter({
    required this.points,
    this.highlightedArm,
    this.glowValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = StarForgeGeometry.outline(points, size.width);

    // The outline, drawn once as a closed path. Every arm is a run of it, so
    // there is nothing per-arm to overlap.
    final base = Paint()
      ..color = SpaceTheme.nebulaPurple.withValues(alpha: 0.35 + 0.15 * glowValue)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    canvas.drawPath(path, base);

    final arm = highlightedArm;
    if (arm == null) return;

    // The highlighted arm: the three outline segments joining its four nodes.
    final color = starArmColors[arm % starArmColors.length];
    final lit = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final halo = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final start = 2 * arm;
    final armPath = Path();
    for (int k = 0; k <= 3; k++) {
      final p = pts[(start + k) % pts.length];
      if (k == 0) {
        armPath.moveTo(p.dx, p.dy);
      } else {
        armPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(armPath, halo);
    canvas.drawPath(armPath, lit);
  }

  @override
  bool shouldRepaint(covariant StarForgeOutlinePainter old) =>
      old.highlightedArm != highlightedArm ||
      old.points != points ||
      old.glowValue != glowValue;
}

// ─── Onboarding illustrations ──────────────────────────────────────────────

/// A worked 5-point star. Every value 1..10 is placed, so all five arms really
/// do total 22 -- the example is a solved board, not a sketch.
///
/// Pairs a tip with the inner node beside it so each pair totals 11; an arm is
/// two such pairs, hence 22. Players are not told that shortcut, but the
/// example is consistent with it, which is what lets them find it.
const List<int> _exampleTips = [1, 9, 3, 7, 5];
const List<int> _exampleInner = [10, 2, 8, 4, 6];
const int _examplePoints = 5;
const int _exampleTotal = 22;

int _exampleValue(int nodeIdx) => nodeIdx < _examplePoints
    ? _exampleTips[nodeIdx]
    : _exampleInner[nodeIdx - _examplePoints];

/// Shared renderer for the onboarding stars: the outline, the nodes, and
/// whichever arm badges the step wants to talk about.
class _ExampleStar extends StatelessWidget {
  /// Arms to highlight, in drawing order. Only the last one gets the thick
  /// outline; every listed arm gets its total badge.
  final List<int> arms;

  /// Nodes to ring in white, e.g. the two an overlapping pair of arms shares.
  final Set<int> markedNodes;

  /// Nodes to leave blank instead of showing their value.
  final Set<int> blankNodes;

  /// Side of the square the example is drawn in.
  static const double size = 190;

  const _ExampleStar({
    required this.arms,
    this.markedNodes = const {},
    this.blankNodes = const {},
  });

  @override
  Widget build(BuildContext context) {
    const points = _examplePoints;
    const nodeSize = size * 0.115;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: StarForgeOutlinePainter(
          points: points,
          highlightedArm: arms.isEmpty ? null : arms.last,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Every arm this step names gets its total, in the arm's colour.
            for (final arm in arms)
              _positioned(
                StarForgeGeometry.armBadgeCenter(arm, points, size),
                44,
                22,
                _badge(arm),
              ),
            for (int i = 0; i < 2 * points; i++)
              _positioned(
                StarForgeGeometry.nodeCenter(i, points, size),
                nodeSize,
                nodeSize,
                _node(i, nodeSize),
              ),
          ],
        ),
      ),
    );
  }

  Widget _positioned(Offset center, double w, double h, Widget child) =>
      Positioned(
        left: center.dx - w / 2,
        top: center.dy - h / 2,
        width: w,
        height: h,
        child: Center(child: child),
      );

  Widget _badge(int arm) {
    final color = starArmColors[arm % starArmColors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$_exampleTotal',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _node(int nodeIdx, double nodeSize) {
    final blank = blankNodes.contains(nodeIdx);
    final marked = markedNodes.contains(nodeIdx);
    return Container(
      width: nodeSize,
      height: nodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: blank
            ? SpaceTheme.deepSpace
            : SpaceTheme.starYellow.withValues(alpha: 0.18),
        border: Border.all(
          color: marked
              ? Colors.white
              : blank
                  ? SpaceTheme.nebulaPurple
                  : SpaceTheme.starYellow,
          width: marked ? 2.5 : 1.5,
        ),
      ),
      child: Center(
        child: blank
            ? Icon(Icons.add,
                size: nodeSize * 0.5, color: SpaceTheme.nebulaPurple)
            : Text(
                '${_exampleValue(nodeIdx)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: nodeSize * 0.48,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Step: what an arm is. One arm lit, its four nodes readable, its total shown.
class StarForgeArmDiagram extends StatelessWidget {
  const StarForgeArmDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ExampleStar(arms: [0]),
        const SizedBox(height: 6),
        Text(
          // Outline order, so the sum reads along the lit arm.
          '${_exampleTips[0]} + ${_exampleInner[0]} + '
          '${_exampleTips[1]} + ${_exampleInner[1]} = $_exampleTotal',
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 14,
            color: starArmColors[0],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Step: arms overlap. Two neighbouring arms, and the two nodes they share
/// ringed in white -- the reason a number cannot be chosen for one arm alone.
class StarForgeOverlapDiagram extends StatelessWidget {
  const StarForgeOverlapDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    // Arms 0 and 1 share tip 1 and inner node 1.
    return const _ExampleStar(
      arms: [0, 1],
      markedNodes: {1, _examplePoints + 1},
    );
  }
}

/// Step: every arm, all at the same total, with two nodes still to fill.
class StarForgeGoalDiagram extends StatelessWidget {
  const StarForgeGoalDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ExampleStar(
      arms: [0, 1, 2, 3, 4],
      blankNodes: {2, _examplePoints + 3},
    );
  }
}
