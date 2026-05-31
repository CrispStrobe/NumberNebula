import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  CircuitRepairPuzzle? _puzzle;
  String? _selectedSegA;
  String? _selectedSegB;
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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
    _glowController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _selectedSegA = null;
      _selectedSegB = null;
      _successController.reset();
    });

    final generator =
        CircuitRepairGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _isGenerating = false;
    });
  }

  void _selectSegment(String seg) {
    setState(() {
      if (_selectedSegA == seg) {
        _selectedSegA = null;
      } else if (_selectedSegB == seg) {
        _selectedSegB = null;
      } else if (_selectedSegA == null) {
        _selectedSegA = seg;
      } else if (_selectedSegB == null) {
        _selectedSegB = seg;
      } else {
        _selectedSegA = seg;
        _selectedSegB = null;
      }
    });
  }

  /// Get the current display segments after applying the user's proposed swap.
  List<Set<String>> _getPreviewSegments() {
    if (_puzzle == null) return [];
    if (_selectedSegA != null && _selectedSegB != null) {
      // Show what the display would look like if we undo the user's swap
      return _puzzle!.corruptedSegments.map((segs) {
        return SevenSegment.applySwap(segs, _selectedSegA!, _selectedSegB!);
      }).toList();
    }
    return _puzzle!.corruptedSegments;
  }

  void _checkSolution() {
    if (_puzzle == null || _selectedSegA == null || _selectedSegB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.circuitRepairInstructions),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_puzzle!.checkAnswer(_selectedSegA!, _selectedSegB!)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int digitBonus = _puzzle!.correctDigits.length * 50;
    int totalScore = baseScore + levelBonus + digitBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'circuit_repair',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore),
    );
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'circuit_repair',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.circuitRepairLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
                  s.circuitRepairInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
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
          child: _buildCorruptedDisplay(constraints),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildSegmentSelector(constraints),
                const SizedBox(height: 16),
                _buildCheckButton(),
              ],
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
          const SizedBox(height: 8),
          _buildCorruptedDisplay(constraints),
          const SizedBox(height: 12),
          _buildSegmentSelector(constraints),
          const SizedBox(height: 12),
          _buildCheckButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCorruptedDisplay(BoxConstraints constraints) {
    // Make display LARGE: fill 60%+ of screen width
    final displayWidth = constraints.maxWidth * 0.7;
    final digitCount = _puzzle!.corruptedSegments.length;
    final digitWidth = ((displayWidth - 32) / digitCount).clamp(50.0, 120.0);
    final digitHeight = (digitWidth * 1.6).clamp(80.0, 200.0);

    final previewSegments = _getPreviewSegments();
    final isPreview = _selectedSegA != null && _selectedSegB != null;

    return AnimatedBuilder(
      animation: _glowAnimation,
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
                color: isPreview
                    ? SpaceTheme.alienGreen.withValues(alpha: _glowAnimation.value)
                    : SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPreview ? SpaceTheme.alienGreen : SpaceTheme.rocketRed)
                      .withValues(alpha: 0.3 * _glowAnimation.value),
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
                    isPreview ? 'PREVIEW (after swap)' : 'CORRUPTED DISPLAY',
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 11,
                      color: isPreview ? SpaceTheme.alienGreen : SpaceTheme.rocketRed,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                // Digits
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: previewSegments.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: digitWidth * 0.1),
                      child: SizedBox(
                        width: digitWidth,
                        height: digitHeight,
                        child: CustomPaint(
                          painter: _SevenSegmentPainter(
                            segments: entry.value,
                            activeColor: isPreview
                                ? SpaceTheme.alienGreen
                                : SpaceTheme.rocketRed,
                            inactiveColor: const Color(0xFF1A1A2E),
                            glowValue: _glowAnimation.value,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentSelector(BoxConstraints constraints) {
    // Interactive 7-segment diagram at a good size
    final selectorSize = (constraints.maxWidth * 0.25).clamp(80.0, 140.0);
    final selectorHeight = selectorSize * 1.6;

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
          Text(
            'Select two segments to swap:',
            style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Interactive 7-segment diagram
              SizedBox(
                width: selectorSize,
                height: selectorHeight,
                child: Stack(
                  children: SevenSegment.allSegments.map((seg) {
                    final isSelected =
                        seg == _selectedSegA || seg == _selectedSegB;
                    return Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _selectSegment(seg),
                        child: CustomPaint(
                          painter: _SegmentHighlightPainter(
                            segment: seg,
                            isSelected: isSelected,
                            isFirst: seg == _selectedSegA,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 20),
              // Segment buttons as backup
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['a', 'b', 'c', 'd']
                        .map((seg) => _buildSegButton(seg))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['e', 'f', 'g']
                        .map((seg) => _buildSegButton(seg))
                        .toList(),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedSegA != null || _selectedSegB != null) ...[
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Text(
                    'Swap: ${_selectedSegA ?? "?"} \u2194 ${_selectedSegB ?? "?"}',
                    style: SpaceTheme.titleStyle.copyWith(
                      color: SpaceTheme.cosmicPink,
                      fontSize: 18,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegButton(String seg) {
    final isSelected = seg == _selectedSegA || seg == _selectedSegB;
    final isFirst = seg == _selectedSegA;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: () => _selectSegment(seg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? (isFirst ? SpaceTheme.cosmicPink : SpaceTheme.alienGreen)
                : SpaceTheme.deepSpace,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? SpaceTheme.starYellow
                  : SpaceTheme.nebulaPurple,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isFirst ? SpaceTheme.cosmicPink : SpaceTheme.alienGreen)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              seg.toUpperCase(),
              style: SpaceTheme.titleStyle.copyWith(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final hasSelection = _selectedSegA != null && _selectedSegB != null;
            return Transform.scale(
              scale: hasSelection ? _pulseAnimation.value : 1.0,
              child: ElevatedButton.icon(
                onPressed: _checkSolution,
                icon: const Icon(Icons.build_circle_outlined),
                label: Text(S.of(context)!.circuitRepairWinTitle),
                style: SpaceTheme.primaryButtonStyle,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
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
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.circuitRepairWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.circuitRepairWinDesc(score),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
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
}

/// Paints a 7-segment display at large scale with CustomPaint.
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
    final gap = t * 0.2;

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
      canvas.drawRRect(
        RRect.fromRectAndRadius(entry.value, Radius.circular(t * 0.3)),
        paint,
      );
      if (isActive) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.3 * glowValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(entry.value, Radius.circular(t * 0.3)),
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SevenSegmentPainter oldDelegate) =>
      oldDelegate.glowValue != glowValue || oldDelegate.segments != segments;
}

/// Highlights individual segments for selection.
class _SegmentHighlightPainter extends CustomPainter {
  final String segment;
  final bool isSelected;
  final bool isFirst;

  _SegmentHighlightPainter({
    required this.segment,
    required this.isSelected,
    required this.isFirst,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = w * 0.18;
    final gap = t * 0.2;

    final segmentRects = <String, Rect>{
      'a': Rect.fromLTWH(gap, 0, w - 2 * gap, t),
      'b': Rect.fromLTWH(w - t, gap, t, h / 2 - gap),
      'c': Rect.fromLTWH(w - t, h / 2 + gap, t, h / 2 - gap),
      'd': Rect.fromLTWH(gap, h - t, w - 2 * gap, t),
      'e': Rect.fromLTWH(0, h / 2 + gap, t, h / 2 - gap),
      'f': Rect.fromLTWH(0, gap, t, h / 2 - gap),
      'g': Rect.fromLTWH(gap, h / 2 - t / 2, w - 2 * gap, t),
    };

    final rect = segmentRects[segment];
    if (rect == null) return;

    Color color;
    if (isSelected) {
      color = isFirst ? SpaceTheme.cosmicPink : SpaceTheme.alienGreen;
    } else {
      color = SpaceTheme.nebulaPurple.withValues(alpha: 0.4);
    }

    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(t * 0.3)),
      paint,
    );

    // Glow for selected segments
    if (isSelected) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(t * 0.3)),
        glowPaint,
      );
    }

    // Draw segment label
    final center = rect.center;
    final textPainter = TextPainter(
      text: TextSpan(
        text: segment.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.5),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SegmentHighlightPainter oldDelegate) =>
      oldDelegate.isSelected != isSelected;
}
