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

## Delivery checklist

- [ ] Versioned original bilingual content covering all 32 competencies, with
  separate practice, independent-check and rehearsal families.
- [ ] Explicit per-part answer rules, partial credit, units, misconceptions,
  explanations and reviewable manual criteria.
- [ ] Profile-scoped immutable first-attempt evidence, assistance and revisions,
  idempotent recording, resumable sessions and independent skill progress.
- [ ] Guided course, next-activity planning, glossary, existing-game practice links,
  independent checks, a 45-minute working-period rehearsal and a progress report.
- [ ] Interactive activities for place value/number lines, everyday quantities,
  data/probability and geometry; keep learning untimed and support accessible input.
- [ ] Matching printable practice and review output from the content package.
- [ ] Content validation, focused scorer/planner/persistence/widget tests and
  exact-branch remote CI/build/browser checks, with evidence recorded honestly.

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

## Validation evidence

Implementation and validation are in progress. This document will be updated
with exact commit/run URLs and remaining limits before handoff.
