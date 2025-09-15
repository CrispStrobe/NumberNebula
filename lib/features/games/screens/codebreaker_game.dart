import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

// Assuming these paths are correct for your project structure
import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../../../core/services/sri_service.dart';

// Space-themed symbols for our equations
enum SpaceSymbol {
  planet,
  star,
  rocket,
  satellite,
  asteroid,
  comet,
  galaxy,
  nebula,
}

extension SpaceSymbolData on SpaceSymbol {
  IconData get icon {
    switch (this) {
      case SpaceSymbol.planet:
        return Icons.public;
      case SpaceSymbol.star:
        return Icons.star;
      case SpaceSymbol.rocket:
        return Icons.rocket_launch;
      case SpaceSymbol.satellite:
        return Icons.satellite_alt;
      case SpaceSymbol.asteroid:
        return Icons.circle;
      case SpaceSymbol.comet:
        return Icons.brightness_1;
      case SpaceSymbol.galaxy:
        return Icons.blur_circular;
      case SpaceSymbol.nebula:
        return Icons.cloud;
    }
  }

  Color get color {
    switch (this) {
      case SpaceSymbol.planet:
        return Colors.blue;
      case SpaceSymbol.star:
        return Colors.yellow;
      case SpaceSymbol.rocket:
        return Colors.orange;
      case SpaceSymbol.satellite:
        return Colors.cyan;
      case SpaceSymbol.asteroid:
        return Colors.brown;
      case SpaceSymbol.comet:
        return Colors.purple;
      case SpaceSymbol.galaxy:
        return Colors.pink;
      case SpaceSymbol.nebula:
        return Colors.teal;
    }
  }
}

class AlienEquation {
  final List<EquationTerm> leftSide;
  final int result;
  final bool resultHidden;

  AlienEquation({
    required this.leftSide,
    required this.result,
    this.resultHidden = false,
  });

  bool isValid(Map<SpaceSymbol, int> symbolValues) {
    int leftSum = 0;
    for (var term in leftSide) {
      if (term.isHidden) return false; // Can't validate with hidden terms
      leftSum += symbolValues[term.symbol]! * term.coefficient;
    }
    return leftSum == result;
  }
}

class EquationTerm {
  final SpaceSymbol symbol;
  final int coefficient;
  final bool isHidden;

  EquationTerm({
    required this.symbol,
    this.coefficient = 1,
    this.isHidden = false,
  });
}

class CodebreakerPuzzle {
  final List<AlienEquation> equations;
  final Map<SpaceSymbol, int> solution;
  final Set<int> hiddenValues;
  final List<int> availableNumbers;

  CodebreakerPuzzle({
    required this.equations,
    required this.solution,
    required this.hiddenValues,
    required this.availableNumbers,
  });
}

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
  // Animation Controllers
  late AnimationController _gameController;
  late AnimationController _glitchController;
  late AnimationController _feedbackController;
  late AnimationController _transmissionController;

  // Game State
  bool gameActive = true;
  double lives = 3.0;
  int puzzlesSolved = 0;
  late int targetPuzzles;
  int totalScore = 0;

  // Current Puzzle State
  CodebreakerPuzzle? currentPuzzle;
  Map<SpaceSymbol, int?> userSolution = {};
  Map<int, int> selectedNumbers = {}; // position -> number
  bool solvingPuzzle = false;
  
  // Visual Effects
  List<TransmissionParticle> particles = [];
  String statusMessage = "";
  Timer? _statusTimer;
  Color feedbackColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _initializeGameValues();
    _generateNewPuzzle();
  }

  void _setupAnimationControllers() {
    _gameController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateGame)..repeat();

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() => setState(() {}));

    _transmissionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _initializeGameValues() {
    targetPuzzles = 5 + widget.grade;
    totalScore = 0;
  }

  void _generateNewPuzzle() {
    if (!mounted || !gameActive) return;

    setState(() {
      currentPuzzle = _createAlienCodePuzzle();
      userSolution.clear();
      selectedNumbers.clear();
      solvingPuzzle = true;
    });

    _addTransmissionEffect();
  }

  CodebreakerPuzzle _createAlienCodePuzzle() {
    final random = math.Random();
    final difficulty = widget.grade;
    
    // Determine complexity based on grade
    final numSymbols = math.min(4, 2 + (difficulty ~/ 2));
    final maxValue = 5 + (difficulty * 3);
    final numEquations = math.min(4, 2 + (difficulty ~/ 3));

    // Select random symbols
    final allSymbols = SpaceSymbol.values.toList()..shuffle();
    final symbols = allSymbols.take(numSymbols).toList();

    // Generate solution values
    final solution = <SpaceSymbol, int>{};
    for (var symbol in symbols) {
      solution[symbol] = 1 + random.nextInt(maxValue);
    }

    // Create equations
    final equations = <AlienEquation>[];
    final hiddenValues = <int>{};

    for (int i = 0; i < numEquations; i++) {
      final terms = <EquationTerm>[];
      int result = 0;

      // Add 1-3 terms per equation
      final numTerms = 1 + random.nextInt(math.min(3, symbols.length));
      final equationSymbols = symbols.toList()..shuffle();

      for (int j = 0; j < numTerms; j++) {
        final symbol = equationSymbols[j];
        final coefficient = 1 + random.nextInt(2); // 1 or 2
        terms.add(EquationTerm(symbol: symbol, coefficient: coefficient));
        result += solution[symbol]! * coefficient;
      }

      // Decide what to hide - sometimes the result, sometimes symbol values
      final hideResult = random.nextBool() && i > 0; // Don't hide first result
      
      if (hideResult) {
        hiddenValues.add(result);
        equations.add(AlienEquation(
          leftSide: terms,
          result: result,
          resultHidden: true,
        ));
      } else {
        equations.add(AlienEquation(
          leftSide: terms,
          result: result,
          resultHidden: false,
        ));
      }
    }

    // Also hide some symbol values for user to guess
    final symbolsToHide = symbols.take(1 + random.nextInt(symbols.length)).toList();
    for (var symbol in symbolsToHide) {
      hiddenValues.add(solution[symbol]!);
    }

    // Generate available numbers (correct ones + distractors)
    final availableNumbers = <int>[];
    availableNumbers.addAll(hiddenValues);

    // Add distractors
    for (var value in hiddenValues) {
      // Add numbers close to the correct ones
      for (int offset in [-2, -1, 1, 2]) {
        final distractor = value + offset;
        if (distractor > 0 && distractor <= maxValue * 2) {
          availableNumbers.add(distractor);
        }
      }
    }

    // Ensure we have enough copies of numbers that appear multiple times
    final numberCounts = <int, int>{};
    for (var num in hiddenValues) {
      numberCounts[num] = (numberCounts[num] ?? 0) + 1;
    }

    final finalNumbers = <int>[];
    for (var entry in numberCounts.entries) {
      for (int i = 0; i < entry.value; i++) {
        finalNumbers.add(entry.key);
      }
    }

    // Add remaining distractors
    availableNumbers.removeWhere((n) => hiddenValues.contains(n));
    finalNumbers.addAll(availableNumbers.take(8).toList());
    finalNumbers.shuffle();

    return CodebreakerPuzzle(
      equations: equations,
      solution: solution,
      hiddenValues: hiddenValues,
      availableNumbers: finalNumbers,
    );
  }

  void _selectNumber(int number, int position) {
    if (!solvingPuzzle) return;

    HapticFeedback.lightImpact();
    
    setState(() {
      selectedNumbers[position] = number;
    });

    _checkSolution();
  }

  void _checkSolution() {
    if (currentPuzzle == null) return;

    final puzzle = currentPuzzle!;
    final allPositionsFilled = _getAllHiddenPositions().every(
      (pos) => selectedNumbers.containsKey(pos),
    );

    if (!allPositionsFilled) return;

    // Build user's proposed solution
    final userValues = <SpaceSymbol, int>{};
    final hiddenResults = <int>[];
    
    int hiddenIndex = 0;
    
    // Extract symbol values and hidden results from user selections
    for (var equation in puzzle.equations) {
      if (equation.resultHidden) {
        hiddenResults.add(selectedNumbers[hiddenIndex] ?? 0);
        hiddenIndex++;
      }
      
      for (var term in equation.leftSide) {
        if (puzzle.hiddenValues.contains(puzzle.solution[term.symbol])) {
          if (!userValues.containsKey(term.symbol)) {
            userValues[term.symbol] = selectedNumbers[hiddenIndex] ?? 0;
            hiddenIndex++;
          }
        } else {
          userValues[term.symbol] = puzzle.solution[term.symbol]!;
        }
      }
    }

    // Validate the solution
    bool isCorrect = _validateUserSolution(userValues, hiddenResults);
    
    if (isCorrect) {
      _handleCorrectSolution();
    } else {
      _handleIncorrectSolution();
    }
  }

  bool _validateUserSolution(Map<SpaceSymbol, int> userValues, List<int> hiddenResults) {
    final puzzle = currentPuzzle!;
    
    int hiddenResultIndex = 0;
    
    for (var equation in puzzle.equations) {
      int leftSum = 0;
      bool canValidate = true;
      
      for (var term in equation.leftSide) {
        if (userValues.containsKey(term.symbol)) {
          leftSum += userValues[term.symbol]! * term.coefficient;
        } else {
          canValidate = false;
          break;
        }
      }
      
      if (!canValidate) continue;
      
      int expectedResult;
      if (equation.resultHidden) {
        expectedResult = hiddenResults[hiddenResultIndex];
        hiddenResultIndex++;
      } else {
        expectedResult = equation.result;
      }
      
      if (leftSum != expectedResult) {
        return false;
      }
    }
    
    return true;
  }

  List<int> _getAllHiddenPositions() {
    if (currentPuzzle == null) return [];
    
    final positions = <int>[];
    int index = 0;
    
    for (var equation in currentPuzzle!.equations) {
      if (equation.resultHidden) {
        positions.add(index++);
      }
    }
    
    // Add positions for hidden symbol values
    final hiddenSymbols = <SpaceSymbol>{};
    for (var equation in currentPuzzle!.equations) {
      for (var term in equation.leftSide) {
        if (currentPuzzle!.hiddenValues.contains(currentPuzzle!.solution[term.symbol])) {
          hiddenSymbols.add(term.symbol);
        }
      }
    }
    
    for (var symbol in hiddenSymbols) {
      positions.add(index++);
    }
    
    return positions;
  }

  void _handleCorrectSolution() {
    puzzlesSolved++;
    final scoreGained = (150 * widget.grade) + (lives.floor() * 75);
    totalScore += scoreGained;
    
    try {
      context.read<GameProvider>().addScore(scoreGained);
    } catch (e) {
      debugPrint('GameProvider not available: $e');
    }
    
    _addSuccessEffect();
    _triggerFeedback(true);
    HapticFeedback.mediumImpact();
    
    _showStatus("${S.of(context)!.codebreakerSuccess} +$scoreGained");
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (puzzlesSolved >= targetPuzzles) {
        _winGame();
      } else {
        _generateNewPuzzle();
      }
    });
  }

  void _handleIncorrectSolution() {
    lives -= 0.5;
    
    _addGlitchEffect();
    _triggerFeedback(false);
    _glitchController.forward(from: 0.0).then((_) {
      _glitchController.reverse();
    });
    HapticFeedback.vibrate();
    
    _showStatus("${S.of(context)!.codebreakerError} (-0.5 HP)");
    
    if (lives <= 0) {
      Future.delayed(const Duration(milliseconds: 1000), _gameOver);
    } else {
      // Clear incorrect selections after a delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            selectedNumbers.clear();
          });
        }
      });
    }
  }

  void _triggerFeedback(bool isSuccess) {
    feedbackColor = isSuccess 
        ? Colors.cyan.withOpacity(0.3) 
        : Colors.red.withOpacity(0.4);
    _feedbackController.forward(from: 0.0).then((_) {
      if (mounted) _feedbackController.reverse();
    });
  }

  void _addTransmissionEffect() {
    for (int i = 0; i < 20; i++) {
      particles.add(TransmissionParticle.incoming());
    }
  }

  void _addSuccessEffect() {
    for (int i = 0; i < 30; i++) {
      particles.add(TransmissionParticle.success());
    }
  }

  void _addGlitchEffect() {
    for (int i = 0; i < 25; i++) {
      particles.add(TransmissionParticle.glitch());
    }
  }

  void _showStatus(String message, {Duration duration = const Duration(seconds: 2)}) {
    setState(() => statusMessage = message);
    _statusTimer?.cancel();
    _statusTimer = Timer(duration, () {
      if (mounted) setState(() => statusMessage = "");
    });
  }

  void _updateGame() {
    if (!mounted) return;
    
    final dt = 0.016;
    particles.removeWhere((p) => p.update(dt));
  }

  void _winGame() {
    if (!mounted) return;
    gameActive = false;
    final completionBonus = 750 + (lives.toInt() * 150);
    totalScore += completionBonus;
    context.read<GameProvider>().addScore(completionBonus);
    context.read<GameProvider>().updateGameProgress('codebreaker', widget.level);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildEndDialog(true),
    );
  }

  void _gameOver() {
    if (!mounted) return;
    gameActive = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildEndDialog(false),
    );
  }

  void _resetGame() {
    if (!mounted) return;
    Navigator.pop(context);
    
    setState(() {
      gameActive = true;
      lives = 3.0;
      puzzlesSolved = 0;
      totalScore = 0;
    });
    _generateNewPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background
            _buildAnimatedBackground(),
            
            // Glitch effect overlay
            if (_glitchController.isAnimating)
              _buildGlitchOverlay(),
            
            // Main content
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildMainContent(),
                ),
                _buildInstructions(),
              ],
            ),
            
            // Particles
            ..._buildParticles(),
            
            // Feedback overlay
            IgnorePointer(
              child: Container(
                color: feedbackColor.withOpacity(
                  feedbackColor.opacity * _feedbackController.value,
                ),
              ),
            ),
            
            // Status message
            if (statusMessage.isNotEmpty)
              _buildStatusMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A1A),
            const Color(0xFF1A1A3A),
            const Color(0xFF2A1A4A),
          ],
          stops: [
            0.0,
            0.5 + 0.2 * math.sin(_transmissionController.value * 2 * math.pi),
            1.0,
          ],
        ),
      ),
    );
  }

  Widget _buildGlitchOverlay() {
    return Container(
      color: Colors.red.withOpacity(0.1 * _glitchController.value),
      child: CustomPaint(
        size: Size.infinite,
        painter: GlitchPainter(_glitchController.value),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                '$puzzlesSolved/$targetPuzzles',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(3, (index) => Icon(
              index < lives.ceil() ? Icons.favorite : Icons.favorite_border,
              color: index < lives ? Colors.redAccent : Colors.grey,
              size: 24,
            )),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.yellow, size: 20),
              const SizedBox(width: 8),
              Text(
                '$totalScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (currentPuzzle == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildTransmissionHeader(),
          const SizedBox(height: 20),
          _buildEquations(),
          const SizedBox(height: 30),
          _buildNumberSelection(),
        ],
      ),
    );
  }

  Widget _buildTransmissionHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.radio,
            color: Colors.cyan,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.codebreakerTransmissionReceived,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: _transmissionController.value,
              color: Colors.cyan,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquations() {
    final puzzle = currentPuzzle!;
    int hiddenIndex = 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A3A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: puzzle.equations.asMap().entries.map((entry) {
          final equation = entry.value;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left side of equation
                ...equation.leftSide.asMap().entries.expand((termEntry) {
                  final term = termEntry.value;
                  final isLast = termEntry.key == equation.leftSide.length - 1;
                  
                  return [
                    _buildSymbolTerm(term),
                    if (!isLast) 
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ];
                }),
                
                // Equals sign
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '=',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Result
                if (equation.resultHidden)
                  _buildHiddenValue(hiddenIndex++)
                else
                  _buildKnownValue(equation.result),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSymbolTerm(EquationTerm term) {
    final isHidden = currentPuzzle!.hiddenValues.contains(
      currentPuzzle!.solution[term.symbol],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (term.coefficient > 1)
          Text(
            '${term.coefficient}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        Icon(
          term.symbol.icon,
          color: term.symbol.color,
          size: 32,
        ),
        if (isHidden)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange, width: 1),
            ),
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHiddenValue(int position) {
    final selectedNumber = selectedNumbers[position];
    
    return GestureDetector(
      onTap: () {
        // Allow deselecting
        if (selectedNumber != null) {
          setState(() {
            selectedNumbers.remove(position);
          });
        }
      },
      child: Container(
        width: 50,
        height: 40,
        decoration: BoxDecoration(
          color: selectedNumber != null 
              ? Colors.cyan.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectedNumber != null ? Colors.cyan : Colors.grey,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            selectedNumber?.toString() ?? '?',
            style: TextStyle(
              color: selectedNumber != null ? Colors.white : Colors.grey,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKnownValue(int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Text(
        value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNumberSelection() {
    final puzzle = currentPuzzle!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            S.of(context)!.codebreakerSelectNumbers,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: puzzle.availableNumbers.asMap().entries.map((entry) {
              final number = entry.value;
              final isUsed = selectedNumbers.containsValue(number);
              
              return GestureDetector(
                onTap: isUsed ? null : () {
                  // Find first empty position
                  final positions = _getAllHiddenPositions();
                  for (var pos in positions) {
                    if (!selectedNumbers.containsKey(pos)) {
                      _selectNumber(number, pos);
                      break;
                    }
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isUsed 
                        ? Colors.grey.withOpacity(0.3)
                        : Colors.cyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUsed ? Colors.grey : Colors.cyan,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: TextStyle(
                        color: isUsed ? Colors.grey : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        S.of(context)!.codebreakerInstructions,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(
          statusMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    return particles.map((p) => p.build()).toList();
  }

  Widget _buildEndDialog(bool isWin) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E).withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isWin ? Colors.greenAccent : Colors.redAccent,
          width: 2,
        ),
      ),
      title: Row(
        children: [
          Icon(
            isWin ? Icons.lock_open : Icons.error,
            color: isWin ? Colors.green : Colors.red,
            size: 30,
          ),
          const SizedBox(width: 10),
          Text(
            isWin 
                ? S.of(context)!.codebreakerWinTitle 
                : S.of(context)!.codebreakerLoseTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        isWin 
            ? S.of(context)!.codebreakerWinDesc(targetPuzzles, totalScore)
            : S.of(context)!.codebreakerLoseDesc,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          child: Text(
            S.of(context)!.playAgain,
            style: const TextStyle(color: Colors.cyanAccent),
          ),
          onPressed: _resetGame,
        ),
        TextButton(
          child: Text(
            S.of(context)!.backToMenu,
            style: const TextStyle(color: Colors.white),
          ),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _gameController.dispose();
    _glitchController.dispose();
    _feedbackController.dispose();
    _transmissionController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }
}

// Particle effect for transmission/glitch effects
class TransmissionParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  TransmissionParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory TransmissionParticle.incoming() {
    final random = math.Random();
    return TransmissionParticle(
      position: Offset(
        random.nextDouble() * 400,
        random.nextDouble() * 800,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 50,
        (random.nextDouble() - 0.5) * 50,
      ),
      color: Colors.cyan,
      size: 1 + random.nextDouble() * 2,
      opacity: 0.8,
      life: 2 + random.nextDouble() * 2,
    );
  }

  factory TransmissionParticle.success() {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 50 + random.nextDouble() * 100;
    
    return TransmissionParticle(
      position: Offset(200, 400),
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.cyan, Colors.green, Colors.white][random.nextInt(3)],
      size: 2 + random.nextDouble() * 3,
      opacity: 1.0,
      life: 1 + random.nextDouble() * 1,
    );
  }

  factory TransmissionParticle.glitch() {
    final random = math.Random();
    return TransmissionParticle(
      position: Offset(
        random.nextDouble() * 400,
        random.nextDouble() * 800,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 200,
        (random.nextDouble() - 0.5) * 200,
      ),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 2 + random.nextDouble() * 4,
      opacity: 1.0,
      life: 0.5 + random.nextDouble() * 0.5,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.98;
    return life <= 0;
  }

  Widget build() {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(opacity * 0.5),
              blurRadius: size * 2,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for glitch effects
class GlitchPainter extends CustomPainter {
  final double progress;

  GlitchPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistent glitch
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red.withOpacity(0.3 * progress);

    for (int i = 0; i < 10; i++) {
      final y = random.nextDouble() * size.height;
      final startX = random.nextDouble() * size.width * 0.2;
      final endX = size.width - random.nextDouble() * size.width * 0.2;
      
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GlitchPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}