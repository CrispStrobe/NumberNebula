# Structural difficulty review: evidence and limits

Updated 2026-10-18. This review preserves the generator algorithms, selectable
legacy/candidate paths, authored level order and child-facing pars. Estimates
remain low confidence and `empiricallyCalibrated: false`.

## Historical evidence

The frozen [calibration summary](calibration-sample-results.json) records 60,400
cases, 48 games, six grades and 20 levels, zero validation failures, 7,493 strata
and 2,031 operation-mixture strata with fewer than ten samples. Comm Relay has
400 balanced strata. These are historical report values, not a fresh measurement
performed by reading that file. See [pure Dart calibration](pure-dart-calibration.md)
for the generation/replay commands and proof limitations, and [handover](../HANDOVER.md)
for exact-commit workflow evidence.

| Mechanic | Recorded flags | Interpretation still requiring evidence |
| --- | --- | --- |
| Molecule | 42 | Seven authored-layout transitions repeated across six grades |
| Robot | 15 | Seeded procedural-board variation and command-workload changes |
| Warp Fold | 4 | Fold-count/workload transitions |
| Crossword | 3 | Hidden-cell/operation-mixture changes |
| Solar | 2 | Structural workload changes |
| Gridlock | 1 | Authored asset transition |

Flags identify review candidates; they are not failed boards or measured child
difficulty. The Molecule asset pool contains 30 numbered levels; the routine
calibration samples levels 1–20. Robot mazes are generated procedurally. A sampled
median drop from level 8 to 9 does not establish an authored maze simplification,
a deterministic level-order defect, uniqueness of command solutions, or what
children experience. Preserve order and pars pending matched solution-path and
human evidence. The [playtest protocol](human-playtest-protocol.md) is preparation
only; no device or child measurements are available.

## What the regression actually checks

`tool/structural_review_g_regression.dart` separates:

1. **Frozen-report integrity:** 57 assertions about the stored schema, flag
   decomposition, strata/fallback counts, and Molecule numbering. These assertions
   do not regenerate 60,400 boards, prove Robot solutions, or establish fresh
   timing/fallback rates.
2. **Bounded live Robot checks:** generate grade 2 levels 8 and 9 using seeds
   `20261002 + level * 1009`, separately for legacy and candidate paths (four
   boards). Solve command states with BFS, execute every returned command, verify
   the goal, preserve the board and JSON round trip. For candidates, additionally
   require reference length to equal BFS length and allowance to cover the path.
   The legacy path retains its original estimate; it is checked for solvability,
   not silently relabelled as a proved optimum.

These seeds describe this narrow regression, not the case-index seed derivation
of a historical all-game sweep. Replay of commands is separate from checking the
metadata. The regression supplements the existing broader algorithm-path tests.

```sh
dart pub get --directory tool/pure_dart
dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/structural_review_g_regression.dart
flutter test test/pure/structural_review_g_test.dart --concurrency=1
```

The pure calibration workflow runs the CLI once per matrix (the all-grade job,
or grade 1 in split sweeps). The Flutter wrapper is included in the full suite.
A configured step alone is not a passing run; use the exact-head evidence linked
from the handover after validation completes.

## Larger measurements and remaining work

Use `.github/workflows/pure-calibration.yml` for larger samples. The routine
sweep uses ten samples and two workers. Manual runs above 50 samples split into
six grade jobs with at most two concurrent jobs and two workers each; artifacts
expire after 14 days. Preserve any fixtures required for longer comparisons.

For each remaining progression candidate, capture matched adjacent-level boards,
retain per-case seeds and fixtures, independently replay solution paths where
available, and publish distributions, sparse strata, proof status and paired
algorithm traces. Wall-clock-bounded generators can choose different valid
fallbacks under different runner loads; frozen fixtures support exact replay.
Generator speed, browser scheduling and structural workload are distinct from
children's solve time, success rate and fair scoring thresholds.

The former version of this review overstated Robot replay coverage, named a
missing Flutter wrapper, and included unarchived local sample/timing claims.
Those claims are withdrawn here. The bounded live regression and wrapper now
exist; this document claims no replacement full sweep or human calibration.
