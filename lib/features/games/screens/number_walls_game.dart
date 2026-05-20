// ignore_for_file: unused_element, unused_field
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../constants/app_constants.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';

// DEVELOPMENT TWEAKING CONSTANTS
const bool kTweakProblems = false;  // Set to true to override normal generation
const String kTweakOps = 'subtraction'; // 'addition', 'subtraction', 'multiplication', 'division'
const int kTweakRangeMin = 2;
const int kTweakRangeMax = 8;
const int kTweakWallHeight = 4; // Override wall height when tweaking

enum WallOperation { addition, subtraction, multiplication, division }

class NumberWallsGame extends StatefulWidget {
  final int grade;
  final int level;

  const NumberWallsGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<NumberWallsGame> createState() => _NumberWallsGameState();
}

class _NumberWallsGameState extends State<NumberWallsGame>
    with TickerProviderStateMixin {
  final GlobalKey _dragTargetKey = GlobalKey();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _warpController;
  late AnimationController _operationController;
  late Animation<double> _operationAnimation;

  NumberWallPuzzle? currentPuzzle;
  List<int?> userAnswers = [];
  List<int> numberPool = [];
  
  bool _isGenerating = true;
  bool _isWarping = false;
  int _lastPlacedCellIndex = -1;
  bool _isDraggingOver = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _fadeTimer;
  bool _shouldShowOperationHint = true;

  @override
  void initState() {
    super.initState();
    debugPrint("🧱 NumberWallsGame.initState() - Grade ${widget.grade}, Level ${widget.level}");
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000), vsync: this
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    
    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);
    
    _warpController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this
    );

    _operationController = AnimationController(
      duration: const Duration(milliseconds: 1000), vsync: this
    )..repeat(reverse: true);
    _operationAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _operationController, curve: Curves.easeInOut));
    
    // New fade controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000), vsync: this
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    _generatePuzzle();
    
    // Start the fade timer
    _startFadeTimer();
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _shouldShowOperationHint) {
        setState(() {
          _shouldShowOperationHint = false;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _warpController.dispose();
    _operationController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("🧱 _generatePuzzle() - Starting puzzle generation");
    
    setState(() {
      _isGenerating = true;
      _isWarping = false;
      _shouldShowOperationHint = true;
      _warpController.reset();
      _successController.reset();
      _fadeController.reset();
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

      final puzzle = await compute(NumberWallPuzzle.generate, puzzleArgs);
      
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          userAnswers = List.generate(currentPuzzle!.hiddenCells.length, (_) => null);
          numberPool = List.from(currentPuzzle!.numberPool);
          _isGenerating = false;
        });
        debugPrint("🧱 Puzzle generated: ${currentPuzzle!.operation.name} wall, height ${currentPuzzle!.wallHeight}");
        _startFadeTimer(); // Restart the timer for new puzzle
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error in _generatePuzzle: $e");
      debugPrint("❌ StackTrace: $stackTrace");
    }
  }
  
  void _placeNumber(int number, int hiddenCellIndex) {
    final answerIndex = currentPuzzle!.getAnswerIndexForCell(hiddenCellIndex);
    if (answerIndex == -1 || userAnswers[answerIndex] != null) {
      return;
    }

    setState(() {
      userAnswers[answerIndex] = number;
      numberPool.remove(number);
      _lastPlacedCellIndex = hiddenCellIndex;
      _dropController.forward(from: 0.0);
    });
    
    _checkIfComplete();
  }

  void _removeNumber(int answerIndex) {
    setState(() {
      final number = userAnswers[answerIndex];
      if (number != null) {
        userAnswers[answerIndex] = null;
        numberPool.add(number);
        numberPool.sort();
      }
    });
  }

  void _checkIfComplete() {
    if (userAnswers.every((answer) => answer != null)) {
      final isValid = currentPuzzle!.validateSolution(userAnswers.cast<int>());
      
      // 1. Get the list of problems the user was tested on in in this puzzle.
      final List<MathProblem> attemptedProblems = _getSolvedProblems();
      
      // 2. Report the outcome to the central GameProvider.
      if (isValid) {
        // On SUCCESS, calculate the score and report it.
        int baseScore = 120 * widget.grade;
        int bonusScore = (baseScore * (currentPuzzle!.wallHeight / 3.0)).round();
        int operationBonus = _getOperationBonus(currentPuzzle!.operation);
        int totalScore = baseScore + bonusScore + operationBonus;

        context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'number_walls',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: attemptedProblems,
    ));
        
        // 3. Trigger the success UI/animation.
        _handleSuccess(totalScore);

      } else {
        // On FAILURE, report a loss with zero score.
        context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'number_walls',
      difficulty: widget.level,
      mathProblems: attemptedProblems,
    ));

        // 3. Trigger the failure UI.
        _handleIncorrect();
      }
    }
  }

  List<MathProblem> _getSolvedProblems() {
    debugPrint("🧱 Gathering all solved problems for the completed wall...");
    // REMOVED: Direct access to sriService.
    final puzzle = currentPuzzle!;
    final List<MathProblem> problemsToLog = [];
    
    // The rest of the logic for finding the problems is excellent and remains the same.
    final completeWall = puzzle.fullSolution;

    for (int row = 0; row < puzzle.wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;

      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentIndex = currentRowStart + col;

        if (puzzle.hiddenCells.contains(parentIndex)) {
          final leftChildIndex = nextRowStart + col;
          final rightChildIndex = nextRowStart + col + 1;

          if (rightChildIndex < completeWall.length) {
            final leftValue = completeWall[leftChildIndex];
            final rightValue = completeWall[rightChildIndex];
            
            MathProblem? problem;
            switch (puzzle.operation) {
              case WallOperation.addition:
                problem = MathProblem.addition(leftValue, rightValue);
                break;
              case WallOperation.subtraction:
                problem = MathProblem.subtraction(math.max(leftValue, rightValue), math.min(leftValue, rightValue));
                break;
              case WallOperation.multiplication:
                problem = MathProblem.multiplication(leftValue, rightValue);
                break;
              case WallOperation.division:
                if (leftValue > rightValue && rightValue != 0 && leftValue % rightValue == 0) {
                  problem = MathProblem.division(leftValue, rightValue);
                } else if (rightValue > leftValue && leftValue != 0 && rightValue % leftValue == 0) {
                  problem = MathProblem.division(rightValue, leftValue);
                }
                break;
            }
            
            if (problem != null) {
              // CHANGED: Instead of calling sriService, add to our list.
              problemsToLog.add(problem);
              debugPrint("🧱 Found problem to log -> ${problem.expression}");
            }
          }
        }
      }
    }
    // ADDED: Return the collected list of problems.
    return problemsToLog;
  }

  MathOperation _convertWallOperationToMathOperation(WallOperation wallOp) {
    switch (wallOp) {
      case WallOperation.addition: return MathOperation.addition;
      case WallOperation.subtraction: return MathOperation.subtraction;
      case WallOperation.multiplication: return MathOperation.multiplication;
      case WallOperation.division: return MathOperation.division;
    }
  }

  void _handleSuccess(int totalScoreGained) {
    HapticFeedback.lightImpact();
    setState(() => _isWarping = true);
    _warpController.forward();

    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _warpController.removeStatusListener(listener);
        
        // REMOVED: All scoring logic and provider calls. They are now in _checkIfComplete.
        
        _successController.forward(from: 0.0);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            // CHANGED: We pass the score bonus to the dialog for display.
            builder: (context) => _buildSuccessDialog(totalScoreGained - (120 * widget.grade)),
          );
        }
      }
    }

    _warpController.addStatusListener(listener);
  }

  int _getOperationBonus(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return 0;
      case WallOperation.subtraction: return 25;
      case WallOperation.multiplication: return 50;
      case WallOperation.division: return 75;
    }
  }

  void _handleIncorrect() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.numberWallsFail)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPuzzle == null || _isGenerating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildCompactHeader(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // MODIFIED: Lowered breakpoint from 650 to 600
                        bool isWide = constraints.maxWidth > 600;
                        return isWide ? _buildWideLayout() : _buildCompactTallLayout();
                      },
                    ),
                  ),
                ],
              ),
              // Floating operation indicator on the right
              if (_shouldShowOperationHint || _fadeController.status == AnimationStatus.reverse)
                _buildFloatingOperationIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingOperationIndicator() {
    return Positioned(
      // MODIFIED: Changed from 80 to 60 to move it up
      top: 60,
      right: 16,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _shouldShowOperationHint ? 1.0 : _fadeAnimation.value,
            child: Container(
              // MODIFIED: Replaced fixed width with a responsive constraint
              // width: MediaQuery.of(context).size.width * 0.75, // <--- OLD
              constraints: BoxConstraints(
                maxWidth: math.min(MediaQuery.of(context).size.width * 0.6, 280), // <--- NEW
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: _getOperationGradient(currentPuzzle!.operation),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getOperationColor(currentPuzzle!.operation), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _getOperationColor(currentPuzzle!.operation).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _operationAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _operationAnimation.value * 0.8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getOperationIcon(currentPuzzle!.operation), 
                            color: Colors.white, 
                            size: 16
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getOperationTitle(currentPuzzle!.operation),
                          style: SpaceTheme.titleStyle.copyWith(
                            color: Colors.white, 
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getOperationDescription(currentPuzzle!.operation),
                          style: SpaceTheme.bodyStyle.copyWith(
                            color: Colors.white70, 
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (kTweakProblems)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TWEAK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      // MODIFIED: Reduced vertical padding to save space
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context)!.numberWallsGameTitle,
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                // MODIFIED: Removed instruction text to save vertical space.
                // The floating hint provides the necessary context.
                // Text(
                //   S.of(context)!.numberWallsInstructions,
                //   style: SpaceTheme.bodyStyle.copyWith(fontSize: 11), 
                //   textAlign: TextAlign.center,
                //   maxLines: 2,
                //   overflow: TextOverflow.ellipsis,
                // ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpaceTheme.starYellow),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 16, color: SpaceTheme.starYellow),
                    const SizedBox(width: 4),
                    Text('${widget.level}', style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpaceTheme.alienGreen),
                ),
                child: Consumer<GameProvider>(
                  builder: (context, gameProvider, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: SpaceTheme.alienGreen),
                        const SizedBox(width: 4),
                        Text('${gameProvider.score}', style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBrick(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Center(
        child: Text(
          number.toString(), 
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 14)
        ),
      ),
    );
  }

  Widget _buildCompactOperationIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _getOperationGradient(currentPuzzle!.operation),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getOperationColor(currentPuzzle!.operation), width: 2),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _operationAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _operationAnimation.value * 0.8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getOperationIcon(currentPuzzle!.operation), 
                    color: Colors.white, 
                    size: 20
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getOperationTitle(currentPuzzle!.operation),
                  style: SpaceTheme.titleStyle.copyWith(
                    color: Colors.white, 
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getOperationDescription(currentPuzzle!.operation),
                  style: SpaceTheme.bodyStyle.copyWith(
                    color: Colors.white70, 
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (kTweakProblems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TWEAK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getOperationTitle(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return S.of(context)!.numberWallsAddition;
      case WallOperation.subtraction: return S.of(context)!.numberWallsSubtraction;
      case WallOperation.multiplication: return S.of(context)!.numberWallsMultiplication;
      case WallOperation.division: return S.of(context)!.numberWallsDivision;
    }
  }

  String _getOperationDescription(WallOperation operation) {
    // UPDATED description for subtraction
    switch (operation) {
      case WallOperation.addition: return S.of(context)!.numberWallsAddDesc;
      case WallOperation.subtraction: return S.of(context)!.numberWallsSubDesc;
      case WallOperation.multiplication: return S.of(context)!.numberWallsMultDesc;
      case WallOperation.division: return S.of(context)!.numberWallsDivDesc;
    }
  }

  IconData _getOperationIcon(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return Icons.add;
      case WallOperation.subtraction: return Icons.remove;
      case WallOperation.multiplication: return Icons.close; // Multiplication icon
      case WallOperation.division: return Icons.horizontal_rule; // Division icon
    }
  }

  Color _getOperationColor(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: return SpaceTheme.alienGreen;
      case WallOperation.subtraction: return SpaceTheme.cosmicPink;
      case WallOperation.multiplication: return SpaceTheme.starYellow;
      case WallOperation.division: return SpaceTheme.planetOrange;
    }
  }

  LinearGradient _getOperationGradient(WallOperation operation) {
    switch (operation) {
      case WallOperation.addition: 
        return const LinearGradient(colors: [SpaceTheme.alienGreen, Color(0xFF10343E)]);
      case WallOperation.subtraction: 
        return const LinearGradient(colors: [SpaceTheme.cosmicPink, Color(0xFF381B42)]);
      case WallOperation.multiplication: 
        return const LinearGradient(colors: [SpaceTheme.starYellow, Color(0xFF38311B)]);
      case WallOperation.division: 
        return const LinearGradient(colors: [SpaceTheme.planetOrange, Color(0xFF38251B)]);
    }
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _buildWallArea()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildCompactNumberPad()),
        ],
      ),
    );
  }

  Widget _buildCompactTallLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          // MODIFIED: Changed flex from 3 to 3
          Flexible(
            flex: 3,
            child: _buildWallArea(),
          ),
          // MODIFIED: Changed height from 12 to 8
          const SizedBox(height: 8),
          // MODIFIED: Changed flex from 2 to 1
          Flexible(
            flex: 1,
            child: _buildCompactNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildWallArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // MODIFIED: Removed the .clamp(300.0, 500.0) to allow scaling
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        
        return Center(
          child: DragTarget<int>(
            key: _dragTargetKey,
            builder: (context, candidateData, rejectedData) {
              return SizedBox(
                width: size,
                height: size,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_glowController, _warpController]),
                        builder: (context, child) {
                          return CustomPaint(
                            painter: NumberWallBackgroundPainter(
                              glowIntensity: _glowAnimation.value,
                              warpActivation: _warpController.value,
                              operation: currentPuzzle?.operation ?? WallOperation.addition,
                            ),
                          );
                        },
                      ),
                    ),
                    ..._buildWallCells(size),
                    ..._buildOperationSymbols(size),
                  ],
                ),
              );
            },
            onWillAcceptWithDetails: (data) {
              setState(() => _isDraggingOver = true);
              return true;
            },
            onLeave: (data) {
              setState(() => _isDraggingOver = false);
            },
            onAcceptWithDetails: (details) {
              setState(() => _isDraggingOver = false);
              
              final RenderBox? renderBox = _dragTargetKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox == null) return;
              
              final localDropPosition = renderBox.globalToLocal(details.offset);
              final droppedNumber = details.data;

              int? closestCellIndex = _findClosestEmptyCell(localDropPosition, size);

              if (closestCellIndex != null) {
                _placeNumber(droppedNumber, closestCellIndex);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context)!.numberWallsDropFar),
                    duration: const Duration(milliseconds: 1500),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
    
  int? _findClosestEmptyCell(Offset dropPosition, double containerSize) {
    if (currentPuzzle == null) return null;

    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.12;
    final double acceptanceRadius = cellSize * 1.2;

    double minDistance = double.infinity;
    int? closestEmptyCellIndex;
    
    for (int cellIndex in currentPuzzle!.hiddenCells) {
      final answerIndex = currentPuzzle!.getAnswerIndexForCell(cellIndex);
      final isEmpty = answerIndex != -1 && answerIndex < userAnswers.length && userAnswers[answerIndex] == null;
      if (isEmpty) {
        final cellCenter = cellPositions[cellIndex];
        final distance = (dropPosition - cellCenter).distance;
        if (distance < minDistance) {
          minDistance = distance;
          closestEmptyCellIndex = cellIndex;
        }
      }
    }

    if (closestEmptyCellIndex != null && minDistance <= acceptanceRadius) {
      return closestEmptyCellIndex;
    }
    return null;
  }

  List<Widget> _buildWallCells(double containerSize) {
    if (currentPuzzle == null) return [];
    
    List<Widget> cells = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final cellSize = containerSize * 0.12;
    
    for (int i = 0; i < currentPuzzle!.totalCells; i++) {
      int? value;
      bool isHidden = currentPuzzle!.hiddenCells.contains(i);
      
      if (isHidden) {
        final answerIndex = currentPuzzle!.getAnswerIndexForCell(i);
        if (answerIndex != -1 && answerIndex < userAnswers.length) {
          value = userAnswers[answerIndex];
        }
      } else {
        value = currentPuzzle!.visibleValues[i];
      }

      Widget cell = isHidden 
          ? _buildDroppableCell(value, currentPuzzle!.getAnswerIndexForCell(i), cellSize)
          : _buildFixedCell(value: value!, size: cellSize);
      
      if (i == _lastPlacedCellIndex) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      cells.add(Positioned(
        left: cellPositions[i].dx - cellSize / 2,
        top: cellPositions[i].dy - cellSize / 2,
        child: cell,
      ));
    }
    
    return cells;
  }

  List<Widget> _buildOperationSymbols(double containerSize) {
    if (currentPuzzle == null) return [];
    
    final gameProvider = context.read<GameProvider>();
    List<Widget> symbols = [];
    final cellPositions = currentPuzzle!.getCellPositions(containerSize);
    final operationColor = _getOperationColor(currentPuzzle!.operation);
    
    // Determine the symbol to display
    String symbolText;
    switch (currentPuzzle!.operation) {
      case WallOperation.addition: symbolText = '+'; break;
      case WallOperation.subtraction: symbolText = '-'; break;
      case WallOperation.multiplication: symbolText = gameProvider.multiplicationSymbol; break;
      case WallOperation.division: symbolText = gameProvider.divisionSymbol; break;
    }

    for (int row = 0; row < currentPuzzle!.wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentIndex = currentRowStart + col;
        final leftChildIndex = nextRowStart + col;
        final rightChildIndex = nextRowStart + col + 1;
        
        if (rightChildIndex < currentPuzzle!.totalCells) {
          final parentPos = cellPositions[parentIndex];
          final leftChildPos = cellPositions[leftChildIndex];
          final rightChildPos = cellPositions[rightChildIndex];
          
          // Calculate the midpoint between the two children
          final childrenMidX = (leftChildPos.dx + rightChildPos.dx) / 2;
          final childrenMidY = (leftChildPos.dy + rightChildPos.dy) / 2;
          
          // The operator should be between the parent and the children.
          // In a normal wall, parent is ABOVE the children.
          // In a subtraction wall, parent is BELOW the children (due to inversion).
          final symbolPos = Offset(
            (parentPos.dx + childrenMidX) / 2,
            (parentPos.dy + childrenMidY) / 2,
          );
          
          symbols.add(Positioned(
            left: symbolPos.dx - 14,
            top: symbolPos.dy - 14,
            child: AnimatedBuilder(
              animation: _operationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _operationAnimation.value * 0.9,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [operationColor, operationColor.withValues(alpha: 0.7)]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: operationColor.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)],
                    ),
                    child: Center(
                      child: Text(
                        symbolText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ));
        }
      }
    }
    
    return symbols;
  }
  
  Widget _buildDroppableCell(int? value, int answerIndex, double size) {
    return Semantics(
      button: true,
      label: value != null
          ? 'Placed value $value, tap to remove'
          : 'Empty brick, drop a number here',
      child: GestureDetector(
        onTap: value != null ? () => _removeNumber(answerIndex) : null,
        child: _buildBrickCell(
          value: value,
          isSelected: _isDraggingOver && value == null,
          isHidden: true,
          size: size,
        ),
      ),
    );
  }

  Widget _buildFixedCell({required int value, double size = 70}) {
    return _buildBrickCell(
      value: value,
      isSelected: false,
      isHidden: false,
      size: size,
    );
  }

  Widget _buildBrickCell({ required int? value, required bool isSelected, required bool isHidden, double size = 70 }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: _getCellGradient(isHidden, isSelected),
        border: Border.all(
          // MODIFIED: Changed SpaceTheme.alien to SpaceTheme.alienGreen
          color: isSelected ? SpaceTheme.starYellow : currentPuzzle != null ? _getOperationColor(currentPuzzle!.operation) : SpaceTheme.alienGreen.withValues(alpha: 0.5),
          width: isSelected ? 3 : 2,
        ),
        boxShadow: _getCellShadow(isSelected),
      ),
      child: Center(
        child: Text(
          isHidden ? (value?.toString() ?? '') : value.toString(),
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: size * 0.35,
            color: isHidden && value == null ? Colors.transparent : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCompactNumberPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.of(context)!.numberWallsBricks, 
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: SpaceTheme.cardDecoration.copyWith(
              border: Border.all(color: SpaceTheme.nebulaPurple, width: 2)
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: math.min(5, numberPool.length), 
                crossAxisSpacing: 6, 
                mainAxisSpacing: 6,
                // MODIFIED: Changed aspect ratio from 1.5 back to 1.0 (square)
                childAspectRatio: 1.0,
              ),
              itemCount: numberPool.length,
              itemBuilder: (context, index) {
                if (index >= numberPool.length) return Container();
                final number = numberPool[index];
                // Semantics goes on the visual child — see note in
                // word_sort_game / codebreaker_game.
                return Draggable<int>(
                  data: number,
                  feedback: _buildDraggableFeedback(number),
                  childWhenDragging: Opacity(opacity: 0.3, child: _buildCompactBrick(number)),
                  child: Semantics(
                    label: 'Number brick $number, drag to a wall slot',
                    button: true,
                    child: _buildCompactBrick(number),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrick(int number) {
    return Container(
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18))
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
          boxShadow: const [BoxShadow(color: SpaceTheme.starYellow, blurRadius: 20)],
        ),
        child: Center(
          child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22))
        ),
      ),
    );
  }
  
  LinearGradient _getCellGradient(bool isHidden, bool isSelected) {
    if (!isHidden && currentPuzzle != null) {
      final operationColor = _getOperationColor(currentPuzzle!.operation);
      return LinearGradient(colors: [operationColor, SpaceTheme.deepSpace]);
    }
    if (isSelected) {
      return const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange]);
    }
    return const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]);
  }

  List<BoxShadow> _getCellShadow(bool isSelected) {
    return [
      BoxShadow(
        // MODIFIED: Changed SpaceTheme.alien to SpaceTheme.alienGreen
        color: isSelected ? SpaceTheme.starYellow : currentPuzzle != null ? _getOperationColor(currentPuzzle!.operation) : SpaceTheme.alienGreen.withValues(alpha: 0.5),
        blurRadius: isSelected ? 20 : 10,
        spreadRadius: isSelected ? 3 : 1,
      ),
    ];
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
                  Text(S.of(context)!.numberWallsWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.numberWallsWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.numberWallsNextWall),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
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

// NumberWallPuzzle class with complete operation support
class NumberWallPuzzle {
  final int wallHeight;
  final int totalCells;
  final WallOperation operation;
  final Set<int> hiddenCells;
  final Map<int, int> visibleValues;
  final List<int> fullSolution;
  final List<int> numberPool;

  NumberWallPuzzle({
    required this.wallHeight,
    required this.operation,
    required this.hiddenCells,
    required this.visibleValues,
    required this.fullSolution,
    required this.numberPool,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  int getAnswerIndexForCell(int cellIndex) {
    if (!hiddenCells.contains(cellIndex)) return -1;
    final sortedHiddenCells = hiddenCells.toList()..sort();
    return sortedHiddenCells.indexOf(cellIndex);
  }

  // MODIFIED: This method now inverts the wall's vertical layout for subtraction puzzles.
  List<Offset> getCellPositions(double containerSize) {
    final positions = <Offset>[];
    final cellSpacing = containerSize / (wallHeight + 1);
    final isSubtraction = operation == WallOperation.subtraction;
    
    // Adjust vertical starting position to keep the wall centered
    final totalWallHeight = cellSpacing * (wallHeight - 1);
    final startY = (containerSize - totalWallHeight) / 2;
    
    for (int row = 0; row < wallHeight; row++) {
      final cellsInRow = row + 1;
      final startX = containerSize / 2 - (cellsInRow - 1) * cellSpacing / 2;
      
      double yPos;
      if (isSubtraction) {
        // For subtraction, the base row (row `wallHeight - 1`) is at the top (y=startY).
        // The tip (row 0) is at the bottom.
        yPos = startY + (wallHeight - 1 - row) * cellSpacing;
      } else {
        // For all other operations, the tip (row 0) is at the top.
        yPos = startY + row * cellSpacing;
      }
      
      for (int col = 0; col < cellsInRow; col++) {
        positions.add(Offset(startX + col * cellSpacing, yPos));
      }
    }
    
    return positions;
  }

  static NumberWallPuzzle generate(Map<String, dynamic> args) {
    final grade = args['grade'] as int;
    final level = args['level'] as int;
    final useCustomSettings = args['useCustomSettings'] as bool;
    final customOps = (args['customOps'] as List<dynamic>).cast<String>().toSet();
    final customMin = args['customMin'] as int;
    final customMax = args['customMax'] as int;

    final wallHeight = _determineWallHeight(grade, level);
    final operation = _determineOperation(grade, level, useCustomSettings, customOps);

    final generator = _NumberWallGenerator(
      wallHeight, grade, level, operation,
      useCustomSettings: useCustomSettings,
      customOps: customOps,
      customRangeMin: customMin,
      customRangeMax: customMax,
    );

    return generator.generate();
  }

  static int _determineWallHeight(int grade, int level) {
    if (kTweakProblems) return kTweakWallHeight;
    if (grade >= 4) { if (level <= 4) return 4; if (level <= 8) return 5; return 6; }
    if (grade >= 3) { if (level <= 6) return 3; return 4; }
    return 3;
  }

  static WallOperation _determineOperation(int grade, int level, bool useCustom, Set<String> customOps) {
    if (kTweakProblems) {
      switch (kTweakOps.toLowerCase()) {
        case 'addition': return WallOperation.addition;
        case 'subtraction': return WallOperation.subtraction;
        case 'multiplication': return WallOperation.multiplication;
        case 'division': return WallOperation.division;
      }
    }

    if (useCustom && customOps.isNotEmpty) {
      final availableOps = customOps.map((op) {
        switch(op) {
          case 'addition': return WallOperation.addition;
          case 'subtraction': return WallOperation.subtraction;
          case 'multiplication': return WallOperation.multiplication;
          case 'division': return WallOperation.division;
          default: return null;
        }
      }).whereType<WallOperation>().toList();
      
      if (availableOps.isNotEmpty) {
        return availableOps[math.Random().nextInt(availableOps.length)];
      }
    }

    if (grade == 1) return WallOperation.addition;
    if (grade == 2) {
      if (level <= 6) return WallOperation.addition;
      return math.Random().nextBool() ? WallOperation.addition : WallOperation.subtraction;
    }
    if (grade == 3) {
      final operations = [WallOperation.addition, WallOperation.subtraction];
      if (level >= 5) operations.add(WallOperation.multiplication);
      return operations[math.Random().nextInt(operations.length)];
    }
    final operations = [WallOperation.addition, WallOperation.subtraction, WallOperation.multiplication];
    if (level >= 6) operations.add(WallOperation.division);
    return operations[math.Random().nextInt(operations.length)];
  }

  bool validateSolution(List<int> userSolution) {
    final completeWall = List<int>.filled(totalCells, 0);
    final sortedHiddenCells = hiddenCells.toList()..sort();
    
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        completeWall[i] = visibleValues[i]!;
      }
    }
    
    for (int answerIndex = 0; answerIndex < userSolution.length; answerIndex++) {
      if (answerIndex < sortedHiddenCells.length) {
        final cellIndex = sortedHiddenCells[answerIndex];
        completeWall[cellIndex] = userSolution[answerIndex];
      }
    }
    
    return _validateOperationConstraints(completeWall, wallHeight, operation);
  }

  static bool _validateOperationConstraints(List<int> wall, int height, WallOperation operation) {
    for (int row = 0; row < height - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        if (rightChild < wall.length) {
          final parentValue = wall[parentCell];
          final leftValue = wall[leftChild];
          final rightValue = wall[rightChild];
          
          bool isValid = false;
          switch (operation) {
            case WallOperation.addition: isValid = parentValue == leftValue + rightValue; break;
            case WallOperation.subtraction: isValid = parentValue == (leftValue - rightValue).abs(); break;
            case WallOperation.multiplication: isValid = parentValue == leftValue * rightValue; break;
            case WallOperation.division:
              if (leftValue != 0 && rightValue != 0) {
                final div1 = leftValue / rightValue;
                final div2 = rightValue / leftValue;
                isValid = (div1 == parentValue && div1 == div1.roundToDouble()) || (div2 == parentValue && div2 == div2.roundToDouble());
              }
              break;
          }
          if (!isValid) return false;
        }
      }
    }
    return true;
  }
}

// Generator class
class _NumberWallGenerator {
  final int wallHeight;
  final int grade;
  final int level;
  final WallOperation operation;
  final int totalCells;
  final bool useCustomSettings;
  final Set<String> customOps;
  final int customRangeMin;
  final int customRangeMax;
  
  _NumberWallGenerator(this.wallHeight, this.grade, this.level, this.operation, {
    required this.useCustomSettings,
    required this.customOps,
    required this.customRangeMin,
    required this.customRangeMax,
  }) : totalCells = (wallHeight * (wallHeight + 1)) ~/ 2;

  NumberWallPuzzle generate() {
    List<int>? fullSolution;
    int attempts = 0;
    
    while (fullSolution == null && attempts < 50) {
      try {
        fullSolution = _generateValidWall();
        if (fullSolution != null && _validateWallStructure(fullSolution)) {
          break;
        } else {
          fullSolution = null;
        }
      } catch (e) {
        // Catches potential generation errors, e.g., division by zero
      }
      attempts++;
    }
    
    fullSolution ??= _createFallbackWall();
    
    final hiddenCells = _selectHiddenCells();
    
    final visibleValues = <int, int>{};
    for (int i = 0; i < totalCells; i++) {
      if (!hiddenCells.contains(i)) {
        visibleValues[i] = fullSolution[i];
      }
    }
    
    final hiddenNumbers = hiddenCells.map((i) => fullSolution![i]).toList();
    final decoyNumbers = _generateDecoyNumbers(hiddenNumbers);
    final numberPool = (hiddenNumbers + decoyNumbers)..shuffle();
    
    return NumberWallPuzzle(
      wallHeight: wallHeight,
      operation: operation,
      hiddenCells: hiddenCells,
      visibleValues: visibleValues,
      fullSolution: fullSolution,
      numberPool: numberPool,
    );
  }

  List<int>? _generateValidWall() {
    switch (operation) {
      case WallOperation.addition: return _generateAdditionWall();
      case WallOperation.subtraction: return _generateSubtractionWall();
      case WallOperation.multiplication: return _generateMultiplicationWall();
      case WallOperation.division: return _generateDivisionWall();
    }
  }

  List<int> _generateAdditionWall() {
    final bottomRow = List.generate(wallHeight, (_) => _getMinNumber() + math.Random().nextInt(_getMaxNumber() - _getMinNumber() + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => a + b);
  }

  List<int> _generateSubtractionWall() {
    final bottomRow = List.generate(wallHeight, (_) => math.max(1, _getMinNumber()) + math.Random().nextInt(_getMaxNumber() - _getMinNumber() + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => (a - b).abs());
  }

  List<int> _generateMultiplicationWall() {
    int minBase, maxBase;
    if (useCustomSettings) {
      // If the user sets max to 100, they want the top of the wall to be around 100.
      // Top of wall for height H is roughly factor^(2^(H-1)).
      // So factor = result^(1/2^(H-1)).
      double exponent = math.pow(2.0, wallHeight - 1.0).toDouble();
      double maxFactor = math.pow(customRangeMax.toDouble(), 1.0 / exponent).toDouble();
      minBase = customRangeMin;
      maxBase = maxFactor.floor().clamp(minBase, customRangeMax);
      // Ensure we have at least some range if customRangeMax is small
      if (maxBase == minBase && maxBase < customRangeMax && wallHeight > 2) {
         maxBase = (maxBase + 1).clamp(minBase, customRangeMax);
      }
    } else {
      minBase = math.max(1, (grade / 2).round());
      maxBase = math.max(3, (level / 2).round() + 3);
    }

    final bottomRow = List.generate(wallHeight, (_) => minBase + math.Random().nextInt(maxBase - minBase + 1));
    return _buildWallFromBottom(bottomRow, (a, b) => a * b);
  }

  List<int>? _generateDivisionWall() {
    final wall = List<int>.filled(totalCells, 0);
    final random = math.Random();
    
    int maxTopValue = useCustomSettings ? customRangeMax * 5 : 24 + grade * 12;
    wall[0] = (12 + random.nextInt(maxTopValue)) * 2; // Start with a highly divisible number
    
    for (int row = 0; row < wallHeight - 1; row++) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final parentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        
        final parentValue = wall[parentCell];
        if (parentValue == 0) return null; // Generation failed
        
        // Find divisors
        final divisors = [ for (var i = 2; i <= parentValue / 2; i++) if (parentValue % i == 0) i ];
        if (divisors.isEmpty) divisors.add(parentValue); // Is a prime or 1
        
        final rightValue = divisors[random.nextInt(divisors.length)];
        final leftValue = (parentValue * rightValue);
        
        wall[leftChild] = leftValue;
        wall[rightChild] = rightValue;
      }
    }
    // Reverse build for division logic
    return _buildWallFromBottom(wall.sublist(wall.length - wallHeight), (a, b) {
      if (b != 0 && a % b == 0) return a ~/ b;
      if (a != 0 && b % a == 0) return b ~/ a;
      return 0; // Should not happen with this generation logic
    });
  }

  List<int> _buildWallFromBottom(List<int> bottomRow, int Function(int, int) operation) {
    final wall = List<int>.filled(totalCells, 0);
    final bottomRowStart = (wallHeight - 1) * wallHeight ~/ 2;
    for (int i = 0; i < wallHeight; i++) {
      wall[bottomRowStart + i] = bottomRow[i];
    }
    
    for (int row = wallHeight - 2; row >= 0; row--) {
      final cellsInCurrentRow = row + 1;
      final currentRowStart = row * (row + 1) ~/ 2;
      final nextRowStart = (row + 1) * (row + 2) ~/ 2;
      for (int col = 0; col < cellsInCurrentRow; col++) {
        final currentCell = currentRowStart + col;
        final leftChild = nextRowStart + col;
        final rightChild = nextRowStart + col + 1;
        if (rightChild < wall.length) {
          wall[currentCell] = operation(wall[leftChild], wall[rightChild]);
        }
      }
    }
    return wall;
  }

  bool _validateWallStructure(List<int> wall) {
    if (wall.any((n) => n > 5000)) return false; // Prevent excessively large numbers
    return NumberWallPuzzle._validateOperationConstraints(wall, wallHeight, operation);
  }

  List<int> _createFallbackWall() {
    switch (operation) {
      case WallOperation.addition: return wallHeight == 3 ? [15, 7, 8, 3, 4, 4] : [30, 13, 17, 5, 8, 9, 2, 3, 5, 4];
      case WallOperation.subtraction: return wallHeight == 3 ? [1, 3, 2, 5, 2, 4] : [2, 1, 3, 4, 3, 6, 8, 4, 1, 5];
      case WallOperation.multiplication: return wallHeight == 3 ? [48, 6, 8, 2, 3, 4, 2] : [144, 12, 12, 3, 4, 3, 1, 3, 4, 1];
      case WallOperation.division: return wallHeight == 3 ? [2, 8, 4, 16, 2, 8] : [2, 4, 2, 16, 4, 8, 2, 2, 4];
    }
  }

  Set<int> _selectHiddenCells() {
    final maxHidden = (2 + grade + (level / 5)).clamp(2, totalCells - 2).floor();
    final candidates = List.generate(totalCells, (i) => i)..shuffle();
    return candidates.take(maxHidden).toSet();
  }

  List<int> _generateDecoyNumbers(List<int> hiddenNumbers) {
    final decoys = <int>{};
    final decoyCount = (8 - hiddenNumbers.length).clamp(2, 4);
    
    for (final num in hiddenNumbers) {
      if (decoys.length >= decoyCount) break;
      final offset = 1 + math.Random().nextInt(5);
      final variations = [num - offset, num + offset, num * 2, (num / 2).round()];
      for (final v in variations) {
        if (!hiddenNumbers.contains(v) && v > 0) {
          decoys.add(v);
          if (decoys.length >= decoyCount) break;
        }
      }
    }
    while (decoys.length < decoyCount) {
      decoys.add(1 + math.Random().nextInt(20));
    }
    
    return decoys.toList();
  }

  int _getMinNumber() {
    // Tweak/Custom settings take priority
    if (kTweakProblems) return kTweakRangeMin;
    if (useCustomSettings) return customRangeMin;
    // Default dynamic calculation
    return math.max(1, (grade - 1) * 3 + (level / 2).floor());
  }

  int _getMaxNumber() {
    // Tweak/Custom settings take priority
    if (kTweakProblems) return kTweakRangeMax;
    if (useCustomSettings) return customRangeMax;
    // Default dynamic calculation
    return _getMinNumber() + 10 + grade * 2;
  }
}

// Background painter for visual effects
class NumberWallBackgroundPainter extends CustomPainter {
  final double glowIntensity;
  final double warpActivation;
  final WallOperation operation;

  const NumberWallBackgroundPainter({
    required this.glowIntensity,
    required this.warpActivation,
    required this.operation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    Color baseColor;
    switch (operation) {
      case WallOperation.addition: baseColor = SpaceTheme.alienGreen; break;
      case WallOperation.subtraction: baseColor = SpaceTheme.cosmicPink; break;
      case WallOperation.multiplication: baseColor = SpaceTheme.starYellow; break;
      case WallOperation.division: baseColor = SpaceTheme.planetOrange; break;
    }
    
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [ baseColor.withValues(alpha: 0.1 * glowIntensity), Colors.transparent ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));
    
    canvas.drawCircle(center, size.width * 0.6, backgroundPaint);
    
    if (warpActivation > 0) {
      final warpPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.4 * (1 - warpActivation))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 + (warpActivation * 10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + warpActivation * 10);
      
      canvas.drawCircle(center, size.width * 0.1 + (size.width/2 * warpActivation), warpPaint);
    }
  }

  @override
  bool shouldRepaint(NumberWallBackgroundPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.warpActivation != warpActivation ||
      oldDelegate.operation != operation;
}