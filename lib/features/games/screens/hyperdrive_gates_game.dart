import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for keyboard input
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui; // Needed for ImageFilter

import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

// --- GAME CONFIGURATION CONSTANTS ---
const int ASTEROID_SPAWN_CHANCE = 250;
const int POWERUP_SPAWN_CHANCE = 400;

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
  // --- Animation & Timers ---
  late AnimationController _gameController;
  late AnimationController _thrusterController;
  late AnimationController _backgroundController;
  late AnimationController _screenShakeController;
  late Timer _gameTimer;
  final FocusNode _focusNode = FocusNode();

  // --- Game State ---
  List<GameObject> gameObjects = [];
  List<ParticleEffect> particles = [];
  List<List<Star>> backgroundStars = [[], [], []];
  Spaceship spaceship = Spaceship();

  double gameSpeed = 100.0;
  double gateSpawnTimer = 0.0;
  int correctGatesPassedThrough = 0;
  int targetGatesNeeded = 10;
  bool gameActive = true;
  double lives = 3.0;

  // --- Awesome Features State ---
  int comboCounter = 0;
  Timer? _comboTimer;
  PowerUpType? activePowerUp;
  Timer? _powerUpTimer;
  Offset screenShakeOffset = Offset.zero;

  // --- Math Problem ---
  MathProblem? currentProblem;
  int correctAnswer = 0;

  @override
  void initState() {
    super.initState();
    _gameController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();

    _thrusterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150))
      ..repeat(reverse: true);

    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();

    _screenShakeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
          ..addListener(() {
            if (_screenShakeController.isAnimating) {
              setState(() {
                final progress = _screenShakeController.value;
                final shakeAmount = 10 * math.sin(progress * math.pi * 4);
                screenShakeOffset = Offset(
                    (math.Random().nextDouble() - 0.5) * shakeAmount,
                    (math.Random().nextDouble() - 0.5) * shakeAmount);
              });
            } else {
              setState(() {
                screenShakeOffset = Offset.zero;
              });
            }
          });

    _initializeGame();
    _gameController.addListener(_updateGame);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _gameController.dispose();
    _thrusterController.dispose();
    _backgroundController.dispose();
    _screenShakeController.dispose();
    _gameTimer.cancel();
    _comboTimer?.cancel();
    _powerUpTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeGame() {
    switch (widget.grade) {
      case 3:
        targetGatesNeeded = 8;
        gameSpeed = 90.0;
        break;
      case 4:
        targetGatesNeeded = 10;
        gameSpeed = 110.0;
        break;
      case 5:
        targetGatesNeeded = 12;
        gameSpeed = 130.0;
        break;
      case 6:
      default:
        targetGatesNeeded = 15;
        gameSpeed = 150.0;
        break;
    }
    _generateBackgroundStars();
    _generateNewProblem();

    _gameTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (gameActive) {
        setState(() {
          gameSpeed += 15;
        });
      }
    });
  }

  void _generateBackgroundStars() {
    for (int layer = 0; layer < 3; layer++) {
      backgroundStars[layer].clear();
      final random = math.Random();
      for (int i = 0; i < 70; i++) {
        backgroundStars[layer].add(Star(
          position: Offset(
            random.nextDouble() * 2000,
            random.nextDouble() * 1000,
          ),
          size: (random.nextDouble() * 1.5 + 0.5) * (layer + 1),
          speed: (random.nextDouble() * 20 + 10) * (layer + 1),
          brightness: random.nextDouble() * 0.5 + 0.5,
        ));
      }
    }
  }

  void _generateNewProblem() {
    final r = math.Random();
    final problemType = r.nextInt(3); // 0: +, 1: -, 2: *

    if (problemType == 0) { // Addition
        int a = r.nextInt(20) + (widget.grade * 5);
        int b = r.nextInt(15) + (widget.grade * 3);
        correctAnswer = a + b;
        currentProblem = MathProblem(expression: '$a + $b', answer: correctAnswer);
    } else if (problemType == 1) { // Subtraction
        int a = r.nextInt(25) + (widget.grade * 6);
        int b = r.nextInt(a - 1) + 1; // Ensure b is smaller than a and > 0
        correctAnswer = a - b;
        currentProblem = MathProblem(expression: '$a - $b', answer: correctAnswer);
    } else { // Multiplication (for higher grades)
        int a = r.nextInt(8) + (widget.grade - 2);
        int b = r.nextInt(8) + 2;
        correctAnswer = a * b;
        currentProblem = MathProblem(expression: '$a × $b', answer: correctAnswer);
    }
  }

  void _updateGame() {
    if (!gameActive) return;

    final dt = 0.016; // 60 FPS
    final screenSize = MediaQuery.of(context).size;
    final random = math.Random();

    final effectiveGameSpeed = activePowerUp == PowerUpType.slowMo ? gameSpeed * 0.5 : gameSpeed;

    setState(() {
      for (int i = 0; i < backgroundStars.length; i++) {
        for (var star in backgroundStars[i]) {
          star.position = Offset(
            star.position.dx - (star.speed + effectiveGameSpeed * 0.1 * (i + 1)) * dt,
            star.position.dy,
          );
          if (star.position.dx < -10) {
            star.position =
                Offset(screenSize.width + 10, random.nextDouble() * screenSize.height);
          }
        }
      }

      spaceship.update(dt, screenSize);
      _spawnObjects(dt, screenSize, effectiveGameSpeed);

      gameObjects.removeWhere((obj) {
        obj.update(dt, effectiveGameSpeed);
        if (_checkCollision(obj)) {
          _handleCollision(obj);
          return true;
        }
        if (obj.position.dx < -100) {
          if (obj is HyperdriveGate && obj.isCorrect) {
            lives = (lives - 0.25).clamp(0.0, 3.0);
            _resetCombo();
          }
          return true;
        }
        return false;
      });

      particles.removeWhere((p) => p.update(dt));
      _addThrusterParticles();
      
      if (correctGatesPassedThrough >= targetGatesNeeded) _winGame();
      if (lives <= 0.0) _gameOver();
    });
  }

  void _spawnObjects(double dt, Size screenSize, double currentSpeed) {
    gateSpawnTimer += dt;
    final dynamicSpawnRate = 2.5 - (currentSpeed / 200.0).clamp(0.0, 1.8);
    if (gateSpawnTimer > dynamicSpawnRate) {
      _spawnGate(screenSize);
      gateSpawnTimer = 0.0;
    }
    if (math.Random().nextInt(ASTEROID_SPAWN_CHANCE) == 0) _spawnAsteroid(screenSize);
    if (math.Random().nextInt(POWERUP_SPAWN_CHANCE) == 0) _spawnPowerUp(screenSize);
  }
  
  // Replace the entire _spawnGate method
  void _spawnGate(Size screenSize) {
    final random = math.Random();
    final gateY = random.nextDouble() * (screenSize.height - 250) + 150;

    // Decide which scenario to spawn
    if (random.nextDouble() < 0.4) { // 40% chance for an Enemy encounter
        final isEnemyAbove = random.nextBool();
        final yOffset = 100.0; // Distance between gate and enemy

        // Spawn the CORRECT gate
        gameObjects.add(HyperdriveGate(
        position: Offset(screenSize.width + 60, isEnemyAbove ? gateY + yOffset : gateY - yOffset),
        answer: correctAnswer,
        isCorrect: true,
        ));

        // Spawn the ENEMY with an incorrect answer
        int enemyAnswer;
        do {
        enemyAnswer = correctAnswer + (random.nextBool() ? 1 : -1) * (random.nextInt(10) + 1);
        } while (enemyAnswer == correctAnswer || enemyAnswer <= 0);

        gameObjects.add(Enemy(
        position: Offset(screenSize.width + 60, isEnemyAbove ? gateY - yOffset : gateY + yOffset),
        incorrectAnswer: enemyAnswer,
        ));

    } else { // 60% chance for the classic two-gate setup
        // This logic creates two gates, one correct and one incorrect
        int incorrectAnswer;
        do {
        incorrectAnswer = correctAnswer + (random.nextBool() ? 1 : -1) * (random.nextInt(10) + 1);
        } while (incorrectAnswer == correctAnswer || incorrectAnswer <= 0);
        
        final yOffset = 120.0 + random.nextDouble() * 50;
        final isCorrectGateTop = random.nextBool();

        // Spawn Correct Gate
        gameObjects.add(HyperdriveGate(
        position: Offset(screenSize.width + 60, isCorrectGateTop ? gateY - yOffset : gateY + yOffset),
        answer: correctAnswer,
        isCorrect: true,
        ));
        
        // Spawn Incorrect Gate
        gameObjects.add(HyperdriveGate(
        position: Offset(screenSize.width + 60, isCorrectGateTop ? gateY + yOffset : gateY - yOffset),
        answer: incorrectAnswer,
        isCorrect: false,
        ));
    }
    }
  
  void _spawnAsteroid(Size screenSize) {
    final random = math.Random();
    final yPos = random.nextDouble() * (screenSize.height - 150) + 100;
    final size = random.nextDouble() * 30 + 20;
    final rotationSpeed = (random.nextDouble() - 0.5) * 2.0;
    
    gameObjects.add(Asteroid(
        position: Offset(screenSize.width + size, yPos),
        size: size,
        rotationSpeed: rotationSpeed,
    ));
  }

  void _spawnPowerUp(Size screenSize) {
    final random = math.Random();
    final yPos = random.nextDouble() * (screenSize.height - 200) + 120;
    final type = PowerUpType.values[random.nextInt(PowerUpType.values.length)];

    gameObjects.add(PowerUp(
        position: Offset(screenSize.width + 30, yPos),
        type: type,
    ));
  }

  bool _checkCollision(GameObject obj) {
    return (spaceship.position - obj.position).distance < (spaceship.size + obj.size) * 0.7;
  }

  void _handleCollision(GameObject obj) {
    if (obj is HyperdriveGate) {
      if (obj.isCorrect) {
        correctGatesPassedThrough++;
        _incrementCombo();
        // final scoreToAdd = (50 * widget.grade) * (1 + comboCounter * 0.1);
        // context.read<GameProvider>().addScore(scoreToAdd.toInt());
        _addBoostEffect();
        _generateNewProblem();
      } else {
        if (activePowerUp == PowerUpType.shield) {
            _endPowerUp();
        } else {
            lives -= 1.0;
            _addDamageEffect();
            _resetCombo();
        }
      }
    } else if (obj is Asteroid) {
        if (activePowerUp == PowerUpType.shield) {
            _endPowerUp();
        } else {
            lives -= 0.5;
            _addDamageEffect();
            _resetCombo();
        }
    } else if (obj is Enemy) {
        if (activePowerUp == PowerUpType.shield) {
            _endPowerUp();
        } else {
            lives -= 1.0; // Hitting an enemy is a big mistake!
            _addDamageEffect();
            _resetCombo();
        }
    } else if (obj is PowerUp) {
        _activatePowerUp(obj.type);
    }
  }

  void _incrementCombo() {
      comboCounter++;
      _comboTimer?.cancel();
      _comboTimer = Timer(const Duration(seconds: 4), _resetCombo);
  }

  void _resetCombo() {
      setState(() {
        comboCounter = 0;
      });
      _comboTimer?.cancel();
  }
  
  void _activatePowerUp(PowerUpType type) {
      setState(() => activePowerUp = type);
      _powerUpTimer?.cancel();
      _powerUpTimer = Timer(const Duration(seconds: 8), _endPowerUp);
  }

  void _endPowerUp() {
      setState(() => activePowerUp = null);
      _powerUpTimer?.cancel();
  }

  void _triggerScreenShake() {
      _screenShakeController.forward(from: 0.0);
  }
  
  void _addBoostEffect() {
    spaceship.boost();
    for (int i = 0; i < 30; i++) {
        particles.add(ParticleEffect.boostParticle(spaceship.position));
    }
  }
  
  void _addDamageEffect() {
    spaceship.damage();
    _triggerScreenShake();
    for (int i = 0; i < 25; i++) {
        particles.add(ParticleEffect.explosionParticle(spaceship.position));
    }
  }
  
  void _addThrusterParticles() {
      if (!spaceship.thrusting) return;
      final particleCount = spaceship.isBoosting ? 6 : 2;
      for (int i = 0; i < particleCount; i++) {
          particles.add(ParticleEffect.thrusterParticle(
            spaceship.position,
            isBoosting: spaceship.isBoosting
          ));
      }
  }
  
  void _winGame() {
    if (!gameActive) return;
    gameActive = false;
    // context.read<GameProvider>().addScore(500);
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndGameDialog(isWin: true));
  }

  void _gameOver() {
    if (!gameActive) return;
    gameActive = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndGameDialog(isWin: false));
  }
  
  void _resetGame() {
    setState(() {
      gameActive = true;
      lives = 3.0;
      correctGatesPassedThrough = 0;
      gameObjects.clear();
      particles.clear();
      spaceship = Spaceship();
      gateSpawnTimer = 0.0;
      _resetCombo();
      _endPowerUp();
    });
    _initializeGame();
  }
  
  void _handleKeyboard(KeyEvent event) {
      final isShiftPressed = event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight;
      
      if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowUp) {
              spaceship.verticalInput = -1.0;
              spaceship.thrusting = true;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowDown) {
              spaceship.verticalInput = 1.0;
              spaceship.thrusting = true;
          } else if (isShiftPressed) {
              spaceship.isBoosting = true;
          }
      } else if (event is KeyUpEvent) {
          if ([LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown].contains(event.logicalKey)) {
              spaceship.verticalInput = 0.0;
              spaceship.thrusting = false;
          } else if (isShiftPressed) {
              spaceship.isBoosting = false;
          }
      }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyboard,
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF000510)),
          child: SafeArea(
            child: Stack(
              children: [
                Transform.translate(
                  offset: screenShakeOffset,
                  child: Stack(
                    children: [
                      ..._buildBackground(),
                      ...gameObjects.map((obj) => obj.build()),
                      ...particles.map((p) => p.build()),
                      Positioned(
                        left: spaceship.position.dx - spaceship.size,
                        top: spaceship.position.dy - spaceship.size,
                        child: SpaceshipWidget(
                          spaceship: spaceship,
                          thrusterAnimation: _thrusterController,
                          activePowerUp: activePowerUp,
                        ),
                      ),
                    ],
                  ),
                ),
                
                _buildGameHeader(),
                Positioned(top: 80, left: 20, right: 20, child: _buildProblemDisplay()),
                if (comboCounter > 1) _buildComboDisplay(),
                if (activePowerUp != null) _buildPowerUpDisplay(),

                Positioned(bottom: 20, left: 20, right: 20, child: _buildInstructions()),
                _buildControlOverlay(),
                _buildBoostButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackground() {
    // FIXED: Explicitly defined the type <Widget> and (Star star)
    // to resolve type inference errors.
    return backgroundStars.expand<Widget>((layer) => layer.map<Widget>((Star star) => Positioned(
      left: star.position.dx,
      top: star.position.dy,
      child: Container(
        width: star.size,
        height: star.size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(star.brightness),
          shape: BoxShape.circle,
          boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: star.size * 2)
          ]
        ),
      ),
    ))).toList();
  }
  
  Widget _buildGameHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black.withOpacity(0.5),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                    print("Back button pressed!"); // For debugging
                    Navigator.of(context).pop();
                },
            ),
            Expanded(child: _buildBoostMeter()),
            const SizedBox(width: 16),
            Text(
              '$correctGatesPassedThrough/$targetGatesNeeded ',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.engineering, color: Colors.amber),
            const SizedBox(width: 16),
            Row(
              children: List.generate(3, (index) => Icon(
                index < lives.floor() ? Icons.favorite : Icons.favorite_border,
                color: Colors.redAccent,
              )),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProblemDisplay() {
    if (currentProblem == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.yellow.withOpacity(0.8), width: 2),
      ),
      child: Column(
        children: [
          Text(
            currentProblem!.expression,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "TARGET: $correctAnswer",
            style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostMeter() {
    final fuelPercentage = spaceship.boostFuel / Spaceship.maxBoostFuel;
    return Row(
      children: [
        Icon(
          Icons.local_fire_department,
          color: fuelPercentage > 0.1 ? Colors.orangeAccent : Colors.grey,
          size: 20
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: fuelPercentage,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
              minHeight: 10,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildComboDisplay() {
    return Positioned(
      top: 180,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'COMBO x$comboCounter',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
            shadows: [Shadow(blurRadius: 10, color: Colors.orange)]
          ),
        ),
      ),
    );
  }

  Widget _buildPowerUpDisplay() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: activePowerUp!.color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activePowerUp!.icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                activePowerUp!.displayName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Use W/S or Arrows | Drag to Move | Hold Shift or Boost Button',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _buildControlOverlay() {
    return Listener(
      onPointerDown: (details) => spaceship.thrusting = true,
      onPointerMove: (details) {
        if (!gameActive) return;
        spaceship.targetY = details.localPosition.dy;
        spaceship.thrusting = true;
      },
      onPointerUp: (details) => spaceship.thrusting = false,
      child: Container(color: Colors.transparent),
    );
  }
  
  Widget _buildBoostButton() {
    return Positioned(
      bottom: 60,
      right: 20,
      child: Listener(
        onPointerDown: (_) => setState(() => spaceship.isBoosting = true),
        onPointerUp: (_) => setState(() => spaceship.isBoosting = false),
        child: CircleAvatar(
          radius: 35,
          backgroundColor: spaceship.isBoosting ? Colors.orange.withOpacity(0.8) : Colors.white.withOpacity(0.3),
          child: const Icon(Icons.local_fire_department, size: 40, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEndGameDialog({required bool isWin}) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: const BorderSide(color: Colors.yellow, width: 2),
      ),
      title: Row(
        children: [
          Icon(isWin ? Icons.check_circle : Icons.cancel, color: isWin ? Colors.greenAccent : Colors.redAccent, size: 30),
          const SizedBox(width: 10),
          Text(isWin ? 'Mission Complete!' : 'Game Over', style: const TextStyle(color: Colors.white)),
        ],
      ),
      content: Text(
        isWin ? 'You successfully navigated the gates!' : 'Your ship took too much damage. Try again!',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Fly Again'),
          onPressed: () {
            Navigator.of(context).pop();
            _resetGame();
          },
        ),
        TextButton(
          child: const Text('Return to Base'),
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
// --- GAME OBJECT AND WIDGET DEFINITIONS ---
// =======================================================

class Star {
  Offset position;
  double size;
  double speed;
  double brightness;
  Star({required this.position, required this.size, required this.speed, required this.brightness});
}

class MathProblem {
  final String expression;
  final int answer;
  MathProblem({required this.expression, required this.answer});
}

abstract class GameObject {
  Offset position;
  double size;
  GameObject({required this.position, required this.size});
  void update(double dt, double gameSpeed);
  Widget build();
}

class Spaceship {
  Offset position = const Offset(100, 300);
  double size = 30.0;
  double targetY = 300;
  double velocityY = 0;
  bool thrusting = false;
  double verticalInput = 0.0;
  bool isBoosting = false;
  double boostFuel = maxBoostFuel;
  static const double maxBoostFuel = 100.0;
  static const double boostCostPerSecond = 35.0;
  static const double fuelRegenPerSecond = 15.0;
  double boostTime = 0;
  double damageTime = 0;
  double angle = 0;

  void update(double dt, Size screenSize) {
    // --- Boost Fuel Logic (Unchanged) ---
    if (isBoosting && boostFuel > 0) {
        boostFuel -= boostCostPerSecond * dt;
    } else {
        isBoosting = false;
        if (boostFuel < maxBoostFuel) {
        boostFuel += fuelRegenPerSecond * dt;
        }
    }
    boostFuel = boostFuel.clamp(0.0, maxBoostFuel);

    // --- MOVEMENT LOGIC ---
    // Greatly increase the difference between normal and boost speeds
    final double maxSpeed = isBoosting ? 800.0 : 400.0;
    final double keyboardAccel = isBoosting ? 2500.0 : 800.0;
    final double touchAccelMultiplier = isBoosting ? 20.0 : 10.0;
    
    // Apply movement input
    if (verticalInput != 0.0) { // Keyboard input
        velocityY += verticalInput * keyboardAccel * dt;
    } else { // Touch/Mouse input
        final diff = targetY - position.dy;
        final touchAccel = (diff * touchAccelMultiplier).clamp(-1500.0, 1500.0);
        velocityY += touchAccel * dt;
    }

    // Clamp velocity to the new max speed
    velocityY = velocityY.clamp(-maxSpeed, maxSpeed);
    
    // Reduce damping while boosting so you can feel the speed
    velocityY *= isBoosting ? 0.97 : 0.92;
    
    position = Offset(
        position.dx,
        (position.dy + velocityY * dt).clamp(size, screenSize.height - size),
    );
    
    angle = (velocityY / 200.0).clamp(-0.4, 0.4);

    if (boostTime > 0) boostTime -= dt;
    if (damageTime > 0) damageTime -= dt;
    }
  
  void boost() => boostTime = 0.3;
  void damage() => damageTime = 0.5;
}

class HyperdriveGate extends GameObject {
  final int answer;
  final bool isCorrect;
  final Color color = Colors.cyan; // All gates are the same color for now

  HyperdriveGate({required Offset position, required this.answer, required this.isCorrect})
      : super(position: position, size: 50.0);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
  }

  @override
  Widget build() {
    return Positioned(
      left: position.dx - 60,
      top: position.dy - 40,
      child: HyperdriveGateWidget(gate: this),
    );
  }
}

class Asteroid extends GameObject {
  double rotation;
  final double rotationSpeed;

  Asteroid({required Offset position, required double size, required this.rotationSpeed})
      : rotation = math.Random().nextDouble() * math.pi * 2,
        super(position: position, size: size);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * 0.7 * dt, position.dy);
    rotation += rotationSpeed * dt;
  }

  @override
  Widget build() {
    return Positioned(
      left: position.dx - size,
      top: position.dy - size,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: size * 2,
          height: size * 2,
          decoration: BoxDecoration(
            color: Colors.brown.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.brown.shade900, width: 3),
          ),
        ),
      ),
    );
  }
}

enum PowerUpType { shield, slowMo }

extension PowerUpInfo on PowerUpType {
  String get displayName {
    switch(this) {
      case PowerUpType.shield: return "SHIELD ACTIVE";
      case PowerUpType.slowMo: return "TIME WARP";
    }
  }
  IconData get icon {
    switch(this) {
      case PowerUpType.shield: return Icons.shield;
      case PowerUpType.slowMo: return Icons.hourglass_empty;
    }
  }
  Color get color {
    switch(this) {
      case PowerUpType.shield: return Colors.blueAccent;
      case PowerUpType.slowMo: return Colors.purpleAccent;
    }
  }
}

class PowerUp extends GameObject {
  final PowerUpType type;
  double _animation = 0.0;

  PowerUp({required Offset position, required this.type})
      : super(position: position, size: 25.0);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * 0.8 * dt, position.dy);
    _animation += dt * 4;
  }

  @override
  Widget build() {
    final glowSize = size * (1.5 + math.sin(_animation) * 0.5);
    return Positioned(
      left: position.dx - size,
      top: position.dy - size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: type.color, blurRadius: 20, spreadRadius: 5)]
            ),
          ),
          Icon(type.icon, color: Colors.white, size: size * 1.5),
        ],
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

    ParticleEffect({
        required this.position, required this.velocity, required this.color,
        required this.life, required this.size,
    }) : maxLife = life;
    
    factory ParticleEffect.thrusterParticle(Offset shipPosition, {bool isBoosting = false}) {
        final random = math.Random();
        return ParticleEffect(
            position: Offset(shipPosition.dx - 25, shipPosition.dy + (random.nextDouble() - 0.5) * 20),
            velocity: Offset((isBoosting ? -400 : -200) - random.nextDouble() * 100, (random.nextDouble() - 0.5) * 40),
            color: Color.lerp(isBoosting ? Colors.cyanAccent : Colors.orangeAccent, Colors.white, random.nextDouble())!,
            life: (isBoosting ? 0.6 : 0.4) + random.nextDouble() * 0.3,
            size: (isBoosting ? 2.5 : 1.5) + random.nextDouble() * 2.0,
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

    factory ParticleEffect.boostParticle(Offset position) {
        final random = math.Random();
        return ParticleEffect(
            position: position,
            velocity: Offset(-400 - random.nextDouble() * 200, (random.nextDouble() - 0.5) * 50),
            color: Color.lerp(Colors.cyanAccent, Colors.white, random.nextDouble())!,
            life: 0.6 + random.nextDouble() * 0.4,
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
            left: position.dx,
            top: position.dy,
            child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    color: color.withOpacity(opacity),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withOpacity(opacity * 0.5), blurRadius: size * 2)]
                ),
            ),
        );
    }
}

class SpaceshipWidget extends StatelessWidget {
    final Spaceship spaceship;
    final AnimationController thrusterAnimation;
    final PowerUpType? activePowerUp;
  
    const SpaceshipWidget({
      super.key, required this.spaceship, required this.thrusterAnimation, this.activePowerUp,
    });

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: thrusterAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: spaceship.angle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (activePowerUp == PowerUpType.shield)
                  Container(
                    width: spaceship.size * 2.5,
                    height: spaceship.size * 2.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.3),
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                    ),
                  ),
                SizedBox(
                  width: spaceship.size * 2,
                  height: spaceship.size * 2,
                  child: CustomPaint(
                    painter: SpaceshipPainter(
                      thrusting: spaceship.thrusting,
                      thrusterFlicker: thrusterAnimation.value,
                      damaged: spaceship.damageTime > 0,
                      isBoosting: spaceship.isBoosting,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
}

class SpaceshipPainter extends CustomPainter {
  final bool thrusting;
  final double thrusterFlicker;
  final bool damaged;
  final bool isBoosting;

  SpaceshipPainter({
    required this.thrusting, required this.thrusterFlicker,
    required this.damaged, required this.isBoosting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = damaged ? Colors.redAccent.shade100 : Colors.grey.shade300
      ..style = PaintingStyle.fill;
    
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
      final thrusterPaint = Paint()
        ..color = Color.lerp(isBoosting ? Colors.cyanAccent : Colors.orangeAccent, Colors.white, thrusterFlicker)!
        ..style = PaintingStyle.fill;
      
      final flameLength = isBoosting ? -25 - thrusterFlicker * 10 : -15 - thrusterFlicker * 5;
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
    return oldDelegate.thrusting != thrusting ||
        oldDelegate.thrusterFlicker != thrusterFlicker ||
        oldDelegate.damaged != damaged ||
        oldDelegate.isBoosting != isBoosting;
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
        border: Border.all(color: gate.color, width: 3),
        borderRadius: BorderRadius.circular(10),
        color: gate.color.withOpacity(0.1),
        boxShadow: [BoxShadow(color: gate.color, blurRadius: 15, spreadRadius: 3)],
      ),
      child: Center(
        child: Text(
          gate.answer.toString(),
          style: TextStyle(
            color: gate.color, fontSize: 24, fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.white, blurRadius: 8)]
          ),
        ),
      ),
    );
  }
}

// Add this class definition with your other game objects
class Enemy extends GameObject {
  final int incorrectAnswer;
  double hoverAnimation = 0.0;

  Enemy({required Offset position, required this.incorrectAnswer})
      : super(position: position, size: 45.0);

  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
    hoverAnimation += dt * 2;
  }

  @override
  Widget build() {
    // A simple placeholder widget for the enemy. You can make this a CustomPainter or an Image.
    return Positioned(
      left: position.dx - size,
      top: position.dy - size + (math.sin(hoverAnimation) * 8), // Hover effect
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simple pirate ship body
          const Icon(Icons.rocket_launch, color: Colors.purpleAccent, size: 60),
          // Display the incorrect answer on the enemy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              incorrectAnswer.toString(),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}