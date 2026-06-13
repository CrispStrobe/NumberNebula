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
import '../services/vault_cracker_logic.dart';

class VaultCrackerGame extends StatefulWidget {
  final int grade;
  final int level;
  const VaultCrackerGame({super.key, required this.grade, required this.level});

  @override
  State<VaultCrackerGame> createState() => _VaultCrackerGameState();
}

class _VaultCrackerGameState extends State<VaultCrackerGame>
    with TickerProviderStateMixin, GameAnimationsMixin<VaultCrackerGame> {

  VaultCrackerPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Player's answer input
  List<int?> _answer = [];
  bool _gameOver = false;

  // Wordle-style guess history
  List<List<int>> _guessHistory = [];
  static const int _maxGuesses = 6;

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

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _guessHistory = [];
      successController.reset();
    });

    final generated = VaultCrackerLogic.generate({
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _answer = List.filled(generated.codeLength, null);
        _isGenerating = false;
      });
    }
  }

  void _setDigit(int position, int digit) {
    if (_gameOver) return;
    setState(() {
      _answer[position] = digit;
    });
  }

  void _clearAnswer() {
    if (_gameOver) return;
    setState(() {
      _answer = List.filled(puzzle?.codeLength ?? 3, null);
    });
  }

  void _submitAnswer() {
    if (_gameOver || puzzle == null) return;
    if (_answer.any((d) => d == null)) return;

    final guess = _answer.map((d) => d!).toList();

    setState(() {
      _guessHistory.add(List<int>.from(guess));
    });

    if (puzzle!.isCorrect(guess)) {
      _handleWin();
    } else if (_guessHistory.length >= _maxGuesses) {
      _handleLoss();
    } else {
      // Reset input for next attempt
      HapticFeedback.mediumImpact();
      setState(() {
        _answer = List.filled(puzzle!.codeLength, null);
      });
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    // Bonus for fewer guesses
    int guessBonus = (_maxGuesses - _guessHistory.length) * 15;
    int totalScore = baseScore + levelBonus + guessBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'vault_cracker',
      difficulty: widget.level,
      score: totalScore,
    ));

    successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(_guessHistory.length, totalScore),
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
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    final locale = Localizations.localeOf(context);
    final isGerman = locale.languageCode == 'de';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Clue attempts list and guess history
          Expanded(
            child: ListView(
              children: [
                ...List.generate(
                  puzzle!.clues.length,
                  (index) => _buildClueRow(puzzle!.clues[index], index, isGerman),
                ),
                const SizedBox(height: 8),
                _buildGuessHistory(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Answer input row
          if (!_gameOver) ...[
            _buildAnswerRow(),
            const SizedBox(height: 8),
            _buildDigitPad(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _clearAnswer,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Clear'),
                  style: SpaceTheme.secondaryButtonStyle,
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed:
                      _answer.any((d) => d == null) ? null : _submitAnswer,
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

  Widget _buildClueRow(VaultClue clue, int index, bool isGerman) {
    final clueText = isGerman ? clue.clueTextDe : clue.clueTextEn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Clue number badge
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 13, color: SpaceTheme.starYellow, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Clue text — mathematical constraint
            Expanded(
              child: Text(
                clueText,
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(puzzle!.codeLength, (i) {
            final hasDigit = _answer[i] != null;
            return GestureDetector(
              onTap: () {
                // Tapping a filled slot clears it
                if (hasDigit) {
                  setState(() {
                    _answer[i] = null;
                  });
                }
              },
              child: Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasDigit
                        ? SpaceTheme.starYellow
                        : SpaceTheme.nebulaPurple
                            .withValues(alpha: glowAnimation.value),
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
                    hasDigit ? _answer[i].toString() : '?',
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 22,
                      color: hasDigit ? Colors.white : Colors.white38,
                    ),
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
      children: List.generate(digitRange, (index) {
        final digit = index + 1; // 1-based digits
        return GestureDetector(
          onTap: () {
            // Place in first empty slot
            for (int i = 0; i < puzzle!.codeLength; i++) {
              if (_answer[i] == null) {
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
                  color: SpaceTheme.starYellow.withValues(alpha: 0.7),
                  width: 2),
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

  /// Returns a list of colors for each digit in the guess:
  /// green = correct position, yellow = wrong position, gray = not in code.
  List<Color> _computeGuessColors(List<int> guess) {
    final secret = puzzle!.secretCode;
    final len = secret.length;
    final colors = List<Color>.filled(len, Colors.grey.shade700);

    // Track which secret positions have been matched
    final secretMatched = List<bool>.filled(len, false);
    final guessMatched = List<bool>.filled(len, false);

    // First pass: exact matches (green)
    for (int i = 0; i < len; i++) {
      if (guess[i] == secret[i]) {
        colors[i] = SpaceTheme.alienGreen;
        secretMatched[i] = true;
        guessMatched[i] = true;
      }
    }

    // Second pass: wrong position matches (yellow)
    for (int i = 0; i < len; i++) {
      if (guessMatched[i]) continue;
      for (int j = 0; j < len; j++) {
        if (secretMatched[j]) continue;
        if (guess[i] == secret[j]) {
          colors[i] = SpaceTheme.starYellow;
          secretMatched[j] = true;
          break;
        }
      }
    }

    return colors;
  }

  Widget _buildGuessHistory() {
    if (_guessHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Text(
            '${_guessHistory.length} / $_maxGuesses',
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ),
        ...List.generate(_guessHistory.length, (index) {
          final guess = _guessHistory[index];
          final colors = _computeGuessColors(guess);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(guess.length, (d) {
                return Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: colors[d],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors[d] == Colors.grey.shade700
                          ? Colors.grey.shade600
                          : colors[d].withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      guess[d].toString(),
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWinDialog(int attempts, int totalScore) {
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
                  const Icon(Icons.lock_open,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.vaultCrackerWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.vaultCrackerWinDesc(attempts, totalScore),
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center),
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
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.vaultCrackerLoseDesc,
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            // Show secret code
            Text(
              'Code: ${puzzle!.secretCode.join('')}',
              style:
                  SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow),
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
