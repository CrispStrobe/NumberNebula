import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:math' as math;
import 'dart:async';

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

// ============================================================================
// CROSSWORD PUZZLE SCALING CONFIGURATION
// ============================================================================
// Adjust these constants to fine-tune difficulty scaling for GRADES 1-4 ONLY

class CrosswordConfig {
  // Number range scaling (compress into 4 grades)
  static const int baseMinNumber = 1;
  static const int baseMaxNumber = 9;
  static const int numberRangeGrowthPerGrade = 5; // Aggressive growth: +5 to max per grade
  static const int maxNumberCap = 25; // Higher cap for grade 4
  
  // Puzzle size scaling (compress into 4 grades + 20 levels each)
  static const int baseEdges = 4; // Start very small
  static const int edgesGrowthPerLevel = 1; // +1 edge every 2 levels
  static const int levelDivisorForEdges = 2; // level/2 for growth calculation
  static const int edgesGrowthPerGrade = 4; // +4 edges per grade
  static const int maxEdges = 20; // Maximum puzzle complexity for grade 4 level 20
  
  // Clue system (pre-filled cells) - ALWAYS provide clues for mathematical reasoning
  static const int baseClues = 2; // Always start with at least 2 clues
  static const int cluesGrowthPerGrade = 1; // +1 clue per grade
  static const int cluesGrowthPerLevel = 1; // +1 clue every 10 levels
  static const int maxClues = 6; // Maximum pre-filled cells
  
  // Advanced constraints - must fit in grade 4
  static const int noDupsStartGrade = 4; // Enable unique numbers at grade 4
  static const int noDupsStartLevel = 15; // And only at level 15+
  
  // Operation complexity (compress into 4 grades)
  static const Map<int, List<String>> operationsByGrade = {
    1: ['+'], // Grade 1: Addition only
    2: ['+', '−'], // Grade 2: Add subtraction  
    3: ['+', '−', '×'], // Grade 3: Add multiplication
    4: ['+', '−', '×', '÷'], // Grade 4: All operations (highly complex)
  };
  
  // Timeout scaling (grade 4 needs much more time)
  static const int baseTimeout = 20;
  static const int timeoutGrowthPerGrade = 15; // +15 seconds per grade
  static const int maxTimeout = 90; // Up to 90 seconds for grade 4
  
  // Calculate actual config for a given grade/level with optional custom settings
  static PuzzleConfig createConfig(int grade, int level, {
    bool useCustomSettings = false,
    List<String>? customOps,
    int? customMin,
    int? customMax,
  }) {
    // Number range - use custom settings if provided
    final minN = useCustomSettings && customMin != null ? customMin : baseMinNumber;
    final maxN = useCustomSettings && customMax != null 
        ? customMax 
        : math.min(baseMaxNumber + (grade * numberRangeGrowthPerGrade), maxNumberCap);
    
    // Puzzle size - both grade and level scaling
    final baseForGrade = baseEdges + (grade * edgesGrowthPerGrade);
    final levelBonus = level ~/ levelDivisorForEdges * edgesGrowthPerLevel;
    final edges = math.min(baseForGrade + levelBonus, maxEdges);
    
    // Operations - use custom settings if provided
    final ops = useCustomSettings && customOps != null && customOps.isNotEmpty
        ? _convertCustomOperations(customOps)
        : (operationsByGrade[grade] ?? operationsByGrade[4]!);
    
    // Clues - ALWAYS provide clues for mathematical reasoning
    final clues = math.min(
      baseClues + (grade * cluesGrowthPerGrade) + (level ~/ 10 * cluesGrowthPerLevel),
      maxClues
    );
    
    // Advanced constraints
    final noDups = grade >= noDupsStartGrade && level >= noDupsStartLevel;
    
    // Timeout - generous for complex grade 4 puzzles
    final timeout = math.min(
      baseTimeout + (grade * timeoutGrowthPerGrade),
      maxTimeout
    );
    
    return PuzzleConfig(
      minN: minN,
      maxN: maxN,
      ops: ops,
      targetEdges: edges,
      numClues: clues,
      noDups: noDups,
      timeoutSeconds: timeout,
    );
  }
  
  // Convert custom operation names to symbols
  static List<String> _convertCustomOperations(List<String> customOps) {
    const operationMap = {
      'addition': '+',
      'subtraction': '−',
      'multiplication': '×',
      'division': '÷',
    };
    
    return customOps
        .map((op) => operationMap[op] ?? op)
        .where((op) => ['+', '−', '×', '÷'].contains(op))
        .toList();
  }
  
  // Debug helper to see what config will be generated
  static String debugConfig(int grade, int level, {
    bool useCustomSettings = false,
    List<String>? customOps,
    int? customMin,
    int? customMax,
  }) {
    final config = createConfig(grade, level, 
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    final customStr = useCustomSettings ? ' [CUSTOM]' : '';
    return 'Grade $grade, Level $level$customStr → Range=${config.minN}-${config.maxN}, '
           'Ops=${config.ops}, Edges=${config.targetEdges}, '
           'Clues=${config.numClues}, NoDups=${config.noDups}, '
           'Timeout=${config.timeoutSeconds}s';
  }
}

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

    _moveWarningController.dispose();
    
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

      debugPrint("🎯 [ARITHMANCER CROSSWORDS] Calling compute function");
      
      // STEP 1: Generate the puzzle (this is where the variable is declared and assigned)
      CrosswordPuzzle? generatedPuzzle = await compute(CrosswordPuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [GEN-RESULT] Generation complete. Result: ${generatedPuzzle != null ? 'SUCCESS' : 'FAILURE'}");
      
      // STEP 2: Now we can use generatedPuzzle
      if (generatedPuzzle != null) {
        debugPrint("✅ [GEN-RESULT] Puzzle details:");
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
            
            debugPrint("🎯 [ARITHMANCER CROSSWORDS] Max moves allowed: $_maxMoves for $emptyCount empty cells");
            debugPrint("🎯 [ARITHMANCER CROSSWORDS] UI state updated with new puzzle");
            debugPrint("🎯 [ARITHMANCER CROSSWORDS] Number pool: ${numberPool.join(', ')}");
            debugPrint("✅ [GEN-RESULT] Empty cells: ${generatedPuzzle.emptyCells.join(', ')}");
          });
        }
      } else {
        throw Exception("Puzzle generation returned null");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [ARITHMANCER CROSSWORDS] Error generating puzzle: $e");
      debugPrint("❌ [ARITHMANCER CROSSWORDS] StackTrace: $stackTrace");
      
      if (mounted) {
        setState(() => _isGenerating = false);
        // Show error dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Puzzle Generation Failed'),
            content: Text('Unable to generate puzzle. Please try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _generatePuzzle();
                },
                child: Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text('Back to Menu'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showGenerationFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SpaceTheme.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: SpaceTheme.rocketRed),
              const SizedBox(height: 16),
              Text(
                'Puzzle Generation Failed',
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to generate a puzzle at this difficulty. Try again or return to the menu.',
                style: SpaceTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Exit game
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(S.of(context)!.backToMenu),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      _generatePuzzle(); // Try again
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    
    debugPrint("🎯 [POOL INIT] Correct numbers: $correctNumbers");
    debugPrint("🎯 [POOL INIT] Decoy numbers: $decoyNumbers");
    debugPrint("🎯 [POOL INIT] Initial pool (sorted): $numberPool");
  }

  void _placeNumber(int number, String cellId) {
    debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT CELL $cellId ===");
    
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedPosition = cellId;
      _dropController.forward(from: 0.0);
      _updateNumberPool();
      
      // Decrement moves
      _movesRemaining--;
      debugPrint("🎮 [PLACE] Moves remaining: $_movesRemaining/$_maxMoves");
      
      // Warning animation when low on moves
      if (_movesRemaining <= 3 && _movesRemaining > 0) {
        _moveWarningController.forward(from: 0.0).then((_) {
          _moveWarningController.reverse();
        });
      }
    });

    debugPrint("🎮 [PLACE] User solution after: $userSolution");
    debugPrint("🎮 [PLACE] Updated pool: $numberPool");
    
    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }
    
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    debugPrint("🗑️ [REMOVE] Removing number from cell $cellId");
    
    setState(() {
      userSolution.remove(cellId);
      _updateNumberPool();
      
      // IMPORTANT: Removing doesn't restore moves (prevents abuse)
      // Player learns to think before placing
    });
    
    debugPrint("🗑️ [REMOVE] Updated pool: $numberPool");
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
    
    debugPrint("🔄 [POOL UPDATE] Solution needs: $solutionCounts");
    debugPrint("🔄 [POOL UPDATE] User placed: $placedCounts");
    debugPrint("🔄 [POOL UPDATE] New pool size: ${newPool.length}");
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
        _handleSuccess(userSolution);
      } else {
        _handleIncorrect(); // We keep this! ==> Error message...
      }
    } else {
      debugPrint("✅ [ARITHMANCER CROSSWORDS] Solution incomplete: ${userSolution.length}/${puzzle!.emptyCells.length} cells filled");
    }
  }

  List<MathProblem> _extractMathProblems(Map<String, int> solution) {
    debugPrint("📤 [CROSSWORDS] Extracting all math problems from completed crossword...");
    
    final problems = <MathProblem>[];
    
    // Create the complete solution
    final completeGrid = Map<String, int>.from(puzzle!.clues);
    completeGrid.addAll(solution);
    
    // Extract a problem from each equation
    for (final equation in puzzle!.equations) {
      final values = equation.variableNames.map((varName) => completeGrid[varName]!).toList();
      
      final operand1 = values[0];
      final operand2 = values[1];
      final result = values[2];
      
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
        debugPrint("📤 [CROSSWORDS] Extracted: ${problem.expression}");
      }
    }
    
    debugPrint("📤 [CROSSWORDS] Extracted ${problems.length} problems total");
    return problems;
  }

  void _handleSuccess(Map<String, int> userSolution) {
    debugPrint("🎉 [ARITHMANCER CROSSWORDS] SUCCESS! Player solved the puzzle!");
    
    int baseScore = 250 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 15 + puzzle!.emptyCells.length * 5;
    int operationBonus = puzzle!.getAllOperators()
        .map((op) => _getOperationBonus(op))
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    debugPrint("🎉 [ARITHMANCER CROSSWORDS] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // Extract all math problems from the solved crossword
    final mathProblems = _extractMathProblems(userSolution);
    debugPrint("🎉 [ARITHMANCER CROSSWORDS] Extracted ${mathProblems.length} math problems for tracking");
    
    // SINGLE CALL to unified progression system
    final didAdvance = context.read<GameProvider>().recordLevelWin(
      gameType: 'arithmancer_crosswords',
      scoreGained: totalScore,
      difficulty: widget.level,
      wasSuccessful: true,
      mathProblems: mathProblems, // Pass all problems at once
    );
    
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

  void _handleOutOfMoves() {
    debugPrint("❌ [ARITHMANCER CROSSWORDS] Out of moves! Game over.");
    
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
              color: SpaceTheme.deepSpace.withOpacity(0.8),
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

  void _handleFailure() {
    debugPrint("❌ [ARITHMANCER CROSSWORDS] FAILURE! Player gave up");
    
    // Extract problems for learning purposes (using partial solution if any)
    final mathProblems = userSolution.isNotEmpty 
        ? _extractMathProblems(userSolution)
        : <MathProblem>[];
    
    // Record the failure
    context.read<GameProvider>().recordLevelWin(
      gameType: 'arithmancer_crosswords',
      scoreGained: 0,
      difficulty: widget.level,
      wasSuccessful: false,
      mathProblems: mathProblems,
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
            child: Text( // Just the title
              S.of(context)!.arithmancerCrosswords,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 16), // Smaller font
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            child: Container(
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
                return Draggable<int>(
                  data: number,
                  feedback: _buildDraggableFeedback(number),
                  childWhenDragging: Opacity(opacity: 0.3, child: _buildNumberTile(number, isCompact: isCompact)),
                  child: _buildNumberTile(number, isCompact: isCompact),
                  // MODIFIED: Removed the extra line below this comment
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
// EXACT BLUEPRINT COPY FROM gencw.dart - FOLLOWS PRECISELY
//##############################################################################

/// Configuration for the crossword puzzle generator
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

/// Grid pattern generator - EXACT COPY from gencw.dart
class GridPatternGenerator {
  final int width;
  final int height;
  final int targetEdges;
  late List<List<String>> grid;
  final math.Random random = math.Random();
  int edgeCount = 0;
  late math.Point<int> mazeStart;
  late int firstDirection;
  final List<math.Point<int>> directions = [
    math.Point(0, -1),
    math.Point(1, 0),
    math.Point(0, 1),
    math.Point(-1, 0)
  ];

  GridPatternGenerator({
    this.width = 30,
    this.height = 25,
    required this.targetEdges,
  }) {
    initializeGrid();
    mazeStart = math.Point(width ~/ 2, height ~/ 2);
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

  int countSquaresBehind(math.Point<int> pos, int direction) {
    math.Point<int> oppositeDir = directions[(direction + 2) % 4];
    int count = 0;
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (oppositeDir.x * step);
      int y = pos.y + (oppositeDir.y * step);
      if (!isValidPosition(x, y) || grid[y][x] != '█') break;
      count++;
    }
    return count;
  }

  bool canWalk4Steps(math.Point<int> pos, int direction) {
    if (countSquaresBehind(pos, direction) >= 4) return false;
    math.Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (!isValidPosition(x, y)) return false;
      if (step < 4 && grid[y][x] == '█') return false;
    }
    return true;
  }

  math.Point<int> walk4Steps(math.Point<int> pos, int direction) {
    math.Point<int> dir = directions[direction];
    for (int step = 1; step <= 4; step++) {
      int x = pos.x + (dir.x * step);
      int y = pos.y + (dir.y * step);
      if (isValidPosition(x, y)) grid[y][x] = '█';
    }
    edgeCount++;
    return math.Point(pos.x + (dir.x * 4), pos.y + (dir.y * 4));
  }

  void runMazeWalker() {
    math.Point<int> currentPos = mazeStart;
    int currentDirection = firstDirection;

    for (int moves = 0; moves < 15 && edgeCount < targetEdges; moves++) {
      if (canWalk4Steps(currentPos, currentDirection)) {
        currentPos = walk4Steps(currentPos, currentDirection);
        int decision = random.nextInt(100);
        List<int> turnOptions = [(currentDirection + 1) % 4, (currentDirection + 3) % 4]
          ..shuffle(random);

        if (decision < 40) {
          math.Point<int> dir = directions[currentDirection];
          math.Point<int> backPos =
              math.Point(currentPos.x - (dir.x * 2), currentPos.y - (dir.y * 2));
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

/// Equation representation - EXACT COPY from gencw.dart
class Equation {
  final List<math.Point<int>> numberCells;
  final math.Point<int> operatorCell;
  final String operator;
  
  Equation(this.numberCells, this.operatorCell, this.operator);
  
  List<String> get variableNames =>
      numberCells.map((p) => 'C_${p.y}_${p.x}').toList();
      
  Set<math.Point<int>> get allCells {
    final op = operatorCell;
    final n1 = numberCells[0];
    final n2 = numberCells[1];
    final n3 = numberCells[2];
    return {
      n1,
      op,
      math.Point((op.x + n2.x) ~/ 2, (op.y + n2.y) ~/ 2),
      n2,
      math.Point((n2.x + n3.x) ~/ 2, (n2.y + n3.y) ~/ 2),
      n3
    };
  }

  @override
  String toString() =>
      '${variableNames[0]} $operator ${variableNames[1]} == ${variableNames[2]}';
}

/// Puzzle parser - EXACT COPY from gencw.dart
class PuzzleParser {
  final List<List<String>> grid;
  final PuzzleConfig config;
  final math.Random random = math.Random();
  final List<Equation> equations = [];
  final Set<math.Point<int>> numberCellLocations = {};

  PuzzleParser(this.grid, this.config) {
    _findEquations();
  }

  void _findEquations() {
    int height = grid.length;
    int width = grid[0].length;
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width - 4; c++) {
        if (List.generate(5, (i) => grid[r][c + i])
            .every((cell) => cell == '█')) {
          final numberCells = [math.Point(c, r), math.Point(c + 2, r), math.Point(c + 4, r)];
          final operatorCell = math.Point(c + 1, r);
          final eq = Equation(numberCells, operatorCell,
              config.ops[random.nextInt(config.ops.length)]);
          equations.add(eq);
          numberCellLocations.addAll(numberCells);
        }
      }
    }
    for (int r = 0; r < height - 4; r++) {
      for (int c = 0; c < width; c++) {
        if (List.generate(5, (i) => grid[r + i][c])
            .every((cell) => cell == '█')) {
          final numberCells = [math.Point(c, r), math.Point(c, r + 2), math.Point(c, r + 4)];
          final operatorCell = math.Point(c, r + 1);
          final eq = Equation(numberCells, operatorCell,
              config.ops[random.nextInt(config.ops.length)]);
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
    final cellsInEquations = <math.Point<int>>{};
    for (final eq in equations) {
      cellsInEquations.addAll(eq.allCells);
    }
    return totalBlockCells == cellsInEquations.length;
  }
}

/// ASCII renderer - EXACT COPY from gencw.dart
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
    final equationCells = <math.Point<int>, String>{};
    for (final eq in puzzle.equations) {
      final mid1 = math.Point((eq.operatorCell.x + eq.numberCells[1].x) ~/ 2,
          (eq.operatorCell.y + eq.numberCells[1].y) ~/ 2);
      final mid2 = math.Point((eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
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

/// MAIN GENERATOR
Future<CrosswordPuzzle> generateCrosswordPuzzle(PuzzleConfig config) async {
  debugPrint('🔧 [GENERATOR] ========================================');
  debugPrint('🔧 [GENERATOR] MATH CROSSWORD PUZZLE GENERATOR & SOLVER');
  debugPrint('🔧 [GENERATOR] Config: Range=${config.minN}-${config.maxN}, Ops=${config.ops}, Edges=${config.targetEdges}, Clues=${config.numClues}, NoDups=${config.noDups}, Timeout=${config.timeoutSeconds}s');

  dynamic solution;
  PuzzleParser? successfulPuzzle;
  Map<String, int> finalClues = {};
  const maxAttempts = 50; // Reduced from 100
  
  final totalStopwatch = Stopwatch()..start();
  const maxTotalSeconds = 6; // Hard limit

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    if (totalStopwatch.elapsed.inSeconds >= maxTotalSeconds) {
      debugPrint("⏰ [GENERATOR] Hard timeout at ${totalStopwatch.elapsed.inSeconds}s (max: ${maxTotalSeconds}s)");
      break;
    }
    
    debugPrint('🔧 [GENERATOR] ------------------------------------------------------------');
    debugPrint('🔧 [GENERATOR] ATTEMPT $attempt/$maxAttempts (elapsed: ${totalStopwatch.elapsed.inSeconds}s)');

    // STEP 1: Generate a valid pattern
    debugPrint("🔧 [GENERATOR] [1] Generating pattern...");
    PuzzleParser? puzzle;
    int patternAttempt = 0;
    do {
      patternAttempt++;
      if (patternAttempt > 20) { // Don't spend forever on pattern
        debugPrint("🔧 [GENERATOR]   -> Pattern generation taking too long, restarting attempt");
        break;
      }
      final generator = GridPatternGenerator(targetEdges: config.targetEdges);
      final rawGrid = generator.generatePattern();
      puzzle = PuzzleParser(rawGrid, config);
    } while (puzzle?.isPatternValid() != true && patternAttempt < 20);

    if (puzzle == null || !puzzle.isPatternValid()) {
      debugPrint("🔧 [GENERATOR]   -> FAILED to generate valid pattern, retrying...");
      continue;
    }

    final allVarNames =
        puzzle.numberCellLocations.map((p) => 'C_${p.y}_${p.x}').toList();
    debugPrint("🔧 [GENERATOR]   -> Pattern OK: ${puzzle.equations.length} equations, ${allVarNames.length} cells");

    // STEP 2: Generate clues (keeping existing logic)
    debugPrint("🔧 [GENERATOR] [2] Generating ${config.numClues} clues...");
    final clues = <String, int>{};
    final domain = List<int>.generate(config.maxN - config.minN + 1, (i) => i + config.minN);

    final variableCounts = <String, int>{};
    for (final varName in allVarNames) {
      variableCounts[varName] = 0;
    }
    for (final eq in puzzle.equations) {
      for (final varName in eq.variableNames) {
        variableCounts[varName] = (variableCounts[varName] ?? 0) + 1;
      }
    }

    final List<String> candidates = [...allVarNames];
    final clueVars = <String>[];
    final disqualifiedEquations = <Equation>{};

    for (int i = 0; i < config.numClues && candidates.isNotEmpty; i++) {
      candidates.sort((a, b) => variableCounts[b]!.compareTo(variableCounts[a]!));
      if (candidates.isEmpty) break;
      final bestCandidate = candidates.first;

      final chosenEquation = puzzle!.equations.firstWhere(
        (eq) => eq.variableNames.contains(bestCandidate) && !disqualifiedEquations.contains(eq),
        orElse: () => puzzle!.equations.first,
      );

      String clueVariable;
      switch (chosenEquation.operator) {
        case '+':
        case '×':
          clueVariable = chosenEquation.variableNames[2];
          break;
        case '−':
        case '÷':
          clueVariable = chosenEquation.variableNames[0];
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
        clueValue = domain[math.Random().nextInt(domain.length)];
      } while (config.noDups && usedClueValues.contains(clueValue));
      clues[clueVar] = clueValue;
      if (config.noDups) usedClueValues.add(clueValue);
    }
    debugPrint("🔧 [GENERATOR]   -> Clues: $clues");

    // STEP 3: Solve CSP
    debugPrint("🔧 [GENERATOR] [3] Solving CSP (timeout: ${config.timeoutSeconds}s)...");
    final p = Problem();
    final fullDomain = List<int>.generate(config.maxN - config.minN + 1, (i) => i + config.minN);
    if (config.noDups) {
      fullDomain.removeWhere((val) => clues.values.contains(val));
    }
    for (final varName in allVarNames) {
      if (clues.containsKey(varName)) {
        p.addVariable(varName, [clues[varName]!]);
      } else {
        p.addVariable(varName, fullDomain);
      }
    }
    for (final eq in puzzle!.equations) {
      p.addConstraint(eq.variableNames, (assignment) {
        final a = assignment[eq.variableNames[0]];
        final b = assignment[eq.variableNames[1]];
        final c = assignment[eq.variableNames[2]];
        if (a == null || b == null || c == null) return false;
        switch (eq.operator) {
          case '+':
            return a + b == c;
          case '−':
            return a - b == c;
          case '×':
            return a * b == c;
          case '÷':
            return b != 0 && a % b == 0 && a ~/ b == c;
          default:
            return false;
        }
      });
    }
    if (config.noDups) {
      p.addAllDifferent(allVarNames);
    }

    final solveStopwatch = Stopwatch()..start();
    try {
      final potentialSolution = await p
          .getSolution()
          .timeout(Duration(seconds: config.timeoutSeconds));
      solveStopwatch.stop();

      if (potentialSolution != 'FAILURE') {
        debugPrint("🔧 [GENERATOR]   -> SOLVED in ${solveStopwatch.elapsedMilliseconds}ms");
        solution = potentialSolution;
        successfulPuzzle = puzzle!;
        finalClues = clues;
        
        debugPrint("🔧 [GENERATOR] [4] Rendering ASCII preview...");
        final emptyRenderer = AsciiRenderer(puzzle!, config, solution: clues);
        debugPrint(emptyRenderer.render());
        break;
      } else {
        debugPrint("🔧 [GENERATOR]   -> UNSOLVABLE (contradiction in clues)");
      }
    } catch (e) {
      solveStopwatch.stop();
      debugPrint("🔧 [GENERATOR]   -> TIMEOUT after ${solveStopwatch.elapsedMilliseconds}ms");
    }
  }

  totalStopwatch.stop();
  debugPrint('🔧 [GENERATOR] ========================================');
  
  if (solution != null && solution != 'FAILURE' && successfulPuzzle != null) {
    debugPrint("🔧 [GENERATOR] SUCCESS - Converting to game format...");
    
    try {
      final typedSolution = solution.cast<String, int>();
      debugPrint("🔧 [GENERATOR] Solution cast successful");
      
      debugPrint("🔧 [GENERATOR] Calling _convertToGameFormat...");
      final result = _convertToGameFormat(successfulPuzzle, finalClues, typedSolution);
      
      debugPrint("🔧 [GENERATOR] _convertToGameFormat returned successfully");
      debugPrint("🔧 [GENERATOR] Result structure validated - ready to return");
      
      return result;
    } catch (e, stackTrace) {
      debugPrint("❌ [GENERATOR] ERROR in conversion: $e");
      debugPrint("❌ [GENERATOR] StackTrace: $stackTrace");
      throw Exception("Puzzle generation succeeded but conversion failed: $e");
    }
  } else {
    final msg = "Failed after ${totalStopwatch.elapsed.inSeconds}s";
    debugPrint("❌ [GENERATOR] FAILURE: $msg");
    throw Exception(msg);
  }
}

CrosswordPuzzle _convertToGameFormat(PuzzleParser puzzle, Map<String, int> clues, Map<String, int> solution) {
  final allVarNames = puzzle.numberCellLocations.map((p) => 'C_${p.y}_${p.x}').toList();
  
  final emptyCells = <String>{};
  for (final varName in allVarNames) {
    if (!clues.containsKey(varName)) {
      emptyCells.add(varName);
    }
  }

  final correctNumbers = emptyCells.map((cellId) => solution[cellId]!).toSet();
  final numberPool = _generateNumberPool(correctNumbers.cast<int>());

  // Create visual layout
  final (numberCells, operatorCells, equalsCells) = _createVisualLayout(puzzle);
  
  // Convert equations
  final gameEquations = puzzle.equations.map((eq) => CrosswordEquation(
    eq.numberCells, eq.operatorCell, eq.operator
  )).toList();

  return CrosswordPuzzle(
    clues: clues,
    emptyCells: emptyCells,
    equations: gameEquations,
    numberPool: numberPool,
    fullSolution: solution,
    numberCells: numberCells,
    operatorCells: operatorCells,
    equalsCells: equalsCells,
  );
}

List<int> _generateNumberPool(Set<int> correctNumbers) {
  final pool = <int>[];
  
  // Add all unique numbers that appear in the solution
  pool.addAll(correctNumbers);
  
  // Add a few decoy numbers (that don't appear in solution)
  final domain = List<int>.generate(9, (i) => i + 1); // 1-9
  final decoys = <int>{};
  final random = math.Random();
  
  final decoyCount = math.max(3, 6 - correctNumbers.length);
  while (decoys.length < decoyCount) {
    final decoy = domain[random.nextInt(domain.length)];
    if (!correctNumbers.contains(decoy)) {
      decoys.add(decoy);
    }
  }
  
  pool.addAll(decoys);
  pool.sort();  // CHANGED FROM pool.shuffle(random) to pool.sort()
  
  return pool;
}

(Map<math.Point<int>, String>, Map<math.Point<int>, String>, Set<math.Point<int>>) _createVisualLayout(PuzzleParser puzzle) {
  final numberCells = <math.Point<int>, String>{};
  final operatorCells = <math.Point<int>, String>{};
  final equalsCells = <math.Point<int>>{};
  
  for (final eq in puzzle.equations) {
    // Number cells
    for (int i = 0; i < eq.numberCells.length; i++) {
      numberCells[eq.numberCells[i]] = eq.variableNames[i];
    }
    
    // Operator cell
    operatorCells[eq.operatorCell] = eq.operator;
    
    // Equals cell (between second number and result)
    final eqPos = math.Point(
      (eq.numberCells[1].x + eq.numberCells[2].x) ~/ 2,
      (eq.numberCells[1].y + eq.numberCells[2].y) ~/ 2,
    );
    equalsCells.add(eqPos);  // Add the Point directly, not wrapped in {}
  }
  
  debugPrint("🎯 [LAYOUT] Created visual layout: ${numberCells.length} number cells, ${operatorCells.length} operator cells, ${equalsCells.length} equals cells");
  
  return (numberCells, operatorCells, equalsCells);  // Return the proper tuple
}

class CrosswordPuzzle {
  final Map<String, int> clues;
  final Set<String> emptyCells;
  final List<CrosswordEquation> equations;
  final List<int> numberPool;
  final Map<String, int> fullSolution;
  
  // Visual layout data
  final Map<math.Point<int>, String> numberCells; // Position -> CellId
  final Map<math.Point<int>, String> operatorCells; // Position -> Operator
  final Set<math.Point<int>> equalsCells; // Positions of equals signs

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
    final attempt = args['attemptNumber'] as int? ?? 0;
    debugPrint("🏭 [FACTORY-$attempt] ========================================");
    debugPrint("🏭 [FACTORY-$attempt] CrosswordPuzzle.generate() called in isolate");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool? ?? false;
    final customOps = args['customOps'] as List<String>? ?? [];
    final customMin = args['customMin'] as int?;
    final customMax = args['customMax'] as int?;
    
    debugPrint("🏭 [FACTORY-$attempt] Grade: $grade, Level: $level");
    debugPrint("🏭 [FACTORY-$attempt] Custom: $useCustomSettings");
    
    // Use the new scaling configuration system with custom settings support
    final config = CrosswordConfig.createConfig(
      grade, 
      level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    
    debugPrint("🏭 [FACTORY-$attempt] Config created: ${CrosswordConfig.debugConfig(
      grade, 
      level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    )}");
    
    debugPrint("🏭 [FACTORY-$attempt] Calling generateCrosswordPuzzle()...");
    
    final result = await generateCrosswordPuzzle(config);
    
    debugPrint("🏭 [FACTORY-$attempt] generateCrosswordPuzzle() returned");
    debugPrint("🏭 [FACTORY-$attempt] Result has ${result.equations.length} equations");
    debugPrint("🏭 [FACTORY-$attempt] About to return from isolate...");
    
    return result;
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [CROSSWORD VALIDATION] Starting solution validation");
    
    // Create complete solution
    final completeGrid = Map<String, int>.from(clues);
    completeGrid.addAll(userSolution);
    
    // Validate all equations
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
        debugPrint("✅ [CROSSWORD VALIDATION] ❌ Equation failed: $equation -> $operand1 ${equation.operator} $operand2 = $result");
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

class CrosswordEquation {
  final List<math.Point<int>> numberCells;
  final math.Point<int> operatorCell;
  final String operator;
  
  CrosswordEquation(this.numberCells, this.operatorCell, this.operator);
  
  List<String> get variableNames =>
      numberCells.map((p) => 'C_${p.y}_${p.x}').toList();
      
  Set<math.Point<int>> get allCells {
    final op = operatorCell;
    final n1 = numberCells[0];
    final n2 = numberCells[1];
    final n3 = numberCells[2];
    return {
      n1,
      op,
      math.Point((op.x + n2.x) ~/ 2, (op.y + n2.y) ~/ 2),
      n2,
      math.Point((n2.x + n3.x) ~/ 2, (n2.y + n3.y) ~/ 2),
      n3
    };
  }

  @override
  String toString() =>
      '${variableNames[0]} $operator ${variableNames[1]} == ${variableNames[2]}';
}