// Using existing l10n strings:
// - asteroidMathHunter: "Asteroid Hunter"
// - nextTarget: "Next target: "
// - asteroidMathWinTitle: "Asteroid Field Cleared!"
// - timesUpSpaceCadet: "Time's Up, Space Cadet!"
// - asteroidMathWinDesc: "Time Bonus: {timeBonus} points!\nYou are a true Space Hunter!"
// - asteroidMathLoseDesc: "The asteroid field got too chaotic!\nTry again, Commander!"

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
import '../../../core/services/sri_service.dart'; // Import SRI Service

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
  // Animation Controllers
  late AnimationController _gameLoopController;
  late AnimationController _explosionController;
  late AnimationController _laserController;
  late AnimationController _screenShakeController;
  late AnimationController _spaceshipController;

  // Game State
  List<Asteroid> asteroids = [];
  List<ParticleExplosion> explosions = [];
  List<LaserBeam> laserBeams = [];
  List<FloatingScore> floatingScores = [];
  List<int> targetOrder = [];
  int currentTargetIndex = 0;
  int timeLeft = 60;
  bool gameActive = true;
  bool showHint = false;
  DifficultyConfig? currentDifficulty;

  // Spaceship position for laser start point
  Offset spaceshipPosition = const Offset(50, 0); // Will be updated in build

  // Timers
  late Timer _gameTimer;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    // Initialize controllers
    _gameLoopController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _explosionController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _laserController =
        AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _screenShakeController =
        AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _spaceshipController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();

    // Initialize difficulty based on grade and level
    currentDifficulty = DifficultyManager.getDifficulty(widget.grade, widget.level);

    // Start the game after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resetGame();
        _gameLoopController.addListener(_updateGame);
      }
    });
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _explosionController.dispose();
    _laserController.dispose();
    _screenShakeController.dispose();
    _spaceshipController.dispose();
    _gameTimer.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      gameActive = true;
      showHint = false;
      currentTargetIndex = 0;
      targetOrder.clear();
      asteroids.clear();
      explosions.clear();
      laserBeams.clear();
      floatingScores.clear();
    });
    
    _generateAsteroids();
    _startGameTimer();
    _startHintTimer();
  }

  void _startHintTimer() {
    _hintTimer?.cancel();
    final hintDelay = currentDifficulty?.showHints == true ? 5 : 10;
    _hintTimer = Timer(Duration(seconds: hintDelay), () {
      if (mounted && gameActive) {
        setState(() => showHint = true);
      }
    });
  }

  void _generateAsteroids() {
    if (!mounted || currentDifficulty == null) return;
    
    final screenSize = MediaQuery.of(context).size;
    final difficulty = currentDifficulty!;
    final random = math.Random();
    final usedAnswers = <int>{};

    int asteroidCount = difficulty.objectCount;
    final problems = <MathProblem>[];

    final sriService = context.read<SriService>(); // Get the SRI service
    
    // Generate math problems using your library
    int attempts = 0;
    while (problems.length < asteroidCount && attempts < 100) {
      attempts++;
      
      // Use the smart generator
      final problem = MathProblem.generateProblem(widget.grade, widget.level, sriService);
      
      // Ensure we don't have duplicate answers and answers are in reasonable range
      if (!usedAnswers.contains(problem.answer) && problem.answer > 0 && problem.answer < 1000) {
        problems.add(problem);
        usedAnswers.add(problem.answer);
      }
    }
    
    // If we need more problems, fill with simple numbers
    while (problems.length < asteroidCount) {
      int plainNumber;
      do {
        final range = difficulty.numberRange;
        plainNumber = random.nextInt(range['max']! - range['min']!) + range['min']!;
      } while (usedAnswers.contains(plainNumber));

      final simpleProblem = MathProblem(
        expression: plainNumber.toString(),
        answer: plainNumber,
        operation: MathOperation.addition,
        operandA: plainNumber,
        operandB: 0,
        difficulty: 1,
      );
      
      problems.add(simpleProblem);
      usedAnswers.add(plainNumber);
    }
    
    // Create asteroids from problems
    for (int i = 0; i < problems.length; i++) {
      final problem = problems[i];
      final asteroidSize = (60.0 + random.nextDouble() * 40) * difficulty.visualComplexity;
      final asteroidSpeed = (8.0 + (difficulty.gameSpeed * 6));

      Offset position;
      int positionAttempts = 0;
      do {
        position = Offset(
          random.nextDouble() * (screenSize.width - asteroidSize),
          random.nextDouble() * (screenSize.height - asteroidSize - 220) + 100,
        );
        positionAttempts++;
      } while (positionAttempts < 10 && _isPositionTooClose(position, asteroidSize));

      final asteroidType = AsteroidType.values[random.nextInt(AsteroidType.values.length)];

      asteroids.add(Asteroid(
        id: i,
        problem: problem, // Corrected
        position: position,
        velocity: Offset(
          (random.nextDouble() - 0.5) * asteroidSpeed,
          (random.nextDouble() - 0.5) * asteroidSpeed,
        ),
        size: asteroidSize,
        rotationSpeed: (random.nextDouble() - 0.5) * 1.5 * difficulty.animationSpeed,
        rotation: random.nextDouble() * 2 * math.pi,
        type: asteroidType,
        hue: random.nextDouble() * 360,
      ));
    }
    
    targetOrder.addAll(usedAnswers);
    targetOrder.sort();
    setState(() {});
  }

  bool _isPositionTooClose(Offset newPosition, double newSize) {
    for (final asteroid in asteroids) {
      if ((newPosition - asteroid.position).distance < (asteroid.size + newSize) * 0.7) {
        return true;
      }
    }
    return false;
  }

  void _updateGame() {
    if (!mounted || !gameActive) return;
    final screenSize = MediaQuery.of(context).size;
    final double deltaTime = 0.016;

    // Update spaceship position
    spaceshipPosition = Offset(50, screenSize.height - 90);

    setState(() {
      // Update asteroids
      for (var asteroid in asteroids) {
        asteroid.position += asteroid.velocity * deltaTime;
        asteroid.rotation += asteroid.rotationSpeed * deltaTime;

        // Smooth wall bouncing with damping
        final margin = asteroid.size / 2;
        if (asteroid.position.dx <= margin || asteroid.position.dx >= screenSize.width - margin) {
          asteroid.velocity = Offset(-asteroid.velocity.dx * 0.8, asteroid.velocity.dy);
          asteroid.position = Offset(
            asteroid.position.dx.clamp(margin, screenSize.width - margin),
            asteroid.position.dy
          );
        }
        if (asteroid.position.dy <= margin + 90 || asteroid.position.dy >= screenSize.height - margin - 90) {
          asteroid.velocity = Offset(asteroid.velocity.dx, -asteroid.velocity.dy * 0.8);
          asteroid.position = Offset(
            asteroid.position.dx,
            asteroid.position.dy.clamp(margin + 90, screenSize.height - margin - 90)
          );
        }
      }

      // Update animations
      explosions.removeWhere((e) => e.isComplete);
      laserBeams.removeWhere((l) => l.isComplete);
      floatingScores.removeWhere((s) => s.isComplete);
      
      for(var e in explosions) { e.update(deltaTime); }
      for(var l in laserBeams) { l.update(deltaTime); }
      for(var s in floatingScores) { s.update(deltaTime); }
    });
  }

  void _startGameTimer() {
    if (currentDifficulty == null) return;
    timeLeft = currentDifficulty!.timeLimit;
    
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameActive && timeLeft > 0) {
        setState(() => timeLeft--);
      } else if (mounted) {
        timer.cancel();
        _endGame(isWin: false);
      }
    });
  }

  void _onAsteroidTapped(Asteroid asteroid) {
    if (!gameActive || currentTargetIndex >= targetOrder.length) return;

    // Get the SRI service and record the result
    final sriService = context.read<SriService>();
    final expectedAnswer = targetOrder[currentTargetIndex];
    final bool isCorrect = asteroid.answer == expectedAnswer;

    // Record the response in the SRI system
    sriService.recordResponse(asteroid.problem, isCorrect);

    setState(() => showHint = false);
    _startHintTimer();

    if (isCorrect) {
      // Correct!
      _triggerScreenShake();
      
      final scoreToAdd = (15 * widget.grade * currentDifficulty!.difficultyMultiplier).round();
      context.read<GameProvider>().addScore(scoreToAdd);

      setState(() {
        _createLaserEffect(asteroid);
        explosions.add(ParticleExplosion(position: asteroid.position, isCorrect: true));
        floatingScores.add(FloatingScore(
            position: asteroid.position,
            text: '+$scoreToAdd',
            color: SpaceTheme.starYellow));
        
        asteroids.remove(asteroid);
        currentTargetIndex++;
      });
      
      if (currentTargetIndex >= targetOrder.length) {
        _endGame(isWin: true);
      }
    } else {
      // Wrong!
      setState(() {
        explosions.add(ParticleExplosion(position: asteroid.position, isCorrect: false));
      });
    }
  }

  void _triggerScreenShake() {
    _screenShakeController.forward(from: 0.0);
  }

  void _createLaserEffect(Asteroid asteroid) {
    setState(() {
      laserBeams.add(LaserBeam(
        startPosition: spaceshipPosition,
        endPosition: asteroid.position
      ));
    });
  }

  void _endGame({required bool isWin}) {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    _hintTimer?.cancel();
    
    if (isWin) {
      final timeBonus = timeLeft * (5 + widget.grade);
      context.read<GameProvider>().addScore(timeBonus);
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => _buildGameEndDialog(isWin: true, timeBonus: timeBonus),
      );
    } else {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => _buildGameEndDialog(isWin: false),
      );
    }
  }
  
  Widget _buildGameEndDialog({required bool isWin, int? timeBonus}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWin ? Icons.emoji_events : Icons.timer_off,
              size: 64,
              color: isWin ? SpaceTheme.starYellow : SpaceTheme.warning,
            ),
            const SizedBox(height: 16),
            Text(
              isWin ? S.of(context)!.asteroidMathWinTitle : S.of(context)!.timesUpSpaceCadet,
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isWin
                  ? S.of(context)!.asteroidMathWinDesc(timeBonus ?? 0)
                  : S.of(context)!.asteroidMathLoseDesc,
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
                  child: Text(isWin ? S.of(context)!.nextLevel : S.of(context)!.backToMenu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    spaceshipPosition = Offset(50, screenSize.height - 90);

    final screenOffset = _screenShakeController.isAnimating
        ? Offset(
            math.sin(_screenShakeController.value * math.pi * 4) * 8,
            math.cos(_screenShakeController.value * math.pi * 3) * 6)
        : Offset.zero;

    return Scaffold(
      body: Transform.translate(
        offset: screenOffset,
        child: SpaceBackground(
          child: SafeArea(
            child: Column(
              children: [
                GameUI(
                  title: S.of(context)!.asteroidMathHunter,
                  level: widget.level,
                  timeLeft: timeLeft,
                  onBack: () {
                    gameActive = false;
                    Navigator.of(context).pop();
                  },
                ),
                _buildTargetDisplay(),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Game Objects
                      CustomPaint(
                        painter: GameObjectsPainter(
                          asteroids: asteroids,
                          explosions: explosions,
                          laserBeams: laserBeams,
                          floatingScores: floatingScores,
                          showHint: showHint,
                          targetAnswer: currentTargetIndex < targetOrder.length
                              ? targetOrder[currentTargetIndex]
                              : null,
                        ),
                        size: Size.infinite,
                      ),

                      // Interaction Layer
                      ...asteroids.map((asteroid) => Positioned(
                            left: asteroid.position.dx - asteroid.size / 2,
                            top: asteroid.position.dy - asteroid.size / 2,
                            child: GestureDetector(
                              onTap: () => _onAsteroidTapped(asteroid),
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: asteroid.size,
                                height: asteroid.size,
                              ),
                            ),
                          )),
                          
                      // Custom-drawn spaceship with thrusters
                      Positioned(
                        left: spaceshipPosition.dx - 40,
                        bottom: 10,
                        child: CustomPaint(
                          painter: SpaceshipPainter(
                            thrusterAnimation: _spaceshipController.value,
                          ),
                          size: const Size(80, 80),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetDisplay() {
    final bool shouldShow = showHint && gameActive && currentTargetIndex < targetOrder.length;

    return AnimatedOpacity(
      opacity: shouldShow ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.85),
          borderRadius: BorderRadius.circular(30),
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
          children: [
            const Icon(Icons.gps_fixed, color: SpaceTheme.rocketRed, size: 22),
            const SizedBox(width: 10),
            Text(S.of(context)!.nextTarget, style: SpaceTheme.bodyStyle.copyWith(fontSize: 18)),
            Text(
              shouldShow ? targetOrder[currentTargetIndex].toString() : '',
              style: SpaceTheme.titleStyle
                  .copyWith(color: SpaceTheme.starYellow, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ENHANCED VISUAL COMPONENTS
// ================================================================

class SpaceshipPainter extends CustomPainter {
  final double thrusterAnimation;

  SpaceshipPainter({required this.thrusterAnimation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Main ship body (triangular)
    paint.color = Colors.grey.shade300;
    final shipPath = Path()
      ..moveTo(center.dx, center.dy - 25)
      ..lineTo(center.dx - 15, center.dy + 20)
      ..lineTo(center.dx + 15, center.dy + 20)
      ..close();
    canvas.drawPath(shipPath, paint);

    // Ship details
    paint.color = Colors.blue.shade400;
    canvas.drawCircle(Offset(center.dx, center.dy - 5), 8, paint);

    // Animated thrusters
    final thrusterIntensity = 0.5 + 0.5 * math.sin(thrusterAnimation * math.pi * 8).abs();
    paint.color = Colors.orange.withOpacity(0.7 * thrusterIntensity);
    final thrusterSize = 12.0 + 8.0 * thrusterIntensity;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 8, center.dy + 25),
        width: 6,
        height: thrusterSize,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 8, center.dy + 25),
        width: 6,
        height: thrusterSize,
      ),
      paint,
    );

    // Wing details
    paint.color = Colors.red.shade400;
    canvas.drawRect(Rect.fromLTWH(center.dx - 18, center.dy + 10, 6, 8), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx + 12, center.dy + 10, 6, 8), paint);
  }

  @override
  bool shouldRepaint(covariant SpaceshipPainter oldDelegate) => 
      thrusterAnimation != oldDelegate.thrusterAnimation;
}

class GameObjectsPainter extends CustomPainter {
  final List<Asteroid> asteroids;
  final List<ParticleExplosion> explosions;
  final List<LaserBeam> laserBeams;
  final List<FloatingScore> floatingScores;
  final bool showHint;
  final int? targetAnswer;

  GameObjectsPainter({
    required this.asteroids,
    required this.explosions,
    required this.laserBeams,
    required this.floatingScores,
    required this.showHint,
    this.targetAnswer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final laser in laserBeams) {
      laser.draw(canvas);
    }
    
    for (final asteroid in asteroids) {
      final bool isTarget = targetAnswer == asteroid.answer;
      asteroid.draw(canvas, isHintActive: showHint && isTarget);
    }
    
    for (final explosion in explosions) {
      explosion.draw(canvas);
    }
    
    for (final score in floatingScores) {
      score.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================================================================
// ENHANCED DATA MODELS
// ================================================================

enum AsteroidType { rocky, icy, metallic, crystalline, volcanic }

class Asteroid {
  final int id;
  final MathProblem problem;
  Offset position;
  Offset velocity;
  double size;
  double rotationSpeed;
  double rotation;
  final AsteroidType type;
  final double hue;

  Asteroid({
    required this.id,
    required this.problem,
    required this.position,
    required this.velocity,
    required this.size,
    required this.rotationSpeed,
    required this.rotation,
    required this.type,
    required this.hue,
  });

  // Update getters to pull from the problem object
  String get mathProblem => problem.expression;
  int get answer => problem.answer;

  void draw(Canvas canvas, {required bool isHintActive}) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final rect = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    
    final Paint asteroidPaint = Paint();
    
    switch (type) {
      case AsteroidType.rocky:
        asteroidPaint.color = HSVColor.fromAHSV(1.0, hue, 0.3, 0.5).toColor();
        _drawRockyAsteroid(canvas, rect, asteroidPaint);
        break;
      case AsteroidType.icy:
        asteroidPaint.color = HSVColor.fromAHSV(1.0, 200 + hue * 0.1, 0.6, 0.8).toColor();
        _drawIcyAsteroid(canvas, rect, asteroidPaint);
        break;
      case AsteroidType.metallic:
        asteroidPaint.color = HSVColor.fromAHSV(1.0, 30 + hue * 0.1, 0.4, 0.7).toColor();
        _drawMetallicAsteroid(canvas, rect, asteroidPaint);
        break;
      case AsteroidType.crystalline:
        asteroidPaint.color = HSVColor.fromAHSV(1.0, 280 + hue * 0.1, 0.7, 0.9).toColor();
        _drawCrystallineAsteroid(canvas, rect, asteroidPaint);
        break;
      case AsteroidType.volcanic:
        asteroidPaint.color = HSVColor.fromAHSV(1.0, 10 + hue * 0.1, 0.8, 0.6).toColor();
        _drawVolcanicAsteroid(canvas, rect, asteroidPaint);
        break;
    }

    // Pulsating hint glow with particles
    if (isHintActive) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final pulseIntensity = (0.5 + 0.5 * math.sin(time * 4)).clamp(0.0, 1.0);
      
      final glowPaint = Paint()
        ..color = SpaceTheme.starYellow.withOpacity(0.6 * pulseIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * pulseIntensity);
      canvas.drawOval(rect.inflate(8), glowPaint);
      
      // Hint particles
      for (int i = 0; i < 8; i++) {
        final angle = (time + i * 0.785) * 2;
        final radius = size * 0.7;
        final sparklePos = Offset(
          math.cos(angle) * radius,
          math.sin(angle) * radius,
        );
        final sparklePaint = Paint()
          ..color = SpaceTheme.starYellow.withOpacity(0.8 * pulseIntensity);
        canvas.drawCircle(sparklePos, 3 * pulseIntensity, sparklePaint);
      }
    }

    canvas.restore();
    
    // Draw math problem text
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: size * 0.2,
      fontWeight: FontWeight.bold,
      shadows: const [
        Shadow(blurRadius: 3, color: Colors.black, offset: Offset(1, 1)),
      ],
    );
    final textSpan = TextSpan(text: mathProblem, style: textStyle);
    final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawRockyAsteroid(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawOval(rect, paint);
    
    final craterPaint = Paint()..color = Colors.black.withOpacity(0.4);
    canvas.drawCircle(Offset(-size * 0.2, size * 0.15), size * 0.12, craterPaint);
    canvas.drawCircle(Offset(size * 0.25, -size * 0.2), size * 0.08, craterPaint);
    canvas.drawCircle(Offset(-size * 0.1, -size * 0.25), size * 0.06, craterPaint);
  }

  void _drawIcyAsteroid(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawOval(rect, paint);
    
    final crystalPaint = Paint()..color = Colors.white.withOpacity(0.6);
    for (int i = 0; i < 5; i++) {
      final angle = i * 1.256;
      final x = math.cos(angle) * size * 0.2;
      final y = math.sin(angle) * size * 0.2;
      canvas.drawCircle(Offset(x, y), size * 0.05, crystalPaint);
    }
  }

  void _drawMetallicAsteroid(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawOval(rect, paint);
    
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(-size * 0.3, -size * 0.2),
      Offset(size * 0.1, size * 0.1),
      shinePaint,
    );
    canvas.drawLine(
      Offset(size * 0.2, -size * 0.3),
      Offset(-size * 0.1, size * 0.2),
      shinePaint,
    );
  }

  void _drawCrystallineAsteroid(Canvas canvas, Rect rect, Paint paint) {
    final path = Path();
    final vertices = 6;
    for (int i = 0; i < vertices; i++) {
      final angle = i * 2 * math.pi / vertices;
      final radius = size * 0.5 * (0.8 + 0.4 * math.sin(i * 1.7));
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  void _drawVolcanicAsteroid(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawOval(rect, paint);
    
    final lavaPaint = Paint()..color = Colors.orange.withOpacity(0.7);
    canvas.drawCircle(Offset(-size * 0.15, size * 0.1), size * 0.08, lavaPaint);
    canvas.drawCircle(Offset(size * 0.2, -size * 0.15), size * 0.06, lavaPaint);
    
    final glowPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(rect, glowPaint);
  }
}

class ParticleExplosion {
  final Offset position;
  final bool isCorrect;
  List<Particle> particles = [];
  double _progress = 0.0;
  final double _duration = 1.2;

  bool get isComplete => _progress >= 1.0;

  ParticleExplosion({required this.position, required this.isCorrect}) {
    final random = math.Random();
    final count = isCorrect ? 60 : 25;
    final baseColors = isCorrect 
        ? [SpaceTheme.starYellow, Colors.orange, Colors.white]
        : [SpaceTheme.rocketRed, Colors.orange, Colors.yellow];

    for (int i = 0; i < count; i++) {
      final speed = random.nextDouble() * (isCorrect ? 200 : 100) + 30;
      final angle = random.nextDouble() * 2 * math.pi;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      final color = baseColors[random.nextInt(baseColors.length)];
      
      particles.add(Particle(
        color: color.withOpacity(0.6 + random.nextDouble() * 0.4),
        velocity: velocity,
        size: random.nextDouble() * 6 + 2,
        type: ParticleType.values[random.nextInt(ParticleType.values.length)],
      ));
    }
  }

  void update(double dt) => _progress += dt / _duration;
  
  void draw(Canvas canvas) {
    final paint = Paint();
    for (final p in particles) {
      final currentPos = position + p.velocity * _progress - Offset(0, 50 * _progress * _progress);
      final opacity = ((1.0 - _progress) * (1.0 - _progress)).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(opacity);
      
      switch (p.type) {
        case ParticleType.circle:
          canvas.drawCircle(currentPos, p.size * (1.2 - _progress), paint);
          break;
        case ParticleType.star:
          _drawStar(canvas, currentPos, p.size * (1.2 - _progress), paint);
          break;
        case ParticleType.diamond:
          _drawDiamond(canvas, currentPos, p.size * (1.2 - _progress), paint);
          break;
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5 - math.pi / 2;
      final outerRadius = size;
      final innerRadius = size * 0.4;
      
      if (i == 0) {
        path.moveTo(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        );
      } else {
        path.lineTo(
          center.dx + math.cos(angle) * outerRadius,
          center.dy + math.sin(angle) * outerRadius,
        );
      }
      
      final innerAngle = angle + math.pi / 5;
      path.lineTo(
        center.dx + math.cos(innerAngle) * innerRadius,
        center.dy + math.sin(innerAngle) * innerRadius,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }
}

enum ParticleType { circle, star, diamond }

class Particle {
  Color color;
  Offset velocity;
  double size;
  ParticleType type;
  
  Particle({
    required this.color, 
    required this.velocity, 
    required this.size,
    required this.type,
  });
}

class LaserBeam {
  final Offset startPosition;
  final Offset endPosition;
  double _progress = 0.0;
  final double _duration = 0.3;

  bool get isComplete => _progress >= 1.0;

  LaserBeam({required this.startPosition, required this.endPosition});
  
  void update(double dt) => _progress += dt / _duration;

  void draw(Canvas canvas) {
    // FIX: Ensure opacity is always between 0.0 and 1.0
    final opacity = (math.sin(_progress * math.pi).abs()).clamp(0.0, 1.0);
    
    final glowPaint = Paint()
      ..strokeWidth = 20.0
      ..color = SpaceTheme.alienGreen.withOpacity(0.3 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..strokeCap = StrokeCap.round;
    
    final middlePaint = Paint()
      ..strokeWidth = 8.0
      ..color = SpaceTheme.alienGreen.withOpacity(0.8 * opacity)
      ..strokeCap = StrokeCap.round;
    
    final corePaint = Paint()
      ..strokeWidth = 3.0
      ..color = Colors.white.withOpacity(opacity)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(startPosition, endPosition, glowPaint);
    canvas.drawLine(startPosition, endPosition, middlePaint);
    canvas.drawLine(startPosition, endPosition, corePaint);
  }
}

class FloatingScore {
  Offset position;
  final String text;
  final Color color;
  double _progress = 0.0;
  final double _duration = 1.5;
  
  bool get isComplete => _progress >= 1.0;
  
  FloatingScore({required this.position, required this.text, required this.color});
  
  void update(double dt) => _progress += dt / _duration;

  void draw(Canvas canvas) {
    final currentPosition = position - Offset(0, 60 * _progress);
    final scale = 1.0 + 0.5 * math.sin(_progress * math.pi).abs();
    // FIX: Ensure opacity is always between 0.0 and 1.0
    final opacity = (math.sin(_progress * math.pi).abs()).clamp(0.0, 1.0);
    
    final textStyle = TextStyle(
      color: color.withOpacity(opacity),
      fontSize: 28 * scale,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          blurRadius: 4,
          color: Colors.black.withOpacity(opacity * 0.5),
          offset: const Offset(2, 2),
        ),
      ],
    );
    
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, currentPosition - Offset(textPainter.width / 2, 0));
  }
}