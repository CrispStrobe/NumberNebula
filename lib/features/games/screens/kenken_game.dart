import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../constants/app_constants.dart';

class KenkenGame extends StatefulWidget {
  final int grade;
  final int level;

  const KenkenGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<KenkenGame> createState() => _KenkenGameState();
}

class _KenkenGameState extends State<KenkenGame>
    with TickerProviderStateMixin {
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  KenkenPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    debugPrint("🔲 [KENKEN] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    
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
      duration: const Duration(milliseconds: 1000),
      vsync: this
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    // Initialize difficulty from the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level);
        debugPrint("🔲 [KENKEN] Difficulty initialized: ${currentDifficulty?.grade}");
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🔲 [KENKEN] Disposing game and cleaning up resources");
    
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
    
    debugPrint("🎯 [KENKEN] Starting puzzle generation process");
    
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

      debugPrint("🎯 [KENKEN] Calling compute function with args: $puzzleArgs");
      final generatedPuzzle = await compute(KenkenPuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [KENKEN] Puzzle generation completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool);
          _isGenerating = false;
        });
        debugPrint("🎯 [KENKEN] UI state updated with new puzzle");
        debugPrint("🎯 [KENKEN] Number pool: ${numberPool.join(', ')}");
        debugPrint("🎯 [KENKEN] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [KENKEN] Error generating puzzle: $e");
      debugPrint("❌ [KENKEN] StackTrace: $stackTrace");
    }
  }

  void _placeNumber(int number, String cellId) {
    debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      // DON'T remove number from pool - numbers are reusable in Kenken
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);
    });

    debugPrint("🎮 [PLACE] User solution after: $userSolution");
    debugPrint("🎮 [PLACE] Number pool remains: $numberPool");
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    debugPrint("🗑️ [KENKEN] Removing number from cell $cellId");
    
    setState(() {
      userSolution.remove(cellId);
      // Don't add back to pool since numbers were never removed
    });
  }

  void _checkSolution() {
    debugPrint("✅ [KENKEN] Checking solution...");
    debugPrint("✅ [KENKEN] User solution: $userSolution");
    debugPrint("✅ [KENKEN] Required cells: ${puzzle!.emptyCells.length}");
    
    if (userSolution.length == puzzle!.emptyCells.length) {
      debugPrint("✅ [KENKEN] All cells filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [KENKEN] Solution validation result: $isValid");
      
      if (isValid) {
        // Extract problems ONCE for unified progression
        final mathProblems = _extractMathProblems(userSolution);
        _handleSuccess(mathProblems);
      } else {
        _handleIncorrect();
      }
    } else {
      debugPrint("✅ [KENKEN] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }

  List<MathProblem> _extractMathProblems(Map<String, int> solution) {
    debugPrint("🔲 [KENKEN] Extracting math problems from completed puzzle...");
    final problems = <MathProblem>[];
    
    // Create the complete grid with user solutions
    final completeGrid = Map<String, int>.from(puzzle!.clues);
    completeGrid.addAll(solution);
    
    // Extract each cage equation as math problem(s)
    for (final cage in puzzle!.cages) {
      if (cage.operation == null) {
        // Single-cell cage, no operation to track
        continue;
      }
      
      final values = cage.cells.map((cell) => completeGrid[cell.id]!).toList();
      final operation = cage.operation!;
      
      debugPrint("🔲 [KENKEN] Processing cage: ${cage.clue} with ${values.length} cells = $values");
      
      switch (operation.symbol) {
        case '+':
          // For addition, decompose multi-cell into binary operations
          // Example: 2+3+1 becomes (2+3=5) and (5+1=6)
          if (values.length >= 2) {
            int accumulator = values[0];
            for (int i = 1; i < values.length; i++) {
              final problem = MathProblem(
                operandA: accumulator,
                operandB: values[i],
                operation: MathOperation.addition,
                answer: accumulator + values[i],
                expression: '$accumulator + ${values[i]}',
                difficulty: widget.grade,
              );
              problems.add(problem);
              debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
              accumulator = problem.answer;
            }
          }
          break;
          
        case '-':
          // Subtraction is always 2 cells in Kenken
          if (values.length == 2) {
            final a = math.max(values[0], values[1]);
            final b = math.min(values[0], values[1]);
            final problem = MathProblem(
              operandA: a,
              operandB: b,
              operation: MathOperation.subtraction,
              answer: a - b,
              expression: '$a - $b',
              difficulty: widget.grade,
            );
            problems.add(problem);
            debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
          }
          break;
          
        case '×':
          // For multiplication, decompose multi-cell into binary operations
          // Example: 2×3×2 becomes (2×3=6) and (6×2=12)
          if (values.length >= 2) {
            int accumulator = values[0];
            for (int i = 1; i < values.length; i++) {
              final problem = MathProblem(
                operandA: accumulator,
                operandB: values[i],
                operation: MathOperation.multiplication,
                answer: accumulator * values[i],
                expression: '$accumulator × ${values[i]}',
                difficulty: widget.grade,
              );
              problems.add(problem);
              debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
              accumulator = problem.answer;
            }
          }
          break;
          
        case '÷':
          // Division is always 2 cells in Kenken
          if (values.length == 2) {
            final a = math.max(values[0], values[1]);
            final b = math.min(values[0], values[1]);
            if (b != 0 && a % b == 0) {
              final problem = MathProblem(
                operandA: a,
                operandB: b,
                operation: MathOperation.division,
                answer: a ~/ b,
                expression: '$a ÷ $b',
                difficulty: widget.grade,
              );
              problems.add(problem);
              debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
            }
          }
          break;
      }
    }
    
    debugPrint("🔲 [KENKEN] Extracted ${problems.length} math problems total");
    return problems;
  }

  void _handleSuccess(List<MathProblem> mathProblems) {
    debugPrint("🎉 [KENKEN] SUCCESS! Player solved the puzzle!");
    HapticFeedback.lightImpact();

    int baseScore = 300 * widget.grade;
    int complexityBonus = puzzle!.size * puzzle!.size * 15 + puzzle!.cages.length * 20;
    int operationBonus = puzzle!.getAllOperators()
        .map((op) => _getOperationBonus(op))
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    debugPrint("🎉 [KENKEN] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // SINGLE CALL to unified progression system
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'kenken',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: mathProblems,
    ));
    
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
      case '-': return 15;
      case '×': return 25;
      case '÷': return 35;
      default: return 0;
    }
  }

  void _handleIncorrect() {
    debugPrint("❌ [KENKEN] Incorrect solution - showing error message");
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.kenkenError)),
          ],
        ),
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
              final bool isWide = constraints.maxWidth > 700;

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
            title: S.of(context)!.kenken,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              S.of(context)!.kenkenInstructions,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    S.of(context)!.kenken,
                    style: SpaceTheme.headlineStyle,
                  ),
                ),
                Text(
                  S.of(context)!.kenkenInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(color: Colors.white70),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildGridArea(isCompact: isCompact),
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
            child: _buildGridArea(isCompact: isCompact),
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

  Widget _buildGridArea({required bool isCompact}) {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12), // Reduced padding
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink.withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildKenkenGrid(isCompact: isCompact),
          );
        },
      ),
    );
  }

  Widget _buildKenkenGrid({required bool isCompact}) {
    // Much more generous sizing - use most of the available space
    final gridSize = puzzle!.size;
    final maxGridWidth = isCompact ? 350.0 : 500.0; // Increased from 300
    final maxCellSize = isCompact ? 45.0 : 70.0; // Increased from 35/50
    final cellSize = math.min(maxCellSize, maxGridWidth / gridSize);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(gridSize, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(gridSize, (col) {
            final cellId = 'r${row}c$col';
            return _buildKenkenCell(cellId, row, col, cellSize, isCompact);
          }),
        );
      }),
    );
  }

  Widget _buildKenkenCell(String cellId, int row, int col, double cellSize, bool isCompact) {
    final cell = puzzle!.board[row][col];
    final cage = puzzle!.getCageForCell(cell);
    final bool isEmpty = puzzle!.emptyCells.contains(cellId);
    final bool hasUserValue = userSolution.containsKey(cellId);
    final int? value = isEmpty ? userSolution[cellId] : puzzle!.clues[cellId];
    final bool isLastDropped = cellId == _lastDroppedPosition;
    
    // Determine if this cell should show the cage clue
    final bool showClue = cage != null && cage.getTopLeftCell() == cell && cage.clue != null;
    
    // Determine border style based on cage membership
    final borderSides = _getCageBorderSides(cell, cage, row, col);

    Widget cellWidget = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        gradient: isEmpty
            ? const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple])
            : const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
        border: Border(
          top: BorderSide(
            color: borderSides['top']! ? SpaceTheme.starYellow : Colors.grey.shade600,
            width: borderSides['top']! ? 3 : 1,
          ),
          right: BorderSide(
            color: borderSides['right']! ? SpaceTheme.starYellow : Colors.grey.shade600,
            width: borderSides['right']! ? 3 : 1,
          ),
          bottom: BorderSide(
            color: borderSides['bottom']! ? SpaceTheme.starYellow : Colors.grey.shade600,
            width: borderSides['bottom']! ? 3 : 1,
          ),
          left: BorderSide(
            color: borderSides['left']! ? SpaceTheme.starYellow : Colors.grey.shade600,
            width: borderSides['left']! ? 3 : 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Clue in top-left corner
          if (showClue)
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cage.clue!
                      .replaceAll('÷', context.read<GameProvider>().divisionSymbol)
                      .replaceAll('×', context.read<GameProvider>().multiplicationSymbol),
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.deepSpace,
                  ),
                ),
              ),
            ),
          // Value in center
          Center(
            child: Text(
              value?.toString() ?? '',
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: isCompact ? 16 : 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (isLastDropped) {
      cellWidget = ScaleTransition(scale: _dropAnimation, child: cellWidget);
    }

    if (isEmpty && !hasUserValue) {
      return DragTarget<int>(
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          
          return Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              gradient: isHovering
                  ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                  : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
              border: Border(
                top: BorderSide(
                  color: borderSides['top']! ? SpaceTheme.starYellow : Colors.grey.shade600,
                  width: borderSides['top']! ? 3 : 1,
                ),
                right: BorderSide(
                  color: borderSides['right']! ? SpaceTheme.starYellow : Colors.grey.shade600,
                  width: borderSides['right']! ? 3 : 1,
                ),
                bottom: BorderSide(
                  color: borderSides['bottom']! ? SpaceTheme.starYellow : Colors.grey.shade600,
                  width: borderSides['bottom']! ? 3 : 1,
                ),
                left: BorderSide(
                  color: borderSides['left']! ? SpaceTheme.starYellow : Colors.grey.shade600,
                  width: borderSides['left']! ? 3 : 1,
                ),
              ),
              boxShadow: isHovering ? [
                BoxShadow(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: Stack(
              children: [
                // Clue in top-left corner
                if (showClue)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cage.clue!
                            .replaceAll('÷', context.read<GameProvider>().divisionSymbol)
                            .replaceAll('×', context.read<GameProvider>().multiplicationSymbol),
                        style: TextStyle(
                          fontSize: isCompact ? 10 : 12,
                          fontWeight: FontWeight.bold,
                          color: SpaceTheme.deepSpace,
                        ),
                      ),
                    ),
                  ),
                // Pulse animation in center
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                          size: cellSize * 0.3,
                        ),
                      ),
                    );
                  },
                ),
              ],
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
      return Semantics(
        button: true,
        label: 'Placed value, tap to remove',
        child: GestureDetector(
          onTap: () => _removeNumber(cellId),
          child: cellWidget,
        ),
      );
    }

    return cellWidget;
  }

  Map<String, bool> _getCageBorderSides(KenkenCell cell, KenkenCage? cage, int row, int col) {
    if (cage == null) {
      return {'top': true, 'right': true, 'bottom': true, 'left': true};
    }
    
    return {
      'top': row == 0 || !cage.containsCell(row - 1, col),
      'right': col == puzzle!.size - 1 || !cage.containsCell(row, col + 1),
      'bottom': row == puzzle!.size - 1 || !cage.containsCell(row + 1, col),
      'left': col == 0 || !cage.containsCell(row, col - 1),
    };
  }

  Widget _buildNumberPad({required bool isCompact}) {
    final gridSize = puzzle!.size;
    
    // Use the SAME cell size calculation as the grid
    final maxGridWidth = isCompact ? 350.0 : 500.0;
    final maxCellSize = isCompact ? 45.0 : 70.0;
    final cellSize = math.min(maxCellSize, maxGridWidth / gridSize);
    
    // Arrange numbers in 3 columns like a phone keypad
    final numbers = numberPool;
    final rows = <List<int>>[];
    
    for (int i = 0; i < numbers.length; i += 3) {
      final rowNumbers = numbers.sublist(i, math.min(i + 3, numbers.length));
      rows.add(rowNumbers);
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isCompact && gridSize <= 6)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(S.of(context)!.kenkenSelectNumbers, style: SpaceTheme.bodyStyle),
          ),
        Container(
          padding: EdgeInsets.all(isCompact ? 6 : 12),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rows.map((rowNumbers) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 8.0 : 0),
                        child: i < rowNumbers.length
                            ? SizedBox(
                                width: cellSize,
                                height: cellSize,
                                child: Semantics(
                                  label: 'Number ${rowNumbers[i]}, drag to a cell',
                                  button: true,
                                  child: Draggable<int>(
                                    data: rowNumbers[i],
                                    feedback: _buildDraggableFeedback(rowNumbers[i], isCompact),
                                    childWhenDragging: Opacity(
                                      opacity: 0.7,
                                      child: _buildNumberTile(rowNumbers[i], tileSize: cellSize)
                                    ),
                                    child: _buildNumberTile(rowNumbers[i], tileSize: cellSize),
                                  ),
                                ),
                              )
                            : SizedBox(width: cellSize, height: cellSize), // Empty space
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberTile(int number, {double? tileSize}) {
    final size = tileSize ?? 50.0;
    final fontSize = size < 40 ? 14.0 : (size < 45 ? 16.0 : 18.0);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(size < 40 ? 8 : 12),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
        ),
      ),
    );
  }

  Widget _buildDraggableFeedback(int number, [bool isSmall = false]) {
    final size = isSmall ? 40.0 : 60.0;
    final fontSize = isSmall ? 18.0 : 22.0;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SpaceTheme.starGradient,
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize)),
        ),
      ),
    );
  }

  Widget _buildLevelIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    final levelText = '${S.of(context)?.level ?? 'Level'} ${widget.level}';
    return Semantics(
      label: levelText,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 12,
            vertical: isCompact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: SpaceTheme.starYellow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: iconSize),
              SizedBox(width: isCompact ? 4 : 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  levelText,
                  style: SpaceTheme.titleStyle.copyWith(fontSize: fontSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    final scoreLabel = S.of(context)?.score ?? 'Score';
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Semantics(
          label: '$scoreLabel ${gameProvider.score}',
          liveRegion: true,
          container: true,
          child: ExcludeSemantics(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 12,
                vertical: isCompact ? 4 : 8,
              ),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: SpaceTheme.alienGreen),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: SpaceTheme.alienGreen, size: iconSize),
                  SizedBox(width: isCompact ? 4 : 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      gameProvider.score.toString(),
                      style: SpaceTheme.titleStyle.copyWith(fontSize: fontSize),
                    ),
                  ),
                ],
              ),
            ),
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
                  Text(S.of(context)!.kenkenWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.kenkenWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
// KENKEN PUZZLE GENERATION SYSTEM (Following kenken_generator.dart exactly)
//##############################################################################

/// Represents a Kenken puzzle following the exact algorithm from the blueprint
class KenkenPuzzle {
  final int size;
  final List<List<KenkenCell>> board;
  final List<KenkenCage> cages;
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<int> numberPool;
  final Map<String, int> fullSolution;

  KenkenPuzzle({
    required this.size,
    required this.board,
    required this.cages,
    required this.clues,
    required this.emptyCells,
    required this.numberPool,
    required this.fullSolution,
  });

  static Future<KenkenPuzzle> generate(Map<String, dynamic> args) async {
    debugPrint("🎯 [KENKEN FACTORY] Starting puzzle generation with args: $args");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;
    
    debugPrint("🎯 [KENKEN FACTORY] Using difficulty config: ${difficultyConfig.grade}");
    
    final generator = KenkenGenerator(
      grade: grade,
      level: level,
      difficultyConfig: difficultyConfig,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    
    return generator.generate();
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [KENKEN VALIDATION] Starting solution validation");
    
    // Create complete grid
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(userSolution);
    
    // Validate Latin square property (each row and column contains each number exactly once)
    for (int r = 0; r < size; r++) {
      final rowValues = <int>[];
      for (int c = 0; c < size; c++) {
        rowValues.add(completeGrid['r${r}c$c']!);
      }
      if (!_isValidLatinSequence(rowValues)) {
        debugPrint("✅ [KENKEN VALIDATION] ❌ Row $r violates Latin square property: $rowValues");
        return false;
      }
    }
    
    for (int c = 0; c < size; c++) {
      final colValues = <int>[];
      for (int r = 0; r < size; r++) {
        colValues.add(completeGrid['r${r}c$c']!);
      }
      if (!_isValidLatinSequence(colValues)) {
        debugPrint("✅ [KENKEN VALIDATION] ❌ Column $c violates Latin square property: $colValues");
        return false;
      }
    }
    
    // Validate all cage constraints
    for (final cage in cages) {
      if (!cage.validateConstraint(completeGrid)) {
        debugPrint("✅ [KENKEN VALIDATION] ❌ Cage constraint failed: ${cage.clue}");
        return false;
      }
    }
    
    debugPrint("✅ [KENKEN VALIDATION] ✅ Solution is valid!");
    return true;
  }

  bool _isValidLatinSequence(List<int> values) {
    final expected = List.generate(size, (i) => i + 1);
    final sorted = List.from(values)..sort();
    return sorted.length == expected.length && 
           sorted.every((val) => expected.contains(val)) &&
           expected.every((val) => sorted.contains(val));
  }

  KenkenCage? getCageForCell(KenkenCell cell) {
    return cages.firstWhere((cage) => cage.cells.contains(cell));
  }

  List<String> getAllOperators() {
    return cages
        .where((cage) => cage.operation != null)
        .map((cage) => cage.operation!.symbol)
        .toList();
  }
}

/// Individual cell in the Kenken grid
class KenkenCell {
  final int value;
  int x;
  int y;
  KenkenCage? group;
  
  KenkenCell({required this.value, required this.x, required this.y});
  
  String get id => 'r${y}c$x';
}

/// Cage containing multiple cells (direct port from blueprint)
class KenkenCage {
  final int id;
  final KenkenGenerator kenken;
  final List<KenkenCell> cells = [];
  String? clue;
  KenkenOperation? operation;

  KenkenCage({required this.id, required this.kenken});

  void addCell(KenkenCell cell) {
    cells.add(cell);
    cell.group = this;
  }

  List<int> getValues() => cells.map((c) => c.value).toList();

  KenkenCell getTopLeftCell() {
    KenkenCell topLeft = cells.first;
    for (final cell in cells) {
      if (cell.y < topLeft.y || (cell.y == topLeft.y && cell.x < topLeft.x)) {
        topLeft = cell;
      }
    }
    return topLeft;
  }

  bool containsCell(int row, int col) {
    return cells.any((cell) => cell.y == row && cell.x == col);
  }
  
  List<KenkenCell> _getGrowthCandidates(KenkenCell cell) {
    final candidates = <KenkenCell>[];
    final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final dir in directions) {
      int nx = cell.x + dir[1];
      int ny = cell.y + dir[0];
      if (ny >= 0 && ny < kenken.size && nx >= 0 && nx < kenken.size) {
        final neighbor = kenken.board[ny][nx];
        if (neighbor.group == null) {
          candidates.add(neighbor);
        }
      }
    }
    return candidates;
  }

  bool grow() {
    final growthCandidates = <KenkenCell>[];
    for (final cell in cells) {
      growthCandidates.addAll(_getGrowthCandidates(cell));
    }
    if (growthCandidates.isEmpty) return false;
    final cellToAdd = growthCandidates[kenken._random.nextInt(growthCandidates.length)];
    addCell(cellToAdd);
    return true;
  }

  bool validateConstraint(Map<String, int> grid) {
    if (cells.length == 1) {
      // Single cell cages just need to match their value
      final expectedValue = int.tryParse(clue ?? '');
      if (expectedValue == null) return false;
      return grid[cells.first.id] == expectedValue;
    }
    
    if (operation == null || clue == null) return false;
    
    final values = cells.map((cell) => grid[cell.id]!).toList();
    final result = operation!.calculate(values);
    final expectedResult = int.tryParse(clue!.replaceAll(operation!.symbol, ''));
    
    return result == expectedResult;
  }
}

/// Abstract base class for Kenken operations (exact port from blueprint)
abstract class KenkenOperation {
  final String symbol;
  final int minCells;
  final int? maxCells;
  
  KenkenOperation({required this.symbol, required this.minCells, this.maxCells});
  
  int? calculate(List<int> numbers);
}

class KenkenAddition extends KenkenOperation {
  KenkenAddition() : super(symbol: '+', minCells: 2);
  
  @override
  int? calculate(List<int> numbers) => numbers.reduce((a, b) => a + b);
}

class KenkenSubtraction extends KenkenOperation {
  KenkenSubtraction() : super(symbol: '-', minCells: 2, maxCells: 2);
  
  @override
  int? calculate(List<int> numbers) => (numbers[0] - numbers[1]).abs();
}

class KenkenMultiplication extends KenkenOperation {
  KenkenMultiplication() : super(symbol: '×', minCells: 2);
  
  @override
  int? calculate(List<int> numbers) => numbers.reduce((a, b) => a * b);
}

class KenkenDivision extends KenkenOperation {
  KenkenDivision() : super(symbol: '÷', minCells: 2, maxCells: 2);
  
  @override
  int? calculate(List<int> numbers) {
    final n1 = numbers[0];
    final n2 = numbers[1];
    if (n1 % n2 == 0) return (n1 ~/ n2);
    if (n2 % n1 == 0) return (n2 ~/ n1);
    return null;
  }
}

/// Generator following the exact algorithm from the blueprint
class KenkenGenerator {
  final int grade;
  final int level;
  final DifficultyConfig difficultyConfig;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customMin;
  final int customMax;
  late math.Random _random;

  late final int size;
  late final int maxGroupSize;
  late final List<KenkenOperation> operations;
  late final int? minResult;
  late final int? maxResult;
  late final bool strictOperations;
  late final bool verbose;
  List<List<KenkenCell>> board = [];
  List<KenkenCage> cages = [];

  KenkenGenerator({
    required this.grade,
    required this.level,
    required this.difficultyConfig,
    required this.useCustomSettings,
    required this.customOps,
    required this.customMin,
    required this.customMax,
  }) {
    _random = math.Random();
  }

  Future<KenkenPuzzle> generate() async {
    debugPrint("🔧 [KENKEN GENERATOR] Starting Kenken generation");
    
    // Initialize parameters based on grade/level (following blueprint logic)
    _initializeParameters();
    
    const maxSeeds = 50;
    const maxRetries = 1000;
    
    for (int seedTry = 1; seedTry <= maxSeeds; seedTry++) {
      debugPrint("🔧 [KENKEN GENERATOR] === SEED $seedTry/$maxSeeds ===");
      
      int currentBaseSeed = _random.nextInt(1000000000);
      
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        int currentSeed = currentBaseSeed + (attempt * 1000) + (attempt * attempt * 137);
        
        try {
          final puzzle = await _attemptGeneration(currentSeed);
          if (puzzle != null) {
            debugPrint("🔧 [KENKEN GENERATOR] ✅ SUCCESS! Generated valid puzzle on seed $seedTry, attempt $attempt");
            return puzzle;
          }
        } catch (e) {
          if (attempt <= 3) {
            debugPrint("🔧 [KENKEN GENERATOR] ❌ Attempt $attempt failed: $e");
          }
        }
      }
    }
    
    throw Exception("Failed to generate a valid Kenken puzzle after trying $maxSeeds seeds with $maxRetries attempts each");
  }

  void _initializeParameters() {
    // PROPER scaling based on grade/level - much more aggressive for high levels
    if (grade <= 1) {
      size = 3;
    } else if (grade <= 2) {
      size = level <= 5 ? 3 : 4;
    } else if (grade <= 3) {
      size = level <= 3 ? 4 : level <= 8 ? 5 : 6;
    } else { // Grade 4+
      size = level <= 5 ? 5 : level <= 10 ? 6 : level <= 15 ? 7 : level <= 20 ? 8 : 9;
    }
    
    maxGroupSize = 4; // Fixed as in blueprint
    
    // Operations based on custom settings or grade
    operations = _getAvailableOperations();
    
    // Result range based on custom settings or defaults
    if (useCustomSettings) {
      minResult = customMin;
      maxResult = customMax;
    } else {
      minResult = null; // Let operations determine natural bounds
      maxResult = null;
    }
    
    // EXACT blueprint settings
    strictOperations = false; // BLUEPRINT DEFAULT: allow fallback to addition
    verbose = true; // NEW: verbose logging
    
    debugPrint("🔧 [KENKEN GENERATOR] Initialized: size=$size, maxGroupSize=$maxGroupSize, operations=${operations.map((o) => o.symbol).join(',')}, range=${minResult ?? 'any'}-${maxResult ?? 'any'}");
  }

  List<KenkenOperation> _getAvailableOperations() {
    if (useCustomSettings && customOps.isNotEmpty) {
      return customOps.map((op) {
        switch (op) {
          case 'addition': return KenkenAddition();
          case 'subtraction': return KenkenSubtraction();
          case 'multiplication': return KenkenMultiplication();
          case 'division': return KenkenDivision();
          default: return KenkenAddition();
        }
      }).toList();
    }

    final ops = <KenkenOperation>[KenkenAddition()];
    if (grade >= 2) ops.add(KenkenSubtraction());
    if (grade >= 3) ops.add(KenkenMultiplication());
    if (grade >= 4 && level >= 6) ops.add(KenkenDivision());
    
    return ops;
  }

  Future<KenkenPuzzle?> _attemptGeneration(int seed) async {
    // EXACT blueprint: Reset state for each attempt
    _random = math.Random(seed);
    cages.clear();
    board.clear();
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Generating ${size}x$size Kenken puzzle (seed: $seed)...");
    }
    
    // Step 1: Create Latin Square (exact copy from blueprint)
    _createLatinSquare();
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [1] Created Latin square");
    }
    
    // Step 2: Shuffle Board (exact copy from blueprint)
    _shuffleBoard();
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [2] Shuffled board");
    }
    
    // Step 3: Create Cages and Clues (exact copy from blueprint)
    _createCagesAndClues();
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [3] Created ${cages.length} cages");
    }
    
    // Step 4: Merge Single Cell Cages (exact copy from blueprint)
    _mergeSingleCellCages();
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [4] Merged single cell cages, final count: ${cages.length}");
    }
    
    // Step 5: Print ASCII debug output (exact copy from blueprint)
    _printAsciiDebug();
    
    // Step 6: Create puzzle data for Flutter UI
    final (clues, emptyCells, numberPool) = _createPuzzleData();
    
    return KenkenPuzzle(
      size: size,
      board: board,
      cages: cages,
      clues: clues,
      emptyCells: emptyCells,
      numberPool: numberPool,
      fullSolution: _createFullSolution(),
    );
  }

  // EXACT copy from blueprint
  void _createLatinSquare() {
    final baseList = List.generate(size, (i) => i + 1)..shuffle(_random);
    board = List.generate(size, (y) {
      return List.generate(size, (x) {
        final value = baseList[(x + y) % size];
        return KenkenCell(value: value, x: x, y: y);
      });
    });
  }

  // EXACT copy from blueprint
  void _shuffleBoard() {
    for (int i = 0; i < size * 2; i++) {
      final col1 = _random.nextInt(size);
      final col2 = _random.nextInt(size);
      for (int y = 0; y < size; y++) {
        final temp = board[y][col1];
        board[y][col1] = board[y][col2];
        board[y][col2] = temp;
        board[y][col1].x = col1;
        board[y][col2].x = col2;
      }

      final row1 = _random.nextInt(size);
      final row2 = _random.nextInt(size);
      final tempRow = board[row1];
      board[row1] = board[row2];
      board[row2] = tempRow;
      for (int x = 0; x < size; x++) {
        board[row1][x].y = row1;
        board[row2][x].y = row2;
      }
    }
  }

  // EXACT copy from blueprint
  void _createCagesAndClues() {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Creating cages and clues...");
    }
    
    int cageId = 1;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (board[y][x].group == null) {
          int targetSize = 1 + _random.nextInt(maxGroupSize);
          final newCage = KenkenCage(id: cageId++, kenken: this);
          newCage.addCell(board[y][x]);

          while (newCage.cells.length < targetSize) {
            if (!newCage.grow()) break;
          }

          if (verbose) {
            debugPrint("🔧 [KENKEN GENERATOR] Created cage ${newCage.id} with ${newCage.cells.length} cells");
          }

          _assignOperationToCage(newCage);
          cages.add(newCage);
        }
      }
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Created ${cages.length} cages total");
    }
  }

  // EXACT copy from blueprint
  void _mergeSingleCellCages() {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Merging single cell cages...");
    }
    
    bool hadToMerge = true;
    int mergeCount = 0;
    while (hadToMerge) {
      hadToMerge = false;
      for (final cage in cages.toList()) {
        if (cage.cells.length == 1) {
          final singleCell = cage.cells.first;
          final neighbors = _getNeighborCells(singleCell);
          if (neighbors.isEmpty) continue;

          final targetCage = neighbors[_random.nextInt(neighbors.length)].group!;
          
          if (verbose) {
            debugPrint("🔧 [KENKEN GENERATOR]   Merging single cell cage ${cage.id} into cage ${targetCage.id}");
          }
          
          // Perform the merge
          targetCage.addCell(singleCell);
          cages.remove(cage);
          
          // Recalculate the clue for the now larger cage
          _assignOperationToCage(targetCage);
          
          hadToMerge = true;
          mergeCount++;
          break;
        }
      }
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Merged $mergeCount single cell cages");
    }
  }

  List<KenkenCell> _getNeighborCells(KenkenCell cell) {
    final neighbors = <KenkenCell>[];
    final directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final dir in directions) {
        int nx = cell.x + dir[1];
        int ny = cell.y + dir[0];
        if (ny >= 0 && ny < size && nx >= 0 && nx < size) {
            neighbors.add(board[ny][nx]);
        }
    }
    return neighbors;
  }
  
  // EXACT copy from blueprint with strict operation enforcement
  void _assignOperationToCage(KenkenCage cage) {
    if (cage.cells.length == 1) {
      cage.clue = cage.cells.first.value.toString();
      cage.operation = null;
      if (verbose) {
        debugPrint("🔧 [KENKEN GENERATOR]   Single cell cage: ${cage.clue}");
      }
      return;
    }
    
    final cageValues = cage.getValues();
    final availableOps = List<KenkenOperation>.from(operations)..shuffle(_random);

    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR]   Assigning operation to cage with ${cage.cells.length} cells, values: $cageValues");
    }

    for (final op in availableOps) {
      if (cage.cells.length < op.minCells) {
        if (verbose) {
          debugPrint("🔧 [KENKEN GENERATOR]     ${op.symbol}: SKIP - need ${op.minCells} cells, have ${cage.cells.length}");
        }
        continue;
      }
      if (op.maxCells != null && cage.cells.length > op.maxCells!) {
        if (verbose) {
          debugPrint("🔧 [KENKEN GENERATOR]     ${op.symbol}: SKIP - max ${op.maxCells} cells, have ${cage.cells.length}");
        }
        continue;
      }

      final result = op.calculate(cageValues);
      if (result != null) {
        bool inRange = true;
        if (minResult != null && result < minResult!) inRange = false;
        if (maxResult != null && result > maxResult!) inRange = false;
        
        if (verbose) {
          debugPrint("🔧 [KENKEN GENERATOR]     ${op.symbol}: result=$result, inRange=$inRange (range: ${minResult ?? 'any'}-${maxResult ?? 'any'})");
        }
        
        if (inRange) {
          cage.clue = '$result${op.symbol}';
          cage.operation = op;
          if (verbose) {
            debugPrint("🔧 [KENKEN GENERATOR]     SUCCESS: ${cage.clue}");
          }
          return;
        }
      } else {
        if (verbose) {
          debugPrint("🔧 [KENKEN GENERATOR]     ${op.symbol}: INVALID - cannot calculate result");
        }
      }
    }
    
    // NEW: Strict operation enforcement
    if (strictOperations) {
      if (verbose) {
        debugPrint("🔧 [KENKEN GENERATOR]     FAILED: No valid operations found for cage with values $cageValues");
      }
      throw Exception('Cannot generate valid clue for cage with values $cageValues using specified operations and constraints');
    }
    
    // OLD: Fallback to addition only when not in strict mode
    final fallbackOp = KenkenAddition();
    final result = fallbackOp.calculate(cageValues)!;

    // If even addition is out of range, use it anyway (better than no clue)
    cage.clue = '$result${fallbackOp.symbol}';
    cage.operation = fallbackOp;
  }

  // EXACT copy from blueprint
  void _printAsciiDebug() {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [5] ASCII Debug Output:");
      final asciiOutput = _toAsciiString(showSolution: false);
      for (final line in asciiOutput.split('\n')) {
        debugPrint("🔧 [ASCII] $line");
      }
      
      debugPrint("🔧 [KENKEN GENERATOR] [5] ASCII Solution:");
      final solutionOutput = _toAsciiString(showSolution: true);
      for (final line in solutionOutput.split('\n')) {
        debugPrint("🔧 [ASCII] $line");
      }
    }
  }

  // EXACT copy from blueprint
  String _toAsciiString({required bool showSolution}) {
    final buffer = StringBuffer();
    final Map<KenkenCell, String> clueLocations = {};
    for (final cage in cages) {
      if (cage.clue != null) {
        clueLocations[cage.getTopLeftCell()] = cage.clue!;
      }
    }

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        buffer.write('+');
        bool sameGroupAbove = (y > 0 && board[y][x].group == board[y - 1][x].group);
        buffer.write(sameGroupAbove ? '....' : '====');
      }
      buffer.writeln('+');

      for (int x = 0; x < size; x++) {
        bool sameGroupLeft = (x > 0 && board[y][x].group == board[y][x - 1].group);
        buffer.write(sameGroupLeft ? ':' : '|');
        final cell = board[y][x];
        String clueContent = clueLocations[cell] ?? '';
        buffer.write(clueContent.padRight(4));
      }
      buffer.writeln('|');

      for (int x = 0; x < size; x++) {
        bool sameGroupLeft = (x > 0 && board[y][x].group == board[y][x - 1].group);
        buffer.write(sameGroupLeft ? ':' : '|');
        final cell = board[y][x];
        String valueContent = showSolution ? ' ${cell.value}  ' : '    ';
        buffer.write(valueContent);
      }
      buffer.writeln('|');
    }

    for (int x = 0; x < size; x++) {
      buffer.write('+====');
    }
    buffer.writeln('+');

    return buffer.toString();
  }

  (Map<String, int>, Set<String>, List<int>) _createPuzzleData() {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [6] Creating puzzle data...");
    }
    
    final clues = <String, int>{};
    final emptyCells = <String>{};
    final allNumbers = <int>[];
    
    // Determine which cells to pre-fill as clues (minimal for Kenken)
    final numClues = _determineNumberOfClues();
    final allCells = <String>[];
    
    // Build list of all cell IDs and collect all numbers
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cellId = 'r${r}c$c';
        allCells.add(cellId);
        allNumbers.add(board[r][c].value);
      }
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Total cells: ${allCells.length}, numClues: $numClues");
    }
    
    // Randomly select a few cells to pre-fill
    final shuffledCells = List<String>.from(allCells);
    shuffledCells.shuffle(_random);
    final clueCells = shuffledCells.take(numClues).toList();
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Selected clue cells: $clueCells");
    }
    
    // Set clues
    for (final cellId in clueCells) {
      final parts = cellId.split('c');
      final row = int.parse(parts[0].substring(1));
      final col = int.parse(parts[1]);
      clues[cellId] = board[row][col].value;
    }
    
    // All other cells are empty
    for (final cellId in allCells) {
      if (!clues.containsKey(cellId)) {
        emptyCells.add(cellId);
      }
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Clues: $clues");
      debugPrint("🔧 [KENKEN GENERATOR] Empty cells: ${emptyCells.length}");
    }
    
    // Create number pool with correct numbers + some decoys
    final correctNumbers = <int>[];
    for (final cellId in emptyCells) {
      final parts = cellId.split('c');
      final row = int.parse(parts[0].substring(1));
      final col = int.parse(parts[1]);
      correctNumbers.add(board[row][col].value);
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Correct numbers: $correctNumbers");
    }
    
    final numberPool = _generateNumberPool(correctNumbers);
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Final number pool: $numberPool");
    }
    
    return (clues, emptyCells, numberPool);
  }

  int _determineNumberOfClues() {
    // Kenken typically has very few or no pre-filled clues
    if (size <= 4) return 0;
    if (size == 5) return 1;
    return 2;
  }

  List<int> _generateNumberPool(List<int> correctNumbers) {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Creating clean number pool for size $size grid");
    }
    
    // CLEAN number pool: Just 1-size, each number once, reusable
    final pool = List.generate(size, (i) => i + 1);
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Clean number pool: $pool");
    }
    
    return pool;
  }

  Map<String, int> _createFullSolution() {
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] [7] Creating full solution...");
    }
    
    final solution = <String, int>{};
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final cellId = 'r${r}c$c';
        solution[cellId] = board[r][c].value;
      }
    }
    
    if (verbose) {
      debugPrint("🔧 [KENKEN GENERATOR] Full solution created with ${solution.length} entries");
    }
    
    return solution;
  }
}