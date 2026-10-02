import '../services/arithmetic_square_logic.dart';
export '../services/arithmetic_square_logic.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../../../core/services/debug_provider.dart';
import '../../../core/services/puzzle_evaluation_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../../../core/services/sri_service.dart';

class ArithmeticSquareGame extends StatefulWidget {
  final int grade;
  final int level;

  const ArithmeticSquareGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<ArithmeticSquareGame> createState() => _ArithmeticSquareGameState();
}

class _ArithmeticSquareGameState extends State<ArithmeticSquareGame>
    with TickerProviderStateMixin, GameAnimationsMixin<ArithmeticSquareGame>, PuzzleSessionMixin<ArithmeticSquareGame> {
  bool _sessionReady = false;
  @override String get sessionGameKey => 'arithmatic_square';
  @override int get sessionGrade => widget.grade;
  @override int get sessionLevel => widget.level;
  @override Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      'userSolution': userSolution.entries.map((v0) => [v0.key, v0.value]).toList(),
      'numberPool': numberPool.map((v0) => v0).toList(),
      '_movesRemaining': _movesRemaining,
      '_maxMoves': _maxMoves,
      '_optimalMoves': _optimalMoves
    };
  }
  @override void applyPuzzleSession(Map<String, dynamic> state) {
    puzzle = (state["puzzle"] == null ? null : ArithmeticSquarePuzzle.fromJson(Map<String, dynamic>.from(state["puzzle"] as Map)));
    userSolution = Map<String, int>.fromEntries((state["userSolution"] as List).map((v0) => MapEntry(v0[0] as String, v0[1] as int)));
    numberPool = (state["numberPool"] as List).map((v0) => v0 as int).toList();
    _movesRemaining = state["_movesRemaining"] as int;
    _maxMoves = state["_maxMoves"] as int;
    _optimalMoves = state["_optimalMoves"] as int;
    _isGenerating = false;
  }
  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

  
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  ArithmeticSquarePuzzle? puzzle;
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
  late AnimationController _moveWarningController;
  late Animation<double> _moveWarningAnimation;

  @override
  void initState() {
    super.initState();
    initGameAnimations();
    if (kDebugMode) debugPrint("🔢 [ARITHMETIC SQUARE] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), 
      vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);


    _moveWarningController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _moveWarningAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _moveWarningController, curve: Curves.easeInOut),
    );
    
    // Initialize difficulty from the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level, gradeOverride: widget.grade);
        if (kDebugMode) debugPrint("🔢 [ARITHMETIC SQUARE] Difficulty initialized: ${currentDifficulty?.grade}");
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    if (kDebugMode) debugPrint("🔢 [ARITHMETIC SQUARE] Disposing game and cleaning up resources");
    
    glowController.stop();
    successController.stop();
    _dropController.stop();
    pulseController.stop();
    
    _dropController.dispose();
    _moveWarningController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    disposeGameAnimations();
    super.dispose();
  }

  Future<void> _generatePuzzle() async {
    beginPuzzleSession();
    if (currentDifficulty == null) return;
    
    if (kDebugMode) debugPrint("🎯 [ARITHMETIC SQUARE] Starting puzzle generation process");
    
    setState(() {
      _isGenerating = true;
      successController.reset();
      userSolution.clear();
      _loggedEquations.clear(); // Reset equation tracking for new puzzle
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

      if (kDebugMode) debugPrint("🎯 [ARITHMETIC SQUARE] Calling compute function with args: $puzzleArgs");
      final generatedPuzzle = await compute(ArithmeticSquarePuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [ARITHMETIC SQUARE] Puzzle generation completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool)..sort();
          
          // Calculate max moves: 160% of empty cells, rounded up
          final emptyCount = generatedPuzzle.emptyCells.length;
          _optimalMoves = emptyCount;
          _maxMoves = (emptyCount * 1.6).ceil();
          _movesRemaining = _maxMoves;
          
          _isGenerating = false;
          
          if (kDebugMode) debugPrint("🎯 [ARITHMETIC SQUARE] Max moves allowed: $_maxMoves for $emptyCount empty cells");
        });
        debugPrint("🎯 [ARITHMETIC SQUARE] UI state updated with new puzzle");
        debugPrint("🎯 [ARITHMETIC SQUARE] Number pool (sorted): ${numberPool.join(', ')}");
        if (kDebugMode) debugPrint("🎯 [ARITHMETIC SQUARE] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
        debugPrint("🎯 [ARITHMETIC SQUARE] Player hints: ${generatedPuzzle.playerHints.keys.join(', ')}");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("❌ [ARITHMETIC SQUARE] Error generating puzzle: $e");
      debugPrint("❌ [ARITHMETIC SQUARE] StackTrace: $stackTrace");
    }
  }

  void _placeNumber(int number, String cellId) {
    if (kDebugMode) debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      numberPool.remove(number);
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);
      
      // Decrement moves
      _movesRemaining--;
      if (kDebugMode) debugPrint("🎮 [PLACE] Moves remaining: $_movesRemaining/$_maxMoves");
      
      // Warning animation when low on moves
      if (_movesRemaining <= 3 && _movesRemaining > 0) {
        _moveWarningController.forward(from: 0.0).then((_) {
          _moveWarningController.reverse();
        });
      }
    });

    if (kDebugMode) debugPrint("🎮 [PLACE] User solution after: $userSolution");
    debugPrint("🎮 [PLACE] Number pool after: $numberPool");
    
    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }
    
    _checkSolution();
  }

  void _handleOutOfMoves() {
    if (kDebugMode) debugPrint("❌ [ARITHMETIC SQUARE] Out of moves! Game over.");
    
    // Call the failure handler
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
                  RoundSummary(gameKey: 'arithmatic_square'),
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.arithmeticSquareOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.arithmeticSquareOutOfMovesDesc,
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
                  child: Text(S.of(context)!.tryAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.backToMenu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _removeNumber(String cellId) {
    if (kDebugMode) debugPrint("🗑️ [ARITHMETIC SQUARE] Removing number from cell $cellId");
    
    setState(() {
      final number = userSolution[cellId];
      if (number != null) {
        userSolution.remove(cellId);
        numberPool.add(number);
        numberPool.sort();
        
        // IMPORTANT: Removing doesn't restore moves (prevents abuse)
        // Player learns to think before placing
        if (kDebugMode) debugPrint("🗑️ [ARITHMETIC SQUARE] Removed $number (moves not restored)");
      }
    });
  }

  void _checkSolution() {
    if (kDebugMode) debugPrint("✅ [ARITHMETIC SQUARE] Checking solution...");
    debugPrint("✅ [ARITHMETIC SQUARE] User solution: $userSolution");
    debugPrint("✅ [ARITHMETIC SQUARE] Required cells: ${puzzle!.emptyCells.length}");
    
    // Check for completed equations and log them to SRI immediately
    _checkAndLogCompletedEquations();
    
    if (userSolution.length == puzzle!.emptyCells.length) {
      if (kDebugMode) debugPrint("✅ [ARITHMETIC SQUARE] All cells filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [ARITHMETIC SQUARE] Solution validation result: $isValid");
      
      if (isValid) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    } else {
      if (kDebugMode) debugPrint("✅ [ARITHMETIC SQUARE] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }
  
  // NEW: Track which equations have been logged to SRI
  final Set<String> _loggedEquations = {};
  
  void _checkAndLogCompletedEquations() {
    final sriService = context.read<SriService>();
    
    // Create the current grid state with clues, hints, and user solutions
    final currentGrid = Map<String, int>.from(puzzle!.clues);
    currentGrid.addAll(puzzle!.playerHints);
    currentGrid.addAll(userSolution);
    
    // Check each row equation
    for (int r = 0; r < puzzle!.gridSize; r++) {
      final equationId = 'row_$r';
      if (_loggedEquations.contains(equationId)) continue;
      
      // Check if all cells in this row are filled
      bool rowComplete = true;
      final values = <int>[];
      for (int c = 0; c < puzzle!.gridSize; c++) {
        final cellId = 'r${r}c$c';
        if (!currentGrid.containsKey(cellId)) {
          rowComplete = false;
          break;
        }
        values.add(currentGrid[cellId]!);
      }
      
      if (rowComplete) {
        // Log each operation in this row
        for (int opIndex = 0; opIndex < puzzle!.rowOperators[r].length; opIndex++) {
          final operator = puzzle!.rowOperators[r][opIndex];
          final operand1 = values[opIndex];
          final operand2 = values[opIndex + 1];
          
          final problem = _createMathProblem(operator, operand1, operand2);
          if (problem != null) {
            // The equation is complete - validate it
            final isCorrect = puzzle!.validateSingleEquation(currentGrid, r, true);
            sriService.recordResponse(problem, isCorrect);
            if (kDebugMode) debugPrint("🔢 SRI: Logged row $r problem -> ${problem.expression} (correct: $isCorrect)");
          }
        }
        _loggedEquations.add(equationId);
      }
    }
    
    // Check each column equation
    for (int c = 0; c < puzzle!.gridSize; c++) {
      final equationId = 'col_$c';
      if (_loggedEquations.contains(equationId)) continue;
      
      // Check if all cells in this column are filled
      bool colComplete = true;
      final values = <int>[];
      for (int r = 0; r < puzzle!.gridSize; r++) {
        final cellId = 'r${r}c$c';
        if (!currentGrid.containsKey(cellId)) {
          colComplete = false;
          break;
        }
        values.add(currentGrid[cellId]!);
      }
      
      if (colComplete) {
        // Log each operation in this column
        for (int opIndex = 0; opIndex < puzzle!.columnOperators[c].length; opIndex++) {
          final operator = puzzle!.columnOperators[c][opIndex];
          final operand1 = values[opIndex];
          final operand2 = values[opIndex + 1];
          
          final problem = _createMathProblem(operator, operand1, operand2);
          if (problem != null) {
            // The equation is complete - validate it
            final isCorrect = puzzle!.validateSingleEquation(currentGrid, c, false);
            sriService.recordResponse(problem, isCorrect);
            if (kDebugMode) debugPrint("🔢 SRI: Logged column $c problem -> ${problem.expression} (correct: $isCorrect)");
          }
        }
        _loggedEquations.add(equationId);
      }
    }
  }
  
  MathProblem? _createMathProblem(String operator, int operand1, int operand2) {
    switch (operator) {
      case '+':
        return MathProblem.addition(operand1, operand2);
      case '−':
      case '-':
        return MathProblem.subtraction(math.max(operand1, operand2), math.min(operand1, operand2));
      case '×':
      case '*':
        return MathProblem.multiplication(operand1, operand2);
      case '÷':
      case '/':
        if (operand2 != 0 && operand1 % operand2 == 0) {
          return MathProblem.division(operand1, operand2);
        } else if (operand1 != 0 && operand2 % operand1 == 0) {
          return MathProblem.division(operand2, operand1);
        }
        return null;
      default:
        return null;
    }
  }

  void _handleSuccess() {
    AppHaptics.lightImpact();
    if (kDebugMode) debugPrint("🎉 [ARITHMETIC SQUARE] SUCCESS! Player solved the puzzle!");
    
    int baseScore = 200 * widget.grade;
    int complexityBonus = puzzle!.gridSize * puzzle!.gridSize * 10;
    int operationBonus = puzzle!.getAllOperators()
        .map(_getOperationBonus)
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    if (kDebugMode) debugPrint("🎉 [ARITHMETIC SQUARE] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // SINGLE CALL to unified progression system
    // NO mathProblems parameter - already tracked in real-time via _checkAndLogCompletedEquations()
    finishPuzzleSession();
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      skillLevel: widget.grade,
      gameType: 'arithmatic_square',
      difficulty: widget.level,
      score: totalScore,
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

  void _handleFailure() {
    if (kDebugMode) debugPrint("❌ [ARITHMETIC SQUARE] Player gave up or failed");
    
    // Record the failure - equations were already tracked via SRI as they were completed
    finishPuzzleSession();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      skillLevel: widget.grade,
      gameType: 'arithmatic_square',
      difficulty: widget.level,
      progress: _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
    ));
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
    if (kDebugMode) debugPrint("❌ [ARITHMETIC SQUARE] Incorrect solution - showing error message");
    AppHaptics.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.arithmeticSquareError)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            title: S.of(context)!.arithmeticSquare,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              S.of(context)!.arithmeticSquareInstructions,
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
                  S.of(context)!.arithmeticSquare,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
                ),
                Text(
                  S.of(context)!.arithmeticSquareInstructions,
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

          const SizedBox(width: 8),
          _buildMovesIndicator(isCompact: true),

          

        ],
      ),
    );
  }

  Widget _buildMovesIndicator({required bool isCompact}) {
    final fontSize = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    
    // Color changes based on remaining moves
    Color indicatorColor;
    if (_movesRemaining <= 3) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (_movesRemaining <= 5) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.nebulaPurple;
    }
    
    return AnimatedBuilder(
      animation: _moveWarningAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _movesRemaining <= 3 ? _moveWarningAnimation.value : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 4 : 8,
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
                SizedBox(width: isCompact ? 4 : 8),
                Text(
                  '$_movesRemaining',
                  style: SpaceTheme.titleStyle.copyWith(
                    fontSize: fontSize,
                    color: indicatorColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.nebulaPurple.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.nebulaPurple.withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildGrid(isCompact: isCompact),
          );
        },
      ),
    );
  }

  Widget _buildGrid({required bool isCompact}) {
    final cellSize = isCompact ? 50.0 : 60.0;
    final operatorSize = isCompact ? 24.0 : 30.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(puzzle!.gridSize * 2 - 1, (index) {
        if (index.isEven) {
          // Number row
          final row = index ~/ 2;
          return _buildNumberRow(row, cellSize, operatorSize, isCompact);
        } else {
          // Operator row  
          final row = index ~/ 2;
          return _buildOperatorRow(row, cellSize, operatorSize, isCompact);
        }
      }),
    );
  }

  Widget _buildNumberRow(int row, double cellSize, double operatorSize, bool isCompact) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(puzzle!.gridSize * 2 - 1, (index) {
          if (index.isEven) {
            // Number cell
            final col = index ~/ 2;
            final cellId = 'r${row}c$col';
            return _buildNumberCell(cellId, cellSize, isCompact);
          } else {
            // This is a slot for an operator or an equals sign.
            final opIndex = index ~/ 2;
            
            // Check if the operator index is within the bounds of the generated operators list.
            if (opIndex < puzzle!.rowOperators[row].length) {
              // If yes, it's a regular operator.
              return _buildOperatorDisplay(puzzle!.rowOperators[row][opIndex], operatorSize);
            } else {
              // If we are past the available operators, it must be the final equals sign for that row.
              return _buildOperatorDisplay('=', operatorSize);
            }
          }
        }),
      ),
    );
  }

  Widget _buildOperatorRow(int row, double cellSize, double operatorSize, bool isCompact) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(puzzle!.gridSize * 2 - 1, (index) {
          if (index.isEven) {
            // Column operator
            final col = index ~/ 2;
            if (row < puzzle!.columnOperators[col].length) {
              return SizedBox(
                width: cellSize,
                child: Center(
                  child: _buildOperatorDisplay(puzzle!.columnOperators[col][row], operatorSize),
                ),
              );
            } else {
              // Equals sign for result row
              return SizedBox(
                width: cellSize,
                child: Center(
                  child: Text(
                    '=',
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: operatorSize,
                      color: SpaceTheme.alienGreen,
                    ),
                  ),
                ),
              );
            }
          } else {
            // Spacer
            return SizedBox(width: operatorSize);
          }
        }),
      ),
    );
  }

  Widget _buildNumberCell(String cellId, double cellSize, bool isCompact) {
    final bool isEmpty = puzzle!.emptyCells.contains(cellId);
    final bool hasUserValue = userSolution.containsKey(cellId);
    final bool isPlayerHint = puzzle!.playerHints.containsKey(cellId);

    final int? value = isEmpty
        ? userSolution[cellId] 
        : isPlayerHint 
            ? puzzle!.playerHints[cellId]
            : puzzle!.clues[cellId];
    
    final bool isLastDropped = cellId == _lastDroppedPosition;

    Widget cell = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isEmpty
            ? const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple])
            : isPlayerHint
                ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                : const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
        border: Border.all(
          color: isEmpty 
              ? SpaceTheme.nebulaPurple 
              : isPlayerHint 
                  ? SpaceTheme.starYellow
                  : SpaceTheme.alienGreen,
          width: 2,
        ),
        boxShadow: isPlayerHint ? [
          BoxShadow(
            color: SpaceTheme.starYellow.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Center(
        child: Text(
          value?.toString() ?? '',
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: isCompact ? 16 : 18,
            color: Colors.white,
            fontWeight: isPlayerHint ? FontWeight.bold : FontWeight.normal,
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
              borderRadius: BorderRadius.circular(8),
              gradient: isHovering
                  ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                  : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
              border: Border.all(
                color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                width: isHovering ? 3 : 2,
              ),
              boxShadow: isHovering ? [
                BoxShadow(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: pulseAnimation.value,
                  child: Center(
                    child: Icon(
                      Icons.add,
                      color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
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
      return Semantics(
        button: true,
        label: S.of(context)!.a11yPlacedValueTapRemove,
        child: GestureDetector(
          onTap: () => _removeNumber(cellId),
          child: cell,
        ),
      );
    }

    return cell;
  }

  Widget _buildOperatorDisplay(String operator, double size) {
    final gameProvider = context.read<GameProvider>();
    String displayOp = operator;
    if (operator == '÷' || operator == '/') {
      displayOp = gameProvider.divisionSymbol;
    } else if (operator == '×' || operator == '*') {
      displayOp = gameProvider.multiplicationSymbol;
    } else if (operator == '−' || operator == '-') {
      displayOp = '−';
    }

    return Container(
      padding: const EdgeInsets.all(4),
      child: Text(
        displayOp,
        style: SpaceTheme.headlineStyle.copyWith(
          fontSize: size,
          color: SpaceTheme.starYellow,
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
            child: Text(S.of(context)!.arithmeticSquareSelectNumbers, style: SpaceTheme.bodyStyle),
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
              // Semantics on visual child — see note in word_sort_game.
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildNumberTile(number, isCompact: isCompact)),
                child: Semantics(
                  label: S.of(context)!.a11yNumberDragCell(number),
                  button: true,
                  child: _buildNumberTile(number, isCompact: isCompact),
                ),
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
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: isCompact ? 16 : 18),
        ),
      ),
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
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)),
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
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: SpaceTheme.starYellow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: iconSize),
          SizedBox(width: isCompact ? 4 : 8),
          Text(
            S.of(context)!.levelN(widget.level),
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
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
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
                  RoundSummary(gameKey: 'arithmatic_square'),
                  const Icon(Icons.emoji_events, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.arithmeticSquareWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.arithmeticSquareWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  if (context.read<DebugProvider>().isDebugMenuEnabled)
                    DebugPuzzleRating(
                      gameType: 'arithmatic_square',
                      puzzleId: 'sq_g${widget.grade}_l${widget.level}_${DateTime.now().millisecondsSinceEpoch}',
                      grade: widget.grade,
                      level: widget.level,
                    ),
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
// ARITHMETIC SQUARE PUZZLE GENERATION SYSTEM (With Player Hints)
//##############################################################################

/// Represents an arithmetic square puzzle with player hints
