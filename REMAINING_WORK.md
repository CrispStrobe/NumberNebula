# Executable next-work lanes

Updated 2026-10-19. Read [HANDOVER.md](HANDOVER.md) first for the green shipping
baseline and completed audits. These are scoped next steps, not claims that the
named games are broken. Each round-audit batch below is independent; implement
one game per PR rather than combining an entire batch.

## Player availability

### Games withheld from players

None. `debugOnlyGames` is empty. The source of truth is
`lib/features/missions/data/game_pool.dart`; if a game is withheld later, list
its exact key and release criteria here. Audit lanes below do not withhold games.

### Fixed and shipping

All 48 registered games are available in the menu and missions. The 36 implemented
focused round audits are mapped in [HANDOVER.md](HANDOVER.md); historical browser
play-throughs are archived in [game-quality notes](docs/game-quality-history.md).
The remaining 12 focused audits are additional hardening work, not a broken-game list.

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

## A — Compact puzzle audits: implemented

Star Forge, Chrono Repair and Orbital Towers have focused round suites. Their
October 17 work was repaired in [PR #58](https://github.com/CrispStrobe/NumberNebula/pull/58):
restore epochs/terminal flags, exhausted full boards, reduced motion, real input,
large text and retry. Retain these tests when changing the screens; do not treat
the former skipped acceptance cases as evidence. Use PR checks to verify the
exact integrated head before release.

## B — Remaining arithmetic and grid-input rounds

**Status:** Implemented; retain exact-source evidence from [PR #61](https://github.com/CrispStrobe/NumberNebula/pull/61).
See the [Puzzle Math round audit](docs/puzzle-math-round-audit.md).
Codebreaker now has a [dedicated round audit](docs/codebreaker-round-audit.md);
retain its real-pointer, inventory, terminal, retry, navigation and motion tests.
Arithmetic Square, Crossword, KenKen, Magic Triangles and Number Walls are covered
by the integrated #58 suites. The Codebreaker capture failure in #55 was traced to a negative tray-padding
count when more than eight answer occurrences were needed; PR #58 fixes that
boundary with finite-domain padding and unit regressions. Its broader round
lifecycle audit is implemented in the Codebreaker repair.

Retain the Puzzle Math pool/answer conservation, old input across restore,
one-time outcomes, timer expiry, persisted mistakes, real retry and phone tests.
Verify its exact-head native, generation and both-engine deployment evidence
before treating the lane as validated. Preserve generator choices.

## C — Remaining construction rounds

**Status:** Relic Assembly is implemented under validation; verify its
[round audit](docs/relic-assembly-round-audit.md) before treating lane C as a green
baseline. Hull Plating's follow-up is [PR #63](https://github.com/CrispStrobe/NumberNebula/pull/63).
No further construction screen remains once the Relic repair is verified.
Alien Tribunal, Hive Station and Xenobiology Lab have integrated #58 suites.
Manual-submit games must retain correct-but-unsubmitted saved answers as playable;
correctness alone is not a terminal marker. Zero-attempt Hive saves offer retry
without replaying a loss.

Retain Hull's physical inventory, frozen drag orientation, placement-instance
removal guards, owned routes and motion checks. Relic adds both real drag and
select/tap placement, physical-index bijection, editable incorrect saves,
round/placement ownership, silent terminal restores, owned dialogs, phone controls
and eight controlled async-generation cases through the production await path.
Its 31 original-API cases and eight seam cases are separate evidence scopes:
old-source comparisons exclude `seam:` names because the baseline lacks that seam.
Run all 39 on the repair, preserve the two existing meaningful layout tests,
and verify full native/generation/both-engine/deployment checks on the exact
pushed source and merged main. Keep generators, free rotations and scoring.
Next audit Molecule Builder in D, with one game per PR.

## D — Planning and bundled-level rounds

**Status:** Gridlock is a [candidate under validation](docs/gridlock-round-audit.md),
version **1.5.40+56**, with 25 prepared original-API tests and five database seams.
Run those remotely, compare final original-API bytes against baseline, complete
missing resume/navigation/fallback/phone cases, and verify exact-head/full-main
publication before closing the audit. Its initial 13-case baseline has two positive
controls and eleven overlapping assertion failures, not eleven independent bugs.
Molecule is [implemented](docs/molecule-builder-round-audit.md); its merged-main
native/generation/artifact-browser checks passed, with deployment still pending.
Retain its 51 original-API contracts and five loader seam cases; verify the exact
repair head, shared session mixin, native/all-game/browser/deployment checks
before treating it as green. Preserve completed Undo +2, coherent interrupted
snapshots, authored levels/progression/fallback and existing score/quality reference.

**Remaining games/screens:** `space_station_gridlock_game.dart`,
`star_loader_game.dart`, `robot_path_game.dart`, `solarpanel_game.dart`.

Start with Gridlock, using `shipsFromBoard` and a legal authored board such as
`GRID_1`. Independently check occupancy after every fixture step. Ships have no
IDs: restore fresh physical instances under the same puzzle ID, list order and
selected index, then continue a held pointer and verify only fresh input works.
Normal pan updates commit one cell immediately; blocked or cross-axis input must
not count. There is no move allowance: `minMoves` is the retained quality reference,
not an exhaustion rule or a proved optimum for per-cell counting.

Exercise real exit input, one-time outcomes, terminal capture and silent solved
restoration. Replace the round during async loading, exit motion and the delayed
result; obsolete completions, tracker writes and retained result actions must not
affect the new board or covering route. Test current Next and retry, disposal,
initial/mid-animation reduced motion, effect lifetime and English/German short
phones at text scale 2. Independently assert fallback nonoverlap as well as bounds;
existing fallback tests check bounds/player count only. Reproduce any failure
before changing that path. Preserve all bundled boards/order, tracker semantics,
scoring and existing fallback algorithms.

Verify bundled-level identity and solution references survive snapshots. Use the
shared A–F acceptance and one game per PR. For Robot distinguish the proven
candidate command BFS from the legacy estimate. **Done:** shared acceptance plus
bundled solution replay; approximate references stay unchanged without separate
evidence from G.

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
D–F cover the 12 registered games without implemented dedicated round audits.
Legacy screens such as `bubble_math_game.dart` and `creature_forge_game.dart`
are not extra registered-game lanes; do not delete them as incidental cleanup.

## G — Structural difficulty review and larger samples

**Status:** Bounded live Robot replay and report-integrity checks implemented; larger matched sampling remains open. Human conclusions depend on lane H.
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

**Status:** [Protocol prepared](docs/human-playtest-protocol.md); actual measurement
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

**Status:** [Draft preparation available](docs/release-readiness.md); current store state requires authorized
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
