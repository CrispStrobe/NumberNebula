# NumberNebula: current state and agent handover

Updated 2026-10-19. Public repository: [CrispStrobe/NumberNebula](https://github.com/CrispStrobe/NumberNebula).
Live app: [numbernebula.vercel.app](https://numbernebula.vercel.app).

## October 18 integration

Current implemented version: **1.5.37+53**; see the [Hull Plating audit](docs/hull-plating-round-audit.md).
The initial Hull repair is [PR #62](https://github.com/CrispStrobe/NumberNebula/pull/62), version **1.5.36+52**.
A follow-up guards same-round plate replacement; its new exact-source checks are required.
The preceding verified version is **1.5.35+51**, [PR #61](https://github.com/CrispStrobe/NumberNebula/pull/61).
The preceding verified version is **1.5.34+50**, [PR #60](https://github.com/CrispStrobe/NumberNebula/pull/60).
The preceding verified baseline is **1.5.33+49**, [PR #59](https://github.com/CrispStrobe/NumberNebula/pull/59).
The earlier [PR #58](https://github.com/CrispStrobe/NumberNebula/pull/58)
repairs the October 17 audits and integrates the work originally proposed in
#55, #56 and #57. Its checks verify that earlier integration; use the second-pass
build evidence for the current source. Historical green runs do not validate a
later head.

There are focused round suites for **34 registered games**, with **14** remaining
to audit. All 22 newly skipped acceptance cases from the October 17 changes have
been re-enabled, the Arithmetic Square placeholder has been replaced by actual
input/save/inventory/terminal tests, and a coverage contract rejects skipped
acceptance cases in these eleven added suites. The two historical generator smoke
skips are also re-enabled in the second-pass suite with their existing bounds.

The integration keeps correct but unsubmitted manual answers playable, resets
round identity and terminal effects on restoration, conserves duplicate tray
values, and makes a full incorrect board lose at its exhausted budget. A correct
last legal move can still win. Existing scores, pars, generators, A/B selection
and fallback implementations are retained. The dynamic Alien card border remains
animated while its static card contents are reused.

The [Lane G evidence review](docs/structural-difficulty-review-G.md) now separates
historical summary integrity from four live seeded Robot generation/command
replays. Its real Flutter wrapper and pure workflow step are present; unsupported
sample/proof claims have been withdrawn. This is not human difficulty calibration.

Puzzle Math (B) is implemented in [PR #61](https://github.com/CrispStrobe/NumberNebula/pull/61); see its
[round audit](docs/puzzle-math-round-audit.md). Hull Plating (C) is implemented in its [round audit](docs/hull-plating-round-audit.md);
verify its repair PR before treating it as a green baseline. The next screen audit
is Relic Assembly (C), followed by the unchanged D/E/F lanes. H has a
[prepared playtest protocol](docs/human-playtest-protocol.md); R has a
[draft readiness document](docs/release-readiness.md). Neither claims device
measurements or a new store release.

## Codebreaker round audit

The [Codebreaker audit](docs/codebreaker-round-audit.md) adds real input,
finite tray accounting, repeated-symbol and duplicate-value checks, restore
isolation, terminal saves, one-time outcomes, guarded retry/navigation and
reduced-motion coverage. English/German phone controls are exercised at doubled
text size. Codebreaker retains both existing generator paths and symbol autofill.
Use its repair PR's exact-source validation and deployed checks as evidence;
implemented tests alone do not establish a passing build.

## Second-pass regression audit

The [change-by-change audit](docs/october-17-regression-audit.md) records additional
missed defects in retry flags, retained controls, restored drop effects and Star
Forge rendering. Its expanded tests require exact state and outcome assertions,
and run against the previous implementations as negative controls. Browser smoke
coverage opens all eleven changed games in both release engines. Passing totals
are evidence for those contracts, not proof that every possible defect is absent.

The [published audit evidence](https://github.com/CrispStrobe/NumberNebula/pull/59)
identifies the tested source, negative controls, full-suite results, all-game
samples and changed-line coverage. Its results are recorded only after validation passes and retain links to the
validated build report. An older deployment or a missing report does not validate
the current source. Production redeployments may omit supplementary audit assets;
the linked PR retains the evidence and exact tested commit. When GitHub's runner queue is excessive, reuse a tested artifact
or use a configured remote validation container; do not wait indefinitely or run
large jobs on a busy shared host.

## Start here

1. Read this file, then [REMAINING_WORK.md](REMAINING_WORK.md) for executable task lanes.
2. Fetch current `main`; inspect the working tree before changing anything. The
   evidence below applies to the named commit, not automatically to later commits.
3. Choose one lane and one game or workload. Read its actual screen, shared
   generator, session mixin and existing tests before identifying a defect.
4. Preserve working algorithms and their selectable A/B and fallback paths.
   Add a regression demonstrating the defect before changing gameplay behavior.
5. Run substantial validation on GitHub Actions. Check load, available memory
   and output/cache disk space before local jobs; avoid overlapping heavy jobs.
6. Push only intended changes. Check the exact PR head, then the merged-main
   head and deployment workflows. Record public proof links and remaining limits.

Private machine configuration, credentials and operational notes do not belong
in this repository. Documentation uses repository-relative paths and public URLs.

## Historical verified baseline (October 5)

App version **1.5.22+38** at
[`8eaf252bc86dfc7e44bb219613e60f2bd3450e7c`](https://github.com/CrispStrobe/NumberNebula/commit/8eaf252bc86dfc7e44bb219613e60f2bd3450e7c),
after [PR #46](https://github.com/CrispStrobe/NumberNebula/pull/46).
That documentation-only update did not change the app version.

| Evidence on that exact main commit | Result | Public run |
| --- | --- | --- |
| Flutter analysis, focused regressions, reduced motion and retained rendering fallbacks | Passed; full suite 1,471 passing, two existing skips | [CI](https://github.com/CrispStrobe/NumberNebula/actions/runs/37241615028) |
| Pure Dart generation, validators and localized hints | 48 registered games; 60,400 cases; zero failures | [Calibration](https://github.com/CrispStrobe/NumberNebula/actions/runs/37241614982) |
| WASM and JavaScript fallback, fixture capture/replay, Chromium/Firefox, production deployment and hosted checks | Passed; 864 Flutter capture/replay cases | [Web and deployment](https://github.com/CrispStrobe/NumberNebula/actions/runs/37241614977) |

All 48 registered games are available. `lib/features/games/game_registry.dart`
and `lib/features/missions/data/game_pool.dart` are the coverage authorities.
Older audit documents catalog 49 games; that includes legacy material and
must not be interpreted as 49 registered games. Generation and session coverage
for all games does not mean every interactive edge case has been audited.

## Completed focused round audits

These games have dedicated round regressions in `test/widgets/`. The October 18
rows refer to the integrated repair; consult PR #58 for its exact merge/check state. The latest shared suite covers them together; do not reimplement these
fixes just because an older planning document predates them.

| Games | Merged public change |
| --- | --- |
| Hull Plating | [Round audit](docs/hull-plating-round-audit.md) |
| Puzzle Math | [Round audit](docs/puzzle-math-round-audit.md) |
| Codebreaker | [Round audit](docs/codebreaker-round-audit.md) |
| Signal Triangulation | [#29](https://github.com/CrispStrobe/NumberNebula/pull/29) |
| Perspective Puzzle; Block Counter | [#30](https://github.com/CrispStrobe/NumberNebula/pull/30) |
| Void Crossing | [#31](https://github.com/CrispStrobe/NumberNebula/pull/31) |
| Circuit Repair; Warp Fold | [#32](https://github.com/CrispStrobe/NumberNebula/pull/32) |
| Star Chart Scan | [#33](https://github.com/CrispStrobe/NumberNebula/pull/33) |
| Cube Scanner | [#34](https://github.com/CrispStrobe/NumberNebula/pull/34) |
| Cryptex Lock Breaker | [#35](https://github.com/CrispStrobe/NumberNebula/pull/35) |
| Grid Filler | [#36](https://github.com/CrispStrobe/NumberNebula/pull/36) |
| Launch Sequence | [#37](https://github.com/CrispStrobe/NumberNebula/pull/37) |
| Sector Painter | [#38](https://github.com/CrispStrobe/NumberNebula/pull/38) |
| Ion Chain | [#39](https://github.com/CrispStrobe/NumberNebula/pull/39) |
| Gravity Well | [#40](https://github.com/CrispStrobe/NumberNebula/pull/40) |
| Comm Relay | [#41](https://github.com/CrispStrobe/NumberNebula/pull/41) |
| Vault Cracker | [#42](https://github.com/CrispStrobe/NumberNebula/pull/42) |
| Galactic Market | [#43](https://github.com/CrispStrobe/NumberNebula/pull/43) |
| Crew Manifest | [#44](https://github.com/CrispStrobe/NumberNebula/pull/44) |
| Nebula Matrix | [#45](https://github.com/CrispStrobe/NumberNebula/pull/45) |
| Dark Matter Grid | [#46](https://github.com/CrispStrobe/NumberNebula/pull/46) |
| Star Forge; Chrono Repair; Arithmetic Square; Orbital Towers; Alien Tribunal | [Audit repairs #58](https://github.com/CrispStrobe/NumberNebula/pull/58) |
| Crossword; KenKen; Magic Triangles; Number Walls; Hive Station; Xenobiology Lab | [Integrated audits #58](https://github.com/CrispStrobe/NumberNebula/pull/58) |

The last five audits cover old controls and drag payloads surviving restoration,
outcomes reported once, exhausted saves, recoverable mistakes, reduced motion,
queued feedback, immutable learning records and large-text phone layouts.
Launch Sequence now charges drag distance, matching its inversion-based par.
Dark Matter Grid retains the generator's approximate move reference; it does
not claim that reference is a proven minimum.

## Generation, rendering and difficulty boundaries

All registered games use shared pure Dart generation, including bundled level
selection where that is the shipping path. See [pure Dart calibration](docs/pure-dart-calibration.md)
for commands, seeds, frozen fixtures, validators and proof limitations.
`pubspec.yaml` and `tool/pure_dart/pubspec.yaml` both pin
[`dart_csp` v2.2.0](https://github.com/CrispStrobe/dart_csp/tree/v2.2.0).
Upstream tasks are in [its integration lanes](https://github.com/CrispStrobe/dart_csp/blob/main/doc/numbernebula-integration.md).

Candidate/legacy generators remain selectable. Square also retains constructive
and pruned CSP candidates. Cargo retains its original piece stream alongside
reachable-row assistance. Grades 1–2 retain baseline behavior where specified.
Do not replace sequential planning with CSP merely to use the dependency.

`ASTEROID_RENDER_PATH`, `SPACE_BACKGROUND_RENDER_PATH` and
`WORMHOLE_RENDER_PATH` retain `cached` and `legacy` rendering paths.
Measurements support allocation/rebuild improvements and bounded session writes;
they do not establish a physical-device FPS or battery improvement. Browser RAF
is browser scheduling, not Flutter raster time. Firefox CPU-renderer observations
are not representative of a child's phone.

The workload heuristic is untrained and explicitly low confidence. The recorded
67 structural review flags are not failed boards or measured child difficulty.
No physical-device profiling or child playtest data are available. Do not infer
ages, solve times, success rates or fair reward thresholds from generator CPU
cost; do not automatically retune child-facing pars.

## Release boundary

Web deployment is verified above. No new App Store upload or release is claimed.
The previously reported 1.4.10 iOS “Waiting for Review” and macOS “Pending
Developer Release” are historical, unverified now. Recheck both platforms in
App Store Connect before deciding what can be released. Current source version
and current store build are separate facts. Release preparation is lane R in
[REMAINING_WORK.md](REMAINING_WORK.md).

## Evidence and document ownership

- [REMAINING_WORK.md](REMAINING_WORK.md): open task ownership, steps and acceptance.
- [PLAN.md](PLAN.md): execution order and dependencies.
- [REMAINING_ISSUES_DETAILED.md](REMAINING_ISSUES_DETAILED.md): current risks and reproduction expectations.
- [docs/optimization-validation.md](docs/optimization-validation.md): validation history and technical contracts.
- [docs/pure-dart-calibration.md](docs/pure-dart-calibration.md): reproducible generation and workload evidence.
- [HISTORY.md](HISTORY.md) and [archived game-quality notes](docs/game-quality-history.md): completed work. [GAME_BALANCE_AUDIT.md](GAME_BALANCE_AUDIT.md)
  is a historical catalog, not a current defect list.

When a lane ships, update this baseline only after exact-head checks complete,
move the outcome to history, and keep the open board honest. CI artifacts can
expire; preserve fixtures needed for longitudinal comparisons without publishing
profile data or secrets.
