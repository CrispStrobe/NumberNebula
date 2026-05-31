import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/warp_fold_logic.dart';

class WarpFoldGame extends StatefulWidget {
  final int grade;
  final int level;
  const WarpFoldGame({super.key, required this.grade, required this.level});
  @override
  State<WarpFoldGame> createState() => _WarpFoldGameState();
}

class _WarpFoldGameState extends State<WarpFoldGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  WarpFoldPuzzle? _puzzle;
  int? _selectedOption;
  bool _isGenerating = true;
  bool _answered = false;
  DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

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
    super.dispose();
  }

  void _generatePuzzle() {
    setState(() {
      _isGenerating = true;
      _selectedOption = null;
      _answered = false;
      _successController.reset();
    });

    final generator =
        WarpFoldGenerator(seed: DateTime.now().millisecondsSinceEpoch);
    final puzzle = generator.generate(grade: widget.grade, level: widget.level);

    setState(() {
      _puzzle = puzzle;
      _isGenerating = false;
    });
  }

  void _selectOption(int index) {
    if (_answered) return;
    setState(() {
      _selectedOption = index;
    });
  }

  void _submitAnswer() {
    if (_selectedOption == null || _answered) return;
    setState(() => _answered = true);

    if (_selectedOption == _puzzle!.correctIndex) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int foldBonus = _puzzle!.folds.length * 50;
    int totalScore = baseScore + levelBonus + foldBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'warp_fold',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildWinDialog(totalScore),
    );
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'warp_fold',
      difficulty: widget.level,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.warpFoldLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
    // Allow retry after short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _answered = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (_puzzle == null || _isGenerating) {
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
                title: s.warpFoldTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.warpFoldInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              _buildFoldInfo(),
              const SizedBox(height: 12),
              Expanded(child: _buildOptionsGrid()),
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoldInfo() {
    final foldNames = _puzzle!.folds.map((f) {
      switch (f.direction) {
        case FoldDirection.left:
          return '\u2190';
        case FoldDirection.right:
          return '\u2192';
        case FoldDirection.top:
          return '\u2191';
        case FoldDirection.bottom:
          return '\u2193';
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.content_cut, color: SpaceTheme.cosmicPink, size: 20),
          const SizedBox(width: 8),
          Text(
            'Folds: ${foldNames.join(" ")}  |  Cuts: ${_puzzle!.cuts.length}',
            style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: _puzzle!.options.length,
        itemBuilder: (context, index) => _buildOptionCard(index),
      ),
    );
  }

  Widget _buildOptionCard(int index) {
    final isSelected = _selectedOption == index;
    final isCorrect = index == _puzzle!.correctIndex;
    final showResult = _answered;

    Color borderColor;
    if (showResult && isSelected) {
      borderColor = isCorrect ? SpaceTheme.alienGreen : SpaceTheme.rocketRed;
    } else if (isSelected) {
      borderColor = SpaceTheme.starYellow;
    } else {
      borderColor = SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value);
    }

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isSelected ? 3 : 1),
              boxShadow: isSelected
                  ? [BoxShadow(
                      color: borderColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                    )]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: CustomPaint(
                painter: _PaperGridPainter(
                  grid: _puzzle!.options[index],
                  gridSize: _puzzle!.gridSize,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              _selectedOption != null && !_answered ? _submitAnswer : null,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(S.of(context)!.warpFoldTitle),
          style: SpaceTheme.primaryButtonStyle,
        ),
      ),
    );
  }

  Widget _buildWinDialog(int score) {
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
                  const Icon(Icons.emoji_events,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.warpFoldWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(S.of(context)!.warpFoldWinDesc(score),
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
                        child: Text(S.of(context)!.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(S.of(context)!.backToMenu),
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

class _PaperGridPainter extends CustomPainter {
  final List<List<bool>> grid;
  final int gridSize;

  _PaperGridPainter({required this.grid, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / gridSize;
    final cellH = size.height / gridSize;

    final paperPaint = Paint()..color = const Color(0xFF2A2A4A);
    final holePaint = Paint()..color = SpaceTheme.cosmicPink;
    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw paper background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paperPaint);

    // Draw cells
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        if (r < grid.length && c < grid[r].length && grid[r][c]) {
          canvas.drawRect(rect, holePaint);
        }
        canvas.drawRect(rect, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGridPainter oldDelegate) => false;
}
