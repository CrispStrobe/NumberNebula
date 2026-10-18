import '../services/xenobiology_lab_logic.dart';
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

class XenobiologyLabGame extends StatefulWidget {
  final int grade;
  final int level;
  const XenobiologyLabGame({super.key, required this.grade, required this.level});

  @override
  State<XenobiologyLabGame> createState() => _XenobiologyLabGameState();
}

class _XenobiologyLabGameState extends State<XenobiologyLabGame>
    with TickerProviderStateMixin, GameAnimationsMixin<XenobiologyLabGame>, PuzzleSessionMixin<XenobiologyLabGame> {
  bool _sessionReady = false;
  Object _round = Object();
  bool _won = false;
  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      !_gameOver &&
      currentDifficulty != null;

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    successController.reset();
    _clearFeedback();
  }

  void _clearFeedback() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(successController, reduced, duration: const Duration(milliseconds: 600));
  }

  @visibleForTesting
  Object get testRound => _round;
  @visibleForTesting
  void rebuildForTesting() => setState(() {});
  @visibleForTesting
  void setSliderForTesting(int which, int value, Object round) => _setSlider(which, value, round);
  @visibleForTesting
  void checkForTesting(Object round) => _checkSolution(round);
  @visibleForTesting
  Future<void> generateForTesting() async {
    _generatePuzzle();
  }

  @override
  String get sessionGameKey => 'xenobiology_lab';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won || _gameOver) return null;
    return {
      '_eyesA': _eyesA,
      '_legsA': _legsA,
      '_eyesB': _eyesB,
      '_legsB': _legsB,
      '_countA': _countA,
      '_countB': _countB,
      '_totalEyes': _totalEyes,
      '_totalLegs': _totalLegs,
      '_nameA': _nameA,
      '_nameB': _nameB,
      '_hasThirdType': _hasThirdType,
      '_eyesC': _eyesC,
      '_legsC': _legsC,
      '_countC': _countC,
      '_nameC': _nameC,
      '_sliderA': _sliderA,
      '_sliderB': _sliderB,
      '_sliderC': _sliderC,
      '_maxSliderValue': _maxSliderValue,
      '_mathProblems': _mathProblems.map((v0) => v0.toJson()).toList(),
      '_wrongChecks': _wrongChecks
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    _eyesA = state['_eyesA'] as int;
    _legsA = state['_legsA'] as int;
    _eyesB = state['_eyesB'] as int;
    _legsB = state['_legsB'] as int;
    _countA = state['_countA'] as int;
    _countB = state['_countB'] as int;
    _totalEyes = state['_totalEyes'] as int;
    _totalLegs = state['_totalLegs'] as int;
    _nameA = state['_nameA'] as String;
    _nameB = state['_nameB'] as String;
    _hasThirdType = state['_hasThirdType'] as bool;
    _eyesC = state['_eyesC'] as int;
    _legsC = state['_legsC'] as int;
    _countC = state['_countC'] as int;
    _nameC = state['_nameC'] as String;
    _sliderA = state['_sliderA'] as int;
    _sliderB = state['_sliderB'] as int;
    _sliderC = state['_sliderC'] as int;
    _maxSliderValue = state['_maxSliderValue'] as int;
    _mathProblems
      ..clear()
      ..addAll((state['_mathProblems'] as List)
          .map((v0) => MathProblem.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList());
    _wrongChecks = state['_wrongChecks'] as int;
    _isGenerating = false;
    _gameOver = false;
    _won = false;
    // If the restored snapshot is already solved, treat it as a won terminal
    // state: show the win dialog once rather than leaving the board stuck
    // in a finished-but-not-reported loop.
    final isSolved = matchesCensusTotals({
      '_maxSliderValue': _maxSliderValue,
      '_hasThirdType': _hasThirdType,
      '_eyesA': _eyesA,
      '_eyesB': _eyesB,
      '_eyesC': _eyesC,
      '_legsA': _legsA,
      '_legsB': _legsB,
      '_legsC': _legsC,
      '_totalEyes': _totalEyes,
      '_totalLegs': _totalLegs,
      '_countA': _countA,
      '_countB': _countB,
      '_countC': _countC,
    }, _sliderA, _sliderB, _sliderC);
    if (isSolved) {
      _gameOver = true;
      _won = true;
      finishPuzzleSession();
      final round = _round;
      final score = _winScore();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(round, _round) || !_won) return;
        _showWinDialog(score, round);
      });
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

  /// Wrong specimen counts submitted before the right one.
  int _wrongChecks = 0;

  // Puzzle data
  int _eyesA = 0, _legsA = 0;
  int _eyesB = 0, _legsB = 0;
  int _countA = 0, _countB = 0;
  int _totalEyes = 0, _totalLegs = 0;
  String _nameA = '', _nameB = '';

  // Optional third type for grade 3+
  bool _hasThirdType = false;
  int _eyesC = 0, _legsC = 0;
  int _countC = 0;
  String _nameC = '';

  // Player input via sliders
  int _sliderA = 0;
  int _sliderB = 0;
  int _sliderC = 0;
  int _maxSliderValue = 10;

  // Math problems for SRI
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level, gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    _round = Object();
    disposePuzzleSession();
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _won = false;
      _wrongChecks = 0;
      _mathProblems.clear();
      _sliderA = 0;
      _sliderB = 0;
      _sliderC = 0;
      successController.reset();
    });

    final grade = currentDifficulty!.grade;
    final generated = generateXenobiologyLab(grade, widget.level, random: _random);
    if (!mounted || !identical(round, _round)) return;
    _countA = generated['_countA'] as int;
    _countB = generated['_countB'] as int;
    _countC = generated['_countC'] as int;
    _eyesA = generated['_eyesA'] as int;
    _eyesB = generated['_eyesB'] as int;
    _eyesC = generated['_eyesC'] as int;
    _hasThirdType = generated['_hasThirdType'] as bool;
    _legsA = generated['_legsA'] as int;
    _legsB = generated['_legsB'] as int;
    _legsC = generated['_legsC'] as int;
    _mathProblems.addAll((generated['_mathProblems'] as List)
        .map((p) => MathProblem.fromJson(Map<String, dynamic>.from(p as Map))));
    _maxSliderValue = generated['_maxSliderValue'] as int;
    _nameA = generated['_nameA'] as String;
    _nameB = generated['_nameB'] as String;
    _nameC = generated['_nameC'] as String;
    _totalEyes = generated['_totalEyes'] as int;
    _totalLegs = generated['_totalLegs'] as int;

    if (mounted && identical(round, _round)) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // Computed totals based on slider values
  int get _computedEyes =>
      _sliderA * _eyesA + _sliderB * _eyesB + (_hasThirdType ? _sliderC * _eyesC : 0);
  int get _computedLegs =>
      _sliderA * _legsA + _sliderB * _legsB + (_hasThirdType ? _sliderC * _legsC : 0);

  bool get _eyesMatch => _computedEyes == _totalEyes;
  bool get _legsMatch => _computedLegs == _totalLegs;

  int _winScore() {
    final baseScore = 100 * widget.grade;
    final levelBonus = widget.level * 25;
    final complexityBonus = _hasThirdType ? 100 : 50;
    return baseScore + levelBonus + complexityBonus;
  }

  bool _isCorrect() {
    return matchesCensusTotals({
      '_maxSliderValue': _maxSliderValue,
      '_hasThirdType': _hasThirdType,
      '_eyesA': _eyesA,
      '_eyesB': _eyesB,
      '_eyesC': _eyesC,
      '_legsA': _legsA,
      '_legsB': _legsB,
      '_legsC': _legsC,
      '_totalEyes': _totalEyes,
      '_totalLegs': _totalLegs,
      '_countA': _countA,
      '_countB': _countB,
      '_countC': _countC,
    }, _sliderA, _sliderB, _sliderC);
  }

  void _setSlider(int which, int value, Object round) {
    if (!_canInteract(round)) return;
    setState(() {
      if (which == 0) _sliderA = value;
      if (which == 1) _sliderB = value;
      if (which == 2) _sliderC = value;
    });
  }

  void _checkSolution([Object? round]) {
    final currentRound = round ?? _round;
    if (!_canInteract(currentRound)) return;
    final correct = _isCorrect();
    if (correct) {
      _handleWin(currentRound);
    } else {
      _handleLoss(currentRound);
    }
  }

  void _handleWin(Object round) {
    if (!_canInteract(round)) return;
    if (!_isCorrect()) return;
    _clearFeedback();
    setState(() {
      _gameOver = true;
      _won = true;
    });
    final totalScore = _winScore();
    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'xenobiology_lab',
          difficulty: widget.level,
          score: totalScore,
          mathProblems: List<MathProblem>.from(_mathProblems),
          performance: Perf.fromMistakes(_wrongChecks),
        ));

    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int totalScore, Object round) {
    if (!mounted || !identical(round, _round) || !_won) return;
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildWinDialog(totalScore, round, dialogContext),
    );
  }

  bool _canUseDialog(BuildContext dialogContext, Object round) =>
      mounted &&
      identical(round, _round) &&
      _won &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  void _handleLoss(Object round) {
    if (!_canInteract(round)) return;
    AppHaptics.heavyImpact();
    setState(() => _wrongChecks++);

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'xenobiology_lab',
          difficulty: widget.level,
          mathProblems: List<MathProblem>.from(_mathProblems),
        ));

    // Recoverable mistake: keep board editable and save snapshot.
    finishPuzzleSession();
    beginPuzzleSession();
    savePuzzleSession();

    if (!mounted || !identical(round, _round)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.xenobiologyLabLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    final round = _round;
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                key: ValueKey(('xeno-header', round)),
                title: s.xenobiologyLabTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    final isShort = constraints.maxHeight < 500;
                    final content = isWide
                        ? _buildWideLayout(round)
                        : _buildCompactLayout(round);
                    if (isShort) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: content,
                        ),
                      );
                    }
                    return content;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(Object round) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildInstructions(),
                  const SizedBox(height: 12),
                  _buildCreatureCards(),
                  const SizedBox(height: 16),
                  _buildCensusDisplay(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: _buildSlidersAndSubmit(round),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(Object round) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 12),
          _buildCreatureCards(),
          const SizedBox(height: 16),
          _buildCensusDisplay(),
          const SizedBox(height: 16),
          _buildSlidersAndSubmit(round),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.xenobiologyLabInstructions,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatureCards() {
    return Column(
      children: [
        _buildAlienCard(_nameA, _eyesA, _legsA, const Color(0xFF06FFA5)),
        const SizedBox(height: 12),
        _buildAlienCard(_nameB, _eyesB, _legsB, const Color(0xFFFFD700)),
        if (_hasThirdType) ...[
          const SizedBox(height: 12),
          _buildAlienCard(_nameC, _eyesC, _legsC, const Color(0xFFFF69B4)),
        ],
      ],
    );
  }

  Widget _buildAlienCard(String name, int eyes, int legs, Color color) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.3 + glowAnimation.value * 0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Visual creature representation
              _buildCreatureVisual(eyes, legs, color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: SpaceTheme.titleStyle.copyWith(color: color, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    _buildTraitRow(Icons.visibility, '$eyes eyes', color),
                    const SizedBox(height: 2),
                    _buildTraitRow(Icons.directions_walk, '$legs legs', color),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTraitRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: SpaceTheme.bodyStyle.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  /// Draw a simple alien creature with visible eye and leg counts.
  Widget _buildCreatureVisual(int eyes, int legs, Color color) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _AlienPainter(eyes: eyes, legs: legs, color: color),
      ),
    );
  }

  int get _computedCreatures => _sliderA + _sliderB + (_hasThirdType ? _sliderC : 0);
  int get _totalCreatures => _countA + _countB + (_hasThirdType ? _countC : 0);
  bool get _creaturesMatch => _computedCreatures == _totalCreatures;

  Widget _buildCensusDisplay() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3 + glowAnimation.value * 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(S.of(context)!.xenoCensusReport,
                  style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 18)),
              const SizedBox(height: 12),
              // FIX: Row overflow -> Wrap with spacing so the two (or three)
              // census cards never overflow on 390w or at textScale 2.0.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildTargetComparison(
                    Icons.visibility,
                    S.of(context)!.xenoEyes,
                    _totalEyes,
                    _computedEyes,
                    _eyesMatch,
                  ),
                  _buildTargetComparison(
                    Icons.directions_walk,
                    S.of(context)!.xenoLegs,
                    _totalLegs,
                    _computedLegs,
                    _legsMatch,
                  ),
                  if (_hasThirdType)
                    _buildTargetComparison(
                      Icons.pest_control,
                      S.of(context)!.xenoCreatures,
                      _totalCreatures,
                      _computedCreatures,
                      _creaturesMatch,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows target value alongside the player's live-computed total.
  /// Green when matching, orange/red when not — lets the player reason
  /// about which slider to adjust instead of guessing blindly.
  Widget _buildTargetComparison(
      IconData icon, String label, int target, int current, bool matches) {
    const matchColor = Color(0xFF06FFA5);
    const mismatchColor = Color(0xFFFF6B6B);
    final statusColor = matches ? matchColor : mismatchColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: matches
              ? matchColor.withValues(alpha: 0.6)
              : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SpaceTheme.starYellow, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13, color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          // Target row — FIX: use Wrap so long German labels don't overflow.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(S.of(context)!.xenoTarget,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white54)),
              Text('$target',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 22,
                    color: SpaceTheme.starYellow,
                  )),
            ],
          ),
          const SizedBox(height: 2),
          // Current (computed) row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(S.of(context)!.xenoYours,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white54)),
              Text('$current',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 22,
                    color: statusColor,
                  )),
              if (matches) const Icon(Icons.check_circle, color: matchColor, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersAndSubmit(Object round) {
    return Column(
      children: [
        _buildSlider(_nameA, _sliderA, const Color(0xFF06FFA5), (v) {
          _setSlider(0, v, round);
        }, round, 0),
        const SizedBox(height: 12),
        _buildSlider(_nameB, _sliderB, const Color(0xFFFFD700), (v) {
          _setSlider(1, v, round);
        }, round, 1),
        if (_hasThirdType) ...[
          const SizedBox(height: 12),
          _buildSlider(_nameC, _sliderC, const Color(0xFFFF69B4), (v) {
            _setSlider(2, v, round);
          }, round, 2),
        ],
        const SizedBox(height: 20),
        // Submit button — keyed per round so stale gesture callbacks are dropped.
        if (!_gameOver)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: ValueKey(('xeno-submit', round)),
              onPressed: () => _checkSolution(round),
              icon: const Icon(Icons.check, size: 28),
              label: Text(S.of(context)!.xenobiologySubmitCensus, style: const TextStyle(fontSize: 16)),
              style: SpaceTheme.primaryButtonStyle,
            ),
          ),
      ],
    );
  }

  Widget _buildSlider(String name, int value, Color color, ValueChanged<int> onChanged, Object round, int index) {
    return Container(
      key: ValueKey(('xeno-slider', round, index)),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: SpaceTheme.titleStyle.copyWith(color: color, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$value',
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 20, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              valueIndicatorColor: color,
              valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: _maxSliderValue.toDouble(),
              divisions: _maxSliderValue,
              label: value.toString(),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinDialog(int totalScore, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'xenobiology_lab'),
                  const Icon(Icons.biotech, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.xenobiologyLabWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.xenobiologyLabWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  // FIX: Row overflow -> Wrap so buttons wrap on narrow/phone at textScale 2.0
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(dialogContext, round)) return;
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseDialog(dialogContext, round)) return;
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

/// Custom painter that draws a simple alien creature
class _AlienPainter extends CustomPainter {
  final int eyes;
  final int legs;
  final Color color;

  _AlienPainter({required this.eyes, required this.legs, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final bodyTop = size.height * 0.2;
    final bodyBottom = size.height * 0.65;
    final bodyRadius = size.width * 0.3;

    // Body (oval)
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, (bodyTop + bodyBottom) / 2),
      width: bodyRadius * 2,
      height: bodyBottom - bodyTop,
    );
    canvas.drawOval(bodyRect, paint);
    canvas.drawOval(bodyRect, outlinePaint);

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black;
    final eyeY = bodyTop + (bodyBottom - bodyTop) * 0.3;
    final eyeSpacing = bodyRadius * 1.6 / (eyes + 1);

    for (int i = 0; i < eyes; i++) {
      final eyeX = cx - bodyRadius * 0.8 + eyeSpacing * (i + 1);
      canvas.drawCircle(Offset(eyeX, eyeY), 4, eyePaint);
      canvas.drawCircle(Offset(eyeX, eyeY), 2, pupilPaint);
    }

    // Legs
    final legPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final legSpacing = bodyRadius * 2 / (legs + 1);
    for (int i = 0; i < legs; i++) {
      final legX = cx - bodyRadius + legSpacing * (i + 1);
      final legEnd = size.height * 0.95;
      // Slight zigzag for knees
      final kneeY = bodyBottom + (legEnd - bodyBottom) * 0.5;
      final kneeOffset = (i % 2 == 0 ? 1 : -1) * 3.0;
      final path = Path()
        ..moveTo(legX, bodyBottom)
        ..lineTo(legX + kneeOffset, kneeY)
        ..lineTo(legX, legEnd);
      canvas.drawPath(path, legPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AlienPainter oldDelegate) =>
      oldDelegate.eyes != eyes || oldDelegate.legs != legs || oldDelegate.color != color;
}
