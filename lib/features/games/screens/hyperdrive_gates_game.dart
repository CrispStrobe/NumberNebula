import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../constants/app_constants.dart';
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
  int lives = 3;
  
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
      // Update background stars
      for (var star in backgroundStars) {
        star.position = Offset(
          star.position.dx - star.speed * dt,
          star.position.dy,
        );
        
        if (star.position.dx < -10) {
          star.position = Offset(
            screenSize.width + 10,
            math.Random().nextDouble() * screenSize.height,
          );
        }
      }
      
      // Update spaceship physics
      spaceship.update(dt);
      
      // Spawn gates
      gateSpawnTimer += dt;
      if (gateSpawnTimer > 2.0) { // Spawn gate every 2 seconds
        _spawnGate(screenSize);
        gateSpawnTimer = 0.0;
      }
      
      // Update gates
      gates.removeWhere((gate) {
        gate.position = Offset(
          gate.position.dx - gameSpeed * dt,
          gate.position.dy,
        );
        
        // Check collision with spaceship
        if (_checkGateCollision(gate)) {
          _handleGateCollision(gate);
          return true;
        }
        
        return gate.position.dx < -100; // Remove off-screen gates
      });
      
      // Update particles
      particles.removeWhere((particle) {
        particle.update(dt);
        return particle.life <= 0;
      });
      
      // Add thruster particles
      if (spaceship.thrusting) {
        _addThrusterParticles();
      }
      
      // Check win condition
      if (correctGatesPassedThrough >= targetGatesNeeded) {
        _winGame();
      }
      
      // Check lose condition
      if (lives <= 0) {
        _gameOver();
      }
    });
  }
  
  void _spawnGate(Size screenSize) {
    final random = math.Random();
    final isCorrectGate = random.nextBool(); // 50% chance for correct gate
    
    int gateAnswer;
    Color gateColor;
    bool isCorrect;
    
    if (isCorrectGate) {
      gateAnswer = correctAnswer;
      gateColor = SpaceTheme.alienGreen;
      isCorrect = true;
    } else {
      // Generate wrong answer
      do {
        gateAnswer = correctAnswer + random.nextInt(20) - 10;
      } while (gateAnswer == correctAnswer || gateAnswer <= 0);
      gateColor = SpaceTheme.rocketRed;
      isCorrect = false;
    }
    
    gates.add(HyperdriveGate(
      position: Offset(
        screenSize.width + 50,
        random.nextDouble() * (screenSize.height - 200) + 100,
      ),
      answer: gateAnswer,
      problem: currentProblem!.expression,
      isCorrect: isCorrect,
      color: gateColor,
    ));
  }
  
  bool _checkGateCollision(HyperdriveGate gate) {
    final spaceshipRect = Rect.fromCenter(
      center: spaceship.position,
      width: 60,
      height: 40,
    );
    
    final gateRect = Rect.fromCenter(
      center: gate.position,
      width: 120,
      height: 80,
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
      lives--;
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
    particles.add(ParticleEffect(
      position: Offset(
        spaceship.position.dx - 30,
        spaceship.position.dy + (random.nextDouble() - 0.5) * 20,
      ),
      velocity: Offset(-150 - random.nextDouble() * 50, 0),
      color: SpaceTheme.planetOrange,
      life: 0.5,
      size: 2.0,
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
              // Background stars
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
              
              // Game UI Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildGameHeader(),
              ),
              
              // Current Problem Display
              Positioned(
                top: 80,
                left: 20,
                child: _buildProblemDisplay(),
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
              
              // Touch control overlay
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
                index < lives ? Icons.favorite : Icons.favorite_border,
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
            'SOLVE:',
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
      child: GestureDetector(
        onPanUpdate: (details) {
          if (!gameActive) return;
          
          setState(() {
            spaceship.targetY = details.localPosition.dy;
            spaceship.thrusting = true;
          });
        },
        onPanEnd: (details) {
          setState(() {
            spaceship.thrusting = false;
          });
        },
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
              'Hyperdrive Navigation Complete!',
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
                  child: const Text('Fly Again'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: const Text('Mission Complete'),
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
              'Navigation System Failure!',
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
                  child: const Text('Retry Mission'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: const Text('Return to Base'),
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
      lives = 3;
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
  
  void update(double dt) {
    // Smooth movement towards target
    final diff = targetY - position.dy;
    velocityY += diff * 5 * dt;
    velocityY *= 0.8; // Damping
    
    position = Offset(
      position.dx,
      (position.dy + velocityY * dt).clamp(20, 600),
    );
    
    if (boostTime > 0) boostTime -= dt;
    if (damageTime > 0) damageTime -= dt;
  }
  
  void boost() {
    boostTime = 0.5;
  }
  
  void damage() {
    damageTime = 0.5;
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gate.color, width: 3),
        color: gate.color.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: gate.color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          gate.answer.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: gate.color,
          ),
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