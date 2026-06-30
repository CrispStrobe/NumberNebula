import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'dart:math' as math;

import '../../../core/services/puzzle_evaluation_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../services/arithmancer_crosswords_logic.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';

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

  Set<int> correctNumbers = {};
  Set<int> decoyNumbers = {};

  CrosswordPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;
  late AnimationController _moveWarningController;
  late Animation<double> _moveWarningAnimation;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("🔤 [ARITHMANCER CROSSWORDS] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    
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
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level);
        if (kDebugMode) debugPrint("🔤 [ARITHMANCER CROSSWORDS] Difficulty initialized: ${currentDifficulty?.grade}");
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    if (kDebugMode) debugPrint("🔤 [ARITHMANCER CROSSWORDS] Disposing game and cleaning up resources");
    
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _pulseController.dispose();
    _moveWarningController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;
    
    if (kDebugMode) debugPrint("🎯 [ARITHMANCER CROSSWORDS] Starting puzzle generation process");
    
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

      if (kDebugMode) debugPrint("🎯 [ARITHMANCER CROSSWORDS] Calling compute function");
      
      // STEP 1: Generate the puzzle (this is where the variable is declared and assigned)
      CrosswordPuzzle? generatedPuzzle = await compute(CrosswordPuzzle.generate, puzzleArgs);
      
      if (kDebugMode) debugPrint("🎯 [GEN-RESULT] Generation complete. Result: ${generatedPuzzle != null ? 'SUCCESS' : 'FAILURE'}");
      
      // STEP 2: Now we can use generatedPuzzle
      if (generatedPuzzle != null) {
        if (kDebugMode) debugPrint("✅ [GEN-RESULT] Puzzle details:");
        debugPrint("✅ [GEN-RESULT]   - Clues: ${generatedPuzzle.clues.length}");
        debugPrint("✅ [GEN-RESULT]   - Empty cells: ${generatedPuzzle.emptyCells.length}");
        debugPrint("✅ [GEN-RESULT]   - Equations: ${generatedPuzzle.equations.length}");
        
        _initializeNumberPool(generatedPuzzle);
        
        // STEP 3: Now update the state with the generated puzzle
        if (mounted) {
          setState(() {
            puzzle = generatedPuzzle;
            
            // Calculate max moves: 160% of empty cells, rounded up
            final emptyCount = generatedPuzzle.emptyCells.length;
            _maxMoves = (emptyCount * 1.6).ceil();
            _movesRemaining = _maxMoves;
            
            _isGenerating = false;
            
            if (kDebugMode) debugPrint("🎯 [ARITHMANCER CROSSWORDS] Max moves allowed: $_maxMoves for $emptyCount empty cells");
            debugPrint("🎯 [ARITHMANCER CROSSWORDS] UI state updated with new puzzle");
            debugPrint("🎯 [ARITHMANCER CROSSWORDS] Number pool: ${numberPool.join(', ')}");
            debugPrint("✅ [GEN-RESULT] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
          });
        }
      } else {
        throw Exception("Puzzle generation returned null");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint("❌ [ARITHMANCER CROSSWORDS] Error generating puzzle: $e");
      debugPrint("❌ [ARITHMANCER CROSSWORDS] StackTrace: $stackTrace");
      
      if (mounted) {
        setState(() => _isGenerating = false);
        // Show error dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(S.of(context)!.puzzleGenerationFailed),
            content: Text(S.of(context)!.puzzleGenerationFailedDesc),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  _generatePuzzle();
                },
                child: Text(S.of(context)!.retry),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(S.of(context)!.backToMenu),
              ),
            ],
          ),
        );
      }
    }
  }

  void _initializeNumberPool(CrosswordPuzzle generatedPuzzle) {
    // Identify which numbers are correct (in solution) vs decoys
    correctNumbers = generatedPuzzle.emptyCells
        .map((cellId) => generatedPuzzle.fullSolution[cellId]!)
        .toSet();
    
    decoyNumbers = generatedPuzzle.numberPool
        .where((n) => !correctNumbers.contains(n))
        .toSet();
    
    numberPool = List.from(generatedPuzzle.numberPool)..sort();  // sorted!
    
    if (kDebugMode) debugPrint("🎯 [POOL INIT] Correct numbers: $correctNumbers");
    debugPrint("🎯 [POOL INIT] Decoy numbers: $decoyNumbers");
    debugPrint("🎯 [POOL INIT] Initial pool (sorted): $numberPool");
  }

  void _placeNumber(int number, String cellId) {
    if (kDebugMode) debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);
      _updateNumberPool();
      
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
    debugPrint("🎮 [PLACE] Updated pool: $numberPool");
    
    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }
    
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    if (kDebugMode) debugPrint("🗑️ [REMOVE] Removing number from cell $cellId");
    
    setState(() {
      userSolution.remove(cellId);
      _updateNumberPool();
      
      // IMPORTANT: Removing doesn't restore moves (prevents abuse)
      // Player learns to think before placing
    });
    
    if (kDebugMode) debugPrint("🗑️ [REMOVE] Updated pool: $numberPool");
  }

  void _updateNumberPool() {
    if (puzzle == null) return;
    
    // Count how many of each number is needed in the solution
    final solutionCounts = <int, int>{};
    for (final cellId in puzzle!.emptyCells) {
      final number = puzzle!.fullSolution[cellId]!;
      solutionCounts[number] = (solutionCounts[number] ?? 0) + 1;
    }
    
    // Count how many of each number has been placed by the user
    final placedCounts = <int, int>{};
    for (final number in userSolution.values) {
      placedCounts[number] = (placedCounts[number] ?? 0) + 1;
    }
    
    final newPool = <int>[];
    
    // For each correct number, add remaining needed instances
    for (final number in solutionCounts.keys) {
      final needed = solutionCounts[number]!;
      final placed = placedCounts[number] ?? 0;
      final remaining = needed - placed;
      
      for (int i = 0; i < remaining; i++) {
        newPool.add(number);
      }
    }
    
    // Always keep all decoy numbers available (they can't be "used up")
    newPool.addAll(decoyNumbers);
    
    // Shuffle to maintain visual randomness
    newPool.sort();  // CHANGED FROM shuffle() to sort()
    
    numberPool = newPool;
    
    if (kDebugMode) debugPrint("🔄 [POOL UPDATE] Solution needs: $solutionCounts");
    debugPrint("🔄 [POOL UPDATE] User placed: $placedCounts");
    debugPrint("🔄 [POOL UPDATE] New pool size: ${newPool.length}");
  }

  void _checkSolution() {
    if (kDebugMode) debugPrint("✅ [ARITHMANCER CROSSWORDS] Checking solution...");
    debugPrint("✅ [ARITHMANCER CROSSWORDS] User solution: $userSolution");
    debugPrint("✅ [ARITHMANCER CROSSWORDS] Required cells: ${puzzle!.emptyCells.length}");
    
    if (userSolution.length == puzzle!.emptyCells.length) {
      if (kDebugMode) debugPrint("✅ [ARITHMANCER CROSSWORDS] All cells filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [ARITHMANCER CROSSWORDS] Solution validation result: $isValid");
      
      if (isValid) {
        _handleSuccess(userSolution);
      } else {
        _handleIncorrect(); // We keep this! ==> Error message...
      }
    } else {
      if (kDebugMode) debugPrint("✅ [ARITHMANCER CROSSWORDS] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }

  List<MathProblem> _extractMathProblems(Map<String, int> solution) {
    if (kDebugMode) debugPrint("📤 [CROSSWORDS] Extracting all math problems from completed crossword...");
    
    final problems = <MathProblem>[];
    
    // Create the complete solution
    final completeGrid = Map<String, int>.from(puzzle!.clues);
    completeGrid.addAll(solution);
    
    // Extract a problem from each equation
    for (final equation in puzzle!.equations) {
      final values = equation.variableNames.map((varName) => completeGrid[varName]!).toList();
      
      final operand1 = values[0];
      final operand2 = values[1];

      MathProblem? problem;
      switch (equation.operator) {
        case '+':
          problem = MathProblem.addition(operand1, operand2);
          break;
        case '−':
        case '-':
          problem = MathProblem.subtraction(math.max(operand1, operand2), math.min(operand1, operand2));
          break;
        case '×':
        case '*':
          problem = MathProblem.multiplication(operand1, operand2);
          break;
        case '÷':
        case '/':
          if (operand2 != 0 && operand1 % operand2 == 0) {
            problem = MathProblem.division(operand1, operand2);
          } else if (operand1 != 0 && operand2 % operand1 == 0) {
            problem = MathProblem.division(operand2, operand1);
          }
          break;
      }
      
      if (problem != null) {
        problems.add(problem);
        if (kDebugMode) debugPrint("📤 [CROSSWORDS] Extracted: ${problem.expression}");
      }
    }
    
    if (kDebugMode) debugPrint("📤 [CROSSWORDS] Extracted ${problems.length} problems total");
    return problems;
  }

  void _handleSuccess(Map<String, int> userSolution) {
    if (kDebugMode) debugPrint("🎉 [ARITHMANCER CROSSWORDS] SUCCESS! Player solved the puzzle!");
    HapticFeedback.lightImpact();

    int baseScore = 250 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 15 + puzzle!.emptyCells.length * 5;
    int operationBonus = puzzle!.getAllOperators()
        .map(_getOperationBonus)
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    if (kDebugMode) debugPrint("🎉 [ARITHMANCER CROSSWORDS] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // Extract all math problems from the solved crossword
    final mathProblems = _extractMathProblems(userSolution);
    if (kDebugMode) debugPrint("🎉 [ARITHMANCER CROSSWORDS] Extracted ${mathProblems.length} math problems for tracking");
    
    // SINGLE CALL to unified progression system
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'arithmancer_crosswords',
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
    if (kDebugMode) debugPrint("❌ [ARITHMANCER CROSSWORDS] Incorrect solution - showing error message");
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.arithmancerCrosswordsError)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOutOfMoves() {
    if (kDebugMode) debugPrint("❌ [ARITHMANCER CROSSWORDS] Out of moves! Game over.");
    
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.arithmancerCrosswordsOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.arithmancerCrosswordsOutOfMovesDesc,
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
      indicatorColor = SpaceTheme.cosmicPink;
    }
    
    return Semantics(
      label: S.of(context)!.a11yMovesRemaining(_movesRemaining),
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_movesRemaining',
                        style: SpaceTheme.titleStyle.copyWith(
                          fontSize: fontSize,
                          color: indicatorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleFailure() {
    if (kDebugMode) debugPrint("❌ [ARITHMANCER CROSSWORDS] FAILURE! Player gave up");
    
    // Extract problems for learning purposes (using partial solution if any)
    final mathProblems = userSolution.isNotEmpty 
        ? _extractMathProblems(userSolution)
        : <MathProblem>[];
    
    // Record the failure
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'arithmancer_crosswords',
      difficulty: widget.level,
      mathProblems: mathProblems,
    ));
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
              // MODIFIED: Use aspect ratio for landscape, and smallest dim for compact
              final bool isLandscape = constraints.maxWidth > constraints.maxHeight;
              final bool isCompact = math.min(constraints.maxWidth, constraints.maxHeight) < 500;

              return Column(
                children: [
                  _buildAdaptiveHeader(isCompact: isCompact), // MODIFIED: Header now just uses isCompact
                  Expanded(
                    child: isLandscape // MODIFIED: Swaps layout based on orientation
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
    if (!isCompact) { // Portrait, tall screen
      return Column(
        children: [
          GameUI(
            title: S.of(context)!.arithmancerCrosswords,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row( // MODIFIED: Put instructions and moves on one line
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    S.of(context)!.arithmancerCrosswordsInstructions,
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                _buildMovesIndicator(isCompact: false), // Full size moves
              ],
            ),
          ),
        ],
      );
    }

    // MODIFIED: Compact (landscape phone, or small screen)
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4), // Reduced vertical padding
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text( // Just the title
                S.of(context)!.arithmancerCrosswords,
                style: SpaceTheme.headlineStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildLevelIndicator(isCompact: true),
          const SizedBox(width: 4), // Tighter spacing
          _buildScoreIndicator(isCompact: true),
          const SizedBox(width: 4), // Tighter spacing
          _buildMovesIndicator(isCompact: true),
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
            flex: 5, // MODIFIED: More space for grid
            child: _buildCrosswordArea(isCompact: isCompact),
          ),
          SizedBox(height: isCompact ? 8 : 16),
          Expanded(
            flex: 2, // MODIFIED: Less space for numpad
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
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(isCompact ? 8 : 12), // MODIFIED: Reduced padding
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
            // MODIFIED: Swapped static child for dynamic LayoutBuilder
            child: _buildCrossword(isCompact: isCompact),
          );
        },
      ),
    );
  }

  Widget _buildCrossword({required bool isCompact}) {
    if (puzzle == null) return Container();
    
    // Calculate the bounding box of all cells in *grid units*
    final allPositions = <math.Point<int>>[
      ...puzzle!.numberCells.keys,
      ...puzzle!.operatorCells.keys,
    ];
    
    if (allPositions.isEmpty) return Container();
    
    final minX = allPositions.map((p) => p.x).reduce(math.min);
    final maxX = allPositions.map((p) => p.x).reduce(math.max);
    final minY = allPositions.map((p) => p.y).reduce(math.min);
    final maxY = allPositions.map((p) => p.y).reduce(math.max);
    
    final gridUnitsWidth = (maxX - minX + 1);
    final gridUnitsHeight = (maxY - minY + 1);

    // MODIFIED: Use LayoutBuilder to determine cell size dynamically
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size based on available space
        // (cellSize + 4) is the space per cell.
        final maxCellSizeW = (constraints.maxWidth - (gridUnitsWidth * 4)) / gridUnitsWidth;
        final maxCellSizeH = (constraints.maxHeight - (gridUnitsHeight * 4)) / gridUnitsHeight;
        // Use the smallest dimension and clamp the size
        final cellSize = math.min(maxCellSizeW, maxCellSizeH).clamp(25.0, 45.0);
        
        final operatorSize = cellSize * 0.6; // Scale operator size
        
        final totalWidth = gridUnitsWidth * (cellSize + 4);
        final totalHeight = gridUnitsHeight * (cellSize + 4);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              width: totalWidth,
              height: totalHeight,
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
                      child: _buildNumberCell(cellId, cellSize, isCompact), // Pass new cell size
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
                      child: _buildOperatorCell(operator, cellSize, operatorSize), // Pass new sizes
                    );
                  }),
                  
                  // Draw equals signs
                  ...puzzle!.equalsCells.map((pos) {
                    final x = (pos.x - minX) * (cellSize + 4);
                    final y = (pos.y - minY) * (cellSize + 4);
                    
                    return Positioned(
                      left: x,
                      top: y,
                      child: _buildEqualsCell(cellSize, operatorSize), // Pass new sizes
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
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
                  color: SpaceTheme.starYellow.withValues(alpha: 0.6),
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
                      color: isHovering ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple.withValues(alpha: 0.7),
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

  Widget _buildOperatorCell(String operator, double cellSize, double operatorSize) {
    final gameProvider = context.read<GameProvider>();
    String displayOp = operator;
    if (operator == '÷' || operator == '/') {
      displayOp = gameProvider.divisionSymbol;
    } else if (operator == '×' || operator == '*') {
      displayOp = gameProvider.multiplicationSymbol;
    }

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
          displayOp,
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
      mainAxisSize: MainAxisSize.min, // Keep this
      children: [
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(S.of(context)!.arithmancerCrosswordsSelectNumbers, style: SpaceTheme.bodyStyle),
          ),
        // MODIFIED: Wrap GridView in Flexible/Expanded
        Flexible(
          child: Container(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            decoration: SpaceTheme.cardDecoration.copyWith(
              border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
            ),
            child: GridView.builder(
              shrinkWrap: true, // Keep shrinkWrap because parent is Flexible
              physics: const BouncingScrollPhysics(), // MODIFIED: Allow scrolling
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isCompact ? 6 : 5, // MODIFIED: More columns
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
                    label: S.of(context)!.a11yNumberDragSlot(number),
                    button: true,
                    child: _buildNumberTile(number, isCompact: isCompact),
                  ),
                );
              },
            ),
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
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5)],
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
                  Text(S.of(context)!.arithmancerCrosswordsWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.arithmancerCrosswordsWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  if (kDebugMode)
                    DebugPuzzleRating(
                      gameType: 'arithmancer_crosswords',
                      puzzleId: 'cw_g${widget.grade}_l${widget.level}_${DateTime.now().millisecondsSinceEpoch}',
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

