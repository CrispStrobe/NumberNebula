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
The web workflow captures the six grade/level combinations on one runner and
analyzes the combined fixtures for a cross-level report. Artifacts retain the report and
boards for 14 days. The merged-main checks recorded below passed on GitHub Actions; artifacts
expire, so retain any fixtures needed for longer-term comparisons.

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

## Victory completion and reduced motion

Magic Triangles, Number Walls and Solarpanel use one-shot victory animations.
These must complete when Reduce motion is enabled, including a setting change
mid-animation. They use separate completion handling from repeating decoration:
completion runs after the frame, once per animation, and reset or disposal
invalidates a pending callback. Solarpanel chains its panel expansion and warp
through completion rather than an independent two-second timer. Full-motion
durations and scoring formulas stay the same.

Forward-only decoration in Magic Triangles, Path Finder, Planet Hopping and
Asteroid Math resumes forward-only after Reduce motion is disabled. Number
Walls also suspends its repeating operation decoration while motion is reduced.
This changes animation handling, not puzzle generation or difficulty calibration.
The real final-placement checks also cover an empty number pool: Number Walls
and Solarpanel keep a valid grid column count after the last number is used.
Solarpanel's victory actions wrap when their labels exceed the popup width.


## Signal Triangulation round callbacks

Auto-submit now owns a cancellable timer. Clearing or transmitting a guess,
restoring a board, resetting the round and disposing the screen invalidate the
old deadline. Each new complete guess retains the original 500ms delay.
Victory/failure dialogs retain their one-second delay, but cannot appear over a
restored or reset round. Header timers and in-progress collapse completion are
also scoped to the round; restored boards restart the header's original window.
Generation, deduction feedback, scoring and guess allowances are unchanged.

Reduce motion suspends both decorative pulse and radar scan; disabling it
resumes their original ping-pong and forward-only directions respectively.
Targeted widget regressions exercise real glyph/button input, delayed results,
restoration, disposal, header collapse and decorative frame updates. Heavy
checks run on GitHub CI.

## Spatial game round callbacks

Perspective Puzzle owns one cancellable feedback timer. Restore, regeneration,
disposal and completion invalidate its callbacks and pending generation results.
Correct feedback retains its one-second delay; retries and final failure retain
1.5 seconds. Completed rounds reject further answers and report one outcome.

Snapshots additionally retain the answer state and selected option. Restoring
pending feedback resumes its original delay while preserving attempts and lives;
it does not count the answer again. Older snapshots infer a pending correct
answer when correct attempts equal the turn index plus one, or pending failure
when lives are exhausted. Stable older snapshots still open for input.

Block Counter also invalidates its one-second wrong-answer reset and stale
generation results when replacing a board. A restored wrong highlight unlocks
retry while retaining the mistake count. A previous feedback timer cannot clear
the next round's answer. Generators, scoring formulas, 3D camera behavior and
existing algorithm/rendering A/B paths remain unchanged.

Focused regressions use real answer controls and JSON snapshots, covering normal
timing, pending-feedback restoration, older snapshots, terminal results,
disposal and generation superseded by restoration. GitHub CI runs these checks
before the full suite.

## Star Chart Scan round effects

Star Chart Scan scopes its 600 ms victory-dialog timer to the round. Restoring,
regenerating or disposing cancels it; completed boards reject further sweeps and
playable snapshots. Restoring also clears the old drag/highlight and success
animation, so late pointer events cannot find equations or count mistakes on a
replacement board. A cancelled pointer gesture clears its highlight without
counting a mistake.

Thirteen widget regressions use actual pointer gestures for forward/reverse sweeps,
normal/reduced-motion wins, dialog timing, terminal input, restoration, disposal,
partial progress and retained mistake grading, active-drag cancellation, and
play-again sessions. The generator, endpoint-based selection algorithm, scoring
formula and normal feedback delay remain unchanged. GitHub CI runs these checks
before the full suite, with calibration, builds and browser verification also
running remotely.

## Circuit Repair and Warp Fold round effects

Circuit Repair cancels a pending swap when selection changes, the player resets
or submits, a board is restored/generated, or the screen is disposed. Snapshots
store the selected pair's settled preview so reopening a game cannot display
pre-swap digits for a selected swap. Both win and exhausted-attempt states block
further submissions and duplicate outcomes. The existing generator, attempt
scoring and normal 400 ms swap duration remain in use; reduced motion completes
the preview through the shared cancellable one-shot helper.

Warp Fold uses the same cancellable completion path for its introductory fold
and replay. Previously replay never restored the answer options. Restoring or
replacing a round invalidates both fold completion and the two-second wrong-answer
retry timer and clears the old error snackbar. Retry removes its feedback at the
end of the two-second lock and starts a saveable session again while retaining mistakes and
the existing outcome policy. Optional pending-retry snapshots resume the original
feedback delay without recounting a mistake. Won rounds block further input and
playable snapshots. Normal folding retains its 1.5-second duration; reduced motion
returns the options after a deferred completion.

Focused widget regressions exercise real digit/option selections, preview timing,
retry, replay, restoration, stale effects, terminal results, disposal and motion
changes. CI runs these before the full suite; builds, calibration and browser
checks run on GitHub rather than the resource-constrained VPS.

## Void Crossing restoration and motion

Restoring Void Crossing recalculates the same BFS minimum-move reference used
when generating a round. Previously restoration left that reference at zero,
which could grade an over-par solution as perfect. The scoring policy and
generator remain unchanged; restored boards now use their real reference.

Shuttle completion is scoped to the current round, including zero-duration
reduced-motion effects. Restore, reset and disposal cancel pending completions
and full-shuttle warning timers. Old conflict/capacity highlights do not carry
into a replaced board. An out-of-moves retry begins a fresh saveable session.

Reduce motion suspends the forward star loop and shortens the crossing effect;
the crossing still transfers cargo and commits exactly one move. Normal motion
retains the original 1.2-second animation. Focused widget regressions cover
restored performance, normal/nonterminal crossings, zero-duration completion,
mid-animation toggles, stale effects, retry and disposal. Tests/builds run on
GitHub CI; existing algorithm and renderer A/B paths remain available.

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

## Merged-main verification (2026-10-02)

PR #20 was merged as `8d7f416b3f81d5e7fee98805cca3485f39e3f700`.
All three main workflows completed successfully:

- [Flutter CI](https://github.com/CrispStrobe/NumberNebula/actions/runs/37035490659):
  clean analysis, 48 reduced-motion session checks, and 1,133 Flutter tests
  (two existing skips).
- [Pure Dart calibration](https://github.com/CrispStrobe/NumberNebula/actions/runs/37035491075):
  411 generator regression checks, 1,370 algorithm-path checks, 4,040 Cargo
  assertions, 4,800 Cargo A/B cases and 60,400 fresh boards across all 48 games.
  Generation and Cargo A/B validation reported zero failures.
- [Web and deployment](https://github.com/CrispStrobe/NumberNebula/actions/runs/37035490985):
  864 Flutter capture/replay cases, WASM/JavaScript release compilation,
  browser generator timing, build size reporting, browser tests against the
  artifact, Vercel production deployment and deployed-site browser tests.

The pure report contains 67 structural review flags. These are workload or
hidden-cell changes, not failing boards or measured child difficulty. The
864-case capture is too sparse to clear every progression flag. Keep existing
algorithms and A/B paths while inspecting flagged mechanics.

Production browser samples (one ten-second window per game/browser) showed:

| Browser | Cold menu | Warm first frame | Idle RAF p95 | Moving RAF p95 | Idle writes | Moving writes |
| --- | --- | --- | --- | --- | --- | --- |
| Chromium/WASM | 6,376 ms | 1,107 ms | 16.67 ms | 16.67 ms | 0 | 3 |
| Firefox/JavaScript | 11,316 ms | 3,076 ms | 200.54 ms | 167.16 ms | 0 | 3 |

Both browsers reported no application errors. Chromium recorded no long tasks
in either sample; Firefox does not expose the Long Tasks API, so its empty
arrays do not establish an absence of long tasks. Similar slow Firefox RAF
intervals occurred against the CI artifact. A follow-up
[baseline run](https://github.com/CrispStrobe/NumberNebula/actions/runs/37044883267)
measured approximately 17 ms blank-page RAF in both browsers, versus 167 ms
idle and 150 ms moving-game RAF in Firefox with normal motion. Both tabs were
visible. This isolates an app-rendering cost on this runner, rather than a
universally slow browser timer. Browser RAF is not native device raster performance.

The browser performance probe now records a blank-page RAF baseline, visibility,
frame sample counts and Long Tasks API availability. The baseline precedes the
cold-start timer and does not warm application resources. Use the hosted
performance workflow to remeasure an existing deployment without rebuilding.
It also accepts `reduce_motion` and records Flutter's CPU-only rendering fallback.

The [reduced-motion comparison](https://github.com/CrispStrobe/NumberNebula/actions/runs/37045798617)
passed both browsers against production. Firefox reported CPU-only rendering:
blank-page RAF p95 was 17.16 ms and idle puzzle RAF p95 improved to 17.16 ms,
while the moving game remained at 150.22 ms. Chromium reported no CPU-only
fallback and stayed at approximately 16.67 ms in both games. Both browsers had
zero idle writes, three moving checkpoints in ten seconds, and no app errors.
The normal-motion and reduced-motion measurements ran on separate hosted jobs,
so these are diagnostic samples, not a controlled device benchmark. The evidence
supports investigating decorative animation cost on CPU-rendered browsers and
moving-game repaint cost separately; no automatic setting changes or generator
algorithm removals follow from these measurements.

Earlier interrupted local WASM/session runs are superseded by the successful
remote checks above. Future builds, full tests and large sweeps belong on GitHub
Actions. Routine pure sweeps run on one runner; manual sweeps above 50 samples
split by grade with at most two concurrent jobs and two workers per runner.

## Asteroid rendering candidate

Asteroid Hunter retains its original screen-wide frame rebuild and uncached
painting via `--dart-define=ASTEROID_RENDER_PATH=legacy`. The default `cached`
path rebuilds the playable stack and its moving hit targets on physics frames,
with a repaint boundary around that region. Screen shake and ship thrusters
have their own animation builders. Physics, fixed timestep, scoring, countdown,
pause behavior and session checkpoint cadence share the existing implementation.

Round-local text paragraphs are cached by asteroid identity, size and displayed
expression; crystal paths are cached by size. Removed objects, reset, restore
and screen disposal release retained paragraphs. System-font changes also clear
retained labels, including after round reset; screen disposal removes that font
listener. Failed candidate label layout
uses the original layout path. No render resources enter saved snapshots.

Regression tests compare 32 legacy/candidate images and exercise moving hit
targets, correct-target taps, frame isolation, pause and reduced-motion gameplay.
CI additionally runs the targeted regressions with the legacy compile define.
The manual web workflow exposes `asteroid_render_path` for A/B builds. These
checks must pass remotely before promoting this change; per-frame CPU work is
reduced, but raster-time improvement still needs browser measurements.

## Shared space background candidate

The shared `SpaceBackground` retains its original AnimatedBuilder and uncached
painting via `--dart-define=SPACE_BACKGROUND_RENDER_PATH=legacy`. The `cached`
candidate repaints directly from the animation controller, retaining two
nebula shaders and the seeded star positions for each mounted background.
Resize or palette changes replace those resources; disposal releases retained
shaders. Only the shader coordinate system changes: canvas translation follows
the same drifting centers, while radii, colors, star twinkle and the 24-second
animation cycle use the original formulas.

Reduced motion and `animate: false` still render phase zero and stop decorative
scheduling. The foreground remains an independent interactive child. Widget
regressions compare 48 candidate/legacy image pairs across three palettes,
four cycle phases, two sizes and 1x/2x pixel density (maximum channel delta
2/255 for coordinate rounding),
exercise resize and motion toggles, and check that candidate animation ticks
repaint without replacing the CustomPaint widget. CI runs these checks with the
legacy compile define as well. The web workflow exposes
`space_background_render_path` for hosted A/B builds. This removes repeated
framework/shader allocation; large gradient rasterization remains and no
physical-device FPS improvement is inferred.

## Magic Triangles wormhole candidate

`WORMHOLE_RENDER_PATH=cached` retains the size-dependent radial shader, triangle
geometry, star distances and paints. Animation listeners repaint directly
without replacing the CustomPaint widget on each tick. Puzzle controls were
already outside the old AnimatedBuilder; their update behavior is unchanged.
The circular radial gradient is rotationally symmetric, so its shader can be
retained while the original star, glow and warp formulas continue to animate.
Resize replaces cached resources and screen disposal releases the shader.

`--dart-define=WORMHOLE_RENDER_PATH=legacy` keeps the original drawing path;
unknown values also select legacy. The manual web workflow exposes
`wormhole_render_path` for hosted A/B builds. Image regressions cover animation
phases, glow and warp states, square and rectangular canvases, 1x/2x density,
and resize/recreation using the same cache. CI also runs the real game selector
with the legacy define. Disk, stars, energy glow, yellow frame and warp strokes
retain their drawing order and blur. This reduces allocation and widget rebuild
work; blur rasterization remains, and device FPS gains are not established.

## Protected preview browser checks

All browser specs import the shared extended Playwright test. Its automatic
fixture exchanges the Vercel automation bypass for a context cookie for every
test; an import-time hook would belong only to the first importing spec.
Protected previews suppress Vercel's toolbar through its documented
`x-vercel-skip-toolbar` header on same-origin document requests. No headers
are added to cross-origin CanvasKit loads. Preview routing disables the browser
HTTP cache; performance reports explicitly record this, and local/public-site
measurements retain ordinary caching.

Performance instrumentation runs only in the top app-origin document. A real
opaque sandbox iframe regression checks that child frames receive no probe and
produce no storage errors. App storage failures and renderer errors remain
fatal. The hosted workflow's `full_suite` input runs both specs without retries
to catch preview setup failures on their first attempt.
Toolbar suppression is explicitly enabled for PR deployments or the hosted
workflow's `protected_preview` input; a public `.vercel.app` hostname alone
does not enable routing or disable caching.

Hosted validation on 2026-10-02 passed both browser specs on the previously
failing preview twice with retries disabled (15 passed, one existing skip per
run), then passed the rebuilt artifact and a fresh protected preview. Native
CI passed 1,143 Flutter tests with two existing skips and the ten targeted
legacy-rendering checks. Pure Dart calibration validated 60,400 boards across
48 games with zero failures. These checks support generator correctness and
the rendering/session contracts; they do not establish children's felt
difficulty or physical-device frame rate. Both browser reports observed zero
idle session writes and three moving-game checkpoints per ten-second sample.

## Shared VPS resource policy

Check load averages, available RAM and free space before substantial local work.
Use local work for edits, inspection and small targeted checks. Run large
calibration, full suites, WASM compilation and browsers on GitHub Actions, or
Kaggle when available. Never overlap heavy local jobs. The 2026-10-02 resource
check found four CPUs, peak load averages 18.72/15.45/9.10, only 2.7 GiB free on
the root volume and 6.0 GiB on the toolchain volume. Large outputs belong on the
storage volume or remote artifacts, not the root filesystem. Preserve other
users' processes and data.
