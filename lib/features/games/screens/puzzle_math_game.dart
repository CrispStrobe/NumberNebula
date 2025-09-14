import 'dart:async';
import 'dart:developer'; // Import the developer log
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
    log("--- INITIALIZING NEW GAME ---", name: "PuzzleMath");
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
    log("Starting timer. Duration: $_timeLeft seconds.", name: "PuzzleMath");
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (mounted) {
          log("Timer finished.", name: "PuzzleMath");
          _showGameOverDialog("Time's up, space cadet!");
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    log("Disposing PuzzleMathGame widget.", name: "PuzzleMath");
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
    log("Generating puzzle with grade $difficulty. Grid: $columns x $rows", name: "PuzzleMath");


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
    log("Generated ${pieceData.length} pieces with math problems.", name: "PuzzleMath");

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
    log("Generated ${_edgeShapes.length} unique edge shapes.", name: "PuzzleMath");
  }

  void _onToggleTimer(bool isEnabled) {
    context.read<GameProvider>().setPuzzleTimer(isEnabled);
    log("Timer toggled: ${isEnabled ? 'ON' : 'OFF'}", name: "PuzzleMath");
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
      log("Rotated piece ID $pieceId to ${piece.rotation} degrees.", name: "PuzzleMath.Interaction");
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
                // score: gameProvider.score,
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
                    log("LayoutBuilder constraints: MaxW=${constraints.maxWidth}, MaxH=${constraints.maxHeight}", name: "PuzzleMath.Layout");
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
    // ✅ FIX: Increased board constraint width from 0.5 to 0.9 for a larger puzzle area.
    final boardConstraints = BoxConstraints(
        maxWidth: constraints.maxWidth * 0.9, 
        maxHeight: constraints.maxHeight * 0.9,
    );

    double pieceWidth = (boardConstraints.maxWidth / columns);
    double pieceHeight = pieceWidth;

    if (pieceHeight * rows > boardConstraints.maxHeight) {
        pieceHeight = (boardConstraints.maxHeight / rows);
        pieceWidth = pieceHeight;
    }
    
    log("Calculated piece size: W=${pieceWidth.toStringAsFixed(2)}, H=${pieceHeight.toStringAsFixed(2)}", name: "PuzzleMath.Layout");
    return Size(pieceWidth, pieceHeight);
  }

  Widget _buildPuzzleBoard(BoxConstraints constraints) {
    final pieceSize = _calculatePieceSize(constraints);
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
  
    final boardWidth = pieceSize.width * columns;
    final boardHeight = pieceSize.height * rows;
    log("Building puzzle board: W=${boardWidth.toStringAsFixed(2)}, H=${boardHeight.toStringAsFixed(2)}", name: "PuzzleMath.Layout");

    return Center(
      child: Container(
        width: boardWidth,
        height: boardHeight,
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.8), width: 3),
        ),
        child: Stack(
          clipBehavior: Clip.none, 
          children: List.generate(rows * columns, (index) {
            final row = index ~/ columns;
            final col = index % columns;
            // Find the original piece that belongs in this slot by its row/col
            final slotData = pieces.firstWhere((p) => p.row == row && p.col == col);
            final isPlaced = placedPieces.containsKey(slotData.id);

            // ✅ FIX: This positioning is correct. The error was in the clipper.
            // A piece's widget is larger than its core (due to knobs), so we
            // offset it by -bumpSize to align the *core* of the piece with the grid.
            final slotLeft = (col * pieceSize.width) - bumpSize;
            final slotTop = (row * pieceSize.height) - bumpSize;

            return Positioned(
              left: slotLeft,
              top: slotTop,
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
                            onRotate: () {},
                          )
                        : null,
                  );
                },
                onWillAccept: (pieceId) {
                  final willAccept = !isPlaced;
                  log("Piece ID $pieceId hovering over slot ${slotData.id} (${slotData.problem}). Will Accept: $willAccept", name: "PuzzleMath.DragDrop");
                  return willAccept;
                },
                onAccept: (pieceId) {
                  final pieceData = pieces.firstWhere((p) => p.id == pieceId);
                  log("Attempting to place piece ID $pieceId (Answer: ${pieceData.answer}, Rot: ${pieceData.rotation}) into slot ${slotData.id} (Answer: ${slotData.answer})", name: "PuzzleMath.DragDrop");
                  
                  if (pieceData.answer == slotData.answer && pieceData.rotation == 0) {
                    log("SUCCESS: Correct placement.", name: "PuzzleMath.DragDrop");
                    setState(() => placedPieces[slotData.id] = pieceId);
                    context.read<GameProvider>().addScore(50);
                    if (placedPieces.length == pieces.length) {
                      _showWinDialog();
                    }
                  } else {
                    log("FAILURE: Incorrect placement. Reason: ${pieceData.answer != slotData.answer ? 'Wrong Answer' : 'Wrong Rotation'}", name: "PuzzleMath.DragDrop");
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
    
    // Make tray pieces smaller to fit nicely
    final trayPieceSize = Size(pieceSize.width * 0.7, pieceSize.height * 0.7);
    final trayBumpSize = math.min(trayPieceSize.width, trayPieceSize.height) / 4;
    final extendedTraySize = trayPieceSize.width + (trayBumpSize * 2);
    
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
                maxCrossAxisExtent: extendedTraySize + 20,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: pieces.length,
              itemBuilder: (context, index) {
                final pieceData = pieces[index];
                if (placedPieces.values.contains(pieceData.id)) {
                  return Container(); // Piece already placed
                }
                return Center(
                  child: Draggable<int>(
                    data: pieceData.id,
                    feedback: Material(
                      color: Colors.transparent,
                      child: PuzzlePieceWidget(
                        imagePath: currentPuzzleImage!,
                        data: pieceData,
                        pieceSize: trayPieceSize,
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
                        pieceSize: trayPieceSize,
                        columns: columns,
                        rows: rows,
                        edgeShapes: _edgeShapes,
                        onRotate: () => _rotatePiece(pieceData.id),
                      ),
                    ),
                    child: PuzzlePieceWidget(
                      imagePath: currentPuzzleImage!,
                      data: pieceData,
                      pieceSize: trayPieceSize,
                      columns: columns,
                      rows: rows,
                      edgeShapes: _edgeShapes,
                      onRotate: () => _rotatePiece(pieceData.id),
                    ),
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
    log("--- PUZZLE COMPLETE ---", name: "PuzzleMath");
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    int bonus = 0;
    String message = S.of(context)!.puzzleMathWin;
    if (gameProvider.puzzleTimerEnabled) {
      bonus = (_timeLeft * 2);
      message = "Constellation restored!\nTime Bonus: $bonus points!";
    }
    context.read<GameProvider>().addScore(100 + bonus);
    log("Awarding win bonus. Base: 100, Time Bonus: $bonus", name: "PuzzleMath");
    
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

// Data Model
class PuzzlePieceData {
  final int id;
  final String problem;
  final int answer;
  final int row;
  final int col;
  int rotation; 

  PuzzlePieceData({
    required this.id,
    required this.problem,
    required this.answer,
    required this.row,
    required this.col,
    this.rotation = 0,
  });
}

// Puzzle Slot Widget
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
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
    final extendedWidth = pieceSize.width + (bumpSize * 2);
    final extendedHeight = pieceSize.height + (bumpSize * 2);
    
    return SizedBox(
      width: extendedWidth,
      height: extendedHeight,
      child: ClipPath(
        clipper: JigsawPieceClipper(
          data: data,
          columns: columns,
          rows: rows,
          edgeShapes: edgeShapes,
          bumpSize: bumpSize,
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
          ),
          child: Center(
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
                  fontSize: pieceSize.width / 5,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Puzzle Piece Widget
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
    final totalWidth = pieceSize.width * columns;
    final totalHeight = pieceSize.height * rows;
    
    final offsetX = -(data.col * pieceSize.width);
    final offsetY = -(data.row * pieceSize.height);
    
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
          child: SizedBox(
            width: extendedWidth,
            height: extendedHeight,
            child: ClipPath(
              clipper: JigsawPieceClipper(
                data: data,
                columns: columns,
                rows: rows,
                edgeShapes: edgeShapes,
                bumpSize: bumpSize,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: offsetX - bumpSize,
                    top: offsetY - bumpSize,  
                    width: totalWidth,
                    height: totalHeight,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    width: extendedWidth,
                    height: extendedHeight,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        data.answer.toString(),
                        style: TextStyle(
                          fontSize: pieceSize.width / 4,
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

// ✅ FIX: Heavily refactored JigsawPieceClipper
class JigsawPieceClipper extends CustomClipper<Path> {
  final PuzzlePieceData data;
  final int columns, rows;
  final Map<String, JigsawSide> edgeShapes;
  final double bumpSize; // It now requires bumpSize

  JigsawPieceClipper({
    required this.data,
    required this.columns,
    required this.rows,
    required this.edgeShapes,
    required this.bumpSize, // Added to constructor
  });

  @override
  Path getClip(Size size) {
    // The `size` passed to the clipper is the extended size (core + 2*bumpSize).
    // We derive the core size from it.
    final path = Path();
    final double coreWidth = size.width - (bumpSize * 2);
    final double coreHeight = size.height - (bumpSize * 2);

    // Get edge shapes for this piece (this logic is correct)
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
    
    // Start path at the top-left of the *core* rectangle
    path.moveTo(bumpSize, bumpSize);

    // --- TOP EDGE ---
    _createEdgePath(path, JigsawEdge.top, topShape, coreWidth, coreHeight);
    
    // --- RIGHT EDGE ---
    _createEdgePath(path, JigsawEdge.right, rightShape, coreWidth, coreHeight);

    // --- BOTTOM EDGE ---
    _createEdgePath(path, JigsawEdge.bottom, bottomShape, coreWidth, coreHeight);
    
    // --- LEFT EDGE ---
    _createEdgePath(path, JigsawEdge.left, leftShape, coreWidth, coreHeight);

    path.close();
    return path;
  }

  void _createEdgePath(Path path, JigsawEdge edge, JigsawSide shape, double w, double h) {
    // This helper function draws one edge of the puzzle piece.
    // All coordinates are offset by `bumpSize` to draw the core in the center.
    switch (edge) {
      case JigsawEdge.top:
        if (shape == JigsawSide.flat) {
          path.lineTo(bumpSize + w, bumpSize);
        } else {
          path.lineTo(bumpSize + w * 0.35, bumpSize);
          double ySign = (shape == JigsawSide.knob) ? -1 : 1;
          path.cubicTo(
              bumpSize + w * 0.30, bumpSize + (bumpSize * ySign),
              bumpSize + w * 0.70, bumpSize + (bumpSize * ySign),
              bumpSize + w * 0.65, bumpSize
          );
          path.lineTo(bumpSize + w, bumpSize);
        }
        break;
      case JigsawEdge.right:
        if (shape == JigsawSide.flat) {
          path.lineTo(bumpSize + w, bumpSize + h);
        } else {
          path.lineTo(bumpSize + w, bumpSize + h * 0.35);
          double xSign = (shape == JigsawSide.knob) ? 1 : -1;
          path.cubicTo(
              bumpSize + w + (bumpSize * xSign), bumpSize + h * 0.30,
              bumpSize + w + (bumpSize * xSign), bumpSize + h * 0.70,
              bumpSize + w, bumpSize + h * 0.65
          );
          path.lineTo(bumpSize + w, bumpSize + h);
        }
        break;
      case JigsawEdge.bottom:
        if (shape == JigsawSide.flat) {
          path.lineTo(bumpSize, bumpSize + h);
        } else {
          path.lineTo(bumpSize + w * 0.65, bumpSize + h);
          double ySign = (shape == JigsawSide.knob) ? 1 : -1;
           path.cubicTo(
              bumpSize + w * 0.70, bumpSize + h + (bumpSize * ySign),
              bumpSize + w * 0.30, bumpSize + h + (bumpSize * ySign),
              bumpSize + w * 0.35, bumpSize + h
          );
          path.lineTo(bumpSize, bumpSize + h);
        }
        break;
      case JigsawEdge.left:
         if (shape == JigsawSide.flat) {
          path.lineTo(bumpSize, bumpSize);
        } else {
          path.lineTo(bumpSize, bumpSize + h * 0.65);
          double xSign = (shape == JigsawSide.knob) ? -1 : 1;
           path.cubicTo(
              bumpSize + (bumpSize * xSign), bumpSize + h * 0.70,
              bumpSize + (bumpSize * xSign), bumpSize + h * 0.30,
              bumpSize, bumpSize + h * 0.35
          );
          path.lineTo(bumpSize, bumpSize);
        }
        break;
    }
  }

  @override
  bool shouldReclip(covariant JigsawPieceClipper oldClipper) => 
      oldClipper.data != data || 
      oldClipper.bumpSize != bumpSize ||
      oldClipper.edgeShapes != edgeShapes;
}

enum JigsawEdge { top, right, bottom, left }
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