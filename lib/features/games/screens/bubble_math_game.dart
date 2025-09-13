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

    // Generate bubbles after the first frame to have access to context/size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateBubbles();
      _startGameTimer();

      _animationController.addListener(() {
        if (gameActive && mounted) {
          _updateBubblePositions(MediaQuery.of(context).size);
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gameTimer.cancel();
    super.dispose();
  }

  void _generateBubbles() {
    if (!mounted) return;
    bubbles.clear();
    targetOrder.clear();
    currentTargetIndex = 0;
    
    final screenSize = MediaQuery.of(context).size;
    final difficulty = widget.grade + widget.level;
    final bubbleCount = math.min(4 + (difficulty / 2).floor(), 10);
    final random = math.Random();
    final usedAnswers = <int>{};

    for (int i = 0; i < bubbleCount; i++) {
      MathProblem problem;
      
      double equationChance = 0.1 * difficulty;
      if (random.nextDouble() > equationChance) {
        int plainNumber;
        do {
          plainNumber = random.nextInt(difficulty * 5 + 10) + 1;
        } while (usedAnswers.contains(plainNumber));
        problem = MathProblem(
          expression: plainNumber.toString(),
          answer: plainNumber,
          operation: MathOperation.addition, 
          operandA: plainNumber,
          operandB: 0,
          difficulty: 1,
        );
      } else {
        do {
          problem = MathProblem.random(widget.grade, difficulty: difficulty);
        } while (usedAnswers.contains(problem.answer));
      }

      usedAnswers.add(problem.answer);
      
      final bubbleSize = 85.0 + random.nextDouble() * 40;
      final bubbleSpeed = 60.0 + random.nextDouble() * 20;

      bubbles.add(Bubble(
        id: i,
        mathProblem: problem.expression,
        answer: problem.answer,
        position: Offset(
          random.nextDouble() * (screenSize.width - bubbleSize) + (bubbleSize / 2),
          random.nextDouble() * (screenSize.height - bubbleSize - 150) + (bubbleSize / 2),
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * bubbleSpeed,
          (random.nextDouble() - 0.5) * bubbleSpeed,
        ),
        color: _getBubbleColor(i),
        size: bubbleSize,
      ));

      targetOrder.add(problem.answer);
    }
    
    targetOrder.sort();
    setState(() {});
  }

  Color _getBubbleColor(int index) {
    final colors = [
      SpaceTheme.planetOrange,
      SpaceTheme.alienGreen,
      SpaceTheme.cosmicPink,
      SpaceTheme.starYellow,
      Colors.cyan,
      Colors.purple.shade300,
    ];
    return colors[index % colors.length];
  }

  void _updateBubblePositions(Size screenSize) {
    setState(() {
      for (var bubble in bubbles) {
        bubble.position += bubble.velocity * 0.016;

        if (bubble.position.dx <= bubble.size / 2 ||
            bubble.position.dx >= screenSize.width - bubble.size / 2) {
          bubble.velocity = Offset(-bubble.velocity.dx, bubble.velocity.dy);
        }

        if (bubble.position.dy <= bubble.size / 2 ||
            bubble.position.dy >=
                screenSize.height - bubble.size / 2 - 150) {
          bubble.velocity = Offset(bubble.velocity.dx, -bubble.velocity.dy);
        }
        
        bubble.position = Offset(
          bubble.position.dx.clamp(bubble.size / 2, screenSize.width - bubble.size / 2),
          bubble.position.dy.clamp(bubble.size / 2, screenSize.height - bubble.size / 2 - 150),
        );
      }
    });
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && gameActive && timeLeft > 0) {
        setState(() => timeLeft--);
      } else if (mounted) {
        _endGame();
      }
    });
  }

  void _onBubbleTapped(Bubble bubble) {
    if (!gameActive) return;

    final expectedAnswer = targetOrder[currentTargetIndex];

    if (bubble.answer == expectedAnswer) {
      setState(() {
        bubbles.remove(bubble);
        currentTargetIndex++;
      });
      context.read<GameProvider>().addScore(10);
      if (currentTargetIndex >= targetOrder.length) {
        _winGame();
      }
    } else {
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
    if (!gameActive) return;
    setState(() => gameActive = false);
    _gameTimer.cancel();
    context.read<GameProvider>().addScore(timeLeft * 5); // Time bonus
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
                title: S.of(context)!.bubbleMath,
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
                    Text(S.of(context)!.nextTarget, style: SpaceTheme.bodyStyle),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        currentTargetIndex < targetOrder.length
                            ? targetOrder[currentTargetIndex].toString()
                            : '✔️',
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
                  children: bubbles.map((bubble) => BubbleWidget(
                    key: ValueKey(bubble.id),
                    bubble: bubble,
                    onTapped: () => _onBubbleTapped(bubble),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
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
    });
    _generateBubbles();
    _startGameTimer();
  }
}

class Bubble {
  final int id;
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

class BubbleWidget extends StatelessWidget {
  final Bubble bubble;
  final VoidCallback onTapped;

  const BubbleWidget({
    super.key,
    required this.bubble,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: bubble.position.dx - bubble.size / 2,
      top: bubble.position.dy - bubble.size / 2,
      child: GestureDetector(
        onTap: onTapped,
        child: Container(
          width: bubble.size,
          height: bubble.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                bubble.color.withOpacity(0.9),
                bubble.color,
              ],
              stops: const [0.0, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: bubble.color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              bubble.mathProblem,
              style: TextStyle(
                fontSize: bubble.size * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(2.0, 2.0),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}