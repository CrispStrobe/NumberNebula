// lib/features/games/screens/game_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/services/debug_provider.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';

import 'magic_triangles_game.dart';
import 'asteroid_math_game.dart';
import 'puzzle_math_game.dart';
import 'hyperdrive_gates_game.dart';
import 'path_finder_game.dart';
import 'planet_hopping_game.dart';
import 'number_walls_game.dart';
import 'codebreaker_game.dart';
import 'perspective_puzzle_game.dart';
import 'blocks_counter_game.dart';
import 'signal_triangulation_game.dart';
import 'cryptex_lock_breaker_game.dart';
import 'arithmancer_duel_game.dart';
import 'arithmatic_square_game.dart';
import 'arithmancer_crosswords_game.dart';
import 'kenken_game.dart';
import 'asteroid_field_navigator_game.dart';
import 'cargo_bay_arranger_game.dart';
import 'quantum_molecule_builder_game.dart';
import 'space_station_gridlock_game.dart';
import 'star_loader_game.dart';
import 'robot_path_game.dart';

import '../widgets/debug_panel.dart';
import '../../settings/screens/settings_screen.dart';
import '../../achievements/screens/achievements_screen.dart';
import '../../../shared/widgets/purchase_dialog.dart';
import '../../../shared/widgets/parental_gate.dart';
import '../../../shared/widgets/imprint_dialog.dart';

class GameMenuScreen extends StatefulWidget {
  const GameMenuScreen({super.key});

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _floatController;
  late List<Animation<Offset>> _cardAnimations;
  late Animation<double> _floatAnimation;

  // for new games, we must manually update game count
  static const int _gameCount = 22;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _floatController =
        AnimationController(duration: const Duration(seconds: 3), vsync: this)
          ..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0)
        .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _cardAnimations = List.generate(_gameCount, (index) {
      return Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          (0.5 + (index * 0.1)).clamp(0.0, 1.0),
          curve: Curves.elasticOut,
        ),
      ));
    });
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _showDebugPanel() {
    showDialog(
      context: context,
      builder: (context) => DebugPanel(),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _navigateToAchievements() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
  }

  void _navigateToGame(Widget gameScreen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => gameScreen));
  }

  void _showPurchaseFlow(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ParentalGateDialog(
        onSuccess: () {
          Navigator.of(context).pop(); // Close the gate dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const PurchaseDialog(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child:
                      isLandscape ? _buildLandscapeGrid() : _buildPortraitGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final debugProvider = context.watch<DebugProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2235), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.of(context)!.gameMenu, style: SpaceTheme.headlineStyle.copyWith(fontSize: 32)),
                Consumer<GameProvider>(
                  builder: (context, gameProvider, child) {
                    return Text(
                      '${S.of(context)!.gradeN(gameProvider.grade)} • ${S.of(context)!.level} ${gameProvider.level}',
                      style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 16),
                    );
                  },
                ),
              ],
            ),
          ),
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: SpaceTheme.starYellow, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      gameProvider.score.toString(),
                      style: SpaceTheme.titleStyle.copyWith(color: SpaceTheme.starYellow, fontSize: 18),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _navigateToAchievements,
                icon: const Icon(Icons.emoji_events),
                color: SpaceTheme.starYellow,
                tooltip: S.of(context)!.achievements,
                style: IconButton.styleFrom(backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8)),
              ),
              const SizedBox(width: 4),
              // --- IMPRINT BUTTON ADDED ---
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ImprintDialog(),
                  );
                },
                icon: const Icon(Icons.gavel), // Legal / Gavel icon
                color: SpaceTheme.moonSilver,
                tooltip: S.of(context)!.imprint,
                style: IconButton.styleFrom(backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8)),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _navigateToSettings,
                icon: const Icon(Icons.settings),
                color: SpaceTheme.moonSilver,
                tooltip: S.of(context)!.settings,
                style: IconButton.styleFrom(backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8)),
              ),
              if (debugProvider.isDebugMenuEnabled) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _showDebugPanel,
                  icon: const Icon(Icons.bug_report),
                  color: debugProvider.isPaidUnlockedForced
                      ? SpaceTheme.alienGreen
                      : SpaceTheme.moonSilver,
                  tooltip: S.of(context)!.debugPanelTitle,
                  style: IconButton.styleFrom(backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Adjust for more games
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.1),
      itemCount: _gameCount,
      itemBuilder: (context, index) => _buildGameCard(index),
    );
  }

  Widget _buildPortraitGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.85),
      itemCount: _gameCount,
      itemBuilder: (context, index) => _buildGameCard(index),
    );
  }

  Widget _buildGameCard(int index) {
    final gameProvider = context.read<GameProvider>();
    final debugProvider = context.read<DebugProvider>();
    final s = S.of(context)!;

    final games = [
        GameInfo(
            title: s.magicTriangles,
            description: s.magicTrianglesDesc,
            icon: Icons.change_history,
            gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.cosmicPink]),
            onTap: () => _navigateToGame(MagicTrianglesGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.bubbleMath,
            description: s.bubbleMathDesc,
            icon: Icons.bubble_chart,
            gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.starYellow]),
            onTap: () => _navigateToGame(AsteroidMathGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.puzzleMath,
            description: s.puzzleMathDesc,
            icon: Icons.extension,
            gradient: const LinearGradient(colors: [SpaceTheme.planetOrange, SpaceTheme.rocketRed]),
            onTap: () => _navigateToGame(PuzzleMathGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.hyperdriveGates,
            description: s.hyperdriveGatesDesc,
            icon: Icons.rocket_launch,
            gradient: const LinearGradient(colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)]),
            onTap: () => _navigateToGame(HyperdriveGatesGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.pathFinderTitle,
            description: s.pathFinderDesc,
            icon: Icons.map,
            gradient: const LinearGradient(colors: [Colors.teal, Colors.cyan]),
            onTap: () => _navigateToGame(PathFinderGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.planetHopping,
            description: s.planetHoppingDesc,
            icon: Icons.public,
            gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
            onTap: () => _navigateToGame(PlanetHoppingGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.numberWalls,
            description: s.numberWallsDesc,
            icon: Icons.view_module,
            gradient: const LinearGradient(colors: [Color(0xFFf97794), Color(0xFF623aa2)]),
            onTap: () => _navigateToGame(NumberWallsGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.codebreaker,
            description: s.codebreakerDesc,
            icon: Icons.vpn_key,
            gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
            onTap: () => _navigateToGame(CodebreakerGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.perspectivePuzzleGameTitle, // Use the correct string
            description: s.perspectivePuzzleInstructions,
            icon: Icons.grid_view_sharp,
            gradient: const LinearGradient(colors: [Color(0xFFf5af19), Color(0xFFf12711)]),
            onTap: () => _navigateToGame(PerspectivePuzzleGame(grade: gameProvider.grade, level: gameProvider.level))), // Use PerspectivePuzzleGame

        GameInfo(
            title: s.blockCounterGameTitle,
            description: s.blockCounterInstructions,
            icon: Icons.view_in_ar,
            gradient: const LinearGradient(colors: [Color(0xFF00F260), Color(0xFF0575E6)]),
            onTap: () => _navigateToGame(BlockCounterGame(grade: gameProvider.grade, level: gameProvider.level))),
        GameInfo(
            title: s.signalTriangulationGameTitle,
            description: s.signalTriangulationInstructions,
            icon: Icons.track_changes,
            gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
            onTap: () => _navigateToGame(SignalTriangulationGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
          title: s.cryptexLockBreakerGameTitle,
          description: s.cryptexLockBreakerInstructions,
          icon: Icons.dialpad, // 🔐 Looks like a combination lock
          gradient: const LinearGradient(colors: [Color(0xFFED213A), Color(0xFF93291E)]), // Intense red "danger" gradient
          onTap: () => _navigateToGame(CryptexLockBreakerGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.arithmancerGameTitle,
            description: s.arithmancerGameInstructions,
            icon: Icons.auto_awesome, // ✨ "Mancer" implies magic
            gradient: const LinearGradient(colors: [Color(0xFFcc2b5e), Color(0xFF753a88)]), // Mystical purple/pink gradient
            onTap: () => _navigateToGame(ArithmancerDuelGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.arithmeticSquare,
            description: s.arithmeticSquareInstructions,
            icon: Icons.grid_on, // 🔢 Perfect for a grid-based puzzle
            gradient: const LinearGradient(colors: [Color(0xFFa8e063), Color(0xFF56ab2f)]), // Fresh green gradient
            onTap: () => _navigateToGame(ArithmeticSquareGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.arithmancerCrosswords,
            description: s.arithmancerCrosswordsInstructions,
            icon: Icons.border_all, //  crossword-like grid
            gradient: const LinearGradient(colors: [Color(0xFFff8008), Color(0xFFffc837)]), // Warm sunrise orange gradient
            onTap: () => _navigateToGame(ArithmancerCrosswordsGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.kenken,
            description: s.kenkenInstructions, 
            icon: Icons.dashboard_customize, // Represents the "cages" in KenKen
            gradient: const LinearGradient(colors: [Color(0xFF00d2ff), Color(0xFF3a7bd5)]), // Cool blue ocean gradient
            onTap: () => _navigateToGame(KenkenGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.asteroidFieldTitle,
            description: s.asteroidFieldInstructions,
            icon: Icons.grid_4x4, // Minesweeper grid icon
            gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]), // Dark space gradient
            onTap: () => _navigateToGame(AsteroidFieldNavigatorGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.cargoBayTitle,
            description: s.cargoBayInstructions,
            icon: Icons.view_module, // Tetris blocks
            gradient: const LinearGradient(colors: [Color(0xFF7F00FF), Color(0xFFE100FF)]), // Purple gradient
            onTap: () => _navigateToGame(CargoBayArrangerGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.moleculeBuilderTitle,
            description: s.moleculeBuilderInstructions,
            icon: Icons.science, // Atom/molecule icon
            gradient: const LinearGradient(colors: [Color(0xFF02AAB0), Color(0xFF00CDAC)]), // Cyan/teal science gradient
            onTap: () => _navigateToGame(QuantumMoleculeBuilderGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.spaceGridlockTitle,
            description: s.spaceGridlockInstructions,
            icon: Icons.view_module, // Atom/molecule icon
            gradient: const LinearGradient(colors: [Color(0xFF02AAB0), Color(0xFF00CDAC)]), // Cyan/teal science gradient
            onTap: () => _navigateToGame(SpaceStationGridlockGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.starLoaderGameTitle, // NOTE: Add this to your S.of(context) strings
            description: s.starLoaderGameDesc, // NOTE: Add this to your S.of(context) strings
            icon: Icons.move_down, // Icon for Sokoban
            gradient: const LinearGradient(colors: [Color(0xFFf9a825), Color(0xFFc66900)]), // Brown/yellow
            onTap: () => _navigateToGame(StarLoaderGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
        GameInfo(
            title: s.robotPathTitle, // NOTE: Add this to your S.of(context) strings
            description: s.robotPathDesc, // NOTE: Add this to your S.of(context) strings
            icon: Icons.smart_toy_outlined, // Icon for robot
            gradient: const LinearGradient(colors: [Color(0xFF00bcd4), Color(0xFF00838f)]), // Cyan
            onTap: () => _navigateToGame(RobotPathGame(grade: gameProvider.grade, level: gameProvider.level)),
        ),
    ];

    if (index >= games.length) return const SizedBox.shrink(); // Safety check

    final game = games[index];
    final bool isPremiumContent = index > 1; // First 2 games are free
    final bool isUnlocked = gameProvider.isFullVersionUnlocked || debugProvider.isPaidUnlockedForced;
    final bool isLocked = isPremiumContent && !isUnlocked;

    if (index >= _cardAnimations.length) return const SizedBox.shrink();

    return SlideTransition(
      position: _cardAnimations[index],
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value * (index % 3 + 1) * 0.3),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GameCard(
                  game: game,
                  onTap: isLocked ? () => _showPurchaseFlow(context) : game.onTap,
                ),
                if (isLocked)
                  Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(25)),
                  ),
                if (isLocked)
                  Icon(Icons.lock, color: SpaceTheme.starYellow, size: 50, shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 10)]),
              ],
            ),
          );
        },
      ),
    );
  }
}

// GameInfo and GameCard classes remain the same... (Code omitted for brevity)
class GameInfo {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  GameInfo({required this.title, required this.description, required this.icon, required this.gradient, required this.onTap});
}

class GameCard extends StatefulWidget {
  final GameInfo game;
  final VoidCallback onTap;
  const GameCard({super.key, required this.game, required this.onTap});

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.game.gradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    BoxShadow(color: widget.game.gradient.colors.first.withOpacity(_glowAnimation.value), blurRadius: 25, spreadRadius: 2),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(widget.game.icon, size: 24, color: Colors.white),
                      ),
                      Text(widget.game.title, style: SpaceTheme.headlineStyle.copyWith(fontSize: 15), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(widget.game.description, style: SpaceTheme.bodyStyle.copyWith(fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(S.of(context)!.launch, style: SpaceTheme.buttonStyle.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}