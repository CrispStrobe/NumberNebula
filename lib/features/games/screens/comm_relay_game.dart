import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
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
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<CommRelayGame>,
        PuzzleSessionMixin<CommRelayGame> {
  bool _sessionReady = false;
  int _roundEpoch = 0;
  bool _roundFinished = false;
  final Set<TextEditingController> _retiredAnswerControllers = {};

  bool _canInteract(int epoch) =>
      mounted &&
      _sessionReady &&
      epoch == _roundEpoch &&
      !_isGenerating &&
      !_roundFinished &&
      puzzle != null &&
      _attempts < _maxAttempts;

  void _resetRoundEffects() {
    _roundEpoch++;
    cancelOneShotMotion(successController);
    successController.reset();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  void _replaceAnswerController(String text) {
    final old = _answerController;
    _answerController = TextEditingController(text: text);
    _retiredAnswerControllers.add(old);
    // Let the previous EditableText detach before disposing its controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_retiredAnswerControllers.remove(old)) old.dispose();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @override
  String get sessionGameKey => 'comm_relay';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _roundFinished) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      '_currentShift': _currentShift,
      '_attempts': _attempts,
      '_maxAttempts': _maxAttempts,
      '_text': _answerController.text
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle = (state["puzzle"] == null
        ? null
        : CommRelayPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    _currentShift = (state["_currentShift"] as int).clamp(-13, 13);
    _attempts = state["_attempts"] as int;
    _maxAttempts = state["_maxAttempts"] as int;
    _replaceAnswerController(state['_text'] as String);
    _isGenerating = false;
    // Legacy snapshots may include the final spent attempt; never reopen it.
    _roundFinished = _attempts >= _maxAttempts;
    if (_roundFinished) {
      finishPuzzleSession();
      final epoch = _roundEpoch;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showLossDialog(epoch));
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

  CommRelayPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // For Caesar cipher: player adjusts shift with a slider
  int _currentShift = 0;
  // For Atbash/keyword: player types the decoded message
  TextEditingController _answerController = TextEditingController();
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
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level,
            gradeOverride: widget.grade);
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _roundEpoch++;
    cancelOneShotMotion(successController);
    _answerController.dispose();
    for (final controller in _retiredAnswerControllers) {
      controller.dispose();
    }
    _retiredAnswerControllers.clear();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  void _generatePuzzle() {
    _resetRoundEffects();
    beginPuzzleSession();
    if (currentDifficulty == null) return;

    // Scale max attempts: grade 1 level 1 = 5 tries, grade 4 level 20 = 1 try
    final grade = currentDifficulty!.grade.clamp(1, 4);
    final level = widget.level.clamp(1, 20);
    _maxAttempts = (6 - grade - (level - 1) ~/ 5).clamp(1, 5);

    setState(() {
      _isGenerating = true;
      _currentShift = 0;
      _replaceAnswerController('');
      _attempts = 0;
      _roundFinished = false;
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
  /// Always keeps at least 1-2 letters hidden so the slider alone never
  /// fully solves the puzzle — the player must still think.
  String _partialDecode() {
    final decoded =
        CommRelayPuzzle.decryptCaesar(puzzle!.cipherText, _currentShift);
    final grade = currentDifficulty?.grade ?? 1;
    final level = currentDifficulty?.level ?? 1;

    // revealEvery: lower = more letters shown. Scales with grade + level.
    int revealEvery;
    if (grade <= 1) {
      // Level 1: every 3rd letter (not trivially solvable).
      // Higher levels: every 2nd letter (more generous).
      revealEvery = level <= 2 ? 3 : 2;
    } else if (grade <= 2) {
      revealEvery = 2; // every 2nd letter — generous for sentences
    } else if (grade <= 3) {
      revealEvery = 3; // every 3rd
    } else {
      revealEvery = 4 + (level > 5 ? 1 : 0); // every 4th-5th
    }

    // Count non-space characters to enforce minimum hidden count.
    final letterCount = decoded.split('').where((c) => c != ' ').length;
    // Ensure at least 2 letters stay hidden (or 1 if very short word).
    final minHidden = letterCount <= 3 ? 1 : 2;

    final buf = StringBuffer();
    int revealed = 0;
    final maxRevealed = letterCount - minHidden;
    for (int i = 0; i < decoded.length; i++) {
      if (decoded[i] == ' ') {
        buf.write(' ');
      } else if ((i == 0 || i % revealEvery == 0) && revealed < maxRevealed) {
        buf.write(decoded[i]);
        revealed++;
      } else {
        buf.write('\u2022'); // bullet dot
      }
    }
    return buf.toString();
  }

  void _checkCaesarAnswer(int epoch) {
    if (!_canInteract(epoch) || puzzle!.cipherType != CipherType.caesar) return;
    setState(() => _attempts++);

    if (puzzle!.checkShift(_currentShift)) {
      _handleWin();
    } else if (_attempts >= _maxAttempts) {
      _handleLoss();
    } else {
      AppHaptics.heavyImpact();
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

  void _checkTextAnswer(int epoch) {
    if (!_canInteract(epoch) || puzzle!.cipherType == CipherType.caesar) return;
    setState(() => _attempts++);

    if (puzzle!.checkAnswer(_answerController.text)) {
      _handleWin();
    } else if (_attempts >= _maxAttempts) {
      _handleLoss();
    } else {
      AppHaptics.heavyImpact();
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
    if (!mounted ||
        !_sessionReady ||
        _isGenerating ||
        _roundFinished ||
        puzzle == null) {
      return;
    }
    _resetRoundEffects();
    setState(() => _roundFinished = true);
    final epoch = _roundEpoch;
    AppHaptics.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int attemptBonus = (_maxAttempts - _attempts) * 50;
    int totalScore = baseScore + levelBonus + attemptBonus;

    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'comm_relay',
          difficulty: widget.level,
          score: totalScore,
          performance: Perf.fromAttempts(_attempts, _maxAttempts),
        ));

    playOneShotMotion(successController, () {});

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _buildWinDialog(totalScore, epoch, dialogContext),
      );
    }
  }

  void _handleLoss() {
    if (!mounted ||
        !_sessionReady ||
        _isGenerating ||
        _roundFinished ||
        puzzle == null) {
      return;
    }
    _resetRoundEffects();
    setState(() => _roundFinished = true);
    final epoch = _roundEpoch;
    AppHaptics.heavyImpact();
    finishPuzzleSession();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'comm_relay',
          difficulty: widget.level,
        ));

    _showLossDialog(epoch);
  }

  void _showLossDialog(int epoch) {
    if (!mounted ||
        !_sessionReady ||
        epoch != _roundEpoch ||
        !_roundFinished ||
        puzzle == null) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildLoseDialog(epoch, dialogContext),
    );
  }

  bool _canUseResultDialog(int epoch, BuildContext dialogContext) =>
      mounted &&
      epoch == _roundEpoch &&
      _roundFinished &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = S.of(context)!;
    final epoch = _roundEpoch;

    if (puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          gameKey: 'comm_relay',
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
        gameKey: 'comm_relay',
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: s.commRelayTitle,
                level: widget.level,
                onBack: () {
                  if (mounted &&
                      _sessionReady &&
                      epoch == _roundEpoch &&
                      !_isGenerating) {
                    Navigator.of(context).pop();
                  }
                },
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
                S.of(context)!.commRelayEncryptedSignal,
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
                  S.of(context)!.commRelayDecoded,
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
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.commRelayHintLetters,
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
    final epoch = _roundEpoch;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.commRelayShift(
                '${_currentShift > 0 ? '+' : ''}$_currentShift'),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          _buildCipherWheel(),
          const SizedBox(height: 8),
          Slider(
            key: ValueKey('comm-relay-shift-$epoch'),
            value: _currentShift.toDouble(),
            min: -13,
            max: 13,
            divisions: 26,
            activeColor: SpaceTheme.starYellow,
            inactiveColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
            label: _currentShift.toString(),
            onChanged: !_canInteract(epoch)
                ? null
                : (value) {
                    if (!_canInteract(epoch) ||
                        puzzle!.cipherType != CipherType.caesar ||
                        !value.isFinite ||
                        value < -13 ||
                        value > 13) {
                      return;
                    }
                    setState(() => _currentShift = value.round());
                  },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                _canInteract(epoch) ? () => _checkCaesarAnswer(epoch) : null,
            style: SpaceTheme.primaryButtonStyle,
            child: Text(
                S.of(context)!.commRelayDecodeBtn(_maxAttempts - _attempts)),
          ),
        ],
      ),
    );
  }

  /// A Caesar cipher wheel: a static A–Z code alphabet is always shown, and on
  /// the lower levels a second "decoded" alphabet is shown directly beneath it
  /// that shifts together with the slider — each column reveals what that code
  /// letter decodes to at the current shift, so kids can read the mapping off
  /// directly. On higher levels the decoder row is hidden so the shift must be
  /// worked out mentally.
  Widget _buildCipherWheel() {
    final grade = currentDifficulty?.grade ?? 1;
    final level = currentDifficulty?.level ?? 1;
    // Show the moving decoder aid only on the easier levels.
    final showDecoder = grade <= 1 || (grade == 2 && level <= 3);

    final codeLetters =
        List<String>.generate(26, (i) => String.fromCharCode(65 + i));

    Widget cellBox(String ch, {required bool decoded}) {
      return Container(
        width: 13,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: decoded
              ? SpaceTheme.starYellow.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          ch,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: decoded ? SpaceTheme.starYellow : SpaceTheme.moonSilver,
          ),
        ),
      );
    }

    Widget rowLabel(String text, Color color) => SizedBox(
          width: 44,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 8,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        );

    final codeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final c in codeLetters) cellBox(c, decoded: false)],
    );

    final decoderRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in codeLetters)
          cellBox(CommRelayPuzzle.decryptCaesar(c, _currentShift),
              decoded: true),
      ],
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              rowLabel(S.of(context)!.commRelayEncryptedSignal,
                  SpaceTheme.moonSilver),
              const SizedBox(width: 4),
              codeRow,
            ],
          ),
          if (showDecoder) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                rowLabel(
                    S.of(context)!.commRelayDecoded, SpaceTheme.starYellow),
                const SizedBox(width: 4),
                decoderRow,
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    final epoch = _roundEpoch;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            key: ValueKey('comm-relay-answer-$epoch'),
            enabled: _canInteract(epoch),
            onChanged: (_) {
              if (!_canInteract(epoch) ||
                  puzzle!.cipherType == CipherType.caesar) {
                return;
              }
              // The controller already holds the edit; schedule its checkpoint.
              setState(() {});
            },
            controller: _answerController,
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: 18,
              letterSpacing: 2,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: S.of(context)!.commRelayTypeHint,
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
            onPressed:
                _canInteract(epoch) ? () => _checkTextAnswer(epoch) : null,
            style: SpaceTheme.primaryButtonStyle,
            child: Text(S.of(context)!.commRelayDecode),
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
            color: i < _attempts ? SpaceTheme.rocketRed : SpaceTheme.alienGreen,
            size: 24,
          ),
        );
      }),
    );
  }

  Widget _buildWinDialog(
      int bonusScore, int epoch, BuildContext dialogContext) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: successAnimation.value,
          child: ScrollableRoundDialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RoundSummary(gameKey: 'comm_relay'),
                  const Icon(Icons.satellite_alt,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.commRelayWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.commRelayWinDesc(bonusScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseResultDialog(epoch, dialogContext)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_canUseResultDialog(epoch, dialogContext)) {
                            return;
                          }
                          Navigator.of(dialogContext).pop();
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

  Widget _buildLoseDialog(int epoch, BuildContext dialogContext) {
    final s = S.of(context)!;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundSummary(gameKey: 'comm_relay'),
            const Icon(Icons.signal_wifi_off,
                size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(s.commRelayLoseTitle,
                style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(s.commRelayLoseDesc,
                style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              S.of(context)!.commRelayAnswer(puzzle!.plainText),
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
                  autofocus: true,
                  onPressed: () {
                    if (!_canUseResultDialog(epoch, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.playAgain),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_canUseResultDialog(epoch, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
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
