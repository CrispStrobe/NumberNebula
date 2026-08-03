# Improvement Plan — space_math_academy & voc (WortUniversum)

Open punch list across both apps. Sibling repo: `../voc` for WortUniversum
(German grammar/vocab); this repo for space_math_academy (math). Both ship.

Everything already finished — the two audit passes, Tiers 1-8, the StarLoader
solver overhaul, the Vercel deployment fix, and the 2026-08-01 mission-grading
work — lives in **[HISTORY.md](HISTORY.md)**. Only open items are listed here.

## Status legend

- [ ] not started
- [/] in progress
- [x] done
- [-] decided not to do

---

## Open items

### [ ] Cargo Bay Arranger — board-aware row generation
The seeded 7-bag landed; what's left from the 2026-05-30 audit is the harder
half: `dart_csp`-backed, board-aware "fill the open row to `targetSum`"
generation for higher grades. Keep any CSP instance tiny — the solver is
uninterruptible once started.

### [ ] Normalize the `arithmatic_square` typo key
`skill_category.dart` and 12 other sites use `'arithmatic_square'` (matches the
typo'd filename, so it is functionally fine). Renaming touches the game key,
the menu, `gameSkillMap`, `kStarThresholds`, the mission game pool, the l10n
key names and the contract tests — cosmetic, do it in one sweep or not at all.

---

## Follow-ups from the mission-grading work (2026-08-01)

### [ ] Play-test the per-game grading thresholds
Every game now reports a 0..1 performance ratio, but a few of the pars are
judgement calls made from reading the code, not from playing:
- deduction games (vault cracker, signal triangulation) treat *half* the guess
  allowance as par
- cargo bay expects roughly one equation bonus per four cleared rows
- atomix expects the molecule inside half the move limit
- minesweeper's par is one second per cell
- cryptex counts one committed dial setting per wrong-at-start dial as par
Watch real sessions and retune; the constants are all at the `Perf.*` call
sites in `lib/features/games/screens/`.

### [ ] Show the grade in the games themselves
The performance grade is currently only visible on mission task tiles. The
per-game success dialogs still show raw score (and stars, which now derive from
performance). Surfacing `PerformanceBadge` in the end-of-round dialogs would
make the feedback consistent everywhere — ~48 dialogs, so worth a shared helper.

### [ ] Regenerate the launcher icons from the compressed source
`assets/images/app_icon.png` was re-encoded (1342 KB → 441 KB, same 1024×1024
art). The per-platform icons under `android/`, `ios/`, `macos/` and `web/` were
generated from the old file and were left untouched — they are byte-identical
art, so this is housekeeping, not a bug. Run
`dart run flutter_launcher_icons` next time the icon changes for real.