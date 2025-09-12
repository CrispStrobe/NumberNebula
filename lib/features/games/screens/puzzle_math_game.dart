import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class PuzzleMathGame extends StatefulWidget {
  final int grade;
  final int level;
  
  const PuzzleMathGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<PuzzleMathGame> createState() => _PuzzleMathGameState();
}

class _PuzzleMathGameState extends State<PuzzleMathGame>
    with TickerProviderStateMixin {
  
  late AnimationController _rotationController;
  late AnimationController _glowController;
  
  List<PuzzlePiece> puzzlePieces = [];
  List<PuzzleSlot> puzzleSlots = [];
  PuzzlePiece? draggedPiece;
  bool gameCompleted = false;
  
  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _generatePuzzle();
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }
  
  void _generatePuzzle() {
    puzzlePieces.clear();
    puzzleSlots.clear();
    gameCompleted = false;
    
    final difficulty = widget.grade + widget.level;
    final pieceCount = math.min(4 + (difficulty ~/ 2), 9);
    final random = math.Random();
    
    // Generate math problems and their solutions
    final problems = <MathProblem>[];
    for (int i = 0; i < pieceCount; i++) {
      problems.add(_generateMathProblem(difficulty, random));
    }
    
    // Create puzzle slots (stationary positions on the puzzle board)
    final gridSize = math.sqrt(pieceCount).ceil();
    final slotSize = 120.0;
    final startX = 50.0;
    final startY = 150.0;
    
    for (int i = 0; i < pieceCount; i++) {
      final row = i ~/ gridSize;
      final col = i % gridSize;
      
      puzzleSlots.add(PuzzleSlot(
        id: i,
        position: Offset(
          startX + col * (slotSize + 20),
          startY + row * (slotSize + 20),
        ),
        mathProblem: problems[i].expression,
        correctAnswer: problems[i].answer,
        size: slotSize,
        isOccupied: false,
        color: _getSlotColor(i),
      ));
    }
    
    // Create puzzle pieces (draggable pieces with answers)
    for (int i = 0; i < pieceCount; i++) {
      // Randomize piece positions on the right side
      puzzlePieces.add(PuzzlePiece(
        id: i,
        position: Offset(
          600 + random.nextDouble() * 200,
          150 + random.nextDouble() * 400,
        ),
        answer: problems[i].answer,
        size: slotSize - 10, // Slightly smaller than slots
        rotation: 0.0,
        isPlaced: false,
        color: _getPieceColor(i),
        slotId: i, // Which slot this piece belongs to
      ));
    }
    
    // Shuffle piece positions
    final shuffledPositions = puzzlePieces.map((p) => p.position).toList();
    shuffledPositions.shuffle(random);
    
    for (int i = 0; i < puzzlePieces.length; i++) {
      puzzlePieces[i].position = shuffledPositions[i];
    }
    
    setState(() {});
  }
  
  MathProblem _generateMathProblem(int difficulty, math.Random random) {
    switch (widget.grade) {
      case 3:
        return _generateGrade3Problem(random);
      case 4:
        return _generateGrade4Problem(random);
      case 5:
        return _generateGrade5Problem(random);
      case 6:
      default:
        return _generateGrade6Problem(random);
    }
  }
  
  MathProblem _generateGrade3Problem(math.Random random) {
    final operations = ['+', '-', '×'];
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case '+':
        final a = random.nextInt(15) + 5;
        final b = random.nextInt(15) + 5;
        return MathProblem('$a + $b', a + b);
      case '-':
        final a = random.nextInt(20) + 10;
        final b = random.nextInt(a);
        return MathProblem('$a - $b', a - b);
      case '×':
      default:
        final a = random.nextInt(6) + 2;
        final b = random.nextInt(6) + 2;
        return MathProblem('$a × $b', a * b);
    }
  }
  
  MathProblem _generateGrade4Problem(math.Random random) {
    final operations = ['+', '-', '×', '÷'];
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case '+':
        final a = random.nextInt(50) + 20;
        final b = random.nextInt(50) + 20;
        return MathProblem('$a + $b', a + b);
      case '-':
        final a = random.nextInt(80) + 30;
        final b = random.nextInt(a - 10) + 10;
        return MathProblem('$a - $b', a - b);
      case '×':
        final a = random.nextInt(10) + 3;
        final b = random.nextInt(10) + 3;
        return MathProblem('$a × $b', a * b);
      case '÷':
      default:
        final b = random.nextInt(10) + 3;
        final answer = random.nextInt(12) + 2;
        final a = b * answer;
        return MathProblem('$a ÷ $b', answer);
    }
  }
  
  MathProblem _generateGrade5Problem(math.Random random) {
    final operations = ['+', '-', '×', '÷'];
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case '+':
        final a = random.nextInt(150) + 50;
        final b = random.nextInt(150) + 50;
        return MathProblem('$a + $b', a + b);
      case '-':
        final a = random.nextInt(200) + 75;
        final b = random.nextInt(a - 25) + 25;
        return MathProblem('$a - $b', a - b);
      case '×':
        final a = random.nextInt(15) + 5;
        final b = random.nextInt(15) + 5;
        return MathProblem('$a × $b', a * b);
      case '÷':
      default:
        final b = random.nextInt(15) + 5;
        final answer = random.nextInt(20) + 3;
        final a = b * answer;
        return MathProblem('$a ÷ $b', answer);
    }
  }
  
  MathProblem _generateGrade6Problem(math.Random random) {
    final operations = ['+', '-', '×', '÷'];
    final operation = operations[random.nextInt(operations.length)];
    
    switch (operation) {
      case '+':
        final a = random.nextInt(300) + 100;
        final b = random.nextInt(300) + 100;
        return MathProblem('$a + $b', a + b);
      case '-':
        final a = random.nextInt(500) + 150;
        final b = random.nextInt(a - 50) + 50;
        return MathProblem('$a - $b', a - b);
      case '×':
        final a = random.nextInt(25) + 8;
        final b = random.nextInt(25) + 8;
        return MathProblem('$a × $b', a * b);
      case '÷':
      default:
        final b = random.nextInt(20) + 8;
        final answer = random.nextInt(30) + 5;
        final a = b * answer;
        return MathProblem('$a ÷ $b', answer);
    }
  }
  
  Color _getSlotColor(int index) {
    final colors = [
      SpaceTheme.deepSpace,
      SpaceTheme.nebulaPurple,
      SpaceTheme.spaceBlue,
    ];
    return colors[index % colors.length];
  }
  
  Color _getPieceColor(int index) {
    final colors = [
      SpaceTheme.planetOrange,
      SpaceTheme.alienGreen,
      SpaceTheme.cosmicPink,
      SpaceTheme.starYellow,
      SpaceTheme.moonSilver,
      Colors.cyan,
      Colors.purple,
      Colors.teal,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }
  
  void _onPieceDragStart(PuzzlePiece piece) {
    setState(() {
      draggedPiece = piece;
    });
  }
  
  void _onPieceDragUpdate(PuzzlePiece piece, Offset position) {
    setState(() {
      piece.position = position;
    });
  }
  
  void _onPieceDragEnd(PuzzlePiece piece) {
    // Check if piece is dropped on correct slot
    final correctSlot = puzzleSlots.firstWhere((slot) => slot.id == piece.slotId);
    
    final distance = (piece.position - correctSlot.position).distance;
    
    if (distance < 60 && !correctSlot.isOccupied) {
      // Snap to correct position
      setState(() {
        piece.position = correctSlot.position;
        piece.isPlaced = true;
        correctSlot.isOccupied = true;
      });
      
      context.read<GameProvider>().addScore(20);
      _checkGameCompletion();
    } else {
      // Return to original area if not placed correctly
      _returnPieceToOriginalArea(piece);
    }
    
    setState(() {
      draggedPiece = null;
    });
  }
  
  void _returnPieceToOriginalArea(PuzzlePiece piece) {
    final random = math.Random();
    setState(() {
      piece.position = Offset(
        600 + random.nextDouble() * 200,
        150 + random.nextDouble() * 400,
      );
    });
  }
  
  void _rotatePiece(PuzzlePiece piece) {
    _rotationController.forward().then((_) {
      setState(() {
        piece.rotation += math.pi / 2;
        if (piece.rotation >= 2 * math.pi) {
          piece.rotation = 0;
        }
      });
      _rotationController.reverse();
    });
  }
  
  void _checkGameCompletion() {
    final allPlaced = puzzlePieces.every((piece) => piece.isPlaced);
    if (allPlaced) {
      setState(() {
        gameCompleted = true;
      });
      
      context.read<GameProvider>().addScore(100);
      _showWinDialog();
    }
  }
  
  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SpaceTheme.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.celebration,
                size: 64,
                color: SpaceTheme.starYellow,
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context).excellent,
                style: SpaceTheme.headlineStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Space Station Complete!',
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
                    child: Text(S.of(context).playAgain),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: Text(S.of(context).nextLevel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Game UI Header
              GameUI(
                title: S.of(context).puzzleMath,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              
              // Instructions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  S.of(context).instructions['puzzleMath'] ?? '',
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Game Area
              Expanded(
                child: Stack(
                  children: [
                    // Puzzle Slots
                    ...puzzleSlots.map((slot) => PuzzleSlotWidget(
                      slot: slot,
                      glowAnimation: _glowController,
                    )),
                    
                    // Puzzle Pieces
                    ...puzzlePieces.map((piece) => PuzzlePieceWidget(
                      piece: piece,
                      onDragStart: () => _onPieceDragStart(piece),
                      onDragUpdate: (position) => _onPieceDragUpdate(piece, position),
                      onDragEnd: () => _onPieceDragEnd(piece),
                      onRotate: () => _rotatePiece(piece),
                      rotationAnimation: _rotationController,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PuzzlePiece {
  int id;
  Offset position;
  int answer;
  double size;
  double rotation;
  bool isPlaced;
  Color color;
  int slotId;
  
  PuzzlePiece({
    required this.id,
    required this.position,
    required this.answer,
    required this.size,
    required this.rotation,
    required this.isPlaced,
    required this.color,
    required this.slotId,
  });
}

class PuzzleSlot {
  int id;
  Offset position;
  String mathProblem;
  int correctAnswer;
  double size;
  bool isOccupied;
  Color color;
  
  PuzzleSlot({
    required this.id,
    required this.position,
    required this.mathProblem,
    required this.correctAnswer,
    required this.size,
    required this.isOccupied,
    required this.color,
  });
}

class PuzzlePieceWidget extends StatelessWidget {
  final PuzzlePiece piece;
  final VoidCallback onDragStart;
  final Function(Offset) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onRotate;
  final AnimationController rotationAnimation;
  
  const PuzzlePieceWidget({
    super.key,
    required this.piece,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onRotate,
    required this.rotationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: piece.position.dx - piece.size / 2,
      top: piece.position.dy - piece.size / 2,
      child: GestureDetector(
        onPanStart: (_) => onDragStart(),
        onPanUpdate: (details) => onDragUpdate(details.globalPosition),
        onPanEnd: (_) => onDragEnd(),
        onTap: onRotate,
        child: AnimatedBuilder(
          animation: rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: piece.rotation + (rotationAnimation.value * math.pi / 2),
              child: Container(
                width: piece.size,
                height: piece.size,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      piece.color,
                      piece.color.withOpacity(0.8),
                      piece.color.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: piece.color.withOpacity(0.5),
                      blurRadius: piece.isPlaced ? 5 : 15,
                      spreadRadius: piece.isPlaced ? 1 : 3,
                    ),
                  ],
                  border: Border.all(
                    color: SpaceTheme.starYellow,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -piece.rotation - (rotationAnimation.value * math.pi / 2), // Keep text upright
                    child: Text(
                      piece.answer.toString(),
                      style: SpaceTheme.headlineStyle.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PuzzleSlotWidget extends StatelessWidget {
  final PuzzleSlot slot;
  final AnimationController glowAnimation;
  
  const PuzzleSlotWidget({
    super.key,
    required this.slot,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: slot.position.dx - slot.size / 2,
      top: slot.position.dy - slot.size / 2,
      child: AnimatedBuilder(
        animation: glowAnimation,
        builder: (context, child) {
          return Container(
            width: slot.size,
            height: slot.size,
            decoration: BoxDecoration(
              color: slot.isOccupied 
                  ? SpaceTheme.correctAnswer.withOpacity(0.3)
                  : slot.color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: slot.isOccupied 
                    ? SpaceTheme.correctAnswer
                    : SpaceTheme.starYellow.withOpacity(glowAnimation.value),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: slot.isOccupied 
                      ? SpaceTheme.correctAnswer.withOpacity(0.3)
                      : SpaceTheme.starYellow.withOpacity(glowAnimation.value * 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                slot.mathProblem,
                style: SpaceTheme.titleStyle.copyWith(
                  fontSize: 16,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

class MathProblem {
  final String expression;
  final int answer;
  
  MathProblem(this.expression, this.answer);
}