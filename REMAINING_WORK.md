# Remaining Work -- Game Quality Fixes

Status as of 2026-09-17.

## 2026-09-14 SESSION

### Games withheld from players (`debugOnlyGames` in `game_pool.dart`)

These are hidden from the game menu and never picked for a mission. They stay
playable once the debug menu is unlocked (tap the home screen title 7x), and
shipping one again means deleting its key from that set -- nothing else.

| Game | Why it was pulled | State |
| --- | --- | --- |
| Sternen-Schmiede (`star_forge`) | Generation searched for a magic constant that cannot exist, so all 200 CSP attempts timed out (~16 min of spinner), then fell back to a layout whose lines did not sum equally | **Fixed** -- needs a play-through |
| Ionen-Ring (`ion_chain`) | Legal moves could strand the player with an unfillable slot (45% of puzzles), with no feedback; the same rule could also be listed twice | **Fixed** -- needs a play-through |
| Relikte-Puzzle (`relic_assembly`) | Pieces could only be removed by an undiscoverable long-press; the generator's random rotation was dead state, so no puzzle ever needed rotating | **Fixed** -- needs a play-through |
| Galaktischer Markt (`galactic_market`) | There was no losing condition at all, so tapping every coin in turn solved it for free and the arithmetic was never worth doing | **Fixed** -- needs a play-through |
| Würfel-Scanner (`cube_scanner`) | Nothing on the board said opposite faces sum to 7, nor that the hidden faces are exactly the ones opposite the visible ones | **Fixed** -- needs a play-through |
| Void-Überquerung (`void_crossing`) | The onboarding described the conflict rule in words and then told the player to look it up elsewhere | **Fixed** -- needs a play-through |

All six are fixed in code and all six are still gated. The only thing between
them and players is someone playing each one once; shipping one is deleting its
key from `debugOnlyGames` in `lib/features/missions/data/game_pool.dart` and
nothing else. Unlock the debug menu with seven taps on the home screen title.

`game_pool.dart` is the source of truth for what is gated and why -- each key
there carries its own note. This table is a summary of it and can go stale, as
it did: it listed the last three as "Not started" for three commits after they
were fixed.

### Fixed and shipping

1. **Alien-Tribunal** — every puzzle was the hardcoded `TLT` fallback. Statements
   about one other delegate only assert whether two share a role, so flipping
   everyone is always a second valid solution and the uniqueness check could
   never pass. Added statements about pairs and about tallies, which break that
   symmetry; the verdict pattern is now drawn first and held fixed while
   statements are re-rolled, so all patterns appear evenly.
2. **Sternkarten-Scan** — a quick sweep reports pointer positions several cells
   apart and the code kept only those, leaving gaps in the selection; correct
   sweeps matched nothing. The run is now derived from its two endpoints
   (`StarChartScanPuzzle.lineBetween`), which also lets the player drag back.
3. **Orbital-Türme** — added an illustrated walkthrough (the sightline rule is
   drawn, not just described) plus a "Spielanleitung" button to reopen it. The
   diagram uses `OrbitalTowersPuzzle.visibilityAlongLine`, the same rule the
   puzzle is scored by, so it cannot drift.
4. **Asteroiden-Duell** — "YOUR TURN" / "AI TURN" / "AI THINKING..." were
   hardcoded English; now localized.
5. **German i18n** — ~90 words across the file had lost their umlauts
   (`Lugner`, `Munzen`, `Hohe`, `Turme`, `fur`, `mussen`, ...). Swept and fixed.
   The onboarding overlay's "Got it"/"Next" buttons were hardcoded English too.

### Notes

- `OnboardingStep` now takes an optional `illustration` widget. Worth reusing
  for the other games whose rules are hard to convey in a sentence.
- Only `debugOnlyGames` gates a game. `calculationGames`, `puzzleGames` and the
  mission generator all filter through `missionGameKeys`, which excludes it.

---

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
