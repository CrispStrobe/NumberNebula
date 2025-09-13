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

class AsteroidMathGame extends StatefulWidget {
  final int grade;
  final int level;

  const AsteroidMathGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<AsteroidMathGame> createState() => _AsteroidMathGameState();
}

class _AsteroidMathGameState extends State<AsteroidMathGame>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _explosionController;
  late Timer _gameTimer;

  List<Asteroid> asteroids = [];
  List<Explosion> explosions = [];
  List<int> targetOrder = [];
  int currentTargetIndex = 0;
  int timeLeft = 60;
  bool gameActive = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Generate asteroids after the first frame to have access to context/size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateAsteroids();
      _startGameTimer();

      _animationController.addListener(() {
        if (gameActive && mounted) {
          _updateAsteroidPositions(MediaQuery.of(context).size);
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _explosionController.dispose();
    _gameTimer.cancel();
    super.dispose();
  }

  void _generateAsteroids() {
    if (!mounted) return;
    asteroids.clear();
    explosions.clear();
    targetOrder.clear();
    currentTargetIndex = 0;
    
    final screenSize = MediaQuery.of(context).size;
    final difficulty = widget.grade + widget.level;
    
    // Grade-based asteroid count: Grade 3 = 4-5, Grade 4 = 5-6, Grade 5 = 6-8, Grade 6 = 7-10
    int asteroidCount;
    switch (widget.grade) {
      case 3:
        asteroidCount = 4 + (widget.level ~/ 3);
        break;
      case 4:
        asteroidCount = 5 + (widget.level ~/ 2);
        break;
      case 5:
        asteroidCount = 6 + (widget.level ~/ 2);
        break;
      case 6:
      default:
        asteroidCount = 7 + (widget.level ~/ 2);
        break;
    }
    
    asteroidCount = math.min(asteroidCount, 10); // Max 10 asteroids
    
    final random = math.Random();
    final usedAnswers = <int>{};

    for (int i = 0; i < asteroidCount; i++) {
      MathProblem problem;
      
      // Mix of equations and plain numbers based on difficulty
      double equationChance = 0.3 + (difficulty * 0.1);
      if (random.nextDouble() < equationChance) {
        do {
          problem = MathProblem.random(widget.grade, difficulty: difficulty);
        } while (usedAnswers.contains(problem.answer));
      } else {
        int plainNumber;
        do {
          plainNumber = random.nextInt(difficulty * 4 + 10) + 1;
        } while (usedAnswers.contains(plainNumber));
        
        problem = MathProblem(
          expression: plainNumber.toString(),
          answer: plainNumber,
          operation: MathOperation.addition, 
          operandA: plainNumber,
          operandB: 0,
          difficulty: 1,
        );
      }

      usedAnswers.add(problem.answer);
      
      final asteroidSize = 80.0 + random.nextDouble() * 30;
      final asteroidSpeed = 50.0 + random.nextDouble() * 30;

      asteroids.add(Asteroid(
        id: i,
        mathProblem: problem.expression,
        answer: problem.answer,
        position: Offset(
          random.nextDouble() * (screenSize.width - asteroidSize) + (asteroidSize / 2),
          random.nextDouble() * (screenSize.height - asteroidSize - 150) + (asteroidSize / 2),
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * asteroidSpeed,
          (random.nextDouble() - 0.5) * asteroidSpeed,
        ),
        size: asteroidSize,
        rotationSpeed: (random.nextDouble() - 0.5) * 2,
        rotation: random.nextDouble() * 2 * math.pi,
      ));

      targetOrder.add(problem.answer);
    }
    
    targetOrder.sort();
    setState(() {});
  }

  void _updateAsteroidPositions(Size screenSize) {
    setState(() {
      for (var asteroid in asteroids) {
        asteroid.position += asteroid.velocity * 0.016;
        asteroid.rotation += asteroid.rotationSpeed * 0.016;

        // Bounce off walls
        if (asteroid.position.dx <= asteroid.size / 2 ||
            asteroid.position.dx >= screenSize.width - asteroid.size / 2) {
          asteroid.velocity = Offset(-asteroid.velocity.dx, asteroid.velocity.dy);
        }

        if (asteroid.position.dy <= asteroid.size / 2 ||
            asteroid.position.dy >= screenSize.height - asteroid.size / 2 - 150) {
          asteroid.velocity = Offset(asteroid.velocity.dx, -asteroid.velocity.dy);
        }
        
        // Clamp position to screen bounds
        asteroid.position = Offset(
          asteroid.position.dx.clamp(asteroid.size / 2, screenSize.width - asteroid.size / 2),
          asteroid.position.dy.clamp(asteroid.size / 2, screenSize.height - asteroid.size / 2 - 150),
        );
      }

      // Update explosions
      explosions.removeWhere((explosion) => 
        DateTime.now().difference(explosion.startTime).inMilliseconds > 500);
    });
  }

  void _startGameTimer() {
    // Grade-based time limits
    int timeLimit;
    switch (widget.grade) {
      case 3:
        timeLimit = 90;
        break;
      case 4:
        timeLimit = 80;
        break;
      case 5:
        timeLimit = 70;
        break;
      case 6:
      default:
        timeLimit = 60;
        break;
    }
    
    timeLeft = timeLimit;
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameActive && timeLeft > 0) {
        setState(() => timeLeft--);
      } else if (mounted) {
        _endGame();
      }
    });
  }

  void _onAsteroidDestroyed(Asteroid asteroid) {
    if (!gameActive) return;

    final expectedAnswer = targetOrder[currentTargetIndex];

    if (asteroid.answer == expectedAnswer) {
      // Correct asteroid!
      _createExplosion(asteroid.position);
      
      setState(() {
        asteroids.remove(asteroid);
        currentTargetIndex++;
      });
      
      context.read<GameProvider>().addScore(15 * widget.grade);
      
      if (currentTargetIndex >= targetOrder.length) {
        _winGame();
      }
    } else {
      // Wrong asteroid
      _showWrongAsteroidFeedback();
    }
  }

  void _createExplosion(Offset position) {
    setState(() {
      explosions.add(Explosion(
        position: position,
        startTime: DateTime.now(),
      ));
    });
    
    _explosionController.reset();
    _explosionController.forward();
  }

  void _showWrongAsteroidFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Target asteroid with answer: ${targetOrder[currentTargetIndex]}',
          style: SpaceTheme.bodyStyle,
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _winGame() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    
    // Grade-based scoring
    final timeBonus = timeLeft * (5 + widget.grade);
    context.read<GameProvider>().addScore(timeBonus);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildWinDialog(),
    );
  }

  void _endGame() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGameOverDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: "Asteroid Math Hunter",
                level: widget.level,
                timeLeft: timeLeft,
                onBack: () => Navigator.of(context).pop(),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: SpaceTheme.cardDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.gps_fixed, color: SpaceTheme.rocketRed, size: 20),
                    const SizedBox(width: 8),
                    Text('Target asteroid: ', style: SpaceTheme.bodyStyle),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        currentTargetIndex < targetOrder.length
                            ? targetOrder[currentTargetIndex].toString()
                            : 'Mission Complete!',
                        style: SpaceTheme.titleStyle.copyWith(
                          color: SpaceTheme.spaceBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Asteroids
                    ...asteroids.map((asteroid) => AsteroidWidget(
                      key: ValueKey(asteroid.id),
                      asteroid: asteroid,
                      onDestroyed: () => _onAsteroidDestroyed(asteroid),
                    )).toList(),
                    
                    // Explosions
                    ...explosions.map((explosion) => AnimatedBuilder(
                      animation: _explosionController,
                      builder: (context, child) {
                        return ExplosionWidget(
                          explosion: explosion,
                          animation: _explosionController.value,
                        );
                      },
                    )).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinDialog() {
    final timeBonus = timeLeft * (5 + widget.grade);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 64,
              color: SpaceTheme.starYellow,
            ),
            const SizedBox(height: 16),
            Text(
              'Asteroid Field Cleared!',
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Time Bonus: $timeBonus points!\nYou are a true Space Hunter!',
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
                  child: Text(S.of(context)!.playAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.nextLevel),
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
              Icons.timer_off,
              size: 64,
              color: SpaceTheme.warning,
            ),
            const SizedBox(height: 16),
            Text(
              'Time\'s Up, Space Cadet!',
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'The asteroid field got too chaotic!\nTry again, Commander!',
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
                  child: Text(S.of(context)!.playAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.backToMenu),
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
    });
    _generateAsteroids();
    _startGameTimer();
  }
}

class Asteroid {
  final int id;
  String mathProblem;
  int answer;
  Offset position;
  Offset velocity;
  double size;
  double rotationSpeed;
  double rotation;

  Asteroid({
    required this.id,
    required this.mathProblem,
    required this.answer,
    required this.position,
    required this.velocity,
    required this.size,
    required this.rotationSpeed,
    required this.rotation,
  });
}

class Explosion {
  final Offset position;
  final DateTime startTime;

  Explosion({
    required this.position,
    required this.startTime,
  });
}

class AsteroidWidget extends StatelessWidget {
  final Asteroid asteroid;
  final VoidCallback onDestroyed;

  const AsteroidWidget({
    super.key,
    required this.asteroid,
    required this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: asteroid.position.dx - asteroid.size / 2,
      top: asteroid.position.dy - asteroid.size / 2,
      child: GestureDetector(
        onTap: onDestroyed,
        child: Transform.rotate(
          angle: asteroid.rotation,
          child: Container(
            width: asteroid.size,
            height: asteroid.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.grey.shade600,
                  Colors.grey.shade800,
                  Colors.grey.shade900,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Asteroid texture (craters)
                Positioned.fill(
                  child: CustomPaint(
                    painter: AsteroidTexturePainter(),
                  ),
                ),
                
                // Math problem/answer
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: SpaceTheme.starYellow.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SpaceTheme.spaceBlue, width: 2),
                    ),
                    child: Text(
                      asteroid.mathProblem,
                      style: TextStyle(
                        fontSize: asteroid.size * 0.25,
                        fontWeight: FontWeight.bold,
                        color: SpaceTheme.spaceBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExplosionWidget extends StatelessWidget {
  final Explosion explosion;
  final double animation;

  const ExplosionWidget({
    super.key,
    required this.explosion,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final size = 100.0 * animation;
    final opacity = 1.0 - animation;
    
    return Positioned(
      left: explosion.position.dx - size / 2,
      top: explosion.position.dy - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                SpaceTheme.starYellow.withOpacity(opacity),
                SpaceTheme.planetOrange.withOpacity(opacity),
                SpaceTheme.rocketRed.withOpacity(opacity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class AsteroidTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent texture
    
    // Draw some craters
    for (int i = 0; i < 5; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * size.width * 0.1 + 2;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(AsteroidTexturePainter oldDelegate) => false;
}