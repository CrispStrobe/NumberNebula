# Complete Issue List for Fresh Session

Updated 2026-05-31 ~18:00 UTC. All Kanguru source references included.

---

## Games That WORK (confirmed by user testing)

1. **Dark Matter Grid** (Lights Out) -- OK
2. **Star Forge** (Magic Star) -- OK, scaling fixed
3. **Comm Relay** (Caesar cipher) -- OK after slider + partial decode fix
4. **Alien Tribunal** (Liar's table) -- OK after infinite loop fix
5. **Orbital Towers** (Skyscrapers) -- probably OK (drag-drop added)
6. **Gravity Well** -- "real riddle now" but weights too small to read
7. **Chrono Repair** -- just fixed with stepper buttons, needs testing

---

## Games That Need Fixes (roughly by priority)

### BROKEN / UNPLAYABLE

| Game | Issue | Kanguru Source | What It Should Be |
|------|-------|---------------|-------------------|
| **Launch Sequence** | Dark blue on dark blue, invisible | #10/2005_56 -- sort cards with min swaps | Bright colored ship cards, visible borders, distinct background |
| **Creature Forge** | Clicks don't register on web, purpose unclear | C6/2024_56 -- 4 caterpillar parts, count combinations | 3 rows of tappable parts, build creatures, count total combos (multiplication) |
| **Galactic Market** | Clicks may not register, too simple | A2/2023_34 -- 66 cent, 3 unknown same coins, deduce denomination | Show known + face-down coins, constraint text, select denomination |
| **Warp Fold** | Animation meaningless, disconnected from answer options | B7/2026_56, C2/2025_34 -- paper folding + cutting | Show paper shrinking as it folds, then cut, then 5 unfolded options |
| **Ion Chain** | Rules don't make sense, puzzle trivial | A6/2026_56 -- Luna's bracelet, shape constraints | Distinct shapes, visual constraint rules (crossed-out pairs), circular bracelet |

### WORKS BUT NEEDS IMPROVEMENT

| Game | Issue | Kanguru Source | Fix Needed |
|------|-------|---------------|------------|
| **Gravity Well** | Weight labels too small | C8/2025_34 -- balance scales with unknown weights | Bigger font, weights sized proportionally, live preview when entering values |
| **Cube Scanner** | Flat tiles not 3D, gameflow extra click | A7/2026_56 -- dice opposite faces sum to 7 | Isometric 3D rendering, auto-advance on correct answer, color-code touching faces |
| **Vault Cracker** | Text-only clues, no visual feedback | C1/2022_56 -- code lock with positional clues | Colored digit boxes (green/yellow/gray like Wordle) for each clue attempt |
| **Hive Station** | 100% hints = click all blanks = trivial | C7/2024_34 -- honeycomb adjacency numbers | Need unique-solution verification at reduced hint rates, OR different mechanic |
| **Sector Painter** | Overlapping circles (fixed?), needs testing | B2/2024_56 -- bus network graph coloring | Non-overlapping nodes, clear adjacency lines |
| **Nebula Matrix** | Zones added to logic but not rendered | B8/2023_34, B1/2022_56 -- Latin square with zones | Color-code 2x2/2x3 zones in the grid cells |
| **Circuit Repair** | No difficulty progression | C4/2026_56 -- clock shows 15:69, swap 2 digit positions | Grade 3+: 5-6 digit numbers or multiple valid-looking swaps |
| **Hull Plating** | Ghost shows full shape now but rotation placement still buggy | Advent #2 -- domino/polyomino tiling | Test rotated piece placement thoroughly |
| **Relic Assembly** | Numbers + drag + rotate button added, needs testing | #22/2005_56 -- edge-matching cards with numbers | Verify edge matching works visually |
| **Xenobiology Lab** | Slider trial-and-error, not a riddle | B5/2026_34 -- monster types, deduce counts from totals | Replace sliders with number input + submit, no auto-feedback |
| **Asteroid Duel** | Visuals still basic, asteroids small | C7/2023_56 -- Nim strategy game | Bigger jagged rock shapes, swipe to select multiple |

---

## Key Files for Next Session

- `GAME_IDEAS.md` -- original analysis of 1544 Kanguru problems, all 28 game concepts
- `GAME_THEMING.md` -- space-themed titles, i18n strings (EN+DE), color assignments
- `DESIGN_BRIEFS.md` + `DESIGN_BRIEFS_ROUND2.md` -- approved redesign specs
- `VISUAL_TEMPLATE.md` -- mandatory drag-drop, sizing, animation patterns
- `AGENT_IMPLEMENTATION_SPEC.md` -- game integration protocol
- Kanguru PDFs in `/mnt/storage/downloads/kaenguru_pdfs/`

## Key Learnings

1. Agents produce code that compiles but has poor gameplay quality
2. Always read the actual Kanguru PDF before designing a game
3. Always test with Playwright or manual browser after each change
4. `HitTestBehavior.opaque` needed on GestureDetectors for Flutter web
5. `ListWheelScrollView` doesn't work well on Flutter web -- use tap steppers instead
6. Dark-on-dark is invisible on SpaceBackground -- use distinct container colors
7. Every game needs visible instructions, clear narrative, proper contrast
