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
import '../services/star_chart_scan_logic.dart';

class StarChartScanGame extends StatefulWidget {
  final int grade;
  final int level;
  const StarChartScanGame({super.key, required this.grade, required this.level});

  @override
  State<StarChartScanGame> createState() => _StarChartScanGameState();
}

class _StarChartScanGameState extends State<StarChartScanGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  StarChartScanPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Tracking found words and current selection
  final Set<String> _foundWords = {};
  final Set<String> _foundCells = {}; // 'row,col' keys
  List<(int, int)> _currentSelection = [];
  bool _isDragging = false;

  static const _enWords = [
    'STAR', 'MOON', 'SUN', 'ORBIT', 'COMET', 'MARS', 'VENUS', 'PLUTO',
    'NOVA', 'NEBULA', 'QUASAR', 'COSMOS', 'GALAXY', 'METEOR', 'ROCKET',
    'PLANET', 'SATURN', 'URANUS', 'EARTH', 'SOLAR',
  ];
  static const _deWords = [
    'STERN', 'MOND', 'SONNE', 'ORBIT', 'KOMET', 'MARS', 'VENUS', 'PLUTO',
    'NOVA', 'NEBEL', 'QUASAR', 'KOSMOS', 'GALAXIS', 'METEOR', 'RAKETE',
    'PLANET', 'SATURN', 'URANUS', 'ERDE', 'SOLAR',
  ];

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
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _foundWords.clear();
      _foundCells.clear();
      _currentSelection.clear();
      _successController.reset();
    });

    final locale = Localizations.localeOf(context);
    final isGerman = locale.languageCode == 'de';
    final wordPool = isGerman ? _deWords : _enWords;

    final grade = currentDifficulty!.grade;
    int gridSize;
    int wordCount;
    bool allowDiagonal;

    if (grade <= 1) {
      gridSize = 6;
      wordCount = 4;
      allowDiagonal = false;
    } else if (grade <= 2) {
      gridSize = 8;
      wordCount = 6;
      allowDiagonal = true;
    } else {
      gridSize = 10;
      wordCount = 10;
      allowDiagonal = true;
    }

    final generated = StarChartScanPuzzle.generate(
      wordPool: wordPool,
      gridSize: gridSize,
      wordCount: wordCount,
      allowDiagonal: allowDiagonal,
    );

    if (mounted) {
      setState(() {
        puzzle = generated;
        _isGenerating = false;
      });
    }
  }

  void _onPanStart(DragStartDetails details, double cellSize, Offset gridOrigin) {
    final pos = _getCellFromPosition(details.localPosition, cellSize, gridOrigin);
    if (pos != null) {
      setState(() {
        _isDragging = true;
        _currentSelection = [pos];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize, Offset gridOrigin) {
    if (!_isDragging) return;
    final pos = _getCellFromPosition(details.localPosition, cellSize, gridOrigin);
    if (pos != null && _currentSelection.isNotEmpty) {
      // Ensure the selection forms a straight line
      if (_currentSelection.length == 1 || _isValidLineExtension(pos)) {
        if (!_currentSelection.contains(pos)) {
          setState(() {
            _currentSelection.add(pos);
          });
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || _currentSelection.isEmpty) {
      setState(() {
        _isDragging = false;
        _currentSelection.clear();
      });
      return;
    }

    // Build the word from selection
    final word = _currentSelection
        .map((pos) => puzzle!.grid[pos.$1][pos.$2])
        .join();

    // Check if word matches any unfound word (forward or reverse)
    final reverseWord = word.split('').reversed.join();
    String? matchedWord;

    for (final target in puzzle!.wordsToFind) {
      if (_foundWords.contains(target)) continue;
      if (word == target || reverseWord == target) {
        matchedWord = target;
        break;
      }
    }

    if (matchedWord != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _foundWords.add(matchedWord!);
        for (final pos in _currentSelection) {
          _foundCells.add('${pos.$1},${pos.$2}');
        }
      });

      // Check for win
      if (_foundWords.length == puzzle!.wordsToFind.length) {
        _handleWin();
      }
    }

    setState(() {
      _isDragging = false;
      _currentSelection.clear();
    });
  }

  bool _isValidLineExtension((int, int) newPos) {
    if (_currentSelection.length < 2) return true;

    final first = _currentSelection.first;
    final second = _currentSelection[1];
    final dr = second.$1 - first.$1;
    final dc = second.$2 - first.$2;

    // Check that the new position continues the same direction
    final last = _currentSelection.last;
    final newDr = newPos.$1 - last.$1;
    final newDc = newPos.$2 - last.$2;

    return newDr == dr && newDc == dc;
  }

  (int, int)? _getCellFromPosition(Offset position, double cellSize, Offset gridOrigin) {
    final relX = position.dx - gridOrigin.dx;
    final relY = position.dy - gridOrigin.dy;

    final col = (relX / cellSize).floor();
    final row = (relY / cellSize).floor();

    if (row >= 0 &&
        row < puzzle!.gridSize &&
        col >= 0 &&
        col < puzzle!.gridSize) {
      return (row, col);
    }
    return null;
  }

  void _handleWin() {
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int wordBonus = puzzle!.wordsToFind.length * 30;
    int totalScore = baseScore + levelBonus + wordBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'star_chart_scan',
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
                title: s.starChartScanTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.starChartScanInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(child: _buildGameArea()),
              _buildWordList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = math.min(constraints.maxWidth - 32, constraints.maxHeight - 16);
        final cellSize = maxSize / puzzle!.gridSize;
        final gridWidth = cellSize * puzzle!.gridSize;
        final gridHeight = cellSize * puzzle!.gridSize;

        return Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: gridWidth + 8,
                height: gridHeight + 8,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SpaceTheme.starYellow
                        .withValues(alpha: _glowAnimation.value * 0.6),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      SpaceTheme.deepSpace.withValues(alpha: 0.8),
                      SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onPanStart: (d) =>
                      _onPanStart(d, cellSize, Offset.zero),
                  onPanUpdate: (d) =>
                      _onPanUpdate(d, cellSize, Offset.zero),
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    size: Size(gridWidth, gridHeight),
                    painter: _GridPainter(
                      puzzle: puzzle!,
                      cellSize: cellSize,
                      foundCells: _foundCells,
                      currentSelection: _currentSelection,
                      glowValue: _glowAnimation.value,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWordList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: puzzle!.wordsToFind.map((word) {
          final found = _foundWords.contains(word);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: found
                  ? SpaceTheme.alienGreen.withValues(alpha: 0.3)
                  : SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: found ? SpaceTheme.alienGreen : Colors.grey.shade600,
              ),
            ),
            child: Text(
              word,
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12,
                color: found ? SpaceTheme.alienGreen : Colors.white70,
                decoration: found ? TextDecoration.lineThrough : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWinDialog(int bonusScore) {
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
                  const Icon(Icons.travel_explore,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.starChartScanWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(
                    s.starChartScanWinDesc(
                        puzzle!.mysteryLetter, bonusScore),
                    style: SpaceTheme.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
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

class _GridPainter extends CustomPainter {
  final StarChartScanPuzzle puzzle;
  final double cellSize;
  final Set<String> foundCells;
  final List<(int, int)> currentSelection;
  final double glowValue;

  _GridPainter({
    required this.puzzle,
    required this.cellSize,
    required this.foundCells,
    required this.currentSelection,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selectionSet = <String>{};
    for (final pos in currentSelection) {
      selectionSet.add('${pos.$1},${pos.$2}');
    }

    for (int r = 0; r < puzzle.gridSize; r++) {
      for (int c = 0; c < puzzle.gridSize; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize,
          r * cellSize,
          cellSize,
          cellSize,
        );

        final key = '$r,$c';
        final isFound = foundCells.contains(key);
        final isSelected = selectionSet.contains(key);

        // Draw cell background
        final bgPaint = Paint();
        if (isFound) {
          bgPaint.color = const Color(0xFF06FFA5).withValues(alpha: 0.25);
        } else if (isSelected) {
          bgPaint.color = const Color(0xFFFFD700).withValues(alpha: 0.35);
        } else {
          bgPaint.color = const Color(0xFF1A1A2E).withValues(alpha: 0.5);
        }
        canvas.drawRect(rect, bgPaint);

        // Draw cell border
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.grey.withValues(alpha: 0.3)
          ..strokeWidth = 0.5;
        canvas.drawRect(rect, borderPaint);

        // Draw letter
        final textPainter = TextPainter(
          text: TextSpan(
            text: puzzle.grid[r][c],
            style: TextStyle(
              color: isFound
                  ? const Color(0xFF06FFA5)
                  : isSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.9),
              fontSize: cellSize * 0.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.foundCells != foundCells ||
        oldDelegate.currentSelection != currentSelection ||
        oldDelegate.glowValue != glowValue;
  }
}
