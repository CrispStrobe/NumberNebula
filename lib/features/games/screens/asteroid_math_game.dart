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
  late AnimationController _laserController;
  late Timer _gameTimer;
  Timer? _hintTimer; // Make nullable and initialize properly

  List<Asteroid> asteroids = [];
  List<Explosion> explosions = [];
  List<LaserBeam> laserBeams = [];
  List<int> targetOrder = [];
  int currentTargetIndex = 0;
  int timeLeft = 60;
  bool gameActive = true;
  bool showHint = false;
  DifficultyConfig? currentDifficulty;

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

    _laserController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize difficulty
    currentDifficulty = DifficultyManager.getDifficulty(widget.grade, widget.level);

    // Generate asteroids after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _generateAsteroids();
        _startGameTimer();
        _startHintTimer();

        _animationController.addListener(() {
          if (gameActive && mounted) {
            _updateAsteroidPositions(MediaQuery.of(context).size);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _explosionController.dispose();
    _laserController.dispose();
    _gameTimer.cancel();
    _hintTimer?.cancel(); // FIX: Safe disposal
    super.dispose();
  }

  void _startHintTimer() {
    _hintTimer?.cancel(); // Cancel existing timer
    _hintTimer = Timer(Duration(seconds: currentDifficulty?.showHints == true ? 3 : 8), () {
      if (mounted && gameActive) {
        setState(() => showHint = true);
      }
    });
  }

  void _generateAsteroids() {
    if (!mounted || currentDifficulty == null) return;
    
    asteroids.clear();
    explosions.clear();
    laserBeams.clear();
    targetOrder.clear();
    currentTargetIndex = 0;
    showHint = false;
    
    final screenSize = MediaQuery.of(context).size;
    final difficulty = currentDifficulty!;
    final random = math.Random();
    final usedAnswers = <int>{};

    // Use difficulty manager for asteroid count
    int asteroidCount = difficulty.objectCount.clamp(4, 12);
    
    for (int i = 0; i < asteroidCount; i++) {
      MathProblem problem;
      
      // Use difficulty manager for equation probability
      if (random.nextDouble() < difficulty.equationProbability) {
        do {
          problem = MathProblem.random(
            widget.grade, 
            difficulty: (difficulty.difficultyMultiplier * 2).round(),
          );
        } while (usedAnswers.contains(problem.answer));
      } else {
        int plainNumber;
        do {
          final range = difficulty.numberRange;
          plainNumber = random.nextInt(range['max']! - range['min']!) + range['min']!;
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
      
      // Varied asteroid sizes and speeds based on difficulty
      final baseSizeMultiplier = 1.0 + (difficulty.visualComplexity - 1.0) * 0.2;
      final asteroidSize = (70.0 + random.nextDouble() * 40) * baseSizeMultiplier;
      final baseSpeed = 40.0 + (difficulty.gameSpeed * 0.3);
      final asteroidSpeed = baseSpeed + random.nextDouble() * 20;

      // Better positioning to avoid clustering
      Offset position;
      int attempts = 0;
      do {
        position = Offset(
          random.nextDouble() * (screenSize.width - asteroidSize) + (asteroidSize / 2),
          random.nextDouble() * (screenSize.height - asteroidSize - 180) + (asteroidSize / 2 + 90),
        );
        attempts++;
      } while (attempts < 10 && _isPositionTooClose(position, asteroidSize));

      asteroids.add(Asteroid(
        id: i,
        mathProblem: problem.expression,
        answer: problem.answer,
        position: position,
        velocity: Offset(
          (random.nextDouble() - 0.5) * asteroidSpeed,
          (random.nextDouble() - 0.5) * asteroidSpeed,
        ),
        size: asteroidSize,
        rotationSpeed: (random.nextDouble() - 0.5) * 3 * difficulty.animationSpeed,
        rotation: random.nextDouble() * 2 * math.pi,
        // Enhanced visual properties
        color: _getAsteroidColor(problem.answer, difficulty),
        craterCount: random.nextInt(3) + 2,
        glowIntensity: 0.3 + random.nextDouble() * 0.4,
      ));

      targetOrder.add(problem.answer);
    }
    
    targetOrder.sort();
    setState(() {});
  }

  bool _isPositionTooClose(Offset newPosition, double newSize) {
    for (final asteroid in asteroids) {
      final distance = (newPosition - asteroid.position).distance;
      if (distance < (asteroid.size + newSize) * 0.6) {
        return true;
      }
    }
    return false;
  }

  Color _getAsteroidColor(int answer, DifficultyConfig difficulty) {
    // Color asteroids based on their answer value for visual sorting hints
    final normalizedValue = (answer / difficulty.numberRange['max']!).clamp(0.0, 1.0);
    return Color.lerp(
      Colors.grey.shade600,
      Colors.brown.shade700,
      normalizedValue,
    )!;
  }

  void _updateAsteroidPositions(Size screenSize) {
    if (!mounted || !gameActive) return; // FIX: Add mounted check
    
    setState(() {
      // Update asteroids with better physics
      for (var asteroid in asteroids) {
        // FIX: More responsive movement
        asteroid.position += asteroid.velocity * 0.020; // Slightly faster movement
        asteroid.rotation += asteroid.rotationSpeed * 0.020;

        // FIX: Better bouncing with proper bounds
        final margin = asteroid.size / 2;
        
        if (asteroid.position.dx <= margin || asteroid.position.dx >= screenSize.width - margin) {
          asteroid.velocity = Offset(-asteroid.velocity.dx * 0.8, asteroid.velocity.dy);
          // Clamp to prevent sticking
          asteroid.position = Offset(
            asteroid.position.dx.clamp(margin, screenSize.width - margin),
            asteroid.position.dy
          );
        }

        if (asteroid.position.dy <= margin + 90 || asteroid.position.dy >= screenSize.height - margin - 150) {
          asteroid.velocity = Offset(asteroid.velocity.dx, -asteroid.velocity.dy * 0.8);
          // Clamp to prevent sticking
          asteroid.position = Offset(
            asteroid.position.dx,
            asteroid.position.dy.clamp(margin + 90, screenSize.height - margin - 150)
          );
        }

        // FIX: Add slight random movement to prevent stagnation
        if (asteroid.velocity.distance < 20) {
          final random = math.Random();
          asteroid.velocity += Offset(
            (random.nextDouble() - 0.5) * 40,
            (random.nextDouble() - 0.5) * 40,
          );
        }

        // Enhanced target glow effect
        if (currentTargetIndex < targetOrder.length) {
          final targetAnswer = targetOrder[currentTargetIndex];
          if (asteroid.answer == targetAnswer) {
            asteroid.glowIntensity = 0.9 + math.sin(DateTime.now().millisecondsSinceEpoch / 150) * 0.1;
          } else {
            asteroid.glowIntensity = math.max(0.3, asteroid.glowIntensity * 0.98);
          }
        }
      }

      // Update explosions and laser beams (unchanged)
      explosions.removeWhere((explosion) => 
        DateTime.now().difference(explosion.startTime).inMilliseconds > 800);
      
      laserBeams.removeWhere((laser) => 
        DateTime.now().difference(laser.startTime).inMilliseconds > 300);
    });
  }

  void _startGameTimer() {
    if (currentDifficulty == null) return;
    
    timeLeft = currentDifficulty!.timeLimit;
    
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

    // Reset hint when player acts
    setState(() => showHint = false);
    _startHintTimer();

    final expectedAnswer = targetOrder[currentTargetIndex];

    if (asteroid.answer == expectedAnswer) {
      // Correct asteroid!
      _createLaserEffect(asteroid);
      _createExplosion(asteroid.position, true);
      
      setState(() {
        asteroids.remove(asteroid);
        currentTargetIndex++;
      });
      
      // Fixed the type conversion issue
      final scoreToAdd = (20 * widget.grade * currentDifficulty!.difficultyMultiplier).round();
      context.read<GameProvider>().addScore(scoreToAdd);
      
      if (currentTargetIndex >= targetOrder.length) {
        _winGame();
      }
    } else {
      // Wrong asteroid - visual feedback only, no life loss
      _createExplosion(asteroid.position, false);
      _showWrongAsteroidFeedback();
    }
  }

  void _createLaserEffect(Asteroid asteroid) {
    setState(() {
      laserBeams.add(LaserBeam(
        startPosition: Offset(50, MediaQuery.of(context).size.height / 2),
        endPosition: asteroid.position,
        startTime: DateTime.now(),
        color: SpaceTheme.alienGreen,
      ));
    });
    
    _laserController.reset();
    _laserController.forward();
  }

  void _createExplosion(Offset position, bool isCorrect) {
    setState(() {
      explosions.add(Explosion(
        position: position,
        startTime: DateTime.now(),
        isCorrect: isCorrect,
        color: isCorrect ? SpaceTheme.starYellow : SpaceTheme.rocketRed,
      ));
    });
    
    _explosionController.reset();
    _explosionController.forward();
  }

  void _showWrongAsteroidFeedback() {
    if (currentTargetIndex < targetOrder.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Target asteroid: ${targetOrder[currentTargetIndex]}',
            style: SpaceTheme.bodyStyle,
          ),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _winGame() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    _hintTimer?.cancel();
    
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
    _hintTimer?.cancel();
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
                onBack: () {
                  // FIX: Proper back button handling
                  setState(() => gameActive = false);
                  _gameTimer.cancel();
                  _hintTimer?.cancel();
                  Navigator.of(context).pop();
                },
              ),
              _buildTargetDisplay(),
              Expanded(
                child: Stack(
                  children: [
                    // Asteroids with better hit detection
                    ...asteroids.map((asteroid) => EnhancedAsteroidWidget(
                      key: ValueKey(asteroid.id),
                      asteroid: asteroid,
                      isTarget: currentTargetIndex < targetOrder.length && 
                               asteroid.answer == targetOrder[currentTargetIndex],
                      onDestroyed: () => _onAsteroidDestroyed(asteroid),
                    )).toList(),
                    
                    // Laser beams
                    ...laserBeams.map((laser) => AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, child) {
                        return LaserBeamWidget(
                          laser: laser,
                          animation: _laserController.value,
                        );
                      },
                    )).toList(),
                    
                    // Explosions
                    ...explosions.map((explosion) => AnimatedBuilder(
                      animation: _explosionController,
                      builder: (context, child) {
                        return EnhancedExplosionWidget(
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

  // Enhanced target display that only shows when hint is active
  Widget _buildTargetDisplay() {
    if (!showHint || currentTargetIndex >= targetOrder.length) {
      return Container();
    }

    return AnimatedOpacity(
      opacity: showHint ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: SpaceTheme.starYellow, width: 2),
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_fixed, color: SpaceTheme.rocketRed, size: 24),
            const SizedBox(width: 12),
            Text(
              'Target: ',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: SpaceTheme.starYellow,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                targetOrder[currentTargetIndex].toString(),
                style: SpaceTheme.titleStyle.copyWith(
                  color: SpaceTheme.spaceBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
      showHint = false;
    });
    _generateAsteroids();
    _startGameTimer();
    _startHintTimer();
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
  Color color;
  int craterCount;
  double glowIntensity;

  Asteroid({
    required this.id,
    required this.mathProblem,
    required this.answer,
    required this.position,
    required this.velocity,
    required this.size,
    required this.rotationSpeed,
    required this.rotation,
    required this.color,
    required this.craterCount,
    required this.glowIntensity,
  });
}

class Explosion {
  final Offset position;
  final DateTime startTime;
  final bool isCorrect;
  final Color color;

  Explosion({
    required this.position,
    required this.startTime,
    required this.isCorrect,
    required this.color,
  });
}

class LaserBeam {
  final Offset startPosition;
  final Offset endPosition;
  final DateTime startTime;
  final Color color;

  LaserBeam({
    required this.startPosition,
    required this.endPosition,
    required this.startTime,
    required this.color,
  });
}

// Enhanced widget classes
class EnhancedAsteroidWidget extends StatelessWidget {
  final Asteroid asteroid;
  final bool isTarget;
  final VoidCallback onDestroyed;

  const EnhancedAsteroidWidget({
    super.key,
    required this.asteroid,
    required this.isTarget,
    required this.onDestroyed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: asteroid.position.dx - asteroid.size / 2,
      top: asteroid.position.dy - asteroid.size / 2,
      child: GestureDetector(
        // FIX: Better tap handling with larger hit area
        onTap: onDestroyed,
        behavior: HitTestBehavior.opaque, // FIX: Ensure taps are captured
        child: Transform.rotate(
          angle: asteroid.rotation,
          child: Container(
            width: asteroid.size,
            height: asteroid.size,
            // FIX: Add padding for better tap target
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  asteroid.color,
                  asteroid.color.withOpacity(0.7),
                  asteroid.color.withOpacity(0.9),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
              border: isTarget ? Border.all(
                color: SpaceTheme.starYellow,
                width: 4, // FIX: Thicker border for visibility
              ) : null,
              boxShadow: [
                BoxShadow(
                  color: asteroid.color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
                if (isTarget) BoxShadow(
                  color: SpaceTheme.starYellow.withOpacity(asteroid.glowIntensity),
                  blurRadius: 25,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Crater effects
                Positioned.fill(
                  child: CustomPaint(
                    painter: AsteroidTexturePainter(asteroid.craterCount),
                  ),
                ),
                
                // Number with better contrast
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9), // FIX: Better contrast
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTarget ? SpaceTheme.starYellow : SpaceTheme.alienGreen, 
                        width: 2
                      ),
                    ),
                    child: Text(
                      asteroid.mathProblem,
                      style: TextStyle(
                        fontSize: asteroid.size * 0.16, // FIX: Better size scaling
                        fontWeight: FontWeight.bold,
                        color: isTarget ? SpaceTheme.starYellow : Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 3,
                          ),
                        ],
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

class EnhancedExplosionWidget extends StatelessWidget {
  final Explosion explosion;
  final double animation;

  const EnhancedExplosionWidget({
    super.key,
    required this.explosion,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final size = 120.0 * animation;
    final opacity = (1.0 - animation) * 0.8;
    
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
                explosion.color.withOpacity(opacity),
                explosion.color.withOpacity(opacity * 0.7),
                explosion.color.withOpacity(opacity * 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class LaserBeamWidget extends StatelessWidget {
  final LaserBeam laser;
  final double animation;

  const LaserBeamWidget({
    super.key,
    required this.laser,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = 1.0 - animation;
    
    return CustomPaint(
      painter: LaserPainter(
        start: laser.startPosition,
        end: laser.endPosition,
        color: laser.color.withOpacity(opacity),
        thickness: 4.0 * (1.0 - animation * 0.5),
      ),
      size: MediaQuery.of(context).size,
    );
  }
}

class AsteroidTexturePainter extends CustomPainter {
  final int craterCount;
  
  AsteroidTexturePainter(this.craterCount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent texture
    
    // Draw craters
    for (int i = 0; i < craterCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * size.width * 0.15 + 3;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(AsteroidTexturePainter oldDelegate) => 
      oldDelegate.craterCount != craterCount;
}

class LaserPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;
  
  LaserPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw main laser beam
    canvas.drawLine(start, end, paint);
    
    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = thickness * 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawLine(start, end, glowPaint);
  }

  @override
  bool shouldRepaint(LaserPainter oldDelegate) {
    return oldDelegate.start != start ||
           oldDelegate.end != end ||
           oldDelegate.color != color ||
           oldDelegate.thickness != thickness;
  }
}