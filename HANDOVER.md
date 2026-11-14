# NumberNebula: current state and agent handover

Updated 2026-11-14. Public repository: [CrispStrobe/NumberNebula](https://github.com/CrispStrobe/NumberNebula).
Live app: [numbernebula.vercel.app](https://numbernebula.vercel.app) (mirror:
[GitHub Pages](https://crispstrobe.github.io/NumberNebula/)).

This file is the current state only. Open work is in [REMAINING_WORK.md](REMAINING_WORK.md);
completed work and earlier handover sections are in [HISTORY.md](HISTORY.md).
Working rules are in [AGENTS.md](AGENTS.md).

## Current state

`main` is at app version **1.6.5+71** (merge of #75, `9c0d7f2`). On that
head [CI](https://github.com/CrispStrobe/NumberNebula/actions/runs/43620238047)
(including `kompass-aot`) and
[calibration](https://github.com/CrispStrobe/NumberNebula/actions/runs/43620238147)
passed; the [web build and deployment](https://github.com/CrispStrobe/NumberNebula/actions/runs/43620237990)
was queued at the time of writing, so recheck that both web hosts serve 1.6.5 (71).
The `v1.6.5` [release run](https://github.com/CrispStrobe/NumberNebula/actions/runs/43620255734)
uploaded both builds.

| Platform | App Store | TestFlight |
|---|---|---|
| iOS | 1.5.45 (61) Waiting for Review since 2026-11-05 (release type Manual) | 1.6.5 (71), internal testers (1.6.4 (70) external) |
| macOS | 1.5.45 (61), released 2026-11-10 (replaced 1.4.10) | 1.6.5 (71), internal testers (1.6.4 (70) external) |

**1.6.5 (71)** fixes a release-build crash when opening any KOMPASS practice or
check session (see HISTORY.md, 2026-11-14) and adds the compiled-build KOMPASS
test (`integration_test/kompass_open_test.dart`, CI job `kompass-aot`). Widget
tests run in JIT and cannot see AOT-only failures; keep that job green. On
Linux `flutter drive` reports success even when the test fails, so the job
greps for the test's `KOMPASS-E2E: done` marker; keep that check.

Store states were checked on 2026-11-11 and change without a commit; recheck
with `tool/asc/asc.py status`. Both 1.6.4 builds passed Beta App Review. The next
store step is to submit 1.6.4 after iOS 1.5.45 is approved and released; the
owner submits and releases. Do not withdraw the iOS 1.5.45 submission. Store
text must not target an age, grade or child audience
(`test/docs/no_age_targeting_test.dart`; guideline 2.3.8 rejection history).
Release mechanics are in [docs/release-readiness.md](docs/release-readiness.md).

### What the app contains

- **48 free-play games**, all available. `lib/features/games/game_registry.dart`
  and `lib/features/missions/data/game_pool.dart` are the coverage authorities.
  Older audit documents catalog 49 games, which includes legacy material.
- **48-game practice/Üben rewrite** ([PR #67](https://github.com/CrispStrobe/NumberNebula/pull/67));
  see [practice rules](docs/practice-rules-and-difficulty.md).
- **KOMPASS 4 mathematics learning path** ([PR #71](https://github.com/CrispStrobe/NumberNebula/pull/71),
  [PR #72](https://github.com/CrispStrobe/NumberNebula/pull/72)): eight labs
  (saved recipe-1 rounds keep their recipe; new rounds use the harder recipe 2),
  a **144-task / 298-part bilingual bank** with practice, check and rehearsal
  pools, and **120 original German paper tasks / 249 parts / 240 points** in six
  20-task papers from the kompass4 repository. Content loader version
  **2.1.0+k4.1.0.0**. The original papers keep `contentUse: original` and do not
  enter the main pools or count as verified course evidence. Their answer
  mappings were checked (no key was wrong) and accept unit words and aliases, but
  `reviewStatus` stays `draft` until a teacher signs them off. Details:
  [implementation](docs/kompass4-implementation.md), [coverage](docs/kompass4-coverage.md),
  [reasoning expansion](docs/kompass4-reasoning-expansion.md),
  [import tooling](tool/kompass/README.md).

## Start here

1. Read this file, then [REMAINING_WORK.md](REMAINING_WORK.md) for executable task lanes.
2. Fetch current `main`; inspect the working tree before changing anything. The
   evidence above applies to the named commit, not automatically to later commits.
3. Choose one lane and one game or workload. Read its actual screen, shared
   generator, session mixin and existing tests before identifying a defect.
4. Preserve working algorithms and their selectable A/B and fallback paths.
   Add a regression demonstrating the defect before changing gameplay behavior.
5. Run substantial validation on GitHub Actions. Check load, available memory
   and output/cache disk space before local jobs; avoid overlapping heavy jobs.
6. Push only intended changes. Check the exact PR head, then the merged-main
   head and deployment workflows. Record public proof links and remaining limits.
   When a lane ships, update this file, move the detail to HISTORY.md and keep
   REMAINING_WORK.md honest.

Private machine configuration, credentials and operational notes do not belong
in this repository. Documentation uses repository-relative paths and public URLs.

## Completed focused round audits

These games have dedicated round regressions in `test/widgets/`. The latest
shared suite covers them together; do not reimplement these fixes just because
an older planning document predates them.

| Games | Merged public change |
| --- | --- |
| Gridlock | [Round audit, #66](docs/gridlock-round-audit.md) |
| Molecule Builder | [Round audit](docs/molecule-builder-round-audit.md) |
| Relic Assembly | [Round audit, #64](docs/relic-assembly-round-audit.md) |
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

## Document map

- [REMAINING_WORK.md](REMAINING_WORK.md): open work, order, risks and acceptance.
- [HISTORY.md](HISTORY.md): completed work, newest first, and earlier handover sections.
- [docs/](docs/): per-game round audits, [release readiness](docs/release-readiness.md),
  [pure Dart calibration](docs/pure-dart-calibration.md),
  [optimization validation](docs/optimization-validation.md),
  [game-quality notes](docs/game-quality-history.md) and the KOMPASS records.
- [docs/archive/](docs/archive/): the original design briefs, game ideas, theming,
  implementation spec and the June balance audit. Historical; verify current
  source before treating anything there as open work.
