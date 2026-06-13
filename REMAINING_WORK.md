# Remaining Work -- Game Quality Fixes

Status as of 2026-06-13.

---

## RESOLVED ISSUES (verified in code)

### Previously BROKEN/UNPLAYABLE — now fixed:

1. **Launch Sequence** — ~~dark blue on dark blue~~ Fixed: bright ship card colors with glowing borders. Container background lightened (0xFF253A5E).
2. **Creature Forge** — ~~taps don't register~~ Fixed: `HitTestBehavior.opaque` added. Clear combinatorics gameplay.
3. **Galactic Market** — ~~clicks don't register~~ Fixed: `HitTestBehavior.opaque` added. Division-based coin puzzle.
4. **Warp Fold** — ~~animation meaningless~~ Fixed: fold animation directly connected to puzzle, shows fold lines, cut holes, answer options.
5. **Ion Chain** — ~~trivial puzzles~~ Fixed: CSP attempts increased 100→500, fallback now uses backtracking with 2 rules instead of trivial alternating pattern.

### Previously NEEDS IMPROVEMENT — now fixed:

6. **Cube Scanner** — ~~flat tiles~~ Fixed: isometric 3D rendering with shading. Auto-advance on correct answer.
7. **Sector Painter** — ~~overlapping circles~~ Fixed: overlap avoidance algorithm (radius ≤ 40% of min inter-node distance).
8. **Nebula Matrix** — ~~zones not rendered~~ Fixed: zone tints and thicker borders on zone boundaries.
9. **Circuit Repair** — ~~no difficulty progression~~ Fixed: grade 1-2 → 4 digits (HH:MM), grade 3+ → 6 digits (HH:MM:SS). Attempts scale 5→3.
10. **Hull Plating** — ~~rotation buggy~~ Fixed: rotation cycles 0-3, ghost preview, placement validation.
11. **Relic Assembly** — ~~needs testing~~ Fixed: numbers, drag-drop, rotate on long-press, green/red edge-match feedback.
12. **Asteroid Duel** — ~~basic visuals~~ Fixed: procedural jagged asteroids with gradients, shadows, 35-70px sizing.
13. **Gravity Well** — ~~weight labels too small~~ Fixed: font sizes increased 8→11 / 10→13px, box sizes enlarged.
14. **Hive Station** — ~~100% hints at grade 1-2~~ Fixed: reduced to 90% at grade 1, 80% at grade 2. Actual deduction now required at all grades.
15. **Vault Cracker** — ~~text-only clues~~ Fixed: Wordle-style colored digit boxes (green/yellow/gray) for each guess attempt. 6-guess limit with bonus for fewer guesses.
16. **Xenobiology Lab** — ~~slider trial-and-error~~ Fixed: live-computed totals shown alongside targets with color feedback (red=mismatch, green=match). Player can now reason mathematically.

---

## REMAINING KNOWN ISSUES (low priority / polish)

1. **Warp Fold** — animation is functional but not a true 3D paper-folding effect. Current 2D approach works and is connected to puzzle logic. A 3D perspective fold would be ideal but is cosmetic.

2. **Hive Station** — unique-solution verification at reduced hint rates not implemented. Some puzzles at grade 3+ may have multiple valid solutions. Players can still win by finding any valid marking.

3. **Ion Chain** — CSP fallback still exists as absolute last resort (simple alternation). In practice, the 500-attempt CSP + 2-rule backtracking fallback should almost never trigger.

---

## VERIFICATION NEEDED

All recently fixed games would benefit from **manual browser testing** to verify:
- Gestures (tap/click) register on Flutter web
- Visuals are visible (contrast against SpaceBackground)
- Game puzzles generate correctly at all difficulty levels

---

## COMPLETED (cumulative)

- 49 games implemented from Kanguru competition analysis
- 70+ test files (774+ tests, all passing)
- Comprehensive game balance audit (GAME_BALANCE_AUDIT.md)
- Star rating normalization system (1-3 stars per game)
- SRI integration for all arithmetic games
- Move limits for no-lose puzzle games
- Grid Filler difficulty scaling (10×10 to 45×45)
- Score:0 bugs fixed in 4 games
- Wordle-style feedback in Vault Cracker
- Live-computed totals in Xenobiology Lab
- Ion Chain puzzle generation hardened

## KEY FILES

- `GAME_BALANCE_AUDIT.md` — systematic audit of all 49 games
- `DESIGN_BRIEFS.md` / `DESIGN_BRIEFS_ROUND2.md` — approved redesign specs
- `GAME_IDEAS.md` — original 1544-problem analysis
- `GAME_THEMING.md` — space narrative, i18n strings
- `VISUAL_TEMPLATE.md` — mandatory UI patterns
