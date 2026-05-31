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
import '../services/ion_chain_logic.dart';

class IonChainGame extends StatefulWidget {
  final int grade;
  final int level;
  const IonChainGame({super.key, required this.grade, required this.level});

  @override
  State<IonChainGame> createState() => _IonChainGameState();
}

class _IonChainGameState extends State<IonChainGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  DifficultyConfig? currentDifficulty;
  IonChainPuzzle? puzzle;
  late List<IonType?> chain;
  late List<IonType> availableIons;
  bool _isGenerating = true;
  bool _won = false;
  int _lastDroppedIndex = -1;

  static const Map<IonType, Color> _ionColors = {
    IonType.red: Color(0xFFE63946),
    IonType.blue: Color(0xFF00C9DB),
    IonType.green: Color(0xFF06FFA5),
    IonType.yellow: Color(0xFFFFD700),
    IonType.purple: Color(0xFF6B48FF),
  };

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
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

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
    _dropController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _won = false;
      _lastDroppedIndex = -1;
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;
    int chainLength;
    int ionTypeCount;
    int ruleCount;

    if (grade <= 1) {
      chainLength = 5;
      ionTypeCount = 3;
      ruleCount = 1;
    } else if (grade <= 2) {
      chainLength = 7;
      ionTypeCount = 3;
      ruleCount = 2;
    } else {
      chainLength = (9 + currentDifficulty!.level ~/ 4).clamp(9, 12);
      ionTypeCount = 4;
      ruleCount = (3 + currentDifficulty!.level ~/ 5).clamp(3, 5);
    }

    final blanksToRemove = (chainLength * 0.4).ceil().clamp(2, chainLength - 2);

    puzzle = IonChainPuzzle.generate(
      chainLength: chainLength,
      ionTypeCount: ionTypeCount,
      ruleCount: ruleCount,
      blanksToRemove: blanksToRemove,
    );

    setState(() {
      chain = List<IonType?>.from(puzzle!.chain);
      availableIons = List<IonType>.from(puzzle!.availableIons);
      _isGenerating = false;
    });
  }

  void _placeIon(IonType ion, int index) {
    if (_won) return;
    if (chain[index] != null) return; // already filled

    HapticFeedback.selectionClick();

    setState(() {
      chain[index] = ion;
      availableIons.remove(ion);
      _lastDroppedIndex = index;
      _dropController.forward(from: 0.0);
    });

    _checkSolution();
  }

  void _removeIon(int index) {
    if (puzzle!.chain[index] != null) return; // was pre-filled

    final ion = chain[index];
    if (ion == null) return;

    setState(() {
      chain[index] = null;
      availableIons.add(ion);
      _lastDroppedIndex = -1;
    });
  }

  void _checkSolution() {
    if (chain.any((c) => c == null)) return; // not complete

    if (IonChainPuzzle.validateChain(chain, puzzle!.rules)) {
      _handleWin();
    } else {
      _handleIncorrect();
    }
  }

  void _handleWin() {
    _won = true;
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int ruleBonus = puzzle!.rules.length * 50;
    int totalScore = baseScore + levelBonus + ruleBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'ion_chain',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildWinDialog(totalScore),
      );
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
            Expanded(child: Text(S.of(context)!.ionChainLoseDesc)),
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

    if (_isGenerating || puzzle == null) {
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
                title: s.ionChainTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.ionChainInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              _buildRules(),
              const SizedBox(height: 16),
              Expanded(child: _buildChainArea()),
              _buildIonTray(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRules() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF06FFA5).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: puzzle!.rules.map((rule) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.rule, color: Color(0xFF06FFA5), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.description,
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChainArea() {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF06FFA5).withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF06FFA5).withValues(alpha: _glowAnimation.value * 0.5),
                width: 2,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(puzzle!.chainLength, (i) {
                  return _buildChainSlot(i);
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChainSlot(int index) {
    final ion = chain[index];
    final isPreFilled = puzzle!.chain[index] != null;
    final isEmpty = ion == null;
    final isLastDropped = index == _lastDroppedIndex;
    const slotSize = 50.0;

    Widget slot;
    if (isEmpty) {
      slot = DragTarget<IonType>(
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            width: slotSize,
            height: slotSize,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isHovering
                  ? const Color(0xFF06FFA5).withValues(alpha: 0.3)
                  : SpaceTheme.deepSpace.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: isHovering ? const Color(0xFF06FFA5) : Colors.grey.shade600,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: Colors.grey.shade500,
                size: 20,
              ),
            ),
          );
        },
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => _placeIon(details.data, index),
      );
    } else {
      final color = _ionColors[ion]!;
      slot = GestureDetector(
        onTap: isPreFilled ? null : () => _removeIon(index),
        child: Container(
          width: slotSize,
          height: slotSize,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: isPreFilled ? Colors.white54 : color,
              width: isPreFilled ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text(
              ion.name[0].toUpperCase(),
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (isLastDropped && !isEmpty) {
      return ScaleTransition(scale: _dropAnimation, child: slot);
    }
    return slot;
  }

  Widget _buildIonTray() {
    if (availableIons.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: const Color(0xFF00C9DB), width: 2),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(availableIons.length, (i) {
          final ion = availableIons[i];
          final color = _ionColors[ion]!;
          return Draggable<IonType>(
            data: ion,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [color, color.withValues(alpha: 0.6)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Center(
                  child: Text(
                    ion.name[0].toUpperCase(),
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildIonChip(ion, color),
            ),
            child: _buildIonChip(ion, color),
          );
        }),
      ),
    );
  }

  Widget _buildIonChip(IonType ion, Color color) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.6)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(
          ion.name[0].toUpperCase(),
          style: SpaceTheme.headlineStyle.copyWith(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildWinDialog(int bonusScore) {
    final s = S.of(context)!;
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
                  Text(s.ionChainWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.ionChainWinDesc(bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(s.backToMenu),
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
