import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;

import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../../../core/services/sri_service.dart'; 

// A few top-level constants for easier tweaking
const int kNumStars = 150;
const int kNumDust = 70;
const double kShipSize = 50.0;
const double kPathWidth = 70.0;

class PathFinderGame extends StatefulWidget {
  final int grade;
  final int level;

  const PathFinderGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<PathFinderGame> createState() => _PathFinderGameState();
}

class _PathFinderGameState extends State<PathFinderGame> with TickerProviderStateMixin {
  // Core Animation Controllers
  late AnimationController _gameController;
  late AnimationController _backgroundController;
  late AnimationController _screenShakeController;
  late AnimationController _shipController;
  late AnimationController _feedbackController;

  // Game State
  bool gameActive = true;
  double lives = 3.0;
  int problemsSolved = 0;
  late int targetProblems;
  double gameSpeed = 150.0;
  int totalScore = 0;

  // Current Problem State
  MathProblem? currentProblem;
  List<SpacePath> availablePaths = [];
  bool choosingPath = true;

  // Problems attempted this session, reported once on game end.
  final List<MathProblem> _attemptedProblems = [];

  // Visual Effects
  List<SpaceParticle> particles = [];
  List<BackgroundStar> stars = [];
  List<BackgroundStar> dust = [];
  Offset screenShakeOffset = Offset.zero;
  String statusMessage = "";
  Timer? _statusTimer;
  Color feedbackColor = Colors.transparent;

  // Ship State
  Spaceship ship = Spaceship();
  SpacePath? selectedPath;
  double pathFollowProgress = 0.0;
  bool followingPath = false;
  late CurvedAnimation _shipCurveAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _initializeGameValues();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ship.position == Offset.zero) {
      _initializeGamePositions();
      _startNewChallenge();
    }
  }

  void _setupAnimationControllers() {
    _gameController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_updateGame)
      ..repeat();

    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 45))
      ..repeat();

    _screenShakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(_updateScreenShake);
    
    _feedbackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..addListener(() => setState(() {}));

    _shipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _shipCurveAnimation = CurvedAnimation(parent: _shipController, curve: Curves.easeInOut);
    _shipCurveAnimation.addListener(_updateShipOnPath);
  }

  void _initializeGameValues() {
    targetProblems = 6 + widget.grade;
    gameSpeed = 120.0 + (widget.grade * 15.0);
    totalScore = 0;
  }

  void _initializeGamePositions() {
    final size = MediaQuery.of(context).size;
    ship.position = Offset(80, size.height / 2);
    _generateStarField(size);
  }

  void _generateStarField(Size size) {
    final random = math.Random();
    stars.clear();
    dust.clear();
    for (int i = 0; i < kNumStars; i++) {
      stars.add(BackgroundStar.create(size, random, speedMultiplier: 0.5));
    }
    for (int i = 0; i < kNumDust; i++) {
      dust.add(BackgroundStar.create(size, random, speedMultiplier: 1.5, isDust: true));
    }
  }
  
  void _startNewChallenge() {
    if (!mounted || !gameActive) return;

    final sriService = context.read<SriService>();
    final gameProvider = context.read<GameProvider>();

    setState(() {
      currentProblem = MathProblem.generateProblem(gameProvider, widget.level, sriService);
      availablePaths.clear();
      pathFollowProgress = 0.0;
      selectedPath = null;
      followingPath = false;
      ship.position = Offset(80, MediaQuery.of(context).size.height / 2);
      ship.angle = 0.0;
    });

    _generateSpacePaths();
  }

  void _generateSpacePaths() {
    final screenSize = MediaQuery.of(context).size;
    final numPaths = math.min(5, 2 + (widget.grade ~/ 2));
    final random = math.Random();
    
    final pathAnswers = {currentProblem!.answer};
    while (pathAnswers.length < numPaths) {
      int wrongAnswer;
      do {
        wrongAnswer = currentProblem!.answer + (random.nextBool() ? 1 : -1) * (random.nextInt(10) + 1);
      } while (wrongAnswer <= 0 || pathAnswers.contains(wrongAnswer));
      pathAnswers.add(wrongAnswer);
    }
    final shuffledAnswers = pathAnswers.toList()..shuffle();

    final newPaths = <SpacePath>[];
    for (int i = 0; i < numPaths; i++) {
      final pathY = (screenSize.height / (numPaths + 1)) * (i + 1);
      final start = Offset(screenSize.width * 0.25, pathY);
      final end = Offset(screenSize.width + 150, pathY);

      newPaths.add(SpacePath(
        startPoint: start,
        endPoint: end,
        controlPoint: Offset(
          (start.dx + end.dx) / 2 + (random.nextDouble() - 0.5) * 200,
          pathY + (random.nextDouble() - 0.5) * 150,
        ),
        answer: shuffledAnswers[i],
        isCorrect: shuffledAnswers[i] == currentProblem!.answer,
        pathType: _selectRandomPathType(),
        width: kPathWidth,
      ));
    }

    setState(() {
      availablePaths = newPaths;
      choosingPath = true;
    });
    
    debugPrint("[TAP DEBUG] Generated ${newPaths.length} paths, choosingPath: $choosingPath");
  }

  SpacePathType _selectRandomPathType() {
    return SpacePathType.values[math.Random().nextInt(SpacePathType.values.length)];
  }

  void _showStatus(String message, {Duration duration = const Duration(seconds: 1)}) {
    setState(() => statusMessage = message);
    _statusTimer?.cancel();
    _statusTimer = Timer(duration, () {
      if (mounted) setState(() => statusMessage = "");
    });
  }

  // NEW: Enhanced tap detection with screen-wide gesture detection
  void _handleScreenTap(Offset tapPosition) {
    debugPrint("[TAP DEBUG] Screen tapped at: $tapPosition");
    debugPrint("[TAP DEBUG] choosingPath: $choosingPath, followingPath: $followingPath");
    debugPrint("[TAP DEBUG] availablePaths.length: ${availablePaths.length}");

    if (!choosingPath || followingPath || availablePaths.isEmpty) {
      debugPrint("[TAP DEBUG] -> Tap IGNORED due to game state");
      return;
    }

    // Check which path (if any) was tapped
    SpacePath? tappedPath;
    double closestDistance = double.infinity;

    for (final path in availablePaths) {
      final bubblePosition = path.getPointAt(0.5);
      final distance = (tapPosition - bubblePosition).distance;
      
      debugPrint("[TAP DEBUG] Path ${path.answer}: bubble at $bubblePosition, distance: ${distance.toStringAsFixed(1)}");
      
      // Increased tap radius for better responsiveness
      if (distance < 70.0 && distance < closestDistance) {
        closestDistance = distance;
        tappedPath = path;
      }
    }

    if (tappedPath != null) {
      debugPrint("[TAP DEBUG] -> Tap ACCEPTED on path with answer: ${tappedPath.answer}");
      _selectPath(tappedPath);
    } else {
      debugPrint("[TAP DEBUG] -> Tap MISSED (closest: ${closestDistance.toStringAsFixed(1)})");
    }
  }

  void _selectPath(SpacePath path) {
    debugPrint("State check: choosingPath is '$choosingPath', followingPath is '$followingPath'.");

    if (!choosingPath || followingPath) {
      debugPrint("-> Path selection IGNORED due to game state.");
      return;
    }
    debugPrint("-> Path selection ACCEPTED. Processing...");

    _attemptedProblems.add(currentProblem!);

    HapticFeedback.lightImpact();

    setState(() {
      selectedPath = path;
      choosingPath = false;
    });
    
    _animateShipToPathStart(path);
  }
  
  void _animateShipToPathStart(SpacePath path) {
    final startPos = ship.position;
    final endPos = path.getPointAt(0);
    
    final moveController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    final moveAnimation = Tween<Offset>(begin: startPos, end: endPos).animate(
      CurvedAnimation(parent: moveController, curve: Curves.easeOut)
    );

    moveAnimation.addListener(() {
      setState(() {
        ship.position = moveAnimation.value;
        ship.angle = (endPos - startPos).direction;
      });
    });

    moveController.forward().whenComplete(() {
      moveController.dispose();
      if (!mounted) return;
      
      setState(() {
        followingPath = true;
      });
      _animateShipAlongPath(path);
    });
  }
  
  void _updateShipOnPath() {
      if (followingPath && selectedPath != null) {
        setState(() {
          pathFollowProgress = _shipCurveAnimation.value;
          final currentPos = selectedPath!.getPointAt(pathFollowProgress);
          final nextProgress = math.min(1.0, pathFollowProgress + 0.01);
          final nextPos = selectedPath!.getPointAt(nextProgress);
          
          ship.position = currentPos;
          if ((nextPos - currentPos).distance > 0.1) {
            ship.angle = (nextPos - currentPos).direction;
          }
        });
      }
  }

  void _animateShipAlongPath(SpacePath path) {
    _shipController.forward(from: 0.0).whenComplete(() {
      if (!mounted) return;
      if (path.isCorrect) {
        _handleCorrectPath();
      } else {
        _handleWrongPath(path);
      }
    });
  }
  
  void _triggerFeedback(bool isSuccess) {
    feedbackColor = isSuccess ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.6);
    _feedbackController.forward(from: 0.0).then((_) {
      if (mounted) _feedbackController.reverse();
    });
  }

  void _handleCorrectPath() {
    problemsSolved++;
    final scoreGained = (100 * widget.grade) + (lives.floor() * 50);
    totalScore += scoreGained;
    
    try {
      context.read<GameProvider>().addScore(scoreGained);
    } catch (e) {
      debugPrint('GameProvider not available: $e');
    }
    
    _addSuccessEffect();
    _triggerFeedback(true);
    HapticFeedback.mediumImpact();
    
    _showStatus("${S.of(context)!.correct} +$scoreGained");
    
    final delay = Duration(milliseconds: problemsSolved >= targetProblems ? 1000 : 400);
    Future.delayed(delay, () {
      if (problemsSolved >= targetProblems) {
        _winGame();
      } else {
        _startNewChallenge();
      }
    });
  }

  void _handleWrongPath(SpacePath path) {
    lives -= path.pathType.damage;

    _addDamageEffect();
    _triggerFeedback(false);
    _screenShakeController.forward(from: 0.0);
    HapticFeedback.vibrate();
    
    final failureMessage = _getLocalizedFailureMessage(path.pathType);
    _showStatus("$failureMessage (-${path.pathType.damage.toStringAsFixed(2)} HP)");
    
    final delay = Duration(milliseconds: lives <= 0 ? 1000 : 400);
    Future.delayed(delay, () {
      if (lives <= 0) {
        _gameOver();
      } else {
        _startNewChallenge();
      }
    });
  }

  String _getLocalizedFailureMessage(SpacePathType pathType) {
    final l10n = S.of(context)!;
    switch (pathType) {
      case SpacePathType.wormhole: return l10n.pathFinderFailureWormhole;
      case SpacePathType.nebula: return l10n.pathFinderFailureNebula;
      case SpacePathType.asteroidBelt: return l10n.pathFinderFailureAsteroidBelt;
      case SpacePathType.clearSpace: return l10n.pathFinderFailureClearSpace;
      case SpacePathType.ionStorm: return l10n.pathFinderFailureIonStorm;
      case SpacePathType.quantumTunnel: return l10n.pathFinderFailureQuantumTunnel;
    }
  }

  void _updateGame() {
    if (!mounted) return;
    
    const dt = 0.016;
    final screenSize = MediaQuery.of(context).size;
    
    for (var star in stars) {
      star.update(dt, screenSize, gameSpeed * 0.1);
    }
    for (var dustParticle in dust) {
      dustParticle.update(dt, screenSize, gameSpeed * 0.3);
    }

    particles.removeWhere((p) => p.update(dt));
    if (followingPath) {
      for (int i = 0; i < 3; i++) {
        particles.add(SpaceParticle.engine(ship.position, ship.angle));
      }
    }
  }
  
  void _updateScreenShake() {
      final progress = _screenShakeController.value;
      final intensity = 15 * math.sin(progress * math.pi);
      setState(() {
        screenShakeOffset = Offset(
          (math.Random().nextDouble() - 0.5) * intensity,
          (math.Random().nextDouble() - 0.5) * intensity
        );
      });
  }

  void _addSuccessEffect() {
    for (int i = 0; i < 40; i++) {
      particles.add(SpaceParticle.success(ship.position));
    }
  }

  void _addDamageEffect() {
    for (int i = 0; i < 50; i++) {
      particles.add(SpaceParticle.damage(ship.position));
    }
  }

  void _winGame() {
    if (!mounted) return;
    gameActive = false;
    final completionBonus = 500 + (lives.toInt() * 100);
    totalScore += completionBonus;
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'pathfinder',
      difficulty: widget.level,
      score: completionBonus,
      mathProblems: _attemptedProblems,
    ));

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndDialog(true));
  }

  void _gameOver() {
    if (!mounted) return;
    gameActive = false;
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'pathfinder',
      difficulty: widget.level,
      mathProblems: _attemptedProblems,
    ));
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => _buildEndDialog(false));
  }
  
  void _resetGame() {
    if (!mounted) return;
    Navigator.pop(context);
    
    setState(() {
      gameActive = true;
      lives = 3.0;
      problemsSolved = 0;
      totalScore = 0;
    });
    _startNewChallenge();
  }

  @override
  Widget build(BuildContext context) {
    // If paths aren't generated yet, show a loading screen.
    // Prevents race condition.
    if (availablePaths.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyan),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // MAIN GAME AREA WITH SCREEN-WIDE TAP DETECTION
            GestureDetector(
              onTapDown: (details) {
                _handleScreenTap(details.localPosition);
              },
              behavior: HitTestBehavior.translucent,
              child: Transform.translate(
                offset: screenShakeOffset,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ..._buildBackground(),
                    ..._buildVisualPaths(),
                    ..._buildParticles(),
                    _buildShip(),
                    // Add visual debug indicators for tap areas in debug mode
                    if (choosingPath) ..._buildDebugTapAreas(),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: Container(
                color: feedbackColor.withValues(alpha: feedbackColor.a * _feedbackController.value),
              ),
            ),
            // UI elements that should not interfere with taps
            _buildUI(),
          ],
        ),
      ),
    );
  }

  // OPTIONAL: Visual debug indicators (remove in production)
  List<Widget> _buildDebugTapAreas() {
    // Uncomment the return below to see tap areas visually
    return [];
    
    /* 
    return availablePaths.map((path) {
      final bubblePosition = path.getPointAt(0.5);
      const tapRadius = 70.0;
      return Positioned(
        left: bubblePosition.dx - tapRadius,
        top: bubblePosition.dy - tapRadius,
        width: tapRadius * 2,
        height: tapRadius * 2,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.yellow, width: 1),
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
    */
  }

  List<Widget> _buildBackground() {
    return [
      ...stars.map((s) => s.build()), 
      ...dust.map((d) => d.build())
    ];
  }

  List<Widget> _buildVisualPaths() {
    return availablePaths.map((path) => Positioned.fill(
      child: CustomPaint(
        painter: SpacePathPainter(
          path: path,
          progress: _backgroundController.value,
        ),
      ),
    )).toList();
  }
  
  List<Widget> _buildParticles() => particles.map((p) => p.build()).toList();

  Widget _buildShip() {
    return Positioned(
      left: ship.position.dx - kShipSize / 2,
      top: ship.position.dy - kShipSize / 2,
      child: Transform.rotate(
        angle: ship.angle,
        child: SizedBox(
          width: kShipSize,
          height: kShipSize,
          child: CustomPaint(
            painter: SpaceshipPainter(boosting: followingPath, damageLevel: 3.0 - lives),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUI() {
    return Column(
      children: [
        _buildHeader(),
        _buildMainDisplay(),
        const Spacer(),
        _buildInstructions(),
      ],
    );
  }
  
  Widget _buildMainDisplay() {
    if (choosingPath) {
      return _buildProblemDisplay();
    } else if (followingPath && statusMessage.isNotEmpty) {
      return _buildStatusMessage();
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text('$problemsSolved/$targetProblems', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: List.generate(3, (index) => Icon(
              index < lives.ceil() ? Icons.favorite : Icons.favorite_border,
              color: index < lives ? Colors.redAccent : Colors.grey,
              size: 24,
            )),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.yellow, size: 20),
              const SizedBox(width: 8),
              Text('$totalScore', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemDisplay() {
    return Container(
      key: const ValueKey('problem'),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan, width: 2),
        boxShadow: [BoxShadow(color: Colors.cyan.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Text(
          currentProblem!.expression
              .replaceAll('÷', context.read<GameProvider>().divisionSymbol)
              .replaceAll('×', context.read<GameProvider>().multiplicationSymbol),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFeatures: [ui.FontFeature.tabularFigures()])),
    );
  }
  
  Widget _buildStatusMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(statusMessage,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(S.of(context)!.pathFinderInstructions,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
      ),
    );
  }
  
  Widget _buildEndDialog(bool isWin) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: isWin ? Colors.greenAccent : Colors.redAccent, width: 2),
      ),
      title: Row(children: [
        Icon(isWin ? Icons.rocket_launch : Icons.error, color: isWin ? Colors.green : Colors.red, size: 30),
        const SizedBox(width: 10),
        Text(isWin ? S.of(context)!.pathFinderWinTitle : S.of(context)!.pathFinderLoseTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      content: Text(
        isWin ? S.of(context)!.pathFinderWinDesc(targetProblems, totalScore) : S.of(context)!.pathFinderLoseDesc,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(onPressed: _resetGame, child: Text(S.of(context)!.playAgain, style: const TextStyle(color: Colors.cyanAccent))),
        TextButton(child: Text(S.of(context)!.backToMenu, style: const TextStyle(color: Colors.white)), onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
        }),
      ],
    );
  }

  @override
  void dispose() {
    _gameController.dispose();
    _backgroundController.dispose();
    _screenShakeController.dispose();
    _shipController.dispose();
    _feedbackController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }
}


// --- ENUMS, DATA MODELS, and CUSTOM PAINTERS (Unchanged) ---

enum SpacePathType { wormhole, nebula, asteroidBelt, clearSpace, ionStorm, quantumTunnel }

extension SpacePathTypeData on SpacePathType {
  double get damage {
    switch (this) {
      case SpacePathType.asteroidBelt: return 1.0;
      case SpacePathType.quantumTunnel: return 1.0;
      case SpacePathType.ionStorm: return 0.75;
      case SpacePathType.wormhole: return 0.5;
      case SpacePathType.nebula: return 0.5;
      case SpacePathType.clearSpace: return 0.25;
    }
  }

  List<Color> get colors {
    switch (this) {
      case SpacePathType.wormhole: return [Colors.purple, Colors.deepPurple, Colors.indigo];
      case SpacePathType.nebula: return [Colors.pink, Colors.pinkAccent, Colors.red.shade200];
      case SpacePathType.asteroidBelt: return [Colors.brown, Colors.orange, Colors.grey.shade700];
      case SpacePathType.clearSpace: return [Colors.blue, Colors.lightBlue, Colors.cyan];
      case SpacePathType.ionStorm: return [Colors.orange, Colors.yellow, Colors.red];
      case SpacePathType.quantumTunnel: return [Colors.cyan, Colors.teal, Colors.lightGreenAccent];
    }
  }
}

class SpacePath {
  final Offset startPoint;
  final Offset endPoint;
  final Offset controlPoint;
  final int answer;
  final bool isCorrect;
  final SpacePathType pathType;
  final double width;

  SpacePath({
    required this.startPoint,
    required this.endPoint,
    required this.controlPoint,
    required this.answer,
    required this.isCorrect,
    required this.pathType,
    required this.width,
  });

  Offset getPointAt(double t) {
    final t2 = t * t;
    final mt = 1 - t;
    final mt2 = mt * mt;
    
    final x = mt2 * startPoint.dx + 2 * mt * t * controlPoint.dx + t2 * endPoint.dx;
    final y = mt2 * startPoint.dy + 2 * mt * t * controlPoint.dy + t2 * endPoint.dy;

    return Offset(x, y);
  }
}

class Spaceship {
  Offset position = Offset.zero;
  double angle = 0.0;
}

class BackgroundStar {
  Offset position;
  double size;
  double speed;
  double brightness;
  bool isDust;

  BackgroundStar({
    required this.position,
    required this.size,
    required this.speed,
    required this.brightness,
    this.isDust = false,
  });

  factory BackgroundStar.create(Size screenSize, math.Random random, {double speedMultiplier = 1.0, bool isDust = false}) {
    return BackgroundStar(
      position: Offset(random.nextDouble() * screenSize.width, random.nextDouble() * screenSize.height),
      size: isDust ? random.nextDouble() * 1.2 + 0.5 : random.nextDouble() * 2.5 + 1.0,
      speed: (random.nextDouble() * 60 + 30) * speedMultiplier,
      brightness: random.nextDouble() * 0.7 + 0.3,
      isDust: isDust,
    );
  }
  
  void update(double dt, Size screenSize, double gameSpeed) {
    position = Offset(position.dx - (speed + gameSpeed) * dt, position.dy);
    if (position.dx < -10) {
      position = Offset(screenSize.width + 10, math.Random().nextDouble() * screenSize.height);
    }
  }
  
  Widget build() {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: brightness),
          shape: BoxShape.circle,
          boxShadow: isDust ? null : [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: size * 2)],
        ),
      ),
    );
  }
}

class SpaceParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  SpaceParticle({
    required this.position, required this.velocity, required this.color,
    required this.size, required this.opacity, required this.life,
  }) : maxLife = life;

  factory SpaceParticle.engine(Offset shipPos, double angle) {
    final random = math.Random();
    final speed = -250 - random.nextDouble() * 100;
    final perpendicularVel = (random.nextDouble() - 0.5) * 60;
    return SpaceParticle(
      position: shipPos + Offset.fromDirection(angle, -kShipSize / 2.5),
      velocity: Offset.fromDirection(angle, speed) + Offset.fromDirection(angle + math.pi/2, perpendicularVel),
      color: Colors.orangeAccent,
      size: 1.5 + random.nextDouble() * 2.5,
      opacity: 0.9,
      life: 0.3 + random.nextDouble() * 0.3,
    );
  }

  factory SpaceParticle.success(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = random.nextDouble() * 200;
    return SpaceParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.cyan, Colors.lightGreenAccent, Colors.white][random.nextInt(3)],
      size: 2 + random.nextDouble() * 3,
      opacity: 1.0,
      life: 0.7 + random.nextDouble() * 0.5,
    );
  }

  factory SpaceParticle.damage(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 50 + random.nextDouble() * 250;
    return SpaceParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 2 + random.nextDouble() * 3,
      opacity: 1.0,
      life: 0.6 + random.nextDouble() * 0.4,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.97;
    return life <= 0;
  }
  
  Widget build() {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class SpacePathPainter extends CustomPainter {
  final SpacePath path;
  final double progress;

  SpacePathPainter({required this.path, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(path.startPoint.dx, path.startPoint.dy)
      ..quadraticBezierTo(path.controlPoint.dx, path.controlPoint.dy, path.endPoint.dx, path.endPoint.dy);
      
    final colors = path.pathType.colors;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = path.width
      ..shader = ui.Gradient.linear(path.startPoint, path.endPoint, colors, [0.0, 0.5, 1.0]);
    canvas.drawPath(p, paint);

    _drawPathEffects(canvas, p, path.pathType);

    final midPoint = path.getPointAt(0.5);
    const bubbleRadius = 38.0;
    canvas.drawCircle(midPoint, bubbleRadius, Paint()..color = Colors.black.withValues(alpha: 0.8));
    canvas.drawCircle(midPoint, bubbleRadius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = colors[1]);

    final textPainter = TextPainter(
      text: TextSpan(
        text: path.answer.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, midPoint - Offset(textPainter.width / 2, textPainter.height / 2));
  }
  
  void _drawPathEffects(Canvas canvas, Path p, SpacePathType type) {
    final random = math.Random(path.answer);
    final metrics = p.computeMetrics().first;
    
    switch(type) {
      case SpacePathType.asteroidBelt:
        for (var i = 0; i < 15; i++) {
          final distance = metrics.length * (i * 0.06 + (progress * 0.1)) % metrics.length;
          final tangent = metrics.getTangentForOffset(distance)!;
          final offset = tangent.position + Offset.fromDirection(tangent.angle + math.pi/2, (random.nextDouble()-0.5) * kPathWidth * 1.5);
          final size = random.nextDouble() * 12 + 8;
          canvas.drawCircle(offset, size, Paint()..color = Colors.brown.shade800);
        }
        break;
      case SpacePathType.ionStorm:
         for (var i = 0; i < 5; i++) {
          final distance = metrics.length * random.nextDouble();
          final tangent = metrics.getTangentForOffset(distance)!;
          final p1 = tangent.position;
          final p2 = p1 + Offset.fromDirection(tangent.angle + (random.nextDouble()-0.5) * 2, 40);
          canvas.drawLine(p1, p2, Paint()..color=Colors.yellow.withValues(alpha: 0.8)..strokeWidth=2);
         }
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(SpacePathPainter oldDelegate) => oldDelegate.progress != progress;
}

class SpaceshipPainter extends CustomPainter {
  final bool boosting;
  final double damageLevel;

  SpaceshipPainter({required this.boosting, required this.damageLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    final bodyColor = Color.lerp(Colors.grey.shade300, Colors.red.shade700, damageLevel/3.0)!;
    
    paint.color = bodyColor;
    final shipPath = Path()
      ..moveTo(size.width * 0.95, size.height * 0.5)
      ..cubicTo(size.width * 0.5, size.height * 0.2, size.width * 0.2, size.height * 0.1, 0, size.height * 0.35)
      ..lineTo(0, size.height * 0.65)
      ..cubicTo(size.width * 0.2, size.height * 0.9, size.width * 0.5, size.height * 0.8, size.width * 0.95, size.height * 0.5)
      ..close();
    canvas.drawPath(shipPath, paint);
    
    paint.color = Colors.cyan.shade200;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.65, size.height * 0.5), width: size.width * 0.4, height: size.height * 0.5),
      paint,
    );
    
    if (damageLevel > 1.0) {
      final crackPaint = Paint()..color = Colors.black.withValues(alpha: 0.5)..strokeWidth = 1.2..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(size.width * 0.5, size.height * 0.35), Offset(size.width * 0.8, size.height * 0.6), crackPaint);
    }

    if (boosting) {
      final thrusterPaint = Paint()..shader = ui.Gradient.radial(
        Offset(-size.width * 0.4, size.height * 0.5), 
        size.width * 0.6, 
        [Colors.cyanAccent, Colors.transparent]
      );
      final thrusterPath = Path()
        ..moveTo(0, size.height * 0.3)
        ..lineTo(-size.width * (0.5 + math.Random().nextDouble() * 0.2), size.height * 0.5)
        ..lineTo(0, size.height * 0.7)
        ..close();
      canvas.drawPath(thrusterPath, thrusterPaint);
    }
  }

  @override
  bool shouldRepaint(SpaceshipPainter oldDelegate) {
    return oldDelegate.boosting != boosting || oldDelegate.damageLevel != damageLevel;
  }
}