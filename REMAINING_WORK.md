# Remaining Work -- Game Quality Fixes

Status as of 2026-05-31 ~17:00 UTC.

---

## KNOWN ISSUES (from user testing)

### HIGH PRIORITY (broken/unplayable)

1. **Launch Sequence** -- dark blue on dark blue, completely invisible. The ship cards and container blend with SpaceBackground. Needs high-contrast colors or different background for the game area.

2. **Creature Forge** -- taps don't register on web/mouse. Added `HitTestBehavior.opaque` but may still fail. Needs playwright testing to verify.

3. **Galactic Market** -- same click issue as Creature Forge. Added `HitTestBehavior.opaque`.

4. **Xenobiology Lab** -- gameplay is just "slide sliders until green". Not engaging as a game. Needs a better mechanic -- perhaps show animated creatures entering a scene and the player must COUNT them, then verify against the census totals.

5. **Ion Chain** -- rule text now uses shape names but the overall puzzle logic may still generate trivial or contradictory puzzles. The fallback pattern (alternating types) is boring. Needs verification via Playwright.

### MEDIUM PRIORITY (works but needs improvement)

6. **Circuit Repair** -- no difficulty progression. Always 4-digit clock. Grade 3+ should use 5-6 digit numbers or require finding the swap among multiple possible swaps.

7. **Nebula Matrix** -- zones added to logic but game screen doesn't render zone borders. Need to add zone coloring in the UI (different background tint per zone).

8. **Hive Station** -- hex visibility fixed with brighter borders. Hint ratio adjusted. Needs testing.

9. **Asteroid Duel** -- bigger cells and instructions now, but visual design still basic. The jagged CustomPaint painter exists but may be visually underwhelming.

### LOW PRIORITY (polish)

10. **Warp Fold** -- animation improved (contrast, cut holes) but still not a real "fold" animation. Ideally: show paper folding with 3D perspective effect.

11. **Relic Assembly** -- rotate button added, drag-drop added. Numbers instead of letters. Needs testing.

12. **Hull Plating** -- error messages on failed placement. Cell count labels. Needs testing.

---

## VERIFICATION NEEDED

All recently fixed games need **Playwright headless browser testing** to verify:
- Do gestures (tap/click) register on Flutter web?
- Are the visuals actually visible (contrast against SpaceBackground)?
- Do game puzzles generate correctly?

Command: `npx playwright screenshot --browser chromium "https://spacemathacademy.vercel.app" screenshot.png`

---

## COMPLETED (this session, ~30 commits)

- 25 new games implemented from Kanguru competition analysis
- 25 test files (400+ tests)
- Dock Clearance removed (duplicate)
- 7 complete game rewrites (Vault Cracker, Star Chart Scan, Cube Scanner, Circuit Repair, Creature Forge, Galactic Market, Ion Chain)
- 15+ targeted fixes across all games
- Multiple design briefs documenting Kanguru originals vs implementation
- VISUAL_TEMPLATE.md and AGENT_IMPLEMENTATION_SPEC.md created

## KEY FILES

- `DESIGN_BRIEFS.md` / `DESIGN_BRIEFS_ROUND2.md` -- approved redesign specs
- `GAME_IDEAS.md` -- original 1544-problem analysis
- `GAME_THEMING.md` -- space narrative, i18n strings
- `VISUAL_TEMPLATE.md` -- mandatory UI patterns
- Kanguru PDFs in `/mnt/storage/downloads/kaenguru_pdfs/`
