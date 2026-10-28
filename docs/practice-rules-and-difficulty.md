# Practice rules and cross-game difficulty

## Current candidate

Version **1.5.43+59** corrects rules shown by the common **Practice / Üben**
screen and the introductory Wormhole progression. This is a candidate under
validation, not a verified deployment. It is separate from the pending Gridlock
repair in [PR #66](https://github.com/CrispStrobe/NumberNebula/pull/66).

The shared tutorial marked each game's old instruction overlay as seen, while
showing only one miniature arithmetic question. `GameCoaching.practice()` did
not include its strategy/rule text. The shared hint dialog could also replace
that text with the generic “use the visible rules” strategy from an observation.
Neither case guarantees the player was ever taught the actual objective.

## Complete lesson and hint audit

All **48 registered games** now have a bilingual, mechanic-specific exercise,
three labelled action choices and an explanation of the correct choice and its
distractors. These replace the old generic arithmetic questions. The pure lesson
catalog is `lib/features/games/models/practice_lesson_catalog.dart`; its keys must
exactly match `lib/features/games/game_keys.dart` and the Flutter registry.

The evidence inventory is split into three readable batches:

- [Numeric and constraint games](lesson-audit-numeric.md): 16 games.
- [Spatial and manipulation games](lesson-audit-spatial.md): 16 games.
- [Action and deduction games](lesson-audit-action.md): 16 games.

The shared tutorial shows the actual rules before the question. Choices can now
be actions or explanations instead of unrelated numbers. Existing numeric
onboarding callers retain their behavior. A new seen key presents the corrected
lessons to existing players; the practice button always permits replay.

Dedicated Star Forge, Orbital Towers and Number Walls hint buttons use the same
audited guidance, attached to their existing asynchronous solver moves. Their
demonstration callbacks retain round guards. Star Loader’s short hint explicitly
teaches pushing onto targets and the absence of pulling.

Current-board hints use actual visible clues and player placements. They explain
ordering, calculation, legal manipulation or a useful deduction rather than
printing internal maps or pretending the stored answer is a deduction. Numeric,
spatial and action guidance live in their corresponding `*_hint_guidance.dart`
services. Existing constraint solvers, verified moves and fallback algorithms
remain available. Replacement observations do not inherit a solver's verified
flag or target. A missing live hint is explicitly labelled as a practice example,
never presented as the current board.

Important corrections include ascending asteroid results, all three equal
triangle sides, code-position feedback, left-to-right arithmetic, shared-symbol
assignments, full-row Cargo clearing versus a bonus sum, Ion ring wraparound,
Molecule stopping rules, Gridlock axes and every applicable cipher type. Hidden
solution poisoning checks cover games where snapshots contain undisclosed
answers. These are source and fixed-fixture checks, not child playtest evidence.

Shared arithmetic generation uses the effective Easy/Normal/Challenge grade,
while preserving the official profile grade, explicit overrides, custom settings
and spaced review. The guided introductory Wormhole path remains selectable
alongside the legacy path.

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

## Publication preparation

Version **1.5.43+59** additionally fixes long-choice reachability on short phones
at doubled text size. The whole lesson scrolls, the header wraps, and tests treat
missed button taps as failures. Retry feedback now refers to a choice, rather
than demanding a number for nonnumeric exercises.

Full calibration exposed three CLI/screen snapshot differences: Relic, Molecule
and Star Loader. Guidance now accepts their actual shared-generator snapshots,
while prioritizing current placements and progress from restored screen saves.
New bilingual parity and hidden-answer checks cover these representations.

[GitHub Pages packaging](github-pages.md) reuses the browser-tested build with
a verified project base path. Publication uses separate Pages hosting checks;
Vercel's isolation-header assertions remain strict. Real manual store uploads
also invoke the existing TestFlight-only distribution lane after signing and
uploading; dry runs remain signing checks. Current upload and publication states
must be verified from the corresponding run, not inferred from configuration.

## Completed bounded checks

The final fixed-fixture checkers passed **879 assertions**: 295 numeric,
312 spatial and 272 action/catalog checks. They cover all 48 lesson entries and
both languages. The 12-profile difficulty smoke comparison also passed. The focused native checks passed **121 cases**: 115 shared lesson/hint/difficulty
cases and six dedicated hint-dialog cases, including stale demonstrations after
restore. These results do not imply that the pending full native/browser checks
passed.

The preceding narrower candidate's
[pure run](https://github.com/CrispStrobe/NumberNebula/actions/runs/39262171407)
passed, but does not validate the expanded rewrite. Its
[native run](https://github.com/CrispStrobe/NumberNebula/actions/runs/39262171405)
failed on two analyzer infos before tests; both reported issues were corrected
in this rewrite. The replacement exact-head checks must be verified separately.

## Executable validation and next lanes

1. Run the three bounded pure checks, using the existing pure package config:
   `tool/check_numeric_lesson_contracts.dart`,
   `tool/check_spatial_lesson_contracts.dart`, and
   `tool/check_action_lesson_contracts.dart`. They use fixed examples, actual pure
   validators where available, wrong-choice witnesses, current partial states,
   snapshot immutability and hidden-answer independence. They do not generate
   large samples or substitute text-presence checks for semantic checks.
2. Run `test/widgets/all_games_coaching_test.dart` remotely. All 48 lessons must
   accept real wrong/correct button input in both languages, including short
   phones at doubled text scale. Run `practice_rule_shell_test.dart` for actual
   shared hints, pause, old-seen-key migration and learning-record invariants.
   Retain the focused board-hint and difficulty tests, then run the full required
   native checks. Pure fixtures cannot prove Flutter layout or gesture behavior.
3. In the existing pure CI job run the three contract checks and the 360-profile
   `tool/check_practice_difficulty.dart` comparison. Keep raw comparison artifacts.
   The completed 12-profile smoke comparison is structural evidence only.
4. Verify the exact pushed head's native, browser and deployment checks, then
   repeat on merged main. Keep queued, failed, skipped and passed runs distinct.
   Preserve [Gridlock PR #66](https://github.com/CrispStrobe/NumberNebula/pull/66)
   and reconcile versions before merging.
5. Fix the remaining displayed-expression ambiguities documented in the numeric
   audit: show grouping for sequential evaluation and make Cryptex's difference
   and quotient convention explicit. Retain working algorithms; add rendered
   examples matching the actual evaluator before changing math behavior.
6. Extend paired workload comparison to all 48 games with the shared pure
   generators, running remotely. Compare dependency depth, givens, choices,
   operations and time pressure separately. Reproduce each spike before tuning,
   preserve old/new paths, and use child playtests to calibrate felt difficulty
   when available. Heuristic scores alone do not establish equal difficulty.
