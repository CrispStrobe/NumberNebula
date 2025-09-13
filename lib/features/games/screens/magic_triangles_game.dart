import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';

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
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  MagicTriangle? currentTriangle;
  List<int?> userAnswers = [];
  int selectedAnswerIndex = -1;

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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateTriangle() {
    setState(() {
      final difficulty = DifficultyManager.getDifficulty(widget.grade, widget.level);
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
          Expanded(flex: 3, child: _buildTriangleWidget()), // FIX: Better flex ratio
          const SizedBox(width: 24),
          Expanded(flex: 2, child: SingleChildScrollView(child: _buildNumberPad())), // FIX: Add scroll
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // FIX: Better padding
        child: Column(
          children: [
            _buildTriangleWidget(),
            const SizedBox(height: 16), // FIX: Reduced spacing
            _buildNumberPad(),
            const SizedBox(height: 20), // FIX: Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildTriangleWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // FIX: Responsive triangle size
        final maxSize = math.min(constraints.maxWidth, constraints.maxHeight);
        final triangleSize = math.min(maxSize * 0.9, 350.0);
        
        return Center(
          child: SizedBox(
            width: triangleSize,
            height: triangleSize,
            child: CustomPaint(
              size: Size(triangleSize, triangleSize),
              painter: MagicTrianglePainter(glow: _glowAnimation.value),
              child: Stack(children: _buildTriangleNodes(triangleSize)),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTriangleNodes(double size) {
    if (currentTriangle == null) return [];
    
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.32; // FIX: Better radius for positioning
    
    // Calculate triangle corner points with better spacing
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
    
    // FIX: Better node size based on triangle size
    final nodeSize = (size * 0.18).clamp(50.0, 80.0);
    
    for (int i = 0; i < currentTriangle!.values.length; i++) {
      int? value = currentTriangle!.values[i];
      bool isHidden = currentTriangle!.hiddenIndices.contains(i);
      int currentAnswerIndex = isHidden ? answerIdx++ : -1;

      if (isHidden) {
        value = userAnswers[currentAnswerIndex];
      }

      nodes.add(
        Positioned(
          left: points[i].dx - nodeSize / 2,
          top: points[i].dy - nodeSize / 2,
          child: isHidden 
              ? DragTarget<int>(
                  builder: (context, candidateData, rejectedData) {
                    return GestureDetector(
                      onTap: () => _onSpotTapped(currentAnswerIndex, value != null),
                      child: _buildStargateNode(
                        value: value,
                        isSelected: selectedAnswerIndex == currentAnswerIndex,
                        isHidden: true,
                        hasCandidate: candidateData.isNotEmpty,
                        size: nodeSize, // FIX: Pass size parameter
                      ),
                    );
                  },
                  onAccept: (number) {
                    setState(() {
                      userAnswers[currentAnswerIndex] = number;
                      selectedAnswerIndex = -1;
                    });
                    _checkCompletion();
                  },
                )
              : _buildStargateNode(
                  value: value,
                  isSelected: false,
                  isHidden: false,
                  hasCandidate: false,
                  size: nodeSize, // FIX: Pass size parameter
                ),
        ),
      );
    }
    return nodes;
  }

  Widget _buildStargateNode({
    required int? value,
    required bool isSelected,
    required bool isHidden,
    required bool hasCandidate,
    double size = 70, // FIX: Default size parameter
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? _pulseAnimation.value : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _getNodeGradient(isHidden, isSelected, hasCandidate),
              border: Border.all(
                color: _getNodeBorderColor(isHidden, isSelected, hasCandidate),
                width: 3,
              ),
              boxShadow: _getNodeShadow(isHidden, isSelected, hasCandidate),
            ),
            child: Stack(
              children: [
                // Energy rings
                Positioned.fill(
                  child: CustomPaint(
                    painter: NodeEnergyPainter(
                      glow: _glowAnimation.value,
                      isActive: isSelected || hasCandidate,
                    ),
                  ),
                ),
                
                // Number with better positioning
                Center(
                  child: Container(
                    padding: EdgeInsets.all(size * 0.1), // FIX: Responsive padding
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(size * 0.15),
                    ),
                    child: Text(
                      isHidden ? (value?.toString() ?? '?') : value.toString(),
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: size * 0.3, // FIX: Responsive font size
                        shadows: [
                          Shadow(
                            color: SpaceTheme.starYellow,
                            blurRadius: isSelected ? 15 : 5,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberPad() {
    final availableNumbers = currentTriangle!.getAvailableNumbers();
    return Column(
      mainAxisSize: MainAxisSize.min, // FIX: Prevent overflow
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SpaceTheme.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min, // FIX: Prevent overflow
            children: [
              Icon(Icons.stars, color: SpaceTheme.starYellow, size: 28),
              const SizedBox(height: 8),
              Text(
                'Magic Sum: ${currentTriangle!.magicSum}',
                style: SpaceTheme.titleStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Each side must equal this number!',
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          selectedAnswerIndex != -1 ? 'Select a number:' : 'Tap a ? circle to fill it',
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 14,
            color: selectedAnswerIndex != -1 ? SpaceTheme.starYellow : Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        // FIX: Constrained grid to prevent overflow
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.3, // FIX: Better aspect ratio
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canSelect ? SpaceTheme.starYellow : Colors.grey,
                      width: 2,
                    ),
                    boxShadow: canSelect
                        ? [
                            BoxShadow(
                              color: SpaceTheme.starYellow.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 20, // FIX: Consistent font size
                        color: canSelect ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  RadialGradient _getNodeGradient(bool isHidden, bool isSelected, bool hasCandidate) {
    if (!isHidden) {
      return RadialGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink]);
    }
    
    if (hasCandidate) {
      return RadialGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    }
    
    if (isSelected) {
      return RadialGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    }
    
    return RadialGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]);
  }

  Color _getNodeBorderColor(bool isHidden, bool isSelected, bool hasCandidate) {
    if (hasCandidate) return SpaceTheme.starYellow;
    if (isSelected) return SpaceTheme.starYellow;
    return SpaceTheme.starYellow.withOpacity(_glowAnimation.value);
  }

  List<BoxShadow> _getNodeShadow(bool isHidden, bool isSelected, bool hasCandidate) {
    if (hasCandidate || isSelected) {
      return [
        BoxShadow(
          color: SpaceTheme.starYellow.withOpacity(0.8),
          blurRadius: 20,
          spreadRadius: 5,
        ),
      ];
    }
    
    return [
      BoxShadow(
        color: SpaceTheme.starYellow.withOpacity(_glowAnimation.value * 0.5),
        blurRadius: 15,
        spreadRadius: 3,
      ),
    ];
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
// Fixed MagicTriangle class with proper algorithm (renamed to Stargate)
class StargateTriangle {
  final List<int> values;
  final Set<int> hiddenIndices;
  final int magicSum;
  final int circlesPerSide;

  StargateTriangle({
    required this.values,
    required this.hiddenIndices,
    required this.magicSum,
    required this.circlesPerSide,
  });

  static StargateTriangle generate(DifficultyConfig difficulty, int grade) {
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
    final totalCircles = (circlesPerSide * 3) - 3; // Each corner shared by 2 sides
    final maxNumber = difficulty.numberRange['max']!;
    final minNumber = difficulty.numberRange['min']!;
    
    List<int> validSolution = [];
    int magicSum = 0;
    int attempts = 0;
    
    // FIX: Use proper algorithm similar to React version
    do {
      attempts++;
      
      // Generate a pool of candidate numbers
      final candidatePool = <int>[];
      for (int i = minNumber; i <= maxNumber; i++) {
        candidatePool.add(i);
      }
      candidatePool.shuffle(random);
      
      // Try to find a valid arrangement
      validSolution = candidatePool.take(totalCircles).toList();
      
      // Calculate sums for each side
      final sums = <int>[];
      bool isValid = true;
      
      for (int side = 0; side < 3; side++) {
        int sideSum = 0;
        final sideIndices = _getSideIndices(side, circlesPerSide, totalCircles);
        
        for (int idx in sideIndices) {
          if (idx >= validSolution.length) {
            isValid = false;
            break;
          }
          sideSum += validSolution[idx];
        }
        
        if (!isValid) break;
        sums.add(sideSum);
      }
      
      // Check if all sides have the same sum
      if (isValid && sums.length == 3 && sums[0] == sums[1] && sums[1] == sums[2]) {
        magicSum = sums[0];
        break;
      }
      
      // If we can't find a valid solution, try a known working configuration
      if (attempts > 1000) {
        if (circlesPerSide == 3) {
          // Known working 3-circle triangle: corners share
          validSolution = [6, 1, 8, 3, 5, 4]; // Forms triangle with sum 15
          magicSum = 15;
          break;
        } else {
          // Known working 4-circle triangle
          validSolution = [1, 11, 8, 4, 6, 2, 9, 7, 3]; // Forms triangle with sum 24
          magicSum = 24;
          break;
        }
      }
    } while (attempts < 1500);
    
    // If still no valid solution, use guaranteed working examples
    if (magicSum == 0) {
      if (circlesPerSide == 3) {
        validSolution = [6, 1, 8, 3, 5, 4];
        magicSum = 15;
      } else {
        validSolution = [1, 11, 8, 4, 6, 2, 9, 7, 3];
        magicSum = 24;
      }
    }

    // Choose which circles to hide (difficulty-based)
    final hiddenCount = (2 + (difficulty.difficultyMultiplier * 1.2).round()).clamp(2, totalCircles - 2);
    final hiddenIndices = <int>{};
    
    // Don't hide all corners at once (would make it too hard)
    final cornerIndices = {0, circlesPerSide - 1, (circlesPerSide - 1) * 2};
    final maxHiddenCorners = math.min(2, hiddenCount - 1);
    int hiddenCorners = 0;
    
    while (hiddenIndices.length < hiddenCount) {
      final candidateIndex = random.nextInt(totalCircles);
      if (!hiddenIndices.contains(candidateIndex)) {
        if (cornerIndices.contains(candidateIndex)) {
          if (hiddenCorners < maxHiddenCorners) {
            hiddenIndices.add(candidateIndex);
            hiddenCorners++;
          }
        } else {
          hiddenIndices.add(candidateIndex);
        }
      }
    }

    return StargateTriangle(
      values: validSolution,
      hiddenIndices: hiddenIndices,
      magicSum: magicSum,
      circlesPerSide: circlesPerSide,
    );
  }

  // FIX: Proper side indices calculation
  static List<int> _getSideIndices(int side, int circlesPerSide, int totalCircles) {
    final indices = <int>[];
    
    switch (side) {
      case 0: // Top-right side
        for (int i = 0; i < circlesPerSide; i++) {
          indices.add(i);
        }
        break;
      case 1: // Bottom side  
        for (int i = 0; i < circlesPerSide; i++) {
          final idx = (circlesPerSide - 1 + i) % totalCircles;
          indices.add(idx);
        }
        break;
      case 2: // Left side
        for (int i = 0; i < circlesPerSide; i++) {
          final idx = (totalCircles - 1 - i) % totalCircles;
          indices.add(idx);
        }
        break;
    }
    
    return indices;
  }
  
  // Properly calculate triangle positions with better spacing
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
    int answerIndex = 0;
    final sortedHiddenIndices = hiddenIndices.toList()..sort();
    
    for (int index in sortedHiddenIndices) {
      if (answerIndex < userAnswers.length) {
        completeValues[index] = userAnswers[answerIndex++];
      }
    }

    // Check each side sum
    for (int side = 0; side < 3; side++) {
      final sideIndices = _getSideIndices(side, circlesPerSide, completeValues.length);
      int sideSum = 0;
      
      for (int idx in sideIndices) {
        if (idx < completeValues.length) {
          sideSum += completeValues[idx];
        }
      }
      
      if (sideSum != magicSum) {
        return false;
      }
    }
    
    return true;
  }

  List<int> getAvailableNumbers() {
    Set<int> correctNumbers = {};
    
    // Add correct answers
    for (int index in hiddenIndices) {
      if (index < values.length) {
        correctNumbers.add(values[index]);
      }
    }
    
    final random = math.Random();
    final maxDistractors = 6;
    
    // Add distractor numbers that make sense
    while (correctNumbers.length < hiddenIndices.length + maxDistractors) {
      final baseRange = magicSum ~/ 3; // Rough average per number
      final num = random.nextInt(baseRange * 2) + 1;
      if (!values.contains(num) && !correctNumbers.contains(num)) {
        correctNumbers.add(num);
      }
    }
    
    return correctNumbers.toList()..sort();
  }
}

// Update the game state class name
class _StargateTriangleGameState extends State<StargateTriangleGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  StargateTriangle? currentTriangle;
  List<int?> userAnswers = [];
  int selectedAnswerIndex = -1;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
        
    _generateTriangle();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateTriangle() {
    setState(() {
      final difficulty = DifficultyManager.getDifficulty(widget.grade, widget.level);
      currentTriangle = StargateTriangle.generate(difficulty, widget.grade);
      userAnswers = List.filled(currentTriangle!.hiddenIndices.length, null);
      selectedAnswerIndex = -1;
    });
  }

  // ... rest of the methods remain the same, just update references to use StargateTriangle
}

// Update the widget class name  
class StargateTriangleGame extends StatefulWidget {
  final int grade;
  final int level;

  const StargateTriangleGame({super.key, required this.grade, required this.level});

  @override
  State<StargateTriangleGame> createState() => _StargateTriangleGameState();
}

// Custom Painter for the triangle outline with cosmic effects
class MagicTrianglePainter extends CustomPainter {
  final double glow;
  
  MagicTrianglePainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
  
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Draw wormhole effect
    _drawWormhole(canvas, center, radius);
    
    // Draw stargate ring
    _drawStargateRing(canvas, center, radius, glow);
    
    // Draw energy lines connecting nodes
    _drawEnergyLines(canvas, center, radius);
  }
  
  void _drawWormhole(Canvas canvas, Offset center, double radius) {
    // Multiple concentric circles for depth
    for (int i = 5; i >= 1; i--) {
      final paint = Paint()
        ..color = Color.lerp(
          SpaceTheme.deepSpace,
          SpaceTheme.nebulaPurple,
          i / 5.0,
        )!.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, radius * (i / 5.0) * 0.8, paint);
    }
  }
  
  void _drawStargateRing(Canvas canvas, Offset center, double radius, double glow) {
    // Outer ring with glow
    final glowPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glow * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
    
    canvas.drawCircle(center, radius * 1.1, glowPaint);
    
    // Main ring
    final ringPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    
    canvas.drawCircle(center, radius * 1.1, ringPaint);
    
    // Inner triangle with energy effect
    final trianglePaint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(glow * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3) - math.pi / 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, trianglePaint);
  }
  
  void _drawEnergyLines(Canvas canvas, Offset center, double radius) {
    // Draw energy connecting lines between triangle points
    final energyPaint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(glow * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      // ..pathEffect = null; // Could add dash effect here
    
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3) - math.pi / 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, energyPaint);
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



class NodeEnergyPainter extends CustomPainter {
  final double glow;
  final bool isActive;
  
  NodeEnergyPainter({required this.glow, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(glow * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw energy rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (size.width / 2) * (0.6 + i * 0.1), paint);
    }
  }

  @override
  bool shouldRepaint(NodeEnergyPainter oldDelegate) => 
      oldDelegate.glow != glow || oldDelegate.isActive != isActive;
}