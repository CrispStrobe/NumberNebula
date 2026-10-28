# NumberNebula: current state and agent handover

Updated 2026-10-28. Public repository: [CrispStrobe/NumberNebula](https://github.com/CrispStrobe/NumberNebula).
Live app: [numbernebula.vercel.app](https://numbernebula.vercel.app).

## Current state (2026-10-28)

`main` is at version **1.5.45+61**: the app code evaluated below
([`b84a927`](https://github.com/CrispStrobe/NumberNebula/commit/b84a927), 1.5.44+60)
plus the removal of all age and child-audience statements. The owner ruled on
2026-10-28 that the app is for math learners of all ages; see lane U item 1 in
REMAINING_WORK.md and `test/docs/no_age_targeting_test.dart`. Since the Molecule
baseline (1.5.39+55, described below), these changes have landed:

- [PR #68](https://github.com/CrispStrobe/NumberNebula/pull/68) (`1672c66`): store
  text only. The App Store rejected 1.4.10 under guideline 2.3.8 because the
  subtitle said "for kids". See [release readiness](docs/release-readiness.md).
- [PR #67](https://github.com/CrispStrobe/NumberNebula/pull/67) (`a6de6a2`): the
  48-game practice/Üben rewrite, with 5 failing native tests fixed before merging.
  See [practice rules](docs/practice-rules-and-difficulty.md#status-2026-10-28).
- `8b39a33`: fixes the web live test that had failed since PR #67's first head
  (live-region text matched twice). `b84a927` reverts a `Podfile.lock` change
  swept into that commit.

Evidence at `b84a927`: [CI](https://github.com/CrispStrobe/NumberNebula/actions/runs/40700725093)
and [pure calibration](https://github.com/CrispStrobe/NumberNebula/actions/runs/40700724702)
passed. The [web build, live tests and deploy](https://github.com/CrispStrobe/NumberNebula/actions/runs/40700724838)
passed build and live tests, including the fixed practice-lesson test. Its
`deploy` and `pages` jobs were still running when this was written: open the run,
confirm both succeeded and that the live site serves `b84a927` or a later
docs-only head with the same app code (`git diff --stat b84a927 <head> -- lib
web assets pubspec.yaml` is empty), and record that
here before calling the web deployment current. PRs #67 and #68 were merged with admin
rights before their required checks finished; the checks above ran afterwards on
`main`.

Store: iOS 1.4.10 (14) is **Waiting for Review** again (resubmitted 2026-10-27).
TestFlight has **1.5.45 (61) for both iOS and macOS**, built and uploaded locally
on 2026-10-28 from `68de24c`/`8c68fa4` (same app code; 1.5.44 (60) iOS before it). Internal testers have it, and
external testers get it after Beta App Review. macOS 1.4.10
is live. The details, and a release path that does not need GitHub's macOS
runners, are in [docs/release-readiness.md](docs/release-readiness.md).

The only open PR is the Gridlock repair, [PR #66](https://github.com/CrispStrobe/NumberNebula/pull/66).
It is a draft at `8ea0975`, version 1.5.40+56. It fails 2 native tests, conflicts
with `main` in `HANDOVER.md` and `pubspec.yaml`, and needs a version above
1.5.45+61. Its exact next steps are in lane D of [REMAINING_WORK.md](REMAINING_WORK.md).

## Preceding verified main publication

[Relic Assembly / PR #64](https://github.com/CrispStrobe/NumberNebula/pull/64)
merged at exact source
[`dd6e5d2`](https://github.com/CrispStrobe/NumberNebula/commit/dd6e5d22397401b360878190ec6963c00fd02203),
version **1.5.38+54**. Strict analysis and 1,823 native cases passed, including all
39 Relic and 45 Hull cases, zero skips. Generation passed 60,400 cases across all
48 games; Flutter capture/replay passed 864 cases. Its full GitHub artifact
browser report has 45 passed and one existing Chromium loader skip, zero observed
retries. Actual raw reports and source/test identities were independently checked.

The tested GitHub artifact was first published with synthetic checkout marker
`656db57`; its complete source tree equals the merged head. Its historical
[canonical proof](https://numbernebula-8bz2qrmmg-crispstrobes-projects.vercel.app/hosted-proof.json)
records two passing Relic checks across Chromium/WASM and Firefox/JavaScript,
zero skips/retries and stable compiled hashes. Report protection applies. The
shipping wrapper was compiled separately; its different build was not substituted
for that browser-tested GitHub artifact.

Merged-main [CI](https://github.com/CrispStrobe/NumberNebula/actions/runs/39235051563),
[calibration](https://github.com/CrispStrobe/NumberNebula/actions/runs/39235051487)
and [web/deployment](https://github.com/CrispStrobe/NumberNebula/actions/runs/39235051481)
**all succeeded**. Both actual main browser reports were independently verified:
each has **45 passed, one existing Chromium loader skip and zero observed retries**.
The main capture report passed 864 cases across 48 games. That workflow published
its own tested main artifact, runtime marker **`dd6e5d2`**, to
[numbernebula.vercel.app](https://numbernebula.vercel.app). Its five compiled-file
hashes, version and isolation headers matched the canonical site after completion.
The older `656db57` report remains historical evidence for its own artifact.
The obsolete queued PR-preview deployment was canceled after the earlier verified
publication; that aggregate is canceled, not green. The preceding Hull main
checks in [PR #63](https://github.com/CrispStrobe/NumberNebula/pull/63) also succeeded.

## October 18 integration

Implemented on October 19: **1.5.39+55** (since superseded; see Current state); see the [Molecule audit](docs/molecule-builder-round-audit.md).
The preceding implemented version is **1.5.38+54**, [PR #64](https://github.com/CrispStrobe/NumberNebula/pull/64); see the [Relic Assembly audit](docs/relic-assembly-round-audit.md).
Its 39 focused cases include held-pointer isolation for generation-error retry.
Its final 39-case source is verified above; earlier 38-case results do not validate that follow-up.
The preceding Hull follow-up is **1.5.37+53**, [PR #63](https://github.com/CrispStrobe/NumberNebula/pull/63);
use its exact-source native, browser and deployment evidence rather than assuming a queued check passed.
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

There are focused round suites for **36 registered games**, with **12** remaining
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
verify its repair PR before treating it as a green baseline. Relic Assembly (C)
has an [implementation under validation](docs/relic-assembly-round-audit.md).
Molecule Builder (D) is [implemented under validation](docs/molecule-builder-round-audit.md).
The next screen audit is Gridlock (D), followed by the unchanged D/E/F games. H has a
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
| Molecule Builder | [Round audit; exact-source validation required](docs/molecule-builder-round-audit.md) |
| Relic Assembly | [Round audit; exact-source validation required](docs/relic-assembly-round-audit.md) |
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

The current store state is in [docs/release-readiness.md](docs/release-readiness.md)
(checked 2026-10-28). Recheck it with `tool/asc/asc.py status`, or the `status`
lane of `submit.yml`, before any store action: review states change without a
commit. Uploads and review submissions remain deliberate manual actions (lane R).
Current source version and current store build are separate facts.

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
