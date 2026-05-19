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
