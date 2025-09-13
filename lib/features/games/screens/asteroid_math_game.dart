import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

// --- Placeholder Imports (replace with your actual files) ---
// These are mocked up below so the code is runnable.
import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
// --- End Placeholder Imports ---


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

  // Timers
  late Timer _gameTimer;
  Timer? _hintTimer;
  
  // Audio
  final AudioPlayer _sfxPlayer = AudioPlayer();

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
    
    // Set sound volume
    _sfxPlayer.setVolume(0.7);

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
    _gameTimer.cancel();
    _hintTimer?.cancel();
    _sfxPlayer.dispose();
    super.dispose();
  }

  void _playSound(String soundAsset) {
    // NOTE: Make sure you have these assets in the path specified in your pubspec.yaml
    // Example: assets/audio/laser.wav
    _sfxPlayer.play(AssetSource(soundAsset));
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
    // Hint appears faster on easier levels
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
    
    for (int i = 0; i < asteroidCount; i++) {
      MathProblem problem;
      
      // FIX: Greatly increased the probability of generating a math problem
      // instead of just a number, based on difficulty settings.
      if (random.nextDouble() < difficulty.equationProbability) {
        do {
          problem = MathProblem.random(
            widget.grade, 
            difficulty: (difficulty.difficultyMultiplier * 2).round().clamp(1, 5),
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
        operation: MathOperation.addition, // Assuming a default enum value
        operandA: plainNumber,
        operandB: 0,
        difficulty: 1,
    );
    }

      usedAnswers.add(problem.answer);
      
      final asteroidSize = (70.0 + random.nextDouble() * 30) * difficulty.visualComplexity;
      final asteroidSpeed = (30.0 + (difficulty.gameSpeed * 20));

      Offset position;
      int attempts = 0;
      do {
        position = Offset(
          random.nextDouble() * (screenSize.width - asteroidSize),
          random.nextDouble() * (screenSize.height - asteroidSize - 220) + 100,
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
        rotationSpeed: (random.nextDouble() - 0.5) * 2 * difficulty.animationSpeed,
        rotation: random.nextDouble() * 2 * math.pi,
      ));
    }
    
    targetOrder.addAll(usedAnswers);
    targetOrder.sort(); // The game objective is to destroy them in ascending order
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
    final double deltaTime = 0.016; // Assumes ~60 FPS

    setState(() {
      // Update asteroids
      for (var asteroid in asteroids) {
        asteroid.position += asteroid.velocity * deltaTime;
        asteroid.rotation += asteroid.rotationSpeed * deltaTime;

        // Wall bouncing logic
        final margin = asteroid.size / 2;
        if (asteroid.position.dx <= margin || asteroid.position.dx >= screenSize.width - margin) {
          asteroid.velocity = Offset(-asteroid.velocity.dx * 0.85, asteroid.velocity.dy);
          asteroid.position = Offset(
            asteroid.position.dx.clamp(margin, screenSize.width - margin),
            asteroid.position.dy
          );
        }
        if (asteroid.position.dy <= margin + 90 || asteroid.position.dy >= screenSize.height - margin - 90) {
          asteroid.velocity = Offset(asteroid.velocity.dx, -asteroid.velocity.dy * 0.85);
          asteroid.position = Offset(
            asteroid.position.dx,
            asteroid.position.dy.clamp(margin + 90, screenSize.height - margin - 90)
          );
        }
      }

      // Update and remove finished animations
      explosions.removeWhere((e) => e.isComplete);
      laserBeams.removeWhere((l) => l.isComplete);
      floatingScores.removeWhere((s) => s.isComplete);
      
      // Update animation progress
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

    // Reset hint timer on any interaction
    setState(() => showHint = false);
    _startHintTimer();

    final expectedAnswer = targetOrder[currentTargetIndex];

    if (asteroid.answer == expectedAnswer) {
      // --- Correct Asteroid! ---
      _playSound('audio/correct_explosion.mp3');
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
      // --- Wrong Asteroid! ---
      _playSound('audio/wrong_hit.wav');
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
      final screenSize = MediaQuery.of(context).size;
      laserBeams.add(LaserBeam(
        startPosition: Offset(60, screenSize.height - 50),
        endPosition: asteroid.position
      ));
    });
     _playSound('audio/laser_fire.wav');
  }

  void _endGame({required bool isWin}) {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    _hintTimer?.cancel();
    
    if (isWin) {
      final timeBonus = timeLeft * (5 + widget.grade);
      context.read<GameProvider>().addScore(timeBonus);
      _playSound('audio/win_jingle.mp3');
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => _buildGameEndDialog(isWin: true, timeBonus: timeBonus),
      );
    } else {
      _playSound('audio/lose_jingle.mp3');
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => _buildGameEndDialog(isWin: false),
      );
    }
  }
  
  // Combines the build method for both win/loss dialogs
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
              isWin ? "Mission Accomplished!" : "Time's Up!",
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isWin
                  ? 'Time Bonus: $timeBonus points!\nYou are a true Math Hunter!'
                  : 'The asteroid field overwhelmed the ship!\nTry again, Commander!',
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
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to level select
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
    // Screen shake calculation
    final screenOffset = _screenShakeController.isAnimating
        ? Offset(
            math.sin(_screenShakeController.value * math.pi * 4) * 8,
            math.cos(_screenShakeController.value * math.pi * 3) * 6)
        : Offset.zero;

    return Scaffold(
      body: Transform.translate(
        offset: screenOffset,
        child: SpaceBackground( // AWESOME: Now with an animated starfield!
          child: SafeArea(
            child: Column(
              children: [
                GameUI(
                  title: "Asteroid Hunter",
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
                      // Game Objects drawn with CustomPainters for performance
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

                      // Interaction Layer (invisible GestureDetector for each asteroid)
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
                          
                      // AWESOME: Player's spaceship
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: SpaceshipWidget(),
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
    // FIX: Target display now correctly tied to the 'showHint' flag.
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed, color: SpaceTheme.rocketRed, size: 22),
            const SizedBox(width: 10),
            Text('Next Target: ', style: SpaceTheme.bodyStyle.copyWith(fontSize: 18)),
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
// AWESOME NEW & ENHANCED WIDGETS AND PAINTERS
// ================================================================

class SpaceshipWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Replace 'assets/images/spaceship.png' with your own image asset
    return Image.asset('assets/images/spaceship.png', width: 100, height: 100);
  }
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
    // Draw Lasers
    for (final laser in laserBeams) {
      laser.draw(canvas);
    }
    // Draw Asteroids
    for (final asteroid in asteroids) {
      final bool isTarget = targetAnswer == asteroid.answer;
      asteroid.draw(canvas, isHintActive: showHint && isTarget);
    }
    // Draw Explosions
    for (final explosion in explosions) {
      explosion.draw(canvas);
    }
    // Draw Floating Scores
    for (final score in floatingScores) {
      score.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================================================================
// DATA MODELS FOR GAME OBJECTS
// ================================================================

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

  void draw(Canvas canvas, {required bool isHintActive}) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final rect = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    
    // Main asteroid body
    final Paint asteroidPaint = Paint()..color = Colors.grey.shade700;
    canvas.drawOval(rect, asteroidPaint);

    // Craters
    final Paint craterPaint = Paint()..color = Colors.black.withOpacity(0.3);
    canvas.drawCircle(Offset(-size * 0.2, size * 0.15), size * 0.15, craterPaint);
    canvas.drawCircle(Offset(size * 0.25, -size * 0.2), size * 0.1, craterPaint);

    // FIX: Hint is now a pulsating glow instead of a static border
    if (isHintActive) {
      final glowPaint = Paint()
        ..color = SpaceTheme.starYellow.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawOval(rect.inflate(6), glowPaint);
    }

    canvas.restore();
    
    // Draw the math problem text (not rotated)
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: size * 0.22,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
    );
    final textSpan = TextSpan(text: mathProblem, style: textStyle);
    final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}

class ParticleExplosion {
  final Offset position;
  final bool isCorrect;
  List<Particle> particles = [];
  double _progress = 0.0;
  final double _duration = 0.8; // seconds

  bool get isComplete => _progress >= 1.0;

  ParticleExplosion({required this.position, required this.isCorrect}) {
    final random = math.Random();
    final count = isCorrect ? 40 : 15;
    final baseColor = isCorrect ? SpaceTheme.starYellow : SpaceTheme.rocketRed;

    for (int i = 0; i < count; i++) {
      final speed = random.nextDouble() * (isCorrect ? 150 : 80) + 20;
      final angle = random.nextDouble() * 2 * math.pi;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      particles.add(Particle(
        color: baseColor.withOpacity(0.5 + random.nextDouble() * 0.5),
        velocity: velocity,
        size: random.nextDouble() * 4 + 2,
      ));
    }
  }

  void update(double dt) => _progress += dt / _duration;
  
  void draw(Canvas canvas) {
    final paint = Paint();
    for (final p in particles) {
      final currentPos = position + p.velocity * _progress;
      paint.color = p.color.withOpacity(1.0 - _progress);
      canvas.drawCircle(currentPos, p.size * (1.0 - _progress), paint);
    }
  }
}

class Particle {
  Color color;
  Offset velocity;
  double size;
  Particle({required this.color, required this.velocity, required this.size});
}

class LaserBeam {
    final Offset startPosition;
    final Offset endPosition;
    double _progress = 0.0;
    final double _duration = 0.2; // seconds

    bool get isComplete => _progress >= 1.0;

    LaserBeam({required this.startPosition, required this.endPosition});
    
    void update(double dt) => _progress += dt / _duration;

    void draw(Canvas canvas) {
      final paint = Paint()
        ..strokeWidth = 4.0
        ..color = SpaceTheme.alienGreen.withOpacity(1.0 - _progress)
        ..strokeCap = StrokeCap.round;
      
      final glowPaint = Paint()
        ..strokeWidth = 12.0
        ..color = SpaceTheme.alienGreen.withOpacity(0.5 * (1.0 - _progress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawLine(startPosition, endPosition, glowPaint);
      canvas.drawLine(startPosition, endPosition, paint);
    }
}

class FloatingScore {
    Offset position;
    final String text;
    final Color color;
    double _progress = 0.0;
    final double _duration = 1.2; // seconds
    
    bool get isComplete => _progress >= 1.0;
    
    FloatingScore({required this.position, required this.text, required this.color});
    
    void update(double dt) => _progress += dt / _duration;

    void draw(Canvas canvas) {
        final currentPosition = position - Offset(0, 40 * _progress);
        final textStyle = TextStyle(
          color: color.withOpacity(1.0 - _progress),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        );
        final textSpan = TextSpan(text: text, style: textStyle);
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        textPainter.layout();
        textPainter.paint(canvas, currentPosition - Offset(textPainter.width/2, 0));
    }
}