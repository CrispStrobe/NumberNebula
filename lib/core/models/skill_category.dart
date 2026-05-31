// lib/core/models/skill_category.dart

enum SkillCategory {
  arithmetic,
  spatial3d,
  spatial2d,
  logicDeduction,
  patternRecognition,
}

// Complete game-to-skill mapping, corresponding to game_menu_screen.dart
const Map<String, SkillCategory> gameSkillMap = {
  // Arithmetic games (use SriService)
  'bubble_math': SkillCategory.arithmetic,
  'puzzle_math': SkillCategory.arithmetic,
  'hyperdrive_gates': SkillCategory.arithmetic,
  'pathfinder': SkillCategory.arithmetic,
  'planet_hopping': SkillCategory.arithmetic,
  'number_walls': SkillCategory.arithmetic,
  'codebreaker': SkillCategory.arithmetic,
  'arithmatic_square': SkillCategory.arithmetic,
  'arithmancer_crosswords': SkillCategory.arithmetic,
  'kenken': SkillCategory.arithmetic,
  'asteroid_math': SkillCategory.arithmetic,
  'cargo_bay_arranger': SkillCategory.arithmetic,
  
  // Spatial games (use CognitiveProfileService)
  'perspective_puzzle': SkillCategory.spatial3d,
  'block_counter': SkillCategory.spatial3d,
  'quantum_molecule_builder': SkillCategory.spatial2d,
  'space_station_gridlock': SkillCategory.spatial2d,
  'star_loader_game': SkillCategory.spatial2d,

  // Logic/Deduction games (use CognitiveProfileService)
  'signal_triangulation': SkillCategory.logicDeduction,
  'cryptex_lock_breaker': SkillCategory.logicDeduction,
  'asteroid_field_navigator': SkillCategory.logicDeduction,
  'robot_path_game': SkillCategory.logicDeduction,
  'solarpanel_game': SkillCategory.logicDeduction,
  'grid_filler_game': SkillCategory.spatial2d,

  // HYBRID: Arithmancer teaches BOTH arithmetic AND pattern recognition
  'arithmancer_duel': SkillCategory.patternRecognition,

  // Pure pattern/puzzle games (no per-problem SRI data)
  'magic_triangles': SkillCategory.patternRecognition,

  // Batch F: Word/Cipher/Tile games
  'star_chart_scan': SkillCategory.patternRecognition,
  'comm_relay': SkillCategory.logicDeduction,
  'hull_plating': SkillCategory.spatial2d,

  // Batch B: Logic Deduction Games
  'vault_cracker': SkillCategory.logicDeduction,
  'crew_manifest': SkillCategory.logicDeduction,
  'alien_tribunal': SkillCategory.logicDeduction,
  'gravity_well': SkillCategory.arithmetic,

  // Batch D: Pattern/Visual Games
  'sector_painter': SkillCategory.logicDeduction,
  'warp_fold': SkillCategory.spatial2d,
  'cube_scanner': SkillCategory.spatial3d,
  'circuit_repair': SkillCategory.logicDeduction,

  // Batch C: Interactive/Spatial Games
  'dark_matter_grid': SkillCategory.logicDeduction,
  'dock_clearance': SkillCategory.spatial2d,
  'ion_chain': SkillCategory.logicDeduction,
  'launch_sequence': SkillCategory.logicDeduction,

  // Batch A: Pure CSP Grid Games
  'star_forge': SkillCategory.logicDeduction,
  'nebula_matrix': SkillCategory.logicDeduction,
  'orbital_towers': SkillCategory.logicDeduction,
  'hive_station': SkillCategory.logicDeduction,
  'relic_assembly': SkillCategory.spatial2d,

  // Batch E: Math/Counting Games
  'xenobiology_lab': SkillCategory.arithmetic,
  'galactic_market': SkillCategory.arithmetic,
  'creature_forge': SkillCategory.patternRecognition,
  'asteroid_duel': SkillCategory.logicDeduction,
  'chrono_repair': SkillCategory.arithmetic,
};