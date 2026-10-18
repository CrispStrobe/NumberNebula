import '../services/generation_configs.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import '../mixins/puzzle_session_mixin.dart';
import 'package:flutter/material.dart';
import '../widgets/round_summary.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../mixins/game_animations_mixin.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/hive_station_logic.dart';
import 'package:flutter/foundation.dart';

class HiveStationGame extends StatefulWidget {
  final int grade;
  final int level;
  const HiveStationGame({super.key, required this.grade, required this.level});

  @override
  State<HiveStationGame> createState() => _HiveStationGameState();
}

class _HiveStationGameState extends State<HiveStationGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<HiveStationGame>,
        PuzzleSessionMixin<HiveStationGame> {
  bool _sessionReady = false;
  @override
  String get sessionGameKey => 'hive_station';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;

  Object _round = Object();
  bool _won = false;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_isGenerating &&
      !_won &&
      puzzle != null;

  void _resetRoundEffects() {
    _round = Object();
    cancelOneShotMotion(successController);
    _clearFeedback();
  }

  void _clearFeedback() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _won &&
      dialogContext.mounted &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateDecorativeMotion([glowController], reduced);
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  @visibleForTesting
  Object get testRound => _round;
  @visibleForTesting
  void rebuildForTesting() => setState(() {});
  @visibleForTesting
  void toggleForTesting(HexCoord coord, Object round) =>
      _toggleCell(coord, round);

  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _won || puzzle == null) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      'userMarked': userMarked.map((v0) => v0.toJson()).toList(),
      '_attemptsLeft': _attemptsLeft
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRoundEffects();
    puzzle = (state["puzzle"] == null
        ? null
        : HiveStationPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    userMarked = (state["userMarked"] as List)
        .map((v0) => HexCoord.fromJson(Map<String, dynamic>.from(v0 as Map)))
        .toSet();
    _attemptsLeft = state["_attemptsLeft"] as int;
    _isGenerating = false;
    _gameOver = false;
    _won = false;
    if (_attemptsLeft <= 0) {
      _gameOver = true;
      _won = true;
      finishPuzzleSession();
      final round = _round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(round, _round) && _won) _showLossDialog(round);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    if (!await restorePuzzleSession() && mounted) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

  HiveStationPuzzle? puzzle;
  Set<HexCoord> userMarked = {};
  bool _isGenerating = true;
  DifficultyConfig? currentDifficulty;
  int _attemptsLeft = 3;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

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
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  // ─── Difficulty scaling ─────────────────────────────────────────────
  //
  // Grade gates the puzzle *type* (grid size, mechanics):
  //   Grade 1: radius 2 (19 cells), generous hints, 3 attempts
  //   Grade 2: radius 2→3, fewer hints, 3 attempts
  //   Grade 3: radius 3 (37 cells), sparse hints, 2 attempts
  //   Grade 4: radius 3→4, very sparse hints, 2 attempts
  //
  // Level tunes parameters within each grade:
  //   - Hint fraction decreases (more deduction needed)
  //   - Energy fraction increases slightly (more mines to find)
  //   - Attempts stay fixed per grade (mechanical gate)

  int _getRadius() => HiveStationGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getRadius();

  double _getEnergyFraction() => HiveStationGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getEnergyFraction();

  double _getHintFraction() => HiveStationGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getHintFraction();

  int _getMaxAttempts() => HiveStationGenerationConfig(
          currentDifficulty?.grade ?? widget.grade,
          currentDifficulty?.level ?? widget.level)
      .getMaxAttempts();

  Future<void> _generatePuzzle() async {
    _resetRoundEffects();
    final round = _round;
    beginPuzzleSession();
    setState(() {
      _isGenerating = true;
      userMarked.clear();
      successController.reset();
      _attemptsLeft = _getMaxAttempts();
      _gameOver = false;
      _won = false;
    });

    try {
      final generator = HiveStationGenerator();
      final p = await generator.generate(
        radius: _getRadius(),
        energyFraction: _getEnergyFraction(),
        hintFraction: _getHintFraction(),
      );

      if (mounted && identical(round, _round)) {
        setState(() {
          puzzle = p;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HiveStation] Error generating puzzle: $e');
    }
  }

  void _toggleCell(HexCoord coord, [Object? round]) {
    final r = round ?? _round;
    if (!_canInteract(r) || !puzzle!.allCells.contains(coord)) return;
    // Don't toggle cells that show a hint
    if (puzzle!.revealedHints.contains(coord)) return;

    setState(() {
      if (userMarked.contains(coord)) {
        userMarked.remove(coord);
      } else {
        userMarked.add(coord);
      }
    });

    AppHaptics.selectionClick();
  }

  void _checkSolution([Object? round]) {
    final r = round ?? _round;
    if (!_canInteract(r)) return;
    if (_gameOver || _won) return;
    if (puzzle!.validateSolution(userMarked)) {
      _handleWin(r);
    } else {
      setState(() {
        _attemptsLeft--;
        if (_attemptsLeft <= 0) {
          _gameOver = true;
          _handleFinalLoss(r);
        } else {
          _handleWrongAttempt(r);
        }
      });
    }
  }

  void _handleWrongAttempt(Object round) {
    if (!mounted || !identical(round, _round) || _won) return;
    AppHaptics.heavyImpact();
    _clearFeedback();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child:
                  Text(S.of(context)!.hiveStationWrongAttempt(_attemptsLeft)),
            ),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleFinalLoss(Object round) {
    if (_won) return;
    if (!identical(round, _round)) return;
    _won = true;
    _clearFeedback();
    AppHaptics.heavyImpact();
    finishPuzzleSession();
    if (mounted) {
      context.read<GameProvider>().reportOutcome(GameOutcome.loss(
            skillLevel: widget.grade,
            gameType: 'hive_station',
            difficulty: widget.level,
          ));
    }
    _showLossDialog(round);
  }

  void _showLossDialog(Object round) {
    if (!mounted || !identical(round, _round) || !_won || puzzle == null)
      return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildLossDialog(round, dialogContext),
    );
  }

  void _handleWin(Object round) {
    if (_won) return;
    if (!identical(round, _round)) return;
    if (!mounted) return;
    // Validate still correct at call time
    if (puzzle == null || !puzzle!.validateSolution(userMarked)) return;
    _won = true;
    _gameOver = true;
    _clearFeedback();
    AppHaptics.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int attemptBonus = _attemptsLeft * 30;
    int totalScore = baseScore + levelBonus + attemptBonus;

    finishPuzzleSession();

    if (mounted) {
      context.read<GameProvider>().reportOutcome(GameOutcome.win(
            skillLevel: widget.grade,
            gameType: 'hive_station',
            difficulty: widget.level,
            score: totalScore,
            performance: Perf.fromAttempts(
                _getMaxAttempts() - _attemptsLeft + 1, _getMaxAttempts()),
          ));
    }

    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int totalScore, Object round) {
    if (!mounted || !identical(round, _round) || !_won || puzzle == null)
      return;
    playOneShotMotion(successController, () {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _buildWinDialog(totalScore, round, dialogContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShort = constraints.maxHeight < 500;
              final isWide = constraints.maxWidth > 700;
              return Column(
                children: [
                  GameUI(
                    key: ValueKey(('hive-header', _round)),
                    title: s.hiveStationTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: isShort ? 2 : 4),
                    child: Text(
                      s.hiveStationInstructions,
                      style: SpaceTheme.bodyStyle
                          .copyWith(fontSize: isShort ? 12 : 14),
                      textAlign: TextAlign.center,
                      maxLines: isShort ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isWide && !isShort)
                    Expanded(child: _buildWideContent(isShort))
                  else
                    Expanded(child: _buildCompactContent(isShort)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideContent(bool isShort) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _buildHexGrid()),
          const SizedBox(width: 16),
          Flexible(child: _buildCheckButton()),
        ],
      ),
    );
  }

  Widget _buildCompactContent(bool isShort) {
    // Short viewports need scrolling so the check button stays reachable
    if (isShort) {
      return SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              child: _buildHexGrid(),
            ),
            _buildCheckButton(),
            const SizedBox(height: 8),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(child: _buildHexGrid()),
        _buildCheckButton(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHexGrid() {
    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.starYellow
                      .withValues(alpha: 0.08 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.starYellow
                    .withValues(alpha: glowAnimation.value * 0.5),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableSize =
                    math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
                return SizedBox(
                  width: availableSize,
                  height: availableSize,
                  child: _buildHexCells(availableSize),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHexCells(double areaSize) {
    final radius = puzzle!.radius;
    final hexSize = areaSize / (2 * radius + 2.5);
    final center = Offset(areaSize / 2, areaSize / 2);

    final cells = <Widget>[];

    for (final coord in puzzle!.allCells) {
      final pixelPos = _hexToPixel(coord, hexSize, center);
      final isRevealed = puzzle!.revealedHints.contains(coord);
      final isMarked = userMarked.contains(coord);
      final hint = puzzle!.numberHints[coord];
      final round = _round;

      cells.add(Positioned(
        left: pixelPos.dx - hexSize * 0.8,
        top: pixelPos.dy - hexSize * 0.8,
        child: GestureDetector(
          key: ValueKey(('hive-hex', round, coord.q, coord.r)),
          behavior: HitTestBehavior.opaque,
          onTap: () => _toggleCell(coord, round),
          child: _buildHexCell(
            hexSize: hexSize * 1.6,
            isRevealed: isRevealed,
            isMarked: isMarked,
            hint: isRevealed ? hint : null,
          ),
        ),
      ));
    }

    return Stack(children: cells);
  }

  Offset _hexToPixel(HexCoord coord, double hexSize, Offset center) {
    final x = hexSize * (math.sqrt(3) * coord.q + math.sqrt(3) / 2 * coord.r);
    final y = hexSize * (1.5 * coord.r);
    return Offset(center.dx + x, center.dy + y);
  }

  Widget _buildHexCell({
    required double hexSize,
    required bool isRevealed,
    required bool isMarked,
    int? hint,
  }) {
    Color bgColor;
    Color borderColor;
    if (isMarked) {
      bgColor = SpaceTheme.starYellow.withValues(alpha: 0.6);
      borderColor = SpaceTheme.starYellow;
    } else if (isRevealed) {
      bgColor = const Color(0xFF1E2A4A); // slightly lighter than deep space
      borderColor = const Color(0xFF4A5A8A); // visible light blue border
    } else {
      bgColor = const Color(0xFF2A1A3A); // dark purple, tappable cells
      borderColor =
          const Color(0xFF6B48FF).withValues(alpha: 0.6); // brighter purple
    }

    return SizedBox(
      width: hexSize,
      height: hexSize,
      child: CustomPaint(
        painter: _HexCellPainter(
          fillColor: bgColor,
          borderColor: borderColor,
          glowColor:
              isMarked ? SpaceTheme.starYellow.withValues(alpha: 0.4) : null,
        ),
        child: Center(
          child: hint != null
              ? Text(
                  hint.toString(),
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: hexSize * 0.35,
                    color: Colors.white,
                  ),
                )
              : isMarked
                  ? Icon(Icons.flash_on,
                      color: Colors.white, size: hexSize * 0.4)
                  : null,
        ),
      ),
    );
  }

  Widget _buildCheckButton() {
    final s = S.of(context)!;

    // Attempts indicator color
    final attColor = _attemptsLeft <= 1
        ? SpaceTheme.rocketRed
        : _attemptsLeft <= 2
            ? SpaceTheme.planetOrange
            : SpaceTheme.alienGreen;

    final round = _round;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: OverflowBar(
        alignment: MainAxisAlignment.center,
        overflowAlignment: OverflowBarAlignment.center,
        spacing: 12,
        overflowSpacing: 8,
        children: [
          // Marked / total
          Text(
            '${userMarked.length} / ${puzzle!.energyCells.length}',
            style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow),
          ),
          // Check button
          ElevatedButton.icon(
            key: ValueKey(('hive-check', round)),
            onPressed: !_gameOver &&
                    !_won &&
                    userMarked.length == puzzle!.energyCells.length
                ? () => _checkSolution(round)
                : null,
            icon: const Icon(Icons.check),
            label: Text(s.correct.replaceAll('!', '')),
            style: SpaceTheme.primaryButtonStyle,
          ),
          // Attempts remaining
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: attColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: attColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$_attemptsLeft',
                  style: SpaceTheme.titleStyle.copyWith(
                    fontSize: 14,
                    color: attColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossDialog(Object round, BuildContext dialogContext) {
    final s = S.of(context)!;
    return ScrollableRoundDialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundSummary(gameKey: 'hive_station'),
            const Icon(Icons.hexagon_outlined,
                size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.hiveStationLoseTitle,
              style: SpaceTheme.headlineStyle
                  .copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.hiveStationLoseDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              overflowAlignment: OverflowBarAlignment.center,
              spacing: 16,
              overflowSpacing: 12,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    if (!_canUseDialog(round, dialogContext)) return;
                    Navigator.of(dialogContext).pop();
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.tryAgain),
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

  Widget _buildWinDialog(int score, Object round, BuildContext dialogContext) {
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
                  RoundSummary(gameKey: 'hive_station'),
                  const Icon(Icons.hexagon,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.hiveStationWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.hiveStationWinDesc(score),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceEvenly,
                    overflowAlignment: OverflowBarAlignment.center,
                    spacing: 16,
                    overflowSpacing: 12,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () {
                          if (!_canUseDialog(round, dialogContext)) return;
                          Navigator.of(dialogContext).pop();
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

/// Draws a flat-top hexagonal cell with fill, border, and optional glow.
class _HexCellPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color? glowColor;

  _HexCellPainter({
    required this.fillColor,
    required this.borderColor,
    this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.92; // slight inset for spacing

    // Flat-top hexagon: vertices at 0, 60, 120, 180, 240, 300 degrees
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180; // -30 for flat-top
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Optional glow shadow
    if (glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
      );
    }

    // Fill
    canvas.drawPath(path, Paint()..color = fillColor);

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HexCellPainter old) =>
      fillColor != old.fillColor ||
      borderColor != old.borderColor ||
      glowColor != old.glowColor;
}
