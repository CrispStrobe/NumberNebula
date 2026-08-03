# Completed work — space_math_academy & voc (WortUniversum)

Archive of finished items, moved out of `PLAN.md` on 2026-08-01 so the plan
only lists what is still open. Entries are kept verbatim as a record of what
was done and why; sibling repo `../voc` is referenced where work was mirrored.
See `PLAN.md` for remaining work.

---

## Tier 1 — Highest leverage

### [x] 1. Crash reporting in both apps
Local-first `CrashLogger` that persists `FlutterError.onError` and
`PlatformDispatcher.instance.onError` to a rotating file in app
documents. User-facing `DiagnosticsScreen` (Settings → Diagnostics)
exposes the log read-only with a "Copy to clipboard" action. Nothing
leaves the device unless the user explicitly copies. DSGVO-clean by
design — no third-party processor.

### [x] 2. Contract test suite (zero tests currently)
Most game logic is deterministic (puzzle generators, SRI decisions,
arithmetic generation, separable-verb detection). A `test/contracts/`
directory of consistency tests would have caught most bugs we just
fixed:
- `gameSkillMap` key drift → assert every menu key resolves
- missing `recordLevelWin` → assert every menu-registered game calls it
- `package.flutter/` typo → covered by `flutter analyze` already, but
  could be CI-enforced
- provider tree completeness — assert every `context.read<X>()` in a
  game has an X registered in `main.dart`

### [x] 3. Real audio in voc
Synthesized 5 short royalty-free sounds via ffmpeg (success / failure
/ tap / levelup / whoosh, ~24 KB total). AudioService now uses
audioplayers with per-effect AudioPlayer instances (no
truncation-on-overlap). Normalized call-site names — was a mix of
`'success'` / `'correct.mp3'` / `'whoosh.mp3'`; all collapsed to bare
keys. Background music + TTS remain stubbed until needed.

---

## Tier 2 — Architecture & maintainability

### [x] 5. Split game files > 1500 LoC
Pulled painters, puzzle generation, and game-world models out of six
oversized screen files into sibling `widgets/` and `services/` files.
Results (before → after):
- `magic_triangles_game.dart` 1486 → 973
- `hyperdrive_gates_game.dart` 1747 → 1111
- `arithmancer_crosswords_game.dart` 2126 → 1240
- `codebreaker_game.dart` 2331 → 1143
- `space_word_rescue_game.dart` (voc) 1625 → 1412
- `arithmancer_duel_game.dart` 3495 → 2839 (partial; see below)
arithmancer_duel was reduced by extracting visual effects, mode
selection, and dialogs. The remaining 2839 LoC is intrinsic
3-mode card-combat State — further reduction would require converting
the State's UI builders into stateless widgets with passed-in deps,
which is architectural work, not a file split, and adds significant
constructor boilerplate. Left as-is unless maintenance pain is felt.

### [x] 6. Unify the progression contract
Added `GameOutcome` value type in both projects with `.win` / `.loss`
/ `.fromRatio` named factories. New `GameProvider.reportOutcome(...)`
is the canonical entry point; legacy `recordLevelWin(...)` is now a
deprecated shim. Migrated all 53 call sites (42 space_math, 11 voc)
via a one-shot Python script. Contract tests updated to accept either
pattern.

---

## Tier 3 — Accessibility (high stakes for a kids' app)

### [x] 7. Replace color-only feedback
Swept all 28 game screens. Added ✓/✗ icon overlays, haptic feedback
(`HapticFeedback.lightImpact/heavyImpact`), and error icons on
snackbars wherever correctness was previously color-only. Colors
themselves unchanged — non-color cues added in parallel.

### [x] 8. Add `Semantics` annotations
Wrapped interactive boundaries (dials, cells, drop slots, draggables,
swipe areas) across all major game screens. Shared `GameUI` widget
now exposes score/time as `liveRegion: true` Semantics so screen
readers announce updates. `ExcludeSemantics` used around decorative
inner content. Labels describe function not color.

### [x] 9. Respect OS text scaling
Dropped hardcoded `fontSize:` on title/instruction/body text in
shared `GameUI` and per-game compact headers — `SpaceTheme.{body,title,
headline}Style` now drives sizing with OS scaler. Fixed-width labels
(stat pills, cell numerals) wrapped in `FittedBox(scaleDown)`. Some
intentionally-sized text inside FittedBox/grid cells left as-is.

### [x] 10. Touch targets ≥ 48dp
Cryptex dial verified at 120×180 (well over 48dp). `signal_triangulation`
glyph buttons and `robot_path` remove-X wrapped in 48dp `SizedBox` +
`HitTestBehavior.translucent`. Several full-area gesture detectors
(`bubble_math`, `cargo_bay_arranger`, `planet_hopping`, `path_finder`,
`hyperdrive_gates`, `asteroid_field_navigator`) got translucent hit
behavior so transparent padding counts as hit area.

---

## Tier 4 — Educational integrity

### [x] 11. Surface the SRI state
Added `SriReviewScreen` (read-only) plus a `Badge.count`-style chip on
the home header that shows the number of items due. Tile lists the
toughest tracked items (lowest easiness factor). Mirrored across both
projects.

### [x] 12. Surface the cognitive profile
Added `CognitiveProfileScreen` showing per-skill bars + per-difficulty
chips. Reads from a new `CognitiveProfileService.snapshot` getter
(returns deep copies so consumers can't mutate). Surfaced via the
home header. Mirrored.

### [x] 13. Parental dashboard
Added `ParentDashboardScreen` with 4-digit PIN gate (default `1234`,
changeable from inside the screen, stored in SharedPreferences).
Aggregates GameProvider game progress, SriService mastery, and
CognitiveProfileService strongest/weakest skills. Surfaced from
Settings → About in both projects. Time-bucketing ("last 7 days")
deferred — current data model doesn't timestamp per-attempt; would
need new plumbing.

### [x] 14. Document and centralize tuning constants
Created `lib/features/games/tuning.dart` in both projects with named
constants for `kWinsRequiredForLevelUp`, `kDefaultPassThreshold`,
`kMinAttemptsForMastery`, `kMinTrackedProblemsForMastery`, plus
the SM-2 algorithm constants (`kSm2InitialEasiness`,
`kSm2MinimumEasiness`, etc.). Wired into GameProvider,
CognitiveProfileService, SriService, GameOutcome.

---

## Tier 5 — Internationalization

### [x] 15. voc: consolidate l10n
Picked direction: voc is German-first, English ARB kept for surface
chrome (existing 200+ keys, plus 70 new ones for the polish work
above). The agent-driven cleanup pass lifted ~68 user-visible German
literals across 8 game/UI files into ARB with real English
translations and ICU plurals where needed. Intentionally left inline:
pedagogical content (grammar rule explanations, German example
sentences the games generate), Wiktionary inflection tag strings,
debug-only output. Final state: `flutter analyze` clean, all 3
contract tests passing.

---

## Tier 6 — DevOps

### [x] 16. Add basic CI
`.github/workflows/ci.yml` in both repos runs `flutter analyze
--fatal-infos` + `flutter test` on push to main and PRs against main.
Uses subosito/flutter-action@v2 pinned to Flutter 3.38.5 to match the
local toolchain. Cache is enabled so warm runs are fast. The
`--fatal-infos` flag locks in the "zero issues at any level" bar we
just cleared.

### [x] 17. Cap Gradle daemon heap
`org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m` in
`android/gradle.properties` of each project. Currently the daemon
balloons to ~5GB after a few builds.

---

## Tier 7 — Game design polish

### [x] 19. Onboarding per game
New `OnboardingOverlay` widget (shared between projects). One-call
API: `OnboardingOverlay.maybeShow(context, gameKey:..., title:...,
steps:...)` from `initState`. Tracks per-game seen-state in
SharedPreferences so it shows exactly once. Wired into
`magic_triangles_game` (space_math) and `word_sort_game` (voc) as
template demonstrations; other games can adopt by adding 5 lines.

### [x] 20. Difficulty picker
New `DifficultyMode` enum (easy / normal / challenge) on
GameProvider in both projects. Maps to a grade shift of -1 / 0 / +1
clamped to 1..6. `effectiveGrade` getter applied at game launch
time so per-game internals don't need to know about it. Toggle row
at the top of the game menu, persisted in SharedPreferences.

### [x] 21. Daily-challenge / streak mechanic
New `StreakService` (shared between projects). Tracks
current/longest streak + last-played day via local calendar
arithmetic. Auto-heals on load if the player skipped ≥2 days. Marked
played on app launch. Surfaced as 🔥 chip on the home screen when
streak > 0.

### [x] 22. Achievements UI for voc
New voc-only `AchievementsScreen` with a 14-entry catalog matching
the IDs already tracked in `GameProvider._achievements`. Surfaced
from the home header with a trophy icon. German strings inline (see
#15 — voc is German-first).

---

## Tier 8 — Privacy / compliance (kids app)

### [x] 23. Privacy policy + data disclosure
New `PrivacyPolicyDialog` in both projects (English for space_math,
German for voc). 7 sections covering: short summary, what's stored
locally, network behavior, crash report flow, COPPA/GDPR-K
applicability, user reset rights, change policy. Reachable from
Settings → Privacy & data (space_math) / Datenschutz (voc).
Composition: honest claim that nothing is transmitted, no PII
collected, so the consent rules of COPPA + GDPR Art. 8 don't
attach because there's nothing to consent to.

### [x] 24. Audit data-at-rest + reset control
Inventory: 11 SharedPreferences keys in space_math (game_data,
sri_database, cognitive_profile, achievements, gridlock_played_puzzles,
streak_current/longest, debug_force_unlock, language,
starloader_played_ids, settings), plus a 50-entry rolling crash_log
JSONL file. Voc adds: sri_language_database, custom_words,
vocabulary_sets, parent_pin, and the extracted DB. No PII anywhere.
Added "Reset all data" parental-gated action to Settings in both
projects — challenge gate first (math addition), then the existing
reset confirmation dialog. Documented findings in the policy text.

---

## Decided not to do

### [-] 4. Extract the voc falling-tile game template
The "~80% duplication" framing turned out to be optimistic. The 4 games
(`grossschreib`, `grossstadt`, `verbtrenner`, `wortbaumeister`) share
*structure* — combo tracking, miss handling, level-up triggers — but
the parameters that differ are intentional pedagogy: different scoring
curves (constant 100 vs `100 + difficulty*20`), different SRI metadata
schemas, different timing (1500ms vs 1200ms delays, 0.92× vs 0.85×
speed multipliers), and meaningfully different UI presentation (falling
sentence vs conveyor item vs verb pair vs compound word). A base class
would need 10+ override hooks and a parameterised UI builder. Each
file already sits comfortably ≤ 1100 LoC and reads standalone — four
readable copies beats `base + override × 4` indirection.

### [-] 5b. Delete orphan files (`bubble_math_game.dart`)
Skipped by user — leave the orphan in place.

---

## Already done in the audit passes

- `flutter analyze` clean on both projects (was 1662 + 581 issues → 0)
- 35 + 228 compile errors fixed (including the `package.flutter/`
  typo, a Python file mistakenly saved as `.dart`, nullable `S.of`
  accesses, mis-migrated `DragTarget.onAcceptWithDetails` callbacks)
- 657 `withOpacity` + 268 web-equivalent migrated to `withValues`
- `gameSkillMap` reconciled — `solar_panel` / `solarpanel_game`,
  `grid_filler` / `grid_filler_game` keys aligned
- `magic_triangles` and `path_finder` now use `recordLevelWin`
- 6 voc games now wire `recordLevelWin` (`word_memory`,
  `word_builder`, `word_type_whirl`, `wortbaumeister`, `grossstadt`,
  `grossschreib`); `word_type_whirl` got a proper game-over dialog
- voc gzip decompression routed through `compute()` (mobile isolate,
  web microtask boundary)
- `late Timer` races in `asteroid_math` + `bubble_math` fixed
- `arithmancer_crosswords` controller leak fixed (`.stop()` →
  `.dispose()`)
- `signal_triangulation` was firing `recordLevelWin` per guess —
  now fires once per puzzle
- `cryptex_lock_breaker` had no fail path at all — now records on
  back-press during active game + has a proper Try Again dialog
- voc `VocabularyService.initialize()` rethrows on failure +
  treats empty vocab as hard error (was silently leaving games with
  no content)
- voc `AudioService` print → debugPrint stub (release-safe)
- space_math `main.dart` global init order fixed (was relying on
  Dart lazy top-level finals)
- `verbtrenner_game` wired into voc — class renamed, route added,
  menu card added, `gameSkillMap` entry added,
  `recordLevelWin` call added

---

# Audit 2026-05-30 — Test coverage + Cargo-Loader generator

Second audit pass, focused on (a) the near-total absence of functional unit
tests and (b) the Cargo-Loader puzzle generator producing dull levels.

## A. Test coverage

State at the time of the audit:

- 100 `lib/` Dart files, ~79k LoC of game logic. **5 test files, all of them
  contract guards** (text-grep checks: menu key ↔ `gameSkillMap`, every game
  calls `recordLevelWin`, provider-tree completeness). **Zero functional tests
  of game logic.**
- CI (`.github/workflows/ci.yml`) already runs `flutter analyze --fatal-infos`
  + `flutter test`, so any tests we add are enforced on every push/PR.
- Large amount of logic is **pure Dart and unit-testable today** (most just
  need a seeded `Random` and tolerance for `debugPrint`). The blockers for a
  few are `DateTime.now()` / `SharedPreferences.getInstance()` called inline
  (testable via `SharedPreferences.setMockInitialValues`; time needs a small
  DI seam to test boundaries precisely).

### [x] T1. Seed a real unit-test suite (one file per game + architecture)
Fan-out of 33 workers (25 games + 8 core modules), each writing & self-
verifying one test file under `test/logic/` (core) or `test/games/` (games).
Policy: real logic unit tests where pure logic exists; robust widget
build/smoke test otherwise; **skip-with-reason** (no flaky red) where a screen
can't be instantiated in a harness (audio/TTS/sqflite/asset coupling) and has
no extractable logic. Workers do **not** modify `lib/`. Highest-value targets:
- `game_provider` — `reportOutcome` / `canAdvanceToNextLevel` / 3-wins-AND-
  mastery gate (the highest-risk untested logic; already DI-friendly).
- `sri_service` — SM-2 EF adjustment, interval scheduling, mastery criteria.
- `streak_service` — day-boundary rollover, idempotency, persistence.
- `cognitive_profile_service`, `progress_service`, `math_problem`,
  `game_outcome`, `skill_category`.
- Generator/solver invariant tests: codebreaker, arithmancer crosswords,
  magic-triangle, robot-path, **starloader**, gridlock, arithmancer-duel.

### [x] T2. Add `DateTime Function() getNow` injection to time-dependent services
`SriService` and `StreakService` call `DateTime.now()` inline, so day-boundary
/ interval behavior can't be tested deterministically. ~5-line constructor
seam each (default `DateTime.now`) unlocks precise tests. Deferred until after
T1 so we don't churn the freshly-written tests.

## B. Cargo-Loader (StarLoader) — Sokoban generator overhaul

Player-facing "Cargo-Loader" = `star_loader_game.dart` (StarLoader), a standard
**push-only Sokoban** (`_movePlayer` :354, win = all targets covered :448). The
math framing is cosmetic; boxes carry no numbers. Live generator is
`starloader_level_generator.dart` (reverse-play DFS). Root causes of boring
levels:

1. **Broken difficulty metric** — `score = boxSwaps × displacement`
   (`:432`), where `displacement` = summed **Manhattan distance to goal**
   (`:478`). This *rewards boxes being far from goals in a straight line* — the
   most boring case (shove straight across open floor). Measures nothing about
   direction changes, box-on-box interaction, or forced ordering.
2. **No real solver** — true optimal push count is never computed, so the
   generator can't filter for difficulty and the in-game efficiency bonus
   (`:503`) is based on a meaningless number.
3. **Greedy single-best state** biases toward the long-straight-slide config.
4. **Rooms too open** (`_generateTopology` :296 stamps blobby masks incl. 2×2);
   deadlock detection that existed in a dead variant was dropped.
5. **Box count barely grows** (`manager.dart:206`: +1 ever, caps at 4).
6. **The 64 hand-verified baked levels in `assets/data/starloader_levels.json`
   are never loaded** — manager says "ignore assets" (`manager.dart:27`) and
   only serves freshly-generated weak levels. JSON shape already matches
   `LevelDatabase.fromJson`; asset already declared in pubspec.
7. **Trivial fallback** — `_createFallbackLevel` (:566) ships a straight-line
   push corridor when generation fails `maxTries`.

`dart_csp` is **not** applicable (Sokoban is sequential planning, not CSP).

### Fix plan (the "start with starloader" work) — DONE
- [x] **S2. Push-optimal solver.** New `starloader_solver.dart`: A* over
  (normalised-player-region, box-config) with dead-square precomputation +
  frozen-box deadlock pruning, bounded node budget. Pure Dart. Returns the true
  minimum push count and proves unsolvable/budget-exhausted.
- [x] **S3. Real difficulty metric + acceptance.** Generator now runs the solver
  on each candidate: rejects proven-unsolvable levels (the buggy reverse-play
  could emit them — one such level was even in the shipped asset) and stores the
  TRUE optimal push count in `optimalMoves`. New `minOptimalPushes` gate +
  bounded `solverNodeBudget`; budget-exhausted levels are accepted as "probably
  hard." Fallback level is now solver-verified too.
- [x] **S1. Load the baked pool.** `StarLoaderLevelManager.initialize()` now
  loads `assets/data/starloader_levels.json` via `rootBundle` and merges it into
  the pool (deduped by `contentHash`, in-memory). Runtime generation is
  fallback-only.
- [x] **Offline re-bake.** New `tool/bake_starloader_levels.dart` re-scored the
  64 shipped "verified" levels with the solver and **dropped 1 unsolvable + 49
  trivial** (only 14 survived — ~78 % of the old pool was junk by the real
  metric, which had stored `optimalMoves` up to 1269 for ≤25-push levels), then
  topped each grade up to 20 fresh solver-verified levels (**80 total**) with
  honest, grade-scaled push counts: g1 6–9, g2 9–16, g3 13–20, g4 17–39.
- [x] **S4. Scale box count** with level progression in
  `_generateRealTimeEntry`; the trivial straight-corridor fallback is now
  solver-verified (reports real pushes) rather than shipping a fake score.
- [x] **S5. Tests.** `test/games/starloader_solver_test.dart` (deterministic
  push counts, corner/frozen deadlocks, dead-square map, + an asset-integrity
  guard asserting every shipped level is solvable, `optimalMoves` == solver
  optimal, and above its grade floor). The pre-existing generator-invariant test
  still passes and now implicitly covers solvability.
- [x] **Dead code.** Removed the 6 dead StarLoader CLI scripts + the unused
  alternate model from `lib/` (`starloader_level_generator_1/2`,
  `starloader_generator_debug`, `starloader_puzzle_debug`,
  `test_starloader_levels`, `starloader_db_generator`,
  `models/starloader_level_database`). 0 live importers; superseded by the new
  solver + bake tool.

Result: `flutter analyze` clean, full suite **354 tests** passing.

## C. Cargo *Bay* Arranger — separate generator (Tetris-with-numbers)
Distinct game (`cargo_bay_arranger_game.dart`), confusingly similar name. Its
piece generator drew **every cube value as i.i.d. uniform noise**, decoupled
from `targetSum` and the 13 math-bonus types — so the entire math/bonus layer
the game is built around almost never fired.
- [x] `CargoPiece.random` now does **target-/sequence-aware value sampling**
  behind optional params (`targetSum`, `sequenceChance`, `targetSumChance`;
  defaults preserve the legacy uniform behaviour and the test's 3-arg
  signature). With probability it emits a piece as a consecutive run (feeds the
  consecutive/sequence bonuses) or clusters values around `targetSum/gridCols`
  (so a row can actually hit the target). All values stay within `[min,max]`.
- [x] `_spawnNewPiece` activates it (`sequenceChance: 0.30, targetSumChance:
  0.30`) for the current/next/hold rolls via a new `_rollPiece()` helper.
- [x] Tests added proving consecutive runs, target-sum clustering, and that a
  degenerate range still produces only its single value.

## D. Dead code in `lib/`
- [x] StarLoader dead scripts removed (see the StarLoader section above):
  `starloader_level_generator_1/2`, `starloader_generator_debug`,
  `starloader_puzzle_debug`, `test_starloader_levels`, `starloader_db_generator`,
  `models/starloader_level_database`.
- [x] `services/test_robot_path_generator.dart` (CLI scratch, 0 live importers)
  removed. A sweep for `test_*` / `*_debug` files shipping as app code now
  comes back empty.

## E. Vercel deployment — git-integrated build was failing
The `spacemath` Vercel project (→ `space-math-academy.vercel.app`) builds
Flutter on Vercel from GitHub. Branch builds errored after ~50s:
`Could not find a file named "pubspec.yaml" in
https://github.com/CrispStrobe/dart_csp.git 6520ed2...`.
- Root cause: `pubspec.lock` pinned `dart_csp` to commit `6520ed2`, which **no
  longer exists** (the repo was force-pushed in the dartCSP → CrispStrobe/
  dart_csp migration). Local builds kept working from the pub cache; Vercel's
  clean clone could not fetch the dangling SHA.
- [x] Fixed by pinning `dart_csp` to the stable **`v2.2.0`** tag in
  `pubspec.yaml` and re-resolving `pubspec.lock` (resolved-ref now `9739dc4`,
  a live commit). `flutter analyze` clean (no v2.1→v2.2 API breakage).
- [x] **Consolidated to one project with git auto-deploy.** Connected the
  GitHub repo to `spacemathacademy` (`vercel git connect`), added a
  version-controlled `vercel.json` (clone Flutter 3.38.5 → `pub get` → `build
  web --release`, output `build/web`, SPA rewrite to `index.html`), and proved
  a push-triggered build goes live (full 3-min Flutter build, all assets 200,
  deep links 200). Then deleted the redundant `spacemath` project and retired
  `deploy.sh` (manual CLI deploy superseded by git auto-deploy). Canonical URL:
  **`spacemathacademy.vercel.app`**; pushes to `main` now auto-deploy.
- [x] Captured screenshots from the web build (home, Mission Control menu,
  Asteroid Hunter gameplay) into `docs/screenshots/` and added a Screenshots
  section + live-demo link to `README.md`.

## Incidental bugs fixed
- [x] `robot_path_generator.dart` :259-260 — `math.max(3, math.min(3, …))`
  always collapsed to 3 (path-length scaling was dead). Fixed to the intended
  ~20%-80% obstacle band; robot_path invariant tests still green.
- [x] `math_problem._generateFromConfig` subtraction threw `RangeError`
  (`nextInt(0)`) when a custom range had `min == max` (settable via the
  settings sliders) and subtraction was active — crashed every game that calls
  `generateProblem`. Fixed by normalising the range + guarding the degenerate
  case; regression test in `test/logic/math_problem_generate_test.dart`.
- The 20-retry mastered-problem fall-through is intentional (avoids an infinite
  loop); left as-is — not a bug.

---

# 2026-08-01 — Mission grading & performance ratio

Missions graded every completed task green regardless of how it was played,
and mission task lists were a uniform random draw over all 48 games (duplicates
included). Fixed in one pass:

- [x] **Normalized performance ratio.** New
  `lib/features/games/models/performance.dart`: a 0..1 "fraction of a perfect
  run" with the product grade bands (≥85% green, >70% yellow, >40% orange, else
  red) and shared builders (`Perf.fromMistakes/fromAttempts/fromMoves/
  fromRatio/fromTime/fromLives/combine/penalize/forLoss`) so one mistake costs
  about the same in every game. `GameOutcome` gained an optional `performance`
  (+ `progress` on `.loss`); `GameProvider` exposes `lastOutcome`,
  `lastPerformance` and an `outcomeCount` seam so callers can tell a finished
  round from a player who backed out. Stars now derive from performance when a
  game reports one — raw scores scale with grade/level and aren't comparable.
- [x] **47 of 48 mission games instrumented** with the signal each one actually
  has: wrong submissions, attempts used, moves vs. the optimum (sokoban,
  rush-hour, atomix, robot path, lights-out and the whole fill-the-grid
  family), accuracy, lives/health, Nim-optimality (asteroid duel), time vs. par
  (minesweeper). Counters reset when a game starts a new round in-place. Only
  `cryptex_lock_breaker` is unmeasured — continuous dials have no discrete
  mistake to count; unmeasured wins fall back to 0.85.
- [x] **Mission generation reworked.** No duplicate mini-game, 2-3 calculation
  games + 2-3 puzzles (4-6 tasks by grade), always at least one hands-on
  signature puzzle, codeword letters spread across tasks, and each task set at
  the level the player has reached in *that* game.
- [x] **Mission UX.** Grade-coloured task tiles with percentage badge, verdict
  word and a threshold-ticked bar; a legend spelling out the scale; real
  localized game names + skill/level subtitle; free task order; replay to
  improve (best result kept); failed attempts shown and retryable; overall
  mission rating on the summary. New EN/DE strings.
- [x] **Tests.** `test/logic/performance_test.dart` and
  `test/logic/mission_generator_test.dart` (37 tests) lock the grade bands, the
  builders, and the no-duplicates / balanced-mix / signature-puzzle contracts.
- [x] Guarded the two unguarded `debugPrint`s in `grid_filler_game.dart` that
  were failing the `O1` optimization contract.

Result: `flutter analyze lib test` clean, full suite **877 passing, 2 skipped**;
the only remaining failure is the pre-existing `O7` asset-size contract.

---

# 2026-08-02 — Plan cleanup pass

Picked off the well-scoped open items from `PLAN.md`.

- [x] **App icon under budget (O7).** `assets/images/app_icon.png` re-encoded
  1342 KB → 441 KB at the same 1024×1024 (pngquant q85-100 + a lossless
  pngcrush pass, RMSE 1.25 % — visually identical, verified side by side, no
  alpha chunk introduced so the iOS `remove_alpha_ios` flow is unaffected).
  `assets/images/` is bundled wholesale, so this is ~900 KB off the download,
  not just a green test. The full suite now passes with zero failures.
- [x] **Cargo Bay Arranger: seeded 7-bag.** New `CargoShapeBag` deals a
  shuffled permutation of all seven tetrominoes before reshuffling, so no shape
  droughts; `CargoPiece.random` gained optional `shapeIndex` and `random`
  params (legacy 3-arg call unchanged) making runs reproducible. 8 tests cover
  bag fairness, the max-gap bound, seed reproducibility and shape selection.
- [x] **Gridlock generator moved out of `lib/` + honest solver result.**
  `gridlock_puzzle_generator.dart` was a `dart:io` CLI shipping as app code →
  `tool/`. Its BFS now returns a `GridlockSolveResult` that distinguishes
  *proven unsolvable* from *budget exhausted* (the old `null` conflated them,
  discarding good deep puzzles), the budget went 15 000 → 250 000 nodes, and
  exhausted candidates get one retry at 4× budget before being dropped. The
  generator's progress output reports the two counts separately.
- [x] **Two more CLI harnesses lifted out of app code.** (`dart:io` in `lib/`
  does *not* break a web build — verified with a full `flutter build web
  --release` — but its APIs throw at runtime on web, and a terminal front-end
  is dead weight in the bundle either way.)
  `starloader_level_generator.dart` (a live runtime service) carried a CLI
  `main()` + ANSI renderer + `dart:io` → `tool/starloader_level_cli.dart`.
  `arithmancer.dart` (the live duel engine) carried an interactive
  stdin/stdout front-end → `tool/arithmancer_cli.dart`; the engine gained a
  `PvPGame.humanTurnHandler` hook plus public `generateAllPossibleResults` /
  `executeResult` / `grantBattleReward` / `drawCards` wrappers so a front-end
  can drive it without reaching into privates. `lib/` now has exactly one
  `main()` and no unexpected `dart:io`.
- [x] **O5 contract generalized** from a single hardcoded filename to two
  rules: `lib/main.dart` is the only entry point in `lib/`, and `dart:io` may
  only be imported by an explicit platform-gated allowlist. Both new rules
  caught real violations (the three CLIs above).
- [x] **cryptex_lock_breaker graded.** The last mission game without a quality
  signal now counts committed dial settings (one per drag gesture or drop)
  against the minimum any solver needs — the number of dials that don't start
  on their solution value. All 48 mission games now report a real performance
  ratio.
- [x] **Version bumping discipline (#18).** New `tool/bump_version.dart`
  (`major|minor|patch|build`, `--set`, `--dry-run`) always advances the build
  number stores reject reusing, plus a `version-bump` CI job that fails a PR
  touching `lib/`, `assets/` or `pubspec.yaml` without a version change, plus
  10 unit tests including a guard that the pubspec version stays parseable.
