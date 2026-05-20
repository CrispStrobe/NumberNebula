// ignore_for_file: unused_element
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

// Enhanced visual effects classes
class CombatParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  final double maxLife;
  final String type;

  CombatParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    required this.type,
  }) : maxLife = life;

  factory CombatParticle.damage(math.Random random) {
    return CombatParticle(
      position: Offset(
        300 + random.nextDouble() * 100,
        200 + random.nextDouble() * 50,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 300,
        -random.nextDouble() * 200,
      ),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 3 + random.nextDouble() * 5,
      life: 0.8 + random.nextDouble() * 0.7,
      type: 'damage',
    );
  }

  factory CombatParticle.explosion(math.Random random) {
    return CombatParticle(
      position: Offset(
        300 + random.nextDouble() * 100,
        200 + random.nextDouble() * 50,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 150,
        -random.nextDouble() * 100,
      ),
      color: [Colors.white, Colors.cyan, Colors.lightBlueAccent][random.nextInt(3)],
      size: 2 + random.nextDouble() * 4,
      life: 1.0 + random.nextDouble() * 0.5,
      type: 'explosion',
    );
  }

  factory CombatParticle.enemyAttack(math.Random random) {
    return CombatParticle(
      position: Offset(
        100 + random.nextDouble() * 200,
        100 + random.nextDouble() * 100,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 200,
        random.nextDouble() * 150,
      ),
      color: [Colors.purple, Colors.deepPurple, Colors.indigo][random.nextInt(3)],
      size: 2 + random.nextDouble() * 3,
      life: 0.6 + random.nextDouble() * 0.4,
      type: 'enemy_attack',
    );
  }

  bool update() {
    position += velocity * 0.016;
    velocity *= 0.96;
    life -= 0.016;
    return life <= 0;
  }

  Widget buildWidget() {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: (life / maxLife).clamp(0.0, 1.0)),
          shape: BoxShape.circle,
          boxShadow: type == 'explosion'
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: size * 2,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

// Enhanced energy orb with card targeting
class EnergyOrb {
  final double startTime;
  final int targetCardIndex;
  late Offset position;
  late Offset startPosition;
  late Offset endPosition;
  double life = 1.0;

  EnergyOrb({required this.startTime, required this.targetCardIndex}) {
    startPosition = const Offset(400, 400); // Player energy stat position
    // Target a specific card position in battlefield
    endPosition = Offset(
      200 + (targetCardIndex * 60.0),
      280,
    );
    position = startPosition;
  }

  bool update(double animationProgress) {
    final adjustedProgress = ((animationProgress - startTime) / (1.0 - startTime)).clamp(0.0, 1.0);
    
    if (adjustedProgress > 0) {
      position = Offset.lerp(startPosition, endPosition, adjustedProgress)!;
      life = 1.0 - adjustedProgress;
    }
    
    return adjustedProgress >= 1.0;
  }

  Widget buildWidget() {
    return Positioned(
      left: position.dx - 8,
      top: position.dy - 8,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: SpaceTheme.starYellow.withValues(alpha: life),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow.withValues(alpha: life * 0.8),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// Shield effect visualization
class ShieldEffect {
  final String type;
  late Color color;
  late String symbol;
  double rotation = 0.0;

  ShieldEffect({required this.type}) {
    switch (type) {
      case 'prime_shield':
        color = Colors.cyan;
        symbol = "PRM";
        break;
      case 'fibonacci_only':
        color = Colors.orange;
        symbol = "FIB";
        break;
      case 'square_immune':
        color = Colors.purple;
        symbol = "SQR";
        break;
      case 'power_of_two_only':
        color = Colors.lightBlue;
        symbol = "2^N";
        break;
      default:
        color = Colors.white;
        symbol = "???";
    }
  }

  void update(double animationValue) {
    rotation = animationValue * 2 * math.pi;
  }

  Widget buildWidget() {
    return Positioned(
      top: 20,
      right: 20,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: color,
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bonus effect visualization
// Bonus effect visualization (Corrected)
class BonusEffect {
  final String type;
  final String value;
  final Color color;
  double scale = 0.0;
  double opacity = 1.0;

  BonusEffect({required this.type, required this.value, required this.color});

  void update(double animationValue) {
    scale = animationValue;
    opacity = 1.0 - (animationValue * 0.5);
  }

  // FIX: Removed the Positioned widget from this method.
  // It now only returns the visual representation of the marker.
  Widget buildWidget() {
    // The text to display, omitting the value if it's empty.
    final displayText = value.isEmpty ? type : "$type $value";

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity * 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.7),
              blurRadius: 15,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// TRON-style grid painter
class TronGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpaceTheme.nebulaPurple.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Card pattern painter
class CardPatternPainter extends CustomPainter {
  final Color color;

  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    // Draw circuit-like patterns
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), paint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), paint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
