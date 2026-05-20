// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/hyperdrive_gates_world.dart';
import '../../../core/services/sri_service.dart';

// --- ENHANCED GAME CONFIGURATION ---
const double BASE_GAME_SPEED = 160.0;
const int INITIAL_LIVES = 5;
const int TARGET_GATES_TO_WIN = 15;
const double GRAVITY_STRENGTH = 150.0;
const double MAX_GRAVITY_DISTANCE = 120.0;

// Enhanced color palettes
const List<List<Color>> gateColorPalettes = [
  [Color(0xfff94144), Color(0xfff3722c)], // Red-Orange
  [Color(0xfff9c74f), Color(0xff90be6d)], // Yellow-Green
  [Color(0xff43aa8b), Color(0xff4d908e)], // Teal-Cyan
  [Color(0xff577590), Color(0xff277da1)], // Blue-Navy
  [Color(0xffa726c3), Color(0xff6a0dad)], // Purple-Violet
];

const List<Color> planetColors = [
  Color(0xFFFF6B35), // Mars-like
  Color(0xFF4ECDC4), // Neptune-like
  Color(0xFFFFE66D), // Venus-like
  Color(0xFF8B5CF6), // Gas giant
  Color(0xFFFF8E9B), // Rose planet
];

// --- UTILITY CLASSES ---

class Star {
  Offset position;
  double size;
  double speed;
  double brightness;
  Star({required this.position, required this.size, required this.speed, required this.brightness});
}

class GravityField {
  final Offset center;
  final double strength;
  final double maxDistance;
  
  GravityField({required this.center, required this.strength, required this.maxDistance});
  
  Offset calculateForce(Offset objectPosition, double objectMass) {
    final distance = (center - objectPosition).distance;
    if (distance > maxDistance || distance < 10) return Offset.zero;
    
    final direction = (center - objectPosition) / distance;
    final force = (strength * objectMass) / (distance * distance);
    return direction * force;
  }
}

// --- POWER-UP SYSTEM ---
enum PowerUpType { shield, slowTime, extraLife, magneticField, speedBoost }

class PowerUp extends GameObject {
  final PowerUpType type;
  final Color color;
  double rotation = 0.0;
  double pulsePhase = 0.0;
  
  PowerUp({required super.position, required this.type})
      : color = _getColorForType(type);
  
  static Color _getColorForType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield: return Colors.blue;
      case PowerUpType.slowTime: return Colors.purple;
      case PowerUpType.extraLife: return Colors.red;
      case PowerUpType.magneticField: return Colors.orange;
      case PowerUpType.speedBoost: return Colors.green;
    }
  }
  
  IconData get icon {
    switch (type) {
      case PowerUpType.shield: return Icons.shield;
      case PowerUpType.slowTime: return Icons.schedule;
      case PowerUpType.extraLife: return Icons.favorite;
      case PowerUpType.magneticField: return Icons.radio_button_checked;
      case PowerUpType.speedBoost: return Icons.flash_on;
    }
  }
  
  @override
  Rect get collisionRect => Rect.fromCenter(center: position, width: 40, height: 40);
  
  @override
  void update(double dt, double gameSpeed) {
    position = Offset(position.dx - gameSpeed * dt, position.dy);
    rotation += dt * 2;
    pulsePhase += dt * 3;
  }
  
  @override
  Widget build() {
    final pulse = math.sin(pulsePhase) * 0.3 + 0.7;
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 20,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8 * pulse),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6 * pulse),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
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
  late AnimationController _screenShakeController;
  late AnimationController _problemGlowController;
  late AnimationController _timeSlowController;
  final FocusNode _focusNode = FocusNode();

  // --- Game State ---
  bool gameActive = false;
  bool gameInitialized = false;
  int lives = INITIAL_LIVES;
  int gatesCleared = 0;
  late int targetGatesForLevel;
  double gameSpeed = BASE_GAME_SPEED;
  Timer? _speedIncreaseTimer;
  int comboCounter = 0;
  double _temporarySpeedBoost = 0.0;

  // --- Enhanced Features ---
  List<GravityField> gravityFields = [];
  List<PowerUp> powerUps = [];
  Map<PowerUpType, double> activePowerUps = {};
  bool hasShield = false;
  bool timeSlowActive = false;
  Timer? _powerUpSpawnTimer;
  bool _choiceMadeForCurrentSet = false;

  // --- Core Gameplay State ---
  MathProblem? currentProblem;
  List<GameObject> gameObjects = [];
  List<Effect> effects = [];
  List<Offset> laneCenters = [];
  Offset screenShakeOffset = Offset.zero;

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
      
    _screenShakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
        ..addListener(() => setState(() {}));
        
    _problemGlowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
        
    _timeSlowController = AnimationController(vsync: this, duration: const Duration(seconds: 1));

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
    _screenShakeController.dispose();
    _problemGlowController.dispose();
    _timeSlowController.dispose();
    _speedIncreaseTimer?.cancel();
    _powerUpSpawnTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeGame(Size screenSize) {
    setState(() {
      lives = INITIAL_LIVES;
      gatesCleared = 0;
      comboCounter = 0;
      _temporarySpeedBoost = 0.0;
      hasShield = false;
      timeSlowActive = false;
      activePowerUps.clear();

      targetGatesForLevel = TARGET_GATES_TO_WIN + widget.level;
      gameSpeed = BASE_GAME_SPEED + (widget.grade * 15.0) + (widget.level * 5.0);
      spaceship.reset(screenSize);
      gameObjects.clear();
      effects.clear();
      gravityFields.clear();
      powerUps.clear();
      gameActive = true;
    });

    _generateBackgroundStars(screenSize);
    _spawnNextGateSet(screenSize);

    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (gameActive) {
        setState(() => gameSpeed += 12);
      }
    });

    _powerUpSpawnTimer?.cancel();
    _powerUpSpawnTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (gameActive && math.Random().nextDouble() < 0.4) {
        _spawnRandomPowerUp(screenSize);
      }
    });

    _gameController.repeat();
  }

  void _generateBackgroundStars(Size screenSize) {
    backgroundStars = List.generate(3, (_) => []);
    final random = math.Random();
    for (int layer = 0; layer < 3; layer++) {
      for (int i = 0; i < 80; i++) {
        backgroundStars[layer].add(Star(
          position: Offset(random.nextDouble() * screenSize.width, random.nextDouble() * screenSize.height),
          size: (random.nextDouble() * 1.8 + 0.5) * (layer + 1),
          speed: (random.nextDouble() * 25 + 15) * (layer + 1),
          brightness: random.nextDouble() * 0.6 + 0.4,
        ));
      }
    }
  }

  void _spawnRandomPowerUp(Size screenSize) {
    final random = math.Random();
    final powerUpType = PowerUpType.values[random.nextInt(PowerUpType.values.length)];
    
    double yPos;
    if (laneCenters.isNotEmpty) {
      yPos = laneCenters[random.nextInt(laneCenters.length)].dy;
    } else {
      yPos = random.nextDouble() * screenSize.height * 0.8 + screenSize.height * 0.1;
    }
    
    powerUps.add(PowerUp(
      position: Offset(screenSize.width + 50, yPos),
      type: powerUpType,
    ));
  }

  void _spawnNextGateSet(Size screenSize) {
    setState(() {
      _choiceMadeForCurrentSet = false;
    });
    final sriService = context.read<SriService>();
    final gameProvider = context.read<GameProvider>();
    currentProblem = MathProblem.generateProblem(gameProvider, widget.level, sriService);
    
    final random = math.Random();
    
    final mutablePalettes = List.of(gateColorPalettes);
    mutablePalettes.shuffle();
    final colors = mutablePalettes.first;

    final numPaths = random.nextInt(2) + 2; 
    final answers = currentProblem!.generateMultipleChoiceOptions(optionsCount: numPaths);
    
    laneCenters.clear();
    
    // Spawn planets with gravity fields
    if (random.nextDouble() < 0.6) {
      _spawnPlanetWithGravity(screenSize);
    }
    
    if (numPaths == 2) {
      _spawnTwoGates(screenSize, answers, colors);
    } else {
      _spawnThreeGates(screenSize, answers, colors);
    }
  }

  void _spawnPlanetWithGravity(Size screenSize) {
    final random = math.Random();
    final planetX = screenSize.width + 200 + random.nextDouble() * 300;
    final planetY = random.nextDouble() * screenSize.height * 0.6 + screenSize.height * 0.2;
    final planetPosition = Offset(planetX, planetY);
    
    // Add planet as visual object
    gameObjects.add(Planet(
      position: planetPosition,
      radius: 40 + random.nextDouble() * 30,
      color: planetColors[random.nextInt(planetColors.length)],
    ));
    
    // Add gravity field
    gravityFields.add(GravityField(
      center: planetPosition,
      strength: GRAVITY_STRENGTH * (0.8 + random.nextDouble() * 0.4),
      maxDistance: MAX_GRAVITY_DISTANCE,
    ));
  }

  void _spawnTwoGates(Size screenSize, List<int> answers, List<Color> colors) {
    final random = math.Random();
    final gateHeight = screenSize.height * 0.4;
    final verticalGap = screenSize.height * 0.2;
    final topGateY = (screenSize.height / 2) - (verticalGap / 2) - (gateHeight / 2);
    final bottomGateY = (screenSize.height / 2) + (verticalGap / 2) + (gateHeight / 2);

    laneCenters.add(Offset(spaceship.position.dx, topGateY));
    laneCenters.add(Offset(spaceship.position.dx, bottomGateY));
    
    final shuffledColors = List.of(colors)..shuffle();

    for(int i = 0; i < answers.length; i++) {
      final yPos = i == 0 ? topGateY : bottomGateY;
      gameObjects.add(Gate(
        position: Offset(screenSize.width + 150, yPos),
        answer: answers[i],
        isCorrect: answers[i] == currentProblem!.answer,
        size: Size(130, gateHeight),
        color: shuffledColors[i],
      ));
    }
    
    // Spawn space debris instead of just asteroids
    for (int i = 0; i < 6; i++) {
      final yPos = (screenSize.height / 2) + (random.nextDouble() - 0.5) * 60;
      final xOffset = 100 + random.nextDouble() * 80;
      if (random.nextBool()) {
        gameObjects.add(Asteroid(position: Offset(screenSize.width + xOffset, yPos), sizeValue: 20.0 + random.nextDouble() * 5));
      } else {
        gameObjects.add(SpaceDebris(position: Offset(screenSize.width + xOffset, yPos)));
      }
    }
  }

  void _spawnThreeGates(Size screenSize, List<int> answers, List<Color> colors) {
    final random = math.Random();
    final gateHeight = screenSize.height * 0.25;
    final topGateY = screenSize.height * 0.25;
    final middleGateY = screenSize.height * 0.5;
    final bottomGateY = screenSize.height * 0.75;

    laneCenters.add(Offset(spaceship.position.dx, topGateY));
    laneCenters.add(Offset(spaceship.position.dx, middleGateY));
    laneCenters.add(Offset(spaceship.position.dx, bottomGateY));

    final yPositions = [topGateY, middleGateY, bottomGateY];
    final shuffledColors = (gateColorPalettes.expand((p) => p).toList()..shuffle());

    for(int i = 0; i < answers.length; i++) {
      gameObjects.add(Gate(
        position: Offset(screenSize.width + 150, yPositions[i]),
        answer: answers[i],
        isCorrect: answers[i] == currentProblem!.answer,
        size: Size(130, gateHeight),
        color: shuffledColors[i],
      ));
    }

    final barrierY1 = (topGateY + middleGateY) / 2;
    final barrierY2 = (middleGateY + bottomGateY) / 2;
    for (int i = 0; i < 4; i++) {
      gameObjects.add(Asteroid(position: Offset(screenSize.width + 100 + random.nextDouble() * 80, barrierY1 + (random.nextDouble() - 0.5) * 50), sizeValue: 15.0));
      gameObjects.add(Asteroid(position: Offset(screenSize.width + 100 + random.nextDouble() * 80, barrierY2 + (random.nextDouble() - 0.5) * 50), sizeValue: 15.0));
    }
  }

  void _updateGame() {
    if (!gameActive) return;

    final dt = timeSlowActive ? 0.008 : 0.016; // Time slow effect
    final screenSize = MediaQuery.of(context).size;
    final random = math.Random();

    // Update power-ups
    _updatePowerUps(dt);

    if (_screenShakeController.isAnimating) {
      final progress = 1 - _screenShakeController.value;
      screenShakeOffset = Offset(
        (random.nextDouble() - 0.5) * 12 * progress,
        (random.nextDouble() - 0.5) * 12 * progress
      );
    } else {
      screenShakeOffset = Offset.zero;
    }
    
    if (_temporarySpeedBoost > 1.0) {
      setState(() {
        _temporarySpeedBoost *= 0.95; 
      });
    } else {
      _temporarySpeedBoost = 0.0;
    }

    final effectiveGameSpeed = gameSpeed + _temporarySpeedBoost;

    setState(() {
      // Update background stars
      for (var layer in backgroundStars) {
        for (var star in layer) {
          star.position = Offset(star.position.dx - (star.speed + effectiveGameSpeed * 0.08) * dt, star.position.dy);
          if (star.position.dx < -10) {
            star.position = Offset(screenSize.width + 10, random.nextDouble() * screenSize.height);
          }
        }
      }

      // Apply gravitational forces to spaceship
      for (final gravityField in gravityFields) {
        final force = gravityField.calculateForce(spaceship.position, 1.0);
        spaceship.applyForce(force * dt);
      }

      spaceship.update(dt, screenSize);
      if (spaceship.isMoving) _addThrusterEffects();

      // Update gravity fields (move with game objects)
      gravityFields.removeWhere((field) {
        final newCenter = Offset(field.center.dx - effectiveGameSpeed * dt, field.center.dy);
        if (newCenter.dx < -200) return true;
        final index = gravityFields.indexOf(field);
        if (index != -1) {
          gravityFields[index] = GravityField(
            center: newCenter,
            strength: field.strength,
            maxDistance: field.maxDistance,
          );
        }
        return false;
      });

      // Update power-ups
      powerUps.removeWhere((powerUp) {
        powerUp.update(dt, effectiveGameSpeed);

        if (powerUp.collisionRect.overlaps(spaceship.collisionRect)) {
          _collectPowerUp(powerUp);
          return true;
        }

        return powerUp.position.dx < -50;
      });

      bool shouldSpawnNext = false;
      gameObjects.removeWhere((obj) {
        // Apply gravity to objects
        if (obj is Asteroid || obj is SpaceDebris) {
          for (final gravityField in gravityFields) {
            final force = gravityField.calculateForce(obj.position, 0.5);
            if (obj is Asteroid) {
              (obj).applyForce(force * dt);
            } else if (obj is SpaceDebris) {
              (obj).applyForce(force * dt);
            }
          }
        }

        obj.update(dt, effectiveGameSpeed);

        if (obj.position.dx > spaceship.position.dx - 50 && obj.position.dx < spaceship.position.dx + 50) {
          if (obj is Gate) {
            if (obj.collisionRect.overlaps(spaceship.collisionRect)) {
              _handleGateCollision(obj);
              shouldSpawnNext = true;
              return true;
            }
          } else if (obj is Asteroid || obj is SpaceDebris) {
            if (obj.collisionRect.overlaps(spaceship.collisionRect)) {
              _handleObstacleCollision(obj);
              return true;
            }
          }
        }

        if (obj is Gate && obj.position.dx < spaceship.position.dx - 150) {
          shouldSpawnNext = true;
        }

        return obj.position.dx < -200;
      });
      
      if (shouldSpawnNext) {
        gameObjects.removeWhere((obj) => obj is Gate || obj is Asteroid || obj is SpaceDebris);
        gravityFields.clear(); // Clear old gravity fields
        _spawnNextGateSet(screenSize);
      }

      effects.removeWhere((e) => e.isComplete);
      for (var effect in effects) { 
        effect.update(dt);
      }
      
      if (lives <= 0) _gameOver();
      if (gatesCleared >= targetGatesForLevel) _winGame();
    });
  }

  void _updatePowerUps(double dt) {
    final toRemove = <PowerUpType>[];
    activePowerUps.forEach((type, timeLeft) {
      final newTime = timeLeft - dt;
      if (newTime <= 0) {
        toRemove.add(type);
        _deactivatePowerUp(type);
      } else {
        activePowerUps[type] = newTime;
      }
    });
    
    for (final type in toRemove) {
      activePowerUps.remove(type);
    }
  }

  void _collectPowerUp(PowerUp powerUp) {
    setState(() {
      switch (powerUp.type) {
        case PowerUpType.shield:
          hasShield = true;
          activePowerUps[PowerUpType.shield] = 8.0;
          break;
        case PowerUpType.slowTime:
          timeSlowActive = true;
          activePowerUps[PowerUpType.slowTime] = 5.0;
          _timeSlowController.forward();
          break;
        case PowerUpType.extraLife:
          lives = math.min(lives + 1, INITIAL_LIVES + 2);
          break;
        case PowerUpType.speedBoost:
          _temporarySpeedBoost += 200.0;
          break;
        case PowerUpType.magneticField:
          activePowerUps[PowerUpType.magneticField] = 10.0;
          break;
      }
    });

    effects.add(FloatingScore(
      position: powerUp.position,
      text: _getPowerUpText(powerUp.type),
      color: powerUp.color,
      fontSize: 20,
    ));

    for (int i = 0; i < 20; i++) {
      effects.add(ParticleEffect.powerUpParticle(powerUp.position, powerUp.color));
    }
  }

  String _getPowerUpText(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield: return 'SHIELD!';
      case PowerUpType.slowTime: return 'SLOW TIME!';
      case PowerUpType.extraLife: return 'EXTRA LIFE!';
      case PowerUpType.speedBoost: return 'SPEED BOOST!';
      case PowerUpType.magneticField: return 'MAGNETIC!';
    }
  }

  void _deactivatePowerUp(PowerUpType type) {
    setState(() {
      switch (type) {
        case PowerUpType.shield:
          hasShield = false;
          break;
        case PowerUpType.slowTime:
          timeSlowActive = false;
          _timeSlowController.reverse();
          break;
        default:
          break;
      }
    });
  }

  void _handleGateCollision(Gate gate) {
    
    // Record with SRI immediately for adaptive difficulty
    final sriService = context.read<SriService>();
    sriService.recordResponse(currentProblem!, gate.isCorrect);

    if (gate.isCorrect) {
      gatesCleared++;
      comboCounter++;
      
      final scoreMultiplier = comboCounter > 0 ? comboCounter : 1;
      final scoreToAdd = (10 * widget.grade) * scoreMultiplier;
      context.read<GameProvider>().addScore(scoreToAdd);
      
      effects.add(FloatingScore(position: gate.position, text: '+$scoreToAdd'));
      _addGateEntryWarpEffect();
      
      if (comboCounter > 1 && comboCounter % 4 == 0) {
        setState(() => gameSpeed += 8);
        effects.add(FloatingScore(
          position: Offset(MediaQuery.of(context).size.width / 2, 160),
          text: S.of(context)!.fast.toUpperCase(),
          color: Colors.purpleAccent,
          fontSize: 32,
        ));
      }
    } else {
      if (!hasShield) {
        lives--;
        comboCounter = 0;
        _addDamageEffect();
      } else {
        // Shield absorbs damage
        effects.add(FloatingScore(
          position: gate.position,
          text: 'SHIELDED!',
          color: Colors.blue,
          fontSize: 24,
        ));
      }
    }
  }

  void _handleObstacleCollision(GameObject obstacle) {
    if (!hasShield) {
      lives--;
      comboCounter = 0;
      _addDamageEffect();
    }
    
    for (int i = 0; i < 15; i++) {
      effects.add(ParticleEffect.explosionParticle(obstacle.position));
    }
  }
  
  void _addGateEntryWarpEffect() {
    final screenSize = MediaQuery.of(context).size;
    effects.add(WarpLinesEffect(screenSize: screenSize));
    for (int i = 0; i < 40; i++) {
      effects.add(ParticleEffect.successParticle(spaceship.position));
    }
  }

  void _addDamageEffect() {
    if (spaceship.isInvincible) return;
    spaceship.damage();
    _screenShakeController.forward(from: 0.0);
    for (int i = 0; i < 25; i++) {
      effects.add(ParticleEffect.explosionParticle(spaceship.position));
    }
  }
  
  void _addThrusterEffects() {
    effects.add(ParticleEffect.thrusterParticle(spaceship.position));
  }

  void _triggerDecisionBoost(Gate targetGate) {
    final screenSize = MediaQuery.of(context).size;
    double bonusMultiplier = ((targetGate.position.dx - spaceship.position.dx) / (screenSize.width - spaceship.position.dx)).clamp(0.0, 1.0);
    
    if (bonusMultiplier < 0.1) return;

    final int bonusPoints = (40 * bonusMultiplier).toInt() + 10;
    context.read<GameProvider>().addScore(bonusPoints);
    
    setState(() {
      _temporarySpeedBoost = 700.0 * bonusMultiplier;
    });

    effects.add(FloatingScore(
      position: Offset(targetGate.position.dx, targetGate.position.dy - 50),
      text: '+$bonusPoints BOOST!',
      color: Colors.amber,
      fontSize: 28,
    ));
  }

  void _handleGateChoice(double targetY) {
    if (_choiceMadeForCurrentSet) return;
    
    final gates = gameObjects.whereType<Gate>();
    if (gates.isEmpty) return;
    
    Gate targetGate = gates.reduce((a, b) => (a.position.dy - targetY).abs() < (b.position.dy - targetY).abs() ? a : b);

    if (targetGate.isCorrect) {
      _triggerDecisionBoost(targetGate);
    }
    
    setState(() {
      _choiceMadeForCurrentSet = true;
    });
  }

  void _handleKeyboard(KeyEvent event) {
    if (event is KeyDownEvent && laneCenters.isNotEmpty) {
      int currentLane = -1;
      double minDistance = double.infinity;
      for (int i = 0; i < laneCenters.length; i++) {
        final dist = (spaceship.targetY - laneCenters[i].dy).abs();
        if (dist < minDistance) {
          minDistance = dist;
          currentLane = i;
        }
      }
      
      double? targetY;
      if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (currentLane > 0) targetY = laneCenters[currentLane - 1].dy;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (currentLane < laneCenters.length - 1) targetY = laneCenters[currentLane + 1].dy;
      } else if (event.logicalKey == LogicalKeyboardKey.space && laneCenters.length == 3) {
        targetY = laneCenters[1].dy;
      }

      if (targetY != null) {
        _handleGateChoice(targetY);
        spaceship.moveTo(targetY);
      }
    }
  }

  void _handleScreenInteraction(Offset localPosition) {
    if (!gameActive || laneCenters.isEmpty) return;

    double closestY = laneCenters.first.dy;
    double minDistance = (localPosition.dy - closestY).abs();

    for (final lane in laneCenters) {
      final dist = (localPosition.dy - lane.dy).abs();
      if (dist < minDistance) {
        minDistance = dist;
        closestY = lane.dy;
      }
    }
    _handleGateChoice(closestY);
    spaceship.moveTo(closestY);
  }
  
  void _handleDrag(Offset localPosition) {
    if (!gameActive) return;
    _handleGateChoice(localPosition.dy);
    spaceship.moveTo(localPosition.dy);
  }
  
  void _winGame() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameController.stop();
    
    // DON'T pass mathProblems - already recorded during gameplay
    // Score already added incrementally; mathProblems already recorded.
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'hyperdrive_gates',
      difficulty: widget.level,
      score: 0,
    ));
    
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (ctx) => _buildEndGameDialog(isWin: true)
    );
  }

  void _gameOver() {
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameController.stop();
    
    // DON'T pass mathProblems - already recorded during gameplay
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'hyperdrive_gates',
      difficulty: widget.level,
    ));
    
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (ctx) => _buildEndGameDialog(isWin: false)
    );
  }
  
  void _resetGame() {
    Navigator.of(context).pop();
    final screenSize = MediaQuery.of(context).size;
    _initializeGame(screenSize);
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
        child: Semantics(
          label: 'Hyperdrive game area',
          hint: 'Tap or drag to steer your ship through gates',
          child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _handleScreenInteraction(details.localPosition),
          onVerticalDragStart: (details) => _handleDrag(details.localPosition),
          onVerticalDragUpdate: (details) => _handleDrag(details.localPosition),
          child: Transform.translate(
            offset: screenShakeOffset,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: timeSlowActive 
                    ? [const Color(0xFF2A1A3A), const Color(0xFF1A0A2A)]
                    : [const Color(0xFF0A0A2A), const Color(0xFF000510)],
                )
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ..._buildBackground(),
                  ..._buildGravityFieldVisuals(),
                  ...gameObjects.map((obj) => obj.build()),
                  ...powerUps.map((powerUp) => powerUp.build()),
                  ...effects.map((e) => e.build()),
                  Positioned(
                    left: spaceship.position.dx - spaceship.sizeValue,
                    top: spaceship.position.dy - spaceship.sizeValue,
                    child: SpaceshipWidget(
                      spaceship: spaceship, 
                      thrusterAnimation: _thrusterController,
                      hasShield: hasShield,
                    ),
                  ),
                  _buildGameHeader(),
                  _buildProblemDisplay(),
                  if (comboCounter > 1) _buildComboDisplay(),
                  _buildActivePowerUpsDisplay(),
                ],
              ),
            ),
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
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: star.brightness), 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: star.brightness * 0.5), blurRadius: star.size * 2)
          ]
        ),
      ),
    ))).toList();
  }

  List<Widget> _buildGravityFieldVisuals() {
    return gravityFields.map((field) => Positioned(
      left: field.center.dx - field.maxDistance,
      top: field.center.dy - field.maxDistance,
      child: Container(
        width: field.maxDistance * 2,
        height: field.maxDistance * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.3),
            width: 2,
          ),
          gradient: RadialGradient(
            colors: [
              Colors.purple.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    )).toList();
  }
  
  Widget _buildGameHeader() {
    final l10n = S.of(context)!;
    final titleText = '${l10n.hyperdriveGatesTitle}: $gatesCleared / $targetGatesForLevel';
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black.withValues(alpha: 0.5),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() => gameActive = false);
                  Navigator.of(context).pop();
                },
              ),
              Expanded(
                child: Text(
                  titleText, 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                children: List.generate(INITIAL_LIVES, (index) => Icon(
                  index < lives ? Icons.favorite : Icons.favorite_border,
                  color: Colors.redAccent.shade100, size: 30,
                  shadows: [Shadow(color: Colors.redAccent.shade100, blurRadius: index < lives ? 6 : 0)],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePowerUpsDisplay() {
    if (activePowerUps.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      top: 100,
      right: 20,
      child: Column(
        children: activePowerUps.entries.map((entry) {
          final powerUp = PowerUp(position: Offset.zero, type: entry.key);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: powerUp.color, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(powerUp.icon, color: powerUp.color, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.toInt()}s',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildProblemDisplay() {
    if (currentProblem == null) return const SizedBox.shrink();
    final l10n = S.of(context)!;
    return AnimatedBuilder(
      animation: _problemGlowController,
      builder: (context, child) {
        final glow = _problemGlowController.value * 0.5 + 0.5;
        return Positioned(
          top: 80, left: 20, right: 20,
          child: Center(
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow.withValues(alpha: glow), width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.yellow.withValues(alpha: glow * 0.6), blurRadius: 18, spreadRadius: 3),
                  ]
                ),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    children: [
                      TextSpan(text: '${l10n.solve} ', style: TextStyle(color: Colors.yellow.shade300)),
                      TextSpan(
                        text: currentProblem!.expression
                            .replaceAll('÷', context.read<GameProvider>().divisionSymbol)
                            .replaceAll('×', context.read<GameProvider>().multiplicationSymbol),
                        style: const TextStyle(color: Colors.white)
                      ),
                    ]
                  ),
                )
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildComboDisplay() {
    const comboText = 'COMBO';

    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          '$comboText x$comboCounter',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: Colors.orangeAccent,
            shadows: [
              Shadow(blurRadius: 20, color: Colors.orangeAccent.withValues(alpha: 0.9)),
              const Shadow(blurRadius: 8, color: Colors.white, offset: Offset(0,0)),
            ]
          ),
        ),
      ),
    );
  }

  Widget _buildEndGameDialog({required bool isWin}) {
    final l10n = S.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0), side: BorderSide(color: isWin ? Colors.cyanAccent : Colors.redAccent, width: 3)),
      title: Text(isWin ? l10n.hyperdriveGatesWinTitle : l10n.hyperdriveGatesLoseTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text(
        isWin ? l10n.hyperdriveGatesWinDesc(targetGatesForLevel) : l10n.hyperdriveGatesLoseDesc,
        style: const TextStyle(color: Colors.white70, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      actions: <Widget>[
        TextButton(onPressed: _resetGame, child: Text(l10n.flyAgain, style: const TextStyle(color: Colors.white, fontSize: 16))),
        TextButton(
          child: Text(l10n.backToMenu, style: const TextStyle(color: Colors.white, fontSize: 16)),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
