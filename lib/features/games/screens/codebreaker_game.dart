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
            child: Column(
            children: [
                GameUI(
                title: S.of(context)!.codebreaker,
                level: widget.level, 
                onBack: () => Navigator.of(context).pop()
                ),
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                    S.of(context)!.codebreakerInstructions,
                    style: SpaceTheme.bodyStyle, 
                    textAlign: TextAlign.center,
                ),
                ),
                Expanded(
                child: LayoutBuilder(
                    builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 650;
                    return isWide ? _buildWideLayout() : _buildConstrainedTallLayout(constraints);
                    },
                ),
                ),
            ],
            ),
        ),
        ),
    );
    }

  Widget _buildConstrainedTallLayout(BoxConstraints constraints) {
    final availableHeight = constraints.maxHeight;
    // Adjust ratios based on number of equations to prevent overflow
    final numEquations = puzzle?.equations.length ?? 4;
    final equationRatio = numEquations > 4 ? 0.65 : 0.6; // More space for more equations
    final numberPadRatio = 1.0 - equationRatio;
    
    final equationHeight = availableHeight * equationRatio;
    final numberPadHeight = availableHeight * numberPadRatio;
    
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
        children: [
            SizedBox(
            height: equationHeight,
            child: SingleChildScrollView(
                child: _buildEquationDisplay(),
            ),
            ),
            SizedBox(
            height: numberPadHeight,
            child: _buildNumberPad(),
            ),
        ],
        ),
    );
    }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildEquationDisplay()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildNumberPad()),
        ],
      ),
    );
  }

  Widget _buildEquationDisplay() {
    return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
        return Container(
            padding: const EdgeInsets.all(16),
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
            children: puzzle!.equations.asMap().entries.map((entry) {
                final index = entry.key;
                final equation = entry.value;
                return _buildSingleEquation(equation, index);
            }).toList(),
            ),
        );
        },
    );
    }

  void _debugCurrentState() {
    debugPrint("🔍 [STATE] Need to fill: ${puzzle!.hiddenPositions.where((pos) => !userSolution.containsKey(pos)).join(', ')}");
    }

  Widget _buildSingleEquation(PuzzleEquation equation, int equationIndex) {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
            _buildTermWidget(equation.term1, 'eq${equationIndex}_term1'),
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
                equation.op,
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 18, color: SpaceTheme.starYellow),
            ),
            ),
            _buildTermWidget(equation.term2, 'eq${equationIndex}_term2'),
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
                '=',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 20, color: SpaceTheme.alienGreen),
            ),
            ),
            _buildTermWidget(equation.result, 'eq${equationIndex}_result'),
        ],
        ),
    );
    }

  Widget _buildTermWidget(dynamic term, String positionId) {
    // Dynamic sizing based on number of equations to prevent overflow
    final numEquations = puzzle?.equations.length ?? 4;
    final cellSize = numEquations > 5 ? 42.0 : (numEquations > 4 ? 46.0 : 50.0);
    final fontSize = numEquations > 5 ? 14.0 : (numEquations > 4 ? 15.0 : 16.0);
    final symbolSize = numEquations > 5 ? 22.0 : (numEquations > 4 ? 24.0 : 26.0);
    
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
                    color: Colors.black.withOpacity(0.4), // Much more transparent
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
                    color: Colors.black.withOpacity(0.4), // Much more transparent
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
            return Container(
                width: cellSize + 32, // Larger hit area for better detection
                height: cellSize + 32,
                child: DragTarget<int>(
                builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    
                    return Container(
                    padding: const EdgeInsets.all(16), // More padding for easier targeting
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
                            blurRadius: 12,
                            spreadRadius: 3,
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
                    debugPrint("🎯 [DRAG TARGET] Will accept ${details.data} at $positionId");
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

  Widget _buildNumberPad() {
    return LayoutBuilder(
        builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount = availableWidth > 400 ? 4 : 3;
        
        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(S.of(context)!.codebreakerSelectNumbers, style: SpaceTheme.bodyStyle),
            const SizedBox(height: 8),
            Expanded(
                child: Container(
                padding: const EdgeInsets.all(12),
                decoration: SpaceTheme.cardDecoration.copyWith(
                    border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
                ),
                child: GridView.builder(
                    shrinkWrap: true,
                    physics: _isDragging ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
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
                        onDragStarted: () {
                            setState(() {
                            _isDragging = true;
                            _draggingNumber = number;
                            });
                            debugPrint("🎮 [DRAG] 🚀 Started: $number");
                        },
                        onDragEnd: (details) {
                            setState(() {
                            _isDragging = false;
                            _draggingNumber = null;
                            });
                            
                            debugPrint("🎮 [DRAG] 🏁 End: $number, accepted=${details.wasAccepted}");
                            if (!details.wasAccepted) {
                            debugPrint("🎮 [DRAG] ❌ FAILED: $number");
                            final availableTargets = puzzle!.hiddenPositions.where((pos) => !userSolution.containsKey(pos)).toList();
                            debugPrint("🎮 [DRAG] Available targets: $availableTargets");
                            }
                        },
                        feedback: _buildDraggableFeedback(number),
                        childWhenDragging: Opacity(opacity: 0.3, child: _buildNumberTile(number)),
                        child: _buildNumberTile(number),
                        );
                    },
                ),
                ),
            ),
            ],
        );
        },
    );
    }

  Widget _buildNumberTile(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18)),
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
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
// ADVANCED PUZZLE GENERATION SYSTEM (Preserved original logic)
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
}

/// Solves puzzles using iterative substitution
class PuzzleSolver {
  bool verbose;
  
  PuzzleSolver({this.verbose = false});

  Map<String, int>? solve(List<PuzzleEquation> equations, List<String> allSymbols, [Map<String, int>? initialKnown]) {
    if (verbose) debugPrint("🧠 [SOLVER] Starting to solve puzzle with ${equations.length} equations and ${allSymbols.length} symbols");
    
    final knownValues = Map<String, int>.from(initialKnown ?? {});
    
    if (verbose) {
      debugPrint("🧠 [SOLVER] Initial known values: $knownValues");
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
  final PuzzleSolver solver = PuzzleSolver(verbose: true);

  static const List<String> availableSymbols = [
    'nebula', 'star', 'galaxy', 'planet', 'rocket', 'satellite', 'comet', 
    'asteroid', 'sun', 'moon', 'supernova', 'blackhole', 'spaceship', 'alien', 'meteor'
  ];

  AdvancedPuzzleGenerator({required this.difficulty, this.verbose = false}) {
    params = _getParams();
    if (verbose) debugPrint("🏗️ [GENERATOR] Initialized with difficulty ${difficulty.grade}, params: $params");
  }

  Map<String, dynamic> _getParams() {
    final grade = difficulty.grade;
    final operationTypes = difficulty.operationTypes;
    final numberRange = difficulty.numberRange;
    
    // Convert the framework operations to our string format
    final operatorStrings = operationTypes.map((op) {
      switch (op) {
        case MathOperation.addition: return '+';
        case MathOperation.subtraction: return '-';
        case MathOperation.multiplication: return '*';
        case MathOperation.division: return '/';
      }
    }).toList();
    
    return {
      'numSymbols': math.min(4 + grade, 6),
      'valueRange': [numberRange['min']!, numberRange['max']!],
      'operators': operatorStrings,
      'numEquations': math.min(4 + grade, 6)
    };
  }

  void _generateSolutionKey() {
    final numSymbols = params['numSymbols'] as int;
    final valueRange = params['valueRange'] as List<int>;
    
    symbols = List.from(availableSymbols)..shuffle(_random);
    symbols = symbols.take(numSymbols).toList();
    
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
    if (verbose) debugPrint("🏗️ [GENERATOR] Creating sophisticated equation pool...");
    
    final pool = <PuzzleEquation>[];
    final eqStrings = <String>{};
    final valueToSymbol = <int, String>{};
    
    for (final entry in solution.entries) {
        valueToSymbol[entry.value] = entry.key;
    }
    
    final operators = params['operators'] as List<String>;
    
    // Template 1: symbol op symbol = result (number or symbol)
    for (final s1 in symbols) {
        for (final s2 in symbols) {
        for (final op in operators) {
            final v1 = solution[s1]!;
            final v2 = solution[s2]!;
            
            if ((op == '-' && v1 == v2) || (op == '/' && v1 == v2)) continue;
            if (op == '-' && v1 < v2) continue;
            if (op == '/' && (v2 == 0 || v1 % v2 != 0)) continue;
            
            final resVal = _calculateInt(v1, v2, op);
            final result = valueToSymbol[resVal] ?? (resVal <= params['valueRange'][1] ? resVal : null);
            if (result == null) continue;

            
            final eq = PuzzleEquation(term1: s1, op: op, term2: s2, result: result);
            final eqStr = eq.toString();
            
            if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🏗️ [GENERATOR] Added: $eq");
            }
        }
        }
    }
    
    // Template 2: number op number = symbol
    for (final sRes in symbols) {
    final vRes = solution[sRes]!;
    
    for (int i = 0; i < 8; i++) {
        final op = operators[_random.nextInt(operators.length)];
        int? n1, n2;
        
        switch (op) {
        case '+':
            if (vRes <= 2) continue;
            final maxSplit = vRes - 1;
            n1 = _random.nextInt(maxSplit) + 1;
            n2 = vRes - n1;
            break;
        case '-':
            final valueRange = params['valueRange'] as List<int>;
            final maxVal = valueRange[1];
            final rangeSize = maxVal - vRes;
            if (rangeSize <= 0) continue;
            n1 = _random.nextInt(rangeSize) + vRes + 1;
            n2 = n1 - vRes;
            break;
        case '*':
            final factors = <int>[];
            for (int f = 2; f <= math.sqrt(vRes).floor(); f++) {
            if (vRes % f == 0) factors.add(f);
            }
            if (factors.isEmpty) continue;
            n1 = factors[_random.nextInt(factors.length)];
            n2 = vRes ~/ n1;
            break;
        default:
            continue;
        }
        
        if (n1 != null && n2 != null) {
        final eq = PuzzleEquation(term1: n1, op: op, term2: n2, result: sRes);
        final eqStr = eq.toString();
        
        if (!eqStrings.contains(eqStr)) {
            pool.add(eq);
            eqStrings.add(eqStr);
            if (verbose) debugPrint("🏗️ [GENERATOR] Added factorized: $eq");
        }
        }
    }
    }
    
    if (verbose) debugPrint("🏗️ [GENERATOR] Created equation pool with ${pool.length} equations");
    return pool;
    }

  List<PuzzleEquation>? _generatePuzzleCandidate() {
    if (verbose) debugPrint("🏗️ [GENERATOR] Assembling puzzle candidate...");
    
    final pool = _createEquationPool();
    pool.shuffle(_random);
    
    final puzzle = <PuzzleEquation>[];
    final knownSymbols = <String>{};
    
    final entryPoints = pool.where((eq) => eq.getSymbols().length <= 1).toList();
    if (entryPoints.isEmpty) {
      if (verbose) debugPrint("🏗️ [GENERATOR] No entry points found");
      return null;
    }
    
    final firstEq = entryPoints[_random.nextInt(entryPoints.length)];
    puzzle.add(firstEq);
    pool.remove(firstEq);
    knownSymbols.addAll(firstEq.getSymbols());
    
    if (verbose) debugPrint("🏗️ [GENERATOR] Starting with: $firstEq, known symbols: $knownSymbols");
    
    final numSymbols = params['numSymbols'] as int;
    while (knownSymbols.length < numSymbols) {
      PuzzleEquation? nextLink;
      
      for (final eq in pool) {
        final eqSyms = eq.getSymbols().toSet();
        final newSymbols = eqSyms.difference(knownSymbols);
        final connectingSymbols = eqSyms.intersection(knownSymbols);
        
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
    
    final numEquations = params['numEquations'] as int;
    while (puzzle.length < numEquations) {
      PuzzleEquation? filler;
      
      for (final eq in pool) {
        final eqSyms = eq.getSymbols().toSet();
        if (eqSyms.difference(knownSymbols).isEmpty) {
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
    final visibleCount = 1;

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
    final numberRange = difficultyConfig.numberRange;
    final maxVal = numberRange['max']!;

    debugPrint("🎯 [PUZZLE FACTORY] Correct numbers needed: ${correctNumbers.join(', ')}");

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