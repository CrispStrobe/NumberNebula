# Pure Dart generation and estimated difficulty

Current verified baseline (2026-10-05): **1.5.22+38**, commit
`8eaf252bc86dfc7e44bb219613e60f2bd3450e7c`. See [handover](../HANDOVER.md)
for exact-head green CI links (1,471 Flutter tests, two skips; 60,400 pure Dart
cases with zero failures; 864 Flutter capture/replay cases and green web deployment).
Dated results below are historical observations. Next tasks are defined in
[the lane board](../REMAINING_WORK.md); estimates remain untrained.

The app and CLI share puzzle generators for all 48 registered games. Screen
models with Flutter colors/layout retain adapters; their generation uses pure
models. Molecule, Gridlock and normal Star Loader select their actual bundled
levels. CLI generation covers puzzle content, starting hands, choices and rules;
it does not simulate Flutter animation, collision timing or rendered input.
Samples use fresh profiles and default problem settings, without a particular
child's spaced-review history.

## Run without Flutter

Install Dart 3.12.1, then run from the repository root:

```sh
dart pub get --directory tool/pure_dart
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/test_pure_generation.dart
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/calibrate_games.dart \
  --generate --require-all --grades 1,2,3,4,5,6 \
  --samples 10 --seed 20261002 --workers 4 --output calibration-report.json
```

This generates **60,400 boards**: all 48 games × six grades × all 20 levels ×
ten samples, with additional balanced cipher/language variants for Comm Relay.
Increase `--samples` up to 1,000 for a broader sweep, or select fewer levels
with `--levels 1,5,10,20`. Start with `--workers 2` on a small runner. `--game KEY` isolates a game
without changing its per-case seed; omit `--require-all` when filtering.

The isolated package depends only on `collection` and the same pinned
`dart_csp` revision as the app. It requires neither Flutter SDK dependencies
nor plugins, devices or a display. A native executable is also supported:

```sh
dart compile exe --packages=tool/pure_dart/.dart_tool/package_config.json \
  tool/calibrate_games.dart -o game-calibration
./game-calibration --generate --require-all --grades 1 --levels 1 --samples 1
```

The executable still reads bundled assets relative to the repository root.
`--fresh-sokoban` exercises the bounded procedural generator instead of the
normal verified pool. Fresh generation is best effort and may miss its push
floor; normal pool selection must satisfy the floor.

## Reproduce and inspect

Output includes JSON results, `.fixtures.jsonl` frozen boards and a
`.summary.csv` table of per-game/grade/level sample distributions. JSON groups
contain novice/fluent score medians and p10/p90, generator timings, reference
moves and hidden counts. These percentiles describe sampled board variation;
they are not confidence intervals about children.

```sh
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/calibrate_games.dart \
  --input calibration-report.json.fixtures.jsonl --require-all \
  --output calibration-replay.json
```

Replay rechecks pure-generated boards with the current validators, runs English
and German hints, checks that hints preserve the board, and checks JSON round
trips. It exits nonzero on failures. Every case records its seed. Random streams
and CSP restart choices are seeded; wall-clock search cancellation in arithmetic
squares, crosswords, Codebreaker and Robot Path can select different fallbacks
under different CPU loads. Frozen fixtures provide exact replay in these cases.

The regression command compares repeated seeds for the other 44 games and
validates both repeated boards for deadline-based generators. It also checks
registry coverage, known failing seeds, valid alternative census assignments,
clock reflections, BFS crossing optima and deliberately corrupted boards.

`.github/workflows/pure-calibration.yml` defaults to 10 samples per level and
combines all six grades on one Dart SDK runner for routine sweeps. Manual sweeps
above 50 samples split into six grade jobs, with at most two running at once to
bound fixture disk usage. Each runner uses two generation workers; reports and
fixtures are retained for 14 days. Configuring this workflow does not mean a
remote GitHub run has passed.

## What the checks establish

Arithmetic and Latin-grid checks recalculate equations, row/column rules, cage
rules, wall relationships, clue/reference agreement and required answer choices.
Tribunal, Manifest and Vault check unique solutions. Lights use a linear-system
solver and replay; Crossing compares BFS optima; sorting checks inversions;
circuits replay the reference swaps. Mines recalculate neighbour counts. Other
checks cover shape/value ranges, projections, encoded messages and clock
transforms. The Flutter suite independently solves every shipped Star Loader
level and checks its stored minimum pushes.

Checks differ by game: generation success is **not** a proof that every board
has a unique solution or a verified minimum. Robot candidates have a full
command-state BFS proof including turns and obstacle operations. The selectable
legacy Robot path retains its original path-length estimate. Gridlock and molecule optima remain asset references. Grid Filler's area
identity alone does not prove every placement strategy can complete the board.
Reference proof status is recorded in each report.

## Estimating felt difficulty

`felt_difficulty.dart` uses an explicit, untrained workload heuristic. It reports
arithmetic, spatial, planning, reading and working-memory loads, task units,
time-pressure flags and prerequisite explanations. Ordinal bands are **light,
moderate, stretch and heavy**, separately for a child still acquiring the relevant
skills and one fluent in them. The coefficients and band boundaries are design
assumptions, not fitted measurements. Every estimate is marked low confidence
and `empiricallyCalibrated: false`.

This can identify likely difficulty jumps, high working-memory demands, large
numbers and weak progression. Candidate arithmetic ranges explicitly extend
through grade 6; spatial/asset families can retain documented board-size caps.
Move allowances may tighten even when the board's workload stays similar.
Generator speed measures software cost, not children's solving time.

Research supports considering strategy proficiency, working memory and spatial
load: [strategy and age in arithmetic](https://pmc.ncbi.nlm.nih.gov/articles/PMC5724815/)
and [visuospatial working memory in early mathematics](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.02460/full).
Neither study validates this app's score formula. Without child playtests,
the report cannot predict ages, completion times, success rates or fair reward
thresholds. The estimates stay offline and do not automatically retune the app.

## Earlier sample run (2026-10-02)

The earlier 11,520-board sweep completed with zero failures under these validators,
including regenerated samples after fixes. It produced 1,152 combination
summaries and 40 progression review candidates. The isolated SDK regression
command passed 411 checks, and a compiled native CLI generated all 48 games
without Flutter. The full Flutter suite passed 1,132 tests, with two skipped.
App and tool static analysis are clean. Another 192 all-game save/reopen
checks passed at grades 2 and 6, levels 1 and 20; four Crossing checks were
rerun after the final high-level puzzle fix. The final release WASM build
also succeeded, and startup/deferred-game smoke checks passed in both
Chromium/WASM and Firefox/JS (four tests).

The sweep found and fixed division-wall factor enumeration that could stall,
contradictory random crossword clues, rejection of valid alternative census
answers, Crossing optima/allowances and an unsolvable six-entity chain that forced
high levels into easier fallbacks, and mirror-clock hour-hand errors when
minutes were nonzero. Census acceptance and the stalled wall have specific
regression seeds; clock checks include 200 mirrored samples.

The [sample summaries](calibration-sample-summary.csv) and
[run metadata/review candidates](calibration-sample-results.json) are saved in the repository.
Full JSON and frozen boards are local/CI artifacts. Timings from this loaded
shared machine should not be used as native-device performance claims.

For example, the heuristic rates grade-1, level-1 Block Counter as moderate
for a novice and light for a fluent solver; Signal Triangulation as moderate
and light; Number Walls as stretch and moderate; and Robot Path as heavy and
stretch. That earlier run used Robot Path's legacy path-length estimate. These
are model scenarios to guide playtest selection, not observed child results.

## Candidate algorithms and A/B comparisons

The working algorithms remain in the app. `--algorithm legacy` runs the previous
paths; `--algorithm candidate` measures candidate generation/solving;
`--algorithm auto` tries the candidate and retains the existing solver as a
fallback. The default is `auto`. Flutter builds can select a path with
`--dart-define=GAME_ALGORITHM_PATH=legacy` (or `candidate`/`auto`). Selection is
zone-local in the CLI, so parallel workers cannot change one another's path.

Arithmetic Square and Crossword use `dart_csp`'s named linear constraints,
indexed arithmetic supports, and domain pruning before search. The original
predicate/restart algorithms and their bounded retries remain available. No
change to the upstream package is required for these integrations. Candidate
hints propagate finite cage/visibility supports and are independently checked
against the original completion solver. A bounded search failure remains an
observation hint, never an invented answer.

Robot Path retains its maze generator. The candidate searches complete command
states, proves an optimum including turns and obstacle operations, and rejects
unproved boards. Retries use the original generator. A final fallback clears
special obstacles from an original maze and proves it again. Capture records
identify that fallback. Candidate command allowances cover the proved sequence,
up to 80 commands; the legacy path keeps its original 40-command cap. Search
budget exhaustion means **unknown**, not unsolvable.

Generation capture records `algorithmTrace`, including legacy fallbacks and
simplified-operation fallbacks. For a paired generation comparison and hint
comparison on identical boards:

```sh
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/compare_algorithm_paths.dart algorithm-comparison.json
```

The comparison keeps the generated boards, hint constraints, seeds, grade,
level, validity, timings, and implementation selection in its report. Candidate
and baseline generation need not yield identical boards: they use different
search decisions. Hint measurements use the **same** board for both paths.

## Every level and explicit advanced grades

Pure generation now defaults to all 20 levels, six grades, and 10 samples per
cell. Comm Relay samples each supported cipher and both English and German with
10 samples **per** variant: 60,400 total boards across the current catalog.
Reports include summaries by algorithm/mechanic/language and identify strata
with fewer than 10 samples. Operator mixtures in other games are described by
their actual operators; they are not guaranteed to have balanced counts. Grade
and level averages still exist for orientation, but progression claims must be
checked within strata to avoid interpreting changes in random cipher mix as a
change in difficulty.

The candidate shared numeric configuration explicitly supports grades 5 and 6
with base maxima 120 and 180, plus the existing level increment. Arithmetic
Square's maxima extend to 30/40 and Crossword's to 32/40. Nebula Matrix and
Orbital Towers remove one/two additional clues while keeping bounded grid
sizes. Timing and speed retain their grade-4 ceilings. The legacy path retains
its previous grade-4 configuration. These are content changes, not measured
child ability or experimentally fitted reward thresholds.

Several spatial families intentionally retain their existing maximum board
size or mechanics: Cube Scanner and Void Crossing use their grade-4 templates;
Star Loader uses the verified grade-4 asset pool with its existing requested
push floors; Molecule Builder and Gridlock depend on available authored assets.
Other generators may retain their existing caps. A requested grade-6 label
alone must not be interpreted as a distinct grade-6 mechanic in every game.

## Paired candidate measurements (2026-10-02)

The final native comparison uses 36 cases per path/game at grades 1–4 and
levels 1/10/20, with three seeds per combination. Hints use identical boards.
On the shared CLI host:

| Operation | Legacy median | Candidate median | Verified hints, legacy → candidate |
|---|---:|---:|---:|
| Arithmetic Square generation | 159.5 ms | 6.7 ms | — |
| Crossword generation | 63.8 ms | 15.8 ms | — |
| KenKen hint | 26.4 ms | 1.0 ms | 21/36 → 32/36 |
| Orbital Towers hint | 40.2 ms | 5.8 ms | 16/36 → 36/36 |
| Robot generation | 0.08 ms | 2.3 ms | — |

Four legacy Robot boards had an allowance below their proved command minimum;
all 36 candidate boards passed. The Robot proof adds computation that the old
path did not perform. Its candidate reuses immutable grid hashes across turns
and movement; mutation operations create fresh hashes. No command rule changes.

The larger sweep exposed a grade-6 Crossword uniqueness cliff: one seed took
118.6 seconds with the widened domain. Retaining the previous uniqueness-size
guard brought that seed to 146 ms. Both affected seeds are standalone
regressions. Candidate hint support enumeration prunes arithmetic bounds,
product divisibility and visibility counts before building tables.

These timing differences are algorithm measurements, not child solving times or
physical-device profiles. Re-run the A/B tool on the intended host before
setting performance budgets.

## Earlier every-level validation

The final replay covers **60,400 boards across all 48 games**, six grades and
all 20 levels, with **zero failures under the implemented validators**. It
produces 5,760 game/grade/level summaries and 7,514 mechanic/language strata.
All 400 Comm Relay strata have ten samples. Another 2,058 operation-mixture
strata have fewer than ten samples and remain explicitly flagged for more data.
The 82 progression candidates are review prompts from adequately sampled
neighboring strata, not experimentally calibrated child difficulty changes.

Final replay returned verified completion hints for 1,004/1,200 KenKen boards
and all 1,200 Orbital Towers boards. Remaining KenKen searches keep observation
hints when the bounded proof is unavailable. A separate traced Robot sweep
proved all 1,200 boards without needing the obstacle-clearing fallback.
Arithmetic Square used its candidate for 1,096 boards and its retained bounded
addition/subtraction fallback for 104; that operation change is visible in the
capture trace and operation strata.

The standalone suites passed 411 generation checks and 238 algorithm-path
checks. The full Flutter suite passed 1,132 tests with two skipped; 205
additional high-grade/session and targeted checks passed, followed by the
Robot/hint integration tests after the final solver optimizations. The complete
[paired A/B report](algorithm-comparison.json) is retained alongside the
[sweep metadata](calibration-sample-results.json) and
[combination table](calibration-sample-summary.csv).

The final WASM build and all four Chromium/WASM and Firefox/JS startup/deferred
loading smoke tests passed. Generation times in the frozen sweep are costs at
capture time; the final paired A/B report measures the current generation
implementations. Replay uses the final validator and hint implementations.
Remote CI/deployment and native-device or child measurements remain separate.


## Launch Sequence and Square follow-up

The retained Launch random-shuffle path can overshoot its inversion floor by a
wide amount. Candidate/auto now construct an exact inversion count, verified by
an independent adjacent-swap execution. App and CLI share the same configuration.
Across levels 1–20, the grade 1–6 swap targets progress respectively from
2→5, 3→8, 5→14, 7→17, 9→20, and 11→23. Plateaus are deliberate because small
permutations have few distinct attainable workloads. Seeds vary layouts at a
given workload; permutations are not claimed to be uniformly sampled.
`--algorithm legacy` retains the original shuffle and level floors.

Square has two independently selectable CSP candidates. The new constructive
path solves the union of permitted exact arithmetic relations using dart_csp,
then chooses supported row/column operators. It tries an advanced-operation
anchor when the actual number range permits one, and relaxes that anchor if the
whole grid cannot support it. Each solve requests cancellation after 500 ms;
this is not a hard wall-clock deadline while the event loop is busy. The prior
pruned/random-operator generator and its simpler-operation fallback remain
intact. Auto falls through constructive → pruned → original baseline on failure;
strict candidate surfaces a constructive failure for testing.

Select `--square-path constructive|pruned` in the calibration CLI, use
`withSquareGenerationPath` in Dart, or pass
`--dart-define=SQUARE_GENERATION_PATH=pruned` to Flutter. The GitHub workflow
exposes both choices. Grouped JSON and CSV summaries keep Square paths separate.

The [focused results](focused-calibration-results.json) contain four sweeps of
6,000 boards each: six grades × all 20 levels × 50 seeds. All 24,000 boards passed
validation and localized hint checks. Square's constructive path used no
simpler-operation fallback; the pruned path used it for 591/6,000 boards. The
constructive path produced 5,997 multiplication/division equations versus 3,593
in the pruned sample. Their generation medians were 12.4 and 16.2 ms, respectively.
The shared host experienced disk and memory pressure; these are host observations,
not controlled device benchmarks or estimates of children's completion times.
The exact-workload Launch sample had no progression review flags.

Standalone checks now include all attainable inversion counts for 2–8 items,
independent sorting proofs, every grade/level target, invalid inputs, both Square
CSP paths, custom operation/range preservation, solver failure handling, and
A/B summary separation. The suites pass 411 generation and 1,370 algorithm-path
checks. Difficulty estimates remain untrained; changes to actual child-facing
pars require playtests.


The replay CLI streams UTF-8 JSONL fixtures one board at a time instead of
retaining every decoded game state. Summaries still retain case-level metrics;
malformed records identify the source file and line. The fixture-reader checks
cover chunk boundaries, non-ASCII symbols, CRLF, blank/empty inputs, and
malformed/non-object JSON. This removes a major memory cost for large sweeps.


The updated all-game replay passes all **60,400 boards with zero validator or
localized-hint failures**. It replaces 2,400 Launch/Square fixtures with fresh
candidate boards and retains the other 58,000 fixtures, including their original
capture-time generation costs. It yields 5,760 combinations, 7,493 strata,
2,031 sparse operation-mixture strata, and 67 remaining progression review
candidates. All 400 Comm Relay strata still have ten samples. Square's 1,200
primary-sweep boards all use the constructive path; Launch has no progression
flags. The current replay verified completion hints for 1,038 KenKen boards
and all 1,200 Orbital boards. Bounded search counts can vary with host load.

Forty-two remaining review strings are the same seven authored Molecule layout
transitions repeated across grades. They describe structural workload changes,
not proven errors or child difficulty. Preserve the authored order until
solution-path evidence or playtests support a different ordering.


Final follow-up verification passed clean app/tool analysis, 411 generation
checks, 1,370 algorithm/fixture-reader checks, and all 1,132 Flutter tests
(two skipped). The release WASM build passed in 285.7 seconds. All eight browser
checks passed: startup, deferred loading, and playable Launch/Square boards in
both Chromium/WASM and Firefox/JavaScript. GitHub workflow configuration was
validated locally; no remote CI run or deployment is claimed.
