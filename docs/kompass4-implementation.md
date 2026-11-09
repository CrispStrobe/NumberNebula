# KOMPASS 4 mathematics pathway

## Scope

Implement the complete optional mathematics pathway across numbers and operations,
space and shape, quantities and measurement, and data and chance. Keep free play,
all existing games, local profiles, saved progress, and the all-ages positioning.
This work is being checkpointed on `codex/kompass4-learning-path`.

The authoring reference is CrispStrobe/kompass4 at
`9a0b25a6b0706b7c7944836e00f163bcbfd46676`. Its 32 mathematics competency IDs
are project-owned identifiers, not official IBBW assessment codes. Published
official papers remain linked references and are not embedded or adapted.

The resumed implementation uses app version **1.6.0+64** and content version
**2.0.1**. kompass4 supplies a deterministic, pinned competency metadata export;
the interactive exercises remain original NumberNebula content. The mapping
includes exact curriculum references and estimated time bounds in seconds.
The source matrix does not author a prerequisite graph; none is inferred from
task order or curriculum identifiers.

## Delivery checklist

- [x] Versioned original bilingual content covering all 32 competencies, with
  separate practice, independent-check and rehearsal families.
- [x] Explicit per-part answer rules, partial credit, units, misconceptions,
  explanations and reviewable manual criteria.
- [x] Profile-scoped immutable first-attempt evidence, assistance and revisions,
  idempotent recording, resumable sessions and independent skill progress.
- [x] Guided course, next-activity planning, glossary, existing-game practice links,
  independent checks, a 45-minute working-period rehearsal and a progress report.
- [x] Interactive activities for place value/number lines, everyday quantities,
  data/probability and geometry; keep learning untimed and support accessible input.
- [x] Matching printable practice and review output from the content package.
- [x] Content validation and focused scorer/planner/persistence/widget tests.
- [ ] Exact-branch remote CI/build/browser checks, with evidence recorded honestly.

## Content contract (schema version 2)

The bundled asset `assets/kompass/math_v2.json` contains `schemaVersion`, `id`,
`version`, `source`, `competencies`, and `tasks`. Localized strings are maps with
`de` and `en`. Competencies contain `id`, `domain`, `title`, `goal`, `evidence`
(`published2025` or `curriculum`), `curriculumUrl`, and `gameKeys`.

Tasks contain `id`, `familyId`, `domain`, `title`, `prompt`, `level` (1–3),
`use` (`practice`, `check`, or `rehearsal`), `parts`, `hints`, `solution`, and
`source`. Optional fields are `figure` and `estimatedSeconds`.

Each part contains `id`, `kind` (`number`, `choice`, `multiChoice`, `text`,
`cells`, or `order`), `prompt`, `competencyIds`, `maxPoints`, and `answer`.
Optional fields are `unit`, `options` (objects with `id` and localized `label`),
`figure`, `rubric`, `carryFrom`, `carryOffset`, and `errors`.

Answer types are `number` (numeric `value`, optional `tolerance`), `choice`
(string `value`), `set` (string-list `values`), `sequence` (string-list `values`),
and `manual` (localized `criteria`). Numeric input accepts German decimal commas;
unit expectations are explicit. Errors contain `value`, `code`, and localized
`feedback`. Carry-error credit is explicit and separately reported.

Figures have `kind`, a JSON `data` map and localized `alt`. Supported figures
will be documented alongside the renderer. Solutions are never shown before
submission in independent checking or rehearsal. Manual responses remain
unreviewed until the learner/supporter explicitly applies the supplied rubric;
their results do not count as independently machine-verified competence.

## Implementation boundaries

The new feature lives under `lib/features/kompass/`. Its models and scorer/planner
are pure Dart. Flutter persistence uses captured `ProfilePreferences` instances;
it must not overwrite another player's data after an asynchronous profile switch.
Game rewards and SRI remain separate from curriculum evidence. Existing internal
`grade` and game keys are unchanged. A rehearsal uses 45 minutes of work after
instructions, with skip/return/edit controls and deferred feedback.

Practice games are enrichment, not proof of curriculum mastery. Course states
describe observed evidence and uncertainty, never an official KOMPASS level,
school recommendation or calibrated prediction. Human learning/playtest outcomes
remain to be collected; automated correctness checks do not substitute for them.

## Learner flow

Open **KOMPASS 4 · Mathematics / Mathematik** from the home screen. The optional
module is loaded on demand. The main free-play and mission routes remain
available; a compact home screen scrolls to keep its actions reachable.

- **My next practice** selects a short set across domains, prioritizing open
  goals and due review. A domain filter and each of the 32 goal cards provide
  targeted practice. Hints are staged; first submissions, later corrections and
  help use remain distinct. A worked solution appears after practice submission.
- **Independent check** uses up to eight unseen held-out tasks. It has no hints
  or immediate correctness feedback. Learners can skip, return and change answers
  before finishing. Unanswered items remain explicitly unattempted.
- **45-minute rehearsal** starts its work clock after the instructions. The
  persisted deadline continues across app backgrounding, route changes and
  reopening. Active work time is recorded separately and excludes background
  time. At expiry the session closes once and opens review. A full rehearsal
  uses this package's 8/5/4/3 domain mix, not an asserted official blueprint.
  If unseen content cannot fill that mix, the introduction explicitly labels a
  repeat rehearsal; previously seen families do not become new evidence.
- **Paper practice** offers an offline paper view and copyable task text on
  native clients. Web clients additionally download self-contained HTML booklets
  with SVG figures for browser printing or PDF saving. Practice and rehearsal
  have separate solution booklets in both languages. Opening a worksheet marks
  its exact task families as seen before they can be used in later checks.
- **Review** preserves per-part scores and first responses. Explanations remain
  pending until a learner or supporter applies the supplied manual rubric.
  Manual review never converts into an automated independent judgement. The
  review links to a suggested next practice and can copy a readable report;
  the hub can export the underlying local records as JSON via the clipboard.

See [the complete coverage map](kompass4-coverage.md) for all 32 competencies and
the four labs. Learners do not need an account, a cloud model or a network call
for the bundled content and saved learning path. Downloading/installing the app,
loading a deferred web module for the first time, and following official external
links still require the relevant resources to be available.

## Evidence and storage

`KompassAttempt` stores content use and screen mode separately; opening practice
content in a check screen cannot turn it into an independent item. Original
responses/scores are immutable. Later edits, manual review, support and active
work time are monotonic revisions. A family first exposed in the current saved
session can still be new; abandoning it, seeing a paper copy or solving an earlier
item in that family makes later attempts previously seen.

Opening a worked solution or requesting a hint updates assistance immediately,
without submitting a draft response. Solution exposure remains visible after a
correction or reopening. Attempt revisions carry an integer generation; a stale
editor cannot overwrite a newer response or manual review. Progress uses this
generation before timestamps when choosing between revisions.

The planner describes observations, not predicted scores. Two distinct families
solved correctly on their first independent submission support the label
“solved independently”; a later independent error returns the goal to practice.
A goal with a required manual explanation is not automatically judged independent.
Review suggestions use transparent 2-day or 7-day intervals, not a calibrated
psychometric or adaptive model. No official threshold, recommendation or test
result is inferred from app points.

The course key is `kompass_learning_v1`, through `ProfilePreferences`. Each lab
uses `kompass_lab_v1_<labId>`. Stores capture the active player before an await,
serialize writes and deduplicate completion IDs. Session revisions and closed
session IDs prevent old callbacks from overwriting or resurrecting a newer run.
Unreadable records are preserved; explicit local recovery backs them up before
resetting only this feature. No existing game score, game key, wallet or SRI
record is reused for course evidence.

The content package and attempt schema are versioned separately. A saved session
from another content version is rejected without deleting completed history.
Historical manual work cannot be rescored against a changed content version.
Export records before intentionally clearing browser or application storage;
remote source checkpoints do not back up a learner's device-local progress.

## Authoring and validation commands

Original interactive-task authoring sources are in `tool/kompass/`. Canonical
competency metadata comes from kompass4's `data/numbernebula_math_mapping_v1.json`.
The reviewed export is copied locally and protected by an immutable commit and
SHA-256 lock. Builders and tests reject an altered export, mismatched provenance,
wrong time units, duplicate IDs or unreviewed fields. This corrects six curriculum
links that had drifted from the source matrix, while preserving the independently
authored tasks and their explicit scoring rules. No task prose or official test
material is imported through this bridge.

Rebuild and validate with Python's standard library:

```sh
python3 -B tool/kompass/build_content.py
python3 -B tool/kompass/validate_content.py
python3 -B tool/kompass/build_print.py
python3 -B -m unittest discover -s tool/kompass -p 'test_*.py' -v
```

CI uses `--check` on both builders to reject stale generated files. The content
validator checks localized fields, competency and option references, numeric and
set answers, figures, family separation and mathematical invariants. Independent
content tests recompute answers and inspect transfer cases rather than accepting
self-declared expected values alone. The matrix distinguishes `published2025`
coverage from curriculum supplements; it does not copy an official paper.

The focused Flutter gate is `flutter test test/kompass --concurrency=1`. Browser
tests in `tool/web_live_test/tests/kompass.spec.mjs` exercise real controls,
corrections, reload/restoration, independent mode, rehearsal deadlines, all four
labs and printable downloads in the wasm and JavaScript builds. The repository's
full analysis, native suite, calibration and web checks still run remotely.

## Human evaluation still to collect

Automated tests establish software and content contracts. They do not establish
learning gains, exact difficulty, a representative rehearsal distribution or
predicted KOMPASS performance. A first learner pilot should record whether people
understand the task language, can explain their methods on paper, can use the
controls without help, and transfer learning to a new task after a delay. Review
wrong-answer patterns and completion times with a teacher before changing the
bank's difficulty labels or time estimates. Any outcome claim needs that evidence.

## Validation evidence

Local focused verification on 2026-11-09 passed **120 KOMPASS Flutter cases**
across engine/scoring, storage, figures, labs, home entry, course interactions,
paper mode and versioned review, plus the existing localization guard
(**121 passing cases, zero failures or skips**). Targeted strict analysis found
no issues. **59 Python content/print/source-mapping tests** and both reproducible
builders passed. The checked package contains 128 tasks and 257 separately
scored parts. kompass4's independent export comparison matches all 32 mappings
against this generated asset.

The resumed audit also repaired worked-solution and immediate-hint history,
stale answer overwrites, recovery when a session snapshot lags durable progress,
and retained manual-review controls. A real held-pointer regression passes with
task-specific input identity and fails when that protection is removed: releasing
the old pointer otherwise answers the next task. This negative control is a
behavioral check, not a text-presence assertion.

The previous full-suite failure was the localization guard; it now passes.
Previous browser failures used incomplete accessible names for answer fields;
the selectors now match the actual question labels. The expanded browser job
retains its one-worker and per-test limits, with enough overall time for both
engines. Full remote results remain a separate gate; local results do not imply
that queued hosted checks have passed.

Exact integrated-head full-suite, calibration, wasm/JavaScript browser and preview
results are recorded in the branch pull request. Use its current checks rather
than treating a prior checkpoint as proof of the final head:
[branch pull request and checks](https://github.com/CrispStrobe/NumberNebula/pulls?q=is%3Apr+head%3Acodex%2Fkompass4-learning-path).
Remote browser artifacts include real-control screenshots and print-layout PDFs.
Native store binaries and learner outcome studies are outside this branch's
verified results. Publication still follows the existing release process.
