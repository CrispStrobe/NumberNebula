import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../../../core/services/sri_service.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class CryptexLockBreakerGame extends StatefulWidget {
  final int grade;
  final int level;

  const CryptexLockBreakerGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<CryptexLockBreakerGame> createState() => _CryptexLockBreakerGameState();
}

class _CryptexLockBreakerGameState extends State<CryptexLockBreakerGame>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late AnimationController _unlockController;
  late AnimationController _particleController;
  late AnimationController _dialController;
  late AnimationController _equationController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _unlockAnimation;
  late Animation<double> _dialAnimation;
  late Animation<double> _equationAnimation;

  // Game State
  late CryptexPuzzle currentPuzzle;
  late List<int> dialValues;
  bool gameActive = true;
  bool isUnlocked = false;
  int selectedDial = -1;
  
  // Visual Effects
  List<CryptexParticle> particles = [];
  double unlockProgress = 0.0;
  
  // Interaction
  bool isDragging = false;
  double dragStartY = 0.0;
  int dragStartValue = 0;

  @override
  void initState() {
    super.initState();
    debugPrint("🔐 [CryptexLockBreaker] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _generatePuzzle();
  }

  void _setupAnimationControllers() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _rotationController, curve: Curves.linear));

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _unlockController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _unlockAnimation = CurvedAnimation(
        parent: _unlockController, curve: Curves.easeOut);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )
      ..addListener(_updateParticles)
      ..repeat();

    _dialController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dialAnimation = CurvedAnimation(
        parent: _dialController, curve: Curves.elasticOut);

    _equationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _equationAnimation = CurvedAnimation(
        parent: _equationController, curve: Curves.easeOut);
  }

  void _generatePuzzle() {
    debugPrint("🔐 [CryptexLockBreaker] Generating new puzzle");
    
    setState(() {
      currentPuzzle = CryptexPuzzle.generate(widget.grade, widget.level);
      dialValues = List.from(currentPuzzle.initialValues);
      gameActive = true;
      isUnlocked = false;
      selectedDial = -1;
    });
    
    debugPrint("🔐 [CryptexLockBreaker] Puzzle generated:");
    debugPrint("🔐 [CryptexLockBreaker] Solution: ${currentPuzzle.solution}");
    debugPrint("🔐 [CryptexLockBreaker] Initial: ${currentPuzzle.initialValues}");
    for (final eq in currentPuzzle.equations) {
      debugPrint("🔐 [CryptexLockBreaker] Equation: ${eq.toString()}");
    }
  }

  void _rotateDial(int dialIndex, int delta) {
    if (!gameActive || isUnlocked) return;
    
    HapticFeedback.selectionClick();
    _dialController.forward(from: 0.0);
    
    setState(() {
      dialValues[dialIndex] = ((dialValues[dialIndex] + delta) % 10).abs();
      if (dialValues[dialIndex] < 0) dialValues[dialIndex] += 10;
    });
    
    debugPrint("🔐 [CryptexLockBreaker] Dial $dialIndex rotated to ${dialValues[dialIndex]}");
    _checkSolution();
  }

  void _onPanStart(DragStartDetails details, int dialIndex) {
    if (!gameActive || isUnlocked) return;
    
    setState(() {
      isDragging = true;
      selectedDial = dialIndex;
      dragStartY = details.globalPosition.dy;
      dragStartValue = dialValues[dialIndex];
    });
  }

  void _onPanUpdate(DragUpdateDetails details, int dialIndex) {
    if (!isDragging || !gameActive || isUnlocked) return;
    
    final deltaY = details.globalPosition.dy - dragStartY;
    final steps = (-deltaY / 20).round(); // 20 pixels per step
    
    final newValue = (dragStartValue + steps) % 10;
    
    if (newValue != dialValues[dialIndex]) {
      HapticFeedback.selectionClick();
      setState(() {
        dialValues[dialIndex] = newValue < 0 ? newValue + 10 : newValue;
      });
      _checkSolution();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      isDragging = false;
      selectedDial = -1;
    });
  }

  void _checkSolution() {
    final allSatisfied = currentPuzzle.equations.every((eq) => eq.isSatisfied(dialValues));
    
    if (allSatisfied && !isUnlocked) {
      debugPrint("🎉 [CryptexLockBreaker] All equations satisfied! Unlocking...");
      _handleSuccess();
    } else {
      // Add feedback particles for partially correct solutions
      final satisfiedCount = currentPuzzle.equations.where((eq) => eq.isSatisfied(dialValues)).length;
      if (satisfiedCount > 0) {
        _addProgressParticles(satisfiedCount);
      }
    }
    
    // Trigger equation highlight animation
    _equationController.forward(from: 0.0);
  }

  void _handleSuccess() {
    setState(() {
      isUnlocked = true;
      gameActive = false;
    });
    
    _unlockController.forward();
    HapticFeedback.heavyImpact();
    
    // Record successful completion
    final sriService = context.read<SriService>();
    final gameProvider = context.read<GameProvider>();
    final problem = MathProblem.generateProblem(gameProvider, widget.level, sriService);
    sriService.recordResponse(problem, true);
    
    // Calculate score
    final baseScore = 250 * widget.grade;
    final complexityBonus = (currentPuzzle.dialCount - 2) * 100;
    final equationBonus = currentPuzzle.equations.length * 50;
    final totalScore = baseScore + complexityBonus + equationBonus;
    
    context.read<GameProvider>().addScore(totalScore);
    context.read<GameProvider>().updateGameProgress('cryptex_lock_breaker', widget.level);
    
    // Add celebration particles
    for (int i = 0; i < 80; i++) {
      particles.add(CryptexParticle.celebration(
        MediaQuery.of(context).size.center(Offset.zero),
      ));
    }
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, complexityBonus, equationBonus),
        );
      }
    });
  }

  void _addProgressParticles(int satisfiedCount) {
    final random = math.Random();
    final screenSize = MediaQuery.of(context).size;
    final center = screenSize.center(Offset.zero);
    
    for (int i = 0; i < satisfiedCount * 3; i++) {
      particles.add(CryptexParticle.progress(
        center + Offset(
          (random.nextDouble() - 0.5) * 150,
          (random.nextDouble() - 0.5) * 150,
        ),
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    
    setState(() {
      particles.removeWhere((p) => p.update(0.016));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background effects
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _glowController, _unlockController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CryptexBackgroundPainter(
                        rotationAngle: _rotationAnimation.value,
                        glowIntensity: _glowAnimation.value,
                        unlockProgress: _unlockAnimation.value,
                        isUnlocked: isUnlocked,
                      ),
                    );
                  },
                ),
              ),
              
              // Particles
              ...particles.map((p) => p.build()),
              
              // Main game UI
              Column(
                children: [
                  GameUI(
                    title: S.of(context)!.cryptexLockBreakerGameTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      S.of(context)!.cryptexLockBreakerInstructions,
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          // Cryptex visual with dials
                          _buildCryptexVisual(),
                          
                          const SizedBox(height: 30),
                          
                          // Equations display
                          _buildEquationsDisplay(),
                          
                          const SizedBox(height: 20),
                          
                          // Controls hint
                          if (gameActive && !isUnlocked)
                            Text(
                              S.of(context)!.cryptexLockBreakerControls,
                              style: SpaceTheme.bodyStyle.copyWith(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCryptexVisual() {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cryptex body
          AnimatedBuilder(
            animation: _unlockAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(450, 250),
                painter: CryptexBodyPainter(
                  isUnlocked: isUnlocked,
                  unlockProgress: _unlockAnimation.value,
                ),
              );
            },
          ),
          
          // Dials
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(currentPuzzle.dialCount, (index) {
              return _buildDial(index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDial(int dialIndex) {
    final isSelected = selectedDial == dialIndex;
    final dialValue = dialValues[dialIndex];
    
    return GestureDetector(
      onPanStart: (details) => _onPanStart(details, dialIndex),
      onPanUpdate: (details) => _onPanUpdate(details, dialIndex),
      onPanEnd: _onPanEnd,
      onTap: () => setState(() => selectedDial = dialIndex),
      child: AnimatedBuilder(
        animation: _dialAnimation,
        builder: (context, child) {
          final scale = isSelected ? (1.0 + _dialAnimation.value * 0.15) : 1.0;
          
          return Transform.scale(
            scale: scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 120,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dial background
                  Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isSelected 
                            ? [SpaceTheme.starYellow.withOpacity(0.3), SpaceTheme.planetOrange.withOpacity(0.3)]
                            : [SpaceTheme.nebulaPurple.withOpacity(0.3), SpaceTheme.deepSpace.withOpacity(0.5)],
                      ),
                      border: Border.all(
                        color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen).withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  
                  // Dial markings and numbers
                  CustomPaint(
                    size: const Size(120, 180),
                    painter: DialPainter(
                      currentValue: dialValue,
                      isSelected: isSelected,
                      dialIndex: dialIndex,
                    ),
                  ),
                  
                  // Dial label
                  Positioned(
                    bottom: 12,
                    child: Text(
                      String.fromCharCode(65 + dialIndex), // A, B, C, etc.
                      style: SpaceTheme.titleStyle.copyWith(
                        fontSize: 20,
                        color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEquationsDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.cryptexLockBreakerEquations,
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.nebulaPurple),
          ),
          const SizedBox(height: 16),
          ...currentPuzzle.equations.map((equation) => _buildEquationRow(equation)),
        ],
      ),
    );
  }

  Widget _buildEquationRow(CryptexEquation equation) {
    final isSatisfied = equation.isSatisfied(dialValues);
    
    return AnimatedBuilder(
      animation: _equationAnimation,
      builder: (context, child) {
        final highlightIntensity = isSatisfied ? _equationAnimation.value : 0.0;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSatisfied 
                ? SpaceTheme.alienGreen.withOpacity(0.2 * highlightIntensity)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSatisfied ? SpaceTheme.alienGreen : Colors.white30,
              width: isSatisfied ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side of equation
              Text(
                equation.getLeftSideDisplay(),
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 18,
                  color: isSatisfied ? SpaceTheme.alienGreen : Colors.white,
                  fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              
              // Equals sign
              Text(
                '=',
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 20,
                  color: isSatisfied ? SpaceTheme.alienGreen : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Right side of equation
              Text(
                equation.getRightSideDisplay(),
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 18,
                  color: isSatisfied ? SpaceTheme.alienGreen : Colors.white,
                  fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              
              // Current result
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSatisfied ? SpaceTheme.alienGreen.withOpacity(0.3) : Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  equation.getCurrentResult(dialValues).toString(),
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 16,
                    color: isSatisfied ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessDialog(int totalScore, int complexityBonus, int equationBonus) {
    return AnimatedBuilder(
      animation: _unlockAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _unlockAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_open, size: 64, color: SpaceTheme.alienGreen),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.cryptexLockBreakerWinTitle,
                    style: SpaceTheme.headlineStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.cryptexLockBreakerWinDesc(
                      totalScore,
                      complexityBonus,
                      equationBonus,
                    ),
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
                        child: Text(S.of(context)!.nextCryptex),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.toTheBridge),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      particles.clear();
      isUnlocked = false;
    });
    
    _unlockController.reset();
    _generatePuzzle();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    _unlockController.dispose();
    _particleController.dispose();
    _dialController.dispose();
    _equationController.dispose();
    super.dispose();
  }
}

// Data Models
class CryptexPuzzle {
  final int dialCount;
  final List<CryptexEquation> equations;
  final List<int> solution;
  final List<int> initialValues;

  CryptexPuzzle({
    required this.dialCount,
    required this.equations,
    required this.solution,
    required this.initialValues,
  });

  static CryptexPuzzle generate(int grade, int level) {
    final complexity = grade + (level / 5.0);
    int dialCount;
    List<String> operators;
    
    if (complexity <= 2.0) {
      dialCount = 3;
      operators = ['+', '-'];
    } else if (complexity <= 3.5) {
      dialCount = math.Random().nextBool() ? 3 : 4;
      operators = ['+', '-', '*'];
    } else if (complexity <= 5.0) {
      dialCount = 4;
      operators = ['+', '-', '*', '/'];
    } else {
      dialCount = math.Random().nextBool() ? 4 : 5;
      operators = ['+', '-', '*', '/'];
    }
    
    return _generateSolvablePuzzle(dialCount, operators, grade);
  }

  static CryptexPuzzle _generateSolvablePuzzle(int dialCount, List<String> operators, int grade) {
    final random = math.Random();
    
    // Generate solution values (1-9 to avoid 0 complications)
    final solution = List.generate(dialCount, (_) => random.nextInt(9) + 1);
    
    // Generate equations that work with the solution
    final equations = <CryptexEquation>[];
    
    // Simple two-dial equations first
    for (int i = 0; i < dialCount - 1; i++) {
      final op = operators[random.nextInt(operators.length)];
      int result;
      
      switch (op) {
        case '+':
          result = solution[i] + solution[i + 1];
          break;
        case '-':
          result = (solution[i] - solution[i + 1]).abs();
          break;
        case '*':
          result = solution[i] * solution[i + 1];
          break;
        case '/':
          // Ensure clean division
          if (solution[i + 1] != 0 && solution[i] % solution[i + 1] == 0) {
            result = solution[i] ~/ solution[i + 1];
          } else {
            result = solution[i] + solution[i + 1]; // Fallback to addition
          }
          break;
        default:
          result = solution[i] + solution[i + 1];
      }
      
      equations.add(CryptexEquation(
        leftOperandIndices: [i, i + 1],
        operator: op == '/' && (solution[i + 1] == 0 || solution[i] % solution[i + 1] != 0) ? '+' : op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }
    
    // Add one more complex equation if we have enough dials
    if (dialCount >= 4) {
      final indices = [0, dialCount - 1];
      final op = ['+', '*'][random.nextInt(2)]; // Simpler operations for complex equations
      final result = op == '+' ? solution[0] + solution[dialCount - 1] : solution[0] * solution[dialCount - 1];
      
      equations.add(CryptexEquation(
        leftOperandIndices: indices,
        operator: op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }
    
    // Generate initial values (different from solution)
    final initialValues = List.generate(dialCount, (i) {
      int value;
      do {
        value = random.nextInt(10);
      } while (value == solution[i]);
      return value;
    });
    
    return CryptexPuzzle(
      dialCount: dialCount,
      equations: equations,
      solution: solution,
      initialValues: initialValues,
    );
  }
}

class CryptexEquation {
  final List<int> leftOperandIndices;
  final String operator;
  final int rightSide;
  final int? resultDialIndex; // null if right side is constant

  CryptexEquation({
    required this.leftOperandIndices,
    required this.operator,
    required this.rightSide,
    this.resultDialIndex,
  });

  bool isSatisfied(List<int> dialValues) {
    final leftResult = _calculateLeftSide(dialValues);
    final rightResult = resultDialIndex != null ? dialValues[resultDialIndex!] : rightSide;
    return leftResult == rightResult;
  }

  int getCurrentResult(List<int> dialValues) {
    return _calculateLeftSide(dialValues);
  }

  int _calculateLeftSide(List<int> dialValues) {
    if (leftOperandIndices.length < 2) return 0;
    
    final a = dialValues[leftOperandIndices[0]];
    final b = dialValues[leftOperandIndices[1]];
    
    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return (a - b).abs();
      case '*':
        return a * b;
      case '/':
        return b != 0 ? (a ~/ b) : 0;
      default:
        return a + b;
    }
  }

  String getLeftSideDisplay() {
    final dialLabels = leftOperandIndices.map((i) => String.fromCharCode(65 + i)).toList();
    if (dialLabels.length >= 2) {
      return '${dialLabels[0]} $operator ${dialLabels[1]}';
    }
    return dialLabels.isNotEmpty ? dialLabels[0] : '?';
  }

  String getRightSideDisplay() {
    return resultDialIndex != null 
        ? String.fromCharCode(65 + resultDialIndex!)
        : rightSide.toString();
  }

  @override
  String toString() {
    return '${getLeftSideDisplay()} = ${getRightSideDisplay()}';
  }
}

// Visual Effects
class CryptexParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  CryptexParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory CryptexParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 80 + random.nextDouble() * 120;
    return CryptexParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.amber, Colors.cyan, Colors.green][random.nextInt(3)],
      size: 3 + random.nextDouble() * 4,
      opacity: 1.0,
      life: 1.2 + random.nextDouble() * 0.8,
    );
  }

  factory CryptexParticle.progress(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 30 + random.nextDouble() * 60;
    return CryptexParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.orange,
      size: 2 + random.nextDouble() * 2,
      opacity: 0.8,
      life: 0.5 + random.nextDouble() * 0.3,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.98; // Damping
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
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(opacity * 0.5),
              blurRadius: size * 1.5,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painters
class CryptexBackgroundPainter extends CustomPainter {
  final double rotationAngle;
  final double glowIntensity;
  final double unlockProgress;
  final bool isUnlocked;

  CryptexBackgroundPainter({
    required this.rotationAngle,
    required this.glowIntensity,
    required this.unlockProgress,
    required this.isUnlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw rotating mystical symbols
    final symbolPaint = Paint()
      ..color = (isUnlocked ? Colors.green : Colors.cyan).withOpacity(0.1 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Concentric circles with ancient script effect
    for (double r = 100; r < size.width * 0.8; r += 120) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle + r * 0.01);
      
      // Draw symbolic markings around circles
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final pos = Offset.fromDirection(angle, r);
        final endPos = Offset.fromDirection(angle, r + 15);
        canvas.drawLine(pos, endPos, symbolPaint);
      }
      
      canvas.restore();
    }
    
    // Central energy vortex
    final vortexPaint = Paint()
      ..shader = RadialGradient(
        colors: isUnlocked 
            ? [Colors.green.withOpacity(0.5), Colors.transparent]
            : [Colors.cyan.withOpacity(0.3 * glowIntensity), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 150));
    
    canvas.drawCircle(center, 150 * (1.0 + unlockProgress * 0.5), vortexPaint);
  }

  @override
  bool shouldRepaint(CryptexBackgroundPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle ||
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.unlockProgress != unlockProgress ||
      oldDelegate.isUnlocked != isUnlocked;
}

class CryptexBodyPainter extends CustomPainter {
  final bool isUnlocked;
  final double unlockProgress;

  CryptexBodyPainter({required this.isUnlocked, required this.unlockProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyWidth = size.width * 0.8;
    final bodyHeight = size.height * 0.4;
    
    // Main cryptex body
    final bodyRect = Rect.fromCenter(
      center: center,
      width: bodyWidth,
      height: bodyHeight,
    );
    
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade800,
          Colors.grey.shade600,
          Colors.grey.shade700,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bodyRect);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(20)),
      bodyPaint,
    );
    
    // Decorative bands
    final bandPaint = Paint()
      ..color = Colors.amber.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final topBand = bodyRect.top + bodyHeight * 0.2;
    final bottomBand = bodyRect.bottom - bodyHeight * 0.2;
    
    canvas.drawLine(
      Offset(bodyRect.left, topBand),
      Offset(bodyRect.right, topBand),
      bandPaint,
    );
    canvas.drawLine(
      Offset(bodyRect.left, bottomBand),
      Offset(bodyRect.right, bottomBand),
      bandPaint,
    );
    
    // Unlock glow effect
    if (isUnlocked) {
      final glowPaint = Paint()
        ..color = Colors.green.withOpacity(0.5 * unlockProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(20)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CryptexBodyPainter oldDelegate) =>
      oldDelegate.isUnlocked != isUnlocked ||
      oldDelegate.unlockProgress != unlockProgress;
}

class DialPainter extends CustomPainter {
  final int currentValue;
  final bool isSelected;
  final int dialIndex;

  DialPainter({
    required this.currentValue,
    required this.isSelected,
    required this.dialIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw number markings around the dial
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * math.pi / 180; // 36 degrees per number
      final position = center + Offset.fromDirection(angle, radius - 15);
      
      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(
          color: i == currentValue ? Colors.white : Colors.white54,
          fontSize: i == currentValue ? 20 : 16,
          fontWeight: i == currentValue ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      
      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
    
    // Draw pointer/indicator for current value
    final pointerAngle = (currentValue * 36 - 90) * math.pi / 180;
    final pointerStart = center;
    final pointerEnd = center + Offset.fromDirection(pointerAngle, radius - 25);
    
    final pointerPaint = Paint()
      ..color = isSelected ? Colors.yellow : Colors.cyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(pointerStart, pointerEnd, pointerPaint);
    
    // Draw center dot
    canvas.drawCircle(
      center,
      4,
      Paint()..color = isSelected ? Colors.yellow : Colors.cyan,
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) =>
      oldDelegate.currentValue != currentValue ||
      oldDelegate.isSelected != isSelected;
}