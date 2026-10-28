# Executable next-work lanes

Updated 2026-10-28. Read [HANDOVER.md](HANDOVER.md) first for the current state,
the shipping baseline and completed audits. These are scoped next steps, not claims
that the named games are broken. Each round-audit batch below is independent;
implement one game per PR rather than combining an entire batch.

## Next up (in this order)

1. **Confirm the web deployment of `b84a927`** (lane R, step 1). Small; blocks
   calling `main` green.
2. **Watch both reviews** (lane R, step 2): iOS 1.4.10 App Review and Beta App
   Review for build 61 (build 60 was submitted too). React only to Apple's messages; do not resubmit
   proactively.
3. **Store listing fixes** (lane S): "20+" → 48, screenshots, truncated cards.
   Text changes need no app build.
4. **Release tooling** (lane T): build numbers, fastlane lanes, local release
   script. This stops the next release from going through what 2026-10-27/28 did.
5. **Gridlock PR #66** (lane D): fix 2 failing tests, rebase, and bump above
   main's version (main is 1.5.45+61, so 1.5.46+62 or higher; builds up to 61
   are taken).
6. Then the remaining round audits (B–F), lane L validation and the product
   ideas in lane U, as capacity allows.

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

**Status:** Molecule is [implemented under validation](docs/molecule-builder-round-audit.md).
Retain its 51 original-API contracts and five loader seam cases; verify the exact
repair head, shared session mixin, native/all-game/browser/deployment checks
before treating it as green. Preserve completed Undo +2, coherent interrupted
snapshots, authored levels/progression/fallback and existing score/quality reference.

**Remaining games/screens:** `space_station_gridlock_game.dart`,
`star_loader_game.dart`, `robot_path_game.dart`, `solarpanel_game.dart`.

**Gridlock already has a draft: [PR #66](https://github.com/CrispStrobe/NumberNebula/pull/66)**
(branch `fix/gridlock-round-isolation`, head `8ea0975`, 4 commits on base `32383b4`,
version 1.5.40+56). Its web build, live test and deploy passed; native
`analyze-and-test` fails 2 cases in `test/widgets/space_station_gridlock_round_test.dart`:
`Gridlock: en 390x500.0 text2 keeps actual legal drag and current result Next reachable`
and the same for `de`. To finish it:
1. Check out the branch and run that test file locally. Reproduce both failures
   and read the assertion: whether the drag is not legal or Next is not
   reachable at 390×500 with text scale 2.
2. Fix the layout or the round logic, not the test, unless the test asserts
   something the design does not promise. Note how the shared onboarding overlay
   was handled in lane L (pinned footer, whole-card scroll only above text scale
   1.3) if the cause is similar.
3. Merge `origin/main`. Resolve `HANDOVER.md` by keeping main's "Current state"
   section and adding one Gridlock line, and `pubspec.yaml` by setting a version
   **above main's version** (1.5.45+61 on 2026-10-28, so for example 1.5.46+62).
   Read `pubspec.yaml` on `main` first. Build numbers up to 61 are taken in App
   Store Connect.
4. Mark the PR ready only when `analyze-and-test`, `build` and `live-test` pass
   at the exact head; then merge and verify on `main`.
The scope below is what PR #66 was written against; use it to review the PR.

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

**Status (2026-10-28):** see the "Current state" table in
[docs/release-readiness.md](docs/release-readiness.md). iOS 1.4.10 (14) is in
review; 1.5.44 (60) is in TestFlight; macOS 1.4.10 is live. **Owner files:**
`.github/workflows/release.yml`, `submit.yml`, `fastlane/`, `tool/asc/asc.py`,
`pubspec.yaml`.

1. **Web deployment of `b84a927`.** Open the
   [web run](https://github.com/CrispStrobe/NumberNebula/actions/runs/40700724838).
   `build` and `live-test` already passed; `deploy` and `pages` were still
   running at hand-over. If they passed, check that the live site serves that commit, or a later docs-only head with the same app
   code (`git diff --stat b84a927 <head> -- lib web assets pubspec.yaml` is empty)
   (the app's runtime marker / `hosted-proof.json`, as earlier entries in
   HANDOVER.md did), then record the run link in HANDOVER.md "Current state". If
   it failed, read `--log-failed`, reproduce, fix, and push a test-only or
   version-bumped change as appropriate.
2. **App Review for iOS 1.4.10.** Check with `tool/asc/asc.py status`.
   - If approved: release stays manual (`AUTOMATIC_RELEASE = false`). Ask the
     owner whether to release 1.4.10 or to replace it with 1.5.x first. Do not
     press release on your own.
   - If rejected again: read the message in App Store Connect. Apple's review
     history for this app includes 4.3(a) (spam/template) and an Extended Review
     warning, so any reply or resubmission needs the owner's explicit go-ahead.
     For metadata-only issues, fix `fastlane/metadata`, then run
     `asc.py push-metadata --write` and `asc.py resubmit`.
3. **Beta App Review for builds 60 and 61.** When approved, external testers are
   notified automatically, and nothing else is needed. If rejected, fix the reason
   and upload a new build number (62+).
4. **Next store version (1.5.x).** Once 1.4.10 is resolved, the next App Store
   version should ship the current `main` (at least 1.5.44 (60) or a newer
   build), on both iOS and macOS so that the macOS listing also loses the old
   "kids" text. Steps:
   - Create the version in App Store Connect.
   - Update `fastlane/metadata/*/release_notes.txt`; it still describes 1.4.10.
   - Push the metadata, attach the build, and submit manually.
   The 4.3(a)/Extended Review caution in `submit.yml` still applies.
**Done:** each platform's state is recorded with date and evidence in
`docs/release-readiness.md`. Keep account IDs, keys and machine instructions out
of repo docs.

## S — Store listing and screenshots

**Status:** Ready. Mostly no app build needed. **Owner files:** `fastlane/metadata/`,
`fastlane/screenshots/`, and the game cards in the menu screen (see
`lib/features/games/game_registry.dart` for the card text sources).

1. **Fix the game count.** `fastlane/metadata/{en-US,de-DE}/promotional_text.txt`
   and both `description.txt` files say "20+"/"über 20" mini-games; there are 48
   (`game_registry.dart`). Change it to 48, and keep the audience wording as "math
   learners of all ages" / "Mathe-Lernende jeden Alters". **Never** reintroduce
   "kids"/"Kinder" or school grades as the target audience in the name, subtitle,
   keywords, screenshots or icon: that was the 2.3.8 rejection. Promotional text
   can be changed at any time; the description changes with the next version.
   Apply with `tool/asc/asc.py push-metadata --write` only while a version is
   editable, and only with the owner's go-ahead while a review is pending.
2. **Check two possible layout defects** seen in `fastlane/screenshots/en-US/iphone-*.png`
   (2868×1320 landscape):
   - a black rounded pill along the left edge of both shots;
   - on the home screen, a red-outlined counter pill showing only "1", with an
     empty area where an icon or label should be.
   Reproduce on an iPhone simulator in landscape. Decide whether each is a
   capture artifact or a real safe-area/layout bug, and fix real bugs with a
   widget test at 2868×1320 and 844×390.
3. **Retake screenshots that show gameplay.** All 6 current shots show home or
   menu screens. Capture 3–4 distinctive games mid-round (for example the Comm
   Relay cipher wheel, Cargo Loader, 3D Block Counter, Magic Triangles), English
   and German, on the device sizes App Store Connect requires. Avoid any text
   implying a child audience. Uploading screenshots is a store action: `appstore_submit`
   skips screenshots on purpose, so upload them deliberately (`deliver` with
   screenshots, or the console).
4. **Truncated card descriptions.** Menu cards cut descriptions mid-word on phones
   (for example "Each side of the triangle must sum to th…"). Either add short
   one-line taglines per game (en/de l10n) or show the full text on long-press.
   Test at 390×844, at 844×390 and at text scale 2. This is a shipping-code
   change and needs a version bump.
**Done:** metadata says 48 games everywhere; screenshot defects are explained or
fixed; new screenshots are uploaded with owner approval.

## T — Release tooling

**Status:** Ready. **Owner files:** `tool/asc/asc.py`, `fastlane/Fastfile`,
`.github/workflows/release.yml`, `submit.yml`, `tool/bump_version.dart`.
Background: the 2026-10-27/28 release had to bypass CI. Read the "Local release
path" in [docs/release-readiness.md](docs/release-readiness.md) first.

1. **Build numbers from App Store Connect.** Builds were uploaded from a branch
   (59) while `main` still said 55, so `pubspec.yaml` drifted behind the store. Add
   a check, in `release.yml` before the build or in `asc.py`, that fails when the
   `pubspec.yaml` build number is ≤ the highest build in App Store Connect, and
   prints the next free number. Do not auto-commit version bumps from CI.
2. **Fastfile `status` lane.** It crashes listing submission items: `undefined
   method review_submission_items` (Spaceship). Use the
   `/v1/reviewSubmissions/{id}?include=items` API, or drop the item listing. It
   also prints no builds, because it filters by the pubspec version only; list
   the latest builds instead.
3. **Fastfile `appstore_submit` lane.** It cannot resubmit an existing
   `UNRESOLVED_ISSUES` submission, and it fails opaquely on new required
   age-rating attributes. Either port `asc.py resubmit` (resolve item → submit)
   into the lane, or document `asc.py` as the supported path and make the lane
   refuse with a clear message. It also takes the version from `pubspec.yaml`, so
   add an optional `app_version`/`build_number` input to `submit.yml` instead of
   requiring a temporary branch with an edited pubspec.
4. **Local signing.** Document in `docs/release-readiness.md` (public-safe, no
   key or keychain names) how to check signing readiness before a local build
   (`security find-identity -v -p codesigning`, a `codesign` test on a scratch
   file). Ask the owner whether the distribution identity should move into a
   NumberNebula-specific keychain; today it lives in a keychain shared with
   another project, which was locked during the release. That is the owner's
   decision.
5. **`asc.py` follow-ups.** `testflight` sets only en-US "What to Test"; add de-DE.
   Add a `macos` option to `status`/`push-metadata`.
**Done:** a release can be checked, uploaded and distributed without the macOS
runner, and the CI path fails early with actionable messages.

## U — Product ideas for the "all ages" positioning

**Status:** Ideas; each needs an owner decision before implementation. The store
now says "for math learners of all ages", while the app's progression and copy
still center on grades 1–4 (for example "Grades 1–4 progression" was removed from
the store text, but in-app labels still say grade/Klasse in places).

1. **No age targeting (owner ruling 2026-10-28; done in 1.5.45+61).** The owner
   decided the app must state **no age ranges and no child/school audience
   anywhere**: "a 30-year-old may still want to play such games". The following
   were removed or rephrased:
   - the Settings "Target age" row and its strings;
   - the "About" text;
   - the "designed for primary-school learners/children" and "your child" wording
     in the in-app privacy dialog, `web/privacy.html` and `docs/privacy-policy.md`;
   - the web `index.html`/`manifest.json` descriptions.
   `test/docs/no_age_targeting_test.dart` now fails if age ranges ("8-12 years"),
   "for kids/children", "primary school", "young learners" or "your child" reappear
   in the translations, the privacy dialog, the web files or `fastlane/metadata`.
   Saying the app is *safe* for children (COPPA/GDPR-K) is allowed and kept.
   Remaining, optional: user-visible labels already say "Skill Level"/"Stufe". The
   internal `grade` parameter, saved keys and data must **not** be renamed (that
   would lose progress). Extend the guard test's file list if new user-facing
   text sources are added.
2. **Higher levels:** most generators accept grades up to 6 (calibration covers
   six grades). Evaluate exposing a fifth/sixth skill level for teens and adults,
   using lane G's structural evidence. One game per PR, legacy path preserved.
3. **Daily puzzle + streak:** one seeded puzzle per day across the 48 games, with
   the existing streak service (`lib/core/services/streak_service.dart`). Must stay
   offline and keep no accounts or analytics (the store says no data collection).
4. **More languages:** only en/de exist. French and Spanish would widen reach.
   This needs full `.arb` translations, store metadata folders and a localized
   rendering pass at text scale 2.
5. **Playtest signal:** with external TestFlight live, an opt-in, on-device-only
   "how hard was this?" prompt after a round could feed lane H. Do not collect or
   transmit data without an explicit privacy decision by the owner.

## Optional housekeeping

- `arithmatic_square` spelling: leave it unless a migration includes saved game
  keys, menu, missions, skill mappings, l10n and compatibility tests in one PR.
  A cosmetic rename that loses progress is unacceptable.
- Launcher icons: regenerate from `assets/images/app_icon.png` when the artwork
  actually changes; re-encoding unchanged source art is not a gameplay fix.
- Historical design briefs/specs describe original implementation tasks. Verify
  current source before treating their old assignments as open work.


## L — Practice rules and comparable difficulty

**Status (2026-10-28):** the 48-game lesson/hint rewrite is **merged** (PR #67,
`a6de6a2`, shipping in 1.5.44+60) and in TestFlight. Native CI and pure
calibration passed on `main`. See [the correction document](docs/practice-rules-and-difficulty.md),
especially "Status (2026-10-28)" for the overlay layout and test changes made at
merge time.

Remaining validation, in order:
1. Done: the web live test `deployment.spec.mjs › published practice lesson
   accepts an actual wrong and correct choice` passed on `main` at `b84a927`.
2. Run all three fixed-fixture contract checks and the 48 bilingual rendered
   wrong/correct lessons (`test/widgets/all_games_coaching_test.dart`). Verify
   shared live hints, restored states, pause and learning records. No text-presence
   test alone counts as mechanic validation.
3. Run the pure job's 360-profile comparison. Address the numeric audit's
   expression-display ambiguities with rendered regressions.
4. Extend the structural comparison to all 48 games. Keep independent tasks,
   dependency depth, distractions and time pressure separate. Make one
   reproducible tuning change at a time, keeping a selectable old path.
5. Wormhole: `MagicTriangleGenerationConfig` (in
   `lib/features/games/services/generation_configs.dart`) now caps guided boards
   at 6 per side for grade 6, level 10 (legacy reaches 7). If larger guided boards
   are wanted at the top levels, change the formula there. Keep
   `test/logic/practice_difficulty_test.dart` monotonic, and update the size
   expectation in `test/logic/magic_triangle_solver_test.dart`.
Actual child calibration still requires lane H's playtest protocol.
