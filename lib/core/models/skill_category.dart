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
  'magic_triangles': SkillCategory.arithmetic,
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
  
  // HYBRID: Arithmancer teaches BOTH arithmetic AND pattern recognition
  'arithmancer_duel': SkillCategory.patternRecognition,
};