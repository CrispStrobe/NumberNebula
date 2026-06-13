import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';

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
  late AnimationController _headerController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _glyphAnimation;
  late Animation<double> _headerAnimation;

  // Game State
  late List<SignalGlyph> secretSequence;
  late List<SignalGlyph> currentGuess;
  late List<GuessResult> previousGuesses;
  late int maxGuesses;
  late int sequenceLength;
  bool gameActive = true;
  bool hasWon = false;
  int currentPosition = 0;
  
  // UI State
  bool showHeader = true;
  Timer? _headerTimer;
  
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
    
    // Start header timer after a brief delay to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startHeaderTimer();
      }
    });
    
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
    _glyphController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glyphAnimation = CurvedAnimation(
        parent: _glyphController, curve: Curves.elasticOut);

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
        parent: _headerController, curve: Curves.easeInOut);
  }

  void _startHeaderTimer() {
    _headerController.forward();
    _headerTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && gameActive) {
        _headerController.reverse().then((_) {
          setState(() => showHeader = false);
        });
      }
    });
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
    // final sriService = context.read<SriService>();
    final isCorrect = result.correctPosition == sequenceLength;
    
    /* Create a simple problem for SRI tracking
    final problem = MathProblem(
      operandA: previousGuesses.length,
      operandB: maxGuesses,           
      operation: MathOperation.addition, // enum value
      answer: isCorrect ? 1 : 0,
      expression: 'Signal Triangulation Attempt ${previousGuesses.length}',
      difficulty: widget.grade,       // required parameter
    );
    sriService.recordResponse(problem, isCorrect); */

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

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'signal_triangulation',
      difficulty: widget.grade + (widget.level ~/ 5),
      score: totalScore,
    ));
    
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

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'signal_triangulation',
      difficulty: widget.grade + (widget.level ~/ 5),
    ));

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 700;
    
    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace, // Ensure no white background flash
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: SpaceTheme.deepSpace, // Double ensure background color
        child: SpaceBackground(
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
                
                // Always visible minimal header (when full header is hidden)
                if (!showHeader)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            SpaceTheme.deepSpace.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${previousGuesses.length}/$maxGuesses',
                              style: const TextStyle(color: SpaceTheme.alienGreen, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Full header (shows for 12 seconds)
                if (showHeader)
                  AnimatedBuilder(
                    animation: _headerAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -100 * (1 - _headerAnimation.value)),
                        child: Opacity(
                          opacity: _headerAnimation.value * 0.9,
                          child: _buildCompactHeader(),
                        ),
                      );
                    },
                  ),
                
                // Main game content with two-column layout
                Positioned(
                  top: showHeader ? 80 : 55,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: isWideScreen ? _buildTwoColumnLayout() : _buildMobileLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpaceTheme.deepSpace.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.6),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),
          
          // Compact instructions in header
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
              ),
              child: Text(
                S.of(context)!.signalTriangulationInstructions,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 10, color: Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          _buildCompactStat(Icons.adjust, sequenceLength.toString(), SpaceTheme.starYellow),
          const SizedBox(width: 8),
          _buildCompactStat(Icons.radio, '${previousGuesses.length}/$maxGuesses', SpaceTheme.alienGreen),
          const SizedBox(width: 8),
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return _buildCompactStat(Icons.star, gameProvider.score.toString(), SpaceTheme.cosmicPink);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTwoColumnLayout() {
    return Row(
      children: [
        // Left column - Game controls (NO SCROLLING, NO INSTRUCTIONS)
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Current guess - compact
                _buildCurrentGuess(),
                const SizedBox(height: 8),
                
                // Glyph selector - only takes needed space
                _buildGlyphSelector(),
                
                // Spacer to push content to top
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // Right column - Previous guesses
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: SpaceTheme.cardDecoration,
            child: Column(
              children: [
                Text(
                  S.of(context)!.signalTriangulationPreviousAttempts,
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildPreviousGuessesScrollable(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildCurrentGuess(),
          const SizedBox(height: 8),
          _buildGlyphSelector(),
          const SizedBox(height: 8),
          _buildPreviousGuesses(),
        ],
      ),
    );
  }

  Widget _buildCurrentGuess() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.signalTriangulationCurrentSequence,
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.alienGreen, fontSize: 16),
          ),
          const SizedBox(height: 12),
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
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glyph.color,
                        border: Border.all(
                          color: isActive ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                          width: isActive ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (glyph.color ?? Colors.transparent).withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: isActive ? 2 : 1,
                          ),
                        ],
                      ),
                      child: glyph.icon != null ?
                          Icon(glyph.icon, color: Colors.white, size: 22) :
                          (isActive ? const Icon(Icons.radio_button_unchecked, 
                              color: SpaceTheme.starYellow, size: 18) : null),
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          if (gameActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: currentPosition > 0 ? _clearGuess : null,
                  style: SpaceTheme.secondaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  ),
                  child: Text(S.of(context)!.signalTriangulationClear, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: currentPosition >= sequenceLength ? _submitGuess : null,
                  style: SpaceTheme.primaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                  ),
                  child: Text(S.of(context)!.signalTriangulationTransmit, style: const TextStyle(fontSize: 12)),
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
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.of(context)!.signalTriangulationFrequencies,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: availableGlyphs.map((glyph) {
                return Semantics(
                  label: 'Glyph ${glyph.name}',
                  button: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _selectGlyph(glyph),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: glyph.color,
                                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: glyph.color!.withValues(alpha: _pulseAnimation.value * 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(glyph.icon, color: Colors.white, size: 18),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousGuessesScrollable() {
    if (previousGuesses.isEmpty) {
      return Center(
        child: Text(
          S.of(context)!.signalNoAttemptsYet,
          style: SpaceTheme.bodyStyle.copyWith(color: Colors.white60),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: previousGuesses.length,
      reverse: true,
      itemBuilder: (context, index) {
        return _buildGuessResult(previousGuesses[previousGuesses.length - 1 - index]);
      },
    );
  }

  Widget _buildPreviousGuesses() {
    if (previousGuesses.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        children: [
          Text(
            S.of(context)!.signalTriangulationPreviousAttempts,
            style: SpaceTheme.titleStyle,
          ),
          const SizedBox(height: 16),
          Column(
            children: previousGuesses.reversed.take(5).map((result) => _buildGuessResult(result)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuessResult(GuessResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Guess sequence
          Expanded(
            child: Row(
              children: result.guess.map((glyph) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glyph.color,
                  border: Border.all(color: Colors.white30),
                ),
                child: Icon(glyph.icon, color: Colors.white, size: 12),
              )).toList(),
            ),
          ),
          
          // Feedback
          Row(
            children: [
              // Correct position indicators
              Row(
                children: List.generate(result.correctPosition, (_) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpaceTheme.alienGreen,
                  ),
                )),
              ),
              // Correct glyph, wrong position indicators
              Row(
                children: List.generate(result.correctGlyph, (_) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: SpaceTheme.starYellow, width: 2),
                  ),
                )),
              ),
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              padding: const EdgeInsets.all(20),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radio, size: 48, color: SpaceTheme.alienGreen),
                    const SizedBox(height: 12),
                    Text(
                      S.of(context)!.signalTriangulationWinTitle,
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.of(context)!.signalTriangulationWinDesc(
                        previousGuesses.length,
                        totalScore,
                        efficiencyBonus,
                      ),
                      style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _resetGame();
                            },
                            style: SpaceTheme.secondaryButtonStyle,
                            child: Text(S.of(context)!.nextSignal, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: SpaceTheme.primaryButtonStyle,
                            child: Text(S.of(context)!.toTheBridge, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.signal_wifi_off, size: 48, color: SpaceTheme.rocketRed),
              const SizedBox(height: 12),
              Text(
                S.of(context)!.signalTriangulationLoseTitle,
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context)!.signalTriangulationLoseDesc,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context)!.signalTriangulationReveal(
                  secretSequence.map((g) => g.displayName).join(' - ')
                ),
                style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.alienGreen, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                      },
                      style: SpaceTheme.secondaryButtonStyle,
                      child: Text(S.of(context)!.tryAgain, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: SpaceTheme.primaryButtonStyle,
                      child: Text(S.of(context)!.toTheBridge, style: const TextStyle(fontSize: 12)),
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

  void _resetGame() {
    setState(() {
      gameActive = true;
      hasWon = false;
      previousGuesses.clear();
      currentGuess = List.filled(sequenceLength, SignalGlyph.empty);
      currentPosition = 0;
      particles.clear();
      showHeader = true;
    });
    
    _generateSecretSequence();
    _successController.reset();
    _feedbackController.reset();
    _headerController.forward();
    _startHeaderTimer();
  }

  @override
  void dispose() {
    _headerTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _successController.dispose();
    _feedbackController.dispose();
    _glyphController.dispose();
    _headerController.dispose();
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
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.5),
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
      ..color = (gameWon ? Colors.green : Colors.cyan).withValues(alpha: 0.1 * pulseIntensity)
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
      ..color = (gameWon ? Colors.green : Colors.cyan).withValues(alpha: 0.3 * pulseIntensity)
      ..strokeWidth = 3;
    
    canvas.drawLine(center, scanEnd, scanLinePaint);
    
    // Central hub
    final hubPaint = Paint()
      ..color = (gameWon ? Colors.green : Colors.cyan).withValues(alpha: 0.5 * pulseIntensity);
    
    canvas.drawCircle(center, 8, hubPaint);
  }

  @override
  bool shouldRepaint(SignalBackgroundPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.gameWon != gameWon;
}