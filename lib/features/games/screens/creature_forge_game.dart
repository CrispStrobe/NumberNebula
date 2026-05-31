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
  late AnimationController _successController;
  late Animation<double> _successAnimation;

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

  static const List<IconData> _headIcons = [Icons.diamond, Icons.local_fire_department, Icons.ac_unit, Icons.nights_stay];
  static const List<IconData> _bodyIcons = [Icons.shield, Icons.flight, Icons.water, Icons.bubble_chart];
  static const List<IconData> _tailIcons = [Icons.flash_on, Icons.grass, Icons.star, Icons.lightbulb];

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
    _answerController.dispose();
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
    } else if (grade == 3) {
      _headCount = 3;
      _bodyCount = 3;
      _tailCount = 3;
      _hasConstraints = true;
      _forbiddenCombos = _random.nextInt(3) + 2; // 2-4 forbidden
    } else {
      _headCount = 4;
      _bodyCount = 4;
      _tailCount = 4;
      _hasConstraints = true;
      _forbiddenCombos = _random.nextInt(5) + 3; // 3-7 forbidden
    }

    _correctAnswer = _headCount * _bodyCount * _tailCount - _forbiddenCombos;

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _cycleHead(int direction) {
    setState(() {
      _currentHead = (_currentHead + direction) % _headCount;
      _addDiscovery();
    });
  }

  void _cycleBody(int direction) {
    setState(() {
      _currentBody = (_currentBody + direction) % _bodyCount;
      _addDiscovery();
    });
  }

  void _cycleTail(int direction) {
    setState(() {
      _currentTail = (_currentTail + direction) % _tailCount;
      _addDiscovery();
    });
  }

  void _addDiscovery() {
    final key = '$_currentHead-$_currentBody-$_currentTail';
    _discoveredCombos.add(key);
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
          // Parts info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPartInfo('Heads', _headCount, const Color(0xFF06FFA5)),
                _buildPartInfo('Bodies', _bodyCount, const Color(0xFFFFD700)),
                _buildPartInfo('Tails', _tailCount, const Color(0xFFFF69B4)),
              ],
            ),
          ),
          if (_hasConstraints) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceTheme.rocketRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$_forbiddenCombos combinations are unstable and forbidden!',
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: SpaceTheme.rocketRed),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Creature preview with swipe controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF06FFA5).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildPartSelector('Head', _currentHead, _headCount,
                    _headNames, _headIcons, const Color(0xFF06FFA5), _cycleHead),
                const SizedBox(height: 8),
                _buildPartSelector('Body', _currentBody, _bodyCount,
                    _bodyNames, _bodyIcons, const Color(0xFFFFD700), _cycleBody),
                const SizedBox(height: 8),
                _buildPartSelector('Tail', _currentTail, _tailCount,
                    _tailNames, _tailIcons, const Color(0xFFFF69B4), _cycleTail),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Discovered: ${_discoveredCombos.length}',
            style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
          ),
          const SizedBox(height: 16),
          // Answer input
          if (!_gameOver) ...[
            Text('How many unique creatures total?',
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _answerController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SpaceTheme.deepSpace,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpaceTheme.starYellow),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpaceTheme.starYellow, width: 2),
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

  Widget _buildPartInfo(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: SpaceTheme.headlineStyle.copyWith(color: color, fontSize: 24)),
        Text(label, style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildPartSelector(String label, int current, int total,
      List<String> names, List<IconData> icons, Color color, void Function(int) onCycle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onCycle(-1),
          icon: const Icon(Icons.chevron_left, color: Colors.white),
        ),
        Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icons[current % icons.length], color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                names[current % names.length],
                style: SpaceTheme.bodyStyle.copyWith(color: color, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onCycle(1),
          icon: const Icon(Icons.chevron_right, color: Colors.white),
        ),
      ],
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
