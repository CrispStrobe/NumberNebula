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
import '../services/vault_cracker_logic.dart';

class VaultCrackerGame extends StatefulWidget {
  final int grade;
  final int level;
  const VaultCrackerGame({super.key, required this.grade, required this.level});

  @override
  State<VaultCrackerGame> createState() => _VaultCrackerGameState();
}

class _VaultCrackerGameState extends State<VaultCrackerGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  VaultCrackerPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Current guess being built
  List<int?> _currentGuess = [];
  // History of past guesses with feedback
  List<VaultClue> _guessHistory = [];
  int _attemptsRemaining = 0;
  bool _gameOver = false;

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
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _guessHistory.clear();
      _gameOver = false;
      _successController.reset();
    });

    final generated = VaultCrackerLogic.generate({
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _currentGuess = List.filled(generated.codeLength, null);
        _attemptsRemaining = generated.maxAttempts;
        _isGenerating = false;
      });
    }
  }

  void _setDigit(int position, int digit) {
    if (_gameOver) return;
    setState(() {
      _currentGuess[position] = digit;
    });
  }

  void _submitGuess() {
    if (_gameOver || puzzle == null) return;
    if (_currentGuess.any((d) => d == null)) return;

    final guess = _currentGuess.map((d) => d!).toList();
    final feedback = puzzle!.evaluate(guess);

    setState(() {
      _guessHistory.add(VaultClue(guess: guess, feedback: feedback));
      _attemptsRemaining--;
      _currentGuess = List.filled(puzzle!.codeLength, null);
    });

    if (puzzle!.isCorrect(guess)) {
      _handleWin();
    } else if (_attemptsRemaining <= 0) {
      _handleLoss();
    }
  }

  void _clearGuess() {
    setState(() {
      _currentGuess = List.filled(puzzle?.codeLength ?? 3, null);
    });
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;
    final attempts = _guessHistory.length;
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int speedBonus = (_attemptsRemaining * 50);
    int totalScore = baseScore + levelBonus + speedBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'vault_cracker',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(attempts, totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    _gameOver = true;

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'vault_cracker',
      difficulty: widget.level,
    ));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildLoseDialog(),
      );
    }
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
                title: s.vaultCrackerTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.vaultCrackerInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              // Attempts remaining
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${s.level}: $_attemptsRemaining',
                  style: SpaceTheme.titleStyle.copyWith(
                    color: _attemptsRemaining <= 2
                        ? SpaceTheme.rocketRed
                        : SpaceTheme.starYellow,
                  ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Guess history
          Expanded(
            child: ListView.builder(
              itemCount: _guessHistory.length,
              itemBuilder: (context, index) => _buildClueRow(_guessHistory[index]),
            ),
          ),
          const SizedBox(height: 8),
          // Current guess input
          if (!_gameOver) ...[
            _buildCurrentGuessRow(),
            const SizedBox(height: 8),
            _buildDigitPad(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _clearGuess,
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(S.of(context)!.playAgain),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _currentGuess.any((d) => d == null) ? null : _submitGuess,
                  style: SpaceTheme.primaryButtonStyle,
                  child: const Icon(Icons.check),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildClueRow(VaultClue clue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(clue.guess.length, (i) {
          Color bgColor;
          switch (clue.feedback[i]) {
            case DigitFeedback.green:
              bgColor = Colors.green;
              break;
            case DigitFeedback.yellow:
              bgColor = Colors.amber;
              break;
            case DigitFeedback.gray:
              bgColor = Colors.grey.shade700;
              break;
          }
          return Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Text(
                clue.guess[i].toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentGuessRow() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(puzzle!.codeLength, (i) {
            final hasDigit = _currentGuess[i] != null;
            return Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasDigit
                      ? SpaceTheme.starYellow
                      : SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
                  width: 2,
                ),
                boxShadow: hasDigit
                    ? [
                        BoxShadow(
                          color: SpaceTheme.starYellow.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  hasDigit ? _currentGuess[i].toString() : '?',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 22,
                    color: hasDigit ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildDigitPad() {
    final digitRange = puzzle!.digitRange;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(digitRange, (digit) {
        return GestureDetector(
          onTap: () {
            // Place in first empty slot
            for (int i = 0; i < puzzle!.codeLength; i++) {
              if (_currentGuess[i] == null) {
                _setDigit(i, digit);
                break;
              }
            }
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: SpaceTheme.starGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
            ),
            child: Center(
              child: Text(
                digit.toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWinDialog(int attempts, int totalScore) {
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
                  const Icon(Icons.lock_open, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.vaultCrackerWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.vaultCrackerWinDesc(attempts, totalScore),
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

  Widget _buildLoseDialog() {
    final s = S.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(s.vaultCrackerLoseTitle,
                style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.vaultCrackerLoseDesc,
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            // Show secret code
            Text(
              'Code: ${puzzle!.secretCode.join('')}',
              style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow),
            ),
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
    );
  }
}
