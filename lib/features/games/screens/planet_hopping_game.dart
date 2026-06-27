// lib/features/games/screens/planet_hopping_game.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../../../core/services/sri_service.dart';
import 'package:flutter/foundation.dart';

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
  late AnimationController _gravityController; // For pulsing gravity effect
  late AnimationController _planetController;
  Timer? _hintTimer;
  Timer? _reLandingCooldown;

  // --- Game State ---
  List<Planet> planets = [];
  List<ParticleEffect> particles = [];
  List<GravityWave> gravityWaves = []; // NEW: For visual gravity effects
  List<Star> backgroundStars = [];
  SpaceHopper hopper = SpaceHopper();
  List<int> targetSequence = [];
  bool gameActive = true;
  int lives = 3;
  int nextTargetIndex = 0;
  int? _lastLandedPlanetId;
  Planet? _targetPlanet; // NEW: Track which planet we're flying to

  // --- Progression Tracking ---
  final List<MathProblem> _attemptedProblems = []; // Track problems we've attempted

  // --- UI State ---
  bool _showInstructions = true;
  bool _showNextTargetHint = false;
  double _gameWidth = 0.0;
  double _gameHeight = 0.0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("[Game Init] 🚀 Planet Hopping game initializing...");

    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16), // ~60 FPS
      vsync: this,
    )..repeat();

    _gravityController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _planetController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    // Defer initialization until the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeGame();
        _gameController.addListener(_updateGame);
      }
    });

    Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showInstructions = false);
    });
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint("[Game Dispose] 🛑 Disposing all controllers and timers.");
    _gameController.dispose();
    _gravityController.dispose();
    _planetController.dispose();
    _hintTimer?.cancel();
    _reLandingCooldown?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    if (kDebugMode) debugPrint("[Gameplay] ✨ Initializing new game board.");
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
    hopper.isLanded = true;
    hopper.velocity = Offset.zero;
    _targetPlanet = null; // NEW: Reset target planet
    gravityWaves.clear(); // NEW: Clear gravity waves
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && gameActive) {
        setState(() => _showNextTargetHint = true);
      }
    });
  }

  void _generateBackgroundStars() {
    backgroundStars.clear();
    final random = math.Random();
    for (int i = 0; i < 80; i++) {
      backgroundStars.add(Star(
          position: Offset(random.nextDouble() * 1500, random.nextDouble() * 1000),
          size: random.nextDouble() * 2 + 1,
          brightness: random.nextDouble() * 0.8 + 0.2));
    }
  }

  // ### START: MODIFIED PLANET GENERATION LOGIC ###
  void _generatePlanets() {
    planets.clear();
    final random = math.Random();
    final difficulty = widget.grade + widget.level;
    final planetCount = (5 + (difficulty / 4)).clamp(5, 8).toInt();
    
    final problems = <MathProblem>[];
    final usedAnswers = <int>{};
    if (kDebugMode) debugPrint("[Gameplay] Generating $planetCount unique planets...");

    final sriService = context.read<SriService>();
    final gameProvider = context.read<GameProvider>();
    final screenSize = MediaQuery.of(context).size;

    int attempts = 0;
    while (problems.length < planetCount && attempts < 100) {
      attempts++;
      final problem = MathProblem.generateProblem(gameProvider, widget.level, sriService);
      
      if (!usedAnswers.contains(problem.answer)) {
        problems.add(problem);
        usedAnswers.add(problem.answer);
      }
    }

    for (int i = 0; i < problems.length; i++) {
      final planetRadius = (32.0 + random.nextDouble() * 16).clamp(30.0, 45.0);
      
      // This helper function now ensures the position is valid.
      final position = _findNonOverlappingPosition(screenSize, planetRadius, planets);

      planets.add(Planet(
        id: i,
        position: position,
        radius: planetRadius,
        mass: (planetRadius * 0.1).clamp(3.0, 5.0),
        problem: problems[i],
        color: _getPlanetColor(i),
        visited: false,
      ));
    }
  }

  // This is the helper function to prevent overlaps.
  Offset _findNonOverlappingPosition(Size screenSize, double newPlanetRadius, List<Planet> existingPlanets) {
    final random = math.Random();
    const int maxAttempts = 100;
    const double padding = 15.0; // Extra space between planets

    for (int i = 0; i < maxAttempts; i++) {
      // Generate a random position within safe screen bounds
      final double x = random.nextDouble() * (screenSize.width - newPlanetRadius * 2 - 100) + newPlanetRadius + 50;
      final double y = random.nextDouble() * (screenSize.height - newPlanetRadius * 2 - 200) + newPlanetRadius + 100;
      final newPosition = Offset(x, y);
      
      bool hasOverlap = false;
      // Check against all previously placed planets
      for (final existingPlanet in existingPlanets) {
        final distance = (newPosition - existingPlanet.position).distance;
        final minDistance = newPlanetRadius + existingPlanet.radius + padding;
        if (distance < minDistance) {
          hasOverlap = true;
          break; // Overlap found, break inner loop to try a new position
        }
      }
      
      // If no overlaps were found after checking all existing planets, this position is valid
      if (!hasOverlap) {
        return newPosition;
      }
    }
    
    // Fallback if no position could be found after many attempts (rare)
    if (kDebugMode) debugPrint("Could not find a non-overlapping position after $maxAttempts attempts. Placing randomly.");
    return Offset(
      random.nextDouble() * (screenSize.width - newPlanetRadius * 2) + newPlanetRadius,
      random.nextDouble() * (screenSize.height - newPlanetRadius * 2 - 150) + newPlanetRadius + 75,
    );
  }
  // ### END: MODIFIED PLANET GENERATION LOGIC ###

  void _generateTargetSequence() {
    targetSequence = planets.map((p) => p.answer).toList();
    switch (widget.level % 3) {
      case 0: targetSequence.sort(); break; // Ascending
      case 1: targetSequence.sort((a, b) => b.compareTo(a)); break; // Descending
      case 2:
        final evens = targetSequence.where((n) => n % 2 == 0).toList()..sort();
        final odds = targetSequence.where((n) => n % 2 == 1).toList()..sort();
        targetSequence = [...evens, ...odds];
        break;
    }
    nextTargetIndex = 0;
    if (kDebugMode) debugPrint("[Gameplay] 🎯 New target sequence: $targetSequence");
  }

  void _landOnPlanet(Planet planet) {
    if (kDebugMode) debugPrint("[Gameplay] 💥 Landing attempt on Planet ${planet.id} (${planet.answer})");
    setState(() => _showNextTargetHint = false);
    _startHintTimer();

    _lastLandedPlanetId = planet.id;
    _targetPlanet = null;
    _reLandingCooldown?.cancel();
    _reLandingCooldown = Timer(const Duration(milliseconds: 500), () => _lastLandedPlanetId = null);

    final bool isCorrect = nextTargetIndex < targetSequence.length &&
                          planet.answer == targetSequence[nextTargetIndex];

    // Track this attempt - we'll report all attempts at the end
    _attemptedProblems.add(planet.problem);
    if (kDebugMode) debugPrint("[Gameplay] 📝 Tracked problem: ${planet.problem.expression} (${isCorrect ? 'correct' : 'incorrect'})");

    if (isCorrect) {
      debugPrint("[Gameplay] ✅ CORRECT landing!");
      HapticFeedback.lightImpact();
      planet.visited = true;
      hopper.landOn(planet);
      nextTargetIndex++;
      context.read<GameProvider>().addScore(100 * widget.grade);
      _addSuccessParticles(planet);

      if (nextTargetIndex >= targetSequence.length) _winGame();
    } else {
      if (kDebugMode) debugPrint("[Gameplay] ❌ WRONG landing!");
      HapticFeedback.heavyImpact();
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
    const dt = 0.016;

    // --- Core Movement (Ballistic Trajectory) ---
    if (!hopper.isLanded) {
      hopper.velocity *= 0.998; // Air drag
      hopper.position += hopper.velocity * dt;
    }

    // --- ENHANCED Gravitational Pull ---
    if (!hopper.isLanded) {
      Offset gravityForce = Offset.zero;
      const baseGravityStrength = 0.8; // Increased from 0.2
      final gravityStrength = baseGravityStrength + (_gravityController.value * 0.6); // More pronounced pulsation

      for (final planet in planets) {
        final distanceVector = planet.position - hopper.position;
        final distance = distanceVector.distance;
        
        // Larger gravity field and stronger effect
        if (distance < (planet.radius + 200) && distance > 1) {
          final direction = distanceVector.normalize();
          final pullMagnitude = (gravityStrength * planet.mass * 15) / (distance * 0.05); // Much stronger
          gravityForce += direction * pullMagnitude;
          
          // NEW: Create visual gravity waves occasionally
          if (math.Random().nextDouble() < 0.03) {
            gravityWaves.add(GravityWave(
              center: planet.position,
              maxRadius: planet.radius + 80,
              color: planet.color.withValues(alpha: 0.3),
            ));
          }
        }
      }
      
      // Apply the gravitational force to velocity (more realistic physics)
      hopper.velocity += gravityForce * dt;
      
      // Also add some position drift for immediate visual feedback
      hopper.position += gravityForce * dt * 0.3;
    }

    // --- Boundary Checks ---
    if (_gameWidth > 0 && _gameHeight > 0) {
      const double bounceDamping = 0.5;
      const double margin = 15;
      if (hopper.position.dx < margin) {
        hopper.position = Offset(margin, hopper.position.dy);
        hopper.velocity = Offset(-hopper.velocity.dx * bounceDamping, hopper.velocity.dy);
      } else if (hopper.position.dx > _gameWidth - margin) {
        hopper.position = Offset(_gameWidth - margin, hopper.position.dy);
        hopper.velocity = Offset(-hopper.velocity.dx * bounceDamping, hopper.velocity.dy);
      }
      if (hopper.position.dy < margin) {
        hopper.position = Offset(hopper.position.dx, margin);
        hopper.velocity = Offset(hopper.velocity.dx, -hopper.velocity.dy * bounceDamping);
      } else if (hopper.position.dy > _gameHeight - margin) {
        hopper.position = Offset(hopper.position.dx, _gameHeight - margin);
        hopper.velocity = Offset(hopper.velocity.dx, -hopper.velocity.dy * bounceDamping);
      }
    }
    
    // Update visual effects
    particles.removeWhere((p) => p.update(dt));
    gravityWaves.removeWhere((wave) => wave.update(dt)); // NEW: Update gravity waves
    
    // Check for planet collisions
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
    
    // NEW: If we have a target planet, only allow landing on that specific planet
    if (_targetPlanet != null && planet.id != _targetPlanet!.id) {
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
        child: SafeArea(
          child: Column(
            children: [
              _buildGameUI(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _gameWidth = constraints.maxWidth;
                    _gameHeight = constraints.maxHeight;
                    return Stack(
                      children: [
                        ..._buildBackgroundElements(),
                        _buildHintDisplay(),
                        _buildControlOverlay(),
                      ],
                    );
                  },
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
        color: SpaceTheme.deepSpace.withValues(alpha: 0.9),
        border: Border(
            bottom:
                BorderSide(color: SpaceTheme.starYellow.withValues(alpha: 0.3), width: 2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (kDebugMode) debugPrint("[UI] 🔙 Back button pressed, popping navigator.");
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(S.of(context)!.planetHoppingTitle,
                    style: SpaceTheme.titleStyle),
              )),
          Semantics(
            label: S.of(context)!.a11yLivesRemaining(lives, 3),
            container: true,
            child: ExcludeSemantics(
              child: Row(
                  children: List.generate(
                      3,
                      (index) => Icon(index < lives ? Icons.favorite : Icons.favorite_border,
                          color: SpaceTheme.rocketRed, size: 22))),
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            label: S.of(context)!.a11yProgress(nextTargetIndex, targetSequence.length),
            liveRegion: true,
            container: true,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: SpaceTheme.alienGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$nextTargetIndex/${targetSequence.length}',
                      style: SpaceTheme.bodyStyle.copyWith(
                          color: SpaceTheme.alienGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintDisplay() {
    final bool shouldShow = _showNextTargetHint && 
                           gameActive && 
                           nextTargetIndex < targetSequence.length;
                           
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: shouldShow ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SpaceTheme.starYellow, width: 1.5)),
            child: Text(
                shouldShow
                    ? S.of(context)!.planetHoppingNextTarget(targetSequence[nextTargetIndex])
                    : '',
                style: SpaceTheme.titleStyle
                    .copyWith(color: SpaceTheme.starYellow, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildControlOverlay() {
    return Positioned.fill(
      child: Semantics(
        label: S.of(context)!.a11yGameArea,
        hint: 'Tap a planet to launch toward it',
        child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          if (!gameActive) return;
          final tapPosition = details.localPosition;
          
          // NEW: Check if player clicked on a planet
          Planet? clickedPlanet;
          for (final planet in planets) {
            final distance = (tapPosition - planet.position).distance;
            if (distance < planet.radius) {
              clickedPlanet = planet;
              break;
            }
          }
          
          if (clickedPlanet != null) {
            // Player clicked on a planet - fly directly to it
            _targetPlanet = clickedPlanet;
            hopper.takeOff(clickedPlanet.position);
            if (kDebugMode) debugPrint("[Gameplay] 🎯 Flying to planet ${clickedPlanet.id} (${clickedPlanet.answer})");
          } else {
            // Player clicked on empty space - normal takeoff
            _targetPlanet = null;
            hopper.takeOff(tapPosition);
          }
          setState(() {});
        },
        child: Container(color: Colors.transparent),
      ),
      ),
    );
  }

  List<Widget> _buildBackgroundElements() {
    return [
      // Background stars
      ...backgroundStars.map((star) => Positioned(
          left: star.position.dx,
          top: star.position.dy,
          child: Container(
              width: star.size,
              height: star.size,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: star.brightness),
                  shape: BoxShape.circle)))),
      
      // NEW: Gravity wave effects
      ...gravityWaves.map((wave) => Positioned(
          left: wave.center.dx - wave.currentRadius,
          top: wave.center.dy - wave.currentRadius,
          child: GravityWaveWidget(wave: wave))),
      
      // Planets
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
      
      // Space hopper
      Positioned(
          left: hopper.position.dx - 15,
          top: hopper.position.dy - 15,
          child: SpaceHopperWidget(hopper: hopper)),
      
      // Particles
      ...particles.map((particle) => Positioned(
          left: particle.position.dx,
          top: particle.position.dy,
          child: ParticleWidget(particle: particle))),
      
      // Instructions
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
                  color: Colors.black.withValues(alpha: 0.7),
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
    if (kDebugMode) debugPrint("[Animation] ✨ Spawning SUCCESS particles at ${planet.position}");
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
    if (kDebugMode) debugPrint("[Animation] 🔥 Spawning ERROR particles at ${planet.position}");
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
    if (kDebugMode) debugPrint("[Gameplay] 🎉 WIN! Game finished.");
    gameActive = false;
    _hintTimer?.cancel();
    
    final bonus = lives * 200;
    final totalScore = bonus + (100 * widget.grade * targetSequence.length);
    
    // UNIFIED PROGRESSION: Report all attempted problems
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'planet_hopping',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: _attemptedProblems,
    ));
    
    if (kDebugMode) debugPrint("[Gameplay] 📊 Reported ${_attemptedProblems.length} attempted problems");
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildWinDialog(bonus),
    );
  }

  void _gameOver() {
    if (!gameActive) return;
    if (kDebugMode) debugPrint("[Gameplay] ☠️ GAME OVER! Ran out of lives.");
    gameActive = false;
    _hintTimer?.cancel();
    
    // UNIFIED PROGRESSION: Report failure with attempted problems for learning
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'planet_hopping',
      difficulty: widget.level,
      mathProblems: _attemptedProblems,
    ));
    
    if (kDebugMode) debugPrint("[Gameplay] 📊 Reported ${_attemptedProblems.length} attempted problems (loss)");
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGameOverDialog(),
    );
  }

  void _resetGame() {
    if (kDebugMode) debugPrint("[Gameplay] 🔄 Resetting game board.");
    setState(() {
      gameActive = true;
      lives = 3;
      nextTargetIndex = 0;
      particles.clear();
      gravityWaves.clear(); // Clear gravity waves
      _targetPlanet = null; // Clear target planet
      _showNextTargetHint = false;
      _attemptedProblems.clear(); // Clear attempt history for fresh start
    });
    // Re-initialize game state, which now includes non-overlapping planet generation
    _initializeGame();
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
                    autofocus: true,
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
                    autofocus: true,
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
    if (kDebugMode) debugPrint("[Physics] 🚀 Hopper takeoff towards $tapPosition");
    isLanded = false;
    landedOnPlanetId = null;
    final direction = (tapPosition - position).normalize();
    velocity = direction * 450;
    if (kDebugMode) debugPrint("[Physics] 🚀 New velocity: $velocity");
  }
}

class Planet {
  final int id;
  Offset position;
  double radius, mass;
  final MathProblem problem;
  Color color;
  bool visited;

  Planet(
      {required this.id,
      required this.position,
      required this.radius,
      required this.mass,
      required this.problem,
      required this.color,
      required this.visited});

  int get answer => problem.answer;
  String get problemExpression => problem.expression;
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

// NEW: Gravity wave effect class
class GravityWave {
  Offset center;
  double currentRadius = 0;
  double maxRadius;
  Color color;
  double life = 1.0;
  double maxLife = 1.0;

  GravityWave({
    required this.center,
    required this.maxRadius,
    required this.color,
  });

  bool update(double dt) {
    currentRadius += (maxRadius / maxLife) * dt;
    life -= dt;
    return life <= 0 || currentRadius >= maxRadius;
  }

  double get opacity => (life / maxLife).clamp(0.0, 1.0);
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
                  color: SpaceTheme.starYellow.withValues(alpha: 0.6),
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
              planet.color.withValues(alpha: 0.7),
              planet.color.withValues(alpha: 0.9)
            ], stops: const [
              0.0,
              0.7,
              1.0
            ]),
            border: Border.all(
                color: planet.visited ? SpaceTheme.alienGreen : Colors.transparent,
                width: planet.visited ? 2 : 0),
            boxShadow: [
              BoxShadow(
                  color: planet.color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2),
            ]),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: PlanetSurfacePainter(planet.color))),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  planet.problemExpression
                      .replaceAll('÷', context.read<GameProvider>().divisionSymbol)
                      .replaceAll('×', context.read<GameProvider>().multiplicationSymbol),
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
            color: particle.color.withValues(alpha: opacity), shape: BoxShape.circle));
  }
}

// NEW: Gravity wave visual widget
class GravityWaveWidget extends StatelessWidget {
  final GravityWave wave;
  const GravityWaveWidget({super.key, required this.wave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wave.currentRadius * 2,
      height: wave.currentRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: wave.color.withValues(alpha: wave.opacity * 0.6),
          width: 2,
        ),
      ),
    );
  }
}

class PlanetSurfacePainter extends CustomPainter {
  final Color planetColor;
  PlanetSurfacePainter(this.planetColor);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = planetColor.withValues(alpha: 0.3)
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