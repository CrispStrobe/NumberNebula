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
      maxWidth: constraints.maxWidth * 0.95,
      maxHeight: constraints.maxHeight * 0.95,
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
    final boardWidth = pieceSize.width * columns;
    final boardHeight = pieceSize.height * rows;

    return Center(
      child: Container(
        width: boardWidth,
            height: boardHeight,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), // Better visibility
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.8), width: 3),
            ),
        child: Stack(
          children: List.generate(rows * columns, (index) {
            final row = index ~/ columns;
            final col = index % columns;
            final slotData = pieces.firstWhere((p) => p.row == row && p.col == col);
            final isPlaced = placedPieces.containsKey(slotData.id);

            return Positioned(
              left: col * pieceSize.width,
              top: row * pieceSize.height,
              width: pieceSize.width,
              height: pieceSize.height,
              child: DragTarget<int>(
                builder: (context, candidateData, rejectedData) {
                  return PuzzleSlotWidget(
                    data: slotData,
                    pieceSize: pieceSize,
                    columns: columns,
                    rows: rows,
                    edgeShapes: _edgeShapes,
                    isPieceOver: candidateData.isNotEmpty,
                    child: isPlaced
                        ? PuzzlePieceWidget(
                            imagePath: currentPuzzleImage!,
                            data: pieces.firstWhere((p) => p.id == placedPieces[slotData.id]),
                            pieceSize: pieceSize,
                            columns: columns,
                            rows: rows,
                            edgeShapes: _edgeShapes,
                            isPlaced: true,
                            onRotate: () {}, // Can't rotate placed pieces
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
                    // Wrong piece or wrong rotation
                    _showIncorrectPlacement();
                  }
                },
              ),
            );
          }),
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
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: JigsawPieceClipper(
        data: data,
        columns: columns,
        rows: rows,
        edgeShapes: edgeShapes,
      ),
      child: child ?? AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          // FIX: Better contrast and visibility
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
            // Background pattern for better visibility
            Positioned.fill(
              child: CustomPaint(
                painter: SlotPatternPainter(),
              ),
            ),
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
    );
  }
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
    return GestureDetector(
      onTap: onRotate != null && !isPlaced ? onRotate : null,
      child: Transform.rotate(
        angle: data.rotation * math.pi / 180,
        child: Material(
          color: Colors.transparent,
          elevation: isPlaced ? 0 : 8,
          child: ClipPath(
            clipper: JigsawPieceClipper(
              data: data,
              columns: columns,
              rows: rows,
              edgeShapes: edgeShapes,
            ),
            child: Container(
              width: pieceSize.width,
              height: pieceSize.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                  alignment: FractionalOffset(
                    columns <= 1 ? 0.5 : (data.col / (columns - 1)),
                    rows <= 1 ? 0.5 : (data.row / (rows - 1)),
                  ),
                ),
                // FIX: Add border for better piece definition
                border: Border.all(
                  color: isPlaced ? SpaceTheme.alienGreen : Colors.white.withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // FIX: Better contrast overlay
                  Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  // Answer display with better visibility
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
                        style: SpaceTheme.headlineStyle.copyWith(
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

    // Get the shapes for all four sides
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

    // Start from top-left corner
    path.moveTo(0, 0);

    // Draw top edge
    _drawHorizontalSide(path, 0, 0, size.width, 0, topShape, size);

    // Draw right edge
    _drawVerticalSide(path, size.width, 0, size.width, size.height, rightShape, size);

    // Draw bottom edge
    _drawHorizontalSide(path, size.width, size.height, 0, size.height, bottomShape.inverse, size);

    // Draw left edge
    _drawVerticalSide(path, 0, size.height, 0, 0, leftShape.inverse, size);

    path.close();
    return path;
  }

  void _drawHorizontalSide(Path path, double x1, double y1, double x2, double y2, 
                        JigsawSide side, Size size) {
    if (side == JigsawSide.flat) {
        path.lineTo(x2, y2);
        return;
    }

    final length = (x2 - x1).abs();
    final direction = x2 > x1 ? 1 : -1;
    final knobWidth = length * 0.2; // FIX: Better knob size
    final knobHeight = size.height * 0.15 * (side == JigsawSide.knob ? -1 : 1);

    // FIX: More pronounced and smoother curves
    final p1x = x1 + direction * length * 0.35;
    final p2x = x1 + direction * length * 0.65;
    final midx = x1 + direction * length * 0.5;
    final midy = y1 + knobHeight;

    path.lineTo(p1x, y1);
    
    // Create smooth curved knob/hole with quadratic bezier curves
    path.quadraticBezierTo(
        p1x, y1 + knobHeight * 0.5,
        midx - knobWidth * 0.5, midy
    );
    path.quadraticBezierTo(
        midx + knobWidth * 0.5, midy,
        p2x, y1 + knobHeight * 0.5
    );
    path.quadraticBezierTo(
        p2x, y1,
        p2x, y1
    );
    
    path.lineTo(x2, y2);
  }

  void _drawVerticalSide(Path path, double x1, double y1, double x2, double y2, 
                        JigsawSide side, Size size) {
    if (side == JigsawSide.flat) {
      path.lineTo(x2, y2);
      return;
    }

    final length = (y2 - y1).abs();
    final direction = y2 > y1 ? 1 : -1;
    final knobHeight = length * 0.2;
    final knobWidth = size.width * 0.15 * (side == JigsawSide.knob ? -1 : 1);

    // FIX: Better vertical knob positioning
    final p1y = y1 + direction * length * 0.35;
    path.lineTo(x1, p1y);

    // Knob/hole using quadratic bezier curves
    final p2y = y1 + direction * length * 0.65;
    final midx = x1 + knobWidth;
    final midy = y1 + direction * length * 0.5;

    path.quadraticBezierTo(
      x1 + knobWidth * 0.5, p1y,
      midx, midy - knobHeight * 0.5
    );
    path.quadraticBezierTo(
      midx, midy + knobHeight * 0.5,
      x1 + knobWidth * 0.5, p2y
    );
    path.quadraticBezierTo(
      x1, p2y,
      x1, p2y
    );

    path.lineTo(x2, y2);
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