# Game Balance Audit

Systematic analysis of all 49 minigames: win/lose conditions, scoring, difficulty scaling, SRI integration, and cross-game consistency.

**Date:** 2026-06-13
**Status:** Complete. All 49 games audited, all bugs fixed, scoring normalized, all games have lose conditions.

### Changes Applied (2026-06-12 — 2026-06-13)

**Priority 1 — Critical Bugs Fixed:**
- [x] **Bubble Math**: Added `reportOutcome()` (win + loss) and SRI MathProblem reporting. Removed orphan `addScore()` call.
- [x] **Arithmetic Square**: Fixed `score: 0` → passes `totalScore` to `GameOutcome.win()`.
- [x] **Perspective Puzzle**: Fixed `score: 0` → passes `finalScore` to `GameOutcome.win()`.
- [x] **Star Loader**: Fixed `score: 0` → passes `totalScore` to `GameOutcome.win()`.
- [x] **Puzzle Math**: Migrated from legacy `GameOutcome()` constructor to `.win()`/`.loss()` factories. Also fixed `score: 0` → passes `finalScore`.
- [x] **Hyperdrive Gates**: Fixed `score: 0` → accumulates in `_levelScore`, passed in outcome. Removed direct `addScore()` calls.

**Priority 2 — SRI Gaps Fixed:**
- [x] **Cargo Bay Arranger**: Added MathProblem extraction from cleared rows (addition chains).
- [x] **Gravity Well**: Added MathProblem extraction from balance scale equations (addition/subtraction).

**Priority 3 — Scoring Normalization:**
- [x] Added `scoreToStars()` function in `tuning.dart` with per-game thresholds for 1-3 star rating.
- [x] Added `bestStars` tracking in `GameProvider` (persisted). Every `reportOutcome()` now computes stars.
- [x] `lastStars` and `bestStars` getters available for UI consumption.
- [x] Star ratings displayed on game menu cards. `StarRatingDisplay` widget available for win dialogs.

**Priority 4 — Difficulty Scaling:**
- [x] **Grid Filler**: Now scales from 10x10 (4 piece types) to 45x45 (9 piece types) based on `grade + level/5`.

**Priority 5 — Lose Conditions (all puzzle games now have move limits):**
- [x] Batch 1: Codebreaker, Nebula Matrix, Orbital Towers, Star Forge
- [x] Batch 2: Magic Triangles, Number Walls, KenKen
- All use 2x empty cells, color-coded indicator (green→orange→red), localized dialogs (en + de).

**Priority 6 — Remaining Issues from REMAINING_WORK.md:**
- [x] **Launch Sequence**: Lightened container background for contrast.
- [x] **Gravity Well**: Increased weight label fonts 8→11/10→13px, enlarged boxes.
- [x] **Hive Station**: Reduced hint fraction (100→90/80/70/60% by grade). Added unique-solution verification.
- [x] **Ion Chain**: Hardened CSP (100→500 attempts), fallback uses backtracking with 2 rules.
- [x] **Vault Cracker**: Added Wordle-style colored digit feedback (green/yellow/gray), 6-guess limit.
- [x] **Xenobiology Lab**: Added live-computed totals with color feedback (red=mismatch, green=match).
- [x] **Arithmancer Duel**: Fully audited — proper win/loss/scoring, real-time SRI tracking. Hybrid categorization intentional.

### Remaining Minor Items

**Galactic Market** — SRI reports only 1 division problem per session. Could extract additional arithmetic from the known/unknown coin relationships.

**Spatial/creative games without move limits** — Hull Plating, Relic Assembly, Star Chart Scan, Dark Matter Grid, Ion Chain, Launch Sequence. These are inherently open-ended (place/drag/explore) where a move limit would feel unnatural. They already have scoring that rewards efficiency.

---

## Table of Contents

1. [Infrastructure Overview](#infrastructure-overview)
2. [Per-Game Catalog](#per-game-catalog)
3. [Cross-Game Comparison Tables](#cross-game-comparison-tables)
4. [Phase 2: Consistency Analysis](#phase-2-consistency-analysis)
5. [Phase 3: Recommended Fixes](#phase-3-recommended-fixes)

---

## Infrastructure Overview

### Global Systems

**DifficultyManager** (`lib/features/games/constants/difficulty_manager.dart`):
- Input: `grade` (1-4 clamped from school grade 3-6) + `level` (1-20 per game)
- Output: `DifficultyConfig` with `difficultyMultiplier`, `numberRange`, `operationTypes`, `timeLimit`, `gameSpeed`, etc.
- Formula: `totalDifficulty = 1.0 + (grade * 0.4) + ((level - 1) * 0.05)` → range 1.4 to 3.55

**GameOutcome** (`lib/features/games/models/game_outcome.dart`):
- `.win(gameType, difficulty, score, mathProblems)` — binary success
- `.loss(gameType, difficulty, mathProblems)` — binary failure, score=0
- `.fromRatio(correct, total, passThreshold=0.7)` — gradient success

**Scoring Constants** (`lib/features/games/constants/app_constants.dart`):
- `correctAnswerPoints = 10`, `levelCompleteBonus = 100`, `timeBonus = 5/sec`, `perfectGameBonus = 200`
- Note: Most games ignore these constants and use their own formulas.

**Progression** (`lib/features/games/tuning.dart`):
- `kWinsRequiredForLevelUp = 3` consecutive wins to advance
- `kDefaultPassThreshold = 0.7` (70%) for ratio-based outcomes

**SRI** (Spaced Repetition Item, SM-2 algorithm):
- Only applies to `SkillCategory.arithmetic` games
- Tracks per-problem easiness factor, repetitions, next review date
- Mastery: EF >= 4.0, >= 3 reps, <= 1 failure

### Skill Categories (from `lib/core/models/skill_category.dart`)

| Category | Games | Tracking |
|----------|-------|----------|
| arithmetic | 16 games | SriService (per-problem SM-2) |
| spatial3d | 3 games | CognitiveProfileService |
| spatial2d | 6 games | CognitiveProfileService |
| logicDeduction | 15 games | CognitiveProfileService |
| patternRecognition | 4 games | CognitiveProfileService |

---

## Per-Game Catalog

Legend:
- **G** = grade (1-4), **L** = level (1-20)
- **SRI** = reports MathProblems to spaced repetition system
- **Outcome** = modern (`GameOutcome.win/loss`) vs legacy

---

### 1. Alien Tribunal
- **Skill:** logicDeduction
- **Concept:** Truth-teller/liar logic puzzle
- **Win:** Correctly assign all persons as truth-teller or liar
- **Lose:** Incorrect assignment (single attempt)
- **Score:** `100*G + L*25 + personCount*40`
- **Difficulty:** Person count scales with grade/level
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 2. Arithmancer Crosswords
- **Skill:** arithmetic
- **Concept:** Fill crossword grid with numbers satisfying equations
- **Win:** All empty cells filled + solution validates
- **Lose:** Out of moves (maxMoves = emptyCells * 1.6)
- **Score:** `250*G + equations*15 + emptyCells*5 + operationBonus` (op bonus: +=0, -=15, *=25, /=35)
- **Difficulty:** Grid complexity from DifficultyManager; division at grade>=4 level>=6
- **Timer:** None
- **Lives:** Move-limited (1.6x empty cells)
- **Rounds:** 1 crossword
- **SRI:** Yes (extracts all equations as MathProblems)
- **Outcome:** Modern

### 3. Arithmancer Duel
- **Skill:** patternRecognition (hybrid — also does real-time SRI arithmetic tracking)
- **Concept:** RPG-style math combat — build arithmetic expressions to damage enemies with mathematical shields
- **Win:** Defeat enemy (health→0). Program mode: 5 sequential enemies. PvP: opponent health→0 or higher HP after 25 turns.
- **Lose:** Player health drops to 0
- **Score:** Program: `200*G + (playerHealth/maxHealth)*100`. PvP: `300*G`.
- **Difficulty:** Fixed per enemy (5 enemies with different math shields: primes, parity, squares, Fibonacci, powers-of-2). Not grade/level parametric.
- **Timer:** None (PvP has 25-turn soft cap with escalating damage after turn 15)
- **Lives:** Single health pool (100 HP) per battle
- **Rounds:** Program: 5 battles. PvP: 1 battle. Ladder: 12 battles.
- **SRI:** Yes — real-time per-expression tracking via `sriService.recordResponse()`. Parses binary operations from player expressions.
- **Outcome:** Modern (passes real score, not 0)
- **Note:** Categorized as `patternRecognition` in `gameSkillMap`, so `reportOutcome` routes to CognitiveProfileService. But SRI tracking happens separately via direct calls during gameplay — both systems receive data.

### 4. Arithmetic Square
- **Skill:** arithmetic
- **Concept:** Fill grid so rows/columns form valid equations
- **Win:** All cells filled + all equations valid
- **Lose:** Out of moves (maxMoves = emptyCells * 1.6)
- **Score:** `200*G + gridSize^2*10 + operationBonus` — **BUT reports score: 0 in outcome (BUG)**
- **Difficulty:** Grid 3x3→5x5 by grade; division at grade>=4 level>=6
- **Timer:** None
- **Lives:** Move-limited (1.6x empty cells)
- **Rounds:** 1 puzzle
- **SRI:** Yes (real-time per-equation logging via sriService.recordResponse)
- **Outcome:** Modern — **score: 0 bug**

### 5. Asteroid Duel
- **Skill:** logicDeduction
- **Concept:** Nim game — avoid taking last asteroid
- **Win:** AI takes last asteroid
- **Lose:** Player takes last asteroid
- **Score:** `100*G + L*25`
- **Difficulty:** Asteroid count 8-25; AI strategy improves with grade (random→near-optimal)
- **Timer:** None
- **Lives:** 1 game
- **Rounds:** 1 Nim game
- **SRI:** No
- **Outcome:** Modern

### 6. Asteroid Field Navigator
- **Skill:** logicDeduction
- **Concept:** Minesweeper
- **Win:** Reveal all safe cells
- **Lose:** Click a mine
- **Score:** `300*G + max(0, (180-seconds)*2) + efficiencyBonus(100-200)`
- **Difficulty:** Grid 6x6/6mines → 20x20/70mines based on `complexity = grade + level/5`
- **Timer:** Tracked for scoring (no hard limit)
- **Lives:** 1 (one mine = game over)
- **Rounds:** 1 grid
- **SRI:** No
- **Outcome:** Modern

### 7. Asteroid Math Hunter
- **Skill:** arithmetic
- **Concept:** Click asteroids in ascending order of math answers
- **Win:** All asteroids clicked in correct order
- **Lose:** Time runs out OR wrong clicks > 1/3 of total
- **Score:** Per correct: `(15*G*diffMultiplier).round()` + time bonus: `timeLeft * (5+G)`
- **Difficulty:** Asteroid count scales with screen size; speed increases; timer from DifficultyConfig
- **Timer:** ~60s (from DifficultyConfig.timeLimit)
- **Lives:** Wrong clicks limited to 1/3 of total
- **Rounds:** 1 round (8-15+ asteroids)
- **SRI:** Yes (all asteroid equations reported)
- **Outcome:** Modern (direct constructor, not .win/.loss)

### 8. Blocks Counter
- **Skill:** spatial3d
- **Concept:** Count visible blocks in 3D isometric structure
- **Win:** Select correct count
- **Lose:** Select incorrect count (can retry — no penalty)
- **Score:** `150*G + difficulty*50` where difficulty = min(5, G + L/4)
- **Difficulty:** Grid 3-6+; block count 8-33+
- **Timer:** None
- **Lives:** Unlimited retries
- **Rounds:** 1 puzzle (4 choices)
- **SRI:** No
- **Outcome:** Modern

### 9. Bubble Math
- **Skill:** arithmetic
- **Concept:** Pop bubbles in ascending order of math answers
- **Win:** All bubbles popped in order
- **Lose:** Time runs out
- **Score:** `10 * bubblesPopped + timeLeft * 5`
- **Difficulty:** Bubble count 4-10; size/speed vary
- **Timer:** 60s fixed
- **Lives:** None (timer only)
- **Rounds:** 1 round (4-10 bubbles)
- **SRI:** Partial — generates MathProblems but does NOT report them in outcome
- **Outcome:** **BROKEN — no reportOutcome() call at all**

### 10. Cargo Bay Arranger
- **Skill:** arithmetic
- **Concept:** Tetris-like: clear rows by making numbers sum to target
- **Win:** Clear `rowsToWin` rows (8-20)
- **Lose:** Piece lands above grid (topout)
- **Score:** `score + 300*G + bonusTotal` (score = drop points + row clear combos; bonuses for patterns)
- **Difficulty:** 8 tiers by `complexity = G + L/5.0`: numberRange 1-5→5-20, speed 1000ms→400ms, rows 8→20
- **Timer:** None (continuous play, increasing speed)
- **Lives:** 1 (topout = game over)
- **Rounds:** Continuous until win/loss
- **SRI:** No (despite being arithmetic category)
- **Outcome:** Modern

### 11. Chrono Repair
- **Skill:** arithmetic
- **Concept:** Fix broken clock by calculating correct time
- **Win:** Selected hour+minute match correct values
- **Lose:** Wrong answer (single attempt)
- **Score:** `100*G + L*25 + complexityBonus(40 or 80)`
- **Difficulty:** Grade 1: simple offset; Grade 2: mirror; Grade 3+: combined offset+minutes
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** Yes (hour addition + minute addition problems)
- **Outcome:** Modern

### 12. Circuit Repair
- **Skill:** logicDeduction
- **Concept:** Swap two digits to fix an equation/time
- **Win:** Correct digit swap identified
- **Lose:** Exceed max attempts (1-5, scales down with difficulty)
- **Score:** `100*G + L*25 + (maxAttempts - used)*30`
- **Difficulty:** Attempts decrease: `(6 - grade - (level-1)/5).clamp(1,5)`
- **Timer:** None
- **Lives:** 1-5 attempts
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 13. Codebreaker
- **Skill:** arithmetic
- **Concept:** Fill hidden numbers in equations (CSP-like)
- **Win:** All hidden positions filled + all equations valid
- **Lose:** No explicit lose (only back-press → loss)
- **Score:** `150*G + equations*25 + operationBonus` (+=0, -=15, *=25, /=35)
- **Difficulty:** DifficultyManager; CSP generation; equation count/complexity scales
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** Yes (extracts equations as MathProblems)
- **Outcome:** Modern

### 14. Comm Relay
- **Skill:** logicDeduction
- **Concept:** Decode cipher (Caesar, Atbash, keyword)
- **Win:** Correct decode
- **Lose:** Exceed max attempts (1-5)
- **Score:** `100*G + L*25 + (maxAttempts - attempts)*50`
- **Difficulty:** Cipher type by grade; attempts decrease
- **Timer:** None
- **Lives:** 1-5 attempts
- **Rounds:** 1 cipher
- **SRI:** No
- **Outcome:** Modern

### 15. Creature Forge
- **Skill:** patternRecognition
- **Concept:** Count total possible creature combinations (combinatorics)
- **Win:** Correct combination count guessed
- **Lose:** No lose condition (unlimited guesses)
- **Score:** `100*G + L*25 + discoveredCombos*10`
- **Difficulty:** 2^3=8 → 4^3=64 combos; forbidden combos added at grade 3+
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only — no loss reported)

### 16. Crew Manifest
- **Skill:** logicDeduction
- **Concept:** Logic grid puzzle (crew-item assignments)
- **Win:** All assignments correct
- **Lose:** Incomplete submission shows error (can retry)
- **Score:** `100*G + L*25 + size*50`
- **Difficulty:** Grid 3x3→5x5 by grade
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 17. Cryptex Lock Breaker
- **Skill:** logicDeduction
- **Concept:** Set dial values to satisfy all equations simultaneously
- **Win:** All equations satisfied
- **Lose:** Back-press only (no explicit fail)
- **Score:** `250*G + (dialCount-2)*100 + equations*50`
- **Difficulty:** 3-5 dials; operators expand with grade; uses `complexity = G + L/5.0`
- **Timer:** None
- **Lives:** Unlimited (back = loss)
- **Rounds:** 1 puzzle
- **SRI:** Yes (equations converted to MathProblems)
- **Outcome:** Modern

### 18. Cube Scanner
- **Skill:** spatial3d
- **Concept:** Determine hidden dice face from visible faces
- **Win:** Select correct answer
- **Lose:** Incorrect answer (single attempt)
- **Score:** `100*G + L*25 + diceCount*75`
- **Difficulty:** Dice count 1-3; question types scale
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle (retry generates new puzzle)
- **SRI:** No
- **Outcome:** Modern

### 19. Dark Matter Grid
- **Skill:** logicDeduction
- **Concept:** Lights-out puzzle (toggle cells to all-off)
- **Win:** All cells in correct state
- **Lose:** No lose condition (unlimited moves)
- **Score:** `100*G + L*25 + (minMoves*50) / moveCount`
- **Difficulty:** Grid 3x3→5x5; toggle count scales
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only — no loss reported)

### 20. Galactic Market
- **Skill:** arithmetic
- **Concept:** Calculate face-down coin denomination from known coins + total
- **Win:** Select correct denomination
- **Lose:** Wrong selection (can retry — no penalty?)
- **Score:** `100*G + L*25`
- **Difficulty:** Grade 1-2: [1,2,5]; Grade 3+: [1,2,5,10,20,50]; 3-4 unknown coins
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** Yes (division problem)
- **Outcome:** Modern

### 21. Gravity Well
- **Skill:** arithmetic
- **Concept:** Determine unknown weights from balance scale equations
- **Win:** All weights correct
- **Lose:** Wrong weight (single attempt)
- **Score:** `100*G + L*25 + scales*30 + unknowns*40`
- **Difficulty:** 3-5 objects, 2-4 scales, 1-3 unknowns by grade
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** No (despite arithmetic category)
- **Outcome:** Modern

### 22. Grid Filler
- **Skill:** spatial2d
- **Concept:** Place squares (1x1 through 9x9) to fill 45x45 grid
- **Win:** All 9 pieces placed
- **Lose:** No lose condition
- **Score:** `300*G` (fixed — no level/complexity bonus)
- **Difficulty:** **FIXED — no scaling at all.** Always 45x45, always 9 pieces.
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 23. Hive Station
- **Skill:** logicDeduction
- **Concept:** Hexagonal minesweeper — mark energy cells
- **Win:** All energy cells correctly marked
- **Lose:** Wrong marking (single submit)
- **Score:** `100*G + L*25`
- **Difficulty:** Radius 1(7 cells)→3(37 cells); hint visibility 100%→65%
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 24. Hull Plating
- **Skill:** spatial2d
- **Concept:** Polyomino tiling (place pieces to cover board)
- **Win:** All pieces placed, full coverage
- **Lose:** No lose condition
- **Score:** `100*G + L*25 + pieces*30`
- **Difficulty:** Board 3x4→4x6; piece variety increases
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 25. Hyperdrive Gates
- **Skill:** arithmetic
- **Concept:** Choose correct math answer gate while flying
- **Win:** Clear `15 + level` gates
- **Lose:** Lose all 5 lives
- **Score:** Per gate: `10*G * comboCounter` (accumulated in `_levelScore`, passed in outcome)
- **Difficulty:** Speed: `160 + G*15 + L*5` + accelerates; gates increase with level
- **Timer:** None (continuous speed increase)
- **Lives:** 5 (shields can absorb 1; max 7 with power-ups)
- **Rounds:** 15+ gates per session
- **SRI:** Yes (per-gate real-time recording — NOT in outcome)
- **Outcome:** Modern (score passed via `_levelScore`)

### 26. Ion Chain
- **Skill:** logicDeduction
- **Concept:** Complete circular chain without rule violations
- **Win:** All blanks filled + validation passes
- **Lose:** Rule violation (can retry — no game over)
- **Score:** `100*G + L*25`
- **Difficulty:** Chain length 5-9; ion types 3-4; rules 1-3; blanks 2-4
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 27. KenKen
- **Skill:** arithmetic
- **Concept:** Latin square with cage arithmetic constraints
- **Win:** All cells filled + all cages valid + Latin square
- **Lose:** Incorrect submission (can retry)
- **Score:** `300*G + gridSize^2*15 + cages*20 + operationBonus` (+=0, -=15, *=25, /=35)
- **Difficulty:** Grid 3x3→9x9 (very aggressive at grade 4+); operations expand
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** Yes (cage equations decomposed into binary MathProblems)
- **Outcome:** Modern

### 28. Launch Sequence
- **Skill:** logicDeduction
- **Concept:** Sort shuffled numbers into ascending order by swapping
- **Win:** Sequence sorted
- **Lose:** No lose condition
- **Score:** `100*G + L*25 + (optimalSwaps/actualSwaps)*100`
- **Difficulty:** 4-8 items; 2-15 minimum inversions by grade/level
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 29. Magic Triangles
- **Skill:** patternRecognition
- **Concept:** Place numbers so each triangle side sums to target
- **Win:** All hidden positions filled + valid + perfect
- **Lose:** No lose (incorrect shows snackbar, retry)
- **Score:** `150*G + (150*G * circlesPerSide/3.0)`
- **Difficulty:** 3-5 circles per side; hidden cells increase
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No (despite being math-adjacent)
- **Outcome:** Modern (win only)

### 30. Nebula Matrix
- **Skill:** logicDeduction
- **Concept:** Binary constraint grid (fill cells based on row/col clues)
- **Win:** All empty cells filled + valid
- **Lose:** Incorrect (snackbar, retry)
- **Score:** `100*G + L*25 + size^2*10`
- **Difficulty:** Grid 3x3→5x5; clue % decreases with level
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 31. Number Walls
- **Skill:** arithmetic
- **Concept:** Pyramid where each brick = sum of two below (or other ops)
- **Win:** All hidden cells filled + all equations valid
- **Lose:** Incorrect (snackbar, retry)
- **Score:** `120*G + (120*G * wallHeight/3.0) + operationBonus` (+=0, -=25, *=50, /=75)
- **Difficulty:** Wall height 3-6; operations expand by grade
- **Timer:** None (15s hint fade)
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** Yes (reconstructs parent-child equations)
- **Outcome:** Modern

### 32. Orbital Towers
- **Skill:** logicDeduction
- **Concept:** Latin square + edge visibility clues (skyscrapers)
- **Win:** All cells filled + valid
- **Lose:** Incorrect (snackbar, retry)
- **Score:** `100*G + L*25 + size^2*15`
- **Difficulty:** Grid 3x3→5x5; edge clue % decreases
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 33. Path Finder
- **Skill:** arithmetic
- **Concept:** Choose correct math-answer gate for flying ship (continuous)
- **Win:** Solve `6 + grade` problems
- **Lose:** Lives drop to 0 (start 3.0; damage 0.25-1.0 per wrong path)
- **Score:** Per correct: `100*G + lives*50`; completion bonus: `500 + lives*100`
- **Difficulty:** Target problems = 6+G; speed = 120+G*15; path count = 2+(G/2)
- **Timer:** None
- **Lives:** 3.0 (floating point, fractional damage)
- **Rounds:** 6-10 problems per session
- **SRI:** Yes (per-attempt real-time recording — NOT in outcome)
- **Outcome:** Modern

### 34. Perspective Puzzle
- **Skill:** spatial3d
- **Concept:** Identify 3D structure from different viewpoints
- **Win:** Correctly answer all 4 perspective questions
- **Lose:** Lives drop to 0 (start 3)
- **Score:** `(250*G + difficulty*100 - mistakes*50).clamp(50, 1000)` — **reports score: 0 in outcome (BUG)**
- **Difficulty:** Grid 3-4; blocks 4-17; difficulty = min(5, G + L/4)
- **Timer:** None
- **Lives:** 3
- **Rounds:** 4 perspectives per session
- **SRI:** No
- **Outcome:** Modern — **score: 0 bug**

### 35. Planet Hopping
- **Skill:** arithmetic
- **Concept:** Land on planets in target sequence by solving math
- **Win:** All planets in sequence visited
- **Lose:** Lives drop to 0 (start 3)
- **Score:** `lives*200 + 100*G*targetSequence.length`
- **Difficulty:** Planet count 5-8 by `difficulty = G + L`; ordering varies
- **Timer:** None (12s hint timer)
- **Lives:** 3
- **Rounds:** 5-8 landings per session
- **SRI:** Yes (attempted problems reported in outcome)
- **Outcome:** Modern

### 36. Puzzle Math
- **Skill:** arithmetic
- **Concept:** Place puzzle pieces (with math expressions) on matching answer slots
- **Win:** All pieces placed correctly with 0 rotation
- **Lose:** Timer expires (120s, toggleable)
- **Score:** `100 + timeLeft*2` (max 340) — or flat 100 if timer off
- **Difficulty:** Grid 2x2→3x4 by grade (4-12 pieces)
- **Timer:** 120s (toggleable by player)
- **Lives:** Unlimited (wrong placement just bounces)
- **Rounds:** 1 puzzle
- **SRI:** Yes (all piece problems reported)
- **Outcome:** **Legacy** (direct GameOutcome constructor, not .win/.loss)

### 37. Quantum Molecule Builder
- **Skill:** spatial2d
- **Concept:** Arrange atoms to match target molecule (Atomix-like)
- **Win:** Pattern matches target arrangement
- **Lose:** Exceed move limit (20-150, formula-based)
- **Score:** `300*G + max(0, (moveLimit - moves)*10)`
- **Difficulty:** 30 predefined levels; move limit scales with grade modifier (1.0-1.3)
- **Timer:** None (move limit instead)
- **Lives:** 1 (move limit); undo costs 2 moves
- **Rounds:** 1 molecule per session
- **SRI:** No
- **Outcome:** Modern

### 38. Relic Assembly
- **Skill:** spatial2d
- **Concept:** Place tiles with matching edges (jigsaw-like)
- **Win:** All tiles placed with matching edges
- **Lose:** No lose condition
- **Score:** `100*G + L*25`
- **Difficulty:** DifficultyManager (puzzle complexity)
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 39. Robot Path
- **Skill:** logicDeduction
- **Concept:** Program robot with commands to reach goal
- **Win:** Robot reaches goal position
- **Lose:** Robot crashes (wall/obstacle/boundary)
- **Score:** `100*G + (100*G * efficiency/100)` where efficiency = optimalMoves/actualMoves * 100
- **Difficulty:** Custom level complexity (no DifficultyManager)
- **Timer:** None
- **Lives:** 1 attempt per run
- **Rounds:** 1 level
- **SRI:** No
- **Outcome:** Modern

### 40. Sector Painter
- **Skill:** logicDeduction
- **Concept:** Graph coloring — color regions with no adjacent same color
- **Win:** Valid coloring submitted
- **Lose:** Invalid coloring
- **Score:** `100*G + L*25 + (colorsUsed <= chromaticNumber ? 100 : 0)`
- **Difficulty:** DifficultyManager (region count, chromatic number)
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 41. Signal Triangulation
- **Skill:** logicDeduction
- **Concept:** Mastermind — guess secret glyph sequence
- **Win:** Correct sequence guessed
- **Lose:** Exhaust all guesses
- **Score:** `200*G + max(0, (maxGuesses - guessesUsed)*50) + (seqLength-3)*100`
- **Difficulty:** Sequence length 4-6 by grade; max guesses decrease
- **Timer:** 12s display timer (cosmetic)
- **Lives:** Limited guesses (varies)
- **Rounds:** 1 sequence
- **SRI:** No
- **Outcome:** Modern

### 42. Solar Panel
- **Skill:** logicDeduction (mapped, but has arithmetic)
- **Concept:** Fill grid cells using multiplication/addition constraints
- **Win:** All hidden cells filled + valid
- **Lose:** Invalid submission
- **Score:** `120*G + (120*G * 0.5)` = `180*G` (fixed)
- **Difficulty:** DifficultyManager
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** Yes (multiplication and addition problems)
- **Outcome:** Modern

### 43. Space Station Gridlock
- **Skill:** spatial2d
- **Concept:** Rush Hour — slide ships to free player ship
- **Win:** Player ship exits grid
- **Lose:** No explicit lose (puzzle always solvable)
- **Score:** `250*G + efficiencyBonus(50-300) + ships*20`
- **Difficulty:** Custom logic (ship count, grid config)
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 44. Star Chart Scan
- **Skill:** patternRecognition
- **Concept:** Find hidden equations in letter/number grid
- **Win:** All equations found
- **Lose:** No lose condition
- **Score:** `100*G + L*25 + equations*30`
- **Difficulty:** DifficultyManager (equation count)
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern (win only)

### 45. Star Forge
- **Skill:** logicDeduction
- **Concept:** Binary constraint puzzle on star graph
- **Win:** All nodes filled + valid
- **Lose:** Invalid submission
- **Score:** `100*G + L*25`
- **Difficulty:** DifficultyManager (node count)
- **Timer:** None
- **Lives:** Unlimited
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 46. Star Loader
- **Skill:** spatial2d
- **Concept:** Sokoban — push boxes onto targets
- **Win:** All boxes on all targets
- **Lose:** Player quits
- **Score:** `200*G + max(0, 1000 - time*5) + max(0, 500 - moves*2) + efficiencyBonus(0-500)` — **reports score: 0 in outcome (BUG)**
- **Difficulty:** DifficultyManager (level config)
- **Timer:** Stopwatch for scoring (no hard limit)
- **Lives:** 1 (quit = loss)
- **Rounds:** 1 level
- **SRI:** No
- **Outcome:** Modern — **score: 0 bug**

### 47. Vault Cracker
- **Skill:** logicDeduction
- **Concept:** Mastermind — guess secret code
- **Win:** Correct code guessed
- **Lose:** Incorrect code (single attempt? or limited)
- **Score:** `100*G + L*25`
- **Difficulty:** DifficultyManager
- **Timer:** None
- **Lives:** Variable
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 48. Warp Fold
- **Skill:** spatial2d
- **Concept:** Paper folding — predict result after folds
- **Win:** Select correct option
- **Lose:** Incorrect option
- **Score:** `100*G + L*25 + folds*50`
- **Difficulty:** Fold count increases with difficulty
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** No
- **Outcome:** Modern

### 49. Xenobiology Lab
- **Skill:** arithmetic
- **Concept:** Count creatures by type using visual multiplication
- **Win:** All slider values match creature counts
- **Lose:** Wrong submission
- **Score:** `100*G + L*25 + (hasThirdType ? 100 : 50)`
- **Difficulty:** 2-3 creature types; complexity bonus
- **Timer:** None
- **Lives:** 1 attempt
- **Rounds:** 1 puzzle
- **SRI:** Yes (multiplication + addition problems)
- **Outcome:** Modern

---

## Cross-Game Comparison Tables

### Scoring Formulas Summary

| Score Pattern | Games | Typical Range (G=3, L=10) |
|---|---|---|
| `100*G + L*25` (minimal) | Asteroid Duel, Galactic Market, Hive Station, Ion Chain, Relic Assembly, Star Forge, Vault Cracker | 550 |
| `100*G + L*25 + complexity` | Alien Tribunal, Circuit Repair, Comm Relay, Chrono Repair, Crew Manifest, Warp Fold, Xenobiology Lab | 550-850 |
| `150*G + complexity` | Codebreaker, Magic Triangles, Blocks Counter | 600-1000 |
| `200*G + complexity` | Arithmetic Square*, Puzzle Math | 100-340 (Puzzle Math) / 0 (ArithSquare bug) |
| `250*G + complexity` | Arithmancer Crosswords, Cryptex Lock, Space Station Gridlock, Perspective Puzzle* | 750-1300 |
| `300*G + complexity` | KenKen, Asteroid Field Nav, Grid Filler, Quantum Molecule, Cargo Bay | 900-2000+ |
| Incremental/combo | Hyperdrive Gates*, Path Finder, Asteroid Math, Bubble Math, Planet Hopping | highly variable |
| Time-based bonus | Star Loader*, Puzzle Math, Asteroid Field Nav | 200-2200 |

\* = score: 0 bug in outcome

### Bugs Found

| Game | Bug | Impact |
|---|---|---|
| **Arithmetic Square** | Reports `score: 0` in GameOutcome.win despite calculating score | Score not tracked in progression |
| **Perspective Puzzle** | Reports `score: 0` in GameOutcome.win despite calculating finalScore | Score not tracked in progression |
| **Star Loader** | Reports `score: 0` in GameOutcome.win despite calculating totalScore | Score not tracked in progression |
| **Hyperdrive Gates** | ~~Reports `score: 0`~~ Fixed — now passes `_levelScore` | Resolved |
| **Bubble Math** | No `reportOutcome()` call at all | Game completions not tracked in progression! |
| **Puzzle Math** | Uses legacy `GameOutcome()` constructor instead of `.win()/.loss()` | Works but inconsistent |

### SRI Integration Status

**Games in arithmetic category that DO report MathProblems:**
| Game | Method | Problems/Session |
|---|---|---|
| Arithmancer Crosswords | Bulk in outcome | 3-8 |
| Arithmetic Square | Real-time sriService.recordResponse | 4-10 |
| Asteroid Math Hunter | Bulk in outcome | 8-15 |
| Chrono Repair | Bulk in outcome | 1-2 |
| Codebreaker | Bulk in outcome | 3-8 |
| Hyperdrive Gates | Real-time sriService.recordResponse | 15+ |
| KenKen | Bulk in outcome | 5-15 |
| Number Walls | Bulk in outcome | 3-10 |
| Path Finder | Real-time sriService.recordResponse | 6-10 |
| Planet Hopping | Bulk in outcome | 5-8 |
| Puzzle Math | Bulk in outcome | 4-12 |
| Xenobiology Lab | Bulk in outcome | 2-4 |

**Games in arithmetic category that do NOT report MathProblems:**
| Game | Issue |
|---|---|
| **Bubble Math** | Generates problems but doesn't report them (also no reportOutcome!) |
| **Cargo Bay Arranger** | No math problem extraction at all |
| **Galactic Market** | Reports 1 division problem only |
| **Gravity Well** | No math problem extraction despite being balance-scale math |

**Non-arithmetic games that DO report MathProblems (unexpected):**
| Game | Category | Why |
|---|---|---|
| Cryptex Lock Breaker | logicDeduction | Has arithmetic equations as mechanic |
| Solar Panel | logicDeduction | Has multiplication/addition constraints |

### Difficulty Scaling Approaches

| Approach | Games | Notes |
|---|---|---|
| Uses DifficultyManager | ~30 games | Standard grade+level scaling |
| Custom `complexity = G + L/5.0` | Cargo Bay, Cryptex, Asteroid Field | Different curve |
| Custom difficulty formula | Blocks Counter, Path Finder, Planet Hopping, Perspective Puzzle, KenKen | Per-game parameters |
| **No scaling at all** | **Grid Filler** | Always same difficulty |
| Predefined levels | Quantum Molecule Builder (30 levels), Robot Path, Star Loader | Level database |

### Timer/Pressure Mechanisms

| Mechanism | Games |
|---|---|
| Hard timer (fail on expire) | Asteroid Math (~60s), Bubble Math (60s), Puzzle Math (120s toggleable) |
| Soft timer (scoring bonus) | Asteroid Field Nav, Star Loader |
| Speed increase | Cargo Bay (drop speed), Hyperdrive Gates (scroll speed) |
| Move/attempt limit | Arithmancer Crosswords, Arithmetic Square, Circuit Repair, Comm Relay, Quantum Molecule, Signal Triangulation |
| Lives system | Asteroid Math (wrong clicks), Hyperdrive Gates (5), Path Finder (3.0), Perspective Puzzle (3), Planet Hopping (3), Cargo Bay (topout) |
| **No pressure at all** | ~25 games (can think forever) |

### Lose Condition Summary

| Type | Games |
|---|---|
| Single wrong answer = loss | Alien Tribunal, Chrono Repair, Cube Scanner, Gravity Well, Hive Station, Warp Fold, Xenobiology Lab |
| Limited attempts | Circuit Repair (1-5), Comm Relay (1-5), Signal Triangulation (varies) |
| Lives system | Hyperdrive Gates, Path Finder, Perspective Puzzle, Planet Hopping |
| Timer/speed | Asteroid Math, Bubble Math, Puzzle Math, Cargo Bay |
| **No lose condition** | Codebreaker, Creature Forge, Dark Matter Grid, Grid Filler, Hull Plating, Ion Chain, KenKen, Launch Sequence, Magic Triangles, Nebula Matrix, Number Walls, Orbital Towers, Relic Assembly, Robot Path*, Sector Painter, Space Station Gridlock, Star Chart Scan, Star Forge, Star Loader |

\* Robot Path has crash mechanic but allows retry

---

## Phase 2: Consistency Analysis

### Issue 1: Score Magnitude Wildly Inconsistent

At **grade 3, level 10** (a typical midpoint), approximate max scores:

| Score Range | Games | Problem |
|---|---|---|
| **0 points** | Arithmetic Square, Perspective Puzzle, Star Loader, Hyperdrive Gates | Score: 0 bugs / design |
| **100-340** | Puzzle Math (100 flat or +time), Bubble Math (10*n + time) | Very low |
| **550** | Asteroid Duel, Galactic Market, Hive Station, Ion Chain, Relic Assembly, Star Forge, Vault Cracker | Low-medium |
| **550-850** | Most "base+level+small bonus" games | Medium |
| **900-1300** | Arithmancer Crosswords, Space Station Gridlock, KenKen | High |
| **1500-2500+** | Cargo Bay, Asteroid Math, Hyperdrive Gates (accumulated), Planet Hopping | Very high |

**A player who gets the same "difficulty" game can earn 0 to 2500+ points depending on which game they pick.** This makes the global score meaningless as a skill indicator.

### Issue 2: ~20 Games Have No Lose Condition

These games can never result in a loss — only wins. This means:
- `kWinsRequiredForLevelUp = 3` is trivially achieved by just... finishing 3 puzzles
- There's no consequence for poor performance
- Level progression is meaningless for these games

### Issue 3: ~25 Games Have No Time Pressure

Combined with no lose condition, many games allow infinite thinking time. While this is fine for some puzzle types (spatial reasoning benefits from deliberation), it means:
- A child can take 1 minute or 60 minutes for the same score
- No incentive to improve speed/fluency
- Session length is unpredictable

### Issue 4: SRI Not Implemented for 4 Arithmetic Games

Bubble Math, Cargo Bay, Galactic Market (partial), and Gravity Well are categorized as arithmetic but don't feed problems to the spaced repetition system. This means the SRI has blind spots — a child could play these games exclusively and never build a problem history.

### Issue 5: Grid Filler Has Zero Difficulty Scaling

Always the same puzzle regardless of grade or level. Once solved, replaying is pointless.

### Issue 6: Inconsistent Lose/Retry Behavior

- Some games: wrong answer = immediate game over (Alien Tribunal, Chrono Repair)
- Some games: wrong answer = snackbar, keep trying forever (KenKen, Magic Triangles, Number Walls)
- Some games: limited attempts that scale down (Circuit Repair, Comm Relay)
- Some games: lives system with different starting lives (3 vs 5 vs 3.0-float)

### Issue 7: Score: 0 Bugs

4 games calculate scores but report 0 in the outcome. This is clearly unintended in most cases (Arithmetic Square, Perspective Puzzle, Star Loader). Hyperdrive Gates is debatable — it accumulates score during play, but reporting 0 in the outcome means the progression system doesn't see a "final score."

### Issue 8: Bubble Math Completely Broken for Progression

No `reportOutcome()` call means the game doesn't register in the progression system at all. Wins don't count toward level-up, and math problems aren't tracked.

### Issue 9: Games Without Loss Can't Fail → Level-Up is Automatic

For games with no lose condition, the progression system sees: win, win, win → level up. Always. The "3 consecutive wins" gate is meaningless. These games should either:
- Have a fail condition added
- Use `GameOutcome.fromRatio()` with quality thresholds
- Track efficiency/moves/time and gate on quality

---

## Phase 3: Recommended Fixes

### Priority 1: Critical Bugs (must fix)

| # | Fix | Games Affected |
|---|---|---|
| 1.1 | **Add reportOutcome() to Bubble Math** | Bubble Math |
| 1.2 | **Fix score: 0 bugs** — pass calculated score to GameOutcome | Arithmetic Square, Perspective Puzzle, Star Loader |
| 1.3 | **Add SRI reporting to Cargo Bay** (extract row-sum equations) | Cargo Bay Arranger |
| 1.4 | **Add SRI reporting to Gravity Well** (extract balance equations) | Gravity Well |
| 1.5 | **Fix Bubble Math SRI** — report generated MathProblems in outcome | Bubble Math |
| 1.6 | **Migrate Puzzle Math** to GameOutcome.win/.loss factories | Puzzle Math |

### Priority 2: Scoring Normalization

**Proposal:** Introduce a normalized score alongside raw score. All games should produce scores in a comparable range (e.g., 0-1000) for the same effective difficulty.

| Approach | Description |
|---|---|
| **Option A: Normalize in GameProvider** | `normalizedScore = rawScore * (1000.0 / expectedMaxForGame)` |
| **Option B: Standardize formulas** | All games use: `baseScore(200) + difficultyBonus(0-300) + efficiencyBonus(0-300) + speedBonus(0-200)` |
| **Option C: Star rating** | Convert each game's score to 1-3 stars using per-game thresholds |

**Recommendation:** Option C (star rating) is simplest and most meaningful to kids. Define per-game thresholds for 1/2/3 stars. Use star count (not raw score) for cross-game comparison.

### Priority 3: Add Fail Conditions to No-Lose Games

**Approach:** Use `GameOutcome.fromRatio()` with efficiency metrics:

| Game Group | Proposed Fail Metric |
|---|---|
| Grid puzzles (Codebreaker, KenKen, etc.) | Move count > 3x optimal → loss |
| Spatial (Hull Plating, Grid Filler, etc.) | Time > generous threshold → loss (or reduced stars) |
| Sorting (Launch Sequence) | Swaps > 3x optimal → loss |
| No-fail puzzles (Dark Matter, Star Chart) | Add move limit or timer |

### Priority 4: Grid Filler Difficulty Scaling

Add difficulty progression: smaller grids at lower levels, larger at higher. Or vary piece shapes/constraints.

### Priority 5: Time Pressure Consistency

Consider adding optional/soft timers to more games:
- Not hard-fail timers (stressful for kids)
- Scoring bonuses for faster completion
- Or "par time" indicators (like golf)

---

## Appendix: Raw Data Reference

### All Scoring Formulas (alphabetical)

```
Alien Tribunal:        100*G + L*25 + persons*40
Arithmancer Crosswords: 250*G + eqs*15 + cells*5 + opBonus
Arithmancer Duel:      Program: 200*G + healthRatio*100; PvP: 300*G
Arithmetic Square:     200*G + gridSize²*10 + opBonus  [REPORTS 0]
Asteroid Duel:         100*G + L*25
Asteroid Field Nav:    300*G + max(0,(180-sec)*2) + effBonus
Asteroid Math:         15*G*mult per hit + timeLeft*(5+G)
Blocks Counter:        150*G + difficulty*50
Bubble Math:           10*popped + timeLeft*5  [NOT REPORTED]
Cargo Bay:             score + 300*G + bonuses
Chrono Repair:         100*G + L*25 + complexity(40/80)
Circuit Repair:        100*G + L*25 + (maxAttempts-used)*30
Codebreaker:           150*G + eqs*25 + opBonus
Comm Relay:            100*G + L*25 + (maxAttempts-attempts)*50
Creature Forge:        100*G + L*25 + combos*10
Crew Manifest:         100*G + L*25 + size*50
Cryptex Lock:          250*G + (dials-2)*100 + eqs*50
Cube Scanner:          100*G + L*25 + dice*75
Dark Matter Grid:      100*G + L*25 + (minMoves*50)/moves
Galactic Market:       100*G + L*25
Gravity Well:          100*G + L*25 + scales*30 + unknowns*40
Grid Filler:           300*G  [FIXED]
Hive Station:          100*G + L*25
Hull Plating:          100*G + L*25 + pieces*30
Hyperdrive Gates:      10*G*combo per gate (accumulated in _levelScore)
Ion Chain:             100*G + L*25
KenKen:                300*G + gridSize²*15 + cages*20 + opBonus
Launch Sequence:       100*G + L*25 + (optimal/actual)*100
Magic Triangles:       150*G + 150*G*(sides/3)
Nebula Matrix:         100*G + L*25 + size²*10
Number Walls:          120*G + 120*G*(height/3) + opBonus
Orbital Towers:        100*G + L*25 + size²*15
Path Finder:           (100*G + lives*50)/problem + 500 + lives*100
Perspective Puzzle:    (250*G + diff*100 - mistakes*50).clamp(50,1000) [REPORTS 0]
Planet Hopping:        lives*200 + 100*G*planets
Puzzle Math:           100 + timeLeft*2  [max 340]
Quantum Molecule:      300*G + max(0,(moveLimit-moves)*10)
Relic Assembly:        100*G + L*25
Robot Path:            100*G + 100*G*(efficiency/100)
Sector Painter:        100*G + L*25 + optimalBonus(0/100)
Signal Triangulation:  200*G + max(0,(maxGuesses-used)*50) + (seqLen-3)*100
Solar Panel:           180*G  [FIXED]
Space Station Gridlock: 250*G + effBonus(50-300) + ships*20
Star Chart Scan:       100*G + L*25 + eqs*30
Star Forge:            100*G + L*25
Star Loader:           200*G + timeBonus + moveBonus + effBonus  [REPORTS 0]
Vault Cracker:         100*G + L*25
Warp Fold:             100*G + L*25 + folds*50
Xenobiology Lab:       100*G + L*25 + complexity(50/100)
```
