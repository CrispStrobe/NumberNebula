import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../constants/app_constants.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../../../core/services/sri_service.dart';

// DEVELOPMENT TWEAKING CONSTANTS
const bool kTweakProblems = false;  // Set to true to override normal generation
const String kTweakOps = 'multiplication'; // 'addition', 'subtraction', 'multiplication', 'division'
const int kTweakRangeMin = 2;
const int kTweakRangeMax = 8;
const int kTweakWallHeight = 4; // Override wall height when tweaking

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
  final GlobalKey _dragTargetKey = GlobalKey();

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
    debugPrint("🧱 NumberWallsGame.initState() - Grade ${widget.grade}, Level ${widget.level}");
    
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
    
    _generatePuzzle();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    _operationController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("🧱 _generatePuzzle() - Starting puzzle generation");
    
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
        'customOps': gameProvider.customOperations.toList(),
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
      };

      final puzzle = await compute(NumberWallPuzzle.generate, puzzleArgs);
      
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.generate(currentPuzzle!.hiddenCells.length, (_) => null);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
        debugPrint("🧱 Puzzle generated: ${currentPuzzle!.operation.name} wall, height ${currentPuzzle!.wallHeight}");
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

      // Record response in SRI system
      final sriService = context.read<SriService>();
      final dummyProblem = MathProblem(
        expression: "numberwall_${widget.level}_${currentPuzzle!.operation.name}",
        answer: isValid ? 1 : 0,
        operation: MathOperation.addition,
        operandA: 1,
        operandB: 0,
        difficulty: widget.grade,
      );
      sriService.recordResponse(dummyProblem, isValid);

      if (isValid) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    }
  }

  void _handleSuccess() {
    setState(() => _isWarping = true);
    _warpController.forward();

    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getOperationGradient(currentPuzzle!.operation),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getOperationColor(currentPuzzle!.operation), width: 3),
        boxShadow: [
          BoxShadow(
            color: _getOperationColor(currentPuzzle!.operation).withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _operationAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _operationAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getOperationIcon(currentPuzzle!.operation), 
                        color: Colors.white, 
                        size: 40
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getOperationTitle(currentPuzzle!.operation),
                    style: SpaceTheme.titleStyle.copyWith(
                      color: Colors.white, 
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getOperationDescription(currentPuzzle!.operation),
                    style: SpaceTheme.bodyStyle.copyWith(
                      color: Colors.white70, 
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (kTweakProblems) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'TWEAKING MODE: $kTweakOps (${kTweakRangeMin}-${kTweakRangeMax})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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

  String _getOperationDescription(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return 'Each brick = sum of two below';
      case WallOperation.subtraction: return 'Each brick = difference of two below';
      case WallOperation.multiplication: return 'Each brick = product of two below';
      case WallOperation.division: return 'Each brick = quotient of two below';
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
              
              final RenderBox? renderBox = _dragTargetKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) return;
              
              final localDropPosition = renderBox.globalToLocal(details.offset);
              final droppedNumber = details.data;

              int? closestCellIndex = _findClosestEmptyCell(localDropPosition, size);

              if (closestCellIndex != null) {
                _placeNumber(droppedNumber, closestCellIndex);
              }
            },
          ),
        );
      },
    );
  }
    
  int? _findClosestEmptyCell(Offset dropPosition, double containerSize) {
    if (currentPuzzle == null) return null;

    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.12;
    final double acceptanceRadius = cellSize;

    double minDistance = double.infinity;
    int? closestEmptyCellIndex;

    for (int cellIndex in currentPuzzle!.hiddenCells) {
      final answerIndex = currentPuzzle!.getAnswerIndexForCell(cellIndex);
      if (answerIndex != -1 && answerIndex < userAnswers.length && userAnswers[answerIndex] == null) {
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

  List<Widget> _buildWallCells(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> cells = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.12;
    
    for (int i = 0; i < currentPuzzle!.totalCells; i++) {
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

  List<Widget> _buildOperationSymbols(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> symbols = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final operationColor = _getOperationColor(currentPuzzle!.operation);
    final operationIcon = _getOperationIcon(currentPuzzle!.operation);
    
    for (int row = 0; row < currentPuzzle!.wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        if (rightChild < currentPuzzle!.totalCells) {
          final leftPos = cellPositions[leftChild];
          final rightPos = cellPositions[rightChild];
          final symbolPos = Offset(
            (leftPos.dx + rightPos.dx) / 2,
            leftPos.dy - containerSize * 0.06,
          );
          
          symbols.add(Positioned(
            left: symbolPos.dx - 16,
            top: symbolPos.dy - 16,
            child: AnimatedBuilder(
              animation: _operationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _operationAnimation.value * 0.9,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [operationColor, operationColor.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: operationColor.withOpacity(0.6), 
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(operationIcon, size: 18, color: Colors.white),
                  ),
                );
              },
            ),
          ));
        }
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
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18))
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
          boxShadow: const [BoxShadow(color: SpaceTheme.starYellow, blurRadius: 20)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22))
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
                  Text(S.of(context)!.numberWallsWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.numberWallsWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.toTheBridge),
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

// NumberWallPuzzle class with complete operation support
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

  int getAnswerIndexForCell(int cellIndex) {
    if (!hiddenCells.contains(cellIndex)) return -1;
    final sortedHiddenCells = hiddenCells.toList()..sort();
    return sortedHiddenCells.indexOf(cellIndex);
  }

  List<Offset> getCellPositions(double containerSize) {
    final positions = <Offset>[];
    final cellSpacing = containerSize / (wallHeight + 1);
    final startY = containerSize * 0.2;
    
    for (int row = 0; row < wallHeight; row++) {
      final cellsInRow = row + 1;
      final startX = containerSize / 2 - (cellsInRow - 1) * cellSpacing / 2;
      
      for (int col = 0; col < cellsInRow; col++) {
        positions.add(Offset(
          startX + col * cellSpacing,
          startY + row * cellSpacing
        ));
      }
    }
    
    return positions;
  }

  static NumberWallPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final wallHeight = _determineWallHeight(grade, level);
    final operation = _determineOperation(grade, level, useCustomSettings, customOps);

    final generator = _NumberWallGenerator(
      wallHeight,
      grade,
      level,
      operation,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customRangeMin: customMin,
      customRangeMax: customMax,
    );

    return generator.generate();
  }

  static int _determineWallHeight(int grade, int level) {
    // TWEAKING OVERRIDE
    if (kTweakProblems) {
      debugPrint("[NumberWall] 🔧 TWEAKING: Overriding wall height to $kTweakWallHeight");
      return kTweakWallHeight;
    }
    
    // Adjusted for grades 1-4 system
    if (grade >= 4) {
      if (level <= 4) return 4;
      if (level <= 8) return 5;
      return 6;
    }
    if (grade >= 3) {
      if (level <= 6) return 3;
      return 4;
    }
    return 3;
  }

  static WallOperation _determineOperation(int grade, int level, bool useCustom, Set<String> customOps) {
    // TWEAKING OVERRIDE
    if (kTweakProblems) {
      debugPrint("[NumberWall] 🔧 TWEAKING: Forcing operation to $kTweakOps");
      switch (kTweakOps.toLowerCase()) {
        case 'addition': return WallOperation.addition;
        case 'subtraction': return WallOperation.subtraction;
        case 'multiplication': 
        case 'multiply': return WallOperation.multiplication;
        case 'division': 
        case 'divide': return WallOperation.division;
        default: return WallOperation.addition;
      }
    }

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

    // Optimized progression for grades 1-4 (school years 3-6)
    if (grade == 1) {
      return WallOperation.addition; // Only addition for beginners
    } else if (grade == 2) {
      if (level <= 6) return WallOperation.addition;
      return math.Random().nextBool() ? WallOperation.addition : WallOperation.subtraction;
    } else if (grade == 3) {
      final operations = [WallOperation.addition, WallOperation.subtraction];
      if (level >= 5) operations.add(WallOperation.multiplication);
      return operations[math.Random().nextInt(operations.length)];
    } else { // grade 4
      final operations = [WallOperation.addition, WallOperation.subtraction, WallOperation.multiplication];
      if (level >= 6) operations.add(WallOperation.division);
      return operations[math.Random().nextInt(operations.length)];
    }
  }

  bool validateSolution(List<int> userSolution) {
    final completeWall = List<int>.filled(totalCells, 0);
    final sortedHiddenCells = hiddenCells.toList()..sort();
    
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        completeWall[i] = visibleValues[i]!;
      }
    }
    
    for (int answerIndex = 0; answerIndex < userSolution.length; answerIndex++) {
      if (answerIndex < sortedHiddenCells.length) {
        final cellIndex = sortedHiddenCells[answerIndex];
        completeWall[cellIndex] = userSolution[answerIndex];
      }
    }
    
    return _validateOperationConstraints(completeWall, wallHeight, operation);
  }

  static bool _validateOperationConstraints(List<int> wall, int height, WallOperation operation) {
    for (int row = 0; row < height - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        if (rightChild < wall.length) {
          final parentValue = wall[parentCell];
          final leftValue = wall[leftChild];
          final rightValue = wall[rightChild];
          
          bool isValid = false;
          
          switch (operation) {
            case WallOperation.addition:
              isValid = parentValue == leftValue + rightValue;
              break;
            case WallOperation.subtraction:
              isValid = parentValue == (leftValue - rightValue).abs();
              break;
            case WallOperation.multiplication:
              isValid = parentValue == leftValue * rightValue;
              break;
            case WallOperation.division:
              if (leftValue != 0 && rightValue != 0) {
                final div1 = leftValue / rightValue;
                final div2 = rightValue / leftValue;
                isValid = (div1 == parentValue && div1 == div1.roundToDouble()) ||
                          (div2 == parentValue && div2 == div2.roundToDouble());
              }
              break;
          }
          
          if (!isValid) return false;
        }
      }
    }
    
    return true;
  }
}

// Generator class with enhanced operation support
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
    List<int>? fullSolution;
    int attempts = 0;
    
    while (fullSolution == null && attempts < 50) {
      try {
        fullSolution = _generateValidWall();
        attempts++;
        
        if (fullSolution != null && _validateWallStructure(fullSolution)) {
          break;
        } else {
          fullSolution = null;
        }
      } catch (e) {
        attempts++;
      }
    }
    
    if (fullSolution == null) {
      fullSolution = _createFallbackWall();
    }
    
    final hiddenCells = _selectHiddenCells();
    
    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = fullSolution[i];
      }
    }
    
    final hiddenNumbers = hiddenCells.map((i) => fullSolution![i]).toList();
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    
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
      case WallOperation.addition: return _generateAdditionWall();
      case WallOperation.subtraction: return _generateSubtractionWall();
      case WallOperation.multiplication: return _generateMultiplicationWall();
      case WallOperation.division: return _generateDivisionWall();
    }
  }

  List<int> _generateAdditionWall() {
    final minNumber = _getMinNumber();
    final maxNumber = _getMaxNumber();
    
    final bottomRow = <int>[];
    for (int i = 0; i < wallHeight; i++) {
      bottomRow.add(minNumber + math.Random().nextInt(maxNumber - minNumber + 1));
    }
    
    return _buildWallFromBottom(bottomRow, (a, b) => a + b);
  }

  List<int> _generateSubtractionWall() {
    final minNumber = math.max(1, _getMinNumber());
    final maxNumber = _getMaxNumber() + 5;
    
    final bottomRow = <int>[];
    for (int i = 0; i < wallHeight; i++) {
      bottomRow.add(minNumber + math.Random().nextInt(maxNumber - minNumber + 1));
    }
    
    return _buildWallFromBottom(bottomRow, (a, b) => (a - b).abs());
  }

  List<int> _generateMultiplicationWall() {
    final minNumber = math.max(1, _getMinNumber() ~/ 2);
    final maxNumber = math.max(3, _getMaxNumber() ~/ 3);
    
    final bottomRow = <int>[];
    for (int i = 0; i < wallHeight; i++) {
      bottomRow.add(minNumber + math.Random().nextInt(maxNumber - minNumber + 1));
    }
    
    return _buildWallFromBottom(bottomRow, (a, b) => a * b);
  }

  List<int> _generateDivisionWall() {
    final wall = List<int>.filled(totalCells, 0);
    final random = math.Random();
    
    wall[0] = 6 + random.nextInt(15);
    
    for (int row = 0; row < wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        if (col == 0) {
          final divisor = 2 + random.nextInt(4);
          wall[leftChild] = wall[parentCell] * divisor;
        }
        
        if (rightChild < totalCells) {
          final leftValue = wall[leftChild];
          final parentValue = wall[parentCell];
          
          if (parentValue > 0 && leftValue % parentValue == 0) {
            wall[rightChild] = leftValue ~/ parentValue;
          } else {
            wall[rightChild] = 1 + random.nextInt(4);
          }
        }
      }
    }
    
    return wall;
  }

  List<int> _buildWallFromBottom(List<int> bottomRow, int Function(int, int) operation) {
    final wall = List<int>.filled(totalCells, 0);
    
    final bottomRowStart = (wallHeight - 1) * wallHeight ~/ 2;
    for (int i = 0; i < wallHeight; i++) {
      wall[bottomRowStart + i] = bottomRow[i];
    }
    
    for (int row = wallHeight - 2; row >= 0; row--) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final currentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        if (rightChild < wall.length) {
          wall[currentCell] = operation(wall[leftChild], wall[rightChild]);
        }
      }
    }
    
    return wall;
  }

  bool _validateWallStructure(List<int> wall) {
    return NumberWallPuzzle._validateOperationConstraints(wall, wallHeight, operation);
  }

  List<int> _createFallbackWall() {
    switch (operation) {
      case WallOperation.addition:
        if (wallHeight == 3) return [15, 7, 8, 3, 4, 4];
        if (wallHeight == 4) return [30, 13, 17, 5, 8, 9, 2, 3, 5, 4];
        break;
      case WallOperation.subtraction:
        if (wallHeight == 3) return [1, 3, 2, 5, 2, 4];
        break;
      case WallOperation.multiplication:
        if (wallHeight == 3) return [6, 2, 3, 2, 1, 3];
        break;
      case WallOperation.division:
        if (wallHeight == 3) return [2, 4, 2, 8, 2, 4];
        break;
    }
    
    return [15, 7, 8, 3, 4, 4]; // Default fallback
  }

  Set<int> _selectHiddenCells() {
    final hidden = <int>{};
    final maxHidden = math.min(4, totalCells - 2);
    final candidates = List.generate(totalCells, (i) => i)..shuffle();
    
    for (int i = 0; i < maxHidden; i++) {
      hidden.add(candidates[i]);
    }
    
    while (totalCells - hidden.length < 2 && hidden.isNotEmpty) {
      hidden.remove(hidden.first);
    }
    
    return hidden;
  }

  List<int> _generateDecoyNumbers(List<int> hiddenNumbers) {
    final decoys = <int>{};
    final decoyCount = math.min(3, hiddenNumbers.length);
    
    for (final num in hiddenNumbers) {
      if (decoys.length >= decoyCount) break;
      final variations = [num - 1, num - 2, num + 1, num + 2];
      for (final v in variations) {
        if (!hiddenNumbers.contains(v) && v > 0) {
          decoys.add(v);
          if (decoys.length >= decoyCount) break;
        }
      }
    }
    
    return decoys.toList();
  }

  int _getMinNumber() {
    if (kTweakProblems) {
      debugPrint("[NumberWall] 🔧 TWEAKING: Using min range $kTweakRangeMin");
      return kTweakRangeMin;
    }
    if (useCustomSettings) return customRangeMin;
    return math.max(1, (grade - 1) * 3 + level);
  }

  int _getMaxNumber() {
    if (kTweakProblems) {
      debugPrint("[NumberWall] 🔧 TWEAKING: Using max range $kTweakRangeMax");
      return kTweakRangeMax;
    }
    if (useCustomSettings) return customRangeMax;
    return _getMinNumber() + 12 + grade * 3;
  }
}

// Background painter for visual effects
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
    
    Color baseColor;
    switch (operation) {
      case WallOperation.addition: baseColor = SpaceTheme.alienGreen; break;
      case WallOperation.subtraction: baseColor = SpaceTheme.cosmicPink; break;
      case WallOperation.multiplication: baseColor = SpaceTheme.starYellow; break;
      case WallOperation.division: baseColor = SpaceTheme.planetOrange; break;
    }
    
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(0.1 * glowIntensity),
          SpaceTheme.deepSpace.withOpacity(0.05),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    
    canvas.drawCircle(center, size.width * 0.6, backgroundPaint);
    
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