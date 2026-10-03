import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

enum WormholeRenderPath { legacy, cached }

class WormholePainter extends CustomPainter {
  final double glowIntensity;
  final double time;
  final double warpActivation;
  final WormholeRenderCache? renderCache;

  const WormholePainter({
    required this.glowIntensity,
    required this.time,
    required this.warpActivation,
    this.renderCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (renderCache != null) {
      renderCache!.paint(canvas, size,
          glowIntensity: glowIntensity,
          time: time,
          warpActivation: warpActivation);
      return;
    }
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
      final point =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, energyPaint);

    final framePaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, framePaint);

    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = Colors.white
            .withValues(alpha: Curves.easeOut.transform(warpActivation))
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final point in cornerPoints) {
        final convergencePoint = Offset.lerp(
            point, center, Curves.easeIn.transform(warpActivation))!;
        canvas.drawLine(point, convergencePoint, warpPaint);
      }
    }
  }

  @override
  bool shouldRepaint(WormholePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.time != time ||
      oldDelegate.warpActivation != warpActivation ||
      oldDelegate.renderCache != renderCache;
}

/// Size-dependent resources owned by a single wormhole; never saved with puzzles.
class WormholeRenderCache {
  Size? _size;
  Offset _center = Offset.zero;
  double _radius = 0;
  Path? _triangle;
  List<Offset> _corners = const [];
  List<double> _starDistances = const [];
  final _diskPaint = Paint();
  final _starPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
  final _energyPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final _framePaint = Paint()
    ..color = SpaceTheme.starYellow.withValues(alpha: 0.8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final _warpPaint = Paint()
    ..strokeWidth = 4.0
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  void _prepare(Size size) {
    if (_size == size) return;
    dispose();
    _center = Offset(size.width / 2, size.height / 2);
    _radius = size.width * 0.42;
    try {
      // Rotation does not change a centered circular radial gradient.
      _diskPaint.shader = const RadialGradient(
        colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        stops: [0.0, 0.8],
      ).createShader(Rect.fromCircle(center: _center, radius: _radius * 1.2));
      final path = Path();
      final corners = <Offset>[];
      for (var i = 0; i < 3; i++) {
        final angle = (i * 2 * math.pi / 3) - math.pi / 2;
        final point = _center +
            Offset(math.cos(angle) * _radius, math.sin(angle) * _radius);
        corners.add(point);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      _triangle = path;
      _corners = corners;
      _starDistances = [
        for (var i = 0; i < 30; i++) math.sqrt(i / 30) * _radius,
      ];
      _size = size;
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  void paint(Canvas canvas, Size size,
      {required double glowIntensity,
      required double time,
      required double warpActivation}) {
    if (size.isEmpty) return;
    _prepare(size);
    canvas.drawCircle(_center, _radius * 1.2, _diskPaint);
    for (var i = 0; i < 30; i++) {
      final starRadius = (math.sin(time * 2 * math.pi + i * 0.5) + 1) / 2 * 1.5;
      final angle = (i * 1.375) + (time * 0.5);
      final distance = _starDistances[i];
      canvas.drawCircle(
        _center +
            Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        starRadius,
        _starPaint,
      );
    }
    _energyPaint.color =
        SpaceTheme.alienGreen.withValues(alpha: glowIntensity * 0.6);
    canvas.drawPath(_triangle!, _energyPaint);
    canvas.drawPath(_triangle!, _framePaint);
    if (warpActivation > 0) {
      _warpPaint.color = Colors.white
          .withValues(alpha: Curves.easeOut.transform(warpActivation));
      for (final point in _corners) {
        final convergencePoint = Offset.lerp(
            point, _center, Curves.easeIn.transform(warpActivation))!;
        canvas.drawLine(point, convergencePoint, _warpPaint);
      }
    }
  }

  void dispose() {
    _diskPaint.shader?.dispose();
    _diskPaint.shader = null;
    _size = null;
    _center = Offset.zero;
    _radius = 0;
    _triangle = null;
    _corners = const [];
    _starDistances = const [];
  }
}

/// Samples animations during paint without rebuilding the CustomPaint widget.
class AnimatedWormholePainter extends CustomPainter {
  final Animation<double> glowIntensity;
  final Animation<double> time;
  final Animation<double> warpActivation;
  final WormholeRenderCache renderCache;

  AnimatedWormholePainter({
    required this.glowIntensity,
    required this.time,
    required this.warpActivation,
    required this.renderCache,
  }) : super(repaint: Listenable.merge([glowIntensity, time, warpActivation]));

  @override
  void paint(Canvas canvas, Size size) => renderCache.paint(canvas, size,
      glowIntensity: glowIntensity.value,
      time: time.value,
      warpActivation: warpActivation.value);

  @override
  bool shouldRepaint(AnimatedWormholePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.time != time ||
      oldDelegate.warpActivation != warpActivation ||
      oldDelegate.renderCache != renderCache;
}
