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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _removeController;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  int _totalAsteroids = 0;
  int _remaining = 0;
  int _maxPerTurn = 0;
  bool _isPlayerTurn = true;
  bool _isAiThinking = false;
  final List<_MoveRecord> _moveHistory = [];

  // Selection state for tap-to-select
  final Set<int> _selectedAsteroids = {};


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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _removeController = AnimationController(
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
    _glowController.stop();
    _successController.stop();
    _pulseController.stop();
    _removeController.stop();
    _glowController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    _removeController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _moveHistory.clear();
      _isPlayerTurn = true;
      _isAiThinking = false;
      _selectedAsteroids.clear();
      _successController.reset();
      _removeController.reset();
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

  void _toggleAsteroidSelection(int index) {
    if (_gameOver || !_isPlayerTurn || _isAiThinking) return;

    setState(() {
      if (_selectedAsteroids.contains(index)) {
        _selectedAsteroids.remove(index);
      } else {
        if (_selectedAsteroids.length < math.min(_maxPerTurn, _remaining)) {
          _selectedAsteroids.add(index);
        }
      }
    });
  }

  void _confirmSelection() {
    if (_selectedAsteroids.isEmpty) return;
    _playerTake(_selectedAsteroids.length);
  }

  void _playerTake(int count) {
    if (_gameOver || !_isPlayerTurn) return;
    if (count < 1 || count > math.min(_maxPerTurn, _remaining)) return;

    _removeController.forward(from: 0.0);

    setState(() {
      _remaining -= count;
      _selectedAsteroids.clear();
      _moveHistory.add(_MoveRecord(isPlayer: true, count: count, remainingAfter: _remaining));
      _isPlayerTurn = false;
    });

    // Check if player took the last one (player loses)
    if (_remaining <= 0) {
      _handleLoss();
      return;
    }

    // AI turn after a short delay
    setState(() => _isAiThinking = true);
    Future.delayed(const Duration(milliseconds: 700), () {
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

    _removeController.forward(from: 0.0);

    setState(() {
      _remaining -= aiTake;
      _moveHistory.add(_MoveRecord(isPlayer: false, count: aiTake, remainingAfter: _remaining));
      _isPlayerTurn = true;
      _isAiThinking = false;
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
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.4)),
                ),
                child: Text(
                  s.asteroidDuelInstructions(_maxPerTurn),
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 15, color: SpaceTheme.starYellow),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    if (isWide) {
                      return _buildWideLayout(constraints);
                    }
                    return _buildCompactLayout(constraints);
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
        Expanded(flex: 3, child: _buildAsteroidGrid(constraints)),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildControlPanel()),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Column(
      children: [
        // Turn indicator
        _buildTurnIndicator(),
        const SizedBox(height: 8),
        // Asteroid grid
        Expanded(flex: 3, child: _buildAsteroidGrid(constraints)),
        const SizedBox(height: 8),
        // Controls
        _buildActionButtons(),
        const SizedBox(height: 8),
        // Move history
        Expanded(flex: 1, child: _buildMoveHistory()),
      ],
    );
  }

  Widget _buildTurnIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _isPlayerTurn && !_isAiThinking
            ? const Color(0xFF06FFA5).withValues(alpha: 0.2)
            : SpaceTheme.rocketRed.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPlayerTurn && !_isAiThinking
              ? const Color(0xFF06FFA5).withValues(alpha: 0.6)
              : SpaceTheme.rocketRed.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isAiThinking) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SpaceTheme.rocketRed.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _isAiThinking ? 'AI THINKING...' : (_isPlayerTurn ? 'YOUR TURN' : 'AI TURN'),
            style: SpaceTheme.titleStyle.copyWith(
              color: _isPlayerTurn && !_isAiThinking
                  ? const Color(0xFF06FFA5)
                  : SpaceTheme.rocketRed,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsteroidGrid(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, gridConstraints) {
          const cols = 5;
          final maxCellW = (gridConstraints.maxWidth - 32) / cols;
          final rows = (_remaining / cols).ceil().clamp(1, 10);
          final maxCellH = (gridConstraints.maxHeight - 32) / rows;
          final cellSize = math.min(maxCellW, maxCellH).clamp(35.0, 70.0);

          return AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value * 0.7),
                  ),
                ),
                child: Center(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: List.generate(_remaining, (i) {
                      final isSelected = _selectedAsteroids.contains(i);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isPlayerTurn && !_gameOver && !_isAiThinking
                            ? () => _toggleAsteroidSelection(i)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: cellSize,
                          height: cellSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [SpaceTheme.starYellow, Color(0xFFFF6B35)],
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFE63946), Color(0xFFFF6B35)],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? SpaceTheme.starYellow.withValues(alpha: 0.8)
                                    : const Color(0xFFE63946).withValues(alpha: 0.4),
                                blurRadius: isSelected ? 12 : 4,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                            border: isSelected
                                ? Border.all(color: SpaceTheme.starYellow, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: CustomPaint(
                              size: Size(cellSize * 0.6, cellSize * 0.6),
                              painter: _AsteroidPainter(isSelected: isSelected, seed: i * 7 + 13),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTurnIndicator(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 16),
          Expanded(child: _buildMoveHistory()),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_gameOver || !_isPlayerTurn || _isAiThinking) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_selectedAsteroids.isNotEmpty) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value * 0.1 + 0.9,
                  child: ElevatedButton.icon(
                    onPressed: _confirmSelection,
                    icon: const Icon(Icons.rocket_launch, size: 20),
                    label: Text(
                      'Mine ${_selectedAsteroids.length}!',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpaceTheme.starYellow,
                      foregroundColor: SpaceTheme.deepSpace,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Tap asteroids to select (1-${math.min(_maxPerTurn, _remaining)})',
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          // Quick-select buttons as alternative
          Wrap(
            spacing: 8,
            children: List.generate(math.min(_maxPerTurn, _remaining), (i) {
              final count = i + 1;
              return OutlinedButton(
                onPressed: () => _playerTake(count),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SpaceTheme.rocketRed,
                  side: BorderSide(color: SpaceTheme.rocketRed.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveHistory() {
    if (_moveHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: move.isPlayer
                        ? const Color(0xFF06FFA5).withValues(alpha: 0.2)
                        : SpaceTheme.rocketRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${move.isPlayer ? "You" : "AI"} took ${move.count} (${move.remainingAfter} left)',
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SpaceTheme.starYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Hint: Try to leave ${_maxPerTurn + 1}+1 = ${_maxPerTurn + 2} asteroids for the AI. '
                'The key pattern is multiples of ${_maxPerTurn + 1}, plus 1.',
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: SpaceTheme.starYellow),
                textAlign: TextAlign.center,
              ),
            ),
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

class _AsteroidPainter extends CustomPainter {
  final bool isSelected;
  final int seed;

  _AsteroidPainter({required this.isSelected, this.seed = 42});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw jagged asteroid shape -- each asteroid unique via seed
    final path = Path();
    const segments = 8;
    final random = math.Random(seed);

    for (int i = 0; i < segments; i++) {
      final angle = (i * 2 * math.pi / segments) - math.pi / 2;
      final variation = 0.7 + random.nextDouble() * 0.3;
      final r = radius * variation;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = isSelected ? SpaceTheme.starYellow.withValues(alpha: 0.8) : Colors.white54
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AsteroidPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected || oldDelegate.seed != seed;
  }
}

class _MoveRecord {
  final bool isPlayer;
  final int count;
  final int remainingAfter;

  _MoveRecord({required this.isPlayer, required this.count, required this.remainingAfter});
}
