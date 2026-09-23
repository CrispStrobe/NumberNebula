// lib/features/games/game_registry.dart
//
// The one place game screens are imported, and they are imported *deferred*:
// on the web each game compiles into its own part that is downloaded the
// first time it is opened, instead of all 48 riding along in the main bundle
// every visitor downloads before seeing the menu. On mobile and desktop
// loadLibrary() completes immediately, so nothing changes there.
//
// Do not import a game screen from anywhere else in lib/: a single eager
// import pulls that game back into the main bundle.
// test/optimization_contracts_test.dart enforces this.

import 'package:flutter/material.dart';

import '../../core/theme/space_theme.dart';
import '../../generated/l10n.dart';
import '../../shared/utils/app_utilities.dart' show SpaceErrorScreen;

import 'screens/magic_triangles_game.dart'
    deferred as magic_triangles_game show MagicTrianglesGame;
import 'screens/asteroid_math_game.dart'
    deferred as asteroid_math_game show AsteroidMathGame;
import 'screens/puzzle_math_game.dart'
    deferred as puzzle_math_game show PuzzleMathGame;
import 'screens/hyperdrive_gates_game.dart'
    deferred as hyperdrive_gates_game show HyperdriveGatesGame;
import 'screens/path_finder_game.dart'
    deferred as path_finder_game show PathFinderGame;
import 'screens/planet_hopping_game.dart'
    deferred as planet_hopping_game show PlanetHoppingGame;
import 'screens/number_walls_game.dart'
    deferred as number_walls_game show NumberWallsGame;
import 'screens/codebreaker_game.dart'
    deferred as codebreaker_game show CodebreakerGame;
import 'screens/perspective_puzzle_game.dart'
    deferred as perspective_puzzle_game show PerspectivePuzzleGame;
import 'screens/blocks_counter_game.dart'
    deferred as blocks_counter_game show BlockCounterGame;
import 'screens/signal_triangulation_game.dart'
    deferred as signal_triangulation_game show SignalTriangulationGame;
import 'screens/cryptex_lock_breaker_game.dart'
    deferred as cryptex_lock_breaker_game show CryptexLockBreakerGame;
import 'screens/arithmancer_duel_game.dart'
    deferred as arithmancer_duel_game show ArithmancerDuelGame;
import 'screens/arithmatic_square_game.dart'
    deferred as arithmatic_square_game show ArithmeticSquareGame;
import 'screens/arithmancer_crosswords_game.dart'
    deferred as arithmancer_crosswords_game show ArithmancerCrosswordsGame;
import 'screens/kenken_game.dart'
    deferred as kenken_game show KenkenGame;
import 'screens/asteroid_field_navigator_game.dart'
    deferred as asteroid_field_navigator_game show AsteroidFieldNavigatorGame;
import 'screens/cargo_bay_arranger_game.dart'
    deferred as cargo_bay_arranger_game show CargoBayArrangerGame;
import 'screens/quantum_molecule_builder_game.dart'
    deferred as quantum_molecule_builder_game show QuantumMoleculeBuilderGame;
import 'screens/space_station_gridlock_game.dart'
    deferred as space_station_gridlock_game show SpaceStationGridlockGame;
import 'screens/star_loader_game.dart'
    deferred as star_loader_game show StarLoaderGame;
import 'screens/robot_path_game.dart'
    deferred as robot_path_game show RobotPathGame;
import 'screens/solarpanel_game.dart'
    deferred as solarpanel_game show SolarPanelGame;
import 'screens/grid_filler_game.dart'
    deferred as grid_filler_game show GridFillerGame;
import 'screens/star_chart_scan_game.dart'
    deferred as star_chart_scan_game show StarChartScanGame;
import 'screens/comm_relay_game.dart'
    deferred as comm_relay_game show CommRelayGame;
import 'screens/hull_plating_game.dart'
    deferred as hull_plating_game show HullPlatingGame;
import 'screens/vault_cracker_game.dart'
    deferred as vault_cracker_game show VaultCrackerGame;
import 'screens/crew_manifest_game.dart'
    deferred as crew_manifest_game show CrewManifestGame;
import 'screens/alien_tribunal_game.dart'
    deferred as alien_tribunal_game show AlienTribunalGame;
import 'screens/gravity_well_game.dart'
    deferred as gravity_well_game show GravityWellGame;
import 'screens/sector_painter_game.dart'
    deferred as sector_painter_game show SectorPainterGame;
import 'screens/warp_fold_game.dart'
    deferred as warp_fold_game show WarpFoldGame;
import 'screens/cube_scanner_game.dart'
    deferred as cube_scanner_game show CubeScannerGame;
import 'screens/circuit_repair_game.dart'
    deferred as circuit_repair_game show CircuitRepairGame;
import 'screens/dark_matter_grid_game.dart'
    deferred as dark_matter_grid_game show DarkMatterGridGame;
import 'screens/ion_chain_game.dart'
    deferred as ion_chain_game show IonChainGame;
import 'screens/launch_sequence_game.dart'
    deferred as launch_sequence_game show LaunchSequenceGame;
import 'screens/star_forge_game.dart'
    deferred as star_forge_game show StarForgeGame;
import 'screens/nebula_matrix_game.dart'
    deferred as nebula_matrix_game show NebulaMatrixGame;
import 'screens/orbital_towers_game.dart'
    deferred as orbital_towers_game show OrbitalTowersGame;
import 'screens/hive_station_game.dart'
    deferred as hive_station_game show HiveStationGame;
import 'screens/relic_assembly_game.dart'
    deferred as relic_assembly_game show RelicAssemblyGame;
import 'screens/xenobiology_lab_game.dart'
    deferred as xenobiology_lab_game show XenobiologyLabGame;
import 'screens/galactic_market_game.dart'
    deferred as galactic_market_game show GalacticMarketGame;
import 'screens/asteroid_duel_game.dart'
    deferred as asteroid_duel_game show AsteroidDuelGame;
import 'screens/chrono_repair_game.dart'
    deferred as chrono_repair_game show ChronoRepairGame;
import 'screens/void_crossing_game.dart'
    deferred as void_crossing_game show VoidCrossingGame;

/// Build a game widget from its grade and level.
typedef GameBuilder = Widget Function(int grade, int level);

class _DeferredGame {
  final Future<void> Function() load;
  final GameBuilder build;
  const _DeferredGame(this.load, this.build);
}

final Map<String, _DeferredGame> _games = {
  'magic_triangles': _DeferredGame(magic_triangles_game.loadLibrary,
      (g, l) => magic_triangles_game.MagicTrianglesGame(grade: g, level: l)),
  'asteroid_math': _DeferredGame(asteroid_math_game.loadLibrary,
      (g, l) => asteroid_math_game.AsteroidMathGame(grade: g, level: l)),
  'puzzle_math': _DeferredGame(puzzle_math_game.loadLibrary,
      (g, l) => puzzle_math_game.PuzzleMathGame(grade: g, level: l)),
  'hyperdrive_gates': _DeferredGame(hyperdrive_gates_game.loadLibrary,
      (g, l) => hyperdrive_gates_game.HyperdriveGatesGame(grade: g, level: l)),
  'pathfinder': _DeferredGame(path_finder_game.loadLibrary,
      (g, l) => path_finder_game.PathFinderGame(grade: g, level: l)),
  'planet_hopping': _DeferredGame(planet_hopping_game.loadLibrary,
      (g, l) => planet_hopping_game.PlanetHoppingGame(grade: g, level: l)),
  'number_walls': _DeferredGame(number_walls_game.loadLibrary,
      (g, l) => number_walls_game.NumberWallsGame(grade: g, level: l)),
  'codebreaker': _DeferredGame(codebreaker_game.loadLibrary,
      (g, l) => codebreaker_game.CodebreakerGame(grade: g, level: l)),
  'perspective_puzzle': _DeferredGame(perspective_puzzle_game.loadLibrary,
      (g, l) => perspective_puzzle_game.PerspectivePuzzleGame(grade: g, level: l)),
  'block_counter': _DeferredGame(blocks_counter_game.loadLibrary,
      (g, l) => blocks_counter_game.BlockCounterGame(grade: g, level: l)),
  'signal_triangulation': _DeferredGame(signal_triangulation_game.loadLibrary,
      (g, l) => signal_triangulation_game.SignalTriangulationGame(grade: g, level: l)),
  'cryptex_lock_breaker': _DeferredGame(cryptex_lock_breaker_game.loadLibrary,
      (g, l) => cryptex_lock_breaker_game.CryptexLockBreakerGame(grade: g, level: l)),
  'arithmancer_duel': _DeferredGame(arithmancer_duel_game.loadLibrary,
      (g, l) => arithmancer_duel_game.ArithmancerDuelGame(grade: g, level: l)),
  'arithmatic_square': _DeferredGame(arithmatic_square_game.loadLibrary,
      (g, l) => arithmatic_square_game.ArithmeticSquareGame(grade: g, level: l)),
  'arithmancer_crosswords': _DeferredGame(arithmancer_crosswords_game.loadLibrary,
      (g, l) => arithmancer_crosswords_game.ArithmancerCrosswordsGame(grade: g, level: l)),
  'kenken': _DeferredGame(kenken_game.loadLibrary,
      (g, l) => kenken_game.KenkenGame(grade: g, level: l)),
  'asteroid_field_navigator': _DeferredGame(asteroid_field_navigator_game.loadLibrary,
      (g, l) => asteroid_field_navigator_game.AsteroidFieldNavigatorGame(grade: g, level: l)),
  'cargo_bay_arranger': _DeferredGame(cargo_bay_arranger_game.loadLibrary,
      (g, l) => cargo_bay_arranger_game.CargoBayArrangerGame(grade: g, level: l)),
  'quantum_molecule_builder': _DeferredGame(quantum_molecule_builder_game.loadLibrary,
      (g, l) => quantum_molecule_builder_game.QuantumMoleculeBuilderGame(grade: g, level: l)),
  'space_station_gridlock': _DeferredGame(space_station_gridlock_game.loadLibrary,
      (g, l) => space_station_gridlock_game.SpaceStationGridlockGame(grade: g, level: l)),
  'star_loader_game': _DeferredGame(star_loader_game.loadLibrary,
      (g, l) => star_loader_game.StarLoaderGame(grade: g, level: l)),
  'robot_path_game': _DeferredGame(robot_path_game.loadLibrary,
      (g, l) => robot_path_game.RobotPathGame(grade: g, level: l)),
  'solarpanel_game': _DeferredGame(solarpanel_game.loadLibrary,
      (g, l) => solarpanel_game.SolarPanelGame(grade: g, level: l)),
  'grid_filler_game': _DeferredGame(grid_filler_game.loadLibrary,
      (g, l) => grid_filler_game.GridFillerGame(grade: g, level: l)),
  'star_chart_scan': _DeferredGame(star_chart_scan_game.loadLibrary,
      (g, l) => star_chart_scan_game.StarChartScanGame(grade: g, level: l)),
  'comm_relay': _DeferredGame(comm_relay_game.loadLibrary,
      (g, l) => comm_relay_game.CommRelayGame(grade: g, level: l)),
  'hull_plating': _DeferredGame(hull_plating_game.loadLibrary,
      (g, l) => hull_plating_game.HullPlatingGame(grade: g, level: l)),
  'vault_cracker': _DeferredGame(vault_cracker_game.loadLibrary,
      (g, l) => vault_cracker_game.VaultCrackerGame(grade: g, level: l)),
  'crew_manifest': _DeferredGame(crew_manifest_game.loadLibrary,
      (g, l) => crew_manifest_game.CrewManifestGame(grade: g, level: l)),
  'alien_tribunal': _DeferredGame(alien_tribunal_game.loadLibrary,
      (g, l) => alien_tribunal_game.AlienTribunalGame(grade: g, level: l)),
  'gravity_well': _DeferredGame(gravity_well_game.loadLibrary,
      (g, l) => gravity_well_game.GravityWellGame(grade: g, level: l)),
  'sector_painter': _DeferredGame(sector_painter_game.loadLibrary,
      (g, l) => sector_painter_game.SectorPainterGame(grade: g, level: l)),
  'warp_fold': _DeferredGame(warp_fold_game.loadLibrary,
      (g, l) => warp_fold_game.WarpFoldGame(grade: g, level: l)),
  'cube_scanner': _DeferredGame(cube_scanner_game.loadLibrary,
      (g, l) => cube_scanner_game.CubeScannerGame(grade: g, level: l)),
  'circuit_repair': _DeferredGame(circuit_repair_game.loadLibrary,
      (g, l) => circuit_repair_game.CircuitRepairGame(grade: g, level: l)),
  'dark_matter_grid': _DeferredGame(dark_matter_grid_game.loadLibrary,
      (g, l) => dark_matter_grid_game.DarkMatterGridGame(grade: g, level: l)),
  'ion_chain': _DeferredGame(ion_chain_game.loadLibrary,
      (g, l) => ion_chain_game.IonChainGame(grade: g, level: l)),
  'launch_sequence': _DeferredGame(launch_sequence_game.loadLibrary,
      (g, l) => launch_sequence_game.LaunchSequenceGame(grade: g, level: l)),
  'star_forge': _DeferredGame(star_forge_game.loadLibrary,
      (g, l) => star_forge_game.StarForgeGame(grade: g, level: l)),
  'nebula_matrix': _DeferredGame(nebula_matrix_game.loadLibrary,
      (g, l) => nebula_matrix_game.NebulaMatrixGame(grade: g, level: l)),
  'orbital_towers': _DeferredGame(orbital_towers_game.loadLibrary,
      (g, l) => orbital_towers_game.OrbitalTowersGame(grade: g, level: l)),
  'hive_station': _DeferredGame(hive_station_game.loadLibrary,
      (g, l) => hive_station_game.HiveStationGame(grade: g, level: l)),
  'relic_assembly': _DeferredGame(relic_assembly_game.loadLibrary,
      (g, l) => relic_assembly_game.RelicAssemblyGame(grade: g, level: l)),
  'xenobiology_lab': _DeferredGame(xenobiology_lab_game.loadLibrary,
      (g, l) => xenobiology_lab_game.XenobiologyLabGame(grade: g, level: l)),
  'galactic_market': _DeferredGame(galactic_market_game.loadLibrary,
      (g, l) => galactic_market_game.GalacticMarketGame(grade: g, level: l)),
  'asteroid_duel': _DeferredGame(asteroid_duel_game.loadLibrary,
      (g, l) => asteroid_duel_game.AsteroidDuelGame(grade: g, level: l)),
  'chrono_repair': _DeferredGame(chrono_repair_game.loadLibrary,
      (g, l) => chrono_repair_game.ChronoRepairGame(grade: g, level: l)),
  'void_crossing': _DeferredGame(void_crossing_game.loadLibrary,
      (g, l) => void_crossing_game.VoidCrossingGame(grade: g, level: l)),
};

/// Every registered gameKey.
Iterable<String> get registeredGameKeys => _games.keys;

/// Returns a builder that shows the game once its code is loaded, or null
/// for an unknown [gameKey].
GameBuilder? gameBuilderFor(String gameKey) {
  final game = _games[gameKey];
  if (game == null) return null;
  return (grade, level) => DeferredGameLoader(
        key: ValueKey('deferred_$gameKey'),
        gameKey: gameKey,
        load: game.load,
        builder: (_) => game.build(grade, level),
      );
}

/// Loads a deferred library, then builds [builder]. Shows a quiet loading
/// screen while it downloads and a retry screen if the download fails.
class DeferredGameLoader extends StatefulWidget {
  final String gameKey;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  const DeferredGameLoader({
    super.key,
    required this.gameKey,
    required this.load,
    required this.builder,
  });

  static final Set<String> _loaded = {};

  static bool isLoaded(String gameKey) => _loaded.contains(gameKey);

  static void markLoaded(String gameKey) => _loaded.add(gameKey);

  @visibleForTesting
  static void resetForTesting() => _loaded.clear();

  @override
  State<DeferredGameLoader> createState() => _DeferredGameLoaderState();
}

class _DeferredGameLoaderState extends State<DeferredGameLoader> {
  Object? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // A game opened before is built straight away, without a loading frame.
    _loaded = DeferredGameLoader.isLoaded(widget.gameKey);
    if (!_loaded) _load();
  }

  Future<void> _load() async {
    try {
      await widget.load();
      DeferredGameLoader.markLoaded(widget.gameKey);
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.builder(context);

    if (_error != null) {
      final s = S.of(context)!;
      return SpaceErrorScreen(
        title: s.gameLoadFailedTitle,
        message: s.gameLoadFailedMessage,
        errorIcon: Icons.cloud_off,
        onRetry: () {
          setState(() => _error = null);
          _load();
        },
        onBack: () => Navigator.of(context).maybePop(),
      );
    }

    return const Scaffold(
      key: ValueKey('deferred_game_loading'),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: SpaceTheme.spaceGradient),
        child: Center(
          child: CircularProgressIndicator(color: SpaceTheme.alienGreen),
        ),
      ),
    );
  }
}
