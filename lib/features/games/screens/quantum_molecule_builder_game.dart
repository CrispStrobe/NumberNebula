import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

import 'levels.dart';

// ============================================================================
// ATOMIX LEVEL DATA INTEGRATION
// ============================================================================

AtomType getAtomTypeFromIndex(int index) {
  if (index >= 0 && index <= 7 || index == 9) return AtomType.hydrogen;
  if (index == 8 || index == 10 || index == 11 || index == 19 || index == 26) return AtomType.oxygen;
  if (index == 12 || index == 13 || index == 18 || index == 24 || index == 25) return AtomType.sulfur;
  if ((index >= 14 && index <= 17) || index == 20 || index == 21 || index == 23 || index == 27 || index == 28) return AtomType.carbon;
  if (index == 22 || index == 29 || index == 30) return AtomType.fluorine;
  if (index == 31) return AtomType.nitrogen;
  if (index >= 32 && index <= 43) {
    const specials = [
      AtomType.special1, AtomType.special2, AtomType.special3, AtomType.special4,
      AtomType.special5, AtomType.special6, AtomType.special7, AtomType.special8,
      AtomType.special9, AtomType.special10, AtomType.special11, AtomType.special12,
    ];
    return specials[(index - 32) % specials.length];
  }
  return AtomType.hydrogen;
}

enum BondDirection { left, right, up, down }

Set<BondDirection> getBondingDirections(int atomIndex) {
  // Hydrogen (valency 1)
  const hydrogenBonds = {
    0: {BondDirection.down},   // Corrected from right
    1: {BondDirection.down},   // Correct
    2: {BondDirection.left},   // Correct
    3: {BondDirection.up},     // Correct
    4: {BondDirection.up},     // Corrected from down
    5: {BondDirection.up},     // Corrected from right
    6: {BondDirection.right},  // Correct
    7: {BondDirection.down},   // Corrected from up
    9: {BondDirection.up},     // Corrected from down
  };

  // Oxygen (valency 2)
  const oxygenBonds = {
    8: {BondDirection.left, BondDirection.right}, // Correct
    10: {BondDirection.left},                      // Corrected from up, down
    11: {BondDirection.up},                        // Corrected from up, down
    19: {BondDirection.down},                      // Corrected from up, down
    // Atom 26 (Q) was removed, as it represents Carbon in Methanal (L23)
  };

  // Sulfur (valency 2)
  const sulfurBonds = {
    12: {BondDirection.down},                      // Corrected from left, right
    13: {BondDirection.right},                     // Corrected from up, down
    18: {BondDirection.left, BondDirection.right, BondDirection.up}, // Corrected from left, right
    24: {BondDirection.left, BondDirection.right}, // Corrected from up, down
    25: {BondDirection.left, BondDirection.right}, // Correct
  };

  // Carbon (valency 4)
  const carbonBonds = {
    14: {BondDirection.left, BondDirection.right, BondDirection.up, BondDirection.down}, // Correct
    15: {BondDirection.left, BondDirection.right, BondDirection.down}, // Kept original, based on trans-butene
    16: {BondDirection.left, BondDirection.right, BondDirection.up},   // Kept original, based on trans-butene
    17: {BondDirection.left, BondDirection.right, BondDirection.up},   // Corrected from left, up, down
    20: {BondDirection.left, BondDirection.right, BondDirection.up, BondDirection.down}, // Corrected from right, up, down
    21: {BondDirection.left, BondDirection.right, BondDirection.up, BondDirection.down}, // Corrected from left, right
    23: {BondDirection.left, BondDirection.right, BondDirection.up, BondDirection.down}, // Corrected from up, down
    26: {BondDirection.right, BondDirection.up, BondDirection.down},  // Added, represents Carbon in Methanal
    27: {BondDirection.left, BondDirection.right},                    // Corrected from left, right, up
    28: {BondDirection.left, BondDirection.right},                    // Corrected from left, right, down
  };

  // Fluorine (valency 1)
  const fluorineBonds = {
    22: {BondDirection.up},    // Corrected from left
    29: {BondDirection.down},  // Corrected from left
    30: {BondDirection.right}, // Corrected from up
  };

  // Nitrogen (valency 3)
  const nitrogenBonds = {
    31: {BondDirection.left, BondDirection.up, BondDirection.down}, // Corrected from left, right, up
  };

  if (hydrogenBonds.containsKey(atomIndex)) return hydrogenBonds[atomIndex]!;
  if (oxygenBonds.containsKey(atomIndex)) return oxygenBonds[atomIndex]!;
  if (sulfurBonds.containsKey(atomIndex)) return sulfurBonds[atomIndex]!;
  if (carbonBonds.containsKey(atomIndex)) return carbonBonds[atomIndex]!;
  if (fluorineBonds.containsKey(atomIndex)) return fluorineBonds[atomIndex]!;
  if (nitrogenBonds.containsKey(atomIndex)) return nitrogenBonds[atomIndex]!;

  return {};
}

class AtomixLevel {
  final int levelNumber;
  final String name;
  final int duration;
  final int background;
  final int cursorType;
  final List<List<Map<String, dynamic>>> playfield;
  final List<List<Map<String, dynamic>>> solution;

  AtomixLevel({
    required this.levelNumber,
    required this.name,
    required this.duration,
    required this.background,
    required this.cursorType,
    required this.playfield,
    required this.solution,
  });

  factory AtomixLevel.fromMap(Map<String, dynamic> map) {
    return AtomixLevel(
      levelNumber: map['levelNumber'] as int,
      name: map['name'] as String,
      duration: map['duration'] as int,
      background: map['background'] as int,
      cursorType: map['cursorType'] as int,
      playfield: (map['playfield'] as List).map((row) => 
        (row as List).map((cell) => Map<String, dynamic>.from(cell as Map)).toList()
      ).toList(),
      solution: (map['solution'] as List).map((row) => 
        (row as List).map((cell) => Map<String, dynamic>.from(cell as Map)).toList()
      ).toList(),
    );
  }
}

class QuantumMoleculeBuilderGame extends StatefulWidget {
  final int grade;
  final int level;

  const QuantumMoleculeBuilderGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<QuantumMoleculeBuilderGame> createState() => _QuantumMoleculeBuilderGameState();
}

class _QuantumMoleculeBuilderGameState extends State<QuantumMoleculeBuilderGame>
    with TickerProviderStateMixin {

  int _currentLevel = 1;
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _successController;
  late Timer _particleTimer;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _successAnimation;

  static const int gridSize = 16;

  late List<List<CellType>> grid;
  late List<Atom> atoms;
  late MoleculePattern targetPattern;
  late int moveLimit;
  
  int movesMade = 0;
  Atom? selectedAtom;
  bool gameActive = true;
  bool hasWon = false;
  bool hasLost = false;
  String levelName = '';
  
  int gridOffsetX = 0;
  int gridOffsetY = 0;
  int visibleWidth = gridSize;
  int visibleHeight = gridSize;
  
  Atom? slidingAtom;
  Offset? slideStartPos;
  Offset? slideEndPos;
  
  List<MoleculeParticle> particles = [];
  
  // Keyboard focus node
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    debugPrint("\n${"=" * 60}\n⚛️  QUANTUM MOLECULE BUILDER\n   Grade: ${widget.grade}, Level: ${widget.level}\n${"=" * 60}");
    
    _setupAnimationControllers();
    _currentLevel = widget.level;
    _loadLevel();
    _startParticleTimer();
    
    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _setupAnimationControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(parent: _slideController, curve: Curves.easeInOut);

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
  }

  void _startParticleTimer() {
    _particleTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted && particles.isNotEmpty) {
        setState(() {
          particles.removeWhere((p) => p.update(0.016));
        });
      }
    });
  }

  // Keyboard input handler
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !gameActive) return KeyEventResult.ignored;
    
    // Handle Tab key for switching atoms
    if (event.logicalKey == LogicalKeyboardKey.tab) {
        if (atoms.isNotEmpty) {
        final currentIndex = selectedAtom != null 
            ? atoms.indexWhere((a) => a.id == selectedAtom!.id) 
            : -1;
        final nextIndex = (currentIndex + 1) % atoms.length;
        _selectAtom(atoms[nextIndex]);
        return KeyEventResult.handled;
        }
    }
    
    // Handle movement keys only if an atom is selected
    if (selectedAtom == null) return KeyEventResult.ignored;

    switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
        _moveAtom(Direction.up);
        return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
        _moveAtom(Direction.down);
        return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
        _moveAtom(Direction.left);
        return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
        _moveAtom(Direction.right);
        return KeyEventResult.handled;
        default:
        return KeyEventResult.ignored;
    }
    }

  void _loadLevel({int? levelToLoad}) { //
    if (levelsData.isEmpty) {
      _loadFallbackLevel();
      return;
    }
    
    final levelNum = levelToLoad ?? _currentLevel;
    final levelIndex = (levelNum - 1) % levelsData.length;

    setState(() {
        _currentLevel = levelNum; // Ensure state is up to date
    });
    
    try {
      final level = AtomixLevel.fromMap(levelsData[levelIndex]);
      levelName = level.name;
      
      grid = List.generate(gridSize, (y) {
        return List.generate(gridSize, (x) {
          final tile = level.playfield[y][x];
          return tile['type'] == 'wall' ? CellType.wall : CellType.empty;
        });
      });
      
      atoms = [];
      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final tile = level.playfield[y][x];
          if (tile['type'] == 'atom') {
            final atomIndex = tile['index'] as int;
            final atomType = getAtomTypeFromIndex(atomIndex);
            atoms.add(Atom(
              type: atomType,
              row: y,
              col: x,
              id: 'atom_$atomIndex',
              atomixIndex: atomIndex,
            ));
          }
        }
      }
      debugPrint("  - Found ${atoms.length} atoms on playfield:");
      for (var atom in atoms) {
        final bonds = getBondingDirections(atom.atomixIndex);
        debugPrint("    - Atom ID: ${atom.id}, Type: ${atom.type.symbol}, "
                    "Index: ${atom.atomixIndex}, Bonds: $bonds");
        }
      
      _calculateVisibleBounds();
      targetPattern = _buildPatternFromSolution(level);
      moveLimit = ((level.duration / 4.5) + (atoms.length * 1.5)).round().clamp(20, 150);
      
      debugPrint("✅ Level ${level.levelNumber}: $levelName loaded (${atoms.length} atoms, $moveLimit moves)");
      
    } catch (e) {
      debugPrint("❌ Error: $e");
      _loadFallbackLevel();
    }
  }

  void _calculateVisibleBounds() {
    int minRow = gridSize, maxRow = -1, minCol = gridSize, maxCol = -1;
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] == CellType.wall || atoms.any((a) => a.row == y && a.col == x)) {
          minRow = math.min(minRow, y);
          maxRow = math.max(maxRow, y);
          minCol = math.min(minCol, x);
          maxCol = math.max(maxCol, x);
        }
      }
    }
    
    gridOffsetY = math.max(0, minRow - 1);
    gridOffsetX = math.max(0, minCol - 1);
    visibleHeight = math.min(gridSize, maxRow - gridOffsetY + 2);
    visibleWidth = math.min(gridSize, maxCol - gridOffsetX + 2);
  }

  MoleculePattern _buildPatternFromSolution(AtomixLevel level) {
    int minRow = gridSize, maxRow = -1, minCol = gridSize, maxCol = -1;
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tile = level.solution[y][x];
        if (tile['type'] == 'atom') {
          minRow = math.min(minRow, y);
          maxRow = math.max(maxRow, y);
          minCol = math.min(minCol, x);
          maxCol = math.max(maxCol, x);
        }
      }
    }
    
    if (maxRow < 0) return MoleculePattern.water();
    
    final height = maxRow - minRow + 1;
    final width = maxCol - minCol + 1;
    final patternSize = math.max(height, width);
    
    final patternGrid = List.generate(patternSize, (_) => List<int?>.filled(patternSize, null));
    final atomTypesList = <AtomType>[];
    
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        final tile = level.solution[y][x];
        if (tile['type'] == 'atom') {
          final atomIndex = tile['index'] as int;
          final atomType = getAtomTypeFromIndex(atomIndex);
          final patternY = y - minRow;
          final patternX = x - minCol;
          
          if (patternY < patternSize && patternX < patternSize) {
            patternGrid[patternY][patternX] = atomIndex;
            atomTypesList.add(atomType);
          }
        }
      }
    }
    
    return MoleculePattern(
      name: level.name,
      size: patternSize,
      grid: patternGrid,
      atomTypes: atomTypesList,
    );
  }

  void _loadFallbackLevel() {
    levelName = 'H₂O';
    grid = List.generate(gridSize, (i) => List.filled(gridSize, CellType.empty));
    
    for (int i = 0; i < gridSize; i++) {
      grid[0][i] = CellType.wall;
      grid[gridSize - 1][i] = CellType.wall;
      grid[i][0] = CellType.wall;
      grid[i][gridSize - 1] = CellType.wall;
    }
    
    atoms = [
      Atom(type: AtomType.hydrogen, row: 2, col: 2, id: 'H1', atomixIndex: 6),
      Atom(type: AtomType.oxygen, row: 5, col: 5, id: 'O1', atomixIndex: 8),
      Atom(type: AtomType.hydrogen, row: 10, col: 10, id: 'H2', atomixIndex: 2),
    ];
    
    gridOffsetX = 0;
    gridOffsetY = 0;
    visibleWidth = gridSize;
    visibleHeight = gridSize;
    targetPattern = MoleculePattern.water();
    moveLimit = 40;
  }

  void _selectAtom(Atom atom) {
    if (!gameActive) return;
    setState(() {
      selectedAtom = (selectedAtom?.id == atom.id) ? null : atom;
    });
    HapticFeedback.selectionClick();
  }

  void _moveAtom(Direction direction) {
    if (selectedAtom == null || !gameActive || slidingAtom != null) return;
    
    final atom = selectedAtom!;
    int newRow = atom.row;
    int newCol = atom.col;
    
    switch (direction) {
      case Direction.up:
        while (newRow > 0 && _canMoveTo(newRow - 1, newCol, atom)) newRow--;
        break;
      case Direction.down:
        while (newRow < gridSize - 1 && _canMoveTo(newRow + 1, newCol, atom)) newRow++;
        break;
      case Direction.left:
        while (newCol > 0 && _canMoveTo(newRow, newCol - 1, atom)) newCol--;
        break;
      case Direction.right:
        while (newCol < gridSize - 1 && _canMoveTo(newRow, newCol + 1, atom)) newCol++;
        break;
    }
    
    if (newRow != atom.row || newCol != atom.col) {
      HapticFeedback.lightImpact();
      
      setState(() {
        slidingAtom = atom;
        slideStartPos = Offset(atom.col.toDouble(), atom.row.toDouble());
        slideEndPos = Offset(newCol.toDouble(), newRow.toDouble());
        movesMade++;
      });
      
      _slideController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            atom.row = newRow;
            atom.col = newCol;
            slidingAtom = null;
            slideStartPos = null;
            slideEndPos = null;
          });
          _checkWinCondition();
          _checkLoseCondition();
        }
      });
    }
  }

  bool _canMoveTo(int row, int col, Atom movingAtom) {
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return false;
    if (grid[row][col] == CellType.wall) return false;
    return !atoms.any((a) => a.id != movingAtom.id && a.row == row && a.col == col);
  }

  void _checkWinCondition() {
    for (int startRow = 0; startRow <= gridSize - targetPattern.size; startRow++) {
      for (int startCol = 0; startCol <= gridSize - targetPattern.size; startCol++) {
        if (_checkPatternAt(startRow, startCol)) {
          _handleSuccess();
          return;
        }
      }
    }
  }

  bool _checkPatternAt(int startRow, int startCol) {
    for (int i = 0; i < targetPattern.size; i++) {
      for (int j = 0; j < targetPattern.size; j++) {
        final expectedIndex = targetPattern.grid[i][j];
        final gridRow = startRow + i;
        final gridCol = startCol + j;
        
        if (expectedIndex != null) {
          final atom = atoms.firstWhere(
            (a) => a.row == gridRow && a.col == gridCol,
            orElse: () => Atom(type: AtomType.hydrogen, row: -1, col: -1, id: 'null', atomixIndex: -1),
          );
          if (atom.atomixIndex != expectedIndex) return false;
        } else {
          if (atoms.any((a) => a.row == gridRow && a.col == gridCol)) return false;
        }
      }
    }
    return true;
  }

  void _checkLoseCondition() {
    if (movesMade >= moveLimit && !hasWon && gameActive) {
      _handleFailure();
    }
  }

  void _handleSuccess() {
    setState(() {
      gameActive = false;
      hasWon = true;
    });
    
    _successController.forward();
    HapticFeedback.heavyImpact();
    
    for (int i = 0; i < 60; i++) {
      particles.add(MoleculeParticle.celebration(MediaQuery.of(context).size.center(Offset.zero)));
    }
    
    final baseScore = 300 * widget.grade;
    final efficiencyBonus = math.max(0, (moveLimit - movesMade) * 10);
    final totalScore = baseScore + efficiencyBonus;
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'quantum_molecule_builder',
      scoreGained: totalScore,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: true,
    );
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildSuccessDialog(totalScore, efficiencyBonus),
        );
      }
    });
  }

  void _handleFailure() {
    setState(() {
      gameActive = false;
      hasLost = true;
    });
    
    HapticFeedback.heavyImpact();
    
    context.read<GameProvider>().recordLevelWin(
      gameType: 'quantum_molecule_builder',
      scoreGained: 0,
      difficulty: widget.grade + (widget.level ~/ 5),
      wasSuccessful: false,
    );
    
    for (int i = 0; i < 40; i++) {
      particles.add(MoleculeParticle.failure(MediaQuery.of(context).size.center(Offset.zero)));
    }
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildFailureDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > screenSize.height && screenSize.width > 600;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Scaffold(
          body: SpaceBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: MolecularBackgroundPainter(
                            pulseIntensity: _pulseAnimation.value,
                            gameWon: hasWon,
                            gameLost: hasLost,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  ...particles.map((p) => p.build()),
                  
                  Column(
                    children: [
                      GameUI(
                        title: 'Molecule Builder',
                        level: widget.level,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      
                      Expanded(
                        child: isWideScreen ? _buildWideLayout() : _buildCompactLayout(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    final screenSize = MediaQuery.of(context).size;
    
    final leftPanelWidth = screenSize.width * 0.25;
    final rightPanelWidth = screenSize.width * 0.75;
    
    final availableHeight = screenSize.height - 120;
    final cellSize = math.min(
      rightPanelWidth / visibleWidth,
      availableHeight / visibleHeight,
    ).clamp(25.0, 55.0);
    
    return Row(
      children: [
        Container(
          width: leftPanelWidth,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildCompactTargetDisplay(),
              const SizedBox(height: 16),
              _buildStats(),
              const SizedBox(height: 16),
              if (gameActive && selectedAtom != null) ...[
                _buildSelectedInfo(),
                const SizedBox(height: 12),
                _buildCompactControls(),
                const SizedBox(height: 12),
              ],
              if (gameActive) _buildRestartButton(),
            ],
          ),
        ),
        
        Expanded(
          child: Center(
            child: _buildGameGrid(cellSize),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    final screenSize = MediaQuery.of(context).size;
    
    final availableWidth = screenSize.width - 24;
    final availableHeight = screenSize.height - 280;
    
    final cellSize = math.min(
      availableWidth / visibleWidth,
      availableHeight / visibleHeight,
    ).clamp(20.0, 45.0);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(child: _buildCompactTargetDisplay()),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatChip(Icons.swap_horiz, '$movesMade/$moveLimit', SpaceTheme.alienGreen),
                  const SizedBox(height: 4),
                  _buildStatChip(Icons.science, '${atoms.length}', SpaceTheme.cosmicPink),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        Expanded(
          child: Center(
            child: _buildGameGrid(cellSize),
          ),
        ),
        
        if (gameActive && selectedAtom != null) ...[
          const SizedBox(height: 8),
          _buildSelectedInfo(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCompactControls(),
              const SizedBox(width: 12),
              _buildRestartButton(),
            ],
          ),
        ] else if (gameActive) ...[
          const SizedBox(height: 8),
          _buildRestartButton(),
        ],
        
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRestartButton() {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          gameActive = true;
          hasWon = false;
          hasLost = false;
          movesMade = 0;
          selectedAtom = null;
          slidingAtom = null;
          slideStartPos = null;
          slideEndPos = null;
          particles.clear();
        });
        _loadLevel();
        _successController.reset();
      },
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Restart', style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withOpacity(0.6),
        foregroundColor: SpaceTheme.starYellow,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: SpaceTheme.starYellow.withOpacity(0.5), width: 2),
        ),
      ),
    );
  }

  Widget _buildCompactTargetDisplay() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TARGET',
            style: TextStyle(
              color: SpaceTheme.alienGreen,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            levelName,
            style: const TextStyle(
              color: SpaceTheme.starYellow,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: _buildTargetAtomsCompact(16.0),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTargetAtomsCompact(double atomSize) {
    return List.generate(targetPattern.size, (i) {
      return List.generate(targetPattern.size, (j) {
        final atomIndex = targetPattern.grid[i][j];
        if (atomIndex != null) {
          final atomType = getAtomTypeFromIndex(atomIndex);
          final bonds = getBondingDirections(atomIndex);
          
          return Positioned(
            left: j * atomSize,
            top: i * atomSize,
            child: _buildAtomVisual(atomType, atomSize, false, bonds),
          );
        }
        return const SizedBox.shrink();
      });
    }).expand((e) => e).toList();
  }

  Widget _buildStats() {
    return Column(
      children: [
        _buildStatRow(Icons.swap_horiz, 'Moves', '$movesMade/$moveLimit', SpaceTheme.alienGreen),
        const SizedBox(height: 8),
        _buildStatRow(Icons.science, 'Atoms', '${atoms.length}', SpaceTheme.cosmicPink),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.starYellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.starYellow.withOpacity(0.5)),
      ),
      child: Text(
        'Selected: ${selectedAtom?.type.name ?? "None"}',
        style: const TextStyle(
          color: SpaceTheme.starYellow,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCompactControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControlButton(Icons.arrow_back, () => _moveAtom(Direction.left)),
        const SizedBox(width: 4),
        _buildControlButton(Icons.arrow_upward, () => _moveAtom(Direction.up)),
        const SizedBox(width: 4),
        _buildControlButton(Icons.arrow_downward, () => _moveAtom(Direction.down)),
        const SizedBox(width: 4),
        _buildControlButton(Icons.arrow_forward, () => _moveAtom(Direction.right)),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withOpacity(0.6),
        foregroundColor: SpaceTheme.alienGreen,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: SpaceTheme.alienGreen.withOpacity(0.5), width: 2),
        ),
      ),
      child: Icon(icon, size: 18),
    );
  }

  Widget _buildAtomVisual(AtomType atomType, double size, bool isSelected, Set<BondDirection> bonds) {
    final isLightAtom = atomType == AtomType.hydrogen || atomType == AtomType.fluorine;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Bond stubs - FIXED: Position each direction correctly!
          ...bonds.map((dir) {
            final stubLength = size * 0.28;
            final stubThickness = size * 0.15;
            
            switch (dir) {
              case BondDirection.left:
                return Positioned(
                  left: 0,
                  top: (size - stubThickness) / 2,
                  child: Container(
                    width: stubLength,
                    height: stubThickness,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(stubThickness / 2),
                        bottomLeft: Radius.circular(stubThickness / 2),
                      ),
                    ),
                  ),
                );
              
              case BondDirection.right:
                return Positioned(
                  right: 0,
                  top: (size - stubThickness) / 2,
                  child: Container(
                    width: stubLength,
                    height: stubThickness,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(stubThickness / 2),
                        bottomRight: Radius.circular(stubThickness / 2),
                      ),
                    ),
                  ),
                );
              
              case BondDirection.up:
                return Positioned(
                  top: 0,
                  left: (size - stubThickness) / 2,
                  child: Container(
                    width: stubThickness,
                    height: stubLength,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(stubThickness / 2),
                        topRight: Radius.circular(stubThickness / 2),
                      ),
                    ),
                  ),
                );
              
              case BondDirection.down:
                return Positioned(
                  bottom: 0,
                  left: (size - stubThickness) / 2,
                  child: Container(
                    width: stubThickness,
                    height: stubLength,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(stubThickness / 2),
                        bottomRight: Radius.circular(stubThickness / 2),
                      ),
                    ),
                  ),
                );
            }
          }).toList(),
          
          // Main atom circle
          Center(
            child: Container(
              width: size * 0.65,
              height: size * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    atomType.color.withOpacity(0.9),
                    atomType.color,
                    atomType.color.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                border: Border.all(
                  color: isSelected 
                      ? SpaceTheme.starYellow 
                      : isLightAtom
                          ? const Color(0xFFCCCCCC)
                          : Colors.white.withOpacity(0.9),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? SpaceTheme.starYellow : atomType.color)
                        .withOpacity(isSelected ? 0.8 : 0.6),
                    blurRadius: isSelected ? 16 : 10,
                    spreadRadius: isSelected ? 3 : 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: size * 0.05,
                    left: size * 0.05,
                    child: Container(
                      width: size * 0.13,
                      height: size * 0.13,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(isLightAtom ? 0.6 : 0.4),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      atomType.symbol,
                      style: TextStyle(
                        color: isLightAtom ? Colors.black87 : Colors.white,
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: isLightAtom ? Colors.white60 : Colors.black87,
                            blurRadius: 2,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid(double cellSize) {
    return Container(
      width: cellSize * visibleWidth,
      height: cellSize * visibleHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A1520),
            Color(0xFF0F1A25),
            Color(0xFF0A1520),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(width: 3, color: const Color(0xFF2A4F6F)),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.nebulaPurple.withOpacity(0.3),
            blurRadius: 18,
            spreadRadius: 4,
          ),
          const BoxShadow(
            color: Colors.black54,
            offset: Offset(4, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            ..._buildGridCells(cellSize),
            ..._buildAtoms(cellSize),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridCells(double cellSize) {
    final cells = <Widget>[];
    
    for (int localY = 0; localY < visibleHeight; localY++) {
      for (int localX = 0; localX < visibleWidth; localX++) {
        final gridY = localY + gridOffsetY;
        final gridX = localX + gridOffsetX;
        
        if (gridY >= gridSize || gridX >= gridSize) continue;
        
        final isWall = grid[gridY][gridX] == CellType.wall;
        
        cells.add(Positioned(
          left: localX * cellSize,
          top: localY * cellSize,
          child: GestureDetector(
            onTap: () {
              final atom = atoms.firstWhere(
                (a) => a.row == gridY && a.col == gridX,
                orElse: () => Atom(type: AtomType.hydrogen, row: -1, col: -1, id: 'null', atomixIndex: -1),
              );
              if (atom.row != -1) _selectAtom(atom);
            },
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                gradient: isWall
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3A5F7F),
                          Color(0xFF2A3F5F),
                          Color(0xFF1A2F3F),
                        ],
                      )
                    : null,
                color: !isWall ? const Color(0xFF0A1520) : null,
                border: Border.all(
                  color: isWall ? const Color(0xFF1A2F3F) : Colors.white.withOpacity(0.05),
                  width: isWall ? 1.5 : 0.5,
                ),
                boxShadow: isWall
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(1.5, 1.5),
                          blurRadius: 3,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ));
      }
    }
    
    return cells;
  }

  List<Widget> _buildAtoms(double cellSize) {
    return atoms.map((atom) {
      final isSelected = selectedAtom?.id == atom.id;
      final isSliding = slidingAtom?.id == atom.id;
      
      double localX = (atom.col - gridOffsetX).toDouble();
      double localY = (atom.row - gridOffsetY).toDouble();
      
      if (isSliding && slideStartPos != null && slideEndPos != null) {
        localX = slideStartPos!.dx - gridOffsetX + 
                 (slideEndPos!.dx - slideStartPos!.dx) * _slideAnimation.value;
        localY = slideStartPos!.dy - gridOffsetY + 
                 (slideEndPos!.dy - slideStartPos!.dy) * _slideAnimation.value;
      }
      
      final bonds = getBondingDirections(atom.atomixIndex);
      
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Positioned(
            left: localX * cellSize,
            top: localY * cellSize,
            child: GestureDetector(
              onTap: () => _selectAtom(atom),
              child: _buildAtomVisual(atom.type, cellSize, isSelected, bonds),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildSuccessDialog(int totalScore, int efficiencyBonus) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: SpaceTheme.cardDecoration.copyWith(
                border: Border.all(color: SpaceTheme.alienGreen, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.science, size: 54, color: SpaceTheme.alienGreen),
                  const SizedBox(height: 8),
                  Text(
                    levelName,
                    style: const TextStyle(
                      color: SpaceTheme.alienGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Molecule Complete!',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Solved in $movesMade moves\nScore: $totalScore (+$efficiencyBonus bonus)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Pass the next level number to the reset function
                            _resetGame(nextLevel: _currentLevel + 1); 
                          },
                          style: SpaceTheme.secondaryButtonStyle,
                          child: const Text('Next', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          style: SpaceTheme.primaryButtonStyle,
                          child: const Text('Exit', style: TextStyle(fontSize: 13)),
                        ),
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

  Widget _buildFailureDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: SpaceTheme.cardDecoration.copyWith(
          border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 54, color: SpaceTheme.rocketRed),
            const SizedBox(height: 12),
            const Text(
              'Out of Moves!',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Try again with fewer moves',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetGame();
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: const Text('Try Again', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: SpaceTheme.primaryButtonStyle,
                    child: const Text('Exit', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resetGame({int? nextLevel}) {
    setState(() {
      gameActive = true;
      hasWon = false;
      hasLost = false;
      movesMade = 0;
      selectedAtom = null;
      slidingAtom = null;
      slideStartPos = null;
      slideEndPos = null;
      particles.clear();
    });
    _loadLevel(levelToLoad: nextLevel);
    _successController.reset();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _successController.dispose();
    _particleTimer.cancel();
    super.dispose();
  }
}

// ==============================================================================
// Data Models (unchanged)
// ==============================================================================

enum CellType { empty, wall }
enum Direction { up, down, left, right }

class AtomType {
  final String symbol;
  final String name;
  final Color color;

  const AtomType({required this.symbol, required this.name, required this.color});

  static const hydrogen = AtomType(symbol: 'H', name: 'Hydrogen', color: Color(0xFFFFFFFF));
  static const oxygen = AtomType(symbol: 'O', name: 'Oxygen', color: Color(0xFFFF4444));
  static const carbon = AtomType(symbol: 'C', name: 'Carbon', color: Color(0xFF909090));
  static const nitrogen = AtomType(symbol: 'N', name: 'Nitrogen', color: Color(0xFF3050F8));
  static const sulfur = AtomType(symbol: 'S', name: 'Sulfur', color: Color(0xFFFFFF30));
  static const fluorine = AtomType(symbol: 'F', name: 'Fluorine', color: Color(0xFF90E050));
  static const special1 = AtomType(symbol: 'W', name: 'Special', color: Color(0xFFFF00FF));
  static const special2 = AtomType(symbol: 'X', name: 'Special', color: Color(0xFF00FFFF));
  static const special3 = AtomType(symbol: 'Y', name: 'Special', color: Color(0xFFFFFF00));
  static const special4 = AtomType(symbol: 'Z', name: 'Special', color: Color(0xFFFF8800));
  static const special5 = AtomType(symbol: '!', name: 'Special', color: Color(0xFF8800FF));
  static const special6 = AtomType(symbol: '?', name: 'Special', color: Color(0xFF00FF88));
  static const special7 = AtomType(symbol: '#', name: 'Special', color: Color(0xFFFF0088));
  static const special8 = AtomType(symbol: '@', name: 'Special', color: Color(0xFF0088FF));
  static const special9 = AtomType(symbol: '%', name: 'Special', color: Color(0xFF88FF00));
  static const special10 = AtomType(symbol: '&', name: 'Special', color: Color(0xFFFF8888));
  static const special11 = AtomType(symbol: '<', name: 'Special', color: Color(0xFF88FF88));
  static const special12 = AtomType(symbol: '>', name: 'Special', color: Color(0xFF8888FF));
}

class Atom {
  final AtomType type;
  int row;
  int col;
  final String id;
  final int atomixIndex;

  Atom({required this.type, required this.row, required this.col, required this.id, required this.atomixIndex});
}

class MoleculePattern {
  final String name;
  final int size;
  final List<List<int?>> grid;
  final List<AtomType> atomTypes;

  MoleculePattern({required this.name, required this.size, required this.grid, required this.atomTypes});

  factory MoleculePattern.water() {
    return MoleculePattern(
      name: 'H₂O',
      size: 3,
      grid: [
        [null, null, null],
        [6, 8, 2],
        [null, null, null],
      ],
      atomTypes: [AtomType.hydrogen, AtomType.oxygen, AtomType.hydrogen],
    );
  }
}

class MoleculeParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  double life;
  final double maxLife;

  MoleculeParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    required this.life,
  }) : maxLife = life;

  factory MoleculeParticle.celebration(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 100 + random.nextDouble() * 200;
    
    return MoleculeParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: [Colors.cyan, Colors.green, Colors.yellow, Colors.pink][random.nextInt(4)],
      size: 4 + random.nextDouble() * 5,
      opacity: 1.0,
      life: 1.0 + random.nextDouble() * 0.6,
    );
  }

  factory MoleculeParticle.failure(Offset pos) {
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final speed = 60 + random.nextDouble() * 120;
    
    return MoleculeParticle(
      position: pos,
      velocity: Offset.fromDirection(angle, speed),
      color: Colors.red,
      size: 3 + random.nextDouble() * 4,
      opacity: 1.0,
      life: 0.8 + random.nextDouble() * 0.5,
    );
  }

  bool update(double dt) {
    position += velocity * dt;
    life -= dt;
    opacity = (life / maxLife).clamp(0.0, 1.0);
    velocity *= 0.96;
    return life <= 0;
  }

  Widget build() {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(opacity * 0.6), blurRadius: size * 2),
            ],
          ),
        ),
      ),
    );
  }
}

class MolecularBackgroundPainter extends CustomPainter {
  final double pulseIntensity;
  final bool gameWon;
  final bool gameLost;

  MolecularBackgroundPainter({required this.pulseIntensity, required this.gameWon, required this.gameLost});

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = gameLost ? Colors.red : gameWon ? Colors.green : Colors.cyan;
    final networkPaint = Paint()
      ..color = baseColor.withOpacity(0.08 * pulseIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    const hexSize = 50.0;
    final hexHeight = hexSize * math.sqrt(3);
    
    for (double y = -hexHeight; y < size.height + hexHeight; y += hexHeight * 0.75) {
      for (double x = -hexSize; x < size.width + hexSize * 2; x += hexSize * 1.5) {
        final offset = (y / hexHeight).floor() % 2 == 0 ? 0.0 : hexSize * 0.75;
        _drawHexagon(canvas, Offset(x + offset, y), hexSize * 0.4, networkPaint);
      }
    }
  }
  
  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MolecularBackgroundPainter oldDelegate) =>
      oldDelegate.pulseIntensity != pulseIntensity ||
      oldDelegate.gameWon != gameWon ||
      oldDelegate.gameLost != gameLost;
}