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

class BubbleMathGame extends StatefulWidget {
  final int grade;
  final int level;

  const BubbleMathGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<BubbleMathGame> createState() => _BubbleMathGameState();
}

class _BubbleMathGameState extends State<BubbleMathGame>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Timer _gameTimer;

  List<Bubble> bubbles = [];
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

    _generateBubbles();
    _startGameTimer();

    _animationController.addListener(() {
      if (gameActive) {
        _updateBubblePositions();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gameTimer.cancel();
    super.dispose();
  }

  void _generateBubbles() {
    bubbles.clear();
    targetOrder.clear();
    currentTargetIndex = 0;

    final difficulty = widget.grade + widget.level;
    final bubbleCount = math.min(6 + difficulty, 12);
    final random = math.Random();

    // Generate math problems based on grade level
    for (int i = 0; i < bubbleCount; i++) {
      final problem = _generateMathProblem(difficulty, random);

      bubbles.add(Bubble(
        id: i,
        mathProblem: problem.expression,
        answer: problem.answer,
        position: Offset(
          random.nextDouble() * 800 + 100,
          random.nextDouble() * 400 + 100,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 200,
          (random.nextDouble() - 0.5) * 200,
        ),
        color: _getBubbleColor(i),
        size: 60.0 + random.nextDouble() * 20,
      ));

      targetOrder.add(problem.answer);
    }

    // Sort target order from smallest to largest
    targetOrder.sort();
    setState(() {});
  }

  // vvv 2. UPDATE ALL OF THESE METHODS vvv
  MathProblem _generateMathProblem(int difficulty, math.Random random) {
    return MathProblem.random(widget.grade, difficulty: difficulty);
  }

  MathProblem _generateGrade3Problem(math.Random random) {
    final operations = [MathOperation.addition, MathOperation.subtraction, MathOperation.multiplication];
    final operation = operations[random.nextInt(operations.length)];

    switch (operation) {
      case MathOperation.addition:
        final a = random.nextInt(20) + 1;
        final b = random.nextInt(20) + 1;
        return MathProblem.addition(a, b);
      case MathOperation.subtraction:
        final a = random.nextInt(20) + 10;
        final b = random.nextInt(a);
        return MathProblem.subtraction(a, b);
      case MathOperation.multiplication:
      default:
        final a = random.nextInt(5) + 2;
        final b = random.nextInt(5) + 2;
        return MathProblem.multiplication(a, b);
    }
  }

  MathProblem _generateGrade4Problem(math.Random random) {
    final operations = [MathOperation.addition, MathOperation.subtraction, MathOperation.multiplication, MathOperation.division];
    final operation = operations[random.nextInt(operations.length)];

    switch (operation) {
      case MathOperation.addition:
        final a = random.nextInt(50) + 10;
        final b = random.nextInt(50) + 10;
        return MathProblem.addition(a, b);
      case MathOperation.subtraction:
        final a = random.nextInt(50) + 20;
        final b = random.nextInt(a);
        return MathProblem.subtraction(a, b);
      case MathOperation.multiplication:
        final a = random.nextInt(8) + 2;
        final b = random.nextInt(8) + 2;
        return MathProblem.multiplication(a, b);
      case MathOperation.division:
      default:
        final b = random.nextInt(8) + 2;
        final answer = random.nextInt(10) + 2;
        final a = b * answer;
        return MathProblem.division(a, b);
    }
  }

  MathProblem _generateGrade5Problem(math.Random random) {
    final operations = [MathOperation.addition, MathOperation.subtraction, MathOperation.multiplication, MathOperation.division];
    final operation = operations[random.nextInt(operations.length)];

    switch (operation) {
      case MathOperation.addition:
        final a = random.nextInt(100) + 25;
        final b = random.nextInt(100) + 25;
        return MathProblem.addition(a, b);
      case MathOperation.subtraction:
        final a = random.nextInt(100) + 50;
        final b = random.nextInt(a);
        return MathProblem.subtraction(a, b);
      case MathOperation.multiplication:
        final a = random.nextInt(12) + 3;
        final b = random.nextInt(12) + 3;
        return MathProblem.multiplication(a, b);
      case MathOperation.division:
      default:
        final b = random.nextInt(12) + 3;
        final answer = random.nextInt(15) + 2;
        final a = b * answer;
        return MathProblem.division(a, b);
    }
  }

  MathProblem _generateGrade6Problem(math.Random random) {
    final operations = [MathOperation.addition, MathOperation.subtraction, MathOperation.multiplication, MathOperation.division];
    final operation = operations[random.nextInt(operations.length)];

    switch (operation) {
      case MathOperation.addition:
        final a = random.nextInt(200) + 50;
        final b = random.nextInt(200) + 50;
        return MathProblem.addition(a, b);
      case MathOperation.subtraction:
        final a = random.nextInt(200) + 100;
        final b = random.nextInt(a);
        return MathProblem.subtraction(a, b);
      case MathOperation.multiplication:
        final a = random.nextInt(15) + 5;
        final b = random.nextInt(15) + 5;
        return MathProblem.multiplication(a, b);
      case MathOperation.division:
      default:
        final b = random.nextInt(15) + 5;
        final answer = random.nextInt(20) + 3;
        final a = b * answer;
        return MathProblem.division(a, b);
    }
  }
  // ^^^ 2. END OF UPDATED METHODS ^^^

  Color _getBubbleColor(int index) {
    final colors = [
      SpaceTheme.alienGreen,
      SpaceTheme.cosmicPink,
      SpaceTheme.starYellow,
      SpaceTheme.planetOrange,
      SpaceTheme.moonSilver,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  void _updateBubblePositions() {
    final screenSize = MediaQuery.of(context).size;

    setState(() {
      for (var bubble in bubbles) {
        // Update position
        bubble.position += bubble.velocity * 0.016; // 60 FPS

        // Bounce off walls
        if (bubble.position.dx <= bubble.size / 2 ||
            bubble.position.dx >= screenSize.width - bubble.size / 2) {
          bubble.velocity = Offset(-bubble.velocity.dx, bubble.velocity.dy);
        }

        if (bubble.position.dy <= bubble.size / 2 ||
            bubble.position.dy >=
                screenSize.height - bubble.size / 2 - 100) {
          bubble.velocity = Offset(bubble.velocity.dx, -bubble.velocity.dy);
        }

        // Keep bubbles within bounds
        bubble.position = Offset(
          bubble.position.dx
              .clamp(bubble.size / 2, screenSize.width - bubble.size / 2),
          bubble.position.dy.clamp(
              bubble.size / 2, screenSize.height - bubble.size / 2 - 100),
        );
      }
    });
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (gameActive && timeLeft > 0) {
        setState(() {
          timeLeft--;
        });
      } else {
        _endGame();
      }
    });
  }

  void _onBubbleTapped(Bubble bubble) {
    if (!gameActive) return;

    final expectedAnswer = targetOrder[currentTargetIndex];

    if (bubble.answer == expectedAnswer) {
      // Correct bubble!
      setState(() {
        bubbles.remove(bubble);
        currentTargetIndex++;
      });

      context.read<GameProvider>().addScore(10);

      if (currentTargetIndex >= targetOrder.length) {
        _winGame();
      }
    } else {
      // Wrong bubble - show feedback
      _showWrongBubbleFeedback();
    }
  }

  void _showWrongBubbleFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${S.of(context)!.tryAgain} Look for: ${targetOrder[currentTargetIndex]}',
          style: SpaceTheme.bodyStyle,
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _winGame() {
    setState(() {
      gameActive = false;
    });

    _gameTimer.cancel();
    context.read<GameProvider>().addScore(timeLeft * 5); // Bonus for time left

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildWinDialog(),
    );
  }

  void _endGame() {
    setState(() {
      gameActive = false;
    });

    _gameTimer.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildGameOverDialog(),
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
              Icons.rocket_launch,
              size: 64,
              color: SpaceTheme.starYellow,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.excellent,
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Time Bonus: ${timeLeft * 5} points!',
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
              Icons.access_time,
              size: 64,
              color: SpaceTheme.warning,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.gameOver,
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.tryAgain,
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
      timeLeft = 60;
      gameActive = true;
      currentTargetIndex = 0;
    });

    _generateBubbles();
    _startGameTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Game UI Header
              GameUI(
                title: S.of(context)!.bubbleMath,
                level: widget.level,
                timeLeft: timeLeft,
                onBack: () => Navigator.of(context).pop(),
              ),

              // Target indicator
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: SpaceTheme.cardDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Next target: ',
                      style: SpaceTheme.bodyStyle,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        currentTargetIndex < targetOrder.length
                            ? targetOrder[currentTargetIndex].toString()
                            : 'Complete!',
                        style: SpaceTheme.titleStyle.copyWith(
                          color: SpaceTheme.spaceBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Game Area
              Expanded(
                child: Stack(
                  children: bubbles
                      .map((bubble) => BubbleWidget(
                            bubble: bubble,
                            onTapped: () => _onBubbleTapped(bubble),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Bubble {
  int id;
  String mathProblem;
  int answer;
  Offset position;
  Offset velocity;
  Color color;
  double size;

  Bubble({
    required this.id,
    required this.mathProblem,
    required this.answer,
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });
}

class BubbleWidget extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onTapped;

  const BubbleWidget({
    super.key,
    required this.bubble,
    required this.onTapped,
  });

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.bubble.position.dx - widget.bubble.size / 2,
      top: widget.bubble.position.dy - widget.bubble.size / 2,
      child: GestureDetector(
        onTap: widget.onTapped,
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Container(
              width: widget.bubble.size,
              height: widget.bubble.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.bubble.color.withOpacity(_shimmerAnimation.value),
                    widget.bubble.color.withOpacity(0.6),
                    widget.bubble.color.withOpacity(0.3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.bubble.color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.bubble.mathProblem,
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.bubble.answer.toString(),
                      style: SpaceTheme.titleStyle.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
