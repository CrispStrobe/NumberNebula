import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
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
    with TickerProviderStateMixin, GameAnimationsMixin<GalacticMarketGame> {

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
  int _changeTotal = 0; // total change to give back
  List<int> _knownCoins = []; // coins already visible (face-up)
  int _unknownCount = 0; // number of face-down coins
  int _correctDenomination = 0; // the answer

  /// Wrong denominations submitted before the correct one.
  /// Wrong scans allowed before the round is lost.
  ///
  /// The game had no losing condition at all: a wrong answer cleared the
  /// selection and let the player pick again, forever. With five options and
  /// no cost to being wrong, tapping every coin in turn solved it in about
  /// three taps, so there was never a reason to do the arithmetic -- which is
  /// the entire point of the game.
  ///
  /// Two attempts forgives one slip and still leaves guessing a losing
  /// strategy: blind picking wins at most two times in five, while working the
  /// answer out wins every time.
  static const int _maxAttempts = 2;
  int _attemptsUsed = 0;
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
    initGameAnimations(usePulse: false);

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
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _attemptsUsed = 0;
      _selectedDenom = null;
      _mathProblems.clear();
      successController.reset();
    });

    final grade = currentDifficulty!.grade;

    final level = widget.level;

    // Unknown coin count — grade sets base, level adds progression
    //   Grade 1: 2 → 4 over 20 levels
    //   Grade 2: 3 → 6 over 20 levels
    //   Grade 3: 4 → 7 over 20 levels
    //   Grade 4: 4 → 8 over 20 levels
    final baseUnknown = [0, 2, 3, 4, 4][grade.clamp(0, 4)];
    final maxUnknown = [0, 4, 6, 7, 8][grade.clamp(0, 4)];
    _unknownCount = baseUnknown +
        ((level - 1) * (maxUnknown - baseUnknown) / 19).round();

    // Denomination pool — grade gates which values appear, level expands
    final List<int> availDenoms;
    if (grade <= 1) {
      // Start with [1,2,5], add 10 at L6, add 20 at L14
      availDenoms = [1, 2, 5];
      if (level >= 6) availDenoms.add(10);
      if (level >= 14) availDenoms.add(20);
    } else if (grade <= 2) {
      // Start with [1,2,5,10], add 20 at L4, add 50 at L12
      availDenoms = [1, 2, 5, 10];
      if (level >= 4) availDenoms.add(20);
      if (level >= 12) availDenoms.add(50);
    } else {
      // Full pool from the start; higher denoms make arithmetic harder
      availDenoms = List.of(_allDenoms);
    }
    _correctDenomination = availDenoms[_random.nextInt(availDenoms.length)];

    final unknownTotal = _correctDenomination * _unknownCount;

    // Known (distractor) coins — more at higher levels for harder sums
    //   Grade 1: 1 → 3 over 20 levels
    //   Grade 2: 2 → 4 over 20 levels
    //   Grade 3+: 2 → 5 over 20 levels
    final baseKnown = grade <= 1 ? 1 : 2;
    final maxKnown = grade <= 1 ? 3 : (grade <= 2 ? 4 : 5);
    final knownCount = baseKnown +
        ((level - 1) * (maxKnown - baseKnown) / 19).round();
    _knownCoins = [];
    for (int i = 0; i < knownCount; i++) {
      _knownCoins.add(availDenoms[_random.nextInt(availDenoms.length)]);
    }

    final knownTotal = _knownCoins.fold(0, (s, c) => s + c);
    _changeTotal = knownTotal + unknownTotal;

    _constraintText = _unknownCount == 1
        ? S.of(context)!.galacticMarketOneCoin
        : S.of(context)!.galacticMarketNCoins(_unknownCount);

    // Generate denomination options (include correct + distractors)
    final options = <int>{_correctDenomination};
    for (final d in availDenoms) {
      options.add(d);
      if (options.length >= 5) break;
    }
    if (options.length < 5) {
      final available = _allDenoms.where((d) => !options.contains(d)).toList()
        ..shuffle(_random);
      options.addAll(available.take(5 - options.length));
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
      _handleWrongAnswer();
    }
  }

  void _handleWrongAnswer() {
    _attemptsUsed++;
    HapticFeedback.heavyImpact();

    if (_attemptsUsed >= _maxAttempts) {
      _handleLose();
      return;
    }

    // Name the method rather than just saying "wrong": a child who guessed
    // needs to be told what to do instead, and a child who miscalculated
    // needs to know which step to check.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.galacticMarketWrongScan),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() => _selectedDenom = null);
  }

  void _handleLose() {
    _gameOver = true;
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'galactic_market',
      difficulty: widget.level,
    ));
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildLoseDialog(),
      );
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    // Solving it outright is worth more than arriving by elimination.
    int attemptBonus = (_maxAttempts - _attemptsUsed) * 50 * widget.grade;
    int totalScore = baseScore + levelBonus + attemptBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'galactic_market',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: _mathProblems,
      performance: Perf.fromAttempts(_attemptsUsed + 1, _maxAttempts),
    ));

    successController.forward(from: 0.0);
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
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeDisplay() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.starYellow.withValues(alpha: glowAnimation.value * 0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                S.of(context)!.galacticMarketTotalChange,
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context)!.galacticMarketCredits(_changeTotal),
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
          // The cost of being wrong, shown before the player commits. Kept
          // next to the question rather than tucked in a corner: a counter
          // noticed only after a wrong answer changes nothing about how the
          // answer was chosen.
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_attemptsUsed == 0
                        ? SpaceTheme.alienGreen
                        : SpaceTheme.rocketRed)
                    .withValues(alpha: 0.8),
              ),
            ),
            child: Text(
              S.of(context)!.galacticMarketAttempts(
                  _maxAttempts - _attemptsUsed, _maxAttempts),
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 11,
                color: _attemptsUsed == 0
                    ? SpaceTheme.alienGreen
                    : SpaceTheme.rocketRed,
              ),
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
          S.of(context)!.galacticMarketDenominationQuestion,
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
              behavior: HitTestBehavior.opaque,
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
            ? S.of(context)!.galacticMarketSubmitEach(_selectedDenom!)
            : S.of(context)!.galacticMarketSelectDenom),
        style: SpaceTheme.primaryButtonStyle,
      ),
    );
  }

  /// Shown when the scans run out.
  ///
  /// It reveals the answer *with the arithmetic that reaches it*, because a
  /// child who ran out of attempts is exactly the one who needs to see the
  /// method worked through once. Telling them only the number teaches nothing.
  Widget _buildLoseDialog() {
    final s = S.of(context)!;
    final knownTotal = _knownCoins.fold(0, (a, c) => a + c);
    final hiddenTotal = _unknownCount * _correctDenomination;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(s.galacticMarketLoseTitle,
                style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              '$_changeTotal − $knownTotal = $hiddenTotal\n'
              '$hiddenTotal ÷ $_unknownCount = $_correctDenomination',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 18,
                color: SpaceTheme.starYellow,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(s.galacticMarketReveal(_correctDenomination),
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
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

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
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
                    '${s.galacticMarketReveal(_correctDenomination)}\n'
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
                        autofocus: true,
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
