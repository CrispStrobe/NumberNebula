import '../services/galactic_market_logic.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
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
  const GalacticMarketGame(
      {super.key, required this.grade, required this.level});

  @override
  State<GalacticMarketGame> createState() => _GalacticMarketGameState();
}

class _GalacticMarketGameState extends State<GalacticMarketGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<GalacticMarketGame>,
        PuzzleSessionMixin<GalacticMarketGame> {
  bool _sessionReady = false;
  int _roundEpoch = 0;
  bool _reducedMotion = false;

  bool _canInteract(int epoch) =>
      mounted &&
      _sessionReady &&
      epoch == _roundEpoch &&
      !_isGenerating &&
      !_gameOver &&
      _attemptsUsed < _maxAttempts;

  bool _validDenom(int denom) => denom > 0 && _denomOptions.contains(denom);

  void _resetRoundEffects() {
    _roundEpoch++;
    cancelOneShotMotion(successController);
    successController.reset();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    _reducedMotion = reduced;
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @override
  String get sessionGameKey => 'galactic_market';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _gameOver) return null;
    return {
      '_changeTotal': _changeTotal,
      '_knownCoins': _knownCoins.map((v0) => v0).toList(),
      '_unknownCount': _unknownCount,
      '_correctDenomination': _correctDenomination,
      '_attemptsUsed': _attemptsUsed,
      '_constraintText': _constraintText,
      '_denomOptions': _denomOptions.map((v0) => v0).toList(),
      '_selectedDenom': (_selectedDenom),
      '_mathProblems': _mathProblems.map((v0) => v0.toJson()).toList()
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    _changeTotal = state["_changeTotal"] as int;
    _knownCoins =
        (state["_knownCoins"] as List).map((v0) => v0 as int).toList();
    _unknownCount = state["_unknownCount"] as int;
    _correctDenomination = state["_correctDenomination"] as int;
    _attemptsUsed = state["_attemptsUsed"] as int;
    _constraintText = state["_constraintText"] as String;
    _denomOptions =
        (state["_denomOptions"] as List).map((v0) => v0 as int).toList();
    final selected = state["_selectedDenom"];
    _selectedDenom = selected is int && _validDenom(selected) ? selected : null;
    _mathProblems
      ..clear()
      ..addAll((state["_mathProblems"] as List)
          .map((v0) =>
              MathProblem.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList());
    _isGenerating = false;
    // A correct selection alone may never have been submitted.
    _gameOver = _attemptsUsed >= _maxAttempts;
    if (_gameOver) {
      finishPuzzleSession();
      final epoch = _roundEpoch;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showLoseDialog(epoch));
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

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
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level,
            gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _roundEpoch++;
    cancelOneShotMotion(successController);
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    _resetRoundEffects();
    beginPuzzleSession();
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

    final generated =
        generateGalacticMarket(grade, widget.level, random: _random);
    _changeTotal = generated['_changeTotal'] as int;
    _correctDenomination = generated['_correctDenomination'] as int;
    _denomOptions = List<int>.from(generated['_denomOptions'] as List);
    _knownCoins = List<int>.from(generated['_knownCoins'] as List);
    _mathProblems.addAll((generated['_mathProblems'] as List)
        .map((p) => MathProblem.fromJson(Map<String, dynamic>.from(p as Map))));
    _unknownCount = generated['_unknownCount'] as int;
    _constraintText = _unknownCount == 1
        ? S.of(context)!.galacticMarketOneCoin
        : S.of(context)!.galacticMarketNCoins(_unknownCount);
    setState(() => _isGenerating = false);
  }

  void _selectDenom(int denom, int epoch) {
    if (!_canInteract(epoch) || !_validDenom(denom)) return;
    AppHaptics.selectionClick();
    setState(() => _selectedDenom = denom);
  }

  void _submitAnswer(int epoch) {
    if (!_canInteract(epoch) ||
        _selectedDenom == null ||
        !_validDenom(_selectedDenom!)) {
      return;
    }

    if (_selectedDenom == _correctDenomination) {
      _handleWin();
    } else {
      _handleWrongAnswer();
    }
  }

  void _handleWrongAnswer() {
    if (!_canInteract(_roundEpoch)) return;
    setState(() => _attemptsUsed++);
    AppHaptics.heavyImpact();

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
    if (!mounted || !_sessionReady || _isGenerating || _gameOver) return;
    _resetRoundEffects();
    setState(() => _gameOver = true);
    final epoch = _roundEpoch;
    finishPuzzleSession();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'galactic_market',
          difficulty: widget.level,
          mathProblems: List<MathProblem>.unmodifiable(_mathProblems),
        ));
    _showLoseDialog(epoch);
  }

  void _showLoseDialog(int epoch) {
    if (!mounted ||
        !_sessionReady ||
        epoch != _roundEpoch ||
        !_gameOver ||
        _isGenerating) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildLoseDialog(epoch, dialogContext),
    );
  }

  bool _canUseDialog(int epoch, BuildContext dialogContext) =>
      mounted &&
      epoch == _roundEpoch &&
      _gameOver &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  void _handleWin() {
    if (!_canInteract(_roundEpoch) || _selectedDenom != _correctDenomination) {
      return;
    }
    _resetRoundEffects();
    setState(() => _gameOver = true);
    final epoch = _roundEpoch;
    AppHaptics.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    // Solving it outright is worth more than arriving by elimination.
    int attemptBonus = (_maxAttempts - _attemptsUsed) * 50 * widget.grade;
    int totalScore = baseScore + levelBonus + attemptBonus;

    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'galactic_market',
          difficulty: widget.level,
          score: totalScore,
          mathProblems: List<MathProblem>.unmodifiable(_mathProblems),
          performance: Perf.fromAttempts(_attemptsUsed + 1, _maxAttempts),
        ));

    playOneShotMotion(successController, () {});
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _buildWinDialog(totalScore, epoch, dialogContext),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = S.of(context)!;
    final epoch = _roundEpoch;

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
                key: ValueKey('market-header-$epoch'),
                title: s.galacticMarketTitle,
                level: widget.level,
                onBack: () {
                  if (mounted &&
                      _sessionReady &&
                      epoch == _roundEpoch &&
                      !_isGenerating) {
                    Navigator.of(context).pop();
                  }
                },
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
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: SpaceTheme.starYellow, size: 18),
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
              color: SpaceTheme.starYellow
                  .withValues(alpha: glowAnimation.value * 0.5),
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
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Known coins stay before the hidden coins on every row.
          ..._knownCoins.map((d) => _buildCoin(d, faceUp: true)),
          ...List.generate(
              _unknownCount, (_) => _buildCoin(null, faceUp: false)),
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
                style: SpaceTheme.headlineStyle
                    .copyWith(fontSize: 18, color: Colors.white),
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
    final question = Row(
      children: [
        const Icon(Icons.help_outline,
            color: SpaceTheme.nebulaPurple, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_constraintText,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13)),
        ),
      ],
    );
    // Keep the scan budget visible before committing, including at large text.
    final attempts = Container(
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
        S
            .of(context)!
            .galacticMarketAttempts(_maxAttempts - _attemptsUsed, _maxAttempts),
        softWrap: true,
        style: SpaceTheme.bodyStyle.copyWith(
          fontSize: 11,
          color:
              _attemptsUsed == 0 ? SpaceTheme.alienGreen : SpaceTheme.rocketRed,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.nebulaPurple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.4)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final badgeScale = MediaQuery.textScalerOf(context).scale(11) / 11;
        if (constraints.maxWidth >= 480 * badgeScale) {
          return Row(children: [
            Expanded(child: question),
            const SizedBox(width: 8),
            attempts,
          ]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            question,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: attempts),
          ],
        );
      }),
    );
  }

  Widget _buildDenominationPicker() {
    final epoch = _roundEpoch;
    return Column(
      children: [
        Text(
          S.of(context)!.galacticMarketDenominationQuestion,
          style: SpaceTheme.titleStyle
              .copyWith(fontSize: 14, color: SpaceTheme.starYellow),
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
              key: ValueKey('market-denom-$epoch-$denom'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectDenom(denom, epoch),
              child: AnimatedContainer(
                duration: _reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? color.withValues(alpha: 0.4)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.5),
                  border: Border.all(
                    color: isSelected ? color : Colors.white24,
                    width: isSelected ? 3 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2)
                        ]
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
    final epoch = _roundEpoch;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: ValueKey('market-submit-$epoch'),
        onPressed: _canInteract(epoch) &&
                _selectedDenom != null &&
                _validDenom(_selectedDenom!)
            ? () => _submitAnswer(epoch)
            : null,
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
  Widget _buildLoseDialog(int epoch, BuildContext dialogContext) {
    final s = S.of(context)!;
    final knownTotal = _knownCoins.fold(0, (a, c) => a + c);
    final hiddenTotal = _unknownCount * _correctDenomination;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundSummary(gameKey: 'galactic_market'),
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
                    if (!_canUseDialog(epoch, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.playAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_canUseDialog(epoch, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
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

  Widget _buildWinDialog(int score, int epoch, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'galactic_market'),
                  const Icon(Icons.storefront,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.galacticMarketWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
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
                          if (!_canUseDialog(epoch, dialogContext)) return;
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseDialog(epoch, dialogContext)) return;
                          Navigator.of(dialogContext).pop();
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
