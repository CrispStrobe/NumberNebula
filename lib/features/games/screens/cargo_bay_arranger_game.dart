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
  late AnimationController _bonusController;
  late Animation<double> _bonusAnimation;
  
  // Game Constants
  static const int gridRows = 18;
  static const int gridCols = 8;
  
  // Game State
  late List<List<CargoCube?>> grid;
  CargoPiece? currentPiece;
  CargoPiece? nextPiece;
  CargoPiece? heldPiece;
  bool hasUsedHold = false;
  bool showBonusPanel = false;
  
  late int numberMin;
  late int numberMax;
  late int targetSum;
  late int dropSpeed;
  late int rowsToWin;
  
  int score = 0;
  int rowsCleared = 0;
  int bonusesEarned = 0;
  int combo = 0;
  bool gameActive = true;
  bool hasWon = false;
  bool hasLost = false;
  Timer? dropTimer;
  
  // Touch controls
  Offset? _dragStartPosition;
  int _dragStartX = 0;
  int _dragStartY = 0;
  bool _isDragging = false;
  
  // Bonus tracking
  Map<BonusType, int> bonusCount = {};
  List<BonusEffect> activeEffects = [];
  Set<String> awardedBonuses = {};
  
  // Visual Effects
  List<CargoParticle> particles = [];
  Set<int> clearingRows = {};
  List<BonusNotification> bonusNotifications = [];
  Ticker? _particleTicker;
  double _lastTickTime = 0;
  
  // Keyboard
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    debugPrint("📦 [CargoBay] Initializing game - Grade: ${widget.grade}, Level: ${widget.level}");
    
    _setupAnimationControllers();
    _initializeGameParameters();
    _initializeGrid();
    _initializeBonusTracking();

    _particleTicker = createTicker(_updateParticles)..start();

    _spawnNewPiece();
    _startDropTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
        
    _bonusController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bonusAnimation =
        CurvedAnimation(parent: _bonusController, curve: Curves.elasticOut);
  }

  void _initializeGameParameters() {
    final complexity = widget.grade + (widget.level / 5.0);
    
    // Progressive difficulty
    if (complexity <= 2.0) {
      numberMin = 1; numberMax = 5; targetSum = 15; dropSpeed = 1000; rowsToWin = 8;
    } else if (complexity <= 3.0) {
      numberMin = 1; numberMax = 7; targetSum = 21; dropSpeed = 900; rowsToWin = 10;
    } else if (complexity <= 4.0) {
      numberMin = 1; numberMax = 9; targetSum = 28; dropSpeed = 800; rowsToWin = 12;
    } else if (complexity <= 5.0) {
      numberMin = 1; numberMax = 12; targetSum = 36; dropSpeed = 700; rowsToWin = 14;
    } else if (complexity <= 6.0) {
      numberMin = 2; numberMax = 15; targetSum = 48; dropSpeed = 600; rowsToWin = 16;
    } else if (complexity <= 7.0) {
      numberMin = 3; numberMax = 18; targetSum = 60; dropSpeed = 500; rowsToWin = 18;
    } else {
      numberMin = 5; numberMax = 20; targetSum = 75; dropSpeed = 400; rowsToWin = 20;
    }
    
    debugPrint("📦 [CargoBay] Numbers: $numberMin-$numberMax, Target: $targetSum, Speed: ${dropSpeed}ms, Rows: $rowsToWin");
  }

  void _initializeGrid() {
    grid = List.generate(
      gridRows,
      (_) => List.filled(gridCols, null),
    );
  }

  void _initializeBonusTracking() {
    for (var type in BonusType.values) {
      bonusCount[type] = 0;
    }
  }

  void _spawnNewPiece() {
    setState(() {
      hasUsedHold = false;
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
      if (gameActive && !_isDragging) {
        _movePieceDown();
      }
    });
  }

  // Touch Control Methods
  void _handleTapOnGrid(Offset localPosition, double cellSize) {
    if (!gameActive || currentPiece == null) return;
    
    // Calculate grid position
    final gridX = (localPosition.dx / cellSize).floor();
    final gridY = (localPosition.dy / cellSize).floor();
    
    // Check if tap is on current piece
    bool tappedOnPiece = false;
    for (int i = 0; i < currentPiece!.shape.length; i++) {
      for (int j = 0; j < currentPiece!.shape[i].length; j++) {
        if (currentPiece!.shape[i][j]) {
          final pieceX = currentPiece!.x + j;
          final pieceY = currentPiece!.y + i;
          if (pieceX == gridX && pieceY == gridY) {
            tappedOnPiece = true;
            break;
          }
        }
      }
      if (tappedOnPiece) break;
    }
    
    if (tappedOnPiece) {
      _rotatePiece();
    }
  }

  void _handlePanStart(DragStartDetails details, double cellSize) {
    if (!gameActive || currentPiece == null) return;
    
    _dragStartPosition = details.localPosition;
    _dragStartX = currentPiece!.x;
    _dragStartY = currentPiece!.y;
    _isDragging = true;
  }

  void _handlePanUpdate(DragUpdateDetails details, double cellSize) {
    if (!gameActive || currentPiece == null || _dragStartPosition == null) return;
    
    final delta = details.localPosition - _dragStartPosition!;
    final cellsMoved = (delta.dx / cellSize).round();
    final cellsDropped = (delta.dy / cellSize).floor();
    
    // Horizontal movement
    if (cellsMoved != 0) {
      final newX = _dragStartX + cellsMoved;
      if (!_checkCollision(newX, currentPiece!.y, currentPiece!.shape)) {
        setState(() {
          currentPiece!.x = newX;
        });
      }
    }
    
    // Vertical movement (only down)
    if (cellsDropped > 0) {
      final newY = _dragStartY + cellsDropped;
      if (!_checkCollision(currentPiece!.x, newY, currentPiece!.shape)) {
        setState(() {
          currentPiece!.y = newY;
          score += cellsDropped; // Soft drop points
        });
      } else {
        // Hit bottom, lock piece
        _lockPiece();
        _isDragging = false;
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    _dragStartPosition = null;
    
    // If swiped down fast, do hard drop
    if (details.velocity.pixelsPerSecond.dy > 500 && currentPiece != null) {
      _hardDrop();
    }
  }

  // Game Actions
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !gameActive) return;
    
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _movePieceLeft();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _movePieceRight();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _movePieceDown();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _rotatePiece();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _hardDrop();
    } else if (event.logicalKey == LogicalKeyboardKey.keyC || 
               event.logicalKey == LogicalKeyboardKey.shift) {
      _holdPiece();
    }
  }

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
      score += cellsDropped * 2;
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

  void _holdPiece() {
    if (currentPiece == null || !gameActive || hasUsedHold) return;
    
    setState(() {
      if (heldPiece == null) {
        heldPiece = currentPiece;
        heldPiece!.x = (gridCols ~/ 2) - (heldPiece!.shape[0].length ~/ 2);
        heldPiece!.y = -2;
        _spawnNewPiece();
      } else {
        var temp = currentPiece;
        currentPiece = heldPiece;
        currentPiece!.x = (gridCols ~/ 2) - (currentPiece!.shape[0].length ~/ 2);
        currentPiece!.y = -2;
        heldPiece = temp;
        heldPiece!.x = (gridCols ~/ 2) - (heldPiece!.shape[0].length ~/ 2);
        heldPiece!.y = -2;
      }
      hasUsedHold = true;
    });
    HapticFeedback.lightImpact();
  }

  // Core Game Logic
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

  int _getGhostY() {
    if (currentPiece == null) return 0;
    
    int ghostY = currentPiece!.y;
    while (!_checkCollision(currentPiece!.x, ghostY + 1, currentPiece!.shape)) {
      ghostY++;
    }
    return ghostY;
  }

  void _lockPiece() {
    if (currentPiece == null) return;
    
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
        _handleGameOver();
        return;
    }

    final affectedRows = <int>{};
    final affectedCols = <int>{};

    setState(() {
      for (int i = 0; i < currentPiece!.shape.length; i++) {
        for (int j = 0; j < currentPiece!.shape[i].length; j++) {
          if (currentPiece!.shape[i][j]) {
            final gridX = currentPiece!.x + j;
            final gridY = currentPiece!.y + i;
            if (gridY >= 0 && gridY < gridRows && gridX >= 0 && gridX < gridCols) {
              grid[gridY][gridX] = currentPiece!.cubes[i][j];
              affectedRows.add(gridY);
              affectedCols.add(gridX);
            }
          }
        }
      }
      currentPiece = null;
    });
    
    _checkBonusesAndClearRows(affectedRows, affectedCols);
    
    if (gameActive) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && gameActive) _spawnNewPiece();
      });
    }
  }

  void _checkBonusesAndClearRows(Set<int> affectedRows, Set<int> affectedCols) {
    final foundBonuses = _scanForBonuses(affectedRows, affectedCols);
    
    if (foundBonuses.isNotEmpty) {
      _handleBonuses(foundBonuses);
    }
    
    _checkAndClearRows();
  }

  List<BonusMatch> _scanForBonuses(Set<int> affectedRows, Set<int> affectedCols) {
    final bonuses = <BonusMatch>[];
    
    // Check only affected horizontal lines
    for (final row in affectedRows) {
      if (grid[row].every((cell) => cell != null)) {
        final values = grid[row].map((c) => c!.value).toList();
        if (values.reduce((a, b) => a + b) == targetSum) {
          final positions = List.generate(gridCols, (col) => Position(col, row));
          bonuses.add(BonusMatch(BonusType.targetSum, positions, values));
        }
      }
      
      for (int startCol = 0; startCol < gridCols; startCol++) {
        for (int len = 4; len <= gridCols - startCol; len++) {
          final result = _checkLineForSequences(row, startCol, 1, 0, len);
          if (result != null) bonuses.add(result);
        }
      }
    }
    
    // Check only affected vertical lines
    for (final col in affectedCols) {
      if (grid.every((row) => row[col] != null)) {
        final values = grid.map((row) => row[col]!.value).toList();
        if (values.reduce((a, b) => a + b) == targetSum) {
          final positions = List.generate(gridRows, (row) => Position(col, row));
          bonuses.add(BonusMatch(BonusType.targetSum, positions, values));
        }
      }
      
      for (int startRow = 0; startRow < gridRows; startRow++) {
        for (int len = 4; len <= gridRows - startRow; len++) {
          final result = _checkLineForSequences(startRow, col, 0, 1, len);
          if (result != null) bonuses.add(result);
        }
      }
    }
    
    // Check squares that overlap with affected cells
    for (final row in affectedRows) {
      for (final col in affectedCols) {
        for (int size = 3; size <= 4; size++) {
          for (int startRow = math.max(0, row - size + 1); startRow <= math.min(gridRows - size, row); startRow++) {
            for (int startCol = math.max(0, col - size + 1); startCol <= math.min(gridCols - size, col); startCol++) {
              final result = _checkSquareForSum(startRow, startCol, size);
              if (result != null) bonuses.add(result);
            }
          }
        }
      }
    }
    
    return _deduplicateBonuses(bonuses);
  }

  List<BonusMatch> _deduplicateBonuses(List<BonusMatch> bonuses) {
    final seen = <String>{};
    final unique = <BonusMatch>[];
    
    for (final bonus in bonuses) {
      final key = '${bonus.type.name}_${bonus.positions.map((p) => '${p.x},${p.y}').join('_')}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(bonus);
      }
    }
    
    return unique;
  }

  BonusMatch? _checkLineForSequences(int startRow, int startCol, int deltaCol, int deltaRow, int length) {
    final values = <int>[];
    final positions = <Position>[];
    
    for (int i = 0; i < length; i++) {
      final row = startRow + i * deltaRow;
      final col = startCol + i * deltaCol;
      
      if (row < 0 || row >= gridRows || col < 0 || col >= gridCols) return null;
      if (grid[row][col] == null) return null;
      
      values.add(grid[row][col]!.value);
      positions.add(Position(col, row));
    }
    
    if (_isFibonacci(values)) {
      if (length >= 6) return BonusMatch(BonusType.fibonacci6, positions, values);
      if (length >= 5) return BonusMatch(BonusType.fibonacci5, positions, values);
      if (length >= 4) return BonusMatch(BonusType.fibonacci4, positions, values);
    }
    
    if (_isDoubling(values)) {
      if (length >= 5) return BonusMatch(BonusType.doubling5, positions, values);
      if (length >= 4) return BonusMatch(BonusType.doubling4, positions, values);
      if (length >= 3) return BonusMatch(BonusType.doubling3, positions, values);
    }
    
    if (_isConsecutive(values)) {
      if (length >= 7) return BonusMatch(BonusType.consecutive7, positions, values);
      if (length >= 6) return BonusMatch(BonusType.consecutive6, positions, values);
      if (length >= 5) return BonusMatch(BonusType.consecutive5, positions, values);
      if (length >= 4) return BonusMatch(BonusType.consecutive4, positions, values);
    }
    
    return null;
  }

  BonusMatch? _checkSquareForSum(int startRow, int startCol, int size) {
    final values = <int>[];
    final positions = <Position>[];
    
    for (int row = startRow; row < startRow + size; row++) {
      for (int col = startCol; col < startCol + size; col++) {
        if (grid[row][col] == null) return null;
        values.add(grid[row][col]!.value);
        positions.add(Position(col, row));
      }
    }
    
    if (values.reduce((a, b) => a + b) == targetSum) {
      return BonusMatch(
        size == 3 ? BonusType.square3 : BonusType.square4, 
        positions, 
        values
      );
    }
    
    return null;
  }

  bool _isFibonacci(List<int> numbers) {
    if (numbers.length < 4) return false;
    
    final fibSequence = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89];
    
    int startIndex = -1;
    for (int i = 0; i <= fibSequence.length - numbers.length; i++) {
      if (fibSequence[i] == numbers[0] && fibSequence[i + 1] == numbers[1]) {
        startIndex = i;
        break;
      }
    }
    
    if (startIndex == -1) return false;
    
    for (int i = 0; i < numbers.length; i++) {
      if (numbers[i] != fibSequence[startIndex + i]) {
        return false;
      }
    }
    
    return true;
  }

  bool _isDoubling(List<int> numbers) {
    if (numbers.length < 3) return false;
    for (int i = 1; i < numbers.length; i++) {
      if (numbers[i] != numbers[i-1] * 2) return false;
    }
    return true;
  }

  bool _isConsecutive(List<int> numbers) {
    if (numbers.length < 4) return false;
    for (int i = 1; i < numbers.length; i++) {
      if (numbers[i] != numbers[i-1] + 1) return false;
    }
    return true;
  }

  void _handleBonuses(List<BonusMatch> bonuses) {
    if (bonuses.isEmpty) return;
    
    debugPrint("🎯 [Bonuses] Found ${bonuses.length} bonus patterns!");
    
    int totalBonus = 0;
    int newBonusesFound = 0;
    
    for (final bonus in bonuses) {
      final posKey = bonus.positions.map((p) => '${p.x},${p.y}').toList()..sort();
      final bonusKey = '${bonus.type.name}_${posKey.join('_')}';
      
      if (awardedBonuses.contains(bonusKey)) {
        debugPrint("   Skipping already awarded: ${bonus.type.name}");
        continue;
      }
      
      awardedBonuses.add(bonusKey);
      newBonusesFound++;
      
      final points = _getBonusPoints(bonus.type);
      totalBonus += points;
      
      bonusCount[bonus.type] = (bonusCount[bonus.type] ?? 0) + 1;
      
      final centerPos = _getCenterPosition(bonus.positions);
      activeEffects.add(BonusEffect(
        type: bonus.type,
        position: centerPos,
        createdAt: DateTime.now(),
      ));
      
      bonusNotifications.add(BonusNotification(
        type: bonus.type,
        points: points,
        createdAt: DateTime.now(),
      ));
      
      for (int i = 0; i < 20; i++) {
        particles.add(CargoParticle.bonus(centerPos, _getBonusColor(bonus.type)));
      }
      
      debugPrint("   ${bonus.type.name}: +$points (${bonus.values.join(',')})");
    }
    
    if (newBonusesFound == 0) return;
    
    setState(() {
      score += totalBonus;
      bonusesEarned += newBonusesFound;
    });
    
    _bonusController.forward(from: 0.0);
    HapticFeedback.heavyImpact();
  }

  int _getBonusPoints(BonusType type) {
    switch (type) {
      case BonusType.targetSum: return 400;
      case BonusType.fibonacci4: return 300;
      case BonusType.fibonacci5: return 500;
      case BonusType.fibonacci6: return 1000;
      case BonusType.doubling3: return 250;
      case BonusType.doubling4: return 600;
      case BonusType.doubling5: return 1200;
      case BonusType.consecutive4: return 200;
      case BonusType.consecutive5: return 350;
      case BonusType.consecutive6: return 550;
      case BonusType.consecutive7: return 800;
      case BonusType.square3: return 500;
      case BonusType.square4: return 700;
    }
  }

  Color _getBonusColor(BonusType type) {
    if (type.name.startsWith('fibonacci')) return Colors.pink.shade300;
    if (type.name.startsWith('doubling')) return Colors.red.shade300;
    if (type.name.startsWith('consecutive')) return Colors.green.shade300;
    if (type.name.startsWith('square')) return Colors.purple.shade300;
    return Colors.blue.shade300;
  }

  String _getBonusName(BonusType type) {
    final gameProvider = context.read<GameProvider>();
    final mult = gameProvider.multiplicationSymbol;
    switch (type) {
      case BonusType.fibonacci4: return 'Fibonacci ${mult}4';
      case BonusType.fibonacci5: return 'Fibonacci ${mult}5';
      case BonusType.fibonacci6: return 'Fibonacci ${mult}6';
      case BonusType.doubling3: return '2$mult ${mult}3';
      case BonusType.doubling4: return '2$mult ${mult}4';
      case BonusType.doubling5: return '2$mult ${mult}5';
      case BonusType.consecutive4: return '1,2,3,4...';
      case BonusType.consecutive5: return '1,2,3,4,5...';
      case BonusType.consecutive6: return '1,2,3,4,5,6...';
      case BonusType.consecutive7: return '1,2,3,4,5,6,7...';
      default: return type.name;
    }
  }

  Offset _getCenterPosition(List<Position> positions) {
    if (positions.isEmpty) return Offset.zero;
    final avgX = positions.map((p) => p.x).reduce((a, b) => a + b) / positions.length;
    final avgY = positions.map((p) => p.y).reduce((a, b) => a + b) / positions.length;
    return Offset(avgX * 30, avgY * 30);
  }

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
    
    combo++;
    final basePoints = 100 * fullRows.length * fullRows.length;
    final comboBonus = combo > 1 ? (combo - 1) * 50 * fullRows.length : 0;
    
    setState(() {
      score += basePoints + comboBonus;
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
          
          awardedBonuses.clear();
        });
        _checkWinCondition();
      }
    });
  }

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

  void _checkWinCondition() {
    if (rowsCleared >= rowsToWin && gameActive) {
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    if (!gameActive) return;
    
    setState(() { gameActive = false; hasWon = true; });
    dropTimer?.cancel();
    HapticFeedback.heavyImpact();
    
    final bonusTotal = bonusesEarned * 100;
    final totalScore = score + (300 * widget.grade) + bonusTotal;
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'cargo_bay_arranger', scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5), wasSuccessful: true,
    );
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        showDialog(context: context, barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, bonusTotal),
        );
      }
    });
  }

  void _handleGameOver() {
    if (!gameActive) return;

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
      score = 0; rowsCleared = 0; bonusesEarned = 0; combo = 0;
      particles.clear(); clearingRows.clear();
      heldPiece = null; hasUsedHold = false;
      activeEffects.clear(); bonusNotifications.clear();
      awardedBonuses.clear();
      _initializeBonusTracking();
    });
    
    _initializeGrid();
    _spawnNewPiece();
    _startDropTimer();
  }

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
    
    activeEffects.removeWhere((e) => 
      DateTime.now().difference(e.createdAt).inMilliseconds > 2000
    );
    
    bonusNotifications.removeWhere((n) =>
      DateTime.now().difference(n.createdAt).inMilliseconds > 2500
    );
  }

  Widget _buildCompactPiecePreview(CargoPiece? piece, bool disabled, double size) {
    final cellSize = size / 6; // Smaller cells for compact view
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade800.withOpacity(0.5) : SpaceTheme.deepSpace.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: disabled ? Colors.grey.shade600 : SpaceTheme.nebulaPurple.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: piece == null
          ? Center(
              child: Text(
                disabled ? '—' : '?',
                style: TextStyle(
                  color: disabled ? Colors.grey.shade600 : Colors.white24,
                  fontSize: size / 3,
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < piece.shape.length; i++)
                  for (int j = 0; j < piece.shape[i].length; j++)
                    if (piece.shape[i][j])
                      Positioned(
                        left: (size / 2) - (piece.shape[0].length * cellSize / 2) + j * cellSize,
                        top: (size / 2) - (piece.shape.length * cellSize / 2) + i * cellSize,
                        child: Container(
                          width: cellSize - 0.5,
                          height: cellSize - 0.5,
                          decoration: BoxDecoration(
                            color: piece.cubes[i][j]!.color,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: SpaceBackground(
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
            ),
            
            // Particles
            ...particles.map((p) => p.build()).toList(),
            
            // Bonus notifications
            ..._buildBonusNotifications(),
            
            // Main game layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final sidebarWidth = isWide ? 120.0 : 70.0; // Reduced mobile sidebar to 70px
                
                return Row(
                  children: [
                    // Left sidebar - ALWAYS visible
                    SizedBox(
                      width: sidebarWidth,
                      child: Container(
                        color: SpaceTheme.deepSpace.withOpacity(0.8),
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: isWide ? 8 : 4),
                        child: Column(
                          children: [
                            // Back button
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Progress counter - more compact
                            Column(
                              children: [
                                Text(
                                  '$rowsCleared',
                                  style: TextStyle(
                                    color: SpaceTheme.alienGreen,
                                    fontSize: isWide ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 1,
                                  color: SpaceTheme.alienGreen.withOpacity(0.5),
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                ),
                                Text(
                                  '$rowsToWin',
                                  style: TextStyle(
                                    color: SpaceTheme.alienGreen.withOpacity(0.7),
                                    fontSize: isWide ? 18 : 16,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Hold piece
                            Text(
                              'HOLD',
                              style: TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                            const SizedBox(height: 2),
                            _buildCompactPiecePreview(heldPiece, hasUsedHold, isWide ? 60 : 45),
                            
                            const SizedBox(height: 8),
                            
                            // Next piece  
                            Text(
                              'NEXT',
                              style: TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                            const SizedBox(height: 2),
                            _buildCompactPiecePreview(nextPiece, false, isWide ? 60 : 45),
                            
                            const Spacer(),
                            
                            // Compact controls
                            if (gameActive) ...[
                              IconButton(
                                icon: const Icon(Icons.rotate_right, size: 18),
                                onPressed: _rotatePiece,
                                color: SpaceTheme.alienGreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward, size: 18),
                                onPressed: _hardDrop,
                                color: SpaceTheme.alienGreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                            
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    
                    // Game grid - takes all remaining space
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Minimal padding
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, gridConstraints) {
                              final maxCellW = (gridConstraints.maxWidth - 4) / gridCols;
                              final maxCellH = (gridConstraints.maxHeight - 4) / gridRows;
                              final cellSize = math.min(maxCellW, maxCellH).clamp(15.0, 35.0);
                              
                              final gridWidth = cellSize * gridCols;
                              final gridHeight = cellSize * gridRows;
                              
                              return GestureDetector(
                                onTapDown: (details) => _handleTapOnGrid(details.localPosition, cellSize),
                                onPanStart: (details) => _handlePanStart(details, cellSize),
                                onPanUpdate: (details) => _handlePanUpdate(details, cellSize),
                                onPanEnd: _handlePanEnd,
                                child: Container(
                                  width: gridWidth + 2, // Reduced border space
                                  height: gridHeight + 2,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.5), width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: Stack(
                                      children: [
                                        CustomPaint(
                                          size: Size(gridWidth, gridHeight),
                                          painter: GridPainter(cellSize: cellSize, intensity: _pulseAnimation.value),
                                        ),
                                        ..._buildPlacedCubes(cellSize),
                                        ..._buildGhostPiece(cellSize),
                                        ..._buildCurrentPiece(cellSize),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    // Right sidebar (wide screens only)
                    if (isWide)
                      SizedBox(
                        width: sidebarWidth,
                        child: _buildRightSidebar(),
                      ),
                  ],
                );
              },
            ),
            
            // Bonus panel overlay
            if (showBonusPanel)
              GestureDetector(
                onTap: () => setState(() => showBonusPanel = false),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                      decoration: SpaceTheme.cardDecoration.copyWith(
                        border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  S.of(context)!.cargoBayBonuses,
                                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => showBonusPanel = false),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _buildFullBonusPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea(BoxConstraints constraints) {
    return LayoutBuilder(
      builder: (context, gameConstraints) {
        final maxCellW = (gameConstraints.maxWidth - 20) / gridCols;
        final maxCellH = (gameConstraints.maxHeight - 20) / gridRows;
        final cellSize = math.min(maxCellW, maxCellH).clamp(20.0, 40.0);
        
        final gridWidth = cellSize * gridCols;
        final gridHeight = cellSize * gridRows;
        
        return Center(
          child: GestureDetector(
            onTapDown: (details) => _handleTapOnGrid(details.localPosition, cellSize),
            onPanStart: (details) => _handlePanStart(details, cellSize),
            onPanUpdate: (details) => _handlePanUpdate(details, cellSize),
            onPanEnd: _handlePanEnd,
            child: Container(
              width: gridWidth + 4,
              height: gridHeight + 4,
              decoration: BoxDecoration(
                border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withOpacity(0.3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(gridWidth, gridHeight),
                      painter: GridPainter(cellSize: cellSize, intensity: _pulseAnimation.value),
                    ),
                    ..._buildPlacedCubes(cellSize),
                    ..._buildGhostPiece(cellSize),
                    ..._buildCurrentPiece(cellSize),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      color: SpaceTheme.deepSpace.withOpacity(0.8),
      padding: const EdgeInsets.all(12), // Reduced from 16
      child: Column(
        children: [
          const SizedBox(height: 40), // Reduced from 50
          
          // Hold piece
          Text(
            'HOLD',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 12), // Reduced from 14
          ),
          const SizedBox(height: 4),
          _buildPiecePreview(heldPiece, hasUsedHold),
          
          const SizedBox(height: 16), // Reduced from 24
          
          // Next piece
          Text(
            'NEXT',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildPiecePreview(nextPiece, false),
          
          const Spacer(),
          
          // Controls
          if (gameActive) ...[
            _buildSideButton(Icons.rotate_right, _rotatePiece),
            const SizedBox(height: 6),
            _buildSideButton(Icons.arrow_downward, _hardDrop),
            const SizedBox(height: 6),
            _buildSideButton(Icons.swap_horiz, _holdPiece),
          ],
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      color: SpaceTheme.deepSpace.withOpacity(0.8),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 50),
          
          // Score
          Text(
            'SCORE',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            score.toString(),
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: 24,
              color: SpaceTheme.starYellow,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bonuses
          Text(
            'BONUSES',
            style: SpaceTheme.titleStyle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            bonusesEarned.toString(),
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: 20,
              color: SpaceTheme.cosmicPink,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Target sum
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                const Text(
                  'TARGET',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
                Text(
                  targetSum.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Combo
          if (combo > 1) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.whatshot, color: Colors.orange, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${context.read<GameProvider>().multiplicationSymbol}$combo',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const Spacer(),
          
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: SpaceTheme.starYellow),
            onPressed: () => setState(() => showBonusPanel = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPiecePreview(CargoPiece? piece, bool disabled) {
    final size = 80.0; // Reduced from 100
    final cellSize = 16.0; // Reduced from 20

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade800.withOpacity(0.5) : SpaceTheme.deepSpace.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: disabled ? Colors.grey.shade600 : SpaceTheme.nebulaPurple.withOpacity(0.3),
        ),
      ),
      child: piece == null
          ? Center(
              child: Text(
                disabled ? 'USED' : '?',
                style: TextStyle(
                  color: disabled ? Colors.grey.shade600 : Colors.white24,
                  fontSize: 20,
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < piece.shape.length; i++)
                  for (int j = 0; j < piece.shape[i].length; j++)
                    if (piece.shape[i][j])
                      Positioned(
                        left: (size / 2) - (piece.shape[0].length * cellSize / 2) + j * cellSize,
                        top: (size / 2) - (piece.shape.length * cellSize / 2) + i * cellSize,
                        child: _buildMiniCube(piece.cubes[i][j]!, cellSize),
                      ),
              ],
            ),
    );
  }

  Widget _buildMobileHoldPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('HOLD:', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          _buildTinyPiecePreview(heldPiece),
        ],
      ),
    );
  }

  Widget _buildMobileNextPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('NEXT:', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          _buildTinyPiecePreview(nextPiece),
        ],
      ),
    );
  }

  Widget _buildTinyPiecePreview(CargoPiece? piece) {
    final size = 40.0;
    final cellSize = 8.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: SpaceTheme.nebulaPurple.withOpacity(0.3)),
      ),
      child: piece == null
          ? const Center(
              child: Text('?', style: TextStyle(color: Colors.white24, fontSize: 14)),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < piece.shape.length; i++)
                  for (int j = 0; j < piece.shape[i].length; j++)
                    if (piece.shape[i][j])
                      Positioned(
                        left: (size / 2) - (piece.shape[0].length * cellSize / 2) + j * cellSize,
                        top: (size / 2) - (piece.shape.length * cellSize / 2) + i * cellSize,
                        child: Container(
                          width: cellSize - 1,
                          height: cellSize - 1,
                          decoration: BoxDecoration(
                            color: piece.cubes[i][j]!.color,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildSideButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withOpacity(0.3),
        foregroundColor: SpaceTheme.alienGreen,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Icon(icon, size: 24),
    );
  }

  Widget _buildMiniCube(CargoCube cube, double size) {
    return Container(
      width: size - 2,
      height: size - 2,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: cube.color,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          cube.value.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBonusNotifications() {
    return bonusNotifications.map((notif) {
      final age = DateTime.now().difference(notif.createdAt).inMilliseconds;
      final opacity = (1.0 - (age / 2500)).clamp(0.0, 1.0);
      final yOffset = age / 10.0;
      
      return Positioned(
        top: 100 + yOffset,
        left: MediaQuery.of(context).size.width / 2 - 100,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getBonusColor(notif.type),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getBonusColor(notif.type).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getBonusName(notif.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${notif.points}',
                    style: const TextStyle(
                      color: SpaceTheme.starYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFullBonusPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTargetSumInfo(),
        const SizedBox(height: 16),
        _buildBonusCategory(S.of(context)!.bonusFibonacciTitle, [
          BonusType.fibonacci4,
          BonusType.fibonacci5,
          BonusType.fibonacci6,
        ]),
        const SizedBox(height: 16),
        _buildBonusCategory(S.of(context)!.bonusDoublingTitle, [
          BonusType.doubling3,
          BonusType.doubling4,
          BonusType.doubling5,
        ]),
        const SizedBox(height: 16),
        _buildBonusCategory(S.of(context)!.bonusConsecutiveTitle, [
          BonusType.consecutive4,
          BonusType.consecutive5,
          BonusType.consecutive6,
          BonusType.consecutive7,
        ]),
        const SizedBox(height: 16),
        _buildBonusCategory(S.of(context)!.bonusSquareTitle, [
          BonusType.square3,
          BonusType.square4,
        ]),
      ],
    );
  }

  Widget _buildTargetSumInfo() {
    final count = bonusCount[BonusType.targetSum] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.of(context)!.bonusTargetSum,
                  style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade300, borderRadius: BorderRadius.circular(12)),
                  child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(S.of(context)!.bonusTargetSumDesc(targetSum), style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(height: 4),
          const Text('+400', style: TextStyle(color: SpaceTheme.starYellow, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBonusCategory(String title, List<BonusType> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...types.map((type) => _buildBonusItem(type)),
      ],
    );
  }

  Widget _buildBonusItem(BonusType type) {
    final count = bonusCount[type] ?? 0;
    final color = _getBonusColor(type);
    final points = _getBonusPoints(type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getBonusDescription(type),
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$points',
            style: const TextStyle(color: SpaceTheme.starYellow, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            ),
        ],
      ),
    );
  }

  String _getBonusDescription(BonusType type) {
    final mult = context.read<GameProvider>().multiplicationSymbol;
    switch (type) {
      case BonusType.fibonacci4: return '1,1,2,3';
      case BonusType.fibonacci5: return '1,1,2,3,5';
      case BonusType.fibonacci6: return '1,1,2,3,5,8';
      case BonusType.doubling3: return '1,2,4';
      case BonusType.doubling4: return '1,2,4,8';
      case BonusType.doubling5: return '1,2,4,8,16';
      case BonusType.consecutive4: return '1,2,3,4';
      case BonusType.consecutive5: return '1,2,3,4,5';
      case BonusType.consecutive6: return '1,2,3,4,5,6';
      case BonusType.consecutive7: return '1,2,3,4,5,6,7';
      case BonusType.square3: return '3$mult 3';
      case BonusType.square4: return '4$mult 4';
      default: return '';
    }
  }

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

  List<Widget> _buildGhostPiece(double cellSize) {
    if (currentPiece == null || cellSize <= 0) return [];
    
    final ghostY = _getGhostY();
    if (ghostY == currentPiece!.y) return [];
    
    List<Widget> pieceWidgets = [];
    for (int i = 0; i < currentPiece!.shape.length; i++) {
      for (int j = 0; j < currentPiece!.shape[i].length; j++) {
        if (currentPiece!.shape[i][j]) {
          pieceWidgets.add(
            Positioned(
              left: (currentPiece!.x + j) * cellSize,
              top: (ghostY + i) * cellSize,
              child: Container(
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: currentPiece!.cubes[i][j]!.color.withOpacity(0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(cellSize * 0.15),
                ),
              ),
            ),
          );
        }
      }
    }
    return pieceWidgets;
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
                border: Border.all(color: Colors.black.withOpacity(0.2), width: 1.0),
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

  Widget _buildSuccessDialog(int totalScore, int bonusTotal) {
    return Dialog(backgroundColor: Colors.transparent, child: Container(
        padding: const EdgeInsets.all(24), decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
        ),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle, size: 60, color: SpaceTheme.alienGreen), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayWinTitle, style: SpaceTheme.headlineStyle, textAlign: TextAlign.center), const SizedBox(height: 16),
            Text(S.of(context)!.cargoBayWinDesc(rowsCleared, totalScore, bonusTotal), style: SpaceTheme.bodyStyle, textAlign: TextAlign.center), const SizedBox(height: 24),
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

  @override
  void dispose() {
    dropTimer?.cancel();
    _particleTicker?.dispose();
    _pulseController.dispose();
    _clearController.dispose();
    _lockController.dispose();
    _bonusController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// Data Models
class CargoCube {
  final int value;
  final Color color;

  CargoCube({required this.value, required this.color});
}

class CargoPiece {
  int x, y;
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

enum BonusType {
  targetSum,
  fibonacci4, fibonacci5, fibonacci6,
  doubling3, doubling4, doubling5,
  consecutive4, consecutive5, consecutive6, consecutive7,
  square3, square4,
}

class Position {
  final int x, y;
  Position(this.x, this.y);
}

class BonusMatch {
  final BonusType type;
  final List<Position> positions;
  final List<int> values;

  BonusMatch(this.type, this.positions, this.values);
}

class BonusEffect {
  final BonusType type;
  final Offset position;
  final DateTime createdAt;

  BonusEffect({required this.type, required this.position, required this.createdAt});
}

class BonusNotification {
  final BonusType type;
  final int points;
  final DateTime createdAt;

  BonusNotification({required this.type, required this.points, required this.createdAt});
}

// Visual Effects
class CargoParticle {
  Offset position; Offset velocity; Color color;
  double size; double life; final double maxLife;

  CargoParticle({required this.position, required this.velocity, required this.color, required this.size, required this.life}) : maxLife = life;

  factory CargoParticle.bonus(Offset pos, Color color) {
    final random = math.Random();
    return CargoParticle(
      position: pos,
      velocity: Offset.fromDirection(random.nextDouble() * 2 * math.pi, 30 + random.nextDouble() * 50),
      color: color, size: 3 + random.nextDouble() * 4,
      life: 0.8 + random.nextDouble() * 0.5,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    velocity = velocity.scale(1.0, 1.05);
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

// Custom Painters
class CargoBayPainter extends CustomPainter {
  final double pulseIntensity;
  final bool gameWon, gameLost;

  CargoBayPainter({required this.pulseIntensity, required this.gameWon, required this.gameLost});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: size.width * 0.7,
        colors: const [Color(0xFF333844), Color(0xFF232834)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final beamPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 35.0;
    canvas.drawLine(const Offset(-50, 50), Offset(size.width * 0.4, size.height + 50), beamPaint);
    canvas.drawLine(Offset(size.width + 50, 50), Offset(size.width * 0.6, size.height + 50), beamPaint);
  }

  @override
  bool shouldRepaint(CargoBayPainter oldDelegate) => oldDelegate.pulseIntensity != pulseIntensity;
}

class GridPainter extends CustomPainter {
  final double cellSize, intensity;

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