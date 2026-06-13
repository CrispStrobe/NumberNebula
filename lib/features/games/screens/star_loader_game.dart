// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
// Import for MaskFilter

import '../models/game_outcome.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../services/starloader_level_manager.dart';
import 'package:flutter/foundation.dart';


// --- Enums for Game Logic ---

enum CellType { floor, wall, target }

class MoveHistory {
  final Offset playerPos;
  final Offset? pushedBoxOrigin;

  MoveHistory({required this.playerPos, this.pushedBoxOrigin});
}

// --- Level Data Structure ---
class LevelData {
  final String id;
  final List<String> layout;
  final int optimalMoves;

  LevelData({required this.id, required this.layout, required this.optimalMoves});
}

// --- Main Game Widget ---

class StarLoaderGame extends StatefulWidget {
  final int grade;
  final int level;

  const StarLoaderGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<StarLoaderGame> createState() => _StarLoaderGameState();
}

class _StarLoaderGameState extends State<StarLoaderGame>
    with TickerProviderStateMixin {
  
  // --- 1. Level & Grid State ---
  late LevelData _currentLevelData; 
  late List<List<CellType>> _grid;
  late Offset _playerPos;
  late int _playerDirection;
  late List<Offset> _boxPositions;
  late List<Offset> _targetPositions;
  late int _optimalMoves;
  // In production, set this to false to hide the rating UI
  static const bool ENABLE_LEVEL_RATING = true; // kDebugMode; 
  int _currentRating = 0; // Local state for the dialog

  // --- 2. Loading State ---
  bool _isLoading = true; 

  // --- 3. Game Logic State (These were missing!) ---
  final List<MoveHistory> _moveHistory = [];
  int _moveCount = 0;
  bool _hasWon = false;
  final Stopwatch _stopwatch = Stopwatch();

  // --- 4. Animation & Controls ---
  late AnimationController _winPulseController;
  late AnimationController _particleController;
  late AnimationController _celebrationController;
  late AnimationController _pushController; 

  late Animation<double> _winPulseAnimation;
  late Animation<double> _pushAnimation; 

  final FocusNode _focusNode = FocusNode();

  // --- 5. Particles ---
  final List<StarParticle> _particles = [];
  final List<TrailParticle> _trails = [];
  final List<CelebrationParticle> _celebrationParticles = [];

  // --- 6. Hints ---
  bool _showingHint = false;
  String _hintMessage = '';

  @override
  void initState() {
    super.initState();

    // Safety first
    _isLoading = true;
    
    // Initialize Controllers
    _winPulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _winPulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _winPulseController, curve: Curves.easeInOut));

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _particleController.addListener(_updateParticles);

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _pushController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pushAnimation = CurvedAnimation(parent: _pushController, curve: Curves.elasticOut)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pushController.reverse();
        }
      });

    // Start Logic
    _generateStarfield();
    _initGameFlow();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (widget.level == 1) {
        _showTutorialHint();
      }
    });
  }

  void _handleDiscard() {
    // 1. Rate as -1 (The "Discard" Signal)
    StarLoaderLevelManager().rateLevel(_currentLevelData.id, -1);
    
    // 2. Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Level Discarded (-1 rating)'),
        duration: Duration(milliseconds: 500),
        backgroundColor: Colors.red,
      ),
    );

    // 3. Load Next
    _loadLevel();
  }

  Future<void> _initGameFlow() async {
    // 1. Initialize the manager
    await StarLoaderLevelManager().initialize();
    
    // 2. Load the level
    await _loadLevel();

    // 3. UI stuff after loading is done
    if (mounted) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        if (widget.level == 1) _showTutorialHint();
      });
    }
  }

  void _generateStarfield() {
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(StarParticle(
        position: Offset(
          random.nextDouble() * 1000,
          random.nextDouble() * 1000,
        ),
        size: 1 + random.nextDouble() * 2,
        opacity: 0.3 + random.nextDouble() * 0.5,
      ));
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      _trails.removeWhere((p) => p.update());
      _celebrationParticles.removeWhere((p) => p.update());
    });
  }

  void _showTutorialHint() {
    setState(() {
      _showingHint = true;
      _hintMessage = S.of(context)!.starLoaderHint; // Name will be updated
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showingHint = false);
      }
    });
  }

  // --- FIX: Renamed to _resetCurrentLevel ---
  // This method resets the state using the cached _currentLevelData.
  void _resetCurrentLevel() {
    final levelData = _currentLevelData; // Use cached data

    setState(() {
      _grid = [];
      _boxPositions = [];
      _targetPositions = [];
      _moveHistory.clear();
      _moveCount = 0;
      _hasWon = false;
      _optimalMoves = levelData.optimalMoves;
      _trails.clear();
      _celebrationParticles.clear();
      _playerDirection = 2; // Default to facing down

      // Parse the level layout string
      for (int y = 0; y < levelData.layout.length; y++) {
        final rowStr = levelData.layout[y];
        final row = <CellType>[];
        for (int x = 0; x < rowStr.length; x++) {
          final char = rowStr[x];
          final pos = Offset(x.toDouble(), y.toDouble());

          switch (char) {
            case 'W':
              row.add(CellType.wall);
              break;
            case 'P':
              _playerPos = pos;
              row.add(CellType.floor);
              break;
            case 'B':
              _boxPositions.add(pos);
              row.add(CellType.floor);
              break;
            case 'T':
              _targetPositions.add(pos);
              row.add(CellType.target);
              break;
            case 'X': // Box on target
              _boxPositions.add(pos);
              _targetPositions.add(pos);
              row.add(CellType.target);
              break;
            case ' ':
            default:
              row.add(CellType.floor);
              break;
          }
        }
        _grid.add(row);
      }
    });

    _stopwatch.reset();
    _stopwatch.start();
    _focusNode.requestFocus();
  }

  Future<void> _loadLevel() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final levelData = await StarLoaderLevelManager().getLevelForGrade(widget.grade, widget.level);

    if (!mounted) return;
    
    if (kDebugMode) debugPrint('🚀 [Game] Loading Level ID: ${levelData.id} (Moves: ${levelData.optimalMoves})');

    _currentLevelData = levelData;
    _resetCurrentLevel(); 

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _winPulseController.dispose();
    _particleController.dispose();
    _celebrationController.dispose();
    _pushController.dispose();
    _focusNode.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _hasWon) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _movePlayer(-1, 0);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _movePlayer(1, 0);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _movePlayer(0, -1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _movePlayer(0, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.keyZ ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _undoMove();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _resetCurrentLevel(); // <-- FIX: Call reset, not new level
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (_hasWon) return;
    final velocity = details.velocity.pixelsPerSecond;

    if (velocity.dx.abs() > velocity.dy.abs()) {
        if (velocity.dx > 0) {
        _movePlayer(1, 0); // Right
        } else {
        _movePlayer(-1, 0); // Left
        }
    } else {
        if (velocity.dy > 0) {
        _movePlayer(0, 1); // Down
        } else {
        _movePlayer(0, -1); // Up
        }
    }
    }

  void _movePlayer(int dx, int dy) {
    if (_hasWon) return;

    final newPlayerPos = _playerPos.translate(dx.toDouble(), dy.toDouble());
    int newDirection = _playerDirection;
    if (dy == -1) newDirection = 0; // Up
    if (dx == 1) newDirection = 1; // Right
    if (dy == 1) newDirection = 2; // Down
    if (dx == -1) newDirection = 3; // Left

    if (_getCellTypeAt(newPlayerPos) == CellType.wall) {
      HapticFeedback.lightImpact();
      return;
    }

    final boxIndex = _getBoxIndexAt(newPlayerPos);
    if (boxIndex != -1) {
      final newBoxPos = newPlayerPos.translate(dx.toDouble(), dy.toDouble());

      if (_getCellTypeAt(newBoxPos) == CellType.wall ||
          _getBoxIndexAt(newBoxPos) != -1) {
        HapticFeedback.lightImpact();
        return;
      }

      final oldPlayerPos = _playerPos;
      final oldBoxPos = _boxPositions[boxIndex];
      _moveHistory
          .add(MoveHistory(playerPos: oldPlayerPos, pushedBoxOrigin: oldBoxPos));

      setState(() {
        _playerPos = newPlayerPos;
        _playerDirection = newDirection;
        _boxPositions[boxIndex] = newBoxPos;
        _moveCount++;
        _createTrailParticle(_playerPos);
      });

      _pushController.forward(from: 0.0);
      HapticFeedback.mediumImpact();
    } else {
      final oldPlayerPos = _playerPos;
      _moveHistory.add(MoveHistory(playerPos: oldPlayerPos));

      setState(() {
        _playerPos = newPlayerPos;
        _playerDirection = newDirection;
        _moveCount++;
        _createTrailParticle(_playerPos);
      });

      HapticFeedback.lightImpact();
    }

    _checkWinCondition();
  }

  void _createTrailParticle(Offset gridPos) {
    final random = math.Random();
    for (int i = 0; i < 3; i++) {
      _trails.add(TrailParticle(
        position: gridPos, // Store grid position
        velocity: Offset(
          (random.nextDouble() - 0.5) * 2, // Slower velocity in grid units
          (random.nextDouble() - 0.5) * 2,
        ),
        size: 2 + random.nextDouble() * 2,
        color: SpaceTheme.alienGreen,
      ));
    }
  }

  void _undoMove() {
    if (_moveHistory.isEmpty || _hasWon) return;

    final lastMove = _moveHistory.removeLast();

    setState(() {
      if (lastMove.pushedBoxOrigin != null) {
        final dx = _playerPos.dx - lastMove.playerPos.dx;
        final dy = _playerPos.dy - lastMove.playerPos.dy;
        final boxCurrentPos = lastMove.pushedBoxOrigin!.translate(dx, dy);
        final boxIndex = _getBoxIndexAt(boxCurrentPos);
        if (boxIndex != -1) {
          _boxPositions[boxIndex] = lastMove.pushedBoxOrigin!;
        }
      }
      _playerPos = lastMove.playerPos;
      _moveCount--;
    });

    HapticFeedback.selectionClick();
  }

  void _checkWinCondition() {
    if (_targetPositions.isEmpty) return;

    for (final target in _targetPositions) {
      if (_getBoxIndexAt(target) == -1) {
        return;
      }
    }

    _stopwatch.stop();
    setState(() => _hasWon = true);

    _celebrationController.forward(from: 0.0);
    _createCelebrationParticles();

    HapticFeedback.heavyImpact();
    _handleSuccess();
  }

  void _createCelebrationParticles() {
    final random = math.Random();
    for (int i = 0; i < 50; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 2 + random.nextDouble() * 5; // Speed in grid units/sec
      _celebrationParticles.add(CelebrationParticle(
        position: _playerPos, // Store grid position
        velocity: Offset.fromDirection(angle, speed),
        size: 3 + random.nextDouble() * 5,
        color: [SpaceTheme.alienGreen, SpaceTheme.starYellow, Colors.cyan]
            [random.nextInt(3)],
      ));
    }
  }

  // --- FIX: Add this method to handle quitting ---
  void _handleQuit() {
    // If they already won or didn't make a single move, don't record a failure.
    if (_hasWon || _moveCount == 0) return; 

    _stopwatch.stop();
    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'star_loader_game',
      difficulty: widget.level,
    ));
  }

  void _handleSuccess() {
    final s = S.of(context)!;
    final timeTaken = _stopwatch.elapsed.inSeconds;

    int baseScore = 200 * widget.grade;
    int timeBonus = math.max(0, 1000 - (timeTaken * 5));
    int moveBonus = math.max(0, 500 - (_moveCount * 2));

    // Efficiency bonus for near-optimal solutions
    final efficiency = _optimalMoves > 0
        ? (_optimalMoves / _moveCount * 100).round()
        : 100;
    int efficiencyBonus =
        efficiency >= 90 ? 500 : (efficiency >= 80 ? 300 : 0);

    int totalScore = baseScore + timeBonus + moveBonus + efficiencyBonus;

    // Use the correct framework method
    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'star_loader_game',
      difficulty: widget.level,
      score: totalScore,
    ));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _buildSuccessDialog(s, totalScore, timeTaken, efficiency),
    );
  }

  CellType _getCellTypeAt(Offset pos) {
    final x = pos.dx.toInt();
    final y = pos.dy.toInt();
    if (y < 0 || y >= _grid.length || x < 0 || x >= _grid[y].length) {
      return CellType.wall;
    }
    return _grid[y][x];
  }

  int _getBoxIndexAt(Offset pos) {
    return _boxPositions.indexWhere((boxPos) => boxPos == pos);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SpaceTheme.deepSpace,
        body: Center(
          child: CircularProgressIndicator(color: SpaceTheme.alienGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace, 
      body: SpaceBackground( 
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          autofocus: true,
          child: Stack(
            children: [
              // --- GAME AREA ---
              OrientationBuilder(
                builder: (context, orientation) {
                  if (orientation == Orientation.portrait) {
                    return _buildPortraitLayout(context, s);
                  } else {
                    return _buildLandscapeLayout(context, s);
                  }
                },
              ),

              // --- STATIC PARTICLES ---
              ..._particles.map((p) => p.build()),

              // --- UI AREA (ON TOP) ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: GameUI(
                    title: S.of(context)!.starLoaderTitle, // Will be updated
                    level: widget.level,
                    // --- FIX: Call _handleQuit on back ---
                    onBack: () { 
                      _handleQuit();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),

              // --- HINT OVERLAY ---
              if (_showingHint)
                Positioned(
                    top: 80,
                    left: 20,
                    right: 20,
                    child: _buildHintBanner(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.alienGreen.withValues(alpha: 0.9),
            SpaceTheme.alienGreen.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.starYellow, width: 2),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.alienGreen.withValues(alpha: 0.5),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: SpaceTheme.starYellow, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _hintMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, S s) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0).copyWith(top: 60), // Space for GameUI
        child: Column(
          children: [
            _buildGameStats(s),
            const SizedBox(height: 16),
            Expanded(
              child: _buildGameGrid(),
            ),
            const SizedBox(height: 16),
            _buildDirectionalPad(s), // NEW: Directional pad
            const SizedBox(height: 12),
            _buildControls(s),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, S s) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(top: 60), // Space for GameUI
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildGameGrid(),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: SingleChildScrollView( // NEW: Added scroll for better fit
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGameStats(s),
                    const SizedBox(height: 24),
                    _buildDirectionalPad(s), // NEW: Directional pad
                    const SizedBox(height: 24),
                    _buildControls(s),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStats(S s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.deepSpace.withValues(alpha: 0.9),
            SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.alienGreen.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.compare_arrows, '$_moveCount', s.moves),
          Container(width: 1, height: 30, color: Colors.white24),
          //_buildStatItem(Icons.flag, '$_optimalMoves', s.optimal),
          // Container(width: 1, height: 30, color: Colors.white24),
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              final time = _stopwatch.elapsed;
              final formattedTime =
                  '${time.inMinutes.toString().padLeft(2, '0')}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';
              return _buildStatItem(Icons.timer, formattedTime, s.time);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: SpaceTheme.alienGreen, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: SpaceTheme.starYellow,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildControls(S s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _moveHistory.isEmpty || _hasWon ? null : _undoMove,
              icon: const Icon(Icons.undo, size: 20),
              label: Text(s.undo),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpaceTheme.nebulaPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _hasWon ? null : _resetCurrentLevel,
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(s.reset),
              style: ElevatedButton.styleFrom(
                backgroundColor: SpaceTheme.rocketRed.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
            ),
          ],
        ),
        
        // --- DEV: DISCARD BUTTON ---
        if (ENABLE_LEVEL_RATING) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _handleDiscard,
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            label: const Text(
              "Verwerfe Level", 
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDirectionalPad(S s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.deepSpace.withValues(alpha: 0.8),
            SpaceTheme.nebulaPurple.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          _buildDirectionalButton(
            icon: Icons.arrow_upward,
            onPressed: () => _movePlayer(0, -1),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left button
              _buildDirectionalButton(
                icon: Icons.arrow_back,
                onPressed: () => _movePlayer(-1, 0),
              ),
              const SizedBox(width: 8),
              // Center spacer
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SpaceTheme.alienGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right button
              _buildDirectionalButton(
                icon: Icons.arrow_forward,
                onPressed: () => _movePlayer(1, 0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Down button
          _buildDirectionalButton(
            icon: Icons.arrow_downward,
            onPressed: () => _movePlayer(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionalButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _hasWon ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hasWon
                  ? [Colors.grey.shade700, Colors.grey.shade800]
                  : [
                      SpaceTheme.alienGreen.withValues(alpha: 0.6),
                      SpaceTheme.alienGreen.withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasWon
                  ? Colors.grey.shade600
                  : SpaceTheme.alienGreen,
              width: 2,
            ),
            boxShadow: _hasWon
                ? []
                : [
                    BoxShadow(
                      color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Icon(
            icon,
            color: _hasWon ? Colors.grey.shade500 : Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildGameGrid() {
    return Center(
      child: Semantics(
        label: 'Star loader puzzle grid',
        hint: 'Swipe in a direction to move the player',
        child: GestureDetector(
        onVerticalDragEnd: _handleSwipe,
        onHorizontalDragEnd: _handleSwipe,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_grid.isEmpty || _grid[0].isEmpty) return Container();

            final maxW = constraints.maxWidth / _grid[0].length;
            final maxH = constraints.maxHeight / _grid.length;
            final cellSize = math.min(maxW, maxH).floorToDouble();
            final gridWidth = cellSize * _grid[0].length;
            final gridHeight = cellSize * _grid.length;

            if (cellSize <= 0) return Container();

            return ExcludeSemantics(
              child: Container(
              width: gridWidth,
              height: gridHeight,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    SpaceTheme.deepSpace.withValues(alpha: 0.5),
                    SpaceTheme.deepSpace.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.alienGreen.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedBuilder(
                  // Repaint painter when push animation runs or particles update
                  animation: Listenable.merge([_pushAnimation, _particleController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: StarLoaderPainter(
                        grid: _grid,
                        playerPos: _playerPos,
                        playerDirection: _playerDirection,
                        boxPositions: _boxPositions,
                        targetPositions: _targetPositions,
                        trails: _trails, // Pass particles
                        celebrationParticles:
                            _celebrationParticles, // Pass particles
                        cellSize: cellSize,
                        winPulse: _hasWon ? _winPulseAnimation.value : 1.0,
                        pushAnimValue: _pushAnimation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildSuccessDialog(
      S s, int totalScore, int timeTaken, int efficiency) {
    
    // Reset rating state every time dialog opens
    _currentRating = 0;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SpaceTheme.deepSpace.withValues(alpha: 0.95),
                  SpaceTheme.nebulaPurple.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- 1. Success Icon ---
                  ScaleTransition(
                    scale: _winPulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SpaceTheme.alienGreen,
                            SpaceTheme.alienGreen.withValues(alpha: 0.5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SpaceTheme.alienGreen.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- 2. Title & Desc ---
                  Text(
                    s.starLoaderWinTitle,
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.starLoaderWinDesc(totalScore, _moveCount, timeTaken),
                    style: SpaceTheme.bodyStyle.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  
                  // --- 3. Rating System (Conditional) ---
                  if (ENABLE_LEVEL_RATING) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "RATE THIS LEVEL (DEV ONLY)", 
                            style: TextStyle(
                              color: SpaceTheme.starYellow, 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            )
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    _currentRating = index + 1;
                                  });
                                  HapticFeedback.selectionClick();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Icon(
                                    index < _currentRating ? Icons.star : Icons.star_border,
                                    color: SpaceTheme.starYellow,
                                    size: 36,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // --- 4. Stats Box ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildScoreRow(
                            s.efficiency,
                            '$efficiency',
                            efficiency >= 90
                                ? SpaceTheme.alienGreen
                                : SpaceTheme.starYellow),
                        const SizedBox(height: 8),
                        _buildScoreRow(s.movesVsOptimal, '$_moveCount / $_optimalMoves',
                            Colors.white70),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- 5. Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // SAVE RATING
                            if (ENABLE_LEVEL_RATING && _currentRating > 0) {
                              StarLoaderLevelManager().rateLevel(
                                _currentLevelData.id, 
                                _currentRating
                              );
                            }
                            
                            Navigator.of(context).pop();
                            _loadLevel(); // Load next
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(s.nextLevel, textAlign: TextAlign.center),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SpaceTheme.alienGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // SAVE RATING
                            if (ENABLE_LEVEL_RATING && _currentRating > 0) {
                              StarLoaderLevelManager().rateLevel(
                                _currentLevelData.id, 
                                _currentRating
                              );
                            }
                            
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.home),
                          label: Text(s.toTheBridge, textAlign: TextAlign.center),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SpaceTheme.nebulaPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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

  Widget _buildScoreRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(
          value,
          style:
              TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- Particle Classes ---
// (No build() method, they are just data containers now)

class StarParticle {
  final Offset position;
  final double size;
  final double opacity;

  StarParticle({
    required this.position,
    required this.size,
    required this.opacity,
  });

  Widget build() {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class TrailParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double life;

  TrailParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.life = 1.0,
  });

  bool update() {
    // Update position based on grid units
    position = position + velocity * 0.016;
    velocity = velocity * 0.95; // Dampen velocity
    life -= 0.03; // Fade faster
    return life <= 0;
  }
}

class CelebrationParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double life;

  CelebrationParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.life = 1.0,
  });

  bool update() {
    position = position + velocity * 0.016;
    velocity = velocity * 0.98; // Slower dampening
    life -= 0.016;
    return life <= 0;
  }
}

// --- Custom Painter ---

class StarLoaderPainter extends CustomPainter {
  final List<List<CellType>> grid;
  final Offset playerPos;
  final int playerDirection;
  final List<Offset> boxPositions;
  final List<Offset> targetPositions;
  final List<TrailParticle> trails;
  final List<CelebrationParticle> celebrationParticles;
  final double cellSize;
  final double winPulse;
  final double pushAnimValue;

  final Paint _floorPaint = Paint()..color = Colors.transparent;
  
  // --- FIX: Updated Wall Paint ---
  final Paint _wallPaint = Paint(); // Shader will be set in paint()

  final Paint _targetPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _targetFillPaint = Paint()
    ..color = SpaceTheme.alienGreen.withValues(alpha: 0.2);
  final Paint _boxPaint = Paint(); // Will use gradient
  final Paint _boxShadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final Paint _playerPaint = Paint(); // Will use gradient
  final Paint _playerWindowPaint = Paint(); // Will use gradient
  final Paint _trailPaint = Paint()..style = PaintingStyle.fill;
  final Paint _celebrationPaint = Paint()..style = PaintingStyle.fill;

  StarLoaderPainter({
    required this.grid,
    required this.playerPos,
    required this.playerDirection,
    required this.boxPositions,
    required this.targetPositions,
    required this.trails,
    required this.celebrationParticles,
    required this.cellSize,
    required this.winPulse,
    required this.pushAnimValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cellSize <= 0) return;

    final double padding = cellSize * 0.1;
    final double innerSize = cellSize - (padding * 2);

    // 1. Draw grid cells
    for (int y = 0; y < grid.length; y++) {
      for (int x = 0; x < grid[y].length; x++) {
        final rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        final cell = grid[y][x];

        switch (cell) {
          case CellType.floor:
            canvas.drawRect(rect, _floorPaint);
            break;

          // --- FIX: Updated Wall Painting ---
          case CellType.wall:
            final wallRect = rect.deflate(padding / 3);
            
            _wallPaint.shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5A3A7B), // Darker, uniform purple
                Color(0xFF381B42), // Even darker
              ],
            ).createShader(wallRect);

            canvas.drawRRect( 
                RRect.fromRectAndRadius(wallRect, Radius.circular(cellSize * 0.1)),
                _wallPaint
            );
            break;
          // --- END FIX ---

          case CellType.target:
            canvas.drawRect(rect, _floorPaint); // Transparent floor
            
            final targetPulse = (winPulse - 0.8) * 2.5; // Remap 0.8-1.2 to 0-1.0
            final glowColor = SpaceTheme.alienGreen.withValues(alpha: 0.5 + targetPulse * 0.5);
            
            // Draw outer glow
            _targetPaint
              ..color = glowColor
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, (10 * targetPulse) + 5);
            
            // Draw inner fill
            _targetFillPaint.color = SpaceTheme.alienGreen.withValues(alpha: 0.1 + targetPulse * 0.2);

            canvas.drawCircle(rect.center, innerSize / 2, _targetFillPaint);
            canvas.drawCircle(rect.center, innerSize / 2, _targetPaint);
            break;
        }
      }
    }

    // 2. Draw trail particles
    for (final p in trails) {
      final center = p.position * cellSize + Offset(cellSize / 2, cellSize / 2);
      _trailPaint.color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0));
      canvas.drawCircle(center, p.size * (p.life + 0.5), _trailPaint);
    }

    // 3. Draw boxes
    final double boxSquash = 1.0 + (pushAnimValue * 0.3);
    final double boxStretch = 1.0 - (pushAnimValue * 0.3);

    for (final pos in boxPositions) {
      Rect rect = Rect.fromLTWH(
        pos.dx * cellSize + padding,
        pos.dy * cellSize + padding,
        innerSize,
        innerSize,
      );

      final bool isPushedBox = (playerPos.dx.round() == pos.dx.round() ||
              playerPos.dy.round() == pos.dy.round()) &&
          (playerPos - pos).distance.abs() < 1.1 &&
          pushAnimValue > 0.0;

      if (isPushedBox) {
        if (playerDirection == 1 || playerDirection == 3) { // Horizontal push
          rect = Rect.fromCenter(center: rect.center, width: innerSize * boxSquash, height: innerSize * boxStretch);
        } else { // Vertical push
          rect = Rect.fromCenter(center: rect.center, width: innerSize * boxStretch, height: innerSize * boxSquash);
        }
      }

      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.1));
      
      canvas.drawRRect(rrect.shift(const Offset(2, 2)), _boxShadowPaint);

      final bool onTarget = targetPositions.contains(pos);
      final color = onTarget ? SpaceTheme.alienGreen : SpaceTheme.planetOrange;

      _boxPaint.shader = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 1.0,
        colors: [Color.lerp(color, Colors.white, 0.4)!, color],
      ).createShader(rect);

      canvas.drawRRect(rrect, _boxPaint);
    }

    // 4. Draw player (as a rocket)
    final double playerSquash = 1.0 - (pushAnimValue * 0.3);
    final double playerStretch = 1.0 + (pushAnimValue * 0.3);

    Rect playerRect = Rect.fromLTWH(
      playerPos.dx * cellSize + padding,
      playerPos.dy * cellSize + padding,
      innerSize,
      innerSize,
    );
    
    if (playerDirection == 1 || playerDirection == 3) { // Horizontal move
      playerRect = Rect.fromCenter(center: playerRect.center, width: innerSize * playerStretch, height: innerSize * playerSquash);
    } else { // Vertical move
      playerRect = Rect.fromCenter(center: playerRect.center, width: innerSize * playerSquash, height: innerSize * playerStretch);
    }

    final path = Path();
    path.moveTo(playerRect.center.dx, playerRect.top);
    path.lineTo(playerRect.right, playerRect.bottom);
    path.lineTo(playerRect.left, playerRect.bottom);
    path.close();

    canvas.save();
    canvas.translate(
        playerPos.dx * cellSize + cellSize / 2,
        playerPos.dy * cellSize + cellSize / 2
    );
    canvas.rotate(playerDirection * math.pi / 2);
    canvas.translate(
        -(playerPos.dx * cellSize + cellSize / 2),
        -(playerPos.dy * cellSize + cellSize / 2)
    );

    _playerPaint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE57373), Color(0xFFD32F2F), Color(0xFFB71C1C)],
    ).createShader(playerRect);

    final windowRect = Rect.fromCircle(
      center: playerRect.center.translate(0, innerSize * 0.15),
      radius: innerSize * 0.15 * playerSquash
    );

    _playerWindowPaint.shader = RadialGradient(
      colors: [Colors.white, Colors.cyan.shade200, Colors.cyan.shade600],
    ).createShader(windowRect);

    canvas.drawPath(path, _playerPaint);
    canvas.drawCircle(
      windowRect.center,
      windowRect.width / 2,
      _playerWindowPaint,
    );

    canvas.restore();
    
    // 5. Draw celebration particles
    for (final p in celebrationParticles) {
      final center = p.position * cellSize + Offset(cellSize / 2, cellSize / 2);
      _celebrationPaint.color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0));
      canvas.drawCircle(center, p.size * (p.life + 0.5), _celebrationPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StarLoaderPainter oldDelegate) {
    return oldDelegate.playerPos != playerPos ||
        oldDelegate.playerDirection != playerDirection ||
        !listEquals(oldDelegate.boxPositions, boxPositions) ||
        oldDelegate.winPulse != winPulse ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.pushAnimValue != pushAnimValue ||
        oldDelegate.trails.length != trails.length ||
        oldDelegate.celebrationParticles.length != celebrationParticles.length;
  }

  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
