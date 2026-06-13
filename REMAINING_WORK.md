# Remaining Work -- Game Quality Fixes

Status as of 2026-06-13. All major issues resolved.

---

## ALL REPORTED ISSUES RESOLVED

### Previously BROKEN/UNPLAYABLE — all fixed:

1. **Launch Sequence** — bright ship card colors, container background lightened.
2. **Creature Forge** — `HitTestBehavior.opaque` added. Clear combinatorics gameplay.
3. **Galactic Market** — `HitTestBehavior.opaque` added. Division-based coin puzzle.
4. **Warp Fold** — fold animation connected to puzzle logic.
5. **Ion Chain** — CSP attempts 500, fallback uses backtracking with 2 rules.

### Previously NEEDS IMPROVEMENT — all fixed:

6. **Cube Scanner** — isometric 3D rendering, auto-advance on correct answer.
7. **Sector Painter** — overlap avoidance algorithm.
8. **Nebula Matrix** — zone tints and thicker borders on zone boundaries.
9. **Circuit Repair** — grade 1-2 → 4 digits, grade 3+ → 6 digits. Attempts 5→3.
10. **Hull Plating** — rotation cycles, ghost preview, placement validation.
11. **Relic Assembly** — numbers, drag-drop, rotate, green/red edge-match feedback.
12. **Asteroid Duel** — procedural jagged asteroids with gradients and shadows.
13. **Gravity Well** — font sizes 11-13px, enlarged boxes.
14. **Hive Station** — 90/80/70/60% hints by grade + unique-solution verification.
15. **Vault Cracker** — Wordle-style colored digit boxes, 6-guess limit.
16. **Xenobiology Lab** — live-computed totals with color feedback.

### Balance Audit Fixes (all 49 games):

17. **Bubble Math** — added missing `reportOutcome()` + SRI reporting.
18. **Arithmetic Square, Perspective Puzzle, Star Loader, Puzzle Math** — fixed score:0 bugs.
19. **Hyperdrive Gates** — fixed score:0, accumulates in `_levelScore`.
20. **Cargo Bay Arranger, Gravity Well** — added SRI MathProblem reporting.
21. **Grid Filler** — difficulty scaling 10×10 → 45×45.
22. **7 puzzle games** — added move limits (Codebreaker, Nebula Matrix, Orbital Towers, Star Forge, Magic Triangles, Number Walls, KenKen).
23. **All games** — star rating normalization (1-3 stars), displayed on game menu cards.
24. **Arithmancer Duel** — fully audited, hybrid SRI+cognitive tracking confirmed working.

---

## MINOR REMAINING ITEMS (cosmetic only, all games fully playable)

1. **Warp Fold** — 2D fold animation works but 3D perspective would look nicer. Cosmetic.
2. **Galactic Market** — SRI reports 1 division problem per session. Could extract more arithmetic.

---

## COMPLETED (cumulative)

- 49 games implemented from Kanguru competition analysis
- 70+ test files (789+ tests, all passing)
- Comprehensive game balance audit (GAME_BALANCE_AUDIT.md)
- Star rating system: `scoreToStars()`, `bestStars`/`lastStars` in GameProvider, UI on game cards
- `StarRatingDisplay` widget for win dialogs
- SRI integration for all arithmetic games
- Move limits for all puzzle games (2× empty cells)
- Grid Filler difficulty scaling (10×10 to 45×45)
- Score:0 bugs fixed in 5 games
- Wordle-style feedback in Vault Cracker
- Live-computed totals in Xenobiology Lab
- Ion Chain CSP hardened (500 attempts + smart fallback)
- Hive Station unique-solution verification
- Localization for all new features (en + de)

## KEY FILES

- `GAME_BALANCE_AUDIT.md` — systematic audit of all 49 games with per-game catalog
- `DESIGN_BRIEFS.md` / `DESIGN_BRIEFS_ROUND2.md` — approved redesign specs
- `GAME_IDEAS.md` — original 1544-problem analysis
- `GAME_THEMING.md` — space narrative, i18n strings
- `VISUAL_TEMPLATE.md` — mandatory UI patterns
