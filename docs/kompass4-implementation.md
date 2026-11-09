# KOMPASS 4 mathematics pathway

## Scope

Implement the complete optional mathematics pathway across numbers and operations,
space and shape, quantities and measurement, and data and chance. Keep free play,
all existing games, local profiles, saved progress, and the all-ages positioning.
The foundation is checkpointed on `codex/kompass4-learning-path` (PR #69).
The active combined implementation is on `integrate/kompass4-all`
([PR #71](https://github.com/CrispStrobe/NumberNebula/pull/71)). It includes the
foundation/harder labs from #69, the reasoning expansion from #70 and the six
original kompass4 papers. Continue on this integration; the two earlier PRs
are component histories.

The authoring reference is CrispStrobe/kompass4 at
`9a0b25a6b0706b7c7944836e00f163bcbfd46676`. Its 32 mathematics competency IDs
are project-owned identifiers, not official IBBW assessment codes. Published
official papers remain linked references and are not embedded or adapted.

The current implementation uses app version **1.6.3+69** and content version
**2.1.0**: 144 original bilingual tasks, 298 scored parts and eight labs with
22 activity types. See [the reasoning expansion](kompass4-reasoning-expansion.md)
for the four added labs and 16 added tasks. A separate original-paper package
adds 120 German tasks, 249 parts and 240 points across six 20-task papers. Its
version is 1.0.0; the combined loader identifies both packages as
`2.1.0+k4.1.0.0`. English UI retains these papers' German wording.
kompass4 supplies a deterministic, pinned competency metadata export;
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
`version`, `source`, `competencies`, `tasks`, and `compatibleTaskIds`. Localized strings are maps with
`de` and `en`. Competencies contain `id`, `domain`, `title`, `goal`, `evidence`
(`published2025` or `curriculum`), `curriculumUrl`, and `gameKeys`.

Tasks contain `id`, `familyId`, `domain`, `title`, `prompt`, `level` (1–3),
`use` (`practice`, `check`, `rehearsal`, or the separately imported `original`), `parts`, `hints`, `solution`, and
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
the eight labs. Learners do not need an account, a cloud model or a network call
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

Opening journey planning or chance counterexamples also records the specific
course families whose procedure the lab teaches, before navigation. Leaving
without a submission cannot later turn those items into unseen checks. This is
an explicit family mapping, not a claim that every related competency is now
exposed. Lab results remain practice only. First-response hint counts are frozen
separately from hints used during later corrections and survive reopening.

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
Lab reads and writes share a queue for each captured player and lab. A reopened
screen takes ownership of its draft, so a delayed completion from the old screen
cannot replace a later round, response or hint history. Retained input controls
also stop accepting edits after disposal or an ownership change.
Unreadable course records are preserved; explicit local recovery backs them up before
resetting only this feature. No existing game score, game key, wallet or SRI
record is reused for course evidence.

The content package and attempt schema are versioned separately. Version 2.1.0
compares all 128 earlier task objects with the immutable 2.0.1 baseline and
declares only those exact identities compatible. A saved session may resume only
when every selected task passes this check; review may reuse a rubric only for a
compatible task. Unknown versions, changed tasks and invalid task lists still
fail closed without deleting completed history. Existing attempts retain their
original content version when revised.
Export records before intentionally clearing browser or application storage;
remote source checkpoints do not back up a learner's device-local progress.

## Original kompass4 practice papers

Like WordUniverse's German course, the pathway now also carries the six
original 45-minute mathematics papers from kompass4 (`mathe1`–`mathe6`,
120 tasks, 240 points), beside the 144 NumberNebula tasks. kompass4 owns the
papers and their interactive answer companions
(`content/interactive/mathe1.json` …, exported by
`python -m kompass.export_interactive_math`); this repository pins that
export in `tool/kompass/kompass4_math_source.json` and converts it with
`tool/kompass/import_kompass4_math.py` into
`assets/kompass/kompass4/math_original.json` plus 63 PNG diagrams rendered
by the print renderer (316 KB). The PDF booklets are linked at the pinned
kompass4 commit, not bundled.

- Tasks use `use: original`; practice, check and rehearsal selection never
  draws them. The hub lists each paper with *Als Test* (timed rehearsal mode,
  45 minutes, feedback at the end) and *Üben* (practice mode with hints).
- The repository merges the two packages at load time. The combined version
  names both inputs; `compatibleTaskIds` keeps records made against the
  main package alone usable.
- Task text is German. Text, tables and diagrams render in print order through
  the `stack`, `text` and `image` figure kinds; a sub-question repeated in its
  answer part is shown once.
- Scoring follows the companion: numbers (with optional count words such as
  "Kinder", and cent amounts where the rubric accepts them), short text with
  rubric review for other wordings, choices, order, and rubric-reviewed
  drawings and explanations. Where a rubric credits a correct continuation of
  a wrong earlier step (`followOnFrom`), the later answer goes to rubric
  review instead of scoring zero.
- Declared `creditSteps` govern the available manual-review values and scorer
  acceptance. Parts without that field retain their established review options.
  Earlier saved scores remain readable; an out-of-step historical review is
  identified in the review screen and changes only when explicitly reviewed.
  Updating one part preserves other parts' historical reviews and never changes
  the immutable first response or score.

## Lab recipes

Recipe 2 (1.6.1) made the original four labs harder: build-number clues
instead of digits, regrouping with a written value (`regroupWrite`),
non-round number-line endpoints, fractional litres with a limited supply,
relational chance goals, composed events, nine symmetry shapes and all eleven
cube nets. Recipe 1 keeps the frozen original generators in
`legacy_lab_rounds_v1.dart`. A draft records its recipe; drafts saved before
the change replay with recipe 1, and the next round uses recipe 2.
`tool/kompass/audit_legacy_lab_recipes.dart` checks recipe 1 byte for byte
against `8971225`.

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
python3 -B tool/kompass/import_kompass4_math.py --check
python3 -B -m unittest discover -s tool/kompass -p 'test_*.py' -v
```

CI uses `--check` on the content/print builders and original-paper importer to
reject stale generated files or a mismatched imported figure set. The content
validator checks localized fields, competency and option references, numeric and
set answers, figures, family separation and mathematical invariants. Independent
content tests recompute answers and inspect transfer cases rather than accepting
self-declared expected values alone. The matrix distinguishes `published2025`
coverage from curriculum supplements; it does not copy an official paper.

The focused Flutter gate is `flutter test test/kompass --concurrency=1`. Browser
tests in `tool/web_live_test/tests/kompass.spec.mjs` cover real controls,
corrections, reload/restoration, independent mode, rehearsal deadlines, the
original labs and printable downloads in the wasm and JavaScript builds. New
reasoning/chance flows add persisted-input and first-response assistance checks.
The repository's
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

### Integrated application

For exact head `2546d4245e2594662340d1c02a4473bac480ca3c`,
[CI attempt 2](https://github.com/CrispStrobe/NumberNebula/actions/runs/42671817079)
passed strict analysis, 83 Python cases, the four standalone lab audits,
**187 focused KOMPASS tests** and the **2,247-test full native suite**. The
successful native logs contain no reported skipped or failed cases. The focused
KOMPASS tests are part of the full suite and must not be added to its count.
[Pure calibration attempt 3](https://github.com/CrispStrobe/NumberNebula/actions/runs/42671816877)
passed **60,400 generated cases across all 48 games with zero failures**.

The [web workflow for that head](https://github.com/CrispStrobe/NumberNebula/actions/runs/42671817293)
completed the WASM/JavaScript build and headless capture/replay jobs; its browser
job was still queued when checked. Follow-up source or browser-test edits require
their own exact-head gates. Current results are recorded in
[PR #71 checks](https://github.com/CrispStrobe/NumberNebula/pull/71/checks).

### Foundation and expansion history

The expansion's local content and mathematical checks are recorded separately in
[its validation table](kompass4-reasoning-expansion.md#validation). They do not
inherit the foundation's earlier Flutter result below. New widget and browser
tests must pass on the exact expanded head before merge; a queued workflow is
not a passing result.

The preceding checkpoint
[`bc12371`](https://github.com/CrispStrobe/NumberNebula/commit/bc12371e969cb0ef8cac9e8765b9b920a55d11d7)
records local verification on 2026-11-09 of **120 KOMPASS Flutter cases**
across engine/scoring, storage, figures, labs, home entry, course interactions,
paper mode and versioned review, plus the existing localization guard
(**121 passing cases, zero failures or skips**). Targeted strict analysis found
no issues. **59 Python content/print/source-mapping tests** and both reproducible
builders passed. The checked package contains 128 tasks and 257 separately
scored parts. kompass4's independent export comparison matches all 32 mappings
against this generated asset.

Two additional lab repairs are saved in **1.6.0+65**:

- Numeric answers now use the shared unit-aware parser. Length accepts written
  millimetres and rejects euros or centimetres; shopping accepts written euros
  and rejects unrelated units. Bare values and decimal commas remain supported.
- Reopening a lab now serializes storage across screen instances and prevents
  obsolete completion callbacks or retained controls from replacing its draft.

Three numeric-scoring regressions and two lifecycle widget regressions accompany
these repairs. They cover actual scoring, delayed completion after reopening and
advancing, retained input, saved hints and first-response preservation. The
integrated application at
[`ac504b0`](https://github.com/CrispStrobe/NumberNebula/commit/ac504b09be02f79d7704bd028f4ba284feaf3989)
passed **126 focused Flutter checks**: all **125 KOMPASS cases**, including the
five new lab cases, plus the localization guard, with zero failures or skips.
Targeted strict analysis also found no issues. The subsequent documentation and
test-formatting update does not change that application code. The **59 Python
tests**, content validator and both reproducible builders also passed. Full
remote analysis, the complete app suite, calibration and both browser engines
remain separate required gates.

**1.6.1+66 — lab difficulty.** Several lab prompts gave the answer away:
the build-number round showed its target in digits, the regroup round stated
the value it was worth, capacity targets read off directly as bottles and cups,
the chance round only asked for as many circles as stars, and the number line
showed both distances live. Now:

- Build-number targets come as a number word, as scrambled places that usually
  include an empty place, as an un-bundled amount, or as a step of 1/10/100
  across a place boundary. The running value display is gone.
- Regroup starts from material with at least two over-full places, does not
  state its value, and scores the regrouping and the written number separately
  (2 points).
- Number-line midpoints use varied endpoints (step 10); the live distance
  readout is removed.
- Capacity targets use ¼, ½ and ¾ litre, and about half of the rounds limit the
  bottle supply so cups must replace litres.
- Chance rounds include triangles as a distractor and ask for equal, double or
  complement-equal chances; event rounds classify composed events against the
  actual bag.
- Symmetry rounds draw from nine shapes with zero to four axes, verified by
  reflecting each vertex set; cube-net rounds grow any of the eleven nets.

The first difficulty change introduced schema 2. The integrated version preserves
older drafts with frozen recipe-1 generators instead of discarding or
reinterpreting them; after completion, the next round uses recipe 2. Seven new
generator tests cover the revised rounds, alongside the frozen recipe audit.

**1.6.1+67 — preserve intermediate regrouping.** A generated round could
legitimately hold 30 hundreds after a trade, while restoration previously capped
each place at 29. Reopening then changed the represented number. Controls and
restoration now share a bound of 99, and trades stop before exceeding that bound.
A real-control regression reproduces the old failure with seed 46 (8005 became
7905), then verifies reopening and successful completion with the repair. A
second regression checks counter/trade limits, reopening and continued input.
The browser geometry test now selects three axes before requesting feedback:
an empty selection is a correct answer for the new parallelogram round.
The integrated application passed **135 focused Flutter checks** (134 KOMPASS
cases plus the localization guard, zero failures or skips), and strict targeted
analysis found no issues. The browser script passed its syntax check; actual
browser execution remains part of the required remote gate.

The resumed audit also repaired worked-solution and immediate-hint history,
stale answer overwrites, recovery when a session snapshot lags durable progress,
and retained manual-review controls. A real held-pointer regression passes with
task-specific input identity and fails when that protection is removed: releasing
the old pointer otherwise answers the next task. This negative control is a
behavioral check, not a text-presence assertion.

The previous full-suite failure was the localization guard; it passed in the
preceding checkpoint's local verification.
Previous browser failures used incomplete accessible names for answer fields;
the selectors now match the actual question labels. The expanded browser job
retains its one-worker and per-test limits, with enough overall time for both
engines. Full remote results remain a separate gate; local results do not imply
that queued hosted checks have passed.

Exact integrated-head full-suite, calibration, wasm/JavaScript browser and preview
results are recorded in the branch pull request. Use its current checks rather
than treating a prior checkpoint as proof of the final head:
[integration pull request and checks](https://github.com/CrispStrobe/NumberNebula/pull/71/checks).
Remote browser artifacts include real-control screenshots and print-layout PDFs.
Native store binaries and learner outcome studies are outside this branch's
verified results. Publication still follows the existing release process.
