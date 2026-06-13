# Complete Issue List

Updated 2026-06-13. All issues verified and resolved.

---

## All 49 Games — Status: WORKING

Every reported issue has been fixed. Summary of fixes applied:

| Game | Was | Fix Applied |
|------|-----|-------------|
| Launch Sequence | Dark on dark | Container lightened (0xFF253A5E), bright card colors |
| Creature Forge | Clicks don't register | HitTestBehavior.opaque |
| Galactic Market | Clicks don't register | HitTestBehavior.opaque |
| Warp Fold | Animation meaningless | Animation connected to puzzle logic |
| Ion Chain | Trivial puzzles | CSP 500 attempts + smart fallback |
| Gravity Well | Labels too small | Font 11-13px, larger boxes |
| Cube Scanner | Flat tiles | Isometric 3D rendering |
| Vault Cracker | Text-only clues | Wordle-style green/yellow/gray digit boxes |
| Hive Station | 100% hints = trivial | 90/80/70/60% by grade + unique-solution verification |
| Sector Painter | Overlapping circles | Overlap avoidance algorithm |
| Nebula Matrix | Zones not rendered | Zone tints + thick borders |
| Circuit Repair | No difficulty | 4-digit (grade 1-2) → 6-digit (grade 3+) |
| Hull Plating | Rotation buggy | Rotation + ghost preview fixed |
| Relic Assembly | Untested | Drag + rotate + edge matching verified |
| Xenobiology Lab | Slider guessing | Live-computed totals with color feedback |
| Asteroid Duel | Basic visuals | Procedural jagged asteroids with gradients |
| Bubble Math | No outcome reporting | reportOutcome + SRI added |
| Arithmetic Square | Score: 0 bug | Passes totalScore |
| Perspective Puzzle | Score: 0 bug | Passes finalScore |
| Star Loader | Score: 0 bug | Passes totalScore |
| Puzzle Math | Legacy constructor | Migrated to .win/.loss, score fixed |
| Hyperdrive Gates | Score: 0 bug | Accumulates in _levelScore |
| Cargo Bay Arranger | No SRI | Addition problems from row clears |
| Gravity Well | No SRI | Balance scale equations |
| Grid Filler | No difficulty scaling | 10×10 → 45×45 by grade+level |
| Codebreaker | No lose condition | 2× move limit |
| Nebula Matrix | No lose condition | 2× move limit |
| Orbital Towers | No lose condition | 2× move limit |
| Star Forge | No lose condition | 2× move limit |
| Magic Triangles | No lose condition | 2× move limit |
| Number Walls | No lose condition | 2× move limit |
| KenKen | No lose condition | 2× move limit |
| All 49 games | Scoring inconsistent | scoreToStars normalization (1-3 stars) |

---

## Minor Remaining Items

| Item | Priority | Notes |
|------|----------|-------|
| Warp Fold 3D animation | Cosmetic | 2D works, 3D would look nicer |
| Galactic Market SRI depth | Low | Reports 1 division problem, could extract more |

---

## Game Balance Audit

See `GAME_BALANCE_AUDIT.md` for the full per-game catalog of:
- Win/lose conditions
- Scoring formulas
- Difficulty scaling parameters
- SRI integration status
- Star rating thresholds

---

## Key Learnings

1. Agents produce code that compiles but has poor gameplay quality — require design briefs
2. Always read the actual Kanguru PDF before designing a game
3. Always test with browser after each change
4. `HitTestBehavior.opaque` needed on GestureDetectors for Flutter web
5. `ListWheelScrollView` doesn't work on Flutter web — use tap steppers
6. Dark-on-dark is invisible on SpaceBackground — use distinct container colors
7. Every game needs visible instructions, clear narrative, proper contrast
8. Scoring must be normalized across games — raw scores are meaningless for comparison
9. Every arithmetic game must report MathProblems for SRI tracking
10. No-lose games need move limits or quality gates to prevent trivial level-ups
11. Star ratings (1-3) are more meaningful to kids than raw point scores
12. Unique-solution verification matters for deduction puzzles at harder difficulties
