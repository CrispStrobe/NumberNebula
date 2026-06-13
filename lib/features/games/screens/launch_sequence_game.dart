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
  late AnimationController _launchController;
  late Animation<double> _launchAnimation;

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

    _launchController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _launchAnimation = CurvedAnimation(parent: _launchController, curve: Curves.easeInExpo);

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
    _launchController.dispose();
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
      _launchController.reset();
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

  void _onReorder(int oldIndex, int newIndex) {
    if (_won) return;
    // ReorderableListView adjusts newIndex when moving down
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    HapticFeedback.selectionClick();

    setState(() {
      final item = sequence.removeAt(oldIndex);
      sequence.insert(newIndex, item);
      swapCount++;
      _selectedIndex = null;
    });

    if (LaunchSequencePuzzle.isSorted(sequence)) {
      _handleWin();
    }
  }

  void _onItemTap(int index) {
    if (_won) return;

    HapticFeedback.selectionClick();

    if (_selectedIndex == null) {
      setState(() {
        _selectedIndex = index;
      });
    } else if (_selectedIndex == index) {
      setState(() {
        _selectedIndex = null;
      });
    } else {
      final diff = (index - _selectedIndex!).abs();
      if (diff == 1) {
        // Adjacent swap with animation
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
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  void _handleWin() {
    _won = true;
    HapticFeedback.lightImpact();

    // Start launch animation
    _launchController.forward(from: 0.0);

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
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

    // Show dialog after launch animation
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildWinDialog(totalScore),
        );
      }
    });
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
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              // Move counter + optimal prominently
              _buildMoveCounter(),
              // Target order
              _buildTargetRow(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildSequenceArea(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoveCounter() {
    final isOptimal = swapCount <= puzzle!.optimalSwaps;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isOptimal
                    ? SpaceTheme.alienGreen.withValues(alpha: _glowAnimation.value)
                    : SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Moves: $swapCount',
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.emoji_events,
                    color: SpaceTheme.starYellow, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Optimal: ${puzzle!.optimalSwaps}',
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 14,
                    color: SpaceTheme.starYellow,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTargetRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
    );
  }

  Widget _buildSequenceArea(BoxConstraints constraints) {
    final availWidth = constraints.maxWidth;
    final cardWidth = ((availWidth - 48) / sequence.length).clamp(55.0, 80.0);
    final cardHeight = (cardWidth * 1.5).clamp(80.0, 120.0);

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF253A5E), // brighter to contrast with SpaceBackground
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.starYellow.withValues(alpha: 0.4 + _glowAnimation.value * 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: SpaceTheme.nebulaPurple.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SizedBox(
              height: cardHeight + 24,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: !_won,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final scale = Tween<double>(begin: 1.0, end: 1.08)
                          .animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          )).value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemCount: sequence.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  return _buildShipCard(
                    key: ValueKey(sequence[index]),
                    index: index,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShipCard({
    required Key key,
    required int index,
    required double cardWidth,
    required double cardHeight,
  }) {
    final value = sequence[index];
    final isSelected = _selectedIndex == index;
    final isInCorrectPosition = sequence[index] == puzzle!.target[index];
    final color = _shipColors[(value - 1) % _shipColors.length];

    Widget card = GestureDetector(
      onTap: () => _onItemTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        height: cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                    ? SpaceTheme.alienGreen
                    : Colors.white24,
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
                color: SpaceTheme.alienGreen.withValues(alpha: 0.4),
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
              size: cardWidth * 0.4,
            ),
            SizedBox(height: cardHeight * 0.06),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$value',
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: cardWidth * 0.22,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Victory launch animation
    if (_won) {
      card = AnimatedBuilder(
        animation: _launchAnimation,
        builder: (context, child) {
          // Stagger launch per ship index
          final delay = index / sequence.length;
          final progress = ((_launchAnimation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, -progress * 300),
            child: Opacity(
              opacity: (1.0 - progress).clamp(0.2, 1.0),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
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
                  const Icon(Icons.rocket_launch, size: 64, color: SpaceTheme.starYellow),
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
