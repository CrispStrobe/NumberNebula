# Space Station Gridlock round audit

## Status and evidence

Version **1.5.40+56** is a repair candidate, not a verified publication.
The focused tests are prepared and still require exact-head execution:
`test/widgets/space_station_gridlock_round_test.dart` contains 37 original-API
contracts; `test/widgets/space_station_gridlock_loader_test.dart` contains six
controlled database-loader cases. The latter exercise the production await but
are not real asset-I/O measurements or old-source counterfactuals.

A [test-only baseline](https://numbernebula-bv3iebble-crispstrobes-projects.vercel.app/baseline-proof.json)
on [`32383b4`](https://github.com/CrispStrobe/NumberNebula/commit/32383b40e93f9e84dd7f8a69dc59dcb68f8c6203)
completed 13 probes: two legal-input/save/current-Next controls passed and eleven
contracts failed with assertions. There were no compilation failures, timeouts,
skips or unclassified exceptions. Actual raw reports and test/source hashes were
independently checked. These failures overlap root causes and stop at their first
failed assertion; they are not eleven independent bugs or evidence that every
later assertion ran. Report protection applies.

Two earlier baselines contained incorrect fixture movement expectations and were
rejected. C cannot initially move left because K blocks it. Two qualifying pan
updates can legally move F twice. Neither observation justifies changing gameplay.
The first repair diagnostic stopped at strict analysis before tests; its reported
lint issues were corrected in the candidate. Formatting is not passing analysis.

## Preserved rules

The board is 6 by 6. Ships have no IDs; snapshots retain puzzle ID, list order and
selected index but restore new physical instances. Each qualifying pan update
commits one legal cell immediately. Blocked and cross-axis input do not count.
There is no move allowance or exhausted-move loss. `minMoves` remains the authored
quality reference, not a proved optimum for this per-cell counting convention.

The final player move reaches the right edge. The exit effect lasts 1,500 ms and
travels two cells; the success effect lasts 800 ms and the result delay is
1,200 ms. Reduced motion completes that meaningful exit and leaves usable result
controls. Scoring remains `250 * grade + efficiencyBonus + ships.length * 20`,
with bonuses 300/150/50 at the existing reference thresholds and unchanged
`Perf.fromMoves`. All 1,313 authored boards, ordering, complexity buckets,
tracker/cache behavior, generator choices, A/B paths and fallback implementations
are retained. The fallback keeps its implementation but moves the second vertical
ship one column right to remove a reproduced overlap at row two, column three.

The test's legal GRID_1 winning witness uses 22 counted cells and yields score
560 at grade one while retaining reference eight. Its independent occupancy
oracle checks bounds and overlap after each fixture step. This witness is not a
shortest-path or felt-difficulty claim.

## Candidate changes

- Own pan callbacks by round and physical ship. Key the screen per round so a
  held recognizer cannot acquire replacement callbacks. Cancel clears feedback.
- Own every database/fallback continuation and loading-stage update. A superseded
  load cannot overwrite a restored board or mark an unseen puzzle as played.
  Opt into the shared session mixin's restore identity without changing its
  default for other games.
- Reject terminal capture. Already exited restores are silent terminal with
  usable Next/Bridge controls and no new reward, learning outcome or stale summary.
- Own delayed results and their actual dialog routes. Restore removes only the
  owned route, including beneath a covering route. Retained Next, Bridge,
  suggested-challenge and debug-rating controls check their owner/current route.
- Complete an owned exit when reduced motion changes; clear obsolete effects on
  restore/disposal. Advance and retire trail/celebration particles by their
  existing lifetimes through visual-only state updates.
- Scroll short/enlarged-text content and wrap stats/result actions. Preserve
  meaningful ship semantics and usable actual controls.

## Next executable validation steps

1. Run strict analysis and both focused files remotely; fix actual failures,
   including test-driver or fixture errors, without retuning legal movement.
2. Compare the final original-API file against the unchanged baseline screen.
   Exclude the separate loader-seam file. Preserve legal-input positive controls,
   classify first failures, and retain raw results/test hashes. Run the repaired
   files in shuffled orders after meaningful changes.
3. Verify the newly prepared coalesced-restore, actual storage resume/decline,
   stale saved-session decisions, current database-failure fallback, fresh
   Bridge/back, retained suggested-challenge and English/German 390×844/390×500
   text-scale-two cases. A prepared test is not evidence it passed.
4. Run the new actual-module fallback occupancy/exit-witness unit test. A bounded
   pure-Dart extraction of the two unedited production generator/configuration
   classes reproduced the overlap in one actual call before the correction. That
   narrow probe does not replace Flutter integration or all-game generation checks.
   Preserve the fallback algorithm, reference ten and selectable paths.
5. Run full native CI, all-game generation/capture/replay, shipping WASM/JS build
   and the full artifact browser matrix on the exact pushed commit. The browser
   inventory adds Gridlock, making 17 audited screens in both engines; derive
   totals/skips/retries from actual reports.
6. Merge only after reviewing the exact-source evidence. Verify merged-main
   checks and publication, including canonical file hashes/isolation headers.
   Record public run links and observed outcomes here and in the handover. An
   unavailable remote runner or queued deployment is not a green result.

This lane does not authorize an App Store upload/submission/release and does not
establish physical-device performance, child difficulty or absence of every
possible regression. Once verified, continue with Star Loader, Robot Path and
Solar Panel as separate game PRs, then the E/F lanes in `REMAINING_WORK.md`.
