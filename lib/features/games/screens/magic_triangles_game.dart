import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

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
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _timeController;
  late AnimationController _dropController;
  late AnimationController _warpController;
  late Animation<double> _dropAnimation;

  final GlobalKey _triangleAreaKey = GlobalKey();

  MagicTrianglePuzzle? currentPuzzle;
  List<int?> userAnswers = [];
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  bool _isWarping = false;
  int _lastPlacedNodeIndex = -1;
  bool _isDraggingOver = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 [UI] MagicTrianglesGame.initState() - Starting initialization");
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
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
    
    debugPrint("🚀 [UI] Animation controllers initialized, calling _generatePuzzle()");
    _generatePuzzle();
  }

  @override
  void dispose() {
    debugPrint("🚀 [UI] MagicTrianglesGame.dispose() - Cleaning up controllers");
    
    // Stop all animations before disposing
    _glowController.stop();
    _successController.stop();
    _timeController.stop();
    _dropController.stop();
    _warpController.stop();
    
    // Remove any listeners
    _warpController.clearListeners();
    
    // Dispose controllers
    _glowController.dispose();
    _successController.dispose();
    _timeController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    
    // Clear puzzle data
    currentPuzzle = null;
    userAnswers.clear();
    numberPool.clear();
    
    debugPrint("🚀 [UI] All controllers disposed and data cleared");
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("🚀 [UI] _generatePuzzle() - Starting puzzle generation");
    debugPrint("🚀 [UI] Current mounted state: $mounted");
    
    setState(() {
      _isGenerating = true;
      _isWarping = false;
      _warpController.reset();
      _successController.reset();
    });
    debugPrint("🚀 [UI] State set to generating, calling compute()");

    try {
      final puzzle = await compute(MagicTrianglePuzzle.generate, {
        'grade': widget.grade,
        'level': widget.level,
      });
      
      debugPrint("🚀 [UI] compute() completed successfully");
      debugPrint("🚀 [UI] Puzzle details: hiddenIndices=${puzzle.hiddenIndices}, numberPool=${puzzle.numberPool}");
      debugPrint("🚀 [UI] mounted state after compute: $mounted");
      
      if (mounted) {
        debugPrint("🚀 [UI] Widget still mounted, updating state");
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.generate(currentPuzzle!.hiddenIndices.length, (_) => null, growable: true);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
        debugPrint("🚀 [UI] State updated successfully");
        debugPrint("🚀 [UI] userAnswers length: ${userAnswers.length}");
        debugPrint("🚀 [UI] numberPool length: ${numberPool.length}");
        debugPrint("🚀 [UI] hiddenIndices: ${currentPuzzle!.hiddenIndices}");
        debugPrint("🚀 [UI] visibleValues: ${currentPuzzle!.visibleValues}");
      } else {
        debugPrint("❌ [UI] Widget not mounted after compute, skipping state update");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [UI] Error in _generatePuzzle: $e");
      debugPrint("❌ [UI] StackTrace: $stackTrace");
    }
    
    debugPrint("🚀 [UI] _generatePuzzle() completed");
  }
  
  void _placeNumber(int number, int answerIndex, int globalNodeIndex) {
    debugPrint("🎯 [UI] _placeNumber($number, $answerIndex, $globalNodeIndex)");
    if (userAnswers[answerIndex] != null) {
      debugPrint("🎯 [UI] Position already filled, ignoring");
      return;
    }

    setState(() {
      userAnswers[answerIndex] = number;
      numberPool.remove(number);
      _lastPlacedNodeIndex = globalNodeIndex;
      _dropController.forward(from: 0.0);
    });
    debugPrint("🎯 [UI] Number placed successfully, checking completion");
    _checkIfComplete();
  }

  void _removeNumber(int answerIndex) {
    debugPrint("🗑️ [UI] _removeNumber($answerIndex)");
    setState(() {
      final number = userAnswers[answerIndex];
      if (number != null) {
        userAnswers[answerIndex] = null;
        numberPool.add(number);
        numberPool.sort();
      }
    });
    debugPrint("🗑️ [UI] Number removed, numberPool: $numberPool");
  }

  void _checkIfComplete() {
    debugPrint("✅ [UI] _checkIfComplete() - userAnswers: $userAnswers");
    if (userAnswers.every((answer) => answer != null)) {
      debugPrint("✅ [UI] All answers filled, checking solution");
      final result = currentPuzzle!.checkSolution(userAnswers.cast<int>());
      debugPrint("✅ [UI] Solution check result: isValid=${result.isValid}, isPerfect=${result.isPerfect}");
      if (result.isValid && result.isPerfect) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    } else {
      debugPrint("✅ [UI] Not all answers filled yet");
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [UI] _handleSuccess() - Starting success animation");
    setState(() => _isWarping = true);
    _warpController.forward();

    // Define a listener function that can be removed.
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        debugPrint("🎉 [UI] Warp animation completed, calculating score");
        
        // IMPORTANT: Remove the listener immediately to prevent it from firing again.
        _warpController.removeStatusListener(listener);

        int baseScore = 150 * widget.grade;
        int bonusScore = (baseScore * (currentPuzzle!.circlesPerSide / 3.0)).round();
        context.read<GameProvider>().addScore(baseScore + bonusScore);
        _successController.forward(from: 0.0);
        
        if (mounted) { // Always check if the widget is still in the tree before showing a dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessDialog(bonusScore),
          );
        }
      }
    }

    // Add the listener.
    _warpController.addStatusListener(listener);
  }

  void _handleIncorrect() {
    debugPrint("❌ [UI] _handleIncorrect() - Showing failure message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.magicTrianglesFail),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🏗️ [UI] build() called - _isGenerating: $_isGenerating, currentPuzzle: ${currentPuzzle != null}");
    
    if (currentPuzzle == null || _isGenerating) {
      debugPrint("🏗️ [UI] Showing loading screen");
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(S.of(context)!.calculatingCoordinates, style: SpaceTheme.bodyStyle),
            ],
          ),
        ),
      );
    }

    debugPrint("🏗️ [UI] Building main game UI");
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(title: S.of(context)!.magicTrianglesGameTitle, level: widget.level, onBack: () => Navigator.of(context).pop()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  S.of(context)!.magicTrianglesInstructions,
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,
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
                      S.of(context)!.magicTrianglesWarpFrequency(currentPuzzle!.warpFrequency),
                      style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.alienGreen, fontSize: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    debugPrint("🏗️ [UI] LayoutBuilder constraints: ${constraints.maxWidth}x${constraints.maxHeight}");
                    bool isWide = constraints.maxWidth > 650;
                    debugPrint("🏗️ [UI] Using ${isWide ? 'wide' : 'tall'} layout");
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
    debugPrint("🏗️ [UI] _buildWideLayout()");
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
    debugPrint("🏗️ [UI] _buildTallLayout()");
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
    debugPrint("🔺 [UI] _buildTriangleArea() - Starting triangle build");
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint("🔺 [UI] Triangle LayoutBuilder constraints: ${constraints.maxWidth}x${constraints.maxHeight}");
        final size = math.min(constraints.maxWidth, constraints.maxHeight).clamp(250.0, 450.0);
        final center = Offset(size / 2, size / 2);
        final radius = size * 0.4;
        debugPrint("🔺 [UI] Triangle parameters: size=$size, center=$center, radius=$radius");
        
        final nodePoints = currentPuzzle!.getCirclePositions(center, radius);
        debugPrint("🔺 [UI] Generated ${nodePoints.length} node points");

        return Center(
          child: DragTarget<int>(
            key: _triangleAreaKey,
            builder: (context, candidateData, rejectedData) {
              debugPrint("🔺 [UI] DragTarget builder called");
              return SizedBox(
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
                    ..._buildTriangleNodes(size, nodePoints),
                  ],
                ),
              );
            },
            onWillAccept: (data) {
              debugPrint("🎯 [UI] DragTarget.onWillAccept: $data");
              setState(() => _isDraggingOver = true);
              return true;
            },
            onLeave: (data) {
              debugPrint("🎯 [UI] DragTarget.onLeave: $data");
              setState(() => _isDraggingOver = false);
            },
            onAcceptWithDetails: (details) {
              debugPrint("🎯 [UI] DragTarget.onAcceptWithDetails: ${details.data} at ${details.offset}");
              setState(() => _isDraggingOver = false);
              
              final RenderBox? renderBox = _triangleAreaKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) {
                debugPrint("❌ [UI] Could not find triangle area render box");
                return;
              }
              
              final localDropPosition = renderBox.globalToLocal(details.offset);
              final droppedNumber = details.data;
              debugPrint("🎯 [UI] Global drop position: ${details.offset}");
              debugPrint("🎯 [UI] Local drop position: $localDropPosition");
              debugPrint("🎯 [UI] Triangle size: $size, center: $center");

              int? closestGlobalIndex = _findClosestEmptyNode(localDropPosition, nodePoints, size);
              debugPrint("🎯 [UI] Closest empty node: $closestGlobalIndex");

              if (closestGlobalIndex != null) {
                  final answerIndex = currentPuzzle!.getAnswerIndex(closestGlobalIndex);
                  debugPrint("🎯 [UI] Answer index: $answerIndex");
                  _placeNumber(droppedNumber, answerIndex, closestGlobalIndex);
              } else {
                  debugPrint("🎯 [UI] No valid drop target found");
              }
            },
          ),
        );
      },
    );
  }

  int? _findClosestEmptyNode(Offset dropPosition, List<Offset> nodePoints, double triangleSize) {
      debugPrint("🔍 [UI] _findClosestEmptyNode at $dropPosition");
      debugPrint("🔍 [UI] Triangle size: $triangleSize");
      
      double minDistance = double.infinity;
      int? targetNodeIndex;
      
      int answerIdx = 0;
      for (int i = 0; i < currentPuzzle!.totalCircles; i++) {
        if (currentPuzzle!.hiddenIndices.contains(i)) {
          if (userAnswers[answerIdx] == null) {
            final nodeCenter = nodePoints[i];
            final distance = (dropPosition - nodeCenter).distance;
            debugPrint("🔍 [UI] Node $i at $nodeCenter, distance: $distance, isEmpty: ${userAnswers[answerIdx] == null}");

            if (distance < minDistance) {
              minDistance = distance;
              targetNodeIndex = i;
            }
          } else {
            debugPrint("🔍 [UI] Node $i already filled with: ${userAnswers[answerIdx]}");
          }
          answerIdx++;
        }
      }
      
      debugPrint("🔍 [UI] Minimum distance: $minDistance, target: $targetNodeIndex");
      
      final dropRadius = (triangleSize * 0.15).clamp(60.0, 120.0);
      debugPrint("🔍 [UI] Using drop radius: $dropRadius");
      
      if (minDistance < dropRadius) {
        debugPrint("✅ [UI] Drop accepted for node $targetNodeIndex");
        return targetNodeIndex;
      }
      
      debugPrint("❌ [UI] Drop rejected - distance $minDistance > radius $dropRadius");
      return null;
  }
  
  List<Widget> _buildTriangleNodes(double size, List<Offset> points) {
    debugPrint("🔵 [UI] _buildTriangleNodes - size: $size, points: ${points.length}");
    if (currentPuzzle == null) {
      debugPrint("❌ [UI] currentPuzzle is null!");
      return [];
    }
    
    List<Widget> nodes = [];
    int answerIdx = 0;
    
    final nodeSize = (size * 0.18).clamp(45.0, 75.0);
    debugPrint("🔵 [UI] Node size: $nodeSize");
    
    for (int i = 0; i < currentPuzzle!.totalCircles; i++) {
      debugPrint("🔵 [UI] Building node $i at position ${points[i]}");
      int? value;
      bool isHidden = currentPuzzle!.hiddenIndices.contains(i);
      int currentAnswerIndex = isHidden ? answerIdx++ : -1;
      debugPrint("🔵 [UI] Node $i: isHidden=$isHidden, answerIdx=$currentAnswerIndex");

      if (isHidden) {
        if (currentAnswerIndex < userAnswers.length) {
          value = userAnswers[currentAnswerIndex];
          debugPrint("🔵 [UI] Hidden node $i value: $value");
        } else {
          debugPrint("❌ [UI] ERROR: currentAnswerIndex $currentAnswerIndex >= userAnswers.length ${userAnswers.length}");
          value = null;
        }
      } else {
        value = currentPuzzle!.visibleValues[i];
        debugPrint("🔵 [UI] Visible node $i value: $value");
      }

      Widget node = isHidden 
          ? _buildDroppableNode(value, currentAnswerIndex, nodeSize)
          : _buildStargateNode(value: value, isSelected: false, isHidden: false, size: nodeSize);
      
      if (i == _lastPlacedNodeIndex) {
        node = ScaleTransition(scale: _dropAnimation, child: node);
      }

      final nodePosition = Positioned(
        left: points[i].dx - nodeSize / 2,
        top: points[i].dy - nodeSize / 2,
        child: node,
      );
      
      nodes.add(nodePosition);
      debugPrint("🔵 [UI] Node $i positioned at (${points[i].dx - nodeSize / 2}, ${points[i].dy - nodeSize / 2})");
    }
    debugPrint("🔵 [UI] Built ${nodes.length} triangle nodes");
    return nodes;
  }
  
  Widget _buildDroppableNode(int? value, int answerIndex, double size) {
    debugPrint("🎯 [UI] _buildDroppableNode - value: $value, answerIndex: $answerIndex");
    return GestureDetector(
      onTap: value != null ? () => _removeNumber(answerIndex) : null,
      child: _buildStargateNode(
        value: value,
        isSelected: _isDraggingOver && value == null,
        isHidden: true,
        size: size,
      ),
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
            fontSize: size * 0.35,
            color: isHidden && value == null ? Colors.transparent : Colors.white,
            shadows: const [Shadow(color: SpaceTheme.starYellow, blurRadius: 10)],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    debugPrint("🔢 [UI] _buildNumberPad - numberPool: $numberPool (length: ${numberPool.length})");
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.of(context)!.magicTrianglesResonators, style: SpaceTheme.bodyStyle),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: SpaceTheme.cardDecoration.copyWith(border: Border.all(color: SpaceTheme.nebulaPurple, width: 2)),
          constraints: const BoxConstraints(maxWidth: 350),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              if (index >= numberPool.length) {
                return Container(); 
              }
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildResonator(number)),
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
      child: Center(child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18))),
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
          boxShadow: const [BoxShadow(color: SpaceTheme.starYellow, blurRadius: 20, spreadRadius: 5)],
        ),
        child: Center(child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22))),
      ),
    );
  }
  
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
                  Text(S.of(context)!.magicTrianglesWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.magicTrianglesWinDesc(bonusScore),
                    style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,
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
                        child: Text(S.of(context)!.nextAnomaly),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                          Navigator.of(context).pop(); // Close the game screen
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
}

class MagicTrianglePuzzle {
  final int circlesPerSide;
  final int totalCircles;
  final int warpFrequency;
  final Set<int> hiddenIndices;
  final Map<int, int> visibleValues;
  final List<int> allNumbers;
  final List<int> numberPool;

  MagicTrianglePuzzle({
    required this.circlesPerSide,
    required this.warpFrequency,
    required this.hiddenIndices,
    required this.visibleValues,
    required this.allNumbers,
    required this.numberPool,
  }) : totalCircles = (circlesPerSide * 3) - 3;

  int getAnswerIndex(int globalIndex) {
    debugPrint("🔍 [Puzzle] getAnswerIndex($globalIndex)");
    int answerIndex = 0;
    for (int i=0; i < totalCircles; i++) {
        if (hiddenIndices.contains(i)) {
            if (i == globalIndex) {
              debugPrint("🔍 [Puzzle] Found globalIndex $globalIndex at answerIndex $answerIndex");
              return answerIndex;
            }
            answerIndex++;
        }
    }
    debugPrint("❌ [Puzzle] globalIndex $globalIndex not found in hiddenIndices");
    return -1;
  }

  static MagicTrianglePuzzle generate(Map<String, int> args) {
    final grade = args['grade']!; // 1-4 (school years 3-6)
    final level = args['level']!; // 1-20

    debugPrint("\n--- Generating Enhanced Triangle Puzzle ---");
    int circlesPerSide = _determineCirclesPerSide(grade, level);
    final totalCircles = (circlesPerSide * 3) - 3;
    debugPrint("[Wormhole] Parameters: Grade=$grade, Level=$level -> circlesPerSide=$circlesPerSide");

    final stopwatch = Stopwatch()..start();
    List<int>? solution;
    List<int> allNumbers = []; 
    
    int attempts = 0;
    while (solution == null && attempts < 15) {
      if (attempts > 0) debugPrint("... Retrying puzzle generation (attempt ${attempts + 1}) ...");
      
      allNumbers = _generateNumberSet(grade, level, totalCircles, attempts);
      debugPrint("[Wormhole] Enhanced resonator values: $allNumbers");

      debugPrint("[Wormhole] Backtracking for a stable alignment...");
      final solver = _MagicTriangleSolver(circlesPerSide, allNumbers);
      solution = solver.findSolution();
      attempts++;
    }
    stopwatch.stop();

    if (solution == null) {
      debugPrint("❌ [Wormhole] FATAL: Solver failed after multiple attempts. Defaulting to an easier puzzle.");
      return generate({'grade': 1, 'level': 1});
    }
    
    debugPrint("✅ [Wormhole] Stable Alignment FOUND in ${stopwatch.elapsedMilliseconds}ms: $solution");
    final warpFrequency = _calculateSideSums(solution, circlesPerSide)[0];
    debugPrint("✨ [Wormhole] Required Warp Frequency: $warpFrequency");

    int visibleCount = _determineVisibleCount(grade, level, totalCircles);
    debugPrint("[Wormhole] Total circles: $totalCircles, Visible: $visibleCount, Hidden: ${totalCircles - visibleCount}");
    final allIndices = List.generate(totalCircles, (i) => i)..shuffle();
    final hiddenIndices = allIndices.sublist(0, totalCircles - visibleCount).toSet();
    debugPrint("[Wormhole] Hidden indices: $hiddenIndices");
    
    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCircles; i++) {
      if (!hiddenIndices.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }
    debugPrint("[Wormhole] Visible values: $visibleValues");

    final hiddenNumbers = allNumbers.where((n) => !visibleValues.values.contains(n)).toList();
    debugPrint("[Wormhole] Hidden numbers: $hiddenNumbers");
    
    final decoyCount = _calculateDecoyCount(grade, level, hiddenNumbers.length);
    final decoyNumbers = _generateEnhancedDecoys(grade, level, decoyCount, allNumbers, hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    debugPrint("[Wormhole] Added $decoyCount enhanced decoy resonators: $decoyNumbers");
    debugPrint("[Wormhole] Final number pool for user: $numberPool");

    final puzzle = MagicTrianglePuzzle(
      circlesPerSide: circlesPerSide,
      warpFrequency: warpFrequency,
      hiddenIndices: hiddenIndices,
      visibleValues: visibleValues,
      allNumbers: allNumbers,
      numberPool: numberPool,
    );
    
    debugPrint("[Wormhole] ✅ Enhanced puzzle generation complete - returning puzzle");
    return puzzle;
  }

  // Proper scaling for grades 1-4 and levels 1-20
  static int _determineCirclesPerSide(int grade, int level) {
    final totalDifficulty = grade + (level / 5.0); // Grades 1-4, Levels 1-20
    
    debugPrint("[Difficulty] Grade=$grade, Level=$level, TotalDifficulty=$totalDifficulty");
    
    if (totalDifficulty <= 2.0) return 3;  // Grade 1, Level 1-5
    if (totalDifficulty <= 3.5) return 4;  // Grade 1-2, Level 6-20 or Grade 3, Level 1-2
    if (totalDifficulty <= 5.0) return 5;  // Grade 3-4, Level 3-10
    if (totalDifficulty <= 6.5) return 6;  // Grade 4, Level 11-20
    return 7; // Grade 4, Level 15-20 only
  }

  // Visibility reduction based on proper 1-4 grade system
  static int _determineVisibleCount(int grade, int level, int totalCircles) {
    final difficulty = grade + (level / 5.0);
    
    // Start with 80% visibility and reduce based on difficulty
    double visibilityRatio = 0.80 - (difficulty * 0.06); // More gradual than before
    
    // Additional level-based reduction
    visibilityRatio -= (level - 1) * 0.01;
    
    // Clamp to reasonable bounds for grades 1-4
    visibilityRatio = visibilityRatio.clamp(0.25, 0.80); // Min 25% visible
    
    final int minVisible = math.max(3, (totalCircles / 5).ceil());
    final int maxVisible = (totalCircles * 0.75).floor();
    
    final calculatedVisible = (totalCircles * visibilityRatio).round();
    
    debugPrint("[Enhanced Difficulty] Grade $grade, Level $level, Total Circles $totalCircles");
    debugPrint("[Enhanced Difficulty] Visibility Ratio: ${visibilityRatio.toStringAsFixed(2)} -> Calculated: $calculatedVisible nodes");
    debugPrint("[Enhanced Difficulty] Clamping between Min: $minVisible and Max: $maxVisible");

    return calculatedVisible.clamp(minVisible, maxVisible);
  }

  // Number generation suitable for grades 1-4
  static List<int> _generateNumberSet(int grade, int level, int totalCircles, int attempt) {
    final random = math.Random();
    final difficulty = grade + (level / 5.0);
    
    if (difficulty < 2.5) {
      // Easy: Sequential numbers (Grade 1, early levels)
      final baseStart = math.max(1, level + attempt * 2);
      return List.generate(totalCircles, (i) => baseStart + i);
    } else if (difficulty < 4.0) {
      // Medium: Sequential with small gaps (Grade 2-3)
      final baseStart = math.max(1, level + grade + attempt * 3);
      final numbers = <int>[];
      int current = baseStart;
      for (int i = 0; i < totalCircles; i++) {
        numbers.add(current);
        current += (random.nextBool() && i > 1) ? random.nextInt(2) + 1 : 1;
      }
      return numbers;
    } else if (difficulty < 5.5) {
      // Hard: Larger ranges (Grade 3-4, higher levels)
      final baseStart = level * 2 + grade * 3 + attempt * 4;
      final range = 10 + level;
      final numbers = <int>[];
      final used = <int>{};
      
      while (numbers.length < totalCircles) {
        final num = baseStart + random.nextInt(range);
        if (!used.contains(num)) {
          used.add(num);
          numbers.add(num);
        }
      }
      numbers.sort();
      return numbers;
    } else {
      // Expert: Complex patterns (Grade 4, Level 15-20)
      final baseStart = level * 3 + grade * 4 + attempt * 6;
      final range = 20 + level;
      final numbers = <int>[];
      final used = <int>{};
      
      while (numbers.length < totalCircles) {
        final num = baseStart + random.nextInt(range);
        if (!used.contains(num)) {
          used.add(num);
          numbers.add(num);
        }
      }
      
      numbers.sort();
      return numbers;
    }
  }

  // Decoy count appropriate for grades 1-4
  static int _calculateDecoyCount(int grade, int level, int hiddenCount) {
    final baseDifficulty = grade + (level / 5.0);
    final baseDecoys = 2 + (level / 4).floor();
    final gradeMultiplier = (grade >= 3) ? 1.3 : 1.0;
    
    final totalDecoys = (baseDecoys * gradeMultiplier).round();
    
    final minDecoys = math.max(2, hiddenCount ~/ 3);
    final maxDecoys = hiddenCount + 5;
    
    return totalDecoys.clamp(minDecoys, maxDecoys);
  }

  // FIXED: Proper variable initialization for decoy generation
  static List<int> _generateEnhancedDecoys(int grade, int level, int count, 
                                         List<int> correctNumbers, List<int> hiddenNumbers) {
    debugPrint("[Enhanced Decoys] Generating $count decoy numbers");
    final decoys = <int>{};
    final allCorrect = Set<int>.from(correctNumbers);
    final random = math.Random();
    final difficulty = grade + (level / 5.0);
    
    final minCorrect = correctNumbers.isNotEmpty ? correctNumbers.first : 1;
    final maxCorrect = correctNumbers.isNotEmpty ? correctNumbers.last : 10;
    final range = maxCorrect - minCorrect;
    
    while (decoys.length < count) {
      int decoy = 1; // FIXED: Initialize the variable
      
      if (difficulty < 2.5) {
        // Easy: Close to correct numbers
        final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
        decoy = baseNum + random.nextInt(6) - 3;
      } else if (difficulty < 4.0) {
        // Medium: Mix of close and distant numbers
        if (random.nextBool()) {
          final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
          decoy = baseNum + random.nextInt(8) - 4;
        } else {
          decoy = minCorrect + random.nextInt(range + 8);
        }
      } else if (difficulty < 5.5) {
        // Hard: Strategic placement to confuse
        final strategy = random.nextInt(3);
        switch (strategy) {
          case 0:
            final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
            decoy = baseNum + [1, -1, 2, -2][random.nextInt(4)];
            break;
          case 1:
            decoy = minCorrect - 3 + random.nextInt(range + 12);
            break;
          case 2:
            decoy = maxCorrect + random.nextInt(8) + 1;
            break;
        }
      } else {
        // Expert: Very tricky decoys
        final strategy = random.nextInt(4);
        switch (strategy) {
          case 0:
            final baseNum = correctNumbers[random.nextInt(correctNumbers.length)];
            decoy = baseNum + [-1, 1][random.nextInt(2)];
            break;
          case 1:
            decoy = minCorrect + random.nextInt(range + 10);
            break;
          case 2:
            decoy = maxCorrect + random.nextInt(12) + 2;
            break;
          case 3:
            decoy = math.max(1, minCorrect - random.nextInt(6) - 1);
            break;
        }
      }
      
      // Ensure positive and unique
      if (decoy > 0 && !allCorrect.contains(decoy) && !decoys.contains(decoy)) {
        decoys.add(decoy);
      }
    }
    
    final result = decoys.toList();
    debugPrint("[Enhanced Decoys] Generated: $result");
    return result;
  }
  
  SolutionResult checkSolution(List<int> userAnswers) {
    debugPrint("✅ [Puzzle] checkSolution: $userAnswers");
    final completeArrangement = List<int>.filled(totalCircles, 0);
    int hiddenIdx = 0;
    for (int i = 0; i < totalCircles; i++) {
      if (hiddenIndices.contains(i)) {
        completeArrangement[i] = userAnswers[hiddenIdx++];
      } else {
        completeArrangement[i] = visibleValues[i]!;
      }
    }
    debugPrint("✅ [Puzzle] Complete arrangement: $completeArrangement");
    
    final usedHidden = Set.from(userAnswers);
    final correctHidden = allNumbers.where((n) => !visibleValues.values.contains(n));
    debugPrint("✅ [Puzzle] Used hidden: $usedHidden, Correct hidden: $correctHidden");
    if(usedHidden.length != correctHidden.length || !usedHidden.containsAll(correctHidden)) {
        debugPrint("❌ [Puzzle] Wrong numbers used");
        return SolutionResult(isValid: false, isPerfect: false);
    }

    final sideSums = _calculateSideSums(completeArrangement, circlesPerSide);
    debugPrint("✅ [Puzzle] Side sums: $sideSums, Target: $warpFrequency");
    final isPerfect = sideSums.every((sum) => sum == warpFrequency);
    debugPrint("✅ [Puzzle] Solution result: isPerfect=$isPerfect");
    return SolutionResult(isValid: true, isPerfect: isPerfect);
  }
  
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
    debugPrint("🔺 [Puzzle] getCirclePositions - center: $center, radius: $radius");
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
    
    debugPrint("🔺 [Puzzle] Generated ${points.length} circle positions");
    return points;
  }
}

class _MagicTriangleSolver {
  final int circlesPerSide;
  final List<int> numbersToUse;
  final int totalCircles;
  late List<int> _arrangement;
  late List<bool> _usedFlags;
  int _iterations = 0;
  late int _maxIterations;

  _MagicTriangleSolver(this.circlesPerSide, this.numbersToUse)
      : totalCircles = (circlesPerSide * 3) - 3 {
    _arrangement = List.filled(totalCircles, 0);
    _usedFlags = List.filled(numbersToUse.length, false);
    
    _maxIterations = _calculateMaxIterations();
    numbersToUse.shuffle(); // Simple shuffle is sufficient
    
    debugPrint("[Enhanced Solver] Initialized with $totalCircles circles, numbers: $numbersToUse");
    debugPrint("[Enhanced Solver] Max iterations: $_maxIterations");
  }

  int _calculateMaxIterations() {
    final baseIterations = 100000;
    final complexityFactor = math.pow(circlesPerSide, 2.0).toInt();
    return baseIterations * complexityFactor;
  }

  List<int>? findSolution() {
    debugPrint("[Enhanced Solver] Starting enhanced backtracking algorithm");
    _iterations = 0;
    
    if (_solve(0, -1)) {
        debugPrint("[Enhanced Solver] Solution found after $_iterations iterations.");
        return _arrangement;
    } else {
        debugPrint("[Enhanced Solver] FAILED to find a solution after $_iterations iterations (limit: $_maxIterations).");
        return null;
    }
  }

  bool _solve(int k, int targetSum) {
    _iterations++;
    if (_iterations > _maxIterations) {
      debugPrint("[Enhanced Solver] Max iterations reached, giving up");
      return false;
    }
    
    if (_iterations % 50000 == 0) {
      debugPrint("[Enhanced Solver] Progress: $_iterations iterations, position $k/$totalCircles");
    }
    
    if (k == totalCircles) {
      debugPrint("[Enhanced Solver] All positions filled, solution found!");
      return true;
    }

    for (int i = 0; i < numbersToUse.length; i++) {
      if (!_usedFlags[i]) {
        _arrangement[k] = numbersToUse[i];
        _usedFlags[i] = true;
        
        bool passesPruning = true;
        int nextTargetSum = targetSum;

        if (k == circlesPerSide - 1) {
          nextTargetSum = MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[0];
          if (nextTargetSum < 10 || nextTargetSum > 300) passesPruning = false;
        } else if (k == 2 * circlesPerSide - 2) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[1] != targetSum) {
            passesPruning = false;
          }
        } else if (k == totalCircles - 1) {
          if (MagicTrianglePuzzle._calculateSideSums(_arrangement, circlesPerSide)[2] != targetSum) {
            passesPruning = false;
          }
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

class WormholePainter extends CustomPainter {
  final double glowIntensity;
  final double time;
  final double warpActivation;

  const WormholePainter({
    required this.glowIntensity,
    required this.time,
    required this.warpActivation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final wormholePaint = Paint()
      ..shader = RadialGradient(
        colors: const [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
        stops: const [0.0, 0.8],
        transform: GradientRotation(time * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.2, wormholePaint);
    
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
    
    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = Colors.white.withOpacity(Curves.easeOut.transform(warpActivation))
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final point in cornerPoints) {
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