import 'dart:math' as math;
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
import '../services/comm_relay_logic.dart';

class CommRelayGame extends StatefulWidget {
  final int grade;
  final int level;
  const CommRelayGame({super.key, required this.grade, required this.level});

  @override
  State<CommRelayGame> createState() => _CommRelayGameState();
}

class _CommRelayGameState extends State<CommRelayGame>
    with TickerProviderStateMixin, GameAnimationsMixin<CommRelayGame> {

  CommRelayPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // For Caesar cipher: player adjusts shift with a slider
  int _currentShift = 0;
  // For Atbash/keyword: player types the decoded message
  final TextEditingController _answerController = TextEditingController();
  int _attempts = 0;
  int _maxAttempts = 5;

  // Decoded preview (used by Atbash/keyword modes)

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
    _answerController.dispose();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    // Scale max attempts: grade 1 level 1 = 5 tries, grade 4 level 20 = 1 try
    final grade = currentDifficulty!.grade.clamp(1, 4);
    final level = widget.level.clamp(1, 20);
    _maxAttempts = (6 - grade - (level - 1) ~/ 5).clamp(1, 5);

    setState(() {
      _isGenerating = true;
      _currentShift = 0;
      _answerController.clear();
      _attempts = 0;
      successController.reset();
    });

    final locale = Localizations.localeOf(context);
    final isGerman = locale.languageCode == 'de';

    final generated = CommRelayPuzzle.generate(
      grade: currentDifficulty!.grade,
      level: widget.level,
      isGerman: isGerman,
    );

    if (mounted) {
      setState(() {
        puzzle = generated;
        _isGenerating = false;
      });
    }
  }

  /// Show every Nth letter of decoded text, rest as dots.
  /// Grade 1: every letter. Grade 2: every 2nd. Grade 3: every 3rd. Grade 4: only 1st.
  String _partialDecode() {
    final decoded = CommRelayPuzzle.decryptCaesar(puzzle!.cipherText, _currentShift);
    final grade = currentDifficulty?.grade ?? 1;
    final level = currentDifficulty?.level ?? 1;

    // How many letters to reveal: scales down with grade + level
    int revealEvery;
    if (grade <= 1) {
      revealEvery = math.max(1, 2 - (level <= 3 ? 0 : 0)); // every 2nd, or every letter at very start
      if (level <= 2) revealEvery = 1; // show all at very beginning
    } else if (grade <= 2) {
      revealEvery = 3; // every 3rd letter
    } else if (grade <= 3) {
      revealEvery = 4 + (level > 5 ? 1 : 0); // every 4th-5th
    } else {
      revealEvery = decoded.length; // only first letter
    }

    final buf = StringBuffer();
    for (int i = 0; i < decoded.length; i++) {
      if (decoded[i] == ' ') {
        buf.write(' ');
      } else if (i == 0 || i % revealEvery == 0) {
        buf.write(decoded[i]);
      } else {
        buf.write('\u2022'); // bullet dot
      }
    }
    return buf.toString();
  }

  void _checkCaesarAnswer() {
    if (puzzle == null) return;
    _attempts++;

    setState(() {});

    if (puzzle!.checkShift(_currentShift)) {
      _handleWin();
    } else if (_attempts >= _maxAttempts) {
      _handleLoss();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${S.of(context)!.commRelayLoseDesc} (${_maxAttempts - _attempts} left)',
                ),
              ),
            ],
          ),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _checkTextAnswer() {
    if (puzzle == null) return;
    _attempts++;

    if (puzzle!.checkAnswer(_answerController.text)) {
      _handleWin();
    } else if (_attempts >= _maxAttempts) {
      _handleLoss();
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(S.of(context)!.commRelayLoseDesc)),
            ],
          ),
          backgroundColor: SpaceTheme.rocketRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int attemptBonus = (_maxAttempts - _attempts) * 50;
    int totalScore = baseScore + levelBonus + attemptBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'comm_relay',
      difficulty: widget.level,
      score: totalScore,
    ));

    successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'comm_relay',
      difficulty: widget.level,
    ));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildLoseDialog(),
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
                title: s.commRelayTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.commRelayInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          _buildCipherDisplay(),
          const SizedBox(height: 16),
          if (puzzle!.hintLetters.isNotEmpty) _buildHints(),
          const SizedBox(height: 16),
          if (puzzle!.cipherType == CipherType.caesar)
            _buildCaesarControls()
          else
            _buildTextInput(),
          const SizedBox(height: 16),
          _buildAttemptsIndicator(),
        ],
      ),
    );
  }

  Widget _buildCipherDisplay() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SpaceTheme.starYellow
                  .withValues(alpha: glowAnimation.value * 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: SpaceTheme.nebulaPurple
                    .withValues(alpha: glowAnimation.value * 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'ENCRYPTED SIGNAL',
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                puzzle!.cipherText,
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: 18,
                  letterSpacing: 3,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              // Show decoded text LIVE as slider changes (for Caesar cipher)
              if (puzzle!.cipherType == CipherType.caesar) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Text(
                  'DECODED',
                  style: SpaceTheme.bodyStyle.copyWith(
                    color: SpaceTheme.alienGreen,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _partialDecode(),
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 22,
                    letterSpacing: 3,
                    color: SpaceTheme.alienGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHints() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            'HINT LETTERS',
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 11,
              color: SpaceTheme.starYellow,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: puzzle!.hintLetters.entries.map((entry) {
              return RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: entry.key,
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    TextSpan(
                      text: ' -> ',
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: SpaceTheme.starYellow,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: entry.value,
                      style: SpaceTheme.headlineStyle.copyWith(
                        color: SpaceTheme.alienGreen,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaesarControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            'SHIFT: ${_currentShift > 0 ? '+' : ''}$_currentShift',
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _currentShift.toDouble(),
            min: -13,
            max: 13,
            divisions: 26,
            activeColor: SpaceTheme.starYellow,
            inactiveColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
            label: _currentShift.toString(),
            onChanged: (value) {
              setState(() {
                _currentShift = value.round();
              });
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkCaesarAnswer,
            style: SpaceTheme.primaryButtonStyle,
            child: Text('DECODE  (${_maxAttempts - _attempts} left)'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _answerController,
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: 18,
              letterSpacing: 2,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'TYPE DECODED MESSAGE...',
              hintStyle: SpaceTheme.bodyStyle.copyWith(
                color: Colors.white30,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SpaceTheme.nebulaPurple),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: SpaceTheme.starYellow, width: 2),
              ),
              filled: true,
              fillColor: SpaceTheme.deepSpace.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _checkTextAnswer,
            style: SpaceTheme.primaryButtonStyle,
            child: const Text('DECODE'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxAttempts, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            i < _attempts ? Icons.signal_wifi_off : Icons.signal_wifi_4_bar,
            color: i < _attempts
                ? SpaceTheme.rocketRed
                : SpaceTheme.alienGreen,
            size: 24,
          ),
        );
      }),
    );
  }

  Widget _buildWinDialog(int bonusScore) {
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
                  const Icon(Icons.satellite_alt,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.commRelayWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.commRelayWinDesc(bonusScore),
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
            const Icon(Icons.signal_wifi_off,
                size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(s.commRelayLoseTitle,
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.commRelayLoseDesc,
                style: SpaceTheme.bodyStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Answer: ${puzzle!.plainText}',
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.starYellow,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
