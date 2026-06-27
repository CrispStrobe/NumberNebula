# Remaining Work -- Game Quality Fixes

Status as of 2026-06-27. All major issues resolved.

## 2026-06-27 SESSION FIXES (20 items)

1. **Game Menu** — compact SRI bar + difficulty picker into single toolbar row
2. **Komm-Relais** — i18n for all hardcoded strings, difficulty curve (always 1-2 letters hidden)
3. **Rumpf-Panzerung** — drag placement uses piece center instead of top-left
4. **Tresor-Knacker** — draggable number palette for digit input
5. **Crew-Manifest** — i18n + uniqueness solver for puzzles, structured clues
6. **Alien-Tribunal** — i18n + grade 3 difficulty fix (4→5 people)
7. **Gravitationsfeld** — i18n + keyboard input + multi-scale puzzles
8. **Ionen-Ring** — capped ring size + fixed duplicate rules
9. **Start-Sequenz** — fixed missing key on ship cards (ReorderableListView)
10. **Orbital-Türme** — clue number alignment with grid cells
11. **Nebel-Matrix** — conditional zone instructions (only when zones exist)
12. **Galaktischer Markt** — level-based difficulty scaling
13. **Kreaturen-Schmiede** — fixed forbidden combo count bug + part variant labels
14. **Sternen-Schmiede** — color-coded star lines + visible magic constant
15. **Sektor-Maler** — edge crossing check prevents overlapping lines
16. **Würfel-Scanner** — roll-sequence puzzles for spatial reasoning
17. **Warp-Faltung** — replay animation button
18. **Relikte-Puzzle** — tap-to-rotate pieces on solution grid (long-press to remove)
19. **Bienen-Station** — investigated, confirmed solid (hex Minesweeper)
20. **CLAUDE.md** — created gitignored project env instructions

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

1. **Warp Fold** — 2D fold animation works but 3D perspective would look nicer. Replay button added. Cosmetic.
2. **i18n gaps** — some games still have hardcoded English strings in logic services (constraint text, section headers). Scan in progress.

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
