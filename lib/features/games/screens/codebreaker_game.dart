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

  CodebreakerPuzzle? puzzle;
  Map<String, int> userSolution = {};
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  String _lastDroppedPosition = '';

  @override
  void initState() {
    super.initState();
    debugPrint("👽 [UI] CodebreakerGame.initState() - Starting initialization");
    
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
    
    debugPrint("👽 [UI] Animation controllers initialized, calling _generatePuzzle()");
    _generatePuzzle();
  }

  @override
  void dispose() {
    debugPrint("👽 [UI] CodebreakerGame.dispose() - Cleaning up controllers");
    
    _glowController.stop();
    _successController.stop();
    _dropController.stop();
    
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    
    puzzle = null;
    userSolution.clear();
    numberPool.clear();
    
    debugPrint("👽 [UI] All controllers disposed and data cleared");
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("👽 [UI] _generatePuzzle() - Starting puzzle generation");
    
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
        'useCustomSettings': gameProvider.useCustomProblemSettings,
        'customOps': gameProvider.customOperations.toList(),
        'customMin': gameProvider.customRangeMin,
        'customMax': gameProvider.customRangeMax,
      };

      final generatedPuzzle = await compute(CodebreakerPuzzle.generate, puzzleArgs);
      
      debugPrint("👽 [UI] compute() completed successfully");
      
      if (mounted) {
        setState(() {
          puzzle = generatedPuzzle;
          numberPool = List.from(generatedPuzzle.numberPool);
          _isGenerating = false;
        });
        debugPrint("👽 [UI] State updated successfully");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [UI] Error in _generatePuzzle: $e");
      debugPrint("❌ [UI] StackTrace: $stackTrace");
    }
  }

  void _placeNumber(int number, String positionId) {
    debugPrint("🎯 [UI] _placeNumber($number, $positionId)");
    
    setState(() {
      // Remove number from previous position if it exists
      userSolution.removeWhere((key, value) => value == number);
      
      // Get the symbol for this position
      final symbol = puzzle!.getSymbolFromPosition(positionId);
      
      // Place in new position
      userSolution[positionId] = number;
      
      // Auto-fill ALL other positions with the same symbol
      for (int eqIndex = 0; eqIndex < puzzle!.equations.length; eqIndex++) {
        final equation = puzzle!.equations[eqIndex];
        for (int symIndex = 0; symIndex < equation.leftSideSymbols.length; symIndex++) {
          final currentSymbol = equation.leftSideSymbols[symIndex];
          final currentPositionId = 'eq${eqIndex}_sym${symIndex}';
          
          if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
            userSolution[currentPositionId] = number;
          }
        }
      }
      
      numberPool.remove(number);
      _lastDroppedPosition = positionId;
      _dropController.forward(from: 0.0);
    });
    
    debugPrint("🎯 [UI] Number placed successfully, auto-filled all ${puzzle!.getSymbolFromPosition(positionId)} positions");
    _checkSolution();
  }

  void _removeNumber(String positionId) {
    debugPrint("🗑️ [UI] _removeNumber($positionId)");
    setState(() {
      final number = userSolution[positionId];
      if (number != null) {
        // Get the symbol for this position
        final symbol = puzzle!.getSymbolFromPosition(positionId);
        
        // Remove ALL positions with this symbol
        final positionsToRemove = <String>[];
        for (int eqIndex = 0; eqIndex < puzzle!.equations.length; eqIndex++) {
          final equation = puzzle!.equations[eqIndex];
          for (int symIndex = 0; symIndex < equation.leftSideSymbols.length; symIndex++) {
            final currentSymbol = equation.leftSideSymbols[symIndex];
            final currentPositionId = 'eq${eqIndex}_sym${symIndex}';
            
            if (currentSymbol == symbol && puzzle!.hiddenSymbols.contains(currentSymbol)) {
              positionsToRemove.add(currentPositionId);
            }
          }
        }
        
        // Remove all positions with this symbol
        for (final pos in positionsToRemove) {
          userSolution.remove(pos);
        }
        
        numberPool.add(number);
        numberPool.sort();
      }
    });
  }

  void _checkSolution() {
    debugPrint("✅ [UI] _checkSolution() - userSolution: $userSolution");
    
    if (userSolution.length == puzzle!.hiddenPositions.length) {
      debugPrint("✅ [UI] All positions filled, validating solution");
      
      final isValid = puzzle!.validateSolution(userSolution);
      debugPrint("✅ [UI] Solution validation result: $isValid");
      
      if (isValid) {
        _handleSuccess();
      } else {
        _handleIncorrect();
      }
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [UI] _handleSuccess() - Starting success animation");
    
    int baseScore = 150 * widget.grade;
    int complexityBonus = puzzle!.equations.length * 25;
    int operationBonus = puzzle!.equations
        .expand((eq) => eq.operations)
        .map(_getOperationBonus)
        .fold(0, (a, b) => a + b);
    
    context.read<GameProvider>().addScore(baseScore + complexityBonus + operationBonus);
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
    debugPrint("❌ [UI] _handleIncorrect() - Showing failure message");
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(S.of(context)!.codebreakerTransmissionReceived, style: SpaceTheme.bodyStyle),
            ],
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    return isWide ? _buildWideLayout() : _buildTallLayout();
                  },
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildEquationDisplay(),
            const SizedBox(height: 24),
            _buildNumberPad(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEquationDisplay() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
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

  Widget _buildSingleEquation(Equation equation, int equationIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...equation.leftSideSymbols.asMap().entries.expand((entry) {
            final symIndex = entry.key;
            final symbol = entry.value;
            final positionId = 'eq${equationIndex}_sym${symIndex}';
            
            final widgets = <Widget>[
              _buildSymbolOrDropZone(symbol, positionId),
            ];
            
            if (symIndex < equation.operations.length) {
              widgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    equation.operations[symIndex],
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 24,
                      color: SpaceTheme.starYellow,
                    ),
                  ),
                ),
              );
            }
            
            return widgets;
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '=',
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: 28,
                color: SpaceTheme.alienGreen,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.alienGreen, width: 2),
            ),
            child: Text(
              equation.result.toString(),
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolOrDropZone(String symbol, String positionId) {
    final isHidden = puzzle!.hiddenSymbols.contains(symbol);
    final hasUserValue = userSolution.containsKey(positionId);
    final isLastDropped = positionId == _lastDroppedPosition;
    
    Widget cell;
    
    if (isHidden) {
      cell = DragTarget<int>(
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: hasUserValue ? () => _removeNumber(positionId) : null,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: candidateData.isNotEmpty 
                      ? SpaceTheme.starYellow 
                      : SpaceTheme.alienGreen,
                  width: candidateData.isNotEmpty ? 3 : 2,
                ),
                gradient: candidateData.isNotEmpty
                    ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                    : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
                boxShadow: candidateData.isNotEmpty
                    ? [
                        BoxShadow(
                          color: SpaceTheme.starYellow.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: hasUserValue
                    ? Text(
                        userSolution[positionId].toString(),
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                      )
                    : Icon(
                        Icons.help_outline,
                        color: SpaceTheme.alienGreen,
                        size: 32,
                      ),
              ),
            ),
          );
        },
        onWillAccept: (data) => true,
        onAcceptWithDetails: (details) {
          _placeNumber(details.data, positionId);
        },
      );
    } else {
      // Visible symbol
      cell = Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.alienGreen.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            puzzle!.symbolValues[symbol].toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
          ),
        ),
      );
    }
    
    if (isLastDropped) {
      cell = ScaleTransition(scale: _dropAnimation, child: cell);
    }
    
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell,
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getSymbolIcon(symbol),
              style: const TextStyle(fontSize: 24), // Made much bigger!
            ),
          ),
        ],
      ),
    );
  }

  String _getSymbolIcon(String symbol) {
    switch (symbol) {
      case 'nebula': return '🌌';
      case 'galaxy': return '🌠';
      case 'asteroid': return '☄️';
      case 'comet': return '💫';
      case 'rocket': return '🚀';
      case 'satellite': return '🛰️';
      case 'planet': return '🪐';
      default: return '⭐';
    }
  }

  Widget _buildNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.of(context)!.codebreakerSelectNumbers,
          style: SpaceTheme.bodyStyle,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          constraints: const BoxConstraints(maxWidth: 400),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: numberPool.length,
            itemBuilder: (context, index) {
              if (index >= numberPool.length) return Container();
              final number = numberPool[index];
              return Draggable<int>(
                data: number,
                feedback: _buildDraggableFeedback(number),
                childWhenDragging: Opacity(
                  opacity: 0.3, 
                  child: _buildNumberTile(number),
                ),
                child: _buildNumberTile(number),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumberTile(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.starYellow.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          number.toString(), 
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildDraggableFeedback(int number) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SpaceTheme.starGradient,
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow.withOpacity(0.8), 
              blurRadius: 20, 
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            number.toString(), 
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
          ),
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
                  Text(
                    S.of(context)!.codebreakerWinTitle, 
                    style: SpaceTheme.headlineStyle, 
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.codebreakerWinDesc(bonusScore),
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
                        child: Text(S.of(context)!.nextLevel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.toTheBridge),
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

// Data Models
class Equation {
  final List<String> leftSideSymbols;
  final List<String> operations;
  final int result;
  
  Equation({
    required this.leftSideSymbols,
    required this.operations,
    required this.result,
  });
}

class CodebreakerPuzzle {
  final Map<String, int> symbolValues;
  final List<Equation> equations;
  final Set<String> hiddenSymbols;
  final List<int> numberPool;
  final List<String> hiddenPositions;

  CodebreakerPuzzle({
    required this.symbolValues,
    required this.equations,
    required this.hiddenSymbols,
    required this.numberPool,
    required this.hiddenPositions,
  });

  static CodebreakerPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final generator = _PuzzleGenerator(
      grade, 
      level,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customMin: customMin,
      customMax: customMax,
    );
    
    return generator.generateComplexPuzzle();
  }

  bool validateSolution(Map<String, int> userSolution) {
    debugPrint("✅ [Puzzle] validateSolution: $userSolution");
    
    // Build complete symbol values including user answers
    final completeValues = Map<String, int>.from(symbolValues);
    
    // Map position-based solutions back to symbol values
    for (final entry in userSolution.entries) {
      final positionId = entry.key;
      final value = entry.value;
      final symbol = getSymbolFromPosition(positionId);
      completeValues[symbol] = value;
    }
    
    debugPrint("✅ [Puzzle] Complete values: $completeValues");
    
    // Validate all equations
    for (int i = 0; i < equations.length; i++) {
      final equation = equations[i];
      if (!_validateEquation(equation, completeValues)) {
        debugPrint("❌ [Puzzle] Equation $i failed validation");
        return false;
      }
    }
    
    debugPrint("✅ [Puzzle] All equations valid");
    return true;
  }

  String _getSymbolFromPosition(String positionId) {
    // Extract equation and symbol index from position ID
    final parts = positionId.split('_');
    final eqIndex = int.parse(parts[0].substring(2)); // Remove 'eq' prefix
    final symIndex = int.parse(parts[1].substring(3)); // Remove 'sym' prefix
    
    return equations[eqIndex].leftSideSymbols[symIndex];
  }

  // Public method to access symbol from position
  String getSymbolFromPosition(String positionId) {
    return _getSymbolFromPosition(positionId);
  }

  bool _validateEquation(Equation equation, Map<String, int> values) {
    int leftSide = values[equation.leftSideSymbols[0]]!;
    
    for (int i = 0; i < equation.operations.length; i++) {
      final operation = equation.operations[i];
      final rightOperand = values[equation.leftSideSymbols[i + 1]]!;
      
      switch (operation) {
        case '+':
          leftSide += rightOperand;
          break;
        case '-':
          leftSide = (leftSide - rightOperand).abs();
          break;
        case '*':
          leftSide *= rightOperand;
          break;
        case '/':
          if (rightOperand != 0) {
            leftSide ~/= rightOperand;
          }
          break;
      }
    }
    
    return leftSide == equation.result;
  }
}

// Puzzle Generator - FIXED VERSION
class _PuzzleGenerator {
  final int grade;
  final int level;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customMin;
  final int customMax;
  
  final List<String> availableSymbols = [
    'nebula', 'galaxy', 'asteroid', 'comet', 
    'rocket', 'satellite', 'planet'
  ];
  
  _PuzzleGenerator(
    this.grade, 
    this.level, {
    required this.useCustomSettings,
    required this.customOps,
    required this.customMin,
    required this.customMax,
  });

  CodebreakerPuzzle generateComplexPuzzle() {
    debugPrint("🎲 [Generator] Starting complex puzzle generation for grade $grade, level $level");
    
    int attempts = 0;
    while (attempts < 50) {
      try {
        final puzzleData = _generatePuzzleSystem();
        
        if (_validatePuzzleSolvability(puzzleData['equations'], puzzleData['symbolValues'])) {
          debugPrint("🎲 [Generator] Successfully generated puzzle");
          return CodebreakerPuzzle(
            symbolValues: puzzleData['symbolValues'],
            equations: puzzleData['equations'],
            hiddenSymbols: puzzleData['hiddenSymbols'],
            numberPool: puzzleData['numberPool'],
            hiddenPositions: puzzleData['hiddenPositions'],
          );
        }
        
        attempts++;
      } catch (e) {
        debugPrint("❌ [Generator] Attempt $attempts failed: $e");
        attempts++;
      }
    }
    
    throw Exception('Failed to generate valid puzzle after 50 attempts');
  }

  Map<String, dynamic> _generatePuzzleSystem() {
    final symbolCount = _getSymbolCount();
    final selectedSymbols = availableSymbols.take(symbolCount).toList();
    final symbolValues = _generateSymbolValues(selectedSymbols);
    
    debugPrint("🎲 [Generator] Using $symbolCount symbols: $selectedSymbols");
    debugPrint("🎲 [Generator] Symbol values: $symbolValues");
    
    // Generate interconnected equation system
    final equations = _generateInterconnectedEquations(selectedSymbols, symbolValues);
    final hiddenSymbols = _selectStrategicHiddenSymbols(selectedSymbols, equations);
    final hiddenPositions = _buildHiddenPositions(equations, hiddenSymbols);
    final numberPool = _generateNumberPool(symbolValues, hiddenSymbols);
    
    debugPrint("🎲 [Generator] Generated ${equations.length} equations");
    debugPrint("🎲 [Generator] Hidden symbols: $hiddenSymbols");
    debugPrint("🎲 [Generator] Number pool: $numberPool");
    
    return {
      'symbolValues': symbolValues,
      'equations': equations,
      'hiddenSymbols': hiddenSymbols,
      'hiddenPositions': hiddenPositions,
      'numberPool': numberPool,
    };
  }

  List<Equation> _generateInterconnectedEquations(List<String> symbols, Map<String, int> values) {
    final equations = <Equation>[];
    final operations = _getAvailableOperations();
    
    if (symbols.length == 2) {
      // 2-symbol system: X + X = result, Y + X = result
      final x = symbols[0];
      final y = symbols[1];
      
      equations.add(Equation(
        leftSideSymbols: [x, x],
        operations: ['+'],
        result: values[x]! + values[x]!,
      ));
      
      equations.add(Equation(
        leftSideSymbols: [y, x],
        operations: ['+'],
        result: values[y]! + values[x]!,
      ));
      
    } else if (symbols.length == 3) {
      // 3-symbol system: X + Y = result, Z + Z = result, X + Z = result
      final x = symbols[0];
      final y = symbols[1]; 
      final z = symbols[2];
      
      equations.add(Equation(
        leftSideSymbols: [x, y],
        operations: ['+'],
        result: values[x]! + values[y]!,
      ));
      
      equations.add(Equation(
        leftSideSymbols: [z, z],
        operations: ['+'],
        result: values[z]! + values[z]!,
      ));
      
      // Third equation uses available operations
      final op = operations[math.Random().nextInt(operations.length)];
      equations.add(Equation(
        leftSideSymbols: [x, z],
        operations: [op],
        result: _calculateResult([x, z], op, values),
      ));
      
    } else if (symbols.length >= 4) {
      // 4+ symbol system: More complex patterns
      final x = symbols[0];
      final y = symbols[1];
      final z = symbols[2];
      final w = symbols[3];
      
      // Pattern: X + Y = result
      equations.add(Equation(
        leftSideSymbols: [x, y],
        operations: ['+'],
        result: values[x]! + values[y]!,
      ));
      
      // Pattern: Z + Z + Z = result
      equations.add(Equation(
        leftSideSymbols: [z, z, z],
        operations: ['+', '+'],
        result: values[z]! * 3,
      ));
      
      // Pattern: W + X = result
      final op1 = operations[math.Random().nextInt(operations.length)];
      equations.add(Equation(
        leftSideSymbols: [w, x],
        operations: [op1],
        result: _calculateResult([w, x], op1, values),
      ));
      
      // Pattern: Y + Z = result
      final op2 = operations[math.Random().nextInt(operations.length)];
      equations.add(Equation(
        leftSideSymbols: [y, z],
        operations: [op2],
        result: _calculateResult([y, z], op2, values),
      ));
    }
    
    return equations;
  }

  Set<String> _selectStrategicHiddenSymbols(List<String> symbols, List<Equation> equations) {
    // Hide symbols strategically to create a solvable puzzle
    final hiddenCount = _getHiddenSymbolCount(symbols.length);
    final toHide = symbols.take(hiddenCount).toSet();
    
    debugPrint("🎲 [Generator] Hiding $hiddenCount out of ${symbols.length} symbols: $toHide");
    debugPrint("🎲 [Generator] Visible symbols: ${symbols.where((s) => !toHide.contains(s))}");
    
    return toHide;
  }

  int _getHiddenSymbolCount(int totalSymbols) {
    // Always leave at least one symbol visible as anchor
    if (totalSymbols == 2) return 1; // Hide 1, show 1
    if (totalSymbols == 3) return 2; // Hide 2, show 1  
    if (totalSymbols >= 4) return totalSymbols - 1; // Hide all but 1
    return totalSymbols - 1;
  }

  int _getSymbolCount() {
    if (grade <= 2) return 2;
    if (grade <= 4) return 3;
    return math.min(4, availableSymbols.length);
  }

  Map<String, int> _generateSymbolValues(List<String> symbols) {
    final values = <String, int>{};
    final maxValue = _getMaxValue();
    final usedValues = <int>{};
    
    for (final symbol in symbols) {
      int value;
      int attempts = 0;
      do {
        value = 1 + math.Random().nextInt(maxValue);
        attempts++;
      } while (usedValues.contains(value) && attempts < 20);
      
      values[symbol] = value;
      usedValues.add(value);
    }
    
    return values;
  }

  int _getMaxValue() {
    if (useCustomSettings) return customMax;
    
    switch (grade) {
      case 1: return 10;
      case 2: return 15;
      case 3: return 20;
      case 4: return 25;
      case 5: return 30;
      default: return 35;
    }
  }

  List<String> _getAvailableOperations() {
    if (useCustomSettings && customOps.isNotEmpty) {
      return customOps.map((op) {
        switch(op) {
          case 'addition': return '+';
          case 'subtraction': return '-';
          case 'multiplication': return '*';
          case 'division': return '/';
          default: return '+';
        }
      }).toList();
    }
    
    // Grade-based operation selection
    if (grade <= 2) {
      return ['+'];
    } else if (grade <= 3) {
      return ['+', '-'];
    } else if (grade <= 4) {
      return ['+', '-', '*'];
    } else {
      return ['+', '-', '*', '/'];
    }
  }

  int _calculateResult(List<String> symbols, String operation, Map<String, int> values) {
    final leftValue = values[symbols[0]]!;
    final rightValue = values[symbols[1]]!;
    
    switch (operation) {
      case '+':
        return leftValue + rightValue;
      case '-':
        return (leftValue - rightValue).abs();
      case '*':
        return leftValue * rightValue;
      case '/':
        // Ensure clean division
        if (rightValue != 0 && leftValue % rightValue == 0) {
          return leftValue ~/ rightValue;
        } else {
          // For division, adjust to ensure clean result
          final adjustedLeft = rightValue * (leftValue ~/ math.max(1, rightValue) + 1);
          values[symbols[0]] = adjustedLeft;
          return adjustedLeft ~/ rightValue;
        }
      default:
        return leftValue + rightValue;
    }
  }

  List<String> _buildHiddenPositions(List<Equation> equations, Set<String> hiddenSymbols) {
    final positions = <String>[];
    
    for (int eqIndex = 0; eqIndex < equations.length; eqIndex++) {
      final equation = equations[eqIndex];
      for (int symIndex = 0; symIndex < equation.leftSideSymbols.length; symIndex++) {
        final symbol = equation.leftSideSymbols[symIndex];
        if (hiddenSymbols.contains(symbol)) {
          positions.add('eq${eqIndex}_sym${symIndex}');
        }
      }
    }
    
    return positions;
  }

  bool _validatePuzzleSolvability(List<Equation> equations, Map<String, int> values) {
    // Basic validation - ensure we have valid equations
    return equations.isNotEmpty && values.isNotEmpty;
  }

  List<int> _generateNumberPool(Map<String, int> symbolValues, Set<String> hiddenSymbols) {
    final correctNumbers = hiddenSymbols.map((s) => symbolValues[s]!).toList();
    final decoys = <int>{};
    final maxValue = _getMaxValue();
    
    // Add strategic decoys (numbers that could plausibly fit)
    for (final correct in correctNumbers) {
      decoys.addAll([
        math.max(1, correct - 3),
        math.max(1, correct - 2),
        math.max(1, correct - 1),
        correct + 1,
        correct + 2,
        correct + 3,
      ]);
    }
    
    // Add some random numbers
    while (decoys.length < correctNumbers.length + 6) {
      decoys.add(1 + math.Random().nextInt(maxValue));
    }
    
    // Remove correct numbers from decoys to avoid duplicates
    decoys.removeWhere((d) => correctNumbers.contains(d));
    
    final pool = [...correctNumbers, ...decoys.take(6)];
    pool.shuffle();
    
    return pool;
  }
}