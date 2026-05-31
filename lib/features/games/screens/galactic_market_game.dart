import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';

class GalacticMarketGame extends StatefulWidget {
  final int grade;
  final int level;
  const GalacticMarketGame({super.key, required this.grade, required this.level});

  @override
  State<GalacticMarketGame> createState() => _GalacticMarketGameState();
}

class _GalacticMarketGameState extends State<GalacticMarketGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
  int _target = 0;
  List<int> _denominations = [];
  Map<int, int> _selectedCoins = {}; // denomination -> count used
  int _currentTotal = 0;
  int _optimalCount = 0; // fewest coins possible (greedy)

  // Math problems for SRI
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  static const List<String> _coinNames = [
    'Nova', 'Pulsar', 'Quasar', 'Nebula', 'Photon', 'Graviton', 'Meson',
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
      _mathProblems.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;

    if (grade <= 2) {
      // Easy: target < 20, 3 denominations
      _denominations = [1, 2, 5];
      _target = _random.nextInt(15) + 5; // 5-19
    } else {
      // Hard: target < 100, 5+ denominations
      _denominations = [1, 2, 5, 10, 25];
      if (grade >= 4) _denominations.add(50);
      _target = _random.nextInt(80) + 20; // 20-99
    }

    _denominations.sort((a, b) => b.compareTo(a));
    _selectedCoins = {for (final d in _denominations) d: 0};
    _currentTotal = 0;

    // Calculate optimal (greedy works for these denominations)
    _optimalCount = _calculateOptimalCoins(_target, _denominations);

    // Create MathProblem for SRI
    _mathProblems.add(MathProblem.addition(_target, 0, difficulty: grade));

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  int _calculateOptimalCoins(int target, List<int> denoms) {
    int remaining = target;
    int count = 0;
    for (final d in denoms) {
      count += remaining ~/ d;
      remaining = remaining % d;
    }
    return count;
  }

  void _addCoin(int denomination) {
    if (_gameOver) return;
    if (_currentTotal + denomination > _target) return;

    setState(() {
      _selectedCoins[denomination] = (_selectedCoins[denomination] ?? 0) + 1;
      _currentTotal += denomination;
    });

    if (_currentTotal == _target) {
      _handleWin();
    }
  }

  void _removeCoin(int denomination) {
    if (_gameOver) return;
    if ((_selectedCoins[denomination] ?? 0) <= 0) return;

    setState(() {
      _selectedCoins[denomination] = _selectedCoins[denomination]! - 1;
      _currentTotal -= denomination;
    });
  }

  void _resetCoins() {
    if (_gameOver) return;
    setState(() {
      _selectedCoins = {for (final d in _denominations) d: 0};
      _currentTotal = 0;
    });
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    final totalCoins = _selectedCoins.values.fold(0, (a, b) => a + b);
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int efficiencyBonus = totalCoins <= _optimalCount ? 100 : math.max(0, 50 - (totalCoins - _optimalCount) * 10);
    int totalScore = baseScore + levelBonus + efficiencyBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'galactic_market',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: _mathProblems,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalCoins, totalScore),
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
                title: s.galacticMarketTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.galacticMarketInstructions,
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
          // Target display
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value * 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text('Target', style: SpaceTheme.bodyStyle.copyWith(color: Colors.white70, fontSize: 13)),
                    Text('$_target',
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 42, color: SpaceTheme.starYellow)),
                    const SizedBox(height: 8),
                    Text('Current: $_currentTotal',
                        style: SpaceTheme.titleStyle.copyWith(
                          color: _currentTotal == _target ? Colors.green : Colors.white,
                          fontSize: 18,
                        )),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _target > 0 ? _currentTotal / _target : 0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentTotal <= _target ? const Color(0xFF06FFA5) : SpaceTheme.rocketRed,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Coin buttons
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _denominations.length,
              itemBuilder: (context, index) {
                final denom = _denominations[index];
                final count = _selectedCoins[denom] ?? 0;
                final nameIndex = index % _coinNames.length;
                return _buildCoinButton(denom, count, _coinNames[nameIndex]);
              },
            ),
          ),
          const SizedBox(height: 8),
          // Reset button
          if (!_gameOver)
            ElevatedButton.icon(
              onPressed: _resetCoins,
              style: SpaceTheme.secondaryButtonStyle,
              icon: const Icon(Icons.refresh),
              label: Text(S.of(context)!.playAgain),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCoinButton(int denomination, int count, String name) {
    final bool canAdd = _currentTotal + denomination <= _target && !_gameOver;
    return GestureDetector(
      onTap: canAdd ? () => _addCoin(denomination) : null,
      onLongPress: count > 0 ? () => _removeCoin(denomination) : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canAdd
                ? [const Color(0xFFFFD700), const Color(0xFFFF6B35)]
                : [Colors.grey.shade800, Colors.grey.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: count > 0 ? SpaceTheme.starYellow : Colors.white24,
            width: count > 0 ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$denomination',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)),
            Text(name, style: SpaceTheme.bodyStyle.copyWith(fontSize: 10)),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('x$count',
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: SpaceTheme.starYellow)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinDialog(int coins, int totalScore) {
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
                  const Icon(Icons.storefront, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.galacticMarketWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.galacticMarketWinDesc(coins, totalScore),
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
}
