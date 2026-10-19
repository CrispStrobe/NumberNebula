# Molecule Builder round audit

Implemented version **1.5.39+55**. The preceding verified publication is
[Relic Assembly / PR #64](https://github.com/CrispStrobe/NumberNebula/pull/64),
version **1.5.38+54**. This implementation still needs exact-source analysis,
native, generation, browser and deployment validation before publication.
Test definitions alone do not establish a passing build.

## Reproduced baseline contracts

A bounded original-API probe against the preceding screen passed real direction
input, completed Undo and a subsequent move. Four actual assertions failed:
a held pan charged a replacement round one move; restoring during a slide left
an atom 278 pixels from its current model position; a late slide completion
overwrote accepted Undo; and a completed last-legal win still returned a terminal
capture map. Compilation errors, timeouts and skips were absent. These are four
failing contracts, not a count of independent root causes.

An expanded diagnostic also reproduced nonmoving intermediate slide geometry,
stale delayed dialogs and controls, silent-terminal restoration failures, motion
cleanup failures and phone header overflow at doubled text size. It completed
all 43 original-API cases, with eight passing cases and 35 nonpassing cases.
Some cases overlap, and raw exception review is required before classifying each
as a behavioral failure. Its first repair comparison was incomplete, so it is
not final-source passing evidence. Later test revisions wait for rendered
framework frames before pressing newly enabled controls; they keep the actual
position, count and outcome assertions. Validation scope and final source hashes
belong in the repair PR.

A [final uncommitted diagnostic](https://numbernebula-wu2fzijd6-crispstrobes-projects.vercel.app/diagnostic-proof.json)
passed strict analysis and all **53 cases**, including three randomized orders
(71, 211, 1009), zero skips. Raw event counts and source/mixin/test hashes were
independently verified. Its 48 original-API cases against the preceding screen
and session mixin passed nine cases and failed 39 assertions, with no compilation
failures or timeouts. These overlapping contracts are not 39 independent bugs.
The five loader seams are separate repair-side evidence. This remains an
uncommitted diagnostic, not a claim that final pushed-head checks passed;
report deployment protection applies.

## State, movement and persistence

Every restore, reset and authored level change replaces the round identity.
Actual pointer recognizers detach with their round; retained controls and pan
payloads check current ownership. Selected atoms must be current model instances,
even when replacement atoms reuse the same IDs. Slide completion belongs to its
round and exact atom. Direction input still slides until a wall or another atom.

The current model commits endpoint, count and history together. Its 200 ms slide
is visual interpolation over a static atom child. An interrupted slide has not yet
reported an outcome, so capture serializes a coherent **pre-move** board, count
and history. Restoration can replay that input without charging twice or losing
an unreported final-move win. Completed moves and Undo penalties remain saved.
Undo ignores input during a pending slide; completed Undo retains its **+2** cost.

A last legal correct move wins before exhaustion is checked. A last legal
incorrect move loses once; an Undo penalty can also exhaust the allowance.
Solved or exhausted restores are silent terminal rounds with reachable retry,
null capture and no replayed reward or previous round summary. Pending success,
failure, owned routes and retained dialog actions cannot affect a replacement or
covering route. Dialog builders and disposal also check ownership.

The shared session mixin adds an opt-in restore identity. Molecule opts in so
an obsolete storage read or accepted/declined resume dialog cannot overwrite or
clear a newer round. Other games retain the default identity; full shared-suite
and all-game session checks are required for this change.

## Motion, layout and preserved rules

Initial and mid-animation reduced motion complete meaningful movement while
stopping decorative pulse, success scaling, particles and their ticker. Slide
position rebuilds independently of decorative pulse; static atom children and
grid cells are reused during animation. These are rendering contracts, not
physical-device FPS or battery measurements.

The phone header wraps; compact content and wide side controls scroll without
shrinking board cells or controls. English and German 390×844 and 390×500 at text
scale 2 exercise actual selection, movement, Undo and result retry.

The 30 bundled levels, authored order, progression, loader cache, parse rules,
fallback and generator algorithms remain. The score stays
`300 * grade + max(0, (moveLimit - movesMade) * 10)`. Quality retains the half-limit
reference, which is **not a proven optimum**. No child-facing pars are retuned.

## Test inventory and remaining evidence

`test/widgets/quantum_molecule_round_test.dart` defines **48 original-API
contracts** and **five controlled-loader seam cases**. Counterfactual runs select
`contract:` names; the old screen does not have the optional loader parameter.
The seam supplies a controlled future to the same initial await used in
production. It tests current cached-level failure and obsolete success/failure
after replacement or disposal; it does not pretend to measure actual asset I/O
or replace independent level-parser tests.

The native workflow includes this file. The browser suite opens the real
Molecule board in Chromium/WASM and Firefox/JavaScript, bringing its inventory
to 16 audited games across both engines. Exact pushed-head and merged-main
checks, full native tests, all-game generation/capture, the shipping WASM/JS
wrapper, complete browser reports and canonical deployment evidence are required.

The preceding 46-case GitHub artifact browser job completed in **19m47s** with
zero observed retries, close to its former 20-minute limit. The expanded 48-case
job has a bounded 25-minute allowance, and publication plus hosted checks have
35 minutes including cloud-slot waits. Per-test timeouts, performance thresholds,
worker count and test inventory remain intact; no extra parallel jobs were added.
This change does not claim a performance improvement.

Twelve registered games remain for dedicated round audits; Gridlock is next in
[the task board](../REMAINING_WORK.md). No physical-device or child-playtest
evidence is claimed, and this audit does not prove every possible defect absent.
