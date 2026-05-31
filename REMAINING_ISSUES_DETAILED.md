# Detailed User Feedback -- All Open Issues

Captured 2026-05-31 ~17:30 UTC from live testing session.

---

## Gravity Well
- Weight labels too small to read
- Weights should be sized proportionally to their value (bigger number = bigger icon)
- When player enters a value in the answer field, it should immediately appear on the scale visual
- Needs touch/drag UI -- slider or scroll wheel for weight values, not keyboard TextField
- The puzzle logic is NOW correct (multi-scale deduction) but the UI undersells it

## Cube Scanner
- Gameflow broken: must click "decoded" to progress, then AGAIN click "play again" -- one click too many
- Cubes still render as flat tiles, not as 3D cubes
- For stacked/row dice: touching faces should be COLOR-CODED (same color = same value) to make the constraint visual
- Face colors could differentiate the cubes

## Warp Fold
- Animation still doesn't meaningfully show paper being folded
- The red/dark overlay doesn't convey "folding" -- needs actual perspective fold effect
- The 5 answer grids are disconnected from the animation
- The whole game concept may need rethinking for web/mobile

## Sector Painter
- Overlapping circles (FIXED: now computes radius from min-distance)
- Still needs better visual differentiation between nodes

## Launch Sequence
- STILL invisible: dark blue on dark blue
- Ship cards and container blend with SpaceBackground
- Needs fundamentally different background color for the game area

## Ion Chain
- Rule naming fixed (shapes not colors)
- But puzzle logic may still generate trivial or contradictory puzzles
- Needs verification that rules actually constrain meaningfully

## Creature Forge
- Taps may not register on web (HitTestBehavior.opaque added but untested)
- Need Playwright verification

## Galactic Market
- Same click issue as Creature Forge
- HitTestBehavior.opaque added but untested

## Circuit Repair
- No difficulty progression -- always 4-digit clock
- Grade 3+ should use 5-6 digit numbers or multiple swaps

## Xenobiology Lab
- Gameplay is just "slide until green" -- not engaging
- Needs more puzzle-like mechanic

## Nebula Matrix
- Zones added to logic but game screen doesn't render zone borders yet
- Need to color-code zones in the grid UI

## General Issues
- Many games rely on keyboard TextField which doesn't work well on mobile/tablet
- All number inputs should offer slider/roller/tap alternatives
- HitTestBehavior.opaque may be needed on ALL GestureDetectors for Flutter web
