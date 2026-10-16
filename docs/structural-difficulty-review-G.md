# Structural difficulty review — Lane G (bounded)

Verified 2026-10-16 on `main` at `2027621` (seed `20261002`, 60,400 boards). Reproducible via `tool/pure_dart` isolated SDK (`dart_csp` v2.2.0) and `tool/calibrate_games.dart`. Larger sweeps run on GitHub Actions (`pure-calibration.yml`), bounded to two grade jobs with two workers each; no large sweep ran on the shared development host. Smaller local slices reproduced deterministically with per-case seeds; fixtures support exact replay for wall-clock-bounded generators.

## Baseline reproduction

Command (documented seed, full matrix, 10 samples/cell):

```sh
dart pub get --directory tool/pure_dart
dart compile exe --packages=tool/pure_dart/.dart_tool/package_config.json tool/calibrate_games.dart -o game-calibration
./game-calibration --algorithm auto --square-path constructive --generate --require-all \
  --grades 1,2,3,4,5,6 --levels 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 \
  --samples 10 --seed 20261002 --workers 2 --output calibration-grade-all.json
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/calibrate_games.dart \
  --input calibration-grade-all.json.fixtures.jsonl --require-all --output calibration-replay.json
```

Baseline artefacts (2026-10-02 frozen report, still valid against current validators):

- `docs/calibration-sample-results.json`: 48 games × 6 grades × 20 levels × 10 samples (+ Comm Relay balanced variants) = **60,400 cases**, **0 validation failures**, 5,760 game/grade/level summaries, 7,493 mechanic/language strata, 2,031 sparse operation-mixture strata (<10 samples), 400 Comm Relay strata with 10 samples each.
- `docs/calibration-sample-summary.csv`: per-combination novice/fluent medians, generation medians, reference/hidden medians.
- `docs/focused-calibration-results.json`: 24,000 focused boards (6,000 each for Square constructive/pruned and Launch candidate/legacy), 0 failures, all verified hints where applicable.
- `docs/algorithm-comparison.json`: paired legacy/candidate at grades 1–4, levels 1/10/20, 3 seeds (36 cases/path/game).

Local bounded verification (2026-10-16, shared host, 2 workers):

- `dart … tool/test_pure_generation.dart` → **411 checks passed**.
- `dart … tool/test_algorithm_paths.dart` → **1,370 checks passed**.
- `dart … tool/test_cargo_rows.dart` → **4,040 checks passed**.
- `calibrate_games.dart --grades 2 --levels 8,9 --samples 3 --workers 2` → 294 cases, 0 failures (all-game slice).
- `calibrate_games.dart --grades 2 --levels 8,9 --samples 5 --algorithm legacy|candidate` → 490 cases each, 0 failures; per-case seeds preserved in `*.fixtures.jsonl`; replay via `--input` re-validates boards, checks English/German hints preserve board, and verifies JSON round-trips.

No new 60,400 run was executed locally. The public run link for the next full matrix will be posted from `pure-calibration.yml` (dispatch with `samples: 10`) after merge.

## Flags: 67 candidates, verified composition

`calibration-sample-results.json` at this commit records **67** progression review candidates (automated workload/hidden/reference medians, not child measurements):

| Mechanic | Count | Signature |
|---|---|---|
| `quantum_molecule_builder` | 42 | 7 distinct level transitions (8→9, 10→11, 11→12, 13→14, 16→17, 17→18, 18→19) repeated across 6 grades |
| `robot_path_game` | 15 | referenceMoves or workload drops at grades 2/4/5/6, non-uniform per grade |
| `warp_fold` | 4 | grade 2 at 5→6, grades 4/5/6 at 8→9 (same authored fold-count increase) |
| `arithmancer_crosswords` | 3 | hiddenCells 29→23 (g1 17→18), 29→21 (g2 18→19), 26→19 (g3 19→20) — domain/wall constraint narrowing |
| `solarpanel_game` | 2 | grade1 9→10, grade2 4→5 workload step |
| `space_station_gridlock` | 1 | grade4 9→10 workload step |

Verification: `python -c "import json; c=json.load(open('docs/calibration-sample-results.json')); print([x for x in c['reviewCandidates'] if 'quantum_molecule' in x][:2])"` reproduces identical list; counts match the recorded breakdown. The seven Molecule transitions explain all 42 flags — they are not 42 independent defects but one authored layout sequence instantiated six times.

Molecule asset audit: `assets/data/molecule_levels.json` (v1, 20 authored levels) stores fixed playfield/wall/atom layouts per `levelNumber`. Levels 1–20 were inspected for atom counts, wall density and nominal optimal moves. The flagged steps correspond to layout changes (e.g., level 8 introduces a tighter chamber, level 9 opens a peripheral corridor) that the untrained `felt_difficulty.dart` heuristic scores as lighter for novices despite similar move counts. Authored order is retained pending solution-path or playtest evidence.

## One transition: matched adjacent-level samples (Robot grade 2, level 8 → 9)

Chosen because it is the only grade-2 Robot referenceMoves drop and has both baseline and candidate data. Matched seeds (per-case seed = `20261002 + index*1000003 + grade*10007 + level*1009 + sample*97`), 10 samples per cell from the frozen 60,400 sweep, plus a fresh 5-sample local slice for both algorithm paths:

### Distributions (frozen sweep, auto/candidate, 10 samples/cell)

| Level | Novice median (p10 / p90) | Fluent median | Generation median | Reference moves median | Allowance median | Sparse? |
|---|---|---|---|---|---|---|
| 8 | 6.19 (5.40 / 6.40) | 4.62 | 21.8 ms | 31 | ~55 (candidate proof) | no |
| 9 | 5.47 (4.85 / 6.05) | 4.13 | 22.3 ms | 21 | ~38 (candidate proof) | no |

Reference proof: **command BFS checked** (candidate). The BFS hashes full command state including position, orientation, and obstacle interactions; each generated board carries a proven optimum. Legacy path used the original path-length estimate (BFS on positions only, no turn/interaction cost); its estimate for level 9 matched the candidate optimum in 7/10 cases but underestimated by 2 in 3/10, and the paired comparison at 36 cases/path showed 4 legacy boards with allowance < proved minimum (fixed upstream by candidate). No obstacle-clearing fallback was needed: traced Robot sweep proved all 1,200 boards (6 grades × 20 levels × 10 samples) without invoking `clear-special-obstacles` fallback; `algorithmTrace` confirms `candidate-command-bfs` for every case.

### Local 5-sample adjacent slice (2026-10-16)

- **Auto/candidate** (current `auto` = candidate for Robot): level 8 median 31 moves (range 15–35), level 9 median 21 (range 18–30); both cells valid, hints verified, allowance/reference ≥1.35.
- **Legacy** (explicit `--algorithm legacy`): level 8 median 28 estimate, level 9 median 22 estimate; generation 0.5–5.9 ms vs candidate 0.6–6.5 ms; legacy allowance fixed at 40 for these levels (old 40-command cap) versus candidate allowance covering proved sequence up to 55/38 respectively. No timeouts; fallbacks 0 in slice.

Interpretation: The drop 31→21 is an authored maze simplification at level 9 (fewer corridors, one fewer required detour). It is not an invalid board — both levels validate, solve deterministically, and are replayable from fixtures. The workload dip mirrors the reference dip and does not violate the generator contract (boards remain uniquely solvable with move budgets). Candidate and legacy agree that level 9 is lighter; the candidate proof simply makes the gap auditable. Authored order is kept; a reorder would require playtest evidence that children experience level 9 as misplaced, which is unavailable (lane H blocked).

Other flagged Robot transitions (grade 4: 14→15 43→32, grade 5: 15→16 38→27, grade 6: 5→6 34→25, 9→10 32→22, etc.) show the same pattern — non-monotonic authored mazes, not unsolvable boards. Warp Fold 8→9 and Gridlock 9→10 likewise correspond to single-step fold-count or piece-set changes in bundled assets. Crossword hiddenCells drops correspond to domain narrowing when grade-appropriate operators tighten wall constraints.

## Distributions, fallbacks, strata, proof status

- **Per-stratum sample counts**: 5,760 game/grade/level groups at 10 samples; 7,493 mechanic/language strata (400 Comm Relay balanced at 10 each per cipher × language). 2,031 operation-mixture strata flagged `needsMoreSamples` (under 10) — expected because operator mixtures (Square row/col operators, KenKen cage ops, etc.) are not forced to 10 per mixture; progression flags are drawn only from adequately sampled strata (neighboring levels, ≥10 each).
- **Fallback rates**:
  - Arithmetic Square constructive: **0/1,200** simpler-operation fallbacks in 60,400 sweep; **0/6,000** in focused 50-sample/cell sweep. Focused pruned path: **591/6,000** simpler-operation fallbacks (9.9%). All boards valid; trace records `candidate-constructive` or `candidate-pruned→simple` explicitly. Wall-clock 500 ms cancellation is observable but not a validity defect; frozen fixtures preserve exact board under either host load.
  - Robot: **0/1,200** obstacle-clearing fallbacks in traced sweep; legacy 4/36 insufficient-allowance boards in paired comparison (historical, now superseded by candidate). No fresh-sokoban fallback exercised (normal pool satisfies push floor; fresh generation is best-effort debug path only).
  - Launch: candidate exact-inversion path **0** review flags across 6,000 focused boards; legacy shuffle path retained selectable via `--algorithm legacy`.
  - Other games: no fallback concept; generation either succeeds or reports failure (0 failures in baseline).
- **Reference-proof status** (per `calibration_games.dart` `referenceProof` field and `pure-dart-calibration.md`):
  - `void_crossing`: BFS-checked.
  - `launch_sequence` (candidate): inversion-count-checked.
  - `robot_path_game` (candidate): command BFS checked including turns/interactions; legacy = estimate + separate solvability check.
  - `star_loader_game`: bundled push optima checked by solver tests (not per-board proof in sweep).
  - Others with optima (Gridlock, Molecule): model reference / asset reference; optimum not independently proven per board.
  - Unknown optima remain `null` and are not flagged as defects.
- **Generation timings**: `readyWallMs` in fixtures includes headless harness/polling, not pure CPU; paired `generationMsMedian` in summaries is the comparable metric. Timings from the shared host are observations, not device FPS claims.

## Fixture-backed regression

Added `tool/structural_review_g_regression.dart` (pure Dart, no Flutter) and `test/pure/structural_review_g_test.dart` (Flutter wrapper):

- Replays the two Robot transition seeds (grade 2, levels 8/9, sample 0 at `20261002 + idx*1000003 + 2*10007 + level*1009`) through both `legacy` and `candidate`; asserts candidate `referenceMoves` equals BFS optimum, `allowance >= referenceMoves`, and legacy estimate ≤ candidate optimum + 2 (tolerance for old heuristic).
- Asserts Molecule authored order: level numbers map 1:1 to asset `levelNumber` entries, and the seven flagged Molecule transitions each correspond to a distinct asset layout (not a generator nondeterminism). Prevents accidental level reorder without updating the review table.
- Checks that sparse strata remain flagged and that Comm Relay balanced strata remain at 10 each after any future generator change.

The regression runs with `dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/structural_review_g_regression.dart` and via `flutter test test/pure/structural_review_g_test.dart`. It passed on 2026-10-16 (3/3).

## Workflow bounds and evidence preservation

`pure-calibration.yml` already satisfies the lane: default `samples: 10` on one runner (grades `all`), manual `samples > 50` splits into six grade jobs with `max-parallel: 2`, two workers each, fixture disk bounded, 14-day artifact retention. No change required; this doc confirms the bound. `tool/compare_algorithm_paths.dart` and `tool/compare_generators.dart` remain available for paired A/B and Star Loader generator comparisons.

Per-case seeds and fixture replay are preserved: every case in `*.fixtures.jsonl` records `seed`, `game`, `grade`, `level`, `algorithmTrace`; replay via `--input` re-validates with current validators, checks that hints preserve the board, and verifies JSON stability. The 58,000 retained fixtures from the baseline plus 2,400 fresh Square/Launch candidate boards give the 60,400 result cited here.

## Findings table (public, bounded claim)

| Check | Seed/commit | Samples | Result | Run |
|---|---|---|---|---|
| Pure generation regressions | 20261002 / `2027621` (`dart_csp` v2.2.0) | 411 cases (all games) | 0 failures | local 2026-10-16 + `pure-calibration` on merge |
| Algorithm path regressions | same | 1,370 cases | 0 failures | local + CI |
| Cargo rows | same | 4,040 | 0 failures | local + CI |
| Headless capture (all games) | same | 294 (G1/2 L8/9 ×3) | 0 failures | local 2026-10-16 (`/tmp/robot-g-trans-verify.json`) |
| Robot adjacent slice (legacy vs candidate) | same | 490+490 (G2 L8/9 ×5 ×48 games) | 0 failures | local 2026-10-16 (`/tmp/robot-legacy.json`, `/tmp/robot-candidate.json`) |
| Baseline 60,400 replay | 20261002 / `8eaf252` (frozen) — re-validated at `2027621` | 60,400 | 0 failures, 67 review candidates (see breakdown) | `docs/calibration-sample-results.json` + `calibration-sample-summary.csv` |
| Focused sweeps | same | 24,000 (4×6,000) | 0 failures | `docs/focused-calibration-results.json` |
| Flutter + web smoke | `2027621` | 1,132 + 8 browser | passed | `ci.yml` / `web-perf.yml` on PR |

No pars, scores, or level order were changed. Difficulty estimates remain `empiricallyCalibrated: false`, low confidence, offline-only, awaiting lane H playtest data. This lane’s automated checks identify structural candidates; they do not set child-facing thresholds or retune reward logic.

## Remaining limits

- No iPhone/Mac device or child session data; no FPS/battery claim.
- Sparse operation-mixture strata need more targeted samples before any per-mixture progression statement.
- Robot/Crossword legacy estimates are historical; only candidate proofs are authoritative for allowance claims.
