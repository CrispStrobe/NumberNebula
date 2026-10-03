import 'dart:async';

import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/launch_sequence_logic.dart';

class LaunchSequenceGame extends StatefulWidget {
  final int grade;
  final int level;
  const LaunchSequenceGame(
      {super.key, required this.grade, required this.level});

  @override
  State<LaunchSequenceGame> createState() => _LaunchSequenceGameState();
}

class _LaunchSequenceGameState extends State<LaunchSequenceGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<LaunchSequenceGame>,
        PuzzleSessionMixin<LaunchSequenceGame> {
  bool _sessionReady = false;
  Timer? _winTimer;
  int _roundEpoch = 0;
  bool _reducedMotion = false;

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    _reducedMotion = reduced;
    updateOneShotMotion(_launchController, reduced,
        duration: const Duration(milliseconds: 1200));
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  void _cancelRoundEffects() {
    _roundEpoch++;
    _winTimer?.cancel();
    _winTimer = null;
    cancelOneShotMotion(_launchController);
    cancelOneShotMotion(successController);
  }

  bool _canInteract(int epoch) =>
      mounted &&
      _sessionReady &&
      epoch == _roundEpoch &&
      !_isGenerating &&
      !_won;

  bool _validIndex(int index) => index >= 0 && index < sequence.length;

  @override
  String get sessionGameKey => 'launch_sequence';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      'sequence': sequence.map((v0) => v0).toList(),
      'swapCount': swapCount,
      '_selectedIndex': (_selectedIndex)
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _cancelRoundEffects();
    _launchController.reset();
    successController.reset();
    puzzle = (state["puzzle"] == null
        ? null
        : LaunchSequencePuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    sequence = (state["sequence"] as List).map((v0) => v0 as int).toList();
    swapCount = state["swapCount"] as int;
    final selected = state["_selectedIndex"];
    _selectedIndex = selected is int && _validIndex(selected) ? selected : null;
    _isGenerating = false;
    _won = false;
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

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
    initGameAnimations(usePulse: false);

    _launchController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _launchAnimation =
        CurvedAnimation(parent: _launchController, curve: Curves.easeInExpo);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level,
            gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    _cancelRoundEffects();
    disposePuzzleSession();
    _launchController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    _cancelRoundEffects();
    beginPuzzleSession();
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _won = false;
      swapCount = 0;
      _selectedIndex = null;
      successController.reset();
      _launchController.reset();
    });

    final config = LaunchSequenceGenerationConfig(
        currentDifficulty!.grade, currentDifficulty!.level);
    puzzle = LaunchSequencePuzzle.generate(
      itemCount: config.itemCount,
      minInversions: config.inversions,
    );

    setState(() {
      sequence = List<int>.from(puzzle!.sequence);
      _isGenerating = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex, int epoch) {
    if (!_canInteract(epoch) ||
        !_validIndex(oldIndex) ||
        !_validIndex(newIndex)) {
      return;
    }
    if (oldIndex == newIndex) return;

    AppHaptics.selectionClick();

    setState(() {
      final item = sequence.removeAt(oldIndex);
      sequence.insert(newIndex, item);
      // Inversions measure adjacent swaps, including each step of a long drag.
      swapCount += (newIndex - oldIndex).abs();
      _selectedIndex = null;
    });

    if (LaunchSequencePuzzle.isSorted(sequence)) {
      _handleWin();
    }
  }

  void _onItemTap(int index, int epoch) {
    if (!_canInteract(epoch) || !_validIndex(index)) return;

    AppHaptics.selectionClick();

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
    if (!_canInteract(_roundEpoch) || puzzle == null) return;
    _won = true;
    // Reject callbacks retained by pre-victory widgets.
    _cancelRoundEffects();
    AppHaptics.lightImpact();

    // Start launch animation
    _launchController.reset();
    playOneShotMotion(_launchController, () {});

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    final optimal = puzzle!.optimalSwaps;
    int efficiencyBonus =
        optimal > 0 ? ((optimal / swapCount.clamp(1, 999)) * 100).round() : 50;
    int totalScore = baseScore + levelBonus + efficiencyBonus;

    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'launch_sequence',
          difficulty: widget.level,
          score: totalScore,
          performance: Perf.fromMoves(swapCount, optimal),
          movesUsed: swapCount,
          optimalMoves: optimal,
        ));

    successController.reset();
    playOneShotMotion(successController, () {});

    // Keep the normal dialog delay independent of decorative motion settings.
    final epoch = _roundEpoch;
    _winTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted && epoch == _roundEpoch && _won) {
        _winTimer = null;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildWinDialog(totalScore, epoch),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = S.of(context)!;
    final epoch = _roundEpoch;

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
                onBack: () {
                  if (mounted && _sessionReady && epoch == _roundEpoch) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        animation: glowAnimation,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isOptimal
                    ? SpaceTheme.alienGreen
                        .withValues(alpha: glowAnimation.value)
                    : SpaceTheme.starYellow
                        .withValues(alpha: glowAnimation.value),
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
          Text(S.of(context)!.launchSequenceTarget,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 12)),
          ...puzzle!.target.map((v) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$v',
                  style: SpaceTheme.bodyStyle
                      .copyWith(fontSize: 12, color: Colors.white70),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSequenceArea(BoxConstraints constraints) {
    final epoch = _roundEpoch;
    final availWidth = constraints.maxWidth;
    final cardWidth = ((availWidth - 48) / sequence.length).clamp(55.0, 80.0);
    final cardHeight = (cardWidth * 1.5).clamp(80.0, 120.0);

    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(
                  0xFF253A5E), // brighter to contrast with SpaceBackground
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.starYellow
                    .withValues(alpha: 0.4 + glowAnimation.value * 0.3),
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
                key: ValueKey(epoch),
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: !_won,
                proxyDecorator: (child, index, animation) {
                  if (_reducedMotion) return child;
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final scale = Tween<double>(begin: 1.0, end: 1.08)
                          .animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ))
                          .value;
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemCount: sequence.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _onReorder(oldIndex, newIndex, epoch),
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
    final epoch = _roundEpoch;
    final value = sequence[index];
    final isSelected = _selectedIndex == index;
    final isInCorrectPosition = sequence[index] == puzzle!.target[index];
    final color = _shipColors[(value - 1) % _shipColors.length];

    Widget card = GestureDetector(
      onTap: () => _onItemTap(index, epoch),
      child: AnimatedContainer(
        duration:
            _reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
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
          final progress = ((_launchAnimation.value - delay) / (1.0 - delay))
              .clamp(0.0, 1.0);
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

    return KeyedSubtree(key: key, child: card);
  }

  Widget _buildWinDialog(int bonusScore, int epoch) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: ScrollableRoundDialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundSummary(gameKey: 'launch_sequence'),
                  const Icon(Icons.rocket_launch,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.launchSequenceWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                      s.launchSequenceWinDesc(
                          swapCount, puzzle!.optimalSwaps, bonusScore),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!mounted || epoch != _roundEpoch || !_won) return;
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!mounted || epoch != _roundEpoch || !_won) return;
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
