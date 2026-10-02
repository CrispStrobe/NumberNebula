import '../services/kenken_logic.dart';
export '../services/kenken_logic.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';
import '../mixins/puzzle_session_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
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
    with TickerProviderStateMixin, GameAnimationsMixin<KenkenGame>, PuzzleSessionMixin<KenkenGame> {
  
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  KenkenPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;

  /// Cells the player has to fill — a flawless solve places each exactly
  /// once, so it doubles as the optimal move count for the performance grade.
  int _optimalMoves = 0;

  @override String get sessionGameKey => 'kenken';
  @override int get sessionGrade => widget.grade;
  @override int get sessionLevel => widget.level;
  @override Map<String, dynamic>? capturePuzzleSession() {
    if (puzzle == null || _isGenerating) return null;
    return {'puzzle': puzzle!.toJson(), 'answers': userSolution, 'pool': numberPool, 'moves': _movesRemaining, 'maxMoves': _maxMoves, 'optimal': _optimalMoves};
  }
  @override void applyPuzzleSession(Map<String, dynamic> state) {
    puzzle = KenkenPuzzle.fromJson(Map<String, dynamic>.from(state['puzzle']), currentDifficulty!);
    userSolution = Map<String, int>.from(state['answers']); numberPool = List<int>.from(state['pool']); _movesRemaining = state['moves']; _maxMoves = state['maxMoves']; _optimalMoves = state['optimal'];
    _isGenerating = false;
  }
  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) _generatePuzzle();
  }

  @override
  void initState() {
    super.initState();
    initGameAnimations();
    if (kDebugMode) debugPrint("🔲 [KENKEN] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), 
      vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    
    // Initialize difficulty from the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level, gradeOverride: widget.grade);
        if (kDebugMode) debugPrint("🔲 [KENKEN] Difficulty initialized: ${currentDifficulty?.grade}");
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    if (kDebugMode) debugPrint("🔲 [KENKEN] Disposing game and cleaning up resources");
    
    glowController.stop();
    successController.stop();
    _dropController.stop();
    pulseController.stop();
    
    _dropController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() async {
    beginPuzzleSession();
    if (currentDifficulty == null) return;
    
    if (kDebugMode) debugPrint("🎯 [KENKEN] Starting puzzle generation process");
    
    setState(() {
      _isGenerating = true;
      successController.reset();
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

      if (kDebugMode) debugPrint("🎯 [KENKEN] Calling compute function with args: $puzzleArgs");
      final generatedPuzzle = await compute(KenkenPuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [KENKEN] Puzzle generation completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool);

          // Calculate max moves: 2x empty cells (generous safety net)
          final emptyCount = generatedPuzzle.emptyCells.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) debugPrint("🎯 [KENKEN] UI state updated with new puzzle");
        debugPrint("🎯 [KENKEN] Max moves allowed: $_maxMoves for ${generatedPuzzle.emptyCells.length} empty cells");
        debugPrint("🎯 [KENKEN] Number pool: ${numberPool.join(', ')}");
        debugPrint("🎯 [KENKEN] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("❌ [KENKEN] Error generating puzzle: $e");
      debugPrint("❌ [KENKEN] StackTrace: $stackTrace");
    }
  }

  void _placeNumber(int number, String cellId) {
    if (kDebugMode) debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      // DON'T remove number from pool - numbers are reusable in Kenken
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);

      // Decrement moves on placement
      _movesRemaining--;
      if (kDebugMode) debugPrint("🎮 [PLACE] Moves remaining: $_movesRemaining/$_maxMoves");
    });

    debugPrint("🎮 [PLACE] User solution after: $userSolution");
    if (kDebugMode) debugPrint("🎮 [PLACE] Number pool remains: $numberPool");

    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }

    _checkSolution();
  }

  void _removeNumber(String cellId) {
    if (kDebugMode) debugPrint("🗑️ [KENKEN] Removing number from cell $cellId");
    
    setState(() {
      userSolution.remove(cellId);
      // Don't add back to pool since numbers were never removed
    });
  }

  void _checkSolution() {
    if (kDebugMode) debugPrint("✅ [KENKEN] Checking solution...");
    debugPrint("✅ [KENKEN] User solution: $userSolution");
    debugPrint("✅ [KENKEN] Required cells: ${puzzle!.emptyCells.length}");
    
    if (userSolution.length == puzzle!.emptyCells.length) {
      if (kDebugMode) debugPrint("✅ [KENKEN] All cells filled, validating solution");
      
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
      if (kDebugMode) debugPrint("✅ [KENKEN] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }

  List<MathProblem> _extractMathProblems(Map<String, int> solution) {
    if (kDebugMode) debugPrint("🔲 [KENKEN] Extracting math problems from completed puzzle...");
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
      
      final values = cage.cells.map((cell) => completeGrid[cell.id] ?? 0).toList();
      if (values.contains(0)) continue; // skip cage with missing data
      final operation = cage.operation!;
      
      if (kDebugMode) debugPrint("🔲 [KENKEN] Processing cage: ${cage.clue} with ${values.length} cells = $values");
      
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
              if (kDebugMode) debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
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
            if (kDebugMode) debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
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
              if (kDebugMode) debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
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
              if (kDebugMode) debugPrint("🔲 [KENKEN] Extracted: ${problem.expression} = ${problem.answer}");
            }
          }
          break;
      }
    }
    
    if (kDebugMode) debugPrint("🔲 [KENKEN] Extracted ${problems.length} math problems total");
    return problems;
  }

  void _handleSuccess(List<MathProblem> mathProblems) {
    finishPuzzleSession();
    if (kDebugMode) debugPrint("🎉 [KENKEN] SUCCESS! Player solved the puzzle!");
    AppHaptics.lightImpact();

    int baseScore = 300 * widget.grade;
    int complexityBonus = puzzle!.size * puzzle!.size * 15 + puzzle!.cages.length * 20;
    int operationBonus = puzzle!.getAllOperators()
        .map(_getOperationBonus)
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    if (kDebugMode) debugPrint("🎉 [KENKEN] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // SINGLE CALL to unified progression system
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      skillLevel: widget.grade,
      gameType: 'kenken',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: mathProblems,
        performance: Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),

      movesUsed: _maxMoves - _movesRemaining,
      optimalMoves: _optimalMoves,
    ));
    
    successController.forward(from: 0.0);
    
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
    if (kDebugMode) debugPrint("❌ [KENKEN] Incorrect solution - showing error message");
    AppHaptics.heavyImpact();
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

  void _handleFailure() {
    if (kDebugMode) debugPrint("❌ [KENKEN] FAILURE - recording loss");
    final mathProblems = _extractMathProblems(userSolution);
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      skillLevel: widget.grade,
      gameType: 'kenken',
      difficulty: widget.level,
      mathProblems: mathProblems,
      progress: _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
    ));
  }

  void _handleOutOfMoves() {
    finishPuzzleSession();
    if (kDebugMode) debugPrint("❌ [KENKEN] Out of moves! Game over.");
    _handleFailure();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildOutOfMovesDialog(),
      );
    }
  }

  Widget _buildOutOfMovesDialog() {
    final s = S.of(context)!;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                  RoundSummary(gameKey: 'kenken'),
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.kenkenOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.kenkenOutOfMovesDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.tryAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(s.backToMenu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovesIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 14.0;
    final iconSize = isCompact ? 16.0 : 20.0;

    Color indicatorColor;
    if (_movesRemaining <= 3) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (_movesRemaining <= 5) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.alienGreen;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: indicatorColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: indicatorColor, size: iconSize),
          SizedBox(width: isCompact ? 4 : 6),
          Text(
            '$_movesRemaining',
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: fontSize,
              color: indicatorColor,
            ),
          ),
        ],
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    S.of(context)!.kenkenInstructions,
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                _buildMovesIndicator(isCompact: false),
              ],
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
          const SizedBox(width: 8),
          _buildMovesIndicator(isCompact: true),
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
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12), // Reduced padding
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink.withValues(alpha: glowAnimation.value),
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
                  animation: pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: pulseAnimation.value,
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
        label: S.of(context)!.a11yPlacedValueTapRemove,
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
                                // Semantics on visual child — see note in word_sort_game.
                                child: Draggable<int>(
                                  data: rowNumbers[i],
                                  feedback: _buildDraggableFeedback(rowNumbers[i], isCompact),
                                  childWhenDragging: Opacity(
                                    opacity: 0.7,
                                    child: _buildNumberTile(rowNumbers[i], tileSize: cellSize)
                                  ),
                                  child: Semantics(
                                    label: S.of(context)!.a11yNumberDragCell(rowNumbers[i]),
                                    button: true,
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
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: ScrollableRoundDialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundSummary(gameKey: 'kenken'),
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
                        autofocus: true,
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
