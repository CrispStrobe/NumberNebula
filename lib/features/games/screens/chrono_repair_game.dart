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

class ChronoRepairGame extends StatefulWidget {
  final int grade;
  final int level;
  const ChronoRepairGame({super.key, required this.grade, required this.level});

  @override
  State<ChronoRepairGame> createState() => _ChronoRepairGameState();
}

enum ClockMalfunction { offset, mirror, combined }

class _ChronoRepairGameState extends State<ChronoRepairGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _pulseController;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
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
    _pulseController.stop();
    _glowController.dispose();
    _successController.dispose();
    _pulseController.dispose();
    
    
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

    // Generate a random correct time
    _correctHour = _random.nextInt(12) + 1; // 1-12
    _correctMinute = _random.nextInt(12) * 5; // 0, 5, 10, ..., 55

    if (grade <= 1) {
      // Simple offset
      _malfunction = ClockMalfunction.offset;
      _offsetHours = _random.nextInt(3) + 1; // 1-3 hours
      _offsetMinutes = 0;
      _displayedHour = ((_correctHour + _offsetHours - 1) % 12) + 1;
      _displayedMinute = _correctMinute;
      _malfunctionHint = S.of(context)!.chronoClockRunsFast(_offsetHours);
    } else if (grade == 2) {
      // Mirror: hour hand and minute hand positions swap visually
      _malfunction = ClockMalfunction.mirror;
      _displayedHour = ((12 - _correctHour) % 12);
      if (_displayedHour == 0) _displayedHour = 12;
      _displayedMinute = (60 - _correctMinute) % 60;
      _malfunctionHint = S.of(context)!.chronoClockMirrored;
    } else {
      // Combined: offset + mirror or offset with minutes
      _malfunction = ClockMalfunction.combined;
      _offsetHours = _random.nextInt(4) + 1;
      _offsetMinutes = (_random.nextInt(4) + 1) * 15; // 15, 30, 45, 60

      int totalMinutes = _correctHour * 60 + _correctMinute + _offsetHours * 60 + _offsetMinutes;
      _displayedHour = ((totalMinutes ~/ 60) % 12);
      if (_displayedHour == 0) _displayedHour = 12;
      _displayedMinute = totalMinutes % 60;
      _malfunctionHint = S.of(context)!.chronoClockRunsFastCombined(_offsetHours, _offsetMinutes);
    }

    // Create MathProblem for SRI tracking
    _mathProblems.add(MathProblem.addition(_correctHour, _offsetHours, difficulty: grade));
    if (_offsetMinutes > 0) {
      _mathProblems.add(MathProblem.addition(_correctMinute, _offsetMinutes, difficulty: grade));
    }

    // Reset scroll controllers
    
    
    
    

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _checkAnswer() {
    if (_gameOver) return;
    if (_selectedHour == _correctHour && _selectedMinute == _correctMinute) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up button
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up, color: SpaceTheme.starYellow, size: 32),
          onPressed: () {
            HapticFeedback.selectionClick();
            onChanged(value + step > max ? min : value + step);
          },
        ),
        // Value display
        Container(
          width: 70, height: 60,
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
          icon: const Icon(Icons.keyboard_arrow_down, color: SpaceTheme.starYellow, size: 32),
          onPressed: () {
            HapticFeedback.selectionClick();
            onChanged(value - step < min ? max : value - step);
          },
        ),
      ],
    );
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int complexityBonus = _malfunction == ClockMalfunction.combined ? 80 : 40;
    int totalScore = baseScore + levelBonus + complexityBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'chrono_repair',
      difficulty: widget.level,
      score: totalScore,
      mathProblems: _mathProblems,
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

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'chrono_repair',
      difficulty: widget.level,
      mathProblems: _mathProblems,
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
                title: s.chronoRepairTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    // Do NOT use SingleChildScrollView here -- it steals scroll
    // gestures from the ListWheelScrollView rollers inside _buildRollerInput.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMalfunctionHint(),
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: _buildClockDisplay(constraints),
          ),
          const SizedBox(height: 6),
          _buildDigitalDisplay(),
          const SizedBox(height: 10),
          if (!_gameOver)
            Expanded(
              flex: 4,
              child: _buildRollerInput(),
            ),
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
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpaceTheme.starYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value * 0.7),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: SpaceTheme.starYellow, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _malfunctionHint,
                  style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 13),
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
            border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
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
                    min: 1, max: 12,
                    onChanged: (v) => setState(() => _selectedHour = v),
                  ),
                  // Colon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(':',
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 40, color: SpaceTheme.starYellow,
                      ),
                    ),
                  ),
                  // Minute stepper
                  _buildStepper(
                    value: _selectedMinute,
                    min: 0, max: 55, step: 5,
                    onChanged: (v) => setState(() => _selectedMinute = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkAnswer,
                icon: const Icon(Icons.check, size: 24),
                label: const Text('Submit', style: TextStyle(fontSize: 16)),
                style: SpaceTheme.primaryButtonStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Stepper widget is defined above in _buildStepper()

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
                  const Icon(Icons.watch_later, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.chronoRepairWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.chronoRepairWinDesc(totalScore),
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

class _ClockPainter extends CustomPainter {
  final int hour;
  final int minute;
  final bool isMirrored;

  _ClockPainter({required this.hour, required this.minute, this.isMirrored = false});

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
