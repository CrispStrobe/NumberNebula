// ignore_for_file: constant_identifier_names, unused_element, unused_field
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../services/codebreaker_logic.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../constants/app_constants.dart';

class CodebreakerGame extends StatefulWidget {
  final int grade;
  final int level;

  const CodebreakerGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<CodebreakerGame> createState() => _CodebreakerGameState();
}

class _CodebreakerGameState extends State<CodebreakerGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  AdvancedCodebreakerPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';
  DifficultyConfig? currentDifficulty;

  bool _isDragging = false;
  int? _draggingNumber;

  @override
  void initState() {
    super.initState();
    debugPrint("🚀 [CODEBREAKER UI] Starting game initialization for Grade ${widget.grade}, Level ${widget.level}");
    debugPrint("🚀 [CODEBREAKER UI] Using ${USE_CSP_GENERATION ? 'CSP' : 'ORIGINAL'} generation algorithm");
    
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
    
    // Initialize difficulty from the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gameProvider, widget.level);
        debugPrint("🚀 [CODEBREAKER UI] Difficulty initialized: ${currentDifficulty?.grade}");
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("🚀 [CODEBREAKER UI] Disposing game and cleaning up resources");
    
    _glowController.stop();
    _successController.stop();
    _dropController.stop();
    
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;
    
    debugPrint("🎯 [CODEBREAKER UI] Starting puzzle generation process");
    
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
        'customOps': gameProvider.customOperations.map((op) => op.toString().split('.').last).toList(),
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
        'useCSP': USE_CSP_GENERATION,
      };

      debugPrint("🎯 [CODEBREAKER UI] Calling compute function with args: $puzzleArgs");
      final generatedPuzzle = await compute(AdvancedCodebreakerPuzzle.generate, puzzleArgs);
      
      debugPrint("🎯 [CODEBREAKER UI] Puzzle generation completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool);
          _isGenerating = false;
        });
        debugPrint("🎯 [CODEBREAKER UI] UI state updated with new puzzle");
        debugPrint("🎯 [CODEBREAKER UI] Number pool: ${numberPool.join(', ')}");
        debugPrint("🎯 [CODEBREAKER UI] Hidden symbols: ${generatedPuzzle.hiddenSymbols.join(', ')}");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [CODEBREAKER UI] Error generating puzzle: $e");
      debugPrint("❌ [CODEBREAKER UI] StackTrace: $stackTrace");
      
      // CRITICAL: Never crash - always provide graceful fallback
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        
        // Show error dialog and offer to return to menu
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Puzzle Generation Failed'),
            content: const Text('Unable to generate a puzzle. Would you like to try again or return to the main menu?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _generatePuzzle(); // Retry
                },
                child: const Text('Try Again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to menu
                },
                child: const Text('Back to Menu'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _placeNumber(int number, String positionId) {
    debugPrint("🎮 [PLACE] === PLACING NUMBER $number AT POSITION $positionId ===");
    
    final symbol = puzzle!.getSymbolFromPosition(positionId);
    debugPrint("🎮 [PLACE] Position $positionId corresponds to symbol: $symbol");
    debugPrint("🎮 [PLACE] Is symbol hidden? ${puzzle!.hiddenSymbols.contains(symbol)}");
    debugPrint("🎮 [PLACE] Current user solution: $userSolution");
    debugPrint("🎮 [PLACE] Number pool before: $numberPool");
    
    // Validation check
    if (!puzzle!.hiddenSymbols.contains(symbol)) {
        debugPrint("🎮 [PLACE] ❌ ERROR: Trying to place number on visible symbol $symbol!");
        return;
    }
    
    setState(() {
        // Remove this number from any other positions first
        userSolution.removeWhere((key, value) => value == number);
        
        // Find all positions with this symbol and fill them
        for (int eqIndex = 0; eqIndex < puzzle!.equations.length; eqIndex++) {
        final equation = puzzle!.equations[eqIndex];
        
        // Check term1
        if (equation.term1 is String) {
            final currentSymbol = equation.term1 as String;
            final currentPositionId = 'eq${eqIndex}_term1';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            userSolution[currentPositionId] = number;
            debugPrint("🎮 [CODEBREAKER UI] Auto-filled position $currentPositionId with $number");
            }
        }
        
        // Check term2
        if (equation.term2 is String) {
            final currentSymbol = equation.term2 as String;
            final currentPositionId = 'eq${eqIndex}_term2';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            userSolution[currentPositionId] = number;
            debugPrint("🎮 [CODEBREAKER UI] Auto-filled position $currentPositionId with $number");
            }
        }
        
        // Check result
        if (equation.result is String) {
            final currentSymbol = equation.result as String;
            final currentPositionId = 'eq${eqIndex}_result';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            userSolution[currentPositionId] = number;
            debugPrint("🎮 [CODEBREAKER UI] Auto-filled position $currentPositionId with $number");
            }
        }
        }
      
        numberPool.remove(number);
        _lastDroppedPosition = positionId;
        _dropController.forward(from: 0.0);
    });

    debugPrint("🎮 [PLACE] User solution after: $userSolution");
    debugPrint("🎮 [PLACE] Number pool after: $numberPool");
    debugPrint("🎮 [PLACE] === PLACEMENT COMPLETE ===");
    _debugCurrentState();
    _checkSolution();
  }

  void _removeNumber(String positionId) {
    debugPrint("🗑️ [CODEBREAKER UI] Removing number from position $positionId");
    
    setState(() {
      final number = userSolution[positionId];
      if (number != null) {
        final symbol = puzzle!.getSymbolFromPosition(positionId);
        debugPrint("🗑️ [CODEBREAKER UI] Removing all instances of symbol $symbol (value $number)");
        
        // Remove all positions with this symbol
        final positionsToRemove = <String>[];
        for (int eqIndex = 0; eqIndex < puzzle!.equations.length; eqIndex++) {
        final equation = puzzle!.equations[eqIndex];
        
        // Check term1
        if (equation.term1 is String) {
            final currentSymbol = equation.term1 as String;
            final currentPositionId = 'eq${eqIndex}_term1';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            positionsToRemove.add(currentPositionId);
            }
        }
        
        // Check term2
        if (equation.term2 is String) {
            final currentSymbol = equation.term2 as String;
            final currentPositionId = 'eq${eqIndex}_term2';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            positionsToRemove.add(currentPositionId);
            }
        }
        
        // Check result
        if (equation.result is String) {
            final currentSymbol = equation.result as String;
            final currentPositionId = 'eq${eqIndex}_result';
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            positionsToRemove.add(currentPositionId);
            }
        }
        }
        
        for (final pos in positionsToRemove) {
          userSolution.remove(pos);
          debugPrint("🗑️ [CODEBREAKER UI] Removed position: $pos");
        }
        
        numberPool.add(number);
        numberPool.sort();
      }
    });
  }

  void _checkSolution() {
    debugPrint("✅ [CODEBREAKER UI] Checking solution...");
    debugPrint("✅ [CODEBREAKER UI] User solution: $userSolution");
    debugPrint("✅ [CODEBREAKER UI] Required positions: ${puzzle!.hiddenPositions.length}");
    
    if (userSolution.length == puzzle!.hiddenPositions.length) {
      debugPrint("✅ [CODEBREAKER UI] All positions filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [CODEBREAKER UI] Solution validation result: $isValid");
      
      if (isValid) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    } else {
      debugPrint("✅ [CODEBREAKER UI] Solution incomplete: ${userSolution.length}/${puzzle!.hiddenPositions.length} positions filled");
    }
  }

  List<MathProblem> _extractMathProblems() {
    final problems = <MathProblem>[];
    
    for (final eq in puzzle!.equations) {
      // Only extract problems where both operands are concrete numbers
      // (either literals or solved symbols)
      int? val1, val2, result;
      
      if (eq.term1 is int) {
        val1 = eq.term1 as int;
      } else if (eq.term1 is String) {
        val1 = puzzle!.fullSolution[eq.term1 as String];
      }
      
      if (eq.term2 is int) {
        val2 = eq.term2 as int;
      } else if (eq.term2 is String) {
        val2 = puzzle!.fullSolution[eq.term2 as String];
      }
      
      if (eq.result is int) {
        result = eq.result as int;
      } else if (eq.result is String) {
        result = puzzle!.fullSolution[eq.result as String];
      }
      
      if (val1 != null && val2 != null && result != null) {
        MathOperation operation;
        switch (eq.op) {
          case '+':
            operation = MathOperation.addition;
            break;
          case '-':
            operation = MathOperation.subtraction;
            break;
          case '*':
            operation = MathOperation.multiplication;
            break;
          case '/':
            operation = MathOperation.division;
            break;
          default:
            continue; // Skip unknown operators
        }
        
        problems.add(MathProblem(
          operandA: val1,
          operandB: val2,
          operation: operation,
          answer: result,
          expression: '$val1 ${eq.op} $val2',
          difficulty: widget.grade,
        ));
      }
    }
    
    return problems;
  }

  void _handleSuccess() {
    debugPrint("🎉 [CODEBREAKER UI] SUCCESS! Player solved the puzzle!");
    HapticFeedback.lightImpact();

    int baseScore = 150 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 25;
    int operationBonus = puzzle!.equations
        .map((eq) => _getOperationBonus(eq.op))
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    debugPrint("🎉 [CODEBREAKER UI] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
    // Extract all math problems from the puzzle
    final mathProblems = _extractMathProblems();
    debugPrint("🎉 [CODEBREAKER UI] Extracted ${mathProblems.length} math problems for SRI tracking");
    
    // SINGLE CALL to unified progression system
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'codebreaker',
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
  } // handleSuccess

  void _handleFailure() {
    debugPrint("❌ [CODEBREAKER UI] FAILURE! Player gave up or failed");
    
    // Extract problems for learning purposes
    final mathProblems = _extractMathProblems();
    
    // Record the failure
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'codebreaker',
      difficulty: widget.level,
      mathProblems: mathProblems,
    ));
  }

  int _getOperationBonus(String operation) {
    switch (operation) {
      case '+': return 0;
      case '-': return 15;
      case '*': return 25;
      case '/': return 35;
      default: return 0;
    }
  }

  void _handleIncorrect() {
    debugPrint("❌ [CODEBREAKER UI] Incorrect solution - showing error message");
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.codebreakerError)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildResponsiveLayout({required bool isCompact}) {
    // This flag triggers only for the most crowded screens.
    final bool isExtraCompact = isCompact && (puzzle?.equations.length ?? 0) >= 4;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.0, 0, 16.0, isCompact ? 4.0 : 8.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _buildEquationDisplay(isCompact: isCompact, isExtraCompact: isExtraCompact),
            ),
          ),
          // Further reduce spacing in extra compact mode.
          SizedBox(height: isExtraCompact ? 4 : (isCompact ? 8 : 16)),
          _buildNumberPad(isCompact: isCompact, isExtraCompact: isExtraCompact),
        ],
      ),
    );
  }

  Widget _buildWideLayout({required bool isCompact, required bool isExtraCompact}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            // FIX: Pass the isExtraCompact flag to the child widget
            child: _buildEquationDisplay(isCompact: isCompact, isExtraCompact: isExtraCompact),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            // FIX: Pass the isExtraCompact flag to the child widget
            child: _buildNumberPad(isCompact: isCompact, isExtraCompact: isExtraCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveHeader({required bool isCompact}) {
    if (!isCompact) {
      return Column(
        children: [
          GameUI(
            title: S.of(context)!.codebreaker,
            level: widget.level,
            onBack: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              S.of(context)!.codebreakerInstructions,
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
                    S.of(context)!.codebreaker,
                    style: SpaceTheme.headlineStyle,
                  ),
                ),
                Text(
                  S.of(context)!.codebreakerInstructions,
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
              final bool isCompact = constraints.maxHeight < 450;
              final bool isWide = constraints.maxWidth > 650;
              // Calculate isExtraCompact here to pass it to all layouts
              final bool isExtraCompact = isCompact && (puzzle?.equations.length ?? 0) >= 4;

              return Column(
                children: [
                  _buildAdaptiveHeader(isCompact: isCompact),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout(isCompact: isCompact, isExtraCompact: isExtraCompact)
                        : _buildResponsiveLayout(isCompact: isCompact),
                  ),
                ],
              );
            },
          ),
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

  Widget _buildEquationDisplay({required bool isCompact, required bool isExtraCompact}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          // Reduce padding even more in the most compact layouts.
          padding: EdgeInsets.all(isExtraCompact ? 8 : (isCompact ? 12 : 16)),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                SpaceTheme.alienGreen.withValues(alpha: 0.1 * _glowAnimation.value),
                SpaceTheme.deepSpace.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SpaceTheme.alienGreen.withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: puzzle!.equations.asMap().entries.map<Widget>((entry) {
              final index = entry.key;
              final equation = entry.value;
              return _buildSingleEquation(equation, index, isCompact: isCompact, isExtraCompact: isExtraCompact);
            }).toList(),
          ),
        );
      },
    );
  }

  void _debugCurrentState() {
    debugPrint("🔍 [STATE] Need to fill: ${puzzle!.hiddenPositions.where((pos) => !userSolution.containsKey(pos)).join(', ')}");
  }

  Widget _buildSingleEquation(PuzzleEquation equation, int equationIndex, {required bool isCompact, required bool isExtraCompact}) {
    final numEquations = puzzle?.equations.length ?? 4;
    final gameProvider = context.read<GameProvider>();
    String displayOp = equation.op;
    if (displayOp == '/') {
      displayOp = gameProvider.divisionSymbol;
    } else if (displayOp == '*') {
      displayOp = gameProvider.multiplicationSymbol;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      // Trim the last bit of vertical padding from each equation row.
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isExtraCompact ? 1 : (isCompact ? 2 : 6)),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTermWidget(equation.term1, 'eq${equationIndex}_term1', isCompact: isCompact),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              displayOp,
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: _getFontSize(numEquations, 18, isCompact: isCompact), 
                color: SpaceTheme.starYellow
              ),
            ),
          ),
          _buildTermWidget(equation.term2, 'eq${equationIndex}_term2', isCompact: isCompact),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '=',
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: _getFontSize(numEquations, 20, isCompact: isCompact), 
                color: SpaceTheme.alienGreen
              ),
            ),
          ),
          _buildTermWidget(equation.result, 'eq${equationIndex}_result', isCompact: isCompact),
        ],
      ),
    );
  }

  double _getFontSize(int numEquations, double baseFontSize, {bool isCompact = false}) {
    final equationFactor = numEquations > 5 ? 0.75 : (numEquations > 4 ? 0.85 : 1.0);
    final compactFactor = isCompact ? 0.85 : 1.0;
    return baseFontSize * equationFactor * compactFactor;
  }

  Widget _buildTermWidget(dynamic term, String positionId, {required bool isCompact}) {
    final numEquations = puzzle?.equations.length ?? 4;
    final cellSize = _getCellSize(numEquations, isCompact: isCompact);
    final fontSize = _getFontSize(numEquations, 16, isCompact: isCompact);
    final symbolSize = _getFontSize(numEquations, 26, isCompact: isCompact);
    
    if (term is int) {
      // Numbers: Show as symbol with number overlay
      return Container(
        width: cellSize, 
        height: cellSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                "🔢",
                style: TextStyle(fontSize: symbolSize * 0.7, color: SpaceTheme.alienGreen.withValues(alpha: 0.3)),
              ),
            ),
            Center(
              child: Text(
                term.toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
              ),
            ),
          ],
        ),
      );
    } else {
      final symbol = term as String;
      final isPositionVisible = puzzle!.isPositionVisible(positionId); // NEW: Check position, not symbol
      final hasUserValue = userSolution.containsKey(positionId);
      final isLastDropped = positionId == _lastDroppedPosition;
      final shouldAcceptDrops = !isPositionVisible && !hasUserValue; // Can drop if not visible and no user value
      
      Widget cellContent;
      
      if (hasUserValue) {
        // User has placed a number here
        cellContent = Semantics(
          button: true,
          label: 'Placed value ${userSolution[positionId]}',
          hint: 'Tap to remove',
          child: GestureDetector(
          onTap: () => _removeNumber(positionId),
          child: Container(
            width: cellSize, 
            height: cellSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.deepSpace]),
              border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _getSymbolIcon(symbol),
                    style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.nebulaPurple.withValues(alpha: 0.6)),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      userSolution[positionId].toString(),
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: fontSize, 
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(
                            blurRadius: 2,
                            color: Colors.black,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      } else if (isPositionVisible) {
        // This specific position is visible (given as a clue)
        final value = puzzle!.getVisibleValue(positionId)!;
        cellContent = Container(
          width: cellSize, 
          height: cellSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
            border: Border.all(color: SpaceTheme.alienGreen, width: 2),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  _getSymbolIcon(symbol),
                  style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.alienGreen.withValues(alpha: 0.6)),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    value.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: fontSize, 
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          blurRadius: 2,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Empty hidden symbol - waiting for player input
        cellContent = Container(
          width: cellSize, 
          height: cellSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
            border: Border.all(color: SpaceTheme.alienGreen, width: 2),
          ),
          child: Center(
            child: Text(
              _getSymbolIcon(symbol),
              style: TextStyle(fontSize: symbolSize, color: SpaceTheme.alienGreen.withValues(alpha: 0.8)),
            ),
          ),
        );
      }
      
      if (isLastDropped) {
        cellContent = ScaleTransition(scale: _dropAnimation, child: cellContent);
      }
      
      // Wrap in DragTarget if it should accept drops
      if (shouldAcceptDrops) {
        return Semantics(
          label: 'Empty slot for $symbol',
          hint: 'Drag a number here',
          child: SizedBox(
          width: cellSize + (isCompact ? 16 : 24),
          height: cellSize + (isCompact ? 16 : 24),
          child: DragTarget<int>(
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              
              return Padding(
                padding: EdgeInsets.all(isCompact ? 8 : 12),
                child: Container(
                  width: cellSize, 
                  height: cellSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: isHovering 
                        ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                        : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
                    border: Border.all(
                        color: isHovering ? SpaceTheme.starYellow : SpaceTheme.alienGreen, 
                        width: isHovering ? 3 : 2
                    ),
                    boxShadow: isHovering ? [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ] : null,
                  ),
                  child: Center(
                    child: Text(
                      _getSymbolIcon(symbol),
                      style: TextStyle(
                        fontSize: symbolSize, 
                        color: isHovering 
                            ? SpaceTheme.starYellow 
                            : SpaceTheme.alienGreen.withValues(alpha: 0.9)
                      ),
                    ),
                  ),
                ),
              );
            },
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              debugPrint("🎯 [DROPPED] ✅ ${details.data} → $positionId");
              _placeNumber(details.data, positionId);
            },
          ),
          ),
        );
      }

      return cellContent;
    }
  }

  double _getCellSize(int numEquations, {bool isCompact = false}) {
    double baseSize;
    if (numEquations <= 3) {
      baseSize = 50.0;
    } else if (numEquations <= 4) {
      baseSize = 46.0;
    } else if (numEquations <= 5) {
      baseSize = 42.0;
    } else {
      baseSize = 38.0;
    }

    // Apply a scaling factor for compact mode.
    return isCompact ? baseSize * 0.8 : baseSize;
  }

  String _getSymbolIcon(String symbol) {
    const symbolMap = {
      'nebula': '🌌',
      'star': '⭐',
      'galaxy': '🌀',
      'planet': '🪐',
      'rocket': '🚀',
      'satellite': '🛰️',
      'comet': '☄️',
      'asteroid': '🌑',
      'sun': '☀️',
      'moon': '🌙',
      'supernova': '💥',
      'blackhole': '🕳️',
      'spaceship': '🛸',
      'alien': '👽',
      'meteor': '💫',
    };
    return symbolMap[symbol] ?? '⭐';
  }

  Widget _buildNumberPad({required bool isCompact, required bool isExtraCompact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount = isCompact || availableWidth > 400 ? 4 : 3;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(S.of(context)!.codebreakerSelectNumbers, style: SpaceTheme.bodyStyle),
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
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  // Reduce vertical spacing between number tiles in the tightest layout.
                  mainAxisSpacing: isExtraCompact ? 4 : 8,
                  childAspectRatio: isCompact ? 1.1 : 1.0,
                ),
                itemCount: numberPool.length,
                itemBuilder: (context, index) {
                  if (index >= numberPool.length) return Container();
                  final number = numberPool[index];
                  return Semantics(
                    label: 'Number $number, drag to a slot',
                    button: true,
                    child: Draggable<int>(
                    data: number,
                    onDragStarted: () {
                      setState(() {
                        _isDragging = true;
                        _draggingNumber = number;
                      });
                    },
                    onDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                        _draggingNumber = null;
                      });
                    },
                    feedback: _buildDraggableFeedback(number),
                    childWhenDragging: Opacity(opacity: 0.3, child: _buildNumberTile(number, isCompact: isCompact)),
                    child: _buildNumberTile(number, isCompact: isCompact),
                  ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNumberTile(int number, {required bool isCompact}) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        // Reduce border radius for smaller tiles
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          number.toString(),
          // Reduce font size in compact mode
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
                  Text(S.of(context)!.codebreakerWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.codebreakerWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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

