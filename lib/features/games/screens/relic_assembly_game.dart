import 'dart:async';

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
import '../services/relic_assembly_logic.dart';
import 'package:flutter/foundation.dart';

typedef _Drag = ({int tileIndex, Object round, int rotation});

class RelicAssemblyGame extends StatefulWidget {
  final int grade;
  final int level;
  const RelicAssemblyGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<RelicAssemblyGame> createState() => _RelicAssemblyGameState();
}

class _RelicAssemblyGameState extends State<RelicAssemblyGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<RelicAssemblyGame>,
        PuzzleSessionMixin<RelicAssemblyGame> {
  bool _sessionReady = false;
  @override
  String get sessionGameKey => 'relic_assembly';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _terminal || puzzle == null) {
      return null;
    }
    return {
      'puzzle': (puzzle?.toJson()),
      'placement': placement.map((v0) => v0).toList(),
      'rotations': rotations.map((v0) => v0).toList(),
      '_placements': _placements,
      'selectedTileIndex': (selectedTileIndex),
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRound();
    puzzle = (state["puzzle"] == null
        ? null
        : RelicAssemblyPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map),
          ));
    placement = (state["placement"] as List).map((v0) => v0 as int).toList();
    rotations = (state["rotations"] as List).map((v0) => v0 as int).toList();
    _placements = state["_placements"] as int;
    selectedTileIndex = (state["selectedTileIndex"] == null
        ? null
        : state["selectedTileIndex"] as int);
    _isGenerating = false;
    _sessionReady = true;
    _cellTokens = List.generate(placement.length, (_) => Object());
    if (selectedTileIndex != null && !_unused(selectedTileIndex!)) {
      selectedTileIndex = null;
    }
    if (_isSolved) {
      _terminal = true;
      finishPuzzleSession();
      successController.value = 1;
      final round = _round;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(round, _round) && _terminal) {
          _showWinDialog(_winScore, round);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Future<void> _restoreOrGenerate() async {
    final round = _round;
    if (!await restorePuzzleSession() && mounted && identical(round, _round)) {
      await Future<void>.sync(_generatePuzzle);
    }
    if (mounted) setState(() => _sessionReady = true);
  }

  RelicAssemblyPuzzle? puzzle;
  bool _isGenerating = true;

  /// Tiles placed, including re-placements — a flawless fit places each once.
  int _placements = 0;
  DifficultyConfig? currentDifficulty;

  // Player's grid: position index -> tile index in playerTiles
  late List<int> placement;
  // Player's rotations: tile index -> rotation (0-3)
  late List<int> rotations;
  // Selected tile for placement (from tray)
  int? selectedTileIndex;

  Object _round = Object();
  bool _terminal = false;
  bool _reportedOutcome = false;
  bool _generationFailed = false;
  DialogRoute<void>? _resultRoute;
  List<Object> _cellTokens = [];

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_terminal &&
      !_isGenerating &&
      !_generationFailed &&
      puzzle != null;

  bool _unused(int index) =>
      puzzle != null &&
      index >= 0 &&
      index < puzzle!.playerTiles.length &&
      !placement.contains(index);

  bool _canUseSource(int index, Object round) =>
      _canInteract(round) && _unused(index);

  bool _ownsCell(int pos, int index, Object round, Object token) =>
      _canInteract(round) &&
      pos >= 0 &&
      pos < placement.length &&
      placement[pos] == index &&
      identical(_cellTokens[pos], token);

  bool _emptyCell(int pos, Object round) =>
      _canInteract(round) &&
      pos >= 0 &&
      pos < placement.length &&
      placement[pos] == -1;

  bool _accepts(_Drag drag, int pos, Object round) =>
      _emptyCell(pos, round) &&
      identical(drag.round, _round) &&
      _canUseSource(drag.tileIndex, round) &&
      drag.rotation >= 0 &&
      drag.rotation < 4;

  bool get _isSolved {
    final board = puzzle;
    if (board == null ||
        placement.length != board.rows * board.cols ||
        board.playerTiles.length != placement.length ||
        rotations.length != board.playerTiles.length ||
        placement.toSet().length != placement.length ||
        placement.any(
          (index) => index < 0 || index >= board.playerTiles.length,
        )) {
      return false;
    }
    return board.validatePlacement(placement, rotations);
  }

  int get _winScore => 100 * widget.grade + widget.level * 25;

  void _resetRound() {
    _round = Object();
    _terminal = false;
    _reportedOutcome = false;
    _generationFailed = false;
    cancelOneShotMotion(successController);
    successController.reset();
    final route = _resultRoute;
    _resultRoute = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(
      successController,
      reduced,
      duration: const Duration(milliseconds: 600),
    );
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _terminal &&
      dialogContext.mounted &&
      identical(ModalRoute.of(dialogContext), _resultRoute) &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  // Glyph symbols for display
  static const _glyphSymbols = ['1', '2', '3', '4', '5', '6', '7', '8'];
  static const _glyphColors = [
    Color(0xFFFF6B35),
    Color(0xFF6B48FF),
    Color(0xFF06FFA5),
    Color(0xFFE63946),
    Color(0xFFFFD700),
    Color(0xFF00C9DB),
    Color(0xFFFF69B4),
    Color(0xFF8B8B8B),
  ];

  @override
  void initState() {
    super.initState();
    initGameAnimations(usePulse: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(
          gp,
          widget.level,
          gradeOverride: widget.grade,
        );
        _restoreOrGenerate();
      }
    });
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _round = Object();
    final route = _resultRoute;
    _resultRoute = null;
    final navigator = route?.navigator;
    if (route != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    disposeGameAnimations(usePulse: false);
    super.dispose();
  }

  int _getRows() => RelicAssemblyGenerationConfig(
        currentDifficulty?.grade ?? widget.grade,
        currentDifficulty?.level ?? widget.level,
      ).getRows();

  int _getCols() => RelicAssemblyGenerationConfig(
        currentDifficulty?.grade ?? widget.grade,
        currentDifficulty?.level ?? widget.level,
      ).getCols();

  int _getEdgeValueCount() => RelicAssemblyGenerationConfig(
        currentDifficulty?.grade ?? widget.grade,
        currentDifficulty?.level ?? widget.level,
      ).getEdgeValueCount();

  @visibleForTesting
  Future<void> generateForTesting(Future<RelicAssemblyPuzzle> pending) =>
      _generatePuzzle(pending: pending);

  Future<void> _generatePuzzle({Future<RelicAssemblyPuzzle>? pending}) async {
    if (!mounted) return;
    _resetRound();
    beginPuzzleSession();
    final round = _round;
    setState(() {
      _isGenerating = true;
      _placements = 0;
      selectedTileIndex = null;
    });
    try {
      final generator = RelicAssemblyGenerator();
      final p = await (pending ??
          generator.generate(
            rows: _getRows(),
            cols: _getCols(),
            edgeValueCount: _getEdgeValueCount(),
          ));
      if (!mounted || !identical(round, _round)) return;
      setState(() {
        puzzle = p;
        placement = List.filled(p.rows * p.cols, -1);
        rotations = List.generate(
          p.playerTiles.length,
          (i) => p.playerTiles[i].rotation,
        );
        _cellTokens = List.generate(placement.length, (_) => Object());
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted || !identical(round, _round)) return;
      if (kDebugMode) debugPrint('[RelicAssembly] Error generating puzzle: $e');
      setState(() {
        puzzle = null;
        _isGenerating = false;
        _generationFailed = true;
      });
    }
  }

  void _selectTile(int index, Object round) {
    if (!_canUseSource(index, round)) return;
    setState(
      () => selectedTileIndex = selectedTileIndex == index ? null : index,
    );
  }

  void _rotateTrayTile(int index, Object round) {
    if (!_canUseSource(index, round)) return;
    setState(() => rotations[index] = (rotations[index] + 1) % 4);
    AppHaptics.selectionClick();
  }

  void _rotateGridTile(int pos, int index, Object round, Object cell) {
    if (!_ownsCell(pos, index, round, cell)) return;
    setState(() => rotations[index] = (rotations[index] + 1) % 4);
    AppHaptics.selectionClick();
    _checkSolution();
  }

  void _placeTileAt(int pos, Object round, {_Drag? drag}) {
    final index = drag?.tileIndex ?? selectedTileIndex;
    if (index == null || !_emptyCell(pos, round)) return;
    if (drag != null) {
      if (!_accepts(drag, pos, round)) return;
    } else if (!_unused(index)) {
      return;
    }
    setState(() {
      // The visual drag retains its starting orientation even if another
      // control has since turned this still-unused tile.
      if (drag != null) rotations[index] = drag.rotation;
      placement[pos] = index;
      _cellTokens[pos] = Object();
      selectedTileIndex = null;
      _placements++;
    });
    AppHaptics.lightImpact();
    _checkSolution();
  }

  void _removeTileFromGrid(int pos, int index, Object round, Object cell) {
    if (!_ownsCell(pos, index, round, cell)) return;
    setState(() {
      placement[pos] = -1;
      _cellTokens[pos] = Object();
    });
  }

  void _checkSolution() {
    if (_canInteract(_round) && _isSolved) _handleWin();
  }

  void _handleWin() {
    if (!_canInteract(_round) || !_isSolved) return;
    _terminal = true;
    _reportedOutcome = true;
    final round = _round;
    AppHaptics.lightImpact();
    final totalScore = _winScore;
    finishPuzzleSession();
    context.read<GameProvider>().reportOutcome(
          GameOutcome.win(
            skillLevel: widget.grade,
            gameType: 'relic_assembly',
            difficulty: widget.level,
            score: totalScore,
            performance: Perf.fromMoves(_placements, placement.length),
            movesUsed: _placements,
            optimalMoves: placement.length,
          ),
        );
    successController.reset();
    playOneShotMotion(successController, () {});
    _showWinDialog(totalScore, round);
  }

  void _showWinDialog(int score, Object round) {
    if (!mounted ||
        !identical(round, _round) ||
        !_terminal ||
        (_resultRoute?.isActive ?? false)) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (ctx) => _buildWinDialog(score, round, ctx),
    );
    _resultRoute = route;
    unawaited(
      navigator.push<void>(route).then((_) {
        if (identical(_resultRoute, route)) _resultRoute = null;
      }),
    );
  }

  /// Check if the edge of a placed tile at grid position [pos] matches
  /// its neighbor on the given [side] (0=top, 1=right, 2=bottom, 3=left).
  /// Returns null if no neighbor, true if match, false if mismatch.
  bool? _edgeMatches(int pos, int side) {
    if (puzzle == null) return null;
    final tileIdx = placement[pos];
    if (tileIdx < 0) return null;

    final row = pos ~/ puzzle!.cols;
    final col = pos % puzzle!.cols;
    int neighborPos = -1;
    int neighborSide = -1;

    switch (side) {
      case 0: // top
        if (row == 0) return null;
        neighborPos = pos - puzzle!.cols;
        neighborSide = 2; // neighbor's bottom
      case 1: // right
        if (col >= puzzle!.cols - 1) return null;
        neighborPos = pos + 1;
        neighborSide = 3; // neighbor's left
      case 2: // bottom
        if (row >= puzzle!.rows - 1) return null;
        neighborPos = pos + puzzle!.cols;
        neighborSide = 0; // neighbor's top
      case 3: // left
        if (col == 0) return null;
        neighborPos = pos - 1;
        neighborSide = 1; // neighbor's right
    }

    if (neighborPos < 0 || neighborPos >= placement.length) return null;
    final neighborTileIdx = placement[neighborPos];
    if (neighborTileIdx < 0) return null;

    final tile = puzzle!.playerTiles[tileIdx].copyWith(
      rotation: rotations[tileIdx],
    );
    final neighbor = puzzle!.playerTiles[neighborTileIdx].copyWith(
      rotation: rotations[neighborTileIdx],
    );
    return tile.getEdge(side) == neighbor.getEdge(neighborSide);
  }

  Set<int> _getPlacedTileIndices() {
    return placement.where((p) => p >= 0).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = S.of(context)!;
    final round = _round;

    if (puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_generationFailed)
                  ElevatedButton(
                    onPressed: () {
                      if (mounted &&
                          identical(round, _round) &&
                          _generationFailed) {
                        _generatePuzzle();
                      }
                    },
                    child: Text(s.tryAgain),
                  )
                else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(s.loadingAdventure, style: SpaceTheme.bodyStyle),
                ],
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
                key: ValueKey(('relic-back', round)),
                title: s.relicAssemblyTitle,
                level: widget.level,
                onBack: () {
                  if (mounted &&
                      identical(round, _round) &&
                      ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.16,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      s.relicAssemblyInstructions,
                      style: SpaceTheme.bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = math.max(0.0, constraints.maxHeight - 8);
                    final gridHeight = math.max(
                      puzzle!.rows * 52.0 + 28,
                      available * 0.6,
                    );
                    final trayHeight = math.max(100.0, available * 0.4);
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: gridHeight, child: _buildGridArea()),
                          SizedBox(height: trayHeight, child: _buildTileTray()),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    final rows = puzzle!.rows;
    final cols = puzzle!.cols;
    // Fill the space the board is given rather than a fixed 80px: on a tablet
    // the old cap left the pieces thumbnail-sized with most of the screen
    // empty, and the edge glyphs scale with the cell.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = math
            .min(
              (constraints.maxWidth - 60) / cols,
              (constraints.maxHeight - 40) / rows,
            )
            .clamp(48.0, 140.0);

        return Center(
          child: AnimatedBuilder(
            animation: glowAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.planetOrange.withValues(
                        alpha: 0.1 * glowAnimation.value,
                      ),
                      SpaceTheme.deepSpace.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: SpaceTheme.planetOrange.withValues(
                      alpha: glowAnimation.value,
                    ),
                    width: 2,
                  ),
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(cols, (c) {
                    final pos = r * cols + c;
                    return _buildGridSlot(pos, cellSize);
                  }),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridSlot(int pos, double cellSize) {
    final tileIdx = placement[pos];
    final round = _round;
    final cell = _cellTokens[pos];
    final reduced = MediaQuery.disableAnimationsOf(context);

    if (tileIdx >= 0) {
      final tile = puzzle!.playerTiles[tileIdx];
      return GestureDetector(
        key: ValueKey(('relic-cell', round, pos, cell)),
        behavior: HitTestBehavior.opaque,
        onTap: () => _rotateGridTile(pos, tileIdx, round, cell),
        onLongPress: () => _removeTileFromGrid(pos, tileIdx, round, cell),
        child: Stack(
          children: [
            _buildTileWidget(
              tile,
              rotations[tileIdx],
              cellSize,
              false,
              gridPos: pos,
            ),
            // Rotate indicator
            Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.rotate_right,
                size: 14,
                color: SpaceTheme.starYellow.withValues(alpha: 0.7),
              ),
            ),
            // Taking a piece back off the grid used to be long-press only,
            // with nothing on screen to suggest it -- so a misplaced piece
            // looked permanent and the puzzle looked unplayable.
            Positioned(
              bottom: 2,
              right: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                key: ValueKey(('relic-remove', round, pos, cell)),
                onTap: () => _removeTileFromGrid(pos, tileIdx, round, cell),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: SpaceTheme.rocketRed.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty slot -- accepts drag OR tap (if tile selected)
    return DragTarget<_Drag>(
      key: ValueKey(('relic-cell', round, pos, cell)),
      builder: (context, candidates, _) {
        final isHovering = candidates.isNotEmpty;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _placeTileAt(pos, round),
          child: AnimatedContainer(
            key: ValueKey(reduced),
            duration:
                reduced ? Duration.zero : const Duration(milliseconds: 200),
            width: cellSize,
            height: cellSize,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isHovering
                  ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                  : selectedTileIndex != null
                      ? SpaceTheme.starYellow.withValues(alpha: 0.15)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering
                    ? SpaceTheme.starYellow
                    : selectedTileIndex != null
                        ? SpaceTheme.starYellow.withValues(alpha: 0.7)
                        : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                width: isHovering ? 3 : (selectedTileIndex != null ? 2 : 1),
              ),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: isHovering
                    ? SpaceTheme.starYellow
                    : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                size: cellSize * 0.3,
              ),
            ),
          ),
        );
      },
      onWillAcceptWithDetails: (details) => _accepts(details.data, pos, round),
      onAcceptWithDetails: (details) =>
          _placeTileAt(pos, round, drag: details.data),
    );
  }

  Widget _buildTileWidget(
    RelicTile tile,
    int rotation,
    double size,
    bool isSelected, {
    int? gridPos,
  }) {
    final effectiveTile = tile.copyWith(rotation: rotation);
    final edgeSize = size * 0.25;

    // Check edge matches if this tile is placed on the grid
    final topMatch = gridPos != null ? _edgeMatches(gridPos, 0) : null;
    final rightMatch = gridPos != null ? _edgeMatches(gridPos, 1) : null;
    final bottomMatch = gridPos != null ? _edgeMatches(gridPos, 2) : null;
    final leftMatch = gridPos != null ? _edgeMatches(gridPos, 3) : null;

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? SpaceTheme.starYellow.withValues(alpha: 0.3)
            : SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Top edge
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(
              child: _buildEdgeLabel(
                effectiveTile.getEdge(0),
                edgeSize,
                matchState: topMatch,
              ),
            ),
          ),
          // Right edge
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildEdgeLabel(
                effectiveTile.getEdge(1),
                edgeSize,
                matchState: rightMatch,
              ),
            ),
          ),
          // Bottom edge
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: _buildEdgeLabel(
                effectiveTile.getEdge(2),
                edgeSize,
                matchState: bottomMatch,
              ),
            ),
          ),
          // Left edge
          Positioned(
            left: 2,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildEdgeLabel(
                effectiveTile.getEdge(3),
                edgeSize,
                matchState: leftMatch,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeLabel(int value, double size, {bool? matchState}) {
    final colorIdx = (value - 1).clamp(0, _glyphColors.length - 1);
    // Edge match feedback: green border for match, red for mismatch
    Color bgColor = _glyphColors[colorIdx].withValues(alpha: 0.3);
    Color? borderColor;
    if (matchState == true) {
      bgColor = SpaceTheme.alienGreen.withValues(alpha: 0.4);
      borderColor = SpaceTheme.alienGreen;
    } else if (matchState == false) {
      bgColor = SpaceTheme.rocketRed.withValues(alpha: 0.4);
      borderColor = SpaceTheme.rocketRed;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          _glyphSymbols[colorIdx],
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            color: _glyphColors[colorIdx],
          ),
        ),
      ),
    );
  }

  Widget _buildTileTray() {
    final placedIndices = _getPlacedTileIndices();
    final round = _round;
    final availableTiles = <int>[];
    for (int i = 0; i < puzzle!.playerTiles.length; i++) {
      if (!placedIndices.contains(i)) {
        availableTiles.add(i);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // As large as the tray allows (up to 110px), so the edge glyphs are
        // readable and a child's finger can hit a piece.
        final count = math.max(1, availableTiles.length);
        final tileSize = math
            .min(
              (constraints.maxWidth - 64 - 8 * (count - 1)) / count,
              constraints.maxHeight - 32,
            )
            .clamp(56.0, 110.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          child: availableTiles.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Text(
                      S.of(context)!.relicAssemblyInstructions,
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: availableTiles.map((idx) {
                      final isSelected = selectedTileIndex == idx;
                      return Draggable<_Drag>(
                        key: ValueKey((
                          'relic-source',
                          round,
                          idx,
                          rotations[idx],
                        )),
                        maxSimultaneousDrags: _terminal ? 0 : 1,
                        data: (
                          tileIndex: idx,
                          round: round,
                          rotation: rotations[idx],
                        ),
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: SpaceTheme.starYellow.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: _buildTileWidget(
                              puzzle!.playerTiles[idx],
                              rotations[idx],
                              tileSize,
                              true,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildTileWidget(
                            puzzle!.playerTiles[idx],
                            rotations[idx],
                            tileSize,
                            false,
                          ),
                        ),
                        child: GestureDetector(
                          key: ValueKey(('relic-select', round, idx)),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _selectTile(idx, round),
                          onLongPress: () => _rotateTrayTile(idx, round),
                          child: Stack(
                            children: [
                              _buildTileWidget(
                                puzzle!.playerTiles[idx],
                                rotations[idx],
                                tileSize,
                                isSelected,
                              ),
                              // Rotate button overlay
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Semantics(
                                  label: S.of(context)!.hullPlatingRotate,
                                  button: true,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    key: ValueKey(('relic-rotate', round, idx)),
                                    onTap: () => _rotateTrayTile(idx, round),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: SpaceTheme.nebulaPurple
                                            .withValues(alpha: 0.8),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(8),
                                          topRight: Radius.circular(6),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.rotate_right,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
        );
      },
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
                  if (_reportedOutcome)
                    RoundSummary(
                      gameKey: 'relic_assembly',
                      canNavigate: () => _canUseDialog(round, dialogContext),
                    ),
                  const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 64,
                    color: SpaceTheme.starYellow,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.relicAssemblyWinTitle,
                    style: SpaceTheme.headlineStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.relicAssemblyWinDesc(score),
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
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
                          if (!_canUseDialog(round, dialogContext)) return;
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
