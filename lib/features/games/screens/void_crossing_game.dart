// lib/features/games/screens/void_crossing_game.dart
//
// "Void Crossing" — a space-themed river crossing puzzle.
// Transport creatures across the void between two space stations using a
// small shuttle. Certain creatures cannot be left together unsupervised!

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../mixins/game_animations_mixin.dart';
import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../services/void_crossing_logic.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../../../shared/widgets/onboarding_overlay.dart';

class VoidCrossingGame extends StatefulWidget {
  final int grade;
  final int level;

  const VoidCrossingGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<VoidCrossingGame> createState() => _VoidCrossingGameState();
}

class _VoidCrossingGameState extends State<VoidCrossingGame>
    with TickerProviderStateMixin, GameAnimationsMixin<VoidCrossingGame> {
  late AnimationController _shuttleController;
  late Animation<double> _shuttleAnimation;
  late AnimationController _conflictFlashController;
  late Animation<double> _conflictFlashAnimation;
  late AnimationController _starFieldController;

  late int _currentLevel;
  VoidCrossingPuzzle? _puzzle;
  VoidCrossingGameState? _gameState;
  bool _isAnimating = false;
  ConflictRule? _activeConflict;
  bool _showConflictWarning = false;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    initGameAnimations(usePulse: true, useSuccess: true);

    _shuttleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shuttleAnimation = CurvedAnimation(
      parent: _shuttleController,
      curve: Curves.easeInOutCubic,
    );

    _conflictFlashController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _conflictFlashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _conflictFlashController,
        curve: Curves.easeOut,
      ),
    );

    _starFieldController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _generatePuzzle();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = S.of(context)!;
      OnboardingOverlay.maybeShow(
        context,
        gameKey: 'void_crossing',
        title: s.voidCrossingOnboardTitle,
        steps: [
          OnboardingStep(
            icon: Icons.touch_app,
            body: s.voidCrossingOnboardTap,
          ),
          OnboardingStep(
            icon: Icons.rocket_launch,
            body: s.voidCrossingOnboardLaunch,
          ),
          OnboardingStep(
            icon: Icons.warning_amber,
            body: s.voidCrossingOnboardConflict,
          ),
        ],
      );
    });
  }

  @override
  void dispose() {
    _shuttleController.dispose();
    _conflictFlashController.dispose();
    _starFieldController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    final puzzle = VoidCrossingLogic.generatePuzzle(widget.grade, _currentLevel);
    setState(() {
      _puzzle = puzzle;
      _gameState = VoidCrossingLogic.createInitialState(puzzle);
      _isAnimating = false;
      _activeConflict = null;
      _showConflictWarning = false;
      _gameOver = false;
    });
    if (kDebugMode) {
      final optimal = VoidCrossingLogic.solve(puzzle);
      debugPrint('🚀 [VoidCrossing] Puzzle: ${puzzle.entities.length} entities, '
          'boat=${puzzle.boatCapacity}, optimal=$optimal, max=${puzzle.maxMoves}');
    }
  }

  // ─── Game actions ──────────────────────────────────────────────────────

  void _tapEntity(String entityId) {
    if (_isAnimating || _gameOver) return;
    final state = _gameState!;
    final puzzle = _puzzle!;

    setState(() {
      if (state.onShuttle.contains(entityId)) {
        // Unload from shuttle back to current bank
        state.onShuttle.remove(entityId);
        state.currentBank.add(entityId);
      } else if (state.currentBank.contains(entityId)) {
        // Load onto shuttle (if capacity allows)
        if (state.onShuttle.length < puzzle.boatCapacity) {
          state.currentBank.remove(entityId);
          state.onShuttle.add(entityId);
        }
      }
      _showConflictWarning = false;
      _activeConflict = null;
    });
  }

  void _launchShuttle() {
    if (_isAnimating || _gameOver) return;
    final state = _gameState!;
    final puzzle = _puzzle!;

    // Check for conflicts on the bank being left behind (shuttle departing)
    final leftBehind = Set<String>.from(state.currentBank);
    final conflict =
        VoidCrossingLogic.findConflict(leftBehind, puzzle.conflicts);

    if (conflict != null) {
      setState(() {
        _activeConflict = conflict;
        _showConflictWarning = true;
      });
      _conflictFlashController.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      return;
    }

    // Valid move — animate shuttle crossing
    _isAnimating = true;
    HapticFeedback.mediumImpact();

    _shuttleController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        // Move entities from shuttle to destination bank
        state.farBank.addAll(state.onShuttle);
        state.onShuttle.clear();
        state.shuttleOnLeft = !state.shuttleOnLeft;
        state.movesTaken++;
        _isAnimating = false;
        _showConflictWarning = false;
        _activeConflict = null;
      });

      // Check win condition
      if (VoidCrossingLogic.isSolved(state, puzzle)) {
        _handleWin();
      } else if (state.movesTaken >= puzzle.maxMoves) {
        _handleOutOfMoves();
      }
    });
  }

  void _handleWin() {
    _gameOver = true;
    HapticFeedback.lightImpact();
    final baseScore = 100 * widget.grade;
    final levelBonus = _currentLevel * 25;
    final efficiencyBonus =
        ((_puzzle!.maxMoves - _gameState!.movesTaken) * 30).clamp(0, 300);
    final score = baseScore + levelBonus + efficiencyBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          gameType: 'void_crossing',
          difficulty: _currentLevel,
          score: score,
        ));
    successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildSuccessDialog(score),
      );
    }
  }

  void _handleOutOfMoves() {
    _gameOver = true;
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
          gameType: 'void_crossing',
          difficulty: _currentLevel,
        ));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildOutOfMovesDialog(),
      );
    }
  }

  void _resetPuzzle() {
    setState(() {
      _gameState = VoidCrossingLogic.createInitialState(_puzzle!);
      _isAnimating = false;
      _activeConflict = null;
      _showConflictWarning = false;
      _gameOver = false;
    });
  }

  // ─── Entity visuals ────────────────────────────────────────────────────

  static const _entityColors = {
    'zorblex': Color(0xFF9B59B6),
    'glimbit': Color(0xFFE67E22),
    'star_moss': Color(0xFF2ECC71),
    'kraxxon': Color(0xFF3498DB),
    'lumifae': Color(0xFFE91E63),
    'void_crab': Color(0xFFE74C3C),
    'nebula_seed': Color(0xFFFFD700),
    'pyrowyrm': Color(0xFFFF5722),
  };

  static const _entityIcons = {
    'zorblex': Icons.pest_control,
    'glimbit': Icons.bug_report,
    'star_moss': Icons.eco,
    'kraxxon': Icons.pets,
    'lumifae': Icons.flutter_dash,
    'void_crab': Icons.coronavirus,
    'nebula_seed': Icons.grain,
    'pyrowyrm': Icons.whatshot,
  };

  String _entityName(String id) {
    final s = S.of(context)!;
    switch (id) {
      case 'zorblex': return s.voidCrossingZorblex;
      case 'glimbit': return s.voidCrossingGlimbit;
      case 'star_moss': return s.voidCrossingStarMoss;
      case 'kraxxon': return s.voidCrossingKraxxon;
      case 'lumifae': return s.voidCrossingLumifae;
      case 'void_crab': return s.voidCrossingVoidCrab;
      case 'nebula_seed': return s.voidCrossingNebulaSeed;
      case 'pyrowyrm': return s.voidCrossingPyrowyrm;
      default: return id;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_puzzle == null || _gameState == null) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(S.of(context)!.calculatingCoordinates,
                    style: SpaceTheme.bodyStyle),
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
                title: S.of(context)!.voidCrossingTitle,
                level: _currentLevel,
                onBack: () => Navigator.pop(context),
              ),
              _buildMoveCounter(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 700) {
                      return _buildWideLayout(constraints);
                    }
                    return _buildTallLayout(constraints);
                  },
                ),
              ),
              _buildConflictRulesBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Move counter ──────────────────────────────────────────────────────

  Widget _buildMoveCounter() {
    final state = _gameState!;
    final puzzle = _puzzle!;
    final remaining = puzzle.maxMoves - state.movesTaken;

    Color color;
    if (remaining <= 2) {
      color = SpaceTheme.rocketRed;
    } else if (remaining <= 4) {
      color = SpaceTheme.planetOrange;
    } else {
      color = SpaceTheme.alienGreen;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rocket_launch, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${state.movesTaken} / ${puzzle.maxMoves}',
                  style: SpaceTheme.titleStyle.copyWith(
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildResetButton(),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return Semantics(
      label: S.of(context)!.tryAgain,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isAnimating ? null : _resetPuzzle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: SpaceTheme.moonSilver.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh,
                    color: SpaceTheme.moonSilver, size: 16),
                const SizedBox(width: 4),
                Text(
                  S.of(context)!.voidCrossingReset,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Layouts ───────────────────────────────────────────────────────────

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildStation(isLeft: true)),
          SizedBox(
            width: constraints.maxWidth * 0.3,
            child: _buildVoidZone(isHorizontal: true),
          ),
          Expanded(child: _buildStation(isLeft: false)),
        ],
      ),
    );
  }

  Widget _buildTallLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Expanded(flex: 3, child: _buildStation(isLeft: true)),
          SizedBox(
            height: constraints.maxHeight * 0.3,
            child: _buildVoidZone(isHorizontal: false),
          ),
          Expanded(flex: 3, child: _buildStation(isLeft: false)),
        ],
      ),
    );
  }

  // ─── Space station ─────────────────────────────────────────────────────

  Widget _buildStation({required bool isLeft}) {
    final state = _gameState!;
    final entities = isLeft ? state.leftStation : state.rightStation;
    final isActive = state.shuttleOnLeft == isLeft && !_isAnimating;
    final s = S.of(context)!;

    final stationLabel = isLeft
        ? s.voidCrossingStationAlpha
        : s.voidCrossingStationOmega;

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? SpaceTheme.alienGreen
                      .withValues(alpha: glowAnimation.value)
                  : SpaceTheme.moonSilver.withValues(alpha: 0.3),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: SpaceTheme.alienGreen.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Station header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLeft ? Icons.satellite_alt : Icons.cell_tower,
                    color: isActive
                        ? SpaceTheme.alienGreen
                        : SpaceTheme.moonSilver,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stationLabel,
                    style: SpaceTheme.titleStyle.copyWith(
                      fontSize: 13,
                      color: isActive
                          ? SpaceTheme.alienGreen
                          : SpaceTheme.moonSilver,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Entity chips
              Expanded(
                child: Center(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: entities.map((id) {
                      return _buildEntityChip(id, isActive);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntityChip(String entityId, bool tappable) {
    final color = _entityColors[entityId] ?? SpaceTheme.moonSilver;
    final icon = _entityIcons[entityId] ?? Icons.help_outline;
    final name = _entityName(entityId);

    final isConflicting = _showConflictWarning &&
        _activeConflict != null &&
        (entityId == _activeConflict!.entityA ||
            entityId == _activeConflict!.entityB);

    return Semantics(
      label: name,
      hint: tappable
          ? S.of(context)!.voidCrossingTapToLoad
          : null,
      child: GestureDetector(
        onTap: tappable ? () => _tapEntity(entityId) : null,
        child: AnimatedBuilder(
          animation: _conflictFlashAnimation,
          builder: (context, child) {
            final flashColor = isConflicting
                ? Color.lerp(
                    color, SpaceTheme.rocketRed, _conflictFlashAnimation.value)
                : color;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    flashColor!.withValues(alpha: 0.3),
                    flashColor.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isConflicting
                      ? SpaceTheme.rocketRed
                      : flashColor.withValues(alpha: tappable ? 0.8 : 0.4),
                  width: isConflicting ? 2.5 : 1.5,
                ),
                boxShadow: [
                  if (tappable)
                    BoxShadow(
                      color: flashColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: flashColor, size: 28),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 10,
                      color: flashColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Void zone (shuttle + launch) ──────────────────────────────────────

  Widget _buildVoidZone({required bool isHorizontal}) {
    final state = _gameState!;
    final puzzle = _puzzle!;
    final s = S.of(context)!;

    return AnimatedBuilder(
      animation: _starFieldController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: RadialGradient(
              colors: [
                Colors.indigo.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _VoidStarsPainter(_starFieldController.value),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Direction arrow
                _buildDirectionArrow(isHorizontal),
                const SizedBox(height: 4),
                // Shuttle
                _buildShuttle(),
                const SizedBox(height: 8),
                // Launch button
                if (!_gameOver)
                  ElevatedButton.icon(
                    onPressed: _isAnimating ? null : _launchShuttle,
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: Text(s.voidCrossingLaunch),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpaceTheme.alienGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                // Conflict warning
                if (_showConflictWarning)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            SpaceTheme.rocketRed.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SpaceTheme.rocketRed),
                      ),
                      child: Text(
                        s.voidCrossingConflictWarning,
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 11,
                          color: SpaceTheme.rocketRed,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                // Capacity indicator
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${state.onShuttle.length} / ${puzzle.boatCapacity}',
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 11,
                      color: SpaceTheme.moonSilver,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectionArrow(bool isHorizontal) {
    final state = _gameState!;
    // Shuttle on left → heading right (Alpha → Omega)
    // Shuttle on right → heading left (Omega → Alpha)
    final IconData arrowIcon;
    if (isHorizontal) {
      arrowIcon = state.shuttleOnLeft
          ? Icons.arrow_forward_rounded
          : Icons.arrow_back_rounded;
    } else {
      // Tall layout: left=top, right=bottom
      arrowIcon = state.shuttleOnLeft
          ? Icons.arrow_downward_rounded
          : Icons.arrow_upward_rounded;
    }

    final label = state.shuttleOnLeft
        ? S.of(context)!.voidCrossingStationOmega
        : S.of(context)!.voidCrossingStationAlpha;

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _isAnimating ? 0.3 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                arrowIcon,
                color: SpaceTheme.starYellow,
                size: 28 * pulseAnimation.value,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 12,
                  color: SpaceTheme.starYellow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuttle() {
    final state = _gameState!;

    return AnimatedBuilder(
      animation: _shuttleAnimation,
      builder: (context, child) {
        // During animation, shuttle slides from one side to other
        final offset = _isAnimating
            ? Offset(
                state.shuttleOnLeft
                    ? _shuttleAnimation.value * 0.3
                    : -_shuttleAnimation.value * 0.3,
                -math.sin(_shuttleAnimation.value * math.pi) * 0.15)
            : Offset.zero;

        return Transform.translate(
          offset: Offset(offset.dx * 100, offset.dy * 100),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.onShuttle.isNotEmpty
                    ? SpaceTheme.starYellow
                    : SpaceTheme.moonSilver.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                if (state.onShuttle.isNotEmpty)
                  BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flight,
                  color: state.onShuttle.isNotEmpty
                      ? SpaceTheme.starYellow
                      : SpaceTheme.moonSilver,
                  size: 24,
                ),
                if (state.onShuttle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: state.onShuttle.map((id) {
                      final canTap =
                          !_isAnimating && !_gameOver;
                      return GestureDetector(
                        onTap: canTap ? () => _tapEntity(id) : null,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: (_entityColors[id] ?? SpaceTheme.moonSilver)
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _entityColors[id] ?? SpaceTheme.moonSilver,
                            ),
                          ),
                          child: Icon(
                            _entityIcons[id] ?? Icons.help_outline,
                            color:
                                _entityColors[id] ?? SpaceTheme.moonSilver,
                            size: 20,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Conflict rules bar ────────────────────────────────────────────────

  Widget _buildConflictRulesBar() {
    final puzzle = _puzzle!;
    final s = S.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
              color: SpaceTheme.moonSilver.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.voidCrossingRules,
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: 15,
              color: SpaceTheme.starYellow,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: puzzle.conflicts.map((rule) {
              final isActive = _activeConflict == rule;
              final colorA = _entityColors[rule.entityA] ?? SpaceTheme.moonSilver;
              final colorB = _entityColors[rule.entityB] ?? SpaceTheme.moonSilver;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? SpaceTheme.rocketRed.withValues(alpha: 0.25)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? SpaceTheme.rocketRed
                        : SpaceTheme.moonSilver.withValues(alpha: 0.4),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _entityIcons[rule.entityA] ?? Icons.help_outline,
                      color: colorA,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _entityName(rule.entityA),
                      style: SpaceTheme.bodyStyle.copyWith(
                        fontSize: 13,
                        color: colorA,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.dangerous,
                          color: SpaceTheme.rocketRed, size: 20),
                    ),
                    Icon(
                      _entityIcons[rule.entityB] ?? Icons.help_outline,
                      color: colorB,
                      size: 22,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _entityName(rule.entityB),
                      style: SpaceTheme.bodyStyle.copyWith(
                        fontSize: 13,
                        color: colorB,
                        fontWeight: FontWeight.w600,
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

  // ─── Dialogs ───────────────────────────────────────────────────────────

  Widget _buildSuccessDialog(int score) {
    final s = S.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: SpaceTheme.starYellow),
            const SizedBox(height: 16),
            Text(
              s.voidCrossingWin,
              style: SpaceTheme.headlineStyle
                  .copyWith(color: SpaceTheme.alienGreen),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.voidCrossingWinDesc(_gameState!.movesTaken),
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '⭐ $score',
              style: SpaceTheme.titleStyle.copyWith(
                color: SpaceTheme.starYellow,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentLevel = (_currentLevel + 1).clamp(1, 20);
                    });
                    _generatePuzzle();
                  },
                  style: SpaceTheme.secondaryButtonStyle,
                  child: Text(s.voidCrossingNextPuzzle),
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

  Widget _buildOutOfMovesDialog() {
    final s = S.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_off, size: 64, color: SpaceTheme.rocketRed),
            const SizedBox(height: 16),
            Text(
              s.voidCrossingLose,
              style: SpaceTheme.headlineStyle
                  .copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              s.voidCrossingLoseDesc,
              style: SpaceTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  autofocus: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetPuzzle();
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
}

// ─── Star field painter ─────────────────────────────────────────────────────

class _VoidStarsPainter extends CustomPainter {
  final double progress;

  _VoidStarsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.3) % size.height;
      final radius = rng.nextDouble() * 1.5 + 0.5;
      final alpha = (math.sin(progress * math.pi * 2 + i) * 0.3 + 0.7)
          .clamp(0.2, 1.0);

      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_VoidStarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
