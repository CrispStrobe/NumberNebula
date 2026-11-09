# KOMPASS mathematics: construction, planning and reasoning

The expansion adds four untimed, resumable labs and 16 original bilingual tasks
to the optional mathematics pathway. It gives learners more opportunities to
construct a solution, plan several steps, explain a relationship and disprove a
claim. The 48 registered free-play games retain their existing rules and saves.

Work is checkpointed on
[`codex/kompass4-reasoning-expansion-20261109`](https://github.com/CrispStrobe/NumberNebula/tree/codex/kompass4-reasoning-expansion-20261109)
in [draft PR #70](https://github.com/CrispStrobe/NumberNebula/pull/70), based on
`8971225`. The PR includes the unmerged pathway foundation from PR #69 and targets
main so the established validation workflows run. App version: **1.6.0+66**.
Content version: **2.1.0**. This work has not been merged or published.

## Added labs

| Lab | Activities and learner actions | Project competencies |
| --- | --- | --- |
| Denkwerkstatt / Reasoning Workshop | Solve an additive wall backwards; arrange its base to maximize the top and explain the middle value; continue an alternating rule machine; construct every permitted code. | M-Z04, M-Z08, M-Z09, M-Z12 |
| Reiseplanung / Journey Planner | Work backwards from an arrival deadline; compare services, walking time and connection reserves to select the earliest feasible journey. | M-G05, with table reading in M-D01 |
| Flächenstudio / Area Studio | Count unit squares and exposed boundary edges; build connected, hole-free shapes meeting area and perimeter constraints. | M-R02, M-R03, M-R08 |
| Zufallsdetektive / Chance Detectives | Construct a legal counterexample to a claim about two draws, respect the replacement rule, and explain why the exception disproves certainty. | M-D04 |

These are nine new activity types, bringing the pathway to eight labs and 22
types. Chance Detective varies three refutable claims within its activity.
The new lab IDs are `reasoning_workshop`, `journey_planner`, `area_studio` and
`chance_detective`. The original four IDs, seed algorithms and variant cycles
are unchanged, so a saved seed and index still describe the same old puzzle.

All activities use staged bilingual hints, persistent editable drafts, partial
credit, immutable first responses, later corrections and a practice-only result.
They are untimed. Journey answers use integer minutes; monetary content uses
integer cents. Area checking accepts alternative valid constructions instead of
requiring one pictured solution. A carried arithmetic error in an inverse wall
can receive credit for a correctly executed following step. Complete-code tasks
check the actual set of constructed codes, including missing, duplicate and
illegal possibilities. Chance scoring distinguishes a legal draw from a valid
counterexample and its explanation; simulation is not treated as proof.

### Why separate course activities

The existing games offer useful representations, but their actual rules matter.
Number Walls uses absolute differences for its subtraction mode; that is not
solving a missing value in an additive wall. Launch Sequence sorts values rather
than continuing arithmetic rules. Chrono Repair uses clock offsets and mirroring;
it does not plan a timetable connection. The new course activities reuse familiar
walls, clocks, grids and tokens while retaining each free-play game's established
mechanic. Existing game links remain enrichment, and game scores do not become
curriculum evidence.

## Added written content

The bank now has **144 tasks and 298 scored parts**: 72 practice, 36 independent
check and 36 rehearsal tasks. The extension contributes 16 tasks and 41 parts.
Each of the four domains receives two practice, one check and one rehearsal task.
The resulting domain counts are 52 numbers, 36 geometry, 32 measurement and 24 data.

| Domain | New task formats |
| --- | --- |
| Numbers and operations | Division scaling, two-dimensional number-grid rules, constrained grid paths, reversing a multi-step stock story. |
| Space and shape | Joined edges, composing tiles, overlapping areas, reconciling two views of one cube building. |
| Quantities and measurement | Deposits and refunds, partially filled containers, offers with a fixed charge, overlapping activities and waiting time. |
| Data and chance | Tallies, most versus majority, charts with different scales, fair games that include neutral outcomes. |

All new words, values, diagrams and scoring rules are authored for NumberNebula.
The reviewed competency mapping and mathematical formats inform the design;
official papers and private task prose are not embedded. The official scope
includes mathematical processes as well as the four content domains; see the
[IBBW conception](https://ibbw-bw.de/,Lde/Startseite/Pruefungen%2B_%2BLernstandserhebungen/Kompass%2B4%2B_%2BKonzeption).

The eight self-contained HTML booklets are regenerated in German and English,
with separate solutions. Practice now contains 72 tasks across 71 distinct
families: the additional tile-composition practice honestly shares its existing
family. The fixed 20-item printable rehearsal is unchanged. Practice sections
remain grouped once per domain. The in-app glossary now explains terms such as
exactly, at least, at most, earliest/latest, all possibilities, counterexample,
and connected without holes.

## Evidence and saved progress

Labs remain practice evidence even when solved without a hint. Opening journey
planning or chance counterexamples marks the explicitly rehearsed course families
as exposed before the lab appears. Leaving without submitting cannot later turn
those same procedures into unseen checks. This is a narrow authored mapping;
other families are not excluded merely because they share a competency.

First-response hint counts are recorded when the first answer is submitted.
Hints used after an incorrect answer remain later assistance, including across
reopening and completion. Old lab saves without that field conservatively retain
the previous total-hint interpretation. Starting the next round clears the new
round's first-response state. Retained controls are keyed to round identity and
cannot edit a later round or a different profile's draft.

Content 2.1.0 retains all 128 original task objects unchanged. The builder compares
full task objects with the immutable 2.0.1 baseline and emits an explicit
`compatibleTaskIds` map. Old sessions can resume only when all selected tasks are
verified compatible; historical review can use a rubric only for a compatible
task. Unknown versions, changed tasks, missing identities and invalid session
lists fail closed. Revisions keep the historical attempt's original version.

The finite bank's family labels describe authored task families; they do not
prove complete conceptual novelty or calibrated transfer. Neither lab completion
nor app points establish an official score, school recommendation or measured
learning gain. Source checkpoints also do not back up device-local learner data.

## Validation

| Gate | Observed result |
| --- | --- |
| Python content, print, source mapping and compatibility suite | 83 cases passed, including 19 extension cases and five compatibility cases. |
| Generated content and printable reproducibility | Both builders pass `--check`; validator confirms 144 tasks, 298 parts and 32 competencies. Eight booklets are current. |
| Reasoning mathematics, actual pure Dart generators/scorers | 961 checks across 64 seeds passed. |
| Journey and area mathematics, actual pure Dart generators/scorers | 695 checks across 40 seeds passed. |
| Chance mathematics, actual pure Dart generators/scorers | 2,412 checks across 64 seeds passed. |
| Original recipe compatibility | 53 frozen baseline rounds across all 13 original types passed, including 281 raw/restored scoring results. |
| New Flutter controls, compact layouts, persistence, compatibility review and assistance | Regression tests authored; execution on the expanded source is pending remote CI. |
| New browser input, correction, reload and first-response assistance | Regression tests authored; WASM/JavaScript execution is pending remote CI. |
| Full analysis, complete native suite, calibration, web build and browser checks | Required on the exact final pushed head before merge; pending results must not be reported as passes. |

The standalone Dart checks execute mathematical code directly; they are not a
Flutter widget run. The foundation's earlier 126 focused Flutter passes apply to
its own source, not this extension. Exact-head workflow status belongs in
[PR #70 checks](https://github.com/CrispStrobe/NumberNebula/pull/70/checks).

The legacy fixture was captured from exact baseline `8971225`. It covers early
and later indices, fixed seeds, both languages, full round configuration,
default/restored responses, valid alternatives and changed responses. Its
SHA-256 is `189bb73e135cc0b1a87f49cecd1c3aebd0861227b6f78a57484e084458af90ba`.
The earlier task baseline has SHA-256
`5c71c27ee35a2853407f968348b7e2b57877cbbaa292ad4f90fcb9a0a4fee54a`.

CI runs the four standalone audits before `flutter test test/kompass`:

```sh
dart tool/kompass/audit_reasoning_labs.dart
dart tool/kompass/audit_journey_area_labs.dart
dart tool/kompass/audit_chance_labs.dart
dart tool/kompass/audit_legacy_lab_recipes.dart
```

Learner and teacher pilots remain necessary to assess language, usability,
difficulty and delayed transfer to a new paper task. Automated mathematical
checks establish correctness contracts, not measured educational outcomes.
