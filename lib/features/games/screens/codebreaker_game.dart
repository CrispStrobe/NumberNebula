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

  bool _isDragging = false; // we must avoid a classic Flutter drag-and-drop issue where the widget tree rebuilds during dragging, causing the DragTargets to lose their hover state.
  int? _draggingNumber; // also to prevent unnecessary rebuilds during dragging

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
    
    debugPrint("🚀 [CODEBREAKER UI] Animation controllers initialized, starting puzzle generation");
    _generatePuzzle();
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
    _debugCurrentState(); // debug details
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
        content: Text(S.of(context)?.codebreakerError ?? "Incorrect solution! Try again."),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

    @override
    Widget build(BuildContext context) {
    if (puzzle == null || _isGenerating) {
        return const Scaffold(
        body: Center(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Receiving Transmission...", style: SpaceTheme.bodyStyle),
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
                title: "Codebreaker",
                level: widget.level, 
                onBack: () => Navigator.of(context).pop()
                ),
                const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                    "Drag numbers to solve the symbol equations!",
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
    final equationHeight = availableHeight * 0.6; // 60% for equations
    final numberPadHeight = availableHeight * 0.4; // 40% for numbers
    
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

  Widget _buildTallLayout() {
    return LayoutBuilder(
        builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final equationHeight = screenHeight * 0.6; // 60% for equations
        final numberPadHeight = screenHeight * 0.35; // 35% for number pad
        
        return Column(
            children: [
            SizedBox(
                height: equationHeight,
                child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildEquationDisplay(),
                ),
                ),
            ),
            SizedBox(
                height: numberPadHeight,
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildNumberPad(),
                ),
            ),
            ],
        );
        },
    );
    }

  Widget _buildEquationDisplay() {
    return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
        return Container(
            padding: const EdgeInsets.all(16), // Reduced from 20
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
            mainAxisSize: MainAxisSize.min, // Add this
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // More padding for easier drops
        decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better spacing
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
    const cellSize = 50.0;
    const fontSize = 16.0;
    
    if (term is int) {
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
            child: Center(
                child: Text(
                term.toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
                ),
            ),
            ),
            const SizedBox(height: 1),
            const Text("🔢", style: TextStyle(fontSize: 14)),
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
        // Show filled value
        cellContent = Container(
            width: cellSize, 
            height: cellSize,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.deepSpace]),
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
            ),
            child: Center(
            child: Text(
                userSolution[positionId].toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
            ),
            ),
        );
        } else if (!isHidden) {
        // Visible symbol value
        final value = puzzle!.knownSymbolValues[symbol]!;
        cellContent = Container(
            width: cellSize, 
            height: cellSize,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace]),
            border: Border.all(color: SpaceTheme.alienGreen, width: 2),
            ),
            child: Center(
            child: Text(
                value.toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: fontSize),
            ),
            ),
        );
        } else {
        // Empty drop target
        cellContent = Container(
            width: cellSize, 
            height: cellSize,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
            border: Border.all(color: SpaceTheme.alienGreen, width: 2),
            ),
            child: const Center(
            child: Icon(Icons.help_outline, color: SpaceTheme.alienGreen, size: 20),
            ),
        );
        }
        
        if (isLastDropped) {
        cellContent = ScaleTransition(scale: _dropAnimation, child: cellContent);
        }
        
        Widget fullWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            cellContent,
            const SizedBox(height: 2),
            Text(_getSymbolIcon(symbol), style: const TextStyle(fontSize: 16)),
        ],
        );
        
        // Wrap the ENTIRE column (cell + emoji) in DragTarget if it should accept drops
        if (shouldAcceptDrops) {
            return Container(
                width: cellSize + 40, // Much larger hit area
                height: cellSize + 40,
                child: DragTarget<int>(
                builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    
                    return Container(
                    padding: const EdgeInsets.all(8), // Extra padding for hit area
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Container(
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
                            ),
                            child: GestureDetector(
                            onTap: hasUserValue ? () => _removeNumber(positionId) : null,
                            child: const Center(
                                child: Icon(Icons.help_outline, color: SpaceTheme.alienGreen, size: 20),
                            ),
                            ),
                        ),
                        const SizedBox(height: 1),
                        Text(_getSymbolIcon(symbol), style: const TextStyle(fontSize: 16)),
                        ],
                    ),
                    );
                },
                onWillAcceptWithDetails: (details) {
                    return true; // Always accept if we're building this DragTarget
                },
                onAcceptWithDetails: (details) {
                    debugPrint("🎯 [DROPPED] ✅ ${details.data} → $positionId");
                    _placeNumber(details.data, positionId);
                },
                ),
            );
            }
        
        return fullWidget;
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
            const Text("Select Numbers", style: SpaceTheme.bodyStyle),
            const SizedBox(height: 8),
            Expanded(
                child: Container(
                padding: const EdgeInsets.all(12),
                decoration: SpaceTheme.cardDecoration.copyWith(
                    border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
                ),
                child: GridView.builder(
                    shrinkWrap: true,
                    physics: _isDragging ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(), // Prevent scrolling during drag
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

  // method to help debug which positions should accept drops
    void _debugPrintDragTargets() {
    debugPrint("🎯 [DEBUG] === CURRENT DRAG TARGET STATUS ===");
    for (int i = 0; i < puzzle!.equations.length; i++) {
        final eq = puzzle!.equations[i];
        for (int j = 0; j < 3; j++) {
        String posId = '';
        String symbol = '';
        bool isHidden = false;
        bool hasValue = false;
        
        switch (j) {
            case 0:
            if (eq.term1 is String) {
                posId = 'eq${i}_term1';
                symbol = eq.term1 as String;
                isHidden = puzzle!.hiddenSymbols.contains(symbol);
                hasValue = userSolution.containsKey(posId);
            }
            break;
            case 1:
            if (eq.term2 is String) {
                posId = 'eq${i}_term2';
                symbol = eq.term2 as String;
                isHidden = puzzle!.hiddenSymbols.contains(symbol);
                hasValue = userSolution.containsKey(posId);
            }
            break;
            case 2:
            if (eq.result is String) {
                posId = 'eq${i}_result';
                symbol = eq.result as String;
                isHidden = puzzle!.hiddenSymbols.contains(symbol);
                hasValue = userSolution.containsKey(posId);
            }
            break;
        }
        
        if (posId.isNotEmpty) {
            debugPrint("🎯 [DEBUG] $posId: symbol=$symbol, hidden=$isHidden, hasValue=$hasValue, shouldAcceptDrops=${isHidden && !hasValue}");
        }
        }
    }
    debugPrint("🎯 [DEBUG] === END DRAG TARGET STATUS ===");
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
                  const Text("Puzzle Solved!", style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text("You earned a bonus of $bonusScore points!", style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: const Text("Next Puzzle"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: SpaceTheme.primaryButtonStyle,
                        child: const Text("Main Menu"),
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
// ADVANCED PUZZLE GENERATION SYSTEM (Based on Python version)
//##############################################################################

/// Represents a single equation with term1 op term2 = result
/// Each term can be either a String (symbol) or int (number)
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

  /// Returns all symbols (String values) present in this equation
  List<String> getSymbols() {
    final symbols = <String>[];
    if (term1 is String) symbols.add(term1 as String);
    if (term2 is String) symbols.add(term2 as String);
    if (result is String) symbols.add(result as String);
    return symbols.toSet().toList(); // Remove duplicates
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

/// Advanced puzzle generator that creates sophisticated symbol-based math puzzles
class AdvancedPuzzleGenerator {
  final int difficulty;
  final bool verbose;
  final math.Random _random = math.Random();
  
  late Map<String, dynamic> params;
  List<String> symbols = [];
  Map<String, int> solution = {};
  final PuzzleSolver solver = PuzzleSolver(verbose: true);

  // Pool of available space-themed symbols
  static const List<String> availableSymbols = [
    'nebula', 'star', 'galaxy', 'planet', 'rocket', 'satellite', 'comet', 
    'asteroid', 'sun', 'moon', 'supernova', 'blackhole', 'spaceship', 'alien', 'meteor'
  ];

  AdvancedPuzzleGenerator({required this.difficulty, this.verbose = false}) {
    params = _getParams();
    if (verbose) debugPrint("🏗️ [GENERATOR] Initialized with difficulty $difficulty, params: $params");
  }

  Map<String, dynamic> _getParams() {
    switch (difficulty) {
        case 1:
        return {
            'numSymbols': 4,        // Need at least 4 symbols
            'valueRange': [2, 12], 
            'operators': ['+', '-'],
            'numEquations': 4       // Need 4 equations for 4 symbols
        };
        case 2:
        return {
            'numSymbols': 5,
            'valueRange': [3, 20],
            'operators': ['+', '-', '*'],
            'numEquations': 5
        };
        default:
        return {
            'numSymbols': 5,
            'valueRange': [2, 25],
            'operators': ['+', '-', '*'],
            'numEquations': 5
        };
    }
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
    
    // Build reverse lookup map
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
            
            // Skip invalid operations
            if ((op == '-' && v1 == v2) || (op == '/' && v1 == v2)) continue;
            if (op == '-' && v1 < v2) continue;
            if (op == '/' && (v2 == 0 || v1 % v2 != 0)) continue;
            
            final resVal = _calculateInt(v1, v2, op);
            // bias towards symbol=symbol results
            // This ensures more symbol-to-symbol relationships
            final result = valueToSymbol[resVal] ?? (resVal <= params['valueRange'][1] ? resVal : null);
            if (result == null) continue; // Skip if result is too large

            
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
    
    // Template 2: number op number = symbol (CRITICAL for interesting puzzles!)
    for (final sRes in symbols) {
    final vRes = solution[sRes]!;
    
    for (int i = 0; i < 8; i++) { // More attempts for variety
        final op = operators[_random.nextInt(operators.length)];
        int? n1, n2;
        
        switch (op) {
        case '+':
            if (vRes <= 2) continue; // Need at least 3 to split meaningfully
            final maxSplit = vRes - 1;
            n1 = _random.nextInt(maxSplit) + 1;
            n2 = vRes - n1;
            break;
        case '-':
            final valueRange = params['valueRange'] as List<int>;
            final maxVal = valueRange[1];
            final rangeSize = maxVal - vRes;
            if (rangeSize <= 0) continue; // Skip if no room for subtraction
            n1 = _random.nextInt(rangeSize) + vRes + 1;
            n2 = n1 - vRes;
            break;
        case '*':
            // Find factors of vRes
            final factors = <int>[];
            for (int f = 2; f <= math.sqrt(vRes).floor(); f++) {
            if (vRes % f == 0) factors.add(f);
            }
            if (factors.isEmpty) continue; // Skip if no factors found
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
    
    // Find entry points (equations with 1 or fewer symbols)
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
    
    // Build the connected graph
    final numSymbols = params['numSymbols'] as int;
    while (knownSymbols.length < numSymbols) {
      PuzzleEquation? nextLink;
      
      for (final eq in pool) {
        final eqSyms = eq.getSymbols().toSet();
        final newSymbols = eqSyms.difference(knownSymbols);
        final connectingSymbols = eqSyms.intersection(knownSymbols);
        
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
    
    // Add filler equations if needed
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
  final Map<String, int> knownSymbolValues; // Visible symbol values
  final List<PuzzleEquation> equations;
  final Set<String> hiddenSymbols;
  final List<int> numberPool;
  final List<String> hiddenPositions;
  final Map<String, int> _fullSolution; // Complete solution for validation

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
    
    // Create difficulty based on grade
    final difficulty = math.min(grade, 3);
    debugPrint("🎯 [PUZZLE FACTORY] Mapped grade $grade to difficulty $difficulty");
    
    final generator = AdvancedPuzzleGenerator(difficulty: difficulty, verbose: true);
    final puzzleEquations = generator.generate();
    
    debugPrint("🎯 [PUZZLE FACTORY] Generated ${puzzleEquations.length} equations");
    
    // Determine which symbols to hide (more challenging = fewer visible)
    final allSymbols = generator.symbols;
    final visibleCount = 1; // Always show only 1 symbol, regardless of difficulty

    allSymbols.shuffle();
    final visibleSymbols = allSymbols.take(visibleCount).toList();

    final hiddenSymbols = allSymbols.toSet().difference(visibleSymbols.toSet());
    
    debugPrint("🎯 [PUZZLE FACTORY] Visible symbols: $visibleSymbols");
    debugPrint("🎯 [PUZZLE FACTORY] Hidden symbols: $hiddenSymbols");
    
    // Create known symbol values map
    final knownValues = <String, int>{};
    for (final symbol in visibleSymbols) {
      knownValues[symbol] = generator.solution[symbol]!;
    }
    
    // Generate number pool
    final correctNumbers = hiddenSymbols.map((s) => generator.solution[s]!).toSet();
    final decoys = <int>{};
    final maxVal = (generator.params['valueRange'] as List<int>)[1];

    debugPrint("🎯 [PUZZLE FACTORY] Correct numbers needed: ${correctNumbers.join(', ')}");

    // Add numbers close to correct ones as decoys
    for (final correct in correctNumbers) {
    for (int i = 1; i <= 2; i++) {
        if (correct - i > 0) decoys.add(correct - i);
        if (correct + i <= maxVal) decoys.add(correct + i);
    }
    }
    decoys.removeAll(correctNumbers); // Remove any decoys that match correct numbers

    // Add random decoys if needed to reach total of 8 numbers
    final random = math.Random();
    final targetPoolSize = 8;
    final requiredDecoys = targetPoolSize - correctNumbers.length;

    while (decoys.length < requiredDecoys) {
    final randomDecoy = random.nextInt(maxVal) + 1;
    if (!correctNumbers.contains(randomDecoy)) {
        decoys.add(randomDecoy);
    }
    }

    // CRITICAL FIX: Always include ALL correct numbers
    final numberPool = <int>[];
    numberPool.addAll(correctNumbers); // Add ALL correct numbers first
    numberPool.addAll(decoys.take(targetPoolSize - correctNumbers.length)); // Then add decoys to fill

    numberPool.shuffle();
    final finalPool = numberPool;

    debugPrint("🎯 [PUZZLE FACTORY] Final number pool: ${finalPool.join(', ')}");
    debugPrint("🎯 [PUZZLE FACTORY] Verifying all correct numbers included: ${correctNumbers.every((n) => finalPool.contains(n))}");
    
    // Build hidden positions list
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
    
    // Check if all values match
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
    final eqIndex = int.parse(parts[0].substring(2)); // Remove 'eq' prefix
    final termType = parts[1]; // 'term1', 'term2', or 'result'
    
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