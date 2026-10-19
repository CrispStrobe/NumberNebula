# Action and deduction lesson audit

All entries describe the current controls and win predicate. Examples are
explicit teaching boards, not purported screenshots or child calibration data.
The bilingual source is `lib/features/games/models/lessons_action.dart`;
live guidance is `lib/features/games/services/action_hint_guidance.dart`.

| Game key | Actual rule and exercise | Misleading alternative rejected | Source evidence |
| --- | --- | --- | --- |
| `asteroid_math` | Shoot results 3, 4, 8 in ascending order | Nearest object or smallest operand | `screens/asteroid_math_game.dart`, expected-answer check |
| `puzzle_math` | Place upright 4+5 on empty result 9 | Right answer with wrong rotation | `screens/puzzle_math_game.dart`, placement checks |
| `hyperdrive_gates` | Choose gate 5 for 9−4 | Gate 13 from adding instead | `screens/hyperdrive_gates_game.dart`, collision correctness |
| `pathfinder` | Choose path 4 for 8÷2 | Subtracting or adding operands | `screens/path_finder_game.dart`, chosen answer |
| `planet_hopping` | Follow displayed descending order 8→5→3 | Always choosing the smallest result | `screens/planet_hopping_game.dart`, next target |
| `signal_triangulation` | Distinguish one exact and two misplaced glyphs | Summing glyphs or claiming totals identify exact slots | `screens/signal_triangulation_game.dart`, feedback calculation |
| `arithmancer_duel` | Three cost-one cards exceed two energy | Treating arithmetic result as energy cost | `screens/arithmancer_duel_game.dart`, total cost guard |
| `asteroid_field_navigator` | A satisfied clue makes other neighbors safe if flags are justified | Ignoring diagonals or treating flags as proven mines | `screens/asteroid_field_navigator_game.dart`, reveal and flag rules |
| `cargo_bay_arranger` | Filling a row clears it; target sum gives a bonus | Requiring the bonus sum for clearing | `screens/cargo_bay_arranger_game.dart`, `_checkAndClearRows` |
| `star_chart_scan` | Sweep a listed equation in one straight line, forward or backward | Bent paths or unrelated true equations | `screens/star_chart_scan_game.dart`, gesture validation |
| `comm_relay` | Apply Caesar, Atbash or keyword rule as named; DBU→CAT / IBVT→HAUS | Applying Caesar to every cipher | `screens/comm_relay_game.dart`, cipher-specific input |
| `crew_manifest` | Use positive/negative clues and a one-to-one assignment | Assigning an item twice or inventing a positive from a negative | `services/crew_manifest_logic.dart`, solution check; screen marks |
| `alien_tribunal` | Evaluate each complete claim consistently with its speaker | Treating one true clause as a wholly true conjunction | `services/alien_tribunal_logic.dart`, `claimHolds` / `isConsistent` |
| `hive_station` | Count six neighboring energy cells; subtract justified marks | Counting the clue itself or square-grid diagonals | `services/hive_station_logic.dart`, `HexCoord.neighbors` |
| `xenobiology_lab` | The same species counts must satisfy eyes and legs | Counts that match only eyes | `screens/xenobiology_lab_game.dart`, both totals |
| `asteroid_duel` | Last taker loses; from six take one and leave five | Taking the last or exceeding the turn limit | `screens/asteroid_duel_game.dart`, terminal rule |

Paths in the final column are relative to `lib/features/games/`.

## Live hint decisions

Ordering hints use the current index, not a freshly sorted generic example.
Jigsaw accounts for slot-to-piece assignments, used pieces, upright orientation
and empty matching slots. Gate/path hints explain the current expression.
Cipher hints explain the selected trial rather than reading the saved plaintext.
Code-position feedback does not reveal the secret or assert unidentified exact
slots. Crew and Tribunal hints use visible claims and current marks/roles, never
stored assignments. Hive subtracts marks only from revealed clues, with an
explicit condition on correctness. Xeno includes a third species when present.
Cargo distinguishes clearing from bonuses and asks the player to check the
whole landing shape. Duel energy is checked separately from calculation and
damage. Misère advice states honestly when no forcing move exists.

The existing Mines clue arithmetic is retained as a conditional observation,
not a verified move. Existing generators and game algorithms are preserved.
Replacement guidance never inherits a previous hint's solver proof.

## Executable evidence and limits

`tool/check_action_lesson_contracts.dart` checks exact 48-key coverage, independent
arithmetic examples, actual Crew/Tribunal validators and hex neighbors, explicit
partial-board fixtures, snapshot immutability and hidden-answer independence.
These checks do not execute private Flutter screen methods such as Cargo row
clearing or Signal feedback. Existing focused game tests and the all-lesson
rendered tests must also pass remotely before this candidate is accepted.
