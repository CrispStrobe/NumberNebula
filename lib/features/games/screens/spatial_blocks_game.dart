// lib/features/games/screens/spatial_blocks_game.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../../../shared/utils/app_utilities.dart'; // FIX: Added import for SpaceDialog

// FIX: Moved data models above the widget class to resolve definition order errors.
class PuzzlePiece {
  final int id;
  final List<List<int>> shape; // 0 for empty, 1 for block
  final Color color;
  PuzzlePiece({required this.id, required this.shape, required this.color});

  List<int> getShapeIndices(int gridWidth) {
    final indices = <int>[];
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          indices.add(r * gridWidth + c);
        }
      }
    }
    return indices;
  }
}

class PuzzleDefinition {
  final int width;
  final int height;
  final List<PuzzlePiece> pieces;
  PuzzleDefinition({required this.width, required this.height, required this.pieces});

  static PuzzleDefinition generate(Map<String, int> args) {
    final grade = args['grade']!;
    final random = math.Random();
    
    // Puzzles defined by grade level
    if (grade < 2) { // Grade 1 (e.g., School Year 3)
      return PuzzleDefinition(width: 2, height: 2, pieces: [
        PuzzlePiece(id: 1, shape: [[1,1]], color: SpaceTheme.planetOrange),
        PuzzlePiece(id: 2, shape: [[1,1]], color: SpaceTheme.alienGreen),
      ]..shuffle(random));
    } else if (grade < 3) { // Grade 2
      return PuzzleDefinition(width: 3, height: 2, pieces: [
        PuzzlePiece(id: 1, shape: [[1,1,1]], color: SpaceTheme.cosmicPink),
        PuzzlePiece(id: 2, shape: [[1,1],[0,1]], color: SpaceTheme.starYellow),
      ]..shuffle(random));
    } else { // Grade 3 & 4
      return PuzzleDefinition(width: 4, height: 3, pieces: [
          PuzzlePiece(id: 1, shape: [[1,1],[1,1]], color: SpaceTheme.rocketRed), // Square
          PuzzlePiece(id: 2, shape: [[1,1,1,1]], color: SpaceTheme.alienGreen), // Line
          PuzzlePiece(id: 3, shape: [[0,1,0],[1,1,1]], color: SpaceTheme.starYellow), // T-shape
          PuzzlePiece(id: 4, shape: [[1,1,0],[0,1,1]], color: SpaceTheme.cosmicPink), // S-shape
      ]..shuffle(random));
    }
  }
}

class SpatialBlocksGame extends StatefulWidget {
  final int grade;
  final int level;

  const SpatialBlocksGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<SpatialBlocksGame> createState() => _SpatialBlocksGameState();
}

class _SpatialBlocksGameState extends State<SpatialBlocksGame> with TickerProviderStateMixin {
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _warpController;

  PuzzleDefinition? currentPuzzle;
  Map<int, PuzzlePiece> placedPieces = {}; // Key: gridIndex, Value: piece
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
    _warpController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _generatePuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    _warpController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    setState(() => _isGenerating = true);
    try {
      final puzzle = await compute(PuzzleDefinition.generate, {'grade': widget.grade, 'level': widget.level});
      if (mounted) {
        setState(() {
          currentPuzzle = puzzle;
          placedPieces.clear();
          _isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint("Error generating puzzle: $e");
      // Handle error, maybe show a dialog
    }
  }

  void _placePiece(PuzzlePiece piece, int gridIndex) {
    if (!mounted || currentPuzzle == null) return;
    final pieceShape = piece.getShapeIndices(currentPuzzle!.width);
    final int gridWidth = currentPuzzle!.width;

    // Check for out-of-bounds and collision
    for (int index in pieceShape) {
        int targetIndex = gridIndex + index;
        if (placedPieces.containsKey(targetIndex)) { // Collision
            _showIncorrectPlacement();
            return;
        }
        // Check for wrapping
        int startCol = gridIndex % gridWidth;
        int currentPieceCol = (index % 4); // Based on piece shape's local grid
        if (startCol + currentPieceCol >= gridWidth) {
            _showIncorrectPlacement();
            return;
        }
    }

    setState(() {
      for (int index in pieceShape) {
        placedPieces[gridIndex + index] = piece;
      }
    });
    _checkIfComplete();
  }
  
  void _removePiece(PuzzlePiece piece) {
    setState(() {
      placedPieces.removeWhere((key, value) => value.id == piece.id);
    });
  }

  void _checkIfComplete() {
    if (currentPuzzle == null) return;
    if (placedPieces.length == currentPuzzle!.width * currentPuzzle!.height) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    _warpController.forward();
    int baseScore = 200 * widget.grade;
    context.read<GameProvider>().addScore(baseScore);
    _successController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(baseScore),
    );
  }

  void _showIncorrectPlacement() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.spatialBlocksFail),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(S.of(context)!.loadingAdventure, style: SpaceTheme.bodyStyle)])));
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(title: S.of(context)!.spatialBlocksGameTitle, level: widget.level, onBack: () => Navigator.of(context).pop()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(S.of(context)!.spatialBlocksInstructions, style: SpaceTheme.bodyStyle, textAlign: TextAlign.center)),
              Expanded(child: LayoutBuilder(builder: (context, constraints) => _buildGameLayout(constraints))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameLayout(BoxConstraints constraints) {
    bool isWide = constraints.maxWidth > 650;
    return isWide ? _buildWideLayout(constraints) : _buildTallLayout(constraints);
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: _buildPuzzleGrid(constraints)),
          const SizedBox(width: 24),
          Expanded(flex: 1, child: _buildPieceTray(constraints)),
        ],
      ),
    );
  }

  Widget _buildTallLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            _buildPuzzleGrid(constraints),
            const SizedBox(height: 24),
            _buildPieceTray(constraints),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleGrid(BoxConstraints constraints) {
    final puzzle = currentPuzzle!;
    final totalSize = math.min(constraints.maxWidth * (constraints.maxWidth > 650 ? 0.6 : 0.9), constraints.maxHeight * 0.8);
    final cellSize = math.min(totalSize / puzzle.width, totalSize / puzzle.height);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.of(context)!.spatialBlocksWorkspace, style: SpaceTheme.titleStyle),
        const SizedBox(height: 12),
        Container(
          width: cellSize * puzzle.width,
          height: cellSize * puzzle.height,
          decoration: BoxDecoration(color: SpaceTheme.deepSpace.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: puzzle.width),
            itemCount: puzzle.width * puzzle.height,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return DragTarget<PuzzlePiece>(
                builder: (context, candidateData, rejectedData) {
                  if (placedPieces.containsKey(index)) {
                    final piece = placedPieces[index]!;
                    return GestureDetector(
                      onTap: () => _removePiece(piece),
                      child: BlockPainter(piece: piece, cellSize: cellSize),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty ? SpaceTheme.alienGreen.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                      border: Border.all(color: SpaceTheme.nebulaPurple, width: 0.5),
                    ),
                  );
                },
                onWillAccept: (data) => !placedPieces.containsKey(index),
                onAccept: (piece) => _placePiece(piece, index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPieceTray(BoxConstraints constraints) {
    final unplacedPieces = currentPuzzle!.pieces.where((p) => !placedPieces.values.any((placed) => placed.id == p.id)).toList();
    final pieceSize = math.min(constraints.maxWidth * 0.2, 80.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.of(context)!.spatialBlocksPieces, style: SpaceTheme.titleStyle),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: SpaceTheme.cardDecoration.copyWith(border: Border.all(color: SpaceTheme.nebulaPurple)),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: unplacedPieces.map((piece) {
              return Draggable<PuzzlePiece>(
                data: piece,
                feedback: BlockPainter(piece: piece, cellSize: pieceSize),
                childWhenDragging: Opacity(opacity: 0.3, child: BlockPainter(piece: piece, cellSize: pieceSize)),
                child: BlockPainter(piece: piece, cellSize: pieceSize),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessDialog(int bonusScore) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: SpaceDialog(
            title: S.of(context)!.spatialBlocksWinTitle,
            content: S.of(context)!.spatialBlocksWinDesc(bonusScore),
            actions: [
              ElevatedButton(onPressed: () {Navigator.of(context).pop(); _generatePuzzle();}, style: SpaceTheme.secondaryButtonStyle, child: Text(S.of(context)!.nextLevel)),
              ElevatedButton(onPressed: () {Navigator.of(context).pop(); Navigator.of(context).pop();}, style: SpaceTheme.primaryButtonStyle, child: Text(S.of(context)!.backToMenu)),
            ],
          ),
        );
      },
    );
  }
}

// Custom Painters for Visuals
class BlockPainter extends StatelessWidget {
  final PuzzlePiece piece;
  final double cellSize;
  const BlockPainter({super.key, required this.piece, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    int maxCols = 0;
    for (var row in piece.shape) {
      if (row.length > maxCols) maxCols = row.length;
    }
    final width = maxCols * cellSize;
    final height = piece.shape.length * cellSize;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: () {
            final List<Widget> blockWidgets = [];
            for (int r = 0; r < piece.shape.length; r++) {
                for (int c = 0; c < piece.shape[r].length; c++) {
                    if (piece.shape[r][c] == 1) {
                        blockWidgets.add(Positioned(
                            left: c * cellSize,
                            top: r * cellSize,
                            child: CustomPaint(
                                size: Size(cellSize, cellSize),
                                painter: IsometricCubePainter(color: piece.color),
                            ),
                        ));
                    }
                }
            }
            return blockWidgets;
        }(),
      ),
    );
  }
}

class IsometricCubePainter extends CustomPainter {
  final Color color;
  IsometricCubePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final topPaint = Paint()..color = color;
    final leftPaint = Paint()..color = Color.lerp(color, Colors.black, 0.25)!;
    final rightPaint = Paint()..color = Color.lerp(color, Colors.black, 0.5)!;

    final pathTop = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(0, size.height * 0.25)
      ..close();

    final pathLeft = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.75)
      ..close();

    final pathRight = Path()
      ..moveTo(size.width, size.height * 0.25)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width, size.height * 0.75)
      ..close();

    canvas.drawPath(pathTop, topPaint);
    canvas.drawPath(pathLeft, leftPaint);
    canvas.drawPath(pathRight, rightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}