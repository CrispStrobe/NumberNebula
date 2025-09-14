import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui; // Needed for lerpDouble

import '../../../generated/l10n.dart'; // Import for localization
import '../models/math_problem.dart'; // Using your existing MathProblem model

// --- GAME CONFIGURATION ---
const int INITIAL_LIVES = 5;
const int TARGET_GATES_TO_WIN = 15;
const double BASE_GAME_SPEED = 200.0;

// --- UTILITY CLASSES ---

class Star {
  Offset position;
  double size;
  double speed;
  double brightness;
  Star({required this.position, required this.size, required this.speed, required this.brightness});
}

// --- MAIN GAME WIDGET ---

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

class _HyperdriveGatesGameState extends State<HyperdriveGatesGame> with TickerProviderStateMixin {
  // --- Animation & Timers ---
  late AnimationController _gameController;
  late AnimationController _thrusterController;
  final FocusNode _focusNode = FocusNode();

  // --- Game State ---
  bool gameActive = false;
  bool gameInitialized = false;
  int lives = INITIAL_LIVES;
  int gatesCleared = 0;
  late int targetGatesForLevel;
  double gameSpeed = BASE_GAME_SPEED;
  Timer? _speedIncreaseTimer;

  // --- Core Gameplay State ---
  MathProblem? currentProblem;
  List<GameObject> gameObjects = [];
  List<ParticleEffect> particles = [];

  // --- Player & Background ---
  late Spaceship spaceship;
  List<List<Star>> backgroundStars = [[], [], []];

  @override
  void initState() {
    super.initState();
    _gameController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_updateGame);

    _thrusterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!gameInitialized) {
      final screenSize = MediaQuery.of(context).size;
      spaceship = Spaceship(initialPosition: Offset(150, screenSize.height / 2));
      _initializeGame(screenSize);
      gameInitialized = true;
    }
  }

  @override
  void dispose() {
    _gameController.dispose();
    _thrusterController.dispose();
    _speedIncreaseTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeGame(Size screenSize) {
    setState(() {
      lives = INITIAL_LIVES;
      gatesCleared = 0;
      targetGatesForLevel = TARGET_GATES_TO_WIN + widget.level;
      gameSpeed = BASE_GAME_SPEED + (widget.grade * 15.0) + (widget.level * 5.0);
      spaceship.reset(screenSize);
      gameObjects.clear();
      particles.clear();
      gameActive = true;
    });

    _generateBackgroundStars(screenSize);
    _spawnNextGatePair(screenSize);

    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (gameActive) {
        setState(() => gameSpeed += 15);
      }
    });

    _gameController.repeat();
  }

  void _generateBackgroundStars(Size screenSize) {
    backgroundStars = List.generate(3, (_) => []);
    final random = math.Random();
    for (int layer = 0; layer < 3; layer++) {
      for (int i = 0; i < 70; i++) {
        backgroundStars[layer].add(Star(
          position: Offset(random.nextDouble() * screenSize.width, random.nextDouble() * screenSize.height),
          size: (random.nextDouble() * 1.5 + 0.5) * (layer + 1),
          speed: (random.nextDouble() * 20 + 10) * (layer + 1),
          brightness: random.nextDouble() * 0.5 + 0.5,
        ));
      }
    }
  }

  void _spawnNextGatePair(Size screenSize) {
    currentProblem = MathProblem.random(widget.grade);
    final answers = currentProblem!.generateMultipleChoiceOptions(optionsCount: 2);
    final correctAns = currentProblem!.answer;
    final incorrectAns = answers.firstWhere((a) => a != correctAns);

    final random = math.Random();
    final bool correctIsTop = random.nextBool();
    
    final gateHeight = screenSize.height * 0.4;
    final verticalGap = screenSize.height * 0.2;
    final topGateY = (screenSize.height / 2) - (verticalGap / 2) - (gateHeight / 2);
    final bottomGateY = (screenSize.height / 2) + (verticalGap / 2) + (gateHeight / 2);

    setState(() {
      gameObjects.add(Gate(
        position: Offset(screenSize.width + 100, correctIsTop ? topGateY : bottomGateY),
        answer: correctAns,
        isCorrect: true,
        size: Size(120, gateHeight),
      ));
      gameObjects.add(Gate(
        position: Offset(screenSize.width + 100, correctIsTop ? bottomGateY : topGateY),
        answer: incorrectAns,
        isCorrect: false,
        size: Size(120, gateHeight),
      ));

      for (int i=0; i < 5; i++) {
        final yPos = (screenSize.height / 2) + (i - 2) * 25.0;
        gameObjects.add(Asteroid(
          position: Offset(screenSize.width + 100, yPos),
          sizeValue: 20.0
        ));
      }
    });
  }

  void _updateGame() {
    if (!gameActive) return;

    final dt = 0.016;
    final screenSize = MediaQuery.of(context).size;
    final random = math.Random();

    setState(() {
      for (var layer in backgroundStars) {
        for (var star in layer) {
          star.position = Offset(star.position.dx - (star.speed + gameSpeed * 0.05) * dt, star.position.dy);
          if (star.position.dx < -10) {
            star.position = Offset(screenSize.width + 10, random.nextDouble() * screenSize.height);
          }
        }
      }

      spaceship.update(dt, screenSize);
      if (spaceship.isMoving) _addThrusterParticles();

      bool shouldSpawnNext = false;
      gameObjects.removeWhere((obj) {
        obj.update(dt, gameSpeed);

        if (obj is Gate) {
          final collisionRect = Rect.fromCenter(
            center: obj.position,
            width: obj.size.width,
            height: obj.size.height,
          );
          if (collisionRect.overlaps(spaceship.collisionRect)) {
            _handleGateCollision(obj);
            shouldSpawnNext = true;
            return true;
          }
        } else if (obj is Asteroid) {
            if (obj.collisionRect.overlaps(spaceship.collisionRect)) {
              _handleObstacleCollision();
              return true;
            }
        }

        if (obj is Gate && obj.position.dx < spaceship.position.dx - 100) {
            shouldSpawnNext = true;
        }

        return obj.position.dx < -150;
      });
      
      if (shouldSpawnNext) {
          gameObjects.removeWhere((obj) => obj is Gate || obj is Asteroid);
          _spawnNextGatePair(screenSize);
      }

      particles.removeWhere((p) => p.update(dt));
      
      if (lives <= 0) _gameOver();
      if (gatesCleared >= targetGatesForLevel) _winGame();
    });
  }

  void _handleGateCollision(Gate gate) {
    if (gate.isCorrect) {
      gatesCleared++;
      _addSuccessEffect();
    } else {
      lives--;
      _addDamageEffect();
    }
  }

  void _handleObstacleCollision() {
      lives--;
      _addDamageEffect();
  }
  
  void _addSuccessEffect() {
      for (int i=0; i < 20; i++) {
          particles.add(ParticleEffect.successParticle(spaceship.position));
      }
  }

  void _addDamageEffect() {
    if (spaceship.isInvincible) return;
    spaceship.damage();
    for (int i = 0; i < 25; i++) {
        particles.add(ParticleEffect.explosionParticle(spaceship.position));
    }
  }
  
  void _addThrusterParticles() {
      particles.add(ParticleEffect.thrusterParticle(spaceship.position));
  }
  
  void _winGame() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameController.stop();
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndGameDialog(isWin: true));
  }

  void _gameOver() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameController.stop();
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndGameDialog(isWin: false));
  }
  
  void _resetGame() {
    Navigator.of(context).pop();
    final screenSize = MediaQuery.of(context).size;
    _initializeGame(screenSize);
  }

  void _handleKeyboard(KeyEvent event) {
      final double moveAmount = MediaQuery.of(context).size.height / 50;
      if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowUp) {
              spaceship.moveBy(-moveAmount);
          } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowDown) {
              spaceship.moveBy(moveAmount);
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    if (!gameInitialized) {
        return const Scaffold(backgroundColor: Color(0xFF000510), body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: KeyboardListener(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKeyboard,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (gameActive) spaceship.moveTo(details.localPosition.dy);
          },
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFF000510)),
            child: Stack(
              children: [
                ..._buildBackground(),
                ...gameObjects.map((obj) => obj.build()),
                ...particles.map((p) => p.build()),
                Positioned(
                  left: spaceship.position.dx - spaceship.sizeValue,
                  top: spaceship.position.dy - spaceship.sizeValue,
                  child: SpaceshipWidget(spaceship: spaceship, thrusterAnimation: _thrusterController),
                ),
                _buildGameHeader(),
                _buildProblemDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackground() {
    return backgroundStars.expand<Widget>((layer) => layer.map<Widget>((Star star) => Positioned(
      left: star.position.dx,
      top: star.position.dy,
      child: Container(
        width: star.size,
        height: star.size,
        decoration: BoxDecoration(color: Colors.white.withOpacity(star.brightness), shape: BoxShape.circle),
      ),
    ))).toList();
  }
  
  Widget _buildGameHeader() {
    // CORRECTED: Assert non-null with '!'
    final l10n = S.of(context)!;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black.withOpacity(0.4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.hyperdriveGatesTitle}: $gatesCleared / $targetGatesForLevel', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(INITIAL_LIVES, (index) => Icon(
                  index < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent, size: 28,
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProblemDisplay() {
    if (currentProblem == null) return const SizedBox.shrink();
    // CORRECTED: Assert non-null with '!'
    final l10n = S.of(context)!;
    return Positioned(
      top: 80, left: 20, right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.yellow.withOpacity(0.8), width: 2),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: '${l10n.solve} ', style: const TextStyle(color: Colors.yellow)),
                TextSpan(text: currentProblem!.expression),
              ]
            ),
          )
        ),
      ),
    );
  }

  Widget _buildEndGameDialog({required bool isWin}) {
    // CORRECTED: Assert non-null with '!'
    final l10n = S.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0), side: BorderSide(color: isWin ? Colors.greenAccent : Colors.redAccent, width: 2)),
      title: Text(isWin ? l10n.hyperdriveGatesWinTitle : l10n.hyperdriveGatesLoseTitle, style: const TextStyle(color: Colors.white)),
      content: Text(
        isWin ? l10n.hyperdriveGatesWinDesc(targetGatesForLevel) : l10n.hyperdriveGatesLoseDesc,
        style: const TextStyle(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
      actions: <Widget>[
        TextButton(child: Text(l10n.flyAgain), onPressed: _resetGame),
        TextButton(
          child: Text(l10n.backToMenu),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// =======================================================
// --- GAME OBJECTS & WIDGETS ---
// =======================================================

abstract class GameObject {
  Offset position;
  GameObject({required this.position});
  void update(double dt, double gameSpeed);
  Widget build();
}

class Spaceship {
  Offset position;
  double sizeValue = 30.0;
  double targetY;
  bool isMoving = false;
  double damageCooldown = 0.0;

  Spaceship({required Offset initialPosition}) 
      : position = initialPosition,
        targetY = initialPosition.dy;
  
  Rect get collisionRect => Rect.fromCenter(center: position, width: sizeValue * 1.5, height: sizeValue * 1.5);
  bool get isInvincible => damageCooldown > 0;

  void reset(Size screenSize) {
      position = Offset(150, screenSize.height / 2);
      targetY = position.dy;
      damageCooldown = 0.0;
  }

  void update(double dt, Size screenSize) {
    if (damageCooldown > 0) damageCooldown -= dt;
    
    if ((position.dy - targetY).abs() > 1.0) {
      position = Offset(
        position.dx,
        ui.lerpDouble(position.dy, targetY, 0.15)!,
      );
      isMoving = true;
    } else {
      isMoving = false;
    }
  }

  void moveTo(double y) {
    targetY = y.clamp(sizeValue, ui.window.physicalSize.height / ui.window.devicePixelRatio - sizeValue);
  }

  void moveBy(double amount) {
    moveTo(targetY + amount);
  }
  
  void damage() {
    if (isInvincible) return;
    damageCooldown = 1.5;
  }
}

class Gate extends GameObject {
  final int answer;
  final bool isCorrect;
  Size size;

  Gate({required Offset position, required this.answer, required this.isCorrect, required this.size})
      : super(position: position);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
  }

  @override
  Widget build() {
    final color = isCorrect ? Colors.cyanAccent : Colors.redAccent;
    return Positioned(
      left: position.dx - size.width / 2,
      top: position.dy - size.height / 2,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.circular(15),
          color: color.withOpacity(0.1),
          boxShadow: [BoxShadow(color: color, blurRadius: 20, spreadRadius: 2)],
        ),
        child: Center(
          child: Text(
            answer.toString(),
            style: TextStyle(
              color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: color, blurRadius: 10)]
            ),
          ),
        ),
      ),
    );
  }
}

class Asteroid extends GameObject {
  double rotation;
  final double rotationSpeed;
  final double sizeValue;

  Asteroid({required Offset position, required this.sizeValue})
      : rotation = math.Random().nextDouble() * math.pi * 2,
        rotationSpeed = (math.Random().nextDouble() - 0.5) * 2.0,
        super(position: position);
  
  Rect get collisionRect => Rect.fromCenter(center: position, width: sizeValue * 1.8, height: sizeValue * 1.8);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
    rotation += rotationSpeed * dt;
  }

  @override
  Widget build() {
    return Positioned(
      left: position.dx - sizeValue,
      top: position.dy - sizeValue,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(Icons.stop_circle, color: const Color(0xFF8B4513), size: sizeValue * 2),
      ),
    );
  }
}

class ParticleEffect {
    Offset position;
    Offset velocity;
    Color color;
    double life;
    double maxLife;
    double size;

    ParticleEffect({required this.position, required this.velocity, required this.color, required this.life, required this.size}) : maxLife = life;
    
    factory ParticleEffect.thrusterParticle(Offset shipPosition) {
        final random = math.Random();
        return ParticleEffect(
            position: Offset(shipPosition.dx - 25, shipPosition.dy + (random.nextDouble() - 0.5) * 20),
            velocity: Offset(-300 - random.nextDouble() * 100, (random.nextDouble() - 0.5) * 50),
            color: Color.lerp(Colors.orangeAccent, Colors.white, random.nextDouble())!,
            life: 0.3 + random.nextDouble() * 0.2,
            size: 1.5 + random.nextDouble() * 2.0,
        );
    }

    factory ParticleEffect.explosionParticle(Offset position) {
        final random = math.Random();
        return ParticleEffect(
            position: position,
            velocity: Offset((random.nextDouble() - 0.5) * 400, (random.nextDouble() - 0.5) * 400),
            color: Color.lerp(Colors.orange, Colors.red, random.nextDouble())!,
            life: 0.5 + random.nextDouble() * 0.4,
            size: 2.0 + random.nextDouble() * 3.0,
        );
    }

    factory ParticleEffect.successParticle(Offset position) {
        final random = math.Random();
        final angle = random.nextDouble() * math.pi * 2;
        final speed = 100 + random.nextDouble() * 150;
        return ParticleEffect(
            position: position,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
            color: Color.lerp(Colors.cyanAccent, Colors.greenAccent, random.nextDouble())!,
            life: 0.6 + random.nextDouble() * 0.5,
            size: 2.0 + random.nextDouble() * 2.0,
        );
    }
    
    bool update(double dt) {
        position += velocity * dt;
        life -= dt;
        velocity *= 0.96;
        return life <= 0;
    }
    
    Widget build() {
        final opacity = (life / maxLife).clamp(0.0, 1.0);
        return Positioned(
            left: position.dx, top: position.dy,
            child: Container(
                width: size, height: size,
                decoration: BoxDecoration(color: color.withOpacity(opacity), shape: BoxShape.circle),
            ),
        );
    }
}

class SpaceshipWidget extends StatelessWidget {
    final Spaceship spaceship;
    final AnimationController thrusterAnimation;
  
    const SpaceshipWidget({super.key, required this.spaceship, required this.thrusterAnimation});

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: thrusterAnimation,
        builder: (context, child) {
          final isDamaged = spaceship.isInvincible && (spaceship.damageCooldown * 10).floor() % 2 == 0;
          return Opacity(
            opacity: isDamaged ? 0.3 : 1.0,
            child: SizedBox(
              width: spaceship.sizeValue * 2,
              height: spaceship.sizeValue * 2,
              child: CustomPaint(
                painter: SpaceshipPainter(
                  thrusting: spaceship.isMoving,
                  thrusterFlicker: thrusterAnimation.value,
                ),
              ),
            ),
          );
        },
      );
    }
}

class SpaceshipPainter extends CustomPainter {
  final bool thrusting;
  final double thrusterFlicker;

  SpaceshipPainter({required this.thrusting, required this.thrusterFlicker});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.shade300..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.2, size.height * 0.1)
      ..lineTo(0, size.height * 0.3)
      ..lineTo(0, size.height * 0.7)
      ..lineTo(size.width * 0.2, size.height * 0.9)
      ..close();
    canvas.drawPath(path, paint);
    
    final cockpitPaint = Paint()..color = Colors.lightBlue.shade200;
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width*0.6, size.height*0.5), width: size.width * 0.4, height: size.height*0.5), cockpitPaint);

    if (thrusting) {
      final thrusterPaint = Paint()..color = Color.lerp(Colors.orangeAccent, Colors.white, thrusterFlicker)!..style = PaintingStyle.fill;
      final flameLength = -15 - thrusterFlicker * 5;
      final flamePath = Path()
        ..moveTo(0, size.height * 0.3)
        ..lineTo(flameLength, size.height * 0.5)
        ..lineTo(0, size.height * 0.7)
        ..close();
      canvas.drawPath(flamePath, thrusterPaint);
    }
  }

  @override
  bool shouldRepaint(SpaceshipPainter oldDelegate) {
    return oldDelegate.thrusting != thrusting || oldDelegate.thrusterFlicker != thrusterFlicker;
  }
}

