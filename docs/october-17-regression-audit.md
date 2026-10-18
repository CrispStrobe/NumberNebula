# October 17 change audit and regression evidence

This review compares the October 17 changes and their pending grid/construction
PRs with the preceding baseline
[`2027621`](https://github.com/CrispStrobe/NumberNebula/commit/202762147924338cb6e07bf83a770a4ecb4ad875).
It includes the integration repairs in
[PR #58](https://github.com/CrispStrobe/NumberNebula/pull/58). Passing tests establish
specific contracts; they cannot establish that every possible regression is absent.

## Scope and evidence map

| Changed area | Behavioral verification |
| --- | --- |
| Star Forge | `test/widgets/star_forge_round_test.dart`: real input, budgets, restore, stale callbacks, one-time outcomes, hints, drop/success motion, phone layouts, animated outline and stable board children |
| Chrono Repair | `test/widgets/chrono_repair_round_test.dart`: real steppers/submission, retained input and navigation, editable mistakes, immutable learning records, restore, retry and large-text phones |
| Orbital Towers | `test/widgets/orbital_towers_round_test.dart`: real input, reusable tray, budgets, restore, outcomes, retained navigation and motion |
| Alien Tribunal | `test/widgets/alien_tribunal_round_test.dart`: real assignment/submission, correct unsubmitted restoration, async generation, feedback, outcomes, navigation and phones |
| Crossword, KenKen, Magic Triangles, Number Walls | Their individual `test/widgets/*_round_test.dart` suites plus `test/widgets/support/round_contract_checks.dart`: actual final pointer drop, independent rule validation, exact move/inventory accounting, exhausted restoration, stale removals, restored effects, initial/mid-drop reduced motion and callbacks after disposal |
| Hive Station, Xenobiology Lab | Their individual round suites: real controls, attempts/mistakes, saved input, retry, outcomes, old rounds, motion and phone layouts |
| Diagnostic logging | `test/core/app_logger_test.dart`, `test/logic/logging_gate_test.dart`; existing Star Loader/Arithmancer rules and full suite |
| Structural review and difficulty claims | `test/pure/structural_review_g_test.dart`, `tool/structural_review_g_regression.dart`: frozen-report integrity separately from newly generated Robot command replays |
| Human/store preparation | `docs/human-playtest-protocol.md`, `docs/release-readiness.md`: documented preparation, no fabricated child/device measurements or store release |
| Workflow and lint changes | Static analysis, enabled-acceptance contract, workflow validation and the full regression suite |

## Second-pass findings

Review of `47c5351` found gaps after the first repair:

- Star Forge hoisted its painter together with static board children, freezing
  the outline's glow. Only the static contents should be reused. Board geometry
  must also use the area remaining after padding.
- Orbital Towers' back callback compared the current round with itself. Retained
  navigation callbacks also need to reject a covering route.
- Triangle/wall removal callbacks read the round and expected value when invoked,
  allowing an old callback to remove new input. Capture both while building and
  give each round's controls separate gesture identity.
- KenKen/triangle/wall restoration left the previous drop marker attached to the
  new board. Triangle/wall drop controllers did not honor initial or mid-effect
  reduced motion, and retained hover callbacks could call state after disposal.
- Triangle/wall retry generation retained terminal and pending-victory flags,
  leaving the next board unplayable. Real win/loss retry must generate a fresh,
  interactable round. Pending hint/loading and last-drop state must reset too.
- Several stale-drag tests checked only outcome counts, allowing silent board or
  inventory mutation. The triangle win test accepted an unsuccessful outcome.
  Assert exact unchanged snapshots and require a validated solution and a win.

The expanded tests must also run against the previous implementations as negative
controls, so passing assertions cannot be mistaken for tests that never exercise
the defect. The [published audit evidence](https://github.com/CrispStrobe/NumberNebula/pull/59)
records the exact tested source, before-fix failing cases, full-suite summaries,
generation/capture counts and changed-line coverage. The build report is generated only after all validation steps pass; its exact
source and results are retained in the linked PR. Verify its source commit before
using it as evidence. The immutable validation deployment preserves the report
when subsequent production builds replace supplementary files. Coverage lists unexecuted changed lines and is not a claim
that every possible interaction or error path has been exercised.

To reproduce, use the pinned SDK and an isolated checkout. Run the eleven focused
round suites listed above, then `flutter test --coverage --concurrency=1` and the
commands in [pure Dart calibration](pure-dart-calibration.md). For negative
controls retain the new tests while substituting the corresponding screen files
from `47c5351`; require behavioral assertion failures, not compilation failures.
Restore the repaired screens and require the same tests to pass. The browser
suite includes `tool/web_live_test/tests/audited-games.spec.mjs` and opens each
changed screen in Chromium/WASM and Firefox/JavaScript.

The two historical skips in `test/logic/csp_generators_test.dart` are removed:
Star Forge now uses a constructive solution and Crossword has its table-assisted
path. Their existing three-minute per-case bounds remain; both checks must run
in the full suite rather than being treated as passing while skipped.

## Limits

All 48 games have generation/session coverage; 17 still lack a dedicated focused
round audit. This change audits the modified areas, rather than declaring those
17 complete. No physical-device or child playtest data are available. Algorithms,
A/B selection, fallbacks, scoring, pars and authored order remain intact.
