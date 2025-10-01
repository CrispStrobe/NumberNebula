// lib/core/models/skill_category.dart

enum SkillCategory {
  arithmetic,
  spatial3d,
  spatial2d,
  logicDeduction,
  patternRecognition,
}

// Complete game-to-skill mapping based on your game_menu_screen.dart
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
  // 'arithmancer_duel': SkillCategory.arithmetic,
  'arithmatic_square': SkillCategory.arithmetic,
  'arithmancer_crosswords': SkillCategory.arithmetic,
  'kenken': SkillCategory.arithmetic,
  'asteroid_math': SkillCategory.arithmetic,
  
  // Spatial 3D games (use CognitiveProfileService)
  'perspective_puzzle': SkillCategory.spatial3d,
  'block_counter': SkillCategory.spatial3d,
  
  // Logic/Deduction games (use CognitiveProfileService)
  'signal_triangulation': SkillCategory.logicDeduction,
  'cryptex_lock_breaker': SkillCategory.logicDeduction,

  // HYBRID: Arithmancer teaches BOTH arithmetic AND pattern recognition
  // Primary skill is pattern recognition, but we also track arithmetic
  'arithmancer_duel': SkillCategory.patternRecognition,
};