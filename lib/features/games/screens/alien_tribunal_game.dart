import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/alien_tribunal_logic.dart';

class AlienTribunalGame extends StatefulWidget {
  final int grade;
  final int level;
  const AlienTribunalGame({super.key, required this.grade, required this.level});

  @override
  State<AlienTribunalGame> createState() => _AlienTribunalGameState();
}

class _AlienTribunalGameState extends State<AlienTribunalGame>
    with TickerProviderStateMixin, GameAnimationsMixin<AlienTribunalGame> {

  AlienTribunalPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // User's assignment: person index -> true (truth-teller) or false (liar) or null
  Map<int, bool?> _userAssignment = {};
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);

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
    glowController.stop();
    successController.stop();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() async {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      successController.reset();
    });

    final generated = await compute(AlienTribunalLogic.generate, {
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _userAssignment = {};
        _isGenerating = false;
      });
    }
  }

  void _toggleAssignment(int index) {
    if (_gameOver) return;
    setState(() {
      final current = _userAssignment[index];
      if (current == null) {
        _userAssignment[index] = true; // truth-teller
      } else if (current == true) {
        _userAssignment[index] = false; // liar
      } else {
        _userAssignment[index] = null; // unset
      }
    });
  }

  void _checkSolution() {
    if (puzzle == null || _gameOver) return;

    // All must be assigned
    if (_userAssignment.length < puzzle!.personCount ||
        _userAssignment.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.alienTribunalLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
        ),
      );
      return;
    }

    final userMap = _userAssignment.map((k, v) => MapEntry(k, v!));
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
    int complexityBonus = puzzle!.personCount * 40;
    int totalScore = baseScore + levelBonus + complexityBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'alien_tribunal',
      difficulty: widget.level,
      score: totalScore,
    ));

    successController.forward(from: 0.0);

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
      gameType: 'alien_tribunal',
      difficulty: widget.level,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.alienTribunalLoseDesc)),
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
                title: s.alienTribunalTitle,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              s.alienTribunalInstructions,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),

          // Person cards — fill available space
          Expanded(
            child: ListView.builder(
              itemCount: puzzle!.personCount,
              itemBuilder: (context, i) => _buildPersonCard(i),
            ),
          ),

          // Submit button
          if (!_gameOver)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _checkSolution,
                  icon: const Icon(Icons.gavel, size: 24),
                  label: const Text('Submit Verdict', style: TextStyle(fontSize: 18)),
                  style: SpaceTheme.primaryButtonStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(int index) {
    final person = puzzle!.people[index];
    final assignment = _userAssignment[index];

    Color borderColor;
    String statusText;
    IconData statusIcon;

    if (assignment == null) {
      borderColor = SpaceTheme.nebulaPurple;
      statusText = '???';
      statusIcon = Icons.help_outline;
    } else if (assignment) {
      borderColor = SpaceTheme.alienGreen;
      statusText = S.of(context)!.alienTribunalTruth;
      statusIcon = Icons.check_circle;
    } else {
      borderColor = SpaceTheme.rocketRed;
      statusText = S.of(context)!.alienTribunalLiar;
      statusIcon = Icons.cancel;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleAssignment(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor.withValues(
                    alpha: assignment == null ? glowAnimation.value : 0.9,
                  ),
                  width: 2,
                ),
                boxShadow: assignment != null
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B48FF), Color(0xFFE63946)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        person.name[0],
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name and statement
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: SpaceTheme.titleStyle.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          person.statement,
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status indicator
                  Column(
                    children: [
                      Icon(statusIcon, color: borderColor, size: 36),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWinDialog(int totalScore) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gavel, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.alienTribunalWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.alienTribunalWinDesc(totalScore),
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
