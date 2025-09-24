import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../constants/app_constants.dart';
import '../../../core/services/sri_service.dart';

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
        'customOps': gameProvider.customOperations.toList(),
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
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
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cellSize, 
            height: cellSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
              border: Border.all(color: SpaceTheme.alienGreen, width: 2),
            ),
            child: Stack(
              children: [
                // Background symbol
                Center(
                  child: Text(
                    "🔢",
                    style: TextStyle(fontSize: symbolSize * 0.7, color: SpaceTheme.alienGreen.withOpacity(0.3)),
                  ),
                ),
                // Number overlay
                Center(
                  child: Text(
                    term.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final symbol = term as String;
      final isHidden = puzzle!.hiddenSymbols.contains(symbol);
      final hasUserValue = userSolution.containsKey(positionId);
      final isLastDropped = positionId == _lastDroppedPosition;
      final shouldAcceptDrops = isHidden && !hasUserValue;
      
      Widget cellContent;
      
      if (hasUserValue) {
        // Hidden symbol with user number overlay - symbol shines through
        cellContent = Container(
          width: cellSize, 
          height: cellSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.deepSpace]),
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          child: Stack(
            children: [
              // Background symbol (visible but muted)
              Center(
                child: Text(
                  _getSymbolIcon(symbol),
                  style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.nebulaPurple.withOpacity(0.6)),
                ),
              ),
              // Semi-transparent number overlay
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
        );
      } else if (!isHidden) {
        // Visible symbol with known value overlay - symbol shines through
        final value = puzzle!.knownSymbolValues[symbol]!;
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
              // Background symbol (visible but muted)
              Center(
                child: Text(
                  _getSymbolIcon(symbol),
                  style: TextStyle(fontSize: symbolSize * 0.8, color: SpaceTheme.alienGreen.withOpacity(0.6)),
                ),
              ),
              // Semi-transparent value overlay
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
        // Empty hidden symbol - show symbol prominently waiting for number
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
                  child: GestureDetector(
                    onTap: hasUserValue ? () => _removeNumber(positionId) : null,
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
                ),
              );
            },
            onWillAcceptWithDetails: (details) {
              return true;
            },
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
      'galaxy': '🌠',
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
// ADVANCED PUZZLE GENERATION SYSTEM (Fixed to avoid number-number equations)
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

/// Solves puzzles using iterative substitution
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

/// Advanced puzzle generator using the framework's difficulty settings
class AdvancedPuzzleGenerator {
  final DifficultyConfig difficulty;
  final bool verbose;
  final math.Random _random = math.Random();
  
  late Map<String, dynamic> params;
  List<String> symbols = [];
  Map<String, int> solution = {};
  // MODIFIED: The solver is now initialized within the constructor
  // to ensure the 'verbose' flag is correctly passed.
  late final PuzzleSolver solver;

  static const List<String> availableSymbols = [
    'nebula', 'star', 'galaxy', 'planet', 'rocket', 'satellite', 'comet', 
    'asteroid', 'sun', 'moon', 'supernova', 'blackhole', 'spaceship', 'alien', 'meteor'
  ];

  AdvancedPuzzleGenerator({required this.difficulty, this.verbose = false}) {
    // Initialize solver here
    solver = PuzzleSolver(verbose: verbose);
    // Get parameters based on the provided difficulty config
    params = _getParams();
    if (verbose) debugPrint("🏗️ [GENERATOR] Initialized with difficulty ${difficulty.grade}, params: $params");
  }

  // MODIFIED: This method is now fully driven by the custom settings
  // passed in the 'difficulty' config object.
  Map<String, dynamic> _getParams() {
    // 1. Get the operators from the config and convert them to the required string format
    final operatorStrings = difficulty.operationTypes.map((op) {
      switch (op) {
        case MathOperation.addition: return '+';
        case MathOperation.subtraction: return '-';
        case MathOperation.multiplication: return '*';
        case MathOperation.division: return '/';
      }
    }).toList();

    // 2. Get the number range directly from the config
    final valueRange = [
      difficulty.numberRange['min']!,
      difficulty.numberRange['max']!,
    ];

    // 3. Determine other parameters based on grade as a fallback for complexity
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

    // 4. Return the parameters, ensuring operators and range come from the custom settings
    return {
      'numSymbols': numSymbols,
      'valueRange': valueRange,
      // Use the operators from the config, with '+' as a safe fallback
      'operators': operatorStrings.isNotEmpty ? operatorStrings : ['+'],
      'numEquations': numEquations,
    };
  }

  void _generateSolutionKey() {
    final numSymbols = params['numSymbols'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    // Shuffle symbols and take the required amount
    symbols = List.from(availableSymbols)..shuffle(_random);
    symbols = symbols.take(numSymbols).toList();
    
    // Generate unique random values for each symbol
    final values = <int>[];
    for (int i = valueRange[0]; i <= valueRange[1]; i++) {
      values.add(i);
    }
    values.shuffle(_random);
    
    solution = {};
    for (int i = 0; i < numSymbols; i++) {
      solution[symbols[i]] = values[i];
    }
    
    if (verbose) debugPrint("🏗️ [GENERATOR] Generated solution key: $solution");
  }

  List<PuzzleEquation> generate() {
    const maxMainTries = 100;
    
    for (int attempt = 1; attempt <= maxMainTries; attempt++) {
      if (verbose) debugPrint("🏗️ [GENERATOR] === Main generation attempt $attempt ===");
      
      _generateSolutionKey();
      final candidateEquations = _generatePuzzleCandidate();
      
      if (candidateEquations != null) {
        if (verbose) debugPrint("🏗️ [GENERATOR] Testing candidate puzzle with solver...");
        
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
            if (verbose) debugPrint("🏗️ [GENERATOR] 🎉 SUCCESS! Generated valid puzzle");
            return candidateEquations;
          } else {
            if (verbose) debugPrint("🏗️ [GENERATOR] ❌ REJECTED: Solver result $solverResult doesn't match key $solution");
          }
        } else {
          if (verbose) debugPrint("🏗️ [GENERATOR] ❌ REJECTED: Solver could not solve the puzzle");
        }
      } else {
        if (verbose) debugPrint("🏗️ [GENERATOR] ❌ REJECTED: Could not generate candidate puzzle");
      }
    }
    
    throw Exception("Failed to generate a valid puzzle after $maxMainTries attempts");
  }

  List<PuzzleEquation> _createEquationPool() {
    if (verbose) debugPrint("🏗️ [GENERATOR] Creating equation pool...");
    
    final pool = <PuzzleEquation>[];
    final eqStrings = <String>{};
    final valueToSymbol = <int, String>{};
    
    for (final entry in solution.entries) {
      valueToSymbol[entry.value] = entry.key;
    }
    
    final operators = params['operators'] as List<String>;
    
    // Template 1: symbol op symbol = result (symbol or number)
    for (final s1 in symbols) {
      for (final s2 in symbols) {
        for (final op in operators) {
          final v1 = solution[s1]!;
          final v2 = solution[s2]!;
          
          if (op == '-' && v1 < v2) continue;
          if (op == '/' && (v2 == 0 || v1 % v2 != 0)) continue;
          
          final resVal = _calculateInt(v1, v2, op);
          final result = valueToSymbol[resVal] ?? resVal;
          
          final eq = PuzzleEquation(term1: s1, op: op, term2: s2, result: result);
          final eqStr = eq.toString();
          
          if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🏗️ [GENERATOR] Added symbol-symbol: $eq");
          }
        }
      }
    }
    
    // Template 2: symbol op number = result (symbol or number)
    for (final s1 in symbols) {
      final v1 = solution[s1]!;
      
      for (int attempt = 0; attempt < 5; attempt++) {
        final op = operators[_random.nextInt(operators.length)];
        int? n2;
        
        switch (op) {
          case '+':
            n2 = _random.nextInt(params['valueRange'][1]) + 1;
            break;
          case '-':
            if (v1 > 1) n2 = _random.nextInt(v1 - 1) + 1;
            break;
          case '*':
            n2 = _random.nextInt(8) + 2; // 2-9
            break;
          case '/':
            final divisors = <int>[];
            for (int i = 2; i < v1; i++) {
              if (v1 % i == 0) divisors.add(i);
            }
            if (divisors.isNotEmpty) n2 = divisors[_random.nextInt(divisors.length)];
            break;
        }
        
        if (n2 != null) {
          final resVal = _calculateInt(v1, n2, op);
          final result = valueToSymbol[resVal] ?? resVal;
          
          // Create symbol op number = result
          final eq1 = PuzzleEquation(term1: s1, op: op, term2: n2, result: result);
          final eq1Str = eq1.toString();
          if (!eqStrings.contains(eq1Str)) {
            pool.add(eq1);
            eqStrings.add(eq1Str);
            if (verbose) debugPrint("🏗️ [GENERATOR] Added symbol-number: $eq1");
          }
          
          // For commutative operations, also create number op symbol = result
          if (op == '+' || op == '*') {
            final eq2 = PuzzleEquation(term1: n2, op: op, term2: s1, result: result);
            final eq2Str = eq2.toString();
            if (!eqStrings.contains(eq2Str)) {
              pool.add(eq2);
              eqStrings.add(eq2Str);
              if (verbose) debugPrint("🏗️ [GENERATOR] Added number-symbol: $eq2");
            }
          }
        }
      }
    }
    
    // Template 3: number op number = symbol (but only strategic ones)
    for (final sRes in symbols) {
      final vRes = solution[sRes]!;
      
      for (int attempt = 0; attempt < 5; attempt++) {
        final op = operators[_random.nextInt(operators.length)];
        
        if (op == '+' && vRes > 1) {
          final n1 = _random.nextInt(vRes - 1) + 1;
          final n2 = vRes - n1;
          
          final eq = PuzzleEquation(term1: n1, op: op, term2: n2, result: sRes);
          final eqStr = eq.toString();
          if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🏗️ [GENERATOR] Added number-number-symbol: $eq");
          }
        }
      }
    }
    
    if (verbose) debugPrint("🏗️ [GENERATOR] Created equation pool with ${pool.length} equations");
    return pool;
  }

  List<PuzzleEquation>? _generatePuzzleCandidate() {
    if (verbose) debugPrint("🏗️ [GENERATOR] Assembling puzzle candidate with connectivity...");
    
    final pool = _createEquationPool();
    pool.shuffle(_random);
    
    final puzzle = <PuzzleEquation>[];
    final knownSymbols = <String>{};
    
    // Find valid entry points: equations with ≤1 symbols AND at least one symbol on the left side
    final entryPoints = pool.where((eq) {
      final symbolCount = eq.getSymbols().length;
      final hasSymbolOnLeft = eq.term1 is String || eq.term2 is String;
      return symbolCount <= 1 && hasSymbolOnLeft;
    }).toList();
    
    if (entryPoints.isEmpty) {
      if (verbose) debugPrint("🏗️ [GENERATOR] No valid entry points found");
      return null;
    }
    
    final firstEq = entryPoints[_random.nextInt(entryPoints.length)];
    puzzle.add(firstEq);
    pool.remove(firstEq);
    knownSymbols.addAll(firstEq.getSymbols());
    
    if (verbose) debugPrint("🏗️ [GENERATOR] Starting with: $firstEq, known symbols: $knownSymbols");
    
    // Build the chain by adding equations that introduce exactly one new symbol
    final numSymbols = params['numSymbols'] as int;
    while (knownSymbols.length < numSymbols) {
      PuzzleEquation? nextLink;
      
      for (final eq in pool) {
        final eqSymbols = eq.getSymbols().toSet();
        final newSymbols = eqSymbols.difference(knownSymbols.toSet());
        final connectingSymbols = eqSymbols.intersection(knownSymbols.toSet());
        
        // Must introduce exactly one new symbol AND connect to known symbols
        if (newSymbols.length == 1 && connectingSymbols.isNotEmpty) {
          nextLink = eq;
          break;
        }
      }
      
      if (nextLink != null) {
        puzzle.add(nextLink);
        pool.remove(nextLink);
        knownSymbols.addAll(nextLink.getSymbols());
        if (verbose) debugPrint("🏗️ [GENERATOR] Added: $nextLink, known symbols: $knownSymbols");
      } else {
        if (verbose) debugPrint("🏗️ [GENERATOR] Dead end - no valid connecting equation found");
        return null;
      }
    }
    
    // Add filler equations that use only known symbols
    final numEquations = params['numEquations'] as int;
    while (puzzle.length < numEquations) {
      PuzzleEquation? filler;
      
      for (final eq in pool) {
        final eqSymbols = eq.getSymbols().toSet();
        if (eqSymbols.difference(knownSymbols.toSet()).isEmpty) {
          filler = eq;
          break;
        }
      }
      
      if (filler != null) {
        puzzle.add(filler);
        pool.remove(filler);
        if (verbose) debugPrint("🏗️ [GENERATOR] Added filler: $filler");
      } else {
        break;
      }
    }
    
    puzzle.shuffle(_random);
    if (verbose) debugPrint("🏗️ [GENERATOR] Final puzzle candidate: ${puzzle.map((e) => e.toString()).toList()}");
    
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

/// Main puzzle data structure
class AdvancedCodebreakerPuzzle {
  final Map<String, int> knownSymbolValues;
  final List<PuzzleEquation> equations;
  final Set<String> hiddenSymbols;
  final List<int> numberPool;
  final List<String> hiddenPositions;
  final Map<String, int> _fullSolution;

  AdvancedCodebreakerPuzzle({
    required this.knownSymbolValues,
    required this.equations,
    required this.hiddenSymbols,
    required this.numberPool,
    required this.hiddenPositions,
    required Map<String, int> fullSolution,
  }) : _fullSolution = fullSolution;

  static AdvancedCodebreakerPuzzle generate(Map<String, dynamic> args) {
    debugPrint("🎯 [PUZZLE FACTORY] Starting puzzle generation with args: $args");
    
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final difficultyConfig = args['difficulty'] as DifficultyConfig;
    
    debugPrint("🎯 [PUZZLE FACTORY] Using difficulty config: ${difficultyConfig.grade}");
    
    final generator = AdvancedPuzzleGenerator(difficulty: difficultyConfig, verbose: true);
    final puzzleEquations = generator.generate();
    
    debugPrint("🎯 [PUZZLE FACTORY] Generated ${puzzleEquations.length} equations");
    
    final allSymbols = generator.symbols;
    final visibleCount = 1; // Always show exactly 1 symbol to start

    allSymbols.shuffle();
    final visibleSymbols = allSymbols.take(visibleCount).toList();
    final hiddenSymbols = allSymbols.toSet().difference(visibleSymbols.toSet());
    
    debugPrint("🎯 [PUZZLE FACTORY] Visible symbols: $visibleSymbols");
    debugPrint("🎯 [PUZZLE FACTORY] Hidden symbols: $hiddenSymbols");
    
    final knownValues = <String, int>{};
    for (final symbol in visibleSymbols) {
      knownValues[symbol] = generator.solution[symbol]!;
    }
    
    final correctNumbers = hiddenSymbols.map((s) => generator.solution[s]!).toSet();
    final decoys = <int>{};
    final numberRange = generator.params['valueRange'] as List<int>;
    final maxVal = numberRange[1];

    debugPrint("🎯 [PUZZLE FACTORY] Correct numbers needed: ${correctNumbers.join(', ')}");

    // Generate strategic decoys (close to correct numbers)
    for (final correct in correctNumbers) {
      for (int i = 1; i <= 2; i++) {
        if (correct - i > 0) decoys.add(correct - i);
        if (correct + i <= maxVal) decoys.add(correct + i);
      }
    }
    decoys.removeAll(correctNumbers);

    final random = math.Random();
    final targetPoolSize = 8;
    final requiredDecoys = targetPoolSize - correctNumbers.length;

    while (decoys.length < requiredDecoys) {
      final randomDecoy = random.nextInt(maxVal) + 1;
      if (!correctNumbers.contains(randomDecoy)) {
        decoys.add(randomDecoy);
      }
    }

    final numberPool = <int>[];
    numberPool.addAll(correctNumbers);
    numberPool.addAll(decoys.take(targetPoolSize - correctNumbers.length));

    numberPool.shuffle();
    final finalPool = numberPool;

    debugPrint("🎯 [PUZZLE FACTORY] Final number pool: ${finalPool.join(', ')}");
    debugPrint("🎯 [PUZZLE FACTORY] Verifying all correct numbers included: ${correctNumbers.every((n) => finalPool.contains(n))}");
    
    final hiddenPositions = <String>[];
    for (int i = 0; i < puzzleEquations.length; i++) {
      final eq = puzzleEquations[i];
      if (eq.term1 is String && hiddenSymbols.contains(eq.term1)) {
        hiddenPositions.add('eq${i}_term1');
      }
      if (eq.term2 is String && hiddenSymbols.contains(eq.term2)) {
        hiddenPositions.add('eq${i}_term2');
      }
      if (eq.result is String && hiddenSymbols.contains(eq.result)) {
        hiddenPositions.add('eq${i}_result');
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
    );
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [VALIDATION] Starting solution validation");
    debugPrint("✅ [VALIDATION] User solution: $userSolution");
    debugPrint("✅ [VALIDATION] Full solution: $_fullSolution");
    
    final completeValues = Map<String, int>.from(knownSymbolValues);
    
    for (final entry in userSolution.entries) {
      final symbol = getSymbolFromPosition(entry.key);
      final expectedValue = _fullSolution[symbol];
      final userValue = entry.value;
      
      debugPrint("✅ [VALIDATION] Position ${entry.key}: symbol=$symbol, user=$userValue, expected=$expectedValue");
      
      if (userValue != expectedValue) {
        debugPrint("✅ [VALIDATION] ❌ Validation failed: $symbol should be $expectedValue but user provided $userValue");
        return false;
      }
      
      completeValues[symbol] = userValue;
    }
    
    for (final symbol in _fullSolution.keys) {
      if (completeValues[symbol] != _fullSolution[symbol]) {
        debugPrint("✅ [VALIDATION] ❌ Missing or incorrect value for symbol $symbol");
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
}