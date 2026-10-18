# Codebreaker round audit

Source version **1.5.34+50**. The preceding verified source is
[`e79a363`](https://github.com/CrispStrobe/NumberNebula/commit/e79a363a88c687f0ac9ec70834ca9a706b5576d6),
[PR #59](https://github.com/CrispStrobe/NumberNebula/pull/59).
The Codebreaker repair's PR records its exact-source validation and deployment;
these implementation notes alone do not establish a passing build.

## Rules retained

Both original and CSP generator implementations remain available as before.
Score formulas and move allowances are retained. The move reference counts
all symbols requiring placement, including a symbol revealed in another slot.
A three-placement fixture exposes the old two-symbol reference; restored saves
retain their spent moves and budget while correcting that reference. One tile
assigns a symbol and automatically fills that symbol's hidden occurrences.
Removing the assignment returns one tile. Repeated equal-valued tray tiles are
independent; assigning one must not erase another symbol's answer. Visible clues
are not user-answer positions. Extra occurrence copies supplied by the existing
pool generator remain available; this repair does not redesign that generator.

## Findings and contracts

- Integer-only drags carried no round identity. A drag overlay, old target or
  consumed tile could reach a replacement board. Payloads and controls now carry
  the round, and targets check budget, finite inventory and empty hidden slots.
- Placement removed every prior assignment with the same number. Two duplicate
  tiles assigned to different symbols could silently erase the first answer.
  Only the selected symbol is filled or removed, with exact tray accounting.
- The generator can reveal one occurrence while retaining other hidden slots
  for the same symbol. The old completely-hidden-symbol guard rejected those
  slots. Input now follows declared hidden positions, preserves visible clues
  and uses the independently verified placement count for its move reference.
- A full incorrect last move bypassed the loss condition. Correct last moves
  still win; exhausted incorrect boards lose once. Mistakes with remaining moves
  stay editable and saved. Learning records cannot be rewritten by old input.
- Captured terminal boards remained restorable as playable sessions. Solved and
  exhausted saves now offer retry without reporting another outcome or reward;
  terminal capture is null.
- Retry, Back and dialog callbacks could dismiss a covering route or act on a
  replacement round. They now check captured round and actual current route.
  Header and cell gesture identity changes on restore.
- Async generation could replace a restored board, including from an obsolete
  failure. Success/error completion checks the generation round. Controlled
  futures exercise the production completion path after restore and disposal.
- Drop effects and snackbars survived restore; drop motion ignored accessibility
  settings. Initial/mid-effect reduced motion, effect cancellation and restarting
  feedback after prior drops or restored wins are covered.
- The fixed-height tray could crowd the board off a short phone. Board and tray
  now have independently scrollable bounded areas; equations can scroll
  horizontally, and translated dialog actions wrap. Glow reuses stable equation
  children while its decoration remains animated.

## Reproduction and evidence

Use the pinned SDK and an isolated runner:

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test test/widgets/codebreaker_round_test.dart --concurrency=1 --reporter expanded
flutter test --concurrency=2 --reporter expanded
bash tool/build_web.sh
```

The focused suite uses actual pointer drops and removal/Back presses, validated
generator-consistent repeated/partially-visible-symbol fixtures, complete snapshots, persisted mistakes, win/loss retry,
covering routes, terminal restores, controlled pending generation and
English/German 390×500/844 phones at text scale 2. Browser smoke opens Codebreaker
in Chromium/WASM and Firefox/JavaScript. All-game generation and capture/replay
remain required; see [pure Dart calibration](pure-dart-calibration.md).

For negative controls, retain the new tests and substitute the screen from
`e79a363`. Run the `contract:` cases; require behavioral failures rather than
compilation failures. The separate `controlled generation:` tests use the new
future seam and are not counted as before-fix failures. Restore the repaired
screen and require the entire focused suite to pass. Failure totals count test
cases, not independent bugs.

This raises dedicated round-suite coverage to 32 registered games, leaving 16
for the [remaining lanes](../REMAINING_WORK.md). Passing automation does not prove
that every interaction or device-specific defect is absent. Physical-device and
child playtest evidence remain unavailable; no store release is claimed.

## Browser validation blocker and mitigation

Mixed Chromium runs exposed Skwasm memory traps in paragraph/glyph rendering,
including unaligned access and an out-of-bounds glyph image read. Flutter's
[confirmed shared glyph-cache race](https://github.com/flutter/flutter/issues/190039)
was repaired after the pinned SDK. The web bootstrap now requests single-thread
Skwasm; the existing JavaScript fallback and cross-origin isolation remain.
`?skwasmThreads=multi` explicitly selects the original worker path for controlled
comparisons. It is not the default while this SDK remains pinned.

The first-visit browser check asserts the actual Skwasm instance uses one thread.
Unexpected browser errors retain their stacks and still fail the suite. Treat
this as a mitigation under validation until the repair PR records exact-head
mixed-game, both-engine and hosted results. A matching upstream issue does not
prove that every observed browser failure has the same cause.
