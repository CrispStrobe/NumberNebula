import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract class GameObject {
  Offset position;
  GameObject({required this.position});
  void update(double dt, double gameSpeed);
  Widget build();
  Rect get collisionRect;
}

abstract class Effect {
  bool get isComplete;
  void update(double dt);
  Widget build();
}

class Spaceship {
  Offset position;
  double sizeValue = 30.0;
  double targetY;
  bool isMoving = false;
  double damageCooldown = 0.0;
  Offset velocity = Offset.zero;

  Spaceship({required Offset initialPosition}) 
      : position = initialPosition,
        targetY = initialPosition.dy;
  
  Rect get collisionRect => Rect.fromCenter(center: position, width: sizeValue * 1.2, height: sizeValue * 1.2);
  bool get isInvincible => damageCooldown > 0;

  void reset(Size screenSize) {
    position = Offset(150, screenSize.height / 2);
    targetY = position.dy;
    damageCooldown = 0.0;
    velocity = Offset.zero;
  }

  void applyForce(Offset force) {
    velocity += force;
  }

  void update(double dt, Size screenSize) {
    if (damageCooldown > 0) damageCooldown -= dt;
    
    // Apply velocity from gravitational forces
    position += velocity * dt;
    velocity *= 0.98; // Damping
    
    // Move towards target Y
    if ((position.dy - targetY).abs() > 1.0) {
      position = Offset(
        position.dx,
        ui.lerpDouble(position.dy, targetY, 0.25)!,
      );
      isMoving = true;
    } else {
      isMoving = false;
    }
    
    // Keep within screen bounds
    position = Offset(
      position.dx,
      position.dy.clamp(sizeValue, screenSize.height - sizeValue)
    );
  }

  void moveTo(double y) {
    final view = ui.PlatformDispatcher.instance.implicitView!;
    targetY = y.clamp(sizeValue, view.physicalSize.height / view.devicePixelRatio - sizeValue);
  }
  
  void damage() {
    if (isInvincible) return;
    damageCooldown = 1.5;
  }
}

// Enhanced Planet class
class Planet extends GameObject {
  final double radius;
  final Color color;
  double rotation = 0.0;
  
  Planet({required super.position, required this.radius, required this.color});
  
  @override
  Rect get collisionRect => Rect.fromCenter(center: position, width: radius * 2, height: radius * 2);
  
  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
    rotation += dt * 0.5;
  }
  
  @override
  Widget build() {
    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                color.withValues(alpha: 0.8),
                color.withValues(alpha: 0.6),
                color.withValues(alpha: 0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: radius * 0.5,
                spreadRadius: radius * 0.1,
              )
            ],
          ),
          child: CustomPaint(
            painter: PlanetSurfacePainter(color: color),
          ),
        ),
      ),
    );
  }
}

class PlanetSurfacePainter extends CustomPainter {
  final Color color;
  
  PlanetSurfacePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    // Draw some surface features
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * size.width * 0.1 + 2;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(PlanetSurfacePainter oldDelegate) =>
      oldDelegate.color != color;
}

// Enhanced Space Debris class
class SpaceDebris extends GameObject {
  final double sizeValue = 15.0;
  double rotation = 0.0;
  final double rotationSpeed;
  Offset velocity = Offset.zero;
  
  SpaceDebris({required super.position})
      : rotationSpeed = (math.Random().nextDouble() - 0.5) * 3.0 {
    rotation = math.Random().nextDouble() * math.pi * 2;
  }
  
  @override
  Rect get collisionRect => Rect.fromCenter(center: position, width: sizeValue, height: sizeValue);
  
  void applyForce(Offset force) {
    velocity += force;
  }
  
  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy) + velocity * dt;
    velocity *= 0.99; // Damping
    rotation += rotationSpeed * dt;
  }
  
  @override
  Widget build() {
    return Positioned(
      left: position.dx - sizeValue / 2,
      top: position.dy - sizeValue / 2,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: sizeValue,
          height: sizeValue,
          decoration: BoxDecoration(
            color: Colors.grey.shade600,
            shape: BoxShape.rectangle,
            border: Border.all(color: Colors.grey.shade400, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.3),
                blurRadius: 4,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class Gate extends GameObject {
  final int answer;
  final bool isCorrect;
  final Color color;
  Size size;

  Gate({required super.position, required this.answer, required this.isCorrect, required this.size, required this.color});
  
  @override
  Rect get collisionRect => Rect.fromCenter(center: position, width: size.width * 0.8, height: size.height * 0.8);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
  }

  @override
  Widget build() {
    final gradient = [color.withValues(alpha: 0.1), color.withValues(alpha: 0.4)];

    return Positioned(
      left: position.dx - size.width / 2,
      top: position.dy - size.height / 2,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight
          ),
          boxShadow: [BoxShadow(color: color, blurRadius: 25, spreadRadius: 4)],
        ),
        child: Center(
          child: Text(
            answer.toString(),
            style: TextStyle(
              color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: color, blurRadius: 15)]
            ),
          ),
        ),
      ),
    );
  }
}

class Asteroid extends GameObject {
  double rotation;
  final double rotationSpeed;
  final double sizeValue;
  final Path shape;
  Offset velocity = Offset.zero;

  Asteroid({required super.position, required this.sizeValue})
      : rotation = math.Random().nextDouble() * math.pi * 2,
        rotationSpeed = (math.Random().nextDouble() - 0.5) * 2.5,
        shape = _createAsteroidShape(sizeValue);
  
  static Path _createAsteroidShape(double size) {
    final random = math.Random();
    final path = Path();
    final points = random.nextInt(4) + 5;
    final angleStep = (math.pi * 2) / points;
    
    path.moveTo(
        size + math.cos(0) * (size + (random.nextDouble() - 0.5) * size * 0.4),
        size + math.sin(0) * (size + (random.nextDouble() - 0.5) * size * 0.4)
    );

    for (int i = 1; i <= points; i++) {
        final angle = angleStep * i;
        final radius = size + (random.nextDouble() - 0.5) * size * 0.4;
        path.lineTo(size + math.cos(angle) * radius, size + math.sin(angle) * radius);
    }
    path.close();
    return path;
  }

  @override
  Rect get collisionRect => Rect.fromCenter(center: position, width: sizeValue * 1.5, height: sizeValue * 1.5);

  void applyForce(Offset force) {
    velocity += force;
  }

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * 0.9 * dt, position.dy) + velocity * dt;
    velocity *= 0.99; // Damping
    rotation += rotationSpeed * dt;
  }

  @override
  Widget build() {
    return Positioned(
      left: position.dx - sizeValue,
      top: position.dy - sizeValue,
      child: Transform.rotate(
        angle: rotation,
        child: CustomPaint(
            size: Size(sizeValue * 2, sizeValue * 2),
            painter: AsteroidPainter(shape: shape),
        )
      ),
    );
  }
}

class AsteroidPainter extends CustomPainter {
    final Path shape;
    final Paint fillPaint = Paint()
        ..shader = ui.Gradient.linear(
            const Offset(0, 0), const Offset(40, 40),
            [const Color(0xFF6E5B4B), const Color(0xFF4A3C31)]
        );
    final Paint borderPaint = Paint()
        ..color = const Color(0xFF3B2F26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
        
    AsteroidPainter({required this.shape});

    @override
    void paint(Canvas canvas, Size size) {
        canvas.drawPath(shape, fillPaint);
        canvas.drawPath(shape, borderPaint);
    }
    
    @override
    bool shouldRepaint(AsteroidPainter oldDelegate) =>
        !identical(oldDelegate.shape, shape);
}

class ParticleEffect extends Effect {
    Offset position;
    Offset velocity;
    Color color;
    double life;
    double maxLife;
    double size;
    
    @override
    bool get isComplete => life <= 0;

    ParticleEffect({required this.position, required this.velocity, required this.color, required this.life, required this.size}) : maxLife = life;
    
    factory ParticleEffect.thrusterParticle(Offset shipPosition) {
        final random = math.Random();
        return ParticleEffect(
            position: Offset(shipPosition.dx - 35, shipPosition.dy + (random.nextDouble() - 0.5) * 20),
            velocity: Offset(-400 - random.nextDouble() * 150, (random.nextDouble() - 0.5) * 60),
            color: Color.lerp(Colors.orangeAccent, Colors.white, random.nextDouble())!,
            life: 0.3 + random.nextDouble() * 0.2,
            size: 2.0 + random.nextDouble() * 2.5,
        );
    }

    factory ParticleEffect.explosionParticle(Offset position) {
        final random = math.Random();
        final angle = random.nextDouble() * math.pi * 2;
        final speed = 100 + random.nextDouble() * 350;
        return ParticleEffect(
            position: position,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: Color.lerp(Colors.orange, Colors.red, random.nextDouble())!,
            life: 0.6 + random.nextDouble() * 0.5,
            size: 2.5 + random.nextDouble() * 3.5,
        );
    }

    factory ParticleEffect.successParticle(Offset position) {
        final random = math.Random();
        final angle = (random.nextDouble() - 0.5) * 0.6;
        final speed = 500 + random.nextDouble() * 300;
        return ParticleEffect(
            position: position,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: Color.lerp(Colors.cyanAccent, Colors.white, random.nextDouble())!,
            life: 0.6 + random.nextDouble() * 0.5,
            size: 2.5 + random.nextDouble() * 3.0,
        );
    }

    factory ParticleEffect.powerUpParticle(Offset position, Color baseColor) {
        final random = math.Random();
        final angle = random.nextDouble() * math.pi * 2;
        final speed = 150 + random.nextDouble() * 200;
        return ParticleEffect(
            position: position,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: Color.lerp(baseColor, Colors.white, random.nextDouble() * 0.5)!,
            life: 0.8 + random.nextDouble() * 0.4,
            size: 3.0 + random.nextDouble() * 2.0,
        );
    }
    
    @override
    void update(double dt) {
        position += velocity * dt;
        life -= dt;
        velocity *= 0.95;
    }
    
    @override
    Widget build() {
        final opacity = (life / maxLife).clamp(0.0, 1.0);
        return Positioned(
            left: position.dx, top: position.dy,
            child: Container(
                width: size, height: size,
                decoration: BoxDecoration(color: color.withValues(alpha: opacity), shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: color.withValues(alpha: opacity * 0.6), blurRadius: size * 2)
                ]),
            ),
        );
    }
}

class FloatingScore extends Effect {
  Offset position;
  final String text;
  final Color color;
  final double fontSize;
  double _progress = 0.0;
  final double _duration = 1.5;
  
  @override
  bool get isComplete => _progress >= 1.0;
  
  FloatingScore({required this.position, required this.text, this.color = Colors.greenAccent, this.fontSize = 24});
  
  @override
  void update(double dt) => _progress += dt / _duration;

  @override
  Widget build() {
    final clampedProgress = _progress.clamp(0.0, 1.0);
    final currentPosition = position - Offset(0, 80 * Curves.easeOut.transform(clampedProgress));
    final opacity = (1.0 - clampedProgress).clamp(0.0, 1.0);
    
    return Positioned(
      left: currentPosition.dx,
      top: currentPosition.dy,
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 5, color: Colors.black.withValues(alpha: opacity * 0.8))],
        ),
      ),
    );
  }
}

class WarpLinesEffect extends Effect {
    final Size screenSize;
    double progress = 0.0;
    
    WarpLinesEffect({required this.screenSize});
    
    @override
    bool get isComplete => progress >= 1.0;
    
    @override
    void update(double dt) => progress += dt / 0.5;
    
    @override
    Widget build() => CustomPaint(
        size: screenSize,
        painter: WarpLinesPainter(progress: progress),
    );
}

class WarpLinesPainter extends CustomPainter {
    final double progress;
    final Paint linePaint = Paint()..strokeWidth = 2.5;
    final int lineCount = 40;

    WarpLinesPainter({required this.progress});
    
    @override
    void paint(Canvas canvas, Size size) {
        final clampedProgress = progress.clamp(0.0, 1.0);
        final center = Offset(size.width * 0.2, size.height / 2);
        final random = math.Random(1);
        final opacity = (1.0 - Curves.easeIn.transform(clampedProgress)).clamp(0.0, 1.0);

        for (int i=0; i < lineCount; i++) {
            final angle = random.nextDouble() * math.pi * 2;
            final startRadius = size.width * 0.8 * Curves.easeOut.transform(clampedProgress);
            final endRadius = startRadius + (200 + random.nextDouble() * 200);

            final startPoint = center + Offset(math.cos(angle), math.sin(angle)) * startRadius;
            final endPoint = center + Offset(math.cos(angle), math.sin(angle)) * endRadius;
            
            linePaint.color = Colors.cyanAccent.withValues(alpha: opacity * (random.nextDouble() * 0.5 + 0.5));
            canvas.drawLine(startPoint, endPoint, linePaint);
        }
    }
    
    @override
    bool shouldRepaint(WarpLinesPainter oldDelegate) => oldDelegate.progress != progress;
}

class SpaceshipWidget extends StatelessWidget {
    final Spaceship spaceship;
    final AnimationController thrusterAnimation;
    final bool hasShield;
  
    const SpaceshipWidget({
      super.key, 
      required this.spaceship, 
      required this.thrusterAnimation,
      this.hasShield = false,
    });

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: thrusterAnimation,
        builder: (context, child) {
          final isDamaged = spaceship.isInvincible && (spaceship.damageCooldown * 12).floor() % 2 == 0;
          return Opacity(
            opacity: isDamaged ? 0.3 : 1.0,
            child: Stack(
              children: [
                SizedBox(
                  width: spaceship.sizeValue * 2.5,
                  height: spaceship.sizeValue * 2.5,
                  child: CustomPaint(
                    painter: SpaceshipPainter(
                      thrusting: spaceship.isMoving,
                      thrusterFlicker: thrusterAnimation.value,
                    ),
                  ),
                ),
                if (hasShield)
                  Positioned(
                    left: -10,
                    top: -10,
                    child: Container(
                      width: spaceship.sizeValue * 2.5 + 20,
                      height: spaceship.sizeValue * 2.5 + 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
}

class SpaceshipPainter extends CustomPainter {
  final bool thrusting;
  final double thrusterFlicker;

  SpaceshipPainter({required this.thrusting, required this.thrusterFlicker});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          [Colors.grey.shade300, Colors.grey.shade600],
      )
      ..style = PaintingStyle.fill;
    
    final bodyPath = Path()
      ..moveTo(size.width, size.height * 0.5)
      ..cubicTo(size.width * 0.8, size.height * 0.3, size.width * 0.3, size.height * 0.1, 0, size.height * 0.2)
      ..lineTo(0, size.height * 0.8)
      ..cubicTo(size.width * 0.3, size.height * 0.9, size.width * 0.8, size.height * 0.7, size.width, size.height * 0.5)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);
    
    final cockpitPaint = Paint()
      ..shader = ui.Gradient.radial(
          Offset(size.width * 0.7, size.height * 0.5), size.width * 0.2,
          [Colors.lightBlue.shade100, Colors.lightBlue.shade400],
      );
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.7, size.height * 0.5), width: size.width * 0.4, height: size.height * 0.4), cockpitPaint);

    if (thrusting) {
        final length = 25 + thrusterFlicker * 10;
        final flameRect = Rect.fromCenter(center: Offset(-length/2, size.height/2), width: length, height: size.height * 0.5);
        final flamePaint = Paint()
            ..shader = ui.Gradient.radial(
                Offset(0, size.height / 2),
                size.height * 0.3,
                [Colors.white, Colors.orangeAccent.withValues(alpha: 0.8), Colors.transparent],
                [0.0, 0.4, 1.0]
            );
        canvas.drawOval(flameRect, flamePaint);
    }
  }

  @override
  bool shouldRepaint(SpaceshipPainter oldDelegate) {
    return oldDelegate.thrusting != thrusting || oldDelegate.thrusterFlicker != thrusterFlicker;
  }
}
