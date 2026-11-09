# KOMPASS mathematics content and paper authoring

This directory contains the original interactive tasks for NumberNebula's optional
KOMPASS 4 mathematics pathway. It produces one bilingual content package and
standalone paper worksheets from the same reviewed tasks. Canonical competency
metadata is imported from a pinned kompass4 export. All tools use the Python
standard library; run them from the repository root.

## Current content

The package contains **128 original tasks and 257 separately scored parts** across
all 32 project-owned competency identifiers. Each competency has two practice
tasks, one independent check task and one rehearsal task: 64 practice, 32 check
and 32 rehearsal tasks.

| Domain | IDs | Competencies | Tasks |
| --- | --- | ---: | ---: |
| Numbers and operations | `M-Z01`–`M-Z12` | 12 | 48 |
| Space and shape | `M-R01`–`M-R08` | 8 | 32 |
| Quantities and measurement | `M-G01`–`M-G07` | 7 | 28 |
| Data and chance | `M-D01`–`M-D05` | 5 | 20 |

Tasks include conventional four-digit arithmetic, place-value regrouping, number
walls, inverse relationships, constrained problems, explanations, units and money,
clocks and timetables, measured paper constructions, rotations, reflections,
cube plans and nets, chart construction and criticism, and qualitative probability.
This is a mathematics pathway, not a German-language test preparation course.

`published2025` means the project's competency mapping identifies a related task
type in the published 2025/26 mathematics paper. It is not an official competency
code, certification, calibrated difficulty or promise about future papers. The
eight broader curriculum entries are `M-Z11`, `M-Z12`, `M-R01`, `M-R08`, `M-G06`,
`M-G07`, `M-D02` and `M-D03`. The other 24 entries use `published2025`.

## Edit and regenerate

| File | Responsibility |
| --- | --- |
| `common.py` | Small authoring helpers; no answer inference from prose |
| `competencies.py` | Bilingual goals, evidence labels, curriculum and existing game links |
| `source_mapping.py` | Validates pinned competency metadata and its provenance |
| `source_mapping_v1.json`, `source_mapping.lock.json` | Reviewed kompass4 export and immutable source/hash lock |
| `sync_mapping.py` | Imports or checks an explicitly reviewed source export |
| `content_numbers.py` | Numbers and operations tasks |
| `content_geometry.py` | Space and shape tasks |
| `content_measurement.py` | Measurement and applied quantity tasks |
| `content_data.py` | Tables, charts and chance tasks |
| `build_content.py` | Deterministic JSON export |
| `validate_content.py` | Schema, localization, coverage, partition and figure checks |
| `build_print.py` | Learner worksheets, separate keys and exposure manifest |
| `test_content.py` | Independent mathematical and contract regressions |
| `test_print.py` | Print isolation, manifest and precise figure regressions |

Edit the authoring sources rather than generated JSON or HTML. Then run:

```sh
python3 -B tool/kompass/build_content.py
python3 -B tool/kompass/build_print.py
```

The committed products are `assets/kompass/math_v2.json` and these files under
`assets/kompass/print/`:

- `practice_de.html` and `practice_en.html`
- `practice_de_solutions.html` and `practice_en_solutions.html`
- `rehearsal_de.html` and `rehearsal_en.html`
- `rehearsal_de_solutions.html` and `rehearsal_en_solutions.html`
- `manifest.json`

Use all four gates before a content checkpoint:

```sh
python3 -B tool/kompass/validate_content.py
python3 -B tool/kompass/build_content.py --check
python3 -B tool/kompass/build_print.py --check
python3 -B -m unittest discover -s tool/kompass -p 'test_*.py' -v
```

The `--check` commands compare generated output byte for byte and do not write
files. Avoid timestamps, random generation and environment-dependent formatting.
Python `-B` keeps bytecode caches out of the repository.

## Updating the kompass4 mapping

kompass4 owns the 32 project competency IDs, domain and evidence classifications,
curriculum codes/URLs/versions, and author-estimated time bounds. The export is
deliberately limited to those fields. It contains no source task prose, solutions
or official papers and grants no license to other kompass4 documents.

The initial reviewed export is at
[`f57dddd`](https://github.com/CrispStrobe/kompass4/commit/f57ddddb17db338e7f7f94b3463d62b6c8091ce3).
It preserves the original matrix pin and records time bounds explicitly in
**seconds**, separately from task duration estimates. The source has no authored
prerequisite graph; the course does not invent one.

For an update, review the export and its source matrix in kompass4, then supply
the exact commit containing it:

```sh
python3 -B tool/kompass/sync_mapping.py \
  --source ../kompass4/data/numbernebula_math_mapping_v1.json \
  --source-commit FULL_REVIEWED_COMMIT_SHA
```

Add `--check` to compare without writing. The importer is offline; the reviewer
must verify that the supplied commit contains those bytes. Builders verify the
local SHA-256 lock on every run. After changing the mapping, bump the content
version, regenerate JSON and paper output, and run the four gates above. The
generated package includes the exact source/export provenance under
`source.competencyMapping`.

## Content contract

The asset has `schemaVersion: 2`, a semantic `version`, original-work `source`
metadata, `competencies` and `tasks`. Every task has stable `id` and `familyId`,
`domain`, `use` (`practice`, `check` or `rehearsal`), a local `level` from 1 to 3,
bilingual `title` and `prompt`, progressive `hints`, a worked `solution`,
explicit `parts`, optional `figure`, author-estimated `estimatedSeconds` and
original-work provenance.

All user-facing text maps have nonempty `de` and `en` values, including error
feedback, criteria, rubrics, descriptions and table/chart labels. Language-neutral
letters, numbers and unit symbols may remain strings. German place-value initials
are localized: `H/Z/E` become `H/T/O` in English.

Each part carries its own `competencyIds` and `maxPoints`. Evidence belongs to
these mappings rather than every competency mentioned elsewhere in a task.

| Part `kind` | Answer `type` | Answer fields |
| --- | --- | --- |
| `number` | `number` | Numeric `value`; optional numeric `tolerance` |
| `choice` | `choice` | Option ID in `value` |
| `multiChoice` | `set` | Exact option IDs in `values` |
| `order` | `sequence` | Ordered option IDs in `values` |
| `cells` | `set` | Added cell IDs in `values` |
| `text` | `manual` | Bilingual `criteria` and reviewable `rubric` |

Options use stable IDs separate from translated labels. Numeric parts specify
the requested `unit` so bare numbers and compatible unit suffixes can be
interpreted consistently. Do not silently accept an unconverted metre value
when centimetres are requested. Clock readings use separate numeric hour/minute
parts or a choice; `15:25` is not a decimal number.

Known errors have an explicit `value`, diagnostic `code` and bilingual
`feedback`. Feedback should address a misconception. Give useful intermediate
hints and a worked explanation, keeping them outside assessment givens.

Manual text and paper constructions require review against the rubric. A
submitted explanation, self-rating or opened model answer is not verified
competence. Accept equivalent mathematical explanations during review. An
automatically correct result does not prove an explanation is correct.

Dependent numeric parts may declare `carryFrom` and `carryOffset` for separate
carried-error credit. The task must explicitly ask the learner to reuse that
earlier value. Both values must be feasible and nonnegative; whole counts
require integers, while euro amounts allow whole cents. The app and paper keys
keep this credit separate from independently correct solutions.

## Figures and accessibility

Figures contain `kind`, mathematical `data` and bilingual `alt`. They describe
givens, not completed answers. Number-line marks store numeric coordinates for
positioning while displaying only their labels. Alt text conveys equivalent
position or scale information without doing the requested calculation.

| Figure kind | Main data |
| --- | --- |
| `wall` | `rows` from bottom to top; `null` means blank |
| `numberLine` | `min`, `max`, `step`, `marks: [{value, label}]` |
| `placeValue` | `columns: [{label, value}]` |
| `grid` | `rows`, `cols`, `filled: ["row,col"]` |
| `table` | `headers`, `rows` |
| `barChart` | `labels`, `values`, `max`, `step`, optional `yLabel` |
| `cubePlan` | Rectangular `heights` matrix and `view: front` or `right` |
| `cubeNet` | `rows`, `cols`, `cells`, optional cell-to-label `labels` map |
| `clock` | `hour`, `minute` |
| `tokenBag` | `tokens: [{label, count}]` |
| `spinner` | `sectors: [{label, weight}]` |
| `shapeComparison` | `shapes: [{id, cells}]` |
| `measureLine` | `start`, `end`, `step`, `unit` |
| `polygon` | Cartesian `points: [[x, y]]`; optional vertex `labels` |
| `mirror` | `rows`, `cols`, `cells`, `axis: {direction, at}` |

Grid coordinates are zero-based from the top left; prompts and paper key labels
use one-based rows/columns. Cell answers list **only additions**, excluding given
cells. Use explicit input bounds for net completion.

A vertical mirror at grid line `at` maps column `c` to `2 * at - 1 - c`;
the horizontal equivalent applies to rows. Polygon coordinates use Cartesian
orientation. The print renderer flips the vertical display axis and uses one
scale for both dimensions to preserve angles and ratios.

All panels of one `shapeComparison` share a common square size and extent.
Fitting each panel independently would distort area comparisons. Cube-plan rows
run from back to front; show every tower height and the viewing direction.
A drawing that hides rear stacks cannot replace those numeric givens. Do not
show a derived silhouette beside a question asking for it.

Bar charts start at zero and use the specified labelled step. Clock hour hands
advance with minutes. Geometry is schematic unless physical dimensions have
been produced and verified. Real measurement tasks direct the learner to draw
on separate paper using a ruler.

## Protect checks and rehearsal

Partition whole reasoning families by mode. Changed numbers, translations,
characters, pictures or task IDs do not automatically make a new independent
family. Compare the operation structure, representations, constraints and
required reasoning. Reuse family IDs for true variants and keep the family
within one mode.

The validator rejects identical family IDs spanning modes. It cannot prove that
differently named families are conceptually distinct, so human review is still
required. Targeted tests also guard specific risks, such as reusing a practiced
cube-net topology in a held-out net selection.

Opening a hint, solution, key or printed task is an exposure even without an
answer. The app can record exact task/family exposure using `manifest.json`.
A later numeric variant of an exposed family is not fresh independent evidence.
Save learner events with package version and stable identifiers so content
changes do not silently reinterpret historical evidence.

Practice printing includes all 64 practice tasks and no check/rehearsal items.
The rehearsal form contains 20 tasks in `REHEARSAL_IDS`, with their exact IDs
emitted in the manifest; the other 12 rehearsal tasks remain available in the
app. This is an authored cross-domain form, not an official distribution of
competencies, points or difficulty.

## Paper use and review

HTML files are self-contained with CSS and inline SVG and require no network.
Open a learner file, optionally filter a domain, then use **Print / save as PDF**.
Open the separate solutions file after the independent attempt. Learner files
contain no embedded answer rules, hints, solutions, rubrics or diagnostic
feedback, including in hidden markup or JavaScript.

Rehearsal allows **45 minutes of work after general instructions**, including
task reading and checking. Practice has no time limit. Selection and estimated
times have not been calibrated with learners. Points and completion times do
not imply an official level, future score or school recommendation.

Keys provide per-part answers, manual rubrics, carried-error notes, worked
explanations and a blank review table. Keep omissions, mistakes, assistance,
carried errors and unreviewed text separate.

Before releasing changed layout, inspect both learner files and keys in supported
browser engines and inspect print pagination. Check figure readability, response
space and clipping, and equal square units in the four-net comparison. Python
tests inspect SVG geometry and content separation; they do not certify browser
pagination or physical print dimensions.

## Verification and limits

Mathematics regressions independently recompute representative arithmetic and
measurement answers, use exact decimal money, enumerate constrained solutions,
apply grid transformations, fold nets by propagating independent 3D face bases,
and check table/chart/probability invariants. Negative contract tests reject
bad options, cells, localization, carry rules and partitions. Print tests inspect
geometry, preserve givens, verify exact manifest exposure and prevent answer
payloads in learner output.

These checks complement editorial mathematical review of all authored tasks.
They do not mechanically prove every natural-language interpretation, calibrate
difficulty, guarantee accessibility for every learner or validate a prediction
model. Add a focused independent regression for new mathematical relationships
and previously missed errors.

## Provenance and rights

These exercises were newly authored for NumberNebula under **AGPL-3.0-only**.
The package records the project-owned mapping reference `CrispStrobe/kompass4`
at commit `9a0b25a6b0706b7c7944836e00f163bcbfd46676`, plus curriculum and official
assessment-information links.

This grants no new license to the separate kompass4 repository or its documents.
The package embeds or adapts no official test item, official solution booklet
or private non-mathematics document. Do not import official PDF text or figures
into this original-work package. Check proposed external material's rights
separately and record provenance explicitly.
