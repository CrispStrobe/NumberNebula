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

enum WallOperation { addition, subtraction, multiplication, division }

class NumberWallsGame extends StatefulWidget {
  final int grade;
  final int level;

  const NumberWallsGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<NumberWallsGame> createState() => _NumberWallsGameState();
}

class _NumberWallsGameState extends State<NumberWallsGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _warpController;
  late AnimationController _operationController;
  late Animation<double> _operationAnimation;

  NumberWallPuzzle? currentPuzzle;
  List<int?> userAnswers = [];
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  bool _isWarping = false;
  int _lastPlacedCellIndex = -1;
  bool _isDraggingOver = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🧱 [UI] NumberWallsGame.initState() - Starting initialization");
    
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

    _operationController = AnimationController(
      duration: const Duration(milliseconds: 1000), vsync: this
    )..repeat(reverse: true);
    _operationAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _operationController, curve: Curves.easeInOut));
    
    debugPrint("🧱 [UI] Animation controllers initialized, calling _generatePuzzle()");
    _generatePuzzle();
  }

  @override
  void dispose() {
    debugPrint("🧱 [UI] NumberWallsGame.dispose() - Cleaning up controllers");
    
    _glowController.stop();
    _successController.stop();
    _dropController.stop();
    _warpController.stop();
    _operationController.stop();
    
    _warpController.clearListeners();
    
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    _operationController.dispose();
    
    currentPuzzle = null;
    userAnswers.clear();
    numberPool.clear();
    
    debugPrint("🧱 [UI] All controllers disposed and data cleared");
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("🧱 [UI] _generatePuzzle() - Starting puzzle generation");
    
    setState(() {
      _isGenerating = true;
      _isWarping = false;
      _warpController.reset();
      _successController.reset();
    });

    try {
      final gameProvider = context.read<GameProvider>();
      final puzzleArgs = {
        'grade': widget.grade,
        'level': widget.level,
        'useCustomSettings': gameProvider.useCustomProblemSettings,
        'customOps': gameProvider.customOperations.toList(), // Sets can't be sent to isolates
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
      };

      // --- Pass the new arguments map to compute ---
      final puzzle = await compute(NumberWallPuzzle.generate, puzzleArgs);
      
      debugPrint("🧱 [UI] compute() completed successfully");
      
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.generate(currentPuzzle!.hiddenCells.length, (_) => null);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
        debugPrint("🧱 [UI] State updated successfully");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [UI] Error in _generatePuzzle: $e");
      debugPrint("❌ [UI] StackTrace: $stackTrace");
    }
  }
  
  void _placeNumber(int number, int answerIndex, int cellIndex) {
    debugPrint("🎯 [UI] _placeNumber($number, $answerIndex, $cellIndex)");
    if (userAnswers[answerIndex] != null) {
      debugPrint("🎯 [UI] Position already filled, ignoring");
      return;
    }

    setState(() {
      userAnswers[answerIndex] = number;
      numberPool.remove(number);
      _lastPlacedCellIndex = cellIndex;
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
  }

  void _checkIfComplete() {
    debugPrint("✅ [UI] _checkIfComplete() - userAnswers: $userAnswers");
    if (userAnswers.every((answer) => answer != null)) {
      debugPrint("✅ [UI] All answers filled, checking solution");
      final isValid = currentPuzzle!.validateSolution(userAnswers.cast<int>());
      debugPrint("✅ [UI] Solution validation result: $isValid");
      if (isValid) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
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

        int baseScore = 120 * widget.grade;
        int bonusScore = (baseScore * (currentPuzzle!.wallHeight / 3.0)).round();
        int operationBonus = _getOperationBonus(currentPuzzle!.operation);
        context.read<GameProvider>().addScore(baseScore + bonusScore + operationBonus);
        _successController.forward(from: 0.0);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessDialog(bonusScore + operationBonus),
          );
        }
      }
    }

    _warpController.addStatusListener(listener);
  }

  int _getOperationBonus(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return 0;
      case WallOperation.subtraction: return 25;
      case WallOperation.multiplication: return 50;
      case WallOperation.division: return 75;
    }
  }

  void _handleIncorrect() {
    debugPrint("❌ [UI] _handleIncorrect() - Showing failure message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.numberWallsFail),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPuzzle == null || _isGenerating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(S.of(context)!.numberWallsCalculating, style: SpaceTheme.bodyStyle),
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
                title: S.of(context)!.numberWallsGameTitle, 
                level: widget.level, 
                onBack: () => Navigator.of(context).pop()
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  S.of(context)!.numberWallsInstructions,
                  style: SpaceTheme.bodyStyle, 
                  textAlign: TextAlign.center,
                ),
              ),
              _buildOperationIndicator(),
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

  Widget _buildOperationIndicator() {
    if (currentPuzzle == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _getOperationGradient(currentPuzzle!.operation),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getOperationColor(currentPuzzle!.operation), width: 2),
        boxShadow: [
          BoxShadow(
            color: _getOperationColor(currentPuzzle!.operation).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _operationAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _operationAnimation.value,
                child: Icon(
                  _getOperationIcon(currentPuzzle!.operation), 
                  color: Colors.white, 
                  size: 32
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            _getOperationTitle(currentPuzzle!.operation),
            style: SpaceTheme.titleStyle.copyWith(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
    );
  }

  String _getOperationTitle(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return S.of(context)!.numberWallsAddition;
      case WallOperation.subtraction: return S.of(context)!.numberWallsSubtraction;
      case WallOperation.multiplication: return S.of(context)!.numberWallsMultiplication;
      case WallOperation.division: return S.of(context)!.numberWallsDivision;
    }
  }

  IconData _getOperationIcon(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return Icons.add;
      case WallOperation.subtraction: return Icons.remove;
      case WallOperation.multiplication: return Icons.close;
      case WallOperation.division: return Icons.more_horiz;
    }
  }

  Color _getOperationColor(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return SpaceTheme.alienGreen;
      case WallOperation.subtraction: return SpaceTheme.cosmicPink;
      case WallOperation.multiplication: return SpaceTheme.starYellow;
      case WallOperation.division: return SpaceTheme.planetOrange;
    }
  }

  LinearGradient _getOperationGradient(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: 
        return const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]);
      case WallOperation.subtraction: 
        return const LinearGradient(colors: [SpaceTheme.cosmicPink, SpaceTheme.deepSpace]);
      case WallOperation.multiplication: 
        return const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.deepSpace]);
      case WallOperation.division: 
        return const LinearGradient(colors: [SpaceTheme.planetOrange, SpaceTheme.deepSpace]);
    }
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _buildWallArea()),
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
            _buildWallArea(),
            const SizedBox(height: 24),
            _buildNumberPad(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWallArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight).clamp(300.0, 500.0);
        
        return Center(
          child: DragTarget<int>(
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
                            painter: NumberWallBackgroundPainter(
                              glowIntensity: _glowAnimation.value,
                              warpActivation: _warpController.value,
                              operation: currentPuzzle?.operation ?? WallOperation.addition,
                            ),
                          );
                        },
                      ),
                    ),
                    ..._buildWallCells(size),
                    ..._buildOperationSymbols(size),
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
              
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localDropPosition = renderBox.globalToLocal(details.offset);
              final droppedNumber = details.data;

              int? closestCellIndex = _findClosestEmptyCell(localDropPosition, size);

              if (closestCellIndex != null) {
                final answerIndex = currentPuzzle!.getAnswerIndex(closestCellIndex);
                if (answerIndex != -1) {
                  _placeNumber(droppedNumber, answerIndex, closestCellIndex);
                }
              }
            },
          ),
        );
      },
    );
  }

  int? _findClosestEmptyCell(Offset dropPosition, double containerSize) {
    double minDistance = double.infinity;
    int? targetCellIndex;
    
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    
    for (int i = 0; i < currentPuzzle!.totalCells; i++) {
      if (currentPuzzle!.hiddenCells.contains(i)) {
        final answerIndex = currentPuzzle!.getAnswerIndex(i);
        if (answerIndex != -1 && userAnswers[answerIndex] == null) {
          final cellCenter = cellPositions[i];
          final distance = (dropPosition - cellCenter).distance;

          if (distance < minDistance) {
            minDistance = distance;
            targetCellIndex = i;
          }
        }
      }
    }
    
    if (minDistance < 75.0) {
      return targetCellIndex;
    }
    return null;
  }
  
  List<Widget> _buildWallCells(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> cells = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.12;
    
    for (int i = 0; i < currentPuzzle!.totalCells; i++) {
      int? value;
      bool isHidden = currentPuzzle!.hiddenCells.contains(i);
      
      if (isHidden) {
        final answerIndex = currentPuzzle!.getAnswerIndex(i);
        if (answerIndex != -1 && answerIndex < userAnswers.length) {
          value = userAnswers[answerIndex];
        }
      } else {
        value = currentPuzzle!.visibleValues[i];
      }

      Widget cell = isHidden 
          ? _buildDroppableCell(value, currentPuzzle!.getAnswerIndex(i), cellSize)
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

  List<Widget> _buildOperationSymbols(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> symbols = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final operationColor = _getOperationColor(currentPuzzle!.operation);
    final operationIcon = _getOperationIcon(currentPuzzle!.operation);
    
    // Add operation symbols between cells that have relationships
    int cellIndex = 0;
    for (int row = currentPuzzle!.wallHeight - 1; row >= 1; row--) {
      final cellsInRow = currentPuzzle!.wallHeight - row + 1;
      
      for (int col = 0; col < cellsInRow; col++) {
        final currentCell = cellIndex;
        final leftChild = cellIndex + cellsInRow;
        final rightChild = leftChild + 1;
        
        if (rightChild < currentPuzzle!.totalCells) {
          // Position symbol between the two child cells
          final leftPos = cellPositions[leftChild];
          final rightPos = cellPositions[rightChild];
          final symbolPos = Offset(
            (leftPos.dx + rightPos.dx) / 2,
            leftPos.dy + containerSize * 0.05,
          );
          
          symbols.add(Positioned(
            left: symbolPos.dx - 12,
            top: symbolPos.dy - 12,
            child: AnimatedBuilder(
              animation: _operationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _operationAnimation.value * 0.8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: operationColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: operationColor.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      operationIcon,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ));
        }
        cellIndex++;
      }
    }
    
    return symbols;
  }
  
  Widget _buildDroppableCell(int? value, int answerIndex, double size) {
    return GestureDetector(
      onTap: value != null ? () => _removeNumber(answerIndex) : null,
      child: _buildBrickCell(
        value: value,
        isSelected: _isDraggingOver && value == null,
        isHidden: true,
        size: size,
      ),
    );
  }

  Widget _buildFixedCell({required int value, double size = 70}) {
    return _buildBrickCell(
      value: value,
      isSelected: false,
      isHidden: false,
      size: size,
    );
  }

  Widget _buildBrickCell({
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
        borderRadius: BorderRadius.circular(8),
        gradient: _getCellGradient(isHidden, isSelected),
        border: Border.all(
          color: isSelected ? SpaceTheme.starYellow : 
                 currentPuzzle != null ? _getOperationColor(currentPuzzle!.operation) : SpaceTheme.alienGreen,
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
            shadows: const [Shadow(color: SpaceTheme.starYellow, blurRadius: 8)],
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
        Text(S.of(context)!.numberWallsBricks, style: SpaceTheme.bodyStyle),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              if (index >= numberPool.length) return Container();
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(
                  opacity: 0.3, 
                  child: _buildBrick(number)
                ),
                child: _buildBrick(number),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBrick(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(), 
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 18)
        )
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
          borderRadius: BorderRadius.circular(12),
          gradient: SpaceTheme.starGradient,
          boxShadow: const [
            BoxShadow(
              color: SpaceTheme.starYellow, 
              blurRadius: 20, 
              spreadRadius: 5
            )
          ],
        ),
        child: Center(
          child: Text(
            number.toString(), 
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)
          )
        ),
      ),
    );
  }
  
  LinearGradient _getCellGradient(bool isHidden, bool isSelected) {
    if (!isHidden && currentPuzzle != null) {
      final operationColor = _getOperationColor(currentPuzzle!.operation);
      return LinearGradient(colors: [operationColor, SpaceTheme.deepSpace]);
    }
    if (isSelected) {
      return const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    }
    return const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]);
  }

  List<BoxShadow> _getCellShadow(bool isSelected) {
    return [
      BoxShadow(
        color: isSelected ? SpaceTheme.starYellow : 
               currentPuzzle != null ? _getOperationColor(currentPuzzle!.operation) : SpaceTheme.alienGreen,
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
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.numberWallsWinTitle, 
                    style: SpaceTheme.headlineStyle, 
                    textAlign: TextAlign.center
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.numberWallsWinDesc(bonusScore),
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
                        child: Text(S.of(context)!.numberWallsNextWall),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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

class NumberWallPuzzle {
  final int wallHeight;
  final int totalCells;
  final WallOperation operation;
  final Set<int> hiddenCells;
  final Map<int, int> visibleValues;
  final List<int> fullSolution;
  final List<int> numberPool;

  NumberWallPuzzle({
    required this.wallHeight,
    required this.operation,
    required this.hiddenCells,
    required this.visibleValues,
    required this.fullSolution,
    required this.numberPool,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  int getAnswerIndex(int cellIndex) {
    int answerIndex = 0;
    for (int i = 0; i < totalCells; i++) {
      if (hiddenCells.contains(i)) {
        if (i == cellIndex) return answerIndex;
        answerIndex++;
      }
    }
    return -1;
  }

  static NumberWallPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    // --- Extract custom settings from the map ---
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    debugPrint("\n--- Generating Number Wall Puzzle ---");
    // --- Determine operation and height based on custom settings ---
    int wallHeight = _determineWallHeight(grade, level);
    WallOperation operation = _determineOperation(grade, level, useCustomSettings, customOps);
    debugPrint("[NumberWall] Parameters: Grade=$grade, Level=$level -> wallHeight=$wallHeight, operation=$operation");

    // --- Pass all settings to the generator ---
    final generator = _NumberWallGenerator(
      wallHeight, 
      grade, 
      level, 
      operation,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customRangeMin: customMin,
      customRangeMax: customMax
    );
    return generator.generate();
  }

  static int _determineWallHeight(int grade, int level) {
    if (grade >= 6) {
      if (level <= 3) return 4;
      if (level <= 7) return 5;
      return 6;
    }
    if (grade >= 4) {
      if (level <= 5) return 3;
      return 4;
    }
    return 3;
  }

  static WallOperation _determineOperation(int grade, int level, bool useCustom, Set<String> customOps) {
    if (useCustom && customOps.isNotEmpty) {
      final availableOps = customOps.map((op) {
        switch(op) {
          case 'addition': return WallOperation.addition;
          case 'subtraction': return WallOperation.subtraction;
          case 'multiplication': return WallOperation.multiplication;
          case 'division': return WallOperation.division;
          default: return WallOperation.addition;
        }
      }).toList();
      return availableOps[math.Random().nextInt(availableOps.length)];
    }

    // Original logic as fallback
    if (grade <= 3) {

      return WallOperation.addition;
    } else if (grade == 4) {
      return level <= 5 ? WallOperation.addition : 
             (level <= 8 ? WallOperation.subtraction : 
              (math.Random().nextBool() ? WallOperation.addition : WallOperation.subtraction));
    } else if (grade == 5) {
      final operations = [WallOperation.addition, WallOperation.subtraction];
      if (level >= 4) operations.add(WallOperation.multiplication);
      return operations[math.Random().nextInt(operations.length)];
    } else { // grade >= 6
      final operations = [
        WallOperation.addition, 
        WallOperation.subtraction, 
        WallOperation.multiplication,
      ];
      if (level >= 5) operations.add(WallOperation.division);
      return operations[math.Random().nextInt(operations.length)];
    }
  }

  List<Offset> getCellPositions(double containerSize) {
    final positions = <Offset>[];
    final cellSpacing = containerSize / (wallHeight + 2);
    final startY = containerSize * 0.15;
    
    int cellIndex = 0;
    for (int row = 0; row < wallHeight; row++) {
      final cellsInRow = wallHeight - row;
      final startX = containerSize / 2 - (cellsInRow - 1) * cellSpacing / 2;
      
      for (int col = 0; col < cellsInRow; col++) {
        positions.add(Offset(
          startX + col * cellSpacing,
          startY + row * cellSpacing
        ));
        cellIndex++;
      }
    }
    
    return positions;
  }

  bool validateSolution(List<int> userSolution) {
    debugPrint("✅ [NumberWall] validateSolution: $userSolution");
    
    // Build complete wall with user's answers
    final completeWall = List<int>.filled(totalCells, 0);
    int hiddenIdx = 0;
    
    for (int i = 0; i < totalCells; i++) {
      if (hiddenCells.contains(i)) {
        completeWall[i] = userSolution[hiddenIdx++];
      } else {
        completeWall[i] = visibleValues[i]!;
      }
    }
    
    debugPrint("✅ [NumberWall] Complete wall: $completeWall");
    
    // Validate the operation constraint
    return _validateOperationConstraints(completeWall, wallHeight, operation);
  }

  static bool _validateOperationConstraints(List<int> wall, int height, WallOperation operation) {
    int cellIndex = 0;
    
    for (int row = height - 1; row >= 1; row--) { // Start from second-to-last row
      final cellsInRow = height - row + 1;
      
      for (int col = 0; col < cellsInRow; col++) {
        final currentCell = cellIndex;
        final leftChild = cellIndex + cellsInRow;
        final rightChild = leftChild + 1;
        
        if (rightChild < wall.length) {
          final leftValue = wall[leftChild];
          final rightValue = wall[rightChild];
          final currentValue = wall[currentCell];
          
          bool isValid = false;
          
          switch (operation) {
            case WallOperation.addition:
              isValid = currentValue == leftValue + rightValue;
              break;
            case WallOperation.subtraction:
              // Allow both (left - right) and (right - left) to avoid negative numbers
              isValid = currentValue == (leftValue - rightValue).abs();
              break;
            case WallOperation.multiplication:
              isValid = currentValue == leftValue * rightValue;
              break;
            case WallOperation.division:
              // Allow both directions, result must be integer
              if (leftValue != 0 && rightValue != 0) {
                final div1 = leftValue / rightValue;
                final div2 = rightValue / leftValue;
                isValid = (div1 == currentValue && div1 == div1.roundToDouble()) ||
                         (div2 == currentValue && div2 == div2.roundToDouble());
              }
              break;
          }
          
          if (!isValid) {
            debugPrint("❌ [NumberWall] Validation failed at cell $currentCell: $currentValue != operation($leftValue, $rightValue)");
            return false;
          }
        }
        cellIndex++;
      }
    }
    
    debugPrint("✅ [NumberWall] Validation passed");
    return true;
  }
}

class _NumberWallGenerator {
  final int wallHeight;
  final int grade;
  final int level;
  final WallOperation operation;
  final int totalCells;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customRangeMin;
  final int customRangeMax;
  
  _NumberWallGenerator(this.wallHeight, this.grade, this.level, this.operation, {
    required this.useCustomSettings,
    required this.customOps,
    required this.customRangeMin,
    required this.customRangeMax,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  NumberWallPuzzle generate() {
    
    if (useCustomSettings) {
      debugPrint("\n🔧 ========== Custom Settings Active ==========");
      debugPrint("🔧 Operation: $operation (from '$customOps')");
      debugPrint("🔧 Wall Height: $wallHeight");
      debugPrint("🔧 Number Range: $customRangeMin - $customRangeMax");
      debugPrint("🔧 ==========================================\n");
    }

    debugPrint("[NumberWall] Starting generation for $wallHeight-row wall with $operation");

    
    int attempts = 0;
    List<int>? fullSolution;
    
    while (fullSolution == null && attempts < 10) {
      try {
        fullSolution = _generateValidWall();
        attempts++;
      } catch (e) {
        debugPrint("[NumberWall] Generation attempt $attempts failed: $e");
        attempts++;
      }
    }
    
    if (fullSolution == null) {
      debugPrint("❌ [NumberWall] Failed to generate valid wall, falling back to addition");
      final fallbackGenerator = _NumberWallGenerator(3, 3, 1, WallOperation.addition,
        useCustomSettings: false, customOps: {}, customRangeMin: 1, customRangeMax: 20
      );return fallbackGenerator.generate();
    }
    
    debugPrint("[NumberWall] Complete wall: $fullSolution");
    
    // Determine which cells to hide
    final hiddenCells = _selectHiddenCells();
    debugPrint("[NumberWall] Hidden cells: $hiddenCells");
    
    // Create visible values map
    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = fullSolution[i];
      }
    }
    
    // Create number pool
    final hiddenNumbers = hiddenCells.map((i) => fullSolution![i]).toList(); // note '!' null-check operator
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    
    debugPrint("[NumberWall] Number pool: $numberPool");
    
    return NumberWallPuzzle(
      wallHeight: wallHeight,
      operation: operation,
      hiddenCells: hiddenCells,
      visibleValues: visibleValues,
      fullSolution: fullSolution,
      numberPool: numberPool,
    );
  }

  List<int>? _generateValidWall() {
    switch (operation) {
      case WallOperation.addition:
        return _generateAdditionWall();
      case WallOperation.subtraction:
        return _generateSubtractionWall();
      case WallOperation.multiplication:
        return _generateMultiplicationWall();
      case WallOperation.division:
        return _generateDivisionWall();
    }
  }

  List<int> _generateAdditionWall() {
    final baseRowSize = wallHeight;
    final minNumber = _getMinNumber();
    final maxNumber = _getMaxNumber();
    
    final baseRow = List.generate(baseRowSize, (i) => 
      minNumber + math.Random().nextInt(maxNumber - minNumber + 1)
    );
    
    return _buildWallFromBase(baseRow, (a, b) => a + b);
  }

  List<int> _generateSubtractionWall() {
    // Start with larger numbers to avoid negatives
    final baseRowSize = wallHeight;
    final minNumber = _getMinNumber() + 5;
    final maxNumber = _getMaxNumber() + 10;
    
    final baseRow = List.generate(baseRowSize, (i) => 
      minNumber + math.Random().nextInt(maxNumber - minNumber + 1)
    );
    
    return _buildWallFromBase(baseRow, (a, b) => (a - b).abs());
  }

  List<int> _generateMultiplicationWall() {
    // Use smaller numbers for multiplication to avoid huge results
    final baseRowSize = wallHeight;
    final minNumber = math.max(1, _getMinNumber() ~/ 2);
    final maxNumber = math.max(4, _getMaxNumber() ~/ 3);
    
    final baseRow = List.generate(baseRowSize, (i) => 
      minNumber + math.Random().nextInt(maxNumber - minNumber + 1)
    );
    
    return _buildWallFromBase(baseRow, (a, b) => a * b);
  }

  List<int> _generateDivisionWall() {
    // Start from the top and work down to ensure integer divisions
    final wall = List<int>.filled(totalCells, 0);
    final random = math.Random();
    
    // Set top cell
    wall[0] = 8 + random.nextInt(20);
    
    // Work down the pyramid
    int cellIndex = 1;
    for (int row = 1; row < wallHeight; row++) {
      final cellsInRow = wallHeight - row + 1;
      
      for (int col = 0; col < cellsInRow; col++) {
        final parentIndex = cellIndex - (wallHeight - row + 2) + col;
        if (col == 0) {
          // First cell in row - choose a divisor
          final divisor = 2 + random.nextInt(4);
          wall[cellIndex] = wall[parentIndex] * divisor;
        } else {
          // Calculate from parent and left sibling
          final leftSibling = wall[cellIndex - 1];
          final parent = wall[parentIndex];
          // parent = leftSibling / rightSibling, so rightSibling = leftSibling / parent
          if (parent > 0 && leftSibling % parent == 0) {
            wall[cellIndex] = leftSibling ~/ parent;
          } else {
            wall[cellIndex] = 1 + random.nextInt(5);
          }
        }
        cellIndex++;
      }
    }
    
    return wall;
  }

  int _getMinNumber() {
    if (useCustomSettings) return customRangeMin;

    switch (operation) {
      case WallOperation.addition:
      case WallOperation.subtraction:
        return math.max(1, (grade - 2) * 3 + level);
      case WallOperation.multiplication:
        return math.max(1, grade);
      case WallOperation.division:
        return math.max(1, grade * 2);
    }
  }

  int _getMaxNumber() {
    if (useCustomSettings) return customRangeMax;
    
    switch (operation) {
      case WallOperation.addition:
      case WallOperation.subtraction:
        return _getMinNumber() + 15 + grade * 2;
      case WallOperation.multiplication:
        return _getMinNumber() + 6;
      case WallOperation.division:
        return _getMinNumber() + 12;
    }
  }

  List<int> _buildWallFromBase(List<int> baseRow, int Function(int, int) operation) {
    final wall = <int>[];
    
    // Initialize wall with zeros
    for (int i = 0; i < totalCells; i++) wall.add(0);
    
    // Fill bottom row
    final bottomRowStart = totalCells - wallHeight;
    for (int i = 0; i < wallHeight; i++) {
      wall[bottomRowStart + i] = baseRow[i];
    }
    
    // Build upward
    for (int row = wallHeight - 2; row >= 0; row--) {
      final cellsInRow = row + 1;
      final rowStartIndex = (row * (2 * wallHeight - row - 1)) ~/ 2;
      final belowRowStartIndex = ((row + 1) * (2 * wallHeight - row - 2)) ~/ 2;
      
      for (int col = 0; col < cellsInRow; col++) {
        final leftChild = belowRowStartIndex + col;
        final rightChild = leftChild + 1;
        wall[rowStartIndex + col] = operation(wall[leftChild], wall[rightChild]);
      }
    }
    
    return wall;
  }

  Set<int> _selectHiddenCells() {
    final hidden = <int>{};
    final totalHidden = (totalCells * 0.6).round().clamp(2, totalCells - 2);
    
    // Ensure we have a good distribution across rows
    int rowStart = 0;
    for (int row = 0; row < wallHeight; row++) {
      final cellsInRow = wallHeight - row;
      final cellsToHideInRow = math.max(1, (cellsInRow * 0.5).round());
      
      final rowIndices = List.generate(cellsInRow, (i) => rowStart + i);
      rowIndices.shuffle();
      
      for (int i = 0; i < cellsToHideInRow && hidden.length < totalHidden; i++) {
        hidden.add(rowIndices[i]);
      }
      
      rowStart += cellsInRow;
    }
    
    return hidden;
  }

  List<int> _generateDecoyNumbers(List<int> hiddenNumbers) {
    final decoys = <int>{};
    final random = math.Random();
    final decoyCount = (hiddenNumbers.length * 0.5).round().clamp(2, 6);
    
    for (final num in hiddenNumbers) {
      // Add numbers close to the actual answers
      final variations = [
        num + random.nextInt(3) + 1,
        num - random.nextInt(3) - 1,
        num + random.nextInt(5) + 3,
      ];
      
      for (final variation in variations) {
        if (variation > 0 && !hiddenNumbers.contains(variation)) {
          decoys.add(variation);
          if (decoys.length >= decoyCount) break;
        }
      }
      if (decoys.length >= decoyCount) break;
    }
    
    return decoys.toList();
  }
}

class NumberWallBackgroundPainter extends CustomPainter {
  final double glowIntensity;
  final double warpActivation;
  final WallOperation operation;

  const NumberWallBackgroundPainter({
    required this.glowIntensity,
    required this.warpActivation,
    required this.operation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Operation-specific background color
    Color baseColor;
    switch (operation) {
      case WallOperation.addition: baseColor = SpaceTheme.alienGreen; break;
      case WallOperation.subtraction: baseColor = SpaceTheme.cosmicPink; break;
      case WallOperation.multiplication: baseColor = SpaceTheme.starYellow; break;
      case WallOperation.division: baseColor = SpaceTheme.planetOrange; break;
    }
    
    // Background glow
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(0.1 * glowIntensity),
          SpaceTheme.deepSpace.withOpacity(0.05),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    
    canvas.drawCircle(center, size.width * 0.6, backgroundPaint);
    
    // Success warp effect
    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = baseColor.withOpacity(0.4 * warpActivation)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      final warpRadius = size.width * 0.3 * (1 + warpActivation);
      canvas.drawCircle(center, warpRadius, warpPaint);
    }
  }

  @override
  bool shouldRepaint(NumberWallBackgroundPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.warpActivation != warpActivation ||
      oldDelegate.operation != operation;
}