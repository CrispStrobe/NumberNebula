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
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;

  StarChartScanPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Tracking found words and current selection
  final Set<String> _foundWords = {};
  final Set<String> _foundCells = {}; // 'row,col' keys
  // Track which cells belong to which found word (for colored highlighting)
  final Map<String, int> _cellWordIndex = {};
  List<(int, int)> _currentSelection = [];
  bool _isDragging = false;

  static const _highlightColors = [
    Color(0xFF06FFA5), // alien green
    Color(0xFFFF69B4), // cosmic pink
    Color(0xFF6B48FF), // purple
    Color(0xFFFFD700), // gold
    Color(0xFFFF6B35), // orange
    Color(0xFF00BCD4), // cyan
    Color(0xFFE63946), // red
    Color(0xFF8BC34A), // light green
    Color(0xFF9C27B0), // deep purple
    Color(0xFFFF9800), // amber
  ];

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

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController, curve: Curves.elasticOut,
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
    _revealController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _foundWords.clear();
      _foundCells.clear();
      _cellWordIndex.clear();
      _currentSelection.clear();
      _successController.reset();
      _revealController.reset();
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

    final word = _currentSelection
        .map((pos) => puzzle!.grid[pos.$1][pos.$2])
        .join();

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
      final wordIdx = _foundWords.length;
      setState(() {
        _foundWords.add(matchedWord!);
        for (final pos in _currentSelection) {
          final key = '${pos.$1},${pos.$2}';
          _foundCells.add(key);
          _cellWordIndex[key] = wordIdx;
        }
      });

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
    _revealController.forward(from: 0.0);

    if (mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _buildWinDialog(totalScore),
          );
        }
      });
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 500;
              final isWide = constraints.maxWidth > 700;

              return Column(
                children: [
                  _buildHeader(s, isCompact),
                  Expanded(
                    child: isWide
                        ? _buildWideLayout()
                        : _buildCompactLayout(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(S s, bool isCompact) {
    if (!isCompact) {
      return Column(
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
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              s.starChartScanTitle,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${_foundWords.length}/${puzzle?.wordsToFind.length ?? 0}',
              style: const TextStyle(
                color: SpaceTheme.alienGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: _buildGameArea(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildWordListPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Expanded(child: _buildGameArea()),
        _buildWordList(),
      ],
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use as much space as possible
        final maxDim = math.min(constraints.maxWidth - 16, constraints.maxHeight - 16);
        final cellSize = maxDim / puzzle!.gridSize;
        final gridSide = cellSize * puzzle!.gridSize;

        return Center(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: gridSide + 12,
                height: gridSide + 12,
                padding: const EdgeInsets.all(6),
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
                    size: Size(gridSide, gridSide),
                    painter: _GridPainter(
                      puzzle: puzzle!,
                      cellSize: cellSize,
                      foundCells: _foundCells,
                      cellWordIndex: _cellWordIndex,
                      highlightColors: _highlightColors,
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

  Widget _buildWordListPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Words',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: puzzle!.wordsToFind.asMap().entries.map((entry) {
                final word = entry.value;
                final found = _foundWords.contains(word);
                final color = found
                    ? _highlightColors[_getWordColorIndex(word) % _highlightColors.length]
                    : Colors.white70;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        found ? Icons.check_circle : Icons.circle_outlined,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          word,
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 14,
                            color: color,
                            decoration: found ? TextDecoration.lineThrough : null,
                            decorationColor: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_foundWords.length}/${puzzle!.wordsToFind.length}',
              style: const TextStyle(
                color: SpaceTheme.alienGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getWordColorIndex(String word) {
    final idx = puzzle!.wordsToFind.indexOf(word);
    return idx >= 0 ? idx : 0;
  }

  Widget _buildWordList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: puzzle!.wordsToFind.asMap().entries.map((entry) {
          final word = entry.value;
          final found = _foundWords.contains(word);
          final color = found
              ? _highlightColors[_getWordColorIndex(word) % _highlightColors.length]
              : null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: found
                  ? color!.withValues(alpha: 0.25)
                  : SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: found ? color! : Colors.grey.shade600,
              ),
            ),
            child: Text(
              word,
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 12,
                color: found ? color : Colors.white70,
                decoration: found ? TextDecoration.lineThrough : null,
                decorationColor: found ? color : null,
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
                  // Mystery letter reveal with animation
                  AnimatedBuilder(
                    animation: _revealAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.5 + _revealAnimation.value * 0.5,
                        child: Opacity(
                          opacity: _revealAnimation.value.clamp(0.0, 1.0),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  SpaceTheme.starYellow.withValues(alpha: 0.8),
                                  SpaceTheme.planetOrange.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                              border: Border.all(
                                color: SpaceTheme.starYellow,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: SpaceTheme.starYellow.withValues(
                                    alpha: _revealAnimation.value * 0.6,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                puzzle!.mysteryLetter,
                                style: SpaceTheme.headlineStyle.copyWith(
                                  fontSize: 36,
                                  color: Colors.white,
                                  shadows: [
                                    const Shadow(
                                      color: SpaceTheme.starYellow,
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
  final Map<String, int> cellWordIndex;
  final List<Color> highlightColors;
  final List<(int, int)> currentSelection;
  final double glowValue;

  _GridPainter({
    required this.puzzle,
    required this.cellSize,
    required this.foundCells,
    required this.cellWordIndex,
    required this.highlightColors,
    required this.currentSelection,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selectionSet = <String>{};
    for (final pos in currentSelection) {
      selectionSet.add('${pos.$1},${pos.$2}');
    }

    // Ensure minimum font size of 20, scale up with cell
    final fontSize = math.max(20.0, cellSize * 0.5);

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
        final wordIdx = cellWordIndex[key];

        // Draw cell background
        final bgPaint = Paint();
        if (isFound && wordIdx != null) {
          final highlightColor = highlightColors[wordIdx % highlightColors.length];
          bgPaint.color = highlightColor.withValues(alpha: 0.3);
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

        // Determine letter color
        Color letterColor;
        if (isFound && wordIdx != null) {
          letterColor = highlightColors[wordIdx % highlightColors.length];
        } else if (isSelected) {
          letterColor = const Color(0xFFFFD700);
        } else {
          letterColor = Colors.white.withValues(alpha: 0.9);
        }

        // Draw letter
        final textPainter = TextPainter(
          text: TextSpan(
            text: puzzle.grid[r][c],
            style: TextStyle(
              color: letterColor,
              fontSize: fontSize,
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

    // Draw a colored stripe across found word cells
    if (foundCells.isNotEmpty) {
      _drawFoundWordStripes(canvas);
    }

    // Draw selection line
    if (currentSelection.length >= 2) {
      _drawSelectionLine(canvas);
    }
  }

  void _drawFoundWordStripes(Canvas canvas) {
    // Group cells by word index
    final wordGroups = <int, List<String>>{};
    for (final entry in cellWordIndex.entries) {
      wordGroups.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    for (final entry in wordGroups.entries) {
      final idx = entry.key;
      final cells = entry.value;
      if (cells.length < 2) continue;

      final color = highlightColors[idx % highlightColors.length];
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = cellSize * 0.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Parse first and last cell to draw a line
      final firstParts = cells.first.split(',');
      final lastParts = cells.last.split(',');
      final startR = int.parse(firstParts[0]);
      final startC = int.parse(firstParts[1]);
      final endR = int.parse(lastParts[0]);
      final endC = int.parse(lastParts[1]);

      canvas.drawLine(
        Offset((startC + 0.5) * cellSize, (startR + 0.5) * cellSize),
        Offset((endC + 0.5) * cellSize, (endR + 0.5) * cellSize),
        linePaint,
      );
    }
  }

  void _drawSelectionLine(Canvas canvas) {
    final first = currentSelection.first;
    final last = currentSelection.last;

    final linePaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.3)
      ..strokeWidth = cellSize * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset((first.$2 + 0.5) * cellSize, (first.$1 + 0.5) * cellSize),
      Offset((last.$2 + 0.5) * cellSize, (last.$1 + 0.5) * cellSize),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.foundCells != foundCells ||
        oldDelegate.currentSelection != currentSelection ||
        oldDelegate.glowValue != glowValue ||
        oldDelegate.cellWordIndex != cellWordIndex;
  }
}
