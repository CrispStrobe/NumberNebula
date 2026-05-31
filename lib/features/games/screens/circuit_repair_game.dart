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
        // Both already selected, replace first
        _selectedSegA = seg;
        _selectedSegB = null;
      }
    });
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
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              _buildCorruptedDisplay(),
              const SizedBox(height: 16),
              _buildSegmentSelector(),
              const Spacer(),
              _buildCheckButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorruptedDisplay() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceTheme.rocketRed.withValues(alpha: 0.3 * _glowAnimation.value),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _puzzle!.corruptedSegments.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 60,
                  height: 100,
                  child: CustomPaint(
                    painter: _SevenSegmentPainter(
                      segments: entry.value,
                      activeColor: SpaceTheme.rocketRed,
                      inactiveColor: const Color(0xFF1A1A2E),
                      glowValue: _glowAnimation.value,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSegmentSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceTheme.nebulaPurple),
      ),
      child: Column(
        children: [
          Text(
            'Select two segments to swap:',
            style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Interactive 7-segment diagram
              SizedBox(
                width: 100,
                height: 160,
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
              const SizedBox(width: 24),
              // Segment buttons as backup
              Column(
                children: [
                  Row(
                    children: ['a', 'b', 'c', 'd']
                        .map((seg) => _buildSegButton(seg))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
            Text(
              'Swap: ${_selectedSegA ?? "?"} \u2194 ${_selectedSegB ?? "?"}',
              style: SpaceTheme.titleStyle.copyWith(
                color: SpaceTheme.cosmicPink,
                fontSize: 18,
              ),
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
        child: Container(
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
        child: ElevatedButton.icon(
          onPressed: _checkSolution,
          icon: const Icon(Icons.build_circle_outlined),
          label: Text(S.of(context)!.circuitRepairWinTitle),
          style: SpaceTheme.primaryButtonStyle,
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

/// Paints a 7-segment display.
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

    // Segment rectangles (a-g)
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
