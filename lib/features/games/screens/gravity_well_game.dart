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
import '../services/gravity_well_logic.dart';

class GravityWellGame extends StatefulWidget {
  final int grade;
  final int level;
  const GravityWellGame({super.key, required this.grade, required this.level});

  @override
  State<GravityWellGame> createState() => _GravityWellGameState();
}

class _GravityWellGameState extends State<GravityWellGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  GravityWellPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // User's answers for unknown weights: label -> entered weight
  Map<String, int?> _userAnswers = {};
  bool _gameOver = false;

  // Text controllers for input fields
  final Map<String, TextEditingController> _controllers = {};

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
    _glowController.stop();
    _successController.stop();
    _glowController.dispose();
    _successController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _successController.reset();
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
    });

    final generated = GravityWellLogic.generate({
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _userAnswers = {for (final label in generated.unknownWeights.keys) label: null};
        for (final label in generated.unknownWeights.keys) {
          _controllers[label] = TextEditingController();
        }
        _isGenerating = false;
      });
    }
  }

  void _checkSolution() {
    if (puzzle == null || _gameOver) return;

    // Parse all input fields
    for (final label in puzzle!.unknownWeights.keys) {
      final text = _controllers[label]?.text ?? '';
      _userAnswers[label] = int.tryParse(text);
    }

    if (_userAnswers.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.gravityWellLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
        ),
      );
      return;
    }

    final userMap = _userAnswers.map((k, v) => MapEntry(k, v!));
    if (puzzle!.checkSolution(userMap)) {
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
    int complexityBonus = puzzle!.scales.length * 30 + puzzle!.unknownWeights.length * 40;
    int totalScore = baseScore + levelBonus + complexityBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'gravity_well',
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
      gameType: 'gravity_well',
      difficulty: widget.level,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.gravityWellLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (puzzle == null || _isGenerating) {
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
                title: s.gravityWellTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    final s = S.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.gravityWellInstructions,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Known weights reference
          if (puzzle!.knownWeights.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: SpaceTheme.alienGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Known: ${puzzle!.knownWeights.entries.map((e) => "${e.key} = ${e.value} kg").join(", ")}',
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 13, color: SpaceTheme.alienGreen),
                  ),
                ],
              ),
            ),

          // Scales
          ...List.generate(puzzle!.scales.length, (i) => _buildScaleCard(i)),

          const SizedBox(height: 16),

          // Answer input section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: SpaceTheme.cardDecoration.copyWith(
              border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'Enter unknown weights:',
                  style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 10),
                ...puzzle!.unknownWeights.keys.map((label) => _buildAnswerInput(label)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Submit button
          if (!_gameOver)
            Center(
              child: ElevatedButton.icon(
                onPressed: _checkSolution,
                icon: const Icon(Icons.balance),
                label: const Text('Check Balance'),
                style: SpaceTheme.primaryButtonStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScaleCard(int index) {
    final scale = puzzle!.scales[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Scale header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.balance, color: SpaceTheme.starYellow, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Scale ${index + 1}',
                      style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Scale visualization
                Row(
                  children: [
                    // Left side
                    Expanded(child: _buildScaleSide(scale.leftSide, Colors.cyan)),
                    // Balance symbol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Text(
                        '=',
                        style: TextStyle(
                          color: SpaceTheme.starYellow,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Right side
                    Expanded(child: _buildScaleSide(scale.rightSide, Colors.orange)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScaleSide(List<ScaleItem> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: item.isKnown
                  ? SpaceTheme.deepSpace.withValues(alpha: 0.8)
                  : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.isKnown ? color : SpaceTheme.starYellow,
                width: 1.5,
              ),
            ),
            child: Text(
              item.isKnown ? item.label : '${item.label} = ?',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: item.isKnown ? Colors.white : SpaceTheme.starYellow,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswerInput(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06FFA5), Color(0xFF00C9DB)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                label,
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text('= ', style: TextStyle(color: Colors.white, fontSize: 18)),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _controllers[label],
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
              enabled: !_gameOver,
              decoration: InputDecoration(
                hintText: '?',
                hintStyle: const TextStyle(color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: SpaceTheme.nebulaPurple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: SpaceTheme.starYellow, width: 2),
                ),
                filled: true,
                fillColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('kg', style: TextStyle(color: Colors.white54, fontSize: 14)),
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
                  const Icon(Icons.balance, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.gravityWellWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.gravityWellWinDesc(totalScore),
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
