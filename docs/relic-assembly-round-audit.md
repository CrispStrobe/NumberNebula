# Relic Assembly round audit

Implemented version **1.5.38+54**. The preceding Hull follow-up is
[1.5.37+53 / PR #63](https://github.com/CrispStrobe/NumberNebula/pull/63).
Use this repair's exact-source analysis, native, generation and both-engine
browser/deployment evidence before treating it as verified. The 39 test
definitions alone do not establish a passing build.

## Initial reproductions

A bounded original-screen probe passed actual normal dragging and failed four
state/outcome assertions: old target/payload across restoration, retained removal
after re-placing the same tile index, pointer-down rotation transferring to a
same-frame replacement, and a duplicate-index save receiving a win. The same
five cases passed with the proposal. They completed without compilation errors,
timeouts or skips. These five cases are not the complete regression inventory.

The original screen at the probe's source is byte-identical to
[the baseline implementation](https://github.com/CrispStrobe/NumberNebula/blob/206aa972dede86a86012d71f797d7a1a20a614c0/lib/features/games/screens/relic_assembly_game.dart).
Broader original-screen comparisons must complete against the repair's final
original-API tests; source identity and scope belong in its repair PR.

An early configured diagnostic passed strict analysis, the first 38 cases and
both retained layout cases. Further inspection found a held generation-error
retry press transferring to a replacement failure when state changes coalesced.
The [follow-up diagnostic](https://numbernebula-k5oz2hz2y-crispstrobes-projects.vercel.app/retry-proof.json)
reproduced that state failure against
[`48500de`](https://github.com/CrispStrobe/NumberNebula/commit/48500deca4a1bf201eb5171b2976f81635100002),
then passed strict analysis, all **39** cases and both retained layout cases with
a round-specific retry key, zero skips. Raw event inventories and the before/fixed
source hashes were independently checked. This was an explicitly uncommitted
overlay, not final pushed-head validation; report deployment protection applies.
The original diagnostic's test style lint was corrected before its successful run.

## Rules and repairs

Both tray drag and select-then-tap placement remain available. Drags carry the
physical tile index, board round and displayed orientation. Placement rejects
old rounds, consumed/unknown indices and occupied targets. A returned tile is
available again; free rotations and all generator paths remain unchanged.
Filled controls capture a unique placement instance so removal and rotation
cannot transfer to a replacement, including re-placement of the same index.

Completion requires every physical index exactly once plus the existing edge
validator. A full incorrect board stays editable and saved; this game has no
invented loss condition or move budget. Removing one duplicate from a malformed
legacy save retains the existing tray accounting for every remaining copy.
Invalid restored selection is cleared; a valid unused selection stays playable.

Restoration resets old input and effects. Solved restores are silent terminal
rounds with retry, no replayed outcome and no previous round's summary. Result
routes belong to their round, including before their builder runs, under a
covering route and after game disposal. Retry, menu, summary and back callbacks
check their relevant round and route ownership.

Generation checks ownership after its production await, for both success and
failure. Obsolete completions cannot replace a restored or newer round. Current
failure offers a reachable real retry whose gesture identity belongs to that
round. A held press cannot activate a replacement error round, and the fresh
retry still generates a playable board. The testing seam supplies a controlled
future to that same await path; it does not replace the production generator.

The score remains `100 * grade + 25 * level`; placement par remains `rows * cols`
and quality remains `Perf.fromMoves(placements, placement.length)`. Rotation is
free. Removal retains spent placements, so replacement preserves its quality cost.
No child-facing threshold or generator algorithm is retuned.

## Test inventory and remaining validation

`test/widgets/relic_assembly_round_test.dart` defines **31 original-API cases**
with `contract:` names and **eight controlled async cases** with `seam:` names.
Original-screen comparisons use only `contract:` cases because the baseline has
no injection method. Missing APIs, compile errors and timeouts are not negative
behavioral evidence. The repair must pass all 39, not only the original-API subset.

The 2×2 fixture has solution indices `[1, 2, 0, 3]` and player rotations
`[0, 0, 0, 3]`, with independently checked internal joins, score 125 and par 4.
Actual controls exercise drag, selection, overlay/long-press/grid rotation,
removal, counted mistakes, persisted incorrect boards and terminal outcomes.
Other cases cover real held pointers, obsolete callbacks, unknown/consumed
payloads, restored selection, duplicate indices, owned routes, retry and a
suggested generated challenge followed by actual new input.

The async cases cover obsolete success/failure after restore, success/failure
after disposal, out-of-order generations, current failure and real retry, and a
successful replacement captured and saved after real input, plus actual held
retry input across coalesced failures. They are additional
repair-side evidence, not original-screen behavioral failures.

English/German 390×500 and 390×844 layouts at text scale 2 include a 3×3 board.
Instructions/content/actions scroll or wrap while the existing 56px phone and
90px tablet tray assertions remain. Initial/mid-hover and mid-success reduced
motion inspect actual painted effects and the owned dialog scale, excluding
framework route animations and button ripples. The ambient builder reuses the grid.

The native workflow includes the focused file. The release-browser suite opens
Relic and finds its actual localized rotation control in Chromium/WASM and
Firefox/JavaScript: 15 audited games across both engines. Complete exact-source
remote checks, all-game generation/capture, deployment verification and run links
are required before claiming this repair is a green baseline.

These checks do not establish physical-device performance, measured child
difficulty or the absence of every possible defect. Thirteen registered games
remain for dedicated round audits in D/E/F; Molecule Builder is next in
[the task board](../REMAINING_WORK.md).
