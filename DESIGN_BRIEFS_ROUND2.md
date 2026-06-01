# Design Briefs Round 2: Remaining Broken Games

---

## 1. Creature Forge -- "How many creatures can you build?"

### Kanguru Source (C6/2024_56)
Richard has 4 body part types. A caterpillar uses 3, 4, or 5 parts total (head + middle + end).
Parts are shown as VISUAL DISTINCT SHAPES. "How many different caterpillars can Richard build?"

### What's Wrong Now
- ListWheelScrollView infinite-looping wheels are confusing
- No labels saying which wheel is heads/bodies/tails
- No indication of how many options exist per category
- Constraint text ("Wings require light body") has no visual connection
- The actual math task is unclear

### Redesign
- Show 3 labeled rows: **HEADS** (row of 2-4 tappable alien head icons), **BODIES** (row of 2-4 body icons), **TAILS** (row of 2-4 tail icons)
- Each part is a distinct, colorful alien shape drawn with CustomPaint
- Player taps ONE from each row to "build" a creature
- The assembled creature appears in a preview area (head + body + tail stacked)
- A "BUILD" button adds it to a gallery grid below
- Gallery shows all discovered combinations as mini-creatures
- The QUESTION displayed: "How many TOTAL unique creatures can you build?" with a number input
- At higher grades: some combinations are "forbidden" (shown as red X when attempted), reducing the total
- The math: headCount x bodyCount x tailCount - forbiddenCount

### How It Differs
- Not a slot machine. A visual build-and-count puzzle.
- Teaches multiplication through concrete combinatorics.

---

## 2. Galactic Market -- "What denomination are the unknown coins?"

### Kanguru Source (A2/2023_34, advent2025 #9)
Paula pays 66 cent. On the table: 50 + ??? + 1 cent. Three unknown coins are identical.
"Which denomination?" → (66-50-1)/3 = 5 cent.

### What's Wrong Now
- Just drag coins to reach a target amount -- trivially addition
- Large empty drop area, then coins shrink to tiny bar
- No deduction, no constraint, no thinking

### Redesign
- Show a **purchase scene**: "Total: X credits. You paid: Y credits. Change: Z credits."
- Show some coins already returned (known), plus N coins face-down (unknown)
- Constraint text: "The 3 unknown coins all have the same value" or "Exactly 5 coins, which denomination must be included?"
- Player selects the unknown denomination from available options (visual coin buttons: 1, 2, 5, 10, 20, 50)
- The math: solve (total - known) / unknownCount = denomination
- Visual: coins are large circles with denomination stamped, face-down coins show "?" with alien glyphs
- At higher grades: "how many ways can you make X with exactly N coins?" (counting problem)
- Score bonus for solving without hints

### How It Differs
- Deduction puzzle, not drag-to-add
- Applied division/algebra in a shopping context

---

## 3. Xenobiology Lab -- "How many of each creature type?"

### Kanguru Source (B5/2026_34, B5/2026_56)
Monster family: each monster has either 2 eyes + 4 legs OR 3 eyes + 2 legs.
Together they have 9 eyes and 16 legs total. "How many of each type?"

### What's Wrong Now
- Just 2 sliders with no context or instructions
- No visual creatures shown
- No census data displayed clearly
- Player has no idea what to do

### Redesign
- Show TWO (or three at grade 3+) **visual alien types** side by side, each with distinct traits drawn clearly:
  - Type A: drawn with 2 eyes + 4 legs (label: "2 eyes, 4 legs")
  - Type B: drawn with 3 eyes + 2 legs (label: "3 eyes, 2 legs")
- Show the **census report**: "Total eyes observed: 18 | Total legs observed: 26"
- Below: a slider for EACH type ("How many Type A?" / "How many Type B?")
- As sliders move, show **live calculation**: "Type A count x 2 eyes = X eyes" etc.
- Computed totals displayed next to targets, green when matching
- Clear instructions text: "A survey found these totals. How many of each alien type are there?"
- Submit only enabled when all totals match
- The math: system of linear equations (grade 1-2: small numbers, grade 3+: 3 types)

### How It Differs from current
- Same mechanic (sliders) but with CONTEXT: visual creatures, clear instructions, live calculation feedback

---

## 4. Dock Clearance -- "Remove minimum blockers" (from Round 1)

### Kanguru Source (A5/2022_56)
Already briefed in DESIGN_BRIEFS.md. Cars face one direction, remove minimum so target can exit.

### Redesign
Per approved brief: tap ships to mark for removal, find minimum count.

---

## 5. Relic Assembly -- "Match the edge numbers"

### Kanguru Source (#22/2005_56)
5 cards with numbers on all 4 edges. Place cards in a cross pattern so touching edges have matching numbers. Cards cannot rotate (at easy levels).

### What's Wrong Now
- Colored letters as "glyphs" -- boring, abstract, meaningless to kids
- No drag-and-drop, just tap to select + tap to place
- No visual feedback on whether edges match
- No clear indication of which edges need to match

### Redesign
- Cards shown as square tiles with **large numbers on each edge** (top, right, bottom, left)
- Each edge number in a distinct color for clarity
- Cards in a **tray** below as Draggable widgets
- Grid positions as DragTarget with visible dashed borders
- When a card is dropped next to another, touching edges **glow green** (match) or **flash red** (mismatch)
- Tap a placed card to remove it (undo)
- At grade 1-2: 2x2 grid, 4 cards, no rotation allowed
- At grade 3+: cross/L-shape, 5 cards, tap to rotate 90° before placing
- Edge numbers use values 1-6 at easy, 1-9 at harder levels
- Visual: cards look like stone tablets with alien number glyphs carved on edges

### How It Differs
- The NUMBERS on edges make it mathematical (matching = equality testing)
- Drag-and-drop with instant visual edge feedback
- Not just abstract letter matching

---

## 6. Hive Station -- "Which cells contain energy?"

### Kanguru Source (C7/2024_34)
Honeycomb grid. Some cells contain honey. EVERY non-honey cell shows a number = how many of its neighbors contain honey. "How many cells contain honey?"

### What's Wrong Now
- Not enough hint cells revealed -- player guesses randomly
- No per-cell feedback during play
- Looks like random clicking until 6/6
- The game is only solvable by LOGIC if ALL non-energy cells show their number

### Redesign
- **ALL non-energy cells must show their adjacency number** (this is the critical fix)
- Energy cells are blank/unmarked -- those are what the player identifies
- Player taps blank cells to mark them as "has energy" (yellow glow)
- The numbers on surrounding cells serve as CLUES -- like Minesweeper, but you FILL instead of FLAG
- Start with cells that have "0" neighbors -- those are clearly NOT energy, helping the player start
- Cells adjacent to only one unmarked neighbor with the right count can be deduced logically
- At higher grades: some number cells are HIDDEN (shown as "?"), making deduction harder
- Submit button validates all marked cells at once
- The hexagonal shape and layout must be clear (hexagons, not circles -- already fixed)

### How It Differs from current
- Current: sparse hints, random guessing. New: ALL hints shown, pure logical deduction.
- Same game, just needs `hintFraction = 1.0` for non-energy cells and proper visual distinction.

---

## Summary of fixes needed

| Game | Core Problem | Fix Type |
|------|-------------|----------|
| Creature Forge | Confusing scroll wheels, no clear task | Full rewrite: tap-to-build gallery |
| Galactic Market | Trivial drag-to-add, no deduction | Full rewrite: coin deduction puzzle |
| Xenobiology Lab | No instructions, no context | Major UI overhaul: add visuals + context |
| Dock Clearance | Rush Hour duplicate | Full rewrite: obstruction removal |
| Relic Assembly | No drag, abstract letters, no edge feedback | Full rewrite: numbered edge cards with drag |
| Hive Station | Sparse hints = random guessing, not logic | Fix: show ALL non-energy numbers, logical deduction |
| Launch Sequence | Black on black, no visible UI elements | Fix: visible ship cards with numbers, contrast colors |
| Ion Chain | Abstract types, no visual meaning, sterile rail | Rewrite: circular bracelet with shaped beads + visual constraint rules |
