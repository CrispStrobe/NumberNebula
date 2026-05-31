# Game Ideas from Kanguru Math Competition Analysis

> Analysis of 58 competition PDFs (1998-2026, grades 3/4 + 5/6) and 6 advent calendar PDFs.
> Evaluated for: gamifiability, algorithmic generation via `dart_csp`, fun factor, difficulty scaling, and grade fit.

---

## Summary of Findings

The Kanguru competition is a goldmine of **recurring puzzle archetypes** that appear year after year in varied clothing. Many of these map directly onto constraint satisfaction problems (CSP) and can be procedurally generated using our `dart_csp` engine. The best game candidates share three traits:

1. **Algorithmically generatable** -- a CSP or algorithm can produce unlimited unique instances
2. **Naturally scalable** -- grid size, number count, or constraint complexity dial difficulty up/down
3. **Visually interactive** -- the player drags, places, toggles, or connects things on screen

---

## Game Ideas Table

| # | Game Name | Puzzle Archetype | Kanguru Sources (examples) | dart_csp Fit | Algorithmic Generation | Difficulty Scaling | Grades | Fun Rating | Gameplay Sketch |
|---|-----------|-----------------|---------------------------|--------------|----------------------|-------------------|--------|------------|----------------|
| 1 | **Number Grid** | Constraint grid: place numbers so rows/cols/diagonals satisfy sum or uniqueness constraints (mini-Sudoku, Latin squares) | B8/2023_34, B1/2022_56, B3/2024_56, C2/2025_56, advent #12 | PERFECT | Generate a solved grid, remove clues, verify unique solution via CSP | 3x3 with sums -> 4x4 Latin -> 5x5 with diagonal constraints -> 6x6+ Sudoku variants | 2-6 | 9/10 | Player taps cells, picks numbers from a tray. Invalid placements glow red. Hint system reveals one cell. Stars for speed + no errors. |
| 2 | **Magic Star** | Place numbers 1-N in nodes of a star/graph so each line sums to the same value | C4/2026_34, C6/2023_34, B6/2024_34, B7/2023_56, B5/2022_56, C3/2025_34, B8/2020_56 | PERFECT | Define graph topology + sum target as CSP. `addAllDifferent` + sum constraints per line. Generate solved state, hide some nodes. | 5-point star -> 6-point -> more arms -> more nodes per arm -> hexagonal webs | 3-6 | 9/10 | Drag numbers into glowing nodes. Lines flash green when their sum is correct. Progressively complex star shapes unlock as levels. Space theme: constellations! |
| 3 | **Codebreaker** | Symbol-to-digit cryptarithmetic: same symbols = same digits, different symbols = different digits, equations must hold | B4/2026_34, C6/2024_34, B6/2022_34, C1/2026_34 | PERFECT (already in codebase) | CSP with variables = symbols, domains = 0-9, constraints = arithmetic equations + allDifferent | Fewer symbols + simpler ops -> more symbols -> multi-equation systems -> multiplication/division | 3-6 | 8/10 | Space mission: decode alien transmissions. Player assigns digits to alien symbols. Equations animate when correct. |
| 4 | **Balance Lab** | Determine unknown weights from balance scale configurations | C8/2025_34, C5/2023_34, C7/2021_34, A8/2021_34, advent #8 | GREAT | Variables = object weights, constraints = balance equations (left side = right side). Generate by picking weights, building valid scale configs, hiding some. | 2 objects + 1 scale -> 3 objects + 2 scales -> 4+ objects + chained scales -> negative weights (subtraction) | 2-6 | 9/10 | Interactive balance scales. Player drags weights onto pans. Scale tilts in real-time with physics animation. "Gravity lab" in space station! |
| 5 | **Lights Out** | Toggle puzzle: pressing a button flips it and its neighbors. Goal: reach target state. | C7/2026_34, C7/2020_56 | GOOD | Solvability via linear algebra over GF(2). Generate by starting from solved state and applying random moves backward. | 2x2 -> 3x3 -> 4x4 -> non-square grids -> hex grids -> custom neighbor rules | 3-6 | 8/10 | Space control panel: buttons are planets/stars. Press to toggle. Satisfying click animations. Minimal-moves scoring. |
| 6 | **Color Map** | Color a graph (map, bus network, tiled regions) with minimum colors so no adjacent regions share a color | B5/2023_34, B6/2023_56, B2/2024_56, A4/2020_56 | PERFECT | Classic CSP: variables = regions, domains = colors, constraints = adjacent != same. Generate planar graphs, solve for chromatic number. | 3-color simple -> 4-color complex -> find minimum colors -> larger maps | 3-6 | 7/10 | Paint planets/space regions with limited color palette. Star map theme. Level complete when no two neighboring regions match. |
| 7 | **Path Finder** | Navigate a grid/maze following movement rules (arrows, hop patterns, step sizes) to reach a goal | A3/2026_34, A1/2024_34, B7/2026_34, C5/2023_56, B1/2023_56, A6/2025_34 | MODERATE | BFS/DFS for solving; procedural maze generation with guaranteed solvability. Can use CSP for constraint-based path puzzles. | Small grid + simple rules -> larger grid -> multiple objectives -> movement constraints (frog hops, knight moves) | 2-5 | 8/10 | Astronaut navigating asteroid field. Swipe to move. Trail of footprints shows path. Undo button. Collect stars along optimal route. |
| 8 | **Who Has What** | Logic grid puzzle: match N people to N items using clue statements | B6/2021_34, B2/2024_34, C4/2023_56, C6/2026_56, advent #16 | PERFECT | CSP: variables = person-item pairs, domains = {true, false}, constraints from clue statements. Generate by creating assignment, deriving minimal clue set. | 3 people x 3 items -> 4x4 -> 5x5 -> add extra dimensions (location, time) | 3-6 | 8/10 | Space crew assignment: match aliens to their ships/planets/tools. Clue cards slide in. Player marks grid with check/X. Satisfying "case solved!" animation. |
| 9 | **Tower Skyline** | Place towers of different heights in a grid; clue numbers on edges tell how many towers are visible from that direction | B6/2026_34, B8/2023_56 | PERFECT | Classic "Skyscrapers" puzzle = pure CSP. Latin square + visibility constraints. | 3x3 -> 4x4 -> 5x5 -> 6x6 (competition-level) | 3-6 | 9/10 | Build a space city! Drag tower blocks into grid cells. Camera rotates to show view from each edge. Shadows and 3D perspective for immersion. |
| 10 | **Honeycomb Fill** | Fill hexagonal cells with values; each cell shows how many neighbors contain honey/value | C7/2024_34, C3/2024_56, C8/2026_34 | PERFECT | Like Minesweeper generation: place values, compute adjacency counts, verify unique solution via CSP. | Small hex grid -> larger -> irregular shapes -> mixed clue types | 3-6 | 8/10 | Bee colony in space! Tap cells to fill with honey. Numbers show adjacent honey count. Satisfying "buzz" when correct. Progressively larger honeycombs. |
| 11 | **Code Lock** | Crack a combination lock given clues like "2 digits correct but wrong position", "1 digit correct and in place" | C1/2022_56 | PERFECT | CSP: variables = digit positions, constraints from each clue (correct count + position). Generate by picking code, deriving non-contradictory clues. | 3 digits + 3 clues -> 4 digits -> more clues with red herrings -> "all wrong" clues | 4-6 | 9/10 | Hack the space vault! Each clue is a failed attempt with color-coded feedback (like Mastermind). Player deduces the code. Timer adds tension. |
| 12 | **Alien Arithmetic** | Fill in blanks in arithmetic grids where rows and columns form valid equations | B8/2026_56, C3/2025_34, C4/2022_56 | PERFECT (already similar to ArithmeticSquare in codebase) | CSP: variables = cells, constraints = row/column equations. Already implemented as ArithmeticSquare! | Addition only -> add subtraction -> add multiplication -> larger grids -> mixed operations | 3-6 | 9/10 | Already partially built! Enhance with space theme. Show operation symbols between cells. Player fills numbers. Rows/columns animate when equation is satisfied. |
| 13 | **Monster Math** | Two types of creatures with different attributes (eyes/legs). Given totals, find how many of each type. | B5/2026_34, B5/2026_56, B7/2023_34, A8/2023_56 | GREAT | System of linear equations. CSP or simple algebra. Generate by picking creature counts, computing totals. | 2 types + 2 attributes -> 3 types -> larger numbers -> three attributes -> negative constraints | 2-5 | 7/10 | Monster lab! Animated creatures with visible eyes/legs. Player adjusts sliders for count of each type. Totals update in real-time. "Aha!" moment when both match. |
| 14 | **Paper Fold** | Predict what a folded+cut paper looks like when unfolded, or vice versa | B7/2026_56, C2/2025_34, A4/2024_34, A1/2024_56, C5/2020_56 | LOW (geometric, not CSP) | Algorithmic: matrix transformations for fold/unfold. Procedural generation by applying random folds + cuts. | 1 fold -> 2 folds -> diagonal folds -> multiple cuts -> 3D folding | 3-6 | 8/10 | Origami station! Animated paper folding with actual fold physics. Player predicts the unfolded result. Choose from 5 options. Beautiful reveal animation. |
| 15 | **Nim & Strategy** | Two players take turns removing objects. Find winning strategy. | C7/2023_56 | LOW (game theory) | Nim-values, Sprague-Grundy theory. Generate positions with known winning/losing status. | Simple Nim -> multi-pile -> Wythoff's game -> custom rules | 4-6 | 7/10 | Space duel! Take asteroids from piles. Play against AI with adjustable difficulty. Learn the strategy through pattern recognition. |
| 16 | **Cipher Trail** | Decode a message using a substitution cipher (shift, swap, symbol replacement) | A3/2024_56, advent #7 | MODERATE | Generate by encoding a word with a random substitution. Can use CSP to verify uniqueness of decryption given partial info. | Caesar shift -> Atbash -> simple substitution with hints -> frequency analysis needed | 3-6 | 7/10 | Intercept alien messages! Decode by dragging letter tiles. Partially decoded words give hints. Progressive reveal as more letters are placed correctly. |
| 17 | **Domino Tile** | Fill a rectangular region with domino/polyomino pieces following coloring or adjacency rules | advent #2, C8/2023_34, A3/2023_34 | GREAT | CSP: tile placement variables with non-overlap and coverage constraints. Or backtracking with constraint propagation. | 2x3 with dominoes -> 4x4 with tetrominoes -> irregular shapes -> colored constraints | 3-6 | 7/10 | Tile the space station floor! Drag tiles into the grid. Pieces snap into place. Constraints visualized as colored overlays. Multiple valid solutions = creativity! |
| 18 | **Digital Detective** | Wires in a digital display are swapped. Deduce the real number from the corrupted display. | C4/2026_56, B6/2020_56 | MODERATE | Enumerate all segment-swap permutations. CSP: map swapped segments to real segments such that all digits become valid. | 1 swap in 1 digit -> 2 swaps -> multiple digits -> which segments are swapped? | 4-6 | 7/10 | Repair the spaceship dashboard! Drag wires between segment positions. Display updates in real-time. Satisfying "fixed!" animation when correct number appears. |
| 19 | **Sequence Builder** | Arrange items in a line obeying adjacency constraints (no two cubes next to each other, colors must alternate, etc.) | A6/2026_56, C4/2023_34, advent #5 | GREAT | CSP: variables = positions, domains = item types, constraints = adjacency rules. Generate valid sequences, remove items for player to fill. | 5 items + 1 rule -> 8 items + 2 rules -> circular arrangement -> multiple constraint types | 2-5 | 7/10 | String a space necklace! Drag beads onto a string. Invalid neighbors flash. Circular mode for advanced levels. Different bead shapes/colors with different rules. |
| 20 | **Dice Detective** | Given partial views of dice, deduce hidden faces using the constraint that opposite faces sum to 7 | A7/2026_56, B1/2020_56, A5/2025_34 | GOOD | CSP: variables = face values, constraints = opposite-sum + visible-face constraints. Generate by placing dice in configurations, revealing some faces. | 1 die, 2 visible faces -> stacked dice -> rolled sequence -> cube net folding | 3-6 | 6/10 | Space dice! Rotate 3D dice to check visible faces. Deduce hidden ones. Multiple dice stacked = constraints chain between touching faces. |
| 21 | **Clock Logic** | Analog/digital clocks with offsets, mirrors, or rotation. Deduce the real time. | A6/2023_34, B2/2023_56, C1/2023_56, advent #11, #18 | LOW (pure arithmetic) | Simple modular arithmetic generation. Parameterize offset, mirror axis, broken display. | Mirror only -> offset + mirror -> multiple clocks with different errors -> digital + analog combo | 3-5 | 6/10 | Fix the space station clocks! Each shows wrong time for a reason (mirror, offset, broken segments). Player adjusts to correct time. |
| 22 | **Parking Puzzle** | Move cars in a grid so a target car can exit (Rush Hour variant) | A5/2022_56, A4/2022_34 | MODERATE | BFS on board states. Generate by reverse-engineering from solved position. | 3 cars -> 6 cars -> trucks (2x1 and 3x1) -> larger board -> minimum moves challenge | 2-6 | 9/10 | Space dock! Move spaceships so the player's ship can launch. Drag to slide. Move counter encourages efficiency. Undo available. Already a proven game concept! |
| 23 | **Card Edge Match** | Arrange cards in a grid so touching edges have matching numbers/symbols | #22/2005_56, A2/2022_34 | PERFECT | CSP: variables = card positions + rotations, constraints = edge matching. Generate cards with values ensuring solvability. | 2x2 with 4 cards -> 3x2 -> rotations allowed -> more edge values | 3-6 | 8/10 | Alien artifact assembly! Place carved stone tablets so adjacent glyphs match. Rotate tiles with tap. Beautiful glyph art. Satisfying "click" when edges match. |
| 24 | **Sorting Puzzle** | Sort a sequence using only specific swap operations, minimizing moves | #10/2005_56, B5/2022_34, B5/2021_34 | MODERATE | Generate random permutations. Optimal solution via BFS. Score based on proximity to optimal. | 4 items + adjacent swaps -> 5 items -> non-adjacent swaps -> constrained swap patterns | 3-6 | 7/10 | Sort the space convoy! Drag ships to swap positions. Move counter shows efficiency. Bronze/silver/gold based on move count vs. optimal. |
| 25 | **Word Nebula** | Find hidden words in a letter grid (word search), horizontally, vertically, diagonally, forwards and backwards | advent2024 #4 | MODERATE | Place words first, then fill remaining cells with random letters. Ensure no accidental extra words. Can use CSP for placement without overlap conflicts. | 5x5 grid + 5 words -> 8x8 + 10 words -> 10x10 + 20 words -> themed vocabulary (math terms, space words) | 2-6 | 7/10 | Scan the star map for hidden constellation names! Swipe across letters to highlight words. Found words glow and float off the grid. Last unfound letter reveals a bonus. |
| 26 | **Chimera Lab** | Combine parts (head/body/tail) from different creatures to count all possible combinations, or find the one that matches constraints | C7/2015_34, C6/2024_56, C1/2024_34 | MODERATE | Combinatorics: generate part sets, compute valid combinations. CSP when constraints apply (e.g., "must have wings AND fins"). | 3 animals x 2 parts -> 4 animals x 3 parts -> add color variants -> constraint-based filtering | 2-4 | 8/10 | Build space creatures! Drag alien heads, bodies, tails together. Counter shows how many unique creatures are possible. Challenge mode: build the one matching a description. |
| 27 | **Liar's Table** | Truth-tellers always tell truth, liars always lie. Deduce who is what from their statements. | C4/2023_56, C4/2020_56, C8/2022_56, B4/2015_34 | GREAT | CSP: variables = person roles (truth/liar), constraints = statement consistency. Generate by assigning roles, creating consistent statement sets. | 2 people + 2 statements -> 3 people -> mixed (sometimes truth/sometimes lie) -> circular references | 4-6 | 8/10 | Alien diplomacy! Meet aliens who either always truth-tell or always lie. Read their claims about each other. Deduce who's trustworthy. Unlock trade routes as reward. |
| 28 | **Coin Change** | Make a target amount using specific denominations; find which coins are forced, or count the ways | A2/2023_34, B6/2015_34, advent2025 #9 | GOOD | Dynamic programming or CSP for exact solutions. Generate targets with interesting constraint properties (unique forced coin, exactly 2 ways, etc.) | Small amounts + 3 denominations -> larger amounts -> "which coin is always needed?" -> minimize coin count | 2-5 | 6/10 | Space vending machine! Drag coins to reach target. Challenge: use fewest coins. Variant: which coin must always be included? |

---

## Top 5 Recommendations (Best ROI for Space Math Academy)

### Tier 1: Build These First

| Priority | Game | Why |
|----------|------|-----|
| 1 | **Alien Arithmetic** (#12) | ArithmeticSquare already exists in codebase via dart_csp. Minimal new code needed. Proven fun. Infinite puzzles. |
| 2 | **Magic Star** (#2) | Pure CSP. Visually stunning as constellations. New topology each level. Works for all grades. |
| 3 | **Tower Skyline** (#9) | Classic puzzle with huge following. Pure CSP. Beautiful 3D visualization potential. |
| 4 | **Balance Lab** (#4) | Universally understood mechanic. Physics animation is delightful. Directly teaches algebra concepts. |
| 5 | **Code Lock** (#11) | Mastermind variant. Addictive loop. Easy to implement. Appeals to puzzle fans of all ages. |

### Tier 2: Build Next

| Priority | Game | Why |
|----------|------|-----|
| 6 | **Number Grid** (#1) | Sudoku is the world's most popular puzzle. Our variant can start smaller (3x3, 4x4). |
| 7 | **Honeycomb Fill** (#10) | Minesweeper-like but constructive (filling, not flagging). Unique hex grid differentiator. |
| 8 | **Parking Puzzle** (#22) | Rush Hour is a proven commercial success. Space dock theme is perfect. |
| 9 | **Who Has What** (#8) | Teaches pure logical deduction. Great for older grades. Story-rich. |
| 10 | **Lights Out** (#5) | Simple to implement, surprisingly deep. Beautiful visual feedback. |

---

## How dart_csp Powers This

Our `dart_csp` engine (constraint satisfaction solver) is the key enabler for procedural puzzle generation:

```
Problem() -> addVariable(name, domain) -> addConstraint(vars, predicate) -> getSolution()
```

**Generation pattern:**
1. Define variables and their domains (e.g., grid cells with values 1-N)
2. Add constraints (row uniqueness, sum targets, adjacency rules)
3. Call `getSolution()` to get a valid solved puzzle
4. Remove some values to create the puzzle (clues)
5. Verify unique solvability by checking no other solution exists

**Already built in codebase:** ArithmeticSquare, MathCrossword, Codebreaker -- these prove the pattern works.

**Games that are PURE CSP** (can be generated entirely by dart_csp):
- #1 Number Grid, #2 Magic Star, #3 Codebreaker, #5 Lights Out, #6 Color Map, #8 Who Has What, #9 Tower Skyline, #10 Honeycomb Fill, #11 Code Lock, #12 Alien Arithmetic, #23 Card Edge Match, #27 Liar's Table

**Games that use CSP + other algorithms:**
- #4 Balance Lab (CSP + physics sim), #7 Path Finder (CSP + BFS), #13 Monster Math (CSP + animation), #17 Domino Tile (CSP + geometry), #19 Sequence Builder (CSP + UI), #25 Word Nebula (CSP + random fill), #26 Chimera Lab (CSP + combinatorics), #28 Coin Change (CSP + DP)

**Games that need different algorithms:**
- #14 Paper Fold (matrix transforms), #15 Nim (game theory), #22 Parking Puzzle (BFS on states), #21 Clock Logic (modular arithmetic), #24 Sorting Puzzle (BFS/permutations)

---

## Difficulty Scaling Framework

Each game can scale along these axes:

| Axis | Easy (Grade 2-3) | Medium (Grade 3-4) | Hard (Grade 5-6) | Expert (Grade 6+) |
|------|-------------------|--------------------|--------------------|-------------------|
| **Grid size** | 3x3 | 4x4 | 5x5 | 6x6+ |
| **Number range** | 1-5 | 1-9 | 1-12 | 1-20+ |
| **Operations** | + only | +, - | +, -, x | +, -, x, / |
| **Constraints** | 1-2 rules | 3-4 rules | 5+ rules | Compound/chained |
| **Clues given** | 70% filled | 50% filled | 30% filled | Minimal clues |
| **Topology** | Line/simple grid | Square grid | Star/hex | Irregular graphs |
| **Time pressure** | None | Generous timer | Tight timer | Speed challenge |

---

## Gameplay Vision

### Core Loop
```
Choose Planet (= puzzle type) -> Select Difficulty (= orbit ring) -> Solve Puzzle -> Earn Stars -> Unlock Next
```

### Meta-Progression
- Each puzzle type is a **planet** in the solar system
- Difficulty levels are **orbit rings** (inner = easy, outer = hard)
- Stars earned unlock new planets
- **Daily Challenge**: one puzzle from each type, like the Kanguru advent calendar
- **Constellation Mode**: solve a sequence of different puzzle types to "draw" a constellation

### Advent Calendar Mode (inspired by Kanguru Adventskalender)
- **24 daily puzzles** in December, one per day
- Each puzzle is a different type from the game roster
- Solving each day's puzzle yields a **letter**
- Letters are placed into numbered slots to spell a secret word/phrase
- Decryption method revealed on Dec 24
- This is EXACTLY what the Kanguru advent calendar does -- and it's brilliant for retention

### What Makes It Fun
1. **Instant feedback** -- constraints light up green/red as you place values
2. **Multiple valid approaches** -- some puzzles have multiple entry points
3. **No penalty for trying** -- undo is always available
4. **Aha! moments** -- the satisfaction of the last piece clicking into place
5. **Infinite replay** -- procedural generation means no two puzzles are the same
6. **Progressive mastery** -- visible difficulty progression gives sense of growth

---

## Sources Analyzed

| Category | Years | PDFs Read | Total Problems Analyzed |
|----------|-------|-----------|----------------------|
| Grades 3/4 competition | 1998-2026 | 29 | ~700 |
| Grades 5/6 competition | 1998-2026 | 29 | ~700 |
| Advent calendar maxi | 2020-2025 | 6 | ~144 |
| **Total** | | **64** | **~1544** |

Recurring problem types were identified by clustering across all years. The 28 game ideas above represent the most frequent, most gamifiable, and most algorithmically tractable archetypes.
