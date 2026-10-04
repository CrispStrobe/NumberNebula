import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'dart:math' as math;
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
import '../services/ion_chain_logic.dart';

class _IonDrag {
  final IonType bead;
  final Object round;
  const _IonDrag(this.bead, this.round);
}

class IonChainGame extends StatefulWidget {
  final int grade;
  final int level;
  const IonChainGame({super.key, required this.grade, required this.level});

  @override
  State<IonChainGame> createState() => _IonChainGameState();
}

class _IonChainGameState extends State<IonChainGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<IonChainGame>,
        PuzzleSessionMixin<IonChainGame> {
  bool _sessionReady = false;
  bool _won = false;
  Object _round = Object();

  bool _canInteract(Object round) =>
      mounted &&
      _sessionReady &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      puzzle != null;

  bool _canPlace(int slot, _IonDrag drag) =>
      _canInteract(drag.round) &&
      slot >= 0 &&
      slot < _playerChain.length &&
      slot < puzzle!.chain.length &&
      puzzle!.chain[slot] == null &&
      _playerChain[slot] == null &&
      _beadsLeftInTray().contains(drag.bead);

  void _resetRound() {
    _round = Object();
    cancelOneShotMotion(successController);
    successController.reset();
    _won = false;
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @override
  String get sessionGameKey => 'ion_chain';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      '_playerChain': _playerChain.map((v0) => (v0?.name)).toList(),
      '_ruleViolations': _ruleViolations
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRound();
    puzzle = (state["puzzle"] == null
        ? null
        : IonChainPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    _playerChain = (state["_playerChain"] as List)
        .map((v0) => (v0 == null ? null : IonType.values.byName(v0 as String)))
        .toList();
    _ruleViolations = state["_ruleViolations"] as int;
    _isGenerating = false;
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

  IonChainPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  /// Rejected bead placements — the quality signal for the performance grade.
  int _ruleViolations = 0;

  List<IonType?> _playerChain = [];

  static const _beadColors = {
    IonType.red: Color(0xFFE63946),
    IonType.blue: Color(0xFF457B9D),
    IonType.green: Color(0xFF06FFA5),
    IonType.yellow: Color(0xFFFFD700),
    IonType.purple: Color(0xFFBB86FC),
  };

  static const _beadShapes = {
    IonType.red: Icons.star,
    IonType.blue: Icons.circle,
    IonType.green: Icons.hexagon,
    IonType.yellow: Icons.diamond,
    IonType.purple: Icons.change_history,
  };

  @override
  void initState() {
    super.initState();
    initGameAnimations();

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
    disposeGameAnimations();
    super.dispose();
  }

  Future<void> _generatePuzzle() async {
    if (currentDifficulty == null) return;
    _resetRound();
    beginPuzzleSession();
    setState(() {
      _isGenerating = true;
      _playerChain = [];
      _ruleViolations = 0;
      successController.reset();
    });

    final grade = currentDifficulty!.grade;
    final level = currentDifficulty!.level;

    // Map grade/level to puzzle parameters
    int chainLength, ionTypeCount, ruleCount, blanksToRemove;
    if (grade <= 1) {
      chainLength = 5;
      ionTypeCount = 3;
      ruleCount = 1;
      blanksToRemove = 2;
    } else if (grade <= 2) {
      chainLength = 6 + (level > 5 ? 1 : 0);
      ionTypeCount = 3;
      ruleCount = 1 + (level > 5 ? 1 : 0);
      blanksToRemove = 3;
    } else {
      chainLength = 7 + (level > 5 ? 2 : 0);
      ionTypeCount = 4;
      ruleCount = 2 + (level > 8 ? 1 : 0);
      blanksToRemove = 3 + (level > 5 ? 1 : 0);
    }

    final p = IonChainPuzzle.generate(
      chainLength: chainLength,
      ionTypeCount: ionTypeCount,
      ruleCount: ruleCount,
      blanksToRemove: blanksToRemove,
    );

    if (mounted) {
      setState(() {
        puzzle = p;
        _playerChain = List<IonType?>.from(p.chain);
        _isGenerating = false;
      });
    }
  }

  /// The beads still in the tray: the puzzle's supply minus what is on the ring.
  List<IonType> _beadsLeftInTray() {
    final left = List<IonType>.from(puzzle!.availableIons);
    for (int i = 0; i < _playerChain.length; i++) {
      if (puzzle!.chain[i] == null && _playerChain[i] != null) {
        left.remove(_playerChain[i]);
      }
    }
    return left;
  }

  void _placeBeadInSlot(int slotIndex, _IonDrag drag, Object round) {
    if (!_canInteract(round) || !_canPlace(slotIndex, drag)) return;
    final bead = drag.bead;

    final testChain = List<IonType?>.from(_playerChain);
    testChain[slotIndex] = bead;

    // Check circular neighbors (bracelet: slot 0 is adjacent to last slot)
    bool valid = true;
    final prevIdx = (slotIndex - 1 + testChain.length) % testChain.length;
    final nextIdx = (slotIndex + 1) % testChain.length;

    if (testChain[prevIdx] != null) {
      for (final rule in puzzle!.rules) {
        if (!rule.check(testChain[prevIdx], bead)) {
          valid = false;
          break;
        }
      }
    }
    if (valid && testChain[nextIdx] != null) {
      for (final rule in puzzle!.rules) {
        if (!rule.check(bead, testChain[nextIdx])) {
          valid = false;
          break;
        }
      }
    }

    if (!valid) {
      _rejectPlacement(S.of(context)!.ionChainRuleViolation);
      return;
    }

    // The move breaks no rule, but it can still strand the player: with the
    // wrong bead here, some other slot ends up with nothing that fits, and the
    // ring can never be closed. Refuse those too, so every accepted move keeps
    // the puzzle winnable and the player never has to guess what went wrong.
    final remaining = _beadsLeftInTray()..remove(bead);
    if (!IonChainPuzzle.isCompletable(testChain, remaining, puzzle!.rules)) {
      _rejectPlacement(S.of(context)!.ionChainDeadEnd);
      return;
    }

    AppHaptics.lightImpact();
    setState(() {
      _playerChain[slotIndex] = bead;
    });

    if (!_playerChain.contains(null)) {
      if (IonChainPuzzle.validateChain(_playerChain, puzzle!.rules)) {
        _handleWin();
      }
    }
  }

  void _rejectPlacement(String message) {
    setState(() => _ruleViolations++);
    AppHaptics.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: SpaceTheme.rocketRed,
      duration: const Duration(seconds: 2),
    ));
  }

  void _removeBeadFromSlot(int slotIndex, Object round, IonType bead) {
    if (!_canInteract(round) ||
        slotIndex < 0 ||
        slotIndex >= _playerChain.length ||
        slotIndex >= puzzle!.chain.length) {
      return;
    }
    if (puzzle!.chain[slotIndex] != null) return;
    if (_playerChain[slotIndex] != bead) return;
    AppHaptics.lightImpact();
    setState(() {
      _playerChain[slotIndex] = null;
    });
  }

  void _handleWin() {
    if (!_canInteract(_round) ||
        _playerChain.contains(null) ||
        !IonChainPuzzle.validateChain(_playerChain, puzzle!.rules)) return;
    _won = true;
    final round = _round;
    AppHaptics.lightImpact();
    int totalScore = 100 * widget.grade + widget.level * 25;

    finishPuzzleSession();

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'ion_chain',
          difficulty: widget.level,
          score: totalScore,
          performance: Perf.fromMistakes(_ruleViolations, per: 0.15),
        ));

    successController.reset();
    playOneShotMotion(successController, () {});
    if (mounted) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _buildWinDialog(totalScore, round));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final round = _round;
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
          Text(s.loadingAdventure, style: SpaceTheme.bodyStyle)
        ],
      ))));
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                  title: s.ionChainTitle,
                  level: widget.level,
                  onBack: () {
                    if (mounted && identical(round, _round)) {
                      Navigator.of(context).pop();
                    }
                  }),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInstructions(s),
                      const SizedBox(height: 10),
                      _buildRules(),
                      const SizedBox(height: 14),
                      _buildBracelet(),
                      const SizedBox(height: 14),
                      _buildBeadTray(),
                      const SizedBox(height: 16),
                    ],
                  ),
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
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(s.ionChainInstructions,
                style: SpaceTheme.bodyStyle.copyWith(fontSize: 14))),
      ]),
    );
  }

  /// The player only ever sees a bead as a shape, never as a word, so a rule
  /// written purely as "Raute darf nicht neben Stern stehen" asks them to
  /// match vocabulary they were never taught. Each rule is therefore drawn as
  /// the two beads it talks about, side by side and struck through, with the
  /// sentence kept underneath for readers.
  String _shapeName(IonType type) {
    final s = S.of(context)!;
    switch (type) {
      case IonType.red:
        return s.ionChainShapeStar;
      case IonType.blue:
        return s.ionChainShapeCircle;
      case IonType.green:
        return s.ionChainShapeHexagon;
      case IonType.yellow:
        return s.ionChainShapeDiamond;
      case IonType.purple:
        return s.ionChainShapeTriangle;
    }
  }

  String _ruleText(IonRule rule) {
    final s = S.of(context)!;
    switch (rule.kind) {
      case IonRuleKind.noSelfPair:
        return s.ionChainRuleNoSelfPair(_shapeName(rule.a!));
      case IonRuleKind.noMixedPair:
        return s.ionChainRuleNoMixedPair(
            _shapeName(rule.a!), _shapeName(rule.b!));
      case IonRuleKind.noRepeatAtAll:
        return s.ionChainRuleNoRepeatAtAll;
    }
  }

  /// One bead drawn at rule size, in its own colour -- the same shape and
  /// colour the ring and the tray use.
  Widget _ruleBead(IonType type) {
    final color = _beadColors[type] ?? Colors.white;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(_beadShapes[type] ?? Icons.circle, color: color, size: 17),
    );
  }

  /// A bead of no particular type, for the "no two identical shapes" rule:
  /// two of these stand for "whatever shape it is, not twice in a row".
  Widget _ruleAnyBead() {
    const color = SpaceTheme.moonSilver;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: color.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: const Icon(Icons.question_mark, color: color, size: 15),
    );
  }

  /// The pair of beads a rule forbids, with a red slash between them.
  Widget _ruleDiagram(IonRule rule) {
    final (Widget left, Widget right) = switch (rule.kind) {
      IonRuleKind.noSelfPair => (_ruleBead(rule.a!), _ruleBead(rule.a!)),
      IonRuleKind.noMixedPair => (_ruleBead(rule.a!), _ruleBead(rule.b!)),
      IonRuleKind.noRepeatAtAll => (_ruleAnyBead(), _ruleAnyBead()),
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [left, const SizedBox(width: 4), right],
        ),
        // The "forbidden" slash, drawn across both beads.
        Transform.rotate(
          angle: -math.pi / 4,
          child: Container(
            width: 74,
            height: 3,
            decoration: BoxDecoration(
              color: SpaceTheme.rocketRed,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.9),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRules() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.rocketRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.ionChainRules,
              style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 14,
                  color: SpaceTheme.rocketRed,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          ...puzzle!.rules.map((rule) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Semantics(
                  label: _ruleText(rule),
                  child: Row(children: [
                    ExcludeSemantics(child: _ruleDiagram(rule)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(_ruleText(rule),
                            style: SpaceTheme.bodyStyle.copyWith(fontSize: 14)),
                      ),
                    ),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBracelet() {
    return LayoutBuilder(builder: (context, constraints) {
      final slotCount = _playerChain.length;
      // Circular layout: compute radius and bead size from available space
      final availSize = math.min(constraints.maxWidth - 24, 320.0);
      final ringRadius = availSize * 0.35;
      final slotSize =
          (2 * math.pi * ringRadius / slotCount * 0.65).clamp(36.0, 56.0);

      return AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, _) {
          return Column(children: [
            Text(S.of(context)!.ionChainRing,
                style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 14,
                    color: SpaceTheme.starYellow,
                    letterSpacing: 2)),
            const SizedBox(height: 6),
            SizedBox(
              width: ringRadius * 2 + slotSize + 16,
              height: ringRadius * 2 + slotSize + 16,
              child: CustomPaint(
                painter: _RingPainter(
                  slotCount: slotCount,
                  ringRadius: ringRadius,
                  glowValue: glowAnimation.value,
                ),
                child: Stack(
                  children: List.generate(slotCount, (i) {
                    final angle = (2 * math.pi * i / slotCount) - math.pi / 2;
                    final cx = ringRadius +
                        slotSize / 2 +
                        8 +
                        ringRadius * math.cos(angle) -
                        slotSize / 2;
                    final cy = ringRadius +
                        slotSize / 2 +
                        8 +
                        ringRadius * math.sin(angle) -
                        slotSize / 2;
                    return Positioned(
                      left: cx,
                      top: cy,
                      child: _buildSlot(i, slotSize),
                    );
                  }),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }

  Widget _buildSlot(int index, double size) {
    final round = _round;
    final isClue = puzzle!.chain[index] != null;
    final value = _playerChain[index];

    if (value == null) {
      return DragTarget<_IonDrag>(
        key: ValueKey((round, index)),
        builder: (context, candidates, _) {
          final hover = candidates.isNotEmpty;
          return AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, _) => Container(
              width: size,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hover
                    ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                    : SpaceTheme.deepSpace.withValues(alpha: 0.4),
                border: Border.all(
                    color: hover
                        ? SpaceTheme.starYellow
                        : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                    width: hover ? 2.5 : 1.5),
              ),
              child: Transform.scale(
                scale: pulseAnimation.value,
                child: Icon(Icons.add,
                    color: SpaceTheme.nebulaPurple, size: size * 0.35),
              ),
            ),
          );
        },
        onWillAcceptWithDetails: (d) =>
            _canInteract(round) && _canPlace(index, d.data),
        onAcceptWithDetails: (d) => _placeBeadInSlot(index, d.data, round),
      );
    }

    final color = _beadColors[value] ?? SpaceTheme.starYellow;
    final icon = _beadShapes[value] ?? Icons.circle;

    Widget bead = Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.35),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );

    if (!isClue) {
      bead = GestureDetector(
          onTap: () => _removeBeadFromSlot(index, round, value), child: bead);
    } else {
      bead = Stack(children: [
        bead,
        Positioned(
            bottom: 0,
            right: 0,
            child: Icon(Icons.lock, color: Colors.white30, size: size * 0.22))
      ]);
    }
    return bead;
  }

  Widget _buildBeadTray() {
    final round = _round;
    final available = <IonType, int>{};
    for (final b in puzzle!.availableIons) {
      available[b] = (available[b] ?? 0) + 1;
    }
    for (int i = 0; i < _playerChain.length; i++) {
      if (puzzle!.chain[i] == null && _playerChain[i] != null) {
        final t = _playerChain[i]!;
        available[t] = (available[t] ?? 1) - 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(S.of(context)!.ionChainAvailableBeads,
            style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 14,
                color: SpaceTheme.starYellow,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: puzzle!.ionTypes.map((type) {
            final count = available[type] ?? 0;
            final color = _beadColors[type] ?? SpaceTheme.starYellow;
            final icon = _beadShapes[type] ?? Icons.circle;

            return Draggable<_IonDrag>(
              key: ValueKey((round, type)),
              data: count > 0 ? _IonDrag(type, round) : null,
              maxSimultaneousDrags: count > 0 && _canInteract(round) ? 1 : 0,
              feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                              color: color.withValues(alpha: 0.7),
                              blurRadius: 15,
                              spreadRadius: 3)
                        ]),
                    child: Icon(icon, color: Colors.white, size: 28),
                  )),
              childWhenDragging: Opacity(
                  opacity: 0.3, child: _beadChip(type, color, icon, count)),
              child: _beadChip(type, color, icon, count),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _beadChip(IonType type, Color color, IconData icon, int count) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: count > 0 ? color.withValues(alpha: 0.25) : Colors.white10,
            border: Border.all(
                color: count > 0 ? color : Colors.white24, width: 2)),
        child: Icon(icon, color: count > 0 ? color : Colors.white24, size: 26),
      ),
      const SizedBox(height: 4),
      Text('×$count',
          style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 14, color: count > 0 ? color : Colors.white24)),
    ]);
  }

  Widget _buildWinDialog(int score, Object round) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: successAnimation,
      builder: (context, _) => Transform.scale(
        scale: successAnimation.value,
        child: ScrollableRoundDialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: SpaceTheme.cardDecoration,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              RoundSummary(gameKey: 'ion_chain'),
              const Icon(Icons.link, size: 64, color: SpaceTheme.starYellow),
              const SizedBox(height: 16),
              Text(s.ionChainWinTitle,
                  style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(s.ionChainWinDesc(score),
                  style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                      if (!mounted || !identical(round, _round) || !_won) {
                        return;
                      }
                      Navigator.of(context).pop();
                      _generatePuzzle();
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(s.playAgain)),
                ElevatedButton(
                    onPressed: () {
                      if (!mounted || !identical(round, _round) || !_won) {
                        return;
                      }
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: Text(s.backToMenu)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Draws a circular ring connecting bead positions.
class _RingPainter extends CustomPainter {
  final int slotCount;
  final double ringRadius;
  final double glowValue;

  _RingPainter(
      {required this.slotCount,
      required this.ringRadius,
      required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the ring
    final ringPaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: 0.15 + glowValue * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Glow ring
    final glowPaint = Paint()
      ..color = SpaceTheme.starYellow.withValues(alpha: glowValue * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, ringRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.glowValue != glowValue ||
      old.slotCount != slotCount ||
      old.ringRadius != ringRadius;
}
