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
import '../services/hull_plating_logic.dart';

class HullPlatingGame extends StatefulWidget {
  final int grade;
  final int level;
  const HullPlatingGame({super.key, required this.grade, required this.level});

  @override
  State<HullPlatingGame> createState() => _HullPlatingGameState();
}

class _HullPlatingGameState extends State<HullPlatingGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  HullPlatingPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Player state
  final List<PlacedPiece> _placedPieces = [];
  int? _selectedPieceIndex; // index in puzzle!.pieces
  int _selectedRotation = 0; // how many 90-degree rotations applied
  final Set<int> _usedPieceIds = {};

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

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

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
      _placedPieces.clear();
      _usedPieceIds.clear();
      _selectedPieceIndex = null;
      _selectedRotation = 0;
      _successController.reset();
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

  PlatingPiece? get _currentPiece {
    if (_selectedPieceIndex == null || puzzle == null) return null;
    var piece = puzzle!.pieces[_selectedPieceIndex!];
    for (int i = 0; i < _selectedRotation; i++) {
      piece = piece.rotated();
    }
    return piece;
  }

  void _selectPiece(int index) {
    if (_usedPieceIds.contains(puzzle!.pieces[index].id)) return;
    setState(() {
      _selectedPieceIndex = index;
      _selectedRotation = 0;
    });
  }

  void _rotatePiece() {
    if (_selectedPieceIndex == null) return;
    setState(() {
      _selectedRotation = (_selectedRotation + 1) % 4;
    });
  }

  void _onBoardTap(int row, int col) {
    final piece = _currentPiece;
    if (piece == null || puzzle == null) return;

    // Check if tapping on an already-placed piece to remove it
    final existing = _getPlacedPieceAt(row, col);
    if (existing != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _usedPieceIds.remove(existing.pieceId);
        _placedPieces.remove(existing);
      });
      return;
    }

    // Try to place current piece with (row, col) as the anchor (first cell)
    final anchor = piece.cells.first;
    final dr = row - anchor.$1;
    final dc = col - anchor.$2;

    final absoluteCells =
        piece.cells.map((c) => (c.$1 + dr, c.$2 + dc)).toList();

    // Validate placement
    for (final cell in absoluteCells) {
      if (cell.$1 < 0 || cell.$1 >= puzzle!.rows ||
          cell.$2 < 0 || cell.$2 >= puzzle!.cols) {
        HapticFeedback.heavyImpact();
        return; // out of bounds
      }
      if (!puzzle!.board[cell.$1][cell.$2]) {
        HapticFeedback.heavyImpact();
        return; // hole
      }
      if (_getPlacedPieceAt(cell.$1, cell.$2) != null) {
        HapticFeedback.heavyImpact();
        return; // overlap
      }
    }

    // Place it
    HapticFeedback.lightImpact();
    setState(() {
      _placedPieces.add(PlacedPiece(
        pieceId: puzzle!.pieces[_selectedPieceIndex!].id,
        absoluteCells: absoluteCells,
      ));
      _usedPieceIds.add(puzzle!.pieces[_selectedPieceIndex!].id);
      _selectedPieceIndex = null;
      _selectedRotation = 0;
    });

    _checkSolution();
  }

  PlacedPiece? _getPlacedPieceAt(int row, int col) {
    for (final p in _placedPieces) {
      if (p.covers(row, col)) return p;
    }
    return null;
  }

  void _checkSolution() {
    if (puzzle == null) return;
    if (_placedPieces.length != puzzle!.pieces.length) return;

    final isValid = HullPlatingPuzzle.validatePlacement(
      _placedPieces, puzzle!.board, puzzle!.rows, puzzle!.cols,
    );

    if (isValid) _handleWin();
  }

  void _handleWin() {
    HapticFeedback.lightImpact();

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.pieces.length * 30;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'hull_plating',
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

  void _clearBoard() {
    HapticFeedback.lightImpact();
    setState(() {
      _placedPieces.clear();
      _usedPieceIds.clear();
      _selectedPieceIndex = null;
      _selectedRotation = 0;
    });
  }

  Color _colorForPieceId(int pieceId) {
    return _pieceColors[pieceId % _pieceColors.length];
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
                title: s.hullPlatingTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.hullPlatingInstructions,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      children: [
        // Board
        Expanded(
          flex: 3,
          child: Center(child: _buildBoard()),
        ),
        // Controls row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.rotate_right, color: SpaceTheme.starYellow),
                iconSize: 32,
                onPressed: _selectedPieceIndex != null ? _rotatePiece : null,
                tooltip: 'Rotate',
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: SpaceTheme.rocketRed),
                iconSize: 32,
                onPressed: _placedPieces.isNotEmpty ? _clearBoard : null,
                tooltip: 'Clear',
              ),
              const SizedBox(width: 16),
              Text(
                '${_placedPieces.length}/${puzzle!.pieces.length}',
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
        // Piece tray
        SizedBox(
          height: 100,
          child: _buildPieceTray(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBoard() {
    final cellSize = _calculateCellSize();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceTheme.starYellow.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(puzzle!.rows, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(puzzle!.cols, (c) {
              return _buildCell(r, c, cellSize);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildCell(int row, int col, double size) {
    final isActive = puzzle!.board[row][col];
    final placed = _getPlacedPieceAt(row, col);
    final isDark = HullPlatingPuzzle.isDarkCell(row, col);

    Color cellColor;
    if (!isActive) {
      cellColor = Colors.transparent;
    } else if (placed != null) {
      cellColor = _colorForPieceId(placed.pieceId).withValues(alpha: 0.8);
    } else if (isDark) {
      cellColor = SpaceTheme.deepSpace.withValues(alpha: 0.8);
    } else {
      cellColor = SpaceTheme.deepSpace.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: isActive ? () => _onBoardTap(row, col) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cellColor,
          border: Border.all(
            color: isActive
                ? SpaceTheme.nebulaPurple.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildPieceTray() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: puzzle!.pieces.length,
      itemBuilder: (context, index) {
        final piece = puzzle!.pieces[index];
        final isUsed = _usedPieceIds.contains(piece.id);
        final isSelected = _selectedPieceIndex == index;

        return GestureDetector(
          onTap: isUsed ? null : () => _selectPiece(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isUsed
                  ? Colors.white10
                  : isSelected
                      ? SpaceTheme.starYellow.withValues(alpha: 0.3)
                      : SpaceTheme.deepSpace.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? SpaceTheme.starYellow
                    : isUsed
                        ? Colors.white10
                        : SpaceTheme.nebulaPurple.withValues(alpha: 0.5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Opacity(
              opacity: isUsed ? 0.2 : 1.0,
              child: _buildMiniPiece(
                isSelected ? _currentPiece! : piece,
                _colorForPieceId(piece.id),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPiece(PlatingPiece piece, Color color) {
    const miniCellSize = 14.0;
    final h = piece.height;
    final w = piece.width;
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
                  border: filled
                      ? Border.all(color: Colors.white24, width: 0.5)
                      : null,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  double _calculateCellSize() {
    final screenWidth = MediaQuery.of(context).size.width - 64;
    final screenHeight = MediaQuery.of(context).size.height * 0.45;
    final cellW = screenWidth / puzzle!.cols;
    final cellH = screenHeight / puzzle!.rows;
    return cellW < cellH ? cellW : cellH;
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
                  const Icon(Icons.shield,
                      size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinTitle,
                      style: SpaceTheme.headlineStyle,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.hullPlatingWinDesc(bonusScore),
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
