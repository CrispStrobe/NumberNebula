import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
import '../constants/app_constants.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';

class PlanetHoppingGame extends StatefulWidget {
  final int grade;
  final int level;

  const PlanetHoppingGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<PlanetHoppingGame> createState() => _PlanetHoppingGameState();
}

class _PlanetHoppingGameState extends State<PlanetHoppingGame>
    with TickerProviderStateMixin {
  late AnimationController _gameController;
  late AnimationController _gravityController;
  late AnimationController _planetController;

  // Game objects
  List<Planet> planets = [];
  List<GravityField> gravityFields = [];
  List<ParticleEffect> particles = [];
  List<Star> backgroundStars = [];
  SpaceHopper hopper = SpaceHopper();

  // Game state
  List<int> targetSequence = [];
  List<int> visitedSequence = [];
  bool gameActive = true;
  int lives = 3;

  // Current objective
  int nextTargetIndex = 0;
  bool showObjective = true;

  @override
  void initState() {
    super.initState();

    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _gravityController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _planetController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _initializeGame();
    _gameController.addListener(_updateGame);
  }

  @override
  void dispose() {
    _gameController.dispose();
    _gravityController.dispose();
    _planetController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    _generateBackgroundStars();
    _generatePlanets();
    _generateTargetSequence();

    if (planets.isNotEmpty) {
      final startPlanet = planets.first;
      hopper.position = Offset(
        startPlanet.position.dx,
        startPlanet.position.dy - startPlanet.radius - 30,
      );
    }
  }

  void _generateBackgroundStars() {
    backgroundStars.clear();
    final random = math.Random();
    for (int i = 0; i < 80; i++) {
      backgroundStars.add(Star(
        position: Offset(
          random.nextDouble() * 1500,
          random.nextDouble() * 1000,
        ),
        size: random.nextDouble() * 2 + 1,
        brightness: random.nextDouble() * 0.8 + 0.2,
      ));
    }
  }

  void _generatePlanets() {
    planets.clear();
    gravityFields.clear();
    final random = math.Random();
    int planetCount;
    double maxNumber;
    switch (widget.grade) {
      case 3:
        planetCount = 5;
        maxNumber = 20;
        break;
      case 4:
        planetCount = 6;
        maxNumber = 50;
        break;
      case 5:
        planetCount = 7;
        maxNumber = 100;
        break;
      case 6:
      default:
        planetCount = 8;
        maxNumber = 200;
        break;
    }

    final problems = <MathProblem>[];
    final usedAnswers = <int>{};

    for (int i = 0; i < planetCount; i++) {
      MathProblem problem;
      do {
        if (random.nextDouble() < 0.3) {
          problem = MathProblem.random(widget.grade, difficulty: widget.level);
        } else {
          final number = random.nextInt(maxNumber.toInt()) + 1;
          problem = MathProblem(
            expression: number.toString(),
            answer: number,
            operation: MathOperation.addition,
            operandA: number,
            operandB: 0,
            difficulty: 1,
          );
        }
      } while (usedAnswers.contains(problem.answer));
      usedAnswers.add(problem.answer);
      problems.add(problem);
    }

    final center = const Offset(400, 300);
    final baseRadius = 250.0;
    for (int i = 0; i < planetCount; i++) {
      final angle = (i * 2 * math.pi / planetCount) + random.nextDouble() * 0.5;
      final distance = baseRadius + random.nextDouble() * 100 - 50;
      final planetRadius = 30.0 + random.nextDouble() * 25;
      final mass = planetRadius * 2;

      final planet = Planet(
        position: Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        ),
        radius: planetRadius,
        mass: mass,
        answer: problems[i].answer,
        problem: problems[i].expression,
        color: _getPlanetColor(i),
        visited: false,
      );
      planets.add(planet);
      gravityFields.add(GravityField(
        center: planet.position,
        radius: planet.radius + 80,
        strength: planet.mass,
      ));
    }
  }

  Color _getPlanetColor(int index) {
    final colors = [
      SpaceTheme.planetOrange,
      SpaceTheme.alienGreen,
      SpaceTheme.cosmicPink,
      SpaceTheme.starYellow,
      Colors.cyan,
      Colors.purple.shade300,
      Colors.teal,
      Colors.orange.shade300,
    ];
    return colors[index % colors.length];
  }

  void _generateTargetSequence() {
    targetSequence = planets.map((p) => p.answer).toList();
    switch (widget.level % 3) {
      case 0:
        targetSequence.sort();
        break;
      case 1:
        targetSequence.sort((a, b) => b.compareTo(a));
        break;
      case 2:
        final evens = targetSequence.where((n) => n % 2 == 0).toList()..sort();
        final odds = targetSequence.where((n) => n % 2 == 1).toList()..sort();
        targetSequence = [...evens, ...odds];
        break;
    }
    visitedSequence.clear();
    nextTargetIndex = 0;
  }

  String get _currentObjectiveText {
    // FIX: Add null assertion '!' to S.of(context)
    final s = S.of(context)!;
    switch (widget.level % 3) {
      case 0: return s.planetHoppingObjectiveAsc;
      case 1: return s.planetHoppingObjectiveDesc;
      case 2: return s.planetHoppingObjectiveEvenOdd;
      default: return '';
    }
  }

  void _addSuccessParticles(Planet planet) {
    for (int i = 0; i < 15; i++) {
      particles.add(ParticleEffect(
        position: planet.position,
        velocity: Offset((math.Random().nextDouble() - 0.5) * 200, (math.Random().nextDouble() - 0.5) * 200),
        color: SpaceTheme.starYellow, life: 1.5, size: 3.0,
      ));
    }
  }

  void _addErrorParticles(Planet planet) {
    for (int i = 0; i < 10; i++) {
      particles.add(ParticleEffect(
        position: planet.position,
        velocity: Offset((math.Random().nextDouble() - 0.5) * 150, (math.Random().nextDouble() - 0.5) * 150),
        color: SpaceTheme.rocketRed, life: 1.0, size: 2.5,
      ));
    }
  }

  void _winGame() {
    gameActive = false;
    final bonus = lives * 200;
    context.read<GameProvider>().addScore(bonus);
    showDialog(context: context, barrierDismissible: false, builder: (context) => _buildWinDialog(bonus));
  }

  void _gameOver() {
    gameActive = false;
    showDialog(context: context, barrierDismissible: false, builder: (context) => _buildGameOverDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFF000510), Color(0xFF1A1A3E), Color(0xFF000510)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ...backgroundStars.map((star) => Positioned(
                  left: star.position.dx, top: star.position.dy,
                  child: Container(width: star.size, height: star.size, decoration: BoxDecoration(color: Colors.white.withOpacity(star.brightness), shape: BoxShape.circle)))),
              ...gravityFields.map((field) => AnimatedBuilder(animation: _gravityController, builder: (context, child) => Positioned(left: field.center.dx - field.radius, top: field.center.dy - field.radius,
                  child: Container(width: field.radius * 2, height: field.radius * 2, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: SpaceTheme.alienGreen.withOpacity(0.3 * _gravityController.value), width: 1)))))),
              
              ...planets.asMap().entries.map((entry) => Positioned(left: entry.value.position.dx - entry.value.radius, top: entry.value.position.dy - entry.value.radius,
                  child: AnimatedBuilder(animation: _planetController, builder: (context, child) => PlanetWidget(planet: entry.value, isTarget: nextTargetIndex < targetSequence.length && entry.value.answer == targetSequence[nextTargetIndex], rotationAnimation: _planetController.value + (entry.key * 0.3))))),
              
              Positioned(left: hopper.position.dx - 15, top: hopper.position.dy - 15, child: SpaceHopperWidget(hopper: hopper, gravityController: _gravityController)),
              
              ...particles.map((particle) => Positioned(left: particle.position.dx, top: particle.position.dy, child: ParticleWidget(particle: particle))),
              
              _buildGameUI(),
              
              _buildControlOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withOpacity(0.9),
            border: Border(bottom: BorderSide(color: SpaceTheme.starYellow.withOpacity(0.3), width: 2)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  // FIX: Stop game loop *before* navigating back
                  gameActive = false;
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              Expanded(
                child: Text(S.of(context)!.planetHoppingTitle, style: SpaceTheme.titleStyle.copyWith(fontSize: 18)),
              ),
              Row(
                children: List.generate(3, (index) => Icon(index < lives ? Icons.favorite : Icons.favorite_border, color: SpaceTheme.rocketRed, size: 18)),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: SpaceTheme.alienGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('$nextTargetIndex/${targetSequence.length}', style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.alienGreen, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              IconButton(
                onPressed: () => setState(() => showObjective = !showObjective),
                icon: Icon(showObjective ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),
        
        if (showObjective)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SpaceTheme.deepSpace.withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: SpaceTheme.starYellow, width: 1)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gps_fixed, color: SpaceTheme.rocketRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_currentObjectiveText, style: SpaceTheme.bodyStyle.copyWith(fontSize: 12), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                if (nextTargetIndex < targetSequence.length) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: SpaceTheme.starYellow, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      // FIX: Add null assertion '!'
                      S.of(context)!.planetHoppingNextTargetValue(targetSequence[nextTargetIndex]),
                      style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.spaceBlue, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        
        const Spacer(),
        
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8), border: Border.all(color: SpaceTheme.alienGreen, width: 1)),
          // FIX: Add null assertion '!'
          child: Text(S.of(context)!.planetHoppingInstructions, style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: SpaceTheme.alienGreen), textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildControlOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (details) {
          if (!gameActive) return;
          final tapPosition = details.localPosition;
          final direction = (tapPosition - hopper.position).normalize();
          setState(() {
            hopper.velocity += direction * 500;
          });
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  void _updateGame() {
    if (!gameActive) return;
    final dt = 0.016;
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      Offset totalForce = Offset.zero;
      for (final field in gravityFields) {
        final distance = (hopper.position - field.center).distance;
        if (distance < field.radius && distance > 10) {
          final direction = (field.center - hopper.position) / distance;
          final force = field.strength / (distance * distance) * 150;
          totalForce += direction * force;
        }
      }

      hopper.velocity += totalForce * dt;
      hopper.velocity *= 0.995;
      hopper.position += hopper.velocity * dt;

      final bounds = Rect.fromLTWH(20, 80, screenSize.width - 40, screenSize.height - 160);
      if (hopper.position.dx < bounds.left || hopper.position.dx > bounds.right) {
        hopper.velocity = Offset(-hopper.velocity.dx * 0.7, hopper.velocity.dy);
        hopper.position = Offset(hopper.position.dx.clamp(bounds.left, bounds.right), hopper.position.dy);
      }
      if (hopper.position.dy < bounds.top || hopper.position.dy > bounds.bottom) {
        hopper.velocity = Offset(hopper.velocity.dx, -hopper.velocity.dy * 0.7);
        hopper.position = Offset(hopper.position.dx, hopper.position.dy.clamp(bounds.top, bounds.bottom));
      }

      for (final planet in planets) {
        if (!planet.visited && _checkPlanetLanding(planet)) {
          _landOnPlanet(planet);
        }
      }

      particles.removeWhere((particle) {
        particle.update(dt);
        return particle.life <= 0;
      });
    });
  }

  bool _checkPlanetLanding(Planet planet) {
    final distance = (hopper.position - planet.position).distance;
    return distance < planet.radius + 30 && hopper.velocity.distance < 120;
  }

  void _landOnPlanet(Planet planet) {
    planet.visited = true;
    visitedSequence.add(planet.answer);
    hopper.velocity *= 0.3;

    if (nextTargetIndex < targetSequence.length && planet.answer == targetSequence[nextTargetIndex]) {
      nextTargetIndex++;
      context.read<GameProvider>().addScore(100 * widget.grade);
      _addSuccessParticles(planet);
      if (nextTargetIndex >= targetSequence.length) {
        _winGame();
      }
    } else {
      lives--;
      _addErrorParticles(planet);
      if (lives <= 0) {
        _gameOver();
      } else {
        context.read<GameProvider>().addScore(-25 * widget.grade);
      }
    }
  }

  Widget _buildWinDialog(int bonus) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 64, color: SpaceTheme.starYellow),
            const SizedBox(height: 16),
            // FIX: Add null assertion '!'
            Text(S.of(context)!.planetHoppingWinTitle, style: SpaceTheme.headlineStyle.copyWith(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              // FIX: Add null assertion '!'
              S.of(context)!.planetHoppingWinDescBonus(bonus),
              style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // FIX: Add null assertion '!'
                ElevatedButton(onPressed: () { Navigator.of(context).pop(); _resetGame(); }, style: SpaceTheme.secondaryButtonStyle, child: Text(S.of(context)!.exploreAgain)),
                // FIX: Add null assertion '!'
                ElevatedButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, style: SpaceTheme.primaryButtonStyle, child: Text(S.of(context)!.returnToBase)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            // FIX: Add null assertion '!'
            Text(S.of(context)!.planetHoppingLoseTitle, style: SpaceTheme.headlineStyle.copyWith(fontSize: 20), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // FIX: Add null assertion '!'
            Text(S.of(context)!.planetHoppingLoseDescCrash, style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // FIX: Add null assertion '!'
                ElevatedButton(onPressed: () { Navigator.of(context).pop(); _resetGame(); }, style: SpaceTheme.primaryButtonStyle, child: Text(S.of(context)!.retryMission)),
                // FIX: Add null assertion '!'
                ElevatedButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }, style: SpaceTheme.secondaryButtonStyle, child: Text(S.of(context)!.returnToBase)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      gameActive = true;
      lives = 3;
      nextTargetIndex = 0;
      visitedSequence.clear();
      particles.clear();
      for (final planet in planets) {
        planet.visited = false;
      }
      if (planets.isNotEmpty) {
        final startPlanet = planets.first;
        hopper = SpaceHopper();
        hopper.position = Offset(startPlanet.position.dx, startPlanet.position.dy - startPlanet.radius - 30);
      }
    });
  }
}

// Data Models
class SpaceHopper {
  Offset position = const Offset(100, 100);
  Offset velocity = Offset.zero;
}

class Planet {
  Offset position;
  double radius, mass;
  int answer;
  String problem;
  Color color;
  bool visited;
  Planet({required this.position, required this.radius, required this.mass, required this.answer, required this.problem, required this.color, required this.visited});
}

class GravityField {
  Offset center;
  double radius, strength;
  GravityField({required this.center, required this.radius, required this.strength});
}

class ParticleEffect {
  Offset position, velocity;
  Color color;
  double life, maxLife, size;
  ParticleEffect({required this.position, required this.velocity, required this.color, required this.life, required this.size}) : maxLife = life;
  void update(double dt) {
    position += velocity * dt;
    life -= dt;
    velocity *= 0.95;
  }
}

class Star {
  Offset position;
  double size, brightness;
  Star({required this.position, required this.size, required this.brightness});
}

// Widgets
class SpaceHopperWidget extends StatelessWidget {
  final SpaceHopper hopper;
  final AnimationController gravityController;
  const SpaceHopperWidget({super.key, required this.hopper, required this.gravityController});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gravityController,
      builder: (context, child) => Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]),
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)],
        ),
        child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18),
      ),
    );
  }
}

class PlanetWidget extends StatelessWidget {
  final Planet planet;
  final bool isTarget;
  final double rotationAnimation;
  const PlanetWidget({super.key, required this.planet, required this.isTarget, required this.rotationAnimation});
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationAnimation,
      child: Container(
        width: planet.radius * 2, height: planet.radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [planet.color, planet.color.withOpacity(0.7), planet.color.withOpacity(0.9)], stops: const [0.0, 0.7, 1.0]),
          border: Border.all(color: isTarget ? SpaceTheme.starYellow : (planet.visited ? SpaceTheme.alienGreen : Colors.transparent), width: isTarget ? 3 : (planet.visited ? 2 : 0)),
          boxShadow: [
            BoxShadow(color: planet.color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
            if (isTarget) BoxShadow(color: SpaceTheme.starYellow.withOpacity(0.6), blurRadius: 15, spreadRadius: 3),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PlanetSurfacePainter(planet.color))),
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                child: Text(planet.problem, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: planet.radius * 0.3), textAlign: TextAlign.center),
              ),
            ),
            if (planet.visited) Positioned(top: 5, right: 5, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: SpaceTheme.alienGreen, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
          ],
        ),
      ),
    );
  }
}

class ParticleWidget extends StatelessWidget {
  final ParticleEffect particle;
  const ParticleWidget({super.key, required this.particle});
  @override
  Widget build(BuildContext context) {
    final opacity = particle.life / particle.maxLife;
    return Container(width: particle.size, height: particle.size, decoration: BoxDecoration(color: particle.color.withOpacity(opacity), shape: BoxShape.circle));
  }
}

class PlanetSurfacePainter extends CustomPainter {
  final Color planetColor;
  PlanetSurfacePainter(this.planetColor);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = planetColor.withOpacity(0.3)..style = PaintingStyle.fill;
    final random = math.Random(42);
    for (int i = 0; i < 3; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * size.width * 0.2 + 5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  @override
  bool shouldRepaint(PlanetSurfacePainter oldDelegate) => false;
}

extension OffsetExtensions on Offset {
  Offset normalize() {
    final length = distance;
    return length > 0 ? this / length : Offset.zero;
  }
}