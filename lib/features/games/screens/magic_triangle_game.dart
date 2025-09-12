import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class MagicTrianglesGame extends StatefulWidget {
  final int grade;
  final int level;
  
  const MagicTrianglesGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<MagicTrianglesGame> createState() => _MagicTrianglesGameState();
}

class _MagicTrianglesGameState extends State<MagicTrianglesGame>
    with TickerProviderStateMixin {
  
  late AnimationController _glowController;
  late AnimationController _rotationController;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotationAnimation;
  
  MagicTriangle? currentTriangle;
  List<int?> userAnswers = [null, null, null]; // For the three missing positions
  int selectedPosition = -1;
  bool isCompleted = false;
  
  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
    
    _generateTriangle();
  }
  
  @override
  void dispose() {
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
  
  void _generateTriangle() {
    final difficulty = widget.grade + widget.level;
    currentTriangle = MagicTriangle.generate(difficulty);
    userAnswers = [null, null, null];
    selectedPosition = -1;
    isCompleted = false;
    setState(() {});
  }
  
  void _onNumberSelected(int number) {
    if (selectedPosition >= 0 && selectedPosition < 3) {
      setState(() {
        userAnswers[selectedPosition] = number;
        selectedPosition = -1;
      });
      _checkCompletion();
    }
  }
  
  void _checkCompletion() {
    if (userAnswers.every((answer) => answer != null)) {
      final isCorrect = currentTriangle!.checkSolution(userAnswers.cast<int>());
      
      if (isCorrect) {
        setState(() => isCompleted = true);
        context.read<GameProvider>().addScore(100);
        _showSuccessDialog();
      } else {
        _showIncorrectDialog();
      }
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SpaceDialog(
        title: S.of(context).excellent,
        content: S.of(context).correct,
        onNext: () {
          Navigator.of(context).pop();
          _generateTriangle();
        },
      ),
    );
  }
  
  void _showIncorrectDialog() {
    showDialog(
      context: context,
      builder: (context) => SpaceDialog(
        title: S.of(context).tryAgain,
        content: S.of(context).incorrect,
        onNext: () {
          Navigator.of(context).pop();
          setState(() {
            userAnswers = [null, null, null];
            selectedPosition = -1;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentTriangle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Game UI Header
              GameUI(
                title: S.of(context).magicTriangles,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              
              // Instructions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  S.of(context).instructions['magicTriangles'] ?? '',
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Main Game Area
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Triangle Display
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(400, 400),
                                painter: MagicTrianglePainter(
                                  triangle: currentTriangle!,
                                  userAnswers: userAnswers,
                                  selectedPosition: selectedPosition,
                                  glowAnimation: _glowAnimation,
                                  rotation: _rotationAnimation.value,
                                  onPositionTapped: (position) {
                                    setState(() {
                                      selectedPosition = position;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      // Number Pad
                      Expanded(
                        child: _buildNumberPad(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNumberPad() {
    final availableNumbers = currentTriangle!.getAvailableNumbers();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Magic Sum: ${currentTriangle!.magicSum}',
          style: SpaceTheme.titleStyle.copyWith(
            color: SpaceTheme.starYellow,
          ),
        ),
        const SizedBox(height: 20),
        
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: availableNumbers.length,
          itemBuilder: (context, index) {
            final number = availableNumbers[index];
            final isUsed = userAnswers.contains(number);
            
            return AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: isUsed 
                        ? const LinearGradient(
                            colors: [Colors.grey, Colors.grey],
                          )
                        : SpaceTheme.starGradient,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withOpacity(
                          isUsed ? 0.2 : _glowAnimation.value * 0.5,
                        ),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: isUsed ? null : () => _onNumberSelected(number),
                      child: Center(
                        child: Text(
                          number.toString(),
                          style: SpaceTheme.headlineStyle.copyWith(
                            fontSize: 28,
                            color: isUsed ? Colors.grey : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class MagicTriangle {
  final List<int> values; // 6 values: corners + midpoints
  final List<bool> isVisible; // Which positions are given
  final int magicSum;
  
  MagicTriangle({
    required this.values,
    required this.isVisible,
    required this.magicSum,
  });
  
  static MagicTriangle generate(int difficulty) {
    // Generate a valid magic triangle based on difficulty
    final random = math.Random();
    final maxNumber = 10 + (difficulty * 2);
    
    // Start with a base magic sum
    final magicSum = 15 + (difficulty * 3);
    
    // Generate valid triangle values
    final values = List<int>.filled(6, 0);
    
    // Place some initial values and solve for others
    values[0] = random.nextInt(maxNumber) + 1; // Top corner
    values[2] = random.nextInt(maxNumber) + 1; // Bottom right corner
    values[4] = random.nextInt(maxNumber) + 1; // Bottom left corner
    
    // Calculate remaining values to satisfy magic sum
    values[1] = magicSum - values[0] - values[2]; // Right side middle
    values[3] = magicSum - values[2] - values[4]; // Bottom side middle
    values[5] = magicSum - values[4] - values[0]; // Left side middle
    
    // Adjust if any values are invalid
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) {
        values[i] = random.nextInt(5) + 1;
      }
    }
    
    // Determine which positions to hide (3 positions)
    final isVisible = List<bool>.filled(6, true);
    final hiddenPositions = <int>[];
    
    while (hiddenPositions.length < 3) {
      final pos = random.nextInt(6);
      if (!hiddenPositions.contains(pos)) {
        hiddenPositions.add(pos);
        isVisible[pos] = false;
      }
    }
    
    return MagicTriangle(
      values: values,
      isVisible: isVisible,
      magicSum: magicSum,
    );
  }
  
  bool checkSolution(List<int> userAnswers) {
    final completeValues = List<int>.from(values);
    int answerIndex = 0;
    
    for (int i = 0; i < isVisible.length; i++) {
      if (!isVisible[i]) {
        completeValues[i] = userAnswers[answerIndex++];
      }
    }
    
    // Check if all three sides sum to magic sum
    final side1 = completeValues[0] + completeValues[1] + completeValues[2];
    final side2 = completeValues[2] + completeValues[3] + completeValues[4];
    final side3 = completeValues[4] + completeValues[5] + completeValues[0];
    
    return side1 == magicSum && side2 == magicSum && side3 == magicSum;
  }
  
  List<int> getAvailableNumbers() {
    // Return a range of possible numbers for the difficulty
    final maxValue = values.reduce(math.max);
    final range = List.generate(maxValue + 5, (i) => i + 1);
    range.shuffle();
    return range.take(9).toList()..sort();
  }
}

class MagicTrianglePainter extends CustomPainter {
  final MagicTriangle triangle;
  final List<int?> userAnswers;
  final int selectedPosition;
  final Animation<double> glowAnimation;
  final double rotation;
  final Function(int) onPositionTapped;
  
  MagicTrianglePainter({
    required this.triangle,
    required this.userAnswers,
    required this.selectedPosition,
    required this.glowAnimation,
    required this.rotation,
    required this.onPositionTapped,
  }) : super(repaint: glowAnimation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    
    // Draw space background effects
    _drawSpaceEffects(canvas, size);
    
    // Calculate triangle points
    final points = <Offset>[
      // Corners
      center + Offset(0, -radius), // Top
      center + Offset(radius * 0.866, radius * 0.5), // Bottom right
      center + Offset(-radius * 0.866, radius * 0.5), // Bottom left
      // Midpoints
      center + Offset(radius * 0.433, -radius * 0.25), // Right side
      center + Offset(0, radius * 0.5), // Bottom side
      center + Offset(-radius * 0.433, -radius * 0.25), // Left side
    ];
    
    // Draw triangle outline
    _drawTriangleOutline(canvas, points);
    
    // Draw values and input fields
    for (int i = 0; i < 6; i++) {
      _drawPosition(canvas, points[i], i);
    }
  }
  
  void _drawSpaceEffects(Canvas canvas, Size size) {
    // Animated cosmic background
    final paint = Paint()
      ..color = SpaceTheme.nebulaPurple.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation * 0.5);
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5);
      final offset = Offset(
        math.cos(angle) * 150,
        math.sin(angle) * 150,
      );
      canvas.drawCircle(offset, 20, paint);
    }
    
    canvas.restore();
  }
  
  void _drawTriangleOutline(Canvas canvas, List<Offset> points) {
    final paint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glowAnimation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = SpaceTheme.starGradient.createShader(
        Rect.fromCircle(
          center: Offset(points[0].dx, points[0].dy),
          radius: 200,
        ),
      );
    
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawPosition(Canvas canvas, Offset position, int index) {
    final isHidden = !triangle.isVisible[index];
    final isSelected = selectedPosition == index;
    
    // Draw circle background
    final circlePaint = Paint()
      ..color = isSelected 
          ? SpaceTheme.alienGreen
          : isHidden 
              ? SpaceTheme.deepSpace
              : SpaceTheme.planetOrange
      ..style = PaintingStyle.fill;
    
    if (isSelected) {
      circlePaint.shader = SpaceTheme.starGradient.createShader(
        Rect.fromCircle(center: position, radius: 30),
      );
    }
    
    canvas.drawCircle(position, 30, circlePaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glowAnimation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(position, 30, borderPaint);
    
    // Draw text
    final text = isHidden 
        ? (userAnswers[_getAnswerIndex(index)]?.toString() ?? '?')
        : triangle.values[index].toString();
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: SpaceTheme.titleStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
  
  int _getAnswerIndex(int position) {
    int answerIndex = 0;
    for (int i = 0; i < position; i++) {
      if (!triangle.isVisible[i]) {
        answerIndex++;
      }
    }
    return answerIndex;
  }
  
  @override
  bool shouldRepaint(MagicTrianglePainter oldDelegate) {
    return oldDelegate.selectedPosition != selectedPosition ||
           oldDelegate.userAnswers != userAnswers;
  }
  
  @override
  bool hitTest(Offset position) => true;
}

class SpaceDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onNext;
  
  const SpaceDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onNext,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: SpaceTheme.headlineStyle),
            const SizedBox(height: 16),
            Text(content, style: SpaceTheme.bodyStyle),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onNext,
              style: SpaceTheme.primaryButtonStyle,
              child: Text(S.of(context).nextLevel),
            ),
          ],
        ),
      ),
    );
  }
}