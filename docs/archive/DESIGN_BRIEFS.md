# Design Briefs for Game Rework

These games need fundamental redesign. Each brief documents the original Kanguru inspiration, the proposed gamification, and how it differs from existing games. **No code until brief is approved.**

---

## 1. Dock Clearance → "Dock Clearance" (Obstruction Removal)

### Original Kanguru Problem (A5/2022_56)
A parking lot grid viewed from above. Cars are parked in cells, each facing a fixed direction (forward only). One car (the black one) needs to exit via an arrow at the edge. Cars can ONLY drive straight forward -- they cannot turn or reverse. Question: "How many of the gray cars must be REMOVED so the black car can leave?"

This is NOT a sliding-block puzzle (that's Rush Hour / Space Station Gridlock which we already have). It's a **graph obstruction** problem: which obstacles block the path?

### Proposed Gamification
- Top-down grid showing a **space dock** with parked ships, each with a visible **direction arrow**
- The player's ship (red/highlighted) needs to reach the exit
- Ships can only fly straight in the direction they face
- A ship is "blocking" if it sits in the path of another ship that needs to move
- Player taps ships to **mark them for removal** (they fade out)
- Goal: find the **minimum number** of ships to remove so the red ship can exit
- Submit button checks: "Can red ship exit now?" If yes + minimum count = perfect score
- Visual: removed ships float away with a fade animation

### Difficulty Scaling
- Grade 1: 4x4 grid, 3-4 ships, obvious single blocker
- Grade 2: 5x5 grid, 5-6 ships, chain of 2 blockers
- Grade 3-4: 6x6 grid, 8+ ships, multiple possible paths, find the one needing fewest removals

### How It Differs from Existing Games
- **Space Station Gridlock**: slide blocks along their axis (Rush Hour). Interactive, many moves.
- **Dock Clearance**: static puzzle, mark ships for removal, find minimum. One-shot answer, pure deduction.

Completely different mechanic despite similar visual theme.

---

## 2. Cube Scanner → "Cube Scanner" (Dice Deduction with Stacking)

### Original Kanguru Problems (A7/2026_56, B1/2020_56, A5/2025_34)
Standard die problems: opposite faces sum to 7. Problems show:
- A die from one angle, ask about the opposite face (A7/2026_56: "three faces showing 3,5,6 have sum 7. Which numbers are on the other three?")
- Multiple dice glued together where touching faces are constrained (B1/2020_56)
- A die rolled through positions, track which face ends up where

The key insight: it's always about the **constraint that opposite faces sum to 7**, sometimes combined with **touching-face constraints** between multiple dice.

### Proposed Gamification
- Show a **large 3D-looking die** (isometric CustomPaint, wireframe edges with glow)
- Three faces are visible (top, left-front, right-front in isometric view)
- The visible faces show their values clearly (large numbers or dot patterns)
- Question: "What value is on the BOTTOM face?" (opposite of top = 7 - top)
- Or: "What is the sum of the three HIDDEN faces?" (= 21 - sum of visible)
- Player selects answer from multiple choice (5 options)

**Scaling with multiple dice (grade 3+):**
- Two dice stacked vertically: top die's bottom touches bottom die's top. Touching faces must be EQUAL.
- Show some faces on each die, ask about hidden ones
- The constraint chain: top's bottom = bottom's top, plus opposite-face=7 rule
- Three dice in a row: left die's right face touches right die's left face

### Difficulty Scaling
- Grade 1: single die, 3 faces visible, ask for one hidden face (just 7 - visible)
- Grade 2: single die, 2 faces visible, ask for sum of hidden faces (requires inferring the third visible)
- Grade 3: 2 stacked dice, touching faces equal, deduce a hidden face from the chain
- Grade 4: 3 dice in a row, chain of touching constraints

### How It Differs from Existing Games
- **Anomaly Scan / Perspective Puzzle**: view 3D blocks from different angles, choose correct view. Visual matching.
- **Cube Scanner**: arithmetic deduction using constraints (sum=7, touching=equal). Math reasoning, not visual matching.

---

## 3. Circuit Repair → "Circuit Repair" (Swapped Clock Digits)

### Original Kanguru Problem (C4/2026_56)
"Grandpa's alarm clock needs repair. Two wires must have been swapped, because two positions on the digital display are now switched. Currently the clock shows 15:69. What does the clock actually show per minute?"

This is NOT about knowing 7-segment wiring labels (a, b, c, d, e, f, g). It's about: **two DIGIT POSITIONS are swapped**. The display reads "15:69" but if you swap positions 2 and 4 (the "5" and the "9"), you get "19:65" -- but that's not a valid time either. Swap positions 3 and 4: "15:96" -- invalid. Swap positions 1 and 3: "65:19" -- invalid. Swap positions 2 and 3: "16:59" -- valid! Answer: 16:59.

Actually re-reading: "zwei Stellen vertauscht" = two POSITIONS on the display are swapped. So it's about swapping digit positions, not wiring segments.

### Proposed Gamification
- Show a large **digital clock display** showing an INVALID time (e.g., "15:69")
- The player knows: exactly two digit positions are swapped
- Player taps two digit positions to swap them
- The display updates in real-time to show the result
- If the result is a valid time (hours 0-23, minutes 0-59): that's the answer!
- Submit to confirm
- Multiple difficulty levels: time displays, multi-digit numbers, calculator displays

### Difficulty Scaling
- Grade 1: 4-digit clock display (HH:MM), two digits swapped, only one valid swap exists
- Grade 2: clock display with trickier swaps (e.g., "25:31" → "15:32"? "21:35"?)
- Grade 3: 6-digit calculator display, two digits swapped. More possibilities to check.
- Grade 4: two separate displays with related swaps, or "the result should be XX:YY, which two positions were swapped?"

### How It Differs from Existing Games
- **Chrono Repair**: clock shows wrong time due to offset/mirror. Pure arithmetic adjustment.
- **Circuit Repair**: the digits themselves are scrambled by position swap. Combinatorial reasoning -- try different swaps mentally.

Much simpler to understand than the current "pick segment a vs segment f" nonsense. Kids see "15:69", think "69 isn't valid minutes, which swap makes it valid?" -- intuitive.

---

## Summary

| Game | Current Mechanic | Kanguru Mechanic | Redesign |
|------|-----------------|-----------------|----------|
| Dock Clearance | Rush Hour clone (duplicate of Gridlock) | Remove minimum blockers so target exits | Tap to remove ships, find minimum |
| Cube Scanner | Flat die, ambiguous "back face" | Opposite faces sum to 7 + stacked dice chains | Isometric die, MC answer, multi-dice scaling |
| Circuit Repair | Pick 7-segment wire labels (impossible UX) | Swap two digit positions to fix invalid display | Tap two digits to swap, real-time update |
