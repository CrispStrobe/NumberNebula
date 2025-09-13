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
  Map<String, PuzzleSide> _edgeShapes = {}; // Stores the shape of each interior edge

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
          _showGameOverDialog("Time's up!");
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
    final difficulty = widget.grade + widget.level;
    final pieceCount = (difficulty < 5) ? 4 : 6;
    columns = (pieceCount == 4) ? 2 : 3;
    rows = 2;

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
    // Horizontal edges
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns - 1; c++) {
        _edgeShapes['h-$r-$c'] = random.nextBool() ? PuzzleSide.knob : PuzzleSide.hole;
      }
    }
    // Vertical edges
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < columns; c++) {
        _edgeShapes['v-$r-$c'] = random.nextBool() ? PuzzleSide.knob : PuzzleSide.hole;
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

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    if (currentPuzzleImage == null) {
      return Scaffold(
          body: Center(
              child: Text("No puzzle images found in assets/images/",
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
                        S.of(context)!.instructionsPuzzleMath,
                        textAlign: TextAlign.center,
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                      ),
                    ),
                    Row(
                      children: [
                        Text("Timer", style: SpaceTheme.bodyStyle.copyWith(color: Colors.white)),
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
      child: SizedBox(
        width: boardWidth,
        height: boardHeight,
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
                          )
                        : null,
                  );
                },
                onWillAccept: (pieceId) => !isPlaced,
                onAccept: (pieceId) {
                  final pieceData = pieces.firstWhere((p) => p.id == pieceId);
                  if (pieceData.answer == slotData.answer) {
                    setState(() => placedPieces[slotData.id] = pieceId);
                    context.read<GameProvider>().addScore(50);
                    if (placedPieces.length == pieces.length) {
                      _showWinDialog();
                    }
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
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: pieceSize.width + 10,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: pieces.length,
        itemBuilder: (context, index) {
          final pieceData = pieces[index];
          if (placedPieces.values.contains(pieceData.id)) {
            return Container();
          }
          return Draggable<int>(
            data: pieceData.id,
            feedback: PuzzlePieceWidget(
              imagePath: currentPuzzleImage!,
              data: pieceData,
              pieceSize: pieceSize,
              columns: columns,
              rows: rows,
              edgeShapes: _edgeShapes,
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: PuzzlePieceWidget(
                imagePath: currentPuzzleImage!,
                data: pieceData,
                pieceSize: pieceSize,
                columns: columns,
                rows: rows,
                edgeShapes: _edgeShapes,
              ),
            ),
            child: PuzzlePieceWidget(
              imagePath: currentPuzzleImage!,
              data: pieceData,
              pieceSize: pieceSize,
              columns: columns,
              rows: rows,
              edgeShapes: _edgeShapes,
            ),
          );
        },
      ),
    );
  }

  void _showWinDialog() {
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    int bonus = 0;
    String message = "Constellation complete!";
    if (gameProvider.puzzleTimerEnabled) {
      bonus = (_timeLeft * 2);
      message = "Constellation complete!\nTime Bonus: $bonus points!";
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
            content: "Let's try another puzzle!",
            onNext: () {
              Navigator.of(context).pop();
              _initializeGame();
            }));
  }
}

// Data and Widgets...
class PuzzlePieceData {
  final int id; final String problem; final int answer; final int row; final int col;
  PuzzlePieceData({ required this.id, required this.problem, required this.answer, required this.row, required this.col });
}

class PuzzleSlotWidget extends StatelessWidget {
  final PuzzlePieceData data; final Size pieceSize; final int columns, rows; final bool isPieceOver; final Widget? child; final Map<String, PuzzleSide> edgeShapes;
  const PuzzleSlotWidget({super.key, required this.data, required this.pieceSize, required this.columns, required this.rows, this.isPieceOver = false, this.child, required this.edgeShapes});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: PuzzlePieceClipper(data: data, columns: columns, rows: rows, edgeShapes: edgeShapes),
      child: child ?? AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isPieceOver ? SpaceTheme.alienGreen.withOpacity(0.3) : SpaceTheme.deepSpace.withOpacity(0.5),
        ),
        child: Center(
          child: Text(data.problem, style: SpaceTheme.titleStyle.copyWith(color: Colors.white.withOpacity(0.8), fontSize: pieceSize.width / 5)),
        ),
      ),
    );
  }
}

class PuzzlePieceWidget extends StatelessWidget {
  final String imagePath; final PuzzlePieceData data; final Size pieceSize; final int columns, rows; final bool isPlaced; final Map<String, PuzzleSide> edgeShapes;
  const PuzzlePieceWidget({super.key, required this.imagePath, required this.data, required this.pieceSize, required this.columns, required this.rows, this.isPlaced = false, required this.edgeShapes });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: isPlaced ? 0 : 10,
      child: ClipPath(
        clipper: PuzzlePieceClipper(data: data, columns: columns, rows: rows, edgeShapes: edgeShapes),
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
          ),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Text(
                data.answer.toString(),
                style: SpaceTheme.headlineStyle.copyWith(fontSize: pieceSize.width / 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The new, robust Jigsaw Clipper
class PuzzlePieceClipper extends CustomClipper<Path> {
  final PuzzlePieceData data; final int columns, rows; final Map<String, PuzzleSide> edgeShapes;
  PuzzlePieceClipper({required this.data, required this.columns, required this.rows, required this.edgeShapes});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Get the shapes for all four sides, inverting for neighbors
    final topShape = data.row == 0 ? PuzzleSide.flat : edgeShapes['v-${data.row - 1}-${data.col}']!.inverse;
    final bottomShape = data.row == rows - 1 ? PuzzleSide.flat : edgeShapes['v-${data.row}-${data.col}']!;
    final leftShape = data.col == 0 ? PuzzleSide.flat : edgeShapes['h-${data.row}-${data.col - 1}']!.inverse;
    final rightShape = data.col == columns - 1 ? PuzzleSide.flat : edgeShapes['h-${data.row}-${data.col}']!;
    
    path.moveTo(0, 0);
    _drawSide(path, 0, 0, size.width, 0, topShape);
    _drawSide(path, size.width, 0, size.width, size.height, rightShape);
    _drawSide(path, size.width, size.height, 0, size.height, bottomShape);
    _drawSide(path, 0, size.height, 0, 0, leftShape);
    
    path.close();
    return path;
  }
  
  void _drawSide(Path path, double x1, double y1, double x2, double y2, PuzzleSide side) {
    if (side == PuzzleSide.flat) {
      path.lineTo(x2, y2);
      return;
    }
    
    final isHorizontal = y1 == y2;
    final length = isHorizontal ? (x2 - x1) : (y2 - y1);
    final knobSize = length.abs() * 0.3;
    final knobDepth = length.abs() * 0.2 * (side == PuzzleSide.knob ? 1 : -1);

    final p1 = isHorizontal ? Offset(x1 + length * 0.35, y1) : Offset(x1, y1 + length * 0.35);
    final p2 = isHorizontal ? Offset(x1 + length * 0.65, y1) : Offset(x1, y1 + length * 0.65);
    
    path.lineTo(p1.dx, p1.dy);

    if (isHorizontal) {
      path.cubicTo(p1.dx, p1.dy - knobDepth, p2.dx, p2.dy - knobDepth, p2.dx, p2.dy);
    } else {
      path.cubicTo(p1.dx + knobDepth, p1.dy, p2.dx + knobDepth, p2.dy, p2.dx, p2.dy);
    }
    path.lineTo(x2, y2);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

enum PuzzleSide { flat, knob, hole }
extension on PuzzleSide {
  PuzzleSide get inverse {
    if (this == PuzzleSide.knob) return PuzzleSide.hole;
    if (this == PuzzleSide.hole) return PuzzleSide.knob;
    return PuzzleSide.flat;
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
            Text(content, style: SpaceTheme.bodyStyle),
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