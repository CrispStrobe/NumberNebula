import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';

import '../constants/app_constants.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

// DEVELOPMENT TWEAKING CONSTANTS
const bool kTweakProblems = false;
const int kTweakRangeMin = 2;
const int kTweakRangeMax = 8;

class SolarPanelGame extends StatefulWidget {
  final int grade;
  final int level;

  const SolarPanelGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<SolarPanelGame> createState() => _SolarPanelGameState();
}

class _SolarPanelGameState extends State<SolarPanelGame>
    with TickerProviderStateMixin {
  final GlobalKey _dragTargetKey = GlobalKey();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _warpController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _panelExpandController;
  late Animation<double> _panelExpandAnimation;

  SolarPanelPuzzle? currentPuzzle;
  List<int?> userAnswers = [];
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  bool _isWarping = false;
  int _lastPlacedCellIndex = -1;
  bool _isDraggingOver = false;
  bool _showPanelExpansion = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _fadeTimer;
  bool _shouldShowHint = true;

  @override
  void initState() {
    super.initState();
    debugPrint("☀️ SolarPanelGame.initState() - Grade ${widget.grade}, Level ${widget.level}");
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);
    
    _warpController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000), vsync: this
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _panelExpandController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this
    );
    _panelExpandAnimation = CurvedAnimation(
      parent: _panelExpandController, 
      curve: Curves.easeOutBack
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000), vsync: this
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    _generatePuzzle();
    _startFadeTimer();
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _shouldShowHint) {
        setState(() {
          _shouldShowHint = false;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    _pulseController.dispose();
    _panelExpandController.dispose();
    _fadeController.dispose();
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("☀️ _generatePuzzle() - Starting puzzle generation");
    
    setState(() {
      _isGenerating = true;
      _isWarping = false;
      _shouldShowHint = true;
      _showPanelExpansion = false;
      _warpController.reset();
      _successController.reset();
      _fadeController.reset();
      _panelExpandController.reset();
    });

    try {
      final gameProvider = context.read<GameProvider>();
      final puzzleArgs = {
        'grade': widget.grade,
        'level': widget.level,
        'useCustomSettings': gameProvider.useCustomProblemSettings,
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
      };

      final puzzle = await compute(SolarPanelPuzzle.generate, puzzleArgs);
      
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.generate(currentPuzzle!.hiddenCells.length, (_) => null);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
        debugPrint("☀️ Puzzle generated: ${currentPuzzle!.baseNumbers}");
        _startFadeTimer();
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in _generatePuzzle: $e");
      debugPrint("❌ StackTrace: $stackTrace");
    }
  }
  
  void _placeNumber(int number, int hiddenCellIndex) {
    final answerIndex = currentPuzzle!.getAnswerIndexForCell(hiddenCellIndex);
    if (answerIndex == -1 || userAnswers[answerIndex] != null) {
      return;
    }

    setState(() {
      userAnswers[answerIndex] = number;
      numberPool.remove(number);
      _lastPlacedCellIndex = hiddenCellIndex;
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
      final isValid = currentPuzzle!.validateSolution(userAnswers.cast<int>());
      
      final List<MathProblem> attemptedProblems = _getSolvedProblems();
      
      if (isValid) {
        int baseScore = 120 * widget.grade;
        int bonusScore = (baseScore * 0.5).round();
        int totalScore = baseScore + bonusScore;

        context.read<GameProvider>().recordLevelWin(
          gameType: 'solar_panel',
          scoreGained: totalScore,
          difficulty: widget.level,
          wasSuccessful: true,
          mathProblems: attemptedProblems,
        );
        
        _handleSuccess(totalScore);
      } else {
        context.read<GameProvider>().recordLevelWin(
          gameType: 'solar_panel',
          scoreGained: 0,
          difficulty: widget.level,
          wasSuccessful: false,
          mathProblems: attemptedProblems,
        );

        _handleIncorrect();
      }
    }
  }

  List<MathProblem> _getSolvedProblems() {
    debugPrint("☀️ Gathering all solved problems...");
    final puzzle = currentPuzzle!;
    final List<MathProblem> problemsToLog = [];
    
    final solution = puzzle.fullSolution;
    final a = solution[3];
    final b = solution[4];
    final c = solution[5];
    
    // Two multiplication problems: A×B and B×C
    problemsToLog.add(MathProblem.multiplication(a, b));
    problemsToLog.add(MathProblem.multiplication(b, c));
    
    // One addition problem: (A×B) + (B×C)
    final leftPanel = a * b;
    final rightPanel = b * c;
    problemsToLog.add(MathProblem.addition(leftPanel, rightPanel));
    
    return problemsToLog;
  }

  void _handleSuccess(int totalScoreGained) {
    // First show panel expansion animation
    setState(() => _showPanelExpansion = true);
    _panelExpandController.forward();

    // Wait for panel expansion to complete before showing warp
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      
      setState(() => _isWarping = true);
      _warpController.forward();

      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _warpController.removeStatusListener(listener);
          _successController.forward(from: 0.0);
          
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _buildSuccessDialog(totalScoreGained - (120 * widget.grade)),
            );
          }
        }
      }

      _warpController.addStatusListener(listener);
    });
  }

  void _handleIncorrect() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.solarPanelFail),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPuzzle == null || _isGenerating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildCompactHeader(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWide = constraints.maxWidth > 600;
                        return isWide ? _buildWideLayout() : _buildCompactTallLayout();
                      },
                    ),
                  ),
                ],
              ),
              if (_shouldShowHint || _fadeController.status == AnimationStatus.reverse)
                _buildFloatingHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHint() {
    return Positioned(
      top: 60,
      right: 16,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _shouldShowHint ? 1.0 : _fadeAnimation.value,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: math.min(MediaQuery.of(context).size.width * 0.6, 280),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpaceTheme.starYellow, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value * 0.8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wb_sunny, 
                            color: Colors.white, 
                            size: 16
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          S.of(context)!.solarPanelTitle,
                          style: SpaceTheme.titleStyle.copyWith(
                            color: Colors.white, 
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          S.of(context)!.solarPanelHint,
                          style: SpaceTheme.bodyStyle.copyWith(
                            color: Colors.white70, 
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (kTweakProblems)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TWEAK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
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

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              S.of(context)!.solarPanelGameTitle,
              style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpaceTheme.starYellow),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 16, color: SpaceTheme.starYellow),
                    const SizedBox(width: 4),
                    Text('${widget.level}', style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.alienGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpaceTheme.alienGreen),
                ),
                child: Consumer<GameProvider>(
                  builder: (context, gameProvider, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: SpaceTheme.alienGreen),
                        const SizedBox(width: 4),
                        Text('${gameProvider.score}', style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBrick(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 1.5),
      ),
      child: Center(
        child: Text(
          number.toString(), 
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 14)
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
          Expanded(flex: 3, child: _buildPanelArea()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildCompactNumberPad()),
        ],
      ),
    );
  }

  Widget _buildCompactTallLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          Flexible(
            flex: 3,
            child: _buildPanelArea(),
          ),
          const SizedBox(height: 8),
          Flexible(
            flex: 1,
            child: _buildCompactNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        
        return Center(
          child: DragTarget<int>(
            key: _dragTargetKey,
            builder: (context, candidateData, rejectedData) {
              return SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_glowController, _warpController]),
                        builder: (context, child) {
                          return CustomPaint(
                            painter: SolarPanelBackgroundPainter(
                              glowIntensity: _glowAnimation.value,
                              warpActivation: _warpController.value,
                            ),
                          );
                        },
                      ),
                    ),
                    ..._buildPanelCells(size),
                    ..._buildOperationSymbols(size),
                    // Panel expansion overlay (on top of cells)
                    if (_showPanelExpansion)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _panelExpandAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: PanelExpansionPainter(
                                expansion: _panelExpandAnimation.value,
                                solution: currentPuzzle?.fullSolution,
                                containerSize: size,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
            onWillAccept: (data) {
              setState(() => _isDraggingOver = true);
              return true;
            },
            onLeave: (data) {
              setState(() => _isDraggingOver = false);
            },
            onAcceptWithDetails: (details) {
              setState(() => _isDraggingOver = false);
              
              final RenderBox? renderBox = _dragTargetKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) return;
              
              final localDropPosition = renderBox.globalToLocal(details.offset);
              final droppedNumber = details.data;

              int? closestCellIndex = _findClosestEmptyCell(localDropPosition, size);

              if (closestCellIndex != null) {
                _placeNumber(droppedNumber, closestCellIndex);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context)!.solarPanelDropFar),
                    duration: const Duration(milliseconds: 1500),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildOperationSymbols(double containerSize) {
    if (currentPuzzle == null) return [];
    
    final gameProvider = context.read<GameProvider>();
    List<Widget> symbols = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    
    // multiplication symbol between A (index 3) and B (index 4) - bottom row
    final aPos = cellPositions[3];
    final bPos = cellPositions[4];
    final leftMultPos = Offset(
      (aPos.dx + bPos.dx) / 2,
      aPos.dy, // Same height as bottom row
    );
    
    symbols.add(_buildOperationIcon(
      leftMultPos,
      gameProvider.multiplicationSymbol,
      SpaceTheme.cosmicPink,
    ));
    
    // multiplication symbol between B (index 4) and C (index 5) - bottom row
    final cPos = cellPositions[5];
    final rightMultPos = Offset(
      (bPos.dx + cPos.dx) / 2,
      bPos.dy, // Same height as bottom row
    );
    
    symbols.add(_buildOperationIcon(
      rightMultPos,
      gameProvider.multiplicationSymbol,
      SpaceTheme.cosmicPink,
    ));
    
    // + symbol between left panel (index 1) and right panel (index 2) - middle row
    final leftPanelPos = cellPositions[1];
    final rightPanelPos = cellPositions[2];
    final addPos = Offset(
      (leftPanelPos.dx + rightPanelPos.dx) / 2,
      leftPanelPos.dy, // Same height as middle row
    );
    
    symbols.add(_buildOperationIcon(
      addPos,
      '+',
      SpaceTheme.alienGreen,
    ));
    
    return symbols;
  }

  Widget _buildOperationIcon(Offset position, String symbol, Color color) {
    return Positioned(
      left: position.dx - 16,
      top: position.dy - 16,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value * 0.9,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)]
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
    
  int? _findClosestEmptyCell(Offset dropPosition, double containerSize) {
    if (currentPuzzle == null) return null;

    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.15;
    final double acceptanceRadius = cellSize * 1.2;

    double minDistance = double.infinity;
    int? closestEmptyCellIndex;
    
    for (int cellIndex in currentPuzzle!.hiddenCells) {
      final answerIndex = currentPuzzle!.getAnswerIndexForCell(cellIndex);
      final isEmpty = answerIndex != -1 && answerIndex < userAnswers.length && userAnswers[answerIndex] == null;
      if (isEmpty) {
        final cellCenter = cellPositions[cellIndex];
        final distance = (dropPosition - cellCenter).distance;
        if (distance < minDistance) {
          minDistance = distance;
          closestEmptyCellIndex = cellIndex;
        }
      }
    }

    if (closestEmptyCellIndex != null && minDistance <= acceptanceRadius) {
      return closestEmptyCellIndex;
    }
    return null;
  }

  List<Widget> _buildPanelCells(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> cells = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.15;
    
    for (int i = 0; i < 6; i++) {
      int? value;
      bool isHidden = currentPuzzle!.hiddenCells.contains(i);
      
      if (isHidden) {
        final answerIndex = currentPuzzle!.getAnswerIndexForCell(i);
        if (answerIndex != -1 && answerIndex < userAnswers.length) {
          value = userAnswers[answerIndex];
        }
      } else {
        value = currentPuzzle!.visibleValues[i];
      }

      Widget cell = isHidden 
          ? _buildDroppableCell(value, currentPuzzle!.getAnswerIndexForCell(i), cellSize)
          : _buildFixedCell(value: value!, size: cellSize);
      
      if (i == _lastPlacedCellIndex) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      cells.add(Positioned(
        left: cellPositions[i].dx - cellSize / 2,
        top: cellPositions[i].dy - cellSize / 2,
        child: cell,
      ));
    }
    
    return cells;
  }

  Widget _buildDroppableCell(int? value, int answerIndex, double size) {
    return GestureDetector(
      onTap: value != null ? () => _removeNumber(answerIndex) : null,
      child: _buildPanelCell(
        value: value,
        isSelected: _isDraggingOver && value == null,
        isHidden: true,
        size: size,
      ),
    );
  }

  Widget _buildFixedCell({required int value, double size = 70}) {
    return _buildPanelCell(
      value: value,
      isSelected: false,
      isHidden: false,
      size: size,
    );
  }

  Widget _buildPanelCell({ required int? value, required bool isSelected, required bool isHidden, double size = 70 }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: _getCellGradient(isHidden, isSelected),
        border: Border.all(
          color: isSelected ? SpaceTheme.starYellow : SpaceTheme.starYellow.withOpacity(0.5),
          width: isSelected ? 3 : 2,
        ),
        boxShadow: _getCellShadow(isSelected),
      ),
      child: Center(
        child: Text(
          isHidden ? (value?.toString() ?? '') : value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: size * 0.35,
            color: isHidden && value == null ? Colors.transparent : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCompactNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.of(context)!.solarPanelNumbers, 
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: SpaceTheme.cardDecoration.copyWith(
              border: Border.all(color: SpaceTheme.nebulaPurple, width: 2)
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: math.min(5, numberPool.length), 
                crossAxisSpacing: 6, 
                mainAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: numberPool.length,
              itemBuilder: (context, index) {
                if (index >= numberPool.length) return Container();
                final number = numberPool[index];
                return Draggable<int>(
                  data: number,
                  feedback: _buildDraggableFeedback(number),
                  childWhenDragging: Opacity(opacity: 0.3, child: _buildCompactBrick(number)),
                  child: _buildCompactBrick(number),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableFeedback(int number) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SpaceTheme.starGradient,
          boxShadow: const [BoxShadow(color: SpaceTheme.starYellow, blurRadius: 20)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22))
        ),
      ),
    );
  }
  
  LinearGradient _getCellGradient(bool isHidden, bool isSelected) {
    if (!isHidden) {
      return const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.deepSpace]);
    }
    if (isSelected) {
      return const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    }
    return const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]);
  }

  List<BoxShadow> _getCellShadow(bool isSelected) {
    return [
      BoxShadow(
        color: isSelected ? SpaceTheme.starYellow : SpaceTheme.starYellow.withOpacity(0.5),
        blurRadius: isSelected ? 20 : 10,
        spreadRadius: isSelected ? 3 : 1,
      ),
    ];
  }

  Widget _buildSuccessDialog(int bonusScore) {
    return AnimatedBuilder(
        animation: _successAnimation,
        builder: (context, child) {
        return Transform.scale(
            scale: _successAnimation.value,
            child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                decoration: SpaceTheme.cardDecoration,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    const Icon(Icons.wb_sunny, size: 48, color: SpaceTheme.starYellow),
                    const SizedBox(height: 12),
                    Text(
                        S.of(context)!.solarPanelWinTitle, 
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 20), 
                        textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 8),
                    Text(
                        S.of(context)!.solarPanelWinDesc(bonusScore), 
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 14), 
                        textAlign: TextAlign.center
                    ),
                    const SizedBox(height: 16),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                        ElevatedButton(
                            onPressed: () {
                            Navigator.of(context).pop();
                            _generatePuzzle();
                            },
                            style: SpaceTheme.primaryButtonStyle,
                            child: Text(S.of(context)!.solarPanelNext),
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
            ),
        );
        },
    );
    }
}

// SolarPanelPuzzle class
class SolarPanelPuzzle {
  final List<int> baseNumbers; // [A, B, C]
  final Set<int> hiddenCells;
  final Map<int, int> visibleValues;
  final List<int> fullSolution; // [top, leftPanel, rightPanel, A, B, C]
  final List<int> numberPool;

  SolarPanelPuzzle({
    required this.baseNumbers,
    required this.hiddenCells,
    required this.visibleValues,
    required this.fullSolution,
    required this.numberPool,
  });

  int getAnswerIndexForCell(int cellIndex) {
    if (!hiddenCells.contains(cellIndex)) return -1;
    final sortedHiddenCells = hiddenCells.toList()..sort();
    return sortedHiddenCells.indexOf(cellIndex);
  }

  List<Offset> getCellPositions(double containerSize) {
    final positions = <Offset>[];
    final cellSpacing = containerSize / 4;
    
    // Top cell (total power) - index 0
    positions.add(Offset(containerSize / 2, cellSpacing));
    
    // Middle cells (left and right panels) - indices 1, 2
    positions.add(Offset(containerSize / 2 - cellSpacing * 0.8, cellSpacing * 2));
    positions.add(Offset(containerSize / 2 + cellSpacing * 0.8, cellSpacing * 2));
    
    // Bottom cells (A, B, C) - indices 3, 4, 5
    positions.add(Offset(containerSize / 2 - cellSpacing, cellSpacing * 3));
    positions.add(Offset(containerSize / 2, cellSpacing * 3));
    positions.add(Offset(containerSize / 2 + cellSpacing, cellSpacing * 3));
    
    return positions;
  }

  static SolarPanelPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final generator = _SolarPanelGenerator(
      grade, level,
      useCustomSettings: useCustomSettings,
      customRangeMin: customMin,
      customRangeMax: customMax,
    );

    return generator.generate();
  }

  bool validateSolution(List<int> userSolution) {
    final completePanel = List<int>.filled(6, 0);
    final sortedHiddenCells = hiddenCells.toList()..sort();
    
    for (int i = 0; i < 6; i++) {
      if (!hiddenCells.contains(i)) {
        completePanel[i] = visibleValues[i]!;
      }
    }
    
    for (int answerIndex = 0; answerIndex < userSolution.length; answerIndex++) {
      if (answerIndex < sortedHiddenCells.length) {
        final cellIndex = sortedHiddenCells[answerIndex];
        completePanel[cellIndex] = userSolution[answerIndex];
      }
    }
    
    // Validate: top = leftPanel + rightPanel
    // leftPanel = A * B, rightPanel = B * C
    final a = completePanel[3];
    final b = completePanel[4];
    final c = completePanel[5];
    final leftPanel = completePanel[1];
    final rightPanel = completePanel[2];
    final top = completePanel[0];
    
    return leftPanel == a * b && rightPanel == b * c && top == leftPanel + rightPanel;
  }
}

// Generator class
class _SolarPanelGenerator {
  final int grade;
  final int level;
  final bool useCustomSettings;
  final int customRangeMin;
  final int customRangeMax;
  
  _SolarPanelGenerator(this.grade, this.level, {
    required this.useCustomSettings,
    required this.customRangeMin,
    required this.customRangeMax,
  });

  SolarPanelPuzzle generate() {
    List<int>? solution;
    int attempts = 0;
    
    while (solution == null && attempts < 50) {
      try {
        solution = _generateValidPanel();
        if (solution != null && _validatePanel(solution)) {
          break;
        } else {
          solution = null;
        }
      } catch (e) {
        // Generation error
      }
      attempts++;
    }
    
    solution ??= _createFallbackPanel();
    
    final hiddenCells = _selectHiddenCells();
    
    final visibleValues = <int, int>{};
    for (int i = 0; i < 6; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = solution[i];
      }
    }
    
    final hiddenNumbers = hiddenCells.map((i) => solution![i]).toList();
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    
    return SolarPanelPuzzle(
      baseNumbers: solution.sublist(3, 6),
      hiddenCells: hiddenCells,
      visibleValues: visibleValues,
      fullSolution: solution,
      numberPool: numberPool,
    );
  }

  List<int>? _generateValidPanel() {
    final random = math.Random();
    
    // Generate base numbers
    final minVal = _getMinNumber();
    final maxVal = _getMaxNumber();
    
    final a = minVal + random.nextInt(maxVal - minVal + 1);
    final b = minVal + random.nextInt(maxVal - minVal + 1);
    final c = minVal + random.nextInt(maxVal - minVal + 1);
    
    final leftPanel = a * b;
    final rightPanel = b * c;
    final top = leftPanel + rightPanel;
    
    return [top, leftPanel, rightPanel, a, b, c];
  }

  bool _validatePanel(List<int> solution) {
    // Check no value is too large
    if (solution.any((n) => n > 500)) return false;
    
    final a = solution[3];
    final b = solution[4];
    final c = solution[5];
    final leftPanel = solution[1];
    final rightPanel = solution[2];
    final top = solution[0];
    
    return leftPanel == a * b && rightPanel == b * c && top == leftPanel + rightPanel;
  }

  List<int> _createFallbackPanel() {
    return [14, 6, 8, 3, 2, 4]; // 3*2=6, 2*4=8, 6+8=14
  }

  Set<int> _selectHiddenCells() {
    final hidden = <int>{};
    final maxHidden = (2 + grade + (level / 5)).clamp(2, 5).floor();
    final candidates = List.generate(6, (i) => i)..shuffle();
    
    // Ensure at least one base number is hidden
    final baseIndices = [3, 4, 5];
    hidden.add(baseIndices[math.Random().nextInt(3)]);
    
    // Add more random cells
    for (final cell in candidates) {
      if (hidden.length >= maxHidden) break;
      hidden.add(cell);
    }
    
    return hidden;
  }

  List<int> _generateDecoyNumbers(List<int> hiddenNumbers) {
    final decoys = <int>{};
    final decoyCount = (8 - hiddenNumbers.length).clamp(2, 4);
    
    for (final num in hiddenNumbers) {
      if (decoys.length >= decoyCount) break;
      final offset = 1 + math.Random().nextInt(5);
      final variations = [num - offset, num + offset, num * 2, (num / 2).round()];
      for (final v in variations) {
        if (!hiddenNumbers.contains(v) && v > 0) {
          decoys.add(v);
          if (decoys.length >= decoyCount) break;
        }
      }
    }
    while (decoys.length < decoyCount) {
      decoys.add(1 + math.Random().nextInt(20));
    }
    
    return decoys.toList();
  }

  int _getMinNumber() {
    if (kTweakProblems) return kTweakRangeMin;
    if (useCustomSettings) return customRangeMin;
    return math.max(1, (grade - 1) * 2 + (level / 3).floor());
  }

  int _getMaxNumber() {
    if (kTweakProblems) return kTweakRangeMax;
    if (useCustomSettings) return customRangeMax;
    return _getMinNumber() + 6 + grade * 2;
  }
}

// Background painter (simple glow and warp only)
class SolarPanelBackgroundPainter extends CustomPainter {
  final double glowIntensity;
  final double warpActivation;

  const SolarPanelBackgroundPainter({
    required this.glowIntensity,
    required this.warpActivation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Glow effect
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [ 
          SpaceTheme.starYellow.withOpacity(0.1 * glowIntensity), 
          Colors.transparent 
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    
    canvas.drawCircle(center, size.width * 0.6, backgroundPaint);
    
    // Warp effect
    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = SpaceTheme.starYellow.withOpacity(0.4 * (1 - warpActivation))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + (warpActivation * 10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + warpActivation * 10);
      
      canvas.drawCircle(center, size.width * 0.1 + (size.width/2 * warpActivation), warpPaint);
    }
  }

  @override
  bool shouldRepaint(SolarPanelBackgroundPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.warpActivation != warpActivation;
}

// Panel expansion painter (renders on top of cells)
class PanelExpansionPainter extends CustomPainter {
  final double expansion;
  final List<int>? solution;
  final double containerSize;

  const PanelExpansionPainter({
    required this.expansion,
    required this.solution,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expansion <= 0 || solution == null || solution!.length != 6) return;
    
    final a = solution![3];
    final b = solution![4]; // height
    final c = solution![5];
    
    final cellSpacing = containerSize / 4;
    final leftPanelCenter = Offset(containerSize / 2 - cellSpacing * 0.8, cellSpacing * 2);
    final rightPanelCenter = Offset(containerSize / 2 + cellSpacing * 0.8, cellSpacing * 2);
    
    // Left panel: width = A, height = B
    final leftWidth = (a * cellSpacing * 0.2 * expansion).clamp(0.0, containerSize * 0.45);
    final leftHeight = (b * cellSpacing * 0.2 * expansion).clamp(0.0, containerSize * 0.45);
    
    final leftPanelRect = Rect.fromCenter(
      center: leftPanelCenter,
      width: leftWidth,
      height: leftHeight,
    );
    
    final leftPanelPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          SpaceTheme.starYellow.withOpacity(0.5 * expansion),
          SpaceTheme.planetOrange.withOpacity(0.3 * expansion),
        ],
      ).createShader(leftPanelRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPanelRect, const Radius.circular(12)),
      leftPanelPaint,
    );
    
    // Border for left panel
    final leftBorderPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(0.9 * expansion)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPanelRect, const Radius.circular(12)),
      leftBorderPaint,
    );
    
    // Dimension labels for left panel
    if (expansion > 0.5) {
      _drawDimensionLabel(
        canvas, 
        '$a', 
        Offset(leftPanelCenter.dx, leftPanelRect.bottom + 15),
        expansion
      );
      _drawDimensionLabel(
        canvas, 
        '$b', 
        Offset(leftPanelRect.left - 15, leftPanelCenter.dy),
        expansion
      );
    }
    
    // Right panel: width = C, height = B
    final rightWidth = (c * cellSpacing * 0.2 * expansion).clamp(0.0, containerSize * 0.45);
    final rightHeight = (b * cellSpacing * 0.2 * expansion).clamp(0.0, containerSize * 0.45);
    
    final rightPanelRect = Rect.fromCenter(
      center: rightPanelCenter,
      width: rightWidth,
      height: rightHeight,
    );
    
    final rightPanelPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          SpaceTheme.starYellow.withOpacity(0.5 * expansion),
          SpaceTheme.planetOrange.withOpacity(0.3 * expansion),
        ],
      ).createShader(rightPanelRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPanelRect, const Radius.circular(12)),
      rightPanelPaint,
    );
    
    // Border for right panel
    final rightBorderPaint = Paint()
      ..color = SpaceTheme.starYellow.withOpacity(0.9 * expansion)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPanelRect, const Radius.circular(12)),
      rightBorderPaint,
    );
    
    // Dimension labels for right panel
    if (expansion > 0.5) {
      _drawDimensionLabel(
        canvas, 
        '$c', 
        Offset(rightPanelCenter.dx, rightPanelRect.bottom + 15),
        expansion
      );
      _drawDimensionLabel(
        canvas, 
        '$b', 
        Offset(rightPanelRect.right + 15, rightPanelCenter.dy),
        expansion
      );
    }
    
    // Energy rays from panels
    if (expansion > 0.7) {
      final rayPaint = Paint()
        ..color = SpaceTheme.starYellow.withOpacity(0.4 * (expansion - 0.7) * 3.33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
      for (int i = 0; i < 6; i++) {
        final angle = (i * math.pi * 2 / 6) + (expansion * math.pi * 2);
        final endX = leftPanelCenter.dx + math.cos(angle) * 40 * expansion;
        final endY = leftPanelCenter.dy + math.sin(angle) * 40 * expansion;
        canvas.drawLine(leftPanelCenter, Offset(endX, endY), rayPaint);
        
        final endX2 = rightPanelCenter.dx + math.cos(angle) * 40 * expansion;
        final endY2 = rightPanelCenter.dy + math.sin(angle) * 40 * expansion;
        canvas.drawLine(rightPanelCenter, Offset(endX2, endY2), rayPaint);
      }
    }
  }

  void _drawDimensionLabel(Canvas canvas, String text, Offset position, double expansion) {
    // Clamp expansion to prevent opacity > 1.0
    final clampedExpansion = expansion.clamp(0.0, 1.0);
    
    final textPainter = TextPainter(
        text: TextSpan(
        text: text,
        style: TextStyle(
            color: Colors.white.withOpacity(0.95 * clampedExpansion),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
            Shadow(
                color: SpaceTheme.starYellow.withOpacity(0.8 * clampedExpansion),
                blurRadius: 8,
            ),
            ],
        ),
        ),
        textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, 
        Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2)
    );
    }

  @override
  bool shouldRepaint(PanelExpansionPainter oldDelegate) =>
      oldDelegate.expansion != expansion;
}