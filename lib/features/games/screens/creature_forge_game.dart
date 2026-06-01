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

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle parameters
  int _headCount = 2;
  int _bodyCount = 2;
  int _tailCount = 2;
  int _forbiddenCombos = 0;
  int _correctAnswer = 8;
  bool _hasConstraints = false;
  String _constraintText = '';

  // Player state
  int _selectedHead = 0;
  int _selectedBody = 0;
  int _selectedTail = 0;
  final Set<String> _discoveredCombos = {};
  final TextEditingController _answerController = TextEditingController();

  final _random = math.Random();

  // Colors per part category
  static const _headColors = [Color(0xFF06FFA5), Color(0xFFFFD700), Color(0xFFFF69B4), Color(0xFF00C9DB)];
  static const _bodyColors = [Color(0xFF6B48FF), Color(0xFFFF6B35), Color(0xFF457B9D), Color(0xFFBB86FC)];
  static const _tailColors = [Color(0xFFE63946), Color(0xFF06FFA5), Color(0xFFFFD700), Color(0xFF00C9DB)];

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
    _answerController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    final grade = currentDifficulty!.grade;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _discoveredCombos.clear();
      _answerController.clear();
      _successController.reset();
      _selectedHead = 0;
      _selectedBody = 0;
      _selectedTail = 0;
    });

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
      _constraintText = 'Winged bodies cannot pair with spiked tails';
    } else {
      _headCount = 4;
      _bodyCount = 4;
      _tailCount = 4;
      _hasConstraints = true;
      _forbiddenCombos = _random.nextInt(5) + 3;
      _constraintText = 'Winged bodies need crystal heads\nAquatic bodies reject flame tails';
    }

    _correctAnswer = _headCount * _bodyCount * _tailCount - _forbiddenCombos;

    setState(() => _isGenerating = false);
  }

  String _comboKey(int h, int b, int t) => '$h-$b-$t';

  bool _isForbidden(int h, int b, int t) {
    if (!_hasConstraints) return false;
    // Simple deterministic forbidden combos based on part indices
    if (b == 1 && t == 2) return true; // Winged + spiked
    if (_headCount >= 4) {
      if (b == 2 && t == 1) return true; // Aquatic + feathered
      if (b == 1 && h != 0) return true; // Winged needs crystal head (index 0)
    }
    return false;
  }

  void _addCreature() {
    if (_gameOver) return;
    final key = _comboKey(_selectedHead, _selectedBody, _selectedTail);

    if (_discoveredCombos.contains(key)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already discovered this creature!'),
          backgroundColor: SpaceTheme.rocketRed,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_isForbidden(_selectedHead, _selectedBody, _selectedTail)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid combination! $_constraintText'),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _discoveredCombos.add(key);
    });
  }

  void _submitAnswer() {
    if (_gameOver) return;
    final answer = int.tryParse(_answerController.text);
    if (answer == null) return;

    if (answer == _correctAnswer) {
      _handleWin();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not quite! You said $answer, try again.'),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int discoveryBonus = _discoveredCombos.length * 10;
    int totalScore = baseScore + levelBonus + discoveryBonus;

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
                title: s.creatureForgeTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Instructions
                          _buildInstructions(s),
                          const SizedBox(height: 8),

                          // Part selection rows
                          _buildPartRow('HEADS', 0, _headCount, _selectedHead,
                              _headColors, (i) => setState(() => _selectedHead = i)),
                          const SizedBox(height: 8),
                          _buildPartRow('BODIES', 1, _bodyCount, _selectedBody,
                              _bodyColors, (i) => setState(() => _selectedBody = i)),
                          const SizedBox(height: 8),
                          _buildPartRow('TAILS', 2, _tailCount, _selectedTail,
                              _tailColors, (i) => setState(() => _selectedTail = i)),

                          const SizedBox(height: 12),

                          // Preview + Add button
                          _buildPreviewAndAdd(),

                          if (_hasConstraints) ...[
                            const SizedBox(height: 8),
                            _buildConstraintBanner(),
                          ],

                          const SizedBox(height: 12),

                          // Gallery + answer
                          _buildGalleryAndAnswer(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    );
                  },
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
              s.creatureForgeInstructions,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartRow(String label, int partType, int count, int selected,
      List<Color> colors, void Function(int) onSelect) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ($count)',
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 14,
              color: SpaceTheme.starYellow,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(count, (i) {
              final isSelected = i == selected;
              final color = colors[i % colors.length];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.25)
                          : SpaceTheme.deepSpace.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : Colors.white12,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                          : null,
                    ),
                    child: SizedBox(
                      height: 50,
                      child: CustomPaint(
                        painter: _CreaturePartPainter(
                          partType: partType,
                          variant: i,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAndAdd() {
    final headColor = _headColors[_selectedHead % _headColors.length];
    final bodyColor = _bodyColors[_selectedBody % _bodyColors.length];
    final tailColor = _tailColors[_selectedTail % _tailColors.length];
    final comboKey = _comboKey(_selectedHead, _selectedBody, _selectedTail);
    final alreadyFound = _discoveredCombos.contains(comboKey);
    final forbidden = _isForbidden(_selectedHead, _selectedBody, _selectedTail);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: forbidden
                  ? SpaceTheme.rocketRed.withValues(alpha: _glowAnimation.value)
                  : alreadyFound
                      ? Colors.white24
                      : SpaceTheme.starYellow.withValues(alpha: _glowAnimation.value * 0.6),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview: head + body + tail stacked
              Column(
                children: [
                  SizedBox(
                    width: 44, height: 44,
                    child: CustomPaint(
                      painter: _CreaturePartPainter(partType: 0, variant: _selectedHead, color: headColor),
                    ),
                  ),
                  SizedBox(
                    width: 44, height: 44,
                    child: CustomPaint(
                      painter: _CreaturePartPainter(partType: 1, variant: _selectedBody, color: bodyColor),
                    ),
                  ),
                  SizedBox(
                    width: 44, height: 44,
                    child: CustomPaint(
                      painter: _CreaturePartPainter(partType: 2, variant: _selectedTail, color: tailColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  if (forbidden)
                    const Text('FORBIDDEN', style: TextStyle(color: SpaceTheme.rocketRed, fontSize: 12, fontWeight: FontWeight.bold))
                  else if (alreadyFound)
                    const Text('ALREADY FOUND', style: TextStyle(color: Colors.white54, fontSize: 12))
                  else
                    const Text('NEW SPECIES!', style: TextStyle(color: SpaceTheme.alienGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: (alreadyFound || forbidden || _gameOver) ? null : _addCreature,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('ADD'),
                    style: SpaceTheme.primaryButtonStyle.copyWith(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConstraintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.rocketRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: SpaceTheme.rocketRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _constraintText,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14, color: SpaceTheme.rocketRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryAndAnswer() {
    final total = _headCount * _bodyCount * _tailCount;
    return Column(
      children: [
        // Discovery counter
        Text(
          '${_discoveredCombos.length} discovered${_hasConstraints ? "" : " of $total"}',
          style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 16),
        ),
        const SizedBox(height: 8),

        // Gallery grid of discovered creatures
        if (_discoveredCombos.isNotEmpty)
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(4),
              itemCount: _discoveredCombos.length,
              itemBuilder: (context, index) {
                final key = _discoveredCombos.elementAt(index);
                final parts = key.split('-').map(int.parse).toList();
                return Container(
                  width: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 20, width: 20,
                        child: CustomPaint(painter: _CreaturePartPainter(
                          partType: 0, variant: parts[0],
                          color: _headColors[parts[0] % _headColors.length],
                        ))),
                      SizedBox(height: 20, width: 20,
                        child: CustomPaint(painter: _CreaturePartPainter(
                          partType: 1, variant: parts[1],
                          color: _bodyColors[parts[1] % _bodyColors.length],
                        ))),
                      SizedBox(height: 20, width: 20,
                        child: CustomPaint(painter: _CreaturePartPainter(
                          partType: 2, variant: parts[2],
                          color: _tailColors[parts[2] % _tailColors.length],
                        ))),
                    ],
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // Answer input
        if (!_gameOver)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Total possible: ', style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _answerController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
                  decoration: InputDecoration(
                    hintText: '?',
                    hintStyle: SpaceTheme.bodyStyle.copyWith(color: Colors.white30),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: SpaceTheme.nebulaPurple),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: SpaceTheme.starYellow, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submitAnswer,
                style: SpaceTheme.primaryButtonStyle,
                child: const Text('SUBMIT'),
              ),
            ],
          ),
      ],
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
                  const Icon(Icons.pets, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.creatureForgeWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    'You found ${_discoveredCombos.length} species!\nCorrect total: $_correctAnswer',
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(s.creatureForgeWinDesc(_correctAnswer, score),
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

/// Draws simple geometric alien body parts.
/// partType: 0=head, 1=body, 2=tail. variant: 0-3 different shapes per type.
class _CreaturePartPainter extends CustomPainter {
  final int partType;
  final int variant;
  final Color color;

  _CreaturePartPainter({required this.partType, required this.variant, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) * 0.4;

    final fillPaint = Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.fill;
    final edgePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0;

    if (partType == 0) {
      // HEADS
      switch (variant % 4) {
        case 0: // Triangle (crystal)
          final path = Path()..moveTo(cx, 2)..lineTo(w - 2, h - 2)..lineTo(2, h - 2)..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          _drawEye(canvas, cx - w * 0.12, cy + h * 0.08, math.max(2, r * 0.15), color);
          _drawEye(canvas, cx + w * 0.12, cy + h * 0.08, math.max(2, r * 0.15), color);
        case 1: // Circle (flame)
          canvas.drawCircle(Offset(cx, cy), r, fillPaint);
          canvas.drawCircle(Offset(cx, cy), r, edgePaint);
          final sp = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
          canvas.drawLine(Offset(cx - 4, cy - r * 0.7), Offset(cx - 2, cy - r * 1.1), sp);
          canvas.drawLine(Offset(cx, cy - r * 0.8), Offset(cx, cy - r * 1.2), sp);
          canvas.drawLine(Offset(cx + 4, cy - r * 0.7), Offset(cx + 2, cy - r * 1.1), sp);
          _drawEye(canvas, cx - r * 0.3, cy, math.max(2, r * 0.12), color);
          _drawEye(canvas, cx + r * 0.3, cy, math.max(2, r * 0.12), color);
        case 2: // Hexagon (frost)
          final path = Path();
          for (int i = 0; i < 6; i++) {
            final angle = (i * 60 - 90) * math.pi / 180;
            final px = cx + r * math.cos(angle);
            final py = cy + r * math.sin(angle);
            i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          _drawEye(canvas, cx - r * 0.3, cy, math.max(2, r * 0.12), color);
          _drawEye(canvas, cx + r * 0.3, cy, math.max(2, r * 0.12), color);
        default: // Diamond (shadow)
          final path = Path()..moveTo(cx, 2)..lineTo(w - 2, cy)..lineTo(cx, h - 2)..lineTo(2, cy)..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
          _drawEye(canvas, cx - r * 0.25, cy, math.max(2, r * 0.12), color);
          _drawEye(canvas, cx + r * 0.25, cy, math.max(2, r * 0.12), color);
      }
    } else if (partType == 1) {
      // BODIES
      switch (variant % 4) {
        case 0: // Rectangle (armored)
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w * 0.7, height: h * 0.8);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, edgePaint);
          final lp = Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1;
          canvas.drawLine(Offset(cx - w * 0.3, cy - h * 0.12), Offset(cx + w * 0.3, cy - h * 0.12), lp);
          canvas.drawLine(Offset(cx - w * 0.3, cy + h * 0.12), Offset(cx + w * 0.3, cy + h * 0.12), lp);
        case 1: // Winged
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: w * 0.5, height: h * 0.8);
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, edgePaint);
          final wp = Path()..moveTo(cx - w * 0.25, cy - h * 0.1)..lineTo(2, cy - h * 0.3)..lineTo(cx - w * 0.25, cy + h * 0.1);
          canvas.drawPath(wp, edgePaint);
          final wp2 = Path()..moveTo(cx + w * 0.25, cy - h * 0.1)..lineTo(w - 2, cy - h * 0.3)..lineTo(cx + w * 0.25, cy + h * 0.1);
          canvas.drawPath(wp2, edgePaint);
        case 2: // Oval (aquatic)
          canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.75, height: h * 0.7), fillPaint);
          canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w * 0.75, height: h * 0.7), edgePaint);
        default: // Rounded rect (elastic)
          final rrect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: w * 0.65, height: h * 0.85),
            const Radius.circular(10),
          );
          canvas.drawRRect(rrect, fillPaint);
          canvas.drawRRect(rrect, edgePaint);
      }
    } else {
      // TAILS
      switch (variant % 4) {
        case 0: // Stinger
          final path = Path()
            ..moveTo(cx - w * 0.18, 2)..lineTo(cx + w * 0.18, 2)
            ..quadraticBezierTo(cx + w * 0.12, cy, cx, h - 2)
            ..quadraticBezierTo(cx - w * 0.12, cy, cx - w * 0.18, 2);
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
        case 1: // Feathered
          final bp = Path()..moveTo(cx, 2)..quadraticBezierTo(cx + w * 0.3, cy, cx, h - 2);
          canvas.drawPath(bp, edgePaint);
          final fp = Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1;
          for (int j = 1; j <= 3; j++) {
            final fY = h * j / 4;
            canvas.drawLine(Offset(cx, fY), Offset(cx - w * 0.25, fY - h * 0.06), fp);
            canvas.drawLine(Offset(cx, fY), Offset(cx + w * 0.25, fY - h * 0.06), fp);
          }
        case 2: // Spiked
          final path = Path()..moveTo(cx, 2);
          for (int j = 0; j < 4; j++) {
            final sY = 2 + (h - 4) * j / 4;
            final d = j.isEven ? 1.0 : -1.0;
            path.lineTo(cx + d * w * 0.3, sY + (h - 4) / 8);
            path.lineTo(cx, sY + (h - 4) / 4);
          }
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, edgePaint);
        default: // Luminous
          final path = Path()..moveTo(cx - w * 0.12, 2)..quadraticBezierTo(cx + w * 0.25, cy, cx, h - 8);
          canvas.drawPath(path, edgePaint);
          canvas.drawCircle(Offset(cx, h - 6), 3, Paint()..color = color);
          canvas.drawCircle(Offset(cx, h - 6), 5,
            Paint()..color = color.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }
  }

  void _drawEye(Canvas canvas, double x, double y, double r, Color c) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x, y), r * 0.5, Paint()..color = c);
  }

  @override
  bool shouldRepaint(covariant _CreaturePartPainter old) =>
      old.variant != variant || old.partType != partType || old.color != color;
}
