# NumberNebula: current state and agent handover

Verified 2026-10-05. Public repository: [CrispStrobe/NumberNebula](https://github.com/CrispStrobe/NumberNebula).
Live app: [numbernebula.vercel.app](https://numbernebula.vercel.app).

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

## Verified shipping baseline

App version **1.5.22+38** at
[`8eaf252bc86dfc7e44bb219613e60f2bd3450e7c`](https://github.com/CrispStrobe/NumberNebula/commit/8eaf252bc86dfc7e44bb219613e60f2bd3450e7c),
after [PR #46](https://github.com/CrispStrobe/NumberNebula/pull/46).
The documentation update does not change the app version.

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

These games have dedicated round regressions in `test/widgets/` and merged
fixes. The latest shared suite covers them together; do not reimplement these
fixes just because an older planning document predates them.

| Games | Merged public change |
| --- | --- |
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
