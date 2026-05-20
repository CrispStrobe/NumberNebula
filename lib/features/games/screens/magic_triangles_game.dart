// ignore_for_file: unused_element, unused_field
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../services/magic_triangle_puzzle.dart';
import '../widgets/magic_triangle_painters.dart';
import '../widgets/space_background.dart';
import '../../../shared/widgets/onboarding_overlay.dart';

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

    OnboardingOverlay.maybeShow(
      context,
      gameKey: 'magic_triangles',
      title: 'Magic Triangles',
      steps: const [
        OnboardingStep(
          icon: Icons.touch_app,
          body: 'Drag numbers from the pool onto the empty triangle nodes.',
        ),
        OnboardingStep(
          icon: Icons.balance,
          body:
              'Every side of the triangle must add up to the same number.',
        ),
        OnboardingStep(
          icon: Icons.refresh,
          body: 'Tap a placed number to send it back to the pool.',
        ),
      ],
    );
  }

  @override
  void dispose() {
    debugPrint("🚀 [UI] MagicTrianglesGame.dispose() - Cleaning up controllers");
    
    _glowController.stop();
    _successController.stop();
    _timeController.stop();
    _dropController.stop();
    _warpController.stop();

    _glowController.dispose();
    _successController.dispose();
    _timeController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    
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

    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        debugPrint("🎉 [UI] Warp animation completed, calculating score");
        
        _warpController.removeStatusListener(listener);

        int baseScore = 150 * widget.grade;
        int bonusScore = (baseScore * (currentPuzzle!.circlesPerSide / 3.0)).round();
        context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'magic_triangles',
      difficulty: widget.level,
      score: baseScore + bonusScore,
    ));
        _successController.forward(from: 0.0);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessDialog(bonusScore),
          );
        }
      }
    }

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
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800 || screenSize.height < 500; // iPhone landscape detection
    
    if (currentPuzzle == null || _isGenerating) {
      debugPrint("🏗️ [UI] Showing loading screen");
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Text(
                  S.of(context)!.calculatingCoordinates,
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: isSmallScreen ? 14 : 16
                  ),
                ),
              ],
            ),
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
              _buildCompactGameHeader(isSmallScreen),
              if (!isSmallScreen) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    S.of(context)!.magicTrianglesInstructions,
                    style: SpaceTheme.bodyStyle, textAlign: TextAlign.center,
                  ),
                ),
              ],
              _buildWarpFrequencyCard(isSmallScreen),
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

  // Compact header for small screens
  Widget _buildCompactGameHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16, 
        vertical: isSmallScreen ? 8 : 16
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E2235),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: isSmallScreen ? 20 : 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            ),
          ),
          
          SizedBox(width: isSmallScreen ? 12 : 20),
          
          // Title - more compact on small screens
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.magicTrianglesGameTitle,
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: isSmallScreen ? 18 : 28
                  ),
                ),
                if (isSmallScreen)
                  Text(
                    S.of(context)!.magicTrianglesInstructions,
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          
          // Level and Score - more compact
          Row(
            children: [
              _buildCompactStatItem(
                icon: Icons.emoji_events,
                label: isSmallScreen ? '' : 'Level',
                value: widget.level.toString(),
                color: const Color(0xFFFFD700),
                isSmall: isSmallScreen,
              ),
              
              SizedBox(width: isSmallScreen ? 8 : 20),
              
              Consumer<GameProvider>(
                builder: (context, gameProvider, child) {
                  return _buildCompactStatItem(
                    icon: Icons.star,
                    label: isSmallScreen ? '' : 'Score',
                    value: gameProvider.score.toString(),
                    color: const Color(0xFF06FFA5),
                    isSmall: isSmallScreen,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isSmall,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 16, 
        vertical: isSmall ? 4 : 8
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: isSmall ? 1 : 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isSmall ? 16 : 20),
          if (label.isNotEmpty || !isSmall) ...[
            SizedBox(width: isSmall ? 4 : 8),
            if (!isSmall)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ] else ...[
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // More subtle warp frequency card
  Widget _buildWarpFrequencyCard(bool isSmallScreen) {
    return Align(
      alignment: Alignment.centerRight, // Align to right to save triangle space
      child: Container(
        margin: EdgeInsets.only(
          right: isSmallScreen ? 16 : 20,
          top: isSmallScreen ? 2 : 4,
          bottom: isSmallScreen ? 2 : 4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withValues(alpha: 0.4), // More transparent
          borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 10),
          border: Border.all(
            color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Only take needed space
          children: [
            Icon(
              Icons.hub, 
              color: SpaceTheme.alienGreen, 
              size: isSmallScreen ? 12 : 16 // Smaller icon
            ),
            SizedBox(width: isSmallScreen ? 4 : 8),
            Text(
              "Warp: ${currentPuzzle!.warpFrequency}", // Shorter text
              style: SpaceTheme.titleStyle.copyWith(
                color: SpaceTheme.alienGreen, 
                fontSize: isSmallScreen ? 10 : 14, // Smaller text
              ),
            ),
          ],
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
        
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 800 || screenSize.height < 500;
        
        double size;
        if (isSmallScreen) {
          // Use much more of the available space on small screens
          size = math.min(constraints.maxWidth * 0.95, constraints.maxHeight * 0.9)
              .clamp(280.0, 400.0); // Larger minimum size
        } else {
          size = math.min(constraints.maxWidth, constraints.maxHeight)
              .clamp(300.0, 500.0);
        }
        
        final center = Offset(size / 2, size / 2);
        final radius = size * 0.42; // Slightly larger radius
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
            onWillAcceptWithDetails: (data) {
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
    
    // Better node size calculation for small screens
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800 || screenSize.height < 500;
    
    final nodeSize = isSmallScreen 
        ? (size * 0.15).clamp(35.0, 55.0)  // Smaller nodes for small screens
        : (size * 0.18).clamp(45.0, 75.0);
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
            fontSize: size * 0.4, // Slightly larger font relative to node size
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
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800 || screenSize.height < 500;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.of(context)!.magicTrianglesResonators, 
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: isSmallScreen ? 12 : 14
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2)
          ),
          constraints: BoxConstraints(maxWidth: isSmallScreen ? 280 : 350),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isSmallScreen ? 5 : 4, // More columns on small screens
              crossAxisSpacing: isSmallScreen ? 6 : 8,
              mainAxisSpacing: isSmallScreen ? 6 : 8,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              if (index >= numberPool.length) {
                return Container(); 
              }
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number, isSmallScreen),
                childWhenDragging: Opacity(
                  opacity: 0.3, 
                  child: _buildResonator(number, isSmallScreen)
                ),
                child: _buildResonator(number, isSmallScreen),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResonator(int number, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
        border: Border.all(
          color: SpaceTheme.starYellow.withValues(alpha: 0.7), 
          width: isSmallScreen ? 1 : 2
        ),
      ),
      child: Center(
        child: Text(
          number.toString(), 
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: isSmallScreen ? 14 : 18
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableFeedback(int number, bool isSmallScreen) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isSmallScreen ? 45 : 60,
        height: isSmallScreen ? 45 : 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SpaceTheme.starGradient,
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow, blurRadius: 20, spreadRadius: 5)],
        ),
        child: Center(
          child: Text(
            number.toString(), 
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: isSmallScreen ? 16 : 22
            ),
          ),
        ),
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
}

