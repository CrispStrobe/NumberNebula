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
  late AnimationController _successController;
  late Animation<double> _successAnimation;

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

  // User answer
  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();

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
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _mathProblems.clear();
      _hourController.clear();
      _minuteController.clear();
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
      _malfunctionHint = 'This clock runs $_offsetHours hours fast';
    } else if (grade == 2) {
      // Mirror: hour hand and minute hand positions swap visually
      _malfunction = ClockMalfunction.mirror;
      // Mirror means the clock face is reflected horizontally
      // 3 becomes 9, 1 becomes 11, etc.
      _displayedHour = ((12 - _correctHour) % 12);
      if (_displayedHour == 0) _displayedHour = 12;
      _displayedMinute = (60 - _correctMinute) % 60;
      _malfunctionHint = 'This clock is horizontally mirrored';
    } else {
      // Combined: offset + mirror or offset with minutes
      _malfunction = ClockMalfunction.combined;
      _offsetHours = _random.nextInt(4) + 1;
      _offsetMinutes = (_random.nextInt(4) + 1) * 15; // 15, 30, 45, 60

      int totalMinutes = _correctHour * 60 + _correctMinute + _offsetHours * 60 + _offsetMinutes;
      _displayedHour = ((totalMinutes ~/ 60) % 12);
      if (_displayedHour == 0) _displayedHour = 12;
      _displayedMinute = totalMinutes % 60;
      _malfunctionHint = 'This clock runs $_offsetHours h $_offsetMinutes min fast';
    }

    // Create MathProblem for SRI tracking
    _mathProblems.add(MathProblem.addition(_correctHour, _offsetHours, difficulty: grade));
    if (_offsetMinutes > 0) {
      _mathProblems.add(MathProblem.addition(_correctMinute, _offsetMinutes, difficulty: grade));
    }

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _checkAnswer() {
    if (_gameOver) return;
    final answerH = int.tryParse(_hourController.text);
    final answerM = int.tryParse(_minuteController.text);
    if (answerH == null || answerM == null) return;

    if (answerH == _correctHour && answerM == _correctMinute) {
      _handleWin();
    } else {
      _handleLoss();
    }
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
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Malfunction hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFFFD700), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _malfunctionHint,
                    style: SpaceTheme.bodyStyle.copyWith(color: const Color(0xFFFFD700), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Clock display
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SpaceTheme.deepSpace,
              border: Border.all(color: const Color(0xFF6B48FF), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B48FF).withValues(alpha: 0.3),
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
          ),
          const SizedBox(height: 12),
          // Digital display (broken)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Text(
              '${_displayedHour.toString().padLeft(2, '0')}:${_displayedMinute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 36,
                color: Color(0xFFFFD700),
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Answer section
          if (!_gameOver) ...[
            Text('What is the correct time?',
                style: SpaceTheme.titleStyle.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _hourController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
                    decoration: InputDecoration(
                      hintText: 'HH',
                      hintStyle: SpaceTheme.bodyStyle.copyWith(color: Colors.white30),
                      filled: true,
                      fillColor: SpaceTheme.deepSpace,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':',
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 28, color: const Color(0xFFFFD700))),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _minuteController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
                    decoration: InputDecoration(
                      hintText: 'MM',
                      hintStyle: SpaceTheme.bodyStyle.copyWith(color: Colors.white30),
                      filled: true,
                      fillColor: SpaceTheme.deepSpace,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _checkAnswer,
                  style: SpaceTheme.primaryButtonStyle,
                  child: const Icon(Icons.check, size: 28),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
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
      ..color = const Color(0xFFFFD700)
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
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFFFFD700));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) {
    return oldDelegate.hour != hour || oldDelegate.minute != minute;
  }
}
