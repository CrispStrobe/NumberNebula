# Spatial and planning lessons: source audit

The 16 entries in `lib/features/games/models/lessons_spatial.dart` replace generic
arithmetic with a small exercise about the game's actual action or constraint.
Each has an English/German rule, a fully specified miniature board or local
position, three action choices, and an explanation of the wrong choices. Local
positions teach a mechanic; they are not claims about authored level IDs,
shortest solutions or child-calibrated difficulty.

The following is a code-inspection audit. Executable lesson, snapshot and layout
checks must be reported separately; this document does not claim they ran.

| Game key | Control and source evidence | Actual completion rule | Example validity |
| --- | --- | --- | --- |
| `block_counter` | `screens/blocks_counter_game.dart`: rotate/inspect scene, select count, check; `services/blocks_counter_logic.dart`: contiguous stacks and `correctAnswer = blocks.length` | Count every solid cube, including invisible cubes | A 2×2 height map with heights 2,1,0,3 has 6 cubes; occupied footprint and visible faces are different quantities. |
| `perspective_puzzle` | `screens/perspective_puzzle_game.dart`: `_setupTurn`, `_selectAnswer`; `services/perspective_logic.dart`: four directional nearest-cube projections | Choose the requested projection with correct occupied positions and frontmost colors | A nearer blue cube occludes a red cube on the same line at the same height. The lesson states FRONT explicitly. |
| `hull_plating` | `screens/hull_plating_game.dart`: `_rotatePiece`, `_placePieceAt`, `_removePlacedPiece`, `_isSolved`; `services/hull_plating_logic.dart`: rotated offsets, `validatePlacement` | Every supplied physical piece used once; every active cell covered; no overlap, holes or out-of-bounds cells | A horizontal domino can rotate into a vertical two-cell gap. Dominoes are in the actual generator's shape pool. |
| `relic_assembly` | `screens/relic_assembly_game.dart`: rotate tray/grid, place/remove; `_glyphSymbols` displays numbers; `services/relic_assembly_logic.dart`: `getEdge` and `validatePlacement` | Every tile used once; all touching internal edge values equal; no frame constraint | Target shared edge is 3. Right tile top/right/bottom/left = 3/2/1/4; three clockwise turns put 3 on its left. Zero turns gives 4; one clockwise turn gives 1. |
| `grid_filler_game` | `screens/grid_filler_game.dart`: `_canPlacePiece`, `_placePiece`, `_movePlacedPiece`, `_removePlacedPiece`, `_checkWin` | Place all remaining square inventory; legal placements fit bounds without overlap (inventory area fills the board) | A local 2×2 gap plus isolated 1×1 gap takes one matching square each. Putting the sole 1×1 in the 2×2 gap strands the remaining 2×2. This is a board crop, not a new inventory rule. |
| `quantum_molecule_builder` | `screens/quantum_molecule_builder_game.dart`: `_moveAtom`, `_canMoveTo`, `_checkPatternAt`, `_checkLoseCondition`, `_undoMove` | Target atom indices and empty spaces match at some board translation before exhaustion; slide endpoints are blocked by wall/atom/edge | `# H . . O #`: moving H right ends directly before O, crossing both empty cells in one move. No arbitrary early stop or atom overlap. Undo carries the existing move penalty. |
| `space_station_gridlock` | `screens/space_station_gridlock_game.dart`: pan handlers, `_canMoveShip`, `_moveShip`, `_checkWinCondition` | Horizontal player reaches the right edge; other ships stay on their axes, fixed blockers stay fixed | On 6×6, vertical length-2 blocker at rows 2–3/column 3 moves UP to rows 1–2 and frees player row 3. One step DOWN still blocks; sideways is illegal. Cells, not whole drags, count as moves. |
| `star_loader_game` | `screens/star_loader_game.dart`: `_movePlayer`, `_undoMove`, `_checkWinCondition` | Every target is occupied by a box | In an enclosed `P B T .` corridor, one step right pushes the single box onto its free target. No pulling, chain pushes or walking through walls. |
| `robot_path_game` | `screens/robot_path_game.dart`: command tray, execution and per-command goal checks; `services/robot_path_logic.dart`: command state transitions | Execute legal commands and reach the goal within the command allowance | Start facing right; two clear rightward cells followed by a goal one row down. Forward, Forward, Right, Forward succeeds. Early right turn hits a wall; left turn points away. |
| `warp_fold` | `screens/warp_fold_game.dart`: animation and answer selection; `services/warp_fold_logic.dart`: `_computeUnfoldedResult`, `_mirrorPoint` | Choose generated unfolded cut pattern | A single vertical center fold reflects a cut left/right at the same height. The lesson avoids exact raster coordinates or claims of exactly 2^fold distinct holes: rounded centers and enlarged cut footprints can merge. |
| `cube_scanner` | `screens/cube_scanner_game.dart`: localized structured question and selection; `services/cube_scanner_logic.dart`: valid orientations and question kinds | Answer the requested hidden face, rolled face or hidden pip total | Top=2/front=6/right=3 is an actual orientation in `_allOrientations`; bottom=5. Front's opposite is back, not bottom. No impossible three-face fixture. |
| `circuit_repair` | `screens/circuit_repair_game.dart`: tap two positions, preview, reset/submit; `services/circuit_repair_logic.dart`: position swap, time ranges and stored repair pair | Restore the generated pair, not move seven-segment sticks; generation restricts repairs | Display 71:23 repairs to 17:23 by swapping positions 1 and 2. All other swaps remain invalid; distractors 21:73 and 73:21 violate minute/hour bounds. |
| `dark_matter_grid` | `screens/dark_matter_grid_game.dart`: cell taps; `services/dark_matter_grid_logic.dart`: `toggle`, `isSolved` | ALL LIT; tap toggles self plus orthogonal in-bounds neighbors | In a 3×3 with four lit corners and dark cross, center tap lights all five dark cells and leaves corners alone. Diagonals do not change. |
| `ion_chain` | `screens/ion_chain_game.dart`: shape legend, tray accounting, removable player beads, `_placeBeadInSlot`; `services/ion_chain_logic.dart`: ring `validateChain` and completion guard | All slots filled, every ring pair allowed including last-first; placement also preserves completability from real tray | Six slots red star–?–red star–blue circle–?–blue circle use exactly the two tray beads (one red star, one blue circle). The first gap requires blue circle and the second takes red star. Separate hint fixtures check wraparound and depleted supply. Color is paired with the actual shape. |
| `sector_painter` | `screens/sector_painter_game.dart`: select color, `_paintRegion`, toggling same color off; `services/sector_painter_logic.dart`: `validateColoring`, `findConflicts` | All sectors colored; each connected pair differs. Exact chromatic count is not the win predicate | A—B—C with red A and C allows green B. A and C can share red because A—C is absent. Proximity without a line is not adjacency. |
| `void_crossing` | `screens/void_crossing_game.dart`: `_tapEntity`, `_launchShuttle`; `services/void_crossing_logic.dart`: conflicts, guardians, capacity, `isSolved` | All entities right, within crossings; forbidden unattended pairs cannot remain on departing bank without guardian | One-seat path conflicts A—B—C: carry B first, leaving safe A+C. Carrying either endpoint leaves a forbidden pair. Empty return is permitted when the station being left is safe. |

Paths in the table are relative to `lib/features/games/`.

## Board hint replacement audit

`lib/features/games/services/spatial_hint_guidance.dart` reads frozen screen
snapshots and returns focus, strategy and worked observation. These are teaching
observations, never a claim of an optimal move or a proved global completion.
It does not read stored correct answers, authored solutions, correct option
indices, Molecule target solutions or Cube hidden dice faces.

- **Counting/viewing:** count a bottom-layer subtotal, name the requested
  perspective in the selected language, and distinguish overlapping lines of
  sight. Cube guidance branches on the actual question kind; rolls are translated
  and ordered, hidden sums use the total-pips method, single faces use opposites.
- **Folding/clock:** state the actual reverse fold axes and cut count. Clock hints
  format current or preview digits with separators, check all applicable fields
  including seconds, and explain whole-position swaps and the confirmation step.
- **Relic/Hull/Filler:** use one-based board positions. Relic checks all four
  neighbors and reports actual rotated edge values or an existing mismatch;
  filled boards never produce the former invalid “slot 0.” Hull subtracts real
  placed cells, locates an uncovered cell and describes blocked sides. Filler
  reports actual remaining square counts/sizes and locates an uncovered cell.
- **Robot/Loader/Gridlock:** translate facing and use one-based row/column. Robot
  explains that turns do not move and execution resets the original board.
  Loader checks immediately possible pushes against actual player, boxes and
  walls but expressly avoids calling them winning moves. Gridlock finds the
  first blocker ahead of the player and explains that particular ship's legal
  axis rather than telling every blocker to move perpendicularly.
- **Molecule/Void:** trace one legal atom endpoint using actual walls and atoms,
  label it as a local observation, and show the remaining move budget. Void
  checks the actual departing station after loading, reports current unsafe
  pairs with creature symbols, accounts for guardians and shows seats/crossings.
- **Ion replacement required:** the old `_ionHint` treated the first/last slots
  as open ends and proposed every ion type even when absent from the tray.
  New guidance uses wraparound neighbors, subtracts only player-placed beads
  from the actual available supply and labels local candidates as local. It
  retains the production placement completion guard and does not introduce a
  second solver or pretend local compatibility proves completion.
- **Sector wording replacement required:** neighbor exclusions are useful and
  retained conceptually, but old hint labels used internal zero-based region
  IDs and the filled-board text presented `chromaticNumber` as an exact target.
  New guidance uses the screen's one-based sector numbers, actual palette names,
  current connection conflicts and the actual win rule. Local color candidates
  remain explicitly local.
- **Dark Matter retained:** the existing `solveLights` result is a verified
  current-board solution and its selected target must remain intact. The new
  helper returns null for this game so the existing solution path runs. Its
  null/empty fallback now distinguishes all-lit from a solver failure; neither
  is evidence of a dark-board goal.
- The `_mineHint` algorithm is outside this 16-game inventory and is not altered.

The hints deliberately preserve authored boards, references, move/score rules,
A/B generator paths and fallbacks. This audit improves instruction accuracy; it
does not validate cross-game felt difficulty, device performance or children's
understanding. Validation should use real current and restored snapshots,
filled-but-wrong positions, ring-end slots, six-digit clocks, local choices that
are not global solutions, and large-text English/German layouts.
