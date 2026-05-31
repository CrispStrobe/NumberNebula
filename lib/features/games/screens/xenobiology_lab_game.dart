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

class XenobiologyLabGame extends StatefulWidget {
  final int grade;
  final int level;
  const XenobiologyLabGame({super.key, required this.grade, required this.level});

  @override
  State<XenobiologyLabGame> createState() => _XenobiologyLabGameState();
}

class _XenobiologyLabGameState extends State<XenobiologyLabGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;
  bool _gameOver = false;

  // Puzzle data
  // Two alien types: e.g. type A has eyesA eyes and legsA legs
  // type B has eyesB eyes and legsB legs
  // Total creatures: countA of type A, countB of type B
  // Player sees: total eyes = countA*eyesA + countB*eyesB, total legs = countA*legsA + countB*legsB
  // Player must deduce countA and countB
  int _eyesA = 0, _legsA = 0;
  int _eyesB = 0, _legsB = 0;
  int _countA = 0, _countB = 0;
  int _totalEyes = 0, _totalLegs = 0;
  String _nameA = '', _nameB = '';

  // For grade 3-4: optional third type
  bool _hasThirdType = false;
  int _eyesC = 0, _legsC = 0;
  int _countC = 0;
  String _nameC = '';

  // User input
  final TextEditingController _answerAController = TextEditingController();
  final TextEditingController _answerBController = TextEditingController();
  final TextEditingController _answerCController = TextEditingController();

  // Math problems for SRI
  final List<MathProblem> _mathProblems = [];

  final _random = math.Random();

  static const List<String> _alienNames = [
    'Zorblings', 'Glimfoxes', 'Kraknids', 'Snazzles',
    'Whifflers', 'Bloopoids', 'Drixels', 'Quazzites',
  ];

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
    _answerAController.dispose();
    _answerBController.dispose();
    _answerCController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _mathProblems.clear();
      _answerAController.clear();
      _answerBController.clear();
      _answerCController.clear();
      _successController.reset();
    });

    final grade = currentDifficulty!.grade;
    _hasThirdType = grade >= 3;

    // Pick unique alien names
    final shuffledNames = List<String>.from(_alienNames)..shuffle(_random);
    _nameA = shuffledNames[0];
    _nameB = shuffledNames[1];

    if (grade <= 2) {
      // Simple: small trait numbers, small counts
      _eyesA = _random.nextInt(3) + 2; // 2-4
      _legsA = _random.nextInt(3) + 2;
      _eyesB = _random.nextInt(3) + 2;
      _legsB = _random.nextInt(3) + 2;

      // Ensure traits differ enough to have a unique solution
      while (_eyesA * _legsB == _eyesB * _legsA) {
        _eyesB = _random.nextInt(3) + 2;
        _legsB = _random.nextInt(3) + 2;
      }

      _countA = _random.nextInt(5) + 1; // 1-5
      _countB = _random.nextInt(5) + 1;
    } else {
      // Harder: larger numbers
      _eyesA = _random.nextInt(4) + 2; // 2-5
      _legsA = _random.nextInt(5) + 2;
      _eyesB = _random.nextInt(4) + 2;
      _legsB = _random.nextInt(5) + 2;

      while (_eyesA * _legsB == _eyesB * _legsA) {
        _eyesB = _random.nextInt(4) + 2;
        _legsB = _random.nextInt(5) + 2;
      }

      _countA = _random.nextInt(6) + 2; // 2-7
      _countB = _random.nextInt(6) + 2;

      if (_hasThirdType) {
        _nameC = shuffledNames[2];
        _eyesC = _random.nextInt(3) + 1;
        _legsC = _random.nextInt(4) + 2;
        _countC = _random.nextInt(3) + 1; // 1-3
      }
    }

    _totalEyes = _countA * _eyesA + _countB * _eyesB + (_hasThirdType ? _countC * _eyesC : 0);
    _totalLegs = _countA * _legsA + _countB * _legsB + (_hasThirdType ? _countC * _legsC : 0);

    // Create MathProblem instances for SRI tracking
    _mathProblems.add(MathProblem.multiplication(_countA, _eyesA, difficulty: grade));
    _mathProblems.add(MathProblem.multiplication(_countB, _legsB, difficulty: grade));
    _mathProblems.add(MathProblem.addition(_countA * _eyesA, _countB * _eyesB, difficulty: grade));

    if (mounted) {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _checkSolution() {
    if (_gameOver) return;

    final answerA = int.tryParse(_answerAController.text);
    final answerB = int.tryParse(_answerBController.text);
    int? answerC;
    if (_hasThirdType) {
      answerC = int.tryParse(_answerCController.text);
      if (answerC == null) return;
    }

    if (answerA == null || answerB == null) return;

    bool correct = answerA == _countA && answerB == _countB;
    if (_hasThirdType) {
      correct = correct && answerC == _countC;
    }

    if (correct) {
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
    int complexityBonus = _hasThirdType ? 100 : 50;
    int totalScore = baseScore + levelBonus + complexityBonus;



    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'xenobiology_lab',
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
      gameType: 'xenobiology_lab',
      difficulty: widget.level,
      mathProblems: _mathProblems,
    ));

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
                title: s.xenobiologyLabTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.xenobiologyLabInstructions,
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
          // Alien type cards
          _buildAlienCard(_nameA, _eyesA, _legsA, const Color(0xFF06FFA5)),
          const SizedBox(height: 12),
          _buildAlienCard(_nameB, _eyesB, _legsB, const Color(0xFFFFD700)),
          if (_hasThirdType) ...[
            const SizedBox(height: 12),
            _buildAlienCard(_nameC, _eyesC, _legsC, const Color(0xFFFF69B4)),
          ],
          const SizedBox(height: 20),
          // Census data
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text('Census Data',
                    style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatChip('Total Eyes', _totalEyes),
                    _buildStatChip('Total Legs', _totalLegs),
                  ],
                ),
                if (_hasThirdType) ...[
                  const SizedBox(height: 8),
                  _buildStatChip('Total Creatures', _countA + _countB + _countC),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Answer input
          _buildAnswerInput(_nameA, _answerAController, const Color(0xFF06FFA5)),
          const SizedBox(height: 8),
          _buildAnswerInput(_nameB, _answerBController, const Color(0xFFFFD700)),
          if (_hasThirdType) ...[
            const SizedBox(height: 8),
            _buildAnswerInput(_nameC, _answerCController, const Color(0xFFFF69B4)),
          ],
          const SizedBox(height: 16),
          if (!_gameOver)
            ElevatedButton(
              onPressed: _checkSolution,
              style: SpaceTheme.primaryButtonStyle,
              child: const Icon(Icons.check, size: 28),
            ),
        ],
      ),
    );
  }

  Widget _buildAlienCard(String name, int eyes, int legs, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.pest_control, color: color, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: SpaceTheme.titleStyle.copyWith(color: color, fontSize: 16)),
              Text('$eyes eyes, $legs legs',
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: SpaceTheme.bodyStyle.copyWith(fontSize: 11, color: Colors.white70)),
          Text('$value',
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 24, color: SpaceTheme.starYellow)),
        ],
      ),
    );
  }

  Widget _buildAnswerInput(String name, TextEditingController controller, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text('$name:', style: SpaceTheme.bodyStyle.copyWith(color: color, fontSize: 14)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 18),
            decoration: InputDecoration(
              filled: true,
              fillColor: SpaceTheme.deepSpace,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
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
                  const Icon(Icons.biotech, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.xenobiologyLabWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.xenobiologyLabWinDesc(totalScore),
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
