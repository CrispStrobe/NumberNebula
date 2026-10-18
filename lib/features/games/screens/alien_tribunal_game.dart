import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import '../mixins/game_animations_mixin.dart';

import '../../../core/services/debug_provider.dart';
import '../../../core/services/puzzle_evaluation_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/alien_tribunal_logic.dart';

class AlienTribunalGame extends StatefulWidget {
  final int grade;
  final int level;
  const AlienTribunalGame(
      {super.key, required this.grade, required this.level});

  @override
  State<AlienTribunalGame> createState() => _AlienTribunalGameState();
}

class _AlienTribunalGameState extends State<AlienTribunalGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<AlienTribunalGame>,
        PuzzleSessionMixin<AlienTribunalGame> {
  bool _sessionReady = false;

  Object _round = Object();
  VoidCallback _backForRound() {
    final round = _round;
    return () {
      if (mounted &&
          identical(round, _round) &&
          !_isGenerating &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    };
  }

  bool _won = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      !_gameOver &&
      puzzle != null;

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    successController.reset();
    _clearFeedback();
  }

  void _clearFeedback() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @visibleForTesting
  Object get testRound => _round;

  @visibleForTesting
  void rebuildForTesting() => setState(() {});

  @visibleForTesting
  void toggleForTesting(int index, Object round) =>
      _toggleAssignment(index, round);

  @visibleForTesting
  Future<void> generateForTesting() => _generatePuzzle();

  @override
  String get sessionGameKey => 'alien_tribunal';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won || _gameOver) {
      return null;
    }
    return {
      'puzzle': (puzzle?.toJson()),
      '_userAssignment':
          _userAssignment.entries.map((v0) => [v0.key, (v0.value)]).toList(),
      '_wrongVerdicts': _wrongVerdicts
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle = (state["puzzle"] == null
        ? null
        : AlienTribunalPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    _userAssignment = Map<int, bool?>.fromEntries(
        (state["_userAssignment"] as List).map((v0) =>
            MapEntry(v0[0] as int, (v0[1] == null ? null : v0[1] as bool))));
    _wrongVerdicts = state["_wrongVerdicts"] as int;
    _isGenerating = false;
    _gameOver = false;
    _won = false;
    // A correct assignment may have been saved before Submit was pressed.
    // Terminal rounds clear their save; restoring input must not consume a win.
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) {
      setState(() => _sessionReady = true);
    }
  }

  AlienTribunalPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // User's assignment: person index -> true (truth-teller) or false (liar) or null
  Map<int, bool?> _userAssignment = {};
  bool _gameOver = false;

  /// Wrong verdicts submitted before the correct one — the quality signal
  /// behind this round's performance grade.
  int _wrongVerdicts = 0;

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
    _round = Object();
    cancelOneShotMotion(successController);
    glowController.stop();
    successController.stop();
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  Future<void> _generatePuzzle() async {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    if (currentDifficulty == null) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _won = false;
      _wrongVerdicts = 0;
      _userAssignment = {};
      successController.reset();
    });

    final generated = await compute(AlienTribunalLogic.generate, {
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (!mounted || !identical(round, _round)) {
      return;
    }
    if (mounted) {
      setState(() {
        puzzle = generated;
        _userAssignment = {};
        _isGenerating = false;
      });
    }
  }

  void _toggleAssignment(int index, [Object? round]) {
    final currentRound = round ?? _round;
    if (!_canInteract(currentRound)) {
      return;
    }
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

  /// Build a localized statement string from the structured person data.
  String _localizedStatement(TribunalPerson person) {
    final s = S.of(context)!;
    switch (person.kind) {
      case TribunalClaimKind.single:
        final name = puzzle!.people[person.targetIndex].name;
        if (person.claimsTruthTeller) {
          switch (person.statementStyle) {
            case 0:
              return s.alienTribunalClaimTruth1(name);
            case 1:
              return s.alienTribunalClaimTruth2(name);
            default:
              return s.alienTribunalClaimTruth3(name);
          }
        }
        switch (person.statementStyle) {
          case 0:
            return s.alienTribunalClaimLiar1(name);
          case 1:
            return s.alienTribunalClaimLiar2(name);
          default:
            return s.alienTribunalClaimLiar3(name);
        }
      case TribunalClaimKind.pair:
        final first = puzzle!.people[person.targetIndex].name;
        final second = puzzle!.people[person.secondTargetIndex].name;
        if (person.pairRequiresBoth) {
          if (person.claimsTruthTeller) {
            return person.statementStyle == 0
                ? s.alienTribunalPairBothTruth1(first, second)
                : s.alienTribunalPairBothTruth2(first, second);
          }
          return person.statementStyle == 0
              ? s.alienTribunalPairBothLiar1(first, second)
              : s.alienTribunalPairBothLiar2(first, second);
        }
        if (person.claimsTruthTeller) {
          return person.statementStyle == 0
              ? s.alienTribunalPairAnyTruth1(first, second)
              : s.alienTribunalPairAnyTruth2(first, second);
        }
        return person.statementStyle == 0
            ? s.alienTribunalPairAnyLiar1(first, second)
            : s.alienTribunalPairAnyLiar2(first, second);
      case TribunalClaimKind.count:
        if (person.countsTruthTellers) {
          if (person.countValue == 0) {
            return s.alienTribunalCountTruthNone;
          }
          if (person.countValue == 1) {
            return s.alienTribunalCountTruthOne;
          }
          return s.alienTribunalCountTruthMany(person.countValue);
        }
        if (person.countValue == 0) {
          return s.alienTribunalCountLiarsNone;
        }
        if (person.countValue == 1) {
          return s.alienTribunalCountLiarsOne;
        }
        return s.alienTribunalCountLiarsMany(person.countValue);
    }
  }

  void _checkSolution([Object? requestedRound]) {
    if (requestedRound != null && !identical(requestedRound, _round)) {
      return;
    }
    if (!_canInteract(_round)) {
      return;
    }
    if (puzzle == null || _gameOver) {
      return;
    }

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

  /// Share of aliens the player judged correctly in the submitted verdict.
  double _correctlyJudgedFraction() {
    final p = puzzle;
    if (p == null || p.personCount == 0) {
      return 0;
    }
    int correct = 0;
    for (int i = 0; i < p.personCount; i++) {
      if (_userAssignment[i] == p.people[i].isTruthTeller) {
        correct++;
      }
    }
    return correct / p.personCount;
  }

  int _winScore() {
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int complexityBonus = puzzle!.personCount * 40;
    return baseScore + levelBonus + complexityBonus;
  }

  void _handleWin() {
    if (!_canInteract(_round)) {
      return;
    }
    final round = _round;
    if (puzzle == null) {
      return;
    }
    // Verify solution still correct for current assignment
    final userMap = _userAssignment.map((k, v) => MapEntry(k, v!));
    if (!puzzle!.checkSolution(userMap)) {
      return;
    }
    _clearFeedback();
    setState(() {
      _gameOver = true;
      _won = true;
    });
    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'alien_tribunal',
          difficulty: widget.level,
          score: _winScore(),
          performance: Perf.fromMistakes(_wrongVerdicts),
        ));

    _showWinDialog(_winScore(), round);
  }

  void _showWinDialog(int totalScore, Object round) {
    if (!mounted || !identical(round, _round) || !_won || puzzle == null) {
      return;
    }
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _buildWinDialog(totalScore, round, dialogContext),
    );
  }

  void _handleLoss() {
    if (!_canInteract(_round)) {
      return;
    }
    AppHaptics.heavyImpact();
    setState(() => _wrongVerdicts++);
    // Recoverable mistake: keep board editable and save snapshot
    // Report loss for analytics but remain playable for retry
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          skillLevel: widget.grade,
          gameType: 'alien_tribunal',
          difficulty: widget.level,
          progress: _correctlyJudgedFraction(),
        ));
    // Keep session alive for retry: finish then immediately begin new session
    finishPuzzleSession();
    beginPuzzleSession();
    savePuzzleSession();
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

  bool _canUseDialog(BuildContext dialogContext, Object round) =>
      mounted &&
      identical(round, _round) &&
      (_won || _gameOver) &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                key: ValueKey(('alien-header', _round)),
                title: s.alienTribunalTitle,
                level: widget.level,
                onBack: _backForRound(),
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
    final round = _round;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < 500;
        final content = Padding(
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
                  itemBuilder: (context, i) => _buildPersonCard(i, round),
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
                      key: ValueKey(('alien-submit', _round)),
                      onPressed: () => _checkSolution(round),
                      icon: const Icon(Icons.gavel, size: 24),
                      label: Text(S.of(context)!.alienTribunalSubmit,
                          style: const TextStyle(fontSize: 18)),
                      style: SpaceTheme.primaryButtonStyle,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (isShort) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: SizedBox(
                height: constraints.maxHeight,
                child: content,
              ),
            ),
          );
        }
        return content;
      },
    );
  }

  Widget _buildPersonCard(int index, Object round) {
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
      key: ValueKey(('alien-card', _round, index)),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return GestureDetector(
            key: ValueKey(('alien-tap', _round, index)),
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleAssignment(index, round),
            child: DecoratedBox(
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
                child: child!),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                      _localizedStatement(person),
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
      ),
    );
  }

  Widget _buildWinDialog(
      int totalScore, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'alien_tribunal'),
                  const Icon(Icons.gavel,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.alienTribunalWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.alienTribunalWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  if (dialogContext.read<DebugProvider>().isDebugMenuEnabled)
                    DebugPuzzleRating(
                      gameType: 'alien_tribunal',
                      puzzleId:
                          'at_g${widget.grade}_l${widget.level}_${DateTime.now().millisecondsSinceEpoch}',
                      grade: widget.grade,
                      level: widget.level,
                    ),
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(dialogContext, round)) {
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
                          if (!_canUseDialog(dialogContext, round)) {
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
}
