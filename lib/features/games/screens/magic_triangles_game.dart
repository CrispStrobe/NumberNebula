import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

// Main Game Widget
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
  late Animation<double> _glowAnimation;

  MagicTriangle? currentTriangle;
  List<int?> userAnswers = [];
  int selectedAnswerIndex = -1; // Index from 0-n for which '?' is selected

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    _generateTriangle();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _generateTriangle() {
    setState(() {
      final difficulty = widget.grade + widget.level;
      currentTriangle = MagicTriangle.generate(difficulty, widget.grade);
      userAnswers = List.filled(currentTriangle!.hiddenIndices.length, null);
      selectedAnswerIndex = -1;
    });
  }

  void _onNumberSelected(int number) {
    if (selectedAnswerIndex != -1 && userAnswers[selectedAnswerIndex] == null) {
      setState(() {
        userAnswers[selectedAnswerIndex] = number;
        selectedAnswerIndex = -1; // Deselect after filling
      });
      _checkCompletion();
    }
  }

  void _onSpotTapped(int answerIndex, bool isFilled) {
    setState(() {
      if (isFilled) {
        userAnswers[answerIndex] = null;
        selectedAnswerIndex = -1;
      } else {
        selectedAnswerIndex = answerIndex;
      }
    });
  }

  void _checkCompletion() {
    if (userAnswers.every((answer) => answer != null)) {
      final isCorrect = currentTriangle!.checkSolution(userAnswers.cast<int>());
      if (isCorrect) {
        context.read<GameProvider>().addScore(100 * widget.grade);
        _showSuccessDialog();
      } else {
        _showIncorrectDialog();
      }
    }
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
              GameUI(
                title: S.of(context)!.magicTriangles,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Complete the cosmic triangle! Each side must add up to the magic number.",
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  bool isWide = constraints.maxWidth > 650;
                  return isWide ? _buildWideLayout() : _buildTallLayout();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 5, child: _buildTriangleWidget()),
          const SizedBox(width: 24),
          Expanded(flex: 4, child: _buildNumberPad()),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTriangleWidget(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildTriangleWidget() {
    return SizedBox(
      width: 360,
      height: 360,
      child: CustomPaint(
        size: const Size(360, 360),
        painter: MagicTrianglePainter(glow: _glowAnimation.value),
        child: Stack(children: _buildTriangleNodes()),
      ),
    );
  }

  List<Widget> _buildTriangleNodes() {
    if (currentTriangle == null) return [];
    
    const size = 360.0;
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.35;
    
    // Calculate triangle corner points
    final topCorner = Offset(center.dx, center.dy - radius);
    final bottomRightCorner = Offset(
      center.dx + radius * math.cos(math.pi / 6), 
      center.dy + radius * math.sin(math.pi / 6)
    );
    final bottomLeftCorner = Offset(
      center.dx - radius * math.cos(math.pi / 6), 
      center.dy + radius * math.sin(math.pi / 6)
    );

    final points = currentTriangle!.getTrianglePoints(
      topCorner, bottomRightCorner, bottomLeftCorner
    );

    List<Widget> nodes = [];
    int answerIdx = 0;
    
    for (int i = 0; i < currentTriangle!.values.length; i++) {
      int? value = currentTriangle!.values[i];
      bool isHidden = currentTriangle!.hiddenIndices.contains(i);
      int currentAnswerIndex = isHidden ? answerIdx++ : -1;

      if (isHidden) {
        value = userAnswers[currentAnswerIndex];
      }

      nodes.add(
        Positioned(
          left: points[i].dx - 35,
          top: points[i].dy - 35,
          child: GestureDetector(
            onTap: isHidden ? () => _onSpotTapped(currentAnswerIndex, value != null) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isHidden
                    ? (selectedAnswerIndex == currentAnswerIndex
                        ? RadialGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                        : RadialGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]))
                    : RadialGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink]),
                border: Border.all(
                  color: SpaceTheme.starYellow.withOpacity(_glowAnimation.value),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  isHidden ? (value?.toString() ?? '?') : value.toString(),
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 28),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return nodes;
  }

  Widget _buildNumberPad() {
    final availableNumbers = currentTriangle!.getAvailableNumbers();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SpaceTheme.cardDecoration,
          child: Column(
            children: [
              Icon(Icons.stars, color: SpaceTheme.starYellow, size: 32),
              const SizedBox(height: 8),
              Text(
                'Magic Sum: ${currentTriangle!.magicSum}',
                style: SpaceTheme.titleStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Each side must equal this number!',
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          selectedAnswerIndex != -1 ? 'Select a number:' : 'Tap a ? circle to fill it',
          style: SpaceTheme.bodyStyle.copyWith(
            color: selectedAnswerIndex != -1 ? SpaceTheme.starYellow : Colors.white70,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: availableNumbers.length,
          itemBuilder: (context, index) {
            final number = availableNumbers[index];
            final isUsed = userAnswers.contains(number);
            final canSelect = !isUsed && selectedAnswerIndex != -1;

            return GestureDetector(
              onTap: canSelect ? () => _onNumberSelected(number) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: canSelect
                      ? SpaceTheme.starGradient
                      : LinearGradient(
                          colors: [
                            Colors.grey.shade600,
                            Colors.grey.shade700,
                          ],
                        ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: canSelect ? SpaceTheme.starYellow : Colors.grey,
                    width: 2,
                  ),
                  boxShadow: canSelect
                      ? [
                          BoxShadow(
                            color: SpaceTheme.starYellow.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    number.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 24,
                      color: canSelect ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SpaceDialog(
        title: S.of(context)!.excellent,
        content: 'The cosmic triangle is complete!\nYou\'ve mastered the space mathematics!',
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
        title: 'Not quite right, Space Cadet!',
        content: 'Check your calculations. Each side should add up to ${currentTriangle!.magicSum}.',
        onNext: () {
          Navigator.of(context).pop();
          setState(() {
            userAnswers = List.filled(currentTriangle!.hiddenIndices.length, null);
            selectedAnswerIndex = -1;
          });
        },
      ),
    );
  }
}

// Enhanced Data Model for the puzzle
class MagicTriangle {
  final List<int> values;
  final Set<int> hiddenIndices;
  final int magicSum;
  final int circlesPerSide;

  MagicTriangle({
    required this.values,
    required this.hiddenIndices,
    required this.magicSum,
    required this.circlesPerSide,
  });

  static MagicTriangle generate(int difficulty, int grade) {
    // Grade-based circle count: Grade 3 = 3, Grade 4 = 3, Grade 5 = 4, Grade 6 = 4
    int circlesPerSide;
    switch (grade) {
      case 3:
      case 4:
        circlesPerSide = 3;
        break;
      case 5:
      case 6:
      default:
        circlesPerSide = 4;
        break;
    }

    final random = math.Random();
    List<int> values;
    int magicSum = 0;
    bool isValid;
    int attempts = 0;
    final totalCircles = (circlesPerSide * 3) - 3; // Each corner shared by 2 sides

    // Generate number range based on grade
    int maxNumber;
    switch (grade) {
      case 3:
        maxNumber = 20;
        break;
      case 4:
        maxNumber = 30;
        break;
      case 5:
        maxNumber = 50;
        break;
      case 6:
      default:
        maxNumber = 100;
        break;
    }

    do {
      isValid = true;
      values = List.filled(totalCircles, 0);
      final numbers = <int>{};
      
      // Generate unique numbers
      while (numbers.length < totalCircles) {
        numbers.add(random.nextInt(maxNumber) + 1);
      }
      values = numbers.toList()..shuffle();

      // Check if this forms a valid magic triangle
      final sideSum1 = _calculateSideSum(values, 0, circlesPerSide);
      final sideSum2 = _calculateSideSum(values, circlesPerSide - 1, circlesPerSide);
      final sideSum3 = _calculateSideSum(values, 2 * (circlesPerSide - 1), circlesPerSide);

      if (sideSum1 == sideSum2 && sideSum2 == sideSum3) {
        magicSum = sideSum1;
      } else {
        isValid = false;
      }
      attempts++;
    } while (!isValid && attempts < 10000);

    // Fallback to a guaranteed valid puzzle if generation fails
    if (!isValid) {
      if (circlesPerSide == 3) {
        return MagicTriangle(
          values: [8, 1, 6, 7, 2, 5], 
          hiddenIndices: {1, 3, 5}, 
          magicSum: 15,
          circlesPerSide: 3,
        );
      } else {
        return MagicTriangle(
          values: [1, 5, 3, 4, 6, 2, 7, 8, 9], 
          hiddenIndices: {1, 3, 5, 7}, 
          magicSum: 15,
          circlesPerSide: 4,
        );
      }
    }

    // Choose random indices to hide (grade-based difficulty)
    final hiddenIndices = <int>{};
    int hiddenCount;
    switch (grade) {
      case 3:
        hiddenCount = 2;
        break;
      case 4:
        hiddenCount = 3;
        break;
      case 5:
        hiddenCount = 3;
        break;
      case 6:
      default:
        hiddenCount = 4;
        break;
    }
    
    while (hiddenIndices.length < hiddenCount) {
      hiddenIndices.add(random.nextInt(totalCircles));
    }

    return MagicTriangle(
      values: values,
      hiddenIndices: hiddenIndices,
      magicSum: magicSum,
      circlesPerSide: circlesPerSide,
    );
  }

  static int _calculateSideSum(List<int> values, int startIndex, int circlesPerSide) {
    int sum = 0;
    for (int i = 0; i < circlesPerSide; i++) {
      final index = (startIndex + i) % values.length;
      sum += values[index];
    }
    return sum;
  }
  
  // Properly calculate triangle positions
  List<Offset> getTrianglePoints(Offset topCorner, Offset bottomRightCorner, Offset bottomLeftCorner) {
    final points = <Offset>[];
    
    // Side 1: Top to bottom-right
    for (int i = 0; i < circlesPerSide; i++) {
      final t = i / (circlesPerSide - 1);
      points.add(Offset.lerp(topCorner, bottomRightCorner, t)!);
    }
    
    // Side 2: Bottom-right to bottom-left (skip first point to avoid duplication)
    for (int i = 1; i < circlesPerSide; i++) {
      final t = i / (circlesPerSide - 1);
      points.add(Offset.lerp(bottomRightCorner, bottomLeftCorner, t)!);
    }
    
    // Side 3: Bottom-left to top (skip first and last points to avoid duplication)
    for (int i = 1; i < circlesPerSide - 1; i++) {
      final t = i / (circlesPerSide - 1);
      points.add(Offset.lerp(bottomLeftCorner, topCorner, t)!);
    }
    
    return points;
  }

  bool checkSolution(List<int> userAnswers) {
    final completeValues = List<int>.from(values);
    int i = 0;
    final sortedHiddenIndices = hiddenIndices.toList()..sort();
    
    for (int index in sortedHiddenIndices) {
      completeValues[index] = userAnswers[i++];
    }

    // Check each side sum
    final sideSum1 = _calculateSideSum(completeValues, 0, circlesPerSide);
    final sideSum2 = _calculateSideSum(completeValues, circlesPerSide - 1, circlesPerSide);
    final sideSum3 = _calculateSideSum(completeValues, 2 * (circlesPerSide - 1), circlesPerSide);

    return sideSum1 == magicSum && sideSum2 == magicSum && sideSum3 == magicSum;
  }

  List<int> getAvailableNumbers() {
    Set<int> numberSet = {};
    
    // Add correct answers
    for (int index in hiddenIndices) {
      numberSet.add(values[index]);
    }
    
    final random = math.Random();
    final maxDistractors = 6;
    
    // Add distractor numbers
    while (numberSet.length < hiddenIndices.length + maxDistractors) {
      final num = random.nextInt(magicSum > 1 ? magicSum + 10 : 30) + 1;
      if (!values.contains(num)) {
        numberSet.add(num);
      }
    }
    
    return numberSet.toList()..sort();
  }
}

// Custom Painter for the triangle outline with cosmic effects
class MagicTrianglePainter extends CustomPainter {
  final double glow;
  MagicTrianglePainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Calculate triangle corners
    final topCorner = Offset(center.dx, center.dy - radius);
    final bottomRightCorner = Offset(
      center.dx + radius * math.cos(math.pi / 6), 
      center.dy + radius * math.sin(math.pi / 6)
    );
    final bottomLeftCorner = Offset(
      center.dx - radius * math.cos(math.pi / 6), 
      center.dy + radius * math.sin(math.pi / 6)
    );

    // Draw triangle with glowing effect
    final paint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final glowPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glow * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

    final path = Path()
      ..moveTo(topCorner.dx, topCorner.dy)
      ..lineTo(bottomRightCorner.dx, bottomRightCorner.dy)
      ..lineTo(bottomLeftCorner.dx, bottomLeftCorner.dy)
      ..close();

    // Draw glow effect
    canvas.drawPath(path, glowPaint);
    // Draw main triangle
    canvas.drawPath(path, paint);

    // Add some cosmic sparkles
    final sparkleRadius = radius * 1.2;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 2 * math.pi / 8) + (glow * 2 * math.pi);
      final sparkleX = center.dx + math.cos(angle) * sparkleRadius;
      final sparkleY = center.dy + math.sin(angle) * sparkleRadius;
      
      final sparklePaint = Paint()
        ..color = SpaceTheme.starYellow.withOpacity(glow * 0.7)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(sparkleX, sparkleY), 2, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(MagicTrianglePainter oldDelegate) => oldDelegate.glow != glow;
}

// Dialog widget
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
            Text(title, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(content, style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onNext,
              style: SpaceTheme.primaryButtonStyle,
              child: Text(S.of(context)!.nextLevel),
            ),
          ],
        ),
      ),
    );
  }
}