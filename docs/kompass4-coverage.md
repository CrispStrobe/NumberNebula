# KOMPASS 4 mathematics coverage

This is the coverage of content package `numbernebula_kompass_math` version
`2.1.0`, schema 2. The 32 identifiers come from the project-owned `kompass4`
competency matrix. They are not official IBBW item or proficiency codes.

The package contains **144 original bilingual tasks and 298 separately scored
parts**: **72 practice, 36 check and 36 rehearsal tasks**. The four domains
contain **52 numbers/operations, 36 geometry, 32 measurement and 24 data/chance
tasks**. The 16 additions contribute 41 parts; all 128 tasks from 2.0.1 remain
unchanged as complete task objects.

Existing-game links are enrichment opportunities. Their normal free-play scores
do not supply KOMPASS competence evidence. **Eight interactive labs with 22 round
types** live inside the optional course, separately from the 144 authored tasks.
The global free-play registry and its scoring are unchanged. The source asset
distinguishes competencies represented in published
2025 material from curriculum supplements; neither label claims future test
weighting or an official blueprint.

## Authored task coverage

Counts below are derived from
[`math_v2.json`](../assets/kompass/math_v2.json). A task counts once for a
competency when at least one of its parts maps to that competency, regardless of
the number of scored parts. These are task counts, not independent-family counts
or learner mastery claims. Check and rehearsal totals describe the authored pool;
prior exposure can make a task unavailable as fresh independent evidence.

| Competency | Learning goal | Tasks: practice / check / rehearsal | Existing enrichment games |
| --- | --- | --- | --- |
| M-Z01 | Place value and regrouping | 2 / 1 / 1 | `number_walls`, `asteroid_math` |
| M-Z02 | Ordering and neighbouring numbers | 2 / 1 / 1 | `asteroid_math` |
| M-Z03 | Number lines and distances | 2 / 1 / 1 | Course tasks and labs |
| M-Z04 | Add, subtract and check | 2 / 1 / 1 | `number_walls`, `arithmancer_crosswords` |
| M-Z05 | Multiplication and division | 2 / 1 / 1 | `number_walls`, `kenken` |
| M-Z06 | Calculations and stories | 2 / 1 / 1 | Course tasks and labs |
| M-Z07 | Explain calculation strategies | 3 / 1 / 1 | `asteroid_math` |
| M-Z08 | Patterns and rules | 3 / 1 / 1 | Course tasks and labs |
| M-Z09 | Systematic optimisation | 2 / 1 / 1 | `number_walls` |
| M-Z10 | Model word problems | 2 / 1 / 2 | Course tasks and labs |
| M-Z11 | Estimate and check | 2 / 1 / 1 | `asteroid_math` |
| M-Z12 | Find every possibility | 2 / 2 / 1 | `codebreaker` |
| M-R01 | Properties of shapes | 2 / 1 / 1 | `hull_plating` |
| M-R02 | Compose and decompose shapes | 3 / 1 / 1 | `hull_plating`, `grid_filler_game` |
| M-R03 | Compare areas | 2 / 2 / 1 | `sector_painter`, `hull_plating` |
| M-R04 | Mentally rotate shapes | 2 / 1 / 1 | `hull_plating` |
| M-R05 | Reflections and symmetry axes | 2 / 1 / 1 | `warp_fold` |
| M-R06 | Plans and views | 2 / 1 / 2 | `perspective_puzzle`, `block_counter` |
| M-R07 | Cube nets | 2 / 1 / 1 | `cube_scanner` |
| M-R08 | Perimeter and area | 3 / 1 / 1 | `hull_plating` |
| M-G01 | Plausible quantities | 2 / 1 / 1 | Course tasks and labs |
| M-G02 | Convert lengths | 2 / 1 / 1 | Course tasks and labs |
| M-G03 | Price relationships | 2 / 1 / 1 | `galactic_market` |
| M-G04 | Calculate with money | 3 / 2 / 1 | `galactic_market` |
| M-G05 | Times and durations | 2 / 1 / 2 | `chrono_repair` |
| M-G06 | Measure and draw | 2 / 1 / 1 | Course tasks and labs |
| M-G07 | Litres and millilitres | 3 / 1 / 1 | Course tasks and labs |
| M-D01 | Read tables | 2 / 1 / 1 | Course tasks and labs |
| M-D02 | Represent data | 3 / 1 / 1 | Course tasks and labs |
| M-D03 | Understand chart scales | 3 / 2 / 1 | Course tasks and labs |
| M-D04 | Certain, possible, impossible | 2 / 1 / 1 | Course tasks and labs |
| M-D05 | Compare chances | 2 / 1 / 2 | Course tasks and labs |

There are **71 distinct practice families**. M-R02 has three practice tasks but
two practice families: `mr02_complete_tile_rectangle` and
`mr02_zz_square_and_corner_piece` deliberately share the family
`mr02_complete_tile_rectangle`. All other counts in this table also equal the
corresponding distinct-family counts. Families remain confined to one mode.

## Interactive labs

The original four labs retain their 13 round types. Four additional labs add nine
types, for **eight labs and 22 types** in total. Parameter changes within a type,
such as drawing with or without replacement, are not counted as extra types.

| Lab | Round types | Interactions | Mapped competencies |
| --- | ---: | --- | --- |
| Place Value Dock / Zahlendock | 3 | Build a number from a clue (number word, scrambled places with an empty place, un-bundled amount, ±1/10/100 across a boundary); regroup un-bundled material and write its value; locate a midpoint between varied endpoints. | `M-Z01`, `M-Z03` |
| Supply Station / Versorgungsstation | 4 | Calculate purchases and construct change, advance a clock, measure ¼/½/¾ litre amounts with a limited bottle supply, convert length. | `M-G02`, `M-G04`, `M-G05`, `M-G07` |
| Data Observatory / Datenobservatorium | 3 | Build a chart, set a bag to a relational chance goal (equal, double, or equal to the complement) with a distractor type, classify composed events and explore draws. | `M-D02`, `M-D03`, `M-D04`, `M-D05` |
| Geometry Workshop / Geometriewerkstatt | 3 | Select every reflection axis of nine shapes (zero to four axes), complete any of the eleven cube nets, reconstruct a side view from a building. | `M-R05`, `M-R06`, `M-R07` |
| Reasoning Workshop / Denkwerkstatt | 4 | Work backwards through a number wall, arrange cards to maximise its top, continue alternating calculation rules, construct every allowed two-symbol code and select a completeness explanation. | `M-Z04`, `M-Z08`, `M-Z09`, `M-Z12` |
| Journey Planner / Reiseplanung | 2 | Plan the latest departure backwards from an arrival deadline; calculate platform arrival and choose the earliest connection allowing the required reserve. | `M-G05`, `M-D01` |
| Area Studio / Flächenstudio | 2 | Measure area and exposed boundary using the given cell size; build a connected shape without holes that satisfies both area and perimeter. Different valid shapes are accepted. | `M-R02`, `M-R03`, `M-R08` |
| Chance Detectives / Zufallsdetektive | 1 | Construct a legal two-draw counterexample to a certainty claim, respecting replacement rules, and select why one possible exception is enough. | `M-D04` |

Each lab has three stages of help, repeatable seeded rounds, a saved draft and
keyboard/tap controls. Completion remains practice evidence. The first response,
partial first points, later successful response, hints and active work time are
kept separately.

The lab skill mappings do not increase the authored-task counts above. Every lab
result is marked as practice even when solved correctly without hints. Opening
Journey Planner or Chance Detectives also records exposure to the named course
families whose procedures those labs rehearse; leaving before submission does
not restore those families to unseen status. Lab completion and normal free play
cannot be promoted to an independent check or rehearsal result.

## Paper coverage

The practice booklet includes all **72 practice tasks and 71 distinct families**.
The fixed rehearsal booklet still uses the same **20 tasks and 20 families** as
2.0.1; the other 16 rehearsal tasks remain available in the app. The print
manifest records exact task IDs for exposure tracking. Learner sheets and answer
keys remain separate. This authored selection is not an official test blueprint.

## Existing progress and compatibility

The frozen
[`math_v2_0_1.json`](../tool/kompass/baselines/math_v2_0_1.json) baseline preserves
the preceding 128 task objects. The build verifies its SHA-256 and full task
equality before generating `compatibleTaskIds["2.0.1"]`. Compatibility therefore
depends on unchanged wording, figures, answers, rubrics and family identities,
as well as the task ID. The 16 added tasks have no historical compatibility claim.

Session restoration requires a nonempty set of unique task IDs compatible with
the saved package version. Review applies the current task rubric and worked
solution only to a compatible record. Older records from unknown or changed
versions remain readable as historical results, with current manual review
controls disabled. Verified older sessions can resume and record corrections
without replacing their first-attempt evidence or losing recorded assistance.

The original labs have a separate
[`lab_recipes_v1.json`](../tool/kompass/baselines/lab_recipes_v1.json) baseline:
53 seeded cases cover all 13 old types, early and later indices, and structural
alternatives. Its standalone audit compares bilingual content, configuration,
default and normalized responses, and 281 scoring results. Keeping the original
seed/index recipes stable prevents saved lab drafts from reopening as different
problems when the four new labs are added.
