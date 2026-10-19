# Hull Plating round audit

Implemented version **1.5.36+52**. The preceding verified baseline is
[1.5.35+51 / PR #61](https://github.com/CrispStrobe/NumberNebula/pull/61).
Use the Hull Plating repair PR's exact-source checks and deployed browser results
before treating this implementation as verified. Test definitions alone do not
establish a passing build.

## Reproductions and repairs

The old drag payload was a list index, allowing retained input to place a plate
in a reordered replacement round. Reusing an already consumed payload could
place the same physical plate twice; board coverage alone did not distinguish
that from a valid inventory. Drags now carry stable piece identity, round identity
and the orientation visible in their feedback. Targets reject obsolete, unknown
and used pieces. Completion requires the complete distinct physical inventory
and the original nonoverlapping board-coverage validator.

Rotation during a drag preserves that drag's displayed orientation. New tray
pieces follow the current rotation control. Center anchoring, grouped identical
shapes, the generator, available rotations and all alternative/fallback paths
remain unchanged.

Restoration resets obsolete input, ghost hover, drop effects, success animation
and queued feedback. Result routes belong to their round and are removed exactly,
including before their builder runs or beneath another modal. Disposal removes
only the owned result after the navigator unlocks. Old retry, menu and suggestion
callbacks cannot affect another round. Already solved saves offer retry without
reporting another outcome or showing an earlier round's performance summary;
terminal boards cannot be captured as playable saves.
Used inventory is derived from actual restored placements, including legacy
saves. Removing one legacy duplicate does not return a plate still on the board.

The score remains `100 * grade + 25 * level + 30 * pieceCount` and performance
remains `Perf.fromMoves(placements, pieceCount)`. Removing or clearing pieces
retains the placement count. Replacing a piece therefore retains its original
quality cost. Invalid drops do not consume a placement.

## Acceptance and evidence boundaries

`test/widgets/hull_plating_round_test.dart` exercises actual grouped-piece drags,
rotation, removal, clearing, replay after retry and persisted session state. It
also retains old callbacks and real pointer/drag gestures across restoration,
checks one-time outcomes and terminal saves, and tests result-route ownership.
The synthetic fixture uses physical IDs 10 and 20 so list indices cannot stand
in for identity. A 3×2 fixture checks rotated straight trominoes and their original
center anchor. Occupied cells, holes and out-of-bounds drops remain invalid.

English/German 390×500 and 390×844 phones at doubled text size exercise reachable
rotated pieces and retry controls. Instructions and tray content scroll; controls
wrap when necessary. Initial and mid-animation reduced-motion checks inspect the
actual hover decoration and placed-cell scale, separately from framework route
and button animations. Ambient glow reuses the board child.

The suite is included in `.github/workflows/ci.yml`; the release browser suite
opens Hull Plating and finds its actual rotation control in Chromium/WASM and
Firefox/JavaScript. Remote acceptance requires strict analysis, focused tests,
completed before-fix comparisons, the full native suite, all-game generation and
capture/replay, both release engines and hosted deployment checks. Record actual
run links, source identity and existing skips in the repair PR. A queued workflow
is not passing evidence. Previous builds do not verify a later source commit.

These tests do not establish physical-device frame rates, measured child
difficulty or the absence of every possible regression. Fourteen registered
games remain for dedicated round audits after this lane is validated. Relic
Assembly is next in lane C; D/E/F remain in [the task board](../REMAINING_WORK.md).
