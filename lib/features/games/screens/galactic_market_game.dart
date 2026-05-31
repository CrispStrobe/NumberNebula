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
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
  int _target = 0;
  List<int> _denominations = [];
  final List<int> _paymentCoins = []; // coins dropped into payment area (values)
  int _currentTotal = 0;
  int _optimalCount = 0;

  // Math problems for SRI
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  static const List<String> _coinNames = [
    'Nova', 'Pulsar', 'Quasar', 'Nebula', 'Photon', 'Graviton', 'Meson',
  ];

  // Coin colors matching denominations
  static const List<Color> _coinColors = [
    Color(0xFFFFD700), // gold
    Color(0xFFC0C0C0), // silver
    Color(0xFFE57373), // light red
    Color(0xFF06FFA5), // green
    Color(0xFF6B48FF), // purple
    Color(0xFF00C9DB), // cyan
    Color(0xFFFF69B4), // pink
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

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _dropAnimation =
        CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0)
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
    _glowController.stop();
    _successController.stop();
    _dropController.stop();
    _pulseController.stop();
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _paymentCoins.clear();
      _currentTotal = 0;
      _mathProblems.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;

    if (grade <= 2) {
      _denominations = [1, 2, 5];
      _target = _random.nextInt(15) + 5;
    } else {
      _denominations = [1, 2, 5, 10, 25];
      if (grade >= 4) _denominations.add(50);
      _target = _random.nextInt(80) + 20;
    }

    _denominations.sort((a, b) => b.compareTo(a));
    _optimalCount = _calculateOptimalCoins(_target, _denominations);

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
    if (_currentTotal + denomination > _target) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _paymentCoins.add(denomination);
      _currentTotal += denomination;
    });
    _dropController.forward(from: 0.0);

    if (_currentTotal == _target) {
      _handleWin();
    }
  }

  void _removeCoinAt(int index) {
    if (_gameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentTotal -= _paymentCoins[index];
      _paymentCoins.removeAt(index);
    });
  }

  void _resetCoins() {
    if (_gameOver) return;
    setState(() {
      _paymentCoins.clear();
      _currentTotal = 0;
    });
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    final totalCoins = _paymentCoins.length;
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int efficiencyBonus = totalCoins <= _optimalCount
        ? 100
        : math.max(0, 50 - (totalCoins - _optimalCount) * 10);
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildTargetDisplay(),
                const SizedBox(height: 12),
                Expanded(child: _buildPaymentArea()),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: _buildCoinTray(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _buildTargetDisplay(),
          const SizedBox(height: 8),
          Expanded(flex: 3, child: _buildPaymentArea()),
          const SizedBox(height: 8),
          Expanded(flex: 4, child: _buildCoinTray()),
          if (!_gameOver) ...[
            const SizedBox(height: 6),
            _buildResetButton(),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTargetDisplay() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.starYellow
                  .withValues(alpha: _glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceTheme.starYellow
                    .withValues(alpha: _glowAnimation.value * 0.3),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              // Target
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Target',
                        style: SpaceTheme.bodyStyle
                            .copyWith(color: Colors.white70, fontSize: 11)),
                    Text('$_target',
                        style: SpaceTheme.headlineStyle.copyWith(
                            fontSize: 32, color: SpaceTheme.starYellow)),
                  ],
                ),
              ),
              // Current total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Current',
                        style: SpaceTheme.bodyStyle
                            .copyWith(color: Colors.white70, fontSize: 11)),
                    Text('$_currentTotal',
                        style: SpaceTheme.headlineStyle.copyWith(
                          fontSize: 32,
                          color: _currentTotal == _target
                              ? SpaceTheme.alienGreen
                              : Colors.white,
                        )),
                  ],
                ),
              ),
              // Optimal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Optimal',
                        style: SpaceTheme.bodyStyle
                            .copyWith(color: Colors.white70, fontSize: 11)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars,
                            color: SpaceTheme.starYellow, size: 16),
                        const SizedBox(width: 4),
                        Text('$_optimalCount coins',
                            style: SpaceTheme.bodyStyle.copyWith(
                                fontSize: 12, color: SpaceTheme.starYellow)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentArea() {
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: isHovering
                  ? [
                      SpaceTheme.starYellow.withValues(alpha: 0.15),
                      SpaceTheme.deepSpace.withValues(alpha: 0.8),
                    ]
                  : [
                      SpaceTheme.deepSpace.withValues(alpha: 0.6),
                      SpaceTheme.nebulaPurple.withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering
                  ? SpaceTheme.starYellow
                  : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
              width: isHovering ? 3 : 2,
            ),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: _paymentCoins.isEmpty
              ? Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments,
                                color: isHovering
                                    ? SpaceTheme.starYellow
                                    : SpaceTheme.nebulaPurple,
                                size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Drop coins here',
                              style: SpaceTheme.bodyStyle.copyWith(
                                color: isHovering
                                    ? SpaceTheme.starYellow
                                    : Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              : _buildPlacedCoins(),
        );
      },
      onWillAcceptWithDetails: (details) {
        return !_gameOver && _currentTotal + details.data <= _target;
      },
      onAcceptWithDetails: (details) {
        _addCoin(details.data);
      },
    );
  }

  Widget _buildPlacedCoins() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(_paymentCoins.length, (index) {
            final denom = _paymentCoins[index];
            final denomIdx = _denominations.indexOf(denom);
            final color = _coinColors[denomIdx.clamp(0, _coinColors.length - 1)];
            final isLast = index == _paymentCoins.length - 1;

            Widget coin = GestureDetector(
              onTap: () => _removeCoinAt(index),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(color, Colors.white, 0.3)!,
                      color,
                    ],
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$denom',
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );

            if (isLast) {
              coin = ScaleTransition(scale: _dropAnimation, child: coin);
            }
            return coin;
          }),
        ),
      ),
    );
  }

  Widget _buildCoinTray() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCoinSize = (constraints.maxWidth - 48) / 3;
        final coinSize = maxCoinSize.clamp(50.0, 90.0);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5), width: 2),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: _denominations.length,
            itemBuilder: (context, index) {
              final denom = _denominations[index];
              final color = _coinColors[index % _coinColors.length];
              final nameIndex = index % _coinNames.length;
              final canAdd = _currentTotal + denom <= _target && !_gameOver;

              return Draggable<int>(
                data: denom,
                maxSimultaneousDrags: canAdd ? 1 : 0,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: coinSize,
                    height: coinSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(color, Colors.white, 0.3)!,
                          color,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.8),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$denom',
                        style: SpaceTheme.headlineStyle
                            .copyWith(fontSize: coinSize * 0.3, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildCoinWidget(denom, color, _coinNames[nameIndex], canAdd),
                ),
                child: _buildCoinWidget(denom, color, _coinNames[nameIndex], canAdd),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCoinWidget(int denomination, Color color, String name, bool canAdd) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: canAdd
              ? [Color.lerp(color, Colors.white, 0.2)!, color, color.withValues(alpha: 0.7)]
              : [Colors.grey.shade700, Colors.grey.shade800],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: canAdd ? color.withValues(alpha: 0.8) : Colors.grey.shade600,
          width: 2,
        ),
        boxShadow: canAdd
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$denomination',
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: 20,
                color: canAdd ? Colors.white : Colors.grey,
              )),
          Text(name,
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 9,
                color: canAdd ? Colors.white70 : Colors.grey,
              )),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: _paymentCoins.isEmpty ? null : _resetCoins,
      style: SpaceTheme.secondaryButtonStyle,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text(S.of(context)!.playAgain),
    );
  }

  Widget _buildWinDialog(int coins, int totalScore) {
    final s = S.of(context)!;
    final isOptimal = coins <= _optimalCount;
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
                  if (isOptimal)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SpaceTheme.starYellow),
                        ),
                        child: Text(
                          'Optimal solution!',
                          style: SpaceTheme.bodyStyle.copyWith(
                            color: SpaceTheme.starYellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
          ),
        );
      },
    );
  }
}
