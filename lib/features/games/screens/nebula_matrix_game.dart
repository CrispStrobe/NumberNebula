import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/nebula_matrix_logic.dart';

class NebulaMatrixGame extends StatefulWidget {
  final int grade;
  final int level;
  const NebulaMatrixGame({super.key, required this.grade, required this.level});

  @override
  State<NebulaMatrixGame> createState() => _NebulaMatrixGameState();
}

class _NebulaMatrixGameState extends State<NebulaMatrixGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  NebulaMatrixPuzzle? puzzle;
  Map<String, int> userSolution = {};
  bool _isGenerating = true;
  String _lastDroppedCell = '';
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _glowController.dispose();
    _successController.dispose();
    _dropController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int _getGridSize() {
    final grade = currentDifficulty?.grade ?? widget.grade;
    if (grade <= 1) return 3;
    if (grade <= 2) return 4;
    if (grade <= 3) return 5;
    return 5;
  }

  int _getClueCount() {
    final level = currentDifficulty?.level ?? widget.level;
    final size = _getGridSize();
    final totalCells = size * size;
    // More clues at low levels, fewer at high levels
    final base = (totalCells * 0.6).round();
    final reduction = (level / 4).floor();
    return (base - reduction).clamp(size, totalCells - 1);
  }

  void _generatePuzzle() async {
    setState(() {
      _isGenerating = true;
      userSolution.clear();
      _successController.reset();
    });

    try {
      final generator = NebulaMatrixGenerator();
      final p = await generator.generate(
        size: _getGridSize(),
        clueCount: _getClueCount(),
      );

      if (mounted) {
        setState(() {
          puzzle = p;
          _isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint('[NebulaMatrix] Error generating puzzle: $e');
    }
  }

  void _placeNumber(int number, String cellId) {
    setState(() {
      userSolution[cellId] = number;
      _lastDroppedCell = cellId;
      _dropController.forward(from: 0.0);
    });
    _checkSolution();
  }

  void _removeNumber(String cellId) {
    setState(() {
      userSolution.remove(cellId);
    });
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
    int sizeBonus = puzzle!.size * puzzle!.size * 10;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'nebula_matrix',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
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
            Expanded(child: Text(S.of(context)!.nebulaMatrixLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
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
                title: s.nebulaMatrixTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.nebulaMatrixInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: _buildGridArea()),
              _buildNumberPad(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridArea() {
    return Center(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  SpaceTheme.cosmicPink.withValues(alpha: 0.1 * _glowAnimation.value),
                  SpaceTheme.deepSpace.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: SpaceTheme.cosmicPink.withValues(alpha: _glowAnimation.value),
                width: 2,
              ),
            ),
            child: _buildGrid(),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    final gridSize = puzzle!.size;
    const maxCellSize = 60.0;
    final cellSize = math.min(maxCellSize, (MediaQuery.of(context).size.width - 80) / gridSize);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(gridSize, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(gridSize, (col) {
            final cellId = 'r${row}c$col';
            return _buildCell(cellId, cellSize);
          }),
        );
      }),
    );
  }

  Widget _buildCell(String cellId, double cellSize) {
    final isClue = puzzle!.clues.containsKey(cellId);
    final hasUserValue = userSolution.containsKey(cellId);
    final value = isClue ? puzzle!.clues[cellId] : userSolution[cellId];
    final isLastDropped = cellId == _lastDroppedCell;

    if (isClue) {
      return Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
          ),
          border: Border.all(color: Colors.grey.shade600, width: 1),
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: cellSize * 0.45),
          ),
        ),
      );
    }

    if (hasUserValue) {
      Widget cell = Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple],
          ),
          border: Border.all(color: Colors.grey.shade600, width: 1),
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: cellSize * 0.45),
          ),
        ),
      );

      if (isLastDropped) {
        cell = ScaleTransition(scale: _dropAnimation, child: cell);
      }

      return GestureDetector(
        onTap: () => _removeNumber(cellId),
        child: cell,
      );
    }

    // Empty cell - drag target
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                gradient: isHovering
                    ? const LinearGradient(colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange])
                    : const LinearGradient(colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple]),
                border: Border.all(color: Colors.grey.shade600, width: 1),
              ),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: SpaceTheme.nebulaPurple,
                    size: cellSize * 0.3,
                  ),
                ),
              ),
            );
          },
        );
      },
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _placeNumber(details.data, cellId),
    );
  }

  Widget _buildNumberPad() {
    final numbers = puzzle!.numberPool;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
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
                width: 50, height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: SpaceTheme.starGradient,
                  boxShadow: [BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.8), blurRadius: 20)],
                ),
                child: Center(child: Text(n.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 20))),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: _buildTrayTile(n)),
            child: _buildTrayTile(n),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrayTile(int number) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.7), width: 2),
      ),
      child: Center(
        child: Text(number.toString(), style: SpaceTheme.headlineStyle.copyWith(fontSize: 16)),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_on_rounded, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.nebulaMatrixWinDesc(score), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
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
