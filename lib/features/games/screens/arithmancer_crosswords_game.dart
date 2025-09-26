import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:dart_csp/dart_csp.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../constants/app_constants.dart';
import '../../../core/services/sri_service.dart';

class ArithmancerCrosswordsGame extends StatefulWidget {
  final int grade;
  final int level;

  const ArithmancerCrosswordsGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<ArithmancerCrosswordsGame> createState() => _ArithmancerCrosswordsGameState();
}

class _ArithmancerCrosswordsGameState extends State<ArithmancerCrosswordsGame>
    with TickerProviderStateMixin {
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  CrosswordPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    debugPrint("🔤 [ARITHMANCER CROSSWORDS] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000), 
      vsync: this
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600), 
      vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), 
      vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    // Initialize difficulty from the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level);
        debugPrint("🔤 [ARITHMANCER CROSSWORDS] Difficulty initialized: ${currentDifficulty?.grade}");
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🔤 [ARITHMANCER CROSSWORDS] Disposing game and cleaning up resources");
    
    _glowController.stop();
    _successController.stop();
    _dropController.stop();
    _pulseController.stop();
    
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _pulseController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;
    
    debugPrint("🎯 [ARITHMANCER CROSSWORDS] Starting puzzle generation process");
    
    setState(() {
      _isGenerating = true;
      _successController.reset();
      userSolution.clear();
    });

    try {
      final gameProvider = context.read<GameProvider>();
      final puzzleArgs = {
        'grade': widget.grade,
        'level': widget.level,
        'difficulty': currentDifficulty!,
        'useCustomSettings': gameProvider.useCustomProblemSettings,
        'customOps': gameProvider.customOperations.toList(),
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
      };

      debugPrint("🎯 [ARITHMANCER CROSSWORDS] Calling compute function with args: $puzzleArgs");
      final generatedPuzzle = await compute(CrosswordPuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [ARITHMANCER CROSSWORDS] Puzzle generation completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool);
          _isGenerating = false;
        });
        debugPrint("🎯 [ARITHMANCER CROSSWORDS] UI state updated with new puzzle");
        debugPrint("🎯 [ARITHMANCER CROSSWORDS] Number pool: ${numberPool.join(', ')}");
        debugPrint("🎯 [ARITHMANCER CROSSWORDS] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [ARITHMANCER CROSSWORDS] Error generating puzzle: $e");
      debugPrint("❌ [ARITHMANCER CROSSWORDS] StackTrace: $stackTrace");
    }
  }

  void _placeNumber(int number, String cellId) {
    debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      numberPool.remove(number);
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);
    });

    debugPrint("🎮 [PLACE] User solution after: $userSolution");
    debugPrint("🎮 [PLACE] Number pool after: $numberPool");
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    debugPrint("🗑️ [ARITHMANCER CROSSWORDS] Removing number from cell $cellId");
    
    setState(() {
      final number = userSolution[cellId];
      if (number != null) {
        userSolution.remove(cellId);
        numberPool.add(number);
        numberPool.sort();
      }
    });
  }

  void _checkSolution() {
    debugPrint("✅ [ARITHMANCER CROSSWORDS] Checking solution...");
    debugPrint("✅ [ARITHMANCER CROSSWORDS] User solution: $userSolution");
    debugPrint("✅ [ARITHMANCER CROSSWORDS] Required cells: ${puzzle!.emptyCells.length}");
    
    if (userSolution.length == puzzle!.emptyCells.length) {
      debugPrint("✅ [ARITHMANCER CROSSWORDS] All cells filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [ARITHMANCER CROSSWORDS] Solution validation result: $isValid");
      
      if (isValid) {
        _logSolvedProblemsToSRI(userSolution);
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    } else {
      debugPrint("✅ [ARITHMANCER CROSSWORDS] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }

  void _logSolvedProblemsToSRI(Map<String, int> solution) {
    debugPrint("🔤 SRI: Logging all solved problems for the completed crossword...");
    final sriService = context.read<SriService>();
    
    // Create the complete solution
    final completeGrid = Map<String, int>.from(puzzle!.clues);
    completeGrid.addAll(solution);
    
    // Log each equation
    for (final equation in puzzle!.equations) {
      final values = equation.variableNames.map((varName) => completeGrid[varName]!).toList();
      
      // Create math problems for the equation: a op b = c
      final operand1 = values[0];
      final operand2 = values[1];
      final result = values[2];
      
      MathProblem? problem;
      switch (equation.operator) {
        case '+':
          problem = MathProblem.addition(operand1, operand2);
          break;
        case '−': // Using proper minus symbol
        case '-':
          problem = MathProblem.subtraction(math.max(operand1, operand2), math.min(operand1, operand2));
          break;
        case '×': // Using proper multiplication symbol
        case '*':
          problem = MathProblem.multiplication(operand1, operand2);
          break;
        case '÷': // Using proper division symbol
        case '/':
          if (operand2 != 0 && operand1 % operand2 == 0) {
            problem = MathProblem.division(operand1, operand2);
          } else if (operand1 != 0 && operand2 % operand1 == 0) {
            problem = MathProblem.division(operand2, operand1);
          }
          break;
      }
      
      if (problem != null) {
        sriService.recordResponse(problem, true);
        debugPrint("🔤 SRI: Logged equation problem -> ${problem.expression}");
      }
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [ARITHMANCER CROSSWORDS] SUCCESS! Player solved the puzzle!");
    
    int baseScore = 250 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 15 + puzzle!.emptyCells.length * 5;
    int operationBonus = puzzle!.getAllOperators()
        .map((op) => _getOperationBonus(op))
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    debugPrint("🎉 [ARITHMANCER CROSSWORDS] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    context.read<GameProvider>().addScore(totalScore);
    _successController.forward(from: 0.0);
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildSuccessDialog(complexityBonus + operationBonus),
      );
    }
  }

  int _getOperationBonus(String operation) {
    switch (operation) {
      case '+': return 0;
      case '−':
      case '-': return 15;
      case '×':
      case '*': return 25;
      case '÷':
      case '/': return 35;
      default: return 0;
    }
  }

  void _handleIncorrect() {
    debugPrint("❌ [ARITHMANCER CROSSWORDS] Incorrect solution - showing error message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.arithmancerCrosswordsError),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(S.of(context)!.loadingAdventure, style: SpaceTheme.bodyStyle),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxHeight < 500;
              final bool isWide = constraints.maxWidth > 750;

              return Column(
                children: [
                  _buildAdaptiveHeader(isCompact: isCompact),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(isCompact: isCompact)
                        : _buildCompactLayout(isCompact: isCompact),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveHeader({required bool isCompact}) {
    if (!isCompact) {
      return Column(
        children: [
          GameUI(
            title: S.of(context)!.arithmancerCrosswords,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              S.of(context)!.arithmancerCrosswordsInstructions,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.arithmancerCrosswords,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
                ),
                Text(
                  S.of(context)!.arithmancerCrosswordsInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildLevelIndicator(isCompact: true),
          const SizedBox(width: 8),
          _buildScoreIndicator(isCompact: true),
        ],
      ),
    );
  }

  Widget _buildWideLayout({required bool isCompact}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: _buildCrosswordArea(isCompact: isCompact),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildNumberPad(isCompact: isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout({required bool isCompact}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildCrosswordArea(isCompact: isCompact),
          ),
          SizedBox(height: isCompact ? 8 : 16),
          Expanded(
            flex: 2,
            child: _buildNumberPad(isCompact: isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildCrosswordArea({required bool isCompact}) {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink.withOpacity(0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink.withOpacity(_glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildCrossword(isCompact: isCompact),
          );
        },
      ),
    );
  }

  Widget _buildCrossword({required bool isCompact}) {
    if (puzzle == null) return Container();
    
    final cellSize = isCompact ? 35.0 : 45.0;
    final operatorSize = isCompact ? 20.0 : 25.0;
    
    // Calculate the bounding box of all cells
    final allPositions = <Point<int>>[
      ...puzzle!.numberCells.keys,
      ...puzzle!.operatorCells.keys,
    ];
    
    if (allPositions.isEmpty) return Container();
    
    final minX = allPositions.map((p) => p.x).reduce(math.min);
    final maxX = allPositions.map((p) => p.x).reduce(math.max);
    final minY = allPositions.map((p) => p.y).reduce(math.min);
    final maxY = allPositions.map((p) => p.y).reduce(math.max);
    
    final width = (maxX - minX + 1) * (cellSize + 4);
    final height = (maxY - minY + 1) * (cellSize + 4);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          width: width,
          height: height,
          child: Stack(
            children: [
              // Draw number cells
              ...puzzle!.numberCells.entries.map((entry) {
                final pos = entry.key;
                final cellId = entry.value;
                final x = (pos.x - minX) * (cellSize + 4);
                final y = (pos.y - minY) * (cellSize + 4);
                
                return Positioned(
                  left: x,
                  top: y,
                  child: _buildNumberCell(cellId, cellSize, isCompact),
                );
              }),
              
              // Draw operator cells
              ...puzzle!.operatorCells.entries.map((entry) {
                final pos = entry.key;
                final operator = entry.value;
                final x = (pos.x - minX) * (cellSize + 4);
                final y = (pos.y - minY) * (cellSize + 4);
                
                return Positioned(
                  left: x,
                  top: y,
                  child: _buildOperatorCell(operator, cellSize, operatorSize),
                );
              }),
              
              // Draw equals signs
              ...puzzle!.equalsCells.map((pos) {
                final x = (pos.x - minX) * (cellSize + 4);
                final y = (pos.y - minY) * (cellSize + 4);
                
                return Positioned(
                  left: x,
                  top: y,
                  child: _buildEqualsCell(cellSize, operatorSize),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCell(String cellId, double cellSize, bool isCompact) {
    final bool isEmpty = puzzle!.emptyCells.contains(cellId);
    final bool hasUserValue = userSolution.containsKey(cellId);
    final int? value = isEmpty 
        ? userSolution[cellId] 
        : puzzle!.clues[cellId];
    
    final bool isLastDropped = cellId == _lastDroppedPosition;

    Widget cell = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: isEmpty
            ? const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple])
            : const LinearGradient(colors: [SpaceTheme.cosmicPink, SpaceTheme.deepSpace]),
        border: Border.all(
          color: isEmpty ? SpaceTheme.nebulaPurple : SpaceTheme.cosmicPink,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          value?.toString() ?? '',
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: isCompact ? 14 : 16,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (isLastDropped) {
      cell = ScaleTransition(scale: _dropAnimation, child: cell);
    }

    if (isEmpty && !hasUserValue) {
      return DragTarget<int>(
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          
          return Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: isHovering
                  ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                  : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
              border: Border.all(
                color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                width: isHovering ? 3 : 2,
              ),
              boxShadow: isHovering ? [
                BoxShadow(
                  color: SpaceTheme.starYellow.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Center(
                    child: Icon(
                      Icons.add_circle_outline,
                      color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple.withOpacity(0.7),
                      size: cellSize * 0.4,
                    ),
                  ),
                );
              },
            ),
          );
        },
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
          _placeNumber(details.data, cellId);
        },
      );
    }

    if (isEmpty && hasUserValue) {
      return GestureDetector(
        onTap: () => _removeNumber(cellId),
        child: cell,
      );
    }

    return cell;
  }

  Widget _buildOperatorCell(String operator, double cellSize, double operatorSize) {
    return Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.deepSpace]),
        border: Border.all(color: SpaceTheme.starYellow, width: 2),
      ),
      child: Center(
        child: Text(
          operator,
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: operatorSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEqualsCell(double cellSize, double operatorSize) {
    return Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
      ),
      child: Center(
        child: Text(
          '=',
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: operatorSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad({required bool isCompact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(S.of(context)!.arithmancerCrosswordsSelectNumbers, style: SpaceTheme.bodyStyle),
          ),
        Container(
          padding: EdgeInsets.all(isCompact ? 8 : 12),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isCompact ? 5 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              if (index >= numberPool.length) return Container();
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildNumberTile(number, isCompact: isCompact)),
                child: _buildNumberTile(number, isCompact: isCompact),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumberTile(int number, {required bool isCompact}) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: isCompact ? 14 : 16),
        ),
      ),
    );
  }

  Widget _buildDraggableFeedback(int number) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SpaceTheme.starGradient,
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildLevelIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12, 
        vertical: isCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: SpaceTheme.starYellow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: iconSize),
          SizedBox(width: isCompact ? 4 : 8),
          Text(
            'Level ${widget.level}',
            style: SpaceTheme.titleStyle.copyWith(fontSize: fontSize),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 12, 
            vertical: isCompact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: SpaceTheme.alienGreen),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: SpaceTheme.alienGreen, size: iconSize),
              SizedBox(width: isCompact ? 4 : 8),
              Text(
                gameProvider.score.toString(),
                style: SpaceTheme.titleStyle.copyWith(fontSize: fontSize),
              ),
            ],
          ),
        );
      },
    );
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
                  Text(S.of(context)!.arithmancerCrosswordsWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.arithmancerCrosswordsWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(S.of(context)!.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the dialog
                          Navigator.of(context).pop(); // Close the game screen
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.backToMenu),
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

//##############################################################################
// CROSSWORD PUZZLE GENERATION SYSTEM (Following gencw.dart exactly)
//##############################################################################

/// Represents a Point in 2D space (Exact copy from gencw.dart)
class Point<T extends num> {
  final T x;
  final T y;
  
  const Point(this.x, this.y);
  
  @override
  bool operator ==(Object other) {
    return other is Point && other.x == x && other.y == y;
  }
  
  @override
  int get hashCode => Object.hash(x, y);
  
  @override
  String toString() => 'Point($x, $y)';
}

/// Represents a mathematical equation in the crossword (Exact copy from gencw.dart)
class CrosswordEquation {
  final List<Point<int>> numberCells;
  final Point<int> operatorCell;
  final String operator;
  
  CrosswordEquation(this.numberCells, this.operatorCell, this.operator);
  
  List<String> get variableNames =>
      numberCells.map((p) => 'C_${p.y}_${p.x}').toList();
      
  Set<Point<int>> get allCells {
    final op = operatorCell;
    final n1 = numberCells[0];
    final n2 = numberCells[1];
    final n3 = numberCells[2];
    return {
      n1,
      op,
      Point((op.x + n2.x) ~/ 2, (op.y + n2.y) ~/ 2),
      n2,
      Point((n2.x + n3.x) ~/ 2, (n2.y + n3.y) ~/ 2),
      n3
    };
  }

  @override
  String toString() =>
      '${variableNames[0]} $operator ${variableNames[1]} == ${variableNames[2]}';
}

/// Main crossword puzzle data structure
class CrosswordPuzzle {
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<CrosswordEquation> equations;
  final List<int> numberPool;
  final Map<String, int> fullSolution;
  
  // Visual layout data
  final Map<Point<int>, String> numberCells; // Position -> CellId
  final Map<Point<int>, String> operatorCells; // Position -> Operator
  final Set<Point<int>> equalsCells; // Positions of equals signs

  CrosswordPuzzle({
    required this.clues,
    required this.emptyCells,
    required this.equations,
    required this.numberPool,
    required this.fullSolution,
    required this.numberCells,
    required this.operatorCells,
    required this.equalsCells,
  });

  static Future<CrosswordPuzzle> generate(Map<String, dynamic> args) async {
    debugPrint("🎯 [CROSSWORD FACTORY] Starting puzzle generation with args: $args");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;
    
    debugPrint("🎯 [CROSSWORD FACTORY] Using difficulty config: ${difficultyConfig.grade}");
    
    final generator = CrosswordGenerator(
      grade: grade,
      level: level,
      difficultyConfig: difficultyConfig,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    
    return await generator.generate();
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [CROSSWORD VALIDATION] Starting solution validation");
    
    // Create complete solution
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(userSolution);
    
    // Validate all equations using the same logic as gencw.dart
    for (final equation in equations) {
      final values = equation.variableNames.map((varName) => completeGrid[varName]!).toList();
      final operand1 = values[0];
      final operand2 = values[1];
      final result = values[2];
      
      bool isValid = false;
      switch (equation.operator) {
        case '+':
          isValid = operand1 + operand2 == result;
          break;
        case '−':
        case '-':
          isValid = operand1 - operand2 == result;
          break;
        case '×':
        case '*':
          isValid = operand1 * operand2 == result;
          break;
        case '÷':
        case '/':
          isValid = operand2 != 0 && operand1 % operand2 == 0 && operand1 ~/ operand2 == result;
          break;
      }
      
      if (!isValid) {
        debugPrint("✅ [CROSSWORD VALIDATION] ❌ Equation failed: $equation -> $operand1 $operator $operand2 = $result");
        return false;
      }
    }
    
    debugPrint("✅ [CROSSWORD VALIDATION] ✅ Solution is valid!");
    return true;
  }

  List<String> getAllOperators() {
    return equations.map((eq) => eq.operator).toList();
  }
}

/// Grid pattern generator (Exact copy from gencw.dart)
class GridPatternGenerator {
  final int width;
  final int height;
  final int targetEdges;
  late List<List<String>> grid;
  final math.Random random = math.Random();
  int edgeCount = 0;
  late Point<int> mazeStart;
  late int firstDirection;
  final List<Point<int>> directions = [
    Point(0, -1), Point(1, 0), Point(0, 1), Point(-1, 0)
  ];

  GridPatternGenerator({
    this.width = 30,
    this.height = 25,
    required this.targetEdges,
  }) {
    initializeGrid();
    mazeStart = Point(width ~/ 2, height ~/ 2);
    firstDirection = random.nextInt(4);
    if (isValidPosition(mazeStart.x, mazeStart.y)) {
      grid[mazeStart.y][mazeStart.x] = '█';
    }
  }

  void initializeGrid() {
    grid = List.generate(height, (_) => List.generate(width, (_) => ' '));
  }

  bool isValidPosition(int x, int y) {
    return x >= 2 && x < width - 2 && y >= 2 && y < height - 2;
  }

  int countSquaresBehind(Point<int> pos, int direction) {
    Point<int> oppositeDir = directions[(direction + 2) % 4];
    int count = 0;
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (oppositeDir.x * step);
      int y = pos.y + (oppositeDir.y * step);
      if (!isValidPosition(x, y) || grid[y][x] != '█') break;
      count++;
    }
    return count;
  }

  bool canWalk4Steps(Point<int> pos, int direction) {
    if (countSquaresBehind(pos, direction) >= 4) return false;
    Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (!isValidPosition(x, y)) return false;
      if (step < 4 && grid[y][x] == '█') return false;
    }
    return true;
  }

  Point<int> walk4Steps(Point<int> pos, int direction) {
    Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (isValidPosition(x, y)) grid[y][x] = '█';
    }
    edgeCount++;
    return Point(pos.x + (dir.x * 4), pos.y + (dir.y * 4));
  }

  void runMazeWalker() {
    Point<int> currentPos = mazeStart;
    int currentDirection = firstDirection;

    for (int moves = 0; moves < 15 && edgeCount < targetEdges; moves++) {
      if (canWalk4Steps(currentPos, currentDirection)) {
        currentPos = walk4Steps(currentPos, currentDirection);
        int decision = random.nextInt(100);
        List<int> turnOptions = [(currentDirection + 1) % 4, (currentDirection + 3) % 4]
          ..shuffle(random);

        if (decision < 40) {
          Point<int> dir = directions[currentDirection];
          Point<int> backPos =
              Point(currentPos.x - (dir.x * 2), currentPos.y - (dir.y * 2));
          bool foundTurn = false;
          for (int newDir in turnOptions) {
            if (canWalk4Steps(backPos, newDir)) {
              currentPos = backPos;
              currentDirection = newDir;
              foundTurn = true;
              break;
            }
          }
          if (!foundTurn) break;
        } else {
          bool foundTurn = false;
          for (int newDir in turnOptions) {
            if (canWalk4Steps(currentPos, newDir)) {
              currentDirection = newDir;
              foundTurn = true;
              break;
            }
          }
          if (!foundTurn) break;
        }
      } else {
        List<int> turnOptions = [(currentDirection + 1) % 4, (currentDirection + 3) % 4]
          ..shuffle(random);
        bool foundTurn = false;
        for (int newDir in turnOptions) {
          if (canWalk4Steps(currentPos, newDir)) {
            currentDirection = newDir;
            foundTurn = true;
            break;
          }
        }
        if (!foundTurn) break;
      }
    }
  }

  List<List<String>> generatePattern() {
    for (int walker = 0; walker < 4 && edgeCount < targetEdges; walker++) {
      int oldEdgeCount = edgeCount;
      runMazeWalker();
      if (edgeCount == oldEdgeCount) break;
    }
    return grid;
  }
}

/// Puzzle parser (Exact copy from gencw.dart)
class PuzzleParser {
  final List<List<String>> grid;
  final List<String> availableOps;
  final math.Random random = math.Random();
  final List<CrosswordEquation> equations = [];
  final Set<Point<int>> numberCellLocations = {};

  PuzzleParser(this.grid, this.availableOps) {
    _findEquations();
  }

  void _findEquations() {
    int height = grid.length;
    int width = grid[0].length;
    
    // Find horizontal equations
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width - 4; c++) {
        if (List.generate(5, (i) => grid[r][c + i])
            .every((cell) => cell == '█')) {
          final numberCells = [Point(c, r), Point(c + 2, r), Point(c + 4, r)];
          final operatorCell = Point(c + 1, r);
          final eq = CrosswordEquation(numberCells, operatorCell,
              availableOps[random.nextInt(availableOps.length)]);
          equations.add(eq);
          numberCellLocations.addAll(numberCells);
        }
      }
    }
    
    // Find vertical equations
    for (int r = 0; r < height - 4; r++) {
      for (int c = 0; c < width; c++) {
        if (List.generate(5, (i) => grid[r + i][c])
            .every((cell) => cell == '█')) {
          final numberCells = [Point(c, r), Point(c, r + 2), Point(c, r + 4)];
          final operatorCell = Point(c, r + 1);
          final eq = CrosswordEquation(numberCells, operatorCell,
              availableOps[random.nextInt(availableOps.length)]);
          equations.add(eq);
          numberCellLocations.addAll(numberCells);
        }
      }
    }
  }

  bool isPatternValid() {
    if (equations.isEmpty) return false;
    int totalBlockCells = 0;
    for (var row in grid) {
      for (var cell in row) {
        if (cell == '█') totalBlockCells++;
      }
    }
    final cellsInEquations = <Point<int>>{};
    for (final eq in equations) {
      cellsInEquations.addAll(eq.allCells);
    }
    return totalBlockCells == cellsInEquations.length;
  }
}

/// ASCII Renderer for debugging (Exact copy from gencw.dart)
class AsciiRenderer {
  final PuzzleParser puzzle;
  final PuzzleConfig config;
  final Map<String, dynamic>? solution;
  late final int cellWidth;

  AsciiRenderer(this.puzzle, this.config, {this.solution}) {
    cellWidth = config.maxN.toString().length + 2;
  }

  String render() {
    if (puzzle.numberCellLocations.isEmpty) return "No valid equations found.";
    final equationCells = <Point<int>, String>{};
    for (final eq in puzzle.equations) {
      final mid1 = Point((eq.operatorCell.x + eq.numberCells[1].x) ~/ 2,
          (eq.operatorCell.y + eq.numberCells[1].y) ~/ 2);
      final mid2 = Point((eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
          (eq.numberCells[1].y + eq.numberCells[2].y) ~/ 2);
      equationCells[mid1] = eq.operator;
      equationCells[mid2] = '=';
    }
    final allDrawableCells = {
      ...puzzle.numberCellLocations,
      ...equationCells.keys
    };
    final minX = allDrawableCells.map((p) => p.x).reduce(math.min);
    final maxX = allDrawableCells.map((p) => p.x).reduce(math.max);
    final minY = allDrawableCells.map((p) => p.y).reduce(math.min);
    final maxY = allDrawableCells.map((p) => p.y).reduce(math.max);
    final canvasWidth = (maxX - minX + 1) * (cellWidth + 1) + 1;
    final canvasHeight = (maxY - minY + 1) * 2 + 1;
    var canvas = List.generate(canvasHeight, (_) => List.filled(canvasWidth, ' '));

    for (final point in allDrawableCells) {
      _drawBox(canvas, point.x - minX, point.y - minY);
    }
    for (final point in allDrawableCells) {
      String content = '';
      if (equationCells.containsKey(point)) {
        content = equationCells[point]!;
      } else if (puzzle.numberCellLocations.contains(point)) {
        final varName = 'C_${point.y}_${point.x}';
        content = solution?[varName]?.toString() ?? '';
      }
      _fillText(canvas, point.x - minX, point.y - minY, content);
    }
    return canvas.map((row) => row.join()).join('\n');
  }

  void _drawBox(List<List<String>> canvas, int x, int y) {
    int cx = x * (cellWidth + 1);
    int cy = y * 2;
    canvas[cy][cx] = '+';
    canvas[cy][cx + cellWidth] = '+';
    canvas[cy + 2][cx] = '+';
    canvas[cy + 2][cx + cellWidth] = '+';
    for (int i = 1; i < cellWidth; i++) {
      canvas[cy][cx + i] = '-';
      canvas[cy + 2][cx + i] = '-';
    }
    canvas[cy + 1][cx] = '|';
    canvas[cy + 1][cx + cellWidth] = '|';
  }

  void _fillText(List<List<String>> canvas, int x, int y, String text) {
    int cx = x * (cellWidth + 1) + (cellWidth ~/ 2) - (text.length - 1) ~/ 2;
    int cy = y * 2 + 1;
    for (int i = 0; i < text.length; i++) {
      if (cx + i < canvas[cy].length) {
        canvas[cy][cx + i] = text[i];
      }
    }
  }
}

/// Puzzle config for ASCII renderer
class PuzzleConfig {
  int minN;
  int maxN;
  List<String> ops;
  int targetEdges;
  int numClues;
  bool noDups;
  bool verbose;
  int timeoutSeconds;

  PuzzleConfig({
    this.minN = 1,
    this.maxN = 9,
    this.ops = const ['+', '−', '×', '÷'],
    this.targetEdges = 8,
    this.numClues = 0,
    this.noDups = false,
    this.verbose = false,
    this.timeoutSeconds = 30,
  });
}

/// Generator using the exact same approach as gencw.dart
class CrosswordGenerator {
  final int grade;
  final int level;
  final DifficultyConfig difficultyConfig;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customMin;
  final int customMax;
  final math.Random _random = math.Random();

  CrosswordGenerator({
    required this.grade,
    required this.level,
    required this.difficultyConfig,
    required this.useCustomSettings,
    required this.customOps,
    required this.customMin,
    required this.customMax,
  });

  Future<CrosswordPuzzle> generate() async {
    debugPrint("🔧 [CROSSWORD GENERATOR] Starting crossword generation");
    
    const maxAttempts = 100; // Same as gencw.dart
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint("🔧 [CROSSWORD GENERATOR] === Attempt $attempt/$maxAttempts ===");
      
      try {
        // Step 1: Generate a valid pattern (exact same logic as gencw.dart)
        debugPrint("🔧 [CROSSWORD GENERATOR] [1] Generating pattern...");
        PuzzleParser? puzzle;
        int patternAttempt = 0;
        
        do {
          patternAttempt++;
          final targetEdges = _determineTargetEdges();
          final generator = GridPatternGenerator(targetEdges: targetEdges);
          final rawGrid = generator.generatePattern();
          final availableOps = _getAvailableOperators();
          puzzle = PuzzleParser(rawGrid, availableOps);
        } while ((puzzle == null || !puzzle.isPatternValid()) && patternAttempt < 100);

        if (puzzle == null || !puzzle.isPatternValid()) {
          debugPrint("🔧 [CROSSWORD GENERATOR] FAILED to generate a valid puzzle pattern. Retrying...");
          continue;
        }

        final allVarNames = puzzle.numberCellLocations.map((p) => 'C_${p.y}_${p.x}').toList();
        debugPrint("🔧 [CROSSWORD GENERATOR] Pattern found with ${puzzle.equations.length} equations and ${allVarNames.length} cells.");

        // Step 2: Generate intelligent clues (EXACT same as gencw.dart)
        debugPrint("🔧 [CROSSWORD GENERATOR] [2] Generating clues...");
        final numClues = _determineNumberOfClues();
        final clues = <String, int>{};
        final domain = _getNumberDomain();

        // Power position selection (EXACT same logic as gencw.dart)
        final variableCounts = <String, int>{};
        for (final varName in allVarNames) {
          variableCounts[varName] = 0;
        }
        for (final eq in puzzle.equations) {
          for (final varName in eq.variableNames) {
            variableCounts[varName] = (variableCounts[varName] ?? 0) + 1;
          }
        }

        final candidates = [...allVarNames];
        final clueVars = <String>[];
        final disqualifiedEquations = <CrosswordEquation>{};

        for (int i = 0; i < numClues && candidates.isNotEmpty; i++) {
          candidates.sort((a, b) => variableCounts[b]!.compareTo(variableCounts[a]!));
          if (candidates.isEmpty) break;
          final bestCandidate = candidates.first;

          final chosenEquation = puzzle.equations.firstWhere(
            (eq) => eq.variableNames.contains(bestCandidate) && !disqualifiedEquations.contains(eq),
            orElse: () => puzzle!.equations.first,
          );

          String clueVariable;
          // EXACT same placement strategy as gencw.dart
          switch (chosenEquation.operator) {
            case '+':
            case '×':
              clueVariable = chosenEquation.variableNames[2]; // Result
              break;
            case '−':
            case '÷':
              clueVariable = chosenEquation.variableNames[0]; // First operand
              break;
            default:
              clueVariable = bestCandidate;
          }
          clueVars.add(clueVariable);
          disqualifiedEquations.add(chosenEquation);
          candidates.removeWhere((v) => chosenEquation.variableNames.contains(v));
        }

        final usedClueValues = <int>{};
        for (final clueVar in clueVars.toSet()) {
          int clueValue;
          do {
            clueValue = domain[_random.nextInt(domain.length)];
          } while (usedClueValues.contains(clueValue));
          clues[clueVar] = clueValue;
          usedClueValues.add(clueValue);
        }
        debugPrint("🔧 [CROSSWORD GENERATOR] Clues placed: $clues");

        // Step 3: Solve using CSP (EXACT same approach as gencw.dart)
        debugPrint("🔧 [CROSSWORD GENERATOR] [3] Solving puzzle with CSP...");
        final solution = await _solveWithCSP(puzzle, clues, allVarNames);

        if (solution == null) {
          debugPrint("🔧 [CROSSWORD GENERATOR] CSP solver failed");
          continue;
        }

        // Add ASCII debug output exactly like gencw.dart
        final puzzleConfig = PuzzleConfig(
          minN: _getNumberDomain().first,
          maxN: _getNumberDomain().last,
          ops: _getAvailableOperators(),
        );
        
        // Show empty puzzle (what player sees)
        final emptyRenderer = AsciiRenderer(puzzle, puzzleConfig, solution: clues);
        debugPrint("🔧 [CROSSWORD GENERATOR] [4] Puzzle to be solved:");
        debugPrint(emptyRenderer.render());
        
        // Show complete solution
        final solvedRenderer = AsciiRenderer(puzzle, puzzleConfig, solution: solution);
        debugPrint("🔧 [CROSSWORD GENERATOR] [5] Complete solution:");
        debugPrint(solvedRenderer.render());

        debugPrint("🔧 [CROSSWORD GENERATOR] ✅ SUCCESS! Solution found on attempt $attempt");

        // Step 4: Create final puzzle
        final emptyCells = <String>{};
        for (final varName in allVarNames) {
          if (!clues.containsKey(varName)) {
            emptyCells.add(varName);
          }
        }

        final correctNumbers = emptyCells.map((cellId) => solution[cellId]!).toList();
        final numberPool = _generateNumberPool(correctNumbers.cast<int>());

        // Create visual layout
        final (numberCells, operatorCells, equalsCells) = _createVisualLayout(puzzle);

        return CrosswordPuzzle(
          clues: clues,
          emptyCells: emptyCells,
          equations: puzzle.equations,
          numberPool: numberPool,
          fullSolution: solution,
          numberCells: numberCells,
          operatorCells: operatorCells,
          equalsCells: equalsCells,
        );

      } catch (e) {
        debugPrint("🔧 [CROSSWORD GENERATOR] Attempt $attempt failed: $e");
      }
    }
    
    throw Exception("Failed to generate a valid puzzle after $maxAttempts attempts");
  }

  int _determineTargetEdges() {
    // Adapt target edges based on grade/level like the original
    if (grade <= 2) return 4 + (level ~/ 3);
    if (grade <= 4) return 6 + (level ~/ 2);
    return 8 + level;
  }

  int _determineNumberOfClues() {
    // Same logic as gencw.dart - few or no clues to make it challenging
    if (grade <= 2) return 1;
    if (grade <= 3) return level <= 5 ? 1 : 0;
    return 0;
  }

  List<String> _getAvailableOperators() {
    // Convert framework operations to proper symbols (same as gencw.dart)
    if (useCustomSettings && customOps.isNotEmpty) {
      return customOps.map((op) {
        switch (op) {
          case 'addition': return '+';
          case 'subtraction': return '−';
          case 'multiplication': return '×';
          case 'division': return '÷';
          default: return '+';
        }
      }).toList();
    }

    final ops = <String>['+'];
    if (grade >= 2) ops.add('−');
    if (grade >= 3) ops.add('×');
    if (grade >= 4 && level >= 6) ops.add('÷');
    
    return ops;
  }

  List<int> _getNumberDomain() {
    final minVal = useCustomSettings ? customMin : math.max(1, grade);
    final maxVal = useCustomSettings ? customMax : math.min(9, 3 + grade * 2);
    return List<int>.generate(maxVal - minVal + 1, (i) => i + minVal);
  }

  // CSP solving with EXACT same approach as gencw.dart
  Future<Map<String, int>?> _solveWithCSP(PuzzleParser puzzle, Map<String, int> clues, List<String> allVarNames) async {
    final p = Problem();
    final fullDomain = _getNumberDomain();
    
    // Add variables (EXACT same as gencw.dart)
    for (final varName in allVarNames) {
      if (clues.containsKey(varName)) {
        p.addVariable(varName, [clues[varName]!]);
      } else {
        p.addVariable(varName, fullDomain);
      }
    }
    
    // Add constraints for each equation (EXACT same as gencw.dart)
    for (final eq in puzzle.equations) {
      p.addConstraint(eq.variableNames, (assignment) {
        final a = assignment[eq.variableNames[0]];
        final b = assignment[eq.variableNames[1]];
        final c = assignment[eq.variableNames[2]];
        if (a == null || b == null || c == null) return false;
        switch (eq.operator) {
          case '+':
            return a + b == c;
          case '−':
          case '-':
            return a - b == c;
          case '×':
          case '*':
            return a * b == c;
          case '÷':
          case '/':
            return b != 0 && a % b == 0 && a ~/ b == c;
          default:
            return false;
        }
      });
    }

    try {
      final solution = await p.getSolution().timeout(Duration(seconds: 30));
      
      if (solution == 'FAILURE') {
        return null;
      }
      
      return solution.cast<String, int>();
      
    } catch (e) {
      debugPrint("🔧 [CSP] Solver timeout or error: $e");
      return null;
    }
  }

  List<int> _generateNumberPool(List<int> correctNumbers) {
    final pool = <int>[];
    pool.addAll(correctNumbers);
    
    final domain = _getNumberDomain();
    
    // Add some decoy numbers
    final decoyCount = math.max(3, 6 - correctNumbers.length);
    final decoys = <int>{};
    
    while (decoys.length < decoyCount) {
      final decoy = domain[_random.nextInt(domain.length)];
      if (!correctNumbers.contains(decoy)) {
        decoys.add(decoy);
      }
    }
    
    pool.addAll(decoys);
    pool.shuffle(_random);
    
    return pool;
  }

  (Map<Point<int>, String>, Map<Point<int>, String>, Set<Point<int>>) _createVisualLayout(PuzzleParser puzzle) {
    final numberCells = <Point<int>, String>{};
    final operatorCells = <Point<int>, String>{};
    final equalsCells = <Set<Point<int>>>{};
    
    for (final eq in puzzle.equations) {
      // Number cells
      for (int i = 0; i < eq.numberCells.length; i++) {
        numberCells[eq.numberCells[i]] = eq.variableNames[i];
      }
      
      // Operator cell
      operatorCells[eq.operatorCell] = eq.operator;
      
      // Equals cell (between second number and result)
      final eqPos = Point(
        (eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
        (eq.numberCells[1].y + eq.numberCells[2].y) ~/ 2,
      );
      equalsCells.add({eqPos});
    }
    
    return (numberCells, operatorCells, equalsCells.expand((s) => s).toSet());
  }
}