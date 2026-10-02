# Automated game testing and calibration

All 48 registered games now also generate puzzle content with the Dart SDK
alone, using the app's shared generators. See [pure Dart calibration](pure-dart-calibration.md)
for the isolated dependency package, 60,400-board every-level sweep, seeded regressions and
estimated difficulty model.

All 48 registered games have a headless Flutter fixture capture and save/reopen
check in `test/widgets/all_games_sessions_test.dart`. The current board hint
engine and completion solver are Flutter-free, so captured boards can be
replayed with the Dart SDK alone.

## Capture every game

From the repository root, with Flutter on PATH:

```sh
dart run tool/calibrate_games.dart --capture --require-all \
  --grades 1,3,6 --levels 1,10 --samples 3 --output calibration-report.json
```

Use `--flutter /path/to/flutter` when the SDK is not on PATH. Add `--game KEY`
without `--require-all` to inspect one game. This captures 864
boards (48 games × 3 grades × 2 levels × 3 samples), exercises English/German
hints, checks snapshot round trips, and reopens the actual game from storage.
Capture failures stop the command with a nonzero exit code. Boards are written
to `calibration-report.json.fixtures.jsonl` for exact subsequent replay.

For a broader grade sweep, use `--grades 1,2,3,4,5,6`. Generation samples are
random; freezing the resulting fixtures makes replay reproducible. This is not
a globally seeded generator benchmark.

A configured checkout is required (its package configuration is created by
`flutter pub get`); replay itself uses the Dart runtime and no Flutter widgets.

## Replay with pure Dart

```sh
dart run tool/calibrate_games.dart --input calibration-report.json.fixtures.jsonl \
  --require-all --output calibration-replay.json
```

The report includes board size, hidden cells where exposed by the model,
snapshot bytes, hint timing, model reference moves, and available move/time
allowances. Missing fields and unknown optima remain null. Hint generation must
leave the board unchanged. A verified move means the specific hint algorithm
validated it; other games offer a current-board strategy rather than a proven
optimal next move.

With at least ten samples in matching mechanic/language strata at neighboring
levels, the report flags large changes in workload, hidden cells or model
reference moves for review. Sparse strata are marked for more samples. It does not automatically
change difficulty. Generator readiness includes the widget harness and polling;
solver execution time is not a measure of children's solving time. Existing
rule/generator tests complement these snapshots; this harness does not prove
uniqueness or optimal solvability of every generated board in every game.

## CI and web measurements

`.flutter-version` pins the SDK used by GitHub Actions and `tool/build_web.sh`.
The web workflow captures the six grade/level combinations separately, then
merges their fixtures for a cross-level report. Artifacts retain the report and
boards for 14 days. These are configured checks, not evidence that a remote CI
run has already passed.

Playwright's `performance.spec.mjs` records cold menu startup, warm first frame,
static and moving-game storage writes, long tasks where supported, browser RAF
intervals, resource transfer bytes, and available JS heap size. It retains raw
JSON measurements. The hosted-performance workflow accepts either a Vercel URL
or a GitHub Pages project URL, including its path. GitHub Pages may use the JS
fallback because its response headers differ from Vercel; the report records
cross-origin isolation instead of requiring identical hosting capabilities.

Local browser command, after building `build/web`:

```sh
cd tool/web_live_test
npm ci --no-bin-links
node node_modules/@playwright/test/cli.js install chromium firefox
node node_modules/@playwright/test/cli.js test tests/performance.spec.mjs
```

For an existing deployment, set `BASE_URL=https://host/project/`. Vercel
automation bypass is exchanged only with a Vercel preview hostname or an
explicit `VERCEL_BYPASS_HOST`; it is not sent to GitHub Pages. Browser RAF
measures browser scheduling, not Flutter raster time. Resource transfer sizes
may be zero for cache hits or cross-origin resources without timing headers.
There is no physical battery, iPhone, or Mac measurement in these reports.

The Sokoban CLI also imports the same pure Dart engine as the app, so its
seeded generation, replay and difficulty metrics cannot drift into a separate
implementation. The triangle solver and Number Walls fallback are likewise
Flutter-free. Native Star Loader generation runs outside the UI isolate; web
`compute` still executes on the browser thread. Search deadlines bound work,
but fresh web generation can still cause a noticeable pause. When the bounded
search falls below its existing push target, the normal game can use a verified
bundled board that meets that target. Forced generation in debug mode still
reports the best effort.

For GitHub Pages, build with the correct project path, for example
`bash tool/build_web.sh --base-href /project/`.

## Remaining calibration evidence

No devices or human playtest data are currently available. Native frame/memory
profiling and age-appropriate difficulty calibration remain open. Automated
results can identify bugs, expensive hints, weak structural progression, and
suspicious allowances; human sessions are needed to set fair child-facing pars.


## Launch and Square candidate comparisons

`--algorithm legacy` keeps the working baselines. Arithmetic Square additionally
accepts `--square-path pruned` to select its previous CSP candidate, or
`--square-path constructive` to select the new operator-compatible solve.
Auto retains both as fallback paths. CI offers the same choices, and exported
summaries label paths separately. See [the focused results](focused-calibration-results.json)
and [the calibration notes](pure-dart-calibration.md) for the 24,000-board
comparison and the exact-swap Launch progression.


The Launch/Square follow-up verification passed clean app/tool analysis, 411 generation
checks, 1,370 algorithm/fixture-reader checks, and all 1,132 Flutter tests
(two skipped). The release WASM build passed in 285.7 seconds. All eight browser
checks passed: startup, deferred loading, and playable Launch/Square boards in
both Chromium/WASM and Firefox/JavaScript. GitHub workflow configuration was
validated locally; no remote CI run or deployment is claimed.

## Cargo reachable-row candidate

Higher grades now have a four-variable `dart_csp` candidate that adjusts a newly
generated preview's values for a reachable exact-sum row. The original 7-bag,
value sampler and legacy algorithm remain available. Grades 1–2 keep their
original generation. Assisted attempts use a 30% chance; missing opportunities
or solver failure retain the baseline piece. Promotion preserves the piece
already advertised in the preview. Reset/restore invalidates pending generation
and row-clear callbacks, and transitional boards are not saved.

Completed checks: 4,040 pure row-generation assertions, 24,000 synthetic A/B
cases with zero validation failures, 22 targeted Flutter tests, and clean
app/Cargo-tool analysis. Independent replay executes rotation, horizontal moves
and hard drop using actual cube values. See
[the results](cargo-row-calibration-results.json). Forced assistance found a
reachable target on 6,000/6,000 planted boards versus 716/6,000 for the baseline;
the 30% variant found one on 2,272/6,000. These are deliberately planted
opportunities, not natural-game win rates or measured child difficulty. A later
piece can change the board before a preview is played.

The latest Cargo WASM build was terminated (compiler exit -15); the broader
Cargo session run reported no tests ran. Neither is a passing check. The earlier
Launch/Square build and browser evidence above predates Cargo. Remaining builds,
full tests and large sweeps belong on GitHub Actions. The pure-calibration
workflow includes Cargo regressions and per-grade A/B artifacts, limits its
matrix to two concurrent jobs, and uses two generation workers per runner.
The CI and web workflows cover Flutter tests, analysis, WASM and browsers; all
three can be dispatched manually once the changes are available remotely.
No new remote run or deployment has been performed.

## Shared VPS resource policy

Check load averages, available RAM and free space before substantial local work.
Use local work for edits, inspection and small targeted checks. Run large
calibration, full suites, WASM compilation and browsers on GitHub Actions, or
Kaggle when available. Never overlap heavy local jobs. The 2026-10-02 resource
check found four CPUs, peak load averages 18.72/15.45/9.10, only 2.7 GiB free on
the root volume and 6.0 GiB on the toolchain volume. Large outputs belong on the
storage volume or remote artifacts, not the root filesystem. Preserve other
users' processes and data.
