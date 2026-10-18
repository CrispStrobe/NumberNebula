import '../services/chrono_repair_logic.dart';
export '../services/chrono_repair_logic.dart';
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

class ChronoRepairGame extends StatefulWidget {
  final int grade;
  final int level;
  const ChronoRepairGame({super.key, required this.grade, required this.level});

  @override
  State<ChronoRepairGame> createState() => _ChronoRepairGameState();
}

class _ChronoRepairGameState extends State<ChronoRepairGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<ChronoRepairGame>,
        PuzzleSessionMixin<ChronoRepairGame> {
  bool _sessionReady = false;
  Object _round = Object();
  bool _won = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      _sessionReady;

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    successController.reset();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @visibleForTesting
  Object get testRound => _round;

  @visibleForTesting
  void rebuildForTesting() => setState(() {});

  @override
  String get sessionGameKey => 'chrono_repair';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won) {
      return null;
    }
    return {
      '_correctHour': _correctHour,
      '_correctMinute': _correctMinute,
      '_displayedHour': _displayedHour,
      '_displayedMinute': _displayedMinute,
      '_malfunction': _malfunction.name,
      '_offsetHours': _offsetHours,
      '_offsetMinutes': _offsetMinutes,
      '_malfunctionHint': _malfunctionHint,
      '_selectedHour': _selectedHour,
      '_selectedMinute': _selectedMinute,
      '_mathProblems': _mathProblems.map((v0) => v0.toJson()).toList(),
      '_wrongChecks': _wrongChecks
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    _won = false;
    _correctHour = state["_correctHour"] as int;
    _correctMinute = state["_correctMinute"] as int;
    _displayedHour = state["_displayedHour"] as int;
    _displayedMinute = state["_displayedMinute"] as int;
    _malfunction =
        ClockMalfunction.values.byName(state["_malfunction"] as String);
    _offsetHours = state["_offsetHours"] as int;
    _offsetMinutes = state["_offsetMinutes"] as int;
    _malfunctionHint = state["_malfunctionHint"] as String;
    _selectedHour = state["_selectedHour"] as int;
    _selectedMinute = state["_selectedMinute"] as int;
    _mathProblems
      ..clear()
      ..addAll((state["_mathProblems"] as List)
          .map((v0) =>
              MathProblem.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList());
    _wrongChecks = state["_wrongChecks"] as int;
    _isGenerating = false;
    _gameOver = false;
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) {
      setState(() => _sessionReady = true);
    }
  }

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
  /// Wrong times submitted before the correct one.
  int _wrongChecks = 0;

  int _correctHour = 0;
  int _correctMinute = 0;
  int _displayedHour = 0;
  int _displayedMinute = 0;
  ClockMalfunction _malfunction = ClockMalfunction.offset;
  int _offsetHours = 0;
  int _offsetMinutes = 0;
  String _malfunctionHint = '';

  // Slot machine roller controllers
  int _selectedHour = 1;
  int _selectedMinute = 0;

  // Math problems for SRI
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    initGameAnimations();

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
    _round = Object();
    cancelOneShotMotion(successController);
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    if (currentDifficulty == null) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _won = false;
      _wrongChecks = 0;
      _mathProblems.clear();
      successController.reset();
    });

    final grade = currentDifficulty!.grade;

    final generated =
        generateChronoRepair(grade, widget.level, random: _random);
    if (!mounted || !identical(round, _round)) {
      return;
    }
    _correctHour = generated['_correctHour'] as int;
    _correctMinute = generated['_correctMinute'] as int;
    _displayedHour = generated['_displayedHour'] as int;
    _displayedMinute = generated['_displayedMinute'] as int;
    _malfunction =
        ClockMalfunction.values.byName(generated['_malfunction'] as String);
    _mathProblems.addAll((generated['_mathProblems'] as List)
        .map((p) => MathProblem.fromJson(Map<String, dynamic>.from(p as Map))));
    _offsetHours = generated['_offsetHours'] as int;
    _offsetMinutes = generated['_offsetMinutes'] as int;
    _malfunctionHint = switch (_malfunction) {
      ClockMalfunction.offset =>
        S.of(context)!.chronoClockRunsFast(_offsetHours),
      ClockMalfunction.mirror => S.of(context)!.chronoClockMirrored,
      ClockMalfunction.combined => S
          .of(context)!
          .chronoClockRunsFastCombined(_offsetHours, _offsetMinutes),
    };
    // Reset scroll controllers

    if (mounted && identical(round, _round)) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _checkAnswer(Object round) {
    if (!_canInteract(round)) {
      return;
    }
    if (_selectedHour == _correctHour && _selectedMinute == _correctMinute) {
      _handleWin(round);
    } else {
      _handleLoss(round);
    }
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
    Object? round,
  }) {
    final currentRound = round ?? _round;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up button
        IconButton(
          key: ValueKey(('chrono-step-up', currentRound, value, min, max)),
          icon: const Icon(Icons.keyboard_arrow_up,
              color: SpaceTheme.starYellow, size: 32),
          onPressed: () {
            if (!_canInteract(currentRound)) {
              return;
            }
            AppHaptics.selectionClick();
            onChanged(value + step > max ? min : value + step);
          },
        ),
        // Value display
        Container(
          width: 70,
          height: 60,
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SpaceTheme.starYellow, width: 2),
          ),
          child: Center(
            child: Text(
              value.toString().padLeft(2, '0'),
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 32),
            ),
          ),
        ),
        // Down button
        IconButton(
          key: ValueKey(('chrono-step-down', currentRound, value, min, max)),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: SpaceTheme.starYellow, size: 32),
          onPressed: () {
            if (!_canInteract(currentRound)) {
              return;
            }
            AppHaptics.selectionClick();
            onChanged(value - step < min ? max : value - step);
          },
        ),
      ],
    );
  }

  void _handleWin(Object round) {
    if (!_canInteract(round)) {
      return;
    }
    _resetRoundEffects();
    setState(() {
      _gameOver = true;
      _won = true;
    });
    final winRound = _round;
    finishPuzzleSession();
    AppHaptics.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int complexityBonus = _malfunction == ClockMalfunction.combined ? 80 : 40;
    int totalScore = baseScore + levelBonus + complexityBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'chrono_repair',
          difficulty: widget.level,
          score: totalScore,
          mathProblems: List<MathProblem>.unmodifiable(_mathProblems),
          performance: Perf.fromMistakes(_wrongChecks),
        ));

    _showWinDialog(totalScore, winRound);
  }

  void _showWinDialog(int totalScore, Object round) {
    if (!mounted || !identical(round, _round) || !_won) {
      return;
    }
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _buildWinDialog(totalScore, round, dialogContext),
    );
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _won &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  void _handleLoss(Object round) {
    if (!_canInteract(round)) {
      return;
    }
    setState(() => _wrongChecks++);
    AppHaptics.heavyImpact();

    // Do not finishPuzzleSession on wrong; keep board editable and save updated wrongChecks
    // Report loss for SRI but keep session open for retry
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'chrono_repair',
          difficulty: widget.level,
          mathProblems: List<MathProblem>.unmodifiable(_mathProblems),
        ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.chronoRepairLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                key: ValueKey(('chrono-header', _round)),
                title: s.chronoRepairTitle,
                level: widget.level,
                onBack: () {
                  if (mounted && identical(_round, _round) && !_isGenerating) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.chronoRepairInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
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
        Expanded(flex: 3, child: _buildClockSection(constraints)),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: _buildRollerSection()),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    // Steppers have no competing wheel gestures. Let all instructions and
    // controls grow naturally at large text scales and on short phones.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMalfunctionHint(),
          const SizedBox(height: 10),
          SizedBox(
              height: constraints.maxWidth.clamp(140.0, 240.0),
              child: _buildClockDisplay(constraints)),
          const SizedBox(height: 6),
          _buildDigitalDisplay(),
          const SizedBox(height: 10),
          if (!_gameOver) _buildRollerInput(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildClockSection(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMalfunctionHint(),
          const SizedBox(height: 16),
          _buildClockDisplay(constraints),
          const SizedBox(height: 12),
          _buildDigitalDisplay(),
        ],
      ),
    );
  }

  Widget _buildRollerSection() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_gameOver) _buildRollerInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMalfunctionHint() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpaceTheme.starYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SpaceTheme.starYellow
                  .withValues(alpha: glowAnimation.value * 0.7),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber,
                  color: SpaceTheme.starYellow, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _malfunctionHint,
                  style: SpaceTheme.bodyStyle
                      .copyWith(color: SpaceTheme.starYellow, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClockDisplay(BoxConstraints constraints) {
    final clockSize = math.min(220.0, constraints.maxWidth * 0.5);
    return Container(
      width: clockSize,
      height: clockSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SpaceTheme.deepSpace,
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 3),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _ClockPainter(
          hour: _displayedHour,
          minute: _displayedMinute,
          isMirrored: _malfunction == ClockMalfunction.mirror,
        ),
      ),
    );
  }

  Widget _buildDigitalDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${_displayedHour.toString().padLeft(2, '0')}:${_displayedMinute.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 36,
          color: SpaceTheme.starYellow,
          letterSpacing: 4,
        ),
      ),
    );
  }

  Widget _buildRollerInput() {
    final round = _round;
    return Column(
      children: [
        Text(S.of(context)!.chronoWhatIsCorrectTime,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hour stepper
                  _buildStepper(
                    value: _selectedHour,
                    min: 1,
                    max: 12,
                    onChanged: (v) {
                      if (!_canInteract(_round)) {
                        return;
                      }
                      setState(() => _selectedHour = v);
                    },
                    round: _round,
                  ),
                  // Colon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 40,
                        color: SpaceTheme.starYellow,
                      ),
                    ),
                  ),
                  // Minute stepper
                  _buildStepper(
                    value: _selectedMinute,
                    min: 0,
                    max: 55,
                    step: 5,
                    onChanged: (v) {
                      if (!_canInteract(_round)) {
                        return;
                      }
                      setState(() => _selectedMinute = v);
                    },
                    round: _round,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: ValueKey(('chrono-submit', _round)),
                onPressed: () => _checkAnswer(round),
                icon: const Icon(Icons.check, size: 24),
                label: Text(S.of(context)!.chronoRepairSubmit,
                    style: const TextStyle(fontSize: 16)),
                style: SpaceTheme.primaryButtonStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Stepper widget is defined above in _buildStepper()

  Widget _buildWinDialog(
      int totalScore, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'chrono_repair'),
                  const Icon(Icons.watch_later,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.chronoRepairWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.chronoRepairWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    overflowAlignment: OverflowBarAlignment.center,
                    spacing: 16,
                    overflowSpacing: 12,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) {
                            return;
                          }
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

class _ClockPainter extends CustomPainter {
  final int hour;
  final int minute;
  final bool isMirrored;

  _ClockPainter(
      {required this.hour, required this.minute, this.isMirrored = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw hour markers
    final markerPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final outer = Offset(
        center.dx + radius * 0.9 * math.cos(angle),
        center.dy + radius * 0.9 * math.sin(angle),
      );
      final inner = Offset(
        center.dx + radius * 0.75 * math.cos(angle),
        center.dy + radius * 0.75 * math.sin(angle),
      );
      canvas.drawLine(inner, outer, markerPaint);
    }

    // Draw hour hand
    final hourAngle = ((hour % 12) * 30 + minute * 0.5 - 90) * math.pi / 180;
    final hourPaint = Paint()
      ..color = SpaceTheme.starYellow
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.5 * math.cos(hourAngle),
        center.dy + radius * 0.5 * math.sin(hourAngle),
      ),
      hourPaint,
    );

    // Draw minute hand
    final minuteAngle = (minute * 6 - 90) * math.pi / 180;
    final minutePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.7 * math.cos(minuteAngle),
        center.dy + radius * 0.7 * math.sin(minuteAngle),
      ),
      minutePaint,
    );

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = SpaceTheme.starYellow);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.hour != hour || oldDelegate.minute != minute;
  }
}
