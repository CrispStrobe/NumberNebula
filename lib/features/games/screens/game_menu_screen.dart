// lib/features/games/screens/game_menu_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/debug_provider.dart';
import '../../../core/services/sri_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import 'karteikasten_screen.dart';

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
import 'solarpanel_game.dart';
import 'grid_filler_game.dart';
import 'star_chart_scan_game.dart';
import 'comm_relay_game.dart';
import 'hull_plating_game.dart';
import 'vault_cracker_game.dart';
import 'crew_manifest_game.dart';
import 'alien_tribunal_game.dart';
import 'gravity_well_game.dart';
import 'sector_painter_game.dart';
import 'warp_fold_game.dart';
import 'cube_scanner_game.dart';
import 'circuit_repair_game.dart';
import 'dark_matter_grid_game.dart';
import 'ion_chain_game.dart';
import 'launch_sequence_game.dart';
import 'star_forge_game.dart';
import 'nebula_matrix_game.dart';
import 'orbital_towers_game.dart';
import 'hive_station_game.dart';
import 'relic_assembly_game.dart';
import 'xenobiology_lab_game.dart';
import 'galactic_market_game.dart';
import 'asteroid_duel_game.dart';
import 'chrono_repair_game.dart';
import 'void_crossing_game.dart';

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

// Helper class to store game data *before* creating the final GameInfo widget
class _GameInfoData {
  final String gameKey;
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final Widget Function(int grade, int level) gameBuilder;

  _GameInfoData({
    required this.gameKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.gameBuilder,
  });
}

class _GameMenuScreenState extends State<GameMenuScreen> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _floatController;
  late List<Animation<Offset>> _cardAnimations;
  late Animation<double> _floatAnimation;

  // This list now holds the raw data, including game keys and widget builders
  late final List<_GameInfoData> _gamesData;
  bool _isGamesDataInitialized = false;

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
    // _cardAnimations created in didChangeDependencies after _gamesData is built
    _cardAnimations = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isGamesDataInitialized) {
      _gamesData = _getGamesList(context);
      _isGamesDataInitialized = true;

      // Derive card animations from actual game count — no manual constant needed
      _cardAnimations = List.generate(_gamesData.length, (index) {
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
  }

  @override
  void dispose() {
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }
  
  // This builds the list of game data, including the all-important gameKey
  List<_GameInfoData> _getGamesList(BuildContext context) {
    final s = S.of(context)!;
    // These keys MUST match the keys used in game_provider.dart and gameSkillMap
    return [
      _GameInfoData(
        gameKey: 'magic_triangles',
        title: s.magicTrianglesGameTitle,
        description: s.magicTrianglesDesc,
        icon: Icons.change_history,
        gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.cosmicPink]),
        gameBuilder: (grade, level) => MagicTrianglesGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'asteroid_math', // Game is titled "Asteroid Field Hunter"
        title: s.asteroidMathHunter,
        description: s.asteroidMathHunterDesc,
        icon: Icons.bubble_chart,
        gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.starYellow]),
        gameBuilder: (grade, level) => AsteroidMathGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'puzzle_math',
        title: s.puzzleMath,
        description: s.puzzleMathDesc,
        icon: Icons.extension,
        gradient: const LinearGradient(colors: [SpaceTheme.planetOrange, SpaceTheme.rocketRed]),
        gameBuilder: (grade, level) => PuzzleMathGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'hyperdrive_gates',
        title: s.hyperdriveGates,
        description: s.hyperdriveGatesDesc,
        icon: Icons.rocket_launch,
        gradient: const LinearGradient(colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)]),
        gameBuilder: (grade, level) => HyperdriveGatesGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'pathfinder',
        title: s.pathFinderTitle,
        description: s.pathFinderDesc,
        icon: Icons.map,
        gradient: const LinearGradient(colors: [Colors.teal, Colors.cyan]),
        gameBuilder: (grade, level) => PathFinderGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'planet_hopping',
        title: s.planetHoppingTitle,
        description: s.planetHoppingDesc,
        icon: Icons.public,
        gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
        gameBuilder: (grade, level) => PlanetHoppingGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'number_walls',
        title: s.numberWallsGameTitle,
        description: s.numberWallsDesc,
        icon: Icons.view_module,
        gradient: const LinearGradient(colors: [Color(0xFFf97794), Color(0xFF623aa2)]),
        gameBuilder: (grade, level) => NumberWallsGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'codebreaker',
        title: s.codebreaker,
        description: s.codebreakerDesc,
        icon: Icons.vpn_key,
        gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
        gameBuilder: (grade, level) => CodebreakerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'perspective_puzzle',
        title: s.perspectivePuzzleGameTitle,
        description: s.perspectivePuzzleInstructions,
        icon: Icons.grid_view_sharp,
        gradient: const LinearGradient(colors: [Color(0xFFf5af19), Color(0xFFf12711)]),
        gameBuilder: (grade, level) => PerspectivePuzzleGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'block_counter',
        title: s.blockCounterGameTitle,
        description: s.blockCounterInstructions,
        icon: Icons.view_in_ar,
        gradient: const LinearGradient(colors: [Color(0xFF00F260), Color(0xFF0575E6)]),
        gameBuilder: (grade, level) => BlockCounterGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'signal_triangulation',
        title: s.signalTriangulationGameTitle,
        description: s.signalTriangulationInstructions,
        icon: Icons.track_changes,
        gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
        gameBuilder: (grade, level) => SignalTriangulationGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'cryptex_lock_breaker',
        title: s.cryptexLockBreakerGameTitle,
        description: s.cryptexLockBreakerInstructions,
        icon: Icons.dialpad,
        gradient: const LinearGradient(colors: [Color(0xFFED213A), Color(0xFF93291E)]),
        gameBuilder: (grade, level) => CryptexLockBreakerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'arithmancer_duel',
        title: s.arithmancerGameTitle,
        description: s.arithmancerGameInstructions,
        icon: Icons.auto_awesome,
        gradient: const LinearGradient(colors: [Color(0xFFcc2b5e), Color(0xFF753a88)]),
        gameBuilder: (grade, level) => ArithmancerDuelGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'arithmatic_square',
        title: s.arithmeticSquare,
        description: s.arithmeticSquareInstructions,
        icon: Icons.grid_on,
        gradient: const LinearGradient(colors: [Color(0xFFa8e063), Color(0xFF56ab2f)]),
        gameBuilder: (grade, level) => ArithmeticSquareGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'arithmancer_crosswords',
        title: s.arithmancerCrosswords,
        description: s.arithmancerCrosswordsInstructions,
        icon: Icons.border_all,
        gradient: const LinearGradient(colors: [Color(0xFFff8008), Color(0xFFffc837)]),
        gameBuilder: (grade, level) => ArithmancerCrosswordsGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'kenken',
        title: s.kenken,
        description: s.kenkenInstructions,
        icon: Icons.dashboard_customize,
        gradient: const LinearGradient(colors: [Color(0xFF00d2ff), Color(0xFF3a7bd5)]),
        gameBuilder: (grade, level) => KenkenGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'asteroid_field_navigator',
        title: s.asteroidFieldTitle,
        description: s.asteroidFieldInstructions,
        icon: Icons.grid_4x4,
        gradient: const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]),
        gameBuilder: (grade, level) => AsteroidFieldNavigatorGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'cargo_bay_arranger',
        title: s.cargoBayTitle,
        description: s.cargoBayInstructions,
        icon: Icons.view_module,
        gradient: const LinearGradient(colors: [Color(0xFF7F00FF), Color(0xFFE100FF)]),
        gameBuilder: (grade, level) => CargoBayArrangerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'quantum_molecule_builder',
        title: s.moleculeBuilderTitle,
        description: s.moleculeBuilderInstructions,
        icon: Icons.science,
        gradient: const LinearGradient(colors: [Color(0xFF02AAB0), Color(0xFF00CDAC)]),
        gameBuilder: (grade, level) => QuantumMoleculeBuilderGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'space_station_gridlock',
        title: s.spaceGridlockTitle,
        description: s.spaceGridlockInstructions,
        icon: Icons.view_module,
        gradient: const LinearGradient(colors: [Color(0xFF02AAB0), Color(0xFF00CDAC)]),
        gameBuilder: (grade, level) => SpaceStationGridlockGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'star_loader_game',
        title: s.starLoaderGameTitle,
        description: s.starLoaderGameDesc,
        icon: Icons.move_down,
        gradient: const LinearGradient(colors: [Color(0xFFf9a825), Color(0xFFc66900)]),
        gameBuilder: (grade, level) => StarLoaderGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'robot_path_game',
        title: s.robotPathTitle,
        description: s.robotPathDesc,
        icon: Icons.smart_toy_outlined,
        gradient: const LinearGradient(colors: [Color(0xFF00bcd4), Color(0xFF00838f)]),
        gameBuilder: (grade, level) => RobotPathGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'solarpanel_game',
        title: s.solarPanelGameTitle,
        description: s.solarPanelTitle,
        icon: Icons.smart_toy_outlined,
        gradient: const LinearGradient(colors: [Color(0xFF44bcd4), Color(0xFF44838f)]),
        gameBuilder: (grade, level) => SolarPanelGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'grid_filler_game',
        title: s.gridFillerTitle,
        description: s.gridFillerDesc,
        icon: Icons.smart_toy_outlined,
        gradient: const LinearGradient(colors: [Color(0xFF44bcd4), Color(0xFF44838f)]),
        gameBuilder: (grade, level) => GridFillerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'star_chart_scan',
        title: s.starChartScanTitle,
        description: s.starChartScanDesc,
        icon: Icons.travel_explore,
        gradient: const LinearGradient(colors: [Color(0xFF00C9DB), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => StarChartScanGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'comm_relay',
        title: s.commRelayTitle,
        description: s.commRelayDesc,
        icon: Icons.satellite_alt,
        gradient: const LinearGradient(colors: [Color(0xFF00C9DB), Color(0xFF6B48FF)]),
        gameBuilder: (grade, level) => CommRelayGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'hull_plating',
        title: s.hullPlatingTitle,
        description: s.hullPlatingDesc,
        icon: Icons.view_compact,
        gradient: const LinearGradient(colors: [Color(0xFF8B8B8B), Color(0xFF00C9DB)]),
        gameBuilder: (grade, level) => HullPlatingGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'vault_cracker',
        title: s.vaultCrackerTitle,
        description: s.vaultCrackerDesc,
        icon: Icons.lock_open,
        gradient: const LinearGradient(colors: [Color(0xFF6B48FF), Color(0xFFE63946)]),
        gameBuilder: (grade, level) => VaultCrackerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'crew_manifest',
        title: s.crewManifestTitle,
        description: s.crewManifestDesc,
        icon: Icons.assignment_ind,
        gradient: const LinearGradient(colors: [Color(0xFF00C9DB), Color(0xFF06FFA5)]),
        gameBuilder: (grade, level) => CrewManifestGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'alien_tribunal',
        title: s.alienTribunalTitle,
        description: s.alienTribunalDesc,
        icon: Icons.gavel,
        gradient: const LinearGradient(colors: [Color(0xFF6B48FF), Color(0xFFE63946)]),
        gameBuilder: (grade, level) => AlienTribunalGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'gravity_well',
        title: s.gravityWellTitle,
        description: s.gravityWellDesc,
        icon: Icons.balance,
        gradient: const LinearGradient(colors: [Color(0xFF06FFA5), Color(0xFF00C9DB)]),
        gameBuilder: (grade, level) => GravityWellGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'sector_painter',
        title: s.sectorPainterTitle,
        description: s.sectorPainterDesc,
        icon: Icons.palette,
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => SectorPainterGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'warp_fold',
        title: s.warpFoldTitle,
        description: s.warpFoldDesc,
        icon: Icons.content_cut,
        gradient: const LinearGradient(colors: [Color(0xFFFF69B4), Color(0xFF6B48FF)]),
        gameBuilder: (grade, level) => WarpFoldGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'cube_scanner',
        title: s.cubeScannerTitle,
        description: s.cubeScannerDesc,
        icon: Icons.view_in_ar_outlined,
        gradient: const LinearGradient(colors: [Color(0xFF6B48FF), Color(0xFFFF69B4)]),
        gameBuilder: (grade, level) => CubeScannerGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'circuit_repair',
        title: s.circuitRepairTitle,
        description: s.circuitRepairDesc,
        icon: Icons.electrical_services,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFE63946)]),
        gameBuilder: (grade, level) => CircuitRepairGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'dark_matter_grid',
        title: s.darkMatterGridTitle,
        description: s.darkMatterGridDesc,
        icon: Icons.grid_view,
        gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF6B48FF)]),
        gameBuilder: (grade, level) => DarkMatterGridGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'ion_chain',
        title: s.ionChainTitle,
        description: s.ionChainDesc,
        icon: Icons.link,
        gradient: const LinearGradient(colors: [Color(0xFF06FFA5), Color(0xFF00C9DB)]),
        gameBuilder: (grade, level) => IonChainGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'launch_sequence',
        title: s.launchSequenceTitle,
        description: s.launchSequenceDesc,
        icon: Icons.sort,
        gradient: const LinearGradient(colors: [Color(0xFFE63946), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => LaunchSequenceGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'star_forge',
        title: s.starForgeTitle,
        description: s.starForgeDesc,
        icon: Icons.auto_awesome_mosaic,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF6B35)]),
        gameBuilder: (grade, level) => StarForgeGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'nebula_matrix',
        title: s.nebulaMatrixTitle,
        description: s.nebulaMatrixDesc,
        icon: Icons.grid_on_rounded,
        gradient: const LinearGradient(colors: [Color(0xFF6B48FF), Color(0xFFFF6B9D)]),
        gameBuilder: (grade, level) => NebulaMatrixGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'orbital_towers',
        title: s.orbitalTowersTitle,
        description: s.orbitalTowersDesc,
        icon: Icons.location_city,
        gradient: const LinearGradient(colors: [Color(0xFFE63946), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => OrbitalTowersGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'hive_station',
        title: s.hiveStationTitle,
        description: s.hiveStationDesc,
        icon: Icons.hexagon,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF6B35)]),
        gameBuilder: (grade, level) => HiveStationGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'relic_assembly',
        title: s.relicAssemblyTitle,
        description: s.relicAssemblyDesc,
        icon: Icons.dashboard_customize_outlined,
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => RelicAssemblyGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'xenobiology_lab',
        title: s.xenobiologyLabTitle,
        description: s.xenobiologyLabDesc,
        icon: Icons.biotech,
        gradient: const LinearGradient(colors: [Color(0xFF06FFA5), Color(0xFFFFD700)]),
        gameBuilder: (grade, level) => XenobiologyLabGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'galactic_market',
        title: s.galacticMarketTitle,
        description: s.galacticMarketDesc,
        icon: Icons.storefront,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFF06FFA5)]),
        gameBuilder: (grade, level) => GalacticMarketGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'asteroid_duel',
        title: s.asteroidDuelTitle,
        description: s.asteroidDuelDesc,
        icon: Icons.sports_kabaddi,
        gradient: const LinearGradient(colors: [Color(0xFFE63946), Color(0xFFFF6B35)]),
        gameBuilder: (grade, level) => AsteroidDuelGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'chrono_repair',
        title: s.chronoRepairTitle,
        description: s.chronoRepairDesc,
        icon: Icons.watch_later,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFF6B48FF)]),
        gameBuilder: (grade, level) => ChronoRepairGame(grade: grade, level: level),
      ),
      _GameInfoData(
        gameKey: 'void_crossing',
        title: s.voidCrossingTitle,
        description: s.voidCrossingDesc,
        icon: Icons.flight,
        gradient: const LinearGradient(colors: [Color(0xFF0B1426), Color(0xFF06FFA5)]),
        gameBuilder: (grade, level) => VoidCrossingGame(grade: grade, level: level),
      ),
    ];
  }

  void _showDebugPanel() {
    if (!kDebugMode) return;
    showDialog(
      context: context,
      builder: (context) => const DebugPanel(),
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
  
  Widget _buildInlineDifficultyPicker() {
    return Consumer<GameProvider>(
      builder: (context, gp, _) {
        final mode = gp.difficultyMode;
        return Container(
          height: 32,
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompactDifficultyTab(
                label: S.of(context)!.difficultyEasy,
                icon: Icons.spa,
                selected: mode == DifficultyMode.easy,
                onTap: () => gp.setDifficultyMode(DifficultyMode.easy),
                isFirst: true,
              ),
              _CompactDifficultyTab(
                label: S.of(context)!.difficultyNormal,
                icon: Icons.school,
                selected: mode == DifficultyMode.normal,
                onTap: () => gp.setDifficultyMode(DifficultyMode.normal),
              ),
              _CompactDifficultyTab(
                label: S.of(context)!.difficultyChallenge,
                icon: Icons.local_fire_department,
                selected: mode == DifficultyMode.challenge,
                onTap: () => gp.setDifficultyMode(DifficultyMode.challenge),
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSriBadge() {
    return Consumer<SriService>(
      builder: (context, sri, _) {
        final total = sri.totalTrackedProblems;
        if (total == 0) return const SizedBox.shrink();

        final due = sri.getAvailableReviewCount();

        return Material(
          color: Colors.transparent,
          child: Semantics(
            button: true,
            label: due > 0
                ? '$due items due for review, tap to open review'
                : 'Review progress, tap to open',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KarteikastenScreen()),
              ),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (due > 0 ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: due > 0 ? SpaceTheme.starYellow : Colors.white70,
                      size: 16,
                    ),
                    if (due > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$due',
                        style: const TextStyle(
                          color: SpaceTheme.starYellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final debugProvider = context.watch<DebugProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2235), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 10),
          // Title + grade
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.of(context)!.gameMenu,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 22)),
              Consumer<GameProvider>(
                builder: (context, gp, _) => Text(
                  S.of(context)!.gradeN(gp.grade),
                  style: SpaceTheme.bodyStyle.copyWith(
                      color: SpaceTheme.starYellow, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Difficulty picker (inline)
          Expanded(child: _buildInlineDifficultyPicker()),
          const SizedBox(width: 8),
          // SRI review badge
          _buildSriBadge(),
          const SizedBox(width: 6),
          // Score chip
          Consumer<GameProvider>(
            builder: (context, gp, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: SpaceTheme.starYellow, size: 16),
                  const SizedBox(width: 4),
                  Text(gp.score.toString(),
                      style: SpaceTheme.titleStyle
                          .copyWith(color: SpaceTheme.starYellow, fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _navigateToAchievements,
                icon: const Icon(Icons.emoji_events, size: 20),
                color: SpaceTheme.starYellow,
                tooltip: S.of(context)!.achievements,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(6),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ImprintDialog(),
                ),
                icon: const Icon(Icons.gavel, size: 20),
                color: SpaceTheme.moonSilver,
                tooltip: S.of(context)!.imprint,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(6),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: _navigateToSettings,
                icon: const Icon(Icons.settings, size: 20),
                color: SpaceTheme.moonSilver,
                tooltip: S.of(context)!.settings,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(6),
                ),
              ),
              if (debugProvider.isDebugMenuEnabled) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed: _showDebugPanel,
                  icon: const Icon(Icons.bug_report, size: 20),
                  color: debugProvider.isPaidUnlockedForced
                      ? SpaceTheme.alienGreen
                      : SpaceTheme.moonSilver,
                  tooltip: S.of(context)!.debugPanelTitle,
                  style: IconButton.styleFrom(
                    backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
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
      itemCount: _gamesData.length,
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
      itemCount: _gamesData.length,
      itemBuilder: (context, index) => _buildGameCard(index),
    );
  }
  
  // --- COMPLETELY REFACTORED _buildGameCard ---
  Widget _buildGameCard(int index) {
    final gameProvider = context.read<GameProvider>();
    final debugProvider = context.read<DebugProvider>();

    // Safety check
    if (index >= _gamesData.length || index >= _cardAnimations.length) {
      return const SizedBox.shrink();
    }
  
    final gameData = _gamesData[index];

    // --- BUG FIX ---
    // Get the specific saved level for *this* game
    final int savedLevel = gameProvider.getGameProgress(gameData.gameKey);
    // Default to level 1 if no progress (level 0) is found
    final int levelToLoad = savedLevel == 0 ? 1 : savedLevel;
    // --- END BUG FIX ---

    // Build the final GameInfo object with the correct onTap
    final game = GameInfo(
      title: gameData.title,
      description: gameData.description,
      icon: gameData.icon,
      gradient: gameData.gradient,
      gameKey: gameData.gameKey,
      // The onTap now correctly builds the game widget with the saved
      // level. We use effectiveGrade so the player's chosen difficulty
      // mode (easy/normal/challenge) shifts the game's grade band.
      onTap: () => _navigateToGame(
        gameData.gameBuilder(gameProvider.effectiveGrade, levelToLoad),
      ),
    );

    final bool isPremiumContent = index > 1; // First 2 games are free
    final bool isUnlocked = gameProvider.isFullVersionUnlocked || debugProvider.isPaidUnlockedForced;
    final bool isLocked = isPremiumContent && !isUnlocked;

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
                  // The onTap logic is now separated:
                  // If locked, show purchase flow. If unlocked, use the game's built-in onTap.
                  onTap: isLocked ? () => _showPurchaseFlow(context) : game.onTap,
                ),
                if (isLocked)
                  Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(25)),
                  ),
                if (isLocked)
                  Icon(Icons.lock, color: SpaceTheme.starYellow, size: 50, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 10)]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GameInfo {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final String gameKey;
  GameInfo({required this.title, required this.description, required this.icon, required this.gradient, required this.onTap, required this.gameKey});
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

  Widget _buildStarRating(BuildContext context) {
    final stars = context.watch<GameProvider>().bestStars[widget.game.gameKey] ?? 0;
    if (stars == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Icon(
        i < stars ? Icons.star_rounded : Icons.star_border_rounded,
        color: i < stars ? SpaceTheme.starYellow : Colors.white24,
        size: 18,
      )),
    );
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                    BoxShadow(color: widget.game.gradient.colors.first.withValues(alpha: _glowAnimation.value), blurRadius: 25, spreadRadius: 2),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Icon(widget.game.icon, size: 24, color: Colors.white),
                      ),
                      Text(widget.game.title, style: SpaceTheme.headlineStyle.copyWith(fontSize: 15), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(widget.game.description, style: SpaceTheme.bodyStyle.copyWith(fontSize: 12), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
                      _buildStarRating(context),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
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
class _CompactDifficultyTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  const _CompactDifficultyTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? SpaceTheme.starYellow.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isFirst ? const Radius.circular(16) : Radius.zero,
              right: isLast ? const Radius.circular(16) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected ? SpaceTheme.starYellow : Colors.white54),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
