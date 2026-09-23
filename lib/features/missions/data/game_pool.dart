// lib/features/missions/data/game_pool.dart
//
// Registry mapping gameKeys to widget builders and display metadata.
// This is the single coupling point between missions and game screens.

import 'package:flutter/material.dart';

import '../../../core/models/skill_category.dart';
import '../../../generated/l10n.dart';
import '../../games/game_registry.dart';

export '../../games/game_registry.dart' show GameBuilder;

/// All game builders keyed by gameKey (matching game_menu_screen.dart).
/// Each builder loads its game's code on first use; see game_registry.dart.
final Map<String, GameBuilder> gameBuilders = {
  for (final key in registeredGameKeys) key: gameBuilderFor(key)!,
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

/// Games withheld from normal play because they are known-broken or not yet
/// good enough to put in front of a child.
///
/// They stay reachable once the debug menu is unlocked (seven taps on the home
/// screen title) so they can be finished, but they are kept out of the game
/// menu and never picked for a mission. Remove a key from here once its game
/// works -- that is the only step needed to ship it.
const Set<String> debugOnlyGames = {
  // Released 2026-09-23 after being played to a win in the browser:
  // galactic_market, relic_assembly, void_crossing (see REMAINING_WORK.md).
  // Fixed twice. First: generation searched for an impossible magic constant,
  // then fell back to a layout whose lines did not sum equally. Then a
  // play-through showed the board still made no sense -- the nodes were drawn
  // on two rings in an order that did not follow the outline, so an "arm" was
  // a bent polyline crossing its neighbours and "each line must have the same
  // sum" named nothing a player could point at. The layout now puts every arm
  // on four neighbouring points of the star outline, each arm carries its own
  // running total, and there is an illustrated walkthrough. Held back pending
  // another play-through.
  'star_forge',
  // Fixed (legal moves could strand the player with an unfillable slot, and
  // the same rule could be listed twice). A play-through then showed the rules
  // were unreadable: they named shapes in words ("Raute", "Stern") that the
  // board only ever draws, so each rule is now drawn as the two beads it
  // forbids. Held back pending another play-through.
  'ion_chain',
  // Fixed (nothing on the board said opposite faces sum to 7, nor that the
  // hidden faces are exactly the ones opposite the visible ones -- there is an
  // onboarding that draws both now). A play-through then found two more: the
  // question text was English literals baked into the generator, so German
  // players read "The bottom of Cube 1 ..."; and the questions were trivial --
  // the grade 3 and grade 4 answers both worked out to a number already
  // printed on the board. Questions now travel as data through the normal
  // localization, and each grade draws from several kinds. Held back pending
  // another play-through.
  'cube_scanner',
};

/// Whether [gameKey] may be offered to a player.
///
/// Broken games stay playable for whoever is fixing them, and stay hidden from
/// everyone else.
bool isGamePlayable(String gameKey, {required bool debugEnabled}) =>
    debugEnabled || !debugOnlyGames.contains(gameKey);

/// Every game key a mission may draw from -- [debugOnlyGames] excluded, so a
/// mission never hands a child a game that cannot be completed.
Iterable<String> get missionGameKeys =>
    gameBuilders.keys.where((k) => !debugOnlyGames.contains(k));

/// Mission games that are calculation practice — the "do the maths" half of a
/// mission. Derived from the canonical skill map so the two never drift.
List<String> get calculationGames => missionGameKeys
    .where((k) => gameSkillMap[k] == SkillCategory.arithmetic)
    .toList();

/// Mission games that are puzzles: logic, deduction, spatial and pattern play.
List<String> get puzzleGames => missionGameKeys
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
  'ion_chain',                 // chain building (currently in debugOnlyGames)
  'warp_fold',                 // paper folding
  'cube_scanner',              // dice nets (in debugOnlyGames)
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
