# Current risks and issue triage

Updated 2026-10-05. [HANDOVER.md](HANDOVER.md) records the exact green baseline;
[REMAINING_WORK.md](REMAINING_WORK.md) defines executable lanes. Earlier claims
that all issues were resolved referred to the June audit, not every future
interaction or difficulty question.

| Risk or evidence gap | Current evidence | Action lane |
| --- | --- | --- |
| Remaining round lifecycle/input edge cases | 20 games have dedicated completed audits; 28 remain to inspect. No specific new defect is asserted without reproduction. | A–F |
| Structural progression jumps | Recorded 67 flags; zero generation failures. Authored transitions can repeat across grades. | G |
| Child-facing pars and workload bands | Untrained estimates; no child playtest results. Generator timing is not solving time. | H |
| Solver costs and browser integer representations | App retains pinned v2.2.0, alternatives and fallbacks. Native success alone does not prove dart2js/WASM safety. | I |
| Rendering/startup claims | Cached paths and remote probes exist; no demonstrated native FPS/battery gain. | J, H |
| CI duplication and artifact expiry | Full gates pass; calibration artifacts have finite retention. Preserve needed fixtures. | K |
| Store release readiness | Old 1.4.10 platform labels are historical; source is 1.5.22+38. No new store release is claimed. | R |

## Reproduction requirements

Report the game key, commit, seed or frozen board, grade/level, locale, text
scale, viewport, motion setting and exact input/restore/retry sequence. Include
expected versus observed outcome and whether the session remains saved.
For asynchronous bugs, capture which round owned the callback. For generator
bugs, replay the fixture with an independent rule validator. Publish only
synthetic/reproducible state, without profiles or account information.

Browser validation still recognizes the narrowly identified upstream Flutter
CPU-only CanvasKit startup race; see [engine report](docs/flutter-engine-race-report.md).
Do not expand this exception to unrelated app, storage or renderer errors.
Historical June fixes and formulas remain in [GAME_BALANCE_AUDIT.md](GAME_BALANCE_AUDIT.md)
and [HISTORY.md](HISTORY.md); confirm current code before using old formulas.
