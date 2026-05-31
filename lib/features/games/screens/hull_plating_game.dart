import 'dart:math' as math;
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
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _dropController;
  late Animation<double> _dropAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  HullPlatingPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // Player state
  final List<PlacedPiece> _placedPieces = [];
  int _selectedRotation = 0;
  final Set<int> _usedPieceIds = {};
  String _lastDroppedCell = '';

  // Ghost preview state
  int? _hoveringPieceIndex;
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

    _dropController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _dropAnimation = CurvedAnimation(parent: _dropController, curve: Curves.elasticOut);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _placedPieces.clear();
      _usedPieceIds.clear();
      _selectedRotation = 0;
      _hoveringPieceIndex = null;
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

  PlatingPiece _getRotatedPiece(int index) {
    var piece = puzzle!.pieces[index];
    for (int i = 0; i < _selectedRotation; i++) {
      piece = piece.rotated();
    }
    return piece;
  }

  void _rotatePiece() {
    setState(() {
      _selectedRotation = (_selectedRotation + 1) % 4;
    });
  }

  List<(int, int)>? _computePlacement(PlatingPiece piece, int row, int col) {
    final anchor = piece.cells.first;
    final dr = row - anchor.$1;
    final dc = col - anchor.$2;

    final absoluteCells =
        piece.cells.map((c) => (c.$1 + dr, c.$2 + dc)).toList();

    for (final cell in absoluteCells) {
      if (cell.$1 < 0 || cell.$1 >= puzzle!.rows ||
          cell.$2 < 0 || cell.$2 >= puzzle!.cols) {
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

  void _placePieceAt(int pieceIndex, int row, int col) {
    final piece = _getRotatedPiece(pieceIndex);
    final placement = _computePlacement(piece, row, col);
    if (placement == null) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Piece doesn\'t fit here! Try rotating or a different position.'),
            backgroundColor: SpaceTheme.rocketRed,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _placedPieces.add(PlacedPiece(
        pieceId: puzzle!.pieces[pieceIndex].id,
        absoluteCells: placement,
      ));
      _usedPieceIds.add(puzzle!.pieces[pieceIndex].id);
      _lastDroppedCell = 'r${row}c$col';
      _dropController.forward(from: 0.0);
      _selectedRotation = 0;
      _hoveringPieceIndex = null;
    });

    _checkSolution();
  }

  PlacedPiece? _getPlacedPieceAt(int row, int col) {
    for (final p in _placedPieces) {
      if (p.covers(row, col)) return p;
    }
    return null;
  }

  void _removePlacedPiece(int row, int col) {
    final existing = _getPlacedPieceAt(row, col);
    if (existing == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _usedPieceIds.remove(existing.pieceId);
      _placedPieces.remove(existing);
    });
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
      _selectedRotation = 0;
    });
  }

  Color _colorForPieceId(int pieceId) {
    return _pieceColors[pieceId % _pieceColors.length];
  }

  Set<String>? _getGhostCells() {
    if (_hoveringPieceIndex == null || _hoverRow == null || _hoverCol == null) {
      return null;
    }
    final piece = _getRotatedPiece(_hoveringPieceIndex!);
    final placement = _computePlacement(piece, _hoverRow!, _hoverCol!);
    if (placement == null) return null;
    return placement.map((c) => 'r${c.$1}c${c.$2}').toSet();
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
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: SpaceTheme.starYellow, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.hullPlatingInstructions,
                      style: SpaceTheme.bodyStyle.copyWith(fontSize: 11))),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxCellW = (constraints.maxWidth - 32) / puzzle!.cols;
                final maxCellH = (constraints.maxHeight - 32) / puzzle!.rows;
                final cellSize = math.min(maxCellW, maxCellH).clamp(30.0, 80.0);
                return _buildBoard(cellSize);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoard(double cellSize) {
    final ghostCells = _getGhostCells();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(puzzle!.rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(puzzle!.cols, (c) {
            return _buildCell(r, c, cellSize, ghostCells);
          }),
        );
      }),
    );
  }

  Widget _buildCell(int row, int col, double size, Set<String>? ghostCells) {
    final isActive = puzzle!.board[row][col];
    final placed = _getPlacedPieceAt(row, col);
    final isDark = HullPlatingPuzzle.isDarkCell(row, col);
    final cellId = 'r${row}c$col';
    final isGhost = ghostCells?.contains(cellId) ?? false;
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
        onTap: () => _removePlacedPiece(row, col),
        child: cellWidget,
      );
    }

    // Empty active cell -- this is a DragTarget
    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isGhost
                ? SpaceTheme.starYellow.withValues(alpha: 0.3)
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
                ? [BoxShadow(
                    color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
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
        // Update ghost preview
        setState(() {
          _hoveringPieceIndex = details.data;
          _hoverRow = row;
          _hoverCol = col;
        });
        return true;
      },
      onLeave: (_) {
        setState(() {
          _hoveringPieceIndex = null;
          _hoverRow = null;
          _hoverCol = null;
        });
      },
      onAcceptWithDetails: (details) {
        _placePieceAt(details.data, row, col);
      },
    );
  }

  Widget _buildControlsAndTray(bool isCompact) {
    return Column(
      children: [
        // Controls row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.rotate_right, size: 24),
                label: Text(isCompact ? '' : 'Rotate'),
                onPressed: _rotatePiece,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceTheme.starYellow.withValues(alpha: 0.3),
                  foregroundColor: SpaceTheme.starYellow,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: SpaceTheme.rocketRed),
                iconSize: 28,
                onPressed: _placedPieces.isNotEmpty ? _clearBoard : null,
                tooltip: 'Clear',
              ),
              const SizedBox(width: 12),
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
    final sorted = piece.cells.toList()..sort((a, b) {
      final r = a.$1.compareTo(b.$1);
      return r != 0 ? r : a.$2.compareTo(b.$2);
    });
    return sorted.map((c) => '${c.$1},${c.$2}').join(';');
  }

  Widget _buildPieceTray() {
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
        child: Text('All pieces placed!',
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
          child: Draggable<int>(
            data: firstIdx,
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
                    top: 2, right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('×$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieceTrayCard(PlatingPiece piece, Color color, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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

  Widget _buildMiniPiece(PlatingPiece piece, Color color, double targetMinCellSize) {
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
