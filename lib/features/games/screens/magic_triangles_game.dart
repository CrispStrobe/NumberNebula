import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

// NOTE: Replace these with your actual project imports
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';

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
  // Core UI controllers
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // NEW Animation controllers for thematic effects
  late AnimationController _timeController; // For ambient wormhole effect
  late AnimationController _dropController; // For node activation effect
  late AnimationController _warpController; // For final success sequence
  late Animation<double> _dropAnimation;

  late AnimationController _successController;
  late Animation<double> _successAnimation;

  MagicTrianglePuzzle? currentPuzzle;
  List<int?> userAnswers = [];
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  bool _isWarping = false; // To trigger final warp animation
  int _lastPlacedNodeIndex = -1; // To trigger drop animation on the right node

  int? _draggedNumber;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    // Setup for new animations
    _timeController = AnimationController(
      duration: const Duration(seconds: 20), vsync: this
    )..repeat();
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);
    
    _warpController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
    _generatePuzzle();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _timeController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _isWarping = false;
      _warpController.reset();
      _successController.reset();
    });

    Future(() {
      final puzzle = MagicTrianglePuzzle.generate(
        grade: widget.grade,
        level: widget.level,
      );
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.filled(currentPuzzle!.hiddenIndices.length, null);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
      }
    });
  }
  
  void _placeNumber(int number, int answerIndex, int globalNodeIndex) {
    if (userAnswers[answerIndex] != null) return;

    setState(() {
      userAnswers[answerIndex] = number;
      numberPool.remove(number);
      _lastPlacedNodeIndex = globalNodeIndex;
      _dropController.forward(from: 0.0);
    });
    _checkIfComplete();
  }

  void _removeNumber(int answerIndex) {
    setState(() {
      final number = userAnswers[answerIndex];
      if (number != null) {
        userAnswers[answerIndex] = null;
        numberPool.add(number);
        numberPool.sort();
      }
    });
  }

  void _checkIfComplete() {
    if (userAnswers.every((answer) => answer != null)) {
      final result = currentPuzzle!.checkSolution(userAnswers.cast<int>());
      if (result.isValid && result.isPerfect) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    }
  }

  void _handleSuccess() {
    setState(() => _isWarping = true);
    _warpController.forward();
    
    _warpController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        int baseScore = 150 * widget.grade * widget.level;
        int bonusScore = (baseScore * (currentPuzzle!.circlesPerSide / 3.0)).round();
        context.read<GameProvider>().addScore(baseScore + bonusScore);
        
        _successController.forward(from: 0.0);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(bonusScore),
        );
      }
    });
  }

  void _handleIncorrect() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Alignment failed. The energy signature is incorrect. Try again!'),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPuzzle == null || _isGenerating) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculating wormhole coordinates...', style: SpaceTheme.bodyStyle),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: "Wormhole Activator",
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Align the Stargate! Drag resonators to match the required Warp Frequency on each side.",
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: SpaceTheme.cardDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hub, color: SpaceTheme.alienGreen, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Warp Frequency: ${currentPuzzle!.warpFrequency}',
                      style: SpaceTheme.titleStyle.copyWith(
                        color: SpaceTheme.alienGreen,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 650;
                    return isWide ? _buildWideLayout() : _buildTallLayout();
                  },
                ),
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
          Expanded(flex: 3, child: _buildTriangleArea()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildNumberPad()),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildTriangleArea(),
            const SizedBox(height: 24),
            _buildNumberPad(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTriangleArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight).clamp(250.0, 400.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_glowController, _timeController, _warpController]),
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WormholePainter(
                          glowIntensity: _glowAnimation.value,
                          time: _timeController.value,
                          warpActivation: _warpController.value,
                        ),
                      );
                    },
                  ),
                ),
                ..._buildTriangleNodes(size),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTriangleNodes(double size) {
    if (currentPuzzle == null) return [];
    
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.4;
    
    final points = currentPuzzle!.getCirclePositions(center, radius);
    List<Widget> nodes = [];
    int answerIdx = 0;
    
    final nodeSize = (size * 0.20).clamp(50.0, 80.0);
    
    for (int i = 0; i < currentPuzzle!.totalCircles; i++) {
      int? value;
      bool isHidden = currentPuzzle!.hiddenIndices.contains(i);
      int currentAnswerIndex = isHidden ? answerIdx++ : -1;

      if (isHidden) {
        value = userAnswers[currentAnswerIndex];
      } else {
        value = currentPuzzle!.visibleValues[i];
      }

      Widget node = isHidden 
          ? _buildDroppableNode(value, currentAnswerIndex, i, nodeSize)
          : _buildStargateNode(value: value, isSelected: false, isHidden: false, size: nodeSize);
      
      // Apply drop animation if this was the last placed node
      if (i == _lastPlacedNodeIndex) {
        node = ScaleTransition(
          scale: _dropAnimation,
          child: node,
        );
      }

      nodes.add(Positioned(
        left: points[i].dx - nodeSize / 2,
        top: points[i].dy - nodeSize / 2,
        child: node,
      ));
    }
    return nodes;
  }
  
  Widget _buildDroppableNode(int? value, int answerIndex, int globalNodeIndex, double size) {
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: value != null ? () => _removeNumber(answerIndex) : null,
          child: _buildStargateNode(
            value: value,
            isSelected: candidateData.isNotEmpty,
            isHidden: true,
            size: size,
          ),
        );
      },
      onWillAccept: (data) => userAnswers[answerIndex] == null && !_isWarping,
      onAccept: (data) => _placeNumber(data, answerIndex, globalNodeIndex),
    );
  }

  Widget _buildStargateNode({
    required int? value,
    required bool isSelected,
    required bool isHidden,
    double size = 70,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getNodeGradient(isHidden, isSelected),
        border: Border.all(
          color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
          width: isSelected ? 4 : 2,
        ),
        boxShadow: _getNodeShadow(isSelected),
      ),
      child: Center(
        child: Text(
          isHidden ? (value?.toString() ?? '') : value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: size * 0.4,
            color: isHidden && value == null ? Colors.transparent : Colors.white,
            shadows: [Shadow(color: SpaceTheme.starYellow, blurRadius: 10)],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Available Subspace Resonators',
          style: SpaceTheme.bodyStyle,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2)
          ),
          constraints: const BoxConstraints(maxWidth: 350),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (numberPool.length / 2).ceil().clamp(4, 6),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                onDragStarted: () => setState(() => _draggedNumber = number),
                onDragEnd: (_) => setState(() => _draggedNumber = null),
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(
                  opacity: 0.3, 
                  child: _buildResonator(number)
                ),
                child: _buildResonator(number),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResonator(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildDraggableFeedback(int number) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SpaceTheme.starGradient,
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow,
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
          ),
        ),
      ),
    );
  }
  
  // --- Dialogs and Thematic UI ---

  RadialGradient _getNodeGradient(bool isHidden, bool isSelected) {
    if (!isHidden) return const RadialGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink]);
    if (isSelected) return const RadialGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    return const RadialGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]);
  }

  List<BoxShadow> _getNodeShadow(bool isSelected) {
    return [
      BoxShadow(
        color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
        blurRadius: isSelected ? 25 : 15,
        spreadRadius: isSelected ? 5 : 2,
      ),
    ];
  }

  Widget _buildSuccessDialog(int bonusScore) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rocket_launch, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  const Text('Wormhole Stabilized!', style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    'Perfect alignment! The warp corridor is open.\nBonus: +$bonusScore points!',
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
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: const Text('Next Anomaly'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: SpaceTheme.primaryButtonStyle,
                        child: const Text('To Bridge'),
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
}

// =========================================================================
// ==           UPGRADED MAGIC TRIANGLE (WORMHOLE) PUZZLE LOGIC           ==
// =========================================================================

class MagicTrianglePuzzle {
  final int circlesPerSide;
  final int totalCircles;
  final int warpFrequency; // Renamed from magicSum
  final Set<int> hiddenIndices;
  final Map<int, int> visibleValues;
  final List<int> allNumbers;
  final List<int> numberPool; // Includes correct numbers + decoys

  MagicTrianglePuzzle({
    required this.circlesPerSide,
    required this.warpFrequency,
    required this.hiddenIndices,
    required this.visibleValues,
    required this.allNumbers,
    required this.numberPool,
  }) : totalCircles = (circlesPerSide * 3) - 3;

  static MagicTrianglePuzzle generate({required int grade, required int level}) {
    debugPrint("\n--- Generating Triangel Puzzle ---");
    int circlesPerSide = _determineCirclesPerSide(grade, level);
    final totalCircles = (circlesPerSide * 3) - 3;
    debugPrint("[Wormhole] Parameters: Grade=$grade, Level=$level -> circlesPerSide=$circlesPerSide");

    final startNumber = math.max(1, level + grade - 2);
    final allNumbers = List.generate(totalCircles, (i) => startNumber + i);
    debugPrint("[Wormhole] Core resonator values: $allNumbers");

    debugPrint("[Wormhole] Backtracking for a stable alignment...");
    final solver = _MagicTriangleSolver(circlesPerSide, allNumbers);
    final solution = solver.findSolution();

    if (solution == null) {
      debugPrint("❌ [Wormhole] FATAL: Alignment failed. This shouldn't happen.");
      return generate(grade: 1, level: 1);
    }
    
    final warpFrequency = _calculateSideSums(solution, circlesPerSide)[0];
    debugPrint("✅ [Wormhole] Stable Alignment FOUND: $solution");
    debugPrint("✨ [Wormhole] Required Warp Frequency: $warpFrequency");

    int visibleCount = _determineVisibleCount(grade, totalCircles);
    debugPrint("[Wormhole] Hiding ${totalCircles - visibleCount} nodes.");

    final allIndices = List.generate(totalCircles, (i) => i)..shuffle();
    final hiddenIndices = allIndices.sublist(0, totalCircles - visibleCount).toSet();
    
    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCircles; i++) {
      if (!hiddenIndices.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }

    // --- Generate Decoy Numbers ---
    final hiddenNumbers = allNumbers.where((n) => !visibleValues.values.contains(n)).toList();
    final decoyCount = (level / 2).floor().clamp(2, 8);
    final decoyNumbers = _generateDecoyNumbers(decoyCount, allNumbers, startNumber);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    debugPrint("[Wormhole] Added $decoyCount decoy resonators: $decoyNumbers");
    debugPrint("[Wormhole] Final number pool for user: $numberPool");

    return MagicTrianglePuzzle(
      circlesPerSide: circlesPerSide,
      warpFrequency: warpFrequency,
      hiddenIndices: hiddenIndices,
      visibleValues: visibleValues.map((k, v) => MapEntry(k, v)),
      allNumbers: allNumbers,
      numberPool: numberPool,
    );
  }

  static List<int> _generateDecoyNumbers(int count, List<int> existingNumbers, int startNumber) {
    final decoys = <int>{};
    final allExisting = Set<int>.from(existingNumbers);
    final maxRange = existingNumbers.last + count + 5;
    final random = math.Random();
    
    while (decoys.length < count) {
      final num = startNumber + random.nextInt(maxRange - startNumber);
      if (!allExisting.contains(num)) {
        decoys.add(num);
      }
    }
    return decoys.toList();
  }
  
  static int _determineCirclesPerSide(int grade, int level) {
    // Grade 6+
    if (grade >= 6) {
      if (level <= 3) return 3;
      if (level <= 7) return 4;
      return 5;
    }
    // Grade 3-5
    if (grade >= 3) {
      if (level <= 5) return 3;
      return 4;
    }
    // Grade 1-2 (Base case)
    return 3;
  }

  static int _determineVisibleCount(int grade, int totalCircles) {
    double ratio = 1.0 - (grade * 0.05 + totalCircles * 0.05);
    return (totalCircles * ratio).round().clamp(1, totalCircles - 3);
  }

  SolutionResult checkSolution(List<int> userAnswers) {
    final completeArrangement = List<int>.filled(totalCircles, 0);
    int hiddenIdx = 0;
    for (int i = 0; i < totalCircles; i++) {
      if (hiddenIndices.contains(i)) {
        completeArrangement[i] = userAnswers[hiddenIdx++];
      } else {
        completeArrangement[i] = visibleValues[i]!;
      }
    }
    
    final usedHidden = Set.from(userAnswers);
    final correctHidden = allNumbers.where((n) => !visibleValues.values.contains(n));
    if(usedHidden.length != correctHidden.length || !usedHidden.containsAll(correctHidden)) {
        return SolutionResult(isValid: false, isPerfect: false);
    }

    final sideSums = _calculateSideSums(completeArrangement, circlesPerSide);
    final isPerfect = sideSums.every((sum) => sum == warpFrequency);
    return SolutionResult(isValid: true, isPerfect: isPerfect);
  }
  
  // Static helpers for geometry and calculations (unchanged from previous fix)
  static List<int> _getSideIndices(int side, int circlesPerSide) {
    final n = circlesPerSide;
    switch (side) {
      case 0: return List.generate(n, (i) => i);
      case 1: return [n - 1, ...List.generate(n - 1, (i) => n + i)];
      case 2: return [2 * n - 2, ...List.generate(n - 2, (i) => 2 * n - 1 + i), 0];
      default: return [];
    }
  }

  static List<int> _calculateSideSums(List<int> arrangement, int circlesPerSide) {
    final sums = <int>[];
    for (int side = 0; side < 3; side++) {
      final indices = _getSideIndices(side, circlesPerSide);
      sums.add(indices.fold(0, (acc, index) => acc + arrangement[index]));
    }
    return sums;
  }
  
  List<Offset> getCirclePositions(Offset center, double radius) {
    // ... (This method is unchanged and correct)
    final points = <Offset>[];
    final n = circlesPerSide;

    final cornerAngles = [ -math.pi / 2, math.pi / 6, 5 * math.pi / 6 ];
    final cornerPoints = [
      center + Offset(math.cos(cornerAngles[0]), math.sin(cornerAngles[0])) * radius,
      center + Offset(math.cos(cornerAngles[1]), math.sin(cornerAngles[1])) * radius,
      center + Offset(math.cos(cornerAngles[2]), math.sin(cornerAngles[2])) * radius,
    ];

    for (int i = 0; i < n; i++) points.add(Offset.lerp(cornerPoints[0], cornerPoints[1], i / (n - 1))!);
    for (int i = 1; i < n; i++) points.add(Offset.lerp(cornerPoints[1], cornerPoints[2], i / (n - 1))!);
    for (int i = 1; i < n - 1; i++) points.add(Offset.lerp(cornerPoints[2], cornerPoints[0], i / (n - 1))!);
    return points;
  }
}

// Backtracking solver (unchanged from previous fix)
class _MagicTriangleSolver {
  // ... (This class is unchanged and correct)
  final int circlesPerSide;
  final List<int> numbersToUse;
  final int totalCircles;
  late List<int> _arrangement;
  late List<bool> _usedFlags;

  _MagicTriangleSolver(this.circlesPerSide, this.numbersToUse)
      : totalCircles = (circlesPerSide * 3) - 3 {
    _arrangement = List.filled(totalCircles, 0);
    _usedFlags = List.filled(numbersToUse.length, false);
    numbersToUse.shuffle();
  }

  List<int>? findSolution() => _solve(0, -1) ? _arrangement : null;

  bool _solve(int k, int targetSum) {
    if (k == totalCircles) return true;
    for (int i = 0; i < numbersToUse.length; i++) {
      if (!_usedFlags[i]) {
        _arrangement[k] = numbersToUse[i];
        _usedFlags[i] = true;
        bool passesPruning = true;
        int nextTargetSum = targetSum;
        if (k == circlesPerSide - 1) {
          nextTargetSum = MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[0];
        } else if (k == 2 * circlesPerSide - 2) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[1] != targetSum) passesPruning = false;
        } else if (k == totalCircles - 1) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[2] != targetSum) passesPruning = false;
        }
        if (passesPruning && _solve(k + 1, nextTargetSum)) return true;
        _usedFlags[i] = false;
      }
    }
    return false;
  }
}

class SolutionResult {
  final bool isValid;
  final bool isPerfect;
  SolutionResult({required this.isValid, required this.isPerfect});
}

// --- Thematic Custom Painter ---
class WormholePainter extends CustomPainter {
  final double glowIntensity;
  final double time; // Value from 0.0 to 1.0 for ambient animation
  final double warpActivation; // Value from 0.0 to 1.0 for success animation

  WormholePainter({
    required this.glowIntensity,
    required this.time,
    required this.warpActivation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // 1. Draw the swirling wormhole vortex
    final wormholePaint = Paint()
      ..shader = RadialGradient(
        colors: const [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        stops: const [0.0, 0.8],
        transform: GradientRotation(time * 2 * math.pi), // Use time for rotation
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.2, wormholePaint);
    
    // 2. Draw shimmering stars inside the wormhole
    final starPaint = Paint()..color = Colors.white.withOpacity(0.5);
    for (int i = 0; i < 30; i++) {
      final starRadius = (math.sin(time * 2 * math.pi + i * 0.5) + 1) / 2 * 1.5;
      final angle = (i * 1.375) + (time * 0.5);
      final distance = math.sqrt(i / 30) * radius;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * distance, math.sin(angle) * distance),
        starRadius,
        starPaint,
      );
    }

    // 3. Draw the triangular stargate frame
    final path = Path();
    final cornerPoints = <Offset>[];
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3) - math.pi / 2;
      final point = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      cornerPoints.add(point);
      if (i == 0) path.moveTo(point.dx, point.dy);
      else path.lineTo(point.dx, point.dy);
    }
    path.close();

    final energyPaint = Paint()
      ..color = SpaceTheme.alienGreen.withOpacity(glowIntensity * 0.6)
      ..style = PaintingStyle.stroke..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, energyPaint);
    
    final framePaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(0.8)
      ..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, framePaint);
    
    // 4. Draw the final warp activation sequence
    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = Colors.white.withOpacity(Curves.easeOut.transform(warpActivation))
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final point in cornerPoints) {
        // Draw beams from corners to a converging center point
        final convergencePoint = Offset.lerp(point, center, Curves.easeIn.transform(warpActivation))!;
        canvas.drawLine(point, convergencePoint, warpPaint);
      }
    }
  }

  @override
  bool shouldRepaint(WormholePainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.time != time ||
      oldDelegate.warpActivation != warpActivation;
}