// lib/features/games/screens/planet_hopping_game.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
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
  // --- Animation & Timers ---
  late AnimationController _gameController;
  late AnimationController _gravityController;
  late AnimationController _planetController;
  Timer? _hintTimer;
  Timer? _reLandingCooldown;

  // --- Game State ---
  List<Planet> planets = [];
  List<ParticleEffect> particles = [];
  List<Star> backgroundStars = [];
  SpaceHopper hopper = SpaceHopper();
  List<int> targetSequence = [];
  bool gameActive = true;
  int lives = 3;
  int nextTargetIndex = 0;
  int? _lastLandedPlanetId;

  // --- UI State ---
  bool _showInstructions = true;
  bool _showNextTargetHint = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[Game Init] 🚀 Planet Hopping game initializing...");

    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16), // ~60 FPS
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

    debugPrint("[Game Init] ℹ️ Starting 5-second timer for instructions overlay.");
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        debugPrint("[Game Init] ℹ️ Hiding instructions overlay now.");
        setState(() => _showInstructions = false);
      }
    });
  }

  @override
  void dispose() {
    debugPrint("[Game Dispose] 🛑 Disposing all controllers and timers.");
    _gameController.dispose();
    _gravityController.dispose();
    _planetController.dispose();
    _hintTimer?.cancel();
    _reLandingCooldown?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    debugPrint("[Gameplay] ✨ Initializing new game board.");
    _generateBackgroundStars();
    _generatePlanets();
    _generateTargetSequence();
    _startHintTimer();

    if (planets.isNotEmpty) {
      final startPlanet = planets.first;
      hopper.position = Offset(
        startPlanet.position.dx,
        startPlanet.position.dy - startPlanet.radius - 30,
      );
    }
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && gameActive) {
        debugPrint("[UI] 💡 Hint timer fired, showing next target.");
        setState(() => _showNextTargetHint = true);
      }
    });
  }

  void _generateBackgroundStars() {
    backgroundStars.clear();
    final random = math.Random();
    for (int i = 0; i < 80; i++) {
      backgroundStars.add(Star(
          position:
              Offset(random.nextDouble() * 1500, random.nextDouble() * 1000),
          size: random.nextDouble() * 2 + 1,
          brightness: random.nextDouble() * 0.8 + 0.2));
    }
  }

  void _generatePlanets() {
    planets.clear();
    final random = math.Random();
    final difficulty = widget.grade + widget.level;
    final planetCount = (5 + (difficulty / 4)).clamp(5, 8).toInt();

    // FIX: Ensure unique problems/answers are generated for each planet
    final problems = <MathProblem>[];
    final usedAnswers = <int>{};
    int attempts = 0; // Safety break to prevent infinite loops
    debugPrint("[Gameplay] Generating $planetCount unique planets...");
    while (problems.length < planetCount && attempts < 200) {
      attempts++;
      final problem = MathProblem.random(widget.grade, difficulty: widget.level);
      if (!usedAnswers.contains(problem.answer)) {
        problems.add(problem);
        usedAnswers.add(problem.answer);
        debugPrint("[Gameplay] ✅ Generated unique planet #${problems.length}: ${problem.expression} = ${problem.answer}");
      } else {
        debugPrint("[Gameplay] ⚠️ Skipped duplicate answer: ${problem.answer}");
      }
    }

    final center = const Offset(400, 300);
    final baseRadius = 250.0;

    for (int i = 0; i < problems.length; i++) {
      final planetRadius = 40.0 + random.nextDouble() * 25;
      final mass = (planetRadius * planetRadius * 0.1).clamp(50.0, 200.0);
      final angle = (i * 2 * math.pi / planetCount) + random.nextDouble() * 0.5;
      final distance = baseRadius + random.nextDouble() * 100 - 50;

      final planet = Planet(
        id: i,
        position: Offset(center.dx + math.cos(angle) * distance,
            center.dy + math.sin(angle) * distance),
        radius: planetRadius,
        mass: mass,
        answer: problems[i].answer,
        problem: problems[i].expression,
        color: _getPlanetColor(i),
        visited: false,
      );
      planets.add(planet);
    }
  }

  void _generateTargetSequence() {
    targetSequence = planets.map((p) => p.answer).toList();
    switch (widget.level % 3) {
      case 0:
        targetSequence.sort();
        break; // Ascending
      case 1:
        targetSequence.sort((a, b) => b.compareTo(a));
        break; // Descending
      case 2:
        final evens = targetSequence.where((n) => n % 2 == 0).toList()..sort();
        final odds = targetSequence.where((n) => n % 2 == 1).toList()..sort();
        targetSequence = [...evens, ...odds];
        break;
    }
    nextTargetIndex = 0;
    debugPrint("[Gameplay] 🎯 New target sequence: $targetSequence");
  }

  void _landOnPlanet(Planet planet) {
    debugPrint("[Gameplay] 💥 Landing attempt on Planet ${planet.id} (${planet.answer})");
    setState(() => _showNextTargetHint = false);
    _startHintTimer();

    _lastLandedPlanetId = planet.id;
    _reLandingCooldown?.cancel();
    _reLandingCooldown =
        Timer(const Duration(milliseconds: 500), () => _lastLandedPlanetId = null);

    final bool isCorrect = nextTargetIndex < targetSequence.length &&
        planet.answer == targetSequence[nextTargetIndex];

    if (isCorrect) {
      debugPrint("[Gameplay] ✅ CORRECT landing!");
      planet.visited = true;
      hopper.landOn(planet);
      nextTargetIndex++;
      context.read<GameProvider>().addScore(100 * widget.grade);
      _addSuccessParticles(planet);
      if (nextTargetIndex >= targetSequence.length) _winGame();
    } else {
      debugPrint("[Gameplay] ❌ WRONG landing!");
      lives--;
      _addErrorParticles(planet);

      final bounceDirection = (hopper.position - planet.position).normalize();
      hopper.velocity = bounceDirection * 150;
      if (lives <= 0) _gameOver();
    }
    setState(() {});
  }

  void _updateGame() {
    if (!gameActive || !mounted) return;
    final dt = 0.016;

    if (hopper.isLanded) {
      setState(() {});
      return;
    }
    
    const double G = 150;
    Offset totalForce = Offset.zero;

    for (final planet in planets) {
      final distanceVector = planet.position - hopper.position;
      final distance = distanceVector.distance;
      if (distance < (planet.radius + 120) && distance > 0) {
        final direction = distanceVector.normalize();
        final forceMagnitude = (G * hopper.mass * planet.mass) / (distance * distance);
        totalForce += direction * forceMagnitude;
      }
    }
    
    hopper.velocity += totalForce * dt;
    hopper.velocity *= 0.998;
    hopper.position += hopper.velocity * dt;
    
    particles.removeWhere((p) => p.update(dt));

    for (final planet in planets) {
      if (_checkPlanetLanding(planet)) {
        _landOnPlanet(planet);
        break;
      }
    }

    setState(() {});
  }
  
  bool _checkPlanetLanding(Planet planet) {
    if (hopper.isLanded || planet.visited || planet.id == _lastLandedPlanetId) {
      return false;
    }
    final distance = (hopper.position - planet.position).distance;
    return distance < planet.radius;
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
        // FIX: Use a Column to separate the UI from the game area, preventing taps on UI from being blocked.
        child: SafeArea(
          child: Column(
            children: [
              _buildGameUI(), // Header is now separate and always on top.
              Expanded( // Game area takes the remaining space.
                child: Stack(
                  children: [
                    ..._buildBackgroundElements(),
                    _buildHintDisplay(),
                    _buildControlOverlay(), // Control overlay only covers this Expanded area.
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.9),
        border: Border(
            bottom:
                BorderSide(color: SpaceTheme.starYellow.withOpacity(0.3), width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              debugPrint("[UI] 🔙 Back button pressed, popping navigator.");
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Expanded(
              child: Text(S.of(context)!.planetHoppingTitle,
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 18))),
          Row(
              children: List.generate(
                  3,
                  (index) => Icon(index < lives ? Icons.favorite : Icons.favorite_border,
                      color: SpaceTheme.rocketRed, size: 22))),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: SpaceTheme.alienGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$nextTargetIndex/${targetSequence.length}',
                style: SpaceTheme.bodyStyle.copyWith(
                    color: SpaceTheme.alienGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildHintDisplay() {
    final bool shouldShow =
        _showNextTargetHint && gameActive && nextTargetIndex < targetSequence.length;
    return Positioned(
      top: 10, // Adjusted position to be clear of the header
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: shouldShow ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SpaceTheme.starYellow, width: 1.5)),
            child: Text(
                S.of(context)!.planetHoppingNextTargetValue(targetSequence[nextTargetIndex]),
                style: SpaceTheme.titleStyle
                    .copyWith(color: SpaceTheme.starYellow, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildControlOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTapDown: (details) {
          if (!gameActive) return;
          final tapPosition = details.localPosition;
          hopper.takeOff(tapPosition);
          setState(() {});
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // --- Particle Effects & Dialogs ---
  List<Widget> _buildBackgroundElements() {
    return [
      ...backgroundStars.map((star) => Positioned(
          left: star.position.dx,
          top: star.position.dy,
          child: Container(
              width: star.size,
              height: star.size,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(star.brightness),
                  shape: BoxShape.circle)))),
      ...planets.asMap().entries.map((entry) => Positioned(
          left: entry.value.position.dx - entry.value.radius,
          top: entry.value.position.dy - entry.value.radius,
          child: AnimatedBuilder(
              animation: _planetController,
              builder: (context, child) => PlanetWidget(
                  planet: entry.value,
                  isTarget: nextTargetIndex < targetSequence.length &&
                      entry.value.answer == targetSequence[nextTargetIndex],
                  rotationAnimation:
                      _planetController.value + (entry.key * 0.3))))),
      Positioned(
          left: hopper.position.dx - 15,
          top: hopper.position.dy - 15,
          child: SpaceHopperWidget(hopper: hopper)),
      ...particles.map((particle) => Positioned(
          left: particle.position.dx,
          top: particle.position.dy,
          child: ParticleWidget(particle: particle))),
      // Instruction overlay at the bottom, within the game area
      Positioned(
        bottom: 10,
        left: 0,
        right: 0,
        child: Center(
          child: AnimatedOpacity(
            opacity: _showInstructions ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpaceTheme.alienGreen, width: 1)),
              child: Text(S.of(context)!.planetHoppingInstructions,
                  style: SpaceTheme.bodyStyle
                      .copyWith(fontSize: 11, color: SpaceTheme.alienGreen),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ];
  }

  Color _getPlanetColor(int index) {
    final colors = [
      SpaceTheme.planetOrange, SpaceTheme.alienGreen, SpaceTheme.cosmicPink,
      SpaceTheme.starYellow, Colors.cyan, Colors.purple.shade300, Colors.teal
    ];
    return colors[index % colors.length];
  }

  void _addSuccessParticles(Planet planet) {
    debugPrint("[Animation] ✨ Spawning SUCCESS particles at ${planet.position}");
    for (int i = 0; i < 15; i++) {
      particles.add(ParticleEffect(
          position: planet.position,
          velocity: Offset((math.Random().nextDouble() - 0.5) * 200,
              (math.Random().nextDouble() - 0.5) * 200),
          color: SpaceTheme.starYellow,
          life: 1.5,
          size: 3.0));
    }
  }

  void _addErrorParticles(Planet planet) {
    debugPrint("[Animation] 🔥 Spawning ERROR particles at ${planet.position}");
    for (int i = 0; i < 10; i++) {
      particles.add(ParticleEffect(
          position: planet.position,
          velocity: Offset((math.Random().nextDouble() - 0.5) * 150,
              (math.Random().nextDouble() - 0.5) * 150),
          color: SpaceTheme.rocketRed,
          life: 1.0,
          size: 2.5));
    }
  }

  void _winGame() {
    if (!gameActive) return;
    debugPrint("[Gameplay] 🎉 WIN! Game finished.");
    gameActive = false;
    _hintTimer?.cancel();
    final bonus = lives * 200;
    context.read<GameProvider>().addScore(bonus);
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildWinDialog(bonus));
  }

  void _gameOver() {
    if (!gameActive) return;
    debugPrint("[Gameplay] ☠️ GAME OVER! Ran out of lives.");
    gameActive = false;
    _hintTimer?.cancel();
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildGameOverDialog());
  }

  void _resetGame() {
    debugPrint("[Gameplay] 🔄 Resetting game board.");
    setState(() {
      gameActive = true;
      lives = 3;
      nextTargetIndex = 0;
      particles.clear();
      _showNextTargetHint = false;
      _initializeGame();
    });
  }

  Widget _buildWinDialog(int bonus) {
    return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
            padding: const EdgeInsets.all(24),
            decoration: SpaceTheme.cardDecoration,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.public, size: 64, color: SpaceTheme.starYellow),
              const SizedBox(height: 16),
              Text(S.of(context)!.planetHoppingWinTitle,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(S.of(context)!.planetHoppingWinDescBonus(bonus),
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetGame();
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(S.of(context)!.exploreAgain)),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: Text(S.of(context)!.returnToBase))
              ])
            ])));
  }

  Widget _buildGameOverDialog() {
    return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
            padding: const EdgeInsets.all(24),
            decoration: SpaceTheme.cardDecoration,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning, size: 64, color: SpaceTheme.rocketRed),
              const SizedBox(height: 16),
              Text(S.of(context)!.planetHoppingLoseTitle,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(S.of(context)!.planetHoppingLoseDescCrash,
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetGame();
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: Text(S.of(context)!.retryMission)),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(S.of(context)!.returnToBase))
              ])
            ])));
  }
}

// ================================================================
// DATA MODELS & WIDGETS
// ================================================================

class SpaceHopper {
  Offset position = const Offset(100, 100);
  Offset velocity = Offset.zero;
  final double mass = 5.0;
  bool isLanded = false;
  int? landedOnPlanetId;

  void landOn(Planet planet) {
    isLanded = true;
    landedOnPlanetId = planet.id;
    velocity = Offset.zero;
    position = planet.position;
  }

  void takeOff(Offset tapPosition) {
    debugPrint("[Physics] 🚀 Hopper takeoff towards $tapPosition");
    isLanded = false;
    landedOnPlanetId = null;
    final direction = (tapPosition - position).normalize();
    velocity = direction * 450;
    debugPrint("[Physics] 🚀 New velocity: $velocity");
  }
}

class Planet {
  final int id;
  Offset position;
  double radius, mass;
  int answer;
  String problem;
  Color color;
  bool visited;

  Planet(
      {required this.id,
      required this.position,
      required this.radius,
      required this.mass,
      required this.answer,
      required this.problem,
      required this.color,
      required this.visited});
}

class ParticleEffect {
  Offset position, velocity;
  Color color;
  double life, maxLife, size;

  ParticleEffect(
      {required this.position,
      required this.velocity,
      required this.color,
      required this.life,
      required this.size})
      : maxLife = life;

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    velocity *= 0.95;
    return life <= 0;
  }
}

class Star {
  Offset position;
  double size, brightness;
  Star({required this.position, required this.size, required this.brightness});
}

class SpaceHopperWidget extends StatelessWidget {
  final SpaceHopper hopper;
  const SpaceHopperWidget({super.key, required this.hopper});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
                colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]),
            boxShadow: [
              BoxShadow(
                  color: SpaceTheme.starYellow.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2)
            ]),
        child: const Icon(Icons.rocket_launch, color: Colors.white, size: 18));
  }
}

class PlanetWidget extends StatelessWidget {
  final Planet planet;
  final bool isTarget;
  final double rotationAnimation;
  const PlanetWidget(
      {super.key,
      required this.planet,
      required this.isTarget,
      required this.rotationAnimation});

  @override
  Widget build(BuildContext context) {
    final fontSize = (12 + planet.radius * 0.25).clamp(14.0, 36.0);
    return Transform.rotate(
      angle: rotationAnimation,
      child: Container(
        width: planet.radius * 2,
        height: planet.radius * 2,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              planet.color,
              planet.color.withOpacity(0.7),
              planet.color.withOpacity(0.9)
            ], stops: const [
              0.0,
              0.7,
              1.0
            ]),
            border: Border.all(
                color: isTarget
                    ? SpaceTheme.starYellow
                    : (planet.visited ? SpaceTheme.alienGreen : Colors.transparent),
                width: isTarget ? 3 : (planet.visited ? 2 : 0)),
            boxShadow: [
              BoxShadow(
                  color: planet.color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2),
              if (isTarget)
                BoxShadow(
                    color: SpaceTheme.starYellow.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 3)
            ]),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: PlanetSurfacePainter(planet.color))),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(planet.problem,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize),
                  textAlign: TextAlign.center),
            ),
          ),
          if (planet.visited)
            Positioned(
                top: 5,
                right: 5,
                child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        color: SpaceTheme.alienGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 14))),
        ]),
      ),
    );
  }
}

class ParticleWidget extends StatelessWidget {
  final ParticleEffect particle;
  const ParticleWidget({super.key, required this.particle});

  @override
  Widget build(BuildContext context) {
    final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);
    return Container(
        width: particle.size,
        height: particle.size,
        decoration: BoxDecoration(
            color: particle.color.withOpacity(opacity), shape: BoxShape.circle));
  }
}

class PlanetSurfacePainter extends CustomPainter {
  final Color planetColor;
  PlanetSurfacePainter(this.planetColor);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = planetColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;
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