import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/puzzle_image_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';

// Main Game Widget
class PuzzleMathGame extends StatefulWidget {
  final int grade;
  final int level;

  const PuzzleMathGame({super.key, required this.grade, required this.level});

  @override
  State<PuzzleMathGame> createState() => _PuzzleMathGameState();
}

class _PuzzleMathGameState extends State<PuzzleMathGame> {
  List<PuzzlePieceData> pieces = [];
  Map<int, int> placedPieces = {}; // Map slotId -> pieceId
  late int columns;
  late int rows;
  String? currentPuzzleImage;
  Timer? _timer;
  int _timeLeft = 120;
  Map<String, JigsawSide> _edgeShapes = {}; // Stores the shape of each interior edge

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    final gameProvider = context.read<GameProvider>();
    currentPuzzleImage = PuzzleImageService.instance.getImageForLevel(widget.level);
    _generatePuzzle();
    if (gameProvider.puzzleTimerEnabled) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timeLeft = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (mounted) {
          _showGameOverDialog("Time's up, space cadet!");
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generatePuzzle() {
    // Difficulty based on grade: 3rd grade = 2x2, 4th = 2x3, 5th = 3x3, 6th = 3x4
    final difficulty = widget.grade;
    if (difficulty <= 3) {
      columns = 2; rows = 2;
    } else if (difficulty == 4) {
      columns = 2; rows = 3;
    } else if (difficulty == 5) {
      columns = 3; rows = 3;
    } else {
      columns = 3; rows = 4;
    }

    final pieceCount = columns * rows;
    _generateEdgeShapes(); // Generate the interlocking shapes first

    final random = math.Random();
    final problems = <MathProblem>{};
    while (problems.length < pieceCount) {
      problems.add(MathProblem.random(widget.grade, difficulty: difficulty));
    }

    final problemList = problems.toList();
    final pieceData = <PuzzlePieceData>[];
    for (int i = 0; i < pieceCount; i++) {
      pieceData.add(PuzzlePieceData(
        id: i,
        problem: problemList[i].expression,
        answer: problemList[i].answer,
        row: i ~/ columns,
        col: i % columns,
        rotation: 0, // Initial rotation
      ));
    }

    setState(() {
      pieces = pieceData..shuffle(random);
      placedPieces.clear();
    });
  }

  void _generateEdgeShapes() {
    _edgeShapes.clear();
    final random = math.Random();
    
    // Horizontal edges (between columns)
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns - 1; c++) {
        _edgeShapes['h-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
      }
    }
    
    // Vertical edges (between rows)
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < columns; c++) {
        _edgeShapes['v-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
      }
    }
  }

  void _onToggleTimer(bool isEnabled) {
    context.read<GameProvider>().setPuzzleTimer(isEnabled);
    if (isEnabled) {
      _startTimer();
    } else {
      _timer?.cancel();
      setState(() {});
    }
  }

  void _rotatePiece(int pieceId) {
    setState(() {
      final piece = pieces.firstWhere((p) => p.id == pieceId);
      piece.rotation = (piece.rotation + 90) % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    if (currentPuzzleImage == null) {
      return Scaffold(
          body: Center(
              child: Text("No constellation images found in assets/images/",
                  style: SpaceTheme.bodyStyle)));
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: S.of(context)!.puzzleMath,
                level: widget.level,
                timeLeft: gameProvider.puzzleTimerEnabled ? _timeLeft : null,
                onBack: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context)!.puzzleMathInstructions,
                        textAlign: TextAlign.center,
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                      ),
                    ),
                    Row(
                      children: [
                        Text(S.of(context)!.timer, style: SpaceTheme.bodyStyle.copyWith(color: Colors.white)),
                        Switch(
                          value: gameProvider.puzzleTimerEnabled,
                          onChanged: _onToggleTimer,
                          activeColor: SpaceTheme.alienGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: _buildPuzzleBoard(constraints)),
                        Expanded(flex: 2, child: _buildPieceTray(constraints)),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Size _calculatePieceSize(BoxConstraints constraints) {
    final boardConstraints = BoxConstraints(
        maxWidth: constraints.maxWidth * 0.6, // Make pieces smaller to accommodate knobs
        maxHeight: constraints.maxHeight * 0.85,
    );

    double pieceWidth = (boardConstraints.maxWidth / columns);
    double pieceHeight = pieceWidth;

    if (pieceHeight * rows > boardConstraints.maxHeight) {
        pieceHeight = (boardConstraints.maxHeight / rows);
        pieceWidth = pieceHeight;
    }
    
    return Size(pieceWidth, pieceHeight);
    }

  Widget _buildPuzzleBoard(BoxConstraints constraints) {
  final pieceSize = _calculatePieceSize(constraints);
  final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
  
  // Board size needs to account for knob extensions  
  final boardWidth = (pieceSize.width * columns) + (bumpSize * 2);
  final boardHeight = (pieceSize.height * rows) + (bumpSize * 2);

  return Center(
    child: Container(
      width: boardWidth,
      height: boardHeight,
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.8), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(bumpSize),
        child: Stack(
          clipBehavior: Clip.none, // CRITICAL: Allow knobs to extend beyond bounds
          children: List.generate(rows * columns, (index) {
            final row = index ~/ columns;
            final col = index % columns;
            final slotData = pieces.firstWhere((p) => p.row == row && p.col == col);
            final isPlaced = placedPieces.containsKey(slotData.id);

            return Positioned(
              left: (col * pieceSize.width),
              top: (row * pieceSize.height),
              child: DragTarget<int>(
                builder: (context, candidateData, rejectedData) {
                  return PuzzleSlotWidget(
                    data: slotData,
                    pieceSize: pieceSize,
                    columns: columns,
                    rows: rows,
                    edgeShapes: _edgeShapes,
                    isPieceOver: candidateData.isNotEmpty,
                    imagePath: currentPuzzleImage, // Pass image for background
                    child: isPlaced
                        ? PuzzlePieceWidget(
                            imagePath: currentPuzzleImage!,
                            data: pieces.firstWhere((p) => p.id == placedPieces[slotData.id]),
                            pieceSize: pieceSize,
                            columns: columns,
                            rows: rows,
                            edgeShapes: _edgeShapes,
                            isPlaced: true,
                            onRotate: () {},
                          )
                        : null,
                  );
                },
                onWillAccept: (pieceId) => !isPlaced,
                onAccept: (pieceId) {
                  final pieceData = pieces.firstWhere((p) => p.id == pieceId);
                  if (pieceData.answer == slotData.answer && pieceData.rotation == 0) {
                    setState(() => placedPieces[slotData.id] = pieceId);
                    context.read<GameProvider>().addScore(50);
                    if (placedPieces.length == pieces.length) {
                      _showWinDialog();
                    }
                  } else {
                    _showIncorrectPlacement();
                  }
                },
              ),
            );
          }),
        ),
      ),
    ),
  );
}

  Widget _buildPieceTray(BoxConstraints constraints) {
    final pieceSize = _calculatePieceSize(constraints);
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.alienGreen.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.constellationPieces,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: pieceSize.width * 0.8,
                childAspectRatio: 1.0,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: pieces.length,
              itemBuilder: (context, index) {
                final pieceData = pieces[index];
                if (placedPieces.values.contains(pieceData.id)) {
                  return Container(); // Piece already placed
                }
                return Draggable<int>(
                  data: pieceData.id,
                  feedback: Material(
                    color: Colors.transparent,
                    child: PuzzlePieceWidget(
                      imagePath: currentPuzzleImage!,
                      data: pieceData,
                      pieceSize: Size(pieceSize.width * 0.8, pieceSize.height * 0.8),
                      columns: columns,
                      rows: rows,
                      edgeShapes: _edgeShapes,
                      onRotate: () => _rotatePiece(pieceData.id),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: PuzzlePieceWidget(
                      imagePath: currentPuzzleImage!,
                      data: pieceData,
                      pieceSize: Size(pieceSize.width * 0.8, pieceSize.height * 0.8),
                      columns: columns,
                      rows: rows,
                      edgeShapes: _edgeShapes,
                      onRotate: () => _rotatePiece(pieceData.id),
                    ),
                  ),
                  child: PuzzlePieceWidget(
                    imagePath: currentPuzzleImage!,
                    data: pieceData,
                    pieceSize: Size(pieceSize.width * 0.8, pieceSize.height * 0.8),
                    columns: columns,
                    rows: rows,
                    edgeShapes: _edgeShapes,
                    onRotate: () => _rotatePiece(pieceData.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showIncorrectPlacement() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.puzzleMathIncorrect),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWinDialog() {
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    int bonus = 0;
    String message = S.of(context)!.puzzleMathWin;
    if (gameProvider.puzzleTimerEnabled) {
      bonus = (_timeLeft * 2);
      message = "Constellation restored!\nTime Bonus: $bonus points!";
    }
    context.read<GameProvider>().addScore(100 + bonus);
    
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SpaceDialog(
            title: S.of(context)!.excellent,
            content: message,
            onNext: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            }));
  }

  void _showGameOverDialog(String title) {
     showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SpaceDialog(
            title: title,
            content: "Let's try another constellation!",
            onNext: () {
              Navigator.of(context).pop();
              _initializeGame();
            }));
  }
}

// Enhanced Data Model
class PuzzlePieceData {
  final int id;
  final String problem;
  final int answer;
  final int row;
  final int col;
  int rotation; // 0, 90, 180, 270

  PuzzlePieceData({
    required this.id,
    required this.problem,
    required this.answer,
    required this.row,
    required this.col,
    this.rotation = 0,
  });
}

// Fix for puzzle_math_game.dart - Better visibility and proper jigsaw pieces
class PuzzleSlotWidget extends StatelessWidget {
  final PuzzlePieceData data;
  final String? imagePath;
  final Size pieceSize;
  final int columns, rows;
  final bool isPieceOver;
  final Widget? child;
  final Map<String, JigsawSide> edgeShapes;

  const PuzzleSlotWidget({
    super.key,
    required this.data,
    required this.pieceSize,
    required this.columns,
    required this.rows,
    this.isPieceOver = false,
    this.child,
    required this.edgeShapes,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
    final extendedWidth = pieceSize.width + (bumpSize * 2);
    final extendedHeight = pieceSize.height + (bumpSize * 2);
    
    return Container(
      width: extendedWidth,
      height: extendedHeight,
      child: ClipPath(
        clipper: JigsawPieceClipper(
          data: data,
          columns: columns,
          rows: rows,
          edgeShapes: edgeShapes,
        ),
        child: child ?? AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isPieceOver 
                    ? SpaceTheme.alienGreen.withOpacity(0.4)
                    : SpaceTheme.moonSilver.withOpacity(0.3),
                isPieceOver 
                    ? SpaceTheme.alienGreen.withOpacity(0.2)
                    : SpaceTheme.deepSpace.withOpacity(0.4),
              ],
            ),
            border: Border.all(
              color: isPieceOver 
                  ? SpaceTheme.alienGreen 
                  : SpaceTheme.starYellow.withOpacity(0.8),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Math problem text
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.problem,
                    style: SpaceTheme.titleStyle.copyWith(
                      color: SpaceTheme.starYellow,
                      fontSize: pieceSize.width / 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageSegmentPainter extends CustomPainter {
  final String imagePath;
  final PuzzlePieceData pieceData;
  final Size pieceSize;
  final int columns, rows;
  final double opacity;

  ImageSegmentPainter({
    required this.imagePath,
    required this.pieceData,
    required this.pieceSize,
    required this.columns,
    required this.rows,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // This will be handled by the background image in the widget
    // Just provide a subtle pattern for now
    final paint = Paint()
      ..color = SpaceTheme.moonSilver.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Add subtle dots pattern
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    for (double x = 10; x < size.width; x += 20) {
      for (double y = 10; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PuzzlePieceWidget extends StatelessWidget {
  final String imagePath;
  final PuzzlePieceData data;
  final Size pieceSize;
  final int columns, rows;
  final bool isPlaced;
  final Map<String, JigsawSide> edgeShapes;
  final VoidCallback? onRotate;

  const PuzzlePieceWidget({
    super.key,
    required this.imagePath,
    required this.data,
    required this.pieceSize,
    required this.columns,
    required this.rows,
    this.isPlaced = false,
    required this.edgeShapes,
    this.onRotate,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total image display size
    final totalWidth = pieceSize.width * columns;
    final totalHeight = pieceSize.height * rows;
    
    // Calculate this piece's offset within the full image
    final offsetX = -(data.col * pieceSize.width);
    final offsetY = -(data.row * pieceSize.height);
    
    // Calculate extended size to accommodate knobs
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
    final extendedWidth = pieceSize.width + (bumpSize * 2);
    final extendedHeight = pieceSize.height + (bumpSize * 2);

    return GestureDetector(
      onTap: onRotate != null && !isPlaced ? onRotate : null,
      child: Transform.rotate(
        angle: data.rotation * math.pi / 180,
        child: Material(
          color: Colors.transparent,
          elevation: isPlaced ? 0 : 8,
          child: Container(
            width: extendedWidth,
            height: extendedHeight,
            child: ClipPath(
              clipper: JigsawPieceClipper(
                data: data,
                columns: columns,
                rows: rows,
                edgeShapes: edgeShapes,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Position the full image, offset to show correct segment
                  Positioned(
                    left: offsetX - bumpSize,
                    top: offsetY - bumpSize,  
                    width: totalWidth + (bumpSize * 2),
                    height: totalHeight + (bumpSize * 2),
                    child: Image.asset(
                      imagePath,
                      width: totalWidth + (bumpSize * 2),
                      height: totalHeight + (bumpSize * 2),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Dark overlay for text visibility
                  Container(
                    width: extendedWidth,
                    height: extendedHeight,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  // Answer text
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        data.answer.toString(),
                        style: TextStyle(
                          fontSize: pieceSize.width / 5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Improved Jigsaw Piece Clipper with better knobs
class JigsawPieceClipper extends CustomClipper<Path> {
  final PuzzlePieceData data;
  final int columns, rows;
  final Map<String, JigsawSide> edgeShapes;

  JigsawPieceClipper({
    required this.data,
    required this.columns,
    required this.rows,
    required this.edgeShapes,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Get edge shapes for this piece
    final topShape = data.row == 0 
        ? JigsawSide.flat 
        : edgeShapes['v-${data.row - 1}-${data.col}']!.inverse;
    final bottomShape = data.row == rows - 1 
        ? JigsawSide.flat 
        : edgeShapes['v-${data.row}-${data.col}']!;
    final leftShape = data.col == 0 
        ? JigsawSide.flat 
        : edgeShapes['h-${data.row}-${data.col - 1}']!.inverse;
    final rightShape = data.col == columns - 1 
        ? JigsawSide.flat 
        : edgeShapes['h-${data.row}-${data.col}']!;

    final bumpSize = math.min(size.width, size.height) / 4; // Much bigger knobs!
    
    path.moveTo(0, 0);
    
    // TOP EDGE
    if (topShape == JigsawSide.flat) {
      path.lineTo(size.width, 0);
    } else {
      // Draw to start of knob/hole
      path.lineTo(size.width / 3, 0);
      
      if (topShape == JigsawSide.knob) {
        // Create protruding knob (goes UP from the piece)
        path.cubicTo(
          size.width / 6, -bumpSize,           // Control point 1 - pulls curve up and left
          size.width / 6 * 5, -bumpSize,      // Control point 2 - pulls curve up and right  
          size.width / 3 * 2, 0               // End point - back to edge
        );
      } else {
        // Create inward hole (curves INTO the piece)
        path.cubicTo(
          size.width / 6, bumpSize,            // Control point 1 - pulls curve down and left
          size.width / 6 * 5, bumpSize,       // Control point 2 - pulls curve down and right
          size.width / 3 * 2, 0               // End point - back to edge
        );
      }
      
      path.lineTo(size.width, 0);
    }

    // RIGHT EDGE  
    if (rightShape == JigsawSide.flat) {
      path.lineTo(size.width, size.height);
    } else {
      path.lineTo(size.width, size.height / 3);
      
      if (rightShape == JigsawSide.knob) {
        // Knob protrudes RIGHT from the piece
        path.cubicTo(
          size.width + bumpSize, size.height / 6,
          size.width + bumpSize, size.height / 6 * 5,
          size.width, size.height / 3 * 2
        );
      } else {
        // Hole curves LEFT into the piece  
        path.cubicTo(
          size.width - bumpSize, size.height / 6,
          size.width - bumpSize, size.height / 6 * 5,
          size.width, size.height / 3 * 2
        );
      }
      
      path.lineTo(size.width, size.height);
    }

    // BOTTOM EDGE
    if (bottomShape == JigsawSide.flat) {
      path.lineTo(0, size.height);
    } else {
      path.lineTo(size.width / 3 * 2, size.height);
      
      if (bottomShape == JigsawSide.knob) {
        // Knob protrudes DOWN from the piece
        path.cubicTo(
          size.width / 6 * 5, size.height + bumpSize,
          size.width / 6, size.height + bumpSize,
          size.width / 3, size.height
        );
      } else {
        // Hole curves UP into the piece
        path.cubicTo(
          size.width / 6 * 5, size.height - bumpSize,
          size.width / 6, size.height - bumpSize,  
          size.width / 3, size.height
        );
      }
      
      path.lineTo(0, size.height);
    }

    // LEFT EDGE
    if (leftShape == JigsawSide.flat) {
      path.close();
    } else {
      path.lineTo(0, size.height / 3 * 2);
      
      if (leftShape == JigsawSide.knob) {
        // Knob protrudes LEFT from the piece
        path.cubicTo(
          -bumpSize, size.height / 6 * 5,
          -bumpSize, size.height / 6,
          0, size.height / 3
        );
      } else {
        // Hole curves RIGHT into the piece
        path.cubicTo(
          bumpSize, size.height / 6 * 5,
          bumpSize, size.height / 6,
          0, size.height / 3
        );
      }
      
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

// Add background pattern painter for slot visibility
class SlotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw grid pattern for better slot visibility
    final spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum JigsawSide { flat, knob, hole }

extension on JigsawSide {
  JigsawSide get inverse {
    if (this == JigsawSide.knob) return JigsawSide.hole;
    if (this == JigsawSide.hole) return JigsawSide.knob;
    return JigsawSide.flat;
  }
}

// Dialog widget
class SpaceDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onNext;

  const SpaceDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: SpaceTheme.headlineStyle),
            const SizedBox(height: 16),
            Text(content, style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onNext,
              style: SpaceTheme.primaryButtonStyle,
              child: Text(S.of(context)!.nextLevel),
            ),
          ],
        ),
      ),
    );
  }
}