# Executable next-work lanes

Updated 2026-10-05. Read [HANDOVER.md](HANDOVER.md) first for the green shipping
baseline and completed audits. These are scoped next steps, not claims that the
named games are broken. Each round-audit batch below is independent; implement
one game per PR rather than combining an entire batch.

## Shared acceptance for game lanes A–F

Read `lib/features/games/mixins/puzzle_session_mixin.dart`, the target screen,
its service/model, and the existing `test/games/` rules before editing. Use
`test/widgets/dark_matter_grid_round_test.dart`, `nebula_matrix_round_test.dart`,
`crew_manifest_round_test.dart` and `vault_cracker_round_test.dart` as examples.
Keep gameplay, generator paths, score formulas and allowances unless a reproduced
bug requires a documented behavior change.

For each game:

1. Trace generation, restore, input, outcome, retry, timers, async work and disposal.
   List any unguarded old-round or terminal-state callback with a reproduction.
2. Add focused tests using actual controls: pointer down before restore and up
   afterward; drag across restore; pending delayed/async completion after restore
   or disposal; duplicate win/loss; retry; partial and exhausted saves. Exercise
   applicable mechanics rather than inventing irrelevant checks.
3. Guard callbacks with round identity and terminal state. Key controls per round
   where Flutter can replace gesture callbacks. Carry round identity in drag
   payloads where old feedback overlays can reach new targets.
4. Keep recoverable mistakes editable and saved. `finishPuzzleSession()` followed
   by continued play needs `beginPuzzleSession()` and a fresh save. Correct but
   unsubmitted manual answers stay playable; already terminal saves must not
   replay rewards or learning outcomes. Capture terminal sessions as null.
5. Respect reduced motion initially and when toggled mid-animation. Stop/reset
   obsolete effects and queued feedback on restore/retry. Hoist unchanged board
   children out of animation builders; preserve useful feedback and fallbacks.
6. Test English/German, 390×844 and short 390×500 layouts at text scale 2 where
   applicable. Controls and retry dialogs remain reachable; scroll full content
   instead of clipping it. Preserve accessible labels and touch targets.
7. Add the focused test to `.github/workflows/ci.yml`; run focused tests, full
   Flutter CI, pure calibration and web/deployment checks remotely. A shipping
   code PR must increase the version/build according to CI. Documentation alone
   does not need a version bump. Record exact-head run links and any existing skips.

Dialog callbacks must check the actual dialog context is mounted, its route is
current, and its round is current before dismissing or retrying. Controllers
owned by text fields must survive until their old widgets detach. Tests must
separate game animations from normal framework button ripples.

## A — Next compact puzzle audit

**Status:** Ready. **Owner files:** screens `star_forge_game.dart`,
`chrono_repair_game.dart`, `orbital_towers_game.dart`; corresponding focused tests.
Screen paths in this document are relative to `lib/features/games/screens/`.

Start with **Star Forge**, then Chrono Repair, then Orbital Towers. Inspect their
win/loss paths, manual submissions and `_dropController` where present. Prove
whether restore cancels old input/effects, whether an exhausted save ends once,
and whether wrong answers preserve an editable snapshot. Retain Star Forge's
arm geometry, Chrono's clock transforms, and Orbital's visibility rules and
illustrated tutorial. **Done:** shared acceptance above for all three, with
no generator/scoring change unless independently justified.

## B — Arithmetic and grid-input rounds

**Status:** Ready; can run independently of A.
**Games/screens:** `arithmatic_square_game.dart`, `arithmancer_crosswords_game.dart`,
`kenken_game.dart`, `magic_triangles_game.dart`, `number_walls_game.dart`,
`codebreaker_game.dart`, `puzzle_math_game.dart`.

Start with Arithmetic Square; test number-pool conservation, old cell/palette
callbacks, drag payload identity, manual versus automatic completion, budget
exhaustion and restored mistakes. Repeat only applicable cases for each game.
Keep legacy/candidate/constructive/pruned generation choices intact. **Done:**
shared acceptance and independent rule validation for each changed game.

## C — Deduction, roles and construction rounds

**Status:** Ready. **Games/screens:** `alien_tribunal_game.dart`,
`hive_station_game.dart`, `xenobiology_lab_game.dart`,
`hull_plating_game.dart`, `relic_assembly_game.dart`.

Start with Alien Tribunal: role assignments, submit/retry, wrong-check persistence
and restored outcomes. For construction games, exercise placement, rotation,
controller/slider updates and stale drag overlays. Preserve unique-solution
checks and the existing rules; confirm feedback describes actual board state.
**Done:** shared acceptance, including phone layouts with all clues/controls
reachable. Do not weaken puzzle rules to make widget tests easier.

## D — Planning and bundled-level rounds

**Status:** Ready. **Games/screens:** `quantum_molecule_builder_game.dart`,
`space_station_gridlock_game.dart`, `star_loader_game.dart`, `robot_path_game.dart`,
`solarpanel_game.dart`.

Start with Molecule: interrupted moves, reset/restore, victory once and resumed
move counts. Check pending animations or search work cannot mutate a replacement
board. Verify bundled-level identity and solution references survive snapshots.
For Robot distinguish the proven candidate command BFS from the legacy estimate.
**Done:** shared acceptance plus bundled solution replay; authored order and
approximate references remain unchanged without separate evidence from lane G.

## E — Moving, timed and falling-piece rounds

**Status:** Ready. **Games/screens:** `asteroid_math_game.dart`,
`hyperdrive_gates_game.dart`, `planet_hopping_game.dart`, `path_finder_game.dart`,
`cargo_bay_arranger_game.dart`, `asteroid_field_navigator_game.dart`.

Start with Cargo: tick/hold/next-piece callbacks across reset, pause and disposal;
row outcomes and learning records; restored timers and piece queues. For moving
games retain physics and meaningful movement under reduced decorative motion.
For Navigator preserve mine rules and the timer/performance contract. Keep
cached/legacy render paths and assisted/original Cargo paths. **Done:** shared
acceptance plus deterministic timing/input regressions appropriate to each game;
no claims of improved device FPS from headless tests.

## F — Turn-based AI rounds

**Status:** Ready. **Games/screens:** `arithmancer_duel_game.dart`,
`asteroid_duel_game.dart`.

Start with Arithmancer: schedule an AI response, replace/restore the round, and
prove the response cannot land in the new state. Verify turn ownership, selected
cards, outcomes once, localized turn labels, pause/retry and disposal. Repeat
for Asteroid Duel. **Done:** shared acceptance and legal-move/AI regression tests.
A–F cover the 28 registered games without the completed dedicated round audits.
Legacy screens such as `bubble_math_game.dart` and `creature_forge_game.dart`
are not extra registered-game lanes; do not delete them as incidental cleanup.

## G — Structural difficulty review and larger samples

**Status:** Ready for CLI work; human conclusions depend on lane H.
**Owner files:** `tool/calibrate_games.dart`, `tool/compare_algorithm_paths.dart`,
`tool/compare_generators.dart`, `lib/features/games/services/felt_difficulty.dart`,
`docs/pure-dart-calibration.md`, `.github/workflows/pure-calibration.yml`.

1. Reproduce the 60,400-case baseline using the documented seed; retain frozen
   fixtures, summaries and per-stratum sample counts. Use workflow dispatch for
   larger runs; above 50 samples the matrix is bounded to two grade jobs with
   two workers each. Do not run the large sweep on a shared development host.
2. Review the recorded 67 flags by mechanic: Molecule 42, Robot 15, Warp Fold 4,
   Crossword 3, Solar 2, Gridlock 1. Verify those counts against the new report;
   repeated authored transitions are not independent defects.
3. Pick one transition, gather matched adjacent-level samples for both paths,
   replay solution evidence, and distinguish hidden-count/workload jumps from
   real invalid boards. Keep authored order unless solution paths support a change.
4. Report distributions, fallback rates, sparse strata and reference-proof status.
   Add a fixture-backed regression for a proven defect. Preserve per-case seeds
   and fixture replay for wall-clock-bounded generators.

**Done:** a public findings table with seed/commit/sample counts, flags explained
or still open, paired baseline/candidate results and zero validation regressions.
Do not automatically change child-facing pars or present software timing as
felt difficulty.

## H — Human difficulty and native-device evidence

**Status:** Instrumentation/research preparation is doable; actual measurement
is blocked by unavailable devices and playtest data.
**Owner files:** workload model, `Perf.*` call sites in screens, and calibration docs.

Prepare a consent-aware, minimal session protocol: relevant skill fluency,
board seed, attempts, hints, completion/abandonment and qualitative confusion.
Define how novice/fluent observations would validate the current ordinal bands.
List unvalidated pars for deduction, Cargo, Molecule, Navigator and Cryptex.
When devices/data become available, collect native frame/memory measurements
and analyze matched skill groups before proposing threshold changes.
**Done now:** a protocol and explicit missing-evidence table. **Done later:**
reviewed human/device results and separately justified changes. No synthetic
samples may stand in for children or physical-device measurements.

## I — Solver integration in dart_csp

**Status:** Ready for a narrow fixture/benchmark lane.
**Repository:** [CrispStrobe/dart_csp](https://github.com/CrispStrobe/dart_csp).
Follow [upstream integration lanes](https://github.com/CrispStrobe/dart_csp/blob/main/doc/numbernebula-integration.md).

Extract one deterministic Square/Crossword/Cargo workload, validate solutions
independently, benchmark baseline and opt-in candidate, and optimize only a
measured bottleneck. Land solver fixes upstream first; update both app dependency
pins together only after native/dart2js/WASM and all-game replay pass.
**Done:** reproducible upstream evidence, preserved fallback and downstream green
checks. Do not bundle a broad engine rewrite with app UI fixes.

## J — Browser rendering and hosting comparisons

**Status:** Ready remotely. **Owner files:** `tool/web_live_test/tests/performance.spec.mjs`,
rendering cache/painter files, `.github/workflows/hosted-performance.yml` and `web-perf.yml`.

Measure cached versus legacy on identical builds, seeds and browsers with warm-up
and repeated windows. Record renderer, cross-origin isolation, startup, storage
writes, allocations where available and RAF limitations. Compare the public
Vercel app and GitHub Pages with its correct base path. Keep preview bypass
restricted to the intended preview host and probes restricted to the app origin.
**Done:** raw measurements and a bounded claim supported by them, both fallback
paths green, no idle checkpoint regression and no swallowed application errors.
Physical battery and native raster conclusions depend on H.

## K — CI cost and documentation maintenance

**Status:** Ready. **Owner files:** workflow YAML and handover/planning docs.

Use recent run durations to identify duplicated setup or repeated focused suites.
Propose cache/matrix changes with before/after runner minutes; retain required
analysis, full regression, all-game generation, fallback and deployed-site gates.
Keep larger sweeps bounded and artifact retention explicit. Verify workflow
syntax and the exact resulting head remotely. Documentation must distinguish
configured jobs, successful historical runs and current green heads.
**Done:** measured lower cost without coverage loss, or a documented no-change
finding. Shared workflow/version files should have one integrator when lanes
run in parallel; do not let separate agents race on them.

## R — Store release readiness

**Status:** Public preparation is doable; current store state requires authorized
App Store Connect access. **Owner files:** `.github/workflows/release.yml`,
`.github/workflows/submit.yml`, `pubspec.yaml`, public release notes.

Read the two workflows and check platform/version/build mapping. Prepare release
notes for the current code and identify which tested commit would be uploaded.
Recheck current iOS/macOS review states and build numbers; the old 1.4.10 states
are not current evidence. Distinguish upload, review submission and developer
release, and use the authorized release policy before executing store actions.
**Done:** a verified platform-by-platform readiness table and, if authorized,
release outcome with public-safe notes. Keep account IDs, keys and machine
instructions out of repo docs. Web deployment is already green at the baseline.

## Optional housekeeping

- `arithmatic_square` spelling: leave it unless a migration includes saved game
  keys, menu, missions, skill mappings, l10n and compatibility tests in one PR.
  A cosmetic rename that loses progress is unacceptable.
- Launcher icons: regenerate from `assets/images/app_icon.png` when the artwork
  actually changes; re-encoding unchanged source art is not a gameplay fix.
- Historical design briefs/specs describe original implementation tasks. Verify
  current source before treating their old assignments as open work.
