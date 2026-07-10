import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Per-minigame background palette. Defaults to the cosmic look used across the
/// app; individual games can opt into a themed variant (e.g. the warm
/// "Solarpanel-Baumeister" glow) by passing a [gameKey] to [SpaceBackground].
class GameBackgroundTheme {
  final List<Color> gradient; // 3-stop base gradient
  final Color nebulaA; // primary drifting glow
  final Color nebulaB; // secondary drifting glow
  final Color starColor;

  const GameBackgroundTheme({
    required this.gradient,
    required this.nebulaA,
    required this.nebulaB,
    this.starColor = Colors.white,
  });

  /// The default deep-space palette (matches the app's original background).
  static const GameBackgroundTheme cosmic = GameBackgroundTheme(
    gradient: [Color(0xFF0B1426), Color(0xFF1A1A2E), Color(0xFF16213E)],
    nebulaA: Color(0xFF6B48FF), // nebula purple
    nebulaB: Color(0xFF00C9DB), // signal cyan
    starColor: Color(0xFFFFF3C4),
  );

  /// Per-game overrides, keyed by the same `gameKey` used elsewhere in the app.
  static const Map<String, GameBackgroundTheme> _byGame = {
    // Solarpanel-Baumeister — warm sunrise gold / solar orange.
    'solarpanel': GameBackgroundTheme(
      gradient: [Color(0xFF1C1305), Color(0xFF2E1E08), Color(0xFF3E2A0B)],
      nebulaA: Color(0xFFFFD700), // gold
      nebulaB: Color(0xFFFF6B35), // solar orange
      starColor: Color(0xFFFFE9A8),
    ),
    // Comm Relay / Komm-Relais — cool signal cyan.
    'comm_relay': GameBackgroundTheme(
      gradient: [Color(0xFF03121A), Color(0xFF07202E), Color(0xFF0B2C3D)],
      nebulaA: Color(0xFF00C9DB),
      nebulaB: Color(0xFF6B48FF),
      starColor: Color(0xFFB8F4FF),
    ),
  };

  static GameBackgroundTheme forGame(String? key) => _byGame[key] ?? cosmic;
}

/// Animated deep-space backdrop shared by (almost) every game screen.
///
/// Renders a vivid base gradient with two slowly drifting nebula glows and a
/// field of gently twinkling stars. Backward compatible: `SpaceBackground(child:
/// …)` keeps working everywhere; pass [gameKey] to tint it for a specific game,
/// or [animate] `false` to force the static look. Honours the platform
/// "reduce motion" accessibility setting automatically.
class SpaceBackground extends StatefulWidget {
  final Widget child;
  final String? gameKey;
  final bool animate;

  const SpaceBackground({
    super.key,
    required this.child,
    this.gameKey,
    this.animate = true,
  });

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (widget.animate) _controller.repeat();

    // Seeded so the star field is stable across rebuilds (no popping).
    final rng = math.Random(7);
    _stars = List.generate(
      90,
      (_) => _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        radius: rng.nextDouble() * 1.1 + 0.3,
        phase: rng.nextDouble(),
        speed: rng.nextDouble() * 0.6 + 0.4,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = GameBackgroundTheme.forGame(widget.gameKey);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = widget.animate && !reduceMotion;

    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }

    final Widget backdrop = IgnorePointer(
      child: RepaintBoundary(
        child: animate
            ? AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(
                  painter: _SpacePainter(_controller.value, _stars, theme),
                  size: Size.infinite,
                ),
              )
            : CustomPaint(
                painter: _SpacePainter(0.0, _stars, theme),
                size: Size.infinite,
              ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop,
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  final double dx, dy, radius, phase, speed;
  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
    required this.speed,
  });
}

class _SpacePainter extends CustomPainter {
  final double t;
  final List<_Star> stars;
  final GameBackgroundTheme theme;

  _SpacePainter(this.t, this.stars, this.theme);

  static const double _twoPi = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    void glow(Color color, double baseX, double baseY, double driftX,
        double driftY, double radiusFactor, double phase) {
      final cx = size.width * (baseX + driftX * math.sin(_twoPi * (t + phase)));
      final cy = size.height * (baseY + driftY * math.cos(_twoPi * (t + phase)));
      final r = size.shortestSide * radiusFactor;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Two large, softly drifting nebula clouds.
    glow(theme.nebulaA, 0.25, 0.30, 0.06, 0.05, 0.60, 0.0);
    glow(theme.nebulaB, 0.78, 0.72, 0.05, 0.06, 0.52, 0.4);

    // Twinkling star field.
    final starPaint = Paint();
    for (final s in stars) {
      final twinkle =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(_twoPi * (t * s.speed + s.phase)));
      starPaint.color = theme.starColor.withValues(alpha: twinkle * 0.9);
      canvas.drawCircle(
          Offset(s.dx * size.width, s.dy * size.height), s.radius, starPaint);
    }
  }

  @override
  bool shouldRepaint(_SpacePainter old) => old.t != t || old.theme != theme;
}
