import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import '../../../core/theme/space_theme.dart';
import '../constants/app_constants.dart';
import '../../../generated/l10n.dart';
import '../models/math_problem.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';

class CargoBayArrangerGame extends StatefulWidget {
  final int grade;
  final int level;

  const CargoBayArrangerGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<CargoBayArrangerGame> createState() => _CargoBayArrangerGameState();
}

class _CargoBayArrangerGameState extends State<CargoBayArrangerGame>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _clearController;
  late Animation<double> _clearAnimation;
  late AnimationController _lockController;
  late Animation<double> _lockAnimation;
  
  // Game Constants
  static const int gridRows = 18;
  static const int gridCols = 8;
  
  // Game State
  late List<List<CargoCube?>> grid;
  CargoPiece? currentPiece;
  CargoPiece? nextPiece;
  late int targetSum;
  late int numberMin;
  late int numberMax;
  late int dropSpeed; // milliseconds
  late int rowsToWin;
  
  int score = 0;
  int rowsCleared = 0;
  int combo = 0;
  bool gameActive = true;
  bool hasWon = false;
  bool hasLost = false;
  Timer? dropTimer;
  
  // Visual Effects
  List<CargoParticle> particles = [];
  Set<int> clearingRows = {};

  Ticker? _particleTicker;
  double _lastTickTime = 0;

  @override
  void initState() {
    super.initState();
    debugPrint("📦 [CargoBay] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _initializeGameParameters();
    _initializeGrid();

    _particleTicker = createTicker(_updateParticles)..start();

    _spawnNewPiece();
    _startDropTimer();
  }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _clearController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _clearAnimation =
        CurvedAnimation(parent: _clearController, curve: Curves.easeOut);

    _lockController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _lockAnimation =
        CurvedAnimation(parent: _lockController, curve: Curves.easeInOut);
  }

  void _initializeGameParameters() {
    final complexity = widget.grade + (widget.level / 5.0);
    
    if (complexity <= 2.5) {
      numberMin = 1; numberMax = 5; targetSum = 12; dropSpeed = 800; rowsToWin = 10;
    } else if (complexity <= 3.5) {
      numberMin = 1; numberMax = 7; targetSum = 18; dropSpeed = 700; rowsToWin = 12;
    } else if (complexity <= 4.5) {
      numberMin = 1; numberMax = 9; targetSum = 24; dropSpeed = 600; rowsToWin = 15;
    } else if (complexity <= 5.5) {
      numberMin = 2; numberMax = 12; targetSum = 32; dropSpeed = 500; rowsToWin = 18;
    } else if (complexity <= 6.5) {
      numberMin = 3; numberMax = 15; targetSum = 40; dropSpeed = 400; rowsToWin = 20;
    } else {
      numberMin = 5; numberMax = 20; targetSum = 50; dropSpeed = 350; rowsToWin = 25;
    }
    
    debugPrint("📦 [CargoBay] Numbers: $numberMin-$numberMax, Target Sum: $targetSum, Rows to Win: $rowsToWin");
  }

  void _initializeGrid() {
    grid = List.generate(
      gridRows,
      (_) => List.filled(gridCols, null),
    );
  }

  void _spawnNewPiece() {
    setState(() {
      if (nextPiece == null) {
        currentPiece = CargoPiece.random(numberMin, numberMax, gridCols);
        nextPiece = CargoPiece.random(numberMin, numberMax, gridCols);
      } else {
        currentPiece = nextPiece;
        nextPiece = CargoPiece.random(numberMin, numberMax, gridCols);
      }

      if (_checkCollision(currentPiece!.x, currentPiece!.y, currentPiece!.shape)) {
        _handleGameOver();
      }
    });
  }

  void _startDropTimer() {
    dropTimer?.cancel();
    dropTimer = Timer.periodic(Duration(milliseconds: dropSpeed), (timer) {
      if (gameActive) {
        _movePieceDown();
      }
    });
  }

  // #region Game Actions & Controls

  void _movePieceDown() {
    if (currentPiece == null || !gameActive) return;
    
    if (!_checkCollision(currentPiece!.x, currentPiece!.y + 1, currentPiece!.shape)) {
      setState(() {
        currentPiece!.y++;
      });
    } else {
      _lockPiece();
    }
  }

  void _movePieceLeft() {
    if (currentPiece == null || !gameActive) return;
    
    if (!_checkCollision(currentPiece!.x - 1, currentPiece!.y, currentPiece!.shape)) {
      setState(() {
        currentPiece!.x--;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _movePieceRight() {
    if (currentPiece == null || !gameActive) return;
    
    if (!_checkCollision(currentPiece!.x + 1, currentPiece!.y, currentPiece!.shape)) {
      setState(() {
        currentPiece!.x++;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _hardDrop() {
    if (currentPiece == null || !gameActive) return;
    
    int cellsDropped = 0;
    while (!_checkCollision(currentPiece!.x, currentPiece!.y + 1, currentPiece!.shape)) {
      currentPiece!.y++;
      cellsDropped++;
    }
    
    setState(() {
      score += cellsDropped;
    });

    _lockPiece();
    HapticFeedback.mediumImpact();
  }

  void _rotatePiece() {
    if (currentPiece == null || !gameActive) return;

    final rotatedShape = _rotateShape(currentPiece!.shape);
    final rotatedCubes = _rotateCubes(currentPiece!.cubes);

    final testOffsets = [
      const Offset(0, 0), const Offset(-1, 0), const Offset(1, 0),
      const Offset(-2, 0), const Offset(2, 0),
    ];

    for (final offset in testOffsets) {
      final newX = currentPiece!.x + offset.dx.toInt();
      final newY = currentPiece!.y + offset.dy.toInt();
      if (!_checkCollision(newX, newY, rotatedShape)) {
        setState(() {
          currentPiece!.x = newX;
          currentPiece!.y = newY;
          currentPiece!.shape = rotatedShape;
          currentPiece!.cubes = rotatedCubes;
        });
        HapticFeedback.lightImpact();
        return;
      }
    }
  }
  // #endregion

  // #region Core Game Logic

  bool _checkCollision(int x, int y, List<List<bool>> shape) {
    for (int shapeY = 0; shapeY < shape.length; shapeY++) {
      for (int shapeX = 0; shapeX < shape[shapeY].length; shapeX++) {
        if (!shape[shapeY][shapeX]) continue;

        int projectedX = x + shapeX;
        int projectedY = y + shapeY;

        if (projectedX < 0 || projectedX >= gridCols || projectedY >= gridRows) {
          return true;
        }
        if (projectedY >= 0 && grid[projectedY][projectedX] != null) {
          return true;
        }
      }
    }
    return false;
  }

  void _lockPiece() {
    if (currentPiece == null) return;
    
    debugPrint("📦 [Lock] Piece locked at (${currentPiece!.x}, ${currentPiece!.y}).");
    _lockController.forward(from: 0.0);
    
    bool toppedOut = false;
    for (int i = 0; i < currentPiece!.shape.length; i++) {
        if (toppedOut) break;
        for (int j = 0; j < currentPiece!.shape[i].length; j++) {
            if (currentPiece!.shape[i][j]) {
                if (currentPiece!.y + i < 0) {
                    toppedOut = true;
                    break;
                }
            }
        }
    }

    if (toppedOut) {
        debugPrint("📦 [GameOver] Game over due to topping out.");
        _handleGameOver();
        return;
    }

    setState(() {
      for (int i = 0; i < currentPiece!.shape.length; i++) {
        for (int j = 0; j < currentPiece!.shape[i].length; j++) {
          if (currentPiece!.shape[i][j]) {
            final gridX = currentPiece!.x + j;
            final gridY = currentPiece!.y + i;
            if (gridY >= 0 && gridY < gridRows && gridX >= 0 && gridX < gridCols) {
              grid[gridY][gridX] = currentPiece!.cubes[i][j];
            }
          }
        }
      }
      currentPiece = null;
    });
    
    _checkAndClearRows();
    
    if (gameActive) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && gameActive) _spawnNewPiece();
      });
    }
  }

  /// NEW GAME LOGIC: Any full row is cleared. Bonuses are checked.
  void _checkAndClearRows() {
    final fullRows = <int>[];
    for (int row = gridRows - 1; row >= 0; row--) {
      if (grid[row].every((cell) => cell != null)) {
        fullRows.add(row);
      }
    }
    
    if (fullRows.isEmpty) {
      combo = 0;
      return;
    }
    
    // --- NEW LOGIC STARTS HERE ---
    combo++;
    int totalBonus = 0;

    for (final row in fullRows) {
      final numbers = grid[row].map((cube) => cube!.value).toList();
      int rowBonus = 0;

      // Check for different math bonuses
      if (_isTargetSum(numbers)) {
        debugPrint("📦 [Evaluate] Row $row got TARGET SUM bonus!");
        rowBonus += 500;
      }
      if (_isSequence(numbers)) {
        debugPrint("📦 [Evaluate] Row $row got SEQUENCE bonus!");
        rowBonus += 800;
      }
      if (_isPrimeRow(numbers)) {
        debugPrint("📦 [Evaluate] Row $row got PRIME bonus!");
        rowBonus += 1200;
      }
      totalBonus += rowBonus;
    }

    final basePoints = 100 * fullRows.length * fullRows.length;
    final comboBonus = combo > 1 ? (combo - 1) * 50 * fullRows.length : 0;
    
    setState(() {
      score += basePoints + comboBonus + totalBonus;
      rowsCleared += fullRows.length;
      clearingRows.addAll(fullRows);
    });

    _clearController.forward(from: 0.0);
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          fullRows.sort((a, b) => b.compareTo(a));
          for (final row in fullRows) {
            grid.removeAt(row);
            grid.insert(0, List.filled(gridCols, null));
          }
          clearingRows.clear();
        });
        _checkWinCondition();
      }
    });
  }

  // #region Bonus Check Functions
  bool _isTargetSum(List<int> numbers) {
    return numbers.reduce((a, b) => a + b) == targetSum;
  }

  bool _isSequence(List<int> numbers) {
    List<int> sorted = List.from(numbers)..sort();
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i+1] != sorted[i] + 1) {
        return false;
      }
    }
    return true;
  }

  bool _isPrime(int n) {
    if (n <= 1) return false;
    for (int i = 2; i * i <= n; i++) {
      if (n % i == 0) return false;
    }
    return true;
  }

  bool _isPrimeRow(List<int> numbers) {
    return numbers.every(_isPrime);
  }
  // #endregion

  List<List<T>> _rotateMatrix<T>(List<List<T>> matrix) {
    if (matrix.isEmpty || matrix[0].isEmpty) return matrix;
    final oldRows = matrix.length;
    final oldCols = matrix[0].length;
    
    return List.generate(oldCols, (j) => 
        List.generate(oldRows, (i) => matrix[oldRows - 1 - i][j])
    );
  }
  
  List<List<bool>> _rotateShape(List<List<bool>> shape) => _rotateMatrix(shape);
  List<List<CargoCube?>> _rotateCubes(List<List<CargoCube?>> cubes) => _rotateMatrix(cubes);

  // #endregion

  // #region Game State Management (Win/Loss)

  void _checkWinCondition() {
    if (rowsCleared >= rowsToWin && gameActive) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    if (!gameActive) return;
    debugPrint("🎉 [CargoBay] Success! All cargo organized!");
    
    setState(() { gameActive = false; hasWon = true; });
    dropTimer?.cancel();
    HapticFeedback.heavyImpact();
    
    final totalScore = score + (200 * widget.grade) + ((rowsCleared - rowsToWin) * 50);
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'cargo_bay_arranger', scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5), wasSuccessful: true,
    );
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        showDialog(context: context, barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, (rowsCleared - rowsToWin) * 50),
        );
      }
    });
  }

  void _handleGameOver() {
    if (!gameActive) return;
    debugPrint("❌ [CargoBay] Game Over - Bay overloaded");

    setState(() { gameActive = false; hasLost = true; currentPiece = null; });
    dropTimer?.cancel();
    HapticFeedback.heavyImpact();
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'cargo_bay_arranger', scoreGained: 0,
      difficulty: widget.grade + (widget.level ~/ 5), wasSuccessful: false,
    );
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        showDialog(context: context, barrierDismissible: false,
          builder: (context) => _buildFailureDialog(),
        );
      }
    });
  }

  void _resetGame() {
    setState(() {
      gameActive = true; hasWon = false; hasLost = false;
      score = 0; rowsCleared = 0; combo = 0;
      particles.clear(); clearingRows.clear();
    });
    
    _initializeGrid();
    _spawnNewPiece();
    _startDropTimer();
  }

  // #endregion

  // #region Particle System
  void _updateParticles(Duration elapsed) {
    if (_lastTickTime == 0) {
      _lastTickTime = elapsed.inMilliseconds.toDouble();
      return;
    }
    final double dt = (elapsed.inMilliseconds.toDouble() - _lastTickTime) / 1000.0;
    _lastTickTime = elapsed.inMilliseconds.toDouble();

    if (particles.isNotEmpty) {
      particles.removeWhere((p) => p.update(dt));
      setState(() {});
    }
  }
  // #endregion

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => CustomPaint(
                    painter: CargoBayPainter(
                        pulseIntensity: _pulseAnimation.value,
                        gameWon: hasWon,
                        gameLost: hasLost),
                  ),
                ),
              ),
              
              ...particles.map((p) => p.build()).toList(),
              
              Column(
                children: [
                  GameUI(
                    title: S.of(context)!.cargoBayTitle,
                    level: widget.level,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildStat(Icons.flag_outlined, '$rowsCleared/$rowsToWin', SpaceTheme.alienGreen),
                        _buildTargetStat(),
                        _buildStat(Icons.star, score.toString(), SpaceTheme.starYellow),
                        if (combo > 1)
                          _buildStat(Icons.whatshot, '×$combo', SpaceTheme.cosmicPink),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final sidePanelWidth = 112.0;
                        final maxCellW = (constraints.maxWidth - sidePanelWidth - 4) / gridCols; // ALIGNMENT FIX
                        final maxCellH = (constraints.maxHeight - 4) / gridRows;
                        final cellSize = math.min(maxCellW, maxCellH);

                        if(kDebugMode) {
                            if ( (cellSize - maxCellH).abs() > 2) { // Only log if constrained by width
                              debugPrint("📦 [Layout] Constraints: ${constraints.maxWidth.toStringAsFixed(1)}x${constraints.maxHeight.toStringAsFixed(1)}");
                              debugPrint("📦 [Layout] CellSize by Width: ${maxCellW.toStringAsFixed(1)}, by Height: ${maxCellH.toStringAsFixed(1)}");
                              debugPrint("📦 [Layout] Final Cell Size: ${cellSize.toStringAsFixed(1)}");
                            }
                        }
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: cellSize * gridCols + 4,
                              height: cellSize * gridRows + 4,
                              decoration: BoxDecoration(
                                border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.5), width: 2),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black.withOpacity(0.3)
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(cellSize * gridCols, cellSize * gridRows),
                                      painter: GridPainter(cellSize: cellSize, intensity: _pulseAnimation.value),
                                    ),
                                    ..._buildPlacedCubes(cellSize),
                                    ..._buildCurrentPiece(cellSize),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: SpaceTheme.cardDecoration,
                                    child: Column(
                                      children: [
                                        Text(
                                          S.of(context)!.cargoBayNext,
                                          style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildNextPiecePreview(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  if (gameActive) ...[
                    const SizedBox(height: 16),
                    _buildControls(),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 80),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // #region Widget Builders

  List<Widget> _buildPlacedCubes(double cellSize) {
    List<Widget> cubes = [];
    if (cellSize <= 0) return cubes;
    for (int row = 0; row < gridRows; row++) {
      for (int col = 0; col < gridCols; col++) {
        if (grid[row][col] != null) {
          cubes.add(
            Positioned(
              left: col * cellSize,
              top: row * cellSize,
              child: _buildCube(
                grid[row][col]!, cellSize,
                isClearing: clearingRows.contains(row),
              ),
            ),
          );
        }
      }
    }
    return cubes;
  }

  List<Widget> _buildCurrentPiece(double cellSize) {
    if (currentPiece == null || cellSize <= 0) return [];
    
    List<Widget> pieceWidgets = [];
    for (int i = 0; i < currentPiece!.shape.length; i++) {
      for (int j = 0; j < currentPiece!.shape[i].length; j++) {
        if (currentPiece!.shape[i][j]) {
          pieceWidgets.add(
            Positioned(
              left: (currentPiece!.x + j) * cellSize,
              top: (currentPiece!.y + i) * cellSize,
              child: _buildCube(currentPiece!.cubes[i][j]!, cellSize),
            ),
          );
        }
      }
    }
    return pieceWidgets;
  }
  
  Widget _buildCube(CargoCube cube, double size, {bool isClearing = false}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_clearAnimation, _lockAnimation]),
      builder: (context, child) {
        final opacity = isClearing ? (1.0 - _clearAnimation.value) : 1.0;
        final scale = isClearing ? (1.0 + _clearAnimation.value * 0.5) : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(cube.color, Colors.white, 0.1)!,
                    cube.color,
                    Color.lerp(cube.color, Colors.black, 0.2)!,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(size * 0.15),
                border: Border.all(
                  color: Colors.black.withOpacity(0.2),
                  width: 1.0,
                ),
                boxShadow: isClearing ? [
                  BoxShadow(color: SpaceTheme.alienGreen.withOpacity(0.7), blurRadius: 12, spreadRadius: 3),
                ] : [
                  BoxShadow(color: Colors.black.withOpacity(0.5), spreadRadius: 1, blurRadius: 3, offset: const Offset(2, 2))
                ],
              ),
              child: Center(
                child: Text(
                  cube.value.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.bold,
                    shadows: [const Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1, 1))]
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextPiecePreview() {
    if (nextPiece == null) return const SizedBox(height: 80, width: 80);
    
    final previewCellSize = 20.0;
    
    return SizedBox(
      height: 80,
      width: 80,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(nextPiece!.shape.length, (i) {
          return List.generate(nextPiece!.shape[i].length, (j) {
            if (nextPiece!.shape[i][j]) {
              return Positioned(
                left: j * previewCellSize + (40 - nextPiece!.shape[0].length / 2 * previewCellSize),
                top: i * previewCellSize + (40 - nextPiece!.shape.length / 2 * previewCellSize),
                child: _buildCube(nextPiece!.cubes[i][j]!, previewCellSize),
              );
            }
            return const SizedBox.shrink();
          });
        }).expand((e) => e).toList(),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row( mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16), const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildTargetStat() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.planetOrange.withOpacity(0.3)),
      ),
      child: Row( mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.adjust, color: SpaceTheme.planetOrange, size: 16), const SizedBox(width: 4),
          Text('∑=$targetSum', style: const TextStyle(color: SpaceTheme.planetOrange, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.arrow_back, _movePieceLeft),
          _buildControlButton(Icons.arrow_downward, _hardDrop),
          _buildControlButton(Icons.arrow_forward, _movePieceRight),
          _buildControlButton(Icons.rotate_right, _rotatePiece),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withOpacity(0.3),
        foregroundColor: SpaceTheme.alienGreen,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: SpaceTheme.alienGreen.withOpacity(0.3)),
        ),
      ),
      child: Icon(icon, size: 24),
    );
  }

  Widget _buildSuccessDialog(int totalScore, int rowBonus) {
    return Dialog(backgroundColor: Colors.transparent, child: Container(
        padding: const EdgeInsets.all(24), decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
        ),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 60, color: SpaceTheme.alienGreen), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayWinDesc(rowsCleared, totalScore, rowBonus), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center), const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Flexible(child: ElevatedButton(onPressed: () {Navigator.of(context).pop(); _resetGame();}, style: SpaceTheme.secondaryButtonStyle, child: Text(S.of(context)!.nextShipment, textAlign: TextAlign.center))),
                const SizedBox(width: 12),
                Flexible(child: ElevatedButton(onPressed: () {Navigator.of(context).pop(); Navigator.of(context).pop();}, style: SpaceTheme.primaryButtonStyle, child: Text(S.of(context)!.toTheBridge, textAlign: TextAlign.center))),
            ]),
        ])),
    ));
  }

  Widget _buildFailureDialog() {
    return Dialog(backgroundColor: Colors.transparent, child: Container(
        padding: const EdgeInsets.all(24), decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning, size: 60, color: SpaceTheme.rocketRed), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayLoseTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayLoseDesc, style: SpaceTheme.bodyStyle, textAlign: TextAlign.center), const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Flexible(child: ElevatedButton(onPressed: () {Navigator.of(context).pop(); _resetGame();}, style: SpaceTheme.secondaryButtonStyle, child: Text(S.of(context)!.tryAgain, textAlign: TextAlign.center))),
                const SizedBox(width: 12),
                Flexible(child: ElevatedButton(onPressed: () {Navigator.of(context).pop(); Navigator.of(context).pop();}, style: SpaceTheme.primaryButtonStyle, child: Text(S.of(context)!.toTheBridge, textAlign: TextAlign.center))),
            ]),
        ])),
    ));
  }
  // #endregion

  @override
  void dispose() {
    dropTimer?.cancel();
    _particleTicker?.dispose();
    _pulseController.dispose();
    _clearController.dispose();
    _lockController.dispose();
    super.dispose();
  }
}

// #region Data Models & Game Pieces

class CargoCube {
  final int value;
  final Color color;
  bool isLocked;

  CargoCube({required this.value, required this.color, this.isLocked = false});
}

class CargoPiece {
  int x; int y;
  List<List<bool>> shape;
  List<List<CargoCube?>> cubes;

  CargoPiece({required this.x, required this.y, required this.shape, required this.cubes});

  static CargoPiece random(int minValue, int maxValue, int gridCols) {
    final random = math.Random();
    
    final shapes = [
      [[false, false, false, false], [true, true, true, true], [false, false, false, false], [false, false, false, false]],
      [[true, true], [true, true]],
      [[false, true, false], [true, true, true], [false, false, false]],
      [[false, false, true], [true, true, true], [false, false, false]],
      [[true, false, false], [true, true, true], [false, false, false]],
      [[false, true, true], [true, true, false], [false, false, false]],
      [[true, true, false], [false, true, true], [false, false, false]],
    ];
    
    final colors = [
      Colors.cyan.shade300, Colors.yellow.shade400, Colors.purple.shade300, Colors.orange.shade400,
      Colors.blue.shade300, Colors.green.shade300, Colors.red.shade300,
    ];
    
    final shapeIndex = random.nextInt(shapes.length);
    final shape = shapes[shapeIndex];
    final color = colors[shapeIndex % colors.length];
    
    final cubes = List.generate(shape.length, (i) => List.generate(shape[i].length, (j) {
        if (shape[i][j]) {
          return CargoCube(value: minValue + random.nextInt(maxValue - minValue + 1), color: color);
        }
        return null;
    }));
    
    return CargoPiece(
      x: (gridCols ~/ 2) - (shape[0].length ~/ 2),
      y: -2,
      shape: shape,
      cubes: cubes,
    );
  }
}
// #endregion

// #region Visual Effects & Particles

class CargoParticle {
  Offset position; Offset velocity; Color color;
  double size; double life; final double maxLife;

  CargoParticle({required this.position, required this.velocity, required this.color, required this.size, required this.life}) : maxLife = life;

  factory CargoParticle.success(Offset pos) {
    final random = math.Random();
    return CargoParticle(
      position: pos,
      velocity: Offset.fromDirection(random.nextDouble() * 2 * math.pi, 20 + random.nextDouble() * 40),
      color: SpaceTheme.alienGreen, size: 2 + random.nextDouble() * 3,
      life: 0.6 + random.nextDouble() * 0.4,
    );
  }

  factory CargoParticle.warning(Offset pos) {
    final random = math.Random();
    return CargoParticle(
      position: pos,
      velocity: Offset.fromDirection(random.nextDouble() * 2 * math.pi - math.pi / 2, 15 + random.nextDouble() * 20),
      color: SpaceTheme.rocketRed, size: 3 + random.nextDouble() * 2,
      life: 0.5 + random.nextDouble() * 0.3,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    velocity = velocity.scale(1.0, 1.05); // Gravity
    life -= dt;
    return life <= 0;
  }

  Widget build() {
    final opacity = (life / maxLife).clamp(0.0, 1.0);
    return Positioned(
      left: position.dx - size / 2, top: position.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity * 0.8), shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(opacity * 0.5), blurRadius: size * 1.5)],
          ),
        ),
      ),
    );
  }
}
// #endregion

// #region Custom Painters

class CargoBayPainter extends CustomPainter {
  final double pulseIntensity;
  final bool gameWon; final bool gameLost;

  CargoBayPainter({required this.pulseIntensity, required this.gameWon, required this.gameLost});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: size.width * 0.7,
        colors: const [
          Color(0xFF333844),
          Color(0xFF232834),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final beamPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 35.0;
    canvas.drawLine(const Offset(-50, 50), Offset(size.width * 0.4, size.height + 50), beamPaint);
    canvas.drawLine(Offset(size.width + 50, 50), Offset(size.width * 0.6, size.height + 50), beamPaint);

    final hazardPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6;
    for (int i = 0; i < 4; i++) {
      hazardPaint.color = i.isEven ? Colors.yellow.shade600 : Colors.black.withOpacity(0.8);
      final offset = i * 8.0;
      canvas.drawLine(Offset(0, 40 + offset), Offset(40 + offset, 0), hazardPaint);
      canvas.drawLine(Offset(size.width, size.height - 40 - offset), Offset(size.width - 40 - offset, size.height), hazardPaint);
    }
  }

  @override
  bool shouldRepaint(CargoBayPainter oldDelegate) => oldDelegate.pulseIntensity != pulseIntensity;
}

class GridPainter extends CustomPainter {
  final double cellSize; final double intensity;

  GridPainter({required this.cellSize, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (cellSize <= 0) return;
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.2 + (intensity * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);
    
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => oldDelegate.cellSize != cellSize || oldDelegate.intensity != intensity;
}
// #endregion