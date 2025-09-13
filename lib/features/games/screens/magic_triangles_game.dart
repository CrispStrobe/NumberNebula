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
  int selectedAnswerIndex = -1; // Index from 0-2 for which '?' is selected

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
      currentTriangle = MagicTriangle.generate(difficulty);
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
        context.read<GameProvider>().addScore(100);
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
                  S.of(context)!.instructionsMagicTriangles,
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
      width: 320,
      height: 320,
      child: CustomPaint(
        size: const Size(320, 320),
        painter: MagicTrianglePainter(glow: _glowAnimation.value),
        child: Stack(children: _buildTriangleNodes()),
      ),
    );
  }

  List<Widget> _buildTriangleNodes() {
    if (currentTriangle == null) return [];
    
    const size = 320.0;
    final center = const Offset(size / 2, size / 2);
    final radius = size * 0.4;
    final points = currentTriangle!.getPoints(center, radius);

    List<Widget> nodes = [];
    int answerIdx = 0;
    for (int i = 0; i < 6; i++) {
      int? value = currentTriangle!.values[i];
      bool isHidden = currentTriangle!.hiddenIndices.contains(i);
      int currentAnswerIndex = isHidden ? answerIdx++ : -1;

      if (isHidden) {
        value = userAnswers[currentAnswerIndex];
      }

      nodes.add(
        Positioned(
          left: points[i].dx - 30,
          top: points[i].dy - 30,
          child: GestureDetector(
            onTap: isHidden ? () => _onSpotTapped(currentAnswerIndex, value != null) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isHidden
                    ? (selectedAnswerIndex == currentAnswerIndex
                        ? SpaceTheme.starYellow
                        : SpaceTheme.deepSpace)
                    : SpaceTheme.planetOrange,
                border: Border.all(
                  color: SpaceTheme.starYellow.withOpacity(_glowAnimation.value),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  isHidden ? (value?.toString() ?? '?') : value.toString(),
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
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
        Text(
          'Magic Sum: ${currentTriangle!.magicSum}',
          style: SpaceTheme.titleStyle.copyWith(
            color: SpaceTheme.starYellow,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 20),
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

            return GestureDetector(
              onTap: isUsed || selectedAnswerIndex == -1
                  ? null
                  : () => _onNumberSelected(number),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isUsed || selectedAnswerIndex == -1 ? 0.4 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: SpaceTheme.starGradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 28),
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

  // --- Dialog methods (no changes needed here) ---
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SpaceDialog(
        title: S.of(context)!.excellent,
        content: S.of(context)!.correct,
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
        title: S.of(context)!.tryAgain,
        content: S.of(context)!.incorrect,
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

// Data Model for the puzzle
class MagicTriangle {
  final List<int> values;
  final Set<int> hiddenIndices;
  final int magicSum;

  MagicTriangle({
    required this.values,
    required this.hiddenIndices,
    required this.magicSum,
  });

  // FIX: Rewritten puzzle generation logic to be more robust.
  static MagicTriangle generate(int difficulty) {
    final random = math.Random();
    List<int> values;
    int magicSum = 0;
    bool isValid;
    int attempts = 0;

    do {
      isValid = true;
      values = List.filled(6, 0);
      final numbers = <int>{};
      while (numbers.length < 6) {
        numbers.add(random.nextInt(10 + difficulty * 2) + 1);
      }
      values = numbers.toList()..shuffle();

      final side1 = values[0] + values[1] + values[2];
      final side2 = values[2] + values[3] + values[4];
      final side3 = values[4] + values[5] + values[0];

      if (side1 == side2 && side2 == side3) {
        magicSum = side1;
      } else {
        isValid = false;
      }
      attempts++;
    } while (!isValid && attempts < 50000);

    // Fallback to a guaranteed valid puzzle if one isn't found quickly
    if (!isValid) {
      return MagicTriangle(values: [8, 1, 6, 7, 2, 5], hiddenIndices: {1, 3, 5}, magicSum: 15);
    }

    final hiddenIndices = <int>{};
    while (hiddenIndices.length < 3) {
      hiddenIndices.add(random.nextInt(6));
    }

    return MagicTriangle(
      values: values,
      hiddenIndices: hiddenIndices,
      magicSum: magicSum,
    );
  }
  
  // FIX: Corrected point calculation for perfect alignment.
  List<Offset> getPoints(Offset center, double radius) {
    final corners = [
      center + Offset(0, -radius),
      center + Offset(radius * math.sqrt(3) / 2, radius / 2),
      center + Offset(-radius * math.sqrt(3) / 2, radius / 2),
    ];

    return [
      corners[0], // Top corner
      _midpoint(corners[0], corners[1]), // Top-right middle
      corners[1], // Bottom-right corner
      _midpoint(corners[1], corners[2]), // Bottom middle
      corners[2], // Bottom-left corner
      _midpoint(corners[2], corners[0]), // Top-left middle
    ];
  }

  Offset _midpoint(Offset p1, Offset p2) {
    return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  }

  // FIX: Rewritten solution check to be more robust.
  bool checkSolution(List<int> userAnswers) {
    final completeValues = List<int>.from(values);
    int i = 0;
    final sortedHiddenIndices = hiddenIndices.toList()..sort();
    for (int index in sortedHiddenIndices) {
      completeValues[index] = userAnswers[i++];
    }

    final side1 = completeValues[0] + completeValues[1] + completeValues[2];
    final side2 = completeValues[2] + completeValues[3] + completeValues[4];
    final side3 = completeValues[4] + completeValues[5] + completeValues[0];

    return side1 == magicSum && side2 == magicSum && side3 == magicSum;
  }

  // FIX: Generate a real number pool with distractors, and sort it.
  List<int> getAvailableNumbers() {
    Set<int> numberSet = {};
    for (int index in hiddenIndices) {
      numberSet.add(values[index]);
    }
    final random = math.Random();
    // Add 3 distractor numbers
    while (numberSet.length < hiddenIndices.length + 3) {
      final num = random.nextInt(magicSum > 1 ? magicSum + 5 : 20) + 1;
      if (!values.contains(num)) {
        numberSet.add(num);
      }
    }
    return numberSet.toList()..sort();
  }
}

// Custom Painter for the static triangle outline
class MagicTrianglePainter extends CustomPainter {
  final double glow;
  MagicTrianglePainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    final cornerPoints = [
      center + Offset(0, -radius),
      center + Offset(radius * math.sqrt(3) / 2, radius / 2),
      center + Offset(-radius * math.sqrt(3) / 2, radius / 2),
    ];

    final paint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path()
      ..moveTo(cornerPoints[0].dx, cornerPoints[0].dy)
      ..lineTo(cornerPoints[1].dx, cornerPoints[1].dy)
      ..lineTo(cornerPoints[2].dx, cornerPoints[2].dy)
      ..close();

    canvas.drawPath(path, paint);
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
            Text(title, style: SpaceTheme.headlineStyle),
            const SizedBox(height: 16),
            Text(content, style: SpaceTheme.bodyStyle),
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
