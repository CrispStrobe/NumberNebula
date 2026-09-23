import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../models/game_outcome.dart';
import '../models/performance.dart';
import '../../../core/theme/space_theme.dart';
import '../../../core/services/debug_provider.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';

import 'levels.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// ATOMIX LEVEL DATA INTEGRATION
// ============================================================================

AtomType getAtomTypeFromIndex(int index) {
  // Hydrogen (1 Bond)
  if (index >= 0 && index <= 7) return AtomType.hydrogen;
  
  // Oxygen (2 Bonds)
  if ((index >= 8 && index <= 13)) return AtomType.oxygen;
  
  // Carbon (3 or 4 Bonds, or special cases)
  if ((index >= 14 && index <= 28)) return AtomType.carbon;
  
  // Fluorine (1 Bond)
  if (index == 29 || index == 30) return AtomType.fluorine;
  
  // Nitrogen (3 Bonds)
  if (index == 31) return AtomType.nitrogen;
  
  // Bonus Stage "Atoms"
  if (index >= 32 && index <= 43) {
    const specials = [
      AtomType.special1, AtomType.special2, AtomType.special3, AtomType.special4,
      AtomType.special5, AtomType.special6, AtomType.special7, AtomType.special8,
      AtomType.special9, AtomType.special10, AtomType.special11, AtomType.special12,
    ];
    return specials[(index - 32) % specials.length];
  }

  // Fallback, though ideally this should not be reached.
  return AtomType.hydrogen; 
}
enum BondDirection {
  left,
  right,
  up,
  down,
  upLeft,
  upRight,
  downLeft,
  downRight,
}

Set<BondDirection> getBondingDirections(int atomIndex) {
  // Hydrogen (valency 1)
  const hydrogenBonds = {
    0: {BondDirection.down},
    1: {BondDirection.downLeft}, // Diagonal in ETHENE, BUTENE
    2: {BondDirection.left},
    3: {BondDirection.upLeft}, // Diagonal in ETHENE, BUTENE
    4: {BondDirection.up},
    5: {BondDirection.upRight}, // Diagonal in ETHENE, BUTENE
    6: {BondDirection.right},
    7: {BondDirection.downRight}, // Diagonal in ETHENE, BUTENE
    
  };

  // Oxygen (valency 2)
  const oxygenBonds = {
    8: {BondDirection.left, BondDirection.right},
    9: {BondDirection.up, BondDirection.down},
    10: {BondDirection.left},
    11: {BondDirection.up},
    12: {BondDirection.down},
    13: {BondDirection.right},
  };

  // Carbon (valency 4)
  const carbonBonds = {
    14: {BondDirection.left, BondDirection.right, BondDirection.up, BondDirection.down},
    15: {BondDirection.left, BondDirection.upRight, BondDirection.downRight}, // F in ETHENE/BUTENE - diagonal bonds
    16: {BondDirection.right, BondDirection.upLeft, BondDirection.downLeft}, // G in ETHENE/BUTENE - diagonal bonds
    17: {BondDirection.left, BondDirection.right, BondDirection.up},
    18: {BondDirection.left, BondDirection.right, BondDirection.up},
    19: {BondDirection.down, BondDirection.left, BondDirection.right},
    20: {BondDirection.upLeft, BondDirection.upRight, BondDirection.downLeft, BondDirection.downRight}, // K in BUTENE - diagonal bonds
    21: {BondDirection.upLeft, BondDirection.upRight, BondDirection.down, BondDirection.up}, // L in METHYL compounds - diagonal bonds
    22: {BondDirection.left, BondDirection.up, BondDirection.down},
    23: {BondDirection.right, BondDirection.up, BondDirection.down},
    24: {BondDirection.left, BondDirection.right, BondDirection.down},
    25: {BondDirection.left, BondDirection.right, BondDirection.down},
    26: {BondDirection.right, BondDirection.up, BondDirection.down},
    27: {BondDirection.left, BondDirection.right},
    28: {BondDirection.left, BondDirection.right, BondDirection.up}, // C in ETHINE
  };

  // Fluorine (valency 1)
  const fluorineBonds = {
    
    29: {BondDirection.up},
    30: {BondDirection.down},
  };

  // Nitrogen (valency 3)
  const nitrogenBonds = {
    31: {BondDirection.left, BondDirection.upRight, BondDirection.downRight}, // V in Ammonia
  };

  if (hydrogenBonds.containsKey(atomIndex)) return hydrogenBonds[atomIndex]!;
  if (oxygenBonds.containsKey(atomIndex)) return oxygenBonds[atomIndex]!;
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
  // Runs only while particles are alive, in step with the display.
  late final Ticker _particleTicker = createTicker(_onParticleTick);
  Duration _lastParticleTick = Duration.zero;
  Duration _particleBacklog = Duration.zero;
  static const _particleStep = Duration(milliseconds: 16);
  
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

  Offset? _panStartPosition;
  Offset? _panCurrentPosition;
  Atom? _panningAtom;

  final Set<int> _levelsWonThisSession = {}; // Track which levels won in current session
  int _startingLevel = 1; // The level we started at (based on persistent progress)
  
  List<MoleculeParticle> particles = [];

  final List<Map<String, dynamic>> _moveHistory = [];

  bool _showInstructions = false;
  
  // Keyboard focus node
  final FocusNode _focusNode = FocusNode();

  bool _showMoleculeInfo = false; // For the molecule target info overlay

  // This will hold the LOCALIZED name for the UI
  String levelDisplayName = '';

  // Store the final, translated strings for the UI
  String _moleculeDescription = '';
  String _moleculeFacts = '';
  String _moleculeSpaceInfo = '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint("\n${"=" * 60}\n⚛️  QUANTUM MOLECULE BUILDER\n   Grade: ${widget.grade}, Level: ${widget.level}\n${"=" * 60}");
    
    _setupAnimationControllers();
    
    // Initialize with default values first to prevent LateInitializationError
    levelName = '';
    targetPattern = MoleculePattern.water();
    moveLimit = 40;
    grid = List.generate(gridSize, (i) => List.filled(gridSize, CellType.empty));
    atoms = [];
    
    // Initialize starting level: highest level won at least 2 times
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
        final gameProvider = context.read<GameProvider>();
        
        // Find the highest level won at least twice by checking GameProvider's progress
        // The gameProgress value represents the current level after achieving 2+ wins
        final savedProgress = gameProvider.getGameProgress('quantum_molecule_builder');
        _startingLevel = savedProgress > 0 ? savedProgress : 1;
        _currentLevel = _startingLevel;
        
        if (kDebugMode) debugPrint("🎮 Starting at level $_startingLevel (last level with 2+ wins)");
        _loadLevel();
        }
    });
    
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

  void _startParticles() {
    if (_particleTicker.isActive) return;
    _lastParticleTick = Duration.zero;
    _particleBacklog = Duration.zero;
    _particleTicker.start();
  }

  void _onParticleTick(Duration elapsed) {
    _particleBacklog += elapsed - _lastParticleTick;
    _lastParticleTick = elapsed;
    // Fixed 16 ms steps keep the per-step damping in MoleculeParticle.update
    // the same on 60 Hz and 120 Hz displays.
    setState(() {
      while (_particleBacklog >= _particleStep && particles.isNotEmpty) {
        _particleBacklog -= _particleStep;
        particles.removeWhere((p) => p.update(0.016));
      }
    });
    if (particles.isEmpty) _particleTicker.stop();
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

  void _loadLevel({int? levelToLoad}) {
    if (levelsData.isEmpty) {
      _loadFallbackLevel();
      return;
    }

    final levelNum = levelToLoad ?? _currentLevel;
    final levelMap = levelsData[(levelNum - 1) % levelsData.length];

    setState(() {
      _currentLevel = levelNum;
      // Reset info strings before loading new ones
      _moleculeDescription = '';
      _moleculeFacts = '';
      _moleculeSpaceInfo = '';
    });

    try {
      final level = AtomixLevel.fromMap(levelMap);
      final s = S.of(context)!; // Get localization delegate

      // Helper to get the level label string
      String getLevelLabel(int levelNum) {
        switch (levelNum) {
          case 1: return s.level01Label;
          case 2: return s.level02Label;
          case 3: return s.level03Label;
          case 4: return s.level04Label;
          case 5: return s.level05Label;
          case 6: return s.level06Label;
          case 7: return s.level07Label;
          case 8: return s.level08Label;
          case 9: return s.level09Label;
          case 10: return s.level10Label;
          case 11: return s.level11Label;
          case 12: return s.level12Label;
          case 13: return s.level13Label;
          case 14: return s.level14Label;
          case 15: return s.level15Label;
          case 16: return s.level16Label;
          case 17: return s.level17Label;
          case 18: return s.level18Label;
          case 19: return s.level19Label;
          case 20: return s.level20Label;
          case 21: return s.level21Label;
          case 22: return s.level22Label;
          case 23: return s.level23Label;
          case 24: return s.level24Label;
          case 25: return s.level25Label;
          case 26: return s.level26Label;
          case 27: return s.level27Label;
          case 28: return s.level28Label;
          case 29: return s.level29Label;
          case 30: return s.level30Label;
          default: return level.name; // Fallback
        }
      }

      setState(() {
        levelDisplayName = getLevelLabel(level.levelNumber);
        levelName = level.name;
      });

      if (level.name.toUpperCase() != 'BONUS STAGE') {
        final levelKey = level.levelNumber.toString().padLeft(2, '0');
        final descKey = 'level${levelKey}Desc';
        final factsKey = 'level${levelKey}Facts';
        final spaceKey = 'level${levelKey}Space';

        String getInfoString(String key) {
          // This switch maps the generated key to the actual S class getter
          switch (key) {
            case 'level01Desc': return s.level01Desc;
            case 'level01Facts': return s.level01Facts;
            case 'level01Space': return s.level01Space;
            case 'level02Desc': return s.level02Desc;
            case 'level02Facts': return s.level02Facts;
            case 'level02Space': return s.level02Space;
            case 'level03Desc': return s.level03Desc;
            case 'level03Facts': return s.level03Facts;
            case 'level03Space': return s.level03Space;
            case 'level04Desc': return s.level04Desc;
            case 'level04Facts': return s.level04Facts;
            case 'level04Space': return s.level04Space;
            case 'level05Desc': return s.level05Desc;
            case 'level05Facts': return s.level05Facts;
            case 'level05Space': return s.level05Space;
            case 'level07Desc': return s.level07Desc;
            case 'level07Facts': return s.level07Facts;
            case 'level07Space': return s.level07Space;
            case 'level08Desc': return s.level08Desc;
            case 'level08Facts': return s.level08Facts;
            case 'level08Space': return s.level08Space;
            case 'level09Desc': return s.level09Desc;
            case 'level09Facts': return s.level09Facts;
            case 'level09Space': return s.level09Space;
            case 'level10Desc': return s.level10Desc;
            case 'level10Facts': return s.level10Facts;
            case 'level10Space': return s.level10Space;
            case 'level11Desc': return s.level11Desc;
            case 'level11Facts': return s.level11Facts;
            case 'level11Space': return s.level11Space;
            case 'level13Desc': return s.level13Desc;
            case 'level13Facts': return s.level13Facts;
            case 'level13Space': return s.level13Space;
            case 'level14Desc': return s.level14Desc;
            case 'level14Facts': return s.level14Facts;
            case 'level14Space': return s.level14Space;
            case 'level15Desc': return s.level15Desc;
            case 'level15Facts': return s.level15Facts;
            case 'level15Space': return s.level15Space;
            case 'level16Desc': return s.level16Desc;
            case 'level16Facts': return s.level16Facts;
            case 'level16Space': return s.level16Space;
            case 'level17Desc': return s.level17Desc;
            case 'level17Facts': return s.level17Facts;
            case 'level17Space': return s.level17Space;
            case 'level19Desc': return s.level19Desc;
            case 'level19Facts': return s.level19Facts;
            case 'level19Space': return s.level19Space;
            case 'level20Desc': return s.level20Desc;
            case 'level20Facts': return s.level20Facts;
            case 'level20Space': return s.level20Space;
            case 'level21Desc': return s.level21Desc;
            case 'level21Facts': return s.level21Facts;
            case 'level21Space': return s.level21Space;
            case 'level22Desc': return s.level22Desc;
            case 'level22Facts': return s.level22Facts;
            case 'level22Space': return s.level22Space;
            case 'level23Desc': return s.level23Desc;
            case 'level23Facts': return s.level23Facts;
            case 'level23Space': return s.level23Space;
            case 'level25Desc': return s.level25Desc;
            case 'level25Facts': return s.level25Facts;
            case 'level25Space': return s.level25Space;
            case 'level26Desc': return s.level26Desc;
            case 'level26Facts': return s.level26Facts;
            case 'level26Space': return s.level26Space;
            case 'level27Desc': return s.level27Desc;
            case 'level27Facts': return s.level27Facts;
            case 'level27Space': return s.level27Space;
            case 'level28Desc': return s.level28Desc;
            case 'level28Facts': return s.level28Facts;
            case 'level28Space': return s.level28Space;
            case 'level29Desc': return s.level29Desc;
            case 'level29Facts': return s.level29Facts;
            case 'level29Space': return s.level29Space;
            default: return ''; // Fallback
          }
        }
        _moleculeDescription = getInfoString(descKey);
        _moleculeFacts = getInfoString(factsKey);
        _moleculeSpaceInfo = getInfoString(spaceKey);
      }

      grid = List.generate(gridSize, (y) {
        return List.generate(gridSize, (x) {
          final tile = level.playfield[y][x];
          return tile['type'] == 'wall' ? CellType.wall : CellType.empty;
        });
      });

      atoms = [];
      int atomIdCounter = 0;
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
              id: 'atom_${atomIdCounter++}',
              atomixIndex: atomIndex,
            ));
          }
        }
      }
      if (kDebugMode) debugPrint("  - Found ${atoms.length} atoms on playfield.");

      _calculateVisibleBounds();
      targetPattern = _buildPatternFromSolution(level);

      // --- MODIFIED: Move limit calculation ---
      double baseMoveLimit = ((level.duration / 4.5) + (atoms.length * 1.5));
      
      // Calculate modifier based on grade
      double gradeModifier = 1.0;
      if (widget.grade == 3) {
        gradeModifier = 1.1;
      } else if (widget.grade == 2) {
        gradeModifier = 1.2;
      } else if (widget.grade == 1) {
        gradeModifier = 1.3;
      }
      // Grade 4 has modifier 1.0

      moveLimit = (baseMoveLimit * gradeModifier).round().clamp(20, 150);
      // --- End of modification ---

      if (kDebugMode) debugPrint("✅ Level ${level.levelNumber}: ${level.name} loaded (${atoms.length} atoms, $moveLimit moves [Grade: ${widget.grade}])");

    } catch (e) {
      debugPrint("❌ Error loading level $_currentLevel: $e");
      _loadFallbackLevel();
    }
  }

  bool _isBonusLevel() {
    // Check against the internal, non-localized name from the level data
    if (levelsData.isEmpty || _currentLevel > levelsData.length) return false;
    final levelMap = levelsData[(_currentLevel - 1)];
    final internalName = levelMap['name'] as String? ?? '';
    return internalName.toUpperCase().contains('BONUS');
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
    levelName = '';
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

  void _handleAtomPanStart(Atom atom, DragStartDetails details) {
    if (!gameActive || slidingAtom != null) return;
    
    setState(() {
        _panStartPosition = details.localPosition;
        _panCurrentPosition = details.localPosition;
        _panningAtom = atom;
    });
    }

  void _handleAtomPanUpdate(DragUpdateDetails details) {
    if (_panStartPosition == null) return;
    
    setState(() {
        _panCurrentPosition = details.localPosition;
    });
    }

  void _handleAtomPanEnd(Atom atom) {
    if (_panStartPosition == null || _panCurrentPosition == null || _panningAtom == null) {
        return;
    }
    
    final delta = _panCurrentPosition! - _panStartPosition!;
    final distance = delta.distance;
    
    // Threshold for distinguishing swipe from tap (in logical pixels)
    const swipeThreshold = 30.0;
    
    if (distance > swipeThreshold) {
        // It's a swipe - determine the primary direction
        Direction direction;
        if (delta.dx.abs() > delta.dy.abs()) {
        // Horizontal swipe
        direction = delta.dx > 0 ? Direction.right : Direction.left;
        } else {
        // Vertical swipe
        direction = delta.dy > 0 ? Direction.down : Direction.up;
        }
        
        // Ensure the atom is selected before moving
        if (selectedAtom?.id != _panningAtom!.id) {
        setState(() {
            selectedAtom = _panningAtom;
        });
        }
        
        // Perform the slide movement
        _moveAtom(direction);
    } else {
        // It's a tap - just select the atom
        _selectAtom(_panningAtom!);
    }
    
    // Reset pan tracking state
    setState(() {
        _panStartPosition = null;
        _panCurrentPosition = null;
        _panningAtom = null;
    });
    }

  void _moveAtom(Direction direction) {
    if (selectedAtom == null || !gameActive || slidingAtom != null) return;
    
    final atom = selectedAtom!;
    int newRow = atom.row;
    int newCol = atom.col;
    
    switch (direction) {
      case Direction.up:
        while (newRow > 0 && _canMoveTo(newRow - 1, newCol, atom)) {
          newRow--;
        }
        break;
      case Direction.down:
        while (newRow < gridSize - 1 && _canMoveTo(newRow + 1, newCol, atom)) {
          newRow++;
        }
        break;
      case Direction.left:
        while (newCol > 0 && _canMoveTo(newRow, newCol - 1, atom)) {
          newCol--;
        }
        break;
      case Direction.right:
        while (newCol < gridSize - 1 && _canMoveTo(newRow, newCol + 1, atom)) {
          newCol++;
        }
        break;
    }
    
    if (newRow != atom.row || newCol != atom.col) {
      HapticFeedback.lightImpact();

      _moveHistory.add({
        'atomId': atom.id,
        'fromRow': atom.row,
        'fromCol': atom.col,
      });
      
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

  /// Best partial match of the target molecule anywhere on the grid — how
  /// close the player got, used to report progress on a failed run.
  int _atomsInPlace() {
    int best = 0;
    for (int startRow = 0; startRow <= gridSize - targetPattern.size; startRow++) {
      for (int startCol = 0; startCol <= gridSize - targetPattern.size; startCol++) {
        int matches = 0;
        for (int i = 0; i < targetPattern.size; i++) {
          for (int j = 0; j < targetPattern.size; j++) {
            final expectedIndex = targetPattern.grid[i][j];
            if (expectedIndex == null) continue;
            final hasAtom = atoms.any((a) =>
                a.row == startRow + i &&
                a.col == startCol + j &&
                a.atomixIndex == expectedIndex);
            if (hasAtom) matches++;
          }
        }
        if (matches > best) best = matches;
      }
    }
    return best;
  }

  void _undoLastMove() {
    if (_moveHistory.isEmpty || !gameActive) return;

    HapticFeedback.mediumImpact();

    final lastMove = _moveHistory.removeLast();
    final atomToUndo = atoms.firstWhere(
      (a) => a.id == lastMove['atomId'],
      // Provide a fallback, though it should never be needed
      orElse: () => Atom(type: AtomType.hydrogen, row: -1, col: -1, id: 'null', atomixIndex: -1),
    );

    if (atomToUndo.id != 'null') {
      setState(() {
        atomToUndo.row = lastMove['fromRow'] as int;
        atomToUndo.col = lastMove['fromCol'] as int;
        movesMade += 2; // Apply the 2-move penalty
        selectedAtom = null; // Deselect to avoid confusion
      });
      _checkLoseCondition(); // Re-check if the penalty caused a loss
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
    
    // Mark this level as won in current session
    _levelsWonThisSession.add(_currentLevel);
    
    _successController.forward();
    HapticFeedback.heavyImpact();
    
    for (int i = 0; i < 60; i++) {
      particles.add(MoleculeParticle.celebration(MediaQuery.of(context).size.center(Offset.zero)));
    }
    _startParticles();
    
    final baseScore = 300 * widget.grade;
    final efficiencyBonus = math.max(0, (moveLimit - movesMade) * 10);
    final totalScore = baseScore + efficiencyBonus;
    
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'quantum_molecule_builder',
      difficulty: widget.grade + (widget.level ~/ 5),
      score: totalScore,
      // The move limit is deliberately generous; assembling the molecule
      // inside half of it is what a clean solution looks like.
      performance: Perf.fromMoves(movesMade, (moveLimit * 0.5).round()),
    ));
    
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
    
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'quantum_molecule_builder',
      difficulty: widget.grade + (widget.level ~/ 5),
      progress: atoms.isEmpty ? 0.0 : _atomsInPlace() / atoms.length,
    ));
    
    for (int i = 0; i < 40; i++) {
      particles.add(MoleculeParticle.failure(MediaQuery.of(context).size.center(Offset.zero)));
    }
    _startParticles();
    
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

  void _navigateToLevel(int newLevel) {
    if (newLevel < 1 || newLevel > levelsData.length) return;
    
    setState(() {
      _currentLevel = newLevel;
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
    
    _loadLevel(levelToLoad: newLevel);
    _successController.reset();
    _focusNode.requestFocus();
  }

  void _goToPreviousLevel() {
    if (_canNavigateBackward()) {
      _navigateToLevel(_currentLevel - 1);
      HapticFeedback.selectionClick();
    }
  }

  void _goToNextLevel() {
    if (_canNavigateForward()) {
      _navigateToLevel(_currentLevel + 1);
      HapticFeedback.selectionClick();
    }
  }

  bool _canNavigateForward() {
    // Can't go beyond available levels
    // This check should always be first, even in debug mode.
    if (_currentLevel >= levelsData.length) return false;

    // Access the debug provider so that we can check the flag.
    final debugProvider = context.read<DebugProvider>();
    
    // Check if the debug menu has been enabled for this session.
    if (debugProvider.isDebugMenuEnabled) {
      return true; // If debug menu is on, always allow moving forward.
    }
    
    // Can go forward if:
    // 1. We've won the current level this session, OR
    // 2. The next level is within our already-unlocked levels (at or below starting level)
    return _levelsWonThisSession.contains(_currentLevel) || 
           (_currentLevel + 1) <= _startingLevel;
  }

  bool _canNavigateBackward() {
    return _currentLevel > 1;
  }

  Widget _buildInfoButton() {
    return IconButton(
      icon: Icon(Icons.info_outline, color: SpaceTheme.alienGreen.withValues(alpha: 0.8)),
      onPressed: () {
        setState(() {
          _showInstructions = true;
        });
        HapticFeedback.selectionClick();
      },
      tooltip: S.of(context)!.moleculeBuilderHelp,
    );
  }

  Widget _buildInstructionsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showInstructions = false), // Tap background to close
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SpaceTheme.deepSpace,
                    SpaceTheme.nebulaPurple.withValues(alpha: 0.4)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context)!.moleculeBuilderInfoTitle,
                          style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _showInstructions = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(S.of(context)!.moleculeBuilderInfoGoal, style: SpaceTheme.bodyStyle),
                    const SizedBox(height: 12),
                    Text(S.of(context)!.moleculeBuilderInfoHowTo, style: SpaceTheme.bodyStyle),
                    const SizedBox(height: 12),
                    Text(S.of(context)!.moleculeBuilderInfoMoves, style: SpaceTheme.bodyStyle),
                    const SizedBox(height: 12),
                    Text(S.of(context)!.moleculeBuilderInfoUndo, style: SpaceTheme.bodyStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled 
            ? SpaceTheme.nebulaPurple.withValues(alpha: 0.8)
            : SpaceTheme.deepSpace.withValues(alpha: 0.4),
        foregroundColor: isEnabled 
            ? SpaceTheme.alienGreen 
            : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isEnabled 
                ? SpaceTheme.alienGreen.withValues(alpha: 0.5) 
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > screenSize.height && screenSize.width > 600;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: _focusNode.requestFocus,
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
                      // REPLACED: The old GameUI and Padding rows are gone
                      _buildTopBar(), 

                      Expanded(
                        child: isWideScreen ? _buildWideLayout() : _buildCompactLayout(),
                      ),
                    ],
                  ),

                  if (_showInstructions) _buildInstructionsOverlay(),

                  if (_showMoleculeInfo) _buildInfoOverlay(),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3), width: 1),
        ),
      ),
      // Use LayoutBuilder to get the available width
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Define a breakpoint below which the title is hidden
          const double titleBreakpoint = 450.0;
          bool showTitle = constraints.maxWidth > titleBreakpoint;

          return Row(
            children: [
              // Back Button (Always shown)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),

              // Title (Conditionally shown)
              if (showTitle)
                Padding(
                  // Add some padding when title is shown
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    S.of(context)!.moleculeBuilderTitle,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 18, color: Colors.white),
                  ),
                ),

              const Spacer(), // Pushes remaining items to the right

              // Previous Level
              _buildNavigationButton(
                icon: Icons.arrow_back_ios,
                label: '',
                onPressed: _canNavigateBackward() ? _goToPreviousLevel : null,
              ),
              const SizedBox(width: 8),

              // Level Counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SpaceTheme.starYellow, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${S.of(context)!.moleculeBuilderLevel} $_currentLevel/${levelsData.length}',
                      style: const TextStyle(
                        color: SpaceTheme.starYellow,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_levelsWonThisSession.contains(_currentLevel)) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: SpaceTheme.alienGreen,
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Next Level
              _buildNavigationButton(
                icon: Icons.arrow_forward_ios,
                label: '',
                onPressed: _canNavigateForward() ? _goToNextLevel : null,
              ),

              // Info Button
              _buildInfoButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    final screenSize = MediaQuery.of(context).size;

    // Width calculations remain the same
    final leftPanelWidth = screenSize.width * 0.22;
    final rightPanelWidth = screenSize.width * 0.78;

    // Height calculation adjusted slightly for the top bar
    final availableHeight = screenSize.height - 60; // Adjusted for top bar height
    final cellSize = math.min(
      rightPanelWidth / visibleWidth,
      availableHeight / visibleHeight,
    ).clamp(25.0, 55.0);

    return Row(
      children: [
        Container(
          width: leftPanelWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12.0), // Vertical padding removed here
          // --- MODIFIED: Added SingleChildScrollView ---
          child: SingleChildScrollView(
            // Padding moved inside scroll view
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
              children: [
                // Top content group
                Column(
                  mainAxisSize: MainAxisSize.min, // Prevent this group from expanding unnecessarily
                  children: [
                     GestureDetector(
                       onTap: () {
                         setState(() => _showMoleculeInfo = true);
                         HapticFeedback.selectionClick();
                       },
                       child: _buildCompactTargetDisplay(),
                     ),
                     const SizedBox(height: 16),
                     _buildStats(),
                     const SizedBox(height: 16),
                     if (gameActive && selectedAtom != null) ...[
                       _buildSelectedInfo(),
                       const SizedBox(height: 12),
                       _buildCompactControls(),
                       const SizedBox(height: 12), // Add some space after controls
                     ],
                  ]
                ),


                // Spacer removed, Column layout handles spacing
                
                // Bottom content group (Undo/Restart)
                if (gameActive)
                  Padding(
                    // Added padding to ensure space above buttons if controls are hidden
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: _buildUndoButton()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildRestartButton()),
                      ],
                    ),
                  ),
                // Removed bottom SizedBox, padding handled by ScrollView/Container
              ],
            ),
          ),
          // --- End of modification ---
        ),
        Expanded(
          child: Center(
            child: _buildGameGrid(cellSize),
          ),
        ),
      ],
    );
  }

  Widget _buildUndoButton() {
    bool canUndo = _moveHistory.isNotEmpty;

    return ElevatedButton(
      onPressed: canUndo ? _undoLastMove : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canUndo
            ? SpaceTheme.secondaryButtonStyle.backgroundColor?.resolve({})
            : SpaceTheme.deepSpace.withValues(alpha: 0.4),
        foregroundColor: canUndo
            ? SpaceTheme.secondaryButtonStyle.foregroundColor?.resolve({})
            : Colors.grey,
        // MODIFIED: Adjusted padding for a more square, icon-only button
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: canUndo
                ? SpaceTheme.cosmicPink.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
      ),
      // MODIFIED: Child is just the Icon
      child: const Icon(Icons.undo, size: 16),
    );
  }

  Widget _buildCompactLayout() {
    final screenSize = MediaQuery.of(context).size;

    final availableWidth = screenSize.width - 24;
    // Adjusted availableHeight to account for the new, slimmer top bar
    final availableHeight = screenSize.height - 240; 

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
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showMoleculeInfo = true);
                    HapticFeedback.selectionClick();
                  },
                  child: _buildCompactTargetDisplay(),
                ),
              ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCompactControls(),
              const SizedBox(width: 12),
              // CHANGED: Wrapped buttons in Expanded
              Expanded(child: _buildUndoButton()),
              const SizedBox(width: 8),
              Expanded(child: _buildRestartButton()),
            ],
          ),
        ] else if (gameActive) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CHANGED: Wrapped buttons in Expanded
              Expanded(child: _buildUndoButton()),
              const SizedBox(width: 8),
              Expanded(child: _buildRestartButton()),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRestartButton() {
    return ElevatedButton(
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
          _moveHistory.clear(); // Ensure history is cleared on restart
        });
        _loadLevel();
        _successController.reset();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.6),
        foregroundColor: SpaceTheme.starYellow,
        // MODIFIED: Adjusted padding for a more square, icon-only button
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: SpaceTheme.starYellow.withValues(alpha: 0.5), width: 2),
        ),
      ),
      // MODIFIED: Child is just the Icon
      child: const Icon(Icons.refresh, size: 16),
    );
  }

  Widget _buildCompactTargetDisplay() {
    const double maxPreviewWidth = 96.0;
    final double atomSize = (targetPattern.size > 0)
        ? (maxPreviewWidth / targetPattern.size)
        : 16.0;
    final double containerSize = atomSize * targetPattern.size;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // REMOVED: "ZIEL" Text
          Text(
            levelDisplayName,
            style: const TextStyle(
              color: SpaceTheme.starYellow,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: containerSize,
            height: containerSize,
            child: Stack(
              children: _buildTargetAtomsCompact(atomSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoleculeInfoOverlay() {
    Widget buildInfoSection(String title, String content) {
      if (content.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: SpaceTheme.bodyStyle.copyWith(
                color: SpaceTheme.alienGreen,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Text(
                content,
                style: SpaceTheme.bodyStyle.copyWith(height: 1.6, color: Colors.white.withValues(alpha: 0.95)),
              ),
            ),
          ],
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 600;
    final previewSize = isCompact ? screenSize.width * 0.7 : screenSize.width * 0.35;
    final atomSize = (targetPattern.size > 0) ? (previewSize / targetPattern.size) : 40.0;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showMoleculeInfo = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple.withValues(alpha: 0.4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: SpaceTheme.starYellow, width: 2),
                boxShadow: [
                  BoxShadow(color: SpaceTheme.starYellow.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            S.of(context)!.moleculeBuilderMoleculeInfo,
                            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.starYellow),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => setState(() => _showMoleculeInfo = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      levelDisplayName,
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 26, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: previewSize,
                      height: previewSize,
                      child: Stack(
                        children: _buildTargetAtomsCompact(atomSize),
                      ),
                    ),
                    const SizedBox(height: 24),
                    buildInfoSection(S.of(context)!.moleculeInfoNomenclature, _moleculeDescription),
                    buildInfoSection(S.of(context)!.moleculeInfoKeyFacts, _moleculeFacts),
                    buildInfoSection(S.of(context)!.moleculeInfoInSpace, _moleculeSpaceInfo),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBonusStageInfoOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 600;
    final previewSize = isCompact ? screenSize.width * 0.75 : screenSize.width * 0.4;
    final atomSize = (targetPattern.size > 0) ? (previewSize / targetPattern.size) : 40.0;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showMoleculeInfo = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple.withValues(alpha: 0.4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                 boxShadow: [
                  BoxShadow(color: SpaceTheme.alienGreen.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context)!.moleculeBuilderBonusTitle,
                        style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => setState(() => _showMoleculeInfo = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: previewSize,
                    height: previewSize,
                    child: Stack(
                      children: _buildTargetAtomsCompact(atomSize),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    if (_isBonusLevel()) {
      return _buildBonusStageInfoOverlay();
    } else {
      return _buildMoleculeInfoOverlay();
    }
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
        _buildStatRow(Icons.swap_horiz, S.of(context)!.moleculeBuilderMoves, '$movesMade/$moveLimit', SpaceTheme.alienGreen),
        // REMOVED: "Atoms" stat row
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
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    // Get the localized name using the helper, pass context
    final localizedName = selectedAtom != null 
        ? getLocalizedAtomName(selectedAtom!.type, context) 
        : S.of(context)!.moleculeBuilderNone; // Use ARB string for "None" too

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.starYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.starYellow.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              // Use the localized name here
              '${S.of(context)!.moleculeBuilderSelected}: $localizedName', 
              style: const TextStyle(
                color: SpaceTheme.starYellow,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              softWrap: true, 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactControls() {
    // Define the buttons first for clarity
    Widget upButton = _buildControlButton(Icons.arrow_upward, () => _moveAtom(Direction.up));
    Widget downButton = _buildControlButton(Icons.arrow_downward, () => _moveAtom(Direction.down));
    Widget leftButton = _buildControlButton(Icons.arrow_back, () => _moveAtom(Direction.left));
    Widget rightButton = _buildControlButton(Icons.arrow_forward, () => _moveAtom(Direction.right));
    
    // Use LayoutBuilder to decide between 1-3 and 2-2 layout
    return LayoutBuilder(
      builder: (context, constraints) {
        // Estimate the width needed for the 1-3 layout (approx 3 buttons + spacing)
        // You might need to adjust this value based on your button size/padding
        const double wideLayoutThreshold = 150.0; 

        if (constraints.maxWidth >= wideLayoutThreshold) {
          // Wider layout: Up on top, Left/Down/Right below
          return Column(
            mainAxisSize: MainAxisSize.min, // Take minimum space
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, // Center the Up button
                children: [
                  // Spacer to push the up button to the center visually above the 3 buttons
                  const SizedBox(width: 44 + 4), // Approx width of button + spacing
                  upButton,
                  const SizedBox(width: 44 + 4), // Approx width of button + spacing
                ],
              ),
              const SizedBox(height: 4), // Spacing between rows
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, // Center the bottom row
                children: [
                  leftButton,
                  const SizedBox(width: 4),
                  downButton,
                  const SizedBox(width: 4),
                  rightButton,
                ],
              ),
            ],
          );
        } else {
          // Narrower layout: 2x2 grid
          return Column(
            mainAxisSize: MainAxisSize.min, // Take minimum space
             children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                  upButton,
                  const SizedBox(width: 4),
                  downButton,
                ],
              ),
              const SizedBox(height: 4), // Spacing between rows
              Row(
                mainAxisSize: MainAxisSize.min,
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                  leftButton,
                  const SizedBox(width: 4),
                  rightButton,
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.nebulaPurple.withValues(alpha: 0.6),
        foregroundColor: SpaceTheme.alienGreen,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: SpaceTheme.alienGreen.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Icon(icon, size: 18),
    );
  }

  Widget _buildAtomVisual(AtomType atomType, double size, bool isSelected, Set<BondDirection> bonds) {
    final isLightAtom = atomType == AtomType.hydrogen || atomType == AtomType.fluorine;
    
    // Define stub properties relative to cell size
    final stubLength = size * 0.28;
    final diagonalStubLength = size * 0.65;
    final stubThickness = size * 0.15;
    final halfStubThickness = stubThickness / 2;
    final stubColor = Colors.white.withValues(alpha: 0.8);
    
    // Base container for the bond stub, before rotation/positioning
    Widget buildStub(double width, double height, BorderRadius radius) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: stubColor,
          borderRadius: radius,
        ),
      );
    }
    
    // Helper to build a vertical/horizontal stub
    Widget buildCardinalStub(BondDirection dir) {
        switch (dir) {
            case BondDirection.left:
            case BondDirection.right:
                return buildStub(stubLength, stubThickness, 
                    dir == BondDirection.left 
                        ? BorderRadius.horizontal(left: Radius.circular(halfStubThickness))
                        : BorderRadius.horizontal(right: Radius.circular(halfStubThickness))
                );
            case BondDirection.up:
            case BondDirection.down:
                return buildStub(stubThickness, stubLength, 
                    dir == BondDirection.up 
                        ? BorderRadius.vertical(top: Radius.circular(halfStubThickness))
                        : BorderRadius.vertical(bottom: Radius.circular(halfStubThickness))
                );
            // Should not happen for cardinal stubs
            default:
                return const SizedBox.shrink();
        }
    }
    
    // Helper to build a diagonal stub using rotation
    Widget buildDiagonalStub(double angle, double translateX, double translateY, double length) {
        return Transform.translate(
            offset: Offset(translateX, translateY),
            child: Transform.rotate(
                angle: angle,
                alignment: Alignment.center,
                child: buildStub(length, stubThickness, // Uses the passed-in length
                    BorderRadius.horizontal(left: Radius.circular(halfStubThickness))
                ),
            ),
        );
    }
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Bond stubs - ADDED: Diagonal Bond Drawing
          ...bonds.map((dir) {
            switch (dir) {
              case BondDirection.left:
                return Positioned(
                  left: 0,
                  top: (size - stubThickness) / 2,
                  child: buildCardinalStub(dir),
                );
              
              case BondDirection.right:
                return Positioned(
                  right: 0,
                  top: (size - stubThickness) / 2,
                  child: buildCardinalStub(dir),
                );
              
              case BondDirection.up:
                return Positioned(
                  top: 0,
                  left: (size - stubThickness) / 2,
                  child: buildCardinalStub(dir),
                );
              
              case BondDirection.down:
                return Positioned(
                  bottom: 0,
                  left: (size - stubThickness) / 2,
                  child: buildCardinalStub(dir),
                );
                
              case BondDirection.upLeft:
                return buildDiagonalStub(
                    -3 * math.pi / 4,  // Fixed angle
                    size * 0.25 - diagonalStubLength / 2,  // Original positioning
                    size * 0.25 - halfStubThickness,       // Original positioning
                    diagonalStubLength
                );
                
              case BondDirection.upRight:
                return buildDiagonalStub(
                    -math.pi / 4,  // Fixed angle
                    size * 0.75 - diagonalStubLength / 2,
                    size * 0.25 - halfStubThickness,
                    diagonalStubLength
                );
                
              case BondDirection.downLeft:
                return buildDiagonalStub(
                    3 * math.pi / 4,  // Fixed angle
                    size * 0.25 - diagonalStubLength / 2,
                    size * 0.75 - halfStubThickness,
                    diagonalStubLength
                );
                
              case BondDirection.downRight:
                return buildDiagonalStub(
                    math.pi / 4,
                    size * 0.75 - diagonalStubLength / 2,
                    size * 0.75 - halfStubThickness,
                    diagonalStubLength
                );
            }
          }),
          
          // Main atom circle
          Center(
            child: Container(
              width: size * 0.65,
              height: size * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    atomType.color.withValues(alpha: 0.9),
                    atomType.color,
                    atomType.color.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                border: Border.all(
                  color: isSelected 
                      ? SpaceTheme.starYellow 
                      : isLightAtom
                          ? const Color(0xFFCCCCCC)
                          : Colors.white.withValues(alpha: 0.9),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? SpaceTheme.starYellow : atomType.color)
                        .withValues(alpha: isSelected ? 0.8 : 0.6),
                    blurRadius: isSelected ? 16 : 10,
                    spreadRadius: isSelected ? 3 : 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
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
                        color: Colors.white.withValues(alpha: isLightAtom ? 0.6 : 0.4),
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
            color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
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
                  color: isWall ? const Color(0xFF1A2F3F) : Colors.white.withValues(alpha: 0.05),
                  width: isWall ? 1.5 : 0.5,
                ),
                boxShadow: isWall
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
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
            child: Semantics(
              label: S.of(context)!.a11yAtom(atom.type.name),
              hint: 'Tap to select, drag to slide',
              button: true,
              selected: isSelected,
              child: GestureDetector(
                onTap: () => _selectAtom(atom),
                // Add pan gesture handlers for touch sliding
                onPanStart: (details) => _handleAtomPanStart(atom, details),
                onPanUpdate: _handleAtomPanUpdate,
                onPanEnd: (details) => _handleAtomPanEnd(atom),
                behavior: HitTestBehavior.opaque, // Ensure gesture detection works
                child: _buildAtomVisual(atom.type, cellSize, isSelected, bonds),
              ),
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
                    levelDisplayName,
                    style: const TextStyle(
                        color: SpaceTheme.alienGreen,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                    ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                    S.of(context)!.moleculeBuilderWinTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                    S.of(context)!.moleculeBuilderWinDesc(movesMade, totalScore, efficiencyBonus),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                        Flexible(
                        child: ElevatedButton(
                            autofocus: true,
                            onPressed: () {
                            Navigator.of(context).pop();
                            _resetGame(nextLevel: _currentLevel + 1);
                            },
                            style: SpaceTheme.secondaryButtonStyle,
                            child: Text(S.of(context)!.moleculeBuilderNextMolecule, style: const TextStyle(fontSize: 13)),
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
                            child: Text(S.of(context)!.toTheBridge, style: const TextStyle(fontSize: 13)),
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
            Text(
                S.of(context)!.moleculeBuilderLoseTitle,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
                S.of(context)!.moleculeBuilderLoseDesc,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                Flexible(
                    child: ElevatedButton(
                    autofocus: true,
                    onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                    },
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(S.of(context)!.tryAgain, style: const TextStyle(fontSize: 13)),
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
                    child: Text(S.of(context)!.toTheBridge, style: const TextStyle(fontSize: 13)),
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
        _moveHistory.clear();
        gameActive = true;
        hasWon = false;
        hasLost = false;
        movesMade = 0;
        selectedAtom = null;
        slidingAtom = null;
        slideStartPos = null;
        slideEndPos = null;
        particles.clear();
        // Reset pan gesture tracking
        _panStartPosition = null;
        _panCurrentPosition = null;
        _panningAtom = null;
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
    _particleTicker.dispose();
    super.dispose();
  }
}

// ==============================================================================
// Data Models (unchanged)
// ==============================================================================

enum CellType { empty, wall }
enum Direction { up, down, left, right }

String getLocalizedAtomName(AtomType type, BuildContext context) {
  final s = S.of(context)!; // Get localization delegate

  if (type == AtomType.hydrogen) return s.atomNameHydrogen;
  if (type == AtomType.oxygen) return s.atomNameOxygen;
  if (type == AtomType.carbon) return s.atomNameCarbon;
  if (type == AtomType.nitrogen) return s.atomNameNitrogen;
  if (type == AtomType.sulfur) return s.atomNameSulfur;
  if (type == AtomType.fluorine) return s.atomNameFluorine;
  // Handle all special types generically
  if (type.symbol.length == 1 && !'HOCNSF'.contains(type.symbol)) return s.atomNameSpecial; 
  
  // Fallback if type is somehow unknown
  return type.name; 
}

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
            color: color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: opacity * 0.6), blurRadius: size * 2),
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
      ..color = baseColor.withValues(alpha: 0.08 * pulseIntensity)
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