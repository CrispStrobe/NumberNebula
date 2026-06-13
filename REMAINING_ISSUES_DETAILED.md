# Complete Issue List

Updated 2026-06-13. All issues verified against current codebase.

---

## Games That WORK (confirmed)

All 49 games are functional. The following had reported issues that have been resolved:

| Game | Was | Now |
|------|-----|-----|
| Dark Matter Grid | OK | OK |
| Star Forge | OK, scaling fixed | OK |
| Comm Relay | OK after slider fix | OK |
| Alien Tribunal | OK after loop fix | OK |
| Orbital Towers | OK, drag-drop added | OK |
| Gravity Well | Weights too small to read | Fixed: font 11-13px, larger boxes |
| Chrono Repair | Stepper buttons added | OK |
| Launch Sequence | Dark on dark, invisible | Fixed: brighter container, vivid card colors |
| Creature Forge | Clicks don't register | Fixed: HitTestBehavior.opaque |
| Galactic Market | Clicks don't register | Fixed: HitTestBehavior.opaque |
| Warp Fold | Animation meaningless | Fixed: animation connected to puzzle |
| Ion Chain | Trivial puzzles | Fixed: CSP hardened, fallback improved |
| Cube Scanner | Flat tiles, extra click | Fixed: 3D isometric, auto-advance |
| Vault Cracker | Text-only clues | Fixed: Wordle-style colored digits |
| Hive Station | 100% hints = trivial | Fixed: 90/80/70/60% by grade |
| Sector Painter | Overlapping circles | Fixed: overlap avoidance algorithm |
| Nebula Matrix | Zones not rendered | Fixed: zone tints + thick borders |
| Circuit Repair | No difficulty progression | Fixed: 4-digit → 6-digit by grade |
| Hull Plating | Rotation placement buggy | Fixed: rotation + ghost preview |
| Relic Assembly | Needs testing | Fixed: drag + rotate + edge feedback |
| Xenobiology Lab | Slider guessing | Fixed: live computed totals shown |
| Asteroid Duel | Basic visuals | Fixed: procedural jagged asteroids |

---

## Remaining Low-Priority Polish

| Game | Issue | Priority |
|------|-------|----------|
| Warp Fold | 2D fold animation (works but not 3D perspective) | Low — cosmetic |
| Hive Station | No unique-solution verification at hard levels | Low — gameplay still valid |
| Ion Chain | CSP fallback still exists as last resort | Low — rarely triggers now |

---

## Game Balance Audit Results (2026-06-12)

See `GAME_BALANCE_AUDIT.md` for the full systematic audit. Key fixes applied:

- **6 critical bugs fixed:** Bubble Math missing outcome, 4 score:0 bugs, Puzzle Math legacy constructor
- **SRI gaps filled:** Cargo Bay + Gravity Well now report MathProblems
- **Scoring normalized:** `scoreToStars()` with per-game thresholds, `bestStars` tracking
- **Difficulty scaling added:** Grid Filler scales 10×10 → 45×45
- **Move limits added:** Codebreaker, Nebula Matrix, Orbital Towers, Star Forge (2× empty cells)

---

## Key Learnings

1. Agents produce code that compiles but has poor gameplay quality
2. Always read the actual Kanguru PDF before designing a game
3. Always test with browser after each change
4. `HitTestBehavior.opaque` needed on GestureDetectors for Flutter web
5. `ListWheelScrollView` doesn't work well on Flutter web — use tap steppers instead
6. Dark-on-dark is invisible on SpaceBackground — use distinct container colors
7. Every game needs visible instructions, clear narrative, proper contrast
8. Scoring must be normalized across games — raw scores are meaningless for comparison
9. Every arithmetic game must report MathProblems for SRI tracking
10. No-lose games need move limits or quality gates to prevent trivial level-ups
