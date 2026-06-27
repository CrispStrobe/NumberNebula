import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/ion_chain_logic.dart';

class IonChainGame extends StatefulWidget {
  final int grade;
  final int level;
  const IonChainGame({super.key, required this.grade, required this.level});

  @override
  State<IonChainGame> createState() => _IonChainGameState();
}

class _IonChainGameState extends State<IonChainGame>
    with TickerProviderStateMixin, GameAnimationsMixin<IonChainGame> {

  IonChainPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  List<IonType?> _playerChain = [];

  static const _beadColors = {
    IonType.red: Color(0xFFE63946),
    IonType.blue: Color(0xFF457B9D),
    IonType.green: Color(0xFF06FFA5),
    IonType.yellow: Color(0xFFFFD700),
    IonType.purple: Color(0xFFBB86FC),
  };

  static const _beadShapes = {
    IonType.red: Icons.star,
    IonType.blue: Icons.circle,
    IonType.green: Icons.hexagon,
    IonType.yellow: Icons.diamond,
    IonType.purple: Icons.change_history,
  };

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);


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
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;
    setState(() { _isGenerating = true; _playerChain = []; successController.reset(); });

    final grade = currentDifficulty!.grade;
    final level = currentDifficulty!.level;

    // Map grade/level to puzzle parameters
    int chainLength, ionTypeCount, ruleCount, blanksToRemove;
    if (grade <= 1) {
      chainLength = 5; ionTypeCount = 3; ruleCount = 1; blanksToRemove = 2;
    } else if (grade <= 2) {
      chainLength = 6 + (level > 5 ? 1 : 0); ionTypeCount = 3; ruleCount = 1 + (level > 5 ? 1 : 0); blanksToRemove = 3;
    } else {
      chainLength = 7 + (level > 5 ? 2 : 0); ionTypeCount = 4; ruleCount = 2 + (level > 8 ? 1 : 0); blanksToRemove = 3 + (level > 5 ? 1 : 0);
    }

    final p = IonChainPuzzle.generate(
      chainLength: chainLength,
      ionTypeCount: ionTypeCount,
      ruleCount: ruleCount,
      blanksToRemove: blanksToRemove,
    );

    if (mounted) {
      setState(() { puzzle = p; _playerChain = List<IonType?>.from(p.chain); _isGenerating = false; });
    }
  }

  void _placeBeadInSlot(int slotIndex, IonType bead) {
    if (_playerChain[slotIndex] != null) return;
    if (puzzle!.chain[slotIndex] != null) return;

    final testChain = List<IonType?>.from(_playerChain);
    testChain[slotIndex] = bead;

    // Check circular neighbors (bracelet: slot 0 is adjacent to last slot)
    bool valid = true;
    final prevIdx = (slotIndex - 1 + testChain.length) % testChain.length;
    final nextIdx = (slotIndex + 1) % testChain.length;

    if (testChain[prevIdx] != null) {
      for (final rule in puzzle!.rules) {
        if (!rule.check(testChain[prevIdx], bead)) { valid = false; break; }
      }
    }
    if (valid && testChain[nextIdx] != null) {
      for (final rule in puzzle!.rules) {
        if (!rule.check(bead, testChain[nextIdx])) { valid = false; break; }
      }
    }

    if (!valid) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rule violation! This bead can\'t go here.'),
        backgroundColor: SpaceTheme.rocketRed, duration: Duration(seconds: 1),
      ));
      return;
    }

    HapticFeedback.lightImpact();
    setState(() { _playerChain[slotIndex] = bead; });

    if (!_playerChain.contains(null)) {
      if (IonChainPuzzle.validateChain(_playerChain, puzzle!.rules)) {
        _handleWin();
      }
    }
  }

  void _removeBeadFromSlot(int slotIndex) {
    if (puzzle!.chain[slotIndex] != null) return;
    if (_playerChain[slotIndex] == null) return;
    HapticFeedback.lightImpact();
    setState(() { _playerChain[slotIndex] = null; });
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int totalScore = 100 * widget.grade + widget.level * 25;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'ion_chain', difficulty: widget.level, score: totalScore,
    ));

    successController.forward(from: 0.0);
    if (mounted) {
      showDialog(context: context, barrierDismissible: false,
        builder: (_) => _buildWinDialog(totalScore));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (puzzle == null || _isGenerating) {
      return Scaffold(body: SpaceBackground(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(), const SizedBox(height: 16),
          Text(s.loadingAdventure, style: SpaceTheme.bodyStyle)],
      ))));
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(title: s.ionChainTitle, level: widget.level,
                onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInstructions(s),
                      const SizedBox(height: 10),
                      _buildRules(),
                      const SizedBox(height: 14),
                      _buildBracelet(),
                      const SizedBox(height: 14),
                      _buildBeadTray(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(S s) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(s.ionChainInstructions,
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 14))),
      ]),
    );
  }

  Widget _buildRules() {
    final isDE = Localizations.localeOf(context).languageCode == 'de';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.rocketRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RULES', style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 14, color: SpaceTheme.rocketRed, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          ...puzzle!.rules.map((rule) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              const Icon(Icons.block, color: SpaceTheme.rocketRed, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(isDE ? rule.descriptionDe : rule.description,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 15))),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildBracelet() {
    return LayoutBuilder(builder: (context, constraints) {
      final slotCount = _playerChain.length;
      // Circular layout: compute radius and bead size from available space
      final availSize = math.min(constraints.maxWidth - 24, 320.0);
      final ringRadius = availSize * 0.35;
      final slotSize = (2 * math.pi * ringRadius / slotCount * 0.65).clamp(36.0, 56.0);

      return AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, _) {
          return Column(children: [
            Text('ION RING', style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 14, color: SpaceTheme.starYellow, letterSpacing: 2)),
            const SizedBox(height: 6),
            SizedBox(
              width: ringRadius * 2 + slotSize + 16,
              height: ringRadius * 2 + slotSize + 16,
              child: CustomPaint(
                painter: _RingPainter(
                  slotCount: slotCount,
                  ringRadius: ringRadius,
                  glowValue: glowAnimation.value,
                ),
                child: Stack(
                  children: List.generate(slotCount, (i) {
                    final angle = (2 * math.pi * i / slotCount) - math.pi / 2;
                    final cx = ringRadius + slotSize / 2 + 8 + ringRadius * math.cos(angle) - slotSize / 2;
                    final cy = ringRadius + slotSize / 2 + 8 + ringRadius * math.sin(angle) - slotSize / 2;
                    return Positioned(
                      left: cx,
                      top: cy,
                      child: _buildSlot(i, slotSize),
                    );
                  }),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }

  Widget _buildSlot(int index, double size) {
    final isClue = puzzle!.chain[index] != null;
    final value = _playerChain[index];

    if (value == null) {
      return DragTarget<IonType>(
        builder: (context, candidates, _) {
          final hover = candidates.isNotEmpty;
          return AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, _) => Container(
              width: size, height: size,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hover ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                    : SpaceTheme.deepSpace.withValues(alpha: 0.4),
                border: Border.all(
                  color: hover ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                  width: hover ? 2.5 : 1.5),
              ),
              child: Transform.scale(
                scale: pulseAnimation.value,
                child: Icon(Icons.add, color: SpaceTheme.nebulaPurple, size: size * 0.35),
              ),
            ),
          );
        },
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _placeBeadInSlot(index, d.data),
      );
    }

    final color = _beadColors[value] ?? SpaceTheme.starYellow;
    final icon = _beadShapes[value] ?? Icons.circle;

    Widget bead = Container(
      width: size, height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.35),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)],
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );

    if (!isClue) {
      bead = GestureDetector(onTap: () => _removeBeadFromSlot(index), child: bead);
    } else {
      bead = Stack(children: [bead,
        Positioned(bottom: 0, right: 0,
          child: Icon(Icons.lock, color: Colors.white30, size: size * 0.22))]);
    }
    return bead;
  }

  Widget _buildBeadTray() {
    final available = <IonType, int>{};
    for (final b in puzzle!.availableIons) { available[b] = (available[b] ?? 0) + 1; }
    for (int i = 0; i < _playerChain.length; i++) {
      if (puzzle!.chain[i] == null && _playerChain[i] != null) {
        final t = _playerChain[i]!;
        available[t] = (available[t] ?? 1) - 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('AVAILABLE BEADS', style: SpaceTheme.bodyStyle.copyWith(
          fontSize: 14, color: SpaceTheme.starYellow, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
          children: puzzle!.ionTypes.map((type) {
            final count = available[type] ?? 0;
            final color = _beadColors[type] ?? SpaceTheme.starYellow;
            final icon = _beadShapes[type] ?? Icons.circle;

            return Draggable<IonType>(
              data: count > 0 ? type : null,
              maxSimultaneousDrags: count > 0 ? 1 : 0,
              feedback: Material(color: Colors.transparent, child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.5),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 15, spreadRadius: 3)]),
                child: Icon(icon, color: Colors.white, size: 28),
              )),
              childWhenDragging: Opacity(opacity: 0.3, child: _beadChip(type, color, icon, count)),
              child: _beadChip(type, color, icon, count),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _beadChip(IonType type, Color color, IconData icon, int count) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: count > 0 ? color.withValues(alpha: 0.25) : Colors.white10,
          border: Border.all(color: count > 0 ? color : Colors.white24, width: 2)),
        child: Icon(icon, color: count > 0 ? color : Colors.white24, size: 26),
      ),
      const SizedBox(height: 4),
      Text('×$count', style: SpaceTheme.bodyStyle.copyWith(
        fontSize: 14, color: count > 0 ? color : Colors.white24)),
    ]);
  }

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, _) => Transform.scale(
        scale: successAnimation.value,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: SpaceTheme.cardDecoration,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.link, size: 64, color: SpaceTheme.starYellow),
              const SizedBox(height: 16),
              Text(s.ionChainWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(s.ionChainWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(autofocus: true, onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                  style: SpaceTheme.secondaryButtonStyle, child: Text(s.playAgain)),
                ElevatedButton(onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
                  style: SpaceTheme.primaryButtonStyle, child: Text(s.backToMenu)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Draws a circular ring connecting bead positions.
class _RingPainter extends CustomPainter {
  final int slotCount;
  final double ringRadius;
  final double glowValue;

  _RingPainter({required this.slotCount, required this.ringRadius, required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the ring
    final ringPaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.15 + glowValue * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Glow ring
    final glowPaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: glowValue * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, ringRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.glowValue != glowValue;
}
