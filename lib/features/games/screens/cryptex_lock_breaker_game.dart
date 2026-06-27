import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../constants/app_constants.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import 'package:flutter/foundation.dart';

class CryptexLockBreakerGame extends StatefulWidget {
  final int grade;
  final int level;

  const CryptexLockBreakerGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<CryptexLockBreakerGame> createState() => _CryptexLockBreakerGameState();
}

class _CryptexLockBreakerGameState extends State<CryptexLockBreakerGame>
    with TickerProviderStateMixin, GameAnimationsMixin<CryptexLockBreakerGame> {
  late AnimationController _rotationController;
  late AnimationController _unlockController;
  late AnimationController _particleController;
  late AnimationController _dialController;
  late AnimationController _equationController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _unlockAnimation;
  late Animation<double> _dialAnimation;
  late Animation<double> _equationAnimation;

  // Game State
  late CryptexPuzzle currentPuzzle;
  late List<int> dialValues;
  bool gameActive = true;
  bool isUnlocked = false;
  int selectedDial = -1;
  
  // Visual Effects
  List<CryptexParticle> particles = [];
  double unlockProgress = 0.0;
  
  // Interaction
  bool isDragging = false;
  double dragStartY = 0.0;
  int dragStartValue = 0;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false, useSuccess: false);
    if (kDebugMode) debugPrint("🔐 [CryptexLockBreaker] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _generatePuzzle();
  }

  void _setupAnimationControllers() {
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi)
        .animate(CurvedAnimation(parent: _rotationController, curve: Curves.linear));

    _unlockAnimation = CurvedAnimation(
        parent: _unlockController, curve: Curves.easeOut);

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )
      ..addListener(_updateParticles)
      ..repeat();

    _dialController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _dialAnimation = CurvedAnimation(
        parent: _dialController, curve: Curves.elasticOut);

    _equationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _equationAnimation = CurvedAnimation(
        parent: _equationController, curve: Curves.easeOut);
  }

  void _generatePuzzle() {
    if (kDebugMode) debugPrint("🔐 [CryptexLockBreaker] Generating new puzzle");
    
    setState(() {
      currentPuzzle = CryptexPuzzle.generate(widget.grade, widget.level);
      dialValues = List.from(currentPuzzle.initialValues);
      gameActive = true;
      isUnlocked = false;
      selectedDial = -1;
    });
    
    if (kDebugMode) debugPrint("🔐 [CryptexLockBreaker] Puzzle generated:");
    debugPrint("🔐 [CryptexLockBreaker] Solution: ${currentPuzzle.solution}");
    debugPrint("🔐 [CryptexLockBreaker] Initial: ${currentPuzzle.initialValues}");
    for (final eq in currentPuzzle.equations) {
      if (kDebugMode) debugPrint("🔐 [CryptexLockBreaker] Equation: ${eq.toString()}");
    }
  }

  void _onPanStart(DragStartDetails details, int dialIndex) {
    if (!gameActive || isUnlocked) return;
    
    setState(() {
      isDragging = true;
      selectedDial = dialIndex;
      dragStartY = details.globalPosition.dy;
      dragStartValue = dialValues[dialIndex];
    });
  }

  void _onPanUpdate(DragUpdateDetails details, int dialIndex) {
    if (!isDragging || !gameActive || isUnlocked) return;
    
    final deltaY = details.globalPosition.dy - dragStartY;
    final steps = (-deltaY / 20).round(); // 20 pixels per step
    
    final newValue = (dragStartValue + steps) % 10;
    
    if (newValue != dialValues[dialIndex]) {
      HapticFeedback.selectionClick();
      setState(() {
        dialValues[dialIndex] = newValue < 0 ? newValue + 10 : newValue;
      });
      _checkSolution();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      isDragging = false;
      selectedDial = -1;
    });
  }

  void _checkSolution() {
    final allSatisfied = currentPuzzle.equations.every((eq) => eq.isSatisfied(dialValues));
    
    if (allSatisfied && !isUnlocked) {
      if (kDebugMode) debugPrint("🎉 [CryptexLockBreaker] All equations satisfied! Unlocking...");
      _handleSuccess();
    } else {
      // Add feedback particles for partially correct solutions
      final satisfiedCount = currentPuzzle.equations.where((eq) => eq.isSatisfied(dialValues)).length;
      if (satisfiedCount > 0) {
        _addProgressParticles(satisfiedCount);
      }
    }
    
    // Trigger equation highlight animation
    _equationController.forward(from: 0.0);
  }

  void _handleSuccess() {
    setState(() {
      isUnlocked = true;
      gameActive = false;
    });

    _unlockController.forward();
    HapticFeedback.heavyImpact();

    // 1. Convert the solved puzzle equations into a list of trackable MathProblem objects.
    //    This uses a new helper method on the CryptexEquation class (defined below).
    final List<MathProblem> solvedProblems = currentPuzzle.equations
        .map((eq) => eq.toMathProblem(currentPuzzle.solution))
        .toList();

    // 2. Calculate score
    final baseScore = 250 * widget.grade;
    final complexityBonus = (currentPuzzle.dialCount - 2) * 100;
    final equationBonus = currentPuzzle.equations.length * 50;
    final totalScore = baseScore + complexityBonus + equationBonus;

    // 3. Make a SINGLE, UNIFIED call to the GameProvider to record the win.
    //    This centralizes progress tracking and dispatches data to both the
    //    SRI and Cognitive Profile services automatically.
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'cryptex_lock_breaker',
      difficulty: widget.grade + (widget.level ~/ 5),
      score: totalScore,
      mathProblems: solvedProblems,
    ));

    // --- END: MODIFIED LOGIC ---

    // Add celebration particles
    for (int i = 0; i < 80; i++) {
      particles.add(CryptexParticle.celebration(
        MediaQuery.of(context).size.center(Offset.zero),
      ));
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, complexityBonus, equationBonus),
        );
      }
    });
  }

  /// Records the level as failed. Pass [showDialogOnFail] = false when the
  /// user is navigating away (back-press) so we don't block their exit.
  void _handleFailure({bool showDialogOnFail = true}) {
    if (!gameActive) return; // Prevent multiple calls

    setState(() {
      gameActive = false;
    });

    HapticFeedback.vibrate();

    // Convert the puzzle equations into MathProblem objects to let the SRI
    // system know which concepts the player struggled with on this attempt.
    final List<MathProblem> attemptedProblems = currentPuzzle.equations
        .map((eq) => eq.toMathProblem(currentPuzzle.solution))
        .toList();

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'cryptex_lock_breaker',
      difficulty: widget.grade + (widget.level ~/ 5),
      mathProblems: attemptedProblems,
    ));

    if (showDialogOnFail && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildFailureDialog(),
      );
    }
  }

  /// Called when the player taps the back button. If the puzzle is still
  /// active, treat the exit as an abandonment so the failure is recorded —
  /// without this hook the game has no fail path at all and the mastery
  /// gate (3 wins + difficulty signal) gets only wins.
  void _onBackPressed() {
    if (gameActive) {
      _handleFailure(showDialogOnFail: false);
    }
    Navigator.of(context).pop();
  }

  Widget _buildFailureDialog() {
    final s = S.of(context)!;
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.lock, size: 32, color: SpaceTheme.rocketRed),
          const SizedBox(width: 12),
          Text(s.gameOver, style: SpaceTheme.headlineStyle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Solution: ${currentPuzzle.solution.join("  ")}',
            style: SpaceTheme.bodyStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: Text(s.backToMenu,
              style: const TextStyle(color: SpaceTheme.starYellow)),
        ),
        TextButton(
          autofocus: true,
          onPressed: () {
            Navigator.of(context).pop();
            _generatePuzzle();
          },
          child: Text(s.tryAgain,
              style: const TextStyle(color: SpaceTheme.alienGreen)),
        ),
      ],
    );
  }

  void _addProgressParticles(int satisfiedCount) {
    final random = math.Random();
    final screenSize = MediaQuery.of(context).size;
    final center = screenSize.center(Offset.zero);
    
    for (int i = 0; i < satisfiedCount * 3; i++) {
      particles.add(CryptexParticle.progress(
        center + Offset(
          (random.nextDouble() - 0.5) * 150,
          (random.nextDouble() - 0.5) * 150,
        ),
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    
    setState(() {
      particles.removeWhere((p) => p.update(0.016));
    });
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: LayoutBuilder( // Use LayoutBuilder to get screen constraints
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 450;

              return Stack(
                children: [
                  // ... (The existing Positioned.fill and particles code remains the same)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rotationController, glowController, _unlockController]),
                      builder: (context, child) {
                        return CustomPaint(
                          painter: CryptexBackgroundPainter(
                            rotationAngle: _rotationAnimation.value,
                            glowIntensity: glowAnimation.value,
                            unlockProgress: _unlockAnimation.value,
                            isUnlocked: isUnlocked,
                          ),
                        );
                      },
                    ),
                  ),
                  ...particles.map((p) => p.build()),
                  
                  // Main game UI column
                  Column(
                    children: [
                      // The new adaptive header handles instructions on small screens
                      _buildAdaptiveHeader(isCompact: isCompact),
                      
                      // The Cryptex visual now expands to fill available space
                      Expanded(
                        flex: 5, // Give the most space to the cryptex
                        child: _buildCryptexVisual(),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Equations display
                      _buildEquationsDisplay(),

                      // Draggable digit palette
                      _buildNumberPalette(),

                      const Spacer(flex: 1), // Use a Spacer for flexible padding
                      
                      // Controls hint
                      if (gameActive && !isUnlocked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            S.of(context)!.cryptexLockBreakerControls,
                            style: SpaceTheme.bodyStyle.copyWith(
                              color: Colors.white60,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveHeader({required bool isCompact}) {
    // For large screens, use the original layout.
    if (!isCompact) {
      return Column(
        children: [
          GameUI(
            title: S.of(context)!.cryptexLockBreakerGameTitle,
            level: widget.level,
            onBack: _onBackPressed,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              S.of(context)!.cryptexLockBreakerInstructions,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    
    // For compact screens, build a condensed header with instructions inside.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          // Use the existing GameUI for the back button and title for consistency.
          Expanded(
            child: GameUI(
              title: S.of(context)!.cryptexLockBreakerGameTitle,
              level: widget.level,
              onBack: _onBackPressed,
              // Pass a custom child to insert the instructions text
              customTitleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      S.of(context)!.cryptexLockBreakerGameTitle,
                      style: SpaceTheme.headlineStyle,
                    ),
                  ),
                  Text(
                    S.of(context)!.cryptexLockBreakerInstructions, // Use the now-shortened text
                    style: SpaceTheme.bodyStyle.copyWith(color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCryptexVisual() {
    return Container(
      // REMOVED: height: 220, to allow this widget to be flexible.
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cryptex body
          AnimatedBuilder(
            animation: _unlockAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(400, 160),
                painter: CryptexBodyPainter(
                  isUnlocked: isUnlocked,
                  unlockProgress: _unlockAnimation.value,
                ),
              );
            },
          ),
          
          // Dials
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(currentPuzzle.dialCount, _buildDial),
          ),
        ],
      ),
    );
  }

  Widget _buildDial(int dialIndex) {
    final isSelected = selectedDial == dialIndex;
    final dialValue = dialValues[dialIndex];
    final dialLabel = String.fromCharCode(65 + dialIndex);

    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => gameActive && !isUnlocked,
      onAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        setState(() {
          dialValues[dialIndex] = details.data;
          selectedDial = dialIndex;
        });
        _checkSolution();
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Semantics(
      label: S.of(context)!.a11yDial(dialLabel, dialValue),
      hint: S.of(context)!.a11yDialHint,
      value: dialValue.toString(),
      button: true,
      selected: isSelected || isDropTarget,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) => _onPanStart(details, dialIndex),
        onPanUpdate: (details) => _onPanUpdate(details, dialIndex),
        onPanEnd: _onPanEnd,
        onTap: () => setState(() => selectedDial = dialIndex),
        child: AnimatedBuilder(
          animation: _dialAnimation,
          builder: (context, child) {
            final scale = isSelected ? (1.0 + _dialAnimation.value * 0.15) : 1.0;

            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 120,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dial background
                    Container(
                      width: 120,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [SpaceTheme.starYellow.withValues(alpha: 0.3), SpaceTheme.planetOrange.withValues(alpha: 0.3)]
                              : [SpaceTheme.nebulaPurple.withValues(alpha: 0.3), SpaceTheme.deepSpace.withValues(alpha: 0.5)],
                        ),
                        border: Border.all(
                          color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen).withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),

                    // Dial markings and numbers
                    CustomPaint(
                      size: const Size(120, 180),
                      painter: DialPainter(
                        currentValue: dialValue,
                        isSelected: isSelected,
                        dialIndex: dialIndex,
                      ),
                    ),

                    // Dial label
                    Positioned(
                      bottom: 12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          dialLabel, // A, B, C, etc.
                          style: SpaceTheme.titleStyle.copyWith(
                            color: isSelected ? SpaceTheme.starYellow : SpaceTheme.alienGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
      },
    );
  }

  Widget _buildNumberPalette() {
    if (!gameActive || isUnlocked) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: List.generate(10, (digit) {
          return Draggable<int>(
            data: digit,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '$digit',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 18,
                    color: SpaceTheme.deepSpace,
                  ),
                ),
              ),
            ),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$digit',
                style: SpaceTheme.titleStyle.copyWith(
                  fontSize: 15,
                  color: SpaceTheme.alienGreen,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEquationsDisplay() {
    final equations = currentPuzzle.equations;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.cryptexLockBreakerEquations,
            style: SpaceTheme.titleStyle.copyWith(
              color: SpaceTheme.nebulaPurple,
            ),
          ),
          const SizedBox(height: 8),
          // Two-column layout
          Column(
            children: [
              for (int i = 0; i < equations.length; i += 2)
                Row(
                  children: [
                    Expanded(child: _buildEquationRow(equations[i])),
                    if (i + 1 < equations.length) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _buildEquationRow(equations[i + 1])),
                    ] else
                      const Expanded(child: SizedBox()),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquationRow(CryptexEquation equation) {
    final isSatisfied = equation.isSatisfied(dialValues);
    
    return AnimatedBuilder(
      animation: _equationAnimation,
      builder: (context, child) {
        final highlightIntensity = isSatisfied ? _equationAnimation.value : 0.0;
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSatisfied 
                ? SpaceTheme.alienGreen.withValues(alpha: 0.2 * highlightIntensity)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSatisfied ? SpaceTheme.alienGreen : Colors.white30,
              width: isSatisfied ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Equation
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${equation.getLeftSideDisplay().replaceAll('/', context.read<GameProvider>().divisionSymbol).replaceAll('*', context.read<GameProvider>().multiplicationSymbol)} = ${equation.getRightSideDisplay()}',
                    style: SpaceTheme.bodyStyle.copyWith(
                      color: isSatisfied ? SpaceTheme.alienGreen : Colors.white,
                      fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              
              // Status indicator
              Icon(
                isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSatisfied ? SpaceTheme.alienGreen : Colors.white30,
                size: 16,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessDialog(int totalScore, int complexityBonus, int equationBonus) {
    return AnimatedBuilder(
      animation: _unlockAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _unlockAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20), // Slightly reduced padding
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              // FIX: Wrap the Column in a SingleChildScrollView to prevent overflow
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Slightly smaller icon to save space
                    const Icon(Icons.lock_open, size: 56, color: SpaceTheme.alienGreen),
                    const SizedBox(height: 12), // Reduced spacing
                    Text(
                      S.of(context)!.cryptexLockBreakerWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12), // Reduced spacing
                    Text(
                      S.of(context)!.cryptexLockBreakerWinDesc(
                        totalScore,
                        complexityBonus,
                        equationBonus,
                      ),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20), // Reduced spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Wrap buttons in Flexible to handle long text
                        Flexible(
                          child: ElevatedButton(
                            autofocus: true,
                            onPressed: () {
                              Navigator.of(context).pop();
                              _resetGame();
                            },
                            style: SpaceTheme.secondaryButtonStyle,
                            child: Text(S.of(context)!.nextCryptex, textAlign: TextAlign.center),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: SpaceTheme.primaryButtonStyle,
                            child: Text(S.of(context)!.toTheBridge, textAlign: TextAlign.center),
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

  void _resetGame() {
    setState(() {
      particles.clear();
      isUnlocked = false;
    });
    
    _unlockController.reset();
    _generatePuzzle();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _unlockController.dispose();
    _particleController.dispose();
    _dialController.dispose();
    _equationController.dispose();
    disposeGameAnimations(usePulse: false, useSuccess: false);
    super.dispose();
  }
}

// Data Models
class CryptexPuzzle {
  final int dialCount;
  final List<CryptexEquation> equations;
  final List<int> solution;
  final List<int> initialValues;

  CryptexPuzzle({
    required this.dialCount,
    required this.equations,
    required this.solution,
    required this.initialValues,
  });

  static CryptexPuzzle generate(int grade, int level) {
    final complexity = grade + (level / 5.0);
    int dialCount;
    List<String> operators;
    
    if (complexity <= 2.0) {
      dialCount = 3;
      operators = ['+', '-'];
    } else if (complexity <= 3.5) {
      dialCount = math.Random().nextBool() ? 3 : 4;
      operators = ['+', '-', '*'];
    } else if (complexity <= 5.0) {
      dialCount = 4;
      operators = ['+', '-', '*', '/'];
    } else {
      dialCount = math.Random().nextBool() ? 4 : 5;
      operators = ['+', '-', '*', '/'];
    }
    
    return _generateSolvablePuzzle(dialCount, operators, grade);
  }

  static CryptexPuzzle _generateSolvablePuzzle(int dialCount, List<String> operators, int grade) {
    final random = math.Random();
    
    // Generate solution values (1-9 to avoid 0 complications)
    final solution = List.generate(dialCount, (_) => random.nextInt(9) + 1);
    
    // Generate equations that work with the solution
    final equations = <CryptexEquation>[];
    
    // Simple two-dial equations first
    for (int i = 0; i < dialCount - 1; i++) {
      final op = operators[random.nextInt(operators.length)];
      int result;
      
      switch (op) {
        case '+':
          result = solution[i] + solution[i + 1];
          break;
        case '-':
          result = (solution[i] - solution[i + 1]).abs();
          break;
        case '*':
          result = solution[i] * solution[i + 1];
          break;
        case '/':
          // Ensure clean division
          if (solution[i + 1] != 0 && solution[i] % solution[i + 1] == 0) {
            result = solution[i] ~/ solution[i + 1];
          } else {
            result = solution[i] + solution[i + 1]; // Fallback to addition
          }
          break;
        default:
          result = solution[i] + solution[i + 1];
      }
      
      equations.add(CryptexEquation(
        leftOperandIndices: [i, i + 1],
        operator: op == '/' && (solution[i + 1] == 0 || solution[i] % solution[i + 1] != 0) ? '+' : op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }
    
    // Add one more complex equation if we have enough dials
    if (dialCount >= 4) {
      final indices = [0, dialCount - 1];
      final op = ['+', '*'][random.nextInt(2)]; // Simpler operations for complex equations
      final result = op == '+' ? solution[0] + solution[dialCount - 1] : solution[0] * solution[dialCount - 1];
      
      equations.add(CryptexEquation(
        leftOperandIndices: indices,
        operator: op,
        rightSide: result,
        resultDialIndex: null,
      ));
    }
    
    // Generate initial values (different from solution)
    final initialValues = List.generate(dialCount, (i) {
      int value;
      do {
        value = random.nextInt(10);
      } while (value == solution[i]);
      return value;
    });
    
    return CryptexPuzzle(
      dialCount: dialCount,
      equations: equations,
      solution: solution,
      initialValues: initialValues,
    );
  }
}

class CryptexEquation {
  final List<int> leftOperandIndices;
  final String operator;
  final int rightSide;
  final int? resultDialIndex; // null if right side is constant

  CryptexEquation({
    required this.leftOperandIndices,
    required this.operator,
    required this.rightSide,
    this.resultDialIndex,
  });

  bool isSatisfied(List<int> dialValues) {
    final leftResult = _calculateLeftSide(dialValues);
    final rightResult = resultDialIndex != null ? dialValues[resultDialIndex!] : rightSide;
    return leftResult == rightResult;
  }

  int getCurrentResult(List<int> dialValues) {
    return _calculateLeftSide(dialValues);
  }

  /// Converts this equation into a standard MathProblem object using the puzzle's solution.
  /// This allows the SRI service to track the underlying math fact mastery.
  MathProblem toMathProblem(List<int> solutionValues) {
    // Ensure we have enough operands to create a valid problem
    if (leftOperandIndices.length < 2) {
      // Return a dummy problem if the equation is malformed
      return MathProblem(
        operandA: 0, operandB: 0, operation: MathOperation.addition, answer: 0, expression: 'error', difficulty: 1
      );
    }

    final opA = solutionValues[leftOperandIndices[0]];
    final opB = solutionValues[leftOperandIndices[1]];

    MathOperation op;
    switch (operator) {
      case '+': op = MathOperation.addition; break;
      case '-': op = MathOperation.subtraction; break;
      case '*': op = MathOperation.multiplication; break;
      case '/': op = MathOperation.division; break;
      default:  op = MathOperation.addition;
    }

    return MathProblem(
      operandA: opA,
      operandB: opB,
      operation: op,
      answer: rightSide, // The equation's result is the problem's answer
      expression: '$opA $operator $opB',
      // The difficulty can be based on the operator or number size
      difficulty: (operator == '*' || operator == '/') ? 3 : 1,
    );
  }

  int _calculateLeftSide(List<int> dialValues) {
    if (leftOperandIndices.length < 2) return 0;
    
    final a = dialValues[leftOperandIndices[0]];
    final b = dialValues[leftOperandIndices[1]];
    
    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return (a - b).abs();
      case '*':
        return a * b;
      case '/':
        return b != 0 ? (a ~/ b) : 0;
      default:
        return a + b;
    }
  }

  String getLeftSideDisplay() {
    final dialLabels = leftOperandIndices.map((i) => String.fromCharCode(65 + i)).toList();
    if (dialLabels.length >= 2) {
      return '${dialLabels[0]} $operator ${dialLabels[1]}';
    }
    return dialLabels.isNotEmpty ? dialLabels[0] : '?';
  }

  String getRightSideDisplay() {
    return resultDialIndex != null 
        ? String.fromCharCode(65 + resultDialIndex!)
        : rightSide.toString();
  }

  @override
  String toString() {
    return '${getLeftSideDisplay()} = ${getRightSideDisplay()}';
  }
}

// Visual Effects
class CryptexParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  CryptexParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory CryptexParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 80 + random.nextDouble() * 120;
    return CryptexParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.amber, Colors.cyan, Colors.green][random.nextInt(3)],
      size: 3 + random.nextDouble() * 4,
      opacity: 1.0,
      life: 1.2 + random.nextDouble() * 0.8,
    );
  }

  factory CryptexParticle.progress(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 30 + random.nextDouble() * 60;
    return CryptexParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.orange,
      size: 2 + random.nextDouble() * 2,
      opacity: 0.8,
      life: 0.5 + random.nextDouble() * 0.3,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.98; // Damping
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
              blurRadius: size * 1.5,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painters
class CryptexBackgroundPainter extends CustomPainter {
  final double rotationAngle;
  final double glowIntensity;
  final double unlockProgress;
  final bool isUnlocked;

  CryptexBackgroundPainter({
    required this.rotationAngle,
    required this.glowIntensity,
    required this.unlockProgress,
    required this.isUnlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw rotating mystical symbols
    final symbolPaint = Paint()
      ..color = (isUnlocked ? Colors.green : Colors.cyan).withValues(alpha: 0.1 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Concentric circles with ancient script effect
    for (double r = 100; r < size.width * 0.8; r += 120) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle + r * 0.01);
      
      // Draw symbolic markings around circles
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final pos = Offset.fromDirection(angle, r);
        final endPos = Offset.fromDirection(angle, r + 15);
        canvas.drawLine(pos, endPos, symbolPaint);
      }
      
      canvas.restore();
    }
    
    // Central energy vortex
    final vortexPaint = Paint()
      ..shader = RadialGradient(
        colors: isUnlocked 
            ? [Colors.green.withValues(alpha: 0.5), Colors.transparent]
            : [Colors.cyan.withValues(alpha: 0.3 * glowIntensity), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 150));
    
    canvas.drawCircle(center, 150 * (1.0 + unlockProgress * 0.5), vortexPaint);
  }

  @override
  bool shouldRepaint(CryptexBackgroundPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle ||
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.unlockProgress != unlockProgress ||
      oldDelegate.isUnlocked != isUnlocked;
}

class CryptexBodyPainter extends CustomPainter {
  final bool isUnlocked;
  final double unlockProgress;

  CryptexBodyPainter({required this.isUnlocked, required this.unlockProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyWidth = size.width * 0.8;
    final bodyHeight = size.height * 0.4;
    
    // Main cryptex body
    final bodyRect = Rect.fromCenter(
      center: center,
      width: bodyWidth,
      height: bodyHeight,
    );
    
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.grey.shade800,
          Colors.grey.shade600,
          Colors.grey.shade700,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bodyRect);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(20)),
      bodyPaint,
    );
    
    // Decorative bands
    final bandPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final topBand = bodyRect.top + bodyHeight * 0.2;
    final bottomBand = bodyRect.bottom - bodyHeight * 0.2;
    
    canvas.drawLine(
      Offset(bodyRect.left, topBand),
      Offset(bodyRect.right, topBand),
      bandPaint,
    );
    canvas.drawLine(
      Offset(bodyRect.left, bottomBand),
      Offset(bodyRect.right, bottomBand),
      bandPaint,
    );
    
    // Unlock glow effect
    if (isUnlocked) {
      final glowPaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.5 * unlockProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(20)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CryptexBodyPainter oldDelegate) =>
      oldDelegate.isUnlocked != isUnlocked ||
      oldDelegate.unlockProgress != unlockProgress;
}

class DialPainter extends CustomPainter {
  final int currentValue;
  final bool isSelected;
  final int dialIndex;

  DialPainter({
    required this.currentValue,
    required this.isSelected,
    required this.dialIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw number markings around the dial
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * math.pi / 180; // 36 degrees per number
      final position = center + Offset.fromDirection(angle, radius - 15);
      
      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(
          color: i == currentValue ? Colors.white : Colors.white54,
          fontSize: i == currentValue ? 20 : 16,
          fontWeight: i == currentValue ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      
      textPainter.paint(
        canvas,
        position - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
    
    // Draw pointer/indicator for current value
    final pointerAngle = (currentValue * 36 - 90) * math.pi / 180;
    final pointerStart = center;
    final pointerEnd = center + Offset.fromDirection(pointerAngle, radius - 25);
    
    final pointerPaint = Paint()
      ..color = isSelected ? Colors.yellow : Colors.cyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(pointerStart, pointerEnd, pointerPaint);
    
    // Draw center dot
    canvas.drawCircle(
      center,
      4,
      Paint()..color = isSelected ? Colors.yellow : Colors.cyan,
    );
  }

  @override
  bool shouldRepaint(DialPainter oldDelegate) =>
      oldDelegate.currentValue != currentValue ||
      oldDelegate.isSelected != isSelected;
}