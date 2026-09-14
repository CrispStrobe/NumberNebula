import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/orbital_towers_diagram.dart';
import '../../../shared/widgets/onboarding_overlay.dart';
import '../constants/difficulty_manager.dart';
import '../services/orbital_towers_logic.dart';
import 'package:flutter/foundation.dart';

class OrbitalTowersGame extends StatefulWidget {
  final int grade;
  final int level;
  const OrbitalTowersGame({super.key, required this.grade, required this.level});

  @override
  State<OrbitalTowersGame> createState() => _OrbitalTowersGameState();
}

class _OrbitalTowersGameState extends State<OrbitalTowersGame>
    with TickerProviderStateMixin, GameAnimationsMixin<OrbitalTowersGame> {
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;

  OrbitalTowersPuzzle? puzzle;
  Map<String, int> userSolution = {};
  bool _isGenerating = true;
  String _lastDroppedCell = '';
  DifficultyConfig? currentDifficulty;

  int _movesRemaining = 0;
  int _maxMoves = 0;

  /// Cells the player has to fill — a flawless solve places each exactly
  /// once, so it doubles as the optimal move count for the performance grade.
  int _optimalMoves = 0;

  // Track completed rows/columns that flash green
  final Set<String> _validatedLines = {};

  @override
  void initState() {
    super.initState();
    initGameAnimations();


    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
        _showOnboarding(onlyIfUnseen: true);
      }
    });
  }

  /// The walkthrough. Shown once on a player's first visit, and again whenever
  /// they tap the help button -- the sightline rule is the whole puzzle, and it
  /// is not something a child guesses from a grid of numbers.
  void _showOnboarding({bool onlyIfUnseen = false}) {
    final s = S.of(context)!;
    final steps = [
      OnboardingStep(
        icon: Icons.grid_4x4,
        body: s.orbitalTowersOnboardGrid,
        illustration: TowerLatinSquareDiagram(size: puzzle?.size ?? 4),
      ),
      OnboardingStep(
        icon: Icons.videocam,
        body: s.orbitalTowersOnboardSightline,
        illustration: const TowerSightlineDiagram(),
      ),
      OnboardingStep(
        icon: Icons.touch_app,
        body: s.orbitalTowersOnboardPlace,
      ),
    ];

    if (onlyIfUnseen) {
      OnboardingOverlay.maybeShow(
        context,
        gameKey: 'orbital_towers',
        title: s.orbitalTowersTitle,
        steps: steps,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => OnboardingOverlay(
        title: s.orbitalTowersTitle,
        steps: steps,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  void dispose() {
    _dropController.dispose();
    disposeGameAnimations();
    super.dispose();
  }

  int _getGridSize() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    return 5;
  }

  int _getEdgeClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    final size = _getGridSize();
    final maxClues = size * 4;
    final base = (maxClues * 0.75).round();
    final reduction = (level / 4).floor();
    return (base - reduction).clamp(size, maxClues);
  }

  int _getCellClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    if (level <= 3) return 2;
    if (level <= 6) return 1;
    return 0;
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userSolution.clear();
      _validatedLines.clear();
      successController.reset();
    });

    try {
      final generator = OrbitalTowersGenerator();
      final p = await generator.generate(
        size: _getGridSize(),
        edgeClueCount: _getEdgeClueCount(),
        cellClueCount: _getCellClueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;

          // Calculate max moves: 2x empty cells (generous safety net)
          final emptyCount = p.emptyCells.length;
          _optimalMoves = emptyCount;
          _maxMoves = emptyCount * 2;
          _movesRemaining = _maxMoves;

          _isGenerating = false;
        });
        if (kDebugMode) debugPrint('[OrbitalTowers] Max moves allowed: $_maxMoves for ${p.emptyCells.length} empty cells');
      }
    } catch (e) {
      debugPrint('[OrbitalTowers] Error generating puzzle: $e');
    }
  }

  void _placeNumber(int number, String cellId) {
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedCell = cellId;
      _dropController.forward(from: 0.0);

      // Decrement moves on placement
      _movesRemaining--;
      if (kDebugMode) debugPrint('[OrbitalTowers] Moves remaining: $_movesRemaining/$_maxMoves');
    });
    _checkLineCompletion(cellId);

    // Check if out of moves BEFORE checking solution
    if (_movesRemaining <= 0 && userSolution.length < puzzle!.emptyCells.length) {
      _handleOutOfMoves();
      return;
    }

    _checkSolution();
  }

  void _removeNumber(String cellId) {
    setState(() {
      userSolution.remove(cellId);
    });
  }

  void _checkLineCompletion(String cellId) {
    if (puzzle == null) return;
    final size = puzzle!.size;
    // Parse row/col from cellId
    final parts = cellId.split('c');
    final row = int.parse(parts[0].substring(1));
    final col = int.parse(parts[1]);

    final complete = Map<String, int>.from(puzzle!.clues);
    complete.addAll(userSolution);

    // Check if row is complete
    bool rowComplete = true;
    final rowVals = <int>{};
    for (int c = 0; c < size; c++) {
      final v = complete['r${row}c$c'];
      if (v == null) { rowComplete = false; break; }
      rowVals.add(v);
    }
    if (rowComplete && rowVals.length == size) {
      _validatedLines.add('row_$row');
    }

    // Check if col is complete
    bool colComplete = true;
    final colVals = <int>{};
    for (int r = 0; r < size; r++) {
      final v = complete['r${r}c$col'];
      if (v == null) { colComplete = false; break; }
      colVals.add(v);
    }
    if (colComplete && colVals.length == size) {
      _validatedLines.add('col_$col');
    }
  }

  void _checkSolution() {
    if (userSolution.length != puzzle!.emptyCells.length) return;

    if (puzzle!.validateSolution(userSolution)) {
      _handleWin();
    } else {
      _handleIncorrect();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.size * puzzle!.size * 15;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'orbital_towers',
      difficulty: widget.level,
      score: totalScore,
        performance: Perf.fromMoves(_maxMoves - _movesRemaining, _optimalMoves),
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

  void _handleIncorrect() {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.orbitalTowersLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleFailure() {
    if (kDebugMode) debugPrint('[OrbitalTowers] FAILURE - recording loss');
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'orbital_towers',
      difficulty: widget.level,
        progress: _optimalMoves == 0 ? 0.0 : userSolution.length / _optimalMoves,
    ));
  }

  void _handleOutOfMoves() {
    if (kDebugMode) debugPrint('[OrbitalTowers] Out of moves! Game over.');
    _handleFailure();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildOutOfMovesDialog(),
      );
    }
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
              s.orbitalTowersOutOfMoves,
              style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              s.orbitalTowersOutOfMovesDesc,
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

  Widget _buildMovesIndicator() {
    Color indicatorColor;
    if (_movesRemaining <= 3) {
      indicatorColor = SpaceTheme.rocketRed;
    } else if (_movesRemaining <= 5) {
      indicatorColor = SpaceTheme.planetOrange;
    } else {
      indicatorColor = SpaceTheme.cosmicPink;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: indicatorColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, color: indicatorColor, size: 18),
          const SizedBox(width: 6),
          Text(
            '$_movesRemaining',
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: 14,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }

  bool _isRowValidated(int row) => _validatedLines.contains('row_$row');
  bool _isColValidated(int col) => _validatedLines.contains('col_$col');

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
                title: s.orbitalTowersTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton.icon(
                    onPressed: _showOnboarding,
                    icon: const Icon(Icons.help_outline,
                        size: 18, color: SpaceTheme.starYellow),
                    label: Text(
                      s.orbitalTowersHowToPlay,
                      style: const TextStyle(
                          color: SpaceTheme.starYellow, fontSize: 13),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        s.orbitalTowersInstructions(puzzle!.size),
                        style: SpaceTheme.bodyStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMovesIndicator(),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return isWide
                        ? _buildWideLayout(constraints)
                        : _buildCompactLayout(constraints);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildGridWithClues(constraints),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _buildNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildGridWithClues(constraints),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: _buildNumberPad(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridWithClues(BoxConstraints outerConstraints) {
    final size = puzzle!.size;

    return Center(
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.rocketRed.withValues(alpha: 0.1 * glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.rocketRed.withValues(alpha: glowAnimation.value),
                width: 2,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Account for clue columns (2 extra) and rows (2 extra)
                final maxCellW = (constraints.maxWidth - 16) / (size + 2);
                final maxCellH = (constraints.maxHeight - 16) / (size + 2);
                final cellSize = math.min(maxCellW, maxCellH).clamp(30.0, 70.0);
                final clueSize = cellSize * 0.7;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top edge clues — width matches grid columns
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: clueSize), // spacer for left clue column
                        ...List.generate(size, (c) {
                          return _buildEdgeClue(puzzle!.edgeClues['top_$c'], cellSize, clueSize);
                        }),
                        SizedBox(width: clueSize), // spacer for right clue column
                      ],
                    ),
                    // Grid rows with left/right clues — height matches grid rows
                    ...List.generate(size, (r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildEdgeClue(puzzle!.edgeClues['left_$r'], clueSize, cellSize),
                          ...List.generate(size, (c) {
                            final cellId = 'r${r}c$c';
                            return _buildCell(cellId, r, c, cellSize);
                          }),
                          _buildEdgeClue(puzzle!.edgeClues['right_$r'], clueSize, cellSize),
                        ],
                      );
                    }),
                    // Bottom edge clues — width matches grid columns
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: clueSize), // spacer for left clue column
                        ...List.generate(size, (c) {
                          return _buildEdgeClue(puzzle!.edgeClues['bottom_$c'], cellSize, clueSize);
                        }),
                        SizedBox(width: clueSize), // spacer for right clue column
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEdgeClue(int? clue, double width, double height) {
    final minDim = math.min(width, height);
    return SizedBox(
      width: width,
      height: height,
      child: clue != null
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  child: Text(
                    clue.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: minDim * 0.5,
                      color: SpaceTheme.starYellow,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCell(String cellId, int row, int col, double cellSize) {
    final isClue = puzzle!.clues.containsKey(cellId);
    final hasUserValue = userSolution.containsKey(cellId);
    final value = isClue ? puzzle!.clues[cellId] : userSolution[cellId];
    final isLastDropped = cellId == _lastDroppedCell;
    final isRowValid = _isRowValidated(row);
    final isColValid = _isColValidated(col);
    final isHighlighted = isRowValid || isColValid;

    if (isClue) {
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHighlighted
                ? [SpaceTheme.alienGreen, SpaceTheme.alienGreen.withValues(alpha: 0.6)]
                : [SpaceTheme.alienGreen.withValues(alpha: 0.4), SpaceTheme.deepSpace],
          ),
          border: Border.all(color: Colors.grey.shade600, width: 1),
        ),
        child: Center(
          child: _buildTowerVisual(value!, cellSize),
        ),
      );
    }

    if (hasUserValue) {
      Widget cell = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHighlighted
                ? [SpaceTheme.alienGreen.withValues(alpha: 0.3), SpaceTheme.deepSpace]
                : [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple],
          ),
          border: Border.all(
            color: isHighlighted ? SpaceTheme.alienGreen : Colors.grey.shade600,
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Center(
          child: _buildTowerVisual(value!, cellSize),
        ),
      );

      if (isLastDropped) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      return GestureDetector(onTap: () => _removeNumber(cellId), child: cell);
    }

    // Empty cell -- DragTarget
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            gradient: isHovering
                ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
            border: Border.all(
              color: isHovering ? SpaceTheme.starYellow : Colors.grey.shade600,
              width: isHovering ? 3 : 1,
            ),
            boxShadow: isHovering
                ? [BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Center(
                  child: Icon(Icons.add, color: SpaceTheme.nebulaPurple, size: cellSize * 0.3),
                ),
              );
            },
          ),
        );
      },
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _placeNumber(details.data, cellId),
    );
  }

  /// Visual tower representation: stacked blocks proportional to height
  Widget _buildTowerVisual(int height, double cellSize) {
    final size = puzzle!.size;
    final blockHeight = (cellSize * 0.7) / size;
    final blockWidth = cellSize * 0.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Number label on top
        Text(
          height.toString(),
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: cellSize * 0.22,
            color: SpaceTheme.starYellow,
          ),
        ),
        // Stacked blocks
        ...List.generate(height, (i) {
          final shade = (i + 1) / size;
          return Container(
            width: blockWidth,
            height: blockHeight.clamp(2.0, 10.0),
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SpaceTheme.planetOrange.withValues(alpha: 0.5 + shade * 0.5),
                  SpaceTheme.rocketRed.withValues(alpha: 0.3 + shade * 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList().reversed,
      ],
    );
  }

  Widget _buildNumberPad() {
    final numbers = puzzle!.numberPool;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: numbers.map((n) {
              return Draggable<int>(
                data: n,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: SpaceTheme.starGradient,
                      boxShadow: [BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )],
                    ),
                    child: Center(
                      child: Text(n.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: _buildTrayTile(n)),
                child: _buildTrayTile(n),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrayTile(int number) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 18)),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
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
                  const Icon(Icons.location_city, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.orbitalTowersWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.orbitalTowersWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        autofocus: true,
                        onPressed: () { Navigator.of(context).pop(); _generatePuzzle(); },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); },
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
