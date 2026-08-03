// lib/features/missions/data/game_pool.dart
//
// Registry mapping gameKeys to widget builders and display metadata.
// This is the single coupling point between missions and game screens.

import 'package:flutter/material.dart';

import '../../../core/models/skill_category.dart';
import '../../../generated/l10n.dart';
import '../../games/screens/magic_triangles_game.dart';
import '../../games/screens/asteroid_math_game.dart';
import '../../games/screens/puzzle_math_game.dart';
import '../../games/screens/hyperdrive_gates_game.dart';
import '../../games/screens/path_finder_game.dart';
import '../../games/screens/planet_hopping_game.dart';
import '../../games/screens/number_walls_game.dart';
import '../../games/screens/codebreaker_game.dart';
import '../../games/screens/perspective_puzzle_game.dart';
import '../../games/screens/blocks_counter_game.dart';
import '../../games/screens/signal_triangulation_game.dart';
import '../../games/screens/cryptex_lock_breaker_game.dart';
import '../../games/screens/arithmancer_duel_game.dart';
import '../../games/screens/arithmatic_square_game.dart';
import '../../games/screens/arithmancer_crosswords_game.dart';
import '../../games/screens/kenken_game.dart';
import '../../games/screens/asteroid_field_navigator_game.dart';
import '../../games/screens/cargo_bay_arranger_game.dart';
import '../../games/screens/quantum_molecule_builder_game.dart';
import '../../games/screens/space_station_gridlock_game.dart';
import '../../games/screens/star_loader_game.dart';
import '../../games/screens/robot_path_game.dart';
import '../../games/screens/solarpanel_game.dart';
import '../../games/screens/grid_filler_game.dart';
import '../../games/screens/star_chart_scan_game.dart';
import '../../games/screens/comm_relay_game.dart';
import '../../games/screens/hull_plating_game.dart';
import '../../games/screens/vault_cracker_game.dart';
import '../../games/screens/crew_manifest_game.dart';
import '../../games/screens/alien_tribunal_game.dart';
import '../../games/screens/gravity_well_game.dart';
import '../../games/screens/sector_painter_game.dart';
import '../../games/screens/warp_fold_game.dart';
import '../../games/screens/cube_scanner_game.dart';
import '../../games/screens/circuit_repair_game.dart';
import '../../games/screens/dark_matter_grid_game.dart';
import '../../games/screens/ion_chain_game.dart';
import '../../games/screens/launch_sequence_game.dart';
import '../../games/screens/star_forge_game.dart';
import '../../games/screens/nebula_matrix_game.dart';
import '../../games/screens/orbital_towers_game.dart';
import '../../games/screens/hive_station_game.dart';
import '../../games/screens/relic_assembly_game.dart';
import '../../games/screens/xenobiology_lab_game.dart';
import '../../games/screens/galactic_market_game.dart';
import '../../games/screens/asteroid_duel_game.dart';
import '../../games/screens/chrono_repair_game.dart';
import '../../games/screens/void_crossing_game.dart';

/// Build a game widget from its key, grade, and level.
typedef GameBuilder = Widget Function(int grade, int level);

/// All game builders keyed by gameKey (matching game_menu_screen.dart).
final Map<String, GameBuilder> gameBuilders = {
  'magic_triangles': (g, l) => MagicTrianglesGame(grade: g, level: l),
  'asteroid_math': (g, l) => AsteroidMathGame(grade: g, level: l),
  'puzzle_math': (g, l) => PuzzleMathGame(grade: g, level: l),
  'hyperdrive_gates': (g, l) => HyperdriveGatesGame(grade: g, level: l),
  'pathfinder': (g, l) => PathFinderGame(grade: g, level: l),
  'planet_hopping': (g, l) => PlanetHoppingGame(grade: g, level: l),
  'number_walls': (g, l) => NumberWallsGame(grade: g, level: l),
  'codebreaker': (g, l) => CodebreakerGame(grade: g, level: l),
  'perspective_puzzle': (g, l) => PerspectivePuzzleGame(grade: g, level: l),
  'block_counter': (g, l) => BlockCounterGame(grade: g, level: l),
  'signal_triangulation': (g, l) => SignalTriangulationGame(grade: g, level: l),
  'cryptex_lock_breaker': (g, l) => CryptexLockBreakerGame(grade: g, level: l),
  'arithmancer_duel': (g, l) => ArithmancerDuelGame(grade: g, level: l),
  'arithmatic_square': (g, l) => ArithmeticSquareGame(grade: g, level: l),
  'arithmancer_crosswords': (g, l) => ArithmancerCrosswordsGame(grade: g, level: l),
  'kenken': (g, l) => KenkenGame(grade: g, level: l),
  'asteroid_field_navigator': (g, l) => AsteroidFieldNavigatorGame(grade: g, level: l),
  'cargo_bay_arranger': (g, l) => CargoBayArrangerGame(grade: g, level: l),
  'quantum_molecule_builder': (g, l) => QuantumMoleculeBuilderGame(grade: g, level: l),
  'space_station_gridlock': (g, l) => SpaceStationGridlockGame(grade: g, level: l),
  'star_loader_game': (g, l) => StarLoaderGame(grade: g, level: l),
  'robot_path_game': (g, l) => RobotPathGame(grade: g, level: l),
  'solarpanel_game': (g, l) => SolarPanelGame(grade: g, level: l),
  'grid_filler_game': (g, l) => GridFillerGame(grade: g, level: l),
  'star_chart_scan': (g, l) => StarChartScanGame(grade: g, level: l),
  'comm_relay': (g, l) => CommRelayGame(grade: g, level: l),
  'hull_plating': (g, l) => HullPlatingGame(grade: g, level: l),
  'vault_cracker': (g, l) => VaultCrackerGame(grade: g, level: l),
  'crew_manifest': (g, l) => CrewManifestGame(grade: g, level: l),
  'alien_tribunal': (g, l) => AlienTribunalGame(grade: g, level: l),
  'gravity_well': (g, l) => GravityWellGame(grade: g, level: l),
  'sector_painter': (g, l) => SectorPainterGame(grade: g, level: l),
  'warp_fold': (g, l) => WarpFoldGame(grade: g, level: l),
  'cube_scanner': (g, l) => CubeScannerGame(grade: g, level: l),
  'circuit_repair': (g, l) => CircuitRepairGame(grade: g, level: l),
  'dark_matter_grid': (g, l) => DarkMatterGridGame(grade: g, level: l),
  'ion_chain': (g, l) => IonChainGame(grade: g, level: l),
  'launch_sequence': (g, l) => LaunchSequenceGame(grade: g, level: l),
  'star_forge': (g, l) => StarForgeGame(grade: g, level: l),
  'nebula_matrix': (g, l) => NebulaMatrixGame(grade: g, level: l),
  'orbital_towers': (g, l) => OrbitalTowersGame(grade: g, level: l),
  'hive_station': (g, l) => HiveStationGame(grade: g, level: l),
  'relic_assembly': (g, l) => RelicAssemblyGame(grade: g, level: l),
  'xenobiology_lab': (g, l) => XenobiologyLabGame(grade: g, level: l),
  'galactic_market': (g, l) => GalacticMarketGame(grade: g, level: l),
  'asteroid_duel': (g, l) => AsteroidDuelGame(grade: g, level: l),
  'chrono_repair': (g, l) => ChronoRepairGame(grade: g, level: l),
  'void_crossing': (g, l) => VoidCrossingGame(grade: g, level: l),
};

/// Localized display title per gameKey, mirroring the game menu so a mission
/// task shows the same name the player knows from the menu instead of a
/// SHOUTED_GAME_KEY.
final Map<String, String Function(S)> gameTitles = {
  'magic_triangles': (s) => s.magicTrianglesGameTitle,
  'asteroid_math': (s) => s.asteroidMathHunter,
  'puzzle_math': (s) => s.puzzleMath,
  'hyperdrive_gates': (s) => s.hyperdriveGates,
  'pathfinder': (s) => s.pathFinderTitle,
  'planet_hopping': (s) => s.planetHoppingTitle,
  'number_walls': (s) => s.numberWallsGameTitle,
  'codebreaker': (s) => s.codebreaker,
  'perspective_puzzle': (s) => s.perspectivePuzzleGameTitle,
  'block_counter': (s) => s.blockCounterGameTitle,
  'signal_triangulation': (s) => s.signalTriangulationGameTitle,
  'cryptex_lock_breaker': (s) => s.cryptexLockBreakerGameTitle,
  'arithmancer_duel': (s) => s.arithmancerGameTitle,
  'arithmatic_square': (s) => s.arithmeticSquare,
  'arithmancer_crosswords': (s) => s.arithmancerCrosswords,
  'kenken': (s) => s.kenken,
  'asteroid_field_navigator': (s) => s.asteroidFieldTitle,
  'cargo_bay_arranger': (s) => s.cargoBayTitle,
  'quantum_molecule_builder': (s) => s.moleculeBuilderTitle,
  'space_station_gridlock': (s) => s.spaceGridlockTitle,
  'star_loader_game': (s) => s.starLoaderGameTitle,
  'robot_path_game': (s) => s.robotPathTitle,
  'solarpanel_game': (s) => s.solarPanelGameTitle,
  'grid_filler_game': (s) => s.gridFillerTitle,
  'star_chart_scan': (s) => s.starChartScanTitle,
  'comm_relay': (s) => s.commRelayTitle,
  'hull_plating': (s) => s.hullPlatingTitle,
  'vault_cracker': (s) => s.vaultCrackerTitle,
  'crew_manifest': (s) => s.crewManifestTitle,
  'alien_tribunal': (s) => s.alienTribunalTitle,
  'gravity_well': (s) => s.gravityWellTitle,
  'sector_painter': (s) => s.sectorPainterTitle,
  'warp_fold': (s) => s.warpFoldTitle,
  'cube_scanner': (s) => s.cubeScannerTitle,
  'circuit_repair': (s) => s.circuitRepairTitle,
  'dark_matter_grid': (s) => s.darkMatterGridTitle,
  'ion_chain': (s) => s.ionChainTitle,
  'launch_sequence': (s) => s.launchSequenceTitle,
  'star_forge': (s) => s.starForgeTitle,
  'nebula_matrix': (s) => s.nebulaMatrixTitle,
  'orbital_towers': (s) => s.orbitalTowersTitle,
  'hive_station': (s) => s.hiveStationTitle,
  'relic_assembly': (s) => s.relicAssemblyTitle,
  'xenobiology_lab': (s) => s.xenobiologyLabTitle,
  'galactic_market': (s) => s.galacticMarketTitle,
  'asteroid_duel': (s) => s.asteroidDuelTitle,
  'chrono_repair': (s) => s.chronoRepairTitle,
  'void_crossing': (s) => s.voidCrossingTitle,
};

/// Localized title for [gameKey], falling back to a readable form of the key.
String gameTitleFor(S s, String gameKey) {
  final builder = gameTitles[gameKey];
  if (builder != null) return builder(s);
  return gameKey
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Mission games that are calculation practice — the "do the maths" half of a
/// mission. Derived from the canonical skill map so the two never drift.
List<String> get calculationGames => gameBuilders.keys
    .where((k) => gameSkillMap[k] == SkillCategory.arithmetic)
    .toList();

/// Mission games that are puzzles: logic, deduction, spatial and pattern play.
List<String> get puzzleGames => gameBuilders.keys
    .where((k) =>
        gameSkillMap.containsKey(k) &&
        gameSkillMap[k] != SkillCategory.arithmetic)
    .toList();

/// The playful, physically-manipulable puzzles — sokoban, atomix, rush-hour
/// and friends. Every mission gets at least one so it never degenerates into
/// a list of grids to fill in.
const Set<String> signaturePuzzleGames = {
  'star_loader_game',          // sokoban
  'quantum_molecule_builder',  // atomix
  'space_station_gridlock',    // rush hour
  'robot_path_game',           // programming a path
  'void_crossing',             // river crossing
  'dark_matter_grid',          // lights out
  'launch_sequence',           // sorting
  'relic_assembly',            // edge-matching tiles
  'hull_plating',              // polyomino packing
  'grid_filler_game',          // tiling
  'cargo_bay_arranger',        // falling blocks
  'asteroid_field_navigator',  // minesweeper
  'sector_painter',            // map colouring
  'ion_chain',                 // chain building
  'warp_fold',                 // paper folding
  'cube_scanner',              // dice nets
};

/// Icons for display in the mission streak screen.
const Map<String, IconData> gameIcons = {
  'magic_triangles': Icons.change_history,
  'asteroid_math': Icons.bubble_chart,
  'puzzle_math': Icons.extension,
  'hyperdrive_gates': Icons.rocket_launch,
  'pathfinder': Icons.map,
  'planet_hopping': Icons.public,
  'number_walls': Icons.view_module,
  'codebreaker': Icons.vpn_key,
  'perspective_puzzle': Icons.grid_view_sharp,
  'block_counter': Icons.view_in_ar,
  'signal_triangulation': Icons.track_changes,
  'cryptex_lock_breaker': Icons.dialpad,
  'arithmancer_duel': Icons.auto_awesome,
  'arithmatic_square': Icons.grid_on,
  'arithmancer_crosswords': Icons.border_all,
  'kenken': Icons.dashboard_customize,
  'asteroid_field_navigator': Icons.grid_4x4,
  'cargo_bay_arranger': Icons.view_module,
  'quantum_molecule_builder': Icons.science,
  'space_station_gridlock': Icons.view_module,
  'star_loader_game': Icons.move_down,
  'robot_path_game': Icons.smart_toy_outlined,
  'solarpanel_game': Icons.smart_toy_outlined,
  'grid_filler_game': Icons.smart_toy_outlined,
  'star_chart_scan': Icons.travel_explore,
  'comm_relay': Icons.satellite_alt,
  'hull_plating': Icons.view_compact,
  'vault_cracker': Icons.lock_open,
  'crew_manifest': Icons.assignment_ind,
  'alien_tribunal': Icons.gavel,
  'gravity_well': Icons.balance,
  'sector_painter': Icons.palette,
  'warp_fold': Icons.content_cut,
  'cube_scanner': Icons.view_in_ar_outlined,
  'circuit_repair': Icons.electrical_services,
  'dark_matter_grid': Icons.grid_view,
  'ion_chain': Icons.link,
  'launch_sequence': Icons.sort,
  'star_forge': Icons.auto_awesome_mosaic,
  'nebula_matrix': Icons.grid_on_rounded,
  'orbital_towers': Icons.location_city,
  'hive_station': Icons.hexagon,
  'relic_assembly': Icons.build,
  'xenobiology_lab': Icons.biotech,
  'galactic_market': Icons.storefront,
  'asteroid_duel': Icons.sports_kabaddi,
  'chrono_repair': Icons.watch_later,
  'void_crossing': Icons.flight,
};
