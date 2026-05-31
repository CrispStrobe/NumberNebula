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
  int _changeTotal = 0; // total change to give back
  List<int> _knownCoins = []; // coins already visible (face-up)
  int _unknownCount = 0; // number of face-down coins
  int _correctDenomination = 0; // the answer
  String _constraintText = '';
  List<int> _denomOptions = []; // available denomination choices
  int? _selectedDenom;

  // SRI tracking
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  // Alien coin denominations
  static const _allDenoms = [1, 2, 5, 10, 20, 50];
  static const _denomColors = {
    1: Color(0xFF8B7355),
    2: Color(0xFFCD853F),
    5: Color(0xFFC0C0C0),
    10: Color(0xFFFFD700),
    20: Color(0xFF06FFA5),
    50: Color(0xFF6B48FF),
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
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _selectedDenom = null;
      _mathProblems.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;

    // Pick how many unknown coins (all same denomination)
    _unknownCount = grade <= 1 ? 3 : (grade <= 2 ? 3 : (_random.nextInt(2) + 3));

    // Pick a valid denomination for the unknowns
    final availDenoms = grade <= 1
        ? [1, 2, 5]
        : grade <= 2
            ? [1, 2, 5, 10]
            : _allDenoms;
    _correctDenomination = availDenoms[_random.nextInt(availDenoms.length)];

    final unknownTotal = _correctDenomination * _unknownCount;

    // Generate 1-3 known coins
    final knownCount = grade <= 1 ? 1 : (1 + _random.nextInt(2));
    _knownCoins = [];
    for (int i = 0; i < knownCount; i++) {
      _knownCoins.add(availDenoms[_random.nextInt(availDenoms.length)]);
    }

    final knownTotal = _knownCoins.fold(0, (s, c) => s + c);
    _changeTotal = knownTotal + unknownTotal;

    _constraintText = _unknownCount == 1
        ? 'One coin is face-down.'
        : 'The $_unknownCount face-down coins all have the same value.';

    // Generate denomination options (include correct + distractors)
    final options = <int>{_correctDenomination};
    for (final d in availDenoms) {
      options.add(d);
      if (options.length >= 5) break;
    }
    while (options.length < 5) {
      options.add(_allDenoms[_random.nextInt(_allDenoms.length)]);
    }
    _denomOptions = options.toList()..sort();

    // Create math problem for SRI
    _mathProblems.add(MathProblem.division(unknownTotal, _unknownCount, difficulty: grade));

    setState(() => _isGenerating = false);
  }

  void _selectDenom(int denom) {
    if (_gameOver) return;
    setState(() => _selectedDenom = denom);
  }

  void _submitAnswer() {
    if (_gameOver || _selectedDenom == null) return;

    if (_selectedDenom == _correctDenomination) {
      _handleWin();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.galacticMarketLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() => _selectedDenom = null);
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int totalScore = baseScore + levelBonus;

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
        builder: (_) => _buildWinDialog(totalScore),
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInstructions(s),
                      const SizedBox(height: 12),
                      _buildChangeDisplay(),
                      const SizedBox(height: 12),
                      _buildCoinTable(),
                      const SizedBox(height: 12),
                      _buildConstraintBanner(),
                      const SizedBox(height: 16),
                      _buildDenominationPicker(),
                      const SizedBox(height: 16),
                      if (!_gameOver) _buildSubmitButton(),
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
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.galacticMarketInstructions,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeDisplay() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value * 0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'TOTAL CHANGE',
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_changeTotal credits',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoinTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Known coins (face-up)
          ..._knownCoins.map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildCoin(d, faceUp: true),
              )),
          // Unknown coins (face-down)
          ...List.generate(_unknownCount, (_) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildCoin(null, faceUp: false),
              )),
        ],
      ),
    );
  }

  Widget _buildCoin(int? value, {required bool faceUp}) {
    final color = faceUp && value != null
        ? (_denomColors[value] ?? SpaceTheme.starYellow)
        : const Color(0xFF333344);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: faceUp ? 0.4 : 0.6),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
        ],
      ),
      child: Center(
        child: faceUp
            ? Text(
                '$value',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 18, color: Colors.white),
              )
            : const Text(
                '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.starYellow,
                ),
              ),
      ),
    );
  }

  Widget _buildConstraintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.nebulaPurple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: SpaceTheme.nebulaPurple, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _constraintText,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationPicker() {
    return Column(
      children: [
        Text(
          'What denomination are the hidden coins?',
          style: SpaceTheme.titleStyle.copyWith(fontSize: 14, color: SpaceTheme.starYellow),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _denomOptions.map((denom) {
            final isSelected = _selectedDenom == denom;
            final color = _denomColors[denom] ?? SpaceTheme.starYellow;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _selectDenom(denom);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color.withValues(alpha: 0.4) : SpaceTheme.deepSpace.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isSelected ? color : Colors.white24,
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$denom',
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 20,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectedDenom != null ? _submitAnswer : null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(_selectedDenom != null
            ? 'Each hidden coin = $_selectedDenom credits'
            : 'Select a denomination'),
        style: SpaceTheme.primaryButtonStyle,
      ),
    );
  }

  Widget _buildWinDialog(int score) {
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
                  const SizedBox(height: 12),
                  Text(
                    'The hidden coins were each $_correctDenomination credits!\n'
                    '$_unknownCount × $_correctDenomination = ${_unknownCount * _correctDenomination}',
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(s.galacticMarketWinDesc(_unknownCount, score),
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
