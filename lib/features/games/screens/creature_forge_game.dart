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

class CreatureForgeGame extends StatefulWidget {
  final int grade;
  final int level;
  const CreatureForgeGame({super.key, required this.grade, required this.level});

  @override
  State<CreatureForgeGame> createState() => _CreatureForgeGameState();
}

class _CreatureForgeGameState extends State<CreatureForgeGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Scroll controllers for the three columns
  late FixedExtentScrollController _headScrollController;
  late FixedExtentScrollController _bodyScrollController;
  late FixedExtentScrollController _tailScrollController;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Parts
  int _headCount = 0;
  int _bodyCount = 0;
  int _tailCount = 0;
  int _correctAnswer = 0;

  // For higher grades: constraints that reduce valid combos
  int _forbiddenCombos = 0;
  bool _hasConstraints = false;
  String _constraintText = '';

  // User exploration state
  int _currentHead = 0;
  int _currentBody = 0;
  int _currentTail = 0;
  final Set<String> _discoveredCombos = {};

  // User answer
  final TextEditingController _answerController = TextEditingController();

  final _random = math.Random();

  static const List<String> _headNames = ['Crystal', 'Flame', 'Frost', 'Shadow'];
  static const List<String> _bodyNames = ['Armored', 'Winged', 'Aquatic', 'Elastic'];
  static const List<String> _tailNames = ['Stinger', 'Feathered', 'Spiked', 'Luminous'];

  // Colors for each variant
  static const List<Color> _headColors = [
    Color(0xFF00E5FF), Color(0xFFFF5722), Color(0xFF80DEEA), Color(0xFF7C4DFF),
  ];
  static const List<Color> _bodyColors = [
    Color(0xFF78909C), Color(0xFFFFD700), Color(0xFF26C6DA), Color(0xFF69F0AE),
  ];
  static const List<Color> _tailColors = [
    Color(0xFFFF9100), Color(0xFF66BB6A), Color(0xFFEF5350), Color(0xFFFFEE58),
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _headScrollController = FixedExtentScrollController();
    _bodyScrollController = FixedExtentScrollController();
    _tailScrollController = FixedExtentScrollController();

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
    _answerController.dispose();
    _headScrollController.dispose();
    _bodyScrollController.dispose();
    _tailScrollController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _discoveredCombos.clear();
      _answerController.clear();
      _successController.reset();
      _currentHead = 0;
      _currentBody = 0;
      _currentTail = 0;
    });

    final grade = currentDifficulty!.grade;

    if (grade <= 2) {
      _headCount = 2;
      _bodyCount = 2;
      _tailCount = 2;
      _hasConstraints = false;
      _forbiddenCombos = 0;
      _constraintText = '';
    } else if (grade == 3) {
      _headCount = 3;
      _bodyCount = 3;
      _tailCount = 3;
      _hasConstraints = true;
      _forbiddenCombos = _random.nextInt(3) + 2;
      _constraintText = 'Wings require light body';
    } else {
      _headCount = 4;
      _bodyCount = 4;
      _tailCount = 4;
      _hasConstraints = true;
      _forbiddenCombos = _random.nextInt(5) + 3;
      _constraintText = 'Wings require light body\nFrost + Stinger is unstable';
    }

    _correctAnswer = _headCount * _bodyCount * _tailCount - _forbiddenCombos;

    // Reset scroll controllers
    _headScrollController.dispose();
    _bodyScrollController.dispose();
    _tailScrollController.dispose();
    _headScrollController = FixedExtentScrollController();
    _bodyScrollController = FixedExtentScrollController();
    _tailScrollController = FixedExtentScrollController();

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
      _addDiscovery();
    }
  }

  void _addDiscovery() {
    final key = '$_currentHead-$_currentBody-$_currentTail';
    setState(() {
      _discoveredCombos.add(key);
    });
  }

  void _checkAnswer() {
    if (_gameOver) return;
    final answer = int.tryParse(_answerController.text);
    if (answer == null) return;

    if (answer == _correctAnswer) {
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
    int totalScore = baseScore + levelBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'creature_forge',
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

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'creature_forge',
      difficulty: widget.level,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.creatureForgeLoseDesc)),
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
                title: s.creatureForgeTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.creatureForgeInstructions,
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
    return Row(
      children: [
        // Scrollable columns on the left
        Expanded(
          flex: 3,
          child: _buildScrollableColumns(constraints),
        ),
        const SizedBox(width: 16),
        // Preview + answer on the right
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: _buildCreaturePreview(constraints)),
              const SizedBox(height: 8),
              _buildInfoAndAnswer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Column(
      children: [
        // Parts info bar
        _buildPartsInfoBar(),

        if (_hasConstraints) _buildConstraintBar(),

        const SizedBox(height: 4),

        // Main area: scrollable columns + creature preview
        Expanded(
          child: Row(
            children: [
              // Three scrollable columns
              Expanded(
                flex: 3,
                child: _buildScrollableColumns(constraints),
              ),
              // Combined creature preview in center
              Expanded(
                flex: 2,
                child: _buildCreaturePreview(constraints),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Discovery counter
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, _) {
            return Text(
              '${_discoveredCombos.length} of ${_hasConstraints ? "?" : "${_headCount * _bodyCount * _tailCount}"} combinations found',
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value),
                fontSize: 13,
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Answer input
        if (!_gameOver) _buildAnswerRow(),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPartsInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPartCount('Heads', _headCount, _headColors[0]),
          _buildPartCount('Bodies', _bodyCount, _bodyColors[0]),
          _buildPartCount('Tails', _tailCount, _tailColors[0]),
          if (_hasConstraints)
            Text(
              'Total: ?',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: SpaceTheme.starYellow),
            )
          else
            Text(
              'Total: ${_headCount * _bodyCount * _tailCount}',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: SpaceTheme.starYellow),
            ),
        ],
      ),
    );
  }

  Widget _buildPartCount(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: SpaceTheme.headlineStyle.copyWith(color: color, fontSize: 18)),
        Text(label, style: SpaceTheme.bodyStyle.copyWith(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildConstraintBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.rocketRed.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$_constraintText  ($_forbiddenCombos forbidden)',
        style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: SpaceTheme.rocketRed),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildScrollableColumns(BoxConstraints constraints) {
    final columnHeight = constraints.maxHeight * 0.5;
    const itemExtent = 70.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Head column
          Expanded(
            child: _buildPartWheel(
              label: 'Head',
              count: _headCount,
              names: _headNames,
              colors: _headColors,
              controller: _headScrollController,
              itemExtent: itemExtent,
              height: columnHeight,
              partType: 0,
              onChanged: (i) {
                _currentHead = i % _headCount;
                _addDiscovery();
              },
            ),
          ),
          const SizedBox(width: 4),
          // Body column
          Expanded(
            child: _buildPartWheel(
              label: 'Body',
              count: _bodyCount,
              names: _bodyNames,
              colors: _bodyColors,
              controller: _bodyScrollController,
              itemExtent: itemExtent,
              height: columnHeight,
              partType: 1,
              onChanged: (i) {
                _currentBody = i % _bodyCount;
                _addDiscovery();
              },
            ),
          ),
          const SizedBox(width: 4),
          // Tail column
          Expanded(
            child: _buildPartWheel(
              label: 'Tail',
              count: _tailCount,
              names: _tailNames,
              colors: _tailColors,
              controller: _tailScrollController,
              itemExtent: itemExtent,
              height: columnHeight,
              partType: 2,
              onChanged: (i) {
                _currentTail = i % _tailCount;
                _addDiscovery();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartWheel({
    required String label,
    required int count,
    required List<String> names,
    required List<Color> colors,
    required FixedExtentScrollController controller,
    required double itemExtent,
    required double height,
    required int partType,
    required void Function(int) onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, _) {
            return Container(
              height: height.clamp(120.0, 300.0),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors[0].withValues(alpha: _glowAnimation.value * 0.5),
                ),
              ),
              child: ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: itemExtent,
                perspective: 0.003,
                diameterRatio: 2.0,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onChanged,
                childDelegate: ListWheelChildLoopingListDelegate(
                  children: List.generate(count, (i) {
                    final color = colors[i % colors.length];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.6)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CustomPaint(
                                painter: _CreaturePartPainter(
                                  partType: partType,
                                  variant: i,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              names[i % names.length],
                              style: SpaceTheme.bodyStyle.copyWith(
                                fontSize: 9,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCreaturePreview(BoxConstraints constraints) {
    final previewSize = math.min(constraints.maxWidth * 0.3, 160.0);

    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return Container(
            width: previewSize,
            height: previewSize * 1.5,
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SpaceTheme.alienGreen.withValues(alpha: _glowAnimation.value * 0.4),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Head
                SizedBox(
                  width: previewSize * 0.5,
                  height: previewSize * 0.35,
                  child: CustomPaint(
                    painter: _CreaturePartPainter(
                      partType: 0,
                      variant: _currentHead,
                      color: _headColors[_currentHead % _headColors.length],
                    ),
                  ),
                ),
                // Body
                SizedBox(
                  width: previewSize * 0.5,
                  height: previewSize * 0.4,
                  child: CustomPaint(
                    painter: _CreaturePartPainter(
                      partType: 1,
                      variant: _currentBody,
                      color: _bodyColors[_currentBody % _bodyColors.length],
                    ),
                  ),
                ),
                // Tail
                SizedBox(
                  width: previewSize * 0.5,
                  height: previewSize * 0.35,
                  child: CustomPaint(
                    painter: _CreaturePartPainter(
                      partType: 2,
                      variant: _currentTail,
                      color: _tailColors[_currentTail % _tailColors.length],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoAndAnswer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPartsInfoBar(),
        if (_hasConstraints) _buildConstraintBar(),
        const SizedBox(height: 8),
        Text(
          '${_discoveredCombos.length} of ${_hasConstraints ? "?" : "${_headCount * _bodyCount * _tailCount}"} combinations found',
          style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (!_gameOver) _buildAnswerRow(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAnswerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Total creatures: ',
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13)),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _answerController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
              decoration: InputDecoration(
                filled: true,
                fillColor: SpaceTheme.deepSpace,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: SpaceTheme.starYellow),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: SpaceTheme.starYellow, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: SpaceTheme.primaryButtonStyle,
                  child: const Icon(Icons.check, size: 24),
                ),
              );
            },
          ),
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
                  const Icon(Icons.pets, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.creatureForgeWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.creatureForgeWinDesc(_correctAnswer, totalScore),
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

/// Draws simple geometric alien body parts via CustomPaint.
/// partType: 0=head, 1=body, 2=tail
/// variant: 0-3 different shapes per part type
class _CreaturePartPainter extends CustomPainter {
  final int partType;
  final int variant;
  final Color color;

  _CreaturePartPainter({
    required this.partType,
    required this.variant,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (partType == 0) {
      // HEADS
      switch (variant % 4) {
        case 0: // Triangle head (crystal)
          final path = Path()
            ..moveTo(cx, 2)
            ..lineTo(w - 2, h - 2)
            ..lineTo(2, h - 2)
            ..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          // Eyes
          _drawEye(canvas, cx - w * 0.15, cy + h * 0.1, 3, color);
          _drawEye(canvas, cx + w * 0.15, cy + h * 0.1, 3, color);
          break;
        case 1: // Circle head (flame)
          canvas.drawCircle(Offset(cx, cy), math.min(w, h) * 0.4, fillPaint);
          canvas.drawCircle(Offset(cx, cy), math.min(w, h) * 0.4, edgePaint);
          // Flame spikes on top
          final spikePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
          canvas.drawLine(Offset(cx - 6, cy - h * 0.3), Offset(cx - 3, cy - h * 0.45), spikePaint);
          canvas.drawLine(Offset(cx, cy - h * 0.35), Offset(cx, cy - h * 0.5), spikePaint);
          canvas.drawLine(Offset(cx + 6, cy - h * 0.3), Offset(cx + 3, cy - h * 0.45), spikePaint);
          _drawEye(canvas, cx - 5, cy, 2, color);
          _drawEye(canvas, cx + 5, cy, 2, color);
          break;
        case 2: // Hexagon head (frost)
          final r = math.min(w, h) * 0.38;
          final path = Path();
          for (int i = 0; i < 6; i++) {
            final angle = (i * 60 - 90) * math.pi / 180;
            final px = cx + r * math.cos(angle);
            final py = cy + r * math.sin(angle);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          _drawEye(canvas, cx - 5, cy, 2, color);
          _drawEye(canvas, cx + 5, cy, 2, color);
          break;
        case 3: // Diamond head (shadow)
          final path = Path()
            ..moveTo(cx, 2)
            ..lineTo(w - 2, cy)
            ..lineTo(cx, h - 2)
            ..lineTo(2, cy)
            ..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          _drawEye(canvas, cx - 5, cy, 2, color);
          _drawEye(canvas, cx + 5, cy, 2, color);
          break;
      }
    } else if (partType == 1) {
      // BODIES
      switch (variant % 4) {
        case 0: // Rectangle body (armored)
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w * 0.7, height: h * 0.8);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, edgePaint);
          // Armor lines
          final linePaint = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1;
          canvas.drawLine(Offset(cx - w * 0.3, cy - h * 0.15), Offset(cx + w * 0.3, cy - h * 0.15), linePaint);
          canvas.drawLine(Offset(cx - w * 0.3, cy + h * 0.15), Offset(cx + w * 0.3, cy + h * 0.15), linePaint);
          break;
        case 1: // Rectangle with wings (winged)
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w * 0.5, height: h * 0.8);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, edgePaint);
          // Wings
          final wingPath = Path()
            ..moveTo(cx - w * 0.25, cy - h * 0.1)
            ..lineTo(2, cy - h * 0.3)
            ..lineTo(cx - w * 0.25, cy + h * 0.1);
          canvas.drawPath(wingPath, edgePaint);
          final wingPath2 = Path()
            ..moveTo(cx + w * 0.25, cy - h * 0.1)
            ..lineTo(w - 2, cy - h * 0.3)
            ..lineTo(cx + w * 0.25, cy + h * 0.1);
          canvas.drawPath(wingPath2, edgePaint);
          break;
        case 2: // Oval body (aquatic)
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: w * 0.75, height: h * 0.7),
            fillPaint,
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy), width: w * 0.75, height: h * 0.7),
            edgePaint,
          );
          // Fin lines
          final finPaint = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1;
          canvas.drawLine(Offset(cx - w * 0.35, cy), Offset(cx - w * 0.15, cy - h * 0.15), finPaint);
          canvas.drawLine(Offset(cx + w * 0.35, cy), Offset(cx + w * 0.15, cy - h * 0.15), finPaint);
          break;
        case 3: // Rounded rectangle (elastic)
          final rrect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: w * 0.65, height: h * 0.85),
            const Radius.circular(12),
          );
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(rrect, edgePaint);
          // Stretch marks
          final markPaint = Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1;
          for (int j = -1; j <= 1; j++) {
            canvas.drawLine(
              Offset(cx - 4, cy + j * h * 0.15),
              Offset(cx + 4, cy + j * h * 0.15),
              markPaint,
            );
          }
          break;
      }
    } else {
      // TAILS
      switch (variant % 4) {
        case 0: // Sharp stinger
          final path = Path()
            ..moveTo(cx - w * 0.2, 2)
            ..lineTo(cx + w * 0.2, 2)
            ..quadraticBezierTo(cx + w * 0.15, cy, cx, h - 2)
            ..quadraticBezierTo(cx - w * 0.15, cy, cx - w * 0.2, 2);
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          break;
        case 1: // Feathered (curved lines)
          final basePath = Path()
            ..moveTo(cx, 2)
            ..quadraticBezierTo(cx + w * 0.3, cy, cx, h - 2);
          canvas.drawPath(basePath, edgePaint);
          // Feather branches
          final featherPaint = Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1;
          for (int j = 1; j <= 3; j++) {
            final fY = h * j / 4;
            canvas.drawLine(Offset(cx, fY), Offset(cx - w * 0.3, fY - h * 0.08), featherPaint);
            canvas.drawLine(Offset(cx, fY), Offset(cx + w * 0.3, fY - h * 0.08), featherPaint);
          }
          break;
        case 2: // Spiked
          final path = Path()..moveTo(cx, 2);
          for (int j = 0; j < 4; j++) {
            final sY = 2 + (h - 4) * j / 4;
            final sDir = j.isEven ? 1.0 : -1.0;
            path.lineTo(cx + sDir * w * 0.35, sY + (h - 4) / 8);
            path.lineTo(cx, sY + (h - 4) / 4);
          }
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          break;
        case 3: // Luminous (curved tail with glow dot)
          final path = Path()
            ..moveTo(cx - w * 0.15, 2)
            ..quadraticBezierTo(cx + w * 0.3, cy, cx, h - 8);
          canvas.drawPath(path, edgePaint);
          // Glow dot at end
          canvas.drawCircle(Offset(cx, h - 6), 4, Paint()..color = color);
          canvas.drawCircle(
            Offset(cx, h - 6),
            6,
            Paint()
              ..color = color.withValues(alpha: 0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
          break;
      }
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double r, Color c) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, y), r * 0.5, Paint()..color = c);
  }

  @override
  bool shouldRepaint(covariant _CreaturePartPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.partType != partType;
}
