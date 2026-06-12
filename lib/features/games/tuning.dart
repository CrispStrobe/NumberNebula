// lib/features/games/tuning.dart
//
// Centralized tuning constants for the progression / mastery / SRI systems.
// Everything in this file is intended to be A/B-testable: changing a value
// here should change behavior across the whole app consistently.
//
// If you find a magic number scattered through a game file, move it here.

/// Number of consecutive wins at the current level required before the
/// player advances to the next one. Lower = faster progression but less
/// retention; higher = slower progression but better mastery.
const int kWinsRequiredForLevelUp = 3;

/// Default pass threshold (0.0 to 1.0) for ratio-based outcomes. Used by
/// [GameOutcome.fromRatio] and [CognitiveProfileService.hasMastery].
const double kDefaultPassThreshold = 0.7;

/// Minimum attempts at a (skill, difficulty) pair before we trust the
/// success ratio enough to claim mastery. Below this we always return
/// "not mastered" regardless of streak.
const int kMinAttemptsForMastery = 5;

/// Mastery gate before advancing a level. Player must have at least
/// [kMinTrackedProblemsForMastery] tracked problems at this difficulty,
/// of which at least [kDefaultPassThreshold] must be mastered.
const int kMinTrackedProblemsForMastery = 10;

// --- SM-2 spaced repetition constants ---
//
// Standard SM-2 (Piotr Wozniak, 1990). The defaults below reproduce
// the classic algorithm; tweak only if you really know what you're doing.

/// Starting easiness factor for a newly-introduced item. SM-2 default.
const double kSm2InitialEasiness = 2.5;

/// Floor on the easiness factor — anything below this means the item
/// is treated as "very hard" and reviewed frequently.
const double kSm2MinimumEasiness = 1.3;

/// Easiness above this threshold (plus enough repetitions) marks an item
/// as mastered.
const double kSm2MasteryEasinessThreshold = 4.0;

/// Repetitions required before mastery can even be considered.
const int kSm2MinimumRepetitionsForMastery = 3;

/// Max number of failure-only events tolerated when claiming mastery.
const int kSm2MaxFailuresForMastery = 1;

// --- Star rating normalization ---
//
// Each game has a different score range. To compare across games fairly,
// we convert raw scores to 1-3 stars using per-game expected-score brackets.
// Stars are awarded based on: 1 = completed, 2 = good, 3 = excellent.

/// Expected max score per game at grade 3, level 10 (midpoint).
/// Used to normalize: stars = rawScore / expectedMax mapped to [1,2,3].
/// Games not in this map default to the generic formula.
const Map<String, List<int>> kStarThresholds = {
  // Format: gameType: [1-star min, 2-star min, 3-star min]
  // Minimal-score games (base: 100*G + L*25)
  'asteroid_duel':          [100, 350, 500],
  'galactic_market':        [100, 350, 500],
  'hive_station':           [100, 350, 500],
  'ion_chain':              [100, 350, 500],
  'relic_assembly':         [100, 350, 500],
  'star_forge':             [100, 350, 500],
  'vault_cracker':          [100, 350, 500],
  'chrono_repair':          [100, 400, 600],
  'xenobiology_lab':        [100, 400, 650],

  // Medium-score games
  'alien_tribunal':         [150, 450, 700],
  'circuit_repair':         [150, 400, 600],
  'comm_relay':             [150, 450, 700],
  'creature_forge':         [150, 400, 600],
  'crew_manifest':          [150, 500, 750],
  'cube_scanner':           [150, 400, 600],
  'dark_matter_grid':       [100, 400, 600],
  'launch_sequence':        [150, 450, 650],
  'nebula_matrix':          [150, 500, 700],
  'orbital_towers':         [150, 500, 750],
  'warp_fold':              [100, 400, 650],
  'sector_painter':         [150, 450, 650],
  'signal_triangulation':   [200, 550, 850],
  'hull_plating':           [150, 450, 650],
  'gravity_well':           [150, 500, 750],
  'blocks_counter':         [200, 500, 700],
  'robot_path_game':        [150, 450, 650],
  'star_chart_scan':        [150, 450, 700],

  // High-score games
  'codebreaker':            [200, 600, 900],
  'magic_triangles':        [200, 550, 800],
  'number_walls':           [200, 600, 900],
  'arithmancer_crosswords': [250, 700, 1000],
  'cryptex_lock_breaker':   [250, 750, 1100],
  'space_station_gridlock': [250, 700, 1000],
  'perspective_puzzle':     [200, 600, 900],
  'kenken':                 [300, 800, 1200],

  // Very high / variable score games
  'asteroid_field_navigator': [300, 700, 1100],
  'cargo_bay_arranger':       [300, 800, 1500],
  'quantum_molecule_builder': [300, 700, 1100],
  'star_loader_game':         [200, 800, 1500],

  // Incremental / action games
  'asteroid_math':          [100, 400, 800],
  'bubble_math':            [50,  200, 400],
  'puzzle_math':            [50,  150, 300],
  'hyperdrive_gates':       [100, 500, 1000],
  'pathfinder':             [200, 600, 1000],
  'planet_hopping':         [300, 800, 1400],

  // Fixed / simple scoring
  'grid_filler_game':       [200, 500, 800],
  'solarpanel_game':        [150, 400, 550],
  'arithmatic_square':      [200, 600, 900],
  'arithmancer_duel':       [150, 450, 700],
};

/// Convert a raw game score to 1-3 stars.
/// Returns 0 if the game was lost (score 0 / not successful).
int scoreToStars(String gameType, int score, bool wasSuccessful) {
  if (!wasSuccessful) return 0;
  if (score <= 0) return 1; // Completed but no points = 1 star

  final thresholds = kStarThresholds[gameType];
  if (thresholds != null) {
    if (score >= thresholds[2]) return 3;
    if (score >= thresholds[1]) return 2;
    return 1;
  }

  // Fallback: generic percentile-based rating
  // Assume "average" score is ~500 at midpoint difficulty
  if (score >= 800) return 3;
  if (score >= 400) return 2;
  return 1;
}
