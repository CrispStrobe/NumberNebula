# Human playtest protocol and missing-evidence table

Prepared 2026-10-16. Status: **protocol only — no measurements claimed.**

No child playtest sessions, focus groups, or physical-device profiling have been run for this repository. No accounts, devices, or raw observations are available on the developer side (see [HANDOVER.md](../HANDOVER.md) and [REMAINING_WORK.md](../REMAINING_WORK.md) lane H). This document defines a minimal, consent-aware protocol that *would* be used when such work becomes possible, how its results would be judged against the current untrained workload bands, and which design pars remain explicitly unvalidated. It does not introduce synthetic child data and does not change app behavior.

Lane H is owned by this file plus [pure Dart calibration](pure-dart-calibration.md) and `lib/features/games/services/felt_difficulty.dart`. Lanes A–F cover round-lifecycle hardening; lane G covers structural review flags. Lane R covers store readiness; see [release readiness](release-readiness.md).

## 1. Scope and non-goals

* **In scope:** defining what to record, how to obtain consent, and what would count as evidence for the five game families named in [REMAINING_WORK.md](../REMAINING_WORK.md): deduction games, Cargo Bay Arranger, Quantum Molecule Builder, Asteroid Field Navigator, and Cryptex Lock Breaker. The current ordinal bands in `felt_difficulty.dart` are **light / moderate / stretch / heavy** per proficiency scenario, marked `empiricallyCalibrated: false` and `confidence: low`.
* **Out of scope:** running sessions now, proposing new numeric thresholds, tuning rewards, or claiming device FPS/battery. Child-facing pars must not be retuned from generator CPU cost, host timings, or synthetic samples.

All references are repository-relative or public URLs. No local machine paths, account identifiers, credentials, or private operational notes are included.

## 2. Ethics and consent (GDPR-K / COPPA posture)

The shipped app stores no PII, transmits no play data off-device, and requires no account (see [privacy policy](privacy-policy.md)). A playtest is a *separate* research activity and must not bypass that posture. The following is the minimum consent contract; local school, district, and IRB/ethics rules add on top — they are not replaced by this file.

1. **Parental/guardian consent and child assent.** Written informed consent from a parent/guardian for each participant, plus age-appropriate assent from the child, before any session. Consent states purpose, data collected (section 3), retention window, and voluntary participation with right to stop at any time without consequence.
2. **Data minimization.** Collect only the fields in section 3. No names, photos, voice recordings, device identifiers, or school identifiers are stored with the observation. Use a session pseudonym (e.g., `P-12`) that the consent form maps to offline, held by the responsible adult — never committed to the repository.
3. **Local handling.** Observation sheets stay with the authorized researcher. Only aggregated, pseudonymous summaries are ever discussed or committed (e.g., counts, proportions). Raw sheets are deleted per the consent retention schedule.
4. **Age and setting.** Sessions are supervised, in-person, on a device the child normally uses for learning. No unsupervised remote telemetry.
5. **No deception about difficulty.** The child is told they are helping test puzzles, not being graded. Abandonment is an expected outcome, never a failure attributed to the child.
6. **Accessibility.** Reduced motion, text scale, and language (EN/DE) are recorded because they affect load; the protocol must not exclude children who need them.

If any of the above cannot be met, do not run the session.

## 3. Minimal session protocol

One row per puzzle attempt. One child may attempt multiple boards, but each row is independent — never average across children without keeping per-child traces.

### 3.1 Required fields

| Field | What to record | Why |
| --- | --- | --- |
| `session_id` | Pseudonym + date, e.g., `P-04/2026-10-20` | Links attempts by same child without PII |
| `relevant_skill_fluency` | For the game's skill: **novice-acquiring** vs **fluent** (see 3.2) | Ordinal bands are defined per proficiency scenario; a fluent child is not evidence about the novice band |
| `game_key` | Registered key from `lib/features/games/game_registry.dart` (e.g., `cargo_bay_arranger`, `alien_tribunal`) | Avoids legacy-screen confusion |
| `grade` / `level` | Requested grade (1–6) and level (1–20) as offered to the child | Determines the par under test |
| `board_seed` | Per-case seed from calibration, or frozen fixture ID (`*.fixtures.jsonl` line reference) | Exact replay via `tool/calibrate_games.dart --input` and `lib/features/games/services/game_generation.dart` |
| `locale` / `textScale` / `motion` | `en` or `de`, OS text scale at session start, reduced-motion on/off and any mid-session toggle | Controls for reading load, layout, and animation |
| `attempts` | Count of discrete submissions (dial commits, code guesses, grid fills, placement tries) | Direct error-recovery signal |
| `hints_used` | Which of the three coaching stages were shown, and whether a compatible completion was given | Hint availability changes working-memory load |
| `completion` | **completed** (solved correctly) / **abandoned** (child stopped, asked to stop, or supervisor stopped after agreed cap) | Success/abandonment is the primary band signal; abandonment is not a child failure |
| `time_on_task` | Wall-clock minutes from board shown to completed/abandoned, excluding coaching pauses where the timer is frozen | Secondary signal; never convert generator CPU ms to child time |
| `qualitative_confusion` | Short observer note in the child's own words where possible, e.g., “did not see that dial 3 is used in two equations” | Distinguishes rule misunderstanding from workload |
| `viewport` | Physical device + orientation + short/standard layout (390×500 vs 390×844 equivalent) | Phone layout can block controls (lane A–F) |
| `observer_id` | Pseudonym of the supervising adult | For debrief only; not per-child |

Do not record: name, birth date, school, device UDID, IP, or any biometric.

### 3.2 Skill-fluency tagging

Tag fluency *per skill*, not per child globally. A child can be fluent in single-digit addition and novice in multi-step deduction on the same day. Use the mapping in `lib/core/models/skill_category.dart` and `lib/features/missions/data/game_pool.dart`:

* **Novice-acquiring:** still learning the prerequisite named in `felt_difficulty.dart` for that game (e.g., “Inverse arithmetic and intersecting constraints” for Cryptex). Hesitant counting, finger use, or rereading rules are expected.
* **Fluent:** can apply the prerequisite without counting/rederivation and can hold 2–3 intermediate results.

The tag is made by the teacher/researcher who knows the child's current curriculum, not by the child's self-rating. If uncertain, tag as `unknown` and do not use the row to validate a band — exclude it from the band comparison and keep it for confusion notes only.

### 3.3 Session flow

1. **Before play:** confirm consent/assent, set `locale`/`textScale`/`motion` to the child's normal preferences, pick a board by `(game_key, grade, level, seed)` from the pre-generated fixture set so every observation is replayable. Do not hand-pick “interesting” boards during the session.
2. **During play:** facilitator does not help beyond the app's own coaching bar. Record `attempts`, `hints_used`, and a verbatim confusion note when the child pauses >30 s, repeats the same wrong move, or asks a rule question. Do not prompt or correct.
3. **End:** mark `completion` and `time_on_task`. Ask the child one open question: “What was the trickiest part of that puzzle?” Record answer in `qualitative_confusion`. Offer to stop — abandonment at any time is a valid datum.
4. **After:** debrief with the observer only. Never link `session_id` to a name in repository artifacts.

## 4. How novice/fluent observations would validate the current ordinal bands

The bands in `felt_difficulty.dart` are design assumptions with `empiricallyCalibrated: false`. The function `estimateFeltDifficulty()` returns `noviceBand` and `fluentBand` per board from weighted arithmetic/spatial/planning/reading/working-memory loads plus `workUnits` and `timePressure`. Thresholds are `light < 2.5 < moderate < 3.5 < stretch < 4.5 < heavy`. Generator speed (`CPU ms`) is not part of the score.

A validation would be a *pre-registered* comparison, not a post-hoc retuning:

* **Pre-register the prediction:** before any sessions, export the band for every fixture that will be shown, for both `novice` and `fluent`. Example from [pure-dart-calibration.md](pure-dart-calibration.md): Block Counter grade 1 level 1 is *moderate* for novice / *light* for fluent; Number Walls is *stretch* / *moderate*; Robot Path is *heavy* / *stretch*. These are the claims to test.
* **Collect matched groups:** for each `(game_key, grade, level)` cell, aim for a small but *matched* sample where the only systematic difference is the fluency tag. Unmatched groups (different ages, languages, or devices mixed) cannot validate a band.
* **Judge by proportions, not by anecdote:**

| Observation pattern | Interpretation vs current band |
| --- | --- |
| Novice group: majority complete with 0–1 hints and 1–2 attempts, no confusion note, time well under the session cap | Band may be **overstated** for novices at that cell (e.g., `stretch` predicted but behaves `light/moderate`) |
| Novice group: majority abandon or need all three hint stages, repeated same-mistake attempts, confusion explicitly about a par (e.g., “too many dials to track”) | Band may be **understated** (e.g., `moderate` predicted but behaves `heavy`) — or the par is too high (see section 5) |
| Fluent group completes where novice group abandons, with qualitatively different confusion (fluent notes about planning, novice about rule) | Supports the *split* between novice/fluent bands for that game — do not collapse them |
| Both groups abandon at same rate, or both complete trivially | Band does not discriminate at that cell; the par may not be the driver — consider whether `timePressure` or `readingLoad` is mis-weighted |
| Abandonment clusters at a single level transition (e.g., Cargo band 3→4) across both groups | Structural jump candidate — compare with lane G’s 67 flags, but do not auto-merge levels |

* **Do not:** infer ages, fit new coefficients, or move a level threshold from fewer than ~10 matched observations per cell. One child's abandonment is a qualitative signal, not a rate. Host CPU timings, browser RAF, or Firefox CPU-renderer observations are not child solving times and cannot validate a band.

If a band is contradicted, the next step is a *separately justified* proposal with the matched table, fixture IDs, and observer notes (lane H “done later”). No synthetic samples may stand in for children.

## 5. Missing-evidence table — unvalidated pars

Every par below ships with a concrete numeric scale and is enforced by generation, but none has been checked against child completion, abandonment, or confusion. The heuristic band for each game *uses* these pars to compute `workUnits`, `planningLoad`, etc., so the band inherits their unvalidated status. Lane G’s 67 structural flags are not failed boards or measured child difficulty; they must not be read as validation.

| Game family | Unvalidated par(s) today | Current scale (source) | Current heuristic treatment | What would count as evidence |
| --- | --- | --- | --- | --- |
| **Deduction** — Alien Tribunal, Crew Manifest, Vault Cracker (and Gravity Well, Xenobiology) | **Tribunal:** `personCount` 3→5 by grade/level (`alien_tribunal_logic.dart`: 3 at grade 1, 3–4 at grade 2, 4–5 at grades 3–6; `pair`/`count` claims only at grade ≥3). **Manifest:** board `size` 3→5 and `directClueCount` `size-1` → `ceil(size*0.5)` (`crew_manifest_logic.dart`). **Vault:** `codeLength` 3→4 and `digitRange` 5→8 with clue-set size implicit (`vault_cracker_logic.dart`). **Categorical:** max attempts/lives per game is a separate product decision. | Grade + level tables, not a single formula. Deduction boards are also checked for *unique* solution via validators in `generated_board_validation.dart`, but uniqueness ≠ appropriate difficulty. | `felt_difficulty.dart` `alien_tribunal/crew_manifest/vault_cracker` branch: `units = personCount / size / length`, `planning = 1.8 + units/5`, `reading = 1.4` for the text-heavy trio. Assumes linear planning growth with unknowns. | Matched novice/fluent completion and abandonment by `personCount`/`size`/`codeLength` step, with confusion notes distinguishing “cannot parse statement” (reading) from “cannot hold hypotheses” (planning). Would show whether grade-3 introduction of `pair`/`count` statements is a true step or a reading cliff. |
| **Cargo Bay Arranger** — `cargo_bay_arranger` | **Band:** `band = ceil(grade + level/5) - 2` clamped 0–6 (`cargo_generation.dart`). Drives `numberMin/Max` 1–5→5–20, `targetSum` 15→75, `dropSpeed` 1000→400 ms, `rowsToWin` 8→20. **Generation policy:** 30% `sequenceChance` (consecutive runs) + 30% `targetSumChance` (cluster near `targetSum/gridCols`) behind a 7-bag shape fairener. | Seven discrete bands shared by live game and CLI calibration. Higher bands increase arithmetic span, target magnitude, speed, and required clears simultaneously. | `felt_difficulty.dart` `cargo_bay_arranger` branch: `units = rowsToWin`, `planning = 2`, `spatial = 1.3`, `arithmetic = 1.5`, `timePressure = true`. Planning is flat across bands; speed and span contribute only via `workingMemory`. | Timed sessions on native devices measuring `rowsCleared` per minute, top-out rate, and whether bonuses (consecutive/sequence) are ever *noticed* vs. hit by chance. Would validate whether speed (400–1000 ms) or arithmetic span (1–5 vs 5–20) dominates abandonment — currently inseparable in the heuristic. Synthetic 24k calibration cases prove row generation does not fail validation; they do not prove win rates. |
| **Quantum Molecule Builder** — `quantum_molecule_builder` | **Level identity:** 30 authored `molecule_levels.json` boards, selected by `(level-1)` index, not procedurally generated (`game_generation.dart`). **Move allowance:** `moveLimit = round((duration/4.5 + atomCount*1.5) * gradeFactor)` where `gradeFactor` 1.3/1.2/1.1/1.0 for grades 1–4 (`game_generation.dart:439`). **Reference:** `optimalMoves` is an *asset* value, not a solver proof. | Authored pool with grade-scaled allowance. The 42 repeated “Molecule layout transition” strings in the 60,400-board sweep are the same 7 authored transitions copied across grades — they are structural flags, not defects. | `felt_difficulty.dart` `quantum_molecule_builder` branch: `units = optimalMoves` (asset), `planning = 1.5 + min(3, units/15)`, `spatial = 1.2`. Treats fewer allowed moves as harder even if board workload is similar. | Child move counts vs `optimalMoves` on the *same* authored boards, plus reset/undo usage and qualitative notes about dead ends. Would show whether the `gradeFactor` tightening is felt as “stretch” or as arbitrary failure, and whether asset optima are realistic for children or only for search. |
| **Asteroid Field Navigator** — `asteroid_field_navigator` (Minesweeper) | **Grid/mine par:** complexity `grade + level/5` maps to `(6,6)/(8,10)/(10,15)/(12,25)/(15,40)/(20,70)` (`game_generation.dart:275`). **Rules:** first click never a mine (regenerated), neighbour counts are validated, but board has no difficulty-aware “is this board solvable without guessing” guarantee. **Timer:** soft scoring bonus only; no hard limit. | Six discrete complexity bands replacing the generic `DifficultyManager` for this game. | `felt_difficulty.dart` `asteroid_field_navigator` branch shares the generic branch with Sector Painter/Ion Chain/Dark Matter: `units = gridRows*gridCols`, `planning = 2.5`, `spatial = 0.8`. Mine density is not an explicit load term. | Reveals/flags per minute, flag precision, and abandonment by density band on matched devices, plus notes on whether children use neighbour deduction vs guessing. Would validate whether the 12→15→20 jump (25→40→70 mines) is a planning or a memory/tracking cliff. Generator neighbour-count correctness does not validate difficulty. |
| **Cryptex Lock Breaker** — `cryptex_lock_breaker` | **Dial/operator par:** complexity `grade + level/5.0` maps to 3 dials `+,-` → 3–4 dials `+,-,*` → 4 dials `+,-,*,/` → 4–5 dials `+,-,*,/` (`cryptex_logic.dart:37`). Equations are `dialCount-1` chained pairs plus one long-range equation at ≥4 dials, wrapped to guarantee solvability from a sampled solution. | Operator set and dial count increase together; division falls back to addition when not clean. | `felt_difficulty.dart` `cryptex_lock_breaker` branch: `units = dialCount`, `planning = 1.8 + units/5`, `reading = 0.3`. Treats every extra dial as +0.2 planning, regardless of operator. | Dial-commit count vs `dialCount` minimum (any solver must set non-initial dials), equation-satisfaction rate, and confusion notes like “did not realize dial 3 appears in two equations” vs “cannot compute `*`”. Would separate arithmetic load (operator set) from planning load (dial coupling). Performance signal is already `Perf.fromMoves` in `cryptex_lock_breaker_game.dart`; it is a reporting hook, not validation. |

For every row, the correct next artifact is a **separate findings table** with seed/commit/sample counts, matched novice/fluent proportions, and the fixture IDs that support a threshold proposal. Do not auto-tune thresholds from this file.

## 6. What to do when devices and participants become available

1. **Re-read this protocol and lane H together.** Confirm consent, then select a *small* fixture set that spans the predicted bands (`light` through `heavy`) for one of the five families. Do not start with all games.
2. **Run matched sessions** per section 3–4. Record pseudonymous rows only.
3. **Analyze per band, not per score.** Compare observed completion/abandonment and hint use to the pre-registered band. Quote observer notes that distinguish rule confusion from workload.
4. **If warranted, propose a single par change** with the supporting table (commit, seed, grade/level, fluency, `n`, observed proportion vs prediction). Keep the change out of the protocol file — it belongs in a dedicated PR with its own evidence.
5. **Collect native device measurements separately.** Frame time, memory, and RAF intervals are lane H device work, not part of this protocol. Physical-device FPS or battery conclusions cannot be drawn from headless tests or browser probes.

## 7. References

* Workload heuristic: `lib/features/games/services/felt_difficulty.dart`
* Board generation and validation: `lib/features/games/services/game_generation.dart`, `lib/features/games/services/generated_board_validation.dart`
* Calibration and workload notes: [pure Dart calibration](pure-dart-calibration.md)
* Performance ratio (reporting, not validation): `lib/features/games/models/performance.dart` and `Perf.*` call sites in `lib/features/games/screens/*.dart`
* Game inventory: `lib/features/games/game_registry.dart` and `lib/features/missions/data/game_pool.dart` (`debugOnlyGames` is empty — all 48 games are available)
* Store process (separate lane): [release readiness](release-readiness.md), `.github/workflows/release.yml`, `.github/workflows/submit.yml`, `pubspec.yaml`, `fastlane/Fastfile`

No synthetic samples, host timings, or browser RAF numbers are presented as child results. No device or playtest data are claimed.
