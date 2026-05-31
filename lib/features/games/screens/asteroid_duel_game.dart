import 'dart:math' as math;
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

class AsteroidDuelGame extends StatefulWidget {
  final int grade;
  final int level;
  const AsteroidDuelGame({super.key, required this.grade, required this.level});

  @override
  State<AsteroidDuelGame> createState() => _AsteroidDuelGameState();
}

class _AsteroidDuelGameState extends State<AsteroidDuelGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  int _totalAsteroids = 0;
  int _remaining = 0;
  int _maxPerTurn = 0;
  bool _isPlayerTurn = true;
  List<_MoveRecord> _moveHistory = [];

  final _random = math.Random();

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
    _glowController.stop();
    _successController.stop();
    _glowController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _moveHistory.clear();
      _isPlayerTurn = true;
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;

    if (grade <= 1) {
      _totalAsteroids = _random.nextInt(5) + 8; // 8-12
      _maxPerTurn = 3;
    } else if (grade == 2) {
      _totalAsteroids = _random.nextInt(6) + 12; // 12-17
      _maxPerTurn = 3;
    } else if (grade == 3) {
      _totalAsteroids = _random.nextInt(6) + 16; // 16-21
      _maxPerTurn = 4;
    } else {
      _totalAsteroids = _random.nextInt(8) + 18; // 18-25
      _maxPerTurn = 4;
    }

    _remaining = _totalAsteroids;

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _playerTake(int count) {
    if (_gameOver || !_isPlayerTurn) return;
    if (count < 1 || count > math.min(_maxPerTurn, _remaining)) return;

    setState(() {
      _remaining -= count;
      _moveHistory.add(_MoveRecord(isPlayer: true, count: count, remainingAfter: _remaining));
      _isPlayerTurn = false;
    });

    // Check if player took the last one (player loses)
    if (_remaining <= 0) {
      _handleLoss();
      return;
    }

    // AI turn after a short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_gameOver) {
        _aiTurn();
      }
    });
  }

  void _aiTurn() {
    final grade = currentDifficulty?.grade ?? 1;
    int aiTake;

    if (grade <= 1) {
      // Random AI
      aiTake = _random.nextInt(math.min(_maxPerTurn, _remaining)) + 1;
    } else {
      // Near-optimal strategy: leave remainder of (maxPerTurn+1) * k + 1
      // Optimal: leave _remaining such that (_remaining - aiTake - 1) % (_maxPerTurn + 1) == 0
      // i.e. leave a number where remainder mod (_maxPerTurn+1) == 1
      final mod = _maxPerTurn + 1;
      final idealRemaining = ((_remaining - 1) ~/ mod) * mod + 1;
      aiTake = _remaining - idealRemaining;

      if (aiTake < 1 || aiTake > math.min(_maxPerTurn, _remaining)) {
        // No winning move, take random
        aiTake = _random.nextInt(math.min(_maxPerTurn, _remaining)) + 1;
      }

      // For grade 2-3: sometimes make a mistake
      if (grade <= 3 && _random.nextDouble() < 0.2) {
        aiTake = _random.nextInt(math.min(_maxPerTurn, _remaining)) + 1;
      }
    }

    setState(() {
      _remaining -= aiTake;
      _moveHistory.add(_MoveRecord(isPlayer: false, count: aiTake, remainingAfter: _remaining));
      _isPlayerTurn = true;
    });

    // Check if AI took the last one (AI loses, player wins)
    if (_remaining <= 0) {
      _handleWin();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'asteroid_duel',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    _gameOver = true;

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'asteroid_duel',
      difficulty: widget.level,
    ));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildLoseDialog(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (_isGenerating || currentDifficulty == null) {
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
                title: s.asteroidDuelTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.asteroidDuelInstructions(_maxPerTurn),
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Asteroid field visualization
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE63946).withValues(alpha: _glowAnimation.value * 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$_remaining',
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 48,
                        color: _remaining <= 3 ? SpaceTheme.rocketRed : SpaceTheme.starYellow,
                      ),
                    ),
                    Text('asteroids remaining',
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 12),
                    // Asteroid dots
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: List.generate(_remaining, (i) {
                        return Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE63946), Color(0xFFFF6B35)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE63946).withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Turn indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isPlayerTurn
                  ? const Color(0xFF06FFA5).withValues(alpha: 0.2)
                  : const Color(0xFFE63946).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isPlayerTurn ? 'Your Turn' : 'Opponent thinking...',
              style: SpaceTheme.titleStyle.copyWith(
                color: _isPlayerTurn ? const Color(0xFF06FFA5) : const Color(0xFFE63946),
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (_isPlayerTurn && !_gameOver)
            Wrap(
              spacing: 12,
              children: List.generate(math.min(_maxPerTurn, _remaining), (i) {
                final count = i + 1;
                return ElevatedButton(
                  onPressed: () => _playerTake(count),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE63946),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Take $count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                );
              }),
            ),
          const SizedBox(height: 12),
          // Move history
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _moveHistory.length,
              itemBuilder: (context, index) {
                final move = _moveHistory[_moveHistory.length - 1 - index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: move.isPlayer
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: move.isPlayer
                              ? const Color(0xFF06FFA5).withValues(alpha: 0.2)
                              : const Color(0xFFE63946).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${move.isPlayer ? "You" : "AI"} took ${move.count} (${move.remainingAfter} left)',
                          style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinDialog(int totalScore) {
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
                  const Icon(Icons.sports_kabaddi, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.asteroidDuelWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.asteroidDuelWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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

  Widget _buildLoseDialog() {
    final s = S.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_kabaddi, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(s.asteroidDuelLoseTitle,
                style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.asteroidDuelLoseDesc,
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
    );
  }
}

class _MoveRecord {
  final bool isPlayer;
  final int count;
  final int remainingAfter;

  _MoveRecord({required this.isPlayer, required this.count, required this.remainingAfter});
}
