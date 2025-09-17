import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/theme/space_theme.dart';
import '../constants/app_constants.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../../../core/services/sri_service.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class SignalTriangulationGame extends StatefulWidget {
  final int grade;
  final int level;

  const SignalTriangulationGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<SignalTriangulationGame> createState() => _SignalTriangulationGameState();
}

class _SignalTriangulationGameState extends State<SignalTriangulationGame>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _successController;
  late AnimationController _feedbackController;
  late AnimationController _glyphController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _feedbackAnimation;
  late Animation<double> _glyphAnimation;

  // Game State
  late List<SignalGlyph> secretSequence;
  late List<SignalGlyph> currentGuess;
  late List<GuessResult> previousGuesses;
  late int maxGuesses;
  late int sequenceLength;
  bool gameActive = true;
  bool hasWon = false;
  int currentPosition = 0;
  
  // Visual Effects
  List<SignalParticle> particles = [];
  double scanProgress = 0.0;
  
  // Available glyphs based on difficulty
  late List<SignalGlyph> availableGlyphs;

  @override
  void initState() {
    super.initState();
    debugPrint("🎯 [SignalTriangulation] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _initializeGameParameters();
    _generateSecretSequence();
    
    debugPrint("🎯 [SignalTriangulation] Secret sequence: ${secretSequence.map((g) => g.name).join(', ')}");
  }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
        parent: _successController, curve: Curves.elasticOut);

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _feedbackAnimation = CurvedAnimation(
        parent: _feedbackController, curve: Curves.easeOut);

    _glyphController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glyphAnimation = CurvedAnimation(
        parent: _glyphController, curve: Curves.elasticOut);
  }

  void _initializeGameParameters() {
    // Determine difficulty based on grade and level
    final complexity = widget.grade + (widget.level / 5.0);
    
    if (complexity <= 2.0) {
      sequenceLength = 4;
      maxGuesses = 10;
      availableGlyphs = SignalGlyph.getBasicGlyphs();
    } else if (complexity <= 3.5) {
      sequenceLength = 4;
      maxGuesses = 8;
      availableGlyphs = SignalGlyph.getIntermediateGlyphs();
    } else if (complexity <= 5.0) {
      sequenceLength = 5;
      maxGuesses = 9;
      availableGlyphs = SignalGlyph.getAdvancedGlyphs();
    } else {
      sequenceLength = 6;
      maxGuesses = 10;
      availableGlyphs = SignalGlyph.getAllGlyphs();
    }
    
    currentGuess = List.filled(sequenceLength, SignalGlyph.empty);
    previousGuesses = [];
    currentPosition = 0;
    
    debugPrint("🎯 [SignalTriangulation] Game parameters: length=$sequenceLength, guesses=$maxGuesses, glyphs=${availableGlyphs.length}");
  }

  void _generateSecretSequence() {
    final random = math.Random();
    secretSequence = List.generate(sequenceLength, (_) {
      return availableGlyphs[random.nextInt(availableGlyphs.length)];
    });
  }

  void _selectGlyph(SignalGlyph glyph) {
    if (!gameActive || currentPosition >= sequenceLength) return;
    
    HapticFeedback.lightImpact();
    _glyphController.forward(from: 0.0);
    
    setState(() {
      currentGuess[currentPosition] = glyph;
      currentPosition++;
    });
    
    debugPrint("🎯 [SignalTriangulation] Selected glyph: ${glyph.name} at position $currentPosition");
    
    // Auto-submit when sequence is complete
    if (currentPosition >= sequenceLength) {
      Future.delayed(const Duration(milliseconds: 500), _submitGuess);
    }
  }

  void _clearGuess() {
    if (!gameActive) return;
    
    setState(() {
      currentGuess = List.filled(sequenceLength, SignalGlyph.empty);
      currentPosition = 0;
    });
  }

  void _submitGuess() async {
    if (!gameActive || currentGuess.any((g) => g == SignalGlyph.empty)) return;
    
    debugPrint("🎯 [SignalTriangulation] Submitting guess: ${currentGuess.map((g) => g.name).join(', ')}");
    
    // Calculate feedback
    final feedback = _calculateFeedback(currentGuess, secretSequence);
    final result = GuessResult(
      guess: List.from(currentGuess),
      correctPosition: feedback['correct']!,
      correctGlyph: feedback['present']!,
    );
    
    setState(() {
      previousGuesses.add(result);
      currentGuess = List.filled(sequenceLength, SignalGlyph.empty);
      currentPosition = 0;
    });
    
    // Record response for SRI tracking
    final sriService = context.read<SriService>();
    final isCorrect = result.correctPosition == sequenceLength;
    
    // Create a simple problem for SRI tracking
    final problem = MathProblem(
      operandA: previousGuesses.length,
      operandB: maxGuesses,           
      operation: MathOperation.addition, // enum value
      answer: isCorrect ? 1 : 0,
      expression: 'Signal Triangulation Attempt ${previousGuesses.length}',
      difficulty: widget.grade,       // required parameter
    );
    sriService.recordResponse(problem, isCorrect);
    
    _feedbackController.forward(from: 0.0);
    
    // Add feedback particles
    _addFeedbackParticles(result);
    
    if (isCorrect) {
      _handleSuccess();
    } else if (previousGuesses.length >= maxGuesses) {
      _handleFailure();
    }
  }

  Map<String, int> _calculateFeedback(List<SignalGlyph> guess, List<SignalGlyph> secret) {
    int correctPosition = 0;
    int correctGlyph = 0;
    
    // Count exact matches
    for (int i = 0; i < guess.length; i++) {
      if (guess[i] == secret[i]) {
        correctPosition++;
      }
    }
    
    // Count color matches (including exact matches)
    final guessCount = <SignalGlyph, int>{};
    final secretCount = <SignalGlyph, int>{};
    
    for (final glyph in guess) {
      guessCount[glyph] = (guessCount[glyph] ?? 0) + 1;
    }
    for (final glyph in secret) {
      secretCount[glyph] = (secretCount[glyph] ?? 0) + 1;
    }
    
    for (final glyph in guessCount.keys) {
      correctGlyph += math.min(guessCount[glyph]!, secretCount[glyph] ?? 0);
    }
    
    // Subtract exact matches to get wrong-position matches
    correctGlyph -= correctPosition;
    
    return {'correct': correctPosition, 'present': correctGlyph};
  }

  void _addFeedbackParticles(GuessResult result) {
    final random = math.Random();
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    
    // Success particles for correct positions
    for (int i = 0; i < result.correctPosition; i++) {
      particles.add(SignalParticle.success(
        Offset(centerX + (random.nextDouble() - 0.5) * 100, 300),
      ));
    }
    
    // Warning particles for correct glyphs in wrong positions
    for (int i = 0; i < result.correctGlyph; i++) {
      particles.add(SignalParticle.warning(
        Offset(centerX + (random.nextDouble() - 0.5) * 100, 300),
      ));
    }
  }

  void _handleSuccess() {
    debugPrint("🎉 [SignalTriangulation] Success! Signal triangulated successfully");
    
    setState(() {
      gameActive = false;
      hasWon = true;
    });
    
    _successController.forward();
    HapticFeedback.heavyImpact();
    
    // Calculate score based on performance
    final baseScore = 200 * widget.grade;
    final efficiencyBonus = math.max(0, (maxGuesses - previousGuesses.length) * 50);
    final difficultyBonus = (sequenceLength - 3) * 100;
    final totalScore = baseScore + efficiencyBonus + difficultyBonus;
    
    context.read<GameProvider>().addScore(totalScore);
    context.read<GameProvider>().updateGameProgress('signal_triangulation', widget.level);
    
    // Add celebration particles
    for (int i = 0; i < 50; i++) {
      particles.add(SignalParticle.celebration(
        MediaQuery.of(context).size.center(Offset.zero),
      ));
    }
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, efficiencyBonus),
        );
      }
    });
  }

  void _handleFailure() {
    debugPrint("❌ [SignalTriangulation] Failed - Signal source remains hidden");
    
    setState(() {
      gameActive = false;
      hasWon = false;
    });
    
    HapticFeedback.vibrate();
    
    // Add failure particles
    for (int i = 0; i < 30; i++) {
      particles.add(SignalParticle.failure(
        MediaQuery.of(context).size.center(Offset.zero),
      ));
    }
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildFailureDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background effects
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _scanController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: SignalBackgroundPainter(
                        pulseIntensity: _pulseAnimation.value,
                        scanProgress: _scanAnimation.value,
                        gameWon: hasWon,
                      ),
                    );
                  },
                ),
              ),
              
              // Particles
              ...particles.map((p) => p.build()),
              
              // Main game UI
              Column(
                children: [
                  GameUI(
                    title: S.of(context)!.signalTriangulationGameTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      S.of(context)!.signalTriangulationInstructions,
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Status info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: SpaceTheme.cardDecoration,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.radio, color: SpaceTheme.alienGreen, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context)!.signalTriangulationAttempts(previousGuesses.length, maxGuesses),
                              style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.alienGreen),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.adjust, color: SpaceTheme.starYellow, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context)!.signalTriangulationLength(sequenceLength),
                              style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Current guess area
                          _buildCurrentGuess(),
                          
                          const SizedBox(height: 20),
                          
                          // Glyph selector
                          _buildGlyphSelector(),
                          
                          const SizedBox(height: 20),
                          
                          // Previous guesses
                          _buildPreviousGuesses(),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentGuess() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.signalTriangulationCurrentSequence,
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(sequenceLength, (index) {
              final glyph = currentGuess[index];
              final isActive = index == currentPosition && gameActive;
              
              return AnimatedBuilder(
                animation: _glyphAnimation,
                builder: (context, child) {
                  final scale = (index == currentPosition - 1) ? 
                      (1.0 + _glyphAnimation.value * 0.3) : 1.0;
                  
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glyph.color,
                        border: Border.all(
                          color: isActive ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                          width: isActive ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (glyph.color ?? Colors.transparent).withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: isActive ? 3 : 1,
                          ),
                        ],
                      ),
                      child: glyph.icon != null ?
                          Icon(glyph.icon, color: Colors.white, size: 30) :
                          (isActive ? Icon(Icons.radio_button_unchecked, 
                              color: SpaceTheme.starYellow, size: 24) : null),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          if (gameActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: currentPosition > 0 ? _clearGuess : null,
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.signalTriangulationClear),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: currentPosition >= sequenceLength ? _submitGuess : null,
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.signalTriangulationTransmit),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlyphSelector() {
    if (!gameActive) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        children: [
          Text(
            S.of(context)!.signalTriangulationFrequencies,
            style: SpaceTheme.titleStyle,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: availableGlyphs.map((glyph) {
              return GestureDetector(
                onTap: () => _selectGlyph(glyph),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glyph.color,
                        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: glyph.color!.withOpacity(_pulseAnimation.value * 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(glyph.icon, color: Colors.white, size: 24),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousGuesses() {
    if (previousGuesses.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        children: [
          Text(
            S.of(context)!.signalTriangulationPreviousAttempts,
            style: SpaceTheme.titleStyle,
          ),
          const SizedBox(height: 16),
          ...previousGuesses.reversed.map((result) => _buildGuessResult(result)),
        ],
      ),
    );
  }

  Widget _buildGuessResult(GuessResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Guess sequence
          Expanded(
            child: Row(
              children: result.guess.map((glyph) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glyph.color,
                  border: Border.all(color: Colors.white30),
                ),
                child: Icon(glyph.icon, color: Colors.white, size: 16),
              )).toList(),
            ),
          ),
          
          // Feedback
          Row(
            children: [
              // Correct position indicators
              ...List.generate(result.correctPosition, (_) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: SpaceTheme.alienGreen,
                ),
              )),
              // Correct glyph, wrong position indicators
              ...List.generate(result.correctGlyph, (_) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SpaceTheme.starYellow, width: 2),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessDialog(int totalScore, int efficiencyBonus) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radio, size: 64, color: SpaceTheme.alienGreen),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.signalTriangulationWinTitle,
                    style: SpaceTheme.headlineStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context)!.signalTriangulationWinDesc(
                      previousGuesses.length,
                      totalScore,
                      efficiencyBonus,
                    ),
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
                          _resetGame();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(S.of(context)!.nextSignal),
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

  Widget _buildFailureDialog() {
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
            const Icon(Icons.signal_wifi_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.signalTriangulationLoseTitle,
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.signalTriangulationLoseDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.signalTriangulationReveal(
                secretSequence.map((g) => g.displayName).join(' - ')
              ),
              style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.alienGreen),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetGame();
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
                  child: Text(S.of(context)!.toTheBridge),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      gameActive = true;
      hasWon = false;
      previousGuesses.clear();
      currentGuess = List.filled(sequenceLength, SignalGlyph.empty);
      currentPosition = 0;
      particles.clear();
    });
    
    _generateSecretSequence();
    _successController.reset();
    _feedbackController.reset();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _successController.dispose();
    _feedbackController.dispose();
    _glyphController.dispose();
    super.dispose();
  }
}

// Data Models
class SignalGlyph {
  final String name;
  final String displayName;
  final IconData? icon;
  final Color? color;
  
  const SignalGlyph({
    required this.name,
    required this.displayName,
    this.icon,
    this.color,
  });
  
  static const empty = SignalGlyph(name: 'empty', displayName: '???');
  
  static const alpha = SignalGlyph(
    name: 'alpha', displayName: 'Alpha',  
    icon: Icons.hexagon_outlined, color: Colors.red, 
  );
  static const beta = SignalGlyph(
    name: 'beta', displayName: 'Beta',
    icon: Icons.blur_circular, color: Colors.blue,
  );
  static const gamma = SignalGlyph(
    name: 'gamma', displayName: 'Gamma',
    icon: Icons.grain, color: Colors.green,
  );
  static const delta = SignalGlyph(
    name: 'delta', displayName: 'Delta',
    icon: Icons.change_history, color: Colors.orange,
  );
  static const epsilon = SignalGlyph(
    name: 'epsilon', displayName: 'Epsilon',
    icon: Icons.electric_bolt, color: Colors.yellow,
  );
  static const zeta = SignalGlyph(
    name: 'zeta', displayName: 'Zeta',
    icon: Icons.waves, color: Colors.purple,
  );
  static const eta = SignalGlyph(
    name: 'eta', displayName: 'Eta',
    icon: Icons.star, color: Colors.cyan,
  );
  static const theta = SignalGlyph(
    name: 'theta', displayName: 'Theta',
    icon: Icons.circle_outlined, color: Colors.teal,
  );
  
  static List<SignalGlyph> getBasicGlyphs() => [alpha, beta, gamma, delta, epsilon];
  
  static List<SignalGlyph> getIntermediateGlyphs() => [alpha, beta, gamma, delta, epsilon, zeta];
  
  static List<SignalGlyph> getAdvancedGlyphs() => [alpha, beta, gamma, delta, epsilon, zeta, eta];
  
  static List<SignalGlyph> getAllGlyphs() => [alpha, beta, gamma, delta, epsilon, zeta, eta, theta];
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignalGlyph &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class GuessResult {
  final List<SignalGlyph> guess;
  final int correctPosition;
  final int correctGlyph;
  
  GuessResult({
    required this.guess,
    required this.correctPosition,
    required this.correctGlyph,
  });
}

// Visual Effects
class SignalParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  SignalParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory SignalParticle.success(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 50 + random.nextDouble() * 100;
    return SignalParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.green,
      size: 3 + random.nextDouble() * 3,
      opacity: 1.0,
      life: 0.8 + random.nextDouble() * 0.4,
    );
  }

  factory SignalParticle.warning(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 40 + random.nextDouble() * 80;
    return SignalParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.orange,
      size: 2 + random.nextDouble() * 2,
      opacity: 1.0,
      life: 0.6 + random.nextDouble() * 0.3,
    );
  }

  factory SignalParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 100 + random.nextDouble() * 200;
    return SignalParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.cyan, Colors.green, Colors.yellow][random.nextInt(3)],
      size: 4 + random.nextDouble() * 4,
      opacity: 1.0,
      life: 1.0 + random.nextDouble() * 0.5,
    );
  }

  factory SignalParticle.failure(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 30 + random.nextDouble() * 70;
    return SignalParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.red,
      size: 2 + random.nextDouble() * 3,
      opacity: 1.0,
      life: 0.5 + random.nextDouble() * 0.3,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.95; // Damping
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

// Custom Painters
class SignalBackgroundPainter extends CustomPainter {
  final double pulseIntensity;
  final double scanProgress;
  final bool gameWon;

  SignalBackgroundPainter({
    required this.pulseIntensity,
    required this.scanProgress,
    required this.gameWon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw radar-like scanning effect
    final scanPaint = Paint()
      ..color = (gameWon ? Colors.green : Colors.cyan).withOpacity(0.1 * pulseIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Concentric circles
    for (double r = 50; r < size.width; r += 80) {
      canvas.drawCircle(center, r, scanPaint);
    }
    
    // Scanning line
    final scanAngle = scanProgress * 2 * math.pi;
    final scanRadius = size.width;
    final scanEnd = center + Offset.fromDirection(scanAngle, scanRadius);
    
    final scanLinePaint = Paint()
      ..color = (gameWon ? Colors.green : Colors.cyan).withOpacity(0.3 * pulseIntensity)
      ..strokeWidth = 3;
    
    canvas.drawLine(center, scanEnd, scanLinePaint);
    
    // Central hub
    final hubPaint = Paint()
      ..color = (gameWon ? Colors.green : Colors.cyan).withOpacity(0.5 * pulseIntensity);
    
    canvas.drawCircle(center, 8, hubPaint);
  }

  @override
  bool shouldRepaint(SignalBackgroundPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.gameWon != gameWon;
}