import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

class WormholePainter extends CustomPainter {
  final double glowIntensity;
  final double time;
  final double warpActivation;

  const WormholePainter({
    required this.glowIntensity,
    required this.time,
    required this.warpActivation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final wormholePaint = Paint()
      ..shader = RadialGradient(
        colors: const [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        stops: const [0.0, 0.8],
        transform: GradientRotation(time * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.2, wormholePaint);

    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (int i = 0; i < 30; i++) {
      final starRadius = (math.sin(time * 2 * math.pi + i * 0.5) + 1) / 2 * 1.5;
      final angle = (i * 1.375) + (time * 0.5);
      final distance = math.sqrt(i / 30) * radius;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        starRadius,
        starPaint,
      );
    }

    final path = Path();
    final cornerPoints = <Offset>[];
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3) - math.pi / 2;
      final point = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      cornerPoints.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final energyPaint = Paint()
      ..color = SpaceTheme.alienGreen.withValues(alpha: glowIntensity * 0.6)
      ..style = PaintingStyle.stroke..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, energyPaint);

    final framePaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, framePaint);

    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = Colors.white.withValues(alpha: Curves.easeOut.transform(warpActivation))
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final point in cornerPoints) {
        final convergencePoint = Offset.lerp(point, center, Curves.easeIn.transform(warpActivation))!;
        canvas.drawLine(point, convergencePoint, warpPaint);
      }
    }
  }

  @override
  bool shouldRepaint(WormholePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.time != time ||
      oldDelegate.warpActivation != warpActivation;
}
