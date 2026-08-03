import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/circuit_repair_logic.dart';

class CircuitRepairGame extends StatefulWidget {
  final int grade;
  final int level;
  const CircuitRepairGame({super.key, required this.grade, required this.level});
  @override
  State<CircuitRepairGame> createState() => _CircuitRepairGameState();
}

class _CircuitRepairGameState extends State<CircuitRepairGame>
    with TickerProviderStateMixin, GameAnimationsMixin<CircuitRepairGame> {
  // -- Animation controllers --
  late AnimationController _swapController;

  CircuitRepairPuzzle? _puzzle;

  /// Index of the first selected digit position (0-3), or null.
  int? _selectedFirst;

  /// Index of the second selected digit position (0-3), or null.
  int? _selectedSecond;

  /// Current digit values shown on the display (may be mid-swap preview).
  List<int> _currentDigits = [];

  bool _isGenerating = true;
  int _attemptsUsed = 0;
  bool _solved = false;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);


    _swapController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    _swapController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _selectedFirst = null;
      _selectedSecond = null;
      _attemptsUsed = 0;
      _solved = false;
      successController.reset();
    });

    final generator =
        CircuitRepairGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _currentDigits = List<int>.from(puzzle.displayedDigits);
      _isGenerating = false;
    });
  }

  void _onDigitTapped(int position) {
    if (_solved || _puzzle == null) return;

    setState(() {
      if (_selectedFirst == position) {
        // Deselect
        _selectedFirst = null;
      } else if (_selectedSecond == position) {
        _selectedSecond = null;
      } else if (_selectedFirst == null) {
        _selectedFirst = position;
      } else if (_selectedSecond == null) {
        _selectedSecond = position;
        // Perform visual swap with animation
        _performSwap();
      } else {
        // Both already selected -- restart selection
        _selectedFirst = position;
        _selectedSecond = null;
        // Revert to original displayed digits
        _currentDigits = List<int>.from(_puzzle!.displayedDigits);
      }
    });
  }

  void _performSwap() {
    if (_selectedFirst == null || _selectedSecond == null || _puzzle == null) return;
    final swapped = _puzzle!.previewSwap(_selectedFirst!, _selectedSecond!);
    _swapController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentDigits = swapped;
        });
      }
    });
  }

  void _submitAnswer() {
    if (_puzzle == null || _selectedFirst == null || _selectedSecond == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.circuitRepairInstructions),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_puzzle!.checkAnswer(_selectedFirst!, _selectedSecond!)) {
      _handleWin();
    } else {
      _handleWrongAnswer();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    setState(() => _solved = true);

    final baseScore = 100 * widget.grade;
    final levelBonus = widget.level * 25;
    final attemptBonus = (_puzzle!.maxAttempts - _attemptsUsed) * 30;
    final totalScore = baseScore + levelBonus + attemptBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'circuit_repair',
      difficulty: widget.level,
      score: totalScore,
      performance:
          Perf.fromAttempts(_attemptsUsed + 1, _puzzle!.maxAttempts),
    ));

    successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore),
    );
  }

  void _handleWrongAnswer() {
    HapticFeedback.heavyImpact();
    _attemptsUsed++;

    if (_attemptsUsed >= _puzzle!.maxAttempts) {
      // Out of attempts
      context.read<GameProvider>().reportOutcome(GameOutcome.loss(
        gameType: 'circuit_repair',
        difficulty: widget.level,
      ));

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildLoseDialog(),
      );
      return;
    }

    // Revert swap: reset to original displayed digits
    setState(() {
      _selectedFirst = null;
      _selectedSecond = null;
      _currentDigits = List<int>.from(_puzzle!.displayedDigits);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                S.of(context)!.circuitInvalidTime(_puzzle!.maxAttempts - _attemptsUsed),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetSelection() {
    if (_solved || _puzzle == null) return;
    setState(() {
      _selectedFirst = null;
      _selectedSecond = null;
      _currentDigits = List<int>.from(_puzzle!.displayedDigits);
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (_puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(s.loadingAdventure, style: SpaceTheme.bodyStyle),
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
                title: s.circuitRepairTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  S.of(context)!.circuitSwapInstruction,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? _buildWideLayout(constraints)
                        : _buildCompactLayout(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          // Size the clock from THIS slot's width, not the full game-area
          // width — otherwise the 7-segment display is computed too wide and
          // overflows into the side panel (badly in iPhone landscape, and by
          // ~44px in iPad portrait).
          child: Center(
            child: LayoutBuilder(
              builder: (context, slot) => _buildClockDisplay(slot),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusPanel(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildClockDisplay(constraints),
          const SizedBox(height: 16),
          _buildStatusPanel(),
          const SizedBox(height: 12),
          _buildActionButtons(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CLOCK DISPLAY with tappable 7-segment digits
  // ---------------------------------------------------------------------------

  Widget _buildClockDisplay(BoxConstraints constraints) {
    final displayWidth = constraints.maxWidth * 0.85;
    // 4 digits + 1 colon = ~4.8 widths. 6 digits + 2 colons = ~7.5 widths.
    final is6Digit = _currentDigits.length == 6;
    final totalWidths = is6Digit ? 7.5 : 4.8;
    final digitWidth = ((displayWidth - 64) / totalWidths).clamp(40.0, is6Digit ? 80.0 : 120.0);
    final digitHeight = (digitWidth * 1.6).clamp(65.0, 200.0);
    final colonWidth = digitWidth * 0.35;

    final isPreview = _selectedFirst != null && _selectedSecond != null;
    final previewValid = isPreview && CircuitRepairPuzzle.isValidTime(_currentDigits);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: digitWidth * 0.3,
              vertical: digitHeight * 0.15,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _solved
                    ? SpaceTheme.alienGreen.withValues(alpha: glowAnimation.value)
                    : isPreview
                        ? (previewValid
                            ? SpaceTheme.alienGreen
                            : SpaceTheme.rocketRed)
                            .withValues(alpha: glowAnimation.value)
                        : SpaceTheme.starYellow
                            .withValues(alpha: glowAnimation.value * 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_solved
                          ? SpaceTheme.alienGreen
                          : isPreview
                              ? (previewValid
                                  ? SpaceTheme.alienGreen
                                  : SpaceTheme.rocketRed)
                              : SpaceTheme.starYellow)
                      .withValues(alpha: 0.25 * glowAnimation.value),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _solved
                        ? 'FIXED!'
                        : isPreview
                            ? (previewValid ? 'VALID TIME' : 'STILL INVALID')
                            : 'BROKEN CLOCK',
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 11,
                      color: _solved
                          ? SpaceTheme.alienGreen
                          : isPreview
                              ? (previewValid
                                  ? SpaceTheme.alienGreen
                                  : SpaceTheme.rocketRed)
                              : SpaceTheme.starYellow,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                // Clock: digit digit : digit digit [: digit digit]
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTappableDigit(0, digitWidth, digitHeight),
                    SizedBox(width: digitWidth * 0.08),
                    _buildTappableDigit(1, digitWidth, digitHeight),
                    // Colon
                    SizedBox(
                      width: colonWidth,
                      height: digitHeight,
                      child: CustomPaint(
                        painter: _ColonPainter(
                          color: SpaceTheme.starYellow
                              .withValues(alpha: 0.6 + 0.4 * glowAnimation.value),
                        ),
                      ),
                    ),
                    _buildTappableDigit(2, digitWidth, digitHeight),
                    SizedBox(width: digitWidth * 0.08),
                    _buildTappableDigit(3, digitWidth, digitHeight),
                    // Seconds (6-digit mode)
                    if (_currentDigits.length == 6) ...[
                      SizedBox(
                        width: colonWidth,
                        height: digitHeight,
                        child: CustomPaint(
                          painter: _ColonPainter(
                            color: SpaceTheme.starYellow
                                .withValues(alpha: 0.6 + 0.4 * glowAnimation.value),
                          ),
                        ),
                      ),
                      _buildTappableDigit(4, digitWidth, digitHeight),
                      SizedBox(width: digitWidth * 0.08),
                      _buildTappableDigit(5, digitWidth, digitHeight),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTappableDigit(int position, double digitWidth, double digitHeight) {
    final isFirstSelected = _selectedFirst == position;
    final isSecondSelected = _selectedSecond == position;
    final isSelected = isFirstSelected || isSecondSelected;

    // Determine if this digit position is part of an invalid group
    final digit = _currentDigits[position];
    final hoursVal = _currentDigits[0] * 10 + _currentDigits[1];
    final minutesVal = _currentDigits[2] * 10 + _currentDigits[3];
    final secondsVal = _currentDigits.length == 6
        ? _currentDigits[4] * 10 + _currentDigits[5]
        : 0;
    final isInvalidPart =
        (position < 2 && hoursVal > 23) ||
        (position >= 2 && position < 4 && minutesVal > 59) ||
        (position >= 4 && secondsVal > 59);

    // Active color depends on state
    Color activeColor;
    if (_solved) {
      activeColor = SpaceTheme.alienGreen;
    } else if (isInvalidPart) {
      activeColor = SpaceTheme.rocketRed;
    } else {
      activeColor = SpaceTheme.starYellow;
    }

    return GestureDetector(
      onTap: () => _onDigitTapped(position),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFirstSelected
                ? SpaceTheme.starYellow
                : isSecondSelected
                    ? SpaceTheme.alienGreen
                    : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isFirstSelected
                            ? SpaceTheme.starYellow
                            : SpaceTheme.alienGreen)
                        .withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          width: digitWidth,
          height: digitHeight,
          child: CustomPaint(
            painter: _SevenSegmentPainter(
              segments: SevenSegment.getSegments(digit),
              activeColor: activeColor,
              inactiveColor: const Color(0xFF1A1A2E),
              glowValue: glowAnimation.value,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS PANEL (attempts, swap info)
  // ---------------------------------------------------------------------------

  Widget _buildStatusPanel() {
    final remaining = _puzzle!.maxAttempts - _attemptsUsed;
    final hasSwap = _selectedFirst != null && _selectedSecond != null;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceTheme.nebulaPurple),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attempts indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: SpaceTheme.rocketRed, size: 18),
              const SizedBox(width: 6),
              Text(
                S.of(context)!.circuitAttempts(remaining, _puzzle!.maxAttempts),
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 14,
                  color: remaining <= 1 ? SpaceTheme.rocketRed : SpaceTheme.moonSilver,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Swap description
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, _) {
              if (_selectedFirst != null && _selectedSecond == null) {
                return Transform.scale(
                  scale: pulseAnimation.value,
                  child: Text(
                    S.of(context)!.circuitPositionSelected(_selectedFirst! + 1),
                    style: SpaceTheme.bodyStyle.copyWith(
                      color: SpaceTheme.starYellow,
                      fontSize: 14,
                    ),
                  ),
                );
              } else if (hasSwap) {
                final previewDigits = _currentDigits;
                final timeStr =
                    '${previewDigits[0]}${previewDigits[1]}:${previewDigits[2]}${previewDigits[3]}';
                final valid = CircuitRepairPuzzle.isValidTime(previewDigits);
                return Column(
                  children: [
                    Text(
                      S.of(context)!.circuitSwapPositions(_selectedFirst! + 1, _selectedSecond! + 1),
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: SpaceTheme.cosmicPink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valid ? S.of(context)!.circuitResultValid(timeStr) : S.of(context)!.circuitResultInvalid(timeStr),
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: valid ? SpaceTheme.alienGreen : SpaceTheme.rocketRed,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }
              return Text(
                S.of(context)!.circuitTapToStart,
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.moonSilver,
                  fontSize: 14,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION BUTTONS
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons() {
    final hasSwap = _selectedFirst != null && _selectedSecond != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Reset button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _resetSelection,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(S.of(context)!.reset),
              style: SpaceTheme.secondaryButtonStyle,
            ),
          ),
          const SizedBox(width: 12),
          // Submit button
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, _) {
                return Transform.scale(
                  scale: hasSwap ? pulseAnimation.value : 1.0,
                  child: ElevatedButton.icon(
                    onPressed: hasSwap ? _submitAnswer : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(S.of(context)!.circuitRepairWinTitle),
                    style: SpaceTheme.primaryButtonStyle,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOGS
  // ---------------------------------------------------------------------------

  Widget _buildWinDialog(int score) {
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.circuitRepairWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    S.of(context)!.circuitClockNowReads(_puzzle!.correctTimeString),
                    style: SpaceTheme.bodyStyle.copyWith(
                      color: SpaceTheme.alienGreen,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(S.of(context)!.circuitRepairWinDesc(score),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(S.of(context)!.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
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

  Widget _buildLoseDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(S.of(context)!.circuitRepairLoseTitle,
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.circuitCorrectTimeWas(_puzzle!.correctTimeString),
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.starYellow,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(S.of(context)!.circuitRepairLoseDesc,
                style: SpaceTheme.bodyStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.playAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: SpaceTheme.primaryButtonStyle,
                  child: Text(S.of(context)!.backToMenu),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CUSTOM PAINTERS
// =============================================================================

/// Paints a single 7-segment digit at large scale.
class _SevenSegmentPainter extends CustomPainter {
  final Set<String> segments;
  final Color activeColor;
  final Color inactiveColor;
  final double glowValue;

  _SevenSegmentPainter({
    required this.segments,
    required this.activeColor,
    required this.inactiveColor,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = w * 0.15; // segment thickness
    final gap = t * 0.25;

    // Segment rectangles matching standard 7-segment layout:
    //  _a_
    // |   |
    // f   b
    // |_g_|
    // |   |
    // e   c
    // |_d_|
    final segmentRects = <String, Rect>{
      'a': Rect.fromLTWH(gap, 0, w - 2 * gap, t),
      'b': Rect.fromLTWH(w - t, gap, t, h / 2 - gap),
      'c': Rect.fromLTWH(w - t, h / 2 + gap, t, h / 2 - gap),
      'd': Rect.fromLTWH(gap, h - t, w - 2 * gap, t),
      'e': Rect.fromLTWH(0, h / 2 + gap, t, h / 2 - gap),
      'f': Rect.fromLTWH(0, gap, t, h / 2 - gap),
      'g': Rect.fromLTWH(gap, h / 2 - t / 2, w - 2 * gap, t),
    };

    for (final entry in segmentRects.entries) {
      final isActive = segments.contains(entry.key);
      final paint = Paint()
        ..color = isActive
            ? activeColor.withValues(alpha: 0.8 + 0.2 * glowValue)
            : inactiveColor;
      final rr = RRect.fromRectAndRadius(entry.value, Radius.circular(t * 0.3));
      canvas.drawRRect(rr, paint);

      if (isActive) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.3 * glowValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(rr, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SevenSegmentPainter oldDelegate) =>
      oldDelegate.glowValue != glowValue ||
      oldDelegate.segments != segments ||
      oldDelegate.activeColor != activeColor;
}

/// Paints the colon (:) between hours and minutes as two dots.
class _ColonPainter extends CustomPainter {
  final Color color;

  _ColonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final dotRadius = math.min(size.width, size.height) * 0.15;
    final cx = size.width / 2;
    final paint = Paint()..color = color;

    // Upper dot at ~1/3 height
    canvas.drawCircle(Offset(cx, size.height * 0.33), dotRadius, paint);
    // Lower dot at ~2/3 height
    canvas.drawCircle(Offset(cx, size.height * 0.67), dotRadius, paint);

    // Subtle glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, size.height * 0.33), dotRadius, glowPaint);
    canvas.drawCircle(Offset(cx, size.height * 0.67), dotRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ColonPainter oldDelegate) =>
      oldDelegate.color != color;
}
