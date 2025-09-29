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

// DEVELOPMENT CONSTANT: Switch between generation approaches
const bool USE_CSP_GENERATION = false; // Set to false to use original algorithm

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
            title: Text('Puzzle Generation Failed'),
            content: Text('Unable to generate a puzzle. Would you like to try again or return to the main menu?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _generatePuzzle(); // Retry
                },
                child: Text('Try Again'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to menu
                },
                child: Text('Back to Menu'),
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
      
      // Record the response with SRI service
      final sriService = context.read<SriService>();
      final dummyProblem = MathProblem(
        expression: "codebreaker_${widget.level}",
        answer: 1,
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
    } else {
      debugPrint("✅ [CODEBREAKER UI] Solution incomplete: ${userSolution.length}/${puzzle!.hiddenPositions.length} positions filled");
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [CODEBREAKER UI] SUCCESS! Player solved the puzzle!");
    
    int baseScore = 150 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 25;
    int operationBonus = puzzle!.equations
        .map((eq) => _getOperationBonus(eq.op))
        .fold(0, (a, b) => a + b);
    
    int totalScore = baseScore + complexityBonus + operationBonus;
    debugPrint("🎉 [CODEBREAKER UI] Score calculation: base=$baseScore, complexity=$complexityBonus, operation=$operationBonus, total=$totalScore");
    
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
      case '-': return 15;
      case '*': return 25;
      case '/': return 35;
      default: return 0;
    }
  }

  void _handleIncorrect() {
    debugPrint("❌ [CODEBREAKER UI] Incorrect solution - showing error message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.codebreakerError),
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
                Text(
                  S.of(context)!.codebreaker,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
                ),
                Text(
                  S.of(context)!.codebreakerInstructions,
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
                SpaceTheme.alienGreen.withOpacity(0.1 * _glowAnimation.value),
                SpaceTheme.deepSpace.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SpaceTheme.alienGreen.withOpacity(_glowAnimation.value),
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
              equation.op,
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
                style: TextStyle(fontSize: symbolSize * 0.7, color: SpaceTheme.alienGreen.withOpacity(0.3)),
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
        cellContent = GestureDetector(
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
                    style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.nebulaPurple.withOpacity(0.6)),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
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
                  style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.alienGreen.withOpacity(0.6)),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
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
              style: TextStyle(fontSize: symbolSize, color: SpaceTheme.alienGreen.withOpacity(0.8)),
            ),
          ),
        );
      }
      
      if (isLastDropped) {
        cellContent = ScaleTransition(scale: _dropAnimation, child: cellContent);
      }
      
      // Wrap in DragTarget if it should accept drops
      if (shouldAcceptDrops) {
        return SizedBox(
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
                        color: SpaceTheme.starYellow.withOpacity(0.6),
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
                            : SpaceTheme.alienGreen.withOpacity(0.9)
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
        );
      }
      
      return cellContent;
    }
  }

  double _getCellSize(int numEquations, {bool isCompact = false}) {
    double baseSize;
    if (numEquations <= 3) baseSize = 50.0;
    else if (numEquations <= 4) baseSize = 46.0;
    else if (numEquations <= 5) baseSize = 42.0;
    else baseSize = 38.0;

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
                  return Draggable<int>(
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
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
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
          boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withOpacity(0.8), blurRadius: 20, spreadRadius: 5)],
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

//##############################################################################
// ADVANCED PUZZLE GENERATION SYSTEM (Both Original and CSP approaches)
//##############################################################################

/// Represents a single equation with term1 op term2 = result
class PuzzleEquation {
  final dynamic term1; // String or int
  final String op;
  final dynamic term2; // String or int  
  final dynamic result; // String or int

  PuzzleEquation({
    required this.term1,
    required this.op,
    required this.term2,
    required this.result,
  });

  @override
  String toString() {
    return "$term1 $op $term2 = $result";
  }

  List<String> getSymbols() {
    final symbols = <String>[];
    if (term1 is String) symbols.add(term1 as String);
    if (term2 is String) symbols.add(term2 as String);
    if (result is String) symbols.add(result as String);
    return symbols.toSet().toList();
  }

  /// Returns true if this equation has both operands as visible numbers
  bool hasBothOperandsAsNumbers() {
    return term1 is int && term2 is int;
  }
}

/// Solves puzzles using iterative substitution (Original Algorithm)
class PuzzleSolver {
  bool verbose;
  
  PuzzleSolver({this.verbose = false});

  Map<String, int>? solve(List<PuzzleEquation> equations, List<String> allSymbols) {
    if (verbose) debugPrint("🧠 [SOLVER] Starting to solve puzzle with ${equations.length} equations and ${allSymbols.length} symbols");
    
    final knownValues = <String, int>{};
    
    if (verbose) {
      debugPrint("🧠 [SOLVER] Equations to solve:");
      for (int i = 0; i < equations.length; i++) {
        debugPrint("🧠 [SOLVER]   Eq$i: ${equations[i]}");
      }
    }

    for (int iteration = 0; iteration < allSymbols.length + 1; iteration++) {
      if (verbose) debugPrint("🧠 [SOLVER] === Iteration ${iteration + 1} ===");
      
      bool newValuesFound = false;
      
      for (int eqIndex = 0; eqIndex < equations.length; eqIndex++) {
        final eq = equations[eqIndex];
        final unknowns = eq.getSymbols().where((s) => !knownValues.containsKey(s)).toList();
        
        if (verbose) debugPrint("🧠 [SOLVER] Eq$eqIndex: ${eq} -> unknowns: $unknowns");
        
        if (unknowns.length == 1) {
          final unknownSymbol = unknowns.first;
          if (knownValues.containsKey(unknownSymbol)) continue;
          
          try {
            final value = _solveFor(unknownSymbol, eq, knownValues);
            if (value != null && (value - value.round()).abs() < 1e-9) {
              final intValue = value.round();
              knownValues[unknownSymbol] = intValue;
              newValuesFound = true;
              if (verbose) debugPrint("🧠 [SOLVER] ✓ Solved: $unknownSymbol = $intValue");
            } else {
              if (verbose) debugPrint("🧠 [SOLVER] ✗ Could not solve for $unknownSymbol (value: $value)");
            }
          } catch (e) {
            if (verbose) debugPrint("🧠 [SOLVER] ✗ Error solving for $unknownSymbol: $e");
            return null;
          }
        }
      }
      
      if (knownValues.length == allSymbols.length) {
        if (verbose) debugPrint("🧠 [SOLVER] 🎉 All symbols solved! Final solution: $knownValues");
        return knownValues;
      }
      
      if (!newValuesFound) {
        if (verbose) debugPrint("🧠 [SOLVER] ❌ No new values found, terminating");
        break;
      }
    }
    
    if (verbose) debugPrint("🧠 [SOLVER] ❌ Failed to solve all symbols. Final known: $knownValues");
    return knownValues.length < allSymbols.length ? null : knownValues;
  }

  double? _solveFor(String symbol, PuzzleEquation eq, Map<String, int> known) {
    // Handle special cases where same symbol appears twice
    if (eq.term1 == symbol && eq.term2 == symbol) {
      final resVal = _getValue(eq.result, known);
      if (resVal != null) {
        switch (eq.op) {
          case '+': return resVal / 2;
          case '*': return resVal >= 0 ? math.sqrt(resVal) : null;
          default: return null;
        }
      }
      return null;
    }

    final t1 = _getValue(eq.term1, known);
    final t2 = _getValue(eq.term2, known);
    final res = _getValue(eq.result, known);
    
    // Check if we have non-symbol values that aren't our target
    if (eq.term1 != symbol && t1 == null) return null;
    if (eq.term2 != symbol && t2 == null) return null;
    if (eq.result != symbol && res == null) return null;
    
    if (symbol == eq.result) {
      if (t1 != null && t2 != null) {
        return _calculate(t1, t2, eq.op);
      }
    }
    
    if (symbol == eq.term1) {
      if (t2 != null && res != null) {
        switch (eq.op) {
          case '+': return res - t2;
          case '-': return res + t2;
          case '*': return t2 != 0 ? res / t2 : null;
          case '/': return res * t2;
          default: return null;
        }
      }
    }
    
    if (symbol == eq.term2) {
      if (t1 != null && res != null) {
        switch (eq.op) {
          case '+': return res - t1;
          case '-': return t1 - res;
          case '*': return t1 != 0 ? res / t1 : null;
          case '/': return res != 0 ? t1 / res : null;
          default: return null;
        }
      }
    }
    
    return null;
  }

  double? _getValue(dynamic term, Map<String, int> known) {
    if (term is int) return term.toDouble();
    if (term is String) return known[term]?.toDouble();
    return null;
  }

  double? _calculate(double v1, double v2, String op) {
    switch (op) {
      case '+': return v1 + v2;
      case '-': return v1 - v2;
      case '*': return v1 * v2;
      case '/': return v2 != 0 ? v1 / v2 : null;
      default: return null;
    }
  }
}

/// Advanced puzzle generator using both original and CSP approaches
class AdvancedPuzzleGenerator {
  final DifficultyConfig difficulty;
  final bool verbose;
  final bool useCSP;
  final Map<String, dynamic>? customSettings;
  final math.Random _random = math.Random();
  
  late Map<String, dynamic> params;
  List<String> symbols = [];
  Map<String, int> solution = {};
  late final PuzzleSolver solver;

  static const List<String> availableSymbols = [
    'nebula', 'star', 'galaxy', 'planet', 'rocket', 'satellite', 'comet', 
    'asteroid', 'sun', 'moon', 'supernova', 'blackhole', 'spaceship', 'alien', 'meteor'
  ];

  AdvancedPuzzleGenerator({
    required this.difficulty, 
    this.verbose = false,
    this.useCSP = USE_CSP_GENERATION,
    this.customSettings,
  }) {
    solver = PuzzleSolver(verbose: verbose);
    params = _getParams();
    if (verbose) debugPrint("🗂️ [GENERATOR] Initialized with difficulty ${difficulty.grade}, using ${useCSP ? 'CSP' : 'ORIGINAL'} approach, params: $params");
  }

  Map<String, dynamic> _getParams() {
    List<String> operatorStrings;
    List<int> valueRange;
    
    // Check if custom settings should be used
    if (customSettings != null && customSettings!['useCustomSettings'] == true) {
      // Use custom operations if provided
      final customOps = customSettings!['customOps'] as List<MathOperation>? ?? [];
      operatorStrings = customOps.map((op) {
        switch (op) {
          case MathOperation.addition: return '+';
          case MathOperation.subtraction: return '-';
          case MathOperation.multiplication: return '*';
          case MathOperation.division: return '/';
        }
      }).toList();
      
      // Use custom range if provided
      valueRange = [
        customSettings!['customMin'] as int? ?? difficulty.numberRange['min']!,
        customSettings!['customMax'] as int? ?? difficulty.numberRange['max']!,
      ];
    } else {
      // Use difficulty config
      operatorStrings = difficulty.operationTypes.map((op) {
        switch (op) {
          case MathOperation.addition: return '+';
          case MathOperation.subtraction: return '-';
          case MathOperation.multiplication: return '*';
          case MathOperation.division: return '/';
        }
      }).toList();
      
      valueRange = [
        difficulty.numberRange['min']!,
        difficulty.numberRange['max']!,
      ];
    }

    final int numSymbols, numEquations;
    final grade = difficulty.grade;

    if (grade >= 3) {
        numSymbols = 4;
        numEquations = 4;
    } else if (grade == 2) {
        numSymbols = 4;
        numEquations = 4;
    } else {
        numSymbols = 3;
        numEquations = 3;
    }

    return {
      'numSymbols': numSymbols,
      'valueRange': valueRange,
      'operators': operatorStrings.isNotEmpty ? operatorStrings : ['+'],
      'numEquations': numEquations,
    };
  }

  Future<List<PuzzleEquation>> generate() async {
    if (useCSP) {
      return _generateWithCSP();
    } else {
      return _generateOriginal(); // Call the correct method
    }
  }

  /// CSP-based generation approach
  Future<List<PuzzleEquation>> _generateWithCSP() async {
    const maxMainTries = 10;
    
    for (int attempt = 1; attempt <= maxMainTries; attempt++) {
      if (verbose) debugPrint("🗂️ [CSP GENERATOR] === Main generation attempt $attempt ===");
      
      try {
        // Step 1: Generate a valid solution (same as original)
        _generateSolutionKey();
        
        // Step 2: Create equations using the original proven logic
        final candidateEquations = _generatePuzzleCandidate();
        
        if (candidateEquations != null) {
          if (verbose) debugPrint("🗂️ [CSP GENERATOR] Testing candidate puzzle with CSP solver...");
          
          // Step 3: Verify with CSP solver (instead of iterative solver)
          final cspResult = await _validateWithCSP(candidateEquations);
          
          if (cspResult != null) {
            bool matches = true;
            for (final symbol in symbols) {
              if (cspResult[symbol] != solution[symbol]) {
                matches = false;
                break;
              }
            }
            
            if (matches) {
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] 🎉 SUCCESS! Generated valid puzzle");
              return candidateEquations;
            } else {
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: CSP result $cspResult doesn't match key $solution");
            }
          } else {
            if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: CSP could not solve the puzzle");
          }
        } else {
          if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ REJECTED: Could not generate candidate puzzle");
        }
        
      } catch (e) {
        if (verbose) debugPrint("🗂️ [CSP GENERATOR] ❌ Attempt $attempt failed: $e");
      }
    }
    
    throw Exception("CSP generation failed to generate a valid puzzle after $maxMainTries attempts");
  }

  List<PuzzleEquation>? _createKnownValidEquations() {
    final equations = <PuzzleEquation>[];
    final operators = params['operators'] as List<String>;
    final numEquations = params['numEquations'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    if (verbose) debugPrint("🗂️ [CSP GENERATOR] Creating equations for solution: $solution");
    
    // Strategy: Create equations that naturally work with mathematical relationships
    final symbolsList = symbols.toList();
    
    // First, try to create some basic relationships
    for (int attempt = 0; attempt < 50 && equations.length < numEquations; attempt++) {
      final s1 = symbolsList[_random.nextInt(symbolsList.length)];
      final s2 = symbolsList[_random.nextInt(symbolsList.length)];
      final s3 = symbolsList[_random.nextInt(symbolsList.length)];
      
      if (s1 == s2 || s1 == s3 || s2 == s3) continue;
      
      // Check if this combination already exists
      final existingEq = equations.any((eq) => 
        {eq.term1, eq.term2, eq.result}.containsAll({s1, s2, s3}));
      if (existingEq) continue;
      
      final v1 = solution[s1]!;
      final v2 = solution[s2]!;
      final v3 = solution[s3]!;
      
      // Try different arrangements and operators
      final arrangements = [
        [s1, s2, s3, v1, v2, v3], // s1 op s2 = s3
        [s1, s3, s2, v1, v3, v2], // s1 op s3 = s2  
        [s2, s1, s3, v2, v1, v3], // s2 op s1 = s3
        [s2, s3, s1, v2, v3, v1], // s2 op s3 = s1
        [s3, s1, s2, v3, v1, v2], // s3 op s1 = s2
        [s3, s2, s1, v3, v2, v1], // s3 op s2 = s1
      ];
      
      bool foundValid = false;
      for (final arr in arrangements) {
        final sym1 = arr[0] as String;
        final sym2 = arr[1] as String; 
        final symResult = arr[2] as String;
        final val1 = arr[3] as int;
        final val2 = arr[4] as int;
        final valResult = arr[5] as int;
        
        for (final op in operators) {
          bool isValid = false;
          switch (op) {
            case '+':
              isValid = (val1 + val2) == valResult;
              break;
            case '-':
              isValid = (val1 - val2) == valResult && val1 > val2;
              break;
            case '*':
              isValid = (val1 * val2) == valResult;
              break;
            case '/':
              isValid = val2 != 0 && val1 % val2 == 0 && (val1 ~/ val2) == valResult;
              break;
          }
          
          if (isValid) {
            equations.add(PuzzleEquation(
              term1: sym1,
              op: op,
              term2: sym2,
              result: symResult,
            ));
            if (verbose) debugPrint("🗂️ [CSP GENERATOR] Found valid equation: $sym1 $op $sym2 = $symResult ($val1 $op $val2 = $valResult)");
            foundValid = true;
            break;
          }
        }
        if (foundValid) break;
      }
      if (foundValid) break;
    }
    
    // If we still don't have enough equations, create some mixed number-symbol equations
    while (equations.length < numEquations) {
      final attempts = 20;
      bool found = false;
      
      for (int i = 0; i < attempts; i++) {
        final s1 = symbolsList[_random.nextInt(symbolsList.length)];
        final s2 = symbolsList[_random.nextInt(symbolsList.length)];
        if (s1 == s2) continue;
        
        final v1 = solution[s1]!;
        final v2 = solution[s2]!;
        
        // Try number op symbol = symbol  
        for (int num = valueRange[0]; num <= math.min(valueRange[1], 20); num++) {
          for (final op in operators) {
            int? result;
            switch (op) {
              case '+':
                result = num + v1;
                break;
              case '-':
                if (num > v1) result = num - v1;
                break;
              case '*':
                result = num * v1;
                break;
              case '/':
                if (v1 != 0 && num % v1 == 0) result = num ~/ v1;
                break;
            }
            
            if (result != null && result == v2 && result >= valueRange[0] && result <= valueRange[1]) {
              equations.add(PuzzleEquation(
                term1: num,
                op: op,
                term2: s1,
                result: s2,
              ));
              if (verbose) debugPrint("🗂️ [CSP GENERATOR] Found mixed equation: $num $op $s1 = $s2");
              found = true;
              break;
            }
          }
          if (found) break;
        }
        if (found) break;
      }
      
      if (!found) {
        if (verbose) debugPrint("🗂️ [CSP GENERATOR] Could not find enough valid equations");
        break;
      }
    }
    
    if (verbose) debugPrint("🗂️ [CSP GENERATOR] Created ${equations.length} equations");
    return equations.length >= math.min(numEquations, 2) ? equations : null; // Accept at least 2 equations
  }

  Future<Map<String, int>?> _validateWithCSP(List<PuzzleEquation> equations) async {
    final p = Problem();
    final valueRange = params['valueRange'] as List<int>;
    final domain = List<int>.generate(valueRange[1] - valueRange[0] + 1, (i) => i + valueRange[0]);
    
    // Add variables for symbols only
    for (final symbol in symbols) {
      p.addVariable(symbol, domain);
    }
    
    // Add equation constraints - handle mixed types
    for (final eq in equations) {
      // Collect only symbol variables for this constraint
      final symbolVars = <String>[];
      if (eq.term1 is String) symbolVars.add(eq.term1 as String);
      if (eq.term2 is String) symbolVars.add(eq.term2 as String);
      if (eq.result is String) symbolVars.add(eq.result as String);
      
      // Skip equations with no symbols (shouldn't happen, but safety check)
      if (symbolVars.isEmpty) continue;
      
      p.addConstraint(symbolVars, (assignment) {
        // Get actual values (symbols from assignment, numbers directly)
        final val1 = eq.term1 is String ? assignment[eq.term1] : (eq.term1 as int);
        final val2 = eq.term2 is String ? assignment[eq.term2] : (eq.term2 as int);
        final valResult = eq.result is String ? assignment[eq.result] : (eq.result as int);
        
        if (val1 == null || val2 == null || valResult == null) return false;
        
        switch (eq.op) {
          case '+': return (val1 + val2) == valResult;
          case '-': return (val1 - val2) == valResult;
          case '*': return (val1 * val2) == valResult;
          case '/': return val2 != 0 && val1 % val2 == 0 && (val1 ~/ val2) == valResult;
          default: return false;
        }
      });
    }
    
    // Add uniqueness constraints for symbols only
    for (int i = 0; i < symbols.length; i++) {
      for (int j = i + 1; j < symbols.length; j++) {
        p.addConstraint([symbols[i], symbols[j]], (a, b) => a != b);
      }
    }
    
    try {
      final result = await p.getSolution();
      if (result is Map<String, dynamic> && result != 'FAILURE') {
        return result.cast<String, int>();
      }
    } catch (e) {
      if (verbose) debugPrint("🗂️ [CSP] Validation error: $e");
    }
    
    return null;
  }

  bool _solutionsMatch(Map<String, int> cspSolution, Map<String, int> originalSolution) {
    for (final symbol in symbols) {
      if (cspSolution[symbol] != originalSolution[symbol]) {
        return false;
      }
    }
    return true;
  }

  List<PuzzleEquation>? _createEquationStructuresCSP(int numEquations) {
    final equations = <PuzzleEquation>[];
    final operators = params['operators'] as List<String>;
    final valueRange = params['valueRange'] as List<int>;
    final maxVal = valueRange[1];
    final minVal = valueRange[0];
    
    // Create equations using symbols strategically to ensure good interconnection
    final usedSymbols = <String>{};
    
    for (int i = 0; i < numEquations; i++) {
      // FILTER OPERATORS based on domain constraints
      final validOps = operators.where((op) {
        switch (op) {
          case '-':
            // For subtraction, ensure we can have meaningful differences within range
            return maxVal - minVal >= 1;
          case '/':
            // For division, ensure we have reasonable divisors
            return maxVal >= 2;
          case '*':
            // For multiplication, ensure products don't exceed range too quickly  
            return maxVal >= 4;
          default:
            return true;
        }
      }).toList();
      
      if (validOps.isEmpty) validOps.add('+'); // Fallback to addition
      
      final op = validOps[_random.nextInt(validOps.length)];
      
      String term1, term2, result;
      
      if (i == 0) {
        // First equation: use fresh symbols
        term1 = symbols[0];
        term2 = symbols[1]; 
        result = symbols[2];
      } else {
        // Subsequent equations: ensure at least one connection to previous equations
        final availableSymbols = symbols.where((s) => usedSymbols.contains(s)).toList();
        if (availableSymbols.isEmpty) {
          return null; // Cannot create connected equations
        }
        
        term1 = availableSymbols[_random.nextInt(availableSymbols.length)];
        
        // Choose term2 and result from unused symbols when possible
        final unusedSymbols = symbols.where((s) => !usedSymbols.contains(s)).toList();
        if (unusedSymbols.length >= 2) {
          term2 = unusedSymbols[0];
          result = unusedSymbols[1];
        } else if (unusedSymbols.length == 1) {
          term2 = unusedSymbols[0];
          result = symbols.where((s) => s != term1 && s != term2).first;
        } else {
          // All symbols used, create interconnected equations
          final otherSymbols = symbols.where((s) => s != term1).toList();
          otherSymbols.shuffle(_random);
          term2 = otherSymbols[0];
          result = otherSymbols[1];
        }
      }
      
      usedSymbols.addAll([term1, term2, result]);
      
      equations.add(PuzzleEquation(
        term1: term1,
        op: op,
        term2: term2,
        result: result,
      ));
    }
    
    return equations;
  }

  Future<Map<String, int>?> _solveWithCSPConstraints(List<PuzzleEquation> equations) async {
    final p = Problem();
    final valueRange = params['valueRange'] as List<int>;
    final domain = List<int>.generate(valueRange[1] - valueRange[0] + 1, (i) => i + valueRange[0]);
    
    // Add variables for each symbol
    for (final symbol in symbols) {
      p.addVariable(symbol, domain);
    }
    
    // Add equation constraints (3 variables - use Map signature)
    for (final eq in equations) {
      p.addConstraint([eq.term1 as String, eq.term2 as String, eq.result as String], (assignment) {
        final a = assignment[eq.term1];
        final b = assignment[eq.term2];
        final c = assignment[eq.result];
        if (a == null || b == null || c == null) return false;
        
        int calculatedResult;
        switch (eq.op) {
          case '+':
            calculatedResult = a + b;
            break;
          case '-':
            calculatedResult = a - b;
            break;
          case '*':
            calculatedResult = a * b;
            break;
          case '/':
            if (b == 0 || a % b != 0) return false;
            calculatedResult = a ~/ b;
            break;
          default:
            return false;
        }
        
        // Ensure the calculated result is within domain AND matches the result variable
        return calculatedResult >= valueRange[0] && 
              calculatedResult <= valueRange[1] && 
              calculatedResult == c;
      });
    }
    
    // FIX: Add pairwise constraints using direct function signature for 2 variables
    for (int i = 0; i < symbols.length; i++) {
      for (int j = i + 1; j < symbols.length; j++) {
        p.addConstraint([symbols[i], symbols[j]], (a, b) => a != b);
      }
    }
    
    // Solve with CSP
    try {
      final result = await p.getSolution();
      if (result is Map<String, dynamic> && result != 'FAILURE') {
        return result.cast<String, int>();
      }
    } catch (e) {
      if (verbose) debugPrint("🗂️ [CSP] Error solving: $e");
    }
    
    return null;
  }

  /// ORIGINAL generation approach (kept for comparison)
  List<PuzzleEquation> _generateOriginal() {
    const maxMainTries = 100;
    
    for (int attempt = 1; attempt <= maxMainTries; attempt++) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] === Main generation attempt $attempt ===");
      
      _generateSolutionKey();
      final candidateEquations = _generatePuzzleCandidate();
      
      if (candidateEquations != null) {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Testing candidate puzzle with solver...");
        
        final solverResult = solver.solve(candidateEquations, symbols);
        
        if (solverResult != null) {
          bool matches = true;
          for (final symbol in symbols) {
            if (solverResult[symbol] != solution[symbol]) {
              matches = false;
              break;
            }
          }
          
          if (matches) {
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] 🎉 SUCCESS! Generated valid puzzle");
            return candidateEquations;
          } else {
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Solver result $solverResult doesn't match key $solution");
          }
        } else {
          if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Solver could not solve the puzzle");
        }
      } else {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] ❌ REJECTED: Could not generate candidate puzzle");
      }
    }
    
    throw Exception("Original generation failed to generate a valid puzzle after $maxMainTries attempts");
  }

  void _generateSolutionKey() {
    final numSymbols = params['numSymbols'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    // For CSP, use smaller values that are more likely to have relationships
    final effectiveMin = useCSP ? math.max(valueRange[0], 1) : valueRange[0];
    final effectiveMax = useCSP ? math.min(valueRange[1], 30) : valueRange[1]; // Limit to 30 for CSP
    
    symbols = List.from(availableSymbols)..shuffle(_random);
    symbols = symbols.take(numSymbols).toList();
    
    final values = <int>[];
    for (int i = effectiveMin; i <= effectiveMax; i++) {
      values.add(i);
    }
    values.shuffle(_random);
    
    solution = {};
    for (int i = 0; i < numSymbols; i++) {
      solution[symbols[i]] = values[i];
    }
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Generated solution key: $solution");
  }

  List<PuzzleEquation> _createEquationPool() {
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Creating equation pool...");
    
    final pool = <PuzzleEquation>[];
    final eqStrings = <String>{};
    final valueToSymbol = <int, String>{};
    
    for (final entry in solution.entries) {
      valueToSymbol[entry.value] = entry.key;
    }
    
    final operators = params['operators'] as List<String>;
    
    // Generate ALL types of equations: symbol-symbol with ANY result
    for (final s1 in symbols) {
      for (final s2 in symbols) {
        for (final op in operators) {
          final v1 = solution[s1]!;
          final v2 = solution[s2]!;
          
          if (op == '-' && v1 < v2) continue;
          if (op == '/' && (v2 == 0 || v1 % v2 != 0)) continue;
          
          final resVal = _calculateInt(v1, v2, op);
          
          // Result can be either a symbol OR a number - both are fine!
          final result = valueToSymbol[resVal] ?? resVal;
          
          final eq = PuzzleEquation(term1: s1, op: op, term2: s2, result: result);
          final eqStr = eq.toString();
          
          if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added symbol-symbol: $eq");
          }
        }
      }
    }
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Created equation pool with ${pool.length} equations");
    return pool;
  }

  List<PuzzleEquation>? _generatePuzzleCandidate() {
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Assembling puzzle candidate with connectivity...");
    
    final pool = _createEquationPool();
    
    // Categorize equations by quality
    // Best: Both operands are symbols (result can be anything)
    final bestEquations = pool.where((eq) => 
      eq.term1 is String && eq.term2 is String
    ).toList();
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Available equations with symbol operands: ${bestEquations.length}");
    
    if (bestEquations.length < 4) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Not enough good equations available");
      return null;
    }
    
    bestEquations.shuffle(_random);
    
    final puzzle = <PuzzleEquation>[];
    final knownSymbols = <String>{};
    
    // Find entry points with at most 2 unknown symbols
    final entryPoints = bestEquations.where((eq) {
      final symbolCount = eq.getSymbols().length;
      return symbolCount <= 2;
    }).toList();
    
    if (entryPoints.isEmpty) {
      if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] No valid entry points");
      return null;
    }
    
    final firstEq = entryPoints[_random.nextInt(entryPoints.length)];
    puzzle.add(firstEq);
    bestEquations.remove(firstEq);
    knownSymbols.addAll(firstEq.getSymbols());
    
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Starting with: $firstEq, known symbols: $knownSymbols");
    
    // Build the chain
    final numSymbols = params['numSymbols'] as int;
    while (knownSymbols.length < numSymbols) {
      PuzzleEquation? nextLink;
      
      for (final eq in bestEquations) {
        final eqSymbols = eq.getSymbols().toSet();
        final newSymbols = eqSymbols.difference(knownSymbols.toSet());
        final connectingSymbols = eqSymbols.intersection(knownSymbols.toSet());
        
        if (newSymbols.length == 1 && connectingSymbols.isNotEmpty) {
          nextLink = eq;
          break;
        }
      }
      
      if (nextLink != null) {
        puzzle.add(nextLink);
        bestEquations.remove(nextLink);
        knownSymbols.addAll(nextLink.getSymbols());
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added: $nextLink, known symbols: $knownSymbols");
      } else {
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Could not find connecting equation");
        return null;
      }
    }
    
    // Add filler equations
    final numEquations = params['numEquations'] as int;
    while (puzzle.length < numEquations) {
      PuzzleEquation? filler;
      
      for (final eq in bestEquations) {
        final eqSymbols = eq.getSymbols().toSet();
        if (eqSymbols.difference(knownSymbols.toSet()).isEmpty) {
          filler = eq;
          break;
        }
      }
      
      if (filler != null) {
        puzzle.add(filler);
        bestEquations.remove(filler);
        if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Added filler: $filler");
      } else {
        break;
      }
    }
    
    puzzle.shuffle(_random);
    if (verbose) debugPrint("🗂️ [ORIGINAL GENERATOR] Final puzzle candidate: ${puzzle.map((e) => e.toString()).toList()}");
    
    return puzzle;
  }

  int _calculateInt(int v1, int v2, String op) {
    switch (op) {
      case '+': return v1 + v2;
      case '-': return v1 - v2;
      case '*': return v1 * v2;
      case '/': return v1 ~/ v2;
      default: throw Exception("Unknown operator: $op");
    }
  }
}

/// Main puzzle data structure (unchanged)
/// Main puzzle data structure - MODIFIED to track visible positions
class AdvancedCodebreakerPuzzle {
  final Map<String, int> knownSymbolValues; // Keep for backward compatibility but won't use much
  final List<PuzzleEquation> equations;
  final Set<String> hiddenSymbols;
  final List<int> numberPool;
  final List<String> hiddenPositions;
  final Map<String, int> _fullSolution;
  final Set<String> visiblePositions; // NEW: Track specific visible positions

  AdvancedCodebreakerPuzzle({
    required this.knownSymbolValues,
    required this.equations,
    required this.hiddenSymbols,
    required this.numberPool,
    required this.hiddenPositions,
    required Map<String, int> fullSolution,
    required this.visiblePositions, // NEW parameter
  }) : _fullSolution = fullSolution;

  static Future<AdvancedCodebreakerPuzzle> generate(Map<String, dynamic> args) async {
    debugPrint("🎯 [PUZZLE FACTORY] Starting puzzle generation with args: $args");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    final useCSP = args['useCSP'] as bool;
    
    debugPrint("🎯 [PUZZLE FACTORY] Using ${useCSP ? 'CSP' : 'ORIGINAL'} generation approach");
    
    // FIX: Handle the enum conversion properly
    final customOpsRaw = args['customOps'] as List<dynamic>;
    final customOps = customOpsRaw.map((op) {
      if (op is MathOperation) return op;
      // Handle string conversion from compute serialization
      if (op is String) {
        switch (op) {
          case 'addition': return MathOperation.addition;
          case 'subtraction': return MathOperation.subtraction;
          case 'multiplication': return MathOperation.multiplication;
          case 'division': return MathOperation.division;
          default: return MathOperation.addition;
        }
      }
      return MathOperation.addition; // fallback
    }).toList();
    
    final customSettings = {
      'useCustomSettings': args['useCustomSettings'] as bool,
      'customOps': customOps,
      'customMin': args['customMin'] as int,
      'customMax': args['customMax'] as int,
    };

    final generator = AdvancedPuzzleGenerator(
      difficulty: difficultyConfig, 
      verbose: true,
      useCSP: useCSP,
      customSettings: customSettings,
    );

    final puzzleEquations = await generator.generate();

    // VALIDATE that the generated solution actually works
    final testSolver = PuzzleSolver(verbose: true);
    final validationResult = testSolver.solve(puzzleEquations, generator.symbols);
    
    if (validationResult == null) {
      throw Exception("Generated puzzle has no valid solution");
    }
    
    // Verify the validation matches the generator's solution
    for (final symbol in generator.symbols) {
      if (validationResult[symbol] != generator.solution[symbol]) {
        throw Exception("Solution mismatch for symbol $symbol: expected ${generator.solution[symbol]}, got ${validationResult[symbol]}");
      }
    }
    
    debugPrint("🎯 [PUZZLE FACTORY] Solution validation passed ✓");
    debugPrint("🎯 [PUZZLE FACTORY] Generated ${puzzleEquations.length} equations");
    
    final allSymbols = generator.symbols;
    
    // NEW: Select visible positions (not symbols)
    final visiblePositions = _selectVisiblePositions(puzzleEquations, allSymbols);
    
    debugPrint("🎯 [PUZZLE FACTORY] Visible positions: $visiblePositions");
    
    // Build known values map only for visible positions
    final knownValues = <String, int>{};
    for (final pos in visiblePositions) {
      final symbol = _getSymbolFromPosition(puzzleEquations, pos);
      if (symbol != null) {
        knownValues[pos] = generator.solution[symbol]!; // Store by position, not symbol
      }
    }
    
    // Determine which symbols are completely hidden (no visible positions)
    final symbolsWithVisiblePositions = <String>{};
    for (final pos in visiblePositions) {
      final symbol = _getSymbolFromPosition(puzzleEquations, pos);
      if (symbol != null) symbolsWithVisiblePositions.add(symbol);
    }
    final hiddenSymbols = allSymbols.toSet().difference(symbolsWithVisiblePositions);
    
    final correctNumbersList = hiddenSymbols.map((s) => generator.solution[s]!).toList();
    final correctNumbersSet = correctNumbersList.toSet();
    final decoys = <int>{};
    final numberRange = generator.params['valueRange'] as List<int>;
    final maxVal = numberRange[1];

    debugPrint("🎯 [PUZZLE FACTORY] Correct numbers needed: ${correctNumbersList.join(', ')}");

    // Generate strategic decoys
    for (final correct in correctNumbersSet) {
      for (int i = 1; i <= 2; i++) {
        if (correct - i > 0) decoys.add(correct - i);
        if (correct + i <= maxVal) decoys.add(correct + i);
      }
    }
    decoys.removeAll(correctNumbersSet);

    final random = math.Random();
    final targetPoolSize = 8;
    final requiredDecoys = targetPoolSize - correctNumbersList.length;

    while (decoys.length < requiredDecoys) {
      final randomDecoy = random.nextInt(maxVal) + 1;
      if (!correctNumbersSet.contains(randomDecoy)) {
        decoys.add(randomDecoy);
      }
    }

    final numberPool = <int>[];
    numberPool.addAll(correctNumbersList);
    numberPool.addAll(decoys.take(targetPoolSize - correctNumbersList.length));

    numberPool.shuffle();
    final finalPool = numberPool;

    debugPrint("🎯 [PUZZLE FACTORY] Final number pool: ${finalPool.join(', ')}");
    
    // Build hidden positions (all symbol positions except visible ones)
    final hiddenPositions = <String>[];
    for (int i = 0; i < puzzleEquations.length; i++) {
      final eq = puzzleEquations[i];
      
      final pos1 = 'eq${i}_term1';
      final pos2 = 'eq${i}_term2';
      final posR = 'eq${i}_result';
      
      if (eq.term1 is String && !visiblePositions.contains(pos1)) {
        hiddenPositions.add(pos1);
      }
      if (eq.term2 is String && !visiblePositions.contains(pos2)) {
        hiddenPositions.add(pos2);
      }
      if (eq.result is String && !visiblePositions.contains(posR)) {
        hiddenPositions.add(posR);
      }
    }
    
    debugPrint("🎯 [PUZZLE FACTORY] Hidden positions: $hiddenPositions");
    debugPrint("🎯 [PUZZLE FACTORY] Puzzle generation complete!");
    
    return AdvancedCodebreakerPuzzle(
      knownSymbolValues: knownValues,
      equations: puzzleEquations,
      hiddenSymbols: hiddenSymbols,
      numberPool: finalPool,
      hiddenPositions: hiddenPositions,
      fullSolution: generator.solution,
      visiblePositions: visiblePositions,
    );
  }

  /// Select which specific positions should be visible (max 1 per equation)
  /// Never reveal symbols in equations that already have number literals
  static Set<String> _selectVisiblePositions(List<PuzzleEquation> equations, List<String> allSymbols) {
    final visiblePositions = <String>{};
    final random = math.Random();
    
    // Find equations that are "pure" (all terms are symbols, no number literals)
    final pureEquations = <int>[];
    for (int i = 0; i < equations.length; i++) {
      final eq = equations[i];
      final hasNoNumbers = (eq.term1 is String) && (eq.term2 is String) && (eq.result is String);
      if (hasNoNumbers) {
        pureEquations.add(i);
      }
    }
    
    debugPrint("🎯 [CLUE SELECTION] Pure symbol equations: $pureEquations out of ${equations.length}");
    
    // Only reveal from pure equations, max 1 position total
    if (pureEquations.isNotEmpty) {
      final selectedEq = pureEquations[random.nextInt(pureEquations.length)];
      final eq = equations[selectedEq];
      
      final symbolPositions = <String>[];
      if (eq.term1 is String) symbolPositions.add('eq${selectedEq}_term1');
      if (eq.term2 is String) symbolPositions.add('eq${selectedEq}_term2');
      if (eq.result is String) symbolPositions.add('eq${selectedEq}_result');
      
      if (symbolPositions.isNotEmpty) {
        final posToReveal = symbolPositions[random.nextInt(symbolPositions.length)];
        visiblePositions.add(posToReveal);
        debugPrint("🎯 [CLUE SELECTION] Revealing position: $posToReveal");
      }
    } else {
      debugPrint("🎯 [CLUE SELECTION] No pure equations available, puzzle will be harder!");
    }
    
    return visiblePositions;
  }

  static String? _getSymbolFromPosition(List<PuzzleEquation> equations, String positionId) {
    final parts = positionId.split('_');
    final eqIndex = int.parse(parts[0].substring(2));
    final termType = parts[1];
    
    if (eqIndex >= equations.length) return null;
    final equation = equations[eqIndex];
    
    switch (termType) {
      case 'term1':
        return equation.term1 is String ? equation.term1 as String : null;
      case 'term2':
        return equation.term2 is String ? equation.term2 as String : null;
      case 'result':
        return equation.result is String ? equation.result as String : null;
      default:
        return null;
    }
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [VALIDATION] Starting solution validation");
    debugPrint("✅ [VALIDATION] User solution: $userSolution");
    debugPrint("✅ [VALIDATION] Full solution: $_fullSolution");
    
    for (final entry in userSolution.entries) {
      final symbol = getSymbolFromPosition(entry.key);
      final expectedValue = _fullSolution[symbol];
      final userValue = entry.value;
      
      debugPrint("✅ [VALIDATION] Position ${entry.key}: symbol=$symbol, user=$userValue, expected=$expectedValue");
      
      if (userValue != expectedValue) {
        debugPrint("✅ [VALIDATION] ❌ Validation failed: $symbol should be $expectedValue but user provided $userValue");
        return false;
      }
    }
    
    // Check all hidden positions are filled
    for (final pos in hiddenPositions) {
      if (!userSolution.containsKey(pos)) {
        debugPrint("✅ [VALIDATION] ❌ Missing value for position $pos");
        return false;
      }
    }
    
    debugPrint("✅ [VALIDATION] ✓ Solution is valid!");
    return true;
  }

  String getSymbolFromPosition(String positionId) {
    final parts = positionId.split('_');
    final eqIndex = int.parse(parts[0].substring(2));
    final termType = parts[1];
    
    final equation = equations[eqIndex];
    
    switch (termType) {
      case 'term1':
        return equation.term1 as String;
      case 'term2':
        return equation.term2 as String;
      case 'result':
        return equation.result as String;
      default:
        throw Exception("Invalid position ID: $positionId");
    }
  }
  
  // NEW: Check if a specific position is visible
  bool isPositionVisible(String positionId) {
    return visiblePositions.contains(positionId);
  }
  
  // NEW: Get value for a visible position
  int? getVisibleValue(String positionId) {
    if (!isPositionVisible(positionId)) return null;
    final symbol = getSymbolFromPosition(positionId);
    return _fullSolution[symbol];
  }
}