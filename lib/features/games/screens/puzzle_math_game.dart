import 'dart:async';
// REFACTORED: No longer need dart:developer
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // REFACTORED: Import for debugPrint
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/puzzle_image_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../../../core/services/sri_service.dart';

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
    // REFACTORED: Using debugPrint for CLI output
    debugPrint("--- INITIALIZING NEW GAME ---");
    final gameProvider = context.read<GameProvider>();
    
    currentPuzzleImage = PuzzleImageService.instance.getImageForLevel(widget.level);
    debugPrint("🖼️ LOADED IMAGE: $currentPuzzleImage for level ${widget.level}");
    
    _generatePuzzle();
    if (gameProvider.puzzleTimerEnabled) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timeLeft = 120;
    _timer?.cancel();
    debugPrint("TIMER: Starting timer. Duration: $_timeLeft seconds.");
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        if (mounted) {
          debugPrint("TIMER: Timer finished.");
          _showGameOverDialog("Time's up, space cadet!");
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    debugPrint("Disposing PuzzleMathGame widget.");
    super.dispose();
  }

  void _generatePuzzle() {
    final gameProvider = context.read<GameProvider>();
    final sriService = context.read<SriService>();
    final difficulty = widget.grade;
    if (difficulty <= 1) { // Adjusted for 1-4 levels
      columns = 2; rows = 2;
    } else if (difficulty == 2) {
      columns = 2; rows = 3;
    } else if (difficulty == 3) {
      columns = 3; rows = 3;
    } else {
      columns = 3; rows = 4;
    }
    debugPrint("PUZZLE: Grid set to ${columns}x${rows} = ${columns * rows} pieces (Grade: $difficulty)");

    final pieceCount = columns * rows;
    _generateEdgeShapes(); 

    final problems = <MathProblem>{};
    while (problems.length < pieceCount) {
      problems.add(MathProblem.generateProblem(gameProvider, widget.level, sriService));
    }

    final problemList = problems.toList();
    final pieceData = <PuzzlePieceData>[];
    for (int i = 0; i < pieceCount; i++) {
      pieceData.add(PuzzlePieceData(
        id: i,
        problem: problemList[i],
        row: i ~/ columns,
        col: i % columns,
        rotation: 0, 
      ));
    }
    debugPrint("PUZZLE: Generated ${pieceData.length} pieces with math problems.");

    setState(() {
      pieces = pieceData..shuffle(math.Random());
      placedPieces.clear();
    });
  }

  void _generateEdgeShapes() {
    _edgeShapes.clear();
    final random = math.Random();
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns - 1; c++) {
        _edgeShapes['h-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
      }
    }
    
    for (int r = 0; r < rows - 1; r++) {
      for (int c = 0; c < columns; c++) {
        _edgeShapes['v-$r-$c'] = random.nextBool() ? JigsawSide.knob : JigsawSide.hole;
      }
    }
    debugPrint("PUZZLE: Generated ${_edgeShapes.length} unique interior edge shapes.");
  }

  void _onToggleTimer(bool isEnabled) {
    context.read<GameProvider>().setPuzzleTimer(isEnabled);
    debugPrint("TIMER: Timer toggled: ${isEnabled ? 'ON' : 'OFF'}");
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
      debugPrint("INTERACTION: Rotated piece ID $pieceId to ${piece.rotation} degrees.");
    });
  }

  void _removePiece(int slotId) {
    setState(() {
      final pieceId = placedPieces[slotId];
      placedPieces.remove(slotId);
      debugPrint("INTERACTION: Removed piece ID $pieceId from slot ID $slotId.");
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    if (currentPuzzleImage == null) {
      return const Scaffold(
          body: Center(
              child: Text("No constellation images found in assets/images/")));
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
                    // REFACTORED: Verbose logging
                    debugPrint("==================== LAYOUT REBUILD ====================");
                    debugPrint("LAYOUT: Available constraints: MaxW=${constraints.maxWidth.toStringAsFixed(1)}, MaxH=${constraints.maxHeight.toStringAsFixed(1)}");
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
    // Calculate board size based on the 3/5 flex split for the board area
    final availableWidth = constraints.maxWidth * (3 / 5);
    final availableHeight = constraints.maxHeight;

    // Leave a small margin
    final boardConstraints = BoxConstraints(
        maxWidth: availableWidth * 0.95, 
        maxHeight: availableHeight * 0.95,
    );

    double pieceWidth = (boardConstraints.maxWidth / columns);
    double pieceHeight = (boardConstraints.maxHeight / rows);
    
    // Make pieces square by choosing the smaller of the two dimensions
    final pieceSide = math.min(pieceWidth, pieceHeight);
    
    // REFACTORED: Verbose logging
    debugPrint("SIZING: Calculating piece size...");
    debugPrint("SIZING:   -> Available for board: W=${availableWidth.toStringAsFixed(1)}, H=${availableHeight.toStringAsFixed(1)}");
    debugPrint("SIZING:   -> Using constraints: W=${boardConstraints.maxWidth.toStringAsFixed(1)}, H=${boardConstraints.maxHeight.toStringAsFixed(1)}");
    debugPrint("SIZING:   -> Calculated side length: ${pieceSide.toStringAsFixed(2)}");
    
    return Size(pieceSide, pieceSide);
  }

  Widget _buildPuzzleBoard(BoxConstraints constraints) {
    final pieceSize = _calculatePieceSize(constraints);
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
    
    // REFACTORED: Board size is now the *core* size, excluding bumps.
    // The Center widget will handle alignment, and Clip.none will show the bumps.
    final coreWidth = pieceSize.width * columns;
    final coreHeight = pieceSize.height * rows;
    
    // REFACTORED: Verbose logging for all board dimensions
    debugPrint("-------------------- Puzzle Board Build --------------------");
    debugPrint("BOARD: Piece Size (Core): ${pieceSize.width.toStringAsFixed(1)} x ${pieceSize.height.toStringAsFixed(1)}");
    debugPrint("BOARD: Bump Size: ${bumpSize.toStringAsFixed(1)}");
    debugPrint("BOARD: Core Grid Dimensions: ${coreWidth.toStringAsFixed(1)} x ${coreHeight.toStringAsFixed(1)}");
    debugPrint("----------------------------------------------------------");

    return Center(
      child: Container(
        width: coreWidth,
        height: coreHeight,
        decoration: BoxDecoration(
          color: SpaceTheme.deepSpace.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.8), width: 3),
        ),
        child: Stack(
          clipBehavior: Clip.none, // This is crucial to let edge bumps render outside the container
          children: List.generate(rows * columns, (index) {
            final row = index ~/ columns;
            final col = index % columns;
            // The slotData is the piece that *should* go here
            final slotData = pieces.firstWhere((p) => p.row == row && p.col == col);
            final isPlaced = placedPieces.containsKey(slotData.id);

            // REFACTORED: Robust positioning.
            // Calculate the top-left of the piece's core area.
            final coreLeft = col * pieceSize.width;
            final coreTop = row * pieceSize.height;

            // The PuzzleSlotWidget is larger than the core size to accommodate bumps.
            // We must offset its position by -bumpSize so the core area aligns perfectly with the grid.
            final slotWidgetLeft = coreLeft - bumpSize;
            final slotWidgetTop = coreTop - bumpSize;

            debugPrint("BOARD: Slot ${slotData.id} (R:$row, C:$col) | Core Pos: (${coreLeft.toStringAsFixed(1)}, ${coreTop.toStringAsFixed(1)}) | Widget Pos: (${slotWidgetLeft.toStringAsFixed(1)}, ${slotWidgetTop.toStringAsFixed(1)})");

            return Positioned(
              left: slotWidgetLeft,
              top: slotWidgetTop,
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
                            onRemove: () => _removePiece(slotData.id),
                          )
                        : null,
                  );
                },
                onWillAccept: (pieceId) {
                  final willAccept = !isPlaced;
                  debugPrint("DRAG: Piece ID $pieceId hovering over slot ${slotData.id}. Will Accept: $willAccept");
                  return willAccept;
                },
                onAccept: (pieceId) {
                  final pieceData = pieces.firstWhere((p) => p.id == pieceId);
                  final isCorrect = pieceData.answer == slotData.answer && pieceData.rotation == 0;
        
                  debugPrint("DROP: Attempting place piece ID $pieceId (Ans: ${pieceData.answer}, Rot: ${pieceData.rotation}) -> slot ${slotData.id} (Ans: ${slotData.answer})");
                  
                  final sriService = context.read<SriService>();
                  sriService.recordResponse(pieceData.problem, isCorrect);
                
                  if (isCorrect) {
                    debugPrint("DROP: SUCCESS! Correct placement.");
                    setState(() => placedPieces[slotData.id] = pieceId);
                    context.read<GameProvider>().addScore(50);
                    if (placedPieces.length == pieces.length) {
                      _showWinDialog();
                    }
                  } else {
                    debugPrint("DROP: FAILURE! Incorrect. Reason: ${pieceData.answer != slotData.answer ? 'Wrong Answer' : 'Wrong Rotation'}");
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
    // We use the same piece size calculation but scale the pieces down for the tray
    final boardPieceSize = _calculatePieceSize(constraints);
    final trayPieceSize = Size(boardPieceSize.width * 0.8, boardPieceSize.height * 0.8);
    final trayBumpSize = math.min(trayPieceSize.width, trayPieceSize.height) / 4;
    // The grid view needs to know the full size of the widget, including bumps
    final extendedTrayWidgetSize = trayPieceSize.width + (trayBumpSize * 2);
    
    debugPrint("-------------------- Piece Tray Build --------------------");
    debugPrint("TRAY: Tray Piece Size (Core): ${trayPieceSize.width.toStringAsFixed(1)} x ${trayPieceSize.height.toStringAsFixed(1)}");
    debugPrint("TRAY: Extended Widget Size for Grid: ${extendedTrayWidgetSize.toStringAsFixed(1)}");
    debugPrint("--------------------------------------------------------");

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
                maxCrossAxisExtent: extendedTrayWidgetSize + 20, // Add padding
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: pieces.length,
              itemBuilder: (context, index) {
                final pieceData = pieces[index];
                if (placedPieces.values.contains(pieceData.id)) {
                  return const SizedBox.shrink(); // Use SizedBox.shrink() for efficiency
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

  void _resetGame() {
    Navigator.of(context).pop(); 
    _initializeGame(); 
  }

  void _showWinDialog() {
    debugPrint("--- PUZZLE COMPLETE ---");
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    int bonus = 0;
    String message = S.of(context)!.puzzleMathWin;
    if (gameProvider.puzzleTimerEnabled) {
      bonus = (_timeLeft * 2);
      message = S.of(context)!.puzzleMathWinBonus(bonus);
    }
    gameProvider.addScore(100 + bonus);
    debugPrint("GAME: Awarding win bonus. Base: 100, Time Bonus: $bonus");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.greenAccent, width: 2),
        ),
        title: Row(children: [
          const Icon(Icons.star, color: Colors.yellow, size: 30),
          const SizedBox(width: 10),
          Text(S.of(context)!.excellent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text(S.of(context)!.playAgain, style: const TextStyle(color: Colors.cyanAccent)),
            onPressed: _resetGame,
          ),
          TextButton(
            child: Text(S.of(context)!.backToMenu, style: const TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(ctx); 
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
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

class PuzzlePieceData {
  final int id;
  final MathProblem problem;
  final int row;
  final int col;
  int rotation; 

  PuzzlePieceData({
    required this.id,
    required this.problem,
    required this.row,
    required this.col,
    this.rotation = 0,
  });

  String get problemExpression => problem.expression;
  int get answer => problem.answer;
}

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
    // The widget's total size must include room for bumps on both sides
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
              padding: const EdgeInsets.all(8),
              // Make the text box proportional to the piece size
              width: pieceSize.width * 0.8,
              height: pieceSize.height * 0.5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.problemExpression,
                  style: SpaceTheme.titleStyle.copyWith(
                    color: SpaceTheme.starYellow,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
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
  final VoidCallback? onRemove;

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
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final totalImageWidth = pieceSize.width * columns;
    final totalImageHeight = pieceSize.height * rows;
    
    // This calculates where this piece's section starts in the full image
    final imageOffsetX = -(data.col * pieceSize.width);
    final imageOffsetY = -(data.row * pieceSize.height);
    
    final bumpSize = math.min(pieceSize.width, pieceSize.height) / 4;
    final extendedWidgetWidth = pieceSize.width + (bumpSize * 2);
    final extendedWidgetHeight = pieceSize.height + (bumpSize * 2);

    // REFACTORED: Verbose logging for piece widget rendering
    debugPrint("PIECE WIDGET ${data.id} (R:${data.row},C:${data.col}): "
        "CoreSize=${pieceSize.width.toStringAsFixed(1)}, "
        "ExtendedSize=${extendedWidgetWidth.toStringAsFixed(1)}, "
        "ImageOffset=(${imageOffsetX.toStringAsFixed(1)}, ${imageOffsetY.toStringAsFixed(1)})");

    return GestureDetector(
      // A placed piece can be removed, an unplaced piece can be rotated
      onTap: isPlaced ? onRemove : onRotate,
      child: SizedBox(
        width: extendedWidgetWidth,
        height: extendedWidgetHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
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
                    bumpSize: bumpSize,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The Image asset must be larger than the piece to account for bumps
                      Positioned(
                        left: imageOffsetX - bumpSize,
                        top: imageOffsetY - bumpSize,
                        width: totalImageWidth + (bumpSize * 2),
                        height: totalImageHeight + (bumpSize * 2),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Overlay to darken the image slightly
                      Container(
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!isPlaced)
              Container(
                width: pieceSize.width * 0.6,
                height: pieceSize.width * 0.4,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                  ]
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.answer.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24, // A base font size for FittedBox to scale from
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// JigsawPieceClipper remains the same as it was functionally correct.
class JigsawPieceClipper extends CustomClipper<Path> {
  final PuzzlePieceData data;
  final int columns, rows;
  final Map<String, JigsawSide> edgeShapes;
  final double bumpSize; 

  JigsawPieceClipper({
    required this.data,
    required this.columns,
    required this.rows,
    required this.edgeShapes,
    required this.bumpSize, 
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    // The core size is the widget's total size minus the bump areas on both axes
    final double coreWidth = size.width - (bumpSize * 2);
    final double coreHeight = size.height - (bumpSize * 2);

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
    
    // Start drawing from the top-left corner of the core piece area
    path.moveTo(bumpSize, bumpSize);

    _createEdgePath(path, JigsawEdge.top, topShape, coreWidth, coreHeight);
    _createEdgePath(path, JigsawEdge.right, rightShape, coreWidth, coreHeight);
    _createEdgePath(path, JigsawEdge.bottom, bottomShape, coreWidth, coreHeight);
    _createEdgePath(path, JigsawEdge.left, leftShape, coreWidth, coreHeight);

    path.close();
    return path;
  }

  void _createEdgePath(Path path, JigsawEdge edge, JigsawSide shape, double w, double h) {
    // Current position is implicitly managed by the path object
    switch (edge) {
      case JigsawEdge.top:
        if (shape == JigsawSide.flat) {
          path.lineTo(bumpSize + w, bumpSize);
        } else {
          double ySign = (shape == JigsawSide.knob) ? -1 : 1;
          path.lineTo(bumpSize + w * 0.35, bumpSize);
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
          double xSign = (shape == JigsawSide.knob) ? 1 : -1;
          path.lineTo(bumpSize + w, bumpSize + h * 0.35);
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
          double ySign = (shape == JigsawSide.knob) ? 1 : -1;
          path.lineTo(bumpSize + w * 0.65, bumpSize + h);
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
          double xSign = (shape == JigsawSide.knob) ? -1 : 1;
          path.lineTo(bumpSize, bumpSize + h * 0.65);
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

// Dialog widget (unchanged)
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