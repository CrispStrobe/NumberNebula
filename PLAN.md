# Next-step execution plan

Updated 2026-10-05. The current verified state is in [HANDOVER.md](HANDOVER.md);
full task specifications and acceptance checks are in [REMAINING_WORK.md](REMAINING_WORK.md).
Completed work belongs in [HISTORY.md](HISTORY.md).

1. **A:** Star Forge, Chrono Repair, Orbital Towers; one focused round audit per PR.
2. **B–F:** Complete the other 25 registered-game round audits in independently
   owned batches. A–F together cover 28 remaining games; 20 already have dedicated
   audited round tests. All 48 already have generation/session baseline coverage.
3. **G and I:** In parallel when resources permit, inspect structural progression
   flags and create a narrow reproducible upstream solver benchmark. Preserve
   all baseline/candidate/fallback paths and avoid automatic par changes.
4. **J and K:** Measure browser/rendering and CI costs remotely. Optimize only
   measured bottlenecks while retaining all required validation gates.
5. **H:** Prepare human/device validation now; execute measurements when real
   devices and playtest data are available. This dependency prevents claims of
   calibrated child difficulty or native frame/battery improvements.
6. **R:** Prepare release notes and verify current store states/build mappings.
   Historical review labels are insufficient evidence to release a platform.

Parallel ownership: screen/test lanes can work independently. Assign a single
integrator to shared mixins, workflow files, dependency pins and version bumps.
Check host load, available RAM and disk before local work; large tests, sampling,
WASM builds and browser jobs belong on GitHub Actions (or a configured remote runner).
Use separate commits per repository and publish public documentation only.
