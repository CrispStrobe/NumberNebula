# Remaining Work -- Game Quality Fixes

Status as of 2026-05-31 ~16:00 UTC. Total: 20+ fixes done this session, 4 tasks remaining.

---

## COMPLETED fixes this session

1. **Cube Scanner** -- choice range fixed (was 3-18 for single-face question, now 1-6)
2. **Hive Station** -- hintFraction=1.0 for grade 1-2 (all non-energy cells show numbers, pure logical deduction)
3. **Launch Sequence** -- container background from invisible gradient to solid SpaceTheme.deepSpace
4. **Sector Painter** -- win condition with _won flag, conflict-aware check, delayed dialog
5. **Xenobiology Lab** -- added instruction banner to both layouts
6. **Hull Plating** -- error SnackBar on failed placement, cell count label per piece in tray
7. **Dock Clearance** -- REMOVED (duplicate of Space Station Gridlock)

Plus earlier in session:
- Alien Tribunal infinite loop fix
- Comm Relay slider/UX redesign
- Hull Plating polyomino redesign
- Gravity Well logic rewrite
- Star Forge difficulty scaling
- Vault Cracker → static deduction
- Star Chart Scan → equation finder
- Cube Scanner → isometric die + stacked dice
- Circuit Repair → digit position swap
- Chrono Repair → slot machine rollers
- Asteroid Duel → jagged asteroid grid with tap-to-select
- Number Walls → authoritative constraint validation
- Hive Station → hexagonal cell rendering
- Visual polish for 5 games (wireframe cube, fold animation, balance scales, territory map, word grid)
- 25 test files (400+ tests)

---

## COMPLETED this round (in addition to earlier fixes)

8. **Creature Forge** -- rewritten as tap-to-build gallery with labeled part rows
9. **Galactic Market** -- rewritten as coin deduction puzzle per Kanguru A2/2023
10. **Ion Chain** -- rewritten with distinct bead shapes, drag-drop, visual rules
11. **Cube Scanner** -- choice range fixed for single-face questions
12. **Hive Station** -- 100% hints for grade 1-2, pure logical deduction
13. **Launch Sequence** -- container visibility fixed
14. **Sector Painter** -- robust win condition
15. **Xenobiology Lab** -- instructions banner added
16. **Hull Plating** -- error messages on failed placement, cell count labels
17. **Dock Clearance** -- REMOVED (duplicate)
18. **Number Walls** -- authoritative constraint validation

## REMAINING tasks (4)

### Task #7: Creature Forge → Tap-to-Build Gallery
**Kanguru source**: C6/2024_56 -- Richard's caterpillar with 4 body parts, build from 3-5 parts.
**Current problem**: ListWheelScrollView infinite wheels, confusing, no clear task.
**Redesign**:
- 3 labeled rows: HEADS (N tappable alien head shapes), BODIES (N body shapes), TAILS (N tail shapes)
- Each part drawn with CustomPaint (distinct shapes + colors)
- Tap one from each row → assembled creature in preview area
- "ADD" button saves to gallery grid
- Gallery shows discovered combos as mini-creatures
- Question: "How many TOTAL unique creatures?" → number input
- Grade 1: 2x2x2=8. Grade 3+: constraints reduce valid combos
- The math: multiplication via concrete combinatorics

### Task #8: Galactic Market → Coin Deduction
**Kanguru source**: A2/2023_34 -- Paula's 66 cent, 3 unknown coins same denomination.
**Current problem**: Trivial drag-coins-to-target, not deduction.
**Redesign**:
- Show purchase: "Change: Z credits"
- Known coins face-up, unknown coins face-down with "?"
- Constraint: "The 3 unknown coins all have the same value"
- Player selects denomination from options (visual coin buttons)
- Math: (total - known_sum) / unknown_count = denomination
- Grade 2+: "how many ways?" counting problems
- Visual: large circular coins with denomination stamped, face-down = "?" with alien glyph

### Task #6: Ion Chain → Space Bracelet
**Kanguru source**: A6/2026_56 -- Luna's bracelet with shape constraints.
**Current problem**: Abstract ion types, no visual meaning, sterile rail.
**Redesign**:
- CIRCULAR bracelet template with empty slots (not a rail)
- 3-4 distinct bead shapes (star, circle, diamond, hex) in different colors
- Constraint rules shown VISUALLY: crossed-out pairs meaning "these can NOT be neighbors"
- Drag beads from tray into slots
- Invalid neighbors flash red + haptic
- Tap placed bead to remove
- Grade 1: 5 slots, 3 types, 1 rule. Grade 3+: 8+ slots, 4 types, 3 rules

### Task #10: Relic Assembly → Edge-Numbered Cards
**Kanguru source**: #22/2005_56 -- 5 cards with numbers on edges, matching at borders.
**Current problem**: Abstract colored letters, no drag, no feedback.
**Redesign**:
- Square cards with NUMBERS on all 4 edges (not letters)
- Draggable cards from tray → DragTarget grid positions
- Touching edges glow green (match) or flash red (mismatch)
- Tap placed card to remove (undo)
- Grade 1-2: 2x2 grid, 4 cards, no rotation
- Grade 3+: cross layout, 5 cards, tap to rotate 90°

### Task #4: Warp Fold → Actual Fold Animation
**Kanguru source**: B7/2026_56, C2/2025_34 -- paper folding + cutting.
**Current problem**: No real animation, just "red blob".
**Redesign**:
- Step-by-step fold animation: show flat paper → animate fold line → paper folds over
- Show cut on folded paper
- Then show 5 unfolded options as multiple choice
- Use AnimationController with ~2s duration
- CustomPaint draws paper with fold lines (dashed), fold region (semi-transparent overlay)
- After animation: 5 answer cards in 2x3 grid (5th centered)

### Task #11: Circuit Repair Scaling
**Current state**: Works but trivial at all levels (just 4-digit clock).
**Enhancement**: 
- Grade 3: 6-digit calculator display (e.g., "124857" with 2 digits swapped)
- Grade 4: two related displays (addend swaps)
- Generate displays where multiple swaps are possible but only one produces a valid/specific result

### Task #12: Space Narrative for All Games
Every game needs visible instructions + narrative. Quick text additions to all game build() methods. Use the narratives defined in GAME_THEMING.md. The i18n strings already exist (Title, Desc, Instructions) but many games don't SHOW the instructions on screen.

---

## Key Learnings for Future Agent Dispatches

1. **Agents must write a design brief FIRST** -- we review before code
2. **Every game needs**: clear instructions shown on screen, space narrative, visual feedback on every action
3. **Drag-and-drop is mandatory** for placement games (use Draggable/DragTarget pattern from VISUAL_TEMPLATE.md)
4. **LayoutBuilder is mandatory** for responsive sizing (never hardcode pixel sizes)
5. **Test files must be updated** when logic is rewritten (same commit)
6. **The Kanguru original** is the authoritative reference -- read the actual PDF before designing
7. **Downloads go to /mnt/storage** subfolders, builds to /mnt/volume1, never /tmp/
8. **No Co-Authored-By** in commits
9. **Git email must be cze+github@mailbox.org** or Vercel blocks deployment
