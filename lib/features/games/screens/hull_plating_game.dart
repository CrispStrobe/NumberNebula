import 'dart:async';

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
import '../services/hull_plating_logic.dart';

typedef HullPlatingDrag = ({int pieceId, Object round, int rotation});

class HullPlatingGame extends StatefulWidget {
  final int grade;
  final int level;
  const HullPlatingGame({super.key, required this.grade, required this.level});

  @override
  State<HullPlatingGame> createState() => _HullPlatingGameState();
}

class _HullPlatingGameState extends State<HullPlatingGame>
    with
        TickerProviderStateMixin,
        GameAnimationsMixin<HullPlatingGame>,
        PuzzleSessionMixin<HullPlatingGame> {
  bool _sessionReady = false;
  @override
  String get sessionGameKey => 'hull_plating';
  @override
  int get sessionGrade => widget.grade;
  @override
  int get sessionLevel => widget.level;
  @override
  Map<String, dynamic>? capturePuzzleSession() {
    if (!_sessionReady || _isGenerating || _terminal) return null;
    return {
      'puzzle': (puzzle?.toJson()),
      '_placedPieces': _placedPieces.map((v0) => v0.toJson()).toList(),
      '_selectedRotation': _selectedRotation,
      '_usedPieceIds': _usedPieceIds.map((v0) => v0).toList(),
      '_placements': _placements
    };
  }

  @override
  void applyPuzzleSession(Map<String, dynamic> state) {
    _resetRound();
    puzzle = (state["puzzle"] == null
        ? null
        : HullPlatingPuzzle.fromJson(
            Map<String, dynamic>.from(state["puzzle"] as Map)));
    _placedPieces
      ..clear()
      ..addAll((state["_placedPieces"] as List)
          .map((v0) =>
              PlacedPiece.fromJson(Map<String, dynamic>.from(v0 as Map)))
          .toList());
    _selectedRotation = state["_selectedRotation"] as int;
    _usedPieceIds
      ..clear()
      ..addAll(_placedPieces.map((piece) => piece.pieceId));
    _placements = state["_placements"] as int;
    _isGenerating = false;
    _sessionReady = true;
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

  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  HullPlatingPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  /// Plates placed, including re-placements — a flawless fit places each once.
  int _placements = 0;

  // Player state
  final List<PlacedPiece> _placedPieces = [];
  int _selectedRotation = 0;
  final Set<int> _usedPieceIds = {};
  String _lastDroppedCell = '';

  Object _round = Object();
  bool _terminal = false;
  bool _reportedOutcome = false;
  DialogRoute<void>? _resultRoute;
  HullPlatingDrag? _hoveringDrag;

  bool _canInteract(Object round) =>
      mounted &&
      identical(round, _round) &&
      !_terminal &&
      !_isGenerating &&
      puzzle != null;

  PlatingPiece? _availablePiece(HullPlatingDrag drag, Object round) {
    if (!_canInteract(round) ||
        !identical(drag.round, _round) ||
        drag.rotation < 0 ||
        drag.rotation > 3 ||
        _usedPieceIds.contains(drag.pieceId)) {
      return null;
    }
    for (final piece in puzzle!.pieces) {
      if (piece.id == drag.pieceId) return _rotatedPiece(piece, drag.rotation);
    }
    return null;
  }

  bool get _isSolved {
    final board = puzzle;
    if (board == null ||
        board.pieces.isEmpty ||
        _placedPieces.length != board.pieces.length) {
      return false;
    }
    final ids = board.pieces.map((p) => p.id).toSet();
    final placedIds = _placedPieces.map((p) => p.pieceId).toSet();
    return ids.length == board.pieces.length &&
        placedIds.length == _placedPieces.length &&
        placedIds.containsAll(ids) &&
        HullPlatingPuzzle.validatePlacement(
            _placedPieces, board.board, board.rows, board.cols);
  }

  int get _winScore =>
      100 * widget.grade + widget.level * 25 + puzzle!.pieces.length * 30;

  void _resetRound() {
    _round = Object();
    _terminal = false;
    _reportedOutcome = false;
    _clearVisuals();
    cancelOneShotMotion(successController);
    successController.reset();
    final route = _resultRoute;
    _resultRoute = null;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.clearSnackBars();
    messenger?.removeCurrentSnackBar();
  }

  void _clearVisuals() {
    _hoveringDrag = null;
    _hoverRow = null;
    _hoverCol = null;
    _lastDroppedCell = '';
    cancelOneShotMotion(_dropController);
    _dropController.value = 1;
  }

  @override
  void onPuzzleSessionMotionChanged(bool reduced) {
    updateOneShotMotion(_dropController, reduced,
        duration: const Duration(milliseconds: 500));
    updateOneShotMotion(successController, reduced,
        duration: const Duration(milliseconds: 600));
  }

  bool _canUseDialog(Object round, BuildContext dialogContext) =>
      mounted &&
      identical(round, _round) &&
      _terminal &&
      dialogContext.mounted &&
      identical(ModalRoute.of(dialogContext), _resultRoute) &&
      ModalRoute.of(dialogContext)?.isCurrent == true;

  // Ghost preview state
  int? _hoverRow;
  int? _hoverCol;

  // Piece colors for display
  static const _pieceColors = [
    Color(0xFFE63946), // red
    Color(0xFF457B9D), // blue
    Color(0xFF06FFA5), // green
    Color(0xFFFFD700), // yellow
    Color(0xFF00C9DB), // cyan
    Color(0xFFBB86FC), // purple
  ];

  @override
  void initState() {
    super.initState();
    initGameAnimations();

    successAnimation =
        CurvedAnimation(parent: successController, curve: Curves.elasticOut);

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation =
        CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

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
    final route = _resultRoute;
    _resultRoute = null;
    final navigator = route?.navigator;
    // Disposal can run while the navigator is finalizing another route.
    // Remove only our result once that navigator unlocks.
    if (route != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
    _dropController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  void _generatePuzzle() {
    if (!mounted || currentDifficulty == null) return;
    _resetRound();
    beginPuzzleSession();

    setState(() {
      _isGenerating = true;
      _placements = 0;
      _placedPieces.clear();
      _usedPieceIds.clear();
      _selectedRotation = 0;
      _hoveringDrag = null;
      successController.reset();
    });

    final generated = HullPlatingPuzzle.generate(
      grade: currentDifficulty!.grade,
      level: widget.level,
    );

    if (mounted) {
      setState(() {
        puzzle = generated;
        _isGenerating = false;
      });
    }
  }

  PlatingPiece _getRotatedPiece(int index) {
    return _rotatedPiece(puzzle!.pieces[index], _selectedRotation);
  }

  PlatingPiece _rotatedPiece(PlatingPiece piece, int rotation) {
    for (int i = 0; i < rotation; i++) {
      piece = piece.rotated();
    }
    return piece;
  }

  void _rotatePiece(Object round) {
    if (!_canInteract(round)) return;
    setState(() {
      _selectedRotation = (_selectedRotation + 1) % 4;
    });
  }

  /// Compute the center offset for a piece so the drop cell aligns with the
  /// piece center rather than the top-left corner.
  (int, int) _pieceCenterOffset(PlatingPiece piece) {
    final maxR = piece.cells.map((c) => c.$1).reduce(math.max);
    final maxC = piece.cells.map((c) => c.$2).reduce(math.max);
    return (maxR ~/ 2, maxC ~/ 2);
  }

  List<(int, int)>? _computePlacement(PlatingPiece piece, int row, int col) {
    // Anchor at the center of the piece bounding box so the drop cell
    // maps to where the user's finger actually is.
    final (centerR, centerC) = _pieceCenterOffset(piece);
    final dr = row - centerR;
    final dc = col - centerC;

    final absoluteCells =
        piece.cells.map((c) => (c.$1 + dr, c.$2 + dc)).toList();

    for (final cell in absoluteCells) {
      if (cell.$1 < 0 ||
          cell.$1 >= puzzle!.rows ||
          cell.$2 < 0 ||
          cell.$2 >= puzzle!.cols) {
        return null;
      }
      if (!puzzle!.board[cell.$1][cell.$2]) {
        return null;
      }
      if (_getPlacedPieceAt(cell.$1, cell.$2) != null) {
        return null;
      }
    }
    return absoluteCells;
  }

  void _placePieceAt(HullPlatingDrag drag, int row, int col, Object round) {
    final piece = _availablePiece(drag, round);
    if (piece == null) return;
    final placement = _computePlacement(piece, row, col);
    if (placement == null) {
      AppHaptics.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.hullPlatingNoFit),
            backgroundColor: SpaceTheme.rocketRed,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    AppHaptics.lightImpact();
    setState(() {
      _placedPieces.add(PlacedPiece(
        pieceId: piece.id,
        absoluteCells: placement,
      ));
      _usedPieceIds.add(piece.id);
      _placements++;
      _lastDroppedCell = 'r${row}c$col';
      _dropController.reset();
      playOneShotMotion(_dropController, () {});
      _selectedRotation = 0;
      _hoveringDrag = null;
    });

    _checkSolution();
  }

  PlacedPiece? _getPlacedPieceAt(int row, int col) {
    for (final p in _placedPieces) {
      if (p.covers(row, col)) return p;
    }
    return null;
  }

  void _removePlacedPiece(
      int row, int col, Object round, PlacedPiece expected) {
    if (!_canInteract(round)) return;
    final existing = _getPlacedPieceAt(row, col);
    if (existing == null || !identical(existing, expected)) return;
    AppHaptics.lightImpact();
    setState(() {
      _placedPieces.remove(existing);
      if (!_placedPieces.any((piece) => piece.pieceId == existing.pieceId)) {
        _usedPieceIds.remove(existing.pieceId);
      }
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

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
          skillLevel: widget.grade,
          gameType: 'hull_plating',
          difficulty: widget.level,
          score: totalScore,
          // Fitting every plate on the first try is the perfect run; shuffling
          // pieces around costs quality.
          performance: Perf.fromMoves(_placements, puzzle!.pieces.length),

          movesUsed: _placements,
          optimalMoves: puzzle!.pieces.length,
        ));

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
    unawaited(navigator.push<void>(route).then((_) {
      if (identical(_resultRoute, route)) _resultRoute = null;
    }));
  }

  void _clearBoard(Object round) {
    if (!_canInteract(round)) return;
    AppHaptics.lightImpact();
    setState(() {
      _placedPieces.clear();
      _usedPieceIds.clear();
      _selectedRotation = 0;
      _clearVisuals();
    });
  }

  Color _colorForPieceId(int pieceId) {
    return _pieceColors[pieceId % _pieceColors.length];
  }

  /// Returns (ghostCells, isValid). Shows ghost even for invalid placements (red).
  (Set<String>, bool) _getGhostInfo() {
    if (_hoveringDrag == null || _hoverRow == null || _hoverCol == null) {
      return (<String>{}, false);
    }
    final piece = _availablePiece(_hoveringDrag!, _round);
    if (piece == null) return (<String>{}, false);

    // Compute absolute cells with center-anchoring (same as _computePlacement)
    final (centerR, centerC) = _pieceCenterOffset(piece);
    final dr = _hoverRow! - centerR;
    final dc = _hoverCol! - centerC;
    final absoluteCells =
        piece.cells.map((c) => (c.$1 + dr, c.$2 + dc)).toList();

    // Check validity
    final validPlacement = _computePlacement(piece, _hoverRow!, _hoverCol!);
    final isValid = validPlacement != null;

    // Only include cells that are within the grid
    final ghostCells = <String>{};
    for (final cell in absoluteCells) {
      if (cell.$1 >= 0 &&
          cell.$1 < puzzle!.rows &&
          cell.$2 >= 0 &&
          cell.$2 < puzzle!.cols) {
        ghostCells.add('r${cell.$1}c${cell.$2}');
      }
    }

    return (ghostCells, isValid);
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
                key: ValueKey(('hull-back', round)),
                title: s.hullPlatingTitle,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: SpaceTheme.starYellow, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.16),
                            child: SingleChildScrollView(
                                child: Text(s.hullPlatingInstructions,
                                    style: SpaceTheme.bodyStyle
                                        .copyWith(fontSize: 14))))),
                  ]),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    final isCompact = constraints.maxHeight < 500;
                    return isWide
                        ? _buildWideLayout(constraints, isCompact)
                        : _buildCompactLayout(constraints, isCompact);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildBoardArea(constraints),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildControlsAndTray(isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildBoardArea(constraints),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: _buildControlsAndTray(isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardArea(BoxConstraints outerConstraints) {
    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink
                      .withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink
                    .withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: child,
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxCellW = (constraints.maxWidth - 32) / puzzle!.cols;
            final maxCellH = (constraints.maxHeight - 32) / puzzle!.rows;
            final cellSize = math.min(maxCellW, maxCellH).clamp(1.0, 80.0);
            return _buildBoard(cellSize);
          },
        ),
      ),
    );
  }

  Widget _buildBoard(double cellSize) {
    final (ghostCells, ghostValid) = _getGhostInfo();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(puzzle!.rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(puzzle!.cols, (c) {
            return _buildCell(r, c, cellSize, ghostCells, ghostValid);
          }),
        );
      }),
    );
  }

  Widget _buildCell(
      int row, int col, double size, Set<String> ghostCells, bool ghostValid) {
    final round = _round;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final isActive = puzzle!.board[row][col];
    final placed = _getPlacedPieceAt(row, col);
    final isDark = HullPlatingPuzzle.isDarkCell(row, col);
    final cellId = 'r${row}c$col';
    final isGhost = ghostCells.contains(cellId);
    final isLastDropped = cellId == _lastDroppedCell;

    if (!isActive) {
      return SizedBox(width: size, height: size);
    }

    // Cell with a placed piece -- tap to remove
    if (placed != null) {
      Widget cellWidget = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _colorForPieceId(placed.pieceId).withValues(alpha: 0.8),
          border: Border.all(
            color: _colorForPieceId(placed.pieceId),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(Icons.close, color: Colors.white30, size: size * 0.3),
        ),
      );

      if (isLastDropped) {
        cellWidget = ScaleTransition(scale: _dropAnimation, child: cellWidget);
      }

      return GestureDetector(
        key: ValueKey(('hull-cell', round, row, col, ObjectKey(placed))),
        onTap: () => _removePlacedPiece(row, col, round, placed),
        child: cellWidget,
      );
    }

    // Empty active cell -- this is a DragTarget
    return DragTarget<HullPlatingDrag>(
      key: ValueKey(('hull-cell', round, row, col)),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          key: ValueKey(reduced),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isGhost
                ? (ghostValid
                    ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                    : SpaceTheme.rocketRed.withValues(alpha: 0.3))
                : isHovering
                    ? SpaceTheme.starYellow.withValues(alpha: 0.2)
                    : isDark
                        ? SpaceTheme.deepSpace.withValues(alpha: 0.8)
                        : SpaceTheme.deepSpace.withValues(alpha: 0.5),
            border: Border.all(
              color: isGhost || isHovering
                  ? SpaceTheme.starYellow
                  : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
              width: isGhost || isHovering ? 2 : 1,
            ),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: SpaceTheme.nebulaPurple.withValues(alpha: 0.4),
                    size: size * 0.3,
                  ),
                ),
              );
            },
          ),
        );
      },
      onWillAcceptWithDetails: (details) {
        if (_availablePiece(details.data, round) == null) return false;
        setVisualState(() {
          _hoveringDrag = details.data;
          _hoverRow = row;
          _hoverCol = col;
        });
        return true;
      },
      onLeave: (data) {
        if (!_canInteract(round) ||
            data != _hoveringDrag ||
            _hoverRow != row ||
            _hoverCol != col) {
          return;
        }
        setVisualState(() {
          _hoveringDrag = null;
          _hoverRow = null;
          _hoverCol = null;
        });
      },
      onAcceptWithDetails: (details) {
        _placePieceAt(details.data, row, col, round);
      },
    );
  }

  Widget _buildControlsAndTray(bool isCompact) {
    final round = _round;
    return Column(
      children: [
        // Controls row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Tooltip(
                message: S.of(context)!.hullPlatingRotate,
                child: ElevatedButton.icon(
                  key: ValueKey(('hull-rotate', round)),
                  icon: const Icon(Icons.rotate_right, size: 24),
                  label:
                      Text(isCompact ? '' : S.of(context)!.hullPlatingRotate),
                  onPressed: _terminal ? null : () => _rotatePiece(round),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        SpaceTheme.starYellow.withValues(alpha: 0.3),
                    foregroundColor: SpaceTheme.starYellow,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey(('hull-clear', round)),
                icon:
                    const Icon(Icons.delete_sweep, color: SpaceTheme.rocketRed),
                iconSize: 28,
                onPressed: !_terminal && _placedPieces.isNotEmpty
                    ? () => _clearBoard(round)
                    : null,
                tooltip: S.of(context)!.clearButton,
              ),
              Text(
                '${_placedPieces.length}/${puzzle!.pieces.length}',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
        // Piece tray
        Expanded(child: _buildPieceTray()),
      ],
    );
  }

  /// Group pieces by shape signature for cleaner tray display.
  String _shapeKey(PlatingPiece piece) {
    final sorted = piece.cells.toList()
      ..sort((a, b) {
        final r = a.$1.compareTo(b.$1);
        return r != 0 ? r : a.$2.compareTo(b.$2);
      });
    return sorted.map((c) => '${c.$1},${c.$2}').join(';');
  }

  Widget _buildPieceTray() {
    final round = _round;
    // Group unused pieces by shape, show each shape once with count
    final unusedIndices = <int>[];
    for (int i = 0; i < puzzle!.pieces.length; i++) {
      if (!_usedPieceIds.contains(puzzle!.pieces[i].id)) {
        unusedIndices.add(i);
      }
    }

    // Group by shape key
    final groups = <String, List<int>>{};
    for (final idx in unusedIndices) {
      final piece = _getRotatedPiece(idx);
      final key = _shapeKey(piece);
      groups.putIfAbsent(key, () => []).add(idx);
    }

    if (groups.isEmpty) {
      return Center(
        child: Text(S.of(context)!.hullPlatingAllPlaced,
            style: SpaceTheme.bodyStyle.copyWith(color: Colors.white54)),
      );
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: groups.entries.map((entry) {
        final indices = entry.value;
        final firstIdx = indices.first;
        final piece = puzzle!.pieces[firstIdx];
        final color = _colorForPieceId(piece.id);
        final displayPiece = _getRotatedPiece(firstIdx);
        final count = indices.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SingleChildScrollView(
            child: Draggable<HullPlatingDrag>(
              key:
                  ValueKey(('hull-source', round, piece.id, _selectedRotation)),
              maxSimultaneousDrags: _terminal ? 0 : 1,
              data: (
                pieceId: piece.id,
                round: round,
                rotation: _selectedRotation
              ),
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _buildMiniPiece(displayPiece, color, 60.0),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildPieceTrayCard(displayPiece, color, false),
              ),
              child: Stack(
                children: [
                  _buildPieceTrayCard(displayPiece, color, true),
                  if (count > 1)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('×$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieceTrayCard(PlatingPiece piece, Color color, bool active) {
    return AnimatedContainer(
      key: ValueKey(MediaQuery.disableAnimationsOf(context)),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active
            ? SpaceTheme.deepSpace.withValues(alpha: 0.6)
            : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.7) : Colors.white10,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniPiece(piece, color, 60.0),
          const SizedBox(height: 4),
          Text(
            '${piece.cells.length} cells',
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPiece(
      PlatingPiece piece, Color color, double targetMinCellSize) {
    final h = piece.height;
    final w = piece.width;
    // Ensure mini-cell is at least 14px, but scale up to targetMinCellSize / max(h,w)
    final miniCellSize = math.max(14.0, targetMinCellSize / math.max(h, w));
    final cellSet = piece.cells.toSet();

    return SizedBox(
      width: w * miniCellSize,
      height: h * miniCellSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(h, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(w, (c) {
              final filled = cellSet.contains((r, c));
              return Container(
                width: miniCellSize,
                height: miniCellSize,
                decoration: BoxDecoration(
                  color: filled ? color : Colors.transparent,
                  borderRadius: filled ? BorderRadius.circular(3) : null,
                  border: filled
                      ? Border.all(color: Colors.white38, width: 1)
                      : null,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildWinDialog(
      int bonusScore, Object round, BuildContext dialogContext) {
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
                        gameKey: 'hull_plating',
                        canNavigate: () => _canUseDialog(round, dialogContext)),
                  const Icon(Icons.shield,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinDesc(bonusScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
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
