# Practice rules and cross-game difficulty

## Current candidate

Version **1.5.41+57** corrects rules shown by the common **Practice / Üben**
screen and the introductory Wormhole progression. This is a candidate under
validation, not a verified deployment. It is separate from the pending Gridlock
repair in [PR #66](https://github.com/CrispStrobe/NumberNebula/pull/66).

The shared tutorial marked each game's old instruction overlay as seen, while
showing only one miniature arithmetic question. `GameCoaching.practice()` did
not include its strategy/rule text. The shared hint dialog could also replace
that text with the generic “use the visible rules” strategy from an observation.
Neither case guarantees the player was ever taught the actual objective.

## Corrections

- Every registered lesson now presents its rule text before asking the practice
  question. Existing players get the corrected tutorial once using a new seen
  key; replay remains available. Capture/render/performance fixtures that bypass
  onboarding use the new key. A migration test deliberately retains the old key.
- **Asteroid Hunter / Asteroiden-Jäger** teaches ascending **results**, irrespective
  of object positions. Its example compares three expressions, chooses the
  smallest result first, and explains why a correctly calculated larger result
  is still the wrong next shot. Bubble Math teaches its same ordering rule.
  Live hints use the remaining target sequence and current index.
- **Wormhole Activator / Wurmloch-Aktivator** teaches that **all three sides** must
  equal the displayed frequency, with both corners included in each sum. A
  six-node triangle diagram and three worked sums demonstrate shared corners.
  Live hints respect current placements, the finite tray and all three sums;
  a one-gap side shows the subtraction, rather than dumping internal maps.
- **Signal Triangulation** now practices exact versus misplaced symbols. Its
  former sum question described a rule the game does not have. Hive terminology
  now describes energy cells and six neighbours rather than hazards copied from
  another game. Jigsaw instructions describe matching results and upright pieces.
- Several other lesson strategies now explicitly name the objective, including
  shared star-arm sums, tower visibility, molecule formation, Gridlock's exit,
  pushing every box onto a goal, robot programming, full coverage, matching tile
  edges and switching all Dark Matter cells on. These wording changes are not a
  claim that every remaining miniature example has been independently audited.
- Shared arithmetic generation uses the **effective** Easy/Normal/Challenge grade,
  matching the grade passed to game screens, while preserving the official
  profile grade, explicit overrides, custom settings and spaced review.

## Difficulty evidence and policy

The same grade/level is not evidence of equivalent difficulty across mechanics.
Jigsaw uses independent calculation-and-match tasks; Wormhole adds intersecting
sum constraints, shared corners and distractors. Increasing all of those together
was an abrupt introduction.

A bounded pure-Dart check ran **12 paired profiles**: grades 1/3, levels 1/3,
seeds 31/97/211. The actual legacy/candidate/auto generators produced solvable
boards. Following both-language introductory hints completed the actual model's
win predicate without changing snapshots during hint generation. All 12 sampled
legacy features and independent Jigsaw expression lists matched the pre-edit
baseline. This is a small structural check, not full Flutter validation or a
measurement of children's success, time or frustration.

Example: grade 3, level 3, seed 31:

| Structural measure | Existing Wormhole path | New introductory path |
| --- | ---: | ---: |
| Nodes per side | 5 | 4 |
| Missing values | 5 | 2 |
| Tray choices | 8 | 2 |
| Target sum | 61 | 42 |
| Repeated one-gap deductions solve the board | No | Yes |

Jigsaw has nine independent tasks in this profile. No equality of felt difficulty
is inferred from these counts. Jigsaw has not been made harder to hide the gap.

The new Wormhole profile starts with a small number of blanks, no distractors for
levels 1–4, and a verified chain of one-gap deductions. Later levels gradually
increase topology, missing values and distractors. The prior generator remains
selectable with `GAME_ALGORITHM_PATH=legacy`; `candidate` and `auto` use the guided
profile. The exact equal-side solver and prior fallback remain. Saved rounds keep
their captured board and rules instead of being regenerated into the new profile.

## Executable validation and next lanes

1. Run strict analysis and the focused Flutter files:
   `test/widgets/all_games_coaching_test.dart`,
   `test/widgets/practice_rule_shell_test.dart`,
   `test/logic/board_hint_engine_test.dart`, and
   `test/logic/practice_difficulty_test.dart`. Verify actual wrong/correct answers,
   rules before answering, real shared hint stages, the old-seen-key migration,
   German/English short phones at doubled text size and pause/outcome records.
2. In the existing pure CI job, run
   `dart --packages=tool/pure_dart/.dart_tool/package_config.json tool/check_practice_difficulty.dart --output practice-difficulty.json`.
   This checks 360 paired grade/level/seed profiles, all three algorithm modes,
   actual solvability, introductory hint replay and structural progression, then
   retains the raw comparison artifact. The small `--smoke` mode is the only
   local generation check completed so far. Run full generation/calibration and
   capture/replay remotely, not on a busy shared host.
3. Verify the exact pushed head's complete native/build/browser/deployment checks,
   then repeat on merged main and verify the published artifact. Reconcile version
   order with PR #66 before merging; do not call queued checks successful.
4. Audit the remaining practice examples against each screen's actual input and
   win predicate. For each game, document objective, legal action, ordering or
   shared constraints, one valid example, one misleading/wrong example and both
   translations. Replace generic arithmetic quizzes when they fail to exercise
   that game's mechanic. Test the real rendered lesson, not just nonempty text.
5. Extend the paired structural report to all 48 games using the shared pure
   generators. Compare workload components at the same effective grade/level,
   including givens, choice counts, dependency depth, operations and time pressure.
   Reproduce spikes before changing a profile, retain old/new paths, and use
   actual child playtests to calibrate felt difficulty when those become available.
   Existing heuristic scores alone do not establish fair cross-game tuning.
