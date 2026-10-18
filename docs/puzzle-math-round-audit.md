# Puzzle Math round audit

Implemented version **1.5.35+51**. The preceding verified source
is [PR #60](https://github.com/CrispStrobe/NumberNebula/pull/60). Tests being present
does not establish a passing build; the repair PR must record exact-source checks.

## Rules and findings

The rectangular jigsaw generator, scores, mistake penalty and two-minute timer
allowance are retained. Pieces with equal arithmetic answers remain interchangeable;
each physical tile can occupy only one slot, and occupied slots cannot be overwritten.
Rotation must be zero for a correct placement. Mistakes remain editable and saved.

Integer-only drags and retained controls previously reached replacement rounds.
Drag payloads, targets, sources and controls now carry round identity, and callbacks
recheck the current round, tile availability and terminal state. Unknown tiles are
ignored. Retry and Back check the actual route before dismissing anything. The shared
result card checks mounted/current route before suggested-challenge navigation;
Puzzle Math additionally supplies a round guard. Normal suggestion input remains
covered, alongside covering-route and restored-round rejection.

The timer formerly waited an extra tick after reaching zero. It now expires on the
one-to-zero tick, stops on completion, respects pause and replaces its previous timer
on restore. Enabling it retains the existing 120-second reset policy. Restored
solved or enabled-timer expired boards offer retry without replaying an outcome;
a disabled-timer zero-time board stays playable. Terminal capture returns null.

Phone headers bound and scroll long instructions above separate timer controls; the tray scrolls with
pieces contained within their cells. Dialog content scrolls and translated win titles
wrap. Slot hover respects reduced motion initially and when changed mid-hover. Changing
the setting replaces its implicit animation state so the rendered gradient snaps
immediately, rather than merely changing the configured duration.
Physical rotation remains a gameplay action.

## Validation contract

The 36-case focused suite is `test/widgets/puzzle_math_round_test.dart`. It exercises actual
drag, rotate, remove and retry input, equal-answer conservation, stale callbacks and
pointer gestures across restore, terminal outcomes, persisted mistakes, pause and
timer replacement, English/German 390×500/844 phones at text scale 2, and reduced motion.
Existing `test/games/puzzle_math_clock_test.dart` requires a clock tick to reuse the
board image widgets. Arithmetic fixture answers are checked independently.

Run remotely with the pinned SDK:

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test test/widgets/puzzle_math_round_test.dart test/games/puzzle_math_clock_test.dart test/games/puzzle_math_game_test.dart --concurrency=1 --reporter expanded
flutter test --concurrency=2 --reporter expanded
bash tool/build_web.sh
```

For before-fix negative controls, retain the focused tests and substitute only
`lib/features/games/screens/puzzle_math_game.dart` from the preceding main commit
`365cc8f`. Require behavioral assertion failures, not compilation errors. Restore
the repair and require all focused cases plus reordered runs to pass. All-game
native and pure generation, capture/replay, retained render fallbacks, WASM and
JavaScript builds and both-engine hosted checks remain required.

Browser smoke opens Constellation Puzzles and checks its actual tile controls in
Chromium/WASM and Firefox/JavaScript. Retain the pinned SDK's single-thread Skwasm
mitigation and original selectable multi-thread path described in the
[Codebreaker audit](codebreaker-round-audit.md).

There are 33 implemented dedicated round suites and 15 games remain to inspect.
No physical-device, child playtest or new store-release evidence is claimed.
