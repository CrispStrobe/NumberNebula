import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class HyperdriveGatesGame extends StatefulWidget {
  final int grade;
  final int level;

  const HyperdriveGatesGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<HyperdriveGatesGame> createState() => _HyperdriveGatesGameState();
}

class _HyperdriveGatesGameState extends State<HyperdriveGatesGame>
    with TickerProviderStateMixin {
  
  late AnimationController _gameController;
  late AnimationController _thrusterController;
  late AnimationController _backgroundController;
  late Timer _gameTimer;
  
  // Game state
  List<HyperdriveGate> gates = [];
  List<ParticleEffect> particles = [];
  List<Star> backgroundStars = [];
  Spaceship spaceship = Spaceship();
  
  double gameSpeed = 100.0; // pixels per second
  double gateSpawnTimer = 0.0;
  int correctGatesPassedThrough = 0;
  int targetGatesNeeded = 10;
  bool gameActive = true;
  double lives = 3.0; // Changed to double to fix type error
  
  // Current math problem for gates
  MathProblem? currentProblem;
  int correctAnswer = 0;
  
  @override
  void initState() {
    super.initState();
    
    _gameController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();
    
    _thrusterController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _initializeGame();
    
    _gameController.addListener(_updateGame);
  }
  
  @override
  void dispose() {
    _gameController.dispose();
    _thrusterController.dispose();
    _backgroundController.dispose();
    _gameTimer.cancel();
    super.dispose();
  }
  
  void _initializeGame() {
    // Grade-based difficulty
    switch (widget.grade) {
      case 3:
        targetGatesNeeded = 8;
        gameSpeed = 80.0;
        break;
      case 4:
        targetGatesNeeded = 10;
        gameSpeed = 100.0;
        break;
      case 5:
        targetGatesNeeded = 12;
        gameSpeed = 120.0;
        break;
      case 6:
      default:
        targetGatesNeeded = 15;
        gameSpeed = 140.0;
        break;
    }
    
    _generateBackgroundStars();
    _generateNewProblem();
    
    // Start game timer for increasing difficulty
    _gameTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (gameActive) {
        setState(() {
          gameSpeed += 20; // Increase speed every 10 seconds
        });
      }
    });
  }
  
  void _generateBackgroundStars() {
    backgroundStars.clear();
    final random = math.Random();
    
    for (int i = 0; i < 100; i++) {
      backgroundStars.add(Star(
        position: Offset(
          random.nextDouble() * 2000,
          random.nextDouble() * 1000,
        ),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 50 + 25,
        brightness: random.nextDouble(),
      ));
    }
  }
  
  void _generateNewProblem() {
    final difficulty = widget.grade + widget.level;
    currentProblem = MathProblem.random(widget.grade, difficulty: difficulty);
    correctAnswer = currentProblem!.answer;
  }
  
  void _updateGame() {
    if (!gameActive) return;
    
    final dt = 0.016; // 60 FPS
    final screenSize = MediaQuery.of(context).size;
    
    setState(() {
        // Update background stars with parallax effect
        for (var star in backgroundStars) {
        star.position = Offset(
            star.position.dx - (star.speed + gameSpeed * 0.1) * dt,
            star.position.dy,
        );
        
        if (star.position.dx < -10) {
            star.position = Offset(
            screenSize.width + 10,
            math.Random().nextDouble() * screenSize.height,
            );
        }
        }
        
        // Update spaceship physics with improved responsiveness
        spaceship.update(dt);
        
        // Dynamic gate spawning based on game speed and level
        gateSpawnTimer += dt;
        final dynamicSpawnRate = 2.0 - (gameSpeed / 200.0).clamp(0.0, 1.5); // Faster spawning as speed increases
        final levelSpawnModifier = 1.0 - (widget.level * 0.05).clamp(0.0, 0.5); // Higher levels spawn faster
        final actualSpawnRate = (dynamicSpawnRate * levelSpawnModifier).clamp(0.5, 3.0);
        
        if (gateSpawnTimer > actualSpawnRate) {
        _spawnGate(screenSize);
        gateSpawnTimer = 0.0;
        }
        
        // Update gates with collision detection
        gates.removeWhere((gate) {
        // Update gate position
        gate.position = Offset(
            gate.position.dx - gameSpeed * dt,
            gate.position.dy,
        );
        
        // Check collision with spaceship
        if (_checkGateCollision(gate)) {
            _handleGateCollision(gate);
            return true;
        }
        
        // Remove off-screen gates and penalize missed correct gates
        if (gate.position.dx < -100) {
            if (gate.isCorrect) {
            // Player missed a correct gate - small penalty
            lives = (lives - 0.1).clamp(0.0, 3.0);
            }
            return true;
        }
        
        return false;
        });
        
        // Update particles with improved lifecycle management
        particles.removeWhere((particle) {
        particle.update(dt);
        return particle.life <= 0;
        });
        
        // Add thruster particles with intensity based on movement
        if (spaceship.thrusting) {
        _addThrusterParticles();
        }
        
        // Add ambient space particles for atmosphere
        if (math.Random().nextDouble() < 0.1) {
        _addAmbientParticles(screenSize);
        }
        
        // Check win condition
        if (correctGatesPassedThrough >= targetGatesNeeded) {
        _winGame();
        }
        
        // Check lose condition with proper double comparison
        if (lives <= 0.0) {
        _gameOver();
        }
    });
  }
  
  void _spawnGate(Size screenSize) {
    final random = math.Random();
    final difficulty = DifficultyManager.getDifficulty(widget.grade, widget.level);
    
    // Determine if this should be a correct gate (balanced probability)
    final correctGateChance = 0.4 + (correctGatesPassedThrough / targetGatesNeeded) * 0.2;
    final isCorrectGate = random.nextDouble() < correctGateChance;
    
    int gateAnswer;
    Color gateColor;
    bool isCorrect;
    
    if (isCorrectGate) {
        gateAnswer = correctAnswer;
        gateColor = SpaceTheme.alienGreen;
        isCorrect = true;
    } else {
        // Generate varied wrong answers based on difficulty
        final wrongAnswerStrategies = [
        () => correctAnswer + random.nextInt(10) + 1, // Close but wrong
        () => correctAnswer - random.nextInt(10) - 1, // Close but wrong (negative)
        () => correctAnswer * 2, // Double
        () => correctAnswer ~/ 2, // Half
        () => random.nextInt(difficulty.numberRange['max']!) + 1, // Random in range
        () => correctAnswer + (random.nextBool() ? 1 : -1) * (10 + random.nextInt(20)), // Moderate offset
        ];
        
        do {
        final strategy = wrongAnswerStrategies[random.nextInt(wrongAnswerStrategies.length)];
        gateAnswer = strategy();
        } while (gateAnswer == correctAnswer || gateAnswer <= 0);
        
        gateColor = SpaceTheme.rocketRed;
        isCorrect = false;
    }
    
    // Varied gate positioning with some randomness
    final gateY = random.nextDouble() * (screenSize.height - 200) + 100;
    
    gates.add(HyperdriveGate(
        position: Offset(screenSize.width + 60, gateY),
        answer: gateAnswer,
        problem: currentProblem!.expression,
        isCorrect: isCorrect,
        color: gateColor,
    ));
    }
  
  bool _checkGateCollision(HyperdriveGate gate) {
    final spaceshipRect = Rect.fromCenter(
        center: spaceship.position,
        width: 50, // Slightly smaller hitbox for better feel
        height: 35,
    );
    
    final gateRect = Rect.fromCenter(
        center: gate.position,
        width: 100, // Slightly smaller gate hitbox
        height: 70,
    );
    
    return spaceshipRect.overlaps(gateRect);
    }
  
  void _handleGateCollision(HyperdriveGate gate) {
    if (gate.isCorrect) {
      // Correct gate - boost forward!
      correctGatesPassedThrough++;
      context.read<GameProvider>().addScore(50 * widget.grade);
      _addBoostEffect();
      _generateNewProblem(); // Generate new problem for next gates
      
      // Add celebration particles
      for (int i = 0; i < 10; i++) {
        particles.add(ParticleEffect(
          position: gate.position,
          velocity: Offset(
            (math.Random().nextDouble() - 0.5) * 200,
            (math.Random().nextDouble() - 0.5) * 200,
          ),
          color: SpaceTheme.starYellow,
          life: 1.0,
          size: 3.0,
        ));
      }
    } else {
      // Wrong gate - lose life and damage effect
      lives -= 1.0; // Properly subtract from double
      _addDamageEffect();
      
      // Add explosion particles
      for (int i = 0; i < 15; i++) {
        particles.add(ParticleEffect(
          position: spaceship.position,
          velocity: Offset(
            (math.Random().nextDouble() - 0.5) * 300,
            (math.Random().nextDouble() - 0.5) * 300,
          ),
          color: SpaceTheme.rocketRed,
          life: 0.8,
          size: 4.0,
        ));
      }
    }
  }
  
  void _addThrusterParticles() {
    final random = math.Random();
    final particleCount = (spaceship.thrustIntensity * 3 + 1).round();
    
    for (int i = 0; i < particleCount; i++) {
        particles.add(ParticleEffect(
        position: Offset(
            spaceship.position.dx - 35 + random.nextDouble() * 10,
            spaceship.position.dy + (random.nextDouble() - 0.5) * 25,
        ),
        velocity: Offset(
            -120 - random.nextDouble() * 80,
            (random.nextDouble() - 0.5) * 30,
        ),
        color: Color.lerp(
            SpaceTheme.planetOrange,
            SpaceTheme.starYellow,
            random.nextDouble(),
        )!,
        life: 0.3 + random.nextDouble() * 0.3,
        size: 1.5 + random.nextDouble() * 1.5,
        ));
    }
    }

  void _addAmbientParticles(Size screenSize) {
    final random = math.Random();
    particles.add(ParticleEffect(
        position: Offset(
        screenSize.width + 10,
        random.nextDouble() * screenSize.height,
        ),
        velocity: Offset(-gameSpeed * 0.3, 0),
        color: Colors.white.withOpacity(0.3 + random.nextDouble() * 0.4),
        life: 2.0 + random.nextDouble() * 3.0,
        size: 0.5 + random.nextDouble() * 1.5,
    ));
    }
  
  void _addBoostEffect() {
    spaceship.boost();
    // Add speed boost visual effect
  }
  
  void _addDamageEffect() {
    spaceship.damage();
    // Add screen shake or damage visual effect
  }
  
  void _winGame() {
    gameActive = false;
    final timeBonus = (targetGatesNeeded * 100);
    context.read<GameProvider>().addScore(timeBonus);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildWinDialog(),
    );
  }
  
  void _gameOver() {
    gameActive = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGameOverDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF000510),
              Color(0xFF1A1A3E),
              Color(0xFF000510),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background stars (unchanged)
              ...backgroundStars.map((star) => Positioned(
                left: star.position.dx,
                top: star.position.dy,
                child: Container(
                  width: star.size,
                  height: star.size,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(star.brightness),
                    shape: BoxShape.circle,
                  ),
                ),
              )).toList(),
              
              // Game UI Header (with back button fix)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace.withOpacity(0.8),
                    border: Border(
                      bottom: BorderSide(
                        color: SpaceTheme.starYellow.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // FIX: Proper cleanup on back
                          setState(() => gameActive = false);
                          _gameTimer.cancel();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      Expanded(
                        child: Text(
                          'Hyperdrive Gates',
                          style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
                        ),
                      ),
                      
                      // Lives display
                      Row(
                        children: List.generate(3, (index) {
                          return Icon(
                            index < lives.floor() ? Icons.favorite : Icons.favorite_border,
                            color: SpaceTheme.rocketRed,
                            size: 20,
                          );
                        }),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Progress
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SpaceTheme.alienGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$correctGatesPassedThrough/$targetGatesNeeded',
                          style: SpaceTheme.bodyStyle.copyWith(
                            color: SpaceTheme.alienGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Current Problem Display
              Positioned(
                top: 80,
                left: 20,
                right: 20, // FIX: Add right constraint
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SpaceTheme.starYellow, width: 2),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calculate, color: SpaceTheme.starYellow, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            S.of(context)!.solve,
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: 14,
                              color: SpaceTheme.starYellow,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (currentProblem != null) ...[
                        Text(
                          currentProblem!.expression,
                          style: SpaceTheme.titleStyle.copyWith(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fly through gates with: ${correctAnswer}',
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 16, 
                            color: SpaceTheme.alienGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Gates
              ...gates.map((gate) => Positioned(
                left: gate.position.dx - 60,
                top: gate.position.dy - 40,
                child: HyperdriveGateWidget(gate: gate),
              )).toList(),
              
              // Spaceship
              Positioned(
                left: spaceship.position.dx - 30,
                top: spaceship.position.dy - 20,
                child: SpaceshipWidget(
                  spaceship: spaceship,
                  thrusterAnimation: _thrusterController,
                ),
              ),
              
              // Particles
              ...particles.map((particle) => Positioned(
                left: particle.position.dx,
                top: particle.position.dy,
                child: ParticleWidget(particle: particle),
              )).toList(),
              
              // FIX: Better control instructions
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceTheme.alienGreen, width: 1),
                  ),
                  child: Text(
                    S.of(context)!.hyperdriveGatesInstructions,
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 12,
                      color: SpaceTheme.alienGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              // FIX: Improved touch control overlay
              _buildControlOverlay(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: SpaceTheme.starYellow.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          
          const SizedBox(width: 10),
          
          Expanded(
            child: Text(
              'Hyperdrive Gates',
              style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
            ),
          ),
          
          // Lives display
          Row(
            children: List.generate(3, (index) {
              return Icon(
                index < lives.floor() ? Icons.favorite : Icons.favorite_border,
                color: SpaceTheme.rocketRed,
                size: 20,
              );
            }),
          ),
          
          const SizedBox(width: 20),
          
          // Progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.alienGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$correctGatesPassedThrough/$targetGatesNeeded',
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.alienGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProblemDisplay() {
    if (currentProblem == null) return Container();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.solve,
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 12,
              color: SpaceTheme.starYellow,
            ),
          ),
          Text(
            currentProblem!.expression,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 24),
          ),
          Text(
            'Fly through gates with answer: $correctAnswer',
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlOverlay() {
    return Positioned.fill(
      top: 140, // FIX: Start below UI elements
      child: GestureDetector(
        onPanStart: (details) {
          if (!gameActive) return;
          setState(() {
            spaceship.thrusting = true;
            spaceship.targetY = details.localPosition.dy + 140; // FIX: Account for UI offset
          });
        },
        onPanUpdate: (details) {
          if (!gameActive) return;
          
          setState(() {
            // FIX: Smooth continuous steering
            spaceship.targetY = (details.localPosition.dy + 140).clamp(160.0, MediaQuery.of(context).size.height - 40.0);
            spaceship.thrusting = true;
          });
        },
        onPanEnd: (details) {
          setState(() {
            spaceship.thrusting = false;
          });
        },
        // FIX: Add tap control for quick navigation
        onTap: () {
          if (!gameActive) return;
          setState(() {
            spaceship.thrusting = !spaceship.thrusting;
          });
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }
  
  Widget _buildWinDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flight_takeoff,
              size: 64,
              color: SpaceTheme.starYellow,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.hyperdriveGatesWinTitle,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You successfully navigated through $targetGatesNeeded gates!\nYou\'re ready for deep space missions!',
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetGame();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.flyAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.missionCompleteStatus),
                ),
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
            const Icon(
              Icons.warning,
              size: 64,
              color: SpaceTheme.rocketRed,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.hyperdriveGatesLoseTitle,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your ship took too much damage!\nReturn to base for repairs and try again.',
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetGame();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.retryMission),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.returnToBase),
                ),
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
      lives = 3.0;
      correctGatesPassedThrough = 0;
      gates.clear();
      particles.clear();
      spaceship = Spaceship();
      gateSpawnTimer = 0.0;
    });
    
    _generateNewProblem();
  }
}

// Game Objects
class Spaceship {
  Offset position = const Offset(100, 200);
  double targetY = 200;
  double velocityY = 0;
  bool thrusting = false;
  double boostTime = 0;
  double damageTime = 0;
  double thrustIntensity = 0;
  
  void update(double dt) {
    // FIX: Much more responsive movement
    final diff = targetY - position.dy;
    final maxAcceleration = 1200.0; // Increased responsiveness
    final acceleration = (diff * 12.0).clamp(-maxAcceleration, maxAcceleration);
    
    velocityY += acceleration * dt;
    velocityY *= 0.88; // Better damping
    
    // FIX: Keep ship on screen with better bounds
    final screenHeight = 600.0; // Approximate screen height
    position = Offset(
      position.dx,
      (position.dy + velocityY * dt).clamp(160.0, screenHeight - 40.0),
    );
    
    // Update thrust intensity for particle effects
    thrustIntensity = thrusting ? (diff.abs() > 50 ? 1.0 : 0.5) : thrustIntensity * 0.92;
    
    // Update effect timers
    if (boostTime > 0) boostTime -= dt;
    if (damageTime > 0) damageTime -= dt;
  }
  
  void boost() {
    boostTime = 0.3;
    velocityY *= 1.1;
  }
  
  void damage() {
    damageTime = 0.4;
    // Add slight knockback
    velocityY += (math.Random().nextDouble() - 0.5) * 100;
  }
}

class HyperdriveGate {
  Offset position;
  int answer;
  String problem;
  bool isCorrect;
  Color color;
  
  HyperdriveGate({
    required this.position,
    required this.answer,
    required this.problem,
    required this.isCorrect,
    required this.color,
  });
}

class ParticleEffect {
  Offset position;
  Offset velocity;
  Color color;
  double life;
  double maxLife;
  double size;
  
  ParticleEffect({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
    required this.size,
  }) : maxLife = life;
  
  void update(double dt) {
    position += velocity * dt;
    life -= dt;
    velocity *= 0.98; // Slow down over time
  }
}

class Star {
  Offset position;
  double size;
  double speed;
  double brightness;
  
  Star({
    required this.position,
    required this.size,
    required this.speed,
    required this.brightness,
  });
}

// Widgets
class SpaceshipWidget extends StatelessWidget {
  final Spaceship spaceship;
  final AnimationController thrusterAnimation;
  
  const SpaceshipWidget({
    super.key,
    required this.spaceship,
    required this.thrusterAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: thrusterAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: spaceship.boostTime > 0 ? 1.2 : 1.0,
          child: Container(
            width: 60,
            height: 40,
            child: CustomPaint(
              painter: SpaceshipPainter(
                thrusting: spaceship.thrusting,
                thrusterFlicker: thrusterAnimation.value,
                damaged: spaceship.damageTime > 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class HyperdriveGateWidget extends StatelessWidget {
  final HyperdriveGate gate;
  
  const HyperdriveGateWidget({super.key, required this.gate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gate.color, width: 4),
        gradient: LinearGradient(
          colors: [
            gate.color.withOpacity(0.1),
            gate.color.withOpacity(0.3),
            gate.color.withOpacity(0.1),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: gate.color.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Energy field effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: RadialGradient(
                  colors: [
                    gate.color.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Answer display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gate.color, width: 2),
              ),
              child: Text(
                gate.answer.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: gate.color,
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    
    return Container(
      width: particle.size,
      height: particle.size,
      decoration: BoxDecoration(
        color: particle.color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class SpaceshipPainter extends CustomPainter {
  final bool thrusting;
  final double thrusterFlicker;
  final bool damaged;
  
  SpaceshipPainter({
    required this.thrusting,
    required this.thrusterFlicker,
    required this.damaged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = damaged ? SpaceTheme.rocketRed : Colors.grey.shade300
      ..style = PaintingStyle.fill;
    
    // Draw spaceship body
    final path = Path();
    path.moveTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width * 0.2, size.height * 0.2);
    path.lineTo(0, size.height * 0.4);
    path.lineTo(0, size.height * 0.6);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Draw thruster flame
    if (thrusting) {
      final thrusterPaint = Paint()
        ..color = Color.lerp(
          SpaceTheme.planetOrange,
          SpaceTheme.starYellow,
          thrusterFlicker,
        )!
        ..style = PaintingStyle.fill;
      
      final flamePath = Path();
      flamePath.moveTo(0, size.height * 0.4);
      flamePath.lineTo(-15 - thrusterFlicker * 5, size.height * 0.5);
      flamePath.lineTo(0, size.height * 0.6);
      flamePath.close();
      
      canvas.drawPath(flamePath, thrusterPaint);
    }
  }

  @override
  bool shouldRepaint(SpaceshipPainter oldDelegate) {
    return oldDelegate.thrusting != thrusting ||
        oldDelegate.thrusterFlicker != thrusterFlicker ||
        oldDelegate.damaged != damaged;
  }
}