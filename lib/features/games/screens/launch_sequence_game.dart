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
import '../services/launch_sequence_logic.dart';

class LaunchSequenceGame extends StatefulWidget {
  final int grade;
  final int level;
  const LaunchSequenceGame({super.key, required this.grade, required this.level});

  @override
  State<LaunchSequenceGame> createState() => _LaunchSequenceGameState();
}

class _LaunchSequenceGameState extends State<LaunchSequenceGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _swapController;

  DifficultyConfig? currentDifficulty;
  LaunchSequencePuzzle? puzzle;
  late List<int> sequence;
  int swapCount = 0;
  bool _isGenerating = true;
  bool _won = false;
  int? _selectedIndex;

  static const List<Color> _shipColors = [
    Color(0xFFE63946),
    Color(0xFF06FFA5),
    Color(0xFF6B48FF),
    Color(0xFFFFD700),
    Color(0xFFFF6B35),
    Color(0xFF00C9DB),
    Color(0xFFFF69B4),
    Color(0xFFA855F7),
  ];

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

    _swapController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _glowController.dispose();
    _successController.dispose();
    _swapController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _won = false;
      swapCount = 0;
      _selectedIndex = null;
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;
    int itemCount;
    int minInversions;

    if (grade <= 1) {
      itemCount = 4;
      minInversions = 2;
    } else if (grade <= 2) {
      itemCount = 5;
      minInversions = 3;
    } else {
      itemCount = (6 + currentDifficulty!.level ~/ 5).clamp(6, 8);
      minInversions = (4 + currentDifficulty!.level ~/ 3).clamp(4, 15);
    }

    puzzle = LaunchSequencePuzzle.generate(
      itemCount: itemCount,
      minInversions: minInversions,
    );

    setState(() {
      sequence = List<int>.from(puzzle!.sequence);
      _isGenerating = false;
    });
  }

  void _onItemTap(int index) {
    if (_won) return;

    HapticFeedback.selectionClick();

    if (_selectedIndex == null) {
      // First selection
      setState(() {
        _selectedIndex = index;
      });
    } else if (_selectedIndex == index) {
      // Deselect
      setState(() {
        _selectedIndex = null;
      });
    } else {
      // Check if adjacent
      final diff = (index - _selectedIndex!).abs();
      if (diff == 1) {
        // Swap
        _swapController.forward(from: 0.0);
        setState(() {
          final temp = sequence[index];
          sequence[index] = sequence[_selectedIndex!];
          sequence[_selectedIndex!] = temp;
          swapCount++;
          _selectedIndex = null;
        });

        if (LaunchSequencePuzzle.isSorted(sequence)) {
          _handleWin();
        }
      } else {
        // Not adjacent, select the new one instead
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  void _handleWin() {
    _won = true;
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    // Bonus for being close to optimal
    final optimal = puzzle!.optimalSwaps;
    int efficiencyBonus = optimal > 0
        ? ((optimal / swapCount.clamp(1, 999)) * 100).round()
        : 50;
    int totalScore = baseScore + levelBonus + efficiencyBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'launch_sequence',
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
                title: s.launchSequenceTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.launchSequenceInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Swaps: $swapCount  |  Optimal: ${puzzle!.optimalSwaps}',
                      style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Target order
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Target: ', style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
                    ...puzzle!.target.map((v) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$v',
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white70),
                      ),
                    )),
                  ],
                ),
              ),
              Expanded(child: _buildSequenceArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSequenceArea() {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE63946).withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: _glowAnimation.value * 0.5),
                width: 2,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(sequence.length, (i) {
                  return _buildShipSlot(i);
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShipSlot(int index) {
    final value = sequence[index];
    final isSelected = _selectedIndex == index;
    final isInCorrectPosition = sequence[index] == puzzle!.target[index];
    final color = _shipColors[(value - 1) % _shipColors.length];

    return GestureDetector(
      onTap: () => _onItemTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 65,
        height: 100,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SpaceTheme.starYellow
                : isInCorrectPosition
                    ? const Color(0xFF06FFA5)
                    : Colors.transparent,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            if (isInCorrectPosition)
              BoxShadow(
                color: const Color(0xFF06FFA5).withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch,
              color: Colors.white.withValues(alpha: 0.9),
              size: 28,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$value',
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
                  Text(s.launchSequenceWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.launchSequenceWinDesc(swapCount, puzzle!.optimalSwaps, bonusScore), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
